extends GutTest
## Feste Plätze auf der Werkbank-Grundseite: nichts darf sich je verschieben.
## Die Stabilität IST die Prüfung - gemessen werden die globalen Rechtecke der
## fünf Regal-Buchten und der sechs Leseschlitze, danach wird die Bank benutzt
## (Paket einlegen, Sorte leerlaufen lassen, in eine leere Bucht liefern) und
## jedes Rechteck muss auf denselben Pixeln liegen wie vorher.

var view: WorkshopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = WorkshopView.new()
	# Dasselbe Seitenverhältnis wie die echte Werkbank - GELÖST, nicht gesetzt:
	# die Breite ist die, bei der die Dossier-Seite bündig aufgeht.
	view.size = Vector2(roundf(540.0 * WorkshopView.dossier_aspect()), 540)
	add_child_autofree(view)
	view.run = run

func _segment_rects() -> Dictionary:
	var rects := {}
	for category: String in PackShelfView.SHELF_ORDER:
		var seat := view._shelf.segment_of(category)
		rects[category] = seat.get_global_rect() if seat != null else Rect2()
	return rects

func _slit_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for slit in view._press_slit_panels:
		rects.append(slit.get_global_rect())
	return rects

func _seat_rect() -> Rect2:
	var seat: Control = view.get_node("PressBand/ActionSeat")
	return seat.get_global_rect()

func _console() -> Control:
	return view.get_node("PressBand/PressConsole")

## Die Schürzen-Linie, die scene_root am Tisch hereinschiebt: genau die Kette aus
## apron_units. Ein geratenes Maß ließe die Buchten auf ihre Mindesthöhe fallen.
func _apron_line() -> float:
	return view.size.y + view.size.x / 100.0 * view.apron_units()

func _row_names() -> Array[String]:
	var names: Array[String] = []
	for child in view._content.get_children():
		names.append(String(child.name))
	return names

func _assert_same_segments(before: Dictionary, after: Dictionary, what: String) -> void:
	for category: String in PackShelfView.SHELF_ORDER:
		assert_eq(after[category], before[category], "%s: %s steht unverrückt" % [what, category])

func _assert_same_slits(before: Array[Rect2], after: Array[Rect2], what: String) -> void:
	assert_eq(after.size(), before.size(), "%s: dieselbe Zahl Schlitze" % what)
	for i in before.size():
		assert_eq(after[i], before[i], "%s: Schlitz %d steht unverrückt" % [what, i])

# --- (a) Ein Paket einlegen: nur die Sichtbarkeit des Knopfes ändert sich ---------

func test_slotting_a_pack_moves_nothing_on_the_page() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	var segments := _segment_rects()
	var slits := _slit_rects()
	var rows := _row_names()
	var seat := _seat_rect()
	assert_false(view._press_button.visible, "vorher zeigt sich kein Knopf")

	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	await wait_frames(2)
	assert_true(view._press_button.visible, "der Knopf ist da")
	assert_eq(_seat_rect(), seat, "sein Sitz war schon vorher genau so hoch")
	assert_eq(_row_names(), rows, "dieselben Zeilen in derselben Ordnung")
	_assert_same_segments(segments, _segment_rects(), "eingelegt")
	_assert_same_slits(slits, _slit_rects(), "eingelegt")

func test_taking_the_pack_back_out_moves_nothing_either() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	await wait_frames(2)
	var segments := _segment_rects()
	var slits := _slit_rects()

	view.clear_press_slot(0)
	await wait_frames(2)
	assert_false(view._press_button.visible, "ohne Paket geht er wieder")
	_assert_same_segments(segments, _segment_rects(), "zurückgenommen")
	_assert_same_slits(slits, _slit_rects(), "zurückgenommen")

# --- (b) Eine Sorte läuft leer: ihre Bucht bleibt stehen --------------------------

