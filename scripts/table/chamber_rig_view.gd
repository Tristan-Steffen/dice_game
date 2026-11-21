class_name ChamberRigView
extends Node3D
## Das GERÜST der KAMMER: ein Rahmenwürfel in den Proportionen des Würfels (FRAME_SCALE),
## fest in der Grube, um den Platz des Würfels - ein Tesserakt. Beim Prägen fährt aus
## jeder seiner acht Ecken eine STREBE schräg an die Würfelecke und greift sie; auf jeder
## liegt ein FLACHBAND mit vier Spuren (Zahl, Material, Rune, Sonderbestand). Die Bänder
## kommen aus Verteilern an den Wänden über den Boden und an den Pfosten hoch. Die Spuren
## der Kanäle, die die Serie braucht, leuchten mit dem Strom auf.
## Rein per Code gebaut; gefahren wird von scene_root, der Würfel steht derweil still.

const CH_NUMBER := "number"
const CH_MATERIAL := "material"
const CH_RUNE := "rune"
## Der Sonderbestand: Veredelung, Pointer-Kopie - und jede Pflege läuft über seine Spur.
const CH_SPECIAL := "special"
## Ein Prägen, das keine Seite ändert.
const CH_CARE := "care"
const CHANNELS: Array[String] = [CH_NUMBER, CH_MATERIAL, CH_RUNE, CH_SPECIAL]
const ALL_FACES := -1

## Der Rahmenwürfel: so groß wie der Würfel samt Kantenrahmen mal FRAME_SCALE.
const FRAME_SCALE := 1.5
## Pfosten (senkrecht, tragen die Bänder) und Riegel (waagerecht): Kantenlänge.
const POST := 0.3
const BAR := 0.16
const JOINT := 0.36
## Das Band: Spurbreite, Träger und Ader.
const LANE := 0.06
const CARRIER := 4.6
const STRAND := 0.72
## Die Strebe und wie weit der Greifer über die Würfelecke faßt.
const STRUT_W := 0.14
const STRUT_H := 0.09
const GRIP_PAD := 0.3
const GRIP_INSET := 0.15
## Verteiler: Abstand von der Wand.
const MANIFOLD_INSET := 0.3
const GUNMETAL := Color(0.27, 0.3, 0.38)
const DARK := Color(0.05, 0.05, 0.065)
const STEEL := Color(0.46, 0.49, 0.57)
const LIGHT := Color(0.45, 0.9, 1.0)
const LIGHT_GLOW := 0.7
## Der Maschinenboden: Platte, Rost-Stäbe (Teilung) und der LICHTRING unter dem Würfel.
const FLOOR := Color(0.07, 0.08, 0.11)
const GRATE := Color(0.2, 0.22, 0.29)
const GRATE_PITCH := 0.32
const RING_SHARE := 1.05
const RING_WIDE := 0.12
const RING_REST := 0.9
const RING_PULSE := 3.0
## Glühen einer Spur: in Ruhe, gelesen, beim Einschlag.
const REST_GLOW := 0.25
const TICK_GLOW := 1.3
const PULSE_GLOW := 2.4
const TICK_TIME := 0.22
const GRIP_TIME := 0.1

const PART_SHADER: Shader = preload("res://assets/shaders/chamber_socket.gdshader")

static var _box: BoxMesh
static var _skins := {}

var _center := Vector3.ZERO
var _half := Vector2.ONE
var _depth := 1.0
var _drop := 0.5
var _reach := 1.0
var _frame: Node3D
var _arms: Node3D
var _struts: Array[Node3D] = []
var _grips: Array[Node3D] = []
var _ends: Array = []
## Je Kanal EIN Material: jede Ader dieser Sorte glüht mit ihm.
var _lanes: Array[ShaderMaterial] = []
var _ring: ShaderMaterial
var _active: Array[int] = []
var _tween: Tween
var _docked := false

