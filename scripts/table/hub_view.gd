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
signal menu_requested
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

## Roulette-Rim: die Fahrplan-Stationen liegen auf einem Rad-Rand, die Lizenz-
## Plakette in der Nabe. roadmap_stage trägt alles frei-positioniert; roadmap_row
## sammelt die Stationen (Tests + Advance-Animation laufen dagegen).
var roadmap_stage: Control
var roadmap_row: Control  # loser Sammel-Node der Stationen (kein Layout-Container)
var rim_arc: RimArc
var current_ball: Panel
var medallion_label: Label
var _roadmap_goals: Array[int] = []
var _roadmap_current := 0  # Position des aktuellen Ziels im Block (0-basiert)
## Marker je Station: GameRun.STRESS_MARKER oder "" (siehe goal_roadmap_markers)
## - er färbt die Station und macht sie anfassbar.
var _roadmap_markers: Array[String] = []
## Hinweis-Karte einer markierten Station (Hover); Breite des Fließtexts in u.
const MARKER_HINT_WIDTH_U := 30.0
var marker_hint: PanelContainer
var marker_hint_title: Label
var marker_hint_body: Label
var _marker_hint_style: StyleBoxFlat
var _pips: Array[Panel] = []
## Radgeometrie (in layout() aus der Bühnengröße gesetzt; Tests lesen sie).
var _rim_center := Vector2.ZERO
var _rim_radius := 0.0
## Wieder-anwendbarer Stil für den Stufen-Re-Skin des Medaillons.
var _medallion_style: StyleBoxFlat
## Lizenz-Nabe (frei auf die Radmitte gesetzt) + die zwei Bonus-Chips.
var _medallion_cluster: VBoxContainer
var _chips: Array[Control] = []

var info_page: Control  # Alias auf roadmap_stage (Rückwärts-Bezug)

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

	# Roulette-Rad: eine freie Bühne trägt den Rad-Rand (Fahrplan-Stationen), die
	# Lizenz-Nabe in der Mitte und die Bonus-Chips seitlich. Kein Raster mehr - der
	# Filz selbst ist der Hintergrund. Hier oben treffen die Bank-Kometen ein.
	roadmap_stage = Control.new()
	roadmap_stage.name = "RimStage"
	roadmap_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roadmap_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roadmap_stage.clip_contents = false
	column.add_child(roadmap_stage)
	info_page = roadmap_stage
	roadmap_stage.resized.connect(_on_stage_resized)
	_build_rim_stage(u)

	# Fußzeile: nur der Einstellungen-Knopf (der Aufstieg wohnt jetzt in der Plakette).
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", int(u * 2.0))
	column.add_child(footer)
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

	_make_menu_button(box, "🏠  Menü", CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK,
		u, menu_requested.emit)
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

## Weiche Wechsel zwischen Seite und Home: der harte Schnitt fiel auf, solange
## die Kamera noch fährt (Titel-HUD). Aus- und Einblenden laufen nacheinander -
## die Seitenregel holt die nächste Fläche erst, wenn die alte weg ist.
const PAGE_FADE := 0.3

var _fade_tween: Tween

## Blendet eine offene Seite aus. Die nachrückende Fläche wartet danach dunkel:
## ohne on_hidden blendet sie sofort ein, MIT on_hidden übernimmt der Aufrufer
## das Einblenden (fade_current_in) und darf im dunklen Moment arbeiten - dort
## steckt der Spiel-Neustart, dessen Aufbau-Ruck sonst in einer Blende säße.
func fade_page_out(panel: Control, on_hidden := Callable()) -> void:
	if not is_instance_valid(panel) or not panel.visible:
		return
	_start_fade()
	_fade_tween.tween_property(panel, "modulate:a", 0.0, PAGE_FADE)
	_fade_tween.tween_callback(func() -> void:
		panel.visible = false
		panel.modulate.a = 1.0  # für das nächste Öffnen zurücksetzen
		_fade_tween = null      # diese Blende ist durch, kein Selbst-Abbruch
		var incoming := _visible_surface()
		if incoming != null:
			incoming.modulate.a = 0.0
		if on_hidden.is_valid():
			on_hidden.call()
		else:
			fade_current_in())

