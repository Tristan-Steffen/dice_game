class_name CharmDiskTip
extends Control
## Der schlanke SCHLÜSSELWORT-TIP an einer Charm-Diskette (2026-11-18, Erbe des Charm-Docks):
## die Wirkung mit klickbaren Lexikon-Verweisen, an dem Anker, den scene_root meldet. Name und
## Wirkung trägt die Diskette selbst - der Tip ist nur der Weg ins Lexikon. Faßt keinen Körper an.

signal lexikon_requested(entry_id: String)

const FILL := Color(0.02, 0.03, 0.05, 0.94)
const EDGE_ALPHA := 0.75
const PAD_SHARE := 0.05
const FONT_SHARE := 0.075
const EDGE_SHARE := 0.008
const RADIUS_SHARE := 0.04

var charm_id := ""
var body: LexikonText
var _tint := Color.WHITE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_ensure()

func _ensure() -> void:
	if body != null:
		return
	body = LexikonText.new()
	body.entry_requested.connect(func(id: String) -> void: lexikon_requested.emit(id))
	add_child(body)

## Zeigt den Tip für charm, oben mittig am Anker (Display-Pixel), so breit wie width.
func show_for(charm: Charm, anchor: Vector2, width: float) -> void:
	_ensure()
	var pad := width * PAD_SHARE
	var px := maxi(8, int(width * FONT_SHARE))
	_tint = charm.rarity_color()
	if charm_id != charm.id:
		charm_id = charm.id
		body.set_source(charm.description, "charm:%s" % charm.id)
		if body.hint == null:
			body.attach_hint(self, width * 0.04)
	body.set_style(px, CasinoStyle.CREAM)
	var inner := width - pad * 2.0
	var height := body.measure(inner, px)
	size = Vector2(width, height + pad * 2.0)
	position = anchor - Vector2(width * 0.5, 0.0)
	body.position = Vector2(pad, pad)
	body.size = Vector2(inner, height)
	visible = true
	queue_redraw()

func hide_tip() -> void:
	visible = false
	charm_id = ""

func has_pixel(pixel: Vector2) -> bool:
	return visible and get_global_rect().has_point(pixel)

## Bewegung immer, ein Klick nur auf einem Schlüsselwort.
func takes_pixel(pixel: Vector2, is_click: bool) -> bool:
	if not has_pixel(pixel):
		return false
	return not is_click or body.keyword_at(pixel) != ""

func _draw() -> void:
	if not visible:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = FILL
	box.border_color = Color(_tint.r, _tint.g, _tint.b, EDGE_ALPHA)
	box.set_border_width_all(maxi(1, int(size.x * EDGE_SHARE)))
	box.set_corner_radius_all(maxi(2, int(size.x * RADIUS_SHARE)))
	draw_style_box(box, Rect2(Vector2.ZERO, size))
