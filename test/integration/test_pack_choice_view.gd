extends GutTest
## Die Paket-Auswahl auf der ÖFFNUNGS-FLÄCHE rechts neben dem Pool: Würfel-Pakete stehen als
## SCHIENE ohne Schirm (je Option eine Reihe, höchstens drei je Spalte, weitere Spalten
## rechts), Karten-Pakete liegen mit Schirm 3 + 2.

const DIE_PX := Vector2(45, 45)
## Gemessen 1280 × 720 (2026-11-18, Layout A): Pool-Reihe, die Naht darunter, der
## freigehaltene Podest-Platz und die Fuge zur Fläche.
const POOL := Rect2(2916.358, 1994.776, 585.0, 487.5)
const SEAM := 48.75
const PODIUM := Rect2(3660.3, 1994.776, 201.7, 352.9)
const GAP := 20.17
const CARD := Vector2(194.4, 129.6)
const OPENING_POS := Vector2(3882.17, 1994.776)
const OPENING_SIZE := Vector2(646.6, 487.5)
## Die SCHIENE darauf (gemessen 646,6 × 442,3).
const RAIL := Rect2(3882.17, 1994.776, 646.6, 442.3)

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

## Das Fenster der Schiene, so wie scene_root es stellt.
func _rail_view() -> PackChoiceView:
	var view := _view()
	var window := PackChoiceView.rail_window_for(RAIL)
	view.position = window.position
	view.size = window.size
	return view

func _dice(view: PackChoiceView, count: int) -> PackChoice:
	var choice := _dice_choice(count)
	view.open(choice, DIE_PX, 1, 5, false, 2)
	return choice

# --- Die SCHIENE -------------------------------------------------------------------

## Das Fenster beginnt mit der Schiene (kein Kopf), der Fuß hängt darunter: die Auskunft
## über die volle Breite, zuunterst der Knopf und rechts daneben die Walze.
func test_the_rail_window_wraps_the_rail() -> void:
	var view := _rail_view()
	_dice(view, 5)
	assert_true(view.lineup(), "ein Würfel-Paket steht als Schiene")
	var rail := view.lineup_area_px()
	assert_almost_eq(rail.position.x, RAIL.position.x, 0.01)
	assert_almost_eq(rail.position.y, RAIL.position.y, 0.01, "oben bündig mit dem Vorrat")
	assert_almost_eq(view.page_rect_px().position.y, RAIL.position.y, 0.01, "kein Kopf darüber")
	assert_almost_eq(rail.size.y, RAIL.size.y, 0.01, "so hoch wie der Vorrat")
	var frame: Dictionary = view._frame_rects()
	var bounds := Rect2(Vector2.ZERO, view.size).grow(0.01)
	for key in ["info", "buttons", "reel"]:
		var rect: Rect2 = frame[key]
		assert_true(bounds.encloses(rect), "%s im Fenster" % key)
		assert_gte(rect.position.y, view.lineup_area().end.y, "%s unter der Schiene" % key)
	var buttons: Rect2 = frame["buttons"]
	var reel: Rect2 = frame["reel"]
	assert_gt(reel.position.x, buttons.end.x, "die Walze steht rechts neben dem Knopf")
	assert_almost_eq(reel.position.y, buttons.position.y, 0.01, "auf derselben Zeile")
	assert_lte((frame["info"] as Rect2).end.y, buttons.position.y, "die Auskunft darüber")
	assert_false(view._title.visible, "kein Name über der Schiene")
	assert_false(view._counter.visible, "kein Zähler über der Schiene")
	assert_eq(PackChoiceView.rail_window_for(Rect2()), Rect2(), "keine Schiene, kein Fenster")

