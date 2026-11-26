class_name FaceCardView
extends Control
## Die SEITEN-AUSKUNFT (Spieler-Wahl „H“ 2026-11-26): drei feste Fächer - links die Zahl
## neutral, in der Mitte das Material auf seiner echten Würfelseite, rechts je Rune ein
## Streifen mit ihrem Zeichen im Grund. Jeder Wert steht in der Farbe, in der er in der
## Grube aufploppt. `show_face` ist der EINE Schreiber, nur der Wechsel baut.

## Die Hintergründe des Material-Fachs (gebacken von tools/godot_face_material_probe.gd).
const FACE_DIR := "res://assets/textures/ui/face_cards/"
const SLOT_GAP_UNITS := 1.4
const NUMBER_SHARE := 0.24
const RADIUS_SHARE := 0.07
const NUMBER_BG := Color(0.13, 0.145, 0.27)
const NUMBER_RIM := Color(0.35, 0.38, 0.59)
const EMPTY_RIM := Color(0.23, 0.25, 0.4)
const EMPTY_TEXT := Color(0.49, 0.53, 0.69)
const RUNE_BG := Color(0.105, 0.115, 0.22)
const PLATE_BG := Color(0.03, 0.03, 0.07, 0.86)
const TAG_BG := Color(0.04, 0.03, 0.06, 0.8)
const INK := Color(0.04, 0.04, 0.1)
const GLYPH_ALPHA := 0.28
const KIND_BASE := "base"
const KIND_MULT := "mult"
const KIND_CRIT := "crit"
const KIND_MONEY := "money"
const KIND_ENERGY := "energy"
const KIND_PLAIN := "plain"
## Die Wirkung eines Materials, zerlegt in Wert, Art, Einheit und Bedingung - je Stufe
## (normal, veredelt). Die Worte sind die von DieMaterial.short/short_doped; "%v" setzt
## die Augen der Seite ein (Glas), "%h" ihre Hälfte.
const MATERIAL_EFFECTS := {
	DieMaterial.RUBY: [["+4", KIND_MULT, "Mult", ""],
		["×2", KIND_CRIT, "Krit", ""]],
	DieMaterial.AMBER: [["+20", KIND_BASE, "Basis", ""],
		["5×", KIND_BASE, "Augensumme", "als Basis"]],
	DieMaterial.GOLD: [["+$3", KIND_MONEY, "", ""],
		["+$7", KIND_MONEY, "", "+$1 je Gold-Seite"]],
	DieMaterial.BONE: [["+2", KIND_PLAIN, "Augen", "Seite wächst beim Nehmen"],
		["+10", KIND_PLAIN, "Augen", "oder +20 % · Seite wächst"]],
	DieMaterial.GLASS: [["+%v", KIND_MULT, "Mult", "Seite schrumpft −1"],
		["×%h", KIND_CRIT, "Krit", "Seite halbiert sich"]],
	DieMaterial.COPPER: [["+1", KIND_ENERGY, "Energie", ""],
		["+2", KIND_ENERGY, "Energie", "Überlauf zahlt $2"]],
}
## Die Wirkung einer Rune: Wert, Art, Einheit (die Worte von Rune.short). Das ⚡ steht als
## Wort: die Würfel-Schrift kennt es nicht, und der Ersatz malt es als buntes Emoji.
const RUNE_EFFECTS := {
	Rune.AFTERGLOW: ["+1", KIND_PLAIN, "Auslösung"],
	Rune.STRAY_LIGHT: ["+$1", KIND_MONEY, "ungewertet"],
	Rune.BURN_IN: ["Fest", KIND_PLAIN, "Seite eingebrannt"],
	Rune.SPARK_FLIGHT: ["+1", KIND_ENERGY, "Energie beim Werten"],
	Rune.REVERSE: ["+1", KIND_PLAIN, "Gegenseite löst aus"],
}
## Das Schild der Runen-Klasse: Grund, Schrift.
const KIND_TAGS := {
	"Wertung": [Color(0.13, 0.19, 0.29), Color(0.66, 0.77, 1.0)],
	"Ökonomie": [Color(0.12, 0.29, 0.17), Color(0.56, 0.88, 0.63)],
	"Schutz": [Color(0.29, 0.14, 0.08), Color(1.0, 0.69, 0.54)],
}

static var _faces := {}

var _key := ""

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _key != "":
		var shown := _key
		_key = ""
		_rebuild_from_key(shown)

