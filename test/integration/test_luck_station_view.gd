extends GutTest
## Die GLÜCKS-STATION meldet nur noch Rechtecke: jedes Teil liegt in ihrem Feld, der Sitz
## mitten im Sockel, das Kreuz im Chip - und die Zeilen sagen, was GameRun sagt.

func _view(at := Vector2(233.0, 570.0)) -> LuckStationView:
	var view := LuckStationView.new()
	view.size = at
	add_child_autofree(view)
	return view

func test_placed_right_of_the_tray_with_its_top_and_height() -> void:
	var tray := Rect2(Vector2(1000, 2000), Vector2(388.4, 570.0))
	var rect := LuckStationView.placed_beside(tray, 23.4)
	assert_almost_eq(rect.position.x, tray.end.x + 23.4, 0.001)
	assert_eq(rect.position.y, tray.position.y)
	assert_eq(rect.size.y, tray.size.y)
	assert_almost_eq(rect.size.x, tray.size.x * LuckStationView.WIDTH_SHARE, 0.001)
	var narrow := LuckStationView.placed_beside(tray, 23.4, tray.end.x + 123.4)
	assert_almost_eq(narrow.end.x, tray.end.x + 123.4, 0.001, "nie über fremdes Möbel")

func test_every_part_lies_inside_the_field() -> void:
	for at: Vector2 in [Vector2(233.0, 570.0), Vector2(150.0, 570.0), Vector2(233.0, 300.0)]:
		var view := _view(at)
		var bounds := Rect2(Vector2.ZERO, at).grow(0.01)
		var lay := view.layout()
		for key: String in LuckStationView.PARTS:
			assert_true(bounds.encloses(lay[key]), "%s in %s" % [key, at])
		for face in 6:
			assert_true((lay["net"] as Rect2).grow(0.01).encloses(view.cell_rect(face)),
				"Zelle %d im Kreuz" % face)
			assert_true((lay["chip"] as Rect2).encloses(view.cell_rect(face)), "Zelle %d im Chip" % face)
		assert_true((lay["socket"] as Rect2).has_point(view.seat_px()), "der Sitz liegt im Sockel")
		assert_gt(view.net_cell(), 0.0)

func test_parts_stand_top_to_bottom_without_overlap() -> void:
	var view := _view()
	var lay := view.layout()
	var keys := ["socket", "traces", "chip", "gauge", "free"]
	for i in keys.size() - 1:
		assert_lte((lay[keys[i]] as Rect2).end.y, (lay[keys[i + 1]] as Rect2).position.y + 0.01,
			"%s über %s" % [keys[i], keys[i + 1]])
	assert_false((lay["lever"] as Rect2).intersects(lay["socket"]), "der Hebel steht neben dem Sockel")

func test_the_lines_read_like_the_plan() -> void:
	assert_eq(LuckStationView.expected_text(13.0 / 6.0), "Ø 2,2 Wahlen")
	assert_eq(LuckStationView.expected_digits(2.0), "2,0")
	var state := {"luck": 8, "prev": 6, "next": 10, "free_bonus": 0, "keeps": 0}
	assert_eq(LuckStationView.gauge_text(state), "Glück 8 · Auge bei 10")
	assert_almost_eq(LuckStationView.gauge_share(state), 0.5, 0.0001)
	var full := {"luck": 470, "prev": 465, "next": -1}
	assert_eq(LuckStationView.gauge_text(full), "Glück 470 · alle Seiten voll")
	assert_eq(LuckStationView.gauge_share(full), 1.0)
	assert_eq(LuckStationView.bonus_text(state), "")
	assert_eq(LuckStationView.bonus_text({"free_bonus": 2}), "Freie Hand +2")
	assert_eq(LuckStationView.bonus_text({"free_bonus": 1, "keeps": 3}), "Noch 3 Einbauten")
	assert_eq(LuckStationView.bonus_text({"keeps": 1}), "Noch 1 Einbau")

func test_the_texts_follow_a_run() -> void:
	var run := GameRun.new_run()
	run.luck = 3
	run.sync_luck_die()
	assert_eq(LuckStationView.expected_text(run.luck_die.expected()), "Ø 1,3 Wahlen")
	assert_eq(LuckStationView.gauge_text(run.luck_station_state()), "Glück 3 · Auge bei 6")
