extends GutTest
## Die LADUNG am KÖRPER: vier Zustände auf EINEM Weg (apply_definition), dazu der
## transiente Zeremonie-Stand. Glimmen sitzt allein im Kantenlicht und in der Lache
## und bleibt in Ruhe UNTER der Bloom-Schwelle, Kriechstrom schaltet die Funken des
## Shaders und die Eck-Lampen an, der Überschlag baut seine Teilchen, und Ruß nimmt
## Lache, Lampen und Seelen-Bewegung fort.

## Die Bloom-Schwelle des Tisches (glow_hdr_threshold) - der kahle Würfel bleibt
## darunter, und Stufe 1 darf ihn nicht darüber heben.
const BLOOM := 0.95

func _display() -> DieFaceDisplay:
	var die: Node3D = autofree(DieBuilder.build())
	return die.get_node("RigidBody3D/Faces")

func _def(charge := 0, burned := false, essence_id := "") -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = [1, 2, 3, 4, 5, 6]
	def.faces = faces
	def.essence_id = essence_id
	def.charge = charge
	def.burned_out = burned
	return def

func _charge_uniform(display: DieFaceDisplay) -> float:
	return display.beam_material.get_shader_parameter("charge_level")

func _peak(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b))

# --- Die Leiter ----------------------------------------------------------------

func test_the_charge_level_travels_from_the_definition_into_the_edge_shader() -> void:
	for level in [0, 1, 2, 3]:
		var display := _display()
		display.apply_definition(_def(level))
		assert_eq(display.shown_charge(), level, "Stufe %d steht am Körper" % level)
		assert_eq(_charge_uniform(display), float(level), "Uniform der Stufe %d" % level)

func test_only_the_flashover_builds_its_particles() -> void:
	for level in [0, 1, 2]:
		var display := _display()
		display.apply_definition(_def(level))
		assert_null(display.charge_motes, "Stufe %d springt nicht über" % level)
	var arcing := _display()
	arcing.apply_definition(_def(3))
	assert_not_null(arcing.charge_motes, "der Überschlag springt")
	# Fällt die Stufe, werden sie wieder freigegeben (das soul_motes-Muster).
	arcing.apply_definition(_def(1))
	assert_null(arcing.charge_motes, "gefallene Stufe gibt die Teilchen frei")

func test_the_flashover_lights_the_corner_lamps_without_a_soul() -> void:
	var cold := _display()
	cold.apply_definition(_def(1))
	assert_false(cold.corner_caps.visible, "Glimmen und Kriechstrom lassen die Ecken dunkel")
	var hot := _display()
	hot.apply_definition(_def(3))
	assert_true(hot.corner_caps.visible, "der Überschlag zündet die Eck-Lampen")

func test_the_first_step_stays_under_the_bloom_threshold_at_rest() -> void:
	# Stufe 1 ist WÄRME, kein Strahlen: der kahle Würfel darf davon nicht bloomen.
	var display := _display()
	display.apply_definition(_def(1))
	assert_lt(_peak(display.edge_material_res.emission), BLOOM,
		"das Glimmen bleibt unter der Bloom-Schwelle")
	# Der Überschlag DARF blühen - sonst wäre die Leiter keine.
	var arcing := _display()
	arcing.apply_definition(_def(3))
	assert_gt(_peak(arcing.edge_material_res.emission),
		_peak(display.edge_material_res.emission), "der Überschlag steht heller")

func test_the_charge_warms_the_floor_pool() -> void:
	var cold := _display()
	cold.apply_definition(_def(0))
	var hot := _display()
	hot.apply_definition(_def(3))
	assert_gt(hot._pool_color.b, cold._pool_color.b, "die Lache nimmt das Violett auf")
	assert_gt(hot._pool_color.a, cold._pool_color.a, "und trägt weiter")

# --- Durchgebrannt --------------------------------------------------------------

func test_burned_out_kills_pool_lamps_and_motion() -> void:
	var display := _display()
	display.apply_definition(_def(3, true, Essence.QUINTESSENCE))
	assert_true(display.shown_burned(), "der Würfel trägt Ruß")
	assert_eq(display.shown_charge(), 0, "durchgebrannt heißt tot, nicht heiß")
	assert_false(display.glow_pool.visible, "keine Lache")
	assert_false(display.corner_caps.visible, "keine Eck-Lampen")
	assert_null(display.soul_motes, "die Seelen-Bewegung steht still")
	assert_eq(_charge_uniform(display), 0.0, "und keine Funken")

