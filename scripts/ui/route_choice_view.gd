class_name RouteChoiceView
extends Control
## Die Vertragswahl IN DER GRUBE: drei Verträge liegen auf dem Grubenboden,
## sobald der Spieler die Runde dort zum ersten Mal aufnimmt - unterschrieben
## wird, bevor der erste Würfel fällt. Kein Schließen-Knopf: die Grube darf man
## verlassen (die Karten liegen beim nächsten Grubenzoom wieder), nur werfen kann
## niemand ohne Vertrag.
##
## Die Einheit u kommt aus BEIDEN Achsen (die Grube ist breit und flach - allein
## aus der Breite gerechnet würde die Schrift riesig).

## Der unterschriebene Platz der Auslage (Index in GameRun.route_offers).
signal route_chosen(index: int)

const TITLE := "Vertragswahl"
const STRESS_TITLE := "Stresstest-Konditionen"

const BONUS_COLOR := Color("#50fa7b")
const MALUS_COLOR := Color("#ff6b6b")
const TEXT_COLOR := Color("#e8e6ff")
const MUTED_COLOR := Color("#9a93c9")
const CARD_BG := Color(0.07, 0.06, 0.16, 0.96)
## Spanne der Paragraphen-Nummer auf der Karte - reine Zierde, je Auslage neu.
const SECTION_MIN := 3
const SECTION_MAX := 219

## Angebotene Vertragskarten (GameRun.route_offers); open() baut daraus die Karten.
var offers: Array[Dictionary] = []
## Stresstest-Runde: andere Überschrift, die Karten sind Boss-Konditionen.
var stress_round := false
## Bonus-Faktor des Winkeladvokats; die Karte zeigt die verdoppelten Zahlen.
var bonus_factor := 1

var _cards: Array[Control] = []

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true  # nie über den Hub-Rahmen hinaus (dort endet die Maus)

## Baut die Auslage neu auf und zeigt sie. cards kommt aus GameRun.route_offers.
func open(cards: Array[Dictionary], is_stress: bool = false, deal_bonus_factor: int = 1) -> void:
	offers = cards.duplicate()
	stress_round = is_stress
	bonus_factor = deal_bonus_factor
	_build()
	visible = true

func close() -> void:
	visible = false

## Maßeinheit aus BEIDEN Achsen: die Auslage nimmt den ganzen Grubenboden, der
## ist breit und flach. Der Höhen-Teiler bremst nur noch extrem flache Gruben -
## im Normalfall bestimmt die Breite (drei Karten nebeneinander).
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
	margin.add_theme_constant_override("margin_left", int(u * 2.0))
	margin.add_theme_constant_override("margin_right", int(u * 2.0))
	margin.add_theme_constant_override("margin_top", int(u * 1.2))
	margin.add_theme_constant_override("margin_bottom", int(u * 1.2))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(u * 1.0))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	column.add_child(_line(TITLE if not stress_round else STRESS_TITLE,
		u * 4.4, TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u * 1.4))
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	for i in offers.size():
		var card := _make_card(offers[i], i, u)
		row.add_child(card)
		_cards.append(card)

## Eine Vertragskarte: Stufenname im Akzent, darunter der Bonus grün und der
## Malus rot, je mit Laufzeit-Etikett. Farbe trennt beide - kein Zwischentitel.
## Die ganze Karte IST der Knopf.
func _make_card(offer: Dictionary, index: int, u: float) -> Control:
	var tier := int(offer.get(GameRun.CARD_TIER, DealClause.Tier.ONE))
	var accent := CasinoStyle.contract_tier_color(tier)
	var card := Button.new()
	card.name = "Card_%d" % index
	card.focus_mode = Control.FOCUS_NONE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.pressed.connect(func() -> void: route_chosen.emit(index))
	_style_card(card, accent, u)

	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", int(u * 1.2))
	pad.add_theme_constant_override("margin_right", int(u * 1.2))
	pad.add_theme_constant_override("margin_top", int(u * 0.9))
	pad.add_theme_constant_override("margin_bottom", int(u * 0.9))
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(pad)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(u * 0.4))
	column.alignment = BoxContainer.ALIGNMENT_CENTER  # Inhalt mittig statt oben klebend
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(column)

	# Lange Namen dürfen weder an der Kartenkante abreißen noch MITTEN IM WORT
	# umbrechen: Umbruch nur an Leerzeichen, und je länger der Name, desto
	# kleiner die Schrift.
	var tier_name := DealClause.tier_label(tier)
	var title := _line(tier_name, u * _title_scale(tier_name), accent)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_line("§ %d" % _section_for(offer), u * 2.0,
		MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
	_add_clause_block(column, String(offer.get(GameRun.CARD_BONUS, "")), BONUS_COLOR, u, bonus_factor)
	_add_clause_block(column, String(offer.get(GameRun.CARD_MALUS, "")), MALUS_COLOR, u)
	return card

## Paragraphen-Nummer: reine Zierde, aber AUS DEN KLAUSELN abgeleitet - so steht
## dieselbe Zahl wieder da, wenn der Spieler die Grube verlässt und zurückkommt.
func _section_for(offer: Dictionary) -> int:
	var stamp := String(offer.get(GameRun.CARD_BONUS, "")) + String(offer.get(GameRun.CARD_MALUS, ""))
	return SECTION_MIN + absi(hash(stamp)) % (SECTION_MAX - SECTION_MIN + 1)

func _add_clause_block(column: VBoxContainer, clause_id: String, color: Color, u: float, factor: int = 1) -> void:
	if DealClause.find(clause_id) == null:
		return
	# Nur die Wirkung, mittig (die Karte ist breiter als hoch). Die Laufzeit steht
	# nicht mehr auf der Karte - sie lebt an den Deal-Marken (Größe = Dauer).
	var body := _line(DealClause.text_for(clause_id, factor), u * 2.8, color, HORIZONTAL_ALIGNMENT_CENTER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)

## Schriftgröße des Kartennamens (in u): das längste Wort muss in die schmale
## Karte passen, sonst steht es zerhackt da.
func _title_scale(name_text: String) -> float:
	var longest := 0
	for word in name_text.split(" ", false):
		longest = maxi(longest, word.length())
	if longest >= 17:
		return 2.8  # "Stresstest-Kondition" - ein Wort, das nirgends umbrechen kann
	if longest >= 15:
		return 3.2
	if longest >= 11:
		return 3.7
	return 4.2

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
