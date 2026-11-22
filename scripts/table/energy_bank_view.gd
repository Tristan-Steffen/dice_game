class_name EnergyBankView
extends Node3D
## Die AKKU-BANK: der physische ⚡-Speicher rechts neben der Glücks-Station. Zehn
## Batterieblöcke, je Block fünf Ladefenster, ein Fenster = eine Energie; ein Block steht
## erst, wenn der Deckel ihn freigibt. Oben nennt die Anzeige Stand und Deckel.
## Code-gebaut, nur Emission.

const CELLS := GameRun.ENERGY_CAP_LIMIT
const ACROSS := GameRun.ENERGY_ROW
const ROWS := 10
## Grundriß in eigenen Einheiten: x = Bild-oben, y = Bild-rechts.
const SIZE := Vector2(15.0, 6.2)
const ROW_PITCH := 1.2
const WINDOW_PITCH := 0.8
const FRAME := 0.3
const BASE_TOP := 0.1
const FRAME_HEIGHT := 0.45
const BLOCK := Vector3(1.04, 0.8, 5.4)
const BLOCK_TOP := BASE_TOP + BLOCK.y
const WINDOW := Vector2(0.56, 0.62)
const POLE_Z := 2.42
const PLATE_LENGTH := 2.2
const PLATE_TOP := 0.5

const STEEL := Color(0.36, 0.4, 0.46)
const COPPER := Color(0.85, 0.45, 0.2)
const SHELL := Color(0.1, 0.12, 0.16)
const LID := Color(0.16, 0.19, 0.25)
const PLUS := Color(0.85, 0.2, 0.18)
const MINUS := Color(0.5, 0.55, 0.62)
const FLOOR := Color(0.04, 0.05, 0.08)
const BAY := Color(0.02, 0.03, 0.045)
const BAY_RIM := Color(0.09, 0.11, 0.15)
## Lichtsaum auf dem Rahmen, unter der Bloom-Schwelle.
const TRIM_SHARE := 0.32
const PLATE_ALBEDO := Color(0.02, 0.03, 0.05)
const EMPTY_ALBEDO := Color(0.06, 0.09, 0.13)
const EMPTY_EMISSION := Color(0.16, 0.40, 0.46)
const EMPTY_ENERGY := 1.6
## Unter der Bloom-Schwelle, damit Nachbarn nicht zu einem Balken verschmelzen.
const LIT_SHARE := 0.6
const LIT_BREATH := 0.12
const FLASH_GAIN := 0.9
const FLASH_TIME := 0.35
const PLATE_ENERGY_EMPTY := 0.02
const PLATE_ENERGY_FULL := 0.14
const PLATE_ENERGY_RESTLESS := 0.2
const SWEEP_TIME := 0.7
const SWEEP_WIDTH := 1.5
const RISE_TIME := 0.3
const ROW_STAGGER := 0.08

const NUMBER_FONT := 150
const CAP_FONT := 80
const LABEL_PIXEL := 0.0105
const NUMBER_Z := -0.95
const CAP_Z := 1.25
const NUMBER_COLOR := Color(1.3, 1.3, 1.25)
const CAP_COLOR := Color(0.7, 1.1, 1.2)

var _energy := 0
var _cap := 0
var _blocks: Array[Node3D] = []
var _bridges: Array[Node3D] = []
var _windows: Array[MeshInstance3D] = []
var _empty_material: StandardMaterial3D
var _sweep_material: StandardMaterial3D
var _plate_material: StandardMaterial3D
var _lit_materials := {}
var _flashes := {}
var _number: Label3D
var _cap_label: Label3D
var _time := 0.0
var _sweep := -1.0
var _pulse_tween: Tween

func _ready() -> void:
	_build()
	_apply(false)

## Einziger Eingang: scene_root spiegelt GameRun.energy/energy_cap hierher.
func set_energy(energy: int, cap: int) -> void:
	var new_cap := clampi(cap, 0, CELLS)
	var new_energy := clampi(energy, 0, new_cap)
	for i in range(_energy, new_energy):
		_flashes[i] = 1.0
	var grew := _cap > 0 and new_cap > _cap
	_cap = new_cap
	_energy = new_energy
	if _blocks.is_empty():
		return
	if grew:
		_sweep = 0.0
	_apply(grew)

## Kurzer Pop der Anzeige - eine Energie ist eben eingetroffen.
func pulse() -> void:
	if _number == null:
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_number.scale = Vector3.ONE * 1.25
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_number, "scale", Vector3.ONE, 0.35)

func energy_count() -> int:
	return _energy

func cap_count() -> int:
	return _cap

func number_text() -> String:
	return _number.text if _number != null else ""

func cap_text() -> String:
	return _cap_label.text if _cap_label != null else ""

## Das Ladefenster der Energie index.
func segment(index: int) -> MeshInstance3D:
	return _windows[index]

