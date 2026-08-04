extends GutTest
## Tests der Paket-Datenklasse: Sorten bilden auf Gravur-Kategorien ab, der
## Inhalt wird beim Öffnen gezogen, Würfel-Pakete folgen ihrer DiceOffer-Vorlage.

func test_engraving_packs_map_to_their_category() -> void:
	assert_eq(Pack.number_pack().engraving_category(), Engraving.CATEGORY_NUMBER)
	assert_eq(Pack.material_pack().engraving_category(), Engraving.CATEGORY_MATERIAL)
	assert_eq(Pack.dice_mod_pack().engraving_category(), Engraving.CATEGORY_DICE)
	assert_eq(Pack.dice_pack(DiceOffer.TEMPLATES[0]).engraving_category(), "",
		"Würfel-Pakete haben keine Gravur-Kategorie")

func test_dice_mod_pack_is_a_slot_only_prize() -> void:
	var pack := Pack.dice_mod_pack()
	assert_eq(pack.price, 0, "reiner Automaten-Gewinn")
	assert_false(Pack.SHELF_WEIGHTS.has(Pack.TYPE_DICE_MOD), "und darum ohne Auslage-Gewicht")
	assert_eq(Pack.by_type(Pack.TYPE_DICE_MOD).type, Pack.TYPE_DICE_MOD, "über die Typ-id baubar")

func test_dice_mod_pack_rolls_dice_engravings() -> void:
	var contents := Pack.dice_mod_pack().roll_engravings()
	assert_eq(contents.size(), Pack.DICE_MOD_COUNT)
	for engraving in contents:
		assert_eq(engraving.category, Engraving.CATEGORY_DICE)

func test_pack_carries_its_own_rarity_floor() -> void:
	var pack := Pack.dice_mod_pack()
	assert_eq(pack.rarity_floor, Engraving.Rarity.COMMON, "ohne Prägung die Untergrenze aller")
	# Die Untergrenze gewichtet, sie schließt nicht aus: gemessen wird die Mischung.
	var high := 0
	var low := 0
	for i in 100:
		for engraving in pack.roll_engravings(Engraving.Rarity.RARE):
			if engraving.rarity >= Engraving.Rarity.RARE:
				high += 1
			else:
				low += 1
	assert_gt(high, low, "die hohe Untergrenze verschiebt den Inhalt nach oben")

func test_engraving_pack_rolls_its_count_in_category() -> void:
	var pack := Pack.material_pack()
	var contents := pack.roll_engravings()
	assert_eq(contents.size(), Pack.MATERIAL_COUNT)
	for engraving in contents:
		assert_eq(engraving.category, Engraving.CATEGORY_MATERIAL)

func test_mixed_pack_rolls_across_all_categories() -> void:
	var pack := Pack.mixed_pack()
	assert_eq(pack.engraving_category(), "", "gemischt hat keine EINE Kategorie")
	var contents := pack.roll_engravings()
	assert_eq(contents.size(), Pack.MIXED_COUNT)
	for engraving in contents:
		assert_true(Engraving.CATEGORIES.has(engraving.category), "jedes Stück aus einer echten Kategorie")

func test_mixed_pack_can_contain_more_than_one_category() -> void:
	# Bei 6/3/1-Gewichten je Stück ist EIN Sortiment aus nur einer Kategorie über
	# 60 Ziehungen praktisch ausgeschlossen.
	var seen: Array[String] = []
	for i in 15:
		for engraving in Pack.mixed_pack().roll_engravings():
			if not seen.has(engraving.category):
				seen.append(engraving.category)
	assert_gt(seen.size(), 1, "gemischt heißt gemischt")

func test_mixed_packs_appear_on_the_shelf() -> void:
	var seen := false
	for i in 200:
		if Pack.roll_engraving_pack(1).type == Pack.TYPE_MIXED:
			seen = true
	assert_true(seen, "gemischte Pakete liegen (auch früh) in der Auslage")

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

func test_dice_pack_rolls_no_engravings() -> void:
	assert_eq(Pack.dice_pack(DiceOffer.TEMPLATES[0]).roll_engravings().size(), 0)