## Welche Kanäle eine Serie braucht: je geänderter Seite und Kanal ein Eintrag
## {face, channel}. Ändert sie keine Seite, aber pflegt (tended), ein CH_CARE-Eintrag.
static func cable_plan(projection: Dictionary, tended := false) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var bonus: Array = projection.get("bonus", [])
	var materials: Array = projection.get("materials", [])
	var doped: Array = projection.get("doped", [])
	var runes: Array = projection.get("runes", [])
	var copied: Array[int] = []
	for copy: Dictionary in projection.get("copies", []):
		copied.append(int(copy.get("to", -1)))
	for face in StampNet.FACES:
		if face < bonus.size() and int(bonus[face]) != 0:
			plan.append({"face": face, "channel": CH_NUMBER})
		if face < materials.size() and String(materials[face]) != "":
			plan.append({"face": face, "channel": CH_MATERIAL})
		if face < runes.size() and not Array(runes[face]).is_empty():
			plan.append({"face": face, "channel": CH_RUNE})
		if (face < doped.size() and bool(doped[face])) or copied.has(face):
			plan.append({"face": face, "channel": CH_SPECIAL})
	if plan.is_empty() and tended:
		plan.append({"face": ALL_FACES, "channel": CH_CARE})
	return plan

## Die Spuren (Rang in CHANNELS), die ein Plan zum Leuchten bringt - Pflege die Sonder-Spur.
static func plan_channels(plan: Array[Dictionary]) -> Array[int]:
	var ranks: Array[int] = []
	for entry in plan:
		var channel := String(entry["channel"])
		var rank := CHANNELS.find(CH_SPECIAL if channel == CH_CARE else channel)
		if rank >= 0 and not ranks.has(rank):
			ranks.append(rank)
	ranks.sort()
	return ranks

static func channel_tint(channel: String) -> Color:
	match channel:
		CH_MATERIAL:
			return PackDrawerView.COLORS[Engraving.CATEGORY_MATERIAL]
		CH_RUNE:
			return PackDrawerView.COLORS[Engraving.CATEGORY_DICE]
		CH_SPECIAL:
			return PackDrawerView.COLORS[Pack.SHELF_SPECIAL]
	return PackDrawerView.COLORS[Engraving.CATEGORY_NUMBER]

## Die Ecke des Gerüsts zu einer Würfelecke: dieselbe Ecke. offset = Ecke minus Würfelmitte.
static func station_of(offset: Vector3) -> Vector3:
	return Vector3(-1.0 if offset.x < 0.0 else 1.0, -1.0 if offset.y < 0.0 else 1.0,
		-1.0 if offset.z < 0.0 else 1.0)

## Wie weit die Außenkante eines Würfels der halben Kante half_edge reicht (samt Rahmen).
static func die_reach(half_edge: float) -> float:
	return half_edge * (1.0 + DieBuilder.EDGE_THICKNESS * 0.5 / DieBuilder.HALF_EXTENT)

## Die Kammer in Welt: Mitte auf Tischhöhe, halbe Spanne (Welt-X, Welt-Z), Tiefe; der
## Würfel steht drop unter dem Tisch und hat die halbe Kante half_edge. Dieselben Maße
## bauen nichts neu.
func setup(center: Vector3, half: Vector2, depth: float, drop: float, half_edge: float) -> void:
	var reach := die_reach(half_edge)
	var same := _frame != null and is_instance_valid(_frame) and center.is_equal_approx(_center) \
		and half.is_equal_approx(_half) and is_equal_approx(depth, _depth) \
		and is_equal_approx(drop, _drop) and is_equal_approx(reach, _reach)
	_center = center
	_half = half
	_depth = depth
	_drop = drop
	_reach = reach
	if not same:
		settle_hard()
		_build_frame()

## Die Mitte des Würfelplatzes und die halbe Kante des Rahmenwürfels.
func die_center() -> Vector3:
	return _center + Vector3.DOWN * _drop

func frame_half() -> float:
	return _reach * FRAME_SCALE

## Die Ecke des Rahmenwürfels: sign = (±1, ±1, ±1).
func frame_corner(sign: Vector3) -> Vector3:
	return die_center() + sign * frame_half()

## Wo der Greifer einer Würfelecke sitzt.
func grip_point(at: Vector3, basis: Basis, corner: Vector3) -> Vector3:
	return at + basis * (corner * _reach)

