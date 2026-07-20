class_name CasinoStyle
## Bunter, Balatro-artiger Casino-Look für die 2D-Spiel-UI: kräftige Neon-
## Farben, dicke Ränder, satte runde Buttons, plakativer Text mit Umriss.

# Kräftige Casino-/Neon-Palette
const GOLD := Color("ffbf3f")
const GOLD_DARK := Color("c8912a")
const GOLD_INTENSE := Color("ffcc00")  # gesättigteres Gold für Aufleucht-Effekte
const RED := Color("fe5f55")
const RED_DARK := Color("c73a31")
const BLUE := Color("2f9ff0")
const BLUE_DARK := Color("1c6fb8")
const GREEN := Color("46c46e")
const GREEN_DARK := Color("2e8f4c")
const PURPLE := Color("9b5de5")
const PURPLE_DARK := Color("6f3bb0")

const PANEL_BG := Color("16212e")  # dunkles Nachtblau
const PANEL_BORDER := Color("ffbf3f")
const CREAM := Color("f6efdd")  # heller Text
const INK := Color("14202b")  # dunkler Text auf hellen Buttons
const MUTED := Color("8a95a1")  # deaktivierter Text
const SHADOW := Color(0, 0, 0, 0.55)

const DISABLED_FILL := Color("36414d")
const DISABLED_BORDER := Color("232c36")

## Satter, runder Aktions-Button: Hover hellt auf, Pressed dunkelt ab,
## Disabled ist entsättigt; Textkontrast folgt der Akzent-Helligkeit.
static func style_button(button: Button, accent: Color, dark: Color, font_size: int = 20) -> void:
	button.add_theme_stylebox_override("normal", _button_box(accent, dark))
	button.add_theme_stylebox_override("hover", _button_box(accent.lightened(0.14), GOLD))
	button.add_theme_stylebox_override("pressed", _button_box(dark, dark.darkened(0.2)))
	button.add_theme_stylebox_override("disabled", _button_box(DISABLED_FILL, DISABLED_BORDER))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", font_size)

	var text_color := _readable_text(accent)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", _readable_text(accent.lightened(0.14)))
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_color_override("font_outline_color", SHADOW)
	button.add_theme_constant_override("outline_size", 3)

static func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(9)
	box.shadow_color = SHADOW
	box.shadow_size = 5
	box.shadow_offset = Vector2(0, 3)
	return box

## Dunkler oder heller Text je nach Hintergrund-Helligkeit.
static func _readable_text(bg: Color) -> Color:
	var luma := bg.r * 0.299 + bg.g * 0.587 + bg.b * 0.114
	return INK if luma > 0.6 else CREAM

## Großer Punktetext: heller Text mit dickem Umriss und weichem Schatten.
static func style_score_label(label: Label, size: int = 30, color: Color = CREAM) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("shadow_outline_size", 4)

## Ruhiges Fließtext-Label auf dunklem Panel (dünner Umriss).
static func style_body_label(label: Label, size: int = 15, color: Color = CREAM) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 2)

## Tooltip aus einem "Name\nWirkung"-String: Name in Gold, Wirkung in Creme.
## Größen/Breite sind Parameter (2D-UI vs. hochaufgelöstes Display).
## Leerer String -> null (kein Tooltip).
static func build_material_tooltip(for_text: String, title_size: int = 20, body_size: int = 15, body_width: float = 280.0) -> Control:
	if for_text == "":
		return null
	var panel := PanelContainer.new()
	style_panel(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var parts := for_text.split("\n", false, 1)  # [Name, Wirkung]
	var title := Label.new()
	title.text = parts[0]
	style_score_label(title, title_size, GOLD)
	box.add_child(title)
	if parts.size() > 1:
		var body := Label.new()
		body.text = parts[1]
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(body_width, 0)
		style_body_label(body, body_size, CREAM)
		box.add_child(body)
	return panel

## Dunkles Casino-Panel mit dickem Goldrahmen und Schatten.
static func style_panel(panel: Control) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.border_color = PANEL_BORDER
	box.set_border_width_all(4)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(16)
	box.shadow_color = SHADOW
	box.shadow_size = 10
	panel.add_theme_stylebox_override("panel", box)
