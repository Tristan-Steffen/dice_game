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
	faces.set_script(load("res://scripts/die_face_display.gd"))
	body.add_child(faces)

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
