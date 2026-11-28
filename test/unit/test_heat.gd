extends GutTest
## Die HITZE: Auslage je Hitze-Stand, Buchung der Wahl, Fumble, Boss-Runde,
## Vorschau, Blind je Runde und der Block-Streifen.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

func _levels() -> Array[int]:
	var levels: Array[int] = []
	for card in run.route_offers:
		levels.append(int(card[GameRun.CARD_LEVEL]))
	return levels

func _deltas() -> Array[int]:
	var deltas: Array[int] = []
	for card in run.route_offers:
		deltas.append(int(card[GameRun.CARD_HEAT_DELTA]))
	return deltas

## Würfelt die Auslage ohne Werbegeschenk (die Chance steht sonst bei 30 %).
func _roll_plain() -> void:
	for i in 50:
		run.roll_route_offers()
		if not bool(run.route_offers[1][GameRun.CARD_TREAT]):
			return

# --- Auslage ----------------------------------------------------------------------

func test_a_run_starts_cool_with_three_deals() -> void:
	assert_eq(run.heat, GameRun.HEAT_MIN)
	assert_eq(run.route_offers.size(), 3, "auch Runde 1 wählt einen Deal")

func test_the_middle_heat_offers_cooler_same_hotter() -> void:
	run.heat = 3
	_roll_plain()
	assert_eq(_levels(), [2, 3, 4] as Array[int])
	assert_eq(_deltas(), [-1, 0, 1] as Array[int])

func test_the_cooler_deal_has_no_malus() -> void:
	for h in range(2, GameRun.HEAT_MAX + 1):
		run.heat = h
		run.roll_route_offers()
		assert_true(run.route_offers[0][GameRun.CARD_MALUS].is_empty(), "Hitze %d: kühler ohne Malus" % h)
		assert_false(run.route_offers[0][GameRun.CARD_BONUS].is_empty())

func test_the_lower_edge_offers_a_second_level_one_deal_with_malus() -> void:
	run.heat = 1
	_roll_plain()
	assert_eq(_levels(), [1, 1, 2] as Array[int])
	assert_eq(_deltas(), [0, 0, 1] as Array[int])
	assert_false(run.route_offers[0][GameRun.CARD_MALUS].is_empty(), "am unteren Rand mit Malus")

func test_the_upper_edge_offers_white_heat() -> void:
	run.heat = 5
	_roll_plain()
	assert_eq(_levels(), [4, 5, 6] as Array[int])
	assert_eq(_deltas(), [-1, 0, 0] as Array[int], "Weißglut läßt die Hitze auf 5")
	var white: Dictionary = run.route_offers[2]
	assert_eq(white[GameRun.CARD_BONUS].size(), 3, "drei Boni")
	assert_eq(white[GameRun.CARD_MALUS].size(), 3, "zwei Mali und eine Boss-Kondition")
	var boss := DealClause.find(String(white[GameRun.CARD_MALUS][2]))
	assert_eq(boss.tier, DealClause.Tier.BOSS)

func test_the_recipes_stack_the_clause_tiers() -> void:
	for level in range(1, GameRun.HEAT_WHITE + 1):
		var recipe: Dictionary = GameRun.HEAT_RECIPES[level]
		assert_eq(recipe["bonus"].size(), [1, 1, 1, 2, 2, 3][level - 1], "Stufe %d" % level)
		assert_eq(recipe["malus"].size(), [1, 1, 1, 2, 2, 3][level - 1], "Stufe %d" % level)
	run.heat = 4
	_roll_plain()
	var same: Dictionary = run.route_offers[1]
	assert_eq(same[GameRun.CARD_BONUS].size(), 2)
	assert_eq(same[GameRun.CARD_MALUS].size(), 2)

