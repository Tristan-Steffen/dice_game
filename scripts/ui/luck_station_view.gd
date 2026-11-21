class_name LuckStationView
extends Control
## Die GLÜCKS-STATION rechts neben dem Chip-Tray: Titel, der SITZ des Glückswürfels, sein
## aufgeklapptes Netz mit echten Augen, die Erwartung, der Glücks-Pegel und die Bonus-Zeile.
## Rein zeichnend: den Körper stellt scene_root auf den gemeldeten Sitz (seat_px).

const GOLD := Color("#ffd36a")
const FILL := Color(0.17, 0.12, 0.03, 0.86)
const FACE_FILL := Color(0.55, 0.4, 0.13)
const FACE_RIM := Color(0.78, 0.58, 0.2)
const PIP := Color(0.02, 0.36, 0.25)
const LAST_RIM := Color(1.0, 0.93, 0.62)
const DIM := Color(0.75, 0.66, 0.45)
const BAR_BACK := Color(0.08, 0.06, 0.02, 0.9)
const LAMP_ON := Color(0.55, 1.0, 0.55)

## Breite als Anteil der Tray-Breite.
const WIDTH_SHARE := 0.6
const FRAME_SHARE := 0.025
## Die Blöcke von oben nach unten, in u (= Breite / 100); die Lücken teilen den Rest.
const PAD_UNITS := 6.0
const TITLE_UNITS := 9.0
const TITLE_FONT_UNITS := 6.5
const SEAT_UNITS := 50.0
const LINE_UNITS := 10.0
const LINE_FONT_UNITS := 7.0
const SMALL_FONT_UNITS := 5.6
const BAR_UNITS := 3.2
const GAUGE_UNITS := 13.0
const BONUS_UNITS := 9.0
## Augen in Zellanteilen (die Lagen des Körpers: Spreizung 0,52, Radius 0,17 der halben Kante).
const PIP_SPREAD := 0.26
const PIP_RADIUS := 0.09
const GAP_FACTOR := 0.1

var _faces: Array[int] = [1, 1, 1, 1, 1, 1]
var _last_face := -1
var _state := {}
var _key := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

## Der Platz: rechts neben dem Tray, so hoch wie es und oben bündig; nie über limit_x hinaus.
static func placed_beside(tray_rect: Rect2, gap: float, limit_x := INF) -> Rect2:
	var x := tray_rect.end.x + gap
	var width := minf(tray_rect.size.x * WIDTH_SHARE, limit_x - x)
	return Rect2(Vector2(x, tray_rect.position.y), Vector2(maxf(width, 0.0), tray_rect.size.y))

## Das Netz bei Zellgröße cell (4 × 3 Zellen samt Lücken).
static func net_size(cell: float) -> Vector2:
	var gap := cell * GAP_FACTOR
	return Vector2(4.0 * cell + 3.0 * gap, 3.0 * cell + 2.0 * gap)

static func expected_text(expected: float) -> String:
	return "Ø %s Wahlen" % ("%.1f" % expected).replace(".", ",")

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

## Der EINE Schreiber: nur der Wechsel malt neu.
func set_state(faces: Array, last_face: int, state: Dictionary) -> void:
	var key := "%s|%d|%s" % [str(faces), last_face, str(state)]
	if key == _key:
		return
	_key = key
	_faces.assign(faces)
	_last_face = last_face
	_state = state.duplicate()
	queue_redraw()

func shown_faces() -> Array[int]:
	return _faces.duplicate()

func last_face() -> int:
	return _last_face

func unit() -> float:
	return size.x / 100.0

func frame_px() -> float:
	return maxf(2.0, size.x * FRAME_SHARE)

## Die Blöcke in eigenen Pixeln: title, seat, net, expected, gauge, bonus.
func layout() -> Dictionary:
	var u := unit()
	var pad := PAD_UNITS * u
	var inner := size.x - pad * 2.0
	var cell := inner / net_size(1.0).x
	var heights := [TITLE_UNITS * u, SEAT_UNITS * u, net_size(cell).y, LINE_UNITS * u,
		GAUGE_UNITS * u, BONUS_UNITS * u]
	var need := pad * 2.0
	for h: float in heights:
		need += h
	# Reicht die Höhe nicht, schrumpft alles gleichmäßig.
	var fit := minf(1.0, size.y / maxf(need, 1.0))
	var gap := maxf(0.0, size.y - need * fit) / float(heights.size() + 1)
	var y := pad * fit + gap
	var rects: Array[Rect2] = []
	for h: float in heights:
		var tall := h * fit
		rects.append(Rect2(Vector2(pad, y), Vector2(inner, tall)))
		y += tall + gap
	var net := rects[2]
	var net_px := net_size(cell * fit)
	net = Rect2(Vector2(net.get_center().x - net_px.x * 0.5, net.position.y), net_px)
	return {"title": rects[0], "seat": rects[1], "net": net, "expected": rects[3],
		"gauge": rects[4], "bonus": rects[5], "cell": cell * fit}

