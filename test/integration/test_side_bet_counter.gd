extends GutTest
## Der WETT-TRESEN des Nebenwetten-Fensters: DER SETZEN-KNOPF IST DER STELLPLATZ.
## Das Fenster meldet nur Geometrie und die reine Regel der Timeline - Körper stellt
## scene_root. Getestet wird darum, was das Fenster verspricht: ein Plot je Angebot,
## rechts in SEINER Zeile, byte-stabile Rechtecke über Setzen, Fassung und Modi
## hinweg, und die Regel, wer wann auf dem Tresen liegt.

var panel: SideBetPanel
var run: GameRun

## Die echten Maße des Tisch-Fensters (cluster_rect).
const WINDOW_SIZE := Vector2(996, 591)

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 100
	run.hub_level = GameRun.HUB_SIDE_BETS_LEVEL
	panel = SideBetPanel.new()
	panel.size = WINDOW_SIZE
	add_child_autofree(panel)
	panel.run = run

func _offers(ids: Array) -> Array[SideBet]:
	var bets: Array[SideBet] = []
	for id in ids:
		for t in SideBet.TEMPLATES:
			if t["id"] == id:
				bets.append(SideBet._from_template(t))
	return bets

func _money_offers() -> Array[SideBet]:
	return _offers(["two_pair", "big_hand", "economist"])

func _bools(values: Array) -> Array[bool]:
	var out: Array[bool] = []
	out.assign(values)
	return out

func _bets(values: Array) -> Array[SideBet]:
	var out: Array[SideBet] = []
	out.assign(values)
	return out

# --- Geometrie ------------------------------------------------------------------

func test_one_plot_per_offer():
	assert_eq(panel.counter_local_rects().size(), SideBetPanel.OFFER_COUNT,
		"je Angebot EIN Stellplatz - der Setzen-Knopf")
	assert_eq(panel.counter_rects().size(), panel.counter_local_rects().size())

func test_plots_lie_inside_the_window_and_do_not_overlap():
	var frame := Rect2(Vector2.ZERO, panel.size)
	var rects := panel.counter_local_rects()
	for rect in rects:
		assert_true(frame.encloses(rect), "Platz liegt im Fenster: %s" % rect)
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			assert_false(rects[i].intersects(rects[j]),
				"Plätze %d und %d überlappen" % [i, j])

## Die Plätze ziehen SENKRECHT durch, einer je Angebots-Zeile, und jeder steht am
## rechten Zeilenrand - dort, wo früher der Kauf-Knopf saß.
func test_plots_stand_at_the_right_edge_of_their_offer_rows():
	var rects := panel.counter_local_rects()
	var u := panel.size.x / 100.0
	for i in rects.size():
		assert_almost_eq(rects[i].end.x, panel.size.x - u * SideBetPanel.MARGIN_UNITS,
			0.001, "Platz %d steht rechts in seiner Zeile" % i)
		assert_almost_eq(rects[i].position.x, rects[0].position.x, 0.001,
			"alle Plätze stehen in einer Spalte")
	for i in range(1, rects.size()):
		assert_gt(rects[i].position.y, rects[i - 1].position.y,
			"und untereinander in Angebots-Reihenfolge")

## Der Text steht LINKS daneben und hat wirklich Platz: kein Plot frißt seine Zeile.
func test_the_row_text_keeps_room_left_of_its_plot():
	var rects := panel.counter_local_rects()
	var u := panel.size.x / 100.0
	var text := rects[0].position.x - u * (SideBetPanel.MARGIN_UNITS
		+ SideBetPanel.PLOT_GAP_UNITS)
	assert_gt(text, rects[0].size.x,
		"die Zeile trägt mehr Text- als Plotbreite (%.1f px)" % text)

## Der KOPF (Titel und Anrede) endet über der ersten Zeile - er verschiebt nichts,
## und die gemessene Luft über der Zeile trägt ihn wirklich.
func test_the_head_ends_above_the_first_row():
	var rects := panel.counter_local_rects()
	panel.open_betting(_money_offers())
	await wait_frames(2)
	var content: Control = null
	for child in panel.get_children():
		if child is VBoxContainer:
			content = child
	assert_not_null(content, "die Seite steht")
	var head := content.position.y
	for child in content.get_children():
		head += (child as Control).get_combined_minimum_size().y
	head += content.get_theme_constant("separation") \
		* maxf(content.get_child_count() - 1, 0)
	assert_lt(head, rects[0].position.y,
		"Titel und Anrede stehen über der ersten Zeile (%.1f < %.1f)"
			% [head, rects[0].position.y])

## Der Plot IST das Rechteck des Sitzes - gemessen, nicht behauptet.
func test_the_seat_button_is_the_plot():
	panel.open_betting(_money_offers())
	await wait_frames(2)
	var rects := panel.counter_local_rects()
	for i in SideBetPanel.OFFER_COUNT:
		var seat: Button = panel.bet_buttons[i]
		assert_almost_eq(seat.position.x, rects[i].position.x, 0.001)
		assert_almost_eq(seat.position.y, rects[i].position.y, 0.001)
		assert_almost_eq(seat.size.x, rects[i].size.x, 0.001)
		assert_almost_eq(seat.size.y, rects[i].size.y, 0.001)

## Und die GRUBE ist dieser Knopf, exakt: dasselbe Rechteck, dieselbe Eckenrundung.
## Die gemeldete Rundung IST die der Fassung - eine zweite Zahl wäre eine zweite Form.
func test_the_reported_pit_radius_is_the_frames_own_corner_radius():
	panel.open_betting(_money_offers())
	await wait_frames(2)
	panel._on_bet_pressed(0)
	await wait_frames(2)
	var seat: Button = panel.bet_buttons[0]
	var radius := panel.counter_plot_radius()
	for state: String in ["normal", "disabled"]:
		var box: StyleBoxFlat = seat.get_theme_stylebox(state)
		assert_eq(float(box.corner_radius_top_left), radius,
			"die Fassung rundet mit der gemeldeten Zahl (%s)" % state)
	assert_gt(radius, 0.0, "eine Rundung, die man auch sieht")

# --- Der SITZ auf dem Plot -------------------------------------------------------
# Gewöhnlich steht der GEWINN mittig auf seinem Plot; nur der Steuer-Plot teilt sich
# (Zählplatte links, Gewinn rechts daneben). Jeder rückt nur so weit ein, dass er den
# Plot nicht verläßt.

func test_a_prize_stands_centred_on_its_plot():
	var plot := Rect2(Vector2(100, 50), Vector2(260, 124))
	for footprint: Vector2 in [Vector2(60, 60), Vector2(150, 70), Vector2.ZERO]:
		assert_true(SideBetPanel.seat_in(plot, footprint).is_equal_approx(
			plot.get_center()), "der Gewinn steht mittig (%s)" % footprint)

func test_a_tax_plot_splits_plate_left_and_prize_right():
	var plot := Rect2(Vector2(100, 50), Vector2(260, 124))
	var plate := SideBetPanel.seat_in(plot, Vector2(46.7, 46.7), SideBetPanel.SEAT_LEFT)
	var prize := SideBetPanel.seat_in(plot, Vector2(147.3, 69.0), SideBetPanel.SEAT_RIGHT)
	assert_lt(plate.x, plot.get_center().x, "die Zählplatte steht links")
	assert_gt(prize.x, plot.get_center().x, "ihr Gewinn rechts daneben")
	assert_almost_eq(plate.y, plot.get_center().y, 0.001)
	assert_almost_eq(prize.y, plot.get_center().y, 0.001)

