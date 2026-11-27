extends GutTest
## Der GRUNDRISS als Ansicht (Welle 7 Teil B): EINE Zeichnung, zwei Fassungen. DETAIL nimmt
## Klick, Zug und Rad, COMPACT ist reine Übersicht.

const PIT_SIZE := Vector2(985, 484)

func _bosses() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(DealClause.ids_for(DealClause.Tier.BOSS, DealClause.Kind.MALUS).slice(0, 3))
	return ids

func _view(mode: FloorPlanView.Mode, view_size: Vector2 = PIT_SIZE) -> FloorPlanView:
	var view: FloorPlanView = add_child_autofree(FloorPlanView.new())
	view.mode = mode
	view.size = view_size
	return view

## Ein Lauf mit fälligem Zug und dessen Nahsicht, ganz herausgezoomt (alles im Bild).
func _detail_whole(run: GameRun) -> FloorPlanView:
	var view := _view(FloorPlanView.Mode.DETAIL)
	view.open(run.floor_view_state())
	view.zoom_at(view.map_rect().get_center(), -50.0)
	return view

func _px(view: FloorPlanView, cells: Vector2) -> Vector2:
	return view.geometry().to_px(cells)

func _room_center(view: FloorPlanView, room_id: String) -> Vector2:
	return view.geometry().room_rect(room_id).get_center()

## Ein Punkt im Raum, der weit genug von jeder Tür liegt.
func _room_point(view: FloorPlanView, room_id: String) -> Vector2:
	var rect := view.geometry().room_rect(room_id)
	for fx in [0.5, 0.3, 0.7]:
		for fy in [0.5, 0.3, 0.7]:
			var at := rect.position + rect.size * Vector2(fx, fy)
			if view.geometry().door_at(at) == "":
				return at
	return rect.get_center()

func _click(view: FloorPlanView, at: Vector2) -> void:
	view.begin_press(at)
	view.end_press(at)

func test_fifty_floors_draw_in_both_modes() -> void:
	var run := GameRun.new_run()
	var detail := _view(FloorPlanView.Mode.DETAIL)
	var compact := _view(FloorPlanView.Mode.COMPACT, Vector2(359, 783))
	for i in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		run.floor_index = i % 5
		run.floor_plan = FloorPlan.roll(rng, Callable(), 0.3, _bosses(), i % 5)
		run.floor_plan.scout(rng, Callable())
		if i % 7 == 3:
			run.floor_history.append(run.floor_plan.snapshot())
		var state := run.floor_view_state()
		detail.open(state)
		compact.open(state)
		assert_gt(detail.zoom_cell(), 0.0)
		assert_false(detail.geometry().trail_points().size() == 1)
		detail.queue_redraw()
		compact.queue_redraw()
		if i % 10 == 0:
			await wait_frames(1)
	await wait_frames(2)
	assert_eq(compact.state["history"].size(), run.floor_history.size())

func test_hits_find_rooms_and_doors() -> void:
	var run := GameRun.new_run()
	var view := _detail_whole(run)
	var geo := view.geometry()
	for room_id: String in geo.rooms:
		assert_eq(view.target_at(_room_point(view, room_id)), {"kind": "room", "id": room_id})
	for door_id: String in geo.doors:
		var at := _px(view, geo.doors[door_id]["center"])
		assert_eq(view.target_at(at), {"kind": "door", "id": door_id})
	assert_eq(view.target_at(Vector2(-5, -5)), {})

func test_a_room_click_takes_the_cheapest_move_and_a_door_click_that_door() -> void:
	var run := GameRun.new_run()
	var view := _detail_whole(run)
	var chosen: Array[Dictionary] = []
	view.move_chosen.connect(func(move: Dictionary) -> void: chosen.append(move))
	var move: Dictionary = run.walkable_moves()[0]
	var cheapest := run.floor_plan.cheapest_move(String(move["room"]))
	_click(view, _room_point(view, String(move["room"])))
	assert_eq(chosen.size(), 1)
	assert_eq(String(chosen[0]["door"]), String(cheapest["door"]), "der Raum nimmt den billigsten Zug")
	assert_eq(String(chosen[0]["fire_door"]), String(cheapest["fire_door"]))
	for option in run.walkable_moves():
		chosen.clear()
		_click(view, _px(view, view.geometry().doors[option["door"]]["center"]))
		assert_eq(chosen.size(), 1)
		assert_eq(String(chosen[0]["door"]), String(option["door"]), "die Tür nimmt genau sich")

