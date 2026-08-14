extends GutTest
## Test der Kamera-Sperre (CameraRig.tilt_locked): solange gesetzt, hält die
## Kamera ihre Ausrichtung und ignoriert das Maus-Rundschauen - genutzt beim
## Ziehen eines Grubenwürfels, damit die Geste nicht den Blick schwenkt.

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

# --- Werkbank-Nahsicht -------------------------------------------------------
# Zweite Zoomstufe der Werkbank (Doppelklick auf freie Fläche): rahmt Fenster
# und Schubladen randvoll, die Trays fallen aus dem Bild, die Kamera steht still.

const WORKSHOP_CENTER := Vector3(-24, 0, 22)
const CLOSE_CENTER := Vector3(-27, 0, 22)
## Proportionen der echten Werkbank-Ecke (breiter als hoch, aber flacher als das
## Bild): so schlägt die HÖHE an, und genau daraus lebt diese Zoomstufe.
const CLOSE_HALF := Vector2(12.9, 9.1)
const CLOSE_BOTTOM := Vector3(-27 - 9.1, 0, 22)  # Mitte der Unterkante (-X = Bild-unten)
## Halbe Ausmaße der GANZEN Ecke - Trays, Fenster UND Schürze - am echten Tisch.
const WIDE_HALF := Vector2(12.2, 14.65)
const WIDE_BOTTOM := Vector3(-24 - 14.65, 0, 22)
const WIDE_TOP := Vector3(-24 + 14.65, 0, 22)

func _aim_at_workshop() -> void:
	# GUT läuft in einem QUADRATISCHEN Viewport - dort schlüge die Breite an und
	# die Zoomstufe stünde weit weg. Für die Höhenfrage muss das Bild breit sein.
	get_viewport().size = Vector2i(1600, 900)
	rig.configure_workshop_target(WORKSHOP_CENTER, WIDE_HALF)
	rig.configure_workshop_close_target(CLOSE_CENTER, CLOSE_HALF)
	rig.zoom_to(CameraRig.Mode.WORKSHOP)
	rig.is_animating = false  # Fahrt überspringen, die Lage steht

## Bildhöhe eines Weltpunkts in Normalkoordinaten (-1 = unterer Rand, +1 = oben).
func _frame_height(point: Vector3) -> float:
	var to_point := point - rig.anchor_origin
	return to_point.dot(rig.anchor_basis.y) \
		/ (to_point.dot(-rig.anchor_basis.z) * tan(deg_to_rad(rig.fov * 0.5)))

func test_the_close_step_moves_in_and_keeps_the_workshop_mode() -> void:
	_aim_at_workshop()
	var wide_distance := rig.global_transform.origin.distance_to(WORKSHOP_CENTER)
	rig.zoom_workshop_close()
	assert_true(rig.workshop_close, "die Nahsicht steht")
	assert_eq(rig.mode, CameraRig.Mode.WORKSHOP,
		"derselbe Arbeitsplatz - Klickweiterleitung und Zeremonie bleiben gültig")
	assert_lt(rig.anchor_origin.distance_to(CLOSE_CENTER), wide_distance,
		"die zweite Stufe steht näher als die erste")

func test_the_close_step_looks_down_more_steeply_than_the_other_zooms() -> void:
	_aim_at_workshop()
	var wide_pitch := (-rig.anchor_basis.z).angle_to(Vector3.DOWN)
	rig.zoom_workshop_close()
	var close_pitch := (-rig.anchor_basis.z).angle_to(Vector3.DOWN)
	assert_lt(close_pitch, wide_pitch, "die Nahsicht blickt steiler von oben")
	assert_almost_eq(rad_to_deg(close_pitch), CameraRig.WORKSHOP_CLOSE_TILT_DEGREES, 0.01)
	assert_almost_eq(rig.anchor_basis.x, Vector3(0, 0, 1), Vector3.ONE * 0.001,
		"Bild-Rechts bleibt Welt +Z wie bei allen anderen Blickwinkeln")

func test_the_tilt_family_spans_title_and_zoom() -> void:
	assert_true(CameraRig.tilted_basis(0.0).is_equal_approx(CameraRig.TITLE_BASIS),
		"0 Grad = die senkrechte Titelsicht")
	assert_true(CameraRig.tilted_basis(15.0).is_equal_approx(CameraRig.ZOOM_BASIS),
		"15 Grad = der übliche Zoomblick")

