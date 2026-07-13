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

func test_transplant_raises_face_to_die_max():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.transplant(d, 0)  # Seite mit 1 -> Höchstwert 6
	assert_eq(d.faces, [6, 2, 3, 4, 5, 6])

func test_can_transplant_only_below_max():
	var d := _die([6, 2, 3, 4, 5, 6])
	assert_false(EtchingEffects.can_transplant(d, 0), "schon Höchstwert")
	assert_true(EtchingEffects.can_transplant(d, 1), "unter dem Höchstwert")

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

func test_fine_engraving_can_set_above_six():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.fine_engraving(d, 0, 11)
	assert_eq(d.faces[0], 11, "Feingravur reicht jetzt bis 12")

func test_engraving_value_bounds():
	assert_true(EtchingEffects.is_valid_engraving_value(1))
	assert_true(EtchingEffects.is_valid_engraving_value(7), "über 6 ist jetzt gültig")
	assert_true(EtchingEffects.is_valid_engraving_value(12))
	assert_false(EtchingEffects.is_valid_engraving_value(0))
	assert_false(EtchingEffects.is_valid_engraving_value(13))

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

func test_double_notch_may_exceed_six():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.double_notch(d, 5, 4)  # 6 -> 7, 5 -> 6
	assert_eq(d.faces, [1, 2, 3, 4, 6, 7], "Doppelkerbe darf über 6 hinaus")

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

func test_connect_up_sets_target_to_source_plus_one_same_die():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.connect_up(d, 2, 0)  # Quelle Index 2 (=3) -> Ziel Index 0 = 4
	assert_eq(d.faces[0], 4)
	assert_eq(d.faces[2], 3, "Quelle bleibt")

func test_connect_up_may_exceed_six():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.connect_up(d, 5, 0)  # Quelle Index 5 (=6) -> Ziel = 7
	assert_eq(d.faces[0], 7, "Anschluss darf über 6 hinaus")

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

func test_imprint_stamps_value_onto_two_lowest_others():
	# Gewählt Index 0 (=5); niedrigste ANDERE Seiten sind Index 1 (1) und Index 2 (2).
	var d := _die([5, 1, 2, 3, 4, 6])
	EtchingEffects.imprint(d, 0)
	assert_eq(d.faces, [5, 5, 5, 3, 4, 6])
	assert_eq(d.faces[0], 5, "Quelle bleibt")

func test_imprint_ignores_the_source_face_when_it_is_lowest():
	# Quelle selbst ist der kleinste Wert - sie darf nicht als eines der beiden
	# Ziele gelten; geprägt werden die zwei kleinsten der ÜBRIGEN Seiten.
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.imprint(d, 0)  # Quelle 1; zwei niedrigste andere: 2 (Idx1), 3 (Idx2)
	assert_eq(d.faces, [1, 1, 1, 4, 5, 6])

# --- Begradigung -------------------------------------------------------------

func test_straighten_bumps_odd_faces():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.straighten(d)
	assert_eq(d.faces, [2, 2, 4, 4, 6, 6])

func test_straighten_bumps_odd_faces_above_six_too():
	var d := _die([5, 7, 1, 2, 4, 6])  # ungerade: 5->6, 7->8, 1->2; gerade bleiben
	EtchingEffects.straighten(d)
	assert_eq(d.faces, [6, 8, 2, 2, 4, 6])

# --- Blaupause ---------------------------------------------------------------

func test_blueprint_sets_all_faces_to_selected_value():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.blueprint(d, 3)  # gewählt Index 3 (=4)
	assert_eq(d.faces, [4, 4, 4, 4, 4, 4])

func test_blueprint_from_a_six_makes_an_always_six_die():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.blueprint(d, 5)  # gewählt Index 5 (=6)
	assert_eq(d.faces, [6, 6, 6, 6, 6, 6])
