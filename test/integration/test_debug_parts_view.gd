extends GutTest
## Das Debug-Werkzeug neben den Kombinationen: jedes Modul steht zur Wahl.

func _view() -> DebugPartsView:
	var view := DebugPartsView.new()
	add_child_autofree(view)
	return view

func test_every_part_has_a_button() -> void:
	var view := _view()
	assert_eq(view.buttons.size(), ComboPart.all().size())
	for part in ComboPart.all():
		assert_eq((view.buttons[part.id] as Button).text, part.display_name)

func test_the_list_opens_and_closes() -> void:
	var view := _view()
	assert_false(view.is_open())
	view.toggle.pressed.emit()
	assert_true(view.is_open())
	view.toggle.pressed.emit()
	assert_false(view.is_open())

func test_a_click_reports_the_part_and_keeps_the_list_open() -> void:
	var view := _view()
	view.toggle.pressed.emit()
	var chosen: Array[String] = []
	view.part_chosen.connect(func(id: String) -> void: chosen.append(id))
	(view.buttons[ComboPart.MAGNETRON] as Button).pressed.emit()
	assert_eq(chosen, [ComboPart.MAGNETRON] as Array[String])
	assert_true(view.is_open())

func test_the_list_is_sorted_by_rarity() -> void:
	var parts := DebugPartsView.sorted_parts()
	assert_eq(parts[0].rarity, ComboPart.RARITY_COMMON)
	assert_eq(parts[parts.size() - 1].rarity, ComboPart.RARITY_LEGENDARY)

func test_it_stands_on_its_right_bottom_corner() -> void:
	var view := _view()
	view.place(Vector2(1000.0, 2000.0))
	assert_eq(view.position + view.size, Vector2(1000.0, 2000.0))
	assert_lte(view.size.x, 256.0, "es paßt zwischen Anzeigerand und Kombinationen")

func test_only_buttons_take_clicks() -> void:
	var view := _view()
	await wait_frames(1)
	var center := view.toggle.get_global_rect().get_center()
	assert_true(TableScreen.interactive_under(view, center))
	assert_false(TableScreen.interactive_under(view, view.panel.get_global_rect().get_center()), "die Liste ist zu")
