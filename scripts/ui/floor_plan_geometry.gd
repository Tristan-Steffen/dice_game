class_name FloorPlanGeometry
extends RefCounted
## Die Geometrie EINES Grundrisses (FloorPlan.view_state bzw. snapshot) in Pixeln: Zelle →
## Pixel, Raum- und Türlagen, Treffer und der gegangene Weg. Getrennt von der Malerei -
## FloorPlanView hält eine je gezeichneter Etage.

## Anteil einer Wandkante, den eine Tür offen läßt.
const DOOR_GAP := 0.6
## So weit innen läuft der Weg im Raum an der Wand entlang (Zellen) - Namen stehen tiefer innen.
const TRAIL_INSET := 0.16
## Trefferradius einer Tür in Zellen.
const DOOR_HIT := 0.42

var plan: Dictionary = {}
## Pixel der Zellecke (0, 0) und Pixel je Zelle.
var origin := Vector2.ZERO
var cell := 1.0
var rooms: Dictionary = {}
var doors: Dictionary = {}
## Flurzelle → Abschnitt.
var corridor: Dictionary = {}

func _init(view: Dictionary = {}) -> void:
	plan = view
	for info: Dictionary in view.get("rooms", []):
		rooms[String(info["id"])] = info
	for entry: Dictionary in view.get("doors", []):
		doors[String(entry["id"])] = entry
	for info: Dictionary in view.get("corridors", []):
		for rect: Rect2i in info["rects"]:
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					corridor[Vector2i(x, y)] = String(info["id"])

# --- Zelle ↔ Pixel ---------------------------------------------------------------

## Die Zellen-Hülle des Umrisses.
func bounds_cells() -> Rect2:
	var outline: Array = plan.get("outline", [])
	if outline.is_empty():
		return Rect2(Vector2.ZERO, Vector2(FloorPlan.GRID))
	var low := Vector2(outline[0])
	var high := low
	for at: Vector2i in outline:
		low = low.min(Vector2(at))
		high = high.max(Vector2(at))
	return Rect2(low, high - low + Vector2.ONE)

## Paßt den ganzen Umriß samt Rand (in Zellen) mittig in die Fläche.
func fit(area: Rect2, pad_cells: float = 0.4) -> void:
	var box := bounds_cells().grow(pad_cells)
	var unit := maxf(0.5, minf(area.size.x / box.size.x, area.size.y / box.size.y))
	place(box.get_center(), unit, area)

## Stellt den Zellpunkt center in die Mitte der Fläche, mit unit Pixeln je Zelle.
func place(center: Vector2, unit: float, area: Rect2) -> void:
	cell = unit
	origin = area.get_center() - center * unit

func to_px(point: Vector2) -> Vector2:
	return origin + point * cell

func to_cells(pixel: Vector2) -> Vector2:
	return (pixel - origin) / cell

func rect_px(rect: Rect2) -> Rect2:
	return Rect2(to_px(rect.position), rect.size * cell)

func room_rect(room_id: String) -> Rect2:
	if not rooms.has(room_id):
		return Rect2()
	return rect_px(Rect2(rooms[room_id]["rect"]))

func elevator_rect() -> Rect2:
	var lift: Dictionary = plan.get("elevator", {})
	return rect_px(Rect2(lift["rect"])) if not lift.is_empty() else Rect2()

## Die Pixel-Hülle des ganzen Umrisses.
func bounds_px() -> Rect2:
	return rect_px(bounds_cells())

## Mitte, Richtung längs der Wand und quer dazu einer Tür in Pixeln.
func door_frame(entry: Dictionary) -> Dictionary:
	var along := Vector2(0, 1) if bool(entry["vertical"]) else Vector2(1, 0)
	return {"center": to_px(entry["center"]), "along": along, "across": Vector2(along.y, along.x)}

## Richtung (Zellen) aus der Tür in den Raum room_id hinein.
static func into_room(entry: Dictionary, room_id: String) -> Vector2:
	var side := Vector2(entry["side"])
	return -side if String(entry["a"]) == room_id else side

static func is_corridor_door(entry: Dictionary) -> bool:
	return String(entry["kind"]) != FloorPlan.DOOR_FIRE and String(entry.get("section", "")) != ""

# --- Treffer -------------------------------------------------------------------

func room_at(pixel: Vector2) -> String:
	var at := to_cells(pixel)
	for room_id: String in rooms:
		if Rect2(rooms[room_id]["rect"]).has_point(at):
			return room_id
	return ""

