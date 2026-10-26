extends GutTest
## Die SERIENSCHALTUNG als reine Rechnung: Reihenfolge, Operatoren, die vier
## Kanäle und die verpuffenden Zellen. Kein rng, kein Lauf - nur Netze und ein
## Zielwürfel.

func _die(faces: Array[int] = [1, 2, 3, 4, 5, 6]) -> DieDefinition:
	var def := DieDefinition.new()
	def.faces = faces.duplicate()
	return def

## Netz aus {Seite: Zelle}.
func _net(cells: Dictionary) -> Array:
	var net := StampNet.empty_net()
	for face: int in cells:
		net[face] = cells[face]
	return net

func _resolve(nets: Array, die: DieDefinition, terms: Dictionary = {}) -> Dictionary:
	return SeriesResolver.resolve(nets, die, terms)

# --- Der Zahl-Kanal ---------------------------------------------------------------

func test_an_empty_series_changes_nothing() -> void:
	var die := _die()
	var out := _resolve([], die)
	assert_true(SeriesResolver.is_empty(out))
	assert_eq(out["faces_after"], die.faces)

func test_value_cells_add_up_across_the_series() -> void:
	var out := _resolve([_net({0: StampNet.value_cell(2)}),
		_net({0: StampNet.value_cell(3)})], _die())
	assert_eq(int(out["bonus"][0]), 5)
	assert_eq(int(out["faces_after"][0]), 6, "1 + 5")

## Der Verdoppler rechnet auf der SUMME, nie auf dem Seitenwert - sonst wäre ×2
## auf einer 6er-Seite sofort absurd.
func test_the_doubler_works_on_the_running_sum_not_on_the_face() -> void:
	var out := _resolve([_net({5: StampNet.value_cell(3)}),
		_net({5: StampNet.operator_cell(StampNet.OP_DOUBLER)})], _die())
	assert_eq(int(out["bonus"][5]), 6, "3 × 2")
	assert_eq(int(out["faces_after"][5]), 12, "6 + 6, nie 6 × 2 + 3")

## Position IST Macht: derselbe Verdoppler früh ist wertlos, spät ist er alles.
func test_position_decides_the_doublers_power() -> void:
	var doubler := _net({0: StampNet.operator_cell(StampNet.OP_DOUBLER)})
	var value := _net({0: StampNet.value_cell(4)})
	assert_eq(int(_resolve([doubler, value], _die())["bonus"][0]), 4, "früh: 0 × 2 + 4")
	assert_eq(int(_resolve([value, doubler], _die())["bonus"][0]), 8, "spät: 4 × 2")

func test_the_mirror_copies_the_sum_to_the_opposite_face() -> void:
	var out := _resolve([_net({1: StampNet.value_cell(5)}),
		_net({1: StampNet.operator_cell(StampNet.OP_MIRROR)})], _die())
	assert_eq(int(out["bonus"][1]), 5, "die Quelle behält ihre Summe")
	assert_eq(int(out["bonus"][DieDefinition.opposite_face(1)]), 5)

func test_the_collector_pulls_every_sum_onto_one_cell() -> void:
	var out := _resolve([_net({0: StampNet.value_cell(2), 3: StampNet.value_cell(4),
		5: StampNet.value_cell(1)}),
		_net({5: StampNet.operator_cell(StampNet.OP_COLLECTOR)})], _die())
	assert_eq(int(out["bonus"][5]), 7)
	assert_eq(int(out["bonus"][0]), 0, "die anderen Seiten sind leergeräumt")
	assert_eq(int(out["bonus"][3]), 0)

## Der Jackpot-Zug: erst sammeln, dann verdoppeln. Andersherum verdoppelt man eine
## einzelne Zelle - genau das ist das Puzzle.
func test_collector_before_doubler_is_the_jackpot() -> void:
	var values := _net({0: StampNet.value_cell(3), 1: StampNet.value_cell(3),
		2: StampNet.value_cell(3)})
	var collector := _net({0: StampNet.operator_cell(StampNet.OP_COLLECTOR)})
	var doubler := _net({0: StampNet.operator_cell(StampNet.OP_DOUBLER)})
	assert_eq(int(_resolve([values, collector, doubler], _die())["bonus"][0]), 18)
	assert_eq(int(_resolve([values, doubler, collector], _die())["bonus"][0]), 12,
		"erst verdoppeln zieht nur die eine Zelle hoch")

