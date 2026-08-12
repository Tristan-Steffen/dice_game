extends GutTest
## Das Pool-Tray ist eine ORDNUNG, keine Aufreihung: ein Würfel, dessen Körper
## gerade woanders steht (aufgespannt, im Dossier), lässt seinen Sitz LEER - die
## Reihe rückt nicht auf. Nur so bleibt Platz i derselbe Würfel wie vorher.

var tray: DiceTrayView

func before_each() -> void:
	tray = load("res://scenes/dice_pool_tray.tscn").instantiate()
	add_child_autofree(tray)
	await wait_frames(1)

func _dice(count: int) -> Array[DieDefinition]:
	var defs: Array[DieDefinition] = []
	for i in count:
		defs.append(DieDefinition.standard())
	return defs

func test_a_null_entry_leaves_its_seat_empty() -> void:
	var defs := _dice(4)
	var hidden := defs[1]
	defs[1] = null
	tray.fill(defs)
	assert_true(tray.slot_roots[0].visible, "Platz 0 steht")
	assert_false(tray.slot_roots[1].visible, "Platz 1 ist die Lücke")
	assert_null(tray.slot_defs[1], "und er trägt keinen Würfel")
	assert_true(tray.slot_roots[2].visible, "Platz 2 rückt NICHT auf")
	assert_eq(tray.slot_defs[2], defs[2], "er zeigt weiter seinen eigenen Würfel")
	assert_ne(tray.slot_defs[2], hidden)

func test_the_hole_answers_no_pick() -> void:
	var defs := _dice(3)
	defs[1] = null
	tray.fill(defs)
	assert_eq(tray.find_slot_index(tray.slot_bodies[1]), -1,
		"eine Lücke fängt keinen Klick")
	assert_eq(tray.find_slot_index(tray.slot_bodies[2]), 2)

func test_filling_the_hole_again_changes_no_other_seat() -> void:
	var defs := _dice(5)
	var seats: Array[Vector3] = []
	for i in 5:
		seats.append(tray.slot_global_position(i))
	var whole := defs.duplicate()
	defs[2] = null
	tray.fill(defs)
	tray.fill(whole)
	for i in 5:
		assert_eq(tray.slot_global_position(i), seats[i], "Platz %d steht unverrückt" % i)
		assert_eq(tray.slot_defs[i], whole[i], "und trägt wieder seinen Würfel")

func test_trailing_seats_stay_empty_and_defless() -> void:
	tray.fill(_dice(2))
	assert_true(tray.slot_roots[1].visible)
	assert_false(tray.slot_roots[2].visible)
	assert_null(tray.slot_defs[2], "ein leerer Platz trägt keinen alten Würfel mehr")

func test_refresh_faces_survives_the_holes() -> void:
	var defs := _dice(4)
	defs[2] = null
	tray.fill(defs)
	tray.refresh_faces()  # darf über die Lücke nicht stolpern
	assert_null(tray.slot_defs[2])

# --- Wer bekommt gar keinen Sitz (die eine Quelle der Regel) ---------------------

func _seats(defs: Array[DieDefinition], clamped: Array[DieDefinition],
		inspected: DieDefinition) -> Array[bool]:
	var shown: Array[bool] = []
	for def in defs:
		shown.append(DiceTrayView.seat_shows(def, clamped, inspected))
	return shown

func test_a_clamped_die_leaves_its_seat_empty() -> void:
	var defs := _dice(4)
	var clamped: Array[DieDefinition] = [defs[1], defs[3]]
	assert_eq(_seats(defs, clamped, null), [true, false, true, false],
		"aufgespannt steht sein Körper auf der Werkbank")

func test_the_dossier_fills_the_clamp_holes_again() -> void:
	# Im Dossier tritt die ganze Aufspannung von der Bank ab - ihre Würfel liegen
	# derweil wieder in ihren eigenen Sitzen, und die EINE Lücke ist der gezeigte.
	var defs := _dice(4)
	var clamped: Array[DieDefinition] = [defs[1], defs[3]]
	assert_eq(_seats(defs, clamped, defs[0]), [false, true, true, true],
		"nur der gezeigte Würfel fehlt")

func test_an_inspected_clamp_is_the_hole_like_any_other() -> void:
	var defs := _dice(4)
	var clamped: Array[DieDefinition] = [defs[1], defs[3]]
	assert_eq(_seats(defs, clamped, defs[1]), [true, false, true, true],
		"sein eigener Sitz bleibt leer, der zweite Zwingen-Sitz füllt sich")

func test_closing_the_dossier_restores_the_clamp_holes() -> void:
	var defs := _dice(4)
	var clamped: Array[DieDefinition] = [defs[1], defs[3]]
	var before := _seats(defs, clamped, null)
	var during := _seats(defs, clamped, defs[2])
	assert_ne(during, before)
	assert_eq(_seats(defs, clamped, null), before, "danach steht die Ordnung wieder")

func test_an_empty_seat_stays_empty_in_every_case() -> void:
	var defs := _dice(2)
	assert_false(DiceTrayView.seat_shows(null, [] as Array[DieDefinition], null))
	assert_false(DiceTrayView.seat_shows(null, [] as Array[DieDefinition], defs[0]))
