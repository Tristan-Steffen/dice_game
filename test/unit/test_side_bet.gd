extends GutTest
## Tier-1-Tests der Nebenwetten (SideBet): Auslage-Erzeugung, Bedingungs-
## Auswertung gegen eine Rundenbilanz, Rang-Vergleich und Belohnung.

func _result(overrides: Dictionary = {}) -> Dictionary:
	var base := {
		"cleared": true, "best_combo_rank": -1, "best_hand_score": 0,
		"dice_taken": 0, "farkled": false,
	}
	for key in overrides:
		base[key] = overrides[key]
	return base

func _bet(id: String) -> SideBet:
	for t in SideBet.TEMPLATES:
		if t["id"] == id:
			return SideBet._from_template(t)
	return null

func test_roll_offers_returns_distinct_bets():
	var bets := SideBet.roll_offers(3)
	assert_eq(bets.size(), 3)
	var ids := {}
	for bet in bets:
		ids[bet.id] = true
	assert_eq(ids.size(), 3, "keine Dubletten in der Auslage")

func test_roll_offers_caps_at_template_count():
	assert_eq(SideBet.roll_offers(99).size(), SideBet.TEMPLATES.size())

func test_unwon_when_round_not_cleared():
	var bet := _bet("clean_run")
	assert_false(bet.evaluate(_result({"cleared": false, "farkled": false})),
		"verlorene Runde verliert jede Wette")

func test_combo_bet_needs_rank_or_better():
	var bet := _bet("full_house")
	var full_rank := SideBet.combo_rank(DiceScoring.FULL_HOUSE)
	assert_true(bet.evaluate(_result({"best_combo_rank": full_rank})), "genau Full House gewinnt")
	assert_true(bet.evaluate(_result({"best_combo_rank": SideBet.combo_rank(DiceScoring.SIX_KIND)})),
		"besser als Full House gewinnt")
	assert_false(bet.evaluate(_result({"best_combo_rank": SideBet.combo_rank(DiceScoring.TWO_PAIR)})),
		"schwächer als Full House verliert")

func test_combo_rank_orders_by_priority():
	assert_gt(SideBet.combo_rank(DiceScoring.SIX_KIND), SideBet.combo_rank(DiceScoring.FULL_HOUSE))
	assert_gt(SideBet.combo_rank(DiceScoring.TWO_PAIR), SideBet.combo_rank(DiceScoring.ONE_KIND))

func test_hand_score_bet():
	var bet := _bet("big_hand")
	assert_true(bet.evaluate(_result({"best_hand_score": 400})))
	assert_true(bet.evaluate(_result({"best_hand_score": 999})))
	assert_false(bet.evaluate(_result({"best_hand_score": 399})))

func test_few_dice_bet():
	var bet := _bet("economist")
	assert_true(bet.evaluate(_result({"dice_taken": 9})))
	assert_false(bet.evaluate(_result({"dice_taken": 10})))

func test_no_farkle_bet():
	var bet := _bet("clean_run")
	assert_true(bet.evaluate(_result({"farkled": false})))
	assert_false(bet.evaluate(_result({"farkled": true})))

func test_live_state_combo():
	var bet := _bet("full_house")
	assert_eq(bet.live_state(_result({"best_combo_rank": SideBet.combo_rank(DiceScoring.FULL_HOUSE)})),
		SideBet.Live.ON_TRACK, "Full House erreicht -> on track")
	assert_eq(bet.live_state(_result({"best_combo_rank": SideBet.combo_rank(DiceScoring.TWO_PAIR)})),
		SideBet.Live.PENDING, "schwächer -> noch offen (kein FAILED, kann noch kommen)")

func test_live_state_few_dice_fails_when_exceeded():
	var bet := _bet("economist")  # <= 9 Würfel
	assert_eq(bet.live_state(_result({"dice_taken": 9})), SideBet.Live.ON_TRACK)
	assert_eq(bet.live_state(_result({"dice_taken": 10})), SideBet.Live.FAILED, "zu viele Würfel -> verloren")

func test_live_state_no_farkle_fails_on_farkle():
	var bet := _bet("clean_run")
	assert_eq(bet.live_state(_result({"farkled": false})), SideBet.Live.ON_TRACK)
	assert_eq(bet.live_state(_result({"farkled": true})), SideBet.Live.FAILED)

func test_progress_fraction_hand_score():
	var bet := _bet("big_hand")  # 400
	assert_almost_eq(bet.progress_fraction(_result({"best_hand_score": 200})), 0.5, 0.01)
	assert_eq(bet.progress_fraction(_result({"best_hand_score": 800})), 1.0, "über Ziel gedeckelt")

func test_status_label_reads_progress():
	assert_eq(_bet("big_hand").status_label(_result({"best_hand_score": 260})), "260 / 400")
	assert_eq(_bet("economist").status_label(_result({"dice_taken": 6})), "6 / 9 Würfel")
	assert_eq(_bet("clean_run").status_label(_result({"farkled": false})), "sauber")

func test_reward_list_size_and_kinds():
	var bet := _bet("full_house")
	var rewards := bet.reward_list()
	assert_eq(rewards.size(), bet.reward_coupons)
	for coupon in rewards:
		assert_true(SideBet.REWARD_KINDS.has(coupon.kind), "Belohnung ist Ätzung/Material")

# --- Wett-Sorten (Geld/Sigill × Einsatz/Gewinn) ------------------------------

func test_templates_cover_all_four_quadrants():
	var seen := {}
	for t in SideBet.TEMPLATES:
		var bet := SideBet._from_template(t)
		seen["%d_%d" % [bet.stake_kind, bet.payout_kind]] = true
	assert_true(seen.has("%d_%d" % [SideBet.Stake.MONEY, SideBet.Payout.SIGILS]), "Geld -> Sigille")
	assert_true(seen.has("%d_%d" % [SideBet.Stake.MONEY, SideBet.Payout.MONEY]), "Geld -> Geld")
	assert_true(seen.has("%d_%d" % [SideBet.Stake.SIGILS, SideBet.Payout.MONEY]), "Sigill -> Geld")
	assert_true(seen.has("%d_%d" % [SideBet.Stake.SIGILS, SideBet.Payout.SIGILS]), "Sigill -> Sigille")

func test_money_stake_label():
	var bet := _bet("two_pair")
	assert_eq(bet.stake_kind, SideBet.Stake.MONEY)
	assert_eq(bet.stake_label(), "$%d" % bet.stake)

func test_sigil_stake_label_pluralizes():
	var bet := _bet("pawn")  # 1 Sigill
	assert_eq(bet.stake_kind, SideBet.Stake.SIGILS)
	assert_eq(bet.stake_label(), "1 Sigill")
	var two := _bet("collateral")  # 2 Sigille
	assert_eq(two.stake_label(), "2 Sigille")

func test_money_payout_reward_label():
	var bet := _bet("jackpot")
	assert_eq(bet.payout_kind, SideBet.Payout.MONEY)
	assert_eq(bet.reward_label(), "$%d" % bet.payout_money)

func test_sigil_payout_reward_label():
	var bet := _bet("full_house")
	assert_eq(bet.payout_kind, SideBet.Payout.SIGILS)
	assert_eq(bet.reward_label(), "%d×" % bet.reward_coupons)
