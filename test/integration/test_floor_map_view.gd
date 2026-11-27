extends GutTest
## Die ETAGEN-KARTE als TURM (FloorMapView): die große Karte (Namen, Marken, Auskunft) und
## der STREIFEN der Startseite (compact: ohne Text, der Ausschnitt folgt dem Puck). Beide
## teilen Geometrie, Zug-Regel und Auskunft.

## Das Maß der großen Karte auf ihrer Hub-Seite (Hub 1068 × 1125).
const MAP_SIZE := Vector2(1034, 960)
## Das Maß des Streifens auf der Startseite.
const STRIP_SIZE := Vector2(360, 740)
const STRIP_UNIT := 10.68

var view: FloorMapView
var run: GameRun
var chosen: Array[String] = []
var opened := 0

func before_each() -> void:
	run = GameRun.new_run()
	run.advance_round()  # ab Runde 2 ist ein Zug fällig
	view = add_child_autofree(FloorMapView.new())
	view.size = MAP_SIZE
	chosen.clear()
	opened = 0
	view.door_chosen.connect(func(door_id: String) -> void: chosen.append(door_id))
	view.open_requested.connect(func() -> void: opened += 1)

func _strip() -> FloorMapView:
	var strip: FloorMapView = add_child_autofree(FloorMapView.new())
	strip.compact = true
	strip.unit_px = STRIP_UNIT
	strip.size = STRIP_SIZE
	strip.door_chosen.connect(func(door_id: String) -> void: chosen.append(door_id))
	strip.open_requested.connect(func() -> void: opened += 1)
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

func _label(node_name: String) -> Label:
	return view.find_child(node_name, true, false) as Label

func _label_texts() -> Array[String]:
	var texts: Array[String] = []
	for child in view.find_children("*", "Label", true, false):
		texts.append(_unwrap((child as Label).text))
	return texts

## Der Text einer Kachel, wie er gemeint ist: eine Wortfuge („Kalt-“ + klein) fällt
## weg, ein echter Bindestrich („Blind-“ + groß) bleibt.
func _plain(label: Label) -> String:
	return _unwrap(label.text)

