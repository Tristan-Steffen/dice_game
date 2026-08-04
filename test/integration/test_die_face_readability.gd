extends GutTest
## Lesbarkeit der Seiten auf Essenz-Würfeln. Additives Licht lässt sich nicht
## durch hellere Einlagen kontern - es muss der Fläche WEGGENOMMEN werden, und
## das tut hier die dunkle Fassung am Flächenrand. (Die Fresnel-Hülle trug
## früher die zweite Hälfte dieser Aufgabe; sie ist ersatzlos gestrichen, siehe
## DieFaceDisplay.) Das Urteil über das Aussehen fällt der Playtest; hier steht
## die Struktur.

func _display() -> DieFaceDisplay:
	var die: Node3D = autofree(DieBuilder.build())
	return die.get_node("RigidBody3D/Faces")

func _axis_for(face_index: int) -> String:
	for axis: String in DiceController.AXIS_FACE_INDEX:
		if DiceController.AXIS_FACE_INDEX[axis] == face_index:
			return axis
	return ""

func _def(material_faces: Array, essence_id := "") -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = [1, 2, 3, 4, 5, 6]
	def.faces = faces
	def.essence_id = essence_id
	for face in material_faces:
		def.set_face_material(int(face), DieMaterial.RUBY)
	return def

# --- Kein additives Licht über den Flächen -------------------------------------------

func test_no_additive_layer_floats_over_the_faces() -> void:
	# Die Fresnel-Hülle ist gestrichen und darf nicht zurückkommen: eine
	# Leuchtfolie knapp über dem Körper hat nur zwei Fehler zur Wahl -
	# deckungsgleich flimmert ihr Tiefentest, abgehoben steht ihr Rand in der
	# Luft und liest sich als abgelöste Seite. Licht nur auf echter Geometrie.
	var die: Node3D = autofree(DieBuilder.build())
	var faces: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
	assert_null(faces.get_node_or_null("FresnelShell"), "keine Hülle über dem Körper")
	for visual in faces.find_children("*", "MeshInstance3D", true, false):
		var material: Material = (visual as MeshInstance3D).material_override
		if material is BaseMaterial3D:
			assert_ne((material as BaseMaterial3D).blend_mode, BaseMaterial3D.BLEND_MODE_ADD,
				"%s liegt nicht additiv über dem Würfel" % visual.name)

# --- Dunkle Fassung -----------------------------------------------------------------

func test_every_face_has_a_gasket() -> void:
	var display := _display()
	assert_eq(display.gaskets.size(), 6, "je Seite eine Fassung")
	for axis: String in display.gaskets:
		assert_true(display.gaskets[axis] is Node3D)

func test_the_gasket_is_a_closed_ring_of_four_bars() -> void:
	var display := _display()
	assert_eq((display.gaskets[_axis_for(0)] as Node3D).get_child_count(), 4,
		"zwei Balken, zwei Pfosten - stoßfrei an den Ecken")

func test_the_gasket_shows_exactly_where_a_material_sits() -> void:
	var display := _display()
	display.apply_definition(_def([0, 2]))
	assert_true((display.gaskets[_axis_for(0)] as Node3D).visible, "Material -> Dichtung")
	assert_true((display.gaskets[_axis_for(2)] as Node3D).visible)
	assert_false((display.gaskets[_axis_for(1)] as Node3D).visible,
		"ohne Einlage gibt es nichts abzudichten")

func test_the_gasket_follows_the_frame_when_the_die_changes() -> void:
	var display := _display()
	display.apply_definition(_def([0]))
	assert_true((display.gaskets[_axis_for(0)] as Node3D).visible)
	display.apply_definition(_def([3]))
	assert_false((display.gaskets[_axis_for(0)] as Node3D).visible, "Einlage weg, Dichtung weg")
	assert_true((display.gaskets[_axis_for(3)] as Node3D).visible, "und an der neuen Seite da")

func test_the_gasket_sits_between_the_quad_and_the_frame() -> void:
	# Vor dem Quad (sonst Z-Fighting), hinter Rahmen und Runen-Auflage - eine
	# Glyphenlinie bis zum Flächenrand muss darüber sichtbar bleiben.
	var display := _display()
	var depth: float = (display.gaskets[_axis_for(0)] as Node3D).position.z
	assert_gt(depth, 0.0, "vor der Fläche")
	assert_lt(depth, (display.frames[_axis_for(0)] as MeshInstance3D).position.z,
		"hinter dem Leuchtrahmen")
	assert_lt(depth, (display.rune_overlays[_axis_for(0)] as MeshInstance3D).position.z,
		"und hinter die Runenn")

func test_the_gasket_is_dark_and_does_not_glow() -> void:
	# Eine Dichtung strahlt nicht - sie ist die Trennzone gegen das Kantenbloom.
	var display := _display()
	var bar: MeshInstance3D = (display.gaskets[_axis_for(0)] as Node3D).get_child(0)
	var material := bar.material_override as StandardMaterial3D
	assert_not_null(material)
	assert_false(material.emission_enabled, "kein Eigenleuchten")
	var albedo := material.albedo_color
	assert_lt(albedo.r + albedo.g + albedo.b, 0.2, "fast schwarz")
	assert_eq(material.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED,
		"kein Szenenlicht hebt sie auf")

func test_the_gasket_stays_inside_its_face() -> void:
	var display := _display()
	var ring: Node3D = display.gaskets[_axis_for(0)]
	var limit := DieBuilder.FACE_SIZE * 0.5
	for bar in ring.get_children():
		var mesh := (bar as MeshInstance3D).mesh as QuadMesh
		var reach := (bar as MeshInstance3D).position.abs() + Vector3(mesh.size.x, mesh.size.y, 0.0) * 0.5
		assert_lte(reach.x, limit + 0.001, "kein Überstand in x")
		assert_lte(reach.y, limit + 0.001, "kein Überstand in y")
