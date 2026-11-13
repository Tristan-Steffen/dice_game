class_name TreasureChestView
extends Control
## Die FASSUNG des Chip-Trays: goldener Rahmen um die Grube, links der RINNEN-KOPF
## je Stückelung (Wert, bei den 10.000ern die ×n-Marke). Rein zeichnend - die Grube
## selbst schneidet das Glas, die Chips gehören scene_root. Meldet Grubenrechteck,
## Rinnen-Köpfe und -Ausläufe in eigenen Pixeln; Rinne 0 (die 1er) liegt unten.

const GOLD := Color("#ffd36a")
const FILL := Color(0.17, 0.12, 0.03, 0.86)

## Rahmenstärke und Kopfspalte als Anteil der Breite.
const FRAME_SHARE := 0.015
const HEAD_SHARE := 0.075
const RANKS := 7
const TOP_RANK := 6
const SLOTS := 5

var _glint := 0.0
var _glint_tween: Tween
var _in_flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _out_flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _in_color: Array[Color] = [GOLD, GOLD, GOLD, GOLD, GOLD, GOLD, GOLD]
var _out_color: Array[Color] = [GOLD, GOLD, GOLD, GOLD, GOLD, GOLD, GOLD]
var _top_count := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

## Der Platz der Fassung: genau das Rechteck des Wett-Tresens, eine Fuge rechts daneben.
static func placed_beside(side_rect: Rect2, gap: float) -> Rect2:
	return Rect2(Vector2(side_rect.end.x + gap, side_rect.position.y), side_rect.size)

func frame_px() -> float:
	return maxf(2.0, size.x * FRAME_SHARE)

func head_px() -> float:
	return size.x * HEAD_SHARE

## Das Loch der Grube in eigenen Pixeln.
func pit_rect() -> Rect2:
	var f := frame_px()
	var head := head_px()
	return Rect2(Vector2(head, f), Vector2(size.x - head - f, size.y - f * 2.0))

func pit_radius() -> float:
	return frame_px()

## Mitte einer Rinne (senkrecht) - Rinne 0 unten.
func row_y(rank: int) -> float:
	var pit := pit_rect()
	return pit.position.y + pit.size.y * (1.0 - (float(rank) + 0.5) / float(RANKS))

## Die Schiene im Kopf, auf der die Kometen herauf- und hinunterlaufen.
func rail_x() -> float:
	return head_px() - frame_px()

## Wo ein Chip-Komet am Kopf einer Rinne landet bzw. ein Zahl-Komet am Auslauf startet.
func entry_px(rank: int) -> Vector2:
	return Vector2(rail_x(), row_y(rank))

func exit_px(rank: int) -> Vector2:
	return Vector2(size.x - frame_px() * 0.5, row_y(rank))

## Die Zahl der 10.000er (ab der zweiten Lage nennt der Kopf sie).
func set_top_count(count: int) -> void:
	if count == _top_count:
		return
	_top_count = count
	queue_redraw()

func glint() -> void:
	if _glint_tween != null:
		_glint_tween.kill()
	_glint_tween = create_tween()
	_glint_tween.tween_method(func(v: float) -> void:
		_glint = v
		queue_redraw(), 1.0, 0.0, 0.6).set_trans(Tween.TRANS_SINE)

## Kopf bzw. Auslauf einer Rinne blitzt in Chipfarbe.
func flash_entry(rank: int, color: Color) -> void:
	_flash(rank, color, true)

func flash_exit(rank: int, color: Color) -> void:
	_flash(rank, color, false)

func _flash(rank: int, color: Color, entry: bool) -> void:
	if rank < 0 or rank >= RANKS:
		return
	if entry:
		_in_color[rank] = color
	else:
		_out_color[rank] = color
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		if entry:
			_in_flash[rank] = v
		else:
			_out_flash[rank] = v
		queue_redraw(), 1.0, 0.0, 0.45).set_trans(Tween.TRANS_SINE)

func _draw() -> void:
	var f := frame_px()
	var accent := GOLD.lerp(Color(2.2, 1.8, 0.9), _glint)
	var body := StyleBoxFlat.new()
	body.bg_color = FILL
	body.border_color = accent
	body.set_border_width_all(maxi(2, int(f * 0.5)))
	body.set_corner_radius_all(int(f * 2.0))
	draw_style_box(body, Rect2(Vector2.ZERO, size))
	var pit := pit_rect()
	var font := ThemeDB.fallback_font
	var row_h := pit.size.y / float(RANKS)
	var fsize := maxi(6, int(minf(head_px() * 0.34, row_h * 0.3)))
	for rank in RANKS:
		var value: int = ChipTrayView.VALUES[rank]
		var color := ChipStackView.denomination_color(value)
		var y := row_y(rank)
		# Kopf-Blitz: der Komet ist angekommen.
		if _in_flash[rank] > 0.01:
			var c := _in_color[rank]
			draw_rect(Rect2(Vector2(f, y - row_h * 0.45), Vector2(head_px() - f, row_h * 0.9)),
				Color(c.r, c.g, c.b, _in_flash[rank] * 0.45))
		if _out_flash[rank] > 0.01:
			var c := _out_color[rank]
			draw_rect(Rect2(Vector2(pit.end.x, y - row_h * 0.45), Vector2(f, row_h * 0.9)),
				Color(c.r * 2.0, c.g * 2.0, c.b * 2.0, _out_flash[rank]))
		var text := ChipStackView.value_label(value)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize).x
		var cx := (f + rail_x()) * 0.5
		draw_string(font, Vector2(cx - tw * 0.5, y + fsize * 0.35), text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, color.lerp(Color.WHITE, 0.15))
		if rank == TOP_RANK and _top_count > SLOTS:
			var mark := "×%d" % _top_count
			var msize := maxi(5, int(fsize * 0.8))
			var mw := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_CENTER, -1, msize).x
			draw_string(font, Vector2(cx - mw * 0.5, y + fsize * 0.35 + msize * 1.2), mark,
				HORIZONTAL_ALIGNMENT_CENTER, -1, msize, GOLD)
	# Die Kometen-Schiene im Kopf: eine dünne Goldlinie längs der Grube.
	draw_rect(Rect2(Vector2(rail_x() - 0.5, pit.position.y), Vector2(1.0, pit.size.y)),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.35))
