extends SceneTree
## Sichtprobe: Würfel im LABOR lassen auch NACH dem Festzurren je einen Sitz im Vorrat leer.
## Aufruf:
##   Godot --path . --fixed-fps 60 --resolution 1280x720 --position 4000,2400 --quit-after 900 \
##     --script tools/godot_labor_seat_probe.gd
## Bilder: E:/Generated Images/Fumble/labor_spiel_2026-11-26/sitz_*.png

const OUT := "E:/Generated Images/Fumble/labor_spiel_2026-11-26/"

var game: Node
var frame := 0
var start := -1

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game

func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("SHOT ", name)

func _rig() -> CameraRig:
	return game.get("camera_rig")

func _seats(tag: String) -> void:
	var tray: DiceTrayView = game.get("pool_tray_view")
	var filled := 0
	for def in tray.slot_defs:
		if def != null:
			filled += 1
	var kinds: Array = game.get("round_pool_kinds")
	print("SITZE ", tag, " Plätze ", tray.slot_defs.size(), " belegt ", filled, " Stapel ", kinds.size(),
		" Ablage ab ", game.call("_ablage_base"), " gezurrt ", game.get("round_committed"))

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		game.call("_on_title_new_game")
	if start < 0:
		if frame > 120 and not _rig().is_animating:
			start = frame
		return frame > 800
	var t := frame - start
	var run: GameRun = game.get("run")
	match t:
		5:
			run.stress_tests_passed = 1
			run.open_labor()
			run.labor_station = Labor.SEELE
			run.owned_pool[3].essence_id = Essence.all()[0].id
			print("START ", run.start_labor_job({"dice": [3, 7]}))
			game.set("_labor_roll_face", -1)
		60:
			_rig().zoom_to(CameraRig.Mode.POOL)
		160:
			_seats("vor dem Zurren")
			_shot("sitz_vor_dem_zurren")
			game.call("_commit_round")
		420:
			_seats("nach dem Zurren")
			_shot("sitz_nach_dem_zurren")
			print("PROBE fertig")
			quit()
	return false
