extends GutTest
## Tier-1-Tests der Ätzungs-Transformationen (EtchingEffects). Prüft jede Wirkung
## an konkreten DieDefinition-Seiten (Indizes 0..5).

func _die(faces: Array) -> DieDefinition:
	var d := DieDefinition.new()
	var typed: Array[int] = []
	typed.assign(faces)
	d.faces = typed
	return d

# --- Meißel ------------------------------------------------------------------

func test_chisel_copies_source_onto_dest():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.chisel(d, 5, 4)  # kopiere Seite 6 (Index 5) auf Index 4
	assert_eq(d.faces, [1, 2, 3, 4, 6, 6])

func test_chisel_leaves_source_unchanged():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.chisel(d, 0, 3)
	assert_eq(d.faces[0], 1, "Quelle bleibt")
	assert_eq(d.faces[3], 1, "Ziel übernimmt Quellwert")

# --- Transplantat ------------------------------------------------------------

func test_transplant_swaps_faces_between_two_dice():
	var a := _die([1, 1, 1, 1, 1, 1])
	var b := _die([6, 6, 6, 6, 6, 6])
	EtchingEffects.transplant(a, 0, b, 5)
	assert_eq(a.faces[0], 6)
	assert_eq(b.faces[5], 1)

func test_transplant_only_touches_the_two_faces():
	var a := _die([1, 2, 3, 4, 5, 6])
	var b := _die([6, 5, 4, 3, 2, 1])
	EtchingEffects.transplant(a, 2, b, 2)
	assert_eq(a.faces, [1, 2, 4, 4, 5, 6])
	assert_eq(b.faces, [6, 5, 3, 3, 2, 1])

# --- Schleifstein ------------------------------------------------------------

func test_grindstone_preserves_sum():
	var d := _die([1, 2, 3, 4, 5, 6])
	var before: int = 0
	for v in d.faces:
		before += v
	EtchingEffects.grindstone(d, 5, 0)  # -1 auf Index 5, +1 auf Index 0
	assert_eq(d.faces, [2, 2, 3, 4, 5, 5])
	var after: int = 0
	for v in d.faces:
		after += v
	assert_eq(after, before, "Augensumme bleibt gleich")

func test_can_grindstone_minus_respects_floor():
	var d := _die([1, 2, 3, 4, 5, 6])
	assert_false(EtchingEffects.can_grindstone_minus(d, 0), "eine 1 darf nicht auf 0")
	assert_true(EtchingEffects.can_grindstone_minus(d, 1), "eine 2 darf auf 1")

# --- Feingravur --------------------------------------------------------------

func test_fine_engraving_sets_chosen_value():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.fine_engraving(d, 2, 6)
	assert_eq(d.faces[2], 6)

func test_engraving_value_bounds():
	assert_true(EtchingEffects.is_valid_engraving_value(1))
	assert_true(EtchingEffects.is_valid_engraving_value(6))
	assert_false(EtchingEffects.is_valid_engraving_value(0))
	assert_false(EtchingEffects.is_valid_engraving_value(7))

# --- Überzahl-Gravur ---------------------------------------------------------

func test_overcount_engraving_increments():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.overcount_engraving(d, 0)
	assert_eq(d.faces[0], 2)

func test_overcount_engraving_may_exceed_six():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.overcount_engraving(d, 5)  # 6 -> 7
	assert_eq(d.faces[5], 7, "Überzahl: darf über 6 hinaus")
