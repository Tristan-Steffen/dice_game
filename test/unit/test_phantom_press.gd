extends GutTest
## Tests der Presse: Ikonensätze, die MULTICAST-Kette (Deckel, flache Chance,
## Grundwurf je Größe, Erwartungswerte) und die FLACHE Auszahlung. Alles rein - der
## Würfel wird injiziert, wo es auf ihn ankommt.

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

# --- Der MULTICAST: eine Auslösung ist sicher, jeder Treffer legt nach -----------

## Die Chance ist für jede GRÖSSE dieselbe - die Kettenlänge ist dasselbe Glück,
## ob Standard oder Kolossal. Die unterste Sprosse ist die Vorgabe ohne Lauf.
func test_the_chance_is_flat_for_every_size() -> void:
	assert_typeof(PhantomPress.MULTICAST_CHANCE, TYPE_FLOAT, "eine Zahl, keine Tabelle")
	assert_almost_eq(PhantomPress.MULTICAST_CHANCE, 0.5, 0.0001)
	assert_lt(PhantomPress.MULTICAST_CHANCE, 1.0,
		"und niemals sicher - sonst wäre es keine Kette")
	assert_eq(PhantomPress.MULTICAST_CAP, 3, "die unterste Sprosse deckelt bei drei")
	assert_almost_eq(PhantomPress.MULTICAST_CHANCE,
		PhantomPress.base_chance(1), 0.0001, "= Sprosse der Lizenzstufe 1")
	assert_eq(PhantomPress.MULTICAST_CAP, PhantomPress.base_cap(1))

## Die Leiter der Lizenz: fünf Meilensteine, beide Werte steigen streng monoton,
## und zwischen zwei Sprossen rührt sich nichts.
func test_the_ladder_grows_with_the_licence() -> void:
	var expected_chance := {1: 0.5, 2: 0.5, 3: 0.56, 4: 0.56, 5: 0.62, 6: 0.62,
		7: 0.69, 8: 0.69, 9: 0.69, 10: 0.75}
	var expected_cap := {1: 3, 2: 3, 3: 4, 4: 4, 5: 5, 6: 5, 7: 6, 8: 6, 9: 6, 10: 7}
	for level: int in expected_chance:
		assert_almost_eq(PhantomPress.base_chance(level), float(expected_chance[level]),
			0.0001, "Chance auf Stufe %d" % level)
		assert_eq(PhantomPress.base_cap(level), int(expected_cap[level]),
			"Decke auf Stufe %d" % level)

func test_the_ladder_steps_match_the_capacitor_rows() -> void:
	var hubs: Array[int] = []
	for rung: Dictionary in PhantomPress.MULTICAST_LADDER:
		hubs.append(int(rung["hub"]))
	assert_eq(hubs, [1, 3, 5, 7, 10] as Array[int],
		"dieselben Meilensteine wie die Kondensator-Reihen")
	assert_eq(PhantomPress.max_cap(), 7, "die höchste Decke der Leiter")
	assert_almost_eq(PhantomPress.MULTICAST_CHANCE_MAX, 0.9, 0.0001)

## Chance und Decke reisen als PARAMETER - PhantomPress kennt keinen Lauf.
func test_chance_and_cap_are_parameters() -> void:
	assert_almost_eq(PhantomPress.expected_triggers(0.5, 5), 1.9375, 0.0001)
	assert_almost_eq(PhantomPress.expected_triggers(0.75, 7), 3.4659, 0.001)
	# Decke 1 = keine Kette: genau eine Auslösung, wie hoch die Chance auch steht.
	assert_almost_eq(PhantomPress.expected_triggers(0.9, 1), 1.0, 0.0001)
	for seed_value in 40:
		assert_eq(PhantomPress.roll_multicast(_seeded(seed_value), 0.9, 1), 1,
			"Kurzschluss: eine Auslösung, nie mehr")

