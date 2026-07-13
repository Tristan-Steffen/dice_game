class_name DicePit
extends Node3D
## Baut die Würfelgrube prozedural: unsichtbarer Kollisionsboden, ein Ring aus
## kurzen, tangential ausgerichteten Wandsegmenten entlang einer Ellipse - und
## darüber je Segment ein sichtbares, durchscheinendes ENERGIEFELD (siehe
## assets/shaders/force_field.gdshader): Die Kollisionswand IST das Feld, das
## aus dem goldenen Emitter-Ring des Tischs aufsteigt.
##
## Die Maße folgen dem PitEmitterRing des Tischs (Tisch.glb, siehe
## tools/poker_tabletop.py): Ring lokal Halbachsen 2.1 x 1.9, mittig im Tisch;
## der Tisch steht 90 Grad gedreht mit Scale 4 bei (0, -3.8, 0) (siehe
## scenes/room.tscn) -> Ringmitte im Weltursprung, lange Halbachse 8.4 entlang
## Welt-Z, kurze 7.6 entlang Welt-X, Würfel landen auf dem Screen (Oberkante
## -3.4). WALL_SEGMENTS = 20 = Eckenzahl des sichtbaren Rings: Kollisions-
## Sehnen und Feld-Paneele liegen deckungsgleich auf den Ring-Facetten.
##
## PitClickZone (Kamera-Zoom-Ziel, Layer 8) bleibt ein normaler Szenenknoten
## in dice_tray.tscn - eigene, gröbere Kollisionsebene, unabhängig von dieser
## Würfel-Kollision.

## Weltposition der Ringmitte (y ohne Bedeutung) - auch Wurfziel und Anker der
## Würfel-Reihen in scene_root (siehe _pit_top_row_position).
const PIT_CENTER := Vector3(0.0, 0.0, 0.0)

const FLOOR_SIZE := Vector3(17, 2, 19)
const FLOOR_Y := -4.4  # Oberkante -3.4 = Screen-Oberfläche des Tischs

const ELLIPSE_SEMI_X := 7.6  # kurze Halbachse (Welt-X) = Ring 1.9 x Scale 4
const ELLIPSE_SEMI_Z := 8.4  # lange Halbachse (Welt-Z) = Ring 2.1 x Scale 4
const WALL_SEGMENTS := 20  # = PIT_RING_SIDES des sichtbaren Emitter-Rings
const WALL_HEIGHT := 16.0  # Oberkante 12.6 - bleibt unter den Wurf-Startpositionen (Y 13.695)
const WALL_THICKNESS := 1.0
const WALL_CENTER_Y := 4.6  # Unterkante bündig mit der Bodenoberseite (FLOOR_Y + FLOOR_SIZE.y / 2 + WALL_HEIGHT / 2)
const WALL_OVERLAP := 0.05  # kleine Überlappung zwischen Segmenten, keine Lücken im Ring

const BOUNCE := 0.25
const FRICTION := 0.4

## Sichtbares Feld: dünnes Paneel je Wandsegment, gleiche Lage wie die
## Kollisionsbox (nur schlanker), gemeinsames additives Shader-Material.
## Das Paneel ist so hoch wie die Kollisionswand, aber der Shader blendet
## oberhalb von FIELD_VISIBLE_HEIGHT auf null aus - das Feld wirkt niedrig,
## die Wand dahinter faengt trotzdem jeden hohen Abpraller.
const FIELD_THICKNESS := 0.12
const FIELD_VISIBLE_HEIGHT := WALL_HEIGHT / 3.0
const FIELD_SHADER := preload("res://assets/shaders/force_field.gdshader")

func _ready() -> void:
	var material := PhysicsMaterial.new()
	material.bounce = BOUNCE
	material.friction = FRICTION

	var field_material := ShaderMaterial.new()
	field_material.shader = FIELD_SHADER
	var field_bottom := FLOOR_Y + FLOOR_SIZE.y / 2.0
	field_material.set_shader_parameter("bottom_y", field_bottom)
	field_material.set_shader_parameter("top_y", field_bottom + FIELD_VISIBLE_HEIGHT)

	_add_box("Floor", Vector3(PIT_CENTER.x, FLOOR_Y, PIT_CENTER.z), Basis.IDENTITY, FLOOR_SIZE, material, "pit_floor")

	for i in WALL_SEGMENTS:
		var theta := TAU * float(i) / float(WALL_SEGMENTS)
		var next_theta := TAU * float(i + 1) / float(WALL_SEGMENTS)
		var point := Vector3(PIT_CENTER.x + ELLIPSE_SEMI_X * cos(theta), WALL_CENTER_Y, PIT_CENTER.z + ELLIPSE_SEMI_Z * sin(theta))
		var next_point := Vector3(PIT_CENTER.x + ELLIPSE_SEMI_X * cos(next_theta), WALL_CENTER_Y, PIT_CENTER.z + ELLIPSE_SEMI_Z * sin(next_theta))
		var mid := (point + next_point) * 0.5
		var x_axis := (next_point - point).normalized()  # tangential = Wandlänge
		var y_axis := Vector3.UP
		var z_axis := x_axis.cross(y_axis).normalized()  # radial = Wanddicke
		var segment_length := point.distance_to(next_point) + WALL_OVERLAP
		var segment_basis := Basis(x_axis, y_axis, z_axis)
		_add_box("Wall%d" % i, mid, segment_basis, Vector3(segment_length, WALL_HEIGHT, WALL_THICKNESS), material, "pit_wall")

		var panel_mesh := BoxMesh.new()
		panel_mesh.size = Vector3(segment_length, WALL_HEIGHT, FIELD_THICKNESS)
		panel_mesh.material = field_material
		var panel := MeshInstance3D.new()
		panel.name = "Field%d" % i
		panel.mesh = panel_mesh
		panel.transform = Transform3D(segment_basis, mid)
		add_child(panel)

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
