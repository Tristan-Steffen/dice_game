class_name EnergyBankView
extends Node3D
## Die AKKU-BANK: der physische ⚡-Speicher rechts neben der Glücks-Station. Zehn
## Stellplätze mit Dock-Stecker, darin je Powerbank eine Glas-KARTUSCHE mit fünf Plasma-
## Zellen, eine Zelle = eine Energie; eine Kartusche steckt erst, wenn der Deckel sie
## freigibt. Oben nennt die Anzeige Stand und Deckel. Code-gebaut, nur Emission.

const CELLS := GameRun.ENERGY_CAP_LIMIT
const ACROSS := GameRun.ENERGY_ROW
const ROWS := 10
## Grundriß in eigenen Einheiten: x = Bild-oben, y = Bild-rechts.
const SIZE := Vector2(15.0, 6.2)
const ROW_PITCH := 1.2
const WINDOW_PITCH := 0.86
const FRAME := 0.3
const BASE_TOP := 0.1
const FRAME_HEIGHT := 0.45
const BLOCK := Vector3(1.04, 0.8, 5.4)
## Achse der Kartusche über ihrem Stellplatz.
const AXIS := 0.5
## Eine Plasma-Zelle: Durchmesser und Länge.
const WINDOW := Vector2(0.54, 0.74)
const CORE_RADIUS := 0.135
## Leer bleibt vom Kern nur die Elektrode.
const EMPTY_CORE := 0.33
const PLUG_PINS := 5
const GUIDE_Z := 1.9
const JAW_Z := 1.29
const PLATE_LENGTH := 2.2
const PLATE_TOP := 0.5

const STEEL := Color(0.36, 0.4, 0.46)
const CAP_STEEL := Color(0.42, 0.46, 0.52)
const DARK := Color(0.07, 0.08, 0.11)
const GOLD := Color(0.86, 0.66, 0.28)
const GLASS := Color(0.62, 0.86, 0.96, 0.2)
const FLOOR := Color(0.04, 0.05, 0.08)
const BAY := Color(0.02, 0.03, 0.045)
const BAY_RIM := Color(0.09, 0.11, 0.15)
## Lichtsaum auf dem Rahmen, unter der Bloom-Schwelle.
const TRIM_SHARE := 0.32
const PLATE_ALBEDO := Color(0.02, 0.03, 0.05)
const MANTLE_LIT := 0.5
const MANTLE_EMPTY := 0.14
const MANTLE_ALPHA := 0.55
const LAMP_OFF := 0.15
const DOCK_OFF := 0.1
const DOCK_ON := 0.3
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
const RISE_TIME := 0.35
## So hoch über dem Dock beginnt eine neue Kartusche ihren Weg.
const RISE_FROM := 1.4
## Trage-Bogen einer gekauften Kartusche vom Schwarzmarkt in ihr Dock.
const FLY_TIME := 0.9
const FLY_PEAK := 3.5
const FLY_START_SCALE := 0.6
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
var _windows: Array[MeshInstance3D] = []
var _mantles: Array[MeshInstance3D] = []
var _lamps: Array[StandardMaterial3D] = []
var _dock_lights: Array[StandardMaterial3D] = []
var _mantle_lit: StandardMaterial3D
var _mantle_empty: StandardMaterial3D
var _glass_material: StandardMaterial3D
var _cylinders := {}
## Laufende Fahrt je Stellplatz (Senken oder Trage-Bogen).
var _rides := {}
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

