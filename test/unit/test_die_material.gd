extends GutTest
## Tier-1-Tests des DieMaterial-Datensatzes und der Registrierung (all) -
## analog zu test_charm/test_engraving: Vollständigkeit, eindeutige ids, gefüllte
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
		assert_ne(material.edge_description, "", "edge_description fehlt bei %s" % material.id)
		assert_ne(material.short, "", "short fehlt bei %s" % material.id)
		assert_ne(material.edge_short, "", "edge_short fehlt bei %s" % material.id)
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

func test_every_material_has_its_own_surface_color():
	for material in DieMaterial.all():
		assert_ne(material.surface_color, Color.WHITE,
			"echte Einlagen-Albedo fehlt bei %s" % material.id)

func test_signature_profiles_reflect_the_material_names():
	# Jedes Material bricht die Glas-Regel anders - genau EINE Signatur je Name.
	assert_gt(DieMaterial.gold().metallic, 0.5, "Gold spiegelt")
	assert_almost_eq(DieMaterial.bone().glow, 0.0, 0.001, "Knochen leuchtet nicht")
	assert_lt(DieMaterial.glass().alpha, 1.0, "Glas ist durchsichtig")
	assert_gt(DieMaterial.mercury().flow_speed, 0.0, "Quecksilber fließt")
	assert_gt(DieMaterial.amber().glow, DieMaterial.gold().glow, "Bernstein glüht, Gold nicht")
	assert_ne(DieMaterial.die_normal_for(DieMaterial.RUBY), null, "Rubin hat Facetten-Relief")

func test_die_normal_for_only_where_a_map_exists():
	assert_null(DieMaterial.die_normal_for(""), "ohne Material kein Relief")
	assert_null(DieMaterial.die_normal_for(DieMaterial.BONE), "Knochen bleibt flach")

# --- Hover-Erklärzeilen ---------------------------------------------------------

func test_face_hint_is_the_short_name_and_effect():
	var amber := DieMaterial.amber()
	var hint := DieMaterial.face_hint(DieMaterial.AMBER)
	assert_eq(hint, "%s: %s" % [amber.display_name, amber.short], "«Name»: Kurzwirkung")
	assert_false(hint.contains(amber.description), "nicht die lange Wirkungszeile")

func test_edge_hint_marks_the_edges_and_uses_the_edge_short():
	# Gold wirkt an der Kante ANDERS als auf der Seite (je Wurf statt beim Nehmen) -
	# der Kanten-Hinweis muss die Kanten-Kurzwirkung nehmen und als Kante ausweisen.
	var gold := DieMaterial.gold()
	var hint := DieMaterial.edge_hint(DieMaterial.GOLD)
	assert_true(hint.contains("Kanten"), "als Kanten-Wirkung ausgewiesen")
	assert_true(hint.contains(gold.edge_short))
	assert_ne(gold.edge_short, gold.short, "Gold-Kante unterscheidet sich von der Seite")

func test_short_hints_stay_short():
	# Kern der Änderung: die Hover-Zeilen sind knapp (keine langen Sätze mehr).
	for material in DieMaterial.all():
		assert_lt(DieMaterial.face_hint(material.id).length(), 40,
			"Seiten-Kurzhinweis zu lang bei %s" % material.id)
		assert_lt(DieMaterial.edge_hint(material.id).length(), 48,
			"Kanten-Kurzhinweis zu lang bei %s" % material.id)

func test_hints_are_empty_without_a_material():
	assert_eq(DieMaterial.face_hint(""), "", "keine Seite ohne Material erklärt sich")
	assert_eq(DieMaterial.edge_hint(""), "")
	assert_eq(DieMaterial.face_hint("unobtainium"), "")