func test_a_tall_window_parks_the_spare_room_below_the_corner() -> void:
	# Hochformatiges Fenster: die BREITE schlägt an, senkrecht bleibt Luft übrig.
	# Die muss UNTER die Ecke (nackter Filz) - oben lägen die Trays im Bild.
	_aim_at_workshop()
	get_viewport().size = Vector2i(900, 1000)
	rig.zoom_workshop_close()
	var corner_top := CLOSE_CENTER + Vector3(CLOSE_HALF.y, 0, 0)
	assert_almost_eq(_frame_height(corner_top), 1.0, 0.02,
		"die Oberkante sitzt am oberen Bildrand, die Luft sammelt sich unten")
	assert_gt(_frame_height(CLOSE_BOTTOM), -1.0,
		"die Unterkante steht dann sichtbar im Bild, nicht am Rand")

func test_the_close_step_announces_itself_even_though_the_mode_is_unchanged() -> void:
	# Die Nahsicht wechselt den Modus NICHT - trotzdem muss scene_root nachziehen
	# (Spiegelung aus). Ohne das Signal müsste jeder Aufrufer daran denken.
	_aim_at_workshop()
	var seen: Array[int] = []
	rig.mode_changed.connect(func(m: CameraRig.Mode) -> void: seen.append(int(m)))
	rig.zoom_workshop_close()
	rig.zoom_workshop_wide()
	assert_eq(seen, [int(CameraRig.Mode.WORKSHOP), int(CameraRig.Mode.WORKSHOP)] as Array[int],
		"hin und zurück melden sich beide")

func test_the_close_step_keeps_the_whole_corner_in_frame() -> void:
	# Zugabe ≥ 1: die Ecke passt IMMER ganz ins Bild, oben wie unten.
	_aim_at_workshop()
	rig.zoom_workshop_close()
	assert_gte(CameraRig.WORKSHOP_CLOSE_MARGIN, 1.0, "sonst wird die Ecke beschnitten")
	assert_gt(_frame_height(CLOSE_BOTTOM), -1.0, "die Unterkante steht im Bild")
	assert_lte(_frame_height(CLOSE_CENTER + Vector3(CLOSE_HALF.y, 0, 0)), 1.0001,
		"und die Oberkante ebenso")

func test_the_close_step_fills_the_frame_up_to_the_corners_top_edge() -> void:
	# Die Ecke füllt das Bild bis oben - über ihrer Oberkante ist kein Platz
	# mehr, und dort beginnt die Tray-Reihe. Der Höhenanschlag ist die
	# eigentliche Forderung an diese Zoomstufe.
	_aim_at_workshop()
	rig.zoom_workshop_close()
	var corner_top := CLOSE_CENTER + Vector3(CLOSE_HALF.y, 0, 0)  # +X = Bild-oben
	var top_height := _frame_height(corner_top)
	assert_almost_eq(top_height, 1.0, 0.001,
		"die Oberkante der Ecke schließt mit dem oberen Bildrand ab - die Luft liegt unten")

func test_the_camera_stands_still_in_the_close_view() -> void:
	_aim_at_workshop()
	rig.zoom_workshop_close()
	rig.is_animating = false
	var before := rig.global_transform
	rig._process(0.1)
	assert_eq(rig.global_transform, before, "kein Rundschauen in der Nahsicht")

func test_the_camera_still_looks_around_in_the_wide_workshop_view() -> void:
	_aim_at_workshop()
	assert_false(rig.workshop_close, "die erste Stufe ist die weite")
	rig._process(0.1)
	assert_eq(rig.mode, CameraRig.Mode.WORKSHOP)
	assert_false(rig.workshop_close, "das Rundschauen läuft dort weiter")

func test_stepping_back_returns_to_the_wide_workshop_not_the_overview() -> void:
	_aim_at_workshop()
	rig.zoom_workshop_close()
	rig.zoom_workshop_wide()
	assert_false(rig.workshop_close)
	assert_eq(rig.mode, CameraRig.Mode.WORKSHOP, "eine Stufe zurück, nicht ganz raus")
	assert_almost_eq(rig.anchor_origin,
		WORKSHOP_CENTER - CameraRig.ZOOM_FORWARD * rig.workshop_wide_distance(),
		Vector3.ONE * 0.001, "wieder die weite Werkbank-Lage")

