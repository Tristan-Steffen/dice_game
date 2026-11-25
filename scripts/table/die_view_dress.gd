class_name DieViewDress
extends Node3D
## Die BAUTEILE der Gleichung (Layout E): VORSCHAU und UPGRADES als CHIPS (Epoxid-Gehäuse
## mit Beinchen an allen vier Seiten, je Seite des Würfels ein Fenster auf das Bild der
## Anzeige), der UMSCHALTER im "+"-Feld, die zwei Busse, das Podest (Kragen um Kammer und
## Die-View samt Wanne, Abtastring, Oben-Marke) und der Schutzschalter des Prägens.
## Alles kommt als Display-Pixel herein (spec), `to_world` rechnet um. seat() ist der EINE
## Schreiber der Teile; Umschalter und Zone haben je einen Setter, der nur den
## Wechsel schreibt. Podest und Schalter liegen in der Öffnungs-Zone und fahren mit ihrer
## Hebebühne (zone_bodies()); Vorschau, UPGRADES, Umschalter und Busse stehen.

## So hoch steht das Gehäuse eines Chips über dem Tisch (die Energiezellen liegen darauf).
const CHIP_HEIGHT := 0.14
const EPOXY := Color(0.075, 0.08, 0.092)
const EPOXY_TOP := Color(0.105, 0.11, 0.124)
const LEG_PITCH := 0.38
## So tief liegt das Netz von ORIGINAL unter dem Tisch.
const TRAY_DROP := 0.85
const FLAT := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
const SILK := Color(0.72, 0.78, 0.84)
const STANDBY := Color(0.45, 0.28, 0.06)
const BUS := Color(0.3, 0.8, 0.9)
const BEZEL := Color(0.07, 0.075, 0.09)
const SEAM := Color(1.0, 0.7, 0.15)
const COLLAR_OUT := 0.3
const COVER_OPEN := 1.26
const COVER_TIME := 0.3
const COVER_LIFT := 0.2
const GUARD := Color(1.0, 0.78, 0.25, 0.1)
const GUARD_SPENT := Color(1.0, 0.2, 0.15, 0.24)
const LAMP_READY := Color(0.35, 0.95, 0.6)
const LAMP_SPENT := Color(0.95, 0.22, 0.18)
const TEXT_SHARE := 0.15
## Der UMSCHALTER: ein Chip mittig im "+"-Feld, so tief wie dieser Anteil des Felds und
## COUPLER_ASPECT mal so breit.
const COUPLER_DEEP := 0.86
const COUPLER_ASPECT := 1.7
## AN leuchtet er cyan, AUS ist er grau; unter dem Zeiger hebt und hellt er sich.
const COUPLER_ON := Color(0.35, 0.9, 1.0)
const COUPLER_OFF := Color(0.1, 0.15, 0.19)
const COUPLER_SIGN_ON := Color(0.6, 0.95, 1.0)
const COUPLER_SIGN_OFF := Color(0.36, 0.4, 0.45)
const COUPLER_HOVER_LIFT := 0.08
const COUPLER_HOVER_LIGHT := 0.3
## Die BUSSE: Träger und Spuren als flache Körper; eine Spur leuchtet in ihrer Sortenfarbe.
const BUS_LANE_SHARE := 0.6
const BUS_HEIGHT := 0.05
const BUS_IDLE := Color(0.2, 0.26, 0.28)
const RING_SHARE := 0.98
const MARK_HEIGHT := 0.15

var _to_world: Callable
var _k := 1.0
var _sink := 0.0
var _key: Array = []
var _parts: Node3D
## Das PODEST: fährt mit der Zone.
var _podium: Node3D
## Wohin _box/_text/_ring gerade bauen.
var _host: Node3D
var _ring_node: Node3D
var _coupler: Node3D
var _coupler_frame: Array[MeshInstance3D] = []
var _coupler_sign: Label3D
var _coupler_state := [true, false]
var _zone_shown := true
var _mark: Node3D
var _mark_cells: Array[Vector3] = []
var _mark_face := -1
var _switch: Node3D
var _switch_key: Array = []
var _cover: Node3D
var _cover_pane: MeshInstance3D
var _lamp: MeshInstance3D
var _cover_closed := false
var _cover_tween: Tween
static var _inks := {}
static var _glasses := {}

