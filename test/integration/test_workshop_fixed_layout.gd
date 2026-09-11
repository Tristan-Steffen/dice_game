extends GutTest
## Feste Plätze auf der Werkbank-Grundseite: nichts darf sich je verschieben.
## Die Stabilität IST die Prüfung - gemessen werden das Magazin-Fach, die
## Etagen-Felder und der Handlungs-Sitz, danach wird die Bank benutzt (Karte
## stecken, Fach leerlaufen lassen, in ein leeres Fach liefern) und jedes
## Rechteck muss auf denselben Pixeln liegen wie vorher. Die Plätze IN dem Fach
## dürfen sich dabei ändern - die Reihe schließt sich hinter einer entnommenen
## Kassette, das ist Magazin-Ordnung, kein Reflow der Seite.

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

func _drawer_rect() -> Rect2:
	return view._drawer.get_global_rect() if view._drawer != null else Rect2()

## Die ETAGEN-FELDER in Display-Pixeln - sie sind die Klick-Ziele der Etagen.
func _field_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for slot in view._slot_buttons:
		rects.append(slot.get_global_rect())
	return rects

func _seat_rect() -> Rect2:
	var seat: Control = view.get_node("Street/ActionSeat")
	return seat.get_global_rect()

## Die SCHÜRZEN-Linie: Naht plus EIN Rang der stehenden Kassette - beides steht im
## Fenster selbst, scene_root schiebt hier nichts mehr herein.
func _apron_line() -> float:
	return view.shelf_top() + view.shelf_min_height()

func _shelf_line() -> float:
	return view.apron_bottom_y()

func _row_names() -> Array[String]:
	var names: Array[String] = []
	for child in view._content.get_children():
		names.append(String(child.name))
	return names

func _assert_same_fields(before: Array[Rect2], after: Array[Rect2], what: String) -> void:
	assert_eq(after.size(), before.size(), "%s: dieselbe Zahl Etagen" % what)
	for i in before.size():
		assert_eq(after[i], before[i], "%s: Etage %d steht unverrückt" % [what, i])

# --- (a) Eine Karte stecken: nur der Inhalt des Fachs ändert sich ------------------

func test_slotting_a_card_moves_nothing_on_the_page() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	var fach := _drawer_rect()
	var fields := _field_rects()
	var rows := _row_names()
	var seat := _seat_rect()
	assert_false(view._action_button.visible, "vorher zeigt sich kein Knopf")

	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_true(view._action_button.visible, "der Knopf ist da")
	assert_eq(_seat_rect(), seat, "sein Sitz war schon vorher genau so hoch")
	assert_eq(_row_names(), rows, "dieselben Zeilen in derselben Ordnung")
	assert_eq(_drawer_rect(), fach, "das Fach steht unverrückt")
	_assert_same_fields(fields, _field_rects(), "gesteckt")

func test_taking_the_card_back_out_moves_nothing_either() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	var fach := _drawer_rect()
	var fields := _field_rects()

	view.clear_press_slot(0)
	await wait_frames(2)
	assert_false(view._action_button.visible, "ohne Karte geht er wieder")
	assert_eq(_drawer_rect(), fach, "zurückgenommen: das Fach steht")
	_assert_same_fields(fields, _field_rects(), "zurückgenommen")

# --- (b) Das Fach läuft leer: es bleibt stehen -------------------------------------

func test_an_emptied_magazine_keeps_its_drawer() -> void:
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	var fach := _drawer_rect()
	var fields := _field_rects()

	view.slot_pack(run.owned_packs[0].pack_uid)  # die letzte Karte verlässt das Fach
	await wait_frames(2)
	assert_true(view.drawer_entries().is_empty(), "das Magazin ist leer")
	assert_eq(_drawer_rect(), fach, "leergelaufen: das Fach steht weiter")
	_assert_same_fields(fields, _field_rects(), "leergelaufen")
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

## Die SCHÜRZE ist nur noch EINE Naht und das Magazin: das Konsolen-Band ist
## gestorben, der Griff steht IM Fenster.
func test_the_apron_is_one_seam_and_the_magazine() -> void:
	await wait_frames(2)
	var window := view.get_global_rect()
	var u := view.unit()
	assert_gt(_drawer_rect().position.y, window.end.y, "das Fach steht unter dem Fenster")
	assert_almost_eq(_drawer_rect().position.y - window.end.y,
		u * WorkshopView.CONSOLE_SHELF_GAP, 1.0, "genau EINE Naht darunter")
	assert_null(view.get_node_or_null("SeriesBand"), "das Konsolen-Band ist gestorben")
	assert_true(window.encloses(_seat_rect()), "der GRIFF steht im Fenster")

## Das Fensterinnere gehört der STRASSE: nichts hängt mehr herein, sie endet erst
## an der Fensterkante (bis auf ihren eigenen Rand). Der TRÄGER deckt das ganze
## Fenster - die Ränder stecken in street_rect, sonst drifteten gemeldete und
## gestellte Plätze um einen Rand auseinander.
func test_the_window_content_uses_the_full_interior() -> void:
	await wait_frames(2)
	var u := view.unit()
	assert_eq(view._content.get_global_rect(), view.get_global_rect(),
		"der Träger deckt das ganze Fenster")
	assert_almost_eq(view.street_rect().end.y, view.size.y - u * WorkshopView.CONTENT_MARGIN_Y,
		1.0, "die Straße endet einen Rand über der Fensterkante")
	# Und der GESTELLTE Platz ist der GEMELDETE: Etage 0 liegt auf floor_field_rect(0).
	var field: Rect2 = view._slot_buttons[0].get_global_rect()
	field.position -= view.get_global_rect().position
	assert_almost_eq(field.position.x, view.floor_field_rect(0).position.x, 0.5,
		"das Feld steht, wo das Fenster es meldet")
	assert_almost_eq(field.position.y, view.floor_field_rect(0).position.y, 0.5)