## Die GEMESSENEN Fußabdrücke des Katalogs passen wirklich nebeneinander in den Plot:
## Platte 46,7 px und der breiteste Steuer-Gewinn (Würfelzoll, 147,3 px).
func test_both_tax_bodies_fit_beside_each_other_without_touching():
	var plot := Rect2(Vector2.ZERO, Vector2(258.96, 124.5))
	var plate_span := Vector2(46.7, 46.7)
	var prize_span := Vector2(147.3, 69.0)
	var plate := SideBetPanel.seat_in(plot, plate_span, SideBetPanel.SEAT_LEFT)
	var prize := SideBetPanel.seat_in(plot, prize_span, SideBetPanel.SEAT_RIGHT)
	var plate_rect := Rect2(plate - plate_span * 0.5, plate_span)
	var prize_rect := Rect2(prize - prize_span * 0.5, prize_span)
	assert_gte(plate_rect.position.x, plot.position.x - 0.001, "die Platte bleibt drin")
	assert_lte(prize_rect.end.x, plot.end.x + 0.001, "der Gewinn ebenso")
	assert_gt(prize_rect.position.x, plate_rect.end.x,
		"und zwischen beiden bleibt eine Fuge (%.1f px)"
			% (prize_rect.position.x - plate_rect.end.x))

## Was in den Plot paßt, verläßt ihn nicht - der Körper rückt lieber ein.
func test_a_wide_body_is_pulled_back_into_its_plot():
	var plot := Rect2(Vector2(100, 50), Vector2(260, 124))
	var wide := Vector2(220, 60)
	assert_almost_eq(SideBetPanel.seat_in(plot, wide, SideBetPanel.SEAT_RIGHT).x,
		plot.end.x - wide.x * 0.5, 0.001, "bündig an der rechten Plotkante")
	assert_almost_eq(SideBetPanel.seat_in(plot, wide, SideBetPanel.SEAT_LEFT).x,
		plot.position.x + wide.x * 0.5, 0.001)

## Was breiter ist als der ganze Plot, steht mittig und ragt nach BEIDEN Seiten
## hinaus - alles andere wäre eine Lüge über den Platz.
func test_a_body_wider_than_the_plot_stands_centred():
	var plot := Rect2(Vector2(100, 50), Vector2(260, 124))
	var huge := Vector2(320, 60)
	for side: int in [SideBetPanel.SEAT_FULL, SideBetPanel.SEAT_LEFT,
			SideBetPanel.SEAT_RIGHT]:
		assert_true(SideBetPanel.seat_in(plot, huge, side)
			.is_equal_approx(plot.get_center()))

# --- Byte-Stabilität ------------------------------------------------------------

func test_rects_are_identical_between_betting_and_progress():
	panel.open_betting(_money_offers())
	var betting := panel.counter_local_rects()
	panel.close_betting()
	var progress := panel.counter_local_rects()
	assert_eq(betting, progress, "der Tresen steht in beiden Modi gleich")

func test_rects_survive_placing_a_bet():
	panel.open_betting(_money_offers())
	var before := panel.counter_local_rects()
	panel._on_bet_pressed(0)
	assert_eq(panel.counter_local_rects(), before,
		"eine gesetzte Wette verrückt keinen Platz")

## Der Sitz RESTYLT zum Stellplatz - sein Rechteck bleibt dasselbe.
func test_the_seat_keeps_its_rect_when_it_becomes_the_frame():
	panel.open_betting(_money_offers())
	await wait_frames(2)
	var seat: Button = panel.bet_buttons[0]
	var before := Rect2(seat.position, seat.size)
	panel._on_bet_pressed(0)
	await wait_frames(2)
	assert_eq(Rect2(seat.position, seat.size), before,
		"aus dem Knopf wird die Fassung, das Rechteck bleibt")
	assert_true(seat.disabled, "gesetzt ist der Sitz kein Knopf mehr")

func test_rects_survive_a_progress_refresh():
	panel.open_betting(_money_offers())
	panel._on_bet_pressed(0)
	panel.close_betting()
	var before := panel.counter_local_rects()
	panel.update_progress({"hands_taken": 2, "best_hand_score": 120})
	assert_eq(panel.counter_local_rects(), before,
		"eine Fortschritts-Meldung verrückt keinen Platz")

# --- Die Regel der Timeline (rein) ----------------------------------------------

func _lies(stage: String, offers: Array[SideBet], placed: Array,
		fulfilled: Array = [], failed: Array = [], won: Array = []) -> Dictionary:
	return SideBetPanel.counter_lies(stage, offers, _bools(placed),
		_bets(fulfilled), _bets(failed), _bets(won))

func test_no_stage_shows_nothing():
	assert_eq(_lies(SideBetPanel.STAGE_NONE, _money_offers(),
		[true, true, true]).size(), 0)

func test_before_placing_nothing_stands_on_the_counter():
	assert_eq(_lies(SideBetPanel.STAGE_OPEN, _money_offers(),
		[false, false, false]).size(), 0,
		"vor dem Setzen ist der Tresen leer - der Knopf nennt den Preis")

## Vom EINSATZ liegt nach dem Kauf NICHTS: der Tisch hat ihn geschluckt. Was dasteht,
## ist der GEWINN - und weil "Doppelspiel" mitten in der Runde noch kippen kann,
## wartet er UNTEN in der offenen Grube.
func test_an_early_bet_parks_its_prize_in_the_pit():
	var lies := _lies(SideBetPanel.STAGE_OPEN, _money_offers(), [false, true, false])
	assert_eq(lies.size(), 1)
	assert_eq(lies.get(1), [SideBetPanel.LIE_PRIZE_PIT],
		"der Gewinn wartet unten - vom Einsatz liegt nichts, kein zweiter Körper")

## Eine grün startende Wette (sie kann nur noch scheitern) zeigt ihren Gewinn sofort
## ausgefahren.
func test_a_green_starting_bet_shows_its_prize_up():
	var offers := _money_offers()  # economist = FEW_DICE, startet ON_TRACK
	var lies := _lies(SideBetPanel.STAGE_ROUND, offers, [false, false, true])
	assert_eq(lies.get(2), [SideBetPanel.LIE_PRIZE_UP])

## Die Steuerwette ist die AUSNAHME: ihr Plot trägt ZWEI Körper - die wachsende
## Zählplatte und ihren Gewinn daneben.
func test_a_tax_bet_carries_its_tally_and_its_prize():
	var offers := _offers(["table_fee", "big_hand", "economist"])
	var lies := _lies(SideBetPanel.STAGE_OPEN, offers, [true, false, false])
	assert_eq(lies.get(0), [SideBetPanel.LIE_TALLY, SideBetPanel.LIE_PRIZE_UP],
		"Zählplatte links, Gewinn oben daneben")

## OPEN und ROUND tragen byteweise dasselbe - die Runde nimmt dem Tresen nichts weg;
## die Stufe entscheidet nur, ab wann die Melder feuern.
func test_open_and_round_carry_the_same():
	var offers := _money_offers()
	var open := _lies(SideBetPanel.STAGE_OPEN, offers, [true, true, true])
	var round_lies := _lies(SideBetPanel.STAGE_ROUND, offers, [true, true, true])
	assert_eq(open.size(), 3, "jede gesetzte Wette zeigt ihren Gewinn")
	assert_eq(round_lies, open)

## Die ERFÜLLUNG hebt den Gewinn aus der Grube: derselbe Platz, anderer ORT.
func test_fulfilment_lifts_the_prize_out_of_the_pit():
	var offers := _money_offers()
	var lies := _lies(SideBetPanel.STAGE_ROUND, offers, [true, true, true],
		[offers[1]])
	assert_eq(lies.get(1), [SideBetPanel.LIE_PRIZE_UP], "erfüllt heißt oben")
	assert_eq(lies.get(0), [SideBetPanel.LIE_PRIZE_PIT], "die anderen warten weiter")

## Und das SCHEITERN nimmt ihn fort - egal, ob er unten wartete oder oben stand.
func test_failure_takes_the_prize_away():
	var offers := _money_offers()
	var lies := _lies(SideBetPanel.STAGE_ROUND, offers, [true, true, true],
		[], [offers[1], offers[2]])
	assert_eq(lies.size(), 1, "zwei Gewinne sind eingezogen")
	assert_eq(lies.get(0), [SideBetPanel.LIE_PRIZE_PIT])

