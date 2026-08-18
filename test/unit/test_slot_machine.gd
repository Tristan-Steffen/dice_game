extends GutTest
## Tests der Fumble-Automaten-Logik (SlotMachine): 5×9-Symbol-Wand, Reihen-Erkennung
## in ALLEN Richtungen (waagerecht, senkrecht, beide Diagonalen; 3+ gleiche, über
## Automaten-Grenzen), die Auszahlungsleiter (Menge UND Paketgröße je Länge, für
## alle drei Gravur-Sorten gleich), Fumble-Paar harmlos / Fumble-Tripel bustet
## (jede Richtung), Belohnungs-Vorlagen, Reset. Deterministisch über handgebaute
## Wände; eine „neutrale" Füllung (mod-4-Muster) bildet in KEINER Richtung eine Reihe.

const M := SlotPrize.Kind.MATERIAL
const S := SlotPrize.Kind.ENGRAVING
const E := SlotPrize.Kind.DICE_ENGRAVING
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

## Zeile mit EINER waagerechten Reihe der Länge length ab Spalte 0; der Rest zyklisch
## aus den anderen Symbolen, damit die Reihe genau dort endet und nichts Neues entsteht.
func _run_row(kind: int, length: int) -> Array:
	var others: Array = []
	for sym in [M, S, C, D, E]:
		if sym != kind:
			others.append(sym)
	var row: Array = []
	for c in SlotMachine.TOTAL_COLS:
		row.append(kind if c < length else others[c % others.size()])
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
	# Vier Material-Symbole über die Grenze Automat 0→1 (Spalten 2,3,4,5).
	var bank := _wall([[S, C, M, M, M, M, S, C, D]])
	var run: Variant = _find_run(bank, [1, 0], M)
	assert_not_null(run)
	assert_eq(int(run["length"]), 4, "spaltenübergreifende 4er-Reihe")
	assert_eq(int(run["start_col"]), 2)

# --- Die Auszahlungsleiter: die Länge entscheidet Menge UND Paketgröße -----------

## Erwartete Auszahlung je Reihenlänge, ausgeschrieben - der Test darf die Regel
## nicht aus derselben Tabelle ableiten, die er prüft.
const LADDER := {
	3: [1, Pack.TIER_NORMAL], 4: [2, Pack.TIER_NORMAL],
	5: [1, Pack.TIER_GROSS], 6: [2, Pack.TIER_GROSS],
	7: [1, Pack.TIER_KOLOSSAL], 8: [2, Pack.TIER_KOLOSSAL],
	9: [3, Pack.TIER_KOLOSSAL],
}

func _pack_spec(kind: int, length: int) -> Dictionary:
	var run: Variant = _find_run(_wall([_run_row(kind, length)]), [1, 0], kind)
	assert_not_null(run, "Reihe der Länge %d" % length)
	assert_eq(int(run["length"]), length, "Länge %d erkannt" % length)
	return run["specs"][0]

func test_pack_ladder_at_every_length() -> void:
	for length: int in LADDER:
		var spec := _pack_spec(S, length)
		assert_eq(int(spec["count"]), int(LADDER[length][0]), "Menge bei Länge %d" % length)
		assert_eq(int(spec["tier"]), int(LADDER[length][1]), "Größe bei Länge %d" % length)

func test_the_ladder_is_uniform_across_the_engraving_sorts() -> void:
	# Die Sortenschere steckt in den Symbol-Gewichten (seltene Sorte = seltenere
	# Reihe); sie zusätzlich schlechter zu zahlen zählte die Knappheit doppelt.
	for length: int in LADDER:
		var numbers := _pack_spec(S, length)
		for kind: int in [M, E]:
			var other := _pack_spec(kind, length)
			assert_eq(int(other["count"]), int(numbers["count"]),
				"gleiche Menge bei Länge %d" % length)
			assert_eq(int(other["tier"]), int(numbers["tier"]),
				"gleiche Größe bei Länge %d" % length)

func test_the_ladder_trades_pieces_for_magazine_slots() -> void:
	# Bewusste Delle: 6 (2× Groß = 6 Grundstücke) wirft mehr aus als 7 (1× Kolossal
	# = 5) - dafür belegt die 7 nur EINEN Magazin-Platz. Der Test hält das fest,
	# damit es eine Entscheidung bleibt und kein Versehen wird.
	var six := SlotMachine.pack_payout(6)
	var seven := SlotMachine.pack_payout(7)
	var six_base := int(six["count"]) * PhantomPress.base_for(int(six["tier"]))
	var seven_base := int(seven["count"]) * PhantomPress.base_for(int(seven["tier"]))
	assert_gt(six_base, seven_base, "die 6er-Reihe wirft mehr Stücke aus")
	assert_lt(int(seven["count"]), int(six["count"]), "dafür kostet sie mehr Magazin-Plätze")

func test_minted_packs_carry_size_name_and_price() -> void:
	var prize := SlotPrize.from_spec(_pack_spec(S, 6))
	assert_eq(prize.packs.size(), 2, "6er-Reihe: zwei Pakete")
	var plain := Pack.number_pack()
	for pack: Pack in prize.packs:
		assert_eq(pack.tier, Pack.TIER_GROSS, "die Größe steht am Paket")
		assert_eq(pack.display_name, "Großes Zahlen-Paket", "und in der Aufschrift")
		assert_gt(pack.price, plain.price, "der Preis skaliert mit")
	var kolossal := SlotPrize.from_spec(_pack_spec(E, 9))
	assert_eq(kolossal.packs.size(), 3, "9er-Reihe: drei Pakete")
	assert_eq(kolossal.packs[0].display_name, "Kolossales Runen-Paket")

