extends GutTest
## Die ETAGEN-KARTE: Grundrisse, Würfeln der Klauseln, Zug, Blind-Schritt, Sperren.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

## Eine gewürfelte Etage, deren Türen alle erkundet sind.
func _scouted_floor(template: int, seed_value: int) -> FloorMap:
	var rng := _rng(seed_value)
	var bosses: Array[String] = []
	bosses.assign(DealClause.ids_for(DealClause.Tier.BOSS, DealClause.Kind.MALUS).slice(0, 3))
	var map := FloorMap.roll(rng, Callable(), 0.3, bosses, template)
	for room_id: String in map.rooms:
		map.scout_from(room_id, rng, Callable())
	return map

## Leert die Etage des Laufs: ein Zug hebt dann nur noch den Blind.
func _quiet_floor() -> void:
	for room_id: String in run.floor_map.rooms:
		run.floor_map.rooms[room_id]["bonus"] = ""
	for entry in run.floor_map.doors:
		entry["malus"] = ""
		entry["boss"] = ""
		entry["free"] = true

## Erster Zug, der nicht ins Büro führt.
func _room_door() -> String:
	var due := run.move_due
	run.move_due = true
	var offers := run.move_offers()
	run.move_due = due
	for card in offers:
		var entry := run.floor_map.door(String(card[GameRun.CARD_DOOR]))
		if not run.floor_map.is_office_door(entry):
			return String(entry["id"])
	return ""

func _move(door_id: String) -> bool:
	run.move_due = true
	return run.move_through(door_id)

# --- Grundrisse ----------------------------------------------------------------

func test_every_template_is_connected_and_four_moves_deep() -> void:
	for t in FloorMap.TEMPLATES.size():
		var map := FloorMap.build(t)
		assert_eq(map.room_ids().size(), FloorMap.ROOM_COUNT, "Vorlage %d: acht Räume" % t)
		assert_eq(map.shortest_moves(map.entrance, map.office), FloorMap.SHORTEST_MOVES,
			"Vorlage %d: vier Züge bis ins Büro" % t)
		for room_id: String in map.rooms:
			assert_gte(map.shortest_moves(map.entrance, room_id), 0, "Vorlage %d: %s erreichbar" % [t, room_id])
		assert_eq(map.doors_from(map.office).size(), FloorMap.BOSS_DOORS, "Vorlage %d: drei Büro-Türen" % t)
		var dead := 0
		for room_id in map.room_ids():
			if map.is_dead_end(room_id):
				dead += 1
		assert_gt(dead, 0, "Vorlage %d hat eine Sackgasse" % t)

func test_rooms_carry_three_three_two_tiers_and_dead_ends_the_highest() -> void:
	for t in FloorMap.TEMPLATES.size():
		var map := _scouted_floor(t, 11 + t)
		var counts := {}
		for room_id in map.room_ids():
			var tier := int(map.rooms[room_id]["tier"])
			counts[tier] = int(counts.get(tier, 0)) + 1
			if map.is_dead_end(room_id):
				assert_eq(tier, DealClause.Tier.THREE, "Sackgassen zuerst Stufe 3")
		assert_eq(int(counts.get(DealClause.Tier.ONE, 0)), 3)
		assert_eq(int(counts.get(DealClause.Tier.TWO, 0)), 3)
		assert_eq(int(counts.get(DealClause.Tier.THREE, 0)), 2)

func test_every_clause_lies_at_most_once_per_floor() -> void:
	for t in FloorMap.TEMPLATES.size():
		for s in 8:
			var ids := _scouted_floor(t, 100 * t + s).floor_clause_ids()
			var seen: Array[String] = []
			for clause_id in ids:
				assert_false(seen.has(clause_id), "%s liegt doppelt" % clause_id)
				seen.append(clause_id)

func test_a_door_never_shares_a_tag_with_either_room() -> void:
	for t in FloorMap.TEMPLATES.size():
		for s in 8:
			var map := _scouted_floor(t, 7 + 100 * t + s)
			for entry in map.doors:
				var malus := String(entry["malus"])
				if malus == "":
					continue
				for side in ["a", "b"]:
					var bonus := String(map.rooms[entry[side]]["bonus"])
					for tag in DealClause.tags_of(bonus):
						assert_false(DealClause.tags_of(malus).has(tag),
							"%s teilt %s mit %s" % [malus, tag, bonus])

