class_name TowerView
extends Node3D
## DER TURM der Werkstatt (Welle X, 2026-09-05): ein gerades Gestell aus sechs
## ETAGEN, seit der Welle 29 in einer geschlossenen TASCHE unter dem Ziel-Netz. Etage
## 0 ist die UNTERSTE und wirkt zuerst - die Reihenfolge IST die Höhe, und das
## DURCHLICHT steigt darum von unten. In jeder Etage LIEGT eine Karte flach, ihre
## Kontakte nach Bild-RECHTS in der KONTAKTLEISTE; links ist der Turm offen, und dort
## ragt sie als STUMMEL in die Auswurf-Bahn.
##
## Die Maße kommen von außen (scene_root rechnet die gemeldeten Rechtecke in Welt).
## seat() ist idempotent - Endzustand zuerst, es gibt keinen Tween außer dem Licht.

## Eine ETAGE ist eine Kartendicke plus ihr Boden - so steht jede Karte frei.
const CARD_THICKNESS := DataCellView.DEPTH * PackDrawerView.CASSETTE_SCALE
const FLOOR_PLATE := 0.06
const FLOOR_PITCH := CARD_THICKNESS + FLOOR_PLATE
## Die KAMMER am Fuß: der Sockel, aus dem das Licht steigt. Ihre Oberseite IST der
## Boden der untersten Etage.
const CHAMBER_HEIGHT := FLOOR_PITCH * 0.7
## Die Karte liegt eine Spur über dem Etagenboden (koplanar stritten sie im
## Tiefenpuffer).
const FLOOR_PROUD := 0.006

## Das Blech des Gestells und die goldene KONTAKTLEISTE (der Finnen-Ton).
const FRAME_ALBEDO := Color(0.22, 0.212, 0.285)
const FRAME_EMISSION := Color(0.46, 0.48, 0.66)
const FRAME_EMISSION_ENERGY := 0.42
const BAR_ALBEDO := Color(0.26, 0.22, 0.13)
const BAR_EMISSION := Color(0.92, 0.74, 0.34)
const BAR_EMISSION_ENERGY := 0.55
## Der MUND einer Etage in der Leiste: die Kontaktzunge, in die der Kartenfuß rastet.
const MOUTH_EMISSION_ENERGY := 1.1
const MOUTH_FLASH_ENERGY := 3.6
const MOUTH_FLASH_TIME := 0.3
## Tiefe der KONTAKTLEISTE als Anteil des Fußabdrucks längs (Welt-Z): sie steht IM
## gemeldeten Rechteck, am Bild-rechten Rand - der Rest gehört der Karte. Das
## Fenster schneidet seinen Turm-Platz an derselben Zahl.
const BAR_SHARE := 0.07
## Seit dem 2026-10-27 ist sie eine RÜCKWAND mit BUCHSEN (Spieler-Entscheid): ihr
## Blech, die goldenen Busbahnen (eine je Stift) und der Rand der Buchse über und
## unter der Karte.
const BACKPLANE := 0.1
const BUS_LINES := 8
const BUS_WIDTH := 0.03
const SOCKET_LIP := 0.05
const SOCKET_ALBEDO := Color(0.08, 0.08, 0.11)
## Das GESTELL wie im Serverschrank: vier Pfosten, und je Etage zwei Winkel unter den
## Längskanten der Karte - eine liegende Auflage und eine stehende Wange.
const RACK_POST := 0.08
const RACK_RAIL := 0.035
const RACK_LEDGE := 0.14
const RACK_CHEEK := 0.025