## Eine zahlungsunfähige Steuerwette hat nichts mehr auf dem Tresen zu suchen -
## Zählplatte UND Gewinn fahren hinaus.
func test_a_voided_tax_bet_loses_plate_and_prize():
	var offers := _offers(["table_fee", "big_hand", "economist"])
	offers[0].voided = true
	assert_false(_lies(SideBetPanel.STAGE_ROUND, offers, [true, true, true]).has(0),
		"die gerissene Wette fährt hinaus")

## In der Abrechnung steht allein, was gewonnen hat - das Haus nimmt den Rest.
func test_the_settlement_keeps_only_the_won_prizes():
	var offers := _offers(["table_fee", "big_hand", "economist"])
	var lies := _lies(SideBetPanel.STAGE_WON, offers, [true, true, true],
		[offers[1]], [], [offers[2]])
	assert_eq(lies.size(), 1, "Zählplatte und Verlorenes sind fort")
	assert_eq(lies.get(2), [SideBetPanel.LIE_PRIZE_UP])

## Ein schon aufgefahrener Gewinn bleibt in der Abrechnung stehen und fährt als
## Mitfahrer mit.
func test_an_early_winner_keeps_standing_in_the_settlement():
	var offers := _money_offers()
	var lies := _lies(SideBetPanel.STAGE_WON, offers, [true, true, true],
		[offers[1]], [], [offers[1]])
	assert_eq(lies.get(1), [SideBetPanel.LIE_PRIZE_UP])
	assert_eq(lies.size(), 1)

## Drei Wetten, drei UNABHÄNGIGE Zustände nebeneinander: eine wartet unten, eine
## steht oben, eine ist eingezogen.
func test_three_plots_carry_three_independent_states():
	var offers := _offers(["two_pair", "big_hand", "economist"])
	var lies := _lies(SideBetPanel.STAGE_ROUND, offers, [true, true, true],
		[offers[1]], [offers[2]])
	assert_eq(lies.get(0), [SideBetPanel.LIE_PRIZE_PIT])
	assert_eq(lies.get(1), [SideBetPanel.LIE_PRIZE_UP])
	assert_false(lies.has(2))

# --- Der Erfüllungs-Melder ------------------------------------------------------
# Er speist sich allein aus live_state - es gibt keine zweite Bedingungs-Auswertung.

func test_monotone_conditions_decide_early():
	for id in ["two_pair", "big_hand", "overclocker", "connoisseur", "comeback",
			"upper_class", "quick_start"]:
		assert_true(_offers([id])[0].decides_early(),
			"%s kann mitten in der Runde erfüllt sein" % id)

func test_end_of_round_conditions_do_not():
	for id in ["economist", "pawn", "efficiency", "small_fry", "no_scraps",
			"variety", "full_grip", "table_fee", "dice_toll"]:
		assert_false(_offers([id])[0].decides_early(),
			"%s entscheidet sich erst am Rundenende" % id)

func test_a_voided_bet_never_reports_fulfilled():
	var bet := _offers(["big_hand"])[0]
	bet.voided = true
	assert_false(bet.decides_early())

func test_the_reporter_flips_exactly_once():
	var bet := _offers(["big_hand"])[0]
	bet.target = 100
	assert_eq(bet.live_state({"best_hand_score": 40}), SideBet.Live.PENDING)
	assert_eq(bet.live_state({"best_hand_score": 120}), SideBet.Live.ON_TRACK)
	assert_eq(bet.live_state({"best_hand_score": 400}), SideBet.Live.ON_TRACK,
		"einmal erfüllt bleibt erfüllt - der Melder darf nur EINMAL zünden")

# --- Die Maschine des Tresens ---------------------------------------------------
# Je Plot EINE Sektion mit EIGENEM Loch - drei Wetten parken, fahren auf und gehen ab,
# ohne einander zu stören. Geprüft wird, was scene_root von ihr verlangt: der PARK ist
# ein Endzustand, jeder Abbruch schließt das Loch, und die Abgangs-Körper gibt die
# Maschine NIE selbst frei - darum führt scene_root seine eigene Abgangs-Liste.

const PARK_DEPTH := 0.9
## Wo die Platte dann steht: GANZ unten, so tief, wie die Fahrt kommt.
const PARK_Y := PARK_DEPTH

func _bet_shaft(holes: Dictionary, slot := TableScreen.PIT_SIDE_BET0,
		deep := 0.0) -> LiftShaftView:
	var shaft := LiftShaftView.new("BetShaft")
	add_child_autofree(shaft)
	shaft.opened.connect(func(_at: Vector3, _half: Vector2) -> void:
		holes[slot] = true)
	shaft.closed.connect(func() -> void:
		holes.erase(slot))
	shaft.setup(Vector3.ZERO, Vector2(1.0, 3.0),
		deep if deep > 0.0 else VitrineView.shaft_depth())
	return shaft

func test_every_plot_uses_its_own_pit_slot():
	assert_eq(TableScreen.PIT_SIDE_BET2, TableScreen.MAX_PITS - 1)
	for i in SideBetPanel.OFFER_COUNT:
		assert_ne(TableScreen.side_bet_pit(i), TableScreen.PIT_MAGAZIN,
			"die Magazin-Grube bleibt Platz null")

## Der PARK ist ein ENDZUSTAND, den der Schreiber DIREKT herstellt: Loch offen,
## Plattform unten - ohne Fahrt. Und settle_hard nimmt ihn ebenso hart zurück.
func test_the_park_state_can_be_written_hard_and_taken_back():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET1, PARK_DEPTH)
	shaft.park_hard()
	assert_true(holes.has(TableScreen.PIT_SIDE_BET1), "das Loch steht offen")
	assert_true(shaft.visible)
	assert_almost_eq(shaft.platform_y(), -PARK_Y, 0.0001,
		"die Plattform steht ganz unten")
	shaft.park_hard()  # idempotent
	assert_almost_eq(shaft.platform_y(), -PARK_Y, 0.0001)
	shaft.settle_hard()
	assert_false(holes.has(TableScreen.PIT_SIDE_BET1))
	assert_almost_eq(shaft.platform_y(), 0.0, 0.0001)

## EIN Maß, eine Frage: der Schacht sagt, wo "ganz unten" ist - und der PARK ist genau
## dort, auf VOLLER Schachttiefe. Die Grube ist so tief, wie die Fahrt kommt.
func test_the_park_height_is_the_whole_shaft():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, 2.4)
	assert_almost_eq(shaft.park_y(), 2.4, 0.0001, "volle Schachttiefe")
	assert_almost_eq(shaft.park_y(), shaft.depth, 0.0001, "genau das Fahrtmaß")
	assert_almost_eq(shaft.park_y(), shaft.drop(), 0.0001,
		"und dasselbe, um das die Ware unter ihrem Platz startet")
	shaft.park_hard()
	assert_almost_eq(shaft.platform_y(), -2.4, 0.0001,
		"die Platte steht am Grubenboden")

## Und der PARK-Zyklus endet wirklich dort: gesenkt bis auf Schachttiefe, Band-Schritt,
## und dort BLEIBT es - zurück hebt nichts mehr.
func test_run_park_stays_down_at_the_full_depth():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET1, 2.4)
	var prize := Node3D.new()
	add_child_autofree(prize)
	shaft.run_park([], [], [prize], [Vector3.ZERO], 0.0)
	await wait_seconds(LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME * 0.5)
	assert_almost_eq(prize.global_position.y, -2.4, 0.05,
		"unterwegs deckt das Display den Schacht")
	await wait_seconds(LiftShaftView.park_cycle_time() + 0.2)
	assert_true(holes.has(TableScreen.PIT_SIDE_BET1), "das Loch bleibt offen")
	assert_almost_eq(prize.global_position.y, -2.4, 0.01,
		"und der Gewinn wartet ganz unten")
	assert_almost_eq(shaft.platform_y(), -2.4, 0.01,
		"die Platte ebenso - sie fährt nicht wieder halb herauf")

