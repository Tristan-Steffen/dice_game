class_name CharmRowView
extends Node3D
## Die Charm-Reihe als PROJEKTOREN an der USB-LEISTE (2026-11-22): zehn Ports an der Rückwand, je
## gekauftem Projektor ein `CharmReaderView` an seinem Port (set_projectors), Schlitz zum
## Spieler. Je Charm steckt eine
## `CharmDiskView` mit Schieber und Bild im Schlitz, ihr Text liegt davor; über der
## Projektor-Linse schwebt das HOLOGRAMM (massives Modell mit Lichtkante,
## charm_hologram.gdshader). set_charms() ist der EINE idempotente Schreiber: Disketten
## und Hologramme gehören ihrem Charm und fahren im Trage-Bogen zum neuen Platz.

## Abstand der Reihe vom Grubenzentrum (+X = Bildschirm-oben); seit die Diskette nur noch den
## Schieber einsteckt, rückt die Reihe um den Unterschied zurück - ihre Vorderkante bleibt stehen.
const LINE_X := 31.0 + (0.56 - CharmDiskView.INSERT) * CharmDiskView.BLENDER_SCALE
const LINE_SPACING := 9.0
const SPOT_Y := 0.0  # Tischoberfläche
const MODEL_SCALE := 4.0
## Das Hologramm schwebt über der Linse - eine Projektion steht nicht auf.
const HOVER_HEIGHT := 0.6

## Projektoren eines frischen Laufs; wie viele stehen, führt GameRun.
const SPOT_COUNT := GameRun.START_PROJECTORS
const PORT_COUNT := GameRun.MAX_PROJECTORS
## In dieser Folge belegen Projektoren die Ports: erst die Mitte, dann abwechselnd außen.
const PORT_ORDER: Array[int] = [4, 5, 3, 6, 2, 7, 8, 1, 9, 0]
const PORT_MODEL := "res://assets/models/hardware/usb_port.glb"
## Die Leiste IST der Wandfuß des Tischs (TableBodyView.FOOT_HEIGHT hoch).
const RAIL_HEIGHT := 2.0
const PORT_PROUD := 0.02
const PORT_DIGIT := Color(0.55, 0.58, 0.64)
const PORT_LIT := 1.1

## Der Hologramm-Look: Spieler-Wahl 2026-09-09 (Lichtkante plus Kegel), unverändert.
const HOLO_SHADER := preload("res://assets/shaders/charm_hologram.gdshader")
const HOLO_SATURATION := 1.6
const HOLO_SELF_GLOW := 0.45
const HOLO_RIM := 1.0
const HOLO_BAND := 0.18
const HOLO_FLASH := 1.0
## Der Kegel steigt kurz und schwach aus der Linse.
const CONE_HEIGHT := 2.2
const CONE_ALPHA := 0.07
const CONE_BOTTOM := 0.13 * CharmDiskView.BLENDER_SCALE
const CONE_TOP := CONE_BOTTOM * 1.6
const BOB_HEIGHT := 0.15
const BOB_SPEED := 1.3

## Strahler je besetztem Platz; er sieht AUSSCHLIESSLICH die Modelle (eigene Lichtebene).
const MODEL_LIGHT_LAYER := 1 << 19
const SPOT_LIGHT_HEIGHT := 8.5
const SPOT_LIGHT_ENERGY := 2.8
const SPOT_LIGHT_RANGE := 14.0
const SPOT_LIGHT_ANGLE := 34.0
const SPOT_LIGHT_COLOR := Color(1.0, 0.99, 0.97)

## Hover-Toleranz um die projizierte Hologramm-Mitte.
const PICK_RADIUS_PX := 70.0
const ROTATION_SPEED := 0.15  # rad/s

## Die Fahrten: Trage-Bogen zum Schlitz, dann gleitet sie hinein.
const CARRY_TIME := 0.42
const CARRY_PEAK := 2.4
const SLIDE_TIME := 0.22
## Gezogen schwebt die Diskette über den Laufwerken.
const DRAG_HEIGHT := CharmReaderView.SIZE.y + 1.6

