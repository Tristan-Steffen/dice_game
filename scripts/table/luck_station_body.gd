class_name LuckStationBody
extends Node3D
## Der Körper der GLÜCKS-STATION, ein Nullkraft-Sockel als Bauteil der Platine: goldener
## SOCKEL mit Kontakten im Randband und dem ruhigen Sitz samt Lichtring, rechts der HEBEL
## (verriegelt grün, offen bernstein - der Würfel ist unterwegs), sechs Abtast-Züge in den
## CHIP mit den sechs Seiten als Fenstern (echte Augen, letzte Seite gold gesäumt, dazu
## "Ø n,n"), darunter der BALKEN zum nächsten Auge ("GLÜCK 25 / 28") und die Bonus-Zeile im
## Klartext. Ursprung = Stationsmitte.

## Höhe des Sitzes: dort ruht der Glückswürfel.
const SEAT_TOP := 0.46
## Höchster Punkt in Ruhe (verriegelter Hebel); der offene Hebel steht darüber auf.
const REST_TOP := 0.62
const SOCKET_HEIGHT := 0.4
const LEVER_OPEN := deg_to_rad(70.0)
const LEVER_TIME := 0.35
const LEVER_HEIGHT := 0.42
const KNOB_RADIUS := 0.36
const CHIP_TOP := 0.34
const LEG_PITCH := 0.38
const GAUGE_ROOM := 1.9
const CONTACTS := 11
const CONTACT_PITCH := 0.33
const PIP_SPREAD := 0.29
const PIP_RADIUS := 0.095
const PIP_FLASH_TIME := 0.5
## Zeichenbreite der Disketten-Schrift je Zeilenhöhe.
const MONO_WIDTH := 0.55
## Die sieben Augen-Plätze einer Seite (Seiten-Koordinaten wie LuckDie.PIP_LAYOUTS).
const SPOTS: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(0, 0),
	Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]

const GOLD := Color(0.72, 0.52, 0.18)
const EMERALD := Color(0.12, 0.9, 0.42)
const EMERALD_DIM := Color(0.03, 0.2, 0.09)
const AMBER := Color(0.95, 0.66, 0.24)
const LIGHT := Color(0.95, 0.82, 0.42)
const LACQUER := Color(0.02, 0.022, 0.026)
const EPOXY := Color(0.075, 0.08, 0.092)
const EPOXY_TOP := Color(0.105, 0.11, 0.124)
const MARKING := Color(0.5, 0.53, 0.58)
const LEG := Color(0.66, 0.69, 0.74)
const GLASS := Color(0.012, 0.016, 0.02)
const MULDE := Color(0.006, 0.02, 0.014)
const RIM_OFF := Color(0.36, 0.37, 0.42)
const SILK := Color(0.55, 0.6, 0.57)
const GHOST := Color(0.04, 0.03, 0.01)

var _built := false
var _key := ""
var _writes := 0
var _faces: Array[int] = [1, 1, 1, 1, 1, 1]
var _last_face := -1
var _state := {}
var _open := false
var _lever_tween: Tween
var _lever: Node3D
var _knob_light: MeshInstance3D
var _seat_ring: MeshInstance3D
var _seat_core: MeshInstance3D
## Je Seite sieben Augen und vier Saum-Stege.
var _pips: Array = []
var _rims: Array[MultiMeshInstance3D] = []
var _flash := {}
var _gauge_rect := Rect2()
var _gauge_number: Label3D
var _bar_fill: MeshInstance3D
var _bar_span := Vector2.ZERO
var _bar_share := 0.0
var _next_pip: MeshInstance3D
var _expected: Label3D
var _gauge_label: Label3D
var _bonus_label: Label3D
var _mat := {}

