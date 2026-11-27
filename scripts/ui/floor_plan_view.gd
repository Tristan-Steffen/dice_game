class_name FloorPlanView
extends Control
## Zeichnet den GRUNDRISS einer Etage aus FloorPlan.view_state(): dunkler Grund, Außenwand,
## Innenwände, Flure, Räume in ihrer Themenfarbe, Türen in der Tür-Skala, Brandschutztüren,
## Aufzug, Büro, Schlüsselkarte und der Standraum. Reine Malerei, keine Eingabe.

const BACKGROUND := Color("#0c0f15")
const CORRIDOR := Color("#262d3b")
const OUTER_WALL := Color("#eef1f6")
const INNER_WALL := Color("#7d889a")
const LIFT_FLOOR := Color("#161b25")
const LIFT_LINE := Color("#55607a")
const TEXT := Color("#e8ebf1")
const TEXT_DIM := Color("#9aa3b3")
const YOU := Color.WHITE
const FIRE_RED := Color("#e0352b")
const BOSS_RED := Color("#ff3b30")
const KEY_CARD := Color("#f4f1e4")
## Raumtür-Stufen: offen, leicht, mittel, schwer - eine eigene Skala, nicht die Raumfarben.
const DOOR_TIER_COLORS := [Color("#d6dbe4"), Color("#8fa3bf"), Color("#e0a840"), Color("#ff7a2e")]

## Anteil einer Wandkante, den eine Tür offen läßt.
const DOOR_GAP := 0.6
const OUTER_WIDTH := 0.11
const INNER_WIDTH := 0.04
const ROOM_ALPHA := 0.2
const OFFICE_ALPHA := 0.32
const NAME_SIZE := 0.3
const BONUS_SIZE := 0.22
const PAD := 0.14

var state: Dictionary = {}
## Rand um den Umriß in Pixeln.
var margin := 24.0

func show_state(view: Dictionary) -> void:
	state = view
	queue_redraw()

# --- Geometrie (Zelle → Pixel) --------------------------------------------------

## Die Zellen-Hülle des Umrisses.
func bounds_cells() -> Rect2:
	var outline: Array = state.get("outline", [])
	if outline.is_empty():
		return Rect2(Vector2.ZERO, Vector2(FloorPlan.GRID))
	var low := Vector2(outline[0])
	var high := low
	for cell: Vector2i in outline:
		low = low.min(Vector2(cell))
		high = high.max(Vector2(cell))
	return Rect2(low, high - low + Vector2.ONE)

## Pixel je Zelle, so daß der Umriß samt Rand ins Control paßt.
func cell_px() -> float:
	var box := bounds_cells()
	var room := size - Vector2(margin, margin) * 2.0
	return maxf(1.0, minf(room.x / box.size.x, room.y / box.size.y))

func origin_px() -> Vector2:
	var box := bounds_cells()
	var unit := cell_px()
	return (size - box.size * unit) * 0.5 - box.position * unit

func to_px(point: Vector2) -> Vector2:
	return origin_px() + point * cell_px()

func rect_px(rect: Rect2i) -> Rect2:
	return Rect2(to_px(Vector2(rect.position)), Vector2(rect.size) * cell_px())

func room_center_px(room_id: String) -> Vector2:
	if room_id == "":
		var lift: Dictionary = state.get("elevator", {})
		return rect_px(lift["rect"]).get_center() if not lift.is_empty() else Vector2.ZERO
	for info: Dictionary in state.get("rooms", []):
		if info["id"] == room_id:
			return rect_px(info["rect"]).get_center()
	return Vector2.ZERO

## Mitte, Richtung längs der Wand und quer dazu einer Tür in Pixeln.
func door_frame(entry: Dictionary) -> Dictionary:
	var along := Vector2(0, 1) if bool(entry["vertical"]) else Vector2(1, 0)
	return {"center": to_px(entry["center"]), "along": along, "across": Vector2(along.y, along.x)}

# --- Malerei --------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if state.is_empty():
		return
	var unit := cell_px()
	for info: Dictionary in state["corridors"]:
		for rect: Rect2i in info["rects"]:
			draw_rect(rect_px(rect), CORRIDOR)
	_draw_elevator(unit)
	for info: Dictionary in state["rooms"]:
		_draw_room_floor(info)
	_draw_trail(unit)
	for wall: Dictionary in state["walls"]:
		var width := (OUTER_WIDTH if wall["outer"] else INNER_WIDTH) * unit
		var color := OUTER_WALL if wall["outer"] else INNER_WALL
		var a := to_px(wall["a"])
		var b := to_px(wall["b"])
		draw_line(a, b, color, width)
		if wall["outer"]:
			draw_rect(Rect2(a - Vector2.ONE * width * 0.5, Vector2.ONE * width), color)
			draw_rect(Rect2(b - Vector2.ONE * width * 0.5, Vector2.ONE * width), color)
	for entry: Dictionary in state["doors"]:
		_draw_door(entry, unit)
	for info: Dictionary in state["rooms"]:
		_draw_room_marks(info, unit)

