extends GutTest
## Zeigen auf einen ECHTEN Würfel (DieFaceDisplay.pick_face/edge_distance):
## seit die flache Projektion weg ist, wird am schwebenden Werkstück der
## Gravur-Station direkt gepickt - über die BILDSCHIRM-Projektion der Seiten-
## und Kantenmitten, nicht über einen Physik-Strahl (die Zeremonien-Würfel
## tragen keine Kollisionsform). Nur zugewandte Seiten zählen.

var faces: DieFaceDisplay
var camera: Camera3D

func before_each() -> void:
	var die := DieBuilder.build()
	add_child_autofree(die)
	faces = die.get_node("RigidBody3D/Faces")
	camera = Camera3D.new()
	add_child_autofree(camera)
	camera.position = Vector3(0, 0, 8)  # frontal auf die VORNE-Seite
	camera.look_at(Vector3.ZERO, Vector3.UP)
	await wait_frames(2)

func _center_px() -> Vector2:
	return camera.unproject_position(faces.global_position)

func test_the_face_towards_the_camera_is_picked_in_its_middle() -> void:
	var pick := faces.pick_face(camera, _center_px(), 400.0)
	assert_eq(int(pick[0]), DiceController.AXIS_FACE_INDEX["VORNE"],
		"in der Mitte liegt die zugewandte Seite")
	assert_lt(float(pick[1]), 1.0, "und zwar genau unter dem Zeiger")

func test_an_averted_face_is_never_picked() -> void:
	# Die Rückseite projiziert auf DENSELBEN Punkt - sie darf trotzdem nie gewinnen.
	var back_px := camera.unproject_position(
		faces.global_transform * (Vector3(0, 0, -1) * DieBuilder.HALF_EXTENT))
	var pick := faces.pick_face(camera, back_px, 400.0)
	assert_ne(int(pick[0]), DiceController.AXIS_FACE_INDEX["HINTEN"],
		"abgewandte Seiten sind kein Ziel")

func test_a_point_beyond_the_radius_hits_nothing() -> void:
	var pick := faces.pick_face(camera, _center_px() + Vector2(500, 0), 20.0)
	assert_eq(int(pick[0]), -1, "außerhalb des Radius ist keine Seite gemeint")
	assert_eq(float(pick[1]), INF)

func test_the_edge_wins_at_the_edge_and_loses_in_the_middle() -> void:
	# Kante gegen Seite entscheidet die kürzere Distanz - das ist die Regel, nach
	# der ein Klick zur Ganz-Würfel-Gravur oder zur Seitenwahl wird.
	var middle := _center_px()
	assert_gt(faces.edge_distance(camera, middle, 400.0),
		float(faces.pick_face(camera, middle, 400.0)[1]),
		"in der Seitenmitte gewinnt die Seite")
	# Mitte der Kante zwischen VORNE und RECHTS.
	var edge_px := camera.unproject_position(
		faces.global_transform * (Vector3(1, 0, 1) * DieBuilder.HALF_EXTENT))
	assert_lt(faces.edge_distance(camera, edge_px, 400.0),
		float(faces.pick_face(camera, edge_px, 400.0)[1]),
		"auf der Kante gewinnt der Rahmen")

func test_a_turned_die_is_picked_in_its_turned_position() -> void:
	# Gedreht wandern die Seiten mit: gepickt wird die Lage, nicht der Index.
	faces.get_parent().get_parent().rotate_y(PI)  # Würfel-Wurzel um 180 Grad
	await wait_frames(2)
	var pick := faces.pick_face(camera, _center_px(), 400.0)
	assert_eq(int(pick[0]), DiceController.AXIS_FACE_INDEX["HINTEN"],
		"nach der halben Drehung liegt HINTEN vorn")
