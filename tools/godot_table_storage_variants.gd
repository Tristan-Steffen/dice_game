extends SceneTree
## Fumble: das LAGER im freien linken Band der Craps-Wanne (der Bestand des Hauses: Chips, Würfel,
## Charms, Karten, Pakete, Module) in drei Entwürfen. Blockouts in echten Maßen, reine Sichtprobe:
##   Godot --path . --resolution 1600x900 --position 4000,2400 --quit-after 600 \
##     --script tools/godot_table_storage_variants.gd
## Bilder: E:/Generated Images/Fumble/lager_entwuerfe_2026-11-23/

const OUT := "E:/Generated Images/Fumble/lager_entwuerfe_2026-11-23/"
const NAMES := ["1_banktablett", "2_vitrinen", "3_tribuene"]
const VIEWS := ["tisch", "band", "schraeg"]
const BODY := preload("res://scripts/table/table_body_view.gd")
const TECH := ["Fensterrahmen", "Platine", "Chip", "Speicher", "Elko", "Heatpipe", "Rippe"]

const DECK := Color(0.075, 0.08, 0.1)
const LACQUER := Color(0.02, 0.02, 0.028)
const LEATHER := Color(0.2, 0.06, 0.15)
const GOLD := Color(0.86, 0.64, 0.24)
const AMBER := Color(1.0, 0.66, 0.24)
const STEEL := Color(0.4, 0.43, 0.48)
const VELVET := Color(0.05, 0.02, 0.06)
const DIE := Color(0.13, 0.13, 0.18)
const SORTS := [Color("#50fa7b"), Color("#ff79c6"), Color("#ffd319"), Color("#bd93f9")]
const CARRIERS := [Color(0.7, 0.66, 0.58), Color(0.05, 0.05, 0.06), Color(0.62, 0.45, 0.3),
	Color(0.04, 0.07, 0.06)]
const CARRIER_THICK := [0.13, 0.4, 0.41, 0.11]
const RARITIES := [Color(0.7, 0.72, 0.78), Color(0.3, 0.6, 1.0), Color(0.74, 0.46, 1.0),
	Color(1.0, 0.8, 0.3)]
const CHIPS := [Color(0.05, 0.11, 0.32), Color(0.40, 0.05, 0.09), Color(0.03, 0.22, 0.11),
	Color(0.06, 0.05, 0.08), Color(0.20, 0.06, 0.34), Color(0.42, 0.16, 0.02), Color(0.50, 0.52, 0.58)]
const CHIP_EDGE := [Color(0.24, 0.66, 0.98), Color(1.0, 0.37, 0.33), Color(0.34, 0.95, 0.58),
	Color(1.0, 0.80, 0.30), Color(0.74, 0.46, 1.0), Color(1.0, 0.62, 0.22), Color(0.86, 0.92, 1.0)]
const CHIP_R := 0.9
const CHIP_H := 0.28
const DIE_EDGE := 1.7
const CARD := Vector2(3.46, 5.18)
const DISK := Vector3(6.67, 0.23, 6.39)
const PACK := Vector3(3.6, 1.3, 5.4)

var holder: Node3D
var cam: Camera3D
var band: Rect2
var step := 0
var wait := 0
var shots: Array[Image] = []
var _mats := {}
var body: Node3D
var cleared := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	RenderingServer.set_default_clear_color(Color.BLACK)
	body = BODY.new()
	root.add_child(body)
	band = BODY.free_band()
	var screen := PlaneMesh.new()
	screen.size = Vector2(BODY.DISPLAY.size.x, BODY.DISPLAY.size.y)
	var plane := MeshInstance3D.new()
	plane.mesh = screen
	var deck := mat(DECK, 0.3)
	deck.set_shader_parameter("seams", 9.0)
	plane.material_override = deck
	plane.position = Vector3(BODY.DISPLAY.get_center().x, 0.0, BODY.DISPLAY.get_center().y)
	root.add_child(plane)
	holder = Node3D.new()
	root.add_child(holder)
	var content: Rect2 = BODY.CONTENT
	box(Vector3(content.size.x, 0.02, content.size.y),
		Vector3(content.get_center().x, 0.03, content.get_center().y), mat(Color(0.05, 0.045, 0.08), 0.1))
	label("SPIEL", Vector3(content.get_center().x, 0.08, content.get_center().y), 9.0, Color(0.2, 0.18, 0.3))
	cam = Camera3D.new()
	cam.near = 1.0
	cam.far = 2000.0
	root.add_child(cam)
	cam.current = true

