extends GutTest
## Der SPEICHER als Platine: die Halter der sechs Energiezellen liegen in den freien
## Kreuz-Ecken rechts, die Anschlüsse der Bahnen kreuzen nicht, und die Körper zeigen die
## Ladung ihrer Scheibe.

const CELL := 64.9

func _origin() -> Vector2:
	var span := DieNetView.net_size(CELL)
	return WorkshopView.StorageBody.net_origin_in(span + Vector2(20.0, 20.0), span)

func test_holders_lie_in_the_free_corners_and_never_touch() -> void:
	var origin := _origin()
	var step := CELL * (1.0 + DieNetView.GAP_FACTOR)
	var seats: Array[Rect2] = []
	for slice in WorkshopView.DRUM_SLICES:
		seats.append(WorkshopView.StorageBody.cell_rect(origin, CELL, slice))
	for slice in seats.size():
		var block := Rect2(origin + Vector2(step * 2.0, step * 2.0 if slice >= 3 else 0.0),
			Vector2(CELL * (2.0 + DieNetView.GAP_FACTOR), CELL))
		assert_true(block.encloses(seats[slice]), "Halter %d in seiner Ecke" % slice)
		for other in slice:
			assert_false(seats[slice].intersects(seats[other]), "%d gegen %d" % [slice, other])
	# Oben liegen 3-2-1 (die äußere Bahn kommt am weitesten), unten 4-5-6.
	assert_gt(seats[0].position.x, seats[1].position.x)
	assert_gt(seats[1].position.x, seats[2].position.x)
	assert_lt(seats[3].position.x, seats[4].position.x)
	assert_lt(seats[4].position.x, seats[5].position.x)

func test_the_net_moves_right_and_down_but_stays_inside() -> void:
	var span := DieNetView.net_size(CELL)
	var size := span + Vector2(20.0, 20.0)
	var origin := WorkshopView.StorageBody.net_origin_in(size, span)
	assert_gt(origin.x, 10.0)
	assert_gt(origin.y, 10.0)
	assert_true(Rect2(Vector2.ZERO, size).encloses(Rect2(origin, span)))

func test_ports_rise_from_left_to_right() -> void:
	var rect := Rect2(Vector2(100.0, 50.0), Vector2(299.2, 227.8))
	var last := rect.position.x
	for i in WorkshopView.DRUM_SLICES * WorkshopView.TRACE_LANES:
		var x := WorkshopView.trace_end_x(rect, WorkshopView.DRUM_SLICES, WorkshopView.TRACE_LANES, i)
		assert_gt(x, last, "Anschluß %d" % i)
		last = x
	assert_lt(last, rect.end.x)

func test_bodies_show_the_charge_of_their_slice() -> void:
	var bank := StorageBankView.new()
	add_child_autofree(bank)
	var centers: Array[Vector3] = []
	for i in 6:
		centers.append(Vector3(float(i), 0.0, 2.0))
	var tints: Array[Color] = [Color(0.3, 1.0, 0.5), Color(0, 0, 0, 0), Color(1.0, 0.5, 0.8),
		Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]
	bank.seat(centers, Vector2(1.2, 0.7), tints)
	assert_eq(bank.cell_count(), 6)
	assert_eq(bank.cell_node(3).position, centers[3])
	assert_eq(bank.shown_core(1), StorageBankView.EMPTY)
	assert_eq(bank.shown_core(0), StorageBankView.core_color(tints[0]))
	assert_gt(bank.shown_core(0).g, 1.0, "geladen über der Bloom-Schwelle")
	assert_lt(bank.top_height(), DiceTrayView.DIE_SCALE, "flacher als ein Würfel")
	# Derselbe Aufruf baut nichts neu.
	var first := bank.cell_node(0)
	bank.seat(centers, Vector2(1.2, 0.7), tints)
	assert_eq(bank.cell_node(0), first)

func test_chip_frames_stand_low_around_every_net_cell() -> void:
	var bank := StorageBankView.new()
	add_child_autofree(bank)
	var chips: Array[Vector3] = []
	for i in 6:
		chips.append(Vector3(float(i) * 2.0, 0.0, 0.0))
	bank.seat_chips(chips, 1.7, 0.04)
	assert_eq(bank.chip_count(), 6)
	var node := bank.chips_node()
	bank.seat_chips(chips, 1.7, 0.04)
	assert_eq(bank.chips_node(), node, "derselbe Aufruf baut nichts neu")
	var centers: Array[Vector3] = [Vector3(1.0, 0.0, 3.0)]
	var tints: Array[Color] = [Color(0, 0, 0, 0)]
	bank.seat(centers, Vector2(1.2, 0.7), tints)
	assert_lt(StorageBankView.RIM_HEIGHT, bank.top_height(), "die Zellen überragen die Rahmen")

func test_the_deck_keeps_its_quiet_fields_within_the_cap() -> void:
	var screen := TableScreen.new()
	add_child_autofree(screen)
	await wait_frames(1)
	var rects: Array[Rect2] = []
	for i in TableScreen.MAX_QUIET + 3:
		rects.append(Rect2(Vector2(float(i) * 10.0, 5.0), Vector2(8.0, 8.0)))
	screen.set_deck_quiet_rects(rects)
	assert_eq(screen.deck_quiet_rects().size(), TableScreen.MAX_QUIET)
	assert_eq(screen.deck_quiet_rects()[0], rects[0])
