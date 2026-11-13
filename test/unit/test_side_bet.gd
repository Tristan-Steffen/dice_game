extends GutTest
## Tier-1-Tests der Nebenwetten (SideBet): Auslage-Erzeugung samt Stufen-Filter und
## Quota-Skalierung, Bedingungs-Auswertung gegen eine Rundenbilanz,
## Rang-Vergleich, Verfall und Etiketten.

## Höchste Freischalt-Stufe im Katalog - damit rollt jede Vorlage.
const TOP_TIER := 10

func _result(overrides: Dictionary = {}) -> Dictionary:
	var base := {
		"cleared": true, "best_combo_rank": -1, "best_hand_score": 0,
		"first_hand_score": 0, "dice_taken": 0, "farkled": false,
		"stages_cleared": 0, "distinct_combos": 0, "hands_taken": 0,
		"combo_repeated": false, "high_hand": false,
		"max_hand_dice": 0, "min_hand_dice": SideBet.FULL_HAND_DICE,
	}
	for key in overrides:
		base[key] = overrides[key]
	return base

func _bet(id: String, quota: int = 0) -> SideBet:
	for t in SideBet.TEMPLATES:
		if t["id"] == id:
			return SideBet._from_template(t, quota)
	return null

# --- Auslage: Stufen-Filter, Quota-Skalierung und das echte Inventar ----------

## Ein Magazin, das jede Paket-Einsatz-Vorlage tragen kann (die teuerste nimmt 2).
func _full_stock() -> Dictionary:
	var stock: Dictionary = {}
	for pack_type: String in Pack.SHELF_WEIGHTS:
		for tier in [Pack.TIER_NORMAL, Pack.TIER_GROSS, Pack.TIER_KOLOSSAL]:
			stock[SideBet.pack_stock_key(pack_type, tier)] = 4
	return stock

func test_roll_offers_returns_distinct_bets():
	var bets := SideBet.roll_offers(3, TOP_TIER, 400, _full_stock())
	assert_eq(bets.size(), 3)
	var ids := {}
	for bet in bets:
		ids[bet.id] = true
	assert_eq(ids.size(), 3, "keine Dubletten in der Auslage")

func test_roll_offers_caps_at_template_count():
	assert_eq(SideBet.roll_offers(99, TOP_TIER, 400, _full_stock()).size(),
		SideBet.TEMPLATES.size())

func test_roll_offers_filters_by_tier():
	var bets := SideBet.roll_offers(99, SideBet.UNLOCK_BASE, 400, _full_stock())
	assert_gt(bets.size(), 3, "die Grundstufe trägt genug Vorlagen")
	for bet in bets:
		assert_eq(bet.unlock_level, SideBet.UNLOCK_BASE, "keine höhere Stufe in der Auslage")

func test_roll_offers_opens_up_with_the_tier():
	var ids := {}
	for bet in SideBet.roll_offers(99, TOP_TIER, 400, _full_stock()):
		ids[bet.id] = true
	assert_true(ids.has("circuit_contract"), "Sonderposten-Wette ab Stufe 10 dabei")
	assert_true(ids.has("quick_start"), "Stufe-5-Wette dabei")

## OHNE passende Pakete erscheint keine Paket-Einsatz-Vorlage: der Tresen verlangt
## nichts, was der Spieler nicht hat.
func test_pack_stakes_stay_off_the_shelf_without_the_ware():
	for bet in SideBet.roll_offers(99, TOP_TIER, 400):
		assert_ne(bet.stake_kind, SideBet.Stake.PACKS,
			"%s dürfte ohne Magazin nicht ausliegen" % bet.id)

## Der falsche Typ hilft nicht, und die falsche ZAHL auch nicht - erst genug von
## einer Sorte macht die Vorlage auslegbar.
func test_a_pack_stake_needs_enough_of_ONE_named_sort():
	var thin: Dictionary = {SideBet.pack_stock_key(Pack.TYPE_NUMBER, Pack.TIER_NORMAL): 1}
	var seen := {}
	for bet in SideBet.roll_offers(99, TOP_TIER, 400, thin):
		if bet.stake_kind == SideBet.Stake.PACKS:
			seen[bet.id] = bet
			assert_eq(bet.stake_packs, 1, "nur die Ein-Paket-Vorlagen liegen aus")
			assert_eq(bet.stake_pack_type, Pack.TYPE_NUMBER, "und sie nennen den Besitz")
			assert_eq(bet.stake_pack_tier, Pack.TIER_NORMAL)
	assert_gt(seen.size(), 0, "ein passendes Paket genügt für die kleinen Vorlagen")
	var fat: Dictionary = {SideBet.pack_stock_key(Pack.TYPE_MATERIAL, Pack.TIER_GROSS): 2}
	var big := false
	for bet in SideBet.roll_offers(99, TOP_TIER, 400, fat):
		if bet.stake_kind == SideBet.Stake.PACKS and bet.stake_packs == 2:
			big = true
			assert_eq(bet.stake_pack_type, Pack.TYPE_MATERIAL)
			assert_eq(bet.stake_pack_tier, Pack.TIER_GROSS)
	assert_true(big, "zwei passende Pakete tragen auch die große Vorlage")

