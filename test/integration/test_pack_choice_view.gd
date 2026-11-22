extends GutTest
## Die Paket-Auswahl in der ÖFFNUNGS-ZONE: Karten- und Würfel-Pakete stehen als EIN Schirm
## (Kopf, Aufstellung zu höchstens drei je Reihe, Auskunft, Knöpfe) - nichts hängt darunter.

const DIE_PX := Vector2(45, 45)
## Die Würfelkante am echten Tisch (Display-px).
const DIE_EDGE := 57.4
## Gemessen 1280 × 720 (Layout C): Pool-Reihe, die Naht darunter und die liegende Karte.
const POOL := Rect2(2916.358, 1994.776, 585.0, 487.5)
const SEAM := 48.75
const CARD := Vector2(194.4, 129.6)
const OPENING_POS := Vector2(3882.17, 1994.776)
const OPENING_SIZE := Vector2(646.6, 487.5)
## Die ZONE (gemessen 1300,4 × 487,5).
const ZONE := Rect2(3521.527, 1994.776, 1300.437, 487.5)

func _open_pack(run: GameRun, pack: Resource) -> PackChoice:
	if pack is DicePack:
		return run.purchase_dice_pack(pack as DicePack, 1)
	return run.purchase_card_pack(pack as CardPack, 1)

func _dice_choice(count: int) -> PackChoice:
	var run := GameRun.new_run()
	run.money = 999
	var choice := _open_pack(run, DicePack.make(DicePack.SORT_NORMAL, 6))
	var base: Array = choice.options.duplicate()
	choice.options.clear()
	for i in count:
		choice.options.append((base[i % base.size()] as DieDefinition).instantiate())
	return choice

func _card_choice() -> PackChoice:
	var run := GameRun.new_run()
	run.money = 999
	return _open_pack(run, CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_LARGE))

func _card_choice_of(count: int) -> PackChoice:
	var choice := _card_choice()
	var base: Array = choice.options.duplicate()
	choice.options.clear()
	for i in count:
		choice.options.append(base[i % base.size()])
	return choice

func _view() -> PackChoiceView:
	var view := PackChoiceView.new()
	add_child_autofree(view)
	view.position = Vector2(40, 30)
	view.size = Vector2(1040, 530)
	return view

func _opening() -> PackChoiceView:
	var view := _view()
	view.position = OPENING_POS
	view.size = OPENING_SIZE
	return view

## Das Fenster IST die Zone - so stellt scene_root es für jede Art.
func _zone_view() -> PackChoiceView:
	var view := _view()
	view.position = ZONE.position
	view.size = ZONE.size
	return view

func _dice(view: PackChoiceView, count: int) -> PackChoice:
	var choice := _dice_choice(count)
	view.open(choice, DIE_PX, 1, 5, false, 2)
	return choice

# --- Würfel im SCHIRM -------------------------------------------------------------

## Karten und Würfel teilen EINE Feld-Rechnung: Kopf oben, Aufstellung, Auskunft, Knöpfe -
## alles im Fenster, nichts darunter.
func test_dice_and_cards_share_the_frame_rects() -> void:
	var dice := _zone_view()
	_dice(dice, 5)
	var cards := _zone_view()
	cards.open(_card_choice(), CARD, 1, 5)
	var a: Dictionary = dice._frame_rects()
	var b: Dictionary = cards._frame_rects()
	for key in ["head", "info", "buttons"]:
		assert_eq(a[key], b[key], "%s an derselben Stelle" % key)
	assert_eq(dice.lineup_area(), cards.lineup_area(), "dieselbe Aufstellung")
	var bounds := Rect2(Vector2.ZERO, dice.size).grow(0.01)
	var stack: Array[Rect2] = [a["head"], dice.lineup_area(), a["info"], a["buttons"]]
	for i in stack.size():
		assert_true(bounds.encloses(stack[i]), "Feld %d im Fenster" % i)
		if i > 0:
			assert_lte(stack[i - 1].end.y, stack[i].position.y + 0.5, "Felder untereinander")
	assert_true(dice._title.visible, "der Name steht im Kopf")
	assert_true(dice._counter.visible, "der Zähler steht im Kopf")
	var take := Rect2(dice._take_button.position, dice._take_button.size)
	assert_true((a["buttons"] as Rect2).grow(0.01).encloses(take), "der Knopf in der Knopfzeile %s in %s" % [take, a["buttons"]])