# --- Der Material-Kanal -------------------------------------------------------------

func test_a_later_material_paints_over_an_earlier_one() -> void:
	var out := _resolve([_net({2: StampNet.material_cell(DieMaterial.GOLD)}),
		_net({2: StampNet.material_cell(DieMaterial.RUBY)})], _die())
	assert_eq(String(out["materials"][2]), DieMaterial.RUBY)
	assert_false(bool(out["doped"][2]), "frische Farbe liegt unveredelt")

## Zweimal dasselbe Material auf dieselbe Seite ist der planbare Weg zur
## Veredelung.
func test_the_same_material_twice_projects_doped() -> void:
	var gold := _net({2: StampNet.material_cell(DieMaterial.GOLD)})
	var out := _resolve([gold, gold], _die())
	assert_eq(String(out["materials"][2]), DieMaterial.GOLD)
	assert_true(bool(out["doped"][2]))

## Auch das Material, das SCHON auf dem Würfel liegt, zählt als erste Schicht.
func test_a_material_on_top_of_its_own_kind_dopes_too() -> void:
	var die := _die()
	die.set_face_material(2, DieMaterial.BONE)
	var out := _resolve([_net({2: StampNet.material_cell(DieMaterial.BONE)})], die)
	assert_true(bool(out["doped"][2]))

func test_the_burn_in_blocks_overpainting_and_the_cell_fizzles() -> void:
	var die := _die()
	die.set_face_material(3, DieMaterial.GLASS)
	die.set_rune(3, Rune.BURN_IN)
	var out := _resolve([_net({3: StampNet.material_cell(DieMaterial.GOLD)})], die)
	assert_eq(String(out["materials"][3]), "", "nichts wird übermalt")
	assert_eq((out["fizzled"] as Array).size(), 1)
	assert_eq(String(out["fizzled"][0]["reason"]), SeriesResolver.FIZZLE_BURNED)

# --- Die Veredelungs-Zelle ----------------------------------------------------------

func test_a_dope_cell_saturates_a_material_the_series_just_laid() -> void:
	var out := _resolve([_net({4: StampNet.material_cell(DieMaterial.RUBY)}),
		_net({4: StampNet.dope_cell()})], _die())
	assert_true(bool(out["doped"][4]))
	assert_true((out["fizzled"] as Array).is_empty())

func test_a_dope_cell_on_a_naked_face_fizzles() -> void:
	var out := _resolve([_net({4: StampNet.dope_cell()})], _die())
	assert_false(bool(out["doped"][4]))
	assert_eq(String(out["fizzled"][0]["reason"]), SeriesResolver.FIZZLE_NAKED)

func test_a_dope_cell_on_an_already_doped_face_fizzles() -> void:
	var die := _die()
	die.set_face_material(4, DieMaterial.AMBER)
	die.dope(4)
	var out := _resolve([_net({4: StampNet.dope_cell()})], die)
	assert_eq(String(out["fizzled"][0]["reason"]), SeriesResolver.FIZZLE_DOPED)

# --- Der Runen-Kanal ---------------------------------------------------------------

func test_the_later_rune_wins_the_first_slot() -> void:
	var out := _resolve([_net({0: StampNet.rune_cell(Rune.AFTERGLOW)}),
		_net({0: StampNet.rune_cell(Rune.AFTERGLOW)})], _die())
	assert_eq(Array(out["runes"][0]), [Rune.AFTERGLOW])

## Ein Duplikat ersetzt sich nicht selbst - es weicht in den zweiten Platz aus,
## und den hat nur das Vakuum.
func test_a_duplicate_rune_moves_into_the_second_slot() -> void:
	var die := _die()
	die.essence_id = Essence.VACUUM
	var glow := _net({0: StampNet.rune_cell(Rune.AFTERGLOW)})
	var out := _resolve([glow, glow], die)
	assert_eq(Array(out["runes"][0]), [Rune.AFTERGLOW, Rune.AFTERGLOW])

