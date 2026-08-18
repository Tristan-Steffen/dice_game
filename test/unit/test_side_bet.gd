extends GutTest
## Tier-1-Tests der Nebenwetten (SideBet): Auslage-Erzeugung samt Hub-Filter und
## Benchmark-Skalierung, Bedingungs-Auswertung gegen eine Rundenbilanz,
## Rang-Vergleich, Verfall und Etiketten.

## Höchste Freischalt-Stufe im Katalog - damit rollt jede Vorlage.
const TOP_HUB := 10

func _result(overrides: Dictionary = {}) -> Dictionary:
	var base := {
		"cleared": true, "best_combo_rank": -1, "best_hand_score": 0,
		"first_hand_score": 0, "dice_taken": 0, "farkled": false,
		"stages_cleared": 0, "distinct_combos": 0, "hands_taken": 0,
		"combo_repeated": false, "fallback_taken": false, "high_hand": false,
		"max_hand_dice": 0, "min_hand_dice": SideBet.FULL_HAND_DICE,
	}
	for key in overrides:
		base[key] = overrides[key]
	return base

func _bet(id: String, benchmark: int = 0) -> SideBet:
	for t in SideBet.TEMPLATES:
		if t["id"] == id:
			return SideBet._from_template(t, benchmark)
	return null

# --- Auslage: Hub-Filter und Benchmark-Skalierung -----------------------------

func test_roll_offers_returns_distinct_bets():
	var bets := SideBet.roll_offers(3, TOP_HUB, 400)
	assert_eq(bets.size(), 3)
	var ids := {}
	for bet in bets:
		ids[bet.id] = true
	assert_eq(ids.size(), 3, "keine Dubletten in der Auslage")

func test_roll_offers_caps_at_template_count():
	assert_eq(SideBet.roll_offers(99, TOP_HUB, 400).size(), SideBet.TEMPLATES.size())

func test_roll_offers_filters_by_hub_level():
	var bets := SideBet.roll_offers(99, SideBet.UNLOCK_BASE, 400)
	assert_gt(bets.size(), 3, "die Grundstufe trägt genug Vorlagen")
	for bet in bets:
		assert_eq(bet.unlock_level, SideBet.UNLOCK_BASE, "keine höhere Stufe in der Auslage")

func test_roll_offers_opens_up_with_hub_level():
	var ids := {}
	for bet in SideBet.roll_offers(99, TOP_HUB, 400):
		ids[bet.id] = true
	assert_true(ids.has("circuit_contract"), "Sonderposten-Wette ab Stufe 10 dabei")
	assert_true(ids.has("quick_start"), "Salon-Wette dabei")

func test_nice_target_rounds_to_readable_numbers():
	assert_eq(SideBet._nice_target(390.0), 400, "unter 1000 auf 25er")
	assert_eq(SideBet._nice_target(412.0), 400)
	assert_eq(SideBet._nice_target(1137.0), 1100, "ab 1000 auf 100er")
	assert_eq(SideBet._nice_target(5.0), 25, "Mindestziel")

func test_scaled_target_follows_benchmark():
	var bet := _bet("big_hand", 525)  # Faktor 1.0
	assert_eq(bet.target, SideBet._nice_target(525.0))
	var whale := _bet("whale", 600)  # Faktor 2.5
	assert_eq(whale.target, SideBet._nice_target(1500.0))

func test_scaled_description_carries_the_number():
	var bet := _bet("big_hand", 400)
	assert_true(bet.description.contains("400"), "Ziel steht in der Beschreibung")
	assert_false(bet.description.contains("%"), "Formatstring ist gefüllt")

func test_offer_targets_are_frozen_at_roll_time():
	for bet in SideBet.roll_offers(99, TOP_HUB, 300):
		if bet.target_factor > 0.0:
			assert_eq(bet.target, SideBet._nice_target(300.0 * bet.target_factor))

# --- Bedingungen: Bestand -----------------------------------------------------

