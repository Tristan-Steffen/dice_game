class_name RotatableDieView
extends SubViewportContainer
## Zeigt 1..n Würfel in einem eigenen SubViewport (isolierte World3D).
## Ziehen dreht den Würfel unter dem Cursor (nur Ansicht); ein Klick ohne
## Bewegung löst die_clicked/face_clicked/edges_clicked aus. Genutzt vom
## Shop (mehrere Würfel) und der Gravur-Station (einer).

signal die_clicked(index: int)
## Zusätzlich mit der angeklickten physischen Seite (0..5) - nur bei
## Einzelwürfel-Nutzung sinnvoll.
signal face_clicked(die_index: int, face_index: int)
## Klick auf den Kanten-Rahmen; gewinnt gegen face_clicked, wenn der Klick
## einer Kanten-Mitte näher liegt als jeder Seiten-Mitte.
signal edges_clicked(die_index: int)
## Seite unter dem Cursor beim Überfahren (ohne Ziehen); face_index -1 = keine
## (Kante näher oder nichts getroffen). Treibt die Gravur-Vorschau.
signal face_hovered(die_index: int, face_index: int)
## Dreh-Geste beginnt/endet - der Aufrufer kann derweil z.B. die Kamera
## sperren. drag_ended folgt IMMER auf ein drag_started.
signal drag_started
signal drag_ended

const DRAG_THRESHOLD := 6.0
const DRAG_SENSITIVITY := 0.01
const DIE_SPACING := 3.0

## DIE Auswahl-Farbe der Gravur-Station - identisch an allen Auswahl-Stellen
## (Projektion, schwebender Würfel, Seiten-Chips). Bewusst dunkles Violett:
## ein helleres bloomt im Tisch-Glow nach Weiß aus.
const SELECT_FACE_COLOR := Color(0.66, 0.22, 1.0)
## Mindest-Dot (Seitennormale · Richtung zur Kamera), ab dem eine Seite als
## zugewandt und damit anklickbar gilt.
const FACE_FRONT_MIN_DOT := 0.15

@export var pick_radius: float = 110.0  # Pixel-Toleranz um die projizierte Mitte
@export var camera_distance: float = 6.0

@onready var viewport: SubViewport = $SubViewport

var die_roots: Array[Node3D] = []
var current_defs: Array[DieDefinition] = []  # Grundlage der Material-Tooltips
var camera: Camera3D

var drag_index: int = -1
var drag_start_pos: Vector2
var is_dragging: bool = false

## Zuletzt überfahrene Seite/Würfel (nur Wechsel feuern face_hovered).
var _hover_face: int = -1
var _hover_die: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_mouse_exited)
	_build_scene()

func _on_mouse_exited() -> void:
	if _hover_face != -1 or _hover_die != -1:
		_hover_face = -1
		_hover_die = -1
		face_hovered.emit(-1, -1)

func _build_scene() -> void:
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-50, 35, 0)
	key_light.light_energy = 1.1
	viewport.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-30, -150, 0)
	fill_light.light_energy = 0.4
	viewport.add_child(fill_light)

	camera = Camera3D.new()
	camera.fov = 30.0
	viewport.add_child(camera)
	camera.position = Vector3(0, 3.2, camera_distance)
	camera.look_at(Vector3.ZERO, Vector3.UP)

## Baut die Würfel neu auf (links nach rechts; ein einzelner steht mittig).
func set_dice(defs: Array[DieDefinition]) -> void:
	current_defs = defs
	drag_index = -1
	is_dragging = false
	_hover_face = -1
	_hover_die = -1
	var count := defs.size()

	# Bei gleicher Anzahl die vorhandenen Würfel weiterverwenden (nur Werte neu
	# setzen, Drehung/Skalierung zurück) statt sie neu zu bauen - spart den
	# Neuaufbau und die GPU-Material-Kompilierung bei jedem Ziel-Wechsel.
	if die_roots.size() == count:
		for i in count:
			die_roots[i].scale = Vector3.ONE
			die_roots[i].rotation_degrees = Vector3(-18, 30, 0)
			_apply_die(i, defs[i])
		return

	for root in die_roots:
		root.queue_free()
	die_roots.clear()

	for i in count:
		var die := DieBuilder.build()
		viewport.add_child(die)
		die.position = Vector3((i - (count - 1) / 2.0) * DIE_SPACING, 0.0, 0.0)
		die.rotation_degrees = Vector3(-18, 30, 0)

		var body: RigidBody3D = die.get_node("RigidBody3D")
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0

		die_roots.append(die)
		_apply_die(i, defs[i])

