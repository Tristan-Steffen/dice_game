class_name HubView
extends Control
## Der HUB auf dem Tisch-Display: reservierter Abschnitt unter der Grube mit
## der Lauf-Übersicht als HOME-SEITE und beliebig vielen angehängten SEITEN
## (Shop, Gravur-Station - siehe attach_panel). Der Hub ist der EINZIGE
## Verwalter seiner Fläche: zu jeder Zeit genau eine Seite ODER Home, nie
## mehreres; verdrängte Seiten kehren beim Schließen der verdrängenden zurück.
## Alle Maße leiten sich aus der eigenen Größe ab (Einheit u = Breite/100).

## Einstellungen-Knopf gedrückt (Menü klappt auf/zu).
signal settings_pressed
## Einträge des Einstellungs-Menüs; scene_root verbindet die Aktionen.
signal new_game_requested
signal debug_win_round_requested
signal debug_money_requested
signal library_requested
signal test_materials_requested
## Aufstieg-Knopf am Hub gedrückt (scene_root bucht den Ausbau über GameRun).
signal hub_upgrade_requested

## Farben im Stil des Displays (80s Neon).
const FRAME_COLOR := Color("#8be9fd")
const FRAME_BG := Color("#1a1836aa")
const TITLE_COLOR := Color("#ff79c6")
const TEXT_COLOR := Color(1.35, 1.35, 1.3)  # überhelles Weiß (Glow)
const GOLD_COLOR := Color("#ffd319")

## Signaturfarbe je Hub-Stufe (1..10): der ganze Hub wechselt Rahmen-, Hintergrund-
## und Lizenz-Farbe, damit die Ausbaustufe schon aus der Ferne ablesbar ist. Kühl
## (Hinterzimmer) über warm bis zur überhellen High-Roller-Krone (blüht).
const HUB_TIER_COLORS := [
	Color("#6478a8"),  # 1 Hinterzimmer - Schiefer
	Color("#8be9fd"),  # 2 Spielecke - Cyan
	Color("#2dd4bf"),  # 3 Lizenz - Türkis
	Color("#50fa7b"),  # 4 Parkett - Grün
	Color("#b6f24a"),  # 5 Salon - Limette
	Color("#ffd319"),  # 6 VIP-Lounge - Gold
	Color("#ff9e3d"),  # 7 Suite - Bernstein
	Color("#ff79c6"),  # 8 Penthouse - Rosa
	Color("#b06bff"),  # 9 Privatclub - Violett
	Color("#ffe6a0"),  # 10 High Roller - Weißgold (wird überhell)
]

var round_label: Label
var money_label: Label
## Rundenbonus-Zeilen - leuchten beim Auszählen des Rundenendes golden auf.
var blind_payout_label: Label
var die_payout_label: Label
## Lizenz-Zeile + nächste Freischaltung als Plan + Aufstieg-Knopf.
var hub_level_label: Label
var hub_next_label: Label
var upgrade_button: Button
var _hub_level := 1

var info_page: VBoxContainer

## Einstellungen-Knopf unten rechts auf der Home-Seite (blendet mit ihr aus).
var settings_button: Button
## Aufklappbares Menü auf dem Display; öffnet nach OBEN über dem Knopf.
var settings_menu: PanelContainer
var _test_materials_button: Button
var _menu_u := 1.0  # Breiteneinheit, für die Neupositionierung gemerkt

## Der Home-Inhalt - sichtbar nur, solange keine Seite offen ist.
var content_root: MarginContainer

var _pages: Array[Control] = []
var _suppressed: Array[Control] = []  # verdrängte Seiten (LIFO), kehren zurück
var _page_shown: Dictionary = {}  # Control -> zuletzt bekanntes visible (entprellt)
var _switching := false  # wahr, während der Hub selbst Sichtbarkeiten umschaltet

var _built := false

var _frame_style: StyleBoxFlat
var _frame_tween: Tween
## Rahmen-Grundzustand je Hub-Stufe: flash_frame/Gold-Ladung kehren HIERHIN zurück
## (nicht zum Stufe-1-Neon), damit der Ausbau am Rahmen sichtbar bleibt.
var _frame_base_color := FRAME_COLOR
var _frame_bg := FRAME_BG
var _frame_base_width_u := 0.3

