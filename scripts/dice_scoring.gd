class_name DiceScoring
## Reine Wertungslogik (Balatro-artig) – keine Nodes, nur Rechnen.
##
## Jede Hand hat einen festen Multiplikator. Punkte = Basiswert × Multiplikator,
## wobei der Basiswert je nach Hand die beteiligten Würfelaugen widerspiegelt
## (z.B. Dreierpasch aus 3x Fünfen: Basis 15 × Mult 3 = 45 Punkte).

const CATEGORIES := [
	{"key": "one_kind", "label": "Höchste Zahl", "mult": 1},
	{"key": "two_kind", "label": "Paar", "mult": 2},
	{"key": "two_pair", "label": "Zwei Paare", "mult": 3},
	{"key": "three_kind", "label": "Dreierpasch", "mult": 3},
	{"key": "small_straight", "label": "Kleine Straße", "mult": 4},
	{"key": "four_kind", "label": "Viererpasch", "mult": 4},
	{"key": "full_house", "label": "Full House", "mult": 4},
	{"key": "three_pairs", "label": "Drei Zweierpäsche", "mult": 5},
	{"key": "double_three_kind", "label": "Doppelter Dreierpasch", "mult": 5},
	{"key": "four_kind_and_pair", "label": "Viererpasch mit Paar", "mult": 6},
	{"key": "large_straight", "label": "Große Straße", "mult": 8},
	{"key": "five_kind", "label": "5 of a Kind", "mult": 10},
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
# Full House durchgehen würden, aber prestigeträchtiger sind. Zwei Paare (2+2,
# zwei Würfel bleiben außen vor) steht ganz unten, direkt vor Dreierpasch/Paar
# - alle spezifischeren 3+/4+-Kombinationen darüber (Full House, Doppelter
# Dreierpasch, Viererpasch mit Paar, Drei Zweierpäsche) werden zuerst geprüft,
# da ein Wert mit Zählung ≥3 auch Zwei Paare lose erfüllen würde.
const HAND_PRIORITY := [
	"six_kind", "five_kind", "large_straight", "four_kind_and_pair", "double_three_kind",
	"three_pairs", "four_kind", "full_house", "small_straight", "three_kind", "two_pair", "two_kind", "one_kind",
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
		"five_kind":
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
		"two_pair":
			return _count_groups_with_at_least(dice, 2) >= 2
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
		"five_kind":
			return _best_value_with_count(dice, 5) * 5 * mult
		"six_kind":
			return _best_value_with_count(dice, 6) * 6 * mult
		"four_kind_and_pair", "double_three_kind", "three_pairs", "full_house", "small_straight", "large_straight", "two_pair":
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

## Wie best_hand(), liefert aber zusätzlich die Positionen in dice, die zur
## besten Kategorie gehören (z.B. beim Full House die drei- und zweifach
## vorkommenden Würfel, aber nicht einen unbeteiligten sechsten Würfel) -
## Grundlage fürs automatische Vorauswählen der besten Kombination nach jedem
## Wurf (siehe scene_root.gd: _auto_select_best_combo).
static func best_hand_indices(dice: Array[int]) -> Array[int]:
	var key: String = best_hand(dice)["key"]
	match key:
		"six_kind":
			return _indices_for_value(dice, _best_value_with_count(dice, 6), 6)
		"five_kind":
			return _indices_for_value(dice, _best_value_with_count(dice, 5), 5)
		"four_kind":
			return _indices_for_value(dice, _best_value_with_count(dice, 4), 4)
		"three_kind":
			return _indices_for_value(dice, _best_value_with_count(dice, 3), 3)
		"two_pair":
			var result: Array[int] = []
			for value in _values_with_count_at_least(dice, 2):
				result.append_array(_indices_for_value(dice, value, 2))
			return result
		"two_kind":
			return _indices_for_value(dice, _best_value_with_count(dice, 2), 2)
		"one_kind":
			return [_index_of_highest(dice)]
		"four_kind_and_pair":
			var pair := _find_count_and_other_count(dice, 4, 2)
			return _indices_for_value(dice, pair[0], 4) + _indices_for_value(dice, pair[1], 2)
		"full_house":
			var pair := _find_count_and_other_count(dice, 3, 2)
			return _indices_for_value(dice, pair[0], 3) + _indices_for_value(dice, pair[1], 2)
		"double_three_kind":
			var pair := _find_two_groups_with_at_least(dice, 3)
			return _indices_for_value(dice, pair[0], 3) + _indices_for_value(dice, pair[1], 3)
		"three_pairs":
			var result: Array[int] = []
			for value in _values_with_count_at_least(dice, 2):
				result.append_array(_indices_for_value(dice, value, 2))
			return result
		"small_straight":
			return _indices_for_straight(dice, 5)
		"large_straight":
			return _indices_for_straight(dice, 6)
	return []

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

## Index des höchsten Werts (erstes Vorkommen) - Grundlage für
## best_hand_indices bei "Höchste Zahl".
static func _index_of_highest(dice: Array[int]) -> int:
	var best_index := 0
	var best_value := -1
	for i in dice.size():
		if dice[i] > best_value:
			best_value = dice[i]
			best_index = i
	return best_index

## Erste n Indizes in dice, deren Wert value entspricht (z.B. die 3 Vierer
## eines Full House) - Grundlage für best_hand_indices.
static func _indices_for_value(dice: Array[int], value: int, n: int) -> Array[int]:
	var result: Array[int] = []
	for i in dice.size():
		if dice[i] == value:
			result.append(i)
			if result.size() >= n:
				break
	return result

## Wie _has_count_and_other_count, liefert aber [value, other_value] statt nur
## true/false - Grundlage für best_hand_indices (Full House, Vierer mit Paar).
static func _find_count_and_other_count(dice: Array[int], n: int, other_n: int) -> Array[int]:
	var counts := _counts(dice)
	for value in counts:
		if counts[value] < n:
			continue
		for other_value in counts:
			if other_value != value and counts[other_value] >= other_n:
				return [value, other_value]
	return [0, 0]

## Wie _has_two_groups_with_at_least, liefert aber die zwei Werte statt nur
## true/false - Grundlage für best_hand_indices (Doppelter Dreierpasch).
static func _find_two_groups_with_at_least(dice: Array[int], n: int) -> Array[int]:
	var counts := _counts(dice)
	var found: Array[int] = []
	for value in counts:
		if counts[value] >= n:
			found.append(value)
			if found.size() >= 2:
				break
	return found

## Alle Werte, die mindestens n-mal vorkommen - Grundlage für
## best_hand_indices (Drei Zweierpäsche).
static func _values_with_count_at_least(dice: Array[int], n: int) -> Array[int]:
	var counts := _counts(dice)
	var found: Array[int] = []
	for value in counts:
		if counts[value] >= n:
			found.append(value)
	return found

## Je ein Index pro Wert der ersten passenden Straße der Länge length (siehe
## _has_straight_of_length) - überzählige Würfel mit doppelten Werten bleiben
## außen vor. Grundlage für best_hand_indices.
static func _indices_for_straight(dice: Array[int], length: int) -> Array[int]:
	var first_index_of := {}
	for i in dice.size():
		if not first_index_of.has(dice[i]):
			first_index_of[dice[i]] = i
	var start := 1
	while start + length - 1 <= 6:
		var has_all := true
		for value in range(start, start + length):
			if not first_index_of.has(value):
				has_all = false
				break
		if has_all:
			var result: Array[int] = []
			for value in range(start, start + length):
				result.append(first_index_of[value])
			return result
		start += 1
	return []
