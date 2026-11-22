extends SceneTree
## Fumble: die CRAPS-WANNE (mittlere Weite, auf die Wurfgrube zentriert - Spieler-Wahl) in drei
## MATERIAL-Fassungen: Klassik, Noir, Lounge. Blockouts um den ECHTEN Tisch, reine Sichtprobe. Aufruf:
##   Godot --path . --resolution 1600x900 --position 4000,2400 --quit-after 6000 \
##     --script tools/godot_table_craps_look_variants.gd
## Bilder: E:/Generated Images/Fumble/tisch_craps_material_2026-11-22/

const OUT := "E:/Generated Images/Fumble/tisch_craps_material_2026-11-22/"
const NAMES := ["1_klassik", "2_noir", "3_lounge"]
## Luft zwischen Inhalt und Wand je Entwurf (Welt); < 0 = die weite Wanne der Vorrunde.
const MARGIN := 10.0
const VIEWS := ["uebersicht", "schraeg", "sitz"]

## Die Anzeige in Welt (x = Bild-oben, z = Bild-rechts).
const X0 := -42.4
const X1 := 42.4
const Z0 := -62.4
const Z1 := 73.44
const ZC := 5.52
const FLOOR_Y := -40.0

const DECK := Color(0.075, 0.08, 0.1)
const LACQUER := Color(0.02, 0.02, 0.028)
const MIDNIGHT := Color(0.03, 0.05, 0.13)
const WALNUT := Color(0.26, 0.12, 0.06)
const LEATHER := Color(0.12, 0.095, 0.14)
const OXBLOOD := Color(0.34, 0.05, 0.07)
const RUBBER := Color(0.2, 0.08, 0.3)
const GOLD := Color(0.86, 0.64, 0.24)
const DARK := Color(0.012, 0.012, 0.018)
const AMBER := Color(1.0, 0.66, 0.24)
const VIOLET := Color(0.62, 0.3, 1.0)
const TEAL := Color(0.3, 0.95, 0.8)
const IVORY := Color(0.7, 0.66, 0.58)
const AUBERGINE := Color(0.2, 0.06, 0.15)
const SMOKE := Color(0.075, 0.065, 0.095)
const NAVY_RUBBER := Color(0.08, 0.11, 0.3)
const CARPET := Color(0.075, 0.025, 0.08)
const CHIP_COLORS := [Color(0.85, 0.85, 0.85), Color(0.75, 0.1, 0.12), Color(0.1, 0.5, 0.26),
	Color(0.05, 0.05, 0.06), Color(0.5, 0.25, 0.85), Color(0.9, 0.5, 0.12)]

## Stil: 0 glatt, 1 Diamant-Pyramiden (Wand), 2 gestepptes Leder, 3 Teppich, 4 Holz.
const SHADER_CODE := "
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 tint : source_color = vec3(0.5);
uniform float seams = 0.0;
uniform float gloss = 0.25;
uniform float glow = 0.0;
uniform int style = 0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (n.z < 0.0) { n = -n; }
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(normalize(-VERTEX), 0.0)).xyz);
	vec3 l = normalize(vec3(-0.35, 0.8, -0.45));
	vec3 base = tint;
	float shade = 0.3 + 0.7 * max(dot(nw, l), 0.0);
	if (style == 3) {
		vec2 q = vec2(wpos.x + wpos.z, wpos.x - wpos.z) / 16.0;
		vec2 d = 0.5 - abs(fract(q) - 0.5);
		float line = 1.0 - smoothstep(0.02, 0.045, min(d.x, d.y));
		float spot = 1.0 - smoothstep(0.1, 0.13, length(fract(q) - 0.5));
		vec3 c = tint + vec3(0.5, 0.36, 0.12) * (line * 0.2 + spot * 0.14);
		ALBEDO = c * (1.0 - smoothstep(80.0, 280.0, length(wpos.xz - vec2(0.0, 5.5))));
	} else {
		if (style == 1 && abs(nw.y) < 0.85) {
			vec2 t = normalize(vec2(nw.z, -nw.x));
			vec2 f = fract(vec2(dot(wpos.xz, t), wpos.y) / 1.5) - 0.5;
			shade *= abs(f.x) > abs(f.y) ? (f.x > 0.0 ? 1.3 : 0.6) : (f.y > 0.0 ? 1.55 : 0.8);
		}
		if (style == 2) {
			vec2 d = 0.5 - abs(fract(vec2(wpos.x + wpos.z, wpos.x - wpos.z) / 3.4) - 0.5);
			shade *= 0.5 + 0.75 * sqrt(d.x * d.y * 4.0);
			if (d.x < 0.07 && d.y < 0.07) { base = vec3(0.86, 0.64, 0.24); }
		}
		if (style == 4) {
			base *= 0.88 + 0.1 * sin(wpos.y * 1.6 + sin(wpos.z * 0.11 + wpos.x * 0.13) * 2.0)
				+ 0.04 * sin(wpos.y * 9.0 + wpos.z * 0.4);
		}
		vec3 c = base * shade;
		c += gloss * pow(max(dot(nw, normalize(l + v)), 0.0), 40.0);
		c += gloss * 0.2 * pow(1.0 - max(dot(nw, v), 0.0), 3.0);
		vec3 r = reflect(-v, nw);
		c += gloss * gloss * 0.3 * smoothstep(0.78, 0.84, r.y) * step(0.0, sin(r.x * 9.0));
		if (seams > 0.0 && nw.y > 0.9) {
			vec2 g = abs(fract(wpos.xz / seams - 0.5) - 0.5) * seams;
			c *= 1.0 - 0.5 * (1.0 - step(0.07, min(g.x, g.y)));
		}
		c *= 0.25 + 0.75 * smoothstep(-55.0, -1.0, min(wpos.y, 0.0));
		ALBEDO = mix(c, tint * 1.5, glow);
	}
}
"

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

