class_name FloorMapPage
extends Control
## Die ETAGEN-KARTE als Hub-Seite im LADEN: dieselbe FloorMapView, nur zum Ansehen.
## Der Knopf „Zurück zum Laden“ blättert zurück; die Seitenregel des Hubs holt den Laden.

signal close_requested

const TITLE := "E T A G E"
const BACK_TEXT := "Zurück zum Laden"
const MARGIN_UNITS := 1.6

var map_view: FloorMapView
var back_button: Button
var _margin: MarginContainer
var _column: VBoxContainer
var _title: Label

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Baut das Gerüst (einmal); die Maße folgen der Größe (_restyle bei jedem resized).
func layout() -> void:
	if map_view != null:
		return
	_margin = MarginContainer.new()
	_margin.name = "Margin"
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(_column)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(header)
	_title = CasinoStyle.label(TITLE, 20.0, Color(0.75, 1.3, 1.5))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = BACK_TEXT
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(back_button)
	map_view = FloorMapView.new()
	map_view.name = "FloorMap"
	map_view.read_only = true
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(map_view)
	resized.connect(_restyle)
	_restyle()

## Zeigt den Stand der Etage (reine Daten aus GameRun.floor_view_state).
func show_state(view_state: Dictionary, deal_bonus_factor: int = 1) -> void:
	layout()
	map_view.open(view_state, deal_bonus_factor)

func _restyle() -> void:
	if _margin == null or size.x < 10.0:
		return
	var u := size.x / 100.0
	for side in ["margin_left", "margin_right"]:
		_margin.add_theme_constant_override(side, int(u * MARGIN_UNITS))
	for side in ["margin_top", "margin_bottom"]:
		_margin.add_theme_constant_override(side, int(u * 2.0))
	_column.add_theme_constant_override("separation", int(u * 1.5))
	_title.add_theme_font_size_override("font_size", int(u * 4.5))
	CasinoStyle.style_button(back_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, int(u * 2.8))
