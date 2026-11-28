extends SceneTree
## Sichtprobe der HITZE im echten Spiel: die Deal-Wahl in der Grube bei Hitze 1, 3 und 5
## und die Hub-Startseite (Block-Streifen, Pegel) bei denselben Ständen. Aufruf:
##   Godot --path . --fixed-fps 60 --resolution 1280x720 --position 4000,2400 --quit-after 1100 \
##     --script tools/godot_heat_probe.gd
## Bilder: E:/Generated Images/Fumble/hitze_2026-11-28/

const OUT := "E:/Generated Images/Fumble/hitze_2026-11-28/"

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

## Legt eine frische Auslage bei Hitze h auf den Grubenboden.
func _lay(run: GameRun, h: int) -> void:
	run.heat = h
	run.roll_route_offers()
	var view: RouteChoiceView = game.get("route_choice")
	view.open(run.route_view_state())

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		game.call("_on_title_new_game")
	if start < 0:
		if frame > 120 and not _rig().is_animating:
			start = frame
		return frame > 1050
	var t := frame - start
	var run: GameRun = game.get("run")
	var view: RouteChoiceView = game.get("route_choice")
	match t:
		10:
			_rig().zoom_to(CameraRig.Mode.PIT)
		200:
			print("WAHL offen %s, Größe %s, pending %s" % [view.visible, view.size, game.get("route_pending")])
			_shot("grube_hitze1")
		210:
			view.route_chosen.emit(2)
		240:
			print("nach der Wahl: Hitze %d, offen %s" % [run.heat, view.visible])
			# Zwei Runden im Zeitraffer, damit der Streifen Geschichte trägt.
			for i in 2:
				run.round_points = 300 + i * 120
				run.advance_round()
				run.take_route(2)
			run.round_points = 520
			run.advance_round()
			_lay(run, 3)
		300:
			_shot("grube_hitze3")
		310:
			_lay(run, 5)
		370:
			_shot("grube_hitze5")
		380:
			view.close()
			game.call("_refresh_hub_info")
			_rig().zoom_to(CameraRig.Mode.HUB)
		580:
			_shot("hub_hitze5")
			run.heat = 3
		620:
			_shot("hub_hitze3")
			run.heat = 1
		660:
			_shot("hub_hitze1")
			return true
	return false
