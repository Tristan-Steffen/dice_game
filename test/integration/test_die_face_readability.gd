extends GutTest
## Lesbarkeit der Seiten auf Essenz-Würfeln. Additives Licht lässt sich nicht
## durch hellere Einlagen kontern - beide Maßnahmen hier NEHMEN der Fläche Licht
## weg: die Randmaske der Fresnel-Hülle und die dunkle Fassung am Flächenrand.
## Das Urteil über das Aussehen fällt der Playtest; hier steht die Struktur.

const FRESNEL := preload("res://assets/shaders/die_fresnel.gdshader")

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

## Zahl hinter einem uniform-Default im Shader-Quelltext.
func _shader_default(uniform_name: String) -> float:
	for line in FRESNEL.code.split("\n"):
		if line.begins_with("uniform") and line.contains(" %s " % uniform_name):
			var parts := line.split("=")
			if parts.size() >= 2:
				return float(parts[1].replace(";", "").strip_edges())
	return -1.0

# --- Randmaske der Fresnel-Hülle ----------------------------------------------------

func test_the_fresnel_shell_carries_the_rim_mask_uniforms() -> void:
	var names: Array[String] = []
	for entry in FRESNEL.get_shader_uniform_list():
		names.append(String(entry["name"]))
	for required in ["glow_color", "strength", "falloff", "face_clear", "rim_soft"]:
		assert_true(names.has(required), "die Hülle kennt %s" % required)

func test_the_face_centre_is_cleared_before_the_rim_carries_again() -> void:
	# face_clear ist der ganz freie Anteil, rim_soft die Stelle voller Wirkung -
	# in dieser Reihenfolge, sonst liefe die Maske verkehrt herum.
	var clear := _shader_default("face_clear")
	var soft := _shader_default("rim_soft")
	assert_between(clear, 0.0, 1.0, "face_clear ist ein Anteil der halben Breite")
	assert_between(soft, 0.0, 1.0, "rim_soft ebenso")
	assert_lt(clear, soft, "erst frei, dann wieder voll")
	assert_gt(clear, 0.0, "die Mitte wird wirklich freigeschnitten")

func test_the_falloff_got_steeper_than_the_old_flat_exponent() -> void:
	# Früher 2.1 und bewusst flach; der Würfel soll strahlen, aber nicht mehr in
	# seine eigenen Flächen hinein.
	assert_gt(_shader_default("falloff"), 2.1, "steiler als vorher")

func test_nothing_overrides_the_shell_defaults_from_code() -> void:
	# Nur Farbe und Stärke kommen aus dem Code - Randmaske und Falloff sind
	# Shader-Defaults, sonst wäre die Regel an zwei Orten.
	var display := _display()
	display.apply_definition(_def([0], Essence.NEON))
	assert_not_null(display.shell_material)
	for owned in ["falloff", "face_clear", "rim_soft"]:
		assert_null(display.shell_material.get_shader_parameter(owned),
			"%s bleibt beim Shader-Default" % owned)

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
	# Vor dem Quad (sonst Z-Fighting), hinter Rahmen und Riss-Auflage - eine
	# Risslinie bis zum Flächenrand muss darüber sichtbar bleiben.
	var display := _display()
	var depth: float = (display.gaskets[_axis_for(0)] as Node3D).position.z
	assert_gt(depth, 0.0, "vor der Fläche")
	assert_lt(depth, (display.frames[_axis_for(0)] as MeshInstance3D).position.z,
		"hinter dem Leuchtrahmen")
	assert_lt(depth, (display.rift_overlays[_axis_for(0)] as MeshInstance3D).position.z,
		"und hinter den Rissen")

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
