class_name LexikonView
extends Control
## Das Lexikon als Hub-Seite (HubView.attach_panel, wie Laden und Titel):
## eine Index-Karte mit allen Einträgen nach Kategorie und eine Eintrags-Karte
## mit querverlinktem Text (RichTextLabel, Verweise aus Lexikon.linkify).
## Verweisen folgen stapelt Browser-artig: go_back() läuft die Historie
## rückwärts, dann Eintrag -> Index, dann false (TitleView-Vertrag).

signal close_requested

enum Card { INDEX, ENTRY }

const INDEX_COLUMNS := 3

var _cards := {}  # Card -> Control
var _card: Card = Card.INDEX
var _history: Array[String] = []
var _shown := ""
var _built := false
## Der Index ist zugeklappt: je Kategorie ein Kopfknopf, das Gitter darunter.
var category_buttons := {}  # String -> Button
var category_grids := {}  # String -> GridContainer
## Falsch nach open_landing: der Rückweg endet am Eintrag, nicht am Index.
var _home_is_index := true

var entry_title: Label
var entry_category: Label
var entry_body: RichTextLabel
var _entry_scroll: ScrollContainer
var _u := 10.0

## Baut beide Karten passend zur (vom Hub gesetzten) Größe - einmalig.
func layout() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_u = size.x / 100.0
	_cards[Card.INDEX] = _build_index(_u)
	_cards[Card.ENTRY] = _build_entry(_u)
	_show_card(Card.INDEX)

func show_index() -> void:
	_home_is_index = true
	_show_card(Card.INDEX)

## Frischer Aufschlag direkt auf einem Eintrag (Schlüsselwort-Klick): der
## Rückweg endet HIER, nicht am Index - ein Rechtsklick führt zurück ins Spiel.
func open_landing(id: String) -> void:
	_history.clear()
	_home_is_index = false
	open_entry(id, false)

## Zeigt einen Eintrag; unbekannte ids fallen auf den Index zurück.
func open_entry(id: String, push_history := true) -> void:
	var e := Lexikon.entry(id)
	if e.is_empty():
		show_index()
		return
	if push_history and _card == Card.ENTRY and _shown != "" and _shown != e["id"]:
		_history.append(_shown)
	_shown = e["id"]
	entry_title.text = e["title"]
	entry_category.text = e["category"]
	entry_body.text = Lexikon.linkify(e["body"], _shown)
	if _entry_scroll != null:
		_entry_scroll.scroll_vertical = 0
	_show_card(Card.ENTRY)

## Ein Schritt zurück (true = verbraucht): Historie -> Index -> false. Ein
## Aufschlags-Eintrag ohne Historie gibt false zurück, damit der Aufrufer das
## Lexikon schließt statt den Index zu zeigen.
func go_back() -> bool:
	if _card != Card.ENTRY:
		return false
	if not _history.is_empty():
		open_entry(_history.pop_back(), false)
		return true
	if _home_is_index:
		show_index()
		return true
	return false

## Frischer Lauf: Historie weg, alle Kategorien zu, der nächste Besuch beginnt
## am Index.
func reset() -> void:
	_history.clear()
	_shown = ""
	_home_is_index = true
	_collapse_categories()
	if _built:
		show_index()

func shown_entry() -> String:
	return _shown if _card == Card.ENTRY else ""

func _show_card(card: Card) -> void:
	_card = card
	for key: Card in _cards:
		_cards[key].visible = key == card

# --- Karten ------------------------------------------------------------------

## Gemeinsames Gerüst: Randspalte mit Kopfzeile (Titel + Schließen).
func _make_card(u: float, heading: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(u * 3.0))
	margin.add_theme_constant_override("margin_right", int(u * 3.0))
	margin.add_theme_constant_override("margin_top", int(u * 2.0))
	margin.add_theme_constant_override("margin_bottom", int(u * 2.0))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(u * 1.2))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(u * 1.5))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var title := Label.new()
	title.text = heading
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_score_label(title, int(u * 4.2), CasinoStyle.GOLD)
	head.add_child(title)
	var close := Button.new()
	close.text = "✕  Schließen"
	close.focus_mode = Control.FOCUS_NONE
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	CasinoStyle.style_button(close, CasinoStyle.RED, CasinoStyle.RED_DARK, int(u * 2.2))
	close.pressed.connect(func() -> void: close_requested.emit())
	head.add_child(close)
	return column

