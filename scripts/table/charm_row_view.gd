class_name CharmRowView
extends Node3D
## Zeigt die besessenen Charms als HOLOGRAMME auf dem Tisch (zweite Fassung,
## Spieler-Entscheid 2026-09-09: der Vitrinen-Sockel ist gestorben, die Charms
## sollen wieder als echte Hologramme lesen): sechs feste Plätze in einer Reihe
## am hinteren Tischrand, Reihenfolge = Besitz-Reihenfolge. Je Platz liegt ein
## flacher EMITTER-RING in der Raritätsfarbe auf dem Filz, darüber schwebt die
## Lichtgestalt des Modells (charm_hologram.gdshader). set_charms() baut bei
## jeder Änderung neu auf; zusätzlich löst der Knoten den Hover/Drag der
## Grubenansicht auf (charm_*_at_screen_pos).

const LINE_X := 31.0  # Abstand der Reihe vom Grubenzentrum (+X = Bildschirm-oben)
const LINE_SPACING := 9.0
const SPOT_Y := 0.0  # Tischoberfläche
const MODEL_SCALE := 4.0
## Das Hologramm schwebt über seinem Emitter - eine Projektion steht nicht auf.
const HOVER_HEIGHT := 0.6

## Anzahl fester Plätze; die Obergrenze besitzbarer Charms führt GameRun, damit
## Laden und Tisch nie auseinanderlaufen.
const SPOT_COUNT := GameRun.CHARM_CAPACITY

## Der EMITTER: ein flacher Ring (Torus) auf dem Filz. Sein Radius trägt zugleich
## den Sockelring der 2D-Konsole (scene_root meldet ihn als Blenden-Radius ans
## Charm-Dock) - dieselbe Zahl wie der alte Beam- und Sockelradius.
const EMITTER_RADIUS := 3.6
const RING_HEIGHT := 0.16

## Emitter-Licht: die Ruhe-Energie bleibt unter der Bloom-Schwelle (0,95 mal dem
## stärksten Kanal jeder Raritätsfarbe), der Puls des Feuerns geht deutlich darüber.
## 0,62 statt 0,88 ist GEMESSEN: dicht unter der Schwelle stand der Ring schon in
## Ruhe fast weiß, und der Puls war im Bild nicht zu unterscheiden.
const RING_REST_ENERGY := 0.62
const RING_FLASH_ENERGY := 2.2

## Der Hologramm-Look (`charm_hologram.gdshader`): additiv und durchscheinend,
## aber in GESÄTTIGTEN Modellfarben (der Tisch ist dunkel und blau-ambient, roh
## lasen die Charms ausgegraut); der Saum trägt das kühle Blau, breite Bänder
## steigen langsam, kein Flackern.
const HOLO_SHADER := preload("res://assets/shaders/charm_hologram.gdshader")
const HOLO_SATURATION := 1.6
const HOLO_BRIGHTNESS := 1.25
const HOLO_ALPHA := 0.6
const HOLO_RIM := 0.9
const HOLO_BAND_MIN := 0.7
const HOLO_TINT_MIX := 0.12
const HOLO_FLASH := 1.0

## Hover-Toleranz um die projizierte Charm-Mitte - die Charms liegen in der
## Grubenansicht klein am oberen Bildrand, daher großzügig.
const PICK_RADIUS_PX := 70.0

## Placement-Pivots (je Charm): tragen Platz-Transform und werden beim Drag
## bewegt; das Modell darin dreht sich dauerhaft - so kollidiert die Rotation
## nie mit Drag/Gleiten.
var charm_nodes: Array[Node3D] = []
var charm_models: Array[Node3D] = []
var current_charms: Array[Charm] = []

## Emitter-Ringe je besetztem Platz, index-parallel zu charm_nodes.
var ring_nodes: Array[MeshInstance3D] = []
## Je Platz eine EIGENE Ring-Instanz - geteilt blitzten sonst alle Emitter
## derselben Rarität mit.
var ring_materials: Array[StandardMaterial3D] = []
## Je Platz die Hologramm-Materialien (ein Array je Platz) - sie blitzen mit.
var charm_materials: Array = []

const ROTATION_SPEED := 0.15  # rad/s, ruhiger Spin - die Silhouette bleibt lesbar

## Geteilte Ressourcen: EIN Ring-Material je Rarität als Vorlage, aus der jeder
## Platz seine Instanz zieht.
var _ring_materials: Dictionary = {}  # Rarität -> StandardMaterial3D
var _ring_mesh: TorusMesh

## Baut die Hologramme neu: je Charm eines auf dem nächsten Platz; mehr Charms
## als Plätze werden abgeschnitten.
func set_charms(charms: Array[Charm]) -> void:
	_ensure_resources()
	for node in charm_nodes:
		node.queue_free()
	charm_nodes.clear()
	charm_models.clear()
	for body in ring_nodes:
		body.queue_free()
	ring_nodes.clear()
	ring_materials.clear()
	charm_materials.clear()
	current_charms = []
	var count := mini(charms.size(), SPOT_COUNT)
	for i in count:
		current_charms.append(charms[i])
		_build_spot(i)

func _process(delta: float) -> void:
	for model in charm_models:
		model.rotate_object_local(Vector3.UP, ROTATION_SPEED * delta)

