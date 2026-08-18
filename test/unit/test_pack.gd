extends GutTest
## Tests der Paket-Datenklasse: ein Gravur-Paket ist EIN Phantomwürfel, die Sorte
## bildet auf eine Gravur-Kategorie ab, Würfel-Pakete folgen ihrer DiceOffer-Vorlage.

func test_engraving_packs_map_to_their_category() -> void:
	assert_eq(Pack.number_pack().engraving_category(), Engraving.CATEGORY_NUMBER)
	assert_eq(Pack.material_pack().engraving_category(), Engraving.CATEGORY_MATERIAL)
	assert_eq(Pack.dice_mod_pack().engraving_category(), Engraving.CATEGORY_DICE)
	assert_eq(Pack.dice_pack(DiceOffer.TEMPLATES[0]).engraving_category(), "",
		"Würfel-Pakete haben keine Gravur-Kategorie")

func test_every_engraving_pack_is_exactly_one_phantom_die() -> void:
	for pack in Pack.all_engraving_packs():
		assert_eq(pack.count, Pack.ENGRAVING_PACK_COUNT, "%s wirft genau einen" % pack.type)
		assert_eq(pack.count, 1)

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
	assert_eq(Pack.fixed_engraving_pack(Engraving.notch()).type, Pack.TYPE_NUMBER)
	assert_eq(Pack.fixed_engraving_pack(Engraving.pointer_engraving()).type, Pack.TYPE_DICE_MOD)
	assert_eq(Pack.pack_type_for_category(Engraving.CATEGORY_DICE), Pack.TYPE_DICE_MOD)

func test_press_sort_is_the_engraving_category() -> void:
	assert_eq(Pack.number_pack().press_sort(), Engraving.CATEGORY_NUMBER)
	assert_eq(Pack.dice_mod_pack().press_sort(), Engraving.CATEGORY_DICE)
	assert_eq(Pack.dice_pack(DiceOffer.TEMPLATES[0]).press_sort(), "")

# --- Würfel-Pakete ------------------------------------------------------------

func test_dice_pack_follows_its_template() -> void:
	# "Ungerade Würfel": 2 Würfel, nur ungerade Augen.
	var template: Dictionary = DiceOffer.TEMPLATES[3]
	var pack := Pack.dice_pack(template)
	assert_eq(pack.count, int(template["count"]))
	assert_eq(pack.template_id, template["style_id"])
	var dice := pack.roll_dice()
	assert_eq(dice.size(), int(template["count"]))
	for die in dice:
		assert_eq(die.style_id, template["style_id"])
		for face in die.faces:
			assert_true([1, 3, 5].has(face), "nur Augen der Vorlage")

func test_dice_pack_contents_are_independent_copies() -> void:
	var dice := Pack.dice_pack(DiceOffer.TEMPLATES[4]).roll_dice()
	assert_gt(dice.size(), 1, "Vorlage liefert ein Bündel")
	dice[0].faces[0] = 6
	assert_ne(dice[1].faces[0], 6, "Kopien teilen keine Seiten")

func test_engraving_packs_roll_no_dice() -> void:
	for pack in Pack.all_engraving_packs():
		assert_eq(pack.roll_dice().size(), 0)

# --- Sonderposten: Einzelstueck im Regal, Buendel im Hinterzimmer --------------

func test_a_fixed_pack_holds_one_piece_by_default() -> void:
	var pack := Pack.fixed_engraving_pack(Engraving.doping())
	assert_eq(pack.count, Pack.ENGRAVING_PACK_COUNT)
	assert_eq(pack.price, 0, "gefunden oder abgegossen wird gratis")
	assert_eq(pack.fixed_engraving.id, Engraving.DOPING)
	assert_eq(pack.type, Pack.TYPE_MATERIAL, "die Kategorie entscheidet die Sorte")

## Ein Bündel ist EINE Karte mit n Stücken - nicht n Karten.
func test_a_bundle_is_one_card_with_several_pieces() -> void:
	var pack := Pack.fixed_engraving_pack(Engraving.pointer_engraving(), 5, 10)
	assert_eq(pack.count, 5)
	assert_eq(pack.price, 10)
	assert_eq(pack.fixed_engraving.id, Engraving.POINTER)
	assert_true(pack.description.contains("5×"), "die Menge steht auf der Karte")
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
		assert_not_null(pack.fixed_engraving)
		assert_true(Engraving.is_special_id(pack.fixed_engraving.id),
			"im Regal liegen nur Sonderposten: %s" % pack.fixed_engraving.id)
		assert_eq(pack.price, Pack.SPECIAL_PRICE, "ein Sonderposten kostet immer dasselbe")

