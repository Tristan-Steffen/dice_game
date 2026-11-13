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
	for count in range(1, 11):
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

func test_the_lineup_is_one_row_up_to_six_and_two_rows_up_to_ten() -> void:
	for count in range(1, 11):
		var grid := PackChoiceView.lineup_grid(count)
		assert_eq(grid.y, 1 if count <= 6 else 2, "Reihen bei %d Würfeln" % count)
		assert_gte(grid.x * grid.y, count)
	assert_eq(PackChoiceView.lineup_grid(99).x * PackChoiceView.lineup_grid(99).y, 10, "nie mehr als 10")

func test_a_net_appears_when_its_quality_locks() -> void:
	var view := _view()
	view.open(_dice_choice(4), DIE_PX, 1, 5, false, CASE_PX, 2)
	for i in 4:
		assert_false(view.net_shown(i), "vor der Enthüllung steht kein Netz")
		assert_false(view.quality_shown(i))
	view.show_lineup()
	view.skip_to_pick()
	for i in 4:
		assert_true(view.net_shown(i))
		assert_true(view.quality_shown(i))
	assert_true(view.choosing())

func test_the_launch_shows_no_slots_and_no_counter() -> void:
	var view := _view()
	var choice := _dice_choice(5)
	view.open(choice, DIE_PX, 1, 5, false, CASE_PX, 2)
	assert_eq(view.stage(), PackChoiceView.STAGE_LAUNCH)
	assert_false(view.slots_shown(), "beim Auswurf zählt niemand mit")
	assert_false(view.choosing())
	assert_false(view.reel_shown(), "die Walze wartet")
	view.show_lineup()
	assert_true(view.slots_shown(), "die Aufstellung zeigt ihre Plätze")
	for i in 5:
		assert_eq(view.slot_rim(i), PackChoiceView.SLOT_RIM, "ohne Güte ein neutraler Saum")

func test_every_slot_keeps_a_rim_in_its_quality() -> void:
	var view := _view()
	var choice := _dice_choice(3)
	choice.qualities.assign([DicePack.QUALITY_STANDARD, DicePack.QUALITY_ROYAL,
		DicePack.QUALITY_FINE])
	view.open(choice, DIE_PX, 1, 5, false, CASE_PX, 2)
	view.show_lineup()
	view.skip_to_pick()
	for i in 3:
		assert_eq(view.slot_rim(i), DicePack.quality_tint(choice.quality_of(i)))

func test_the_reveal_steps_lock_on_the_die_quality() -> void:
	for floor_q in DicePack.QUALITIES:
		for quality in range(floor_q, DicePack.QUALITY_ROYAL + 1):
			var steps := PackChoiceView.reveal_steps(quality, floor_q)
			assert_eq(steps[steps.size() - 1], quality, "sie rastet auf seiner Güte ein")
			for tier in steps:
				assert_gte(tier, floor_q, "nie unter der Paket-Güte")
	assert_gt(PackChoiceView.reveal_steps(DicePack.QUALITY_STANDARD, 0).size(), 1,
		"die Anzeige läuft durch die Stufen")

func test_the_reel_spins_up_to_count_minus_one_and_stops_on_the_booked_picks() -> void:
	for count in [2, 3, 5, 10]:
		assert_eq(PackChoiceView.reel_top(count), count - 1)
		var top: int = count - 1
		for base in range(1, top + 1):
			for picks in range(base, top + 1):
				var path := PackChoiceView.reel_path(base, picks, top)
				assert_eq(path[path.size() - 1], picks, "Halt auf der gebuchten Zahl")
				for value in path:
					assert_between(value, base, top, "die Walze zeigt nur mögliche Zahlen")
				assert_gte(path.size(), PackChoiceView.REEL_MIN_SPINS)
	assert_lt(PackChoiceView.reel_beat(0, 12), PackChoiceView.reel_beat(11, 12),
		"die Walze wird langsamer")