## Höchstens drei Würfel untereinander, weitere Spalten rechts daneben, oben bündig.
func test_the_rail_stacks_three_per_column_and_grows_right() -> void:
	for count in range(1, 7):
		var view := _rail_view()
		_dice(view, count)
		var grid := PackChoiceView.rail_grid(count)
		assert_eq(grid, Vector2i(int(ceil(count / 3.0)), mini(count, 3)), "%d Würfel" % count)
		var area := view.lineup_area().grow(0.01)
		var pitch := view.rail_pitch()
		assert_almost_eq(pitch * 3.0, view.lineup_area().size.y, 0.01, "drei Reihen füllen die Höhe")
		var taken: Array[Rect2] = []
		for i in count:
			var block := view.lineup_block(i, count)
			var die := view.slot_rect(i, count)
			var net := view.net_rect(i, count)
			var column := i / 3
			var row := i % 3
			assert_almost_eq(block.position.y, view.lineup_area().position.y + row * pitch, 0.01,
				"%d/%d: Reihe %d oben bündig" % [i, count, row])
			if column > 0:
				var left := view.lineup_block(i - 3, count)
				assert_almost_eq(block.position.y, left.position.y, 0.01, "Spalten oben bündig")
				assert_gt(block.position.x, left.end.x, "die nächste Spalte steht rechts")
			for rect: Rect2 in [block, die, net]:
				assert_true(area.encloses(rect), "%d/%d: auf der Schiene" % [i, count])
			assert_true(block.grow(0.01).encloses(net), "das Netz steht in seiner Kachel")
			assert_true(block.grow(0.01).encloses(die), "der Würfel liest in seiner Kachel")
			assert_gte(net.position.x, die.end.x, "der Würfel liest links neben seinem Netz")
			assert_almost_eq(die.position.x - block.position.x, block.end.x - net.end.x, 0.01,
				"links und rechts dieselbe Luft")
			for other in taken:
				assert_false(other.intersects(block.grow(-0.5)), "Kacheln überlappen nicht")
			taken.append(block)
		assert_gte(view.net_cell(count), 25.0, "lesbare Zellen (%d Würfel)" % count)

## Die Schiene ist so breit wie ihre Spalten (mindestens zwei, der Fuß braucht Platz).
func test_the_rail_is_as_wide_as_its_columns() -> void:
	for count in range(1, 11):
		var width := PackChoiceView.rail_width_for(RAIL.size.y, DIE_PX.y, count)
		var view := _view()
		var window := PackChoiceView.rail_window_for(Rect2(RAIL.position, Vector2(width, RAIL.size.y)))
		view.position = window.position
		view.size = window.size
		_dice(view, count)
		var last := view.lineup_block(count - 1, count)
		assert_lte(last.end.x, width + 0.01, "%d Würfel: nichts ragt hinaus" % count)
		if count > 3:
			assert_almost_eq(last.end.x, width, 0.01, "%d Würfel: die Spalten füllen die Breite" % count)
	assert_almost_eq(PackChoiceView.rail_width_for(RAIL.size.y, DIE_PX.y, 1),
		PackChoiceView.rail_width_for(RAIL.size.y, DIE_PX.y, 6), 0.01, "bis sechs Würfel gleich breit")

func test_five_dice_stand_three_and_two() -> void:
	var view := _rail_view()
	_dice(view, 5)
	var top := view.lineup_block(0, 5).position.y
	assert_almost_eq(view.lineup_block(3, 5).position.y, top, 0.01, "Spalte 2 beginnt oben")
	assert_almost_eq(view.lineup_block(4, 5).position.y, view.lineup_block(1, 5).position.y, 0.01)
	assert_gt(view.lineup_block(3, 5).position.x, view.lineup_block(2, 5).end.x)

## Die Plätze stehen in Display-Pixeln auf der Schiene.
func test_the_rail_reports_its_places_in_display_pixels() -> void:
	var view := _rail_view()
	_dice(view, 6)
	var centers := view.slot_centers()
	assert_eq(centers.size(), 6)
	for i in 6:
		var local := view.slot_rect(i, 6).get_center()
		assert_almost_eq(centers[i].x, view.position.x + local.x, 0.01)
		assert_true(RAIL.grow(1.0).has_point(centers[i]), "Platz %d liegt auf der Schiene" % i)