func test_burned_out_flattens_the_edges_and_dims_the_digit() -> void:
	var display := _display()
	display.apply_definition(_def(0, true))
	var flat: Vector4 = display.beam_material.get_shader_parameter("flat_tint")
	assert_gt(flat.w, 0.0, "die Kanten stehen flach (der set_edge_tint-Schalter)")
	assert_almost_eq(Vector3(flat.x, flat.y, flat.z),
		Vector3(DieFaceDisplay.BURNED_EDGE.r, DieFaceDisplay.BURNED_EDGE.g,
			DieFaceDisplay.BURNED_EDGE.b), Vector3.ONE * 0.001, "im Ruß-Ton")
	var label: Label3D = display.labels.values()[0]
	assert_lt(label.modulate.get_luminance(),
		DieFaceDisplay.NUMBER_COLOR.get_luminance(), "die Ziffer ist gedimmt")

# --- Der ZEREMONIE-Stand ---------------------------------------------------------

func test_the_override_shows_the_running_state_and_the_definition_takes_it_back() -> void:
	var display := _display()
	var def := _def(1)
	display.apply_definition(def)
	display.set_charge_override(3, false)
	assert_eq(display.shown_charge(), 3, "die Zeremonie zeigt ihren Stand")
	assert_not_null(display.charge_motes, "samt seinen Teilchen")
	display.clear_charge_override()
	assert_eq(display.shown_charge(), 1, "danach steht wieder der Def-Stand")
	# Der HARTE Weg: apply_definition löscht den Override ebenfalls.
	display.set_charge_override(0, true)
	assert_true(display.shown_burned(), "der Ruß der Zeremonie")
	display.apply_definition(def)
	assert_false(display.shown_burned(), "apply_definition ist der harte Weg")
	assert_eq(display.shown_charge(), 1, "und der Def-Stand übernimmt")

func test_the_flash_lifts_the_lamp_and_falls_back() -> void:
	var display := _display()
	display.apply_definition(_def(1))
	var rest := _peak(display.edge_material_res.emission)
	display.flash_charge(1.0)
	assert_gt(_peak(display.edge_material_res.emission), rest, "der Blitz hebt den Rahmen")
	# Der Tween läuft von selbst zurück; der Endzustand ist der Ruhe-Ton.
	display._charge_flash = 0.0
	display._refresh_face_colors()
	assert_almost_eq(_peak(display.edge_material_res.emission), rest, 0.001,
		"und fällt auf die Ruhe zurück")

func test_only_the_glimmer_builds_its_heat_parts() -> void:
	# Stufe 1 wabert: zwei Hitze-Lagen, lazy gebaut - kalt, heißer und Ruß
	# tragen keine Hitze-Teile.
	var glimmer := _display()
	glimmer.apply_definition(_def(1))
	assert_eq(glimmer.heat_parts.size(), 2, "zwei Lagen: Verzerrung und Glut")
	var shaders := []
	for part in glimmer.heat_parts:
		shaders.append((part.material_override as ShaderMaterial).shader)
	assert_true(shaders.has(DieFaceDisplay.HEAT_SHADER), "die Verzerrung")
	assert_true(shaders.has(DieFaceDisplay.HEAT_GLOW_SHADER), "die Glut")
	# Die Verzerrung liegt ZUUNTERST, die Glut ZUOBERST - sonst löscht die eine
	# Ziffern und die andere wird von den Nachbar-Würfeln übermalt.
	var prio := {}
	for part in glimmer.heat_parts:
		var mat := part.material_override as ShaderMaterial
		prio[mat.shader] = mat.render_priority
	assert_lt(int(prio[DieFaceDisplay.HEAT_SHADER]), int(prio[DieFaceDisplay.HEAT_GLOW_SHADER]))
	glimmer.apply_definition(_def(0))
	assert_true(glimmer.heat_parts.is_empty(), "kalt: keine Hitze")
	for level in [2, 3]:
		var hotter := _display()
		hotter.apply_definition(_def(level))
		assert_true(hotter.heat_parts.is_empty(), "Stufe %d flimmert nicht mehr" % level)
	var burned := _display()
	burned.apply_definition(_def(1, true))
	assert_true(burned.heat_parts.is_empty(), "Ruß ist tot, nicht heiß")
