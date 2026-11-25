extends SceneTree
## Sichtprobe der GLEICHUNG als Bauteile (DieViewDress, offene Kammer, Wanne) im echten
## Spiel: leer, belegt, schräg, mitten im Prägen, danach, an der Station. Aufruf:
##   Godot --path . --resolution 1600x900 --position 4000,2400 --quit-after 2400 \
##     --script tools/godot_dieview_embed_probe.gd
## Bilder: E:/Generated Images/Fumble/werkstatt_register_2026-11-24/

const OUT := "E:/Generated Images/Fumble/werkstatt_register_2026-11-24/"
const VIEWS := ["leer", "belegt", "belegt_schraeg", "praegen", "nach_praegen", "station",
	"oeffnung_fahrt", "oeffnung", "nach_oeffnung"]

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

func _fill(workshop: WorkshopView) -> void:
	var run: GameRun = game.get("run")
	for kind: String in [Pack.TYPE_NUMBER, Pack.TYPE_MATERIAL, Pack.TYPE_NUMBER, ""]:
		var pack := Pack.roll_engraving_pack() if kind == "" else Pack.tiered(Pack.by_type(kind),
			Pack.TIER_NORMAL, null)
		var got := run.grant_pack(pack)
		if got != null:
			workshop.call("_on_pack_pressed", got.pack_uid)
	workshop.choose_index(0)

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
	if wait < ([90, 90, 90, 90, 40, 90, 90, 25, 240, 300] as Array[int])[step]:
		return false
	wait = 0
	if step > 0:
		root.get_texture().get_image().save_png(OUT + "%d_%s.png" % [step, VIEWS[step - 1]])
	if step >= VIEWS.size():
		return true
	var screen: TableScreen = game.get("table_screen")
	var workshop: WorkshopView = screen.workshop_window
	var area := workshop.call("_global", workshop.upgrades_net_rect()) as Rect2
	area = area.merge(workshop.call("_global", workshop.podium_net_rect()) as Rect2)
	area = area.merge(workshop.podium_plate_px())
	var t := screen.pixel_to_world(area.get_center())
	var forward := Vector3(0.2588, -0.9659, 0.0)
	cam.fov = 40.0
	match step:
		0:
			cam.look_at_from_position(t - forward * 27.0, t, Vector3(1, 0, 0))
			cam.current = true
		1:
			_fill(workshop)
		2:
			cam.look_at_from_position(t + Vector3(-15.0, 11.0, -6.0), t, Vector3.UP)
		3:
			workshop.pull_lever()
		5:
			(game.get("camera_rig") as Camera3D).current = true
			game.call("_zoom_to_mode", CameraRig.Mode.WORKSHOP)
		6:
			(game.get("run") as GameRun).purchase_card_pack(CardPack.roll_shop(), 0)
		8:
			game.call("_on_pack_choice_confirmed", [])
			cam.current = true
	if step == 0:
		for part: String in ["upgrades", "podium", "podium_stage", "podium_net", "result",
				"stamp", "equation"]:
			print("MASS %s %s" % [part, workshop.call("_global", workshop.drum()[part])])
		print("MASS schale %s" % [game.call("_fach_spot_px")])
		print("MASS zone %s" % [game.call("_opening_area_rect")])
		print("MASS zeichen %s" % [workshop.sign_rects_px()])
	step += 1
	return false