## parts: je Teil ein Rechteck in der Ebene (x = Bild-rechts, y = Bild-unten, Welt-Einheiten,
## um die Stationsmitte), "cells" je Seite eines.
func setup(parts: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_pips.clear()
	_rims.clear()
	_flash.clear()
	_build_materials()
	_build_socket(parts["socket"], parts["seat"])
	_build_lever(parts["lever"])
	_build_chip(parts["chip"], parts["cells"], parts["expected"])
	_gauge_rect = parts["gauge"]
	_build_gauge()
	_bonus_label = StationParts.label(self, "Bonus", "",
		_at(Vector2((parts["gauge"] as Rect2).get_center().x, (parts["free"] as Rect2).get_center().y), 0.003),
		0.32, LIGHT)
	_built = true
	_key = ""
	_set_lever_angle(LEVER_OPEN if _open else 0.0)
	_paint_lever_lights()
	_write()

## Der EINE Schreiber des Standes: nur der Wechsel schreibt.
func set_state(faces: Array, last_face: int, state: Dictionary) -> void:
	var key := "%s|%d|%s" % [str(faces), last_face, str(state)]
	if key == _key:
		return
	_key = key
	var before := _faces.duplicate()
	_faces.assign(faces)
	_last_face = last_face
	_state = state.duplicate()
	if _built:
		for face in mini(_faces.size(), before.size()):
			if _faces[face] > int(before[face]):
				_flash[face] = 1.0
	_write()

## Der Hebel: offen, solange der Würfel unterwegs ist. Endzustand zuerst, dann die Fahrt.
func set_lever_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	_paint_lever_lights()
	if _lever == null:
		return
	if _lever_tween != null and _lever_tween.is_valid():
		_lever_tween.kill()
	_lever_tween = create_tween()
	_lever_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lever_tween.tween_method(_set_lever_angle, _lever.rotation.z,
		LEVER_OPEN if open else 0.0, LEVER_TIME)

## Der harte Weg: Hebel an seinem Ziel, kein Blitz.
func settle_hard() -> void:
	if _lever_tween != null and _lever_tween.is_valid():
		_lever_tween.kill()
	_set_lever_angle(LEVER_OPEN if _open else 0.0)
	_flash.clear()
	_paint_pips()

func lever_open() -> bool:
	return _open

func lever_angle() -> float:
	return _lever.rotation.z if _lever != null else 0.0

func writes() -> int:
	return _writes

func lit_pip_count() -> int:
	var count := 0
	for face_pips: Array in _pips:
		for pip: MeshInstance3D in face_pips:
			if pip.visible:
				count += 1
	return count

## Füllung des Balkens von der letzten zur nächsten Schwelle (0..1).
func bar_share() -> float:
	return _bar_share

func gauge_shown() -> String:
	return _gauge_label.text if _gauge_label != null else ""

func gauge_number_shown() -> String:
	return _gauge_number.text if _gauge_number != null else ""

func bonus_shown() -> String:
	return _bonus_label.text if _bonus_label != null and _bonus_label.visible else ""

func rim_lit(face: int) -> bool:
	return _rims[face].material_override == _mat["light"]

func expected_shown() -> String:
	return _expected.text if _expected != null else ""

# --- Bau ----------------------------------------------------------------------------------

func _build_materials() -> void:
	_mat = {
		"gold": StationParts.steel(GOLD, 0.15, 0.05),
		"steel": StationParts.steel(ChipFrameView.STEEL, 0.4),
		"lacquer": StationParts.lit(LACQUER),
		"epoxy": StationParts.lit(EPOXY),
		"glass": StationParts.lit(GLASS),
		"mulde": StationParts.lit(MULDE),
		"emerald": StationParts.lit(EMERALD),
		"emerald_dim": StationParts.lit(EMERALD_DIM),
		"amber": StationParts.lit(AMBER),
		"light": StationParts.lit(LIGHT),
		"rim_off": StationParts.lit(RIM_OFF),
		"epoxy_top": StationParts.lit(EPOXY_TOP),
		"leg": StationParts.steel(LEG, 0.3, 0.12),
		"flash": StationParts.lit(LIGHT),
	}

## Ebene (rechts, unten) -> lokal (x = Bild-oben, z = Bild-rechts).
static func _at(p: Vector2, y: float) -> Vector3:
	return Vector3(-p.y, y, p.x)

func _build_socket(socket: Rect2, seat: Rect2) -> void:
	var c := socket.get_center()
	var side := socket.size.x
	StationParts.box(self, "Sockel", Vector3(side, SOCKET_HEIGHT, side), _at(c, SOCKET_HEIGHT * 0.5), _mat["gold"])
	StationParts.box(self, "Deckplatte", Vector3(side - 0.44, 0.04, side - 0.44),
		_at(c, SOCKET_HEIGHT + 0.02), _mat["lacquer"])
	var contacts: Array[Transform3D] = []
	for i in CONTACTS:
		for j in CONTACTS:
			if mini(mini(i, j), mini(CONTACTS - 1 - i, CONTACTS - 1 - j)) >= 2:
				continue
			var p := c + Vector2(float(i) - 5.0, float(j) - 5.0) * CONTACT_PITCH
			contacts.append(StationParts.cube(Vector3(0.12, 0.006, 0.12), _at(p, SOCKET_HEIGHT + 0.043)))
	StationParts.swarm(self, "Kontakte", contacts, _mat["gold"])
	var r := seat.size.x * 0.5
	StationParts.cyl(self, "Sitz", r, 0.02, _at(c, SOCKET_HEIGHT + 0.05), _mat["mulde"], 48)
	_seat_ring = StationParts.ring(self, "SitzRing", r * 0.89, 0.12, _at(c, SEAT_TOP), _mat["emerald"])
	_seat_core = StationParts.cyl(self, "SitzKern", r * 0.4, 0.004, _at(c, SEAT_TOP - 0.003), _mat["emerald_dim"], 32)
	StationParts.box(self, "Pin1", Vector3(0.22, 0.02, 0.22),
		_at(c + Vector2(-side * 0.5 + 0.36, -side * 0.5 + 0.36), SOCKET_HEIGHT + 0.03), _mat["emerald"])

## Der Hebel dreht um seinen Fuß (Bild-unten) nach oben auf.
func _build_lever(rect: Rect2) -> void:
	var foot := Vector2(rect.get_center().x, rect.end.y - 0.35)
	var reach := (rect.end.y - 0.35) - (rect.position.y + KNOB_RADIUS)
	StationParts.box(self, "HebelLager", Vector3(0.6, 0.4, 0.6), _at(foot, 0.2), _mat["gold"])
	_lever = Node3D.new()
	_lever.name = "Hebel"
	_lever.position = _at(foot, LEVER_HEIGHT)
	add_child(_lever)
	StationParts.box(_lever, "Stange", Vector3(reach - 0.15, 0.22, 0.26), Vector3((reach - 0.15) * 0.5, 0, 0),
		_mat["gold"])
	StationParts.cyl(_lever, "Knauf", KNOB_RADIUS, 0.3, Vector3(reach, 0, 0), _mat["lacquer"], 32)
	_knob_light = StationParts.cyl(_lever, "KnaufLicht", KNOB_RADIUS * 0.66, 0.34, Vector3(reach, 0, 0),
		_mat["emerald"], 32)

func _build_chip(rect: Rect2, cells: Array, expected: Rect2) -> void:
	var c := rect.get_center()
	StationParts.box(self, "Chip", Vector3(rect.size.y, CHIP_TOP, rect.size.x), _at(c, CHIP_TOP * 0.5), _mat["epoxy"])
	# Deckfläche mit Fase: ein hellerer Spiegel, der einen Rand stehen läßt.
	StationParts.box(self, "ChipSpiegel", Vector3(rect.size.y - 0.2, 0.012, rect.size.x - 0.2),
		_at(c, CHIP_TOP + 0.006), _mat["epoxy_top"])
	# Beinchen an allen vier Seiten: Schulter am Gehäuse, Fuß auf der Platine.
	var shoulders: Array[Transform3D] = []
	var feet: Array[Transform3D] = []
	var across := int(floor((rect.size.x - 0.6) / LEG_PITCH)) + 1
	var along := int(floor((rect.size.y - 0.6) / LEG_PITCH)) + 1
	for side in [-1.0, 1.0]:
		for k in along:
			var y: float = c.y + (float(k) - float(along - 1) * 0.5) * LEG_PITCH
			var edge: float = c.x + side * rect.size.x * 0.5
			shoulders.append(StationParts.cube(Vector3(0.16, 0.06, 0.16), _at(Vector2(edge + side * 0.07, y), 0.2)))
			feet.append(StationParts.cube(Vector3(0.16, 0.05, 0.24), _at(Vector2(edge + side * 0.24, y), 0.025)))
		for k in across:
			var x: float = c.x + (float(k) - float(across - 1) * 0.5) * LEG_PITCH
			var edge: float = c.y + side * rect.size.y * 0.5
			shoulders.append(StationParts.cube(Vector3(0.16, 0.06, 0.16), _at(Vector2(x, edge + side * 0.07), 0.2)))
			feet.append(StationParts.cube(Vector3(0.24, 0.05, 0.16), _at(Vector2(x, edge + side * 0.24), 0.025)))
	StationParts.swarm(self, "Schultern", shoulders, _mat["leg"])
	StationParts.swarm(self, "Beine", feet, _mat["leg"])
	# Pin-1-Mulde, Auswerfer-Marke und Laser-Beschriftung in den freien Ecken des Kreuzes.
	var corner := rect.size * 0.5 - Vector2(0.5, 0.5)
	StationParts.cyl(self, "Pin1Mulde", 0.16, 0.004, _at(c + Vector2(-corner.x, -corner.y), CHIP_TOP + 0.014),
		_mat["epoxy"], 24)
	StationParts.cyl(self, "Auswerfer", 0.22, 0.004, _at(c + Vector2(-corner.x + 0.25, corner.y - 0.2), CHIP_TOP + 0.014),
		_mat["epoxy"], 24)
	StationParts.label(self, "Beschriftung", "FMB RNG-6\n2611 A",
		_at(c + Vector2(corner.x - 0.75, -corner.y + 0.2), CHIP_TOP + 0.015), 0.22, MARKING)
	for face in LuckDie.FACES:
		var cell: Rect2 = cells[face]
		var cc := cell.get_center()
		var s := cell.size.x
		StationParts.box(self, "Fenster%d" % face, Vector3(s, 0.04, s), _at(cc, CHIP_TOP + 0.02), _mat["glass"])
		_rims.append(StationParts.swarm(self, "Saum%d" % face, _frame(cc, s + 0.1, s, CHIP_TOP + 0.045, 0.012),
			_mat["rim_off"]))
		var spots: Array[Transform3D] = []
		var face_pips: Array = []
		for spot in SPOTS:
			var p := cc + Vector2(spot.y, -spot.x) * s * PIP_SPREAD
			spots.append(StationParts.cube(Vector3(s * PIP_RADIUS * 2.6, 0.002, s * PIP_RADIUS * 2.6),
				_at(p, CHIP_TOP + 0.041)))
			face_pips.append(StationParts.cyl(self, "Auge%d_%d" % [face, face_pips.size()], s * PIP_RADIUS, 0.006,
				_at(p, CHIP_TOP + 0.045), _mat["emerald"], 16))
		StationParts.swarm(self, "Mulden%d" % face, spots, _mat["mulde"])
		_pips.append(face_pips)
	_expected = _window(expected, "Erwartung", LIGHT, CHIP_TOP)
	StationParts.label(self, "ErwartungDruck", "Ø WAHLEN",
		_at(Vector2(expected.get_center().x, expected.end.y + 0.18), CHIP_TOP + 0.003), 0.2, SILK)

## Ein Segment-Fenster: Rauchglas, darin die Zahl.
func _window(rect: Rect2, part: String, color: Color, base := 0.0) -> Label3D:
	StationParts.box(self, part + "Glas", Vector3(rect.size.y, 0.08, rect.size.x),
		_at(rect.get_center(), base + 0.04), _mat["glass"])
	var label := StationParts.label(self, part, "", _at(rect.get_center(), base + 0.085),
		rect.size.y * 0.82, color)
	label.outline_size = 8
	label.outline_modulate = color * 0.6
	return label

## Der Balken zum nächsten Auge: Zahl groß, Balken von Schwelle zu Schwelle, rechts das Auge.
func _build_gauge() -> void:
	var area := Rect2(_gauge_rect.position, Vector2(_gauge_rect.size.x, GAUGE_ROOM))
	_gauge_number = StationParts.label(self, "Zahl", "", _at(Vector2(area.get_center().x, area.position.y + 0.32), 0.003),
		0.62, LIGHT)
	_bar_span = Vector2(area.position.x + 0.15, area.end.x - 0.85)
	var mid := Vector2((_bar_span.x + _bar_span.y) * 0.5, area.position.y + 1.02)
	StationParts.box(self, "Balkenbett", Vector3(0.5, 0.1, _bar_span.y - _bar_span.x + 0.12), _at(mid, 0.05),
		_mat["lacquer"])
	_bar_fill = StationParts.box(self, "Balken", Vector3(0.34, 0.05, 1.0), _at(mid, 0.125), _mat["emerald"])
	var pip := Vector2(area.end.x - 0.4, mid.y)
	StationParts.cyl(self, "AugeMulde", 0.3, 0.02, _at(pip, 0.11), _mat["mulde"], 32)
	_next_pip = StationParts.ring(self, "AugeRing", 0.26, 0.08, _at(pip, 0.13), _mat["light"])
	_gauge_label = StationParts.label(self, "Pegel", "", _at(Vector2(area.get_center().x, area.position.y + 1.62), 0.003),
		0.3, SILK)

static func _frame(center: Vector2, outer: float, inner: float, y: float, height: float) -> Array[Transform3D]:
	return StationParts.frame_boxes(Vector2(-center.y, center.x), Vector2(outer, outer), Vector2(inner, inner),
		y, height)

# --- Zustand ------------------------------------------------------------------------------

func _write() -> void:
	if not _built:
		return
	_writes += 1
	_paint_pips()
	for face in _rims.size():
		_rims[face].material_override = _mat["light"] if face == _last_face else _mat["rim_off"]
	var sum := 0
	for v in _faces:
		sum += v
	_expected.text = "Ø " + LuckStationView.expected_digits(float(sum) / float(LuckDie.FACES))
	_write_gauge()
	var keeps := int(_state.get("keeps", 0))
	var free := int(_state.get("free_bonus", 0))
	if keeps > 0:
		_bonus_label.text = "NOCH 1 MODUL EINBAUEN" if keeps == 1 else "NOCH %d MODULE EINBAUEN" % keeps
	elif free > 0:
		_bonus_label.text = "+%d WAHL BEIM NÄCHSTEN PAKET" % free
	else:
		_bonus_label.text = ""
	_bonus_label.visible = _bonus_label.text != ""
	_sync_process()

func _write_gauge() -> void:
	var luck := int(_state.get("luck", 0))
	var next := int(_state.get("next", -1))
	var full := next < 0
	_bar_share = 1.0 if full else LuckStationView.gauge_share(_state)
	var length := (_bar_span.y - _bar_span.x) * _bar_share
	_bar_fill.visible = length > 0.001
	_bar_fill.scale = Vector3(1.0, 1.0, maxf(length, 0.001))
	_bar_fill.position = _at(Vector2(_bar_span.x + length * 0.5, _gauge_rect.position.y + 1.02), 0.125)
	_next_pip.visible = not full
	if full:
		_gauge_number.text = "GLÜCK %d" % luck
		_gauge_label.text = "ALLE SEITEN VOLL"
	else:
		_gauge_number.text = "GLÜCK %d / %d" % [luck, next]
		_gauge_label.text = "BEI %d KOMMT EIN AUGE DAZU" % next

func _paint_pips() -> void:
	for face in _pips.size():
		var on := {}
		for at: Vector2 in LuckDie.pip_layout(_faces[face] if face < _faces.size() else 0):
			on[at] = true
		var face_pips: Array = _pips[face]
		var flash := float(_flash.get(face, 0.0)) > 0.0
		for k in SPOTS.size():
			var pip: MeshInstance3D = face_pips[k]
			pip.visible = on.has(SPOTS[k])
			pip.material_override = _mat["flash"] if flash else _mat["emerald"]

func _paint_lever_lights() -> void:
	if _knob_light == null:
		return
	_knob_light.material_override = _mat["amber"] if _open else _mat["emerald"]
	_seat_ring.material_override = _mat["amber"] if _open else _mat["emerald"]
	_seat_core.visible = not _open

func _set_lever_angle(angle: float) -> void:
	if _lever != null:
		_lever.rotation.z = angle

func _sync_process() -> void:
	set_process(not _flash.is_empty())

## Ein neues Auge blitzt kurz golden auf.
func _process(delta: float) -> void:
	var done := false
	for face: int in _flash.keys():
		_flash[face] = float(_flash[face]) - delta / PIP_FLASH_TIME
		if float(_flash[face]) <= 0.0:
			_flash.erase(face)
			done = true
	if done:
		_paint_pips()
	_sync_process()
