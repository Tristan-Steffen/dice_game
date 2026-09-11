class_name WorkshopInfoView
extends Panel
## Der INFO-SCHIRM der Werkstatt (2026-09-11): er liegt in der LÜCKE zwischen der
## Pool-Reihe und dem Streifen, ist so breit wie dieser und trägt JEDE Auskunft der
## Station - Netz-Zelle, Karte, Podest-Würfel und (neu) Pool-Würfel. Er ersetzt die
## winzige CAPTION unter dem Summen-Netz.
##
## DREI Zeilen, linksbündig: TITEL (Name des Dings), UNTERZEILE (Seele bzw.
## Größe·Sorte, in ihrer eigenen Tönung) und die WIRKUNG, die sich in höchstens
## zwei Zeilen einpaßt.
##
## Er MELDET nur seine Höhe (height_for) und faßt nichts an - scene_root schneidet
## sein Rechteck und schreibt ihn je Bild (das apron_bottom-Muster).

## Ränder und Zeilen-Fuge in u des STREIFENS.
const MARGIN_X := 2.4
const MARGIN_Y := 1.4
const LINE_GAP := 0.5
## Die Grade der drei Zeilen in u. Die WIRKUNG paßt sich über ihre Leiter ein.
const TITLE_UNITS := 5.2
const SUB_UNITS := 3.8
const BODY_STEPS := [3.6, 3.2, 2.8, 2.4, 2.0]
## So viele Zeilen darf die Wirkung brechen.
const BODY_LINES := 2
## Wie hoch ein Label über seinem Grad steht - EIN Faktor für alle drei Zeilen,
## damit height_for und Aufbau nicht auseinanderlaufen. GEMESSEN: die Schrifthöhe
## ist ~1,42 × Grad, und der Zeilenabstand kommt je Zeile dazu; ein knapperer Wert
## schluckte die ZWEITE Wirkungszeile (Godot zählt sie nur, wenn sie samt Abstand
## in die Kiste paßt).
const LINE_BOX := 1.6

## Was der Schirm sagt, wenn nichts unter dem Zeiger liegt und kein Ziel steht.
const IDLE_TITLE := "Werkstatt"
const IDLE_BODY := "Einen Vorrats-Würfel antippen: er wird das Ziel der Serie."
## Der Würfel ohne Seele und der Würfel ohne alles.
const SOULLESS := "Ohne Seele"
const PLAIN_DIE := "Ein schlichter Würfel."
## Die Unterzeile einer Netz-Zelle.
const CELL_SUB := "Zelle"
## Das Trennzeichen zweier Wirkungs-Teile - dieselbe Fuge wie in DieNetView.
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
## Die Signatur der gezeigten Auskunft - nur der WECHSEL schreibt (je Bild gefragt).
var _signature := ""
## Die letzte Auskunft, damit ein Neuaufbau sie ohne den Schreiber wiederholt.
var _shown := {"title": "", "sub": "", "sub_tint": Color.WHITE, "body": ""}
## Die Restbreite der Wirkung und die Einheit, in der ihre Leiter mißt.
var _body_span := Vector2.ZERO
var _body_unit := 0.0
## Seelen-Auskunft je Essenz-id: Essence.by_id baut den ganzen Katalog, und die
## Frage kommt je Bild.
static var _soul_cache: Dictionary = {}

func _init() -> void:
	name = "WorkshopInfoWindow"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Auskunft, kein Bedienteil

func _ready() -> void:
	_rebuild()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_rebuild()

## Die HÖHE, die der Schirm bei dieser Einheit braucht: beide Ränder, Titel,
## Unterzeile, zwei Wirkungs-Zeilen am größten Grad und die zwei Fugen. scene_root
## schneidet sein Rechteck daraus, statt eine Zahl zu tippen.
static func height_for(u: float) -> float:
	var grades := TITLE_UNITS + SUB_UNITS + float(BODY_STEPS[0]) * float(BODY_LINES)
	return u * (MARGIN_Y * 2.0 + LINE_GAP * 2.0 + LINE_BOX * grades)

func unit() -> float:
	if unit_px > 0.0:
		return unit_px
	return maxf(size.x, 200.0) / 100.0

## Der EINE Schreiber (scene_root, je Bild). Nur der WECHSEL schreibt.
func set_info(title: String, sub: String, sub_tint: Color, body: String) -> void:
	var signature := "%s|%s|%s|%s" % [title, sub, sub_tint.to_html(false), body]
	if signature == _signature:
		return
	_signature = signature
	_shown = {"title": title, "sub": sub, "sub_tint": sub_tint, "body": body}
	_paint()

func title_text() -> String:
	return _title.text if _title != null and is_instance_valid(_title) else ""

func sub_text() -> String:
	return _sub.text if _sub != null and is_instance_valid(_sub) else ""

func body_text() -> String:
	return _body.text if _body != null and is_instance_valid(_body) else ""

func body_font_size() -> int:
	if _body == null or not is_instance_valid(_body):
		return 0
	return _body.get_theme_font_size("font_size")

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
	var u := unit()
	var pad := Vector2(u * MARGIN_X, u * MARGIN_Y)
	var inner := maxf(size.x - pad.x * 2.0, 1.0)
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var gap := u * LINE_GAP
	var title_h := u * TITLE_UNITS * LINE_BOX
	var sub_h := u * SUB_UNITS * LINE_BOX
	_title = _line("Titel", Vector2(pad.x, pad.y), Vector2(inner, title_h),
		u * TITLE_UNITS, WorkshopView.TEXT_COLOR, false)
	_sub = _line("Unterzeile", Vector2(pad.x, pad.y + title_h + gap),
		Vector2(inner, sub_h), u * SUB_UNITS, WorkshopView.MUTED_COLOR, false)
	var body_top := pad.y + title_h + gap + sub_h + gap
	_body_span = Vector2(inner, maxf(size.y - body_top - pad.y, 1.0))
	_body_unit = u
	_body = _line("Wirkung", Vector2(pad.x, body_top), _body_span,
		u * float(BODY_STEPS[0]), WorkshopView.MUTED_COLOR, true)
	_paint()

