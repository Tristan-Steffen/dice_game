extends SceneTree
## EINGABE-PROBE des Grundrisses im echten Spiel (Welle 7 Teil C): echte Maus-Ereignisse über
## Input.parse_input_event an Bildschirm-Positionen, die aus der Projektion der Ziel-Pixel
## gerechnet sind. Je Schritt eine Zeile PASS/FAIL samt Meßwerten. Aufruf:
##   Godot --path . --fixed-fps 60 --resolution 1280x720 --position 4000,2400 --quit-after 1200 \
##     --script tools/godot_floor_plan_input_probe.gd

var game: Node
var frame := 0
var start := -1
var target_room := ""
var press_at := Vector2.ZERO
var before_center := Vector2.ZERO
var before_zoom := 0.0
var before_moves := 0
var fails := 0
## Was der weitergereichte Zeiger in der Nahsicht traf, Bild für Bild (der echte Mauszeiger steht
## off-screen woanders, und der Abgleich je Bild räumt den Hover darum gleich wieder ab).
var hovers: Array = []
## Schräg nach unten rechts: so schiebt der Zug auch, wenn eine Achse ganz ins Bild paßt.
const DRAG_DIR := Vector2(0.6, 0.8)

func _initialize() -> void:
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game

func _rig() -> CameraRig:
	return game.get("camera_rig")

func _screen() -> TableScreen:
	return game.get("table_screen")

func _detail() -> FloorPlanView:
	return game.get("floor_detail")

## Display-Pixel → Bildschirm-Position über die echte Kamera.
func _to_screen(display_px: Vector2) -> Vector2:
	return root.get_viewport().get_camera_3d().unproject_position(_screen().pixel_to_world(display_px))

## Viewport-Koordinaten (Projektion) → Fenster-Koordinaten, wie das Betriebssystem sie meldet:
## das Projekt streckt 1280 × 900 auf das Fenster (canvas_items/expand).
func _to_window(at: Vector2) -> Vector2:
	return root.get_final_transform() * at

func _move(at: Vector2, mask: int = 0) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _to_window(at)
	ev.global_position = ev.position
	ev.button_mask = mask
	_send(ev)

func _button(at: Vector2, index: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = _to_window(at)
	ev.global_position = ev.position
	ev.button_index = index
	ev.pressed = pressed
	if pressed and index == MOUSE_BUTTON_LEFT:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	_send(ev)

## Der echte Weg eines Betriebssystem-Ereignisses: Input puffert, dann das Fenster.
func _send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)

func _report(step: String, ok: bool, values: String) -> void:
	if not ok:
		fails += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", step, values])

