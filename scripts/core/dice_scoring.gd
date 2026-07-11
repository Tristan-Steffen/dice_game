class_name DiceScoring
## Reine Wertungslogik (Balatro-artig) – keine Nodes, nur Rechnen.
##
## Jede Hand hat einen festen Multiplikator. Punkte = Basiswert × Multiplikator,
## wobei der Basiswert je nach Hand die beteiligten Würfelaugen widerspiegelt
## (z.B. Dreierpasch aus 3x Fünfen: Basis 15 × Mult 3 = 45 Punkte).
##
## Optionale charm_ids (siehe Charm/CharmEffects) verändern die Wertung an
## mehreren Stellen - Augenwert einzelner Würfel (z.B. Hasenpfote: jede 6 zählt
## doppelt), Kombi-Multiplikator (z.B. Hufeisen), feste Bonuspunkte (z.B.
## Regenbogenforelle) und Verdopplung ganzer Hände (z.B. Zauberkarte) -
## beeinflussen aber nie, welche Kategorie überhaupt zutrifft.

# --- Kategorie-Keys (Single Source of Truth) ----------------------------------
# Wie bei Charm/Coupon-ids: einmal als Konstante definiert und überall darüber
# referenziert (CATEGORIES, HAND_PRIORITY, qualifies, _base_value,
# best_hand_indices, CharmEffects) - ein Tippfehler wird so zum Compilerfehler
# statt zu einer still nie zutreffenden Kategorie. Die Kombinations-Labels der
# Tischliste (siehe scene_root._collect_combo_labels) sind in der Szene nach
# genau diesen Werten benannt.
const ONE_KIND := "one_kind"
const TWO_KIND := "two_kind"
const TWO_PAIR := "two_pair"
const THREE_KIND := "three_kind"
const SMALL_STRAIGHT := "small_straight"
const FOUR_KIND := "four_kind"
const FULL_HOUSE := "full_house"
const THREE_PAIRS := "three_pairs"
const DOUBLE_THREE_KIND := "double_three_kind"
const FOUR_KIND_AND_PAIR := "four_kind_and_pair"
const LARGE_STRAIGHT := "large_straight"
const FIVE_KIND := "five_kind"
const SIX_KIND := "six_kind"

