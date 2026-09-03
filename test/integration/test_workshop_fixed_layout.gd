extends GutTest
## Feste Plätze auf der Werkbank-Grundseite: nichts darf sich je verschieben.
## Die Stabilität IST die Prüfung - gemessen werden das Magazin-Fach, die
## Serien-Slots und der Handlungs-Sitz, danach wird die Bank benutzt (Karte
## stecken, Fach leerlaufen lassen, in ein leeres Fach liefern) und jedes
## Rechteck muss auf denselben Pixeln liegen wie vorher. Die Plätze IN dem Fach
## dürfen sich dabei ändern - die Reihe schließt sich hinter einer entnommenen
## Kassette, das ist Magazin-Ordnung, kein Reflow der Seite.

var view: WorkshopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = WorkshopView.new()
	# Dasselbe Seitenverhältnis wie die echte Werkbank - GELÖST, nicht gesetzt:
	# die Breite folgt aus der Höhe der zentrierten Ziel-Säule.
	view.size = Vector2(roundf(540.0 * WorkshopView.bench_aspect()), 540)
	add_child_autofree(view)
	view.run = run

func _drawer_rect() -> Rect2:
	return view._drawer.get_global_rect() if view._drawer != null else Rect2()

func _slit_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for slit in view._slit_panels:
		rects.append(slit.get_global_rect())
	return rects

func _seat_rect() -> Rect2:
	var seat: Control = view.get_node("SeriesBand/ActionSeat")
	return seat.get_global_rect()

func _console() -> Control:
	return view.get_node("Street/SeriesConsole")

## Die Schürzen-Linie, die scene_root am Tisch hereinschiebt: genau die Kette aus
## apron_units. Ein geratenes Maß ließe das Fach auf seine Mindesthöhe fallen.
func _apron_line() -> float:
	return view.size.y + view.size.x / 100.0 * view.apron_units()

func _row_names() -> Array[String]:
	var names: Array[String] = []
	for child in view._content.get_children():
		names.append(String(child.name))
	return names

func _assert_same_slits(before: Array[Rect2], after: Array[Rect2], what: String) -> void:
	assert_eq(after.size(), before.size(), "%s: dieselbe Zahl Slots" % what)
	for i in before.size():
		assert_eq(after[i], before[i], "%s: Slot %d steht unverrückt" % [what, i])

# --- (a) Eine Karte stecken: nur der Inhalt des Fachs ändert sich ------------------

func test_slotting_a_card_moves_nothing_on_the_page() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	var fach := _drawer_rect()
	var slits := _slit_rects()
	var rows := _row_names()
	var seat := _seat_rect()
	assert_false(view._action_button.visible, "vorher zeigt sich kein Knopf")

	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_true(view._action_button.visible, "der Knopf ist da")
	assert_eq(_seat_rect(), seat, "sein Sitz war schon vorher genau so hoch")
	assert_eq(_row_names(), rows, "dieselben Zeilen in derselben Ordnung")
	assert_eq(_drawer_rect(), fach, "das Fach steht unverrückt")
	_assert_same_slits(slits, _slit_rects(), "gesteckt")

func test_taking_the_card_back_out_moves_nothing_either() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	var fach := _drawer_rect()
	var slits := _slit_rects()

	view.clear_press_slot(0)
	await wait_frames(2)
	assert_false(view._action_button.visible, "ohne Karte geht er wieder")
	assert_eq(_drawer_rect(), fach, "zurückgenommen: das Fach steht")
	_assert_same_slits(slits, _slit_rects(), "zurückgenommen")

# --- (b) Das Fach läuft leer: es bleibt stehen -------------------------------------

func test_an_emptied_magazine_keeps_its_drawer() -> void:
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	var fach := _drawer_rect()
	var slits := _slit_rects()

	view.slot_pack(run.owned_packs[0].pack_uid)  # die letzte Karte verlässt das Fach
	await wait_frames(2)
	assert_true(view.drawer_entries().is_empty(), "das Magazin ist leer")
	assert_eq(_drawer_rect(), fach, "leergelaufen: das Fach steht weiter")
	_assert_same_slits(slits, _slit_rects(), "leergelaufen")
	var hint := view._drawer.hint_at(_drawer_rect().get_center())
	assert_eq(String(hint.get("title", "")), PackDrawerView.EMPTY_TITLE,
		"und es nennt sich weiter selbst")

# --- (c) Lieferung ins leere Fach: sie landet auf dem stehenden Anker --------------

