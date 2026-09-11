extends GutTest
## Die SERIENSCHALTUNG an der Werkbank: die Slot-Reihe wächst mit dem Hub, die
## Steckreihenfolge IST die Rechnung, das Ziel wählt der Spieler per Klick auf einen
## physischen Pool-Würfel (set_target_die), und die Vorschau ist buchstäblich
## dieselbe Rechnung wie der Griff.

## Breite der Probeseite: der 100-u-Boden, damit unit() die Konvention bleibt.
const PAGE_WIDTH := 560.0

var view: WorkshopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = WorkshopView.new()
	view.size = Vector2(PAGE_WIDTH, 540)
	add_child_autofree(view)
	view.run = run
	# Wie am Tisch: die EINHEIT wird GEMELDET (sie folgt dort der Würfelfläche), und
	# BREITE wie HÖHE fallen daraus - die Zeile ist so groß, wie ihr Inhalt ist.
	view.unit_px = PAGE_WIDTH / 100.0
	var u := view.unit()
	view.size = Vector2(
		roundf(WorkshopView.bench_width_for(u, view.net_span(u).x,
			view.tower_span_px().x, view.stage_px(), view.eject_lane_px())),
		roundf(WorkshopView.bench_height_for(u, view.net_span(u).y,
			view.tower_span_px().y, view.stage_px())))
	view.refresh()  # das neue Maß will gebaut werden, sonst steht die alte Seite

## Legt count Zahlen-Pakete ins Magazin und liefert ihre uids.
func _stock(count: int) -> Array[int]:
	var uids: Array[int] = []
	for i in count:
		var pack := run.grant_pack(Pack.number_pack())
		uids.append(pack.pack_uid)
	return uids

## Fuellt die Reihe mit LEEREN Netzen auf sechs auf - der Griff verlangt eine VOLLE
## Reihe, und eine leere Karte verschiebt keine Zelle und keinen Stand.
func _fill_row() -> void:
	while view.press_slot_uids().size() < GameRun.SERIES_SLOT_CAP:
		var pack := run.grant_pack(Pack.number_pack())
		pack.stamp_net = StampNet.empty_net()
		if not view.slot_pack(pack.pack_uid):
			return

## Ein Paket mit GARANTIERTEM Netz - ein leer gewürfeltes prägt nichts.
func _valued_pack(face: int, amount: int) -> Pack:
	var pack := run.grant_pack(Pack.number_pack())
	pack.stamp_net = StampNet.empty_net()
	pack.stamp_net[face] = StampNet.value_cell(amount)
	return pack

# --- Die Reihe IST die Serienlänge -----------------------------------------------

func test_the_row_carries_exactly_the_series_slots() -> void:
	await wait_frames(2)
	assert_eq(view.slot_count(), run.series_slots(), "die Reihe IST die Serienlänge")
	assert_eq(view._slot_buttons.size(), 6, "und die ist 6 ab Runde 1")
	run.series_slot_bonus = 2
	run.grant_press_boost()
	view.refresh()
	await wait_frames(2)
	assert_eq(view._slot_buttons.size(), 6,
		"der Deckel ist die Block-Größe: eine siebte gibt es nicht")

## Eine geschrumpfte Reihe (Kurzschluß) wirft trotzdem keine steckende Karte fort.
func test_a_shrunken_ladder_never_drops_a_standing_card() -> void:
	var uids := _stock(6)
	for uid in uids:
		view.slot_pack(uid)
	await wait_frames(2)
	var short_circuit: Array[String] = [DealClause.SHORT_CIRCUIT]
	run.sign_clauses(short_circuit)
	view.refresh()
	await wait_frames(2)
	assert_eq(run.series_slots(), 1, "der Kurzschluß setzt absolut")
	assert_eq(view.press_slot_uids().size(), 6, "die gesteckten Karten bleiben stecken")
	assert_eq(view.slot_count(), 6, "und die Reihe trägt sie alle")

# --- Stecken, zurückwerfen, umsortieren -------------------------------------------

func test_tapping_a_cassette_fills_the_next_free_slot() -> void:
	var uids := _stock(2)
	view._on_pack_pressed(uids[0])
	view._on_pack_pressed(uids[1])
	assert_eq(view.press_slot_uids(), uids, "in der Reihenfolge des Tippens")

func test_a_slotted_card_is_reserved_against_the_magazine() -> void:
	var uids := _stock(2)
	view.slot_pack(uids[0])
	await wait_frames(2)
	var shown: Array[int] = []
	for entry in view.drawer_entries():
		shown.append(int(entry["uid"]))
	assert_eq(shown, [uids[1]] as Array[int], "was steckt, liegt nicht mehr im Fach")

func test_clicking_a_filled_slot_reports_its_place_and_returns_it() -> void:
	var uids := _stock(1)
	view.slot_pack(uids[0])
	var seen: Array = []
	view.pack_unslotted.connect(func(slot: int, uid: int) -> void: seen.append([slot, uid]))
	view.clear_press_slot(0)
	assert_eq(seen, [[0, uids[0]]], "Platz und Karte gemeldet")
	assert_true(view.press_slot_uids().is_empty())

func test_the_row_is_cap_and_reorder_is_move_not_swap() -> void:
	run.hub_level = 10
	view.refresh()
	var uids := _stock(3)
	for uid in uids:
		view.slot_pack(uid)
	assert_eq(view.press_slot_uids(), uids)
	view.move_slot(2, 0)
	assert_eq(view.press_slot_uids(), [uids[2], uids[0], uids[1]] as Array[int],
		"herausgenommen und eingesetzt - alles dazwischen rückt eine Stelle")

func test_the_row_never_takes_more_than_its_slots() -> void:
	var uids := _stock(9)
	for uid in uids:
		view.slot_pack(uid)
	assert_eq(view.press_slot_uids().size(), run.series_slots(),
		"über die Serienlänge geht nichts")

func test_a_locked_round_bars_the_row() -> void:
	var uids := _stock(1)
	view.editing_locked = true
	assert_false(view.slot_pack(uids[0]), "unterschrieben wird nichts mehr gesteckt")

# --- Die ZIELWAHL per Pool-Klick --------------------------------------------------

func test_choosing_a_die_reports_it_and_choosing_again_drops_it() -> void:
	var seen: Array = []
	view.target_chosen.connect(func(die: DieDefinition) -> void: seen.append(die))
	view.choose_target(3)
	assert_eq(view.target_die(), run.owned_pool[3], "der gewählte Würfel")
	view.choose_target(3)
	assert_null(view.target_die(), "derselbe Tipp wählt ab")
	assert_eq(seen, [run.owned_pool[3], null], "und beides wird gemeldet")

func test_another_tap_switches_the_target() -> void:
	view.choose_target(1)
	view.choose_target(4)
	assert_eq(view.target_die(), run.owned_pool[4])
	assert_eq(view.second_index(), -1, "ohne Doppelmatrize gibt es keinen zweiten")

