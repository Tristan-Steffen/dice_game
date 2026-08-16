class_name CharmRowView
extends Node3D
## Zeigt die besessenen Charms als Hologramme auf dem Tisch: sechs feste
## Plätze in einer Reihe am hinteren Tischrand, Reihenfolge = Besitz-
## Reihenfolge. set_charms() baut bei jeder Änderung neu auf; zusätzlich löst
## der Knoten den Hover/Drag der Grubenansicht auf (charm_*_at_screen_pos).

const LINE_X := 31.0  # Abstand der Reihe vom Grubenzentrum (+X = Bildschirm-oben)
const LINE_SPACING := 9.0
const SPOT_Y := 0.0  # Tischoberfläche
const MODEL_SCALE := 4.0

## Anzahl fester Plätze; die Obergrenze besitzbarer Charms führt GameRun, damit
## Laden und Tisch nie auseinanderlaufen.
const SPOT_COUNT := GameRun.CHARM_CAPACITY

## Hologramm-Look: Modell bekommt den Hologramm-Shader, aus der Tischfläche
## steigt je Charm ein Lichtzylinder auf.
const HOLOGRAM_SHADER := preload("res://assets/shaders/charm_hologram.gdshader")
const BEAM_SHADER := preload("res://assets/shaders/hologram_beam.gdshader")
const BEAM_RADIUS := 3.6
const BEAM_HEIGHT := 9.0

## Hover-Toleranz um die projizierte Charm-Mitte - die Charms liegen in der
## Grubenansicht klein am oberen Bildrand, daher großzügig.
const PICK_RADIUS_PX := 70.0

## Placement-Pivots (je Charm): tragen Platz-Transform und werden beim Drag
## bewegt; das Modell darin dreht sich dauerhaft - so kollidiert die Rotation
## nie mit Drag/Gleiten.
var charm_nodes: Array[Node3D] = []
var charm_models: Array[Node3D] = []
var current_charms: Array[Charm] = []
var beam_nodes: Array[MeshInstance3D] = []
var charm_materials: Array = []  # je Charm die Hologramm-Materialien (für flash_charm)

const ROTATION_SPEED := 0.15  # rad/s, ruhiger Spin - die Silhouette bleibt lesbar

## Geteilte Beam-Ressourcen: EIN Material je Rarität (Kegel schimmert in der
## Raritätsfarbe); der Hologramm-Shader wird je Fläche instanziiert.
var _beam_materials: Dictionary = {}  # Rarität -> ShaderMaterial
var _beam_mesh: CylinderMesh

## Wie stark die Raritätsfarbe in den Kegel mischt (dezent - der Kegel soll
## weiter als Lichtprojektion lesen, nicht jeden Charm gleich einfärben).
const BEAM_RARITY_MIX := 0.35

## Baut die Charm-Modelle neu: je Charm ein Modell auf dem nächsten Platz;
## mehr Charms als Plätze werden abgeschnitten.
func set_charms(charms: Array[Charm]) -> void:
	_ensure_holo_resources()
	for node in charm_nodes:
		node.queue_free()
	charm_nodes.clear()
	charm_models.clear()
	for beam in beam_nodes:
		beam.queue_free()
	beam_nodes.clear()
	current_charms = []
	charm_materials.clear()
	var count := mini(charms.size(), SPOT_COUNT)
	for i in count:
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.transform = _spot_transform(i)
		var model := _load_model(charms[i])
		pivot.add_child(model)
		var materials: Array[ShaderMaterial] = []
		_apply_hologram(model, materials)
		charm_nodes.append(pivot)
		charm_models.append(model)
		current_charms.append(charms[i])
		charm_materials.append(materials)
		_add_beam(i)

func _process(delta: float) -> void:
	for model in charm_models:
		model.rotate_object_local(Vector3.UP, ROTATION_SPEED * delta)

func _ensure_holo_resources() -> void:
	if _beam_mesh != null:
		return
	_beam_mesh = CylinderMesh.new()
	_beam_mesh.top_radius = BEAM_RADIUS
	_beam_mesh.bottom_radius = BEAM_RADIUS
	_beam_mesh.height = BEAM_HEIGHT
	_beam_mesh.radial_segments = 24

## Kegel-Material einer Rarität: Shader-Grundton, dezent Richtung
## Raritätsfarbe gemischt - einmal gebaut, dann wiederverwendet.
func _beam_material_for(rarity: String) -> ShaderMaterial:
	if _beam_materials.has(rarity):
		return _beam_materials[rarity]
	var material := ShaderMaterial.new()
	material.shader = BEAM_SHADER
	material.set_shader_parameter("bottom_y", SPOT_Y)
	material.set_shader_parameter("top_y", SPOT_Y + BEAM_HEIGHT)
	var base_color := Color(0.3, 0.68, 1.0)  # beam_color-Default des Shaders
	var rarity_color: Color = Charm.RARITY_COLORS.get(rarity, Charm.RARITY_COLORS[Charm.RARITY_COMMON])
	var tinted := base_color.lerp(rarity_color, BEAM_RARITY_MIX)
	material.set_shader_parameter("beam_color", Vector3(tinted.r, tinted.g, tinted.b))
	_beam_materials[rarity] = material
	return material