func test_an_exhausted_sort_keeps_its_bay() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.material_pack())
	await wait_frames(2)
	var segments := _segment_rects()
	var slits := _slit_rects()
	assert_true(view._shelf.bay_stocked(Engraving.CATEGORY_NUMBER))

	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)  # das letzte Zahlen-Paket verlässt den Stapel
	await wait_frames(2)
	assert_eq(view.sealed_pack_count(Engraving.CATEGORY_NUMBER), 0, "die Sorte ist leer")
	_assert_same_segments(segments, _segment_rects(), "leergelaufen")
	_assert_same_slits(slits, _slit_rects(), "leergelaufen")

	assert_false(view._shelf.bay_stocked(Engraving.CATEGORY_NUMBER))
	assert_not_null(view._shelf.segment_of(Engraving.CATEGORY_NUMBER), "die Bucht steht weiter")
	var chip := view._shelf.stack_button(Engraving.CATEGORY_NUMBER)
	assert_true(chip.disabled, "aber sie fängt nichts mehr")
	assert_eq(String(chip.get_meta("title", "")),
		PackShelfView.bay_name(Engraving.CATEGORY_NUMBER), "sie nennt weiter ihre Sorte")
	assert_eq(view._shelf.segment_of(Engraving.CATEGORY_NUMBER).modulate,
		PackShelfView.BAY_REST, "und ihre Schale steht offen wie zuvor")
	assert_true(view._shelf.bay_stocked(Engraving.CATEGORY_MATERIAL),
		"die Nachbarin führt weiter Ware und rückt nicht auf")

# --- (c) Lieferung in eine leere Bucht: sie ploppt an ihren festen Platz ----------

func test_a_delivery_into_an_empty_sort_lands_on_the_standing_anchor() -> void:
	# Der Anker existiert, BEVOR die Ware kommt - genau das macht den Einschlag
	# ruhig: scene_root stellt den Körper auf denselben Punkt, den die leere Bucht
	# schon die ganze Zeit gemeldet hat.
	assert_false(view._shelf.bay_stocked(Engraving.CATEGORY_DICE), "Runen führt niemand")
	run.grant_pack(Pack.dice_mod_pack())
	view.expect_pack_delivery(Engraving.CATEGORY_DICE)  # unterwegs: der Stapel wächst erst bei Ankunft
	await wait_frames(2)
	var segments := _segment_rects()
	var slits := _slit_rects()
	var anchor := view.stack_anchor_px(Engraving.CATEGORY_DICE)
	assert_false(view._shelf.bay_stocked(Engraving.CATEGORY_DICE), "noch ist sie leer")

	view.deliver_pack(Engraving.CATEGORY_DICE)
	await wait_frames(2)
	assert_true(view._shelf.bay_stocked(Engraving.CATEGORY_DICE), "die Ware liegt da")
	_assert_same_segments(segments, _segment_rects(), "geliefert")
	_assert_same_slits(slits, _slit_rects(), "geliefert")
	assert_eq(view.stack_anchor_px(Engraving.CATEGORY_DICE), anchor,
		"und zwar auf demselben Anker wie vor der Lieferung")
	var found := false
	for entry in view.shelf_entries():
		if String(entry.get("category", "")) == Engraving.CATEGORY_DICE:
			found = true
	assert_true(found, "erst jetzt meldet die Sorte einen Stapel - vorher gab es keinen Körper")

# --- (d) Die Schürze: Konsole unter der Kante, Buchten darunter --------------------

## Das Konsolen-Band hängt GANZ unter dem Fenster, zwischen zwei gleichen Nähten:
## Fensterkante - Naht - Band - Naht - Buchten.
func test_the_console_hangs_below_the_window_between_two_equal_seams() -> void:
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	var console := _console().get_global_rect()
	var window := view.get_global_rect()
	var u := view.size.x / 100.0
	assert_gt(console.position.y, window.end.y, "es steht vollständig außerhalb")
	assert_almost_eq(console.position.y - window.end.y, u * WorkshopView.CONSOLE_SHELF_GAP,
		1.0, "eine Naht unter der Fensterkante")
	assert_almost_eq(view._shelf.get_global_rect().position.y - console.end.y,
		console.position.y - window.end.y, 1.0, "und genau dieselbe Naht zu den Buchten")
	assert_almost_eq(console.get_center().x, window.get_center().x, 1.0,
		"waagerecht steht es weiter mittig")

## Das Fensterinnere gehört dem Inhalt: nichts hängt mehr herein, der Zeilenfluss
## endet erst an der Fensterkante (bis auf seinen eigenen Rand).
func test_the_window_content_uses_the_full_interior() -> void:
	await wait_frames(2)
	var u := view.size.x / 100.0
	assert_almost_eq(view._content.get_global_rect().end.y,
		view.get_global_rect().end.y - u * WorkshopView.CONTENT_MARGIN_Y, 1.0,
		"der Zeilenfluss endet an der Fensterkante")
	assert_lt(view._content.get_global_rect().end.y,
		_console().get_global_rect().position.y, "und nie unter dem Band")

