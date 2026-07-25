extends GutTest
## Tests des Titel-HUDs (TitleView): drei Karten auf einer Fläche, von denen
## immer genau EINE sichtbar ist, der Rückweg auf die Menü-Karte und die
## Meldung geänderter Einstellungen (anwenden/sichern tut scene_root).

var view: TitleView

func before_each() -> void:
	view = TitleView.new()
	view.size = Vector2(1000, 1050)
	add_child_autofree(view)
	view.layout()

func _visible_cards() -> int:
	var count := 0
	for key: TitleView.Card in view._cards:
		if view._cards[key].visible:
			count += 1
	return count

func test_the_menu_card_opens_first() -> void:
	assert_eq(_visible_cards(), 1)
	assert_true(view._cards[TitleView.Card.MENU].visible)

func test_only_one_card_shows_at_a_time() -> void:
	view.show_card(TitleView.Card.SETTINGS)
	assert_eq(_visible_cards(), 1)
	assert_true(view._cards[TitleView.Card.SETTINGS].visible)
	assert_false(view._cards[TitleView.Card.MENU].visible)

func test_going_back_returns_to_the_menu() -> void:
	view.show_card(TitleView.Card.CREDITS)
	assert_true(view.go_back(), "die Unterkarte verbraucht den Rückwärts-Klick")
	assert_true(view._cards[TitleView.Card.MENU].visible)

func test_the_menu_card_has_nowhere_to_go_back_to() -> void:
	assert_false(view.go_back(), "auf der Menü-Karte bleibt der Klick frei")

func test_resume_appears_only_with_a_running_game() -> void:
	assert_false(view.resume_button.visible, "am Startbildschirm wartet kein Lauf")
	assert_false(view.is_resumable())
	view.set_resumable(true)
	assert_true(view.resume_button.visible)
	assert_true(view.is_resumable())

func test_loaded_settings_reach_the_controls_without_a_report() -> void:
	var reports := []
	view.settings_changed.connect(func() -> void: reports.append(true))
	var loaded := GameSettings.new()
	loaded.master_volume = 0.3
	loaded.fullscreen = true
	view.set_settings(loaded)
	assert_almost_eq(view.volume_slider.value, 0.3, 0.0001)
	assert_true(view.fullscreen_check.button_pressed)
	assert_eq(view.fullscreen_check.text, "an", "der Schalter beschriftet sich mit")
	assert_eq(reports.size(), 0, "Übernehmen ist keine Änderung des Spielers")

func test_moving_the_slider_reports_the_change() -> void:
	var reports := []
	view.settings_changed.connect(func() -> void: reports.append(true))
	view.volume_slider.value = 0.5
	assert_almost_eq(view.settings.master_volume, 0.5, 0.0001)
	assert_eq(view.volume_value.text, "50%")
	assert_eq(reports.size(), 1)
