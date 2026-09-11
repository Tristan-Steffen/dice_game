extends GutTest
## Die LADUNG am KÖRPER: vier Zustände auf EINEM Weg (apply_definition), dazu der
## transiente Zeremonie-Stand. Glimmen sitzt allein in Hitze und Lache und bleibt
## in Ruhe UNTER der Bloom-Schwelle, Kriechstrom entzündet den BRAND auf den Seiten,
## der Überschlag brennt BLAU und zündet die Eck-Lampen, und Ruß nimmt Lache,
## Lampen und Seelen-Bewegung fort.

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

func _peak(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b))

# --- Die Leiter ----------------------------------------------------------------

func test_the_charge_level_travels_from_the_definition_into_the_fire() -> void:
	# Ab Stufe 2 trägt jede Seite ihr Brand-Quad; der Überschlag brennt blau und
	# höher. Stufe 0 und 1 und der Ruß tragen keines - die Kante selbst bleibt
	# unverändert, sie hat keinen Ladungs-Kanal.
	for level in [0, 1, 2, 3]:
		var display := _display()
		display.apply_definition(_def(level))
		assert_eq(display.shown_charge(), level, "Stufe %d steht am Körper" % level)
		var wanted := 6 if level >= DieFaceDisplay.CHARGE_FIRE_LEVEL else 0
		assert_eq(display.fire_parts.size(), wanted, "Brand-Quads der Stufe %d" % level)
		if wanted == 0:
			continue
		var material: ShaderMaterial = display.fire_parts[0].material_override
		assert_eq(material.shader, DieFaceDisplay.FIRE_SHADER)
		var gain: float = material.get_shader_parameter("gain")
		assert_eq(gain, DieFaceDisplay.FIRE_ARC_GAIN if level >= 3 else 1.0,
			"Höhe der Stufe %d" % level)
		var blue: bool = level >= DieFaceDisplay.CHARGE_ARC_LEVEL
		var mid: Vector3 = material.get_shader_parameter("mid_color")
		var want := DieFaceDisplay.BLUE_FIRE_MID if blue else DieFaceDisplay.FIRE_MID
		assert_almost_eq(mid, Vector3(want.r, want.g, want.b), Vector3.ONE * 0.001,
			"Stufe %d brennt %s" % [level, "blau" if blue else "orange"])
	var burned := _display()
	burned.apply_definition(_def(2, true))
	assert_true(burned.fire_parts.is_empty(), "Ruß brennt nicht")
	var cooled := _display()
	cooled.apply_definition(_def(3))
	cooled.apply_definition(_def(0))
	assert_true(cooled.fire_parts.is_empty(), "entladen: die Quads sind weg")

func test_the_fire_sits_under_the_digit_and_leaves_the_frame_alone() -> void:
	# Der Rahmen trägt die Essenz-Farbe (Spieler-Sorge 2026-09-11): der Brand ist
	# eine SEITEN-Auflage auf dem Aschen-Platz, unter der Ziffer gezeichnet.
	var display := _display()
	display.apply_definition(_def(2))
	for part in display.fire_parts:
		assert_almost_eq(part.position.z, DieFaceDisplay.FIRE_LIFT, 0.0001, "auf dem Aschen-Platz")
		assert_eq((part.material_override as ShaderMaterial).render_priority, -1, "vor der Ziffer gezeichnet")
		assert_true(part.get_parent() in display.quads.values(), "Kind eines Seiten-Quads")
	assert_eq(display.get_node_or_null("ChargeArcs"), null, "kein Körper-Quad um den Würfel")

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
	# Auch der Überschlag färbt die Kante NICHT (Spieler-Wunsch 2026-09-07): er
	# lebt in seinen Blitzen und den Eck-Lampen, der Rahmen bleibt der kahle.
	var arcing := _display()
	arcing.apply_definition(_def(3))
	assert_almost_eq(_peak(arcing.edge_material_res.emission),
		_peak(display.edge_material_res.emission), 0.001, "die Kante bleibt, wie sie ist")

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
	assert_true(display.fire_parts.is_empty(), "und kein Brand")

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
	assert_eq(display.fire_parts.size(), 6, "samt seinem Brand")
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

func test_the_glimmer_builds_its_heat_parts_and_every_level_keeps_them() -> void:
	# Stufe 1 wabert: zwei Hitze-Lagen, lazy gebaut. Jede Stufe trägt alle
	# darunter, also wabern 2 und 3 weiter - kalt und Ruß tragen keine Hitze.
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
		assert_eq(hotter.heat_parts.size(), 2, "Stufe %d wabert weiter" % level)
	var burned := _display()
	burned.apply_definition(_def(1, true))
	assert_true(burned.heat_parts.is_empty(), "Ruß ist tot, nicht heiß")

# --- STUMM: die Auflagen bleiben fort, der Zustand nicht ------------------------
# Die GLAS-ANSICHT schaltet die versenkten Vorrats-Würfel so (Spieler-Wunsch
# 2026-09-11): unter dem halb durchsichtigen Schirm zögen ihre Effekte quer über
# das Raster.

func test_stumm_nimmt_hitze_brand_funken_und_lache_fort() -> void:
	var legendary := ""
	for essence in Essence.all():
		if essence.rarity == Essence.Rarity.LEGENDARY:
			legendary = essence.id
			break
	assert_ne(legendary, "", "es gibt eine legendäre Seele")
	var display := _display()
	display.apply_definition(_def(DieDefinition.CHARGE_MAX, false, legendary))
	assert_gt(display.heat_parts.size(), 0, "geladen wabert er")
	assert_gt(display.fire_parts.size(), 0, "und brennt")
	assert_not_null(display.soul_motes, "die legendäre Seele funkt")
	assert_true(display.glow_pool.visible, "und wirft ihre Lache")

	display.effects_muted = true
	assert_eq(display.heat_parts.size(), 0, "stumm wabert nichts")
	assert_eq(display.fire_parts.size(), 0, "und brennt nichts")
	assert_null(display.soul_motes, "und funkt nichts")
	assert_false(display.glow_pool.visible, "und keine Lache")
	assert_eq(display.shown_charge(), DieDefinition.CHARGE_MAX,
		"die LADUNG selbst bleibt - nur ihre Auflagen schweigen")

	display.effects_muted = false
	assert_gt(display.heat_parts.size(), 0, "und alles kommt zurück")
	assert_not_null(display.soul_motes)
	assert_true(display.glow_pool.visible)

## Ein STUMMER Würfel behält seine Stummheit über einen Neuaufbau der Anzeige -
## das Tray schreibt bei jeder Änderung neu.
func test_stumm_ueberlebt_ein_neues_apply_definition() -> void:
	var display := _display()
	display.effects_muted = true
	display.apply_definition(_def(DieDefinition.CHARGE_MAX))
	assert_eq(display.heat_parts.size(), 0, "auch frisch gesetzt bleibt er stumm")
	assert_eq(display.fire_parts.size(), 0)