## Ohne Schirm: die Schiene malt keinen Hintergrund, das setzt scene_root nur bei Karten.
func test_the_rail_has_no_backdrop_by_default() -> void:
	var view := _rail_view()
	_dice(view, 3)
	assert_false(view.backdrop, "auf dem Filz steht kein Schirm")

func test_the_nets_open_with_the_lineup() -> void:
	var view := _rail_view()
	_dice(view, 4)
	for i in 4:
		assert_false(view.net_shown(i), "beim Fall steht kein Netz")
	view.show_lineup()
	for i in 4:
		assert_true(view.net_shown(i), "auf der Schiene steht jedes Netz sofort")
	view.skip_to_pick()
	assert_true(view.choosing())

func test_the_launch_shows_no_slots_and_no_counter() -> void:
	var view := _rail_view()
	_dice(view, 5)
	assert_eq(view.stage(), PackChoiceView.STAGE_LAUNCH)
	assert_false(view.slots_shown(), "beim Fall zählt niemand mit")
	assert_false(view.choosing())
	assert_false(view.reel_shown(), "die Walze wartet")
	view.show_lineup()
	assert_true(view.slots_shown(), "die Schiene zeigt ihre Plätze")
	view.skip_to_pick()
	for i in 5:
		assert_eq(view.slot_rim(i), PackChoiceView.SLOT_RIM, "ein Würfel trägt einen neutralen Saum")

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

func test_the_opening_runs_the_reel_then_pick() -> void:
	var view := _rail_view()
	var choice := _dice_choice(4)
	choice.base_picks = 1
	choice.picks = 2
	view.open(choice, DIE_PX, 1, 5, false, 2)
	assert_false(view.reel_shown(), "die Walze steht erst auf der Schiene")
	var events: Array = []
	view.reel_stopped.connect(func(value: int, _top: int) -> void: events.append(["stop", value]))
	view.opening_finished.connect(func() -> void: events.append(["done"]))
	view.show_lineup()
	view.play_reel()
	assert_eq(view.stage(), PackChoiceView.STAGE_REEL, "es geht direkt zur Walze")
	assert_true(view.reel_shown())
	var reel := view.get_node("PickReel") as Control
	assert_true(Rect2(Vector2.ZERO, view.size).encloses(Rect2(reel.position, reel.size)),
		"die Walze steht im Fenster")
	await wait_for_signal(view.opening_finished, 10.0)
	assert_eq(events[events.size() - 2], ["stop", 2], "die Walze hält auf der Buchung")
	assert_eq(events[events.size() - 1], ["done"])
	assert_true(view.reel_done())
	assert_eq(view.reel_value(), 2, "im Fenster steht die gebuchte Zahl")
	assert_true(view.choosing())

func test_a_net_cell_names_its_face() -> void:
	var view := _rail_view()
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
	var dice := _rail_view()
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

## Das Rechteck der Fläche: rechts neben dem Podest-Platz, oben bündig mit der Pool-Reihe
## und so hoch wie sie.
func test_the_opening_area_stands_beside_the_podium_place() -> void:
	var width := PackChoiceView.area_width_for(POOL.size.y, CARD, DIE_PX.y, RAIL.size.y)
	var area := PackChoiceView.area_beside(POOL, PODIUM, GAP, width)
	assert_almost_eq(area.position.x, PODIUM.end.x + GAP, 0.01, "rechts vom Podest-Platz")
	assert_almost_eq(area.position.y, POOL.position.y, 0.01, "oben bündig mit dem Pool")
	assert_almost_eq(area.size.y, POOL.size.y, 0.01, "so hoch wie er")
	assert_gte(area.size.x, CARD.x * PackChoiceView.SLOT_ROOM * 3.0, "drei Karten nebeneinander")
	assert_eq(PackChoiceView.area_beside(Rect2(), PODIUM, GAP, width), Rect2(),
		"ohne Pool keine Fläche")

