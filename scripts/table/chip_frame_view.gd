class_name ChipFrameView
extends Node3D
## Fassungen im Prozessor-Stil: der HEATSPREADER um ein Fenster (Flansch plus Deckelrahmen,
## Gravur, Pin-1-Marke) und der SOCKEL-RAHMEN um die Wurfgrube (hoher Stahlrahmen, Hebel).
## Ursprung = Fenstermitte auf der Tischebene, X = Bild-oben, Z = Bild-rechts.

const STEEL_SHADER := preload("res://assets/shaders/chip_steel.gdshader")
const STEEL := Color(0.4, 0.42, 0.46)
const STEEL_DARK := Color(0.2, 0.21, 0.25)
const GOLD := Color(0.83, 0.6, 0.22)
const ETCH := Color(0.06, 0.06, 0.075)
const CORNER_STEPS := 8
const BEVEL_STEPS := 4

## Heatspreader: der Deckel reicht über die Fensterkante hinaus, seine Lippe hinein.
const LID_OUT := 0.5
const LID_HEIGHT := 0.3
const LID_BEVEL := 0.13
const FLANGE_HEIGHT := 0.09
const FLANGE_BEVEL := 0.04
const ETCH_SIZE := 0.3
const PIN_MARK := 0.24

## Sockel: die Kollisionswand der Grube steht eine halbe Wandstärke innen, der Rahmen davor.
const SOCKET_OUT := 0.3
const SOCKET_IN := 0.45
const SOCKET_HEIGHT := 0.3
const SOCKET_BEVEL := 0.11
const LIP := 0.035
const LEVER_RADIUS := 0.09
const LEVER_OFFSET := 0.14
const LEVER_HEIGHT := 0.2

static var _skins := {}

## half = halbe Fenstergröße (X, Z), radius = Eckenradius des Fensters; lid_in = wie weit
## die Lippe über den Fensterrand greift, flange_out = wie weit der Flansch hinausreicht.
func setup_spreader(half: Vector2, radius: float, mark: String, lid_in := 0.3,
		flange_out := 0.7) -> void:
	_clear()
	_ring("Flansch", half, radius,
		collar(-flange_out, -LID_OUT + 0.06, FLANGE_HEIGHT, FLANGE_BEVEL), _skin(STEEL_DARK, 0.3))
	_ring("Deckel", half, radius, collar(-LID_OUT, lid_in, LID_HEIGHT, LID_BEVEL),
		_skin(STEEL, 0.4))
	var rim := (LID_OUT - lid_in) * 0.5
	var flat := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	var etch := Label3D.new()
	etch.name = "Gravur"
	etch.text = mark
	etch.pixel_size = ETCH_SIZE / 64.0
	etch.font_size = 64
	etch.outline_size = 0
	etch.modulate = ETCH
	etch.shaded = false
	etch.transform = Transform3D(flat, Vector3(-half.x - rim, LID_HEIGHT + 0.004, 0.0))
	add_child(etch)
	var pin := MeshInstance3D.new()
	pin.name = "Pin1"
	var prism := PrismMesh.new()
	prism.size = Vector3(PIN_MARK, PIN_MARK, 0.012)
	pin.mesh = prism
	pin.material_override = _skin(GOLD, 0.2, 0.5)
	pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pin.transform = Transform3D(flat,
		Vector3(-half.x - rim, LID_HEIGHT + 0.006, -half.y + maxf(radius, 0.6)))
	add_child(pin)

