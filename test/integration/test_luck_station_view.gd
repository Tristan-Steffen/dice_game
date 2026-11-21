extends GutTest
## Die GLÜCKS-STATION: alles liegt in ihrer Fassung, der Sitz wird gemeldet, der Schreiber
## malt nur den Wechsel, und die Zeilen sagen, was GameRun sagt.

func _view(at := Vector2(388.4, 570.0)) -> LuckStationView:
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

func test_every_block_lies_inside_the_frame() -> void:
	for at: Vector2 in [Vector2(233.0, 570.0), Vector2(150.0, 570.0), Vector2(233.0, 300.0)]:
		var view := _view(at)
		var bounds := Rect2(Vector2.ZERO, at)
		var lay := view.layout()
		for key in ["title", "seat", "net", "expected", "gauge", "bonus"]:
			var rect: Rect2 = lay[key]
			assert_true(bounds.encloses(rect), "%s in %s" % [key, at])
		for face in 6:
			assert_true((lay["net"] as Rect2).grow(0.01).encloses(view.cell_rect(face)),
				"Zelle %d im Netz" % face)
		assert_true(bounds.has_point(view.seat_px()))
		assert_gt(view.net_cell(), 0.0)

func test_blocks_stand_top_to_bottom_without_overlap() -> void:
	var view := _view(Vector2(233.0, 570.0))
	var lay := view.layout()
	var keys := ["title", "seat", "net", "expected", "gauge", "bonus"]
	for i in keys.size() - 1:
		assert_lte((lay[keys[i]] as Rect2).end.y, (lay[keys[i + 1]] as Rect2).position.y + 0.01)

func test_set_state_is_idempotent() -> void:
	var view := _view()
	var state := {"luck": 8, "prev": 6, "next": 10, "expected": 1.5, "free_bonus": 0, "keeps": 0}
	view.set_state([1, 2, 1, 3, 1, 1], 3, state)
	assert_eq(view.shown_faces(), [1, 2, 1, 3, 1, 1] as Array[int])
	assert_eq(view.last_face(), 3)
	var redraws := [0]
	view.draw.connect(func() -> void: redraws[0] += 1)
	await wait_frames(2)
	var before: int = redraws[0]
	view.set_state([1, 2, 1, 3, 1, 1], 3, state)
	await wait_frames(2)
	assert_eq(redraws[0], before, "derselbe Stand malt nicht neu")
	view.set_state([1, 2, 2, 3, 1, 1], 3, state)
	await wait_frames(2)
	assert_gt(redraws[0], before, "der Wechsel malt")

func test_the_lines_read_like_the_plan() -> void:
	assert_eq(LuckStationView.expected_text(13.0 / 6.0), "Ø 2,2 Wahlen")
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

func test_the_station_follows_a_run() -> void:
	var run := GameRun.new_run()
	run.luck = 3
	run.sync_luck_die()
	var view := _view()
	view.set_state(run.luck_die.faces, -1, run.luck_station_state())
	assert_eq(LuckStationView.expected_text(run.luck_die.expected()), "Ø 1,3 Wahlen")
	assert_eq(LuckStationView.gauge_text(run.luck_station_state()), "Glück 3 · Auge bei 6")