## Höchstens drei Kacheln je Reihe, zwei Reihen, der Block mittig - wie die Karten.
func test_dice_tiles_stand_in_rows_of_three() -> void:
	for count in range(2, 7):
		var view := _zone_view()
		_dice(view, count)
		var area := view.lineup_area().grow(0.01)
		var taken: Array[Rect2] = []
		var columns := view.per_row(count)
		assert_lte(columns, 3, "%d Würfel: höchstens drei je Reihe" % count)
		for i in count:
			var block := view.lineup_block(i, count)
			var die := view.slot_rect(i, count)
			var net := view.net_rect(i, count)
			for rect: Rect2 in [block, die, net]:
				assert_true(area.encloses(rect), "%d/%d: in der Aufstellung" % [i, count])
			assert_true(block.grow(0.01).encloses(net), "das Netz steht in seiner Kachel")
			assert_true(block.grow(0.01).encloses(die), "der Würfel liest in seiner Kachel")
			assert_gte(net.position.x, die.end.x, "der Würfel liest links neben seinem Netz")
			for other in taken:
				assert_false(other.intersects(block.grow(-0.5)), "Kacheln überlappen nicht")
			taken.append(block)
		var first := view.lineup_block(0, count)
		var last := view.lineup_block(count - 1, count)
		var middle := (first.position.y + last.end.y) * 0.5
		assert_almost_eq(middle, view.lineup_area().get_center().y, 0.5, "der Block steht mittig")
		assert_gte(view.net_cell(count), 30.0, "lesbare Zellen (%d Würfel)" % count)
	var six := _zone_view()
	_dice(six, 6)
	assert_almost_eq(six.lineup_block(3, 6).position.x, six.lineup_block(0, 6).position.x, 0.01,
		"6 = 3 + 3")
	assert_gt(six.lineup_block(3, 6).position.y, six.lineup_block(0, 6).end.y)

## Die Plätze stehen in Display-Pixeln in der Zone, der Sitz tiefer als die Bandmitte.
func test_dice_report_their_places_in_display_pixels() -> void:
	var view := _zone_view()
	_dice(view, 6)
	var centers := view.slot_centers()
	assert_eq(centers.size(), 6)
	for i in 6:
		var local := view.slot_rect(i, 6).get_center()
		assert_almost_eq(centers[i].x, view.position.x + local.x, 0.01)
		assert_almost_eq(centers[i].y - view.position.y - local.y,
			DIE_PX.y * PackChoiceView.DIE_SEAT_DROP, 0.01, "der Sitz liegt tiefer")
		assert_true(ZONE.has_point(centers[i]), "Platz %d liegt in der Zone" % i)

func test_the_nets_open_with_the_lineup() -> void:
	var view := _zone_view()
	_dice(view, 4)
	for i in 4:
		assert_false(view.net_shown(i), "beim Fall steht kein Netz")
	view.show_lineup()
	for i in 4:
		assert_true(view.net_shown(i), "in der Aufstellung steht jedes Netz sofort")
	view.skip_to_pick()
	assert_true(view.choosing())

func test_the_launch_shows_no_slots_and_no_counter() -> void:
	var view := _zone_view()
	_dice(view, 5)
	assert_eq(view.stage(), PackChoiceView.STAGE_LAUNCH)
	assert_false(view.slots_shown(), "beim Fall zählt niemand mit")
	assert_false(view.choosing())
	assert_eq(view._counter.text, "", "keine Zahl vor dem Wurf")
	view.show_lineup()
	assert_true(view.slots_shown(), "die Aufstellung zeigt ihre Plätze")
	view.skip_to_pick()
	for i in 5:
		assert_eq(view.slot_rim(i), PackChoiceView.SLOT_RIM, "ein Würfel trägt einen neutralen Saum")