## Die Farbe einer Wertungsart - dieselbe wie ihre Zuwachs-Zahl in der Grube, auf ihr
## hellstes Glied normiert (auf der Platte darf sie nicht blühen).
static func kind_color(kind: String) -> Color:
	var raw := Color(1.0, 1.0, 1.0)
	match kind:
		KIND_BASE: raw = TableScreen.TRAIL_BASE_COLOR
		KIND_MULT: raw = TableScreen.TRAIL_MULT_COLOR
		KIND_CRIT: raw = TableScreen.CRIT_COLOR
		KIND_MONEY: raw = CasinoStyle.MONEY
		KIND_ENERGY: raw = CasinoStyle.ENERGY
	return _peak_one(raw)

static func _peak_one(color: Color) -> Color:
	var peak := maxf(color.r, maxf(color.g, color.b))
	if peak <= 0.0:
		return Color.WHITE
	return Color(color.r / peak, color.g / peak, color.b / peak, 1.0)

## Die Wirkung eines Materials auf einer Seite mit value Augen: [Wert, Art, Einheit,
## Bedingung] (leer = ohne Material).
static func material_effect(material_id: String, level: int, value: int) -> Array:
	var rows: Array = MATERIAL_EFFECTS.get(material_id, [])
	if rows.is_empty():
		return []
	var row: Array = (rows[1] if level >= DieMaterial.MAX_LEVEL else rows[0]).duplicate()
	row[0] = String(row[0]).replace("%v", str(mini(value, 6))) \
		.replace("%h", _half_text(value))
	return row

static func _half_text(value: int) -> String:
	if value % 2 == 0:
		return str(value / 2)
	return ("%.1f" % (float(value) / 2.0)).replace(".", ",")

## Der Hintergrund des Material-Fachs (null = keiner gebacken).
static func face_texture(material_id: String, level: int) -> Texture2D:
	var key := material_id + ("_veredelt" if level >= DieMaterial.MAX_LEVEL else "")
	if not _faces.has(key):
		var path := FACE_DIR + key + ".png"
		_faces[key] = load(path) if ResourceLoader.exists(path) else null
	return _faces[key]

## Der EINE Schreiber: Seite face des Würfels def.
func show_face(def: DieDefinition, face: int) -> void:
	if def == null or face < 0 or face >= def.faces.size():
		_clear()
		_key = ""
		return
	var key := "%d|%s|%d|%s|%s" % [int(def.faces[face]), def.materials[face],
		def.material_level(face), ",".join(def.runes_on(face)), def.essence_id]
	if key == _key:
		return
	_key = key
	_rebuild_from_key(key)

func shown_key() -> String:
	return _key

func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func _rebuild_from_key(key: String) -> void:
	_clear()
	_key = key
	if size.x <= 8.0 or size.y <= 8.0:
		return
	var parts := key.split("|")
	var value := int(parts[0])
	var material_id := parts[1]
	var level := int(parts[2])
	var runes := Array(parts[3].split(",", false))
	var essence := parts[4]
	var u := size.y / 30.0
	var gap := u * SLOT_GAP_UNITS
	var number_w := size.x * NUMBER_SHARE
	var rest := (size.x - number_w - gap * 2.0) * 0.5
	var high := size.y
	_build_number(Rect2(Vector2.ZERO, Vector2(number_w, high)), value)
	_build_material(Rect2(Vector2(number_w + gap, 0.0), Vector2(rest, high)), material_id,
		level, value)
	_build_runes(Rect2(Vector2(number_w + gap * 2.0 + rest, 0.0), Vector2(rest, high)),
		runes, essence)

# --- Die Fächer ---------------------------------------------------------------

func _build_number(rect: Rect2, value: int) -> void:
	var slot := _panel("Zahl", rect, NUMBER_BG, NUMBER_RIM, 3.0)
	var text := str(value)
	_text(slot, "Wert", text, Rect2(Vector2(0, rect.size.y * 0.08),
		Vector2(rect.size.x, rect.size.y * 0.66)), Color.WHITE, true, rect.size.y * 0.5)
	_text(slot, "Einheit", "Augen", Rect2(Vector2(0, rect.size.y * 0.72),
		Vector2(rect.size.x, rect.size.y * 0.18)), Color(0.67, 0.7, 0.84), false,
		rect.size.y * 0.1)