## Der Turm steht seit der Welle 29 in einer GESCHLOSSENEN Tasche unter dem Ziel-Netz;
## offen ist nur die Auswurf-Bahn links davon. Daraus ragt jede Karte mit einem
## STUMMEL (Anteil ihrer LÄNGE über die Lochkante hinaus), gestaffelt je Etage (unten
## am weitesten heraus). Eingerastet bleibt ein kürzerer Stummel stehen - an ihm
## sieht man das Licht steigen -, und der HOVER zieht sie ganz in die Bahn. Die EINE
## Quelle: der Körper fährt danach, das Fenster schneidet seine Bahn danach.
const STUB_SHARE := 0.2
const STUB_LATCHED := 0.1
const PEEK_SHARE := 0.03
## Der volle Zug unter dem Zeiger: die ganze Karte samt einer Spur Luft in der Bahn.
const EJECT_PULL := 1.05
## Der Fußabdruck einer Etage ist die liegende Karte mal CARD_ROOM (WorkshopView
## schneidet seinen Turm-Platz danach), und die DAHEIM liegende Karte beginnt die
## halbe Luft hinter der offenen Turmkante.
const CARD_ROOM := 1.10
const HOME_INSET := (CARD_ROOM - 1.0) * 0.5

## Der Ruhe-Versatz der Karte von Etage index, als Anteil ihrer Länge. count ist
## die ETAGENZAHL des Turms, nie die Zahl der gesteckten Karten - sonst rückten
## alle gemeinsam heraus, sobald eine dazukommt.
static func pull_share(index: int, count: int) -> float:
	return HOME_INSET + STUB_SHARE + PEEK_SHARE * float(maxi(count - 1 - index, 0))

## Eingerastet: der kurze Stummel, an dem das Licht vorbeizieht.
static func latched_share() -> float:
	return HOME_INSET + STUB_LATCHED

## Der Hover-Zug der Karte von Etage index (DataCellView.hover_slide): von ihrer Ruhe
## bis ganz in die Bahn - jede Etage landet am selben Platz.
static func hover_slide_for(index: int, count: int) -> float:
	return maxf(HOME_INSET + EJECT_PULL - pull_share(index, count), 0.0)

## So breit ist die AUSWURF-BAHN, in Kartenlängen - für jede Etagenzahl dieselbe.
static func eject_share(_count: int) -> float:
	return EJECT_PULL

## Die KAMMER glimmt, bevor sie zündet, und die LICHT-EBENE ist ein additives Quad
## in Kartengröße.
const CHAMBER_EMISSION := Color(0.55, 0.91, 0.99)
const CHAMBER_EMISSION_ENERGY := 0.5
## GEMESSEN am dunklen Filz: darüber überstrahlt die Ebene das Licht-Netz auf ihr.
const LIGHT_ALPHA := 0.30
const LIGHT_ENERGY := 1.25

## Die TASCHE unter dem Filz: fast schwarz, sie ist nur der Grund hinter den Stummeln.
const POCKET_WALL := 0.06
const POCKET_ALBEDO := Color(0.028, 0.026, 0.042)
const POCKET_EMISSION := Color(0.10, 0.11, 0.17)
const POCKET_ENERGY := 0.35

var _frame_material: StandardMaterial3D
var _bar_material: StandardMaterial3D
var _socket_material: StandardMaterial3D
var _chamber_material: StandardMaterial3D
var _light_material: StandardMaterial3D

var _count := 0
var _span := Vector2.ONE
var _seat := Vector3.ZERO
var _chamber: Node3D
var _pocket: Node3D
var _rack: Node3D
var _floors: Array[Node3D] = []
var _mouths: Array[MeshInstance3D] = []
var _mouth_flashes: Array[Tween] = []
## Der LICHT-Halter: die Ebene hängt daran, und mit ihr reitet das Licht-Netz.
var _light: Node3D
var _light_plane: MeshInstance3D
var _light_ride: Tween

func _init() -> void:
	name = "Tower"

## Höhe des Etagenbodens index über dem Glas (0 = unten).
static func floor_top(index: int) -> float:
	return CHAMBER_HEIGHT + FLOOR_PITCH * float(maxi(index, 0))

## ... und die Höhe, auf der die KARTE dieser Etage LIEGT.
static func floor_seat(index: int) -> float:
	return floor_top(index) + FLOOR_PROUD

