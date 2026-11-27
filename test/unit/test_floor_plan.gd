extends GutTest
## Der GRUNDRISS einer Etage (Welle 7 Teil A): Erzeuger, Prüfungen, Themen, Zug-Regeln.

const FLOORS := 1000

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _bosses() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(DealClause.ids_for(DealClause.Tier.BOSS, DealClause.Kind.MALUS).slice(0, 3))
	return ids

func _plan(seed_value: int, floor_index: int = 0) -> FloorPlan:
	return FloorPlan.roll(_rng(seed_value), Callable(), 0.3, _bosses(), floor_index)

## Was an einem Grundriß gegen die PRÜFUNG des Plans verstößt (leer = gültig).
func _problems(plan: FloorPlan) -> Array[String]:
	var found: Array[String] = []
	var count := plan.room_ids().size()
	if count < FloorPlan.MIN_ROOMS or count > FloorPlan.MAX_ROOMS:
		found.append("Räume %d" % count)
	for info in plan.sections:
		var in_section := 0
		for room_id: String in plan.rooms:
			if plan.rooms[room_id]["section"] == info["id"]:
				in_section += 1
		if in_section < FloorPlan.MIN_SECTION_ROOMS or in_section > FloorPlan.MAX_SECTION_ROOMS:
			found.append("Abschnitt %s: %d Räume" % [info["id"], in_section])
	var reach := plan._distances("", false)
	for room_id in plan.room_ids():
		if not reach.has(room_id):
			found.append("%s unerreichbar" % room_id)
	if plan.office == "" or not plan.rooms[plan.office]["is_office"]:
		found.append("kein Büro")
	var keys := 0
	for room_id: String in plan.rooms:
		if plan.rooms[room_id]["has_key"]:
			keys += 1
	if keys != 1 or plan.key_room == plan.office or plan.key_room == "":
		found.append("Schlüsselkarten %d" % keys)
	elif not reach.has(plan.key_room):
		found.append("Karte unerreichbar")
	if plan.key_route_moves() < FloorPlan.MIN_KEY_MOVES:
		found.append("Kartenweg %d" % plan.key_route_moves())
	if plan.key_room != "" and plan.rooms[plan.key_room]["section"] == plan.rooms[plan.office]["section"]:
		found.append("Karte im Büro-Abschnitt")
	var boss := 0
	for entry in plan.doors:
		if entry["kind"] == FloorPlan.DOOR_BOSS:
			boss += 1
	if boss < 2 or boss > 3:
		found.append("Boss-Türen %d" % boss)
	if plan.elevator.is_empty():
		found.append("kein Aufzug")
	return found

## Spielt Aufzug → Schlüsselkarte → Büro mit echten Zügen (Breitensuche je Etappe).
func _walk_to_office(plan: FloorPlan) -> bool:
	for goal in [plan.key_room, plan.office]:
		var guard := 0
		while plan.position != goal and guard < 40:
			guard += 1
			var step := _next_step(plan, goal)
			if step.is_empty() or plan.apply_move(step).is_empty():
				return false
	return plan.position == plan.office

func _next_step(plan: FloorPlan, goal: String) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := 999
	for move in plan.reachable_moves():
		var target: String = move["room"]
		var dist := plan.shortest_moves(target, goal, plan.key_taken or target == plan.key_room)
		if dist >= 0 and dist < best_dist:
			best_dist = dist
			best = move
	return best

