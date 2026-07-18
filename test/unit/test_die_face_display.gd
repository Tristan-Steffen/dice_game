extends GutTest
## Tier-1-Tests der Würfel-Anzeige (DieFaceDisplay) auf einem echten
## DieBuilder-Würfel: Seitenwerte, Material-Tints von Seiten und Kanten-Rahmen,
## Eigenleuchten (Material-Flächen überhell) und das Umgebungslicht des Würfels
## (Farbe/Stärke folgen den Materialien).

func _display() -> DieFaceDisplay:
	var die: Node3D = autofree(DieBuilder.build())
	return die.get_node("RigidBody3D/Faces")

func _axis_for(face_index: int) -> String:
	for axis in DiceController.AXIS_FACE_INDEX:
		if DiceController.AXIS_FACE_INDEX[axis] == face_index:
			return axis
	return ""

func _face_material(display: DieFaceDisplay, face_index: int) -> StandardMaterial3D:
	return display.quads[_axis_for(face_index)].get_surface_override_material(0)

# --- Seitenwerte & Grundfarben ------------------------------------------------

func test_apply_definition_sets_face_values():
	var display := _display()
	display.apply_definition(DieDefinition.fixed(9, "Neun"))
	for axis in display.labels:
		assert_eq(display.labels[axis].text, "9")

func test_plain_die_uses_neutral_edge_neon():
	var display := _display()
	display.apply_definition(DieDefinition.standard())
	assert_eq(display.edge_base, DieFaceDisplay.EDGE_COLOR)
	# Körper überall dunkles Glas; das Neon liegt in der Emission der Kanten.
	assert_eq(display.edge_material_res.albedo_color, DieFaceDisplay.BODY_COLOR * Color.WHITE)
	assert_eq(display.edge_material_res.emission,
		DieFaceDisplay.EDGE_NEON * DieFaceDisplay.EDGE_GLOW * Color.WHITE)

func test_edge_material_tints_the_frame():
	var def := DieDefinition.standard()
	def.edge_material = DieMaterial.GOLD
	var display := _display()
	display.apply_definition(def)
	assert_eq(display.edge_base, DieMaterial.tint_for(DieMaterial.GOLD))

func test_set_edge_tint_highlights_and_set_tint_restores():
	# Kanten-Auswahl in der Gravur-Station: set_edge_tint übersteuert den Rahmen,
	# set_tint stellt danach die Materialfarbe wieder her.
	var def := DieDefinition.standard()
	def.edge_material = DieMaterial.GOLD
	var display := _display()
	display.apply_definition(def)
	display.set_edge_tint(RotatableDieView.SELECT_FACE_COLOR)
	assert_eq(display.edge_material_res.albedo_color, RotatableDieView.SELECT_FACE_COLOR)
	# Unschattiert, damit der Rahmen die FLACHE Auswahl-Farbe zeigt (wie die 2D-Chips
	# und die Ziffern) - nicht beleuchtet+leuchtend nach Pink klemmend.
	assert_eq(display.edge_material_res.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED,
		"der hervorgehobene Rahmen wird unschattiert gezeigt")
	display.set_tint(Color.WHITE)
	assert_eq(display.edge_material_res.albedo_color, DieFaceDisplay.BODY_COLOR * Color.WHITE)
	assert_eq(display.edge_material_res.emission,
		DieMaterial.tint_for(DieMaterial.GOLD) * DieFaceDisplay.MATERIAL_EDGE_GLOW * Color.WHITE,
		"das Gold-Neon der Kanten kehrt zurück")
	assert_eq(display.edge_material_res.shading_mode, BaseMaterial3D.SHADING_MODE_PER_PIXEL,
		"set_tint nimmt die unschattierte Auswahl wieder zurück")

func test_set_face_number_tint_colors_only_that_digit_and_leaves_the_body():
	# Seiten-Auswahl in der Gravur-Station: nur die ZIFFER der gewählten Seite
	# leuchtet (set_face_number_tint), der Würfelkörper bleibt neutral.
	var display := _display()
	display.apply_definition(DieDefinition.standard())
	display.set_face_number_tint(2, RotatableDieView.SELECT_FACE_COLOR)
	assert_eq(display.labels[_axis_for(2)].modulate, RotatableDieView.SELECT_FACE_COLOR,
		"die gewählte Ziffer leuchtet in der Auswahlfarbe")
	assert_eq(display.labels[_axis_for(3)].modulate, DieFaceDisplay.NUMBER_COLOR,
		"andere Ziffern behalten ihr Neutral-Neon")
	assert_eq(_face_material(display, 2).albedo_color, DieFaceDisplay.BODY_COLOR,
		"der Körper der gewählten Seite bleibt neutral")

