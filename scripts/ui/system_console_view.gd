class_name SystemConsoleView
extends Control
## Die Systemkonsole - Hub-Seite zum Übertakten der Kombinations-Chips: links
## das Chip-Raster (Reihenfolge = Tisch-Cluster), rechts das Detail des
## gewählten Chips mit aktueller Stufe, Vorschau der nächsten und dem
## Übertakten-Knopf. Kein Stufen-Limit - der Preis steigt je Stufe (GameRun).
## "Zurück" schließt die Seite; der Hub holt die verdrängte Seite (Shop) zurück.
## Alle Maße: Einheit u = Breite/100 (wie HubView/Shop).

const TITLE_COLOR := Color("#ff79c6")
const TEXT_COLOR := Color(1.35, 1.35, 1.3)  # überhelles Weiß (Glow)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const CYAN := Color("#8be9fd")
const GOLD := Color("#ffd319")
const GREEN := Color("#50fa7b")
const CHIP_BG := Color("#1a1836cc")
const CHIP_SELECTED_BG := Color("#2a2456")
const GRID_COLUMNS := 3

## Der laufende Spiellauf; die Konsole hört auf Geld/Stufen-Änderungen.
var run: GameRun:
	set(value):
		if run != null:
			if run.money_changed.is_connected(_on_run_changed_int):
				run.money_changed.disconnect(_on_run_changed_int)
			if run.combo_upgraded.is_connected(_on_combo_upgraded):
				run.combo_upgraded.disconnect(_on_combo_upgraded)
		run = value
		if run != null:
			run.money_changed.connect(_on_run_changed_int)
			run.combo_upgraded.connect(_on_combo_upgraded)

var selected_key: String = DiceScoring.HAND_PRIORITY[0]
var u := 8.0

var money_label: Label
var chip_buttons: Dictionary = {}  # combo_key -> Button
var detail_panel: PanelContainer
var overclock_button: Button
var _content: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visible = false

## Öffnet die Konsole (baut das Gerüst passend zur aktuellen Größe).
func open() -> void:
	_rebuild()
	visible = true

# --- Aufbau --------------------------------------------------------------------

func _rebuild() -> void:
	u = maxf(size.x, 640.0) / 100.0
	if _content != null and is_instance_valid(_content):
		_content.queue_free()
	chip_buttons.clear()

	_content = VBoxContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = u * 4.0
	_content.offset_right = -u * 4.0
	_content.offset_top = u * 3.0
	_content.offset_bottom = -u * 3.0
	_content.add_theme_constant_override("separation", int(u * 2.0))
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	# Kopfzeile: Titel links, Geld rechts.
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _label("SYSTEMKONSOLE", u * 4.6, TITLE_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	money_label = _label("$%d" % (run.money if run != null else 0), u * 4.2, GOLD)
	header.add_child(money_label)
	_content.add_child(header)

	_content.add_child(_label("Chip wählen und übertakten - jede Stufe hebt Punkte und Multiplikator.", u * 2.3, MUTED_COLOR))

	# Rumpf: Chip-Raster links, Detail rechts.
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(u * 3.0))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(body)

	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", int(u * 1.2))
	grid.add_theme_constant_override("v_separation", int(u * 1.2))
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(grid)
	for key: String in DiceScoring.HAND_PRIORITY:
		var chip := _chip_button(key)
		grid.add_child(chip)
		chip_buttons[key] = chip

	detail_panel = PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(u * 28.0, 0)
	body.add_child(detail_panel)
	_rebuild_detail()

	# Fußzeile: Zurück rechts (der Hub holt den Shop zurück).
	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(spacer)
	var back := Button.new()
	back.text = "Zurück"
	back.focus_mode = Control.FOCUS_NONE
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back.custom_minimum_size = Vector2(u * 16.0, u * 5.0)
	CasinoStyle.style_button(back, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, maxi(10, int(u * 2.6)))
	back.pressed.connect(func() -> void: visible = false)
	footer.add_child(back)
	_content.add_child(footer)

