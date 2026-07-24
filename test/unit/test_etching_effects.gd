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

# --- Kerbe -------------------------------------------------------------------

func test_notch_increments():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.notch(d, 0)
	assert_eq(d.faces[0], 2)

func test_notch_may_exceed_six():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.notch(d, 5)  # 6 -> 7
	assert_eq(d.faces[5], 7, "Kerbe: darf über 6 hinaus")

# --- Feile -------------------------------------------------------------------

func test_file_down_decrements():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.file_down(d, 3)  # 4 -> 3
	assert_eq(d.faces[3], 3)

func test_can_file_down_respects_floor():
	var d := _die([1, 2, 3, 4, 5, 6])
	assert_false(EtchingEffects.can_file_down(d, 0), "eine 1 darf nicht auf 0")
	assert_true(EtchingEffects.can_file_down(d, 1), "eine 2 darf auf 1")

# --- Stanze ------------------------------------------------------------------

func test_punch_adds_five():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.punch(d, 0)
	assert_eq(d.faces, [6, 2, 3, 4, 5, 6])

func test_punch_may_exceed_six():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.punch(d, 5)  # 6 -> 11
	assert_eq(d.faces[5], 11, "Stanze: darf über 6 hinaus")

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

# --- Politur -----------------------------------------------------------------

func test_polish_bumps_every_face():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.polish(d)
	assert_eq(d.faces, [2, 3, 4, 5, 6, 7], "Politur: alle Seiten +1, auch über 6")

# --- Schmirgel -----------------------------------------------------------------

func test_sandpaper_lowers_every_face():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.sandpaper(d)
	assert_eq(d.faces, [1, 1, 2, 3, 4, 5], "Schmirgel: alle Seiten −1, die 1 bleibt 1")

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
