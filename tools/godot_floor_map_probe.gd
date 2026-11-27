extends SceneTree
## Sichtprobe der ETAGEN-KARTE: Etagen-Beginn und mitten in der Etage (besuchter Weg,
## eine gesperrte und eine freie Tür), im Maß des echten Grubenbodens.
## Aufruf: --path . --resolution 1280x720 --position 4000,2400 --quit-after 600 --script tools/godot_floor_map_probe.gd

const OUT := "E:/Generated Images/Fumble/etagen_karte_2026-11-27/"
const SIZE := Vector2i(985, 484)

var _viewport: SubViewport
var _view: FloorMapView

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var ground := ColorRect.new()
	ground.color = Color("#0d1a14")
	ground.size = Vector2(SIZE)
	_viewport.add_child(ground)
	_view = FloorMapView.new()
	_view.size = Vector2(SIZE)
	_viewport.add_child(_view)
	_run.call_deferred()

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 27
	var run := GameRun.new_run()
	run.floor_map = FloorMap.roll(rng, run._clause_offerable, 0.0, run._boss_condition_ids(), 2)
	run.floor_map.scout_from(run.floor_map.position, rng, run._clause_offerable)
	run.advance_round()
	_view.open(run.floor_view_state())
	await _shot("1_etagen_beginn.png")

	# Mitten in der Etage: zwei Züge Richtung Büro, eine freie und eine gesperrte Tür.
	var map := run.floor_map
	for i in 2:
		var here := map.position
		for entry in map.doors_from(here):
			var next := map.other_side(entry, here)
			if map.shortest_moves(next, map.office) == map.shortest_moves(here, map.office) - 1:
				run.move_through(String(entry["id"]))
				break
		run.move_due = true
	for entry in map.doors_from(map.position):
		if int(entry["state"]) == FloorMap.DoorState.OPEN and not map.is_office_door(entry):
			entry["free"] = true
			entry["malus"] = ""
			break
	var candidates := map.lock_candidates()
	var locked := ""
	for entry in candidates:
		if not map.is_office_door(entry) and not bool(entry["free"]):
			entry["state"] = FloorMap.DoorState.LOCKED
			locked = String(entry["id"])
			break
	run.last_locked_door = locked
	_view.open(run.floor_view_state(), 1, locked)
	await _shot("2_mitten_blitz.png")
	await create_timer(FloorMapView.FLASH_TIME + 0.2).timeout
	var walk: Array = run.floor_view_state()["walkable"]
	var target := map.other_side(map.door(String(walk[0])), map.position)
	_view.hover_at(_view.room_rect(target).get_center())
	await _shot("3_mitten_hover_raum.png")
	_view.hover_at(_view.door_mark_rect(String(walk[walk.size() - 1])).get_center())
	await _shot("4_mitten_hover_tuer.png")
	quit()

func _shot(file: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	image.save_png(OUT + file)
	print("Bild: ", OUT + file)
