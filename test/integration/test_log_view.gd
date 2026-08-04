extends GutTest
## Integrationstest des Rückblick-Fensters (LogView): die Chronik-Liste auf dem
## Grubenboden und die schmale Schritt-Leiste am oberen Grubenrand sind DASSELBE
## Control in zwei Zuständen - der Wechsel darf weder Rechteck noch Signale
## verlieren, sonst steht der Rückblick über den posierten Würfeln.

var view: LogView

const LIST_RECT := Rect2(40, 20, 900, 320)
const BAR_RECT := Rect2(40, 20, 900, 46)

func _rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append({"label": "Wurf: 5 · 5 · 3 · 2 · 2 · 1", "hand_index": 0, "kind": RoundLog.ENTRY_THROW})
	rows.append({"label": "Zug: Drilling — 350 Punkte", "hand_index": 0, "kind": RoundLog.ENTRY_TAKE})
	rows.append({"label": "Wurf: 6 · 4 · 1", "hand_index": 1, "kind": RoundLog.ENTRY_THROW})
	return rows

func before_each() -> void:
	view = LogView.new()
	add_child_autofree(view)
	view.set_list_rect(LIST_RECT)
	view.set_bar_rect(BAR_RECT)
	view.open(_rows())

func test_the_list_shows_every_entry() -> void:
	await wait_frames(2)
	assert_eq(view._row_buttons.size(), 3, "je Eintrag eine Zeile")
	for row_button in view._row_buttons:
		assert_gt(row_button.get_global_rect().size.x, 0.0, "jede Zeile hat Fläche")

func test_the_list_groups_by_hand() -> void:
	await wait_frames(2)
	var headings: Array[String] = []
	for label in _labels_in(view):
		if label.text.begins_with("Hand "):
			headings.append(label.text)
	assert_eq(headings, ["Hand 1", "Hand 2"] as Array[String], "je Hand eine Überschrift")

func test_clicking_a_row_reports_its_index() -> void:
	await wait_frames(2)
	var seen: Array[int] = []
	view.entry_selected.connect(func(index: int) -> void: seen.append(index))
	view._row_buttons[1].pressed.emit()
	assert_eq(seen, [1] as Array[int], "die Zeile meldet ihren Platz")

func test_the_list_takes_the_pit_floor_and_the_bar_the_rim() -> void:
	await wait_frames(2)
	assert_eq(view.size, LIST_RECT.size, "die Liste nimmt den ganzen Boden")
	view.set_compact(true)
	await wait_frames(2)
	assert_eq(view.size, BAR_RECT.size, "die Leiste bleibt am Rand")
	assert_eq(view._row_buttons.size(), 0, "im Leisten-Zustand steht keine Liste mehr")

func test_the_bar_reports_both_step_directions() -> void:
	view.set_compact(true)
	await wait_frames(2)
	var deltas: Array[int] = []
	view.step_requested.connect(func(delta: int) -> void: deltas.append(delta))
	_press(view, "◀")
	_press(view, "▶")
	assert_eq(deltas, [-1, 1] as Array[int], "beide Pfeile melden ihre Richtung")

func test_the_bar_leads_back_to_the_list() -> void:
	view.set_compact(true)
	await wait_frames(2)
	_press(view, "Liste")
	await wait_frames(2)
	assert_false(view.compact, "der Rückblick steht wieder als Liste")
	assert_eq(view._row_buttons.size(), 3, "und trägt seine Zeilen wieder")

func test_the_bar_names_entry_and_step() -> void:
	view.set_compact(true)
	await wait_frames(2)
	view.set_cursor(1, 6, 23, "Würfel 5 · +5 Punkte")
	assert_string_contains(view._title_label.text, "Schritt 7/23")
	assert_string_contains(view._title_label.text, "Zug: Drilling")
	assert_eq(view._step_label.text, "Würfel 5 · +5 Punkte")

func test_closing_is_reported_from_both_states() -> void:
	await wait_frames(2)
	var closes: Array[int] = []
	view.close_requested.connect(func() -> void: closes.append(1))
	_press(view, "Schließen")
	view.set_compact(true)
	await wait_frames(2)
	_press(view, "Schließen")
	assert_eq(closes.size(), 2, "beide Zustände tragen den Schließen-Knopf")

func test_hit_only_answers_for_the_visible_rect() -> void:
	await wait_frames(2)
	assert_true(view.hit(LIST_RECT.position + LIST_RECT.size / 2.0), "die Mitte gehört dem Rückblick")
	assert_false(view.hit(LIST_RECT.position - Vector2(20, 20)), "davor nicht")
	view.close()
	assert_false(view.hit(LIST_RECT.position + LIST_RECT.size / 2.0), "geschlossen trifft nichts")

func test_an_empty_round_says_so() -> void:
	view.open([] as Array[Dictionary])
	await wait_frames(2)
	assert_eq(view._row_buttons.size(), 0, "keine Zeilen")
	var texts: Array[String] = []
	for label in _labels_in(view):
		texts.append(label.text)
	assert_has(texts, LogView.EMPTY_TEXT)

func _labels_in(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	for child in node.get_children():
		if child is Label:
			found.append(child)
		found.append_array(_labels_in(child))
	return found

func _press(node: Node, text: String) -> void:
	for button in _buttons_in(node):
		if button.text == text:
			button.pressed.emit()
			return
	fail_test("Knopf '%s' steht nicht im Rückblick" % text)

func _buttons_in(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	for child in node.get_children():
		if child is Button:
			found.append(child)
		found.append_array(_buttons_in(child))
	return found
