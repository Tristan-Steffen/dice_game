extends SceneTree
## Fumble: sieben ENTWÜRFE für den Runen-Tray (Tontafeln) des Magazins (2026-11-21). Reine Sichtprobe,
## nichts davon ist im Spiel. Aufruf:
##   Godot --path . --resolution 1280x720 --position 4000,2400 --quit-after 900 \
##     --script tools/godot_tablet_tray_variants.gd
## Bilder: E:/Generated Images/Fumble/runen_tray_entwuerfe_2026-11-22/

const OUT := "E:/Generated Images/Fumble/runen_tray_entwuerfe_2026-11-22/"
const K := 3.2
const NAMES := ["1_archivnische", "2_korb", "3_sandbett", "4_brennofen", "5_museumslade",
	"6_tonhuelle", "7_nische_mit_glut"]
const TITLES := ["1 · ARCHIVNISCHE", "2 · KORB MIT ETIKETT", "3 · SANDBETT", "4 · BRENNOFEN",
	"5 · MUSEUMSLADE", "6 · TONHÜLLE", "7 · NISCHE MIT GLUT"]

## Die Grube (halbe Maße: x längs = Bild-hoch, y quer = Bild-breit) und ihre Höhen.
const HOLE := Vector2(3.82, 5.675)
const SLOT_END := 5.312
const BAY := Vector2(1.8315, 2.687)
const CARD := Vector2(1.728, 2.592)
const FLOOR_Y := -0.859
const DECK := 0.54
const SEAT := 0.056
const CARD_T := 0.41
const BAY_X := [1.91, -1.91]
const BAY_Z := [-2.928, 2.565]
const MARGIN := Vector3(0.21, 0.21, 0.9)

const YELLOW := Color(0.96, 0.8, 0.3)
const EMBER := Color(1.0, 0.5, 0.18)
const LIME := Color(0.74, 0.68, 0.56)
const CLAY := Color(0.62, 0.36, 0.22)
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
	cell.setup(String(Pack.SHELF_ORDER[2]))
	cell.rotation.y = -PI / 2.0
	cell.set_body_scale(K)
	cell.position = Vector3(at.x, FLOOR_Y + seat, at.z)

# --- Der Tray ----------------------------------------------------------------------

## Was jeder Entwurf teilt: Filz, Schacht, Lamellen-Deck, Rollschiene, Fassung, Lichtleiste.
func _build(variant: int) -> void:
	var looks := [
		{"deck": mat(LIME, 0.3, 0.0, 0.95), "frame": mat(LIME * 1.05, 0.3, 0.0, 0.95)},
		{"deck": mat(Color(0.36, 0.25, 0.15), 0.4, 0.0, 0.8), "frame": mat(Color(0.4, 0.28, 0.17), 0.4, 0.0, 0.8)},
		{"deck": mat(Color(0.3, 0.27, 0.23), 0.4, 0.0, 0.9), "frame": mat(Color(0.34, 0.3, 0.26), 0.4, 0.0, 0.9)},
		{"deck": mat(Color(0.2, 0.1, 0.08), 0.6, 0.0, 0.95), "frame": mat(Color(0.24, 0.12, 0.09), 0.6, 0.0, 0.95)},
		{"deck": mat(Color(0.07, 0.075, 0.085), 0.9, 0.0, 0.9), "frame": mat(Color(0.09, 0.095, 0.11), 0.8, 0.2, 0.4)},
		{"deck": mat(Color(0.3, 0.2, 0.14), 0.45, 0.0, 0.95), "frame": mat(Color(0.34, 0.22, 0.15), 0.45, 0.0, 0.95)},
		{"deck": mat(LIME * 0.8, 0.32, 0.0, 0.95), "frame": mat(LIME * 0.86, 0.32, 0.0, 0.95)},
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
		lamp(YELLOW, 0.9))
	var high := 0.028
	box(scene, Vector3(MARGIN.y, high, (HOLE.y + MARGIN.x) * 2.0), Vector3(HOLE.x + MARGIN.y * 0.5,
		high * 0.5, 0), frame)
	box(scene, Vector3(MARGIN.z, high, (HOLE.y + MARGIN.x) * 2.0), Vector3(-HOLE.x - MARGIN.z * 0.5,
		high * 0.5, 0), frame)
	for dir: float in [-1.0, 1.0]:
		box(scene, Vector3(HOLE.x * 2.0, high, MARGIN.x), Vector3(0, high * 0.5,
			dir * (HOLE.y + MARGIN.x * 0.5)), frame)
	box(scene, Vector3(0.62, 0.036, HOLE.y * 2.0 - 0.1), Vector3(-HOLE.x - 0.13 - 0.31, 0.03, 0),
		lamp(YELLOW * 0.6, 0.55))
	text(scene, "Rune 2", Vector3(-HOLE.x - 0.44, 0.052, 0), 0.4, YELLOW.lerp(Color.WHITE, 0.7))
	text(scene, TITLES[variant], Vector3(HOLE.x + 0.95, 0.01, 0), 0.5, Color(0.85, 0.85, 0.9))
	for row in 2:
		for across in 2:
			var at := Vector3(BAY_X[row], FLOOR_Y, BAY_Z[across])
			var loaded := row != across
			match variant:
				0: _archivnische(at, loaded)
				1: _korb(at, loaded)
				2: _sandbett(at, loaded)
				3: _brennofen(at, loaded)
				4: _museumslade(at, loaded)
				5: _tonhuelle(at, loaded)
				6: _nische_mit_glut(at, loaded)
			if loaded:
				card(at)
	if variant == 4:
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				box(scene, Vector3(0.16, 0.008, 0.16), Vector3(sx * (HOLE.x + 0.1) - (0.35 if sx < 0.0
					else 0.0), 0.032, sz * (HOLE.y + 0.1)), mat(Color(0.78, 0.6, 0.26), 0.5, 0.8, 0.3))