## Die Kette, aus der scene_root die Fensterhöhe auflöst: Naht, ganzes Band,
## Naht, Bucht-Streifen. Weicht sie ab, enden die Buchten nicht auf der Hub-Linie.
func test_the_apron_chain_is_seam_band_seam_bays() -> void:
	assert_almost_eq(view.apron_units(),
		WorkshopView.CONSOLE_SHELF_GAP * 2.0 + view.console_size(1.0).y
			+ WorkshopView.SHELF_STRIP_UNITS, 0.001, "die Schürze in Einheiten")
	var u := view.size.x / 100.0
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	assert_almost_eq(view.shelf_top() - view.size.y,
		u * WorkshopView.CONSOLE_SHELF_GAP * 2.0 + view.console_size(u).y, 1.0,
		"und dieselbe Kette misst sich am Fenster nach")

## Die Buchten liegen GANZ außerhalb, über die volle Fensterbreite, und enden auf
## der gemeldeten Schürzen-Linie (am Tisch: der Unterkante des Hubs).
func test_the_bays_lie_below_the_window_at_full_width() -> void:
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	var row := view._shelf.get_global_rect()
	var window := view.get_global_rect()
	assert_gt(row.position.y, window.end.y, "die Buchten liegen unter dem Fenster")
	assert_almost_eq(row.end.y, window.position.y + view.apron_bottom, 1.0,
		"und enden genau auf der gemeldeten Linie")
	assert_lte(window.size.x - row.size.x, PackShelfView.SHELF_ORDER.size(),
		"sie nehmen die volle Fensterbreite (bis auf die Pixel-Abrundung)")
	assert_almost_eq(row.get_center().x, window.get_center().x, 1.0, "und stehen mittig")
	for category: String in PackShelfView.SHELF_ORDER:
		assert_almost_eq(view._shelf.segment_of(category).size.y, row.size.y, 1.0,
			"%s füllt den Streifen" % category)

## Der Abstand zur Konsole ist gesetzt, die HÖHE der Buchten folgt daraus.
func test_the_bay_height_falls_out_of_the_gap_below_the_console() -> void:
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	var u := view.size.x / 100.0
	var gap := view._shelf.get_global_rect().position.y - _console().get_global_rect().end.y
	assert_almost_eq(gap, u * WorkshopView.CONSOLE_SHELF_GAP, 1.0, "eine Naht unter dem Blech")
	assert_almost_eq(view._shelf.get_global_rect().size.y,
		view.apron_bottom - view.shelf_top(), 1.0, "der Rest ist Buchthöhe")

## Fenster PLUS Schürze - daran messen sich Klick-Weiterleitung und Kamera.
func test_the_bench_rect_covers_window_and_apron() -> void:
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	var bench := view.bench_rect()
	assert_true(bench.encloses(view.get_global_rect()), "das Fenster liegt darin")
	assert_true(bench.encloses(_console().get_global_rect()), "das Blech ebenso")
	assert_almost_eq(view._shelf.get_global_rect().end.y, bench.end.y, 1.0,
		"und die Buchten enden genau auf seiner Unterkante")

## Gemessen und gerechnet sind derselbe Punkt: solange die Leiste steht, misst der
## Anker am Knopf, sonst folgt er aus dem Streifen. Weichen die beiden ab, springt
## ein Liefer-Komet in dem Moment, in dem das Regal zurückkommt.
func test_the_derived_stack_anchor_matches_the_measured_one() -> void:
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	for category: String in PackShelfView.SHELF_ORDER:
		var measured := view._shelf.stack_anchor_px(category)
		var derived := PackShelfView.stack_anchor_in(view.shelf_rect_global(), category,
			view.shelf_cell_px())
		# Auf Pixelrundung genau: der Kasten verteilt in ganzen Pixeln, die Formel
		# rechnet in Brüchen - alles darüber wäre ein sichtbarer Sprung.
		assert_almost_eq(derived.x, measured.x, 1.5, "%s: dieselbe Spalte" % category)
		assert_almost_eq(derived.y, measured.y, 1.5, "%s: dieselbe Höhe" % category)

