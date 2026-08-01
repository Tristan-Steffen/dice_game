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
## Rest-Höhe, wenn ein Würfel den Tisch BERÜHRT (Gravur/Zählen, extern genutzt).
const REST_Y := DIE_SCALE

## Schweb-Animation: Wippen (vertikal) + leichtes Gieren (Drehung), je Slot
## phasenversetzt, damit die Vitrine lebt ohne die Augenzahl unlesbar zu drehen.
const BOB_AMPLITUDE := 0.06
const BOB_SPEED := 1.1
const SWAY_DEGREES := 5.0
const SWAY_SPEED := 0.6

## Emitter-Station: Dial-Puck (flach) + Iris (Dunkelglas-Port, aus dem der Strahl
## austritt) + Kraftfeld-Säule (Projektionskegel). Alle DAUERHAFT sichtbar und
## IMMER auf der Tischfläche - nur der Würfel schwebt, die Säule trägt ihn.
const PUCK_RADIUS := 0.62
const PUCK_Y := 0.04
const PUCK_SHADER := preload("res://assets/shaders/stasis_puck.gdshader")
const BEAM_SHADER := preload("res://assets/shaders/stasis_beam.gdshader")
const LENS_SHADER := preload("res://assets/shaders/stasis_lens.gdshader")
## Projektionskegel: schmale Blende unten, öffnet sich nach oben zum Würfel.
const BEAM_BOTTOM_RADIUS := 0.28
const BEAM_TOP_RADIUS := 0.6
## Emitter-Iris (flacher Dunkelglas-Port) - Halbbreite der Scheibe.
const LENS_RADIUS := 0.34
## Last-Puls: der Emitter leuchtet heller, je tiefer der Würfel im Wippen sinkt.
const LOAD_AMOUNT := 0.5
## Einrast-Ripple beim Ablegen (impact 0->1).
const RIPPLE_TIME := 0.5

@export var tray_color: Color = Color(0.15, 0.35, 0.75):
	set(value):
		tray_color = value
		for material in puck_materials:
			material.set_shader_parameter("tint", tray_color)
		for material in beam_materials:
			material.set_shader_parameter("beam_color", Vector3(tray_color.r, tray_color.g, tray_color.b))
		for material in lens_materials:
			material.set_shader_parameter("tint", Vector3(tray_color.r, tray_color.g, tray_color.b))

@onready var tray_mesh_root: Node3D = $TrayMesh
@onready var slots_container: Node3D = $Slots

## Unsichtbarer Klickbereich (Layer 4) für den Kamera-Zoom auf dieses Tray.
@onready var click_zone: StaticBody3D = $ClickZone

## Kollisions-Layer der Slot-Bodies - macht einzelne Tray-Würfel anklickbar.
const SLOT_PICK_LAYER := 16
## Anheben des gegriffenen Würfels beim Umlegen (Höhe, Größe, Dauer).
const DRAG_LIFT := 0.9
const DRAG_LIFT_SCALE := 1.12
const DRAG_LIFT_TIME := 0.12

var slot_roots: Array[Node3D] = []
var slot_bodies: Array[RigidBody3D] = []
var slot_face_displays: Array[DieFaceDisplay] = []
var slot_defs: Array[DieDefinition] = []

## Emitter-Stationen je Slot (Puck + Beam) - dauerhaft sichtbar. Die Beams
## brauchen EIGENE Materialien: Höhe (Terrasse) und engaged sind je Slot anders.
var slot_pucks: Array[MeshInstance3D] = []
var slot_beams: Array[MeshInstance3D] = []
var slot_lenses: Array[MeshInstance3D] = []
var puck_materials: Array[ShaderMaterial] = []
var beam_materials: Array[ShaderMaterial] = []
var lens_materials: Array[ShaderMaterial] = []
var puck_tweens: Array[Tween] = []
## Ruhe-Höhe (inkl. Terrasse) und Phasen-Offset je Slot für die Schweb-Animation.
var slot_base_y: Array[float] = []
var slot_phase: Array[float] = []

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
		slot_roots[i].rotation.y = -PI / 2.0 + deg_to_rad(SWAY_DEGREES) * sin(t * SWAY_SPEED + phase)
		# bob < 0 = Würfel unten = mehr Last = heller.
		var load := 1.0 - LOAD_AMOUNT * bob
		beam_materials[i].set_shader_parameter("load", load)
		lens_materials[i].set_shader_parameter("pulse", load)

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
	slot_pucks.clear()
	slot_beams.clear()
	slot_lenses.clear()
	puck_materials.clear()
	beam_materials.clear()
	lens_materials.clear()
	puck_tweens.clear()
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
		var puck := _build_puck(Vector3(x, PUCK_Y, z))
		slots_container.add_child(puck)
		var lens := _build_lens(Vector3(x, PUCK_Y, z))
		slots_container.add_child(lens)
		var beam := _build_beam(Vector3(x, 0.0, z), rest_y)
		slots_container.add_child(beam)

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
		slot_pucks.append(puck)
		slot_beams.append(beam)
		slot_lenses.append(lens)
		puck_materials.append(puck.mesh.surface_get_material(0))
		beam_materials.append(beam.material_override as ShaderMaterial)
		lens_materials.append(lens.mesh.surface_get_material(0))
		puck_tweens.append(null)
		slot_base_y.append(rest_y)
		slot_phase.append(float(i) * 0.7)

## Emitter-Puck: flache, additive Leuchtscheibe (liegt in der XZ-Ebene).
func _build_puck(at: Vector3) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = PUCK_SHADER
	material.set_shader_parameter("tint", tray_color)
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(PUCK_RADIUS * 2.0, PUCK_RADIUS * 2.0)
	mesh.material = material
	var puck := MeshInstance3D.new()
	puck.mesh = mesh
	puck.position = at
	return puck