## Steht der Block der Energie index (unter dem Deckel)?
func cell_stands(index: int) -> bool:
	return _blocks[_row_of(index)].visible

func sweeping() -> bool:
	return _sweep >= 0.0

## Mitte des Fensters index in eigenen Einheiten: Block 0 liegt Bild-unten, Fenster 0 links.
static func cell_spot(index: int) -> Vector3:
	return Vector3(row_x(_row_of(index)), BLOCK_TOP,
		(float(index % ACROSS) - float(ACROSS - 1) * 0.5) * WINDOW_PITCH)

static func row_x(row: int) -> float:
	return -SIZE.x * 0.5 + FRAME + ROW_PITCH * (float(row) + 0.5)

static func _row_of(index: int) -> int:
	@warning_ignore("integer_division")
	return index / ACROSS

func _build() -> void:
	_build_materials()
	var steel := _solid(STEEL, 0.5, 0.4, 0.9)
	var copper := _solid(COPPER, 0.6, 0.35, 0.8)
	var shell := _solid(SHELL, 0.2, 0.5, 1.0)
	var lid := _solid(LID, 0.2, 0.45, 1.0)
	var plus := _solid(PLUS, 0.3, 0.4, 0.9)
	var minus := _solid(MINUS, 0.6, 0.35, 0.9)
	var bay := _solid(BAY, 0.0, 0.9, 1.0)
	var bay_rim := _solid(BAY_RIM, 0.1, 0.7, 1.0)
	var trim := StandardMaterial3D.new()
	trim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trim.albedo_color = CasinoStyle.ENERGY * TRIM_SHARE
	_box("Boden", Vector3(SIZE.x, BASE_TOP, SIZE.y), Vector3(0, BASE_TOP * 0.5, 0), _solid(FLOOR, 0.1, 0.8, 1.0))
	for side in [-1.0, 1.0]:
		_box("Holm", Vector3(SIZE.x, FRAME_HEIGHT, 0.2),
			Vector3(0, FRAME_HEIGHT * 0.5, side * (SIZE.y * 0.5 - 0.1)), steel)
		_box("Traverse", Vector3(FRAME, FRAME_HEIGHT, SIZE.y),
			Vector3(side * (SIZE.x * 0.5 - FRAME * 0.5), FRAME_HEIGHT * 0.5, 0), steel)
		_box("SaumLang", Vector3(SIZE.x - 0.12, 0.02, 0.06),
			Vector3(0, FRAME_HEIGHT + 0.01, side * (SIZE.y * 0.5 - 0.1)), trim)
		_box("SaumQuer", Vector3(0.06, 0.02, SIZE.y - 0.14),
			Vector3(side * (SIZE.x * 0.5 - FRAME * 0.5), FRAME_HEIGHT + 0.01, 0), trim)
	var stopper := _cylinder(0.08, 0.05)
	var pole := _cylinder(0.13, 0.16)
	for row in ROWS:
		var x := row_x(row)
		# Der leere Stellplatz: eine Wanne, die unter dem Block verschwindet.
		_box("Wanne%d" % row, Vector3(BLOCK.x, 0.03, BLOCK.z), Vector3(x, BASE_TOP + 0.015, 0), bay_rim)
		_box("Wannengrund%d" % row, Vector3(BLOCK.x - 0.16, 0.02, BLOCK.z - 0.16), Vector3(x, BASE_TOP + 0.035, 0), bay)
		var block := Node3D.new()
		block.name = "Block%d" % row
		block.position = Vector3(x, BASE_TOP, 0)
		add_child(block)
		_box("Gehaeuse", BLOCK, Vector3(0, BLOCK.y * 0.5, 0), shell, block)
		_box("Deckel", Vector3(BLOCK.x - 0.14, 0.06, BLOCK.z - 0.14), Vector3(0, BLOCK.y + 0.03, 0), lid, block)
		for across in ACROSS:
			var z := cell_spot(across).z
			_windows.append(_box("Fenster%d" % across, Vector3(WINDOW.x, 0.03, WINDOW.y),
				Vector3(-0.06, BLOCK.y + 0.075, z), _empty_material, block))
			_mesh("Stopfen%d" % across, stopper, Vector3(0.33, BLOCK.y + 0.085, z), minus, block)
		_mesh("Plus", pole, Vector3(0, BLOCK.y + 0.14, -POLE_Z), plus, block)
		_mesh("Minus", pole, Vector3(0, BLOCK.y + 0.14, POLE_Z), minus, block)
		_blocks.append(block)
		# Brückenkabel zum nächsten Block, abwechselnd links und rechts: die Bank liegt in Reihe.
		var bridge := Node3D.new()
		bridge.name = "Bruecke%d" % row
		add_child(bridge)
		if row + 1 < ROWS:
			var side := -1.0 if row % 2 == 1 else 1.0
			_box("Kabel", Vector3(ROW_PITCH, 0.07, 0.16),
				Vector3(x + ROW_PITCH * 0.5, BLOCK_TOP + 0.23, side * POLE_Z), copper, bridge)
		_bridges.append(bridge)
	var plate_x := SIZE.x * 0.5 - FRAME - PLATE_LENGTH * 0.5
	_box("Anzeige", Vector3(PLATE_LENGTH, PLATE_TOP - BASE_TOP, SIZE.y - 0.6),
		Vector3(plate_x, (PLATE_TOP + BASE_TOP) * 0.5, 0), _plate_material)
	_number = _add_label("Number", NUMBER_FONT, Vector3(plate_x, PLATE_TOP + 0.01, NUMBER_Z), NUMBER_COLOR)
	_cap_label = _add_label("Cap", CAP_FONT, Vector3(plate_x - 0.12, PLATE_TOP + 0.01, CAP_Z), CAP_COLOR)