func test_the_opening_runs_reveal_then_reel_then_pick() -> void:
	var view := _view()
	var choice := _dice_choice(4)
	choice.qualities.assign([0, 0, 1, 0])
	choice.base_picks = 1
	choice.picks = 2
	view.open(choice, DIE_PX, 1, 5, false, CASE_PX, 2)
	assert_false(view.reel_shown(), "die Walze steht erst nach der Enthüllung")
	var events: Array = []
	view.quality_locked.connect(func(i: int, q: int, climbed: bool) -> void:
		events.append(["lock", i, q, climbed]))
	view.reel_stopped.connect(func(value: int, _top: int) -> void: events.append(["stop", value]))
	view.opening_finished.connect(func() -> void: events.append(["done"]))
	view.show_lineup()
	view.play_reveal()
	assert_false(view.net_shown(0), "das Netz wartet auf das Einrasten")
	await wait_for_signal(view.opening_finished, 10.0)
	var locks := events.filter(func(e: Array) -> bool: return e[0] == "lock")
	assert_eq(locks.size(), 4, "jeder Würfel rastet ein")
	assert_eq(locks[2], ["lock", 2, 1, true], "ein Aufstieg bekommt seinen Moment")
	assert_eq(events[events.size() - 2], ["stop", 2], "die Walze hält auf der Buchung")
	assert_eq(events[events.size() - 1], ["done"])
	assert_true(view.reel_shown())
	assert_true(view.reel_done())
	assert_eq(view.reel_value(), 2, "im Fenster steht die gebuchte Zahl")
	assert_true(view.choosing())

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

## Als HUB-SEITE steht die Ansicht bei (0, 0) im Hub - gemeldet wird trotzdem in
## Display-Pixeln, also samt dem Versatz des Hubs.
func test_a_hub_page_reports_its_places_in_display_pixels() -> void:
	var hub := Control.new()
	add_child_autofree(hub)
	hub.position = Vector2(1800, 2000)
	hub.size = Vector2(1068, 1125)
	var view := PackChoiceView.new()
	view.defer_show = true
	view.visible = false
	hub.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await wait_frames(2)
	var choice := _dice_choice(7)
	view.open(choice, DIE_PX, 1, 5, false, CASE_PX, 2)
	assert_false(view.visible, "als Hub-Seite blendet scene_root sie ein")
	assert_eq(view.position, Vector2.ZERO)
	assert_eq(view.case_seat_px(), hub.position + view.case_rect_local().get_center())
	var centers := view.slot_centers()
	assert_eq(centers.size(), 7)
	var page := Rect2(hub.position, hub.size)
	assert_eq(view.page_rect_px(), page)
	for i in 7:
		var local := view.slot_rect(i, 7).get_center()
		assert_almost_eq(centers[i].x, hub.position.x + local.x, 0.01)
		assert_true(page.has_point(centers[i]), "Platz %d liegt auf der Seite" % i)
	assert_true(page.encloses(view.lineup_area_px()))

func test_on_the_tall_hub_page_the_nets_are_at_least_as_big_as_in_the_pit() -> void:
	var pit := _view()
	var hub := _view()
	hub.size = Vector2(1068, 1125)
	for count in range(1, 11):
		var choice := _dice_choice(count)
		pit.open(choice, DIE_PX, 1, 5, false, CASE_PX, 2)
		hub.open(choice, DIE_PX, 1, 5, false, CASE_PX, 2)
		assert_gte(hub.net_cell(count), pit.net_cell(count), "%d Würfel" % count)
		var area := Rect2(Vector2.ZERO, hub.size)
		var taken: Array[Rect2] = [hub.case_rect_local()]
		for i in count:
			var die := hub.slot_rect(i, count)
			var net := hub.net_rect(i, count)
			assert_true(area.encloses(net))
			assert_lte(hub.lineup_block(i, count).size.y, hub.block_max_height() + 0.01,
				"ein Block wächst nicht über die halbe Seite")
			for other in taken:
				assert_false(other.intersects(die.grow(-0.5)))
				assert_false(other.intersects(net.grow(-0.5)))
			taken.append(die)
			taken.append(net)

func test_the_page_names_the_energy_for_the_reshuffle() -> void:
	var view := _view()
	view.open(_dice_choice(3), DIE_PX, 2, 7, false, CASE_PX, 2)
	assert_eq(view.energy_text(), "Energie ⚡ 7")
	var label := view.get_node("Energy") as Label
	assert_eq(label.text, view.energy_text())
