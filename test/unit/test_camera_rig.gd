extends GutTest
## Test der Kamera-Sperre (CameraRig.tilt_locked): solange gesetzt, hält die
## Kamera ihre Ausrichtung und ignoriert das Maus-Rundschauen - genutzt beim
## Drehen der Würfel-Projektion in der Gravur-Station (siehe scene_root ->
## DieInspectorView.rotating_die), damit die Ziehbewegung nicht den Blick schwenkt.

var rig: CameraRig

func before_each() -> void:
	rig = CameraRig.new()
	add_child_autofree(rig)
	rig._ready()  # anchor_basis/anchor_origin aus dem aktuellen Transform übernehmen

func test_tilt_locked_holds_the_camera_orientation() -> void:
	rig.set_tilt_locked(true)
	var before := rig.global_transform
	rig._process(0.1)
	assert_eq(rig.global_transform, before, "gesperrt bewegt sich die Kamera nicht")

func test_release_holds_then_eases_the_look_back() -> void:
	# Nach dem Freigeben bleibt die Kamera erst stehen (Halte-Phase), blendet
	# dann sanft ein und ist am Ende wieder voll frei - kein Sprung zur Maus.
	rig.set_tilt_locked(true)
	rig._process(0.1)  # eingefroren
	var frozen := rig.global_transform
	rig.set_tilt_locked(false)  # Nachlauf startet
	# Halte-Phase (< TILT_RESUME_HOLD = 0.25 s): die Kamera steht weiter still.
	rig._process(0.1)
	assert_true(rig.global_transform.is_equal_approx(frozen), "erst hält die Kamera (Halte-Phase)")
	rig._process(0.1)  # gesamt 0.2 s < 0.25 s Halten
	assert_true(rig.global_transform.is_equal_approx(frozen), "noch in der Halte-Phase")
	assert_gt(rig._tilt_resume_time, 0.0, "Nachlauf läuft noch")
	# Nach Halten + Ease ist das Rundschauen wieder voll da.
	for i in 20:
		rig._process(0.1)  # +2 s, deutlich über HOLD + EASE
	assert_lt(rig._tilt_resume_time, 0.0, "Nachlauf abgeschlossen, Kamera wieder frei")

func test_regrabbing_during_the_resume_does_not_jump_on_release() -> void:
	# Regression: den Nachlauf (Halten + Ease) mit einer NEUEN Dreh-Geste
	# unterbrechen und wieder loslassen ließ die Kamera springen - es wurde vom
	# schon zur Maus vorgelaufenen tilt_offset eingeblendet statt von der zuletzt
	# GEZEIGTEN Abweichung (_applied_offset). Jetzt hält es bruchlos.
	rig.set_tilt_locked(true)
	rig._process(0.1)  # eingefroren
	rig.set_tilt_locked(false)  # erster Nachlauf startet
	for i in 8:
		rig._process(0.1)  # ~0.8 s: Halten vorbei, mitten im Einblenden (applied != tilt_offset)
	rig.set_tilt_locked(true)  # erneut gepackt, mitten im Nachlauf
	var shown := rig.global_transform  # das, was der Spieler gerade sieht
	rig._process(0.1)  # gesperrt: darf sich nicht bewegen
	assert_true(rig.global_transform.is_equal_approx(shown), "gesperrt hält die gezeigte Lage")
	rig.set_tilt_locked(false)  # zweiter Nachlauf
	rig._process(0.05)  # noch in der Halte-Phase
	assert_true(rig.global_transform.is_equal_approx(shown),
		"Loslassen mitten im Nachlauf springt nicht - es hält bei der gezeigten Lage")

func test_release_immediately_cancels_any_resume() -> void:
	rig.set_tilt_locked(true)
	rig.set_tilt_locked(false)  # würde sonst einen Nachlauf starten
	rig.release_tilt_immediately()
	assert_false(rig.tilt_locked)
	assert_lt(rig._tilt_resume_time, 0.0, "kein Nachlauf mehr aktiv")

func test_unlocked_process_recomputes_from_the_anchor() -> void:
	# Ohne Sperre baut _process das Transform aus dem Anker + Rundschauen neu auf
	# (die Ausrichtung bleibt am Anker verankert, Position unverändert).
	rig.tilt_locked = false
	rig._process(0.1)
	assert_almost_eq(rig.global_transform.origin, rig.anchor_origin, Vector3.ONE * 0.001,
		"Rundschauen dreht nur den Blick, es verschiebt die Kamera nicht")

func test_lock_defaults_off() -> void:
	assert_false(rig.tilt_locked, "standardmäßig ist die Kamera frei")

# --- Titelsicht --------------------------------------------------------------
# Der Startbildschirm liegt IM Hub-Fenster: die Kamera steht senkrecht darüber,
# das Fenster deckt das ganze Bild, und das Maus-Rundschauen ruht (es schwenkte
# sonst den Filz daneben ins Bild).

const TITLE_CENTER := Vector3(-26, 0, 0)
const TITLE_HALF := Vector2(14.25, 15.0)

func _aim_at_title() -> void:
	rig.configure_title_target(TITLE_CENTER, TITLE_HALF)
	rig.show_title(true)

func test_the_title_view_looks_straight_down_on_the_window() -> void:
	_aim_at_title()
	assert_eq(rig.mode, CameraRig.Mode.TITLE)
	var t := rig.global_transform
	assert_almost_eq(t.origin.x, TITLE_CENTER.x, 0.001, "senkrecht über der Fenstermitte")
	assert_almost_eq(t.origin.z, TITLE_CENTER.z, 0.001)
	assert_gt(t.origin.y, 0.0, "über dem Tisch")
	assert_almost_eq(-t.basis.z, Vector3.DOWN, Vector3.ONE * 0.001, "Blick senkrecht nach unten")
	assert_almost_eq(t.basis.y, Vector3(1, 0, 0), Vector3.ONE * 0.001, "Bild-Oben = Welt +X")

func test_the_title_view_keeps_the_whole_window_and_its_surroundings_in_sight() -> void:
	_aim_at_title()
	var distance := rig.title_distance()
	var vp_size := rig.get_viewport().get_visible_rect().size
	var half_h := tan(deg_to_rad(rig.fov * 0.5)) * distance
	var half_w := half_h * (vp_size.x / vp_size.y)
	assert_gt(half_w, TITLE_HALF.x, "seitlich bleibt Tisch im Blick (die Würfel-Ablage)")
	assert_gt(half_h, TITLE_HALF.y, "oben und unten ebenso")
	# Die WEITERE Achse schlägt an; sie liegt genau um die Zugabe daneben.
	assert_almost_eq(minf(half_w / TITLE_HALF.x, half_h / TITLE_HALF.y),
		CameraRig.TITLE_MARGIN, 0.001, "das Fenster steht ganz im Bild")

func test_the_camera_stands_still_in_the_title_view() -> void:
	_aim_at_title()
	var before := rig.global_transform
	rig._process(0.1)
	assert_eq(rig.global_transform, before, "kein Rundschauen im Titel-HUD")

func test_the_reveal_leaves_the_title_for_the_overview() -> void:
	_aim_at_title()
	rig.reveal_table()
	assert_eq(rig.mode, CameraRig.Mode.OVERVIEW)
	assert_true(rig.is_animating, "der Rückzieher läuft")
