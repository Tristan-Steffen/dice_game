extends SceneTree
## Sichtprobe der ETAGEN-KARTE auf der HUB-STARTSEITE (Welle 3): im Maß des echten Hubs
## (1068 × 1125) Etagen-Beginn mit fälligem Zug, mitten in der Etage mit gesperrter und
## freier Tür samt Hover, die Etagen-Seite des Ladens - und ein Bild aus dem echten Spiel
## an der Hub-Station. Gemessen werden die Schriftgrade (Display- und Bildschirm-px).
## Aufruf: --path . --fixed-fps 60 --resolution 1280x720 --position 4000,2400 --quit-after 1500
##   --script tools/godot_floor_map_probe.gd

const OUT := "E:/Generated Images/Fumble/etagen_karte_hub_2026-11-27/"
const HUB_SIZE := Vector2i(1068, 1125)

var game: Node
var frame := 0
var start := -1
var _viewport: SubViewport
var _hub: HubView
var _page: FloorMapPage

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

func _sizes(map: FloorMapView, tag: String) -> void:
	var by: Dictionary = {}
	for child in map.get_children():
		var label := child as Label
		if label == null or label.text == "":
			continue
		var kind := String(label.name).split("_")[0]
		var px := label.get_theme_font_size("font_size")
		var span: Vector2i = by.get(kind, Vector2i(9999, 0))
		by[kind] = Vector2i(mini(span.x, px), maxi(span.y, px))
	print("SCHRIFT ", tag, " karte ", map.size, " ", by)

## Mitten in der Etage: zwei Züge Richtung Büro, eine freie und eine gesperrte Tür.
func _mid_floor(run: GameRun) -> String:
	var map := run.floor_map
	for i in 2:
		var here := map.position
		for entry in map.doors_from(here):
			var next := map.other_side(entry, here)
			if map.shortest_moves(next, map.office) == map.shortest_moves(here, map.office) - 1:
				run.move_through(String(entry["id"]))
				break
		run.move_due = true
	for entry in map.doors_from(map.position):
		if int(entry["state"]) == FloorMap.DoorState.OPEN and not map.is_office_door(entry):
			entry["free"] = true
			entry["malus"] = ""
			break
	for entry in map.lock_candidates():
		if not map.is_office_door(entry) and not bool(entry["free"]):
			entry["state"] = FloorMap.DoorState.LOCKED
			return String(entry["id"])
	return ""

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		game.call("_on_title_new_game")
	if start < 0:
		if frame > 120 and not _rig().is_animating:
			start = frame
		return frame > 1450
	var t := frame - start
	var run: GameRun = game.get("run")
	var screen: TableScreen = game.get("table_screen")
	match t:
		2:
			# Studio: Etagen-Beginn mit fälligem Zug.
			var rng := RandomNumberGenerator.new()
			rng.seed = 27
			var studio := GameRun.new_run()
			studio.floor_map = FloorMap.roll(rng, studio._clause_offerable, 0.0,
				studio._boss_condition_ids(), 2)
			studio.floor_map.scout_from(studio.floor_map.position, rng, studio._clause_offerable)
			studio.advance_round()
			_hub.set_floor_state(studio.floor_view_state())
			_hub.set_run_stats(studio.next_blind(), 4, 2, {}, roundi(studio.blind_growth() * 100.0))
			set_meta("studio", studio)
		10:
			_shot_hub("1_hub_etagen_beginn.png")
			_sizes(_hub.floor_map, "beginn")
		12:
			var studio: GameRun = get_meta("studio")
			var locked := _mid_floor(studio)
			_hub.set_floor_state(studio.floor_view_state(), 1, locked)
			var walk: Array = studio.floor_view_state()["walkable"]
			var target := studio.floor_map.other_side(studio.floor_map.door(String(walk[0])),
				studio.floor_map.position)
			_hub.floor_map.hover_at(_hub.floor_map.room_rect(target).get_center())
		24:
			_shot_hub("2_hub_mitten_gesperrt_frei_hover.png")
			_sizes(_hub.floor_map, "mitten")
		26:
			var studio: GameRun = get_meta("studio")
			studio.move_due = false
			var walk_state := studio.floor_view_state()
			_page.show_state(walk_state)
			_page.visible = true
			var map := studio.floor_map
			for entry in map.doors_from(map.position):
				if int(entry["state"]) == FloorMap.DoorState.OPEN and bool(entry["scouted"]):
					_page.map_view.hover_at(_page.map_view.door_mark_rect(String(entry["id"])).get_center())
					break
		40:
			_shot_hub("3_laden_etage_seite.png")
			_sizes(_page.map_view, "laden")
			# Das echte Spiel: Runde 2 mit fälligem Zug, Kamera an der Hub-Station.
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
			var factor := pa.distance_to(pb) / 100.0
			print("BILDSCHIRM je Display-px ", factor, " hub ", hub.size, " karte ", hub.floor_map.size)
			_sizes(hub.floor_map, "spiel")
			print("ROUTE_PENDING ", game.get("route_pending"), " walk ", run.walkable_doors().size())
			quit()
	return false
