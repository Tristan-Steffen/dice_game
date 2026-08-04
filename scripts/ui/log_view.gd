class_name LogView
extends Control
## Der RÜCKBLICK in der Grube: die Chronik der laufenden Runde. Zwei Zustände auf
## demselben Control - die LISTE nimmt den ganzen Grubenboden (wie die
## Vertragswahl), nach der Wahl eines Eintrags bleibt nur die schmale LEISTE am
## oberen Grubenrand stehen, damit der posierte Tisch darunter frei liegt.
##
## Die Einheit u kommt aus BEIDEN Achsen - die Grube ist breit und flach.

## Ein Eintrag der Liste wurde gewählt (Index in RoundLog.entries).
signal entry_selected(index: int)
## Ein Schritt vor (+1) oder zurück (-1).
signal step_requested(delta: int)
signal close_requested

const TITLE := "Rückblick"
const SUBTITLE := "Diese Runde"
const EMPTY_TEXT := "Noch nichts geschehen."

const TEXT_COLOR := Color("#e8e6ff")
const MUTED_COLOR := Color("#9a93c9")
const PANEL_BG := Color(0.05, 0.05, 0.13, 0.95)
const BAR_BG := Color(0.05, 0.05, 0.13, 0.72)
const CARD_BG := Color(0.09, 0.08, 0.19, 0.94)
const ACCENT := CasinoStyle.BLUE
## Der gewählte Eintrag steht golden im Rückblick - dieselbe Sprache wie die
## goldene Hervorhebung der zählenden Kombination.
const CURRENT_COLOR := CasinoStyle.GOLD

## Zeilen der Liste: {label, hand_index, kind}.
var rows: Array[Dictionary] = []
var compact := false
var current_entry := -1

var _list_rect := Rect2()
var _bar_rect := Rect2()
var _row_buttons: Array[Button] = []
var _step_label: Label
var _title_label: Label

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

## Baut die Liste neu und zeigt sie. entries kommt aus scene_root.
func open(entry_rows: Array[Dictionary]) -> void:
	rows = entry_rows.duplicate(true)
	compact = false
	current_entry = -1
	_apply_rect()
	_build()
	visible = true

func close() -> void:
	visible = false

## Umschalten zwischen Liste (ganzer Grubenboden) und Leiste (oberer Rand).
func set_compact(value: bool) -> void:
	if compact == value:
		return
	compact = value
	_apply_rect()
	_build()
	queue_redraw()

func set_list_rect(rect: Rect2) -> void:
	_list_rect = rect
	_apply_rect()

func set_bar_rect(rect: Rect2) -> void:
	_bar_rect = rect
	_apply_rect()

## Der Stand des Cursors in der Leiste: welcher Eintrag, welcher Schritt, was tut er.
func set_cursor(entry_index: int, step_index: int, step_total: int, step_label: String) -> void:
	current_entry = entry_index
	if _title_label != null:
		_title_label.text = "%s · Schritt %d/%d" % [_entry_title(entry_index), step_index + 1, step_total]
	if _step_label != null:
		_step_label.text = step_label

## Trifft der Mauszeiger den Rückblick? (Klick-Weiterleitung in scene_root.)
func hit(pixel: Vector2) -> bool:
	return visible and Rect2(position, size).has_point(pixel)

func _entry_title(index: int) -> String:
	if index < 0 or index >= rows.size():
		return TITLE
	return String(rows[index].get("label", TITLE))

func _apply_rect() -> void:
	var rect := _bar_rect if compact else _list_rect
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	position = rect.position
	size = rect.size

func _unit() -> float:
	if compact:
		return maxf(minf(size.x / 90.0, size.y / 3.4), 1.0)
	return maxf(minf(size.x / 100.0, size.y / 46.0), 1.0)

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_row_buttons.clear()
	_step_label = null
	_title_label = null
	if compact:
		_build_bar()
	else:
		_build_list()

