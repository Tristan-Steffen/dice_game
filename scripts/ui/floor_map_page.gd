class_name FloorMapPage
extends Control
## Die NAHSICHT des Grundrisses als Hub-Seite des Ladens (Knopf „Etage“): dieselbe Ansicht
## wie auf dem Grubenboden, nur zum Ansehen - Ziehen schiebt, das Rad zoomt, ein Klick zieht
## nie. „Zurück zum Laden“ blättert heim (die Seitenregel des Hubs).

signal close_requested

const TITLE := "E T A G E"
const BACK_SHOP_TEXT := "Zurück zum Laden"
const MARGIN_UNITS := 1.6
## Die Seite steht an der Hub-Station weiter weg als der Grubenboden: größere Einheit.
const MAP_UNIT_DIV := 62.0

var map_view: FloorPlanView
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
	back_button.text = BACK_SHOP_TEXT
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(back_button)
	map_view = FloorPlanView.new()
	map_view.name = "FloorPlan"
	map_view.mode = FloorPlanView.Mode.DETAIL
	map_view.read_only = true
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(map_view)
	resized.connect(_restyle)
	_restyle()

## Zeigt den Stand der Etage (reine Daten aus GameRun.floor_view_state).
func show_state(view_state: Dictionary) -> void:
	layout()
	map_view.open(view_state)

## Das Rad über dem Grundriß zoomt um den Zeiger (true = verbraucht).
func wheel_at(pixel: Vector2, up: bool) -> bool:
	if not visible or map_view == null or not map_view.get_global_rect().has_point(pixel):
		return false
	map_view.wheel(map_view.get_global_transform().affine_inverse() * pixel, up)
	return true

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
	map_view.unit_px = size.x / MAP_UNIT_DIV
