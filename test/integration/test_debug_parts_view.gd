extends GutTest
## Das Debug-Werkzeug im Hub: jedes Modul steht zur Wahl.

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
	view.toggle_list()
	assert_true(view.is_open())
	view.toggle_list()
	assert_false(view.is_open())

func test_a_click_reports_the_part_and_keeps_the_list_open() -> void:
	var view := _view()
	view.toggle_list()
	var chosen: Array[String] = []
	view.part_chosen.connect(func(id: String) -> void: chosen.append(id))
	(view.buttons[ComboPart.HIGH_VOLTAGE_TUBE] as Button).pressed.emit()
	assert_eq(chosen, [ComboPart.HIGH_VOLTAGE_TUBE] as Array[String])
	assert_true(view.is_open())

func test_the_list_is_sorted_by_rarity() -> void:
	var parts := DebugPartsView.sorted_parts()
	assert_eq(parts[0].rarity, ComboPart.RARITY_COMMON)
	assert_eq(parts[parts.size() - 1].rarity, ComboPart.RARITY_LEGENDARY)

func test_it_stands_centered_and_fits_the_hub() -> void:
	var view := _view()
	var hub := Vector2(1068.0, 1125.0)
	view.center_in(hub)
	assert_almost_eq(view.position.x + view.size.x * 0.5, hub.x * 0.5, 1.0)
	assert_lte(view.size.x, hub.x, "es paßt in die Hub-Fläche")
	assert_lte(view.size.y, hub.y)

func test_only_buttons_take_clicks() -> void:
	var view := _view()
	await wait_frames(1)
	var button: Button = view.buttons[ComboPart.HIGH_VOLTAGE_TUBE]
	assert_false(TableScreen.interactive_under(view, button.get_global_rect().get_center()),
		"die Liste ist zu")
	view.toggle_list()
	assert_true(TableScreen.interactive_under(view, button.get_global_rect().get_center()))
