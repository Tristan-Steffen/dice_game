class_name DiceTrayView
extends Node3D
## Zeigt Würfel in einem rows×columns-Raster über einem Lichtgitter (statt
## Plastik-Tray). Slot-Reihenfolge liest wie ein Buch: 0 = oben links, dann
## zeilenweise. Drei Rollen: Pool- und Warteschlangen-Tray (setzen bei jeder
## Änderung ihren Inhalt komplett neu, siehe fill) sowie Ablage-Tray
## (startet leer, füllt sich an - siehe clear/add_die).

@export var rows: int = 5
@export var columns: int = 6
const SPACING := Vector2(1.8, 1.8)
const DIE_SCALE := 0.6  # gemeinsame Würfelgröße (Tray + Grube)
## Höhe der Würfel-MITTE über dem Boden = skalierte Halbhöhe, damit die
## Unterseite genau auf dem Tischbildschirm aufliegt.
const REST_Y := DIE_SCALE

@export var tray_color: Color = Color(0.15, 0.35, 0.75):
	set(value):
		tray_color = value
		if is_inside_tree():
			_rebuild_grid()

@onready var tray_mesh_root: Node3D = $TrayMesh
@onready var slots_container: Node3D = $Slots

## Lichtgitter: dünne leuchtende Balken knapp über dem Tischfilz, unbeleuchtet
## und über den Glow-Schwellwert hinaus leuchtend.
const GRID_Y := 0.03
const GRID_LINE_WIDTH := 0.09
const GRID_LINE_HEIGHT := 0.05
const GRID_EMISSION_ENERGY := 2.6
var grid_root: Node3D

## Unsichtbarer Klickbereich (Layer 4) für den Kamera-Zoom auf dieses Tray.
@onready var click_zone: StaticBody3D = $ClickZone

## Kollisions-Layer der Slot-Bodies - macht einzelne Tray-Würfel anklickbar.
const SLOT_PICK_LAYER := 16

var slot_roots: Array[Node3D] = []
var slot_bodies: Array[RigidBody3D] = []
var slot_face_displays: Array[DieFaceDisplay] = []
var slot_defs: Array[DieDefinition] = []

var next_free_index: int = 0  # nächster freier Slot im Ablage-Modus

func _ready() -> void:
	tray_mesh_root.visible = false  # das Lichtgitter ersetzt das Plastik-Tray
	_build_slots()
	_rebuild_grid()

## Baut das Lichtgitter passend zum rows×columns-Raster neu.
func _rebuild_grid() -> void:
	if grid_root != null:
		grid_root.queue_free()
	grid_root = Node3D.new()
	grid_root.name = "Grid"
	add_child(grid_root)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tray_color
	material.emission_enabled = true
	material.emission = tray_color
	material.emission_energy_multiplier = GRID_EMISSION_ENERGY

	var half_x := rows * 0.5 * SPACING.x
	var half_z := columns * 0.5 * SPACING.y
	for k in rows + 1:
		var x := half_x - float(k) * SPACING.x
		_add_grid_bar(material, Vector3(x, GRID_Y, 0.0),
			Vector3(GRID_LINE_WIDTH, GRID_LINE_HEIGHT, half_z * 2.0))
	for k in columns + 1:
		var z := -half_z + float(k) * SPACING.y
		_add_grid_bar(material, Vector3(0.0, GRID_Y, z),
			Vector3(half_x * 2.0, GRID_LINE_HEIGHT, GRID_LINE_WIDTH))

func _add_grid_bar(material: StandardMaterial3D, at: Vector3, size: Vector3) -> void:
	var bar := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	bar.mesh = mesh
	bar.material_override = material
	bar.position = at
	grid_root.add_child(bar)

