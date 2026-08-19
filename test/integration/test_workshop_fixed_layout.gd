extends GutTest
## Feste Plätze auf der Werkbank-Grundseite: nichts darf sich je verschieben.
## Die Stabilität IST die Prüfung - gemessen werden das Magazin-Fach, die sechs
## Leseschlitze und der Handlungs-Sitz, danach wird die Bank benutzt (Paket
## einlegen, Fach leerlaufen lassen, in ein leeres Fach liefern) und jedes
## Rechteck muss auf denselben Pixeln liegen wie vorher. Die Plätze IN dem Fach
## dürfen sich dabei ändern - die Reihe schließt sich hinter einem entnommenen
## Paket, das ist Magazin-Ordnung, kein Reflow der Seite.

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

func _drawer_rect() -> Rect2:
	return view._drawer.get_global_rect() if view._drawer != null else Rect2()

func _slit_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for slit in view._press_slit_panels:
		rects.append(slit.get_global_rect())
	return rects

func _seat_rect() -> Rect2:
	var seat: Control = view.get_node("PressBand/ActionSeat")
	return seat.get_global_rect()

func _multicast_rect() -> Rect2:
	var screen: Control = view.get_node("PressBand/MulticastScreen")
	return screen.get_global_rect()

func _console() -> Control:
	return view.get_node("PressBand/PressConsole")

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
	assert_eq(after.size(), before.size(), "%s: dieselbe Zahl Schlitze" % what)
	for i in before.size():
		assert_eq(after[i], before[i], "%s: Schlitz %d steht unverrückt" % [what, i])

# --- (a) Ein Paket einlegen: nur der Inhalt des Fachs ändert sich ------------------

func test_slotting_a_pack_moves_nothing_on_the_page() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	var fach := _drawer_rect()
	var slits := _slit_rects()
	var rows := _row_names()
	var seat := _seat_rect()
	var screen := _multicast_rect()
	assert_false(view._press_button.visible, "vorher zeigt sich kein Knopf")

	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_true(view._press_button.visible, "der Knopf ist da")
	assert_eq(_seat_rect(), seat, "sein Sitz war schon vorher genau so hoch")
	assert_eq(_multicast_rect(), screen, "und der Multicast-Schirm daneben ebenso")
	assert_eq(_row_names(), rows, "dieselben Zeilen in derselben Ordnung")
	assert_eq(_drawer_rect(), fach, "das Fach steht unverrückt")
	_assert_same_slits(slits, _slit_rects(), "eingelegt")

func test_taking_the_pack_back_out_moves_nothing_either() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	var fach := _drawer_rect()
	var slits := _slit_rects()

	view.clear_press_slot(0)
	await wait_frames(2)
	assert_false(view._press_button.visible, "ohne Paket geht er wieder")
	assert_eq(_drawer_rect(), fach, "zurückgenommen: das Fach steht")
	_assert_same_slits(slits, _slit_rects(), "zurückgenommen")

# --- (b) Das Fach läuft leer: es bleibt stehen -------------------------------------

func test_an_emptied_magazine_keeps_its_drawer() -> void:
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	var fach := _drawer_rect()
	var slits := _slit_rects()

	view.slot_pack(run.owned_packs[0].pack_uid)  # das letzte Paket verlässt das Fach
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

# --- (d) Die Schürze: Konsole unter der Kante, das Fach darunter -------------------

## Das Konsolen-Band hängt GANZ unter dem Fenster, zwischen zwei gleichen Nähten:
## Fensterkante - Naht - Band - Naht - Fach.
func test_the_console_hangs_below_the_window_between_two_equal_seams() -> void:
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	var console := _console().get_global_rect()
	var window := view.get_global_rect()
	var u := view.size.x / 100.0
	assert_gt(console.position.y, window.end.y, "es steht vollständig außerhalb")
	assert_almost_eq(console.position.y - window.end.y, u * WorkshopView.CONSOLE_SHELF_GAP,
		1.0, "eine Naht unter der Fensterkante")
	assert_almost_eq(_drawer_rect().position.y - console.end.y,
		console.position.y - window.end.y, 1.0, "und genau dieselbe Naht zum Fach")
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
## Naht, Fach-Streifen. Weicht sie ab, endet das Fach nicht auf der Hub-Linie.
func test_the_apron_chain_is_seam_band_seam_bays() -> void:
	var unit := view.size.x / 100.0
	# Das Band wird in ECHTEN u gemessen: seit der Schlitz die Kappe der Kassette
	# schluckt, hängt seine Höhe an einem Weltmaß und nicht mehr allein an u.
	assert_almost_eq(view.apron_units(),
		WorkshopView.CONSOLE_SHELF_GAP * 2.0 + view.console_size(unit).y / unit
			+ WorkshopView.SHELF_STRIP_UNITS, 0.001, "die Schürze in Einheiten")
	var u := view.size.x / 100.0
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	assert_almost_eq(view.shelf_top() - view.size.y,
		u * WorkshopView.CONSOLE_SHELF_GAP * 2.0 + view.console_size(u).y, 1.0,
		"und dieselbe Kette misst sich am Fenster nach")

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