func test_unwon_when_round_not_cleared():
	var bet := _bet("clean_run")
	assert_false(bet.evaluate(_result({"cleared": false, "farkled": false})),
		"verlorene Runde verliert jede Wette")

func test_voided_bet_always_loses():
	var bet := _bet("table_fee")
	assert_true(bet.evaluate(_result()), "bezahlte Steuerwette gewinnt mit der Runde")
	bet.voided = true
	assert_false(bet.evaluate(_result()), "zahlungsunfähig = verloren")
	assert_eq(bet.live_state(_result()), SideBet.Live.FAILED)

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
	var bet := _bet("big_hand", 400)
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

# --- Bedingungen: neue Sorten -------------------------------------------------

func test_first_hand_bet():
	var bet := _bet("quick_start", 500)  # Faktor 0.6 -> 300
	assert_eq(bet.target, 300)
	assert_true(bet.evaluate(_result({"first_hand_score": 300, "hands_taken": 2})))
	assert_false(bet.evaluate(_result({"first_hand_score": 299, "best_hand_score": 900,
		"hands_taken": 2})), "eine spätere Hand rettet nichts")

func test_first_hand_live_state_decides_after_the_first_hand():
	var bet := _bet("quick_start", 500)
	assert_eq(bet.live_state(_result()), SideBet.Live.PENDING, "vor der ersten Hand offen")
	assert_eq(bet.live_state(_result({"hands_taken": 1, "first_hand_score": 300})),
		SideBet.Live.ON_TRACK)
	assert_eq(bet.live_state(_result({"hands_taken": 1, "first_hand_score": 120})),
		SideBet.Live.FAILED, "zu schwache erste Hand ist endgültig")

func test_overcharge_bet():
	var bet := _bet("overclocker")  # 2 Stufen
	assert_true(bet.evaluate(_result({"stages_cleared": 2})))
	assert_false(bet.evaluate(_result({"stages_cleared": 1})))
	assert_eq(bet.live_state(_result({"stages_cleared": 1})), SideBet.Live.PENDING)
	assert_eq(bet.live_state(_result({"stages_cleared": 3})), SideBet.Live.ON_TRACK)

func test_distinct_combos_bet():
	var bet := _bet("connoisseur")  # 3 Sorten
	assert_true(bet.evaluate(_result({"distinct_combos": 3})))
	assert_false(bet.evaluate(_result({"distinct_combos": 2})))
	assert_eq(bet.live_state(_result({"distinct_combos": 2})), SideBet.Live.PENDING)

func test_hand_limit_bet():
	var bet := _bet("efficiency")  # <= 3 Hände
	assert_true(bet.evaluate(_result({"hands_taken": 3})))
	assert_false(bet.evaluate(_result({"hands_taken": 4})))
	assert_eq(bet.live_state(_result({"hands_taken": 3})), SideBet.Live.ON_TRACK)
	assert_eq(bet.live_state(_result({"hands_taken": 4})), SideBet.Live.FAILED)

func test_comeback_bet_needs_a_farkle():
	var bet := _bet("comeback")
	assert_true(bet.evaluate(_result({"farkled": true})))
	assert_false(bet.evaluate(_result({"farkled": false})), "ohne Farkle kein Comeback")
	assert_eq(bet.live_state(_result({"farkled": false})), SideBet.Live.PENDING)
	assert_eq(bet.live_state(_result({"farkled": true})), SideBet.Live.ON_TRACK)

func test_high_dice_bet():
	var bet := _bet("upper_class")
	assert_true(bet.evaluate(_result({"high_hand": true})))
	assert_false(bet.evaluate(_result({"high_hand": false})))
	assert_eq(bet.live_state(_result({"high_hand": false})), SideBet.Live.PENDING)

func test_cleared_bet_only_needs_the_round():
	var bet := _bet("dice_toll")
	assert_true(bet.evaluate(_result()))
	assert_false(bet.evaluate(_result({"cleared": false})))
	assert_eq(bet.live_state(_result()), SideBet.Live.ON_TRACK)