func test_thousand_floors_pass_every_check() -> void:
	var broken := 0
	var stats := {"rooms": [], "sections": [], "back": [], "side": [], "lift_moves": [], "walk_moves": [],
		"route": [], "large": [], "medium": [], "small": [], "attempts": []}
	var fallbacks := 0
	var unreached := 0
	var usec := 0
	for i in FLOORS:
		var started := Time.get_ticks_usec()
		var plan := _plan(1000 + i * 7919, i % 6)
		usec += Time.get_ticks_usec() - started
		var problems := _problems(plan)
		if not problems.is_empty():
			broken += 1
			if broken <= 5:
				gut.p("Etage %d: %s" % [i, ", ".join(problems)])
		if plan.fallback:
			fallbacks += 1
		stats["rooms"].append(plan.room_ids().size())
		stats["sections"].append(plan.sections.size())
		stats["back"].append(plan.back_room_count())
		stats["side"].append(plan.side_corridor_count())
		stats["lift_moves"].append(plan.reachable_moves().size())
		stats["route"].append(plan.key_route_moves())
		var large := 0
		var medium := 0
		for room_id in plan.room_ids():
			if int(plan.rooms[room_id]["tier"]) == 3:
				large += 1
			elif int(plan.rooms[room_id]["tier"]) == 2:
				medium += 1
		stats["large"].append(large)
		stats["medium"].append(medium)
		stats["small"].append(plan.room_ids().size() - large - medium)
		stats["attempts"].append(plan.attempts)
		# Zufallslauf: wie viele Züge stehen je Zugwahl zur Wahl?
		var walk := _plan(1000 + i * 7919, i % 6)
		var rng := _rng(i)
		for step in 12:
			var moves := walk.reachable_moves()
			stats["walk_moves"].append(moves.size())
			if moves.is_empty() or walk.position == walk.office:
				break
			walk.apply_move(moves[rng.randi_range(0, moves.size() - 1)])
		if not _walk_to_office(plan):
			unreached += 1
	assert_eq(broken, 0, "jede gewürfelte Etage besteht die Prüfung")
	assert_eq(unreached, 0, "das Büro ist auf jeder Etage mit echten Zügen erreichbar")
	var lines: Array[String] = []
	for key: String in stats:
		lines.append("%s %s" % [key, _stat_line(stats[key])])
	gut.p("STATISTIK über %d Etagen: %s; Rückfall %d (%.1f %%); %.2f ms je Etage" % [FLOORS,
		"; ".join(lines), fallbacks, 100.0 * fallbacks / FLOORS, usec / 1000.0 / FLOORS])

func _stat_line(values: Array) -> String:
	var low := 999
	var high := -999
	var sum := 0.0
	for value: int in values:
		low = mini(low, value)
		high = maxi(high, value)
		sum += value
	return "%d/%.2f/%d" % [low, sum / maxf(1.0, values.size()), high]

func test_same_seed_same_floor() -> void:
	for seed_value in [3, 77, 4242]:
		var a := _plan(seed_value, 2)
		var b := _plan(seed_value, 2)
		assert_eq(a.snapshot(), b.snapshot(), "Seed %d" % seed_value)

func test_fallback_layout_is_valid() -> void:
	var plan := FloorPlan.fallback_layout()
	plan._dress(_rng(1), Callable(), 0.3, _bosses())
	assert_true(plan.fallback)
	assert_eq(_problems(plan), [] as Array[String])

func test_rooms_never_overlap_rooms_or_corridors() -> void:
	for seed_value in range(1, 80):
		var plan := _plan(seed_value, seed_value % 6)
		var rects: Array[Rect2i] = []
		for room_id: String in plan.rooms:
			rects.append(plan.rooms[room_id]["rect"])
		for info in plan.sections:
			for rect: Rect2i in info["rects"]:
				rects.append(rect)
		rects.append(plan.elevator["rect"])
		var overlaps := 0
		for i in rects.size():
			assert_true(rects[i].size.x >= 1 and rects[i].size.y >= 1)
			for j in range(i + 1, rects.size()):
				if rects[i].intersects(rects[j]):
					overlaps += 1
		assert_eq(overlaps, 0, "Seed %d" % seed_value)
		for room_id: String in plan.rooms:
			var rect: Rect2i = plan.rooms[room_id]["rect"]
			assert_true(rect.size.x >= 2 and rect.size.y >= 2, "Mindestmaß 2 × 2")
			assert_true(Rect2i(Vector2i.ZERO, FloorPlan.GRID).encloses(rect))

