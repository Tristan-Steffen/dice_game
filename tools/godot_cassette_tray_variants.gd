extends SceneTree
## Fumble: fünf ENTWÜRFE für den Material-Tray (Kassetten) des Magazins (2026-11-21). Reine Sichtprobe,
## nichts davon ist im Spiel. Aufruf:
##   Godot --path . --resolution 1280x720 --position 4000,2400 --quit-after 900 \
##     --script tools/godot_cassette_tray_variants.gd
## Bilder: E:/Generated Images/Fumble/material_tray_entwuerfe_2026-11-21/

const OUT := "E:/Generated Images/Fumble/material_tray_entwuerfe_2026-11-21/"
const K := 3.2
const NAMES := ["1_tapedeck", "2_studiospule", "3_neonlaufwerk", "4_tastenfach", "5_pegelkupfer"]
const TITLES := ["1 · TAPEDECK", "2 · STUDIOSPULE", "3 · NEON-LAUFWERK", "4 · TASTENFACH",
	"5 · PEGEL IN KUPFER"]

## Die Grube (halbe Maße: x längs = Bild-hoch, y quer = Bild-breit) und ihre Höhen.
const HOLE := Vector2(3.82, 5.675)
const SLOT_END := 5.312
const BAY := Vector2(1.8315, 2.687)
const CARD := Vector2(1.728, 2.592)
const FLOOR_Y := -0.859
const DECK := 0.54
const SEAT := 0.056
const CARD_T := 0.403
const BAY_X := [1.91, -1.91]
const BAY_Z := [-2.928, 2.565]
const MARGIN := Vector3(0.21, 0.21, 0.9)

const PINK := Color(0.95, 0.36, 0.64)
const HUB := Vector2(1.029, 1.664)
const CAPSTAN := Vector2(-1.28, 1.504)
const CHROME := Color(0.72, 0.74, 0.78)
const COPPER := Color(0.8, 0.47, 0.28)
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
	cell.setup(String(Pack.SHELF_ORDER[1]))
	cell.rotation.y = -PI / 2.0
	cell.set_body_scale(K)
	cell.position = Vector3(at.x, FLOOR_Y + seat, at.z)

# --- Der Tray ----------------------------------------------------------------------

## Was jeder Entwurf teilt: Filz, Schacht, Lamellen-Deck, Rollschiene, Fassung, Lichtleiste.
func _build(variant: int) -> void:
	var looks := [
		{"deck": mat(Color(0.5, 0.51, 0.53), 0.28, 0.4, 0.3), "frame": mat(Color(0.55, 0.56, 0.58), 0.28, 0.4, 0.3)},
		{"deck": mat(Color(0.1, 0.1, 0.115), 0.8, 0.1, 0.55), "frame": mat(Color(0.13, 0.13, 0.15), 0.7, 0.2, 0.45)},
		{"deck": mat(Color(0.03, 0.03, 0.04), 1.0, 0.0, 0.5), "frame": mat(Color(0.03, 0.03, 0.04), 1.0, 0.0, 0.45)},
		{"deck": mat(Color(0.06, 0.06, 0.07), 0.9, 0.1, 0.4), "frame": mat(Color(0.07, 0.07, 0.08), 0.9, 0.1, 0.35)},
		{"deck": mat(Color(0.42, 0.33, 0.26), 0.3, 0.5, 0.35), "frame": mat(Color(0.46, 0.36, 0.28), 0.3, 0.5, 0.35)},
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
		lamp(PINK, 0.9))
	var high := 0.028
	box(scene, Vector3(MARGIN.y, high, (HOLE.y + MARGIN.x) * 2.0), Vector3(HOLE.x + MARGIN.y * 0.5,
		high * 0.5, 0), frame)
	box(scene, Vector3(MARGIN.z, high, (HOLE.y + MARGIN.x) * 2.0), Vector3(-HOLE.x - MARGIN.z * 0.5,
		high * 0.5, 0), frame)
	for dir: float in [-1.0, 1.0]:
		box(scene, Vector3(HOLE.x * 2.0, high, MARGIN.x), Vector3(0, high * 0.5,
			dir * (HOLE.y + MARGIN.x * 0.5)), frame)
	box(scene, Vector3(0.62, 0.036, HOLE.y * 2.0 - 0.1), Vector3(-HOLE.x - 0.13 - 0.31, 0.03, 0),
		lamp(PINK * 0.6, 0.55))
	text(scene, "Material 2", Vector3(-HOLE.x - 0.44, 0.052, 0), 0.4, PINK.lerp(Color.WHITE, 0.7))
	text(scene, TITLES[variant], Vector3(HOLE.x + 0.95, 0.01, 0), 0.5, Color(0.85, 0.85, 0.9))
	for row in 2:
		for across in 2:
			var at := Vector3(BAY_X[row], FLOOR_Y, BAY_Z[across])
			var loaded := row != across
			match variant:
				0: _tapedeck(at, loaded)
				1: _studiospule(at, loaded)
				2: _neonlaufwerk(at, loaded)
				3: _tastenfach(at, loaded)
				4: _pegelkupfer(at, loaded)
			if loaded:
				card(at)
	match variant:
		0: _frame_tapedeck()
		2: _frame_neon()
		3: _frame_tastenfach()
		4: _frame_kupfer()

