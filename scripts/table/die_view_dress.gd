class_name DieViewDress
extends Node3D
## Die BAUTEILE der Gleichung: Namensschilder, Nummern und Bereitschaft am Speicher, der
## gemeinsame Kragen um Kammer und ORIGINAL samt Wanne des Netzes, die Chips von ORIGINAL,
## die Blende um ERGEBNIS, die Koppler "+" und "=" auf zwei Schienen, Abtastring und
## Oben-Marke. Alles kommt als Display-Pixel herein (spec), `to_world` rechnet um. seat()
## ist der EINE Schreiber, mark_up() führt nur die Oben-Marke. Der Knoten bleibt im
## Ursprung - die Hebebühne der Zone fährt ihn als Ganzes.

## So tief liegt das Netz von ORIGINAL unter dem Tisch.
const TRAY_DROP := 0.85
const FLAT := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
const SILK := Color(0.72, 0.78, 0.84)
const STANDBY := Color(0.45, 0.28, 0.06)
const IDLE := Color(0.22, 0.25, 0.3)
const BUS := Color(0.3, 0.8, 0.9)
const RESULT := Color(0.35, 0.95, 0.6)
const BEZEL := Color(0.07, 0.075, 0.09)
const SEAM := Color(1.0, 0.7, 0.15)
const COLLAR_OUT := 0.3
const BEZEL_OUT := 0.34
const PLATE_HEIGHT := 0.05
const TEXT_SHARE := 0.15
const COUPLER_SHARE := 0.6
const RING_SHARE := 0.98
const MARK_HEIGHT := 0.15
const FEED_HEIGHT := 0.2

var _to_world: Callable
var _k := 1.0
var _sink := 0.0
var _key: Array = []
var _parts: Node3D
var _mark: Node3D
var _mark_cells: Array[Vector3] = []
var _mark_face := -1
static var _inks := {}

## spec: up, chips[6], seats[6], tints[6], mouth, net, cell, result, signs[2], stamp,
## live, seated, ring_on, ring (Weltpunkt des schwebenden Würfels), edge (Würfelkante, Welt).
func seat(spec: Dictionary, to_world: Callable, floor_skin: Material) -> void:
	var key := [spec]
	if key == _key and _parts != null and is_instance_valid(_parts):
		return
	_key = [spec.duplicate(true)]
	_to_world = to_world
	_k = absf(_w(Vector2(100, 0)).z - _w(Vector2.ZERO).z) / 100.0
	if _parts != null and is_instance_valid(_parts):
		remove_child(_parts)
		_parts.queue_free()
	_parts = Node3D.new()
	_parts.name = "Teile"
	add_child(_parts)
	_mark = null
	var cell: float = spec["cell"]
	_build_storage(spec, cell)
	_build_hull(spec, floor_skin)
	_build_original(spec, cell)
	_build_result(spec, cell)
	_build_flow(spec, cell)
	_ring(spec["stamp"], 0.12, ChipFrameView.collar(-0.14, 0.0, 0.09, 0.04), _steel())
	var face := _mark_face
	_mark_face = -2
	mark_up(face)

## Die OBEN-MARKE: der Goldrahmen um die Seite, die am Würfel oben liegt (-1 = keine).
func mark_up(face: int) -> void:
	if face == _mark_face:
		return
	_mark_face = face
	if _mark == null or not is_instance_valid(_mark):
		return
	_mark.visible = face >= 0 and face < _mark_cells.size()
	if _mark.visible:
		_mark.position = _mark_cells[face]

func marked_face() -> int:
	return _mark_face

func part_count() -> int:
	return _parts.get_child_count() if _parts != null and is_instance_valid(_parts) else 0

## Der Ursprung eines Kreuzes im Rechteck seines Schirms (mittig).
static func net_origin(rect: Rect2, cell: float) -> Vector2:
	return rect.position + ((rect.size - DieNetView.net_size(cell)) * 0.5).max(Vector2.ZERO)

