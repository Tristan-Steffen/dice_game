class_name LedStripView
extends Control
## Eine LICHT-ADER auf dem Deck: ein Bündel Kupferzüge unter Lötstopplack, Gold-Pads an
## den Enden der Haupt-Ader, und KNOTEN, wo ein Bündel auf eine Schiene trifft. Lichtläufe (TracePulseView) fahren als
## Datenpakete über strip_path.

const TRACKS := 3
const RAIL_TRACKS := 2

## Mittellinie der Leiste (Screen-px, achsenparallele L-Führung ab Hub-Oberkante).
var strip_path := PackedVector2Array()
## Abzweig (T-Stück) aus dem Korridor zu einem weiteren Fenster; rein dekorativ -
## Lichtläufe (Kometen) fahren nur strip_path.
var branch_path := PackedVector2Array()
## Beliebig viele weitere Adern in DIESEM Knoten (Sammelschienen + Stichleitungen
## des Kombi-Chip-Netzes); ebenfalls rein zeichnend.
var rail_paths: Array[PackedVector2Array] = []
## Einspurige Stiche von Geräte-Pins auf eine Schiene, Gold-Pad am Pin (erster Punkt).
var stub_paths: Array[PackedVector2Array] = []
var _thickness := 9.0
## Falsch: die Ader trägt nur Kometen-Routen, ihr Bild malt ein gemeinsamer Bus.
var drawn := true:
	set(value):
		drawn = value
		queue_redraw()
## KONTAKTFELDER, auf denen Geräte stehen: Goldrahmen, Kontaktreihe vorn.
var contacts: Array[Rect2] = []
## Abzweige von strip_path als genormte T-Stücke: [Knoten auf der Mittellinie, Richtung
## des Abzweigs, sein freies Ende].
var taps: Array = []
## KNOTEN, an denen ein Bündel auf eine Schiene dieses Knotens trifft (zusätzlich zu den
## T-Stücken der Haupt-Ader): {at (Mitte der Schiene), dir (zum Abzweig), reach, branch, rail}.
var junctions: Array = []
## Wie weit die gezeichnete Haupt-Ader am Anfang gekürzt ist - dort beginnt ein Knoten
## einer anderen Ader. Die Kometen-Route bleibt ungekürzt.
var trim_start := 0.0
## Der Zug liegt als Kupfer unter grünem Lötstopplack (Spieler-Wahl 2026-11-24, „Maske“).
const TRACE := Color(0.075, 0.27, 0.18)
const CROWN := Color(0.13, 0.39, 0.26)
const WIDTH := 4.2
const CLEAR := 2.0
const PAD := Color(0.5, 0.385, 0.16)
## Abstand von der Schienen-Mitte, an dem ein Knoten-Abzweig beginnt.
const JUNCTION_REACH := 4.4
## Radius eines Triebs (in Teilungen) - kleiner als die Teilung, damit er vor dem nächsten
## Schienenzug ansetzt - und seine Stützpunkte.
const SHOOT_RADIUS := 0.72
const SHOOT_STEPS := 8

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Grund-Führung: senkrechter Austritt an (exit_x, from_edge_y), waagerecht durch
## den gemeinsamen Korridor lane_y, senkrecht in (enter_x, to_edge_y). Richtungs-
## agnostisch - der Korridor darf über ODER unter der Quelle liegen (Pit->Score,
## Kombis->Score von unten; Charm-Dock->Score von oben). So kreuzt die Ader kein
## Fenster, solange lane_y in der Lücke zwischen Quell- und Zielkante liegt.
func link_edges(from_edge_y: float, exit_x: float, to_edge_y: float, enter_x: float, lane_y: float, width: float) -> void:
	_thickness = width
	strip_path = PackedVector2Array([
		Vector2(exit_x, from_edge_y), Vector2(exit_x, lane_y),
		Vector2(enter_x, lane_y), Vector2(enter_x, to_edge_y)])
	branch_path = PackedVector2Array()
	queue_redraw()

## Gerade waagerechte Ader zwischen zwei SEITEN-Kanten (Hub -> Werkstatt) - die
## einzige Verbindung ohne Korridor, weil beide Fenster auf gleicher Höhe liegen.
func link_horizontal(from_x: float, to_x: float, y: float, width: float) -> void:
	_thickness = width
	strip_path = PackedVector2Array([Vector2(from_x, y), Vector2(to_x, y)])
	branch_path = PackedVector2Array()
	queue_redraw()

