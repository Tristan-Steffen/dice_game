class_name TableBodyView
extends Node3D
## Der Tischkörper: eine CRAPS-WANNE in der Fassung NOIR um den Inhalt der Anzeige
## (Spieler-Wahl 2026-11-22, Plan docs/plan_tisch_noir.md). Prozedural, weil die Wanne dem
## Layout folgt: ein Profil (Versatz nach außen, Höhe) wird am Innen-Umriß entlanggezogen.
## Ebene (x, z): x = Bild-oben, z = Bild-rechts.

const SHADER := preload("res://assets/shaders/table_body.gdshader")

## Die Anzeige in Welt.
const DISPLAY := Rect2(-42.4, -62.4, 84.8, 135.84)
## Was auf der Anzeige belegt ist (gemessen: Fenster, Chip-Rahmen, Wurfplatz); hinten endet
## es an der PORT-EBENE der Charm-Reihe (gemessen 25,667) - dort steht die Rückwand.
const CONTENT := Rect2(-41.7, -43.68, 67.37, 112.85)
## Die Wurfgrube ist die waagerechte Mitte des Tischs.
const PIT_Z := -0.08
const MARGIN := 8.0
## Die Rückwand steht direkt hinter den USB-Ports.
const BACK_MARGIN := 0.0
## Der Wandfuß ist die senkrechte Leiste der USB-Ports (CharmRowView.RAIL_HEIGHT), rundum.
const FOOT_HEIGHT := 2.0
## So weit reicht der Wandkörper nach außen (Zarge).
const WALL_REACH := 14.2
const RADIUS := 9.0 + MARGIN
const FLOOR_Y := -40.0
## Die Spielerwand steht auf halber Höhe.
const NEAR_HEIGHT := 0.5

## Die Massefläche der Platine: PcbDeckView.POUR, um das eingemalte Licht (0,86) gehoben.
const DECK := Color(0.028, 0.111, 0.086)
const LACQUER := Color(0.02, 0.02, 0.028)
const LEATHER := Color(0.2, 0.06, 0.15)
const SMOKE := Color(0.075, 0.065, 0.095)
const GOLD := Color(0.86, 0.64, 0.24)
const DARK := Color(0.012, 0.012, 0.018)
const AMBER := Color(1.0, 0.66, 0.24)
## Der ganze Wandfuß ist EIN LED-Band um den Tisch; die USB-Ports sitzen darauf.
const LED := Color(0.2, 0.75, 0.9) * 0.6
const VIOLET := Color(0.62, 0.3, 1.0)
const CARPET := Color(0.075, 0.025, 0.08)

const STYLE_PLAIN := 0
const STYLE_PYRAMID := 1
const STYLE_QUILT := 2
const STYLE_CARPET := 3

static func inner_center() -> Vector2:
	return inner_rect().get_center()

static func inner_half() -> Vector2:
	return inner_rect().size * 0.5

## Vorn und seitlich MARGIN Luft, hinten die Wand an den Ports; waagerecht um die Grube gespiegelt.
static func inner_rect() -> Rect2:
	var half_z := maxf(CONTENT.end.y - PIT_Z, PIT_Z - CONTENT.position.y) + MARGIN
	var x0 := CONTENT.position.x - MARGIN
	return Rect2(x0, PIT_Z - half_z, CONTENT.end.x + BACK_MARGIN - x0, half_z * 2.0)

## Hinter dieser Linie (Welt-x) liegt die Anzeige ungenutzt im Wandkörper und wird nicht gezeichnet.
static func display_cut_x() -> float:
	return inner_rect().end.x + 1.0

static func inner_outline() -> PackedVector2Array:
	var c := inner_center()
	var half := inner_half()
	return rounded_rect(c.x, c.y, half.x, half.y, RADIUS)

## Das freie Band links der Fenster (der Inhalt liegt um die Grube schief).
static func free_band() -> Rect2:
	var inner := inner_rect()
	var z0 := inner.position.y + MARGIN * 0.5
	return Rect2(inner.position.x + MARGIN, z0, inner.size.x - MARGIN * 2.0,
		CONTENT.position.y - MARGIN * 0.5 - z0)