func test_every_door_sits_on_a_shared_wall() -> void:
	for seed_value in range(1, 80):
		var plan := _plan(seed_value)
		for entry in plan.doors:
			var cell: Vector2i = entry["cell"]
			var side: Vector2i = entry["side"]
			assert_eq(absi(side.x) + absi(side.y), 1)
			assert_eq(plan.cells.get(cell, ""), entry["a"], "%s Seite a" % entry["id"])
			assert_eq(plan.cells.get(cell + side, ""), entry["b"], "%s Seite b" % entry["id"])
			if entry["section"] != "":
				assert_eq(entry["section"], entry["b"])
		var lift: Dictionary = plan.elevator
		assert_eq(plan.cells.get(lift["cell"], ""), FloorPlan.ELEVATOR)
		assert_eq(plan.cells.get(lift["cell"] + lift["side"], ""), lift["section"])

func test_every_room_has_a_door_and_back_rooms_hang_on_links() -> void:
	for seed_value in range(1, 80):
		var plan := _plan(seed_value)
		for room_id: String in plan.rooms:
			var own := plan.doors_of(room_id)
			assert_false(own.is_empty(), "%s ohne Tür" % room_id)
			var corridor := 0
			for entry in own:
				if entry["section"] != "" and entry["a"] == room_id:
					corridor += 1
			assert_eq(corridor, 0 if plan.rooms[room_id]["back"] else 1, room_id)

func test_room_of_clause_covers_every_bonus_clause_once() -> void:
	var bonus: Array[String] = []
	for clause in DealClause.all():
		if clause.kind == DealClause.Kind.BONUS and int(clause.tier) <= DealClause.Tier.THREE:
			bonus.append(clause.id)
	for clause_id in bonus:
		assert_true(FloorPlan.ROOM_OF_CLAUSE.has(clause_id), "%s ohne Raum" % clause_id)
	assert_eq(FloorPlan.ROOM_OF_CLAUSE.size(), bonus.size(), "keine fremden Einträge")
	var themes: Array[String] = []
	for entry: Dictionary in FloorPlan.THEMES:
		themes.append(entry["id"])
	assert_eq(themes.size(), 11)
	for clause_id: String in FloorPlan.ROOM_OF_CLAUSE:
		assert_true(themes.has(FloorPlan.ROOM_OF_CLAUSE[clause_id]), clause_id)
	assert_eq(FloorPlan.ROOM_OF_CLAUSE[DealClause.ANCHOR_CLAUSE], FloorPlan.THEME_BETTING)
	assert_eq(FloorPlan.ROOM_OF_CLAUSE[DealClause.GOLD_VEIN], FloorPlan.THEME_GENERATOR)

func test_theme_at_most_twice_clause_once_and_tier_matches() -> void:
	for seed_value in range(1, 120):
		var plan := _plan(seed_value, seed_value % 6)
		var themes: Dictionary = {}
		var clauses: Dictionary = {}
		for room_id in plan.room_ids():
			var info: Dictionary = plan.rooms[room_id]
			themes[info["theme"]] = int(themes.get(info["theme"], 0)) + 1
			var bonus: String = info["bonus"]
			assert_ne(bonus, "", "jeder Raum trägt einen Bonus")
			clauses[bonus] = int(clauses.get(bonus, 0)) + 1
			assert_eq(FloorPlan.ROOM_OF_CLAUSE.get(bonus, ""), info["theme"])
			assert_eq(int(DealClause.find(bonus).tier), FloorPlan.clause_tier(int(info["tier"])))
			assert_eq(int(info["tier"]), FloorPlan.tier_of_area(int(info["area"])))
		for theme_id: String in themes:
			assert_true(int(themes[theme_id]) <= FloorPlan.THEME_LIMIT, "%s zu oft" % theme_id)
		for clause_id: String in clauses:
			assert_eq(int(clauses[clause_id]), 1, "%s doppelt" % clause_id)
		assert_eq(plan.rooms[plan.office]["bonus"], "")

