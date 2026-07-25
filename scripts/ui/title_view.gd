class_name TitleView
extends Control
## Das Titel-HUD: Startbildschirm, Pausenmenü UND Ende-Bildschirm, gezeigt als
## Seite des Hubs (siehe HubView.attach_panel). Karten auf derselben Fläche -
## Menü, Einstellungen, Credits, Spielende; sichtbar ist immer genau eine.
## Nach einer verlorenen Partie ist die Ende-Karte die HEIMAT-Karte: der
## Rückweg endet dort, nicht im Menü.
##
## Die Titelkamera zeigt das ganze Hub-Fenster; der Inhalt sitzt mittig darin
## und lässt oben und unten Luft - der Rahmen soll als Rahmen lesbar bleiben.

signal new_game_requested
signal resume_requested
signal quit_requested
## Ein Regler wurde bewegt; anwenden und sichern tut scene_root (die Ansicht
## selbst fasst weder Engine noch Dateisystem an).
signal settings_changed

enum Card { MENU, SETTINGS, CREDITS, GAME_OVER }

const TITLE_GLOW := Color(1.7, 1.8, 2.0)   # überhelles Weiß (blüht)
const ACCENT := Color("#8be9fd")
const PINK := Color("#ff79c6")
const TEXT_COLOR := Color(1.2, 1.2, 1.18)
const LOSS := Color(1.7, 0.5, 0.42)  # überhelles Rot (blüht)

var settings: GameSettings = GameSettings.new()

var resume_button: Button
var volume_slider: HSlider
var volume_value: Label
var fullscreen_check: BaseButton
var game_over_result: Label
var game_over_round: Label

var _cards := {}  # Card -> Control
var _card: Card = Card.MENU
## Karte, auf die der Rückweg führt - nach einer verlorenen Partie das Ende.
var _home_card: Card = Card.MENU
var _built := false

## Baut die Karten passend zur (vom Hub gesetzten) Größe - einmalig.
func layout() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var u := size.x / 100.0
	_cards[Card.MENU] = _build_menu(u)
	_cards[Card.SETTINGS] = _build_settings(u)
	_cards[Card.CREDITS] = _build_credits(u)
	_cards[Card.GAME_OVER] = _build_game_over(u)
	show_card(Card.MENU)

## Übernimmt die geladenen Einstellungen (Regler/Schalter folgen den Werten).
func set_settings(loaded: GameSettings) -> void:
	settings = loaded
	if volume_slider != null:
		volume_slider.set_value_no_signal(settings.master_volume)
		_refresh_volume_value()
	if fullscreen_check != null:
		fullscreen_check.set_pressed_no_signal(settings.fullscreen)
		_refresh_fullscreen_label()

## "Weiterspielen" gibt es nur, wenn hinter dem Menü ein Lauf wartet.
func set_resumable(on: bool) -> void:
	if resume_button != null:
		resume_button.visible = on

## Ob hinter dem Menü ein Lauf wartet (am Startbildschirm nicht).
func is_resumable() -> bool:
	return resume_button != null and resume_button.visible

func show_card(card: Card) -> void:
	_card = card
	for key: Card in _cards:
		_cards[key].visible = key == card

## Zeigt die Heimat-Karte (Menü, nach einer verlorenen Partie das Ende).
func show_home() -> void:
	show_card(_home_card)

## Rechtsklick/Escape auf einer Unterkarte: zurück zur Heimat (true = verbraucht).
func go_back() -> bool:
	if _card == _home_card:
		return false
	show_home()
	return true

## Partie verloren: die Ende-Karte wird zur Heimat, "Weiterspielen" fällt weg.
func show_game_over(total: int, goal: int, round_number: int) -> void:
	game_over_result.text = "Ziel verfehlt: %d / %d Punkte" % [total, goal]
	game_over_round.text = "in Runde %d" % round_number
	set_resumable(false)
	_home_card = Card.GAME_OVER
	show_card(Card.GAME_OVER)

## Frischer Lauf: das Ende ist keine Heimat mehr.
func clear_game_over() -> void:
	_home_card = Card.MENU
	if _card == Card.GAME_OVER:
		show_card(Card.MENU)

# --- Karten ------------------------------------------------------------------

## Gemeinsames Gerüst: mittig zentrierte Spalte, damit der Beschnitt oben und
## unten nichts vom Inhalt abschneidet.
func _make_card(u: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(u * 1.6))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	return column

func _build_menu(u: float) -> Control:
	var column := _make_card(u)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "F U M B L E"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(u * 12.0))
	title.modulate = TITLE_GLOW
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Würfel-Roguelike"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", int(u * 3.6))
	subtitle.modulate = Color(PINK.r, PINK.g, PINK.b, 0.9)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(subtitle)

	column.add_child(_make_gap(u * 3.5))

	resume_button = _make_button(column, "Weiterspielen", CasinoStyle.GREEN, CasinoStyle.GREEN_DARK, u,
		func() -> void: resume_requested.emit())
	resume_button.visible = false
	_make_button(column, "Neues Spiel", CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, u,
		func() -> void: new_game_requested.emit())
	_make_button(column, "Einstellungen", CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, u,
		func() -> void: show_card(Card.SETTINGS))
	_make_button(column, "Credits", CasinoStyle.BLUE, CasinoStyle.BLUE_DARK, u,
		func() -> void: show_card(Card.CREDITS))
	_make_button(column, "Beenden", CasinoStyle.RED, CasinoStyle.RED_DARK, u,
		func() -> void: quit_requested.emit())
	return column.get_parent()

