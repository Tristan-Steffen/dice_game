class_name DiceTrayView
extends Node3D
## Zeigt Würfel als Stasis-Vitrine: jeder Slot ist ein Emitter-Puck (Leuchtscheibe
## auf dem Filz), über dem der Würfel schwebt (sanftes Wippen + leichtes Gieren).
## Alle Würfel schweben GLEICH hoch (Höhe der vorletzten Reihe). Slot-Reihenfolge
## liest wie ein Buch: 0 = oben links, dann zeilenweise. Drei Rollen: Pool- und
## Warteschlangen-Tray (setzen bei jeder Änderung ihren Inhalt komplett neu, siehe
## fill) sowie Ablage-Tray (startet leer, füllt sich an - siehe clear/add_die; das
## Einrasten löst den Puck-Ripple aus).

@export var rows: int = 5
@export var columns: int = 6
const SPACING := Vector2(1.8, 1.8)
const DIE_SCALE := 0.6  # gemeinsame Würfelgröße (Tray + Grube)
## Einheitliche Schwebehöhe der Würfel-MITTE über der Tischfläche für ALLE Trays
## (auch die einreihige Warteschlange) - hoch genug, dass der Emitter darunter
## sichtbar bleibt und nicht vom Würfel verdeckt wird.
const FLOAT_HEIGHT := 2.22

## Schweb-Animation: Wippen (vertikal) + leichtes Gieren (Drehung), je Slot
## phasenversetzt, damit die Vitrine lebt ohne die Augenzahl unlesbar zu drehen.
const BOB_AMPLITUDE := 0.06
const BOB_SPEED := 1.1
const SWAY_DEGREES := 5.0
const SWAY_SPEED := 0.6

@export var tray_color: Color = Color(0.15, 0.35, 0.75):
	set(value):
		tray_color = value
		for emitter in slot_emitters:
			emitter.set_tint(tray_color)

@onready var tray_mesh_root: Node3D = $TrayMesh
@onready var slots_container: Node3D = $Slots

## Unsichtbarer Klickbereich (Layer 4) für den Kamera-Zoom auf dieses Tray.
@onready var click_zone: StaticBody3D = $ClickZone

## Kollisions-Layer der Slot-Bodies - macht einzelne Tray-Würfel anklickbar.
const SLOT_PICK_LAYER := 16

var slot_roots: Array[Node3D] = []
var slot_bodies: Array[RigidBody3D] = []
var slot_face_displays: Array[DieFaceDisplay] = []
var slot_defs: Array[DieDefinition] = []

## Stasis-Station je Slot - dauerhaft sichtbar, auch unter einem leeren Platz.
## Jede bringt ihre EIGENEN Materialien mit: Höhe und engaged sind je Slot anders.
var slot_emitters: Array[StasisEmitter] = []
## Ruhe-Höhe (inkl. Terrasse) und Phasen-Offset je Slot für die Schweb-Animation.
var slot_base_y: Array[float] = []
var slot_phase: Array[float] = []
## Gekippte Lage je Slot: welche SEITE nach oben zeigt. Nur das Ablage-Tray
## setzt sie (der Würfel liegt dort so, wie er abgelegt wurde); Pool und
## Warteschlange bleiben auf der Ruhelage.
var slot_pose: Array[Quaternion] = []

var next_free_index: int = 0  # nächster freier Slot im Ablage-Modus

func _ready() -> void:
	tray_mesh_root.visible = false  # die Stasis-Vitrine ersetzt das Plastik-Tray
	_build_slots()

