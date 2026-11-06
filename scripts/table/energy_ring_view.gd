class_name EnergyRingView
extends Node3D
## Der Energie-Ring: der physische ⚡-Speicher im freien Chip-Platz. Ein Segment
## ist eine Energie: außen die ersten 25, innen die nächsten bis zum Limit, je in
## Fünfergruppen. In der Mitte steht die Zahl. Liegt flach, weil der Tisch fast
## senkrecht von oben gesehen wird; nur Emission, keine Lichter (TableGround: 16).

const SEGMENTS := GameRun.ENERGY_CAP_LIMIT
const RING_SEGMENTS := SEGMENTS / 2
const GROUP_SIZE := 5
const GROUP_GAP_DEG := 5.0
const SEGMENT_GAP_DEG := 1.4
const SEGMENT_STEPS := 4
const SEGMENT_HEIGHT := 0.05

const BASE_RADIUS := 1.06
const BASE_HEIGHT := 0.06
const OUTER_RING := Vector2(0.81, 0.99)  # innen, außen
const INNER_RING := Vector2(0.62, 0.77)
const CORE_RADIUS := 0.58
const CORE_HEIGHT := 0.07

const BASE_ALBEDO := Color(0.09, 0.10, 0.14)
const CORE_ALBEDO := Color(0.02, 0.03, 0.05)
const LOCKED_ALBEDO := Color(0.05, 0.06, 0.08)
const LOCKED_EMISSION := Color(0.03, 0.05, 0.06)
const EMPTY_ALBEDO := Color(0.06, 0.09, 0.13)
const EMPTY_EMISSION := Color(0.16, 0.40, 0.46)
const EMPTY_ENERGY := 1.6
## Unter der Bloom-Schwelle, damit Nachbarn nicht zu einem Balken verschmelzen.
const LIT_SHARE := 0.6
const LIT_BREATH := 0.12
const FLASH_GAIN := 0.9
const FLASH_TIME := 0.35
const CORE_ENERGY_EMPTY := 0.02
const CORE_ENERGY_FULL := 0.14
const CORE_ENERGY_RESTLESS := 0.2
const SWEEP_TIME := 0.7
const SWEEP_WIDTH := 1.5

const NUMBER_FONT := 96
const CAP_FONT := 44
const LABEL_PIXEL := 0.0058
const NUMBER_Y := 0.13
const CAP_Y := -0.3
const NUMBER_COLOR := Color(1.3, 1.3, 1.25)
const CAP_COLOR := Color(0.7, 1.1, 1.2)

var _energy := 0
var _cap := 0
var _segments: Array[MeshInstance3D] = []
var _empty_material: StandardMaterial3D
var _locked_material: StandardMaterial3D
var _sweep_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _lit_materials := {}
var _flashes := {}
var _number: Label3D
var _cap_label: Label3D
var _time := 0.0
var _sweep := -1.0
var _pulse_tween: Tween
var _rest_scale := Vector3.ONE

func _ready() -> void:
	_build()
	_apply()

## Einziger Eingang: scene_root spiegelt GameRun.energy/energy_cap hierher.
func set_energy(energy: int, cap: int) -> void:
	var new_cap := clampi(cap, 0, SEGMENTS)
	var new_energy := clampi(energy, 0, new_cap)
	for i in range(_energy, new_energy):
		_flashes[i] = 1.0
	var grew := _cap > 0 and new_cap > _cap
	_cap = new_cap
	_energy = new_energy
	if _segments.is_empty():
		return
	if grew:
		_sweep = 0.0
	_apply()

## Kurzer elastischer Pop - eine Energie ist eben eingetroffen.
func pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	else:
		_rest_scale = scale
	scale = _rest_scale * 1.08
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", _rest_scale, 0.35)

func energy_count() -> int:
	return _energy

func cap_count() -> int:
	return _cap

func number_text() -> String:
	return _number.text if _number != null else ""

func cap_text() -> String:
	return _cap_label.text if _cap_label != null else ""

func segment(index: int) -> MeshInstance3D:
	return _segments[index]

func sweeping() -> bool:
	return _sweep >= 0.0