## Die u-Kette der Schürze ist nur noch die NAHT - die Magazin-Tiefe ist ein
## WELTMASS und steht als eigener Posten in der Höhen-Rechnung.
func test_the_apron_chain_is_one_seam() -> void:
	assert_almost_eq(WorkshopView.apron_span_units(), WorkshopView.CONSOLE_SHELF_GAP,
		0.001, "die Schürze in Einheiten")
	var u := view.unit()
	await wait_frames(2)
	assert_almost_eq(view.shelf_top() - view.size.y, u * WorkshopView.CONSOLE_SHELF_GAP,
		1.0, "und dieselbe Naht misst sich am Fenster nach")
	assert_almost_eq(view.apron_bottom_y(), view.shelf_top() + view.shelf_min_height(),
		1.0, "darunter hängt EIN Rang der stehenden Karte")

## Das Fach liegt GANZ außerhalb, über die volle Fensterbreite, und endet auf
## der gemeldeten Schürzen-Linie - es sei denn, EIN Rang der hochkanten Karte
## braucht mehr Tiefe (Welle P), dann wächst es in den freien Filz.
func test_the_drawer_lies_below_the_window_at_full_width() -> void:
	await wait_frames(2)
	var row := _drawer_rect()
	var window := view.get_global_rect()
	assert_gt(row.position.y, window.end.y, "das Fach liegt unter dem Fenster")
	assert_almost_eq(row.end.y, window.position.y + _shelf_line(), 1.0,
		"und endet auf der gemeldeten Linie, notfalls tiefer")
	assert_lte(window.size.x - row.size.x, 2.0,
		"es nimmt die volle Fensterbreite (bis auf die Pixel-Abrundung)")
	assert_almost_eq(row.get_center().x, window.get_center().x, 1.0, "und steht mittig")

## OHNE gemeldete Linkskante bleibt das Magazin der reine Streifen.
func test_the_drawer_spans_only_the_strip_at_window_width() -> void:
	await wait_frames(2)
	var row := _drawer_rect()
	var window := view.get_global_rect()
	assert_almost_eq(row.end.x, window.end.x, 2.0,
		"das Fach bleibt bündig mit der rechten Fensterkante")
	assert_almost_eq(row.position.x, window.position.x, 2.0,
		"und beginnt an der LINKEN Fensterkante - kein Pool-Überhang mehr")
	assert_almost_eq(row.size.x, window.size.x, 2.0, "genau die Streifen-Breite")

## Der Abstand zur Fensterkante ist gesetzt, die TIEFE des Fachs sind ZWEI LANES -
## der Kreislauf zeigt zwei Reihen übereinander in der Fläche.
func test_the_drawer_height_is_two_lanes_of_the_lying_card() -> void:
	await wait_frames(2)
	var u := view.unit()
	var gap := _drawer_rect().position.y - view.get_global_rect().end.y
	assert_almost_eq(gap, u * WorkshopView.CONSOLE_SHELF_GAP, 1.0,
		"eine Naht unter der Fensterkante")
	assert_almost_eq(_drawer_rect().size.y, view.shelf_min_height(), 1.0,
		"und die Tiefe ist die gemeldete Mindesttiefe")
	var lane := view.shelf_cell_px().y * PackDrawerView.CASSETTE_SCALE \
		* PackDrawerView.RANK_SPAN
	assert_almost_eq(view.shelf_min_height(),
		lane * float(PackDrawerView.LANES)
			+ PackDrawerView.LANE_GAP_PX * float(PackDrawerView.LANES + 1)
			+ PackDrawerView.rim_inset(view.shelf_unit()) * 2.0, 1.0,
		"zwei Lanes, drei gleiche Ränder und die gemalte Fassung")
	# Und die Grube trägt beide Lanes samt der drei gleichen Ränder wirklich.
	var lanes := PackDrawerView.lane_rects(view.shelf_pit_rect().size)
	assert_almost_eq(lanes[0].position.y,
		PackDrawerView.LANE_GAP_PX, 0.01, "der Rand über der hinteren Reihe")
	assert_almost_eq(lanes[1].position.y - lanes[0].end.y,
		PackDrawerView.LANE_GAP_PX, 0.01, "derselbe zwischen den Reihen")
	assert_almost_eq(view.shelf_pit_rect().size.y - lanes[1].end.y,
		PackDrawerView.LANE_GAP_PX, 0.01, "und derselbe unter der vorderen Reihe")
	# ... und die zwei Lanes liegen wirklich ÜBEREINANDER in der Grube.
	var pit := view.shelf_pit_rect()
	assert_gt(pit.size.y, lane * 1.9, "die Grube trägt beide Reihen")
	assert_true(view.bench_rect().encloses(pit),
		"und bench_rect streckt sich mit - sonst schluckt sie jeden Chip-Tap")

## Fenster PLUS Schürze - daran messen sich Klick-Weiterleitung und Kamera.
func test_the_bench_rect_covers_window_and_apron() -> void:
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
		var derived := PackDrawerView.anchor_in(view.shelf_pit_rect(),
			view.shelf_cell_of(uid), view.shelf_cell_px(), view.shelf_lane_of(uid))
		# Auf Pixelrundung genau - alles darüber wäre ein sichtbarer Sprung.
		assert_almost_eq(derived.x, measured.x, 1.5, "uid %d: dieselbe Spalte" % uid)
		assert_almost_eq(derived.y, measured.y, 1.5, "uid %d: dieselbe Höhe" % uid)

