class_name DiceController
extends RefCounted
## Physik und Zustand der 6 Würfel-Slots: Werfen, Halten, Ruheerkennung.
## Welcher Wert gezeigt wird, kommt aus der DieDefinition des Slots - die
## Physik liefert nur, welche physische Seite oben liegt.

## Was sichtbar in der Grube liegt, hat gewechselt (Wurf, Ablegen, Zurücksetzen).
## Die Werkbank hängt daran: ein Würfel wird nie zweimal gezeigt.
signal pit_contents_changed

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

## Zufälliger Drall beim Abrutschen vom Stapel - der Würfel soll nicht flach
## weiterschlittern.
const SLIDE_TORQUE := 0.5

## So lange darf ein geworfener Würfel ohne Ruhelage bleiben, dann wird genau
## dieser Slot neu geworfen. Ein Anstoß löste eine Klemmlage nicht zuverlässig.
const STUCK_RETHROW_SECONDS := 6.0

## Ein flach auf einem anderen Würfel liegender Würfel ist langsam UND flach,
## kommt also durch die Ruheprüfung - erkannt wird er nur an der Höhe.
const STACK_HEIGHT := DIE_HALF * 1.6

## Kanten-Drehmoment hilft auf einem flachen Deckel nicht - es braucht einen
## seitlichen Schubs weg vom tragenden Würfel, plus etwas Höhe zum Loslösen.
const SLIDE_IMPULSE := 3.0
const SLIDE_LIFT := 1.0

func _is_stacked(body: RigidBody3D) -> bool:
	return body.global_position.y > STACK_HEIGHT

## Richtung weg vom nächsten tiefer liegenden Würfel (XZ); bei exakt
## deckungsgleichen Mitten eine zufällige, sonst bliebe der Würfel liegen.
func _slide_direction(body: RigidBody3D) -> Vector2:
	var here := body.global_position
	var away := Vector2.ZERO
	var nearest := INF
	for other in bodies:
		if other == body or other.global_position.y >= here.y:
			continue
		var delta := Vector2(here.x - other.global_position.x, here.z - other.global_position.z)
		if delta.length() < nearest:
			nearest = delta.length()
			away = delta
	if away.length() < 0.01:
		return Vector2.RIGHT.rotated(randf() * TAU)
	return away.normalized()

## Schiebt den aufliegenden Würfel vom tragenden Würfel weg.
func _slide_off_stack(body: RigidBody3D) -> void:
	var away := _slide_direction(body)
	body.apply_central_impulse(Vector3(away.x * SLIDE_IMPULSE, SLIDE_LIFT, away.y * SLIDE_IMPULSE))
	body.apply_torque_impulse(Vector3(
		randf_range(-SLIDE_TORQUE, SLIDE_TORQUE),
		randf_range(-SLIDE_TORQUE, SLIDE_TORQUE),
		randf_range(-SLIDE_TORQUE, SLIDE_TORQUE)
	))

var roots: Array[Node3D]
var bodies: Array[RigidBody3D]
var face_displays: Array[DieFaceDisplay] = []
var start_transforms: Array[Transform3D] = []
var selected: Array[bool] = []  # true = vor dem nächsten Neu-Würfeln geschützt
var values: Array[int] = []
var face_indices: Array[int] = []  # oben liegende physische Seite (0..5), -1 = ungewürfelt
var settled: Array[bool] = []
var rest_timers: Array[float] = []
var stuck_timers: Array[float] = []
var slot_defs: Array[DieDefinition] = []

## Wurfparameter des letzten Wurfs - ein steckender Slot wird damit exakt so
## neu geworfen, wie er ursprünglich abgeworfen wurde.
var _throw_force: float = 0.0
var _spin_strength: float = 0.0
var _throw_target: Vector3 = Vector3.ZERO