func _unwrap(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("-\\n(?=[a-zäöüß])")
	return regex.sub(text, "", true).replace("-\n", "-").replace("\n", " ")

# --- Die große Karte: senkrecht, mit Namen --------------------------------------------

func test_the_floor_reads_from_bottom_to_top() -> void:
	view.open(run.floor_view_state())
	var entrance := view.room_rect(run.floor_map.entrance)
	var office := view.room_rect(run.floor_map.office)
	assert_gt(entrance.position.y, office.position.y, "der Eingang unten, das Büro oben")
	for room: Dictionary in run.floor_view_state()["rooms"]:
		if bool(room["entrance"]) or bool(room["office"]):
			continue
		var rect := view.room_rect(String(room["id"]))
		assert_true(rect.end.y <= entrance.position.y and rect.position.y >= office.end.y,
			"%s steht zwischen Eingang und Büro" % room["id"])

func test_every_room_is_a_tile_with_its_name() -> void:
	view.open(run.floor_view_state())
	for room: Dictionary in run.floor_view_state()["rooms"]:
		if bool(room["entrance"]) or bool(room["office"]):
			continue
		var label := _label("Room_" + String(room["id"]))
		assert_not_null(label, "Kachel für %s" % room["id"])
		assert_eq(_plain(label), String(room["name"]))

func test_room_tiles_never_overlap_and_marks_stay_off_tiles() -> void:
	_mixed_floor()
	view.open(run.floor_view_state())
	var rooms: Array = run.floor_view_state()["rooms"]
	for i in rooms.size():
		var a := view.room_rect(String(rooms[i]["id"]))
		for j in range(i + 1, rooms.size()):
			assert_false(a.intersects(view.room_rect(String(rooms[j]["id"]))), "Kacheln überlappen")
		for door: Dictionary in run.floor_view_state()["doors"]:
			var mark := view.door_mark_rect(String(door["id"]))
			assert_false(mark.intersects(a.grow(-1.0)), "Marke %s liegt auf %s" % [door["id"], rooms[i]["id"]])

func test_the_bonus_name_stands_on_an_unvisited_room() -> void:
	view.open(run.floor_view_state())
	for room_id in run.floor_map.room_ids():
		var bonus := String(run.floor_map.rooms[room_id]["bonus"])
		var label := _label("Bonus_" + room_id)
		assert_not_null(label)
		assert_eq(_plain(label), DealClause.find(bonus).display_name)

func test_marks_follow_the_door_state() -> void:
	var doors := _mixed_floor()
	view.open(run.floor_view_state())
	assert_null(_label("Mark_" + doors["passed"]), "ausgebrannt: nur der helle Weg")
	assert_null(_label("Mark_" + doors["locked"]), "gesperrt: ohne Inhalt")
	assert_eq(_label("Mark_" + doors["unknown"]).text, FloorMapView.UNKNOWN_TEXT)
	assert_eq(_label("Mark_" + doors["free"]).text, FloorMapView.FREE_TEXT)
	for entry in run.floor_map.doors:
		if int(entry["state"]) != FloorMap.DoorState.OPEN or not bool(entry["scouted"]) or bool(entry["free"]):
			continue
		var clause := String(entry["boss"]) if String(entry["boss"]) != "" else String(entry["malus"])
		assert_eq(_plain(_label("Mark_" + String(entry["id"]))), DealClause.find(clause).display_name)

func test_office_doors_show_the_boss_condition_from_the_start() -> void:
	view.open(run.floor_view_state())
	for entry in run.floor_map.doors_from(run.floor_map.office):
		assert_eq(_plain(_label("Mark_" + String(entry["id"]))),
			DealClause.find(String(entry["boss"])).display_name)

func test_a_locked_door_shows_nothing_of_its_malus() -> void:
	var doors := _mixed_floor()
	view.open(run.floor_view_state())
	var name_text := DealClause.find(String(doors["locked_malus"])).display_name
	assert_false(_label_texts().has(name_text), "der Malus der gesperrten Tür steht nirgends")
	view.hover_at(view.door_mark_rect(doors["locked"]).get_center())
	assert_string_contains(view.info_text(), FloorMapView.LOCKED_TITLE)
	assert_false(view.info_text().contains(name_text))

## Kein Name bricht mitten im Wort: er wird kleiner oder bricht an einer Wortfuge.
func test_long_names_never_break_inside_a_word() -> void:
	view.open(run.floor_view_state())
	var font := view.get_theme_font("font", "Label")
	var u := view.unit()
	var m := view.metrics()
	var mark := Vector2(float(m["lane_gap"]) - u * 1.1, float(m["tile_h"]) * 0.86 - u * 0.6)
	var tile := Vector2(float(m["tile_w"]) - u * 2.0, float(m["tile_h"]) * 0.42)
	for text in ["Standardprotokoll", "Wackelkontakt", "Hohe Erwartungen", "Kaltverfestigung"]:
		for box: Vector2 in [mark, tile]:
			var fit := FloorMapView.fit_name(text, font, box.x, box.y,
				int(u * FloorMapView.MARK_UNITS.x), int(u * FloorMapView.MARK_UNITS.y))
			var lines: PackedStringArray = fit["lines"]
			var allowed: Array[String] = []
			for word in text.split(" "):
				allowed.append(word)
				allowed.append_array(Array(FloorMapView.word_parts(word)))
			for line in lines:
				for token in line.split(" ", false):
					assert_true(allowed.has(token), "%s: „%s“ ist kein ganzes Wort und keine Fuge" % [text, token])
				assert_lte(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit["px"])).x,
					box.x + 0.5, "%s paßt in die Breite" % text)
			assert_eq("".join(lines).replace("-", "").replace(" ", ""),
				text.replace("-", "").replace(" ", ""), "nichts fehlt")
			assert_gte(int(fit["px"]), int(u * FloorMapView.MARK_UNITS.y), "%s lesbar" % text)

