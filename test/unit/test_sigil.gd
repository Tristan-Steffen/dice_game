extends GutTest
## Tier-1-Tests des Sigill-Datensatzes (Kategorien, Materialien, Ziehung).

func test_all_returns_etchings_materials_and_edges():
	# 13 Ätzungen + 6 Material-Sigille + 6 Kanten-Sigille (siehe DieMaterial.all).
	assert_eq(Sigil.all().size(), 25)

func test_all_ids_are_unique():
	var seen := {}
	for sigil in Sigil.all():
		assert_false(seen.has(sigil.id), "doppelte id: %s" % sigil.id)
		seen[sigil.id] = true

func test_every_sigil_has_filled_metadata():
	for sigil in Sigil.all():
		assert_ne(sigil.id, "", "id fehlt")
		assert_ne(sigil.display_name, "", "display_name fehlt bei %s" % sigil.id)
		assert_ne(sigil.description, "", "description fehlt bei %s" % sigil.id)
		assert_true(sigil.category in [Sigil.CATEGORY_NUMBER, Sigil.CATEGORY_MATERIAL, Sigil.CATEGORY_DICE],
			"bekannter kind bei %s" % sigil.id)

func test_material_sigils_use_the_material_id():
	# Die Sigil-id eines Material-Sigille IST die Material-id - so löst die
	# Gravur-Station die Anwendung direkt über DieMaterial auf.
	var material_ids := {}
	for sigil in Sigil.all():
		if sigil.category == Sigil.CATEGORY_MATERIAL:
			assert_true(DieMaterial.is_valid_id(sigil.id), "%s ist eine Material-id" % sigil.id)
			material_ids[sigil.id] = true
	assert_eq(material_ids.size(), DieMaterial.all().size(), "je Material genau ein Sigil")

func test_material_sigils_have_footprints():
	for sigil in Sigil.all():
		if sigil.category == Sigil.CATEGORY_MATERIAL:
			assert_true(sigil.width >= 1 and sigil.height >= 1)
			assert_true(Sigil.FOOTPRINT.has(sigil.id), "Fläche definiert für %s" % sigil.id)

func test_factory_id_matches_constant():
	assert_eq(Sigil.chisel().id, Sigil.CHISEL)
	assert_eq(Sigil.overcount_engraving().id, Sigil.OVERCOUNT_ENGRAVING)
	assert_eq(Sigil.file_down().id, Sigil.FILE_DOWN)
	assert_eq(Sigil.blueprint().id, Sigil.BLUEPRINT)

func test_rarities_match_the_spec():
	assert_eq(Sigil.chisel().rarity, Sigil.Rarity.COMMON)
	assert_eq(Sigil.transplant().rarity, Sigil.Rarity.COMMON)
	assert_eq(Sigil.grindstone().rarity, Sigil.Rarity.COMMON)
	assert_eq(Sigil.fine_engraving().rarity, Sigil.Rarity.UNCOMMON)
	assert_eq(Sigil.overcount_engraving().rarity, Sigil.Rarity.RARE)
	assert_eq(Sigil.file_down().rarity, Sigil.Rarity.COMMON)
	assert_eq(Sigil.double_notch().rarity, Sigil.Rarity.COMMON)
	assert_eq(Sigil.averaging().rarity, Sigil.Rarity.UNCOMMON)
	assert_eq(Sigil.blueprint().rarity, Sigil.Rarity.RARE)

func test_edge_sigils_use_prefixed_material_ids():
	# Kanten-Sigil-id = EDGE_PREFIX + Material-id; material_id() löst zurück auf.
	var edge_ids := {}
	for sigil in Sigil.all():
		if sigil.category == Sigil.CATEGORY_DICE:
			assert_true(Sigil.is_edge_id(sigil.id), "%s ist eine Kanten-id" % sigil.id)
			assert_true(DieMaterial.is_valid_id(sigil.material_id()), "%s löst auf ein Material auf" % sigil.id)
			assert_true(Sigil.FOOTPRINT.has(sigil.id), "Fläche definiert für %s" % sigil.id)
			edge_ids[sigil.id] = true
	assert_eq(edge_ids.size(), DieMaterial.all().size(), "je Material genau ein Kanten-Sigil")