func _build_index(u: float) -> Control:
	var column := _make_card(u, "📖  Lexikon")

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", int(u * 0.8))
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(list)

	for category in Lexikon.CATEGORIES:
		var ids := Lexikon.ids_in_category(category)
		var section := Button.new()
		section.focus_mode = Control.FOCUS_NONE
		section.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		section.alignment = HORIZONTAL_ALIGNMENT_LEFT
		section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			section.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		section.add_theme_font_size_override("font_size", int(u * 2.6))
		section.add_theme_color_override("font_color", CasinoStyle.MUTED)
		section.add_theme_color_override("font_hover_color", CasinoStyle.GOLD)
		list.add_child(section)
		var grid := GridContainer.new()
		grid.columns = INDEX_COLUMNS
		grid.add_theme_constant_override("h_separation", int(u * 1.5))
		grid.add_theme_constant_override("v_separation", int(u * 0.2))
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.visible = false
		list.add_child(grid)
		for id in ids:
			grid.add_child(_index_button(id, u))
		category_buttons[category] = section
		category_grids[category] = grid
		_label_category(category)
		section.pressed.connect(func() -> void: toggle_category(category))

	return column.get_parent()

## Klappt eine Kategorie auf oder zu - jede für sich, kein Akkordeon.
func toggle_category(category: String) -> void:
	var grid: GridContainer = category_grids.get(category)
	if grid == null:
		return
	grid.visible = not grid.visible
	_label_category(category)

func _collapse_categories() -> void:
	for category: String in category_grids:
		category_grids[category].visible = false
		_label_category(category)

func _label_category(category: String) -> void:
	var button: Button = category_buttons.get(category)
	var grid: GridContainer = category_grids.get(category)
	if button == null or grid == null:
		return
	var form := "▼  %s (%d)" if grid.visible else "▶  %s (%d)"
	button.text = form % [category, grid.get_child_count()]

## Flacher Verweis-Knopf im Chip-Schalen-Stil: kein Kasten, nur das Wort.
func _index_button(id: String, u: float) -> Button:
	var button := Button.new()
	var e := Lexikon.entry(id)
	button.text = e["title"]
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", int(u * 1.9))
	button.add_theme_color_override("font_color", CasinoStyle.LEXIKON_LINK)
	button.add_theme_color_override("font_hover_color", CasinoStyle.GOLD)
	button.add_theme_color_override("font_pressed_color", CasinoStyle.GOLD_INTENSE)
	button.pressed.connect(func() -> void: open_entry(id, false))
	return button

func _build_entry(u: float) -> Control:
	var column := _make_card(u, "📖  Lexikon")

	entry_title = Label.new()
	entry_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_score_label(entry_title, int(u * 3.4), CasinoStyle.CREAM)
	column.add_child(entry_title)
	entry_category = Label.new()
	entry_category.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_body_label(entry_category, int(u * 1.7), CasinoStyle.MUTED)
	column.add_child(entry_category)

	_entry_scroll = ScrollContainer.new()
	_entry_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_entry_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_entry_scroll)
	entry_body = RichTextLabel.new()
	entry_body.bbcode_enabled = true
	entry_body.fit_content = true
	entry_body.scroll_active = false  # der äußere ScrollContainer scrollt
	entry_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_body.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	entry_body.add_theme_font_size_override("normal_font_size", int(u * 2.1))
	entry_body.add_theme_color_override("default_color", CasinoStyle.CREAM)
	entry_body.add_theme_color_override("font_outline_color", CasinoStyle.INK)
	entry_body.add_theme_constant_override("outline_size", 2)
	entry_body.meta_clicked.connect(func(meta: Variant) -> void: open_entry(String(meta)))
	_entry_scroll.add_child(entry_body)

	var back := Button.new()
	back.text = "‹  Zurück"
	back.focus_mode = Control.FOCUS_NONE
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	CasinoStyle.style_button(back, CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, int(u * 2.2))
	# Auf einem Aufschlags-Eintrag gibt es keinen Weg zurück - dann schließt er.
	back.pressed.connect(func() -> void:
		if not go_back():
			close_requested.emit()
	)
	column.add_child(back)

	return column.get_parent()
