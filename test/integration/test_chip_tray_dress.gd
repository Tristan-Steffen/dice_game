extends GutTest
## Die FASSUNG des Chip-Trays als Körper: der Schreiber schreibt nur den Wechsel, die
## Füllmarken zählen die liegenden Chips, der Übertrag leuchtet für die Dauer seines Schritts,
## und nichts ragt über REST_TOP.

const SIDE := Vector2(388.4, 570.0)
const WORLD_PER_PX := 10.36 / 388.4

var _tray: ChipTrayView

func _dress() -> ChipTrayDress:
	var place := TreasureChestView.new()
	place.size = SIDE
	var pit := place.pit_rect()
	var rail_px := place.rail_x()
	place.free()
	_tray = ChipTrayView.new()
	add_child_autofree(_tray)
	_tray.setup(Vector3(3.0, 0.0, 5.0), Vector2(pit.size.y, pit.size.x) * WORLD_PER_PX * 0.5)
	# Bild-x ist Welt +Z, Bild-y Welt -X; der Rahmen um die Grubenmitte.
	var mid := pit.get_center()
	var frame := Rect2(Vector2(-(SIDE.y - mid.y), -mid.x) * WORLD_PER_PX, Vector2(SIDE.y, SIDE.x) * WORLD_PER_PX)
	var dress := ChipTrayDress.new()
	add_child_autofree(dress)
	dress.setup(_tray, frame, (rail_px - mid.x) * WORLD_PER_PX)
	return dress

func _feed(dress: ChipTrayDress, top := 0) -> void:
	var gates: Array[bool] = []
	for r in 7:
		gates.append(_tray.gate_open(r))
	dress.set_state(_tray.body_counts(), gates, _tray.flow(), top)

func test_the_writer_is_idempotent() -> void:
	var dress := _dress()
	_tray.seat_hard(ChipTrayView.belegung(137))
	_feed(dress)
	var writes := dress.writes()
	_feed(dress)
	assert_eq(dress.writes(), writes, "derselbe Stand schreibt nicht")
	_tray.seat_hard(ChipTrayView.belegung(4860))
	_feed(dress)
	assert_eq(dress.writes(), writes + 1, "der Wechsel schreibt")

func test_fill_marks_count_the_lying_chips() -> void:
	var dress := _dress()
	for money in [0, 137, 4860, 182_000]:
		_tray.seat_hard(ChipTrayView.belegung(money))
		_feed(dress)
		var counts := _tray.body_counts()
		for r in 7:
			var expect := 0
			for mark in ChipTrayDress.MARKS:
				if counts[r] >= mark:
					expect += 1
			assert_eq(dress.marks_lit(r), expect, "$%d, Rinne %d" % [money, r])
			assert_eq(dress.mark_full(r), counts[r] >= ChipTrayView.CAP)

func test_the_carry_lights_its_path_for_the_step() -> void:
	var dress := _dress()
	_tray.seat_hard(ChipTrayView.belegung(20))
	_tray.play(ChipTrayView.transition(ChipTrayView.belegung(20), ChipTrayView.belegung(21), false))
	var seen := false
	for i in 900:
		_tray.step(1.0 / 60.0)
		_feed(dress)
		if _tray.flow() == Vector2i(0, 1):
			seen = true
			assert_eq(dress.path_shown(), [0] as Array[int], "der Weg von Kappe 0 zu Kappe 1")
			assert_true(dress.arrow_up(0), "der Pfeil zeigt hinauf")
			assert_true(dress.lamp_lit(0))
		if seen and not _tray.busy():
			break
	assert_true(seen, "der Übertrag lief")
	assert_eq(dress.path_shown(), [] as Array[int], "nach dem Schritt ist der Weg dunkel")
	assert_false(dress.lamp_lit(0))

func test_a_borrow_points_down() -> void:
	var dress := _dress()
	_tray.seat_hard(ChipTrayView.belegung(21))
	_tray.play(ChipTrayView.transition(ChipTrayView.belegung(21), ChipTrayView.belegung(18), false))
	var seen := false
	for i in 900:
		_tray.step(1.0 / 60.0)
		_feed(dress)
		var flow := _tray.flow()
		if flow.x >= 0 and flow.y < flow.x:
			seen = true
			assert_false(dress.arrow_up(flow.y), "Borgen zeigt hinab")
		if seen and not _tray.busy():
			break
	assert_true(seen, "geborgt wurde")

func test_an_open_gate_rings_amber() -> void:
	var dress := _dress()
	_tray.seat_hard(ChipTrayView.belegung(30))
	_tray.play(ChipTrayView.transition(ChipTrayView.belegung(30), ChipTrayView.belegung(0)))
	var opened := false
	for i in 600:
		_tray.step(1.0 / 60.0)
		_feed(dress)
		for r in 7:
			if _tray.gate_open(r):
				opened = true
				assert_true(dress.ring_open(r), "Rinne %d: offen heißt bernstein" % r)
	assert_true(opened)
	for r in 7:
		assert_false(dress.ring_open(r), "danach ruhen alle")

func test_the_top_cap_counts_from_the_sixth() -> void:
	var dress := _dress()
	_feed(dress, 5)
	assert_eq(dress.times_text(), "")
	_feed(dress, 12)
	assert_eq(dress.times_text(), "×12")
	assert_eq(dress.value_text(6), "10K")
	assert_eq(dress.value_text(5), "2,5K")

func test_nothing_rises_above_the_rest_height() -> void:
	var dress := _dress()
	_tray.seat_hard(ChipTrayView.belegung(182_000))
	_feed(dress, 18)
	var inverse := dress.global_transform.affine_inverse()
	for node in dress.find_children("*", "GeometryInstance3D", true, false):
		var shape := node as GeometryInstance3D
		if shape is Label3D:
			continue
		var box := (inverse * shape.global_transform) * shape.get_aabb()
		assert_lte(box.end.y, ChipTrayDress.REST_TOP + 0.001, "%s bleibt flach" % shape.name)
