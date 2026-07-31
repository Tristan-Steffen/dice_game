extends GutTest
## Tier-1-Tests des Gravur-Datensatzes (Kategorien, Materialien, Ziehung).

func test_all_returns_etchings_materials_and_rifts():
	# 10 Ätzungen + Leiterbahn + Dotierung + 5 Material-Gravuren + 4 Bruchmuster.
	assert_eq(Engraving.all().size(), 21)

func test_no_engraving_targets_the_edges_anymore():
	# Die Kanten sind als Ausbau-Slot gestrichen - es gibt keine Gravur mehr,
	# die den ganzen Würfel überzieht. Die Würfel-Kategorie füllen jetzt die
	# Bruchmuster neben der Leiterbahn.
	for engraving in Engraving.all():
		assert_false(engraving.id.begins_with("edge_"), "keine Kanten-Gravur mehr: %s" % engraving.id)
	var dice_ids: Array[String] = []
	for engraving in Engraving.all():
		if engraving.category == Engraving.CATEGORY_DICE:
			dice_ids.append(engraving.id)
	assert_eq(dice_ids.size(), 5, "Leiterbahn + vier Bruchmuster")
	assert_true(dice_ids.has(Engraving.POINTER))
	for rift in Rift.all():
		assert_true(dice_ids.has(Engraving.BREAK_PREFIX + rift.id), "Bruchmuster für %s" % rift.id)

func test_all_ids_are_unique():
	var seen := {}
	for engraving in Engraving.all():
		assert_false(seen.has(engraving.id), "doppelte id: %s" % engraving.id)
		seen[engraving.id] = true

func test_every_engraving_has_filled_metadata():
	for engraving in Engraving.all():
		assert_ne(engraving.id, "", "id fehlt")
		assert_ne(engraving.display_name, "", "display_name fehlt bei %s" % engraving.id)
		assert_ne(engraving.description, "", "description fehlt bei %s" % engraving.id)
		assert_true(engraving.category in [Engraving.CATEGORY_NUMBER, Engraving.CATEGORY_MATERIAL, Engraving.CATEGORY_DICE],
			"bekannter kind bei %s" % engraving.id)

func test_material_engravings_use_the_material_id():
	# Die Engraving-id eines Material-Gravuren IST die Material-id - so löst die
	# Gravur-Station die Anwendung direkt über DieMaterial auf. Sonderposten
	# (Dotierung) behalten nur die Kategorie und belegen kein Material.
	var material_ids := {}
	for engraving in Engraving.all():
		if engraving.category == Engraving.CATEGORY_MATERIAL and not Engraving.is_special_id(engraving.id):
			assert_true(DieMaterial.is_valid_id(engraving.id), "%s ist eine Material-id" % engraving.id)
			material_ids[engraving.id] = true
	assert_eq(material_ids.size(), DieMaterial.all().size(), "je Material genau ein Engraving")

func test_material_engravings_have_footprints():
	for engraving in Engraving.all():
		if engraving.category == Engraving.CATEGORY_MATERIAL:
			assert_true(engraving.width >= 1 and engraving.height >= 1)
			assert_true(Engraving.FOOTPRINT.has(engraving.id), "Fläche definiert für %s" % engraving.id)

func test_factory_id_matches_constant():
	assert_eq(Engraving.chisel().id, Engraving.CHISEL)
	assert_eq(Engraving.notch().id, Engraving.NOTCH)
	assert_eq(Engraving.file_down().id, Engraving.FILE_DOWN)
	assert_eq(Engraving.blueprint().id, Engraving.BLUEPRINT)

func test_rarities_match_the_spec():
	assert_eq(Engraving.notch().rarity, Engraving.Rarity.COMMON)
	assert_eq(Engraving.file_down().rarity, Engraving.Rarity.COMMON)
	assert_eq(Engraving.grindstone().rarity, Engraving.Rarity.COMMON)
	assert_eq(Engraving.averaging().rarity, Engraving.Rarity.UNCOMMON)
	assert_eq(Engraving.polish().rarity, Engraving.Rarity.UNCOMMON)
	assert_eq(Engraving.sandpaper().rarity, Engraving.Rarity.UNCOMMON)
	assert_eq(Engraving.chisel().rarity, Engraving.Rarity.RARE)
	assert_eq(Engraving.punch().rarity, Engraving.Rarity.RARE)
	assert_eq(Engraving.blueprint().rarity, Engraving.Rarity.EPIC)

func test_the_doping_is_an_epic_material_engraving_without_material():
	var doping := Engraving.doping()
	assert_eq(doping.category, Engraving.CATEGORY_MATERIAL)
	assert_eq(doping.rarity, Engraving.Rarity.EPIC)
	assert_eq(doping.material_id(), "", "die Dotierung belegt kein Material, sie hebt eines")
	assert_true(Engraving.is_special_id(Engraving.DOPING), "sie liegt im Sonderbestand")
	assert_true(Engraving.FOOTPRINT.has(Engraving.DOPING))

func test_all_categories_are_inventory_kinds():
	# Nach dem Wegfall der Menü-Gravuren sind alle Archetypen inventarfähig.
	for engraving in Engraving.all():
		assert_true(Engraving.DRAFT_CATEGORIES.has(engraving.category), "%s ist inventarfähig" % engraving.id)

func test_rarity_name_is_german():
	assert_eq(Engraving.rarity_name(Engraving.Rarity.COMMON), "häufig")
	assert_eq(Engraving.rarity_name(Engraving.Rarity.UNCOMMON), "ungewöhnlich")
	assert_eq(Engraving.rarity_name(Engraving.Rarity.RARE), "selten")
	assert_eq(Engraving.rarity_name(Engraving.Rarity.EPIC), "episch")

# --- Lichtgravur-Ziehung -----------------------------------------------------

func test_roll_draft_returns_distinct_inventory_engravings():
	var draft := Engraving.roll_draft(3, Engraving.Rarity.COMMON)
	assert_eq(draft.size(), 3, "drei Siegel")
	var seen := {}
	for engraving in draft:
		assert_true(Engraving.DRAFT_CATEGORIES.has(engraving.category), "nur inventarfähige Sorten (keine Menüs)")
		assert_false(seen.has(engraving.id), "keine Dubletten: %s" % engraving.id)
		seen[engraving.id] = true

func test_roll_draft_respects_rarity_floor():
	for i in 20:
		for engraving in Engraving.roll_draft(3, Engraving.Rarity.UNCOMMON):
			assert_true(engraving.rarity >= Engraving.Rarity.UNCOMMON, "kein häufiges Siegel unter der Grenze")

func test_roll_draft_lowers_floor_when_pool_too_small():
	# Mehr Siegel verlangt als es seltene+ gibt (8) -> die Untergrenze fällt,
	# damit die Auslage voll wird (statt leer zu bleiben).
	var draft := Engraving.roll_draft(9, Engraving.Rarity.RARE)
	assert_eq(draft.size(), 9, "Auslage voll trotz knapper seltener Siegel")

func test_roll_in_category_stays_in_category():
	for category in Engraving.CATEGORIES:
		var offers := Engraving.roll_in_category(category, 2)
		assert_eq(offers.size(), 2, "zwei Angebote je Kategorie")
		var seen := {}
		for engraving in offers:
			assert_eq(engraving.category, category, "bleibt in der Kategorie")
			assert_false(seen.has(engraving.id), "keine Dubletten: %s" % engraving.id)
			seen[engraving.id] = true
