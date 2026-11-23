extends GutTest
## Das geroutete Deck (PcbDeckView): Eckschnitt der Züge, Routing-Regeln, Adern-Korridore.

func _view(reserved: Array[Rect2] = []) -> PcbDeckView:
	var view := PcbDeckView.new()
	view.board = Rect2(0, 0, 3000, 2000)
	var comps: Array[Rect2] = [Rect2(400, 400, 500, 400), Rect2(1500, 500, 600, 300),
		Rect2(900, 1300, 700, 400)]
	var names: Array[String] = ["A", "B", "C"]
	view.comps = comps
	view.names = names
	view.reserved = reserved
	view.plan()
	return view

func test_track_line_cuts_a_long_corner_at_45_degrees():
	var path := PackedVector2Array([Vector2(0, 0), Vector2(300, 0), Vector2(300, 300)])
	var line := PcbDeckView.track_line(path, 0.0, 13.0)
	assert_eq(line.size(), 4, "Anfang, zwei Schnittpunkte, Ende")
	var cut := line[2] - line[1]
	assert_almost_eq(absf(cut.x), absf(cut.y), 0.01, "die Ecke ist ein 45-Grad-Stück")

func test_track_line_keeps_a_short_corner_square():
	var path := PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(20, 20)])
	assert_eq(PcbDeckView.track_line(path, 0.0, 13.0).size(), 3)

func test_parallel_tracks_keep_their_pitch_through_a_corner():
	var path := PackedVector2Array([Vector2(0, 0), Vector2(400, 0), Vector2(400, 400)])
	var inner := PcbDeckView.track_line(path, -PcbDeckView.PITCH, 13.0)
	var outer := PcbDeckView.track_line(path, PcbDeckView.PITCH, 13.0)
	var gap := absf((outer[1] - inner[1]).dot(Vector2(1, 1).normalized()))
	assert_almost_eq((inner[2] - inner[1]).normalized().dot((outer[2] - outer[1]).normalized()),
		1.0, 0.001, "beide Schrägen laufen parallel")
	assert_gt(gap, 0.0)

func test_plan_is_deterministic_and_routes_something():
	var a := _view()
	var b := _view()
	assert_gt(a.bundle_count(), 0)
	assert_eq(a.bundle_count(), b.bundle_count())
	assert_eq(str(a._bundles), str(b._bundles))
	a.free()
	b.free()

func test_no_bundle_has_more_than_two_corners_or_crosses_furniture():
	var view := _view()
	for bundle in view._bundles:
		var pts: Array = bundle["pts"]
		assert_lte(pts.size(), 4, "höchstens zwei Ecken")
		for i in range(1, pts.size() - 2):
			var seg := Rect2(pts[i], Vector2.ZERO).expand(pts[i + 1])
			for c in view.comps.size() - view._ghosts:
				assert_false(view.comps[c].intersects(seg), "kein Zug durch ein Möbel")
	view.free()

func test_reserved_corridors_stay_free():
	var corridor := Rect2(0, 950, 3000, 120)
	var reserved: Array[Rect2] = [corridor]
	var view := _view(reserved)
	for bundle in view._bundles:
		var pts: Array = bundle["pts"]
		for i in pts.size() - 1:
			assert_false(corridor.intersects(Rect2(pts[i], Vector2.ZERO).expand(pts[i + 1])),
				"kein Deko-Zug im Korridor einer Ader")
	view.free()

func test_pulse_runs_one_stream_per_track():
	var pulse := TracePulseView.new()
	add_child_autofree(pulse)
	var path := PackedVector2Array([Vector2(0, 0), Vector2(300, 0), Vector2(300, 200)])
	pulse.setup(path, Color.WHITE, 9.0, 21.0, 0.2, 100.0)
	assert_eq(pulse.track_count(), LedStripView.TRACKS)
	var rail := TracePulseView.new()
	add_child_autofree(rail)
	rail.setup(path, Color.WHITE, 9.0, 21.0, 0.2, 100.0, LedStripView.RAIL_TRACKS)
	assert_eq(rail.track_count(), LedStripView.RAIL_TRACKS)
