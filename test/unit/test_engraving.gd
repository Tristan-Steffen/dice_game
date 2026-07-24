extends GutTest
## Tier-1-Tests des Gravur-Datensatzes (Kategorien, Materialien, Ziehung).

func test_all_returns_etchings_materials_and_edges():
	# 10 Ätzungen + 6 Material-Gravuren + 6 Kanten-Gravuren (siehe DieMaterial.all).
	assert_eq(Engraving.all().size(), 22)

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
	# Gravur-Station die Anwendung direkt über DieMaterial auf.
	var material_ids := {}
	for engraving in Engraving.all():
		if engraving.category == Engraving.CATEGORY_MATERIAL:
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

func test_edge_engravings_use_prefixed_material_ids():
	# Kanten-Engraving-id = EDGE_PREFIX + Material-id; material_id() löst zurück auf.
	var edge_ids := {}
	for engraving in Engraving.all():
		if engraving.category == Engraving.CATEGORY_DICE:
			assert_true(Engraving.is_edge_id(engraving.id), "%s ist eine Kanten-id" % engraving.id)
			assert_true(DieMaterial.is_valid_id(engraving.material_id()), "%s löst auf ein Material auf" % engraving.id)
			assert_true(Engraving.FOOTPRINT.has(engraving.id), "Fläche definiert für %s" % engraving.id)
			edge_ids[engraving.id] = true
	assert_eq(edge_ids.size(), DieMaterial.all().size(), "je Material genau ein Kanten-Engraving")

func test_is_edge_id_rejects_non_edges():
	assert_false(Engraving.is_edge_id(DieMaterial.GOLD), "Seiten-Material ist kein Kanten-Engraving")
	assert_false(Engraving.is_edge_id(Engraving.CHISEL), "Ätzung ist kein Kanten-Engraving")
	assert_false(Engraving.is_edge_id("edge_unobtainium"), "unbekanntes Material zählt nicht")

func test_material_id_resolution_per_kind():
	assert_eq(Engraving.material_engraving(DieMaterial.gold(), Engraving.Rarity.COMMON).material_id(), DieMaterial.GOLD)
	assert_eq(Engraving.edge_engraving(DieMaterial.gold(), Engraving.Rarity.UNCOMMON).material_id(), DieMaterial.GOLD)
	assert_eq(Engraving.chisel().material_id(), "", "Ätzungen haben kein Material")

func test_edge_engravings_are_rarer_than_their_face_variant():
	for material in DieMaterial.all():
		var face_rarity: int = Engraving.MATERIAL_RARITY.get(material.id, Engraving.Rarity.UNCOMMON)
		var edge_rarity: int = Engraving.EDGE_RARITY.get(material.id, Engraving.Rarity.RARE)
		assert_true(edge_rarity >= face_rarity, "%s-Kanten mindestens so selten wie die Seite" % material.id)

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
