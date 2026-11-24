extends SceneTree
## Sichtprobe des KLINGEN-RACKS (EnergyBankView) im echten Spiel. Aufruf:
##   Godot --path . --resolution 1280x720 --position 4000,2400 --quit-after 700 \
##     --script tools/godot_energy_rack_probe.gd
## Bilder: E:/Generated Images/Fumble/energie_spiel_2026-11-24/

const OUT := "E:/Generated Images/Fumble/energie_spiel_2026-11-24/"
const FORWARD := Vector3(0.2588, -0.9659, 0.0)

var game: Node
var cam: Camera3D
var frame := 0

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

func _bank() -> EnergyBankView:
	return game.get("energy_bank")

## Wie die Station CHIPS: um 15° geneigt auf Tray, Glück und Bank.
func _station() -> void:
	var t: Vector3 = (game.get("chips_click_zone") as Node3D).global_position
	t.y = 0.0
	cam.look_at_from_position(t - FORWARD * 30.0, t, Vector3(1, 0, 0))
	cam.current = true

func _overview() -> void:
	var screen: TableScreen = game.get("table_screen")
	var t := screen.pixel_to_world(Vector2(TableScreen.RESOLUTION) * 0.5)
	cam.look_at_from_position(t - FORWARD * 118.0, t, Vector3(1, 0, 0))
	cam.current = true

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		60:
			_bank().set_energy(0, 5)
			_station()
		100:
			_shot("1_station_0von5")
			_bank().set_energy(12, 15)
		140:
			_shot("2_station_12von15")
			_bank().set_energy(12, 20)
		146:
			_shot("3_station_klinge_senkt")
		190:
			_bank().set_energy(50, 50)
		230:
			_shot("4_station_50von50")
			_bank().set_energy(7, 15)
			var t := _bank().global_position
			cam.look_at_from_position(t + Vector3(-8.0, 9.0, 3.5), t, Vector3.UP)
		260:
			_shot("5_nah_schraeg_7von15")
			_overview()
		300:
			_shot("6_uebersicht")
			return true
	return false