func test_a_delivery_lands_on_the_standing_anchor() -> void:
	# Der Anker existiert, BEVOR die Ware ankommt - genau das macht den Einschlag
	# ruhig: scene_root stellt den Körper auf denselben Punkt, den der zurück-
	# gehaltene Platz schon die ganze Zeit gemeldet hat.
	run.grant_pack(Pack.dice_mod_pack())
	var uid := run.owned_packs[0].pack_uid
	view.expect_pack_delivery(uid)  # unterwegs: der Chip erscheint erst bei Ankunft
	await wait_frames(2)
	var fach := _drawer_rect()
	var anchor := view.pack_anchor_px(uid)
	assert_null(view._drawer.pack_button(uid), "noch liegt kein Chip da")

	view.deliver_pack(uid)
	await wait_frames(2)
	assert_not_null(view._drawer.pack_button(uid), "die Ware liegt da")
	assert_eq(_drawer_rect(), fach, "geliefert: das Fach steht")
	assert_eq(view.pack_anchor_px(uid), anchor,
		"und zwar auf demselben Anker wie vor der Lieferung")

# --- (d) Die Schürze: Band unter der Kante, das Fach darunter ---------------------

## Das Konsolen-Band hängt GANZ unter dem Fenster, zwischen zwei gleichen Nähten:
## Fensterkante - Naht - Band - Naht - Fach. Die SCHACHT-REIHE steht seit der
## Bühnen-Straße IM Fenster, nicht mehr in diesem Band.
func test_the_band_hangs_below_the_window_between_two_equal_seams() -> void:
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	var band := view.console_band_rect()
	band.position += view.get_global_rect().position
	var window := view.get_global_rect()
	var u := view.size.x / 100.0
	assert_gt(band.position.y, window.end.y, "es steht vollständig außerhalb")
	assert_almost_eq(band.position.y - window.end.y, u * WorkshopView.CONSOLE_SHELF_GAP,
		1.0, "eine Naht unter der Fensterkante")
	assert_almost_eq(_drawer_rect().position.y - band.end.y,
		band.position.y - window.end.y, 1.0, "und genau dieselbe Naht zum Fach")
	assert_true(window.encloses(_console().get_global_rect()),
		"die Schacht-Reihe steht IM Fenster")

## Das Fensterinnere gehört der STRASSE: nichts hängt mehr herein, sie endet erst
## an der Fensterkante (bis auf ihren eigenen Rand). Der TRÄGER deckt seit der
## Welle J das ganze Fenster - die Ränder stecken in street_rect, sonst drifteten
## gemeldete und gestellte Plätze um einen Rand auseinander.
func test_the_window_content_uses_the_full_interior() -> void:
	await wait_frames(2)
	var u := view.size.x / 100.0
	assert_eq(view._content.get_global_rect(), view.get_global_rect(),
		"der Träger deckt das ganze Fenster")
	assert_almost_eq(view.street_rect().end.y, view.size.y - u * WorkshopView.CONTENT_MARGIN_Y,
		1.0, "die Straße endet einen Rand über der Fensterkante")
	# Und der GESTELLTE Platz ist der GEMELDETE: die Konsole liegt auf console_rect.
	var console := _console().get_global_rect()
	console.position -= view.get_global_rect().position
	assert_almost_eq(console.position.x, view.console_rect(u).position.x, 0.5,
		"die Konsole steht, wo das Fenster sie meldet")
	assert_almost_eq(console.position.y, view.console_rect(u).position.y, 0.5)

## Die Kette, aus der scene_root die Fensterhöhe auflöst: Naht, ganzes Band,
## Naht, Fach-Streifen. Sie ist seit der Bühnen-Straße eine reine KONSTANTE - kein
## Weltmaß mehr darin, denn die Kassetten stehen im Fenster.
func test_the_apron_chain_is_seam_band_seam_bays() -> void:
	assert_almost_eq(view.apron_units(),
		WorkshopView.CONSOLE_SHELF_GAP * 2.0 + WorkshopView.BAND_HEIGHT_UNITS
			+ WorkshopView.SHELF_STRIP_UNITS, 0.001, "die Schürze in Einheiten")
	var u := view.size.x / 100.0
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	assert_almost_eq(view.shelf_top() - view.size.y,
		u * (WorkshopView.CONSOLE_SHELF_GAP * 2.0 + WorkshopView.BAND_HEIGHT_UNITS),
		1.0, "und dieselbe Kette misst sich am Fenster nach")

## Das Fach liegt GANZ außerhalb, über die volle Fensterbreite, und endet auf
## der gemeldeten Schürzen-Linie (am Tisch: der Unterkante des Hubs).
func test_the_drawer_lies_below_the_window_at_full_width() -> void:
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	var row := _drawer_rect()
	var window := view.get_global_rect()
	assert_gt(row.position.y, window.end.y, "das Fach liegt unter dem Fenster")
	assert_almost_eq(row.end.y, window.position.y + view.apron_bottom, 1.0,
		"und endet genau auf der gemeldeten Linie")
	assert_lte(window.size.x - row.size.x, 2.0,
		"es nimmt die volle Fensterbreite (bis auf die Pixel-Abrundung)")
	assert_almost_eq(row.get_center().x, window.get_center().x, 1.0, "und steht mittig")

