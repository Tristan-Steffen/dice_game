class_name DiceTrayView
extends Node3D
## Zeigt bis zu 30 Würfel in einem Raster auf einem Kunststoff-Tray (wie ein
## Casino-Chip-Tray). Tray-Mesh, Klickbereich und die 30 Würfel-Slots sind
## echte Kindknoten dieser Szene (siehe scenes/dice_chip_tray.tscn), nicht
## zur Laufzeit gebaut - dieses Skript färbt/steuert sie nur noch.
##
## Wird in zwei Rollen verwendet: als Pool-Tray (alle 30 sichtbar, werden
## beim Ziehen ausgeblendet - siehe set_layout/mark_used/set_queued) und als
## Ablage-Tray für bereits benutzte Würfel (startet leer, gebrauchte Würfel
## werden nacheinander eingeblendet - siehe clear/add_die).

const COLUMNS := 5
const ROWS := 6

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
var slot_meshes: Array[MeshInstance3D] = []
var kind_tint_materials: Dictionary = {}
var queued_material: StandardMaterial3D
var plastic_material: StandardMaterial3D

var next_free_index: int = 0  # nächster freier Slot im Ablage-Modus (add_die)

func _ready() -> void:
	for kind in DiceController.KIND_TINTS:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = DiceController.KIND_TINTS[kind]
		mat.emission_enabled = true
		mat.emission = DiceController.KIND_TINTS[kind]
		mat.emission_energy_multiplier = 0.4
		kind_tint_materials[kind] = mat

	queued_material = StandardMaterial3D.new()
	queued_material.albedo_color = Color(1.0, 0.85, 0.2)
	queued_material.emission_enabled = true
	queued_material.emission = Color(1.0, 0.75, 0.1)
	queued_material.emission_energy_multiplier = 0.7

	_apply_tray_color()
	_collect_slots()

## Färbt die Tray-Mesh-Teile (Boden, Wände, Trennstege) in tray_color ein.
func _apply_tray_color() -> void:
	plastic_material = StandardMaterial3D.new()
	plastic_material.albedo_color = tray_color
	plastic_material.roughness = 0.25
	plastic_material.metallic = 0.05
	for mesh_instance in tray_mesh_root.get_children():
		if mesh_instance is MeshInstance3D:
			mesh_instance.set_surface_override_material(0, plastic_material)

## Liest die 30 vorhandenen Würfel-Slots (Kindknoten von $Slots) aus und
## macht sie zu rein dekorativen, eingefrorenen Würfeln (kein Kollisions-
## Overhead). Wird zur Laufzeit gesetzt statt in der Szene gebacken, weil
## alle 30 Slot-Instanzen intern denselben unique_id aus der Basisszene
## (die.tscn) teilen - eigene Node-Overrides dafür würden Godot beim Laden
## der Szene zu Duplikaten verleiten.
func _collect_slots() -> void:
	slot_roots.clear()
	slot_meshes.clear()
	for slot in slots_container.get_children():
		var body: RigidBody3D = slot.get_node("RigidBody3D")
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
		var mesh: MeshInstance3D = body.get_node("Die")
		slot_roots.append(slot)
		slot_meshes.append(mesh)

## --- Pool-Modus: alle Slots vorbelegt, werden einzeln ausgeblendet ---

## Setzt das komplette Layout für eine neue Runde: alle 30 Slots sichtbar,
## eingefärbt nach Würfelart.
func set_layout(defs: Array[DieDefinition]) -> void:
	for i in slot_roots.size():
		slot_roots[i].visible = true
		var style_id: String = defs[i].style_id if i < defs.size() else "normal"
		slot_meshes[i].set_surface_override_material(0, kind_tint_materials.get(style_id))
		slot_meshes[i].set_surface_override_material(1, null)

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
	for i in slot_meshes.size():
		if not slot_roots[i].visible:
			continue
		slot_meshes[i].set_surface_override_material(1, queued_material if queued.has(i) else null)

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
	slot_meshes[i].set_surface_override_material(0, kind_tint_materials.get(def.style_id))
	slot_meshes[i].set_surface_override_material(1, null)
