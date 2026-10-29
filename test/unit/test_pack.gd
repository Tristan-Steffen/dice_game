extends GutTest
## Tests der Paket-Datenklasse: ein Gravur-Paket trägt EIN Prägenetz, und die
## Sorte bildet auf eine Gravur-Kategorie ab. Würfel sind KEINE Paketware mehr.

func test_engraving_packs_map_to_their_category() -> void:
	assert_eq(Pack.number_pack().engraving_category(), Engraving.CATEGORY_NUMBER)
	assert_eq(Pack.material_pack().engraving_category(), Engraving.CATEGORY_MATERIAL)
	assert_eq(Pack.dice_mod_pack().engraving_category(), Engraving.CATEGORY_DICE)

func test_there_is_no_dice_pack_sort_any_more() -> void:
	# Würfel werden nie versiegelt - sie gehen als Ware ins Ausgabefach.
	assert_false(Pack.TYPE_NAMES.has("dice"))
	assert_false(Pack.SHELF_WEIGHTS.has("dice"))
	assert_eq(Pack.shelf_for_pack_type("dice"), Engraving.CATEGORY_NUMBER,
		"eine unbekannte Sorte fällt auf die Zahlen zurück, sie bekommt kein Fach")

func test_every_engraving_pack_carries_exactly_one_net() -> void:
	for pack in Pack.all_engraving_packs():
		assert_eq(pack.count, Pack.ENGRAVING_PACK_COUNT, "%s trägt genau eins" % pack.type)
		assert_eq(pack.stamp_net.size(), StampNet.FACES, "sechs Zellen, eine je Seite")
		assert_gt(StampNet.filled_count(pack.stamp_net), 0, "und mindestens eine gefüllt")

func test_the_mixed_pack_is_gone() -> void:
	# Vielfalt ist jetzt der gemischte BATCH, keine eigene Sorte mehr.
	for pack in Pack.all_engraving_packs():
		assert_ne(pack.type, "mixed")
	assert_false(Pack.TYPE_NAMES.has("mixed"))
	assert_false(Pack.SHELF_WEIGHTS.has("mixed"))

func test_the_rune_pack_is_on_the_shelf_now() -> void:
	var pack := Pack.dice_mod_pack()
	assert_eq(pack.price, Pack.DICE_MOD_PRICE)
	assert_gt(pack.price, 0, "es ist Ware, kein reiner Automaten-Gewinn mehr")
	assert_true(Pack.SHELF_WEIGHTS.has(Pack.TYPE_DICE_MOD), "und liegt darum im Regal")

func test_shelf_weights_are_the_authored_ones() -> void:
	assert_eq(int(Pack.SHELF_WEIGHTS[Pack.TYPE_NUMBER]), 6)
	assert_eq(int(Pack.SHELF_WEIGHTS[Pack.TYPE_MATERIAL]), 3)
	assert_eq(int(Pack.SHELF_WEIGHTS[Pack.TYPE_DICE_MOD]), 2)

func test_prices_are_the_authored_ones() -> void:
	assert_eq(Pack.number_pack().price, 5)
	assert_eq(Pack.material_pack().price, 6)
	assert_eq(Pack.dice_mod_pack().price, 7)

func test_every_shelf_sort_really_rolls() -> void:
	var seen := {}
	for i in 400:
		seen[Pack.roll_engraving_pack().type] = true
	for pack_type: String in Pack.SHELF_WEIGHTS:
		assert_true(seen.has(pack_type), "%s liegt in der Auslage" % pack_type)

func test_by_type_builds_every_shelf_sort() -> void:
	for pack_type: String in Pack.SHELF_WEIGHTS:
		assert_eq(Pack.by_type(pack_type).type, pack_type)

# --- Fixinhalt ----------------------------------------------------------------

