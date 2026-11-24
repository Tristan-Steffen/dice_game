extends SceneTree
## Sichtprobe der drei Leiterbahn-ENTWÜRFE (WorkshopView.TraceLayer.style 1-3) im Spiel. Aufruf:
##   Godot --path . --resolution 1600x900 --position 4000,2400 --quit-after 3600 \
##     --script tools/godot_trace_style_probe.gd
## Bilder: E:/Generated Images/Fumble/leiterbahn_entwuerfe_2026-11-23/

const OUT := "E:/Generated Images/Fumble/leiterbahn_entwuerfe_2026-11-23/"
const STYLES := [0, 1, 2, 3]
const NAMES := ["heute", "kupfer", "busband", "datenstrom"]

var game: Node
var cam: Camera3D
var started := false
var filled := false
var shot := 0
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

## Je Entwurf zwei Bilder: nah über dem Bus, dann die Werkstatt-Station.
func _process(_delta: float) -> bool:
	var ms := Time.get_ticks_msec()
	if not started:
		if ms > 2500:
			started = true
			game.call("_on_title_new_game")
		return false
	if ms < 12000:
		return false
	var workshop: WorkshopView = game.get("table_screen").workshop_window
	wait += 1
	if not filled:
		if wait >= 40:
			filled = true
			wait = 0
			_fill()
		return false
	if wait < 45:
		return false
	wait = 0
	if shot > 0:
		var prev := shot - 1
		var name := "%d_%s_%s.png" % [prev / 2 + 1, NAMES[prev / 2], "nah" if prev % 2 == 0 else "station"]
		root.get_texture().get_image().save_png(OUT + name)
	if shot >= STYLES.size() * 2:
		return true
	if shot % 2 == 0:
		WorkshopView.TraceLayer.style = STYLES[shot / 2]
		workshop.refresh()
		var screen: TableScreen = game.get("table_screen")
		var band: Rect2 = workshop.call("_global", workshop.drum()["trace_band"]) as Rect2
		var t := screen.pixel_to_world(Vector2(band.position.x + band.size.x * 0.33,
			band.get_center().y))
		var forward := Vector3(0.2588, -0.9659, 0.0)
		cam.fov = 40.0
		cam.look_at_from_position(t - forward * 17.0, t, Vector3(1, 0, 0))
		cam.current = true
	else:
		(game.get("camera_rig") as Camera3D).current = true
		game.call("_zoom_to_mode", CameraRig.Mode.WORKSHOP)
	shot += 1
	return false