## spec: up, chips[6], seats[6], tints[6], mouth, net, cell, signs[1], stamp, preview,
## entries/feeds (Bus-Spuren, je eine Polylinie), bus_tints (je Spur, Alpha 0 = dunkel),
## pitch (Spur-Teilung), seated, ring_on, ring (Weltpunkt des schwebenden Würfels),
## edge (Würfelkante, Welt).
func seat(spec: Dictionary, to_world: Callable, floor_skin: Material) -> void:
	var key := [spec]
	if key == _key and _parts != null and is_instance_valid(_parts):
		return
	_key = [spec.duplicate(true)]
	_to_world = to_world
	_k = absf(_w(Vector2(100, 0)).z - _w(Vector2.ZERO).z) / 100.0
	for old: Node3D in [_parts, _podium]:
		if old != null and is_instance_valid(old):
			remove_child(old)
			old.queue_free()
	_parts = Node3D.new()
	_parts.name = "Teile"
	add_child(_parts)
	_podium = Node3D.new()
	_podium.name = "Podestteile"
	add_child(_podium)
	_mark = null
	_ring_node = null
	_coupler = null
	_coupler_frame.clear()
	var cell: float = spec["cell"]
	_host = _parts
	_build_storage(spec, cell)
	_build_preview(spec, cell)
	_build_flow(spec, cell)
	_build_buses(spec)
	_host = _podium
	_build_hull(spec, floor_skin)
	_build_original(spec, cell)
	_host = _parts
	_seat_switch(spec["stamp"], spec.get("spent", false), spec.get("armed", false))
	_apply_coupler()
	_apply_zone_shown()
	var face := _mark_face
	_mark_face = -2
	mark_up(face)

## Der UMSCHALTER: on = ERGEBNIS. AN leuchten Rahmen und Zeichen, AUS sind sie grau; unter
## dem Zeiger hebt und hellt er sich.
func set_coupler(on: bool, hovered: bool) -> void:
	var state := [on, hovered]
	if state == _coupler_state:
		return
	_coupler_state = state
	_apply_coupler()

func coupler_on() -> bool:
	return bool(_coupler_state[0])

func coupler_lifted() -> bool:
	return _coupler != null and is_instance_valid(_coupler) and _coupler.position.y > 0.001

func _apply_coupler() -> void:
	if _coupler == null or not is_instance_valid(_coupler):
		return
	var on: bool = _coupler_state[0]
	var hovered: bool = _coupler_state[1]
	var frame := COUPLER_ON if on else COUPLER_OFF
	var sign := COUPLER_SIGN_ON if on else COUPLER_SIGN_OFF
	if hovered:
		frame = frame.lightened(COUPLER_HOVER_LIGHT)
		sign = sign.lightened(COUPLER_HOVER_LIGHT)
	for bar in _coupler_frame:
		bar.material_override = _ink(frame)
	if _coupler_sign != null and is_instance_valid(_coupler_sign):
		_coupler_sign.modulate = sign
	_coupler.position.y = COUPLER_HOVER_LIFT if hovered else 0.0

## Die Lichtfarbe des Umschalters.
func coupler_light() -> Color:
	if _coupler_frame.is_empty():
		return Color.BLACK
	return (_coupler_frame[0].material_override as StandardMaterial3D).albedo_color

## Podest und Schalter des Prägens stehen nur, solange keine Paket-Öffnung ihren Platz hat.
func set_zone_shown(shown: bool) -> void:
	if shown == _zone_shown:
		return
	_zone_shown = shown
	_apply_zone_shown()

func _apply_zone_shown() -> void:
	for node: Node3D in zone_bodies():
		node.visible = _zone_shown

## Was mit der Hebebühne der Zone fährt.
func zone_bodies() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node: Node3D in [_podium, _switch]:
		if node != null and is_instance_valid(node):
			out.append(node)
	return out

## Die OBEN-MARKE: der Goldrahmen um die Seite, die am Würfel oben liegt (-1 = keine).
func mark_up(face: int) -> void:
	if face == _mark_face:
		return
	_mark_face = face
	if _mark == null or not is_instance_valid(_mark):
		return
	if face >= 0 and face < _mark_cells.size():
		_mark.position = _mark_cells[face]
	_mark.visible = face >= 0 and face < _mark_cells.size()

func marked_face() -> int:
	return _mark_face

func part_count() -> int:
	var count := 0
	for node: Node3D in [_parts, _podium]:
		if node != null and is_instance_valid(node):
			count += node.get_child_count()
	return count

