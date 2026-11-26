class_name DieInfoBand
extends Control
## Die EINE Würfel-Auskunft, feste Plätze, je Ding seine Farbe.
## WÜRFEL: der Seelen-Name in ihrem Glühen, daneben bzw. darunter ihre Wirkung.
## Ohne Seele schweigt er. SEITE: Augen (weiß) | Material (seine Farbe) | Runen (ihre).
## Zwei Fassungen: LINE (eine Zeile, drei Spalten - die Grube) und ROWS (drei Zeilen).

enum Layout { LINE, ROWS }

## LINE: so viele Schriftgrade breit ist das Band am vollen Grad; längere Seiten
## steigen die Leiter hinab (gemessen braucht die längste 44).
const LINE_EM := 34.0
const LINE_FONT_SHARE := 0.55
const LINE_STEPS := [1.0, 0.9, 0.8, 0.7, 0.62]
const LINE_SHARES := [0.14, 0.45, 0.41]
## ROWS: die längste Zeile samt Etikett (gemessen 27).
const ROW_EM := 28.0
const ROW_BOX := 1.4
const TAG_EM := 5.2
const GAP_EM := 0.7
const TAGS: Array[String] = ["Augen", "Material", "Runen"]
const DOPED := "veredelt"
const JOIN := "  ·  "
const PLUS := " + "
const TAG_COLOR := Color(0.62, 0.66, 0.74)
const PIPS_COLOR := Color(1.0, 1.0, 1.0)
## Die Wirkung trägt die Farbe ihres Dings, zum Weiß hin aufgehellt.
const EFFECT_LIFT := 0.45
const NO_DATA := {}

var layout := Layout.ROWS:
	set(value):
		layout = value
		_paint()
## Umriß der Schrift in px (0 = keiner) - die Grube liegt ohne ruhigen Grund.
var outline_px := 0:
	set(value):
		outline_px = value
		_style()

