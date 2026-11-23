extends SceneTree
## Sichtprobe der WALZEN-SPERRE im echten Spiel: Hauben über gesperrten Scheiben, Preis
## bezahlbar, Freischalten, und die stromlose Walze nach der Prägung der Runde. Aufruf:
##   Godot --path . --resolution 1600x900 --position 4000,2400 --quit-after 2400 \
##     --script tools/godot_drum_lock_probe.gd
## Bilder: E:/Generated Images/Fumble/walze_sperre_2026-11-23/

const OUT := "E:/Generated Images/Fumble/walze_sperre_2026-11-23/"
const VIEWS := ["gesperrt", "bezahlbar", "freischalten", "frei", "belegt", "praegen",
	"stromlos", "stromlos_station"]
const WAITS: Array[int] = [90, 60, 60, 12, 90, 90, 40, 200, 150]

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
	if wait < WAITS[step]:
		return false
	wait = 0
	if step > 0:
		root.get_texture().get_image().save_png(OUT + "%d_%s.png" % [step, VIEWS[step - 1]])
	if step >= VIEWS.size():
		return true
	var run: GameRun = game.get("run")
	var screen: TableScreen = game.get("table_screen")
	var workshop: WorkshopView = screen.workshop_window
	var area := workshop.call("_global", workshop.slice_rect(0)) as Rect2
	area = area.merge(workshop.call("_global", workshop.slice_rect(5)) as Rect2)
	area = area.merge(workshop.stamp_seat_px())
	var t := screen.pixel_to_world(area.get_center())
	var forward := Vector3(0.2588, -0.9659, 0.0)
	cam.fov = 40.0
	match step:
		0:
			cam.look_at_from_position(t - forward * 30.0, t, Vector3(1, 0, 0))
			cam.current = true
		1:
			run.add_energy(5)
		2:
			run.buy_drum_slot()
		4:
			for i in 2:
				var got := run.grant_pack(Pack.tiered(Pack.by_type(Pack.TYPE_NUMBER),
					Pack.TIER_NORMAL, null))
				workshop.call("_on_pack_pressed", got.pack_uid)
			workshop.choose_index(0)
		5:
			workshop.pull_lever()
		7:
			(game.get("camera_rig") as Camera3D).current = true
			game.call("_zoom_to_mode", CameraRig.Mode.WORKSHOP)
	step += 1
	return false