func test_a_duplicate_rune_without_a_free_slot_changes_nothing() -> void:
	var glow := _net({0: StampNet.rune_cell(Rune.AFTERGLOW)})
	var out := _resolve([glow, glow], _die())
	assert_eq(Array(out["runes"][0]), [Rune.AFTERGLOW], "einmal gesetzt bleibt einmal gesetzt")

func test_a_rune_the_die_already_carries_is_no_change() -> void:
	var die := _die()
	die.set_rune(0, Rune.AFTERGLOW)
	var out := _resolve([_net({0: StampNet.rune_cell(Rune.AFTERGLOW)})], die)
	assert_true(Array(out["runes"][0]).is_empty(), "die Projektion meldet nur Änderungen")

# --- Der Pointer-Kanal --------------------------------------------------------------

func test_a_pointer_cell_wires_its_neighbour() -> void:
	var out := _resolve([_net({0: StampNet.pointer_cell(1)})], _die())
	assert_eq(int(out["pointers"][0]), 1)

func test_a_pointer_to_the_opposite_face_fizzles() -> void:
	var out := _resolve([_net({0: StampNet.pointer_cell(
		DieDefinition.opposite_face(0))})], _die())
	assert_eq(int(out["pointers"][0]), -1)
	assert_eq(String(out["fizzled"][0]["reason"]), SeriesResolver.FIZZLE_POINTER)

# --- Katalysator-Terme und die Zweitprojektion ---------------------------------------

## Die Treibladung legt am ENDE auf jede gefüllte Zahl-Zelle nach - ein früherer
## Zuschlag wäre vom Verdoppler mitverdoppelt worden.
func test_the_propellant_lifts_every_filled_number_cell_once() -> void:
	var out := _resolve([_net({0: StampNet.value_cell(2), 1: StampNet.value_cell(1)}),
		_net({0: StampNet.operator_cell(StampNet.OP_DOUBLER)})], _die(),
		{"propellant": 1})
	assert_eq(int(out["bonus"][0]), 5, "2 × 2, dann +1")
	assert_eq(int(out["bonus"][1]), 2)
	assert_eq(int(out["bonus"][2]), 0, "leere Zellen bleiben leer")

func test_a_factor_cell_multiplies_the_accumulated_sum_of_its_face() -> void:
	var out := _resolve([_net({0: StampNet.value_cell(2), 1: StampNet.value_cell(1)}),
		_net({0: StampNet.factor_cell(3), 2: StampNet.factor_cell(3)}),
		_net({0: StampNet.value_cell(1)})], _die())
	assert_eq(int(out["bonus"][0]), 7, "2 × 3, dann +1")
	assert_eq(int(out["bonus"][1]), 1, "ohne Faktor-Zelle unberührt")
	assert_eq(int(out["bonus"][2]), 0, "nichts aufgelaufen, nichts vervielfacht")
	assert_eq(int(out["factors"][2]), 3, "die Anzeige kennt den Faktor trotzdem")
	assert_eq(int(out["factors"][1]), 1)

func test_the_propellant_comes_after_the_factor() -> void:
	var out := _resolve([_net({0: StampNet.value_cell(2)}),
		_net({0: StampNet.factor_cell(4)})], _die(), {"propellant": 1})
	assert_eq(int(out["bonus"][0]), 9, "2 × 4, dann +1")

# --- DIE VERDICHTUNG --------------------------------------------------------------
## Sie ist eine ANDERE Rechnung als das Prägen: Faktoren ADDIEREN, und darum ist die
## Reihenfolge hier gleichgültig. Verdichten sammelt ein, die Serie wertet aus.

## Der Fall, den der Spieler genannt hat (2026-10-26): ×4, +5 und +4 werden 4x+9.
func test_verdichten_schreibt_zahl_und_faktor_als_mathematische_notation() -> void:
	var out := SeriesResolver.compress([
		_net({0: StampNet.factor_cell(4)}),
		_net({0: StampNet.value_cell(5)}),
		_net({0: StampNet.value_cell(4)})])
	var cell: Dictionary = StampNet.cell_at(out["net"], 0)
	assert_eq(StampNet.kind_of(cell), StampNet.KIND_COMPOUND)
	assert_eq(int(cell["factor"]), 4)
	assert_eq(int(cell["value"]), 9, "die Summanden addieren")
	assert_eq(StampNet.compound_glyph(cell), "4x+9", "und so steht es auf der Karte")