## Baut den Inhalt passend zur (von TableScreen.place_hub gesetzten) Größe -
## einmalig, direkt nach dem Platzieren.
func layout() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # der Rahmen selbst schluckt nichts
	var u := size.x / 100.0

	var frame := Panel.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = FRAME_BG
	style.border_color = FRAME_COLOR
	style.set_border_width_all(maxi(2, int(u * 0.3)))
	style.set_corner_radius_all(int(u * 1.6))
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)
	_frame_style = style

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(u * 5.0))
	margin.add_theme_constant_override("margin_right", int(u * 5.0))
	margin.add_theme_constant_override("margin_top", int(u * 3.5))
	margin.add_theme_constant_override("margin_bottom", int(u * 3.5))
	add_child(margin)
	content_root = margin

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", int(u * 2.2))
	margin.add_child(column)

	# Kopfzeile: Runde links, Geld rechts.
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", int(u * 2.0))
	column.add_child(header)
	round_label = Label.new()
	round_label.name = "RoundLabel"
	round_label.text = "Runde 1"
	round_label.add_theme_font_size_override("font_size", int(u * 6.0))
	round_label.modulate = TEXT_COLOR
	round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	round_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(round_label)
	money_label = Label.new()
	money_label.name = "MoneyLabel"
	money_label.text = "$0"
	money_label.add_theme_font_size_override("font_size", int(u * 6.0))
	money_label.modulate = GOLD_COLOR
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(money_label)

	# Lauf-Übersicht: Rundenbonus-Zeilen.
	info_page = VBoxContainer.new()
	info_page.name = "InfoPage"
	info_page.add_theme_constant_override("separation", int(u * 1.6))
	info_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(info_page)

	_make_line(info_page, "Rundenbonus", u * 4.4, TITLE_COLOR)
	blind_payout_label = _make_line(info_page, "5$ pro Blind", u * 4.4, TEXT_COLOR)
	die_payout_label = _make_line(info_page, "1$ pro Würfel übrig", u * 4.4, TEXT_COLOR)
	# Lizenz-Zeile: aktuelle Hub-Stufe (golden, wie eine Casino-Lizenz) + der
	# nächste Ausbau als Plan-Zeile darunter (cyan, dezenter).
	hub_level_label = _make_line(info_page, "Hub: Hinterzimmer", u * 4.4, GOLD_COLOR)
	hub_next_label = _make_line(info_page, "", u * 3.2, FRAME_COLOR)

	# Fußzeile: Aufstieg-Knopf unten links, Platzhalter drückt Einstellungen rechts.
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", int(u * 2.0))
	column.add_child(footer)
	upgrade_button = Button.new()
	upgrade_button.name = "UpgradeButton"
	upgrade_button.text = "⬆ Ausbau"
	upgrade_button.focus_mode = Control.FOCUS_NONE
	upgrade_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	CasinoStyle.style_button(upgrade_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, int(u * 3.2))
	upgrade_button.pressed.connect(func() -> void: hub_upgrade_requested.emit())
	footer.add_child(upgrade_button)
	footer.add_child(_make_h_spacer())
	settings_button = Button.new()
	settings_button.name = "SettingsButton"
	settings_button.text = "⚙  Einstellungen"
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	CasinoStyle.style_button(settings_button, CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, int(u * 3.4))
	settings_button.pressed.connect(_toggle_settings_menu)
	footer.add_child(settings_button)

	_menu_u = u
	_build_settings_menu(u)