var readers: Array[CharmReaderView] = []
## Port je Projektor, aufsteigend (index-parallel zu readers).
var reader_ports: Array[int] = []
var ports: Array[Node3D] = []
var _port_lights: Array[StandardMaterial3D] = []
var _by_port := {}  # Port -> CharmReaderView
var current_charms: Array[Charm] = []
## Index-parallel zu current_charms (für Wertung und Tests).
var charm_nodes: Array[Node3D] = []
var charm_models: Array[Node3D] = []
var charm_materials: Array = []
var spot_lights: Array[SpotLight3D] = []
var cone_nodes: Array[MeshInstance3D] = []
var disks: Array[CharmDiskView] = []

var _bob_time := 0.0
var _cone_mesh: CylinderMesh
## Charm -> {disk, pivot, model, materials, light, cone}
var _bodies := {}
## Charms, deren Diskette noch fliegt: ihr Laufwerk zeigt den Platz LEER.
var _arriving := {}
var _drag: Charm = null
var _badges := {}

func _ready() -> void:
	_ensure_readers()

func _ensure_readers() -> void:
	if readers.is_empty():
		set_projectors(SPOT_COUNT, true)

## Der EINE Schreiber der Projektoren: count stehen an den ersten Ports von PORT_ORDER.
## Ein neuer wächst an seinem Port auf; rückt ein Platz dadurch, ziehen die Disketten um.
func set_projectors(count: int, hard := false) -> void:
	_ensure_rail()
	var wanted: Array[int] = []
	for i in clampi(count, 0, PORT_COUNT):
		wanted.append(PORT_ORDER[i])
	wanted.sort()
	if wanted == reader_ports:
		return
	if current_charms.size() > wanted.size():
		set_charms(current_charms.slice(0, wanted.size()), {}, true)
	for port: int in _by_port.keys():
		if not wanted.has(port):
			(_by_port[port] as Node).queue_free()
			_by_port.erase(port)
	var old := readers.duplicate()
	readers.clear()
	for port in wanted:
		if not _by_port.has(port):
			var reader := CharmReaderView.new()
			reader.name = "Projektor_Port%d" % port
			reader.position = port_position(port)
			add_child(reader)
			_by_port[port] = reader
			if not hard and is_inside_tree():
				reader.appear()
		readers.append(_by_port[port])
	reader_ports = wanted
	for i in current_charms.size():
		if i >= old.size() or old[i] != readers[i]:
			_move_body(current_charms[i], i, hard)
	_refresh_readers()

## Zehn Ports am Wandfuß hinter der Reihe.
func _ensure_rail() -> void:
	if not ports.is_empty():
		return
	var scene: PackedScene = load(PORT_MODEL) if ResourceLoader.exists(PORT_MODEL) else null
	for port in PORT_COUNT:
		var node := Node3D.new()
		node.name = "Port%d" % port
		node.position = port_position(port) + CharmReaderView.PORT - Vector3(PORT_PROUD, 0.0, 0.0)
		add_child(node)
		var light := CharmDiskView._unshaded(CharmReaderView.DARK)
		if scene != null:
			var model := scene.instantiate() as Node3D
			# Platte senkrecht, Normale zum Spieler, Portlicht unten.
			model.basis = Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.UP, -PI * 0.5)
			model.scale = Vector3.ONE * CharmDiskView.BLENDER_SCALE
			CharmDiskView.dress_shell(model)
			node.add_child(model)
			var lamp := model.find_child("Portlicht*", true, false) as MeshInstance3D
			if lamp != null:
				lamp.material_override = light
		var digit := Label3D.new()
		digit.name = "Ziffer"
		digit.text = "%02d" % (port + 1)
		digit.font = CharmDiskView.disk_font()
		digit.font_size = 34
		digit.pixel_size = CharmDiskView.PIXEL
		digit.shaded = false
		digit.double_sided = false
		digit.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		digit.modulate = PORT_DIGIT
		digit.basis = Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT)
		digit.position = Vector3(-0.1, 0.62, 0.0)
		node.add_child(digit)
		ports.append(node)
		_port_lights.append(light)

