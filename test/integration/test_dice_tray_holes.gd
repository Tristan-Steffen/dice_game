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
# Der Ort-Zustand lebt in scene_root (_clamp_on_bench); die Sitzordnung kennt nur die
# reine Regel: ein Würfel STEHT in seinem Sitz, es sei denn, er ist gerade auf der
# Bank (on_bench) oder das Dossier zeigt ihn (inspected).

func _seat(def: DieDefinition, inspected: DieDefinition, on_bench := false) -> bool:
	return DiceTrayView.seat_shows(def, inspected, on_bench)

func test_a_pool_die_lies_in_its_seat_until_it_migrates() -> void:
	# Aufgespannt heißt NICHT weg: der Würfel LIEGT im Pool, bis er zur Bank wandert.
	var defs := _dice(4)
	assert_true(_seat(defs[1], null, false), "im Pool steht sein Körper im Sitz")

func test_a_die_on_the_bench_leaves_its_seat_empty() -> void:
	var defs := _dice(4)
	assert_false(_seat(defs[1], null, true),
		"auf der Bank steht sein Körper woanders - der Sitz bleibt leer")

func test_the_inspected_die_is_the_hole() -> void:
	var defs := _dice(4)
	assert_false(_seat(defs[0], defs[0]), "der gezeigte Würfel fehlt im Tray")
	assert_true(_seat(defs[1], defs[0]), "sein Nachbar steht")

func test_an_empty_seat_stays_empty_in_every_case() -> void:
	var defs := _dice(2)
	assert_false(DiceTrayView.seat_shows(null, null))
	assert_false(DiceTrayView.seat_shows(null, defs[0]))
	assert_false(DiceTrayView.seat_shows(null, null, true))

# --- Die Platz-BÜHNE: was unter der Fläche liegt, zeigt gar nichts --------------

func test_ein_abgesenkter_platz_zeigt_weder_puck_noch_wuerfel() -> void:
	tray.fill(_dice(3))
	assert_true(tray.slot_roots[0].visible)
	assert_true(tray.slot_emitter(0).visible, "der Puck steht auf der Fläche")
	tray.set_slot_staged(0, false)
	assert_false(tray.slot_roots[0].visible, "der Würfel ist fort")
	assert_false(tray.slot_emitter(0).visible, "und der Puck mit ihm")
	tray.set_slot_staged(0, true)
	assert_true(tray.slot_roots[0].visible, "zurück auf der Fläche steht wieder beides")
	assert_true(tray.slot_emitter(0).visible)

func test_ein_leerer_platz_bleibt_leer_auch_wenn_er_auffaehrt() -> void:
	tray.fill(_dice(1))
	tray.set_slot_staged(2, false)
	tray.set_slot_staged(2, true)
	assert_false(tray.slot_roots[2].visible, "ohne Würfel kommt keiner zurück")
	assert_true(tray.slot_emitter(2).visible, "der leere Puck steht trotzdem")

func test_ein_fahrender_platz_wird_vom_schwebe_takt_in_ruhe_gelassen() -> void:
	tray.fill(_dice(2))
	tray.set_slot_riding(0, true)
	var parked := Vector3(1.0, 9.0, 2.0)
	tray.slot_roots[0].global_position = parked
	tray.slot_roots[1].global_position = parked
	await wait_frames(3)
	assert_eq(tray.slot_roots[0].global_position, parked,
		"die Hebebühne führt ihn, nicht das Wippen")
	assert_ne(tray.slot_roots[1].global_position, parked,
		"der stehende Nachbar wippt weiter")

# --- Der Sitz ist GERECHNET, nicht gemessen -------------------------------------

func test_der_sitz_kommt_aus_dem_raster_und_nicht_vom_koerper() -> void:
	for i in tray.slot_roots.size():
		# Die Höhe wippt, der GRUNDRISS nicht - dort muss der Sitz stimmen.
		var body := tray.slot_global_position(i)
		assert_almost_eq(tray.slot_home_position(i).x, body.x, 0.0001, "Platz %d x" % i)
		assert_almost_eq(tray.slot_home_position(i).z, body.z, 0.0001, "Platz %d z" % i)
		assert_almost_eq(tray.slot_home_position(i).y, tray.global_position.y, 0.0001)
		assert_almost_eq(tray.slot_home_position(i, true).y,
			tray.global_position.y + DiceTrayView.FLOAT_HEIGHT, 0.0001)
	# Ein fahrender Körper verschiebt den Sitz NICHT - sonst spränge das Loch.
	var seat := tray.slot_home_position(3)
	tray.slot_roots[3].global_position = Vector3(50.0, -9.0, 50.0)
	assert_eq(tray.slot_home_position(3), seat)

# --- Der Belegungs-DIFF der Bühne ----------------------------------------------

func _bits(values: Array) -> Array[bool]:
	var out: Array[bool] = []
	out.assign(values)
	return out

func test_der_diff_faehrt_nur_die_neuen_plaetze() -> void:
	assert_eq(DiceTrayView.stage_entering(_bits([true, true, true]),
		_bits([true, false, false])), [1, 2] as Array[int])

func test_wer_schon_steht_faehrt_nicht_noch_einmal() -> void:
	assert_eq(DiceTrayView.stage_entering(_bits([true, true]),
		_bits([true, true])), [] as Array[int])

func test_ein_verlorener_wuerfel_loest_keine_fahrt_aus() -> void:
	# Ihn trug die Wurf-Zeremonie fort - die Bühne holt ihn nicht nach.
	assert_eq(DiceTrayView.stage_entering(_bits([false, false]),
		_bits([true, true])), [] as Array[int])

func test_eine_leere_belegung_faehrt_alles_auf() -> void:
	assert_eq(DiceTrayView.stage_entering(_bits([true, true, true]),
		_bits([])), [0, 1, 2] as Array[int])

# --- Die WERKBANK-Geometrie ist EINGEFROREN ------------------------------------
# Das Ablage-Tray ist tot, aber die Werkbank-Ecke maß an SEINER Spanne mit. Das
# Raster war dasselbe, nur um 12,15 in Welt-Z versetzt (33 minus 20,85) - genau
# diese zwei Spannen hält scene_root weiter, also bleibt jede abgeleitete Zahl.

const LEGACY_Z := 12.15

func test_die_beiden_tray_spannen_messen_wie_eh_und_je() -> void:
	assert_eq(tray.rows, 5)
	assert_eq(tray.columns, 6)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for shift: float in [0.0, LEGACY_Z]:
		for i in tray.slot_roots.size():
			var at := tray.slot_home_position(i) + Vector3(0.0, 0.0, shift)
			lo = Vector2(minf(lo.x, at.x), minf(lo.y, at.z))
			hi = Vector2(maxf(hi.x, at.x), maxf(hi.y, at.z))
	# Fünf Reihen in Welt-X, sechs Spalten plus der Versatz in Welt-Z - alles aus
	# SPACING gerechnet, damit ein Abstands-Tweak die Zahlen nicht einfriert.
	var sx := DiceTrayView.SPACING.x
	var sy := DiceTrayView.SPACING.y
	assert_almost_eq(hi.x - lo.x, (tray.rows - 1) * sx, 0.0001, "die Höhe der Ecke")
	assert_almost_eq(hi.y - lo.y, (tray.columns - 1) * sy + LEGACY_Z, 0.0001, "und ihre Breite")
	assert_almost_eq(lo.x, tray.global_position.x - (tray.rows - 1) / 2.0 * sx, 0.0001)
	assert_almost_eq(lo.y, tray.global_position.z - (tray.columns - 1) / 2.0 * sy, 0.0001)
