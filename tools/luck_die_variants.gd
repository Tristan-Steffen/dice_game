extends RefCounted
## Fünf Entwürfe des Glückswürfels zur Auswahl (Probe - der Gewinner zieht in LuckDieView).

const NAMES := ["1 Juwel", "2 Onyx", "3 Käfig", "4 Perlmutt", "5 Orbit",
	"6 Onyx Neon", "7 Goldrahmen", "8 Guilloché", "9 Lichtfuge", "10 Art déco"]

const SHADER := """shader_type spatial;
render_mode unshaded, cull_back%s;
uniform vec3 base : source_color = vec3(0.86, 0.63, 0.2);
uniform vec3 rim : source_color = vec3(1.0, 0.85, 0.5);
uniform float metal = 1.0;
uniform float gloss = 1.0;
uniform float irid = 0.0;
uniform float glow = 0.0;
uniform float brush = 0.0;
uniform float guilloche = 0.0;
uniform float alpha = 1.0;
varying vec3 wn;
varying vec3 wp;
varying vec3 lp;
varying vec3 ln;
void vertex() {
	ln = NORMAL;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lp = VERTEX;
}
void fragment() {
	vec3 n = normalize(wn);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	vec3 r = reflect(-v, n);
	float top = smoothstep(0.35, 0.95, r.y);
	float az = atan(r.z, r.x);
	float strip = smoothstep(0.86, 0.99, sin(az * 2.0 + r.y * 2.5 + TIME * 0.35) * 0.5 + 0.5)
		* smoothstep(-0.3, 0.4, r.y);
	float horizon = pow(1.0 - abs(r.y), 4.0);
	vec3 env = vec3(1.0, 0.96, 0.88) * top * 0.75 + vec3(1.0) * strip * 1.1
		+ vec3(0.95, 0.6, 0.3) * horizon * 0.22;
	float ndv = max(dot(n, v), 0.0);
	float fres = pow(1.0 - ndv, 4.0);
	float lam = max(dot(n, normalize(vec3(0.45, 0.8, -0.35))), 0.0);
	float hair = 1.0 - brush * 0.18 * (sin(lp.x * 90.0 + lp.z * 37.0) * 0.5 + 0.5);
	vec3 diffuse = base * (0.28 + 0.6 * lam);
	vec3 metal_col = base * (0.2 + 0.35 * lam) + env * base * 1.25;
	vec3 gloss_col = diffuse + (env - vec3(1.0, 0.96, 0.88) * top * 0.5) * gloss * (0.1 + 0.9 * fres);
	vec3 c = mix(gloss_col, metal_col, metal) * hair + rim * fres * 0.45;
	vec3 film = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + ndv * 1.3 + r.y * 0.4 + TIME * 0.05));
	c = mix(c, c * 0.8 + mix(vec3(0.75, 0.7, 0.65), film, 0.55) * 0.32, irid * (0.35 + 0.65 * (1.0 - ndv)));
	vec3 an = abs(ln);
	vec2 fuv = an.x > an.y && an.x > an.z ? lp.yz : (an.y > an.z ? lp.xz : lp.xy);
	float flat_share = smoothstep(0.9, 0.99, max(an.x, max(an.y, an.z)));
	float rays = sin(atan(fuv.y, fuv.x) * 40.0 + length(fuv) * 14.0) * 0.5 + 0.5;
	c *= 1.0 - guilloche * flat_share * 0.38 * rays;
	c += base * glow;
	ALBEDO = min(c, vec3(0.94));
	%s
}
"""

static var _opaque: Shader
static var _clear: Shader