## scene_root meldet den angetippten PHYSISCHEN Würfel per set_target_die; ein
## anderer Würfel wechselt das Ziel, null wählt ab.
func test_set_target_die_selects_switches_and_clears() -> void:
	var seen: Array = []
	view.target_chosen.connect(func(die: DieDefinition) -> void: seen.append(die))
	view.set_target_die(run.owned_pool[2])
	assert_eq(view.target_die(), run.owned_pool[2], "der angetippte Würfel wird Ziel")
	view.set_target_die(run.owned_pool[5])
	assert_eq(view.target_die(), run.owned_pool[5], "ein anderer wechselt das Ziel")
	view.set_target_die(null)
	assert_null(view.target_die(), "null wählt ab")
	assert_eq(seen, [run.owned_pool[2], run.owned_pool[5], null])

# --- Der GRIFF --------------------------------------------------------------------

func test_the_grip_needs_a_target_a_full_row_and_a_stamping_card() -> void:
	var uids := _stock(1)
	await wait_frames(2)
	assert_false(view.can_pull(), "nackt greift nichts")
	view.slot_pack(uids[0])
	assert_false(view.can_pull(), "ohne Ziel auch nicht")
	view.choose_target(0)
	assert_false(view.can_pull(), "und mit EINER Karte auch nicht - der Block ist sechs")
	assert_true(view._action_button.disabled, "der Sitz steht grau da")
	_fill_row()
	await wait_frames(2)
	assert_true(view.can_pull(), "Ziel plus volle Reihe genügt")