## Der Abstand zur Konsole ist gesetzt, die HÖHE des Fachs folgt daraus.
func test_the_drawer_height_falls_out_of_the_gap_below_the_console() -> void:
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	var u := view.size.x / 100.0
	var gap := _drawer_rect().position.y - _console().get_global_rect().end.y
	assert_almost_eq(gap, u * WorkshopView.CONSOLE_SHELF_GAP, 1.0, "eine Naht unter dem Blech")
	assert_almost_eq(_drawer_rect().size.y, view.apron_bottom - view.shelf_top(), 1.0,
		"der Rest ist Fachhöhe")

## Fenster PLUS Schürze - daran messen sich Klick-Weiterleitung und Kamera.
func test_the_bench_rect_covers_window_and_apron() -> void:
	view.apron_bottom = _apron_line()
	await wait_frames(2)
	var bench := view.bench_rect()
	assert_true(bench.encloses(view.get_global_rect()), "das Fenster liegt darin")
	assert_true(bench.encloses(_console().get_global_rect()), "das Blech ebenso")
	assert_almost_eq(_drawer_rect().end.y, bench.end.y, 1.0,
		"und das Fach endet genau auf seiner Unterkante")

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
	assert_eq(view.shelf_pit_rect(), pit, "eingelegt: die Grube steht")
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
	assert_lte(screen.end.y, _drawer_rect().position.y + 1.0,
		"unter das Fach taucht er nie - dort liegen die Kassetten davor")

# --- Der MULTICAST-SCHIRM: das Gegenstück zum Hinweis-Schirm ----------------------

## Rechte Flanke, in dieser Ordnung: Blech - Naht - Sitz - Naht - Schirm, und der
## endet bündig auf der Fensterkante. Nichts davon überlappt.
func test_the_multicast_screen_takes_the_right_corner_behind_the_seat() -> void:
	await wait_frames(2)
	var console := _console().get_global_rect()
	var seat := _seat_rect()
	var screen := _multicast_rect()
	var window := view.get_global_rect()
	var u := view.size.x / 100.0
	assert_gt(seat.position.x, console.end.x, "der Sitz steht rechts vom Blech")
	assert_gte(screen.position.x, seat.end.x, "der Schirm steht rechts vom Sitz")
	assert_almost_eq(screen.end.x, window.end.x, 1.0, "und endet auf der Fensterkante")
	assert_almost_eq(screen.position.x - seat.end.x, u * WorkshopView.ACTION_GAP, 1.0,
		"dieselbe Naht wie zwischen Blech und Sitz")
	assert_almost_eq(screen.get_center().y, console.get_center().y, screen.size.y * 0.5,
		"er steht auf dem Band")
	assert_almost_eq(screen.size.y, view._info_screen.get_global_rect().size.y, 1.0,
		"und ist so hoch wie sein Bruder links")