## Das Schild im Kreuz: die freie Ecke unten links (Zeile 2, Spalte 0).
static func plate_rect(origin: Vector2, cell: float, row: int) -> Rect2:
	var step := cell * (1.0 + DieNetView.GAP_FACTOR)
	return Rect2(origin + Vector2(0, step * float(row)), Vector2.ONE * cell).grow(-cell * 0.04)

## SPEICHER: Namensschild mit Füllstand, je Zelle Nummer und Bereitschafts-Lampe.
func _build_storage(spec: Dictionary, cell: float) -> void:
	var chips: Array = spec["chips"]
	if chips.is_empty():
		return
	var tints: Array = spec["tints"]
	var origin: Vector2 = (chips[3] as Rect2).position - DieNetView.cell_position(3, cell)
	var plate := plate_rect(origin, cell, 0)
	_plate(plate, "UPGRADES", cell, -cell * 0.14)
	for i in 6:
		var at := plate.get_center() + Vector2((float(i) - 2.5) * cell * 0.13, cell * 0.2)
		_box(Rect2(at - Vector2.ONE * cell * 0.04, Vector2.ONE * cell * 0.08), 0.02, PLATE_HEIGHT,
			_ink(_lit(tints, i, STANDBY.darkened(0.4))))
	var seats: Array = spec["seats"]
	for i in seats.size():
		var holder: Rect2 = seats[i]
		var top := i < 3
		_text(str(i + 1), Vector2(holder.end.x + cell * 0.09,
			holder.position.y + cell * 0.1 if top else holder.end.y - cell * 0.1),
			cell * _k * 0.2, SILK)
		var led := Vector2(holder.position.x - cell * 0.07,
			holder.end.y - cell * 0.05 if top else holder.position.y + cell * 0.05)
		_box(Rect2(led - Vector2.ONE * cell * 0.035, Vector2.ONE * cell * 0.07), 0.03, 0.0,
			_ink(_lit(tints, i, STANDBY)))
	_outline((spec["up"] as Rect2).grow(3.0))

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
	_parts.add_child(floor_quad)
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

## ORIGINAL auf dem Wannenboden: Chips am Flächen-Bus, Stecker, Fassung der Seele, Schild.
func _build_original(spec: Dictionary, cell: float) -> void:
	var net: Rect2 = spec["net"]
	var o := net_origin(net, cell)
	var span := DieNetView.net_size(cell)
	var step := cell * (1.0 + DieNetView.GAP_FACTOR)
	var gap := cell * DieNetView.GAP_FACTOR
	_sink = TRAY_DROP
	var spots: Array[Vector3] = []
	_mark_cells.clear()
	for face in 6:
		var at := _w(o + DieNetView.cell_position(face, cell) + Vector2.ONE * cell * 0.5)
		spots.append(Vector3(at.x, 0.0, at.z))
		_mark_cells.append(at)
	var bank := StorageBankView.new()
	bank.name = "OriginalChips"
	_parts.add_child(bank)
	bank.position.y = -TRAY_DROP
	bank.seat_chips(spots, cell * _k, cell * _k * DieNetView.GAP_FACTOR * 0.22)
	var bus := _ink(BUS if spec["seated"] else IDLE)
	var right := o.x + span.x + gap
	var head := Rect2(Vector2(o.x + step * 2.0 + cell * 0.2, o.y + cell * 0.3),
		Vector2(cell * 1.7, cell * 0.34))
	for row in 2:
		var y := o.y + cell + gap * 0.5 + step * float(row)
		_seg(Vector2(net.position.x, y), Vector2(net.end.x, y), 1.8, bus)
	_seg(Vector2(right, o.y + step + cell + gap * 0.5), Vector2(right, head.get_center().y), 1.8,
		bus)
	_seg(Vector2(right, head.get_center().y), Vector2(head.end.x, head.get_center().y), 1.8, bus)
	_box(head, 0.14, 0.0, ChipFrameView._skin(BEZEL, 0.15))
	var gold := ChipFrameView._skin(ChipFrameView.GOLD, 0.2, 0.3)
	for pin in 6:
		var at := Vector2(head.position.x + head.size.x * (float(pin) + 0.5) / 6.0,
			head.get_center().y)
		_box(Rect2(at - Vector2.ONE * cell * 0.045, Vector2.ONE * cell * 0.09), 0.05, 0.14, gold)
	var soul := o + Vector2.ONE * cell * 0.5
	var reach := cell * 0.42
	var rhomb := [soul + Vector2(0, -reach), soul + Vector2(reach, 0), soul + Vector2(0, reach),
		soul + Vector2(-reach, 0)]
	for i in 4:
		_bar(_parts, rhomb[i], rhomb[(i + 1) % 4], cell * 0.05, 0.08,
			ChipFrameView._skin(StorageBankView.RIM_STEEL, 0.3))
	_plate(plate_rect(o, cell, 2), "ORIGINAL", cell, 0.0)
	# Die Oben-Marke: ein Rahmen um den Ursprung, mark_up() stellt ihn auf seine Zelle.
	_mark = Node3D.new()
	_mark.name = "ObenMarke"
	_mark.visible = false
	_parts.add_child(_mark)
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
	_parts.add_child(ring)