func test_pot_summary_keeps_the_three_kinds_apart() -> void:
	# Je Sorte eine eigene Wand mit EINER 3er-Reihe (mehrere explizite Zeilen
	# zugleich brächen die Neutralität der Füllung - dann entstünden Extra-Reihen).
	assert_eq(int(_wall([[S, S, S, C, D, C, D, C, D]]).pot_summary()["engravings"]), 1,
		"3er-Zahlen-Reihe → 1 Zahlen-Paket")
	assert_eq(int(_wall([[M, M, M, C, D, C, D, C, D]]).pot_summary()["materials"]), 1,
		"3er-Material-Reihe → 1 Material-Paket")
	assert_eq(int(_wall([[E, E, E, C, D, C, D, C, D]]).pot_summary()["edges"]), 1,
		"3er-Würfel-Reihe → 1 Würfel-Gravur-Paket")
	var numbers := _wall([[S, S, S, C, D, C, D, C, D]]).pot_summary()
	assert_eq(int(numbers["materials"]), 0, "eine Zahlen-Reihe zählt NICHT als Material")
	assert_eq(int(numbers["edges"]), 0)

func test_pot_summary_empty_when_no_runs() -> void:
	var summary := _neutral().pot_summary()
	assert_eq(int(summary["engravings"]), 0)
	assert_eq(int(summary["materials"]), 0)
	assert_eq(int(summary["edges"]), 0)
	assert_true((summary["packs"] as Array).is_empty())
	assert_true((summary["charms"] as Array).is_empty())
	assert_eq(int(summary["dice"]), 0)

func test_pot_summary_reports_the_sizes() -> void:
	# Die alten Gesamtzahlen bleiben; "packs" gliedert dieselben Pakete nach Größe.
	var summary := _wall([_run_row(S, 5)]).pot_summary()
	assert_eq(int(summary["engravings"]), 1, "eine Kassette im Topf")
	var lines: Array = summary["packs"]
	assert_eq(lines.size(), 1, "eine Zeile je Sorte und Größe")
	assert_eq(int(lines[0]["symbol"]), S)
	assert_eq(int(lines[0]["tier"]), Pack.TIER_GROSS)
	assert_eq(int(lines[0]["count"]), 1)

func test_no_symbol_pays_money() -> void:
	# Der Automat setzt Geld um, er druckt keines - keine Reihe darf Geld liefern.
	var bank := _neutral()
	for c in SlotMachine.TOTAL_COLS:
		for r in SlotMachine.ROWS:
			bank.cells[c][r] = [S, M, E, C, D][(c + r) % 5]
	for run in bank.runs():
		for spec: Dictionary in run["specs"]:
			assert_ne(String(spec["kind"]), "money", "kein Geld-Gewinn am Automaten")

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

func test_any_spun_tracks_the_session() -> void:
	var bank := _bank()
	bank.fumble_chance = 0.0
	assert_false(bank.any_spun(), "frische Sitzung: nichts gedreht")
	bank.spin(0)
	assert_true(bank.any_spun(), "ein Automat gedreht")
	bank.reset_session()
	assert_false(bank.any_spun(), "nach dem Reset wieder leer")

func test_run_specs_resolve_by_symbol() -> void:
	var material_run: Variant = _find_run(_wall([[M, M, M, S, C, D, S, C, D]]), [1, 0], M)
	var material: Dictionary = material_run["specs"][0]
	assert_eq(String(material["kind"]), "pack")
	assert_eq(int(material["symbol"]), SlotPrize.Kind.MATERIAL, "die Sorte steht in der Vorlage")
	var engraving_run: Variant = _find_run(_wall([[S, S, S, C, M, D, C, M, D]]), [1, 0], S)
	var engraving: Dictionary = engraving_run["specs"][0]
	assert_eq(String(engraving["kind"]), "pack")
	assert_eq(int(engraving["count"]), 1, "3er-Zahlen-Reihe → 1 Zahlen-Paket")

func test_run_label_names_the_pack_kind() -> void:
	var numbers: Variant = _find_run(_wall([[S, S, S, C, M, D, C, M, D]]), [1, 0], S)
	assert_eq(String(numbers["label"]), "◉ ×3 → 1 Zahlen-Paket")
	var long_run: Variant = _find_run(_wall([[S, S, S, S, C, M, C, M, D]]), [1, 0], S)
	assert_eq(String(long_run["label"]), "◉ ×4 → 2 Zahlen-Pakete", "Plural im Etikett")

func test_run_label_names_the_pack_size() -> void:
	# Die Größe ist der ganze Unterschied zwischen einer 4er- und einer 6er-Reihe -
	# das Etikett muss sie nennen, im richtigen Numerus.
	var gross: Variant = _find_run(_wall([_run_row(S, 5)]), [1, 0], S)
	assert_eq(String(gross["label"]), "◉ ×5 → 1 Großes Zahlen-Paket")
	var kolossal: Variant = _find_run(_wall([_run_row(M, 8)]), [1, 0], M)
	assert_eq(String(kolossal["label"]), "◆ ×8 → 2 Kolossale Material-Pakete")

func test_spin_prices_rise_per_machine() -> void:
	assert_eq(SlotMachine.SPIN_PRICES.size(), SlotMachine.MACHINE_COUNT)
	for i in SlotMachine.MACHINE_COUNT - 1:
		assert_gt(int(SlotMachine.SPIN_PRICES[i + 1]), int(SlotMachine.SPIN_PRICES[i]),
			"höherer Automat kostet mehr")
