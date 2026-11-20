class_name ChamberRigView
extends Node3D
## Die KABEL der KAMMER: beim Prägen fahren FLACHBÄNDER aus den Wänden und klemmen an
## die ECKEN der Seiten, die die Serie ändert - je KANAL (Zahl, Material, Rune,
## Sonderbestand) eines in der Sortenfarbe. Der Strom der Walze läuft durch sie in den Würfel.
## Jedes Band wohnt in einem festen AUSLASS (eine ZIF-Leiste): acht Stationen (die vier
## Kammerecken, oben und unten), je Station einer je Kanal - die Würfelecke unten links
## zieht aus der Kammerecke unten links. Eingefahren steht die Bandzunge sichtbar darin.
## Je Seiten-Ecke verflechten sich die Bänder zu EINEM Strang, laufen durch einen Sammler
## und enden als vierspuriges Kabel in EINEM Eckstecker auf dem Rahmen.
## Rein per Code gebaut; gefahren wird von scene_root, der Würfel steht derweil still.

const CH_NUMBER := "number"
const CH_MATERIAL := "material"
const CH_RUNE := "rune"
## Der Sonderbestand: Veredelung, Pointer-Kopie - und jede Pflege fährt aus seinem Auslass.
const CH_SPECIAL := "special"
## Pflege ohne Seite (Kühlen, Reparatur): alle acht Ecken.
const CH_CARE := "care"
const CHANNELS: Array[String] = [CH_NUMBER, CH_MATERIAL, CH_RUNE, CH_SPECIAL]
const ALL_FACES := -1

const SIDES := 6
## Das Flachband an der Wand: Breite und Dicke (halbe Maße).
const RIBBON_WIDE := 0.1
const RIBBON_FLAT := 0.018
const PROUD := 0.03
## Der AUSLASS: Breite längs der Wand, Höhe quer dazu.
const OUTLET_W := 0.8
const OUTLET_H := 0.44
## Je Station vier Auslässe: zwei auf jeder der beiden Wände ihrer Ecke, nah und fern.
const OUTLET_NEAR := 0.58
const OUTLET_FAR := 1.5
## Er schaut schräg nach oben - von oben gesehen läse er sonst nur als Strich.
const OUTLET_TILT := 0.9
## Die oberen Stationen liegen so tief unter dem Tisch, die unteren so hoch über dem Boden.
const STATION_TOP := 0.6
const STATION_FLOOR := 0.8
## Der STAMM: vier Spuren nebeneinander, so breit je Spur und so lang vor dem Stecker.
const LANE := 0.085
const TRUNK := 0.62
const TRUNK_SEGMENTS := 4
## Der ZOPF: auf dem letzten Stück vor dem Sammler kreuzen sich die Bänder.
const WEAVE_SEGMENTS := 30
const WEAVE_FROM := 0.42
const WEAVE_TURNS := 1.5
const BRAID := 0.13
## Anteil der Bandlänge (UV) bis zum Sammler.
const TRUNK_SHARE := 0.84
## Der ECKSTECKER: Schenkellänge und -breite, wie weit sein Schuh von der Ecke sitzt und
## wie weit er über der Seite steht - der Rahmen des Würfels ragt selbst vor.
const CLIP_ARM := 0.44
const CLIP_BAR := 0.11
const CLIP_INSET := 0.11
const CLIP_PROUD := 0.09
const GUNMETAL := Color(0.2, 0.22, 0.27)
const DARK := Color(0.07, 0.075, 0.09)
const STEEL := Color(0.55, 0.58, 0.66)
const GOLD := Color(0.85, 0.63, 0.24)
const IDLE_LANE := Color(0.1, 0.11, 0.14)
const SAG := 0.18
const STAGGER_SPAN := 0.18
const TICK_GLOW := 0.6
const REST_GLOW := 0.1
const TICK_TIME := 0.22

