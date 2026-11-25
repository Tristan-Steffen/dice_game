extends GutTest
## Der SPEICHER als Platine: die Halter der sechs Energiezellen liegen in den freien
## Kreuz-Ecken rechts, der Eingang kommt von links, der Abgang geht oben ab, und die Körper
## zeigen die Ladung ihrer Scheibe.

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
		var bottom := slice >= WorkshopView.StorageBody.ROW_CELLS
		var block := Rect2(origin + Vector2(step * 2.0, step * 2.0 if bottom else 0.0),
			Vector2(CELL * (2.0 + DieNetView.GAP_FACTOR), CELL))
		assert_true(block.encloses(seats[slice]), "Halter %d in seiner Ecke" % slice)
		for other in slice:
			assert_false(seats[slice].intersects(seats[other]), "%d gegen %d" % [slice, other])
	# Oben liegen 1-2-3, unten 4-5-6, je von links.
	assert_eq(seats.size(), 6)
	for i in 2:
		assert_lt(seats[i].position.x, seats[i + 1].position.x, "oben %d links von %d" % [i, i + 1])
		assert_lt(seats[i + 3].position.x, seats[i + 4].position.x, "unten %d links" % (i + 3))

func test_the_net_moves_right_but_stays_inside() -> void:
	var span := DieNetView.net_size(CELL)
	var size := span + Vector2(20.0, 20.0)
	var origin := WorkshopView.StorageBody.net_origin_in(size, span)
	assert_gt(origin.x, 10.0, "links bleibt Platz für den Eingang")
	assert_true(Rect2(Vector2.ZERO, size).encloses(Rect2(origin, span)))

## Der Eingang kommt mittig von links, der Abgang geht mittig oben ab - Spur 0 außen.
func test_entries_and_feeds_are_centred() -> void:
	var rect := Rect2(Vector2(100.0, 50.0), Vector2(299.2, 227.8))
	var pitch := 6.5
	var lanes := WorkshopView.TRACE_LANES
	for lane in range(1, lanes):
		assert_gt(WorkshopView.entry_y(rect, pitch, lane, lanes),
			WorkshopView.entry_y(rect, pitch, lane - 1, lanes), "Spur %d unter der vorigen" % lane)
		assert_gt(WorkshopView.feed_x(rect, pitch, lane), WorkshopView.feed_x(rect, pitch, lane - 1))
	var mid_y := (WorkshopView.entry_y(rect, pitch, 0, lanes)
		+ WorkshopView.entry_y(rect, pitch, lanes - 1, lanes)) * 0.5
	assert_almost_eq(mid_y, rect.get_center().y, 0.01)
	var mid_x := (WorkshopView.feed_x(rect, pitch, 0) + WorkshopView.feed_x(rect, pitch, lanes - 1)) * 0.5
	assert_almost_eq(mid_x, rect.get_center().x, 0.01)

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
