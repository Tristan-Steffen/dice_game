extends SceneTree
## Fumble: drei ENTWÜRFE für die FORM des Spieltischs (gefrästes Deck statt endlosem Filz).
## Blockouts um den ECHTEN Tisch: das Spiel bootet, der Filz verschwindet, der Entwurf steht
## darum. Reine Sichtprobe, nichts davon ist im Spiel. Aufruf:
##   Godot --path . --resolution 1600x900 --position 4000,2400 --quit-after 6000 \
##     --script tools/godot_table_shape_variants.gd
## Bilder: E:/Generated Images/Fumble/tisch_formen_2026-11-22/

const OUT := "E:/Generated Images/Fumble/tisch_formen_2026-11-22/"
const NAMES := ["a_wanne", "b_platine", "c_bogen"]
const VIEWS := ["uebersicht", "schraeg", "sitz"]

## Die Anzeige in Welt (x = Bild-oben, z = Bild-rechts).
const X0 := -42.4
const X1 := 42.4
const Z0 := -62.4
const Z1 := 73.44
const ZC := 5.52

const DECK := Color(0.075, 0.08, 0.1)
const GRAPHITE := Color(0.13, 0.135, 0.16)
const STEEL := Color(0.4, 0.43, 0.48)
const NICKEL := Color(0.62, 0.64, 0.68)
const WHITE := Color(0.8, 0.82, 0.86)
const PCB := Color(0.03, 0.037, 0.045)
const GOLD := Color(0.86, 0.64, 0.24)
const DARK := Color(0.012, 0.012, 0.018)
const AMBER := Color(1.0, 0.6, 0.18)

const SHADER_CODE := "
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 tint : source_color = vec3(0.5);
uniform float seams = 0.0;
uniform float gloss = 0.25;
uniform float glow = 0.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (n.z < 0.0) { n = -n; }
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(normalize(-VERTEX), 0.0)).xyz);
	vec3 l = normalize(vec3(-0.35, 0.8, -0.45));
	vec3 c = tint * (0.3 + 0.7 * max(dot(nw, l), 0.0));
	c += gloss * pow(max(dot(nw, normalize(l + v)), 0.0), 40.0);
	c += gloss * 0.2 * pow(1.0 - max(dot(nw, v), 0.0), 3.0);
	if (seams > 0.0 && nw.y > 0.9) {
		vec2 g = abs(fract(wpos.xz / seams - 0.5) - 0.5) * seams;
		c *= 1.0 - 0.5 * (1.0 - step(0.07, min(g.x, g.y)));
	}
	c *= 0.12 + 0.88 * smoothstep(-30.0, -1.0, min(wpos.y, 0.0));
	ALBEDO = mix(c, tint * 1.5, glow);
}
"

var shader: Shader
var game: Node
var holder: Node3D
var my_cam: Camera3D
var step := 0
var wait := 0
var started := false
var shots: Array[Image] = []
var background: CanvasItem
var skin: ShaderMaterial

const SKIN_CODE := "
shader_type canvas_item;
uniform vec3 tint : source_color;
uniform float seam_px = 337.5;
uniform vec2 rect_size;
void fragment() {
	vec2 g = abs(fract(UV * rect_size / seam_px - 0.5) - 0.5) * seam_px;
	COLOR = vec4(tint * (1.0 - 0.5 * (1.0 - step(2.6, min(g.x, g.y)))), 1.0);
}
"

## Der Grund der Anzeige ist selbst Filz: für die Probe trägt er die Haut des Decks.
func _find_background() -> void:
	var screen: Node = game.get("table_screen")
	var felt: Material = screen.get("_felt_material")
	for node in screen.find_children("*", "ColorRect", true, false):
		if (node as ColorRect).material == felt:
			background = node
	skin = ShaderMaterial.new()
	skin.shader = Shader.new()
	skin.shader.code = SKIN_CODE
	skin.set_shader_parameter("rect_size", Vector2(5094, 3180))
	if background != null:
		background.material = skin
	else:
		print("Anzeige-Grund nicht gefunden")

func _skin_display(tint: Color, seams: float) -> void:
	skin.set_shader_parameter("tint", tint * 0.86)
	skin.set_shader_parameter("seam_px", seams * 37.5)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	shader = Shader.new()
	shader.code = SHADER_CODE
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	my_cam = Camera3D.new()
	my_cam.near = 1.0
	my_cam.far = 2000.0
	root.add_child(my_cam)

