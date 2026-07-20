class_name SideBetPanel
extends Panel
## Tisch-Fenster rechts vom Würfelbecher: platziert die Nebenwetten VOR dem
## ersten Wurf einer Runde (Wett-Modus mit Setzen-Knöpfen, über die
## Maus-Weiterleitung bedient) und zeigt danach den Live-Fortschritt
## (Fortschritts-Modus). Platzieren mutiert den Zustand über GameRun.

## Nach dem Platzieren einer Wette - scene_root aktualisiert ggf. die Anzeige.
signal changed
## VOR der Einsatz-Zahlung (scene_root unterdrückt das generische Geld-Licht und
## merkt sich die Knopfmitte) bzw. DANACH (scene_root startet das Einsatz-Licht).
signal bet_selected(index: int)
signal bet_placed(index: int)

enum Mode { BETTING, PROGRESS }

## Anzahl Wett-Angebote je Runde.
const OFFER_COUNT := 3

const TITLE_COLOR := Color("#ff79c6")
const TEXT_COLOR := Color(1.35, 1.35, 1.3)  # überhelles Weiß (Glow)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GREEN := Color("#50fa7b")
const RED := Color("#ff5555")
const GOLD := Color("#ffd319")
const ENGRAVING_GLOW := Color("#c77dff")  # Gravur-Licht (violett)
const BAR_BG := Color("#100e20")

var run: GameRun
var mode: int = Mode.PROGRESS

## Wett-Auslage dieser Runde (nur im BETTING-Modus).
var offers: Array[SideBet] = []
var placed: Array[bool] = []
var bet_buttons: Array[Button] = []
## Platzierte Wetten, deren Einsatz-Licht angekommen ist: index -> Glühfarbe.
## Getrennt von placed, damit der Knopf erst bei ANKUNFT golden leuchtet (und
## nach jedem _rebuild wieder). Von scene_root über glow_bet gesetzt.
var bet_glow: Dictionary = {}

var _result: Dictionary = {}
var _content: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # die Setzen-Knöpfe fangen selbst
	clip_contents = true  # nichts ragt über den Neon-Rahmen hinaus
	add_theme_stylebox_override("panel", TableScreen.window_style())

# --- Modus-Umschaltung (scene_root) --------------------------------------------

## Öffnet den Wett-Modus mit frischer Auslage (vor dem ersten Wurf).
func open_betting(new_offers: Array[SideBet]) -> void:
	mode = Mode.BETTING
	offers = new_offers
	placed.resize(offers.size())
	placed.fill(false)
	bet_glow.clear()
	_rebuild()

## Schließt den Wett-Modus (erster Wurf) - ab jetzt nur noch Fortschritt.
func close_betting() -> void:
	mode = Mode.PROGRESS
	_rebuild()

## Aktualisiert den Live-Fortschritt (nur im Fortschritts-Modus wirksam).
func update_progress(result: Dictionary) -> void:
	_result = result
	if mode == Mode.PROGRESS:
		_rebuild()

# --- Aufbau --------------------------------------------------------------------

func _rebuild() -> void:
	var u := maxf(size.x, 200.0) / 100.0
	if _content != null and is_instance_valid(_content):
		_content.queue_free()
	bet_buttons.clear()
	_content = VBoxContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = u * 3.0
	_content.offset_right = -u * 3.0
	_content.offset_top = u * 2.2
	_content.offset_bottom = -u * 2.2
	_content.add_theme_constant_override("separation", int(u * 1.6))
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_content.add_child(_label("NEBENWETTEN", u * 5.2, TITLE_COLOR))
	if mode == Mode.BETTING:
		_build_betting(u)
	else:
		_build_progress(u)

## Wett-Modus: je Angebot eine kompakte Zeile mit Setzen-Knopf.
func _build_betting(u: float) -> void:
	_content.add_child(_label("Vor dem ersten Wurf setzen:", u * 2.5, MUTED_COLOR))
	for i in offers.size():
		_content.add_child(_offer_row(offers[i], i, u))

