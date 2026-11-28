extends GutTest
## Laufwerte: Rundenschnitt, Trend, Einholen, der Blind nach einem Deal und die beste Hand.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

func _scores(values: Array) -> void:
	run.round_scores.assign(values)

# --- Rundenpunkte ------------------------------------------------------------------

func test_a_fresh_run_has_no_values() -> void:
	assert_true(run.round_scores.is_empty())
	assert_false(run.has_typical_score())
	assert_eq(run.typical_score(), 0.0)
	assert_eq(run.cushion(150), 0.0, "kein Wert ohne Runde")
	assert_eq(run.score_growth(), 0.0)
	assert_eq(run.rounds_until_caught(), -1)

func test_advance_round_books_the_round_points_beside_the_blind() -> void:
	run.round_points = 420
	run.advance_round()
	assert_eq(run.round_scores, [420] as Array[int])
	assert_eq(run.round_scores.size(), run.blind_history.size(), "derselbe Index wie der Blind")
	assert_eq(run.round_points, 0, "die neue Runde beginnt bei null")
	run.round_points = 900
	run.advance_round()
	assert_eq(run.round_scores, [420, 900] as Array[int])

func test_one_round_is_its_own_typical_score() -> void:
	_scores([600])
	assert_almost_eq(run.typical_score(), 600.0, 0.001)
	assert_almost_eq(run.cushion(200), 3.0, 0.001)
	assert_eq(run.score_growth(), 0.0, "Trend erst ab zwei Runden")

func test_the_typical_score_is_the_geometric_mean_of_the_last_three() -> void:
	_scores([1, 100, 1000, 10000])
	assert_almost_eq(run.typical_score(), 1000.0, 0.01, "nur die letzten drei, geometrisch")

func test_zero_rounds_never_divide_by_zero() -> void:
	_scores([0, 0])
	assert_almost_eq(run.typical_score(), 1.0, 0.001, "Nullrunden zählen als 1")
	assert_almost_eq(run.score_growth(), 1.0, 0.001)
	_scores([0, 400])
	assert_almost_eq(run.score_growth(), 400.0, 0.01)

func test_the_score_growth_reads_the_last_four_rounds() -> void:
	_scores([1, 1000, 1100, 1210, 1331])
	assert_almost_eq(run.score_growth(), 1.1, 0.0001, "Verhältnisse 1,1 über die letzten vier")

func test_the_house_grows_by_the_next_step() -> void:
	assert_almost_eq(run.house_growth(), 1.0 + GameRun.blind_growth(run.round_number + 1), 0.0001)

func test_ahead_of_the_house_never_gets_caught() -> void:
	_scores([300, 600])
	assert_gt(run.score_growth(), run.house_growth())
	assert_eq(run.rounds_until_caught(), -1, "voraus")

func test_a_slower_player_gets_caught_after_the_estimated_rounds() -> void:
	run.round_scores.assign([1000, 1000, 1000])
	run.round_points = 1000
	run.advance_round()  # vier Runden zu 1000, kein Wachstum
	var pad := run.cushion(run.cushion_blind())
	var expected := ceili(log(pad) / log(run.house_growth()))
	assert_eq(run.rounds_until_caught(), expected)
	assert_gt(expected, 0)

func test_a_cushion_below_one_is_caught_already() -> void:
	_scores([100])
	run.round_points = 100
	run.advance_round()
	assert_lt(run.cushion(run.cushion_blind()), 1.0)
	assert_eq(run.rounds_until_caught(), 0)

func test_the_values_measure_the_blind_of_this_round() -> void:
	_scores([600])
	run.advance_round()
	assert_eq(run.cushion_blind(), run.effective_goal())

func test_the_hints_explain_without_data_and_with_it() -> void:
	assert_string_contains(run.round_average_hint(), "ersten geschafften Runde")
	assert_eq(run.round_average_hint().find("Polster"), -1)
	assert_string_contains(run.trend_hint(), "zwei geschafften Runden")
	_scores([300, 600])
	assert_string_contains(run.trend_hint(), "voraus")
	_scores([1000, 1000, 1000])
	assert_string_contains(run.trend_hint(), "bei diesem Tempo")

func test_the_margin_light_has_three_steps() -> void:
	assert_eq(GameRun.margin_of(0.0, 100), "", "ohne Schnitt kein Licht")
	assert_eq(GameRun.margin_of(151.0, 100), GameRun.MARGIN_GOOD)
	assert_eq(GameRun.margin_of(150.0, 100), GameRun.MARGIN_TIGHT)
	assert_eq(GameRun.margin_of(100.0, 100), GameRun.MARGIN_TIGHT)
	assert_eq(GameRun.margin_of(99.0, 100), GameRun.MARGIN_SHORT)

# --- Der Blind nach dem Deal --------------------------------------------------------

## Setzt die Klauseln einer Karte der Auslage von Hand.
func _card_with(index: int, bonus: Array, malus: Array) -> void:
	var card: Dictionary = run.route_offers[index]
	var bonus_ids: Array[String] = []
	bonus_ids.assign(bonus)
	var malus_ids: Array[String] = []
	malus_ids.assign(malus)
	card[GameRun.CARD_BONUS] = bonus_ids
	card[GameRun.CARD_MALUS] = malus_ids

func _assert_preview_books(index: int) -> void:
	var preview := run.blind_after_offer(index)
	assert_true(run.take_route(index))
	assert_eq(preview, run.effective_goal(), "die Vorschau ist die Buchung")

func test_a_plain_deal_previews_the_blind_of_this_round() -> void:
	run.advance_round()
	_card_with(1, [], [])
	assert_eq(run.blind_after_offer(1), run.effective_goal())
	_assert_preview_books(1)

func test_a_blind_raise_shows_in_the_preview() -> void:
	run.advance_round()
	_card_with(1, [], [DealClause.QUOTA_SHOCK])
	assert_gt(run.blind_after_offer(1), run.effective_goal())
	_assert_preview_books(1)

func test_calibration_and_surcharge_with_the_shyster() -> void:
	run.owned_charms.append(Charm.shyster())
	_card_with(2, [DealClause.CALIBRATION], [DealClause.USURY_CLAUSE])
	_assert_preview_books(2)

func test_a_round_wise_boss_raise_counts_in_the_preview() -> void:
	_card_with(0, [], [DealClause.HIGH_EXPECTATIONS])
	assert_gt(run.blind_after_offer(0), run.effective_goal() * 2)
	_assert_preview_books(0)

func test_the_route_state_carries_the_numbers_of_each_card() -> void:
	_scores([800])
	run.advance_round()
	var state := run.route_view_state()
	assert_eq((state["cards"] as Array).size(), GameRun.ROUTE_OFFER_COUNT)
	for card: Dictionary in state["cards"]:
		var after := run.blind_after_offer(int(card["index"]))
		assert_eq(int(card["blind_after"]), after)
		assert_almost_eq(float(card["typical"]), run.typical_score(), 0.0001)
		assert_eq(String(card["margin"]), GameRun.margin_of(run.typical_score(), after))

# --- Beste Hand ------------------------------------------------------------------------

func test_the_best_hand_keeps_the_highest_total() -> void:
	run.note_hand_counters({"total": 120})
	run.note_hand_counters({"total": 80})
	assert_eq(run.best_hand, 120)
	run.note_hand_counters({"total": 300})
	assert_eq(run.best_hand, 300)
