class_name ScoreTraceView
extends Control
## Eine "Leiterbahn" der Zähl-Animation auf dem Tisch-Display (siehe
## TableScreen.spawn_score_trail): eine feste, NUR aus waagerechten und
## senkrechten Segmenten bestehende Linie (keine Schrägen - wie eine Leiterbahn
## auf einer Platine), die die Punktquelle (Würfel/Charm/Kombi-Zelle) mit dem
## Basis- bzw. Mult-Zähler verbindet. Die Bahn leuchtet von der Quelle aus zum
## Ziel auf (Lichtkopf an der Front), steht dann einen Moment als durchgehende
## Verbindung und blendet aus - danach räumt sie sich selbst weg.
##
## Der Aufrufer wartet reveal_time (= SCORE_TRAIL_TIME), bevor er die Zahl
## hochsetzt: genau der Moment, in dem die Bahn das Ziel erreicht. Halten und
## Ausblenden laufen danach ungestört weiter (kein Warten nötig).

## Standzeit der voll aufgeleuchteten Bahn ("für einen kurzen Moment verbunden").
const HOLD_TIME := 0.15
## Ausblendzeit nach dem Halten.
const FADE_TIME := 0.3

var points := PackedVector2Array()  # Eckpunkte der Bahn (Screen-px, achsenparallel)
var color := Color.WHITE            # überhelle Trail-Farbe (bloomt dank use_hdr_2d)
var core_width := 6.0               # Kern-Strichstärke (px)
var glow_width := 18.0              # breiter, schwacher Schein um den Kern (px)
var progress := 0.0                 # 0..1: Anteil der Bahnlänge, der schon leuchtet

var _segment_lengths: Array[float] = []
var _total_length := 0.0

## Startet die Bahn: Punkte/Farbe/Stärken setzen, dann Aufleuchten -> Halten ->
## Ausblenden -> queue_free. reveal_time = Zeit bis zum Ziel (siehe Kopfkommentar).
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
	# Aufgeleuchteter Teil der Punktkette bis zur Fortschritts-Länge (die Front
	# liegt mitten im gerade wachsenden Segment).
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

	# Breiter, schwacher Schein unter dem hellen Kern; runde Kappen über die
	# Eckpunkte, damit die rechtwinkligen Knicke sauber verbunden aussehen.
	var glow_color := Color(color.r, color.g, color.b, color.a * 0.28)
	if lit.size() >= 2:
		draw_polyline(lit, glow_color, glow_width)
		draw_polyline(lit, color, core_width)
	for corner in lit:
		draw_circle(corner, core_width / 2.0, color)
	# Heller Lichtkopf an der Front, solange die Bahn noch wächst.
	if progress < 1.0:
		draw_circle(head, core_width * 1.6, color)