## Die nächste Tür im Trefferradius ("" = keine).
func door_at(pixel: Vector2) -> String:
	var best := ""
	var best_dist := DOOR_HIT * cell
	for door_id: String in doors:
		var dist := to_px(doors[door_id]["center"]).distance_to(pixel)
		if dist <= best_dist:
			best = door_id
			best_dist = dist
	return best

## {kind: "door"|"room", id} unter dem Pixel ({} = nichts); Türen vor Räumen.
func target_at(pixel: Vector2) -> Dictionary:
	var door_id := door_at(pixel)
	if door_id != "":
		return {"kind": "door", "id": door_id}
	var room_id := room_at(pixel)
	if room_id != "":
		return {"kind": "room", "id": room_id}
	return {}

# --- Ausschnitte ----------------------------------------------------------------

## Die Zellen-Hülle eines Flurabschnitts samt seiner Räume (und des Aufzugs, wenn dort).
func section_box(section_id: String) -> Rect2:
	var box := Rect2()
	var first := true
	for info: Dictionary in plan.get("corridors", []):
		if String(info["id"]) != section_id:
			continue
		for rect: Rect2i in info["rects"]:
			box = Rect2(rect) if first else box.merge(Rect2(rect))
			first = false
	for room_id: String in rooms:
		if String(rooms[room_id]["section"]) == section_id:
			box = Rect2(rooms[room_id]["rect"]) if first else box.merge(Rect2(rooms[room_id]["rect"]))
			first = false
	var lift: Dictionary = plan.get("elevator", {})
	if not lift.is_empty() and String(lift["section"]) == section_id:
		box = Rect2(lift["rect"]) if first else box.merge(Rect2(lift["rect"]))
		first = false
	return bounds_cells() if first else box

## Der Abschnitt des Standorts (der Aufzug hat seinen).
func home_section() -> String:
	var here := String(plan.get("position", ""))
	if here == "":
		var lift: Dictionary = plan.get("elevator", {})
		return String(lift.get("section", ""))
	return String(rooms.get(here, {}).get("section", ""))

## Der Standraum in Zellen (der Aufzug, solange man in ihm steht).
func home_rect_cells() -> Rect2:
	var here := String(plan.get("position", ""))
	if here == "":
		var lift: Dictionary = plan.get("elevator", {})
		return Rect2(lift["rect"]) if not lift.is_empty() else Rect2()
	return Rect2(rooms[here]["rect"]) if rooms.has(here) else Rect2()

# --- Der gegangene Weg ------------------------------------------------------------

## Der Weg in Zellkoordinaten: in Räumen nur ein Stück hinter der Tür und an der Wand
## entlang, auf dem Flur durch die Flurmitten - nie quer über einen Raumnamen.
func trail_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for step: Dictionary in plan.get("trail", []):
		var from := String(step["from"])
		var to := String(step["to"])
		if not doors.has(String(step["door"])):
			continue
		var entry: Dictionary = doors[String(step["door"])]
		var leg: Array[Vector2] = []
		if not is_corridor_door(entry) and String(entry["kind"]) != FloorPlan.DOOR_FIRE:
			leg = [_stub(entry, from), Vector2(entry["center"]), _stub(entry, to)]
		else:
			var start := _exit(from, String(step.get("section_from", "")))
			if start.is_empty():
				continue
			leg.append_array(start)
			var front := Vector2(entry["center"]) + Vector2(entry["side"]) * 0.5
			var walk := corridor_path(Vector2i(start[start.size() - 1].floor()), Vector2i(front.floor()))
			for i in range(1, walk.size()):
				leg.append(walk[i])
			if walk.size() <= 1:
				leg.append(front)
			leg.append(Vector2(entry["center"]))
			leg.append(_stub(entry, to))
		if not points.is_empty() and from != "" and rooms.has(from):
			for corner in ring_path(Rect2(rooms[from]["rect"]), points[points.size() - 1], leg[0]):
				points.append(corner)
		for point in leg:
			if points.is_empty() or not points[points.size() - 1].is_equal_approx(point):
				points.append(point)
	return points

## Punkt knapp hinter der Tür im Raum (auf dem Wandring).
func _stub(entry: Dictionary, room_id: String) -> Vector2:
	return Vector2(entry["center"]) + into_room(entry, room_id) * TRAIL_INSET

