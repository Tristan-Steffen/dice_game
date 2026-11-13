extends GutTest
## Die Paket-Auswahl: bei Würfel-Paketen steht die Schatulle oben, darunter die
## AUFSTELLUNG - je Würfel sein Platz und sein Netz; Karten-Pakete bleiben, wie sie sind.

const CASE_PX := Vector2(200, 134)
const DIE_PX := Vector2(45, 45)
## Die ÖFFNUNGS-FLÄCHE unter dem Lager, gemessen 2026-11-13 (1280 × 720): ihre linke
## untere Ecke eine Fuge rechts neben der Die-View, auf deren Unterkante.
const OPENING_POS := Vector2(3593.744, 1898.176)
const OPENING_SIZE := Vector2(1480.398, 754.919)

func _open_pack(run: GameRun, pack: Resource) -> PackChoice:
	var stored: Resource = run.purchase_dice_pack(pack as DicePack, 1) if pack is DicePack \
		else run.purchase_card_pack(pack as CardPack, 1)
	return run.open_stored_pack(int(stored.get("store_uid")))

func _dice_choice(count: int) -> PackChoice:
	var run := GameRun.new_run()
	run.money = 999
	var choice := _open_pack(run, DicePack.make(DicePack.SORT_MIXED, CardPack.SIZE_HUGE))
	var base: Array = choice.options.duplicate()
	choice.options.clear()
	for i in count:
		choice.options.append((base[i % base.size()] as DieDefinition).instantiate())
	return choice

func _card_choice() -> PackChoice:
	var run := GameRun.new_run()
	run.money = 999
	return _open_pack(run, CardPack.make(CardPack.SORT_MIXED, CardPack.SIZE_LARGE))

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

## Das Raster folgt der FLÄCHE: jeder Würfel hat einen Platz, keine Reihe bleibt leer,
## und nie mehr als zehn Plätze.
func test_the_lineup_grid_follows_the_area() -> void:
	var small := _view()
	var real := _opening()
	for count in range(1, 11):
		var choice := _dice_choice(count)
		small.open(choice, DIE_PX, 1, 5, false, CASE_PX, 2)
		real.open(choice, DIE_PX, 1, 5, false, CASE_PX, 2)
		for view in [small, real]:
			var grid: Vector2i = view.lineup_grid(count)
			assert_gte(grid.x * grid.y, count)
			assert_lt((grid.y - 1) * grid.x, count, "keine leere Reihe")
	var grid99: Vector2i = small.lineup_grid(99)
	assert_lte(grid99.x * grid99.y, 10, "nie mehr als 10 Würfel")

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
	assert_lte(view.case_rect_local().end.x, view.lineup_area().position.x,
		"breit steht die Schatulle in der Spalte links der Aufstellung")

func test_card_choice_keeps_its_layout() -> void:
	var choice := _card_choice()
	var view := _view()
	view.open(choice, Vector2(60, 90), 1, 5)
	assert_false(view.lineup())
	var count := choice.option_count()
	for i in count:
		assert_true(Rect2(Vector2.ZERO, view.size).encloses(view.slot_rect(i, count)))
		assert_false(view.net_shown(i), "Karten tragen kein Würfelnetz")

## Auf der ÖFFNUNGS-FLÄCHE meldet die Ansicht in Display-Pixeln: Plätze, Schatulle,
## Aufstellung und Landefläche liegen alle auf der Fläche.
func test_the_opening_reports_its_places_in_display_pixels() -> void:
	var view := _opening()
	var choice := _dice_choice(7)
	view.open(choice, DIE_PX, 1, 5, false, CASE_PX, 2)
	assert_true(view.visible)
	assert_eq(view.case_seat_px(), OPENING_POS + view.case_rect_local().get_center())
	var page := Rect2(OPENING_POS, OPENING_SIZE)
	assert_almost_eq(view.page_rect_px().size.x, page.size.x, 0.01)
	assert_eq(view.page_rect_px().position, page.position)
	var centers := view.slot_centers()
	assert_eq(centers.size(), 7)
	for i in 7:
		var local := view.slot_rect(i, 7).get_center()
		assert_almost_eq(centers[i].x, OPENING_POS.x + local.x, 0.01)
		assert_true(page.has_point(centers[i]), "Platz %d liegt auf der Fläche" % i)
	assert_true(page.encloses(view.lineup_area_px()))
	assert_true(page.encloses(view.landing_rect_px()))
	var case_px := Rect2(OPENING_POS + view.case_rect_local().position, CASE_PX)
	assert_true(view.landing_rect_px().encloses(case_px),
		"die Schatulle steht AUF der Landefläche - ihr Schuß fällt nie über eine Wand")
	assert_lt(view.case_seat_px().x, view.lineup_area_px().get_center().x,
		"die Schatulle steht links, geschossen wird nach rechts")

