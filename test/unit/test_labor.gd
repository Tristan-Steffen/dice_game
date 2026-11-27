extends GutTest
## Das LABOR (core/): Öffnen, Preis, Wartezeit, die vier Stationen von Einsatz bis Abholung.

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

## Ein Lauf mit offenem Labor an dieser Station; der Glückswürfel zeigt überall value.
func _run(station: String, value := 3) -> GameRun:
	var run := GameRun.new_run()
	run.stress_tests_passed = 1
	run.open_labor(_rng(1))
	run.labor_station = station
	run.luck_die.faces = [value, value, value, value, value, value] as Array[int]
	run.energy = 5
	return run

func _soul_run() -> GameRun:
	var run := _run(Labor.SEELE)
	run.owned_pool[0].essence_id = Essence.SCAR
	return run

# --- Regeln -------------------------------------------------------------------------

func test_wait_is_six_minus_pips_and_six_is_instant() -> void:
	for value in range(1, 7):
		assert_eq(Labor.wait_for(value), 6 - value)
	assert_eq(Labor.make(Labor.KARTEN, {}, 0, 6).done, true, "eine 6 ist sofort fertig")
	assert_eq(Labor.make(Labor.KARTEN, {}, 0, 2).rounds_left, 4)

func test_next_station_never_repeats() -> void:
	var rng := _rng(7)
	for station: String in Labor.STATIONS:
		for i in 40:
			var next := Labor.next_station(station, rng)
			assert_ne(next, station)
			assert_true(Labor.STATIONS.has(next))

func test_dict_roundtrip() -> void:
	var job := Labor.make(Labor.MODUL, {"part": {"key": "x", "slot": 1}}, 2, 4)
	var back := Labor.from_dict(job.to_dict())
	assert_eq(back.station, Labor.MODUL)
	assert_eq(back.die_face, 2)
	assert_eq(back.die_value, 4)
	assert_eq(back.rounds_left, 2)
	assert_false(back.done)
	assert_eq(back.inputs, job.inputs)

# --- Öffnen und Preis ---------------------------------------------------------------

func test_debug_opens_the_labor_at_once() -> void:
	var run := GameRun.new_run()
	run.debug_open_labor(_rng(1))
	assert_true(run.labor_open(), "ohne Boss-Runde sofort offen")
	var first := run.labor_station
	run.debug_open_labor(_rng(2))
	assert_eq(run.labor_station, first, "ein zweiter Druck ändert nichts")

func test_opens_with_first_boss_round() -> void:
	var run := GameRun.new_run()
	assert_false(run.labor_open())
	assert_eq(run.labor_state()["open"], false)
	run.grant_stress_reward()
	assert_true(run.labor_open())
	assert_true(Labor.STATIONS.has(run.labor_station))
	var first := run.labor_station
	run.grant_stress_reward()
	assert_eq(run.labor_station, first, "eine Boss-Runde wechselt die Station nicht")

func test_new_run_starts_closed() -> void:
	var run := GameRun.new_run()
	assert_eq(run.labor_station, "")
	assert_null(run.labor_job)
	assert_eq(run.labor_uses, 0)

func test_price_ladder_counts_started_jobs() -> void:
	var run := _run(Labor.KARTEN, 6)
	run.energy = 5
	var expected_prices := [0, 1, 2]
	for price: int in expected_prices:
		assert_eq(run.labor_price(), price)
		run.labor_station = Labor.KARTEN
		var card := run.grant_pack(Pack.number_pack(_rng(price)))
		var before := run.energy
		assert_true(run.start_labor_job({"packs": [card.pack_uid]}, _rng(price)))
		assert_eq(run.energy, before - price)
		assert_false(run.collect_labor(_rng(price)).is_empty())
	assert_eq(run.labor_uses, 3)

func test_unaffordable_start_books_nothing() -> void:
	var run := _run(Labor.KARTEN)
	run.labor_uses = 4
	run.energy = 3
	var card := run.grant_pack(Pack.number_pack(_rng(1)))
	assert_false(run.can_start_labor({"packs": [card.pack_uid]}))
	assert_false(run.labor_state()["affordable"])
	assert_false(run.start_labor_job({"packs": [card.pack_uid]}))
	assert_null(run.labor_job)
	assert_eq(run.energy, 3)
	assert_eq(run.owned_packs.size(), 1)

func test_one_job_at_a_time() -> void:
	var run := _run(Labor.KARTEN, 2)
	var a := run.grant_pack(Pack.number_pack(_rng(1)))
	var b := run.grant_pack(Pack.number_pack(_rng(2)))
	assert_true(run.start_labor_job({"packs": [a.pack_uid]}))
	assert_false(run.can_start_labor({"packs": [b.pack_uid]}))

