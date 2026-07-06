class_name PageStyle
## Gemeinsamer "Papier"-Look für Scorecard und Spielprotokoll.

const BG_COLOR := Color(0.94, 0.9, 0.78)
const BORDER_COLOR := Color(0.35, 0.25, 0.12)
const TEXT_COLOR := Color(0.15, 0.1, 0.05)
const MUTED_COLOR := Color(0.45, 0.38, 0.25)
const CELL_COLOR := Color(0.98, 0.96, 0.9)
const CELL_DISABLED_COLOR := Color(0.88, 0.84, 0.72)

static func apply_page_style(panel: Control, border_width: int = 3) -> void:
	var page_style := StyleBoxFlat.new()
	page_style.bg_color = BG_COLOR
	page_style.border_color = BORDER_COLOR
	page_style.set_border_width_all(border_width)
	page_style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", page_style)

static func make_cell_stylebox(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(4)
	return style

static func style_label(label: Label, color: Color = TEXT_COLOR) -> void:
	label.add_theme_color_override("font_color", color)

static func make_label(text: String, font_size: int, color: Color = TEXT_COLOR) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	style_label(label, color)
	return label

static func style_button(button: Button) -> void:
	var normal := make_cell_stylebox(CELL_COLOR)
	var disabled := make_cell_stylebox(CELL_DISABLED_COLOR)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color", MUTED_COLOR)

static func style_icon_button(button: Button) -> void:
	var style := make_cell_stylebox(BG_COLOR)
	style.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", TEXT_COLOR)

static func make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", BORDER_COLOR)
	return sep