## Die Größe setzt den GRUNDWURF: was eine einzelne Auslösung auswirft.
func test_the_base_table_carries_one_entry_per_size() -> void:
	assert_eq(PhantomPress.BASE_PIECES.size(), Pack.TIER_PRICE_FACTORS.size(),
		"je Paketgröße ein Grundwurf")
	assert_eq(PhantomPress.base_for(Pack.TIER_NORMAL), 1)
	assert_eq(PhantomPress.base_for(Pack.TIER_GROSS), 3)
	assert_eq(PhantomPress.base_for(Pack.TIER_KOLOSSAL), 5)
	var previous := 0
	for tier in PhantomPress.BASE_PIECES.size():
		var base := PhantomPress.base_for(tier)
		assert_gt(base, previous, "Größe %d wirft mehr aus als die darunter" % tier)
		previous = base

func test_an_unknown_size_falls_back_to_the_norm() -> void:
	assert_eq(PhantomPress.base_for(-1), PhantomPress.base_for(Pack.TIER_NORMAL))
	assert_eq(PhantomPress.base_for(99), PhantomPress.base_for(Pack.TIER_NORMAL))

## Die geometrische Reihe bis zur Decke - auf der untersten Sprosse 1 + p + p².
func test_the_expected_pieces_are_the_geometric_series() -> void:
	assert_almost_eq(PhantomPress.expected_triggers(), 1.75, 0.0001)
	assert_almost_eq(PhantomPress.expected_pieces(Pack.TIER_NORMAL), 1.75, 0.0001)
	assert_almost_eq(PhantomPress.expected_pieces(Pack.TIER_GROSS), 5.25, 0.0001)
	assert_almost_eq(PhantomPress.expected_pieces(Pack.TIER_KOLOSSAL), 8.75, 0.0001)

## Das Verhältnis 1 : 3 : 5 hängt NICHT an der Kette - darum bleibt die
## Preistabelle (Pack.TIER_PRICE_FACTORS) auf jeder Lizenzstufe dieselbe.
func test_the_size_ratio_is_chance_independent() -> void:
	for rung: Dictionary in PhantomPress.MULTICAST_LADDER:
		var chance := float(rung["chance"])
		var cap := int(rung["cap"])
		var base := PhantomPress.expected_pieces(Pack.TIER_NORMAL, chance, cap)
		assert_almost_eq(PhantomPress.expected_pieces(Pack.TIER_GROSS, chance, cap) / base,
			3.0, 0.0001, "Groß = 3× Standard auf Stufe %d" % int(rung["hub"]))
		assert_almost_eq(PhantomPress.expected_pieces(Pack.TIER_KOLOSSAL, chance, cap) / base,
			5.0, 0.0001, "Kolossal = 5× Standard auf Stufe %d" % int(rung["hub"]))

func test_the_chain_never_reaches_past_the_cap() -> void:
	for seed_value in 120:
		var triggers := PhantomPress.roll_multicast(_seeded(seed_value))
		assert_between(triggers, 1, PhantomPress.MULTICAST_CAP,
			"%d Auslösungen" % triggers)

## Über ein paar hundert gesetzte Würfe muss sich der Erwartungswert zeigen -
## sonst ist die Kette nur eine Behauptung.
func test_the_measured_average_meets_the_expected_one() -> void:
	var sum := 0
	for seed_value in 300:
		sum += PhantomPress.roll_multicast(_seeded(seed_value * 7))
	var mean := float(sum) / 300.0
	assert_almost_eq(mean, PhantomPress.expected_triggers(), 0.25,
		"im Mittel bei %.2f Auslösungen" % mean)

