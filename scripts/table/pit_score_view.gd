class_name PitScoreView
extends Control
## EIN einzelner Wertungszähler auf dem Tisch-Display OBERHALB der Grube - eine
## Dauerzahl, mittig in seiner Fläche gezeichnet. Basis (Cyan) und Mult (Gold)
## sind zwei GETRENNTE Instanzen (siehe TableScreen.base_counter/mult_counter),
## jede an ihrem eigenen Editor-Anker ($ScreenAnchors/BaseCounter bzw.
## MultCounter) - so lassen sie sich einzeln über den Bildschirm schieben.
## Außerhalb eines Wurfs steht 0; sobald ein Wurf liegt, springt der
## Kombinationswert hinein (siehe scene_root._refresh_ui), und die Zähl-Animation
## beim Nehmen zählt darauf weiter. Die verschmolzene Gesamtzahl zeigt TableScreen
## dagegen am Zielbalken (nicht hier - siehe TableScreen.show_pit_total).
##
## Eigenes _draw statt eines Labels: die Zahl zentriert sich damit sofort (ohne
## aufgeschobenes Container-Layout), egal wie viele Stellen sie hat.

const BASE_COLOR := Color("#00ffff")     # 80s Neon --accent-2 (Cyan): Basispunkte
const MULT_COLOR := Color("#ffd319")     # 80s Neon Gold: Multiplikator
const TOTAL_COLOR := Color(2.1, 1.7, 0.15)  # überhelles Gold: die Gesamtzahl (am Balken, siehe TableScreen)

var value := 0
var color := BASE_COLOR  # je Instanz gesetzt (Basis Cyan / Mult Gold)

## Setzt den angezeigten Wert (der Normalzustand während der Zählschritte).
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
	# Mittig in der Fläche - deren Mitte liegt (siehe TableScreen.configure_pit_score)
	# genau auf dem Editor-Anker dieses Zählers.
	draw_string(font, Vector2(size.x / 2.0 - text_width / 2.0, baseline), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, value_font, color)

## Lokaler Zielpunkt für die Licht-Trails der Zähl-Animation: die Mitte der
## Fläche (= die gezeichnete Zahl).
func value_anchor() -> Vector2:
	return size / 2.0