## Auf der Öffnungs-Fläche für 1 bis 10 Würfel: nichts überlappt, nichts ragt hinaus,
## alles steht rechts der Spalte, die Netze bleiben lesbar - und jede Kachel ist
## ausgewogen: der Würfel liest ganz über seinem Netz, oben und unten dieselbe Luft.
func test_on_the_opening_up_to_ten_dice_fit_without_overlap() -> void:
	var view := _opening()
	for count in range(1, 11):
		var choice := _dice_choice(count)
		view.open(choice, DIE_PX, 1, 5, false, CASE_PX, 2)
		assert_gte(view.net_cell(count), 28.0, "lesbare Zellen (%d Würfel)" % count)
		var area := view.lineup_area()
		var taken: Array[Rect2] = []
		for i in count:
			var block := view.lineup_block(i, count)
			var die := view.slot_rect(i, count)
			var net := view.net_rect(i, count)
			assert_true(area.encloses(block), "%d/%d: in der Aufstellung" % [i, count])
			assert_gte(block.position.x, view.column_width(), "rechts der Spalte")
			assert_true(block.encloses(die) and block.encloses(net))
			assert_gte(net.position.y, die.end.y, "der Würfel liest ganz über seinem Netz")
			assert_almost_eq(die.position.y - block.position.y, block.end.y - net.end.y, 0.01,
				"oben und unten dieselbe Luft")
			var seat: float = view.slot_centers()[i].y - OPENING_POS.y
			assert_almost_eq(seat - view.look_above(seat), die.position.y, 0.01,
				"der Sitz rückt um seine gemessene Projektion tiefer")
			for other in taken:
				assert_false(other.intersects(block.grow(-0.5)), "Kacheln überlappen nicht")
			taken.append(block)
		var info: Rect2 = view._frame_rects()["info"]
		assert_lte(view.lineup_area().end.y, info.position.y, "die Auskunft bleibt frei")
	# Die SPALTE: Schatulle, Kopf, Energie und Knöpfe untereinander, ohne Überlappung.
	var frame: Dictionary = view._frame_rects()
	var column: Array[Rect2] = [view.case_rect_local(), frame["head"], frame["energy"],
		frame["buttons"]]
	for i in column.size():
		assert_true(Rect2(Vector2.ZERO, view.size).encloses(column[i]), "Spalten-Feld %d" % i)
		assert_lte(column[i].end.x, view.column_width(), "Spalten-Feld %d links" % i)
		if i > 0:
			assert_lte(column[i - 1].end.y, column[i].position.y + 0.5,
				"Spalten-Felder %d/%d untereinander" % [i - 1, i])

