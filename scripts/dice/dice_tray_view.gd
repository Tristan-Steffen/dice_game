class_name DiceTrayView
extends Node3D
## Zeigt Würfel in einem Raster auf einem Kunststoff-Tray (wie ein Casino-
## Chip-Tray). Tray-Mesh und Klickbereich sind echte Kindknoten dieser Szene
## (siehe scenes/dice_chip_tray.tscn für die 30er-Ablage-Variante,
## scenes/dice_pool_tray.tscn für das 30er-Dice-Tray, scenes/dice_queue_tray.tscn
## für das kleine 1x6-Nachschub-Tray); die Würfel werden bei _ready() per
## DieBuilder gebaut und unter $Slots eingehängt (siehe rows/columns/SPACING
## für das Raster - je Tray-Instanz per Export einstellbar). Das Dice-Tray zeigt
## zu Rundenbeginn ALLE POOL_SIZE=30 Würfel; sobald der Spieler zum ersten Mal in
## die Grube zoomt, lösen sich die nächsten 6 ins Nachschub-Tray vor der Grube und
## das Dice-Tray zeigt den Rest (siehe scene_root.gd: _refresh_deck_trays /
## _queue_display_capacity).
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
const DIE_SCALE := 0.6  # gemeinsame Würfelgröße (Tray + Grube, siehe scene_root._ready)
## Höhe der Würfel-MITTE über dem Tray-Boden (lokal, Boden = y 0): gleich der
## skalierten Würfel-Halbhöhe (DieBuilder.HALF_EXTENT 1.0 × DIE_SCALE), damit
## die Unterseite genau auf dem Tray-Boden (= Tischbildschirm) aufliegt. Wächst
## automatisch mit DIE_SCALE mit, sonst würden größere Würfel einsinken.
const REST_Y := DIE_SCALE

@export var tray_color: Color = Color(0.15, 0.35, 0.75):
	set(value):
		tray_color = value
		if is_inside_tree():
			_rebuild_grid()

@onready var tray_mesh_root: Node3D = $TrayMesh
@onready var slots_container: Node3D = $Slots

## Lichtgitter statt Plastik-Tray: dünne, leuchtende Balken bilden ein Raster,
## in dem jeder Würfel eine Zelle belegt (siehe _rebuild_grid). GRID_Y liegt
## knapp über dem Tischfilz (unter den Würfeln), die Balken sind unbeleuchtet
## und leuchten in tray_color über den Glow-Schwellwert hinaus.
const GRID_Y := 0.03
const GRID_LINE_WIDTH := 0.09
const GRID_LINE_HEIGHT := 0.05
const GRID_EMISSION_ENERGY := 2.6
var grid_root: Node3D

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

var next_free_index: int = 0  # nächster freier Slot im Ablage-Modus (add_die)

func _ready() -> void:
	tray_mesh_root.visible = false  # Plastik-Tray entfällt - das Lichtgitter ersetzt es
	_build_slots()
	_rebuild_grid()

## Baut das Lichtgitter neu: ein Lattengitter aus leuchtenden Balken, das genau
## das rows x columns-Raster der Slots nachzeichnet (jede Zelle = ein Würfel-
## Platz). Wird bei Größenänderungen (ensure_capacity) und Farbwechsel erneuert.
func _rebuild_grid() -> void:
	if grid_root != null:
		grid_root.queue_free()
	grid_root = Node3D.new()
	grid_root.name = "Grid"
	add_child(grid_root)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tray_color
	material.emission_enabled = true
	material.emission = tray_color
	material.emission_energy_multiplier = GRID_EMISSION_ENERGY

	var half_x := rows * 0.5 * SPACING.x
	var half_z := columns * 0.5 * SPACING.y
	# Zeilenlinien (feste x, laufen entlang z) - rows+1 Stück.
	for k in rows + 1:
		var x := half_x - float(k) * SPACING.x
		_add_grid_bar(material, Vector3(x, GRID_Y, 0.0),
			Vector3(GRID_LINE_WIDTH, GRID_LINE_HEIGHT, half_z * 2.0))
	# Spaltenlinien (festes z, laufen entlang x) - columns+1 Stück.
	for k in columns + 1:
		var z := -half_z + float(k) * SPACING.y
		_add_grid_bar(material, Vector3(0.0, GRID_Y, z),
			Vector3(half_x * 2.0, GRID_LINE_HEIGHT, GRID_LINE_WIDTH))

func _add_grid_bar(material: StandardMaterial3D, at: Vector3, size: Vector3) -> void:
	var bar := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	bar.mesh = mesh
	bar.material_override = material
	bar.position = at
	grid_root.add_child(bar)

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
		# 90° nach rechts (aus der Draufsicht): die Ziffer der Oben-Seite steht
		# damit für den Spieler aufrecht (ihr FACE_TEXT_UP -Z dreht auf Welt +X
		# = Bildschirm-oben; die Trays selbst stehen ungedreht in der Szene).
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

## --- Pool-/Warteschlangen-Modus: kompletter Inhalt wird bei jeder Änderung neu gesetzt ---

## Erweitert das Raster bei Bedarf um zusätzliche Spalten, bis mindestens
## capacity Slots existieren (Ausziehtisch: die Warteschlange wächst dauerhaft,
## siehe scene_root._queue_capacity). Baut die Slots neu auf; den sichtbaren
## Inhalt setzt der nächste fill()-Aufruf wieder. Die zusätzlichen Slots ragen
## über das Tray-Mesh hinaus - bewusst in Kauf genommen, statt das Mesh zu
## skalieren.
func ensure_capacity(capacity: int) -> void:
	if rows * columns >= capacity:
		return
	columns = int(ceil(float(capacity) / rows))
	for child in slots_container.get_children():
		child.queue_free()
	_build_slots()
	_rebuild_grid()  # Gitter an die neue Spaltenzahl anpassen (Ausziehtisch)

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