func test_unwalkable_rooms_and_the_locked_office_report_nothing() -> void:
	var run := GameRun.new_run()
	var view := _detail_whole(run)
	var chosen: Array[Dictionary] = []
	view.move_chosen.connect(func(move: Dictionary) -> void: chosen.append(move))
	var walkable := {}
	for move in run.walkable_moves():
		walkable[move["room"]] = true
	for room_id: String in view.geometry().rooms:
		if walkable.has(room_id):
			continue
		_click(view, _room_point(view, room_id))
	assert_true(chosen.is_empty(), "nicht gangbare Räume schweigen")
	_click(view, _room_point(view, run.floor_plan.office))
	assert_true(chosen.is_empty(), "das Büro ohne Schlüsselkarte nimmt keinen Klick")
	view.hover_at(_room_point(view, run.floor_plan.office))
	assert_string_contains(view.info_text(), "Schlüsselkarte")

## Ein Lauf, dessen Etage größer ist als der Heimat-Ausschnitt - nur dort gibt es etwas zu schieben und hinauszuzoomen.
func _roomy(unit_px: float = 0.0) -> Array:
	for n in range(1, 80):
		var run := GameRun.new_run()
		var view := _view(FloorPlanView.Mode.DETAIL)
		if unit_px > 0.0:
			view.unit_px = unit_px
		view.open(run.floor_view_state())
		if view.whole_cell() < view.zoom_cell() - 1.0:
			return [run, view]
		view.free()
	return []

func test_a_drag_over_the_threshold_pans_both_ways_and_never_moves() -> void:
	var pair := _roomy()
	assert_eq(pair.size(), 2, "eine Etage mit Platz zum Schieben")
	if pair.is_empty():
		return
	var run: GameRun = pair[0]
	var view: FloorPlanView = pair[1]
	var chosen: Array[Dictionary] = []
	view.move_chosen.connect(func(move: Dictionary) -> void: chosen.append(move))
	var at := _room_point(view, String(run.walkable_moves()[0]["room"]))
	var before := view.view_center()
	view.begin_press(at)
	view.drag_to(at + Vector2(-40, -30))
	view.end_press(at + Vector2(-40, -30))
	assert_true(chosen.is_empty(), "ein Zug zieht nie")
	# Steht die Heimat am Rand, gibt nur die Gegenrichtung nach.
	if view.view_center().distance_to(before) < 0.01:
		view.begin_press(at)
		view.drag_to(at + Vector2(40, 30))
		view.end_press(at + Vector2(40, 30))
	var moved := view.view_center() - before
	assert_true(absf(moved.x) > 0.01 or absf(moved.y) > 0.01, "der Ausschnitt ist verschoben")
	view.snap_home(true)
	view.zoom_at(view.map_rect().get_center(), -3.0)
	var start := view.view_center()
	view.begin_press(view.map_rect().get_center())
	view.drag_to(view.map_rect().get_center() + Vector2(0, 60))
	view.end_press(view.map_rect().get_center() + Vector2(0, 60))
	view.begin_press(view.map_rect().get_center())
	view.drag_to(view.map_rect().get_center() + Vector2(60, 0))
	view.end_press(view.map_rect().get_center() + Vector2(60, 0))
	assert_true(chosen.is_empty())

func test_the_wheel_zooms_and_home_restores() -> void:
	var pair := _roomy()
	assert_eq(pair.size(), 2, "eine Etage mit Platz zum Zoomen")
	if pair.is_empty():
		return
	var view: FloorPlanView = pair[1]
	await wait_frames(1)
	var home := view.zoom_cell()
	assert_false(view.away_from_home())
	view.wheel(view.map_rect().get_center(), false)
	assert_lt(view.zoom_cell(), home, "das Rad zoomt hinaus")
	assert_gte(view.zoom_cell(), view.whole_cell() - 0.01, "nie weiter als die ganze Etage")
	assert_true(view.away_from_home())
	assert_true(view.find_child("ToHome", true, false).visible, "„Zum Standort“ steht")
	view.snap_home(true)
	assert_almost_eq(view.zoom_cell(), home, 0.01)
	assert_false(view.away_from_home())
	assert_false(view.find_child("ToHome", true, false).visible)

