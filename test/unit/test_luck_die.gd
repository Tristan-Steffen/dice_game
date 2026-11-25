extends GutTest
## Der GLÜCKSWÜRFEL (core/): Schwellen, Deckel 6, Stapel-Rücknahme, Wurf, Roundtrip und die
## Buchung in GameRun.

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _sum_extra(die: LuckDie) -> int:
	return die.total_pips() - LuckDie.FACES * LuckDie.BASE

func test_thresholds_are_triangular() -> void:
	var expected := {0: 0, 1: 1, 2: 1, 3: 2, 5: 2, 6: 3, 9: 3, 10: 4, 15: 5, 21: 6}
	for luck: int in expected:
		assert_eq(LuckDie.pips_for(luck), expected[luck], "Glück %d" % luck)
	assert_eq(LuckDie.next_threshold(0), 1)
	assert_eq(LuckDie.next_threshold(4), 6)
	assert_eq(LuckDie.next_threshold(6), 10)

func test_the_cap_holds_at_thirty_extra_pips() -> void:
	assert_eq(LuckDie.MAX_EXTRA, 30)
	assert_eq(LuckDie.pips_for(100000), 30)
	assert_eq(LuckDie.next_threshold(100000), -1, "alle Seiten voll")
	var die := LuckDie.new()
	die.sync(100000, _rng(1))
	assert_eq(die.faces, [6, 6, 6, 6, 6, 6] as Array[int])

func test_no_face_ever_passes_six() -> void:
	for seed_value in 30:
		var die := LuckDie.new()
		for luck in range(0, 500, 7):
			die.sync(luck, _rng(seed_value * 1000 + luck))
			for value in die.faces:
				assert_between(value, 1, LuckDie.CAP)
			assert_eq(_sum_extra(die), LuckDie.pips_for(luck))

func test_a_gain_reports_its_face_and_value() -> void:
	var die := LuckDie.new()
	var changes := die.sync(3, _rng(2))
	assert_eq(changes.size(), 2)
	var replay: Array[int] = [1, 1, 1, 1, 1, 1]
	for change: Dictionary in changes:
		assert_eq(int(change["delta"]), 1)
		replay[int(change["face"])] += 1
		assert_eq(int(change["value_after"]), replay[int(change["face"])], "der Stand nach dem Schlag")
	assert_eq(replay, die.faces)
	assert_true(die.sync(3, _rng(3)).is_empty(), "gleiches Glück, keine Änderung")

func test_placement_is_random() -> void:
	var seen := {}
	for seed_value in 40:
		var die := LuckDie.new()
		die.sync(1, _rng(seed_value))
		seen[die.gained[0]] = true
	assert_gt(seen.size(), 3, "das erste Auge fällt auf verschiedene Seiten")

func test_a_loss_takes_back_the_last_gained_pip() -> void:
	var die := LuckDie.new()
	die.sync(10, _rng(5))
	var stack := die.gained.duplicate()
	var before := die.faces.duplicate()
	var changes := die.sync(6, _rng(6))
	assert_eq(changes.size(), 1)
	var last: int = stack[stack.size() - 1]
	assert_eq(int(changes[0]["face"]), last, "das zuletzt gewonnene geht")
	assert_eq(int(changes[0]["delta"]), -1)
	assert_eq(die.faces[last], before[last] - 1)
	assert_eq(die.gained, stack.slice(0, stack.size() - 1), "der Stapel schrumpft von oben")
	die.sync(0, _rng(7))
	assert_eq(die.faces, [1, 1, 1, 1, 1, 1] as Array[int], "ohne Glück der Grundwürfel")

func test_the_roll_only_hits_existing_faces() -> void:
	var die := LuckDie.new()
	die.sync(21, _rng(8))
	var hits := {}
	for seed_value in 300:
		var face := die.roll(_rng(seed_value))
		assert_between(face, 0, LuckDie.FACES - 1)
		hits[face] = true
		assert_between(die.value(face), 1, LuckDie.CAP)
	assert_eq(hits.size(), LuckDie.FACES, "jede Seite kommt vor")

func test_round_trip() -> void:
	var die := LuckDie.new()
	die.sync(15, _rng(9))
	var back := LuckDie.from_dict(die.to_dict())
	assert_eq(back.faces, die.faces)
	assert_eq(back.gained, die.gained)
	back.sync(10, _rng(10))
	die.sync(10, _rng(10))
	assert_eq(back.faces, die.faces, "der Stapel reist mit")

