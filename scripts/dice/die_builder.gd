class_name DieBuilder
extends RefCounted
## Baut einen kompletten Würfel (RigidBody3D + Kollision + 6 Gesichts-Quads,
## siehe DieFaceDisplay) komplett per Code zusammen - keine .tscn-Datei mehr
## nötig. Wird sowohl für die 6 Spielwürfel (scene_root.gd) als auch die 30
## Tray-Würfel (dice_tray_view.gd) verwendet.
##
## Die 6 Quads bilden den weißen Würfelkörper (kein separater Körper-Mesh);
## jedes trägt ein Label3D-Kind, das die Augenzahl als Ziffer zeigt (siehe
## DieFaceDisplay). Die konkreten Werte/Tönungen setzt der Aufrufer danach über
## DieFaceDisplay.apply_definition / set_tint.

const HALF_EXTENT := 1.0
const FACE_SIZE := 1.9
const FACE_MARGIN := 0.02
## Kantenstärke des Rahmen-Körpers (Balken-Querschnitt): ragt EDGE_THICKNESS/2
## über die Würfeloberfläche hinaus - also spürbar VOR den Gesichts-Quads
## (HALF_EXTENT + FACE_MARGIN), damit die Kanten als Rahmen hervortreten.
const EDGE_THICKNESS := 0.16

## Lässt Würfel spürbar von Wänden/Boden der Grube abprallen statt beim
## ersten Kontakt zu kleben (siehe scenes/dice_tray.tscn: dieselbe
## PhysicsMaterial-Charakteristik liegt auch auf den Grubenwänden, damit
## beide Seiten eines Aufpralls Energie zurückgeben).
const BOUNCE := 0.25
const FRICTION := 0.4