func test_names_stand_large_enough() -> void:
	view.open(run.floor_view_state())
	for room_id in run.floor_map.room_ids():
		var px := _label("Room_" + room_id).get_theme_font_size("font_size")
		assert_gte(px, 22, "Raumname mindestens 22 Display-px")
	for child in view.find_children("Mark_*", "Label", true, false):
		if true:
			assert_gte((child as Label).get_theme_font_size("font_size"), 18, "Tür-Marke mindestens 18")

func test_only_walkable_neighbours_take_the_click() -> void:
	var state := run.floor_view_state()
	view.open(state)
	var walk: Array = state["walkable"]
	assert_gt(walk.size(), 0)
	for room: Dictionary in state["rooms"]:
		chosen.clear()
		var room_id := String(room["id"])
		var expected := ""
		for door_id: String in walk:
			var entry := run.floor_map.door(door_id)
			if run.floor_map.other_side(entry, run.floor_map.position) == room_id:
				expected = door_id
		var took := view.press_at(view.room_rect(room_id).get_center())
		if expected == "":
			assert_false(took, "%s nimmt keinen Klick" % room_id)
			assert_true(chosen.is_empty())
		else:
			assert_true(took)
			assert_eq(chosen, [expected] as Array[String], "%s meldet seine Tür" % room_id)
	assert_eq(opened, 0, "die große Karte schlägt sich nicht selbst auf")

func test_a_walkable_door_mark_takes_the_click_too() -> void:
	var walk: Array = run.floor_view_state()["walkable"]
	view.open(run.floor_view_state())
	assert_true(view.press_at(view.door_mark_rect(String(walk[0])).get_center()))
	assert_eq(chosen, [String(walk[0])] as Array[String])

func test_without_a_due_move_nothing_takes_the_click() -> void:
	run.move_due = false
	view.open(run.floor_view_state())
	for room: Dictionary in run.floor_view_state()["rooms"]:
		assert_false(view.press_at(view.room_rect(String(room["id"])).get_center()))
	assert_true(chosen.is_empty())

func test_the_info_names_the_bonus_and_the_blind_after_the_move() -> void:
	var state := run.floor_view_state()
	view.open(state, 2)
	var door_id := String((state["walkable"] as Array)[0])
	var target := run.floor_map.other_side(run.floor_map.door(door_id), run.floor_map.position)
	var bonus := String(run.floor_map.rooms[target]["bonus"])
	view.hover_at(view.room_rect(target).get_center())
	assert_string_contains(view.info_text(), DealClause.text_for(bonus, 2), "voller Bonus-Text mit Faktor")
	assert_string_contains(view.info_text(),
		"Blind nach diesem Zug: %s (" % BigNumber.short(run.blind_after_move(door_id)))

func test_the_info_names_the_cushion_of_the_move() -> void:
	run.round_scores.assign([600, 900])
	var state := run.floor_view_state()
	view.open(state)
	var door_id := String((state["walkable"] as Array)[0])
	var target := run.floor_map.other_side(run.floor_map.door(door_id), run.floor_map.position)
	view.hover_at(view.room_rect(target).get_center())
	var cushion := run.cushion(run.blind_after_move(door_id))
	assert_string_contains(view.info_text(), FloorMapView.CUSHION_PART % BigNumber.factor(cushion))
	assert_ne(view.info_parts()["move_color"], FloorMapView.SHORT_COLOR, "über ×1 nicht rot")
	assert_false(_label("InfoMove").get_rect().intersects(_label("InfoTitle").get_rect()),
		"Titel und Zug-Zeile teilen sich die Zeile")

func test_a_cushion_below_one_reads_red() -> void:
	run.round_scores.assign([20])
	var state := run.floor_view_state()
	view.open(state)
	var door_id := String((state["walkable"] as Array)[0])
	view.hover_at(view.door_mark_rect(door_id).get_center())
	assert_string_contains(view.info_text(), "Polster ×0,1")
	assert_eq(_label("InfoMove").modulate, FloorMapView.SHORT_COLOR)

