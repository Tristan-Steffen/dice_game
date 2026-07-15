class_name ScoreTraceView
extends Control
## Eine "Leiterbahn" auf dem Tisch-Display: rein achsenparallele Linie, die
## von der Quelle zum Ziel aufleuchtet (Lichtkopf an der Front), kurz als
## Verbindung steht und ausblendet - räumt sich selbst weg. Der Aufrufer
## wartet reveal_time (= Ankunft am Ziel), bevor er die Zahl hochsetzt.

const HOLD_TIME := 0.15
const FADE_TIME := 0.3

var points := PackedVector2Array()  # Eckpunkte (Screen-px, achsenparallel)
var color := Color.WHITE            # überhelle Trail-Farbe (bloomt)
var core_width := 6.0
var glow_width := 18.0
var progress := 0.0  # 0..1: Anteil der Bahnlänge, der schon leuchtet

var _segment_lengths: Array[float] = []
var _total_length := 0.0

## Startet: Aufleuchten -> Halten -> Ausblenden -> queue_free.
func setup(p_points: PackedVector2Array, p_color: Color, p_core_width: float, p_glow_width: float, reveal_time: float) -> void:
	points = p_points
	color = p_color
	core_width = p_core_width
	glow_width = p_glow_width
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_total_length = 0.0
	_segment_lengths.clear()
	for i in points.size() - 1:
		var segment_length := points[i].distance_to(points[i + 1])
		_segment_lengths.append(segment_length)
		_total_length += segment_length

	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, reveal_time)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)

func _set_progress(value: float) -> void:
	progress = value
	queue_redraw()

func _draw() -> void:
	if points.size() < 2 or _total_length <= 0.0:
		return
	# Aufgeleuchteter Teil der Punktkette bis zur Fortschritts-Länge.
	var lit_length := _total_length * progress
	var lit := PackedVector2Array()
	lit.append(points[0])
	var run := 0.0
	var head := points[points.size() - 1]
	for i in _segment_lengths.size():
		var segment_length := _segment_lengths[i]
		if run + segment_length >= lit_length:
			var t := 0.0 if segment_length <= 0.0 else (lit_length - run) / segment_length
			head = points[i].lerp(points[i + 1], t)
			lit.append(head)
			break
		lit.append(points[i + 1])
		run += segment_length

	# Breiter Schein unter dem Kern; runde Kappen verbinden die Knicke sauber.
	var glow_color := Color(color.r, color.g, color.b, color.a * 0.28)
	if lit.size() >= 2:
		draw_polyline(lit, glow_color, glow_width)
		draw_polyline(lit, color, core_width)
	for corner in lit:
		draw_circle(corner, core_width / 2.0, color)
	# Heller Lichtkopf, solange die Bahn noch wächst.
	if progress < 1.0:
		draw_circle(head, core_width * 1.6, color)
