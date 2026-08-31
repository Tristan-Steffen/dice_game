class_name DiceTrayView
extends Node3D
## Zeigt Würfel als Stasis-Vitrine: jeder Slot ist ein Emitter-Puck (Leuchtscheibe
## auf dem Filz), über dem der Würfel schwebt (sanftes Wippen + leichtes Gieren).
## Alle Würfel schweben GLEICH hoch (Höhe der vorletzten Reihe). Slot-Reihenfolge
## liest wie ein Buch: 0 = oben links, dann zeilenweise. ZWEI Rollen: Pool- und
## Warteschlangen-Tray - beide setzen bei jeder Änderung ihren Inhalt komplett neu
## (siehe fill). Wo ein Platz überhaupt STEHT, entscheidet die Hebebühne draußen
## (slot_staged/slot_riding): der Vorrat sinkt mit dem Zurren der Runde als TRÄGER
## ins Pit und steht dort sichtbar weiter, die Warteschlange fährt je Würfel auf.

@export var rows: int = 5
@export var columns: int = 6
const SPACING := Vector2(1.8, 1.8)
const DIE_SCALE := 0.6  # gemeinsame Würfelgröße (Tray + Grube)
## Einheitliche Schwebehöhe der Würfel-MITTE über der Tischfläche für ALLE Trays
## (auch die einreihige Warteschlange) - hoch genug, dass der Emitter darunter
## sichtbar bleibt und nicht vom Würfel verdeckt wird.
const FLOAT_HEIGHT := 2.22
## 90° aus der Draufsicht: die Ziffer der Oben-Seite steht für den Spieler
## aufrecht. Die EINE Quelle - Bau, Schwebe-Takt und die liegende Pit-Ablage.
const YAW_REST := -PI / 2.0

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
## Steht dieser Platz überhaupt AUF dem Tisch? Die Warteschlange fährt per
## Hebebühne auf und ab - ein abgesenkter Platz zeigt weder Puck noch Würfel,
## egal was fill() sagt. Vorbelegt true: der Vorrat steht wie eh und je.
var slot_staged: Array[bool] = []
## Und führt ihn gerade die Hebebühne? Dann schweigt der Schwebe-Takt: zwei
## Schreiber auf derselben Höhe zappelten gegeneinander.
var slot_riding: Array[bool] = []

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
		if not slot_roots[i].visible or slot_riding[i]:
			continue
		var phase: float = slot_phase[i]
		var bob := sin(t * BOB_SPEED + phase)
		slot_roots[i].position.y = slot_base_y[i] + bob * BOB_AMPLITUDE
		# Gieren um die Hochachse - quaternion statt rotation.y, weil die Lage sonst
		# jeden Frame verloren ginge (der Setter nimmt die Skalierung mit).
		var yaw := YAW_REST + deg_to_rad(SWAY_DEGREES) * sin(t * SWAY_SPEED + phase)
		slot_roots[i].quaternion = Quaternion(Vector3.UP, yaw)
		slot_emitters[i].set_load(StasisEmitter.load_for(bob))

## Einheitliche Schwebehöhe für ALLE Slots und Trays (siehe FLOAT_HEIGHT).
func _slot_rest_y(_line: int) -> float:
	return FLOAT_HEIGHT

## Der Sitz eines Platzes im Raster (tray-lokal, y = Tischfläche). Die EINE
## Rasterrechnung: Aufbau und Fahrplan lesen sie, statt sie nachzurechnen.
func slot_offset(index: int) -> Vector3:
	var line := index / columns
	var pos_in_line := index % columns
	return Vector3(((rows - 1) / 2.0 - line) * SPACING.x, 0.0,
		(pos_in_line - (columns - 1) / 2.0) * SPACING.y)

## Und seine HEIMAT in der Welt - gerechnet, nie am Körper gemessen: wer gerade
## fährt, steht woanders. floating = die Schwebehöhe des Würfels statt der Fläche.
func slot_home_position(index: int, floating := false) -> Vector3:
	var at := global_position + slot_offset(index)
	if floating:
		at.y += FLOAT_HEIGHT
	return at

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
	slot_staged.clear()
	slot_riding.clear()
	for i in rows * columns:
		var line := i / columns
		var seat := slot_offset(i)
		var x := seat.x
		var z := seat.z
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
		die.rotation.y = YAW_REST
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
		slot_staged.append(true)
		slot_riding.append(false)

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
## eine Quelle der Lücken-Regel (scene_root fragt sie für beide Trays). Ein
## aufgespannter Würfel LIEGT im Pool, bis er zur Bank WANDERT - erst auf der Bank
## (on_bench) bleibt sein Sitz leer. Und der gezeigte Dossier-Würfel steht über der
## Seite; sein Sitz ist die andere Lücke.
static func seat_shows(def: DieDefinition, inspected: DieDefinition,
		on_bench: bool = false) -> bool:
	if def == null or def == inspected:
		return false
	return not on_bench

