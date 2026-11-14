class_name PackStoreView
extends Control
## Das PAKET-LAGER rechts vom Chip-Tray: drei schmale RINNEN ÜBEREINANDER (Karten, Würfel,
## Module), je ein Kopf (Name, n/12) darüber. In einer Rinne STEHEN die Pakete hochkant wie
## Chips im Tray - von oben liest nur ihr RÜCKEN. Rein zeichnend und meldend: die Körper
## stellt scene_root, die Gruben schneidet TableScreen. Die Breite folgt dem dicksten
## Paket, die Höhe ist die des Chip-Trays daneben.

const GOLD := Color("#ffd36a")
const TEXT := Color(1.25, 1.25, 1.2)
const MUTED := Color(0.62, 0.64, 0.78)
const LOCKED_TINT := Color(1.0, 0.45, 0.4)
## Plätze je Rinne (= GameRun.STORE_CAPACITY) - eine Lage, der Platz ist der Index.
const PLACES := 12
## Fuge zwischen zwei Rücken, in Anteilen der dicksten Paketdicke.
const GAP_SHARE := 0.12
## Rand der Rinne, Rahmen und Kopf - in Anteilen der Paketbreite (quer zur Rinne).
const EDGE_SHARE := 0.06
const FRAME_SHARE := 0.045
const HEAD_SHARE := 0.2
const FONT_SHARE := 0.66
## Die Rinnen von oben nach unten (= GameRun.LANE_*).
const LANES := 3
const LANE_NAMES := ["KARTEN-PAKETE", "WÜRFEL-PAKETE", "MODUL-PAKETE"]

## Der RÜCKEN eines stehenden Pakets in Display-Pixeln (gemeldet von scene_root):
## x = dickstes Paket (längs der Rinne), y = seine kurze Seite (quer).
var spine_px := Vector2(58, 135)
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
	return spine_px.x * GAP_SHARE

## Die Teilung der Rinne: dickstes Paket plus Fuge - jedes Paket hat denselben Platz.
func pitch_px() -> float:
	return spine_px.x + gap_px()

func edge_px() -> float:
	return spine_px.y * EDGE_SHARE

func frame_px() -> float:
	return maxf(2.0, spine_px.y * FRAME_SHARE)

func head_px() -> float:
	return spine_px.y * HEAD_SHARE

func pit_width() -> float:
	return pitch_px() * float(PLACES) + edge_px() * 2.0

## So breit wie zwölf Plätze samt Rand, so hoch wie drei Köpfe und Rinnen.
func preferred_size() -> Vector2:
	return Vector2(pit_width() + frame_px() * 2.0, min_height())

func min_height() -> float:
	return frame_px() * 2.0 + (head_px() + spine_px.y + edge_px() * 2.0) * float(LANES)

## Die Höhe einer Rinne: was die Fassung über Köpfe und Rahmen hinaus hat, zu gleichen Teilen.
func pit_height() -> float:
	var height := maxf(size.y, min_height())
	return (height - frame_px() * 2.0) / float(LANES) - head_px()

## Die Rinne einer Reihe in eigenen Pixeln (0 oben … 2 unten).
func lane_pit_rect(lane: int) -> Rect2:
	var f := frame_px()
	var top := f + float(lane) * (head_px() + pit_height()) + head_px()
	return Rect2(Vector2(f, top), Vector2(pit_width(), pit_height()))

func lane_head_rect(lane: int) -> Rect2:
	var pit := lane_pit_rect(lane)
	return Rect2(Vector2(pit.position.x, pit.position.y - head_px()), Vector2(pit.size.x, head_px()))

func pit_radius() -> float:
	return frame_px()

## Der Platz index (0 links am Tray … 11) einer Rinne: ein Streifen der Teilung über die
## volle Rinnenbreite - so bleibt auch das dünnste Paket treffbar.
func slot_rect(lane: int, index: int) -> Rect2:
	var pit := lane_pit_rect(lane)
	return Rect2(Vector2(pit.position.x + edge_px() + pitch_px() * float(index), pit.position.y),
		Vector2(pitch_px(), pit.size.y))

func slot_center(lane: int, index: int) -> Vector2:
	return slot_rect(lane, index).get_center()

## Welcher Platz liegt unter einem eigenen Pixel? {} = keiner.
func slot_at(local: Vector2) -> Dictionary:
	for lane in LANES:
		var pit := lane_pit_rect(lane)
		if not pit.has_point(local):
			continue
		var index := floori((local.x - pit.position.x - edge_px()) / pitch_px())
		if index >= 0 and index < PLACES:
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
	var text := "%s  %d/%d" % [name, count, PLACES]
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
		label.position = rect.position + Vector2(edge_px(), 0.0)
		label.size = Vector2(rect.size.x - edge_px() * 2.0, rect.size.y)
		label.add_theme_font_size_override("font_size", maxi(8, int(rect.size.y * FONT_SHARE)))
		label.text = head_text(i, counts[i], locked)
		var full := counts[i] >= PLACES
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