## Durchmesser in eigenen Einheiten - der Aufrufer skaliert den Ring in den Platz.
static func diameter() -> float:
	return BASE_RADIUS * 2.0

## Uhrzeigersinn ab Bild-oben, in Grad: Mitte des Segments i innerhalb seines Rings.
static func segment_angle_deg(ring_index: int) -> float:
	var group_span := 360.0 * float(GROUP_SIZE) / float(RING_SEGMENTS)
	var span := _segment_span_deg()
	@warning_ignore("integer_division")
	var group := ring_index / GROUP_SIZE
	var slot := ring_index % GROUP_SIZE
	return float(group) * group_span + GROUP_GAP_DEG * 0.5 + span * 0.5 \
		+ float(slot) * (span + SEGMENT_GAP_DEG)

static func _segment_span_deg() -> float:
	var group_span := 360.0 * float(GROUP_SIZE) / float(RING_SEGMENTS)
	return (group_span - GROUP_GAP_DEG - SEGMENT_GAP_DEG * float(GROUP_SIZE - 1)) / float(GROUP_SIZE)

func _build() -> void:
	_build_materials()
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = BASE_ALBEDO
	base_material.metallic = 0.7
	base_material.roughness = 0.35
	_add_disc("Base", BASE_RADIUS, BASE_HEIGHT, base_material)
	_add_disc("Core", CORE_RADIUS, CORE_HEIGHT, _core_material)
	var outer := _segment_mesh(OUTER_RING)
	var inner := _segment_mesh(INNER_RING)
	for i in SEGMENTS:
		var seg := MeshInstance3D.new()
		seg.name = "Segment%d" % i
		seg.mesh = outer if i < RING_SEGMENTS else inner
		seg.position.y = BASE_HEIGHT
		# Bild-oben ist +X; eine positive Drehung um Y liefe gegen den Uhrzeigersinn.
		seg.rotation.y = -deg_to_rad(segment_angle_deg(i % RING_SEGMENTS))
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(seg)
		_segments.append(seg)
	_number = _add_label("Number", NUMBER_FONT, NUMBER_Y, NUMBER_COLOR)
	_cap_label = _add_label("Cap", CAP_FONT, CAP_Y, CAP_COLOR)

func _add_disc(disc_name: String, radius: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 64
	mesh.rings = 0
	var disc := MeshInstance3D.new()
	disc.name = disc_name
	disc.mesh = mesh
	disc.material_override = material
	disc.position.y = height * 0.5
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)