## Größer heißt nicht längere Kette, sondern schwererer Schlag - und über die
## ganze Ausbeute gemessen zahlt es sich genauso aus.
func test_a_bigger_pack_really_pays_more() -> void:
	var means: Array[float] = []
	for tier in [Pack.TIER_NORMAL, Pack.TIER_GROSS, Pack.TIER_KOLOSSAL]:
		var sum := 0
		for seed_value in 120:
			sum += PhantomPress.payout(NUMBER, tier, _seeded(seed_value * 13 + tier)).size()
		means.append(float(sum) / 120.0)
	assert_gt(means[1], means[0], "Groß schlägt Standard")
	assert_gt(means[2], means[1], "Kolossal schlägt Groß")
	for i in means.size():
		# Die Streuung skaliert mit dem Grundwurf: ein Kolossal-Wurf springt in
		# Fünferschritten, also darf auch die Schranke mitwachsen.
		assert_almost_eq(means[i], PhantomPress.expected_pieces(i),
			0.4 * float(PhantomPress.base_for(i)),
			"Größe %d im Mittel bei %.2f Stücken" % [i, means[i]])

func test_the_same_seed_rolls_the_same_chain() -> void:
	assert_eq(PhantomPress.roll_multicast(_seeded(4242)),
		PhantomPress.roll_multicast(_seeded(4242)))

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

func test_the_payout_rolls_its_own_chain() -> void:
	var pieces := PhantomPress.payout(NUMBER, Pack.TIER_NORMAL, _seeded(11))
	assert_between(pieces.size(), 1, PhantomPress.MULTICAST_CAP,
		"eins ist sicher, die Decke der Sprosse ist das Ende")

# --- Die Auslösungs-Gruppen: eine Gruppe je Schlag, so groß wie die Größe --------

func test_every_trigger_group_carries_the_size_base() -> void:
	for tier in [Pack.TIER_NORMAL, Pack.TIER_GROSS, Pack.TIER_KOLOSSAL]:
		for seed_value in 30:
			var groups := PhantomPress.payout_groups(MATERIAL, tier, _seeded(seed_value))
			assert_between(groups.size(), 1, PhantomPress.MULTICAST_CAP,
				"Größe %d: %d Auslösungen" % [tier, groups.size()])
			for group in groups:
				assert_eq(group.size(), PhantomPress.base_for(tier),
					"jede Auslösung wirft den Grundwurf ihrer Größe aus")

## Der schwerste Wurf überhaupt: fünf Auslösungen zu fünf Stücken.
func test_the_heaviest_possible_press_is_five_times_five() -> void:
	var most := 0
	for seed_value in 200:
		most = maxi(most, PhantomPress.payout(RUNES, Pack.TIER_KOLOSSAL,
			_seeded(seed_value)).size())
	assert_eq(most, PhantomPress.MULTICAST_CAP * PhantomPress.base_for(Pack.TIER_KOLOSSAL),
		"25 Stücke aus einem Leser sind die Decke - und sie fällt auch")

func test_the_flat_payout_is_the_groups_read_in_one_line() -> void:
	var groups := PhantomPress.payout_groups(NUMBER, Pack.TIER_GROSS, _seeded(77))
	var flat := PhantomPress.payout(NUMBER, Pack.TIER_GROSS, _seeded(77))
	var sum := 0
	for group in groups:
		sum += group.size()
	assert_eq(flat.size(), sum, "dieselbe Beute, nur ohne Gliederung")

## Jede Auslösung würfelt FRISCH: über viele Ketten dürfen die Icons einer
## Auszahlung nicht immer dieselben sein.
func test_every_trigger_rolls_its_own_icon() -> void:
	var mixed := false
	for seed_value in 60:
		var ids := {}
		for piece in PhantomPress.payout(NUMBER, Pack.TIER_KOLOSSAL, _seeded(seed_value)):
			ids[String(piece["id"])] = true
		if ids.size() > 1:
			mixed = true
			break
	assert_true(mixed, "eine Kette wirft nicht sechsmal dasselbe Icon")

func test_an_unknown_sort_pays_nothing() -> void:
	assert_eq(PhantomPress.payout_of("kein-regal", 5, _seeded(1)).size(), 0)

func test_the_fizzle_is_one_coin() -> void:
	# Bei zwei bis zehn Stücken je Paket wäre mehr eine Gelddruckmaschine.
	assert_eq(PhantomPress.FIZZLE_MONEY, 1)

