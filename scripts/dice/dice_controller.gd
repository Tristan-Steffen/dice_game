class_name DiceController
extends RefCounted
## Physik und Zustand der 6 Würfel-Slots: Werfen, Halten, Ruheerkennung, Spezialwürfel-Tints.
## Welcher Wert gezeigt wird, kommt aus der DieDefinition jedes Slots
## (slot_defs) - die Physik liefert nur, welche der 6 physischen Seiten
## gerade oben liegt. Die 6 Würfel selbst werden von DieBuilder rein per Code
## gebaut, es gibt keine .tscn-Datei mehr dafür.

# Lokale Achsen des Würfelmodells (feste Richtungen in RigidBody3D-Lokalraum).
const AXIS_DIRECTIONS := {
	"OBEN": Vector3.UP,
	"UNTEN": Vector3.DOWN,
	"RECHTS": Vector3.RIGHT,
	"LINKS": Vector3.LEFT,
	"VORNE": Vector3(0, 0, 1),
	"HINTEN": Vector3(0, 0, -1),
}

# "Oben"-Richtung der Ziffer je Seite (lokaler Würfelraum), damit die Zahl auf
# jeder Seite aufrecht steht, wenn man sie frontal ansieht (siehe DieBuilder.
# _face_basis / DieFaceDisplay). Ohne feste Vorgabe stünde die Ziffer je Seite
# unterschiedlich verdreht. Für die 4 Seitenflächen zeigt "oben" nach +Y, für
# Ober-/Unterseite entlang der Z-Achse (die Y-Achse ist dort die Normale).
const FACE_TEXT_UP := {
	"OBEN": Vector3(0, 0, -1),
	"UNTEN": Vector3(0, 0, 1),
	"RECHTS": Vector3(0, 1, 0),
	"LINKS": Vector3(0, 1, 0),
	"VORNE": Vector3(0, 1, 0),
	"HINTEN": Vector3(0, 1, 0),
}

# Kalibrierung: welcher Index in DieDefinition.faces liegt physisch auf
# welcher Achse.
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

## Markiert Würfel, die der Spieler vor dem nächsten "Neu würfeln" schützen
## will (siehe set_selected/selected) - "Nehmen" nimmt ohnehin immer alle 6.
const SELECT_TINT := Color(1.0, 0.82, 0.2)

## Ein Würfel gilt nur dann als "ruhig genug", wenn er zusätzlich fast flach
## auf einer Seite liegt (Dot der am besten ausgerichteten Achse mit UP) -
## sonst kann er scheinbar zur Ruhe kommen, während er tatsächlich instabil
## auf einer Kante oder Ecke balanciert (die scharfkantige BoxShape3D erlaubt
## das, echte Würfel mit leicht gerundeten Kanten würden nie so liegen
## bleiben). 1.0 = exakt flach, cos(~23°) ≈ 0.92 lässt kleine Nick-/Roll-Reste
## noch durchgehen.
const SETTLE_ALIGNMENT_MIN_DOT := 0.92

## Kleiner Anstoß, der ein solches Kanten-/Eckengleichgewicht bricht - danach
## übernimmt wieder ganz normal die Physik (Schwerkraft kippt den Würfel auf
## eine Seite), siehe physics_step.
const NUDGE_TORQUE := 0.5

var roots: Array[Node3D]
var bodies: Array[RigidBody3D]
var face_displays: Array[DieFaceDisplay] = []

var start_transforms: Array[Transform3D] = []
var selected: Array[bool] = []  # true = vor dem nächsten Neu-Würfeln geschützt (siehe set_selected)
var values: Array[int] = []
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
		settled.append(true)
		rest_timers.append(0.0)
		slot_defs.append(DieDefinition.standard())
		roots[i].visible = false

func count() -> int:
	return bodies.size()

## Wirft genau die Würfel bei indices (siehe scene_root.gd: entweder alle 6
## beim ersten Wurf einer Hand, oder beim Neu-Würfeln nur die nicht
## geschützten Slots). Alle anderen (geschützten) Slots bleiben unangetastet
## liegen, mit ihrem alten Wert.
func throw_slots(indices: Array[int], throw_force: float, spin_strength: float) -> void:
	for i in indices:
		roots[i].visible = true
		settled[i] = false
		rest_timers[i] = 0.0
		bodies[i].freeze = false  # falls der Slot zuletzt als ausgewählt an den oberen Grubenrand geglitten war (siehe scene_root.gd: _play_cup_roll)

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
		var is_slow := body.linear_velocity.length() < linear_threshold and body.angular_velocity.length() < angular_threshold
		if is_slow and _top_axis_info(body)[1] >= SETTLE_ALIGNMENT_MIN_DOT:
			rest_timers[i] += delta
			if rest_timers[i] >= rest_time_required:
				settled[i] = true
				values[i] = _value_for_slot(i)
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

## Spieler klickt einen noch nicht genommenen Würfel an, um ihn fürs nächste
## "Nehmen" zu markieren (siehe SELECT_TINT).
func set_selected(index: int, is_selected: bool) -> void:
	selected[index] = is_selected
	face_displays[index].set_tint(SELECT_TINT if is_selected else _style_tint(slot_defs[index]))

func index_of_body(collider: Object) -> int:
	return bodies.find(collider)

func reset() -> void:
	for i in count():
		selected[i] = false
		values[i] = 0
		settled[i] = true
		rest_timers[i] = 0.0
		roots[i].visible = false
		face_displays[i].set_tint(_style_tint(slot_defs[i]))

## Leert die Schutz-Auswahl (nach jedem Wurf, siehe scene_root.gd:
## _on_roll_finished) - der Spieler markiert für jede neue Lage der Grube
## wieder gezielt, welche Würfel er vor dem nächsten Neu-Würfeln schützen will.
func clear_selection() -> void:
	for i in count():
		selected[i] = false
		face_displays[i].set_tint(_style_tint(slot_defs[i]))

## Markiert alle Würfel als geschützt vor dem nächsten Neu-Würfeln (siehe
## scene_root.gd: SelectAllButton).
func select_all() -> void:
	for i in count():
		selected[i] = true
		face_displays[i].set_tint(SELECT_TINT)

func set_slot_defs(defs: Array[DieDefinition]) -> void:
	slot_defs = defs.duplicate()
	for i in count():
		face_displays[i].apply_definition(slot_defs[i])
		face_displays[i].set_tint(_style_tint(slot_defs[i]))

func _style_tint(def: DieDefinition) -> Color:
	return KIND_TINTS.get(def.style_id, Color.WHITE)

func _value_for_slot(index: int) -> int:
	var face_index: int = AXIS_FACE_INDEX[_top_axis_info(bodies[index])[0]]
	return slot_defs[index].faces[face_index]

## Gibt [Achsenname, Ausrichtungs-Dot] zurück: der Dot ist 1.0, wenn diese
## Achse exakt nach oben zeigt (Würfel liegt flach auf der gegenüberliegenden
## Seite), und deutlich niedriger (siehe SETTLE_ALIGNMENT_MIN_DOT), wenn der
## Würfel stattdessen auf einer Kante oder Ecke balanciert.
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
