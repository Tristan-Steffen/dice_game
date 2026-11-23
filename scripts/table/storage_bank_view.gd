class_name StorageBankView
extends Node3D
## Die KÖRPER des Speichers (UPGRADES): je Scheibe eine ENERGIEZELLE - ein Glasrohr in zwei
## Federklemmen, geladen leuchtet sein Kern in der Farbe der Karte, leer ist er dunkel -, und
## um jede Netz-Zelle der Rahmen eines CHIPS mit Beinchen (die Zelle selbst bleibt das Bild
## der Anzeige). Halter und Zellen meldet das Fenster (WorkshopView.storage_cells_px,
## storage_chips_px); seat() und seat_chips() sind die EINEN Schreiber. Der Knoten bleibt im
## Ursprung - die Hebebühne der Zone fährt ihn als Ganzes.

## Rohr-Durchmesser als Anteil der Halterbreite, Längen als Anteile der Halterlänge.
const TUBE_SHARE := 0.86
const CORE_SHARE := 0.62
const GLASS_LENGTH := 0.66
const CAP_LENGTH := 0.13
const CLIP_THICK := 0.05
## Luft zwischen Tisch und Rohr.
const LIFT := 0.04
const EMPTY := Color(0.07, 0.08, 0.1)
const GLASS := Color(0.7, 0.88, 1.0, 0.16)
const GLINT := Color(1.0, 1.0, 1.0, 0.42)
const STEEL := Color(0.5, 0.52, 0.56)
## Der geladene Kern steht knapp über der Bloom-Schwelle.
const CORE_ENERGY := 1.15
## Der Rahmen eines Chips: Höhe und Breite (Anteil der Zellkante), Beinchen je Seite.
const RIM_HEIGHT := 0.11
const RIM_SHARE := 0.035
const RIM_STEEL := Color(0.3, 0.31, 0.36)
const PINS_PER_SIDE := 5
const PIN_HEIGHT := 0.04

var _chips: Node3D
var _chips_key: Array = []
var _cells: Array[Node3D] = []
var _cores: Array[StandardMaterial3D] = []
var _size := Vector2.ZERO

## centers = Mitte je Halter auf dem Tisch, size = (längs Welt-X, quer Welt-Z).
func seat(centers: Array[Vector3], size: Vector2, tints: Array[Color]) -> void:
	if centers.size() != _cells.size() or not size.is_equal_approx(_size):
		_rebuild(centers.size(), size)
	for i in _cells.size():
		_cells[i].position = centers[i]
	for i in _cores.size():
		_cores[i].albedo_color = core_color(tints[i] if i < tints.size() else Color(0, 0, 0, 0))

## Die CHIP-RAHMEN: chips = Mitte je Netz-Zelle, side = Zellkante, pin_reach = Länge der
## Beinchen. Idempotent.
func seat_chips(chips: Array[Vector3], side: float, pin_reach: float) -> void:
	var key := [chips, side, pin_reach]
	if key == _chips_key:
		return
	_chips_key = key
	if _chips != null:
		remove_child(_chips)
		_chips.queue_free()
	_chips = Node3D.new()
	_chips.name = "Chips"
	add_child(_chips)
	if chips.is_empty() or side <= 0.0:
		return
	var rim := side * RIM_SHARE
	var bars: Array[Transform3D] = []
	var pins: Array[Transform3D] = []
	var wide := side / float(PINS_PER_SIDE) * 0.4
	for chip in chips:
		for way: float in [-1.0, 1.0]:
			var out := way * (side * 0.5 + rim * 0.5)
			bars.append(_box(Vector3(rim, RIM_HEIGHT, side + rim * 2.0),
				Vector3(chip.x + out, RIM_HEIGHT * 0.5, chip.z)))
			bars.append(_box(Vector3(side, RIM_HEIGHT, rim),
				Vector3(chip.x, RIM_HEIGHT * 0.5, chip.z + out)))
			var far := way * (side * 0.5 + rim + pin_reach * 0.5)
			for k in PINS_PER_SIDE:
				var along := side * ((float(k) + 0.5) / float(PINS_PER_SIDE) - 0.5)
				pins.append(_box(Vector3(pin_reach, PIN_HEIGHT, wide),
					Vector3(chip.x + far, PIN_HEIGHT * 0.5, chip.z + along)))
				pins.append(_box(Vector3(wide, PIN_HEIGHT, pin_reach),
					Vector3(chip.x + along, PIN_HEIGHT * 0.5, chip.z + far)))
	_swarm("Rahmen", bars, ChipFrameView._skin(RIM_STEEL, 0.3))
	if pin_reach > 0.0:
		_swarm("Beinchen", pins, ChipFrameView._skin(STEEL, 0.4))