## Anzeige-Überschreibung der OBEREN Seite je Slot (Slot -> Wert): der Würfel
## zeigt einen anderen Wert als seine Def. Zwei Quellen, ein Mechanismus -
## Verwandlungs-Charms (grün, vorläufig) und der Wertwandel zwischen den
## Aktivierungen beim Zählen (normal, weil er dauerhaft wird). Rein Anzeige:
## values bleibt, was die Wertung dieses Wurfs gelesen hat.
var value_overrides: Dictionary = {}
var _overrides_tinted: bool = true

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
		stuck_timers.append(0.0)
		slot_defs.append(DieDefinition.standard())
		roots[i].visible = false

func count() -> int:
	return bodies.size()

## Wirft genau die Slots bei indices Richtung target (Grubenmitte); alle
## anderen (geschützten) bleiben mit ihrem alten Wert liegen.
func throw_slots(indices: Array[int], throw_force: float, spin_strength: float, target: Vector3 = Vector3.ZERO) -> void:
	_throw_force = throw_force
	_spin_strength = spin_strength
	_throw_target = target
	var targets := _spread_targets(indices.size())
	for ordinal in indices.size():
		var i: int = indices[ordinal]
		roots[i].visible = true
		settled[i] = false
		rest_timers[i] = 0.0
		stuck_timers[i] = 0.0
		value_overrides.erase(i)  # die Vorschau des alten Werts fliegt mit
		bodies[i].freeze = false  # falls der Slot zuletzt an den Grubenrand geglitten war

		var body := bodies[i]
		var start_transform := start_transforms[i]
		body.global_transform = start_transform
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false

		# Wurf ballistisch über die FLUGZEIT gelöst: Ziel (Grubenmitte + Streuung je
		# Würfel) und Bogen sind fix, die Geschwindigkeit folgt daraus - so landen
		# die Würfel unabhängig von der Becherposition sanft genug, dass die
		# Grubenwände sie halten (voller throw_force schoss über die Wände hinaus).
		var g_eff := 9.8 * body.gravity_scale
		body.linear_velocity = _throw_velocity(
			start_transform.origin, target + targets[ordinal], g_eff, throw_force,
			THROW_FLIGHT_TIME + float(ordinal) * THROW_STAGGER)
		body.apply_torque_impulse(Vector3(
			randf_range(-spin_strength, spin_strength),
			randf_range(-spin_strength, spin_strength),
			randf_range(-spin_strength, spin_strength)
		))
	pit_contents_changed.emit()

## Flugzeit des Wurfbogens; je Würfel wächst sie um THROW_STAGGER, damit die
## Würfel NACHEINANDER einschlagen - gleichzeitig ankommende Würfel schoben sich
## nicht auseinander, sondern übereinander.
const THROW_FLIGHT_TIME := 0.6
const THROW_STAGGER := 0.05

## Wurfziele je Würfel auf der langen Grubenachse (Welt-Z, Grube ±14.28).
const SPREAD_HALF_Z := 10.5
const SPREAD_JITTER_X := 2.5
## Echte halbe Kantenlänge: scene_root skaliert die Kollisionsform mit
## DIE_SCALE, DieBuilder.HALF_EXTENT allein ist also zu groß.
const DIE_HALF := DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT
## Halbe Raumdiagonale - so weit müssen Bahnmitten mindestens auseinander
## liegen, damit sich zwei Ziele in keiner Lage überlappen können.
const DIE_HALF_DIAGONAL := DIE_HALF * 1.733

## Eine eigene Bahn je Würfel statt unabhängiger Zufallsstreuung: sechs freie
## Ziehungen in einem kleinen Fenster trafen sich zwangsläufig. Die Bahnen sind
## gemischt, der Rest-Jitter bleibt so klein, dass Bahnen sich nie berühren.
static func _spread_targets(count: int) -> Array[Vector3]:
	var lane := (SPREAD_HALF_Z * 2.0) / float(maxi(count, 1))
	var jitter_z := maxf(lane * 0.5 - DIE_HALF_DIAGONAL, 0.0)
	var lanes: Array[int] = []
	for i in count:
		lanes.append(i)
	lanes.shuffle()
	var targets: Array[Vector3] = []
	for i in count:
		var center_z := -SPREAD_HALF_Z + lane * (float(lanes[i]) + 0.5)
		targets.append(Vector3(
			randf_range(-SPREAD_JITTER_X, SPREAD_JITTER_X), 0.0,
			center_z + randf_range(-jitter_z, jitter_z)))
	return targets