## Der Ursprung eines Kreuzes im Rechteck seines Schirms (mittig).
static func net_origin(rect: Rect2, cell: float) -> Vector2:
	return rect.position + ((rect.size - DieNetView.net_size(cell)) * 0.5).max(Vector2.ZERO)

## Eine freie Kreuz-Ecke links (Zeile row, Spalte 0).
static func plate_rect(origin: Vector2, cell: float, row: int) -> Rect2:
	var step := cell * (1.0 + DieNetView.GAP_FACTOR)
	return Rect2(origin + Vector2(0, step * float(row)), Vector2.ONE * cell).grow(-cell * 0.04)

## SPEICHER: der Chip UPGRADES - sechs Fenster, obenauf der Füllstand, je Energiezelle
## Nummer und Bereitschafts-Lampe (oben 1-2-3, unten 4-5-6).
func _build_storage(spec: Dictionary, cell: float) -> void:
	var chips: Array = spec["chips"]
	if chips.is_empty():
		return
	var tints: Array = spec["tints"]
	var holes: Array[Rect2] = []
	for chip: Rect2 in chips:
		holes.append(chip)
	_chip("UpgradesChip", (spec["up"] as Rect2).grow(3.0), holes)
	var origin: Vector2 = (chips[3] as Rect2).position - DieNetView.cell_position(3, cell)
	var plate := plate_rect(origin, cell, 0)
	var stored := 0
	for tint: Color in tints:
		if tint.a > 0.0:
			stored += 1
	_etch(plate, "%d/%d" % [stored, tints.size()], cell, -cell * 0.14)
	for i in tints.size():
		var at := plate.get_center() + Vector2((float(i) - float(tints.size() - 1) * 0.5)
			* cell * 0.1, cell * 0.2)
		_box(Rect2(at - Vector2.ONE * cell * 0.04, Vector2.ONE * cell * 0.08), 0.02,
			CHIP_HEIGHT + 0.012, _ink(_lit(tints, i, STANDBY.darkened(0.4))))
	var seats: Array = spec["seats"]
	for i in seats.size():
		var holder: Rect2 = seats[i]
		var top := i < WorkshopView.StorageBody.ROW_CELLS
		_text(str(i + 1), Vector2(holder.end.x + cell * 0.09,
			holder.position.y + cell * 0.1 if top else holder.end.y - cell * 0.1),
			cell * _k * 0.2, SILK, CHIP_HEIGHT + 0.02)
		var led := Vector2(holder.position.x - cell * 0.07,
			holder.end.y - cell * 0.05 if top else holder.position.y + cell * 0.05)
		_box(Rect2(led - Vector2.ONE * cell * 0.035, Vector2.ONE * cell * 0.07), 0.03,
			CHIP_HEIGHT + 0.012, _ink(_lit(tints, i, STANDBY)))

## Ein CHIP über einem Display-Rechteck: Epoxid mit hellerem Spiegel, Fenster (holes) auf
## das Bild der Anzeige, Beinchen an allen vier Seiten, Pin-1-Mulde unten links.
func _chip(part: String, rect: Rect2, holes: Array[Rect2]) -> void:
	var host := Node3D.new()
	host.name = part
	_host.add_child(host)
	var body: Array[Transform3D] = []
	for piece in cut_plate(rect, holes):
		body.append(_cube(piece, CHIP_HEIGHT, 0.0))
	StationParts.swarm(host, "Gehaeuse", body, _ink(EPOXY))
	var mirror: Array[Transform3D] = []
	for piece in cut_plate(rect.grow(-0.1 / _k), holes):
		mirror.append(_cube(piece, 0.012, CHIP_HEIGHT))
	StationParts.swarm(host, "Spiegel", mirror, _ink(EPOXY_TOP))
	var c := _w(rect.get_center())
	var half := Vector2(rect.size.y, rect.size.x) * 0.5 * _k
	var legs: Array[Transform3D] = []
	for way: float in [-1.0, 1.0]:
		for k in int(floor((half.x * 2.0 - 0.5) / LEG_PITCH)) + 1:
			var x: float = c.x + (float(k) - floor((half.x * 2.0 - 0.5) / LEG_PITCH) * 0.5) * LEG_PITCH
			legs.append(StationParts.cube(Vector3(0.14, 0.05, 0.14),
				Vector3(x, CHIP_HEIGHT * 0.6, c.z + way * (half.y + 0.07))))
			legs.append(StationParts.cube(Vector3(0.14, 0.04, 0.16),
				Vector3(x, 0.02, c.z + way * (half.y + 0.2))))
		for k in int(floor((half.y * 2.0 - 0.5) / LEG_PITCH)) + 1:
			var z: float = c.z + (float(k) - floor((half.y * 2.0 - 0.5) / LEG_PITCH) * 0.5) * LEG_PITCH
			legs.append(StationParts.cube(Vector3(0.14, 0.05, 0.14),
				Vector3(c.x + way * (half.x + 0.07), CHIP_HEIGHT * 0.6, z)))
			legs.append(StationParts.cube(Vector3(0.16, 0.04, 0.14),
				Vector3(c.x + way * (half.x + 0.2), 0.02, z)))
	StationParts.swarm(host, "Beine", legs, _steel())
	StationParts.cyl(host, "Pin1Mulde", 0.1, 0.004,
		Vector3(c.x - half.x + 0.26, CHIP_HEIGHT + 0.014, c.z - half.y + 0.26), _ink(EPOXY.darkened(0.5)))

