class_name RouteChoiceView
extends Control
## Die Deal-Wahl IN DER GRUBE: drei Deals liegen auf dem Grubenboden (kühler, gleich,
## heißer), sobald der Spieler die Runde dort aufnimmt - unterschrieben wird vor dem
## ersten Wurf. Kein Schließen-Knopf: die Grube darf man verlassen, nur werfen kann
## niemand ohne Deal. Gespeist aus GameRun.route_view_state(); gerechnet wird nichts.

## Der unterschriebene Platz der Auslage (Index in GameRun.route_offers).
signal route_chosen(index: int)

const TITLE := "Deal wählen"
const STRESS_TITLE := "Boss-Konditionen"
const CARD_BG := Color(0.07, 0.06, 0.16, 0.96)
const BOSS_ACCENT := HeatStyle.BOSS_COLOR

var state: Dictionary = {}
var _cards: Array[Control] = []

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

## Baut die Auslage neu auf und zeigt sie.
func open(view_state: Dictionary) -> void:
	state = view_state.duplicate(true)
	_build()
	visible = true

func close() -> void:
	visible = false

func stress_round() -> bool:
	return bool(state.get("boss", false))

func cards() -> Array[Control]:
	return _cards

## Maßeinheit aus BEIDEN Achsen: die Grube ist breit und flach.
func _unit() -> float:
	return minf(size.x / 100.0, size.y / 46.0)

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_cards.clear()
	var u := maxf(_unit(), 1.0)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, int(u * 2.0))
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(u * 1.0))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(u * 0.8))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	column.add_child(CasinoStyle.label(_title_text(), u * 3.6, HeatStyle.TEXT_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER, 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u * 1.4))
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	var offers: Array = state.get("cards", [])
	for i in offers.size():
		var card := _make_card(offers[i], i, u, _fit_units(offers[i], u, maxi(1, offers.size())))
		row.add_child(card)
		_cards.append(card)

func _title_text() -> String:
	if stress_round():
		return STRESS_TITLE
	return TITLE

## Schriftgrade der Klauseln (in u), vom größten abwärts.
const TEXT_STEPS := [3.1, 2.8, 2.5, 2.25, 2.0, 1.8, 1.65, 1.5, 1.35, 1.2]
## Luft für Umriß und Rundung beim Messen.
const FIT_SLACK := 0.92

## Der größte Grad, in dem alle Klauseln der Karte ungeschnitten in ihren Rumpf passen.
func _fit_units(card: Dictionary, u: float, count: int) -> float:
	var font := get_theme_font("font", "Label")
	if font == null:
		return TEXT_STEPS[-1]
	var card_w := (size.x - float(int(u * 2.0)) * 2.0 - float(int(u * 1.4)) * float(count - 1)) / float(count)
	var inner_w := card_w - float(int(u * 1.1)) * 2.0
	var card_h := size.y - float(int(u)) * 2.0 - font.get_height(int(u * 3.6)) - float(int(u * 0.8))
	var fixed := float(int(u * 0.8)) * 2.0 + font.get_height(int(u * 3.4)) + font.get_height(int(u * 2.0)) \
		+ font.get_height(int(u * 2.2)) + float(int(u * 0.35)) * 3.0
	var budget := (card_h - fixed) * FIT_SLACK
	var texts: Array[String] = []
	for clause: Dictionary in card.get("bonus", []) + card.get("malus", []):
		texts.append(_clause_text(clause))
	for step: float in TEXT_STEPS:
		var total := float(int(u * 0.45)) * float(maxi(0, texts.size() - 1))
		for text in texts:
			total += font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, inner_w,
				int(u * step)).y
		if total <= budget:
			return step
	return TEXT_STEPS[-1]

static func _clause_text(clause: Dictionary) -> String:
	return String(clause.get("text", "")).trim_suffix(".")

func _make_card(card: Dictionary, index: int, u: float, text_units: float) -> Control:
	var boss := bool(card.get("boss", false))
	var level := int(card.get("level", 1))
	var accent := BOSS_ACCENT if boss else HeatStyle.color(level)
	var button := Button.new()
	button.name = "Card_%d" % index
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.pressed.connect(func() -> void: route_chosen.emit(index))
	_style_card(button, accent, u)
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, int(u * 1.1))
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(u * 0.8))
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(u * 0.35))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(column)
	var head := "Boss-Kondition" if boss else HeatStyle.level_name(level)
	var title := CasinoStyle.label(head, u * 3.4, accent, HORIZONTAL_ALIGNMENT_CENTER, 3)
	title.name = "Head"
	column.add_child(title)
	var effect := CasinoStyle.label(HeatStyle.effect_text(card), u * 2.0, HeatStyle.MUTED_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER, 2)
	effect.name = "Effect"
	column.add_child(effect)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", int(u * 0.45))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)
	for clause: Dictionary in card.get("bonus", []):
		body.add_child(_clause_label(clause, HeatStyle.BONUS_COLOR, u * text_units))
	for clause: Dictionary in card.get("malus", []):
		body.add_child(_clause_label(clause, HeatStyle.MALUS_COLOR, u * text_units))
	var foot := CasinoStyle.label(HeatStyle.foot_text(card), u * 2.2,
		HeatStyle.margin_color(String(card.get("margin", ""))), HORIZONTAL_ALIGNMENT_CENTER, 2)
	foot.name = "Foot"
	column.add_child(foot)
	return button

func _clause_label(clause: Dictionary, color: Color, font: float) -> Label:
	var label := CasinoStyle.label(_clause_text(clause), font, color, HORIZONTAL_ALIGNMENT_CENTER, 2)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1.0
	return label

func _style_card(card: Button, accent: Color, u: float) -> void:
	card.add_theme_stylebox_override("normal", _card_box(accent, 0.75, u))
	card.add_theme_stylebox_override("hover", _card_box(accent, 1.0, u))
	card.add_theme_stylebox_override("pressed", _card_box(accent, 1.0, u))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _card_box(accent: Color, strength: float, u: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = CARD_BG.lerp(Color(accent.r, accent.g, accent.b, CARD_BG.a), 0.12 * strength)
	box.border_color = Color(accent.r, accent.g, accent.b, strength)
	box.set_border_width_all(maxi(2, int(u * 0.3)))
	box.set_corner_radius_all(int(u * 1.4))
	box.shadow_color = Color(accent.r, accent.g, accent.b, 0.3 * strength)
	box.shadow_size = int(u * 0.9)
	return box