func test_the_treat_strikes_the_malus_of_the_middle_deal() -> void:
	run.owned_charms.append(Charm.ad_drum())
	var seen := false
	for i in 30:
		run.roll_route_offers()
		if bool(run.route_offers[1][GameRun.CARD_TREAT]):
			seen = true
			assert_true(run.route_offers[1][GameRun.CARD_MALUS].is_empty())
	assert_true(seen)

func test_the_boss_round_offers_conditions_without_heat_change() -> void:
	run.heat = 4
	run.round_number = GameRun.GOAL_BLOCK
	run.roll_route_offers()
	assert_eq(run.route_offers.size(), 3)
	for card in run.route_offers:
		assert_true(bool(card[GameRun.CARD_BOSS]))
		assert_eq(int(card[GameRun.CARD_HEAT_DELTA]), 0)
	run.take_route(2)
	assert_eq(run.heat, 4, "die Boss-Kondition ändert die Hitze nicht")

# --- Buchung ----------------------------------------------------------------------

func test_each_pick_books_the_heat() -> void:
	run.heat = 3
	run.roll_route_offers()
	run.take_route(2)
	assert_eq(run.heat, 4, "heißer")
	run.roll_route_offers()
	run.take_route(1)
	assert_eq(run.heat, 4, "gleich")
	run.roll_route_offers()
	run.take_route(0)
	assert_eq(run.heat, 3, "kühler")

func test_white_heat_keeps_the_heat_at_five() -> void:
	run.heat = 5
	run.roll_route_offers()
	run.take_route(2)
	assert_eq(run.heat, 5)

func test_the_heat_signal_fires_on_change_only() -> void:
	watch_signals(run)
	run.heat = 1
	assert_signal_not_emitted(run, "heat_changed")
	run.heat = 2
	assert_signal_emitted(run, "heat_changed")

func test_take_route_rejects_a_bad_index() -> void:
	assert_false(run.take_route(5))
	assert_eq(run.route_offers.size(), 3, "nichts gebucht")

# --- Fumble -----------------------------------------------------------------------

func test_the_first_fumble_of_a_round_costs_a_level() -> void:
	run.heat = 4
	run.note_fumble(false)
	assert_eq(run.heat, 3, "der erste kostet")
	run.note_fumble(false)
	assert_eq(run.heat, 3, "der zweite nicht")
	run.advance_round()
	run.note_fumble(false)
	assert_eq(run.heat, 2, "die neue Runde zählt neu")

func test_a_fumble_never_cools_below_one() -> void:
	run.note_fumble(false)
	assert_eq(run.heat, GameRun.HEAT_MIN)

# --- Boss-Runde -------------------------------------------------------------------

func test_the_boss_reward_pays_dice_by_heat() -> void:
	for h in range(1, GameRun.HEAT_MAX + 1):
		var fresh := GameRun.new_run()
		fresh.heat = h
		var tier := fresh.reward_die_tier()
		assert_eq(tier, fresh.progress_tier() + h - 1, "die Güte steigt mit der Hitze")
		var dice := fresh.grant_stress_reward()
		assert_eq(dice.size(), 1 if h <= 3 else 2, "Hitze %d" % h)
		assert_eq(fresh.pending_dice.size(), dice.size())
		for die in dice:
			assert_ne(die.essence_id, "", "beseelt")

func test_the_heat_halves_after_the_boss_round() -> void:
	for pair in [[5, 3], [4, 2], [3, 2], [2, 1], [1, 1]]:
		var fresh := GameRun.new_run()
		fresh.heat = pair[0]
		fresh.grant_stress_reward()
		assert_eq(fresh.heat, pair[1], "%d -> %d" % pair)

# --- Vorschau und Blind -----------------------------------------------------------

func test_the_preview_is_the_booking() -> void:
	for h in range(1, GameRun.HEAT_MAX + 1):
		for slot in 3:
			var fresh := GameRun.new_run()
			fresh.heat = h
			fresh.roll_route_offers()
			var preview := fresh.blind_after_offer(slot)
			fresh.take_route(slot)
			assert_eq(preview, fresh.effective_goal(), "Hitze %d, Platz %d" % [h, slot])

