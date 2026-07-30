extends GutTest
## Tier-2-Tests des Tisch-Wettfensters (SideBetPanel): Wett-Modus platziert
## Wetten gegen einen echten GameRun, nach dem Schließen wird nichts mehr gesetzt.

var panel: SideBetPanel
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 100
	run.hub_level = GameRun.HUB_SIDE_BETS_LEVEL  # darunter liegt gar keine Wette aus
	panel = SideBetPanel.new()
	panel.size = Vector2(1000, 600)
	add_child_autofree(panel)  # löst _ready aus
	panel.run = run

func _offers() -> Array[SideBet]:
	return SideBet.roll_offers(SideBetPanel.OFFER_COUNT, run.hub_level, run.round_goal)

## Deterministische Geld-Auslage (index 0 = Geld-Einsatz), damit die Setz-Tests
## nicht an einer zufällig gezogenen Gravur-Wette scheitern.
func _money_offers() -> Array[SideBet]:
	var bets: Array[SideBet] = []
	for id in ["two_pair", "big_hand", "economist"]:
		for t in SideBet.TEMPLATES:
			if t["id"] == id:
				bets.append(SideBet._from_template(t))
	return bets

func test_open_betting_sets_mode_and_offers():
	panel.open_betting(_offers())
	assert_eq(panel.mode, SideBetPanel.Mode.BETTING)
	assert_eq(panel.offers.size(), SideBetPanel.OFFER_COUNT)

func test_place_bet_deducts_and_registers():
	var offers := _money_offers()
	panel.open_betting(offers)
	var before := run.money
	panel._on_bet_pressed(0)
	assert_eq(run.money, before - offers[0].stake, "Einsatz abgezogen")
	assert_eq(run.active_side_bets.size(), 1, "Wette registriert")
	assert_true(panel.placed[0])

func test_place_engraving_stake_bet_consumes_engraving():
	run.grant_engraving(Engraving.chisel())
	var pawn: Array[SideBet] = []
	for t in SideBet.TEMPLATES:
		if t["id"] == "pawn":  # 1 Gravur Einsatz
			pawn.append(SideBet._from_template(t))
	panel.open_betting(pawn)
	panel._on_bet_pressed(0)
	assert_eq(run.owned_engravings.size(), 0, "Gravur als Einsatz geopfert")
	assert_eq(run.active_side_bets.size(), 1, "Gravur-Wette registriert")

func test_cannot_place_twice():
	panel.open_betting(_money_offers())
	panel._on_bet_pressed(0)
	var money_after := run.money
	panel._on_bet_pressed(0)
	assert_eq(run.money, money_after, "zweiter Klick tut nichts")
	assert_eq(run.active_side_bets.size(), 1)

func test_cannot_place_after_close():
	panel.open_betting(_offers())
	panel.close_betting()
	assert_eq(panel.mode, SideBetPanel.Mode.PROGRESS)
	panel._on_bet_pressed(0)
	assert_eq(run.active_side_bets.size(), 0, "nach dem ersten Wurf keine Wette mehr")

func test_unaffordable_not_placed():
	run.money = 0
	panel.open_betting(_offers())
	panel._on_bet_pressed(0)
	assert_eq(run.active_side_bets.size(), 0, "ohne Geld keine Wette")

func test_progress_mode_reads_active_bets():
	var offers := _offers()
	panel.open_betting(offers)
	panel._on_bet_pressed(0)
	panel.close_betting()
	panel.update_progress({"best_combo_rank": -1, "best_hand_score": 0, "dice_taken": 0, "farkled": false})
	# Kein Absturz und Modus bleibt Fortschritt.
	assert_eq(panel.mode, SideBetPanel.Mode.PROGRESS)
