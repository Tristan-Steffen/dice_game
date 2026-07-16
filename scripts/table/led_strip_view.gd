class_name LedStripView
extends Control
## Eine durchgehende, glatte LED-Leiste auf dem Filz zwischen Hub und
## Kombinationen-Fenster: dunkle Ader mit feinem, ununterbrochenem Platin-Saum;
## nur zarte Quer-Ticks deuten die Segmentierung an. Bewusst zurückhaltend (eine
## Ader). Der Kauf-Lichtlauf (TableScreen) läuft als kurzer Komet über strip_path.

const SCREEN_FILL := Color(0.028, 0.024, 0.07, 0.97)  # deutlich dunkler als das Fenster
const SCREEN_BORDER := Color(0.72, 0.76, 0.86, 0.42)  # poliertes Platin, hauchdünn
## Quer-Ticks: kaum sichtbarer Hinweis auf die LED-Segmente.
const TICK_COLOR := Color(0.72, 0.76, 0.86, 0.14)

## Mittellinie der Leiste (Screen-px, achsenparallele L-Führung ab Hub-Oberkante).
var strip_path := PackedVector2Array()
var _thickness := 9.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Verlegt die Leiste zwischen den Fenster-Rechtecken; width = Aderbreite.
## obstacle = zu umgehendes Fenster (Grube) - leer = direkte Führung.
func link(hub_rect: Rect2, cluster_rect: Rect2, width: float, obstacle := Rect2()) -> void:
	_thickness = width
	strip_path = _route(hub_rect, cluster_rect, obstacle)
	queue_redraw()

## Verlegt die Leiste seitlich zwischen zwei nebeneinander liegenden Fenstern
## (zugewandte Links/Rechts-Kanten), bei Höhenversatz als flaches Z.
func link_side(from_rect: Rect2, to_rect: Rect2, width: float) -> void:
	_thickness = width
	var to_right := to_rect.get_center().x >= from_rect.get_center().x
	var ax := from_rect.end.x if to_right else from_rect.position.x
	var bx := to_rect.position.x if to_right else to_rect.end.x
	var ay := from_rect.get_center().y
	var by := to_rect.get_center().y
	if absf(ay - by) < 2.0:
		strip_path = PackedVector2Array([Vector2(ax, ay), Vector2(bx, by)])
	else:
		var mid := lerpf(ax, bx, 0.5)
		strip_path = PackedVector2Array([
			Vector2(ax, ay), Vector2(mid, ay), Vector2(mid, by), Vector2(bx, by)])
	queue_redraw()

## Eine Ader ab der Hub-OBERKANTE: senkrecht in den freien Korridor zwischen
## Hub-Oberkante und den darüber liegenden Fenstern (Grube/Cluster), dann
## waagerecht bis unter den Cluster, dort senkrecht in seine Unterkante - so
## kreuzt die Leiste kein anderes Fenster.
func _route(hub_rect: Rect2, cluster_rect: Rect2, obstacle: Rect2) -> PackedVector2Array:
	# Korridor-Höhe: mittig zwischen der tiefsten Hindernis-Unterkante über dem
	# Hub und der Hub-Oberkante.
	var above_bottom := cluster_rect.end.y
	if obstacle.size.y > 0.0:
		above_bottom = maxf(above_bottom, obstacle.end.y)
	var lane_y := (above_bottom + hub_rect.position.y) * 0.5
	# Fällt kein Korridor an (kein Hindernis darüber), führt die Ader direkt.
	if lane_y >= hub_rect.position.y or lane_y <= cluster_rect.end.y:
		lane_y = hub_rect.position.y - _thickness * 2.0
	var start := Vector2(hub_rect.get_center().x, hub_rect.position.y)
	var enter_x := cluster_rect.get_center().x
	return PackedVector2Array([
		start, Vector2(start.x, lane_y), Vector2(enter_x, lane_y), Vector2(enter_x, cluster_rect.end.y)])

func _draw() -> void:
	if strip_path.size() < 2:
		return
	# Durchgehendes Band: erst der Saum als etwas breiteres Band, dann die
	# dunkle Füllung darüber - so bleibt der Platin-Saum ununterbrochen (keine
	# Quer-Nähte an den Segmentgrenzen).
	var edge := maxf(1.0, _thickness * 0.13)
	_draw_band(SCREEN_BORDER, _thickness + edge * 2.0)
	_draw_band(SCREEN_FILL, _thickness)
	_draw_segment_ticks()

## Zeichnet ein durchgehendes Band der gegebenen Dicke entlang strip_path.
## Nur an INNEREN Ecken ragt ein Segment um die halbe Dicke über sein Ende
## hinaus (füllt die Ecke); die beiden Enden der Ader (Hub-Oberkante,
## Cluster-Unterkante) bleiben bündig - so ragt nichts in ein Fenster hinein.
func _draw_band(color: Color, thickness: float) -> void:
	var half := thickness * 0.5
	var last := strip_path.size() - 1
	for i in last:
		var a := strip_path[i]
		var b := strip_path[i + 1]
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
func _draw_segment_ticks() -> void:
	var gap := _thickness * 3.4
	var tick_half := _thickness * 0.34
	var tick_w := maxf(1.0, _thickness * 0.07)
	var total := 0.0
	for i in strip_path.size() - 1:
		total += strip_path[i].distance_to(strip_path[i + 1])
	var d := gap
	while d < total - _thickness:
		var here := _point_dir_at(d)
		var perp := Vector2(-here[1].y, here[1].x)
		draw_line(here[0] - perp * tick_half, here[0] + perp * tick_half, TICK_COLOR, tick_w)
		d += gap

## Punkt UND Richtung in Bogenlänge-Distanz d entlang strip_path.
func _point_dir_at(d: float) -> Array:
	var run := 0.0
	for i in strip_path.size() - 1:
		var a := strip_path[i]
		var b := strip_path[i + 1]
		var seg := a.distance_to(b)
		if seg <= 0.0:
			continue
		if run + seg >= d:
			var dir := (b - a) / seg
			return [a + dir * (d - run), dir]
		run += seg
	return [strip_path[strip_path.size() - 1], Vector2.RIGHT]
