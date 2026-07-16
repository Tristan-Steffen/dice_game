extends GutTest
## Tests der drehbaren 3D-Projektion in der Gravur-Station (DieInspectorView):
## rechts neben der Bühne sitzt ein RotatableDieView auf seinem eigenen kleinen
## Unter-Bildschirm (Rahmen + abgesetzte Grundfarbe). Klicks auf seine Seiten/
## Kanten laufen in DIESELBE Auswahl-Logik wie die Seiten-Chips, die Auswahl
## spiegelt sich als violette Hervorhebung zurück (Ziffer bzw. Kanten-Rahmen,
## siehe _sync_die_view).

var view: DieInspectorView

func before_each() -> void:
	view = DieInspectorView.new()
	view.size = Vector2(1400, 1470)
	add_child_autofree(view)
	view.show_die(_die())

func _die() -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = [1, 2, 3, 4, 5, 6]
	def.faces = faces
	var materials: Array[String] = ["ruby", "", "gold", "glass", "", "mercury"]
	def.materials = materials
	def.edge_material = "amber"
	return def

func test_projection_is_built_next_to_the_stage() -> void:
	assert_not_null(view.die_view, "die Projektion ist gebaut")
	assert_not_null(view.die_view_panel, "... auf ihrem eigenen Unter-Bildschirm")
	var stage_row: Control = view.stage.get_parent()
	assert_eq(stage_row.name, "StageRow", "Bühne und Projektion teilen sich eine Reihe")
	assert_true(view.die_view_panel.get_parent() == stage_row)
	assert_lt(view.stage.get_index(), view.die_view_panel.get_index(),
		"die Bühne (echter Würfel) sitzt LINKS, die Projektion RECHTS daneben")
	assert_eq(view.die_view.die_roots.size(), 1, "die Projektion zeigt genau den bearbeiteten Würfel")

func test_projection_screen_has_border_and_distinct_background() -> void:
	var style: StyleBoxFlat = view.die_view_panel.get_theme_stylebox("panel")
	assert_eq(style.bg_color, DieInspectorView.DIE_VIEW_BG,
		"eigene, von den Fenstern abgesetzte Grundfarbe")
	assert_gt(style.border_width_top, 0, "eigener Rahmen")
	assert_ne(style.bg_color, HubView.FRAME_BG, "bewusst NICHT die normale Fensterfarbe")

func test_projection_viewport_is_isolated_and_transparent() -> void:
	var sub: SubViewport = view.die_view.viewport
	assert_true(sub.own_world_3d, "eigene Welt - die Vorschau-Kamera filmt nicht den Tisch")
	assert_true(sub.transparent_bg, "der Unter-Bildschirm liefert den Grund")

func test_clicking_a_projected_face_selects_that_face() -> void:
	view.die_view.face_clicked.emit(0, 3)
	assert_eq(view.selected_face, 3, "Klick auf die projizierte Seite wählt sie")
	assert_false(view.edges_selected)

func test_clicking_the_projected_edges_selects_the_edges() -> void:
	view.die_view.edges_clicked.emit(0)
	assert_true(view.edges_selected, "Klick auf den projizierten Kanten-Rahmen wählt die Kanten")
	assert_eq(view.selected_face, -1)

func test_selection_highlights_the_projected_face_number() -> void:
	view._on_face_clicked(0, 1)  # Seite 1 trägt kein Material (Körper bleibt weiß)
	var faces: DieFaceDisplay = view.die_view.die_roots[0].get_node("RigidBody3D/Faces")
	# Nur die ZIFFER der gewählten Seite leuchtet violett - der Körper bleibt neutral.
	var selected_axis := ""
	for axis in DiceController.AXIS_FACE_INDEX:
		if DiceController.AXIS_FACE_INDEX[axis] == 1:
			selected_axis = axis
	var label: Label3D = faces.labels[selected_axis]
	assert_eq(label.modulate, RotatableDieView.SELECT_FACE_COLOR,
		"die gewählte projizierte Ziffer leuchtet violett")
	var quad: MeshInstance3D = faces.quads[selected_axis]
	var material: StandardMaterial3D = quad.get_surface_override_material(0)
	assert_eq(material.albedo_color, DieFaceDisplay.BODY_COLOR,
		"der Würfelkörper der gewählten Seite bleibt neutral")