## Sitz und Hinweiskarte reisen MIT dem Band: er in seiner rechten Flanke, sie in
## seiner linken, beide auf seiner Mittellinie.
func test_seat_and_card_ride_the_console_band() -> void:
	await wait_frames(2)
	view.show_hover_info("Meißel", "Kopiert einen Seitenwert auf eine andere Seite.")
	await wait_frames(2)
	var console := _console().get_global_rect()
	assert_gt(_seat_rect().position.x, console.end.x, "der Sitz steht in der rechten Flanke")
	assert_almost_eq(_seat_rect().get_center().y, console.get_center().y, 1.0,
		"auf der Mittellinie des Bandes")
	var screen := view._info_screen.get_global_rect()
	assert_lt(screen.end.x, console.position.x, "der Schirm steht links vom Blech")
	assert_almost_eq(screen.get_center().y, console.get_center().y, screen.size.y * 0.5,
		"und er steht auf dem Band")
	assert_lte(screen.end.y, view._shelf.get_global_rect().position.y + 1.0,
		"unter die Buchten taucht er nie - dort liegen die Kassetten davor")

func test_the_growth_comes_out_of_the_slack_not_out_of_the_nets() -> void:
	# Erst die Restluft, dann erst (und hier gar nicht) der Netz-Deckel.
	var u := view.size.x / 100.0
	var dice: Array[DieDefinition] = []
	for i in 6:
		dice.append(run.owned_pool[i])
	run.clamped_dice = dice
	run.clamped_changed.emit()
	await wait_frames(2)
	assert_gt(view._content.get_node("BenchSlack").size.y, 0.0,
		"auch bei sechs Zwingen bleibt Luft über der Konsole")
	assert_gt(view.clamp_cell(u), 0.0)
	assert_lte(view.clamp_cell(u), u * WorkshopView.CLAMP_CELL_MAX,
		"der Netz-Deckel steht unverändert")

func test_the_shelf_cells_grow_with_their_bays() -> void:
	await wait_frames(2)
	assert_gt(view.shelf_cell_scale(), 1.0, "in der Bucht wächst die Kassette")
	assert_lte(view.shelf_cell_scale(), PackShelfView.SHELF_SCALE_MAX)
	assert_almost_eq(view.shelf_cell_scale(), view._shelf.cell_scale(), 0.001,
		"eine Quelle, auch wenn die Leiste gerade nicht steht")

# --- (e) Der Wurf läuft IN der Seite: auch er verrückt nichts --------------------

func test_the_whole_press_cycle_never_reflows_the_page() -> void:
	# Weder Pressung noch Platzierung haben eine eigene Seite - die eine läuft in
	# den Anzeigefeldern, und ihre Beute LIEGT als Haufen über dem Zeilenfluss.
	# Also stehen Buchten, Schlitze, Zeilen und der Sitz durch den ganzen Kreis auf
	# denselben Pixeln: vorher, mit liegender Beute und nach dem Fertig.
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	await wait_frames(2)
	var segments := _segment_rects()
	var slits := _slit_rects()
	var rows := _row_names()
	var seat := _seat_rect()
	var displays := view.press_display_anchors()
	var strip := view.ablage_rect()

	view.start_press()
	await wait_frames(2)
	assert_true(view.placing(), "die Beute liegt in der Ablage")
	assert_eq(_row_names(), rows, "dieselben Zeilen in derselben Ordnung")
	assert_eq(_seat_rect(), seat, "derselbe Sitz, jetzt mit dem Fertig")
	assert_null(view._press_button, "der Pressen-Knopf tritt ab")
	assert_not_null(view._apply_button)
	assert_eq(view._apply_button.get_global_rect(), seat, "und der Knopf füllt ihn genau")
	_assert_same_segments(segments, _segment_rects(), "mit Beute")
	_assert_same_slits(slits, _slit_rects(), "mit Beute")
	assert_eq(view.press_display_anchors(), displays, "und die Leser stehen still")
	assert_eq(view.ablage_rect(), strip, "der Streifen hängt am Fenster, nicht am Inhalt")
	assert_not_null(view._ablage_host, "der Haufen liegt da")

	view.apply_placements()  # das Fertig führt zurück auf die Grundseite
	await wait_frames(2)
	assert_false(view.placing())
	assert_eq(_row_names(), rows, "und nach dem Kreis steht wieder dieselbe Seite")
	assert_eq(_seat_rect(), seat)
	_assert_same_segments(segments, _segment_rects(), "danach")
	_assert_same_slits(slits, _slit_rects(), "danach")
	assert_eq(view.press_display_anchors(), displays)
	assert_eq(view.ablage_rect(), strip, "auch der leere Streifen steht, wo er stand")

