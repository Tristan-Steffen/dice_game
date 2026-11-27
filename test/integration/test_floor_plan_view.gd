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
		assert_true(detail.geometry().trail_segments().is_empty(), "ohne Zug kein Weg")
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

## Ein Lauf mitten in der Etage: n Züge gegangen, ein Zug fällig, ein Rundenschnitt steht.
func _walked(seed_value: int, steps: int) -> GameRun:
	var run := GameRun.new_run()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	run.floor_plan = FloorPlan.roll(rng, Callable(), 0.3, _bosses(), 0)
	run.floor_plan.scout(rng, Callable())
	run.round_scores.assign([300])
	for i in steps:
		var options: Array[Dictionary] = []
		for move in run.walkable_moves():
			if String(move["room"]) != run.floor_plan.office:
				options.append(move)
		if options.is_empty():
			break
		run.move_to(options[rng.randi_range(0, options.size() - 1)])
		run.move_due = true
	return run

func test_every_walkable_room_carries_its_price_block() -> void:
	var view := _view(FloorPlanView.Mode.DETAIL)
	for seed_value in range(1, 30):
		var run := _walked(seed_value, seed_value % 4)
		view.open(run.floor_view_state())
		for room_id in run.floor_plan.reachable_rooms():
			var cheapest := run.floor_plan.cheapest_move(room_id)
			var block := view.price_block(room_id)
			assert_false(block.is_empty(), "%s trägt einen Preis" % room_id)
			var door_line := FloorPlanView.segments_text(block["door"])
			var label := view.door_label(cheapest)
			assert_true(door_line.begins_with(FloorPlanView.PRICE_DOOR % String(label[0])), door_line)
			var fire := String(cheapest["fire_door"]) != ""
			assert_eq(door_line.find("Maut +") >= 0, fire, "die Maut nur bei einem Zug durch eine Brandschutztür")
			var blind: Array = block["blind"]
			assert_eq((blind[0] as Array)[1], FloorPlanView.TEXT_COLOR, "der Blind trägt keine Ampel")
			var last: Array = blind[blind.size() - 1]
			assert_true(String(last[0]).begins_with("dein Schnitt"), "die Ampel steht nur am Schnitt")
			var options := 0
			for move in run.walkable_moves():
				if String(move["room"]) == room_id:
					options += 1
			assert_eq(int(block["more"]), options - 1, "weitere Türen werden gezählt")

func test_the_door_label_follows_the_scale() -> void:
	var run := _walked(4, 0)
	var view := _view(FloorPlanView.Mode.DETAIL)
	view.open(run.floor_view_state())
	for move in run.walkable_moves():
		var entry: Dictionary = view.geometry().doors[String(move["door"])]
		var label := view.door_label(move)
		if bool(entry["passed"]):
			assert_eq(label[0], FloorPlanView.PRICE_PASSED)
		elif int(entry["tier"]) <= FloorPlan.TIER_FREE:
			assert_eq(label[0], FloorPlanView.PRICE_FREE)
		else:
			assert_eq(label[0], String(entry["malus_name"]))
			assert_eq(label[1], FloorPlanView.DOOR_TIER_COLORS[clampi(int(entry["tier"]), 0, 3)])

func test_no_toll_marks_on_rooms_and_no_names_in_the_corridor() -> void:
	var view := _view(FloorPlanView.Mode.DETAIL)
	assert_false(view.has_method("_draw_door_label"), "keine Malus-Namen im Flur")
	var run := _walked(7, 2)
	view.open(run.floor_view_state())
	var maluses := {}
	for entry: Dictionary in view.geometry().doors.values():
		if String(entry.get("malus_name", "")) != "":
			maluses[String(entry["malus_name"])] = true
	for text in view.label_texts():
		assert_false(maluses.has(text), "%s steht nicht lose im Grundriß" % text)

func test_the_plan_area_lies_between_head_and_foot() -> void:
	var view := _view(FloorPlanView.Mode.DETAIL)
	view.open(GameRun.new_run().floor_view_state())
	assert_eq(view.map_rect().position.y, view.head_rect().end.y)
	assert_eq(view.map_rect().end.y, view.info_rect().position.y, "der Plan endet über der Auskunft")
	assert_eq(FloorPlanView.BAR_BG.a, 1.0, "Kopf und Fuß decken")
	var home: Array = view.home_view()
	var half: Vector2 = view.map_rect().size / float(home[1]) * 0.5
	var here := view.geometry().home_rect_cells()
	assert_true(Rect2(Vector2(home[0]) - half, half * 2.0).grow(0.01).encloses(here), "der Standort liegt ganz im Plan-Bereich")