## OHNE gemeldete Linkskante bleibt das Magazin der reine Streifen.
func test_the_drawer_spans_only_the_strip_at_window_width() -> void:
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	var row := _drawer_rect()
	var window := view.get_global_rect()
	assert_almost_eq(row.end.x, window.end.x, 2.0,
		"das Fach bleibt bündig mit der rechten Fensterkante")
	assert_almost_eq(row.position.x, window.position.x, 2.0,
		"und beginnt an der LINKEN Fensterkante - kein Pool-Überhang mehr")
	assert_almost_eq(row.size.x, window.size.x, 2.0, "genau die Streifen-Breite")

## Der Abstand zur Konsole ist gesetzt, die HÖHE des Fachs folgt daraus.
func test_the_drawer_height_falls_out_of_the_gap_below_the_console() -> void:
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	var u := view.size.x / 100.0
	var band := view.console_band_rect()
	band.position += view.get_global_rect().position
	var gap := _drawer_rect().position.y - band.end.y
	assert_almost_eq(gap, u * WorkshopView.CONSOLE_SHELF_GAP, 1.0, "eine Naht unter dem Band")
	assert_almost_eq(_drawer_rect().size.y, view.apron_bottom - view.shelf_top(), 1.0,
		"der Rest ist Fachhöhe")

## Fenster PLUS Schürze - daran messen sich Klick-Weiterleitung und Kamera.
func test_the_bench_rect_covers_window_and_apron() -> void:
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	var bench := view.bench_rect()
	assert_true(bench.encloses(view.get_global_rect()), "das Fenster liegt darin")
	assert_true(bench.encloses(_seat_rect()), "der Handlungs-Sitz ebenso")
	# KORREKTUR-WELLE H: das ganze Magazin liegt WAAGERECHT in bench_rect (kein
	# Pool-Überhang mehr, der links herausragte) - so werden Klicks auf jede
	# Kassette weitergereicht.
	var drawer := _drawer_rect()
	assert_gte(drawer.position.x, bench.position.x - 1.0,
		"das Magazin beginnt nicht links von bench_rect")
	assert_lte(drawer.end.x, bench.end.x + 1.0,
		"und endet nicht rechts davon - jede Kassette ist tippbar")
	assert_almost_eq(drawer.end.y, bench.end.y, 1.0,
		"und das Fach endet genau auf seiner Unterkante")

## KORREKTUR-WELLE H, der eigentliche Fix: eine Magazin-Kassette wird über die
## ECHTE Klick-Weiterleitung gesteckt, nicht über slot_pack direkt. Der Prädikat
## der Weiterleitung ist TableScreen.window_takes_pixel(fenster, bench_rect, px):
## liegt die Kassette (wie früher unter dem Pool-Überhang) AUSSERHALB von
## bench_rect, kommt der Klick nie an und der Chip zündet nie.
func test_a_cassette_tap_reaches_the_slot_through_the_forward_region() -> void:
	for i in 6:
		run.grant_pack(Pack.number_pack())
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	var uid := run.owned_packs[0].pack_uid
	var chip := view._drawer.pack_button(uid)
	assert_not_null(chip, "die Kassette hat einen Chip-Knopf")
	var px := chip.get_global_rect().get_center()
	# Genau das Prädikat, mit dem scene_root entscheidet, ob der Klick ans Fenster
	# geht: Rechteck deckt den Pixel UND ein aktiver Knopf liegt darunter.
	assert_true(TableScreen.window_takes_pixel(view, view.bench_rect(), px, true, false),
		"der Klick auf die Kassette wird an das Fenster weitergereicht")
	# Und der so weitergereichte Chip-Tap steckt die Karte (pressed -> _on_pack_pressed).
	chip.pressed.emit()
	await wait_frames(2)
	assert_true(view.press_slot_uids().has(uid), "die Kassette steckt im nächsten Slot")

## Die GRUBE hängt am selben Streifen: sie ist er, abzüglich seiner gemalten
## Fassung. Sie muss durch jeden Ablauf byteweise stehen - das Loch im Glas und
## der Körper darunter werden aus ihr gestellt, ein Wandern wäre ein springendes
## Loch im Tisch.
func test_the_pit_hangs_on_the_standing_drawer_rect() -> void:
	view.apron_bottom = _apron_line()
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.material_pack())
	await wait_frames(2)
	var pit := view.shelf_pit_rect()
	assert_true(_drawer_rect().encloses(pit), "das Loch liegt IM Fach")
	assert_gt(pit.size.x, 0.0)
	assert_gt(pit.size.y, 0.0)
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_eq(view.shelf_pit_rect(), pit, "gesteckt: die Grube steht")
	view.clear_press_slot(0)
	await wait_frames(2)
	assert_eq(view.shelf_pit_rect(), pit, "zurückgenommen: die Grube steht")