## Öffnet eine Seite mit Einblende (die alte Fläche weicht sofort).
func fade_page_in(panel: Control) -> void:
	if not is_instance_valid(panel):
		return
	panel.modulate.a = 0.0
	panel.visible = true
	_start_fade()
	_fade_tween.tween_property(panel, "modulate:a", 1.0, PAGE_FADE)

## Blendet ein, was gerade die Fläche hält (Home oder die zurückgekehrte Seite).
func fade_current_in() -> void:
	var surface := _visible_surface()
	if surface == null:
		return
	surface.modulate.a = 0.0
	_start_fade()
	_fade_tween.tween_property(surface, "modulate:a", 1.0, PAGE_FADE)

func _start_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()

func _visible_surface() -> Control:
	for page in _pages:
		if is_instance_valid(page) and page.visible:
			return page
	return content_root

## Harter Reset (Spiel-Neustart): alle Seiten zu, Gedächtnis leer, Home sichtbar.
func reset_pages() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_switching = true
	_suppressed.clear()
	for page in _pages:
		if is_instance_valid(page):
			page.visible = false
			page.modulate.a = 1.0  # eine unterbrochene Blende darf nicht kleben
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
## note: Zusatz der laufenden Runde - "Stresstest" oder der Ereignis-Name.
func set_run_info(round_number: int, money: int, note: String = "") -> void:
	if not _built:
		return
	round_label.text = ("Runde %d" % round_number) if note == "" \
		else "Runde %d · %s" % [round_number, note]
	money_label.text = "$%d" % money

## Setzt die Hub-Ausbaustufe: Lizenz-Zeile, Aufstieg-Knopf (nächste Freischaltung
## als Plan) und die Rahmen-Stufe (dicker + eine Spur goldener je Stufe). next_name
## leer = Maximalstufe (Knopf verschwindet).
func set_hub_level(level: int, level_name: String, next_name: String, unlock: String, price: int) -> void:
	if not _built:
		return
	_hub_level = level
	hub_level_label.text = level_name  # nur der Lizenzname; die Stufe trägt das Medaillon
	if medallion_label != null:
		medallion_label.text = str(level)
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
	_apply_tier_to_medallion(tier, last)

## Zieht die Stufenfarbe durch die Nabe: Medaillon, die gefüllten Pips (bis zur
## aktuellen Stufe, je in ihrer eigenen Farbe) und die aktuelle Rad-Station.
func _apply_tier_to_medallion(tier: Color, last: int) -> void:
	if _medallion_style != null:
		_medallion_style.border_color = tier
		_medallion_style.bg_color = FRAME_BG.lerp(Color(tier.r, tier.g, tier.b, 1.0), 0.18)
	if medallion_label != null:
		medallion_label.modulate = tier
	for i in _pips.size():
		var ps := _pips[i].get_theme_stylebox("panel") as StyleBoxFlat
		if ps == null:
			continue
		if i < _hub_level:
			var pc: Color = HUB_TIER_COLORS[clampi(i, 0, last)]
			ps.bg_color = Color(pc.r, pc.g, pc.b, 0.95)
		else:
			ps.bg_color = Color(1, 1, 1, 0.12)
	_layout_rim()  # Nabe neu zentrieren (Höhe ändert sich, z.B. Knopf weg bei Max)
	if not _roadmap_goals.is_empty():
		_rebuild_roadmap()

# --- Fahrplan + Lizenz-Plakette (Home-Bänder) --------------------------------

