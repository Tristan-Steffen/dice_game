class_name DicePit
extends Node3D
## Baut die Würfelgrube prozedural: unsichtbarer Kollisionsboden und ein
## RECHTECKIGER Rand mit leicht abgerundeten Ecken aus kurzen, tangential
## ausgerichteten Wandsegmenten - und darüber je Segment ein sichtbares,
## durchscheinendes ENERGIEFELD (siehe assets/shaders/force_field.gdshader): Die
## Kollisionswand IST das Feld. In Ruhe ist das Feld fast unsichtbar; es blitzt
## nur beim Aufprall eines Würfels auf (siehe flash_segment).
##
## Der frühere goldene Emitter-Ring des Tischmodells ist entfernt, die Form ist
## damit frei: Grubenmitte im Weltursprung, halbe Höhe PIT_HALF_X entlang Welt-X,
## halbe Breite PIT_HALF_Z entlang Welt-Z (deutlich breiter als hoch), Würfel
## landen auf dem Screen (Oberkante -3.4). Der Rand entsteht aus einer
## Punktkette (siehe _rounded_rect_points): gerade Kanten als lange Boxen, Ecken
## als kurze Bogen-Segmente.
##
## PitClickZone (Kamera-Zoom-Ziel, Layer 8) bleibt ein normaler Szenenknoten
## in dice_tray.tscn - eigene, gröbere Kollisionsebene, unabhängig von dieser
## Würfel-Kollision.

## Weltposition der Ringmitte (y ohne Bedeutung) - auch Wurfziel und Anker der
## Würfel-Reihen in scene_root (siehe _pit_top_row_position).
const PIT_CENTER := Vector3(0.0, 0.0, 0.0)

const FLOOR_SIZE := Vector3(17, 2, 31)  # Z groß genug für die breitere Grube (siehe PIT_HALF_Z)
const FLOOR_Y := -4.4  # Oberkante -3.4 = Screen-Oberfläche des Tischs

## RECHTECKIGE Grube mit leicht abgerundeten Ecken (der frühere goldene
## Emitter-Ring ist raus, die Form ist jetzt frei). PIT_HALF_X = halbe Höhe auf
## dem Bildschirm (Welt-X, unverändert), PIT_HALF_Z = halbe Breite (Welt-Z) -
## rund 70% breiter als zuvor (8.4 -> 14.28). CORNER_RADIUS macht die Ecken
## sanft; CORNER_STEPS ist die Zahl der Bogen-Segmente je Ecke.
const PIT_HALF_X := 7.6           # halbe Höhe (Welt-X) - "so hoch wie bisher"
const PIT_HALF_Z := 14.28         # halbe Breite (Welt-Z) - ~70% breiter als bisher (8.4 × 1.7)
const CORNER_RADIUS := 2.0        # leichte Rundung der Ecken
const CORNER_STEPS := 4           # Bogen-Segmente je Ecke (4 Ecken -> 4·(CORNER_STEPS+1) Wandsegmente)
const WALL_HEIGHT := 16.0  # Oberkante 12.6 - bleibt unter den Wurf-Startpositionen (Y 13.695)
const WALL_THICKNESS := 1.0
const WALL_CENTER_Y := 4.6  # Unterkante bündig mit der Bodenoberseite (FLOOR_Y + FLOOR_SIZE.y / 2 + WALL_HEIGHT / 2)
const WALL_OVERLAP := 0.05  # kleine Überlappung zwischen Segmenten, keine Lücken im Rand

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
## Abklingzeit des Aufprall-Blitzes je Segment (impact 1 -> 0, siehe flash_segment).
const FIELD_FLASH_DECAY := 0.5

## Je Wandsegment ein EIGENES Feld-Material (gleicher Shader), damit sich beim
## Aufprall nur das getroffene Segment aufblitzen lässt (siehe flash_segment).
var field_materials: Array[ShaderMaterial] = []
var _field_tweens: Array[Tween] = []

func _ready() -> void:
	var material := PhysicsMaterial.new()
	material.bounce = BOUNCE
	material.friction = FRICTION

	var field_bottom := FLOOR_Y + FLOOR_SIZE.y / 2.0

	_add_box("Floor", Vector3(PIT_CENTER.x, FLOOR_Y, PIT_CENTER.z), Basis.IDENTITY, FLOOR_SIZE, material, "pit_floor")

	# Perimeter der abgerundeten Rechteck-Grube als Punktkette (siehe
	# _rounded_rect_points); je zwei aufeinanderfolgende Punkte spannen ein
	# Wandsegment + Feld-Paneel auf (gerade Kanten = lange Boxen, Ecken = kurze).
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

## Punktkette (im Uhrzeigergegensinn) entlang des abgerundeten Rechteck-Rands auf
## Wandhöhe (WALL_CENTER_Y): vier Viertelkreis-Ecken (Radius CORNER_RADIUS, je
## CORNER_STEPS Bogen-Segmente), dazwischen liegen automatisch die geraden Kanten
## (der Abstand zwischen dem letzten Punkt einer Ecke und dem ersten der nächsten).
func _rounded_rect_points() -> Array:
	var pts: Array = []
	var cx := PIT_HALF_X - CORNER_RADIUS
	var cz := PIT_HALF_Z - CORNER_RADIUS
	# Eckzentrum (X, Z) + Startwinkel je Ecke, so dass die Bögen die geraden
	# Kanten sauber verbinden (X = cos, Z = sin um das Zentrum).
	var corners := [
		[Vector2(cx, cz), 0.0],       # oben-rechts  (+X, +Z)
		[Vector2(-cx, cz), 90.0],     # unten-rechts (-X, +Z)
		[Vector2(-cx, -cz), 180.0],   # unten-links  (-X, -Z)
		[Vector2(cx, -cz), 270.0],    # oben-links   (+X, -Z)
	]
	for corner in corners:
		var c: Vector2 = corner[0]
		var a0: float = corner[1]
		for k in CORNER_STEPS + 1:
			var a := deg_to_rad(a0 + 90.0 * float(k) / float(CORNER_STEPS))
			pts.append(Vector3(c.x + CORNER_RADIUS * cos(a), WALL_CENTER_Y, c.y + CORNER_RADIUS * sin(a)))
	return pts

## Lässt das Feldsegment der getroffenen Wand (StaticBody "Wall<i>", siehe
## _add_box) mit der gegebenen Stärke aufblitzen - gerufen von scene_root beim
## Wand-Kontakt eines Würfels.
func flash_wall(wall_body: Node, strength: float) -> void:
	var suffix := String(wall_body.name).trim_prefix("Wall")
	if suffix.is_valid_int():
		flash_segment(int(suffix), strength)

## Blitzt Segment index kurz auf: setzt seinen impact-Parameter auf strength und
## lässt ihn über FIELD_FLASH_DECAY auf 0 abklingen (ein laufendes Abklingen wird
## dabei ersetzt, damit ein erneuter Treffer sofort wieder hell wird).
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
