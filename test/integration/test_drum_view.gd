extends GutTest
## Die WALZE: Seite je Sorte, leer auf Kante, idempotent, Endzustand zuerst; die Achse
## läuft Bild-links → Bild-rechts (Welt +Z).

var drum: DrumView

func before_each() -> void:
	drum = DrumView.new()
	add_child_autofree(drum)
	var centers: Array[Vector3] = []
	for i in DrumView.SLICES:
		centers.append(Vector3(0.0, 0.0, 5.5 * float(i)))
	drum.setup(centers, 3.6, 5.5)

func _pack(category: String) -> Pack:
	var pack := Pack.new()
	pack.type = Pack.pack_type_of_shelf(category)
	return pack

func test_empty_slices_stand_on_edge() -> void:
	drum.seat_hard([])
	for i in DrumView.SLICES:
		assert_almost_eq(drum.shown_angle(i), DrumView.EMPTY_ANGLE, 0.0001)

func test_each_sort_has_its_own_face() -> void:
	var seen := {}
	for rank in Pack.SHELF_ORDER.size():
		seen[snappedf(DrumView.face_angle(rank), 0.0001)] = true
	assert_eq(seen.size(), Pack.SHELF_ORDER.size())
	assert_false(seen.has(snappedf(DrumView.EMPTY_ANGLE, 0.0001)))

func test_seat_writes_end_state_first_then_turns() -> void:
	var pack := _pack(Engraving.CATEGORY_MATERIAL)
	drum.seat([pack])
	var want := DrumView.face_angle(Pack.shelf_rank(pack))
	assert_almost_eq(drum.target_angle(0), want, 0.0001)
	assert_true(drum.turning(0))
	await wait_seconds(DrumView.QUARTER_TIME * 2.0 + 0.1)
	assert_almost_eq(drum.shown_angle(0), want, 0.001)

func test_seat_is_idempotent() -> void:
	var pack := _pack(Engraving.CATEGORY_NUMBER)
	drum.seat_hard([pack])
	drum.seat([pack])
	assert_false(drum.turning(0))

func test_top_point_is_on_glass() -> void:
	assert_almost_eq(drum.top_point(2).y, 0.0, 0.0001)
	assert_almost_eq(drum.top_point(2).z, 11.0, 0.0001)

## Die Scheibe dreht um die Achse der Walze: Welt-Z.
func test_slices_turn_about_the_drum_axis() -> void:
	var pack := _pack(Engraving.CATEGORY_DICE)
	drum.seat_hard([pack])
	var pivot := drum.get_node("Scheibe1") as Node3D
	assert_almost_eq(pivot.rotation.x, 0.0, 0.0001)
	assert_almost_eq(pivot.rotation.z, DrumView.face_angle(Pack.shelf_rank(pack)), 0.0001)

func test_the_stream_runs_from_slice_one_to_the_right() -> void:
	for i in range(1, DrumView.SLICES + 1):
		assert_gt(drum.light_stop(i).z, drum.light_stop(i - 1).z, "Stopp %d liegt weiter rechts" % i)
	assert_gt(drum.light_stop(0).y, 0.0, "über der liegenden Karte")

## Das Ende der Walze liegt hinter Scheibe 6, auf dem Glas.
func test_the_end_point_follows_the_last_slice() -> void:
	assert_gt(drum.end_point().z, drum.top_point(DrumView.SLICES - 1).z)
	assert_almost_eq(drum.end_point().y, 0.0, 0.0001)

func test_the_same_geometry_keeps_the_light_rider() -> void:
	var rider := Node3D.new()
	drum.attach_to_light(rider)
	var centers: Array[Vector3] = []
	for i in DrumView.SLICES:
		centers.append(drum.top_point(i))
	drum.setup(centers, 3.6, 5.5)
	assert_true(is_instance_valid(rider) and rider.is_inside_tree(),
		"ein gleicher Abgleich baut nichts neu - das Licht-Netz reitet weiter")
