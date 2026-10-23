extends GutTest
## Die LADUNG am KÖRPER: vier Zustände auf EINEM Weg (apply_definition), dazu der
## transiente Zeremonie-Stand. Die Stufe färbt die ZIFFER (Weiß, Gelb, Orange, Rot),
## der Überschlag zittert und zündet die Eck-Lampen, und Ruß nimmt Lache, Lampen
## und Seelen-Bewegung fort.

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

func _digit(display: DieFaceDisplay) -> Color:
	return (display.labels.values()[0] as Label3D).modulate

func test_the_charge_level_colours_the_digit() -> void:
	# Die Ladung lebt in der ZIFFER (Spieler-Wahl 2026-10-23): Weiß, Gelb, Orange,
	# Rot - jede Stufe ihre Farbe, und über der Seite liegt keine Auflage.
	for level in [0, 1, 2, 3]:
		var display := _display()
		display.apply_definition(_def(level))
		assert_eq(display.shown_charge(), level, "Stufe %d steht am Körper" % level)
		for label: Label3D in display.labels.values():
			assert_eq(label.modulate, DieFaceDisplay.HEAT_NUMBER_COLORS[level],
				"jede Ziffer trägt Stufe %d" % level)
	assert_eq(DieFaceDisplay.HEAT_NUMBER_COLORS[0], DieFaceDisplay.NUMBER_COLOR, "kalt ist weiß")
	var cooled := _display()
	cooled.apply_definition(_def(3))
	cooled.apply_definition(_def(0))
	assert_eq(_digit(cooled), DieFaceDisplay.NUMBER_COLOR, "entladen: wieder weiß")

func test_the_heat_steps_are_distinct_hues() -> void:
	# Gelb, Orange, Rot müssen als TÖNE auseinanderliegen, nicht nur als Helligkeit -
	# zwei Bernstein-Stufen waren nicht zu unterscheiden.
	var hues := []
	for level in [1, 2, 3]:
		hues.append(DieFaceDisplay.HEAT_NUMBER_COLORS[level].h)
	assert_gt(hues[0] - hues[1], 0.04, "Gelb liegt sichtbar über Orange")
	assert_gt(hues[1] - hues[2], 0.04, "Orange liegt sichtbar über Rot")

func test_a_selection_tint_survives_a_repaint_and_falls_back_to_the_heat() -> void:
	var display := _display()
	display.apply_definition(_def(2))
	display.set_face_number_tint(0, DieFaceDisplay.SELECT_NUMBER_COLOR)
	display.set_tint(Color.WHITE)
	var tinted := false
	for label: Label3D in display.labels.values():
		tinted = tinted or label.modulate == DieFaceDisplay.SELECT_NUMBER_COLOR
	assert_true(tinted, "ein Neuanstrich löscht die Auswahl nicht")
	display.reset_number_tints()
	assert_eq(_digit(display), DieFaceDisplay.HEAT_NUMBER_COLORS[2], "zurück auf die Glut")

func test_material_faces_give_the_digit_a_wide_dark_halo() -> void:
	# Rubin, Bernstein und Gold teilen die Töne der Hitze: auf einer Material-Seite
	# glüht die Ziffer darum auf eigenem Dunkel.
	var display := _display()
	var def := _def(2)
	def.materials[0] = DieMaterial.GOLD
	def.levels[0] = 1
	display.apply_definition(def)
	for axis in display.labels:
		var label: Label3D = display.labels[axis]
		var want := DieFaceDisplay.LABEL_OUTLINE_MATERIAL if display.face_ids[axis] != "" else DieFaceDisplay.LABEL_OUTLINE_SIZE
		assert_eq(label.outline_size, want, "Hof der Seite %s" % axis)
	assert_gt(DieFaceDisplay.LABEL_OUTLINE_MATERIAL, DieFaceDisplay.LABEL_OUTLINE_SIZE)

func test_only_the_top_step_trembles() -> void:
	var calm := _display()
	calm.apply_definition(_def(2))
	calm._tick_heat()
	assert_eq(calm.position, Vector3.ZERO, "Stufe 2 ruht")
	var hot := _display()
	hot.apply_definition(_def(3))
	hot._tick_heat()
	assert_ne(hot.position, Vector3.ZERO, "Stufe 3 zittert")
	hot.apply_definition(_def(3, true))
	hot._tick_heat()
	assert_eq(hot.position, Vector3.ZERO, "Ruß zittert nicht mehr")
	assert_eq(hot.rotation, Vector3.ZERO)

func test_the_flashover_lights_the_corner_lamps_without_a_soul() -> void:
	var cold := _display()
	cold.apply_definition(_def(1))
	assert_false(cold.corner_caps.visible, "die unteren Stufen lassen die Ecken dunkel")
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
	# lebt in Ziffer und Eck-Lampen, der Rahmen bleibt der kahle.
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
	assert_eq(_digit(display), DieFaceDisplay.BURNED_NUMBER, "und die Ziffer ist erloschen")

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
	assert_eq(_digit(display), DieFaceDisplay.HEAT_NUMBER_COLORS[3], "samt seiner Glut")
	display.clear_charge_override()
	assert_eq(display.shown_charge(), 1, "danach steht wieder der Def-Stand")
	assert_eq(_digit(display), DieFaceDisplay.HEAT_NUMBER_COLORS[1])
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

# --- STUMM: die Auflagen bleiben fort, der Zustand nicht ------------------------
# Die GLAS-ANSICHT schaltet die versenkten Vorrats-Würfel so (Spieler-Wunsch
# 2026-09-11): unter dem halb durchsichtigen Schirm zögen ihre Effekte quer über
# das Raster.

func test_stumm_nimmt_zittern_funken_und_lache_fort() -> void:
	var legendary := ""
	for essence in Essence.all():
		if essence.rarity == Essence.Rarity.LEGENDARY:
			legendary = essence.id
			break
	assert_ne(legendary, "", "es gibt eine legendäre Seele")
	var display := _display()
	display.apply_definition(_def(DieDefinition.CHARGE_MAX, false, legendary))
	display._tick_heat()
	assert_ne(display.position, Vector3.ZERO, "geladen zittert er")
	assert_not_null(display.soul_motes, "die legendäre Seele funkt")
	assert_true(display.glow_pool.visible, "und wirft ihre Lache")

	display.effects_muted = true
	display._tick_heat()
	assert_eq(display.position, Vector3.ZERO, "stumm zittert nichts")
	assert_null(display.soul_motes, "und funkt nichts")
	assert_false(display.glow_pool.visible, "und keine Lache")
	assert_eq(display.shown_charge(), DieDefinition.CHARGE_MAX,
		"die LADUNG selbst bleibt - nur ihre Auflagen schweigen")

	display.effects_muted = false
	display._tick_heat()
	assert_ne(display.position, Vector3.ZERO, "und alles kommt zurück")
	assert_not_null(display.soul_motes)
	assert_true(display.glow_pool.visible)

## Ein STUMMER Würfel behält seine Stummheit über einen Neuaufbau der Anzeige -
## das Tray schreibt bei jeder Änderung neu.
func test_stumm_ueberlebt_ein_neues_apply_definition() -> void:
	var display := _display()
	display.effects_muted = true
	display.apply_definition(_def(DieDefinition.CHARGE_MAX))
	display._tick_heat()
	assert_eq(display.position, Vector3.ZERO, "auch frisch gesetzt bleibt er stumm")