static func _box(size: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), at)

## Viele Quader als EIN MultiMesh.
func _swarm(part: String, boxes: Array[Transform3D], material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = boxes.size()
	for i in boxes.size():
		multi.set_instance_transform(i, boxes[i])
	var node := MultiMeshInstance3D.new()
	node.name = part
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chips.add_child(node)

## So viele Chip-Rahmen stehen (vier Stege je Chip).
func chip_count() -> int:
	if _chips == null:
		return 0
	var rims := _chips.get_node_or_null("Rahmen") as MultiMeshInstance3D
	return rims.multimesh.instance_count / 4 if rims != null else 0

func chips_node() -> Node3D:
	return _chips

static func core_color(tint: Color) -> Color:
	if tint.a <= 0.0:
		return EMPTY
	return Color(tint.r * CORE_ENERGY, tint.g * CORE_ENERGY, tint.b * CORE_ENERGY)

func cell_count() -> int:
	return _cells.size()

func cell_node(index: int) -> Node3D:
	return _cells[index]

func shown_core(index: int) -> Color:
	return _cores[index].albedo_color

## Die Oberkante einer Zelle über dem Tisch.
func top_height() -> float:
	return LIFT + _size.y * TUBE_SHARE

func _rebuild(count: int, size: Vector2) -> void:
	for cell in _cells:
		remove_child(cell)
		cell.queue_free()
	_cells.clear()
	_cores.clear()
	_size = size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var steel := ChipFrameView._skin(STEEL, 0.4)
	var glass := _flat(GLASS, true)
	var glint := _flat(GLINT, true)
	for i in count:
		var core := _flat(EMPTY, false)
		_cores.append(core)
		var cell := _build_cell(size, steel, glass, glint, core)
		cell.name = "Zelle%d" % i
		add_child(cell)
		_cells.append(cell)

static func _flat(color: Color, sheer: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if sheer:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

## Lokal +X = längs (Bild-oben), +Z = quer; der Ursprung liegt auf dem Tisch.
func _build_cell(size: Vector2, steel: Material, glass: Material, glint: Material,
		core: Material) -> Node3D:
	var cell := Node3D.new()
	var radius := size.y * TUBE_SHARE * 0.5
	var axis := LIFT + radius
	_rod(cell, "Kern", radius * CORE_SHARE, size.x * (GLASS_LENGTH - 0.04), 0.0, axis, core)
	for side: float in [-1.0, 1.0]:
		var at := side * size.x * (GLASS_LENGTH + CAP_LENGTH) * 0.5
		_rod(cell, "Kappe", radius, size.x * CAP_LENGTH, at, axis, steel)
		var clip := MeshInstance3D.new()
		clip.name = "Klemme"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(CLIP_THICK, axis + radius * 0.5, size.y * 0.7)
		clip.mesh = mesh
		clip.position = Vector3(side * (size.x * 0.5 - CLIP_THICK * 0.5), mesh.size.y * 0.5, 0.0)
		clip.material_override = steel
		clip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cell.add_child(clip)
	_rod(cell, "Glas", radius * 0.97, size.x * GLASS_LENGTH, 0.0, axis, glass)
	var shine := MeshInstance3D.new()
	shine.name = "Glanz"
	var strip := BoxMesh.new()
	strip.size = Vector3(size.x * GLASS_LENGTH * 0.8, 0.004, radius * 0.22)
	shine.mesh = strip
	shine.position = Vector3(0.0, axis + radius * 0.93, -radius * 0.35)
	shine.material_override = glint
	shine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cell.add_child(shine)
	return cell

## Ein liegender Zylinder längs lokal X.
func _rod(parent: Node3D, part: String, radius: float, length: float, at: float, height: float,
		material: Material) -> void:
	var rod := MeshInstance3D.new()
	rod.name = part
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 20
	mesh.rings = 1
	rod.mesh = mesh
	rod.rotation.z = PI * 0.5
	rod.position = Vector3(at, height, 0.0)
	rod.material_override = material
	rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(rod)