## Listen-Zustand: Titel, dann je Hand eine Gruppe mit ihren Zeilen.
func _build_list() -> void:
	var u := _unit()
	var column := _padded_column(u * 2.0, u * 1.2, u * 0.6)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(u * 1.0))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var title := _line(TITLE, u * 4.0, TEXT_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_line(SUBTITLE, u * 2.4, MUTED_COLOR))
	head.add_child(_make_button("Schließen", u, func() -> void: close_requested.emit()))

	if rows.is_empty():
		column.add_child(_line(EMPTY_TEXT, u * 2.6, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
		return

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", int(u * 0.4))
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var last_hand := -1
	for i in rows.size():
		var hand := int(rows[i].get("hand_index", 0))
		if hand != last_hand:
			list.add_child(_line("Hand %d" % (hand + 1), u * 2.2, MUTED_COLOR))
			last_hand = hand
		var row_button := _make_row(i, u)
		list.add_child(row_button)
		_row_buttons.append(row_button)

## Leisten-Zustand: ein Schritt, zwei Pfeile, zurück zur Liste.
func _build_bar() -> void:
	var u := _unit()
	var bar := _padded_column(u * 1.2, u * 0.4, u * 0.2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u * 0.8))
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)

	row.add_child(_make_button("◀", u, func() -> void: step_requested.emit(-1)))

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	_title_label = _line(_entry_title(current_entry), u * 1.9, MUTED_COLOR)
	texts.add_child(_title_label)
	_step_label = _line("", u * 2.6, TEXT_COLOR)
	texts.add_child(_step_label)

	row.add_child(_make_button("▶", u, func() -> void: step_requested.emit(1)))
	row.add_child(_make_button("Liste", u, func() -> void: set_compact(false)))
	row.add_child(_make_button("Schließen", u, func() -> void: close_requested.emit()))

func _padded_column(side: float, top: float, separation: float) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(side))
	margin.add_theme_constant_override("margin_right", int(side))
	margin.add_theme_constant_override("margin_top", int(top))
	margin.add_theme_constant_override("margin_bottom", int(top))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(separation))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	return column

## Eine Zeile der Chronik - die ganze Zeile IST der Knopf.
func _make_row(index: int, u: float) -> Button:
	var row_button := Button.new()
	row_button.name = "Row_%d" % index
	row_button.text = String(rows[index].get("label", ""))
	row_button.focus_mode = Control.FOCUS_NONE
	row_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_button.add_theme_font_size_override("font_size", maxi(8, int(u * 2.4)))
	var accent := CURRENT_COLOR if index == current_entry else ACCENT
	row_button.add_theme_color_override("font_color", TEXT_COLOR)
	row_button.add_theme_color_override("font_hover_color", CURRENT_COLOR)
	row_button.add_theme_stylebox_override("normal", _box(accent, 0.55, u))
	row_button.add_theme_stylebox_override("hover", _box(accent, 1.0, u))
	row_button.add_theme_stylebox_override("pressed", _box(accent, 1.0, u))
	row_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	row_button.pressed.connect(func() -> void: entry_selected.emit(index))
	return row_button

func _make_button(text: String, u: float, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", maxi(8, int(u * 2.2)))
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", CURRENT_COLOR)
	button.add_theme_stylebox_override("normal", _box(ACCENT, 0.6, u))
	button.add_theme_stylebox_override("hover", _box(ACCENT, 1.0, u))
	button.add_theme_stylebox_override("pressed", _box(ACCENT, 1.0, u))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(on_press)
	return button

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

func _box(accent: Color, strength: float, u: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = CARD_BG.lerp(Color(accent.r, accent.g, accent.b, CARD_BG.a), 0.14 * strength)
	box.border_color = Color(accent.r, accent.g, accent.b, strength)
	box.set_border_width_all(maxi(1, int(u * 0.2)))
	box.set_corner_radius_all(int(u * 0.9))
	box.content_margin_left = u * 1.0
	box.content_margin_right = u * 1.0
	box.content_margin_top = u * 0.4
	box.content_margin_bottom = u * 0.4
	return box

## Die Liste deckt den Grubenboden, die Leiste legt sich nur als schmales Band
## darüber - unter ihr sollen die posierten Würfel frei liegen.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_BG if not compact else BAR_BG)
