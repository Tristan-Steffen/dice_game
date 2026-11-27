extends GutTest
## Der GRUNDRISS im Lauf (Welle 7 Teil B): Zug, Maut, Schlüsselkarte, Büro, Runde 1,
## Vorschau gleich Buchung, Aufzug und Geschichte.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

## Leert die Etage: ein Zug hebt dann nur den Blind.
func _quiet_floor() -> void:
	for room_id: String in run.floor_plan.rooms:
		run.floor_plan.rooms[room_id]["bonus"] = ""
	for entry in run.floor_plan.doors:
		entry["malus"] = ""
		entry["boss"] = ""

## Ein gangbarer Zug ohne bzw. mit Brandschutztür, nie ins Büro ({} = keiner).
func _move(fire: bool) -> Dictionary:
	for move in run.walkable_moves():
		if move["room"] != run.floor_plan.office and (String(move["fire_door"]) != "") == fire:
			return move
	return {}

## Ein Lauf, dessen Aufzug einen Zug durch eine Brandschutztür bietet.
func _run_with_fire_move() -> Dictionary:
	for attempt in 40:
		var move := _move(true)
		if not move.is_empty():
			return move
		run = GameRun.new_run()
	return {}

func test_round_one_begins_with_a_room_choice() -> void:
	assert_eq(run.round_number, 1)
	assert_true(run.move_due, "auch Runde 1 wählt einen Raum")
	assert_false(run.walkable_moves().is_empty())
	assert_eq(run.floor_plan.position, "", "man steigt aus dem Aufzug")
	assert_eq(run.effective_goal(), GameRun.BASE_GOAL, "bis zum Zug steht der Start-Blind")
	_quiet_floor()
	assert_true(run.move_to(_move(false)))
	assert_eq(run.round_goal, GameRun.floor_to_blind(150.0 * 1.1), "der erste Zug hebt ihn")
	assert_false(run.move_due)

func test_no_move_leads_into_the_elevator() -> void:
	for step in 6:
		for move in run.walkable_moves():
			assert_ne(String(move["room"]), "", "der Aufzug ist kein Raum")
			assert_true(run.floor_plan.rooms.has(move["room"]))
		var next := _move(false)
		if next.is_empty():
			break
		run.move_to(next)
		run.advance_round()

func test_a_move_signs_bonus_and_malus_once() -> void:
	var move := _move(false)
	var entry := run.floor_plan.door(String(move["door"]))
	entry["malus"] = DealClause.ids_for(DealClause.Tier.ONE, DealClause.Kind.MALUS)[0]
	entry["free"] = false
	var expected := run.move_clauses(move)
	assert_eq(expected.size(), 2, "Bonus des Raums und Malus der Tür")
	assert_true(run.move_to(move))
	var signed: Array[String] = []
	for deal in run.active_deals:
		signed.append(String(deal["id"]))
	assert_eq(signed, expected, "genau die angekündigten Klauseln")
	assert_true(bool(run.floor_plan.room(String(move["room"]))["visited"]))
	assert_true(bool(entry["passed"]), "die Tür ist ausgebrannt")
	# Zurück in denselben Raum durch dieselbe Tür unterschreibt nichts mehr.
	run.advance_round()
	run.floor_plan.position = ""
	for option in run.walkable_moves():
		if option["door"] == move["door"]:
			assert_true(run.move_clauses(option).is_empty(), "besucht und ausgebrannt")

func test_the_toll_is_booked_on_every_crossing() -> void:
	var move := _run_with_fire_move()
	if move.is_empty():
		pending("kein Aufzug mit Brandschutztür gewürfelt")
		return
	_quiet_floor()
	var start_section := String(move["section_from"])
	var g1 := run.blind_growth(1)
	var g2 := run.blind_growth(2)
	assert_eq(run.toll_percent(), roundi(g1 * 100.0), "die Maut ist der laufende Schritt")
	assert_true(run.move_to(move))
	assert_eq(run.floor_moves, 2, "Maut und Zug zählen je einen Schritt")
	assert_almost_eq(run.blind_value, 150.0 * (1.0 + g1) * (1.0 + g2), 0.001)
	# Zurück über eine Brandschutztür kostet wieder.
	run.advance_round()
	var back: Dictionary = {}
	for option in run.walkable_moves():
		if String(option["fire_door"]) != "" and String(option["section_to"]) == start_section \
				and option["room"] != run.floor_plan.office:
			back = option
	if back.is_empty():
		return
	var before := run.blind_value
	assert_true(run.move_to(back))
	assert_eq(run.floor_moves, 4, "die zweite Durchquerung kostet wieder")
	assert_almost_eq(run.blind_value, before * (1.0 + run.blind_growth(3)) * (1.0 + run.blind_growth(4)), 0.001)

func test_preview_equals_booking_with_and_without_fire_door_and_blind_clause() -> void:
	for fire in [false, true]:
		for clause in ["", DealClause.QUOTA_SHOCK]:
			run = GameRun.new_run()
			var move := _move(fire)
			if fire and move.is_empty():
				move = _run_with_fire_move()
			if move.is_empty():
				continue
			var entry := run.floor_plan.door(String(move["door"]))
			entry["malus"] = clause
			entry["boss"] = ""
			run.floor_plan.room(String(move["room"]))["bonus"] = ""
			var preview := run.blind_after_move(move)
			assert_true(run.move_to(move))
			assert_eq(preview, run.effective_goal(), "Brandschutz %s, Klausel %s" % [fire, clause])