## Baut die dekorativen Würfel-Slots (eingefroren, ohne Physik-Overhead).
func _build_slots() -> void:
	slot_roots.clear()
	slot_bodies.clear()
	slot_face_displays.clear()
	slot_defs.clear()
	for i in rows * columns:
		var line := i / columns
		var pos_in_line := i % columns
		var x := ((rows - 1) / 2.0 - line) * SPACING.x
		var z := (pos_in_line - (columns - 1) / 2.0) * SPACING.y

		var die := DieBuilder.build()
		slots_container.add_child(die)
		die.position = Vector3(x, REST_Y, z)
		# 90° aus der Draufsicht: die Ziffer der Oben-Seite steht für den
		# Spieler aufrecht (FACE_TEXT_UP -Z dreht auf Welt +X = Bildschirm-oben).
		die.rotation.y = -PI / 2.0
		die.scale = Vector3.ONE * DIE_SCALE
		die.visible = false

		var body: RigidBody3D = die.get_node("RigidBody3D")
		body.freeze = true
		body.collision_layer = SLOT_PICK_LAYER
		body.collision_mask = 0

		slot_roots.append(die)
		slot_bodies.append(body)
		slot_face_displays.append(die.get_node("RigidBody3D/Faces"))
		slot_defs.append(DieDefinition.standard())

## Erweitert das Raster um Spalten, bis mindestens capacity Slots existieren
## (Ausziehtisch). Den sichtbaren Inhalt setzt der nächste fill()-Aufruf.
func ensure_capacity(capacity: int) -> void:
	if rows * columns >= capacity:
		return
	columns = int(ceil(float(capacity) / rows))
	for child in slots_container.get_children():
		child.queue_free()
	_build_slots()
	_rebuild_grid()

## Setzt den Inhalt komplett neu: erste defs.size() Slots gefüllt (kompakt
## von vorn, nie eine Lücke mittendrin), Rest ausgeblendet.
func fill(defs: Array[DieDefinition]) -> void:
	for i in slot_roots.size():
		if i < defs.size():
			var def: DieDefinition = defs[i]
			slot_roots[i].visible = true
			slot_defs[i] = def
			slot_face_displays[i].apply_definition(def)
			slot_face_displays[i].set_tint(_style_tint(def))
		else:
			slot_roots[i].visible = false

## Leert das Tray (Ablage-Modus, z.B. zu Rundenbeginn).
func clear() -> void:
	next_free_index = 0
	for root in slot_roots:
		root.visible = false

## Legt einen Würfel in den nächsten freien Slot (Ablage-Modus).
func add_die(def: DieDefinition) -> void:
	if next_free_index >= slot_roots.size():
		return
	var i := next_free_index
	next_free_index += 1
	slot_roots[i].visible = true
	slot_defs[i] = def
	slot_face_displays[i].apply_definition(def)
	slot_face_displays[i].set_tint(_style_tint(def))

func _style_tint(def: DieDefinition) -> Color:
	return DiceController.KIND_TINTS.get(def.style_id, Color.WHITE)

## Zeichnet die Augenzahlen aller sichtbaren Slots neu aus slot_defs (nach
## einer Ätzung - slot_defs hält dieselben Instanzen wie der Pool).
func refresh_faces() -> void:
	for i in slot_roots.size():
		if slot_roots[i].visible:
			slot_face_displays[i].apply_definition(slot_defs[i])
			slot_face_displays[i].set_tint(_style_tint(slot_defs[i]))

## Weltposition eines Slots - auch für leere/unsichtbare (Animations-Ziele).
func slot_global_position(index: int) -> Vector3:
	return slot_roots[index].global_position

## Blendet genau einen Slot aus/ein, ohne den Inhalt zu ändern (Drag-Ghost);
## fill() stellt die normale Sichtbarkeit wieder her.
func set_slot_visible(index: int, is_visible: bool) -> void:
	slot_roots[index].visible = is_visible

## Slot-Index zum per Raycast getroffenen Body, oder -1. Auch leere Slots
## behalten ihre Kollisionsform - darum zusätzlich Sichtbarkeit prüfen.
func find_slot_index(collider: Object) -> int:
	var i := slot_bodies.find(collider)
	if i == -1 or not slot_roots[i].visible:
		return -1
	return i