const SHADER: Shader = preload("res://assets/shaders/chamber_cable.gdshader")
const PART_SHADER: Shader = preload("res://assets/shaders/chamber_socket.gdshader")
const QUARTER := Vector3(0.0, PI * 0.25, 0.0)

static var _box: BoxMesh
static var _skins := {}

var _center := Vector3.ZERO
var _half := Vector2.ONE
var _depth := 1.0
## Erst die ausgezogenen Bänder (_live Stück), dahinter die dunklen Leerspuren der Stämme.
var _cables: Array[Dictionary] = []
var _live := 0
var _loom: Node3D
var _fittings: Array[Node3D] = []
var _ports_lit: Array[Node3D] = []
var _tween: Tween
var _docked := false
var _ports: Node3D
## Schlüssel "sx|up|sz|rank" -> die Bandzunge, die eingefahren im Auslass steht.
var _plugs := {}

## Welche Kabel eine Serie braucht: je geänderter Seite und Kanal ein Eintrag
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

## Wie viele Kabel der Plan ausfährt.
static func plan_cable_count(plan: Array[Dictionary]) -> int:
	var count := 0
	for entry in plan:
		count += 8 if int(entry["face"]) == ALL_FACES else 4
	return count

## Die Richtung einer Würfelseite im Rahmen des Würfels (ZERO = keine).
static func face_direction(face: int) -> Vector3:
	for axis: String in DiceController.AXIS_FACE_INDEX:
		if int(DiceController.AXIS_FACE_INDEX[axis]) == face:
			return DiceController.AXIS_DIRECTIONS[axis]
	return Vector3.ZERO

## Die vier Ecken einer Seite im Einheitswürfel (±1); ALL_FACES = alle acht.
static func face_corners(face: int) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	var dir := face_direction(face)
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				var corner := Vector3(x, y, z)
				if face == ALL_FACES or (dir != Vector3.ZERO and corner.dot(dir) > 0.5):
					corners.append(corner)
	return corners

static func channel_tint(channel: String) -> Color:
	match channel:
		CH_MATERIAL:
			return PackDrawerView.COLORS[Engraving.CATEGORY_MATERIAL]
		CH_RUNE:
			return PackDrawerView.COLORS[Engraving.CATEGORY_DICE]
		CH_SPECIAL:
			return PackDrawerView.COLORS[Pack.SHELF_SPECIAL]
	return PackDrawerView.COLORS[Engraving.CATEGORY_NUMBER]

## Die Kammer in Welt: Mitte auf Tischhöhe, halbe Spanne (Welt-X, Welt-Z), Tiefe.
## Dieselben Maße bauen nichts neu.
func setup(center: Vector3, half: Vector2, depth: float) -> void:
	var same := _ports != null and is_instance_valid(_ports) and center.is_equal_approx(_center) \
		and half.is_equal_approx(_half) and is_equal_approx(depth, _depth)
	_center = center
	_half = half
	_depth = depth
	if not same:
		_build_sockets()

## Der Auslass einer Station: sx/sz = die Kammerecke (Vorzeichen in Welt-X/-Z), upper =
## obere oder untere Reihe, rank = der Kanal.
func socket_point(sx: float, upper: bool, sz: float, rank: int) -> Vector3:
	var at := _center + Vector3(sx * (_half.x - PROUD), 0.0, sz * (_half.y - PROUD))
	var step := OUTLET_NEAR if rank < 2 else OUTLET_FAR
	if rank % 2 == 0:
		at.x -= sx * step
	else:
		at.z -= sz * step
	at.y = _center.y - (STATION_TOP if upper else _depth - STATION_FLOOR)
	return at

## In die Kammer hinein: die Wandnormale des Auslasses.
func socket_normal(sx: float, sz: float, rank: int) -> Vector3:
	return Vector3(0.0, 0.0, -sz) if rank % 2 == 0 else Vector3(-sx, 0.0, 0.0)

