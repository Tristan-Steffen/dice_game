class_name DiceTrayView
extends Node3D
## Zeigt bis zu 30 Würfel in einem Raster auf einem prozedural gebauten
## Kunststoff-Tray (wie ein Casino-Chip-Tray). Wird in zwei Rollen verwendet:
## als Pool-Tray (alle 30 sichtbar, werden beim Ziehen ausgeblendet - siehe
## set_layout/mark_used/set_queued) und als Ablage-Tray für bereits benutzte
## Würfel (startet leer, gebrauchte Würfel werden nacheinander eingeblendet -
## siehe clear/add_die).

const COLUMNS := 5
const ROWS := 6
const SPACING := Vector2(1.8, 1.8)
const DIE_SCALE := 0.5
const REST_Y := 0.5  # Höhe der Würfel über dem Tray-Boden (lokal, Boden = y 0)

@export var tray_color: Color = Color(0.15, 0.35, 0.75)

var die_scene: PackedScene = preload("res://scenes/die.tscn")

var slot_roots: Array[Node3D] = []
var slot_meshes: Array[MeshInstance3D] = []
var kind_tint_materials: Dictionary = {}
var queued_material: StandardMaterial3D

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

	_build_tray_mesh()
	_build_slots()

## Baut den sichtbaren Kunststoff-Tray: eine Bodenplatte, ein umlaufender
## Rand und dünne Trennstege zwischen den Spalten (wie die Bahnen eines
## echten Chip-Trays) - rein dekorativ, ohne Kollision.
func _build_tray_mesh() -> void:
	var plastic := StandardMaterial3D.new()
	plastic.albedo_color = tray_color
	plastic.roughness = 0.25
	plastic.metallic = 0.05

	var inner_w: float = (COLUMNS - 1) * SPACING.x + 2.0
	var inner_d: float = (ROWS - 1) * SPACING.y + 2.0
	var wall_t := 0.5
	var base_h := 0.6
	var wall_h := 1.2

	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(inner_w + wall_t * 2.0, base_h, inner_d + wall_t * 2.0)
	base_mesh.material = plastic
	_add_mesh(base_mesh, Vector3(0, -base_h / 2.0, 0))

	var half_w := inner_w / 2.0 + wall_t / 2.0
	var half_d := inner_d / 2.0 + wall_t / 2.0
	var ns_wall := BoxMesh.new()
	ns_wall.size = Vector3(inner_w + wall_t * 2.0, wall_h, wall_t)
	ns_wall.material = plastic
	_add_mesh(ns_wall, Vector3(0, wall_h / 2.0, half_d))
	_add_mesh(ns_wall, Vector3(0, wall_h / 2.0, -half_d))

	var ew_wall := BoxMesh.new()
	ew_wall.size = Vector3(wall_t, wall_h, inner_d + wall_t * 2.0)
	ew_wall.material = plastic
	_add_mesh(ew_wall, Vector3(half_w, wall_h / 2.0, 0))
	_add_mesh(ew_wall, Vector3(-half_w, wall_h / 2.0, 0))

	var lane_h := 0.8
	var lane_mesh := BoxMesh.new()
	lane_mesh.size = Vector3(0.25, lane_h, inner_d)
	lane_mesh.material = plastic
	for col in range(1, COLUMNS):
		var x := (col - (COLUMNS - 1) / 2.0 - 0.5) * SPACING.x
		_add_mesh(lane_mesh, Vector3(x, lane_h / 2.0, 0))

func _add_mesh(mesh: Mesh, pos: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	add_child(instance)

func _build_slots() -> void:
	for i in COLUMNS * ROWS:
		var col := i % COLUMNS
		var row := i / COLUMNS
		var x := (col - (COLUMNS - 1) / 2.0) * SPACING.x
		var z := (row - (ROWS - 1) / 2.0) * SPACING.y

		var instance: Node3D = die_scene.instantiate()
		add_child(instance)
		instance.position = Vector3(x, REST_Y, z)
		instance.scale = Vector3.ONE * DIE_SCALE
		instance.visible = false

		var body: RigidBody3D = instance.get_node("RigidBody3D")
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0

		var mesh: MeshInstance3D = body.get_node("Die")
		slot_roots.append(instance)
		slot_meshes.append(mesh)

## --- Pool-Modus: alle Slots vorbelegt, werden einzeln ausgeblendet ---

## Setzt das komplette Layout für eine neue Runde: alle 30 Slots sichtbar,
## eingefärbt nach Würfelart.
func set_layout(kinds: Array[String]) -> void:
	for i in slot_roots.size():
		slot_roots[i].visible = true
		var kind: String = kinds[i] if i < kinds.size() else "normal"
		slot_meshes[i].set_surface_override_material(0, kind_tint_materials.get(kind))
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
func add_die(kind: String) -> void:
	if next_free_index >= slot_roots.size():
		return
	var i := next_free_index
	next_free_index += 1
	slot_roots[i].visible = true
	slot_meshes[i].set_surface_override_material(0, kind_tint_materials.get(kind))
	slot_meshes[i].set_surface_override_material(1, null)