## Der PARK-Zyklus endet UNTEN: der Gewinn steht sichtbar in der offenen Grube.
func test_run_park_ends_below_with_the_hole_open():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
	var prize := Node3D.new()
	add_child_autofree(prize)
	var seat := Vector3(0.0, 0.0, 1.0)
	shaft.run_park([], [], [prize], [seat], 0.0)
	await wait_seconds(LiftShaftView.park_cycle_time() + 0.1)
	assert_true(holes.has(TableScreen.PIT_SIDE_BET0), "das Loch BLEIBT offen")
	assert_almost_eq(shaft.platform_y(), -PARK_Y, 0.001)
	assert_almost_eq(prize.global_position.y, seat.y - PARK_Y, 0.01,
		"der Gewinn wartet unten auf der Platte")
	assert_almost_eq(prize.global_position.z, seat.z, 0.001,
		"und über seinem Sitz")

## Die AUFFAHRT aus dem Park: der Gewinn kommt herauf, das Loch schließt.
func test_run_rise_lifts_out_of_the_park_and_shuts():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
	var prize := Node3D.new()
	add_child_autofree(prize)
	var seat := Vector3(0.0, 0.0, 1.0)
	shaft.run_rise([prize], [seat], 0.0)
	await wait_seconds(LiftShaftView.LIFT_TIME * 0.5)
	assert_true(holes.has(TableScreen.PIT_SIDE_BET0), "unterwegs steht es offen")
	assert_lt(prize.global_position.y, seat.y, "und er ist noch unterwegs")
	await wait_seconds(LiftShaftView.rise_cycle_time() + 0.1)
	assert_false(holes.has(TableScreen.PIT_SIDE_BET0), "danach ist das Loch zu")
	assert_almost_eq(prize.global_position.y, seat.y, 0.001, "er steht oben")
	assert_almost_eq(shaft.platform_y(), 0.0, 0.001)

## Der ABGANG aus dem Park: was unten wartete, geht unten fort - es taucht NIE auf.
func test_run_leave_park_never_lets_the_ware_surface():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET2, PARK_DEPTH)
	var prize := Node3D.new()
	add_child_autofree(prize)
	var seat := Vector3(0.0, 0.0, 1.0)
	var swept: Array = []
	shaft.run_leave_park([prize], [seat], 0.0, func() -> void: swept.append(prize))
	var highest := -100.0
	for step in 8:
		await wait_seconds(LiftShaftView.PUSH_TIME / 8.0)
		highest = maxf(highest, prize.global_position.y)
	assert_lt(highest, -PARK_Y * 0.9,
		"die Ware bleibt tief im Schacht (%.3f)" % highest)
	await wait_seconds(LiftShaftView.leave_park_time() + 0.1)
	assert_eq(swept.size(), 1, "der Band-Schritt meldet sie als draußen")
	assert_false(holes.has(TableScreen.PIT_SIDE_BET2), "und das Loch ist zu")
	assert_almost_eq(shaft.platform_y(), 0.0, 0.001, "die leere Platte steht bündig")

## Geprüft wird jeder Schlag jedes Fahrplans - auch die drei neuen.
func test_every_abort_closes_the_hole_and_seats_the_platform():
	var slot := TableScreen.PIT_SIDE_BET0
	for plan in ["auftritt", "schlucken", "abrechnung", "parken", "auffahrt",
			"abgang_aus_park"]:
		for beat: float in [0.1, 0.55, 1.0]:
			var holes: Dictionary = {}
			var shaft := _bet_shaft(holes, slot)
			var body := Node3D.new()
			add_child_autofree(body)
			var swept: Array = []
			var report := func() -> void: swept.append(body)
			match plan:
				"auftritt":
					shaft.run_cycle([body], [Vector3.ZERO], 0.0)
				"schlucken":
					shaft.run_exit([body], [Vector3.ZERO], 0.0, report)
				"abrechnung":
					shaft.run_take([body], [Vector3.ZERO], 0.0, report)
				"parken":
					shaft.run_park([], [], [body], [Vector3.ZERO], 0.0)
				"auffahrt":
					shaft.run_rise([body], [Vector3.ZERO], 0.0)
				"abgang_aus_park":
					shaft.run_leave_park([body], [Vector3.ZERO], 0.0, report)
			await wait_seconds(beat)
			var reported := swept.size()
			shaft.settle_hard()
			assert_false(holes.has(slot),
				"%s bei %.2f: der Abbruch schließt das Loch" % [plan, beat])
			assert_almost_eq(shaft.platform_y(), 0.0, 0.0001,
				"%s bei %.2f: und die Platte steht bündig" % [plan, beat])
			assert_false(shaft.visible,
				"%s bei %.2f: die Maschine ist fort" % [plan, beat])
			# Der Abbruch meldet NICHTS nach: was vor ihm nicht durchs Band war, gibt
			# allein scene_root frei (_bet_leaving in _settle_bet_shafts).
			assert_eq(swept.size(), reported,
				"%s bei %.2f: der Abbruch gibt keinen Körper selbst frei"
					% [plan, beat])

## Drei Sektionen, drei Löcher: eine parkt, während die nächste auffährt und die
## dritte abgeht - keine schließt das Loch einer anderen.
func test_three_sections_park_and_ride_independently():
	var holes: Dictionary = {}
	var shafts: Array[LiftShaftView] = []
	var bodies: Array[Node3D] = []
	for i in SideBetPanel.OFFER_COUNT:
		shafts.append(_bet_shaft(holes, TableScreen.side_bet_pit(i), PARK_DEPTH))
		var body := Node3D.new()
		add_child_autofree(body)
		bodies.append(body)
	shafts[0].park_hard()
	shafts[1].run_rise([bodies[1]], [Vector3.ZERO], 0.0)
	shafts[2].run_leave_park([bodies[2]], [Vector3.ZERO], 0.0)
	await wait_seconds(LiftShaftView.PUSH_TIME * 0.5)
	for i in SideBetPanel.OFFER_COUNT:
		assert_true(holes.has(TableScreen.side_bet_pit(i)),
			"Plot %d hat sein eigenes offenes Loch" % i)
	await wait_seconds(LiftShaftView.leave_park_time() + 0.2)
	assert_true(holes.has(TableScreen.side_bet_pit(0)),
		"die geparkte Grube steht weiter offen")
	assert_false(holes.has(TableScreen.side_bet_pit(1)),
		"die aufgefahrene ist zu")
	assert_false(holes.has(TableScreen.side_bet_pit(2)),
		"die abgegangene ebenso")
	assert_almost_eq(shafts[0].platform_y(), -PARK_Y, 0.001,
		"und der Park hat davon nichts gemerkt")

## Die drei Plots stehen in einer Spalte und ihre Maschinen schieben längs derselben
## Achse: reichte ein Hohlraum unter das offene Loch der Nachbarin, sähe man dort
## senkrecht in seine bewußt fast schwarze Tiefe - der schwarze Balken quer durch die
## Grube. Der Wirt MELDET darum die Reichweite, und die Maschine hält sie ein.
func test_the_cavity_never_reaches_past_the_reported_room():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, 2.0)
	assert_gt(shaft.cavity_span(), 0.4, "ohne Meldung nimmt sie sich ihr Wunschmaß")
	shaft.cavity_reach = 0.4
	shaft.setup(Vector3.ZERO, Vector2(1.0, 3.0), 2.0)  # dieselben Maße, neue Meldung
	assert_almost_eq(shaft.cavity_span(), 0.4 - LiftShaftView.REACH_CLEAR, 0.0001,
		"gemeldet heißt eingehalten - und nie ganz ausgeschöpft")
	assert_almost_eq(shaft.waiting_offset(), 1.4 - LiftShaftView.REACH_CLEAR, 0.0001,
		"und die Ware wartet am neuen Ende, nicht dahinter")
	for child in shaft.get_children():
		if not (child is MeshInstance3D):
			continue
		var box: BoxMesh = (child as MeshInstance3D).mesh
		assert_lte(absf(child.position.x) + box.size.x * 0.5,
			1.0 + 0.4 + LiftShaftView.WALL * 2.0 + 0.0001,
			"%s bleibt in der gemeldeten Reichweite" % child.name)

