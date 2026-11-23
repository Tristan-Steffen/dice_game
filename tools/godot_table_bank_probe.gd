extends SceneTree
## Sichtprobe der BANK im echten Spiel (Übersicht, Band, schräg) samt Bild-Kosten. Aufruf:
##   Godot --path . --resolution 1600x900 --position 4000,2400 --quit-after 2400 \
##     --script tools/godot_table_bank_probe.gd
## Bilder: E:/Generated Images/Fumble/lager_bank_spiel_2026-11-23/

const OUT := "E:/Generated Images/Fumble/lager_bank_spiel_2026-11-23/"
const VIEWS := ["uebersicht", "band", "station", "station_wuerfel", "station_modul"]

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
	cam.near = 1.0
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
	if wait < 8:
		return false
	wait = 0
	if step > 0:
		if step >= 4:
			print((game.get("house_bank") as TableBankView).screen_text())
		var shot := root.get_texture().get_image()
		if _mark.x >= 0.0:
			var k := float(shot.get_width()) / root.get_visible_rect().size.x
			for d in range(-14, 15):
				shot.set_pixel(clampi(int(_mark.x * k) + d, 0, shot.get_width() - 1), clampi(int(_mark.y * k), 0, shot.get_height() - 1), Color.RED)
				shot.set_pixel(clampi(int(_mark.x * k), 0, shot.get_width() - 1), clampi(int(_mark.y * k) + d, 0, shot.get_height() - 1), Color.RED)
		shot.save_png(OUT + "%d_%s.png" % [step, VIEWS[step - 1]])
		print("%s: draws %d, prims %d, fps %d" % [VIEWS[step - 1],
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.TIME_FPS)])
	if step >= VIEWS.size():
		return true
	var band := TableBodyView.free_band()
	var mid := band.get_center()
	var forward := Vector3(0.2588, -0.9659, 0.0)
	cam.fov = 40.0
	match step:
		0:
			(game.get("camera_rig") as Camera3D).current = true
		1:
			var t := Vector3(mid.x, 0, mid.y + 12.0)
			cam.look_at_from_position(t - forward * 100.0, t, Vector3(1, 0, 0))
			cam.current = true
		2:
			var rig := game.get("camera_rig") as CameraRig
			rig.current = true
			rig.zoom_to(CameraRig.Mode.BANK)
			wait = -90
		3:
			_point_at(7)
		4:
			_point_at(TableBankView.dice_stock().size() + 5)
	step += 1
	return false

var _mark := Vector2(-1, -1)

func _point_at(index: int) -> void:
	var bank := game.get("house_bank") as TableBankView
	var rig := game.get("camera_rig") as CameraRig
	game.set_process(false)
	rig.set_process(false)
	var at := rig.unproject_position(bank.item_ray(index))
	_mark = at
	var got := bank.item_at(rig.project_ray_origin(at), rig.project_ray_normal(at))
	bank.show_item(got)
	print("zeigt auf ", bank.item_title(index), " bei ", at, " trifft ", got, " von ", index,
		" sichtbar ", root.get_visible_rect().size, " fenster ", root.size)
