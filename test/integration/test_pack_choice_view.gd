extends GutTest
## Die Paket-Auswahl: bei Würfel-Paketen steht die Schatulle oben, darunter die
## AUFSTELLUNG - je Würfel sein Platz und sein Netz; Karten-Pakete bleiben, wie sie sind.

const CASE_PX := Vector2(200, 134)
const DIE_PX := Vector2(45, 45)

func _dice_choice(count: int) -> PackChoice:
	var run := GameRun.new_run()
	run.money = 999
	var choice := run.purchase_dice_pack(DicePack.make(DicePack.SORT_MIXED, CardPack.SIZE_HUGE), 1)
	var base: Array = choice.options.duplicate()
	choice.options.clear()
	for i in count:
		choice.options.append((base[i % base.size()] as DieDefinition).instantiate())
	return choice

func _card_choice() -> PackChoice:
	var run := GameRun.new_run()
	run.money = 999
	return run.purchase_card_pack(CardPack.make(CardPack.SORT_MIXED, CardPack.SIZE_LARGE), 1)

func _view() -> PackChoiceView:
	var view := PackChoiceView.new()
	add_child_autofree(view)
	view.position = Vector2(40, 30)
	view.size = Vector2(1040, 530)
	return view

func test_up_to_ten_dice_line_up_with_their_nets_inside_the_pit() -> void:
	for count in [1, 3, 5, 6, 8, 10]:
		var view := _view()
		view.open(_dice_choice(count), DIE_PX, 1, 5, false, CASE_PX, 2)
		assert_true(view.lineup())
		var bounds := Rect2(Vector2.ZERO, view.size)
		var case_rect := view.case_rect_local()
		assert_true(bounds.encloses(case_rect), "die Schatulle steht in der Grube")
		var taken: Array[Rect2] = [case_rect]
		for i in count:
			var die := view.slot_rect(i, count)
			var net := view.net_rect(i, count)
			assert_true(bounds.encloses(die), "%d/%d: Platz in der Grube" % [i, count])
			assert_true(bounds.encloses(net), "%d/%d: Netz in der Grube" % [i, count])
			assert_gte(net.position.y, die.end.y, "das Netz steht unter seinem Würfel")
			for other in taken:
				assert_false(other.intersects(die.grow(-0.5)), "Plätze überlappen nicht")
				assert_false(other.intersects(net.grow(-0.5)), "Netze überlappen nicht")
			taken.append(die)
			taken.append(net)
		assert_gte(view.net_cell(count), 14.0, "die Zellen bleiben lesbar (%d Würfel)" % count)

func test_a_net_appears_when_its_die_lands() -> void:
	var view := _view()
	view.open(_dice_choice(4), DIE_PX, 1, 5, false, CASE_PX, 2)
	for i in 4:
		assert_false(view.net_shown(i), "vor der Landung steht kein Netz")
	view.reveal_net(2)
	assert_true(view.net_shown(2))
	assert_false(view.net_shown(1))
	view.reveal_all_nets()
	for i in 4:
		assert_true(view.net_shown(i))

func test_a_net_cell_names_its_face() -> void:
	var view := _view()
	view.open(_dice_choice(3), DIE_PX, 1, 5, false, CASE_PX, 2)
	var net := view.net_rect(0, 3)
	var cell := view.net_cell(3)
	# Die mittlere Zelle der Mittelreihe ist eine Würfelseite.
	var inside := net.position + Vector2(cell * 1.5 * (1.0 + DieNetView.GAP_FACTOR),
		cell * 1.5 * (1.0 + DieNetView.GAP_FACTOR))
	assert_eq(view.net_face_at(0, inside), PackChoiceView.NO_FACE, "verdeckt sagt es nichts")
	view.reveal_net(0)
	assert_gte(view.net_face_at(0, inside), 0, "gelandet nennt die Zelle ihre Seite")
	assert_eq(view.net_face_at(0, net.end + Vector2(5, 5)), PackChoiceView.NO_FACE)

func test_the_case_seat_is_reported_in_display_pixels() -> void:
	var view := _view()
	view.open(_dice_choice(5), DIE_PX, 1, 5, false, CASE_PX, 2)
	assert_eq(view.case_seat_px(), view.position + view.case_rect_local().get_center())
	assert_lt(view.case_rect_local().position.y, view.lineup_area().position.y,
		"die Schatulle steht über der Aufstellung")

func test_card_choice_keeps_its_layout() -> void:
	var choice := _card_choice()
	var view := _view()
	view.open(choice, Vector2(60, 90), 1, 5)
	assert_false(view.lineup())
	var count := choice.option_count()
	for i in count:
		assert_true(Rect2(Vector2.ZERO, view.size).encloses(view.slot_rect(i, count)))
		assert_false(view.net_shown(i), "Karten tragen kein Würfelnetz")
