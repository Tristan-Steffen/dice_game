extends SceneTree
## Klick-Probe des LABORS mit ECHTEN Maus-Ereignissen: je Station Kammer-Klick (rüstet die
## Wahl), Tipps auf die Einsätze (Pool-Würfel, Charm-Diskette, gestecktes Modul, Magazin-
## Karte), Rechtsklick, START, Wurf überspringen, Abholen per Kammer-Klick.
## Aufruf:
##   Godot --path . --fixed-fps 60 --resolution 1280x720 --position 4000,2400 --quit-after 1800 \
##     --script tools/godot_labor_pick_probe.gd
## Bilder: E:/Generated Images/Fumble/labor_spiel_2026-11-26/politur_*.png

const OUT := "E:/Generated Images/Fumble/labor_spiel_2026-11-26/"

var game: Node
var fails := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	_probe.call_deferred()

func _rig() -> CameraRig:
	return game.get("camera_rig")

func _run() -> GameRun:
	return game.get("run")

func _screen() -> TableScreen:
	return game.get("table_screen")

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _settle(min_frames := 20) -> void:
	await _frames(min_frames)
	var guard := 0
	while _rig().is_animating and guard < 300:
		await process_frame
		guard += 1
	await _frames(5)

func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("SHOT ", name)

func _check(label: String, ok: bool, extra := "") -> void:
	print("CHECK ", label, " ", "ok" if ok else "FAIL", " ", extra)
	if not ok:
		fails += 1

func _px(world: Vector3) -> Vector2:
	return _rig().unproject_position(world)

func _display_px(pixel: Vector2) -> Vector2:
	return _px(_screen().pixel_to_world(pixel))