func test_without_a_typical_score_the_cushion_stays_out() -> void:
	run.round_scores.clear()
	var state := run.floor_view_state()
	view.open(state)
	view.hover_at(view.door_mark_rect(String((state["walkable"] as Array)[0])).get_center())
	assert_string_contains(view.info_text(), "Blind nach diesem Zug")
	assert_false(view.info_text().contains("Polster"), "ohne typischen Wert kein Polster")

func test_the_head_names_floor_move_and_the_next_blind_before_the_move() -> void:
	view.open(run.floor_view_state())
	assert_eq(_label("Head").text, "Etage 1 · Zug 1")
	assert_eq(_label("HeadBlind").text, FloorMapView.NEXT_BLIND_HEAD % run.next_blind())

func test_the_entrance_and_the_office_head() -> void:
	var fresh := GameRun.new_run()
	view.open(fresh.floor_view_state())
	assert_eq(_label("Head").text, "Etage 1 · Eingang")
	var state := fresh.floor_view_state()
	state["position"] = state["office"]
	view.open(state)
	assert_eq(_label("Head").text, FloorMapView.OFFICE_HEAD % 1)
	assert_eq(_label("Head").modulate, FloorMapView.LOCKED_COLOR, "die Boss-Runde rot")

func test_the_locked_door_flashes_once_but_stays_locked() -> void:
	var doors := _mixed_floor()
	view.open(run.floor_view_state(), 1, doors["locked"])
	assert_eq(view.flashing_door(), doors["locked"])
	assert_null(_label("Mark_" + doors["locked"]), "Endzustand zuerst: gesperrt gemalt")
	await wait_seconds(FloorMapView.FLASH_TIME + 0.1)
	assert_eq(view.flashing_door(), "")

func test_disabled_moves_take_no_click_but_still_explain() -> void:
	var state := run.floor_view_state()
	view.open(state)
	view.set_moves_enabled(false)
	var door_id := String((state["walkable"] as Array)[0])
	var target := run.floor_map.other_side(run.floor_map.door(door_id), run.floor_map.position)
	assert_false(view.press_at(view.room_rect(target).get_center()))
	view.hover_at(view.room_rect(target).get_center())
	assert_false(view.info_text().contains("Blind nach diesem Zug"))
	view.set_moves_enabled(true)
	assert_true(view.press_at(view.room_rect(target).get_center()))

func test_a_read_only_map_never_takes_a_move() -> void:
	view.read_only = true
	view.open(run.floor_view_state())
	for room: Dictionary in run.floor_view_state()["rooms"]:
		assert_false(view.press_at(view.room_rect(String(room["id"])).get_center()))
	assert_true(chosen.is_empty())

func test_the_hover_info_falls_when_the_pointer_leaves() -> void:
	var state := run.floor_view_state()
	view.open(state)
	var idle := view.info_text()
	var room_id := run.floor_map.room_ids()[0]
	view.hover_at(view.room_rect(room_id).get_center())
	assert_ne(view.info_text(), idle)
	view.clear_hover()
	assert_eq(view.info_text(), idle, "ohne Zeiger die Ruhe-Auskunft")
	view.hover_at(view.room_rect(room_id).get_center())
	view.notification(Control.NOTIFICATION_MOUSE_EXIT)
	assert_eq(view.info_text(), idle, "mouse_exited räumt ebenso")

func test_an_unchanged_state_keeps_the_hover_and_builds_nothing() -> void:
	view.open(run.floor_view_state())
	var room_id := run.floor_map.room_ids()[0]
	view.hover_at(view.room_rect(room_id).get_center())
	var label := _label("Head")
	view.open(run.floor_view_state())
	assert_same(_label("Head"), label, "derselbe Zustand baut nicht neu")
	assert_eq(view.hovered()["id"], room_id)

