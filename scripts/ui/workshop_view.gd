class_name WorkshopView
extends Panel
## Tisch-Fenster rechts vom Hub: das Lager der gekauften, noch VERSIEGELTEN
## Pakete. Hier - und nur hier - werden sie geöffnet; der Laden verkauft nur.
## Zustands-Mutation läuft über GameRun; die Zeremonie hängt an pack_activated.

## Der Spieler will das Paket auf Platz index öffnen.
signal pack_activated(index: int)

const TITLE_COLOR := Color("#8be9fd")
const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")

## Farbe je Paketsorte - dieselbe Zuordnung wie im Laden.
const PACK_COLORS := {
	Pack.TYPE_DICE: Color("#8be9fd"),
	Pack.TYPE_NUMBER: Color("#50fa7b"),
	Pack.TYPE_MATERIAL: Color("#ff79c6"),
	Pack.TYPE_EDGE: Color("#ffd319"),
}

var run: GameRun:
	set(value):
		if run == value:
			return
		if run != null and run.packs_changed.is_connected(refresh):
			run.packs_changed.disconnect(refresh)
		run = value
		if run != null:
			run.packs_changed.connect(refresh)
		refresh()

var _content: VBoxContainer
## Öffnen-Knöpfe der Lagerkarten, Reihenfolge = owned_packs.
var _pack_buttons: Array[Button] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # die Knöpfe fangen selbst
	clip_contents = true
	add_theme_stylebox_override("panel", TableScreen.window_style())
	refresh()

func refresh() -> void:
	if not is_inside_tree():
		return
	var u := maxf(size.x, 200.0) / 100.0
	if _content != null and is_instance_valid(_content):
		remove_child(_content)
		_content.queue_free()
	_pack_buttons.clear()

	_content = VBoxContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = u * 3.0
	_content.offset_right = -u * 3.0
	_content.offset_top = u * 2.2
	_content.offset_bottom = -u * 2.2
	_content.add_theme_constant_override("separation", int(u * 1.6))
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_content.add_child(_label("WERKSTATT", u * 5.0, TITLE_COLOR))

	var packs: Array[Pack] = []
	if run != null:
		packs = run.owned_packs
	if packs.is_empty():
		var hint := _label("Kein Paket im Lager.\nIm Laden gibt es welche.", u * 2.6, MUTED_COLOR)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_content.add_child(hint)
		return

	var shelf := HFlowContainer.new()
	shelf.add_theme_constant_override("h_separation", int(u * 1.4))
	shelf.add_theme_constant_override("v_separation", int(u * 1.4))
	shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(shelf)
	for i in packs.size():
		shelf.add_child(_pack_card(packs[i], i, u))

## Lagerkarte: Siegel, Sorte, Inhaltsmenge - und der Öffnen-Knopf.
func _pack_card(pack: Pack, index: int, u: float) -> Control:
	var accent: Color = PACK_COLORS.get(pack.type, TITLE_COLOR)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(u * 26.0, u * 26.0)
	button.tooltip_text = pack.description
	_style_button(button, accent)
	button.pressed.connect(func() -> void: pack_activated.emit(index))
	_pack_buttons.append(button)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(u * 0.5))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)

	var seal := _label("✦", u * 6.0, accent)
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(seal)
	var name_label := _label(pack.display_name, u * 2.4, TEXT_COLOR)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)
	var count_label := _label(_content_text(pack), u * 2.0, MUTED_COLOR)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(count_label)
	var open_label := _label("Öffnen", u * 2.2, GOLD)
	open_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(open_label)
	return button

func _content_text(pack: Pack) -> String:
	if pack.is_dice_pack():
		return "%d Würfel" % pack.count
	return "%d %s" % [pack.count, Engraving.CATEGORY_NAMES[pack.engraving_category()]]

# --- Bausteine -----------------------------------------------------------------

func _label(text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_stylebox_override("normal", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("hover", _button_box(Color("#2c2757dd"), GOLD))
	button.add_theme_stylebox_override("pressed", _button_box(Color("#3a2f66"), GOLD))
	button.add_theme_stylebox_override("focus", _button_box(Color("#221e46cc"), accent))

func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var u := maxf(size.x, 200.0) / 100.0
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.2)))
	box.set_corner_radius_all(int(u * 0.9))
	box.set_content_margin_all(int(u * 0.6))
	return box