## Liegend, Schriftrichtung Bild-rechts (+Z), Oberkante Bild-oben (+X).
func _add_label(label_name: String, font: int, offset: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.name = label_name
	label.font_size = font
	label.pixel_size = LABEL_PIXEL
	label.modulate = color
	label.outline_size = 8
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	label.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	label.position = Vector3(offset, CORE_HEIGHT + 0.01, 0.0)
	add_child(label)
	return label

func _build_materials() -> void:
	_empty_material = StandardMaterial3D.new()
	_empty_material.albedo_color = EMPTY_ALBEDO
	_empty_material.metallic = 0.4
	_empty_material.roughness = 0.25
	_empty_material.emission_enabled = true
	_empty_material.emission = EMPTY_EMISSION
	_empty_material.emission_energy_multiplier = EMPTY_ENERGY
	_empty_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_locked_material = StandardMaterial3D.new()
	_locked_material.albedo_color = LOCKED_ALBEDO
	_locked_material.metallic = 0.5
	_locked_material.roughness = 0.3
	_locked_material.emission_enabled = true
	_locked_material.emission = LOCKED_EMISSION
	_locked_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sweep_material = _new_lit_material()
	_sweep_material.albedo_color = CasinoStyle.ENERGY
	_core_material = StandardMaterial3D.new()
	_core_material.albedo_color = CORE_ALBEDO
	_core_material.metallic = 0.3
	_core_material.roughness = 0.2
	_core_material.emission_enabled = true
	_core_material.emission = CasinoStyle.ENERGY

func _new_lit_material() -> StandardMaterial3D:
	var lit := StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.albedo_color = CasinoStyle.ENERGY * LIT_SHARE
	lit.cull_mode = BaseMaterial3D.CULL_DISABLED
	return lit

## Ein Segment als Ringstück um Bild-oben (+X): Deckel und Außenkante genügen,
## denn von unten sieht es niemand.
func _segment_mesh(radii: Vector2) -> ArrayMesh:
	var half := deg_to_rad(_segment_span_deg() * 0.5)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in SEGMENT_STEPS:
		var a := lerpf(-half, half, float(step) / float(SEGMENT_STEPS))
		var b := lerpf(-half, half, float(step + 1) / float(SEGMENT_STEPS))
		var inner_a := _ring_point(radii.x, a, SEGMENT_HEIGHT)
		var inner_b := _ring_point(radii.x, b, SEGMENT_HEIGHT)
		var outer_a := _ring_point(radii.y, a, SEGMENT_HEIGHT)
		var outer_b := _ring_point(radii.y, b, SEGMENT_HEIGHT)
		_add_quad(surface, Vector3.UP, inner_a, outer_a, outer_b, inner_b)
		var side := Vector3(cos((a + b) * 0.5), 0.0, sin((a + b) * 0.5))
		_add_quad(surface, side, outer_a, _ring_point(radii.y, a, 0.0),
			_ring_point(radii.y, b, 0.0), outer_b)
	return surface.commit()

static func _ring_point(radius: float, angle: float, y: float) -> Vector3:
	return Vector3(cos(angle) * radius, y, sin(angle) * radius)

static func _add_quad(surface: SurfaceTool, normal: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	surface.set_normal(normal)
	for point: Vector3 in [a, b, c, a, c, d]:
		surface.add_vertex(point)

func _apply() -> void:
	_number.text = str(_energy)
	_cap_label.text = "/ %d" % _cap
	for i in _segments.size():
		if i >= _energy:
			_lit_materials.erase(i)
		_paint(i)
	_apply_core()
	_sync_process()

func _paint(index: int) -> void:
	var seg := _segments[index]
	if _sweep >= 0.0 and index < _cap and absf(float(index) - _sweep) < SWEEP_WIDTH:
		seg.material_override = _sweep_material
	elif index < _energy:
		if not _lit_materials.has(index):
			_lit_materials[index] = _new_lit_material()
		seg.material_override = _lit_materials[index]
	else:
		seg.material_override = _empty_material if index < _cap else _locked_material

func _apply_core() -> void:
	var fill := float(_energy) / float(maxi(_cap, 1))
	var glow := lerpf(CORE_ENERGY_EMPTY, CORE_ENERGY_FULL, fill)
	if _is_full():
		glow += CORE_ENERGY_RESTLESS * absf(sin(_time * 7.3) * sin(_time * 3.1))
	_core_material.emission_energy_multiplier = glow

func _is_full() -> bool:
	return _cap > 0 and _energy >= _cap

func _sync_process() -> void:
	set_process(not _lit_materials.is_empty() or not _flashes.is_empty() or _sweep >= 0.0)

## Jedes geladene Segment atmet in eigener Phase; neu geladene blitzen kurz.
func _process(delta: float) -> void:
	_time += delta
	for i: int in _flashes.keys():
		_flashes[i] = float(_flashes[i]) - delta / FLASH_TIME
		if float(_flashes[i]) <= 0.0:
			_flashes.erase(i)
	for i: int in _lit_materials:
		var breath := 0.5 + 0.5 * sin(_time * 2.6 + float(i) * 2.39) * sin(_time * 1.7 + float(i) * 5.7)
		var flash := float(_flashes.get(i, 0.0))
		var material: StandardMaterial3D = _lit_materials[i]
		material.albedo_color = CasinoStyle.ENERGY * (LIT_SHARE + LIT_BREATH * breath + FLASH_GAIN * flash)
	if _sweep >= 0.0:
		_sweep += delta / SWEEP_TIME * float(_cap)
		if _sweep > float(_cap) + SWEEP_WIDTH:
			_sweep = -1.0
		for i in _cap:
			_paint(i)
	_apply_core()
	_sync_process()