func test_fixed_engraving_pack_carries_its_piece_sealed() -> void:
	var pack := Pack.fixed_engraving_pack(Engraving.material_engraving(
		DieMaterial.by_id(DieMaterial.GOLD), Engraving.Rarity.COMMON))
	assert_eq(pack.type, Pack.TYPE_MATERIAL, "die Sorte folgt der Kategorie")
	assert_eq(pack.price, 0, "so etwas wird gefunden, nie verkauft")
	assert_not_null(pack.fixed_engraving)
	assert_eq(pack.fixed_engraving.id, DieMaterial.GOLD)

func test_fixed_engraving_pack_sorts_every_category() -> void:
	assert_eq(Pack.fixed_engraving_pack(Engraving.doping()).type, Pack.TYPE_MATERIAL)
	assert_eq(Pack.fixed_engraving_pack(Engraving.pointer_engraving()).type, Pack.TYPE_DICE_MOD)
	assert_eq(Pack.pack_type_for_category(Engraving.CATEGORY_DICE), Pack.TYPE_DICE_MOD)

func test_press_sort_is_the_engraving_category() -> void:
	assert_eq(Pack.number_pack().press_sort(), Engraving.CATEGORY_NUMBER)
	assert_eq(Pack.dice_mod_pack().press_sort(), Engraving.CATEGORY_DICE)

# --- Sonderposten: Einzelstueck im Regal, starke Karte im Hinterzimmer ---------

func test_a_fixed_pack_holds_one_piece_by_default() -> void:
	var pack := Pack.fixed_engraving_pack(Engraving.doping())
	assert_eq(pack.count, Pack.ENGRAVING_PACK_COUNT)
	assert_eq(pack.price, 0, "gefunden oder abgegossen wird gratis")
	assert_eq(pack.fixed_engraving.id, Engraving.DOPING)
	assert_eq(pack.type, Pack.TYPE_MATERIAL, "die Kategorie entscheidet die Sorte")

## Die STARKE Karte des Schwarzmarkts (2026-10-29): EINE Karte, mehrere Zellen.
func test_a_strong_fixed_pack_is_one_card_with_several_cells() -> void:
	var pack := Pack.fixed_engraving_pack(Engraving.pointer_engraving(), 1, 0, null, 3)
	assert_eq(pack.count, 1)
	assert_eq(pack.fixed_engraving.id, Engraving.POINTER)
	assert_eq(StampNet.filled_count(pack.stamp_net), 3)
	assert_true(pack.description.contains("3 Seiten"), "die Stärke steht auf der Karte")
	assert_eq(pack.type, Pack.TYPE_DICE_MOD)

## Der Sonderposten-Platz führt zwei Familien: das Gravur-Einzelstück zum flachen
## Preis und die Katalysator-Kassette zu ihrem eigenen. Nichts Drittes.
func test_the_shop_special_is_a_single_at_the_flat_price() -> void:
	for i in 60:
		var pack := Pack.roll_special_pack()
		assert_eq(pack.count, 1, "im Regal gibt es keine Bündel")
		if pack.is_catalyst():
			assert_eq(pack.price, Pack.catalyst_price(pack.catalyst_id))
			continue
		if pack.is_operator():
			assert_eq(pack.price, StampNet.operator_price(pack.operator_id))
			continue
		assert_not_null(pack.fixed_engraving)
		assert_true(Engraving.is_special_id(pack.fixed_engraving.id),
			"im Regal liegen nur Sonderposten: %s" % pack.fixed_engraving.id)
		assert_eq(pack.price, Pack.SPECIAL_PRICE, "ein Sonderposten kostet immer dasselbe")