## rect ohne die Fenster, als Rechtecke (zeilenweise geschnitten).
static func cut_plate(rect: Rect2, holes: Array[Rect2]) -> Array[Rect2]:
	var ys: Array[float] = [rect.position.y, rect.end.y]
	for hole in holes:
		ys.append(clampf(hole.position.y, rect.position.y, rect.end.y))
		ys.append(clampf(hole.end.y, rect.position.y, rect.end.y))
	ys.sort()
	var out: Array[Rect2] = []
	for i in ys.size() - 1:
		var y0 := ys[i]
		var y1 := ys[i + 1]
		if y1 - y0 < 0.01:
			continue
		var mid := (y0 + y1) * 0.5
		var spans: Array[Rect2] = []
		for hole in holes:
			if hole.position.y < mid and hole.end.y > mid:
				spans.append(hole)
		spans.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
		var x := rect.position.x
		for hole in spans:
			if hole.position.x > x + 0.01:
				out.append(Rect2(x, y0, hole.position.x - x, y1 - y0))
			x = maxf(x, hole.end.x)
		if rect.end.x > x + 0.01:
			out.append(Rect2(x, y0, rect.end.x - x, y1 - y0))
	return out

func _cube(rect: Rect2, height: float, base: float) -> Transform3D:
	return StationParts.cube(Vector3(rect.size.y * _k, height, rect.size.x * _k),
		_w(rect.get_center()) + Vector3.UP * (base + height * 0.5))

## Laser-Aufschrift auf einem Chip.
func _etch(rect: Rect2, text: String, cell: float, shift: float) -> void:
	_text(text, rect.get_center() + Vector2(0, shift), cell * _k * TEXT_SHARE, SILK.darkened(0.25),
		CHIP_HEIGHT + 0.016)

static func _lit(tints: Array, index: int, idle: Color) -> Color:
	if index < tints.size() and (tints[index] as Color).a > 0.0:
		return Color(tints[index] as Color, 1.0)
	return idle

## Der Kragen um Kammer und Wanne, die Wanne selbst und die Stufe zur Kammer.
func _build_hull(spec: Dictionary, floor_skin: Material) -> void:
	var mouth: Rect2 = spec["mouth"]
	var tray := tray_rect(mouth, spec["net"])
	_ring(mouth.merge(tray), 0.06, ChipFrameView.collar(-COLLAR_OUT, 0.02, 0.14, 0.05), _steel())
	var floor_quad := MeshInstance3D.new()
	floor_quad.name = "Wannenboden"
	var plane := PlaneMesh.new()
	plane.size = Vector2(tray.size.y * _k, tray.size.x * _k)
	floor_quad.mesh = plane
	floor_quad.material_override = floor_skin
	floor_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor_quad.position = _w(tray.get_center()) + Vector3.DOWN * TRAY_DROP
	_podium.add_child(floor_quad)
	var wall := ChipFrameView._skin(ChipFrameView.STEEL_DARK, 0.2)
	var thick := 0.12 / _k
	var sides := [
		Rect2(Vector2(tray.position.x - thick, tray.position.y), Vector2(thick, tray.size.y)),
		Rect2(Vector2(tray.end.x, tray.position.y), Vector2(thick, tray.size.y))]
	var runs := sides + [
		Rect2(Vector2(tray.position.x, tray.end.y), Vector2(tray.size.x, thick)),
		Rect2(Vector2(tray.position.x, tray.position.y - thick),
			Vector2(maxf(mouth.position.x - tray.position.x, 0.0), thick)),
		Rect2(Vector2(mouth.end.x, tray.position.y - thick),
			Vector2(maxf(tray.end.x - mouth.end.x, 0.0), thick))]
	for run: Rect2 in runs:
		if run.size.x > 0.01:
			_box(run, TRAY_DROP, -TRAY_DROP - 0.02, wall)
	var seam := _ink(BUS)
	for side: Rect2 in sides:
		var x := side.end.x if side.position.x < tray.position.x else side.position.x - 1.2
		_box(Rect2(Vector2(x, side.position.y), Vector2(1.2, side.size.y)), 0.03, -0.12, seam)
	# Die Stufe: die Kammerwand zur Wanne endet auf Wannenhöhe.
	_box(Rect2(Vector2(mouth.position.x, mouth.end.y), Vector2(mouth.size.x, 0.1 / _k)),
		0.3, -TRAY_DROP - 0.3, wall)