## Frei dunkel, angeschlossen glimmt der Port, mit Charm leuchtet er in dessen Rarität.
func _refresh_ports() -> void:
	for port in ports.size():
		var reader: CharmReaderView = _by_port.get(port)
		var color := CharmReaderView.DARK
		if reader != null and reader.charm != null:
			color = CharmDiskView.energized(CharmDiskView.rarity_color(reader.charm.rarity), PORT_LIT)
		elif reader != null:
			color = CharmReaderView.STANDBY
		_port_lights[port].albedo_color = color

func port_light_color(port: int) -> Color:
	return _port_lights[port].albedo_color

func projector_count() -> int:
	return readers.size()

## Der EINE Schreiber. incoming: eine frisch gekaufte Diskette, die schon in der Welt
## liegt (Charm -> CharmDiskView) - sie fliegt hinein statt hart zu stecken.
func set_charms(charms: Array[Charm], incoming := {}, hard := false) -> void:
	_ensure_readers()
	_ensure_resources()
	var wanted: Array[Charm] = []
	for i in mini(charms.size(), readers.size()):
		wanted.append(charms[i])
	for charm: Charm in _bodies.keys():
		if not wanted.has(charm):
			_drop_body(charm)
	var old := current_charms
	current_charms = wanted
	for i in wanted.size():
		var charm := wanted[i]
		if incoming.has(charm) and not _bodies.has(charm):
			_adopt(charm, incoming[charm], i)
		elif not _bodies.has(charm):
			_build_body(charm, i)
		elif old.find(charm) != i or _drag == charm:
			_move_body(charm, i, hard)
	if _drag != null and not wanted.has(_drag):
		_drag = null
	_index_bodies()
	_refresh_readers()

func _process(delta: float) -> void:
	_bob_time += delta
	var lift := sin(_bob_time * BOB_SPEED) * BOB_HEIGHT / MODEL_SCALE
	for model in charm_models:
		if is_instance_valid(model):
			model.rotate_object_local(Vector3.UP, ROTATION_SPEED * delta)
			model.position.y = lift

func _refresh_readers() -> void:
	for i in readers.size():
		var charm: Charm = current_charms[i] if i < current_charms.size() else null
		var shown := charm != null and not _arriving.has(charm)
		readers[i].set_charm(charm if shown else null)
		readers[i].set_badge(String(_badges.get(i, "")))
		if charm != null and _bodies.has(charm):
			_set_holo_visible(charm, shown)
	_refresh_ports()

func _index_bodies() -> void:
	charm_nodes.clear()
	charm_models.clear()
	charm_materials.clear()
	spot_lights.clear()
	cone_nodes.clear()
	disks.clear()
	for charm in current_charms:
		var body: Dictionary = _bodies[charm]
		charm_nodes.append(body["pivot"])
		charm_models.append(body["model"])
		charm_materials.append(body["materials"])
		spot_lights.append(body["light"])
		cone_nodes.append(body["cone"])
		disks.append(body["disk"])

func _build_body(charm: Charm, i: int) -> void:
	var disk := CharmDiskView.new(charm)
	disk.name = "Diskette_%s" % charm.id
	add_child(disk)
	disk.global_transform = readers[i].disk_global_transform()
	_bodies[charm] = _holo_for(charm, i)
	_bodies[charm]["disk"] = disk

## Eine gekaufte Diskette: sie liegt schon in der Welt und fliegt in ihren Schlitz.
func _adopt(charm: Charm, disk: CharmDiskView, i: int) -> void:
	var at := disk.global_transform
	if disk.get_parent() != null:
		disk.get_parent().remove_child(disk)
	add_child(disk)
	disk.global_transform = at
	disk.set_lifted(false)
	disk.set_tag("")
	_bodies[charm] = _holo_for(charm, i)
	_bodies[charm]["disk"] = disk
	_arriving[charm] = true
	_fly_in(charm, i)

