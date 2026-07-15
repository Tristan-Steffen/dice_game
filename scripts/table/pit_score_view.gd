class_name PitScoreView
extends Control
## Ein einzelner Wertungszähler oberhalb der Grube, mittig in seiner Fläche
## gezeichnet. Basis (Cyan) und Mult (Gold) sind zwei getrennte Instanzen an
## eigenen Editor-Ankern. Eigenes _draw statt Label: die Zahl zentriert sich
## sofort, ohne aufgeschobenes Container-Layout.

const BASE_COLOR := Color("#00ffff")
const MULT_COLOR := Color("#ffd319")
const TOTAL_COLOR := Color(2.1, 1.7, 0.15)  # überhelles Gold der Gesamtzahl

var value := 0
var color := BASE_COLOR  # je Instanz gesetzt

func set_value(p_value: int) -> void:
	value = p_value
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var h := size.y
	var value_font := int(h * 0.6)
	var baseline := size.y / 2.0 + h * 0.22
	var text := str(value)
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, value_font).x
	draw_string(font, Vector2(size.x / 2.0 - text_width / 2.0, baseline), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, value_font, color)

## Lokaler Zielpunkt der Licht-Trails: die Mitte der Fläche (= die Zahl).
func value_anchor() -> Vector2:
	return size / 2.0