# --- Wartezeit ------------------------------------------------------------------------

func test_countdown_per_round() -> void:
	var run := _run(Labor.KARTEN, 3)
	var card := run.grant_pack(Pack.number_pack(_rng(1)))
	assert_true(run.start_labor_job({"packs": [card.pack_uid]}))
	var state := run.labor_state()
	assert_eq(state["phase"], Labor.PHASE_RUNNING)
	assert_eq(state["die_value"], 3)
	assert_eq(state["rounds_left"], 3)
	assert_false(run.labor_collectable())
	for left in [2, 1]:
		run.advance_round()
		assert_eq(run.labor_job.rounds_left, left)
		assert_false(run.labor_collectable())
	run.advance_round()
	assert_true(run.labor_job.done)
	assert_eq(run.labor_state()["phase"], Labor.PHASE_DONE)
	assert_true(run.labor_collectable())
	run.advance_round()
	assert_eq(run.labor_job.rounds_left, 0, "fertig wartet, bis es abgeholt ist")

func test_six_is_done_at_once() -> void:
	var run := _run(Labor.KARTEN, 6)
	var card := run.grant_pack(Pack.number_pack(_rng(1)))
	assert_true(run.start_labor_job({"packs": [card.pack_uid]}))
	assert_true(run.labor_collectable())
	assert_eq(run.labor_state()["phase"], Labor.PHASE_DONE)

# --- SEELEN-TRANSFER ----------------------------------------------------------------

func test_soul_transfer_locks_dice_and_copies_soul() -> void:
	var run := _soul_run()
	run.owned_pool[5].essence_id = ""
	var source := run.owned_pool[0]
	var target := run.owned_pool[5]
	assert_true(run.start_labor_job({"dice": [0, 5]}, _rng(3)))
	assert_eq(run.owned_pool.size(), GameRun.POOL_SIZE, "der Vorrat behält alle Einträge")
	assert_true(run.die_in_labor(source))
	assert_true(run.die_in_labor(target))
	assert_eq(run.labor_dice().size(), 2)
	var hand := run.playable_pool()
	assert_eq(hand.size(), GameRun.POOL_SIZE - 2)
	assert_false(hand.has(source))
	assert_false(hand.has(target))
	run.labor_job.done = true
	var out := run.collect_labor(_rng(4))
	assert_eq(out["station"], Labor.SEELE)
	assert_eq(target.essence_id, Essence.SCAR)
	assert_eq(source.essence_id, Essence.SCAR, "die Quelle behält ihre Seele")
	assert_same(run.owned_pool[0], source)
	assert_same(run.owned_pool[5], target)
	assert_false(run.die_in_labor(source))
	assert_eq(run.playable_pool().size(), GameRun.POOL_SIZE)
	assert_ne(run.labor_station, Labor.SEELE, "danach eine andere Station")

func test_soul_transfer_overwrites_target_soul() -> void:
	var run := _soul_run()
	run.owned_pool[1].essence_id = Essence.all()[0].id if Essence.all()[0].id != Essence.SCAR \
		else Essence.all()[1].id
	assert_true(run.start_labor_job({"dice": [0, 1]}))
	run.labor_job.done = true
	run.collect_labor()
	assert_eq(run.owned_pool[1].essence_id, Essence.SCAR)

func test_locked_dice_are_not_exchanged_reordered_or_stamped() -> void:
	var run := _soul_run()
	assert_true(run.start_labor_job({"dice": [0, 5]}))
	var source := run.owned_pool[0]
	run.stash_die(DieDefinition.standard(), 0)
	assert_false(run.exchange_pending_die(0, 0), "kein Tausch auf einen Labor-Sitz")
	assert_true(run.exchange_pending_die(0, 1))
	assert_false(run.reorder_pool(0, 3))
	assert_false(run.reorder_pool(3, 5))
	assert_true(run.reorder_pool(1, 4))
	assert_same(run.owned_pool[0], source, "der Labor-Würfel behält seinen Sitz")
	assert_true(run.die_in_labor(run.owned_pool[5]))
	var card := run.grant_pack(Pack.number_pack(_rng(1)))
	assert_eq(run.apply_series([card.pack_uid] as Array[int], source), {})