## Ein Punkt im gangbaren Raum, fern jeder Tür, in Display-Pixeln.
func _room_display_point(room_id: String) -> Vector2:
	var detail := _detail()
	var rect := detail.geometry().room_rect(room_id)
	for fy in [0.45, 0.3, 0.6]:
		for fx in [0.5, 0.3, 0.7]:
			var local := rect.position + rect.size * Vector2(fx, fy)
			if detail.map_rect().has_point(local) and detail.target_at(local).get("kind", "") == "room":
				return detail.position + local
	return detail.position + rect.get_center()

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		game.call("_on_title_new_game")
	if start < 0:
		if frame > 120 and not _rig().is_animating:
			start = frame
		return frame > 1150
	var t := frame - start
	var run: GameRun = game.get("run")
	var detail := _detail()
	match t:
		10:
			var pit := Rect2(_screen().pit_window.position, _screen().pit_window.size)
			var at := _to_screen(pit.get_center())
			_move(at)
		40:
			# Die Übersicht neigt sich mit dem Zeiger: erst setzen, dann am neuen Ort klicken.
			var pit := Rect2(_screen().pit_window.position, _screen().pit_window.size)
			var at := _to_screen(pit.get_center())
			_move(at)
			_button(at, MOUSE_BUTTON_LEFT, true)
		42:
			var pit := Rect2(_screen().pit_window.position, _screen().pit_window.size)
			_button(_to_screen(pit.get_center()), MOUSE_BUTTON_LEFT, false)
		200:
			_report("1 Klick auf die Grube", _rig().mode == CameraRig.Mode.PIT and detail.visible
				and not _rig().is_animating,
				"Station %s, Nahsicht %s, Runde %d, route_pending %s" % [CameraRig.Mode.keys()[_rig().mode],
				detail.visible, run.round_number, game.get("route_pending")])
			for move in detail.walkable_moves():
				target_room = String(move["room"])
				if String(move["fire_door"]) == "":
					break
			press_at = _to_screen(_room_display_point(target_room))
			detail.hover_changed.connect(func() -> void:
				if not detail.hovered().is_empty():
					hovers.append([detail.hovered(), detail.info_parts()]))
			_move(press_at)
		202, 204, 206:
			# Ein echter Zeiger meldet sich in jedem Bild, in dem er sich rührt.
			_move(press_at + Vector2(0.5 * (t - 200), 0.0))
		210:
			var hover: Dictionary = hovers[0][0] if not hovers.is_empty() else {}
			var info: Dictionary = hovers[0][1] if not hovers.is_empty() else detail.info_parts()
			var room_name := String(detail.geometry().rooms[target_room]["name"])
			_report("2 Zeiger über gangbarem Raum", hover.get("id", "") == target_room
				and String(info["title"]).contains(room_name),
				"Ziel %s (%s) bei %s, Hover %s, Auskunft „%s“" % [target_room, room_name, press_at, hover,
				info["title"]])
			# Erst hinein (das geht immer), dann ist auf jeder Etage Platz zum Schieben.
			before_zoom = detail.zoom_cell()
			_button(press_at, MOUSE_BUTTON_WHEEL_UP, true)
			_button(press_at, MOUSE_BUTTON_WHEEL_UP, false)
		212:
			_button(press_at, MOUSE_BUTTON_WHEEL_UP, true)
			_button(press_at, MOUSE_BUTTON_WHEEL_UP, false)
		214:
			_report("3 Rad", absf(detail.zoom_cell() - before_zoom) > 0.5 and detail.away_from_home(),
				"Zoom %.1f → %.1f px je Zelle, Knopf Zum Standort %s" % [before_zoom, detail.zoom_cell(),
				detail.find_child("ToHome", true, false).visible])
			before_center = detail.view_center()
			before_moves = run.floor_moves
			_button(press_at, MOUSE_BUTTON_LEFT, true)
		215, 216, 217, 218, 219, 220:
			_move(press_at + DRAG_DIR * 12.0 * (t - 214), MOUSE_BUTTON_MASK_LEFT)
		222:
			_button(press_at + DRAG_DIR * 72.0, MOUSE_BUTTON_LEFT, false)
		226:
			var shift := detail.view_center() - before_center
			_report("4 Drücken-Ziehen-Loslassen 72 px", shift.length() > 0.05 and run.floor_moves == before_moves
				and bool(game.get("route_pending")),
				"Ausschnitt verschoben um %s Zellen, floor_moves %d → %d, route_pending %s" % [shift, before_moves,
				run.floor_moves, game.get("route_pending")])
			_button(press_at, MOUSE_BUTTON_RIGHT, true)
			_button(press_at, MOUSE_BUTTON_RIGHT, false)
		260:
			var home: Array = detail.home_view()
			_report("5 erster Rechtsklick", not detail.away_from_home() and _rig().mode == CameraRig.Mode.PIT
				and detail.visible,
				"Zoom %.1f (Heimat %.1f), Mitte %s (Heimat %s), Station %s, Nahsicht %s" % [detail.zoom_cell(),
				float(home[1]), detail.view_center(), home[0], CameraRig.Mode.keys()[_rig().mode], detail.visible])
			press_at = _to_screen(_room_display_point(target_room))
			before_moves = run.floor_moves
			_move(press_at)
		266:
			_button(press_at, MOUSE_BUTTON_LEFT, true)
		268:
			_button(press_at, MOUSE_BUTTON_LEFT, false)
		330:
			var beckon := _screen().pit_beckon
			var title := (beckon.get_child(0) as Label).text if beckon != null else ""
			_report("6 kurzer Klick auf den Raum", run.floor_moves > before_moves and not bool(game.get("route_pending"))
				and not detail.visible and beckon.visible and title == TableScreen.PIT_BECKON_TITLE,
				"floor_moves %d → %d, Standort %s, route_pending %s, Nahsicht %s, Lockruf %s „%s“" % [before_moves,
				run.floor_moves, run.floor_plan.position, game.get("route_pending"), detail.visible, beckon.visible,
				title])
			print("EINGABE-PROBE: %d Fehler" % fails)
			return true
	return false
