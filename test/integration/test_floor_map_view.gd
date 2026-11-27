extends GutTest
## Die ETAGEN-KARTE als Fenster (FloorMapView): Kachel je Raum, Marke je Türzustand,
## nur gangbare Nachbarn nehmen den Klick, die Auskunft folgt dem Zeiger.

var view: FloorMapView
var run: GameRun
var chosen: Array[String] = []

func before_each() -> void:
	run = GameRun.new_run()
	run.advance_round()  # ab Runde 2 ist ein Zug fällig
	view = add_child_autofree(FloorMapView.new())
	view.size = Vector2(985, 484)  # das Maß auf dem echten Grubenboden
	chosen.clear()
	view.door_chosen.connect(func(door_id: String) -> void: chosen.append(door_id))

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

## Eine Etage mit allen Türzuständen: alles erkundet, dann je eine Tür durchschritten,
## gesperrt, unerkundet und frei - keine davon am Eingang.
func _mixed_floor() -> Dictionary:
	var bosses: Array[String] = []
	bosses.assign(DealClause.ids_for(DealClause.Tier.BOSS, DealClause.Kind.MALUS).slice(0, 3))
	var map := FloorMap.roll(_rng(9), Callable(), 0.0, bosses, 0)
	for room_id: String in map.rooms:
		map.scout_from(room_id, _rng(10), Callable())
	run.floor_map = map
	var inner: Array[Dictionary] = []
	for entry in map.doors:
		if not map.is_office_door(entry) and entry["a"] != map.entrance and entry["b"] != map.entrance:
			inner.append(entry)
	inner[0]["state"] = FloorMap.DoorState.PASSED
	inner[1]["state"] = FloorMap.DoorState.LOCKED
	inner[2]["scouted"] = false
	inner[3]["free"] = true
	inner[3]["malus"] = ""
	return {"passed": String(inner[0]["id"]), "locked": String(inner[1]["id"]),
		"unknown": String(inner[2]["id"]), "free": String(inner[3]["id"]),
		"locked_malus": String(inner[1]["malus"])}

func _label(node_name: String) -> Label:
	return view.get_node_or_null(node_name) as Label

func _label_texts() -> Array[String]:
	var texts: Array[String] = []
	for child in view.get_children():
		if child is Label:
			texts.append((child as Label).text)
	return texts

func test_every_room_is_a_tile_with_its_name() -> void:
	view.open(run.floor_view_state())
	for room: Dictionary in run.floor_view_state()["rooms"]:
		var label := _label("Room_" + String(room["id"]))
		assert_not_null(label, "Kachel für %s" % room["id"])
		assert_eq(label.text, String(room["name"]))
		assert_gt(view.room_rect(String(room["id"])).size.x, 0.0)

func test_room_tiles_never_overlap_and_marks_stay_off_tiles() -> void:
	_mixed_floor()
	view.open(run.floor_view_state())
	var rooms: Array = run.floor_view_state()["rooms"]
	for i in rooms.size():
		var a := view.room_rect(String(rooms[i]["id"]))
		for j in range(i + 1, rooms.size()):
			assert_false(a.intersects(view.room_rect(String(rooms[j]["id"]))), "Kacheln überlappen")
		for door: Dictionary in run.floor_view_state()["doors"]:
			var mark := view.door_mark_rect(String(door["id"]))
			assert_false(mark.intersects(a.grow(-1.0)), "Marke %s liegt auf %s" % [door["id"], rooms[i]["id"]])

func test_the_bonus_name_stands_on_an_unvisited_room() -> void:
	view.open(run.floor_view_state())
	for room_id in run.floor_map.room_ids():
		var bonus := String(run.floor_map.rooms[room_id]["bonus"])
		var label := _label("Bonus_" + room_id)
		assert_not_null(label)
		assert_eq(label.text, DealClause.find(bonus).display_name)

func test_marks_follow_the_door_state() -> void:
	var doors := _mixed_floor()
	view.open(run.floor_view_state())
	assert_null(_label("Mark_" + doors["passed"]), "ausgebrannt: nur der helle Weg")
	assert_null(_label("Mark_" + doors["locked"]), "gesperrt: ohne Inhalt")
	assert_eq(_label("Mark_" + doors["unknown"]).text, FloorMapView.UNKNOWN_TEXT)
	assert_eq(_label("Mark_" + doors["free"]).text, FloorMapView.FREE_TEXT)
	for entry in run.floor_map.doors:
		if int(entry["state"]) != FloorMap.DoorState.OPEN or not bool(entry["scouted"]) or bool(entry["free"]):
			continue
		var clause := String(entry["boss"]) if String(entry["boss"]) != "" else String(entry["malus"])
		assert_eq(_label("Mark_" + String(entry["id"])).text, DealClause.find(clause).display_name)

