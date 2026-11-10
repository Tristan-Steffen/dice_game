extends GutTest
## Die Gewinn-Karten einer Wette stehen ab dem Auslegen fest: die Grube zeigt genau,
## was die Abrechnung gewährt.

func _bet(id: String, kind: int) -> SideBet:
	for t: Dictionary in SideBet.TEMPLATES:
		if t["id"] == id:
			var bet := SideBet._from_template(t)
			bet.payout_kind = kind
			bet.reward_pack_type = Pack.TYPE_NUMBER
			return bet
	return null

func test_the_cards_are_rolled_once() -> void:
	var bet := _bet("large_straight", SideBet.Payout.PACKS)
	var first := bet.reward_cards()
	assert_gt(first.size(), 0)
	assert_eq(bet.reward_cards(), first, "dieselben Karten, kein zweiter Wurf")

func test_the_won_cards_are_the_shown_cards() -> void:
	var run := GameRun.new_run()
	run.money = 100
	var bet := _bet("large_straight", SideBet.Payout.PACKS)
	var shown := bet.reward_cards(run.side_bet_payout_factor())
	run.place_side_bet(bet)
	run.resolve_side_bets({"cleared": true,
		"best_combo_rank": SideBet.combo_rank(DiceScoring.LARGE_STRAIGHT)})
	assert_eq(bet.awarded_packs.size(), shown.size())
	for i in shown.size():
		assert_same(bet.awarded_packs[i], shown[i], "Karte %d ist die aus der Grube" % i)

func test_only_card_bets_lie_as_cards() -> void:
	assert_true(_bet("large_straight", SideBet.Payout.PACKS).pays_cards())
	assert_true(_bet("large_straight", SideBet.Payout.MULTIPLIER).pays_cards())
	assert_true(_bet("large_straight", SideBet.Payout.PACK).pays_cards())
	assert_false(_bet("jackpot", SideBet.Payout.MONEY).pays_cards())
	assert_false(_bet("chain_reaction", SideBet.Payout.PART).pays_cards())
	assert_false(_bet("chain_reaction", SideBet.Payout.DIE).pays_cards())
