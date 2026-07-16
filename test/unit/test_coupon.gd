extends GutTest
## Tier-1-Tests des Coupon-Datensatzes (die Bogen-Auswürfelung testet
## CouponSheet, siehe scripts/coupon_sheet.gd).

func test_all_returns_etchings_materials_edges_and_meals():
	# 13 Ätzungen + 6 Material-Coupons + 6 Kanten-Coupons + 13 Menü-Coupons
	# (siehe DieMaterial.all / DiceScoring.CATEGORIES).
	assert_eq(Coupon.all().size(), 38)

func test_all_ids_are_unique():
	var seen := {}
	for coupon in Coupon.all():
		assert_false(seen.has(coupon.id), "doppelte id: %s" % coupon.id)
		seen[coupon.id] = true

func test_every_coupon_has_filled_metadata():
	for coupon in Coupon.all():
		assert_ne(coupon.id, "", "id fehlt")
		assert_ne(coupon.display_name, "", "display_name fehlt bei %s" % coupon.id)
		assert_ne(coupon.description, "", "description fehlt bei %s" % coupon.id)
		assert_true(coupon.kind in [Coupon.KIND_ETCHING, Coupon.KIND_MATERIAL, Coupon.KIND_EDGE, Coupon.KIND_MEAL],
			"bekannter kind bei %s" % coupon.id)

func test_material_coupons_use_the_material_id():
	# Die Coupon-id eines Material-Coupons IST die Material-id - so löst die
	# Gravur-Station die Anwendung direkt über DieMaterial auf.
	var material_ids := {}
	for coupon in Coupon.all():
		if coupon.kind == Coupon.KIND_MATERIAL:
			assert_true(DieMaterial.is_valid_id(coupon.id), "%s ist eine Material-id" % coupon.id)
			material_ids[coupon.id] = true
	assert_eq(material_ids.size(), DieMaterial.all().size(), "je Material genau ein Coupon")

func test_material_coupons_have_footprints():
	for coupon in Coupon.all():
		if coupon.kind == Coupon.KIND_MATERIAL:
			assert_true(coupon.width >= 1 and coupon.height >= 1)
			assert_true(Coupon.FOOTPRINT.has(coupon.id), "Fläche definiert für %s" % coupon.id)

func test_factory_id_matches_constant():
	assert_eq(Coupon.chisel().id, Coupon.CHISEL)
	assert_eq(Coupon.overcount_engraving().id, Coupon.OVERCOUNT_ENGRAVING)
	assert_eq(Coupon.file_down().id, Coupon.FILE_DOWN)
	assert_eq(Coupon.blueprint().id, Coupon.BLUEPRINT)

func test_rarities_match_the_spec():
	assert_eq(Coupon.chisel().rarity, Coupon.Rarity.COMMON)
	assert_eq(Coupon.transplant().rarity, Coupon.Rarity.COMMON)
	assert_eq(Coupon.grindstone().rarity, Coupon.Rarity.COMMON)
	assert_eq(Coupon.fine_engraving().rarity, Coupon.Rarity.UNCOMMON)
	assert_eq(Coupon.overcount_engraving().rarity, Coupon.Rarity.RARE)
	assert_eq(Coupon.file_down().rarity, Coupon.Rarity.COMMON)
	assert_eq(Coupon.double_notch().rarity, Coupon.Rarity.COMMON)
	assert_eq(Coupon.averaging().rarity, Coupon.Rarity.UNCOMMON)
	assert_eq(Coupon.blueprint().rarity, Coupon.Rarity.RARE)

func test_edge_coupons_use_prefixed_material_ids():
	# Kanten-Coupon-id = EDGE_PREFIX + Material-id; material_id() löst zurück auf.
	var edge_ids := {}
	for coupon in Coupon.all():
		if coupon.kind == Coupon.KIND_EDGE:
			assert_true(Coupon.is_edge_id(coupon.id), "%s ist eine Kanten-id" % coupon.id)
			assert_true(DieMaterial.is_valid_id(coupon.material_id()), "%s löst auf ein Material auf" % coupon.id)
			assert_true(Coupon.FOOTPRINT.has(coupon.id), "Fläche definiert für %s" % coupon.id)
			edge_ids[coupon.id] = true
	assert_eq(edge_ids.size(), DieMaterial.all().size(), "je Material genau ein Kanten-Coupon")

func test_is_edge_id_rejects_non_edges():
	assert_false(Coupon.is_edge_id(DieMaterial.GOLD), "Seiten-Material ist kein Kanten-Coupon")
	assert_false(Coupon.is_edge_id(Coupon.CHISEL), "Ätzung ist kein Kanten-Coupon")
	assert_false(Coupon.is_edge_id("edge_unobtainium"), "unbekanntes Material zählt nicht")

