class_name SecretShopInfoView
extends Control
## Das INFO-DISPLAY auf dem Dach des Schwarzmarkts: der frühere INFO-FUSS in einem eigenen
## SubViewport (scene_root reicht ihn dem Körper). In Ruhe steht allein „SCHWARZMARKT“, beim
## Hover Titel und Wirkung der Ware. Ein Würfel spricht wie in der Werkstatt: die
## Würfel-Auskunft (DieCardView) neben seinem Netz, und eine überfahrene Seite des Netzes
## tauscht sie gegen die Seiten-Auskunft (FaceCardView). Lexikon-Wörter trägt es nicht (OFFEN).

## Die Pixelgröße des Viewports: dasselbe Verhältnis wie das Display am Körper.
const PIXELS := Vector2i(1600, 254)
const PAD := 10.0
const TITLE_PX := 34
const BODY_STEPS := [26, 23, 20, 18, 16]
const IDLE_PX := 46
const VIOLET := Color(0.75, 0.35, 1.0)
const BG := Color(0.012, 0.01, 0.03)
## Die Würfel-Karte ist so breit wie in der Werkstatt-Auskunft, gemessen an ihrer Höhe.
const CARD_ASPECT := 3.0
const NET_GAP := 18.0
const HINT := "Zeiger auf eine Seite: ihre Auskunft"
const HINT_PX := 22
const HINT_COLOR := Color(0.55, 0.58, 0.7)

var _title: Label
var _body: Label
var _idle: Label
var _hint: Label
var _die_card: DieCardView
var _face_card: FaceCardView
var _net_host: Control
var _cell := 0.0
var _key := "-"

func _init() -> void:
	size = Vector2(PIXELS)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = size
	add_child(bg)
	_idle = _label(IDLE_PX, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.55))
	_idle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_idle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_idle.position = Vector2.ZERO
	_idle.size = size
	_idle.text = SecretShopView.IDLE_TITLE
	_title = _label(TITLE_PX, CasinoStyle.GOLD)
	_body = _label(BODY_STEPS[0], CasinoStyle.CREAM)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_hint = _label(HINT_PX, HINT_COLOR)
	_hint.text = HINT
	_die_card = DieCardView.new()
	add_child(_die_card)
	_face_card = FaceCardView.new()
	add_child(_face_card)
	_net_host = Control.new()
	_net_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_net_host)
	clear()

func _label(px: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", CasinoStyle.SHADOW)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	return label

## Die Auskunft eines Fachs (SecretShopView.bay_info), beim Würfel samt der überfahrenen
## Seite (-1 = keine); nur der Wechsel schreibt.
func show_info(data: Dictionary, face := -1) -> void:
	if data.is_empty():
		clear()
		return
	var net: DieDefinition = data.get("net")
	if net == null or face < 0:
		face = -1
	var key := "%s|%s|%d|%d" % [String(data.get("title", "")), String(data.get("body", "")),
		net.get_instance_id() if net != null else 0, face]
	if key == _key:
		return
	_key = key
	_idle.visible = false
	_drop_net()
	var width := size.x - PAD * 2.0
	if net != null:
		width = _lay_die(net, face)
	else:
		_die_card.visible = false
		_die_card.show_die(null)
		_face_card.visible = false
		_face_card.show_face(null, -1)
		_hint.visible = false
	_title.text = String(data.get("title", ""))
	_title.position = Vector2(PAD, PAD * 0.5)
	_title.size = Vector2(width, TITLE_PX * 1.3)
	_title.visible = true
	if net != null:
		_body.visible = false
		_hint.position = Vector2(PAD, PAD * 0.5 + TITLE_PX * 1.4)
		_hint.size = Vector2(width, HINT_PX * 1.4)
		_hint.visible = true
		return
	var top := PAD * 0.5 + TITLE_PX * 1.3
	var room := Rect2(Vector2(PAD, top), Vector2(width, size.y - top - PAD * 0.5))
	_body.text = String(data.get("body", ""))
	_body.position = room.position
	_body.size = room.size
	_body.add_theme_font_size_override("font_size", body_px(_body.text, room.size))
	_body.visible = _body.text != ""

## Netz rechts, links daneben die Würfel- bzw. Seiten-Karte; liefert die Breite des Titels.
func _lay_die(net: DieDefinition, face: int) -> float:
	var inner := size.y - PAD * 2.0
	_cell = inner / DieNetView.net_size(1.0).y
	var view := DieNetView.build(net, face, _cell)
	var net_w := DieNetView.net_size(_cell).x
	_net_host.position = Vector2(size.x - PAD - net_w, PAD)
	_net_host.size = DieNetView.net_size(_cell)
	_net_host.add_child(view)
	var card := Rect2(Vector2(_net_host.position.x - NET_GAP - inner * CARD_ASPECT, PAD),
		Vector2(inner * CARD_ASPECT, inner))
	for view_card: Control in [_die_card, _face_card]:
		view_card.position = card.position
		view_card.size = card.size
	_face_card.visible = face >= 0
	_face_card.show_face(net if face >= 0 else null, face)
	_die_card.visible = face < 0
	_die_card.show_die(net if face < 0 else null)
	return card.position.x - PAD * 2.0

## Die Seite des gezeigten Netzes unter einem Viewport-Pixel (-1 = keine).
func face_at(pixel: Vector2) -> int:
	if _cell <= 0.0 or _net_host.get_child_count() == 0:
		return -1
	var face := DieNetView.face_at(pixel - _net_host.position, _cell)
	return face if face >= 0 else -1

func _drop_net() -> void:
	_cell = 0.0
	for child in _net_host.get_children():
		_net_host.remove_child(child)
		child.queue_free()

## Der größte Grad, in dem der Text umgebrochen in die Fläche paßt.
static func body_px(text: String, room: Vector2) -> int:
	var font := ThemeDB.fallback_font
	if font == null:
		return BODY_STEPS[BODY_STEPS.size() - 1]
	for px: int in BODY_STEPS:
		if ShopController.wrapped_height(font, text, room.x, px, 0) <= room.y:
			return px
	return BODY_STEPS[BODY_STEPS.size() - 1]

## Ruhe: dunkel bis auf „SCHWARZMARKT“.
func clear() -> void:
	if _key == "":
		return
	_key = ""
	_idle.visible = true
	_title.visible = false
	_body.visible = false
	_hint.visible = false
	_die_card.visible = false
	_die_card.show_die(null)
	_face_card.visible = false
	_face_card.show_face(null, -1)
	_drop_net()

func showing() -> String:
	return _title.text if _title.visible else ""

func die_card() -> DieCardView:
	return _die_card

func face_card() -> FaceCardView:
	return _face_card
