class_name WorkshopInfoView
extends Panel
## Der INFO-SCHIRM der Werkstatt (Layout E): ein BLOCK unter Vorschau und Prägen, der JEDE
## Auskunft der Station trägt - Netz-Zelle, Karte, Würfel, Ruhe.
##
## Oben der TITEL, daneben die Unterzeile in ihrer Farbe; darunter die WIRKUNG mehrzeilig
## (so groß, wie sie ungeschnitten in den Block paßt), am Fuß die GESTE gedämpft. Ein
## Würfel spricht statt der Wirkung über DieInfoBand (ROWS). Die Größe ist GEGEBEN (die
## Kette); er faßt nichts an.

## Ränder und Fugen zwischen den Zeilen, in u des STREIFENS.
const MARGIN_X := 2.4
const MARGIN_Y := 1.4
const ROW_GAP := 0.8
## Die Grade von Titel, Wirkung (größter) und Geste in u; LINE_BOX ist die Zeilenhöhe je
## Grad einer einzeiligen Zeile (gemessen ~1,42 samt Luft).
const TITLE_UNITS := 6.0
const BODY_UNITS := 5.4
const ACTION_UNITS := 4.2
const LINE_BOX := 1.5
## Die Unterzeile steht eine Spur kleiner als der Titel.
const SUB_SHARE := 0.85
## Die Fuge zwischen Titel und Unterzeile, in Schriftgraden.
const SUB_GAP_EM := 0.8
const ACTION_COLOR := Color(0.55, 0.58, 0.7)

## Die RUHE sagt den NÄCHSTEN SCHRITT.
const IDLE_TITLE := "Nächster Schritt"
const STEP_DIE_FIRST := "Würfel im Vorrat antippen"
const STEP_CARD := "Karte aus dem Magazin auf die Walze legen"
const STEP_DIE := "Würfel wählen"
const STEP_READY := "Prägen bereit"
const STEP_SPENT := "Geprägt — die nächste Prägung gibt es in der nächsten Runde"
## Liegt ein Rohling auf dem Podest, sagt der Schirm, was dort geschieht.
const PACKING_BODY := "Verdichten: die Karten der Reihe werden zu EINER. Zahlen und Multiplikatoren addieren sich, Material und Rune liegen danach auf derselben Seite."
## Die Unterzeile einer Netz-Zelle.
const CELL_SUB := "Zelle"
## Der Titel eines Würfels ohne Seele.
const SOULLESS := "Normal"
## Das Trennzeichen zweier Teile - dieselbe Fuge wie in DieNetView.
const JOIN := "  ·  "

## Die Maßeinheit u (0 = die u-Konvention, Fensterbreite/100). scene_root schiebt
## die des STREIFENS herein, damit beide dieselbe Schrift tragen.
var unit_px := 0.0:
	set(value):
		if is_equal_approx(unit_px, value):
			return
		unit_px = value
		_rebuild()

var _title: Label
var _sub: Label
var _body: Label
var _action: Label
## Die Signatur der gezeigten Auskunft - nur der WECHSEL schreibt (je Bild gefragt).
var _signature := ""
## Die letzte Auskunft, damit ein Neuaufbau sie ohne den Schreiber wiederholt.
var _shown := {"title": "", "sub": "", "sub_tint": Color.WHITE, "body": "", "action": ""}
## Der Würfel, über den der Schirm spricht (null = keiner): dann trägt die Würfel-Auskunft
## den Platz der Wirkung.
var _die: DieDefinition = null
var _die_face := -1
var _band: DieInfoBand
## Die SEITEN-AUSKUNFT: steht eine Seite (face >= 0), trägt sie den ganzen Schirm.
var _card: FaceCardView
## Die WÜRFEL-AUSKUNFT: steht ein ganzer Würfel (face < 0), trägt sie den ganzen Schirm.
var _die_card: DieCardView

func _init() -> void:
	name = "WorkshopInfoWindow"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Auskunft, kein Bedienteil

func _ready() -> void:
	_rebuild()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_rebuild()