func test_material_id_resolution_per_kind():
	assert_eq(Coupon.material_coupon(DieMaterial.gold(), Coupon.Rarity.COMMON).material_id(), DieMaterial.GOLD)
	assert_eq(Coupon.edge_coupon(DieMaterial.gold(), Coupon.Rarity.UNCOMMON).material_id(), DieMaterial.GOLD)
	assert_eq(Coupon.chisel().material_id(), "", "Ätzungen haben kein Material")

func test_edge_coupons_are_rarer_than_their_face_variant():
	for material in DieMaterial.all():
		var face_rarity: int = Coupon.MATERIAL_RARITY.get(material.id, Coupon.Rarity.UNCOMMON)
		var edge_rarity: int = Coupon.EDGE_RARITY.get(material.id, Coupon.Rarity.RARE)
		assert_true(edge_rarity >= face_rarity, "%s-Kanten mindestens so selten wie die Seite" % material.id)

func test_meal_coupons_cover_every_combination():
	# Je Kombination genau ein Gericht (siehe MEAL_NAMES); id = MEAL_PREFIX + Key,
	# meal_combo_key() löst zurück auf, Fläche und Motiv-Textur sind registriert.
	var seen := {}
	for coupon in Coupon.all():
		if coupon.kind != Coupon.KIND_MEAL:
			continue
		var key := coupon.meal_combo_key()
		assert_true(DiceScoring.HAND_PRIORITY.has(key), "%s zielt auf eine echte Kombination" % coupon.id)
		assert_false(seen.has(key), "doppeltes Gericht für %s" % key)
		assert_true(Coupon.FOOTPRINT.has(coupon.id), "Fläche definiert für %s" % coupon.id)
		assert_true(ResourceLoader.exists(coupon.texture_path), "Motiv fehlt: %s" % coupon.texture_path)
		seen[key] = true
	assert_eq(seen.size(), DiceScoring.CATEGORIES.size(), "je Kombination genau ein Gericht")

func test_meal_coupon_names_match_the_menu():
	assert_eq(Coupon.meal_coupon(DiceScoring.ONE_KIND).display_name, "Tagessuppe")
	assert_eq(Coupon.meal_coupon(DiceScoring.THREE_KIND).display_name, "Drei im Weggla")
	assert_eq(Coupon.meal_coupon(DiceScoring.SIX_KIND).display_name, "Spezialität des Hauses")

func test_meal_combo_key_is_empty_for_other_kinds():
	assert_eq(Coupon.chisel().meal_combo_key(), "")
	assert_eq(Coupon.material_coupon(DieMaterial.gold(), Coupon.Rarity.COMMON).meal_combo_key(), "")

func test_meal_rarity_follows_combo_strength():
	assert_eq(Coupon.meal_coupon(DiceScoring.ONE_KIND).rarity, Coupon.Rarity.COMMON)
	assert_eq(Coupon.meal_coupon(DiceScoring.FULL_HOUSE).rarity, Coupon.Rarity.UNCOMMON)
	assert_eq(Coupon.meal_coupon(DiceScoring.SIX_KIND).rarity, Coupon.Rarity.RARE)

func test_rarity_name_is_german():
	assert_eq(Coupon.rarity_name(Coupon.Rarity.COMMON), "häufig")
	assert_eq(Coupon.rarity_name(Coupon.Rarity.UNCOMMON), "ungewöhnlich")
	assert_eq(Coupon.rarity_name(Coupon.Rarity.RARE), "selten")

# --- Lichtgravur-Ziehung -----------------------------------------------------

func test_roll_draft_returns_distinct_inventory_coupons():
	var draft := Coupon.roll_draft(3, Coupon.Rarity.COMMON)
	assert_eq(draft.size(), 3, "drei Siegel")
	var seen := {}
	for coupon in draft:
		assert_true(Coupon.DRAFT_KINDS.has(coupon.kind), "nur inventarfähige Sorten (keine Menüs)")
		assert_false(seen.has(coupon.id), "keine Dubletten: %s" % coupon.id)
		seen[coupon.id] = true

func test_roll_draft_respects_rarity_floor():
	for i in 20:
		for coupon in Coupon.roll_draft(3, Coupon.Rarity.UNCOMMON):
			assert_true(coupon.rarity >= Coupon.Rarity.UNCOMMON, "kein häufiges Siegel unter der Grenze")

func test_roll_draft_lowers_floor_when_pool_too_small():
	# Mehr Siegel verlangt als es seltene gibt (7) -> die Untergrenze fällt,
	# damit die Auslage voll wird (statt leer zu bleiben).
	var draft := Coupon.roll_draft(9, Coupon.Rarity.RARE)
	assert_eq(draft.size(), 9, "Auslage voll trotz knapper seltener Siegel")