var _soul_name: Label
var _soul_text: Label
var _tags: Array[Label] = []
var _heads: Array[Label] = []
var _values: Array[Label] = []
var _data: Dictionary = NO_DATA
var _key := ""
static var _soul_cache := {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_soul_name = _label(false)
	_soul_text = _label(true)
	for i in 3:
		_tags.append(_label(false))
		_heads.append(_label(false))
		_values.append(_label(false))
		_tags[i].text = TAGS[i]
		_tags[i].add_theme_color_override("font_color", TAG_COLOR)
	resized.connect(_lay)
	_paint()

# --- Die Daten ---------------------------------------------------------------

## Die Seele eines Würfels ({} ohne Würfel oder ohne Seele).
static func die_data(def: DieDefinition) -> Dictionary:
	if def == null or def.essence_id == "":
		return NO_DATA
	if not _soul_cache.has(def.essence_id):
		var essence := Essence.by_id(def.essence_id)
		_soul_cache[def.essence_id] = NO_DATA if essence == null else {
			"mode": "die", "name": essence.display_name,
			"tint": ShopController.soul_tint(def.essence_id),
			"text": essence.description, "short": essence.short}
	return _soul_cache[def.essence_id]

## Eine Seite: Augen, Material samt Veredelung, Runen. Der Seelen-Chip und alles
## außerhalb des Kreuzes fallen auf den Würfel zurück.
static func face_data(def: DieDefinition, face: int) -> Dictionary:
	if def == null:
		return NO_DATA
	if face < 0 or face >= def.faces.size():
		return die_data(def)
	var data := {"mode": "face", "pips": pips_text(int(def.faces[face])),
		"material": "", "material_text": "", "material_tint": Color.WHITE,
		"runes": "", "runes_text": "", "runes_tint": Color.WHITE}
	var material := DieMaterial.by_id(def.materials[face]) \
		if face < def.materials.size() else null
	if material != null:
		var level := MaterialEffects.face_level(def, face)
		var doped := level >= DieMaterial.MAX_LEVEL
		data["material"] = material.display_name + (JOIN + DOPED if doped else "")
		data["material_text"] = material.short_for(level)
		data["material_tint"] = readable(DieMaterial.tint_for(material.id, level))
	var names: PackedStringArray = []
	var effects: PackedStringArray = []
	for rune_id in def.runes_on(face):
		var rune := Rune.by_id(rune_id)
		if rune == null:
			continue
		if names.is_empty():
			data["runes_tint"] = readable(Rune.tint_for(rune_id))
		names.append(rune.display_name)
		effects.append(rune.short)
	data["runes"] = PLUS.join(names)
	data["runes_text"] = JOIN.join(effects)
	return data

## Die Augenzahl ausgeschrieben, mit Tausenderpunkten.
static func pips_text(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "." + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out

## Eine dunkle Farbe auf ein lesbares Maß gehoben, der Ton bleibt.
static func readable(color: Color) -> Color:
	var out := color
	out.a = 1.0
	if out.v < 0.75:
		out.v = 0.75
	return out

static func effect_color(tint: Color) -> Color:
	return tint.lerp(Color.WHITE, EFFECT_LIFT)

# --- Der Schreiber -----------------------------------------------------------

## Der EINE Schreiber: face < 0 zeigt den Würfel. Nur der Wechsel schreibt.
func show_info(def: DieDefinition, face := -1) -> void:
	set_data(face_data(def, face))

func clear() -> void:
	set_data(NO_DATA)

func set_data(data: Dictionary) -> void:
	var key := str(data)
	if key == _key:
		return
	_key = key
	_data = data
	_paint()

func is_empty() -> bool:
	return _data.is_empty()

func mode() -> String:
	return String(_data.get("mode", ""))

## Was gerade dasteht, Platz für Platz (für Tests und Vergleiche).
func plain_text() -> String:
	var parts: PackedStringArray = []
	var order: Array[Label] = [_soul_name, _soul_text]
	for i in 3:
		order.append(_tags[i])
		order.append(_heads[i])
		order.append(_values[i])
	for label: Label in order:
		if label.visible and label.text != "":
			parts.append(label.text)
	return JOIN.join(parts)

## Der feste Platz eines Dings (0 Augen, 1 Material, 2 Runen).
func place_rect(place: int) -> Rect2:
	if layout == Layout.ROWS:
		var row := size.y / 3.0
		return Rect2(0.0, row * place, size.x, row)
	var left := 0.0
	for i in place:
		left += size.x * float(LINE_SHARES[i])
	return Rect2(left, 0.0, size.x * float(LINE_SHARES[place]), size.y)

func head_color(place: int) -> Color:
	return _heads[place].get_theme_color("font_color")

func font_px() -> int:
	return _heads[0].get_theme_font_size("font_size")

# --- Aufbau ------------------------------------------------------------------

func _all() -> Array[Label]:
	var out: Array[Label] = [_soul_name, _soul_text]
	out.append_array(_tags)
	out.append_array(_heads)
	out.append_array(_values)
	return out

func _label(wrap: bool) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	EffectText.colorize(label)
	return label

func _style() -> void:
	for label: Label in _all():
		label.add_theme_color_override("font_outline_color", CasinoStyle.SHADOW)
		label.add_theme_constant_override("outline_size", outline_px)

func _paint() -> void:
	if _soul_name == null:
		return
	var face := mode() == "face"
	var die := mode() == "die"
	var rows := layout == Layout.ROWS
	_soul_name.visible = die
	_soul_text.visible = die
	for i in 3:
		# Die Zeile nennt ihr Ding immer; in der Spalte genügt bei Material und Rune die Farbe.
		_tags[i].visible = face and (rows or i == 0)
		_heads[i].visible = face
		_values[i].visible = face
	if die:
		_soul_name.text = String(_data["name"])
		_soul_name.add_theme_color_override("font_color", _data["tint"])
		_soul_text.text = String(_data["text"] if rows else _data["short"])
		_soul_text.add_theme_color_override("font_color", effect_color(_data["tint"]))
	elif face:
		_write(0, String(_data["pips"]), PIPS_COLOR, "")
		_write(1, String(_data["material"]), _data["material_tint"], String(_data["material_text"]))
		_write(2, String(_data["runes"]), _data["runes_tint"], String(_data["runes_text"]))
	_lay()

func _write(place: int, head: String, tint: Color, value: String) -> void:
	_heads[place].text = head
	_heads[place].add_theme_color_override("font_color", tint)
	_values[place].text = value
	_values[place].add_theme_color_override("font_color", effect_color(tint))

func _lay() -> void:
	if _soul_name == null or size.x <= 0.0 or size.y <= 0.0:
		return
	if layout == Layout.ROWS:
		_lay_rows()
	else:
		_lay_line()

func _width(text: String, px: int) -> float:
	var font := ThemeDB.fallback_font
	if font == null or text == "":
		return 0.0
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x

## Etikett, Name, Wirkung hintereinander in ein Feld; liefert die gebrauchte Breite.
func _chain(labels: Array[Label], field: Rect2, px: int, tag_w: float) -> float:
	var gap := px * GAP_EM
	var x := field.position.x
	for label in labels:
		label.add_theme_font_size_override("font_size", px)
		if not label.visible or label.text == "":
			label.size = Vector2.ZERO
			continue
		var wide := _width(label.text, px) + 1.0
		if tag_w > 0.0 and label == labels[0]:
			wide = tag_w - gap
		label.position = Vector2(x, field.position.y)
		label.size = Vector2(maxf(minf(wide, field.end.x - x), 0.0), field.size.y)
		x += wide + gap
	return x - gap - field.position.x

func _lay_rows() -> void:
	var row := size.y / 3.0
	var px := maxi(8, int(minf(row / ROW_BOX, size.x / ROW_EM)))
	for i in 3:
		_chain([_tags[i], _heads[i], _values[i]], place_rect(i), px, px * TAG_EM)
	# Die Seele: Name in Zeile eins, die Wirkung über die zwei darunter.
	_soul_name.add_theme_font_size_override("font_size", px)
	_soul_name.position = Vector2.ZERO
	_soul_name.size = Vector2(size.x, row)
	_soul_text.add_theme_font_size_override("font_size", _fit_wrapped(px, size.x, row * 2.0))
	_soul_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_soul_text.position = Vector2(0.0, row)
	_soul_text.size = Vector2(size.x, row * 2.0)

func _lay_line() -> void:
	var base := maxi(8, int(minf(size.y * LINE_FONT_SHARE, size.x / LINE_EM)))
	var px := base
	# Paßt eine Spalte nicht, steigt das GANZE Band eine Stufe hinab.
	for step: float in LINE_STEPS:
		px = maxi(8, int(base * step))
		var fits := true
		for i in 3:
			var field := place_rect(i)
			var need := _width(_heads[i].text, px) + _width(_values[i].text, px) + px * GAP_EM * 2.0
			if i == 0:
				need += _width(_tags[0].text, px)
			if need > field.size.x:
				fits = false
		var soul := _width(_soul_name.text, px) + _width(_soul_text.text, px) + px * GAP_EM
		if mode() == "die" and soul > size.x:
			fits = false
		if fits:
			break
	for i in 3:
		_chain([_tags[i], _heads[i], _values[i]], place_rect(i), px, 0.0)
	_soul_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chain([_soul_name, _soul_text], Rect2(Vector2.ZERO, size), px, 0.0)

## Der größte Grad, in dem der umbrochene Text in die Höhe paßt.
func _fit_wrapped(px: int, width: float, height: float) -> int:
	var font := ThemeDB.fallback_font
	if font == null:
		return px
	var lead := _soul_text.get_theme_constant("line_spacing")
	for step: float in LINE_STEPS:
		var wanted := maxi(8, int(px * step))
		if ShopController.wrapped_height(font, _soul_text.text, width, wanted, lead) <= height:
			return wanted
	return maxi(8, int(px * float(LINE_STEPS[LINE_STEPS.size() - 1])))
