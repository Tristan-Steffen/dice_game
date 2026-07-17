class_name ScoreShockwave
extends Control
## Kurzlebiger Stoßwellen-Ring am Verschmelzungspunkt der Wertungs-Orbs: ein
## heller Ring dehnt sich aus und blendet aus, dann räumt sich der Knoten selbst
## weg. Rein schmückend - unterstreicht den "Einschlag" der Merge.

var _center := Vector2.ZERO
var _color := Color.WHITE
var _max_radius := 0.0
var _t := 0.0
var _duration := 0.45

func setup(center_px: Vector2, ring_color: Color, max_radius: float, duration: float) -> void:
	_center = center_px
	_color = ring_color
	_max_radius = max_radius
	_duration = duration
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	if _t >= _duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var f := clampf(_t / _duration, 0.0, 1.0)
	var r: float = _max_radius * ease(f, 0.35)  # schnell raus, dann bremsend
	var a: float = (1.0 - f) * _color.a
	var width: float = maxf(2.0, _max_radius * 0.06 * (1.0 - f))
	draw_arc(_center, r, 0.0, TAU, 64, Color(_color.r, _color.g, _color.b, a), width, true)
