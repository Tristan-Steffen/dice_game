class_name DicePit
extends Node3D
## Baut die Würfelgrube prozedural: unsichtbarer Kollisionsboden und ein
## rechteckiger Rand mit abgerundeten Ecken aus kurzen Wandsegmenten; über
## jedem Segment ein durchscheinendes ENERGIEFELD - die Kollisionswand IST
## das Feld. In Ruhe fast unsichtbar, blitzt beim Würfel-Aufprall auf.
## PitClickZone (Kamera-Zoom, Layer 8) bleibt ein Szenenknoten in dice_tray.tscn.

## Weltposition der Grubenmitte (y ohne Bedeutung) - auch Wurfziel.
const PIT_CENTER := Vector3(0.0, 0.0, 0.0)

const FLOOR_SIZE := Vector3(17, 2, 31)
const FLOOR_Y := -1.0  # Oberkante 0 = Screen-Oberfläche des Tischs

## PIT_HALF_X = halbe Höhe auf dem Bildschirm (Welt-X), PIT_HALF_Z = halbe
## Breite (Welt-Z, deutlich breiter als hoch).
const PIT_HALF_X := 7.6
const PIT_HALF_Z := 14.28
const CORNER_RADIUS := 2.0
const CORNER_STEPS := 4  # Bogen-Segmente je Ecke
const WALL_HEIGHT := 16.0  # bleibt unter den Wurf-Startpositionen (Y ~17.1)
const WALL_THICKNESS := 1.0
const WALL_CENTER_Y := 8.0  # Unterkante bündig mit der Bodenoberseite
const WALL_OVERLAP := 0.05  # keine Lücken zwischen Segmenten

const BOUNCE := 0.25
const FRICTION := 0.4

## Sichtbares Feld: dünnes Paneel je Wandsegment. So hoch wie die Wand, aber
## der Shader blendet oberhalb FIELD_VISIBLE_HEIGHT aus - das Feld wirkt
## niedrig, die Wand fängt trotzdem jeden hohen Abpraller.
const FIELD_THICKNESS := 0.12
const FIELD_VISIBLE_HEIGHT := WALL_HEIGHT / 3.0
const FIELD_SHADER := preload("res://assets/shaders/force_field.gdshader")
const FIELD_FLASH_DECAY := 0.5

## Je Segment ein EIGENES Material, damit nur das getroffene aufblitzt.
var field_materials: Array[ShaderMaterial] = []
var _field_tweens: Array[Tween] = []

func _ready() -> void:
	var material := PhysicsMaterial.new()
	material.bounce = BOUNCE
	material.friction = FRICTION

	var field_bottom := FLOOR_Y + FLOOR_SIZE.y / 2.0

	_add_box("Floor", Vector3(PIT_CENTER.x, FLOOR_Y, PIT_CENTER.z), Basis.IDENTITY, FLOOR_SIZE, material, "pit_floor")

	# Je zwei aufeinanderfolgende Perimeter-Punkte spannen ein Wandsegment +
	# Feld-Paneel auf (gerade Kanten = lange Boxen, Ecken = kurze).
	var points := _rounded_rect_points()
	field_materials.resize(points.size())
	_field_tweens.resize(points.size())
	for i in points.size():
		var point: Vector3 = points[i]
		var next_point: Vector3 = points[(i + 1) % points.size()]
		var mid := (point + next_point) * 0.5
		var x_axis := (next_point - point).normalized()  # tangential = Wandlänge
		var y_axis := Vector3.UP
		var z_axis := x_axis.cross(y_axis).normalized()  # radial = Wanddicke
		var segment_length := point.distance_to(next_point) + WALL_OVERLAP
		var segment_basis := Basis(x_axis, y_axis, z_axis)
		_add_box("Wall%d" % i, mid, segment_basis, Vector3(segment_length, WALL_HEIGHT, WALL_THICKNESS), material, "pit_wall")

		var field_material := ShaderMaterial.new()
		field_material.shader = FIELD_SHADER
		field_material.set_shader_parameter("bottom_y", field_bottom)
		field_material.set_shader_parameter("top_y", field_bottom + FIELD_VISIBLE_HEIGHT)
		field_materials[i] = field_material

		var panel_mesh := BoxMesh.new()
		panel_mesh.size = Vector3(segment_length, WALL_HEIGHT, FIELD_THICKNESS)
		panel_mesh.material = field_material
		var panel := MeshInstance3D.new()
		panel.name = "Field%d" % i
		panel.mesh = panel_mesh
		panel.transform = Transform3D(segment_basis, mid)
		add_child(panel)

## Punktkette entlang des abgerundeten Rechteck-Rands auf Wandhöhe: vier
## Viertelkreis-Ecken, dazwischen automatisch die geraden Kanten.
func _rounded_rect_points() -> Array:
	var pts: Array = []
	var cx := PIT_HALF_X - CORNER_RADIUS
	var cz := PIT_HALF_Z - CORNER_RADIUS
	# Eckzentrum (X, Z) + Startwinkel, so dass die Bögen die Kanten verbinden.
	var corners := [
		[Vector2(cx, cz), 0.0],
		[Vector2(-cx, cz), 90.0],
		[Vector2(-cx, -cz), 180.0],
		[Vector2(cx, -cz), 270.0],
	]
	for corner in corners:
		var c: Vector2 = corner[0]
		var a0: float = corner[1]
		for k in CORNER_STEPS + 1:
			var a := deg_to_rad(a0 + 90.0 * float(k) / float(CORNER_STEPS))
			pts.append(Vector3(c.x + CORNER_RADIUS * cos(a), WALL_CENTER_Y, c.y + CORNER_RADIUS * sin(a)))
	return pts

## Blitzt das Feldsegment der getroffenen Wand ("Wall<i>") auf.
func flash_wall(wall_body: Node, strength: float) -> void:
	var suffix := String(wall_body.name).trim_prefix("Wall")
	if suffix.is_valid_int():
		flash_segment(int(suffix), strength)

## Setzt impact auf strength und klingt über FIELD_FLASH_DECAY auf 0 ab;
## ein laufendes Abklingen wird ersetzt (erneuter Treffer wird sofort hell).
func flash_segment(index: int, strength: float) -> void:
	if index < 0 or index >= field_materials.size():
		return
	if _field_tweens[index] != null and _field_tweens[index].is_valid():
		_field_tweens[index].kill()
	var material := field_materials[index]
	var peak := clampf(strength, 0.0, 1.0)
	material.set_shader_parameter("impact", peak)
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: material.set_shader_parameter("impact", v),
		peak, 0.0, FIELD_FLASH_DECAY)
	_field_tweens[index] = tween

## group unterscheidet Boden- und Wandkontakte für den Würfel-Sound.
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
