extends SceneTree
## Fumble: fünf ENTWÜRFE für den Lochkarten-Tray des Magazins (2026-11-21). Reine Sichtprobe,
## nichts davon ist im Spiel. Aufruf:
##   Godot --path . --resolution 1280x720 --position 4000,2400 --quit-after 900 \
##     --script tools/godot_punch_tray_variants.gd
## Bilder: E:/Generated Images/Fumble/lochkarten_tray_entwuerfe_2026-11-21/

const OUT := "E:/Generated Images/Fumble/lochkarten_tray_entwuerfe_2026-11-21/"
const K := 3.2
const NAMES := ["1_lichtkasten", "2_buerstenleser", "3_lochraster", "4_leuchtpodest",
	"5_kartenbahn"]
const TITLES := ["1 · LICHTKASTEN", "2 · BÜRSTENLESER", "3 · LOCHRASTER", "4 · LEUCHTPODEST",
	"5 · KARTENBAHN"]

## Die Grube (halbe Maße: x längs = Bild-hoch, y quer = Bild-breit) und ihre Höhen.
const HOLE := Vector2(3.82, 5.675)
const SLOT_END := 5.312
const BAY := Vector2(1.8315, 2.687)
const CARD := Vector2(1.728, 2.592)
const FLOOR_Y := -0.859
const DECK := 0.54
const SEAT := 0.056
const CARD_T := 0.128
const BAY_X := [1.91, -1.91]
const BAY_Z := [-2.928, 2.565]
const MARGIN := Vector3(0.21, 0.21, 0.9)

const GREEN := Color(0.33, 0.9, 0.5)
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

func wedge(host: Node3D, at: Vector3, high: float, material: Material) -> void:
	var leg := 0.156 * K - 0.02
	var corner := Vector2(CARD.x, -CARD.y)
	MagazinTrayDress._wedge(host, "Keil", [corner, corner + Vector2(-leg, 0.0),
		corner + Vector2(0.0, leg)], at.y, at.y + high, material).position = \
		Vector3(at.x, 0.0, at.z)

func card(at: Vector3, seat := SEAT) -> void:
	var cell := DataCellView.new()
	scene.add_child(cell)
	cell.setup(String(Pack.SHELF_ORDER[0]))
	cell.rotation.y = -PI / 2.0
	cell.set_body_scale(K)
	cell.position = Vector3(at.x, FLOOR_Y + seat, at.z)

# --- Der Tray ----------------------------------------------------------------------

