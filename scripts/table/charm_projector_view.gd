class_name CharmProjectorView
extends Node3D
## Der PROJEKTOR eines Charm-Platzes im LADEN (Spieler-Wunsch 2026-11-20, seit dem 2026-11-22 im
## Stil des Stahldecks): eine flache Brücke über dem Schieber der eingelegten Diskette - schwarzer
## Lack, Stahlplatte mit Schale und KLEINEM Hologramm, rechts das Preisfeld, vorn das Display mit
## dem NAMEN. Modell charm_bridge.glb (Licht eingemalt). Ursprung = Mitte der Brücke auf dem
## Tisch, lokal +X = Bild-oben; die Diskette liegt davor (-X) und stellt der Aufrufer.

const MODEL_PATH := "res://assets/models/hardware/charm_bridge.glb"
const S := CharmDiskView.BLENDER_SCALE

const AIR := 0.04
const BACK := 0.12
const CHEEK := 0.2
const UNDER := 0.4
const DECK := 0.38
const DEPTH := CharmDiskView.INSERT_DEPTH + BACK
const WIDTH := CharmDiskView.SIZE.z + (CHEEK + AIR) * 2.0
## Blender-Maße aus tools/blender_projector_baked.py (bruecke): Platte, Schalenmitte, Linse.
const PLATE := 0.012 * S
const TOP := UNDER + DECK + PLATE
const PLATE_DEPTH := DEPTH - 0.125 * S
const DISH_X := DEPTH * 0.5 - 0.012 * S - PLATE_DEPTH * 0.5
const LENS := Vector3(DISH_X, TOP - 0.009 * S, 0.0)
const LENS_RADIUS := 0.05 * S
const GLOW_PARTS := ["Lippe", "Ring", "Umriss"]

## Kleiner als in der Reihe (CharmRowView.MODEL_SCALE 4).
const HOLO_SCALE := 2.6
const HOVER_HEIGHT := 0.35
const CONE_HEIGHT := 1.3
const CONE_ALPHA := 0.07
const BOB_HEIGHT := 0.08
const BOB_SPEED := 1.3
const ROTATION_SPEED := 0.15
const LIGHT_HEIGHT := 6.0
const LIGHT_RANGE := 10.0
const LIGHT_ANGLE := 30.0

const GLOW_REST := 0.62
const GLOW_HOVER := 1.5
const PRICE_Z := 2.25
const PRICE_WIDTH := 1.4
const PRICE_BIGGEST := 72
const PRICE_MUTED := Color(0.5, 0.5, 0.58)
## Der Name steht auf dem Display vorn auf dem Deck.
const NAME_INSET := 0.056 * S
const NAME_WIDTH := WIDTH - 0.08 * S - 0.4
const NAME_BIGGEST := 52
const NAME_ENERGY := 1.15

var charm: Charm
var price_label: Label3D
var name_label: Label3D
var holo: Node3D
var _glow: StandardMaterial3D
var _lens: StandardMaterial3D
var _model: Node3D
var _light: SpotLight3D
var _cone: MeshInstance3D
var _hovered := false
var _projecting := true
var _bob := 0.0

func _ready() -> void:
	if _glow == null:
		_build()

## Welt-Lage der Brücke, wenn Diskette samt Brücke mittig auf dem Weltpunkt liegen sollen.
static func origin_for(center: Vector3) -> Vector3:
	return Vector3(center.x + (CharmDiskView.SIZE.x - CharmDiskView.INSERT_DEPTH) * 0.5, 0.0, center.z)

