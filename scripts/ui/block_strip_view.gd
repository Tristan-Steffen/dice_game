class_name BlockStripView
extends Control
## Der BLOCK-STREIFEN der Hub-Startseite: oben der HITZE-PEGEL (fünf Felder, das
## aktuelle benannt, dahinter gestrichelt Weißglut), darunter die sechs Runden des
## Blocks mit Blind - geschaffte in der Farbe ihrer Hitze samt Wahl-Wort, die laufende
## hervorgehoben, kommende gestrichelt, die sechste der Pit Boss. Reine Anzeige aus
## GameRun.block_strip_state().

const BOSS_NAME := "Pit Boss"
const BOSS_PAYS := "zahlt nach Hitze"
const METER_TITLE := "Hitze"
## Anteil der Höhe für den Pegel, Fugen in u.
const METER_SHARE := 0.34
const ROW_GAP_UNITS := 1.0
const STOP_GAP_UNITS := 0.8
const RADIUS_UNITS := 0.7
const DASH_UNITS := 0.9

## Die Einheit des Hubs (HubView reicht sie herein).
var unit_px := 8.0
var state: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_state(view_state: Dictionary) -> void:
	if view_state == state:
		return
	state = view_state.duplicate(true)
	queue_redraw()

func stops() -> Array:
	return state.get("stops", [])

func heat() -> int:
	return int(state.get("heat", GameRun.HEAT_MIN))

## Rechteck des Pegels samt Titel (lokal).
func meter_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x, size.y * METER_SHARE))

## Die Felder des Pegels: HEAT_MIN..HEAT_WHITE (das letzte ist Weißglut).
func meter_cells() -> Array[Rect2]:
	var r := meter_rect()
	var title_w := size.x * 0.13
	var gap := unit_px * STOP_GAP_UNITS * 0.5
	var count := GameRun.HEAT_WHITE
	var w := (r.size.x - title_w - gap * float(count)) / float(count)
	var cells: Array[Rect2] = []
	for i in count:
		cells.append(Rect2(title_w + gap + float(i) * (w + gap), r.position.y, maxf(w, 1.0), r.size.y))
	return cells

## Die sechs Stops (lokal).
func stop_rects() -> Array[Rect2]:
	var top := size.y * METER_SHARE + unit_px * ROW_GAP_UNITS
	var h := maxf(size.y - top, 1.0)
	var gap := unit_px * STOP_GAP_UNITS
	var count := maxi(1, stops().size())
	var w := (size.x - gap * float(count - 1)) / float(count)
	var rects: Array[Rect2] = []
	for i in count:
		rects.append(Rect2(float(i) * (w + gap), top, maxf(w, 1.0), h))
	return rects

## Die drei Zeilen eines Stops: Kopf, Blind, Fuß.
static func stop_lines(stop: Dictionary) -> Array[String]:
	var boss := bool(stop.get("boss", false))
	var head := BOSS_NAME if boss else "Runde %d" % int(stop.get("round", 0))
	var blind := BigNumber.short(int(stop.get("blind", 0)))
	var foot := ""
	if boss:
		foot = BOSS_PAYS
	elif String(stop.get("state", "")) == GameRun.STOP_DONE:
		foot = HeatStyle.pick_word(String(stop.get("pick", "")))
	elif String(stop.get("state", "")) == GameRun.STOP_NOW:
		var pick := String(stop.get("pick", ""))
		foot = "Deal wählen" if pick == "" and bool(stop.get("pending", false)) else HeatStyle.pick_word(pick)
	return [head, blind, foot]

## Farbe eines Stops: geschafft/laufend in der Farbe seiner Hitze, kommend gedämpft.
func stop_color(stop: Dictionary) -> Color:
	if bool(stop.get("boss", false)) and String(stop.get("state", "")) == GameRun.STOP_AHEAD:
		return HeatStyle.BOSS_COLOR
	var level := int(stop.get("heat", 0))
	if level <= 0:
		level = heat() if String(stop.get("state", "")) == GameRun.STOP_NOW else 0
	return HeatStyle.color(level) if level > 0 else HeatStyle.MUTED_COLOR

func _font() -> Font:
	return get_theme_default_font()