## Die Höhe des ganzen Turms bei count Etagen.
static func tower_height(count: int) -> float:
	return floor_top(maxi(count, 1) - 1) + CARD_THICKNESS

## Der TURM HART setzen: at = Fußpunkt seiner Mitte, span = Weltmaß seines
## Fußabdrucks (x quer, y längs = Welt-Z), count = Etagen. Mit glass_y steht er in
## seiner geschlossenen TASCHE unter dem Filz (pocket_width = ihre Breite quer, so
## breit wie das Loch daneben). Idempotent.
func seat(at: Vector3, span: Vector2, count: int, glass_y := NAN,
		pocket_width := 0.0) -> void:
	_ensure_materials()
	_seat = at
	_span = Vector2(maxf(span.x, 0.01), maxf(span.y, 0.01))
	_count = maxi(count, 1)
	for old in _floors + ([_chamber] if _chamber != null else []) \
			+ ([_pocket] if _pocket != null else []) + ([_rack] if _rack != null else []):
		if is_instance_valid(old):
			remove_child(old)
			old.queue_free()
	_floors.clear()
	_mouths.clear()
	_mouth_flashes.clear()
	_pocket = null
	_build_chamber()
	for i in _count:
		_floors.append(_build_floor(i))
	_rack = _build_rack()
	if not is_nan(glass_y):
		_build_pocket(glass_y, maxf(pocket_width, _span.x))
	_ensure_light()
	_fit_light_plane()
	_light.global_position = Vector3(_seat.x, _seat.y + chamber_top(), _seat.z)

## Die Länge einer liegenden Karte in Welt, aus dem Fußabdruck zurückgerechnet.
func card_length() -> float:
	return _span.y * (1.0 - BAR_SHARE) / CARD_ROOM

## Die TASCHE ist auch zur MAGAZIN-Grube hin offen (Spieler-Wunsch 2026-10-27): die
## Oberwand des Magazins hat dort einen Durchbruch von EINER Kartenlänge, und durch
## ihn sieht man aus der Grube auf die ETAGEN. Von außen bestellt, VOR dem seat.
## Was neben dem Durchbruch liegt, deckt die Grubenwand selbst - sie steht eine
## Wandstärke dahinter, also sieht man auch so nie in den Raum.
var pit_open := false

## Und ihr DECKEL fällt, sobald es bestellt ist (Spieler-Wunsch 2026-10-27): die
## TISCHSEKTION darüber ist GLAS, also soll dort der Turm stehen und keine Decke.
var lid_open := false

## Die TASCHE: ein dunkler Kasten um den Turm, zur Auswurf-Bahn hin offen - durch
## das Loch sieht man unter dem Filz in eine ehrliche Tiefe, nie in den Raum.
func _build_pocket(glass_y: float, width: float) -> void:
	var host := Node3D.new()
	host.name = "Tasche"
	add_child(host)
	_pocket = host
	var material := TableProps.metal(POCKET_ALBEDO, POCKET_EMISSION, POCKET_ENERGY,
		0.35, 0.55)
	var top := glass_y - PackPitView.WALL_SINK
	var bottom := _seat.y - POCKET_WALL
	var high := maxf(top - bottom, 0.05)
	var near := _seat.z - _span.y * 0.5
	var deep := _span.y + POCKET_WALL
	var wide := width + POCKET_WALL * 2.0
	var mid := Vector3(_seat.x, (top + bottom) * 0.5, near + deep * 0.5)
	if not lid_open:
		TableProps.box(host, "Decke", Vector3(wide, POCKET_WALL, deep),
			Vector3(mid.x, top - POCKET_WALL * 0.5, mid.z), material)
	TableProps.box(host, "Boden", Vector3(wide, POCKET_WALL, deep),
		Vector3(mid.x, bottom - POCKET_WALL * 0.5, mid.z), material)
	TableProps.box(host, "Rueckwand", Vector3(wide, high, POCKET_WALL),
		Vector3(mid.x, mid.y, near + deep + POCKET_WALL * 0.5), material)
	for side in 2:
		var dir := float(side) * 2.0 - 1.0
		# Zur MAGAZIN-Grube (Welt -X, Bild-unten) steht die Flanke offen, sobald es
		# bestellt ist - sonst schaut der Durchbruch nur auf eine zweite Wand.
		if pit_open and dir < 0.0:
			continue
		TableProps.box(host, "Flanke%d" % side, Vector3(POCKET_WALL, high, deep),
			Vector3(mid.x + dir * (wide * 0.5 - POCKET_WALL * 0.5), mid.y, mid.z),
			material)