## Die zuletzt freigegebene Kartusche fliegt von from_global (Welt) im Trage-Bogen in ihr
## Dock. Sie steckt schon (Endzustand zuerst); bis zur Landung bleibt das Dock dunkel.
func fly_in(from_global: Vector3) -> void:
	if _cap <= 0 or _blocks.is_empty():
		return
	var row := _row_of(_cap - 1)
	var block := _blocks[row]
	_end_ride(row)
	var rest := Vector3(row_x(row), BASE_TOP, 0)
	var start := to_local(from_global)
	_dock_lights[row].albedo_color = CasinoStyle.ENERGY * DOCK_OFF
	var tween := block.create_tween()
	_rides[row] = tween
	var fly := func(t: float) -> void:
		var eased := smoothstep(0.0, 1.0, t)
		block.position = start.lerp(rest, eased) + Vector3.UP * FLY_PEAK * sin(PI * t)
		block.scale = Vector3.ONE * lerpf(FLY_START_SCALE, 1.0, eased)
	var land := func() -> void:
		_rides.erase(row)
		_dock_lights[row].albedo_color = CasinoStyle.ENERGY * DOCK_ON
		pulse()
	fly.call(0.0)
	tween.tween_method(fly, 0.0, 1.0, FLY_TIME)
	tween.tween_callback(land)

## Harter Weg einer Fahrt: die Kartusche steht auf ihrem Platz.
func _end_ride(row: int) -> void:
	if _rides.has(row):
		var ride: Tween = _rides[row]
		if ride != null and ride.is_valid():
			ride.kill()
		_rides.erase(row)
	_blocks[row].position = Vector3(row_x(row), BASE_TOP, 0)
	_blocks[row].scale = Vector3.ONE

func riding(row: int) -> bool:
	return _rides.has(row)

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

## Der Plasma-Kern der Energie index.
func segment(index: int) -> MeshInstance3D:
	return _windows[index]

## Steckt die Kartusche der Energie index (unter dem Deckel)?
func cell_stands(index: int) -> bool:
	return _blocks[_row_of(index)].visible

func sweeping() -> bool:
	return _sweep >= 0.0

## Mitte der Zelle index in eigenen Einheiten: Kartusche 0 liegt Bild-unten, Zelle 0 links.
static func cell_spot(index: int) -> Vector3:
	return Vector3(row_x(_row_of(index)), BASE_TOP + AXIS,
		(float(index % ACROSS) - float(ACROSS - 1) * 0.5) * WINDOW_PITCH)

static func row_x(row: int) -> float:
	return -SIZE.x * 0.5 + FRAME + ROW_PITCH * (float(row) + 0.5)

static func _row_of(index: int) -> int:
	@warning_ignore("integer_division")
	return index / ACROSS

func _build() -> void:
	_build_materials()
	var steel := _solid(STEEL, 0.5, 0.4, 0.9)
	var metal := _solid(CAP_STEEL, 0.85, 0.28, 0.9)
	var dark := _solid(DARK, 0.4, 0.4, 1.0)
	var gold := _solid(GOLD, 0.85, 0.25, 0.8)
	var hole := _solid(BAY, 0.0, 0.9, 1.0)
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
	for row in ROWS:
		var dock := Node3D.new()
		dock.name = "Dock%d" % row
		dock.position = Vector3(row_x(row), BASE_TOP, 0)
		add_child(dock)
		_build_dock(dock, _flat(CasinoStyle.ENERGY * DOCK_OFF), bay_rim, hole, dark, metal, gold)
		var block := Node3D.new()
		block.name = "Block%d" % row
		block.position = Vector3(row_x(row), BASE_TOP, 0)
		add_child(block)
		_build_cartridge(block, _flat(CasinoStyle.ENERGY * LAMP_OFF), dark, metal, gold)
		_blocks.append(block)
	var plate_x := SIZE.x * 0.5 - FRAME - PLATE_LENGTH * 0.5
	_box("Anzeige", Vector3(PLATE_LENGTH, PLATE_TOP - BASE_TOP, SIZE.y - 0.6),
		Vector3(plate_x, (PLATE_TOP + BASE_TOP) * 0.5, 0), _plate_material)
	_number = _add_label("Number", NUMBER_FONT, Vector3(plate_x, PLATE_TOP + 0.01, NUMBER_Z), NUMBER_COLOR)
	_cap_label = _add_label("Cap", CAP_FONT, Vector3(plate_x - 0.12, PLATE_TOP + 0.01, CAP_Z), CAP_COLOR)