## Baut das Einstellungs-Menü (Kind der Hub-Fläche, anfangs verborgen);
## positioniert wird es erst beim Öffnen.
func _build_settings_menu(u: float) -> void:
	settings_menu = PanelContainer.new()
	settings_menu.name = "SettingsMenu"
	settings_menu.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1a1836")  # wie FRAME_BG, aber deckend (Dropdown)
	style.border_color = FRAME_COLOR
	style.set_border_width_all(maxi(2, int(u * 0.3)))
	style.set_corner_radius_all(int(u * 1.2))
	style.set_content_margin_all(int(u * 1.6))
	settings_menu.add_theme_stylebox_override("panel", style)
	add_child(settings_menu)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", int(u * 1.4))
	settings_menu.add_child(box)

	_make_menu_button(box, "📖  Charm-Bibliothek", CasinoStyle.GREEN, CasinoStyle.GREEN_DARK,
		u, library_requested.emit)
	_make_menu_button(box, "Neues Spiel", CasinoStyle.RED, CasinoStyle.RED_DARK,
		u, new_game_requested.emit)
	_make_menu_button(box, "Debug: Runde gewinnen", CasinoStyle.BLUE, CasinoStyle.BLUE_DARK,
		u, debug_win_round_requested.emit)
	# Bleibt offen für schnelles Mehrfach-Klicken (+$100 je Klick).
	_make_menu_button(box, "Debug: +100$", CasinoStyle.GREEN, CasinoStyle.GREEN_DARK,
		u, debug_money_requested.emit, true)
	_test_materials_button = _make_menu_button(box, "🧪 Testmaterialien: aus",
		CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, u, test_materials_requested.emit)

## keep_open = true lässt das Menü nach dem Klick offen (für Mehrfach-Klick-Debug).
func _make_menu_button(parent: Control, text: String, accent: Color, dark: Color,
		u: float, on_pressed: Callable, keep_open := false) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(u * 34.0, u * 6.0)
	CasinoStyle.style_button(button, accent, dark, int(u * 3.0))
	button.pressed.connect(func() -> void:
		on_pressed.call()
		if not keep_open:
			settings_menu.visible = false)
	parent.add_child(button)
	return button

## Beschriftung des Testmaterialien-Eintrags (AN/aus).
func set_test_materials_label(text: String) -> void:
	if _test_materials_button != null:
		_test_materials_button.text = text

func _toggle_settings_menu() -> void:
	settings_pressed.emit()
	if settings_menu == null:
		return
	settings_menu.visible = not settings_menu.visible
	if settings_menu.visible:
		_position_settings_menu()

## Rechtsbündig ÜBER dem Knopf (klappt nach oben, bleibt im Rahmen).
func _position_settings_menu() -> void:
	settings_menu.reset_size()
	var anchor := settings_button.get_global_rect()
	var top_left := Vector2(
		anchor.end.x - settings_menu.size.x,
		anchor.position.y - settings_menu.size.y - _menu_u * 1.2)
	settings_menu.position = top_left - global_position  # Viewport -> Hub-lokal

## Ob unter dem Display-Pixel ein sichtbarer, aktiver Knopf liegt - so
## unterscheidet scene_root Knopf-Klick von Hub-Zoom-Klick.
func interactive_at(point: Vector2) -> bool:
	return _interactive_under(self, point)

func _interactive_under(node: Node, point: Vector2) -> bool:
	for child in node.get_children():
		var control := child as Control
		if control != null:
			if not control.visible:
				continue
			if control is BaseButton and not (control as BaseButton).disabled \
					and control.mouse_filter != Control.MOUSE_FILTER_IGNORE \
					and control.get_global_rect().has_point(point):
				return true
		if _interactive_under(child, point):
			return true
	return false