## Die Wanne des Netzes: unter der Kammer, so breit wie die Die-View.
static func tray_rect(mouth: Rect2, net: Rect2) -> Rect2:
	return Rect2(Vector2(net.position.x, mouth.end.y),
		Vector2(net.size.x, net.end.y - mouth.end.y))

## ORIGINAL auf dem Wannenboden: Stecker und Fassung der Seele.
func _build_original(spec: Dictionary, cell: float) -> void:
	var net: Rect2 = spec["net"]
	var o := net_origin(net, cell)
	var step := cell * (1.0 + DieNetView.GAP_FACTOR)
	_sink = TRAY_DROP
	_mark_cells.clear()
	for face in 6:
		_mark_cells.append(_w(o + DieNetView.cell_position(face, cell) + Vector2.ONE * cell * 0.5))
	var head := Rect2(Vector2(o.x + step * 2.0 + cell * 0.2, o.y + cell * 0.3),
		Vector2(cell * 1.7, cell * 0.34))
	_box(head, 0.14, 0.0, ChipFrameView._skin(BEZEL, 0.15))
	var gold := ChipFrameView._skin(ChipFrameView.GOLD, 0.2, 0.3)
	for pin in 6:
		var at := Vector2(head.position.x + head.size.x * (float(pin) + 0.5) / 6.0,
			head.get_center().y)
		_box(Rect2(at - Vector2.ONE * cell * 0.045, Vector2.ONE * cell * 0.09), 0.05, 0.14, gold)
	_rhomb(o + Vector2.ONE * cell * 0.5, cell)
	# Die Oben-Marke: ein Rahmen um den Ursprung, mark_up() stellt ihn auf seine Zelle.
	_mark = Node3D.new()
	_mark.name = "ObenMarke"
	_mark.visible = false
	_podium.add_child(_mark)
	var half := cell * 0.53 * _k
	var mark_gold := ChipFrameView._skin(ChipFrameView.GOLD, 0.2, 0.6)
	for side: float in [-1.0, 1.0]:
		_solid(_mark, Vector3(cell * 0.07 * _k, MARK_HEIGHT, half * 2.0),
			Vector3(side * half, MARK_HEIGHT * 0.5, 0.0), mark_gold)
		_solid(_mark, Vector3(half * 2.0, MARK_HEIGHT, cell * 0.07 * _k),
			Vector3(0.0, MARK_HEIGHT * 0.5, side * half), mark_gold)
	_sink = 0.0
	if not spec["ring_on"]:
		return
	# Der Abtastring um den schwebenden Würfel.
	var hover: Vector3 = spec["ring"]
	var ring := MeshInstance3D.new()
	ring.name = "Abtastring"
	var torus := TorusMesh.new()
	torus.outer_radius = float(spec["edge"]) * RING_SHARE
	torus.inner_radius = torus.outer_radius - 0.05
	ring.mesh = torus
	ring.material_override = _ink(BUS)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = hover
	_podium.add_child(ring)
	_ring_node = ring

## Die Fassung der Seele: eine Stahl-Raute um den Platz oben links im Kreuz.
func _rhomb(soul: Vector2, cell: float) -> void:
	var reach := cell * 0.42
	var rhomb := [soul + Vector2(0, -reach), soul + Vector2(reach, 0), soul + Vector2(0, reach),
		soul + Vector2(-reach, 0)]
	for i in 4:
		_bar(_podium, rhomb[i], rhomb[(i + 1) % 4], cell * 0.05, 0.08,
			ChipFrameView._skin(StorageBankView.RIM_STEEL, 0.3))