## Der Stellplatz: Buchse mit fünf Kontakten, Lichtrahmen, zwei Führungshülsen und zwei
## Klemmbacken. Er steht immer - auch leer.
func _build_dock(dock: Node3D, light: StandardMaterial3D, rim: Material, hole: Material,
		dark: Material, metal: Material, gold: Material) -> void:
	_dock_lights.append(light)
	_box("Wanne", Vector3(BLOCK.x, 0.03, BLOCK.z), Vector3(0, 0.015, 0), rim, dock)
	_box("Buchse", Vector3(0.56, 0.14, 1.2), Vector3(0, 0.1, 0), dark, dock)
	_box("Schacht", Vector3(0.38, 0.02, 0.98), Vector3(0, 0.175, 0), hole, dock)
	for i in PLUG_PINS:
		_post("Kontakt%d" % i, 0.035, 0.02, Vector3(0, 0.19, _pin_z(i)), gold, dock)
	for side in [-1.0, 1.0]:
		_box("RahmenLang", Vector3(0.03, 0.015, 1.3), Vector3(side * 0.33, 0.04, 0), light, dock)
		_box("RahmenQuer", Vector3(0.68, 0.015, 0.03), Vector3(0, 0.04, side * 0.65), light, dock)
		_post("Huelse", 0.12, 0.1, Vector3(0, 0.08, side * GUIDE_Z), metal, dock)
		_post("Huelsenloch", 0.07, 0.02, Vector3(0, 0.135, side * GUIDE_Z), hole, dock)
		for jaw in [-1.0, 1.0]:
			_box("Backenfuss", Vector3(0.2, 0.08, 0.26), Vector3(jaw * 0.41, 0.07, side * JAW_Z), dark, dock)
			_box("Backe", Vector3(0.09, 0.5, 0.2), Vector3(jaw * 0.445, 0.33, side * JAW_Z), metal, dock)
			_post("Schraube", 0.05, 0.03, Vector3(jaw * 0.445, 0.595, side * JAW_Z), gold, dock)

## Die Kartusche "Labor": Glasrohr mit fünf Plasma-Zellen zwischen Stahlbändern, gerändelte
## Kappen, darunter der Steckerblock und zwei Führungszapfen.
func _build_cartridge(block: Node3D, lamp: StandardMaterial3D, dark: Material, metal: Material,
		gold: Material) -> void:
	_lamps.append(lamp)
	for side in [-1.0, 1.0]:
		_tube("Kappe", 0.42, 0.34, side * 2.42, metal, block)
		for k in 3:
			_tube("Raendel%d" % k, 0.44, 0.04, side * (2.31 + float(k) * 0.1), dark, block)
		_tube("Stirn", 0.3, 0.06, side * 2.62, dark, block)
		_tube("Endstift", 0.15, 0.16, side * 2.66, gold, block)
		_box("Lampe", Vector3(0.09, 0.03, 0.09), Vector3(0, AXIS + 0.425, side * 2.2), lamp, block)
		_post("Zapfen", 0.06, 0.16, Vector3(0, AXIS - 0.43, side * GUIDE_Z), metal, block)
	for across in ACROSS:
		var z := cell_spot(across).z
		_mantles.append(_tube("Mantel%d" % across, WINDOW.x * 0.5, WINDOW.y, z, _mantle_empty, block))
		_windows.append(_tube("Fenster%d" % across, CORE_RADIUS, WINDOW.y, z, _empty_material, block))
	for i in ACROSS + 1:
		var z := (float(i) - float(ACROSS) * 0.5) * WINDOW_PITCH
		_tube("Band%d" % i, 0.385, 0.07, z, metal, block)
		_tube("Goldring%d" % i, 0.392, 0.02, z, gold, block)
	_tube("Glas", 0.365, 4.5, 0.0, _glass_material, block)
	_box("Stecker", Vector3(0.34, 0.14, 0.94), Vector3(0, AXIS - 0.4, 0), dark, block)
	_box("Steckerleiste", Vector3(0.28, 0.03, 0.88), Vector3(0, AXIS - 0.48, 0), gold, block)