func _process(_delta: float) -> bool:
	if not cleared:
		cleared = true
		for child in body.get_children():
			for prefix: String in TECH:
				if String(child.name).begins_with(prefix):
					child.queue_free()
	wait += 1
	if wait < 6:
		return false
	wait = 0
	if step > 0:
		var last := step - 1
		var shot := root.get_texture().get_image()
		@warning_ignore("integer_division")
		shot.save_png(OUT + "%s_%s.png" % [NAMES[last / 3], VIEWS[last % 3]])
		shots.append(shot)
	@warning_ignore("integer_division")
	var variant := step / 3
	if variant >= NAMES.size():
		_save_sheet()
		return true
	var mid := band.get_center()
	var forward := Vector3(0.2588, -0.9659, 0.0)
	match step % 3:
		0:
			for child in holder.get_children():
				if child.has_meta("lager"):
					child.queue_free()
			match variant:
				0: _build_tray()
				1: _build_vitrines()
				2: _build_tribune()
			cam.fov = 40.0
			var c: Vector2 = BODY.inner_center()
			cam.look_at_from_position(Vector3(c.x, 0, c.y) - forward * 158.0, Vector3(c.x, 0, c.y), Vector3(1, 0, 0))
		1:
			var t := Vector3(mid.x, 0, mid.y + 12.0)
			cam.look_at_from_position(t - forward * 100.0, t, Vector3(1, 0, 0))
		2:
			cam.fov = 45.0
			cam.look_at_from_position(Vector3(-78.0, 34.0, -14.0), Vector3(-10.0, 0.0, -60.0))
	step += 1
	return false

func _save_sheet() -> void:
	var cell := Vector2i(800, 450)
	var sheet := Image.create(cell.x * 3, cell.y * NAMES.size(), false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var small := shots[i].duplicate() as Image
		small.convert(Image.FORMAT_RGBA8)
		small.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		@warning_ignore("integer_division")
		sheet.blit_rect(small, Rect2i(Vector2i.ZERO, cell), Vector2i((i % 3) * cell.x, (i / 3) * cell.y))
	sheet.save_png(OUT + "blatt.png")

# --- Entwurf 1: das BANKTABLETT - ein in Messing gefaßtes Tablett, alles liegt in Fächern ---------

func _build_tray() -> void:
	var mid := band.get_center()
	var half := Vector2(band.size.x * 0.5 - 0.6, band.size.y * 0.5 - 1.0)
	_framed_bed(mid, half, 0.0)
	var z := mid.y
	var w := half.y * 2.0 - 2.0
	var rows := [["CHARMS", 13.5, 25.2, disks], ["KARTEN", 3.5, 12.7, cards], ["PAKETE", -6.0, 2.7, packs],
		["WÜRFEL", -17.0, -6.8, dice], ["CHIPS", -34.0, -17.8, chip_rolls], ["MODULE", -40.3, -34.8, pins]]
	for row: Array in rows:
		var x0: float = row[1]
		var x1: float = row[2]
		bar(Vector3(x1 + 0.4, 0.3, z - half.y), Vector3(x1 + 0.4, 0.3, z + half.y), 0.14, mat(GOLD, 0.8))
		label(row[0], Vector3(x0 + 0.8, 0.12, z), 1.0, GOLD)
		(row[3] as Callable).call(Vector3((x0 + x1 + 1.6) * 0.5, 0.1, z), x1 - x0 - 1.8, w)

# --- Entwurf 2: drei VITRINEN - Inseln aus Lack mit Rauchglas-Haube und Lichtsaum -------------------

func _build_vitrines() -> void:
	var z := band.get_center().y
	var w := band.size.y - 3.0
	var islands := [[9.0, 26.0, [["CHARMS", 17.6, 25.5, disks], ["KARTEN", 9.5, 16.4, cards]]],
		[-13.0, 6.5, [["PAKETE", -2.5, 6.0, packs], ["WÜRFEL", -12.5, -3.5, dice]]],
		[-41.0, -15.5, [["CHIPS", -33.5, -16.0, chip_rolls], ["MODULE", -40.5, -34.5, pins]]]]
	for island: Array in islands:
		var x0: float = island[0]
		var x1: float = island[1]
		var c := Vector3((x0 + x1) * 0.5, 0.0, z)
		var size := Vector2(x1 - x0, w)
		box(Vector3(size.x, 1.2, size.y), c + Vector3(0, 0.6, 0), mat(LACQUER, 0.95))
		box(Vector3(size.x + 0.3, 0.18, size.y + 0.3), c + Vector3(0, 0.16, 0), light(AMBER))
		box(Vector3(size.x + 0.24, 0.16, size.y + 0.24), c + Vector3(0, 1.12, 0), mat(GOLD, 0.8))
		box(Vector3(size.x - 0.8, 0.04, size.y - 0.8), c + Vector3(0, 1.21, 0), mat(VELVET, 0.1))
		for row: Array in island[2]:
			var a: float = row[1]
			var b: float = row[2]
			label(row[0], Vector3(a + 0.7, 1.26, z), 0.9, GOLD)
			(row[3] as Callable).call(Vector3((a + b + 1.4) * 0.5, 1.24, z), b - a - 1.6, w - 2.0, 30.0)
		var glass := StandardMaterial3D.new()
		glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.55, 0.45, 0.7, 0.13)
		box(Vector3(size.x - 0.4, 4.2, size.y - 0.4), c + Vector3(0, 3.3, 0), glass)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var p := c + Vector3(sx * (size.x * 0.5 - 0.2), 0, sz * (size.y * 0.5 - 0.2))
				bar(p + Vector3(0, 1.2, 0), p + Vector3(0, 5.4, 0), 0.1, mat(GOLD, 0.8))
		box(Vector3(size.x - 0.2, 0.1, size.y - 0.2), c + Vector3(0, 5.42, 0), glass)