func _draw_elevator(unit: float) -> void:
	var lift: Dictionary = state.get("elevator", {})
	if lift.is_empty():
		return
	var box := rect_px(lift["rect"])
	draw_rect(box, LIFT_FLOOR)
	var steps := 6
	for i in range(1, steps):
		var y := box.position.y + box.size.y * i / steps
		draw_line(Vector2(box.position.x + unit * 0.12, y), Vector2(box.end.x - unit * 0.12, y), LIFT_LINE, 1.5)
	var mid := box.get_center()
	var tip := mid - Vector2(0, unit * 0.45)
	draw_colored_polygon(PackedVector2Array([tip, mid + Vector2(-unit * 0.3, -unit * 0.05),
		mid + Vector2(unit * 0.3, -unit * 0.05)]), TEXT)
	draw_line(mid, mid + Vector2(0, unit * 0.4), TEXT, unit * 0.1)
	_text(FloorPlan.ELEVATOR_NAME, Vector2(box.position.x + unit * 0.1, box.end.y - unit * 0.12),
		unit * BONUS_SIZE, TEXT_DIM, box.size.x)

func _draw_room_floor(info: Dictionary) -> void:
	var box := rect_px(info["rect"])
	var color: Color = info["color"]
	if bool(info["visited"]) and not bool(info["current"]):
		color = color.lerp(Color(color.get_luminance(), color.get_luminance(), color.get_luminance()), 0.7)
	color.a = OFFICE_ALPHA if bool(info["is_office"]) else ROOM_ALPHA
	draw_rect(box, color)

func _draw_room_marks(info: Dictionary, unit: float) -> void:
	var box := rect_px(info["rect"]).grow(-unit * PAD)
	var color: Color = info["color"]
	var name_size := unit * NAME_SIZE
	var dot := unit * 0.09
	draw_circle(box.position + Vector2(dot, name_size * 0.62), dot, color.lightened(0.25))
	var title_x := box.position.x + dot * 2.8
	var title: String = info["name"]
	var head := TEXT if not bool(info["is_office"]) else BOSS_RED.lightened(0.3)
	_text(title, Vector2(title_x, box.position.y + name_size), name_size, head, box.end.x - title_x)
	var line := String(info["bonus_name"])
	if bool(info["is_office"]) and not bool(state.get("key_taken", false)):
		line = "Schlüsselkarte fehlt"
	if bool(info["visited"]) and not bool(info["is_office"]):
		line = "besucht"
	if line != "":
		_text(line, Vector2(box.position.x, box.position.y + name_size * 1.25 + unit * BONUS_SIZE),
			unit * BONUS_SIZE, TEXT_DIM, box.size.x)
	if bool(info["has_key"]):
		_draw_key_card(Vector2(box.end.x - unit * 0.5, box.end.y - unit * 0.34), unit)
	if bool(info["current"]):
		draw_rect(rect_px(info["rect"]).grow(-unit * 0.08), YOU, false, unit * 0.08)
	elif bool(info["reachable"]):
		draw_rect(rect_px(info["rect"]).grow(-unit * 0.08), Color(1, 1, 1, 0.45), false, unit * 0.035)

func _draw_key_card(at: Vector2, unit: float) -> void:
	var card := Rect2(at, Vector2(unit * 0.46, unit * 0.3))
	draw_rect(card, KEY_CARD)
	draw_rect(Rect2(card.position + Vector2(0, card.size.y * 0.2), Vector2(card.size.x, card.size.y * 0.18)),
		Color("#2b3240"))
	draw_rect(Rect2(card.position + Vector2(card.size.x * 0.12, card.size.y * 0.55),
		Vector2(card.size.x * 0.22, card.size.y * 0.3)), Color("#c9a84a"))

func _draw_door(entry: Dictionary, unit: float) -> void:
	var frame := door_frame(entry)
	var c: Vector2 = frame["center"]
	var along: Vector2 = frame["along"]
	var across: Vector2 = frame["across"]
	var half := unit * DOOR_GAP * 0.5
	match String(entry["kind"]):
		FloorPlan.DOOR_FIRE:
			_draw_fire_door(c, along, unit)
		FloorPlan.DOOR_BOSS:
			draw_line(c - along * half, c + along * half, BOSS_RED, unit * 0.12)
			draw_rect(Rect2(c - Vector2.ONE * unit * 0.07, Vector2.ONE * unit * 0.14), Color("#2a0d0b"))
		_:
			if bool(entry["passed"]):
				var hinge := c - along * half
				draw_line(hinge, hinge + across * half * 2.0, YOU, unit * 0.04)
				draw_arc(hinge, half * 2.0, across.angle() - 0.0, across.angle() + PI * 0.5 * signf(along.x + along.y),
					10, Color(1, 1, 1, 0.45), 1.0)
				return
			var tier := int(entry["tier"])
			var color: Color = DOOR_TIER_COLORS[clampi(tier, 0, DOOR_TIER_COLORS.size() - 1)]
			if tier <= FloorPlan.TIER_FREE:
				draw_arc(c - along * half, half * 2.0, along.angle(), along.angle() + PI * 0.5, 10,
					Color(color, 0.35), 1.0)
				return
			draw_line(c - along * half, c + along * half, color, unit * 0.05)
			for i in tier:
				var at := c + along * half * ((i + 1.0) / (tier + 1.0) * 2.0 - 1.0)
				draw_line(at - across * unit * 0.1, at + across * unit * 0.1, color, unit * 0.05)