func test_a_catalysts_only_series_never_stamps() -> void:
	for i in GameRun.SERIES_SLOT_CAP:
		var fuel := run.grant_pack(Pack.catalyst(Pack.CATALYST_PROPELLANT))
		view.slot_pack(fuel.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	assert_eq(view.stamping_card_count(), 0)
	assert_false(view.can_pull(), "Katalysatoren verstärken eine Projektion, sie sind keine")
	assert_true(view._action_button.disabled)

## Der Griff ist UNBEGRENZT (2026-09-05): zwei hintereinander buchen beide.
func test_two_grips_in_a_row_both_book() -> void:
	view.slot_pack(_valued_pack(0, 3).pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var before: int = run.owned_pool[0].faces[0]
	_fill_row()
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	assert_eq(run.owned_pool[0].faces[0], before + 3, "der erste bucht")
	view.slot_pack(_valued_pack(0, 4).pack_uid)
	_fill_row()
	await wait_frames(2)
	assert_true(view.can_pull(), "und der zweite steht bereit")
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	assert_eq(run.owned_pool[0].faces[0], before + 7, "auch der zweite bucht")

## Die Doppelmatrize ist diese Welle DEAKTIVIERT: sie verlangt keinen zweiten
## Würfel mehr, der Griff steht mit EINEM Ziel bereit, und apply_series bekommt null
## als zweiten - die Matrix-Karte bleibt gesteckt, ihre Zweitprojektion ist inert.
func test_the_doppelmatrize_is_deactivated_this_wave() -> void:
	_valued_pack(0, 4)
	run.grant_pack(Pack.catalyst(Pack.CATALYST_MATRIX))
	for pack in run.owned_packs:
		view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	assert_false(view.needs_second(), "sie mahnt keinen zweiten Würfel mehr an")
	assert_null(view.second_die(), "und liefert nie einen")
	_fill_row()
	assert_true(view.can_pull(), "der Griff steht mit EINEM Ziel bereit")
	var before: int = run.owned_pool[0].faces[0]
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	assert_eq(run.owned_pool[0].faces[0], before + 4,
		"gebucht wird auf den EINEN Zielwürfel - die Matrix-Zweitprojektion ist inert")
	view.skip_ceremony()

func test_the_grip_books_and_burns_its_cards() -> void:
	var pack := _valued_pack(0, 3)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var before: int = run.owned_pool[0].faces[0]
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	assert_eq(run.owned_pool[0].faces[0], before + 3, "gebucht ist sofort")
	assert_true(view.press_slot_uids().is_empty() or view.burning(),
		"die Reihe gehört jetzt der Zeremonie")

func test_the_ceremony_reports_the_grip_at_its_end() -> void:
	var pack := _valued_pack(1, 2)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var seen: Array = []
	view.series_applied.connect(func(result: Dictionary, _px: Vector2) -> void:
		seen.append(result))
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	assert_true(view.burning(), "die Fahrt läuft")
	assert_true(seen.is_empty(), "und meldet erst am Ende")
	view.skip_ceremony()
	await wait_frames(2)
	assert_false(view.burning(), "übersprungen ist sie fertig")
	assert_eq(seen.size(), 1, "und der Griff ist gemeldet")
	assert_eq(int(Dictionary(seen[0]).get("cards", 0)), GameRun.SERIES_SLOT_CAP)

# --- DIE LAWINE und der SCANNER -----------------------------------------------------

## Alle Takt-Meldungen der Zeremonie in Reihenfolge, als [Kennung, Nutzlast].
func _record_press() -> Array:
	var beats: Array = []
	view.cards_latched.connect(func(time: float) -> void:
		beats.append(["latched", time]))
	view.die_raised.connect(func(time: float) -> void: beats.append(["raised", time]))
	view.light_passed.connect(func(index: int, faces: Array, values: Array,
			operator: String, time: float) -> void:
		beats.append(["passed", index, faces, values, operator, time]))
	view.light_struck.connect(func(time: float) -> void: beats.append(["struck", time]))
	view.die_returned.connect(func(time: float) -> void:
		beats.append(["returned", time]))
	return beats

## Es gibt genau EIN Netz, und es PARKT im Netz-Schirm der Netz-Spalte: der
## Schirm hält nur seinen Platz, das Netz selbst liegt genau darauf und fährt nie.
func test_the_net_screen_parks_the_one_net() -> void:
	await wait_frames(2)
	assert_eq(view._net_host.get_child_count(), 0, "der Parkplatz selbst ist leer")
	assert_almost_eq(view._net.get_global_rect().get_center().x,
		view.ist_net_center().x, 0.5, "das Netz steht auf der gemeldeten Mitte")
	assert_almost_eq(view._net.get_global_rect().get_center().y,
		view.ist_net_center().y, 0.5)

## Der Griff RASTET zuerst alle Karten EIN, dann hebt der Würfel ab - erst danach
## steigt das Licht.
func test_the_grip_latches_the_cards_and_raises_the_die_first() -> void:
	var pack := _valued_pack(0, 3)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var beats := _record_press()
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	await wait_frames(2)
	assert_true(view.burning(), "die Zeremonie läuft noch")
	assert_eq(String(beats[0][0]), "latched", "erst rasten alle Karten ein")
	assert_almost_eq(float(beats[0][1]), view.latch_time(), 0.001,
		"und zwar in der gemeldeten Gesamtdauer")
	assert_almost_eq(view.latch_time(), WorkshopView.LATCH_TIME
		+ WorkshopView.LATCH_STAGGER * float(GameRun.SERIES_SLOT_CAP - 1), 0.001,
		"eine Karte plus die Staffel über die Etagen")
	view.skip_ceremony()

## Je Etage EINE Licht-Meldung, in Serienfolge, mit ihren Zellen und dem
## aufgelaufenen Stand - genau das, was die Kassette abdunkelt und das Licht-Netz
## tickt. Zuletzt der Einschlag und der Rückflug.
func test_every_card_reports_its_cells_and_the_running_sum() -> void:
	var first := _valued_pack(0, 2)
	var second := _valued_pack(3, 5)
	view.slot_pack(first.pack_uid)
	view.slot_pack(second.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var beats := _record_press()
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	await wait_seconds(view.ceremony_time() + 0.35)
	var reads: Array = []
	for beat in beats:
		if String(beat[0]) == "passed":
			reads.append(beat)
	assert_eq(reads.size(), GameRun.SERIES_SLOT_CAP, "je Etage genau ein Takt")
	assert_eq(int(reads[0][1]), 0, "in Serienfolge - Index 0 liegt UNTEN")
	assert_eq(reads[0][2], [0] as Array[int], "Karte 1 gibt ihre Seite her")
	assert_eq(int(reads[0][3][0]), 2, "und der Stand danach ist ihr Wert")
	assert_eq(reads[1][2], [3] as Array[int])
	assert_eq(int(reads[1][3][0]), 2, "der Stand LÄUFT AUF - Karte 1 bleibt darin")
	assert_eq(int(reads[1][3][3]), 5)
	assert_eq(String(beats[-2][0]), "struck", "dann schlagen die Funken ein")
	assert_eq(String(beats[-1][0]), "returned", "und der Würfel fliegt zurück")

## Ein OPERATOR meldet seine Kennung mit - er schlägt perkussiv zu, statt still
## aufzunehmen.
func test_an_operator_card_reports_its_operator() -> void:
	var value := _valued_pack(0, 2)
	var doubler := run.grant_pack(Pack.operator_pack(StampNet.OP_DOUBLER))
	doubler.stamp_net = StampNet.empty_net()
	doubler.stamp_net[0] = StampNet.operator_cell(StampNet.OP_DOUBLER)
	view.slot_pack(value.pack_uid)
	view.slot_pack(doubler.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var beats := _record_press()
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	await wait_seconds(view.ceremony_time() + 0.35)
	var operators: Array[String] = []
	for beat in beats:
		if String(beat[0]) == "passed":
			operators.append(String(beat[4]))
	assert_eq(operators.size(), GameRun.SERIES_SLOT_CAP)
	assert_eq(operators[0], "", "die Wert-Karte nennt keinen")
	assert_eq(operators[1], StampNet.OP_DOUBLER, "nur die Operator-Karte nennt einen")

## Die Fahrt darf JEDERZEIT abbrechen: der EINE Aufräum-Pfad stellt das Netz auf
## seinen Endstand, die Reihe ist leer und der Griff genau einmal gemeldet.
func test_an_aborted_ride_owes_nothing() -> void:
	var pack := _valued_pack(0, 4)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var park := view.ist_net_center()
	var seen: Array = []
	view.series_applied.connect(func(_result: Dictionary, _px: Vector2) -> void:
		seen.append(true))
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	await wait_seconds(WorkshopView.LIGHT_STEP * 0.5)
	view.skip_ceremony()
	await wait_frames(2)
	assert_almost_eq(view._net.get_global_rect().get_center().x, park.x, 0.5,
		"das Netz steht auf seinem Parkplatz")
	assert_almost_eq(view._net.get_global_rect().get_center().y, park.y, 0.5)
	assert_true(view.press_slot_uids().is_empty(), "die Reihe ist leer")
	assert_true(view.showing_result(), "und das Netz zeigt das ERGEBNIS")
	assert_eq(view._net.preview_die().faces[0], run.owned_pool[0].faces[0],
		"das Netz zeigt den gebuchten Stand")
	assert_eq(seen.size(), 1, "der Griff ist genau einmal gemeldet")

## Die Fahrt AUSGEFAHREN (ohne Skip): danach ist die Reihe leer, der Sitz trägt
## wieder den Griff, und das Netz steht auf seinem Parkplatz. Derselbe Endzustand,
## den auch das "Fertig" liefert.
func test_the_full_ride_lands_in_the_same_end_state() -> void:
	var pack := _valued_pack(2, 4)
	view.slot_pack(pack.pack_uid)
	view.choose_target(1)
	await wait_frames(2)
	var park := view.ist_net_center()
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	var span := view.ceremony_time()
	await wait_seconds(span + 0.35)
	assert_false(view.burning(), "die Fahrt ist von selbst durch")
	assert_true(view.press_slot_uids().is_empty(), "die Reihe ist leer")
	assert_eq(view._action_button.text, "Griff 0/%d" % run.series_slots(),
		"und der Zähler in der Aufschrift steht wieder auf null")
	assert_true(String(view._action_button.text).begins_with("Griff"),
		"der Sitz trägt wieder den Griff, nicht das Fertig")
	assert_almost_eq(view._net.get_global_rect().get_center().x, park.x, 0.5,
		"das Netz steht auf seinem Parkplatz")
	assert_almost_eq(view._net.get_global_rect().get_center().y, park.y, 0.5)
	assert_eq(view._net.get_child(0).position,
		DieNetView.cell_position(0, view._net.cell), "und ungefaltet")
	assert_eq(view._net.get_child(0).scale, Vector2.ONE)

## Während der Fahrt rechnet der Soll-Schirm gegen die Ausgangslage - der gebuchte
## Stand kommt erst im Nachspiel.
func test_the_preview_holds_the_before_state_until_the_end() -> void:
	var pack := _valued_pack(0, 6)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var before: int = run.owned_pool[0].faces[0]
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	await wait_frames(2)
	assert_eq(view.preview_target().faces[0], before,
		"das Netz mißt gegen den Stand VOR dem Griff")
	view.skip_ceremony()
	await wait_frames(2)
	assert_eq(run.owned_pool[0].faces[0], before + 6, "danach ist gebucht")

## Das Netz zeigt danach das ERGEBNIS: den gebuchten Stand mit den GRÜNEN Deltas -
## also den Stand VOR dem Griff plus die Projektion darüber, sonst wäre nichts grün.
func test_after_the_ride_the_net_shows_the_booked_result() -> void:
	var pack := _valued_pack(0, 5)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var before: int = run.owned_pool[0].faces[0]
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	assert_true(view.showing_result(), "das Ergebnis steht")
	assert_eq(view._net.def.faces[0], before, "das Netz mißt gegen den Stand DAVOR")
	assert_eq(view._net.preview_die().faces[0], before + 5,
		"und zeigt darüber den gebuchten - das ist das Grün")
	assert_false(view.preview().is_empty(), "die Rechnung der Buchung bleibt stehen")

## Der Takt hat eine RAMPE: die späteren Karten fahren schneller, ein Operator
## bekommt seinen Sondermoment obendrauf.
func test_the_beat_ramps_and_operators_get_their_moment() -> void:
	var value := _valued_pack(0, 2)
	var doubler := run.grant_pack(Pack.operator_pack(StampNet.OP_DOUBLER))
	doubler.stamp_net = StampNet.empty_net()
	doubler.stamp_net[0] = StampNet.operator_cell(StampNet.OP_DOUBLER)
	run.hub_level = 10
	view.refresh()
	var third := _valued_pack(1, 1)
	view.slot_pack(value.pack_uid)
	view.slot_pack(third.pack_uid)
	view.slot_pack(doubler.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	assert_lt(view.card_beat(3), view.card_beat(1), "die Rampe zieht an")
	assert_gt(view.card_beat(2), view.card_beat(1),
		"der Operator bekommt seine %.2f s dazu" % WorkshopView.LIGHT_OPERATOR_EXTRA)
	var span := view.latch_time() + WorkshopView.RAISE_TIME
	for i in GameRun.SERIES_SLOT_CAP:
		span += view.card_beat(i)
	span += WorkshopView.STRIKE_TIME + WorkshopView.STRIKE_HOLD \
		+ WorkshopView.RETURN_TIME
	assert_almost_eq(view.ceremony_time(), span, 0.001,
		"ceremony_time IST die Summe aller Takte")
	view.skip_ceremony()

# --- Die LIVE-VORSCHAU ------------------------------------------------------------

func test_the_preview_is_the_same_calculation_as_the_booking() -> void:
	var pack := _valued_pack(2, 5)
	view.slot_pack(pack.pack_uid)
	view.choose_target(7)
	await wait_frames(2)
	var projection := view.preview()
	assert_eq(projection["faces_after"],
		run.resolve_series(view.press_slot_uids(), run.owned_pool[7])["faces_after"],
		"Vorschau und Buchung rechnen dasselbe")
	assert_eq(int(projection["bonus"][2]), 5)

func test_without_a_target_there_is_nothing_to_preview() -> void:
	var pack := _valued_pack(0, 2)
	view.slot_pack(pack.pack_uid)
	await wait_frames(2)
	assert_true(view.preview().is_empty(), "ohne Zielwürfel keine Rechnung")

## Die REIHENFOLGE ist die Entscheidung: derselbe Satz Karten, andere Ordnung,
## anderes Ergebnis - der Verdoppler rechnet auf der aufgelaufenen Summe.
func test_the_order_of_the_row_changes_the_result() -> void:
	var value := _valued_pack(0, 3)
	var doubler := run.grant_pack(Pack.operator_pack(StampNet.OP_DOUBLER))
	doubler.stamp_net = StampNet.empty_net()
	doubler.stamp_net[0] = StampNet.operator_cell(StampNet.OP_DOUBLER)
	view.slot_pack(value.pack_uid)
	view.slot_pack(doubler.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	assert_eq(int(view.preview()["bonus"][0]), 6, "Wert, dann Verdoppler")
	view.move_slot(1, 0)
	await wait_frames(2)
	assert_eq(int(view.preview()["bonus"][0]), 3, "Verdoppler zuerst verdoppelt nichts")

# --- Der GRIFF trägt den Zähler ---------------------------------------------------

## Der Serien-Schirm ist tot: wie voll die Reihe ist, steht in der Aufschrift des
## Knopfs - "Griff gesteckt/Serienlänge".
func test_the_grip_label_counts_the_slots() -> void:
	var uids := _stock(1)
	await wait_frames(2)
	assert_eq(view.grip_label(), "Griff 0/%d" % run.series_slots())
	assert_false(view._action_button.visible, "leer zeigt sich kein Knopf")
	view.slot_pack(uids[0])
	await wait_frames(2)
	assert_true(view._action_button.visible, "gesteckt steht er da")
	assert_eq(view._action_button.text, "Griff 1/%d" % run.series_slots())

## Der SERIEN-Schirm ist tot (der Zähler steht in der Griff-Aufschrift), und an der
## Stelle des dreizeiligen Tooltips steht seit der Welle O der SUMMEN-Schirm.
func test_the_series_screen_is_gone_and_the_sum_screen_stands() -> void:
	await wait_frames(2)
	assert_false(view.has_method("series_text"), "kein Serien-Schirm mehr")
	assert_false(view.has_method("set_info"), "und kein dreizeiliger Tooltip mehr")
	assert_null(view.get_node_or_null("SeriesBand/SeriesScreen"))
	assert_null(view.get_node_or_null("SeriesBand/SumScreen"),
		"und im Band steht er auch nicht")
	assert_not_null(view.get_node_or_null("Street/SumScreen"),
		"der Summen-Schirm steht in Zeile 2 der Straße")
	assert_null(view.get_node_or_null("Street/SumScreen/Caption"),
		"die Caption darunter ist am 2026-09-11 gestorben")

# --- WELLE O: der SUMMEN-SCHIRM ---------------------------------------------------
# Zeile 2 trägt DREI Netze. Das mittlere zeigt die REINE Summe der gesteckten
# Prägenetze (zielunabhängig) - und beim Hover das Netz DER einen Karte.

func _sum_view() -> Control:
	return view.get_node("Street/SumScreen/SumNet").get_child(0)

## Ohne Karte steht dort dasselbe LEERE KREUZ wie links und rechts.
func test_the_sum_screen_shows_the_empty_cross_without_a_card() -> void:
	await wait_frames(2)
	assert_eq(_sum_view().name, "EmptyNet", "leer heißt: sechs dunkle Zellen")
	assert_eq(_sum_view().get_child_count(), 6)

## Mit Karten die SUMME - in Steckreihenfolge und OHNE Zielwürfel: ein Verdoppler
## NACH der Wert-Karte verdoppelt, DAVOR nicht (derselbe Kartensatz wie oben).
func test_the_sum_screen_sums_the_slotted_nets_in_order() -> void:
	var value := _valued_pack(0, 3)
	var doubler := run.grant_pack(Pack.operator_pack(StampNet.OP_DOUBLER))
	doubler.stamp_net = StampNet.empty_net()
	doubler.stamp_net[0] = StampNet.operator_cell(StampNet.OP_DOUBLER)
	view.slot_pack(value.pack_uid)
	view.slot_pack(doubler.pack_uid)
	await wait_frames(2)
	assert_null(view.target_die(), "kein Ziel gewählt - die Summe steht trotzdem")
	assert_eq(_sum_view().name, "SeriesSum", "der Schirm trägt die Summe")
	assert_eq(int(view._sum_projection["bonus"][0]), 6, "Wert, dann Verdoppler")
	view.move_slot(1, 0)
	await wait_frames(2)
	assert_eq(int(view._sum_projection["bonus"][0]), 3,
		"Verdoppler zuerst verdoppelt nichts")

## Der HOVER zeigt DIE EINE Karte statt der Summe - Schacht wie Magazin -, und
## verläßt der Zeiger sie, steht die Summe wieder.
func test_hovering_a_card_shows_its_own_net() -> void:
	var slotted := _valued_pack(0, 3)
	var spare := _valued_pack(1, 2)
	view.slot_pack(slotted.pack_uid)
	await wait_frames(2)
	view.sync_hover_at(view._slot_buttons[0].get_global_rect().get_center())
	assert_eq(_sum_view().name, "StampNet", "die Schacht-Karte zeigt ihr eigenes Netz")
	assert_eq(view.hover_pack_name(), slotted.display_name)
	view.sync_hover_at(view.pack_anchor_px(spare.pack_uid))
	assert_eq(_sum_view().name, "StampNet", "und eine Magazin-Kassette ebenso")
	assert_eq(view.hover_pack_name(), spare.display_name)
	view.sync_hover_at(Vector2(-50, -50))
	assert_eq(_sum_view().name, "SeriesSum", "weg vom Zeiger steht wieder die Summe")
	assert_eq(view.hover_pack_name(), "", "und niemand wird genannt")

## Die CAPTION ist am 2026-09-11 gestorben - der Info-Schirm fragt statt dessen
## nach dem PAKET unter dem Zeiger, und die ETAGE schlägt das Magazin.
func test_hover_pack_names_the_floor_before_the_magazine() -> void:
	var slotted := _valued_pack(0, 3)
	var spare := _valued_pack(1, 2)
	view.slot_pack(slotted.pack_uid)
	await wait_frames(2)
	assert_null(view.hover_pack(), "ohne Zeiger liegt keine Karte da")
	view.sync_hover_at(view.pack_anchor_px(spare.pack_uid))
	assert_eq(view.hover_pack(), spare, "die Magazin-Kassette unter dem Zeiger")
	view.sync_hover_at(view._slot_buttons[0].get_global_rect().get_center())
	view._hover_pack_uid = spare.pack_uid  # beides zugleich: die Etage gewinnt
	assert_eq(view.hover_pack(), slotted)
	assert_false(view.get_script().get_script_constant_map().has("CAPTION_STEPS"),
		"die Konstanten der Caption sind fort")
	assert_false(view.has_method("set_caption"), "und ihr Schreiber ebenso")
	assert_false(view.has_method("caption_text"))

## Und eine Zelle des Summen-Netzes erklärt sich selbst: Zahl und Material im
## Klartext, aus denselben Quellen wie jedes andere Netz.
func test_a_sum_cell_explains_itself() -> void:
	var value := _valued_pack(0, 2)
	var stuff := run.grant_pack(Pack.material_pack())
	stuff.stamp_net = StampNet.empty_net()
	stuff.stamp_net[1] = StampNet.material_cell(DieMaterial.RUBY)
	view.slot_pack(value.pack_uid)
	view.slot_pack(stuff.pack_uid)
	await wait_frames(2)
	var rect := _sum_view().get_global_rect()
	var cell := view._sum_cell
	var number := rect.position + DieNetView.cell_position(0, cell) + Vector2.ONE * cell * 0.5
	assert_true(view.net_hint_at(number).contains("+2"),
		"die Zahl-Zelle nennt ihren Zuschlag: %s" % view.net_hint_at(number))
	var stone := rect.position + DieNetView.cell_position(1, cell) + Vector2.ONE * cell * 0.5
	assert_true(view.net_hint_at(stone).contains(DieMaterial.by_id(DieMaterial.RUBY).display_name),
		"die Material-Zelle nennt ihr Material: %s" % view.net_hint_at(stone))

# --- Was scene_root an der Reihe abliest -------------------------------------------

func test_the_row_reports_sorts_places_and_cards() -> void:
	var number := run.grant_pack(Pack.number_pack())
	var material := run.grant_pack(Pack.material_pack())
	view.slot_pack(number.pack_uid)
	view.slot_pack(material.pack_uid)
	await wait_frames(2)
	assert_eq(view.press_slot_sorts(),
		[Engraving.CATEGORY_NUMBER, Engraving.CATEGORY_MATERIAL] as Array[String])
	assert_eq(view.press_slot_anchors().size(), view.slot_count(),
		"auch die leeren Schächte melden ihren Mund")
	assert_eq(view.press_display_anchors().size(), view.slot_count())

## Die Körper gehören scene_root, den PLATZ meldet das Fenster - seit der WELLE S
## ist es EIN Podest, und seit der WELLE Z steht es RECHTS vom Netz-Schirm.
func test_the_window_reports_the_one_podium() -> void:
	await wait_frames(2)
	assert_true(view.bench_open(), "die Straße ist Möbel, kein Ablauf")
	assert_gt(view.target_net_center().x, 0.0, "das Podest meldet seine Mitte")
	assert_eq(view.target_projector_y(), view.target_net_center().y,
		"Zeile und Mitte sind derselbe Platz")
	assert_gt(view.target_net_center().x, view.ist_screen_rect().end.x
		+ view.get_global_rect().position.x, "es steht RECHTS vom Netz-Schirm")
	assert_false(view.has_method("result_net_center"),
		"und ein zweites Podest gibt es nicht mehr")

# --- Der Zeiger hebt den Beitrag EINER Karte hervor --------------------------------

func test_hovering_a_card_highlights_its_cells() -> void:
	var pack := _valued_pack(4, 2)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	assert_true(view._net.highlight.is_empty(), "ohne Zeiger leuchtet alles gleich")
	view.sync_hover_at(view._slot_buttons[0].get_global_rect().get_center())
	await wait_frames(2)
	assert_eq(view._net.highlight, [4] as Array[int],
		"die überfahrene Karte zeigt IHRE Zelle")

func test_a_fresh_run_drops_the_standing_series() -> void:
	var uids := _stock(1)
	view.slot_pack(uids[0])
	view.choose_target(2)
	await wait_frames(2)
	view.run = GameRun.new_run()
	await wait_frames(2)
	assert_true(view.press_slot_uids().is_empty(), "die Reihe des alten Laufs ist fort")
	assert_null(view.target_die(), "und sein Ziel ebenso")

# --- Die SCHACHT-REIHE: das Fenster malt nur Löcher und MELDET ihre Anker ----------

## Die 2D-Karten-Attrappen sind mit der Bühnen-Straße gestorben: im Fenster steht
## kein Abbild einer Kassette mehr, nur ihr Schacht - der Körper gehört scene_root.
func test_the_row_carries_no_card_mockups() -> void:
	var uids := _stock(1)
	view.slot_pack(uids[0])
	await wait_frames(2)
	assert_false("SlotCard" in _node_names(view), "keine Karten-Attrappe im Fenster")
	assert_false("SlotCardSeat" in _node_names(view))
	assert_eq(view._slot_buttons.size(), view.step_count(),
		"gemeldet werden die ETAGEN-FELDER, nicht gemalte Karten")

## Alle Namen im Fensterbaum - der Beweis, dass etwas NICHT mehr gebaut wird.
func _node_names(root: Node) -> Array[String]:
	var names: Array[String] = []
	for child in root.get_children():
		names.append(String(child.name))
		names.append_array(_node_names(child))
	return names

## Fach-Anker und Karten-Fläche sind derselbe Platz (die Karte LIEGT in ihrem
## Fach) - und beide rühren sich beim Legen keinen Byte weit.
func test_the_fach_anchors_stand_still_through_slotting() -> void:
	var uids := _stock(2)
	await wait_frames(2)
	var mouths := view.press_slot_anchors()
	var faces := view.press_display_anchors()
	assert_eq(mouths, faces, "das FACH IST die Karten-Fläche")
	view.slot_pack(uids[0])
	await wait_frames(2)
	assert_eq(view.press_slot_anchors(), mouths, "gelegt: die Fächer stehen")
	view.clear_press_slot(0)
	await wait_frames(2)
	assert_eq(view.press_slot_anchors(), mouths, "zurückgenommen: sie stehen weiter")

## Umsortieren tauscht die uids der Plätze - der KÖRPER fährt um, das Fenster
## meldet dafür nur die neue Reihenfolge auf denselben Ankern.
func test_reordering_keeps_the_anchors_and_swaps_the_uids() -> void:
	run.hub_level = 10
	view.refresh()
	var uids := _stock(2)
	view.slot_pack(uids[0])
	view.slot_pack(uids[1])
	await wait_frames(2)
	var anchors := view.press_slot_anchors()
	view.move_slot(1, 0)
	await wait_frames(2)
	assert_eq(view.press_slot_uids(), [uids[1], uids[0]] as Array[int],
		"die Reihenfolge IST die Rechenreihenfolge")
	assert_eq(view.press_slot_anchors(), anchors, "der Turm selbst steht still")

## WELLE L: die Karte in ihrer Etage LIEGT in der EINEN Kartengröße - derselben wie
## im Magazin. Das eigene Schacht-Maß (socket_cell_scale) ist gestorben.
func test_a_tower_cassette_lies_at_the_one_card_size() -> void:
	view.data_cell_px = Vector2(16, 40)
	await wait_frames(2)
	assert_almost_eq(view.lie_span_px().y, 40.0 * PackDrawerView.CASSETTE_SCALE,
		0.001, "die KARTENBREITE in ihrer einen Größe")
	assert_almost_eq(view.lie_span_px().x,
		40.0 * WorkshopView.CARD_ASPECT * PackDrawerView.CASSETTE_SCALE, 0.001,
		"und ihre Langseite quer dazu")
	assert_almost_eq(view.shelf_cell_scale(), PackDrawerView.CASSETTE_SCALE, 0.001,
		"und das Magazin stellt sie in genau derselben - Turm == Magazin")
	assert_false(view.has_method("socket_cell_scale"),
		"es gibt keinen kontext-eigenen Maßstab mehr")

# --- WELLE X: EINE Kartengröße, der TURM paßt sich an -----------------------------

## Der TURM-Fußabdruck kommt aus der KARTE plus Luft, nicht aus der Etagenzahl: er
## ist bei einer wie bei sechs Etagen gleich groß - der Turm wächst nach OBEN.
func test_the_tower_footprint_is_the_lying_card_plus_air() -> void:
	view.data_cell_px = Vector2(8, 24)
	view.refresh()
	await wait_frames(2)
	var short := view.tower_span_px()
	assert_almost_eq(short.y, view.lie_span_px().y * WorkshopView.TOWER_ROOM, 0.001,
		"die Kartenbreite plus Luft")
	var short_circuit: Array[String] = [DealClause.SHORT_CIRCUIT]
	run.sign_clauses(short_circuit)
	view.refresh()
	await wait_frames(2)
	assert_eq(view.step_count(), 1, "ein ganz kurzer Turm")
	assert_almost_eq(view.tower_span_px().x, short.x, 0.001,
		"und er zerdrückt die Karte NICHT - der Fußabdruck bleibt ihr treu")

## Die ETAGEN-FELDER teilen sich EINE Spalte: mehr Etagen heißt schmalere Felder,
## nicht eine breitere Leiste.
func test_more_floors_split_the_same_strip() -> void:
	view.data_cell_px = Vector2(8, 24)
	view.refresh()
	await wait_frames(2)
	assert_gt(view._slot_buttons.size(), 1)
	var first: Rect2 = view._slot_buttons[0].get_global_rect()
	var second: Rect2 = view._slot_buttons[1].get_global_rect()
	assert_lt(second.position.y, first.position.y, "Etage 2 liegt HÖHER als Etage 1")
	assert_almost_eq(second.position.x, first.position.x, 0.001, "in EINER Spalte")
	assert_almost_eq(view.strip_rect().size.x,
		view.unit() * WorkshopView.STRIP_WIDTH, 0.001, "die Leiste hat EINE Breite")

## Der STREIFEN wächst mit dem TURM in die BREITE, statt die Karten zu schrumpfen -
## und die Zeilenhöhe hängt nicht mehr an der Etagenzahl.
func test_the_strip_grows_sideways_instead_of_shrinking_the_cards() -> void:
	var u := 5.0
	var net := 125.0
	var stage := 94.0
	assert_almost_eq(WorkshopView.bench_height_for(u, net, 97.0, stage),
		WorkshopView.bench_height_for(u, net, 97.0, stage), 0.001,
		"die Höhe kennt die Etagenzahl gar nicht")
	var narrow := WorkshopView.bench_width_for(u, 168.3, 100.0, stage, 100.0)
	var wide := WorkshopView.bench_width_for(u, 168.3, 160.0, stage, 160.0)
	assert_gt(wide, narrow, "ein größerer Turm macht den Streifen breiter")

## Der STREIFEN ist BREITER als die Treppen-Spalte war - dafür ist er FLACH, und
## die Kamera kommt näher.
func test_the_tower_strip_trades_height_for_width() -> void:
	var u := 5.0
	var net := 125.0
	var stage := 94.0
	var now := WorkshopView.bench_height_for(u, net, 97.3, stage)
	# Die Treppe war sechs liegende Karten hoch: 6 x 90 px plus Netz und u-Kette.
	var was := 90.0 * 6.0 + net
	assert_lt(now, was, "die Zeile ist %.1f px hoch statt %.1f px" % [now, was])

## Die MASSEINHEIT darf von außen vorgegeben werden: der Streifen ist breiter als
## seine 100 u, sonst zerrisse die gewachsene Reihe die senkrechte Rechnung.
func test_the_reported_unit_beats_the_window_width() -> void:
	view.unit_px = 0.0
	await wait_frames(2)
	var own := view.size.x / 100.0
	assert_almost_eq(view.unit(), own, 0.001, "ohne Meldung die u-Konvention")
	view.unit_px = own * 0.5
	await wait_frames(2)
	assert_almost_eq(view.unit(), own * 0.5, 0.001, "gemeldet schlägt gerechnet")

## (2) Die gemeldeten ANKER zeigen alle auf den TURM-Platz: alle Karten liegen über
## DEMSELBEN Fußabdruck, nur die HÖHE unterscheidet sie - und die rechnet der Körper.
func test_the_anchors_all_name_the_tower_place() -> void:
	await wait_frames(2)
	var anchors := view.press_slot_anchors()
	assert_eq(anchors, view.press_display_anchors(),
		"Turm-Platz und Kartenfläche liegen aufeinander")
	assert_eq(anchors.size(), view.step_count())
	var centre := view.get_global_rect().position + view.tower_rect().get_center()
	for i in anchors.size():
		assert_almost_eq(anchors[i].x, centre.x, 0.001)
		assert_almost_eq(anchors[i].y, centre.y, 0.001)

# --- DER EINE NETZ-SCHIRM unter dem Podest (WELLE S) -------------------------------
# Die Aufschlüsselungs-Zeilen sind tot, die dritte Spalte auch - der Schirm trägt
# das EINE Netz: Vorschau, Ergebnis, grüne Deltas.

## Er trägt keinen eigenen Hintergrund (blanker Filz).
func test_the_net_screen_has_no_background() -> void:
	await wait_frames(2)
	assert_true(view._ist_screen.get_theme_stylebox("panel") is StyleBoxEmpty,
		"der Netz-Schirm steht auf blankem Filz")

## Die Diff-Zeilen sind restlos fort - weder Rechnung noch Zeilen-Hover.
func test_the_breakdown_rows_are_dead() -> void:
	assert_false(view.has_method("diff_rows"), "keine Aufschlüsselungs-Zeilen mehr")
	assert_false(view.has_method("diff_row_slot_at"), "und kein Zeilen-Hover")

## Das Zellmaß ist die gemeldete WÜRFELFLÄCHE, und Netz wie Summen-Schirm teilen es.
func test_both_nets_share_the_die_face_cell() -> void:
	view.die_face_px = 28.0
	view.choose_target(0)
	await wait_frames(2)
	assert_almost_eq(view._net.cell, 28.0, 0.001, "das Netz trägt die Würfelfläche")
	assert_almost_eq(view.sum_net_cell(view.unit()), 28.0, 0.001,
		"und der Summen-Schirm dasselbe Maß")

## OHNE Ziel rechnet der Netz-Schirm nichts - er hängt allein am gewählten
## Zielwürfel; der wartende Neuzugang wird von der Info-Säule am Fach gezeigt.
func test_the_net_screen_hangs_on_the_target_alone() -> void:
	run.stash_die(DieDefinition.standard(), 0)  # stash_die hinterlegt eine eigene Kopie
	await wait_frames(2)
	assert_null(view.preview_target(), "ohne Ziel steht kein Würfel im Schirm")
	assert_true(view.preview().is_empty())
	view.choose_target(0)
	await wait_frames(2)
	assert_eq(view.preview_target(), view.target_die(), "gewählt rechnet er auf ihm")
	view.clear_target()
	await wait_frames(2)
	assert_null(view.preview_target(), "abgewählt ist er wieder dunkel")

# --- WELLE U: DER BLOCK und der SCANNER --------------------------------------------

## Die SCHABLONEN-FAHRT ist tot: kein Wechsel-Takt, keine Schiene, keine Faltung -
## das Fenster meldet nur noch Abflug, Presshub und Scan.
func test_the_stencil_ride_is_gone() -> void:
	await wait_frames(2)
	assert_false(view.has_signal("die_handover"), "kein Wechsel-Takt mehr")
	assert_false(view.has_signal("stencil_launched"), "und keine Schablone mehr")
	assert_false(view.has_signal("stencil_folded"))
	assert_false(view.has_method("dim_ist_net"), "das Netz gibt nichts mehr ab")
	assert_false(view.has_signal("card_fused"), "und kein wachsender Block mehr")
	assert_false(view.has_signal("block_travelled"))
	assert_false(view.has_signal("stack_lifted"), "und keine LAWINE mehr")
	assert_false(view.has_signal("stack_slid"))
	assert_false(view.has_signal("stack_dropped"))
	assert_false(view.has_signal("stack_scanned"))
	assert_true(view.has_signal("cards_latched"))
	assert_true(view.has_signal("die_raised"))
	assert_true(view.has_signal("light_passed"))
	assert_true(view.has_signal("light_struck"))
	assert_true(view.has_signal("die_returned"))
	var net := view.ist_net_center()
	assert_gt(net.x, 0.0, "der Parkplatz des Netzes steht")
	assert_gt(net.x, view.tower_rect().get_center().x
		+ view.get_global_rect().position.x, "und liegt RECHTS des Turms")

## Der Zielwürfel behält seine ALTEN Augen, bis der Scanner sie aufdeckt: held_faces
## trägt den Stand VOR dem Griff und ist danach wieder leer.
func test_the_window_holds_the_faces_before_the_grip() -> void:
	var pack := _valued_pack(0, 4)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	assert_null(view.held_faces(), "ohne Zeremonie hält es nichts")
	var before: int = run.owned_pool[0].faces[0]
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	await wait_frames(2)
	var held := view.held_faces()
	assert_not_null(held, "während der Zeremonie steht der alte Stand")
	assert_eq(held.faces[0], before)
	assert_eq(run.owned_pool[0].faces[0], before + 4, "gebucht ist längst")
	view.skip_ceremony()
	await wait_frames(2)
	assert_null(view.held_faces(), "danach hält es nichts mehr")

## Die Kartendaten der Zeremonie tragen die PAKETGRÖSSE - daraus nimmt der Block
## seine Intensität.
func test_the_card_data_carries_the_tier() -> void:
	var pack := _valued_pack(0, 2)
	pack.tier = Pack.TIER_KOLOSSAL
	assert_eq(int(WorkshopView.card_data(pack.pack_uid, pack).get("tier", -1)),
		Pack.TIER_KOLOSSAL)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	await wait_frames(2)
	var cards := view.burning_cards()
	assert_eq(cards.size(), GameRun.SERIES_SLOT_CAP)
	assert_eq(int(cards[0].get("tier", -1)), Pack.TIER_KOLOSSAL)
	assert_false(view.burn_projection().is_empty(), "und die Projektion steht")
	view.skip_ceremony()

## Der Takt der letzten Etappe: der Einschlag, dann der Rückflug - dazwischen nichts.
func test_the_last_leg_is_striking_then_returning() -> void:
	var pack := _valued_pack(0, 3)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var beats := _record_press()
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	await wait_seconds(view.ceremony_time() + 0.35)
	assert_eq(String(beats[-2][0]), "struck", "erst schlagen die Funken ein")
	assert_eq(String(beats[-1][0]), "returned", "dann fliegt der Würfel zurück")

## Skip MITTEN im LICHT: das Ende ist genau einmal gemeldet, die Reihe leer, und der
## Endstand ist derselbe wie bei der ausgefahrenen Zeremonie.
func test_a_skip_inside_the_light_owes_nothing() -> void:
	var pack := _valued_pack(3, 4)
	view.slot_pack(pack.pack_uid)
	view.choose_target(2)
	await wait_frames(2)
	var before: int = run.owned_pool[2].faces[3]
	var seen: Array = []
	view.series_applied.connect(func(_result: Dictionary, _px: Vector2) -> void:
		seen.append(true))
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	await wait_seconds(view.latch_time() + WorkshopView.RAISE_TIME
		+ WorkshopView.LIGHT_STEP * 1.5)
	assert_true(view.burning(), "das Licht steigt noch")
	view.skip_ceremony()
	await wait_frames(2)
	assert_eq(seen.size(), 1, "der Griff ist genau einmal gemeldet")
	assert_true(view.press_slot_uids().is_empty(), "die Reihe ist leer")
	assert_eq(run.owned_pool[2].faces[3], before + 4, "gebucht ist gebucht")
	assert_true(view.showing_result(), "und das Ergebnis steht")

## Nach der Buchung STEHT das Ergebnis: das Netz zeigt den gebuchten Würfel mit den
## grünen Deltas - bis abgewählt wird.
func test_the_result_stands_until_the_target_is_dropped() -> void:
	var pack := _valued_pack(1, 3)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var before: int = run.owned_pool[0].faces[1]
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	assert_true(view.showing_result(), "das Ergebnis steht")
	assert_eq(view._net.def.faces[1], before, "das Netz mißt gegen den Stand DAVOR")
	assert_eq(view._net.preview_die().faces[1], before + 3,
		"und zeigt darüber den gebuchten - das ist das Grün")
	view.clear_target()
	await wait_frames(2)
	assert_false(view.showing_result(), "abgewählt verfällt das Ergebnis")
	assert_true(view.preview().is_empty(), "und es gibt nichts mehr zu rechnen")

## Ein ANDERES Ziel räumt das Ergebnis ebenso fort - es gehört EINEM Würfel.
func test_another_target_drops_the_standing_result() -> void:
	var pack := _valued_pack(0, 2)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	assert_true(view.showing_result())
	view.choose_target(3)
	await wait_frames(2)
	assert_false(view.showing_result(), "das Ergebnis gehörte dem anderen Würfel")
	assert_eq(view.target_die(), run.owned_pool[3], "das Ziel ist der neue")

## Eine frisch gesteckte Karte übernimmt den Schirm sofort wieder als VORSCHAU -
## das stehende Ergebnis ist ein Nachklang, kein Zustand.
func test_a_fresh_card_takes_the_screen_back_from_the_result() -> void:
	run.hub_level = 10
	view.refresh()
	var first := _valued_pack(0, 2)
	var second := _valued_pack(4, 1)
	view.slot_pack(first.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	_fill_row()  # der Griff verlangt eine VOLLE Reihe
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	assert_true(view.showing_result())
	view.slot_pack(second.pack_uid)
	await wait_frames(2)
	assert_false(view.showing_result(), "die neue Karte rechnet, statt zu erinnern")
	assert_eq(view.preview_target(), run.owned_pool[0], "und zwar auf dem echten Würfel")
	assert_eq(int(view.preview()["bonus"][4]), 1, "mit ihrem eigenen Beitrag")

# --- WARUM der Griff schweigt ------------------------------------------------------
## Eine geschlossene Bremse stand bisher stumm im Knopf: der Spieler sah einen
## grauen Griff und keinen Grund. Die Caption nennt die ERSTE geschlossene.

func test_a_ready_grip_says_nothing() -> void:
	view.set_target_die(run.owned_pool[0])
	view.slot_pack(_valued_pack(0, 2).pack_uid)
	_fill_row()
	assert_true(view.can_pull(), "Ziel plus volle Reihe reicht")
	assert_eq(view.grip_blocker(), "", "wer greifen darf, bekommt keine Mahnung")

func test_a_zurred_round_names_itself() -> void:
	view.set_target_die(run.owned_pool[0])
	view.slot_pack(_valued_pack(0, 2).pack_uid)
	_fill_row()
	view.editing_locked = true
	assert_false(view.can_pull())
	assert_true(view.grip_blocker().contains("gezurrt"),
		"die gesperrte Werkstatt nennt sich: %s" % view.grip_blocker())

func test_a_missing_target_names_itself() -> void:
	var pack := _valued_pack(0, 2)
	view.slot_pack(pack.pack_uid)
	assert_null(view.target_die(), "ohne Tipp auf den Vorrat steht kein Ziel")
	assert_true(view.grip_blocker().contains("Ziel"),
		"das fehlende Ziel nennt sich: %s" % view.grip_blocker())

## Der KURZSCHLUSS deckelt die Reihe unter sechs - dann sagt der Griff das ehrlich.
## OFFEN: unter dieser Klausel ist die Werkstatt unbenutzbar.
func test_the_short_circuit_names_itself() -> void:
	view.set_target_die(run.owned_pool[0])
	view.slot_pack(_valued_pack(0, 2).pack_uid)
	var short_circuit: Array[String] = [DealClause.SHORT_CIRCUIT]
	run.sign_clauses(short_circuit)
	await wait_frames(2)
	assert_lt(run.series_slots(), GameRun.SERIES_SLOT_CAP)
	assert_false(view.can_pull())
	assert_true(view.grip_blocker().contains("Kurzschlu"),
		"der Kurzschluß nennt sich: %s" % view.grip_blocker())

## Die halbleere Reihe nennt sich - der Block IST sechs Karten.
func test_a_half_empty_row_names_itself() -> void:
	view.set_target_die(run.owned_pool[0])
	for i in GameRun.SERIES_SLOT_CAP - 1:
		view.slot_pack(_valued_pack(0, 1).pack_uid)
	assert_false(view.can_pull(), "fünf Karten greifen nicht")
	assert_true(view.grip_blocker().contains("sechs Karten"),
		"die halbleere Reihe nennt sich: %s" % view.grip_blocker())
	view.slot_pack(_valued_pack(1, 1).pack_uid)
	assert_true(view.can_pull(), "die sechste macht sie voll")
	assert_eq(view.grip_blocker(), "")
