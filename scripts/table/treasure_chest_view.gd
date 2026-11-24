class_name TreasureChestView
extends Control
## Der PLATZ des Chip-Trays im Display: er malt nichts mehr (den Rahmen trägt der Körper
## ChipTrayDress), er MELDET Grubenrechteck, Kometen-Schiene, Rinnen-Köpfe und -Ausläufe in
## eigenen Pixeln - Rinne 0 (die 1er) liegt unten - und hält die Blitze als reine Daten,
## die scene_root je Bild an den Körper reicht.

## Rahmenstärke und Kopfspalte als Anteil der Breite.
const FRAME_SHARE := 0.015
const HEAD_SHARE := 0.075
const RANKS := 7
const TOP_RANK := 6
const SLOTS := 5
const FLASH_TIME := 0.45
const GLINT_TIME := 0.6

var _glint := 0.0
var _glint_tween: Tween
var _in_flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _out_flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _top_count := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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

## Die Takt-Schiene in der Kopfspalte, auf der die Kometen herauf- und hinunterlaufen.
func rail_x() -> float:
	return head_px() - frame_px()

## Wo ein Chip-Komet am Kopf einer Rinne landet bzw. ein Zahl-Komet am Auslauf startet.
func entry_px(rank: int) -> Vector2:
	return Vector2(rail_x(), row_y(rank))

func exit_px(rank: int) -> Vector2:
	return Vector2(size.x - frame_px() * 0.5, row_y(rank))

## Die Zahl der 10.000er (ab der sechsten nennt die Kappe sie).
func set_top_count(count: int) -> void:
	_top_count = count

func top_count() -> int:
	return _top_count

## Ein Gewinn: alle Kappen leuchten kurz auf.
func glint() -> void:
	if _glint_tween != null:
		_glint_tween.kill()
	_glint_tween = create_tween()
	_glint_tween.set_trans(Tween.TRANS_SINE)
	_glint_tween.tween_method(_set_glint, 1.0, 0.0, GLINT_TIME)

func _set_glint(v: float) -> void:
	_glint = v

## Kappe bzw. Statusring einer Rinne blitzt (die Farbe ist die der Rinne).
func flash_entry(rank: int, _color: Color) -> void:
	_flash(rank, true)

func flash_exit(rank: int, _color: Color) -> void:
	_flash(rank, false)

func glint_share() -> float:
	return _glint

func entry_flash(rank: int) -> float:
	return _in_flash[rank]

func exit_flash(rank: int) -> float:
	return _out_flash[rank]

func _flash(rank: int, entry: bool) -> void:
	if rank < 0 or rank >= RANKS:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_flash.bind(rank, entry), 1.0, 0.0, FLASH_TIME)

func _set_flash(v: float, rank: int, entry: bool) -> void:
	if entry:
		_in_flash[rank] = v
	else:
		_out_flash[rank] = v
