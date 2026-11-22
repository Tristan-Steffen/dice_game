extends SceneTree
## Fumble: drei ANSCHLÜSSE der Powerbank "Kartusche Labor" (Spieler-Wahl aus
## tools/godot_powerbank_kartusche_variants.gd) - wie sie am Tisch andockt. Reine Sichtprobe, nichts davon ist im Spiel. Aufruf:
##   Godot --path . --resolution 1280x720 --position 4000,2400 --quit-after 900 \
##     --script tools/godot_powerbank_dock_variants.gd
## Bilder: E:/Generated Images/Fumble/powerbank_anschluss_2026-11-22/

const OUT := "E:/Generated Images/Fumble/powerbank_anschluss_2026-11-22/"
const NAMES := ["1_kiel", "2_sicherung", "3_stecker"]
const TITLES := ["1 · KONTAKTKIEL", "2 · SICHERUNGSHALTER", "3 · DOCK-STECKER"]
const VIEWS := ["station", "nah", "detail"]

const BLOCK := Vector3(1.04, 0.8, 5.4)
const ROW_PITCH := 1.2
const CELLS := 5
const CELL_PITCH := 0.86
## Achshöhe der Kartusche über dem Stellplatz.
const AXIS := 0.5
## Je Stellplatz von vorn: Ladung (-1 = frei) und ob die Kartusche angehoben gezeigt wird.
const ROWS := [[-1, false], [5, true], [3, false], [5, false]]

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
			camera.look_at_from_position(Vector3(-5.0, 2.3, -3.4), Vector3(-1.2, 0.7, -0.4),
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
	var node := add(host, mesh, Vector3(0, 0, z), material)
	node.rotation.x = PI * 0.5
	return node

## Ring um die Achse der Kartusche.
func hoop(host: Node3D, inner: float, outer: float, z: float, material: Material) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 12
	add(host, mesh, Vector3(0, 0, z), material).rotation.x = PI * 0.5

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
	var rows := ROWS.size()
	var deep := ROW_PITCH * float(rows) + 0.6
	box(scene, Vector3(deep, 0.1, 6.2), Vector3(0, 0.05, 0), mat(Color(0.04, 0.05, 0.08), 0.6, 0.1, 0.8))
	for side: float in [-1.0, 1.0]:
		box(scene, Vector3(deep, 0.45, 0.2), Vector3(0, 0.225, side * 3.0), steel)
		box(scene, Vector3(0.3, 0.45, 6.2), Vector3(side * (deep * 0.5 - 0.15), 0.225, 0), steel)
	for row in rows:
		var x := (float(row) - float(rows - 1) * 0.5) * ROW_PITCH
		var charge: int = ROWS[row][0]
		var lifted: bool = ROWS[row][1]
		var bay := Node3D.new()
		bay.position = Vector3(x, 0.1, 0)
		scene.add_child(bay)
		box(bay, Vector3(BLOCK.x, 0.03, BLOCK.z), Vector3(0, 0.015, 0), mat(Color(0.09, 0.11, 0.15), 0.6))
		var docked := charge >= 0 and not lifted
		match variant:
			0: _kiel_bay(bay, docked)
			1: _sicherung_bay(bay, docked)
			2: _stecker_bay(bay, docked)
		if charge < 0:
			continue
		var cart := Node3D.new()
		cart.position = Vector3(0, AXIS, 0)
		if lifted:
			# Angehoben und zum Betrachter gerollt: die Unterseite liegt offen.
			cart.position = Vector3(-0.25, AXIS + 1.05, 0)
			cart.rotation.z = -1.0
		bay.add_child(cart)
		_cartridge(cart, charge)
		match variant:
			0: _kiel_cart(cart)
			1: _sicherung_cart(cart)
			2: _stecker_cart(cart)
	text(scene, TITLES[variant], Vector3(-deep * 0.5 - 0.7, 0.02, 0), 0.5, Color(1.2, 1.2, 1.15))
	text(scene, "freier Platz · angehoben · 3 von 5 · voll", Vector3(-deep * 0.5 - 1.35, 0.02, 0), 0.26,
		Color(0.7, 0.72, 0.85))

## Die Kartusche "Labor" selbst, um ihre Achse gebaut: Kappen, Bänder, Plasma, Glas.
func _cartridge(cart: Node3D, charge: int) -> void:
	var steel := mat(STEEL, 0.5, 0.85, 0.28)
	var dark := mat(DARK, 0.6, 0.4, 0.4)
	var gold := mat(GOLD, 0.7, 0.85, 0.25)
	for side: float in [-1.0, 1.0]:
		tube(cart, 0.42, 0.34, side * 2.42, steel)
		for k in 4:
			tube(cart, 0.44, 0.035, side * (2.3 + float(k) * 0.08), dark)
		tube(cart, 0.3, 0.06, side * 2.62, dark)
		tube(cart, 0.15, 0.16, side * 2.66, gold)
		box(cart, Vector3(0.09, 0.03, 0.09), Vector3(0, 0.425, side * 2.2),
			flat(ENERGY * (1.0 if charge > 0 else 0.15)))
	for i in CELLS:
		plasma(cart, cell_z(i), 0.27, 0.74, i < charge)
	for i in CELLS + 1:
		tube(cart, 0.385, 0.07, band_z(i), steel)
		tube(cart, 0.392, 0.02, band_z(i), gold)
	tube(cart, 0.365, 4.5, 0, glass(Color(0.62, 0.86, 0.96), 0.2))

## Zwei Klemmbacken des Stellplatzes mit Schrauben (halten die Kartusche seitlich).
func _jaws(bay: Node3D, z: float) -> void:
	var steel := mat(STEEL, 0.5, 0.85, 0.28)
	for jaw: float in [-1.0, 1.0]:
		box(bay, Vector3(0.2, 0.08, 0.26), Vector3(jaw * 0.41, 0.07, z), mat(DARK, 0.6, 0.4, 0.4))
		box(bay, Vector3(0.09, 0.5, 0.2), Vector3(jaw * 0.445, 0.33, z), steel)
		post(bay, 0.05, 0.03, Vector3(jaw * 0.445, 0.595, z), mat(GOLD, 0.7, 0.85, 0.25))

func _contact_light(docked: bool) -> StandardMaterial3D:
	return flat(ENERGY * (0.9 if docked else 0.12))

# --- 1 · KONTAKTKIEL: ein Kiel unter der Kartusche fährt in eine Nut mit Kupferschienen ---

func _kiel_bay(bay: Node3D, docked: bool) -> void:
	var dark := mat(DARK, 0.6, 0.4, 0.4)
	var copper := mat(COPPER, 0.6, 0.8, 0.3)
	for side: float in [-1.0, 1.0]:
		box(bay, Vector3(0.07, 0.12, 4.5), Vector3(side * 0.17, 0.09, 0), dark)
		box(bay, Vector3(0.03, 0.015, 4.5), Vector3(side * 0.225, 0.04, 0), _contact_light(docked))
		box(bay, Vector3(0.22, 0.03, 0.56), Vector3(0, 0.045, side * 1.75), copper)
		# Kupferbahn vom Kontakt hinaus zum Holm: so liegt die Bank in Reihe.
		box(bay, Vector3(0.1, 0.02, 0.95), Vector3(0, 0.04, side * 2.5), copper)
		_jaws(bay, side * 1.29)

func _kiel_cart(cart: Node3D) -> void:
	var dark := mat(DARK, 0.6, 0.4, 0.4)
	var gold := mat(GOLD, 0.7, 0.85, 0.25)
	box(cart, Vector3(0.2, 0.1, 4.2), Vector3(0, -0.41, 0), dark)
	for side: float in [-1.0, 1.0]:
		box(cart, Vector3(0.16, 0.04, 0.5), Vector3(0, -0.475, side * 1.75), gold)
		box(cart, Vector3(0.22, 0.06, 0.08), Vector3(0, -0.43, side * 2.1), mat(STEEL, 0.5, 0.85, 0.28))

# --- 2 · SICHERUNGSHALTER: Federklammern greifen die goldenen Endstifte ---

func _sicherung_bay(bay: Node3D, docked: bool) -> void:
	var dark := mat(DARK, 0.6, 0.4, 0.4)
	var copper := mat(COPPER, 0.6, 0.8, 0.3)
	for side: float in [-1.0, 1.0]:
		var z := side * 2.62
		box(bay, Vector3(0.62, 0.1, 0.3), Vector3(0, 0.08, z), copper)
		for leaf: float in [-1.0, 1.0]:
			var spring := box(bay, Vector3(0.04, 0.6, 0.24), Vector3(leaf * 0.2, 0.4, z), copper)
			spring.rotation.z = leaf * 0.1
			box(bay, Vector3(0.1, 0.04, 0.24), Vector3(leaf * 0.27, 0.71, z), copper)
		box(bay, Vector3(0.08, 0.03, 0.08), Vector3(-0.42, 0.045, z), _contact_light(docked))
		# Sattel unter der Stahlkappe mit Nut für ihre Paßfeder.
		box(bay, Vector3(0.7, 0.08, 0.3), Vector3(0, 0.07, side * 2.3), dark)
		box(bay, Vector3(0.14, 0.03, 0.3), Vector3(0, 0.1, side * 2.3), mat(Color(0.01, 0.01, 0.02), 0.2))
	# Eine Mulde in der Mitte stützt das Glas.
	for wedge: float in [-1.0, 1.0]:
		var pad := box(bay, Vector3(0.3, 0.08, 0.5), Vector3(wedge * 0.22, 0.12, 0), dark)
		pad.rotation.z = wedge * 0.5

func _sicherung_cart(cart: Node3D) -> void:
	var steel := mat(STEEL, 0.5, 0.85, 0.28)
	for side: float in [-1.0, 1.0]:
		box(cart, Vector3(0.12, 0.06, 0.26), Vector3(0, -0.435, side * 2.3), steel)

# --- 3 · DOCK-STECKER: ein Steckerblock unter der Mitte, zwei Führungszapfen ---

func _stecker_bay(bay: Node3D, docked: bool) -> void:
	var dark := mat(DARK, 0.6, 0.4, 0.4)
	var gold := mat(GOLD, 0.7, 0.85, 0.25)
	var steel := mat(STEEL, 0.5, 0.85, 0.28)
	box(bay, Vector3(0.56, 0.14, 1.2), Vector3(0, 0.1, 0), dark)
	box(bay, Vector3(0.38, 0.02, 0.98), Vector3(0, 0.175, 0), mat(Color(0.01, 0.01, 0.02), 0.2))
	for i in 5:
		post(bay, 0.035, 0.02, Vector3(0, 0.19, (float(i) - 2.0) * 0.2), gold)
	for side: float in [-1.0, 1.0]:
		box(bay, Vector3(0.03, 0.015, 1.3), Vector3(side * 0.33, 0.04, 0), _contact_light(docked))
		box(bay, Vector3(0.68, 0.015, 0.03), Vector3(0, 0.04, side * 0.65), _contact_light(docked))
		post(bay, 0.12, 0.1, Vector3(0, 0.08, side * 1.9), steel)
		post(bay, 0.07, 0.02, Vector3(0, 0.135, side * 1.9), mat(Color(0.01, 0.01, 0.02), 0.2))
		_jaws(bay, side * 1.29)

func _stecker_cart(cart: Node3D) -> void:
	var dark := mat(DARK, 0.6, 0.4, 0.4)
	var gold := mat(GOLD, 0.7, 0.85, 0.25)
	var steel := mat(STEEL, 0.5, 0.85, 0.28)
	box(cart, Vector3(0.34, 0.14, 0.94), Vector3(0, -0.4, 0), dark)
	box(cart, Vector3(0.28, 0.03, 0.88), Vector3(0, -0.48, 0), gold)
	for i in 5:
		post(cart, 0.03, 0.07, Vector3(0, -0.51, (float(i) - 2.0) * 0.2), gold)
	for side: float in [-1.0, 1.0]:
		post(cart, 0.06, 0.16, Vector3(0, -0.43, side * 1.9), steel)