func test_offerable_is_asked_for_bonus_and_malus() -> void:
	var banned := [DealClause.ADVANCE_PAYMENT, DealClause.SEIZURE, DealClause.BLANK_CHEQUE]
	var offerable := func(clause_id: String) -> bool: return not banned.has(clause_id)
	for seed_value in range(1, 60):
		var rng := _rng(seed_value)
		var plan := FloorPlan.roll(rng, offerable, 0.3, _bosses())
		for room_id in plan.room_ids():
			assert_false(banned.has(plan.rooms[room_id]["bonus"]))
		for entry in plan.doors:
			plan.scout_door(entry, rng, offerable)
			assert_false(banned.has(entry["malus"]))

## Prüft jeden Zug eines Standorts gegen die drei Regeln und daß keiner fehlt.
func _check_moves(plan: FloorPlan, standpoint: String) -> void:
	var own := plan.own_sections(standpoint)
	var moves := plan.moves_from(standpoint, plan.key_taken)
	var by_door: Dictionary = {}
	for move in moves:
		var entry := plan.door(move["door"])
		var target: String = move["room"]
		assert_ne(target, standpoint)
		assert_true(plan.rooms.has(target), "nie zurück in den Aufzug")
		assert_false(by_door.has(move["door"]), "eine Tür je Zug")
		by_door[move["door"]] = move
		if String(move["fire_door"]) != "":
			var fire := plan.door(move["fire_door"])
			assert_eq(fire["kind"], FloorPlan.DOOR_FIRE)
			assert_true(own.has(move["section_from"]))
			assert_false(own.has(move["section_to"]))
			assert_true([fire["a"], fire["b"]].has(move["section_from"]))
			assert_true([fire["a"], fire["b"]].has(move["section_to"]))
			assert_eq(entry["section"], move["section_to"])
		elif entry["section"] != "":
			assert_true(own.has(entry["section"]), "Flurtür am eigenen Abschnitt")
		else:
			assert_true(entry["a"] == standpoint or entry["b"] == standpoint, "Verbindungstür am Standraum")
		if target == plan.office:
			assert_true(plan.key_taken, "Büro nur mit Karte")
	if standpoint != "" and plan.rooms[standpoint]["back"]:
		for move in moves:
			assert_eq(move["fire_door"], "")
			assert_eq(plan.door(move["door"])["section"], "", "hinterer Raum nur über Verbindungstüren")
	# Vollständig: jede Tür, die eine Regel erlaubt, liegt als Zug vor.
	for entry in plan.doors:
		if entry["kind"] == FloorPlan.DOOR_FIRE:
			continue
		var target: String = entry["a"]
		var allowed := false
		if entry["section"] != "":
			if own.has(entry["section"]):
				allowed = true
			for sid in own:
				if plan.section(sid)["neighbors"].has(entry["section"]):
					allowed = true
		elif entry["a"] == standpoint or entry["b"] == standpoint:
			allowed = true
			target = entry["b"] if entry["a"] == standpoint else entry["a"]
		if target == standpoint:
			allowed = false
		if (target == plan.office or entry["kind"] == FloorPlan.DOOR_BOSS) and not plan.key_taken:
			allowed = false
		assert_eq(by_door.has(entry["id"]), allowed, "%s von %s" % [entry["id"], standpoint])

func test_reachability_follows_the_three_rules() -> void:
	for seed_value in range(1, 40):
		var plan := _plan(seed_value, seed_value % 6)
		_check_moves(plan, "")
		for room_id: String in plan.rooms:
			_check_moves(plan, room_id)
		plan.key_taken = true
		for room_id: String in plan.rooms:
			_check_moves(plan, room_id)