## Und sie schöpft die Meldung NIE ganz aus. Die gemeldete Fuge endet an der WAND der
## Nachbarin: wer sie voll nimmt, stellt seine Stirnwand exakt in deren Innenwand-Ebene,
## und dann streiten beide im Tiefenpuffer und schneiden die Nachbargrube in flimmernde
## schwarze Streifen. Gemessen wird an der Stirnwand, denn sie ist das äußerste Bauteil.
func test_the_cavity_stops_short_of_the_neighbour_wall():
	assert_gt(LiftShaftView.REACH_CLEAR, 0.0, "ein Haar Luft, sonst liegen zwei Flächen gleich")
	assert_lt(LiftShaftView.REACH_CLEAR, LiftShaftView.WALL,
		"aber weniger als eine Wandstärke - die Stirnwand endet IN der Nachbarwand")
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, 2.0)
	var gap := 0.4
	shaft.cavity_reach = gap
	shaft.setup(Vector3.ZERO, Vector2(1.0, 3.0), 2.0)
	# Der Plot der Nachbarin beginnt genau eine gemeldete Fuge weiter - zuzüglich der
	# beiden Wände, die der Wirt schon abgezogen hat.
	var neighbour := 1.0 + gap + LiftShaftView.WALL * 2.0
	for child in shaft.get_children():
		if not (child is MeshInstance3D) or not String(child.name).ends_with("End"):
			continue
		var box: BoxMesh = (child as MeshInstance3D).mesh
		assert_almost_eq(absf(child.position.x) + box.size.x * 0.5,
			neighbour - LiftShaftView.REACH_CLEAR, 0.0001,
			"%s endet vor der Nachbarwand, nicht in ihrer Ebene" % child.name)

## Und nach OBEN ist die Maschine dicht: die Decke jedes Hohlraums füllt das ganze
## Sturz-Band bis an die Schnittkante. Ein Schlitz darüber wäre genau das Loch, durch
## das ein Nachbar-Loch in den Hohlraum sähe - und über der Anzeige steht nie etwas.
func test_the_cavity_is_closed_up_to_the_cut_edge():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, 2.0)
	var lids := 0
	for child in shaft.get_children():
		if not (child is MeshInstance3D):
			continue
		var box: BoxMesh = (child as MeshInstance3D).mesh
		var top: float = child.position.y + box.size.y * 0.5
		assert_lte(top, -LiftShaftView.WALL_SINK + 0.0001,
			"%s steht nicht über der Anzeige" % child.name)
		if String(child.name).ends_with("Lid"):
			lids += 1
			assert_almost_eq(top, -LiftShaftView.WALL_SINK, 0.0001,
				"%s schließt bündig unter der Schnittkante" % child.name)
			assert_almost_eq(box.size.y,
				shaft.depth * (1.0 - LiftShaftView.MOUTH_SHARE), 0.0001,
				"%s ist genau das Sturz-Band hoch" % child.name)
	assert_eq(lids, 2, "beide Hohlräume haben ihre Decke")

# --- Der GRUBEN-SCHIRM ----------------------------------------------------------
# Über der geparkten Grube liegt ein fast durchsichtiger Deckel aus zwei Paneelen, die
# aus linker und rechter Wand herausfahren. Er wird BESTELLT - eine Auslage ohne
# Bestellung baut keinen -, er trägt die gemeldete Gewinn-Zeile, und er ist IMMER fort,
# bevor Ware ihn durchstoßen könnte.

func _wings(shaft: LiftShaftView) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var cover := shaft.get_node_or_null("Schirm")
	if cover == null:
		return out
	for child in cover.get_children():
		if String(child.name).begins_with("Fluegel"):
			out.append(child)
	return out

## Der Laden und das Magazin fahren dieselbe Maschine - und bekommen keinen Schirm,
## weil sie keinen bestellen.
func test_a_shaft_without_an_order_builds_no_cover():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
	assert_false(shaft.has_cover(), "ungebeten kein Deckel")
	assert_null(shaft.get_node_or_null("Schirm"), "und kein Körper dafür")
	shaft.park_hard()
	assert_almost_eq(shaft.cover_share(), 0.0, 0.0001,
		"auch ein Park ohne Bestellung bleibt offen")
	assert_null(shaft.get_node_or_null("Schirm"))

## Zwei Hälften, je eine aus einer Seitenwand, und sie treffen sich in der Mitte -
## eingefahren steckt jede als Nullstrich in ihrem Wandschlitz.
func test_the_cover_comes_out_of_both_side_walls_and_meets_in_the_middle():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
	shaft.order_cover("$30", Color.GOLD)
	var wings := _wings(shaft)
	assert_eq(wings.size(), 2, "zwei Hälften, zwei Wände")
	var sides: Array[float] = []
	for wing in wings:
		sides.append(wing.position.z)
		assert_almost_eq(absf(wing.position.z), shaft.half.y, 0.0001,
			"%s beginnt IN seiner Wand" % wing.name)
		assert_lt(wing.scale.z, 0.01, "und steckt eingefahren darin")
	assert_lt(sides[0] * sides[1], 0.0, "eine links, eine rechts")
	shaft.park_hard()
	for wing in _wings(shaft):
		assert_almost_eq(wing.scale.z, 1.0, 0.0001, "ausgefahren steht %s ganz" % wing.name)
		var pane: MeshInstance3D = wing.get_node("Scheibe")
		var mesh: BoxMesh = pane.mesh
		var inner := absf(wing.position.z) - mesh.size.z
		assert_almost_eq(inner, 0.0, 0.0001,
			"%s stößt NAHTLOS an die Mitte - keine Fuge, keine Überdeckung"
			% wing.name)
		assert_almost_eq(mesh.size.x, shaft.half.x * 2.0, 0.0001,
			"und deckt die Grube in voller Breite")

## Er sitzt KNAPP unter der Schnittkante und ÜBER dem Lichtsaum: der Saum trägt weiter
## die Tiefe, und über der Anzeige steht nichts.
func test_the_cover_sits_under_the_cut_edge_and_over_the_light_seam():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
	shaft.order_cover("$30", Color.GOLD)
	var top := -LiftShaftView.COVER_DROP + LiftShaftView.COVER_H * 0.5
	var bottom := -LiftShaftView.COVER_DROP - LiftShaftView.COVER_H * 0.5
	assert_lte(top, -LiftShaftView.WALL_SINK,
		"der Schirm steht nie über der Anzeige")
	assert_gt(bottom, -LiftShaftView.GLOW_DROP,
		"und liegt über dem Lichtsaum")
	for wing in _wings(shaft):
		assert_almost_eq(wing.position.y, -LiftShaftView.COVER_DROP, 0.0001)

## park_hard stellt ihn HART mit (Endzustand zuerst), settle_hard räumt ihn mit ab -
## und beides ist idempotent.
func test_park_hard_writes_the_cover_and_settle_hard_takes_it_back():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET1, PARK_DEPTH)
	shaft.order_cover("2 Pakete", Color.GOLD)
	shaft.park_hard()
	assert_almost_eq(shaft.cover_share(), 1.0, 0.0001, "der Deckel liegt")
	shaft.park_hard()
	assert_almost_eq(shaft.cover_share(), 1.0, 0.0001, "idempotent")
	shaft.settle_hard()
	assert_almost_eq(shaft.cover_share(), 0.0, 0.0001, "und der Abbruch räumt ihn ab")
	assert_false(holes.has(TableScreen.PIT_SIDE_BET1))

## Der PARK-Zyklus fährt ihn ZULETZT aus: erst ist die Ware unten, dann kommt der
## Deckel darüber.
func test_run_park_extends_the_cover_last():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
	shaft.order_cover("$30", Color.GOLD)
	var prize := Node3D.new()
	add_child_autofree(prize)
	shaft.run_park([], [], [prize], [Vector3.ZERO], 0.0)
	await wait_seconds(LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME * 0.5)
	assert_almost_eq(shaft.cover_share(), 0.0, 0.001,
		"solange die Ware fährt, ist der Schirm fort")
	await wait_seconds(LiftShaftView.park_cycle_time() + 0.1)
	assert_almost_eq(shaft.cover_share(), 1.0, 0.001, "danach liegt er")
	assert_true(holes.has(TableScreen.PIT_SIDE_BET0), "über der offenen Grube")

