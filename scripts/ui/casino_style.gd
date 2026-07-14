class_name CasinoStyle
## Bunter, Balatro-artiger Casino-Look für die 2D-Spiel-UI (Buttons, Labels,
## Panels). Bewusst getrennt vom schlichten "Papier"-Look der Scorecard/des
## Protokolls (siehe PageStyle) - hier geht es um kräftige Neon-/Casinofarben,
## dicke Ränder, satte runde Buttons und plakativen Punktetext mit Umriss.

# Kräftige Casino-/Neon-Palette
const GOLD := Color("ffbf3f")  # Geld-Farbe (Geldanzeige, "+$"-Popups) - siehe scene_root.gd
const GOLD_DARK := Color("c8912a")
const GOLD_INTENSE := Color("ffcc00")  # kräftigeres, gesättigteres Gold für kurze Aufleucht-Effekte (Tisch-Texte/Würfel beim Auszahlen, siehe scene_root.gd: _light_up_payout_label/_flash_die_tint)
const RED := Color("fe5f55")
const RED_DARK := Color("c73a31")
const BLUE := Color("2f9ff0")
const BLUE_DARK := Color("1c6fb8")
const GREEN := Color("46c46e")
const GREEN_DARK := Color("2e8f4c")
const PURPLE := Color("9b5de5")
const PURPLE_DARK := Color("6f3bb0")

const PANEL_BG := Color("16212e")  # dunkles Nachtblau
const PANEL_BORDER := Color("ffbf3f")  # Goldrahmen
const CREAM := Color("f6efdd")  # heller Text
const INK := Color("14202b")  # dunkler Text auf hellen (goldenen) Buttons
const MUTED := Color("8a95a1")  # deaktivierter Text
const SHADOW := Color(0, 0, 0, 0.55)

const DISABLED_FILL := Color("36414d")
const DISABLED_BORDER := Color("232c36")

## Satter, runder Aktions-Button in einer Akzentfarbe (accent) mit dunklerem
## Rand (dark). Hover hellt auf, Pressed dunkelt ab, Disabled ist entsättigt.
## Der Textkontrast (hell/dunkel) richtet sich automatisch nach der Helligkeit
## der Akzentfarbe (siehe _readable_text).
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

## Dunkler oder heller Text je nach Helligkeit der Hintergrundfarbe - damit
## Gold (hell) dunklen, Rot/Blau/Grün (satt) hellen Text bekommt.
static func _readable_text(bg: Color) -> Color:
	var luma := bg.r * 0.299 + bg.g * 0.587 + bg.b * 0.114
	return INK if luma > 0.6 else CREAM

## Großer, energiegeladener Punktetext (die Hand-Anzeige) - heller Text mit
## dickem dunklem Umriss und weichem Schatten für den Neon-Casino-Look.
static func style_score_label(label: Label, size: int = 30, color: Color = CREAM) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("shadow_outline_size", 4)

## Kleineres "Casino-Chip"-Label (z.B. Rundeninfo) - goldener Text mit Umriss.
static func style_chip_label(label: Label, size: int = 20, color: Color = GOLD) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 5)

## Ruhiges Fließtext-Label auf dunklem Panel (z.B. Kombinationen-Liste) - heller
## Text mit nur dünnem Umriss, damit mehrzeilige Listen nicht überladen wirken.
static func style_body_label(label: Label, size: int = 15, color: Color = CREAM) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 2)

## Dunkler "Arcade"-Zielbalken (Rundenfortschritt): dunkler Hintergrund mit
## Goldrahmen, satte Goldfüllung - siehe scene_root.gd: _animate_points_to.
static func style_progress_bar(bar: ProgressBar) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("0d151d")
	background.border_color = PANEL_BORDER
	background.set_border_width_all(2)
	background.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", background)

	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("fill", fill)

## Baut einen Material-/Hinweis-Tooltip im Charm-Look aus einem "Name\nWirkung"-
## String: dunkles Casino-Panel, Name in Gold, Wirkung in Creme darunter. Geteilt
## von den 3D-Würfelseiten (RotatableDieView) und den Seiten-Chips der Gravur-
## Station (DieInspectorView). Die Schriftgrößen und die Textbreite sind Parameter,
## damit derselbe Look auf der niedrig aufgelösten 2D-UI wie auf dem hoch
## aufgelösten Tisch-Display passt. Leerer String -> null (kein Tooltip).
static func build_material_tooltip(for_text: String, title_size: int = 20, body_size: int = 15, body_width: float = 280.0) -> Control:
	if for_text == "":
		return null
	var panel := PanelContainer.new()
	style_panel(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var parts := for_text.split("\n", false, 1)  # 1× trennen: [Name, Wirkung]
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

## Dunkles Casino-Panel mit dickem Goldrahmen und Schatten - für Shop,
## Game-Over, Kombinationen-Übersicht usw.
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