## Setzt den Fahrplan-BLOCK + die Position des aktuellen Ziels darin. Der Block
## bleibt stehen, bis sein letztes Ziel geschafft ist: geschaffte Stationen sind
## gefüllt, die aktuelle trägt die Kugel, kommende verblassen. Rückt die Position
## im selben Block vor, blitzt die eben geschaffte Station auf; ein frischer
## Block zündet alle Stationen im Lauf des Bogens.
func set_goal_roadmap(goals: Array[int], current: int = 0, markers: Array[String] = []) -> void:
	if not _built:
		return
	var same_block := goals == _roadmap_goals
	var cleared := same_block and current == _roadmap_current + 1
	var fresh_block := not same_block and not _roadmap_goals.is_empty()
	_roadmap_goals = goals.duplicate()
	_roadmap_markers = markers.duplicate()
	_roadmap_current = clampi(current, 0, maxi(0, goals.size() - 1))
	_rebuild_roadmap()
	if cleared:
		_play_station_cleared()
	elif fresh_block:
		_play_roadmap_advance()

## Setzt die Stationen auf den oberen Rad-Rand (180°→360°). Drei Zustände:
## geschafft (gefüllt in Stufenfarbe), aktuell (groß + Kugel), offen (verblasst
## mit dem Abstand zum aktuellen Ziel).
func _rebuild_roadmap() -> void:
	if roadmap_row == null:
		return
	_hide_marker_hint()  # die gehoverte Station wird gleich freigegeben
	for child in roadmap_row.get_children():
		# Sofort aushängen: queue_free allein ließe bei zwei Aufbauten im selben
		# Frame beide Generationen nebeneinander stehen.
		roadmap_row.remove_child(child)
		child.queue_free()
	current_ball = null
	if _roadmap_goals.is_empty() or _rim_radius <= 0.0:
		if rim_arc != null:
			rim_arc.set_rim(_rim_center, _rim_radius, PackedFloat32Array(), PackedFloat32Array(), FRAME_COLOR, 0.0)
		return
	var u := size.x / 100.0
	var n := _roadmap_goals.size()
	var angles := PackedFloat32Array()
	var alphas := PackedFloat32Array()
	for i in n:
		var ang := deg_to_rad(180.0 + i * (180.0 / float(maxi(1, n - 1))))
		angles.append(ang)
		if i < n - 1:
			# Rand-Segment am hellsten nahe der aktuellen Station.
			var seg_dist := absf(float(i) + 0.5 - float(_roadmap_current))
			alphas.append(clampf(0.5 - seg_dist * 0.09, 0.08, 0.5))
		var st := _make_station(_roadmap_goals[i], i, u, _frame_base_color)
		roadmap_row.add_child(st)
		st.reset_size()
		var st_center := _rim_center + Vector2(cos(ang), sin(ang)) * _rim_radius
		st.position = st_center - st.size * 0.5
		if i == _roadmap_current:  # Roulette-Kugel oben auf der aktuellen Station
			current_ball = _make_ball(u)
			st.add_child(current_ball)
			var bd := current_ball.custom_minimum_size
			current_ball.position = Vector2(st.size.x * 0.5 - bd.x * 0.5, -bd.y * 0.5)
	if rim_arc != null:
		rim_arc.set_rim(_rim_center, _rim_radius, angles, alphas, FRAME_COLOR, maxf(2.0, u * 0.18))