func test_chip_selection_also_highlights_the_projection() -> void:
	# Auswahl über die SEITEN-CHIPS spiegelt sich in die Projektion (eine Logik).
	view._on_chip_clicked(4, 3)  # Wert 4 = face_index 3
	var faces: DieFaceDisplay = view.die_view.die_roots[0].get_node("RigidBody3D/Faces")
	var axis := ""
	for candidate in DiceController.AXIS_FACE_INDEX:
		if DiceController.AXIS_FACE_INDEX[candidate] == 3:
			axis = candidate
	var label: Label3D = faces.labels[axis]
	assert_eq(label.modulate, RotatableDieView.SELECT_FACE_COLOR)

func test_edge_selection_highlights_the_projected_frame() -> void:
	view._on_edges_clicked()
	var faces: DieFaceDisplay = view.die_view.die_roots[0].get_node("RigidBody3D/Faces")
	assert_eq(faces.edge_material_res.albedo_color,
		DieFaceDisplay.BODY_COLOR * RotatableDieView.SELECT_FACE_COLOR,
		"der projizierte Kanten-Rahmen leuchtet gold")

func test_dragging_the_projection_reports_rotating_die() -> void:
	# Ziehen an der Projektion meldet rotating_die(true)/(false) - scene_root
	# sperrt daraufhin das Kamera-Rundschauen (siehe CameraRig.set_tilt_locked),
	# damit die Ziehbewegung nicht zugleich den Blick schwenkt. Die Werte selbst
	# aufzeichnen (GUTs Signal-Parameter-Diff stolpert über bool-Parameter).
	var events: Array = []
	view.rotating_die.connect(func(active: bool) -> void: events.append(active))
	# Maus drücken, dann WEIT genug ziehen (über DRAG_THRESHOLD) und loslassen.
	_press(view.die_view, Vector2(50, 50), true)
	_motion(view.die_view, Vector2(50, 50), Vector2(80, 60))  # > DRAG_THRESHOLD
	assert_eq(events, [true], "Ziehbeginn sperrt die Kamera")
	_press(view.die_view, Vector2(80, 60), false)
	assert_eq(events, [true, false], "Loslassen gibt die Kamera wieder frei")

func test_a_pure_click_does_not_lock_the_camera() -> void:
	# Ein Klick OHNE nennenswertes Ziehen ist eine Auswahl, keine Dreh-Geste -
	# rotating_die darf dabei nicht feuern.
	var events: Array = []
	view.rotating_die.connect(func(active: bool) -> void: events.append(active))
	_press(view.die_view, Vector2(50, 50), true)
	_press(view.die_view, Vector2(51, 50), false)  # kaum bewegt
	assert_eq(events, [], "ein reiner Klick sperrt nichts")

func test_selection_changed_reports_the_selected_face() -> void:
	# selection_changed treibt die violette Hervorhebung am ECHTEN schwebenden
	# Würfel über dem Hub (siehe scene_root._highlight_engraving_die). bool-Parameter
	# selbst aufzeichnen (GUTs Signal-Parameter-Diff stolpert darüber).
	var events: Array = []
	view.selection_changed.connect(func(face: int, edges: bool) -> void: events.append([face, edges]))
	view._on_face_clicked(0, 2)
	assert_eq(events.back(), [2, false], "die gewählte Seite wird gemeldet (keine Kanten)")

func test_selection_changed_reports_the_edges() -> void:
	var events: Array = []
	view.selection_changed.connect(func(face: int, edges: bool) -> void: events.append([face, edges]))
	view._on_edges_clicked()
	assert_eq(events.back(), [-1, true], "die Kanten-Auswahl wird gemeldet (keine Seite)")

func _press(target: Control, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	target._gui_input(ev)

func _motion(target: Control, from: Vector2, to: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = to
	ev.relative = to - from
	target._gui_input(ev)

func test_second_face_step_accepts_a_projected_face_click() -> void:
	# Zweitschritt einer Ätzung (z.B. Meißel): der Klick auf die Projektion
	# liefert die zweite Seite - wie ein Chip-Klick.
	view.run = GameRun.new_run()
	view.run.grant_sigil(Sigil.chisel())
	view._on_face_clicked(0, 1)
	view.mode = DieInspectorView.Mode.AWAIT_SECOND_FACE
	view.active_sigil_id = Sigil.CHISEL
	view.die_view.face_clicked.emit(0, 4)
	# Meißel: Quelle (4) wird auf Ziel (1) gemeißelt - der Modus löst sich auf.
	assert_eq(view.mode, DieInspectorView.Mode.SELECT, "der Zweitschritt ist aufgelöst")