func test_office_doors_carry_boss_conditions_and_room_names_are_unique() -> void:
	var map := _scouted_floor(0, 5)
	for entry in map.doors_from(map.office):
		assert_eq(DealClause.find(String(entry["boss"])).tier, DealClause.Tier.BOSS)
		assert_true(bool(entry["scouted"]), "Boss-Konditionen sind ab Beginn sichtbar")
	var names: Array[String] = []
	for room_id in map.room_ids():
		var room_name := String(map.rooms[room_id]["name"])
		assert_ne(room_name, "")
		assert_false(names.has(room_name), "%s steht doppelt" % room_name)
		names.append(room_name)

func test_a_door_malus_falls_only_when_scouted() -> void:
	var map := FloorMap.roll(_rng(3), Callable(), 0.0, [] as Array[String], 0)
	for entry in map.doors:
		if not map.is_office_door(entry):
			assert_false(bool(entry["scouted"]))
			assert_eq(String(entry["malus"]), "", "erst das Erkunden würfelt den Malus")

func test_the_ad_drum_frees_more_doors() -> void:
	var plain := 0
	var drummed := 0
	for s in 40:
		for entry in FloorMap.roll(_rng(s), Callable(), 0.0, [] as Array[String], 1).doors:
			plain += 1 if bool(entry["free"]) else 0
		for entry in FloorMap.roll(_rng(s), Callable(), 1.0, [] as Array[String], 1).doors:
			drummed += 1 if bool(entry["free"]) else 0
	assert_eq(plain, 0, "ohne Chance keine freie Tür")
	assert_gt(drummed, 40, "bei voller Chance fast immer drei")

# --- Der Zug -------------------------------------------------------------------

func test_round_one_stands_at_the_entrance_without_a_clause() -> void:
	assert_eq(run.floor_map.position, run.floor_map.entrance)
	assert_false(run.move_due, "Runde 1 hat keinen Zug")
	assert_true(run.move_offers().is_empty())
	assert_true(run.active_deals.is_empty())
	run.advance_round()
	assert_false(run.move_offers().is_empty(), "ab Runde 2 steht ein Zug an")

func test_the_entrance_doors_are_scouted_from_the_start() -> void:
	for entry in run.floor_map.doors_from(run.floor_map.entrance):
		assert_true(bool(entry["scouted"]))

func test_a_move_signs_the_room_bonus_and_the_door_malus() -> void:
	run.advance_round()
	var door_id := _room_door()
	var entry := run.floor_map.door(door_id)
	var target := run.floor_map.room(run.floor_map.other_side(entry, run.floor_map.position))
	var expected: Array[String] = []
	if String(target["bonus"]) != "":
		expected.append(String(target["bonus"]))
	if String(entry["malus"]) != "":
		expected.append(String(entry["malus"]))
	assert_true(run.move_through(door_id))
	var signed: Array[String] = []
	for deal in run.active_deals:
		signed.append(String(deal["id"]))
	assert_eq(signed, expected)
	assert_eq(run.floor_map.position, String(target["id"]))
	assert_eq(int(entry["state"]), FloorMap.DoorState.PASSED)
	for next in run.floor_map.doors_from(run.floor_map.position):
		assert_true(bool(next["scouted"]), "die Türen des neuen Raums sind erkundet")

func test_the_way_back_signs_nothing() -> void:
	run.advance_round()
	var door_id := _room_door()
	run.move_through(door_id)
	var deals := run.active_deals.size()
	assert_true(_move(door_id), "zurück durch dieselbe Tür")
	assert_eq(run.active_deals.size(), deals, "ausgebrannte Tür, leerer Raum")
	assert_eq(run.floor_map.position, run.floor_map.entrance)
	assert_eq(run.floor_moves, 2, "aber der Zug zählt")