func test_a_broken_save_falls_back_to_the_base_die() -> void:
	var broken := LuckDie.from_dict({"faces": [2, 1, 1, 1, 1, 1], "gained": [3]})
	assert_eq(broken.faces, [1, 1, 1, 1, 1, 1] as Array[int])
	assert_true(broken.gained.is_empty())
	assert_eq(LuckDie.from_dict({}).faces, [1, 1, 1, 1, 1, 1] as Array[int])

# --- In GameRun -------------------------------------------------------------------

func test_game_run_books_every_luck_change() -> void:
	var run := GameRun.new_run()
	var heard: Array = []
	run.luck_die_changed.connect(func(changes: Array) -> void: heard.append(changes.size()))
	run.add_luck(3)
	assert_eq(_sum_extra(run.luck_die), 2)
	assert_eq(heard, [2])
	run.add_luck(-2)
	assert_eq(_sum_extra(run.luck_die), 1)
	assert_eq(heard, [2, 1])
	run.advance_round()
	assert_eq(_sum_extra(run.luck_die), LuckDie.pips_for(run.luck))

func test_the_lucky_mushroom_feeds_the_die() -> void:
	var run := GameRun.new_run()
	run.money = 999
	run.purchase_charm(Charm.lucky_mushroom(), 0)
	assert_eq(_sum_extra(run.luck_die), LuckDie.pips_for(GameRun.LUCKY_MUSHROOM_LUCK))
	run.sell_charm(0)
	assert_eq(_sum_extra(run.luck_die), 0, "verkauft, und das Auge geht")

func test_the_hint_names_the_next_pip() -> void:
	var run := GameRun.new_run()
	run.luck = 4
	assert_eq(run.luck_die_hint(), "Glückswürfel · Glück 4 · nächstes Auge bei 6")
	assert_string_contains(run.luck_hint(), "Ab Glück 6 bekommt der Glückswürfel ein Auge")

# --- Die GLÜCKS-STATION -------------------------------------------------------------

func test_prev_threshold_is_the_last_gained_pip() -> void:
	assert_eq(LuckDie.prev_threshold(0), 0)
	assert_eq(LuckDie.prev_threshold(2), 1)
	assert_eq(LuckDie.prev_threshold(3), 3)
	assert_eq(LuckDie.prev_threshold(9), 6)
	assert_eq(LuckDie.next_threshold(9), 10)

func test_expected_is_the_pip_mean() -> void:
	var die := LuckDie.new()
	assert_almost_eq(die.expected(), 1.0, 0.0001)
	die.faces.assign([1, 2, 3, 4, 5, 6])
	assert_almost_eq(die.expected(), 3.5, 0.0001)

func test_the_net_holds_every_face_once_with_up_in_the_middle() -> void:
	var seen: Array[int] = []
	for row: Array in LuckDie.NET_LAYOUT:
		for face: int in row:
			if face >= 0:
				seen.append(face)
	seen.sort()
	assert_eq(seen, [0, 1, 2, 3, 4, 5] as Array[int])
	assert_eq(LuckDie.net_cell(0), Vector2i(1, 1), "die Ruhe-Seite liegt in der Mitte")
	assert_eq(LuckDie.net_cell(5), Vector2i(3, 1), "die Gegenseite außen")

func test_body_and_net_share_one_pip_source() -> void:
	for value in range(1, 7):
		assert_eq(LuckDie.pip_layout(value).size(), value)
		assert_eq(LuckDieView.pip_layout(value), LuckDie.pip_layout(value))

func test_station_state_follows_the_run() -> void:
	var run := GameRun.new_run()
	run.luck = 8
	run.sync_luck_die()
	var state := run.luck_station_state()
	assert_eq(int(state["luck"]), 8)
	assert_eq(int(state["prev"]), 6)
	assert_eq(int(state["next"]), 10)
	assert_almost_eq(float(state["expected"]), float(6 + 3) / 6.0, 0.0001)
	assert_eq(int(state["free_bonus"]), 0)
	assert_eq(int(state["keeps"]), 0)
	run.module_keeps = 2
	assert_eq(int(run.luck_station_state()["keeps"]), 2)

func test_station_state_names_free_hand_for_the_whole_round() -> void:
	var run := GameRun.new_run()
	var ids: Array[String] = [DealClause.FREE_HAND]
	run.sign_clauses(ids)
	assert_eq(int(run.luck_station_state()["free_bonus"]), 1)
	run.packs_opened_this_round = 1
	assert_eq(int(run.luck_station_state()["free_bonus"]), 1, "jedes Paket der Runde")