## Leer steht die Fläche weiter: ihr Schirm, ein ruhiger Hinweis, keine Knöpfe.
## Das Rechteck der Fläche aus den gemessenen Nachbarn (1280 × 720): ihre linke UNTERE
## Ecke steht eine Fuge rechts der Die-View auf deren Unterkante, oben eine Fuge unter
## dem Lager, rechts bündig mit ihm - und nirgends eine Überlappung.
func test_the_opening_area_sits_at_the_die_view() -> void:
	var store := Rect2(3719.563, 1304.776, 1354.58, 569.9999)
	var die_view := Rect2(3340.409, 2510.535, 229.9355, 142.5599)
	var crown := Rect2(3367.822, 2410.168, 175.1079, 93.96035)
	var info := Rect2(2916.358, 2366.026, 424.0503, 105.7766)
	var magazin := Rect2(2920.667, 2669.552, 961.0, 369.12)
	var keys := Rect2(3892.1, 2669.552, 59.97, 369.12)
	var gap := TableScreen.LAYOUT_SIZE.x * 0.005
	var neighbours: Array[Rect2] = [crown, info, magazin, keys]
	var area := PackChoiceView.area_for(store, die_view, neighbours, 5094.0 - 18.75, gap)
	assert_almost_eq(area.position.x, die_view.end.x + gap, 0.01, "eine Fuge neben der Die-View")
	assert_almost_eq(area.end.y, die_view.end.y, 0.01, "unten bündig mit der Die-View")
	assert_almost_eq(area.position.y, store.end.y + gap, 0.01, "eine Fuge unter dem Lager")
	assert_almost_eq(area.end.x, store.end.x, 0.01, "rechts bündig mit dem Lager")
	for other in [store, die_view, crown, info, magazin, keys]:
		assert_false(area.intersects(other), "keine Überlappung mit %s" % other)
	assert_almost_eq(area.position.x, OPENING_POS.x, 1.0, "die gemessene Fläche")
	assert_almost_eq(area.size.x, OPENING_SIZE.x, 1.0)
	assert_almost_eq(area.size.y, OPENING_SIZE.y, 1.0)
	# Ragt die Krone über die Die-View hinaus, weicht die Fläche ihr.
	var wide_crown := Rect2(crown.position, Vector2(260.0, crown.size.y))
	var pushed := PackChoiceView.area_for(store, die_view, [wide_crown] as Array[Rect2],
		5094.0 - 18.75, gap)
	assert_almost_eq(pushed.position.x, wide_crown.end.x + gap, 0.01, "nie über die Krone")

func test_the_empty_opening_shows_a_hint_and_no_buttons() -> void:
	var view := _opening()
	view.backdrop = true
	view.open(_dice_choice(3), DIE_PX, 1, 5, false, CASE_PX, 2)
	view.close()
	view.set_idle_text("Paket im Lager anklicken zum Öffnen")
	assert_true(view.visible, "die Fläche steht permanent")
	assert_false(view.choosing())
	assert_not_null(view.idle_label())
	assert_eq(view.idle_label().text, "Paket im Lager anklicken zum Öffnen")
	assert_eq(view.find_children("*", "Button", true, false).size(), 0, "keine Knöpfe")
	view.set_idle_text("Öffnen nach der Runde")
	assert_eq(view.idle_label().text, "Öffnen nach der Runde")
	view.open(_dice_choice(3), DIE_PX, 1, 5, false, CASE_PX, 2)
	assert_null(view.idle_label(), "eine Öffnung verdrängt den Hinweis")

func test_cards_on_the_opening_stay_on_the_area() -> void:
	var choice := _card_choice()
	var view := _opening()
	view.open(choice, Vector2(194, 130), 1, 5)
	var area := view.lineup_area()
	for i in choice.option_count():
		var slot := view.slot_rect(i, choice.option_count())
		assert_true(area.encloses(slot), "Karte %d liegt in der Fläche rechts der Spalte" % i)

func test_the_page_names_the_energy_for_the_reshuffle() -> void:
	var view := _view()
	view.open(_dice_choice(3), DIE_PX, 2, 7, false, CASE_PX, 2)
	assert_eq(view.energy_text(), "Energie ⚡ 7")
	var label := view.get_node("Energy") as Label
	assert_eq(label.text, view.energy_text())

# --- Modul-Pakete -------------------------------------------------------------------

func _module_choice() -> PackChoice:
	var run := GameRun.new_run()
	run.money = 999
	var stored := run.purchase_module_pack(ModulePack.make(CardPack.SIZE_HUGE,
		ModulePack.GRADE_RARE), 1)
	return run.open_stored_pack(stored.store_uid)

func test_module_options_stand_in_the_lineup_area_with_their_rarity() -> void:
	var view := _opening()
	var choice := _module_choice()
	view.open(choice, Vector2(78, 78), 1, 5)
	await wait_frames(2)
	var area := view.lineup_area_px()
	for i in choice.option_count():
		var part: ComboPart = choice.options[i]
		assert_true(area.has_point(view.slot_centers()[i]), "Platz %d in der Aufstellung" % i)
		assert_eq(view.slot_rim(i), Color(part.rarity_color(), 0.85), "Saum = Seltenheit")
		assert_string_contains(PackChoiceView.option_text(part), part.description)
	var bag := view.bag_seat_px()
	assert_lt(bag.x, area.position.x, "der Beutel liegt in der Spalte")
	assert_true(view.page_rect_px().has_point(bag))
