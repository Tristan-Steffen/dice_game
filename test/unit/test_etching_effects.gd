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

# --- Feile -------------------------------------------------------------------

func test_file_down_decrements():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.file_down(d, 3)  # 4 -> 3
	assert_eq(d.faces[3], 3)

func test_can_file_down_respects_floor():
	var d := _die([1, 2, 3, 4, 5, 6])
	assert_false(EtchingEffects.can_file_down(d, 0), "eine 1 darf nicht auf 0")
	assert_true(EtchingEffects.can_file_down(d, 1), "eine 2 darf auf 1")

# --- Doppelkerbe -------------------------------------------------------------

func test_double_notch_bumps_both_faces():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.double_notch(d, 0, 2)  # +1 auf Index 0 und 2
	assert_eq(d.faces, [2, 2, 4, 4, 5, 6])

func test_can_notch_respects_ceiling():
	var d := _die([1, 2, 3, 4, 5, 6])
	assert_true(EtchingEffects.can_notch(d, 4), "eine 5 darf auf 6")
	assert_false(EtchingEffects.can_notch(d, 5), "eine 6 nicht weiter (über 6 nur via Überzahl)")

# --- Mittelung ---------------------------------------------------------------

func test_averaging_sets_rounded_up_mean():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.averaging(d, 0, 5)  # 1 und 6 -> beide 4
	assert_eq(d.faces[0], 4)
	assert_eq(d.faces[5], 4)

func test_averaging_rounds_up():
	var d := _die([2, 3, 3, 4, 5, 6])
	EtchingEffects.averaging(d, 0, 1)  # 2 und 3 -> ceil(2.5) = 3
	assert_eq(d.faces[0], 3)
	assert_eq(d.faces[1], 3)

# --- Anschluss ---------------------------------------------------------------

func test_connect_up_sets_target_to_source_plus_one():
	var a := _die([1, 2, 3, 4, 5, 6])
	var b := _die([1, 1, 1, 1, 1, 1])
	EtchingEffects.connect_up(a, 2, b, 0)  # Quelle 3 -> Ziel 4
	assert_eq(b.faces[0], 4)
	assert_eq(a.faces[2], 3, "Quelle bleibt")

func test_can_connect_up_forbidden_over_six():
	var a := _die([1, 2, 3, 4, 5, 6])
	assert_true(EtchingEffects.can_connect_up(a, 4), "aus 5 wird 6")
	assert_false(EtchingEffects.can_connect_up(a, 5), "aus 6 würde 7 - verboten")

# --- Spiegelung --------------------------------------------------------------

func test_mirror_inverts_standard_die():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.mirror_die(d)
	assert_eq(d.faces, [6, 5, 4, 3, 2, 1])

func test_mirror_uses_actual_min_and_max():
	var d := _die([2, 2, 3, 3, 4, 4])  # Min 2, Max 4 -> Wert -> 6 - Wert
	EtchingEffects.mirror_die(d)
	assert_eq(d.faces, [4, 4, 3, 3, 2, 2])

# --- Abdruck -----------------------------------------------------------------

func test_imprint_copies_across_dice():
	var a := _die([1, 2, 3, 4, 5, 6])
	var b := _die([1, 1, 1, 1, 1, 1])
	EtchingEffects.imprint(a, 5, b, 0)  # kopiere 6 auf b[0]
	assert_eq(b.faces[0], 6)
	assert_eq(a.faces[5], 6, "Quelle bleibt")

# --- Begradigung -------------------------------------------------------------

func test_straighten_bumps_odd_faces():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.straighten(d)
	assert_eq(d.faces, [2, 2, 4, 4, 6, 6])

func test_straighten_caps_at_six():
	var d := _die([5, 7, 1, 2, 4, 6])  # 5->6, 7 (ungerade, aber >=6) bleibt, 1->2
	EtchingEffects.straighten(d)
	assert_eq(d.faces, [6, 7, 2, 2, 4, 6])

# --- Blaupause ---------------------------------------------------------------

func test_blueprint_copies_whole_value_set():
	var a := _die([6, 6, 6, 2, 2, 2])
	var b := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.blueprint(a, b)
	assert_eq(b.faces, [6, 6, 6, 2, 2, 2])
	assert_eq(a.faces, [6, 6, 6, 2, 2, 2], "Quelle unverändert")

func test_blueprint_target_is_independent_copy():
	var a := _die([6, 6, 6, 2, 2, 2])
	var b := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.blueprint(a, b)
	b.faces[0] = 1
	assert_eq(a.faces[0], 6, "Ziel-Kopie ist unabhängig von der Quelle")
