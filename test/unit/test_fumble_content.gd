extends GutTest
## Fumbles als Laufzähler und ihr Inhalt: Zähler im Kern, Pechsträhne, Strafgebühr,
## die vier Charms, die zwei Seelen, die zwei Module und der Joker der Automaten.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

func _ids(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _fumble(times: int = 1) -> void:
	for i in times:
		run.note_fumble(false)

# --- Zähler ----------------------------------------------------------------------

func test_note_fumble_counts_run_block_and_round() -> void:
	_fumble(3)
	assert_eq(run.farkle_count, 3)
	assert_eq(run.block_fumbles, 3)
	assert_eq(run.round_fumbles, 3)

func test_block_fumbles_reset_at_the_block_edge_only() -> void:
	_fumble(2)
	for i in GameRun.GOAL_BLOCK - 1:
		run.advance_round()
	assert_eq(run.block_fumbles, 2, "noch im ersten Block")
	run.advance_round()
	assert_eq(run.block_fumbles, 0, "neuer Block, neuer Speicher")
	assert_eq(run.farkle_count, 2, "der Laufzähler sinkt nie")

# --- Klauseln ----------------------------------------------------------------------

func test_bad_streak_raises_the_blind_for_good_per_fumble() -> void:
	run.sign_clauses(_ids([DealClause.BAD_STREAK]))
	_fumble(2)
	assert_almost_eq(run.blind_value, 150.0 * 1.02 * 1.02, 0.001)
	run.advance_round()
	_fumble()
	assert_almost_eq(run.blind_value, 150.0 * 1.02 * 1.02 * 1.1, 0.001, "nur in ihrer Runde")

func test_penalty_fee_costs_five_but_never_below_zero() -> void:
	run.round_number = GameRun.GOAL_BLOCK
	run.sign_clauses(_ids([DealClause.PENALTY_FEE]))
	run.money = 7
	_fumble()
	assert_eq(run.money, 2)
	assert_eq(run.last_fumble_fee, 5)
	_fumble()
	assert_eq(run.money, 0, "nie unter $0")
	assert_eq(run.last_fumble_fee, 2)

func test_new_clauses_carry_their_tiers_and_tags() -> void:
	assert_eq(DealClause.find(DealClause.BAD_STREAK).tier, DealClause.Tier.TWO)
	assert_eq(DealClause.find(DealClause.BAD_STREAK).kind, DealClause.Kind.MALUS)
	assert_eq(DealClause.find(DealClause.PENALTY_FEE).tier, DealClause.Tier.BOSS)
	assert_eq(DealClause.find(DealClause.UNLUCKY_NUMBER).kind, DealClause.Kind.MALUS)
	for clause_id in [DealClause.LUCKY_PENNY, DealClause.LUCKY_STREAK, DealClause.LUCKY_CHILD, DealClause.UNLUCKY_NUMBER]:
		assert_true(DealClause.tags_of(clause_id).has(DealClause.TAG_LUCK), clause_id)
		assert_eq(DealClause.find(clause_id).scope, DealClause.Scope.INSTANT, clause_id)

# --- Charms ------------------------------------------------------------------------

func test_unlucky_bird_adds_one_mult_per_two_fumbles() -> void:
	var ctx := {CharmEffects.CTX_FARKLE_STACKS: 7}
	var values: Array[int] = [3, 3]
	var materials: Array[String] = ["", ""]
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, values, materials,
		_ids([Charm.UNLUCKY_BIRD]), ctx), 3)

func test_fumble_pension_pays_one_per_three_fumbles() -> void:
	var entries := CharmEffects.round_end_income_entries(0, 0, _ids([Charm.FUMBLE_PENSION]), 0, 0, 10)
	assert_eq(entries.size(), 1)
	assert_eq(int(entries[0]["amount"]), 3)
	assert_eq(String(entries[0]["charm_id"]), Charm.FUMBLE_PENSION)
	assert_eq(CharmEffects.round_end_income(0, 0, _ids([Charm.FUMBLE_PENSION]), 0, 0, 2), 0)

func test_gallows_reprieve_lowers_only_this_rounds_blind() -> void:
	run.owned_charms.append(Charm.gallows_reprieve())
	var goal := run.effective_goal()
	_fumble(2)
	assert_eq(run.effective_goal(), roundi(goal * 0.97 * 0.97))
	assert_almost_eq(run.blind_value, 150.0, 0.001, "der Akkumulator bleibt")
	assert_eq(run.stage_size(1), run.effective_goal(), "der Balken zieht mit")