## Startgeschwindigkeit, die from nach genau flight_time auf to einschlagen
## lässt (Schwerkraft g); max_speed kappt Extremfälle (sehr weite Würfe landen
## dann etwas kurz statt als Geschoss).
static func _throw_velocity(from: Vector3, to: Vector3, g: float, max_speed: float,
		flight_time: float = THROW_FLIGHT_TIME) -> Vector3:
	var t := flight_time
	var velocity := Vector3(to.x - from.x, 0.0, to.z - from.z) / t
	velocity.y = (to.y - from.y + 0.5 * g * t * t) / t
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	return velocity

## Ein Physik-Tick; true, sobald alle Würfel zur Ruhe gekommen sind.
func physics_step(delta: float, linear_threshold: float, angular_threshold: float, rest_time_required: float) -> bool:
	var all_settled := true
	for i in count():
		if settled[i]:
			continue
		var body := bodies[i]
		stuck_timers[i] += delta
		if stuck_timers[i] >= STUCK_RETHROW_SECONDS:
			_rethrow_slot(i)
			all_settled = false
			continue
		var is_slow := body.linear_velocity.length() < linear_threshold and body.angular_velocity.length() < angular_threshold
		if is_slow and _top_axis_info(body)[1] >= SETTLE_ALIGNMENT_MIN_DOT:
			if _is_stacked(body):
				rest_timers[i] = 0.0
				_slide_off_stack(body)
				all_settled = false
				continue
			rest_timers[i] += delta
			if rest_timers[i] >= rest_time_required:
				settled[i] = true
				face_indices[i] = AXIS_FACE_INDEX[_top_axis_info(body)[0]]
				values[i] = slot_defs[i].faces[face_indices[i]]
		else:
			rest_timers[i] = 0.0
		if not settled[i]:
			all_settled = false
	return all_settled

## Steckender Slot: derselbe Wurf noch einmal, Steck-Timer wieder auf 0 - bleibt
## er erneut liegen, wirft er nach weiteren STUCK_RETHROW_SECONDS wieder.
func _rethrow_slot(i: int) -> void:
	var single: Array[int] = [i]
	throw_slots(single, _throw_force, _spin_strength, _throw_target)

## Markiert einen Würfel als geschützt - sichtbar über das Leucht-Podest auf
## dem Display, nicht am Würfelkörper.
func set_selected(index: int, is_selected: bool) -> void:
	selected[index] = is_selected

func index_of_body(collider: Object) -> int:
	return bodies.find(collider)

## Physische Seite (0..5) in Richtung local_dir (Würfel-Lokalraum) - die dem
## Vektor am nächsten liegende Achse. Genutzt fürs Seiten-Hover in der Grube.
static func face_index_for_local_dir(local_dir: Vector3) -> int:
	var best_axis := ""
	var best_dot := -INF
	for axis in AXIS_DIRECTIONS:
		var d: float = local_dir.dot(AXIS_DIRECTIONS[axis])
		if d > best_dot:
			best_dot = d
			best_axis = axis
	return AXIS_FACE_INDEX.get(best_axis, -1)

func reset() -> void:
	value_overrides.clear()
	for i in count():
		selected[i] = false
		values[i] = 0
		face_indices[i] = -1
		settled[i] = true
		rest_timers[i] = 0.0
		stuck_timers[i] = 0.0
		roots[i].visible = false
		face_displays[i].set_tint(_style_tint(slot_defs[i]))
	pit_contents_changed.emit()

## Leert die Schutz-Auswahl (nach jedem Wurf).
func clear_selection() -> void:
	for i in count():
		selected[i] = false
		face_displays[i].set_tint(_style_tint(slot_defs[i]))

