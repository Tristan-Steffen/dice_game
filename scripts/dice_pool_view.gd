class_name DicePoolView
extends Node3D
## Zeigt den kompletten 30er Würfel-Pool sichtbar in einem Raster neben dem
## Spielbrett. Rein visuell (keine Physik/Kollision) - markiert per Tint,
## welche Würfel als Nächstes gezogen werden ("queued"), und blendet
## gezogene Würfel aus, sobald sie tatsächlich verwendet wurden.

const COLUMNS := 5
const ROWS := 6
const SPACING := Vector2(1.8, 1.8)
const DIE_SCALE := 0.5
const REST_Y := -3.15

var die_scene: PackedScene = preload("res://scenes/die.tscn")

var slot_roots: Array[Node3D] = []
var slot_meshes: Array[MeshInstance3D] = []
var kind_tint_materials: Dictionary = {}
var queued_material: StandardMaterial3D

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

	_build_slots()

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

		var body: RigidBody3D = instance.get_node("RigidBody3D")
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0

		var mesh: MeshInstance3D = body.get_node("Die")
		slot_roots.append(instance)
		slot_meshes.append(mesh)

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
