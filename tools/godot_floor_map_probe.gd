extends SceneTree
## Sichtprobe des TURMS (Welle 5 der Etagen-Karte): im Maß des echten Hubs (1068 × 1125)
## (1) die Startseite in Etage 1 mit fälligem Zug, (2) mitten in Etage 3 über zwei
## geschafften Etagen mit gesperrter und freier Tür, Hover auf einem gangbaren Raum und
## einem Diagramm über zehn Runden im Millionenbereich, (3) die große Karte, (4) das echte
## Spiel an der Hub-Station. Gemessen werden die Schriftgrade (Display- und Bildschirm-px).
## Aufruf: --path . --resolution 1280x720 --position 4000,2400 --quit-after 600
##   --script tools/godot_floor_map_probe.gd

const OUT := "E:/Generated Images/Fumble/etagen_turm_2026-11-27/"
const HUB_SIZE := Vector2i(1068, 1125)

var game: Node
var frame := 0
var start := -1
var _viewport: SubViewport
var _hub: HubView
var _page: FloorMapPage
var _studio: GameRun

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	_viewport = SubViewport.new()
	_viewport.size = HUB_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var ground := ColorRect.new()
	ground.color = Color("#0b1712")
	ground.size = Vector2(HUB_SIZE)
	_viewport.add_child(ground)
	_hub = HubView.new()
	_hub.size = Vector2(HUB_SIZE)
	_viewport.add_child(_hub)
	_hub.layout()
	_page = FloorMapPage.new()
	_hub.attach_panel(_page)
	_page.layout()

func _rig() -> CameraRig:
	return game.get("camera_rig")

func _shot_hub(file: String) -> void:
	_viewport.get_texture().get_image().save_png(OUT + file)
	print("Bild: ", OUT + file)

## Hub-Stand aus einem Lauf - dieselben Aufrufe wie scene_root._refresh_hub_info.
func _feed(run: GameRun, flash: String = "") -> void:
	_hub.set_floor_state(run.floor_view_state(), run.deal_bonus_factor(), flash)
	var saved: GameRun = game.get("run")
	game.set("run", run)
	_hub.set_run_values(game.call("_run_value_entries"))
	game.set("run", saved)
	_hub.set_chart(run.run_chart())

func _sizes(node: Node, tag: String) -> void:
	var by: Dictionary = {}
	for child in node.find_children("*", "Label", true, false):
		var label := child as Label
		if label.text == "" or not label.is_visible_in_tree():
			continue
		var kind := String(label.name).split("_")[0]
		var px := label.get_theme_font_size("font_size")
		var span: Vector2i = by.get(kind, Vector2i(9999, 0))
		by[kind] = Vector2i(mini(span.x, px), maxi(span.y, px))
	print("SCHRIFT ", tag, " ", by)

## Ein Zug Richtung Büro (gangbar, kürzester Weg).
func _step(run: GameRun) -> void:
	var map := run.floor_map
	run.move_due = true
	var here := map.position
	for entry in map.doors_from(here):
		if not map.passable(entry):
			continue
		var next := map.other_side(entry, here)
		if map.shortest_moves(next, map.office) == map.shortest_moves(here, map.office) - 1:
			run.move_through(String(entry["id"]))
			return

## Eine Etage bis ins Büro gehen und abrechnen.
func _clear_floor(run: GameRun) -> void:
	while run.floor_map.position != run.floor_map.office:
		_step(run)
	run.settle_block_deals()

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		game.call("_on_title_new_game")
	if start < 0:
		if frame > 120 and not _rig().is_animating:
			start = frame
		return frame > 590
	var t := frame - start
	var run: GameRun = game.get("run")
	var screen: TableScreen = game.get("table_screen")
	match t:
		2:
			# (1) Etage 1, Runde 2: ein Zug ist fällig.
			_studio = GameRun.new_run()
			_studio.round_points = 620
			_studio.advance_round()
			_feed(_studio)
		10:
			_shot_hub("1_startseite_etage1_zug_faellig.png")
			_sizes(_hub, "startseite")
		12:
			# (2) Zwei Etagen geschafft, mitten in Etage 3, Zahlen im Millionenbereich.
			_clear_floor(_studio)
			_clear_floor(_studio)
			_step(_studio)
			_step(_studio)
			_studio.move_due = true
			var map := _studio.floor_map
			for entry in map.doors_from(map.position):
				if int(entry["state"]) == FloorMap.DoorState.OPEN and not map.is_office_door(entry):
					entry["free"] = true
					entry["malus"] = ""
					break
			var locked := ""
			for entry in map.lock_candidates():
				if not map.is_office_door(entry) and not bool(entry["free"]):
					entry["state"] = FloorMap.DoorState.LOCKED
					locked = String(entry["id"])
					break
			var blinds: Array[int] = []
			var scores: Array[int] = []
			for i in 10:
				blinds.append(int(180.0 * pow(4.1, i)))
				scores.append(int(520.0 * pow(4.4, i)))
			_studio.blind_history = blinds
			_studio.round_scores = scores
			# Der laufende Blind setzt die Reihe fort (sonst bräche die Linie ab).
			_studio.blind_value = float(blinds[-1]) * 3.2
			_studio.round_goal = GameRun.floor_to_blind(_studio.blind_value)
			_studio.best_hand = 2_400_000
			_studio.farkle_count = 7
			_feed(_studio, locked)
			var walk: Array = _studio.floor_view_state()["walkable"]
			var target := map.other_side(map.door(String(walk[0])), map.position)
			_hub.floor_map.hover_at(_hub.floor_map.room_rect(target).get_center())
		24:
			_shot_hub("2_startseite_etage3_geschichte_hover.png")
			_sizes(_hub, "mitten")
			print("STREIFEN etagen sichtbar ", _hub.floor_map.visible_floors(),
				" kacheln ", _hub.floor_map.visible_room_keys().size(), " u ", _hub.floor_map.unit())
		26:
			# (3) Die große Karte von der Startseite.
			_page.open_from(false)
			_page.show_state(_studio.floor_view_state())
			_page.visible = true
		30:
			var map := _studio.floor_map
			for entry in map.doors_from(map.position):
				if int(entry["state"]) == FloorMap.DoorState.OPEN and bool(entry["scouted"]):
					_page.map_view.hover_at(_page.map_view.door_mark_rect(String(entry["id"])).get_center())
					break
		40:
			_shot_hub("3_grosse_karte.png")
			_sizes(_page.map_view, "grosse_karte")
			# (4) Das echte Spiel: Runde 2 mit fälligem Zug, Kamera an der Hub-Station.
			run.round_points = 480
			run.advance_round()
			game.call("_start_new_round")
			_rig().zoom_to(CameraRig.Mode.HUB)
		200:
			root.get_texture().get_image().save_png(OUT + "4_spiel_hub_station.png")
			print("Bild: ", OUT + "4_spiel_hub_station.png")
			var hub := screen.hub
			var camera := root.get_camera_3d()
			var a := hub.floor_map.get_global_rect().position
			var b := a + Vector2(100.0, 0.0)
			var pa := camera.unproject_position(screen.pixel_to_world(a))
			var pb := camera.unproject_position(screen.pixel_to_world(b))
			print("BILDSCHIRM je Display-px ", pa.distance_to(pb) / 100.0, " hub ", hub.size,
				" streifen ", hub.floor_map.size)
			_sizes(hub, "spiel")
			print("ROUTE_PENDING ", game.get("route_pending"), " walk ", run.walkable_doors().size())
			quit()
	return false
