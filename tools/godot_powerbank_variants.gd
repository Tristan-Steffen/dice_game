extends SceneTree
## Fumble: fünf ENTWÜRFE für die POWERBANK (ein Block der Akku-Bank, fünf Energien). Reine
## Sichtprobe, nichts davon ist im Spiel. Aufruf:
##   Godot --path . --resolution 1280x720 --position 4000,2400 --quit-after 900 \
##     --script tools/godot_powerbank_variants.gd
## Bilder: E:/Generated Images/Fumble/powerbank_entwuerfe_2026-11-22/

const OUT := "E:/Generated Images/Fumble/powerbank_entwuerfe_2026-11-22/"
const NAMES := ["1_barren", "2_kristall", "3_ringkern", "4_kartusche", "5_lamellen"]
const TITLES := ["1 · BARREN", "2 · KRISTALL", "3 · RINGKERN", "4 · KARTUSCHE", "5 · LAMELLEN"]

## Ein Block wie im Spiel: x tief, y hoch, z lang; Stellplätze im Raster der Bank.
const BLOCK := Vector3(1.04, 0.8, 5.4)
const ROW_PITCH := 1.2
const CELLS := 5
## Ladung je gezeigtem Block (-1 = leerer Stellplatz).
const CHARGES := [5, 3, 0, -1]

const ENERGY := CasinoStyle.ENERGY
const FELT := Color(0.07, 0.04, 0.12)
const STEEL := Color(0.36, 0.4, 0.46)
const DARK := Color(0.1, 0.11, 0.15)
const GOLD := Color(0.86, 0.66, 0.28)
const COPPER := Color(0.85, 0.45, 0.2)

var camera: Camera3D
var scene: Node3D
var frames := 0
var step := 0
var shots: Array[Image] = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.015, 0.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.5, 0.75)
	e.ambient_light_energy = 0.22
	e.glow_enabled = true
	e.glow_hdr_threshold = 0.95
	e.glow_intensity = 0.7
	env.environment = e
	root.add_child(env)
	var light := OmniLight3D.new()
	light.position = Vector3(6.0, 17.0, 0.0)
	light.omni_range = 60.0
	light.light_energy = 1.3
	root.add_child(light)
	camera = Camera3D.new()
	camera.near = 0.5
	camera.fov = 38.0
	root.add_child(camera)
	camera.current = true

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 4 or frames % 5 != 0:
		return false
	var variant := step / 2
	var view := step % 2
	if step > 0:
		var last := step - 1
		var shot := root.get_texture().get_image()
		shot.save_png(OUT + "%s_%s.png" % [NAMES[last / 2], "station" if last % 2 == 0 else "nah"])
		shots.append(shot)
	if variant >= NAMES.size():
		_save_sheet()
		return true
	if view == 0:
		if scene != null:
			scene.queue_free()
		scene = Node3D.new()
		root.add_child(scene)
		_build(variant)
		var forward := Vector3(0.2588, -0.9659, 0.0)
		camera.look_at_from_position(Vector3(-0.3, 0.0, 0.0) - forward * 10.5,
			Vector3(-0.3, 0.0, 0.0), Vector3(1, 0, 0))
	else:
		camera.look_at_from_position(Vector3(-5.4, 3.6, -4.6), Vector3(-0.5, 0.2, -0.4),
			Vector3(0, 1, 0))
	step += 1
	return false

## Alle Aufnahmen auf EINEM Blatt: je Entwurf eine Zeile, links Station, rechts nah.
func _save_sheet() -> void:
	var cell := Vector2i(640, 360)
	var sheet := Image.create(cell.x * 2, cell.y * NAMES.size(), false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var small := shots[i].duplicate() as Image
		small.convert(Image.FORMAT_RGBA8)
		small.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		@warning_ignore("integer_division")
		sheet.blit_rect(small, Rect2i(Vector2i.ZERO, cell), Vector2i((i % 2) * cell.x, (i / 2) * cell.y))
	sheet.save_png(OUT + "blatt.png")

# --- Bausteine ---------------------------------------------------------------------

func mat(color: Color, glow := 0.3, metallic := 0.0, roughness := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = glow
	return m

## Licht einer Zelle: geladen hell, leer ein Glimmen.
func cell_light(lit: bool, tint := ENERGY) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = tint * (0.85 if lit else 0.12)
	return m

func glass(color: Color, alpha: float) -> StandardMaterial3D:
	var m := mat(color, 0.25, 0.1, 0.1)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = alpha
	return m

func add(host: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	host.add_child(node)
	return node

func box(host: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return add(host, mesh, at, material)

## Zylinder; axis 1 = stehend, 2 = längs Z. top < 0 = gleicher Radius oben.
func cyl(host: Node3D, radius: float, high: float, at: Vector3, material: Material,
		axis := 1, segments := 24, top := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = high
	mesh.radial_segments = segments
	var node := add(host, mesh, at, material)
	if axis == 2:
		node.rotation.x = PI * 0.5
	return node

func torus(host: Node3D, inner: float, outer: float, at: Vector3, material: Material) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 16
	add(host, mesh, at, material)

func text(host: Node3D, body: String, at: Vector3, high: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = body
	label.font_size = 64
	label.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	label.pixel_size = high / 46.0
	label.modulate = color
	label.outline_size = 6
	label.position = at
	host.add_child(label)

func cell_z(i: int, pitch: float) -> float:
	return (float(i) - float(CELLS - 1) * 0.5) * pitch

# --- Die Szene -----------------------------------------------------------------------

func _build(variant: int) -> void:
	box(scene, Vector3(12.0, 0.04, 14.0), Vector3(0, -0.02, 0), mat(FELT, 0.5, 0.0, 0.95))
	var steel := mat(STEEL, 0.5, 0.5, 0.4)
	var rows := CHARGES.size()
	var deep := ROW_PITCH * float(rows) + 0.6
	box(scene, Vector3(deep, 0.1, 6.2), Vector3(0, 0.05, 0), mat(Color(0.04, 0.05, 0.08), 0.6, 0.1, 0.8))
	for side: float in [-1.0, 1.0]:
		box(scene, Vector3(deep, 0.45, 0.2), Vector3(0, 0.225, side * 3.0), steel)
		box(scene, Vector3(0.3, 0.45, 6.2), Vector3(side * (deep * 0.5 - 0.15), 0.225, 0), steel)
	for row in rows:
		var x := (float(row) - float(rows - 1) * 0.5) * ROW_PITCH
		box(scene, Vector3(BLOCK.x, 0.03, BLOCK.z), Vector3(x, 0.115, 0), mat(Color(0.09, 0.11, 0.15), 0.6))
		var charge: int = CHARGES[row]
		if charge < 0:
			continue
		var block := Node3D.new()
		block.position = Vector3(x, 0.1, 0)
		scene.add_child(block)
		match variant:
			0: _barren(block, charge)
			1: _kristall(block, charge)
			2: _ringkern(block, charge)
			3: _kartusche(block, charge)
			4: _lamellen(block, charge)
	text(scene, TITLES[variant], Vector3(-deep * 0.5 - 0.7, 0.02, 0), 0.5, Color(1.2, 1.2, 1.15))
	text(scene, "voll · 3 von 5 · leer · freier Platz", Vector3(-deep * 0.5 - 1.35, 0.02, 0), 0.26,
		Color(0.7, 0.72, 0.85))

## 1 · Schlanker Alu-Barren, obenauf EINE Ladeleiste in fünf Segmenten, Goldfasen.
func _barren(block: Node3D, charge: int) -> void:
	var shell := mat(Color(0.13, 0.14, 0.19), 0.7, 0.7, 0.35)
	var cap := mat(STEEL, 0.6, 0.8, 0.3)
	var gold := mat(GOLD, 0.7, 0.8, 0.3)
	box(block, Vector3(0.96, 0.5, 4.9), Vector3(0, 0.25, 0), shell)
	box(block, Vector3(0.74, 0.05, 4.7), Vector3(0, 0.525, 0), mat(Color(0.03, 0.035, 0.05), 0.4, 0.3, 0.2))
	for side: float in [-1.0, 1.0]:
		box(block, Vector3(0.04, 0.04, 4.9), Vector3(side * 0.44, 0.5, 0), gold)
		box(block, Vector3(1.0, 0.58, 0.22), Vector3(0, 0.29, side * 2.56), cap)
	for i in CELLS:
		box(block, Vector3(0.34, 0.03, 0.8), Vector3(0, 0.56, cell_z(i, 0.9)), cell_light(i < charge))
	cyl(block, 0.13, 0.08, Vector3(0, 0.62, -2.56), gold)
	cyl(block, 0.13, 0.08, Vector3(0, 0.62, 2.56), cap)

## 2 · Fünf geschliffene Kristalle in goldenen Fassungen auf schwarzer Schiene.
func _kristall(block: Node3D, charge: int) -> void:
	var rail := mat(Color(0.05, 0.05, 0.08), 0.5, 0.4, 0.25)
	var gold := mat(GOLD, 0.7, 0.8, 0.3)
	box(block, Vector3(0.96, 0.2, 5.3), Vector3(0, 0.1, 0), rail)
	for side: float in [-1.0, 1.0]:
		box(block, Vector3(0.04, 0.03, 5.3), Vector3(side * 0.45, 0.21, 0), gold)
	for i in CELLS:
		var z := cell_z(i, 1.02)
		var lit := i < charge
		cyl(block, 0.42, 0.07, Vector3(0, 0.235, z), gold, 1, 6)
		cyl(block, 0.34, 0.03, Vector3(0, 0.275, z), cell_light(lit), 1, 6)
		var gem := glass(ENERGY if lit else Color(0.35, 0.45, 0.55), 0.75 if lit else 0.35)
		gem.emission_energy_multiplier = 1.5 if lit else 0.15
		cyl(block, 0.32, 0.3, Vector3(0, 0.43, z), gem, 1, 6)
		cyl(block, 0.32, 0.26, Vector3(0, 0.71, z), gem, 1, 6, 0.0)

## 3 · Fünf Kupfer-Ringkerne auf einer Stahlschiene, der Kern leuchtet geladen.
func _ringkern(block: Node3D, charge: int) -> void:
	var plate := mat(Color(0.16, 0.18, 0.23), 0.6, 0.7, 0.35)
	var copper := mat(COPPER, 0.6, 0.7, 0.35)
	box(block, Vector3(0.96, 0.16, 5.3), Vector3(0, 0.08, 0), plate)
	box(block, Vector3(0.1, 0.05, 5.0), Vector3(0.4, 0.185, 0), copper)
	for i in CELLS:
		var z := cell_z(i, 1.02)
		var lit := i < charge
		cyl(block, 0.46, 0.04, Vector3(0, 0.18, z), mat(Color(0.04, 0.05, 0.07), 0.4))
		torus(block, 0.2, 0.44, Vector3(0, 0.32, z), copper)
		cyl(block, 0.17, 0.42, Vector3(0, 0.37, z), cell_light(lit))
		torus(block, 0.15, 0.21, Vector3(0, 0.58, z), mat(STEEL, 0.6, 0.8, 0.3))
		if lit:
			cyl(block, 0.47, 0.02, Vector3(0, 0.205, z), cell_light(true, ENERGY * 0.4))

## 4 · Liegende Glas-Kartusche: fünf Plasma-Abschnitte zwischen Metallbändern, in zwei Klammern.
func _kartusche(block: Node3D, charge: int) -> void:
	var steel := mat(STEEL, 0.6, 0.8, 0.3)
	var dark := mat(DARK, 0.5, 0.4, 0.4)
	var gold := mat(GOLD, 0.7, 0.8, 0.3)
	box(block, Vector3(0.7, 0.08, 5.2), Vector3(0, 0.04, 0), dark)
	for side: float in [-1.0, 1.0]:
		box(block, Vector3(0.96, 0.3, 0.3), Vector3(0, 0.15, side * 1.6), dark)
		cyl(block, 0.42, 0.4, Vector3(0, 0.5, side * 2.45), steel, 2)
		cyl(block, 0.16, 0.12, Vector3(0, 0.5, side * 2.7), gold, 2)
	for i in CELLS:
		cyl(block, 0.27, 0.72, Vector3(0, 0.5, cell_z(i, 0.86)), cell_light(i < charge), 2)
	for i in CELLS + 1:
		cyl(block, 0.38, 0.08, Vector3(0, 0.5, (float(i) - float(CELLS) * 0.5) * 0.86), steel, 2)
	cyl(block, 0.36, 4.4, Vector3(0, 0.5, 0), glass(Color(0.6, 0.85, 0.95), 0.22), 2)

## 5 · Kühlkörper: je Zelle ein Lamellen-Paket, das Licht steht zwischen den Rippen.
func _lamellen(block: Node3D, charge: int) -> void:
	var body := mat(Color(0.11, 0.12, 0.16), 0.6, 0.6, 0.4)
	var fin := mat(Color(0.3, 0.33, 0.39), 0.5, 0.8, 0.3)
	box(block, Vector3(0.96, 0.22, 5.3), Vector3(0, 0.11, 0), body)
	for i in CELLS + 1:
		box(block, Vector3(0.96, 0.62, 0.1), Vector3(0, 0.31, (float(i) - float(CELLS) * 0.5) * 1.04), body)
	for i in CELLS:
		var z := cell_z(i, 1.04)
		var lit := i < charge
		box(block, Vector3(0.8, 0.04, 0.9), Vector3(0, 0.24, z), cell_light(lit))
		var lit_fin := fin
		if lit:
			lit_fin = mat(Color(0.3, 0.33, 0.39).lerp(ENERGY, 0.25), 0.7, 0.8, 0.3)
		for k in 6:
			box(block, Vector3(0.86, 0.36, 0.05), Vector3(0, 0.42, z + (float(k) - 2.5) * 0.145), lit_fin)
	box(block, Vector3(0.12, 0.05, 5.3), Vector3(-0.42, 0.645, 0), mat(GOLD, 0.7, 0.8, 0.3))