## Die weite Sicht rahmt die GANZE Ecke, und die untere Kante ist die harte: sie
## liegt näher an der geneigten Kamera und bildet sich darum größer ab.
func test_the_wide_step_frames_the_whole_corner_including_the_near_edge() -> void:
	_aim_at_workshop()
	assert_gt(rig.workshop_wide_distance(),
		CameraRig.ZOOM_DISTANCE + CameraRig.WORKSHOP_ZOOM_DISTANCE_BONUS,
		"die gewachsene Ecke braucht mehr Abstand als der alte feste")
	assert_lte(absf(_frame_height(WIDE_BOTTOM)), 1.0, "die Buchten stehen im Bild")
	assert_lte(absf(_frame_height(WIDE_TOP)), 1.0, "und die Trays ebenso")
	assert_gt(absf(_frame_height(WIDE_BOTTOM)), absf(_frame_height(WIDE_TOP)),
		"die nähere Kante füllt mehr Bild - genau darum reicht eine Höhenrechnung nicht")

func test_leaving_the_workshop_drops_the_close_flag() -> void:
	for leave in ["zoom_out", "pit", "title"]:
		_aim_at_workshop()
		rig.zoom_workshop_close()
		match leave:
			"zoom_out":
				rig.zoom_out()
			"pit":
				rig.zoom_to(CameraRig.Mode.PIT)
			"title":
				rig.show_title(true)
		assert_false(rig.workshop_close, "%s verlässt die Nahsicht" % leave)

# --- Werkstück-Sicht ---------------------------------------------------------
# Dritte Werkbank-Stufe: der schwebende Gravur-Würfel allein im Bild. Der Modus
# bleibt WORKSHOP (Klickweiterleitung und Zeremonie gelten weiter), die Kamera
# steht still - gedreht wird der Würfel, nicht der Blick.

const DIE_CENTER := Vector3(-27, 2.22, 22)
const DIE_HALF := 0.6 * sqrt(3.0)  # halbe Raumdiagonale eines Tray-Würfels

func test_the_die_view_moves_in_and_keeps_the_workshop_mode() -> void:
	_aim_at_workshop()
	var wide_distance := rig.anchor_origin.distance_to(WORKSHOP_CENTER)
	rig.zoom_die_focus(DIE_CENTER, DIE_HALF)
	assert_true(rig.die_focus, "die Werkstück-Sicht steht")
	assert_eq(rig.mode, CameraRig.Mode.WORKSHOP, "derselbe Arbeitsplatz")
	assert_lt(rig.anchor_origin.distance_to(DIE_CENTER), wide_distance,
		"sie steht näher als die weite Werkbank")

func test_the_die_stays_in_frame_in_every_rotation() -> void:
	# Gerechnet wird mit der halben RAUMDIAGONALE: beim Drehen darf der Würfel
	# nicht aus dem Bild wachsen.
	_aim_at_workshop()
	rig.zoom_die_focus(DIE_CENTER, DIE_HALF)
	var distance := rig.anchor_origin.distance_to(DIE_CENTER)
	var half_h := tan(deg_to_rad(rig.fov * 0.5)) * distance
	assert_gt(half_h, DIE_HALF, "der Würfel passt ganz ins Bild")
	assert_almost_eq(half_h / DIE_HALF, CameraRig.DIE_FOCUS_MARGIN, 0.001,
		"und ringsum bleibt die Zugabe als Luft stehen")

func test_the_camera_stands_still_at_the_die() -> void:
	_aim_at_workshop()
	rig.zoom_die_focus(DIE_CENTER, DIE_HALF)
	rig.is_animating = false
	var before := rig.global_transform
	rig._process(0.1)
	assert_eq(rig.global_transform, before, "kein Rundschauen an der Werkstück-Sicht")

func test_stepping_back_returns_to_the_step_the_grab_started_from() -> void:
	for from_close in [false, true]:
		_aim_at_workshop()
		if from_close:
			rig.zoom_workshop_close()
		rig.zoom_die_focus(DIE_CENTER, DIE_HALF)
		assert_false(rig.workshop_close, "die Werkstück-Sicht ist keine Nahsicht")
		rig.zoom_die_focus_out()
		assert_false(rig.die_focus)
		assert_eq(rig.workshop_close, from_close,
			"der Rückweg endet dort, wo der Griff begann")
		assert_eq(rig.mode, CameraRig.Mode.WORKSHOP, "eine Stufe zurück, nicht ganz raus")

