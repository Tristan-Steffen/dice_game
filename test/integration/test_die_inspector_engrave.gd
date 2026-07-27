extends GutTest
## Integrationstest der Werkzeug-zuerst-Gravur am echten View (Nodes gebaut):
## Aufnehmen, Ziel-Klicks, Anwenden in Quelle→Ziel-Richtung und Verbrauch;
## Abbruch verbraucht nichts; das Bord ist ohne Vorwahl bedienbar.

var view: DieInspectorView
## Die Zahlen-Schublade als Werkzeug-Bord der Station.
var drawer: SupplyDrawerView

func before_each() -> void:
	view = DieInspectorView.new()
	view.size = Vector2(1400, 1470)
	add_child_autofree(view)
	drawer = SupplyDrawerView.new()
	drawer.category = Engraving.CATEGORY_NUMBER
	add_child_autofree(drawer)
	view.set_drawers([drawer] as Array[SupplyDrawerView])
	view.run = GameRun.new_run()
	drawer.run = view.run
	view.run.grant_engraving(Engraving.chisel())
	view.show_die(_die())

func _die() -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = [5, 1, 2, 3, 4, 6]
	def.faces = faces
	return def

## Der Werkzeug-Platz liegt in der Vorrats-Schublade seiner Kategorie.
func _slot_for(engraving_id: String) -> Button:
	for entry in drawer.slots:
		if entry["id"] == engraving_id:
			return entry["button"]
	return null

func test_locked_editing_refuses_pickup_and_shows_the_round_message() -> void:
	# Während der Runde: der Würfel bleibt einsehbar, aber keine Gravur lässt sich
	# aufnehmen, das Bord ist gesperrt und die Info-Leiste meldet die Sperre.
	var info := RichTextLabel.new()
	add_child_autofree(info)
	view.set_prompt_label(info)
	view.set_editing_locked(true)
	assert_eq(info.text, DieInspectorView.ROUND_RUNNING_PROMPT, "die Leiste meldet die Sperre")
	view._on_engraving_pressed(Engraving.CHISEL)
	assert_eq(view.held_id, "", "gesperrt: kein Werkzeug lässt sich aufnehmen")
	assert_true(_slot_for(Engraving.CHISEL).disabled, "der besessene Platz ist gesperrt")

func test_unlocking_restores_the_usable_board() -> void:
	view.set_editing_locked(true)
	view.set_editing_locked(false)
	assert_false(_slot_for(Engraving.CHISEL).disabled, "entsperrt ist der Platz wieder nutzbar")
	view._on_engraving_pressed(Engraving.CHISEL)
	assert_eq(view.held_id, Engraving.CHISEL, "und die Gravur lässt sich wieder aufnehmen")

func test_pick_up_then_two_clicks_applies_and_consumes() -> void:
	view._on_engraving_pressed(Engraving.CHISEL)
	assert_eq(view.held_id, Engraving.CHISEL, "aufgenommen")
	view._on_chip_clicked(5, 0)  # Quelle (Wert 5)
	assert_eq(view.first_face, 0, "erster Klick ist die Quelle")
	view._on_chip_clicked(1, 1)  # Ziel
	assert_eq(view.current_def.faces[1], 5, "das Ziel erhält den Quellwert")
	assert_eq(view.held_id, "", "letztes Exemplar verbraucht -> Werkzeug abgelegt")
	assert_eq(view.run.owned_engravings.size(), 0, "Meißel verbraucht")

func test_tool_stays_held_while_copies_remain() -> void:
	# Zwei Kerben: nach der ersten Anwendung bleibt die Kerbe in der Hand
	# (direkt weitergravieren), nach der zweiten ist sie abgelegt.
	view.run.grant_engraving(Engraving.notch())
	view.run.grant_engraving(Engraving.notch())
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.NOTCH)
	view._on_chip_clicked(1, 1)
	assert_eq(view.current_def.faces[1], 2, "erste Kerbe angewandt")
	assert_eq(view.held_id, Engraving.NOTCH, "noch ein Exemplar -> bleibt in der Hand")
	assert_eq(view.mode, DieInspectorView.Mode.TARGETING)
	view._on_chip_clicked(2, 2)
	assert_eq(view.current_def.faces[2], 3, "zweite Kerbe angewandt")
	assert_eq(view.held_id, "", "letztes Exemplar verbraucht -> abgelegt")

func test_pair_tool_restarts_at_step_one_when_kept() -> void:
	# Meißel ×2: nach dem ersten Paar beginnt der nächste Durchgang wieder bei
	# der Quellseite (first_face zurückgesetzt).
	view.run.grant_engraving(Engraving.chisel())
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.CHISEL)
	view._on_chip_clicked(5, 0)
	view._on_chip_clicked(1, 1)
	assert_eq(view.held_id, Engraving.CHISEL, "zweites Exemplar -> bleibt in der Hand")
	assert_eq(view.first_face, -1, "das Paar beginnt von vorn")

func test_re_clicking_the_held_slot_puts_the_tool_down() -> void:
	view._on_engraving_pressed(Engraving.CHISEL)
	view._on_engraving_pressed(Engraving.CHISEL)
	assert_eq(view.held_id, "", "erneuter Klick legt ab")

func test_cancel_mid_pair_consumes_nothing() -> void:
	view._on_engraving_pressed(Engraving.CHISEL)
	view._on_chip_clicked(5, 0)
	view.cancel_pending()
	assert_eq(view.held_id, "", "abgelegt")
	assert_eq(view.current_def.faces, [5, 1, 2, 3, 4, 6] as Array[int], "nichts verändert")
	assert_eq(view.run.owned_engravings.size(), 1, "Meißel nicht verbraucht")