static func material(base: Color, metal := 1.0, gloss := 1.0, see_through := -1.0) -> ShaderMaterial:
	if _opaque == null:
		_opaque = Shader.new()
		_opaque.code = SHADER % ["", ""]
		_clear = Shader.new()
		_clear.code = SHADER % [", blend_mix, depth_draw_never",
			"ALPHA = clamp(alpha + fres * 0.7 + strip * 0.5, 0.0, 1.0);"]
	var m := ShaderMaterial.new()
	m.shader = _clear if see_through >= 0.0 else _opaque
	m.set_shader_parameter("base", base)
	m.set_shader_parameter("metal", metal)
	m.set_shader_parameter("gloss", gloss)
	if see_through >= 0.0:
		m.set_shader_parameter("alpha", see_through)
	return m

## Ein Würfel mit runden Kanten (halbe Kante half, Radius radius), glatt schattiert.
static func rounded_box(half: float, radius: float, steps := 10) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := half - radius
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			for i in steps:
				for j in steps:
					var quad: Array[Vector3] = []
					for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
						var a := (float(i + corner.x) / steps * 2.0 - 1.0) * half
						var b := (float(j + corner.y) / steps * 2.0 - 1.0) * half
						var p := Vector3.ZERO
						p[axis] = side * half
						p[(axis + 1) % 3] = a
						p[(axis + 2) % 3] = b
						quad.append(p)
					var order := [0, 2, 1, 0, 3, 2] if side > 0.0 else [0, 1, 2, 0, 2, 3]
					for k: int in order:
						var p := quad[k]
						var core := p.clamp(Vector3.ONE * -inner, Vector3.ONE * inner)
						var out := p - core
						var normal := out.normalized() if out.length() > 0.0001 else Vector3.ZERO
						if normal == Vector3.ZERO:
							normal[axis] = side
						st.set_normal(normal)
						st.add_vertex(core + normal * radius)
	return st.commit()

static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, at := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

## Die Augen aller Seiten: je Auge make.call() an seinem Platz (lokal +Y = aus der Seite).
static func _pips(body: Node3D, half: float, faces: Array, proud: float, make: Callable) -> void:
	for face in 6:
		var out := LuckDieView.face_up_basis(face, 0.0, 0.0).inverse()
		for at: Vector2 in LuckDie.pip_layout(int(faces[face])):
			var spot := at * 0.52 * half
			var pip := Node3D.new()
			pip.add_child(make.call())
			pip.transform = Transform3D(out, out * Vector3(spot.x, half + proud, spot.y))
			body.add_child(pip)

