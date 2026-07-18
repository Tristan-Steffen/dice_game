extends GutTest
## Tier-2-Integrationstests der Fumble-Automaten-Anzeige (SlotBankView mit echtem
## GameRun). Deterministisch über slot_bank.fumble_chance; die Walzen-Animation
## wird umgangen, indem die Landung (_on_reel_landed) direkt gerufen wird.

var view: SlotBankView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 200
	run.hub_level = 9  # alle drei Automaten frei
	run.slot_bank.fumble_chance = 0.0
	view = SlotBankView.new()
	view.size = Vector2(900, 1400)
	add_child_autofree(view)
	view.run = run
	view.refresh()

func test_builds_a_reel_per_machine() -> void:
	await wait_frames(2)
	assert_eq(view._reels.size(), SlotMachine.MACHINE_COUNT, "drei Walzen")

func test_locked_machines_cannot_be_spun() -> void:
	run.hub_level = 1  # kein Automat frei
	view.refresh()
	await wait_frames(2)
	assert_eq(run.slots_unlocked(), 0)
	assert_false(run.can_spin_slot(0), "gesperrter Automat nicht drehbar")

func test_landing_a_win_fills_the_pot() -> void:
	var prize := run.spin_slot(0)  # zahlt Einsatz, Treffer im slot_bank.pending
	view._on_reel_landed(0, prize)
	await wait_frames(2)
	assert_not_null(view._landed[0], "Walze zeigt den Gewinn")
	assert_eq(run.slot_bank.hit_count(), 1, "ein Gewinn im Topf")

func test_fumble_marks_the_session_busted() -> void:
	run.spin_slot(0)  # ein Treffer
	run.slot_bank.fumble_chance = 1.0
	var fumble := run.spin_slot(1)
	view._on_reel_landed(1, fumble)
	await wait_frames(2)
	assert_eq(fumble.kind, SlotPrize.Kind.FUMBLE)
	assert_true(run.slot_bank.busted)
	assert_eq(run.slot_bank.hit_count(), 0, "Topf verloren")

func test_cash_out_redeems_and_resets() -> void:
	var prize := run.spin_slot(0)
	view._on_reel_landed(0, prize)
	await wait_frames(2)
	var money_before := run.money
	view._on_cash_out_pressed()
	await wait_frames(2)
	assert_eq(run.slot_bank.hit_count(), 0, "Sitzung zurückgesetzt")
	assert_null(view._landed[0], "Walze wieder leer")
	if prize.kind == SlotPrize.Kind.MONEY:
		assert_eq(run.money, money_before + prize.money, "Bargewinn gutgeschrieben")

func test_new_session_after_a_bust() -> void:
	run.slot_bank.fumble_chance = 1.0
	var fumble := run.spin_slot(0)
	view._on_reel_landed(0, fumble)
	await wait_frames(2)
	assert_true(run.slot_bank.busted)
	view._on_cash_out_pressed()  # bei busted = „Neue Sitzung"
	await wait_frames(2)
	assert_false(run.slot_bank.busted, "Sitzung frisch")
	assert_true(run.can_spin_slot(0), "Automat wieder drehbar")
