extends GutTest
## Die Prozessor-Fassungen: der Ring folgt dem gerundeten Rechteck, der Sockel-Rahmen bleibt
## vor der Kollisionswand der Grube, und ein zweiter Aufbau läßt nichts doppelt stehen.

const HALF := Vector2(7.6, 14.28)
const RADIUS := 2.0

var frame: ChipFrameView

func before_each() -> void:
	frame = ChipFrameView.new()
	add_child_autofree(frame)

func test_loop_follows_the_rounded_rect() -> void:
	var points := ChipFrameView.loop(HALF, RADIUS, -0.3, 0.5)
	assert_eq(points.size(), 4 * (ChipFrameView.CORNER_STEPS + 1))
	for p in points:
		assert_almost_eq(p.y, 0.5, 0.0001)
		assert_true(absf(p.x) <= HALF.x + 0.3 + 0.0001 and absf(p.z) <= HALF.y + 0.3 + 0.0001)

func test_ring_mesh_spans_its_profile() -> void:
	var mesh := ChipFrameView.ring_mesh(HALF, RADIUS, [Vector2(-0.3, 0.0), Vector2(-0.3, 0.8),
		Vector2(0.4, 0.8)])
	var box := mesh.get_aabb()
	assert_almost_eq(box.size.y, 0.8, 0.001)
	assert_almost_eq(box.size.x, (HALF.x + 0.3) * 2.0, 0.001)
	assert_almost_eq(box.size.z, (HALF.y + 0.3) * 2.0, 0.001)

func test_socket_frame_stays_in_front_of_the_collision_wall() -> void:
	assert_lt(ChipFrameView.SOCKET_IN, DicePit.WALL_THICKNESS * 0.5)
	frame.setup_socket(HALF, RADIUS, Color.CYAN)
	assert_not_null(frame.get_node_or_null("Rahmen"))
	assert_not_null(frame.get_node_or_null("Hebel"))

func test_spreader_carries_lid_flange_and_etch() -> void:
	frame.setup_spreader(Vector2(15.0, 14.25), 0.3, "FX-6", 0.3, 0.7)
	for part in ["Flansch", "Deckel", "Gravur", "Pin1"]:
		assert_not_null(frame.get_node_or_null(part), part)
	assert_eq((frame.get_node("Gravur") as Label3D).text, "FX-6")

func test_second_setup_replaces_the_first() -> void:
	frame.setup_spreader(Vector2(15.0, 14.25), 0.3, "A")
	frame.setup_socket(HALF, RADIUS, Color.CYAN)
	assert_null(frame.get_node_or_null("Deckel"))
	assert_eq(frame.find_children("Rahmen", "", false, false).size(), 1)