func floor_count() -> int:
	return _count

## Tiefe der Kontaktleiste in Welt - so weit weicht der Kartenplatz nach Bild-links.
func bar_depth() -> float:
	return _span.y * BAR_SHARE

## Das Blech der RÜCKWAND - nie tiefer als der Leisten-Platz.
func backplane_depth() -> float:
	return minf(BACKPLANE, bar_depth())

## Der MUND jeder Buchse in Welt-Z: der Fuß der EINGERASTETEN Karte.
func socket_mouth_z() -> float:
	return floor_point_z() - latched_share() * card_length() + card_length() * 0.5

func floor_point_z() -> float:
	return _seat.z - bar_depth() * 0.5

## Breite der liegenden Karte quer, aus dem Fußabdruck zurückgerechnet.
func card_width() -> float:
	return _span.x / CARD_ROOM

## Querschnitt der Buchse - das Modell in tools/blender_hardware.py spiegelt dieselben
## Zahlen (Breite 0,92 der Karte, je LIP über und unter ihr).
static func socket_width() -> float:
	return DataCellView.WIDTH * PackDrawerView.CASSETTE_SCALE * 0.92

static func socket_height() -> float:
	return CARD_THICKNESS + SOCKET_LIP * 2.0

## Die Querlage des Stifts i über der Kartenmitte (dieselbe Teilung wie im Modell).
static func pin_x(i: int) -> float:
	var spread := DataCellView.WIDTH * PackDrawerView.CASSETTE_SCALE * 0.74
	return -spread * 0.5 + spread * float(i) / float(BUS_LINES - 1)

## Der Weltpunkt, auf dem die Karte der Etage index LIEGT (ZERO = keine solche).
## Sie liegt vor der Leiste, nicht in ihr.
func floor_point(index: int) -> Vector3:
	if index < 0 or index >= _count:
		return Vector3.ZERO
	return _seat + Vector3(0.0, floor_seat(index), -bar_depth() * 0.5)

## Die Oberkante der KAMMER - dort zündet das Licht.
func chamber_top() -> float:
	return CHAMBER_HEIGHT

## Der Weltpunkt des Turmkopfs (Oberkante der obersten Etage).
func top_point() -> Vector3:
	return _seat + Vector3.UP * tower_height(_count)

## Der Fußabdruck in Welt, wie er gesetzt wurde.
func span() -> Vector2:
	return _span

# --- DAS DURCHLICHT ------------------------------------------------------------

## Das Licht ZÜNDET in der Kammer, im Ton der Serie.
func light_on(accent: Color) -> void:
	_ensure_light()
	if _light_material != null:
		_light_material.albedo_color = Color(accent.r * LIGHT_ENERGY,
			accent.g * LIGHT_ENERGY, accent.b * LIGHT_ENERGY, LIGHT_ALPHA)
	_light.visible = true
	light_hard(_seat.y + chamber_top())

## Die Licht-Ebene STEIGT auf eine Welt-Höhe. Endzustand zuerst: bei time <= 0 steht
## sie sofort dort.
func light_to(height: float, time: float) -> void:
	_ensure_light()
	if time <= 0.0:
		light_hard(height)
		return
	_kill(_light_ride)
	_light_ride = create_tween()
	_light_ride.tween_property(_light, "global_position",
		Vector3(_seat.x, height, _seat.z), time)
	_light_ride.tween_callback(func() -> void: light_hard(height))