## Gemessen und gerechnet sind derselbe Punkt: solange das Fach steht, misst der
## Anker am Chip, sonst folgt er aus dem Streifen. Weichen die beiden ab, springt
## ein Liefer-Komet in dem Moment, in dem das Fach zurückkommt.
func test_the_derived_pack_anchor_matches_the_measured_one() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.material_pack())
	run.grant_pack(Pack.dice_mod_pack())
	await wait_frames(2)
	for i in run.owned_packs.size():
		var uid := run.owned_packs[i].pack_uid
		var measured := view._drawer.pack_anchor_px(uid)
		var derived := PackDrawerView.anchor_in(view.shelf_pit_rect(), i,
			run.owned_packs.size(), view.shelf_cell_px())
		# Auf Pixelrundung genau - alles darüber wäre ein sichtbarer Sprung.
		assert_almost_eq(derived.x, measured.x, 1.5, "uid %d: dieselbe Spalte" % uid)
		assert_almost_eq(derived.y, measured.y, 1.5, "uid %d: dieselbe Höhe" % uid)

## Das BAND trägt nur noch den Handlungs-Sitz, und der steht MITTIG unter der
## Schacht-Reihe - die beiden kleinen Schirme sind gestorben.
func test_the_seat_rides_the_console_band_below_the_row() -> void:
	await wait_frames(2)
	var band := view.console_band_rect()
	band.position += view.get_global_rect().position
	var seat := _seat_rect()
	assert_almost_eq(seat.get_center().y, band.get_center().y, 1.0,
		"der Sitz sitzt auf der Mittellinie des Bandes")
	assert_almost_eq(seat.get_center().x,
		view.row_field_rect().get_center().x + view.get_global_rect().position.x, 1.0,
		"und mittig unter der Schacht-Reihe")
	assert_null(view.get_node_or_null("SeriesBand/InfoScreen"),
		"der Tooltip-Schirm ist mit der KORREKTUR-WELLE J aus dem Band ins Fenster")
	assert_null(view.get_node_or_null("SeriesBand/SeriesScreen"),
		"der Serien-Schirm bleibt gestorben")

## Der Streifen trägt KEINEN Schirm-Hintergrund mehr - er liegt auf dem Filz. Und
## seit der KORREKTUR-WELLE I fällt auch der eigene Hintergrund des SOLL-SCHIRMS:
## das Ergebnis-Netz steht auf blankem Filz, UI-gleich zur Info-Säule links.
func test_the_strip_has_no_window_background() -> void:
	await wait_frames(2)
	assert_true(view.get_theme_stylebox("panel") is StyleBoxEmpty,
		"das Fenster malt nichts")
	assert_true(view._diff_screen.get_theme_stylebox("panel") is StyleBoxEmpty,
		"der SOLL-SCHIRM steht auf blankem Filz")

