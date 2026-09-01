extends GutTest
## Die SERIENSCHALTUNG an der Werkbank: die Slot-Reihe wächst mit dem Hub, die
## Steckreihenfolge IST die Rechnung, das Ziel wählt der Spieler im Pool-Raster,
## und die Vorschau ist buchstäblich dieselbe Rechnung wie der Griff.

var view: WorkshopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = WorkshopView.new()
	view.size = Vector2(roundf(540.0 * WorkshopView.dossier_aspect()), 540)
	add_child_autofree(view)
	view.run = run

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

# --- Die Reihe wächst mit dem Hub ------------------------------------------------

func test_the_row_carries_exactly_the_series_slots() -> void:
	await wait_frames(2)
	assert_eq(view.slot_count(), run.series_slots(), "die Reihe IST die Serienlänge")
	assert_eq(view._slot_buttons.size(), run.series_slots())
	run.hub_level = 10
	view.refresh()
	await wait_frames(2)
	assert_eq(view._slot_buttons.size(), run.series_slots(),
		"die Lizenz verlängert die Schaltung, und die Reihe zieht nach")
	assert_gt(run.series_slots(), 2, "Stufe 10 ist mehr als der Sockel")

func test_a_shrunken_ladder_never_drops_a_standing_card() -> void:
	run.hub_level = 10
	view.refresh()
	var uids := _stock(4)
	for uid in uids:
		view.slot_pack(uid)
	await wait_frames(2)
	run.hub_level = 1
	view.refresh()
	await wait_frames(2)
	assert_eq(view.press_slot_uids().size(), 4, "die gesteckten Karten bleiben stecken")
	assert_eq(view.slot_count(), 4, "und die Reihe trägt sie alle")

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
	var uids := _stock(5)
	for uid in uids:
		view.slot_pack(uid)
	assert_eq(view.press_slot_uids().size(), run.series_slots(),
		"über die Serienlänge geht nichts")

func test_a_locked_round_bars_the_row() -> void:
	var uids := _stock(1)
	view.editing_locked = true
	assert_false(view.slot_pack(uids[0]), "unterschrieben wird nichts mehr gesteckt")

# --- Die ZIELWAHL im Pool-Raster --------------------------------------------------

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

func test_the_grid_highlights_what_is_chosen() -> void:
	await wait_frames(2)
	view.choose_target(2)
	await wait_frames(2)
	assert_eq(view._pool_grid._highlights, [2] as Array[int])

# --- Der GRIFF --------------------------------------------------------------------

func test_the_grip_needs_a_target_and_a_stamping_card() -> void:
	var uids := _stock(1)
	await wait_frames(2)
	assert_false(view.can_pull(), "nackt greift nichts")
	view.slot_pack(uids[0])
	assert_false(view.can_pull(), "ohne Ziel auch nicht")
	assert_true(String(view._action_button.get_meta("body", "")).contains("Raster"),
		"und der Grund steht auf dem Hinweis-Schirm")
	view.choose_target(0)
	assert_true(view.can_pull(), "Karte plus Ziel genügt")

