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
const UPPER_BONUS_THRESHOLD := 63
const UPPER_BONUS_VALUE := 35

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

static func calculate_bonus(category_used: Dictionary, category_scores: Dictionary) -> int:
	var upper_sum := 0
	for key in UPPER_KEYS:
		if category_used.get(key, false):
			upper_sum += category_scores[key]
	return UPPER_BONUS_VALUE if upper_sum >= UPPER_BONUS_THRESHOLD else 0

static func calculate_total(category_used: Dictionary, category_scores: Dictionary) -> int:
	var total := calculate_bonus(category_used, category_scores)
	for cat in CATEGORIES:
		if category_used.get(cat["key"], false):
			total += category_scores[cat["key"]]
	return total

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
