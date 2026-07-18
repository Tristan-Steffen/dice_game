extends GutTest
## Tests der Überladungs-Anzeige am Zielbalken (TableScreen): Fortschritt der
## aktuellen Stufe (obere Bahn), die volle Basis-Bahn der bereits gefüllten
## Stufen, Stufenfarben, Beschriftung mit/ohne ×N und Rollover-Erkennung.

func _screen() -> TableScreen:
	var ts: TableScreen = add_child_autofree(TableScreen.new())
	ts.place_goal_bar(Vector2(2000, 1000))
	return ts

func _full_w() -> float:
	return TableScreen.GOAL_BAR_SIZE.x - TableScreen.GOAL_BAR_INSET * 2.0

func test_label_has_multiplier_once_a_stage_is_cleared() -> void:
	var ts := _screen()
	ts.set_goal_progress(50, 300, 2, 1)
	assert_true("50 / 300" in ts.goal_bar_label.text)
	assert_true("×1" in ts.goal_bar_label.text, "ab Stufe 1 zeigt der Balken ×N")

func test_label_has_no_multiplier_on_first_stage() -> void:
	var ts := _screen()
	ts.set_goal_progress(75, 150, 1, 0)
	assert_eq(ts.goal_bar_label.text, "75 / 150")

func test_current_fill_is_within_stage() -> void:
	var ts := _screen()
	ts.set_goal_progress(150, 300, 2, 1)  # halbe Stufe 2
	assert_almost_eq(ts.goal_bar_fill.size.x, _full_w() * 0.5, 1.0)

func test_base_bar_full_when_stage_cleared() -> void:
	var ts := _screen()
	ts.set_goal_progress(50, 300, 2, 1)  # Stufe 1 gefüllt
	assert_almost_eq(ts.goal_bar_base.size.x, _full_w(), 1.0, "Basis-Bahn voll")
	assert_true(ts.goal_bar_base.color.is_equal_approx(TableScreen.GOAL_STAGE_FILL_COLORS[0]),
		"Basis in der Farbe der letzten Stufe (Gold)")

func test_no_base_bar_on_first_stage() -> void:
	var ts := _screen()
	ts.set_goal_progress(75, 150, 1, 0)
	assert_almost_eq(ts.goal_bar_base.size.x, 0.0, 1.0, "vor der ersten Überladung keine Basis-Bahn")

func test_current_fill_uses_next_stage_color() -> void:
	var ts := _screen()
	ts.set_goal_progress(10, 150, 1, 0)  # Stufe 1 läuft -> Gold
	assert_true(ts.goal_bar_fill.color.is_equal_approx(TableScreen.GOAL_STAGE_FILL_COLORS[0]))
	ts.set_goal_progress(10, 300, 2, 1)  # Stufe 2 läuft -> Cyan
	assert_true(ts.goal_bar_fill.color.is_equal_approx(TableScreen.GOAL_STAGE_FILL_COLORS[1]),
		"neue Stufe startet in neuer Farbe")

func test_rollover_tracks_last_cleared() -> void:
	var ts := _screen()
	ts.set_goal_progress(120, 150, 1, 0)
	assert_eq(ts._goal_last_cleared, 0)
	ts.set_goal_progress(50, 300, 2, 1)  # gerade Stufe 1 gefüllt
	assert_eq(ts._goal_last_cleared, 1, "Rollover merkt sich die gefüllte Stufe")
