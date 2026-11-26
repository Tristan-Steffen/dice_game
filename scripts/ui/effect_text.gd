class_name EffectText
extends RefCounted
## Färbt in jedem Wirkungstext die Krit-, Mult- und Basis-Phrasen („kritet ×10“, „+4 Mult“,
## „+20 Basispunkte“, auch das nackte Wort) in der Farbe ihrer Wertungsart. `colorize(label)`
## hängt an ein bestehendes Label eine bunte Überlagerung - das Label bleibt Maß und Quelle.

const KIND_CRIT := FaceCardView.KIND_CRIT
const KIND_MULT := FaceCardView.KIND_MULT
const KIND_BASE := FaceCardView.KIND_BASE
const META := "effect_text"

const _L := "A-Za-zÄÖÜäöüß"
const _NUM := "(?:\\d[\\d.,]*%?|\\([^)]*\\))"

static var _pattern: RegEx = null

static func _regex() -> RegEx:
	if _pattern != null:
		return _pattern
	var left := "(?<![%s-])" % _L
	var right := "(?![%s-])" % _L
	var crit_word := "[Kk]rit(?:s|et)?"
	var crit := "(?<crit>%s%s\\s*×\\s?(?:%s|[%s]+(?:/\\d+)?)|×\\s?%s\\s+Krits?%s|%s%s%s)" % [
		left, crit_word, _NUM, _L, _NUM, right, left, crit_word, right]
	var mult := "(?<mult>[+×−-]\\s?%s\\s+Mult%s|%sMult%s)" % [_NUM, right, left, right]
	var base_word := "Basis(?:punkten?)?"
	var base := "(?<base>[+−-]\\s?%s\\s+%s%s|%s%s%s)" % [_NUM, base_word, right, left,
		base_word, right]
	_pattern = RegEx.new()
	_pattern.compile("%s|%s|%s" % [crit, mult, base])
	return _pattern

## Die gefärbten Stücke: [{start, end, kind}], aufsteigend und ohne Überlappung.
static func ranges(text: String) -> Array:
	var out := []
	if text == "":
		return out
	for m in _regex().search_all(text):
		for kind: String in [KIND_CRIT, KIND_MULT, KIND_BASE]:
			if m.get_start(kind) >= 0:
				out.append({"start": m.get_start(kind), "end": m.get_end(kind), "kind": kind})
				break
	return out

static func color_of(kind: String) -> Color:
	return FaceCardView.kind_color(kind)

## Der Text als BBCode, die Phrasen in ihrer Farbe.
static func bbcode(text: String) -> String:
	var result := ""
	var cursor := 0
	for r: Dictionary in ranges(text):
		result += _escape(text.substr(cursor, int(r["start"]) - cursor))
		result += "[color=#%s]%s[/color]" % [color_of(String(r["kind"])).to_html(false),
			_escape(text.substr(int(r["start"]), int(r["end"]) - int(r["start"])))]
		cursor = int(r["end"])
	return result + _escape(text.substr(cursor))

static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")

## Die Art je Zeichen ("" = schlicht) - für Setzer, die selbst stückeln (LexikonText).
static func kind_map(text: String) -> PackedStringArray:
	var map := PackedStringArray()
	map.resize(text.length())
	for r: Dictionary in ranges(text):
		for i in range(int(r["start"]), int(r["end"])):
			map[i] = String(r["kind"])
	return map

## Hängt die bunte Überlagerung an label; sie folgt jeder Änderung von Text, Maß und Stil.
static func colorize(label: Label) -> void:
	if label == null or label.has_meta(META):
		return
	var rich := RichTextLabel.new()
	rich.name = "EffectText"
	rich.bbcode_enabled = true
	rich.scroll_active = false
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.visible = false
	label.add_child(rich, false, Node.INTERNAL_MODE_FRONT)
	label.set_meta(META, rich)
	label.draw.connect(_sync.bind(label), CONNECT_DEFERRED)
	_sync(label)

## Die Überlagerung eines Labels (null = keine).
static func overlay_of(label: Label) -> RichTextLabel:
	if label == null or not label.has_meta(META):
		return null
	return label.get_meta(META) as RichTextLabel

static func _sync(label: Label) -> void:
	if not is_instance_valid(label):
		return
	var rich := overlay_of(label)
	if rich == null:
		return
	var text := label.text
	var font := label.get_theme_font("font")
	var px := label.get_theme_font_size("font_size")
	var color := label.get_theme_color("font_color")
	var outline := label.get_theme_constant("outline_size")
	var outline_color := label.get_theme_color("font_outline_color")
	var key := [text, label.size, font, px, color, outline, outline_color,
		label.horizontal_alignment, label.vertical_alignment, label.autowrap_mode,
		label.get_theme_constant("line_spacing")]
	if rich.has_meta("key") and rich.get_meta("key") == key:
		return
	rich.set_meta("key", key)
	var colored := not ranges(text).is_empty()
	rich.visible = colored
	label.self_modulate.a = 0.0 if colored else 1.0
	if not colored:
		return
	rich.position = Vector2.ZERO
	rich.size = label.size
	rich.add_theme_font_override("normal_font", font)
	rich.add_theme_font_size_override("normal_font_size", px)
	rich.add_theme_color_override("default_color", color)
	rich.add_theme_constant_override("outline_size", outline)
	rich.add_theme_color_override("font_outline_color", outline_color)
	rich.add_theme_constant_override("line_separation", label.get_theme_constant("line_spacing"))
	rich.horizontal_alignment = label.horizontal_alignment
	rich.vertical_alignment = label.vertical_alignment
	rich.autowrap_mode = label.autowrap_mode
	rich.text = bbcode(text)
