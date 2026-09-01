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
	var out := _resolve([_net({0: StampNet.rune_cell(Rune.CAST)}),
		_net({0: StampNet.rune_cell(Rune.AFTERGLOW)})], _die())
	assert_eq(Array(out["runes"][0]), [Rune.AFTERGLOW])

## Ein Duplikat ersetzt sich nicht selbst - es weicht in den zweiten Platz aus,
## und den hat nur das Vakuum.
func test_a_duplicate_rune_moves_into_the_second_slot() -> void:
	var die := _die()
	die.essence_id = Essence.VACUUM
	var cast := _net({0: StampNet.rune_cell(Rune.CAST)})
	var out := _resolve([cast, cast], die)
	assert_eq(Array(out["runes"][0]), [Rune.CAST, Rune.CAST])

func test_a_duplicate_rune_without_a_free_slot_changes_nothing() -> void:
	var cast := _net({0: StampNet.rune_cell(Rune.CAST)})
	var out := _resolve([cast, cast], _die())
	assert_eq(Array(out["runes"][0]), [Rune.CAST], "einmal gesetzt bleibt einmal gesetzt")

func test_a_rune_the_die_already_carries_is_no_change() -> void:
	var die := _die()
	die.set_rune(0, Rune.CAST)
	var out := _resolve([_net({0: StampNet.rune_cell(Rune.CAST)})], die)
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

func test_the_secondary_halves_the_numbers_and_drops_every_other_channel() -> void:
	var out := _resolve([_net({0: StampNet.value_cell(5),
		1: StampNet.material_cell(DieMaterial.GOLD),
		2: StampNet.rune_cell(Rune.CAST)})], _die())
	var second := SeriesResolver.secondary(out, _die())
	assert_eq(int(second["bonus"][0]), 2, "5 / 2 abgerundet")
	assert_eq(String(second["materials"][1]), "", "Material bleibt beim ersten Würfel")
	assert_true(Array(second["runes"][2]).is_empty())