## Und er ist IMMER zuerst fort: nichts durchstößt ihn - weder die Auffahrt noch der
## Abgang aus dem Park.
func test_nothing_passes_through_the_cover():
	for plan: String in ["auffahrt", "abgang_aus_park"]:
		var holes: Dictionary = {}
		var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
		shaft.order_cover("$30", Color.GOLD)
		var body := Node3D.new()
		add_child_autofree(body)
		var seat := Vector3(0.0, 0.0, 1.0)
		if plan == "auffahrt":
			shaft.run_rise([body], [seat], 0.0)
		else:
			shaft.run_leave_park([body], [seat], 0.0)
		await wait_seconds(LiftShaftView.COVER_TIME * 0.6)
		assert_gt(shaft.cover_share(), 0.0, "%s: der Schirm fährt zuerst ein" % plan)
		assert_almost_eq(body.global_position.y, -PARK_Y, 0.02,
			"%s: und die Ware rührt sich derweil nicht" % plan)
		await wait_seconds(LiftShaftView.COVER_TIME * 0.6)
		assert_almost_eq(shaft.cover_share(), 0.0, 0.001,
			"%s: dann ist er fort" % plan)
		shaft.settle_hard()

## Ohne Zeiger ist die Zeile unsichtbar - der Schirm ist ein Deckel, kein Schild.
func test_the_cover_text_needs_the_pointer():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET2, PARK_DEPTH)
	shaft.order_cover("2 Pakete", Color.GOLD)
	shaft.park_hard()
	assert_almost_eq(shaft.cover_text_share(), 0.0, 0.0001, "unbeachtet sagt er nichts")
	assert_false(shaft.cover_hovered())
	shaft.set_cover_hovered(true)
	await wait_seconds(LiftShaftView.COVER_HOVER_TIME + 0.1)
	assert_almost_eq(shaft.cover_text_share(), 1.0, 0.001, "am Zeiger nennt er den Gewinn")
	assert_true(shaft.cover_hovered())
	shaft.set_cover_hovered(false)
	await wait_seconds(LiftShaftView.COVER_HOVER_TIME + 0.1)
	assert_almost_eq(shaft.cover_text_share(), 0.0, 0.001, "und schweigt wieder")
	# Ein eingefahrener Schirm trägt nie Text, auch wenn der Zeiger stehen bleibt.
	shaft.set_cover_hovered(true)
	await wait_seconds(LiftShaftView.COVER_HOVER_TIME + 0.1)
	shaft.settle_hard()
	assert_almost_eq(shaft.cover_text_share(), 0.0, 0.0001,
		"kein Text über einer geschlossenen Grube")

## Die Zeile kommt von DRAUSSEN und wird nachgeschrieben, ohne den Schirm neu zu bauen.
func test_the_cover_line_is_reported_and_rewritten_in_place():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
	shaft.order_cover("$30", Color.GOLD)
	var cover := shaft.get_node_or_null("Schirm")
	shaft.park_hard()
	shaft.order_cover("2 Pakete", Color.GOLD)
	assert_eq(shaft.cover_text, "2 Pakete")
	assert_eq(shaft.get_node_or_null("Schirm"), cover, "derselbe Körper, neue Zeile")
	assert_almost_eq(shaft.cover_share(), 1.0, 0.0001, "der Park merkt davon nichts")
	var label: Label3D = cover.get_node("Aufschrift")
	assert_eq(label.text, "2 Pakete")
	assert_eq(label.alpha_cut, Label3D.ALPHA_CUT_OPAQUE_PREPASS,
		"die Ziffern-Lehre der Würfel: der Prepass schreibt Tiefe")
	assert_gt(label.pixel_size, 0.0, "und sie hat einen gerechneten Grad")

## Eine neu vermessene Grube behält ihre Bestellung UND ihren Zustand.
func test_the_cover_survives_a_remeasure():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
	shaft.order_cover("$30", Color.GOLD)
	shaft.park_hard()
	shaft.setup(Vector3.ZERO, Vector2(1.4, 2.2), PARK_DEPTH)
	assert_true(shaft.has_cover(), "die Bestellung überlebt den Neubau")
	assert_almost_eq(shaft.cover_share(), 1.0, 0.0001, "und ihr Zustand ebenso")
	assert_eq(_wings(shaft).size(), 2)
	for wing in _wings(shaft):
		assert_almost_eq(absf(wing.position.z), 2.2, 0.0001,
			"die Hälften stehen in den NEUEN Wänden")

## Die Zeile ist IMMER dasselbe helle Gold - der Akzent der Wette bleibt am Saum, und
## im Einblenden liest zu keinem Zeitpunkt etwas Schwarzes.
func test_the_cover_line_stays_gold_whatever_the_bet_pays():
	var holes: Dictionary = {}
	var tones: Array[Color] = []
	for accent: Color in [Color.GOLD, CasinoStyle.BLUE, CasinoStyle.RED]:
		var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
		shaft.order_cover("$30", accent)
		shaft.park_hard()
		var label: Label3D = shaft.get_node("Schirm/Aufschrift")
		tones.append(Color(label.modulate.r, label.modulate.g, label.modulate.b))
		var edge := label.outline_modulate
		assert_gt(edge.r + edge.g + edge.b, 0.4,
			"der Umriß ist dunkles GOLD, nicht Schwarz (%s)" % edge)
		assert_gt(edge.r, edge.b, "und bleibt in der Gold-Familie")
		shaft.settle_hard()
	for tone in tones:
		assert_eq(tone, tones[0], "eine Farbe für alle Wetten")
	var gold := LiftShaftView.cover_text_color()
	assert_eq(tones[0], Color(gold.r, gold.g, gold.b), "die Haus-Goldquelle")
	assert_gt(gold.r, 1.0, "und sie leuchtet über der Ware")

## Ein- und Ausblenden läuft REIN über Alpha: mitten im Fade tragen Zeile und Umriß
## denselben Wert, und ihre Farben stehen unverändert.
func test_the_cover_line_fades_on_alpha_alone():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET1, PARK_DEPTH)
	shaft.order_cover("$30", CasinoStyle.BLUE)
	shaft.park_hard()
	var label: Label3D = shaft.get_node("Schirm/Aufschrift")
	var gold := LiftShaftView.cover_text_color()
	var edge := LiftShaftView.cover_outline_color()
	shaft.set_cover_hovered(true)
	await wait_seconds(LiftShaftView.COVER_HOVER_TIME * 0.5)
	var seen := label.modulate.a
	assert_gt(seen, 0.0, "mitten im Einblenden")
	assert_lt(seen, 1.0)
	assert_almost_eq(label.outline_modulate.a, seen, 0.0001,
		"Zeile und Umriß blenden gemeinsam")
	assert_almost_eq(label.modulate.r, gold.r, 0.0001, "die Farbe kippt dabei nicht")
	assert_almost_eq(label.outline_modulate.r, edge.r, 0.0001)
	assert_gt(label.outline_modulate.r, 0.1, "und ist nie schwarz")

## Der EINE Aufräum-Pfad nimmt ihn in jedem Schlag jedes Fahrplans mit.
func test_every_abort_takes_the_cover_down():
	for plan: String in ["parken", "auffahrt", "abgang_aus_park"]:
		for beat: float in [0.1, 0.5, 0.9]:
			var holes: Dictionary = {}
			var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET1, PARK_DEPTH)
			shaft.order_cover("$30", Color.GOLD)
			var body := Node3D.new()
			add_child_autofree(body)
			match plan:
				"parken":
					shaft.run_park([], [], [body], [Vector3.ZERO], 0.0)
				"auffahrt":
					shaft.run_rise([body], [Vector3.ZERO], 0.0)
				"abgang_aus_park":
					shaft.run_leave_park([body], [Vector3.ZERO], 0.0)
			await wait_seconds(beat)
			shaft.settle_hard()
			assert_almost_eq(shaft.cover_share(), 0.0, 0.0001,
				"%s bei %.2f: der Abbruch räumt den Schirm ab" % [plan, beat])
			assert_almost_eq(shaft.cover_text_share(), 0.0, 0.0001,
				"%s bei %.2f: und seine Zeile mit" % [plan, beat])
			assert_false(holes.has(TableScreen.PIT_SIDE_BET1))