func unit() -> float:
	if unit_px > 0.0:
		return unit_px
	return maxf(size.x, 200.0) / 100.0

## Der EINE Schreiber (scene_root, je Bild). Nur der WECHSEL schreibt.
func set_info(title: String, sub: String, sub_tint: Color, body: String,
		action := "") -> void:
	var signature := "%s|%s|%s|%s|%s" % [title, sub, sub_tint.to_html(false), body, action]
	if signature == _signature:
		return
	_signature = signature
	_shown = {"title": title, "sub": sub, "sub_tint": sub_tint, "body": body,
		"action": action}
	_paint()

## Der Würfel bzw. seine Seite für die Würfel-Auskunft (null = die Wirkung spricht).
func set_die(def: DieDefinition, face := -1) -> void:
	_die = def
	_die_face = face
	if _band == null or not is_instance_valid(_band):
		return
	_band.show_info(_die, _die_face)
	# Schweigt die Würfel-Auskunft (ohne Seele), spricht die Wirkung - nie eine leere Fläche.
	var speaks := _die != null and not _band.is_empty()
	_band.visible = speaks
	if _body != null and is_instance_valid(_body):
		_body.visible = not speaks
	_sync_card()

## Eine SEITE spricht über die Seiten-Karte, ein ganzer WÜRFEL über die Würfel-Karte,
## sonst die Zeilen.
func _sync_card() -> void:
	if _card == null or not is_instance_valid(_card) or _die_card == null 			or not is_instance_valid(_die_card):
		return
	var face_shown := _die != null and _die_face >= 0
	var die_shown := _die != null and _die_face < 0
	_card.visible = face_shown
	_card.show_face(_die if face_shown else null, _die_face)
	_die_card.visible = die_shown
	_die_card.show_die(_die if die_shown else null)
	for label: Label in labels():
		label.visible = not (face_shown or die_shown) and (label != _body or not _band.visible)
	if face_shown or die_shown:
		_band.visible = false

func die_card() -> DieCardView:
	return _die_card

func face_card() -> FaceCardView:
	return _card

func die_band() -> DieInfoBand:
	return _band

## Das Innere des Blocks in Fenster-Pixeln.
func inner_rect() -> Rect2:
	var u := unit()
	var pad := Vector2(u * MARGIN_X, u * MARGIN_Y)
	return Rect2(pad, (size - pad * 2.0).max(Vector2.ONE))

## Die Kopfzeile (Titel samt Unterzeile).
func head_rect() -> Rect2:
	var inner := inner_rect()
	return Rect2(inner.position, Vector2(inner.size.x,
		minf(unit() * TITLE_UNITS * LINE_BOX, inner.size.y)))

## Die Fußzeile (die Geste).
func action_rect() -> Rect2:
	var inner := inner_rect()
	var high := minf(unit() * ACTION_UNITS * LINE_BOX, inner.size.y)
	return Rect2(Vector2(inner.position.x, inner.end.y - high), Vector2(inner.size.x, high))

## Wo die Wirkung bzw. die Würfel-Auskunft steht: alles zwischen Kopf und Fuß.
func band_rect() -> Rect2:
	var head := head_rect()
	var foot := action_rect()
	var gap := unit() * ROW_GAP
	var top := head.end.y + gap
	return Rect2(Vector2(head.position.x, top),
		Vector2(head.size.x, maxf(foot.position.y - gap - top, 1.0)))

func title_text() -> String:
	return _title.text if _title != null and is_instance_valid(_title) else ""

func sub_text() -> String:
	return _sub.text if _sub != null and is_instance_valid(_sub) else ""

func body_text() -> String:
	return _body.text if _body != null and is_instance_valid(_body) else ""

func action_text() -> String:
	return _action.text if _action != null and is_instance_valid(_action) else ""

func title_font_size() -> int:
	return _font_of(_title)

func body_font_size() -> int:
	return _font_of(_body)

func action_font_size() -> int:
	return _font_of(_action)