## Trage-Bogen vor den Schlitz, dann gleitet sie hinein; erst dann leuchtet das Laufwerk.
func _fly_in(charm: Charm, i: int) -> void:
	var disk: CharmDiskView = _bodies[charm]["disk"]
	var home := readers[i].disk_global_transform()
	var mouth := home
	mouth.origin -= readers[i].global_basis.x.normalized() * CharmDiskView.INSERT_DEPTH
	var slide := func() -> void:
		if not _bodies.has(charm) or _bodies[charm]["disk"] != disk:
			return
		var glide := disk.carry_to(home, SLIDE_TIME, 0.0)
		var land := func() -> void:
			if _arriving.erase(charm):
				_refresh_readers()
		if glide == null:
			land.call()
		else:
			glide.finished.connect(land)
	var fly := func() -> void:
		if not _bodies.has(charm) or _bodies[charm]["disk"] != disk:
			return
		var tween := disk.carry_to(mouth, CARRY_TIME, CARRY_PEAK)
		if tween == null:
			slide.call()
		else:
			tween.finished.connect(slide)
	# Steckt sie noch im Laden-Projektor, gleitet sie erst aus dessen Schlitz.
	var out: Tween = null
	if disk.has_meta(&"pull_out"):
		out = disk.carry_to(disk.get_meta(&"pull_out"), SLIDE_TIME, 0.0)
		disk.remove_meta(&"pull_out")
	if out == null:
		fly.call()
	else:
		out.finished.connect(fly)