func _build() -> void:
	_glow = CharmDiskView._unshaded(CharmReaderView.DARK)
	_lens = CharmDiskView._unshaded(CharmReaderView.DARK)
	var scene: PackedScene = load(MODEL_PATH) if ResourceLoader.exists(MODEL_PATH) else null
	if scene != null:
		var shell := scene.instantiate() as Node3D
		shell.name = "Bruecke"
		shell.rotation = Vector3(0.0, -PI * 0.5, 0.0)
		shell.scale = Vector3.ONE * S
		CharmDiskView.dress_shell(shell)
		add_child(shell)
		for part in GLOW_PARTS:
			var mesh := shell.find_child(part, true, false) as MeshInstance3D
			if mesh != null:
				mesh.material_override = _glow
		var lens := shell.find_child("Linse", true, false) as MeshInstance3D
		if lens != null:
			lens.material_override = _lens
		var korpus := shell.find_child("Korpus", true, false) as MeshInstance3D
		if korpus != null and korpus.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR:
			korpus.material_override = CharmReaderView._baked_material()
	else:
		_box("Deck", Vector3(DEPTH, DECK, WIDTH), Vector3(0.0, UNDER + DECK * 0.5, 0.0),
			CharmDiskView.shell_material("Schwarzlack"))
	price_label = Label3D.new()
	price_label.name = "Preis"
	price_label.font = CharmDiskView.disk_font()
	price_label.pixel_size = CharmDiskView.PIXEL
	price_label.shaded = false
	price_label.double_sided = false
	price_label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	price_label.basis = CharmDiskView._flat_basis()
	price_label.position = Vector3(DISH_X, TOP + 0.06, PRICE_Z)
	add_child(price_label)
	name_label = price_label.duplicate() as Label3D
	name_label.name = "Name"
	name_label.position = Vector3(-DEPTH * 0.5 + NAME_INSET, UNDER + DECK + 0.06, 0.0)
	add_child(name_label)
	_refresh()

