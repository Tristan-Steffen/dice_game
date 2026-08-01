extends GutTest
## Tier-2-Integrationstests der Fumble-Automaten-Anzeige (SlotBankView mit echtem
## GameRun). Deterministisch über handgebaute Wände; die Walzen-Animation wird
## umgangen, indem die Landung (_on_reel_landed mit dem 3×3-Block) direkt gerufen
## wird.

const M := SlotPrize.Kind.MATERIAL
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
	# 3er-Zahlen-Reihe in Automat 0 → ein Zahlen-Paket ins Lager.
	_set_wall([[S, S, S, M, C, M, C, M, C]])
	view.refresh()
	await wait_frames(2)
	var money_before := run.money
	var packs_before := run.owned_packs.size()
	view._on_cash_out_pressed()
	await wait_frames(2)
	assert_eq(run.slot_bank.hit_count(), 0, "Sitzung zurückgesetzt")
	assert_eq(run.owned_packs.size(), packs_before,
		"während der Anzeige ist noch nichts gebucht")
	view.finish_payout_now()
	assert_eq(run.owned_packs.size(), packs_before + 1, "Reihe als Paket ausgezahlt")
	assert_eq(run.money, money_before, "der Automat zahlt KEIN Geld aus")

func test_each_engraving_symbol_pays_its_own_pack_kind() -> void:
	# Zahlen-, Material- und Würfel-Reihe zahlen je in ihrer eigenen Paketsorte.
	for entry in [[S, Pack.TYPE_NUMBER], [M, Pack.TYPE_MATERIAL],
			[SlotPrize.Kind.DICE_ENGRAVING, Pack.TYPE_DICE_MOD]]:
		var symbol: int = entry[0]
		var fresh := GameRun.new_run()
		fresh.hub_level = 9
		run = fresh          # _set_wall schreibt in die Wand von run
		view.run = fresh
		_set_wall([[symbol, symbol, symbol, C, F, C, F, C, F]])
		view.refresh()
		await wait_frames(2)
		view._on_cash_out_pressed()
		await wait_frames(2)
		view.finish_payout_now()  # Licht abfliegen lassen: DANN ist gebucht
		assert_gt(fresh.owned_packs.size(), 0, "Sorte %s zahlt aus" % entry[1])
		for pack in fresh.owned_packs:
			assert_eq(pack.type, String(entry[1]), "nur Pakete der eigenen Sorte")

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

func test_spun_without_a_win_can_reset_to_spin_again() -> void:
	# Gedreht, aber keine Reihe und kein Bust: der Spieler saß bisher fest. Der
	# Knopf verwirft die Wand und macht die Automaten wieder drehbar.
	_set_wall([])  # neutrale Wand, alle Automaten gedreht
	view.refresh()
	await wait_frames(2)
	assert_eq(run.slot_bank.hit_count(), 0, "keine Gewinn-Reihe")
	assert_false(run.slot_bank.busted, "auch kein Bust")
	assert_false(run.can_spin_slot(0), "vorher: Automat verbraucht")
	view._on_cash_out_pressed()
	await wait_frames(2)
	assert_true(run.can_spin_slot(0), "nachher: Automat wieder drehbar")
	assert_false(run.slot_bank.any_spun(), "Sitzung zurückgesetzt")

# --- Einwurf: die Münze fährt, dann läuft die Walze ------------------------------

func test_paying_the_stake_announces_the_coin() -> void:
	var paid: Array[int] = []
	view.spin_paid.connect(func(machine: int) -> void: paid.append(machine))
	var money_before := run.money
	view._on_spin_pressed(0)
	assert_eq(paid, [0] as Array[int], "der Einwurf meldet sich, damit das Licht losfährt")
	assert_eq(run.money, money_before - run.slot_spin_price(0), "der Einsatz ist sofort weg")

func test_the_reel_waits_for_the_coin_to_arrive() -> void:
	view.coin_travel_time = 5.0  # so lang, dass sie im Test sicher nicht ankommt
	view._on_spin_pressed(0)
	await wait_frames(4)
	assert_true(view._landed[0].is_empty(), "ohne angekommene Münze dreht sich nichts")

func test_without_strips_the_reel_starts_at_once() -> void:
	# Fenster-UI-Rückfall (keine Adern verlegt): kein Warten, sonst hinge das Spiel.
	view.coin_travel_time = 0.0
	var landed: Array[int] = []
	view.spun_out.connect(func(machine: int, _f: bool) -> void: landed.append(machine))
	view._on_spin_pressed(0)
	await wait_frames(2)
	assert_eq(view._spinning_index, 0, "die Walze läuft ohne Umweg an")

# --- Bezahlbarkeit folgt dem Geld (Wechsel auf den Automaten) --------------------

func test_refresh_if_idle_tracks_the_current_money() -> void:
	# Beim letzten Aufbau pleite -> gesperrt; nach Geldzuwachs macht refresh_if_idle
	# den Automaten wieder drehbar (sonst bliebe der Knopf grau, obwohl das Geld reicht).
	run.money = 0
	view.refresh()
	await wait_frames(2)
	assert_true((view._spin_buttons[0] as Button).disabled, "pleite: Drehen gesperrt")
	run.money = 100
	view.refresh_if_idle()
	await wait_frames(2)
	assert_false((view._spin_buttons[0] as Button).disabled, "nach Geldzuwachs drehbar")

func test_refresh_if_idle_leaves_a_running_spin_untouched() -> void:
	await wait_frames(2)
	var before: Button = view._spin_buttons[0]
	view._spinning = true
	view.refresh_if_idle()
	assert_true(view._spin_buttons[0] == before, "laufende Walze: kein Neuaufbau")
	view._spinning = false

# --- Gewinne verlassen das Fenster als Licht -------------------------------------

func _dispatched() -> Array:
	var seen: Array = []
	view.prize_dispatched.connect(func(prize: SlotPrize, from_px: Vector2) -> void:
		seen.append({"prize": prize, "from": from_px}))
	return seen

func test_every_prize_leaves_the_window_once() -> void:
	_set_wall([[S, S, S, M, C, M, C, M, C]])
	view.refresh()
	await wait_frames(2)
	var seen := _dispatched()
	view._on_cash_out_pressed()
	await wait_frames(2)
	assert_eq(seen.size(), 0, "während der Anzeige fliegt noch nichts")
	view.finish_payout_now()
	assert_gt(seen.size(), 0, "jeder Gewinn macht sich auf den Weg")
	for entry in seen:
		var from: Vector2 = entry["from"]
		assert_true(Rect2(view.position, view.size).has_point(from),
			"der Start liegt IM Automaten-Fenster")

func test_a_finished_payout_does_not_fire_again() -> void:
	_set_wall([[S, S, S, M, C, M, C, M, C]])
	view.refresh()
	await wait_frames(2)
	view._on_cash_out_pressed()
	await wait_frames(2)
	view.finish_payout_now()
	var booked := run.owned_packs.size()
	var seen := _dispatched()
	view.finish_payout_now()
	assert_eq(seen.size(), 0, "ein abgeschlossener Ablauf löst nichts nach")
	assert_eq(run.owned_packs.size(), booked, "und bucht auch nichts doppelt")

func test_a_run_swap_credits_the_run_that_won() -> void:
	# Neustart mitten in der Auszahlung: die Ware gehört dem alten Lauf.
	_set_wall([[S, S, S, M, C, M, C, M, C]])
	view.refresh()
	await wait_frames(2)
	var winner := run
	view._on_cash_out_pressed()
	await wait_frames(2)
	var next_run := GameRun.new_run()
	view.run = next_run
	view.finish_payout_now()
	assert_gt(winner.owned_packs.size(), 0, "der Gewinner bekommt seine Ware")
	assert_eq(next_run.owned_packs.size(), 0, "der neue Lauf erbt nichts")

func test_fresh_session_leaves_the_button_disabled() -> void:
	# Nichts gedreht: kein Verwerfen anzubieten, „Auszahlen" bleibt gesperrt.
	view.refresh()
	await wait_frames(2)
	var button := view._cash_out_button(9.0, false, 0)
	assert_true(button.disabled, "ohne Dreh kein aktiver Knopf")
	assert_eq(button.text, "Auszahlen")