## Die Station einer Würfelecke: dieselbe Ecke der Kammer. offset = Ecke minus Würfelmitte.
static func station_of(offset: Vector3) -> Array:
	return [-1.0 if offset.x < 0.0 else 1.0, offset.y >= 0.0, -1.0 if offset.z < 0.0 else 1.0]

static func _socket_key(sx: float, upper: bool, sz: float, rank: int) -> String:
	return "%d|%d|%d|%d" % [int(sx), int(upper), int(sz), rank]

func socket_count() -> int:
	return _plugs.size()

## Wie viele Bandzungen gerade eingefahren in ihrem Auslass stehen.
func plugs_home() -> int:
	var count := 0
	for plug: Node3D in _plugs.values():
		if plug.visible:
			count += 1
	return count

func _build_sockets() -> void:
	if _ports != null and is_instance_valid(_ports):
		_ports.queue_free()
	_plugs.clear()
	_ports = Node3D.new()
	_ports.name = "Auslaesse"
	add_child(_ports)
	if _box == null:
		_box = BoxMesh.new()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			for upper: bool in [true, false]:
				for rank in CHANNELS.size():
					_build_socket(sx, upper, sz, rank)

## Die ZIF-LEISTE (lokal +X längs der Wand, +Y aus der Wand heraus, schräg nach oben):
## schwarzer Steckverbinder mit Verriegelungsbügel und goldener Kontaktreihe, die
## Sortenfarbe an den zwei Riegel-Laschen. Eingefahren steht die Bandzunge darin.
func _build_socket(sx: float, upper: bool, sz: float, rank: int) -> void:
	var tint := channel_tint(CHANNELS[rank])
	var normal := socket_normal(sx, sz, rank)
	var out := (normal + Vector3.UP * OUTLET_TILT).normalized()
	var along := Vector3.UP.cross(normal).normalized()
	var socket := Node3D.new()
	socket.name = "Auslass"
	_ports.add_child(socket)
	socket.global_transform = Transform3D(Basis(along, out, along.cross(out)),
		socket_point(sx, upper, sz, rank))
	var w := OUTLET_W
	var h := OUTLET_H
	_m(socket, GUNMETAL * 0.8, Vector3.ZERO, Vector3(w, 0.03, h))
	_m(socket, DARK, Vector3(0, 0.07, 0), Vector3(w * 0.84, 0.11, h * 0.56), 0.3)
	_m(socket, Color.BLACK, Vector3(0, 0.13, -h * 0.06), Vector3(w * 0.7, 0.012, h * 0.16), 0.0)
	for i in 11:
		_m(socket, GOLD, Vector3((float(i) - 5.0) * w * 0.062, 0.132, -h * 0.06),
			Vector3(0.022, 0.014, h * 0.14))
	_m(socket, STEEL * 0.8, Vector3(0, 0.14, h * 0.17), Vector3(w * 0.84, 0.035, h * 0.13))
	for side: float in [-1.0, 1.0]:
		_m(socket, tint * 0.9, Vector3(side * w * 0.455, 0.12, h * 0.17),
			Vector3(0.05, 0.07, h * 0.2), 0.2, 0.25)
	var plug := Node3D.new()
	plug.name = "Zunge"
	socket.add_child(plug)
	_m(plug, tint * 0.75, Vector3(0, 0.19, -h * 0.06), Vector3(w * 0.52, 0.1, RIBBON_FLAT * 2.0), 0.1, 0.15)
	_m(plug, STEEL, Vector3(0, 0.24, -h * 0.06), Vector3(w * 0.58, 0.035, 0.055))
	_plugs[_socket_key(sx, upper, sz, rank)] = plug

