class_name DieBuilder
extends RefCounted
## Baut einen kompletten Würfel (RigidBody3D + Kollision + 6 Gesichts-Quads,
## siehe DieFaceDisplay) komplett per Code zusammen - keine .tscn-Datei mehr
## nötig. Wird sowohl für die 6 Spielwürfel (scene_root.gd) als auch die 30
## Tray-Würfel (dice_tray_view.gd) verwendet.
##
## Die 6 Quads bilden den kompletten sichtbaren Würfel (jedes SVG-Icon
## enthält schon Rand+Punkte auf schwarzem Grund) - es gibt keinen separaten
## Körper-Mesh mehr.

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
		quad.basis = _face_basis(direction)

		var default_value: int = DiceController.AXIS_FACE_INDEX[axis] + 1
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = DieFaceDisplay.FACE_TEXTURES[default_value]
		quad.set_surface_override_material(0, mat)

		faces.add_child(quad)
		faces.quads[axis] = quad

	return root

static func _face_basis(direction: Vector3) -> Basis:
	var up_hint := Vector3(0, 0, -1)
	if absf(direction.dot(up_hint)) > 0.99:
		up_hint = Vector3.RIGHT
	var z_axis := direction.normalized()
	var x_axis := up_hint.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)