## Emitter-Ring und Hologramm des Platzes i.
func _build_spot(i: int) -> void:
	var spot := _spot_position(i)
	var charm := current_charms[i]

	var ring_material: StandardMaterial3D = _ring_material_for(charm.rarity).duplicate()
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.material_override = ring_material
	ring.position = spot + Vector3(0.0, RING_HEIGHT * 0.5, 0.0)  # flach auf dem Filz
	add_child(ring)
	ring_nodes.append(ring)
	ring_materials.append(ring_material)

	var pivot := Node3D.new()
	add_child(pivot)
	pivot.transform = _spot_transform(i)
	var model := _load_model(charm)
	pivot.add_child(model)
	var materials: Array[ShaderMaterial] = []
	apply_hologram(model, materials)
	charm_nodes.append(pivot)
	charm_models.append(model)
	charm_materials.append(materials)

func _ensure_resources() -> void:
	if _ring_mesh != null:
		return
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = EMITTER_RADIUS - RING_HEIGHT * 0.5
	_ring_mesh.outer_radius = EMITTER_RADIUS + RING_HEIGHT * 0.5
	_ring_mesh.rings = 32
	_ring_mesh.ring_segments = 8

## Ring-Vorlage einer Rarität: unshaded in der Raritätsfarbe, Ruhe-Energie unter
## der Bloom-Schwelle - einmal gebaut, je Platz dupliziert.
func _ring_material_for(rarity: String) -> StandardMaterial3D:
	if _ring_materials.has(rarity):
		return _ring_materials[rarity]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = ring_color(rarity, RING_REST_ENERGY)
	_ring_materials[rarity] = material
	return material

## Emitter-Farbe: Raritätsfarbe mal Energie, Alpha bleibt voll.
static func ring_color(rarity: String, energy: float) -> Color:
	var tint: Color = Charm.RARITY_COLORS.get(rarity, Charm.RARITY_COLORS[Charm.RARITY_COMMON])
	return Color(tint.r * energy, tint.g * energy, tint.b * energy)

## Stülpt jeder Modell-Fläche das Hologramm-Material über, das Originalfarbe und
## -textur übernimmt; out_materials sammelt sie für flash_charm. Die GLB-Ressource
## liegt im geteilten Cache und wird nie angefaßt - der Override liegt DARÜBER.
## STATISCH, weil der Laden dieselben Modelle zeigt und zwei Rezepte für einen
## Look auseinanderliefen.
static func apply_hologram(node: Node, out_materials: Array = []) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.material_override is BaseMaterial3D:
			mesh_instance.material_override = _holo_material(
				mesh_instance.material_override, out_materials)
		else:
			var surface_count := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0
			for s in surface_count:
				# Eine Fläche OHNE Material bekommt eine neutrale - sonst rendert
				# der Renderer sie mit einem Null-Material und schimpft je Bild.
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
	holo.set_shader_parameter("saturation", HOLO_SATURATION)
	holo.set_shader_parameter("brightness", HOLO_BRIGHTNESS)
	holo.set_shader_parameter("base_alpha", HOLO_ALPHA)
	holo.set_shader_parameter("rim_gain", HOLO_RIM)
	holo.set_shader_parameter("band_min", HOLO_BAND_MIN)
	holo.set_shader_parameter("tint_mix", HOLO_TINT_MIX)
	holo.set_shader_parameter("flash", 0.0)  # Ruhestand explizit: ungesetzt liest er null
	out_materials.append(holo)
	return holo

## Lässt das Hologramm auf Platz index kurz aufblitzen ("dieser Charm feuert"):
## der Emitter pulst über die Bloom-Schwelle, die Lichtgestalt zieht mit und poppt.
func flash_charm(index: int) -> void:
	if index < 0 or index >= charm_models.size():
		return
	var materials: Array = charm_materials[index]
	var set_flash := func(value: float) -> void:
		for material: ShaderMaterial in materials:
			material.set_shader_parameter("flash", value)
	var holo_tween := create_tween()
	holo_tween.tween_method(set_flash, 0.0, HOLO_FLASH, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	holo_tween.tween_method(set_flash, HOLO_FLASH, 0.0, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var material := ring_materials[index]
	var rarity := current_charms[index].rarity
	var set_energy := func(value: float) -> void:
		material.albedo_color = ring_color(rarity, value)
	var ring_tween := create_tween()
	ring_tween.tween_method(set_energy, RING_REST_ENERGY, RING_FLASH_ENERGY, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_method(set_energy, RING_FLASH_ENERGY, RING_REST_ENERGY, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var model := charm_models[index]
	var scale_tween := create_tween()
	scale_tween.tween_property(model, "scale", Vector3.ONE * 1.22, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(model, "scale", Vector3.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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

## Globale Position des festen Platzes i auf der Tischfläche (Drop-Ziel,
## Rückgleit-Anker und Mitte des 2D-Sockelrings).
func spot_global_position(i: int) -> Vector3:
	return to_global(_spot_position(i))

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

## Stößt das Laden im Ladethread an - der Hauptfaden blockiert nie. Über dem
## Deckel wandert der Auftrag in die Schlange statt in den Ladethread.
static func request_model_scene(path: String) -> void:
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

func _spot_position(i: int) -> Vector3:
	var z := (float(i) - float(SPOT_COUNT - 1) * 0.5) * LINE_SPACING
	return Vector3(LINE_X, SPOT_Y, z)

## Transform des Platzes i: schwebend über dem Emitter, zur Mitte gedreht.
func _spot_transform(i: int) -> Transform3D:
	var pos := _spot_position(i) + Vector3(0.0, HOVER_HEIGHT, 0.0)
	var to_center := Vector3(-pos.x, 0.0, -pos.z).normalized()
	var basis := Basis.looking_at(to_center, Vector3.UP).scaled(Vector3.ONE * MODEL_SCALE)
	return Transform3D(basis, pos)