static func _stud(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	node.mesh = mesh
	node.scale = Vector3(1.0, height / radius, 1.0)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

static func _disc(radius: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.03
	mesh.radial_segments = 24
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

static func _ring(radius: float, thick: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thick
	mesh.outer_radius = radius + thick
	mesh.rings = 48
	mesh.ring_segments = 10
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

## Zwölf Kantenstäbe eines Würfels.
static func _edges(body: Node3D, half: float, thick: float, mat: Material) -> void:
	for axis in 3:
		for a: float in [-1.0, 1.0]:
			for b: float in [-1.0, 1.0]:
				var size := Vector3.ONE * thick
				size[axis] = half * 2.0 + thick
				var box := BoxMesh.new()
				box.size = size
				var at := Vector3.ZERO
				at[(axis + 1) % 3] = a * half
				at[(axis + 2) % 3] = b * half
				_mesh(body, box, mat, at)

static func _glow(color: Color, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy)
	return m

## Baut Entwurf style (0..4) mit halber Kante half; der Körper heißt "Body".
static func build(style: int, half: float, faces: Array) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var gold := Color(0.9, 0.66, 0.22)
	match style:
		0:
			# JUWEL: Bernstein-Kristall mit glühendem Kern, Augen als Goldnieten.
			var shell := material(Color(1.0, 0.62, 0.14), 0.0, 1.6, 0.42)
			shell.set_shader_parameter("rim", Color(1.0, 0.8, 0.4))
			shell.set_shader_parameter("glow", 0.5)
			_mesh(body, rounded_box(half, half * 0.16), shell)
			var core := _mesh(body, rounded_box(half * 0.42, half * 0.04, 2), _glow(Color(1.0, 0.72, 0.3), 0.92))
			core.name = "Core"
			core.rotation = Vector3(0.6, 0.78, 0.0)
			var stud := material(gold)
			_pips(body, half, faces, -0.02 * half, func() -> Node3D: return _stud(0.15 * half, 0.07 * half, stud))
		1:
			# ONYX: schwarzer Klavierlack, Goldkanten, leuchtende Gold-Augen.
			var lacquer := material(Color(0.03, 0.025, 0.04), 0.0, 2.6)
			lacquer.set_shader_parameter("rim", Color(0.9, 0.7, 0.35))
			_mesh(body, rounded_box(half, half * 0.08), lacquer)
			_edges(body, half * 0.955, half * 0.07, material(gold))
			var eye := _glow(Color(1.0, 0.78, 0.36), 0.93)
			var socket := material(gold)
			_pips(body, half, faces, 0.0, func() -> Node3D:
				var pip := Node3D.new()
				pip.add_child(_ring(0.17 * half, 0.025 * half, socket))
				pip.add_child(_disc(0.14 * half, eye))
				return pip)
		2:
			# KÄFIG: Goldrahmen, darin ein schwebender Lichtkern; Augen als Diamanten.
			var frame := material(gold)
			_edges(body, half * 0.93, half * 0.14, frame)
			for x: float in [-1.0, 1.0]:
				for y: float in [-1.0, 1.0]:
					for z: float in [-1.0, 1.0]:
						var knob := _stud(0.15 * half, 0.15 * half, frame)
						knob.position = Vector3(x, y, z) * half * 0.93
						body.add_child(knob)
			var pane := material(Color(0.25, 0.16, 0.05), 0.0, 1.2, 0.1)
			_mesh(body, rounded_box(half * 0.9, half * 0.02, 2), pane)
			var core := _mesh(body, SphereMesh.new(), _glow(Color(1.0, 0.8, 0.45), 0.93))
			core.name = "Core"
			core.scale = Vector3.ONE * half * 0.62
			var halo := _ring(half * 0.52, half * 0.03, frame)
			halo.name = "Halo"
			body.add_child(halo)
			var gem := material(Color(1.0, 0.96, 0.9), 0.0, 2.2)
			gem.set_shader_parameter("glow", 0.35)
			gem.set_shader_parameter("irid", 0.35)
			_pips(body, half, faces, -0.08 * half, func() -> Node3D:
				var node := MeshInstance3D.new()
				var mesh := SphereMesh.new()
				mesh.radius = 0.16 * half
				mesh.height = 0.2 * half
				mesh.radial_segments = 6
				mesh.rings = 2
				node.mesh = mesh
				node.material_override = gem
				return node)
		3:
			# PERLMUTT: weiche Perle mit Farbspiel, Augen als dunkle Juwelen in Goldfassung.
			var pearl := material(Color(1.0, 0.95, 0.88), 0.0, 1.3)
			pearl.set_shader_parameter("glow", 0.22)
			pearl.set_shader_parameter("irid", 1.0)
			pearl.set_shader_parameter("rim", Color(1.0, 0.8, 0.9))
			_mesh(body, rounded_box(half, half * 0.26, 14), pearl)
			var setting := material(gold)
			var jewel := material(Color(0.18, 0.03, 0.3), 0.0, 2.0)
			jewel.set_shader_parameter("glow", 0.5)
			_pips(body, half, faces, 0.0, func() -> Node3D:
				var pip := Node3D.new()
				pip.add_child(_ring(0.165 * half, 0.03 * half, setting))
				pip.add_child(_stud(0.14 * half, 0.06 * half, jewel))
				return pip)
		4:
			# ORBIT: gebürstetes Gold, Neon-Augen, zwei Ringe kreisen wie ein Gyroskop.
			var brushed := material(gold)
			brushed.set_shader_parameter("brush", 1.0)
			_mesh(body, rounded_box(half, half * 0.14), brushed)
			var neon := _glow(Color(0.35, 1.0, 0.85), 0.93)
			var cup := material(Color(0.03, 0.05, 0.05), 0.0, 0.6)
			_pips(body, half, faces, 0.0, func() -> Node3D:
				var pip := Node3D.new()
				pip.add_child(_disc(0.18 * half, cup))
				var light := _disc(0.12 * half, neon)
				light.position.y = 0.012 * half
				pip.add_child(light)
				return pip)
			var steel := material(Color(0.95, 0.8, 0.5))
			for i in 2:
				var ring := _ring(half * (1.95 + 0.16 * i), half * 0.03, steel)
				ring.name = "Orbit%d" % i
				root.add_child(ring)
		5:
			# ONYX NEON: Klavierlack und Goldkanten, die Augen in Neon-Mint.
			var lacquer := material(Color(0.03, 0.025, 0.04), 0.0, 2.6)
			lacquer.set_shader_parameter("rim", Color(0.4, 0.9, 0.8))
			_mesh(body, rounded_box(half, half * 0.08), lacquer)
			_edges(body, half * 0.955, half * 0.07, material(gold))
			var neon := _glow(Color(0.35, 1.0, 0.85), 0.93)
			var socket := material(gold)
			_pips(body, half, faces, 0.0, func() -> Node3D:
				var pip := Node3D.new()
				pip.add_child(_ring(0.17 * half, 0.025 * half, socket))
				pip.add_child(_disc(0.14 * half, neon))
				return pip)
		6:
			# GOLDRAHMEN: gebürstetes Gold, je Seite ein Feld aus schwarzem Lack, Gold-Augen.
			var brushed := material(gold)
			brushed.set_shader_parameter("brush", 1.0)
			_mesh(body, rounded_box(half, half * 0.12), brushed)
			var lacquer := material(Color(0.03, 0.025, 0.04), 0.0, 2.6)
			_panels(body, half, 0.76, lacquer)
			var eye := _glow(Color(1.0, 0.78, 0.36), 0.93)
			var socket := material(gold)
			_pips(body, half, faces, 0.02 * half, func() -> Node3D:
				var pip := Node3D.new()
				pip.add_child(_ring(0.16 * half, 0.022 * half, socket))
				pip.add_child(_disc(0.13 * half, eye))
				return pip)
		7:
			# GUILLOCHÉ: graviertes Gold mit polierter Fase, Augen als Smaragde in dunklen Fassungen.
			var engraved := material(gold)
			engraved.set_shader_parameter("guilloche", 1.0)
			_mesh(body, rounded_box(half, half * 0.16), engraved)
			var cup := material(Color(0.03, 0.03, 0.03), 0.0, 0.8)
			var emerald := material(Color(0.05, 0.75, 0.5), 0.0, 2.4)
			emerald.set_shader_parameter("glow", 0.55)
			_pips(body, half, faces, 0.0, func() -> Node3D:
				var pip := Node3D.new()
				pip.add_child(_disc(0.19 * half, cup))
				pip.add_child(_stud(0.14 * half, 0.07 * half, emerald))
				return pip)
		8:
			# LICHTFUGE: schwarzer Lack, an jeder Kante eine warme Lichtfuge, Gold-Ecken, Ring-Augen.
			var lacquer := material(Color(0.03, 0.025, 0.04), 0.0, 2.6)
			_mesh(body, rounded_box(half, half * 0.08), lacquer)
			_edges(body, half * 0.975, half * 0.035, _glow(Color(1.0, 0.72, 0.3), 0.93))
			_corners(body, half, 0.26, material(gold))
			var halo := _glow(Color(1.0, 0.8, 0.42), 0.93)
			_pips(body, half, faces, 0.0, func() -> Node3D:
				return _ring(0.14 * half, 0.035 * half, halo))
		_:
			# ART DÉCO: schwarzer Lack, Gold-Ecken, je Seite ein feiner Goldrahmen, Diamant-Augen.
			var lacquer := material(Color(0.03, 0.025, 0.04), 0.0, 2.6)
			_mesh(body, rounded_box(half, half * 0.1), lacquer)
			var gilt := material(gold)
			_corners(body, half, 0.3, gilt)
			_face_frames(body, half, 0.8, 0.03, gilt)
			var gem := material(Color(1.0, 0.97, 0.92), 0.0, 2.4)
			gem.set_shader_parameter("glow", 0.5)
			gem.set_shader_parameter("irid", 0.3)
			_pips(body, half, faces, 0.0, func() -> Node3D:
				var pip := Node3D.new()
				pip.add_child(_ring(0.165 * half, 0.025 * half, gilt))
				var stone := MeshInstance3D.new()
				var mesh := SphereMesh.new()
				mesh.radius = 0.135 * half
				mesh.height = 0.15 * half
				mesh.radial_segments = 8
				mesh.rings = 2
				stone.mesh = mesh
				stone.material_override = gem
				pip.add_child(stone)
				return pip)
	return root

## Je Seite ein flaches Feld (Anteil share der Kante), eine Spur über der Fläche.
static func _panels(body: Node3D, half: float, share: float, mat: Material) -> void:
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			var size := Vector3.ONE * half * 2.0 * share
			size[axis] = half * 0.02
			var at := Vector3.ZERO
			at[axis] = side * half
			_mesh(body, rounded_box_flat(size), mat, at)

static func rounded_box_flat(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box

## Acht Eckkappen (Kantenanteil share).
static func _corners(body: Node3D, half: float, share: float, mat: Material) -> void:
	var cap := half * share
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				_mesh(body, rounded_box(cap * 0.5, cap * 0.12, 3), mat,
					Vector3(x, y, z) * (half - cap * 0.5 + half * 0.025))

## Je Seite ein feiner Rahmen (Anteil share der Kante).
static func _face_frames(body: Node3D, half: float, share: float, thick: float, mat: Material) -> void:
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			for k in 2:
				var along := (axis + 1 + k) % 3
				var across := (axis + 2 - k) % 3
				for edge: float in [-1.0, 1.0]:
					var size := Vector3.ONE * half * thick
					size[along] = half * 2.0 * share + half * thick
					size[axis] = half * 0.03
					var box := BoxMesh.new()
					box.size = size
					var at := Vector3.ZERO
					at[axis] = side * half
					at[across] = edge * half * share
					_mesh(body, box, mat, at)

## Die Ruhe-Bewegung zur Zeit t: Schweben, langsames Drehen, je Entwurf sein Eigenes.
static func animate(root: Node3D, style: int, half: float, t: float, rest: Basis, rest_y: float) -> void:
	var body: Node3D = root.get_node("Body")
	body.basis = Basis(Vector3.UP, t * 0.5) * rest
	body.position.y = rest_y + half * (0.45 + 0.12 * sin(t * 1.6))
	var core := body.get_node_or_null("Core") as Node3D
	if core != null and style == 0:
		core.rotation = Vector3(0.6 + t * 0.9, 0.78 - t * 1.3, 0.0)
		core.scale = Vector3.ONE * (1.0 + 0.08 * sin(t * 2.4))
	if core != null and style == 2:
		core.scale = Vector3.ONE * half * (0.62 + 0.05 * sin(t * 2.4))
	var halo := body.get_node_or_null("Halo") as Node3D
	if halo != null:
		halo.rotation = Vector3(t * 1.1, t * 0.7, 0.4)
	for i in 2:
		var ring := root.get_node_or_null("Orbit%d" % i) as Node3D
		if ring != null:
			ring.position.y = body.position.y
			ring.rotation = Vector3(0.5 + t * (0.9 - 0.5 * i), t * (0.6 + 0.4 * i), 1.1 * i)