func _draw() -> void:
	if size.x < 10.0 or size.y < 10.0:
		return
	_draw_meter()
	var rects := stop_rects()
	var list := stops()
	for i in mini(rects.size(), list.size()):
		var stop: Dictionary = list[i].duplicate()
		stop["pending"] = bool(state.get("pending", false))
		_draw_stop(rects[i], stop)

func _draw_meter() -> void:
	var r := meter_rect()
	_draw_text(Rect2(r.position, Vector2(size.x * 0.12, r.size.y)), METER_TITLE,
		r.size.y * 0.5, HeatStyle.MUTED_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	var cells := meter_cells()
	var radius := unit_px * RADIUS_UNITS
	for i in cells.size():
		var level := i + 1
		var cell := cells[i]
		var tint := HeatStyle.color(level)
		if level == GameRun.HEAT_WHITE:
			_dashed_rect(cell, Color(tint, 0.7), maxf(1.5, unit_px * 0.2))
			_draw_text(cell, HeatStyle.level_name(level), cell.size.y * 0.42, Color(tint, 0.7))
			continue
		var lit := level <= heat()
		var box := StyleBoxFlat.new()
		box.bg_color = Color(tint, 0.9 if level == heat() else (0.35 if lit else 0.06))
		box.border_color = Color(tint, 1.0 if lit else 0.35)
		box.set_border_width_all(maxi(1, int(unit_px * (0.35 if level == heat() else 0.15))))
		box.set_corner_radius_all(int(radius))
		draw_style_box(box, cell)
		if level == heat():
			_draw_text(cell, HeatStyle.level_name(level), cell.size.y * 0.5, Color("#14101e"))

func _draw_stop(rect: Rect2, stop: Dictionary) -> void:
	var tint := stop_color(stop)
	var mode := String(stop.get("state", ""))
	var radius := unit_px * RADIUS_UNITS
	if mode == GameRun.STOP_AHEAD:
		_dashed_rect(rect, Color(tint, 0.6), maxf(1.5, unit_px * 0.18))
	else:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(tint, 0.28 if mode == GameRun.STOP_DONE else 0.16)
		box.border_color = Color.WHITE if mode == GameRun.STOP_NOW else Color(tint, 0.9)
		box.set_border_width_all(maxi(1, int(unit_px * (0.45 if mode == GameRun.STOP_NOW else 0.2))))
		box.set_corner_radius_all(int(radius))
		draw_style_box(box, rect)
	var lines := stop_lines(stop)
	var pad := unit_px * 0.6
	var inner := rect.grow(-pad)
	var line_h := inner.size.y / 3.0
	var text_tint := HeatStyle.TEXT_COLOR if mode != GameRun.STOP_AHEAD else HeatStyle.MUTED_COLOR
	_draw_text(Rect2(inner.position, Vector2(inner.size.x, line_h)), lines[0], line_h * 0.62,
		tint if bool(stop.get("boss", false)) else HeatStyle.MUTED_COLOR)
	_draw_text(Rect2(inner.position + Vector2(0.0, line_h), Vector2(inner.size.x, line_h)), lines[1],
		line_h * 0.9, text_tint)
	_draw_text(Rect2(inner.position + Vector2(0.0, line_h * 2.0), Vector2(inner.size.x, line_h)),
		lines[2], line_h * 0.58, tint if mode != GameRun.STOP_AHEAD or bool(stop.get("boss", false)) \
		else HeatStyle.MUTED_COLOR)

## Text mittig in rect, so groß wie möglich bis max_size.
func _draw_text(rect: Rect2, text: String, max_size: float, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var font := _font()
	if font == null or text == "":
		return
	var font_size := maxi(6, int(max_size))
	while font_size > 6 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x:
		font_size -= 1
	var ascent := font.get_ascent(font_size)
	var height := font.get_height(font_size)
	var y := rect.position.y + (rect.size.y - height) * 0.5 + ascent
	draw_string(font, Vector2(rect.position.x, y), text, align, rect.size.x, font_size, color)

func _dashed_rect(rect: Rect2, color: Color, width: float) -> void:
	var dash := unit_px * DASH_UNITS
	var a := rect.position
	var b := Vector2(rect.end.x, rect.position.y)
	var c := rect.end
	var d := Vector2(rect.position.x, rect.end.y)
	for seg in [[a, b], [b, c], [c, d], [d, a]]:
		draw_dashed_line(seg[0], seg[1], color, width, dash)