## Der Glückswürfel rollt (scene_root), und erst sein Stillstand nennt die Wahlen.
func test_the_opening_waits_for_the_luck_die_then_picks() -> void:
	var view := _zone_view()
	var choice := _dice_choice(4)
	choice.picks = 2
	view.open(choice, DIE_PX, 1, 5, false, 2)
	var events: Array = []
	view.opening_finished.connect(func() -> void: events.append("done"))
	view.show_lineup()
	view.await_roll()
	assert_eq(view.stage(), PackChoiceView.STAGE_ROLL, "es geht direkt zum Wurf")
	assert_true(view.awaiting_roll())
	assert_false(view.choosing(), "vor dem Stillstand keine Wahl")
	var label := view._counter
	assert_eq(label.text, "", "noch keine Zahl")
	view.die_landed()
	assert_eq(events, ["done"])
	assert_eq(view.stage(), PackChoiceView.STAGE_PICK)
	assert_eq(label.text, "Wähle 2 von 4", "der Zähler nennt die Wahlen")
	assert_true(view.choosing())
	view.die_landed()
	assert_eq(events, ["done"], "idempotent")

func test_cards_wait_for_the_luck_die_and_a_click_asks_to_skip() -> void:
	var view := _opening()
	var choice := _card_choice()
	view.open(choice, CARD, 1, 5)
	var asked: Array = []
	view.roll_skip_requested.connect(func() -> void: asked.append(true))
	view.await_roll()
	assert_true(view.awaiting_roll())
	assert_eq(view._counter.text, "")
	view.skip_count()
	assert_eq(asked.size(), 1, "der Klick bittet scene_root, den Würfel liegen zu lassen")
	assert_false(view.choosing())
	view.die_landed()
	assert_true(view.choosing())
	assert_eq(view._counter.text, view.counter_text())

func test_free_hand_names_itself_in_the_counter() -> void:
	var view := _opening()
	var choice := _card_choice()
	choice.free_bonus = 1
	choice.picks = 2
	view.open(choice, CARD, 1, 5, true)
	assert_string_contains(view.counter_text(), "Freie Hand +1")

func test_a_net_cell_names_its_face() -> void:
	var view := _zone_view()
	_dice(view, 3)
	var net := view.net_rect(0, 3)
	var cell := view.net_cell(3)
	# Die mittlere Zelle der Mittelreihe ist eine Würfelseite.
	var inside := net.position + Vector2(cell * 1.5 * (1.0 + DieNetView.GAP_FACTOR),
		cell * 1.5 * (1.0 + DieNetView.GAP_FACTOR))
	assert_eq(view.net_face_at(0, inside), PackChoiceView.NO_FACE, "verdeckt sagt es nichts")
	view.reveal_net(0)
	assert_gte(view.net_face_at(0, inside), 0, "gelandet nennt die Zelle ihre Seite")
	assert_eq(view.net_face_at(0, net.end + Vector2(5, 5)), PackChoiceView.NO_FACE)

# --- Karten auf der Öffnungs-Fläche ------------------------------------------------

func test_card_choice_keeps_its_layout() -> void:
	var choice := _card_choice()
	var view := _view()
	view.open(choice, Vector2(60, 90), 1, 5)
	assert_false(view.lineup())
	var count := choice.option_count()
	for i in count:
		assert_true(Rect2(Vector2.ZERO, view.size).encloses(view.slot_rect(i, count)))
		assert_false(view.net_shown(i), "Karten tragen kein Würfelnetz")

## Der Zeiger über einer Karten-Option nennt das die Magazin-Spalte ihrer Sorte; Würfel
## und Leerstellen nennen keines.
func test_a_card_option_names_its_shelf_column() -> void:
	var choice := _card_choice()
	var view := _view()
	view.open(choice, Vector2(60, 90), 1, 5)
	for i in choice.option_count():
		assert_eq(view.option_shelf_column(i), Pack.shelf_rank(choice.options[i] as Pack))
	assert_eq(view.option_shelf_column(-1), -1)
	assert_eq(view.option_shelf_column(choice.option_count()), -1)
	var dice := _zone_view()
	_dice(dice, 3)
	assert_eq(dice.option_shelf_column(0), -1)