func _build_material(rect: Rect2, material_id: String, level: int, value: int) -> void:
	var effect := material_effect(material_id, level, value)
	if effect.is_empty():
		_empty_slot("Material", rect, "Material")
		return
	var slot := Control.new()
	slot.name = "Material"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.position = rect.position
	slot.size = rect.size
	add_child(slot)
	var texture := face_texture(material_id, level)
	if texture != null:
		var back := TextureRect.new()
		back.name = "Seite"
		back.texture = texture
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.size = rect.size
		slot.add_child(back)
		slot.clip_contents = true
	else:
		var tint := DieMaterial.tint_for(material_id, level)
		_panel("Seite", Rect2(Vector2.ZERO, rect.size), tint, tint, 0.0, slot)
	var color := kind_color(String(effect[1]))
	var pad := rect.size.x * 0.06
	var plate_rect := Rect2(Vector2(pad, pad), Vector2(rect.size.x - pad * 2.0,
		rect.size.y * 0.68))
	var plate := _panel("Platte", plate_rect, PLATE_BG, color, 3.0, slot)
	var unit := String(effect[2])
	var value_h := plate_rect.size.y * (0.5 if unit != "" else 0.62)
	_text(plate, "Wert", String(effect[0]), Rect2(Vector2(0, plate_rect.size.y * 0.03),
		Vector2(plate_rect.size.x, value_h)), color, true, value_h * 0.95)
	var y := plate_rect.size.y * 0.03 + value_h
	if unit != "":
		var unit_h := plate_rect.size.y * 0.2
		_text(plate, "Einheit", unit, Rect2(Vector2(0, y), Vector2(plate_rect.size.x, unit_h)),
			color, true, unit_h)
		y += unit_h
	_text(plate, "Bedingung", String(effect[3]), Rect2(Vector2(pad * 0.5, y),
		Vector2(plate_rect.size.x - pad, plate_rect.size.y - y - plate_rect.size.y * 0.04)),
		Color(0.89, 0.9, 0.96), false, plate_rect.size.y * 0.15)
	var material := DieMaterial.by_id(material_id)
	var label := (material.display_name if material != null else material_id) \
		+ (" · veredelt" if level >= DieMaterial.MAX_LEVEL else "")
	var tag_h := rect.size.y * 0.15
	var tag := _text(slot, "Name", label, Rect2(Vector2(pad, rect.size.y - tag_h - pad * 0.6),
		Vector2(rect.size.x - pad * 2.0, tag_h)), Color.WHITE, false, tag_h * 0.72)
	_tag_box(tag, TAG_BG)

func _build_runes(rect: Rect2, runes: Array, essence: String) -> void:
	if runes.is_empty():
		_empty_slot("Runen", rect, "Rune")
		return
	var host := Control.new()
	host.name = "Runen"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.position = rect.position
	host.size = rect.size
	add_child(host)
	var gap := rect.size.y * 0.03
	var count := runes.size()
	var high := (rect.size.y - gap * float(count - 1)) / float(count)
	for i in count:
		_build_rune(host, Rect2(Vector2(0.0, (high + gap) * float(i)),
			Vector2(rect.size.x, high)), String(runes[i]), essence, i)

func _build_rune(host: Control, rect: Rect2, rune_id: String, essence: String,
		index: int) -> void:
	var rune := Rune.by_id(rune_id)
	if rune == null:
		return
	var tone := _peak_one(RuneEffects.glyph_color(rune_id, essence))
	if essence == Essence.VACUUM:
		tone = _peak_one(rune.core)
	var stripe := _panel("Rune%d" % index, rect, RUNE_BG, tone, 3.0, host)
	stripe.clip_contents = true
	var side := minf(rect.size.x, rect.size.y) * 0.92
	var glyph := DieNetView.RuneGlyph.new()
	glyph.name = "Zeichen"
	glyph.lines = Rune.glyph_lines(rune.glyph)
	glyph.weights = Rune.glyph_weights(rune.glyph)
	glyph.bounds = Rune.glyph_bounds(rune.glyph)
	glyph.tint = tone
	glyph.core = tone
	glyph.size = Vector2.ONE * side
	glyph.position = (rect.size - glyph.size) * 0.5
	glyph.modulate = Color(1.0, 1.0, 1.0, GLYPH_ALPHA)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.add_child(glyph)
	var effect: Array = RUNE_EFFECTS.get(rune_id, [rune.short, KIND_PLAIN, ""])
	var kind := String(effect[1])
	var color := kind_color(kind) if kind != KIND_PLAIN else tone
	var compact := rect.size.y < rect.size.x * 0.6
	var pad := rect.size.x * 0.05
	var tags: Array = KIND_TAGS.get(rune.kind, [TAG_BG, Color.WHITE])
	var tag_h := rect.size.y * (0.2 if compact else 0.11)
	var tag := _text(stripe, "Klasse", rune.kind, Rect2(Vector2(rect.size.x * 0.5,
		pad * 0.6), Vector2(rect.size.x * 0.5 - pad * 0.6, tag_h)), tags[1], false, tag_h * 0.75)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tag_box(tag, tags[0], true)
	if compact:
		# Mehrere Runen teilen das Fach: Wert links, Name und Wirkung rechts daneben.
		var value_w := rect.size.x * 0.38
		_text(stripe, "Wert", String(effect[0]), Rect2(Vector2(pad, rect.size.y * 0.12),
			Vector2(value_w, rect.size.y * 0.8)), color, true, rect.size.y * 0.6)
		_text(stripe, "Name", rune.display_name, Rect2(Vector2(value_w + pad, rect.size.y * 0.3),
			Vector2(rect.size.x - value_w - pad * 2.0, rect.size.y * 0.3)), tone, false,
			rect.size.y * 0.24)
		_text(stripe, "Wirkung", String(effect[2]), Rect2(Vector2(value_w + pad,
			rect.size.y * 0.6), Vector2(rect.size.x - value_w - pad * 2.0, rect.size.y * 0.3)),
			Color(0.89, 0.9, 0.96), false, rect.size.y * 0.2)
		return
	_text(stripe, "Wert", String(effect[0]), Rect2(Vector2(0, rect.size.y * 0.14),
		Vector2(rect.size.x, rect.size.y * 0.4)), color, true, rect.size.y * 0.38)
	_text(stripe, "Wirkung", String(effect[2]), Rect2(Vector2(pad, rect.size.y * 0.56),
		Vector2(rect.size.x - pad * 2.0, rect.size.y * 0.16)), Color(0.89, 0.9, 0.96), false,
		rect.size.y * 0.11)
	_text(stripe, "Name", rune.display_name, Rect2(Vector2(pad, rect.size.y * 0.76),
		Vector2(rect.size.x - pad * 2.0, rect.size.y * 0.16)), tone, false, rect.size.y * 0.11)

