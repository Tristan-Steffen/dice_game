extends GutTest
## Die ETAGEN-KARTE als TURM (FloorMapView): die NAHSICHT auf dem Grubenboden (DETAIL: drei
## große Kacheln quer, voller Klausel-Text, Klick zieht, Zug schiebt) und der STREIFEN der
## Startseite (COMPACT: ohne Text, reine Übersicht). Beide teilen Geometrie, Zug-Regel und
## Auskunft.

## Das Maß des Grubenbodens (Querformat).
const DETAIL_SIZE := Vector2(985, 484)
## Das Maß des Streifens auf der Startseite.
const STRIP_SIZE := Vector2(360, 783)
const STRIP_UNIT := 10.68

var view: FloorMapView
var run: GameRun
var chosen: Array[String] = []

func before_each() -> void:
	run = GameRun.new_run()
	run.advance_round()  # ab Runde 2 ist ein Zug fällig
	view = add_child_autofree(FloorMapView.new())
	view.mode = FloorMapView.Mode.DETAIL
	view.size = DETAIL_SIZE
	chosen.clear()
	view.door_chosen.connect(func(door_id: String) -> void: chosen.append(door_id))

func _strip() -> FloorMapView:
	var strip: FloorMapView = add_child_autofree(FloorMapView.new())
	strip.mode = FloorMapView.Mode.COMPACT
	strip.unit_px = STRIP_UNIT
	strip.size = STRIP_SIZE
	strip.door_chosen.connect(func(door_id: String) -> void: chosen.append(door_id))
	return strip

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

## Eine Etage mit allen Türzuständen: alles erkundet, dann je eine Tür durchschritten,
## gesperrt, unerkundet und frei - keine davon am Eingang.
func _mixed_floor() -> Dictionary:
	var bosses: Array[String] = []
	bosses.assign(DealClause.ids_for(DealClause.Tier.BOSS, DealClause.Kind.MALUS).slice(0, 3))
	var map := FloorMap.roll(_rng(9), Callable(), 0.0, bosses, 0)
	for room_id: String in map.rooms:
		map.scout_from(room_id, _rng(10), Callable())
	run.floor_map = map
	var inner: Array[Dictionary] = []
	for entry in map.doors:
		if not map.is_office_door(entry) and entry["a"] != map.entrance and entry["b"] != map.entrance:
			inner.append(entry)
	inner[0]["state"] = FloorMap.DoorState.PASSED
	inner[1]["state"] = FloorMap.DoorState.LOCKED
	inner[2]["scouted"] = false
	inner[3]["free"] = true
	inner[3]["malus"] = ""
	return {"passed": String(inner[0]["id"]), "locked": String(inner[1]["id"]),
		"unknown": String(inner[2]["id"]), "free": String(inner[3]["id"]),
		"locked_malus": String(inner[1]["malus"])}

## Der Puck steht in einem Raum der mittleren Reihe, von dem aus mehrere Türen gehen.
func _stand_in_the_middle() -> void:
	var map := run.floor_map
	for room_id in map.room_ids():
		if int(FloorMap.row_of(map.rooms[room_id]["cell"])) == 2:
			map.position = room_id
			map.rooms[room_id]["visited"] = true
			map.scout_from(room_id, _rng(11), Callable())
			return

func _label(node_name: String) -> Label:
	return view.find_child(node_name, true, false) as Label