func ring(at: Vector3, half: Vector2, width: float, high: float, material: Material) -> void:
	for dir: float in [-1.0, 1.0]:
		box(scene, Vector3(width, high, half.y * 2.0), at + Vector3(dir * (half.x - width * 0.5),
			high * 0.5, 0), material)
		box(scene, Vector3(half.x * 2.0 - width * 2.0, high, width), at + Vector3(0, high * 0.5,
			dir * (half.y - width * 0.5)), material)

## Ein Keil der Keilschrift, flach auf Höhe y; die Spitze zeigt nach -X (Bild-unten).
func keil(at: Vector3, x: float, z: float, size: float, material: Material) -> void:
	MagazinTrayDress._wedge(scene, "Keil", [Vector2(x, z - size * 0.5), Vector2(x, z + size * 0.5),
		Vector2(x - size * 1.6, z)], at.y, at.y + 0.006, material).position = Vector3(at.x, 0, at.z)

## Das Zeichen auf der Rippe unter einem Platz: leuchtet, wenn eine Tafel liegt.
func rippenzeichen(at: Vector3, loaded: bool, color: Color, wide := 0.5) -> void:
	box(scene, Vector3(0.06, 0.006, wide), Vector3(at.x - BAY.x - 0.04, FLOOR_Y + DECK + 0.002,
		at.z), lamp(color, 1.8 if loaded else 0.16))

## Zwei Lagerbalken tragen die Tafel.
func lager(at: Vector3, material: Material) -> void:
	for dir: float in [-1.0, 1.0]:
		box(scene, Vector3(CARD.x * 1.7, SEAT, 0.24), at + Vector3(0, SEAT * 0.5, dir * 1.3), material)

func boden(at: Vector3, material: Material, high := 0.012) -> void:
	box(scene, Vector3(BAY.x * 2.0 - 0.1, high, BAY.y * 2.0 - 0.1), at + Vector3(0, high * 0.5, 0),
		material)

# --- 1 · ARCHIVNISCHE: heller Kalkstein, gestufte Nische, eingelegtes Zeichen auf der Rippe ------

func _archivnische(at: Vector3, loaded: bool) -> void:
	boden(at, mat(LIME * 0.5, 0.4, 0.0, 0.95))
	var stone := mat(LIME * 0.72, 0.36, 0.0, 0.95)
	# Eine Stufe rings um den Boden macht die Mulde zur Nische.
	ring(at, BAY - Vector2.ONE * 0.02, 0.07, 0.3, stone)
	lager(at, stone)
	var cut := mat(LIME * 0.28, 0.5, 0.0, 1.0)
	for i in 5:
		box(scene, Vector3(0.016, 0.004, BAY.y * 2.0 - 0.6), at + Vector3((float(i) - 2.0) * 0.6,
			0.014, 0), cut)
	rippenzeichen(at, loaded, YELLOW)

# --- 2 · KORB MIT ETIKETT: geflochtener Boden, warmes Holz, Ton-Etikett an der Rippe -------------