## ERGEBNIS: die dunkle Blende mit Lichtlippe und das Schild.
func _build_result(spec: Dictionary, cell: float) -> void:
	var rect: Rect2 = spec["result"]
	_ring(rect, 0.3, ChipFrameView.collar(-BEZEL_OUT, 0.05, 0.17, 0.07),
		ChipFrameView._skin(BEZEL, 0.15))
	_ring(rect, 0.3, [Vector2(0.05, 0.02), Vector2(0.05, 0.075)],
		ChipFrameView._skin(RESULT, 0.0, 0.5))
	_plate(plate_rect(net_origin(rect, cell), cell, 2), "ERGEBNIS", cell, 0.0)

## Zwei SCHIENEN vom Speicher an die Wanne und von ihr an die Blende; "+" und "=" sitzen
## als Koppler dazwischen.
func _build_flow(spec: Dictionary, cell: float) -> void:
	var up: Rect2 = spec["up"]
	var net: Rect2 = spec["net"]
	var res: Rect2 = spec["result"]
	var chips: Array = spec["chips"]
	var live: bool = spec["live"]
	var step := cell * (1.0 + DieNetView.GAP_FACTOR)
	var gap := cell * DieNetView.GAP_FACTOR
	var o := net_origin(net, cell)
	var u_y := o.y
	if not chips.is_empty():
		u_y = ((chips[3] as Rect2).position - DieNetView.cell_position(3, cell)).y
	var sum := _ink(BUS if live else IDLE)
	var out := _ink(RESULT if live else IDLE)
	for row in 2:
		var lane := cell + gap * 0.5 + step * float(row)
		var from := Vector2(up.end.x, u_y + lane)
		var to := Vector2(net.position.x - COLLAR_OUT / _k, o.y + lane)
		var jog := absf(from.y - to.y)
		var knee := (from.x + to.x) * 0.5
		_wire([from, Vector2(knee - jog * 0.5, from.y), Vector2(knee + jog * 0.5, to.y), to], sum)
		_wire([Vector2(net.end.x + COLLAR_OUT / _k, to.y),
			Vector2(res.position.x - BEZEL_OUT / _k, to.y)], out)
		_feed(Vector2(net.position.x, to.y), -1.0, cell, sum)
		_feed(Vector2(net.end.x, to.y), 1.0, cell, out)
	var signs: Array = spec["signs"]
	for i in signs.size():
		var c := Vector2((signs[i] as Rect2).get_center().x, o.y + step + cell * 0.5)
		var side := cell * COUPLER_SHARE
		_box(Rect2(c - Vector2.ONE * side * 0.5, Vector2.ONE * side), 0.16, 0.03,
			ChipFrameView._skin(BEZEL, 0.15))
		for s: float in [-1.0, 1.0]:
			for j in 3:
				var leg := Vector2(c.x + float(j - 1) * side * 0.3, c.y + s * side * 0.6)
				_box(Rect2(leg - Vector2(side * 0.05, side * 0.11),
					Vector2(side * 0.1, side * 0.22)), 0.05, 0.0, _steel())
		var tint := SILK
		if live:
			tint = Color(0.6, 0.95, 1.0) if i == 0 else Color(0.5, 1.0, 0.65)
		_text("+" if i == 0 else "=", c, side * _k, tint, 0.2)