func _font_of(label: Label) -> int:
	if label == null or not is_instance_valid(label):
		return 0
	return label.get_theme_font_size("font_size")

## Die Labels in Lese-Reihenfolge (für Tests: was abgeschnitten wäre, zeigt sich hier).
func labels() -> Array[Label]:
	var out: Array[Label] = []
	for label: Label in [_title, _sub, _body, _action]:
		if label != null and is_instance_valid(label):
			out.append(label)
	return out

# --- Die Fassung ------------------------------------------------------------

func _rebuild() -> void:
	if not is_inside_tree():
		return
	add_theme_stylebox_override("panel", TableScreen.window_style())
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_title = null
	_sub = null
	_body = null
	_action = null
	_band = null
	_card = null
	_die_card = null
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var head := head_rect()
	_title = _line("Titel", head, WorkshopView.TEXT_COLOR, false)
	_sub = _line("Unterzeile", head, WorkshopView.MUTED_COLOR, false)
	var middle := band_rect()
	_body = _line("Wirkung", middle, WorkshopView.MUTED_COLOR, true)
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_action = _line("Geste", action_rect(), ACTION_COLOR, true)
	_band = DieInfoBand.new()
	_band.name = "WuerfelAuskunft"
	_band.layout = DieInfoBand.Layout.ROWS
	add_child(_band)
	_band.position = middle.position
	_band.size = middle.size
	_card = FaceCardView.new()
	_card.name = "SeitenAuskunft"
	_card.visible = false
	add_child(_card)
	var inner := inner_rect()
	_card.position = inner.position
	_card.size = inner.size
	_die_card = DieCardView.new()
	_die_card.name = "WuerfelKarte"
	_die_card.visible = false
	add_child(_die_card)
	_die_card.position = inner.position
	_die_card.size = inner.size
	set_die(_die, _die_face)
	_paint()

## Eine Zeile des Schirms - Umbruch und clip_text VOR dem Maß, sonst klemmt die
## Mindestgröße das Label hoch.
func _line(line_name: String, rect: Rect2, tint: Color, wrap: bool) -> Label:
	var label := Label.new()
	label.name = line_name
	label.add_theme_color_override("font_color", tint)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.position = rect.position
	label.size = rect.size
	EffectText.colorize(label)
	return label

func _paint() -> void:
	if _title == null or not is_instance_valid(_title):
		return
	_title.text = String(_shown.get("title", ""))
	_sub.text = String(_shown.get("sub", ""))
	_sub.add_theme_color_override("font_color",
		_shown.get("sub_tint", WorkshopView.MUTED_COLOR))
	_body.text = String(_shown.get("body", ""))
	_action.text = String(_shown.get("action", ""))
	_fit()

## Titel und Unterzeile steigen gemeinsam ab, bis sie nebeneinander in den Kopf passen;
## Wirkung und Geste nehmen den größten Grad, in dem sie UNGESCHNITTEN in ihre Kiste
## passen - gemessen mit ShopController.wrapped_height, der ehrlichen Höhe samt
## Zeilenabstand.
func _fit() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var u := unit()
	var head := head_rect()
	var title_px := maxi(8, int(u * TITLE_UNITS))
	while title_px > 8 and (_head_width(font, title_px) > head.size.x
			or font.get_height(title_px) > head.size.y):
		title_px -= 1
	_title.add_theme_font_size_override("font_size", title_px)
	_sub.add_theme_font_size_override("font_size", maxi(8, int(title_px * SUB_SHARE)))
	var title_w := minf(_text_width(font, _title.text, title_px) + 1.0, head.size.x)
	_title.size = Vector2(title_w, head.size.y)
	var shift := title_w + (title_px * SUB_GAP_EM if _title.text != "" else 0.0)
	_sub.position = head.position + Vector2(shift, 0.0)
	_sub.size = Vector2(maxf(head.size.x - shift, 1.0), head.size.y)
	_fit_wrapped(_body, font, int(u * BODY_UNITS))
	_fit_wrapped(_action, font, int(u * ACTION_UNITS))

