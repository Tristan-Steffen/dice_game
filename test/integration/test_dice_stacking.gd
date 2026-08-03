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

const STEP_SECONDS := 0.1

func _step() -> bool:
	return _controller.physics_step(STEP_SECONDS, 0.1, 0.1, 0.05)

## Schritte für eine Zeit in Sekunden - die Klemm-Tests hängen an
## STUCK_RETHROW_SECONDS, nie an einer abgezählten Schleife.
func _steps_for(seconds: float) -> int:
	return ceili(seconds / STEP_SECONDS)

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

## Legt Slot 0 auf die Kante (nie flach, also nie ruhig) und merkt sich einen
## erkennbaren Abwurfpunkt.
func _wedge_slot_zero() -> Vector3:
	var launch := Vector3(0.0, 20.0, 0.0)
	_controller.start_transforms[0] = Transform3D(Basis.IDENTITY, launch)
	_bodies[0].global_transform = Transform3D(
		Basis(Vector3.FORWARD, PI * 0.25), Vector3(0.0, DiceController.DIE_HALF, 0.0))
	_controller.settled[0] = false
	_controller.stuck_timers[0] = 0.0
	return launch

func test_a_wedged_die_keeps_lying_before_the_stuck_limit() -> void:
	_wedge_slot_zero()
	for _i in _steps_for(DiceController.STUCK_RETHROW_SECONDS - 0.5):  # knapp unter der Grenze
		_step()
	assert_almost_eq(_bodies[0].global_position.y, DiceController.DIE_HALF, 0.001,
		"vor der Grenze wird nicht neu geworfen")

func test_a_wedged_die_is_thrown_again_after_the_stuck_limit() -> void:
	var launch := _wedge_slot_zero()
	for _i in _steps_for(DiceController.STUCK_RETHROW_SECONDS + 0.5):  # ueber die Grenze
		_step()
	assert_almost_eq(_bodies[0].global_position, launch, Vector3.ONE * 0.001,
		"der steckende Slot startet neu am Abwurfpunkt")
	assert_false(_controller.settled[0])
	assert_lt(_controller.stuck_timers[0], DiceController.STUCK_RETHROW_SECONDS,
		"der Timer laeuft nach dem Neuwurf wieder von vorn")