## Der Balance-Anker: zwei Multiplikatoren ADDIEREN, sie multiplizieren nicht. Damit
## waechst die Macht linear mit der Zahl ausgegebener Mult-Karten.
func test_zwei_multiplikatoren_addieren_sich_beim_verdichten() -> void:
	var out := SeriesResolver.compress([
		_net({0: StampNet.factor_cell(4)}),
		_net({0: StampNet.factor_cell(4)})])
	assert_eq(int(StampNet.cell_at(out["net"], 0)["factor"]), 8, "×4 + ×4 = ×8, nicht ×16")

## Und darum ist die Reihenfolge beim Verdichten gleichgueltig - anders als beim
## Praegen, wo genau dieselben zwei Karten 20 oder 5 ergeben.
func test_die_reihenfolge_entscheidet_beim_praegen_aber_nicht_beim_verdichten() -> void:
	var value := _net({0: StampNet.value_cell(5)})
	var factor := _net({0: StampNet.factor_cell(4)})
	assert_eq(int(_resolve([value, factor], _die())["bonus"][0]), 20, "prägen: 5 × 4")
	assert_eq(int(_resolve([factor, value], _die())["bonus"][0]), 5, "prägen: 0 × 4 + 5")
	var a: Dictionary = StampNet.cell_at(SeriesResolver.compress([value, factor])["net"], 0)
	var b: Dictionary = StampNet.cell_at(SeriesResolver.compress([factor, value])["net"], 0)
	assert_eq(a, b, "verdichten: dieselbe Karte, wie man sie auch stapelt")

## Spieler-Entscheid 2026-10-26: Material und Rune schliessen sich NICHT mehr aus.
func test_material_und_rune_liegen_verdichtet_auf_derselben_seite() -> void:
	var out := SeriesResolver.compress([
		_net({0: StampNet.material_cell(DieMaterial.RUBY)}),
		_net({0: StampNet.rune_cell(Rune.AFTERGLOW)}),
		_net({0: StampNet.value_cell(3)})])
	var cell: Dictionary = StampNet.cell_at(out["net"], 0)
	assert_eq(String(cell["id"]), DieMaterial.RUBY, "das Material bleibt")
	assert_eq(String(cell["rune"]), Rune.AFTERGLOW, "die Rune auch")
	assert_eq(int(cell["value"]), 3, "und die Zahl daneben")
	assert_eq(out["fizzled"], [], "hier verpufft nichts")

## Zweimal dieselbe Farbe ist die Veredelung - genau wie beim Prägen.
func test_zweimal_dasselbe_material_verdichtet_zur_veredelung() -> void:
	var paint := _net({0: StampNet.material_cell(DieMaterial.GOLD)})
	var out := SeriesResolver.compress([paint, paint])
	var cell: Dictionary = StampNet.cell_at(out["net"], 0)
	assert_true(bool(cell["dope"]), "dieselbe Farbe doppelt sättigt die Glasur")
	assert_eq(out["fizzled"], [], "sie verdrängt sich nicht selbst")

## Eine Seite traegt EIN Material - so viel wie ein Wuerfel. Der letzte gewinnt, der
## fruehere verpufft und sagt es.
func test_zwei_materialien_auf_einer_seite_lassen_das_fruehere_verpuffen() -> void:
	var out := SeriesResolver.compress([
		_net({0: StampNet.material_cell(DieMaterial.RUBY)}),
		_net({0: StampNet.material_cell(DieMaterial.GOLD)})])
	assert_eq(String(StampNet.cell_at(out["net"], 0)["id"]), DieMaterial.GOLD,
		"der letzte gewinnt")
	assert_eq(out["fizzled"].size(), 1, "und der frühere meldet sich")
	assert_eq(String(out["fizzled"][0]["reason"]), SeriesResolver.FIZZLE_CROWDED)
	assert_eq(int(out["fizzled"][0]["face"]), 0)

