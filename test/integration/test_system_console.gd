extends GutTest
## Tier-2-Tests der Systemkonsole: Chip wählen, Übertakten kauft die nächste
## Stufe über GameRun, ohne Geld bleibt der Knopf aus.

var console: SystemConsoleView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 100
	console = SystemConsoleView.new()
	console.size = Vector2(1000, 900)
	add_child_autofree(console)
	console.run = run
	console.open()

func test_open_builds_all_chips():
	assert_eq(console.chip_buttons.size(), DiceScoring.HAND_PRIORITY.size(), "je Kombination ein Chip")
	assert_true(console.visible)

func test_overclock_buys_next_stage():
	console.select_combo(DiceScoring.FULL_HOUSE)
	var price := run.overclock_price(DiceScoring.FULL_HOUSE)
	var before := run.money
	console._on_overclock_pressed()
	assert_eq(run.combo_level(DiceScoring.FULL_HOUSE), 1, "Stufe gekauft")
	assert_eq(run.money, before - price, "Preis abgezogen")

func test_price_rises_after_purchase():
	console.select_combo(DiceScoring.TWO_KIND)
	var first := run.overclock_price(DiceScoring.TWO_KIND)
	console._on_overclock_pressed()
	assert_eq(run.overclock_price(DiceScoring.TWO_KIND), first * 2, "nächste Stufe teurer")

func test_unaffordable_does_nothing():
	run.money = 0
	console.select_combo(DiceScoring.SIX_KIND)
	console._on_overclock_pressed()
	assert_eq(run.combo_level(DiceScoring.SIX_KIND), 0, "ohne Geld keine Stufe")
	assert_eq(run.money, 0)

func test_overclock_button_disabled_without_money():
	run.money = 0
	console.select_combo(DiceScoring.SIX_KIND)
	assert_true(console.overclock_button.disabled, "Kauf-Knopf aus ohne Geld")

func test_back_closes_page():
	console.visible = false
	assert_false(console.visible)