## Ein Chip im Raster: Name + Stufe, Rahmenfarbe folgt der Stufe (wie die
## Zellen im Kombinationen-Fenster).
func _chip_button(key: String) -> Button:
	var level := run.combo_level(key) if run != null else 0
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(u * 16.0, u * 7.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Lange Namen dürfen die Spaltenbreite nie sprengen (Button bricht nicht um).
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.text = "%s\n%s" % [DiceScoring.label_for(key), _level_text(level)]
	button.add_theme_font_size_override("font_size", maxi(9, int(u * 1.7)))
	button.add_theme_color_override("font_color", TEXT_COLOR if key == selected_key else MUTED_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	var accent := _level_color(level)
	var selected := key == selected_key
	button.add_theme_stylebox_override("normal", _chip_box(CHIP_SELECTED_BG if selected else CHIP_BG, accent, selected))
	button.add_theme_stylebox_override("hover", _chip_box(CHIP_SELECTED_BG, accent, selected))
	button.add_theme_stylebox_override("pressed", _chip_box(CHIP_SELECTED_BG, accent, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(select_combo.bind(key))
	return button

## Wählt einen Chip an (Raster-Hervorhebung + Detail neu).
func select_combo(key: String) -> void:
	if key == selected_key:
		return
	selected_key = key
	_rebuild()

## Detailtafel des gewählten Chips: Stufe, Jetzt-Werte, Vorschau, Kauf-Knopf.
func _rebuild_detail() -> void:
	if detail_panel == null:
		return
	for child in detail_panel.get_children():
		child.queue_free()
	var style := StyleBoxFlat.new()
	style.bg_color = CHIP_BG
	style.border_color = _level_color(run.combo_level(selected_key) if run != null else 0)
	style.set_border_width_all(maxi(1, int(u * 0.25)))
	style.set_corner_radius_all(int(u * 1.2))
	style.set_content_margin_all(int(u * 2.0))
	detail_panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(u * 1.2))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_panel.add_child(box)

	if run == null:
		box.add_child(_label("Kein Lauf.", u * 2.6, MUTED_COLOR))
		return
	var level := run.combo_level(selected_key)
	box.add_child(_label(DiceScoring.label_for(selected_key), u * 3.4, TEXT_COLOR))
	box.add_child(_label("Stufe %d" % level, u * 2.6, _level_color(level)))
	box.add_child(_label("Jetzt: %d Punkte × %d" % [
		DiceScoring.points_for(selected_key, run.combo_levels),
		DiceScoring.mult_for(selected_key, run.combo_levels)], u * 2.5, CYAN))
	var next_levels := run.combo_levels.duplicate()
	next_levels[selected_key] = level + 1
	box.add_child(_label("Stufe %d: %d Punkte × %d" % [level + 1,
		DiceScoring.points_for(selected_key, next_levels),
		DiceScoring.mult_for(selected_key, next_levels)], u * 2.5, MUTED_COLOR))

	overclock_button = Button.new()
	overclock_button.focus_mode = Control.FOCUS_NONE
	overclock_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	overclock_button.custom_minimum_size = Vector2(0, u * 6.0)
	overclock_button.text = "Übertakten — $%d" % run.overclock_price(selected_key)
	overclock_button.disabled = not run.can_overclock(selected_key)
	CasinoStyle.style_button(overclock_button, CasinoStyle.GREEN, CasinoStyle.GREEN_DARK, maxi(10, int(u * 2.6)))
	overclock_button.pressed.connect(_on_overclock_pressed)
	box.add_child(overclock_button)

func _on_overclock_pressed() -> void:
	if run == null or not run.can_overclock(selected_key):
		return
	run.overclock_combo(selected_key)  # combo_upgraded baut die Seite neu

# --- Aktualisierung --------------------------------------------------------------

## Geldstand ändert sich (Kauf hier oder anderswo): Anzeige + Kaufbarkeit.
func _on_run_changed_int(_value: int) -> void:
	if not visible:
		return
	if money_label != null and is_instance_valid(money_label):
		money_label.text = "$%d" % run.money
	if overclock_button != null and is_instance_valid(overclock_button):
		overclock_button.disabled = not run.can_overclock(selected_key)

func _on_combo_upgraded(_key: String, _level: int) -> void:
	if visible:
		_rebuild()

# --- Bausteine -----------------------------------------------------------------

## Stufe -> Anzeigetext ("—", "Stufe 3").
func _level_text(level: int) -> String:
	return "—" if level <= 0 else "Stufe %d" % level

## Stufe -> Akzentfarbe (wie der Zellrahmen: neutral, cyan, gold).
func _level_color(level: int) -> Color:
	if level >= ComboCellView.GOLD_LEVEL:
		return GOLD
	if level >= 1:
		return CYAN
	return MUTED_COLOR

func _chip_box(bg: Color, accent: Color, strong: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = accent if strong or accent != MUTED_COLOR else Color(accent.r, accent.g, accent.b, 0.45)
	box.set_border_width_all(maxi(1, int(u * (0.35 if strong else 0.2))))
	box.set_corner_radius_all(int(u * 0.9))
	box.set_content_margin_all(int(u * 0.8))
	return box

func _label(text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