func _unwrap(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("-\\n(?=[a-zäöüß])")
	return regex.sub(text, "", true).replace("-\n", "-").replace("\n", " ")

func _walk_target(door_id: String) -> String:
	return run.floor_map.other_side(run.floor_map.door(door_id), run.floor_map.position)

## Paßt der Text des Labels ganz hinein (nichts abgeschnitten)?
func _fits(label: Label) -> bool:
	var font := label.get_theme_font("font")
	var px := label.get_theme_font_size("font_size")
	var lines := label.text.split("\n").size()
	return FloorMapView.text_height(font, px, lines) <= label.size.y + 1.5

func _no_word_break(label: Label, text: String) -> void:
	var allowed: Array[String] = []
	for word in text.split(" ", false):
		allowed.append(word)
		allowed.append_array(Array(FloorMapView.word_parts(word)))
	for line in label.text.split("\n"):
		for token in line.split(" ", false):
			assert_true(allowed.has(token), "%s: „%s“ ist kein ganzes Wort und keine Fuge" % [text, token])
	assert_eq(_unwrap(label.text).replace("-", "").replace(" ", ""),
		text.replace("-", "").replace(" ", ""), "nichts fehlt")

# --- Die NAHSICHT -------------------------------------------------------------------

func test_the_floor_reads_from_bottom_to_top() -> void:
	view.open(run.floor_view_state())
	var entrance := view.room_rect(run.floor_map.entrance)
	var office := view.room_rect(run.floor_map.office)
	assert_gt(entrance.position.y, office.position.y, "der Eingang unten, das Büro oben")

func test_three_rooms_fill_the_width_and_the_next_row_stands_in_the_middle() -> void:
	view.open(run.floor_view_state())
	var area := view.map_rect()
	var m := view.metrics()
	assert_gt(float(m["tile_w"]) * 3.0, area.size.x * 0.6, "drei Kacheln füllen die Breite")
	var door_id := String(run.walkable_doors()[0])
	var target := view.room_rect(_walk_target(door_id))
	assert_true(area.encloses(target), "die Reihe der gangbaren Räume steht ganz im Bild")
	assert_almost_eq(target.get_center().y, area.get_center().y, 2.0, "mittig")
	var here := view.room_rect(run.floor_map.position)
	assert_true(here.intersects(area) and here.end.y > area.end.y - 1.0,
		"der Standraum am unteren Rand (angeschnitten erlaubt)")

func test_only_the_rows_of_the_window_are_built() -> void:
	_stand_in_the_middle()
	view.open(run.floor_view_state())
	var area := view.map_rect()
	var built := 0
	for room_id in run.floor_map.room_ids():
		var inside := view.room_rect(room_id).intersects(area)
		assert_eq(_label("Room_" + room_id) != null, inside, "%s gebaut genau dann, wenn im Bild" % room_id)
		built += 1 if inside else 0
	assert_lt(built, run.floor_map.room_ids().size(), "nicht der ganze Turm")

func test_a_room_carries_name_bonus_and_its_full_text() -> void:
	view.open(run.floor_view_state(), 2)
	var target := _walk_target(String(run.walkable_doors()[0]))
	var bonus := String(run.floor_map.rooms[target]["bonus"])
	assert_eq(_unwrap(_label("Room_" + target).text), String(run.floor_map.rooms[target]["name"]))
	assert_eq(_unwrap(_label("Bonus_" + target).text), DealClause.find(bonus).display_name)
	var text := _label("Text_" + target)
	assert_eq(_unwrap(text.text), DealClause.text_for(bonus, 2), "voller Bonus-Text mit Faktor")
	assert_true(_fits(text))

func test_a_scouted_door_carries_its_malus_name_and_full_text() -> void:
	_stand_in_the_middle()
	view.open(run.floor_view_state())
	var area := view.map_rect()
	var seen := 0
	for entry in run.floor_map.doors:
		var door_id := String(entry["id"])
		if int(entry["state"]) != FloorMap.DoorState.OPEN or not bool(entry["scouted"]) \
				or bool(entry["free"]) or not view.door_mark_rect(door_id).intersects(area):
			continue
		var clause := String(entry["boss"]) if String(entry["boss"]) != "" else String(entry["malus"])
		assert_eq(_unwrap(_label("Mark_" + door_id).text), DealClause.find(clause).display_name)
		var text := _label("MarkText_" + door_id)
		assert_eq(_unwrap(text.text), DealClause.text_for(clause), "voller Malus-Text")
		assert_true(_fits(text), "%s paßt" % door_id)
		seen += 1
	assert_gt(seen, 0)

func test_blind_and_cushion_stand_only_on_walkable_rooms() -> void:
	run.round_scores.assign([600, 900])
	var state := run.floor_view_state()
	view.open(state)
	var walk := run.walkable_doors()
	for room_id in run.floor_map.room_ids():
		var label := _label("Move_" + room_id)
		var door_id := view.door_to(room_id)
		if door_id == "":
			assert_null(label, "%s ist nicht gangbar" % room_id)
			continue
		assert_true(walk.has(door_id))
		if label == null:
			continue  # außerhalb des Ausschnitts
		var expected := "Blind %s · Polster %s" % [BigNumber.short(run.blind_after_move(door_id)),
			BigNumber.factor(run.cushion(run.blind_after_move(door_id)))]
		assert_eq(label.text, expected)
	assert_not_null(_label("Move_" + _walk_target(String(walk[0]))))

func test_without_a_typical_score_only_the_blind_stands() -> void:
	run.round_scores.clear()
	view.open(run.floor_view_state())
	var target := _walk_target(String(run.walkable_doors()[0]))
	assert_eq(_label("Move_" + target).text, FloorMapView.MOVE_LINE % BigNumber.short(
		run.blind_after_move(String(run.walkable_doors()[0]))))

func test_a_cushion_below_one_reads_red() -> void:
	run.round_scores.assign([20])
	view.open(run.floor_view_state())
	var target := _walk_target(String(run.walkable_doors()[0]))
	assert_string_contains(_label("Move_" + target).text, "Polster ×0,1")
	assert_eq(_label("Move_" + target).modulate, FloorMapView.SHORT_COLOR)

func test_a_short_click_moves_and_reports_the_door() -> void:
	view.open(run.floor_view_state())
	var door_id := String(run.walkable_doors()[0])
	var at := view.room_rect(_walk_target(door_id)).get_center()
	assert_true(view.begin_press(at))
	view.drag_to(at + Vector2(3, 2))  # unter der Schwelle des Magazins
	assert_true(view.end_press(at + Vector2(3, 2)))
	assert_eq(chosen, [door_id] as Array[String])

func test_a_click_on_the_door_moves_too() -> void:
	view.open(run.floor_view_state())
	var door_id := String(run.walkable_doors()[0])
	var at := view.door_mark_rect(door_id).get_center()
	view.begin_press(at)
	view.end_press(at)
	assert_eq(chosen, [door_id] as Array[String])

func test_a_drag_over_the_threshold_never_moves_and_shifts_the_window() -> void:
	view.open(run.floor_view_state())
	var home := view.scroll
	var at := view.room_rect(_walk_target(String(run.walkable_doors()[0]))).get_center()
	view.begin_press(at)
	var step := PackDrawerView.DRAG_THRESHOLD + 60.0
	view.drag_to(at + Vector2(0, step))
	assert_true(view.dragging())
	view.end_press(at + Vector2(0, step))
	assert_true(chosen.is_empty(), "ein Zug zieht nie")
	assert_almost_eq(view.scroll, home + step, 0.5, "der Ausschnitt bleibt, wo er losgelassen wird")
	assert_true(view.scrolled_free())
	assert_true((view.find_child("ToPuck", true, false) as Button).visible, "„Zum Puck“ steht")

func test_a_drag_past_the_end_springs_back_into_the_tower() -> void:
	view.open(run.floor_view_state())
	var at := view.map_rect().get_center()
	view.begin_press(at)
	view.drag_to(at - Vector2(0, 2000))
	var span := view.scroll_range()
	assert_gt(view.scroll, span.x - 2000.0 * 0.5, "über das Ende nur gedämpft")
	view.end_press(at - Vector2(0, 2000))
	await wait_seconds(FloorMapView.SNAP_TIME + 0.1)
	assert_almost_eq(view.scroll, span.x, 0.5, "weich begrenzt")

func test_the_wheel_shifts_and_to_puck_brings_it_back() -> void:
	view.open(run.floor_view_state())
	var home := view.scroll
	assert_false((view.find_child("ToPuck", true, false) as Button).visible, "auf dem Puck kein Knopf")
	view.scroll_by(2.0)
	assert_gt(view.scroll, home, "das Rad schiebt den Turm hinauf")
	var button := view.find_child("ToPuck", true, false) as Button
	assert_true(button.visible)
	button.pressed.emit()
	await wait_seconds(FloorMapView.SNAP_TIME + 0.1)
	assert_almost_eq(view.scroll, home, 0.5)
	assert_false(view.scrolled_free())
	assert_false(button.visible)

func test_the_first_right_click_rule_snaps_back_only_when_shifted() -> void:
	view.open(run.floor_view_state())
	assert_false(view.scrolled_free(), "auf dem Puck verläßt der Rechtsklick die Station")
	view.scroll_by(-1.0)
	view.scroll_by(3.0)
	assert_true(view.scrolled_free(), "verschoben holt der erste Rechtsklick zurück")
	view.snap_to_puck(true)
	assert_false(view.scrolled_free())

func test_the_window_reaches_down_into_finished_floors() -> void:
	run.settle_block_deals()
	run.advance_round()
	view.open(run.floor_view_state())
	view.scroll_by(-8.0)
	var old := false
	for key in view.visible_room_keys():
		old = old or key.begins_with("1/raum")
	assert_true(old, "nach unten in die Geschichte")
	assert_not_null(view.find_child("H1_Room_*", true, false), "mit Namen, gedimmt")

func test_shifting_rebuilds_only_when_the_window_changes() -> void:
	view.open(run.floor_view_state())
	var label := _label("Head")
	var room_label := _label("Room_" + _walk_target(String(run.walkable_doors()[0])))
	var before := view.label_rect(room_label)
	view.begin_press(view.map_rect().get_center())
	view.drag_to(view.map_rect().get_center() + Vector2(0, 10))
	assert_same(_label("Head"), label)
	if is_instance_valid(room_label) and room_label.is_inside_tree():
		assert_almost_eq(view.label_rect(room_label).position.y, before.position.y + 10.0, 0.5,
			"die Beschriftung fährt mit")

func test_a_locked_door_shows_nothing_of_its_malus() -> void:
	var doors := _mixed_floor()
	run.floor_map.position = run.floor_map.door(doors["locked"])["a"]
	view.open(run.floor_view_state())
	var name_text := DealClause.find(String(doors["locked_malus"])).display_name
	var full := DealClause.text_for(String(doors["locked_malus"]))
	for child in view.find_children("*", "Label", true, false):
		var text := _unwrap((child as Label).text)
		assert_ne(text, name_text, "der Malus der gesperrten Tür steht nirgends")
		assert_ne(text, full)
	assert_null(_label("Mark_" + doors["locked"]), "gesperrt: nur das rote Kreuz")

func test_door_states_read_unknown_free_and_visited() -> void:
	var doors := _mixed_floor()
	for key in ["unknown", "free"]:
		var entry := run.floor_map.door(doors[key])
		run.floor_map.position = String(entry["a"])
		view.close()
		view.open(run.floor_view_state())
		var label := _label("Mark_" + doors[key])
		if label == null:
			continue  # die Tür liegt außerhalb des Ausschnitts dieses Standplatzes
		assert_eq(label.text, FloorMapView.UNKNOWN_TEXT if key == "unknown" else FloorMapView.FREE_TEXT)
	run.floor_map.rooms[_walk_target(String(run.walkable_doors()[0]))]["visited"] = true
	view.close()
	view.open(run.floor_view_state())
	var target := _walk_target(String(run.walkable_doors()[0]))
	assert_eq(_label("Visited_" + target).text, FloorMapView.VISITED_TEXT)
	assert_null(_label("Text_" + target), "besucht: kein Bonus mehr")

func test_the_office_is_a_red_band_and_its_doors_carry_the_boss_condition() -> void:
	var map := run.floor_map
	for entry in map.doors_from(map.office):
		var room_id := map.other_side(entry, map.office)
		map.position = room_id
		map.scout_from(room_id, _rng(12), Callable())
		break
	view.open(run.floor_view_state())
	assert_eq(_label("Room_" + map.office).text, "Büro · Boss-Runde")
	var shown := 0
	for entry in map.doors_from(map.office):
		var label := _label("MarkText_" + String(entry["id"]))
		if label == null:
			continue
		assert_eq(_unwrap(label.text), DealClause.text_for(String(entry["boss"])))
		shown += 1
	assert_gt(shown, 0)

## Der längste echte Klausel-Text paßt in seine Kachel bzw. Tür-Marke, ganz und ohne Wortbruch.
func test_every_clause_text_fits_its_tile_and_its_door() -> void:
	var door_id := String(run.walkable_doors()[0])
	var target := _walk_target(door_id)
	for clause in DealClause.all():
		for factor in [1, 2]:
			var text := DealClause.text_for(clause.id, factor)
			if clause.kind == DealClause.Kind.BONUS:
				run.floor_map.rooms[target]["bonus"] = clause.id
				view.close()
				view.open(run.floor_view_state(), factor)
				var label := _label("Text_" + target)
				assert_true(_fits(label), "%s paßt in die Kachel" % clause.id)
				_no_word_break(label, text)
				assert_true(view.room_rect(target).encloses(view.label_rect(label)))
			elif factor == 1:
				for entry in run.floor_map.doors_from(run.floor_map.position):
					if String(entry["id"]) == door_id:
						entry["malus"] = clause.id
						entry["boss"] = ""
						entry["scouted"] = true
						entry["free"] = false
				view.close()
				view.open(run.floor_view_state())
				var mark := _label("MarkText_" + door_id)
				assert_true(_fits(mark), "%s paßt in die Tür" % clause.id)
				_no_word_break(mark, text)

func test_texts_never_overlap() -> void:
	_stand_in_the_middle()
	run.round_scores.assign([600, 900])
	view.open(run.floor_view_state())
	var rects: Array[Rect2] = []
	var names: Array[String] = []
	for child in view.find_children("*", "Label", true, false):
		var label := child as Label
		if label.name.begins_with("Head"):
			continue
		rects.append(view.label_rect(label))
		names.append(String(label.name))
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			assert_false(rects[i].grow(-0.5).intersects(rects[j].grow(-0.5)),
				"%s überdeckt %s" % [names[i], names[j]])
	for room_id in run.floor_map.room_ids():
		for door: Dictionary in run.floor_view_state()["doors"]:
			assert_false(view.door_mark_rect(String(door["id"])).intersects(view.room_rect(room_id).grow(-1.0)),
				"Marke %s liegt auf %s" % [door["id"], room_id])

func test_the_head_names_floor_move_and_the_next_blind() -> void:
	view.open(run.floor_view_state())
	assert_eq(_label("Head").text, "Etage 1 · Zug 1")
	assert_eq(_label("HeadBlind").text, FloorMapView.NEXT_BLIND_HEAD % BigNumber.short(run.next_blind()))

func test_the_names_stand_large_enough_in_display_px() -> void:
	view.open(run.floor_view_state())
	var target := _walk_target(String(run.walkable_doors()[0]))
	assert_gte(_label("Room_" + target).get_theme_font_size("font_size"), 14)
	assert_gte(_label("Text_" + target).get_theme_font_size("font_size"), 10)

func test_a_read_only_view_never_moves_but_still_shifts() -> void:
	view.read_only = true
	view.open(run.floor_view_state())
	for room: Dictionary in run.floor_view_state()["rooms"]:
		var at := view.room_rect(String(room["id"])).get_center()
		view.begin_press(at)
		view.end_press(at)
	assert_true(chosen.is_empty())
	var home := view.scroll
	view.begin_press(view.map_rect().get_center())
	view.drag_to(view.map_rect().get_center() + Vector2(0, 40))
	view.end_press(view.map_rect().get_center() + Vector2(0, 40))
	assert_ne(view.scroll, home, "ansehen darf man")

func test_the_locked_door_flashes_once_but_stays_locked() -> void:
	var doors := _mixed_floor()
	view.open(run.floor_view_state(), 1, doors["locked"])
	assert_eq(view.flashing_door(), doors["locked"])
	await wait_seconds(FloorMapView.FLASH_TIME + 0.1)
	assert_eq(view.flashing_door(), "")

# --- Der STREIFEN der Startseite ---------------------------------------------------

func test_the_strip_carries_no_text_and_takes_no_click() -> void:
	var strip := _strip()
	strip.open(run.floor_view_state())
	assert_eq(strip.find_children("*", "Label", true, false).size(), 0, "Kacheln ohne Text")
	assert_gt(strip.visible_room_keys().size(), 0)
	var door_id := String(run.walkable_doors()[0])
	var at := strip.room_rect(_walk_target(door_id)).get_center()
	assert_false(strip.press_at(at), "gezogen wird in der Grube")
	assert_false(strip.begin_press(at))
	assert_true(chosen.is_empty())

func test_the_strip_explains_and_rests_on_the_pit() -> void:
	var strip := _strip()
	strip.open(run.floor_view_state())
	assert_eq(strip.info_parts()["body"], FloorMapView.IDLE_BODY)
	assert_eq(FloorMapView.IDLE_BODY, "Gewählt wird in der Grube.")
	var door_id := String(run.walkable_doors()[0])
	var target := _walk_target(door_id)
	strip.hover_at(strip.room_rect(target).get_center())
	var bonus := String(run.floor_map.rooms[target]["bonus"])
	assert_string_contains(strip.info_text(), DealClause.text_for(bonus))
	assert_string_contains(strip.info_text(), "Blind nach diesem Zug: %s (" % BigNumber.short(run.blind_after_move(door_id)))

func test_the_puck_stands_on_the_entrance_band() -> void:
	var strip := _strip()
	strip.open(run.floor_view_state())
	var here := strip.room_rect(run.floor_map.position)
	assert_true(strip.map_rect().encloses(here), "der Standraum steht im Ausschnitt")
	assert_true(strip.visible_room_keys().has("1/" + run.floor_map.entrance))

func test_the_window_follows_the_puck() -> void:
	var strip := _strip()
	strip.open(run.floor_view_state())
	var start := strip.scroll
	run.settle_block_deals()
	run.advance_round()
	run.move_through(String(run.walkable_doors()[0]))
	strip.open(run.floor_view_state())
	await wait_seconds(FloorMapView.SNAP_TIME + 0.1)
	assert_gt(strip.scroll, start, "eine Etage höher steht der Ausschnitt höher")
	var here := strip.room_rect(run.floor_map.position)
	assert_true(strip.map_rect().encloses(here))

func test_the_wheel_rolls_and_the_strip_snaps_back() -> void:
	for i in 3:
		run.settle_block_deals()
	run.advance_round()
	var strip := _strip()
	strip.open(run.floor_view_state())
	var home := strip.scroll
	strip.scroll_by(-4.0)
	assert_lt(strip.scroll, home, "das Rad rollt in die Geschichte")
	assert_true(strip.scrolled_free())
	strip.clear_hover()
	strip._process(FloorMapView.SNAP_BACK_DELAY + 0.1)
	await wait_seconds(FloorMapView.SNAP_TIME + 0.1)
	assert_almost_eq(strip.scroll, home, 0.5, "den Zeiger weg, zurück auf den Puck")

func test_only_the_window_is_drawn() -> void:
	for i in 12:
		run.settle_block_deals()
	var strip := _strip()
	strip.open(run.floor_view_state())
	assert_eq((strip.state["history"] as Array).size(), 12)
	assert_lte(strip.visible_floors().size(), 3, "der Turm ist hoch, gezeichnet wird der Ausschnitt")
	assert_false(strip.visible_floors().has(1))

func test_the_old_office_is_the_entrance_of_the_next_floor() -> void:
	run.settle_block_deals()
	var strip := _strip()
	strip.open(run.floor_view_state())
	assert_eq(strip.room_rect(run.floor_map.entrance, 2), strip.room_rect(run.floor_map.office, 1),
		"das Büro darunter ist der Standplatz")
	assert_false(strip.visible_room_keys().has("2/" + run.floor_map.entrance), "der Eingang wird nicht gezeichnet")

func test_a_fumble_lock_shows_at_once() -> void:
	view.open(run.floor_view_state())
	run.move_through(String(run.walkable_doors()[0]))
	var locked := run._lock_fumble_door()
	if locked == "":
		pass_test("kein Sperr-Kandidat in diesem Wurf")
		return
	view.open(run.floor_view_state(), 1, locked)
	for door: Dictionary in view.state["doors"]:
		if String(door["id"]) == locked:
			assert_eq(int(door["state"]), FloorMap.DoorState.LOCKED)
	assert_eq(view.flashing_door(), locked)