func test_zoomed_out_only_symbol_and_name() -> void:
	var pair := _roomy(15.0)  # große Schrift: die ganze Etage liegt unter der Schwelle
	assert_eq(pair.size(), 2, "eine Etage mit Platz zum Zoomen")
	if pair.is_empty():
		return
	var view: FloorPlanView = pair[1]
	view.zoom_at(view.map_rect().get_center(), -50.0)
	assert_lt(view.zoom_cell(), view.unit() * FloorPlanView.FULL_TEXT_CELL)
	assert_false(view.full_text())
	for room_id: String in view.geometry().rooms:
		assert_false(view.room_shows_text(room_id))
	assert_eq(view.label_px("bonus_text"), 0)
	assert_eq(view.label_px("bonus_name"), 0, "nur Symbol und Name")

func test_the_info_line_names_the_full_text_and_never_polster() -> void:
	var run := GameRun.new_run()
	run.round_scores.assign([400])
	var view := _detail_whole(run)
	var move: Dictionary = run.walkable_moves()[0]
	var room := run.floor_plan.room(String(move["room"]))
	view.hover_at(_room_point(view, String(move["room"])))
	assert_string_contains(view.info_text(), DealClause.text_for(String(room["bonus"])), "voller Bonus-Text")
	assert_string_contains(view.info_text(), "dein Schnitt")
	for door_id: String in view.geometry().doors:
		var door: Dictionary = view.geometry().doors[door_id]
		if String(door.get("malus_text", "")) != "":
			view.hover_at(_px(view, door["center"]))
			assert_string_contains(view.info_text(), String(door["malus_text"]), "voller Malus-Text")
			break
	view.snap_home(true)
	for text in view.label_texts():
		assert_eq(text.find("Polster"), -1)
	assert_eq(view.info_text().find("Polster"), -1)
	assert_null(view.find_child("Puck*", true, false), "kein Goldchip mehr")

func test_home_detail_carries_full_text_where_it_fits() -> void:
	var run := GameRun.new_run()
	var view := _view(FloorPlanView.Mode.DETAIL)
	view.open(run.floor_view_state())
	assert_true(view.full_text(), "die Heimat trägt Text")
	assert_gt(view.label_px("name"), 0)

func test_compact_takes_no_click_and_feeds_the_info() -> void:
	var run := GameRun.new_run()
	var view := _view(FloorPlanView.Mode.COMPACT, Vector2(359, 783))
	view.open(run.floor_view_state())
	var chosen: Array[Dictionary] = []
	view.move_chosen.connect(func(move: Dictionary) -> void: chosen.append(move))
	var move: Dictionary = run.walkable_moves()[0]
	var at := view.geometry().room_rect(String(move["room"])).get_center()
	assert_false(view.begin_press(at))
	view.end_press(at)
	view.press_at(at)
	assert_true(chosen.is_empty(), "der Streifen ist reine Übersicht")
	view.hover_at(at)
	assert_false(view.hovered().is_empty(), "der Zeiger speist die Auskunft")

func test_compact_stacks_the_history_and_the_wheel_rolls_it() -> void:
	var run := GameRun.new_run()
	for i in 3:
		run.settle_block_deals()
	var view := _view(FloorPlanView.Mode.COMPACT, Vector2(359, 783))
	view.open(run.floor_view_state())
	assert_eq(view.current_floor(), 4)
	assert_gt(view.stack_height(), view.map_rect().size.y, "drei geschaffte Etagen reichen unter den Rand")
	view.scroll_by(-1.0)
	assert_gt(view.scroll, 0.0, "das Rad rollt in die Geschichte")
	view.scroll_by(10.0)
	assert_eq(view.scroll, 0.0)