func test_a_catalysts_only_series_never_stamps() -> void:
	run.grant_pack(Pack.catalyst(Pack.CATALYST_PROPELLANT))
	view.slot_pack(run.owned_packs[0].pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	assert_eq(view.stamping_card_count(), 0)
	assert_false(view.can_pull(), "Katalysatoren verstärken eine Projektion, sie sind keine")
	assert_true(String(view._action_button.get_meta("body", "")).contains("Netz"))

func test_a_spent_grip_locks_the_seat() -> void:
	run.press_uses = 1
	var uids := _stock(1)
	view.slot_pack(uids[0])
	view.choose_target(0)
	await wait_frames(2)
	assert_false(view.can_pull(), "der Griff dieser Runde ist verbraucht")
	assert_true(String(view._action_button.get_meta("body", "")).contains("verbraucht"))
	run.reset_press_cycle()
	view.refresh()
	await wait_frames(2)
	assert_true(view.can_pull(), "die Unterschrift gibt ihn zurück")

func test_the_doppelmatrize_asks_for_a_second_die() -> void:
	_valued_pack(0, 4)
	run.grant_pack(Pack.catalyst(Pack.CATALYST_MATRIX))
	for pack in run.owned_packs:
		view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	assert_true(view.needs_second(), "die Matrize will ein zweites Ziel")
	assert_false(view.can_pull(), "und ohne es greift der Hebel nicht")
	view.choose_target(5)
	assert_eq(view.second_die(), run.owned_pool[5])
	assert_true(view.can_pull())

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

# --- DIE DURCHLICHT-FAHRT ----------------------------------------------------------

## Es gibt genau EIN Summen-Netz, und es gehört dem SCHLITTEN: die Ziel-Säule hält
## nur seinen Parkplatz, und geparkt liegt sein Netz genau darauf.
func test_the_scanner_carries_the_one_sum_net() -> void:
	await wait_frames(2)
	assert_eq(view._net, view._scanner.net, "das Netz ist das Display des Schlittens")
	assert_eq(view._net_host.get_child_count(), 0, "der Parkplatz selbst ist leer")
	assert_almost_eq(view._net.get_global_rect().get_center().x,
		view.target_net_center().x, 0.5, "geparkt steht er auf der gemeldeten Mitte")
	assert_almost_eq(view._net.get_global_rect().get_center().y,
		view.target_net_center().y, 0.5)
	assert_false(view._scanner.riding(), "und er fährt nicht")

## Der Griff schickt ihn hinunter auf die Schiene: dort geht sein Netz durch die
## Karten, also steht es tiefer als sein Parkplatz und kleiner.
func test_the_grip_sends_the_scanner_down_to_the_rail() -> void:
	var pack := _valued_pack(0, 3)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var park := view.target_net_center()
	view.pull_lever()
	await wait_seconds(WorkshopView.SCAN_EMPTY_TIME + WorkshopView.SCAN_TO_RAIL_TIME + 0.1)
	assert_true(view.burning(), "die Fahrt läuft noch")
	assert_true(view._scanner.riding(), "und der Schlitten ist unterwegs")
	assert_gt(view._scanner.get_global_rect().get_center().y, park.y,
		"er steht auf der Schiene über der Reihe")
	assert_lt(view._scanner.scale.x, 1.0, "und fährt dort klein")
	assert_eq(view.target_net_center(), park, "der Parkplatz rührt sich nie")
	view.skip_ceremony()

## Die Fahrt darf JEDERZEIT abbrechen: der EINE Aufräum-Pfad stellt den Schlitten
## geparkt und ungefaltet zurück, die Reihe ist leer und der Griff gemeldet.
func test_an_aborted_ride_owes_nothing() -> void:
	var pack := _valued_pack(0, 4)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var park := view.target_net_center()
	var seen: Array = []
	view.series_applied.connect(func(_result: Dictionary, _px: Vector2) -> void:
		seen.append(true))
	view.pull_lever()
	await wait_seconds(WorkshopView.SCAN_EMPTY_TIME + WorkshopView.SCAN_TO_RAIL_TIME + 0.1)
	view.skip_ceremony()
	await wait_frames(2)
	assert_false(view._scanner.riding(), "er fährt nicht mehr")
	assert_eq(view._scanner.scale, Vector2.ONE, "und steht in voller Größe")
	assert_almost_eq(view._net.get_global_rect().get_center().x, park.x, 0.5,
		"wieder auf seinem Parkplatz")
	assert_almost_eq(view._net.get_global_rect().get_center().y, park.y, 0.5)
	assert_eq(view._net.get_child(0).scale, Vector2.ONE, "die Faltung ist aufgegangen")
	assert_true(view.press_slot_uids().is_empty(), "die Reihe ist leer")
	assert_eq(seen.size(), 1, "und der Griff ist genau einmal gemeldet")

## Die Fahrt AUSGEFAHREN (ohne Skip): danach ist die Reihe leer, der Sitz trägt
## wieder den Griff, und das Netz steht ungefaltet in voller Größe auf seinem
## Parkplatz. Derselbe Endzustand, den auch das "Fertig" liefert.
func test_the_full_ride_lands_in_the_same_end_state() -> void:
	var pack := _valued_pack(2, 4)
	view.slot_pack(pack.pack_uid)
	view.choose_target(1)
	await wait_frames(2)
	var park := view.target_net_center()
	view.pull_lever()
	var span := view.ceremony_time()
	await wait_seconds(span + 0.35)
	assert_false(view.burning(), "die Fahrt ist von selbst durch")
	assert_true(view.press_slot_uids().is_empty(), "die Reihe ist leer")
	assert_eq(view.series_text(), "", "und der Serien-Schirm dunkel")
	assert_true(String(view._action_button.text).begins_with("Griff"),
		"der Sitz trägt wieder den Griff, nicht das Fertig")
	assert_eq(view._scanner.scale, Vector2.ONE, "der Schlitten steht in voller Größe")
	assert_false(view._scanner.riding())
	assert_almost_eq(view._net.get_global_rect().get_center().x, park.x, 0.5,
		"das Netz steht auf seinem Parkplatz")
	assert_almost_eq(view._net.get_global_rect().get_center().y, park.y, 0.5)
	assert_eq(view._net.get_child(0).position,
		DieNetView.cell_position(0, view._net.cell), "die Faltung ist aufgegangen")
	assert_eq(view._net.get_child(0).scale, Vector2.ONE)

## Das Netz zeigt danach den GEBUCHTEN Würfel - die Fahrt hat nichts geschuldet.
func test_after_the_ride_the_net_shows_the_booked_die() -> void:
	var pack := _valued_pack(0, 5)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var before: int = run.owned_pool[0].faces[0]
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	assert_eq(view._net.def, run.owned_pool[0], "der echte Würfel steht wieder da")
	assert_eq(view._net.def.faces[0], before + 5)
	assert_true(view.preview().is_empty(), "und es gibt nichts mehr zu rechnen")

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
		"der Operator bekommt seine %.1f s dazu" % WorkshopView.SCAN_OPERATOR_EXTRA)
	assert_gt(view.ceremony_time(), WorkshopView.SCAN_FOLD_TIME,
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

# --- Der SERIEN-SCHIRM ------------------------------------------------------------

func test_the_screen_stays_dark_until_a_card_is_slotted() -> void:
	var uids := _stock(1)
	await wait_frames(2)
	assert_eq(view.series_text(), "", "ohne Karte sagt er nichts")
	assert_false(view._series_body.visible)
	view.slot_pack(uids[0])
	await wait_frames(2)
	assert_true(view._series_body.visible, "gesteckt spricht er")
	assert_true(view.series_text().contains("1 / %d Slots" % run.series_slots()))

func test_the_screen_names_the_slotted_catalysts() -> void:
	_valued_pack(0, 1)
	run.grant_pack(Pack.catalyst(Pack.CATALYST_PROPELLANT))
	for pack in run.owned_packs:
		view.slot_pack(pack.pack_uid)
	await wait_frames(2)
	assert_true(view.series_text().contains(Pack.catalyst_name(Pack.CATALYST_PROPELLANT)),
		"die eine Namensquelle ist Pack: %s" % view.series_text())

## Der Schirm ERKLÄRT sich nicht - sein Text ist ein Verweis, und ein Klick meldet
## die Eintrags-id nach draußen.
func test_the_series_word_is_a_lexikon_reference() -> void:
	var uids := _stock(1)
	view.slot_pack(uids[0])
	await wait_frames(2)
	assert_true(Lexikon.has_entry(Lexikon.SERIE), "der Eintrag steht im Katalog")
	assert_true(view._series_body.bbcode_enabled)
	var seen: Array[String] = []
	view.lexikon_requested.connect(func(id: String) -> void: seen.append(id))
	view._series_body.meta_clicked.emit(Lexikon.SERIE)
	assert_eq(seen, [Lexikon.SERIE] as Array[String])

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
		"auch die leeren Schlitze melden ihren Platz")
	assert_eq(view.press_display_anchors().size(), view.slot_count())

