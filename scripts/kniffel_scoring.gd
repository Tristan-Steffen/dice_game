class_name KniffelScoring
## Reine Wertungslogik (Balatro-artig) – keine Nodes, nur Rechnen.
##
## Jede Hand hat einen festen Multiplikator. Punkte = Basiswert × Multiplikator,
## wobei der Basiswert je nach Hand die beteiligten Würfelaugen widerspiegelt
## (z.B. Dreierpasch aus 3x Fünfen: Basis 15 × Mult 3 = 45 Punkte).

const CATEGORIES := [
	{"key": "one_kind", "label": "Höchste Zahl", "mult": 1},
	{"key": "two_kind", "label": "Paar", "mult": 2},
	{"key": "three_kind", "label": "Dreierpasch", "mult": 3},
	{"key": "small_straight", "label": "Kleine Straße", "mult": 4},
	{"key": "four_kind", "label": "Viererpasch", "mult": 4},
	{"key": "full_house", "label": "Full House", "mult": 4},
	{"key": "three_pairs", "label": "Drei Zweierpäsche", "mult": 5},
	{"key": "double_three_kind", "label": "Doppelter Dreierpasch", "mult": 5},
	{"key": "four_kind_and_pair", "label": "Viererpasch mit Paar", "mult": 6},
	{"key": "large_straight", "label": "Große Straße", "mult": 8},
	{"key": "yahtzee", "label": "Kniffel", "mult": 10},
	{"key": "six_kind", "label": "Sechserpasch", "mult": 15},
]

# Von der prestigeträchtigsten zur schwächsten Hand. best_hand() nimmt die
# erste Kategorie, die zutrifft - Rang schlägt rohen Punktwert (ein Paar
# Einsen soll trotzdem "Paar" heißen, nicht von "Höchste Zahl" überboten
# werden, nur weil eine 6 mehr Basispunkte hätte).
#
# Kleine Straße braucht 5 Würfel in Folge, Große Straße alle 6 (1-2-3-4-5-6).
# Full House (3+2, ein Würfel bleibt außen vor) ist mit den spezifischeren
# 6-Würfel-"Haus"-Varianten kombiniert: Doppelter Dreierpasch (3+3) und
# Viererpasch mit Paar (4+2) werden zuerst geprüft, da sie sonst auch als
# Full House durchgehen würden, aber prestigeträchtiger sind.
const HAND_PRIORITY := [
	"six_kind", "yahtzee", "large_straight", "four_kind_and_pair", "double_three_kind",
	"three_pairs", "four_kind", "full_house", "small_straight", "three_kind", "two_kind", "one_kind",
]

static func label_for(key: String) -> String:
	for cat in CATEGORIES:
		if cat["key"] == key:
			return cat["label"]
	return key

static func mult_for(key: String) -> int:
	for cat in CATEGORIES:
		if cat["key"] == key:
			return cat["mult"]
	return 1

static func qualifies(key: String, dice: Array[int]) -> bool:
	match key:
		"six_kind":
			return _has_count_at_least(dice, 6)
		"yahtzee":
			return _has_count_at_least(dice, 5)
		"large_straight":
			return _has_straight_of_length(dice, 6)
		"four_kind_and_pair":
			return _has_count_and_other_count(dice, 4, 2)
		"double_three_kind":
			return _has_two_groups_with_at_least(dice, 3)
		"three_pairs":
			return _count_groups_with_at_least(dice, 2) >= 3
		"four_kind":
			return _has_count_at_least(dice, 4)
		"full_house":
			return _has_count_and_other_count(dice, 3, 2)
		"small_straight":
			return _has_straight_of_length(dice, 5)
		"three_kind":
			return _has_count_at_least(dice, 3)
		"two_kind":
			return _has_count_at_least(dice, 2)
		"one_kind":
			return true
	return false