## [Stub im Raum, Türmitte, Flurmitte davor] der Tür, durch die der Standort auf den Flur tritt.
func _exit(room_id: String, section_id: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if room_id == "":
		var lift: Dictionary = plan.get("elevator", {})
		if lift.is_empty():
			return out
		var side := Vector2(lift["side"])
		var center := Vector2(lift["cell"]) + Vector2(0.5, 0.5) + side * 0.5
		out.append_array([center - side * 0.4, center, center + side * 0.5])
		return out
	var found: Dictionary = {}
	for door_id: String in doors:
		var entry: Dictionary = doors[door_id]
		if String(entry["a"]) == room_id and is_corridor_door(entry):
			if found.is_empty() or String(entry["section"]) == section_id:
				found = entry
	if found.is_empty():
		return out
	var middle := Vector2(found["center"])
	out.append_array([_stub(found, room_id), middle, middle + Vector2(found["side"]) * 0.5])
	return out

## Flurmitten von a nach b (Breitensuche über die Flurzellen), Knicke nur an Ecken.
func corridor_path(a: Vector2i, b: Vector2i) -> Array[Vector2]:
	var path: Array[Vector2] = []
	if not corridor.has(a) or not corridor.has(b):
		return path
	var came := {a: a}
	var queue: Array[Vector2i] = [a]
	while not queue.is_empty():
		var here: Vector2i = queue.pop_front()
		if here == b:
			break
		for side: Vector2i in FloorPlan.SIDES:
			var next := here + side
			if corridor.has(next) and not came.has(next):
				came[next] = here
				queue.append(next)
	if not came.has(b):
		return path
	var cells: Array[Vector2i] = [b]
	while cells[0] != a:
		cells.insert(0, came[cells[0]])
	for i in cells.size():
		var point := Vector2(cells[i]) + Vector2(0.5, 0.5)
		if i > 0 and i < cells.size() - 1:
			var before := cells[i] - cells[i - 1]
			var after := cells[i + 1] - cells[i]
			if before == after:
				continue
		path.append(point)
	return path

## Ecken des Wandrings (Raum um TRAIL_INSET eingerückt) auf dem kürzeren Weg von p nach q.
static func ring_path(room_cells: Rect2, p: Vector2, q: Vector2) -> Array[Vector2]:
	var ring := room_cells.grow(-TRAIL_INSET)
	var w := ring.size.x
	var h := ring.size.y
	var total := 2.0 * (w + h)
	var corners: Array[Vector2] = [ring.position, Vector2(ring.end.x, ring.position.y), ring.end,
		Vector2(ring.position.x, ring.end.y)]
	var marks: Array[float] = [0.0, w, w + h, 2.0 * w + h]
	var tp := _ring_param(ring, p)
	var tq := _ring_param(ring, q)
	var forward := fposmod(tq - tp, total)
	var out: Array[Vector2] = []
	if forward <= total * 0.5:
		for k in 4:
			var d := fposmod(marks[k] - tp, total)
			if d > 0.001 and d < forward - 0.001:
				out.append(corners[k])
		out.sort_custom(func(x: Vector2, y: Vector2) -> bool:
			return fposmod(_ring_param(ring, x) - tp, total) < fposmod(_ring_param(ring, y) - tp, total))
	else:
		var backward := total - forward
		for k in 4:
			var d := fposmod(tp - marks[k], total)
			if d > 0.001 and d < backward - 0.001:
				out.append(corners[k])
		out.sort_custom(func(x: Vector2, y: Vector2) -> bool:
			return fposmod(tp - _ring_param(ring, x), total) < fposmod(tp - _ring_param(ring, y), total))
	return out

## Lage eines Punkts auf dem Ring im Uhrzeigersinn ab der linken oberen Ecke.
static func _ring_param(ring: Rect2, point: Vector2) -> float:
	var p := point.clamp(ring.position, ring.end)
	var w := ring.size.x
	var h := ring.size.y
	var d_top := absf(p.y - ring.position.y)
	var d_right := absf(p.x - ring.end.x)
	var d_bottom := absf(p.y - ring.end.y)
	var d_left := absf(p.x - ring.position.x)
	var nearest := minf(minf(d_top, d_right), minf(d_bottom, d_left))
	if nearest == d_top:
		return p.x - ring.position.x
	if nearest == d_right:
		return w + (p.y - ring.position.y)
	if nearest == d_bottom:
		return w + h + (ring.end.x - p.x)
	return 2.0 * w + h + (ring.end.y - p.y)