func test_elevator_reaches_its_section_and_one_fire_door_beyond() -> void:
	var plan := _plan(11)
	var lift: String = plan.elevator["section"]
	var with_fire := 0
	for move in plan.reachable_moves():
		if move["fire_door"] == "":
			assert_eq(plan.door(move["door"])["section"], lift)
		else:
			with_fire += 1
			assert_true(plan.section(lift)["neighbors"].has(move["section_to"]))
	assert_true(with_fire > 0, "der Nachbar-Abschnitt liegt hinter einer Brandschutztür")
	assert_eq(plan.position, "")

func test_office_only_with_the_key() -> void:
	for seed_value in range(1, 40):
		var plan := _plan(seed_value)
		for room_id in plan.room_ids():
			for move in plan.moves_from(room_id, false):
				assert_ne(move["room"], plan.office)
		var opens := 0
		for room_id in plan.room_ids():
			for move in plan.moves_from(room_id, true):
				if move["room"] == plan.office:
					opens += 1
					assert_eq(plan.door(move["door"])["kind"], FloorPlan.DOOR_BOSS)
		assert_true(opens > 0)

func test_apply_move_books_bonus_once_malus_once_and_tolls_every_time() -> void:
	var plan := _plan(5)
	var rng := _rng(9)
	plan.scout(rng, Callable())
	var fire_move: Dictionary = {}
	for move in plan.reachable_moves():
		if move["fire_door"] != "" and not plan.door(move["door"])["free"]:
			fire_move = move
			break
	assert_false(fire_move.is_empty(), "vom Aufzug liegt ein Zug hinter einer Brandschutztür")
	var target: String = fire_move["room"]
	var entry := plan.door(fire_move["door"])
	var first := plan.apply_move(fire_move)
	assert_eq(first["bonus"], plan.rooms[target]["bonus"])
	assert_eq(first["malus"], entry["malus"])
	assert_ne(first["malus"], "")
	assert_eq(first["tolls"], 1)
	assert_eq(plan.position, target)
	assert_true(plan.rooms[target]["visited"])
	assert_true(entry["passed"])
	assert_eq(plan.trail.size(), 1)
	# Hinaus in einen Raum am eigenen Abschnitt, dann zurück durch dieselbe Tür.
	var away: Dictionary = {}
	for move in plan.reachable_moves():
		if move["fire_door"] == "" and plan.door(move["door"])["section"] != "":
			away = move
			break
	assert_false(away.is_empty())
	plan.scout(rng, Callable())
	plan.apply_move(away)
	var back: Dictionary = {}
	for move in plan.reachable_moves():
		if move["door"] == fire_move["door"]:
			back = move
	assert_false(back.is_empty(), "derselbe Raum ist wieder gangbar")
	var again := plan.apply_move(back)
	assert_eq(again["bonus"], "", "kein Bonus beim zweiten Besuch")
	assert_eq(again["malus"], "", "die Tür ist ausgebrannt")
	assert_eq(again["tolls"], 1 if back["fire_door"] != "" else 0, "jede Durchquerung zahlt Maut")

func test_toll_on_every_crossing_of_a_fire_door() -> void:
	var plan := _plan(5)
	var tolls := 0
	var crossings := 0
	var rng := _rng(3)
	for step in 30:
		var moves := plan.reachable_moves()
		var fire: Array[Dictionary] = []
		for move in moves:
			if move["fire_door"] != "" and move["room"] != plan.office:
				fire.append(move)
		if fire.is_empty():
			break
		var result := plan.apply_move(fire[rng.randi_range(0, fire.size() - 1)])
		crossings += 1
		tolls += int(result["tolls"])
	assert_true(crossings >= 2)
	assert_eq(tolls, crossings)

func test_key_is_taken_and_opens_the_office() -> void:
	var plan := _plan(21)
	assert_false(plan.key_taken)
	assert_true(_walk_to_office(plan))
	assert_true(plan.key_taken)
	var took := 0
	for step in plan.trail:
		if step["to"] == plan.key_room:
			took += 1
	assert_true(took >= 1)
	assert_eq(plan.position, plan.office)
	assert_true(plan.trail.size() >= FloorPlan.MIN_KEY_MOVES)