## Der GRIFF steht am RECHTEN Ende der Zeile, neben dem PODEST (Welle Z), und die
## gemeldete LEHNE des Turms schiebt alles rechts von ihm mit.
func test_the_seat_stands_right_of_the_podium() -> void:
	await wait_frames(2)
	var origin := view.get_global_rect().position
	var podium := view.target_podium_rect()
	var seat := _seat_rect()
	assert_almost_eq(seat.position.x - (origin.x + podium.end.x),
		view.unit() * WorkshopView.STREET_GAP, 0.5, "der Sitz steht rechts vom Podest")
	assert_almost_eq(seat.get_center().y,
		origin.y + view.row_rect().get_center().y, 1.0, "und auf der Zeilenmitte")
	var lean_free := view.ist_screen_rect().position.x
	view.tower_lean = 40.0
	await wait_frames(2)
	assert_almost_eq(view.ist_screen_rect().position.x - lean_free, 40.0, 0.5,
		"eine gemeldete Lehne schiebt das Ziel-Netz weiter nach rechts")
	assert_almost_eq(_seat_rect().position.x
		- (origin.x + view.target_podium_rect().end.x),
		view.unit() * WorkshopView.STREET_GAP, 0.5, "und den Sitz mit ihm")
	view.tower_lean = 0.0
	# Die LEHNE des PODEST-Würfels hält allein den Sitz auf Abstand - ohne sie deckte
	# der schwebende Würfel den Knopf zu (am Bild gemessen).
	view.die_lean = 30.0
	await wait_frames(2)
	assert_almost_eq(_seat_rect().position.x
		- (origin.x + view.target_podium_rect().end.x),
		view.unit() * WorkshopView.STREET_GAP + 30.0, 0.5,
		"die Lehne der Bühne schiebt den Sitz nach rechts")
	view.die_lean = 0.0
	await wait_frames(2)

## Der Streifen trägt KEINEN Schirm-Hintergrund mehr - er liegt auf dem Filz, und
## der NETZ-SCHIRM ebenso (Korrektur-Welle I).
func test_the_strip_has_no_window_background() -> void:
	await wait_frames(2)
	assert_true(view.get_theme_stylebox("panel") is StyleBoxEmpty,
		"das Fenster malt nichts")
	assert_true(view._ist_screen.get_theme_stylebox("panel") is StyleBoxEmpty,
		"der NETZ-SCHIRM steht auf blankem Filz")

## Der Sitz muss seine breiteste Aufschrift ungeschnitten tragen, sonst hätte
## clip_text sie nur versteckt.
func test_the_seat_still_carries_its_widest_label() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	var u := view.unit()
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

## Das EINE Kassettenmaß: das Magazin trägt es, und der TURM ist auf die LIEGENDE
## Karte geschnitten - eine Karte wächst und schrumpft auf ihrem Weg nicht.
func test_magazine_and_tower_are_cut_to_the_same_cassette() -> void:
	view.data_cell_px = Vector2(16, 40)
	await wait_frames(2)
	assert_almost_eq(view.shelf_cell_scale(), PackDrawerView.CASSETTE_SCALE, 0.001,
		"die Karte steht im festen Maß im Turm")
	var lying := Vector2(40.0 * WorkshopView.CARD_ASPECT, 40.0) \
		* PackDrawerView.CASSETTE_SCALE
	assert_almost_eq(view.lie_span_px().x, lying.x, 0.001,
		"die LIEGENDE Karte folgt aus der gemeldeten stehenden Zelle")
	assert_almost_eq(view.lie_span_px().y, lying.y, 0.001)
	assert_almost_eq(view.tower_span_px().y, lying.y * WorkshopView.TOWER_ROOM, 0.001,
		"und der Turm ist sie plus Luft")
	assert_almost_eq(view.tower_span_px().x,
		lying.x * WorkshopView.TOWER_ROOM / (1.0 - TowerView.BAR_SHARE), 0.001,
		"längs steckt darin noch die KONTAKTLEISTE - EINE Quelle für ihre Tiefe")

## Der TURM-Platz liegt QUER: die Langseite waagerecht, die Karte liest darin von
## links nach rechts.
func test_the_tower_footprint_lies_crosswise() -> void:
	await wait_frames(2)
	assert_gt(view.tower_span_px().x, view.tower_span_px().y,
		"ein liegender Turm-Fußabdruck ist breiter als tief")
	assert_almost_eq(view.tower_rect().get_center().y,
		view.row_rect().get_center().y, 0.5, "er sitzt auf der Zeilenmitte")

## Die Menge drückt keine Karte klein - nie. Der gemessene Deckel ist genau so
## gewählt, dass eine randvolle Grube noch in voller Größe steht.
func test_the_magazine_never_squeezes_its_cards_by_count() -> void:
	await wait_frames(2)
	var columns := PackDrawerView.columns_for(view.shelf_pit_rect().size,
		view.shelf_cell_px(), 1)
	var capacity := PackDrawerView.capacity_for(view.shelf_pit_rect().size,
		view.shelf_cell_px())
	assert_gt(capacity, 0, "die Grube hat einen GEMESSENEN Deckel")
	assert_eq(capacity, columns * GameRun.PACK_ROWS, "Reihe mal Kreislauf-Reihen")
	run.set_pack_grid(columns)
	for i in capacity:
		run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	assert_eq(run.owned_packs.size(), capacity, "bis an den Deckel gefüllt")
	assert_almost_eq(view.shelf_cell_scale(), PackDrawerView.CASSETTE_SCALE, 0.001,
		"die randvolle Grube steht in voller Größe")
	assert_null(run.grant_pack(Pack.number_pack()), "und darüber hinaus kommt nichts")