## Wie breit Titel und Unterzeile nebeneinander im Grad px stehen.
func _head_width(font: Font, px: int) -> float:
	var width := _text_width(font, _title.text, px)
	if _sub.text != "":
		width += px * SUB_GAP_EM + _text_width(font, _sub.text, maxi(8, int(px * SUB_SHARE)))
	return width

static func _text_width(font: Font, text: String, px: int) -> float:
	if text == "":
		return 0.0
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x

## Der größte Grad bis top_px, in dem der Text ungeschnitten in seine Kiste paßt.
func _fit_wrapped(label: Label, font: Font, top_px: int) -> void:
	var lead := label.get_theme_constant("line_spacing")
	var chosen := 8
	for wanted in range(maxi(top_px, 8), 7, -1):
		if ShopController.wrapped_height(font, label.text, label.size.x, wanted, lead) \
				<= label.size.y:
			chosen = wanted
			break
	label.add_theme_font_size_override("font_size", chosen)

# --- Die reinen Text-Quellen ------------------------------------------------
# Jede liefert {title, sub, sub_tint, body, action}. Formuliert wird hier nichts: die
# Texte kommen aus DieInfoBand, Essence und Pack.

## Ein WÜRFEL: oben der Name seiner Seele (ohne Seele "Normal"), darunter spricht die
## Würfel-Auskunft bzw. ohne Seele die Augenzeile.
static func die_info(def: DieDefinition, action := "") -> Dictionary:
	if def == null:
		return idle_info(false, false, false)
	var soul := DieInfoBand.die_data(def)
	var title := String(soul.get("name", SOULLESS))
	var body := ""
	if not soul.has("name"):
		body = "Augen  %s" % " · ".join(
			Array(def.faces).map(func(v: int) -> String: return str(v)))
	return {"title": title, "sub": "", "sub_tint": WorkshopView.MUTED_COLOR,
		"body": body, "action": action, "die": def}

## Eine KASSETTE: Name, Größe·Sorte in der Sortenfarbe, Wirkung plus Netz-Zeile.
## Die Sorte fällt weg, wenn sie schon der Titel ist (Standard-Pakete heißen so).
static func pack_info(pack: Pack, action := "") -> Dictionary:
	if pack == null:
		return idle_info(false, false, false)
	var shelf := Pack.shelf_of(pack)
	var sort := Pack.shelf_name(shelf)
	var tier := Pack.tier_label(pack.tier)
	return {"title": pack.display_name,
		"sub": tier if sort == pack.display_name else "%s%s%s" % [tier, JOIN, sort],
		"sub_tint": PackDrawerView.pack_tint(pack),
		"body": Pack.info_body(pack), "action": action}

## Eine NETZ-ZELLE: sie gehört jemandem, und der steht im Titel.
static func cell_info(owner_title: String, hint: String, action := "") -> Dictionary:
	return {"title": owner_title, "sub": CELL_SUB,
		"sub_tint": WorkshopView.MUTED_COLOR, "body": hint, "action": action}

## RUHE = der NÄCHSTE SCHRITT, nie leer. Ein Rohling sagt, was das Verdichten tut (oder
## warum es nicht geht), eine verbrauchte Prägung sagt es; sonst führt die Leiter Würfel →
## Karte → Prägen, und wo alles da ist, nennt sie die Bremse, falls eine greift.
static func idle_info(die: bool, cards: bool, spent: bool, packing := false,
		blocker := "") -> Dictionary:
	var body := STEP_READY
	if packing:
		body = blocker if blocker != "" else PACKING_BODY
	elif spent:
		body = STEP_SPENT
	elif not die and not cards:
		body = STEP_DIE_FIRST
	elif not cards:
		body = STEP_CARD
	elif not die:
		body = STEP_DIE
	elif blocker != "":
		body = blocker
	return {"title": IDLE_TITLE, "sub": "", "sub_tint": WorkshopView.MUTED_COLOR,
		"body": body, "action": ""}