func _build_frame() -> void:
	if _frame != null and is_instance_valid(_frame):
		_frame.queue_free()
	if _box == null:
		_box = BoxMesh.new()
	if _lanes.is_empty():
		for channel in CHANNELS:
			var tint := channel_tint(channel)
			var material := ShaderMaterial.new()
			material.shader = PART_SHADER
			material.set_shader_parameter("base", Vector3(tint.r, tint.g, tint.b))
			material.set_shader_parameter("metal", 0.0)
			material.set_shader_parameter("glow", REST_GLOW)
			_lanes.append(material)
	_frame = Node3D.new()
	_frame.name = "Geruest"
	add_child(_frame)
	var c := die_center()
	var r := frame_half()
	var floor_y := _center.y - _depth
	var gun := _skin(GUNMETAL, 0.15, 0.0)
	var steel := _skin(STEEL, 0.25, 0.0)
	var lit := _skin(LIGHT, 0.0, LIGHT_GLOW)
	for a: float in [-1.0, 1.0]:
		for b: float in [-1.0, 1.0]:
			# Zwölf Kanten: vier Pfosten bis auf den Boden, acht Riegel.
			var top := c.y + r
			_part(_frame, gun, Vector3(c.x + a * r, (top + floor_y) * 0.5, c.z + b * r),
				Vector3(POST, top - floor_y, POST))
			_part(_frame, steel, Vector3(c.x + a * r, floor_y + 0.04, c.z + b * r),
				Vector3(POST + 0.2, 0.08, POST + 0.2))
			_part(_frame, gun, c + Vector3(0, a * r, b * r), Vector3(r * 2.0 - POST, BAR, BAR))
			_part(_frame, gun, c + Vector3(b * r, a * r, 0), Vector3(BAR, BAR, r * 2.0 - POST))
			if a > 0.0:
				_part(_frame, lit, c + Vector3(0, r + BAR * 0.5, b * r), Vector3(r * 1.5, 0.03, 0.05))
				_part(_frame, lit, c + Vector3(b * r, r + BAR * 0.5, 0), Vector3(0.05, 0.03, r * 1.5))
			for up: float in [-1.0, 1.0]:
				_part(_frame, steel, c + Vector3(a * r, up * r, b * r), Vector3.ONE * JOINT)
	_build_floor(floor_y)
	var run_y := floor_y + 0.04
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			# Zwei Bänder je Pfosten: auf der einen Außenseite zur oberen Ecke, auf der
			# anderen zur unteren.
			var wall_z := Vector3(c.x + sx * r, floor_y + 0.12, _center.z + sz * (_half.y - MANIFOLD_INSET))
			_build_manifold(wall_z, Vector3(0, 0, -sz))
			var foot_z := Vector3(c.x + sx * r, run_y, c.z + sz * (r + POST * 0.5 + 0.01))
			_ribbon(_frame, [Vector3(wall_z.x, run_y, wall_z.z - sz * 0.2), foot_z,
				Vector3(foot_z.x, c.y + r, foot_z.z)], [Vector3.UP, Vector3(0, 0, sz)])
			var wall_x := Vector3(_center.x + sx * (_half.x - MANIFOLD_INSET), floor_y + 0.12, c.z + sz * r)
			_build_manifold(wall_x, Vector3(-sx, 0, 0))
			var foot_x := Vector3(c.x + sx * (r + POST * 0.5 + 0.01), run_y, c.z + sz * r)
			_ribbon(_frame, [Vector3(wall_x.x - sx * 0.2, run_y, wall_x.z), foot_x,
				Vector3(foot_x.x, c.y - r, foot_x.z)], [Vector3.UP, Vector3(sx, 0, 0)])

## Der MASCHINENBODEN: dunkle Platte, Rost quer, und der Lichtring unter dem Würfel.
func _build_floor(floor_y: float) -> void:
	_part(_frame, _skin(FLOOR, 0.0, 0.0), Vector3(_center.x, floor_y - 0.05, _center.z),
		Vector3(_half.x * 2.0, 0.1, _half.y * 2.0))
	var bar := _skin(GRATE, 0.1, 0.0)
	var z := -_half.y + GRATE_PITCH * 0.5
	while z < _half.y:
		_part(_frame, bar, Vector3(_center.x, floor_y + 0.012, _center.z + z),
			Vector3(_half.x * 2.0, 0.024, 0.05))
		z += GRATE_PITCH
	if _ring == null:
		_ring = ShaderMaterial.new()
		_ring.shader = PART_SHADER
		_ring.set_shader_parameter("base", Vector3(LIGHT.r, LIGHT.g, LIGHT.b))
		_ring.set_shader_parameter("metal", 0.0)
		_ring.set_shader_parameter("glow", RING_REST)
	var torus := TorusMesh.new()
	torus.outer_radius = frame_half() * RING_SHARE
	torus.inner_radius = torus.outer_radius - RING_WIDE
	var ring := MeshInstance3D.new()
	ring.name = "Lichtring"
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.25, 1.0)
	ring.position = Vector3(die_center().x, floor_y + 0.04, die_center().z)
	ring.material_override = _ring
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_frame.add_child(ring)