## Eine Zeile des Schirms - Grad, Umbruch und clip_text VOR dem Maß, sonst klemmt
## die Mindestgröße das Label hoch.
func _line(line_name: String, at: Vector2, span: Vector2, font_size: float,
		tint: Color, wrap: bool) -> Label:
	var label := Label.new()
	label.name = line_name
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.add_theme_color_override("font_color", tint)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP if wrap else VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.position = at
	label.size = span
	return label

func _paint() -> void:
	if _title == null or not is_instance_valid(_title):
		return
	_title.text = String(_shown.get("title", ""))
	_sub.text = String(_shown.get("sub", ""))
	_sub.add_theme_color_override("font_color",
		_shown.get("sub_tint", WorkshopView.MUTED_COLOR))
	_body.text = String(_shown.get("body", ""))
	_fit_body()

## Der Grad der Wirkung: die größte Stufe, die noch in BODY_LINES Zeilen UND in die
## Kiste paßt. Gemessen wird mit ShopController.wrapped_height - die ehrliche Höhe
## samt Zeilenabstand, denn genau der entscheidet, ob Godot die letzte Zeile noch
## zeichnet.
func _fit_body() -> void:
	var font := ThemeDB.fallback_font
	if font == null or _body == null or not is_instance_valid(_body) \
			or _body_span.x <= 0.0:
		return
	var lead := _body.get_theme_constant("line_spacing")
	var px := maxi(8, int(_body_unit * float(BODY_STEPS[BODY_STEPS.size() - 1])))
	for step: float in BODY_STEPS:
		var wanted := maxi(8, int(_body_unit * step))
		if WorkshopView.text_block_lines(font, _body.text, _body_span.x,
				wanted) <= BODY_LINES \
				and ShopController.wrapped_height(font, _body.text, _body_span.x,
					wanted, lead) <= _body_span.y:
			px = wanted
			break
	_body.add_theme_font_size_override("font_size", px)

# --- Die reinen Text-Quellen ------------------------------------------------
# Jede liefert {title, sub, sub_tint, body}. Formuliert wird hier nichts: die
# Texte kommen aus DieNetView, Essence und Pack.

## Ein WÜRFEL: Name, Seele in ihrem Glühen, Wirkung plus Ladungszeile.
static func die_info(def: DieDefinition) -> Dictionary:
	if def == null:
		return idle_info(null, "")
	var soul := _soul_of(def.essence_id)
	var body := String(soul.get("body", ""))
	var charge := DieNetView.charge_hint(def)
	if charge != "":
		body = "%s%s%s" % [body, JOIN, charge] if body != "" else charge
	return {"title": def.display_name,
		"sub": String(soul.get("name", SOULLESS)),
		"sub_tint": soul.get("tint", WorkshopView.MUTED_COLOR),
		"body": body if body != "" else PLAIN_DIE}

## Eine KASSETTE: Name, Größe·Sorte in der Sortenfarbe, Wirkung plus Netz-Zeile.
## Die Sorte fällt weg, wenn sie schon der Titel ist (Standard-Pakete heißen so).
static func pack_info(pack: Pack) -> Dictionary:
	if pack == null:
		return idle_info(null, "")
	var shelf := Pack.shelf_of(pack)
	var sort := Pack.shelf_name(shelf)
	var tier := Pack.tier_label(pack.tier)
	return {"title": pack.display_name,
		"sub": tier if sort == pack.display_name else "%s%s%s" % [tier, JOIN, sort],
		"sub_tint": PackDrawerView.COLORS.get(shelf, WorkshopView.MUTED_COLOR),
		"body": Pack.info_body(pack)}

## Eine NETZ-ZELLE: sie gehört jemandem, und der steht im Titel.
static func cell_info(owner_title: String, hint: String) -> Dictionary:
	return {"title": owner_title, "sub": CELL_SUB,
		"sub_tint": WorkshopView.MUTED_COLOR, "body": hint}

## RUHE: steht ein Ziel, erklärt der Schirm den Zielwürfel - sonst sagt er, warum
## der Griff schweigt, und sonst, was zu tun ist.
static func idle_info(target: DieDefinition, blocker: String) -> Dictionary:
	if target != null:
		return die_info(target)
	return {"title": IDLE_TITLE, "sub": "",
		"sub_tint": WorkshopView.MUTED_COLOR,
		"body": blocker if blocker != "" else IDLE_BODY}

## Name, Ton und Wirkung einer Seele - gecacht, denn Essence.by_id baut jedesmal
## den ganzen Katalog.
static func _soul_of(essence_id: String) -> Dictionary:
	if _soul_cache.has(essence_id):
		return _soul_cache[essence_id]
	var essence := Essence.by_id(essence_id)
	var entry := {"name": SOULLESS, "tint": WorkshopView.MUTED_COLOR, "body": ""}
	if essence != null:
		entry = {"name": essence.display_name,
			"tint": ShopController.soul_tint(essence_id),
			"body": essence.description}
	_soul_cache[essence_id] = entry
	return entry