## Über viele Würfe kommen BEIDE Sonderposten und ALLE VIER Regal-Katalysatoren
## vor - sonst wäre einer unerreichbar. Die Reparatur-Karte NIE.
func test_both_specials_reach_the_shelf() -> void:
	var seen := {}
	for i in 400:
		var pack := Pack.roll_special_pack()
		var key := pack.fixed_engraving.id if pack.fixed_engraving != null else ""
		if pack.is_catalyst():
			key = pack.catalyst_id
		elif pack.is_operator():
			key = pack.operator_id
		seen[key] = true
	for special_id: String in Engraving.SPECIAL_IDS:
		assert_true(seen.has(special_id), "%s liegt irgendwann aus" % special_id)
	for catalyst_id in Pack.catalyst_ids():
		if Pack.catalyst_secret_only(catalyst_id):
			assert_false(seen.has(catalyst_id), "%s nur im Schwarzmarkt" % catalyst_id)
		else:
			assert_true(seen.has(catalyst_id), "%s liegt irgendwann aus" % catalyst_id)
	for op_id: String in StampNet.OPERATOR_IDS:
		assert_true(seen.has(op_id), "%s liegt irgendwann aus" % op_id)

# --- Die Katalysator-Kassetten -------------------------------------------------

func test_every_catalyst_is_a_named_sonderbestand_card() -> void:
	assert_eq(Pack.catalyst_ids().size(), 5, "fuenf Karten, nicht mehr")
	for id in Pack.catalyst_ids():
		var pack := Pack.catalyst(id)
		assert_not_null(pack, "%s baut sich" % id)
		assert_true(pack.is_catalyst())
		assert_eq(pack.catalyst_id, id)
		assert_ne(pack.display_name, "", "%s hat einen Namen" % id)
		assert_gt(pack.price, 0, "%s hat einen Preis" % id)
		assert_eq(Pack.shelf_of(pack), Pack.SHELF_SPECIAL,
			"%s liegt im Sonderbestand" % id)
		assert_true(pack.description.contains(Pack.catalyst_effect(id)),
			"die Wirkung steht auf der Karte")
		assert_true(pack.description.contains("verbraucht"),
			"und dass sie beim Prägen verbraucht wird")

func test_the_catalyst_prices_are_the_authored_ones() -> void:
	assert_eq(Pack.catalyst_price(Pack.CATALYST_PROPELLANT), 14)
	assert_eq(Pack.catalyst_price(Pack.CATALYST_COOL), 10)
	assert_eq(Pack.catalyst_price(Pack.CATALYST_CHILL), 18)
	assert_eq(Pack.catalyst_price(Pack.CATALYST_GROUND), 8)
	assert_eq(Pack.catalyst_price(Pack.CATALYST_REPAIR), 30)

## Die Reparatur-Karte ist Schwarzmarkt-Ware und die einzige ihrer Art.
func test_the_repair_card_is_secret_only() -> void:
	for id in Pack.catalyst_ids():
		assert_eq(Pack.catalyst_secret_only(id), id == Pack.CATALYST_REPAIR, id)
	assert_true(Pack.catalyst(Pack.CATALYST_REPAIR).is_repair())
	assert_false(Pack.catalyst(Pack.CATALYST_GROUND).is_repair())
	assert_false(Pack.SPECIAL_ROLL_WEIGHTS.has(Pack.CATALYST_REPAIR), "nie im Regal")

func test_an_unknown_catalyst_builds_nothing() -> void:
	assert_null(Pack.catalyst("gibtsnicht"), "lieber keine Karte als eine namenlose")

## Ein Katalysator wirft nichts aus - also trägt er auch keine Größe.
func test_a_catalyst_is_never_tierable() -> void:
	for id in Pack.catalyst_ids():
		var pack := Pack.catalyst(id)
		assert_false(Pack.tierable(pack))
		var before := pack.display_name
		Pack.tiered(pack, Pack.TIER_KOLOSSAL)
		assert_eq(pack.tier, Pack.TIER_NORMAL, "die Größe bleibt draußen")
		assert_eq(pack.display_name, before, "und der Name unangetastet")

func test_a_catalyst_carries_no_engraving() -> void:
	var pack := Pack.catalyst(Pack.CATALYST_GROUND)
	assert_null(pack.fixed_engraving, "der Sonderbestand hat zwei Familien")
	assert_ne(pack.catalyst_id, "")