# --- Entwurf 3: die TRIBÜNE - drei Stufen zur Wand hin, der Bestand steht auf den Rängen -----------

func _build_tribune() -> void:
	var x0 := band.position.x + 0.5
	var x1 := band.end.x - 0.5
	var edges := [band.end.y - 0.5, band.end.y - 8.0, band.end.y - 16.2, band.position.y + 0.6]
	var heights := [0.8, 2.6, 4.4]
	for k in 3:
		var za: float = edges[k + 1]
		var zb: float = edges[k]
		var h: float = heights[k]
		var c := Vector3((x0 + x1) * 0.5, 0.0, (za + zb) * 0.5)
		box(Vector3(x1 - x0, h, zb - za), c + Vector3(0, h * 0.5, 0), mat(LEATHER, 0.4, 0.0, 2))
		box(Vector3(x1 - x0, 0.08, zb - za - 0.3), c + Vector3(0, h + 0.04, -0.15), mat(LACQUER, 0.95))
		bar(Vector3(x0, h + 0.05, zb), Vector3(x1, h + 0.05, zb), 0.16, mat(GOLD, 0.8))
		box(Vector3(x1 - x0, 0.12, 0.12), Vector3(c.x, h - 0.5, zb + 0.03), light(AMBER))
	var z0: float = (edges[0] + edges[1]) * 0.5
	var z1: float = (edges[1] + edges[2]) * 0.5
	var z2: float = (edges[2] + edges[3]) * 0.5
	var d0: float = edges[0] - edges[1] - 1.6
	var rows := [["CHIPS", -40.5, -12.0, z0, 0.9, d0, chip_towers], ["WÜRFEL", -10.0, 7.0, z0, 0.9, d0, dice],
		["MODULE", 9.0, 26.0, z0, 0.9, d0, pins], ["KARTEN", -40.5, -8.0, z1, 2.7, 6.2, cards],
		["PAKETE", -5.0, 26.0, z1, 2.7, 6.2, packs], ["CHARMS", -40.5, -8.5, z2, 4.5, 7.0, disks],
		["CHARMS", -5.0, 26.0, z2, 4.5, 7.0, disks]]
	for row: Array in rows:
		var a: float = row[1]
		var b: float = row[2]
		label(row[0], Vector3(a + 0.7, float(row[4]) + 0.03, row[3]), 0.9, GOLD)
		(row[6] as Callable).call(Vector3((a + b + 1.4) * 0.5, row[4], row[3]), b - a - 1.6, row[5])

# --- Bestand ---------------------------------------------------------------------------------------

