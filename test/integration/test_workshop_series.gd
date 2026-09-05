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
	# Die HÖHE wie am Tisch GELÖST (WELLE S): Kerf und Netz sind feste Pixel.
	var u := view.unit()
	view.size.y = roundf(WorkshopView.bench_height_for(u, view.mouth_size(u).y,
		view.net_span(u).y))
	view.refresh()  # die neue Höhe will gebaut werden, sonst steht die alte Seite

## Legt count Zahlen-Pakete ins Magazin und liefert ihre uids.
func _stock(count: int) -> Array[int]:
	var uids: Array[int] = []
	for i in count:
		var pack := run.grant_pack(Pack.number_pack())
		uids.append(pack.pack_uid)
	return uids

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
	view.refresh()
	await wait_frames(2)
	assert_eq(view._slot_buttons.size(), run.series_slots(),
		"der Taktgeber verlängert die Schaltung, und die Reihe zieht nach")
	assert_eq(run.series_slots(), 8, "zwei erkaufte Plätze über dem Sockel")

func test_a_shrunken_ladder_never_drops_a_standing_card() -> void:
	run.series_slot_bonus = 2
	view.refresh()
	var uids := _stock(8)
	for uid in uids:
		view.slot_pack(uid)
	await wait_frames(2)
	run.series_slot_bonus = 0
	view.refresh()
	await wait_frames(2)
	assert_eq(view.press_slot_uids().size(), 8, "die gesteckten Karten bleiben stecken")
	assert_eq(view.slot_count(), 8, "und die Reihe trägt sie alle")

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

func test_the_grip_needs_a_target_and_a_stamping_card() -> void:
	var uids := _stock(1)
	await wait_frames(2)
	assert_false(view.can_pull(), "nackt greift nichts")
	view.slot_pack(uids[0])
	assert_false(view.can_pull(), "ohne Ziel auch nicht")
	assert_true(view._action_button.disabled, "und der Sitz steht grau da")
	view.choose_target(0)
	assert_true(view.can_pull(), "Karte plus Ziel genügt")