## Der Zielwürfel gehört scene_root: das Fenster meldet nur, WO seine Bühne liegt.
func test_the_window_reports_the_stage_and_the_net() -> void:
	await wait_frames(2)
	assert_true(view.bench_open(), "die Ziel-Säule ist Möbel, kein Ablauf")
	assert_gt(view.target_net_center().x, 0.0, "das Netz meldet seine Mitte")
	assert_lt(view.target_projector_y(), view.target_net_center().y,
		"und die Bühne liegt darüber")

# --- Der Zeiger hebt den Beitrag EINER Karte hervor --------------------------------

func test_hovering_a_card_highlights_its_cells() -> void:
	var pack := _valued_pack(4, 2)
	view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	assert_true(view._net.highlight.is_empty(), "ohne Zeiger leuchtet alles gleich")
	view.chip_hint_at(view._slot_buttons[0].get_global_rect().get_center())
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

# --- EINSETZEN, Zurückwerfen, Umlegen: der Platz steht, die Karte FÄHRT -------------

## Abbilder zurückgeworfener Karten, die gerade in ihren Schlitz sinken.
func _sink_ghosts() -> int:
	var count := 0
	for child in view.get_children():
		if String(child.name).begins_with("SlotCard"):
			count += 1
	return count

## Die Kassette steigt aus ihrem Leseschlitz ins Bild - sie beginnt UNTER ihrem
## Platz, und geschnitten wird dabei am Platz, nicht an der Karte.
func test_a_slotted_card_rises_out_of_its_slit() -> void:
	var uids := _stock(1)
	await wait_frames(2)
	view.slot_pack(uids[0])
	await wait_frames(1)
	var seat: Control = view._card_panels[0]
	var face: Control = seat.get_child(0)
	assert_true(seat.clip_contents, "sie steigt aus dem Schlitz, also wird geschnitten")
	assert_gt(face.position.y, 0.0, "und beginnt unter ihrem Platz")
	await wait_seconds(WorkshopView.CARD_RISE_TIME + 0.15)
	assert_almost_eq(face.position.y, 0.0, 0.5, "danach steht sie auf ihrem Platz")

