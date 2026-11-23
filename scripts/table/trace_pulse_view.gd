class_name TracePulseView
extends Control
## DATENFLUSS über EINEN festen Pfad: je Leiterzug des Bündels laufen kurze helle Pakete
## hintereinander her, die Züge gegeneinander versetzt, dahinter glimmt der Zug nach.
## Räumt sich selbst weg.

const FADE_TIME := 0.16
const PACKET_GLOW := 0.28
const PACKET_LONG := 22.0
const PACKET_SHORT := 12.0
const PACKET_GAP := 16.0
const TRAIL_GLOW := 0.22

var _lines: Array[PackedVector2Array] = []
var _totals: Array[float] = []
var _color := Color.WHITE
var _width := PcbDeckView.WIDTH
var _trail := 60.0
var _glow := 8.0
var _packets := 5
var _progress := 0.0

## Startet den Lauf über points (Mittellinie des Bündels) in travel_time; comet_length ist
## die Länge des Nachglimmens, core_width hebt die Paketbreite für kräftige Läufe.
func setup(points: PackedVector2Array, color: Color, core_width: float, _glow_width: float,
		travel_time: float, comet_length: float, tracks: int = LedStripView.TRACKS) -> void:
	_color = color
	_width = maxf(PcbDeckView.WIDTH + 1.0, core_width * 0.6)
	_glow = maxf(_glow_width * 0.6, _width * 2.0)
	_packets = clampi(int(comet_length / 22.0), 4, 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.clear()
	_totals.clear()
	var half := float(tracks - 1) * PcbDeckView.PITCH * 0.5
	for k in tracks:
		var line := PcbDeckView.track_line(points, (float(k) - float(tracks - 1) * 0.5)
			* PcbDeckView.PITCH, half)
		var total := 0.0
		for i in line.size() - 1:
			total += line[i].distance_to(line[i + 1])
		if line.size() >= 2 and total > 0.0:
			_lines.append(line)
			_totals.append(total)
	_trail = float(_packets) * (PACKET_LONG + PACKET_GAP + 9.0)

	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, travel_time)
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)

func track_count() -> int:
	return _lines.size()

func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()

func _draw() -> void:
	for track in _lines.size():
		var line := _lines[track]
		var total := _totals[track]
		var trail := minf(_trail, total * 0.6)
		# Der Kopf läuft über das Ende hinaus, bis auch das letzte Paket angekommen ist.
		var head := (total + trail) * _progress - float((track * 7) % 5) * 9.0
		var from := maxf(head - trail, 0.0)
		var to := minf(head, total)
		if to - from > 1.0:
			var glow := Color(_color.r, _color.g, _color.b, _color.a * TRAIL_GLOW)
			draw_polyline(_subpath(line, from, to), glow, PcbDeckView.WIDTH, true)
		var at := head
		for index in _packets:
			var length := PACKET_LONG if (index + track) % 2 == 0 else PACKET_SHORT
			var a := clampf(at - length, 0.0, total)
			var b := clampf(at, 0.0, total)
			if b - a > 1.0 and at > head - trail:
				var fade := 1.0 - float(index) / float(_packets + 2)
				var piece := _subpath(line, a, b)
				draw_polyline(piece, Color(_color.r, _color.g, _color.b,
					_color.a * PACKET_GLOW * fade), _glow)
				draw_polyline(piece, Color(_color.r, _color.g, _color.b, _color.a * fade),
					_width, true)
			at -= length + PACKET_GAP + float((index * 5 + track * 3) % 4) * 9.0

## Punkt in Bogenlänge-Distanz d entlang der Punktkette.
func _point_at(line: PackedVector2Array, d: float) -> Vector2:
	var run := 0.0
	for i in line.size() - 1:
		var seg := line[i].distance_to(line[i + 1])
		if seg > 0.0 and run + seg >= d:
			return line[i].lerp(line[i + 1], (d - run) / seg)
		run += seg
	return line[line.size() - 1]

## Teilstück der Kette zwischen den Distanzen from_d und to_d.
func _subpath(line: PackedVector2Array, from_d: float, to_d: float) -> PackedVector2Array:
	var out := PackedVector2Array([_point_at(line, from_d)])
	var run := 0.0
	for i in line.size() - 1:
		run += line[i].distance_to(line[i + 1])
		if run > from_d and run < to_d:
			out.append(line[i + 1])
	out.append(_point_at(line, to_d))
	return out
