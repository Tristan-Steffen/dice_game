extends SceneTree
## Sichtprobe der Welle 6 der Etagen-Karte (die Entscheidung fällt in der Grube):
## (1) die NAHSICHT im Maß des Grubenbodens, Etage 1, Zug 1 vom Eingang; (2) mitten in der
## Etage mit gesperrter und freier Tür, besuchtem Raum und rotem Polster; (3) nach oben
## verschoben mit „Zum Puck“; (4) das echte Spiel an der GRUBEN-Station mit fälligem Zug;
## (5) die Übersicht mit dem Lockruf „RAUM WÄHLEN“; (6) die Hub-Startseite mit dem höheren
## Streifen. Gemessen werden die Schriftgrade (Display- und Bildschirm-px).
## Aufruf: --path . --resolution 1280x720 --position 4000,2400 --quit-after 900
##   --script tools/godot_floor_map_probe.gd

const OUT := "E:/Generated Images/Fumble/etagen_grube_2026-11-27/"
const HUB_SIZE := Vector2i(1068, 1125)
const PIT_SIZE := Vector2i(985, 484)

var game: Node
var frame := 0
var start := -1
var _hub_vp: SubViewport
var _pit_vp: SubViewport
var _hub: HubView
var _detail: FloorMapView
var _studio: GameRun
var _ratio := 0.0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	_hub_vp = _studio_viewport(HUB_SIZE)
	_hub = HubView.new()
	_hub.size = Vector2(HUB_SIZE)
	_hub_vp.add_child(_hub)
	_hub.layout()
	_pit_vp = _studio_viewport(PIT_SIZE)
	_detail = FloorMapView.new()
	_detail.mode = FloorMapView.Mode.DETAIL
	_detail.size = Vector2(PIT_SIZE)
	_pit_vp.add_child(_detail)

func _studio_viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var ground := ColorRect.new()
	ground.color = Color("#0b1712")
	ground.size = Vector2(size)
	vp.add_child(ground)
	return vp

func _rig() -> CameraRig:
	return game.get("camera_rig")

func _shot(vp: Viewport, file: String) -> void:
	vp.get_texture().get_image().save_png(OUT + file)
	print("Bild: ", OUT + file)

func _sizes(node: Node, tag: String, ratio := 0.0) -> void:
	var by: Dictionary = {}
	for child in node.find_children("*", "Label", true, false):
		var label := child as Label
		if label.text == "" or not label.is_visible_in_tree():
			continue
		var kind := String(label.name).split("_")[0]
		var px := label.get_theme_font_size("font_size")
		var span: Vector2i = by.get(kind, Vector2i(9999, 0))
		by[kind] = Vector2i(mini(span.x, px), maxi(span.y, px))
	print("SCHRIFT ", tag, " (Display-px) ", by)
	if ratio > 0.0:
		var screen := {}
		for kind: String in by:
			var span: Vector2i = by[kind]
			screen[kind] = "%.1f-%.1f" % [span.x * ratio, span.y * ratio]
		print("SCHRIFT ", tag, " (Bildschirm-px) ", screen)

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

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		game.call("_on_title_new_game")
	if start < 0:
		if frame > 120 and not _rig().is_animating:
			start = frame
		return frame > 890
	var t := frame - start
	var run: GameRun = game.get("run")
	var screen: TableScreen = game.get("table_screen")
	match t:
		2:
			# (1) Etage 1, Runde 2: der erste Zug vom Eingang.
			_studio = GameRun.new_run()
			_studio.round_points = 620
			_studio.advance_round()
			_detail.open(_studio.floor_view_state())
			_hub.set_floor_state(_studio.floor_view_state())
			_hub.set_floor_moves_enabled(true)
		10:
			_shot(_pit_vp, "1_nahsicht_etage1_zug1.png")
			_sizes(_detail, "nahsicht_1")
			_shot(_hub_vp, "6_startseite_streifen.png")
			print("STREIFEN ", _hub.floor_map.size, " buehne ", _hub.roadmap_stage.size)
		12:
			# (2) Mitten in der Etage: besuchter Raum, gesperrte und freie Tür, rotes Polster.
			_step(_studio)
			_step(_studio)
			_studio.move_due = true
			_studio.round_scores.assign([30, 40])
			var map := _studio.floor_map
			var locked := ""
			for entry in map.lock_candidates():
				if not map.is_office_door(entry):
					entry["state"] = FloorMap.DoorState.LOCKED
					locked = String(entry["id"])
					break
			for entry in map.doors_from(map.position):
				if int(entry["state"]) == FloorMap.DoorState.OPEN and not map.is_office_door(entry) \
						and String(entry["id"]) != locked and not map.rooms[map.other_side(entry, map.position)]["visited"]:
					entry["free"] = true
					entry["malus"] = ""
					break
			_detail.close()
			_detail.open(_studio.floor_view_state(), 1, locked)
		24:
			_shot(_pit_vp, "2_nahsicht_mitte_gesperrt_frei_besucht.png")
			_sizes(_detail, "nahsicht_2")
			# (3) nach oben verschoben: „Zum Puck“ steht.
			_detail.scroll_by(1.6)
		30:
			_shot(_pit_vp, "3_nahsicht_verschoben_zum_puck.png")
			# (4) Das echte Spiel: Runde 2 mit fälligem Zug, Kamera an der GRUBEN-Station.
			run.round_points = 480
			run.advance_round()
			game.call("_start_new_round")
			_rig().zoom_to(CameraRig.Mode.PIT)
		200:
			root.get_texture().get_image().save_png(OUT + "4_spiel_gruben_station.png")
			print("Bild: ", OUT + "4_spiel_gruben_station.png")
			var detail: FloorMapView = game.get("floor_detail")
			var camera := root.get_camera_3d()
			var a := detail.position + Vector2(0.0, detail.size.y * 0.5)
			var b := a + Vector2(100.0, 0.0)
			var floor_y := Vector3(0.0, DicePit.FLOOR_TOP, 0.0)
			var pa := camera.unproject_position(screen.pixel_to_world(a) + floor_y)
			var pb := camera.unproject_position(screen.pixel_to_world(b) + floor_y)
			_ratio = pa.distance_to(pb) / 100.0
			print("NAHSICHT sichtbar ", detail.visible, " groesse ", detail.size, " u ", detail.unit(),
				" BILDSCHIRM je Display-px ", _ratio, " modus ", _rig().mode)
			_sizes(detail, "spiel", _ratio)
			print("ROUTE_PENDING ", game.get("route_pending"), " walk ", run.walkable_doors().size())
			_rig().zoom_out()
		330:
			root.get_texture().get_image().save_png(OUT + "5_spiel_uebersicht_lockruf.png")
			print("Bild: ", OUT + "5_spiel_uebersicht_lockruf.png")
			var beckon: Control = screen.pit_beckon
			print("LOCKRUF sichtbar ", beckon.visible, " titel ", (beckon.get_child(0) as Label).text,
				" unter ", (beckon.get_child(1) as Label).text, " nahsicht ", (game.get("floor_detail") as FloorMapView).visible)
			quit()
	return false
