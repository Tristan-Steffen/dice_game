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
	var gold := DieMaterial.gold()
	assert_eq(display.edge_material_res.albedo_color, gold.surface_color * Color.WHITE,
		"die echte Gold-Albedo kehrt zurück")
	assert_almost_eq(display.edge_material_res.emission.r,
		gold.tint.r * DieFaceDisplay.MATERIAL_EDGE_GLOW_FLOOR, 0.001,
		"das Kanten-Neon (Distanz-Floor) kehrt zurück")
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

# --- Shading-Profile (Einlagen aus echtem Material) ------------------------------

func test_amber_face_glows_from_within_brighter_than_plain_faces():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.AMBER
	var display := _display()
	display.apply_definition(def)
	var amber := DieMaterial.amber()
	var amber_emission: Color = _face_material(display, 0).emission
	var plain_emission: Color = _face_material(display, 1).emission
	assert_almost_eq(amber_emission.r, amber.tint.r * amber.glow, 0.001,
		"Material-Seite glüht in Tint × Profil-glow")
	assert_gt(amber_emission.r, plain_emission.r, "Bernstein heller als neutrale Seite")
	assert_almost_eq(plain_emission.r, DieFaceDisplay.EDGE_NEON.r * DieFaceDisplay.FACE_GLOW, 0.001,
		"neutrale Seite glimmt nur schwach (dunkles Glas)")

func test_gold_face_is_reflective_metal_not_neon():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.GOLD
	var display := _display()
	display.apply_definition(def)
	var material := _face_material(display, 0)
	var gold := DieMaterial.gold()
	assert_almost_eq(material.metallic, DieMaterial.gold().metallic, 0.001, "Gold ist Metall")
	assert_eq(material.albedo_color, gold.surface_color * Color.WHITE,
		"helle Metall-Albedo statt dunklem Glas")
	assert_lt(material.emission.r, DieFaceDisplay.EDGE_NEON.r * DieFaceDisplay.EDGE_GLOW,
		"Gold glüht kaum - es spiegelt")

func test_bone_face_is_matte_and_dead():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.BONE
	var display := _display()
	display.apply_definition(def)
	var material := _face_material(display, 0)
	assert_eq(material.emission, Color(0, 0, 0, 0), "Knochen leuchtet gar nicht")
	assert_almost_eq(material.roughness, DieMaterial.bone().roughness, 0.001, "stumpf-matt")

func test_glass_face_is_transparent():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.GLASS
	var display := _display()
	display.apply_definition(def)
	var material := _face_material(display, 0)
	assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_almost_eq(material.albedo_color.a, DieMaterial.glass().alpha, 0.001,
		"das Würfelinnere scheint durch die Glas-Seite")
	assert_eq(_face_material(display, 1).transparency, BaseMaterial3D.TRANSPARENCY_DISABLED,
		"neutrale Seiten bleiben deckend")

func test_ruby_face_gets_its_facet_normal_map():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.RUBY
	var display := _display()
	display.apply_definition(def)
	assert_true(_face_material(display, 0).normal_enabled, "Rubin-Facetten fangen Licht")
	assert_false(_face_material(display, 1).normal_enabled, "neutrale Seiten bleiben flach")

func test_mercury_face_flows_plain_faces_stay_still():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.MERCURY
	var display := _display()
	display.apply_definition(def)
	display._process(0.5)
	assert_ne(_face_material(display, 0).uv1_offset, Vector3.ZERO,
		"Quecksilber-Oberfläche driftet")
	assert_eq(_face_material(display, 1).uv1_offset, Vector3.ZERO,
		"neutrale Seiten fließen nicht")

func test_mercury_edges_flow_too():
	var def := DieDefinition.standard()
	def.edge_material = DieMaterial.MERCURY
	var display := _display()
	display.apply_definition(def)
	display._process(0.5)
	assert_ne(display.edge_material_res.uv1_offset, Vector3.ZERO)

