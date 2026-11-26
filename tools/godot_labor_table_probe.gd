extends SceneTree
## Sichtprobe des LABORS am echten Tisch (Welle 3): Übersicht, Station bereit, ein Seelen-
## Auftrag mit dem Glückswürfel auf der Haube, laufend und fertig.
## Aufruf:
##   Godot --path . --fixed-fps 60 --resolution 1280x720 --position 4000,2400 --quit-after 1400 \
##     --script tools/godot_labor_table_probe.gd
## Bilder: E:/Generated Images/Fumble/labor_spiel_2026-11-26/tisch_*.png

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

func _report() -> void:
	var screen: TableScreen = game.get("table_screen")
	var labor: Rect2 = game.call("labor_rect_px")
	var market := Rect2(screen.secret_shop_window.position, screen.secret_shop_window.size)
	var hub := Rect2(screen.hub.position, screen.hub.size)
	print("LABOR ", labor, " end ", labor.end, " world ", labor.size / screen.pixels_per_world())
	print("MARKT ", market, " end ", market.end)
	print("HUB ", hub, " end ", hub.end, " DISPLAY ", TableScreen.RESOLUTION)
	print("FUGE ", labor.position.y - market.end.y, " bis Hub-Unterkante ", hub.end.y - labor.end.y)
	var run: GameRun = game.get("run")
	print("STATE ", run.labor_state()["phase"], " ", (screen.labor_window as LaborView).body_state()["status"])

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		game.call("_on_title_new_game")
	if start < 0:
		if frame > 120 and not _rig().is_animating:
			start = frame
		return frame > 1300
	var t := frame - start
	var run: GameRun = game.get("run")
	match t:
		5:
			run.stress_tests_passed = 1
			run.open_labor()
			run.labor_station = Labor.SEELE
			run.energy = run.energy_cap()
			run.owned_pool[0].essence_id = Essence.all()[0].id
			run.labor_changed.emit()
		40:
			_report()
			_shot("tisch_uebersicht")
			_rig().zoom_to(CameraRig.Mode.LABOR)
		120:
			_report()
			_shot("tisch_labor_bereit")
		125:
			print("START ", run.start_labor_job({"dice": [0, 1]}))
			game.set("_labor_roll_face", run.labor_job.die_face)
			game.set("_labor_roll_started", false)
			print("WURF ", run.labor_job.die_face, " Augen ", run.labor_job.die_value)
		175:
			var luck: LuckDieView = game.get("luck_die_view")
			var body: LaborBody = game.get("labor_body")
			print("GLUECK ", luck.global_position, " Haube ", body.lid_point())
			_shot("tisch_labor_wurf")
		330:
			_report()
			_shot("tisch_labor_laeuft")
		335:
			while not run.labor_job.done:
				run.labor_job.tick()
			run.labor_changed.emit()
		380:
			_report()
			_shot("tisch_labor_fertig")
		385:
			game.call("_on_labor_chamber_pressed")
		430:
			_report()
			_shot("tisch_labor_abgeholt")
		440:
			# Die WAHL über den echten Weg: Kammer -> Vorrat -> Quelle, Ziel -> zurück, START.
			run.labor_station = Labor.SEELE
			run.labor_changed.emit()
			game.call("_on_labor_chamber_pressed")
			print("WAHL gerüstet ", game.call("labor_picking"), " Station ", _rig().mode)
		520:
			_shot("tisch_wahl_vorrat")
			game.call("_stage_labor_die", run.owned_pool[0])
			game.call("_stage_labor_die", run.owned_pool[2])
			print("WAHL ", (game.call("labor_staged") as Array).size(), " gerüstet ",
				game.call("labor_picking"))
		600:
			_report()
			_shot("tisch_wahl_einsatz")
			game.call("_on_labor_start_pressed")
			print("START per Knopf ", run.labor_job != null)
		640:
			game.call("_skip_labor_roll")
		660:
			print("GLUECK daheim ", game.get("_luck_at"), " Wurf ", game.get("_labor_roll_face"))
			_report()
		670:
			return true
	return false