func ring(at: Vector3, half: Vector2, width: float, high: float, material: Material) -> void:
	for dir: float in [-1.0, 1.0]:
		box(scene, Vector3(width, high, half.y * 2.0), at + Vector3(dir * (half.x - width * 0.5),
			high * 0.5, 0), material)
		box(scene, Vector3(half.x * 2.0 - width * 2.0, high, width), at + Vector3(0, high * 0.5,
			dir * (half.y - width * 0.5)), material)

## Ein gezahnter Wickeldorn auf seinem Teller; er endet im Gehäuse der Kassette.
func spindle(at: Vector3, core: Material, plate: Material, plate_r := 0.3) -> void:
	var high := SEAT + CARD_T * 0.72
	cyl(scene, plate_r, SEAT, at + Vector3(0, SEAT * 0.5, 0), plate)
	cyl(scene, 0.117, high, at + Vector3(0, high * 0.5, 0), core)
	for tooth in 6:
		var angle := TAU * float(tooth) / 6.0
		var fin := box(scene, Vector3(0.112, high - SEAT - 0.01, 0.056), at + Vector3(cos(angle), 0,
			sin(angle)) * 0.16 + Vector3(0, SEAT + (high - SEAT - 0.01) * 0.5, 0), core)
		fin.rotation.y = -angle

func hubs(at: Vector3) -> Array[Vector3]:
	return [at + Vector3(HUB.x, 0, -HUB.y), at + Vector3(HUB.x, 0, HUB.y)]

func capstans(at: Vector3, material: Material) -> void:
	for dir: float in [-1.0, 1.0]:
		cyl(scene, 0.09, SEAT + CARD_T * 0.5, at + Vector3(CAPSTAN.x, (SEAT + CARD_T * 0.5) * 0.5,
			dir * CAPSTAN.y), material)

# --- 1 · TAPEDECK: gebürstetes Aluminium, Chrom-Dorne, Pegel-Dioden auf der Mittellippe ---------

func _tapedeck(at: Vector3, loaded: bool) -> void:
	box(scene, Vector3(BAY.x * 2.0 - 0.1, 0.012, BAY.y * 2.0 - 0.1), at + Vector3(0, 0.006, 0),
		mat(Color(0.03, 0.03, 0.035), 1.0, 0.1, 0.4))
	var chrome := mat(CHROME, 0.5, 0.8, 0.2)
	for hub in hubs(at):
		spindle(hub, chrome, mat(Color(0.2, 0.2, 0.22), 0.6, 0.5, 0.3), 0.36)
	capstans(at, chrome)
	box(scene, Vector3(0.3, SEAT, 0.96), at + Vector3(CAPSTAN.x - 0.2, SEAT * 0.5, 0), chrome)
	ring(at + Vector3(0, 0.012, 0), BAY - Vector2.ONE * 0.03, 0.04, 0.012,
		lamp(PINK, 1.3 if loaded else 0.2))
	# Der Pegel auf der Rippe unter dem Platz: zehn Dioden, belegt steigen sie an.
	for i in 10:
		var on := loaded and i < 7
		box(scene, Vector3(0.05, 0.006, 0.3), Vector3(at.x - BAY.x - 0.04, FLOOR_Y + DECK + 0.002,
			at.z - 1.9 + float(i) * 0.42), lamp(PINK if i < 8 else Color(1, 0.85, 0.5),
			1.5 if on else 0.15))

func _frame_tapedeck() -> void:
	var dark := mat(Color(0.05, 0.05, 0.06), 0.6)
	# Gefräste Rillen im Aluminium oben und Senkschrauben in den Ecken.
	for i in 3:
		box(scene, Vector3(0.012, 0.004, HOLE.y * 2.0), Vector3(HOLE.x + 0.06 + float(i) * 0.045,
			0.03, 0), dark)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			cyl(scene, 0.06, 0.008, Vector3(sx * (HOLE.x + 0.1) - (0.35 if sx < 0.0 else 0.0), 0.032,
				sz * (HOLE.y + 0.105)), mat(CHROME, 0.4, 0.8, 0.2))