func test_leaving_the_workshop_drops_the_die_focus() -> void:
	for leave in ["zoom_out", "pit", "title"]:
		_aim_at_workshop()
		rig.zoom_die_focus(DIE_CENTER, DIE_HALF)
		match leave:
			"zoom_out":
				rig.zoom_out()
			"pit":
				rig.zoom_to(CameraRig.Mode.PIT)
			"title":
				rig.show_title(true)
		assert_false(rig.die_focus, "%s verlässt die Werkstück-Sicht" % leave)

func test_the_die_view_announces_itself_even_though_the_mode_is_unchanged() -> void:
	_aim_at_workshop()
	var seen: Array[int] = []
	rig.mode_changed.connect(func(m: CameraRig.Mode) -> void: seen.append(int(m)))
	rig.zoom_die_focus(DIE_CENTER, DIE_HALF)
	rig.zoom_die_focus_out()
	assert_eq(seen, [int(CameraRig.Mode.WORKSHOP), int(CameraRig.Mode.WORKSHOP)] as Array[int],
		"hin und zurück melden sich beide")

func test_the_grabbed_die_starts_in_a_three_quarter_pose() -> void:
	# Aus der Zoom-Basis heraus gedreht: von der Kamera aus sind DREI Seiten zu
	# sehen, sonst wäre der Würfel bloß ein Quadrat.
	var basis := CameraRig.die_focus_basis()
	var forward := -CameraRig.ZOOM_BASIS.z  # Blickrichtung der Werkstück-Kamera
	var facing := 0
	for axis: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP,
			Vector3.DOWN, Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		if (basis * axis).dot(-forward) > DieFaceDisplay.FACE_FRONT_MIN_DOT:
			facing += 1
	assert_eq(facing, 3, "drei Seiten liegen zur Kamera")

func test_the_close_step_needs_the_workshop_mode() -> void:
	rig.configure_workshop_close_target(CLOSE_CENTER, CLOSE_HALF)
	rig.zoom_to(CameraRig.Mode.PIT)
	rig.zoom_workshop_close()
	assert_false(rig.workshop_close, "aus der Grube heraus gibt es keine Werkbank-Nahsicht")
	assert_eq(rig.mode, CameraRig.Mode.PIT)

# --- Freikamera (WASD + Mausrad) ---------------------------------------------
# Zwei Systeme, die einander ausschließen: die Freikamera steht die ganze Zeit
# auf OVERVIEW, parkt beim Loslassen dort, wo sie ist, und wird NUR von einer
# gerechneten Fahrt verlassen - _animate_to ist der eine Ausstieg.

const PIT_POINT := Vector3(4, 0, 0)
const HUB_POINT := Vector3(-24, 0, 0)
const SCORE_POINT := Vector3(-4, 0, 0)

## Bringt die Kamera an einer Station zur Ruhe (die Fahrt wird übersprungen).
func _stand_at(station: CameraRig.Mode) -> void:
	rig.configure_pit_target(PIT_POINT)
	rig.configure_hub_target(HUB_POINT)
	rig.configure_score_target(SCORE_POINT)
	rig.zoom_to(station)
	rig.is_animating = false
	rig.global_transform = Transform3D(rig.anchor_basis, rig.anchor_origin)

func test_the_key_axes_lie_flat_on_the_table() -> void:
	# Bild-Rechts = Welt +Z, Bild-Oben = Welt +X: abgeleitet aus der Zoom-Basis,
	# nicht getippt - sonst hinge die Laufrichtung an einem Vorzeichen.
	assert_almost_eq(CameraRig.GLIDE_RIGHT, Vector3(0, 0, 1), Vector3.ONE * 0.001)
	assert_almost_eq(CameraRig.GLIDE_UP, Vector3(1, 0, 0), Vector3.ONE * 0.001)

func test_the_free_camera_stays_over_the_display_surface() -> void:
	var bounds := Rect2(-30, -40, 60, 80)
	assert_almost_eq(CameraRig.clamp_to_bounds(Vector3(0, 0, 5), bounds, 6.0),
		Vector3(0, 0, 5), Vector3.ONE * 0.001, "drinnen bleibt der Punkt unberührt")
	var out := CameraRig.clamp_to_bounds(Vector3(500, 0, -500), bounds, 6.0)
	assert_almost_eq(out, Vector3(36, 0, -46), Vector3.ONE * 0.001,
		"draußen klemmt es auf das Rechteck plus Zugabe")

