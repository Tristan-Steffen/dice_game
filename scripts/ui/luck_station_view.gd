class_name LuckStationView
extends Control
## Die GLÜCKS-STATION rechts neben dem Chip-Tray: ein Nullkraft-SOCKEL mit Hebel, darunter
## der CHIP mit den sechs Seiten, die Schalterbank des Glücks und zwei Steckbrücken. Das
## Fenster malt nichts - es MELDET die Rechtecke der Teile; den Körper (LuckStationBody)
## stellt scene_root. Hier wohnen nur die Text-Regeln.

## Breite als Anteil der Tray-Breite.
const WIDTH_SHARE := 0.6
## Der Grundriß in Stations-Einheiten (= Welt bei 37,5 px je Einheit).
const UNITS := Vector2(6.2, 15.2)
## Die Teile als (Mitte x, Mitte y, Breite, Höhe) in Stations-Einheiten, y Bild-OBEN.
const PARTS := {
	"socket": Rect2(-0.2, 4.65, 4.2, 4.2),
	"seat": Rect2(-0.2, 4.65, 2.44, 2.44),
	"lever": Rect2(2.32, 4.65, 0.72, 4.5),
	"traces": Rect2(0.0, 2.15, 2.4, 0.8),
	"chip": Rect2(0.0, -0.55, 5.7, 4.55),
	"net": Rect2(0.0, -0.5, 4.9, 3.64),
	"expected": Rect2(1.5, -1.68, 2.4, 0.86),
	"gauge": Rect2(0.0, -4.2, 5.8, 1.15),
	"luck_box": Rect2(-2.5, -4.2, 1.0, 0.6),
	"bank": Rect2(0.0, -4.2, 3.7, 1.15),
	"next_box": Rect2(2.5, -4.2, 1.0, 0.6),
	"free": Rect2(-2.5, -6.05, 0.95, 0.44),
	"keep": Rect2(0.6, -6.05, 0.95, 0.44),
	"keeps_box": Rect2(2.72, -6.05, 0.6, 0.5),
}
## Kreuz: Zelle und Teilung in Stations-Einheiten.
const CELL := 1.12
const CELL_STEP := 1.26

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Der Platz: rechts neben dem Tray, so hoch wie es und oben bündig; nie über limit_x hinaus.
static func placed_beside(tray_rect: Rect2, gap: float, limit_x := INF) -> Rect2:
	var x := tray_rect.end.x + gap
	var width := minf(tray_rect.size.x * WIDTH_SHARE, limit_x - x)
	return Rect2(Vector2(x, tray_rect.position.y), Vector2(maxf(width, 0.0), tray_rect.size.y))

static func expected_text(expected: float) -> String:
	return "Ø %s Wahlen" % expected_digits(expected)

## Die Zahl im Segment-Fenster des Chips ("2,2").
static func expected_digits(expected: float) -> String:
	return ("%.1f" % expected).replace(".", ",")

static func gauge_text(state: Dictionary) -> String:
	var luck := int(state.get("luck", 0))
	var next := int(state.get("next", -1))
	if next < 0:
		return "Glück %d · alle Seiten voll" % luck
	return "Glück %d · Auge bei %d" % [luck, next]

## Wie weit der Pegel von der letzten zur nächsten Schwelle steht (0..1).
static func gauge_share(state: Dictionary) -> float:
	var next := int(state.get("next", -1))
	if next < 0:
		return 1.0
	var prev := int(state.get("prev", 0))
	if next <= prev:
		return 0.0
	return clampf(float(int(state.get("luck", 0)) - prev) / float(next - prev), 0.0, 1.0)

## Die Bonus-Zeile (leer = sie sagt nichts): offene Einbauten vor Freier Hand.
static func bonus_text(state: Dictionary) -> String:
	var keeps := int(state.get("keeps", 0))
	if keeps > 0:
		return "Noch 1 Einbau" if keeps == 1 else "Noch %d Einbauten" % keeps
	var free := int(state.get("free_bonus", 0))
	if free > 0:
		return "Freie Hand +%d" % free
	return ""

## Pixel je Stations-Einheit (die knappere Achse gewinnt).
func unit() -> float:
	return minf(size.x / UNITS.x, size.y / UNITS.y)

## Ein Teil in eigenen Pixeln.
func part_rect(key: String) -> Rect2:
	var part: Rect2 = PARTS[key]
	return _to_px(Vector2(part.position.x, part.position.y), Vector2(part.size.x, part.size.y))

func _to_px(center: Vector2, extent: Vector2) -> Rect2:
	var k := unit()
	var mid := size * 0.5 + Vector2(center.x, -center.y) * k
	return Rect2(mid - extent * k * 0.5, extent * k)

## Alle Teile in eigenen Pixeln, dazu die Zellgröße.
func layout() -> Dictionary:
	var out := {}
	for key: String in PARTS:
		out[key] = part_rect(key)
	out["cell"] = net_cell()
	return out

## Die Mitte des Sitzes in eigenen Pixeln - dort liegt der Würfel.
func seat_px() -> Vector2:
	return part_rect("seat").get_center()

func seat_radius() -> float:
	var seat := part_rect("seat")
	return minf(seat.size.x, seat.size.y) * 0.5

func net_cell() -> float:
	return CELL * unit()

## Das Rechteck einer Kreuz-Zelle (eigene Pixel).
func cell_rect(face: int) -> Rect2:
	var at := LuckDie.net_cell(face)
	if at.x < 0:
		return Rect2()
	var net: Rect2 = PARTS["net"]
	var center := Vector2(net.position.x + (float(at.x) - 1.5) * CELL_STEP,
		net.position.y + (1.0 - float(at.y)) * CELL_STEP)
	return _to_px(center, Vector2(CELL, CELL))
