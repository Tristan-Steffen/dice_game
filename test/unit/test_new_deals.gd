extends GutTest
## Die Klauseln vom 2026-11-25 (Welle 2): Werkstatt, Module, Charms, Glückswürfel.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

func _sign(ids: Array) -> void:
	var typed: Array[String] = []
	typed.assign(ids)
	run.sign_clauses(typed)

func _shyster() -> void:
	run.owned_charms.append(Charm.shyster())

func _stamp() -> Dictionary:
	run.grant_pack(Pack.number_pack())
	var uids: Array[int] = [run.owned_packs[run.owned_packs.size() - 1].pack_uid]
	return run.apply_series(uids, run.owned_pool[0])

func _fill_chip(key: String, count: int) -> void:
	var sockets: Array = [null, null, null]
	var ids := [ComboPart.RESISTOR, ComboPart.CAPACITOR, ComboPart.COIL]
	for i in count:
		sockets[i] = ComboPart.make(ids[i])
	run.combo_parts[key] = sockets

const NEW := {
	DealClause.TRIAL_RUN: [DealClause.Tier.ONE, DealClause.Kind.BONUS],
	DealClause.HAND_WAGE: [DealClause.Tier.ONE, DealClause.Kind.BONUS],
	DealClause.DEPOSIT: [DealClause.Tier.ONE, DealClause.Kind.BONUS],
	DealClause.OVERTIME: [DealClause.Tier.TWO, DealClause.Kind.BONUS],
	DealClause.EXCHANGE_OFFICE: [DealClause.Tier.TWO, DealClause.Kind.BONUS],
	DealClause.LOADED_LUCK_DIE: [DealClause.Tier.THREE, DealClause.Kind.BONUS],
	DealClause.MASTER_PRESS: [DealClause.Tier.THREE, DealClause.Kind.BONUS],
	DealClause.FULL_LOADOUT: [DealClause.Tier.THREE, DealClause.Kind.BONUS],
	DealClause.SLOW_START: [DealClause.Tier.ONE, DealClause.Kind.MALUS],
	DealClause.WORKSHOP_BAN: [DealClause.Tier.ONE, DealClause.Kind.MALUS],
	DealClause.LOOSE_CONTACT: [DealClause.Tier.TWO, DealClause.Kind.MALUS],
	DealClause.PROJECTOR_FAILURE: [DealClause.Tier.TWO, DealClause.Kind.MALUS],
	DealClause.SHORT_TIME: [DealClause.Tier.TWO, DealClause.Kind.MALUS],
	DealClause.SEIZURE: [DealClause.Tier.THREE, DealClause.Kind.MALUS],
	DealClause.FORCED_AUCTION: [DealClause.Tier.THREE, DealClause.Kind.MALUS],
	DealClause.SHOP_CLOSED: [DealClause.Tier.THREE, DealClause.Kind.MALUS],
	DealClause.SCRAP_PRESS: [DealClause.Tier.THREE, DealClause.Kind.MALUS],
	DealClause.UNLUCKY_PACT: [DealClause.Tier.THREE, DealClause.Kind.MALUS],
}

func test_every_new_clause_sits_in_its_pot():
	for clause_id: String in NEW:
		var clause := DealClause.find(clause_id)
		assert_not_null(clause, clause_id)
		assert_eq(clause.tier, NEW[clause_id][0], clause_id)
		assert_eq(clause.kind, NEW[clause_id][1], clause_id)
		assert_false(clause.tags.is_empty(), "%s trägt ein Tag" % clause_id)

# --- Werkstatt --------------------------------------------------------------------

func test_one_press_per_round_by_default():
	assert_false(_stamp().is_empty())
	assert_true(_stamp().is_empty(), "die zweite Prägung ist verbraucht")

func test_trial_run_allows_a_second_press():
	_sign([DealClause.TRIAL_RUN])
	assert_eq(run.press_limit(), 2)
	assert_false(_stamp().is_empty())
	assert_false(_stamp().is_empty())
	assert_true(_stamp().is_empty())

func test_trial_run_doubles_under_the_shyster():
	_shyster()
	_sign([DealClause.TRIAL_RUN])
	assert_eq(run.press_limit(), 3)

