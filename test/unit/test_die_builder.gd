extends GutTest
## Tier-1-Tests des per Code gebauten Würfels (DieBuilder): Struktur aus
## Gesichts-Quads, durchgehendem Kanten-Rahmen (Füll-Box + 12 Balken, EIN
## geteiltes Material) und dem Umgebungslicht (standardmäßig aus, siehe
## DieFaceDisplay.set_light_enabled).

func _faces(die: Node3D) -> DieFaceDisplay:
	return die.get_node("RigidBody3D/Faces")

func test_build_creates_six_faces_with_labels():
	var die: Node3D = autofree(DieBuilder.build())
	var faces := _faces(die)
	assert_eq(faces.quads.size(), 6)
	assert_eq(faces.labels.size(), 6)

func test_build_creates_edge_frame_with_shared_material():
	var die: Node3D = autofree(DieBuilder.build())
	var faces := _faces(die)
	var edges: Node3D = faces.get_node("Edges")
	assert_eq(edges.get_child_count(), 14, "Füll-Box + 12 Kanten-Balken + Eck-Kappen")
	assert_not_null(faces.edge_material_res)
	var parts: Array = edges.get_children().filter(func(c): return c is MeshInstance3D)
	parts.append_array(faces.corner_caps.get_children())
	assert_eq(parts.size(), 21, "13 Rahmen-Teile + 8 Kappen")
	for child in parts:
		assert_eq(child.material_override, faces.edge_material_res,
			"alle Rahmen-Teile teilen EIN Material (eine Farbzuweisung färbt alles)")

func test_edge_beams_protrude_beyond_face_quads():
	# Rahmen-Optik: die Balken ragen über die Ebene der Gesichts-Quads hinaus.
	var beam_reach := DieBuilder.HALF_EXTENT + DieBuilder.EDGE_THICKNESS / 2.0
	var quad_plane := DieBuilder.HALF_EXTENT + DieBuilder.FACE_MARGIN
	assert_gt(beam_reach, quad_plane, "Kanten stehen vor den Gesichtern")

func test_die_light_exists_but_starts_disabled():
	# Nur die Spielwürfel schalten ihr Licht frei (siehe scene_root._ready) -
	# die Tray-Würfel würden sonst das Per-Objekt-Lichtlimit sprengen.
	var die: Node3D = autofree(DieBuilder.build())
	var faces := _faces(die)
	assert_not_null(faces.die_light)
	assert_false(faces.die_light.visible, "Licht ist standardmäßig aus")

func test_all_body_materials_have_emission_enabled():
	# Das Neon (siehe DieFaceDisplay.EDGE_GLOW/FACE_GLOW) braucht emission_enabled
	# schon beim Bau - sonst wäre jede spätere emission-Zuweisung wirkungslos.
	var die: Node3D = autofree(DieBuilder.build())
	var faces := _faces(die)
	for axis in faces.quads:
		var material: StandardMaterial3D = faces.quads[axis].get_surface_override_material(0)
		assert_true(material.emission_enabled, "Eigenleuchten der Seite %s" % axis)
	assert_true(faces.edge_material_res.emission_enabled, "Eigenleuchten des Rahmens")
