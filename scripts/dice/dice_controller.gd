class_name DiceController
extends RefCounted
## Physik und Zustand der 6 Würfel-Slots: Werfen, Halten, Ruheerkennung.
## Welcher Wert gezeigt wird, kommt aus der DieDefinition des Slots - die
## Physik liefert nur, welche physische Seite oben liegt.

# Lokale Achsen des Würfelmodells (RigidBody3D-Lokalraum).
const AXIS_DIRECTIONS := {
	"OBEN": Vector3.UP,
	"UNTEN": Vector3.DOWN,
	"RECHTS": Vector3.RIGHT,
	"LINKS": Vector3.LEFT,
	"VORNE": Vector3(0, 0, 1),
	"HINTEN": Vector3(0, 0, -1),
}

# "Oben"-Richtung der Ziffer je Seite (lokal), damit die Zahl frontal
# aufrecht steht; für Ober-/Unterseite entlang Z (Y ist dort die Normale).
const FACE_TEXT_UP := {
	"OBEN": Vector3(0, 0, -1),
	"UNTEN": Vector3(0, 0, 1),
	"RECHTS": Vector3(0, 1, 0),
	"LINKS": Vector3(0, 1, 0),
	"VORNE": Vector3(0, 1, 0),
	"HINTEN": Vector3(0, 1, 0),
}

# Kalibrierung: welcher Index in DieDefinition.faces liegt auf welcher Achse.
const AXIS_FACE_INDEX := {
	"OBEN": 3,
	"UNTEN": 2,
	"RECHTS": 4,
	"LINKS": 1,
	"VORNE": 0,
	"HINTEN": 5,
}

## Körperfarbe je style_id - bewusst leer: Shop-Würfel sehen normal aus,
## besonders machen sie Seitenwerte und Materialien.
const KIND_TINTS := {}

## Ruhig gilt ein Würfel nur, wenn er zusätzlich fast flach liegt (Dot der
## bestausgerichteten Achse mit UP) - sonst balanciert die scharfkantige
## BoxShape3D scheinbar stabil auf Kante/Ecke. cos(~23°) ≈ 0.92.
const SETTLE_ALIGNMENT_MIN_DOT := 0.92

## Kleiner Anstoß, der ein Kanten-/Eckengleichgewicht bricht.
const NUDGE_TORQUE := 0.5

var roots: Array[Node3D]
var bodies: Array[RigidBody3D]
var face_displays: Array[DieFaceDisplay] = []
## Slot des zuletzt zur Ruhe gekommenen Würfels (-1 = keiner) - Nachzügler-Charm.
var last_settled_index: int = -1

var start_transforms: Array[Transform3D] = []
var selected: Array[bool] = []  # true = vor dem nächsten Neu-Würfeln geschützt
var values: Array[int] = []
var face_indices: Array[int] = []  # oben liegende physische Seite (0..5), -1 = ungewürfelt
var settled: Array[bool] = []
var rest_timers: Array[float] = []
var slot_defs: Array[DieDefinition] = []

func _init(p_roots: Array[Node3D], p_bodies: Array[RigidBody3D], p_face_displays: Array[DieFaceDisplay]) -> void:
	roots = p_roots
	bodies = p_bodies
	face_displays = p_face_displays

	for i in bodies.size():
		start_transforms.append(bodies[i].global_transform)
		selected.append(false)
		values.append(0)
		face_indices.append(-1)
		settled.append(true)
		rest_timers.append(0.0)
		slot_defs.append(DieDefinition.standard())
		roots[i].visible = false

func count() -> int:
	return bodies.size()

## Wirft genau die Slots bei indices Richtung target (Grubenmitte); alle
## anderen (geschützten) bleiben mit ihrem alten Wert liegen.
func throw_slots(indices: Array[int], throw_force: float, spin_strength: float, target: Vector3 = Vector3.ZERO) -> void:
	for i in indices:
		roots[i].visible = true
		settled[i] = false
		rest_timers[i] = 0.0
		bodies[i].freeze = false  # falls der Slot zuletzt an den Grubenrand geglitten war

		var body := bodies[i]
		var start_transform := start_transforms[i]
		body.global_transform = start_transform
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false

		var throw_direction := (target - start_transform.origin).normalized()
		body.apply_central_impulse(throw_direction * throw_force + Vector3.DOWN * 2.0)
		body.apply_torque_impulse(Vector3(
			randf_range(-spin_strength, spin_strength),
			randf_range(-spin_strength, spin_strength),
			randf_range(-spin_strength, spin_strength)
		))

## Ein Physik-Tick; true, sobald alle Würfel zur Ruhe gekommen sind.
func physics_step(delta: float, linear_threshold: float, angular_threshold: float, rest_time_required: float) -> bool:
	var all_settled := true
	for i in count():
		if settled[i]:
			continue
		var body := bodies[i]
		var is_slow := body.linear_velocity.length() < linear_threshold and body.angular_velocity.length() < angular_threshold
		if is_slow and _top_axis_info(body)[1] >= SETTLE_ALIGNMENT_MIN_DOT:
			rest_timers[i] += delta
			if rest_timers[i] >= rest_time_required:
				settled[i] = true
				face_indices[i] = AXIS_FACE_INDEX[_top_axis_info(body)[0]]
				values[i] = slot_defs[i].faces[face_indices[i]]
				last_settled_index = i
		else:
			rest_timers[i] = 0.0
			if is_slow:
				body.apply_torque_impulse(Vector3(
					randf_range(-NUDGE_TORQUE, NUDGE_TORQUE),
					randf_range(-NUDGE_TORQUE, NUDGE_TORQUE),
					randf_range(-NUDGE_TORQUE, NUDGE_TORQUE)
				))
		if not settled[i]:
			all_settled = false
	return all_settled

## Markiert einen Würfel als geschützt - sichtbar über das Leucht-Podest auf
## dem Display, nicht am Würfelkörper.
func set_selected(index: int, is_selected: bool) -> void:
	selected[index] = is_selected

func index_of_body(collider: Object) -> int:
	return bodies.find(collider)

func reset() -> void:
	last_settled_index = -1
	for i in count():
		selected[i] = false
		values[i] = 0
		face_indices[i] = -1
		settled[i] = true
		rest_timers[i] = 0.0
		roots[i].visible = false
		face_displays[i].set_tint(_style_tint(slot_defs[i]))

## Leert die Schutz-Auswahl (nach jedem Wurf).
func clear_selection() -> void:
	for i in count():
		selected[i] = false
		face_displays[i].set_tint(_style_tint(slot_defs[i]))

func set_slot_defs(defs: Array[DieDefinition]) -> void:
	slot_defs = defs.duplicate()
	for i in count():
		face_displays[i].apply_definition(slot_defs[i])
		face_displays[i].set_tint(_style_tint(slot_defs[i]))

func _style_tint(def: DieDefinition) -> Color:
	return KIND_TINTS.get(def.style_id, Color.WHITE)

## [Achsenname, Ausrichtungs-Dot]: Dot 1.0 = liegt exakt flach, deutlich
## niedriger = balanciert auf Kante/Ecke.
func _top_axis_info(body: RigidBody3D) -> Array:
	var basis := body.global_transform.basis
	var best_axis := "OBEN"
	var best_dot := -INF
	for axis in AXIS_DIRECTIONS.keys():
		var world_dir: Vector3 = basis * AXIS_DIRECTIONS[axis]
		var d := world_dir.dot(Vector3.UP)
		if d > best_dot:
			best_dot = d
			best_axis = axis
	return [best_axis, best_dot]
