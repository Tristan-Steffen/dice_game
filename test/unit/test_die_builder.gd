extends GutTest
## Tier-1-Tests des per Code gebauten Würfels (DieBuilder): Struktur aus
## Gesichts-Quads, durchgehendem Kanten-Rahmen (Füll-Box + 12 Balken, EIN
## geteiltes Material) und dem Umgebungslicht (standardmäßig aus, siehe
## DieFaceDisplay.set_pool_enabled).

func _faces(die: Node3D) -> DieFaceDisplay:
	return die.get_node("RigidBody3D/Faces")

func test_build_creates_six_faces_with_labels():
	var die: Node3D = autofree(DieBuilder.build())
	var faces := _faces(die)
	assert_eq(faces.quads.size(), 6)
	assert_eq(faces.labels.size(), 6)

func test_build_creates_edge_frame_as_three_parts():
	# Füll-Box (StandardMaterial), Balken-Mesh (Fluss-Shader) und Kappen-Mesh
	# (Lampen-Shader): drei Draw-Calls für den ganzen Rahmen statt 21 Knoten.
	var die: Node3D = autofree(DieBuilder.build())
	var faces := _faces(die)
	var edges: Node3D = faces.get_node("Edges")
	assert_eq(edges.get_child_count(), 3, "Füll-Box + Balken-Mesh + Kappen-Mesh")
	assert_not_null(faces.edge_material_res)
	assert_eq((edges.get_node("Fill") as MeshInstance3D).material_override,
		faces.edge_material_res, "der Füllkörper bleibt beim alten Material")
	var beams: MeshInstance3D = edges.get_node("Beams")
	assert_not_null(faces.beam_material)
	assert_eq(beams.material_override, faces.beam_material,
		"die Balken tragen den Fluss-Shader")

func test_the_frame_mesh_carries_all_twelve_beams():
	var boxes: Array = DieBuilder.beam_boxes()
	assert_eq(boxes.size(), 12, "je Kante ein Balken")
	var span: Vector3 = DieBuilder.edge_frame_mesh().get_aabb().size
	var expected := DieBuilder.HALF_EXTENT * 2.0 + DieBuilder.EDGE_THICKNESS
	for axis in 3:
		assert_almost_eq(span[axis], expected, 0.001, "der Rahmen spannt Achse %d voll" % axis)

func test_the_corner_caps_are_one_mesh_with_their_own_lamp_material():
	# Die Kappen scheren aus dem geteilten Rahmen-Material aus: ab episch laufen
	# sie reihum, und dafür muss der Shader die einzelne Ecke unterscheiden
	# können. EIN Mesh mit vorgelagerten Vertizes löst das über sign(VERTEX) -
	# ohne 8 Materialien und mit einem Draw-Call statt acht.
	var die: Node3D = autofree(DieBuilder.build())
	var faces := _faces(die)
	assert_true(faces.corner_caps is MeshInstance3D, "ein Mesh, kein Knotenbündel")
	assert_eq(faces.corner_caps.get_child_count(), 0, "keine Einzelknoten mehr")
	assert_not_null(faces.cap_material)
	assert_eq(faces.corner_caps.material_override, faces.cap_material)
	assert_ne(faces.corner_caps.material_override, faces.edge_material_res)

func test_the_cap_mesh_reaches_every_corner():
	# Acht Kappen heißt: das Mesh spannt in jeder Achse über den ganzen Würfel.
	var span: Vector3 = DieBuilder.corner_cap_mesh().get_aabb().size
	var expected := DieBuilder.HALF_EXTENT * 2.0 + DieBuilder.CAP_SIZE
	for axis in 3:
		assert_almost_eq(span[axis], expected, 0.001, "Kappen auf beiden Enden von Achse %d" % axis)

func test_only_the_posts_run_through_the_corners():
	# Liefen alle drei Balken einer Ecke bis hinein, überlagerten sich dort je
	# zwei AUSSENflächen deckungsgleich - 96 solcher Paare flimmerten im
	# Tiefenpuffer. Die Pfosten laufen durch, die Riegel stoßen an.
	var reach := {}  # Laufrichtung -> halbe Länge
	for box: Array in DieBuilder.beam_boxes():
		var size: Vector3 = box[1]
		reach[size.max_axis_index()] = size[size.max_axis_index()] * 0.5
	assert_eq(reach.size(), 3, "je Achse eine Balkenlänge")
	var post: float = reach[Vector3.AXIS_Y]
	assert_almost_eq(post, DieBuilder.HALF_EXTENT + DieBuilder.EDGE_THICKNESS * 0.5, 0.001,
		"der Pfosten läuft bis zur äußeren Ecke durch")
	for axis in [Vector3.AXIS_X, Vector3.AXIS_Z]:
		assert_almost_eq(float(reach[axis]),
			DieBuilder.HALF_EXTENT - DieBuilder.EDGE_THICKNESS * 0.5, 0.001,
			"der Riegel endet an der Pfostenflanke")

func test_edge_beams_protrude_beyond_face_quads():
	# Rahmen-Optik: die Balken ragen über die Ebene der Gesichts-Quads hinaus.
	var beam_reach := DieBuilder.HALF_EXTENT + DieBuilder.EDGE_THICKNESS / 2.0
	var quad_plane := DieBuilder.HALF_EXTENT + DieBuilder.FACE_MARGIN
	assert_gt(beam_reach, quad_plane, "Kanten stehen vor den Gesichtern")

func test_glow_pool_exists_but_starts_disabled():
	# Der Würfel wirft KEIN echtes Licht (es beleuchtete nur die anderen Würfel
	# und ließ sie sich gegenseitig auswaschen) - nur eine Lache am Boden, und
	# die schaltet erst scene_root für die Grubenwürfel frei.
	var die: Node3D = autofree(DieBuilder.build())
	var faces: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
	assert_null(die.find_child("*Light*", true, false), "kein Würfellicht mehr")
	assert_not_null(faces.glow_pool)
	assert_true(faces.pool_allowed, "Lache läuft von Haus aus mit")

func test_all_body_materials_have_emission_enabled():
	# Das Neon (siehe DieFaceDisplay.EDGE_GLOW/FACE_GLOW) braucht emission_enabled
	# schon beim Bau - sonst wäre jede spätere emission-Zuweisung wirkungslos.
	var die: Node3D = autofree(DieBuilder.build())
	var faces := _faces(die)
	for axis in faces.quads:
		var material: StandardMaterial3D = faces.quads[axis].get_surface_override_material(0)
		assert_true(material.emission_enabled, "Eigenleuchten der Seite %s" % axis)
	assert_true(faces.edge_material_res.emission_enabled, "Eigenleuchten des Rahmens")