## Zweiflügelig quer über den Flur, rot-weiß gesäumt.
func _draw_fire_door(c: Vector2, along: Vector2, unit: float) -> void:
	var half := unit * 0.5
	var a := c - along * half
	var b := c + along * half
	draw_line(a, b, FIRE_RED, unit * 0.13)
	draw_line(a, b, Color.WHITE, unit * 0.035)
	draw_line(c - along * unit * 0.02, c + along * unit * 0.02, BACKGROUND, unit * 0.14)
	for end in [a, b]:
		draw_rect(Rect2(end - Vector2.ONE * unit * 0.07, Vector2.ONE * unit * 0.14), FIRE_RED)

## Der gegangene Weg als weiße Linie durch Türen und Brandschutztüren.
func _draw_trail(unit: float) -> void:
	var trail: Array = state.get("trail", [])
	if trail.is_empty():
		return
	var points := PackedVector2Array()
	for point in trail_points():
		points.append(to_px(point))
	draw_polyline(points, Color(1, 1, 1, 0.55), unit * 0.04, true)

## Der gegangene Weg in Zellkoordinaten: Raummitte → Tür → Flur (mit Knick im Flur) → Tür → Raummitte.
func trail_points() -> Array[Vector2]:
	var doors := {}
	for entry: Dictionary in state["doors"]:
		doors[entry["id"]] = entry
	var corridor := {}
	for info: Dictionary in state["corridors"]:
		for rect: Rect2i in info["rects"]:
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					corridor[Vector2i(x, y)] = true
	var points: Array[Vector2] = []
	for step: Dictionary in state.get("trail", []):
		var from := String(step["from"])
		var leg: Array[Vector2] = [_room_center_cells(from)]
		var leaving := String(step.get("section_from", ""))
		var exit := _exit_door(from, leaving) if leaving != "" else []
		if not exit.is_empty():
			leg.append(exit[0])
			leg.append(exit[1])
		if String(step["fire_door"]) != "":
			leg.append(doors[step["fire_door"]]["center"])
		var entry: Dictionary = doors[step["door"]]
		if bool(is_corridor_door(entry)):
			leg.append(Vector2(entry["center"]) + Vector2(entry["side"]) * 0.5)
		leg.append(entry["center"])
		leg.append(_room_center_cells(String(step["to"])))
		for point in leg:
			if not points.is_empty():
				var last: Vector2 = points[points.size() - 1]
				if not is_equal_approx(last.x, point.x) and not is_equal_approx(last.y, point.y):
					var bend := Vector2(point.x, last.y)
					if not corridor.has(Vector2i(bend.floor())):
						bend = Vector2(last.x, point.y)
					points.append(bend)
			points.append(point)
	return points

static func is_corridor_door(entry: Dictionary) -> bool:
	return String(entry["kind"]) != FloorPlan.DOOR_FIRE and FloorPlan.is_section(String(entry["b"]))

## [Türmitte, Flurpunkt davor] der Tür, durch die der Standort auf den Flur tritt ([] = keine).
func _exit_door(room_id: String, section_id: String) -> Array:
	if room_id == "":
		var lift: Dictionary = state.get("elevator", {})
		if lift.is_empty():
			return []
		var center := Vector2(lift["cell"]) + Vector2(0.5, 0.5) + Vector2(lift["side"]) * 0.5
		return [center, center + Vector2(lift["side"]) * 0.5]
	for entry: Dictionary in state["doors"]:
		if entry["a"] == room_id and entry["b"] == section_id and is_corridor_door(entry):
			return [Vector2(entry["center"]), Vector2(entry["center"]) + Vector2(entry["side"]) * 0.5]
	return []

func _room_center_cells(room_id: String) -> Vector2:
	if room_id == "":
		var lift: Dictionary = state.get("elevator", {})
		return Rect2(lift["rect"]).get_center() if not lift.is_empty() else Vector2.ZERO
	for info: Dictionary in state.get("rooms", []):
		if info["id"] == room_id:
			return Rect2(info["rect"]).get_center()
	return Vector2.ZERO

func _text(text: String, at: Vector2, font_px: float, color: Color, width: float) -> void:
	var font := ThemeDB.fallback_font
	var px := int(font_px)
	while px > 7 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		px -= 1
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