## Über viele Würfe kommen BEIDE Sonderposten und ALLE VIER Katalysatoren vor -
## sonst wäre einer unerreichbar.
func test_both_specials_reach_the_shelf() -> void:
	var seen := {}
	for i in 400:
		var pack := Pack.roll_special_pack()
		seen[pack.catalyst_id if pack.is_catalyst() else pack.fixed_engraving.id] = true
	for special_id: String in Engraving.SPECIAL_IDS:
		assert_true(seen.has(special_id), "%s liegt irgendwann aus" % special_id)
	for catalyst_id in Pack.catalyst_ids():
		assert_true(seen.has(catalyst_id), "%s liegt irgendwann aus" % catalyst_id)

# --- Die Katalysator-Kassetten -------------------------------------------------

func test_every_catalyst_is_a_named_sonderbestand_card() -> void:
	assert_eq(Pack.catalyst_ids().size(), 4, "vier Karten, nicht mehr")
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
			"und dass sie mit ihrer Pressung verbraucht wird")

func test_the_catalyst_prices_are_the_authored_ones() -> void:
	assert_eq(Pack.catalyst_price(Pack.CATALYST_PROPELLANT), 14)
	assert_eq(Pack.catalyst_price(Pack.CATALYST_TIMER), 14)
	assert_eq(Pack.catalyst_price(Pack.CATALYST_MATRIX), 18)
	assert_eq(Pack.catalyst_price(Pack.CATALYST_GROUND), 8)

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

func test_a_catalyst_is_no_dice_pack_and_carries_no_engraving() -> void:
	var pack := Pack.catalyst(Pack.CATALYST_MATRIX)
	assert_false(pack.is_dice_pack())
	assert_null(pack.fixed_engraving, "der Sonderbestand hat zwei Familien")
	assert_eq(pack.roll_dice().size(), 0)

## Die Gewichtstabelle IST die Regel: 40 % Gravur, der Rest gleichmäßig auf die
## vier Karten.
func test_the_special_roll_weights_are_the_documented_table() -> void:
	assert_eq(int(Pack.SPECIAL_ROLL_WEIGHTS[Pack.SPECIAL_ENGRAVING]), 40)
	var rest := 0
	for id in Pack.catalyst_ids():
		assert_eq(int(Pack.SPECIAL_ROLL_WEIGHTS[id]), 15)
		rest += int(Pack.SPECIAL_ROLL_WEIGHTS[id])
	assert_eq(rest, 60, "und zusammen genau der Rest")

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

## Der Aufschlag liegt ÜBER dem Zuwachs an Stücken: gekauft wird Dichte, nicht
## ein Rabatt auf die Beute.
func test_the_price_factor_stays_above_the_piece_gain() -> void:
	var base := PhantomPress.expected_pieces(Pack.TIER_NORMAL)
	for tier in [Pack.TIER_GROSS, Pack.TIER_KOLOSSAL]:
		var pieces := PhantomPress.expected_pieces(tier) / base
		assert_gt(Pack.tier_price_factor(tier), pieces,
			"Größe %d kostet mehr, als sie an Stücken zulegt" % tier)
		# ... und zwar gleichmäßig: der Aufschlag ist derselbe, nicht mal so, mal so.
		assert_almost_eq(Pack.tier_price_factor(tier) / pieces, 1.15, 0.01,
			"Größe %d trägt denselben Dichte-Aufschlag" % tier)

func test_only_pressable_packs_carry_a_size() -> void:
	var dice := Pack.dice_pack(DiceOffer.TEMPLATES[0])
	var before := dice.display_name
	assert_false(Pack.tierable(dice), "ein Würfel-Paket presst nie")
	assert_eq(Pack.tiered(dice, Pack.TIER_KOLOSSAL).display_name, before)
	assert_eq(dice.tier, Pack.TIER_NORMAL)
	var fixed := Pack.fixed_engraving_pack(Engraving.pointer_engraving())
	assert_false(Pack.tierable(fixed), "ein Fixinhalt würfelt nichts aus")
	assert_eq(Pack.tiered(fixed, Pack.TIER_GROSS).tier, Pack.TIER_NORMAL)

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

func test_the_multicast_line_reads_the_one_table() -> void:
	assert_eq(Pack.multicast_line(Pack.TIER_NORMAL),
		"1 Gravur je Auslösung, Multicast 50 %, max. ×3")
	assert_eq(Pack.multicast_line(Pack.TIER_GROSS),
		"3 Gravuren je Auslösung, Multicast 50 %, max. ×3")
	assert_eq(Pack.multicast_line(Pack.TIER_KOLOSSAL),
		"5 Gravuren je Auslösung, Multicast 50 %, max. ×3")

## Chance und Decke kommen von außen - die Karte nennt, was die Presse JETZT kann.
func test_the_multicast_line_takes_the_live_values() -> void:
	assert_eq(Pack.multicast_line(Pack.TIER_GROSS, 0.75, 7),
		"3 Gravuren je Auslösung, Multicast 75 %, max. ×7")
	var run := GameRun.new_run()
	run.hub_level = 10
	assert_eq(Pack.multicast_line(Pack.TIER_NORMAL, run.multicast_chance(), run.multicast_cap()),
		"1 Gravur je Auslösung, Multicast 75 %, max. ×7")
