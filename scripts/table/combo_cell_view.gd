class_name ComboCellView
extends Control
## Eine kompakte Zelle der Bildschirm-Kombinationsliste (siehe TableScreen):
## gedämpfter Neon-Rahmen, Kombinationsname klein darüber, darunter die
## Beispiel-Würfel als reine NEON-UMRISSE mit Leucht-Pips (kein gefülltes
## Plättchen) und rechts der Multiplikator "×N" in gedämpftem Magenta.
##
## scene_root hält diese Zellen in combo_labels und tweent modulate/scale fürs
## Aufleuchten der gewürfelten Kombination - die Basisfarben hier sind bewusst
## gedämpft, Ruhe- und Glühfarben kommen als modulate von außen (Überhell > 1
## bloomt dank use_hdr_2d des TableScreen-Viewports).

const NEON_DIM := Color(0.4, 0.75, 0.85, 0.75)   # Rahmen, Name, Würfel-Umrisse
const NEON_PIP := Color(0.55, 0.95, 1.0)          # Leucht-Pips (Augen)
const MULT_COLOR := Color(0.85, 0.55, 0.8)        # Multiplikator, gedämpftes Magenta
const BORDER_WIDTH := 1.5
const NAME_FONT_SIZE := 10
const MULT_FONT_SIZE := 15
const DIE_MAX_SIZE := 14.0
const DIE_GAP := 2.0
const PADDING_X := 8.0
const MULT_WIDTH := 30.0  # rechts reservierter Platz für "×N"

## Pip-Anordnungen je Augenzahl (Anteile der Würfelfläche).
const PIP_LAYOUTS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
	3: [Vector2(0.25, 0.25), Vector2(0.5, 0.5), Vector2(0.75, 0.75)],
	4: [Vector2(0.28, 0.28), Vector2(0.72, 0.28), Vector2(0.28, 0.72), Vector2(0.72, 0.72)],
	5: [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.5, 0.5), Vector2(0.25, 0.75), Vector2(0.75, 0.75)],
	6: [Vector2(0.27, 0.22), Vector2(0.73, 0.22), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.78), Vector2(0.73, 0.78)],
}

var combo_name := ""
var values: Array = []
var mult := 1
## Bezugsgröße fürs Highlight-Wachsen (siehe scene_root._tween_combo_label).
var base_scale := Vector2.ONE

var _die_style: StyleBoxFlat

## Befüllt die Zelle; Position/Größe setzt der TableScreen vorher.
func setup(p_name: String, p_values: Array, p_mult: int) -> void:
	combo_name = p_name
	values = p_values
	mult = p_mult
	pivot_offset = size / 2.0  # Highlight skaliert um die Zellenmitte
	_die_style = StyleBoxFlat.new()
	_die_style.draw_center = false  # nur Umriss - der Würfel ist eine Neonlinie
	_die_style.border_color = NEON_DIM
	_die_style.set_border_width_all(1)
	_die_style.set_corner_radius_all(3)
	queue_redraw()

## Schreibt den Multiplikator neu (Menü-Stufen, siehe DiceScoring.mult_for).
func set_mult(p_mult: int) -> void:
	mult = p_mult
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), NEON_DIM, false, BORDER_WIDTH)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(PADDING_X, 4.0 + NAME_FONT_SIZE), combo_name,
		HORIZONTAL_ALIGNMENT_CENTER, size.x - PADDING_X * 2.0, NAME_FONT_SIZE, NEON_DIM)

	# Untere Zeile: Würfelreihe links, "×N" rechtsbündig daneben.
	var count := values.size()
	if count > 0:
		var avail := size.x - PADDING_X * 2.0 - MULT_WIDTH
		var die_size: float = minf(DIE_MAX_SIZE, (avail - DIE_GAP * float(count - 1)) / float(count))
		var x := PADDING_X
		var y := size.y - die_size - 6.0
		for value: int in values:
			var rect := Rect2(Vector2(x, y), Vector2.ONE * die_size)
			draw_style_box(_die_style, rect)
			for pip: Vector2 in PIP_LAYOUTS.get(value, []):
				draw_circle(rect.position + pip * die_size, die_size * 0.11, NEON_PIP)
			x += die_size + DIE_GAP

	draw_string(font, Vector2(size.x - PADDING_X - MULT_WIDTH, size.y - 8.0), "×%d" % mult,
		HORIZONTAL_ALIGNMENT_RIGHT, MULT_WIDTH, MULT_FONT_SIZE, MULT_COLOR)