## Emitter-Iris: flacher Dunkelglas-Port (liegt in der XZ-Ebene, knapp über dem
## Puck) - die sichtbare Austrittsstelle des Strahls.
func _build_lens(at: Vector3) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = LENS_SHADER
	material.set_shader_parameter("tint", Vector3(tray_color.r, tray_color.g, tray_color.b))
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(LENS_RADIUS * 2.0, LENS_RADIUS * 2.0)
	mesh.material = material
	var lens := MeshInstance3D.new()
	lens.mesh = mesh
	lens.position = at + Vector3.UP * 0.01  # knapp über dem Puck-Dial
	return lens

## Kraftfeld-Säule: vom Tisch (base_at) bis zur Würfel-Ruhehöhe rest_y; der
## Griff-Ring sitzt an der Würfel-Unterseite (grip_h relativ zur Säulenhöhe).
func _build_beam(base_at: Vector3, rest_y: float) -> MeshInstance3D:
	var beam_h := rest_y - base_at.y
	var die_bottom := rest_y - DIE_SCALE * DieBuilder.HALF_EXTENT
	var material := ShaderMaterial.new()
	material.shader = BEAM_SHADER
	material.set_shader_parameter("beam_height", beam_h)
	material.set_shader_parameter("grip_h", clampf((die_bottom - base_at.y) / beam_h, 0.0, 1.0))
	material.set_shader_parameter("beam_color", Vector3(tray_color.r, tray_color.g, tray_color.b))
	var mesh := CylinderMesh.new()
	mesh.top_radius = BEAM_TOP_RADIUS
	mesh.bottom_radius = BEAM_BOTTOM_RADIUS
	mesh.height = beam_h
	mesh.radial_segments = 16
	var beam := MeshInstance3D.new()
	beam.mesh = mesh
	beam.material_override = material
	beam.position = base_at + Vector3.UP * beam_h * 0.5
	return beam

## Erweitert das Raster um Spalten, bis mindestens capacity Slots existieren
## (Ausziehtisch). Den sichtbaren Inhalt setzt der nächste fill()-Aufruf.
func ensure_capacity(capacity: int) -> void:
	if rows * columns >= capacity:
		return
	columns = int(ceil(float(capacity) / rows))
	for child in slots_container.get_children():
		child.queue_free()
	_build_slots()

## Setzt den Inhalt komplett neu: erste defs.size() Slots gefüllt (kompakt
## von vorn, nie eine Lücke mittendrin), Rest ausgeblendet.
func fill(defs: Array[DieDefinition]) -> void:
	for i in slot_roots.size():
		if i < defs.size():
			var def: DieDefinition = defs[i]
			_set_slot_shown(i, true)
			slot_defs[i] = def
			slot_face_displays[i].apply_definition(def)
			slot_face_displays[i].set_tint(_style_tint(def))
		else:
			_set_slot_shown(i, false)

## Leert das Tray (Ablage-Modus, z.B. zu Rundenbeginn).
func clear() -> void:
	next_free_index = 0
	for i in slot_roots.size():
		_set_slot_shown(i, false)

## Legt einen Würfel in den nächsten freien Slot (Ablage-Modus); das Feld rastet
## mit einem Ripple ein.
func add_die(def: DieDefinition) -> void:
	if next_free_index >= slot_roots.size():
		return
	var i := next_free_index
	next_free_index += 1
	_set_slot_shown(i, true)
	slot_defs[i] = def
	slot_face_displays[i].apply_definition(def)
	slot_face_displays[i].set_tint(_style_tint(def))
	_pulse_puck(i)

## Blitzt den Einrast-Ripple eines Pucks auf (impact läuft 0->1 nach außen).
func _pulse_puck(index: int) -> void:
	if puck_tweens[index] != null and puck_tweens[index].is_valid():
		puck_tweens[index].kill()
	var material := puck_materials[index]
	material.set_shader_parameter("impact", 0.0)
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: material.set_shader_parameter("impact", v),
		0.0, 1.0, RIPPLE_TIME)
	puck_tweens[index] = tween

## Blendet nur den WÜRFEL ein/aus - die Emitter-Station (Puck + Beam) bleibt
## dauerhaft sichtbar; die Säule wechselt zwischen Leerlauf-Stummel und voller
## Trage-Höhe (engaged, siehe stasis_beam.gdshader).
func _set_slot_shown(index: int, shown: bool) -> void:
	slot_roots[index].visible = shown
	beam_materials[index].set_shader_parameter("engaged", 1.0 if shown else 0.0)

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

## Hebt den Würfel eines Slots sichtbar an und hellt ihn auf, solange er für
## eine Zieh-Geste in der Hand liegt. Reine Anzeige - der Inhalt bleibt.
func lift_slot(index: int, lifted: bool) -> void:
	if index < 0 or index >= slot_roots.size():
		return
	var root := slot_roots[index]
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "position:y",
		_slot_rest_y(0) + (DRAG_LIFT if lifted else 0.0), DRAG_LIFT_TIME)
	tween.tween_property(root, "scale",
		Vector3.ONE * (DRAG_LIFT_SCALE if lifted else 1.0), DRAG_LIFT_TIME)

## Slot-Index zum per Raycast getroffenen Body, oder -1. Auch leere Slots
## behalten ihre Kollisionsform - darum zusätzlich Sichtbarkeit prüfen.
func find_slot_index(collider: Object) -> int:
	var i := slot_bodies.find(collider)
	if i == -1 or not slot_roots[i].visible:
		return -1
	return i
