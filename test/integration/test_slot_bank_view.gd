extends GutTest
## Tier-2-Integrationstests der Fumble-Automaten-Anzeige (SlotBankView mit echtem
## GameRun). Deterministisch über handgebaute Wände; die Walzen-Animation wird
## umgangen, indem die Landung (_on_reel_landed mit dem 3×3-Block) direkt gerufen
## wird.

const M := SlotPrize.Kind.MONEY
const S := SlotPrize.Kind.ENGRAVING
const C := SlotPrize.Kind.CHARM
const F := SlotPrize.Kind.FUMBLE

var view: SlotBankView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 200
	run.hub_level = 9  # alle drei Automaten frei
	view = SlotBankView.new()
	view.size = Vector2(900, 1400)
	add_child_autofree(view)
	view.run = run
	view.refresh()

## Setzt eine Wand aus den gegebenen oberen Zeilen; Restzeilen im mod-4-Muster
## (bilden in KEINER Richtung eine Reihe). Markiert alle Automaten gedreht.
func _set_wall(rows_in: Array) -> void:
	var syms := [M, S, C, SlotPrize.Kind.DIE]
	for c in SlotMachine.TOTAL_COLS:
		var col: Array = []
		for r in SlotMachine.ROWS:
			if r < rows_in.size():
				col.append(rows_in[r][c])
			else:
				col.append(syms[(c + 2 * r) % 4])
		run.slot_bank.cells[c] = col
	run.slot_bank.spun = [true, true, true]

func test_builds_a_reel_window_per_machine() -> void:
	await wait_frames(2)
	assert_eq(view._reel_cols.size(), SlotMachine.MACHINE_COUNT, "drei Automaten")

func test_shows_three_by_three_symbol_labels() -> void:
	await wait_frames(2)
	assert_eq(view._face_labels[0].size(), SlotMachine.MACHINE_COLS, "drei Spalten")
	assert_eq(view._face_labels[0][0].size(), SlotMachine.ROWS, "drei Zeilen je Spalte")

func test_locked_machines_cannot_be_spun() -> void:
	run.hub_level = 1  # kein Automat frei
	view.refresh()
	await wait_frames(2)
	assert_eq(run.slots_unlocked(), 0)
	assert_false(run.can_spin_slot(0), "gesperrter Automat nicht drehbar")

func test_a_run_fills_the_pot() -> void:
	_set_wall([[M, M, M, S, C, S, C, S, C]])  # 3er-Reihe
	view.refresh()
	await wait_frames(2)
	assert_eq(run.slot_bank.hit_count(), 1, "eine Gewinn-Reihe im Topf")

func test_fumble_triple_marks_the_session_busted() -> void:
	run.slot_bank.fumble_chance = 1.0
	var block := run.spin_slot(0)  # drei Fumble-Spalten = 3er-Reihe
	view._on_reel_landed(0, block)
	await wait_frames(2)
	assert_true(run.slot_bank.busted)
	assert_eq(run.slot_bank.hit_count(), 0, "Topf verloren")

func test_cash_out_redeems_runs_and_resets() -> void:
	# 3er-Geld-Reihe in Automat 0 (Zellwert 1, Bonus 1.0 ⇒ $3).
	_set_wall([[M, M, M, S, C, S, C, S, C]])
	view.refresh()
	await wait_frames(2)
	var money_before := run.money
	view._on_cash_out_pressed()
	await wait_frames(2)
	assert_eq(run.slot_bank.hit_count(), 0, "Sitzung zurückgesetzt")
	assert_eq(run.money, money_before + 3, "Reihe ausgezahlt")

func test_new_session_after_a_bust() -> void:
	run.slot_bank.fumble_chance = 1.0
	var block := run.spin_slot(0)
	view._on_reel_landed(0, block)
	await wait_frames(2)
	assert_true(run.slot_bank.busted)
	view._on_cash_out_pressed()  # bei busted = „Neue Sitzung"
	await wait_frames(2)
	assert_false(run.slot_bank.busted, "Sitzung frisch")
	assert_true(run.can_spin_slot(0), "Automat wieder drehbar")
