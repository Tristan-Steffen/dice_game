class_name PackStoreView
extends Control
## Das PAKET-LAGER rechts vom Chip-Tray: drei Gruben NEBENEINANDER (Karten, Würfel,
## Module), je ein Kopf (Name, n/12) darüber, darin sechs Plätze quer in 2 × 3 - ab dem
## siebten Paket einer Art liegt eine zweite LAGE darauf. Rein zeichnend und meldend - die
## Körper (samt Stapel) stellt scene_root, die Gruben schneidet TableScreen. Die Breite
## folgt dem Inhalt (gemeldeter Paket-Grundriß), die Höhe ist die des Chip-Trays daneben.

const GOLD := Color("#ffd36a")
const TEXT := Color(1.25, 1.25, 1.2)
const MUTED := Color(0.62, 0.64, 0.78)
const LOCKED_TINT := Color(1.0, 0.45, 0.4)
## Die Plätze einer Grube: zwei Spalten, drei Zeilen, zwei Lagen (= GameRun.STORE_CAPACITY).
const COLUMNS := 2
const ROWS := 3
const LAYERS := 2
const PLACES := COLUMNS * ROWS
## Rand zwischen Paket und Grubenwand - eine Spur mehr als die Fuge, damit nichts gequetscht liest.
const EDGE_SHARE := 0.09
## Fuge zwischen zwei Paketen, Rahmen und Kopf - in Anteilen der Paket-Höhe.
const GAP_SHARE := 0.08
const FRAME_SHARE := 0.045
const HEAD_SHARE := 0.32
const FONT_SHARE := 0.62
## Die Reihen von links nach rechts (= GameRun.LANE_*).
const LANES := 3
const LANE_NAMES := ["KARTEN-PAKETE", "WÜRFEL-PAKETE", "MODUL-PAKETE"]

## Der Grundriß eines liegenden Pakets in Display-Pixeln (gemeldet von scene_root).
var item_px := Vector2(202, 135)
var counts: Array[int] = [0, 0, 0]
## In der Runde gesperrt: grau, und der Kopf sagt warum.
var locked := false
var _heads: Array[Label] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _ready() -> void:
	resized.connect(_layout)

func gap_px() -> float:
	return item_px.y * GAP_SHARE

func frame_px() -> float:
	return maxf(2.0, item_px.y * FRAME_SHARE)

func head_px() -> float:
	return item_px.y * HEAD_SHARE

## Die Breite, die das Lager braucht: drei Gruben zu je zwei Paketen nebeneinander.
func preferred_size() -> Vector2:
	return Vector2(pit_width() * float(LANES) + frame_px() * 2.0 * float(LANES), min_height())

## Mindestens so hoch wie Kopf und alle Zeilen samt Fugen.
func min_height() -> float:
	return frame_px() * 2.0 + head_px() + item_px.y * ROWS + gap_px() * (ROWS + 1)

func edge_px() -> float:
	return item_px.y * EDGE_SHARE

func pit_width() -> float:
	return item_px.x * COLUMNS + gap_px() * (COLUMNS - 1) + edge_px() * 2.0

func pit_size() -> Vector2:
	return Vector2(pit_width(), maxf(size.y, min_height()) - frame_px() * 2.0 - head_px())

## Die Grube einer Reihe in eigenen Pixeln (0 links … 2 rechts).
func lane_pit_rect(lane: int) -> Rect2:
	var f := frame_px()
	return Rect2(Vector2(f + float(lane) * (pit_width() + f * 2.0), f + head_px()), pit_size())

func lane_head_rect(lane: int) -> Rect2:
	var pit := lane_pit_rect(lane)
	return Rect2(Vector2(pit.position.x, pit.position.y - head_px()), Vector2(pit.size.x, head_px()))

func pit_radius() -> float:
	return frame_px()

## Die Mitte von Lagerplatz slot (0..11; die obere Lage liegt über Platz slot % 6) in
## eigenen Pixeln; die Zeilen teilen sich die Höhe der Grube gleichmäßig.
func slot_center(lane: int, slot: int) -> Vector2:
	var pit := lane_pit_rect(lane)
	var place := slot % PLACES
	var col := place % COLUMNS
	var row := place / COLUMNS
	var air := (pit.size.y - item_px.y * ROWS) / float(ROWS + 1)
	return pit.position + Vector2(edge_px() + item_px.x * 0.5 + float(col) * (item_px.x + gap_px()),
		air + item_px.y * 0.5 + float(row) * (item_px.y + air))

## Welcher sichtbare Platz (0..5) liegt unter einem eigenen Pixel? {} = keiner.
func slot_at(local: Vector2) -> Dictionary:
	for lane in LANES:
		for index in PLACES:
			var center := slot_center(lane, index)
			if Rect2(center - item_px * 0.5, item_px).has_point(local):
				return {"lane": lane, "index": index}
	return {}

## Der EINE Eingang: je Reihe ihr Füllstand, und ob gesperrt ist.
func set_state(lane_counts: Array, is_locked: bool) -> void:
	var fresh: Array[int] = []
	for lane in LANES:
		fresh.append(int(lane_counts[lane]) if lane < lane_counts.size() else 0)
	if fresh == counts and locked == is_locked and not _heads.is_empty():
		return
	counts = fresh
	locked = is_locked
	_layout()

## Der Kopf einer Reihe: Name, Füllstand und - gesperrt - warum.
static func head_text(lane: int, count: int, is_locked: bool) -> String:
	var name := String(LANE_NAMES[clampi(lane, 0, LANES - 1)])
	var text := "%s  %d/%d" % [name, count, PLACES * LAYERS]
	return text + "  ·  öffnen nach der Runde" if is_locked else text

func _layout() -> void:
	if _heads.is_empty():
		for i in LANES:
			var label := CasinoStyle.label("", 12.0, TEXT, HORIZONTAL_ALIGNMENT_LEFT, 2)
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.clip_text = true
			add_child(label)
			_heads.append(label)
	for i in LANES:
		var rect := lane_head_rect(i)
		var label := _heads[i]
		label.position = rect.position + Vector2(gap_px(), 0.0)
		label.size = Vector2(rect.size.x - gap_px() * 2.0, rect.size.y)
		label.add_theme_font_size_override("font_size", maxi(8, int(rect.size.y * FONT_SHARE)))
		label.text = head_text(i, counts[i], locked)
		var full := counts[i] >= PLACES * LAYERS
		label.add_theme_color_override("font_color",
			MUTED if locked else (LOCKED_TINT if full else TEXT))
	queue_redraw()

func _draw() -> void:
	var f := frame_px()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.05, 0.11, 0.86)
	box.border_color = Color(GOLD, 0.55 if locked else 0.9)
	box.set_border_width_all(int(ceil(f)))
	box.set_corner_radius_all(int(f * 3.0))
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	for lane in LANES:
		var pit := lane_pit_rect(lane)
		draw_rect(pit.grow(f * 0.6), Color(GOLD, 0.35), false, maxf(1.0, f * 0.5))