func test_the_office_needs_the_key_card() -> void:
	var plan := run.floor_plan
	for room_id: String in plan.rooms:
		for move in plan.moves_from(room_id, false):
			assert_ne(String(move["room"]), plan.office, "ohne Karte kein Zug ins Büro")
	for move in run.walkable_moves():
		assert_ne(String(move["room"]), plan.office)
	# Mit Karte: ein Raum neben dem Büro führt hinein, und das ist die Boss-Runde.
	var into: Dictionary = {}
	for room_id: String in plan.rooms:
		if room_id == plan.office:
			continue
		for move in plan.moves_from(room_id, true):
			if move["room"] == plan.office:
				plan.position = room_id
				into = move
				break
		if not into.is_empty():
			break
	assert_false(into.is_empty())
	plan.key_taken = true
	var boss := String(plan.door(String(into["door"]))["boss"])
	assert_true(run.move_to(into))
	assert_true(run.is_boss_round(), "der Zug ins Büro macht die Boss-Runde")
	var signed: Array[String] = []
	for deal in run.active_deals:
		signed.append(String(deal["id"]))
	assert_has(signed, boss, "die Kondition der gewählten Tür")

func test_taking_the_key_card_shows_in_the_state() -> void:
	var plan := run.floor_plan
	assert_false(bool(run.floor_view_state()["key_taken"]), "noch nicht geholt")
	# Der Standort wird ein Raum, von dem ein Zug in den Kartenraum führt.
	for room_id: String in plan.rooms:
		for move in plan.moves_from(room_id, false):
			if move["room"] == plan.key_room and room_id != plan.key_room:
				plan.position = room_id
				assert_true(run.move_to(move))
				assert_true(bool(run.floor_view_state()["key_taken"]))
				return
	fail_test("kein Weg in den Kartenraum")

func test_the_elevator_rolls_the_next_floor_and_the_history_grows() -> void:
	var first := run.floor_plan
	run.settle_block_deals()
	assert_eq(run.floor_index, 1)
	assert_ne(run.floor_plan, first, "eine neue Etage")
	assert_eq(run.floor_moves, 0)
	assert_eq(run.floor_plan.position, "", "man steht im Aufzug")
	assert_eq(run.floor_history.size(), 1)
	assert_eq(int(run.floor_history[0]["floor_index"]), 0)
	assert_true(run.floor_history[0].has("walls"), "die Geschichte trägt ihre Zeichnung")
	assert_eq(var_to_str(run.floor_history).find("Object("), -1, "nur Werte")
	run.settle_block_deals()
	assert_eq(run.floor_history.size(), 2)
	assert_eq((run.floor_view_state()["history"] as Array).size(), 2)
	assert_true(GameRun.new_run().floor_history.is_empty(), "ein neuer Lauf beginnt leer")

func test_a_fumble_leaves_the_floor_alone() -> void:
	var before := run.floor_plan.snapshot()
	run.note_fumble(false)
	assert_eq(run.floor_plan.snapshot(), before, "Fumbles sperren keine Türen mehr")
	assert_false("last_locked_door" in run)
	assert_false(run.has_method("locked_door_note"))

func test_the_floor_state_is_plain_and_complete() -> void:
	var state := run.floor_view_state()
	for key in ["rooms", "doors", "moves", "walls", "floor", "move_count", "due", "blind",
			"next_blind", "toll_percent", "key_taken", "history", "margin_next"]:
		assert_true(state.has(key), key)
	assert_eq(var_to_str(state).find("Object("), -1)
	for move: Dictionary in state["moves"]:
		for key in ["blind_after", "typical", "margin", "toll_percent", "room", "door", "fire_door"]:
			assert_true(move.has(key), key)
	for room: Dictionary in state["rooms"]:
		if String(room["bonus"]) != "":
			assert_eq(String(room["bonus_text"]), DealClause.text_for(String(room["bonus"])))
	run.move_to(state["moves"][0])
	assert_true((run.floor_view_state()["moves"] as Array).is_empty(), "nach dem Zug ist keiner fällig")

## Ein Sucher holt die Karte und geht ins Büro - drei Etagen ohne Fehler.
func test_a_headless_run_over_three_floors() -> void:
	var guard := 0
	while run.floor_index < 3 and guard < 200:
		guard += 1
		var plan := run.floor_plan
		var goal := plan.office if plan.key_taken else plan.key_room
		var best: Dictionary = {}
		var best_steps := 1 << 20
		for move in run.walkable_moves():
			var steps := plan.shortest_moves(String(move["room"]), goal, plan.key_taken)
			if steps >= 0 and steps < best_steps:
				best_steps = steps
				best = move
		assert_false(best.is_empty(), "der Sucher findet immer einen Zug")
		if best.is_empty():
			return
		assert_true(run.move_to(best))
		if run.is_boss_round():
			run.settle_block_deals()
		run.round_points = 100
		run.advance_round()
	assert_eq(run.floor_index, 3, "drei Etagen geschafft")
	assert_eq(run.floor_history.size(), 3)