func _build_settings(u: float) -> Control:
	var column := _make_card(u)
	column.add_child(_make_heading("Einstellungen", u))
	column.add_child(_make_gap(u * 1.5))

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = settings.master_volume
	volume_slider.custom_minimum_size = Vector2(u * 34.0, u * 4.5)
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_slider.modulate = ACCENT
	volume_slider.value_changed.connect(_on_volume_changed)
	volume_value = Label.new()
	volume_value.custom_minimum_size = Vector2(u * 9.0, 0)
	volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_value.add_theme_font_size_override("font_size", int(u * 3.6))
	volume_value.modulate = TEXT_COLOR
	volume_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_make_row("Lautstärke", u, [volume_slider, volume_value]))
	_refresh_volume_value()

	# Schalt-Knopf statt CheckButton: dessen Theme-Symbol wüchse nicht mit u und
	# bliebe auf dem hochaufgelösten Display ein Krümel.
	fullscreen_check = Button.new()
	fullscreen_check.toggle_mode = true
	fullscreen_check.focus_mode = Control.FOCUS_NONE
	fullscreen_check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fullscreen_check.custom_minimum_size = Vector2(u * 16.0, u * 7.0)
	fullscreen_check.set_pressed_no_signal(settings.fullscreen)
	CasinoStyle.style_button(fullscreen_check, CasinoStyle.BLUE, CasinoStyle.BLUE_DARK, int(u * 3.6))
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_refresh_fullscreen_label()
	column.add_child(_make_row("Vollbild", u, [fullscreen_check]))

	column.add_child(_make_gap(u * 2.0))
	_make_button(column, "Zurück", CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, u,
		func() -> void: show_card(Card.MENU))
	return column.get_parent()

func _build_game_over(u: float) -> Control:
	var column := _make_card(u)

	var heading := Label.new()
	heading.text = "SPIEL VORBEI"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", int(u * 8.5))
	heading.modulate = LOSS
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)

	game_over_result = Label.new()
	game_over_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_result.add_theme_font_size_override("font_size", int(u * 4.2))
	game_over_result.modulate = TEXT_COLOR
	game_over_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(game_over_result)

	game_over_round = Label.new()
	game_over_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_round.add_theme_font_size_override("font_size", int(u * 3.6))
	game_over_round.modulate = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.85)
	game_over_round.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(game_over_round)

	column.add_child(_make_gap(u * 3.5))
	_make_button(column, "Neues Spiel", CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, u,
		func() -> void: new_game_requested.emit())
	_make_button(column, "Menü", CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, u,
		func() -> void: show_card(Card.MENU))
	return column.get_parent()

func _build_credits(u: float) -> Control:
	var column := _make_card(u)
	column.add_child(_make_heading("Credits", u))
	column.add_child(_make_gap(u * 1.5))
	for line in ["Fumble", "Entwicklung: Tristan Steffen", "Gebaut mit Godot 4.7"]:
		var label := Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", int(u * 3.8))
		label.modulate = TEXT_COLOR
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(label)
	column.add_child(_make_gap(u * 2.0))
	_make_button(column, "Zurück", CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, u,
		func() -> void: show_card(Card.MENU))
	return column.get_parent()

# --- Bausteine ---------------------------------------------------------------

func _make_heading(text: String, u: float) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(u * 7.0))
	label.modulate = ACCENT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap

## Beschriftete Zeile: Text links, Bedienelemente rechts.
func _make_row(text: String, u: float, controls: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u * 2.0))
	row.custom_minimum_size = Vector2(u * 62.0, u * 7.0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", int(u * 4.0))
	label.modulate = TEXT_COLOR
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	for control: Control in controls:
		row.add_child(control)
	return row

func _make_button(parent: Control, text: String, accent: Color, dark: Color,
		u: float, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(u * 48.0, u * 7.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	CasinoStyle.style_button(button, accent, dark, int(u * 4.0))
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button

# --- Einstellungen melden ----------------------------------------------------

func _on_volume_changed(value: float) -> void:
	settings.master_volume = value
	_refresh_volume_value()
	settings_changed.emit()

func _on_fullscreen_toggled(pressed: bool) -> void:
	settings.fullscreen = pressed
	_refresh_fullscreen_label()
	settings_changed.emit()

func _refresh_fullscreen_label() -> void:
	if fullscreen_check != null:
		fullscreen_check.text = "an" if fullscreen_check.button_pressed else "aus"

func _refresh_volume_value() -> void:
	if volume_value != null:
		volume_value.text = "%d%%" % roundi(settings.master_volume * 100.0)