# --- 2 · STUDIOSPULE: große Spulenteller um die Dorne, Bandweg als Lichtlinie ---------------------

func _studiospule(at: Vector3, loaded: bool) -> void:
	box(scene, Vector3(BAY.x * 2.0 - 0.1, 0.012, BAY.y * 2.0 - 0.1), at + Vector3(0, 0.006, 0),
		mat(Color(0.05, 0.05, 0.06), 0.9, 0.1, 0.5))
	var alu := mat(Color(0.6, 0.61, 0.63), 0.4, 0.6, 0.25)
	var cut := mat(Color(0.02, 0.02, 0.025), 0.8)
	var white := mat(Color(0.85, 0.83, 0.8), 0.5, 0.0, 0.5)
	for hub in hubs(at):
		cyl(scene, 0.74, 0.02, hub + Vector3(0, 0.022, 0), alu)
		for i in 3:
			var a := TAU * float(i) / 3.0 + 0.5
			cyl(scene, 0.2, 0.004, hub + Vector3(cos(a) * 0.44, 0.034, sin(a) * 0.44), cut)
		spindle(hub, white, mat(PINK * 0.6, 0.8), 0.26)
	capstans(at, alu)
	# Der Bandweg: von Spule zu Spule über die beiden Umlenkrollen.
	var path := lamp(PINK, 1.4 if loaded else 0.35)
	box(scene, Vector3(0.03, 0.008, CAPSTAN.y * 2.0), at + Vector3(CAPSTAN.x - 0.14, 0.02, 0), path)
	for dir: float in [-1.0, 1.0]:
		var run := box(scene, Vector3(2.0, 0.008, 0.03), at + Vector3(-0.2, 0.02, dir * 2.07), path)
		run.rotation.y = dir * 0.33
	# Eine Aufnahme-Lampe auf der Rippe meldet den belegten Platz.
	cyl(scene, 0.05, 0.008, Vector3(at.x - BAY.x - 0.04, FLOOR_Y + DECK + 0.003, at.z - 2.2),
		lamp(Color(1.0, 0.3, 0.35), 1.8 if loaded else 0.12))

# --- 3 · NEON-LAUFWERK: schwarzes Glas, Neon-Umriß der Kassette, glühende Dorne ------------------

func _neonlaufwerk(at: Vector3, loaded: bool) -> void:
	box(scene, Vector3(BAY.x * 2.0 - 0.1, 0.014, BAY.y * 2.0 - 0.1), at + Vector3(0, 0.007, 0),
		mat(Color(0.012, 0.012, 0.02), 1.0, 0.3, 0.1))
	var neon := lamp(PINK, 2.0 if loaded else 0.45)
	ring(at + Vector3(0, 0.014, 0), CARD + Vector2(0.075, 0.07), 0.045, 0.02, neon)
	var soft := lamp(PINK, 0.4)
	var black := mat(Color(0.05, 0.05, 0.065), 1.0, 0.4, 0.2)
	for hub in hubs(at):
		var halo := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.4
		torus.outer_radius = 0.44
		halo.mesh = torus
		halo.material_override = soft
		halo.position = hub + Vector3(0, 0.02, 0)
		halo.scale.y = 0.4
		scene.add_child(halo)
		spindle(hub, black, soft, 0.2)
		cyl(scene, 0.07, 0.01, hub + Vector3(0, SEAT + CARD_T * 0.72 + 0.005, 0), lamp(PINK, 0.9))
	capstans(at, black)
	# Der Kopf als feine Lichtkante.
	box(scene, Vector3(0.03, 0.01, 0.9), at + Vector3(CAPSTAN.x - 0.2, 0.02, 0), soft)

func _frame_neon() -> void:
	ring(Vector3(0, 0.029, 0), HOLE + Vector2(0.12, 0.12), 0.025, 0.006, lamp(PINK, 0.7))
	for row in 2:
		for mark in 2:
			text(scene, "A" if mark == 0 else "B", Vector3(BAY_X[row] + (0.9 if mark == 0 else -0.9),
				0.03, -HOLE.y - 0.105), 0.13, PINK.lerp(Color.WHITE, 0.4))

# --- 4 · TASTENFACH: Chromrahmen um das Fach, fünf Laufwerkstasten auf der Rippe darunter -------