static func rounded_rect(cx: float, cz: float, hx: float, hz: float, r: float,
		seg := 12) -> PackedVector2Array:
	var out := PackedVector2Array()
	var corners: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for c in 4:
		var mid := Vector2(cx + corners[c].x * (hx - r), cz + corners[c].y * (hz - r))
		for i in seg + 1:
			var a := PI * 0.5 * (c + float(i) / seg)
			var p := mid + Vector2(cos(a), sin(a)) * r
			if out.is_empty() or (out[-1].distance_to(p) > 0.01 and out[0].distance_to(p) > 0.01):
				out.append(p)
	return out

func _ready() -> void:
	var c := inner_center()
	var half := inner_half()
	var inner := inner_outline()
	_build_floor(c)
	_build_deck(inner)
	_build_wall(inner, c, half)
	_build_back_rail(c, half)
	_build_legs(c, half)
	var bank := TableBankView.new()
	bank.name = "Bank"
	add_child(bank)

# --- Teile -------------------------------------------------------------------------

func _build_floor(c: Vector2) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(900, 900)
	var carpet := _mat(CARPET, 0.0, STYLE_CARPET)
	carpet.set_shader_parameter("carpet_center", c)
	_add("Teppich", mesh, carpet).position = Vector3(c.x, FLOOR_Y, c.y)

## Deck-Ring um die Anzeige, darauf die eine goldene Layout-Linie.
func _build_deck(inner: PackedVector2Array) -> void:
	var deck := _mat(DECK, 0.3)
	var hole := _rect_poly(DISPLAY)
	var outline := inner.duplicate()
	if Geometry2D.is_polygon_clockwise(outline):
		outline.reverse()
	# In zwei Hälften geschnitten bleibt jedes Stück ein einfaches Polygon.
	var mid := DISPLAY.get_center().y
	var verts := PackedVector3Array()
	for span: Vector2 in [Vector2(-900.0, mid), Vector2(mid, 900.0)]:
		var cut := _rect_poly(Rect2(-900.0, span.x, 1800.0, span.y - span.x))
		for part: PackedVector2Array in Geometry2D.intersect_polygons(outline, cut):
			for piece: PackedVector2Array in Geometry2D.clip_polygons(part, hole):
				for i in Geometry2D.triangulate_polygon(piece):
					verts.append(Vector3(piece[i].x, 0.04, piece[i].y))
	if not verts.is_empty():
		_add("Deck", _tri_mesh(verts), deck)
	_sweep("Layoutlinie", inner, [-1.5, 0.09, -2.0, 0.09], _gold())

func _build_wall(inner: PackedVector2Array, c: Vector2, half: Vector2) -> void:
	var low := func(p: Vector2) -> float:
		return lerpf(NEAR_HEIGHT, 1.0, smoothstep(c.x - half.x * 0.67, c.x + half.x * 0.55, p.x))
	var lacquer := _mat(LACQUER, 0.95)
	_sweep("LedLeiste", inner, [0, 0, 0, FOOT_HEIGHT, 0.3, FOOT_HEIGHT], _light(LED), low)
	_sweep("Pyramidenwand", inner, [0.3, FOOT_HEIGHT, 1.6, 8.6], _mat(SMOKE, 0.5, STYLE_PYRAMID), low)
	_sweep("Lichtlippe", inner, [1.6, 8.6, 1.2, 8.9, 1.2, 9.3], _light(AMBER), low)
	_sweep("Ablage", inner, [1.2, 9.3, 1.2, 9.9, 5.6, 9.9], lacquer, low)
	_sweep("Reling", inner, [5.6, 9.9, 6.1, 11.5, 8.0, 12.2, 12.2, 12.2, 14.1, 11.3, 14.7, 9.4],
		_mat(LEATHER, 0.4, STYLE_QUILT), low)
	_sweep("Keder", inner, [14.7, 9.4, 15.1, 9.0, 14.7, 8.6], _gold(), low)
	_sweep("Zarge", inner, [14.7, 8.6, WALL_REACH, -9.0], lacquer, low)
	_sweep("Messingband", inner, [WALL_REACH, -9.0, 14.5, -10.0, 14.0, -11.0], _gold())
	_sweep("Unterseite", inner, [14.0, -11.0, 2.0, -12.0], _mat(DARK))
	_sweep("Unterlicht", inner, [13.6, -11.2, 12.4, -11.6], _light(VIOLET))

