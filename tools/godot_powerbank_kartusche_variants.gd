extends SceneTree
## Fumble: drei AUSARBEITUNGEN der Powerbank "Kartusche" (Spieler-Wahl aus
## tools/godot_powerbank_variants.gd). Reine Sichtprobe, nichts davon ist im Spiel. Aufruf:
##   Godot --path . --resolution 1280x720 --position 4000,2400 --quit-after 900 \
##     --script tools/godot_powerbank_kartusche_variants.gd
## Bilder: E:/Generated Images/Fumble/powerbank_kartusche_2026-11-22/

const OUT := "E:/Generated Images/Fumble/powerbank_kartusche_2026-11-22/"
const NAMES := ["a_labor", "b_reaktor", "c_juwel"]
const TITLES := ["A · LABOR", "B · REAKTOR", "C · JUWEL"]
const VIEWS := ["station", "nah", "detail"]

const BLOCK := Vector3(1.04, 0.8, 5.4)
const ROW_PITCH := 1.2
const CELLS := 5
const CELL_PITCH := 0.86
const AXIS_Y := 0.5
## Ladung je gezeigtem Block (-1 = leerer Stellplatz).
const CHARGES := [5, 3, 0, -1]

const ENERGY := CasinoStyle.ENERGY
const FELT := Color(0.07, 0.04, 0.12)
const STEEL := Color(0.42, 0.46, 0.52)
const GUN := Color(0.17, 0.19, 0.24)
const DARK := Color(0.07, 0.08, 0.11)
const LACQUER := Color(0.025, 0.025, 0.04)
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
	camera.near = 0.3
	camera.fov = 38.0
	root.add_child(camera)
	camera.current = true

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 4 or frames % 5 != 0:
		return false
	var views := VIEWS.size()
	@warning_ignore("integer_division")
	var variant := step / views
	var view := step % views
	if step > 0:
		var last := step - 1
		var shot := root.get_texture().get_image()
		@warning_ignore("integer_division")
		shot.save_png(OUT + "%s_%s.png" % [NAMES[last / views], VIEWS[last % views]])
		shots.append(shot)
	if variant >= NAMES.size():
		_save_sheet()
		return true
	match view:
		0:
			if scene != null:
				scene.queue_free()
			scene = Node3D.new()
			root.add_child(scene)
			_build(variant)
			var forward := Vector3(0.2588, -0.9659, 0.0)
			camera.look_at_from_position(Vector3(-0.3, 0.0, 0.0) - forward * 10.5,
				Vector3(-0.3, 0.0, 0.0), Vector3(1, 0, 0))
		1:
			camera.look_at_from_position(Vector3(-5.4, 3.6, -4.6), Vector3(-0.5, 0.2, -0.4),
				Vector3(0, 1, 0))
		2:
			camera.look_at_from_position(Vector3(-4.3, 1.9, -3.9), Vector3(-1.5, 0.45, -1.5),
				Vector3(0, 1, 0))
	step += 1
	return false

## Alle Aufnahmen auf EINEM Blatt: je Entwurf eine Zeile.
func _save_sheet() -> void:
	var cell := Vector2i(640, 360)
	var views := VIEWS.size()
	var sheet := Image.create(cell.x * views, cell.y * NAMES.size(), false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var small := shots[i].duplicate() as Image
		small.convert(Image.FORMAT_RGBA8)
		small.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		@warning_ignore("integer_division")
		sheet.blit_rect(small, Rect2i(Vector2i.ZERO, cell),
			Vector2i((i % views) * cell.x, (i / views) * cell.y))
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

func flat(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func glass(color: Color, alpha: float) -> StandardMaterial3D:
	var m := mat(color, 0.25, 0.1, 0.08)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = alpha
	m.render_priority = 1
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

## Stehender Zylinder.
func post(host: Node3D, radius: float, high: float, at: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius
	mesh.height = high
	mesh.radial_segments = 16
	add(host, mesh, at, material)

## Zylinder längs der Kartusche (Z) auf ihrer Achse.
func tube(host: Node3D, radius: float, length: float, z: float, material: Material,
		segments := 32) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius
	mesh.height = length
	mesh.radial_segments = segments
	var node := add(host, mesh, Vector3(0, AXIS_Y, z), material)
	node.rotation.x = PI * 0.5
	return node

## Ring um die Achse der Kartusche.
func hoop(host: Node3D, inner: float, outer: float, z: float, material: Material) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 12
	add(host, mesh, Vector3(0, AXIS_Y, z), material).rotation.x = PI * 0.5

func ball(host: Node3D, radius: float, at: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
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

func cell_z(i: int) -> float:
	return (float(i) - float(CELLS - 1) * 0.5) * CELL_PITCH

func band_z(i: int) -> float:
	return (float(i) - float(CELLS) * 0.5) * CELL_PITCH

## Plasma einer Zelle: weicher Mantel um einen hellen Kern; leer bleibt die Elektrode.
func plasma(host: Node3D, z: float, radius: float, length: float, lit: bool) -> void:
	if lit:
		tube(host, radius, length, z, flat(ENERGY * 0.75, 0.55))
		tube(host, radius * 0.5, length, z, flat(ENERGY.lerp(Color.WHITE, 0.45)))
	else:
		tube(host, radius, length, z, flat(ENERGY * 0.16, 0.5))
		tube(host, radius * 0.16, length, z, mat(STEEL, 0.4, 0.8, 0.3))

# --- Die Szene -----------------------------------------------------------------------

func _build(variant: int) -> void:
	box(scene, Vector3(12.0, 0.04, 14.0), Vector3(0, -0.02, 0), mat(FELT, 0.5, 0.0, 0.95))
	var steel := mat(Color(0.36, 0.4, 0.46), 0.5, 0.5, 0.4)
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
			0: _labor(block, charge)
			1: _reaktor(block, charge)
			2: _juwel(block, charge)
	text(scene, TITLES[variant], Vector3(-deep * 0.5 - 0.7, 0.02, 0), 0.5, Color(1.2, 1.2, 1.15))
	text(scene, "voll · 3 von 5 · leer · freier Platz", Vector3(-deep * 0.5 - 1.35, 0.02, 0), 0.26,
		Color(0.7, 0.72, 0.85))

## A · Präzisions-Kartusche: gerändelte Stahlkappen, feine Goldringe, zwei Klemmbacken
## mit Schrauben, Status-Lampe auf der Kappe.
func _labor(block: Node3D, charge: int) -> void:
	var steel := mat(STEEL, 0.5, 0.85, 0.28)
	var dark := mat(DARK, 0.6, 0.4, 0.4)
	var gold := mat(GOLD, 0.7, 0.85, 0.25)
	box(block, Vector3(0.62, 0.07, 5.0), Vector3(0, 0.035, 0), dark)
	box(block, Vector3(0.03, 0.02, 4.8), Vector3(-0.27, 0.075, 0), gold)
	for i in CELLS + 1:
		box(block, Vector3(0.1, 0.02, 0.03), Vector3(-0.2, 0.075, band_z(i)), steel)
	for side: float in [-1.0, 1.0]:
		var z := side * 1.29
		box(block, Vector3(0.98, 0.14, 0.2), Vector3(0, 0.07, z), dark)
		for jaw: float in [-1.0, 1.0]:
			box(block, Vector3(0.09, 0.5, 0.2), Vector3(jaw * 0.445, 0.33, z), steel)
			post(block, 0.05, 0.03, Vector3(jaw * 0.445, 0.595, z), gold)
		tube(block, 0.42, 0.34, side * 2.42, steel)
		for k in 4:
			tube(block, 0.44, 0.035, side * (2.3 + float(k) * 0.08), dark)
		tube(block, 0.3, 0.06, side * 2.62, dark)
		tube(block, 0.15, 0.16, side * 2.66, gold)
		var on := charge > 0
		box(block, Vector3(0.09, 0.03, 0.09), Vector3(0, AXIS_Y + 0.425, side * 2.2),
			flat(ENERGY * (1.0 if on else 0.15)))
	for i in CELLS:
		plasma(block, cell_z(i), 0.27, 0.74, i < charge)
	for i in CELLS + 1:
		tube(block, 0.385, 0.07, band_z(i), steel)
		tube(block, 0.392, 0.02, band_z(i), gold)
	tube(block, 0.365, 4.5, 0, glass(Color(0.62, 0.86, 0.96), 0.2))

## B · Gepanzert: Sechskant-Kappen mit Lüftungsschlitzen, zwei Schutzholme, Kupferspulen
## zwischen den Zellen.
func _reaktor(block: Node3D, charge: int) -> void:
	var gun := mat(GUN, 0.6, 0.8, 0.35)
	var steel := mat(STEEL, 0.5, 0.85, 0.3)
	var copper := mat(COPPER, 0.6, 0.8, 0.3)
	var dark := mat(DARK, 0.6, 0.3, 0.5)
	box(block, Vector3(0.9, 0.1, 5.2), Vector3(0, 0.05, 0), gun)
	for side: float in [-1.0, 1.0]:
		box(block, Vector3(0.06, 0.03, 5.0), Vector3(side * 0.4, 0.115, 0), flat(ENERGY * (0.5 if charge > 0 else 0.1)))
		tube(block, 0.47, 0.44, side * 2.44, gun, 6)
		tube(block, 0.36, 0.06, side * 2.68, dark, 6)
		tube(block, 0.13, 0.14, side * 2.72, copper)
		for k in 3:
			box(block, Vector3(0.36, 0.02, 0.05), Vector3(0, AXIS_Y + 0.41, side * (2.32 + float(k) * 0.11)), dark)
		for rail: float in [-1.0, 1.0]:
			box(block, Vector3(0.08, 0.08, 0.36), Vector3(rail * 0.36, AXIS_Y + 0.21, side * 2.1), gun)
	# Zwei Schutzholme schräg oben - die Mitte bleibt für den Blick von oben frei.
	for rail: float in [-1.0, 1.0]:
		var bar := box(block, Vector3(0.07, 0.07, 4.5), Vector3(rail * 0.36, AXIS_Y + 0.21, 0), steel)
		bar.rotation.z = -rail * PI / 3.0
		for i in CELLS + 1:
			ball(block, 0.035, Vector3(rail * 0.385, AXIS_Y + 0.25, band_z(i)), copper)
	for i in CELLS:
		plasma(block, cell_z(i), 0.25, 0.66, i < charge)
	for i in CELLS + 1:
		for k in 3:
			hoop(block, 0.28, 0.4, band_z(i) + (float(k) - 1.0) * 0.055, copper)
	for i in [1, 4]:
		box(block, Vector3(0.7, 0.34, 0.14), Vector3(0, 0.22, band_z(i)), gun)
	tube(block, 0.33, 4.5, 0, glass(Color(0.62, 0.86, 0.96), 0.2))

## C · Schmuckstück: schwarzer Lack mit Goldringen, facettiertes Glas, jede Zelle drei
## Lichtscheiben auf einer Goldspindel, Ladepunkte auf dem Sockel.
func _juwel(block: Node3D, charge: int) -> void:
	var lacquer := mat(LACQUER, 0.6, 0.5, 0.12)
	var gold := mat(GOLD, 0.7, 0.9, 0.22)
	box(block, Vector3(0.96, 0.12, 5.3), Vector3(0, 0.06, 0), lacquer)
	for side: float in [-1.0, 1.0]:
		box(block, Vector3(0.03, 0.02, 5.3), Vector3(side * 0.465, 0.13, 0), gold)
		box(block, Vector3(0.96, 0.02, 0.03), Vector3(0, 0.13, side * 2.635), gold)
		tube(block, 0.42, 0.38, side * 2.44, lacquer)
		hoop(block, 0.4, 0.45, side * 2.27, gold)
		hoop(block, 0.4, 0.45, side * 2.61, gold)
		ball(block, 0.2, Vector3(0, AXIS_Y, side * 2.66), gold)
		# Goldene Gabel, in der die Kartusche ruht.
		for jaw: float in [-1.0, 1.0]:
			var arm := box(block, Vector3(0.07, 0.36, 0.1), Vector3(jaw * 0.36, 0.27, side * 1.72), gold)
			arm.rotation.z = jaw * 0.35
		box(block, Vector3(0.5, 0.06, 0.1), Vector3(0, 0.15, side * 1.72), gold)
	for i in CELLS:
		var z := cell_z(i)
		var lit := i < charge
		for k in 3:
			var disc := flat(ENERGY * (0.95 - 0.12 * absf(float(k) - 1.0))) if lit else flat(ENERGY * 0.14)
			tube(block, 0.27, 0.1, z + (float(k) - 1.0) * 0.22, disc)
		if lit:
			tube(block, 0.3, 0.7, z, flat(ENERGY * 0.6, 0.3))
		var pip := box(block, Vector3(0.11, 0.02, 0.11), Vector3(-0.4, 0.13, z),
			flat(ENERGY * (1.0 if lit else 0.14)))
		pip.rotation.y = PI * 0.25
	tube(block, 0.035, 4.7, 0, gold)
	for i in CELLS + 1:
		hoop(block, 0.355, 0.395, band_z(i), gold)
	tube(block, 0.37, 4.5, 0, glass(Color(0.7, 0.88, 0.96), 0.2), 8)