## Baut einen Würfel und gibt seinen Wurzelknoten ("Dice", Node3D) zurück.
## Der Aufrufer muss den Knoten noch in den Baum einhängen und positionieren.
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Dice"

	var body := RigidBody3D.new()
	body.name = "RigidBody3D"
	body.collision_layer = 2
	body.collision_mask = 3
	body.gravity_scale = 3.5
	body.linear_damp = 0.2
	body.angular_damp = 0.2
	body.continuous_cd = true  # verhindert Tunneln durch die dünnen Grubenwände bei hohem throw_force
	var material := PhysicsMaterial.new()
	material.bounce = BOUNCE
	material.friction = FRICTION
	body.physics_material_override = material
	root.add_child(body)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * HALF_EXTENT * 2.0
	collision.shape = shape
	body.add_child(collision)

	var faces := Node3D.new()
	faces.name = "Faces"
	faces.set_script(load("res://scripts/dice/die_face_display.gd"))
	body.add_child(faces)

	# Durchgehender Kanten-Körper: 12 Balken entlang der Würfelkanten, die ein
	# Stück ÜBER die Gesichts-Quads hinausragen (Rahmen-Optik), plus eine
	# Füll-Box dahinter, die die Lücken zwischen den Balken schließt. Alle
	# teilen EIN Material - dessen Farbe setzt DieFaceDisplay (neutral bzw.
	# Kanten-Material-Tint, siehe DieDefinition.edge_material).
	var edge_material := StandardMaterial3D.new()
	edge_material.albedo_color = DieFaceDisplay.EDGE_COLOR
	edge_material.roughness = 0.55
	edge_material.emission_enabled = true  # leichtes Eigenleuchten (siehe DieFaceDisplay.GLOW_STRENGTH)
	edge_material.emission = DieFaceDisplay.EDGE_COLOR * DieFaceDisplay.GLOW_STRENGTH
	faces.edge_material_res = edge_material

	# Umgebungslicht des Würfels (standardmäßig aus; nur die Spielwürfel
	# schalten es frei, siehe DieFaceDisplay.set_light_enabled) - lässt den
	# Würfel seine Umgebung tatsächlich beleuchten, Farbe/Stärke folgen den
	# Materialien (siehe DieFaceDisplay._refresh_die_light).
	var die_light := OmniLight3D.new()
	die_light.name = "DieLight"
	die_light.omni_range = DieFaceDisplay.LIGHT_RANGE
	die_light.light_color = DieFaceDisplay.LIGHT_BASE_COLOR
	die_light.light_energy = DieFaceDisplay.LIGHT_BASE_ENERGY
	die_light.shadow_enabled = false
	die_light.visible = false
	faces.add_child(die_light)
	faces.die_light = die_light

	var edges_root := Node3D.new()
	edges_root.name = "Edges"
	faces.add_child(edges_root)

	var fill := MeshInstance3D.new()
	fill.name = "Fill"
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3.ONE * HALF_EXTENT * 2.0
	fill.mesh = fill_mesh
	fill.material_override = edge_material
	edges_root.add_child(fill)

	# Je Kante ein Balken: jedes Paar senkrechter Achsrichtungen (a, b) bezeichnet
	# genau eine Kante (Mitte bei (a+b)·HALF_EXTENT, lang entlang der dritten
	# Achse) - 12 Paare = 12 Kanten. Balken gleicher Richtung teilen ihr BoxMesh.
	var beam_meshes := {}
	var directions: Array = DiceController.AXIS_DIRECTIONS.values()
	for i in directions.size():
		for j in range(i + 1, directions.size()):
			var a: Vector3 = directions[i]
			var b: Vector3 = directions[j]
			if not is_zero_approx(a.dot(b)):
				continue  # (anti)parallel = keine gemeinsame Kante
			var long_axis: Vector3 = a.cross(b).abs()
			if not beam_meshes.has(long_axis):
				var mesh := BoxMesh.new()
				mesh.size = Vector3.ONE * EDGE_THICKNESS + long_axis * HALF_EXTENT * 2.0
				beam_meshes[long_axis] = mesh
			var beam := MeshInstance3D.new()
			beam.mesh = beam_meshes[long_axis]
			beam.position = (a + b) * HALF_EXTENT
			beam.material_override = edge_material
			edges_root.add_child(beam)

	for axis: String in DiceController.AXIS_DIRECTIONS:
		var direction: Vector3 = DiceController.AXIS_DIRECTIONS[axis]
		var quad := MeshInstance3D.new()
		quad.name = "Face%s" % axis.capitalize()

		var quad_mesh := QuadMesh.new()
		quad_mesh.size = Vector2.ONE * FACE_SIZE
		quad.mesh = quad_mesh

		quad.position = direction * (HALF_EXTENT + FACE_MARGIN)
		quad.basis = _face_basis(direction, DiceController.FACE_TEXT_UP[axis])

		var default_value: int = DiceController.AXIS_FACE_INDEX[axis] + 1
		var mat := StandardMaterial3D.new()
		mat.albedo_color = DieFaceDisplay.BODY_COLOR
		mat.roughness = 0.55
		mat.emission_enabled = true  # leichtes Eigenleuchten (siehe DieFaceDisplay.GLOW_STRENGTH)
		mat.emission = DieFaceDisplay.BODY_COLOR * DieFaceDisplay.GLOW_STRENGTH
		quad.set_surface_override_material(0, mat)

		faces.add_child(quad)
		faces.quads[axis] = quad

		var label := _build_label(default_value)
		quad.add_child(label)
		faces.labels[axis] = label
		DieFaceDisplay.fit_label(label)

	return root

## Baut das Ziffern-Label eines Gesichts. Kind des Körper-Quads, minimal davor
## (+Z) gesetzt, damit es plan aufliegt, aber nicht mit dem Quad z-fightet; erbt
## dessen nach außen gerichtete Orientierung (siehe _face_basis).
static func _build_label(value: int) -> Label3D:
	var label := Label3D.new()
	label.name = "Value"
	label.text = str(value)
	label.font_size = DieFaceDisplay.LABEL_FONT_SIZE
	label.pixel_size = DieFaceDisplay.LABEL_PIXEL_SIZE
	label.modulate = DieFaceDisplay.NUMBER_COLOR
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS  # schreibt Tiefe + kantenglatt, korrektes Sortieren bei vielen Würfeln
	label.position = Vector3(0, 0, 0.01)  # Schauseite (+Z) zeigt nach außen (Quad-Normale), Ziffer liest sich seitenrichtig
	return label

## Orientierung eines Gesichts-Quads: z (Normale) zeigt nach außen (direction),
## y (Ziffern-"oben") entlang up (siehe DiceController.FACE_TEXT_UP), damit die
## Zahl frontal aufrecht steht. up muss senkrecht auf direction stehen.
static func _face_basis(direction: Vector3, up: Vector3) -> Basis:
	var z_axis := direction.normalized()
	var x_axis := up.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)