## Der Sitz ist schmaler geworden - er muss seine breiteste Aufschrift trotzdem
## ungeschnitten tragen, sonst hätte clip_text sie nur versteckt.
func test_the_seat_still_carries_its_widest_label() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	var u := view.size.x / 100.0
	var button := view._press_button
	var font: Font = button.get_theme_font("font")
	var px: int = button.get_theme_font_size("font_size")
	var text := font.get_string_size("Pressen (6)", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	assert_lte(text + u * 1.2, _seat_rect().size.x,
		"die breiteste Aufschrift paßt samt Rand in den Sitz")

func test_the_screen_stays_dark_until_a_cassette_is_slotted() -> void:
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	assert_eq(view.multicast_text(), "", "ohne Kassette sagt er nichts")
	assert_false(view._multicast_body.visible)
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_true(view._multicast_body.visible, "eingelegt spricht er")
	assert_true(view.multicast_text().contains("Standard ×1"),
		"die Größe sagt, was EIN Schlag auswirft")
	assert_true(view.multicast_text().contains("Multicast 50 %"),
		"die Chance ist für alle dieselbe und steht für sich")
	assert_true(view.multicast_text().contains("max. ×3"), "und nennt die Decke")

## Chance und Decke sind LEBENDIG: der Schirm liest sie aus dem Lauf, also stehen
## Lizenzstufe, wirkende Klausel und vorgemerkter Wett-Schub sofort darauf.
func test_the_screen_prints_the_live_chance_and_limit() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	run.hub_level = 10
	await wait_frames(2)
	assert_true(view.multicast_text().contains("Multicast 75 %"), "die Sprosse der Lizenz")
	assert_true(view.multicast_text().contains("max. ×7"))
	run.round_number = 1
	run.sign_clauses([DealClause.CHAIN_DRIVER] as Array[String])
	view.refresh()
	await wait_frames(2)
	assert_true(view.multicast_text().contains("max. ×9"), "der Kettentreiber steht drauf")

## Je GRÖSSE eine Zeile, nie je Kassette - zwei Standard-Pakete sagen dasselbe wie
## eins. Die Zeile nennt den Grundwurf, nicht die (flache) Chance.
func test_one_line_per_distinct_size() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.tiered(Pack.material_pack(), Pack.TIER_KOLOSSAL))
	await wait_frames(2)
	for pack in run.owned_packs:
		view.slot_pack(pack.pack_uid)
	await wait_frames(2)
	var lines := view.multicast_lines()
	assert_eq(lines.size(), 2, "zwei Größen, zwei Zeilen")
	assert_eq(lines[0], "Standard ×1")
	assert_eq(lines[1], "Kolossal ×5")

## Der Schirm sagt die WAHRHEIT ÜBER DEN GRIFF: die Terme der eingelegten
## Katalysatoren fahren durch dieselben Abfragen wie die Pressung selbst.
func test_the_screen_composes_the_slotted_catalysts() -> void:
	run.hub_level = 1
	var bare_chance := roundi(run.multicast_chance() * 100.0)
	var bare_cap := run.multicast_cap()
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.catalyst(Pack.CATALYST_PROPELLANT))
	run.grant_pack(Pack.catalyst(Pack.CATALYST_TIMER))
	await wait_frames(2)
	for pack in run.owned_packs:
		view.slot_pack(pack.pack_uid)
	await wait_frames(2)
	var text := view.multicast_text()
	assert_true(text.contains("Multicast %d %%" % (bare_chance + 20)),
		"die Treibladung steht im Prozentsatz: %s" % text)
	assert_true(text.contains("max. ×%d" % (bare_cap + 2)),
		"und der Taktgeber im Limit: %s" % text)

## Eine Doppelmatrize hebt den Grundwurf - die Größenzeilen nennen den WIRKSAMEN.
func test_the_matrix_shows_in_the_size_lines() -> void:
	run.grant_pack(Pack.tiered(Pack.material_pack(), Pack.TIER_GROSS))
	run.grant_pack(Pack.catalyst(Pack.CATALYST_MATRIX))
	await wait_frames(2)
	for pack in run.owned_packs:
		view.slot_pack(pack.pack_uid)
	await wait_frames(2)
	assert_eq(view.multicast_lines(), ["Groß ×4"] as Array[String],
		"3 + 1, und der Katalysator selbst hat keine Zeile")

## Ein Griff aus lauter Katalysatoren presst nicht - der Sitz sperrt, und der
## Hinweis-Schirm sagt, warum.
func test_a_catalysts_only_grip_locks_the_seat() -> void:
	run.charge = 9
	run.grant_pack(Pack.catalyst(Pack.CATALYST_PROPELLANT))
	await wait_frames(2)
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_eq(view.loot_slot_count(), 0)
	assert_false(view.can_press(), "Katalysatoren allein pressen nichts")
	assert_true(view._press_button.disabled)
	assert_true(String(view._press_button.get_meta("body", "")).contains("Inhalt"),
		"und der Grund steht auf dem Hinweis-Schirm")
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	view.slot_pack(run.owned_packs[1].pack_uid)
	await wait_frames(2)
	assert_true(view.can_press(), "mit einer Kassette voll Inhalt geht es")