func disks(at: Vector3, ex: float, ez: float, tilt := 55.0) -> void:
	var pitch := 1.3 if tilt > 45.0 else 2.3
	var cols := maxi(1, int(ez / 7.0))
	var reach := DISK.x * cos(deg_to_rad(tilt))
	var n := maxi(1, int((ex - reach) / pitch))
	var rise := sin(deg_to_rad(tilt)) * DISK.x * 0.5
	for c in cols:
		var z := at.z + (c - (cols - 1) * 0.5) * 7.3
		box(Vector3(ex, 0.4, 6.9), Vector3(at.x, at.y + 0.2, z), mat(LACQUER, 0.9))
		for i in n:
			var node := Node3D.new()
			node.set_meta("lager", true)
			holder.add_child(node)
			node.basis = Basis(Vector3(0, 0, 1), deg_to_rad(tilt))
			node.position = Vector3(at.x - ex * 0.5 + reach * 0.5 + 0.3 + i * pitch, at.y + rise + 0.4, z)
			box(DISK, Vector3.ZERO, mat(STEEL, 0.7), node)
			box(Vector3(3.7, 0.03, 5.3), Vector3(-1.2, 0.12, 0.0), mat(Color(0.02, 0.03, 0.05), 0.6), node)
			box(Vector3(3.7, 0.04, 0.35), Vector3(-1.2, 0.13, -2.85), light(RARITIES[(i * 7 + c * 3) % 4]), node)
			box(Vector3(1.7, 0.04, 3.4), Vector3(2.3, 0.12, 0.0), mat(Color(0.75, 0.77, 0.82), 0.9), node)

func cards(at: Vector3, ex: float, ez: float, _tilt := 0.0) -> void:
	var rows := maxi(1, int(ex / 4.0))
	var cols := maxi(1, int(ez / 5.7))
	for r in rows:
		for c in cols:
			var sort := (c + (r if cols < 4 else 0)) % 4
			var p := at + Vector3((r - (rows - 1) * 0.5) * 4.0, 0, (c - (cols - 1) * 0.5) * 5.7)
			var t: float = CARRIER_THICK[sort]
			var n := 3 + (r * 5 + c * 3) % 6
			for k in n:
				box(Vector3(CARD.x, t * 0.9, CARD.y), p + Vector3(0, t * (k + 0.5), 0),
					mat((CARRIERS[sort] as Color) * (0.85 + 0.15 * (k % 2)), 0.4))
			box(Vector3(CARD.x * 0.62, 0.03, CARD.y * 0.5), p + Vector3(0, t * n + 0.01, 0), light(SORTS[sort]))

func packs(at: Vector3, ex: float, ez: float, _tilt := 0.0) -> void:
	var rows := maxi(1, int(ex / 4.2))
	var cols := maxi(1, int(ez / 6.0))
	for r in rows:
		for c in cols:
			var p := at + Vector3((r - (rows - 1) * 0.5) * 4.2, 0, (c - (cols - 1) * 0.5) * 6.0)
			var n := 1 + (r * 3 + c * 2) % 3
			for k in n:
				var q := p + Vector3(0, PACK.y * (k + 0.5), 0)
				box(PACK - Vector3(0, 0.06, 0), q, mat(Color(0.03, 0.03, 0.04), 0.7))
				box(Vector3(PACK.x + 0.04, 0.5, 1.0), q + Vector3(0, 0.3, -1.4),
					light((SORTS[(r + c + k) % 4] as Color) * 0.8))
				box(Vector3(PACK.x * 0.5, 0.03, PACK.z * 0.36), q + Vector3(0, PACK.y * 0.5, 0.9),
					mat(Color(0.8, 0.8, 0.85), 0.9))

func dice(at: Vector3, ex: float, ez: float, _tilt := 0.0) -> void:
	var pitch := DIE_EDGE + 0.45
	var rows := maxi(1, int(ex / pitch))
	var cols := maxi(1, int(ez / pitch))
	box(Vector3(rows * pitch + 0.4, 0.3, cols * pitch + 0.4), at + Vector3(0, 0.15, 0), mat(VELVET, 0.1))
	for r in rows:
		for c in cols:
			var p := at + Vector3((r - (rows - 1) * 0.5) * pitch, 0.3 + DIE_EDGE * 0.5, (c - (cols - 1) * 0.5) * pitch)
			box(Vector3.ONE * DIE_EDGE, p, mat(DIE, 0.8))
			box(Vector3(0.9, 0.03, 0.9), p + Vector3(0, DIE_EDGE * 0.5, 0),
				light(Color(0.75, 0.9, 1.0) if (r + c * 3) % 5 else SORTS[(r + c) % 4]))

## Liegende Rollen wie im Rack eines Dealers: je Stückelung eine Rinne.
func chip_rolls(at: Vector3, ex: float, ez: float, _tilt := 0.0) -> void:
	var pitch := minf(2.1, ex / 7.0)
	var per := int((ez - 1.0) / CHIP_H)
	var turn := Basis(Vector3(1, 0, 0), PI * 0.5)
	for rank in 7:
		var x := at.x + (rank - 3) * pitch
		box(Vector3(pitch - 0.1, 0.5, ez), Vector3(x, at.y + 0.25, at.z), mat(LACQUER, 0.9))
		var fill := per - (rank * rank * per) / 70
		for k in fill:
			chip(Vector3(x, at.y + 0.5 + CHIP_R * 0.8, at.z - ez * 0.5 + 0.5 + (k + 0.5) * CHIP_H), turn, rank, k)

