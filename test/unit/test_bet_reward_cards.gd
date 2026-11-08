extends GutTest
## Die Gewinn-Karten einer Wette stehen ab dem Auslegen fest: die Grube zeigt genau,
## was die Abrechnung gewährt.

func _template(id: String) -> Dictionary:
	for t: Dictionary in SideBet.TEMPLATES:
		if t["id"] == id:
			return t
	return {}

func test_the_cards_are_rolled_once() -> void:
	var bet := SideBet._from_template(_template("large_straight"))
	var first := bet.reward_cards(3)
	assert_eq(first.size(), 3)
	assert_eq(bet.reward_cards(3), first, "dieselben Karten, kein zweiter Wurf")
	assert_eq(bet.reward_cards(5).slice(0, 3), first, "der Quotenbonus legt nur nach")

func test_the_won_cards_are_the_shown_cards() -> void:
	var run := GameRun.new_run()
	run.money = 100
	var bet := SideBet._from_template(_template("large_straight"))
	var shown := bet.reward_cards(bet.reward_packs)
	run.place_side_bet(bet)
	run.resolve_side_bets({"cleared": true,
		"best_combo_rank": SideBet.combo_rank(DiceScoring.LARGE_STRAIGHT)})
	assert_eq(bet.awarded_packs.size(), shown.size())
	for i in shown.size():
		assert_same(bet.awarded_packs[i], shown[i], "Karte %d ist die aus der Grube" % i)

func test_only_card_bets_lie_as_cards() -> void:
	assert_true(SideBet._from_template(_template("large_straight")).pays_cards())
	assert_true(SideBet._from_template(_template("circuit_contract")).pays_cards())
	assert_false(SideBet._from_template(_template("jackpot")).pays_cards())
	assert_false(SideBet._from_template(_template("chain_reaction")).pays_cards())