## Die Mitte des Sitzes in eigenen Pixeln - dort liegt der Körper.
func seat_px() -> Vector2:
	return (layout()["seat"] as Rect2).get_center()

func seat_radius() -> float:
	var seat: Rect2 = layout()["seat"]
	return minf(seat.size.x, seat.size.y) * 0.5

func net_cell() -> float:
	return layout()["cell"]

## Das Rechteck einer Netz-Zelle (eigene Pixel).
func cell_rect(face: int) -> Rect2:
	var lay := layout()
	var net: Rect2 = lay["net"]
	var cell: float = lay["cell"]
	var at := LuckDie.net_cell(face)
	if at.x < 0:
		return Rect2()
	var step := cell * (1.0 + GAP_FACTOR)
	return Rect2(net.position + Vector2(at.x, at.y) * step, Vector2(cell, cell))

func _draw() -> void:
	var f := frame_px()
	var u := unit()
	var body := StyleBoxFlat.new()
	body.bg_color = FILL
	body.border_color = GOLD
	body.set_border_width_all(maxi(2, int(f * 0.5)))
	body.set_corner_radius_all(int(f * 2.0))
	draw_style_box(body, Rect2(Vector2.ZERO, size))
	var lay := layout()
	var font := ThemeDB.fallback_font
	_text(font, lay["title"], "GLÜCKSWÜRFEL", int(TITLE_FONT_UNITS * u), GOLD)
	_draw_seat(lay["seat"])
	for face in LuckDie.FACES:
		_draw_face(face, cell_rect(face))
	_text(font, lay["expected"], expected_text(_expected()), int(LINE_FONT_UNITS * u), GOLD)
	_draw_gauge(font, lay["gauge"], u)
	_draw_bonus(font, lay["bonus"], u)

func _expected() -> float:
	var sum := 0
	for v in _faces:
		sum += v
	return float(sum) / float(LuckDie.FACES)

func _text(font: Font, rect: Rect2, text: String, font_size: int, color: Color) -> void:
	font_size = maxi(6, font_size)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var base := rect.get_center().y + font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.5
	draw_string(font, Vector2(rect.get_center().x - w * 0.5, base), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_seat(rect: Rect2) -> void:
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.5
	draw_circle(c, r, Color(0.05, 0.035, 0.01, 0.95))
	draw_arc(c, r, 0.0, TAU, 64, GOLD, maxf(2.0, r * 0.06), true)
	draw_arc(c, r * 0.82, 0.0, TAU, 64, Color(GOLD.r, GOLD.g, GOLD.b, 0.35), maxf(1.0, r * 0.02), true)

func _draw_face(face: int, rect: Rect2) -> void:
	if rect.size.x <= 0.0:
		return
	var last := face == _last_face
	var box := StyleBoxFlat.new()
	box.bg_color = FACE_FILL
	box.border_color = LAST_RIM if last else FACE_RIM
	box.set_border_width_all(maxi(1, int(rect.size.x * (0.09 if last else 0.04))))
	box.set_corner_radius_all(int(rect.size.x * 0.14))
	draw_style_box(box, rect)
	var c := rect.get_center()
	# Seiten-Koordinaten (x Bild-oben, y Bild-rechts am Körper) → Netz: (y, -x).
	for at: Vector2 in LuckDie.pip_layout(_faces[face]):
		draw_circle(c + Vector2(at.y, -at.x) * rect.size.x * PIP_SPREAD,
			rect.size.x * PIP_RADIUS, PIP)

func _draw_gauge(font: Font, rect: Rect2, u: float) -> void:
	var bar_h := BAR_UNITS * u
	var bar := Rect2(rect.position, Vector2(rect.size.x, bar_h))
	draw_rect(bar, BAR_BACK)
	var share := gauge_share(_state)
	if share > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar_h)), GOLD)
	draw_rect(bar, Color(GOLD.r, GOLD.g, GOLD.b, 0.6), false, 1.0)
	var line := Rect2(Vector2(rect.position.x, bar.end.y), Vector2(rect.size.x, rect.size.y - bar_h))
	_text(font, line, gauge_text(_state), int(SMALL_FONT_UNITS * u), DIM)

func _draw_bonus(font: Font, rect: Rect2, u: float) -> void:
	var text := bonus_text(_state)
	if text == "":
		return
	var lamp_on := int(_state.get("keeps", 0)) <= 0
	var font_size := maxi(6, int(SMALL_FONT_UNITS * u))
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var lamp_r := font_size * 0.32
	var total := lamp_r * 2.0 + font_size * 0.4 + w
	var x := rect.get_center().x - total * 0.5
	var cy := rect.get_center().y
	draw_circle(Vector2(x + lamp_r, cy), lamp_r, LAMP_ON if lamp_on else GOLD)
	if lamp_on:
		draw_circle(Vector2(x + lamp_r, cy), lamp_r * 1.9, Color(LAMP_ON.r, LAMP_ON.g, LAMP_ON.b, 0.18))
	var base := cy + font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.5
	draw_string(font, Vector2(x + lamp_r * 2.0 + font_size * 0.4, base), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, GOLD)