## Der Haufen ist ein AUFLIEGER: ob er leer ist oder dreißig Chips trägt, ändert
## keinen Pixel der Grundseite.
func test_a_full_pile_moves_nothing_on_the_page() -> void:
	await wait_frames(2)
	var segments := _segment_rects()
	var slits := _slit_rects()
	var rows := _row_names()
	var seat := _seat_rect()
	var nets: Array[Rect2] = []
	for net in view._clamp_nets:
		nets.append(net.get_global_rect())

	for i in 30:
		run.press_piece_serial += 1
		run.press_pieces.append({"sort": Engraving.CATEGORY_NUMBER, "id": Engraving.NOTCH,
			"stufe": 1, "applications": 1, "piece_uid": run.press_piece_serial})
	run.press_changed.emit()
	await wait_frames(2)
	assert_eq(view._ablage_chips.size(), 30, "dreißig Chips liegen da")
	assert_eq(_row_names(), rows, "dieselben Zeilen")
	assert_eq(_seat_rect(), seat)
	_assert_same_segments(segments, _segment_rects(), "voller Haufen")
	_assert_same_slits(slits, _slit_rects(), "voller Haufen")
	for i in nets.size():
		assert_eq(view._clamp_nets[i].get_global_rect(), nets[i], "Netz %d steht unverrückt" % i)
	var strip := view.ablage_rect()
	for uid in view._ablage_chips:
		assert_true(strip.has_point(view.ablage_spot(int(uid))),
			"und jeder Chip bleibt im Streifen")

func test_the_console_stays_clear_of_the_shelf() -> void:
	# Der gewachsene Leser darf die Buchten nicht anschneiden - die Restluft über
	# der Konsole ist die Reserve, und sie bleibt positiv.
	var u := view.size.x / 100.0
	var console := _console()
	await wait_frames(2)
	assert_gt(view._shelf.get_global_rect().position.y, console.get_global_rect().end.y,
		"die Konsole endet über dem Regal")
	assert_gt(view._content.get_node("BenchSlack").size.y, 0.0, "und darüber bleibt Luft")
	assert_gt(view.socket_size(u).y, u * WorkshopView.SLIT_DISPLAY,
		"ein Platz trägt sein Feld UND seinen Schlitz")

func test_the_bays_never_reflow_however_the_stock_stands() -> void:
	# Der Beweis in einem Bild: derselbe Satz Rechtecke bei leerem, gemischtem und
	# vollem Regal.
	await wait_frames(2)
	var empty := _segment_rects()
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.dice_mod_pack())
	await wait_frames(2)
	_assert_same_segments(empty, _segment_rects(), "gemischt")
	run.grant_pack(Pack.material_pack())
	run.grant_pack(Pack.dice_pack(DiceOffer.TEMPLATES[0]))
	run.grant_pack(Pack.fixed_engraving_pack(Engraving.pointer_engraving()))
	await wait_frames(2)
	_assert_same_segments(empty, _segment_rects(), "voll")

# --- (f) Auch ein Würfel-Paket nimmt der Schürze nichts weg ------------------------

