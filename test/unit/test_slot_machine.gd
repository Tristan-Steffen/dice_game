extends GutTest
## Tests der Fumble-Automaten-Logik (SlotMachine): 5×9-Symbol-Wand, Reihen-Erkennung
## in ALLEN Richtungen (waagerecht, senkrecht, beide Diagonalen; 3+ gleiche, über
## Automaten-Grenzen), Längen-Bonus, Fumble-Paar harmlos / Fumble-Tripel bustet
## (jede Richtung), Belohnungs-Vorlagen, Reset. Deterministisch über handgebaute
## Wände; eine „neutrale" Füllung (mod-4-Muster) bildet in KEINER Richtung eine Reihe.

const M := SlotPrize.Kind.MONEY
const S := SlotPrize.Kind.SIGIL
const C := SlotPrize.Kind.CHARM
const D := SlotPrize.Kind.DIE
const F := SlotPrize.Kind.FUMBLE

func _bank() -> SlotMachine:
	return SlotMachine.new()

## Reihe ohne benachbarte Gleiche in irgendeiner Richtung: value = syms[(c+2r)%4].
## (Kein lineares mod-3-Muster vermeidet alle vier Richtungen - darum vier Symbole.)
func _filler_row(r: int) -> Array:
	var syms := [M, S, C, D]
	var row: Array = []
	for c in SlotMachine.TOTAL_COLS:
		row.append(syms[(c + 2 * r) % 4])
	return row

## Volle Wand aus den gegebenen oberen Zeilen; restliche Zeilen neutral gefüllt.
func _wall(rows_in: Array) -> SlotMachine:
	var bank := SlotMachine.new()
	for c in SlotMachine.TOTAL_COLS:
		var col: Array = []
		for r in SlotMachine.ROWS:
			var row: Array = rows_in[r] if r < rows_in.size() else _filler_row(r)
			col.append(row[c])
		bank.cells[c] = col
	bank.spun = [true, true, true]
	return bank

## Komplett neutrale Wand (keine Reihe in keiner Richtung).
func _neutral() -> SlotMachine:
	return _wall([])

## Erste Reihe passender Richtung und Art (oder null).
func _find_run(bank: SlotMachine, direction: Array, kind: int) -> Variant:
	for r in bank.runs():
		if r["direction"] == direction and int(r["kind"]) == kind:
			return r
	return null

func test_spin_fills_a_machine_block() -> void:
	var bank := _bank()
	bank.fumble_chance = 0.0
	var block := bank.spin(0)
	assert_eq(block.size(), SlotMachine.MACHINE_COLS, "drei Spalten je Block")
	assert_eq(block[0].size(), SlotMachine.ROWS, "fünf Symbole je Spalte")
	assert_false(bank.busted)

func test_each_machine_spins_once() -> void:
	var bank := _bank()
	bank.fumble_chance = 0.0
	bank.spin(0)
	assert_false(bank.can_spin(0), "derselbe Automat nicht zweimal")
	assert_true(bank.spin(0).is_empty(), "zweiter Dreh: nichts")

func test_neutral_wall_has_no_runs() -> void:
	assert_true(_neutral().runs().is_empty(), "Füllmuster bildet keine Reihe")

func test_three_in_a_row_pays() -> void:
	var bank := _wall([[M, M, M, S, C, S, C, S, C]])
	var horiz: Variant = _find_run(bank, [1, 0], M)
	assert_not_null(horiz, "waagerechte 3er-Reihe")
	assert_eq(int(horiz["length"]), 3)

func test_two_in_a_row_does_not_pay() -> void:
	var bank := _wall([[M, M, S, C, D, S, C, D, S]])
	assert_true(bank.runs().is_empty(), "zwei nebeneinander zahlt nicht mehr")

func test_vertical_run_pays() -> void:
	var bank := _neutral()
	for r in 3:
		bank.cells[4][r + 1] = S  # Spalte 4, Zeilen 1-3
	var run: Variant = _find_run(bank, [0, 1], S)
	assert_not_null(run, "senkrechte Reihe erkannt")
	assert_eq(int(run["length"]), 3)

func test_diagonal_down_right_pays() -> void:
	var bank := _neutral()
	bank.cells[2][1] = C
	bank.cells[3][2] = C
	bank.cells[4][3] = C
	var run: Variant = _find_run(bank, [1, 1], C)
	assert_not_null(run, "Diagonale ↘ erkannt")
	assert_eq(int(run["length"]), 3)

func test_diagonal_up_right_pays() -> void:
	var bank := _neutral()
	bank.cells[2][3] = D
	bank.cells[3][2] = D
	bank.cells[4][1] = D
	var run: Variant = _find_run(bank, [1, -1], D)
	assert_not_null(run, "Diagonale ↗ erkannt")
	assert_eq(int(run["length"]), 3)