## Weniger Defs als Slots (der Rest-Pool wird als kleinere Hand ausgespielt): die
## übrigen Slots liegen unsichtbar daneben, brauchen aber einen Würfel - jede
## Slot-Abfrage läuft über count().
func set_slot_defs(defs: Array[DieDefinition]) -> void:
	slot_defs = defs.duplicate()
	while slot_defs.size() < count():
		slot_defs.append(DieDefinition.standard())
	refresh_faces()
	pit_contents_changed.emit()

## Wer von außen an roots[i].visible schreibt, meldet es hier - die Grube hat
## sonst keinen zweiten Weg, ihren Bestand bekanntzugeben.
func note_pit_changed() -> void:
	pit_contents_changed.emit()

## Welche Würfel-EXEMPLARE gerade sichtbar in der Grube liegen. Ein Würfel wird
## nie zweimal gezeigt: wer hier steht, hat auf der Werkbank nichts zu suchen.
func visible_slot_defs() -> Array[DieDefinition]:
	var defs: Array[DieDefinition] = []
	for i in count():
		if roots[i].visible and slot_defs[i] != null:
			defs.append(slot_defs[i])
	return defs

## Zeichnet die Augenzahlen aller Slots neu aus slot_defs - nötig, sobald ein
## liegender Würfel sich ändert (Knochen/Glas beim Nehmen, Materialien). Rein
## Anzeige: values bleibt, was die Wertung dieses Wurfs gelesen hat.
func refresh_faces() -> void:
	for i in count():
		face_displays[i].apply_definition(slot_defs[i])
		face_displays[i].set_tint(_style_tint(slot_defs[i]))
		_apply_value_override(i)

## Setzt die Anzeige-Überschreibungen (Slot -> Wert); leeres Dictionary löscht
## sie. tinted = der Wert gilt nur vorläufig und wird grün gezeigt.
func set_value_overrides(overrides: Dictionary, tinted: bool = true) -> void:
	if value_overrides == overrides and _overrides_tinted == tinted:
		return
	value_overrides = overrides.duplicate()
	_overrides_tinted = tinted
	refresh_faces()

func clear_value_overrides() -> void:
	set_value_overrides({})

## Schreibt die Überschreibung des Slots auf seine oben liegende Seite. Ohne
## gewürfelte Seite (face_indices == -1) gibt es keine "obere" Ziffer.
func _apply_value_override(i: int) -> void:
	if not value_overrides.has(i) or face_indices[i] < 0:
		return
	face_displays[i].set_face_value_at(face_indices[i], int(value_overrides[i]))
	if _overrides_tinted:
		face_displays[i].set_face_number_tint(face_indices[i], DieFaceDisplay.PREVIEW_NUMBER_COLOR)

func _style_tint(def: DieDefinition) -> Color:
	return KIND_TINTS.get(def.style_id, Color.WHITE)

## [Achsenname, Ausrichtungs-Dot]: Dot 1.0 = liegt exakt flach, deutlich
## niedriger = balanciert auf Kante/Ecke.
## Rückblick-Pose: kippt den Würfel in Slot i so, dass face oben liegt - eine ECHTE
## Neuausrichtung des Körpers, kein getauschter Zahlenwert. Der Würfel liegt
## danach still (kein neuer Wurf, also auch keine Farkle-Prüfung beim Aufrufer).
## false, wenn der Slot leer ist oder die Seite nicht zum Würfel gehört.
func tip_to_face(i: int, face: int) -> bool:
	if i < 0 or i >= bodies.size() or face < 0 or face > 5 or slot_defs[i] == null:
		return false
	var axis := ""
	for key in AXIS_FACE_INDEX:
		if AXIS_FACE_INDEX[key] == face:
			axis = key
			break
	if axis == "":
		return false
	var body := bodies[i]
	var basis := body.global_transform.basis
	var world_dir: Vector3 = (basis * AXIS_DIRECTIONS[axis]).normalized()
	# Die kürzeste Drehung, die diese Seite nach oben bringt.
	var turn := Quaternion(world_dir, Vector3.UP)
	body.global_transform = Transform3D(Basis(turn) * basis, body.global_transform.origin)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	face_indices[i] = face
	values[i] = slot_defs[i].faces[face]
	settled[i] = true
	return true

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