# --- (e) Der GRIFF läuft IN der Seite: auch er verrückt nichts ---------------------

func test_the_whole_grip_cycle_never_reflows_the_page() -> void:
	# Die Zeremonie hat keine eigene Seite: sie läuft im Turm, und das EINE Netz
	# parkt dabei still. Also stehen Fach, Etagen, Zeilen und Sitz durch den ganzen
	# Kreis auf denselben Pixeln.
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	var fach := _drawer_rect()
	var fields := _field_rects()
	var rows := _row_names()
	var seat := _seat_rect()
	var cards := view.press_display_anchors()
	var net := view._net.get_global_rect()
	var park := view.ist_net_center()

	# Der Griff verlangt eine VOLLE Reihe: der Turm IST sechs Etagen.
	while view.press_slot_uids().size() < GameRun.SERIES_SLOT_CAP:
		var filler := run.grant_pack(Pack.number_pack())
		if not view.slot_pack(filler.pack_uid):
			break
	view.pull_lever()
	await wait_frames(2)
	assert_true(view.burning(), "die Fahrt läuft")
	assert_eq(_row_names(), rows, "dieselben Zeilen in derselben Ordnung")
	assert_eq(_seat_rect(), seat, "derselbe Sitz, jetzt mit dem Fertig")
	assert_eq(_drawer_rect(), fach, "in der Fahrt: das Fach steht")
	_assert_same_fields(fields, _field_rects(), "in der Fahrt")
	assert_eq(view.press_display_anchors(), cards, "und die KARTENPLÄTZE stehen still")
	assert_eq(view.ist_net_center(), park, "der Parkplatz des Netzes ebenso")

	view.skip_ceremony()
	await wait_frames(2)
	assert_false(view.burning())
	assert_eq(_row_names(), rows, "und nach dem Kreis steht wieder dieselbe Seite")
	assert_eq(_seat_rect(), seat)
	assert_eq(_drawer_rect(), fach, "danach: das Fach steht")
	_assert_same_fields(fields, _field_rects(), "danach")
	assert_eq(view.ist_net_center(), park)
	assert_eq(view._net.get_global_rect(), net, "und das Netz steht wieder geparkt")

func test_the_tower_stays_clear_of_the_drawer() -> void:
	# Der Turm steht IM Fenster - zwischen ihm und dem Fach liegen der Rand und
	# eine Naht, und der Abstand bleibt positiv.
	await wait_frames(2)
	assert_gt(_drawer_rect().position.y,
		view.get_global_rect().position.y + view.tower_rect().end.y,
		"der Turm endet über dem Fach")

## DIE ETAGEN-LEISTE: sechs Felder in EINER Spalte, gleiche Teilung - und Etage 1
## steht UNTEN, denn das Licht steigt.
func test_the_floor_strip_is_one_column_with_floor_one_at_the_bottom() -> void:
	await wait_frames(2)
	assert_eq(view.step_count(), view.slot_count(), "je Slot eine Etage")
	var rects := view.floor_field_rects()
	assert_eq(rects.size(), view.step_count())
	for i in rects.size():
		assert_almost_eq(rects[i].position.x, rects[0].position.x, 0.001,
			"Etage %d steht in derselben Spalte" % i)
		assert_almost_eq(rects[i].size.x, rects[0].size.x, 0.001)
		assert_almost_eq(rects[i].size.y, rects[0].size.y, 0.001)
		if i > 0:
			assert_lt(rects[i].position.y, rects[i - 1].position.y,
				"Etage %d liegt HÖHER im Bild als die darunter" % i)
			assert_almost_eq(rects[i - 1].position.y - rects[i].position.y,
				rects[0].size.y + view.unit() * WorkshopView.STRIP_GAP, 0.001,
				"gleiche Teilung")
	assert_almost_eq(view.strip_rect().size.y, view.row_rect().size.y, 0.001,
		"die Leiste nimmt die ganze Zeilenhöhe")

## Jedes Feld trägt seine NUMMER - die Reihenfolge steht da, bevor die erste Karte
## liegt -, und belegt trägt es die Sortenfarbe.
func test_a_floor_field_carries_its_number_and_its_sort_colour() -> void:
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	for i in view.step_count():
		var label: Label = view._slot_buttons[i].get_node("FloorNumber")
		assert_eq(label.text, str(i + 1), "Feld %d nennt seine Etage" % i)
	var empty: StyleBoxFlat = view._slot_buttons[0].get_theme_stylebox("normal")
	assert_eq(empty.bg_color, WorkshopView.FIELD_EMPTY, "leer bleibt es dunkel")
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	var filled: StyleBoxFlat = view._slot_buttons[0].get_theme_stylebox("normal")
	assert_ne(filled.bg_color, WorkshopView.FIELD_EMPTY, "belegt trägt es die Sorte")
	var sort: Color = PackDrawerView.COLORS[Engraving.CATEGORY_NUMBER]
	assert_almost_eq(filled.border_color.h, sort.h, 0.02,
		"und zwar im Farbton ihrer Sorte")