## Was jeder Entwurf teilt: Filz, Schacht, Lamellen-Deck, Rollschiene, Fassung, Lichtleiste.
func _build(variant: int) -> void:
	var looks := [
		{"deck": mat(Color(0.4, 0.42, 0.44), 0.3, 0.3, 0.35), "frame": mat(Color(0.52, 0.54, 0.56), 0.3, 0.35, 0.35)},
		{"deck": mat(Color(0.075, 0.075, 0.085), 0.9, 0.1, 0.6), "frame": mat(Color(0.1, 0.1, 0.11), 0.8, 0.1, 0.5)},
		{"deck": mat(Color(0.03, 0.035, 0.04), 1.0, 0.0, 0.6), "frame": mat(Color(0.03, 0.035, 0.04), 1.0, 0.0, 0.5)},
		{"deck": mat(Color(0.16, 0.17, 0.19), 0.6, 0.3, 0.4), "frame": mat(Color(0.3, 0.31, 0.34), 0.4, 0.35, 0.35)},
		{"deck": mat(Color(0.5, 0.52, 0.54), 0.28, 0.4, 0.3), "frame": mat(Color(0.5, 0.52, 0.54), 0.28, 0.4, 0.3)},
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
	# Lippen längs (links, Mitte, vor der Schiene), Rippen quer (oben, Mitte, unten).
	for lip: Vector2 in [Vector2(-HOLE.y + 0.03, 0.06), Vector2(-0.181, 0.12),
			Vector2(SLOT_END - 0.03, 0.06)]:
		box(scene, Vector3(HOLE.x * 2.0, DECK, lip.y), Vector3(0, top, lip.x), deck)
	var slots := SLOT_END + HOLE.y
	for rib: Vector2 in [Vector2(HOLE.x - 0.039, 0.078), Vector2(0, 0.157),
			Vector2(-HOLE.x + 0.039, 0.078)]:
		box(scene, Vector3(rib.y, DECK - 0.002, slots), Vector3(rib.x, top - 0.001,
			-HOLE.y + slots * 0.5), deck)
	# Die Rollschiene rechts.
	var rail_w := HOLE.y - SLOT_END
	var rail_z := SLOT_END + rail_w * 0.5
	box(scene, Vector3(HOLE.x * 2.0, DECK - 0.17, rail_w), Vector3(0, FLOOR_Y + (DECK - 0.17) * 0.5,
		rail_z), dark)
	for dir: float in [-1.0, 1.0]:
		box(scene, Vector3(HOLE.x * 2.0, DECK, 0.07), Vector3(0, top, rail_z + dir * (rail_w * 0.5
			- 0.035)), deck)
	box(scene, Vector3(3.0, 0.2, rail_w * 0.62), Vector3(2.2, FLOOR_Y + DECK - 0.08, rail_z),
		lamp(GREEN, 0.9))
	# Die Fassung auf dem Filz und die Lichtleiste.
	var high := 0.028
	box(scene, Vector3(MARGIN.y, high, (HOLE.y + MARGIN.x) * 2.0), Vector3(HOLE.x + MARGIN.y * 0.5,
		high * 0.5, 0), frame)
	box(scene, Vector3(MARGIN.z, high, (HOLE.y + MARGIN.x) * 2.0), Vector3(-HOLE.x - MARGIN.z * 0.5,
		high * 0.5, 0), frame)
	for dir: float in [-1.0, 1.0]:
		box(scene, Vector3(HOLE.x * 2.0, high, MARGIN.x), Vector3(0, high * 0.5,
			dir * (HOLE.y + MARGIN.x * 0.5)), frame)
	box(scene, Vector3(0.62, 0.036, HOLE.y * 2.0 - 0.1), Vector3(-HOLE.x - 0.13 - 0.31, 0.03, 0),
		lamp(GREEN * 0.6, 0.55))
	text(scene, "Zahl 2", Vector3(-HOLE.x - 0.44, 0.052, 0), 0.4, GREEN.lerp(Color.WHITE, 0.7))
	text(scene, TITLES[variant], Vector3(HOLE.x + 0.95, 0.01, 0), 0.5, Color(0.85, 0.85, 0.9))
	for row in 2:
		for across in 2:
			var at := Vector3(BAY_X[row], FLOOR_Y, BAY_Z[across])
			var loaded := row != across
			var seat := SEAT
			match variant:
				0: _lichtkasten(at, loaded)
				1: _buerstenleser(at, loaded)
				2: _lochraster(at, loaded)
				3:
					seat = _leuchtpodest(at, loaded)
				4: _kartenbahn(at, loaded)
			if loaded:
				card(at, seat)
	match variant:
		0: _frame_lichtkasten()
		1: _frame_buerstenleser()
		2: _frame_lochraster()
		3: _frame_leuchtpodest()
		4: _frame_kartenbahn()

## Vier Streifen als Rahmen um ein Rechteck (halbe Maße half), width breit.
func ring(at: Vector3, half: Vector2, width: float, high: float, material: Material) -> void:
	for dir: float in [-1.0, 1.0]:
		box(scene, Vector3(width, high, half.y * 2.0), at + Vector3(dir * (half.x - width * 0.5),
			high * 0.5, 0), material)
		box(scene, Vector3(half.x * 2.0 - width * 2.0, high, width), at + Vector3(0, high * 0.5,
			dir * (half.y - width * 0.5)), material)

# --- 1 · LICHTKASTEN: Opalglas-Leuchtfeld in schmaler Stahlfassung ------------------------

func _lichtkasten(at: Vector3, loaded: bool) -> void:
	var opal := lamp(Color(0.72, 0.95, 0.8), 1.25 if loaded else 0.16)
	box(scene, Vector3(BAY.x * 2.0 - 0.3, 0.02, BAY.y * 2.0 - 0.3), at + Vector3(0, 0.01, 0), opal)
	var steel := mat(STEEL, 0.4, 0.6, 0.3)
	ring(at, BAY - Vector2.ONE * 0.02, 0.13, 0.03, steel)
	# Feines Raster im Glas: zwölf Zeilen der Karte.
	var line := mat(Color(0.2, 0.3, 0.24), 0.5)
	for i in 11:
		box(scene, Vector3(0.012, 0.004, BAY.y * 2.0 - 0.36), at + Vector3((float(i) - 5.0) * 0.27,
			0.022, 0), line)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			if sx > 0.0 and sz < 0.0:
				continue
			box(scene, Vector3(0.3, SEAT, 0.3), at + Vector3(sx * (CARD.x - 0.15), SEAT * 0.5,
				sz * (CARD.y - 0.15)), steel)
	wedge(scene, at, SEAT + CARD_T, lamp(GREEN, 0.9))

func _frame_lichtkasten() -> void:
	var line := lamp(Color(0.72, 0.95, 0.8), 0.8)
	for dir: float in [-1.0, 1.0]:
		box(scene, Vector3(HOLE.x * 2.0 + 0.1, 0.01, 0.03), Vector3(0, 0.033,
			dir * (HOLE.y + 0.105)), line)
	box(scene, Vector3(0.03, 0.01, HOLE.y * 2.0 + 0.24), Vector3(HOLE.x + 0.105, 0.033, 0), line)

# --- 2 · BÜRSTENLESER: Messing-Kontaktschienen, Licht aus den Fugen dazwischen ------------------

func _buerstenleser(at: Vector3, loaded: bool) -> void:
	var slit := lamp(GREEN, 1.4 if loaded else 0.12)
	box(scene, Vector3(BAY.x * 2.0 - 0.24, 0.012, BAY.y * 2.0 - 0.24), at + Vector3(0, 0.006, 0), slit)
	var brass := mat(BRASS, 0.45, 0.8, 0.3)
	# Zwölf Kontaktschienen längs der Karte: zwischen ihnen scheint das Licht.
	for i in 12:
		box(scene, Vector3(0.2, 0.03, BAY.y * 2.0 - 0.5), at + Vector3((float(i) - 5.5) * 0.276,
			0.022, 0), brass)
	var block := mat(Color(0.13, 0.13, 0.15), 0.8, 0.2, 0.5)
	for sz: float in [-1.0, 1.0]:
		box(scene, Vector3(BAY.x * 2.0 - 0.3, SEAT, 0.16), at + Vector3(0, SEAT * 0.5,
			sz * (CARD.y - 0.08)), block)
		for i in 12:
			cyl(scene, 0.03, 0.02, at + Vector3((float(i) - 5.5) * 0.276, SEAT + 0.002,
				sz * (CARD.y + 0.045)), brass)
	wedge(scene, at, SEAT + CARD_T, brass)

func _frame_buerstenleser() -> void:
	var brass := mat(BRASS, 0.5, 0.8, 0.3)
	# Die Spalten-Skala der Lochkarte am oberen Rand, jede zehnte Marke länger.
	for i in 81:
		var z := -HOLE.y + 0.1 + float(i) * (HOLE.y + SLOT_END - 0.2) / 80.0
		var long := i % 10 == 0
		box(scene, Vector3(0.11 if long else 0.06, 0.006, 0.022), Vector3(HOLE.x + 0.04
			+ (0.055 if long else 0.03), 0.031, z), brass)
	for i in 4:
		cyl(scene, 0.06, 0.02, Vector3(-HOLE.x - 0.07, 0.036, -HOLE.y + 0.5 + float(i) * 3.5), brass)

# --- 3 · LOCHRASTER: schwarzes Glas, je Lochposition eine Leuchtdiode ---------------------------

func _lochraster(at: Vector3, loaded: bool) -> void:
	var glass := mat(Color(0.012, 0.016, 0.02), 1.0, 0.3, 0.08)
	box(scene, Vector3(BAY.x * 2.0 - 0.2, 0.014, BAY.y * 2.0 - 0.2), at + Vector3(0, 0.007, 0), glass)
	var dot := lamp(GREEN, 2.2 if loaded else 0.22)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.14, 0.006, 0.09)
	mesh.material = dot
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = 140
	for i in 14:
		for d in 10:
			multi.set_instance_transform(i * 10 + d, Transform3D(Basis.IDENTITY, Vector3(
				(0.42 - float(d) * 0.86 / 9.0) * K, 0.018, (-0.72 + float(i) * 1.46 / 13.0) * K)))
	var dots := MultiMeshInstance3D.new()
	dots.multimesh = multi
	dots.position = at
	scene.add_child(dots)
	ring(at, BAY - Vector2.ONE * 0.03, 0.035, 0.016, lamp(GREEN, 0.9 if loaded else 0.3))
	wedge(scene, at, SEAT + CARD_T, lamp(GREEN, 0.7))

