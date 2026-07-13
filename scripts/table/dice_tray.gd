extends Node3D
## Baut die Kollision der Würfelgrube prozedural: Boden plus ein Ring aus
## kurzen, tangential ausgerichteten Wandsegmenten, die eine Ellipse annähern.
## Passt damit deutlich besser zur tatsächlich runden Kontur der sichtbaren
## Grube (Teil des importierten Tischmodells, siehe scenes/room.tscn) als
## vorher 4 rechtwinklige Wände, deren Ecken über den runden Rand
## hinausragten. Ellipsen-Maße wurden per Mausklick-Raycast gegen die
## Bodenebene kalibriert (Kanten der sichtbaren Grube abgetastet).
##
## PitClickZone (Kamera-Zoom-Ziel, Layer 8) bleibt ein normaler Szenenknoten
## in dice_tray.tscn - eigene, gröbere Kollisionsebene, unabhängig von dieser
## Würfel-Kollision.

const FLOOR_SIZE := Vector3(22, 2, 20)
const FLOOR_Y := -8.23

const ELLIPSE_SEMI_X := 10.5  # Halbachse in Tiefenrichtung (Welt-X)
const ELLIPSE_SEMI_Z := 9.5  # Halbachse in Seitenrichtung (Welt-Z)
const WALL_SEGMENTS := 20
const WALL_HEIGHT := 20.0
const WALL_THICKNESS := 1.0
const WALL_CENTER_Y := 2.77  # Unterkante bündig mit der Bodenoberseite (FLOOR_Y + FLOOR_SIZE.y / 2)
const WALL_OVERLAP := 0.05  # kleine Überlappung zwischen Segmenten, keine Lücken im Ring

const BOUNCE := 0.25
const FRICTION := 0.4

func _ready() -> void:
	var material := PhysicsMaterial.new()
	material.bounce = BOUNCE
	material.friction = FRICTION

	_add_box("Floor", Vector3(0, FLOOR_Y, 0), Basis.IDENTITY, FLOOR_SIZE, material, "pit_floor")

	for i in WALL_SEGMENTS:
		var theta := TAU * float(i) / float(WALL_SEGMENTS)
		var next_theta := TAU * float(i + 1) / float(WALL_SEGMENTS)
		var point := Vector3(ELLIPSE_SEMI_X * cos(theta), WALL_CENTER_Y, ELLIPSE_SEMI_Z * sin(theta))
		var next_point := Vector3(ELLIPSE_SEMI_X * cos(next_theta), WALL_CENTER_Y, ELLIPSE_SEMI_Z * sin(next_theta))
		var mid := (point + next_point) * 0.5
		var x_axis := (next_point - point).normalized()  # tangential = Wandlänge
		var y_axis := Vector3.UP
		var z_axis := x_axis.cross(y_axis).normalized()  # radial = Wanddicke
		var segment_length := point.distance_to(next_point) + WALL_OVERLAP
		_add_box("Wall%d" % i, mid, Basis(x_axis, y_axis, z_axis), Vector3(segment_length, WALL_HEIGHT, WALL_THICKNESS), material, "pit_wall")

## group unterscheidet Boden- und Wandkontakte für den Würfel-Sound (siehe DiceAudio).
func _add_box(node_name: String, box_position: Vector3, box_basis: Basis, size: Vector3, material: PhysicsMaterial, group: String) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_mask = 0
	body.add_to_group(group)
	body.physics_material_override = material
	body.transform = Transform3D(box_basis, box_position)
	add_child(body)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