## Setzt den Inhalt komplett neu: Platz i zeigt defs[i], der Rest bleibt leer.
## Ein null-Eintrag ist eine LÜCKE - der Platz bleibt leer, die Reihe rückt nicht
## auf: jeder Würfel hat seinen Platz (aufgespannt oder im Dossier steht sein
## Körper anderswo, sein Sitz bleibt trotzdem seiner).
func fill(defs: Array[DieDefinition]) -> void:
	for i in slot_roots.size():
		var def: DieDefinition = defs[i] if i < defs.size() else null
		slot_defs[i] = def
		if def == null:
			_set_slot_shown(i, false)
			continue
		_set_slot_shown(i, true)
		slot_face_displays[i].apply_definition(def)
		slot_face_displays[i].set_tint(_style_tint(def))

## Leert das Tray (z.B. zu Rundenbeginn).
func clear() -> void:
	for i in slot_roots.size():
		_set_slot_shown(i, false)

## Blendet nur den WÜRFEL ein/aus - die Emitter-Station bleibt dauerhaft
## sichtbar; die Säule wechselt zwischen Leerlauf-Stummel und voller Trage-Höhe
## (engaged, siehe stasis_beam.gdshader).
## Ein abgesenkter Platz (slot_staged) zeigt gar nichts - er liegt unter der Fläche.
func _set_slot_shown(index: int, shown: bool) -> void:
	var up: bool = shown and slot_staged[index]
	slot_roots[index].visible = up
	slot_emitters[index].visible = slot_staged[index]
	slot_emitters[index].set_engaged(1.0 if up else 0.0)

## Der EINE Schreiber der Platz-Bühne: liegt der Platz unter der Fläche, sind Puck
## UND Würfel fort; kommt er zurück, entscheidet wieder sein Inhalt.
func set_slot_staged(index: int, staged: bool) -> void:
	if index < 0 or index >= slot_staged.size() or slot_staged[index] == staged:
		return
	slot_staged[index] = staged
	_set_slot_shown(index, slot_defs[index] != null)

## Solange die Hebebühne einen Platz führt, hält der Schwebe-Takt still.
func set_slot_riding(index: int, riding: bool) -> void:
	if index >= 0 and index < slot_riding.size():
		slot_riding[index] = riding

## Der PUCK eines Platzes als Körper - er fährt als Cargo mit (Puck UND Würfel).
func slot_emitter(index: int) -> StasisEmitter:
	return slot_emitters[index]

## Wieviele volle Reihen VOR diesem Platz liegen - die Rechnung, nach der der
## geparkte Träger vorrückt (ist die vorderste Pool-Reihe leer, fährt er eine
## Reihen-Teilung weiter). Reine Arithmetik, damit sie prüfbar bleibt.
static func rows_before(index: int, columns: int) -> int:
	return maxi(index, 0) / maxi(columns, 1)

## Die EINE Reststreuung des Spiels: eine Ablage-Reihe wird beim ERSCHEINEN einmal
## gemischt - jeder Eintrag trägt Würfel UND gemerkte Seite, sie können also nicht
## auseinanderlaufen. Reine Rechnung, damit sie prüfbar bleibt.
static func shuffle_row(items: Array) -> Array:
	var order: Array[int] = []
	for i in items.size():
		order.append(i)
	order.shuffle()
	var out: Array = []
	for i: int in order:
		out.append(items[i])
	return out

## Der Belegungs-DIFF der Hebebühne: welche Plätze AUFFAHREN müssen. Wer seinen
## Würfel verloren hat, wird nur abgeschrieben - ihn trug die Wurf-Zeremonie fort,
## die Bühne holt ihn nicht nach. Reine Rechnung, damit sie prüfbar bleibt.
static func stage_entering(wanted: Array[bool], standing: Array[bool]) -> Array[int]:
	var enter: Array[int] = []
	for i in wanted.size():
		var up: bool = i < standing.size() and standing[i]
		if wanted[i] and not up:
			enter.append(i)
	return enter

## Lage, die face nach oben bringt und ihre Ziffer aufrecht stehen lässt: die
## Seiten-Achse dreht auf Welt-Oben, die Ziffern-Oben-Richtung auf lokal -Z -
## dieselbe Kalibrierung, aus der die Ruhelage (Gieren um -90°) entstanden ist.
## Die LIEGENDE Ablage im Pit trägt damit die gemerkte Seite oben.
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