static func score_category(key: String, dice: Array[int]) -> int:
	if not qualifies(key, dice):
		return 0
	var mult := mult_for(key)
	match key:
		"one_kind":
			return _highest_value(dice) * mult
		"two_kind":
			return _best_value_with_count(dice, 2) * 2 * mult
		"three_kind":
			return _best_value_with_count(dice, 3) * 3 * mult
		"four_kind":
			return _best_value_with_count(dice, 4) * 4 * mult
		"yahtzee":
			return _best_value_with_count(dice, 5) * 5 * mult
		"six_kind":
			return _best_value_with_count(dice, 6) * 6 * mult
		"four_kind_and_pair", "double_three_kind", "three_pairs", "full_house", "small_straight", "large_straight":
			return _sum(dice) * mult
	return 0

## Bestimmt die bestmögliche Hand für den aktuellen Wurf: die
## prestigeträchtigste Kategorie, die zutrifft (siehe HAND_PRIORITY),
## nicht einfach die mit dem höchsten Punktwert.
static func best_hand(dice: Array[int]) -> Dictionary:
	for key in HAND_PRIORITY:
		if qualifies(key, dice):
			return {
				"key": key,
				"label": label_for(key),
				"mult": mult_for(key),
				"score": score_category(key, dice),
			}
	return {"key": "one_kind", "label": label_for("one_kind"), "mult": 1, "score": score_category("one_kind", dice)}

## Vergleicht zwei Würfe anhand ihres Punktwerts: liefert true, wenn der neue
## Wurf strikt mehr Punkte bringt als der alte. Grundlage der Farkle-Regel:
## ein Neu-Würfeln, das NICHT mehr Punkte bringt (gleich viele oder weniger),
## gilt als Farkle - unabhängig davon, welche Hand-Kategorie jeweils vorliegt.
static func is_strictly_better(new_dice: Array[int], old_dice: Array[int]) -> bool:
	var new_score: int = best_hand(new_dice)["score"]
	var old_score: int = best_hand(old_dice)["score"]
	return new_score > old_score

static func _counts(dice: Array[int]) -> Dictionary:
	var result := {}
	for value in dice:
		result[value] = result.get(value, 0) + 1
	return result

static func _sum(dice: Array[int]) -> int:
	var total := 0
	for value in dice:
		total += value
	return total

static func _highest_value(dice: Array[int]) -> int:
	var best := 0
	for value in dice:
		if value > best:
			best = value
	return best

static func _best_value_with_count(dice: Array[int], n: int) -> int:
	var best := 0
	var counts := _counts(dice)
	for value in counts:
		if counts[value] >= n and value > best:
			best = value
	return best

static func _has_count_at_least(dice: Array[int], n: int) -> bool:
	for count in _counts(dice).values():
		if count >= n:
			return true
	return false

## Anzahl unterschiedlicher Augenzahlen, die je mindestens n-mal vorkommen.
static func _count_groups_with_at_least(dice: Array[int], n: int) -> int:
	var qualifying := 0
	for count in _counts(dice).values():
		if count >= n:
			qualifying += 1
	return qualifying

## True, wenn mindestens zwei unterschiedliche Augenzahlen je mindestens n-mal
## vorkommen (z.B. n=3 für "zwei Dreierpasche").
static func _has_two_groups_with_at_least(dice: Array[int], n: int) -> bool:
	return _count_groups_with_at_least(dice, n) >= 2

## True, wenn eine Augenzahl mindestens n-mal und eine ANDERE Augenzahl
## mindestens other_n-mal vorkommt (z.B. n=4, other_n=2 für "Vierer mit Paar").
static func _has_count_and_other_count(dice: Array[int], n: int, other_n: int) -> bool:
	var counts := _counts(dice)
	for value in counts:
		if counts[value] < n:
			continue
		for other_value in counts:
			if other_value != value and counts[other_value] >= other_n:
				return true
	return false

## True, wenn die Würfel `length` aufeinanderfolgende Augenzahlen abdecken
## (z.B. length=5 für die kleine, length=6 für die große Straße).
static func _has_straight_of_length(dice: Array[int], length: int) -> bool:
	var unique := {}
	for value in dice:
		unique[value] = true
	var start := 1
	while start + length - 1 <= 6:
		var has_all := true
		for value in range(start, start + length):
			if not unique.has(value):
				has_all = false
				break
		if has_all:
			return true
		start += 1
	return false