## Zurückgenommen ist er restlos fort.
func test_dropping_the_order_removes_the_body():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
	shaft.order_cover("$30", Color.GOLD)
	shaft.park_hard()
	shaft.drop_cover()
	assert_false(shaft.has_cover())
	assert_almost_eq(shaft.cover_share(), 0.0, 0.0001)
	assert_null(shaft.get_node_or_null("Schirm"))

## Wer auf der Plattform STEHEN bleibt, fährt mit - sonst schwebte er über dem
## offenen Loch, während die Platte unter ihm wegfährt.
func test_a_rider_travels_with_the_platform_and_ends_on_its_seat():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes)
	var leaving := Node3D.new()
	var rider := Node3D.new()
	add_child_autofree(leaving)
	add_child_autofree(rider)
	var seat := Vector3(0.0, 0.0, 1.0)
	rider.global_position = seat
	shaft.run_exit([leaving], [Vector3.ZERO], 0.0, Callable(), [rider], [seat])
	await wait_seconds(LiftShaftView.SINK_TIME * 0.8)
	assert_almost_eq(rider.global_position.y, shaft.platform_y(), 0.05,
		"der Mitfahrer steht auf der Platte, nicht über dem Loch")
	await wait_seconds(LiftShaftView.exit_cycle_time())
	assert_almost_eq(rider.global_position.y, seat.y, 0.001,
		"und steht am Ende wieder auf seinem Platz")
	assert_almost_eq(rider.global_position.z, seat.z, 0.001,
		"der Band-Schritt hat ihn nie angefaßt")

# --- Die WANDHAUT und ihre BLENDEN -----------------------------------------------
# Eine Wett-Grube bleibt offen stehen, also müssen ihre vier Seiten gleich lesen: die
# Wandhaut liegt auf allen Wänden UND auf zwei Blenden, die die Öffnungsbänder
# schließen. Bestellt wird sie wie der Schirm - wer nichts bestellt, fährt die nackte
# Maschine mit offenen Bändern (Laden, Hinterzimmer, Schlitzreihe, Magazin).

const SKIN: Texture2D = preload("res://assets/textures/gruben_paneel.png")

func _shutter(shaft: LiftShaftView, back: bool) -> Node3D:
	var blinds := shaft.get_node_or_null("Blenden")
	if blinds == null:
		return null
	return blinds.get_node_or_null("Blende%s" % ("Hinten" if back else "Vorn"))

func _wall_material(shaft: LiftShaftView) -> StandardMaterial3D:
	var wall: MeshInstance3D = shaft.get_node("WallLeft")
	return wall.material_override

## Der Laden und das Magazin fahren dieselbe Maschine - und bekommen keine Haut, weil
## sie keine bestellen. Ihre Öffnungsbänder stehen offen wie bisher.
func test_a_shaft_without_an_order_wears_no_skin():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
	assert_false(shaft.has_skin(), "ungebeten keine Haut")
	assert_null(shaft.get_node_or_null("Blenden"), "und keine Blende davor")
	var wall := _wall_material(shaft)
	assert_null(wall.albedo_texture, "die Wand bleibt nackte Maschine")
	assert_null(wall.emission_texture)
	shaft.park_hard()
	assert_almost_eq(shaft.shutter_open(true), 0.0, 0.0001,
		"ohne Blende behauptet auch niemand einen Zustand")
	assert_almost_eq(shaft.shutter_open(false), 0.0, 0.0001)

## Bestellt liegt sie auf ALLEN vier Wänden, beiden Stürzen und beiden Blenden - EIN
## Material, damit kein Bauteil aus dem Maßstab fällt.
func test_the_ordered_skin_dresses_every_wall_and_both_shutters():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
	shaft.order_skin(SKIN)
	assert_true(shaft.has_skin())
	var wall := _wall_material(shaft)
	assert_eq(wall.albedo_texture, SKIN, "die Wand trägt die gemeldete Textur")
	assert_eq(wall.emission_texture, SKIN, "und leuchtet aus derselben Map")
	assert_eq(wall.emission_operator, BaseMaterial3D.EMISSION_OP_MULTIPLY,
		"multipliziert - addiert läge ein Schleier über den Paneelen")
	assert_true(wall.uv1_triplanar and wall.uv1_world_triplanar,
		"Welt-Triplanar: der Maßstab ist ein Weltmaß, keine UV je Fläche")
	assert_almost_eq(wall.uv1_scale.x, 1.0 / LiftShaftView.SKIN_TILE, 0.0001)
	for part: String in ["WallLeft", "WallRight", "BackLintel", "FrontLintel"]:
		var mesh: MeshInstance3D = shaft.get_node(part)
		assert_eq(mesh.material_override, wall, "%s trägt dieselbe Haut" % part)
	for back: bool in [true, false]:
		var pane: MeshInstance3D = _shutter(shaft, back).get_node("Platte")
		assert_eq(pane.material_override, wall,
			"auch die Blende - sonst läse sie sich als Loch")

## Geschlossen füllt eine Blende ihr Öffnungsband GENAU: bündig in der Ebene ihres
## Sturzes, so breit wie er und so hoch wie das Band. Das ist der ganze Wunsch.
func test_the_closed_shutter_fills_its_band_flush_with_the_lintel():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
	shaft.order_skin(SKIN)
	var lintel: MeshInstance3D = shaft.get_node("BackLintel")
	var lintel_box: BoxMesh = lintel.mesh
	for back: bool in [true, false]:
		var holder := _shutter(shaft, back)
		var pane: MeshInstance3D = holder.get_node("Platte")
		var box: BoxMesh = pane.mesh
		var side := 1.0 if back else -1.0
		assert_almost_eq(holder.position.x, side * (shaft.half.x + LiftShaftView.WALL * 0.5),
			0.0001, "die Blende steht in der Ebene ihres Sturzes")
		assert_almost_eq(box.size.x, LiftShaftView.WALL, 0.0001, "und ist so dick wie er")
		assert_almost_eq(box.size.z, lintel_box.size.z, 0.0001, "und so breit")
		assert_almost_eq(box.size.y, shaft.mouth_height(), 0.0001,
			"sie füllt das ganze Öffnungsband")
		assert_almost_eq(holder.position.y, -LiftShaftView.WALL_SINK - (shaft.depth
			- shaft.mouth_height()), 0.0001, "und hängt an der Unterkante des Sturzes")
		var top: float = holder.position.y + pane.position.y + box.size.y * 0.5
		assert_lte(top, -LiftShaftView.WALL_SINK + 0.0001,
			"über der Anzeige steht auch sie nicht")
		assert_almost_eq(holder.scale.y, 1.0, 0.0001, "in Ruhe ist sie ZU")

## park_hard schreibt beide Bänder blind, settle_hard ebenso - und beides idempotent.
func test_park_hard_and_settle_hard_shut_both_bands():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET1, PARK_DEPTH)
	shaft.order_skin(SKIN)
	shaft.park_hard()
	for back: bool in [true, false]:
		assert_almost_eq(shaft.shutter_open(back), 0.0, 0.0001,
			"die geparkte Grube steht auf allen vier Seiten geschlossen")
		assert_almost_eq(_shutter(shaft, back).scale.y, 1.0, 0.0001)
	shaft.park_hard()
	assert_almost_eq(shaft.shutter_open(true), 0.0, 0.0001, "idempotent")
	shaft.settle_hard()
	assert_almost_eq(shaft.shutter_open(true), 0.0, 0.0001)
	assert_almost_eq(shaft.shutter_open(false), 0.0, 0.0001)