## Die Gewichtstabelle IST die Regel: Gravur 30, je 10 für jeden Katalysator des
## Regals und jeden Operator.
func test_the_special_roll_weights_are_the_documented_table() -> void:
	assert_eq(int(Pack.SPECIAL_ROLL_WEIGHTS[Pack.SPECIAL_ENGRAVING]), 30)
	var rest := 0
	for id in Pack.catalyst_ids() + StampNet.OPERATOR_IDS:
		if Pack.catalyst_secret_only(id):
			continue
		assert_eq(int(Pack.SPECIAL_ROLL_WEIGHTS[id]), 10, "%s" % id)
		rest += int(Pack.SPECIAL_ROLL_WEIGHTS[id])
	assert_eq(rest, 70, "vier Katalysatoren und drei Operatoren")

# --- Die KÜHL-Karten ------------------------------------------------------------

func test_the_cooling_cards_tend_the_die_and_are_shop_goods() -> void:
	for id in [Pack.CATALYST_COOL, Pack.CATALYST_CHILL]:
		var pack := Pack.catalyst(id)
		assert_true(pack.is_cooling(), id)
		assert_true(pack.tends_die(), id)
		assert_false(Pack.catalyst_secret_only(id), "auch im Laden")
		assert_true(Pack.SPECIAL_ROLL_WEIGHTS.has(id), "als Sonderposten")
	assert_true(Pack.catalyst(Pack.CATALYST_REPAIR).tends_die())
	assert_false(Pack.catalyst(Pack.CATALYST_PROPELLANT).tends_die())

# --- Das MULTIPLIKATOR-NETZ -----------------------------------------------------

func test_the_multiplier_factor_and_faces_follow_the_size() -> void:
	var rng := RandomNumberGenerator.new()
	var spans := {Pack.TIER_NORMAL: [2, 1, 2], Pack.TIER_GROSS: [3, 1, 2],
		Pack.TIER_KOLOSSAL: [4, 1, 3]}
	for tier: int in spans:
		var rule: Array = spans[tier]
		for seed_value in 40:
			rng.seed = seed_value
			var pack := Pack.tiered(Pack.multiplier_pack(rng), tier, rng)
			assert_true(pack.is_multiplier())
			assert_eq(StampNet.top_factor(pack.stamp_net), int(rule[0]))
			var cells := StampNet.filled_count(pack.stamp_net)
			assert_between(cells, int(rule[1]), int(rule[2]))

func test_the_multiplier_is_a_number_card_priced_above_one() -> void:
	var pack := Pack.multiplier_pack()
	assert_eq(Pack.shelf_of(pack), Engraving.CATEGORY_NUMBER, "liegt im Zahlen-Tablett")
	assert_gt(pack.price, Pack.NUMBER_PRICE)
	assert_false(Pack.number_pack().is_multiplier())
	assert_true(Pack.net_line(pack).begins_with("×2"))

func test_the_shop_roll_turns_number_cards_into_multipliers_on_demand() -> void:
	var always := 0
	var never := 0
	for i in 60:
		var pack := Pack.roll_engraving_pack(Pack.TIER_NORMAL, null, 1.0)
		if pack.type == Pack.TYPE_NUMBER:
			assert_true(pack.is_multiplier(), "Chance 1 macht jede Zahlen-Karte lila")
			always += 1
		if Pack.roll_engraving_pack().is_multiplier():
			never += 1
	assert_gt(always, 0)
	assert_eq(never, 0, "ohne Chance bleibt das Regal grün")

# --- Die drei Paketgrößen -------------------------------------------------------

func test_a_fresh_pack_is_a_standard_one() -> void:
	for pack in Pack.all_engraving_packs():
		assert_eq(pack.tier, Pack.TIER_NORMAL, "%s ist der Normalfall" % pack.type)
		assert_false(pack.display_name.begins_with("Groß"), "und trägt kein Adjektiv")