func test_the_speed_follows_the_height_but_stays_steerable() -> void:
	# Kartengrammatik: hoch oben weit ausgreifen, dicht über den Würfeln fein -
	# aber nie so langsam, dass es kriecht, und nie so schnell, dass es entgleitet.
	assert_almost_eq(CameraRig.free_speed(CameraRig.ZOOM_DISTANCE),
		CameraRig.GLIDE_SPEED, 0.001, "auf Zoom-Höhe gilt der Gefühlswert selbst")
	assert_lt(CameraRig.free_speed(CameraRig.ZOOM_DISTANCE * 0.5),
		CameraRig.free_speed(CameraRig.ZOOM_DISTANCE), "tiefer ist langsamer")
	assert_eq(CameraRig.free_speed(0.01), CameraRig.FREE_SPEED_MIN, "unten hält der Boden")
	assert_eq(CameraRig.free_speed(10000.0), CameraRig.FREE_SPEED_MAX, "oben die Decke")

func test_a_wheel_notch_scales_the_distance_and_stops_at_the_limits() -> void:
	var near := CameraRig.zoom_step_distance(20.0, 1.0, 2.5, 70.0)
	assert_almost_eq(near, 20.0 * (1.0 - CameraRig.FREE_ZOOM_STEP), 0.001,
		"eine Kerbe heran nimmt denselben ANTEIL, egal auf welcher Höhe")
	assert_gt(CameraRig.zoom_step_distance(20.0, -1.0, 2.5, 70.0), 20.0, "und zurück hinaus")
	assert_eq(CameraRig.zoom_step_distance(2.5, 5.0, 2.5, 70.0), 2.5, "unten ist Schluss")
	assert_eq(CameraRig.zoom_step_distance(70.0, -5.0, 2.5, 70.0), 70.0, "oben auch")

func test_zooming_leaves_the_point_under_the_cursor_where_it_is() -> void:
	# Der Blickpunkt wandert um denselben Faktor auf den Cursor zu, um den die
	# Distanz schrumpft - nur so bleibt liegen, worauf man zeigt.
	var cursor := Vector3(10, 0, -4)
	assert_almost_eq(CameraRig.zoom_anchor(Vector3.ZERO, cursor, 0.5),
		Vector3(5, 0, -2), Vector3.ONE * 0.001)
	assert_almost_eq(CameraRig.zoom_anchor(Vector3.ZERO, cursor, 1.0),
		Vector3.ZERO, Vector3.ONE * 0.001, "ohne Zoom wandert nichts")
	assert_almost_eq(CameraRig.zoom_anchor(cursor, cursor, 0.3),
		cursor, Vector3.ONE * 0.001, "auf dem Cursor selbst bleibt alles stehen")

func test_the_free_camera_drops_the_mode_without_flying_anywhere() -> void:
	_stand_at(CameraRig.Mode.PIT)
	var before := rig.global_transform
	assert_true(rig.begin_free(), "aus einer Station heraus geht es frei weiter")
	assert_true(rig.free_camera)
	assert_eq(rig.mode, CameraRig.Mode.OVERVIEW, "eine freie Kamera hat keinen Fokus")
	assert_false(rig.is_animating, "aber sie FÄHRT nicht in die Übersicht")
	assert_eq(rig.global_transform, before, "die Lage steht noch, wo sie stand")
	assert_almost_eq(rig._free_target, Vector3(PIT_POINT.x, 0.0, PIT_POINT.z),
		Vector3.ONE * 0.05, "der Blickpunkt der Grube ist der Ausgangspunkt")

func test_the_keys_move_the_look_point_along_the_image_axes_and_then_park() -> void:
	_stand_at(CameraRig.Mode.PIT)
	rig.begin_free()
	var start: Vector3 = rig._free_target
	for i in 10:
		rig.free_step(Vector2(0, 1), 0.1)  # W
	assert_gt(rig._free_target.x, start.x + 10.0, "W schiebt den Blick nach Welt +X")
	assert_almost_eq(rig._free_target.z, start.z, 0.001, "und seitlich nicht")
	start = rig._free_target
	for i in 10:
		rig.free_step(Vector2(1, 0), 0.1)  # D
	assert_gt(rig._free_target.z, start.z + 10.0, "D schiebt ihn nach Welt +Z")
	# Loslassen rastet nirgends ein: die Kamera bleibt stehen, wo sie steht.
	for i in 10:
		rig.free_step(Vector2.ZERO, 0.1)
	assert_true(rig.free_camera, "die Freikamera bleibt stehen")
	assert_false(rig.is_animating, "und fährt zu keiner Station")
	assert_almost_eq(rig._free_velocity.length(), 0.0, 0.5, "sie läuft nur aus")