var shader: Shader
var game: Node
var holder: Node3D
var my_cam: Camera3D
var step := 0
var wait := 0
var started := false
var shots: Array[Image] = []
var content := Rect2()
## Die Wurfgrube ist die waagerechte Mitte des Tischs (Spieler-Wunsch).
var pit_z := 0.0
var crop_shader: Shader

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
			_skin_display()
			_measure_content()
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
			var carpet := PlaneMesh.new()
			carpet.size = Vector2(900, 900)
			_add(carpet, mat(CARPET, 0.0, 0.0, 0.0, 3)).position = Vector3(0, FLOOR_Y, ZC)
			_build_craps(variant)
			(game.get("camera_rig") as Camera3D).current = true
		1:
			my_cam.fov = 40.0
			my_cam.look_at_from_position(Vector3(-168.0, 104.0, -72.0), Vector3(4.0, -6.0, 10.0))
			my_cam.current = true
		2:
			my_cam.fov = 55.0
			my_cam.look_at_from_position(Vector3(-140.0, 34.0, ZC - 34.0), Vector3(20.0, -4.0, ZC + 4.0))
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

## Der Grund der Anzeige ist selbst Filz: für die Probe trägt er die Haut des Decks.
func _skin_display() -> void:
	var screen: Node = game.get("table_screen")
	var felt: Material = screen.get("_felt_material")
	var skin := ShaderMaterial.new()
	skin.shader = Shader.new()
	skin.shader.code = SKIN_CODE
	skin.set_shader_parameter("rect_size", Vector2(5094, 3180))
	skin.set_shader_parameter("tint", DECK * 0.86)
	for node in screen.find_children("*", "ColorRect", true, false):
		if (node as ColorRect).material == felt:
			(node as ColorRect).material = skin

# --- Bausteine ---------------------------------------------------------------------