## Kopf, Aufstellung, Auskunft und Knöpfe stehen untereinander auf der Fläche.
func test_cards_on_the_opening_stack_their_fields() -> void:
	var choice := _card_choice()
	var view := _opening()
	view.open(choice, Vector2(194, 130), 1, 5)
	var area := view.lineup_area()
	for i in choice.option_count():
		var slot := view.slot_rect(i, choice.option_count())
		assert_true(area.encloses(slot), "Karte %d liegt in der Aufstellung" % i)
	var frame: Dictionary = view._frame_rects()
	var bounds := Rect2(Vector2.ZERO, view.size)
	var stack: Array[Rect2] = [frame["head"], area, frame["info"], frame["buttons"]]
	for i in stack.size():
		assert_true(bounds.encloses(stack[i]), "Feld %d auf der Fläche" % i)
		if i > 0:
			assert_lte(stack[i - 1].end.y, stack[i].position.y + 0.5,
				"Felder %d/%d untereinander" % [i - 1, i])
	assert_true((frame["head"] as Rect2).encloses(frame["energy"]), "die Energie steht im Kopf")
	assert_eq(view.page_rect_px().position, OPENING_POS)
	assert_true(view.page_rect_px().has_point(view.hull_seat_px()), "die Hülle geht auf der Fläche auf")

## Die ZONE an der echten Kette (1280 × 720, Layout C).
func _zone() -> Dictionary:
	var lay := WorkshopView.drum_layout(POOL, CARD, 55.46, 5.042, 0.0, SEAM)
	var equation: Rect2 = lay["equation"]
	var width := maxf(PackChoiceView.panel_width_for(POOL.size.y, DIE_EDGE), equation.size.x)
	var end_x := equation.position.x + width
	return {"lay": lay, "end_x": end_x,
		"area": PackChoiceView.area_beside(POOL, lay["equation"], end_x)}

## Die reine Regel: die Zone beginnt mit der Gleichung, oben bündig mit der Pool-Reihe und
## so hoch wie sie, und endet bei end_x.
func test_the_zone_rule_starts_at_the_equation() -> void:
	var equation := Rect2(3521.5, 1994.776, 968.2, 458.3)
	var area := PackChoiceView.area_beside(POOL, equation, 4822.0)
	assert_almost_eq(area.position.x, equation.position.x, 0.01, "links ab der Gleichung")
	assert_almost_eq(area.position.y, POOL.position.y, 0.01, "oben bündig mit dem Pool")
	assert_almost_eq(area.size.y, POOL.size.y, 0.01, "so hoch wie er")
	assert_almost_eq(area.end.x, 4822.0, 0.01, "rechts bis end_x")
	assert_eq(PackChoiceView.area_beside(Rect2(), equation, 4822.0), Rect2(), "ohne Pool keine Zone")
	assert_eq(PackChoiceView.area_beside(POOL, equation, equation.position.x), Rect2(),
		"ohne Breite keine Zone")

## An der echten Kette deckt die Zone die GANZE Gleichung, bleibt aber neben Pool, Walze und
## Info-Schirm; ihr rechter Rand ist der der alten Fläche neben dem Podest.
func test_the_zone_covers_the_whole_equation() -> void:
	var zone := _zone()
	var lay: Dictionary = zone["lay"]
	var area: Rect2 = zone["area"]
	assert_almost_eq(area.position.x, POOL.end.x + 5.042 * WorkshopView.DRUM_SHELF_GAP, 0.01,
		"eine Fuge rechts vom Pool")
	for key in ["upgrades", "podium_stage", "podium_net", "result", "stamp"]:
		assert_true(area.encloses(lay[key]), "die Zone deckt %s" % key)
	assert_false(area.intersects(POOL), "nicht über dem Pool")
	assert_false(area.intersects(lay["bounds"]), "nicht über Walze, Info-Schirm und Magazin")
	assert_lte(area.end.x, 5094.0, "innerhalb der Anzeige")
	assert_gte(area.size.x, PackChoiceView.cards_width_for(POOL.size.y, CARD, 3),
		"drei Karten passen nebeneinander")

## Die Zone ist genau so breit wie die Würfel-Auswahl: drei Kacheln füllen die Aufstellung.
func test_the_zone_is_as_wide_as_the_dice_selection() -> void:
	var width := PackChoiceView.panel_width_for(POOL.size.y, DIE_EDGE)
	var view := _view()
	view.size = Vector2(width, POOL.size.y)
	view.open(_dice_choice(6), Vector2.ONE * DIE_EDGE, -1, 0, true)
	await wait_frames(2)
	var first := view.lineup_block(0, 6)
	var third := view.lineup_block(2, 6)
	var area := view.lineup_area()
	assert_almost_eq(first.position.x, area.position.x, 1.0, "links bündig")
	assert_almost_eq(third.end.x, area.end.x, 1.0, "rechts bündig")