## Der Sitz muss seine breiteste Aufschrift ungeschnitten tragen, sonst hätte
## clip_text sie nur versteckt.
func test_the_seat_still_carries_its_widest_label() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	var u := view.size.x / 100.0
	var button := view._action_button
	var font: Font = button.get_theme_font("font")
	var px: int = button.get_theme_font_size("font_size")
	var text := font.get_string_size("Griff 8/8", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	assert_lte(text + u * 1.2, _seat_rect().size.x,
		"die breiteste Aufschrift paßt samt Rand in den Sitz")

## Der SITZ rührt sich auch mit Katalysatoren keinen Byte weit.
func test_the_seat_rect_survives_a_catalyst() -> void:
	var seat := _seat_rect()
	run.grant_pack(Pack.catalyst(Pack.CATALYST_MATRIX))
	run.grant_pack(Pack.tiered(Pack.number_pack(), Pack.TIER_KOLOSSAL))
	await wait_frames(2)
	for pack in run.owned_packs:
		view.slot_pack(pack.pack_uid)
	await wait_frames(2)
	assert_eq(_seat_rect(), seat, "der Sitz behält sein Rechteck")

## Der ZÄHLER wandert in die Aufschrift, das Rechteck rührt sich dabei nicht.
func test_the_seat_rect_is_byte_stable_through_the_cycle() -> void:
	var seat := _seat_rect()
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	assert_eq(_seat_rect(), seat, "eine Kassette im Magazin")
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_eq(_seat_rect(), seat, "gesteckt")
	assert_eq(view._action_button.text, "Griff 1/%d" % run.series_slots(),
		"nur die Aufschrift zählt mit")
	view.choose_target(0)
	await wait_frames(2)
	assert_eq(_seat_rect(), seat, "mit gewähltem Ziel")

func test_the_cell_scale_has_one_source() -> void:
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	assert_almost_eq(view.shelf_cell_scale(), PackDrawerView.CASSETTE_SCALE, 0.001)
	assert_almost_eq(view.shelf_cell_scale(), view._drawer.cell_scale(), 0.001,
		"eine Quelle, auch wenn das Fach gerade nicht steht")

## Das EINE Kassettenmaß: das Magazin trägt es, und der Leseschlitz ist darauf
## geschnitten - eine Karte wächst und schrumpft auf ihrem Weg nicht mehr.
func test_magazine_and_slit_are_cut_to_the_same_cassette() -> void:
	view.data_cell_px = Vector2(40, 16)
	await wait_frames(2)
	var u := view.size.x / 100.0
	assert_almost_eq(view.shelf_cell_scale(), PackDrawerView.CASSETTE_SCALE, 0.001,
		"die Karte liegt im festen Maß im Fach")
	var cap := view.data_cell_px * PackDrawerView.CASSETTE_SCALE
	assert_gte(view.slit_size(u).x, cap.x, "und der Schlitz schluckt genau diese Kappe")
	assert_gte(view.slit_size(u).y, cap.y)
	assert_gte(view.card_size(u).x, view.slit_size(u).x,
		"die Kassette steht senkrecht über ihrem Schlitz, nie schmaler")

## Die Menge drückt keine Karte klein - nie. Der gemessene Deckel ist genau so
## gewählt, dass eine randvolle Grube noch in voller Größe steht.
func test_the_magazine_never_squeezes_its_cards_by_count() -> void:
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	var capacity := PackDrawerView.capacity_for(view.shelf_pit_rect().size,
		view.shelf_cell_px())
	assert_gt(capacity, GameRun.PACK_CAPACITY, "die echte Grube fasst mehr als der Rückfall")
	run.set_pack_capacity(capacity)
	for i in capacity:
		run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	assert_eq(run.owned_packs.size(), capacity, "bis an den Deckel gefüllt")
	assert_almost_eq(view.shelf_cell_scale(), PackDrawerView.CASSETTE_SCALE, 0.001,
		"die randvolle Grube steht in voller Größe")
	assert_null(run.grant_pack(Pack.number_pack()), "und darüber hinaus kommt nichts")

# --- (e) Der GRIFF läuft IN der Seite: auch er verrückt nichts ---------------------

func test_the_whole_grip_cycle_never_reflows_the_page() -> void:
	# Die Zeremonie hat keine eigene Seite: sie läuft in der Reihe, und der
	# SCHLITTEN fährt über allem - sein PARKPLATZ in der Säule rührt sich dabei
	# nie. Also stehen Fach, Slots, Zeilen und Sitz durch den ganzen Kreis auf
	# denselben Pixeln.
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var fach := _drawer_rect()
	var slits := _slit_rects()
	var rows := _row_names()
	var seat := _seat_rect()
	var cards := view.press_display_anchors()
	var net := view._net.get_global_rect()
	var park := view.sum_net_center()

	view.pull_lever()
	await wait_frames(2)
	assert_true(view.burning(), "die Fahrt läuft")
	assert_eq(_row_names(), rows, "dieselben Zeilen in derselben Ordnung")
	assert_eq(_seat_rect(), seat, "derselbe Sitz, jetzt mit dem Fertig")
	assert_eq(_drawer_rect(), fach, "in der Fahrt: das Fach steht")
	_assert_same_slits(slits, _slit_rects(), "in der Fahrt")
	assert_eq(view.press_display_anchors(), cards, "und die KARTENPLÄTZE stehen still")
	assert_eq(view.sum_net_center(), park, "der Parkplatz des Schlittens ebenso")

	view.skip_ceremony()
	await wait_frames(2)
	assert_false(view.burning())
	assert_eq(_row_names(), rows, "und nach dem Kreis steht wieder dieselbe Seite")
	assert_eq(_seat_rect(), seat)
	assert_eq(_drawer_rect(), fach, "danach: das Fach steht")
	_assert_same_slits(slits, _slit_rects(), "danach")
	assert_eq(view.sum_net_center(), park)
	assert_eq(view._net.get_global_rect(), net, "und das Netz steht wieder geparkt")

func test_the_console_stays_clear_of_the_drawer() -> void:
	# Die Reihe steht IM Fenster - zwischen ihr und dem Fach liegen Band und zwei
	# Nähte, und der Abstand bleibt positiv.
	var u := view.size.x / 100.0
	await wait_frames(2)
	assert_gt(_drawer_rect().position.y, _console().get_global_rect().end.y,
		"die Reihe endet weit über dem Fach")
	assert_gt(view.mouth_size(u).y, view.mouth_size(u).x,
		"ein Schacht-Mund ist höher als breit - die Karte steht hochkant darin")

func test_the_drawer_never_reflows_however_the_stock_stands() -> void:
	# Der Beweis in einem Bild: dasselbe Fach-Rechteck bei leerem, gemischtem und
	# vollem Magazin.
	await wait_frames(2)
	var empty := _drawer_rect()
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.dice_mod_pack())
	await wait_frames(2)
	assert_eq(_drawer_rect(), empty, "gemischt")
	run.grant_pack(Pack.material_pack())
	run.grant_pack(Pack.catalyst(Pack.CATALYST_GROUND))
	run.grant_pack(Pack.fixed_engraving_pack(Engraving.pointer_engraving()))
	await wait_frames(2)
	assert_eq(_drawer_rect(), empty, "voll")