func test_apply_move_refuses_unreachable_moves() -> void:
	var plan := _plan(8)
	var boss: Dictionary = {}
	for entry in plan.doors:
		if entry["kind"] == FloorPlan.DOOR_BOSS:
			boss = entry
	assert_eq(plan.apply_move({"door": boss["id"], "fire_door": ""}), {})
	assert_eq(plan.position, "")

func test_cheapest_move_prefers_passed_then_free_then_low_tier_then_no_fire() -> void:
	var plan := _plan(5)
	var a := {"room": "x", "door": plan.doors[0]["id"], "fire_door": ""}
	for entry in plan.doors:
		if entry["kind"] == FloorPlan.DOOR_ROOM:
			entry["passed"] = false
			entry["tier"] = 2
			entry["free"] = false
			a["door"] = entry["id"]
			break
	var base := plan.move_rank(a)
	var with_fire := a.duplicate()
	with_fire["fire_door"] = "tuer0"
	assert_true(plan.move_rank(with_fire) > base)
	var entry := plan.door(a["door"])
	entry["tier"] = 1
	assert_true(plan.move_rank(a) < base)
	entry["tier"] = FloorPlan.TIER_FREE
	var free_rank := plan.move_rank(a)
	entry["passed"] = true
	assert_true(plan.move_rank(a) < free_rank)
	assert_true(plan.move_rank(with_fire) > plan.move_rank(a))
	for room_id in plan.reachable_rooms():
		var best := plan.cheapest_move(room_id)
		for move in plan.reachable_moves():
			if move["room"] == room_id:
				assert_true(plan.move_rank(best) <= plan.move_rank(move))

func test_scout_rolls_malus_only_for_reachable_doors() -> void:
	var plan := _plan(13)
	plan.scout(_rng(1), Callable())
	var reachable: Dictionary = {}
	for move in plan.reachable_moves():
		reachable[move["door"]] = true
	for entry in plan.doors:
		if entry["kind"] == FloorPlan.DOOR_ROOM or entry["kind"] == FloorPlan.DOOR_LINK:
			assert_eq(bool(entry["scouted"]), reachable.has(entry["id"]), entry["id"])
			if reachable.has(entry["id"]) and not entry["free"]:
				assert_ne(entry["malus"], "")
				var tags := DealClause.tags_of(plan.rooms[entry["a"]]["bonus"])
				for tag in DealClause.tags_of(entry["malus"]):
					assert_false(tags.has(tag), "kein Tag mit dem Bonus des Zielraums")
		if entry["kind"] == FloorPlan.DOOR_FIRE:
			assert_eq(entry["malus"], "", "Brandschutztüren tragen keine Klausel")
	var ids := plan.floor_clause_ids()
	for clause_id in ids:
		assert_eq(ids.count(clause_id), 1)

func test_view_state_carries_plain_values() -> void:
	var plan := _plan(17)
	plan.scout(_rng(2), Callable())
	var state := plan.view_state()
	for key in ["grid", "outline", "walls", "corridors", "rooms", "doors", "elevator", "office",
			"key_room", "key_taken", "position", "moves", "trail"]:
		assert_true(state.has(key), key)
	assert_true((state["walls"] as Array).size() > 10)
	var outer := 0
	for wall: Dictionary in state["walls"]:
		if wall["outer"]:
			outer += 1
	assert_true(outer > 4)
	assert_eq((state["rooms"] as Array).size(), plan.rooms.size())
	var hidden := 0
	for entry: Dictionary in state["doors"]:
		if not entry["scouted"]:
			assert_eq(entry["malus"], "")
			hidden += 1
	assert_true(hidden > 0, "unerkundete Türen verraten ihren Malus nicht")
	assert_eq(var_to_str(state).find("Object("), -1, "keine Objekte in der Ansicht")
	assert_eq(var_to_str(plan.snapshot()).find("Object("), -1)
