class_name ShopDicePicker
extends SubViewportContainer
## Zeigt die Würfel-Kandidaten des Shops als echte 3D-Würfel nebeneinander in
## einem eigenen SubViewport (eigene, isolierte World3D - siehe _build_scene).
## Ziehen mit gedrückter Maustaste dreht den Würfel unter dem Cursor frei
## (nur Ansicht, keine Physik); ein Klick ohne nennenswerte Bewegung löst
## die_chosen aus. Die Unterscheidung Klick/Ziehen läuft über DRAG_THRESHOLD
## in Pixeln, gemessen ab dem Maus-Down.

signal die_chosen(def: DieDefinition)

const DRAG_THRESHOLD := 6.0
const DRAG_SENSITIVITY := 0.01
const DIE_SPACING := 3.0

@onready var viewport: SubViewport = $SubViewport

var die_roots: Array[Node3D] = []
var die_defs: Array[DieDefinition] = []
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
	camera.position = Vector3(0, 3.2, 6.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)

## Baut die Kandidaten-Würfel neu auf (Reihenfolge = Anzeigereihenfolge
## links nach rechts).
func set_choices(defs: Array[DieDefinition]) -> void:
	for root in die_roots:
		root.queue_free()
	die_roots.clear()
	die_defs = defs.duplicate()
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
		body.collision_layer = 1
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
				die_chosen.emit(die_defs[drag_index])
			drag_index = -1
			is_dragging = false
	elif event is InputEventMouseMotion and drag_index != -1:
		if not is_dragging and event.position.distance_to(drag_start_pos) > DRAG_THRESHOLD:
			is_dragging = true
		if is_dragging:
			var die := die_roots[drag_index]
			die.global_rotate(Vector3.UP, -event.relative.x * DRAG_SENSITIVITY)
			die.global_rotate(camera.global_transform.basis.x.normalized(), -event.relative.y * DRAG_SENSITIVITY)

## Findet den Würfel unter local_pos (Container-lokale Pixelkoordinaten,
## entspricht dank stretch=true 1:1 den Viewport-Pixeln) per Raycast in die
## isolierte World3D des Vorschau-Viewports.
func _pick_die(local_pos: Vector2) -> int:
	if camera == null:
		return -1
	var from := camera.project_ray_origin(local_pos)
	var to := from + camera.project_ray_normal(local_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := viewport.world_3d.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return -1
	var collider: Object = result.collider
	for i in die_roots.size():
		if die_roots[i].get_node("RigidBody3D") == collider:
			return i
	return -1