func test_max_hand_dice_bet():
	var bet := _bet("small_fry")  # keine Hand > 3 Würfel
	assert_true(bet.evaluate(_result({"max_hand_dice": 3})))
	assert_false(bet.evaluate(_result({"max_hand_dice": 4})))
	assert_eq(bet.live_state(_result({"max_hand_dice": 4})), SideBet.Live.FAILED)

func test_full_hands_bet():
	var bet := _bet("full_grip")
	assert_true(bet.evaluate(_result({"hands_taken": 2, "min_hand_dice": 6})))
	assert_false(bet.evaluate(_result({"hands_taken": 2, "min_hand_dice": 5})))
	assert_false(bet.evaluate(_result({"hands_taken": 0, "min_hand_dice": 99})),
		"ohne genommene Hand kein Vollgriff")
	assert_eq(bet.live_state(_result({"min_hand_dice": 5})), SideBet.Live.FAILED)
	assert_eq(bet.live_state(_result({"min_hand_dice": 99})), SideBet.Live.ON_TRACK)

func test_no_repeat_bet():
	var bet := _bet("variety")
	assert_true(bet.evaluate(_result({"combo_repeated": false})))
	assert_false(bet.evaluate(_result({"combo_repeated": true})))
	assert_eq(bet.live_state(_result({"combo_repeated": true})), SideBet.Live.FAILED)

func test_no_fallback_bet():
	var bet := _bet("no_scraps")
	assert_true(bet.evaluate(_result({"fallback_taken": false})))
	assert_false(bet.evaluate(_result({"fallback_taken": true})))
	assert_eq(bet.live_state(_result({"fallback_taken": true})), SideBet.Live.FAILED)

# --- Anzeige ------------------------------------------------------------------

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
	var bet := _bet("big_hand", 400)
	assert_almost_eq(bet.progress_fraction(_result({"best_hand_score": 200})), 0.5, 0.01)
	assert_eq(bet.progress_fraction(_result({"best_hand_score": 800})), 1.0, "über Ziel gedeckelt")

func test_progress_fraction_is_binary_for_flag_conditions():
	assert_eq(_bet("variety").progress_fraction(_result({"combo_repeated": true})), 0.0)
	assert_eq(_bet("variety").progress_fraction(_result({"combo_repeated": false})), 1.0)
	assert_eq(_bet("upper_class").progress_fraction(_result({"high_hand": true})), 1.0)

func test_status_label_reads_progress():
	assert_eq(_bet("big_hand", 400).status_label(_result({"best_hand_score": 260})), "260 / 400")
	assert_eq(_bet("economist").status_label(_result({"dice_taken": 6})), "6 / 9 Würfel")
	assert_eq(_bet("clean_run").status_label(_result({"farkled": false})), "sauber")
	assert_eq(_bet("overclocker").status_label(_result({"stages_cleared": 1})), "1 / 2 Stufen")
	assert_eq(_bet("efficiency").status_label(_result({"hands_taken": 2})), "2 / 3 Hände")

func test_reward_list_size_and_kinds():
	var bet := _bet("full_house")
	var rewards := bet.reward_list()
	assert_eq(rewards.size(), bet.reward_packs)
	for pack in rewards:
		assert_true(Pack.SHELF_WEIGHTS.has(pack.type), "Belohnung ist Regal-Ware")
		assert_eq(pack.count, Pack.ENGRAVING_PACK_COUNT, "je ein Phantomwürfel")

# --- Wett-Sorten (Geld/Paket × Einsatz/Gewinn) ------------------------------

