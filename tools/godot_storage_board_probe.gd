extends SceneTree
## Sichtprobe des SPEICHERS (UPGRADES als Platine mit Energiezellen) im echten Spiel. Aufruf:
##   Godot --path . --resolution 1600x900 --position 4000,2400 --quit-after 2400 \
##     --script tools/godot_storage_board_probe.gd
## Bilder: E:/Generated Images/Fumble/speicher_platine_spiel_2026-11-23/

const OUT := "E:/Generated Images/Fumble/speicher_platine_spiel_2026-11-23/"
const VIEWS := ["leer_nah", "belegt_nah", "belegt_schraeg", "belegt_station"]

var game: Node
var cam: Camera3D
var started := false
var step := 0
var wait := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	cam = Camera3D.new()
	cam.near = 0.5
	cam.far = 2000.0
	root.add_child(cam)

func _fill() -> void:
	var run: GameRun = game.get("run")
	var workshop: WorkshopView = game.get("table_screen").workshop_window
	for kind: String in [Pack.TYPE_NUMBER, Pack.TYPE_MATERIAL, Pack.TYPE_NUMBER, ""]:
		var pack := Pack.roll_engraving_pack() if kind == "" else Pack.tiered(Pack.by_type(kind),
			Pack.TIER_NORMAL, null)
		var got := run.grant_pack(pack)
		if got != null:
			workshop.call("_on_pack_pressed", got.pack_uid)

func _process(_delta: float) -> bool:
	var ms := Time.get_ticks_msec()
	if not started:
		if ms > 2500:
			started = true
			game.call("_on_title_new_game")
		return false
	if ms < 12000:
		return false
	wait += 1
	if wait < 40:
		return false
	wait = 0
	if step > 0:
		root.get_texture().get_image().save_png(OUT + "%d_%s.png" % [step, VIEWS[step - 1]])
	if step >= VIEWS.size():
		return true
	var screen: TableScreen = game.get("table_screen")
	var workshop: WorkshopView = screen.workshop_window
	var rect := workshop.call("_global", workshop.upgrades_net_rect()) as Rect2
	var t := screen.pixel_to_world(rect.get_center())
	var forward := Vector3(0.2588, -0.9659, 0.0)
	cam.fov = 40.0
	match step:
		0:
			cam.look_at_from_position(t - forward * 16.0, t, Vector3(1, 0, 0))
			cam.current = true
		1:
			_fill()
		2:
			cam.look_at_from_position(t + Vector3(-9.0, 7.0, -3.0), t, Vector3.UP)
		3:
			(game.get("camera_rig") as Camera3D).current = true
			game.call("_zoom_to_mode", CameraRig.Mode.WORKSHOP)
	step += 1
	return false