## Operatoren sind nicht verdichtbar: sie rechnen auf der aufgelaufenen Summe und
## schreiben auf FREMDE Seiten.
func test_ein_operator_laesst_sich_nicht_verdichten() -> void:
	var nets := [_net({0: StampNet.operator_cell(StampNet.OP_MIRROR)})]
	assert_false(SeriesResolver.compressible(nets), "die Reihe ist gesperrt")
	var out := SeriesResolver.compress(nets)
	assert_true(StampNet.is_blank(out["net"]), "er traegt nichts in die Karte")
	assert_eq(String(out["fizzled"][0]["reason"]), SeriesResolver.FIZZLE_OPERATOR)

func test_eine_reihe_ohne_operator_ist_verdichtbar() -> void:
	assert_true(SeriesResolver.compressible([
		_net({0: StampNet.value_cell(3)}),
		_net({1: StampNet.factor_cell(2)})]))

## Leere Seiten bleiben leer - eine verdichtete Karte traegt keine Null-Zellen.
func test_verdichten_laesst_leere_seiten_leer() -> void:
	var out := SeriesResolver.compress([_net({2: StampNet.value_cell(4)})])
	assert_eq(StampNet.filled_count(out["net"]), 1, "nur die eine Seite")
	assert_eq(int(StampNet.cell_at(out["net"], 2)["value"]), 4)

# --- Die verdichtete Karte im PRÄGEN ----------------------------------------------

## Angewandt rechnet sie AFFIN: Summe × factor + value. Das ist genau, was "4x+9"
## liest - und es laeuft durch dieselben Kanalregeln wie jede andere Zelle.
func test_eine_verdichtete_zelle_praegt_affin() -> void:
	var packed := _net({0: StampNet.compound_cell(4, 9)})
	assert_eq(int(_resolve([packed], _die())["bonus"][0]), 9, "0 × 4 + 9")
	var out := _resolve([_net({0: StampNet.value_cell(5)}), packed], _die())
	assert_eq(int(out["bonus"][0]), 29, "5 × 4 + 9")
	assert_eq(int(out["factors"][0]), 4, "und die Anzeige kennt den Faktor")

## Ihre uebrigen Kanaele wirken wie die der Einzelkarten, inklusive Verpuffen.
func test_eine_verdichtete_zelle_traegt_ihre_kanaele_ins_praegen() -> void:
	var die := _die()
	var packed := _net({0: StampNet.compound_cell(1, 2, DieMaterial.RUBY, true,
		Rune.AFTERGLOW)})
	var out := _resolve([packed], die)
	assert_eq(int(out["bonus"][0]), 2)
	assert_eq(String(out["materials"][0]), DieMaterial.RUBY)
	assert_true(bool(out["doped"][0]), "die Veredelung der Zelle greift")
	assert_eq(Array(out["runes"][0]), [Rune.AFTERGLOW] as Array[String])

## Verdichten einer schon verdichteten Karte bleibt LINEAR - das ist der Grund, warum
## es keinen Verdichtungs-Deckel braucht.
func test_verdichten_einer_verdichteten_karte_waechst_linear() -> void:
	var once: Array = SeriesResolver.compress([
		_net({0: StampNet.factor_cell(4)}), _net({0: StampNet.value_cell(5)})])["net"]
	var twice: Array = SeriesResolver.compress([once, _net({0: StampNet.factor_cell(4)})])["net"]
	var cell: Dictionary = StampNet.cell_at(twice, 0)
	assert_eq(int(cell["factor"]), 8, "4 + 4, nicht 4 × 4")
	assert_eq(int(cell["value"]), 5, "der Summand bleibt")

## Eine verdichtete Karte OHNE Faktor erfindet beim erneuten Verdichten keinen.
func test_zwei_faktorlose_verdichtete_karten_erfinden_keinen_faktor() -> void:
	var plain: Array = SeriesResolver.compress([_net({0: StampNet.value_cell(3)})])["net"]
	var out: Array = SeriesResolver.compress([plain, plain])["net"]
	var cell: Dictionary = StampNet.cell_at(out, 0)
	assert_eq(int(cell["factor"]), 1, "1 heißt: kein Multiplikator")
	assert_eq(int(cell["value"]), 6)
	assert_eq(StampNet.compound_glyph(cell), "+6", "und so steht es auch da")
