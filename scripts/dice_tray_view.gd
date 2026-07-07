class_name DiceTrayView
extends Node3D
## Zeigt bis zu 30 Würfel in einem Raster auf einem Kunststoff-Tray (wie ein
## Casino-Chip-Tray). Tray-Mesh und Klickbereich sind echte Kindknoten dieser
## Szene (siehe scenes/dice_chip_tray.tscn); die 30 Würfel werden bei _ready()
## per DieBuilder gebaut und unter $Slots eingehängt (siehe COLUMNS/ROWS/
## SPACING für das Raster).
##
## Wird in zwei Rollen verwendet: als Pool-Tray (alle 30 sichtbar, werden
## beim Ziehen ausgeblendet - siehe set_layout/mark_used/set_queued) und als
## Ablage-Tray für bereits benutzte Würfel (startet leer, gebrauchte Würfel
## werden nacheinander eingeblendet - siehe clear/add_die).

const COLUMNS := 5
const ROWS := 6
const SPACING := Vector2(1.8, 1.8)
const DIE_SCALE := 0.5
const REST_Y := 0.5  # Höhe der Würfel über dem Tray-Boden (lokal, Boden = y 0)

const QUEUED_TINT := Color(1.0, 0.85, 0.2)

@export var tray_color: Color = Color(0.15, 0.35, 0.75):
	set(value):
		tray_color = value
		if is_inside_tree():
			_apply_tray_color()

@onready var tray_mesh_root: Node3D = $TrayMesh
@onready var slots_container: Node3D = $Slots

## Unsichtbarer Klickbereich über dem ganzen Tray (Layer 4), damit die
## Kamera per Klick auf dieses Tray zoomen kann - siehe CameraRig.
@onready var click_zone: StaticBody3D = $ClickZone

var slot_roots: Array[Node3D] = []
var slot_face_displays: Array[DieFaceDisplay] = []
var slot_defs: Array[DieDefinition] = []
var plastic_material: StandardMaterial3D

var next_free_index: int = 0  # nächster freier Slot im Ablage-Modus (add_die)

func _ready() -> void:
	_apply_tray_color()
	_build_slots()

## Färbt die Tray-Mesh-Teile (Boden, Wände, Trennstege) in tray_color ein.
func _apply_tray_color() -> void:
	plastic_material = StandardMaterial3D.new()
	plastic_material.albedo_color = tray_color
	plastic_material.roughness = 0.25
	plastic_material.metallic = 0.05
	for mesh_instance in tray_mesh_root.get_children():
		if mesh_instance is MeshInstance3D:
			mesh_instance.set_surface_override_material(0, plastic_material)

## Baut die 30 dekorativen Würfel-Slots im 5x6-Raster (eingefroren und aus
## den Kollisions-Layern genommen - kein Physik-Overhead nötig).
func _build_slots() -> void:
	slot_roots.clear()
	slot_face_displays.clear()
	slot_defs.clear()
	for i in COLUMNS * ROWS:
		var col := i % COLUMNS
		var row := i / COLUMNS
		var x := (col - (COLUMNS - 1) / 2.0) * SPACING.x
		var z := (row - (ROWS - 1) / 2.0) * SPACING.y

		var die := DieBuilder.build()
		slots_container.add_child(die)
		die.position = Vector3(x, REST_Y, z)
		die.scale = Vector3.ONE * DIE_SCALE
		die.visible = false

		var body: RigidBody3D = die.get_node("RigidBody3D")
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0

		slot_roots.append(die)
		slot_face_displays.append(die.get_node("RigidBody3D/Faces"))
		slot_defs.append(DieDefinition.standard())

## --- Pool-Modus: alle Slots vorbelegt, werden einzeln ausgeblendet ---

## Setzt das komplette Layout für eine neue Runde: alle 30 Slots sichtbar,
## eingefärbt nach Würfelart.
func set_layout(defs: Array[DieDefinition]) -> void:
	for i in slot_roots.size():
		slot_roots[i].visible = true
		var def: DieDefinition = defs[i] if i < defs.size() else DieDefinition.standard()
		slot_defs[i] = def
		slot_face_displays[i].apply_definition(def)
		slot_face_displays[i].set_tint(_style_tint(def))

## Blendet einen einzelnen Slot aus (Würfel wurde tatsächlich gezogen/verbraucht).
func mark_used(index: int) -> void:
	if index >= 0 and index < slot_roots.size():
		slot_roots[index].visible = false

## Markiert genau die übergebenen (noch sichtbaren) Slots als "als Nächstes
## dran" - alle anderen verlieren die Markierung.
func set_queued(indices: Array[int]) -> void:
	var queued := {}
	for i in indices:
		queued[i] = true
	for i in slot_roots.size():
		if not slot_roots[i].visible:
			continue
		var tint: Color = QUEUED_TINT if queued.has(i) else _style_tint(slot_defs[i])
		slot_face_displays[i].set_tint(tint)

## --- Ablage-Modus: startet leer, füllt sich Würfel für Würfel ---

## Leert das Tray (z.B. zu Rundenbeginn), bereit für neue Ablagen.
func clear() -> void:
	next_free_index = 0
	for root in slot_roots:
		root.visible = false

## Legt einen weiteren gebrauchten Würfel in den nächsten freien Slot.
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