## Die GRÖSSE sagt die INTENSITÄT: dieselbe Leiter, die auch die Karte liest.
func test_the_field_colour_follows_the_pack_tier() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.tiered(Pack.number_pack(), Pack.TIER_KOLOSSAL))
	view.slot_pack(run.owned_packs[0].pack_uid)
	view.slot_pack(run.owned_packs[1].pack_uid)
	await wait_frames(2)
	var small: StyleBoxFlat = view._slot_buttons[0].get_theme_stylebox("normal")
	var big: StyleBoxFlat = view._slot_buttons[1].get_theme_stylebox("normal")
	assert_lt(small.border_color.s, big.border_color.s,
		"das Kolossale steht gesättigter da")
	assert_almost_eq(small.border_color.h, big.border_color.h, 0.02,
		"die Sorte bleibt dieselbe Farbe")

## Die HÖHE der Zeile trägt die HÖCHSTE Spalte - hier der Summen-Schirm.
func test_the_row_height_is_the_tallest_column() -> void:
	await wait_frames(2)
	var u := view.unit()
	var wanted := WorkshopView.bench_height_for(u, view.net_span(u).y,
		view.tower_span_px().y, view.stage_px())
	assert_almost_eq(view.size.y, roundf(wanted), 1.0,
		"die Fensterhöhe folgt der höchsten Spalte")
	assert_lte(view.tower_rect().size.y, view.row_rect().size.y + 0.5,
		"der Turm paßt in die Zeile")
	assert_lte(view.sum_screen_rect(u).size.y, view.row_rect().size.y + 0.5,
		"der Summen-Schirm ebenso")

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
	assert_not_null(view._net, "das EINE Netz steht")
	assert_not_null(view._target_stage_host, "und das Podest davor")
	assert_not_null(view._ist_screen, "und sein Schirm")
	assert_true(view.bench_open())

## DIE ZEILE liest seit der WELLE Z von LINKS nach RECHTS: Summen-Netz, Leiste,
## Auswurf-Bahn, Turm, Ziel-Netz, Podest, Griff - die GRUBE links, der WÜRFEL rechts,
## Spalten, die einander nie überlappen.
func test_the_page_reads_left_to_right() -> void:
	await wait_frames(2)
	var u := view.unit()
	var podium := view.target_podium_rect()
	var ist := view.ist_screen_rect()
	var sum := view.sum_screen_rect(u)
	var strip := view.strip_rect()
	var tower := view.tower_rect()
	var grip := view.grip_seat_rect()
	assert_almost_eq(sum.position.x, u * WorkshopView.CONTENT_MARGIN_X, 0.5,
		"das SUMMEN-NETZ steht am linken Rand")
	assert_almost_eq(strip.position.x - sum.end.x, u * WorkshopView.STREET_GAP, 0.5)
	assert_almost_eq(tower.position.x - strip.end.x,
		u * WorkshopView.STREET_GAP + view.eject_lane_px(), 0.5,
		"zwischen Leiste und Turm liegt die AUSWURF-BAHN")
	assert_almost_eq(ist.position.x - tower.end.x,
		u * WorkshopView.STREET_GAP + view.tower_lean, 0.5,
		"hinter dem Turm die Luft seiner LEHNE, dann das ZIEL-NETZ")
	assert_almost_eq(podium.position.x - ist.end.x, u * WorkshopView.STREET_GAP, 0.5)
	assert_almost_eq(grip.position.x - podium.end.x, u * WorkshopView.STREET_GAP, 0.5)
	assert_lte(grip.end.x, view.size.x - u * WorkshopView.CONTENT_MARGIN_X + 0.5,
		"der Griff bleibt im Rand")
	assert_almost_eq(ist.size.x, view.net_column_width(u), 0.5,
		"die Netz-Spalten folgen dem Netz")
	assert_almost_eq(sum.size.x, view.net_column_width(u), 0.5)

## Die AUSWURF-BAHN ist so breit, dass die unterste Karte GANZ aus dem Turm fährt.
func test_the_eject_lane_takes_the_whole_pull() -> void:
	await wait_frames(2)
	assert_almost_eq(view.eject_lane_px(),
		view.lie_span_px().x * TowerView.eject_share(view.step_count()), 0.001,
		"EINE Quelle: der Zug des Körpers")
	assert_gte(view.eject_lane_px(), view.lie_span_px().x,
		"mindestens eine ganze Kartenlänge")

## DIE GEMEINSAME GRUBE (Welle Y): die BUCHT deckt Turm UND Auswurf-Bahn, berührt
## die Magazin-Grube und läßt die ETAGEN-LEISTE draußen auf dem Glas.
func test_the_tower_bay_touches_the_magazine_pit() -> void:
	await wait_frames(2)
	var bay := view.tower_pit_rect()
	var shelf := view.shelf_pit_rect()
	var origin := view.get_global_rect().position
	var tower := view.tower_rect()
	assert_true(bay.encloses(Rect2(origin + tower.position, tower.size)),
		"der Turm steht ganz in der Bucht")
	assert_lte(bay.position.x,
		origin.x + tower.position.x - view.eject_lane_px() + 0.5,
		"und die AUSWURF-BAHN liegt mit darin")
	assert_almost_eq(bay.end.y, shelf.position.y, 0.001,
		"unten berührt sie die Magazin-Grube: EIN Raum aus zwei Rechtecken")
	assert_gte(bay.position.x, origin.x + view.strip_rect().end.x - 0.001,
		"die ETAGEN-LEISTE bleibt links AUSSERHALB - im Loch wird nichts gemalt")
	assert_gte(bay.position.y, origin.y - 0.001, "und oben bleibt sie im Fenster")