func test_office_doors_show_the_boss_condition_from_the_start() -> void:
	view.open(run.floor_view_state())
	for entry in run.floor_map.doors_from(run.floor_map.office):
		assert_eq(_label("Mark_" + String(entry["id"])).text,
			DealClause.find(String(entry["boss"])).display_name)

func test_a_locked_door_shows_nothing_of_its_malus() -> void:
	var doors := _mixed_floor()
	view.open(run.floor_view_state())
	var name_text := DealClause.find(String(doors["locked_malus"])).display_name
	assert_false(_label_texts().has(name_text), "der Malus der gesperrten Tür steht nirgends")
	view.hover_at(view.door_mark_rect(doors["locked"]).get_center())
	assert_string_contains(view.info_text(), FloorMapView.LOCKED_TITLE)
	assert_false(view.info_text().contains(name_text))

func test_only_walkable_neighbours_take_the_click() -> void:
	var state := run.floor_view_state()
	view.open(state)
	var walk: Array = state["walkable"]
	assert_gt(walk.size(), 0)
	for room: Dictionary in state["rooms"]:
		chosen.clear()
		var room_id := String(room["id"])
		var expected := ""
		for door_id: String in walk:
			var entry := run.floor_map.door(door_id)
			if run.floor_map.other_side(entry, run.floor_map.position) == room_id:
				expected = door_id
		var took := view.press_at(view.room_rect(room_id).get_center())
		if expected == "":
			assert_false(took, "%s nimmt keinen Klick" % room_id)
			assert_true(chosen.is_empty())
		else:
			assert_true(took)
			assert_eq(chosen, [expected] as Array[String], "%s meldet seine Tür" % room_id)

func test_a_walkable_door_mark_takes_the_click_too() -> void:
	var walk: Array = run.floor_view_state()["walkable"]
	view.open(run.floor_view_state())
	assert_true(view.press_at(view.door_mark_rect(String(walk[0])).get_center()))
	assert_eq(chosen, [String(walk[0])] as Array[String])

func test_without_a_due_move_nothing_takes_the_click() -> void:
	run.move_due = false
	view.open(run.floor_view_state())
	for room: Dictionary in run.floor_view_state()["rooms"]:
		assert_false(view.press_at(view.room_rect(String(room["id"])).get_center()))
	assert_true(chosen.is_empty())

func test_the_info_names_the_bonus_and_the_blind_after_the_move() -> void:
	var state := run.floor_view_state()
	view.open(state, 2)
	var door_id := String((state["walkable"] as Array)[0])
	var target := run.floor_map.other_side(run.floor_map.door(door_id), run.floor_map.position)
	var bonus := String(run.floor_map.rooms[target]["bonus"])
	view.hover_at(view.room_rect(target).get_center())
	assert_string_contains(view.info_text(), DealClause.text_for(bonus, 2), "voller Bonus-Text mit Faktor")
	assert_string_contains(view.info_text(),
		FloorMapView.BLIND_LINE % [run.next_blind(), roundi(run.blind_growth() * 100.0)])

func test_a_far_room_names_its_bonus_without_a_blind_line() -> void:
	view.open(run.floor_view_state())
	for room_id in run.floor_map.room_ids():
		if view.door_to(room_id) != "":
			continue
		view.hover_at(view.room_rect(room_id).get_center())
		var bonus := String(run.floor_map.rooms[room_id]["bonus"])
		assert_string_contains(view.info_text(), DealClause.text_for(bonus))
		assert_false(view.info_text().contains("Blind nach diesem Zug"), "nur gangbare Züge nennen den Blind")
		return

func test_the_info_names_a_scouted_door_malus() -> void:
	view.open(run.floor_view_state())
	for entry in run.floor_map.doors_from(run.floor_map.entrance):
		if String(entry["malus"]) == "":
			continue
		view.hover_at(view.door_mark_rect(String(entry["id"])).get_center())
		assert_string_contains(view.info_text(), DealClause.text_for(String(entry["malus"])))
		return
	pass_test("keine Eingangstür mit Malus in diesem Wurf")

func test_the_head_names_floor_move_and_blind() -> void:
	view.open(run.floor_view_state())
	assert_eq(_label("Head").text, "Etage 1 · Zug 1")
	assert_eq(_label("HeadBlind").text, FloorMapView.BLIND_HEAD % run.effective_goal())

func test_the_locked_door_flashes_once_but_stays_locked() -> void:
	var doors := _mixed_floor()
	view.open(run.floor_view_state(), 1, doors["locked"])
	assert_eq(view.flashing_door(), doors["locked"])
	assert_null(_label("Mark_" + doors["locked"]), "Endzustand zuerst: gesperrt gemalt")
	await wait_seconds(FloorMapView.FLASH_TIME + 0.1)
	assert_eq(view.flashing_door(), "")