func light_hard(height: float) -> void:
	_ensure_light()
	_kill(_light_ride)
	_light.global_position = Vector3(_seat.x, height, _seat.z)

func light_height() -> float:
	return _light.global_position.y if _light != null and is_instance_valid(_light) \
		else 0.0

func lighting() -> bool:
	return _light != null and is_instance_valid(_light) and _light.visible

## Der EINE Aufräum-Pfad des Lichts: Fahrt aus, Ebene fort.
func light_off() -> void:
	_kill(_light_ride)
	if _light != null and is_instance_valid(_light):
		_light.visible = false
		_light.global_position = Vector3(_seat.x, _seat.y + chamber_top(), _seat.z)

## Ein Reiter auf der Licht-Ebene (das LICHT-NETZ): er hängt daran und fährt mit.
func attach_to_light(rider: Node3D) -> void:
	_ensure_light()
	if rider.get_parent() == _light:
		return
	if rider.get_parent() != null:
		rider.get_parent().remove_child(rider)
	_light.add_child(rider)

## Der MUND-BLITZ beim Einrasten der Karte von Etage index.
func latch_flash(index: int) -> void:
	if index < 0 or index >= _mouths.size():
		return
	var mouth := _mouths[index]
	if not is_instance_valid(mouth):
		return
	var material := mouth.material_override as StandardMaterial3D
	if material == null:
		return
	_kill(_mouth_flashes[index])
	material.emission_energy_multiplier = MOUTH_FLASH_ENERGY
	var flash := create_tween()
	_mouth_flashes[index] = flash
	flash.tween_method(func(value: float) -> void:
		material.emission_energy_multiplier = value,
		MOUTH_FLASH_ENERGY, MOUTH_EMISSION_ENERGY, MOUTH_FLASH_TIME)

# --- Aufbau ---------------------------------------------------------------------

func _build_chamber() -> void:
	var host := Node3D.new()
	host.name = "Chamber"
	add_child(host)
	_chamber = host
	var base := MeshInstance3D.new()
	base.name = "Base"
	var box := BoxMesh.new()
	box.size = Vector3(_span.x, CHAMBER_HEIGHT, _span.y)
	base.mesh = box
	base.material_override = _frame_material
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	base.position = Vector3(_seat.x, _seat.y + CHAMBER_HEIGHT * 0.5, _seat.z)
	host.add_child(base)
	# Der SCHACHT: ein glimmendes Feld in der Kammer-Oberseite, aus dem das Licht steigt.
	var vent := MeshInstance3D.new()
	vent.name = "Vent"
	var quad := QuadMesh.new()
	quad.size = Vector2(_span.x * 0.7, _span.y * 0.7)
	vent.mesh = quad
	vent.material_override = _chamber_material
	vent.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	vent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vent.position = Vector3(_seat.x, _seat.y + CHAMBER_HEIGHT + FLOOR_PROUD, _seat.z)
	host.add_child(vent)
	# Die RÜCKWAND am Bild-rechten Rand (Welt +Z, Spieler-Entscheid 2026-10-27): ein
	# dunkles Blech mit goldenen Busbahnen, auf dem die Buchsen der Etagen sitzen -
	# links bleibt der Turm offen.
	var bar := MeshInstance3D.new()
	bar.name = "ContactBar"
	var wall := BoxMesh.new()
	var depth := backplane_depth()
	var high := tower_height(_count)
	wall.size = Vector3(_span.x, high, depth)
	bar.mesh = wall
	bar.material_override = _frame_material
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.position = Vector3(_seat.x, _seat.y + high * 0.5,
		_seat.z + _span.y * 0.5 - depth * 0.5)
	host.add_child(bar)
	for i in BUS_LINES:
		var x := pin_x(i)
		TableProps.box(host, "Bus%d" % i, Vector3(BUS_WIDTH, high, BUS_WIDTH),
			Vector3(_seat.x + x, _seat.y + high * 0.5,
				_seat.z + _span.y * 0.5 - depth - BUS_WIDTH * 0.5), _bar_material)

