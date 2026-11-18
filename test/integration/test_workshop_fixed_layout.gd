extends GutTest
## Die Werkstatt auf der WALZEN-KETTE (drum_layout): das Fenster steht auf der
## gemeldeten Kette, und nichts darf sich je verschieben. Die Stabilität IST die
## Prüfung - gemessen werden Magazin-Fach, Scheiben und Handlungs-Sitz, danach wird
## die Bank benutzt und jedes Rechteck muss auf denselben Pixeln liegen wie vorher.

## Gemessene Eingaben vom 2026-11-18, 1280 × 720 (siehe test_workshop_drum_layout).
const POOL := Rect2(2916.4, 1994.8, 585.0, 487.5)
const FACH := Rect2(3553.9, 1994.8, 86.3, 86.2)
const CELL := Vector2(16.4, 40.5)
const FACE := 55.46
const U := 5.042
const INFO_H := 149.85
const HUB_BOTTOM := 3127.3

var view: WorkshopView
var run: GameRun
var frame: Dictionary

func before_each() -> void:
	run = GameRun.new_run()
	view = WorkshopView.new()
	add_child_autofree(view)
	view.unit_px = U
	view.data_cell_px = CELL
	view.die_face_px = FACE
	frame = WorkshopView.drum_layout(POOL, FACH, PackDrawerView.lie_cell(CELL), FACE, U,
		INFO_H)
	var bounds: Rect2 = frame["bounds"]
	view.position = bounds.position
	view.size = bounds.size
	view.drum_frame = frame
	view.run = run

func _drawer_rect() -> Rect2:
	return view._drawer.get_global_rect() if view._drawer != null else Rect2()

func _slice_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for slot in view._slot_buttons:
		rects.append(slot.get_global_rect())
	return rects

func _seat_rect() -> Rect2:
	var seat: Control = view.get_node("Street/ActionSeat")
	return seat.get_global_rect()

func _assert_same(before: Array[Rect2], after: Array[Rect2], what: String) -> void:
	assert_eq(after.size(), before.size(), "%s: dieselbe Zahl Scheiben" % what)
	for i in before.size():
		assert_eq(after[i], before[i], "%s: Scheibe %d steht unverrückt" % [what, i + 1])

# --- Die Kette --------------------------------------------------------------------

func test_the_slices_stand_on_the_reported_chain() -> void:
	await wait_frames(2)
	var slices: Array = frame["slices"]
	var rects := _slice_rects()
	assert_eq(rects.size(), view.slot_count(), "je belegbarer Scheibe ein Knopf")
	for i in rects.size():
		assert_true(rects[i].is_equal_approx(slices[i]), "Scheibe %d liegt auf der Kette" % (i + 1))
		if i > 0:
			assert_gt(rects[i].position.y, rects[i - 1].position.y, "Scheibe 1 OBEN")
	assert_eq(view.drum_pit_rect(), frame["pit"], "der Graben ist die Kette")

func test_slot_at_finds_the_slice_under_the_pointer() -> void:
	await wait_frames(2)
	for i in view.slot_count():
		assert_eq(view.slot_at((frame["slices"][i] as Rect2).get_center()), i)
	assert_eq(view.slot_at(POOL.get_center()), -1, "neben der Walze trifft nichts")

func test_the_nets_stand_before_and_after_the_drum() -> void:
	await wait_frames(2)
	var before: Rect2 = frame["before"]
	var after: Rect2 = frame["after"]
	assert_true(view.get_node("Street/BeforeScreen").get_global_rect().is_equal_approx(before),
		"VORHER über Scheibe 1")
	assert_true(view.get_node("Street/AfterScreen").get_global_rect().is_equal_approx(after),
		"NACHHER unter Scheibe 6")
	assert_true(after.encloses(Rect2(view.ist_net_center() - Vector2.ONE, Vector2.ONE * 2.0)),
		"sein Parkplatz liegt darin")

func test_the_magazine_stands_right_of_the_drum_with_two_columns() -> void:
	await wait_frames(2)
	var shelf: Rect2 = frame["shelf"]
	assert_true(_drawer_rect().is_equal_approx(shelf), "genau das Sorten-Rechteck der Kette")
	assert_true(view.shelf_rect_global().is_equal_approx(shelf))
	assert_gt(_drawer_rect().position.x, view.drum_pit_rect().end.x)
	assert_eq(PackDrawerView.columns_for(view.shelf_pit_rect().size, CELL),
		PackDrawerView.COLUMNS, "jede Reihe zeigt COLUMNS Karten")
	var rows: Array = frame["rows"]
	for row in PackDrawerView.ROWS:
		assert_true(view.shelf_row_rect(row).is_equal_approx(rows[row]), "Reihe %d" % row)
		assert_true(view.shelf_pit_rect().encloses(view.shelf_row_rect(row)))
	assert_gt(_drawer_rect().position.y, view.info_rect_px().end.y, "unter dem Info-Schirm")