func _korb(at: Vector3, loaded: bool) -> void:
	boden(at, mat(Color(0.12, 0.08, 0.05), 0.6, 0.0, 1.0))
	var warp := mat(Color(0.62, 0.47, 0.27), 0.4, 0.0, 0.9)
	var weft := mat(Color(0.5, 0.36, 0.2), 0.4, 0.0, 0.9)
	for i in 9:
		box(scene, Vector3(0.28, 0.02, BAY.y * 2.0 - 0.2), at + Vector3((float(i) - 4.0) * 0.39,
			0.022, 0), warp)
	for i in 13:
		box(scene, Vector3(BAY.x * 2.0 - 0.2, 0.02, 0.28), at + Vector3(0, 0.034 if i % 2 == 0
			else 0.016, (float(i) - 6.0) * 0.4), weft)
	# Der Korbrand: ein gedrehter Wulst rings um die Mulde.
	ring(at + Vector3(0, 0.3, 0), BAY - Vector2.ONE * 0.015, 0.06, 0.06, warp)
	# Das Ton-Etikett liegt auf der Rippe und leuchtet, wenn eine Tafel im Korb liegt.
	box(scene, Vector3(0.09, 0.02, 0.7), Vector3(at.x - BAY.x - 0.04, FLOOR_Y + DECK + 0.008, at.z),
		mat(CLAY, 0.5, 0.0, 0.95))
	rippenzeichen(at + Vector3(0, 0.02, 0), loaded, YELLOW, 0.36)

# --- 3 · SANDBETT: feiner Sand, der Abdruck der Tafel, Wellen ringsum -------------------------------

func _sandbett(at: Vector3, loaded: bool) -> void:
	var sand := mat(Color(0.72, 0.63, 0.46), 0.42, 0.0, 1.0)
	boden(at, sand, 0.04)
	# Der Abdruck: wo eine Tafel hingehört, ist der Sand dunkel und glatt gedrückt.
	var press := mat(Color(0.42, 0.35, 0.24), 0.45, 0.0, 1.0)
	box(scene, Vector3(CARD.x * 2.0 - 0.9, 0.006, CARD.y * 2.0), at + Vector3(0, 0.041, 0), press)
	box(scene, Vector3(CARD.x * 2.0, 0.006, CARD.y * 2.0 - 0.9), at + Vector3(0, 0.041, 0), press)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			cyl(scene, 0.46, 0.006, at + Vector3(sx * (CARD.x - 0.46), 0.041, sz * (CARD.y - 0.46)), press)
	# Gerechte Wellen im Abdruck, wie von einem Kamm gezogen.
	var groove := mat(Color(0.3, 0.25, 0.17), 0.45, 0.0, 1.0)
	for i in 7:
		box(scene, Vector3(0.02, 0.004, CARD.y * 2.0 - 1.2), at + Vector3((float(i) - 3.0) * 0.42,
			0.046, 0), groove)
	ring(at + Vector3(0, 0.04, 0), BAY - Vector2.ONE * 0.03, 0.045, 0.012,
		lamp(YELLOW, 1.5 if loaded else 0.12))

# --- 4 · BRENNOFEN: Schamotte, Glutschlitze unter der Tafel -----------------------------------------

func _brennofen(at: Vector3, loaded: bool) -> void:
	var brick := mat(Color(0.22, 0.1, 0.07), 0.6, 0.0, 0.95)
	boden(at, brick)
	var glut := lamp(EMBER, 1.9 if loaded else 0.5)
	for i in 6:
		box(scene, Vector3(0.14, 0.008, BAY.y * 2.0 - 0.36), at + Vector3((float(i) - 2.5) * 0.56,
			0.016, 0), glut)
	var joint := mat(Color(0.08, 0.04, 0.03), 0.6, 0.0, 1.0)
	for i in 7:
		box(scene, Vector3(BAY.x * 2.0 - 0.2, 0.01, 0.03), at + Vector3(0, 0.017,
			(float(i) - 3.0) * 0.8), joint)
	# Drei Schamotte-Stege tragen die Tafel über der Glut.
	for i in 3:
		box(scene, Vector3(CARD.x * 1.8, SEAT, 0.2), at + Vector3(0, SEAT * 0.5,
			(float(i) - 1.0) * 1.7), mat(Color(0.4, 0.22, 0.15), 0.5, 0.0, 0.95))
	rippenzeichen(at, loaded, EMBER, 0.9)

# --- 5 · MUSEUMSLADE: dunkler Schaum mit Paßform, Messing-Schildhalter mit Nummer ----------------