func _build_floor(index: int) -> Node3D:
	var host := Node3D.new()
	host.name = "Floor%d" % (index + 1)
	add_child(host)
	# Die BUCHSE der Etage (Spieler-Entscheid 2026-10-27): ihr Mund sitzt dort, wo der
	# Fuß der EINGERASTETEN Karte steht - beim Einrasten stecken die Stifte darin, in
	# Ruhe stehen sie frei davor. Ein STEG trägt sie bis an die Rückwand.
	var mid_y := _seat.y + floor_seat(index) + CARD_THICKNESS * 0.5
	var mouth_z := socket_mouth_z()
	var socket := DataCellView.socket_model()
	if socket != null:
		socket.position = Vector3(_seat.x, mid_y, mouth_z)
		host.add_child(socket)
	var back := _seat.z + _span.y * 0.5 - backplane_depth()
	var riser_from := mouth_z + DataCellView.SOCKET_DEPTH
	if back - riser_from > 0.001:
		TableProps.box(host, "Steg", Vector3(socket_width(), socket_height(),
			back - riser_from), Vector3(_seat.x, mid_y, (riser_from + back) * 0.5),
			_socket_material)
	# Der MUND ist die Goldlippe oben am Buchsenmund: sie blitzt beim Einrasten.
	var mouth := MeshInstance3D.new()
	mouth.name = "Mouth"
	var lip := BoxMesh.new()
	lip.size = Vector3(socket_width() * 0.9, 0.014, 0.05)
	mouth.mesh = lip
	var material := StandardMaterial3D.new()
	material.albedo_color = BAR_ALBEDO
	material.metallic = 0.6
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = BAR_EMISSION
	material.emission_energy_multiplier = MOUTH_EMISSION_ENERGY
	mouth.material_override = material
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mouth.position = Vector3(_seat.x, mid_y + socket_height() * 0.5 + 0.007,
		mouth_z + 0.03)
	host.add_child(mouth)
	if index > 0:
		_build_rails(host, index)
	_mouths.append(mouth)
	_mouth_flashes.append(null)
	return host

## Die zwei WINKEL einer Etage: die Auflage greift RACK_LEDGE unter die Kartenkante,
## die Wange steht außen daneben. Sie reichen von der offenen Kante bis zur Buchse -
## die Karte fährt über sie hinaus in die Bahn.
func _build_rails(host: Node3D, index: int) -> void:
	var top := _seat.y + floor_top(index)
	var near := _seat.z - _span.y * 0.5
	var far := socket_mouth_z()
	var length := far - near
	if length <= 0.01:
		return
	var edge := card_width() * 0.5
	var outer := _span.x * 0.5 - RACK_POST
	for side in [-1.0, 1.0]:
		var inner := edge - RACK_LEDGE
		TableProps.box(host, "Auflage%s" % ("A" if side < 0.0 else "B"),
			Vector3(outer - inner, RACK_RAIL, length),
			Vector3(_seat.x + side * (inner + outer) * 0.5, top - RACK_RAIL * 0.5,
				near + length * 0.5), _frame_material)
		var cheek_x := edge + (outer - edge) * 0.5
		TableProps.box(host, "Wange%s" % ("A" if side < 0.0 else "B"),
			Vector3(RACK_CHEEK, CARD_THICKNESS * 0.6, length),
			Vector3(_seat.x + side * cheek_x, top + CARD_THICKNESS * 0.3, near + length * 0.5),
			_frame_material)