func _frame_lochraster() -> void:
	ring(Vector3(0, 0.029, 0), HOLE + Vector2(0.12, 0.12), 0.025, 0.006, lamp(GREEN, 0.7))
	for row in 2:
		for d in 10:
			text(scene, str(d), Vector3(BAY_X[row] + (0.42 - float(d) * 0.86 / 9.0) * K, 0.03,
				-HOLE.y - 0.105), 0.13, GREEN.lerp(Color.WHITE, 0.4))

# --- 4 · LEUCHTPODEST: die Karte liegt hoch auf einem leuchtenden Glasblock ---------------------

func _leuchtpodest(at: Vector3, loaded: bool) -> float:
	var seat := DECK - CARD_T - 0.05
	var glow := lamp(Color(0.6, 0.95, 0.72), 1.3 if loaded else 0.14)
	var block := Vector2(CARD.x - 0.16, CARD.y - 0.16)
	box(scene, Vector3(block.x * 2.0, seat - 0.02, block.y * 2.0), at + Vector3(0, (seat - 0.02) * 0.5,
		0), glow)
	box(scene, Vector3(BAY.x * 2.0 - 0.1, 0.01, BAY.y * 2.0 - 0.1), at + Vector3(0, 0.005, 0),
		mat(Color(0.02, 0.03, 0.03), 1.0, 0.4, 0.1))
	var steel := mat(STEEL, 0.4, 0.6, 0.3)
	# Ein Stahlkragen trägt die Karte am Rand, vier Pfosten in den Ecken.
	for dir: float in [-1.0, 1.0]:
		box(scene, Vector3(0.05, 0.03, block.y * 2.0 + 0.1), at + Vector3(dir * (block.x + 0.025),
			seat - 0.015, 0), steel)
		box(scene, Vector3(block.x * 2.0, 0.03, 0.05), at + Vector3(0, seat - 0.015,
			dir * (block.y + 0.025)), steel)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			if sx > 0.0 and sz < 0.0:
				continue
			cyl(scene, 0.045, seat + CARD_T, at + Vector3(sx * (CARD.x + 0.05), (seat + CARD_T) * 0.5,
				sz * (CARD.y + 0.045)), steel)
	wedge(scene, at + Vector3(0, seat - SEAT, 0), SEAT + CARD_T, lamp(GREEN, 0.9))
	return seat