func test_the_close_range_travels_slower_than_the_high_view() -> void:
	_stand_at(CameraRig.Mode.PIT)
	rig.begin_free()
	rig._free_distance = CameraRig.ZOOM_DISTANCE
	rig._free_zoom_goal = rig._free_distance
	var high := rig._free_target
	for i in 5:
		rig.free_step(Vector2(1, 0), 0.05)
	var high_way: float = rig._free_target.distance_to(high)
	rig._free_distance = CameraRig.FREE_ZOOM_MIN
	rig._free_zoom_goal = rig._free_distance
	rig._free_velocity = Vector3.ZERO
	var low := rig._free_target
	for i in 5:
		rig.free_step(Vector2(1, 0), 0.05)
	assert_lt(rig._free_target.distance_to(low), high_way,
		"dicht über dem Tisch greift dieselbe Taste kürzer aus")

func test_the_wheel_drives_the_distance_into_its_limits() -> void:
	_stand_at(CameraRig.Mode.PIT)
	rig.begin_free()
	for i in 60:
		rig.free_zoom(1.0)
	assert_almost_eq(rig._free_zoom_goal, CameraRig.FREE_ZOOM_MIN, 0.001,
		"heran endet an der Untergrenze")
	for i in 200:
		rig.free_zoom(-1.0)
	assert_almost_eq(rig._free_zoom_goal, rig.free_zoom_max(), 0.001,
		"und hinaus ein Stück über der Übersicht")
	# Die gezeigte Distanz läuft dem Ziel nach, sie springt nicht.
	var goal: float = rig._free_zoom_goal
	var before: float = rig._free_distance
	rig.free_step(Vector2.ZERO, 0.016)
	assert_gt(rig._free_distance, before, "ein Bild später ist sie unterwegs")
	assert_lt(rig._free_distance, goal, "aber noch nicht da")
	for i in 60:
		rig.free_step(Vector2.ZERO, 0.016)
	assert_almost_eq(rig._free_distance, goal, 0.01, "kommt aber an")

func test_a_click_flight_wins_and_ends_the_free_camera() -> void:
	_stand_at(CameraRig.Mode.PIT)
	rig.begin_free()
	rig.free_step(Vector2(1, 1), 0.2)
	rig.zoom_to(CameraRig.Mode.HUB)
	assert_false(rig.free_camera, "eine gerechnete Fahrt gewinnt immer")
	assert_eq(rig.mode, CameraRig.Mode.HUB, "und landet an ihrer Station")
	assert_true(rig.is_animating)

func test_the_way_home_flies_although_the_mode_already_says_overview() -> void:
	_stand_at(CameraRig.Mode.PIT)
	rig.begin_free()
	rig.free_step(Vector2(1, 0), 0.5)
	rig.zoom_out()
	assert_false(rig.free_camera)
	assert_true(rig.is_animating, "sonst stünde die Kamera mitten auf dem Tisch")
	assert_almost_eq(rig.anchor_origin, rig.base_origin, Vector3.ONE * 0.001)

func test_a_running_flight_is_untouchable() -> void:
	_stand_at(CameraRig.Mode.PIT)
	rig.zoom_to(CameraRig.Mode.SCORE)  # Klickfahrt läuft
	assert_false(rig.begin_free(), "eine Fahrt hat ein Ziel und wird nicht aufgebrochen")
	assert_false(rig.free_camera)

func test_the_close_steps_stay_dead_to_the_free_camera() -> void:
	_aim_at_workshop()
	rig.zoom_workshop_close()
	rig.is_animating = false
	assert_false(rig.begin_free(), "in der Nahsicht ist der Rahmen randvoll")
	rig.zoom_workshop_wide()
	rig.is_animating = false
	rig.zoom_die_focus(DIE_CENTER, DIE_HALF)
	rig.is_animating = false
	assert_false(rig.begin_free(), "am Werkstück dreht der Spieler den Würfel, nicht den Blick")
	rig.show_title(true)
	assert_false(rig.begin_free(), "und im Titel-HUD steht die Kamera still")

func test_the_title_takes_the_camera_back_even_without_a_flight() -> void:
	_stand_at(CameraRig.Mode.PIT)
	rig.begin_free()
	rig.show_title(true)  # Spielstart: harter Sprung, ohne _animate_to
	assert_false(rig.free_camera, "auch der harte Sprung beendet die Freikamera")