func _box(part: String, size: Vector3, at: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(part, mesh, at, material, parent)

func _mesh(part: String, mesh: Mesh, at: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 1
	return mesh

## Liegend, Schriftrichtung Bild-rechts (+Z), Oberkante Bild-oben (+X).
func _add_label(label_name: String, font: int, at: Vector3, color: Color) -> Label3D:
	var label := Label3D.new()
	label.name = label_name
	label.font_size = font
	label.pixel_size = LABEL_PIXEL
	label.modulate = color
	label.outline_size = 8
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	label.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	label.position = at
	add_child(label)
	return label

## Der Tisch beleuchtet nichts: jedes Teil trägt einen Anteil Eigenlicht.
func _solid(color: Color, metallic: float, roughness: float, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material

func _build_materials() -> void:
	_empty_material = StandardMaterial3D.new()
	_empty_material.albedo_color = EMPTY_ALBEDO
	_empty_material.metallic = 0.4
	_empty_material.roughness = 0.25
	_empty_material.emission_enabled = true
	_empty_material.emission = EMPTY_EMISSION
	_empty_material.emission_energy_multiplier = EMPTY_ENERGY
	_sweep_material = _new_lit_material()
	_sweep_material.albedo_color = CasinoStyle.ENERGY
	_plate_material = StandardMaterial3D.new()
	_plate_material.albedo_color = PLATE_ALBEDO
	_plate_material.metallic = 0.3
	_plate_material.roughness = 0.2
	_plate_material.emission_enabled = true
	_plate_material.emission = CasinoStyle.ENERGY

func _new_lit_material() -> StandardMaterial3D:
	var lit := StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.albedo_color = CasinoStyle.ENERGY * LIT_SHARE
	return lit

func _apply(grew: bool) -> void:
	_number.text = str(_energy)
	_cap_label.text = "/ %d" % _cap
	for row in _blocks.size():
		_stand(row, row * ACROSS < _cap, grew)
		_bridges[row].visible = (row + 1) * ACROSS < _cap
	for i in _windows.size():
		if i >= _energy:
			_lit_materials.erase(i)
		_paint(i)
	_apply_plate()
	_sync_process()

## Endzustand zuerst: der Block steht, ein neu freigegebener wächst nur dorthin.
func _stand(row: int, stands: bool, grew: bool) -> void:
	var block := _blocks[row]
	var was := block.visible
	block.visible = stands
	if not stands or was or not grew:
		block.scale = Vector3.ONE
		return
	block.scale = Vector3(1.0, 0.02, 1.0)
	var tween := block.create_tween()
	tween.tween_interval(ROW_STAGGER * float(row % 5))
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(block, "scale", Vector3.ONE, RISE_TIME)

func _paint(index: int) -> void:
	var window := _windows[index]
	if _sweep >= 0.0 and index < _cap and absf(float(index) - _sweep) < SWEEP_WIDTH:
		window.material_override = _sweep_material
	elif index < _energy:
		if not _lit_materials.has(index):
			_lit_materials[index] = _new_lit_material()
		window.material_override = _lit_materials[index]
	else:
		window.material_override = _empty_material

func _apply_plate() -> void:
	var fill := float(_energy) / float(maxi(_cap, 1))
	var glow := lerpf(PLATE_ENERGY_EMPTY, PLATE_ENERGY_FULL, fill)
	if _is_full():
		glow += PLATE_ENERGY_RESTLESS * absf(sin(_time * 7.3) * sin(_time * 3.1))
	_plate_material.emission_energy_multiplier = glow

func _is_full() -> bool:
	return _cap > 0 and _energy >= _cap

func _sync_process() -> void:
	set_process(not _lit_materials.is_empty() or not _flashes.is_empty() or _sweep >= 0.0)

## Jedes geladene Fenster atmet in eigener Phase; neu geladene blitzen kurz.
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
	_apply_plate()
	_sync_process()