## Es öffnet nur, was der Schritt WIRKLICH benutzt: herein geht es hinten, hinaus vorn.
func test_only_the_band_the_step_uses_ever_opens():
	var plans: Array[String] = ["auftritt", "abgang", "kauf", "abgang_aus_park",
		"auffahrt", "umschlag"]
	for plan: String in plans:
		var holes: Dictionary = {}
		var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
		shaft.order_skin(SKIN)
		var body := Node3D.new()
		var other := Node3D.new()
		add_child_autofree(body)
		add_child_autofree(other)
		var seat := Vector3(0.0, 0.0, 1.0)
		var wants_back := plan in ["auftritt", "kauf", "umschlag"]
		var wants_front := plan in ["abgang", "abgang_aus_park", "umschlag"]
		match plan:
			"auftritt":
				shaft.run_cycle([body], [seat], 0.0)
			"abgang":
				shaft.run_exit([body], [seat], 0.0)
			"kauf":
				shaft.run_take([body], [seat], 0.0)
			"abgang_aus_park":
				shaft.run_leave_park([body], [seat], 0.0)
			"auffahrt":
				shaft.run_rise([body], [seat], 0.0)
			"umschlag":
				shaft.run_swap([other], [seat], [body], [seat], 0.0)
		# Mitten im BAND-SCHRITT: was gebraucht wird, steht ganz offen; der Rest bleibt zu.
		var lead := LiftShaftView.COVER_TIME if plan == "abgang_aus_park" \
			else LiftShaftView.SINK_TIME
		if plan == "auffahrt":
			lead = LiftShaftView.COVER_TIME
		await wait_seconds(lead + LiftShaftView.PUSH_TIME * 0.5)
		assert_almost_eq(shaft.shutter_open(true), 1.0 if wants_back else 0.0, 0.02,
			"%s: der EINGANG" % plan)
		assert_almost_eq(shaft.shutter_open(false), 1.0 if wants_front else 0.0, 0.02,
			"%s: der AUSGANG" % plan)
		shaft.settle_hard()

## Und am Ende jedes Fahrplans sind beide wieder blind - im HUB-Takt bzw. mit dem Schirm.
func test_every_plan_shuts_its_bands_again():
	for plan: String in ["auftritt", "abgang", "kauf", "parken", "abgang_aus_park"]:
		var holes: Dictionary = {}
		var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET2, PARK_DEPTH)
		shaft.order_skin(SKIN)
		shaft.order_cover("$30", Color.GOLD)
		var body := Node3D.new()
		add_child_autofree(body)
		var seat := Vector3(0.0, 0.0, 1.0)
		var span := LiftShaftView.cycle_time()
		match plan:
			"auftritt":
				shaft.run_cycle([body], [seat], 0.0)
			"abgang":
				shaft.run_exit([body], [seat], 0.0)
			"kauf":
				shaft.run_take([body], [seat], 0.0)
			"parken":
				shaft.run_park([], [], [body], [seat], 0.0)
				span = LiftShaftView.park_cycle_time()
			"abgang_aus_park":
				shaft.run_leave_park([body], [seat], 0.0)
				span = LiftShaftView.leave_park_time()
		await wait_seconds(span + 0.15)
		assert_almost_eq(shaft.shutter_open(true), 0.0, 0.001,
			"%s: der Eingang ist wieder blind" % plan)
		assert_almost_eq(shaft.shutter_open(false), 0.0, 0.001,
			"%s: der Ausgang ebenso" % plan)
		shaft.settle_hard()

## Der PARK schließt seine Blende IM Schirm-Takt: die Grube steht danach rundum zu.
func test_the_park_shuts_its_band_together_with_the_cover():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
	shaft.order_skin(SKIN)
	shaft.order_cover("$30", Color.GOLD)
	var body := Node3D.new()
	add_child_autofree(body)
	shaft.run_park([], [], [body], [Vector3.ZERO], 0.0)
	await wait_seconds(LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME * 0.5)
	assert_almost_eq(shaft.shutter_open(true), 1.0, 0.02,
		"während der Ware ist das Band auf")
	await wait_seconds(LiftShaftView.park_cycle_time() + 0.15)
	assert_almost_eq(shaft.shutter_open(true), 0.0, 0.001, "danach ist es blind")
	assert_almost_eq(shaft.cover_share(), 1.0, 0.001, "und der Schirm liegt")
	assert_true(holes.has(TableScreen.PIT_SIDE_BET0), "über der offenen Grube")

## Der EINE Aufräum-Pfad nimmt die Blenden in JEDEM Schlag JEDES Fahrplans mit - eine
## offen gebliebene Blende wäre ein Loch in der Wand.
func test_every_abort_shuts_the_bands():
	for plan: String in ["auftritt", "parken", "abgang_aus_park", "kauf"]:
		for beat: float in [0.1, 0.5, 0.9]:
			var holes: Dictionary = {}
			var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET1, PARK_DEPTH)
			shaft.order_skin(SKIN)
			var body := Node3D.new()
			add_child_autofree(body)
			match plan:
				"auftritt":
					shaft.run_cycle([body], [Vector3.ZERO], 0.0)
				"parken":
					shaft.run_park([], [], [body], [Vector3.ZERO], 0.0)
				"abgang_aus_park":
					shaft.run_leave_park([body], [Vector3.ZERO], 0.0)
				"kauf":
					shaft.run_take([body], [Vector3.ZERO], 0.0)
			await wait_seconds(beat)
			shaft.settle_hard()
			assert_almost_eq(shaft.shutter_open(true), 0.0, 0.0001,
				"%s bei %.2f: der Abbruch schließt den Eingang" % [plan, beat])
			assert_almost_eq(shaft.shutter_open(false), 0.0, 0.0001,
				"%s bei %.2f: und den Ausgang" % [plan, beat])
			assert_almost_eq(_shutter(shaft, true).scale.y, 1.0, 0.0001)

## Ihr Takt liegt IN den bestehenden Schlägen: ein Band kostet den Zyklus keine Zeit.
func test_the_bands_cost_the_cycle_no_time():
	assert_lte(LiftShaftView.SHUTTER_TIME, LiftShaftView.SINK_TIME,
		"auf geht sie im Senk-Takt")
	assert_lte(LiftShaftView.SHUTTER_TIME, LiftShaftView.LIFT_TIME,
		"zu im Hub-Takt")
	assert_lte(LiftShaftView.SHUTTER_TIME, LiftShaftView.COVER_TIME,
		"und beim Parken im Schirm-Takt")

## Die Bestellung überlebt einen Neuschnitt, ihr Körper nicht - und der Zustand steht
## danach wieder genau so da.
func test_the_skin_survives_a_remeasure():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
	shaft.order_skin(SKIN)
	shaft.park_hard()
	shaft.setup(Vector3.ZERO, Vector2(1.4, 2.6), PARK_DEPTH)  # neu geschnitten
	assert_true(shaft.has_skin(), "die Bestellung überlebt")
	assert_not_null(_shutter(shaft, true), "und ihr Körper steht neu")
	var pane: MeshInstance3D = _shutter(shaft, true).get_node("Platte")
	var box: BoxMesh = pane.mesh
	assert_almost_eq(box.size.z, 2.6 * 2.0 + LiftShaftView.WALL * 2.0, 0.0001,
		"auf dem NEUEN Maß")
	assert_eq(_wall_material(shaft).albedo_texture, SKIN)

## Zurückgenommen ist sie restlos fort: nackte Wand, offene Bänder.
func test_dropping_the_skin_removes_the_shutters():
	var holes: Dictionary = {}
	var shaft := _bet_shaft(holes, TableScreen.PIT_SIDE_BET0, PARK_DEPTH)
	shaft.order_skin(SKIN)
	shaft.park_hard()
	shaft.drop_skin()
	assert_false(shaft.has_skin())
	assert_null(shaft.get_node_or_null("Blenden"))
	assert_null(_wall_material(shaft).albedo_texture)
	assert_almost_eq(shaft.shutter_open(true), 0.0, 0.0001)