func _apply_die(index: int, def: DieDefinition) -> void:
	var faces: DieFaceDisplay = die_roots[index].get_node("RigidBody3D/Faces")
	faces.apply_definition(def)
	faces.set_tint(DiceController.KIND_TINTS.get(def.style_id, Color.WHITE))

## Tooltip: Material der Seite/Kante unter dem Cursor samt Wirkung; leer,
## wenn dort keins sitzt. at_position ist Control-lokal (= Viewport-Pixel).
func _get_tooltip(at_position: Vector2) -> String:
	var die_index := _pick_die(at_position)
	if die_index < 0 or die_index >= current_defs.size():
		return ""
	var def := current_defs[die_index]
	# Kante vs. Seite: das Nähere gewinnt (wie beim Klick).
	var face_pick := _pick_face(die_index, at_position)
	var edge_dist := _pick_edges_distance(die_index, at_position)
	if edge_dist < float(face_pick[1]):
		if DieMaterial.is_valid_id(def.edge_material):
			var edge := DieMaterial.by_id(def.edge_material)
			return "Kanten – %s\n%s" % [edge.display_name, edge.edge_description]
		return ""
	var face_index: int = face_pick[0]
	if face_index != -1 and face_index < def.materials.size() and DieMaterial.is_valid_id(def.materials[face_index]):
		var material := DieMaterial.by_id(def.materials[face_index])
		return "%s\n%s" % [material.display_name, material.description]
	return ""

func _make_custom_tooltip(for_text: String) -> Object:
	return CasinoStyle.build_material_tooltip(for_text)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_index = _pick_die(event.position)
			drag_start_pos = event.position
			is_dragging = false
		elif drag_index != -1:
			if not is_dragging:
				die_clicked.emit(drag_index)
				# Seite oder Kanten-Rahmen: was dem Klick näher liegt, gewinnt.
				var face_pick := _pick_face(drag_index, event.position)
				var edge_dist := _pick_edges_distance(drag_index, event.position)
				if edge_dist < face_pick[1]:
					edges_clicked.emit(drag_index)
				elif face_pick[0] != -1:
					face_clicked.emit(drag_index, face_pick[0])
			else:
				drag_ended.emit()
			drag_index = -1
			is_dragging = false
	elif event is InputEventMouseMotion and drag_index != -1:
		if not is_dragging and event.position.distance_to(drag_start_pos) > DRAG_THRESHOLD:
			is_dragging = true
			drag_started.emit()
		if is_dragging:
			var die := die_roots[drag_index]
			die.global_rotate(Vector3.UP, event.relative.x * DRAG_SENSITIVITY)
			die.global_rotate(camera.global_transform.basis.x.normalized(), event.relative.y * DRAG_SENSITIVITY)
	elif event is InputEventMouseMotion and drag_index == -1:
		_update_hover(event.position)

## Meldet die Seite unter dem Cursor (Kante näher = keine), nur bei Wechsel.
func _update_hover(local_pos: Vector2) -> void:
	var die_index := _pick_die(local_pos)
	var face_index := -1
	if die_index != -1:
		var face_pick := _pick_face(die_index, local_pos)
		var edge_dist := _pick_edges_distance(die_index, local_pos)
		if edge_dist >= float(face_pick[1]):
			face_index = face_pick[0]
	if face_index != _hover_face or die_index != _hover_die:
		_hover_face = face_index
		_hover_die = die_index
		face_hovered.emit(die_index, face_index)

## Angeklickte physische Seite: [face_index (-1 = keine), Distanz zur
## projizierten Seiten-Mitte (INF)]. Nur zugewandte Seiten zählen; Bildschirm-
## Projektion statt Physik-Raycast (der im isolierten Viewport unzuverlässig ist).
func _pick_face(die_index: int, local_pos: Vector2) -> Array:
	var best_face := -1
	var best_dist := INF
	var faces := _face_display(die_index)
	if faces == null:
		return [best_face, best_dist]
	for axis in faces.quads:
		var quad: MeshInstance3D = faces.quads[axis]
		var to_cam: Vector3 = (camera.global_position - quad.global_position).normalized()
		var normal: Vector3 = quad.global_transform.basis.z.normalized()
		if normal.dot(to_cam) <= FACE_FRONT_MIN_DOT:
			continue
		var screen: Vector2 = camera.unproject_position(quad.global_position)
		var dist := screen.distance_to(local_pos)
		if dist < best_dist and dist < pick_radius:
			best_dist = dist
			best_face = DiceController.AXIS_FACE_INDEX[axis]
	return [best_face, best_dist]