func _offer_row(bet: SideBet, index: int, u: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u * 1.2))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", int(u * 0.2))
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(_label(bet.display_name, u * 3.4, TEXT_COLOR))
	var desc := _label(bet.description, u * 2.4, MUTED_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(desc)
	row.add_child(text)

	var button := _setzen_button(bet, index, u)
	row.add_child(button)
	bet_buttons.append(button)
	return row

## Setzen-Knopf zeigt Einsatz UND Gewinn (kompakt: "$6 → 2×" / "1 Gravur → $16").
func _setzen_button(bet: SideBet, index: int, u: float) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(u * 24.0, u * 6.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", maxi(8, int(u * 2.6)))
	var enabled := not placed[index] and run != null and run.can_place_side_bet(bet)
	if placed[index]:
		button.text = "platziert"
		button.disabled = true
	else:
		button.text = "%s → %s" % [bet.stake_label(), bet.reward_label()]
		button.disabled = not enabled
		button.pressed.connect(_on_bet_pressed.bind(index))
	# Bar-Gewinn goldgelb, Gravur-Gewinn grün - die Farbe verrät die Wett-Sorte.
	var accent := GOLD if bet.payout_kind == SideBet.Payout.MONEY else GREEN
	_style_button(button, accent if enabled else MUTED_COLOR)
	# Angekommener Einsatz: den platzierten Knopf golden/violett glühen lassen.
	if placed[index] and bet_glow.has(index):
		_apply_stake_glow(button, bet_glow[index], false)
	return button

## Legt einen glühenden Einsatz-Rahmen auf den (platzierten) Knopf. animate =
## Ankunft (Rahmen fährt hell hoch + kurzer Pop), sonst sofort (Neuaufbau).
func _apply_stake_glow(button: Button, color: Color, animate: bool) -> void:
	var box := _button_box(Color(color.r * 0.28, color.g * 0.28, color.b * 0.28, 0.85), color)
	button.add_theme_stylebox_override("disabled", box)
	button.add_theme_color_override("font_disabled_color", color)
	if not animate:
		return
	box.border_color = Color(color, 0.0)
	var tween := create_tween()
	tween.tween_property(box, "border_color", color, 0.35).set_trans(Tween.TRANS_SINE)
	button.pivot_offset = button.size / 2.0
	button.scale = Vector2.ONE * 1.12
	var pop := create_tween()
	pop.tween_property(button, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_bet_pressed(index: int) -> void:
	if mode != Mode.BETTING or placed[index] or run == null:
		return
	if not run.can_place_side_bet(offers[index]):
		return
	bet_selected.emit(index)  # scene_root: Geld-Licht unterdrücken, Knopfmitte merken
	run.place_side_bet(offers[index])
	placed[index] = true
	_rebuild()
	bet_placed.emit(index)  # scene_root: Einsatz-Licht starten
	changed.emit()

## Bildschirm-Mitte des Setzen-Knopfs (SubViewport-Pixel) - Ziel des
## Diffusions-Lichts. (-1,-1), falls der Knopf (noch) nicht existiert.
func bet_button_center(index: int) -> Vector2:
	if index < 0 or index >= bet_buttons.size() or not is_instance_valid(bet_buttons[index]):
		return Vector2(-1, -1)
	var button := bet_buttons[index]
	if button.size.x < 1.0 or button.size.y < 1.0:
		return Vector2(-1, -1)  # noch nicht ausgelegt (erster Frame) - kein Diffusions-Ziel
	return button.global_position + button.size / 2.0

## Der Einsatz ist "angekommen": der Setzen-Knopf glüht ab jetzt in color (bleibt
## über _rebuild erhalten, solange die Wette platziert ist).
func glow_bet(index: int, color: Color) -> void:
	bet_glow[index] = color
	if index >= 0 and index < bet_buttons.size() and is_instance_valid(bet_buttons[index]):
		_apply_stake_glow(bet_buttons[index], color, true)

## Fortschritts-Modus: je aktiver Wette eine Zeile mit Balken.
func _build_progress(u: float) -> void:
	var bets: Array[SideBet] = run.active_side_bets if run != null else [] as Array[SideBet]
	if bets.is_empty():
		_content.add_child(_label("Keine Wetten aktiv.", u * 3.5, MUTED_COLOR))
		return
	for bet in bets:
		_content.add_child(_progress_row(bet, u))

func _progress_row(bet: SideBet, u: float) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(u * 1.2))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var state := bet.live_state(_result)
	var color := GREEN if state == SideBet.Live.ON_TRACK \
		else (RED if state == SideBet.Live.FAILED else MUTED_COLOR)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _label(bet.display_name, u * 4.2, TEXT_COLOR)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	header.add_child(_label(bet.status_label(_result), u * 3.8, color))
	box.add_child(header)

	box.add_child(_bar(bet.progress_fraction(_result), color, u))
	return box

## Fortschrittsbalken: dunkle Wanne mit farbiger Füllung (Anteil per Anker).
func _bar(fraction: float, color: Color, u: float) -> Control:
	var track := Panel.new()
	track.custom_minimum_size = Vector2(0, u * 2.2)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = BAR_BG
	bg.set_corner_radius_all(int(u * 0.9))
	track.add_theme_stylebox_override("panel", bg)

	var fill := ColorRect.new()
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_right = clampf(fraction, 0.0, 1.0)
	fill.anchor_bottom = 1.0
	var inset := u * 0.35
	fill.offset_left = inset
	fill.offset_top = inset
	fill.offset_right = -inset
	fill.offset_bottom = -inset
	track.add_child(fill)
	return track

# --- Bausteine -----------------------------------------------------------------

func _label(text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_disabled_color", Color(MUTED_COLOR.r, MUTED_COLOR.g, MUTED_COLOR.b, 0.5))
	button.add_theme_stylebox_override("normal", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("hover", _button_box(Color("#2c2757dd"), GOLD))
	button.add_theme_stylebox_override("pressed", _button_box(Color("#3a2f66"), GOLD))
	button.add_theme_stylebox_override("disabled", _button_box(Color("#1a183666"), Color(accent.r, accent.g, accent.b, 0.25)))

func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var u := maxf(size.x, 200.0) / 100.0
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.2)))
	box.set_corner_radius_all(int(u * 0.8))
	box.set_content_margin_all(int(u * 0.6))
	return box
