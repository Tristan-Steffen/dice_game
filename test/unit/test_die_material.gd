extends GutTest
## Tier-1-Tests des DieMaterial-Datensatzes und der Registrierung (all) -
## analog zu test_charm/test_engraving: Vollständigkeit, eindeutige ids, gefüllte
## Anzeigefelder und die Auflösungs-Helfer (by_id/is_valid_id/tint_for).

func test_all_returns_five_materials():
	# Quecksilber ist raus: es zahlte nicht, es löste aus - und gehört damit in
	# eine andere Schicht (die Essenzen).
	assert_eq(DieMaterial.all().size(), 5)

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
		assert_ne(material.short, "", "short fehlt bei %s" % material.id)
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

func test_short_hints_stay_short():
	# Kern der Änderung: die Hover-Zeilen sind knapp (keine langen Sätze mehr).
	for material in DieMaterial.all():
		assert_lt(DieMaterial.face_hint(material.id).length(), 40,
			"Seiten-Kurzhinweis zu lang bei %s" % material.id)

func test_every_material_has_three_levels():
	# Die Sättigung hebt jedes Material - nur Seiten, Kanten kennen keine Stufe.
	for material in DieMaterial.all():
		for level in [2, 3]:
			assert_ne(material.short_for(level), "", "Stufe %d ohne Kurzwirkung bei %s" % [level, material.id])
			assert_ne(material.description_for(level), "", "Stufe %d ohne Beschreibung bei %s" % [level, material.id])
		assert_ne(material.short_for(2), material.short, "Stufe II wirkt anders bei %s" % material.id)
		assert_ne(material.short_for(3), material.short_for(2), "Stufe III wirkt anders bei %s" % material.id)

func test_short_for_falls_back_to_the_first_level():
	var ruby := DieMaterial.ruby()
	assert_eq(ruby.short_for(1), ruby.short)
	assert_eq(ruby.description_for(1), ruby.description)
	assert_eq(ruby.short_for(0), ruby.short, "auch ohne gesetzte Stufe gilt I")

func test_level_roman_names_only_the_raised_levels():
	assert_eq(DieMaterial.level_roman(1), "", "Stufe I nennt sich nicht - sie ist der Normalfall")
	assert_eq(DieMaterial.level_roman(2), "II")
	assert_eq(DieMaterial.level_roman(3), "III")

func test_face_hint_marks_the_raised_level():
	var ruby := DieMaterial.ruby()
	assert_eq(DieMaterial.face_hint(DieMaterial.RUBY, 2), "%s II: %s" % [ruby.display_name, ruby.short_for(2)])
	assert_eq(DieMaterial.face_hint(DieMaterial.RUBY, 3), "%s III: %s" % [ruby.display_name, ruby.short_for(3)])
	assert_eq(DieMaterial.face_hint(DieMaterial.RUBY, 1), "%s: %s" % [ruby.display_name, ruby.short],
		"Stufe I bleibt die schlichte Namenszeile")
	assert_eq(DieMaterial.face_hint("", 3), "", "ohne Material auch gehoben nichts")

func test_raised_short_hints_stay_short():
	for material in DieMaterial.all():
		for level in [2, 3]:
			assert_lt(DieMaterial.face_hint(material.id, level).length(), 44,
				"Stufen-Kurzhinweis zu lang bei %s (Stufe %d)" % [material.id, level])

func test_hints_are_empty_without_a_material():
	assert_eq(DieMaterial.face_hint(""), "", "keine Seite ohne Material erklärt sich")
	assert_eq(DieMaterial.face_hint("unobtainium"), "")