func _box(part: String, size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_part(part, mesh, at, material)

func _part(part: String, mesh: Mesh, at: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = part
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.layers |= CharmRowView.MODEL_LIGHT_LAYER
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

## Der EINE Schreiber: belegt projiziert er den Charm, leer (verkauft) ist er dunkel.
func set_charm(value: Charm) -> void:
	if _glow == null:
		_build()
	if value == charm:
		return
	charm = value
	_drop_holo()
	if charm != null:
		_build_holo()
	_refresh()

## Das Preisschild auf dem Deck ("" = keines).
func set_price(text: String, muted := false) -> void:
	if _glow == null:
		_build()
	var shown := text if charm != null else ""
	if price_label.text != shown:
		price_label.text = shown
		price_label.font_size = CharmDiskView.fit_line(shown,
			PRICE_WIDTH / CharmDiskView.PIXEL, PRICE_BIGGEST)
	price_label.modulate = PRICE_MUTED if muted else CharmDiskView.TAG_COLOR

func price_text() -> String:
	return price_label.text if price_label != null else ""

## Der Zeiger liegt auf dem Platz: Lippe und Ring leuchten heller.
func set_hovered(on: bool) -> void:
	if on == _hovered:
		return
	_hovered = on
	_refresh()

func glow_color() -> Color:
	return _glow.albedo_color if _glow != null else CharmReaderView.DARK

func name_text() -> String:
	return name_label.text if name_label != null else ""

func _write_name() -> void:
	var title := charm.display_name.to_upper() if charm != null else ""
	name_label.text = title
	name_label.font_size = CharmDiskView.fit_line(title, NAME_WIDTH / CharmDiskView.PIXEL, NAME_BIGGEST)
	if charm != null:
		name_label.modulate = CharmDiskView.energized(CharmDiskView.rarity_color(charm.rarity),
			NAME_ENERGY)

func _refresh() -> void:
	_write_name()
	var lit := charm != null
	var tint := CharmDiskView.rarity_color(charm.rarity) if lit else CharmReaderView.DARK
	_glow.albedo_color = CharmDiskView.energized(tint, GLOW_HOVER if _hovered else GLOW_REST) \
		if lit else CharmReaderView.DARK
	_lens.albedo_color = CharmDiskView.energized(CharmReaderView.LENS_COLOR, 1.4) \
		if lit else CharmReaderView.DARK

func _process(delta: float) -> void:
	if _model == null or not is_instance_valid(_model):
		return
	_bob += delta
	_model.rotate_object_local(Vector3.UP, ROTATION_SPEED * delta)
	_model.position.y = sin(_bob * BOB_SPEED) * BOB_HEIGHT / HOLO_SCALE

func _build_holo() -> void:
	holo = Node3D.new()
	holo.name = "Hologramm"
	add_child(holo)
	holo.position = LENS + Vector3(0.0, HOVER_HEIGHT, 0.0)
	holo.basis = Basis.looking_at(Vector3(-1.0, 0.0, 0.0), Vector3.UP).scaled(Vector3.ONE * HOLO_SCALE)
	var path := charm.model_path
	if path == "" or not ResourceLoader.exists(path):
		_model = CharmRowView.placeholder_model(charm.id)
	else:
		_model = CharmRowView.model_scene(path).instantiate()
	holo.add_child(_model)
	CharmRowView.apply_hologram(_model)
	_light = SpotLight3D.new()
	_light.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_light.light_color = CharmRowView.SPOT_LIGHT_COLOR
	_light.light_energy = CharmRowView.SPOT_LIGHT_ENERGY
	_light.light_cull_mask = CharmRowView.MODEL_LIGHT_LAYER
	_light.spot_range = LIGHT_RANGE
	_light.spot_angle = LIGHT_ANGLE
	_light.shadow_enabled = false
	_light.position = LENS + Vector3(0.0, LIGHT_HEIGHT, 0.0)
	add_child(_light)
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = LENS_RADIUS
	mesh.top_radius = LENS_RADIUS * 1.6
	mesh.height = CONE_HEIGHT
	mesh.cap_top = false
	mesh.cap_bottom = false
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tint := CharmDiskView.rarity_color(charm.rarity)
	tint.a = CONE_ALPHA
	material.albedo_color = tint
	_cone = MeshInstance3D.new()
	_cone.name = "Kegel"
	_cone.mesh = mesh
	_cone.material_override = material
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.position = LENS + Vector3(0.0, CONE_HEIGHT * 0.5, 0.0)
	add_child(_cone)
	_show_holo()

func _drop_holo() -> void:
	for node: Node3D in [holo, _light, _cone]:
		if node != null and is_instance_valid(node):
			# Erst verbergen: ein sichtbar freigegebenes Hologramm fragt den Renderer nach Material.
			node.visible = false
			node.queue_free()
	holo = null
	_model = null
	_light = null
	_cone = null

## Lage der eingelegten Diskette (Ursprung = Mitte ihrer Unterseite), flach auf dem Tisch.
func disk_global_transform() -> Transform3D:
	return global_transform * Transform3D(Basis(), disk_offset())

## Dieselbe Lage relativ zur Brücke.
static func disk_offset() -> Vector3:
	return Vector3(DEPTH * 0.5 - BACK - AIR - CharmDiskView.SIZE.x * 0.5, VitrineView.FLOOR_CLEAR, 0.0)

## Halbe Länge von Brücke samt eingelegter Diskette, längs der Einschub-Achse.
static func assembly_reach() -> float:
	return (CharmDiskView.SIZE.x + BACK) * 0.5 + AIR

## Ob das Hologramm steht: in einem Gehäuse (Schwarzmarkt-Fach) schweigt es, bis es draußen ist.
func set_projecting(on: bool) -> void:
	if on == _projecting:
		return
	_projecting = on
	_show_holo()

func projecting() -> bool:
	return _projecting and holo != null and holo.visible

func _show_holo() -> void:
	for node: Node3D in [holo, _light, _cone]:
		if node != null and is_instance_valid(node):
			node.visible = _projecting

## Vor dem Schlitz: dorthin gleitet sie beim Kauf, ehe sie abfliegt.
func mouth_global_transform() -> Transform3D:
	var out := disk_global_transform()
	out.origin -= global_basis.x.normalized() * (CharmDiskView.INSERT_DEPTH + AIR)
	return out
