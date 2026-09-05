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
## Energie (⚡): überhelles Cyan - Börse am Hub, Preise im Schwarzmarkt und die
## Ladungs-Kometen der Auszahlung teilen sich diese eine Signalfarbe.
const ENERGY := Color(0.55, 1.9, 2.1)
## Vertragsstufen (DealClause.Tier): Standard, Risiko, Knebel, Werbegeschenk,
## Stresstest - die Akzentfarbe der Karte steigt mit der Gefahr.
const CONTRACT_TIER_COLORS := [
	Color("6fd3ff"), Color("c48cff"), Color("ff5f6d"), Color("ffcc00"), Color("ff3b3b"),
]

static func contract_tier_color(tier: int) -> Color:
	return CONTRACT_TIER_COLORS[clampi(tier, 0, CONTRACT_TIER_COLORS.size() - 1)]

## Verweis-Blau des Lexikons: klar getrennt von GOLD (Geld) und ENERGY (⚡).
## LDR mit Absicht - BBCode-Hex kennt kein HDR (siehe Lexikon.linkify).
const LEXIKON_LINK := Color("7ec8ff")

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

## Der EINE gefüllte Knopf einer Seite: die primäre Aktion steht auf sattem
## Akzent-Grund mit dunkler Schrift, alles andere bleibt Umriss. u = Breiten-
## einheit der Seite, damit Saum und Radius zur Neon-Grammatik der Displays passen.
static func style_primary_button(button: Button, accent: Color, u: float) -> void:
	button.add_theme_stylebox_override("normal", _filled_box(accent, accent.lightened(0.35), u))
	button.add_theme_stylebox_override("hover", _filled_box(accent.lightened(0.18), CREAM, u))
	button.add_theme_stylebox_override("pressed", _filled_box(accent.darkened(0.22), accent, u))
	button.add_theme_stylebox_override("focus", _filled_box(accent, accent.lightened(0.35), u))
	button.add_theme_stylebox_override("disabled", _filled_box(DISABLED_FILL, DISABLED_BORDER, u))
	# Dunkle Schrift auf hellem Grund - die Umkehr ist der ganze Rangunterschied.
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_constant_override("outline_size", 0)

static func _filled_box(fill: Color, border: Color, u: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.22)))
	box.set_corner_radius_all(int(u * 0.9))
	box.set_content_margin_all(int(u * 0.8))
	box.shadow_color = Color(fill.r, fill.g, fill.b, 0.3)
	box.shadow_size = maxi(1, int(u * 0.8))
	return box

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

## Dasselbe für einen RichTextLabel - überall dort, wo Schlüsselwörter im Text
## Lexikon-Verweise tragen (Laden-Tooltip, Serien-Schirm).
static func style_rich_body(label: RichTextLabel, size: int = 15, color: Color = CREAM) -> void:
	label.add_theme_font_size_override("normal_font_size", size)
	label.add_theme_color_override("default_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 2)

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