## Runde Ziel-Station: geschafft = satt in Stufenfarbe gefüllt (dunkle Zahl),
## aktuell = groß + Stufenfarbe + Glow, offen = dunkel und mit der Entfernung
## zum aktuellen Ziel verblassend (die Zukunft dimmt aus). Die Stresstest-
## Station trägt statt der Stufenfarbe durchgehend Warnrot; Ereignis-Stationen
## kündigen sich als farbiger Punkt unter der Scheibe an.
func _make_station(goal: int, index: int, u: float, tier: Color) -> Control:
	# Besonderheiten färben die STATION selbst - Stresstest warnrot, Ereignisse in
	# ihrer eigenen Farbe. Nur so ist der Block auf einen Blick lesbar; ein Punkt
	# unter der Scheibe verschwand aus der Übersichts-Distanz.
	var marker := _roadmap_markers[index] if index < _roadmap_markers.size() else ""
	var accent := _marker_color(marker)
	var marked := marker != ""
	if marked:
		tier = accent
	var current := index == _roadmap_current
	var done := index < _roadmap_current
	var dia := (u * 9.0) if current else ((u * 5.6) if done else (u * 6.2))
	var station := Panel.new()
	station.custom_minimum_size = Vector2(dia, dia)
	station.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	if current:
		# Dunkle Nabe: die helle Zahl bleibt lesbar, auch unter der überhellen
		# High-Roller-Krone. Die Stufenfarbe trägt der Ring + Glow, nicht die Füllung.
		box.bg_color = Color(0.10, 0.09, 0.22, 0.94)
		box.border_color = tier
		box.set_border_width_all(maxi(2, int(u * 0.4)))
		box.shadow_color = Color(tier.r, tier.g, tier.b, 0.35)
		box.shadow_size = int(u * 1.2)
	elif done:
		box.bg_color = Color(tier.r, tier.g, tier.b, 0.55)
		box.border_color = Color(tier.r, tier.g, tier.b, 0.85)
		box.set_border_width_all(maxi(1, int(u * 0.25)))
	else:
		# Kommende Besonderheit: getönte Füllung + satter Ring, damit sie sich von
		# den grauen Stationen abhebt, ohne wie "geschafft" zu wirken. Markierte
		# Stationen verblassen NICHT mit der Entfernung - der Stresstest steht
		# immer am Blockende, die Distanz-Blende hätte ihn zum blassesten Punkt
		# des Rades gemacht.
		var dist := index - _roadmap_current
		var fade := 1.0 if marked else clampf(1.0 - dist * 0.15, 0.32, 1.0)
		var frame := accent if marked else FRAME_COLOR
		box.bg_color = Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.9) if marked \
			else Color("#161033cc")
		box.border_color = Color(frame.r, frame.g, frame.b, (0.95 if marked else 0.5) * fade)
		box.set_border_width_all(maxi(1, int(u * (0.34 if marked else 0.22))))
	box.set_corner_radius_all(int(dia * 0.5))
	station.add_theme_stylebox_override("panel", box)

	if marked:
		_make_hoverable(station, marker)

	var label := Label.new()
	label.text = str(goal)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int((u * 2.9) if current else (u * 2.2)))
	if done:  # dunkle Zahl auf der gefüllten Scheibe
		label.modulate = Color(0.09, 0.08, 0.2)
	else:
		var lfade := 1.0 if current else clampf(1.0 - (index - _roadmap_current) * 0.13, 0.45, 1.0)
		label.modulate = Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, lfade)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	station.add_child(label)
	return station

## Farbe eines Fahrplan-Markers (heute nur der Stresstest - Deals stehen als
## Marken am Hub, nicht auf dem Fahrplan).
func _marker_color(marker: String) -> Color:
	return ComboChipView.THROTTLE_COLOR if marker == GameRun.STRESS_MARKER else FRAME_COLOR

## Name + Wirkung eines Markers als [Titel, Beschreibung] für den Hinweis.
func _marker_text(marker: String) -> PackedStringArray:
	if marker == GameRun.STRESS_MARKER:
		return PackedStringArray([GameRun.STRESS_NAME, GameRun.STRESS_HINT])
	return PackedStringArray(["", ""])

## Macht eine markierte Station anfassbar: Hover zeigt, was die Runde bringt.
## Nur markierte Stationen hören zu - graue Stationen bleiben tote Deko.
func _make_hoverable(station: Panel, marker: String) -> void:
	station.mouse_filter = Control.MOUSE_FILTER_PASS
	station.mouse_entered.connect(func() -> void: _show_marker_hint(station, marker))
	station.mouse_exited.connect(_hide_marker_hint)

## Überhelle "Roulette-Kugel" auf der aktuellen Station (blüht im HDR).
func _make_ball(u: float) -> Panel:
	var d := u * 2.4
	var ball := Panel.new()
	ball.custom_minimum_size = Vector2(d, d)
	ball.size = Vector2(d, d)
	ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1.7, 1.8, 1.9)
	box.set_corner_radius_all(int(d * 0.5))
	ball.add_theme_stylebox_override("panel", box)
	return ball