## Freie Führung über beliebige Stützpunkte.
func link_path(points: PackedVector2Array, width: float) -> void:
	_thickness = width
	strip_path = points
	branch_path = PackedVector2Array()
	queue_redraw()

## Ein BUS: die Schiene path, Abzweige als T-Stücke, dazu die Kontaktfelder der Geräte.
func link_bus(path: PackedVector2Array, bus_taps: Array, pads: Array[Rect2], width: float) -> void:
	_thickness = width
	strip_path = path
	branch_path = PackedVector2Array()
	taps = bus_taps
	contacts = pads
	queue_redraw()

## Bequem-Wrapper: Hub-OBERKANTE -> Ziel-UNTERKANTE (Eintritt mittig), wie bisher.
func link_from_hub_top(hub_rect: Rect2, target_rect: Rect2, width: float, exit_x: float, lane_y: float) -> void:
	link_edges(hub_rect.position.y, exit_x, target_rect.end.y, target_rect.get_center().x, lane_y, width)

## Zweigt an der Korridor-Ecke (unter dem Hauptziel) ab: waagerecht weiter bis
## unter target, senkrecht in dessen UNTERKANTE. Erst nach link_from_hub_top rufen.
func fork_to(target_rect: Rect2) -> void:
	if strip_path.size() < 4:
		return
	var from := strip_path[2]
	var enter_x := target_rect.get_center().x
	branch_path = PackedVector2Array([
		from, Vector2(enter_x, from.y), Vector2(enter_x, target_rect.end.y)])
	queue_redraw()

## Legt ein ganzes Adernetz (Schienen + Pin-Stiche) in EINEN Knoten - ohne
## Haupt-Ader: Kometen fahren hier über wiring_paths_to_cell, nicht über
## strip_path.
func link_rails(paths: Array[PackedVector2Array], width: float,
		stubs: Array[PackedVector2Array] = []) -> void:
	_thickness = width
	strip_path = PackedVector2Array()
	branch_path = PackedVector2Array()
	rail_paths = paths
	stub_paths = stubs
	queue_redraw()


## Knoten einer Schiene dieses Knotens (siehe junctions).
func set_junctions(list: Array) -> void:
	junctions = list
	queue_redraw()

func _draw() -> void:
	if not drawn:
		return
	var paths: Array[PackedVector2Array] = []
	var main := _drawn_strip()
	for path in [main, branch_path]:
		if path.size() >= 2:
			paths.append(path)
	for rail in rail_paths:
		if rail.size() >= 2:
			paths.append(rail)
	for stub in stub_paths:
		if stub.size() >= 2:
			paths.append(stub)
	var knots := _all_junctions()
	for pad in contacts:
		_draw_contact(pad)
	# Freistellung im Kupfer, dann die Züge, zuletzt die Knoten.
	for path in paths:
		for line in track_lines(path, tracks_of(path)):
			draw_polyline(line, PcbDeckView.MOAT, WIDTH + CLEAR * 2.0, true)
	for knot in knots:
		for line in knot_lines(knot):
			draw_polyline(line, PcbDeckView.MOAT, WIDTH + CLEAR * 2.0, true)
	for path in paths:
		var count := tracks_of(path)
		for line in track_lines(path, count):
			_draw_raised(line)
		var lines := track_lines(path, count)
		for line in lines:
			if path == main:
				if trim_start <= 0.0:
					_draw_pad(line[0], line[1])
				_draw_pad(line[line.size() - 1], line[line.size() - 2])
			elif count == 1:
				_draw_pad(line[0], line[1])
	for knot in knots:
		_draw_knot_top(knot)

## Die gezeichnete Haupt-Ader: am Anfang um trim_start gekürzt.
func _drawn_strip() -> PackedVector2Array:
	if trim_start <= 0.0 or strip_path.size() < 2:
		return strip_path
	var out := PackedVector2Array()
	var left := trim_start
	for i in strip_path.size() - 1:
		var a := strip_path[i]
		var b := strip_path[i + 1]
		var seg := a.distance_to(b)
		if left >= seg and out.is_empty():
			left -= seg
			continue
		if out.is_empty():
			out.append(a.lerp(b, left / seg))
		out.append(b)
	return out

