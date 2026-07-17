class_name LedStripView
extends Control
## Eine durchgehende, glatte LED-Leiste auf dem Filz zwischen Hub und
## Kombinationen-Fenster: dunkle Ader mit feinem, ununterbrochenem Platin-Saum;
## nur zarte Quer-Ticks deuten die Segmentierung an. Bewusst zurückhaltend (eine
## Ader). Der Kauf-Lichtlauf (TableScreen) läuft als kurzer Komet über strip_path.

const SCREEN_FILL := Color(0.022, 0.018, 0.055, 0.94)  # deutlich dunkler als das Fenster
const SCREEN_BORDER := Color(0.72, 0.76, 0.86, 0.22)   # poliertes Platin, nur ein Hauch
## Weicher Schatten-Sitz im Filz (zwei Lagen ~ Verlauf) - lässt die Ader
## eingelassen statt aufgemalt wirken.
const SHADOW_OUTER := Color(0.0, 0.0, 0.0, 0.10)
const SHADOW_INNER := Color(0.0, 0.0, 0.0, 0.16)
## Quer-Ticks: kaum sichtbarer Hinweis auf die LED-Segmente.
const TICK_COLOR := Color(0.72, 0.76, 0.86, 0.07)

## Mittellinie der Leiste (Screen-px, achsenparallele L-Führung ab Hub-Oberkante).
var strip_path := PackedVector2Array()
## Abzweig (T-Stück) aus dem Korridor zu einem weiteren Fenster; rein dekorativ -
## Lichtläufe (Kometen) fahren nur strip_path.
var branch_path := PackedVector2Array()
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

func _draw() -> void:
	if strip_path.size() < 2:
		return
	var paths: Array[PackedVector2Array] = [strip_path]
	if branch_path.size() >= 2:
		paths.append(branch_path)
	# Durchgehendes Band von außen nach innen: weicher Schatten-Sitz, hauchdünner
	# Platin-Saum, dunkle Füllung - der Saum bleibt ununterbrochen (keine
	# Quer-Nähte an den Segmentgrenzen). Jede Lage über ALLE Adern, damit das
	# T-Stück nahtlos verschmilzt (die Füllung deckt den Saum am Knoten).
	var edge := maxf(1.0, _thickness * 0.09)
	for path in paths:
		_draw_band(path, SHADOW_OUTER, _thickness * 2.1)
	for path in paths:
		_draw_band(path, SHADOW_INNER, _thickness * 1.5)
	for path in paths:
		_draw_band(path, SCREEN_BORDER, _thickness + edge * 2.0)
	for path in paths:
		_draw_band(path, SCREEN_FILL, _thickness)
	for path in paths:
		_draw_segment_ticks(path)

## Zeichnet ein durchgehendes Band der gegebenen Dicke entlang path.
## Nur an INNEREN Ecken ragt ein Segment um die halbe Dicke über sein Ende
## hinaus (füllt die Ecke); die beiden Enden der Ader (Hub-Oberkante,
## Cluster-Unterkante) bleiben bündig - so ragt nichts in ein Fenster hinein.
func _draw_band(path: PackedVector2Array, color: Color, thickness: float) -> void:
	var half := thickness * 0.5
	var last := path.size() - 1
	for i in last:
		var a := path[i]
		var b := path[i + 1]
		var seg := a.distance_to(b)
		if seg <= 0.0:
			continue
		var dir := (b - a) / seg
		var ea := a - dir * (half if i > 0 else 0.0)          # Start nur innen verlängern
		var eb := b + dir * (half if i < last - 1 else 0.0)   # Ende nur innen verlängern
		if absf(dir.x) > absf(dir.y):
			draw_rect(Rect2(minf(ea.x, eb.x), a.y - half, absf(eb.x - ea.x), thickness), color)
		else:
			draw_rect(Rect2(a.x - half, minf(ea.y, eb.y), thickness, absf(eb.y - ea.y)), color)

## Zarte Quer-Ticks in gleichmäßigem Abstand - der einzige Hinweis auf die
## LED-Segmentierung (sonst wirkt die Ader glatt).
func _draw_segment_ticks(path: PackedVector2Array) -> void:
	var gap := _thickness * 5.2
	var tick_half := _thickness * 0.3
	var tick_w := maxf(1.0, _thickness * 0.07)
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	var d := gap
	while d < total - _thickness:
		var here := _point_dir_at(path, d)
		var perp := Vector2(-here[1].y, here[1].x)
		draw_line(here[0] - perp * tick_half, here[0] + perp * tick_half, TICK_COLOR, tick_w)
		d += gap

## Punkt UND Richtung in Bogenlänge-Distanz d entlang path.
func _point_dir_at(path: PackedVector2Array, d: float) -> Array:
	var run := 0.0
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var seg := a.distance_to(b)
		if seg <= 0.0:
			continue
		if run + seg >= d:
			var dir := (b - a) / seg
			return [a + dir * (d - run), dir]
		run += seg
	return [path[path.size() - 1], Vector2.RIGHT]