## Messingstange auf der hinteren Ablage.
func _build_back_rail(c: Vector2, half: Vector2) -> void:
	var span := half.y - RADIUS
	var x := c.x + half.x + 3.4
	_bar("Stange", Vector3(x, 10.7, c.y - span), Vector3(x, 10.7, c.y + span), 0.45, _gold())
	for k in 7:
		var z := c.y - span + span * 2.0 * k / 6.0
		_bar("Stuetze%d" % k, Vector3(x, 9.9, z), Vector3(x, 10.7, z), 0.3, _gold())

func _build_legs(c: Vector2, half: Vector2) -> void:
	var lacquer := _mat(LACQUER, 0.95)
	var height := -11.0 - FLOOR_Y
	for sz: float in [-1.0, 1.0]:
		for sx: float in [-1.0, 1.0]:
			var p := c + Vector2(sx * (half.x - 14.0), sz * (half.y - 18.0))
			_box("Bein", Vector3(13.0, height, 13.0), Vector3(p.x, FLOOR_Y + height * 0.5, p.y), lacquer)
			_box("Beinschuh", Vector3(14.2, 1.6, 14.2), Vector3(p.x, FLOOR_Y + 0.8, p.y), _gold())

# --- Bausteine ---------------------------------------------------------------------

func _mat(color: Color, gloss := 0.25, style := STYLE_PLAIN) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("gloss", gloss)
	m.set_shader_parameter("style", style)
	return m

func _gold() -> ShaderMaterial:
	return _mat(GOLD, 0.8)

func _light(color: Color) -> ShaderMaterial:
	var m := _mat(color, 0.0)
	m.set_shader_parameter("glow", 1.0)
	return m

func _add(part: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _tri_mesh(verts: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _rect_poly(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)])

static func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5

## Außen-Normalen je Umrißpunkt, auf Gehrung verlängert.
static func outline_normals(outline: PackedVector2Array) -> PackedVector2Array:
	var n := outline.size()
	var side := signf(_area(outline))
	var out := PackedVector2Array()
	for i in n:
		var e1 := (outline[i] - outline[(i - 1 + n) % n]).normalized()
		var e2 := (outline[(i + 1) % n] - outline[i]).normalized()
		var n1 := Vector2(e1.y, -e1.x)
		var m := (n1 + Vector2(e2.y, -e2.x)).normalized()
		out.append(m / maxf(m.dot(n1), 0.5) * side)
	return out

## Zieht ein Profil (Paare Versatz nach außen, Höhe) am Umriß entlang; height staucht alles über 0.
func _sweep(part: String, outline: PackedVector2Array, profile: Array, material: Material,
		height := Callable()) -> void:
	var n := outline.size()
	var nrm := outline_normals(outline)
	var rings: Array[PackedVector3Array] = []
	for i in n:
		var squash := 1.0
		if height.is_valid():
			squash = height.call(outline[i])
		var ring := PackedVector3Array()
		for j in range(0, profile.size(), 2):
			var q := outline[i] + nrm[i] * float(profile[j])
			var y := float(profile[j + 1])
			ring.append(Vector3(q.x, y * (squash if y > 0.0 else 1.0), q.y))
		rings.append(ring)
	var verts := PackedVector3Array()
	for i in n:
		var a := rings[i]
		var b := rings[(i + 1) % n]
		for j in a.size() - 1:
			verts.append_array([a[j], b[j], b[j + 1], a[j], b[j + 1], a[j + 1]])
	_add(part, _tri_mesh(verts), material)

func _box(part: String, size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add(part, mesh, material).position = pos

func _cyl(part: String, radius: float, length: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 16
	var node := _add(part, mesh, material)
	node.position = pos
	return node

func _bar(part: String, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var node := _cyl(part, radius, a.distance_to(b), (a + b) * 0.5, material)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	node.basis = Basis(x, y, x.cross(y))