## Eine verbrauchte Pressung sperrt den Sitz - und die Erdungsklemme holt sie
## NICHT zurück.
func test_a_spent_session_locks_the_seat() -> void:
	run.press_uses = 1
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_false(view.can_press(), "die Pressung dieser Runde ist verbraucht")
	assert_true(String(view._press_button.get_meta("body", "")).contains("verbraucht"),
		"und der Grund steht auf dem Hinweis-Schirm")
	run.grant_pack(Pack.catalyst(Pack.CATALYST_GROUND))
	await wait_frames(2)
	view.slot_pack(run.owned_packs[1].pack_uid)
	await wait_frames(2)
	assert_false(view.can_press(), "die Klemme bewahrt, sie belebt nicht")
	run.reset_press_cycle()
	view.refresh()
	await wait_frames(2)
	assert_true(view.can_press(), "die Unterschrift gibt die Pressung zurück")

## Der Schirm rührt sich auch mit Katalysatoren keinen Byte weit.
func test_the_multicast_rect_survives_a_catalyst() -> void:
	var before := view.multicast_screen_rect()
	var seat := _seat_rect()
	run.grant_pack(Pack.catalyst(Pack.CATALYST_MATRIX))
	run.grant_pack(Pack.tiered(Pack.number_pack(), Pack.TIER_KOLOSSAL))
	await wait_frames(2)
	for pack in run.owned_packs:
		view.slot_pack(pack.pack_uid)
	await wait_frames(2)
	assert_eq(view.multicast_screen_rect(), before)
	assert_eq(_seat_rect(), seat, "und der Sitz behält sein Rechteck")

func test_a_fixed_content_cassette_says_it_never_repeats() -> void:
	run.grant_pack(Pack.fixed_engraving_pack(Engraving.pointer_engraving()))
	await wait_frames(2)
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_true(view.multicast_lines().has("Fixinhalt ×1"))

## Der Wurf schreibt seinen höchsten Schlag auf den Schirm - und ein Neuaufbau
## des Bandes nimmt ihn ihm nicht.
func test_the_peak_of_a_running_press_survives_a_rebuild() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	view.start_press()
	view.withhold_press_pieces([999])  # eine Pressung, die noch fliegt
	view.flash_multicast(4)
	await wait_frames(2)
	assert_eq(view.multicast_text(), "×4!")
	view.flash_multicast(2)
	assert_eq(view.multicast_text(), "×4!", "ein kleinerer Schlag schreibt nicht zurück")
	view.refresh()
	await wait_frames(2)
	assert_eq(view.multicast_text(), "×4!", "und der Neuaufbau liest ihn wieder")

## Der Schirm ERKLÄRT sich nicht mehr - sein Text ist ein Verweis. Hovern sagt
## darum nichts, und der Hinweis-Schirm bleibt frei für die anderen Sprecher.
func test_hovering_the_multicast_screen_says_nothing() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_true(view.chip_hint_at(_multicast_rect().get_center()).is_empty())

## Statt dessen ist das Wort ein Lexikon-Verweis wie im Laden-Tooltip: gefärbt,
## klickbar, und der Klick meldet die Eintrags-id nach draußen.
func test_the_multicast_word_is_a_lexikon_reference() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_true(Lexikon.has_entry(Lexikon.MULTICAST), "der Eintrag steht im Katalog")
	assert_true(view._multicast_body.bbcode_enabled)
	assert_true(view._multicast_body.text.contains("[url=%s]" % Lexikon.MULTICAST),
		"das Wort trägt seinen Verweis")
	assert_ne(view._multicast_body.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"und ist damit anklickbar")
	var seen: Array[String] = []
	view.lexikon_requested.connect(func(id: String) -> void: seen.append(id))
	view._multicast_body.meta_clicked.emit(Lexikon.MULTICAST)
	assert_eq(seen, [Lexikon.MULTICAST] as Array[String])