## Schweben lassen: sichtbare Würfel wippen und gieren sanft um ihre Ruhelage.
## Emitter/Säule pulsen GEGENPHASIG mit: sinkt der Würfel, arbeitet das Feld
## sichtbar härter (heller) - der Last-Rückkopplung macht Emitter und Würfel zu
## EINER Maschine statt zwei getrennter Animationen.
func _process(_delta: float) -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	for i in slot_roots.size():
		if not slot_roots[i].visible:
			continue
		var phase: float = slot_phase[i]
		var bob := sin(t * BOB_SPEED + phase)
		slot_roots[i].position.y = slot_base_y[i] + bob * BOB_AMPLITUDE
		# Gieren um die Hochachse ÜBER der gekippten Lage - quaternion statt
		# rotation.y, weil die Lage sonst jeden Frame verloren ginge (der Setter
		# nimmt die Skalierung mit).
		var yaw := -PI / 2.0 + deg_to_rad(SWAY_DEGREES) * sin(t * SWAY_SPEED + phase)
		slot_roots[i].quaternion = Quaternion(Vector3.UP, yaw) * slot_pose[i]
		slot_emitters[i].set_load(StasisEmitter.load_for(bob))

## Einheitliche Schwebehöhe für ALLE Slots und Trays (siehe FLOAT_HEIGHT).
func _slot_rest_y(_line: int) -> float:
	return FLOAT_HEIGHT

## Baut die dekorativen Würfel-Slots (eingefroren, ohne Physik-Overhead) samt
## ihren Emitter-Pucks.
func _build_slots() -> void:
	slot_roots.clear()
	slot_bodies.clear()
	slot_face_displays.clear()
	slot_defs.clear()
	slot_emitters.clear()
	slot_base_y.clear()
	slot_phase.clear()
	for i in rows * columns:
		var line := i / columns
		var pos_in_line := i % columns
		var x := ((rows - 1) / 2.0 - line) * SPACING.x
		var z := (pos_in_line - (columns - 1) / 2.0) * SPACING.y
		var rest_y := _slot_rest_y(line)

		# Station IMMER auf der Tischfläche; die Säule reicht bis zum Würfel
		# (hintere Terrassen = höhere Säulen).
		var emitter := StasisEmitter.new()
		emitter.name = "Emitter%d" % i
		slots_container.add_child(emitter)
		emitter.position = Vector3(x, 0.0, z)
		emitter.build(rest_y, DIE_SCALE, tray_color)

		var die := DieBuilder.build()
		slots_container.add_child(die)
		die.position = Vector3(x, rest_y, z)
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
		slot_emitters.append(emitter)
		slot_base_y.append(rest_y)
		slot_phase.append(float(i) * 0.7)
		slot_pose.append(Quaternion.IDENTITY)

## Erweitert das Raster um Spalten, bis mindestens capacity Slots existieren
## (Ausziehtisch). Den sichtbaren Inhalt setzt der nächste fill()-Aufruf.
func ensure_capacity(capacity: int) -> void:
	if rows * columns >= capacity:
		return
	columns = int(ceil(float(capacity) / rows))
	for child in slots_container.get_children():
		child.queue_free()
	_build_slots()

## Zeigt ein Tray den Körper dieses Würfels, oder steht der gerade WOANDERS? Die
## eine Quelle der Lücken-Regel (scene_root fragt sie für beide Trays).
## Aufgespannte Würfel stehen auf der Werkbank - solange dort die Aufspannung
## steht. Steht statt ihrer das DOSSIER, sind die Zwingen von der Bank abgetreten
## und liegen wieder in ihren eigenen Sitzen; dann ist nur der gezeigte Würfel
## woanders, und seine Lücke ist die einzige.
## clamps_visiting: die Aufspannung ist im Tray zu GAST (Pool-Sicht, Würfel noch
## bearbeitbar) - dann füllen sich ihre Sitze; der gezeigte Würfel fehlt weiter.
static func seat_shows(def: DieDefinition, clamped: Array[DieDefinition],
		inspected: DieDefinition, clamps_visiting: bool = false) -> bool:
	if def == null or def == inspected:
		return false
	if inspected != null or clamps_visiting:
		return true
	return not clamped.has(def)