## Die gemeldete MINDEST-KANTE des Turms ist mit der WELLE Z gestorben: er steht in
## der Grube und ragt nirgends heraus, also darf die Bucht unter der Pool-Reihe liegen.
func test_the_reported_tower_minimum_is_dead() -> void:
	await wait_frames(2)
	assert_null(view.get("min_tower_left"), "keine gemeldete Mindest-Kante mehr")
	assert_almost_eq(view.tower_rect().position.x,
		view.strip_rect().end.x + view.unit() * WorkshopView.STREET_GAP
			+ view.eject_lane_px(), 0.5,
		"der Turm steht allein auf der gerechneten Kante")

## Das EINE Podest meldet das Fenster, und es steht seit der WELLE Z RECHTS vom
## ZIEL-NETZ - um den gemessenen Neigungs-Versatz nach unten gerückt.
func test_the_podium_stands_right_of_the_target_net() -> void:
	await wait_frames(2)
	assert_gt(view.target_net_center().x, 0.0, "das Podest meldet seine Mitte")
	assert_eq(view.target_projector_y(), view.target_net_center().y,
		"Zeile und Mitte sind derselbe Punkt")
	assert_almost_eq(view.target_podium_rect().get_center().y,
		view.row_rect().get_center().y + WorkshopView.BENCH_TILT_TRIM, 0.5,
		"die Podest-Mitte liegt auf der Zeilenmitte plus dem Neigungs-Versatz")
	assert_gte(view.target_podium_rect().position.x,
		view.ist_screen_rect().end.x - 0.5, "und rechts vom Ziel-Netz")
	assert_lte(view.target_podium_rect().end.x,
		view.grip_seat_rect().position.x + 0.5, "vor dem Griff")

## Die BÜHNE ist ein WELTMASS: die Würfelfläche mal ihrem Faktor.
func test_the_stage_span_is_a_world_measure() -> void:
	view.die_face_px = 40.0
	await wait_frames(2)
	assert_almost_eq(view.stage_px(), 40.0 * WorkshopView.STAGE_FACES, 0.001)
	assert_almost_eq(view.target_podium_rect().size.x, view.stage_px(), 0.001)
	view.die_face_px = 0.0
	await wait_frames(2)
	assert_almost_eq(view.stage_px(), view.unit() * WorkshopView.STAGE_HEIGHT, 0.001,
		"ohne Meldung trägt der kopflose Rückfall")

func test_the_bench_is_always_furnished() -> void:
	await wait_frames(2)
	assert_true(view.bench_open())
	view.refresh()
	await wait_frames(2)
	assert_true(view.bench_open(), "auch nach jedem Neuaufbau")

## Die LEISTE wächst mit der Serienlänge - der TURM und die Netz-Spalten rühren
## sich dabei nicht. Kürzer wird sie nur noch über den KURZSCHLUSS.
func test_a_longer_series_splits_the_strip_not_the_columns() -> void:
	var short_circuit: Array[String] = [DealClause.SHORT_CIRCUIT]
	run.sign_clauses(short_circuit)
	view.refresh()
	await wait_frames(2)
	var u := view.unit()
	var screen := view.sum_screen_rect(u)
	var strip := view.strip_rect().position.x
	var one_field := view.floor_field_rect(0).size.y
	assert_eq(view.step_count(), 1, "der Kurzschluß läßt EIN Feld")
	run.active_deals.clear()
	view.refresh()
	await wait_frames(2)
	assert_eq(view.slot_count(), 6, "ohne Klausel steht die volle Leiste")
	assert_lt(view.floor_field_rect(0).size.y, one_field,
		"sechs Felder teilen dieselbe Spalte")
	assert_eq(view.sum_screen_rect(u), screen, "der Summen-Schirm rührt sich nicht")
	assert_almost_eq(view.strip_rect().position.x, strip, 0.001,
		"und die Leiste steht auf derselben Kante")
	for station in ["TargetStage", "IstScreen", "ActionSeat", "SumScreen"]:
		assert_true(station in _row_names(), "%s steht weiter" % station)

## Und der DECKEL steht hart auf SECHS: Taktgeber, Wett-Schub und Kettentreiber
## heben ihn nicht mehr - der Turm IST sechs Etagen.
func test_six_floors_are_the_hard_cap() -> void:
	run.series_slot_bonus = 2
	run.grant_press_boost()
	view.refresh()
	await wait_frames(2)
	assert_eq(view.slot_count(), 6, "sechs ist der Deckel")
	assert_eq(view.floor_field_rects().size(), 6, "sechs Etagen-Felder")
	assert_almost_eq(view.tower_span_px().y,
		view.lie_span_px().y * WorkshopView.TOWER_ROOM, 0.001,
		"und der Turm schrumpft nicht: die Karte hat EINE Größe")

# --- Ein BAND aus Podest | Ist-Netz | Summen-Netz | Leiste | Turm ------------------

func _info_screen() -> Control:
	return view.get_node("Street/SumScreen")

## (1) Die GRUBE spannt nur noch den STREIFEN: der Überhang unter die fremde
## Info-Säule ist mit dem Umzug unter den Pool gestorben.
func test_the_magazine_spans_exactly_the_strip() -> void:
	await wait_frames(2)
	var row := _drawer_rect()
	var window := view.get_global_rect()
	assert_almost_eq(row.position.x, window.position.x, 1.0, "links bündig")
	assert_almost_eq(row.end.x, window.end.x, 2.0, "rechts bündig")
	assert_almost_eq(row.end.y, window.position.y + _shelf_line(), 1.0,
		"und ihre Unterkante bleibt die Schürzenlinie, solange EIN Rang hineinpaßt")
	assert_null(view.get("shelf_left"), "die gemeldete Linkskante ist fort")