func test_the_size_stands_in_the_name() -> void:
	assert_eq(Pack.tiered(Pack.number_pack(), Pack.TIER_GROSS).display_name,
		"Großes Zahlen-Paket")
	assert_eq(Pack.tiered(Pack.material_pack(), Pack.TIER_KOLOSSAL).display_name,
		"Kolossales Material-Paket")
	assert_eq(Pack.tiered(Pack.dice_mod_pack(), Pack.TIER_NORMAL).display_name,
		"Runen-Paket", "der Standard bleibt unmarkiert")

func test_the_price_climbs_with_the_size() -> void:
	assert_eq(Pack.tiered(Pack.number_pack(), Pack.TIER_GROSS).price, 17)
	assert_eq(Pack.tiered(Pack.number_pack(), Pack.TIER_KOLOSSAL).price, 29)
	assert_eq(Pack.tiered(Pack.dice_mod_pack(), Pack.TIER_GROSS).price, 24)
	assert_eq(Pack.tiered(Pack.dice_mod_pack(), Pack.TIER_KOLOSSAL).price, 40)

func test_only_pressable_packs_carry_a_size() -> void:
	var catalyst := Pack.catalyst(Pack.CATALYST_GROUND)
	var before := catalyst.display_name
	assert_false(Pack.tierable(catalyst), "ein Katalysator wirft gar nichts aus")
	assert_eq(Pack.tiered(catalyst, Pack.TIER_KOLOSSAL).display_name, before)
	assert_eq(catalyst.tier, Pack.TIER_NORMAL)
	var fixed := Pack.fixed_engraving_pack(Engraving.pointer_engraving())
	assert_false(Pack.tierable(fixed), "ein Fixinhalt würfelt nichts aus")
	assert_eq(Pack.tiered(fixed, Pack.TIER_GROSS).tier, Pack.TIER_NORMAL)
	var op := Pack.operator_pack(StampNet.OP_DOUBLER)
	assert_false(Pack.tierable(op), "ein Operator trägt genau eine Zelle")
	assert_eq(Pack.tiered(op, Pack.TIER_GROSS).tier, Pack.TIER_NORMAL)

func test_the_size_weights_are_sixty_thirty_ten() -> void:
	assert_eq(Pack.TIER_WEIGHTS, [0.6, 0.3, 0.1])
	var sum := 0.0
	for weight in Pack.TIER_WEIGHTS:
		sum += float(weight)
	assert_almost_eq(sum, 1.0, 0.0001, "die Gewichte schließen die Verteilung")

func test_the_roll_hands_out_every_size_and_prefers_the_norm() -> void:
	var seen := {}
	for i in 400:
		seen[Pack.roll_tier()] = int(seen.get(Pack.roll_tier(), 0)) + 1
	for tier in [Pack.TIER_NORMAL, Pack.TIER_GROSS, Pack.TIER_KOLOSSAL]:
		assert_true(seen.has(tier), "Größe %d fällt überhaupt" % tier)

func test_the_shop_roll_carries_the_size_through() -> void:
	var pack := Pack.roll_engraving_pack(Pack.TIER_KOLOSSAL)
	assert_eq(pack.tier, Pack.TIER_KOLOSSAL)
	assert_true(pack.display_name.begins_with("Kolossales"))
	assert_eq(Pack.roll_engraving_pack().tier, Pack.TIER_NORMAL,
		"ohne Angabe prägt jede Quelle Standard")

## Die Netz-Zeile liest das Netz der KARTE, nie eine zweite Tabelle.
func test_the_net_line_reads_the_card() -> void:
	var pack := Pack.number_pack()
	assert_eq(Pack.net_line(pack), StampNet.line(pack.stamp_net))
	assert_eq(Pack.net_line(Pack.catalyst(Pack.CATALYST_GROUND)),
		Pack.catalyst_effect(Pack.CATALYST_GROUND), "ein Katalysator nennt seine Wirkung")
	assert_eq(Pack.net_line(Pack.operator_pack(StampNet.OP_MIRROR)),
		StampNet.operator_name(StampNet.OP_MIRROR))
