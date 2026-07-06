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
	{"key": "small_straight", "label": "Kleine Straße", "mult": 3},
	{"key": "four_kind", "label": "Viererpasch", "mult": 4},
	{"key": "full_house", "label": "Full House", "mult": 4},
	{"key": "yahtzee", "label": "Kniffel", "mult": 10},
]

# Von der prestigeträchtigsten zur schwächsten Hand. best_hand() nimmt die
# erste Kategorie, die zutrifft - Rang schlägt rohen Punktwert (ein Paar
# Einsen soll trotzdem "Paar" heißen, nicht von "Höchste Zahl" überboten
# werden, nur weil eine 6 mehr Basispunkte hätte).
const HAND_PRIORITY := [
	"yahtzee", "four_kind", "full_house", "small_straight", "three_kind", "two_kind", "one_kind",
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
		"yahtzee":
			return _has_count_at_least(dice, 5)
		"four_kind":
			return _has_count_at_least(dice, 4)
		"full_house":
			return _is_full_house(dice)
		"small_straight":
			return _has_small_straight(dice)
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
		"full_house", "small_straight":
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

static func _is_full_house(dice: Array[int]) -> bool:
	var counts: Array = _counts(dice).values()
	counts.sort()
	return counts == [2, 3]

static func _has_small_straight(dice: Array[int]) -> bool:
	var unique := {}
	for value in dice:
		unique[value] = true
	var runs := [[1, 2, 3, 4], [2, 3, 4, 5], [3, 4, 5, 6]]
	for run in runs:
		var has_all := true
		for value in run:
			if not unique.has(value):
				has_all = false
				break
		if has_all:
			return true
	return false
