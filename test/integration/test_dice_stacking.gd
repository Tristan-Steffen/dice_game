extends GutTest
## Ruheerkennung: ein aufeinanderliegender Wuerfel darf nicht als "fertig" gelten.

var _controller: DiceController
var _bodies: Array[RigidBody3D]

func before_each() -> void:
	var roots: Array[Node3D] = []
	_bodies = []
	var displays: Array[DieFaceDisplay] = []
	for i in 2:
		var root := Node3D.new()
		var body := RigidBody3D.new()
		var display := DieFaceDisplay.new()
		add_child_autofree(root)
		root.add_child(body)
		body.add_child(display)
		roots.append(root)
		_bodies.append(body)
		displays.append(display)
	_controller = DiceController.new(roots, _bodies, displays)

func _step() -> bool:
	return _controller.physics_step(0.1, 0.1, 0.1, 0.05)

func test_a_die_resting_on_the_floor_settles() -> void:
	_bodies[0].global_position = Vector3(0.0, DiceController.DIE_HALF, 0.0)
	_bodies[1].global_position = Vector3(6.0, DiceController.DIE_HALF, 0.0)
	_controller.settled[0] = false
	_step()
	_step()
	assert_true(_controller.settled[0])

func test_a_die_lying_on_another_die_does_not_settle() -> void:
	# Flach und langsam, aber oben auf - genau der Fall, den die Hoehe faengt.
	_bodies[0].global_position = Vector3(0.0, DiceController.DIE_HALF, 0.0)
	_bodies[1].global_position = Vector3(0.0, DiceController.DIE_HALF * 3.0, 0.0)
	_controller.settled[1] = false
	assert_false(_step())
	assert_false(_controller.settled[1])

func test_the_push_points_away_from_the_carrying_die() -> void:
	_bodies[0].global_position = Vector3(0.0, DiceController.DIE_HALF, 0.0)
	_bodies[1].global_position = Vector3(0.4, DiceController.DIE_HALF * 3.0, 0.0)
	assert_almost_eq(_controller._slide_direction(_bodies[1]), Vector2.RIGHT, Vector2(0.001, 0.001))

func test_a_die_centred_exactly_on_top_still_gets_a_direction() -> void:
	# Sonst bliebe der perfekt deckungsgleiche Stapel ewig liegen.
	_bodies[0].global_position = Vector3(0.0, DiceController.DIE_HALF, 0.0)
	_bodies[1].global_position = Vector3(0.0, DiceController.DIE_HALF * 3.0, 0.0)
	assert_almost_eq(_controller._slide_direction(_bodies[1]).length(), 1.0, 0.001)