func test_glass_edges_stay_opaque():
	# Der Füllkörper hinter dem Rahmen IST die Würfelmasse - Alpha würde ihn aushöhlen.
	var def := DieDefinition.standard()
	def.edge_material = DieMaterial.GLASS
	var display := _display()
	display.apply_definition(def)
	assert_eq(display.edge_material_res.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED)

# --- Distanz-Signale (Ziffernfarbe, Leucht-Rahmen, Kanten-Floor, Eck-Kappen) ------

func test_material_face_digit_stays_neutral_white():
	# Ziffern bleiben unabhängig vom Material neutral-weiß - Materialfarben
	# machten die Zahl schwer lesbar. Identität tragen Fläche/Rahmen/Kanten.
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.RUBY
	var display := _display()
	display.apply_definition(def)
	assert_eq(display.labels[_axis_for(0)].modulate, DieFaceDisplay.NUMBER_COLOR,
		"Material-Ziffer bleibt weiß")
	assert_eq(display.labels[_axis_for(1)].modulate, DieFaceDisplay.NUMBER_COLOR,
		"neutrale Ziffern ebenso")

func test_reset_number_tints_restores_neutral_white():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.RUBY
	var display := _display()
	display.apply_definition(def)
	display.set_face_number_tint(0, RotatableDieView.SELECT_FACE_COLOR)
	display.reset_number_tints()
	assert_eq(display.labels[_axis_for(0)].modulate, DieFaceDisplay.NUMBER_COLOR,
		"nach der Auswahl kehrt das Neutral-Weiß zurück")

func test_material_face_shows_a_glowing_frame_plain_faces_none():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.RUBY
	var display := _display()
	display.apply_definition(def)
	var frame: MeshInstance3D = display.frames[_axis_for(0)]
	assert_true(frame.visible, "Material-Seite trägt den Leucht-Rahmen")
	var frame_material: StandardMaterial3D = frame.material_override
	assert_almost_eq(frame_material.emission.r,
		DieMaterial.ruby().tint.r * DieFaceDisplay.FRAME_GLOW, 0.001,
		"Rahmen leuchtet voll in Materialfarbe")
	assert_false(display.frames[_axis_for(1)].visible, "neutrale Seiten bleiben rahmenlos")

func test_bone_frame_stays_dark():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.BONE
	var display := _display()
	display.apply_definition(def)
	var frame: MeshInstance3D = display.frames[_axis_for(0)]
	assert_true(frame.visible, "auch Knochen bekommt den Rahmen (als dunkle Linie)")
	assert_eq((frame.material_override as StandardMaterial3D).emission, Color(0, 0, 0, 0),
		"aber er leuchtet nie - Knochen-Identität")

func test_material_edges_glow_at_least_the_distance_floor():
	var def := DieDefinition.standard()
	def.edge_material = DieMaterial.GOLD
	var display := _display()
	display.apply_definition(def)
	var gold := DieMaterial.gold()
	assert_almost_eq(display.edge_material_res.emission.r,
		gold.tint.r * DieFaceDisplay.MATERIAL_EDGE_GLOW_FLOOR, 0.001,
		"Gold-Kanten glühen mindestens auf Floor-Stärke (dünne Linien brauchen Emission)")

func test_bone_edges_stay_dark():
	var def := DieDefinition.standard()
	def.edge_material = DieMaterial.BONE
	var display := _display()
	display.apply_definition(def)
	assert_eq(display.edge_material_res.emission, Color(0, 0, 0, 0),
		"der Floor gilt nicht für Knochen - seine Identität ist Nicht-Leuchten")

func test_corner_caps_only_with_edge_material():
	var display := _display()
	display.apply_definition(DieDefinition.standard())
	assert_false(display.corner_caps.visible, "ohne Kanten-Material keine Kappen")
	var def := DieDefinition.standard()
	def.edge_material = DieMaterial.GOLD
	display.apply_definition(def)
	assert_true(display.corner_caps.visible, "Kanten-Material beschlägt die Ecken")
	assert_eq(display.corner_caps.get_child_count(), 8)

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