## Der VERTEILER an der Wand: ein Block mit vier Ports in den Sortenfarben.
func _build_manifold(at: Vector3, face: Vector3) -> void:
	var basis := _aim(at, at + face, Vector3.UP)
	_part(_frame, _skin(GUNMETAL, 0.15, 0.0), at, Vector3(0.5, 0.22, 0.34), basis)
	_part(_frame, _skin(STEEL, 0.25, 0.0), at + basis.z * 0.17 + basis.y * 0.1, Vector3(0.54, 0.06, 0.06), basis)
	for rank in CHANNELS.size():
		_part(_frame, _lanes[rank], at + basis.x * (float(rank) - 1.5) * 0.11 + basis.z * 0.18,
			Vector3(0.07, 0.07, 0.03), basis)

## Ein gefaltetes FLACHBAND: gerade Stücke, je Stück ein dunkler Träger und vier Adern.
func _ribbon(parent: Node3D, points: Array, normals: Array) -> void:
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var basis := _aim(a, b, normals[i])
		_strip(parent, (a + b) * 0.5, basis, a.distance_to(b) + LANE * 2.0)

func _strip(parent: Node3D, mid: Vector3, basis: Basis, length: float) -> void:
	_part(parent, _skin(DARK, 0.0, 0.0), mid + basis.y * 0.01, Vector3(LANE * CARRIER, 0.02, length), basis)
	for rank in CHANNELS.size():
		_part(parent, _lanes[rank], mid + basis.x * (float(rank) - 1.5) * LANE + basis.y * 0.026,
			Vector3(LANE * STRAND, 0.014, length), basis)

## Die Streben fahren aus und greifen die acht Ecken. Endzustand zuerst: sie STEHEN am
## Würfel, das Ausfahren ist nur der Weg dorthin. lead = so lange richtet er sich erst.
func dock(at: Vector3, die_basis: Basis, plan: Array[Dictionary], time: float, lead := 0.0) -> void:
	settle_hard()
	if _frame == null or not is_instance_valid(_frame):
		return
	var basis := die_basis.orthonormalized()
	_active = plan_channels(plan)
	_arms = Node3D.new()
	_arms.name = "Streben"
	add_child(_arms)
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				_build_arm(at, basis, Vector3(x, y, z))
	_docked = true
	if time <= 0.0 or not is_inside_tree():
		return
	_tween = create_tween().set_parallel(true)
	for strut in _struts:
		strut.scale = Vector3(1.0, 1.0, 0.02)
		_tween.tween_property(strut, "scale", Vector3.ONE, time).set_delay(lead) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for grip in _grips:
		var full := grip.scale
		grip.scale = Vector3.ONE * 0.001
		_tween.tween_property(grip, "scale", full, GRIP_TIME).set_delay(lead + time * 0.9) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## EINE Strebe: von der Gerüst-Ecke schräg an die Würfelecke, das Band obenauf, am Ende
## der Greifer mit drei Backen auf den drei Flächen der Ecke.
func _build_arm(at: Vector3, basis: Basis, corner: Vector3) -> void:
	var outer := frame_corner(station_of(basis * corner))
	var inner := grip_point(at, basis, corner)
	var length := outer.distance_to(inner)
	var strut := Node3D.new()
	strut.name = "Strebe"
	_arms.add_child(strut)
	strut.transform = Transform3D(_aim(outer, inner, Vector3.UP), outer)
	_part(strut, _skin(GUNMETAL, 0.15, 0.0), Vector3(0, 0, length * 0.5), Vector3(STRUT_W, STRUT_H, length))
	var band := length - JOINT * 0.5
	_strip(strut, Vector3(0, STRUT_H * 0.5 + 0.005, JOINT * 0.5 + band * 0.5), Basis.IDENTITY, band)
	_struts.append(strut)
	var grip := Node3D.new()
	grip.name = "Greifer"
	_arms.add_child(grip)
	grip.transform = Transform3D(basis, inner)
	var steel := _skin(STEEL, 0.25, 0.0)
	for axis in 3:
		var size := Vector3.ONE * GRIP_PAD
		size[axis] = 0.05
		var seat := -corner * GRIP_INSET
		seat[axis] = corner[axis] * 0.03
		_part(grip, steel, seat, size)
	_part(grip, _skin(GUNMETAL, 0.15, 0.0), corner * 0.04, Vector3.ONE * 0.13)
	_grips.append(grip)
	_ends.append([outer, inner])

