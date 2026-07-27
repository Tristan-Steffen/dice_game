class_name RouteChoiceView
extends Control
## Die Routenwahl auf dem Tisch-Display: drei Deal-Karten als Hub-SEITE (wie der
## Shop, siehe HubView.attach_panel). Ohne Unterschrift beginnt keine Runde -
## darum hat die Seite bewusst kein Zurück und keinen Schließen-Knopf.
## Alle Maße leiten sich aus der eigenen Breite ab (Einheit u = Breite/100).

signal route_chosen(deal_id: String)

const TITLE := "Routenwahl"
const STRESS_TITLE := "Stresstest-Konditionen"
const SUBTITLE := "Eine Route wählen - der Deal gilt, bis die Abrechnung ihn löscht."
const STRESS_SUBTITLE := "Zum Stresstest: unter welchen Bedingungen soll er laufen?"

const BONUS_COLOR := Color("#50fa7b")
const MALUS_COLOR := Color("#ff6b6b")
const TEXT_COLOR := Color("#e8e6ff")
const MUTED_COLOR := Color("#9a93c9")
const CARD_BG := Color(0.07, 0.06, 0.16, 0.96)

## Angebotene Deal-ids; open() baut daraus die Karten.
var offers: Array[String] = []
## Stresstest-Runde: andere Überschrift, die Karten sind Boss-Konditionen.
var stress_round := false

var _cards: Array[Control] = []

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true  # nie über den Hub-Rahmen hinaus (dort endet die Maus)

## Baut die Auslage neu auf und zeigt sie. deal_ids kommt aus GameRun.route_offers.
func open(deal_ids: Array[String], is_stress: bool = false) -> void:
	offers = deal_ids.duplicate()
	stress_round = is_stress
	_build()
	visible = true

func close() -> void:
	visible = false

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_cards.clear()
	var u := maxf(size.x, 640.0) / 100.0

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(u * 3.0))
	margin.add_theme_constant_override("margin_right", int(u * 3.0))
	margin.add_theme_constant_override("margin_top", int(u * 2.5))
	margin.add_theme_constant_override("margin_bottom", int(u * 2.5))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(u * 1.6))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	column.add_child(_line(TITLE if not stress_round else STRESS_TITLE,
		u * 5.0, TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_line(SUBTITLE if not stress_round else STRESS_SUBTITLE,
		u * 2.6, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u * 2.0))
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	for deal_id in offers:
		var deal := RouteDeal.find(deal_id)
		if deal == null:
			continue
		var card := _make_card(deal, u)
		row.add_child(card)
		_cards.append(card)

## Eine Deal-Karte: Name im Akzent, Bonus grün, Malus rot, je mit Laufzeit-
## Etikett. Die ganze Karte IST der Knopf - ein Klick unterschreibt.
func _make_card(deal: RouteDeal, u: float) -> Control:
	var card := Button.new()
	card.name = "Card_%s" % deal.id
	card.focus_mode = Control.FOCUS_NONE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.pressed.connect(func() -> void: route_chosen.emit(deal.id))
	_style_card(card, deal.color, u)

	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", int(u * 1.6))
	pad.add_theme_constant_override("margin_right", int(u * 1.6))
	pad.add_theme_constant_override("margin_top", int(u * 1.4))
	pad.add_theme_constant_override("margin_bottom", int(u * 1.4))
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(pad)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(u * 0.9))
	column.alignment = BoxContainer.ALIGNMENT_CENTER  # Inhalt mittig statt oben klebend
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(column)

	# Lange Namen dürfen weder an der Kartenkante abreißen noch MITTEN IM WORT
	# umbrechen ("Doppelbelastun/g"): Umbruch nur an Leerzeichen, und je länger
	# der Name, desto kleiner die Schrift.
	var title := _line(deal.display_name, u * _title_scale(deal.display_name), deal.color)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(title)
	column.add_child(_side_block(deal.bonus_text, deal.bonus_scope, BONUS_COLOR, u))
	if deal.malus_text != "":
		column.add_child(_side_block(deal.malus_text, deal.malus_scope, MALUS_COLOR, u))
	return card

## Schriftgröße des Kartennamens (in u): das längste Wort muss in die schmale
## Karte passen, sonst steht es zerhackt da.
func _title_scale(name_text: String) -> float:
	var longest := 0
	for word in name_text.split(" ", false):
		longest = maxi(longest, word.length())
	if longest >= 15:
		return 2.5
	if longest >= 11:
		return 2.9
	return 3.4

## Eine Deal-Seite: Wirkung in ihrer Farbe, darunter klein die Laufzeit - die
## Laufzeit ist die eigentliche Entscheidung, sie darf nie fehlen.
func _side_block(text: String, scope: RouteDeal.Scope, color: Color, u: float) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body := _line(text, u * 2.5, color)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	block.add_child(body)
	block.add_child(_line(RouteDeal.scope_label(scope), u * 2.0, MUTED_COLOR))
	return block

func _line(text: String, font_size: float, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.add_theme_color_override("font_outline_color", CasinoStyle.SHADOW)
	label.add_theme_constant_override("outline_size", 3)
	label.modulate = color
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
