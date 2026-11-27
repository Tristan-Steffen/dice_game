class_name RunChartView
extends Control
## Das DIAGRAMM der Hub-Startseite: Blind und Rundenpunkte über die letzten Runden, die
## senkrechte Achse logarithmisch (die Zahlen explodieren). Bekommt reine Zahlen.

const SHOWN_ROUNDS := 12
const BLIND_COLOR := Color("#ff5555")
const SCORE_COLOR := Color("#ecebff")
const GRID_COLOR := Color(0.6, 0.57, 0.8, 0.22)
const LABEL_COLOR := Color("#8a85b8")
const EMPTY_TEXT := "Noch keine Runde beendet"
const LEGEND_BLIND := "Blind"
const LEGEND_SCORE := "Rundenpunkte"
const ROUND_TEXT := "Runde %d"
## Maße in u (die Einheit des Hubs).
const LEGEND_UNITS := 2.6
const AXIS_UNITS := 8.6
const FOOT_UNITS := 2.4
const FONT_UNITS := 1.8
const LINE_UNITS := 0.32
const DOT_UNITS := 0.45

var unit_px := 10.0
## Blind je Runde (der letzte ist der laufende) und Punkte je beendeter Runde.
var blinds: Array[int] = []
var scores: Array[int] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_series(blind_values: Array, score_values: Array) -> void:
	var b: Array[int] = []
	var s: Array[int] = []
	b.assign(blind_values)
	s.assign(score_values)
	if b == blinds and s == scores:
		return
	blinds = b
	scores = s
	queue_redraw()

## Ohne beendete Runde gibt es nichts zu vergleichen.
func is_empty_state() -> bool:
	return scores.is_empty()

## Die erste gezeigte Runde (0-basiert) - es stehen höchstens SHOWN_ROUNDS.
func first_shown() -> int:
	return maxi(0, blinds.size() - SHOWN_ROUNDS)

func shown_count() -> int:
	return blinds.size() - first_shown()

## Zehnerpotenzen, die die gezeigten Werte einschließen: Vector2i(unten, oben).
func decade_range() -> Vector2i:
	var low := INF
	var high := 0.0
	for i in range(first_shown(), blinds.size()):
		for value in [blinds[i], scores[i] if i < scores.size() else -1]:
			if value > 0:
				low = minf(low, float(value))
				high = maxf(high, float(value))
	if high <= 0.0:
		return Vector2i(0, 1)
	var bottom := floori(log(low) / log(10.0))
	var top := ceili(log(high) / log(10.0))
	if top <= bottom:
		top = bottom + 1
	return Vector2i(bottom, top)

func plot_rect() -> Rect2:
	var u := unit_px
	return Rect2(u * AXIS_UNITS, u * LEGEND_UNITS, maxf(size.x - u * (AXIS_UNITS + 1.0), 1.0),
		maxf(size.y - u * (LEGEND_UNITS + FOOT_UNITS), 1.0))

## Der Punkt einer Runde (0-basiert) bei value im Plot.
func point_at(round_index: int, value: float) -> Vector2:
	var plot := plot_rect()
	var range_dec := decade_range()
	var count := maxi(1, shown_count() - 1)
	var x := plot.position.x + plot.size.x * float(round_index - first_shown()) / float(count)
	var t := (log(maxf(value, 1.0)) / log(10.0) - float(range_dec.x)) / float(range_dec.y - range_dec.x)
	return Vector2(x, plot.end.y - plot.size.y * clampf(t, 0.0, 1.0))

func _font() -> Font:
	var font := get_theme_font("font", "Label")
	return font if font != null else ThemeDB.fallback_font

func _draw() -> void:
	var u := unit_px
	var font := _font()
	var px := maxi(8, int(u * FONT_UNITS))
	_draw_legend(font, px)
	if is_empty_state():
		draw_string(font, Vector2(0.0, size.y * 0.55), EMPTY_TEXT, HORIZONTAL_ALIGNMENT_CENTER,
			size.x, maxi(8, int(u * FONT_UNITS * 1.2)), LABEL_COLOR)
		return
	var plot := plot_rect()
	var dec := decade_range()
	for d in range(dec.x, dec.y + 1):
		var y := point_at(first_shown(), pow(10.0, d)).y
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), GRID_COLOR, maxf(1.0, u * 0.1))
		draw_string(font, Vector2(0.0, y + font.get_ascent(px) * 0.4), BigNumber.short(pow(10.0, d)),
			HORIZONTAL_ALIGNMENT_RIGHT, plot.position.x - u * 0.8, px, LABEL_COLOR)
	_draw_series(blinds, BLIND_COLOR)
	_draw_series(scores, SCORE_COLOR)
	var foot_y := size.y - u * 0.4
	draw_string(font, Vector2(plot.position.x, foot_y), ROUND_TEXT % (first_shown() + 1),
		HORIZONTAL_ALIGNMENT_LEFT, -1, px, LABEL_COLOR)
	draw_string(font, Vector2(plot.position.x, foot_y), ROUND_TEXT % blinds.size(),
		HORIZONTAL_ALIGNMENT_RIGHT, plot.size.x, px, LABEL_COLOR)

func _draw_series(values: Array[int], color: Color) -> void:
	var u := unit_px
	var points := PackedVector2Array()
	for i in range(first_shown(), values.size()):
		points.append(point_at(i, float(values[i])))
	if points.size() >= 2:
		draw_polyline(points, color, maxf(1.0, u * LINE_UNITS), true)
	for point in points:
		draw_circle(point, u * DOT_UNITS, color)

func _draw_legend(font: Font, px: int) -> void:
	var u := unit_px
	var y := u * LEGEND_UNITS * 0.6
	var x := u * AXIS_UNITS
	for item: Array in [[LEGEND_BLIND, BLIND_COLOR], [LEGEND_SCORE, SCORE_COLOR]]:
		draw_line(Vector2(x, y - px * 0.3), Vector2(x + u * 2.0, y - px * 0.3), item[1], maxf(1.0, u * LINE_UNITS))
		x += u * 2.6
		draw_string(font, Vector2(x, y), String(item[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, px, LABEL_COLOR)
		x += font.get_string_size(String(item[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + u * 2.4