func test_pack_choice_cannot_seat_on_a_locked_die() -> void:
	var run := _soul_run()
	assert_true(run.start_labor_job({"dice": [0, 5]}))
	var choice := PackChoice.new()
	choice.kind = PackChoice.KIND_DICE
	choice.pack = DicePack.make(DicePack.SORT_NORMAL, 2)
	choice.options = [DieDefinition.standard(), DieDefinition.standard()]
	choice.picks = 2
	run.pending_pack_choices.append(choice)
	assert_eq(run.confirm_dice_choice(choice, {0: 5}), [])
	assert_eq(run.confirm_dice_choice(choice, {0: 2}).size(), 1)

func test_full_reorder_keeps_locked_seats() -> void:
	var run := _soul_run()
	assert_true(run.start_labor_job({"dice": [0, 5]}))
	var locked := [run.owned_pool[0], run.owned_pool[5]]
	var rest := run.playable_pool()
	rest.reverse()
	assert_true(run.reorder_pool_full(rest), "der Stapel ohne Labor-Würfel reicht")
	assert_same(run.owned_pool[0], locked[0])
	assert_same(run.owned_pool[5], locked[1])
	assert_same(run.owned_pool[1], rest[0])

func test_invalid_soul_inputs() -> void:
	var run := _soul_run()
	assert_false(run.labor_inputs_valid({"dice": [1, 2]}), "Quelle ohne Seele")
	assert_false(run.labor_inputs_valid({"dice": [0, 0]}))
	assert_false(run.labor_inputs_valid({"dice": [0]}))
	assert_false(run.labor_inputs_valid({"dice": [0, 99]}))
	assert_false(run.labor_inputs_valid({"charm": 0}), "falsche Station")
	assert_true(run.labor_inputs_valid({"dice": [0, 2]}))

# --- CHARM-KOPIERER -------------------------------------------------------------------

func test_charm_goes_dark_and_comes_back_with_a_copy() -> void:
	var run := _run(Labor.CHARM, 6)
	run.owned_charms.append(Charm.rabbits_foot())
	run.owned_charms.append(Charm.lucky_cigarettes())
	var foot := run.owned_charms[0]
	assert_true(run.start_labor_job({"charm": 0}))
	assert_eq(run.labor_charm_slot(), 0)
	assert_false(run.charm_ids().has(foot.id), "im Labor wirkt er nicht")
	assert_eq(run.owned_charms.size(), 2, "sein Projektor bleibt belegt")
	run.sell_charm(0)
	assert_eq(run.owned_charms.size(), 2, "nicht verkäuflich")
	run.move_charm(0, 1)
	assert_same(run.owned_charms[0], foot, "nicht verschiebbar")
	run.move_charm(1, 0)
	assert_same(run.owned_charms[0], foot, "auch nicht verdrängbar")
	var out := run.collect_labor()
	assert_same(out["charm"], foot)
	assert_eq(run.owned_charms.size(), 3)
	assert_not_same(out["copy"], foot)
	assert_eq((out["copy"] as Charm).id, foot.id)
	assert_eq(run.charm_ids().count(foot.id), 2, "Original und Kopie wirken")
	assert_eq(run.labor_charm_slot(), -1)

func test_charm_copy_waits_for_a_free_projector() -> void:
	var run := _run(Labor.CHARM, 6)
	for i in run.charm_capacity():
		run.owned_charms.append(Charm.rabbits_foot())
	assert_true(run.start_labor_job({"charm": 1}))
	assert_true(run.labor_job.done)
	assert_false(run.labor_collectable())
	assert_true(run.labor_state()["needs_projector"])
	assert_eq(run.collect_labor(), {})
	assert_not_null(run.labor_job, "der Auftrag bleibt fertig stehen")
	run.sell_charm(0)
	assert_true(run.labor_collectable())
	assert_false(run.collect_labor().is_empty())
	assert_eq(run.owned_charms.size(), run.charm_capacity())

func test_labor_charm_is_spared_by_losses() -> void:
	var run := _run(Labor.CHARM)
	run.owned_charms.append(Charm.rabbits_foot())
	assert_true(run.start_labor_job({"charm": 0}))
	assert_eq(run.auction_charm_index(), -1)

# --- MODUL-KOPIERER -------------------------------------------------------------------