## Züge je Ader: Stiche tragen einen, die Schienen des Kombi-Netzes zwei, alles andere drei.
func tracks_of(path: PackedVector2Array) -> int:
	if stub_paths.has(path):
		return 1
	return RAIL_TRACKS if rail_paths.has(path) else TRACKS

static func _offset_of(k: int, count: int) -> float:
	return (float(k) - float(count - 1) * 0.5) * PcbDeckView.PITCH

static func track_lines(path: PackedVector2Array, count: int) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var half := float(count - 1) * PcbDeckView.PITCH * 0.5
	for k in count:
		var line := PcbDeckView.track_line(path, _offset_of(k, count), half)
		if line.size() >= 2:
			out.append(line)
	return out

## Ein Zug unter dem Lack: Grundfarbe, darauf ein schmaler heller Grat.
func _draw_raised(line: PackedVector2Array) -> void:
	draw_polyline(line, TRACE, WIDTH, true)
	draw_polyline(line, CROWN, WIDTH * 0.32, true)

func _draw_pad(at: Vector2, toward: Vector2) -> void:
	var dir := (toward - at).normalized()
	var reach := minf(12.0, at.distance_to(toward))
	draw_line(at + dir, at + dir * reach, PAD, WIDTH + 2.4)

func _draw_contact(rect: Rect2) -> void:
	var plate := StyleBoxFlat.new()
	plate.bg_color = PcbDeckView.LACQUER
	plate.set_corner_radius_all(10)
	plate.set_border_width_all(5)
	plate.border_color = PcbDeckView.GOLD
	draw_style_box(plate, rect)
	# Kontaktreihe an der Vorderkante, wo die Ader abgeht.
	var y := rect.end.y - 12.0
	var x := rect.position.x + 22.0
	while x < rect.end.x - 26.0:
		draw_rect(Rect2(x, y - 4.0, 9.0, 8.0), PcbDeckView.GOLD)
		x += 17.0

#region Die KNOTEN
## Alle Knoten dieses Knotens: die T-Stücke der Haupt-Ader und die gemeldeten.
func _all_junctions() -> Array:
	var out: Array = []
	for tap in taps:
		var center: Vector2 = tap[0]
		out.append({"at": center, "dir": (tap[1] as Vector2).normalized(),
			"reach": center.distance_to(tap[2]), "branch": TRACKS, "rail": TRACKS})
	out.append_array(junctions)
	return out

## DER RUNDBOGEN-KNOTEN: jeder ankommende Zug läuft gerade durch das Bündel bis zum fernsten
## Schienenzug und schickt an JEDEM Schienenzug einen Trieb im Viertelkreis hinein - die Züge
## links der Achse nach links, rechts nach rechts, der mittlere nach beiden Seiten. So ist der
## Knoten zur Abzweig-Achse symmetrisch, und ein Kreuz sind zwei gespiegelte Knoten.
static func knot_lines(knot: Dictionary) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var center: Vector2 = knot["at"]
	var dir: Vector2 = knot["dir"]
	var reach: float = knot["reach"]
	var branch: int = knot["branch"]
	var rail: int = knot["rail"]
	var side := Vector2(-dir.y, dir.x)
	var pitch := PcbDeckView.PITCH
	var near := float(rail - 1) * 0.5 * pitch
	var radius := pitch * SHOOT_RADIUS
	for k in branch:
		var lateral := _offset_of(k, branch)
		var axis := center + side * lateral
		out.append(PackedVector2Array([axis + dir * reach, axis + dir * (-near + radius)]))
		var bends: Array[float] = [-1.0, 1.0]
		if absf(lateral) >= 0.5:
			bends = [signf(lateral)]
		for j in rail:
			var depth := near - float(j) * pitch
			for bend in bends:
				var hub := axis + side * bend * radius + dir * (depth + radius)
				var shoot := PackedVector2Array()
				for step in SHOOT_STEPS + 1:
					var angle := PI * 0.5 * float(step) / float(SHOOT_STEPS)
					shoot.append(hub - side * bend * radius * cos(angle) - dir * radius * sin(angle))
				out.append(shoot)
	return out

func _draw_knot_top(knot: Dictionary) -> void:
	for line in knot_lines(knot):
		_draw_raised(line)
#endregion
