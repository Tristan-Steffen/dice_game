class_name TracePulseView
extends Control
## Kurzer, gedämpfter Lichtkopf, der EINEN festen Pfad entlangläuft: statt der
## ganzen Bahn (ScoreTraceView) leuchtet nur ein Kometen-Fenster fester Länge,
## das von Anfang bis Ende wandert. Dünn und dim - räumt sich selbst weg.

const FADE_TIME := 0.16

var _points := PackedVector2Array()
var _seg_len: Array[float] = []
var _total := 0.0
var _color := Color.WHITE
var _core := 3.0
var _glow := 8.0
var _comet := 60.0
var _progress := 0.0

## Startet den Lauf: Komet der Länge comet_length wandert in travel_time von
## Pfadanfang zu -ende, blendet dann kurz aus. Die Länge wird auf max. 60% der
## Gesamtlänge gedeckelt, damit auch kurze Pfade ein wanderndes Fenster zeigen.
func setup(points: PackedVector2Array, color: Color, core_width: float, glow_width: float, travel_time: float, comet_length: float) -> void:
	_points = points
	_color = color
	_core = core_width
	_glow = glow_width
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_total = 0.0
	_seg_len.clear()
	for i in points.size() - 1:
		var length := points[i].distance_to(points[i + 1])
		_seg_len.append(length)
		_total += length
	_comet = minf(comet_length, _total * 0.6)

	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, travel_time)
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)

func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()

func _draw() -> void:
	if _points.size() < 2 or _total <= 0.0:
		return
	var head_d := _total * _progress
	var seg := _subpath(maxf(0.0, head_d - _comet), head_d)
	if seg.size() >= 2:
		draw_polyline(seg, Color(_color.r, _color.g, _color.b, _color.a * 0.3), _glow)
		draw_polyline(seg, _color, _core)
	draw_circle(_point_at(head_d), _core * 0.85, _color)

## Punkt in Bogenlänge-Distanz d entlang der Punktkette.
func _point_at(d: float) -> Vector2:
	var run := 0.0
	for i in _seg_len.size():
		if run + _seg_len[i] >= d:
			var t := 0.0 if _seg_len[i] <= 0.0 else (d - run) / _seg_len[i]
			return _points[i].lerp(_points[i + 1], t)
		run += _seg_len[i]
	return _points[_points.size() - 1]

## Teilstück der Kette zwischen den Distanzen from_d und to_d.
func _subpath(from_d: float, to_d: float) -> PackedVector2Array:
	var out := PackedVector2Array([_point_at(from_d)])
	var run := 0.0
	for i in _seg_len.size():
		var node_d := run + _seg_len[i]
		if node_d > from_d and node_d < to_d:
			out.append(_points[i + 1])
		run = node_d
	out.append(_point_at(to_d))
	return out