func test_is_edge_id_rejects_non_edges():
	assert_false(Sigil.is_edge_id(DieMaterial.GOLD), "Seiten-Material ist kein Kanten-Sigil")
	assert_false(Sigil.is_edge_id(Sigil.CHISEL), "Ätzung ist kein Kanten-Sigil")
	assert_false(Sigil.is_edge_id("edge_unobtainium"), "unbekanntes Material zählt nicht")

func test_material_id_resolution_per_kind():
	assert_eq(Sigil.material_sigil(DieMaterial.gold(), Sigil.Rarity.COMMON).material_id(), DieMaterial.GOLD)
	assert_eq(Sigil.edge_sigil(DieMaterial.gold(), Sigil.Rarity.UNCOMMON).material_id(), DieMaterial.GOLD)
	assert_eq(Sigil.chisel().material_id(), "", "Ätzungen haben kein Material")

func test_edge_sigils_are_rarer_than_their_face_variant():
	for material in DieMaterial.all():
		var face_rarity: int = Sigil.MATERIAL_RARITY.get(material.id, Sigil.Rarity.UNCOMMON)
		var edge_rarity: int = Sigil.EDGE_RARITY.get(material.id, Sigil.Rarity.RARE)
		assert_true(edge_rarity >= face_rarity, "%s-Kanten mindestens so selten wie die Seite" % material.id)

func test_all_categories_are_inventory_kinds():
	# Nach dem Wegfall der Menü-Sigille sind alle Archetypen inventarfähig.
	for sigil in Sigil.all():
		assert_true(Sigil.DRAFT_CATEGORIES.has(sigil.category), "%s ist inventarfähig" % sigil.id)

func test_rarity_name_is_german():
	assert_eq(Sigil.rarity_name(Sigil.Rarity.COMMON), "häufig")
	assert_eq(Sigil.rarity_name(Sigil.Rarity.UNCOMMON), "ungewöhnlich")
	assert_eq(Sigil.rarity_name(Sigil.Rarity.RARE), "selten")

# --- Lichtgravur-Ziehung -----------------------------------------------------

func test_roll_draft_returns_distinct_inventory_sigils():
	var draft := Sigil.roll_draft(3, Sigil.Rarity.COMMON)
	assert_eq(draft.size(), 3, "drei Siegel")
	var seen := {}
	for sigil in draft:
		assert_true(Sigil.DRAFT_CATEGORIES.has(sigil.category), "nur inventarfähige Sorten (keine Menüs)")
		assert_false(seen.has(sigil.id), "keine Dubletten: %s" % sigil.id)
		seen[sigil.id] = true

func test_roll_draft_respects_rarity_floor():
	for i in 20:
		for sigil in Sigil.roll_draft(3, Sigil.Rarity.UNCOMMON):
			assert_true(sigil.rarity >= Sigil.Rarity.UNCOMMON, "kein häufiges Siegel unter der Grenze")

func test_roll_draft_lowers_floor_when_pool_too_small():
	# Mehr Siegel verlangt als es seltene gibt (7) -> die Untergrenze fällt,
	# damit die Auslage voll wird (statt leer zu bleiben).
	var draft := Sigil.roll_draft(9, Sigil.Rarity.RARE)
	assert_eq(draft.size(), 9, "Auslage voll trotz knapper seltener Siegel")

func test_roll_in_category_stays_in_category():
	for category in Sigil.CATEGORIES:
		var offers := Sigil.roll_in_category(category, 2)
		assert_eq(offers.size(), 2, "zwei Angebote je Kategorie")
		var seen := {}
		for sigil in offers:
			assert_eq(sigil.category, category, "bleibt in der Kategorie")
			assert_false(seen.has(sigil.id), "keine Dubletten: %s" % sigil.id)
			seen[sigil.id] = true
