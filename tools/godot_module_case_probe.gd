extends SceneTree
## Sichtprobe des STANGENMAGAZINS (Modul-Paket) im echten Spiel: 2er Gewöhnlich, 4er Selten, 5er Episch offen,
## 6er Legendär über dem Kombinations-Feld. Aufruf:
##   Godot --path . --resolution 1600x900 --position 4000,2400 --quit-after 2400 \
##     --script tools/godot_module_case_probe.gd
## Bilder: E:/Generated Images/Fumble/modul_stange_spiel_2026-11-23/

const OUT := "E:/Generated Images/Fumble/modul_stange_spiel_2026-11-23/"
const VIEWS := ["oben", "schraeg", "nah_offen", "nah_legendaer"]
const SETS := [[0, 0], [2, 1], [3, 2], [4, 3]]  # Größe, Stufe

var game: Node
var cam: Camera3D
var started := false
var hulls: Array[CardPackView] = []
var step := 0
var wait := 0
var at := Vector3.ZERO

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	cam = Camera3D.new()
	cam.near = 0.5
	cam.far = 2000.0
	root.add_child(cam)

func _place() -> void:
	var chips: Dictionary = game.get("combo_chips")
	at = (chips.values()[4] as Node3D).global_position + Vector3(0, 2.2, 0)
	for i in SETS.size():
		var hull := CardPackView.new()
		game.add_child(hull)
		hull.setup_module_bag(SETS[i][0], SETS[i][1])
		hull.rotation.y = -PI / 2.0
		hull.set_body_scale(PackDrawerView.CASSETTE_SCALE)
		hull.position = at + Vector3((i / 2 - 0.5) * -5.0, 0.0, (i % 2 - 0.5) * 7.0)
		hulls.append(hull)
	hulls[2].set_torn(true)

func _process(_delta: float) -> bool:
	var ms := Time.get_ticks_msec()
	if not started:
		if ms > 2500:
			started = true
			game.call("_on_title_new_game")
		return false
	if ms < 13000:
		return false
	if hulls.is_empty():
		_place()
		return false
	wait += 1
	if wait < 20:
		return false
	wait = 0
	if step > 0:
		root.get_texture().get_image().save_png(OUT + "%d_%s.png" % [step, VIEWS[step - 1]])
		print("bild ", VIEWS[step - 1])
	if step >= VIEWS.size():
		return true
	cam.fov = 30.0
	cam.current = true
	match step:
		0:
			cam.look_at_from_position(at + Vector3(-5.0, 30.0, 0.0), at, Vector3(1, 0, 0))
		1:
			cam.look_at_from_position(at + Vector3(-17.0, 13.0, 9.0), at, Vector3.UP)
		2:
			var t := hulls[2].global_position + Vector3(0, 1.0, 0)
			cam.look_at_from_position(t + Vector3(-8.0, 7.0, 6.0), t, Vector3.UP)
		3:
			var t := hulls[3].global_position + Vector3(0, 0.6, 0)
			cam.look_at_from_position(t + Vector3(-7.0, 7.0, -5.0), t, Vector3.UP)
	step += 1
	return false