func test_a_catalysts_only_series_never_stamps() -> void:
	run.grant_pack(Pack.catalyst(Pack.CATALYST_PROPELLANT))
	view.slot_pack(run.owned_packs[0].pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	assert_eq(view.stamping_card_count(), 0)
	assert_false(view.can_pull(), "Katalysatoren verstärken eine Projektion, sie sind keine")
	assert_true(view._action_button.disabled)

func test_a_spent_grip_locks_the_seat() -> void:
	run.press_uses = 1
	var uids := _stock(1)
	view.slot_pack(uids[0])
	view.choose_target(0)
	await wait_frames(2)
	assert_false(view.can_pull(), "der Griff dieser Runde ist verbraucht")
	assert_true(view._action_button.disabled)
	run.reset_press_cycle()
	view.refresh()
	await wait_frames(2)
	assert_true(view.can_pull(), "die Unterschrift gibt ihn zurück")

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
	assert_true(view.can_pull(), "der Griff steht mit EINEM Ziel bereit")
	var before: int = run.owned_pool[0].faces[0]
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
	view.pull_lever()
	assert_eq(run.owned_pool[0].faces[0], before + 3, "gebucht ist sofort")
	assert_eq(run.press_uses, 1, "und der Griff der Sitzung ist verbraucht")
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
	view.pull_lever()
	assert_true(view.burning(), "die Fahrt läuft")
	assert_true(seen.is_empty(), "und meldet erst am Ende")
	view.skip_ceremony()
	await wait_frames(2)
	assert_false(view.burning(), "übersprungen ist sie fertig")
	assert_eq(seen.size(), 1, "und der Griff ist gemeldet")
	assert_eq(int(Dictionary(seen[0]).get("cards", 0)), 1)

# --- DIE SCHABLONEN-FAHRT ----------------------------------------------------------

## Alle Takt-Meldungen der Fahrt in Reihenfolge, als [Kennung, Nutzlast].
func _record_stencil() -> Array:
	var beats: Array = []
	view.stencil_launched.connect(func(_t: float) -> void: beats.append(["born"]))
	view.stencil_moved.connect(func(to: Vector2, _t: float) -> void:
		beats.append(["move", to]))
	view.stencil_read.connect(func(index: int, faces: Array, values: Array,
			operator: String, _t: float) -> void:
		beats.append(["read", index, faces, values, operator]))
	view.stencil_landed.connect(func(_t: float) -> void: beats.append(["land"]))
	view.stencil_folded.connect(func(_t: float) -> void: beats.append(["fold"]))
	return beats

## Es gibt genau EIN Netz, und es PARKT im Netz-Schirm der Würfel-Spalte: der
## Schirm hält nur seinen Platz, das Netz selbst liegt genau darauf und fährt nie.
func test_the_net_screen_parks_the_one_net() -> void:
	await wait_frames(2)
	assert_eq(view._net_host.get_child_count(), 0, "der Parkplatz selbst ist leer")
	assert_almost_eq(view._net.get_global_rect().get_center().x,
		view.ist_net_center().x, 0.5, "das Netz steht auf der gemeldeten Mitte")
	assert_almost_eq(view._net.get_global_rect().get_center().y,
		view.ist_net_center().y, 0.5)

## Der Griff GEBIERT die Schablone (den Ort nennt scene_root - dort steht die
## Info-Säule) und schickt sie dann auf die Schiene über der Reihe.
func test_the_grip_births_the_stencil_before_the_rail() -> void:
	var pack := _valued_pack(0, 3)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var beats := _record_stencil()
	view.pull_lever()
	await wait_seconds(WorkshopView.STENCIL_BIRTH_TIME
		+ WorkshopView.STENCIL_TO_RAIL_TIME + 0.1)
	assert_true(view.burning(), "die Fahrt läuft noch")
	assert_eq(String(beats[0][0]), "born", "erst die Geburt")
	assert_eq(String(beats[1][0]), "move", "dann die Auffahrt auf die Schiene")
	var entry: Vector2 = beats[1][1]
	assert_lt(entry.x, view.press_display_anchors()[0].x,
		"sie setzt VOR der ersten Karte an")
	assert_almost_eq(entry.y, view._rail_seat_y(), 0.5, "auf der Schienenhöhe")
	view.skip_ceremony()

## Je Karte EINE Aufnahme-Meldung, in Serienfolge, mit ihren Zellen und dem
## aufgelaufenen Stand - genau das, was die Kassette abdunkelt und die Schablone
## tickt. Zuletzt Podest und Faltung.
func test_every_card_reports_its_cells_and_the_running_sum() -> void:
	var first := _valued_pack(0, 2)
	var second := _valued_pack(3, 5)
	view.slot_pack(first.pack_uid)
	view.slot_pack(second.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var beats := _record_stencil()
	view.pull_lever()
	await wait_seconds(view.ceremony_time() + 0.35)
	var reads: Array = []
	for beat in beats:
		if String(beat[0]) == "read":
			reads.append(beat)
	assert_eq(reads.size(), 2, "je Karte genau eine Aufnahme")
	assert_eq(int(reads[0][1]), 0, "in Serienfolge")
	assert_eq(reads[0][2], [0] as Array[int], "Karte 1 gibt ihre Seite her")
	assert_eq(int(reads[0][3][0]), 2, "und der Stand danach ist ihr Wert")
	assert_eq(reads[1][2], [3] as Array[int])
	assert_eq(int(reads[1][3][0]), 2, "der Stand LÄUFT AUF - Karte 1 bleibt darin")
	assert_eq(int(reads[1][3][3]), 5)
	assert_eq(String(beats[-2][0]), "land", "dann das Podest")
	assert_eq(String(beats[-1][0]), "fold", "und die Faltung hinein")

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
	var beats := _record_stencil()
	view.pull_lever()
	await wait_seconds(view.ceremony_time() + 0.35)
	var operators: Array[String] = []
	for beat in beats:
		if String(beat[0]) == "read":
			operators.append(String(beat[4]))
	assert_eq(operators, ["", StampNet.OP_DOUBLER] as Array[String],
		"nur die Operator-Karte nennt einen")

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
	view.pull_lever()
	await wait_seconds(WorkshopView.STENCIL_BIRTH_TIME
		+ WorkshopView.STENCIL_TO_RAIL_TIME + 0.1)
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
	view.pull_lever()
	assert_lt(view.card_beat(1), view.card_beat(0), "die Rampe zieht an")
	assert_gt(view.card_beat(2), view.card_beat(1),
		"der Operator bekommt seine %.1f s dazu" % WorkshopView.STENCIL_OPERATOR_EXTRA)
	assert_gt(view.ceremony_time(), WorkshopView.STENCIL_FOLD_TIME,
		"und die Faltung ist nur ihr letzter Schlag")
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
	assert_not_null(view.get_node_or_null("Street/SumScreen/Caption"),
		"mit EINER Zeile darunter")

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

## Die CAPTION ist EINE Zeile, sie schreibt nur beim WECHSEL, und der Schacht
## schlägt das Magazin.
func test_the_caption_writes_on_change_and_names_the_shaft_first() -> void:
	var slotted := _valued_pack(0, 3)
	var spare := _valued_pack(1, 2)
	view.slot_pack(slotted.pack_uid)
	await wait_frames(2)
	assert_eq(view.caption_text(), "", "sie startet leer")
	view.set_caption("Zahlen-Paket")
	assert_eq(view.caption_text(), "Zahlen-Paket")
	view.set_caption("Zahlen-Paket")
	assert_eq(view.caption_text(), "Zahlen-Paket", "derselbe Text ändert nichts")
	view.set_caption("")
	assert_eq(view.caption_text(), "", "und die leere Zeile räumt sie")
	view.sync_hover_at(view._slot_buttons[0].get_global_rect().get_center())
	view._hover_pack_uid = spare.pack_uid  # beides zugleich: der Schacht gewinnt
	assert_eq(view.hover_pack_name(), slotted.display_name)

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
## ist es EIN Podest, und es steht auf der Zeilenhöhe der Schacht-Reihe.
func test_the_window_reports_the_one_podium() -> void:
	await wait_frames(2)
	assert_true(view.bench_open(), "die Straße ist Möbel, kein Ablauf")
	assert_gt(view.target_net_center().x, 0.0, "das Podest meldet seine Mitte")
	assert_eq(view.target_projector_y(), view.target_net_center().y,
		"Zeile und Mitte sind derselbe Platz")
	assert_lt(view.target_net_center().y, view.ist_screen_rect().position.y
		+ view.get_global_rect().position.y, "es steht ÜBER dem Netz-Schirm")
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
	assert_eq(view._card_panels.size(), view.slot_count(),
		"gemeldet werden die Karten-FLÄCHEN, nicht gemalte Karten")

## Alle Namen im Fensterbaum - der Beweis, dass etwas NICHT mehr gebaut wird.
func _node_names(root: Node) -> Array[String]:
	var names: Array[String] = []
	for child in root.get_children():
		names.append(String(child.name))
		names.append_array(_node_names(child))
	return names

## Mund und Karten-Fläche liegen auf demselben Platz (die Karte steht geneigt über
## ihrem Schacht) - und beide Anker rühren sich beim Stecken keinen Byte weit.
func test_the_shaft_anchors_stand_still_through_slotting() -> void:
	var uids := _stock(2)
	await wait_frames(2)
	var mouths := view.press_slot_anchors()
	var faces := view.press_display_anchors()
	assert_eq(mouths, faces, "der Mund IST die Karten-Fläche")
	view.slot_pack(uids[0])
	await wait_frames(2)
	assert_eq(view.press_slot_anchors(), mouths, "gesteckt: die Münder stehen")
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
	assert_eq(view.press_slot_anchors(), anchors, "die Schächte selbst stehen still")

## WELLE L: die Schacht-Kassette steht in der EINEN Kartengröße - derselben wie im
## Magazin. Das eigene Schacht-Maß (socket_cell_scale) ist gestorben.
func test_a_shaft_cassette_stands_at_the_one_card_size() -> void:
	view.data_cell_px = Vector2(60, 16)
	await wait_frames(2)
	assert_almost_eq(view.card_span_px(), 60.0 * PackDrawerView.CASSETTE_SCALE,
		0.001, "die KAPPENBREITE der Karte in ihrer einen Größe")
	assert_almost_eq(view.shelf_cell_scale(), PackDrawerView.CASSETTE_SCALE, 0.001,
		"und das Magazin stellt sie in genau derselben - Slot == Magazin")
	assert_false(view.has_method("socket_cell_scale"),
		"es gibt keinen kontext-eigenen Maßstab mehr")

# --- WELLE L: EINE Kartengröße, die Reihe paßt sich an ----------------------------

## (3) Der MUND kommt aus der KARTE plus Fuge, nicht mehr aus dem Platz: er ist bei
## zwei wie bei acht Schächten gleich groß.
func test_the_mouth_is_the_card_plus_its_gap() -> void:
	view.data_cell_px = Vector2(24, 8)
	view.refresh()
	await wait_frames(2)
	var short := view.mouth_width(view.unit())
	assert_almost_eq(short, view.card_span_px() * WorkshopView.MOUTH_ROOM, 0.001,
		"die Kappenbreite plus Luft")
	run.hub_level = 10
	run.series_slot_bonus = 4
	view.refresh()
	await wait_frames(2)
	assert_gt(view.slot_count(), 5, "eine lange Serie")
	assert_almost_eq(view.mouth_width(view.unit()), short, 0.001,
		"und sie zerdrückt die Karte NICHT - der Mund bleibt der Karte treu")

## Und im Bild steht die Fuge auch: zwischen zwei SLOTS klafft eine halbe
## Mundbreite - deutlich mehr, als das alte u-Maß hergab.
func test_two_shafts_stand_a_real_gap_apart() -> void:
	view.data_cell_px = Vector2(24, 8)  # kleine Karte: die Reihe paßt bequem
	run.hub_level = 10
	# Der Streifen wird auf die Reihe GELÖST, wie scene_root ihn stellt - sonst kappt
	# ihn schon das Rückfallmaß und die Fuge schließt sich.
	var u0 := view.size.x / 100.0
	view.size.x = WorkshopView.bench_width_for(run.series_slots(), u0,
		24.0 * PackDrawerView.CASSETTE_SCALE)
	view.unit_px = u0
	view.refresh()
	await wait_frames(2)
	var u := view.unit()
	assert_gt(view._slot_buttons.size(), 1)
	var first: Rect2 = view._slot_buttons[0].get_global_rect()
	var second: Rect2 = view._slot_buttons[1].get_global_rect()
	var gap: float = second.position.x - first.end.x
	assert_almost_eq(gap, view.mouth_width(u) * WorkshopView.MOUTH_GAP_SHARE, 0.5,
		"die Münder stehen nicht mehr bündig aneinander")
	assert_gte(gap, view.mouth_width(u) * 0.5 - 0.5,
		"und die Luft ist mindestens eine halbe Mundbreite")
	assert_lte(view.console_size(u).x, view.row_field_rect().size.x + 0.5,
		"und die Reihe bleibt trotzdem im Feld")

## Der gemalte SCHLITZ ist der Kartenteil, der hineinfährt - schmaler als sein Slot
## und mittig darin. Die KAPPE steht darüber, und der Knopf spannt sie.
func test_the_slit_is_narrower_than_its_slot_and_sits_centred() -> void:
	view.data_cell_px = Vector2(24, 8)
	view.data_cell_body_px = Vector2(9, 8)
	view.refresh()
	await wait_frames(2)
	var u := view.unit()
	var slit := view.slit_size(u)
	assert_lt(slit.x, view.mouth_size(u).x, "schmaler als der Slot")
	assert_almost_eq(slit.x / slit.y, 9.0 / 8.0, 0.01,
		"und in der Proportion des Körper-Fußabdrucks")
	var seat: Rect2 = view._slot_buttons[0].get_global_rect()
	var painted: Rect2 = view._slit_panels[0].get_global_rect()
	assert_almost_eq(painted.get_center().x, seat.get_center().x, 0.5, "mittig im Slot")
	assert_almost_eq(painted.get_center().y, seat.get_center().y, 0.5)
	assert_almost_eq(painted.size.x, slit.x, 0.5)
	assert_lt(painted.size.x, seat.size.x, "der Knopf bleibt der breitere Klickfang")

## (3) Der STREIFEN wächst mit der Reihe, statt die Karten zu schrumpfen: je Slot
## genau eine Kartenbreite plus eine Fuge mehr.
func test_the_strip_grows_instead_of_shrinking_the_cards() -> void:
	var u := 5.0
	var card := 110.0
	var mouth := card * WorkshopView.MOUTH_ROOM
	assert_almost_eq(WorkshopView.row_span(6, u, mouth)
		- WorkshopView.row_span(2, u, mouth),
		4.0 * mouth * (1.0 + WorkshopView.MOUTH_GAP_SHARE), 0.001,
		"je Karte eine Kartenbreite plus Fuge")
	var six := WorkshopView.bench_width_for(6, u, card)
	assert_gt(six, WorkshopView.bench_width_for(2, u, card),
		"sechs Karten brauchen mehr Streifen als zwei")
	assert_gt(WorkshopView.bench_width_for(8, u, card), six)
	assert_gte(WorkshopView.bench_width_for(1, u, card), u * 100.0,
		"und schmaler als seine 100 u wird der Streifen nie")

## WELLE O: die Reihe mißt jetzt an der KAPPE, nicht mehr an der Langseite - der
## Streifen wird bei JEDER Serienlänge schmaler. Die Kappe ist die BREITE der
## Karte, die alte Bezugsgröße war ihre LANGSEITE - also zwei Drittel davon.
func test_the_kerf_row_is_narrower_than_the_lying_row_was() -> void:
	var u := 5.0
	var lying := 140.0  # die Langseite, an der die Welle L maß
	var cap := lying * DataCellView.WIDTH / DataCellView.HEIGHT  # 93,3 px Kappe
	for slots in [2, 6]:
		var was := WorkshopView.bench_width_for(slots, u, lying)
		var now := WorkshopView.bench_width_for(slots, u, cap)
		assert_lt(now, was,
			"%d Schächte: %.1f px statt %.1f px" % [slots, now, was])

## Und die Karte bleibt auch dann groß, wenn der TISCH den Streifen kappt: dann
## rückt die TEILUNG zusammen, nie der Mund selbst.
func test_a_capped_strip_closes_the_gap_before_it_shrinks_a_card() -> void:
	view.data_cell_px = Vector2(60, 16)
	run.hub_level = 10
	run.series_slot_bonus = 4
	view.refresh()
	await wait_frames(2)
	var u := view.unit()
	assert_lt(view.mouth_step(u),
		view.mouth_width(u) * (1.0 + WorkshopView.MOUTH_GAP_SHARE),
		"die Fuge schließt sich")
	assert_almost_eq(view.mouth_width(u),
		view.card_span_px() * WorkshopView.MOUTH_ROOM, 0.001,
		"aber der Mund - und damit die Karte - bleibt")
	assert_gte(view.mouth_step(u), view.mouth_width(u) * WorkshopView.MOUTH_TIGHT,
		"aber nie enger als der Boden - die Karten decken sich nie ganz zu")

## Die MASSEINHEIT darf von außen vorgegeben werden: der Streifen ist breiter als
## seine 100 u, sonst zerrisse die gewachsene Reihe die senkrechte Rechnung.
func test_the_reported_unit_beats_the_window_width() -> void:
	await wait_frames(2)
	var own := view.size.x / 100.0
	assert_almost_eq(view.unit(), own, 0.001, "ohne Meldung die u-Konvention")
	view.unit_px = own * 0.5
	await wait_frames(2)
	assert_almost_eq(view.unit(), own * 0.5, 0.001, "gemeldet schlägt gerechnet")

## (2) Die gemeldeten ANKER zeigen weiter auf Mund- bzw. Kartenflächen-Mitte - die
## Schablonen-Fahrt fährt unverändert.
func test_the_anchors_still_name_the_card_faces() -> void:
	await wait_frames(2)
	var u := view.size.x / 100.0
	var mouths := view.press_slot_anchors()
	assert_eq(mouths, view.press_display_anchors(),
		"Mund und Kartenfläche liegen aufeinander")
	assert_eq(mouths.size(), view.slot_count())
	for i in mouths.size():
		var mouth: Rect2 = view._slit_panels[i].get_global_rect()
		assert_almost_eq(mouths[i].x, mouth.get_center().x, 0.001)
		assert_almost_eq(mouths[i].y, mouth.get_center().y, 0.001)
	assert_almost_eq(mouths[0].y, view._rail_seat_y(), u * 0.5,
		"und sie liegen auf der Zeile der Schiene")

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

# --- WELLE S: die FAHRT ENDET, WO SIE GEBOREN WURDE --------------------------------

## Die ÜBERGABE ist tot: die Schablone kehrt zum EINEN Netz zurück, der Würfel
## wechselt keine Seite mehr, und das Fenster kennt den Takt nicht mehr.
func test_the_handover_is_gone_and_the_stencil_comes_home() -> void:
	await wait_frames(2)
	assert_false(view.has_signal("die_handover"), "kein Wechsel-Takt mehr")
	assert_false(view.has_method("die_seat"), "und kein zweiter Landeplatz")
	assert_false(view.has_method("handover_time"))
	var net := view.ist_net_center()
	assert_gt(net.x, 0.0, "der Geburtsort steht")
	assert_lt(net.x, view.row_field_rect().get_center().x
		+ view.get_global_rect().position.x, "und liegt LINKS der Schacht-Reihe")

## Der Takt der letzten Etappe: Abfahrt, dann Faltung - dazwischen nichts.
func test_the_last_leg_is_landing_then_folding() -> void:
	var pack := _valued_pack(0, 3)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var beats := _record_stencil()
	view.pull_lever()
	await wait_seconds(view.ceremony_time() + 0.35)
	assert_eq(String(beats[-2][0]), "land", "erst die Abfahrt zum Podest")
	assert_eq(String(beats[-1][0]), "fold", "dann die Faltung hinein")

## Skip MITTEN in der Faltung: das Ende ist genau einmal gemeldet, die Reihe leer,
## und der Endstand ist derselbe wie bei der ausgefahrenen Fahrt.
func test_a_skip_inside_the_folding_owes_nothing() -> void:
	var pack := _valued_pack(3, 4)
	view.slot_pack(pack.pack_uid)
	view.choose_target(2)
	await wait_frames(2)
	var before: int = run.owned_pool[2].faces[3]
	var seen: Array = []
	view.series_applied.connect(func(_result: Dictionary, _px: Vector2) -> void:
		seen.append(true))
	view.pull_lever()
	await wait_seconds(view.ceremony_time() - WorkshopView.STENCIL_FOLD_TIME * 0.5)
	assert_true(view.burning(), "die Faltung läuft noch")
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
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	assert_true(view.showing_result())
	run.reset_press_cycle()
	view.slot_pack(second.pack_uid)
	await wait_frames(2)
	assert_false(view.showing_result(), "die neue Karte rechnet, statt zu erinnern")
	assert_eq(view.preview_target(), run.owned_pool[0], "und zwar auf dem echten Würfel")
	assert_eq(int(view.preview()["bonus"][4]), 1, "mit ihrem eigenen Beitrag")

# --- WARUM der Griff schweigt ------------------------------------------------------
## Eine geschlossene Bremse stand bisher stumm im Knopf: der Spieler sah einen
## grauen Griff und keinen Grund. Die Caption nennt die ERSTE geschlossene.

func test_a_ready_grip_says_nothing() -> void:
	var pack := _valued_pack(0, 2)
	view.set_target_die(run.owned_pool[0])
	view.slot_pack(pack.pack_uid)
	assert_true(view.can_pull(), "eine Karte reicht")
	assert_eq(view.grip_blocker(), "", "wer greifen darf, bekommt keine Mahnung")

func test_a_zurred_round_names_itself() -> void:
	var pack := _valued_pack(0, 2)
	view.set_target_die(run.owned_pool[0])
	view.slot_pack(pack.pack_uid)
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

func test_a_spent_grip_names_itself() -> void:
	var pack := _valued_pack(0, 2)
	view.set_target_die(run.owned_pool[0])
	view.slot_pack(pack.pack_uid)
	view.pull_lever()
	view.skip_ceremony()
	var again := _valued_pack(1, 2)
	view.slot_pack(again.pack_uid)  # das Ziel steht noch - ein zweiter Tipp wählte es AB
	assert_not_null(view.target_die(), "das Ziel überlebt den Griff")
	assert_false(run.press_allowed(), "der Griff der Sitzung ist weg")
	assert_true(view.grip_blocker().contains("verbraucht"),
		"der verbrauchte Griff nennt sich: %s" % view.grip_blocker())
