extends GutTest
## Der Körper des GLÜCKSWÜRFELS: echte Augen je Seite, der Schlag hält den alten Stand, der
## geführte Wurf landet auf der gebuchten Seite, der harte Weg schuldet nichts.

func _view() -> LuckDieView:
	var view := LuckDieView.new()
	add_child_autofree(view)
	return view

func test_one_size_everywhere() -> void:
	assert_almost_eq(LuckDieView.SCALE, 0.9 * DiceTrayView.DIE_SCALE, 0.0001)

func test_every_face_turns_up() -> void:
	for face in 6:
		var up := LuckDieView.face_up_basis(face, 0.0, 0.0) * LuckDieView.FACE_DIRS[face]
		assert_almost_eq(up.distance_to(Vector3.UP), 0.0, 0.001, "Seite %d oben" % face)

func test_the_pip_layouts_count_right() -> void:
	for value in range(1, 7):
		assert_eq(LuckDieView.pip_layout(value).size(), value)

func test_seat_hard_shows_real_pips() -> void:
	var view := _view()
	view.seat_hard([1, 2, 3, 4, 5, 6])
	for face in 6:
		assert_eq(view.pips_on(face), face + 1, "Seite %d" % face)

func test_a_change_holds_the_old_state_until_its_beat() -> void:
	var view := _view()
	view.seat_hard([1, 1, 1, 1, 1, 1])
	var heard: Array = []
	view.pip_changed.connect(func(gain: bool, value: int) -> void: heard.append([gain, value]))
	view.play_changes([{"face": 2, "delta": 1, "value_after": 2},
		{"face": 2, "delta": 1, "value_after": 3}])
	assert_eq(view.shown_faces()[2], 1, "gebucht ist, gezeigt noch nicht")
	assert_eq(view.pending_beats(), 2)
	await wait_seconds(4.0)
	assert_eq(view.shown_faces()[2], 3, "beide Schläge nacheinander")
	assert_eq(view.pips_on(2), 3)
	assert_eq(heard, [[true, 2], [true, 3]])
	assert_false(view.busy())

func test_settle_hard_jumps_to_the_booked_state() -> void:
	var view := _view()
	view.seat_hard([1, 1, 1, 1, 1, 1])
	view.play_changes([{"face": 4, "delta": 1, "value_after": 2}])
	await wait_frames(2)
	view.settle_hard()
	assert_eq(view.shown_faces()[4], 2)
	assert_eq(view.pending_beats(), 0)
	assert_false(view.busy())

func test_the_guided_roll_lands_on_the_booked_face() -> void:
	var view := _view()
	view.seat_hard([1, 2, 3, 4, 5, 6])
	var landed: Array = []
	var hops: Array = []
	view.rolled.connect(func(face: int) -> void: landed.append(face))
	view.hopped.connect(func(step: int) -> void: hops.append(step))
	view.roll_to(4)
	assert_true(view.rolling())
	await wait_seconds(LuckDieView.ROLL_TIME + 0.3)
	assert_eq(landed, [4])
	assert_eq(hops, [1, 2])
	assert_eq(view.up_face(), 4)
	var body := view.get_node("Body") as Node3D
	var up: Vector3 = body.global_basis.orthonormalized() * LuckDieView.FACE_DIRS[4]
	var rest: Vector3 = LuckDieView.face_up_basis(4) * LuckDieView.FACE_DIRS[4]
	assert_almost_eq(up.distance_to(rest), 0.0, 0.01, "Seite 4 liegt oben")
	assert_gt(rest.y, 0.9, "geneigt, aber oben")
	assert_lt(rest.x, 0.0, "zum Betrachter geneigt")

func test_a_click_jumps_to_the_end_of_the_roll() -> void:
	var view := _view()
	var landed: Array = []
	view.rolled.connect(func(face: int) -> void: landed.append(face))
	view.roll_to(1)
	await wait_frames(3)
	view.finish_roll()
	view.finish_roll()
	assert_eq(landed, [1], "genau einmal")
	assert_false(view.rolling())

func test_the_hint_reads_above_it() -> void:
	var view := _view()
	view.set_hint("Glückswürfel · Glück 3 · nächstes Auge bei 6")
	assert_true(view.hint_shown())
	view.set_hint("")
	assert_false(view.hint_shown())