func test_templates_cover_all_four_quadrants():
	var seen := {}
	for t in SideBet.TEMPLATES:
		var bet := SideBet._from_template(t)
		seen["%d_%d" % [bet.stake_kind, bet.payout_kind]] = true
	assert_true(seen.has("%d_%d" % [SideBet.Stake.MONEY, SideBet.Payout.PACKS]), "Geld -> Pakete")
	assert_true(seen.has("%d_%d" % [SideBet.Stake.MONEY, SideBet.Payout.MONEY]), "Geld -> Geld")
	assert_true(seen.has("%d_%d" % [SideBet.Stake.PACKS, SideBet.Payout.MONEY]), "Paket -> Geld")
	assert_true(seen.has("%d_%d" % [SideBet.Stake.PACKS, SideBet.Payout.PACKS]), "Paket -> Pakete")

func test_template_ids_are_unique():
	var ids := {}
	for t in SideBet.TEMPLATES:
		var id: String = t["id"]
		assert_false(ids.has(id), "doppelte Vorlagen-id: %s" % id)
		ids[id] = true

func test_special_payouts_name_a_known_engraving():
	for t in SideBet.TEMPLATES:
		var bet := SideBet._from_template(t)
		if bet.payout_kind != SideBet.Payout.SPECIAL:
			continue
		assert_true(Engraving.is_special_id(bet.special_id), "%s zahlt einen Sonderposten" % bet.id)
		assert_not_null(bet.special_engraving(), "%s findet seine Gravur" % bet.id)

func test_money_stake_label():
	var bet := _bet("two_pair")
	assert_eq(bet.stake_kind, SideBet.Stake.MONEY)
	assert_eq(bet.stake_label(), "$%d" % bet.stake)

func test_pack_stake_label_pluralizes():
	var bet := _bet("pawn")  # 1 Paket
	assert_eq(bet.stake_kind, SideBet.Stake.PACKS)
	assert_eq(bet.stake_label(), "1 Paket")
	var two := _bet("collateral")  # 2 Pakete
	assert_eq(two.stake_label(), "2 Pakete")

func test_tax_and_charge_stake_labels():
	assert_eq(_bet("table_fee").stake_label(), "$3 je Hand")
	assert_eq(_bet("dice_toll").stake_label(), "$1 je Würfel")
	assert_eq(_bet("feedback_loop").stake_label(), "4 ⚡")
	assert_eq(_bet("table_fee").stake_label(2), "$6 je Hand", "Wettsteuer verdoppelt auch die Gebühr")

func test_money_payout_reward_label():
	var bet := _bet("jackpot")
	assert_eq(bet.payout_kind, SideBet.Payout.MONEY)
	assert_eq(bet.reward_label(), "$%d" % bet.payout_money)

func test_pack_payout_reward_label_pluralizes():
	var single := _bet("two_pair")  # 1 Paket Gewinn
	assert_eq(single.payout_kind, SideBet.Payout.PACKS)
	assert_eq(single.reward_label(), "1 Paket")
	var many := _bet("full_house")  # 2 Pakete Gewinn
	assert_eq(many.reward_label(), "2 Pakete")

func test_new_payout_reward_labels():
	assert_eq(_bet("feedback_loop").reward_label(), "8 ⚡")
	assert_eq(_bet("shipment").reward_label(), "1 Paket")
	assert_eq(_bet("patent").reward_label(), "+1 Stufe")
	assert_eq(_bet("circuit_contract").reward_label(), "1 Pointer")
	assert_eq(_bet("clean_room").reward_label(), "1 Veredelung")

## Der Quotenbonus (×2) verdoppelt Geld, Ware und Ladung - Einzelstücke nicht.
func test_payout_factor_spares_unique_goods():
	assert_eq(_bet("jackpot").reward_label(2), "$36")
	assert_eq(_bet("full_house").reward_label(2), "4 Pakete")
	assert_eq(_bet("feedback_loop").reward_label(2), "16 ⚡")
	assert_eq(_bet("circuit_contract").reward_label(2), "1 Pointer")
	assert_eq(_bet("clean_room").reward_label(2), "1 Veredelung")
	assert_eq(_bet("shipment").reward_label(2), "1 Paket")
	assert_eq(_bet("patent").reward_label(2), "+1 Stufe")
