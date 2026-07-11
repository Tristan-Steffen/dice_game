extends GutTest
## Tier-1-Tests des DieMaterial-Datensatzes und der Registrierung (all) -
## analog zu test_charm/test_coupon: Vollständigkeit, eindeutige ids, gefüllte
## Anzeigefelder und die Auflösungs-Helfer (by_id/is_valid_id/tint_for).

func test_all_returns_six_materials():
	assert_eq(DieMaterial.all().size(), 6)

func test_all_ids_are_unique():
	var seen := {}
	for material in DieMaterial.all():
		assert_false(seen.has(material.id), "doppelte id: %s" % material.id)
		seen[material.id] = true

func test_every_material_has_filled_metadata():
	for material in DieMaterial.all():
		assert_ne(material.id, "", "id fehlt")
		assert_ne(material.display_name, "", "display_name fehlt bei %s" % material.id)
		assert_ne(material.description, "", "description fehlt bei %s" % material.id)
		assert_ne(material.tint, Color.WHITE, "eigene Seitenfarbe fehlt bei %s" % material.id)

func test_by_id_resolves_and_rejects():
	assert_eq(DieMaterial.by_id(DieMaterial.RUBY).display_name, "Rubin")
	assert_null(DieMaterial.by_id(""), "NONE ist kein Material")
	assert_null(DieMaterial.by_id("unobtainium"))

func test_is_valid_id():
	assert_true(DieMaterial.is_valid_id(DieMaterial.GLASS))
	assert_false(DieMaterial.is_valid_id(""))
	assert_false(DieMaterial.is_valid_id("chisel"), "Ätzungs-ids sind keine Material-ids")

func test_tint_for_falls_back_to_white():
	assert_eq(DieMaterial.tint_for(""), Color.WHITE, "keine Seite ohne Material wird eingefärbt")
	assert_ne(DieMaterial.tint_for(DieMaterial.GOLD), Color.WHITE)