## Viewport-Koordinaten in Fenster-Koordinaten (parse_input_event rechnet die Streckung zurück).
func _win(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos

func _move(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _win(pos)
	motion.global_position = _win(pos)
	Input.parse_input_event(motion)
	await _frames(3)

func _click(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	await _move(pos)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.position = _win(pos)
		ev.global_position = _win(pos)
		Input.parse_input_event(ev)
		await _frames(2)
	await _frames(4)

func _labor_part(key: String) -> Vector2:
	return _display_px(_screen().labor_part_px(key).get_center())

func _open_labor(station: String) -> void:
	var run := _run()
	run.labor_job = null
	run.stress_tests_passed = 1
	if run.labor_station == "":
		run.open_labor()
	run.labor_station = station
	run.energy = run.energy_cap()
	run.labor_changed.emit()
	_rig().zoom_to(CameraRig.Mode.LABOR)
	await _settle()

## Kammer-Klick an der Station rüstet die Wahl.
func _arm(station: String) -> void:
	await _open_labor(station)
	await _click(_labor_part("chamber"))
	_check(station + " gerüstet", bool(game.call("labor_picking")), "Modus %d" % _rig().mode)
	await _settle()

func _start_and_collect(station: String) -> void:
	await _settle()
	_check(station + " zurück am Labor", _rig().mode == CameraRig.Mode.LABOR)
	var state: Dictionary = (_screen().labor_window as LaborView).body_state()
	_check(station + " START leuchtet", bool(state["start_lit"]), str(state["status"]))
	await _click(_labor_part("start"))
	_check(station + " START bucht", _run().labor_job != null, "Energie %d Preis %d Status %s" % [
		_run().energy, _run().labor_price(), str((_screen().labor_window as LaborView).body_state()["status"])])
	if _run().labor_job == null:
		return
	await _frames(14)
	await _shot("politur_flug_" + station)
	var tray: DiceTrayView = game.get("pool_tray_view")
	var lab := _run().labor_job.dice.duplicate()
	if station == Labor.SEELE:
		_check("seele Sitze leer", tray.slot_defs.find(lab[0]) < 0 and tray.slot_defs.find(lab[1]) < 0
			and tray.slot_defs.size() >= _run().owned_pool.size(),
			"Sitze %d Vorrat %d" % [tray.slot_defs.size(), _run().owned_pool.size()])
	await _frames(26)
	await _click(_labor_part("start"))  # ein Klick springt den Wurf ans Ende
	await _frames(30)
	_check(station + " Wurf fertig", int(game.get("_labor_roll_face")) < 0)
	await _move(Vector2(40, 700))
	await _frames(60)
	await _shot("politur_labor_laeuft_" + station)
	if station == Labor.SEELE:
		await _hint_shot("chamber", "politur_hinweis_kammer")
		await _hint_shot("start", "politur_hinweis_start")
		_rig().zoom_out()
		await _settle()
		await _hint_shot("chamber", "politur_hinweis_uebersicht")
		game.call("_zoom_to_mode", CameraRig.Mode.POOL)
		await _settle()
		game.call("_open_deck_glass", true)
		await _settle(90)
		var glass: DeckGlassView = _screen().deck_glass_window
		var cells := glass.grid().tiles
		var at := _run().owned_pool.find(lab[0])
		_check("raster Labor-Sitz leer", at >= 0 and at < cells.size() and cells[at] == null,
			"Sitz %d Kacheln %d" % [at, cells.size()])
		await _shot("politur_raster_labor")
		game.call("_close_deck_glass")
		await _settle()
		_rig().zoom_to(CameraRig.Mode.LABOR)
		await _settle()
	while not _run().labor_job.done:
		_run().labor_job.tick()
	_run().labor_changed.emit()
	await _frames(10)
	await _click(_labor_part("chamber"))
	_check(station + " abgeholt", _run().labor_job == null)
	await _frames(12)
	await _shot("politur_heim_" + station)
	if station == Labor.SEELE:
		_check("seele Sitz im Heimflug leer", tray.slot_defs.find(lab[0]) < 0)
	await _frames(50)
	if station == Labor.SEELE:
		_check("seele Sitz nach Landung", tray.slot_defs.find(lab[0]) >= 0)
	if station == Labor.CHARM:
		var row: CharmRowView = game.get("charm_row")
		_check("charm Kopie in der Reihe", row.current_charms.size() == _run().owned_charms.size()
			and row.withheld() == null, "Reihe %d Besitz %d" % [row.current_charms.size(), _run().owned_charms.size()])

## Der Zeiger dieser Probe ist synthetisch (get_mouse_position liest das echte Fenster):
## die Hinweis-Karte wird darum im Bild vor dem Zeichnen so gestellt wie _sync_labor_hint.
func _hint_shot(part: String, name: String) -> void:
	var view: LaborView = _screen().labor_window
	var pixel := _screen().labor_part_px(part).get_center()
	for i in 4:
		await RenderingServer.frame_pre_draw
		_screen().show_labor_hint(_screen().labor_hint_box(), LaborView.station_name(_run().labor_station),
			view.hint_at(pixel - view.position), CasinoStyle.ENERGY)
	await RenderingServer.frame_post_draw
	_shot(name)
	var card: Control = _screen().labor_hint
	print("HINT ", part, " karte ", Rect2(card.position, card.size), " labor ", game.call("labor_rect_px"),
		" markt ", Rect2(_screen().secret_shop_window.position, _screen().secret_shop_window.size))

func _probe() -> void:
	await _frames(30)
	game.call("_on_title_new_game")
	await _settle(120)
	var run := _run()

	# --- SEELE: zwei Pool-Würfel per Tipp ---
	run.owned_pool[0].essence_id = Essence.all()[0].id
	run.pool_changed.emit()
	await _arm(Labor.SEELE)
	var tray: DiceTrayView = game.get("pool_tray_view")
	await _click(_px(tray.slot_global_position(0)))
	_check("seele Quelle", (game.call("labor_staged") as Array).size() == 1)
	await _shot("politur_wahl_vorrat")
	await _click(_px(tray.slot_global_position(1)))
	_check("seele Ziel", (game.call("labor_staged") as Array).size() == 2)
	await _start_and_collect(Labor.SEELE)

	# --- CHARM: eine Diskette per Tipp ---
	run.owned_charms.append(Charm.rabbits_foot())
	run.charms_changed.emit()
	await _frames(20)
	await _arm(Labor.CHARM)
	var row: CharmRowView = game.get("charm_row")
	var at: Vector3 = row.charm_nodes[0].global_position if not row.charm_nodes.is_empty() \
		else row.readers[0].global_position
	await _click(_px(at))
	_check("charm gewählt", (game.call("labor_staged") as Array).size() == 1
		or _run().labor_job != null)
	await _start_and_collect(Labor.CHARM)

	# --- MODUL: ein gestecktes Modul per Tipp ---
	var key: String = DiceScoring.HAND_PRIORITY[0]
	run.combo_parts[key] = [ComboPart.resistor(), null, null]
	run.combo_parts_changed.emit(key)
	await _frames(20)
	await _arm(Labor.MODUL)
	var chip: ComboChipView = (game.get("combo_chips") as Dictionary)[key]
	await _shot("politur_wahl_modul")
	# Die Stations-Kamera neigt sich zum Zeiger: erst hinfahren, setzen lassen, dann neu messen.
	var pin_at := chip.pin_world(0) + Vector3.UP * ComboPartBody.TOP * 0.8
	for _settle in 4:
		await _move(_px(pin_at))
		await _frames(30)
	# Der Klick gilt dem Pixel, den das Spiel selbst Fach 0 zuschreibt - gesucht mit dem Zeiger
	# schon dort, denn die Kamera neigt sich mit ihm.
	var hit := _px(pin_at)
	for _try in 8:
		await _move(hit)
		await _frames(40)
		var here: Dictionary = game.call("_part_pick_at", hit)
		if not here.is_empty() and String(here["key"]) == key and int(here["slot"]) == 0:
			break
		var best := hit
		var best_d := INF
		for dy in range(-72, 73, 6):
			for dx in range(-72, 73, 6):
				var probe_px := hit + Vector2(dx, dy)
				var pick: Dictionary = game.call("_part_pick_at", probe_px)
				if not pick.is_empty() and String(pick["key"]) == key and int(pick["slot"]) == 0 \
						and Vector2(dx, dy).length() < best_d:
					best = probe_px
					best_d = Vector2(dx, dy).length()
		hit = best
	print("DIAG modul Klick bei ", hit, " trifft ", game.call("_part_pick_at", hit))
	await _click(hit)
	_check("modul gewählt", (game.call("labor_staged") as Array).size() == 1)
	await _start_and_collect(Labor.MODUL)
	# Die Kopie wartet im EINBAU; aufräumen, damit er die nächste Wahl nicht sperrt.
	run.pending_parts.clear()
	run.pending_parts_changed.emit()
	await _frames(20)

	# --- KARTEN: zwei Magazin-Karten per Tipp, Rechtsklick schließt ab ---
	var a := run.grant_pack(Pack.number_pack())
	var b := run.grant_pack(Pack.material_pack())
	run.packs_changed.emit()
	await _frames(30)
	await _arm(Labor.KARTEN)
	var workshop: WorkshopView = _screen().workshop_window
	await _click(_display_px(workshop.pack_anchor_px(a.pack_uid)))
	await _click(_display_px(workshop.pack_anchor_px(b.pack_uid)))
	_check("karten zwei gewählt", (game.call("labor_staged") as Array).size() == 2,
		str(game.call("labor_staged")))
	await _shot("politur_wahl_karten")
	await _click(Vector2(640, 360), MOUSE_BUTTON_RIGHT)
	_check("karten Rechtsklick schließt", not bool(game.call("labor_picking")))
	await _start_and_collect(Labor.KARTEN)

	print("PROBE fertig, Fehler: ", fails)
	quit()
