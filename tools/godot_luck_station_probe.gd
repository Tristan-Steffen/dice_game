extends SceneTree
## Sichtprobe der GLÜCKS-STATION (LuckStationBody) im echten Spiel. Aufruf:
##   Godot --path . --resolution 1280x720 --position 4000,2400 --quit-after 900 \
##     --script tools/godot_luck_station_probe.gd
## Bilder: E:/Generated Images/Fumble/glueck_spiel_2026-11-24/

const OUT := "E:/Generated Images/Fumble/glueck_spiel_2026-11-24/runde2/"
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

func _station() -> void:
	var t: Vector3 = (game.get("chips_click_zone") as Node3D).global_position
	t.y = 0.0
	cam.look_at_from_position(t - FORWARD * 30.0, t, Vector3(1, 0, 0))
	cam.current = true

func _near() -> void:
	var t: Vector3 = (game.get("luck_station_body") as Node3D).global_position
	cam.look_at_from_position(t - FORWARD * 17.0, t, Vector3(1, 0, 0))
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
		return frame > 800
	var run: GameRun = game.get("run")
	match frame - start:
		10:
			_near()
		50:
			_shot("1_nah_start")
			run.luck = 25
			game.set("_luck_last_face", 3)
		150:
			_shot("2_nah_mitte_letzte_seite")
			_station()
		190:
			_shot("3_station_mitte")
			run.luck = 214
			run.module_keeps = 2
			_near()
		330:
			_shot("4_nah_spaet_einbau")
			game.call("_send_luck_die", 2)
		345:
			_shot("5_nah_unterwegs_flug")
		420:
			_shot("6_nah_unterwegs_sitz_leer")
			game.call("_luck_die_home_hard")
			_overview()
		460:
			_shot("7_uebersicht")
			return true
	return false