func test_labels_never_overlap_and_stay_in_their_room() -> void:
	var view := _view(FloorPlanView.Mode.DETAIL)
	var bad := 0
	for i in 50:
		var run := _walked(2000 + i, i % 4)
		view.open(run.floor_view_state())
		view.snap_home(true)
		var geo := view.geometry()
		var all := view.label_rects()
		for room_id: String in all:
			var room := geo.room_rect(room_id).grow(0.5)
			var rects: Array = all[room_id]
			for a in rects.size():
				var ra: Rect2 = rects[a]
				if not room.encloses(ra):
					bad += 1
					if bad <= 5:
						gut.p("Etage %d %s: %s ragt aus %s" % [i, room_id, ra, room])
				for b in range(a + 1, rects.size()):
					if ra.grow(-0.5).intersects((rects[b] as Rect2).grow(-0.5)):
						bad += 1
						if bad <= 5:
							gut.p("Etage %d %s: %s schneidet %s" % [i, room_id, ra, rects[b]])
	assert_eq(bad, 0, "keine Beschriftung schneidet eine andere oder ragt aus ihrem Raum")

func test_the_trail_draws_every_stretch_once() -> void:
	var run := _walked(11, 6)
	var view := _view(FloorPlanView.Mode.DETAIL)
	view.open(run.floor_view_state())
	var segs := view.geometry().trail_segments()
	assert_gt(segs.size(), 0)
	for i in segs.size():
		for j in range(i + 1, segs.size()):
			assert_lt(_overlap(segs[i], segs[j]), 0.01, "keine Strecke doppelt")
	var ages := {}
	for seg: Dictionary in segs:
		ages[int(seg["age"])] = true
	assert_true(ages.has(0), "der letzte Zug ist dabei")

## Gemeinsame Länge zweier achsparalleler Strecken auf derselben Linie (0 = keine).
func _overlap(p: Dictionary, q: Dictionary) -> float:
	var a1: Vector2 = p["a"]
	var b1: Vector2 = p["b"]
	var a2: Vector2 = q["a"]
	var b2: Vector2 = q["b"]
	if absf(a1.y - b1.y) < 0.001 and absf(a2.y - b2.y) < 0.001 and absf(a1.y - a2.y) < 0.001:
		return minf(maxf(a1.x, b1.x), maxf(a2.x, b2.x)) - maxf(minf(a1.x, b1.x), minf(a2.x, b2.x))
	if absf(a1.x - b1.x) < 0.001 and absf(a2.x - b2.x) < 0.001 and absf(a1.x - a2.x) < 0.001:
		return minf(maxf(a1.y, b1.y), maxf(a2.y, b2.y)) - maxf(minf(a1.y, b1.y), minf(a2.y, b2.y))
	return 0.0

func test_brightness_ranks_open_fire_and_unwalkable() -> void:
	var run := _walked(3, 1)
	var view := _view(FloorPlanView.Mode.DETAIL)
	view.open(run.floor_view_state())
	for room_id: String in view.geometry().rooms:
		var plain := false
		var fire := false
		for move in run.walkable_moves():
			if String(move["room"]) == room_id:
				if String(move["fire_door"]) == "":
					plain = true
				else:
					fire = true
		var expected := FloorPlanView.REACH_OPEN if plain else (FloorPlanView.REACH_FIRE if fire else FloorPlanView.REACH_NONE)
		assert_eq(view.room_reach(room_id), expected, room_id)
		var current := room_id == run.floor_plan.position
		assert_eq(view.room_dimmed(room_id), expected == FloorPlanView.REACH_NONE and not current, room_id)
	if not run.floor_plan.key_taken:
		assert_true(view.room_dimmed(run.floor_plan.office), "das Büro ohne Karte ist gedimmt")
	view.read_only = true
	for room_id: String in view.geometry().rooms:
		assert_false(view.room_dimmed(room_id), "nur ansehen dimmt nichts")

func test_a_walkable_room_names_bonus_and_door_in_the_info() -> void:
	var run := _walked(5, 1)
	var view := _detail_whole(run)
	var move: Dictionary = run.walkable_moves()[0]
	var room_id := String(move["room"])
	view.hover_at(_room_point(view, room_id))
	var info := view.info_parts()
	assert_ne(String(info["door"]), "", "die Tür steht in der Auskunft")
	var label := view.door_label(run.floor_plan.cheapest_move(room_id))
	assert_string_contains(String(info["door"]), String(label[0]))
	var bonus := String(run.floor_plan.rooms[room_id]["bonus"])
	if not bool(run.floor_plan.rooms[room_id]["visited"]):
		assert_string_contains(String(info["body"]), DealClause.text_for(bonus))
