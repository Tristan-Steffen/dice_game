extends SceneTree
## Sichtprobe der Tray-Fassung (ChipTrayDress, Schieberegister) im echten Spiel. Aufruf:
##   Godot --path . --resolution 1280x720 --position 4000,2400 --quit-after 1100 \
##     --script tools/godot_chip_dress_probe.gd
## Bilder: E:/Generated Images/Fumble/chips_spiel_2026-11-24/

const OUT := "E:/Generated Images/Fumble/chips_spiel_2026-11-24/"
const FORWARD := Vector3(0.2588, -0.9659, 0.0)

var game: Node
var cam: Camera3D
var frame := 0
var start := -1

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	cam = Camera3D.new()
	cam.near = 0.3
	cam.far = 2000.0
	cam.fov = 40.0
	root.add_child(cam)

func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + name + ".png")

func _tray() -> ChipTrayView:
	return game.get("chip_tray")

func _money(amount: int) -> void:
	_tray().seat_hard(ChipTrayView.belegung(amount))
	(game.get("table_screen") as TableScreen).treasure_window.set_top_count(
		ChipTrayView.belegung(amount)[ChipTrayView.TOP])

func _station() -> void:
	var t: Vector3 = (game.get("chips_click_zone") as Node3D).global_position
	t.y = 0.0
	cam.look_at_from_position(t - FORWARD * 30.0, t, Vector3(1, 0, 0))
	cam.current = true

func _near() -> void:
	var t := _tray().global_position
	cam.look_at_from_position(t + Vector3(-11.0, 9.5, 4.5), t + Vector3(0.0, -0.5, 0.0), Vector3.UP)
	cam.current = true

func _overview() -> void:
	var screen: TableScreen = game.get("table_screen")
	var t := screen.pixel_to_world(Vector2(TableScreen.RESOLUTION) * 0.5)
	cam.look_at_from_position(t - FORWARD * 118.0, t, Vector3(1, 0, 0))
	cam.current = true

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		game.call("_on_title_new_game")
	if start < 0:
		var rig: CameraRig = game.get("camera_rig")
		if frame > 120 and not rig.is_animating:
			start = frame
			game.call("_zoom_to_mode", CameraRig.Mode.CHIPS)
		return frame > 1000
	match frame - start:
		90:
			_money(0)
		110:
			_shot("1_station_leer")
			_money(137)
		140:
			_shot("2_station_137")
			_money(4860)
		170:
			_shot("3_station_4860")
			_station()
			_money(182_000)
		200:
			_shot("4_station_182000")
			_money(4860)
			_near()
		230:
			_shot("5_nah_4860")
			var t := _tray().global_position
			cam.look_at_from_position(t - FORWARD * 21.0, t + Vector3(-1.5, 0, 0), Vector3(1, 0, 0))
			_money(20)
			_tray().play(ChipTrayView.transition(ChipTrayView.belegung(20), ChipTrayView.belegung(21), false))
		248:
			_shot("6_nah_uebertrag")
		262:
			_shot("7_nah_uebertrag_spaet")
			_overview()
		320:
			_shot("8_uebersicht")
			return true
	return false