func test_master_press_never_runs_out():
	_sign([DealClause.MASTER_PRESS])
	for i in 5:
		assert_false(_stamp().is_empty(), "Prägung %d" % i)

func test_workshop_ban_blocks_every_press():
	_sign([DealClause.WORKSHOP_BAN])
	assert_true(run.press_banned())
	assert_false(run.press_allowed())
	assert_true(_stamp().is_empty())
	run.grant_pack(Pack.catalyst(Pack.CATALYST_GROUND))
	run.grant_pack(Pack.number_pack())
	var uids: Array[int] = []
	for pack in run.owned_packs:
		uids.append(pack.pack_uid)
	assert_false(run.series_press_allowed(uids), "auch keine Erdungsklemme")

func test_presses_reset_with_the_round():
	_stamp()
	assert_false(run.press_allowed())
	run.apply_round_start_charms()
	assert_true(run.press_allowed())

# --- Geld und Energie -------------------------------------------------------------

func test_hand_wage_pays_per_hand():
	assert_eq(run.hand_wage(), 0)
	_sign([DealClause.HAND_WAGE])
	assert_eq(run.hand_wage(), 2)
	_shyster()
	assert_eq(run.hand_wage(), 4)

func test_exchange_office_pays_per_energy():
	run.energy = 4
	assert_eq(run.exchange_income(), 0)
	_sign([DealClause.EXCHANGE_OFFICE])
	assert_eq(run.exchange_income(), 12)

func test_deposit_mints_energy_per_opened_pack():
	_sign([DealClause.DEPOSIT])
	watch_signals(run)
	run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_SMALL), 0)
	assert_eq(run.energy, 1)
	assert_signal_emitted_with_parameters(run, "deposit_energy", [1])
	run.purchase_module_pack(ModulePack.new(), 0)
	assert_eq(run.energy, 2, "Modul-Pakete zählen mit")

func test_seizure_takes_half_the_money():
	run.money = 21
	_sign([DealClause.SEIZURE])
	assert_eq(run.money, 11)

func test_seizure_is_not_offered_without_money():
	run.money = 0
	assert_false(run._clause_offerable(DealClause.SEIZURE))

# --- Glückswürfel -----------------------------------------------------------------

func test_loaded_luck_die_shows_the_best_face_first():
	run.luck_die.faces.assign([1, 2, 5, 1, 3, 1])
	_sign([DealClause.LOADED_LUCK_DIE])
	var first := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_HUGE), 0)
	assert_eq(first.die_face, 2)
	assert_eq(first.die_value, 5)

func test_loose_contact_caps_the_luck_die():
	run.luck_die.faces.assign([6, 6, 6, 6, 6, 2])
	_sign([DealClause.LOOSE_CONTACT])
	for i in 6:
		var choice := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_HUGE), 0)
		assert_eq(choice.die_face, 5, "nur die kleine Seite")
		assert_eq(choice.die_value, 2)
	run.luck_die.faces.assign([6, 6, 6, 6, 6, 6])
	var clamped := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_HUGE), 0)
	assert_eq(clamped.die_value, 2, "ohne kleine Seite klemmt der Wert")

# --- Module -----------------------------------------------------------------------

func test_overtime_stamps_only_full_chips():
	_fill_chip(DiceScoring.TWO_KIND, 3)
	_fill_chip(DiceScoring.THREE_KIND, 2)
	_sign([DealClause.OVERTIME])
	var parts := run.scoring_parts()
	var full: Array = parts[DiceScoring.TWO_KIND]
	var half: Array = parts[DiceScoring.THREE_KIND]
	assert_eq(ComboPartEffects.die_retriggers(full, 0, -1, -1), 1)
	assert_eq(ComboPartEffects.die_retriggers(half, 0, -1, -1), 0)
	assert_true(ComboPartEffects.has_die_parts(full))

func test_overtime_ends_with_the_round():
	_fill_chip(DiceScoring.TWO_KIND, 3)
	_sign([DealClause.OVERTIME])
	run.scoring_parts()
	run.advance_round()
	var full: Array = run.scoring_parts()[DiceScoring.TWO_KIND]
	assert_eq(ComboPartEffects.die_retriggers(full, 0, -1, -1), 0)