## Der SCHUTZSCHALTER des Prägens: Sockel um den Knopf der Anzeige, hinten das Scharnier,
## darüber die Klappe (offen = frei, zu und rot = die Prägung ist verbraucht), rechts die
## Lampe. Er überlebt den Neubau der Teile; nur der Platz baut ihn neu.
func _seat_switch(rect: Rect2, spent: bool, armed: bool) -> void:
	var key := [rect, _k]
	if key != _switch_key or _switch == null or not is_instance_valid(_switch):
		_switch_key = key
		_build_switch(rect)
		_cover_closed = spent
		_cover.rotation.z = 0.0 if spent else -COVER_OPEN
	elif spent != _cover_closed:
		_cover_closed = spent
		if _cover_tween != null:
			_cover_tween.kill()
		var angle := 0.0 if spent else -COVER_OPEN
		if is_inside_tree():
			_cover_tween = create_tween()
			_cover_tween.tween_property(_cover, "rotation:z", angle, COVER_TIME).set_trans(
				Tween.TRANS_SINE)
		else:
			_cover.rotation.z = angle
	_cover_pane.material_override = _glass(GUARD_SPENT if spent else GUARD)
	_lamp.material_override = _ink(LAMP_SPENT if spent else (LAMP_READY if armed else STANDBY))

func cover_closed() -> bool:
	return _cover_closed

func _build_switch(rect: Rect2) -> void:
	if _switch != null and is_instance_valid(_switch):
		remove_child(_switch)
		_switch.queue_free()
	_switch = Node3D.new()
	_switch.name = "Schalter"
	add_child(_switch)
	var c: Vector3 = _to_world.call(rect.get_center())
	c.y = 0.0
	var half := Vector2(rect.size.y, rect.size.x) * 0.5 * _k
	var dark := ChipFrameView._skin(ChipFrameView.STEEL_DARK, 0.3)
	var base := MeshInstance3D.new()
	base.name = "Sockel"
	base.mesh = ChipFrameView.ring_mesh(half, 0.12,
		ChipFrameView.collar(-0.22, 0.0, COVER_LIFT - 0.03, 0.05))
	base.material_override = dark
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	base.position = c
	_switch.add_child(base)
	var hinge := c.x + half.x + 0.14
	_solid(_switch, Vector3(0.08, 0.08, half.y * 1.7), Vector3(hinge, COVER_LIFT, c.z), _steel())
	for side: float in [-1.0, 1.0]:
		_solid(_switch, Vector3(0.2, COVER_LIFT + 0.06, 0.24),
			Vector3(hinge, (COVER_LIFT + 0.06) * 0.5, c.z + side * half.y * 0.6), dark)
	_cover = Node3D.new()
	_cover.name = "Klappe"
	_cover.position = Vector3(hinge, COVER_LIFT + 0.02, c.z)
	_switch.add_child(_cover)
	var reach := half.x * 2.0 + 0.3
	var wide := half.y * 2.0 + 0.3
	for side: float in [-1.0, 1.0]:
		_solid(_cover, Vector3(reach, 0.05, 0.08), Vector3(-reach * 0.5, 0.0, side * wide * 0.5),
			_steel())
	_solid(_cover, Vector3(0.08, 0.05, wide), Vector3(-reach, 0.0, 0.0), _steel())
	_solid(_cover, Vector3(0.08, 0.05, wide), Vector3(-0.04, 0.0, 0.0), _steel())
	_solid(_cover, Vector3(0.14, 0.05, wide * 0.3), Vector3(-reach - 0.1, 0.0, 0.0), _steel())
	_cover_pane = _solid(_cover, Vector3(reach, 0.02, wide), Vector3(-reach * 0.5, 0.0, 0.0),
		_glass(GUARD))
	_cover_pane.name = "Scheibe"
	var lamp_at := Vector3(c.x, 0.0, c.z + half.y + 0.55)
	_solid(_switch, Vector3(0.3, 0.06, 0.3), lamp_at + Vector3.UP * 0.03, dark)
	_lamp = _solid(_switch, Vector3(0.18, 0.04, 0.18), lamp_at + Vector3.UP * 0.08, _ink(STANDBY))
	_lamp.name = "Lampe"

