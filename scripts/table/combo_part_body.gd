class_name ComboPartBody
extends Node3D
## Ein MODUL als Körper: jedes hat sein eigenes Modell (part_<id>.glb aus
## tools/blender_part_models.py), dieselben Außenmaße und denselben Goldstecker; ohne
## eigenes Modell bleibt das Grundgehäuse (part_module.glb) mit seinem FENSTER. Die
## Tönung nennt die Modulart, die Plattform die Seltenheit. Die Erweiterungsplatine (part_riser.glb) ist dasselbe Gehäuse mit
## demselben Stecker und trägt oben ZWEI Buchsen. Ursprung = Gehäuse-Unterseite.
## EINE Größe überall (Bucht, Schwarzmarkt, Steckplatz, Geist): SIDE in Welt.

const MODULE_SCENE := "res://assets/models/hardware/part_module.glb"
const RISER_SCENE := "res://assets/models/hardware/part_riser.glb"
const SOCKET_SCENE := "res://assets/models/hardware/part_socket.glb"
const OWN_MODEL := "res://assets/models/hardware/part_%s.glb"
## Die Plattform ist Stahl mit einem Hauch Seltenheit - sie soll den Aufbau tragen, nicht überstrahlen.
const PLATE_STEEL := Color(0.46, 0.48, 0.53)
const PLATE_RARITY_SHARE := 0.32

## Die Maße spiegeln tools/blender_combo_hardware.py - wer sie ändert, baut dort neu.
const SIDE := 0.8
const HEIGHT := 0.32
## So tief sinkt das Gehäuse in seine Buchse; darüber ragt HEIGHT - WELL.
const WELL := 0.19
const CLEARANCE := 0.014
const WALL := 0.02
const FLOOR := 0.11
const MOUTH := SIDE + 2.0 * CLEARANCE
const OUTER := MOUTH + 2.0 * WALL
## Die Platine liegt QUER zur Chip-Reihe (+Z, zum Frontband) und um RISER_SHIFT
## nach vorn gerückt - so bleibt die Reihe frei und die Platine ganz im Chip.
const RISER_PITCH := OUTER + 0.006
const RISER_SHIFT := 0.17
const RISER_DEPTH := OUTER + 0.02
const RISER_WIDTH := RISER_PITCH + OUTER + 0.02
const RISER_THICK := WELL + FLOOR + 0.012
const RISER_TOP := HEIGHT + RISER_THICK

const WINDOW_ENERGY := 1.6
const TRACE_ENERGY := 0.9
const DIM_ENERGY := 0.12
const DIM_ALBEDO := Color(0.16, 0.17, 0.2)
const HOUSING_ALBEDO := Color(0.1, 0.1, 0.13)
const HOUSING_EMISSION := 0.08
const GOLD_ALBEDO := Color(1.0, 0.78, 0.36)
const GOLD_EMISSION := 0.35
## Wertungs-Blitz: Leuchten und Größe springen an und klingen ab.
const FLASH_ENERGY := 4.0
const FLASH_POP := 0.35
const FLASH_TIME := 0.45

static var _scenes: Dictionary = {}

var part: ComboPart
var _dimmed := false
var _lit: StandardMaterial3D
var _plate: StandardMaterial3D
var _flash := 0.0
var _flash_tween: Tween

static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]

## Das eigene Modell des Teils (tools/blender_part_models.py), sonst das Grundgehäuse.
static func model_path(p_part: ComboPart) -> String:
	if is_riser(p_part):
		return RISER_SCENE
	if p_part != null:
		var own := OWN_MODEL % p_part.id
		if ResourceLoader.exists(own):
			return own
	return MODULE_SCENE

## Ein Teil ist eine Platine, wenn es Steckplätze trägt.
static func is_riser(p_part: ComboPart) -> bool:
	return p_part != null and p_part.id == ComboPart.EXPANSION_BOARD