func test_the_apron_stands_through_the_whole_dice_pack_flow() -> void:
	# Die Schürze gehört der Bank, nicht einem Ablauf: Buchten, Schlitze und Blech
	# stehen auf denselben Pixeln, während ein Würfel-Paket das Fenster füllt -
	# nur anfassen lässt sich dann nichts.
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.dice_pack(DiceOffer.TEMPLATES[4]))  # 3 Würfel = echte Wahl
	await wait_frames(2)
	var segments := _segment_rects()
	var slits := _slit_rects()
	var console := _console().get_global_rect()
	var seat := _seat_rect()
	assert_false(view.shelf_locked(), "vorher steht die Bank offen")

	assert_true(view.open_top_dice_pack(), "das Würfel-Paket geht auf")
	await wait_frames(2)
	assert_eq(view._phase, WorkshopView.Phase.CHOOSE_DIE)
	_assert_same_segments(segments, _segment_rects(), "in der Wahl")
	_assert_same_slits(slits, _slit_rects(), "in der Wahl")
	assert_eq(_console().get_global_rect(), console, "und das Blech steht still")
	assert_eq(_seat_rect(), seat, "der Sitz ebenso")
	assert_true(view.shelf_locked(), "aber die Buchten sind zu")
	assert_false(view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER),
		"kein Paket in eine laufende Wahl")
	assert_false(view.open_top_dice_pack(), "und kein zweites Siegel nebenher")

	view._materialized.fill(true)  # die Zeremonie hätte sie längst aufgestellt
	view.choose_die(0)
	await wait_frames(2)
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE)
	_assert_same_segments(segments, _segment_rects(), "beim Einsetzen")
	_assert_same_slits(slits, _slit_rects(), "beim Einsetzen")
	assert_eq(_console().get_global_rect(), console)
	assert_eq(_seat_rect(), seat)

	view._phase = WorkshopView.Phase.UNSEAL  # der eine Zustand ohne Zeilenfluss
	view.refresh()
	await wait_frames(2)
	assert_null(view._content, "das Fensterinnere gehört dem Siegel")
	_assert_same_segments(segments, _segment_rects(), "beim Entsiegeln")
	_assert_same_slits(slits, _slit_rects(), "beim Entsiegeln")
	assert_eq(_console().get_global_rect(), console)

	view.finish_ceremony()
	await wait_frames(2)
	_assert_same_segments(segments, _segment_rects(), "danach")
	_assert_same_slits(slits, _slit_rects(), "danach")
	assert_eq(_console().get_global_rect(), console)
	assert_false(view.shelf_locked(), "und die Bank steht wieder offen")

# --- (e) Von weitem ist die Bank leer ---------------------------------------------
# Die Würfel der Runde treten erst auf, wenn der Spieler heranfährt. Die SCHÜRZE
# gehört dem Tisch, nicht dem Blick: sie steht in beiden Zuständen auf demselben
# Pixel - sonst wanderten Konsole und Buchten bei jedem Zoom.

func test_without_the_zoom_the_window_stands_empty() -> void:
	await wait_frames(2)
	assert_false(view._clamp_nets.is_empty(), "an der Bank steht die Netzzeile")
	view.bench_focused = false
	await wait_frames(2)
	assert_true(view._clamp_nets.is_empty(), "von weitem ist das Fenster leer")
	assert_true(view._clamp_stage_hosts.is_empty(), "und keine Bühne trägt einen Würfel")
	assert_false(view.clamps_on_bench(),
		"also steht die Aufspannung auch nicht - ihre Würfel liegen im Tray")

func test_the_apron_never_moves_with_the_zoom() -> void:
	await wait_frames(2)
	var segments := _segment_rects()
	var slits := _slit_rects()
	var seat := _seat_rect()
	view.bench_focused = false
	await wait_frames(2)
	_assert_same_segments(segments, _segment_rects(), "ohne Zoom")
	_assert_same_slits(slits, _slit_rects(), "ohne Zoom")
	assert_eq(_seat_rect(), seat, "und der Handlungs-Sitz steht, wo er stand")
	view.bench_focused = true
	await wait_frames(2)
	_assert_same_segments(segments, _segment_rects(), "zurück an der Bank")
	_assert_same_slits(slits, _slit_rects(), "zurück an der Bank")
	assert_eq(_seat_rect(), seat)

func test_a_dossier_shows_itself_only_at_the_bench() -> void:
	# Die Seite bleibt aufgeschlagen - sie zeigt sich nur nicht. Und ohne gezeigten
	# Würfel liegt auch er wieder in seinem Sitz (inspected_die ist die Auskunft,
	# an der scene_root Bühne und Tray-Lücke hängt).
	var die := run.owned_pool[3]
	assert_true(view.open_inspect(die))
	await wait_frames(2)
	assert_eq(view.inspected_die(), die)
	view.bench_focused = false
	await wait_frames(2)
	assert_true(view.inspecting(), "die Seite ist weiter aufgeschlagen")
	assert_null(view.inspected_die(), "aber nichts von ihr steht auf der Bank")
	view.bench_focused = true
	await wait_frames(2)
	assert_eq(view.inspected_die(), die, "an der Bank steht sie wieder da")