## Umsortiert: Diskette und Hologramm fahren zum neuen Laufwerk.
func _move_body(charm: Charm, i: int, hard: bool) -> void:
	var body: Dictionary = _bodies[charm]
	var disk: CharmDiskView = body["disk"]
	if _arriving.has(charm):
		_arriving.erase(charm)
	var home := readers[i].disk_global_transform()
	var pivot: Node3D = body["pivot"]
	var holo_at := _holo_position(i)
	if hard:
		disk.settle_carry()
		disk.global_transform = home
		pivot.position = holo_at
	else:
		disk.carry_to(home, CARRY_TIME, CARRY_PEAK)
		var tween := pivot.create_tween()
		tween.tween_property(pivot, "position", holo_at, CARRY_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_place_light(body, i)

func _drop_body(charm: Charm) -> void:
	var body: Dictionary = _bodies[charm]
	for key in ["disk", "pivot", "light", "cone"]:
		var node: Node = body.get(key)
		if node != null and is_instance_valid(node):
			node.queue_free()
	_bodies.erase(charm)
	_arriving.erase(charm)

## Gibt die Diskette des Platzes frei (Verkauf): die Reihe vergißt sie, der Aufrufer
## führt den Körper weiter. Das Hologramm erlischt sofort.
func release_disk(index: int) -> CharmDiskView:
	if index < 0 or index >= current_charms.size():
		return null
	var charm := current_charms[index]
	var body: Dictionary = _bodies[charm]
	var disk: CharmDiskView = body["disk"]
	body["disk"] = null
	_drop_body(charm)
	if disk != null:
		disk.settle_carry()
		var at := disk.global_transform
		remove_child(disk)
		disk.set_meta(&"released_at", at)
	return disk

## Der harte Weg: jede Fahrt steht sofort, gezogen wird nichts mehr.
func settle_hard() -> void:
	_drag = null
	_arriving.clear()
	for i in current_charms.size():
		var body: Dictionary = _bodies[current_charms[i]]
		var disk: CharmDiskView = body["disk"]
		disk.settle_carry()
		disk.global_transform = readers[i].disk_global_transform()
		disk.set_lifted(false)
		(body["pivot"] as Node3D).position = _holo_position(i)
	_refresh_readers()

func arriving() -> bool:
	return not _arriving.is_empty()

# --- Umsortieren -----------------------------------------------------------

## Hebt die Diskette des Platzes aus dem Schlitz; sie folgt dann dem Zeiger.
func begin_drag(index: int) -> void:
	if index < 0 or index >= current_charms.size():
		return
	_drag = current_charms[index]
	var disk: CharmDiskView = _bodies[_drag]["disk"]
	disk.settle_carry()

func dragging() -> bool:
	return _drag != null

## Die gezogene Diskette über dem Weltpunkt (auf der Zieh-Höhe).
func drag_to(point: Vector3) -> void:
	if _drag == null:
		return
	var disk: CharmDiskView = _bodies[_drag]["disk"]
	var at := disk.global_transform
	at.origin = Vector3(point.x, global_position.y + DRAG_HEIGHT, point.z)
	disk.global_transform = at

## Belegtes Laufwerk, das dem Weltpunkt quer am nächsten liegt.
func drop_target(point: Vector3) -> int:
	var best := -1
	var best_dist := INF
	for i in current_charms.size():
		var dist := absf(readers[i].global_position.z - point.z)
		if dist < best_dist:
			best_dist = dist
			best = i
	return best

## Ohne Umsortieren: zurück in den eigenen Schlitz.
func end_drag() -> void:
	if _drag == null:
		return
	var charm := _drag
	_drag = null
	var i := current_charms.find(charm)
	if i >= 0:
		(_bodies[charm]["disk"] as CharmDiskView).carry_to(
			readers[i].disk_global_transform(), CARRY_TIME, 0.6)

# --- Anzeige ---------------------------------------------------------------

## Zähler-Chips je Platz (Platz -> Text) auf das Front-Display.
func set_badges(texts: Dictionary) -> void:
	_badges = texts.duplicate()
	for i in readers.size():
		readers[i].set_badge(String(_badges.get(i, "")))

## Der Verkaufspreis auf dem Display des Platzes (-1 = keiner).
func set_sale(index: int, text: String) -> void:
	for i in readers.size():
		readers[i].set_sale(text if i == index else "")

## Hologramm, Laufwerk UND Diskette blitzen ("dieser Charm feuert").
func flash_charm(index: int) -> void:
	if index < 0 or index >= current_charms.size():
		return
	var body: Dictionary = _bodies[current_charms[index]]
	var materials: Array = body["materials"]
	var set_flash := func(value: float) -> void:
		for material: ShaderMaterial in materials:
			material.set_shader_parameter("flash", value)
	var holo_tween := create_tween()
	holo_tween.tween_method(set_flash, 0.0, HOLO_FLASH, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	holo_tween.tween_method(set_flash, HOLO_FLASH, 0.0, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	readers[index].flash()
	(body["disk"] as CharmDiskView).flash()
	var model: Node3D = body["model"]
	var scale_tween := create_tween()
	scale_tween.tween_property(model, "scale", Vector3.ONE * 1.22, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(model, "scale", Vector3.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- Treffer ---------------------------------------------------------------

## Belegter Platz unter dem Zeiger: Laufwerk samt Diskette, oder nah am Hologramm.
func charm_index_at_screen_pos(camera: Camera3D, screen_pos: Vector2) -> int:
	var best := -1
	var best_dist := INF
	for i in current_charms.size():
		var rect := readers[i].screen_rect(camera)
		var dist := rect.get_center().distance_to(screen_pos)
		if rect.has_point(screen_pos) and dist < best_dist:
			best_dist = dist
			best = i
	if best >= 0:
		return best
	best_dist = PICK_RADIUS_PX
	for i in charm_nodes.size():
		var world_pos := charm_nodes[i].global_position
		if camera.is_position_behind(world_pos):
			continue
		var dist := camera.unproject_position(world_pos).distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best = i
	return best

## Belegter Platz, dessen AUSWURF-TASTE unter dem Zeiger liegt, oder -1.
func eject_index_at_screen_pos(camera: Camera3D, screen_pos: Vector2) -> int:
	for i in current_charms.size():
		if readers[i].eject_screen_rect(camera).has_point(screen_pos):
			return i
	return -1

## Linsenpunkt des Platzes i (darüber schwebt das Hologramm).
func spot_global_position(i: int) -> Vector3:
	_ensure_readers()
	return readers[i].lens_global_position()

## Displaymitte des Laufwerks i - der Anker der Charm-Kometen.
func display_global_position(i: int) -> Vector3:
	_ensure_readers()
	return readers[i].display_global_position()

## Mitte des Textfelds der Diskette auf Platz i (Anker des Schlüsselwort-Tips).
func text_global_position(i: int) -> Vector3:
	_ensure_readers()
	return readers[i].disk_global_transform() * CharmDiskView.text_center_local()

## Welt-XZ-Grundriß des Laufwerks i samt vorstehender Diskette (zwei Ecken).
func footprint(i: int) -> Array[Vector3]:
	_ensure_readers()
	return readers[i].footprint_world()

## Welt-XZ-Grundriß des Gehäuses an einem Port - auch wo (noch) kein Projektor steht.
func port_body_footprint(port: int) -> Array[Vector3]:
	var at := port_position(port)
	var half := CharmReaderView.SIZE * 0.5
	return [to_global(at + Vector3(half.x, 0.0, -half.z)), to_global(at + Vector3(-half.x, 0.0, half.z))]

func disk_of(index: int) -> CharmDiskView:
	if index < 0 or index >= current_charms.size():
		return null
	return _bodies[current_charms[index]]["disk"]

# --- Hologramm -------------------------------------------------------------

func _holo_position(i: int) -> Vector3:
	return to_local(readers[i].lens_global_position()) + Vector3(0.0, HOVER_HEIGHT, 0.0)

func _holo_for(charm: Charm, i: int) -> Dictionary:
	var pivot := Node3D.new()
	pivot.name = "Hologramm_%s" % charm.id
	add_child(pivot)
	pivot.position = _holo_position(i)
	var to_center := Vector3(-pivot.position.x, 0.0, -pivot.position.z).normalized()
	pivot.basis = Basis.looking_at(to_center, Vector3.UP).scaled(Vector3.ONE * MODEL_SCALE)
	var model := _load_model(charm)
	pivot.add_child(model)
	var materials: Array[ShaderMaterial] = []
	apply_hologram(model, materials)
	var light := SpotLight3D.new()
	light.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	light.light_color = SPOT_LIGHT_COLOR
	light.light_energy = SPOT_LIGHT_ENERGY
	light.light_cull_mask = MODEL_LIGHT_LAYER
	light.spot_range = SPOT_LIGHT_RANGE
	light.spot_angle = SPOT_LIGHT_ANGLE
	light.shadow_enabled = false
	add_child(light)
	var cone := MeshInstance3D.new()
	cone.mesh = _cone_mesh
	var cone_material := StandardMaterial3D.new()
	cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tint := CharmDiskView.rarity_color(charm.rarity)
	tint.a = CONE_ALPHA
	cone_material.albedo_color = tint
	cone.material_override = cone_material
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cone)
	var body := {"pivot": pivot, "model": model, "materials": materials, "light": light,
		"cone": cone, "disk": null}
	_place_light(body, i)
	return body

## Strahler und Kegel stehen fest über ihrer Linse.
func _place_light(body: Dictionary, i: int) -> void:
	var lens := to_local(readers[i].lens_global_position())
	(body["light"] as Node3D).position = lens + Vector3(0.0, SPOT_LIGHT_HEIGHT, 0.0)
	(body["cone"] as Node3D).position = lens + Vector3(0.0, CONE_HEIGHT * 0.5, 0.0)

func _set_holo_visible(charm: Charm, on: bool) -> void:
	var body: Dictionary = _bodies[charm]
	for key in ["pivot", "light", "cone"]:
		(body[key] as Node3D).visible = on

func _ensure_resources() -> void:
	if _cone_mesh != null:
		return
	_cone_mesh = CylinderMesh.new()
	_cone_mesh.bottom_radius = CONE_BOTTOM
	_cone_mesh.top_radius = CONE_TOP
	_cone_mesh.height = CONE_HEIGHT
	_cone_mesh.cap_top = false
	_cone_mesh.cap_bottom = false

## Stülpt jeder Modell-Fläche das Hologramm-Material über, das Originalfarbe und
## -textur übernimmt; out_materials sammelt sie für flash_charm. Die GLB-Ressource
## liegt im geteilten Cache und wird nie angefaßt - der Override liegt DARÜBER.
## STATISCH, weil der Laden dieselben Modelle zeigt.
static func apply_hologram(node: Node, out_materials: Array = []) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.layers |= MODEL_LIGHT_LAYER
		if mesh_instance.material_override is BaseMaterial3D:
			mesh_instance.material_override = _holo_material(
				mesh_instance.material_override, out_materials)
		else:
			var surface_count := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0
			for s in surface_count:
				# Eine Fläche OHNE Material bekommt eine neutrale - sonst schimpft der Renderer.
				var base: BaseMaterial3D = mesh_instance.get_active_material(s) as BaseMaterial3D
				if base == null:
					base = StandardMaterial3D.new()
				mesh_instance.set_surface_override_material(s,
					_holo_material(base, out_materials))
	for child in node.get_children():
		apply_hologram(child, out_materials)

static func _holo_material(source: BaseMaterial3D, out_materials: Array) -> ShaderMaterial:
	var holo := ShaderMaterial.new()
	holo.shader = HOLO_SHADER
	holo.set_shader_parameter("albedo_color", source.albedo_color)
	if source.albedo_texture != null:
		holo.set_shader_parameter("albedo_tex", source.albedo_texture)
		holo.set_shader_parameter("use_texture", true)
	holo.set_shader_parameter("metallic_value", source.metallic)
	holo.set_shader_parameter("roughness_value", source.roughness)
	holo.set_shader_parameter("saturation", HOLO_SATURATION)
	holo.set_shader_parameter("self_glow", HOLO_SELF_GLOW)
	holo.set_shader_parameter("rim_gain", HOLO_RIM)
	holo.set_shader_parameter("band_gain", HOLO_BAND)
	holo.set_shader_parameter("flash", 0.0)  # Ruhestand explizit: ungesetzt liest er null
	out_materials.append(holo)
	return holo

func _load_model(charm: Charm) -> Node3D:
	var path := charm.model_path
	var model: Node3D
	if path == "" or not ResourceLoader.exists(path):
		model = placeholder_model(charm.id)
	else:
		model = model_scene(path).instantiate()
	return model

## Geladene Charm-Modelle bleiben im Prozess liegen: ein GLB kostet KALT ~0,1 s,
## warm 0 ms, und Bibliothek wie Tischkarten bauen ihre Modelle laufend neu auf.
static var _model_scenes := {}   # Pfad -> PackedScene (Cache)
static var _model_requests := {}  # Pfad -> true (Ladeauftrag läuft im Ladethread)
static var _model_queue: Array[String] = []  # angefordert, wartet auf einen freien Platz
static var _model_failures := {}  # Pfad -> true (Laden endgültig fehlgeschlagen)

## Deckel für gleichzeitige Ladeaufträge: die Bibliothek fordert beim Öffnen ALLE
## Charm-Modelle an, und ein blockierendes model_scene() musste sich sonst durch die
## ganze Schlange warten - gemessen 35 s statt 0,2 s für die Charm-Reihe.
const MAX_IN_FLIGHT := 4

## Einzige Ladestelle der Charm-Modelle - CharmThumb greift hier mit ab.
## Blockiert; ein laufender Ladeauftrag wird zu Ende geholt statt doppelt geladen.
## Wer nur in der Schlange steht, wird hier selbst geladen statt abgewartet.
static func model_scene(path: String) -> PackedScene:
	if not _model_scenes.has(path):
		if _model_requests.has(path):
			_model_requests.erase(path)
			_model_scenes[path] = ResourceLoader.load_threaded_get(path) as PackedScene
		else:
			_model_queue.erase(path)
			_model_scenes[path] = load(path) as PackedScene
		_pump_model_queue()
	return _model_scenes[path]

## Läuft ein Platz frei, rückt der nächste Wartende in den Ladethread nach.
static func _pump_model_queue() -> void:
	while not _model_queue.is_empty() and _model_requests.size() < MAX_IN_FLIGHT:
		_start_model_request(_model_queue.pop_front())

static func _start_model_request(path: String) -> void:
	if ResourceLoader.load_threaded_request(path) == OK:
		_model_requests[path] = true
	else:
		_model_failures[path] = true

## Wie viele Modelle gerade wirklich im Ladethread stecken (Diagnose und Test).
static func models_in_flight() -> int:
	return _model_requests.size()

## Wie viele nur auf einen freien Platz warten (Diagnose und Test).
static func models_queued() -> int:
	return _model_queue.size()

static func cached_model_scene(path: String) -> PackedScene:
	return _model_scenes.get(path)

static func model_failed(path: String) -> bool:
	return _model_failures.has(path)

## Der Ladethread läuft nur mit ECHTEM Renderer: die Kopflos-Attrappe führt ihren
## Texturspeicher ohne Sperre, Ladethread und Hauptfaden griffen dort sporadisch
## ins Leere ('Parameter "t" is null' - ein Engine-Fehler, der irgendeinen gerade
## laufenden Test kippt). Kopflos lädt nur noch model_scene(), blockierend.
static var _threaded_loads := DisplayServer.get_name() != "headless"

static func threaded_loads() -> bool:
	return _threaded_loads

## Stößt das Laden im Ladethread an - der Hauptfaden blockiert nie. Über dem
## Deckel wandert der Auftrag in die Schlange statt in den Ladethread.
static func request_model_scene(path: String) -> void:
	if not _threaded_loads:
		return
	if _model_scenes.has(path) or _model_requests.has(path) \
			or _model_failures.has(path) or _model_queue.has(path):
		return
	if _model_requests.size() < MAX_IN_FLIGHT:
		_start_model_request(path)
	else:
		_model_queue.append(path)

## null solange geladen wird; bei Fehlschlag bleibt es null und model_failed steht.
## Jeder Fragende hält die Schlange in Bewegung - sonst stünde sie still, sobald
## das Fenster mit den wartenden Vorschauen geschlossen wird.
static func poll_model_scene(path: String) -> PackedScene:
	if _model_scenes.has(path):
		return _model_scenes[path]
	_pump_model_queue()
	if not _model_requests.has(path):
		return null
	match ResourceLoader.load_threaded_get_status(path):
		ResourceLoader.THREAD_LOAD_LOADED:
			_model_requests.erase(path)
			_model_scenes[path] = ResourceLoader.load_threaded_get(path) as PackedScene
			return _model_scenes[path]
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return null
		_:
			_model_requests.erase(path)
			_model_failures[path] = true
			return null

## Stabile Farbe aus der Charm-id (Hash -> Farbton) - auch die Bibliothek
## nutzt sie, damit Tisch-Karte und Eintrag zusammenfinden.
static func placeholder_color(charm_id: String) -> Color:
	var hue := float(abs(charm_id.hash()) % 360) / 360.0
	return Color.from_hsv(hue, 0.55, 0.85)

## Platzhalter für Charms ohne Modelldatei: flache Karte in stabiler id-Farbe.
static func placeholder_model(charm_id: String) -> Node3D:
	var root := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.14, 1.4)
	mesh_instance.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = placeholder_color(charm_id)
	material.roughness = 0.4
	mesh_instance.material_override = material
	root.add_child(mesh_instance)
	return root

## Mitte des Projektors an Port port (lokal, auf dem Filz).
static func port_position(port: int) -> Vector3:
	var z := (float(port) - float(PORT_COUNT - 1) * 0.5) * LINE_SPACING
	return Vector3(LINE_X, SPOT_Y, z)

## Die Vorderkante der Reihe (lokal x): dort endet der Text der eingelegten Disketten.
static func front_edge_x() -> float:
	return LINE_X + CharmReaderView.LOADED_X - CharmDiskView.SIZE.x * 0.5