## Layout C: an der echten Kette steht die Fläche rechts neben dem Podest der Gleichung -
## über "=", ERGEBNIS und PRÄGEN (die dann fort sind), nie über Pool, UPGRADES oder Kammer,
## und nicht über die Anzeige hinaus.
func test_the_opening_area_stands_right_of_the_equation_podium() -> void:
	var card := Vector2(194.4, 129.6)
	var lay := WorkshopView.drum_layout(POOL, card, 55.46, 5.042, 0.0, 48.75)
	var podium: Rect2 = lay["podium"]
	var width := PackChoiceView.area_width_for(POOL.size.y, card, DIE_PX.y, RAIL.size.y)
	var area := PackChoiceView.area_beside(POOL, podium, 5.042 * WorkshopView.DRUM_SHELF_GAP,
		width)
	assert_gt(area.position.x, podium.end.x, "rechts vom Podest-Platz")
	assert_almost_eq(area.position.y, POOL.position.y, 0.01, "oben bündig mit dem Pool")
	for key in ["upgrades", "podium_stage", "chamber", "podium_net", "raster", "bounds"]:
		assert_false((lay[key] as Rect2).intersects(area), "nicht über %s" % key)
	assert_lte(area.end.x, 5094.0, "innerhalb der Anzeige")
	var window := PackChoiceView.rail_window_for(PackChoiceView.rail_in(area, DIE_PX.y, 5, 48.75))
	assert_lte(window.end.y, (lay["pit"] as Rect2).position.y
		- 5.042 * (WorkshopView.SLICE_NUMBER_UNITS + WorkshopView.SLICE_NUMBER_GAP) + 0.01,
		"der Fuß der Schiene endet vor den Nummern der Walze")
	assert_false(window.intersects(lay["info"]), "und über dem Info-Schirm")

## Die Schiene steht oben auf der Fläche, ihr Fuß reicht höchstens um die Naht darunter.
func test_the_rail_fits_the_area_and_the_seam() -> void:
	var width := PackChoiceView.area_width_for(POOL.size.y, CARD, DIE_PX.y, RAIL.size.y)
	var area := PackChoiceView.area_beside(POOL, PODIUM, GAP, width)
	for count in [1, 3, 5, 6]:
		var rail := PackChoiceView.rail_in(area, DIE_PX.y, count, SEAM)
		var window := PackChoiceView.rail_window_for(rail)
		assert_eq(rail.position, area.position, "%d Würfel: oben auf der Fläche" % count)
		assert_almost_eq(rail.size.x, area.size.x, 0.01, "so breit wie sie")
		assert_lte(window.end.y, area.end.y + SEAM + 0.01, "%d Würfel: der Fuß bleibt in der Naht"
			% count)
		assert_lte(PackChoiceView.rail_width_for(rail.size.y, DIE_PX.y, count), area.size.x + 0.01,
			"die Spalten passen in die Breite")
	assert_almost_eq(PackChoiceView.rail_in(area, DIE_PX.y, 5, SEAM).size.y, RAIL.size.y, 1.0,
		"gemessen 442,3 hoch")
	assert_eq(PackChoiceView.rail_in(Rect2(), DIE_PX.y, 5), Rect2(), "keine Fläche, keine Schiene")

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
	var view := _rail_view()
	view.open(_dice_choice(3), DIE_PX, -1, 7, false, 2)
	assert_false((view.get_node("Energy") as Label).visible)
	assert_false(view._reshuffle_button.visible)

# --- ZUORDNEN: beim Würfel-Paket ist Wählen Einsetzen -------------------------------

func _picking(count: int, picks: int) -> PackChoiceView:
	var view := _rail_view()
	var choice := _dice_choice(count)
	choice.picks = picks
	view.open(choice, DIE_PX, 1, 5, false, 2)
	view.show_lineup()
	view.skip_to_pick()
	return view

func test_a_dice_pack_assigns_instead_of_picking() -> void:
	var view := _picking(5, 2)
	assert_true(view.assigning(), "Würfel-Pakete ordnen zu")
	assert_eq(view.reel_value(), 2, "die Walze am Knopf nennt die Wahlen")
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
	assert_gte(button.position.y, view.lineup_area().end.y, "der Knopf unter der Schiene")

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
	# Ein belegter Platz schickt seine Option zurück auf die Schiene.
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
	var view := _rail_view()
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
