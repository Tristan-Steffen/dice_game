extends GutTest
## Tests der Presse: Ikonensätze, die Ausbeute-Verteilung (1/3/5) und die FLACHE
## Auszahlung. Alles rein - der Würfel wird injiziert, wo es auf ihn ankommt.

const NUMBER := Engraving.CATEGORY_NUMBER
const MATERIAL := Engraving.CATEGORY_MATERIAL
const RUNES := Engraving.CATEGORY_DICE

func _seeded(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng

# --- Ikonensätze --------------------------------------------------------------

func test_every_sort_has_exactly_six_icons() -> void:
	for sort: String in PhantomPress.ICONS:
		assert_eq(PhantomPress.icons_for(sort).size(), PhantomPress.FACE_COUNT,
			"%s hat sechs Icons" % sort)

func test_every_icon_is_a_real_engraving() -> void:
	for sort: String in PhantomPress.ICONS:
		for id in PhantomPress.icons_for(sort):
			var engraving := Engraving.by_id(id)
			assert_not_null(engraving, "Icon %s ist ein Archetyp" % id)
			assert_eq(engraving.category, sort, "%s liegt in seiner Sorte" % id)

func test_the_icon_sets_are_disjoint() -> void:
	var seen := {}
	for sort: String in PhantomPress.ICONS:
		for id in PhantomPress.icons_for(sort):
			assert_false(seen.has(id), "Icon doppelt: %s" % id)
			seen[id] = true

func test_sort_of_finds_the_icon_set() -> void:
	assert_eq(PhantomPress.sort_of(Engraving.NOTCH), NUMBER)
	assert_eq(PhantomPress.sort_of(DieMaterial.COPPER), MATERIAL)
	assert_eq(PhantomPress.sort_of(Engraving.RUNE_PREFIX + Rune.CAST), RUNES)

func test_the_pointer_lies_on_no_icon_set() -> void:
	# Genau darum gibt es den Pointer nur als Fixinhalt - gewürfelt wird er nie.
	assert_eq(PhantomPress.sort_of(Engraving.POINTER), "")
	assert_eq(PhantomPress.face_of(RUNES, Engraving.POINTER), -1)

# --- Die Ausbeute: 1 / 3 / 5 zu 60 / 30 / 10 % ---------------------------------

func test_the_yield_table_is_one_source() -> void:
	assert_eq(PhantomPress.YIELDS, [1, 3, 5])
	assert_eq(PhantomPress.YIELD_WEIGHTS.size(), PhantomPress.YIELDS.size())
	var sum := 0.0
	for weight in PhantomPress.YIELD_WEIGHTS:
		sum += float(weight)
	assert_almost_eq(sum, 1.0, 0.0001, "die Gewichte schließen die Verteilung")

## Die Grenzen sind das Wesentliche: 0.59 fällt noch auf eins, 0.61 schon auf
## drei, 0.91 auf fünf - und 0.9999 bleibt bei fünf.
func _yield_at(roll: float) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	# randf ist nicht setzbar - also über den Rand geprüft, den roll_yield zieht.
	var sum := 0.0
	for i in PhantomPress.YIELDS.size():
		sum += float(PhantomPress.YIELD_WEIGHTS[i])
		if roll < sum:
			return int(PhantomPress.YIELDS[i])
	return int(PhantomPress.YIELDS[PhantomPress.YIELDS.size() - 1])

func test_the_boundaries_fall_where_the_weights_say() -> void:
	assert_eq(_yield_at(0.0), 1)
	assert_eq(_yield_at(0.59), 1)
	assert_eq(_yield_at(0.61), 3)
	assert_eq(_yield_at(0.89), 3)
	assert_eq(_yield_at(0.91), 5)
	assert_eq(_yield_at(0.9999), 5, "und der Rest ist Jackpot")

func test_a_seeded_roll_only_ever_gives_one_three_or_five() -> void:
	var seen := {}
	for seed_value in 200:
		var count := PhantomPress.roll_yield(_seeded(seed_value))
		assert_true(PhantomPress.YIELDS.has(count), "Ausbeute %d liegt in der Tabelle" % count)
		seen[count] = int(seen.get(count, 0)) + 1
	assert_gt(int(seen.get(1, 0)), int(seen.get(5, 0)), "eins fällt öfter als fünf")
	assert_gt(int(seen.get(1, 0)), int(seen.get(3, 0)), "und öfter als drei")

func test_the_same_seed_rolls_the_same_yield() -> void:
	assert_eq(PhantomPress.roll_yield(_seeded(4242)), PhantomPress.roll_yield(_seeded(4242)))

# --- Auszahlung: flach, und jedes Stück würfelt sein Icon selbst ---------------

func test_a_piece_is_always_flat() -> void:
	var piece := PhantomPress.piece(NUMBER, Engraving.NOTCH)
	assert_eq(int(piece["stufe"]), 1, "aus der Presse kommt nur die erste Sprosse")
	assert_eq(int(piece["applications"]), 1, "und genau eine Anwendung")
	assert_eq(String(piece["sort"]), NUMBER)
	assert_false(piece.has("slot"), "die Beute liegt in der Ablage, in keinem Leser")

func test_the_payout_delivers_exactly_its_count() -> void:
	for count in [0, 1, 3, 5, 9]:
		assert_eq(PhantomPress.payout_of(NUMBER, count, _seeded(count)).size(), count,
			"%d Stücke" % count)

func test_every_piece_of_a_payout_is_flat_and_of_its_sort() -> void:
	for piece in PhantomPress.payout_of(MATERIAL, 5, _seeded(3)):
		assert_eq(String(piece["sort"]), MATERIAL)
		assert_eq(int(piece["stufe"]), 1)
		assert_eq(int(piece["applications"]), 1)
		assert_true(PhantomPress.icons_for(MATERIAL).has(String(piece["id"])),
			"%s liegt auf dem Ikonensatz" % String(piece["id"]))

## Jedes Stück würfelt EINZELN: zwei gleiche Icons in einem Paket sind kein
## Fehler, sondern zwei Stücke.
func test_two_pieces_may_show_the_same_icon() -> void:
	var doubled := false
	for seed_value in 40:
		var ids := {}
		for piece in PhantomPress.payout_of(RUNES, 5, _seeded(seed_value)):
			var id := String(piece["id"])
			if ids.has(id):
				doubled = true
			ids[id] = true
	assert_true(doubled, "bei fünf Stücken aus sechs Icons fällt irgendwann ein Paar")

# --- Ein Icon faellt nach seiner Seltenheit -----------------------------------------

func test_the_icon_weights_come_from_the_rarity() -> void:
	for sort in [NUMBER, MATERIAL, RUNES]:
		var weights := PhantomPress.weights_for(sort)
		assert_eq(weights.size(), PhantomPress.FACE_COUNT, "%s: je Icon ein Gewicht" % sort)
		for i in weights.size():
			var id := PhantomPress.icon_of(sort, i)
			assert_eq(weights[i], Engraving.rarity_weight(Engraving.by_id(id).rarity),
				"%s traegt das Gewicht seiner Seltenheit" % id)

func test_a_rarer_engraving_is_never_likelier() -> void:
	# Die Kurve muss monoton fallen, sonst waere "selten" nur ein Wort.
	var order := [Engraving.Rarity.COMMON, Engraving.Rarity.UNCOMMON,
		Engraving.Rarity.RARE, Engraving.Rarity.EPIC, Engraving.Rarity.LEGENDARY]
	for i in range(1, order.size()):
		assert_lt(Engraving.rarity_weight(order[i]), Engraving.rarity_weight(order[i - 1]),
			"Stufe %d faellt seltener als die darunter" % i)

func test_commons_fall_far_more_often_than_the_epic() -> void:
	# Der Zahlensatz ist der mit der groessten Spanne: zwei COMMON, drei UNCOMMON,
	# ein EPIC. Ueber viele Wuerfe muss sich das deutlich zeigen.
	var counts := {}
	for seed_value in 400:
		for piece in PhantomPress.payout_of(NUMBER, 5, _seeded(seed_value)):
			var id := String(piece["id"])
			counts[id] = int(counts.get(id, 0)) + 1
	var common := int(counts.get(Engraving.NOTCH, 0))
	var uncommon := int(counts.get(Engraving.POLISH, 0))
	var epic := int(counts.get(Engraving.CHISEL, 0))
	assert_gt(common, uncommon, "haeufig schlaegt ungewoehnlich")
	assert_gt(uncommon, epic, "ungewoehnlich schlaegt episch")
	assert_gt(common, epic * 4, "und der Meissel ist wirklich selten")
	assert_gt(epic, 0, "faellt aber ueberhaupt")

func test_the_payout_rolls_its_own_count() -> void:
	var pieces := PhantomPress.payout(NUMBER, _seeded(11))
	assert_true(PhantomPress.YIELDS.has(pieces.size()), "die Menge kommt aus der Tabelle")

func test_an_unknown_sort_pays_nothing() -> void:
	assert_eq(PhantomPress.payout_of("kein-regal", 5, _seeded(1)).size(), 0)

func test_the_fizzle_is_one_coin() -> void:
	# Bei zwei Stücken je Paket im Schnitt wäre mehr eine Gelddruckmaschine.
	assert_eq(PhantomPress.FIZZLE_MONEY, 1)

# --- Füllhorn-Sorte -----------------------------------------------------------

func _sorts(list: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(list)
	return typed

func test_the_free_piece_takes_the_majority_sort() -> void:
	assert_eq(PhantomPress.majority_sort(_sorts([NUMBER, MATERIAL, MATERIAL])), MATERIAL)

func test_a_tie_falls_back_to_the_first_pack() -> void:
	assert_eq(PhantomPress.majority_sort(_sorts([RUNES, MATERIAL])), RUNES)

func test_an_empty_press_has_a_sort_anyway() -> void:
	assert_eq(PhantomPress.majority_sort(_sorts([])), NUMBER)