## (1, der FALLSTRICK) Die Grube liegt GANZ in der Weiterleitungs-Region: genau
## daran scheiterte die Welle H, weil bench_rect nur die HÖHE streckte.
func test_the_bench_rect_covers_the_whole_magazine() -> void:
	await wait_frames(2)
	var bench := view.bench_rect()
	assert_true(bench.encloses(view.get_global_rect()), "das Fenster liegt darin")
	assert_true(bench.encloses(_drawer_rect().grow(-1.0)),
		"und das ganze Magazin ebenso: %s in %s" % [_drawer_rect(), bench])

## (1, der eigentliche Beweis) Eine Kassette im UNTEREN Grubenteil - unterhalb der
## Schürzenlinie, wo die liegende Karte den Streifen nach unten wachsen läßt - wird
## über die ECHTE Weiterleitung gesteckt: dasselbe Prädikat, mit dem scene_root
## entscheidet, plus der Knopf-Pfad dahinter.
func test_a_cassette_in_the_lower_pit_part_still_reaches_the_slot() -> void:
	for i in 8:
		run.grant_pack(Pack.number_pack())
	# Am Tisch steht der Streifen mitten auf der Anzeige, nicht auf x = 0.
	view.position = Vector2(340.0, 0.0)
	# Eine Schürzenlinie, die KÜRZER ist als die liegende Karte braucht: der Streifen
	# wächst dann nach unten über sie hinaus (shelf_min_height).
	view.apron_bottom = view.size.y + 1.0  # eine zu kurze Linie: das Fach wächst darüber hinaus
	await wait_frames(2)
	assert_gt(_drawer_rect().end.y, view.get_global_rect().position.y + view.apron_bottom,
		"das Magazin reicht unter die gemeldete Schürzenlinie")
	var uid := run.owned_packs[0].pack_uid
	var chip := view._drawer.pack_button(uid)
	assert_not_null(chip, "die vorderste Kassette hat einen Chip-Knopf")
	var px := chip.get_global_rect().get_center()
	assert_true(TableScreen.window_takes_pixel(view, view.bench_rect(), px, true, false),
		"der Klick dort wird an das Fenster weitergereicht")
	chip.pressed.emit()
	await wait_frames(2)
	assert_true(view.press_slot_uids().has(uid), "und steckt die Kassette")

## (2) Der SUMMEN-SCHIRM steht seit der WELLE Z als ERSTE Spalte, links der Leiste.
func test_the_sum_screen_stands_first_in_the_row() -> void:
	await wait_frames(2)
	var u := view.unit()
	var info := _info_screen().get_global_rect()
	info.position -= view.get_global_rect().position
	assert_almost_eq(info.position.x, view.sum_screen_rect(u).position.x, 0.5,
		"dieselbe linke Kante")
	assert_almost_eq(info.size.x, view.net_column_width(u), 0.5, "und dieselbe Breite")
	assert_almost_eq(info.position.x, view.row_rect().position.x, 0.5,
		"er steht am linken Rand der Zeile")
	assert_lte(info.end.x, view.strip_rect().position.x + 0.5,
		"und links von der Leiste")
	assert_almost_eq(info.size.y, view.net_span(u).y
		+ u * WorkshopView.INFO_MARGIN * 2.0, 0.5,
		"seine Höhe ist das Netz plus seiner Fassung - die Caption ist tot")

## (3) Das EINE NETZ steht RECHTS vom Turm und links vom Podest - und IMMER: ohne
## Ziel als leeres Kreuz.
func test_the_one_net_stands_right_of_the_tower() -> void:
	await wait_frames(2)
	var origin := view.get_global_rect().position
	var screen: Control = view.get_node("Street/IstScreen")
	var ist := screen.get_global_rect()
	assert_gte(ist.position.x, origin.x + view.tower_rect().end.x - 0.5,
		"der Netz-Schirm steht hinter dem Turm")
	assert_lte(ist.end.x, origin.x + view.target_podium_rect().position.x + 0.5,
		"und vor dem Podest")
	assert_almost_eq(ist.get_center().y,
		origin.y + view.row_rect().get_center().y, 0.5,
		"er sitzt auf der Zeilenmitte")
	assert_true(screen.get_theme_stylebox("panel") is StyleBoxEmpty, "auf blankem Filz")

## (3) Die Netz-ZELLE IST die gemeldete WÜRFELFLÄCHE (WELLE S), und der
## Summen-Schirm teilt dasselbe Maß.
func test_the_net_cell_is_the_reported_die_face() -> void:
	view.die_face_px = 31.0
	view.choose_target(0)
	await wait_frames(2)
	var u := view.unit()
	assert_almost_eq(view.net_cell(u), 31.0, 0.001, "die Zelle IST die Würfelfläche")
	assert_almost_eq(view._net.cell, 31.0, 0.001, "das Netz trägt sie")
	assert_almost_eq(view.sum_net_cell(u), 31.0, 0.001, "und der Summen-Schirm auch")
	assert_almost_eq(view.net_column_width(u),
		maxf(DieNetView.net_size(31.0).x + u * maxf(WorkshopView.DIFF_PAD,
			WorkshopView.INFO_MARGIN) * 2.0,
			u * WorkshopView.DIFF_WIDTH_UNITS), 0.5,
		"die Spalte wächst mit dem Netz")
	view.die_face_px = 0.0
	await wait_frames(2)
	assert_ne(view.net_cell(view.unit()), 31.0,
		"ohne Meldung trägt wieder der kopflose Fit")