static func _pin_z(i: int) -> float:
	return (float(i) - float(PLUG_PINS - 1) * 0.5) * 0.2

## Zylinder längs der Kartusche (Z) auf ihrer Achse.
func _tube(part: String, radius: float, length: float, z: float, material: Material,
		parent: Node3D) -> MeshInstance3D:
	var node := _mesh(part, _cylinder(radius, length), Vector3(0, AXIS, z), material, parent)
	node.rotation.x = PI * 0.5
	return node

func _post(part: String, radius: float, height: float, at: Vector3, material: Material,
		parent: Node3D) -> MeshInstance3D:
	return _mesh(part, _cylinder(radius, height), at, material, parent)

func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

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
	var key := Vector2(radius, height)
	if _cylinders.has(key):
		return _cylinders[key]
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 1
	_cylinders[key] = mesh
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
	_empty_material = _solid(CAP_STEEL, 0.8, 0.3, 0.9)
	_mantle_lit = _flat(CasinoStyle.ENERGY * MANTLE_LIT)
	_mantle_empty = _flat(CasinoStyle.ENERGY * MANTLE_EMPTY)
	for mantle: StandardMaterial3D in [_mantle_lit, _mantle_empty]:
		mantle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mantle.albedo_color.a = MANTLE_ALPHA
	_glass_material = _solid(Color(GLASS.r, GLASS.g, GLASS.b), 0.1, 0.08, 0.25)
	_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_material.albedo_color.a = GLASS.a
	_glass_material.render_priority = 1
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
		var stands := row * ACROSS < _cap
		_stand(row, stands, grew)
		if not _rides.has(row):
			_dock_lights[row].albedo_color = CasinoStyle.ENERGY * (DOCK_ON if stands else DOCK_OFF)
		_lamps[row].albedo_color = CasinoStyle.ENERGY * (1.0 if _energy > row * ACROSS else LAMP_OFF)
	for i in _windows.size():
		if i >= _energy:
			_lit_materials.erase(i)
		_paint(i)
	_apply_plate()
	_sync_process()

## Endzustand zuerst: die Kartusche steckt, eine neu freigegebene senkt sich nur dorthin.
func _stand(row: int, stands: bool, grew: bool) -> void:
	var block := _blocks[row]
	var was := block.visible
	block.visible = stands
	if stands and was:
		return  # eine laufende Fahrt bleibt, sonst steht sie ohnehin
	_end_ride(row)
	if not stands or not grew:
		return
	block.position.y = BASE_TOP + RISE_FROM
	var tween := block.create_tween()
	_rides[row] = tween
	tween.tween_interval(ROW_STAGGER * float(row % 5))
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(block, "position:y", BASE_TOP, RISE_TIME)
	tween.tween_callback(func() -> void: _rides.erase(row))

func _paint(index: int) -> void:
	var window := _windows[index]
	var lit := true
	if _sweep >= 0.0 and index < _cap and absf(float(index) - _sweep) < SWEEP_WIDTH:
		window.material_override = _sweep_material
	elif index < _energy:
		if not _lit_materials.has(index):
			_lit_materials[index] = _new_lit_material()
		window.material_override = _lit_materials[index]
	else:
		window.material_override = _empty_material
		lit = false
	window.scale = Vector3.ONE if lit else Vector3(EMPTY_CORE, 1.0, EMPTY_CORE)
	_mantles[index].material_override = _mantle_lit if lit else _mantle_empty

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