## Rundensieg IM Block: die eben geschaffte Station blitzt überhell auf, die
## Kugel springt sichtbar auf das neue Ziel.
func _play_station_cleared() -> void:
	var stations := roadmap_row.get_children()
	var done_index := _roadmap_current - 1
	if done_index >= 0 and done_index < stations.size():
		var st := stations[done_index] as Control
		if st != null:
			st.modulate = Color(2.2, 2.2, 2.0)
			var tw := create_tween()
			tw.tween_property(st, "modulate", Color.WHITE, 0.55) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if current_ball != null:
		current_ball.modulate = Color(1, 1, 1, 0)
		var btw := create_tween()
		btw.tween_interval(0.2)
		btw.tween_property(current_ball, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)

## Frischer Block: die Stationen zünden im Lauf des Bogens nacheinander auf.
func _play_roadmap_advance() -> void:
	var i := 0
	for child in roadmap_row.get_children():
		var c := child as Control
		if c == null:
			continue
		c.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
		i += 1

## Zeichnet den Rad-Rand: je zwei benachbarte Stationen ein Bogen-Segment, dessen
## Deckkraft mit der Entfernung von "jetzt" verblasst (native draw_arc, kein Node).
class RimArc:
	extends Control
	var center := Vector2.ZERO
	var radius := 0.0
	var angles := PackedFloat32Array()
	var seg_alpha := PackedFloat32Array()
	var base_color := Color("#8be9fd")
	var width := 3.0

	func set_rim(c: Vector2, r: float, angs: PackedFloat32Array, alphas: PackedFloat32Array, color: Color, w: float) -> void:
		center = c
		radius = r
		angles = angs
		seg_alpha = alphas
		base_color = color
		width = w
		queue_redraw()

	func _draw() -> void:
		for i in range(angles.size() - 1):
			var a: float = seg_alpha[i] if i < seg_alpha.size() else 0.3
			var col := Color(base_color.r, base_color.g, base_color.b, a)
			draw_arc(center, radius, angles[i], angles[i + 1], 32, col, width, true)

## Baut die Rad-Bühne: Rand-Zeichner (hinten), Stationen-Sammler, Lizenz-Nabe,
## Bonus-Chips. Positioniert wird erst, wenn die Bühne ihre Größe kennt (_on_stage_resized).
func _build_rim_stage(u: float) -> void:
	rim_arc = RimArc.new()
	rim_arc.set_anchors_preset(Control.PRESET_FULL_RECT)
	rim_arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roadmap_stage.add_child(rim_arc)

	roadmap_row = Control.new()
	roadmap_row.name = "RoadmapRow"
	roadmap_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	roadmap_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roadmap_stage.add_child(roadmap_row)

	_build_medallion_cluster(u)
	_build_bonus_chips(u)
	_build_marker_hint(u)  # zuletzt: der Hinweis liegt über Nabe und Stationen

## Hinweis-Karte der Fahrplan-Marker: Titel in Markerfarbe, darunter die
## Wirkung. Liegt als Overlay über der Nabe (darf sie verdecken, sie erscheint
## nur beim Hover) und wird beim Zeigen unter die Station gesetzt.
func _build_marker_hint(u: float) -> void:
	marker_hint = PanelContainer.new()
	marker_hint.name = "MarkerHint"
	marker_hint.visible = false
	marker_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker_hint_style = StyleBoxFlat.new()
	_marker_hint_style.bg_color = Color(0.06, 0.05, 0.14, 0.96)
	_marker_hint_style.set_border_width_all(maxi(1, int(u * 0.22)))
	_marker_hint_style.set_corner_radius_all(int(u * 1.2))
	_marker_hint_style.content_margin_left = u * 1.8
	_marker_hint_style.content_margin_right = u * 1.8
	_marker_hint_style.content_margin_top = u * 1.1
	_marker_hint_style.content_margin_bottom = u * 1.1
	marker_hint.add_theme_stylebox_override("panel", _marker_hint_style)
	roadmap_stage.add_child(marker_hint)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(u * 0.5))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_hint.add_child(column)

	marker_hint_title = Label.new()
	marker_hint_title.add_theme_font_size_override("font_size", int(u * 3.2))
	marker_hint_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(marker_hint_title)

	marker_hint_body = Label.new()
	marker_hint_body.add_theme_font_size_override("font_size", int(u * 2.5))
	marker_hint_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	marker_hint_body.custom_minimum_size.x = u * MARKER_HINT_WIDTH_U
	marker_hint_body.modulate = TEXT_COLOR
	marker_hint_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(marker_hint_body)