## (3) Es steht IMMER: ohne Ziel und ohne Karten trägt der Schirm das LEERE Kreuz -
## versteckt wird es nie.
func test_the_one_net_stands_empty_without_a_target() -> void:
	await wait_frames(2)
	assert_null(view.target_die(), "kein Ziel gewählt")
	assert_true(view.press_slot_uids().is_empty(), "und keine Karte gesteckt")
	assert_true(view._ist_screen.visible, "der Netz-Schirm steht")
	assert_not_null(view._empty_net, "und trägt das leere Kreuz")
	assert_true(view._empty_net.visible, "sichtbar")
	assert_eq(view._empty_net.get_child_count(), 6, "sechs leere Zellen")
	assert_almost_eq(view._empty_net.get_global_rect().size.x,
		DieNetView.net_size(view._net.cell).x, 1.0, "in Netzgröße")
	view.choose_target(0)
	await wait_frames(2)
	assert_false(view._empty_net.visible,
		"mit gewähltem Ziel tritt der Platzhalter hinter das echte Netz zurück")

## bench_width_for zählt ZWEI Netz-Spalten, Leiste, Bahn, Turm, Bühne und Griff -
## jede Spalte und jede der fünf Fugen genau einmal.
func test_bench_width_counts_every_column() -> void:
	var u := 5.0
	var net := 168.3
	var tower := 157.0
	var stage := 94.0
	var lane := 148.0
	var column := maxf(net + u * maxf(WorkshopView.DIFF_PAD,
		WorkshopView.INFO_MARGIN) * 2.0, u * WorkshopView.DIFF_WIDTH_UNITS)
	var wanted := u * (WorkshopView.CONTENT_MARGIN_X * 2.0 + WorkshopView.STRIP_WIDTH
		+ WorkshopView.STREET_GAP * 5.0 + WorkshopView.ACTION_WIDTH) \
		+ column * 2.0 + lane + tower + stage
	assert_almost_eq(WorkshopView.bench_width_for(u, net, tower, stage, lane),
		wanted, 0.001, "jede Spalte und jede Fuge genau einmal")
	assert_almost_eq(WorkshopView.bench_width_for(u, net, tower, stage, lane, 60.0),
		wanted + 60.0, 0.001, "die LEHNE des Turms kommt obendrauf")
	assert_almost_eq(WorkshopView.bench_width_for(u, net, tower, stage, lane, 0.0, 25.0),
		wanted + 25.0, 0.001, "und die der Bühne ebenso")

## Die HÖHE ist GEGEBEN: die höchste der drei Spalten plus die beiden Ränder -
## nichts davon hängt an einem Budget.
func test_the_height_is_the_tallest_column_plus_the_margins() -> void:
	var u := 3.56
	var net := 125.28
	var tower := 97.3
	var stage := 94.0
	var nets := net + u * WorkshopView.INFO_MARGIN * 2.0
	assert_almost_eq(WorkshopView.bench_height_for(u, net, tower, stage),
		nets + u * WorkshopView.height_units(), 0.001,
		"hier bindet der Summen-Schirm")
	assert_almost_eq(WorkshopView.bench_height_for(u, net, 400.0, stage),
		400.0 + u * WorkshopView.height_units(), 0.001,
		"ein hoher Turm bindet statt dessen")
	assert_almost_eq(WorkshopView.height_units(),
		WorkshopView.CONTENT_MARGIN_Y * 2.0, 0.001, "die u-Kette ist nur der Rand")

## Und die MASSEINHEIT folgt der WÜRFELFLÄCHE, nicht einem Höhen-Budget.
func test_the_unit_follows_the_die_face() -> void:
	assert_almost_eq(WorkshopView.unit_for(39.15),
		39.15 / WorkshopView.U_PER_FACE, 0.001)
	assert_gt(WorkshopView.unit_for(60.0), WorkshopView.unit_for(30.0),
		"eine größere Würfelfläche gibt eine größere Einheit")
	assert_gte(WorkshopView.unit_for(0.0), 0.5, "und sie fällt nie auf null")

## Die so gelöste Breite trägt die Zeile wirklich: der Turm bleibt in ihr, und der
## Griff bleibt im rechten Rand.
func test_the_solved_width_really_carries_the_row() -> void:
	var u0 := view.unit()
	view.unit_px = u0
	view.size.x = WorkshopView.bench_width_for(u0, view.net_span(u0).x,
		view.tower_span_px().x, view.stage_px(), view.eject_lane_px())
	view.refresh()
	await wait_frames(2)
	assert_eq(view.slot_count(), 6)
	assert_gte(view.tower_rect().position.x, view.strip_rect().end.x - 0.5,
		"der Turm steht rechts der Leiste")
	assert_lte(view.grip_seat_rect().end.x,
		view.size.x - u0 * WorkshopView.CONTENT_MARGIN_X + 0.5,
		"und der Griff bleibt im Rand")

## (4) Der GRIFF behält seinen sichtbaren Platz IM Fenster, neben dem Turm - nie
## unter dem Magazin.
func test_the_grip_keeps_a_visible_seat_above_the_magazine() -> void:
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	var seat := _seat_rect()
	assert_true(view._action_button.visible, "der Knopf steht")
	assert_gt(seat.size.x, 0.0)
	assert_true(view.get_global_rect().encloses(seat), "er liegt IM Fenster")
	assert_lte(seat.end.y, _drawer_rect().position.y + 0.5,
		"und über dem Magazin - nie darunter")
	assert_true(view.bench_rect().encloses(seat), "und in der Weiterleitungs-Region")