func test_a_move_needs_a_due_round_and_a_neighbour() -> void:
	assert_false(run.move_through(_room_door()), "Runde 1 zieht nicht")
	run.move_due = true
	var far := ""
	for entry in run.floor_map.doors:
		if entry["a"] != run.floor_map.position and entry["b"] != run.floor_map.position:
			far = String(entry["id"])
	assert_false(run.move_through(far), "nur eine Tür des Standraums")
	assert_true(run.move_due, "nichts gebucht")

func test_the_office_makes_the_boss_round() -> void:
	_quiet_floor()
	var path := _path_to_office()
	for i in path.size():
		assert_false(run.is_boss_round())
		assert_true(_move(path[i]))
	assert_true(run.is_boss_round())

## Die Türen des kürzesten Wegs vom Standraum ins Büro.
func _path_to_office() -> Array[String]:
	var map := run.floor_map
	var path: Array[String] = []
	var here := map.position
	while here != map.office:
		for entry in map.doors_from(here):
			var next := map.other_side(entry, here)
			if map.shortest_moves(next, map.office) == map.shortest_moves(here, map.office) - 1:
				path.append(String(entry["id"]))
				here = next
				break
	return path

# --- Der Blind -----------------------------------------------------------------

func test_each_move_steps_ten_twelve_fourteen_percent() -> void:
	_quiet_floor()
	var door_id := _room_door()
	assert_eq(run.next_blind(), 165, "die Vorschau ist die Buchung")
	_move(door_id)
	assert_almost_eq(run.blind_value, 165.0, 0.001)
	assert_eq(run.next_blind(), GameRun.floor_to_blind(165.0 * 1.12))
	_move(door_id)
	assert_almost_eq(run.blind_value, 184.8, 0.001)
	_move(door_id)
	assert_almost_eq(run.blind_value, 184.8 * 1.14, 0.001)

func test_the_move_counter_resets_on_the_next_floor() -> void:
	_quiet_floor()
	var door_id := _room_door()
	_move(door_id)
	_move(door_id)
	run.settle_block_deals()
	assert_eq(run.floor_index, 1)
	assert_eq(run.floor_moves, 0, "der Aufzug setzt den Zähler zurück")
	assert_eq(run.floor_map.position, run.floor_map.entrance)
	assert_almost_eq(run.blind_growth(), 0.15, 0.0001, "Etage 2 beginnt bei 15 %")

# --- Fumbles sperren Türen -----------------------------------------------------

func test_a_fumble_locks_a_door_but_never_the_last_way() -> void:
	for i in 30:
		run.note_fumble(false)
		assert_true(run.floor_map.reaches_office(run.floor_map.position), "das Büro bleibt erreichbar")
	var locked := 0
	for entry in run.floor_map.doors:
		if int(entry["state"]) == FloorMap.DoorState.LOCKED:
			locked += 1
	assert_gt(locked, 0, "Fumbles haben gesperrt")
	assert_true(run.floor_map.lock_candidates().is_empty(), "am Ende ist nichts mehr zu sperren")

func test_a_fumble_names_the_locked_door() -> void:
	run.note_fumble(false)
	assert_ne(run.last_locked_door, "")
	assert_true(run.locked_door_note().begins_with("Tür gesperrt: "))
	var entry := run.floor_map.door(run.last_locked_door)
	assert_false(run.floor_map.passable(entry))

func test_a_locked_door_is_no_move() -> void:
	run.advance_round()
	var door_id := _room_door()
	run.floor_map.door(door_id)["state"] = FloorMap.DoorState.LOCKED
	for card in run.move_offers():
		assert_ne(String(card[GameRun.CARD_DOOR]), door_id)
	assert_false(run.move_through(door_id))

# --- Laufzeiten ----------------------------------------------------------------

func test_the_regular_customer_lives_until_the_settlement() -> void:
	run.sign_clauses([DealClause.REGULAR_CUSTOMER] as Array[String])
	var discounted := run.shop_price_factor()
	assert_lt(discounted, 1.0)
	for i in 4:
		run.advance_round()
	assert_almost_eq(run.shop_price_factor(), discounted, 0.0001, "noch auf der Etage")
	run.settle_block_deals()
	assert_almost_eq(run.shop_price_factor(), 1.0, 0.0001, "die Abrechnung beendet ihn")