func test_whole_die_tool_applies_on_a_single_face_click() -> void:
	view.run.grant_engraving(Engraving.polish())
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.POLISH)
	view._on_chip_clicked(2, 2)  # ein Klick auf irgendeine Seite genügt
	assert_eq(view.current_def.faces, [6, 2, 3, 4, 5, 7] as Array[int], "alle Seiten +1")
	assert_eq(view.held_id, "", "Werkzeug abgelegt")

func test_board_slot_is_enabled_without_a_face_selection() -> void:
	# Werkzeug-zuerst: die besessene Gravur ist anklickbar, ohne dass vorher eine
	# Seite gewählt wurde.
	assert_false(_slot_for(Engraving.CHISEL).disabled, "Meißel-Slot ist bedienbar")

func test_edge_tool_applies_via_the_frame() -> void:
	# Kanten-Gravur aufnehmen, in den Rahmen um die Seiten klicken -> Kanten
	# veredelt, Gravur verbraucht. Keine Kanten-Auswahl nötig (es gibt nur einen).
	view.run.grant_engraving(Engraving.edge_engraving(DieMaterial.gold(), Engraving.Rarity.UNCOMMON))
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.EDGE_PREFIX + DieMaterial.GOLD)
	view._handle_edge_target()
	assert_eq(view.current_def.edge_material, DieMaterial.GOLD, "Rahmen trägt Gold")
	assert_eq(view.held_id, "", "Werkzeug abgelegt")

func test_edge_frame_glows_while_an_edge_tool_is_held() -> void:
	view.run.grant_engraving(Engraving.edge_engraving(DieMaterial.gold(), Engraving.Rarity.UNCOMMON))
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.EDGE_PREFIX + DieMaterial.GOLD)
	var box: StyleBoxFlat = view.edge_frame.get_theme_stylebox("panel")
	assert_eq(box.border_color, RotatableDieView.SELECT_FACE_COLOR, "Rahmen leuchtet als Ziel")

func test_edge_frame_preview_tints_to_the_new_material() -> void:
	view.run.grant_engraving(Engraving.edge_engraving(DieMaterial.gold(), Engraving.Rarity.UNCOMMON))
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.EDGE_PREFIX + DieMaterial.GOLD)
	view._preview_edge_frame(Engraving.EDGE_PREFIX + DieMaterial.GOLD)
	var box: StyleBoxFlat = view.edge_frame.get_theme_stylebox("panel")
	assert_eq(box.border_color, DieMaterial.tint_for(DieMaterial.GOLD), "Vorschau = neue Materialfarbe")
	view._clear_preview()
	var restored: StyleBoxFlat = view.edge_frame.get_theme_stylebox("panel")
	assert_eq(restored.border_color, RotatableDieView.SELECT_FACE_COLOR, "Ende der Vorschau -> Ziel-Glow zurück")
	assert_eq(view.current_def.edge_material, "", "nichts angewandt")

func test_face_order_stays_frozen_while_editing() -> void:
	# Beim Öffnen nach Wert sortiert: [5,1,2,3,4,6] -> Indizes [1,2,3,4,0,5].
	assert_eq(view.face_order, [1, 2, 3, 4, 0, 5] as Array[int])
	view.run.grant_engraving(Engraving.notch())
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.NOTCH)
	view._on_chip_clicked(1, 1)  # die 1 wird zur 2
	assert_eq(view.current_def.faces[1], 2)
	assert_eq(view.face_order, [1, 2, 3, 4, 0, 5] as Array[int],
		"beim Gravieren springen die Chips nicht um")

func test_face_order_resorts_for_a_newly_shown_die() -> void:
	var def := DieDefinition.new()
	var faces: Array[int] = [6, 5, 4, 3, 2, 1]
	def.faces = faces
	view.show_die(def)
	assert_eq(view.face_order, [5, 4, 3, 2, 1, 0] as Array[int],
		"neues Ziel -> wieder aufsteigend nach Wert")

func test_has_pending_action_tracks_the_held_tool() -> void:
	assert_false(view.has_pending_action(), "anfangs nichts in der Hand")
	view._on_engraving_pressed(Engraving.CHISEL)
	assert_true(view.has_pending_action(), "Werkzeug aufgenommen")
	view.cancel_pending()
	assert_false(view.has_pending_action(), "abgelegt")

func test_the_pointer_applies_source_to_adjacent_target() -> void:
	view.run.grant_engraving(Engraving.pointer_engraving())
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.POINTER)
	assert_eq(view.held_id, Engraving.POINTER, "aufgenommen")
	view._on_chip_clicked(5, 0)  # Startseite
	assert_eq(view.first_face, 0, "erster Klick ist die Startseite")
	view._on_chip_clicked(6, 5)  # Gegenseite von 0: kein gültiges Ziel
	assert_eq(view.current_def.pointers[0], -1, "die Gegenseite wird verweigert")
	assert_eq(view.first_face, 0, "der erste Klick bleibt stehen")
	view._on_chip_clicked(1, 1)  # Nachbar
	assert_eq(view.current_def.pointers[0], 1, "Leiterbahn gelegt")
	assert_eq(view.held_id, "", "letztes Exemplar verbraucht -> abgelegt")

func test_a_new_pointer_overwrites_the_faces_old_one() -> void:
	view.current_def.pointers[0] = 1
	view.run.grant_engraving(Engraving.pointer_engraving())
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.POINTER)
	view._on_chip_clicked(5, 0)
	view._on_chip_clicked(3, 3)
	assert_eq(view.current_def.pointers[0], 3, "je Seite höchstens eine Bahn - überschrieben")