static func _glass(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if not _glasses.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = color
		_glasses[key] = material
	return _glasses[key]

## VORSCHAU: ein Chip wie UPGRADES - sechs Fenster und das der Seele. Er steht neben der
## Zone und bleibt bei jeder Öffnung.
func _build_preview(spec: Dictionary, cell: float) -> void:
	var rect: Rect2 = spec.get("preview", Rect2())
	if rect.size.x <= 0.0:
		return
	var o := net_origin(rect, cell)
	var holes: Array[Rect2] = [Rect2(o, Vector2.ONE * cell)]
	for face in 6:
		holes.append(Rect2(o + DieNetView.cell_position(face, cell), Vector2.ONE * cell))
	_chip("VorschauChip", rect.grow(3.0), holes)

## Der UMSCHALTER füllt das "+"-Feld zwischen der Die-View des Podests und UPGRADES.
func _build_flow(spec: Dictionary, cell: float) -> void:
	var signs: Array = spec["signs"]
	if signs.is_empty():
		return
	_build_coupler(signs[0])

## Der Umschalter, ein eigener Knoten (er hebt sich): ein Chip mit Lichtrahmen und "+".
func _build_coupler(field: Rect2) -> void:
	_coupler = Node3D.new()
	_coupler.name = "Koppler"
	_host.add_child(_coupler)
	var at := _w(field.get_center())
	var deep := field.size.y * COUPLER_DEEP * _k
	var wide := minf(deep * COUPLER_ASPECT, field.size.x * _k)
	var case := _solid(_coupler, Vector3(deep, 0.16, wide), at + Vector3.UP * 0.08,
		ChipFrameView._skin(BEZEL, 0.15))
	case.name = "Gehaeuse"
	var bar := deep * 0.09
	var w := wide * 0.9
	var d := deep * 0.84
	_coupler_frame.clear()
	for e: float in [-1.0, 1.0]:
		_coupler_frame.append(_solid(_coupler, Vector3(bar, 0.03, w),
			at + Vector3(e * (d - bar) * 0.5, 0.175, 0.0), _ink(COUPLER_OFF)))
		_coupler_frame.append(_solid(_coupler, Vector3(d - bar * 2.0, 0.03, bar),
			at + Vector3(0.0, 0.175, e * (w - bar) * 0.5), _ink(COUPLER_OFF)))
	_coupler_sign = Label3D.new()
	_coupler_sign.name = "Zeichen"
	_coupler_sign.text = "+"
	_coupler_sign.font_size = 64
	_coupler_sign.pixel_size = d * 0.95 / 64.0
	_coupler_sign.outline_size = 0
	_coupler_sign.shaded = false
	_coupler_sign.transform = Transform3D(FLAT, at + Vector3.UP * 0.18)
	_coupler.add_child(_coupler_sign)

## Die BUSSE als Körper: je Bus ein dunkler Träger, darauf je Spur ein Steg (leuchtend in
## ihrer Sortenfarbe, sonst matt) und Gold-Pads an beiden Enden. Der Ausgangs-Bus endet am
## "+"-Feld; sein letztes Stück bis in die Wanne gehört dem Podest (es fährt mit der Zone)
## samt der DURCHFÜHRUNG am Kragen.
func _build_buses(spec: Dictionary) -> void:
	var pitch: float = spec.get("pitch", 0.0)
	if pitch <= 0.0:
		return
	var tints: Array = spec.get("bus_tints", [])
	_bus("EingangsBus", spec.get("entries", []), tints, pitch, -1.0)
	var signs: Array = spec["signs"]
	var cut: float = (signs[0] as Rect2).position.y if not signs.is_empty() else -1.0
	_bus("AusgangsBus", spec.get("feeds", []), tints, pitch, cut)
	if cut < 0.0:
		return
	_host = _podium
	var net: Rect2 = spec["net"]
	var tops: Array = []
	for path: PackedVector2Array in spec.get("feeds", []):
		if path.size() >= 2:
			tops.append(PackedVector2Array([Vector2(path[0].x, cut), Vector2(path[0].x,
				net.end.y)]))
	_bus("AusgangsBusOben", tops, tints, pitch, -1.0)
	if not tops.is_empty():
		var first: PackedVector2Array = tops[0]
		var last: PackedVector2Array = tops[tops.size() - 1]
		var gland := Rect2(Vector2(first[0].x - pitch, net.end.y - pitch * 0.6),
			Vector2(last[0].x - first[0].x + pitch * 2.0, pitch * 1.6))
		_box(gland, 0.14, 0.0, ChipFrameView._skin(ChipFrameView.STEEL_DARK, 0.3))
	_host = _parts

## Ein Bus aus waagerechten bzw. senkrechten Spuren; cut >= 0 kappt senkrechte Spuren oben
## auf dieser Höhe (Display-y).
func _bus(part: String, paths: Array, tints: Array, pitch: float, cut: float) -> void:
	if paths.is_empty():
		return
	var host := Node3D.new()
	host.name = part
	_host.add_child(host)
	var keep := _host
	_host = host
	var lane_w := pitch * BUS_LANE_SHARE
	var carrier := Rect2()
	var runs: Array[Rect2] = []
	for i in paths.size():
		var path: PackedVector2Array = paths[i]
		if path.size() < 2:
			continue
		var a := path[0]
		var b := path[path.size() - 1]
		if cut >= 0.0:
			if a.y < b.y:
				a.y = maxf(a.y, cut)
			else:
				b.y = maxf(b.y, cut)
		var run := Rect2(a, Vector2.ZERO).expand(b).grow(lane_w * 0.5)
		runs.append(run)
		carrier = run if carrier.size == Vector2.ZERO else carrier.merge(run)
	if runs.is_empty():
		_host = keep
		return
	_box(carrier.grow(pitch * 0.35), BUS_HEIGHT * 0.5, 0.0, _ink(BEZEL))
	var gold := ChipFrameView._skin(ChipFrameView.GOLD, 0.2, 0.3)
	for i in runs.size():
		var tint: Color = tints[i] if i < tints.size() else Color(0, 0, 0, 0)
		var lit := tint.a > 0.0
		_box(runs[i], BUS_HEIGHT, BUS_HEIGHT * 0.5,
			_ink(Color(tint, 1.0) if lit else BUS_IDLE))
		var vertical := runs[i].size.y > runs[i].size.x
		for end in 2:
			var pad := Rect2(runs[i].position, Vector2.ONE * lane_w * 1.6)
			if vertical:
				pad.position = Vector2(runs[i].get_center().x - lane_w * 0.8,
					runs[i].position.y if end == 0 else runs[i].end.y - lane_w * 1.6)
			else:
				pad.position = Vector2(runs[i].position.x if end == 0 else runs[i].end.x
					- lane_w * 1.6, runs[i].get_center().y - lane_w * 0.8)
			_box(pad, 0.012, BUS_HEIGHT * 1.5, gold)
	_host = keep

func _w(p: Vector2) -> Vector3:
	var at: Vector3 = _to_world.call(p)
	return Vector3(at.x, -_sink, at.z)

static func _steel() -> ShaderMaterial:
	return ChipFrameView._skin(ChipFrameView.STEEL, 0.4)

static func _ink(color: Color) -> StandardMaterial3D:
	var key := color.to_html(false)
	if not _inks.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		_inks[key] = material
	return _inks[key]

static func _solid(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	body.mesh = mesh
	body.material_override = material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.position = at
	parent.add_child(body)
	return body

## Ein Quader über einem Display-Rechteck: height hoch, Unterkante auf base.
func _box(rect: Rect2, height: float, base: float, material: Material) -> void:
	_solid(_host, Vector3(rect.size.y * _k, height, rect.size.x * _k),
		_w(rect.get_center()) + Vector3.UP * (base + height * 0.5), material)

## Ein Steg zwischen zwei Display-Punkten, beliebig gedreht.
func _bar(parent: Node3D, a: Vector2, b: Vector2, width: float, height: float,
		material: Material) -> void:
	var from := _w(a)
	var to := _w(b)
	var body := _solid(parent, Vector3(width * _k, height, a.distance_to(b) * _k),
		Vector3.ZERO, material)
	body.transform = Transform3D(Basis.looking_at((to - from).normalized(), Vector3.UP),
		(from + to) * 0.5 + Vector3.UP * height * 0.5)

func _ring(rect: Rect2, radius: float, profile: Array, material: Material) -> void:
	var body := MeshInstance3D.new()
	body.mesh = ChipFrameView.ring_mesh(Vector2(rect.size.y, rect.size.x) * 0.5 * _k, radius,
		profile)
	body.material_override = material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.position = _w(rect.get_center())
	_host.add_child(body)

func _text(text: String, at: Vector2, height: float, color: Color, lift := 0.02) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = height / 64.0
	label.outline_size = 0
	label.modulate = color
	label.shaded = false
	label.transform = Transform3D(FLAT, _w(at) + Vector3.UP * lift)
	_host.add_child(label)
	return label