const CATEGORIES := [
	{"key": ONE_KIND, "label": "Höchste Zahl", "mult": 1},
	{"key": TWO_KIND, "label": "Paar", "mult": 2},
	{"key": TWO_PAIR, "label": "Zwei Paare", "mult": 3},
	{"key": THREE_KIND, "label": "Dreierpasch", "mult": 3},
	{"key": SMALL_STRAIGHT, "label": "Kleine Straße", "mult": 4},
	{"key": FOUR_KIND, "label": "Viererpasch", "mult": 4},
	{"key": FULL_HOUSE, "label": "Full House", "mult": 4},
	{"key": THREE_PAIRS, "label": "Drei Zweierpäsche", "mult": 5},
	{"key": DOUBLE_THREE_KIND, "label": "Doppelter Dreierpasch", "mult": 5},
	{"key": FOUR_KIND_AND_PAIR, "label": "Viererpasch mit Paar", "mult": 6},
	{"key": LARGE_STRAIGHT, "label": "Große Straße", "mult": 8},
	{"key": FIVE_KIND, "label": "5 of a Kind", "mult": 10},
	{"key": SIX_KIND, "label": "Sechserpasch", "mult": 15},
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
	SIX_KIND, FIVE_KIND, LARGE_STRAIGHT, FOUR_KIND_AND_PAIR, DOUBLE_THREE_KIND,
	THREE_PAIRS, FOUR_KIND, FULL_HOUSE, SMALL_STRAIGHT, THREE_KIND, TWO_PAIR, TWO_KIND, ONE_KIND,
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
		SIX_KIND:
			return _has_count_at_least(dice, 6)
		FIVE_KIND:
			return _has_count_at_least(dice, 5)
		LARGE_STRAIGHT:
			return _has_straight_of_length(dice, 6)
		FOUR_KIND_AND_PAIR:
			return _has_count_and_other_count(dice, 4, 2)
		DOUBLE_THREE_KIND:
			return _has_two_groups_with_at_least(dice, 3)
		THREE_PAIRS:
			return _count_groups_with_at_least(dice, 2) >= 3
		FOUR_KIND:
			return _has_count_at_least(dice, 4)
		FULL_HOUSE:
			return _has_count_and_other_count(dice, 3, 2)
		SMALL_STRAIGHT:
			return _has_straight_of_length(dice, 5)
		THREE_KIND:
			return _has_count_at_least(dice, 3)
		TWO_PAIR:
			return _count_groups_with_at_least(dice, 2) >= 2
		TWO_KIND:
			return _has_count_at_least(dice, 2)
		ONE_KIND:
			return true
	return false

## charm_ids (siehe Charm.id) wirken auf den Punktwert (siehe CharmEffects) -
## welche Kategorie überhaupt zutrifft, entscheidet weiterhin allein
## qualifies() anhand der rohen Würfelwerte. Reihenfolge der Charm-Wirkungen:
## Augenwert je Würfel (schon im Basiswert) → Kombi-Multiplikator (+mult_bonus)
## → feste Bonuspunkte (flat_bonus) → Verdopplung der ganzen Hand
## (score_multiplier, z.B. Zauberkarte für die erste Hand der Runde, daher der
## is_first_hand-Parameter).
##
## materials (optional, parallel zu dice: DieMaterial-id der oben liegenden
## Seite je Slot, "" = keins) rechnet die Wertungs-Boni der Seiten-Materialien
## ein (siehe MaterialEffects) - nur für Seiten, die zur Kombination gehören
## (siehe participating_indices). Leer = keine Materialien (Verhalten wie zuvor).
static func score_category(key: String, dice: Array[int], charm_ids: Array[String] = [], is_first_hand: bool = false, materials: Array[String] = []) -> int:
	if not qualifies(key, dice):
		return 0
	var base := _base_value(key, dice, charm_ids)
	var mult := mult_for(key) + CharmEffects.mult_bonus(key, charm_ids)
	if not materials.is_empty():
		var participating := participating_indices(key, dice)
		base += MaterialEffects.base_bonus(dice, materials, participating, charm_ids)
		mult += MaterialEffects.mult_bonus(dice, materials, participating)
	var score := base * mult + CharmEffects.flat_bonus(key, charm_ids)
	return score * CharmEffects.score_multiplier(charm_ids, is_first_hand)

## Basiswert einer Kategorie VOR Kombi-Multiplikator: die beteiligten
## (charm-angepassten) Würfelaugen. Paschs zählen n×Augenwert, die
## Summen-Kombinationen die gesamte (angepasste) Augensumme.
static func _base_value(key: String, dice: Array[int], charm_ids: Array[String]) -> int:
	match key:
		ONE_KIND:
			return CharmEffects.eye_value(_highest_value(dice), charm_ids)
		TWO_KIND:
			return CharmEffects.eye_value(_best_value_with_count(dice, 2), charm_ids) * 2
		THREE_KIND:
			return CharmEffects.eye_value(_best_value_with_count(dice, 3), charm_ids) * 3
		FOUR_KIND:
			return CharmEffects.eye_value(_best_value_with_count(dice, 4), charm_ids) * 4
		FIVE_KIND:
			return CharmEffects.eye_value(_best_value_with_count(dice, 5), charm_ids) * 5
		SIX_KIND:
			return CharmEffects.eye_value(_best_value_with_count(dice, 6), charm_ids) * 6
		FOUR_KIND_AND_PAIR, DOUBLE_THREE_KIND, THREE_PAIRS, FULL_HOUSE, SMALL_STRAIGHT, LARGE_STRAIGHT, TWO_PAIR:
			return _sum(dice, charm_ids)
	return 0

## Bestimmt die bestmögliche Hand für den aktuellen Wurf: die
## prestigeträchtigste Kategorie, die zutrifft (siehe HAND_PRIORITY),
## nicht einfach die mit dem höchsten Punktwert. charm_ids/materials siehe
## score_category (das "mult"-Feld enthält auch die Material-Mult-Boni, damit
## die Anzeige zur tatsächlichen Rechnung passt).
static func best_hand(dice: Array[int], charm_ids: Array[String] = [], is_first_hand: bool = false, materials: Array[String] = []) -> Dictionary:
	for key in HAND_PRIORITY:
		if qualifies(key, dice):
			return {
				"key": key,
				"label": label_for(key),
				"mult": _display_mult(key, dice, charm_ids, materials),
				"score": score_category(key, dice, charm_ids, is_first_hand, materials),
			}
	return {"key": ONE_KIND, "label": label_for(ONE_KIND), "mult": _display_mult(ONE_KIND, dice, charm_ids, materials), "score": score_category(ONE_KIND, dice, charm_ids, is_first_hand, materials)}

## Der in best_hand angezeigte Multiplikator: Kategorie-Mult + Charm-Boni +
## Material-Mult-Boni der beteiligten Seiten - identisch zur Rechnung in
## score_category.
static func _display_mult(key: String, dice: Array[int], charm_ids: Array[String], materials: Array[String]) -> int:
	var mult := mult_for(key) + CharmEffects.mult_bonus(key, charm_ids)
	if not materials.is_empty():
		mult += MaterialEffects.mult_bonus(dice, materials, participating_indices(key, dice))
	return mult

## Wie best_hand(), liefert aber zusätzlich die Positionen in dice, die zur
## besten Kategorie gehören - Grundlage fürs automatische Vorauswählen der
## besten Kombination nach jedem Wurf (siehe scene_root.gd:
## _auto_select_best_combo). Die eigentliche Zuordnung macht
## participating_indices, damit auch die Material-Wertung dieselbe Regel nutzt.
static func best_hand_indices(dice: Array[int]) -> Array[int]:
	return participating_indices(best_hand(dice)["key"], dice)

## Die Positionen in dice, die zur Kategorie key gehören (z.B. beim Full House
## die drei- und zweifach vorkommenden Würfel, aber nicht einen unbeteiligten
## sechsten Würfel). Genau diese Seiten zählen für den Basiswert - und nur auf
## ihnen wirken Seiten-Materialien (siehe MaterialEffects).
static func participating_indices(key: String, dice: Array[int]) -> Array[int]:
	match key:
		SIX_KIND:
			return _indices_for_value(dice, _best_value_with_count(dice, 6), 6)
		FIVE_KIND:
			return _indices_for_value(dice, _best_value_with_count(dice, 5), 5)
		FOUR_KIND:
			return _indices_for_value(dice, _best_value_with_count(dice, 4), 4)
		THREE_KIND:
			return _indices_for_value(dice, _best_value_with_count(dice, 3), 3)
		TWO_PAIR:
			var result: Array[int] = []
			for value in _values_with_count_at_least(dice, 2):
				result.append_array(_indices_for_value(dice, value, 2))
			return result
		TWO_KIND:
			return _indices_for_value(dice, _best_value_with_count(dice, 2), 2)
		ONE_KIND:
			return [_index_of_highest(dice)]
		FOUR_KIND_AND_PAIR:
			var pair := _find_count_and_other_count(dice, 4, 2)
			return _indices_for_value(dice, pair[0], 4) + _indices_for_value(dice, pair[1], 2)
		FULL_HOUSE:
			var pair := _find_count_and_other_count(dice, 3, 2)
			return _indices_for_value(dice, pair[0], 3) + _indices_for_value(dice, pair[1], 2)
		DOUBLE_THREE_KIND:
			var pair := _find_two_groups_with_at_least(dice, 3)
			return _indices_for_value(dice, pair[0], 3) + _indices_for_value(dice, pair[1], 3)
		THREE_PAIRS:
			var result: Array[int] = []
			for value in _values_with_count_at_least(dice, 2):
				result.append_array(_indices_for_value(dice, value, 2))
			return result
		SMALL_STRAIGHT:
			return _indices_for_straight(dice, 5)
		LARGE_STRAIGHT:
			return _indices_for_straight(dice, 6)
	return []

## Vergleicht zwei Würfe anhand ihres Punktwerts: liefert true, wenn der neue
## Wurf strikt mehr Punkte bringt als der alte. Grundlage der Farkle-Regel:
## ein Neu-Würfeln, das NICHT mehr Punkte bringt (gleich viele oder weniger),
## gilt als Farkle - unabhängig davon, welche Hand-Kategorie jeweils vorliegt.
## Materialien zählen auf beiden Seiten mit (jeweils die damals oben liegenden).
static func is_strictly_better(new_dice: Array[int], old_dice: Array[int], charm_ids: Array[String] = [], new_materials: Array[String] = [], old_materials: Array[String] = []) -> bool:
	var new_score: int = best_hand(new_dice, charm_ids, false, new_materials)["score"]
	var old_score: int = best_hand(old_dice, charm_ids, false, old_materials)["score"]
	return new_score > old_score

static func _counts(dice: Array[int]) -> Dictionary:
	var result := {}
	for value in dice:
		result[value] = result.get(value, 0) + 1
	return result

static func _sum(dice: Array[int], charm_ids: Array[String] = []) -> int:
	var total := 0
	for value in dice:
		total += CharmEffects.eye_value(value, charm_ids)
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