## Wo die zwei Buchsen der Platine sitzen, relativ zu ihrem Ursprung.
static func riser_sockets() -> Array[Vector3]:
	return [Vector3(0.0, RISER_TOP, RISER_SHIFT - RISER_PITCH * 0.5),
		Vector3(0.0, RISER_TOP, RISER_SHIFT + RISER_PITCH * 0.5)]

## Die vier oberen Ecken der Platine, relativ zum Ursprung (ihr Fußabdruck).
static func riser_corners() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			out.append(Vector3(sx * RISER_DEPTH * 0.5, RISER_TOP, RISER_SHIFT + sz * RISER_WIDTH * 0.5))
	return out

func setup(p_part: ComboPart) -> void:
	part = p_part
	for child in get_children():
		child.queue_free()
	_lit = StandardMaterial3D.new()
	_lit.emission_enabled = true
	_lit.roughness = 0.3
	var inst := _scene(model_path(part)).instantiate() as Node3D
	inst.name = "Model"
	add_child(inst)
	_skin(inst, "Gehaeuse", _flat(HOUSING_ALBEDO, HOUSING_EMISSION))
	_skin(inst, "Stecker", _flat(GOLD_ALBEDO, GOLD_EMISSION, 0.7))
	_skin(inst, "Platine", _flat(Color(0.05, 0.09, 0.08), 0.06))
	_skin(inst, "Fenster", _lit)
	_skin(inst, "Bahnen", _lit)
	_skin(inst, "Licht", _lit)
	_apply_baked(inst)
	_apply()

## Höhe des Körpers über seinem Fuß.
func height() -> float:
	return RISER_TOP if is_riser(part) else HEIGHT

## Hitzestau: das Teil ist für die Runde still - stumpf statt leuchtend.
func set_dimmed(on: bool) -> void:
	if _dimmed == on:
		return
	_dimmed = on
	_apply()

func dimmed() -> bool:
	return _dimmed

## Das Teil feuert in der Wertung; strength 1 = ein Schritt, mehr = Krit-Schlag.
func flash(strength := 1.0) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, strength, 0.0, FLASH_TIME * maxf(strength, 1.0))

func flash_level() -> float:
	return _flash

func _set_flash(value: float) -> void:
	_flash = value
	scale = Vector3.ONE * (1.0 + FLASH_POP * value)
	_apply()

func _apply() -> void:
	if _lit == null:
		return
	var tint := part.tint() if part != null else ComboPart.BOARD_TINT
	var base := TRACE_ENERGY if is_riser(part) else WINDOW_ENERGY
	_lit.albedo_color = DIM_ALBEDO if _dimmed else tint.darkened(0.2)
	_lit.emission = tint
	_lit.emission_energy_multiplier = (DIM_ENERGY if _dimmed else base) + FLASH_ENERGY * _flash
	if _plate != null:
		var rarity := part.rarity_color() if part != null else Color.WHITE
		_plate.albedo_color = DIM_ALBEDO if _dimmed else PLATE_STEEL.lerp(rarity, PLATE_RARITY_SHARE)

## Modelle mit eingemaltem Licht (Vertexfarben): der Tisch ist zu dunkel, um Metall zu tragen.
## Die Plattform multipliziert darauf die Seltenheitsfarbe.
func _apply_baked(inst: Node3D) -> void:
	var korpus := inst.find_child("Korpus", true, false) as MeshInstance3D
	if korpus == null or not (korpus.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR):
		return
	korpus.material_override = _baked(false)
	var glass := inst.find_child("Glas", true, false) as MeshInstance3D
	if glass != null:
		glass.material_override = _baked(true)
	_plate = _baked(false)
	_skin(inst, "Plattform", _plate)

func _baked(transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _skin(inst: Node3D, node_name: String, material: Material) -> void:
	var mesh := inst.find_child(node_name, true, false) as MeshInstance3D
	if mesh != null:
		mesh.material_override = material

func _flat(albedo: Color, emission: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = metallic
	material.roughness = 0.45
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = albedo
		material.emission_energy_multiplier = emission
	return material