func test_nothing_reaches_below_the_hub() -> void:
	await wait_frames(2)
	assert_lt(view.bench_rect().end.y, HUB_BOTTOM)
	assert_lt(view.chamber_area_px().end.y, HUB_BOTTOM)

func test_the_chamber_is_a_square_that_takes_the_lying_blank() -> void:
	await wait_frames(2)
	var chamber := view.chamber_rect_px()
	assert_eq(chamber, frame["chamber"])
	assert_almost_eq(chamber.size.x, chamber.size.y, 0.001, "quadratisch")
	var card := PackDrawerView.lie_cell(CELL)
	assert_gt(chamber.size.x, card.x, "der liegende Rohling paßt längs hinein")
	assert_gt(chamber.size.y, card.y, "und quer")
	assert_gt(chamber.position.y, _drawer_rect().end.y, "unter dem Magazin")
	assert_gt(_seat_rect().position.x, chamber.end.x, "der Präge-Sitz rechts daneben")
	assert_true(view.chamber_area_px().encloses(_seat_rect()), "beide zusammen")

func test_the_podium_anchor_is_the_chamber_centre_trimmed_down() -> void:
	await wait_frames(2)
	var centre := view.chamber_rect_px().get_center()
	var anchor := view.target_net_center()
	assert_almost_eq(anchor.x - centre.x, WorkshopView.BENCH_TILT_TRIM_X, 0.01,
		"um den gemessenen Neigungs-Versatz verschoben - quer")
	assert_almost_eq(anchor.y - centre.y, WorkshopView.BENCH_TILT_TRIM, 0.01, "und längs")
	assert_eq(view.blank_seat_center(), centre, "der Rohling liegt in der Kammermitte")

func test_the_hit_rects_cover_column_magazine_and_chamber() -> void:
	await wait_frames(2)
	var hits := view.hit_rects()
	var covered := func(point: Vector2) -> bool:
		for rect in hits:
			if rect.has_point(point):
				return true
		return false
	assert_true(covered.call((frame["slices"][0] as Rect2).get_center()), "die Scheiben")
	assert_true(covered.call(_drawer_rect().get_center()), "das Magazin")
	assert_true(covered.call(_seat_rect().get_center()), "der Präge-Sitz")
	assert_true(covered.call(view.chamber_rect_px().get_center()), "die Kammer")
	assert_true(view.bench_rect().encloses(_drawer_rect()), "bench_rect deckt das Magazin")

func test_the_strip_has_no_window_background() -> void:
	await wait_frames(2)
	assert_true(view.get_theme_stylebox("panel") is StyleBoxEmpty, "das Fenster malt nichts")
	for slot in view._slot_buttons:
		assert_true(slot.get_theme_stylebox("normal") is StyleBoxEmpty,
			"die Scheibe malt nichts - dort ist ohnehin das Loch")

# --- Eine Karte stecken, zurücknehmen, leerlaufen, liefern: nichts wandert ---------

func test_slotting_a_card_moves_nothing_on_the_page() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	var fach := _drawer_rect()
	var slices := _slice_rects()
	var seat := _seat_rect()
	assert_true(view._action_button.visible, "der Knopf steht schon vorher")
	assert_true(view._action_button.disabled, "grau, solange nichts steckt")
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_true(view._action_button.visible, "der Knopf ist da")
	assert_eq(_seat_rect(), seat, "sein Sitz steht")
	assert_eq(_drawer_rect(), fach, "das Fach steht unverrückt")
	_assert_same(slices, _slice_rects(), "gesteckt")

func test_taking_the_card_back_out_moves_nothing_either() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	var fach := _drawer_rect()
	var slices := _slice_rects()
	view.clear_press_slot(0)
	await wait_frames(2)
	assert_true(view._action_button.disabled, "ohne Karte steht er wieder grau")
	assert_eq(_drawer_rect(), fach, "zurückgenommen: das Fach steht")
	_assert_same(slices, _slice_rects(), "zurückgenommen")

func test_a_click_on_a_filled_slice_sends_the_card_home() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	var slot: Button = view._slot_buttons[0]
	assert_false(slot.disabled, "die belegte Scheibe nimmt den Klick")
	assert_true(view._slot_buttons[1].disabled, "die leere nicht")
	slot.pressed.emit()
	await wait_frames(2)
	assert_true(view.press_slot_uids().is_empty(), "die Karte ist zurück im Magazin")

func test_an_emptied_magazine_keeps_its_drawer() -> void:
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	var fach := _drawer_rect()
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_true(view.drawer_entries().is_empty(), "das Magazin ist leer")
	assert_eq(_drawer_rect(), fach, "leergelaufen: das Fach steht weiter")

