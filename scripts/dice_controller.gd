class_name DiceController
extends RefCounted
## Physik und Zustand der 6 Würfel-Slots: Werfen, Halten, Ruheerkennung, Spezialwürfel-Tints.
## Welcher Wert gezeigt wird, kommt aus der DieDefinition jedes Slots
## (slot_defs) - die Physik liefert nur, welche der 6 physischen Seiten
## gerade oben liegt.

# Lokale Achsen des Würfelmodells (feste Richtungen in RigidBody3D-Lokalraum).
const AXIS_DIRECTIONS := {
	"OBEN": Vector3.UP,
	"UNTEN": Vector3.DOWN,
	"RECHTS": Vector3.RIGHT,
	"LINKS": Vector3.LEFT,
	"VORNE": Vector3(0, 0, 1),
	"HINTEN": Vector3(0, 0, -1),
}

# Kalibrierung: welcher Index in DieDefinition.faces liegt physisch auf
# welcher Achse (bisher fest verdrahtet auf die im Mesh eingebrannten Pips:
# OBEN zeigte immer die 4, also Index 3, usw.).
const AXIS_FACE_INDEX := {
	"OBEN": 3,
	"UNTEN": 2,
	"RECHTS": 4,
	"LINKS": 1,
	"VORNE": 0,
	"HINTEN": 5,
}

const KIND_TINTS := {
	"fixed_6": Color(0.55, 0.15, 0.75),
	"fixed_5": Color(0.15, 0.35, 0.85),
	"fixed_4": Color(0.15, 0.65, 0.3),
}

var roots: Array[Node3D]
var bodies: Array[RigidBody3D]
var meshes: Array[MeshInstance3D]

var start_transforms: Array[Transform3D] = []
var held: Array[bool] = []
var values: Array[int] = []
var settled: Array[bool] = []
var rest_timers: Array[float] = []
var slot_defs: Array[DieDefinition] = []

var hold_highlight_material: StandardMaterial3D
var kind_tint_materials: Dictionary = {}

func _init(p_roots: Array[Node3D], p_bodies: Array[RigidBody3D], p_meshes: Array[MeshInstance3D]) -> void:
	roots = p_roots
	bodies = p_bodies
	meshes = p_meshes

	# Deutlich gedämpft: dieses Material ersetzt Oberfläche 1 (die Augen/Pips
	# des Würfels) komplett, ein zu heller Farbton macht die Punktezahl
	# unleserlich, sobald ein Würfel gehalten wird.
	hold_highlight_material = StandardMaterial3D.new()
	hold_highlight_material.albedo_color = Color(0.45, 0.34, 0.05)
	hold_highlight_material.emission_enabled = true
	hold_highlight_material.emission = Color(0.4, 0.28, 0.04)
	hold_highlight_material.emission_energy_multiplier = 0.2

	for kind in KIND_TINTS:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = KIND_TINTS[kind]
		mat.emission_enabled = true
		mat.emission = KIND_TINTS[kind]
		mat.emission_energy_multiplier = 0.4
		kind_tint_materials[kind] = mat

	for i in bodies.size():
		start_transforms.append(bodies[i].global_transform)
		held.append(false)
		values.append(0)
		settled.append(true)
		rest_timers.append(0.0)
		slot_defs.append(DieDefinition.standard())
		roots[i].visible = false

func count() -> int:
	return bodies.size()

func throw_unheld(throw_force: float, spin_strength: float) -> void:
	for i in count():
		if held[i]:
			settled[i] = true
			continue

		roots[i].visible = true
		settled[i] = false
		rest_timers[i] = 0.0

		var body := bodies[i]
		var start_transform := start_transforms[i]
		body.global_transform = start_transform
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false

		var throw_direction := (Vector3.ZERO - start_transform.origin).normalized()
		body.apply_central_impulse(throw_direction * throw_force + Vector3.DOWN * 2.0)
		body.apply_torque_impulse(Vector3(
			randf_range(-spin_strength, spin_strength),
			randf_range(-spin_strength, spin_strength),
			randf_range(-spin_strength, spin_strength)
		))

## Ein Physik-Tick; liefert true, sobald alle Würfel zur Ruhe gekommen sind.
func physics_step(delta: float, linear_threshold: float, angular_threshold: float, rest_time_required: float) -> bool:
	var all_settled := true
	for i in count():
		if settled[i]:
			continue
		var body := bodies[i]
		if body.linear_velocity.length() < linear_threshold and body.angular_velocity.length() < angular_threshold:
			rest_timers[i] += delta
			if rest_timers[i] >= rest_time_required:
				settled[i] = true
				values[i] = _value_for_slot(i)
		else:
			rest_timers[i] = 0.0
		if not settled[i]:
			all_settled = false
	return all_settled

func set_held(index: int, is_held: bool) -> void:
	held[index] = is_held
	meshes[index].set_surface_override_material(1, hold_highlight_material if is_held else null)

func index_of_body(collider: Object) -> int:
	return bodies.find(collider)

func reset() -> void:
	for i in count():
		held[i] = false
		values[i] = 0
		settled[i] = true
		rest_timers[i] = 0.0
		roots[i].visible = false
		meshes[i].set_surface_override_material(1, null)

func set_slot_defs(defs: Array[DieDefinition]) -> void:
	slot_defs = defs.duplicate()
	for i in count():
		meshes[i].set_surface_override_material(0, kind_tint_materials.get(slot_defs[i].style_id))

func _value_for_slot(index: int) -> int:
	var face_index: int = AXIS_FACE_INDEX[_get_top_axis(bodies[index])]
	return slot_defs[index].faces[face_index]

func _get_top_axis(body: RigidBody3D) -> String:
	var basis := body.global_transform.basis
	var best_axis := "OBEN"
	var best_dot := -INF
	for axis in AXIS_DIRECTIONS.keys():
		var world_dir: Vector3 = basis * AXIS_DIRECTIONS[axis]
		var d := world_dir.dot(Vector3.UP)
		if d > best_dot:
			best_dot = d
			best_axis = axis
	return best_axis
