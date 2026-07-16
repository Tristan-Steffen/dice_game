class_name SigilDraftView
extends Control
## Lichtgravur-Ziehung als HUB-SEITE nach geräumter Runde: drei Siegel zünden
## nacheinander ins Bild, der Spieler wählt genau eines - die anderen verlöschen.
## Das gewählte Siegel wird über resolved(sigil_data) gemeldet (null = verzichtet);
## scene_root verbucht die Gutschrift und öffnet danach den Shop. Alle Maße
## leiten sich aus der eigenen Breite ab (u = Breite/100), damit die Seite den
## Hub füllt wie Shop und Gravur-Station.

## Ausgang der Ziehung: der gewählte Sigil oder null (verzichtet).
signal resolved(sigil_data: Sigil)

const IGNITE_TIME := 0.5
const IGNITE_STAGGER := 0.14
const TITLE_COLOR := Color("#ff79c6")
const MUTED := Color(0.75, 0.78, 0.9)

var offers: Array[Sigil] = []
var card_row: HBoxContainer
var _content: VBoxContainer
var _cards: Array[Control] = []
var _sigils: Array[SigilRenderer] = []
var resolving: bool = false  # Klicks nach der Wahl ignorieren

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	visible = false

## Öffnet die Ziehung mit der Auslage; die Siegel zünden gestaffelt ins Bild.
func show_draft(sigils: Array[Sigil]) -> void:
	offers = sigils
	resolving = false
	visible = true
	_rebuild()
	_ignite_in()

## Baut die Seite passend zur aktuellen Breite neu auf.
func _rebuild() -> void:
	var u := maxf(size.x, 400.0) / 100.0
	if _content != null and is_instance_valid(_content):
		_content.queue_free()
	_cards.clear()
	_sigils.clear()

	_content = VBoxContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", int(u * 2.4))
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_content.add_child(_label("LICHTGRAVUR-ZIEHUNG", u * 5.4, TITLE_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
	_content.add_child(_label("Wähle ein Siegel.", u * 2.8, MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	card_row = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", int(u * 3.0))
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(card_row)
	for i in offers.size():
		var card := _build_card(offers[i], i, u)
		card_row.add_child(card)
		_cards.append(card)

	var skip := Button.new()
	skip.text = "Verzichten"
	skip.focus_mode = Control.FOCUS_NONE
	skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	CasinoStyle.style_button(skip, CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, maxi(10, int(u * 2.6)))
	skip.pressed.connect(_on_skip)
	_content.add_child(skip)

## Ein Siegel-Karten-Button: Sigil + Name + Seltenheit, klickbar.
func _build_card(sigil_data: Sigil, index: int, u: float) -> Control:
	var card_size := Vector2(u * 26.0, u * 36.0)
	var sigil_size := Vector2(u * 17.0, u * 17.0)
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.custom_minimum_size = card_size
	card.pivot_offset = card_size / 2.0
	var seam: Color = SigilRenderer.SEAM_COLORS[sigil_data.rarity]
	card.add_theme_stylebox_override("normal", _card_box(seam, 0.0, u))
	card.add_theme_stylebox_override("hover", _card_box(seam, 0.14, u))
	card.add_theme_stylebox_override("pressed", _card_box(seam, 0.14, u))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.pressed.connect(_on_pick.bind(index))

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", int(u * 1.4))
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	var sigil_holder := CenterContainer.new()
	sigil_holder.custom_minimum_size = sigil_size
	sigil_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sigil := SigilRenderer.for_sigil(sigil_data)
	sigil.custom_minimum_size = sigil_size
	sigil.ignite = 0.0  # zündet gleich per Tween ein
	sigil_holder.add_child(sigil)
	column.add_child(sigil_holder)
	_sigils.append(sigil)

	var name_label := _label(sigil_data.display_name, u * 3.2, CasinoStyle.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(card_size.x - u * 2.0, 0)
	column.add_child(name_label)

	column.add_child(_label(Sigil.rarity_name(sigil_data.rarity), u * 2.4, seam, HORIZONTAL_ALIGNMENT_CENTER))
	return card

## Zündet die Siegel nacheinander ein (ignite 0 -> 1).
func _ignite_in() -> void:
	for i in _sigils.size():
		var tween := create_tween()
		tween.tween_interval(i * IGNITE_STAGGER)
		tween.tween_property(_sigils[i], "ignite", 1.0, IGNITE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_pick(index: int) -> void:
	if resolving or index < 0 or index >= offers.size():
		return
	resolving = true
	var chosen := offers[index]
	# Gewähltes Siegel pulst, die anderen verlöschen.
	for i in _cards.size():
		if i == index:
			_pulse(_cards[i])
		else:
			var fade := create_tween()
			fade.set_parallel(true)
			fade.tween_property(_sigils[i], "ignite", 0.0, 0.3)
			fade.tween_property(_cards[i], "modulate:a", 0.0, 0.35)
	var finish := create_tween()
	finish.tween_interval(0.55)
	finish.tween_callback(func() -> void: _close(chosen))

func _on_skip() -> void:
	if resolving:
		return
	resolving = true
	_close(null)

## Bricht eine offene Ziehung ab (z.B. Spiel-Reset): schließt und meldet null.
func cancel() -> void:
	if not visible or resolving:
		return
	resolving = true
	_close(null)

func _close(sigil_data: Sigil) -> void:
	visible = false
	if _content != null and is_instance_valid(_content):
		_content.queue_free()
		_content = null
	_cards.clear()
	_sigils.clear()
	resolved.emit(sigil_data)

## Neon-Rahmen der Karte; highlight hebt bei Hover die Füllung leicht an.
func _card_box(seam: Color, highlight: float, u: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.06, 0.11, 0.85 + highlight)
	box.border_color = Color(seam.r, seam.g, seam.b, 0.85)
	box.set_border_width_all(maxi(2, int(u * 0.28)))
	box.set_corner_radius_all(int(u * 1.6))
	box.set_content_margin_all(int(u * 1.2))
	return box

## Kurzer elastischer Puls (Bestätigung der Wahl).
func _pulse(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(1.12, 1.12)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.4)

func _label(text: String, font_size: float, color: Color, align: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