func chip_towers(at: Vector3, ex: float, ez: float, _tilt := 0.0) -> void:
	var pitch := CHIP_R * 2.3
	var rows := maxi(1, int(ex / pitch))
	var cols := maxi(1, int(ez / pitch))
	for r in rows:
		@warning_ignore("integer_division")
		var rank := mini(6, r * 7 / rows)
		for c in cols:
			var p := at + Vector3((r - (rows - 1) * 0.5) * pitch, 0, (c - (cols - 1) * 0.5) * pitch)
			for k in 20 - rank * 2 - (r + c) % 3:
				chip(p + Vector3(0, (k + 0.5) * CHIP_H, 0), Basis.IDENTITY, rank, k)

func chip(pos: Vector3, basis: Basis, rank: int, k: int) -> void:
	var mesh := _shared("chip", func() -> Mesh:
		var m := CylinderMesh.new()
		m.top_radius = CHIP_R
		m.bottom_radius = CHIP_R
		m.height = CHIP_H * 0.94
		m.radial_segments = 20
		return m)
	var color: Color = CHIPS[rank] if k % 4 else (CHIP_EDGE[rank] as Color) * 0.8
	var node := _add(mesh, mat(color, 0.6), holder)
	node.position = pos
	node.basis = basis

func pins(at: Vector3, ex: float, ez: float, _tilt := 0.0) -> void:
	var rows := maxi(1, int(ex / 1.4))
	var cols := maxi(1, int(ez / 2.3))
	box(Vector3(rows * 1.4 + 0.3, 0.2, cols * 2.3 + 0.3), at + Vector3(0, 0.1, 0), mat(VELVET, 0.1))
	for r in rows:
		for c in cols:
			var p := at + Vector3((r - (rows - 1) * 0.5) * 1.4, 0.5, (c - (cols - 1) * 0.5) * 2.3)
			box(Vector3(0.85, 0.6, 1.7), p, mat(Color(0.16, 0.17, 0.2), 0.7))
			box(Vector3(0.5, 0.04, 0.7), p + Vector3(0, 0.31, 0.3), light(RARITIES[(r * 3 + c) % 4]))

# --- Bausteine -------------------------------------------------------------------------------------

func _framed_bed(mid: Vector2, half: Vector2, y: float) -> void:
	box(Vector3(half.x * 2.0, 0.06, half.y * 2.0), Vector3(mid.x, y + 0.05, mid.y), mat(VELVET, 0.1))
	for s: float in [-1.0, 1.0]:
		box(Vector3(half.x * 2.0 + 1.0, 0.6, 0.5), Vector3(mid.x, y + 0.3, mid.y + s * (half.y + 0.25)), mat(GOLD, 0.8))
		box(Vector3(0.5, 0.6, half.y * 2.0 + 1.0), Vector3(mid.x + s * (half.x + 0.25), y + 0.3, mid.y), mat(GOLD, 0.8))

func mat(color: Color, gloss := 0.25, glow := 0.0, style := 0) -> ShaderMaterial:
	var key := "%s|%s|%s|%s" % [color, gloss, glow, style]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = BODY.SHADER
		m.set_shader_parameter("tint", color)
		m.set_shader_parameter("gloss", gloss)
		m.set_shader_parameter("glow", glow)
		m.set_shader_parameter("style", style)
		_mats[key] = m
	return _mats[key]

func light(color: Color) -> ShaderMaterial:
	return mat(color, 0.0, 1.0)

func _shared(key: String, make: Callable) -> Mesh:
	if not _mats.has(key):
		_mats[key] = make.call()
	return _mats[key]

func _add(mesh: Mesh, material: Material, parent: Node) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.set_meta("lager", true)
	parent.add_child(node)
	return node

func box(size: Vector3, pos: Vector3, material: Material, parent: Node = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := _add(mesh, material, holder if parent == null else parent)
	node.position = pos
	return node

func bar(a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12
	var node := _add(mesh, material, holder)
	node.position = (a + b) * 0.5
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	node.basis = Basis(x, y, x.cross(y))

func label(text: String, pos: Vector3, height: float, color: Color) -> void:
	var node := Label3D.new()
	node.text = text
	node.font_size = 96
	node.pixel_size = height / 68.0
	node.modulate = color
	node.outline_size = 0
	node.double_sided = true
	if text != "SPIEL":
		node.set_meta("lager", true)
	holder.add_child(node)
	node.position = pos
	node.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