## Ein Quader-Bauteil: sein Licht rechnet der Shader selbst (in der Grube ist keines).
func _m(parent: Node3D, color: Color, at: Vector3, size: Vector3,
		metal := 1.0, glow := 0.0, turn := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = _box
	part.position = at
	part.rotation = turn
	part.scale = size
	part.material_override = _skin(color, metal, glow)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part

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

## Wo der ECKSTECKER einer Seiten-Ecke sitzt: auf dem Rahmen der Seite, dicht an der Ecke -
## die Fläche selbst bleibt frei.
func clamp_point(die_center: Vector3, basis: Basis, half_edge: float, face: int,
		corner: Vector3) -> Vector3:
	var dir := face_direction(face)
	var at := corner * half_edge + (dir - corner).normalized() * CLIP_INSET + dir * CLIP_PROUD
	return die_center + basis * at

## Die Kabel fahren aus und klemmen an. Endzustand zuerst: sie STEHEN angeklemmt, das
## Ausfahren ist nur der Weg dorthin. lead = so lange zeigt der Würfel erst seine Ports
## (er richtet sich derweil).
func dock(die_center: Vector3, die_basis: Basis, half_edge: float,
		plan: Array[Dictionary], time: float, care_tint := Color.WHITE, lead := 0.0) -> void:
	settle_hard()
	if _box == null:
		_box = BoxMesh.new()
	var basis := die_basis.orthonormalized()
	var faces := {}
	for entry in plan:
		var face := int(entry["face"])
		var channel := String(entry["channel"])
		var rank := CHANNELS.find(CH_SPECIAL if channel == CH_CARE else channel)
		var tint := care_tint if channel == CH_CARE else channel_tint(channel)
		var targets: Array = [face]
		if face == ALL_FACES:
			# Pflege ohne Seite faßt alle acht Ecken: über die obere und die untere Seite.
			targets = [DiceController.AXIS_FACE_INDEX["OBEN"], DiceController.AXIS_FACE_INDEX["UNTEN"]]
		for target: int in targets:
			if not faces.has(target):
				faces[target] = {}
			faces[target][rank] = tint
	if faces.is_empty():
		return
	_loom = Node3D.new()
	_loom.name = "Straenge"
	add_child(_loom)
	for face: int in faces:
		for corner in face_corners(face):
			_build_harness(die_center, basis, half_edge, face, corner, faces[face])
	_docked = true
	if time <= 0.0 or not is_inside_tree():
		_show_docked()
		return
	var gap := STAGGER_SPAN / float(maxi(_cables.size(), 1))
	_tween = create_tween().set_parallel(true)
	for port in _ports_lit:
		port.scale = Vector3.ZERO
		_tween.tween_property(port, "scale", Vector3.ONE, maxf(lead, 0.08)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_callback(port.hide).set_delay(lead + time)
	for i in _cables.size():
		var material: ShaderMaterial = _cables[i]["material"]
		material.set_shader_parameter("grow", 0.0)
		_tween.tween_property(material, "shader_parameter/grow", 1.0, time) \
			.set_delay(lead + gap * i).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for fitting in _fittings:
		fitting.scale = Vector3.ZERO
		_tween.tween_property(fitting, "scale", Vector3.ONE, 0.1).set_delay(lead + time * 0.85) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## EIN Strang: die Bänder der aktiven Kanäle von ihren Auslässen zum SAMMLER, von dort
## vier Spuren (unbenutzte dunkel) in den ECKSTECKER auf dem Rahmen der Seite.
func _build_harness(die_center: Vector3, basis: Basis, half_edge: float, face: int,
		corner: Vector3, lanes: Dictionary) -> void:
	var station := station_of(basis * corner)
	var seat := clamp_point(die_center, basis, half_edge, face, corner)
	var hub := Vector3.ZERO
	for rank in CHANNELS.size():
		hub += socket_point(station[0], station[1], station[2], rank) / float(CHANNELS.size())
	var toward := (hub - seat).normalized()
	var lat := toward.cross(Vector3.UP)
	lat = Vector3.RIGHT if lat.length() < 0.01 else lat.normalized()
	var joint := seat + toward * TRUNK
	for rank in CHANNELS.size():
		var shift := lat * (float(rank) - 1.5) * LANE
		if lanes.has(rank):
			var from := socket_point(station[0], station[1], station[2], rank)
			var key := _socket_key(station[0], station[1], station[2], rank)
			_add_cable(_weave_path(from, joint, seat, lat, rank), lanes[rank], from, seat, true)
			if _plugs.has(key):
				(_plugs[key] as Node3D).visible = false  # die Zunge ist ausgezogen
			var lamp := Node3D.new()
			lamp.name = "Port"
			_loom.add_child(lamp)
			lamp.global_position = seat + shift
			_m(lamp, lanes[rank], Vector3.ZERO, Vector3.ONE * 0.055, 0.0, 1.0)
			_ports_lit.append(lamp)
		else:
			_add_cable(_trunk_path(joint + shift, seat + shift, lat), IDLE_LANE, joint, seat, false)
	_fittings.append(_build_collector(joint, lat, toward, lanes))
	_fittings.append(_build_connector(die_center, basis, half_edge, face, corner, lanes))

## Der Weg EINES Bandes: Bézier-Durchhang vom Auslass zum Sammler, auf dem letzten Stück
## kreuzt es die anderen über und unter (der Zopf) und läuft auf seine Spur ein, dann
## gerade durch den Stamm in den Stecker. Je Punkt [Ort, Querachse, halbe Breite, Anteil].
func _weave_path(from: Vector3, joint: Vector3, seat: Vector3, lat: Vector3,
		rank: int) -> Array:
	var path: Array = []
	var lane := (float(rank) - 1.5) * LANE
	var mid := (from + joint) * 0.5 + Vector3.DOWN * from.distance_to(joint) * SAG
	mid.y = maxf(mid.y, _center.y - _depth + 0.1)
	for i in WEAVE_SEGMENTS + 1:
		var t := float(i) / float(WEAVE_SEGMENTS)
		var at := from.lerp(mid, t).lerp(mid.lerp(joint, t), t)
		var along := ((mid - from).lerp(joint - mid, t)).normalized()
		var flat := along.cross(Vector3.UP)
		flat = lat if flat.length() < 0.01 else flat.normalized()
		var braid := clampf((t - WEAVE_FROM) / (1.0 - WEAVE_FROM), 0.0, 1.0)
		var swing := sin(PI * braid)
		var phase := TAU * braid * WEAVE_TURNS + float(rank) * PI * 0.5
		at += lat * (lane * smoothstep(0.0, 1.0, braid) + sin(phase) * BRAID * swing)
		at += Vector3.UP * cos(phase) * BRAID * 0.45 * swing
		path.append([at, flat.lerp(lat, braid).normalized(),
			lerpf(RIBBON_WIDE, LANE * 0.44, braid), t * TRUNK_SHARE])
	path.append_array(_trunk_path(joint + lat * lane, seat + lat * lane, lat).slice(1))
	return path

func _trunk_path(from: Vector3, to: Vector3, lat: Vector3) -> Array:
	var path: Array = []
	for i in TRUNK_SEGMENTS + 1:
		var t := float(i) / float(TRUNK_SEGMENTS)
		path.append([from.lerp(to, t), lat, LANE * 0.44, lerpf(TRUNK_SHARE, 1.0, t)])
	return path

func _add_cable(path: Array, tint: Color, from: Vector3, to: Vector3, live: bool) -> void:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	material.set_shader_parameter("grow", 1.0)
	material.set_shader_parameter("pulse", -1.0)
	material.set_shader_parameter("glow", REST_GLOW if live else 0.0)
	var band := MeshInstance3D.new()
	band.name = "Band" if live else "Leerspur"
	band.mesh = _band_mesh(path)
	band.material_override = material
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_loom.add_child(band)
	band.global_transform = Transform3D.IDENTITY
	var cable := {"material": material, "from": from, "to": to, "live": live}
	if live:
		_cables.push_front(cable)
		_live += 1
	else:
		_cables.append(cable)

## Der SAMMLER: eine flache Muffe, in die die Bänder einlaufen und aus der der Stamm tritt.
func _build_collector(joint: Vector3, lat: Vector3, toward: Vector3, lanes: Dictionary) -> Node3D:
	var block := Node3D.new()
	block.name = "Sammler"
	_loom.add_child(block)
	block.global_transform = Transform3D(Basis(lat, toward.cross(lat), toward), joint)
	_m(block, GUNMETAL, Vector3.ZERO, Vector3(LANE * 4.7, 0.075, 0.2))
	_m(block, STEEL, Vector3(0, 0, -0.085), Vector3(LANE * 4.9, 0.09, 0.03))
	for rank in CHANNELS.size():
		if lanes.has(rank):
			_m(block, lanes[rank], Vector3((float(rank) - 1.5) * LANE, 0.04, 0.03),
				Vector3(LANE * 0.55, 0.012, 0.07), 0.0, 0.6)
	return block

## Der ECKSTECKER: ein Winkel, der die Ecke der Seite von innen faßt (zwei Schenkel längs
## der Kanten, stählerne Enden), davor der Schuh mit vier Kontakten für den Stamm.
func _build_connector(die_center: Vector3, basis: Basis, half_edge: float, face: int,
		corner: Vector3, lanes: Dictionary) -> Node3D:
	var dir := face_direction(face)
	var rim := corner - dir * corner.dot(dir)
	var edges: Array[Vector3] = []
	for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		if absf(rim.dot(axis)) > 0.5:
			edges.append(basis * (-axis * signf(rim.dot(axis))))
	var up := basis * dir
	var x := edges[0]
	if x.cross(up).dot(edges[1]) < 0.0:
		x = edges[1]
	var clip := Node3D.new()
	clip.name = "Eckstecker"
	_loom.add_child(clip)
	clip.global_transform = Transform3D(Basis(x, up, x.cross(up)),
		die_center + basis * (corner * half_edge + dir * (CLIP_PROUD - 0.06)))
	_m(clip, GUNMETAL * 0.9, Vector3(CLIP_ARM * 0.5, 0.025, CLIP_BAR * 0.5), Vector3(CLIP_ARM, 0.05, CLIP_BAR))
	_m(clip, GUNMETAL * 0.9, Vector3(CLIP_BAR * 0.5, 0.025, CLIP_ARM * 0.5), Vector3(CLIP_BAR, 0.05, CLIP_ARM))
	_m(clip, STEEL, Vector3(CLIP_ARM, 0.03, CLIP_BAR * 0.5), Vector3(0.05, 0.07, CLIP_BAR + 0.03))
	_m(clip, STEEL, Vector3(CLIP_BAR * 0.5, 0.03, CLIP_ARM), Vector3(CLIP_BAR + 0.03, 0.07, 0.05))
	var seat := CLIP_INSET * 0.7071
	_m(clip, DARK * 1.4, Vector3(seat, 0.045, seat), Vector3(LANE * 4.6, 0.09, 0.17), 0.4, 0.0, QUARTER)
	for rank in CHANNELS.size():
		var along := (float(rank) - 1.5) * LANE * 0.7071
		var inner := seat + 0.085
		var lit := lanes.has(rank)
		_m(clip, lanes[rank] if lit else GOLD * 0.5,
			Vector3(inner + along, 0.035, inner - along), Vector3(LANE * 0.45, 0.03, 0.06),
			0.0 if lit else 1.0, 0.35 if lit else 0.0, QUARTER)
	return clip

## Der Strom liest eine Karte: die Kabel glimmen kurz mit.
func tick() -> void:
	if not _docked or not is_inside_tree():
		return
	var blip := create_tween().set_parallel(true)
	for i in _live:
		var material: ShaderMaterial = _cables[i]["material"]
		blip.tween_property(material, "shader_parameter/glow", REST_GLOW, TICK_TIME) \
			.from(TICK_GLOW)

## DER EINSCHLAG: ein Puls läuft durch jedes Kabel von der Wand in seine Ecke.
func pulse(time: float) -> void:
	if not _docked or not is_inside_tree():
		return
	_kill()
	_show_docked()
	_tween = create_tween().set_parallel(true)
	for i in _live:
		var material: ShaderMaterial = _cables[i]["material"]
		_tween.tween_property(material, "shader_parameter/pulse", 1.0, maxf(time, 0.01)) \
			.from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(material, "shader_parameter/glow", 1.0, maxf(time, 0.01))

## Die Kabel lösen sich und fahren in die Wand zurück.
func release(time: float) -> void:
	if _cables.is_empty():
		return
	_kill()
	_docked = false
	if time <= 0.0 or not is_inside_tree():
		_clear()
		return
	for fitting in _fittings:
		fitting.visible = false
	for port in _ports_lit:
		port.visible = false
	_tween = create_tween().set_parallel(true)
	for cable in _cables:
		var material: ShaderMaterial = cable["material"]
		material.set_shader_parameter("pulse", -1.0)
		_tween.tween_property(material, "shader_parameter/grow", 0.0, time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(material, "shader_parameter/glow", 0.0, time)
	_tween.chain().tween_callback(_clear)

## Der EINE harte Aufräum-Pfad: kein Kabel steht mehr.
func settle_hard() -> void:
	_kill()
	_clear()

func docked() -> bool:
	return _docked

## Die ausgezogenen Bänder (ohne die dunklen Leerspuren der Stämme).
func cable_count() -> int:
	return _live

## Die Stränge: je Seiten-Ecke einer, mit Sammler und Eckstecker.
func harness_count() -> int:
	return _fittings.size() / 2

## Auslass und Stecker-Sitz des Bandes index in Welt - für Tests und Proben.
func cable_ends(index: int) -> Array[Vector3]:
	var cable := _cables[index]
	return [cable["from"], cable["to"]]

func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

func _clear() -> void:
	_docked = false
	if _loom != null and is_instance_valid(_loom):
		_loom.queue_free()
	_loom = null
	_cables.clear()
	_fittings.clear()
	_ports_lit.clear()
	_live = 0
	for plug: Node3D in _plugs.values():
		plug.visible = true  # jede Zunge steht wieder in ihrem Auslass

func _show_docked() -> void:
	for cable in _cables:
		(cable["material"] as ShaderMaterial).set_shader_parameter("grow", 1.0)
	for fitting in _fittings:
		fitting.scale = Vector3.ONE
	for port in _ports_lit:
		port.visible = false

## Ein FLACHBAND längs eines Weges: je Punkt [Ort, Querachse, halbe Breite, Anteil].
func _band_mesh(path: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var normals: Array = []
	for i in path.size():
		var at: Vector3 = path[i][0]
		var a: Vector3 = path[i][1]
		var wide := float(path[i][2])
		var next: Vector3 = path[mini(i + 1, path.size() - 1)][0]
		var last: Vector3 = path[maxi(i - 1, 0)][0]
		var b := (next - last).normalized().cross(a).normalized()
		var ring: Array[Vector3] = []
		var out: Array[Vector3] = []
		for j in SIDES + 1:
			var angle := TAU * float(j) / float(SIDES)
			ring.append(at + a * cos(angle) * wide + b * sin(angle) * RIBBON_FLAT)
			out.append((a * cos(angle) * RIBBON_FLAT + b * sin(angle) * wide).normalized())
		rings.append(ring)
		normals.append(out)
	for i in path.size() - 1:
		for j in SIDES:
			var corners: Array = [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
			for k: int in [0, 1, 2, 0, 2, 3]:
				var ring_index: int = corners[k][0]
				var side: int = corners[k][1]
				tool.set_normal(normals[ring_index][side])
				tool.set_uv(Vector2(float(path[ring_index][3]), float(side) / float(SIDES)))
				tool.add_vertex(rings[ring_index][side])
	return tool.commit()
