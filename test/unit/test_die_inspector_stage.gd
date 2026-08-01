extends GutTest
## Tests der Bühne in der Gravur-Station (DieInspectorView): dort schwebt der
## ECHTE Würfel - eine flache Projektion daneben gibt es NICHT mehr. Die Station
## hält nur noch den Ablauf: scene_root pickt Seite und Kante am schwebenden
## Würfel und meldet sie über click_face/click_edges/set_die_hover herein;
## zurück gehen Auswahl (selection_changed) und Eignung (dimmed_faces).

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
	var materials: Array[String] = ["ruby", "", "gold", "glass", "", "bone"]
	def.materials = materials
	def.essence_id = Essence.NEON
	return def

func _count_type(node: Node, type: String) -> int:
	var found := 0
	if node.is_class(type):
		found += 1
	for child in node.get_children():
		found += _count_type(child, type)
	return found

func test_the_station_shows_no_flat_projection_any_more() -> void:
	# Der schwebende Würfel IST die Ansicht - kein zweites Bild daneben.
	assert_eq(_count_type(view, "SubViewportContainer"), 0, "keine Projektion mehr")
	assert_eq(_count_type(view, "SubViewport"), 0, "und kein Unter-Bildschirm dafür")

func test_the_stage_takes_the_room_the_net_leaves() -> void:
	# Die Bühne ist der Platz des Werkstücks: sie sitzt oben in der linken Spalte
	# und dehnt sich, das Seiten-Netz sitzt darunter am Fuß.
	var left: Control = view.stage.get_parent()
	assert_eq(left.name, "LeftColumn", "die Bühne hängt direkt in der Spalte")
	assert_eq(view.stage.size_flags_vertical, Control.SIZE_EXPAND_FILL)
	assert_lt(view.stage.get_index(), view.summary_list.get_index(),
		"oben das Werkstück, darunter sein Netz")
	assert_gt(view.stage.size.y, view.size.y * DieInspectorView.STAGE_FRACTION * 0.9,
		"und sie bekommt mindestens ihren Mindestanteil")

func test_clicking_a_face_of_the_floating_die_selects_it() -> void:
	view.click_face(3)
	assert_eq(view.selected_face, 3, "der Klick am Werkstück wählt die Seite")

func test_clicking_the_edges_without_a_tool_does_nothing() -> void:
	# Es gibt nur EINEN Kanten-Rahmen - ohne gehaltene Gravur ist da nichts zu
	# wählen; der Klick verpufft.
	view.click_edges()
	assert_eq(view.selected_face, -1)
	assert_eq(view.held_id, "")

func test_selection_changed_reports_the_selected_face() -> void:
	# selection_changed treibt die violette Hervorhebung am schwebenden Würfel
	# (siehe scene_root._highlight_engraving_die).
	var events: Array = []
	view.selection_changed.connect(func(face: int) -> void: events.append(face))
	view.click_face(2)
	assert_eq(events.back(), 2, "die gewählte Seite wird gemeldet")

func test_the_second_pair_step_accepts_a_click_on_the_floating_die() -> void:
	# Werkzeug-zuerst: Meißel aufnehmen, Quellseite am Würfel klicken, dann das Ziel.
	view.run = GameRun.new_run()
	view.run.grant_engraving(Engraving.chisel())
	view._on_engraving_pressed(Engraving.CHISEL)
	view.click_face(4)  # Quelle (Wert 5)
	assert_eq(view.first_face, 4, "erster Klick ist die Quelle")
	view.click_face(1)  # Ziel
	assert_eq(view.current_def.faces[1], 5, "das Ziel trägt den Quellwert")
	assert_eq(view.held_id, "", "nach dem Anwenden ist nichts mehr in der Hand")

func test_without_a_tool_nothing_is_dimmed() -> void:
	assert_eq(view.dimmed_faces(), _all_false(), "in der Inspektion ist jede Seite hell")

func test_a_held_tool_dims_the_faces_it_cannot_reach() -> void:
	# Die Feile kann keine Seite auf dem Mindestwert weiter senken - Seite 0
	# (Wert 1) ist ihr einziges verbotenes Ziel.
	view.run = GameRun.new_run()
	view.run.grant_engraving(Engraving.file_down())
	view._on_engraving_pressed(Engraving.FILE_DOWN)
	var dim := view.dimmed_faces()
	assert_true(dim[0], "die 1 lässt sich nicht weiter feilen")
	for i in range(1, 6):
		assert_false(dim[i], "jede andere Seite bleibt Ziel")

func test_the_first_pair_click_stays_bright() -> void:
	# Die gewählte Quelle leuchtet violett - sie darf nicht zugleich gedimmt sein.
	view.run = GameRun.new_run()
	view.run.grant_engraving(Engraving.chisel())
	view._on_engraving_pressed(Engraving.CHISEL)
	view.click_face(2)
	assert_false(view.dimmed_faces()[2], "der erste Paar-Klick bleibt hell")

func test_the_floating_die_beats_the_chip_under_the_pointer() -> void:
	# Der Würfel meldet je Frame, der Chip nur bei Wechsel: ohne Vorrang löschte
	# der Frame-Takt den gerade betretenen Chip wieder.
	view._on_face_hover(1)
	assert_eq(view.hovered_face, 1, "der Chip führt, solange nichts am Würfel liegt")
	view.set_die_hover(4)
	assert_eq(view.hovered_face, 4, "das Werkstück schlägt den Chip")
	view.set_die_hover(-1)
	assert_eq(view.hovered_face, 1, "verlässt der Zeiger den Würfel, gilt wieder der Chip")
	view._on_face_hover_exit()
	assert_eq(view.hovered_face, -1)

func _all_false() -> Array[bool]:
	var none: Array[bool] = []
	none.resize(6)
	none.fill(false)
	return none