## Lässt den Neon-Rahmen kurz in color aufleuchten und zur Grundfarbe abklingen
## (Geld-Lichtanimation: Gold bei Gutschriften, Chip-Farbe je Kauf-Puls).
func flash_frame(color: Color) -> void:
	if _frame_style == null:
		return
	if _frame_tween != null:
		_frame_tween.kill()
	# Füllung/Randbreite auf Grundwerte zurücksetzen - räumt eine etwaige
	# unterbrochene Gold-Ladung auf, sonst bliebe der Hub golden.
	_charge = 0.0
	_frame_style.bg_color = _frame_bg
	_frame_style.set_border_width_all(maxi(2, int(size.x / 100.0 * _frame_base_width_u)))
	_frame_style.border_color = color
	_frame_tween = create_tween()
	_frame_tween.tween_property(_frame_style, "border_color", _frame_base_color, 0.5) \
		.set_delay(0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Gold-Ladung des Hubs (Übertaktungs-Kauf): jeder ankommende Geld-Chip lädt
## das Panel eine Stufe weiter golden auf; beim Abschuss in die Leiste entlädt
## es sich RESTLOS (linear, ohne Nachglühen).
const PULSE_BORDER := Color(3.2, 2.5, 0.8)       # voll geladen (starker HDR-Bloom)
const PULSE_FILL := Color(0.82, 0.66, 0.18, 0.97)  # ganzes Panel kräftig golden

var _charge := 0.0  # 0..1 aktuelle Gold-Ladung

## Setzt die Ladung direkt (fraction 0..1) - ein Schritt je angekommenem Chip.
func charge_gold(fraction: float) -> void:
	if _frame_style == null:
		return
	if _frame_tween != null:
		_frame_tween.kill()
	_apply_charge(clampf(fraction, 0.0, 1.0))

## Restlose Entladung: die gesamte Ladung schießt in die Leiste, der Rahmen
## kehrt LINEAR über duration zum Grundzustand zurück - kein Nachglühen.
func discharge_gold(duration: float) -> void:
	if _frame_style == null or _charge <= 0.0:
		return
	if _frame_tween != null:
		_frame_tween.kill()
	_frame_tween = create_tween()
	_frame_tween.tween_method(_apply_charge, _charge, 0.0, duration)

func _apply_charge(value: float) -> void:
	_charge = value
	var u := size.x / 100.0
	_frame_style.border_color = _frame_base_color.lerp(PULSE_BORDER, value)
	_frame_style.bg_color = _frame_bg.lerp(PULSE_FILL, value)
	_frame_style.set_border_width_all(maxi(2, int(lerpf(u * _frame_base_width_u, u * 0.8, value))))

## Hängt ein Vollflächen-Panel als SEITE an: ab jetzt setzt der Hub die
## Eine-Seite-Regel durch; die Panels öffnen/schließen sich weiter selbst
## über ihr visible. Der Neon-Rahmen bleibt stehen und rahmt auch die Seite.
func attach_panel(panel: Control) -> void:
	add_child(panel)
	# set_anchors_AND_offsets: eine Standardgröße aus einer .tscn bliebe sonst
	# als Offset stehen.
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pages.append(panel)
	_page_shown[panel] = panel.visible
	panel.visibility_changed.connect(_on_page_visibility_changed.bind(panel))
	if panel.visible:
		_apply_page_opened(panel)

## Reagiert auf jede Sichtbarkeits-Änderung einer Seite und stellt die
## Eine-Seite-Regel wieder her. Entprellt über _page_shown (Baum-Signale
## ändern das eigene visible nicht); _switching verhindert Kaskaden.
func _on_page_visibility_changed(panel: Control) -> void:
	if _switching or not is_instance_valid(panel):
		return
	if _page_shown.get(panel, false) == panel.visible:
		return  # nur ein Baum-Signal
	_page_shown[panel] = panel.visible
	if panel.visible:
		_apply_page_opened(panel)
	else:
		_apply_page_closed(panel)

## Seite geöffnet: andere offene Seiten verdrängen, Home ausblenden.
func _apply_page_opened(panel: Control) -> void:
	_switching = true
	for other in _pages:
		if other != panel and is_instance_valid(other) and other.visible:
			other.visible = false
			_page_shown[other] = false
			_suppressed.append(other)
	_suppressed.erase(panel)  # falls sie selbst verdrängt war und nun zurück ist
	if content_root != null:
		content_root.visible = false
	if settings_menu != null:
		settings_menu.visible = false  # gehört zur Home-Seite, weicht mit ihr
	_switching = false

## Seite geschlossen: zuletzt verdrängte zurückholen, sonst Home zeigen.
## Ist eine ANDERE Seite offen, passiert nichts.
func _apply_page_closed(panel: Control) -> void:
	_suppressed.erase(panel)  # von außen geschlossen -> kehrt nicht mehr zurück
	if _any_page_visible():
		return
	var restore := _pop_suppressed()
	if restore != null:
		_switching = true
		restore.visible = true
		_page_shown[restore] = true
		_switching = false
		if content_root != null:
			content_root.visible = false
	elif content_root != null:
		content_root.visible = true

## Harter Reset (Spiel-Neustart): alle Seiten zu, Gedächtnis leer, Home sichtbar.
func reset_pages() -> void:
	_switching = true
	_suppressed.clear()
	for page in _pages:
		if is_instance_valid(page):
			page.visible = false
			_page_shown[page] = false
	if content_root != null:
		content_root.visible = true
	_switching = false

func _any_page_visible() -> bool:
	for page in _pages:
		if is_instance_valid(page) and page.visible:
			return true
	return false

func _pop_suppressed() -> Control:
	while not _suppressed.is_empty():
		var candidate: Control = _suppressed.pop_back()
		if is_instance_valid(candidate):
			return candidate
	return null

## Aktualisiert die Lauf-Übersicht (Runde + Geld; das Ziel zeigt der Zielbalken).
func set_run_info(round_number: int, money: int) -> void:
	if not _built:
		return
	round_label.text = "Runde %d" % round_number
	money_label.text = "$%d" % money

## Setzt die Hub-Ausbaustufe: Lizenz-Zeile, Aufstieg-Knopf (nächste Freischaltung
## als Plan) und die Rahmen-Stufe (dicker + eine Spur goldener je Stufe). next_name
## leer = Maximalstufe (Knopf verschwindet).
func set_hub_level(level: int, level_name: String, next_name: String, unlock: String, price: int) -> void:
	if not _built:
		return
	_hub_level = level
	hub_level_label.text = "Hub: %s  (Stufe %d)" % [level_name, level]
	if next_name == "":
		upgrade_button.visible = false
		hub_next_label.text = "voll ausgebaut"
	else:
		upgrade_button.visible = true
		upgrade_button.text = "⬆ Ausbau  (%d$)" % price
		hub_next_label.text = "→ %s: %s" % [next_name, unlock]
	_apply_frame_tier()

## Graut den Aufstieg-Knopf aus, wenn der Preis (noch) nicht bezahlbar ist.
func set_hub_upgrade_affordable(affordable: bool) -> void:
	if _built and upgrade_button != null and upgrade_button.visible:
		upgrade_button.disabled = not affordable

## Voller Re-Skin des Hubs aus der Stufe: Rahmenfarbe = Signaturfarbe der Stufe,
## Rahmen dicker, Hintergrund leicht in die Farbe getönt (Fern-Erkennung) und die
## Lizenz-Zeile in derselben Farbe. Höchststufe blüht überhell (Krone).
func _apply_frame_tier() -> void:
	if _frame_style == null:
		return
	var last := HUB_TIER_COLORS.size() - 1
	var tier: Color = HUB_TIER_COLORS[clampi(_hub_level - 1, 0, last)]
	if _hub_level > last:  # High Roller: überheller Rahmen (Bloom = Krone)
		tier = Color(tier.r * 1.7, tier.g * 1.6, tier.b * 1.25)
	_frame_base_color = tier
	var t := clampf(float(_hub_level - 1) / float(maxi(1, last)), 0.0, 1.0)
	_frame_base_width_u = 0.3 + t * 0.5
	# Panel-Hintergrund eine Spur in die Tier-Farbe (dezent, damit Text lesbar bleibt).
	_frame_bg = FRAME_BG.lerp(Color(tier.r, tier.g, tier.b, FRAME_BG.a), 0.16)
	if hub_level_label != null:
		hub_level_label.modulate = tier
	if _charge <= 0.0:  # nicht mitten in einer Gold-Ladung übermalen
		_frame_style.border_color = _frame_base_color
		_frame_style.bg_color = _frame_bg
		_frame_style.set_border_width_all(maxi(2, int((size.x / 100.0) * _frame_base_width_u)))

func _make_line(parent: Control, text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(font_size))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _make_h_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer
