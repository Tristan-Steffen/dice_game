extends SceneTree
## Fumble: sieben ENTWÜRFE für den Sonderbestand-Tray (Service-Module) des Magazins (2026-11-21). Reine Sichtprobe,
## nichts davon ist im Spiel. Aufruf:
##   Godot --path . --resolution 1280x720 --position 4000,2400 --quit-after 900 \
##     --script tools/godot_module_tray_variants.gd
## Bilder: E:/Generated Images/Fumble/sonder_tray_entwuerfe_2026-11-22/

const OUT := "E:/Generated Images/Fumble/sonder_tray_entwuerfe_2026-11-22/"
const K := 3.2
const NAMES := ["1_reinraum", "2_esd_matte", "3_kartenkaefig", "4_pruefadapter", "5_servicekoffer",
	"6_blister", "7_dock"]
const TITLES := ["1 · REINRAUM-SCHALE", "2 · ESD-MATTE", "3 · KARTENKÄFIG", "4 · PRÜFADAPTER",
	"5 · SERVICEKOFFER", "6 · BLISTER-REGAL", "7 · DOCK"]

## Die Grube (halbe Maße: x längs = Bild-hoch, y quer = Bild-breit) und ihre Höhen.
const HOLE := Vector2(3.82, 5.675)
const SLOT_END := 5.312
const BAY := Vector2(1.8315, 2.687)
const CARD := Vector2(1.728, 2.592)
const FLOOR_Y := -0.859
const DECK := 0.54
const SEAT := 0.056
const CARD_T := 0.109
const BAY_X := [1.91, -1.91]
const BAY_Z := [-2.928, 2.565]
const MARGIN := Vector3(0.21, 0.21, 0.9)

const LILA := Color(0.66, 0.52, 0.98)
const GOLD := Color(0.86, 0.66, 0.28)
const CONTACT_Z := 2.443
const CONTACT_PITCH := 0.272
const BRASS := Color(0.78, 0.6, 0.26)
const STEEL := Color(0.62, 0.65, 0.68)

var camera: Camera3D
var scene: Node3D
var frames := 0
var step := 0

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
		root.get_texture().get_image().save_png(OUT + "%s_%s.png" % [NAMES[last / 2],
			"station" if last % 2 == 0 else "nah"])
	if variant >= NAMES.size():
		return true
	if view == 0:
		if scene != null:
			scene.queue_free()
		scene = Node3D.new()
		root.add_child(scene)
		_build(variant)
		var forward := Vector3(0.2588, -0.9659, 0.0)
		camera.look_at_from_position(Vector3(-0.35, 0.0, 0.0) - forward * 14.5,
			Vector3(-0.35, 0.0, 0.0), Vector3(1, 0, 0))
	else:
		camera.look_at_from_position(Vector3(-5.2, 6.4, -6.4), Vector3(0.2, -0.6, -1.6),
			Vector3(0, 1, 0))
	step += 1
	return false

# --- Bausteine ---------------------------------------------------------------------

func mat(color: Color, glow := 0.2, metallic := 0.0, roughness := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = glow
	return m

func lamp(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color * 0.3
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

func box(host: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	return TableProps.box(host, "Teil", size, at, material)

## Ein Zylinder; axis 0 = längs X, 1 = stehend, 2 = längs Z.
func cyl(host: Node3D, radius: float, high: float, at: Vector3, material: Material,
		axis := 1) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = high
	mesh.radial_segments = 20
	node.mesh = mesh
	node.material_override = material
	node.position = at
	if axis == 0:
		node.rotation.z = PI * 0.5
	elif axis == 2:
		node.rotation.x = PI * 0.5
	host.add_child(node)
	return node

func text(host: Node3D, body: String, at: Vector3, high: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = body
	label.font_size = 64
	label.transform.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	label.pixel_size = high / 46.0
	label.position = at
	label.modulate = color
	label.outline_size = 10
	label.outline_modulate = Color(0.02, 0.02, 0.03)
	label.shaded = false
	host.add_child(label)

func card(at: Vector3, seat := SEAT) -> void:
	var cell := DataCellView.new()
	scene.add_child(cell)
	cell.setup(String(Pack.SHELF_ORDER[3]))
	cell.rotation.y = -PI / 2.0
	cell.set_body_scale(K)
	cell.position = Vector3(at.x, FLOOR_Y + seat, at.z)

# --- Der Tray ----------------------------------------------------------------------

## Was jeder Entwurf teilt: Filz, Schacht, Lamellen-Deck, Rollschiene, Fassung, Lichtleiste.
func _build(variant: int) -> void:
	var looks := [
		{"deck": mat(Color(0.58, 0.59, 0.63), 0.34, 0.0, 0.5), "frame": mat(Color(0.62, 0.63, 0.67), 0.34, 0.0, 0.45)},
		{"deck": mat(Color(0.12, 0.12, 0.15), 0.8, 0.0, 0.7), "frame": mat(Color(0.14, 0.14, 0.18), 0.7, 0.1, 0.5)},
		{"deck": mat(Color(0.42, 0.44, 0.47), 0.3, 0.5, 0.3), "frame": mat(Color(0.46, 0.48, 0.51), 0.3, 0.5, 0.3)},
		{"deck": mat(Color(0.09, 0.08, 0.07), 0.8, 0.1, 0.5), "frame": mat(Color(0.5, 0.39, 0.18), 0.4, 0.7, 0.3)},
		{"deck": mat(Color(0.09, 0.09, 0.11), 0.8, 0.0, 0.8), "frame": mat(Color(0.3, 0.24, 0.46), 0.5, 0.1, 0.5)},
		{"deck": mat(Color(0.4, 0.38, 0.52), 0.4, 0.0, 0.8), "frame": mat(Color(0.44, 0.42, 0.56), 0.4, 0.0, 0.8)},
		{"deck": mat(Color(0.022, 0.022, 0.03), 1.0, 0.2, 0.3), "frame": mat(Color(0.022, 0.022, 0.03), 1.0, 0.2, 0.25)},
	]
	var deck: Material = looks[variant]["deck"]
	var frame: Material = looks[variant]["frame"]
	var felt := mat(Color(0.1, 0.05, 0.17), 0.5, 0.0, 1.0)
	var dark := mat(Color(0.03, 0.03, 0.04), 0.5)
	var outer := Vector2(HOLE.x + 14.0, HOLE.y + 16.0)
	box(scene, Vector3(14.0, 0.1, outer.y * 2.0), Vector3(HOLE.x + 7.0, -0.05, 0), felt)
	box(scene, Vector3(14.0, 0.1, outer.y * 2.0), Vector3(-HOLE.x - 7.0, -0.05, 0), felt)
	for dir: float in [-1.0, 1.0]:
		box(scene, Vector3(HOLE.x * 2.0, 0.1, 16.0), Vector3(0, -0.05, dir * (HOLE.y + 8.0)), felt)
		box(scene, Vector3(HOLE.x * 2.0 + 0.4, 1.4, 0.2), Vector3(0, -0.75, dir * (HOLE.y + 0.1)), dark)
		box(scene, Vector3(0.2, 1.4, HOLE.y * 2.0), Vector3(dir * (HOLE.x + 0.1), -0.75, 0), dark)
	box(scene, Vector3(HOLE.x * 2.0, 0.06, HOLE.y * 2.0), Vector3(0, FLOOR_Y - 0.03, 0), deck)
	var top := FLOOR_Y + DECK * 0.5
	for lip: Vector2 in [Vector2(-HOLE.y + 0.03, 0.06), Vector2(-0.181, 0.12),
			Vector2(SLOT_END - 0.03, 0.06)]:
		box(scene, Vector3(HOLE.x * 2.0, DECK, lip.y), Vector3(0, top, lip.x), deck)
	var slots := SLOT_END + HOLE.y
	for rib: Vector2 in [Vector2(HOLE.x - 0.039, 0.078), Vector2(0, 0.157),
			Vector2(-HOLE.x + 0.039, 0.078)]:
		box(scene, Vector3(rib.y, DECK - 0.002, slots), Vector3(rib.x, top - 0.001,
			-HOLE.y + slots * 0.5), deck)
	var rail_w := HOLE.y - SLOT_END
	var rail_z := SLOT_END + rail_w * 0.5
	box(scene, Vector3(HOLE.x * 2.0, DECK - 0.17, rail_w), Vector3(0, FLOOR_Y + (DECK - 0.17) * 0.5,
		rail_z), dark)
	for dir: float in [-1.0, 1.0]:
		box(scene, Vector3(HOLE.x * 2.0, DECK, 0.07), Vector3(0, top, rail_z + dir * (rail_w * 0.5
			- 0.035)), deck)
	box(scene, Vector3(3.0, 0.2, rail_w * 0.62), Vector3(2.2, FLOOR_Y + DECK - 0.08, rail_z),
		lamp(LILA, 0.9))
	var high := 0.028
	box(scene, Vector3(MARGIN.y, high, (HOLE.y + MARGIN.x) * 2.0), Vector3(HOLE.x + MARGIN.y * 0.5,
		high * 0.5, 0), frame)
	box(scene, Vector3(MARGIN.z, high, (HOLE.y + MARGIN.x) * 2.0), Vector3(-HOLE.x - MARGIN.z * 0.5,
		high * 0.5, 0), frame)
	for dir: float in [-1.0, 1.0]:
		box(scene, Vector3(HOLE.x * 2.0, high, MARGIN.x), Vector3(0, high * 0.5,
			dir * (HOLE.y + MARGIN.x * 0.5)), frame)
	box(scene, Vector3(0.62, 0.036, HOLE.y * 2.0 - 0.1), Vector3(-HOLE.x - 0.13 - 0.31, 0.03, 0),
		lamp(LILA * 0.6, 0.55))
	text(scene, "Sonder 2", Vector3(-HOLE.x - 0.44, 0.052, 0), 0.4, LILA.lerp(Color.WHITE, 0.7))
	text(scene, TITLES[variant], Vector3(HOLE.x + 0.95, 0.01, 0), 0.5, Color(0.85, 0.85, 0.9))
	for row in 2:
		for across in 2:
			var at := Vector3(BAY_X[row], FLOOR_Y, BAY_Z[across])
			var loaded := row != across
			match variant:
				0: _reinraum(at, loaded)
				1: _esd_matte(at, loaded)
				2: _kartenkaefig(at, loaded)
				3: _pruefadapter(at, loaded)
				4: _servicekoffer(at, loaded)
				5: _blister(at, loaded)
				6: _dock(at, loaded)
			if loaded:
				card(at)
	if variant == 4:
		# Zwei Schnappverschlüsse am unteren Rand des Koffers.
		for dir: float in [-1.0, 1.0]:
			box(scene, Vector3(0.14, 0.03, 0.9), Vector3(-HOLE.x - 0.07, 0.04, dir * 3.0),
				mat(Color(0.7, 0.72, 0.76), 0.5, 0.8, 0.2))
	if variant == 6:
		ring(Vector3(0, 0.029, 0), HOLE + Vector2(0.12, 0.12), 0.025, 0.006, lamp(LILA, 0.7))

func ring(at: Vector3, half: Vector2, width: float, high: float, material: Material) -> void:
	for dir: float in [-1.0, 1.0]:
		box(scene, Vector3(width, high, half.y * 2.0), at + Vector3(dir * (half.x - width * 0.5),
			high * 0.5, 0), material)
		box(scene, Vector3(half.x * 2.0 - width * 2.0, high, width), at + Vector3(0, high * 0.5,
			dir * (half.y - width * 0.5)), material)

func glass(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func boden(at: Vector3, material: Material, high := 0.012) -> void:
	box(scene, Vector3(BAY.x * 2.0 - 0.1, high, BAY.y * 2.0 - 0.1), at + Vector3(0, high * 0.5, 0),
		material)

## Die Lampe auf der Rippe unter einem Platz: leuchtet, wenn ein Modul liegt.
func rippenlampe(at: Vector3, loaded: bool, color: Color, wide := 0.6, z := 0.0) -> void:
	box(scene, Vector3(0.06, 0.006, wide), Vector3(at.x - BAY.x - 0.04, FLOOR_Y + DECK + 0.002,
		at.z + z), lamp(color, 1.8 if loaded else 0.16))

## Vier Stützen unter den Ecken der Platine.
func stuetzen(at: Vector3, material: Material, radius := 0.1) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			cyl(scene, radius, SEAT, at + Vector3(sx * (CARD.x - 0.22), SEAT * 0.5,
				sz * (CARD.y - 0.22) - (0.4 if sz > 0.0 else 0.0)), material)

## Die Steckleiste am Kartenfuß mit elf Kontakten.
func steckleiste(at: Vector3, block: Material, pin: Material) -> void:
	box(scene, Vector3(CONTACT_PITCH * 11.6, SEAT * 0.55, 0.36), at + Vector3(0, SEAT * 0.28,
		CONTACT_Z), block)
	for i in 11:
		cyl(scene, 0.045, SEAT, at + Vector3((float(i) - 5.0) * CONTACT_PITCH, SEAT * 0.5, CONTACT_Z), pin)

# --- 1 · REINRAUM-SCHALE: seidenweißer Träger, geformte Tasche, Lichtlinie in Lila ----------------

func _reinraum(at: Vector3, loaded: bool) -> void:
	var white := mat(Color(0.5, 0.51, 0.55), 0.36, 0.0, 0.5)
	boden(at, white, 0.02)
	# Die Tasche: ein erhabener Kragen um die Platine, vier Griffmulden an den Ecken.
	ring(at + Vector3(0, 0.02, 0), BAY - Vector2.ONE * 0.03, 0.05, 0.22,
		mat(Color(0.62, 0.63, 0.67), 0.36, 0.0, 0.45))
	var scoop := mat(Color(0.3, 0.31, 0.35), 0.4, 0.0, 0.6)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			cyl(scene, 0.3, 0.004, at + Vector3(sx * (CARD.x - 0.3), 0.022, sz * (CARD.y - 0.3)), scoop)
	stuetzen(at, mat(Color(0.7, 0.71, 0.75), 0.36, 0.0, 0.4))
	ring(at + Vector3(0, 0.02, 0), BAY - Vector2.ONE * 0.085, 0.035, 0.01,
		lamp(LILA, 1.7 if loaded else 0.3))
	rippenlampe(at, loaded, LILA)

# --- 2 · ESD-MATTE: lila Antistatik-Matte mit grobem Raster, Lagewinkel, Erdungsknopf --------------

func _esd_matte(at: Vector3, loaded: bool) -> void:
	boden(at, mat(Color(0.36, 0.3, 0.62), 0.75 if loaded else 0.5, 0.0, 1.0), 0.03)
	var grid := mat(Color(0.56, 0.5, 0.86), 0.7, 0.0, 1.0)
	for i in 7:
		box(scene, Vector3(0.022, 0.004, BAY.y * 2.0 - 0.2), at + Vector3((float(i) - 3.0) * 0.52,
			0.032, 0), grid)
	for i in 9:
		box(scene, Vector3(BAY.x * 2.0 - 0.2, 0.004, 0.022), at + Vector3(0, 0.032,
			(float(i) - 4.0) * 0.6), grid)
	# Lagewinkel in den Ecken und der verchromte Erdungsknopf.
	var mark := mat(Color(0.92, 0.9, 1.0), 0.8, 0.0, 1.0)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			box(scene, Vector3(0.5, 0.006, 0.05), at + Vector3(sx * (CARD.x - 0.2), 0.036,
				sz * (CARD.y - 0.0)), mark)
			box(scene, Vector3(0.05, 0.006, 0.5), at + Vector3(sx * (CARD.x + 0.02), 0.036,
				sz * (CARD.y - 0.25)), mark)
	cyl(scene, 0.13, 0.03, at + Vector3(-CARD.x + 0.3, 0.045, -CARD.y + 0.3),
		mat(Color(0.75, 0.77, 0.8), 0.5, 0.8, 0.2))
	cyl(scene, 0.06, 0.034, at + Vector3(-CARD.x + 0.3, 0.047, -CARD.y + 0.3),
		mat(Color(0.05, 0.05, 0.06), 0.5))
	rippenlampe(at, loaded, LILA, 0.9)

# --- 3 · KARTENKÄFIG: Führungsschienen, Steckleiste, zwei Auswurfhebel am Kopf -------------------

func _kartenkaefig(at: Vector3, loaded: bool) -> void:
	boden(at, mat(Color(0.05, 0.07, 0.06), 0.8, 0.0, 0.8))
	var steel := mat(STEEL, 0.45, 0.7, 0.25)
	# Die Führungsschienen an den Langseiten, mit Nut für die Platine.
	for dir: float in [-1.0, 1.0]:
		box(scene, Vector3(0.14, 0.26, BAY.y * 2.0 - 0.5), at + Vector3(dir * (CARD.x + 0.01),
			0.13, 0.1), steel)
		box(scene, Vector3(0.05, 0.03, BAY.y * 2.0 - 0.5), at + Vector3(dir * (CARD.x - 0.07),
			SEAT - 0.015, 0.1), mat(Color(0.2, 0.21, 0.23), 0.5, 0.4, 0.4))
	steckleiste(at, mat(Color(0.03, 0.03, 0.035), 0.8), mat(GOLD, 0.55, 0.8, 0.3))
	# Die Auswurfhebel: leer stehen sie offen, mit Modul liegen sie an.
	var lever := lamp(LILA, 1.5 if loaded else 0.5)
	for dir: float in [-1.0, 1.0]:
		var arm := box(scene, Vector3(0.09, 0.2, 0.75), at + Vector3(dir * (CARD.x - 0.42), 0.16,
			-CARD.y + 0.02), lever)
		arm.rotation.y = PI * 0.5 if loaded else dir * 0.75
		cyl(scene, 0.08, 0.24, at + Vector3(dir * (CARD.x - 0.05), 0.14, -CARD.y + 0.02), steel)
	rippenlampe(at, loaded, LILA, 0.5)

# --- 4 · PRÜFADAPTER: Nadelbett aus goldenen Federstiften unter einer klaren Platte ----------------

func _pruefadapter(at: Vector3, loaded: bool) -> void:
	boden(at, mat(Color(0.05, 0.045, 0.04), 0.8, 0.0, 0.8))
	var pin := CylinderMesh.new()
	pin.top_radius = 0.035
	pin.bottom_radius = 0.05
	pin.height = SEAT - 0.012
	pin.radial_segments = 8
	pin.material = lamp(GOLD, 1.5 if loaded else 0.75)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = pin
	multi.instance_count = 11 * 17
	for i in 11:
		for n in 17:
			multi.set_instance_transform(i * 17 + n, Transform3D(Basis.IDENTITY, Vector3(
				(float(i) - 5.0) * 0.3, 0.012 + pin.height * 0.5, (float(n) - 8.0) * 0.29)))
	var field := MultiMeshInstance3D.new()
	field.multimesh = multi
	field.position = at
	scene.add_child(field)
	# Vier Paßstifte und ein Messingrahmen um das Nadelbett.
	var brass := mat(GOLD, 0.5, 0.8, 0.3)
	ring(at + Vector3(0, 0.012, 0), BAY - Vector2.ONE * 0.03, 0.06, 0.05, brass)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			cyl(scene, 0.07, SEAT + CARD_T, at + Vector3(sx * (CARD.x + 0.03), (SEAT + CARD_T) * 0.5,
				sz * (CARD.y + 0.03)), brass)
	rippenlampe(at, loaded, GOLD, 0.9)

# --- 5 · SERVICEKOFFER: Noppenschaum mit Paßform, lila Kofferkante ----------------------------------

func _servicekoffer(at: Vector3, loaded: bool) -> void:
	boden(at, mat(Color(0.1, 0.1, 0.12), 0.8, 0.0, 1.0), 0.03)
	var nub := SphereMesh.new()
	nub.radius = 0.09
	nub.height = 0.07
	nub.radial_segments = 8
	nub.rings = 3
	nub.material = mat(Color(0.2, 0.2, 0.24), 0.8, 0.0, 1.0)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = nub
	multi.instance_count = 12 * 18
	for i in 12:
		for n in 18:
			multi.set_instance_transform(i * 18 + n, Transform3D(Basis.IDENTITY, Vector3(
				(float(i) - 5.5) * 0.29, 0.03, (float(n) - 8.5) * 0.29)))
	var foam := MultiMeshInstance3D.new()
	foam.multimesh = multi
	foam.position = at
	scene.add_child(foam)
	# Die Kofferkante faßt jeden Platz in Lila.
	ring(at + Vector3(0, DECK - 0.05, 0), BAY - Vector2.ONE * 0.02, 0.04, 0.05,
		mat(LILA * 0.55, 0.7, 0.1, 0.5))
	rippenlampe(at, loaded, LILA, 0.9)

# --- 6 · BLISTER-REGAL: bedruckte Rückkarte, klare Haube über jedem Platz ---------------------------

func _blister(at: Vector3, loaded: bool) -> void:
	boden(at, mat(Color(0.74, 0.73, 0.8), 0.4, 0.0, 0.9), 0.02)
	# Der Druck der Rückkarte: ein lila Kopfband mit Euro-Loch, Streifen am Fuß.
	box(scene, Vector3(BAY.x * 2.0 - 0.12, 0.004, 0.9), at + Vector3(0, 0.022, -BAY.y + 0.5),
		mat(LILA * 0.7, 0.6, 0.0, 0.9))
	box(scene, Vector3(0.9, 0.006, 0.26), at + Vector3(0, 0.024, -BAY.y + 0.5),
		mat(Color(0.05, 0.05, 0.06), 0.5))
	for dir: float in [-1.0, 1.0]:
		cyl(scene, 0.13, 0.006, at + Vector3(dir * 0.45, 0.024, -BAY.y + 0.5),
			mat(Color(0.05, 0.05, 0.06), 0.5))
	for i in 3:
		box(scene, Vector3(BAY.x * 2.0 - 0.12, 0.004, 0.07), at + Vector3(0, 0.022,
			BAY.y - 0.3 - float(i) * 0.16), mat(LILA * 0.7, 0.6, 0.0, 0.9))
	stuetzen(at, mat(Color(0.85, 0.85, 0.9), 0.4, 0.0, 0.5), 0.08)
	# Die klare Haube: fast unsichtbar, nur ihre Kanten fangen das Licht.
	var dome := Vector2(CARD.x + 0.06, CARD.y + 0.06)
	box(scene, Vector3(dome.x * 2.0, 0.34, dome.y * 2.0), at + Vector3(0, 0.19, 0),
		glass(Color(0.85, 0.88, 1.0), 0.1))
	ring(at + Vector3(0, 0.355, 0), dome, 0.03, 0.006,
		glass(Color(1, 1, 1), 0.75 if loaded else 0.45))
	rippenlampe(at, loaded, LILA, 0.9)

# --- 7 · DOCK: Lichtring um den Platz, Status-Dioden, die sich beim Andocken füllen ---------------

func _dock(at: Vector3, loaded: bool) -> void:
	boden(at, mat(Color(0.012, 0.012, 0.02), 1.0, 0.3, 0.1))
	ring(at + Vector3(0, 0.012, 0), BAY - Vector2.ONE * 0.03, 0.07, 0.03,
		lamp(LILA, 2.0 if loaded else 0.4))
	# Pfeile am Boden weisen zum Anschluß am Fuß.
	var arrow := lamp(LILA, 0.3)
	for i in 4:
		for dir: float in [-1.0, 1.0]:
			var stroke := box(scene, Vector3(0.6, 0.006, 0.045), at + Vector3(dir * 0.2, 0.016,
				-1.6 + float(i) * 0.9), arrow)
			stroke.rotation.y = dir * 0.9
	steckleiste(at, mat(Color(0.05, 0.05, 0.065), 1.0, 0.3, 0.2), lamp(LILA, 0.9))
	stuetzen(at, mat(Color(0.06, 0.06, 0.08), 1.0, 0.4, 0.2))
	# Fünf Status-Dioden auf der Rippe: angedockt füllen sie sich.
	for i in 5:
		rippenlampe(at, loaded, LILA, 0.3, (float(i) - 2.0) * 0.45)