func test_the_blind_grows_per_round_again() -> void:
	run.advance_round()
	assert_almost_eq(run.blind_value, 165.0, 0.001)
	for i in 5:
		run.advance_round()
	assert_eq(run.round_number, 7)
	assert_almost_eq(run.blind_value, 150.0 * pow(1.1, 5) * 1.15, 0.001, "Block 2: +15 %")

# --- Ansichten ---------------------------------------------------------------------

func test_the_strip_state_follows_the_block() -> void:
	run.heat = 2
	run.roll_route_offers()
	run.take_route(2)  # heißer: gespielt mit Stufe 3
	run.advance_round()
	var state := run.block_strip_state()
	var stops: Array = state["stops"]
	assert_eq(stops.size(), GameRun.GOAL_BLOCK)
	assert_eq(String(stops[0]["state"]), GameRun.STOP_DONE)
	assert_eq(int(stops[0]["heat"]), 3)
	assert_eq(String(stops[0]["pick"]), GameRun.PICK_HOT)
	assert_eq(String(stops[1]["state"]), GameRun.STOP_NOW)
	assert_eq(String(stops[2]["state"]), GameRun.STOP_AHEAD)
	assert_true(bool(stops[5]["boss"]))
	assert_eq(int(state["heat"]), 3)
	assert_eq(int(state["heat_max"]), GameRun.HEAT_MAX)
	assert_eq(int(state["block"]), 1)
	assert_true(bool(state["pending"]))

func test_the_block_log_clears_with_the_next_block() -> void:
	run.take_route(1)
	for i in GameRun.GOAL_BLOCK:
		run.advance_round()
	assert_true(run.block_log.is_empty())
	assert_eq(int(run.block_strip_state()["block"]), 2)

func test_the_route_state_carries_full_texts() -> void:
	run.owned_charms.append(Charm.shyster())
	run.heat = 3
	run.roll_route_offers()
	var state := run.route_view_state()
	assert_false(bool(state["boss"]))
	for card: Dictionary in state["cards"]:
		var offer: Dictionary = run.route_offers[int(card["index"])]
		assert_eq(int(card["level"]), int(offer[GameRun.CARD_LEVEL]))
		for clause: Dictionary in card["bonus"]:
			assert_eq(String(clause["text"]), DealClause.text_for(String(clause["id"]), 2), "Bonus mit Faktor")
			assert_ne(String(clause["name"]), "")
		for clause: Dictionary in card["malus"]:
			assert_eq(String(clause["text"]), DealClause.text_for(String(clause["id"])))

# --- Kopfloser Lauf ---------------------------------------------------------------

func test_a_headless_run_over_three_blocks() -> void:
	seed(7)
	var max_seen := 0
	for r in GameRun.GOAL_BLOCK * 3:
		assert_eq(run.route_offers.size(), 3, "Runde %d legt aus" % run.round_number)
		var slot := 2 if run.round_number % 3 != 0 else 0
		var preview := run.blind_after_offer(slot)
		assert_true(run.take_route(slot))
		assert_eq(preview, run.effective_goal())
		assert_between(run.heat, GameRun.HEAT_MIN, GameRun.HEAT_MAX)
		max_seen = maxi(max_seen, run.heat)
		if run.round_number % 4 == 0:
			run.note_fumble(false)
		if run.is_boss_round():
			run.settle_block_deals()
			var before := run.heat
			var dice := run.grant_stress_reward()
			assert_eq(dice.size(), 1 if before <= 3 else 2)
			assert_eq(run.heat, ceili(float(before) / 2.0))
			run.pending_dice.clear()
		run.advance_round()
	assert_eq(run.round_number, GameRun.GOAL_BLOCK * 3 + 1)
	assert_gt(max_seen, 2, "die Hitze ist gestiegen")