func test_run_crosses_machine_boundary() -> void:
	# Vier $ über die Grenze Automat 0→1 (Spalten 2,3,4,5).
	var bank := _wall([[S, C, M, M, M, M, S, C, D]])
	var run: Variant = _find_run(bank, [1, 0], M)
	assert_not_null(run)
	assert_eq(int(run["length"]), 4, "spaltenübergreifende 4er-Reihe")
	assert_eq(int(run["start_col"]), 2)

func test_longer_run_pays_more() -> void:
	var short_run: Variant = _find_run(_wall([[M, M, M, S, C, D, S, C, D]]), [1, 0], M)
	var long_run: Variant = _find_run(_wall([[M, M, M, M, M, C, S, C, D]]), [1, 0], M)
	var short_money := int(short_run["specs"][0]["amount"])
	var long_money := int(long_run["specs"][0]["amount"])
	assert_gt(long_money, short_money * 2, "5er zahlt überproportional mehr als 3er")

func test_pot_summary_sums_all_runs() -> void:
	# Zeile 0: 3er-$ (Automat 0, $3). Zeile 2: 3er-Sigill (2 Sigille). Rest neutral.
	var bank := _neutral()
	for c in 3:
		bank.cells[c][0] = M
		bank.cells[c][2] = S
	var summary := bank.pot_summary()
	assert_eq(int(summary["money"]), 3, "Geld aller Geld-Reihen summiert")
	assert_eq(int(summary["sigils"]), 2, "Sigille aller Sigill-Reihen summiert (3er → 2)")
	assert_true((summary["charms"] as Array).is_empty())
	assert_eq(int(summary["dice"]), 0)

func test_pot_summary_empty_when_no_runs() -> void:
	var summary := _neutral().pot_summary()
	assert_eq(int(summary["money"]), 0)
	assert_eq(int(summary["sigils"]), 0)
	assert_true((summary["charms"] as Array).is_empty())
	assert_eq(int(summary["dice"]), 0)

func test_fumble_pair_is_harmless() -> void:
	var bank := _neutral()
	bank.cells[0][0] = F
	bank.cells[1][0] = F  # waagerechtes Fumble-Paar
	assert_false(bank.busted, "zwei Fumbles brechen nur Reihen")
	assert_eq(bank.fumble_run_cells(2).size(), 2, "Paar wird als Bedrohung markiert")

func test_three_fumbles_bust_on_spin() -> void:
	var bank := _bank()
	bank.fumble_chance = 1.0  # alle Zellen Fumble
	bank.spin(0)  # eine Maschine = drei Spalten je Zeile = 3er-Fumble-Reihe
	assert_true(bank.busted, "drei Fumbles nebeneinander busten")
	assert_true(bank.runs().is_empty(), "Bust: keine Gewinn-Reihen")
	assert_false(bank.can_spin(1), "nach dem Bust ist die Sitzung dicht")

func test_vertical_fumble_triple_busts() -> void:
	var bank := _neutral()
	for r in 3:
		bank.cells[6][r] = F  # senkrechtes Fumble-Tripel
	bank._detect_bust()
	assert_true(bank.busted, "auch senkrechte Fumbles busten")

func test_unspun_columns_break_runs() -> void:
	# Nur Automat 0 gedreht, ganz mit $: Reihen bleiben in Spalten 0..2.
	var bank := _bank()
	for lc in SlotMachine.MACHINE_COLS:
		var col: Array = []
		for r in SlotMachine.ROWS:
			col.append(M)
		bank.cells[lc] = col
	bank.spun = [true, false, false]
	var runs := bank.runs()
	assert_gt(runs.size(), 0, "Reihen innerhalb Automat 0")
	for run in runs:
		for cell in run["cells"]:
			assert_lt(int(cell[0]), SlotMachine.MACHINE_COLS, "keine Reihe in leere Spalten")

func test_reset_session_clears_wall() -> void:
	var bank := _bank()
	bank.fumble_chance = 0.0
	bank.spin(0)
	bank.reset_session()
	assert_false(bank.busted)
	assert_true(bank.runs().is_empty())
	for c in SlotMachine.TOTAL_COLS:
		assert_true(bank.cells[c].is_empty(), "Spalte %d leer" % c)
	for i in SlotMachine.MACHINE_COUNT:
		assert_true(bank.can_spin(i))

func test_run_specs_resolve_by_symbol() -> void:
	var money_run: Variant = _find_run(_wall([[M, M, M, S, C, D, S, C, D]]), [1, 0], M)
	var money: Dictionary = money_run["specs"][0]
	assert_eq(String(money["kind"]), "money")
	assert_gt(int(money["amount"]), 0)
	var sigil_run: Variant = _find_run(_wall([[S, S, S, C, M, D, C, M, D]]), [1, 0], S)
	var sigil: Dictionary = sigil_run["specs"][0]
	assert_eq(String(sigil["kind"]), "sigil")
	assert_eq(int(sigil["count"]), 2, "3er-Sigill-Reihe → 2 Sigille")