func _empty_slot(slot_name: String, rect: Rect2, what: String) -> void:
	var slot := _panel(slot_name, rect, Color(0, 0, 0, 0), EMPTY_RIM, 3.0)
	_text(slot, "Ohne", "Ohne", Rect2(Vector2(0, rect.size.y * 0.3),
		Vector2(rect.size.x, rect.size.y * 0.24)), EMPTY_TEXT, true, rect.size.y * 0.2)
	_text(slot, "Was", what, Rect2(Vector2(0, rect.size.y * 0.54),
		Vector2(rect.size.x, rect.size.y * 0.14)), EMPTY_TEXT, false, rect.size.y * 0.1)

# --- Bausteine ----------------------------------------------------------------

func _panel(panel_name: String, rect: Rect2, fill: Color, rim: Color, width: float,
		parent: Control = null) -> Panel:
	var panel := Panel.new()
	panel.name = panel_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(int(width))
	box.set_corner_radius_all(int(minf(rect.size.x, rect.size.y) * RADIUS_SHARE))
	panel.add_theme_stylebox_override("panel", box)
	(parent if parent != null else self).add_child(panel)
	panel.position = rect.position
	panel.size = rect.size
	return panel

## Eine Zeile, mittig, im größten Grad bis top_px, der ungeschnitten paßt. big = die
## Würfel-Schrift (Barlow), sonst die Schrift des Tisches.
func _text(parent: Control, label_name: String, text: String, rect: Rect2, color: Color,
		big: bool, top_px: float) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	var font: Font = DieFaceDisplay.NUMBER_FONT if big else ThemeDB.fallback_font
	if big:
		label.add_theme_font_override("font", font)
	var px := fit_size(font, text, rect.size, top_px)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_constant_override("outline_size", maxi(2, int(px * 0.12)))
	parent.add_child(label)
	label.position = rect.position
	label.size = rect.size
	EffectText.colorize(label)
	return label

## Der größte Grad bis top_px, in dem text einzeilig in room paßt.
static func fit_size(font: Font, text: String, room: Vector2, top_px: float) -> int:
	var px := maxi(6, int(top_px))
	if font == null:
		return px
	while px > 6 and (font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			> room.x * 0.94 or font.get_height(px) > room.y * 1.05):
		px -= 1
	return px

## Ein dunkles Schild hinter einer Zeile, so breit wie ihr Text.
func _tag_box(label: Label, fill: Color, right := false) -> void:
	var font: Font = label.get_theme_font("font")
	var px := label.get_theme_font_size("font_size")
	var wide := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x \
		+ px * 0.9 if font != null else label.size.x
	wide = minf(wide, label.size.x)
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(label.size.y * 0.3))
	var back := Panel.new()
	back.name = label.name + "Schild"
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel", box)
	label.get_parent().add_child(back)
	label.get_parent().move_child(back, label.get_index())
	var x := label.position.x + (label.size.x - wide if right else (label.size.x - wide) * 0.5)
	back.position = Vector2(x, label.position.y)
	back.size = Vector2(wide, label.size.y)
	if right:
		label.size.x -= px * 0.45