# --- (f) Die STRASSE steht in jedem Kamera-Modus -----------------------------------

func test_the_bench_is_furnished_without_any_camera() -> void:
	await wait_frames(2)
	assert_not_null(view._net, "das Summen-Netz steht")
	assert_not_null(view._stage_host, "und das Ergebnis-Podest darüber")
	assert_not_null(view._diff_screen, "und der Diff-Schirm darunter")
	assert_true(view.bench_open())

## DIE STRASSE liest von LINKS nach RECHTS: Schacht-Reihe, Fuge, Ergebnis-Spalte -
## zwei Stationen, die einander nie überlappen und zusammen die 100u füllen. Die
## Bench-Spalte ist gestorben: der Zielwürfel schwebt am Ausgabefach.
func test_the_street_reads_left_to_right() -> void:
	await wait_frames(2)
	var u := view.size.x / 100.0
	var row := view.row_field_rect()
	var column := view.result_column_rect()
	assert_almost_eq(row.position.x, u * WorkshopView.CONTENT_MARGIN_X, 0.5,
		"die Schacht-Reihe steht am linken Rand")
	assert_almost_eq(column.position.x - row.end.x, u * WorkshopView.STREET_GAP, 0.5,
		"eine Fuge zur Ergebnis-Spalte")
	assert_almost_eq(column.end.x, view.size.x - u * WorkshopView.CONTENT_MARGIN_X, 0.5,
		"die endet am rechten Rand")
	assert_gt(row.size.x, 0.0, "und die Reihe bleibt")
	assert_lt(view.result_podium_rect().end.y, view.diff_screen_rect().position.y + 0.5,
		"das Ergebnis-Podest steht über dem Soll-Schirm")
	assert_almost_eq(view.diff_screen_rect().end.y, column.end.y, 0.5,
		"und der Soll-Schirm sitzt am Fuß der Ergebnis-Spalte")
	assert_false(view.has_method("bench_column_rect"),
		"die Bench-Spalte gibt es nicht mehr")
	assert_false(view.has_method("target_net_center"),
		"und ihr Podest meldet das Fenster nicht mehr")

## Nur EIN Podest meldet das Fenster noch: das Ergebnis rechts.
func test_only_the_result_podium_is_reported() -> void:
	await wait_frames(2)
	assert_gt(view.result_net_center().x, 0.0, "das Ergebnis-Podest meldet seine Mitte")
	assert_eq(view.result_projector_y(), view.result_net_center().y,
		"Zeile und Mitte sind derselbe Punkt")

func test_the_bench_is_always_furnished() -> void:
	await wait_frames(2)
	assert_true(view.bench_open())
	view.refresh()
	await wait_frames(2)
	assert_true(view.bench_open(), "auch nach jedem Neuaufbau")

## Die Reihe WÄCHST mit der Lizenz - und das Blech wächst mit ihr, nicht die
## Straße: der Soll-Schirm rührt sich keinen Byte weit.
func test_a_longer_series_grows_the_console_not_the_page() -> void:
	await wait_frames(2)
	var rows := _row_names()
	var diff := view.diff_screen_rect()
	var short_console := _console().get_global_rect().size.x
	run.hub_level = 10
	view.refresh()
	await wait_frames(2)
	assert_gt(_console().get_global_rect().size.x, short_console, "das Blech wächst")
	assert_eq(_row_names(), rows, "dieselben Stationen in derselben Ordnung")
	assert_eq(view.diff_screen_rect(), diff, "der Diff-Schirm rührt sich nicht")

## Auch die lange Reihe (Stufe 10, acht Schächte) bleibt IN ihrem Feld zwischen den
## beiden Schirmen - kein Mund läuft in eine Nachbar-Station.
func test_the_long_series_row_still_fits_between_the_screens() -> void:
	run.hub_level = 10
	view.refresh()
	await wait_frames(2)
	assert_eq(view.slot_count(), 6, "Stufe 10 trägt sechs Slots")
	var console := _console().get_rect()
	var field := view.row_field_rect()
	assert_gte(console.position.x, field.position.x - 0.5, "das Blech steht im Feld")
	assert_lte(console.end.x, field.end.x + 0.5)
	for slit in view._slit_panels:
		var mouth: Rect2 = slit.get_global_rect()
		assert_gte(mouth.position.x, view._console.get_global_rect().position.x - 0.5)
		assert_lte(mouth.end.x, view._console.get_global_rect().end.x + 0.5)