## Distanz zur nächsten zugewandten KANTEN-Mitte (INF = keine in pick_radius).
## Jedes Paar senkrechter Achsrichtungen ist eine Kante; ihre "Normale" ist
## die Winkelhalbierende beider Seiten-Normalen.
func _pick_edges_distance(die_index: int, local_pos: Vector2) -> float:
	var best_dist := INF
	var faces := _face_display(die_index)
	if faces == null:
		return best_dist
	var directions: Array = DiceController.AXIS_DIRECTIONS.values()
	for i in directions.size():
		for j in range(i + 1, directions.size()):
			var a: Vector3 = directions[i]
			var b: Vector3 = directions[j]
			if not is_zero_approx(a.dot(b)):
				continue
			var mid_global: Vector3 = faces.global_transform * ((a + b) * DieBuilder.HALF_EXTENT)
			var to_cam: Vector3 = (camera.global_position - mid_global).normalized()
			var normal: Vector3 = (faces.global_transform.basis * (a + b)).normalized()
			if normal.dot(to_cam) <= FACE_FRONT_MIN_DOT:
				continue
			var dist := camera.unproject_position(mid_global).distance_to(local_pos)
			if dist < best_dist and dist < pick_radius:
				best_dist = dist
	return best_dist

func _face_display(die_index: int) -> DieFaceDisplay:
	if camera == null or die_index < 0 or die_index >= die_roots.size():
		return null
	return die_roots[die_index].get_node_or_null("RigidBody3D/Faces")

## Hebt genau eine Seite hervor: ihre Ziffer leuchtet violett, der Körper
## bleibt neutral; -1 = keine Hervorhebung.
func highlight_face(die_index: int, face_index: int) -> void:
	if die_index < 0 or die_index >= die_roots.size():
		return
	var faces: DieFaceDisplay = die_roots[die_index].get_node_or_null("RigidBody3D/Faces")
	if faces == null:
		return
	faces.set_tint(Color.WHITE)
	faces.reset_number_tints()
	if face_index != -1:
		faces.set_face_number_tint(face_index, SELECT_FACE_COLOR)

## Färbt NUR die Ziffer einer einzelnen Seite (Eignungs-Dimmung der Gravur-
## Station); highlight_face/highlight_edges setzen alle Ziffern wieder zurück.
func tint_face(die_index: int, face_index: int, color: Color) -> void:
	if face_index == -1:
		return
	var faces := _face_display(die_index)
	if faces != null:
		faces.set_face_number_tint(face_index, color)

## Hebt den Kanten-Rahmen hervor; highlight_face setzt wieder zurück.
func highlight_edges(die_index: int) -> void:
	if die_index < 0 or die_index >= die_roots.size():
		return
	var faces: DieFaceDisplay = die_roots[die_index].get_node_or_null("RigidBody3D/Faces")
	if faces == null:
		return
	faces.set_tint(Color.WHITE)
	faces.reset_number_tints()
	faces.set_edge_tint(SELECT_FACE_COLOR)

## Zeichnet die Augenzahlen neu (z.B. nach einer Ätzung); Tönungen bleiben,
## der Aufrufer setzt danach ggf. highlight_face neu.
func refresh_faces(defs: Array[DieDefinition]) -> void:
	for i in mini(defs.size(), die_roots.size()):
		var faces: DieFaceDisplay = die_roots[i].get_node_or_null("RigidBody3D/Faces")
		if faces != null:
			faces.apply_definition(defs[i])

## Würfel unter local_pos: die am nächsten projizierte Mitte gewinnt
## (innerhalb pick_radius); kein Physik-Raycast nötig.
func _pick_die(local_pos: Vector2) -> int:
	if camera == null:
		return -1
	var best_index := -1
	var best_dist := pick_radius
	for i in die_roots.size():
		var screen_pos := camera.unproject_position(die_roots[i].global_position)
		var dist := screen_pos.distance_to(local_pos)
		if dist < best_dist:
			best_dist = dist
			best_index = i
	return best_index