## Zurückgeworfen SINKT sie denselben Weg: ein Abbild fährt in den Schlitz zurück
## und räumt sich selbst weg.
func test_a_returned_card_sinks_back_and_cleans_itself_up() -> void:
	var uids := _stock(1)
	view.slot_pack(uids[0])
	await wait_frames(2)
	var ghosts := _sink_ghosts()
	view.clear_press_slot(0)
	await wait_frames(1)
	assert_eq(_sink_ghosts(), ghosts + 1, "ein Abbild fährt zurück")
	await wait_seconds(WorkshopView.CARD_SINK_TIME + 0.25)
	assert_eq(_sink_ghosts(), ghosts, "und ist danach von selbst fort")

## Umlegen GLEITET seitlich: die Karte kommt von ihrem alten Platz her. Der Weg
## wird GERECHNET, nicht gemessen - beim Umlegen ist das Blech noch nicht gelegt.
func test_reordering_glides_sideways() -> void:
	run.hub_level = 10
	view.refresh()
	var uids := _stock(2)
	view.slot_pack(uids[0])
	view.slot_pack(uids[1])
	await wait_frames(2)
	view.move_slot(1, 0)
	await wait_frames(1)
	var seat: Control = view._card_panels[0]
	var face: Control = seat.get_child(0)
	assert_gt(absf(face.position.x), 0.0, "sie kommt von ihrem alten Platz her")
	assert_false(seat.clip_contents, "seitlich wird nicht geschnitten")
	await wait_seconds(WorkshopView.CARD_SLIDE_TIME + 0.15)
	assert_almost_eq(face.position.x, 0.0, 0.5, "und steht danach auf ihrem Platz")