## Zeigt den Hinweis unter der Station - notfalls darüber, wenn unten die Bühne
## endet; waagerecht wird er in die Bühne geklemmt.
func _show_marker_hint(station: Control, marker: String) -> void:
	if marker_hint == null:
		return
	var text := _marker_text(marker)
	if text[0] == "":
		return
	var u := size.x / 100.0
	var accent := _marker_color(marker)
	marker_hint_title.text = text[0]
	marker_hint_title.modulate = accent
	marker_hint_body.text = text[1]
	_marker_hint_style.border_color = Color(accent.r, accent.g, accent.b, 0.85)
	marker_hint.visible = true
	marker_hint.reset_size()
	var box := marker_hint.size
	var anchor := station.position + station.size * 0.5
	var y := station.position.y + station.size.y + u * 1.2
	if y + box.y > roadmap_stage.size.y:
		y = station.position.y - u * 1.2 - box.y
	marker_hint.position = Vector2(
		clampf(anchor.x - box.x * 0.5, 0.0, maxf(0.0, roadmap_stage.size.x - box.x)),
		maxf(0.0, y))

func _hide_marker_hint() -> void:
	if marker_hint != null:
		marker_hint.visible = false

## Lizenz-Nabe: Medaillon (Stufe) + Lizenzname + 10 Pips + Plan-Zeile + Aufstieg.
## Frei auf die Radmitte gesetzt (_layout_rim); trägt die Signaturfarbe der Stufe.
func _build_medallion_cluster(u: float) -> void:
	_medallion_cluster = VBoxContainer.new()
	_medallion_cluster.alignment = BoxContainer.ALIGNMENT_CENTER
	_medallion_cluster.add_theme_constant_override("separation", int(u * 1.0))
	_medallion_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roadmap_stage.add_child(_medallion_cluster)

	var med_stage := CenterContainer.new()
	med_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medallion_cluster.add_child(med_stage)
	var medallion := Panel.new()
	medallion.custom_minimum_size = Vector2(u * 15.0, u * 15.0)
	medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medallion_style = StyleBoxFlat.new()
	_medallion_style.bg_color = FRAME_BG
	_medallion_style.border_color = GOLD_COLOR
	_medallion_style.set_border_width_all(maxi(2, int(u * 0.55)))
	_medallion_style.set_corner_radius_all(int(u * 7.5))
	medallion.add_theme_stylebox_override("panel", _medallion_style)
	med_stage.add_child(medallion)
	medallion_label = Label.new()
	medallion_label.text = "1"
	medallion_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	medallion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	medallion_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	medallion_label.add_theme_font_size_override("font_size", int(u * 7.5))
	medallion_label.modulate = GOLD_COLOR
	medallion_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medallion.add_child(medallion_label)

	# Lizenzname - behält den bisherigen Node (Payout/Tests referenzieren ihn).
	hub_level_label = Label.new()
	hub_level_label.text = "Hinterzimmer"
	hub_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hub_level_label.add_theme_font_size_override("font_size", int(u * 4.2))
	hub_level_label.modulate = GOLD_COLOR
	hub_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medallion_cluster.add_child(hub_level_label)

	# 10 Stufen-Pips (gefüllt bis zur aktuellen Stufe in _apply_tier_to_medallion).
	var pip_row := HBoxContainer.new()
	pip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pip_row.add_theme_constant_override("separation", int(u * 0.8))
	pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medallion_cluster.add_child(pip_row)
	_pips.clear()
	for i in HUB_TIER_COLORS.size():
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(u * 1.6, u * 1.6)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(1, 1, 1, 0.12)
		ps.set_corner_radius_all(int(u * 0.8))
		pip.add_theme_stylebox_override("panel", ps)
		pip_row.add_child(pip)
		_pips.append(pip)

	# Plan-Zeile: begrenzte Breite (bricht um), damit die Nabe schmal bleibt.
	hub_next_label = Label.new()
	hub_next_label.text = ""
	hub_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hub_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hub_next_label.custom_minimum_size = Vector2(u * 34.0, 0)
	hub_next_label.add_theme_font_size_override("font_size", int(u * 2.6))
	hub_next_label.modulate = FRAME_COLOR
	hub_next_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medallion_cluster.add_child(hub_next_label)

	upgrade_button = Button.new()
	upgrade_button.name = "UpgradeButton"
	upgrade_button.text = "⬆ Ausbau"
	upgrade_button.focus_mode = Control.FOCUS_NONE
	upgrade_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	upgrade_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	CasinoStyle.style_button(upgrade_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, int(u * 3.0))
	upgrade_button.pressed.connect(func() -> void: hub_upgrade_requested.emit())
	_medallion_cluster.add_child(upgrade_button)