func test_reset_number_tints_restores_all_digits():
	var display := _display()
	display.apply_definition(DieDefinition.standard())
	display.set_face_number_tint(2, RotatableDieView.SELECT_FACE_COLOR)
	display.reset_number_tints()
	assert_eq(display.labels[_axis_for(2)].modulate, DieFaceDisplay.NUMBER_COLOR)

# --- Eigenleuchten (Emission) ---------------------------------------------------

func test_material_faces_glow_brighter_than_plain_faces():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.AMBER
	var display := _display()
	display.apply_definition(def)
	var amber_emission: Color = _face_material(display, 0).emission
	var plain_emission: Color = _face_material(display, 1).emission
	var amber_tint := DieMaterial.tint_for(DieMaterial.AMBER)
	# Material-Seite glimmt in Tint × MATERIAL_FACE_GLOW (gedämpft, nicht überhell -
	# die breiten Flächen sollen nicht blühen), aber klar heller als das dunkle Glas.
	assert_almost_eq(amber_emission.r, amber_tint.r * DieFaceDisplay.MATERIAL_FACE_GLOW, 0.001,
		"Material-Seite = Tint × MATERIAL_FACE_GLOW")
	assert_gt(amber_emission.r, plain_emission.r, "Material-Seite heller als neutrale Seite")
	assert_almost_eq(plain_emission.r, DieFaceDisplay.EDGE_NEON.r * DieFaceDisplay.FACE_GLOW, 0.001,
		"neutrale Seite glimmt nur schwach (dunkles Glas)")

func test_material_edges_glow_overbright():
	var def := DieDefinition.standard()
	def.edge_material = DieMaterial.GOLD
	var display := _display()
	display.apply_definition(def)
	var gold_tint := DieMaterial.tint_for(DieMaterial.GOLD)
	assert_almost_eq(display.edge_material_res.emission.r,
		gold_tint.r * DieFaceDisplay.MATERIAL_EDGE_GLOW, 0.001)

# --- Umgebungslicht ------------------------------------------------------------

func test_light_stays_hidden_without_permission():
	var display := _display()
	display.apply_definition(DieDefinition.standard())
	assert_false(display.die_light.visible, "ohne set_light_enabled bleibt das Licht aus")

func test_plain_die_light_is_cool_neon():
	var display := _display()
	display.set_light_enabled(true)
	display.apply_definition(DieDefinition.standard())
	assert_true(display.die_light.visible)
	assert_almost_eq(display.die_light.light_energy, DieFaceDisplay.LIGHT_BASE_ENERGY, 0.001)
	assert_eq(display.die_light.light_color, DieFaceDisplay.LIGHT_BASE_COLOR * Color.WHITE)

func test_material_die_light_shines_way_brighter_in_material_color():
	var def := DieDefinition.standard()
	def.edge_material = DieMaterial.GOLD
	var display := _display()
	display.set_light_enabled(true)
	display.apply_definition(def)
	assert_almost_eq(display.die_light.light_energy, DieFaceDisplay.LIGHT_MATERIAL_ENERGY, 0.001)
	var gold_tint := DieMaterial.tint_for(DieMaterial.GOLD)
	assert_almost_eq(display.die_light.light_color.r, gold_tint.r, 0.001)
	assert_almost_eq(display.die_light.light_color.b, gold_tint.b, 0.001)

func test_mixed_materials_blend_the_light_color():
	# Gold-Kanten + Quecksilber-Seite: das Licht mischt beide Tints.
	var def := DieDefinition.standard()
	def.edge_material = DieMaterial.GOLD
	def.materials[0] = DieMaterial.MERCURY
	var display := _display()
	display.set_light_enabled(true)
	display.apply_definition(def)
	var expected := (DieMaterial.tint_for(DieMaterial.GOLD) + DieMaterial.tint_for(DieMaterial.MERCURY)) / 2.0
	assert_almost_eq(display.die_light.light_color.r, expected.r, 0.001)
	assert_almost_eq(display.die_light.light_color.g, expected.g, 0.001)
	assert_almost_eq(display.die_light.light_color.b, expected.b, 0.001)

func test_body_tint_colors_the_light():
	var def := DieDefinition.standard()
	def.edge_material = DieMaterial.GOLD
	var display := _display()
	display.set_light_enabled(true)
	display.apply_definition(def)
	display.set_tint(Color(0.5, 0.5, 0.5))
	var expected := DieMaterial.tint_for(DieMaterial.GOLD) * Color(0.5, 0.5, 0.5)
	assert_almost_eq(display.die_light.light_color.r, expected.r, 0.001)

func test_disabling_the_light_hides_it_again():
	var display := _display()
	display.set_light_enabled(true)
	display.apply_definition(DieDefinition.standard())
	display.set_light_enabled(false)
	assert_false(display.die_light.visible)
