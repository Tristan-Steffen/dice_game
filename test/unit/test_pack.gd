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