## EIN Fußabdruck: das Würfel-Fenster ist die Zone, und nichts davon reicht darunter.
func test_a_dice_panel_stays_inside_the_zone() -> void:
	var view := _zone_view()
	_dice(view, 6)
	assert_true(view.page_rect_px().is_equal_approx(ZONE), "das Fenster ist die Zone")
	var bounds := Rect2(Vector2.ZERO, view.size).grow(0.01)
	for child in view.get_children():
		var item := child as Control
		if item == null or not item.visible:
			continue
		assert_true(bounds.encloses(Rect2(item.position, item.size)),
			"%s bleibt in der Zone" % item.name)

## Zwei Reihen zu drei: 5 = 3 + 2, 6 = 3 + 3, die Karte schrumpft nie.
func test_cards_stand_in_two_rows_of_three() -> void:
	for count in [5, 6]:
		var choice := _card_choice_of(count)
		var view := _zone_view()
		view.open(choice, CARD, 1, 5)
		assert_eq(view.per_row(count), 3, "%d Karten: drei je Reihe" % count)
		var lineup := view.lineup_area()
		for i in count:
			var slot := view.slot_rect(i, count)
			assert_true(lineup.encloses(slot), "Karte %d in der Aufstellung" % i)
			assert_almost_eq(slot.size.x, CARD.x * PackChoiceView.SLOT_ROOM, 0.01,
				"die Karte schrumpft nie")
		assert_gt(view.slot_rect(3, count).position.y, view.slot_rect(0, count).end.y,
			"die vierte steht in Reihe zwei")
		var top := view.slot_rect(0, count).position.y
		var bottom := view.slot_rect(count - 1, count).end.y
		assert_almost_eq((top + bottom) * 0.5, lineup.get_center().y, 0.5, "der Block mittig")

## Fünf liegende Karten stehen 3 + 2 ganz in der Aufstellung, der Kopf ist EINE Zeile.
func test_five_cards_stand_three_and_two_under_a_one_line_head() -> void:
	var choice := _card_choice()
	var view := _opening()
	view.open(choice, CARD, 1, 5)
	assert_eq(choice.option_count(), 5)
	assert_eq(view.per_row(5), 3, "drei nebeneinander")
	var area := view.lineup_area()
	for i in 5:
		assert_true(area.encloses(view.slot_rect(i, 5)), "Karte %d in der Aufstellung" % i)
	assert_gt(view.slot_rect(3, 5).position.y, view.slot_rect(0, 5).end.y, "zwei in Reihe zwei")
func test_the_page_names_the_energy_for_the_reshuffle() -> void:
	var view := _view()
	view.open(_card_choice(), Vector2(194, 130), 2, 7)
	assert_eq(view.energy_text(), "Energie ⚡ 7")
	var label := view.get_node("Energy") as Label
	assert_eq(label.text, view.energy_text())
	assert_true(label.visible)

func test_a_dice_pack_has_no_reshuffle() -> void:
	var view := _zone_view()
	view.open(_dice_choice(3), DIE_PX, -1, 7, false, 2)
	assert_false((view.get_node("Energy") as Label).visible)
	assert_false(view._reshuffle_button.visible)

# --- ZUORDNEN: beim Würfel-Paket ist Wählen Einsetzen -------------------------------

func _picking(count: int, picks: int) -> PackChoiceView:
	var view := _zone_view()
	var choice := _dice_choice(count)
	choice.picks = picks
	view.open(choice, DIE_PX, 1, 5, false, 2)
	view.show_lineup()
	view.skip_to_pick()
	return view

func test_a_dice_pack_assigns_instead_of_picking() -> void:
	var view := _picking(5, 2)
	assert_true(view.assigning(), "Würfel-Pakete ordnen zu")
	assert_eq(view._counter.text, "Wähle 2 von 5",
		"der Zähler im Kopf nennt die Wahlen")
	assert_eq(view._take_button.text, "Nichts nehmen")
	assert_true(view.assign(1, 3, "Platz 4"))
	assert_eq(view.assignments(), {1: 3})
	assert_eq(view.assignment_of(1), 3)
	assert_eq(view.assignment_label(1), "Platz 4")
	assert_eq(view._take_button.text, "Einsetzen (1)")
	var mark := view.get_node("Mark1") as Label
	assert_true(mark.visible, "die Option nennt ihren Platz")
	assert_eq(mark.text, "→ Platz 4")
	assert_false((view.get_node("Mark0") as Label).visible)
	assert_string_contains(view._info.text, "1 von 2 eingesetzt")
	var button := Rect2(view._take_button.position, view._take_button.size)
	assert_true(Rect2(Vector2.ZERO, view.size).grow(0.01).encloses(button), "der Knopf im Fenster")
	assert_gte(button.position.y, view.lineup_area().end.y, "der Knopf unter der Aufstellung")