## Die vier PFOSTEN und der Kopfrahmen. Vorn (zur Bahn) läuft kein Querträger: dort
## fahren die Karten hinaus.
func _build_rack() -> Node3D:
	var host := Node3D.new()
	host.name = "Gestell"
	add_child(host)
	var high := tower_height(_count)
	var x := _span.x * 0.5 - RACK_POST * 0.5
	var near := _seat.z - _span.y * 0.5 + RACK_POST * 0.5
	var back := _seat.z + _span.y * 0.5 - backplane_depth() - RACK_POST * 0.5
	for side in [-1.0, 1.0]:
		var tag := "A" if side < 0.0 else "B"
		for z in [near, back]:
			TableProps.box(host, "Pfosten%s%s" % [tag, "V" if z == near else "H"],
				Vector3(RACK_POST, high, RACK_POST),
				Vector3(_seat.x + side * x, _seat.y + high * 0.5, z), _frame_material)
		TableProps.box(host, "Holm%s" % tag, Vector3(RACK_POST, RACK_POST, back - near),
			Vector3(_seat.x + side * x, _seat.y + high - RACK_POST * 0.5, (near + back) * 0.5),
			_frame_material)
	return host

func _ensure_light() -> void:
	if _light != null and is_instance_valid(_light):
		return
	_light = Node3D.new()
	_light.name = "Light"
	_light.visible = false
	add_child(_light)
	_light_material = StandardMaterial3D.new()
	_light_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_light_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_light_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_light_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# LICHT liest IMMER: die noch nicht gelesenen Karten liegen über der Ebene und
	# verdeckten sie sonst von oben.
	_light_material.no_depth_test = true
	_light_material.render_priority = DataCellView.PRIORITY_NET
	_light_material.albedo_color = Color(CHAMBER_EMISSION.r * LIGHT_ENERGY,
		CHAMBER_EMISSION.g * LIGHT_ENERGY, CHAMBER_EMISSION.b * LIGHT_ENERGY,
		LIGHT_ALPHA)
	_light_plane = MeshInstance3D.new()
	_light_plane.name = "Plane"
	_light_plane.mesh = QuadMesh.new()
	_light_plane.material_override = _light_material
	_light_plane.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_light_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light.add_child(_light_plane)

## Die LICHT-EBENE liegt nur über den STUMMELN - unter dem Filz sähe sie keiner, und
## über dem Ziel-Netz malte sie sich (sie liest ohne Tiefentest) auf die Anzeige.
func _fit_light_plane() -> void:
	if _light_plane == null or not is_instance_valid(_light_plane):
		return
	var reach := card_length() * (pull_share(0, _count) - HOME_INSET)
	var quad := _light_plane.mesh as QuadMesh
	quad.size = Vector2(_span.x, maxf(reach, 0.01))
	_light_plane.position = Vector3(0.0, 0.0, -_span.y * 0.5 - reach * 0.5)

func light_plane_size() -> Vector2:
	if _light_plane == null or not is_instance_valid(_light_plane):
		return Vector2.ZERO
	return (_light_plane.mesh as QuadMesh).size

func _ensure_materials() -> void:
	if _frame_material != null:
		return
	_frame_material = StandardMaterial3D.new()
	_frame_material.albedo_color = FRAME_ALBEDO
	_frame_material.metallic = 0.35
	_frame_material.roughness = 0.55
	_frame_material.emission_enabled = true
	_frame_material.emission = FRAME_EMISSION
	_frame_material.emission_energy_multiplier = FRAME_EMISSION_ENERGY
	_bar_material = StandardMaterial3D.new()
	_bar_material.albedo_color = BAR_ALBEDO
	_bar_material.metallic = 0.6
	_bar_material.roughness = 0.35
	_bar_material.emission_enabled = true
	_bar_material.emission = BAR_EMISSION
	_bar_material.emission_energy_multiplier = BAR_EMISSION_ENERGY
	_socket_material = StandardMaterial3D.new()
	_socket_material.albedo_color = SOCKET_ALBEDO
	_socket_material.metallic = 0.3
	_socket_material.roughness = 0.4
	_chamber_material = StandardMaterial3D.new()
	_chamber_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_chamber_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_chamber_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_chamber_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_chamber_material.albedo_color = Color(
		CHAMBER_EMISSION.r * CHAMBER_EMISSION_ENERGY,
		CHAMBER_EMISSION.g * CHAMBER_EMISSION_ENERGY,
		CHAMBER_EMISSION.b * CHAMBER_EMISSION_ENERGY, 0.4)

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
