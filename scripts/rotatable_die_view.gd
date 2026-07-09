class_name RotatableDieView
extends SubViewportContainer
## Zeigt 1..n Würfel nebeneinander in einem eigenen SubViewport (eigene,
## isolierte World3D - siehe _build_scene). Ziehen mit gedrückter Maustaste
## dreht den Würfel unter dem Cursor frei (nur Ansicht, keine Physik); ein
## Klick ohne nennenswerte Bewegung löst die_clicked(index) aus - was das
## für den Aufrufer bedeutet (kaufen, schließen, ...) entscheidet dieser
## selbst. Verwendet vom Shop (mehrere Würfel, siehe scene_root.gd) und vom
## DieInspectorView (ein einzelner Würfel).
##
## Die Unterscheidung Klick/Ziehen läuft über DRAG_THRESHOLD in Pixeln,
## gemessen ab dem Maus-Down.

signal die_clicked(index: int)

const DRAG_THRESHOLD := 6.0
const DRAG_SENSITIVITY := 0.01
const DIE_SPACING := 3.0

@export var pick_radius: float = 110.0  # Pixel-Toleranz um die projizierte Würfelmitte
@export var camera_distance: float = 6.0

@onready var viewport: SubViewport = $SubViewport

var die_roots: Array[Node3D] = []
var camera: Camera3D

var drag_index: int = -1
var drag_start_pos: Vector2
var is_dragging: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_scene()

## Baut Licht und Kamera der isolierten Vorschau-Szene einmalig auf.
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

## Baut die Würfel neu auf (Reihenfolge = Anzeigereihenfolge links nach
## rechts; bei nur einem Eintrag steht der Würfel mittig).
func set_dice(defs: Array[DieDefinition]) -> void:
	for root in die_roots:
		root.queue_free()
	die_roots.clear()
	drag_index = -1
	is_dragging = false

	var count := defs.size()
	for i in count:
		var die := DieBuilder.build()
		viewport.add_child(die)
		die.position = Vector3((i - (count - 1) / 2.0) * DIE_SPACING, 0.0, 0.0)
		die.rotation_degrees = Vector3(-18, 30, 0)

		var body: RigidBody3D = die.get_node("RigidBody3D")
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0

		var faces: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
		faces.apply_definition(defs[i])
		faces.set_tint(DiceController.KIND_TINTS.get(defs[i].style_id, Color.WHITE))

		die_roots.append(die)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_index = _pick_die(event.position)
			drag_start_pos = event.position
			is_dragging = false
		elif drag_index != -1:
			if not is_dragging:
				die_clicked.emit(drag_index)
			drag_index = -1
			is_dragging = false
	elif event is InputEventMouseMotion and drag_index != -1:
		if not is_dragging and event.position.distance_to(drag_start_pos) > DRAG_THRESHOLD:
			is_dragging = true
		if is_dragging:
			var die := die_roots[drag_index]
			die.global_rotate(Vector3.UP, event.relative.x * DRAG_SENSITIVITY)
			die.global_rotate(camera.global_transform.basis.x.normalized(), event.relative.y * DRAG_SENSITIVITY)

## Hebt den Würfel an index optisch hervor (leicht vergrößert), alle anderen
## zurück auf Normalgröße - index == -1 zeigt keine Auswahl. Verwendet vom
## Shop, um die aktuell gewählte Würfeloption erkennbar zu machen (siehe
## scene_root.gd: _on_shop_die_picked).
func set_highlighted(index: int) -> void:
	for i in die_roots.size():
		die_roots[i].scale = Vector3.ONE * (1.15 if i == index else 1.0)

## Findet den Würfel unter local_pos (Container-lokale Pixelkoordinaten,
## entspricht dank stretch=true 1:1 den Viewport-Pixeln): wählt den Würfel,
## dessen auf den Bildschirm projizierte Mitte am nächsten liegt (innerhalb
## pick_radius). Kein Physik-Raycast nötig - vermeidet direct_space_state,
## das für den isolierten Vorschau-Viewport zum Klickzeitpunkt noch nicht
## zuverlässig verfügbar ist.
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
