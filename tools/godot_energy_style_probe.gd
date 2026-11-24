extends SceneTree
## Sichtprobe: das BATTERIE-RACK mit silbernen Einschüben und offenen Fächern. Aufruf:
##   Godot --path . --resolution 1280x720 --position 4000,2400 --quit-after 1500 \
##     --script tools/godot_energy_style_probe.gd
## Bilder: E:/Generated Images/Fumble/energie_silber_2026-11-24/

const OUT := "E:/Generated Images/Fumble/energie_silber_2026-11-24/"
const FORWARD := Vector3(0.2588, -0.9659, 0.0)
const STATES := [[12, 15, "12von15"], [3, 5, "3von5"], [50, 50, "50von50"]]

var game: Node
var cam: Camera3D
var frame := 0
var shots: Array = []
var step := 0

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
	for state in STATES:
		shots.append([state[0], state[1], "%s_nah" % state[2], "near"])
	shots.append([12, 15, "station", "station"])
	shots.append([12, 15, "schraeg", "tilt"])
	shots.append([3, 5, "schraeg_leer", "tilt"])

func _process(_delta: float) -> bool:
	frame += 1
	if frame < 60 or frame % 25 != 0:
		return false
	if step > 0:
		root.get_texture().get_image().save_png(OUT + String(shots[step - 1][2]) + ".png")
	if step >= shots.size():
		return true
	var shot: Array = shots[step]
	var bank: EnergyBankView = game.get("energy_bank")
	bank.set_energy(int(shot[0]), int(shot[1]))
	var t := bank.global_position
	match String(shot[3]):
		"station":
			t = (game.get("chips_click_zone") as Node3D).global_position
			t.y = 0.0
			cam.look_at_from_position(t - FORWARD * 30.0, t, Vector3(1, 0, 0))
		"tilt":
			cam.look_at_from_position(t + Vector3(-8.0, 9.0, 3.5), t, Vector3.UP)
		_:
			cam.look_at_from_position(t - FORWARD * 17.0, t, Vector3(1, 0, 0))
	cam.current = true
	step += 1
	return false