func test_cards_do_not_assign() -> void:
	var view := _opening()
	view.open(_card_choice(), Vector2(194, 130), 1, 5)
	assert_false(view.assigning())
	assert_false(view.assign(0, 0, "Platz 1"))

func test_assignments_stay_within_the_picks_one_per_seat() -> void:
	var view := _picking(5, 2)
	assert_true(view.assign(0, 1, "Platz 2"))
	assert_true(view.assign(1, 2, "Platz 3"))
	assert_false(view.assign(2, 4, "Platz 5"), "mehr als K gibt es nicht")
	assert_eq(view.assigned_count(), 2)
	# Ein belegter Platz schickt seine Option zurück in die Aufstellung.
	assert_true(view.assign(2, 1, "Platz 2"))
	assert_eq(view.assignments(), {1: 2, 2: 1})
	assert_eq(view.option_on_seat(1), 2)
	assert_eq(view.assignment_of(0), -1)
	# Eine schon eingesetzte Option wechselt den Platz, ohne zu zählen.
	assert_true(view.assign(1, 4, "Platz 5"))
	assert_eq(view.assignments(), {1: 4, 2: 1})
	view.unassign(2)
	assert_eq(view.assignments(), {1: 4})

func test_a_tap_arms_and_an_assignment_disarms() -> void:
	var view := _picking(4, 2)
	view.arm(2)
	assert_eq(view.armed_index(), 2, "getippt wählt aus")
	view.arm(2)
	assert_eq(view.armed_index(), -1, "derselbe Tipp wählt ab")
	view.arm(3)
	assert_true(view.assign(3, 0, "Platz 1"))
	assert_eq(view.armed_index(), -1, "eingesetzt ist nicht mehr ausgewählt")

func test_confirm_reports_the_assigned_options() -> void:
	var view := _picking(5, 3)
	var got: Array = []
	view.confirmed.connect(func(indices: Array) -> void: got.append(indices))
	view.assign(3, 0, "Platz 1")
	view.assign(1, 2, "Platz 3")
	view._on_take_pressed()
	assert_eq(got.size(), 1)
	assert_eq(got[0], [1, 3], "gemeldet wird der Entwurf, sortiert")

func test_the_draft_books_through_game_run() -> void:
	var run := GameRun.new_run()
	run.money = 999
	var choice := run.purchase_dice_pack(DicePack.make(DicePack.SORT_NORMAL, 6), 1)
	var view := _zone_view()
	view.open(choice, DIE_PX, 1, 5, false, 2)
	view.skip_to_pick()
	var target := run.owned_pool[2]
	var option := choice.options[0] as DieDefinition
	assert_true(view.assign(0, 2, "Platz 3"))
	var booked := run.confirm_dice_choice(choice, view.assignments())
	assert_eq(booked.size(), 1)
	assert_same(run.owned_pool[2], target, "become schreibt in dieselbe Instanz")
	assert_eq(run.owned_pool[2].faces, option.faces)
	assert_false(run.pending_pack_choices.has(choice))
	assert_true(run.pending_dice.is_empty(), "Paket-Würfel gehen nicht durch das Ausgabefach")

func test_a_reopen_drops_the_draft() -> void:
	var view := _picking(4, 2)
	view.assign(0, 1, "Platz 2")
	view.arm(2)
	view.open(view.choice, DIE_PX, 1, 5, false, 2)
	assert_true(view.assignments().is_empty(), "ein Neuaufbau verwirft den Entwurf")
	assert_eq(view.armed_index(), -1)

func test_an_option_is_found_under_its_block() -> void:
	var view := _picking(5, 2)
	await wait_process_frames(1)
	for i in 5:
		var block := view.lineup_block(i, 5)
		assert_eq(view.option_at_px(view.global_position + block.get_center()), i)
	assert_eq(view.option_at_px(view.global_position + Vector2(1, view.size.y - 1)), -1,
		"im Fuß liegt keine Option")