## Der Strom liest eine Karte: die Spuren der Serie glimmen kurz auf.
func tick() -> void:
	if not _docked or not is_inside_tree():
		return
	var blip := create_tween().set_parallel(true)
	for rank in _active:
		blip.tween_property(_lanes[rank], "shader_parameter/glow", REST_GLOW, TICK_TIME).from(TICK_GLOW)

## DER EINSCHLAG: die Spuren der Serie laufen hell an.
func pulse(time: float) -> void:
	if not _docked or not is_inside_tree():
		return
	_kill()
	_show_docked()
	_tween = create_tween().set_parallel(true)
	for rank in _active:
		_tween.tween_property(_lanes[rank], "shader_parameter/glow", PULSE_GLOW, maxf(time, 0.01)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _ring != null:
		_tween.tween_property(_ring, "shader_parameter/glow", RING_PULSE, maxf(time, 0.01)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Die Greifer lösen sich, die Streben fahren ins Gerüst zurück.
func release(time: float) -> void:
	if _arms == null or not is_instance_valid(_arms):
		return
	_kill()
	_docked = false
	if time <= 0.0 or not is_inside_tree():
		_clear()
		return
	for grip in _grips:
		grip.visible = false
	_tween = create_tween().set_parallel(true)
	for strut in _struts:
		_tween.tween_property(strut, "scale", Vector3(1.0, 1.0, 0.02), time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for material in _lanes:
		_tween.tween_property(material, "shader_parameter/glow", REST_GLOW, time)
	if _ring != null:
		_tween.tween_property(_ring, "shader_parameter/glow", RING_REST, time)
	_tween.chain().tween_callback(_clear)

## Der EINE harte Aufräum-Pfad: keine Strebe steht mehr, jede Spur ruht.
func settle_hard() -> void:
	_kill()
	_clear()

func docked() -> bool:
	return _docked

## Die ausgefahrenen Streben.
func arm_count() -> int:
	return _struts.size()

## Gerüst-Ecke und Würfelecke der Strebe index in Welt - für Tests und Proben.
func arm_ends(index: int) -> Array:
	return _ends[index]

## Die Spuren, die die laufende Serie leuchten läßt.
func active_channels() -> Array[int]:
	return _active

func ring_glow() -> float:
	return float(_ring.get_shader_parameter("glow")) if _ring != null else 0.0

func lane_glow(rank: int) -> float:
	return float(_lanes[rank].get_shader_parameter("glow")) if rank < _lanes.size() else 0.0

func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

func _clear() -> void:
	_docked = false
	if _arms != null and is_instance_valid(_arms):
		_arms.queue_free()
	_arms = null
	_struts.clear()
	_grips.clear()
	_ends.clear()
	_active = []
	for material in _lanes:
		material.set_shader_parameter("glow", REST_GLOW)
	if _ring != null:
		_ring.set_shader_parameter("glow", RING_REST)

func _show_docked() -> void:
	for strut in _struts:
		strut.scale = Vector3.ONE
	for grip in _grips:
		grip.scale = Vector3.ONE

## Ein Quader-Bauteil: sein Licht rechnet der Shader selbst (in der Grube ist keines).
func _part(parent: Node3D, material: Material, at: Vector3, size: Vector3,
		basis := Basis.IDENTITY) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = _box
	part.transform = Transform3D(basis * Basis.from_scale(size), at)
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part

## Die Lage eines Stücks von a nach b (lokal +Z), dessen Oberseite nach normal schaut.
static func _aim(a: Vector3, b: Vector3, normal: Vector3) -> Basis:
	var z := (b - a).normalized()
	var x := normal.cross(z)
	x = (Vector3.RIGHT.cross(z) if x.length() < 0.01 else x).normalized()
	return Basis(x, z.cross(x), z)

## Je Farbe und Glanz EIN geteiltes Material.
static func _skin(color: Color, metal: float, glow: float) -> ShaderMaterial:
	var key := "%s|%.2f|%.2f" % [color.to_html(false), metal, glow]
	if not _skins.has(key):
		var material := ShaderMaterial.new()
		material.shader = PART_SHADER
		material.set_shader_parameter("base", Vector3(color.r, color.g, color.b))
		material.set_shader_parameter("metal", metal)
		material.set_shader_parameter("glow", glow)
		_skins[key] = material
	return _skins[key]