## Und die Auslage bleibt VOLL, solange der Katalog hergibt: eine ausgefallene
## Paket-Vorlage schiebt die nächste nach.
func test_a_skipped_pack_template_lets_the_next_one_move_up():
	for i in 20:
		assert_eq(SideBet.roll_offers(3, TOP_TIER, 400).size(), 3,
			"drei Angebote, auch ganz ohne Pakete im Magazin")

func test_nice_target_rounds_to_readable_numbers():
	assert_eq(SideBet._nice_target(390.0), 400, "unter 1000 auf 25er")
	assert_eq(SideBet._nice_target(412.0), 400)
	assert_eq(SideBet._nice_target(1137.0), 1100, "ab 1000 auf 100er")
	assert_eq(SideBet._nice_target(5.0), 25, "Mindestziel")

func test_scaled_target_follows_quota():
	var bet := _bet("big_hand", 525)  # Faktor 1.0
	assert_eq(bet.target, SideBet._nice_target(525.0))
	var whale := _bet("whale", 600)  # Faktor 2.5
	assert_eq(whale.target, SideBet._nice_target(1500.0))

func test_scaled_description_carries_the_number():
	var bet := _bet("big_hand", 400)
	assert_true(bet.description.contains("400"), "Ziel steht in der Beschreibung")
	assert_false(bet.description.contains("%"), "Formatstring ist gefüllt")

func test_offer_targets_are_frozen_at_roll_time():
	for bet in SideBet.roll_offers(99, TOP_TIER, 300):
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
	assert_gt(SideBet.combo_rank(DiceScoring.TWO_PAIR), SideBet.combo_rank(DiceScoring.TWO_KIND))

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

## Eine Wette mit fest gesetzter Ware - die Tests prüfen Mengen, nicht den Wurf.
func _with(id: String, kind: int, pack_type: String = Pack.TYPE_NUMBER) -> SideBet:
	var bet := _bet(id)
	bet.payout_kind = kind
	bet.reward_pack_type = pack_type
	return bet

# --- Der GEWINNWERT -------------------------------------------------------------

func test_every_template_carries_an_odds_class():
	var odds := [SideBet.ODDS_EASY, SideBet.ODDS_MEDIUM, SideBet.ODDS_HARD]
	for t in SideBet.TEMPLATES:
		assert_true(t.has("odds"), "%s nennt seine Quote" % t["id"])
		assert_true(odds.has(float(t["odds"])), "%s: eine der drei Quoten" % t["id"])
		assert_false(t.has("payout_money") or t.has("reward") or t.has("payout_energy"),
			"%s trägt keinen festen Gewinn mehr" % t["id"])

func test_stake_value_per_stake_kind():
	assert_eq(_bet("two_pair").stake_value(), 4, "Geld wie gedruckt")
	assert_eq(_bet("table_fee").stake_value(), 12, "$3 je Hand × 4 Hände")
	assert_eq(_bet("dice_toll").stake_value(), 10, "$1 je Würfel × 10 Würfel")
	assert_eq(_bet("feedback_loop").stake_value(), 40, "4 ⚡ × $10")
	var two := _bet("collateral")
	two.stake_pack_type = Pack.TYPE_MATERIAL
	two.stake_pack_tier = Pack.TIER_GROSS
	assert_eq(two.stake_value(), 26, "zwei Große Material-Karten zum Ladenpreis")

func test_payout_value_is_stake_times_odds_and_ware_bonus():
	var easy := _with("two_pair", SideBet.Payout.MONEY)
	assert_eq(easy.payout_value(), 8, "$4 × 2")
	easy.payout_kind = SideBet.Payout.PACKS
	assert_eq(easy.payout_value(), 10, "als Ware × 1,25")
	var medium := _with("jackpot", SideBet.Payout.MONEY)
	assert_eq(medium.payout_value(), 15, "$6 × 2,5")
	var hard := _with("shipment", SideBet.Payout.MONEY)
	assert_eq(hard.payout_value(), 30, "$10 × 3")
	assert_eq(hard.payout_value(2.0), 60, "der Faktor hebt den Wert")

func test_special_bets_keep_their_fixed_prize():
	for id in ["circuit_contract", "clean_room"]:
		for i in 10:
			var bet := _bet(id)
			assert_eq(bet.payout_kind, SideBet.Payout.SPECIAL, "%s würfelt nichts" % id)
			assert_true(Engraving.is_special_id(bet.special_id))

