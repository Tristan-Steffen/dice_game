extends GutTest
## Sättigung als Farbe: mit jeder Materialstufe wird die Materialfarbe SATTER.
## Der Name ist das Signal. Stufe I muss dabei überall byteweise die alte Farbe
## bleiben - sie ist der Normalfall und kündigt sich nie an.

func test_level_one_and_zero_are_identity() -> void:
	var probes := [Color(0.8, 0.2, 0.2), Color(0.3, 0.3, 0.35), Color.WHITE, Color.BLACK]
	for probe in probes:
		assert_eq(DieMaterial.saturated(probe, 0), probe, "Stufe 0 lässt die Farbe in Ruhe")
		assert_eq(DieMaterial.saturated(probe, 1), probe, "Stufe I ist der Normalfall")

func test_the_default_keeps_every_old_caller_on_the_old_colour() -> void:
	for material in DieMaterial.all():
		assert_eq(DieMaterial.tint_for(material.id), material.tint,
			"%s ohne Stufenangabe = die Farbe von vorher" % material.id)
		assert_eq(DieMaterial.tint_for(material.id, 1), material.tint)

func test_every_material_steps_twice() -> void:
	# BEIDE Enden müssen steigen: Rubin liegt schon bei S≈0.81, Knochen bei
	# S≈0.34 - ein glattes Multiplizieren würde das eine sofort deckeln und das
	# andere kaum bewegen.
	for material in DieMaterial.all():
		var one := DieMaterial.tint_for(material.id, 1)
		var two := DieMaterial.tint_for(material.id, 2)
		var three := DieMaterial.tint_for(material.id, 3)
		assert_gt(two.s, one.s, "%s: II ist satter als I" % material.id)
		assert_gt(three.s, two.s, "%s: III ist satter als II" % material.id)

func test_saturation_and_value_stay_in_range() -> void:
	for material in DieMaterial.all():
		for level in [1, 2, 3]:
			var color := DieMaterial.tint_for(material.id, level)
			assert_between(color.s, 0.0, 1.0, "%s Stufe %d: S im Rahmen" % [material.id, level])
			assert_between(color.v, 0.0, 1.0, "%s Stufe %d: V im Rahmen" % [material.id, level])

func test_richer_never_reads_as_darker() -> void:
	# Ohne den kleinen Hellwert-Zuschlag läse "satter" als "matschiger".
	for material in DieMaterial.all():
		assert_gte(DieMaterial.tint_for(material.id, 2).v, DieMaterial.tint_for(material.id, 1).v,
			"%s: II wird nicht dunkler" % material.id)
		assert_gte(DieMaterial.tint_for(material.id, 3).v, DieMaterial.tint_for(material.id, 2).v,
			"%s: III wird nicht dunkler" % material.id)

func test_the_hue_survives_the_step() -> void:
	# Satter, nicht anders: eine verschobene Farbe wäre ein anderes Material.
	for material in DieMaterial.all():
		if material.tint.s <= 0.001:
			continue
		for level in [2, 3]:
			assert_almost_eq(DieMaterial.tint_for(material.id, level).h, material.tint.h, 0.001,
				"%s Stufe %d behält seinen Farbton" % [material.id, level])

func test_an_unknown_material_stays_white_at_every_level() -> void:
	for level in [1, 2, 3]:
		assert_eq(DieMaterial.tint_for("", level), Color.WHITE, "keine Seite, keine Sättigung")
		assert_eq(DieMaterial.tint_for("kein_material", level), Color.WHITE)

func test_the_step_never_pushes_emission_over_the_bloom_threshold() -> void:
	# Das Signal der Stufe ist Farbreinheit, nie Helligkeit - dieselbe Regel wie
	# bei den Rissen. Geprüft wird der Zuwachs: die Stufe darf die Emission eines
	# Materials nicht nennenswert heller machen.
	for material in DieMaterial.all():
		if material.glow <= 0.0:
			continue
		var base := DieFaceDisplay.intense(material.tint).v * material.glow
		var top := DieFaceDisplay.intense(DieMaterial.tint_for(material.id, 3)).v * material.glow
		assert_lt(top - base, 0.10,
			"%s: Stufe III leuchtet höchstens einen Hauch heller" % material.id)

func test_bone_stays_dead_matte_at_every_level() -> void:
	# Tot-matt IST die Identität des Knochens; seine Stufe reitet allein auf der
	# Albedo. Ein Glühen bei Stufe III wäre ein anderes Material.
	var bone := DieMaterial.by_id(DieMaterial.BONE)
	assert_eq(bone.glow, 0.0, "Knochen glüht nie")
	for level in [1, 2, 3]:
		assert_gt(DieMaterial.tint_for(DieMaterial.BONE, level).s, 0.0, "aber er wird satter")