func test_black_cat_discounts_two_percent_per_fumble_capped() -> void:
	run.owned_charms.append(Charm.black_cat())
	_fumble(5)
	assert_almost_eq(run.shop_price_factor(), 0.9, 0.0001)
	_fumble(30)
	assert_almost_eq(run.shop_price_factor(), 0.7, 0.0001, "höchstens −30 %")

func test_the_new_charms_are_registered() -> void:
	for charm_id in [Charm.UNLUCKY_BIRD, Charm.FUMBLE_PENSION, Charm.GALLOWS_REPRIEVE, Charm.BLACK_CAT]:
		var found := false
		for charm in Charm.all():
			found = found or charm.id == charm_id
		assert_true(found, charm_id)
		assert_true(Charm.RARITIES.has(charm_id), charm_id)

# --- Seelen ------------------------------------------------------------------------

func test_scar_grows_its_up_face_on_a_real_fumble() -> void:
	var die := DieDefinition.standard()
	die.essence_id = Essence.SCAR
	var before: int = die.faces[2]
	run.charge_fumble_dice([die] as Array[DieDefinition], [2] as Array[int])
	assert_eq(die.faces[2], before + 1)
	assert_eq(die.charge, 1, "geheizt wird trotzdem")

func test_cooling_jacket_cools_instead_of_heating() -> void:
	var die := DieDefinition.standard()
	die.essence_id = Essence.COOLING_JACKET
	die.charge = 2
	run.charge_fumble_dice([die] as Array[DieDefinition], [0] as Array[int])
	assert_eq(die.charge, 1)
	die.charge = 0
	run.charge_fumble_dice([die] as Array[DieDefinition], [0] as Array[int])
	assert_eq(die.charge, 0, "nie unter 0")

func test_a_plain_die_still_heats() -> void:
	var die := DieDefinition.standard()
	run.charge_fumble_dice([die] as Array[DieDefinition])
	assert_eq(die.charge, 1)

# --- Module ------------------------------------------------------------------------

func test_error_memory_adds_the_block_fumbles_as_mult() -> void:
	run.combo_parts[DiceScoring.TWO_KIND] = [ComboPart.error_memory(), null, null]
	_fumble(4)
	var steps := ComboPartEffects.combo_steps(run.scoring_parts(), DiceScoring.TWO_KIND)
	assert_eq(steps.size(), 1)
	assert_eq(int(steps[0]["mult"]), 4)

func test_afterburner_fires_once_after_a_fumble() -> void:
	var part := ComboPart.afterburner()
	run.combo_parts[DiceScoring.TWO_KIND] = [part, null, null]
	assert_true(ComboPartEffects.crit_steps(run.parts_of(DiceScoring.TWO_KIND)).is_empty(), "kalt ohne Fumble")
	_fumble()
	var steps := ComboPartEffects.crit_steps(run.parts_of(DiceScoring.TWO_KIND))
	assert_eq(steps.size(), 1)
	assert_almost_eq(float(steps[0]["crit_x"]), 2.0, 0.0001)
	run.book_combo_scored(DiceScoring.TWO_KIND)
	assert_true(ComboPartEffects.crit_steps(run.parts_of(DiceScoring.TWO_KIND)).is_empty(), "einmal je Fumble")

func test_the_afterburner_is_a_secret_crit_part() -> void:
	var part := ComboPart.afterburner()
	assert_eq(part.phase, ComboPart.PHASE_CRIT)
	assert_true(part.secret)
	assert_eq(ComboPart.error_memory().phase, ComboPart.PHASE_COMBO)

# --- Automaten ---------------------------------------------------------------------

func test_the_joker_weight_grows_with_the_run_fumbles() -> void:
	assert_almost_eq(SlotMachine.joker_weight(0), SlotMachine.W_JOKER, 0.0001)
	assert_almost_eq(SlotMachine.joker_weight(10), SlotMachine.W_JOKER + 0.5, 0.0001)
	assert_almost_eq(SlotMachine.joker_weight(999), SlotMachine.W_JOKER + 1.0, 0.0001, "gedeckelt")

func test_fumble_readers_name_what_reads_the_counter() -> void:
	run.owned_charms.append(Charm.unlucky_bird())
	_fumble(6)
	var lines := run.fumble_readers()
	assert_true(lines.has("Pechvogel: +3 Mult"), str(lines))
