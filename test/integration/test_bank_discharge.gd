extends GutTest
## Tests der Bank-Entladung (Rundenauszahlung): die neue pit_hub_strip wird
## verlegt, bank_comet feuert zwei Halb-Kometen mit korrekter, achsenparalleler
## Route (Zielbalken -> Grube -> Hub), und drain_goal_bar entlädt den Balken.

func _screen() -> TableScreen:
	var ts: TableScreen = add_child_autofree(TableScreen.new())
	# Layout wie im Spiel: Score oben, Grube mittig, Hub unten.
	ts.configure_pit_score(Vector2(1500, 650), Vector2(3180, 650), Vector2(900, 400))
	ts.place_goal_bar(Vector2(2340, 650))
	ts.place_combo_cluster(Vector2(700, 650))
	ts.place_score_screen()
	ts.place_hub(Vector2(2340, 2500), Vector2(1700, 520))
	ts.place_pit_window(Rect2(Vector2(1640, 1150), Vector2(1400, 760)), 60.0)
	ts.link_score_strips()
	return ts

func test_pit_hub_strip_is_linked() -> void:
	var ts := _screen()
	assert_not_null(ts.pit_hub_strip)
	assert_true(ts.pit_hub_strip.strip_path.size() >= 2, "Bank-Leiste ist verlegt")

func test_pit_hub_strip_runs_pit_bottom_to_hub_top() -> void:
	var ts := _screen()
	var path := ts.pit_hub_strip.strip_path
	var pit_bottom := ts.pit_window.position.y + ts.pit_window.size.y
	var hub_top := ts.hub.position.y
	# Erste Kante an der Grube-Unterkante, letzte an der Hub-Oberkante.
	assert_almost_eq(path[0].y, pit_bottom, 1.0, "Start = Grube-Unterkante")
	assert_almost_eq(path[path.size() - 1].y, hub_top, 1.0, "Ende = Hub-Oberkante")

func test_bank_comet_returns_positive_travel_and_spawns_two_pulses() -> void:
	var ts := _screen()
	var before := _count_pulses(ts)
	var travel: float = ts.bank_comet(ts.stage_fill_color(3))
	assert_gt(travel, 0.0, "Laufzeit > 0")
	assert_eq(_count_pulses(ts) - before, 2, "zwei Halb-Kometen (links + rechts)")

func test_bank_route_is_axis_parallel() -> void:
	var ts := _screen()
	var path: PackedVector2Array = ts._bank_route(false)
	assert_true(path.size() >= 6, "mehrgliedrige Route")
	for i in path.size() - 1:
		var d := path[i + 1] - path[i]
		assert_true(is_zero_approx(d.x) or is_zero_approx(d.y),
			"Segment %d achsenparallel" % i)

func test_bank_route_touches_goal_bar_pit_and_hub() -> void:
	var ts := _screen()
	var left: PackedVector2Array = ts._bank_route(false)
	var right: PackedVector2Array = ts._bank_route(true)
	var gb := ts.goal_bar.position + ts.goal_bar.size * 0.5
	# Start am Zielbalken, Ende an der Hub-Oberkante.
	assert_almost_eq(left[0].x, gb.x, 1.0, "Start x = Zielbalken-Mitte")
	assert_almost_eq(left[0].y, gb.y, 1.0, "Start y = Zielbalken-Mitte")
	assert_almost_eq(left[left.size() - 1].y, ts.hub.position.y, 1.0, "Ende an Hub-Oberkante")
	# Linke Route berührt die linke Grubenkante, rechte die rechte.
	assert_almost_eq(_min_x(left), ts.pit_window.position.x, 1.0, "linke Route an linker Grubenkante")
	assert_almost_eq(_max_x(right), ts.pit_window.position.x + ts.pit_window.size.x, 1.0,
		"rechte Route an rechter Grubenkante")

func test_drain_goal_bar_shrinks_and_recolors() -> void:
	var ts := _screen()
	ts.set_goal_progress(600, 600, 3, 3)  # 3 Stufen voll -> volle Breite
	var full_w := TableScreen.GOAL_BAR_SIZE.x - TableScreen.GOAL_BAR_INSET * 2.0
	var target_color := ts.stage_fill_color(2)
	ts.drain_goal_bar(2.0 / 3.0, target_color, 0.0)  # Dauer 0 -> sofort
	await wait_frames(2)
	assert_almost_eq(ts.goal_bar_base.size.x, full_w * (2.0 / 3.0), 2.0, "Balken auf 2/3 geschrumpft")
	assert_eq(ts.goal_bar_base.color, target_color, "Balken in neuer Stufenfarbe")
	assert_eq(ts.goal_bar_fill.size.x, 0.0, "Teilstufe geräumt")

func _count_pulses(ts: TableScreen) -> int:
	var n := 0
	for c in ts.get_children():
		if c is TracePulseView:
			n += 1
	return n

func _min_x(path: PackedVector2Array) -> float:
	var m := INF
	for p in path:
		m = minf(m, p.x)
	return m

func _max_x(path: PackedVector2Array) -> float:
	var m := -INF
	for p in path:
		m = maxf(m, p.x)
	return m