## Zwei runde Bonus-Chips (Blind / Würfel) - die Auszahl-Labels leben darin und
## bleiben referenziert (scene_root lässt sie beim Zählen golden aufleuchten).
func _build_bonus_chips(u: float) -> void:
	_chips.clear()
	blind_payout_label = _make_bonus_chip(u, "je Benchmark", "5$")
	die_payout_label = _make_bonus_chip(u, "je Würfel", "1$")

func _make_bonus_chip(u: float, caption: String, value: String) -> Label:
	var d := u * 16.0
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(d, d)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#191540e6")
	box.border_color = Color(TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b, 0.7)
	box.set_border_width_all(maxi(2, int(u * 0.3)))
	box.set_corner_radius_all(int(d * 0.5))
	box.shadow_color = Color(TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b, 0.16)
	box.shadow_size = int(u * 0.8)
	chip.add_theme_stylebox_override("panel", box)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(u * 0.2))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(col)
	var cap := Label.new()
	cap.text = caption
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", int(u * 2.1))
	cap.modulate = Color(TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b, 0.9)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cap)
	var val := Label.new()
	val.text = value
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.custom_minimum_size = Vector2(d * 0.82, 0)
	val.add_theme_font_size_override("font_size", int(u * 3.4))
	val.modulate = TEXT_COLOR
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(val)

	roadmap_stage.add_child(chip)
	_chips.append(chip)
	return val

## Radgeometrie aus der Bühnengröße: Mitte etwas unter der geometrischen Mitte,
## Radius aus der kleineren Kante. false, solange die Bühne noch keine Größe hat.
func _compute_rim_geometry() -> bool:
	var s := roadmap_stage.size
	if s.x < 40.0 or s.y < 40.0:
		return false
	_rim_center = Vector2(s.x * 0.5, s.y * 0.56)
	_rim_radius = minf(s.x * 0.42, s.y * 0.5)
	return true

func _on_stage_resized() -> void:
	if not _compute_rim_geometry():
		return
	_layout_rim()
	_rebuild_roadmap()

## Positioniert Nabe + Chips relativ zur Radmitte (die Stationen macht _rebuild_roadmap).
func _layout_rim() -> void:
	if _rim_radius <= 0.0:
		return
	if _medallion_cluster != null:
		_medallion_cluster.reset_size()
		_medallion_cluster.position = _rim_center - _medallion_cluster.size * 0.5
	var offs := [Vector2(-0.62, 0.46), Vector2(0.62, 0.46)]
	for i in mini(_chips.size(), offs.size()):
		var chip: Control = _chips[i]
		chip.reset_size()
		var p := _rim_center + Vector2(offs[i].x, offs[i].y) * _rim_radius
		chip.position = p - chip.size * 0.5

func _make_h_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer
