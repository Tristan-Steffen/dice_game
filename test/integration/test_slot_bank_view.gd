extends GutTest
## Tier-2-Integrationstests der Fumble-Automaten-Anzeige (SlotBankView mit echtem
## GameRun). Deterministisch über handgebaute Wände; die Walzen-Animation wird
## umgangen, indem die Landung (_on_reel_landed mit dem 3×3-Block) direkt gerufen
## wird. Die Auszahlung ist der PERLENZUG: gebucht wird je Preis bei seinem Abflug
## (prize_dispatched), und finish_payout_now ist die Ungeduld-Garantie.

const M := SlotPrize.Kind.MATERIAL
const S := SlotPrize.Kind.ENGRAVING
const C := SlotPrize.Kind.ENERGY
const F := SlotPrize.Kind.FUMBLE

## Das Fenster am Tisch: die hohe Spalte des Kombi-Clusters.
const WINDOW_SIZE := Vector2(900, 1400)

var view: SlotBankView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 200
	run.energy = 20  # Einsatz ist Energie
	run.hub_level = 9  # alle drei Automaten frei
	view = SlotBankView.new()
	view.size = WINDOW_SIZE
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
	assert_eq(view._face_labels[0][0].size(), SlotMachine.ROWS, "vier Zeilen je Spalte")

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

## Die Reihen-Zahlen, die cashed_out meldet, und die abgeflogenen Preise.
func _cashed() -> Array:
	var seen: Array = []
	view.cashed_out.connect(func(runs: int) -> void: seen.append(runs))
	return seen

func _dispatched() -> Array:
	var seen: Array = []
	view.prize_dispatched.connect(func(prize: SlotPrize, from_px: Vector2) -> void:
		seen.append({"prize": prize, "from_px": from_px}))
	return seen

func test_cash_out_redeems_runs_and_resets() -> void:
	# 3er-Zahlen-Reihe in Automat 0 → ein Zahlen-Paket, gebucht erst am Ende des
	# Perlenzugs der Reihe (beim Abflug ihres Lichts).
	_set_wall([[S, S, S, M, C, M, C, M, C]])
	view.refresh()
	await wait_frames(2)
	var money_before := run.money
	var packs_before := run.owned_packs.size()
	var seen := _cashed()
	var flown := _dispatched()
	view._on_cash_out_pressed()
	assert_eq(run.slot_bank.hit_count(), 0, "Sitzung sofort zurückgesetzt")
	assert_eq(run.owned_packs.size(), packs_before,
		"beim Klick ist noch nichts gebucht - der Perlenzug läuft erst")
	assert_eq(seen, [1], "die Zahl der Reihen verläßt das Fenster sofort")
	view.finish_payout_now()  # Ungeduld: bucht und verschickt alles Ausstehende
	assert_eq(run.owned_packs.size(), packs_before + 1, "Reihe als Paket gebucht")
	assert_eq(flown.size(), 1, "und ihr Licht ist abgeflogen")
	assert_gt((flown[0]["from_px"] as Vector2).length(), 0.0,
		"mit einem echten Abflug-Pixel")
	assert_eq(run.money, money_before, "der Automat zahlt KEIN Geld aus")

func test_the_pearl_train_books_every_prize_exactly_once() -> void:
	# Zwei Reihen (Zahlen + Material); der harte Abschluß bucht beide, ein zweiter
	# Abschluß bucht nichts doppelt.
	# Zweite Zeile ohne C im Wechseltakt - sonst stünde mit den Füllzeilen ein
	# senkrechtes ⚡-Tripel in Spalte 6 und die Wand trüge DREI Reihen.
	_set_wall([
		[S, S, S, M, C, M, C, M, C],
		[M, M, M, S, SlotPrize.Kind.DIE, S, SlotPrize.Kind.DIE, S, SlotPrize.Kind.DIE],
	])
	view.refresh()
	await wait_frames(2)
	assert_eq(run.slot_bank.hit_count(), 2, "genau die zwei gebauten Reihen")
	var packs_before := run.owned_packs.size()
	var flown := _dispatched()
	view._on_cash_out_pressed()
	view.finish_payout_now()
	assert_eq(run.owned_packs.size(), packs_before + 2, "beide Reihen gebucht")
	assert_eq(flown.size(), 2, "je Preis EIN Abflug")
	view.finish_payout_now()
	assert_eq(run.owned_packs.size(), packs_before + 2, "idempotent - nichts doppelt")
	assert_eq(flown.size(), 2)

func test_a_refresh_mid_payout_loses_no_prize() -> void:
	# Der Neuaufbau (Hub-Aufstieg, Laufwechsel) bringt die Auszahlung hart zu Ende.
	_set_wall([[S, S, S, M, C, M, C, M, C]])
	view.refresh()
	await wait_frames(2)
	var packs_before := run.owned_packs.size()
	view._on_cash_out_pressed()
	view.refresh()  # mitten im Perlenzug
	assert_eq(run.owned_packs.size(), packs_before + 1,
		"refresh bucht die ausstehenden Preise")

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
		for prize: SlotPrize in fresh.redeem_slots()["prizes"]:
			fresh.book_slot_prize(prize)
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

# --- Einwurf: die Energie fährt, dann läuft die Walze ----------------------------

func test_paying_the_stake_announces_the_coin() -> void:
	var paid: Array[int] = []
	view.spin_paid.connect(func(machine: int) -> void: paid.append(machine))
	var energy_before := run.energy
	var money_before := run.money
	view._on_spin_pressed(0)
	assert_eq(paid, [0] as Array[int], "der Einwurf meldet sich, damit das Licht losfährt")
	assert_eq(run.energy, energy_before - run.slot_spin_energy(0), "der Einsatz ist sofort weg")
	assert_eq(run.money, money_before, "Geld kostet der Dreh nicht")

func test_the_reel_waits_for_the_coin_to_arrive() -> void:
	view.coin_travel_time = 5.0  # so lang, dass sie im Test sicher nicht ankommt
	view._on_spin_pressed(0)
	await wait_frames(4)
	assert_true(view._landed[0].is_empty(), "ohne angekommene Energie dreht sich nichts")

func test_without_strips_the_reel_starts_at_once() -> void:
	# Fenster-UI-Rückfall (keine Adern verlegt): kein Warten, sonst hinge das Spiel.
	view.coin_travel_time = 0.0
	var landed: Array[int] = []
	view.spun_out.connect(func(machine: int, _f: bool) -> void: landed.append(machine))
	view._on_spin_pressed(0)
	await wait_frames(2)
	assert_eq(view._spinning_index, 0, "die Walze läuft ohne Umweg an")

# --- Bezahlbarkeit folgt der Energie (Wechsel auf den Automaten) -----------------

func test_refresh_if_idle_tracks_the_current_energy() -> void:
	# Beim letzten Aufbau leer -> gesperrt; nach Energiezuwachs macht refresh_if_idle
	# den Automaten wieder drehbar (sonst bliebe der Knopf grau, obwohl die ⚡ reicht).
	run.energy = 0
	view.refresh()
	await wait_frames(2)
	assert_true((view._spin_buttons[0] as Button).disabled, "leer: Drehen gesperrt")
	run.energy = 5
	view.refresh_if_idle()
	await wait_frames(2)
	assert_false((view._spin_buttons[0] as Button).disabled, "nach Energiezuwachs drehbar")

func test_refresh_if_idle_leaves_a_running_spin_untouched() -> void:
	await wait_frames(2)
	var before: Button = view._spin_buttons[0]
	view._spinning = true
	view.refresh_if_idle()
	assert_true(view._spin_buttons[0] == before, "laufende Walze: kein Neuaufbau")
	view._spinning = false

func test_a_second_cash_out_reports_nothing() -> void:
	_set_wall([[S, S, S, M, C, M, C, M, C]])
	view.refresh()
	await wait_frames(2)
	view._on_cash_out_pressed()
	var seen := _cashed()
	view._on_cash_out_pressed()  # mitten im laufenden Perlenzug: der Guard schluckt
	assert_eq(seen.size(), 0, "keine zweite Auszahlung, solange die erste läuft")
	view.finish_payout_now()
	view._on_cash_out_pressed()  # und die leere Sitzung zahlt ebenfalls nichts
	assert_eq(seen.size(), 0, "eine leere Sitzung zahlt nicht noch einmal aus")

func test_fresh_session_leaves_the_button_disabled() -> void:
	# Nichts gedreht: kein Verwerfen anzubieten, „Auszahlen" bleibt gesperrt.
	view.refresh()
	await wait_frames(2)
	var button := view._cash_out_button(9.0, false, 0)
	assert_true(button.disabled, "ohne Dreh kein aktiver Knopf")
	assert_eq(button.text, "Auszahlen")

# --- Die drei SPALTEN und ihre Melde-API ------------------------------------------

## Alle Beschriftungen des Fensters, flach.
func _texts(node: Node = null) -> Array[String]:
	var out: Array[String] = []
	for child in (node if node != null else view).get_children():
		if child is Label:
			out.append((child as Label).text)
		elif child is Button:
			out.append((child as Button).text)
		out.append_array(_texts(child))
	return out

func test_the_legend_names_energy_instead_of_a_charm() -> void:
	await wait_frames(2)
	var texts := _texts()
	assert_true(texts.has("Energie"), "die ⚡-Zeile heißt Energie")
	assert_false(texts.has("Charm"), "und der Charm ist restlos fort")