## drop = so tief liegt der Grubenboden unter dem Tisch; die Innenwand reicht bis dorthin.
func setup_socket(half: Vector2, radius: float, glow: Color, drop := 0.0) -> void:
	_clear()
	var profile := collar(-SOCKET_OUT, SOCKET_IN, SOCKET_HEIGHT, SOCKET_BEVEL)
	profile[profile.size() - 1] = Vector2(SOCKET_IN, -drop)
	_ring("Rahmen", half, radius, profile, _skin(STEEL, 0.4))
	_ring("Lippe", half, radius, [Vector2(SOCKET_IN - LIP, 0.02 - drop),
		Vector2(SOCKET_IN - LIP, 0.09 - drop)], _skin(glow, 0.0, 0.5))
	# Der Hebel liegt Bild-oben neben dem Rahmen, sein Griff am rechten Ende.
	var x := half.x + SOCKET_OUT + LEVER_OFFSET
	var reach := half.y - radius
	_rod("Hebel", Vector3(x, LEVER_HEIGHT, 0.0), reach * 2.0, LEVER_RADIUS, _skin(STEEL, 0.2))
	_rod("Griff", Vector3(x, LEVER_HEIGHT, reach - 0.5), 1.0, LEVER_RADIUS * 1.5,
		_skin(STEEL_DARK, 0.0))
	for s in [-0.5, 0.5]:
		var block := MeshInstance3D.new()
		block.name = "Lager"
		var box := BoxMesh.new()
		box.size = Vector3(LEVER_RADIUS * 3.4, LEVER_HEIGHT + LEVER_RADIUS * 1.5, 0.5)
		block.mesh = box
		block.material_override = _skin(STEEL_DARK, 0.2)
		block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		block.position = Vector3(x - LEVER_RADIUS * 0.4, box.size.y * 0.5, reach * s)
		add_child(block)

## Das Profil eines Kragens: außen hoch, beide Oberkanten gerundet, innen hinunter.
static func collar(outer: float, inner: float, height: float, bevel: float) -> Array:
	var profile := [Vector2(outer, 0.0)]
	for k in BEVEL_STEPS + 1:
		var t := PI * 0.5 * float(k) / float(BEVEL_STEPS)
		profile.append(Vector2(outer + bevel - bevel * cos(t), height - bevel + bevel * sin(t)))
	for k in BEVEL_STEPS + 1:
		var t := PI * 0.5 * float(k) / float(BEVEL_STEPS)
		profile.append(Vector2(inner - bevel + bevel * sin(t), height - bevel + bevel * cos(t)))
	profile.append(Vector2(inner, 0.0))
	return profile

## Ein gerundetes Rechteck, um inset nach innen versetzt (negativ = nach außen).
static func loop(half: Vector2, radius: float, inset: float, height: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var r := maxf(radius - inset, 0.001)
	var c := Vector2(half.x - radius, half.y - radius)
	var corners := [[Vector2(c.x, c.y), 0.0], [Vector2(-c.x, c.y), 90.0],
		[Vector2(-c.x, -c.y), 180.0], [Vector2(c.x, -c.y), 270.0]]
	for corner in corners:
		var at: Vector2 = corner[0]
		for k in CORNER_STEPS + 1:
			var a := deg_to_rad(float(corner[1]) + 90.0 * float(k) / float(CORNER_STEPS))
			points.append(Vector3(at.x + r * cos(a), height, at.y + r * sin(a)))
	return points

## Ein Ring längs des gerundeten Rechtecks: profile = Folge aus (Versatz nach innen, Höhe).
## Glatt schattiert - die Rundungen des Profils lesen als Rundungen.
static func ring_mesh(half: Vector2, radius: float, profile: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 4 * (CORNER_STEPS + 1)
	for step: Vector2 in profile:
		for p in loop(half, radius, step.x, step.y):
			tool.add_vertex(p)
	for k in profile.size() - 1:
		for i in n:
			var j := (i + 1) % n
			var a := k * n
			var b := (k + 1) * n
			for index: int in [a + i, a + j, b + j, a + i, b + j, b + i]:
				tool.add_index(index)
	tool.generate_normals()
	return tool.commit()

func _ring(part: String, half: Vector2, radius: float, profile: Array, material: Material) -> void:
	var body := MeshInstance3D.new()
	body.name = part
	body.mesh = ring_mesh(half, radius, profile)
	body.material_override = material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)

func _rod(part: String, at: Vector3, length: float, radius: float, material: Material) -> void:
	var body := MeshInstance3D.new()
	body.name = part
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	body.mesh = mesh
	body.material_override = material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at)
	add_child(body)

func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

static func _skin(color: Color, brush: float, glow := 0.0) -> ShaderMaterial:
	var key := "%s|%.2f|%.2f" % [color.to_html(false), brush, glow]
	if not _skins.has(key):
		var material := ShaderMaterial.new()
		material.shader = STEEL_SHADER
		material.set_shader_parameter("base", Vector3(color.r, color.g, color.b))
		material.set_shader_parameter("brush", brush)
		material.set_shader_parameter("glow", glow)
		_skins[key] = material
	return _skins[key]