func _process(_delta: float) -> bool:
	var ms := Time.get_ticks_msec()
	if not started:
		if ms > 2500:
			started = true
			game.call("_on_title_new_game")
			game.get("table_ground").visible = false
			_find_background()
		return false
	if ms < 15000:
		return false
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
	match step % 3:
		0:
			if holder != null:
				holder.queue_free()
			holder = Node3D.new()
			root.add_child(holder)
			[_build_wanne, _build_platine, _build_bogen][variant].call()
			(game.get("camera_rig") as Camera3D).current = true
		1:
			my_cam.fov = 40.0
			my_cam.look_at_from_position(Vector3(-140.0, 96.0, -58.0), Vector3(10.0, 0.0, 12.0))
			my_cam.current = true
		2:
			my_cam.fov = 55.0
			my_cam.look_at_from_position(Vector3(-128.0, 36.0, ZC - 30.0), Vector3(20.0, 0.0, ZC + 4.0))
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

# --- Bausteine ---------------------------------------------------------------------

func mat(color: Color, seams := 0.0, gloss := 0.25, glow := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("seams", seams)
	m.set_shader_parameter("gloss", gloss)
	m.set_shader_parameter("glow", glow)
	return m

func _add(mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(node)
	return node

func _tri_mesh(verts: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5

## Zieht ein Profil (Versatz nach außen, Höhe) am Umriß (x, z) entlang.
func sweep(outline: PackedVector2Array, profile: PackedVector2Array, material: Material,
		closed := true, side := 0.0, mod := Callable()) -> void:
	var n := outline.size()
	if side == 0.0:
		side = signf(area(outline))
	var rings: Array[PackedVector3Array] = []
	for i in n:
		var prev := outline[(i - 1 + n) % n]
		var next := outline[(i + 1) % n]
		if not closed and i == 0:
			prev = outline[0] * 2.0 - outline[1]
		if not closed and i == n - 1:
			next = outline[i] * 2.0 - outline[i - 1]
		var e1 := (outline[i] - prev).normalized()
		var e2 := (next - outline[i]).normalized()
		var n1 := Vector2(e1.y, -e1.x)
		var m := (n1 + Vector2(e2.y, -e2.x)).normalized()
		var normal := m / maxf(m.dot(n1), 0.5) * side
		var scale := Vector2.ONE
		if mod.is_valid():
			scale = mod.call(outline[i])
		var ring := PackedVector3Array()
		for p in profile:
			var q := outline[i] + normal * p.x * scale.x
			ring.append(Vector3(q.x, p.y * (scale.y if p.y > 0.0 else 1.0), q.y))
		rings.append(ring)
	var verts := PackedVector3Array()
	for i in (n if closed else n - 1):
		var a := rings[i]
		var b := rings[(i + 1) % n]
		for j in profile.size() - 1:
			verts.append_array([a[j], b[j], b[j + 1], a[j], b[j + 1], a[j + 1]])
	_add(_tri_mesh(verts), material)

func plate(poly: PackedVector2Array, y: float, material: Material) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		print("Platte nicht trianguliert: ", poly.size())
		return
	var verts := PackedVector3Array()
	for i in idx:
		verts.append(Vector3(poly[i].x, y, poly[i].y))
	_add(_tri_mesh(verts), material)

## Deckplatte mit dem Loch der Anzeige: in zwei Hälften geschnitten, je ein einfaches Polygon.
func deck(outline: PackedVector2Array, material: Material, y := 0.04) -> void:
	var hole := PackedVector2Array([Vector2(X0, Z0), Vector2(X1, Z0), Vector2(X1, Z1), Vector2(X0, Z1)])
	outline = outline.duplicate()
	if Geometry2D.is_polygon_clockwise(outline):
		outline.reverse()
	if Geometry2D.is_polygon_clockwise(hole):
		hole.reverse()
	for half in [[-900.0, ZC], [ZC, 900.0]]:
		var cut := PackedVector2Array([Vector2(-900, half[0]), Vector2(900, half[0]),
			Vector2(900, half[1]), Vector2(-900, half[1])])
		if Geometry2D.is_polygon_clockwise(cut):
			cut.reverse()
		for part in Geometry2D.intersect_polygons(outline, cut):
			for piece in Geometry2D.clip_polygons(part, hole):
				plate(piece, y, material)

func box(size: Vector3, pos: Vector3, material: Material, yaw := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := _add(mesh, material)
	node.position = pos
	node.rotation.y = yaw
	return node

func cyl(radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 40
	var node := _add(mesh, material)
	node.position = pos
	return node

func bar(a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var node := cyl(radius, a.distance_to(b), (a + b) * 0.5, material)
	(node.mesh as CylinderMesh).radial_segments = 12
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	node.basis = Basis(x, y, x.cross(y))

func circle(cx: float, cz: float, r: float, n := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cx + cos(a) * r, cz + sin(a) * r))
	return pts

func rounded_rect(cx: float, cz: float, hx: float, hz: float, r: float, seg := 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for c in 4:
		var mid := Vector2(cx + corners[c].x * (hx - r), cz + corners[c].y * (hz - r))
		for i in seg + 1:
			var a := PI * 0.5 * (c + float(i) / seg)
			pts.append(mid + Vector2(cos(a), sin(a)) * r)
	return pts

func fan(c: Vector3, r: float, frame: Material) -> void:
	cyl(r, 0.2, c + Vector3(0, 0.1, 0), mat(DARK))
	sweep(circle(c.x, c.z, r), PackedVector2Array([Vector2(0, c.y), Vector2(0.15, c.y + 1.0),
		Vector2(1.2, c.y + 1.0), Vector2(1.5, c.y)]), frame)
	cyl(r * 0.26, 1.0, c + Vector3(0, 0.5, 0), mat(STEEL, 0.0, 0.5))
	var blade := mat(GRAPHITE.lightened(0.12), 0.0, 0.4)
	for i in 9:
		var a := TAU * i / 9.0
		var node := box(Vector3(r * 0.66, 0.1, r * 0.34), c + Vector3(cos(a), 0, sin(a)) * r * 0.6
			+ Vector3(0, 0.5, 0), blade)
		node.basis = Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, 0.4)

func pts(list: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, list.size(), 2):
		out.append(Vector2(list[i], list[i + 1]))
	return out

# --- A · WANNE: die Craps-Wanne, rund, hohe Lamellenwand, gepolsterte Reling ----------

func _build_wanne() -> void:
	var inner := rounded_rect(0.0, ZC, 52.0, 81.0, 34.0)
	_skin_display(DECK, 9.0)
	deck(inner, mat(DECK, 9.0, 0.3))
	# Spielerseite abgesenkt, damit die Wand keine Station verdeckt.
	var low := func(p: Vector2) -> Vector2:
		return Vector2(1.0, lerpf(0.42, 1.0, smoothstep(-34.0, 28.0, p.x)))
	sweep(inner, pts([0, 0, 0.3, 1.4, 1.0, 1.4, 1.3, 2.8, 2.0, 2.8, 2.3, 4.2, 3.0, 4.2, 3.3, 5.6,
		4.0, 5.6, 4.3, 7.0]), mat(GRAPHITE, 0.0, 0.5), true, 0.0, low)
	sweep(inner, pts([4.3, 7.0, 4.3, 7.3, 4.9, 7.3]), mat(AMBER, 0.0, 0.0, 1.0), true, 0.0, low)
	sweep(inner, pts([4.9, 7.3, 5.6, 8.0, 8.5, 8.0, 8.5, 7.3]), mat(WHITE, 0.0, 0.4), true, 0.0, low)
	sweep(inner, pts([8.5, 7.3, 10.6, 7.3]), mat(DARK), true, 0.0, low)
	sweep(inner, pts([10.6, 7.3, 10.6, 8.0, 14.6, 8.0, 15.7, 7.0, 15.9, 4.4]), mat(WHITE, 0.0, 0.4),
		true, 0.0, low)
	sweep(inner, pts([15.9, 4.4, 14.9, 3.6, 13.5, -36.0]), mat(GRAPHITE, 0.0, 0.3), true, 0.0, low)
	# Heatpipes an der hinteren Wand.
	var back := PackedVector2Array()
	for i in range(inner.size() - 6, inner.size() + 17):
		back.append(inner[i % inner.size()])
	for k in 3:
		var ring := PackedVector2Array()
		for i in 10:
			var a := TAU * i / 10.0
			ring.append(Vector2(-1.6 - k * 1.5 + cos(a) * 0.55, 0.6 + sin(a) * 0.55))
		ring.append(ring[0])
		sweep(back, ring, mat(NICKEL, 0.0, 0.7), false, signf(area(inner)))
	# Lüftungsschlitze an beiden Enden.
	for sgn in [-1.0, 1.0]:
		for k in 9:
			box(Vector3(1.0, 0.1, 6.5), Vector3(-16.0 + k * 4.0, 0.03, ZC + sgn * 74.6), mat(DARK))

# --- B · PLATINE: der Tisch ist eine Steckkarte - flach, offen, asymmetrisch ----------

func _build_platine() -> void:
	var c := 6.0
	var o := pts([-52, -84 + c, -52 + c, -84, 56 - c, -84, 56, -84 + c, 56, 102 - c, 56 - c, 102,
		-52 + c, 102, -52, 102 - c])
	o.reverse()
	_skin_display(PCB, 2.2)
	deck(o, mat(PCB, 2.2, 0.35))
	sweep(o, pts([0, -0.02, 0, -1.2, -2.5, -1.2, -2.5, -3.0]), mat(Color(0.07, 0.09, 0.085), 0.0, 0.3))
	sweep(o, pts([-2.5, -3.0, -1.5, -3.0, -1.5, -4.2, -15.0, -4.2, -17.0, -40.0]), mat(STEEL, 0.0, 0.4))
	# Goldfinger an der Spielerkante.
	box(Vector3(5.0, 1.2, 74.0), Vector3(-54.5, -0.62, ZC), mat(PCB))
	for k in 29:
		if k != 9:
			box(Vector3(4.2, 0.1, 1.6), Vector3(-54.6, 0.03, ZC - 35.0 + k * 2.5), mat(GOLD, 0.0, 0.8))
	# Slotblech hinten mit zehn USB-Ports.
	var steel := mat(STEEL, 0.0, 0.6)
	box(Vector3(1.0, 8.0, 172.0), Vector3(56.5, 2.0, 9.0), steel)
	box(Vector3(4.5, 0.5, 172.0), Vector3(58.5, 6.0, 9.0), steel)
	for k in 10:
		box(Vector3(0.3, 1.3, 3.4), Vector3(55.95, 2.4, -30.0 + k * 6.2), mat(DARK))
	for k in 2:
		box(Vector3(0.3, 2.6, 9.0), Vector3(55.95, 2.6, 46.0 + k * 13.0), mat(WHITE))
	# Rechter Flügel: weiße Haube mit zwei Lüftern.
	var white := mat(WHITE, 0.0, 0.4)
	box(Vector3(98.0, 3.0, 23.0), Vector3(2.0, 1.5, 89.5), white)
	box(Vector3(98.0, 0.3, 0.5), Vector3(2.0, 3.1, 78.3), mat(AMBER, 0.0, 0.0, 1.0))
	for x in [-22.0, 26.0]:
		cyl(10.4, 0.1, Vector3(x, 3.02, 89.5), mat(DARK))
		fan(Vector3(x, 3.0, 89.5), 9.0, mat(GRAPHITE, 0.0, 0.5))
	for k in 3:
		box(Vector3(14.0, 0.08, 0.7), Vector3(2.0 + (k - 1) * 2.4, 3.03, 89.5), mat(DARK), 0.9)
	# Linker Rand: Kühlrippen, von dort vier Heatpipes über die hintere Kante zum Flügel.
	for k in 28:
		box(Vector3(0.6, 3.2, 14.0), Vector3(-36.0 + k * 2.66, 1.6, -74.0), mat(NICKEL, 0.0, 0.6))
	for k in 4:
		var x := 45.8 + k * 2.0
		bar(Vector3(34.0 - k * 3.0, 0.75, -74.0 - k * 1.2), Vector3(x, 0.75, -62.0 + k * 1.5), 0.7, mat(NICKEL, 0.0, 0.8))
		bar(Vector3(x, 0.75, -62.0 + k * 1.5), Vector3(x, 0.75, 78.0), 0.7, mat(NICKEL, 0.0, 0.8))
	# Kleinteile an der Spielerkante: Drosseln, Elkos, zwei Chips.
	for k in 9:
		box(Vector3(2.8, 2.0, 2.8), Vector3(-47.0, 1.0, -74.0 + k * 3.6), mat(GRAPHITE.lightened(0.08), 0.0, 0.5))
	for k in 7:
		cyl(1.2, 2.4, Vector3(-47.2, 1.2, 50.0 + k * 3.4), mat(STEEL, 0.0, 0.7))
	# Abstandsbolzen in den Ecken.
	for p in [Vector2(-47, -79), Vector2(51, -79), Vector2(-47, 97), Vector2(51, 97)]:
		cyl(2.2, 0.16, Vector3(p.x, 0.06, p.y), mat(GOLD, 0.0, 0.8))
		cyl(1.2, 0.7, Vector3(p.x, 0.35, p.y), steel)

# --- C · BOGEN: gerade Spielerkante, hinten ein facettierter Maschinenraum in Terrassen ----

func _build_bogen() -> void:
	var arc := PackedVector2Array()
	for k in 11:
		var t := PI * k / 10.0
		arc.append(Vector2(-26.0 + 112.0 * sin(t), ZC + 96.0 * cos(t)))
	var o := PackedVector2Array([Vector2(-50, ZC - 82.0), Vector2(-50, ZC + 82.0)])
	o.append_array(arc)
	var side := signf(area(o))
	_skin_display(DECK, 9.0)
	deck(o, mat(DECK, 9.0, 0.3))
	sweep(o, pts([0, 0, 0, -2.0, -5.0, -38.0]), mat(GRAPHITE, 0.0, 0.3))
	# Armauflage an der Spielerkante.
	var near := PackedVector2Array([arc[10], o[0], o[1], arc[0]])
	sweep(near, pts([0, 0, 0, 1.0, -0.8, 1.7, -6.2, 1.5, -6.8, 0]), mat(WHITE, 0.0, 0.4), false, side)
	sweep(near, pts([-6.8, 0.02, -7.5, 0.02]), mat(AMBER, 0.0, 0.0, 1.0), false, side)
	# Terrassen: zur Mitte hin breit und hoch, an den Flanken laufen sie aus.
	var grow := func(p: Vector2) -> Vector2:
		var s := clampf((p.x + 26.0) / 112.0, 0.0, 1.0)
		return Vector2(lerpf(0.2, 1.0, pow(s, 4.0)), lerpf(0.4, 1.0, s * s))
	var graphite := mat(GRAPHITE, 0.0, 0.5)
	sweep(arc, pts([0, 0, 0, 11.0]), graphite, false, side, grow)
	sweep(arc, pts([0, 11.0, -9.0, 11.0]), mat(WHITE, 0.0, 0.4), false, side, grow)
	sweep(arc, pts([-9.0, 11.0, -9.0, 10.6, -9.5, 10.6]), mat(AMBER, 0.0, 0.0, 1.0), false, side, grow)
	sweep(arc, pts([-9.5, 10.6, -9.8, 7.0, -21.0, 7.0, -21.6, 3.5]), graphite, false, side, grow)
	sweep(arc, pts([-21.6, 3.5, -31.0, 3.5, -31.5, 0]), mat(WHITE, 0.0, 0.4), false, side, grow)
	# Maschinenraum: Rippenblock auf der mittleren Terrasse, Heatpipes hinab zur Anzeige.
	for k in 25:
		box(Vector3(9.0, 4.4, 0.6), Vector3(70.0, 9.2, ZC - 31.2 + k * 2.6), mat(NICKEL, 0.0, 0.6))
	for k in 7:
		var z := ZC + (k - 3) * 8.0
		var pipe := mat(NICKEL, 0.0, 0.8)
		bar(Vector3(66.0, 7.7, z), Vector3(60.5, 7.7, z), 0.65, pipe)
		bar(Vector3(60.5, 7.7, z), Vector3(58.0, 4.2, z), 0.65, pipe)
		bar(Vector3(58.0, 4.2, z), Vector3(51.0, 4.2, z), 0.65, pipe)
		bar(Vector3(51.0, 4.2, z), Vector3(49.0, 0.7, z), 0.65, pipe)
		bar(Vector3(49.0, 0.7, z), Vector3(43.5, 0.7, z), 0.65, pipe)
	# Je zwei Lüfter in den Flanken neben der Anzeige.
	for sgn in [-1.0, 1.0]:
		for x in [-22.0, -3.0]:
			fan(Vector3(x, 0.0, ZC + sgn * 77.6), 7.2, mat(WHITE, 0.0, 0.4))