## Nur die Klickbarkeit ist neu - das Rechteck rührt sich durch den ganzen
## Presse-Zyklus keinen Byte weit.
func test_the_multicast_rect_is_byte_stable_through_the_cycle() -> void:
	var before := view.multicast_screen_rect()
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	assert_eq(view.multicast_screen_rect(), before, "eine Kassette im Magazin")
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_eq(view.multicast_screen_rect(), before, "eingesteckt")
	view.flash_multicast(4)
	await wait_frames(2)
	assert_eq(view.multicast_screen_rect(), before, "im Wurf")
	run.hub_level = 10
	view.refresh()
	await wait_frames(2)
	assert_eq(view.multicast_screen_rect(), before, "und mit längerem Text")

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
		"selbst bei sechs Netzen - mehr als die Aufspannung je stellt - bleibt Luft")
	assert_gt(view.clamp_cell(u), 0.0)
	assert_lte(view.clamp_cell(u), u * WorkshopView.CLAMP_CELL_MAX,
		"der Netz-Deckel steht unverändert")

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

# --- (e) Der Wurf läuft IN der Seite: auch er verrückt nichts ----------------------

func test_the_whole_press_cycle_never_reflows_the_page() -> void:
	# Weder Pressung noch Platzierung haben eine eigene Seite - die eine läuft in
	# den Anzeigefeldern, und ihre Beute LIEGT als Haufen über dem Zeilenfluss.
	# Also stehen Fach, Schlitze, Zeilen und der Sitz durch den ganzen Kreis auf
	# denselben Pixeln: vorher, mit liegender Beute und nach dem Fertig.
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	var fach := _drawer_rect()
	var slits := _slit_rects()
	var rows := _row_names()
	var seat := _seat_rect()
	var screen := _multicast_rect()
	var displays := view.press_display_anchors()
	var strip := view.ablage_rect()

	view.start_press()
	await wait_frames(2)
	assert_true(view.placing(), "die Beute liegt in der Ablage")
	assert_eq(_row_names(), rows, "dieselben Zeilen in derselben Ordnung")
	assert_eq(_seat_rect(), seat, "derselbe Sitz, jetzt mit dem Fertig")
	assert_eq(_multicast_rect(), screen, "der Multicast-Schirm steht durch den Wurf")
	assert_null(view._press_button, "der Pressen-Knopf tritt ab")
	assert_not_null(view._apply_button)
	assert_eq(view._apply_button.get_global_rect(), seat, "und der Knopf füllt ihn genau")
	assert_eq(_drawer_rect(), fach, "mit Beute: das Fach steht")
	_assert_same_slits(slits, _slit_rects(), "mit Beute")
	assert_eq(view.press_display_anchors(), displays, "und die Leser stehen still")
	assert_eq(view.ablage_rect(), strip, "der Streifen hängt am Fenster, nicht am Inhalt")
	assert_not_null(view._ablage_host, "der Haufen liegt da")

	view.apply_placements()  # das Fertig führt zurück auf die Grundseite
	await wait_frames(2)
	assert_false(view.placing())
	assert_eq(_row_names(), rows, "und nach dem Kreis steht wieder dieselbe Seite")
	assert_eq(_seat_rect(), seat)
	assert_eq(_multicast_rect(), screen, "auch der Schirm steht danach, wo er stand")
	assert_eq(_drawer_rect(), fach, "danach: das Fach steht")
	_assert_same_slits(slits, _slit_rects(), "danach")
	assert_eq(view.press_display_anchors(), displays)
	assert_eq(view.ablage_rect(), strip, "auch der leere Streifen steht, wo er stand")

## Der Haufen ist ein AUFLIEGER: ob er leer ist oder dreißig Chips trägt, ändert
## keinen Pixel der Grundseite.
func test_a_full_pile_moves_nothing_on_the_page() -> void:
	await wait_frames(2)
	var fach := _drawer_rect()
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
	assert_eq(_drawer_rect(), fach, "voller Haufen: das Fach steht")
	_assert_same_slits(slits, _slit_rects(), "voller Haufen")
	for i in nets.size():
		assert_eq(view._clamp_nets[i].get_global_rect(), nets[i], "Netz %d steht unverrückt" % i)
	var strip := view.ablage_rect()
	for uid in view._ablage_chips:
		assert_true(strip.has_point(view.ablage_spot(int(uid))),
			"und jeder Chip bleibt im Streifen")