func test_full_loadout_doubles_every_module():
	_fill_chip(DiceScoring.TWO_KIND, 2)
	var sockets: Array = run.scoring_parts()[DiceScoring.TWO_KIND]
	assert_eq(ComboPartEffects.weight(sockets, sockets[0]), 1)
	_sign([DealClause.FULL_LOADOUT])
	sockets = run.scoring_parts()[DiceScoring.TWO_KIND]
	assert_eq(ComboPartEffects.weight(sockets, sockets[0]), 2)
	assert_eq(ComboPartEffects.weighted(sockets).size(), 5, "zwei Module doppelt, der freie Platz einfach")

func test_scrap_press_destroys_one_module():
	_fill_chip(DiceScoring.TWO_KIND, 2)
	_sign([DealClause.SCRAP_PRESS])
	assert_eq(ComboPartEffects.part_count(run.combo_parts[DiceScoring.TWO_KIND]), 1)
	assert_not_null(run.last_scrapped_part)

func test_scrap_press_is_not_offered_without_modules():
	assert_false(run._clause_offerable(DealClause.SCRAP_PRESS))
	_fill_chip(DiceScoring.TWO_KIND, 1)
	assert_true(run._clause_offerable(DealClause.SCRAP_PRESS))

# --- Wertung ----------------------------------------------------------------------

func test_slow_start_halves_only_the_first_hand():
	var dice: Array[int] = [4, 4]
	var plain := DiceScoring.score_category(DiceScoring.TWO_KIND, dice)
	var first := {DiceScoring.CTX_SLOW_START: true, DiceScoring.CTX_HANDS_TAKEN: 0}
	var later := {DiceScoring.CTX_SLOW_START: true, DiceScoring.CTX_HANDS_TAKEN: 1}
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, dice, [], false, [], {}, first), plain / 2)
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, dice, [], false, [], {}, later), plain)
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, dice, [], true, [], {}, first)
	assert_eq(int(breakdown["total"]), plain / 2)
	assert_eq((breakdown["post_steps"] as Array).size(), 1)

# --- Charms -----------------------------------------------------------------------

func test_projector_failure_switches_one_charm_off_for_the_round():
	run.owned_charms.append(Charm.lucky_mushroom())
	run.owned_charms.append(Charm.shyster())
	_sign([DealClause.PROJECTOR_FAILURE])
	var dark := run.dark_charm_slot()
	assert_true(dark == 0 or dark == 1)
	assert_eq(run.charm_ids().size(), 1)
	assert_false(run.charm_ids().has(run.owned_charms[dark].id))
	run.advance_round()
	assert_eq(run.dark_charm_slot(), -1)
	assert_eq(run.charm_ids().size(), 2)

func test_forced_auction_sells_the_most_expensive_charm():
	var cheap := Charm.lucky_mushroom()
	var dear := Charm.shyster()
	cheap.price = 3
	dear.price = 9
	run.owned_charms.append(cheap)
	run.owned_charms.append(dear)
	var value := run.charm_sell_value(1)
	var before := run.money
	_sign([DealClause.FORCED_AUCTION])
	assert_eq(run.owned_charms.size(), 1)
	assert_eq(run.owned_charms[0], cheap)
	assert_eq(run.money, before + value, "zum Verkaufspreis")

func test_charm_clauses_need_a_charm():
	assert_false(run._clause_offerable(DealClause.FORCED_AUCTION))
	assert_false(run._clause_offerable(DealClause.PROJECTOR_FAILURE))

# --- Rest -------------------------------------------------------------------------

func test_shop_closed_empties_the_shop():
	_sign([DealClause.SHOP_CLOSED])
	assert_true(run.shop_closed())
	assert_eq(run.shop_charm_slots(), 0)
	assert_eq(run.shop_packs_offered(), 0)

func test_short_time_cuts_six_dice():
	assert_eq(run.short_time_cut(), 0)
	_sign([DealClause.SHORT_TIME])
	assert_eq(run.short_time_cut(), 6)

func test_unlucky_pact_costs_four_luck():
	run.luck = 10
	_sign([DealClause.UNLUCKY_PACT])
	assert_eq(run.luck, 6)
