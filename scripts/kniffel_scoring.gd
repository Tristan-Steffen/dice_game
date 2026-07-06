class_name KniffelScoring
## Reine Kniffel-Wertungslogik – keine Nodes, nur Rechnen.

const CATEGORIES := [
	{"key": "ones", "label": "Einser"},
	{"key": "twos", "label": "Zweier"},
	{"key": "threes", "label": "Dreier"},
	{"key": "fours", "label": "Vierer"},
	{"key": "fives", "label": "Fünfer"},
	{"key": "sixes", "label": "Sechser"},
	{"key": "three_kind", "label": "Dreierpasch"},
	{"key": "four_kind", "label": "Viererpasch"},
	{"key": "full_house", "label": "Full House"},
	{"key": "small_straight", "label": "Kleine Straße"},
	{"key": "large_straight", "label": "Große Straße"},
	{"key": "yahtzee", "label": "Kniffel"},
	{"key": "chance", "label": "Chance"},
]
const UPPER_KEYS := ["ones", "twos", "threes", "fours", "fives", "sixes"]

# Von der prestigeträchtigsten zur schwächsten Hand - entscheidet bei
# Punktgleichstand (z.B. Viererpasch und Dreierpasch treffen beide zu).
const HAND_PRIORITY := [
	"yahtzee", "large_straight", "small_straight", "full_house",
	"four_kind", "three_kind",
	"sixes", "fives", "fours", "threes", "twos", "ones",
	"chance",
]

static func score_category(key: String, dice: Array[int]) -> int:
	match key:
		"ones":
			return _count(dice, 1) * 1
		"twos":
			return _count(dice, 2) * 2
		"threes":
			return _count(dice, 3) * 3
		"fours":
			return _count(dice, 4) * 4
		"fives":
			return _count(dice, 5) * 5
		"sixes":
			return _count(dice, 6) * 6
		"three_kind":
			return _sum(dice) if _has_count_at_least(dice, 3) else 0
		"four_kind":
			return _sum(dice) if _has_count_at_least(dice, 4) else 0
		"full_house":
			return 25 if _is_full_house(dice) else 0
		"small_straight":
			return 30 if _has_small_straight(dice) else 0
		"large_straight":
			return 40 if _has_large_straight(dice) else 0
		"yahtzee":
			return 50 if _has_count_at_least(dice, 5) else 0
		"chance":
			return _sum(dice)
	return 0

static func label_for(key: String) -> String:
	for cat in CATEGORIES:
		if cat["key"] == key:
			return cat["label"]
	return key

## Bestimmt die bestmögliche Hand für den aktuellen Wurf (höchster Punktwert;
## bei Gleichstand gewinnt der prestigeträchtigere Kategorie gemäß HAND_PRIORITY,
## z.B. Viererpasch statt Dreierpasch statt Chance bei gleicher Summe).
static func best_hand(dice: Array[int]) -> Dictionary:
	var best_key: String = HAND_PRIORITY[-1]
	var best_score := -1
	for key in HAND_PRIORITY:
		var score := score_category(key, dice)
		if score > best_score:
			best_score = score
			best_key = key
	return {"key": best_key, "label": label_for(best_key), "score": best_score}

static func _counts(dice: Array[int]) -> Dictionary:
	var result := {}
	for value in dice:
		result[value] = result.get(value, 0) + 1
	return result

static func _count(dice: Array[int], value: int) -> int:
	return _counts(dice).get(value, 0)

static func _sum(dice: Array[int]) -> int:
	var total := 0
	for value in dice:
		total += value
	return total

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

static func _has_large_straight(dice: Array[int]) -> bool:
	var unique := {}
	for value in dice:
		unique[value] = true
	if unique.size() != 5:
		return false
	return not unique.has(1) or not unique.has(6)