## Unter jedem Mindestwert bleibt nur Geld.
func test_ware_roll_respects_minimum_values():
	var cheap := {"id": "x", "condition": SideBet.Condition.CLEARED, "stake": 1,
		"odds": SideBet.ODDS_EASY, "name": "x", "desc": "x"}
	for i in 40:
		assert_eq(SideBet._from_template(cheap).payout_kind, SideBet.Payout.MONEY)
	var mid := {"id": "y", "condition": SideBet.Condition.CLEARED, "stake": 4,
		"odds": SideBet.ODDS_EASY, "name": "y", "desc": "y"}
	var kinds := {}
	for i in 400:
		var bet := SideBet._from_template(mid)
		kinds[bet.payout_kind] = true
		if bet.payout_kind == SideBet.Payout.CATALYST:
			assert_eq(bet.reward_item_id, Pack.CATALYST_COOL, "nur die Kühlrippe kostet ≤ $10")
		if bet.payout_kind == SideBet.Payout.PART:
			assert_true(bet.reward_part().price <= 10, "ein Modul bis zum Wert")
	assert_false(kinds.has(SideBet.Payout.OPERATOR), "Operatoren erst ab $11")
	assert_false(kinds.has(SideBet.Payout.PACK), "Sonderposten erst ab $18")
	assert_true(kinds.has(SideBet.Payout.MONEY) and kinds.has(SideBet.Payout.PACKS))

func test_ware_roll_never_pays_repair_or_blank():
	var rich := {"id": "z", "condition": SideBet.Condition.CLEARED, "stake": 30,
		"odds": SideBet.ODDS_HARD, "name": "z", "desc": "z"}
	for i in 300:
		var bet := SideBet._from_template(rich)
		for card in bet.reward_cards():
			assert_false(card.is_repair(), "keine Reparatur-Karte")
			assert_false(card.is_blank_card(), "kein Rohling")

## Größte Größe, die der Wert trägt; Anzahl = Wert / Preis, höchstens vier.
func test_card_amount_rule():
	var bet := _with("full_house", SideBet.Payout.PACKS, Pack.TYPE_MATERIAL)  # Ware $19
	assert_eq(bet.reward_tier(), Pack.TIER_GROSS)
	assert_eq(bet.reward_count(), 1)
	assert_eq(bet.reward_label(), "1 Große Material-Karte")
	var runes := _with("two_pair", SideBet.Payout.PACKS, Pack.TYPE_DICE_MOD)  # Ware $10
	assert_eq(runes.reward_label(), "1 Runen-Karte")
	var ship := _with("shipment", SideBet.Payout.PACKS)  # Ware $38
	assert_eq(ship.reward_label(), "2 Kolossale Zahlen-Karten")
	var whale := _with("whale", SideBet.Payout.PACKS)  # Ware $94
	assert_eq(whale.reward_count(), SideBet.MAX_REWARD_CARDS, "höchstens vier Karten")
	var cards := ship.reward_cards()
	assert_eq(cards.size(), 2)
	for card in cards:
		assert_eq(card.type, Pack.TYPE_NUMBER)
		assert_eq(card.tier, Pack.TIER_KOLOSSAL)

func test_multiplier_cards_follow_the_same_rule():
	var bet := _with("full_house", SideBet.Payout.MULTIPLIER)  # Ware $19
	assert_eq(bet.reward_label(), "2 Multiplikator-Karten")
	for card in bet.reward_cards():
		assert_true(card.is_multiplier())

## Die Karten stehen fest: dieselben bei jeder Frage, der Faktor legt nach.
func test_reward_cards_are_rolled_once():
	var bet := _with("full_house", SideBet.Payout.PACKS)
	var first := bet.reward_cards()
	assert_eq(bet.reward_cards(), first, "kein zweiter Wurf")

func test_payout_factor_lifts_every_ware():
	assert_eq(_with("jackpot", SideBet.Payout.MONEY).reward_label(2.0), "$30")
	var cards := _with("full_house", SideBet.Payout.PACKS)
	assert_eq(cards.reward_label(), "1 Kolossale Zahlen-Karte")
	assert_eq(cards.reward_label(2.0), "2 Kolossale Zahlen-Karten", "mehr Karten")
	var mats := _with("full_house", SideBet.Payout.PACKS, Pack.TYPE_MATERIAL)
	assert_eq(mats.reward_label(2.0), "1 Kolossale Material-Karte", "eine größere Karte")
	assert_eq(_with("feedback_loop", SideBet.Payout.ENERGY).reward_label(), "15 ⚡")
	assert_eq(_with("feedback_loop", SideBet.Payout.ENERGY).reward_label(2.0), "31 ⚡")
	assert_eq(_bet("circuit_contract").reward_label(2.0), "1 Pointer")
	assert_eq(_bet("clean_room").reward_label(2.0), "1 Veredelung")
	var patent := _with("patent", SideBet.Payout.PART)
	patent.reward_part_id = ComboPart.RELAY
	assert_eq(patent.reward_label(2.0), "1 Relais")

