class_name ComboCellView
extends Control
## Eine Zelle der Bildschirm-Kombinationsliste: Neon-Rahmen, Name, Beispiel-
## Würfel als Neon-Umrisse mit Leucht-Pips, rechts Basispunkte (Cyan) + "×N"
## (Gold). Alle Maße sind Anteile der Zellengröße - skaliert mit jeder
## Auflösung. Ruhe-/Glühfarben kommen als modulate von außen (scene_root).

const NEON_DIM := Color("#ff79c6cc")   # Pink: Rahmen, Name, Würfel-Umrisse
const NEON_PIP := Color("#00ffff")     # Cyan: Leucht-Pips
const MULT_COLOR := Color("#ffd319")   # Gold: Multiplikator

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
var points := 0
var mult := 1
## Bezugsgröße fürs Highlight-Wachsen.
var base_scale := Vector2.ONE

## Befüllt die Zelle; Position/Größe setzt der TableScreen vorher.
func setup(p_name: String, p_values: Array, p_points: int, p_mult: int) -> void:
	combo_name = p_name
	values = p_values
	points = p_points
	mult = p_mult
	pivot_offset = size / 2.0  # Highlight skaliert um die Zellenmitte
	queue_redraw()

## Schreibt Basispunkte + Multiplikator neu (Menü-Stufen).
func set_score(p_points: int, p_mult: int) -> void:
	points = p_points
	mult = p_mult
	queue_redraw()

func _draw() -> void:
	var h := size.y
	var w := size.x
	var pad := h * 0.16
	var name_font := int(h * 0.22)
	var mult_font := int(h * 0.34)
	var points_font := int(h * 0.26)
	var mult_width := w * 0.3  # rechte Wertungs-Spalte
	var border := maxf(2.0, h * 0.03)

	draw_rect(Rect2(Vector2.ZERO, size), NEON_DIM, false, border)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(pad, pad + float(name_font)), combo_name,
		HORIZONTAL_ALIGNMENT_CENTER, w - pad * 2.0, name_font, NEON_DIM)

	# Untere Zeile: Würfelreihe links, Wertung rechts.
	var count := values.size()
	if count > 0:
		var die_gap := h * 0.05
		var avail := w - pad * 2.0 - mult_width
		var die_size: float = minf(h * 0.42, (avail - die_gap * float(count - 1)) / float(count))
		var die_style := StyleBoxFlat.new()
		die_style.draw_center = false  # nur Umriss - der Würfel ist eine Neonlinie
		die_style.border_color = NEON_DIM
		die_style.set_border_width_all(int(maxf(1.5, h * 0.022)))
		die_style.set_corner_radius_all(int(die_size * 0.18))
		var x := pad
		var y := h - die_size - pad * 0.4
		for value: int in values:
			var rect := Rect2(Vector2(x, y), Vector2.ONE * die_size)
			draw_style_box(die_style, rect)
			for pip: Vector2 in PIP_LAYOUTS.get(value, []):
				draw_circle(rect.position + pip * die_size, die_size * 0.11, NEON_PIP)
			x += die_size + die_gap

	# "×N" (Gold) ganz außen, Basispunkte (Cyan) links davor, gleiche Grundlinie.
	var mult_text := "×%d" % mult
	var mult_text_width := font.get_string_size(mult_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, mult_font).x
	var baseline := h - pad * 0.5
	draw_string(font, Vector2(w - pad - mult_width, baseline), mult_text,
		HORIZONTAL_ALIGNMENT_RIGHT, mult_width, mult_font, MULT_COLOR)
	draw_string(font, Vector2(0.0, baseline), str(points),
		HORIZONTAL_ALIGNMENT_RIGHT, w - pad - mult_text_width - h * 0.12, points_font, NEON_PIP)
