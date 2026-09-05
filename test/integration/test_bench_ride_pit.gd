extends GutTest
## Das LOCH der Hebebühne: jede Fahrt SCHLIESST es wieder, ein Umsetzen der
## Maschine zwischen zwei Feldern läßt keines offen, und der harte Weg schließt es
## auch mitten in der Fahrt. Die Regel gilt für JEDEN Besteller (Vitrine, Schluck,
## Wett-Tresen); die Bühnen-Fahrt des Zielwürfels gehört seit der Welle T NICHT
## mehr dazu - sie fliegt als TRAGE-BOGEN über den Tisch und gräbt gar kein Loch.
## Gebucht wird hier wie in scene_root: opened setzt, closed räumt.

const HALF := Vector2(0.6, 0.6)

var _open := false

func _shaft() -> LiftShaftView:
	var shaft := LiftShaftView.new("BenchShaft")
	add_child_autofree(shaft)
	shaft.opened.connect(func(_at: Vector3, _hole: Vector2) -> void: _open = true)
	shaft.closed.connect(func() -> void: _open = false)
	shaft.setup(Vector3.ZERO, HALF, 3.0)
	return shaft

func _body() -> Node3D:
	var body := Node3D.new()
	add_child_autofree(body)
	return body

func before_each() -> void:
	_open = false

func test_ein_abgang_schliesst_sein_loch() -> void:
	var shaft := _shaft()
	var body := _body()
	var tween := shaft.run_exit([body], [Vector3.ZERO], 0.0)
	assert_not_null(tween, "der Abgang ist ein Fahrplan")
	await wait_for_signal(tween.finished, 5.0)
	assert_false(_open, "nach dem Abgang steht kein Loch mehr offen")

func test_zwei_beine_ueber_zwei_felder_lassen_kein_loch_stehen() -> void:
	# Der harte Fall: Bein A am einen Feld, dann wird DIESELBE Maschine auf ein
	# zweites umgesetzt und fährt dort Bein B.
	var shaft := _shaft()
	var body := _body()
	var first := shaft.run_exit([body], [Vector3.ZERO], 0.0)
	await wait_for_signal(first.finished, 5.0)
	shaft.setup(Vector3(4.0, 0.0, -2.0), HALF, 3.0)
	var second := shaft.run_cycle([body], [Vector3(4.0, 0.0, -2.0)], 0.0)
	assert_not_null(second, "auch das zweite Bein ist ein Fahrplan")
	await wait_for_signal(second.finished, 5.0)
	assert_false(_open, "und danach ist das Loch zu")

func test_der_harte_weg_schliesst_das_loch_mitten_in_der_fahrt() -> void:
	var shaft := _shaft()
	var body := _body()
	shaft.run_cycle([body], [Vector3.ZERO], 0.0)
	await wait_frames(4)
	assert_true(_open, "die laufende Fahrt hat ihr Loch offen")
	shaft.settle_hard()
	assert_false(_open, "der harte Weg macht es zu")
	assert_false(shaft.riding(), "und läßt keine Fahrt zurück")

func test_ein_umsetzen_mitten_in_der_fahrt_schuldet_nichts() -> void:
	# Der schlimmste Fall: die Maschine wird umgesetzt, WÄHREND sie fährt. Danach
	# muß der harte Weg trotzdem alles schließen.
	var shaft := _shaft()
	var body := _body()
	shaft.run_cycle([body], [Vector3.ZERO], 0.0)
	await wait_frames(4)
	shaft.setup(Vector3(4.0, 0.0, -2.0), HALF, 3.0)
	shaft.settle_hard()
	assert_false(_open, "kein Loch bleibt stehen")
	assert_false(shaft.visible, "und die Maschine ist fort")