func _museumslade(at: Vector3, loaded: bool) -> void:
	var foam := mat(Color(0.1, 0.105, 0.12), 0.8, 0.0, 1.0)
	boden(at, foam, 0.04)
	# Die Paßform: eine helle Linie zeichnet die Tafel nach, zwei Griffmulden an den Langseiten.
	var line := mat(Color(0.3, 0.31, 0.35), 0.8, 0.0, 1.0)
	ring(at + Vector3(0, 0.04, 0), CARD + Vector2(0.04, 0.04), 0.03, 0.006, line)
	var notch := mat(Color(0.03, 0.03, 0.035), 0.8, 0.0, 1.0)
	for dir: float in [-1.0, 1.0]:
		cyl(scene, 0.34, 0.006, at + Vector3(dir * (CARD.x - 0.3), 0.043, 0), notch)
	var brass := mat(Color(0.78, 0.6, 0.26), 0.5, 0.8, 0.3)
	# Der Schildhalter auf der Rippe: Messingrahmen, Inventarnummer, eine Diode meldet die Tafel.
	var plate := Vector3(at.x - BAY.x - 0.04, FLOOR_Y + DECK, at.z - 0.9)
	box(scene, Vector3(0.1, 0.012, 1.3), plate + Vector3(0, 0.006, 0), brass)
	box(scene, Vector3(0.07, 0.004, 1.2), plate + Vector3(0, 0.014, 0), mat(Color(0.85, 0.82, 0.74),
		0.6, 0.0, 0.9))
	box(scene, Vector3(0.06, 0.006, 0.3), plate + Vector3(0, 0.003, 1.2),
		lamp(YELLOW, 1.8 if loaded else 0.16))

# --- 6 · TONHÜLLE: die untere Hälfte der Hülle, innen der Abdruck der Schrift -------------------

func _tonhuelle(at: Vector3, loaded: bool) -> void:
	boden(at, mat(Color(0.16, 0.09, 0.06), 0.6, 0.0, 1.0))
	var clay := mat(CLAY, 0.45, 0.0, 0.95)
	# Der aufgebrochene Rand der Hülle: ungleich hohe Scherben rings um die Tafel.
	var heights := [0.42, 0.3, 0.38, 0.24, 0.44, 0.33, 0.27, 0.4]
	for i in 8:
		var z := -BAY.y + 0.36 + float(i) * 0.665
		for dir: float in [-1.0, 1.0]:
			var high: float = heights[(i + (3 if dir > 0.0 else 0)) % 8]
			box(scene, Vector3(0.07, high, 0.66), at + Vector3(dir * (BAY.x - 0.055), high * 0.5, z), clay)
	for i in 5:
		var x := -BAY.x + 0.4 + float(i) * 0.72
		for dir: float in [-1.0, 1.0]:
			var high: float = heights[(i * 3 + (5 if dir > 0.0 else 1)) % 8]
			box(scene, Vector3(0.7, high, 0.07), at + Vector3(x, high * 0.5, dir * (BAY.y - 0.055)), clay)
	# Innen steht der Abdruck der Schrift: leuchtende Keile, belegt scheinen sie am Rand vor.
	var glow := lamp(YELLOW, 1.6 if loaded else 0.4)
	for row in 4:
		for n in 9:
			keil(at + Vector3(0, 0.014, 0), 1.2 - float(row) * 0.72, -2.0 + float(n) * 0.5,
				0.2 if (row + n) % 3 else 0.28, glow)
	ring(at + Vector3(0, 0.012, 0), BAY - Vector2.ONE * 0.1, 0.035, 0.01, glow)
	lager(at, clay)

# --- 7 · NISCHE MIT GLUT (Empfehlung): Kalkstein-Nische, darunter glimmt der Ofen ------------------

func _nische_mit_glut(at: Vector3, loaded: bool) -> void:
	boden(at, mat(Color(0.1, 0.07, 0.05), 0.7, 0.0, 1.0))
	var stone := mat(LIME * 0.62, 0.36, 0.0, 0.95)
	var glut := lamp(YELLOW.lerp(EMBER, 0.45), 1.9 if loaded else 0.45)
	# Glutschlitze im Nischenboden, quer unter der Tafel; die Stufe darüber fängt ihr Licht.
	for i in 5:
		box(scene, Vector3(BAY.x * 2.0 - 0.5, 0.008, 0.2), at + Vector3(0, 0.016,
			(float(i) - 2.0) * 0.95), glut)
	ring(at, BAY - Vector2.ONE * 0.02, 0.07, 0.3, stone)
	ring(at + Vector3(0, 0.012, 0), BAY - Vector2.ONE * 0.09, 0.05, 0.012, glut)
	lager(at, stone)
	# In die Stufe geschnittene Keile an der Kopfseite, und das Zeichen auf der Rippe.
	for n in 6:
		keil(at + Vector3(0, 0.3, 0), BAY.x - 0.03, -1.9 + float(n) * 0.76, 0.03, glut)
	rippenzeichen(at, loaded, YELLOW.lerp(EMBER, 0.3), 0.9)