func test_a_delivery_lands_on_the_standing_anchor() -> void:
	run.grant_pack(Pack.number_pack())
	var uid := run.owned_packs[0].pack_uid
	view.expect_pack_delivery(uid)
	await wait_frames(2)
	var fach := _drawer_rect()
	var anchor := view.pack_anchor_px(uid)
	view.deliver_pack(uid)
	await wait_frames(2)
	assert_not_null(view._drawer.pack_button(uid), "die Ware liegt da")
	assert_eq(_drawer_rect(), fach, "geliefert: das Fach steht")
	assert_eq(view.pack_anchor_px(uid), anchor, "auf demselben Anker wie vorher")

func test_a_cassette_tap_reaches_the_slice_through_the_forward_region() -> void:
	for i in 6:
		run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	var uid := run.owned_packs[0].pack_uid
	var chip := view._drawer.pack_button(uid)
	assert_not_null(chip, "die Kassette hat einen Chip-Knopf")
	var px := chip.get_global_rect().get_center()
	assert_true(TableScreen.window_takes_pixel(view, view.shelf_rect_global(), px, true,
		false), "der Klick auf die Kassette wird an das Fenster weitergereicht")
	chip.pressed.emit()
	await wait_frames(2)
	assert_eq(view.press_slot_uids(), [uid] as Array[int], "sie liegt auf Scheibe 1")

func test_the_pit_hangs_on_the_standing_drawer_rect() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.material_pack())
	await wait_frames(2)
	var pit := view.shelf_pit_rect()
	assert_true(_drawer_rect().encloses(pit), "das Loch liegt IM Fach")
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_eq(view.shelf_pit_rect(), pit, "gesteckt: die Grube steht")

# --- Der Sitz ---------------------------------------------------------------------

func test_the_seat_still_carries_its_widest_label() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	var button := view._action_button
	var font: Font = button.get_theme_font("font")
	var px: int = button.get_theme_font_size("font_size")
	var text := font.get_string_size("Verdichten 6/6", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	assert_lte(text + U * 1.2, _seat_rect().size.x,
		"die breiteste Aufschrift paßt samt Rand in den Sitz")

func test_the_seat_rect_is_byte_stable_through_the_cycle() -> void:
	await wait_frames(2)
	var seat := _seat_rect()
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	assert_eq(_seat_rect(), seat, "eine Kassette im Magazin")
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_eq(_seat_rect(), seat, "gesteckt")
	assert_eq(view._action_button.text, "Prägen 1/%d" % run.series_slots(),
		"nur die Aufschrift zählt mit")
	view.choose_target(0)
	await wait_frames(2)
	assert_eq(_seat_rect(), seat, "mit gewähltem Ziel")

# --- Die Netze --------------------------------------------------------------------

func test_every_net_shares_the_card_net_cell() -> void:
	view.choose_target(0)
	await wait_frames(2)
	var card := WorkshopView.card_net_cell(view.shelf_cell_px())
	assert_almost_eq(view.net_cell(U), card, 0.001, "das Zellmaß der Werkstatt")
	assert_almost_eq(view._net.cell, card, 0.001, "NACHHER ist eine Kartenzelle")
	assert_almost_eq(view._before_net.cell, card, 0.001, "VORHER auch")
	assert_lte(DieNetView.net_size(card).x, (frame["after"] as Rect2).size.x,
		"und es paßt in NACHHER")

func test_without_a_target_before_is_the_empty_cross() -> void:
	await wait_frames(2)
	assert_null(view.target_die(), "kein Ziel gewählt")
	assert_null(view._before_net, "VORHER zeigt keinen Würfel")
	var cross: Control = view._before_host.get_child(0)
	assert_eq(cross.name, "EmptyNet", "sondern das leere Kreuz")
	assert_eq(cross.get_child_count(), 6, "sechs leere Zellen")
	view.choose_target(0)
	await wait_frames(2)
	assert_eq(view._before_net.def, view.target_die(), "mit Ziel steht der Würfel da")
	assert_true(view._before_net.projection.is_empty(), "schlicht, ohne Vorschau")

func test_the_net_lives_in_the_window() -> void:
	await wait_frames(2)
	assert_eq(view._net.get_parent(), view, "das NACHHER-Netz hängt im Fenster")
	assert_false("net_pane" in view, "die Glas-Scheibe ist gestorben")

## Ohne gemeldete Kette (kopflos) rechnet das Fenster sie selbst ab dem Ursprung.
func test_without_a_reported_chain_the_window_still_lays_out() -> void:
	var bare := WorkshopView.new()
	add_child_autofree(bare)
	bare.run = run
	await wait_frames(2)
	assert_eq(bare._slot_buttons.size(), bare.slot_count())
	assert_gt(bare.slice_rect(5).position.y, bare.slice_rect(0).position.y)