func test_the_console_stays_clear_of_the_drawer() -> void:
	# Der gewachsene Leser darf das Fach nicht anschneiden - die Restluft über
	# der Konsole ist die Reserve, und sie bleibt positiv.
	var u := view.size.x / 100.0
	var console := _console()
	await wait_frames(2)
	assert_gt(_drawer_rect().position.y, console.get_global_rect().end.y,
		"die Konsole endet über dem Fach")
	assert_gt(view._content.get_node("BenchSlack").size.y, 0.0, "und darüber bleibt Luft")
	assert_gt(view.socket_size(u).y, u * WorkshopView.SLIT_DISPLAY,
		"ein Platz trägt sein Feld UND seinen Schlitz")

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

# --- (f) Auch der Tausch nimmt der Schürze nichts weg ------------------------------

func test_the_apron_stands_through_the_whole_exchange_flow() -> void:
	# Die Schürze gehört der Bank, nicht einem Ablauf: Fach, Schlitze und Blech
	# stehen auf denselben Pixeln, während der Tausch-Wähler das Fenster füllt -
	# nur anfassen lässt sich dann nichts.
	run.grant_pack(Pack.number_pack())
	run.stash_die(DieDefinition.fixed(6, "Sechser"), 0)
	await wait_frames(2)
	var fach := _drawer_rect()
	var slits := _slit_rects()
	var console := _console().get_global_rect()
	var seat := _seat_rect()
	assert_false(view.shelf_locked(), "vorher steht die Bank offen")

	assert_true(view.open_exchange(0), "der Wähler nimmt das Fenster")
	await wait_frames(2)
	assert_eq(view._phase, WorkshopView.Phase.EXCHANGE)
	assert_eq(_drawer_rect(), fach, "im Tausch: das Fach steht")
	_assert_same_slits(slits, _slit_rects(), "im Tausch")
	assert_eq(_console().get_global_rect(), console, "und das Blech steht still")
	assert_eq(_seat_rect(), seat, "der Sitz ebenso")
	assert_true(view.shelf_locked(), "aber das Fach ist zu")
	assert_false(view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER),
		"kein Paket in eine laufende Wahl")

	view._on_exchange_slot_pressed(0)
	await wait_frames(2)
	assert_eq(view._phase, WorkshopView.Phase.STASH)
	assert_eq(_drawer_rect(), fach, "danach")
	_assert_same_slits(slits, _slit_rects(), "danach")
	assert_eq(_console().get_global_rect(), console)
	assert_eq(_seat_rect(), seat)
	assert_false(view.shelf_locked(), "und die Bank steht wieder offen")

# --- (g) Die Bank ist IMMER bestückt ----------------------------------------------
# Der Blick entscheidet nichts mehr: Netzzeile, Zwingen und Dossier stehen in
# jedem Kamera-Modus. Nur die PHASE (Paket, Dossier) nimmt die Zeile weg.

func test_the_bench_is_furnished_without_any_camera() -> void:
	await wait_frames(2)
	assert_false(view._clamp_nets.is_empty(), "die Netzzeile steht")
	assert_false(view._clamp_stage_hosts.is_empty(), "und je Zwinge eine Bühne")
	assert_true(view.clamps_on_bench(), "die Aufspannung steht auf der Grundseite")

func test_only_the_phase_takes_the_net_row_away() -> void:
	await wait_frames(2)
	assert_true(view.open_inspect(run.owned_pool[0]))
	await wait_frames(2)
	assert_false(view.clamps_on_bench(), "das Dossier nimmt das Fenster")
	view.close_inspect()
	await wait_frames(2)
	assert_true(view.clamps_on_bench(), "danach kommen sie zurück")

func test_a_dossier_stands_until_it_is_closed() -> void:
	# Es überdauert jeden Kamera-Ausflug - dieselbe Grammatik wie die Platzierung.
	var die := run.owned_pool[3]
	assert_true(view.open_inspect(die))
	await wait_frames(2)
	assert_eq(view.inspected_die(), die)
	view.refresh()
	await wait_frames(2)
	assert_eq(view.inspected_die(), die, "ein Neuaufbau nimmt sie ihm nicht")
	view.close_inspect()
	await wait_frames(2)
	assert_null(view.inspected_die(), "erst das Schließen legt ihn zurück")
