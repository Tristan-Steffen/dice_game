class_name DiceTrayView
extends Node3D
## Zeigt Würfel in einem Raster auf einem Kunststoff-Tray (wie ein Casino-
## Chip-Tray). Tray-Mesh und Klickbereich sind echte Kindknoten dieser Szene
## (siehe scenes/dice_chip_tray.tscn für die 30er-Ablage-Variante,
## scenes/dice_pool_tray.tscn für das 24er-Pool-Tray, scenes/dice_queue_tray.tscn
## für die kleine 1x6-Warteschlange); die Würfel werden bei _ready() per
## DieBuilder gebaut und unter $Slots eingehängt (siehe rows/columns/SPACING
## für das Raster - je Tray-Instanz per Export einstellbar). Pool- (24) und
## Warteschlangen-Tray (6) bilden zusammen die vollen POOL_SIZE=30 Würfel der
## laufenden Runde (siehe scene_root.gd: _refresh_deck_trays).
##
## Slot-Reihenfolge liest wie ein Buch: Index 0 = oberste Zeile, ganz links,
## dann zeilenweise nach unten (siehe _build_slots).
##
## Wird in drei Rollen verwendet: als Pool-Tray und als Warteschlangen-Tray
## (beide zeigen bei jeder Änderung ihren kompletten Inhalt neu, immer von
## vorne kompakt gepackt - siehe fill()) sowie als Ablage-Tray (startet leer
## und füllt sich Würfel für Würfel an - siehe clear/add_die).

@export var rows: int = 5  # Anzahl Zeilen, jede mit `columns` Würfeln nebeneinander
@export var columns: int = 6  # Würfel pro Zeile, links nach rechts
const SPACING := Vector2(1.8, 1.8)
const DIE_SCALE := 0.5
const REST_Y := 0.5  # Höhe der Würfel über dem Tray-Boden (lokal, Boden = y 0)

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

## Kollisions-Layer der Slot-RigidBody3D, damit ein einzelner Würfel im
## gezoomten Tray anklickbar ist (siehe scene_root.gd: _try_tray_die_click).
const SLOT_PICK_LAYER := 16

var slot_roots: Array[Node3D] = []
var slot_bodies: Array[RigidBody3D] = []
var slot_face_displays: Array[DieFaceDisplay] = []
var slot_defs: Array[DieDefinition] = []
var plastic_material: StandardMaterial3D

var next_free_index: int = 0  # nächster freier Slot im Ablage-Modus (add_die)

func _ready() -> void:
	_apply_tray_color()
	_build_slots()

## Färbt die Tray-Mesh-Teile (Boden, Wände, Trennstege) in tray_color ein.
func _apply_tray_color() -> void:
	plastic_material = StandardMaterial3D.new()
	plastic_material.albedo_color = tray_color
	plastic_material.roughness = 0.25
	plastic_material.metallic = 0.05
	for mesh_instance in tray_mesh_root.get_children():
		if mesh_instance is MeshInstance3D:
			mesh_instance.set_surface_override_material(0, plastic_material)

## Baut die dekorativen Würfel-Slots im `rows`x`columns`-Raster (eingefroren
## und aus den Kollisions-Layern genommen - kein Physik-Overhead nötig).
## Index-Reihenfolge wie ein Buch: i=0 ist oben links, dann zeilenweise nach
## rechts und unten - siehe Klassenkommentar.
func _build_slots() -> void:
	slot_roots.clear()
	slot_bodies.clear()
	slot_face_displays.clear()
	slot_defs.clear()
	for i in rows * columns:
		var line := i / columns  # 0 = oberste Zeile
		var pos_in_line := i % columns  # 0 = ganz links
		var x := ((rows - 1) / 2.0 - line) * SPACING.x
		var z := (pos_in_line - (columns - 1) / 2.0) * SPACING.y

		var die := DieBuilder.build()
		slots_container.add_child(die)
		die.position = Vector3(x, REST_Y, z)
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

## --- Pool-/Warteschlangen-Modus: kompletter Inhalt wird bei jeder Änderung neu gesetzt ---

## Setzt den sichtbaren Inhalt komplett neu: die ersten defs.size() Slots
## zeigen die übergebenen Würfel (von vorne kompakt gepackt), alle weiteren
## Slots werden ausgeblendet. Dadurch entsteht nie eine Lücke mittendrin, wenn
## der Aufrufer nach und nach weniger Würfel übergibt (z.B. weil vorne welche
## verbraucht wurden) - die freie Fläche wächst immer von hinten (unten rechts).
func fill(defs: Array[DieDefinition]) -> void:
	for i in slot_roots.size():
		if i < defs.size():
			var def: DieDefinition = defs[i]
			slot_roots[i].visible = true
			slot_defs[i] = def
			slot_face_displays[i].apply_definition(def)
			slot_face_displays[i].set_tint(_style_tint(def))
		else:
			slot_roots[i].visible = false

## --- Ablage-Modus: startet leer, füllt sich Würfel für Würfel an ---

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
	slot_defs[i] = def
	slot_face_displays[i].apply_definition(def)
	slot_face_displays[i].set_tint(_style_tint(def))

func _style_tint(def: DieDefinition) -> Color:
	return DiceController.KIND_TINTS.get(def.style_id, Color.WHITE)

## Zeichnet die Augenzahlen aller sichtbaren Slots neu aus slot_defs - nötig,
## nachdem eine Ätzung die faces eines Würfels verändert hat (siehe
## DieInspectorView; slot_defs hält dieselbe DieDefinition-Instanz wie der Pool,
## die Mutation ist also schon passiert). Positionen/Sichtbarkeit bleiben gleich.
func refresh_faces() -> void:
	for i in slot_roots.size():
		if slot_roots[i].visible:
			slot_face_displays[i].apply_definition(slot_defs[i])
			slot_face_displays[i].set_tint(_style_tint(slot_defs[i]))

## Weltposition des Slots mit Index index - auch für leere/unsichtbare Slots,
## z.B. als Start-/Zielpunkt der Aufrück-Animation (siehe scene_root.gd:
## _animate_deck_shift).
func slot_global_position(index: int) -> Vector3:
	return slot_roots[index].global_position

## Blendet genau einen Slot aus/ein, ohne seinen Inhalt zu ändern - z.B. um den
## Würfel eines laufenden Umsortier-Drags kurzzeitig zu verstecken, während ein
## Ghost-Würfel ihn an der Mausposition zeigt (siehe scene_root.gd:
## _begin_reorder_drag). fill() stellt die normale Sichtbarkeit danach wieder her.
func set_slot_visible(index: int, is_visible: bool) -> void:
	slot_roots[index].visible = is_visible

## Liefert den Slot-Index für einen per Raycast getroffenen RigidBody3D, oder
## -1, wenn collider zu keinem sichtbaren Slot dieses Trays gehört (auch
## unsichtbare/leere Slots behalten ihre Kollisionsform, siehe SLOT_PICK_LAYER
## - deshalb hier zusätzlich auf Sichtbarkeit prüfen).
func find_slot_index(collider: Object) -> int:
	var i := slot_bodies.find(collider)
	if i == -1 or not slot_roots[i].visible:
		return -1
	return i