func mat(color: Color, seams := 0.0, gloss := 0.25, glow := 0.0, style := 0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("seams", seams)
	m.set_shader_parameter("gloss", gloss)
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("style", style)
	return m

func gold() -> ShaderMaterial:
	return mat(GOLD, 0.0, 0.8)

func light(color: Color) -> ShaderMaterial:
	return mat(color, 0.0, 0.0, 1.0)

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

## Außen-Normalen je Umrißpunkt (auf Gehrung verlängert).
func normals(outline: PackedVector2Array, closed := true, side := 0.0) -> PackedVector2Array:
	var n := outline.size()
	if side == 0.0:
		side = signf(area(outline))
	var out := PackedVector2Array()
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
		out.append(m / maxf(m.dot(n1), 0.5) * side)
	return out

## Zieht ein Profil (Versatz nach außen, Höhe) am Umriß (x, z) entlang.
func sweep(outline: PackedVector2Array, profile: PackedVector2Array, material: Material,
		closed := true, side := 0.0, mod := Callable()) -> void:
	var n := outline.size()
	var nrm := normals(outline, closed, side)
	var rings: Array[PackedVector3Array] = []
	for i in n:
		var scale := Vector2.ONE
		if mod.is_valid():
			scale = mod.call(outline[i])
		var loop := PackedVector3Array()
		for p in profile:
			var q := outline[i] + nrm[i] * p.x * scale.x
			loop.append(Vector3(q.x, p.y * (scale.y if p.y > 0.0 else 1.0), q.y))
		rings.append(loop)
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

func cyl(radius: float, height: float, pos: Vector3, material: Material, bottom := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius if bottom < 0.0 else bottom
	mesh.height = height
	mesh.radial_segments = 40
	var node := _add(mesh, material)
	node.position = pos
	return node

func bar(a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var node := cyl(radius, a.distance_to(b), (a + b) * 0.5, material)
	(node.mesh as CylinderMesh).radial_segments = 16
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	node.basis = Basis(x, y, x.cross(y))

func circle(cx: float, cz: float, r: float, n := 40) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(Vector2(cx + cos(a) * r, cz + sin(a) * r))
	return out

func rounded_rect(cx: float, cz: float, hx: float, hz: float, r: float, seg := 12) -> PackedVector2Array:
	var out := PackedVector2Array()
	var corners := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for c in 4:
		var mid := Vector2(cx + corners[c].x * (hx - r), cz + corners[c].y * (hz - r))
		for i in seg + 1:
			var a := PI * 0.5 * (c + float(i) / seg)
			var p := mid + Vector2(cos(a), sin(a)) * r
			if out.is_empty() or (out[-1].distance_to(p) > 0.01 and out[0].distance_to(p) > 0.01):
				out.append(p)
	return out

func pts(list: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, list.size(), 2):
		out.append(Vector2(list[i], list[i + 1]))
	return out

## Gedruckter Ring auf dem Deck.
func ring(cx: float, cz: float, r: float, width: float, material: Material, y := 0.09) -> void:
	sweep(circle(cx, cz, r, 48), pts([0, y, width, y]), material)

## Schrift flach auf dem Deck (liest vom Spieler aus) oder stehend zur Spielerseite.
func label(text: String, pos: Vector3, height: float, color: Color, standing := false) -> void:
	var node := Label3D.new()
	node.text = text
	node.font_size = 96
	node.pixel_size = height / 68.0
	node.modulate = color
	node.outline_size = 0
	node.double_sided = true
	holder.add_child(node)
	node.position = pos
	if standing:
		node.basis = Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	else:
		node.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))

## Chip-Rollen liegend in einer Rinne: ab start längs dir, je Rolle eine Farbe.
func chip_rolls(start: Vector3, dir: Vector3, count: int, radius := 1.0) -> void:
	for k in count:
		var a := start + dir * (k * 3.9)
		bar(a, a + dir * 3.6, radius, mat(CHIP_COLORS[k % CHIP_COLORS.size()], 0.0, 0.4))

func leg(pos: Vector2, top_y: float, size: float, material: Material) -> void:
	var h := top_y - FLOOR_Y
	box(Vector3(size, h, size), Vector3(pos.x, FLOOR_Y + h * 0.5, pos.y), material)
	box(Vector3(size + 1.2, 1.6, size + 1.2), Vector3(pos.x, FLOOR_Y + 0.8, pos.y), gold())

# --- Inhalt messen, Anzeige beschneiden ------------------------------------------------

## Was auf der Anzeige wirklich belegt ist, in Welt (x, z): Fenster, Körper, Wurfplatz.
func _measure_content() -> void:
	var px := Rect2()
	for node in (game.get("table_screen") as Node).get_children():
		if node is Control and (node as Control).visible and node.name != "DebugParts":
			var r := (node as Control).get_global_rect()
			if r.size.x > 4500.0 or r.size.x < 2.0:
				continue
			px = r if px.size == Vector2.ZERO else px.merge(r)
			if node.name == "PitWindow":
				pit_z = Z0 + r.get_center().x / 37.5
	px = px.merge(Rect2(4822, 1994, 112, 92))
	content = Rect2(X1 - px.end.y / 37.5, Z0 + px.position.x / 37.5, px.size.y / 37.5, px.size.x / 37.5)
	var display := Rect2(X0, Z0, X1 - X0, Z1 - Z0)
	for node in game.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if not m.is_visible_in_tree() or str(m.get_path()).contains("/Room/"):
			continue
		var b := m.global_transform * m.get_aabb()
		var r := Rect2(b.position.x, b.position.z, b.size.x, b.size.z)
		if b.end.y < -0.5 or b.position.y > 12.0 or r.size.length() > 90.0 or not display.encloses(r):
			continue
		if not content.encloses(r):
			print("Körper außerhalb der Fenster: ", m.get_path(), " ", r)
		content = content.merge(r)
	print("Inhalt (x, z): ", content, " Grube z ", pit_z)

## Die Anzeige endet für die Probe unter der Wand (im Spiel wäre sie so zugeschnitten).
func _crop_display(center: Vector2, half: Vector2, radius: float) -> void:
	var mesh := game.get_node("Room").find_child("Screen", true, false) as MeshInstance3D
	var m := mesh.material_override as ShaderMaterial
	if crop_shader == null:
		crop_shader = Shader.new()
		crop_shader.code = m.shader.code.replace("void fragment() {", """uniform vec4 probe_box;
uniform float probe_radius;
varying vec3 probe_world;
void vertex() { probe_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 probe_q = abs(probe_world.xz - probe_box.xy) - probe_box.zw + probe_radius;
	if (length(max(probe_q, 0.0)) + min(max(probe_q.x, probe_q.y), 0.0) - probe_radius > 0.0) { discard; }
""")
		m.shader = crop_shader
	m.set_shader_parameter("probe_box", Vector4(center.x, center.y, half.x, half.y))
	m.set_shader_parameter("probe_radius", radius)

# --- Die CRAPS-WANNE in drei Fassungen ---------------------------------------------------

func _build_craps(look: int) -> void:
	# Klassik: Nußbaum, schwarzes Leder, violette Pyramiden, Chip-Rollen.
	var apron := mat(WALNUT, 0.0, 0.6, 0.0, 4)
	var shelf := apron
	var leather := mat(LEATHER, 0.0, 0.35, 0.0, 2)
	var wall := mat(RUBBER, 0.0, 0.2, 0.0, 1)
	var lip := AMBER
	var under := VIOLET
	if look == 1:  # Noir: Klavierlack, Aubergine-Leder, Rauch-Pyramiden, Messingstange, Technik-Fenster.
		apron = mat(LACQUER, 0.0, 0.95)
		shelf = apron
		leather = mat(AUBERGINE, 0.0, 0.4, 0.0, 2)
		wall = mat(SMOKE, 0.0, 0.5, 0.0, 1)
	if look == 2:  # Lounge: Nachtblau-Lack, helles Leder, blaue Pyramiden, Licht in der Farbe der Grube.
		apron = mat(MIDNIGHT, 0.0, 0.95)
		shelf = mat(LACQUER, 0.0, 0.95)
		leather = mat(IVORY, 0.0, 0.3, 0.0, 2)
		wall = mat(NAVY_RUBBER, 0.0, 0.3, 0.0, 1)
		lip = TEAL
		under = TEAL
	var c := Vector2(content.get_center().x, pit_z)
	var half := Vector2(content.size.x * 0.5, maxf(content.end.y - pit_z, pit_z - content.position.y)) 		+ Vector2(MARGIN, MARGIN)
	var r := 9.0 + MARGIN
	_crop_display(c, half + Vector2(1.5, 1.5), r + 1.5)
	var inner := rounded_rect(c.x, c.y, half.x, half.y, r)
	deck(inner, mat(DECK, 9.0, 0.3))
	sweep(inner, pts([-1.5, 0.09, -2.0, 0.09]), gold())
	# Das freie Band links der Fenster: Signet oder Technik-Fenster.
	var free := content.position.y - (c.y - half.y) - MARGIN
	var mid := Vector2(c.x, content.position.y - MARGIN * 0.5 - free * 0.5)
	if look == 1:
		_tech_window(mid, Vector2(17.0, free * 0.5 - 1.5))
	else:
		var rad := minf(free * 0.5 - 1.0, 11.0)
		ring(mid.x, mid.y, rad, 0.5, gold())
		ring(mid.x, mid.y, rad - 2.2, 0.2, gold())
		label("FUMBLE", Vector3(mid.x, 0.1, mid.y), rad * 0.26, GOLD)
	# Spielerseite abgesenkt, damit die Wand keine Station verdeckt.
	var low := func(p: Vector2) -> Vector2:
		return Vector2(1.0, lerpf(0.5, 1.0, smoothstep(c.x - half.x * 0.67, c.x + half.x * 0.55, p.x)))
	sweep(inner, pts([0, 0, 0.3, 2.0]), mat(LACQUER, 0.0, 0.9), true, 0.0, low)
	sweep(inner, pts([0.3, 2.0, 1.6, 8.6]), wall, true, 0.0, low)
	sweep(inner, pts([1.6, 8.6, 1.2, 8.9, 1.2, 9.3]), light(lip), true, 0.0, low)
	sweep(inner, pts([1.2, 9.3, 1.2, 9.9, 5.6, 9.9]), shelf, true, 0.0, low)
	sweep(inner, pts([5.6, 9.9, 6.1, 11.5, 8.0, 12.2, 12.2, 12.2, 14.1, 11.3, 14.7, 9.4]), leather,
		true, 0.0, low)
	sweep(inner, pts([14.7, 9.4, 15.1, 9.0, 14.7, 8.6]), gold(), true, 0.0, low)
	sweep(inner, pts([14.7, 8.6, 14.2, -9.0]), apron, true, 0.0, low)
	sweep(inner, pts([14.2, -9.0, 14.5, -10.0, 14.0, -11.0]), gold())
	sweep(inner, pts([14.0, -11.0, 2.0, -12.0]), mat(DARK))
	sweep(inner, pts([13.6, -11.2, 12.4, -11.6]), light(under))
	var span := half.y - r
	var x := c.x + half.x + 3.4
	if look == 0:
		var rolls := int(span * 2.0 / 3.9)
		chip_rolls(Vector3(x, 10.9, c.y - rolls * 1.95), Vector3(0, 0, 1), rolls)
	elif look == 1:
		bar(Vector3(x, 10.7, c.y - span), Vector3(x, 10.7, c.y + span), 0.45, gold())
		for k in 7:
			var z := c.y - span + span * 2.0 * k / 6.0
			bar(Vector3(x, 9.9, z), Vector3(x, 10.7, z), 0.3, gold())
	else:
		box(Vector3(1.6, 0.25, span * 2.0), Vector3(x, 10.0, c.y), light(TEAL))
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			leg(c + Vector2(sx * (half.x - 14.0), sz * (half.y - 18.0)), -11.0, 13.0, apron)

## Technik als Akzent: ein gefaßtes Sichtfenster ins Innenleben des Tischs.
func _tech_window(mid: Vector2, half: Vector2) -> void:
	var frame := rounded_rect(mid.x, mid.y, half.x, half.y, 2.0, 5)
	sweep(frame, pts([0, 0.05, 0, 0.5, 1.0, 0.5, 1.0, 0.05]), gold())
	plate(frame, 0.07, mat(Color(0.015, 0.05, 0.045), 1.3, 0.5))
	box(Vector3(6.0, 0.5, 6.0), Vector3(mid.x + 4.0, 0.3, mid.y), mat(LACQUER, 0.0, 0.8))
	box(Vector3(6.6, 0.1, 6.6), Vector3(mid.x + 4.0, 0.1, mid.y), gold())
	box(Vector3(3.0, 0.4, 4.5), Vector3(mid.x - 6.0, 0.25, mid.y - half.y * 0.4), mat(LACQUER, 0.0, 0.8))
	for k in 6:
		cyl(0.6, 1.0, Vector3(mid.x - 12.0, 0.55, mid.y - half.y * 0.6 + k * 1.9), mat(Color(0.4, 0.43, 0.48), 0.0, 0.7))
	for k in 3:
		var z := mid.y + half.y * 0.35 + k * 1.3
		bar(Vector3(mid.x - half.x + 2.0, 0.5, z), Vector3(mid.x + half.x - 2.0, 0.5, z), 0.4,
			mat(Color(0.62, 0.64, 0.68), 0.0, 0.8))
	for k in 12:
		box(Vector3(0.35, 0.9, 5.0), Vector3(mid.x + 10.0 + k * 0.55, 0.5, mid.y - half.y * 0.45),
			mat(Color(0.62, 0.64, 0.68), 0.0, 0.6))