func _tastenfach(at: Vector3, loaded: bool) -> void:
	box(scene, Vector3(BAY.x * 2.0 - 0.1, 0.012, BAY.y * 2.0 - 0.1), at + Vector3(0, 0.006, 0),
		mat(Color(0.035, 0.035, 0.042), 1.0, 0.1, 0.5))
	var line := mat(Color(0.09, 0.09, 0.1), 0.9)
	for i in 15:
		box(scene, Vector3(0.012, 0.004, BAY.y * 2.0 - 0.3), at + Vector3((float(i) - 7.0) * 0.22,
			0.014, 0), line)
	var chrome := mat(CHROME, 0.5, 0.8, 0.2)
	for hub in hubs(at):
		spindle(hub, mat(Color(0.85, 0.83, 0.8), 0.5, 0.0, 0.5), chrome, 0.3)
	capstans(at, chrome)
	# Ein Chromrahmen faßt die Öffnung des Fachs.
	ring(at + Vector3(0, DECK - 0.03, 0), BAY - Vector2.ONE * 0.022, 0.03, 0.03, chrome)
	# Fünf Tasten auf der Rippe unter dem Platz; belegt leuchtet die Wiedergabe.
	for i in 5:
		var on := loaded and i == 2
		box(scene, Vector3(0.1, 0.02, 0.62), Vector3(at.x - BAY.x - 0.04, FLOOR_Y + DECK + 0.008,
			at.z + (float(i) - 2.0) * 0.72), lamp(PINK, 1.8) if on else chrome)

func _frame_tastenfach() -> void:
	var chrome := mat(CHROME, 0.5, 0.8, 0.2)
	ring(Vector3(0, 0.028, 0), HOLE + Vector2(0.07, 0.07), 0.03, 0.008, chrome)

# --- 5 · PEGEL IN KUPFER: warmes Metall, Kupferköpfe, Pegel-Leiter am Rand jedes Platzes --------

func _pegelkupfer(at: Vector3, loaded: bool) -> void:
	box(scene, Vector3(BAY.x * 2.0 - 0.1, 0.012, BAY.y * 2.0 - 0.1), at + Vector3(0, 0.006, 0),
		mat(Color(0.05, 0.035, 0.03), 0.9, 0.1, 0.5))
	var copper := mat(COPPER, 0.5, 0.8, 0.25)
	var rubber := mat(Color(0.03, 0.03, 0.035), 0.9, 0.0, 0.9)
	for hub in hubs(at):
		spindle(hub, copper, mat(Color(0.2, 0.14, 0.1), 0.7, 0.4, 0.4), 0.42)
	# Kopfblock, Löschkopf und zwei Andruckrollen an der Kopfkante.
	box(scene, Vector3(0.34, SEAT, 0.7), at + Vector3(CAPSTAN.x - 0.18, SEAT * 0.5, 0), copper)
	box(scene, Vector3(0.24, SEAT, 0.3), at + Vector3(CAPSTAN.x - 0.18, SEAT * 0.5, -0.85), copper)
	for dir: float in [-1.0, 1.0]:
		cyl(scene, 0.16, SEAT, at + Vector3(CAPSTAN.x - 0.12, SEAT * 0.5, dir * CAPSTAN.y), rubber)
		cyl(scene, 0.05, SEAT + CARD_T * 0.5, at + Vector3(CAPSTAN.x - 0.12, (SEAT + CARD_T * 0.5)
			* 0.5, dir * CAPSTAN.y), copper)
	# Die Pegel-Leiter links neben der Kassette: belegt steigt sie von Grün nach Pink.
	for i in 12:
		var share := float(i) / 11.0
		var color := Color(0.4, 0.9, 0.5).lerp(Color(1.0, 0.8, 0.35), minf(share * 2.0, 1.0)) \
			.lerp(PINK, clampf(share * 2.0 - 1.0, 0.0, 1.0))
		var on := loaded and i < 9
		box(scene, Vector3(0.2, 0.012, 0.055), at + Vector3(-1.5 + float(i) * 0.272, 0.02,
			-CARD.y - 0.05), lamp(color, 1.6 if on else 0.14))

func _frame_kupfer() -> void:
	var copper := mat(COPPER, 0.5, 0.8, 0.25)
	box(scene, Vector3(0.03, 0.008, HOLE.y * 2.0 + 0.3), Vector3(HOLE.x + 0.105, 0.032, 0), copper)
	for i in 4:
		cyl(scene, 0.06, 0.02, Vector3(-HOLE.x - 0.07, 0.036, -HOLE.y + 0.5 + float(i) * 3.5), copper)
