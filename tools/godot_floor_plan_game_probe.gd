extends SceneTree
## Sichtprobe des GRUNDRISSES im echten Spiel (Welle 7 Teil B): Runde 1 mit fälligem Zug in
## der Übersicht („RAUM WÄHLEN“) und an der Gruben-Station (Nahsicht im engen Rahmen), dazu
## der Maßstab Bildschirm-px je Display-px und ein Zug über das Signal der Nahsicht. Aufruf:
##   Godot --path . --fixed-fps 60 --resolution 1280x720 --position 4000,2400 --quit-after 900 \
##     --script tools/godot_floor_plan_game_probe.gd
## Bilder: E:/Generated Images/Fumble/etagen_grundriss_spiel_2026-11-27/

const OUT := "E:/Generated Images/Fumble/etagen_grundriss_spiel_2026-11-27/"

var game: Node
var frame := 0
var start := -1

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game

func _rig() -> CameraRig:
	return game.get("camera_rig")

func _shot(file: String) -> void:
	root.get_texture().get_image().save_png(OUT + file + ".png")
	print("SHOT ", file)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		game.call("_on_title_new_game")
	if start < 0:
		if frame > 120 and not _rig().is_animating:
			start = frame
		return frame > 850
	var t := frame - start
	var run: GameRun = game.get("run")
	var detail: FloorPlanView = game.get("floor_detail")
	match t:
		30:
			print("RUNDE ", run.round_number, " Zug fällig ", run.move_due, " route_pending ", game.get("route_pending"))
			_shot("6_spiel_uebersicht_raum_waehlen")
			_rig().zoom_to(CameraRig.Mode.PIT)
		200:
			print("NAHSICHT offen ", detail.visible, " Größe ", detail.size)
			var screen: TableScreen = game.get("table_screen")
			var camera := root.get_viewport().get_camera_3d()
			var a := camera.unproject_position(screen.pixel_to_world(detail.position))
			var b := camera.unproject_position(screen.pixel_to_world(detail.position + detail.size))
			print("MASSSTAB %.3f Bildschirm-px je Display-px" % (absf(b.x - a.x) / detail.size.x))
			for role in ["name", "bonus_name", "bonus_text", "move"]:
				print("  ", role, " ", detail.label_px(role), " Display-px")
			_shot("4_spiel_grube_runde1")
		210:
			var move: Dictionary = detail.walkable_moves()[0]
			detail.move_chosen.emit(move)
		300:
			print("NACH DEM ZUG route_pending ", game.get("route_pending"), " Nahsicht ", detail.visible,
				" Blind ", run.effective_goal(), " Raum ", run.floor_plan.position)
			_shot("4b_spiel_grube_nach_dem_zug")
			return true
	return false