func _frame_leuchtpodest() -> void:
	var line := lamp(Color(0.6, 0.95, 0.72), 0.7)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			box(scene, Vector3(0.5, 0.008, 0.03), Vector3(sx * (HOLE.x - 0.25), 0.032,
				sz * (HOLE.y + 0.105)), line)

# --- 5 · KARTENBAHN: Stahlbahn mit Transportlöchern, Walzen in den Rippen, Leseschlitz ------------

func _kartenbahn(at: Vector3, loaded: bool) -> void:
	var track := mat(Color(0.3, 0.31, 0.33), 0.35, 0.5, 0.3)
	box(scene, Vector3(BAY.x * 2.0 - 0.1, 0.014, BAY.y * 2.0 - 0.1), at + Vector3(0, 0.007, 0), track)
	var slit := lamp(GREEN, 1.6 if loaded else 0.18)
	# Drei Leseschlitze quer zur Bahn und das Licht unter der ganzen Karte.
	for i in 3:
		box(scene, Vector3(BAY.x * 2.0 - 0.7, 0.008, 0.5), at + Vector3(0, 0.018,
			(float(i) - 1.0) * 1.62), slit)
	box(scene, Vector3(BAY.x * 2.0 - 0.9, 0.006, BAY.y * 2.0 - 0.6), at + Vector3(0, 0.016, 0),
		lamp(GREEN, 0.9 if loaded else 0.05))
	var hole := mat(Color(0.01, 0.01, 0.012), 0.5)
	var steel := mat(STEEL, 0.45, 0.7, 0.25)
	for sx: float in [-1.0, 1.0]:
		box(scene, Vector3(0.14, SEAT, BAY.y * 2.0 - 0.2), at + Vector3(sx * (CARD.x - 0.07),
			SEAT * 0.5, 0), steel)
		for i in 13:
			cyl(scene, 0.035, 0.004, at + Vector3(sx * (CARD.x - 0.07), SEAT + 0.002,
				(float(i) - 6.0) * 0.39), hole)
	# Die Transportwalzen liegen in den Rippen über und unter der Karte.
	var rubber := mat(Color(0.05, 0.05, 0.055), 0.9, 0.0, 0.9)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			cyl(scene, 0.07, 1.3, at + Vector3(sx * (BAY.x + 0.02), DECK - 0.04, sz * 1.25), rubber, 2)
			cyl(scene, 0.03, 1.6, at + Vector3(sx * (BAY.x + 0.02), DECK - 0.04, sz * 1.25), steel, 2)
	wedge(scene, at, SEAT + CARD_T, steel)

func _frame_kartenbahn() -> void:
	var hole := mat(Color(0.01, 0.01, 0.012), 0.5)
	for dir: float in [-1.0, 1.0]:
		for i in 30:
			cyl(scene, 0.04, 0.004, Vector3(dir * (HOLE.x + 0.105), 0.03,
				-HOLE.y + 0.2 + float(i) * 0.385), hole)
	var steel := mat(STEEL, 0.45, 0.7, 0.25)
	box(scene, Vector3(0.04, 0.014, HOLE.y * 2.0), Vector3(-HOLE.x - 0.06, 0.035, 0), steel)