## Und ganz oben, mit jedem Zuschlag: acht Schächte passen ebenso.
func test_eight_shafts_still_fit_the_row_field() -> void:
	run.hub_level = 10
	run.series_slot_bonus = 2
	view.refresh()
	await wait_frames(2)
	assert_eq(view.slot_count(), 8, "acht ist der Deckel")
	var console := _console().get_rect()
	var field := view.row_field_rect()
	assert_lte(console.size.x, field.size.x + 0.5, "die Reihe bleibt im Feld")
	var u := view.size.x / 100.0
	assert_gte(view.mouth_width(u), u * WorkshopView.MOUTH_MIN_WIDTH - 0.001,
		"und kein Mund fällt unter sein Mindestmaß")

# --- KORREKTUR-WELLE J: ein BAND aus Ist-Netz | Tooltip | Soll-Netz ----------------

## Am Tisch meldet scene_root die linke Kante des IST-NETZES herein; hier steht ein
## Maß dafür, das links über die Fensterkante hinausragt.
const NET_OVERHANG := 300.0

func _info_screen() -> Control:
	return view.get_node("Street/InfoScreen")

## (1) Die GRUBE reicht wieder nach LINKS, bis auf die gemeldete Ist-Netz-Kante -
## rechts und unten bleibt sie, wo sie war.
func test_the_magazine_reaches_left_to_the_reported_net_edge() -> void:
	view.apron_bottom = _apron_line()
	view.shelf_left = -NET_OVERHANG
	await wait_frames(2)
	var row := _drawer_rect()
	var window := view.get_global_rect()
	assert_almost_eq(row.position.x, window.position.x - NET_OVERHANG, 1.0,
		"die Grube beginnt auf der gemeldeten Ist-Netz-Kante")
	assert_almost_eq(row.end.x, window.end.x, 2.0, "rechts bleibt sie bündig")
	assert_almost_eq(row.end.y, window.position.y + view.apron_bottom, 1.0,
		"und ihre Unterkante bleibt die Pool-Unterkante")

## (1, der FALLSTRICK) Die verbreiterte Grube liegt GANZ in der Weiterleitungs-
## Region: genau daran scheiterte die Welle H, weil bench_rect nur die HÖHE streckte.
func test_the_bench_rect_covers_the_widened_magazine() -> void:
	view.apron_bottom = _apron_line()
	view.shelf_left = -NET_OVERHANG
	await wait_frames(2)
	var bench := view.bench_rect()
	assert_true(bench.encloses(view.get_global_rect()), "das Fenster liegt darin")
	assert_true(bench.encloses(_drawer_rect().grow(-1.0)),
		"und das ganze Magazin ebenso: %s in %s" % [_drawer_rect(), bench])

## (1, der eigentliche Beweis) Eine Kassette im NEU dazugekommenen LINKEN Grubenteil
## wird über die ECHTE Weiterleitung gesteckt - dasselbe Prädikat, mit dem scene_root
## entscheidet, plus der Knopf-Pfad dahinter.
func test_a_cassette_in_the_new_left_part_still_reaches_the_slot() -> void:
	for i in 8:
		run.grant_pack(Pack.number_pack())
	# Am Tisch steht der Streifen mitten auf der Anzeige: die Weiterleitung wirft
	# negative Display-Pixel ab, also darf das Fenster hier nicht auf x = 0 kleben.
	view.position = Vector2(NET_OVERHANG + 40.0, 0.0)
	view.apron_bottom = _apron_line()
	view.shelf_left = -NET_OVERHANG
	await wait_frames(2)
	var uid := run.owned_packs[0].pack_uid
	var chip := view._drawer.pack_button(uid)
	assert_not_null(chip, "die vorderste Kassette hat einen Chip-Knopf")
	var px := chip.get_global_rect().get_center()
	assert_lt(px.x, view.get_global_rect().position.x,
		"sie liegt im NEUEN linken Grubenteil, links der Fensterkante")
	assert_true(TableScreen.window_takes_pixel(view, view.bench_rect(), px, true, false),
		"der Klick dort wird an das Fenster weitergereicht")
	chip.pressed.emit()
	await wait_frames(2)
	assert_true(view.press_slot_uids().has(uid), "und steckt die Kassette")