## Die DURCHFÜHRUNG einer Schiene am Kragen: ein Block auf dem Kragen, obenauf ihr
## Licht, innen der Abgang die Wannenwand hinunter. side = -1 links, +1 rechts.
func _feed(edge: Vector2, side: float, cell: float, light: Material) -> void:
	var out := (COLLAR_OUT + 0.06) / _k
	var half := cell * 0.07
	var from := edge.x + side * out
	var to := edge.x - side * 0.1 / _k
	var block := Rect2(Vector2(minf(from, to), edge.y - half), Vector2(absf(from - to), half * 2.0))
	_box(block, FEED_HEIGHT, 0.0, ChipFrameView._skin(BEZEL, 0.15))
	_box(block.grow_individual(-1.0, -half + 0.9, -1.0, -half + 0.9), 0.012, FEED_HEIGHT, light)
	var wall := edge.x - side * 0.75
	_box(Rect2(Vector2(wall - 0.75, edge.y - 0.9), Vector2(1.5, 1.8)), TRAY_DROP, -TRAY_DROP, light)

func _plate(rect: Rect2, text: String, cell: float, shift: float) -> void:
	_box(rect, PLATE_HEIGHT, 0.0, ChipFrameView._skin(ChipFrameView.STEEL_DARK, 0.3))
	_text(text, rect.get_center() + Vector2(0, shift), cell * _k * TEXT_SHARE, SILK,
		PLATE_HEIGHT + 0.006)

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
	_solid(_parts, Vector3(rect.size.y * _k, height, rect.size.x * _k),
		_w(rect.get_center()) + Vector3.UP * (base + height * 0.5), material)

func _seg(a: Vector2, b: Vector2, width: float, material: Material) -> void:
	_box(Rect2(a, Vector2.ZERO).expand(b).grow(width * 0.5), 0.012, 0.012, material)

## Ein Steg zwischen zwei Display-Punkten, beliebig gedreht.
func _bar(parent: Node3D, a: Vector2, b: Vector2, width: float, height: float,
		material: Material) -> void:
	var from := _w(a)
	var to := _w(b)
	var body := _solid(parent, Vector3(width * _k, height, a.distance_to(b) * _k),
		Vector3.ZERO, material)
	body.transform = Transform3D(Basis.looking_at((to - from).normalized(), Vector3.UP),
		(from + to) * 0.5 + Vector3.UP * height * 0.5)

func _wire(points: Array, material: Material) -> void:
	for i in points.size() - 1:
		if (points[i] as Vector2).distance_to(points[i + 1]) > 0.01:
			_bar(_parts, points[i], points[i + 1], 1.8, 0.012, material)

func _ring(rect: Rect2, radius: float, profile: Array, material: Material) -> void:
	var body := MeshInstance3D.new()
	body.mesh = ChipFrameView.ring_mesh(Vector2(rect.size.y, rect.size.x) * 0.5 * _k, radius,
		profile)
	body.material_override = material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.position = _w(rect.get_center())
	_parts.add_child(body)

## Der Umriß eines Geräts als Bestückungsdruck.
func _outline(rect: Rect2) -> void:
	var ink := _ink(SILK.darkened(0.45))
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		_box(Rect2(corners[i], Vector2.ZERO).expand(corners[(i + 1) % 4]).grow(1.0), 0.006, 0.003,
			ink)

func _text(text: String, at: Vector2, height: float, color: Color, lift := 0.02) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = height / 64.0
	label.outline_size = 0
	label.modulate = color
	label.shaded = false
	label.transform = Transform3D(FLAT, _w(at) + Vector3.UP * lift)
	_parts.add_child(label)