func test_the_big_map_scrolls_down_into_the_history() -> void:
	run.settle_block_deals()
	run.advance_round()
	view.open(run.floor_view_state())
	for key in view.visible_room_keys():
		assert_false(key.begins_with("1/raum"), "die laufende Etage füllt die Karte: %s" % key)
	view.scroll_by(-6.0)
	var old := false
	for key in view.visible_room_keys():
		old = old or key.begins_with("1/raum")
	assert_true(old, "nach unten in die Geschichte")
	assert_not_null(_label("H1_Room_" + run.floor_map.room_ids()[0]), "mit Namen, gedimmt")

# --- Der STREIFEN der Startseite ---------------------------------------------------

func test_the_strip_carries_no_text() -> void:
	var strip := _strip()
	strip.open(run.floor_view_state())
	assert_eq(strip.find_children("*", "Label", true, false).size(), 0, "Kacheln ohne Text")
	assert_gt(strip.visible_room_keys().size(), 0)

func test_a_walkable_tile_of_the_strip_reports_its_door() -> void:
	var strip := _strip()
	var state := run.floor_view_state()
	strip.open(state)
	var door_id := String((state["walkable"] as Array)[0])
	var target := run.floor_map.other_side(run.floor_map.door(door_id), run.floor_map.position)
	assert_true(strip.press_at(strip.room_rect(target).get_center()))
	assert_eq(chosen, [door_id] as Array[String])
	assert_eq(opened, 0)

func test_a_click_beside_a_move_opens_the_big_map() -> void:
	var strip := _strip()
	strip.open(run.floor_view_state())
	for room_id in run.floor_map.room_ids():
		if strip.door_to(room_id) == "" and strip.room_rect(room_id).intersects(strip.map_rect()):
			assert_true(strip.press_at(strip.room_rect(room_id).get_center()))
			break
	assert_eq(opened, 1, "Karte öffnen")
	assert_true(chosen.is_empty())

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
	assert_gt(here.get_center().y, strip.map_rect().size.y * 0.5, "der Puck im unteren Teil")

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
	assert_true(strip.press_at(strip.foot_rect().get_center()), "die Fußzeile rastet ein")
	await wait_seconds(FloorMapView.SNAP_TIME + 0.1)
	assert_almost_eq(strip.scroll, home, 0.5)
	strip.scroll_by(-4.0)
	strip.clear_hover()
	strip._process(FloorMapView.SNAP_BACK_DELAY + 0.1)
	await wait_seconds(FloorMapView.SNAP_TIME + 0.1)
	assert_almost_eq(strip.scroll, home, 0.5, "den Zeiger weg, zurück auf den Puck")
	strip.scroll_by(-4.0)
	run.move_through(String(run.walkable_doors()[0]))
	strip.open(run.floor_view_state())
	assert_false(strip.scrolled_free(), "ein Zug rastet zurück")

func test_only_the_window_is_drawn() -> void:
	for i in 12:
		run.settle_block_deals()
	var strip := _strip()
	strip.open(run.floor_view_state())
	assert_eq((strip.state["history"] as Array).size(), 12)
	assert_lte(strip.visible_floors().size(), 3, "der Turm ist hoch, gezeichnet wird der Ausschnitt")
	assert_false(strip.visible_floors().has(1))
	assert_lte(strip.visible_room_keys().size(), 3 * (FloorMap.ROOM_COUNT + 2))

func test_a_finished_floor_explains_but_takes_no_move() -> void:
	run.settle_block_deals()
	run.advance_round()
	var strip := _strip()
	strip.open(run.floor_view_state())
	strip.scroll_by(-3.0)
	var history: Dictionary = (strip.state["history"] as Array)[0]
	for room: Dictionary in history["rooms"]:
		if bool(room["entrance"]) or bool(room["office"]):
			continue
		var rect := strip.room_rect(String(room["id"]), 1)
		if not strip.map_rect().encloses(rect):
			continue
		var target := strip.target_at(rect.get_center())
		assert_eq(int(target["floor"]), 1)
		assert_eq(strip.move_for(target), "", "geschafft ist geschafft")
		strip.hover_at(rect.get_center())
		assert_string_contains(strip.info_text(), String(room["name"]))
		return
	fail_test("keine Kachel der alten Etage im Ausschnitt")

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