## (2) Der TOOLTIP-SCHIRM steht DIREKT UNTER der Schacht-Reihe und ist GENAU so
## breit wie sie.
func test_the_tooltip_sits_below_the_row_at_its_exact_width() -> void:
	await wait_frames(2)
	var u := view.size.x / 100.0
	var console := _console().get_global_rect()
	var info := _info_screen().get_global_rect()
	assert_almost_eq(info.position.x, console.position.x, 0.5, "dieselbe linke Kante")
	assert_almost_eq(info.end.x, console.end.x, 0.5, "und dieselbe rechte")
	assert_gte(info.position.y, console.end.y - 0.5, "er steht UNTER der Reihe")
	assert_almost_eq(info.size.y, u * WorkshopView.DIFF_HEIGHT_UNITS, 0.5,
		"und ist so hoch wie das Band")

## Auch mit acht Schächten: der Tooltip wächst mit der Reihe mit.
func test_the_tooltip_follows_a_longer_row() -> void:
	run.hub_level = 10
	run.series_slot_bonus = 2
	view.refresh()
	await wait_frames(2)
	assert_eq(view.slot_count(), 8)
	var console := _console().get_global_rect()
	var info := _info_screen().get_global_rect()
	assert_almost_eq(info.position.x, console.position.x, 0.5)
	assert_almost_eq(info.end.x, console.end.x, 0.5)

## (3) Das SOLL-NETZ steht RECHTS neben dem Tooltip, auf DERSELBEN Zeile - ein BAND.
func test_the_result_net_stands_beside_the_tooltip_in_one_band() -> void:
	await wait_frames(2)
	var info := _info_screen().get_global_rect()
	var diff := view._diff_screen.get_global_rect()
	assert_gte(diff.position.x, info.end.x - 0.5, "der Soll-Schirm steht rechts davon")
	assert_almost_eq(diff.position.y, info.position.y, 0.5, "auf derselben Oberkante")
	assert_almost_eq(diff.size.y, info.size.y, 0.5, "und in derselben Zeilenhöhe")
	# Und das PODEST bleibt darüber in Zeile 1 - Würfel über Netz, wie links.
	var podium := view.result_podium_rect()
	assert_lte(podium.end.y, view.band_row_rect().position.y + 0.5,
		"das Ergebnis-Podest steht über dem Band")

## (3) GLEICH GROSS wie das Ist-Netz: das gemeldete Zellmaß der Info-Säule gilt.
func test_the_result_net_takes_the_reported_cell_of_the_left_net() -> void:
	await wait_frames(2)
	var u := view.size.x / 100.0
	var wide := (view.diff_screen_rect().size.x - u * WorkshopView.DIFF_PAD * 2.0) \
		/ DieNetView.net_size(1.0).x
	view.result_net_cell = wide * 0.8  # ein Maß, das die Spalte nicht sprengt
	await wait_frames(2)
	assert_almost_eq(view._net.cell, wide * 0.8, 0.5,
		"das Soll-Netz übernimmt das Zellmaß des Ist-Netzes")

## (3) Es steht IMMER: ohne Ziel und ohne Karten trägt der Soll-Schirm das LEERE
## Kreuz - versteckt wird es nie.
func test_the_result_net_stands_empty_without_a_target() -> void:
	await wait_frames(2)
	assert_null(view.target_die(), "kein Ziel gewählt")
	assert_true(view.press_slot_uids().is_empty(), "und keine Karte gesteckt")
	assert_true(view._diff_screen.visible, "der Soll-Schirm steht")
	assert_not_null(view._empty_net, "und trägt das leere Kreuz")
	assert_true(view._empty_net.visible, "sichtbar")
	assert_eq(view._empty_net.get_child_count(), 6, "sechs leere Zellen")
	assert_almost_eq(view._empty_net.get_global_rect().size.x,
		DieNetView.net_size(view._net.cell).x, 1.0, "in Netzgröße")
	view.choose_target(0)
	await wait_frames(2)
	assert_false(view._empty_net.visible,
		"mit gewähltem Ziel tritt der Platzhalter hinter das echte Netz zurück")

## (4) Der GRIFF behält seinen sichtbaren Platz im Streifen: im Konsolen-Band
## zwischen Fensterkante und Grube - nie unter dem Magazin.
func test_the_grip_keeps_a_visible_seat_above_the_magazine() -> void:
	view.apron_bottom = _apron_line()
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	var seat := _seat_rect()
	assert_true(view._action_button.visible, "der Knopf steht")
	assert_gt(seat.size.x, 0.0)
	assert_gte(seat.position.y, view.get_global_rect().end.y - 0.5,
		"er liegt unter der Fensterkante")
	assert_lte(seat.end.y, _drawer_rect().position.y + 0.5,
		"und über dem Magazin - nie darunter")
	assert_true(view.bench_rect().encloses(seat), "und in der Weiterleitungs-Region")