func test_catalyst_and_operator_labels():
	var cat := _with("full_house", SideBet.Payout.CATALYST)
	cat.reward_item_id = Pack.CATALYST_CHILL
	assert_eq(cat.reward_label(), "1 Kältebad")
	assert_true(cat.reward_cards()[0].is_cooling())
	var op := _with("shipment", SideBet.Payout.OPERATOR)
	op.reward_item_id = StampNet.OP_MIRROR
	assert_eq(op.reward_label(), "1 Spiegel")
	assert_true(op.pays_cards() and cat.pays_cards())

## Die Seele eines Wett-Würfels hängt am Wert.
func test_die_soul_follows_the_value():
	assert_eq(DiceOffer.bet_soul_rarity(11), -1)
	assert_eq(DiceOffer.bet_soul_rarity(12), Essence.Rarity.RARE)
	assert_eq(DiceOffer.bet_soul_rarity(20), Essence.Rarity.EPIC)
	assert_eq(DiceOffer.bet_soul_rarity(32), Essence.Rarity.LEGENDARY)
	for i in 20:
		var low := DiceOffer.roll_bet_die(9)
		if low.essence_id != "":
			assert_eq(Essence.by_id(low.essence_id).rarity, Essence.Rarity.COMMON,
				"unter $12 höchstens gewöhnlich")
		var top := DiceOffer.roll_bet_die(40)
		assert_eq(Essence.by_id(top.essence_id).rarity, Essence.Rarity.LEGENDARY)

func test_die_reward_is_named_and_stays():
	var bet := _with("shipment", SideBet.Payout.DIE)  # Ware $38: legendär
	var die := bet.reward_die()
	assert_not_null(die)
	assert_eq(bet.reward_die(), die, "ein Würfel, einmal gewürfelt")
	assert_eq(bet.reward_label(), "1 %s" % SideBet.die_name(die))
	assert_true(bet.reward_label().contains(" · "), "der Knopf nennt die Seele")
	assert_false(bet.pays_cards())

# --- Wett-Sorten und Etiketten --------------------------------------------------

func test_templates_cover_money_and_pack_stakes():
	var seen := {}
	for t in SideBet.TEMPLATES:
		seen[int(t.get("stake_kind", SideBet.Stake.MONEY))] = true
	assert_true(seen.has(SideBet.Stake.MONEY) and seen.has(SideBet.Stake.PACKS))
	assert_true(seen.has(SideBet.Stake.ENERGY) and seen.has(SideBet.Stake.MONEY_PER_HAND))

func test_template_ids_are_unique():
	var ids := {}
	for t in SideBet.TEMPLATES:
		var id: String = t["id"]
		assert_false(ids.has(id), "doppelte Vorlagen-id: %s" % id)
		ids[id] = true

func test_money_stake_label():
	var bet := _bet("two_pair")
	assert_eq(bet.stake_kind, SideBet.Stake.MONEY)
	assert_eq(bet.stake_label(), "$%d" % bet.stake)
	assert_eq(bet.stake_label(1.5), "$6", "Hoher Tisch rundet auf")

## Der Einsatz NENNT seine Ware: Zahl, Größe, Sorte. Aus den EINEN Namensquellen
## (Pack.TYPE_NAMES + tier_adjective) - eine zweite Formulierung gibt es nicht.
func test_pack_stake_label_names_type_and_size():
	var bet := _bet("pawn")  # 1 Paket
	assert_eq(bet.stake_kind, SideBet.Stake.PACKS)
	bet.stake_pack_type = Pack.TYPE_MATERIAL
	bet.stake_pack_tier = Pack.TIER_NORMAL
	assert_eq(bet.stake_label(), "1 Material-Karte")
	var two := _bet("collateral")  # 2 Pakete
	two.stake_pack_type = Pack.TYPE_MATERIAL
	two.stake_pack_tier = Pack.TIER_GROSS
	assert_eq(two.stake_label(), "2 Große Material-Karten")
	assert_eq(two.stake_label(),
		Pack.amount_phrase(Pack.TYPE_MATERIAL, Pack.TIER_GROSS, 2),
		"und zwar aus der EINEN Quelle")

func test_tax_and_energy_stake_labels():
	assert_eq(_bet("table_fee").stake_label(), "$3 je Hand")
	assert_eq(_bet("dice_toll").stake_label(), "$1 je Würfel")
	assert_eq(_bet("feedback_loop").stake_label(), "4 ⚡")
	assert_eq(_bet("table_fee").stake_label(2.0), "$6 je Hand", "Wettsteuer verdoppelt auch die Gebühr")