## Stülpt je Fläche ein Hologramm-Material über, das die Originalfarbe
## (Textur + albedo_color) übernimmt; out_materials sammelt sie für flash_charm.
func _apply_hologram(node: Node, out_materials: Array[ShaderMaterial]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var surface_count := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0
		# Originalmaterialien zuerst lesen und den Voll-Override lösen, damit
		# die Flächen-Hologramme greifen.
		var originals: Array = []
		for s in surface_count:
			originals.append(mesh_instance.get_active_material(s))
		mesh_instance.material_override = null
		for s in surface_count:
			var material := ShaderMaterial.new()
			material.shader = HOLOGRAM_SHADER
			if originals[s] is BaseMaterial3D:
				var base := originals[s] as BaseMaterial3D
				material.set_shader_parameter("albedo_color", base.albedo_color)
				if base.albedo_texture != null:
					material.set_shader_parameter("albedo_tex", base.albedo_texture)
					material.set_shader_parameter("use_texture", true)
			mesh_instance.set_surface_override_material(s, material)
			out_materials.append(material)
	for child in node.get_children():
		_apply_hologram(child, out_materials)

## Lässt den Charm auf Platz index kurz aufblitzen ("dieser Charm feuert"):
## Helligkeits-Puls über den flash-Parameter plus kleiner Größen-Pop.
func flash_charm(index: int) -> void:
	if index < 0 or index >= charm_models.size():
		return
	var materials: Array = charm_materials[index]
	var set_flash := func(value: float) -> void:
		for material: ShaderMaterial in materials:
			material.set_shader_parameter("flash", value)
	var flash_tween := create_tween()
	flash_tween.tween_method(set_flash, 0.0, 1.0, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash_tween.tween_method(set_flash, 1.0, 0.0, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var model := charm_models[index]
	var scale_tween := create_tween()
	scale_tween.tween_property(model, "scale", Vector3.ONE * 1.22, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(model, "scale", Vector3.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _add_beam(i: int) -> void:
	var beam := MeshInstance3D.new()
	beam.mesh = _beam_mesh
	beam.material_override = _beam_material_for(current_charms[i].rarity)
	var spot := _spot_position(i)
	beam.position = Vector3(spot.x, SPOT_Y + BEAM_HEIGHT * 0.5, spot.z)
	add_child(beam)
	beam_nodes.append(beam)

## Charm-Index (Position in current_charms = Besitz-Reihenfolge), dessen Modell
## screen_pos am nächsten liegt (innerhalb PICK_RADIUS_PX), oder -1.
## Projektions-Nähe statt Physik-Raycast - die GLB-Modelle bringen keine
## verlässlichen Kollider mit.
func charm_index_at_screen_pos(camera: Camera3D, screen_pos: Vector2) -> int:
	var best := -1
	var best_dist := PICK_RADIUS_PX
	for i in charm_nodes.size():
		var world_pos := charm_nodes[i].global_position
		if camera.is_position_behind(world_pos):
			continue
		var dist := camera.unproject_position(world_pos).distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best = i
	return best

## Globale Position des festen Platzes i (Drop-Ziel/Rückgleit-Anker).
func spot_global_position(i: int) -> Vector3:
	return to_global(_spot_transform(i).origin)

func _load_model(charm: Charm) -> Node3D:
	var path := charm.model_path
	var model: Node3D
	if path == "" or not ResourceLoader.exists(path):
		model = placeholder_model(charm.id)
	else:
		model = model_scene(path).instantiate()
	return model

## Geladene Charm-Modelle bleiben im Prozess liegen: ein GLB kostet KALT ~0,8 s,
## warm 0 ms, und Bibliothek wie Tischkarten bauen ihre Modelle laufend neu auf.
static var _model_scenes := {}   # Pfad -> PackedScene (Cache)
static var _model_requests := {}  # Pfad -> true (Ladeauftrag läuft im Ladethread)
static var _model_failures := {}  # Pfad -> true (Laden endgültig fehlgeschlagen)

## Einzige Ladestelle der Charm-Modelle - CharmThumb greift hier mit ab.
## Blockiert; ein laufender Ladeauftrag wird zu Ende geholt statt doppelt geladen.
static func model_scene(path: String) -> PackedScene:
	if not _model_scenes.has(path):
		if _model_requests.has(path):
			_model_requests.erase(path)
			_model_scenes[path] = ResourceLoader.load_threaded_get(path) as PackedScene
		else:
			_model_scenes[path] = load(path) as PackedScene
	return _model_scenes[path]

static func cached_model_scene(path: String) -> PackedScene:
	return _model_scenes.get(path)

static func model_failed(path: String) -> bool:
	return _model_failures.has(path)

## Stößt das Laden im Ladethread an - der Hauptfaden blockiert nie.
static func request_model_scene(path: String) -> void:
	if _model_scenes.has(path) or _model_requests.has(path) or _model_failures.has(path):
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		_model_requests[path] = true
	else:
		_model_failures[path] = true

## null solange geladen wird; bei Fehlschlag bleibt es null und model_failed steht.
static func poll_model_scene(path: String) -> PackedScene:
	if _model_scenes.has(path):
		return _model_scenes[path]
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

func _spot_position(i: int) -> Vector3:
	var z := (float(i) - float(SPOT_COUNT - 1) * 0.5) * LINE_SPACING
	return Vector3(LINE_X, SPOT_Y, z)

## Transform des Platzes i: auf der Tischfläche, zur Mitte gedreht.
func _spot_transform(i: int) -> Transform3D:
	var pos := _spot_position(i)
	var to_center := Vector3(-pos.x, 0.0, -pos.z).normalized()
	var basis := Basis.looking_at(to_center, Vector3.UP).scaled(Vector3.ONE * MODEL_SCALE)
	return Transform3D(basis, pos)
