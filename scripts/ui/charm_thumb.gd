class_name CharmThumb
extends SubViewportContainer
## 3D-Vorschau eines Charm-Modells in eigenem SubViewport: über die
## Gesamt-AABB auf Einheitsgröße normiert und um sein Zentrum aufgehängt;
## ohne Modelldatei greift die Platzhalter-Karte. rotatable=false rendert
## genau EIN Bild (billig für die vielen Bibliothekszeilen), rotatable=true
## erlaubt freies Drehen per Ziehen (Nahansicht, Shop).

const DRAG_SENSITIVITY := 0.01  # Drehgeschwindigkeit, wie am Werkstück der Gravur-Station
const FIT_SIZE := 2.2           # Zielgröße des Modells in Welteinheiten

var pivot: Node3D
var camera: Camera3D
var dragging := false
var _viewport: SubViewport
var _charm: Charm
var _rotatable := false
var _pending_path := ""  # Modell lädt noch im Ladethread

func _init(charm: Charm, size: int, rotatable: bool = false) -> void:
	_charm = charm
	_rotatable = rotatable
	custom_minimum_size = Vector2(size, size)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP if rotatable else Control.MOUSE_FILTER_IGNORE

	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(size, size)
	_viewport.render_target_update_mode = \
		SubViewport.UPDATE_ALWAYS if rotatable else SubViewport.UPDATE_ONCE
	add_child(_viewport)

	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-50, 35, 0)
	key_light.light_energy = 1.1
	_viewport.add_child(key_light)

	camera = Camera3D.new()
	camera.fov = 30.0
	camera.transform = Transform3D(Basis(), Vector3(0, 1.4, 6.0)).looking_at(Vector3.ZERO, Vector3.UP)
	_viewport.add_child(camera)

	pivot = Node3D.new()
	_viewport.add_child(pivot)
	pivot.rotation_degrees = Vector3(-15, 30, 0)

	# Kaltes Modell blockiert nicht: der Ladethread holt es, _process montiert es.
	var path := charm.model_path
	if path == "" or not CharmRowView.models_wanted() or not ResourceLoader.exists(path):
		_mount_placeholder()
	else:
		CharmRowView.request_model_scene(path)
		var scene := CharmRowView.cached_model_scene(path)
		if scene != null:
			_mount_model(scene.instantiate() as Node3D)
		elif CharmRowView.model_failed(path):
			_mount_placeholder()
		else:
			_pending_path = path
	set_process(_pending_path != "")

func _process(_delta: float) -> void:
	if _pending_path == "":
		set_process(false)
		return
	if CharmRowView.model_failed(_pending_path):
		_pending_path = ""
		_mount_placeholder()
		set_process(false)
		return
	var scene := CharmRowView.poll_model_scene(_pending_path)
	if scene == null:
		return
	_pending_path = ""
	_mount_model(scene.instantiate() as Node3D)
	set_process(false)

## Die flache Platzhalter-Karte liegt auf dem Tisch (Normale +Y) - hier
## aufgestellt, damit die Kamera ihre FLÄCHE sieht statt der dünnen Kante.
func _mount_placeholder() -> void:
	var model := CharmRowView.placeholder_model(_charm.id)
	model.rotation_degrees.x = 90.0
	_mount_model(model)

## Modell über seine AABB einheitlich einpassen (auf FIT_SIZE skaliert) und
## um sein Zentrum drehbar aufhängen, leicht angekippt wie die Würfel.
func _mount_model(model: Node3D) -> void:
	var aabb := merged_aabb(model)
	var max_dim: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var fit: float = FIT_SIZE / maxf(max_dim, 0.001)
	model.scale = Vector3.ONE * fit
	model.position = -aabb.get_center() * fit
	pivot.add_child(model)
	# Das einmalige Bild war schon gerendert, als das Modell noch fehlte.
	if not _rotatable:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

## Freies Drehen per Ziehen (nur rotatable=true - sonst kommt wegen
## MOUSE_FILTER_IGNORE nie ein Ereignis an).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		pivot.global_rotate(Vector3.UP, event.relative.x * DRAG_SENSITIVITY)
		pivot.global_rotate(camera.global_transform.basis.x.normalized(), event.relative.y * DRAG_SENSITIVITY)

## Gesamt-AABB aller MeshInstance3D unter node (im Raum von node).
static func merged_aabb(node: Node) -> AABB:
	var result := AABB()
	var found := false
	var stack: Array = [[node, Transform3D()]]
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var current: Node = pair[0]
		var xform: Transform3D = pair[1]
		if current is Node3D and current != node:
			xform = xform * (current as Node3D).transform
		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			var mesh_aabb: AABB = xform * (current as MeshInstance3D).mesh.get_aabb()
			result = mesh_aabb if not found else result.merge(mesh_aabb)
			found = true
		for child in current.get_children():
			stack.push_back([child, xform])
	return result