## Setzt den Inhalt komplett neu: Platz i zeigt defs[i], der Rest bleibt leer.
## Ein null-Eintrag ist eine LÜCKE - der Platz bleibt leer, die Reihe rückt nicht
## auf: jeder Würfel hat seinen Platz (aufgespannt oder im Dossier steht sein
## Körper anderswo, sein Sitz bleibt trotzdem seiner).
## faces: je Würfel die Seite, die oben liegen soll (-1/fehlend = Ruhelage) -
## nur das Ablage-Tray gibt sie mit.
func fill(defs: Array[DieDefinition], faces: Array[int] = []) -> void:
	for i in slot_roots.size():
		var def: DieDefinition = defs[i] if i < defs.size() else null
		slot_defs[i] = def
		if def == null:
			_set_slot_shown(i, false)
			continue
		_set_slot_shown(i, true)
		slot_pose[i] = face_up_pose(faces[i] if i < faces.size() else -1)
		slot_face_displays[i].apply_definition(def)
		slot_face_displays[i].set_tint(_style_tint(def))

## Leert das Tray (Ablage-Modus, z.B. zu Rundenbeginn).
func clear() -> void:
	next_free_index = 0
	for i in slot_roots.size():
		_set_slot_shown(i, false)

## Legt einen Würfel in den nächsten freien Slot (Ablage-Modus); das Feld rastet
## mit einem Ripple ein.
## face: die Seite, mit der der Würfel abgelegt wurde - er liegt danach so da,
## wie er in der Grube lag (-1 = Ruhelage).
func add_die(def: DieDefinition, face: int = -1) -> void:
	if next_free_index >= slot_roots.size():
		return
	var i := next_free_index
	next_free_index += 1
	_set_slot_shown(i, true)
	slot_defs[i] = def
	slot_pose[i] = face_up_pose(face)
	slot_face_displays[i].apply_definition(def)
	slot_face_displays[i].set_tint(_style_tint(def))
	slot_emitters[i].ripple()  # das Feld rastet ein

## Blendet nur den WÜRFEL ein/aus - die Emitter-Station bleibt dauerhaft
## sichtbar; die Säule wechselt zwischen Leerlauf-Stummel und voller Trage-Höhe
## (engaged, siehe stasis_beam.gdshader).
func _set_slot_shown(index: int, shown: bool) -> void:
	slot_roots[index].visible = shown
	slot_emitters[index].set_engaged(1.0 if shown else 0.0)

## Lage, die face nach oben bringt und ihre Ziffer aufrecht stehen lässt: die
## Seiten-Achse dreht auf Welt-Oben, die Ziffern-Oben-Richtung auf lokal -Z -
## dieselbe Kalibrierung, aus der die Ruhelage (Gieren um -90°) entstanden ist.
static func face_up_pose(face: int) -> Quaternion:
	if face < 0 or face > 5:
		return Quaternion.IDENTITY
	for axis: String in DiceController.AXIS_FACE_INDEX:
		if DiceController.AXIS_FACE_INDEX[axis] != face:
			continue
		var normal: Vector3 = DiceController.AXIS_DIRECTIONS[axis]
		var text_up: Vector3 = DiceController.FACE_TEXT_UP[axis]
		var from := Basis(normal, text_up, normal.cross(text_up))
		var to := Basis(Vector3.UP, Vector3.FORWARD, Vector3.LEFT)
		return Quaternion(to * from.transposed()).normalized()
	return Quaternion.IDENTITY

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

## Blendet genau den Würfel eines Slots aus/ein (Drag-Ghost), ohne den Inhalt
## zu ändern; die Station bleibt sichtbar. fill() stellt den Würfel wieder her.
func set_slot_visible(index: int, is_visible: bool) -> void:
	_set_slot_shown(index, is_visible)

## Slot-Index zum per Raycast getroffenen Body, oder -1. Auch leere Slots
## behalten ihre Kollisionsform - darum zusätzlich Sichtbarkeit prüfen.
func find_slot_index(collider: Object) -> int:
	var i := slot_bodies.find(collider)
	if i == -1 or not slot_roots[i].visible:
		return -1
	return i
