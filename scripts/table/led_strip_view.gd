class_name LedStripView
extends Control
## Eine LICHT-ADER auf dem Deck: ein Bündel Leiterzüge im Stil der Platine (PcbDeckView),
## mit Gold-Pads an beiden Enden der Haupt-Ader. Lichtläufe (TracePulseView) fahren als
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
var _thickness := 9.0

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

## Sammelschiene (T-Form): waagerechte Schiene rail_left..rail_right auf rail_y,
## Stamm senkrecht von trunk_x bis trunk_bottom. Die Konsolen-Adern speisen die
## Schiene; der Komet läuft nicht über diese Leiste selbst (rein zeichnend).
func link_tee(rail_left: float, rail_right: float, rail_y: float, trunk_x: float, trunk_bottom: float, width: float) -> void:
	_thickness = width
	strip_path = PackedVector2Array([Vector2(rail_left, rail_y), Vector2(rail_right, rail_y)])
	branch_path = PackedVector2Array([Vector2(trunk_x, rail_y), Vector2(trunk_x, trunk_bottom)])
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
func link_rails(paths: Array[PackedVector2Array], width: float) -> void:
	_thickness = width
	strip_path = PackedVector2Array()
	branch_path = PackedVector2Array()
	rail_paths = paths
	queue_redraw()

func _draw() -> void:
	var paths: Array[PackedVector2Array] = []
	if strip_path.size() >= 2:
		paths.append(strip_path)
	if branch_path.size() >= 2:
		paths.append(branch_path)
	for rail in rail_paths:
		if rail.size() >= 2:
			paths.append(rail)
	for moat in [true, false]:
		for path in paths:
			var count := tracks_of(path)
			var half := float(count - 1) * PcbDeckView.PITCH * 0.5
			for k in count:
				var offset := (float(k) - float(count - 1) * 0.5) * PcbDeckView.PITCH
				var line := PcbDeckView.track_line(path, offset, half)
				if line.size() < 2:
					continue
				if moat:
					draw_polyline(line, PcbDeckView.MOAT, PcbDeckView.WIDTH + 9.0, true)
					continue
				draw_polyline(line, PcbDeckView.TRACE, PcbDeckView.WIDTH, true)
				if path == strip_path:
					_draw_pad(line[0], line[1])
					_draw_pad(line[line.size() - 1], line[line.size() - 2])

## Züge je Ader: die Schienen des Kombi-Netzes sind schmal, alles andere trägt drei.
func tracks_of(path: PackedVector2Array) -> int:
	return RAIL_TRACKS if rail_paths.has(path) else TRACKS

func _draw_pad(at: Vector2, toward: Vector2) -> void:
	var dir := (toward - at).normalized()
	draw_line(at + dir, at + dir * 15.0, PcbDeckView.GOLD, PcbDeckView.WIDTH + 4.0)