func test_module_is_inactive_and_copy_goes_to_pending() -> void:
	var run := _run(Labor.MODUL, 6)
	var key: String = DiceScoring.HAND_PRIORITY[0]
	var other: String = DiceScoring.HAND_PRIORITY[1]
	var part := ComboPart.resistor()
	run.combo_parts[key] = [part, null, null]
	assert_true(run.start_labor_job({"part": {"key": key, "slot": 0}}))
	assert_same(run.labor_part(), part)
	assert_true(run.is_part_disabled(part))
	assert_null(run.scoring_parts()[key][0], "es wirkt nicht")
	assert_same(run.parts_of(key)[0], part, "sein Steckplatz bleibt belegt")
	assert_false(run.move_part(key, 0, other, 0))
	assert_false(run.move_part(key, 1, key, 0))
	assert_eq(run.install_target(key, 0, true), -1)
	run.stash_part(ComboPart.resistor())
	assert_false(run.install_pending_part_at(0, key, 0))
	run.pending_parts.clear()
	assert_null(run._destroy_random_part(_rng(1)), "der Fumble-Verlust trifft es nicht")
	var state := run.labor_state()
	assert_eq(state["part_key"], key)
	assert_eq(state["part_slot"], 0)
	var out := run.collect_labor()
	assert_same(out["part"], part)
	assert_eq(run.pending_parts.size(), 1)
	assert_not_same(run.pending_parts[0], part)
	assert_eq(run.pending_parts[0].id, part.id)
	assert_false(run.is_part_disabled(part))
	assert_same(run.scoring_parts()[key][0], part)

func test_invalid_module_inputs() -> void:
	var run := _run(Labor.MODUL)
	var key: String = DiceScoring.HAND_PRIORITY[0]
	assert_false(run.labor_inputs_valid({"part": {"key": key, "slot": 0}}), "leerer Platz")
	assert_false(run.labor_inputs_valid({"part": {"key": "nix", "slot": 0}}))
	assert_false(run.labor_inputs_valid({"part": 3}))

# --- KARTEN-PRESSE --------------------------------------------------------------------

func test_cards_leave_and_return_as_new_cards_of_the_same_sort() -> void:
	var run := _run(Labor.KARTEN, 6)
	var given: Array[Pack] = [
		run.grant_pack(Pack.number_pack(_rng(1))),
		run.grant_pack(Pack.material_pack(_rng(2))),
		run.grant_pack(Pack.dice_mod_pack(_rng(3))),
		run.grant_pack(Pack.operator_pack(StampNet.OP_DOUBLER)),
	]
	var uids := [given[0].pack_uid, given[1].pack_uid, given[2].pack_uid]
	assert_true(run.start_labor_job({"packs": uids}))
	assert_eq(run.owned_packs.size(), 1, "die Karten sind fort")
	assert_eq(run.labor_packs().size(), 3)
	var out := run.collect_labor(_rng(9))
	var cards: Array = out["cards"]
	assert_eq(cards.size(), 3)
	for i in 3:
		var card: Pack = cards[i]
		assert_eq(Pack.shelf_of(card), Pack.shelf_of(given[i]), "dieselbe Sorte")
		assert_not_same(card, given[i])
		assert_true(run.owned_packs.has(card))
		assert_gt(card.pack_uid, 0)
	assert_eq(run.owned_packs.size(), 4)
	assert_eq(run.labor_packs().size(), 0)

func test_invalid_card_inputs() -> void:
	var run := _run(Labor.KARTEN)
	var blank := run.grant_pack(Pack.blank_card())
	var catalyst := run.grant_pack(Pack.catalyst(Pack.CATALYST_PROPELLANT))
	var op := run.grant_pack(Pack.operator_pack(StampNet.OP_DOUBLER))
	var plain := run.grant_pack(Pack.number_pack(_rng(1)))
	assert_false(run.labor_inputs_valid({"packs": [blank.pack_uid]}), "Rohling")
	assert_false(run.labor_inputs_valid({"packs": [catalyst.pack_uid]}), "Katalysator")
	assert_false(run.labor_inputs_valid({"packs": [op.pack_uid]}), "Operator")
	assert_false(run.labor_inputs_valid({"packs": []}))
	assert_false(run.labor_inputs_valid({"packs": [plain.pack_uid, plain.pack_uid]}))
	assert_false(run.labor_inputs_valid({"packs": [999]}))
	var seven: Array = []
	for i in 7:
		seven.append(run.grant_pack(Pack.number_pack(_rng(10 + i))).pack_uid)
	assert_false(run.labor_inputs_valid({"packs": seven}), "höchstens sechs")
	seven.pop_back()
	assert_true(run.labor_inputs_valid({"packs": seven}))

func test_closed_labor_starts_nothing() -> void:
	var run := GameRun.new_run()
	run.energy = 5
	var card := run.grant_pack(Pack.number_pack(_rng(1)))
	assert_false(run.can_start_labor({"packs": [card.pack_uid]}))
