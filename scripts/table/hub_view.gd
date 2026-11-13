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
signal debug_energy_requested
signal library_requested
signal test_materials_requested
signal test_engravings_requested
signal test_charges_requested

## Aufschrift der Testlieferung - scene_root beschriftet seinen Zwilling damit.
const TEST_PACKS_LABEL := "🧪 +20 Datenkarten je Sorte"
## Der Laden soll noch einmal aufmachen (Vorlauf der Runde, siehe scene_root).
signal shop_reopen_requested
## Das Lexikon soll aufschlagen (scene_root öffnet die Seite am Index).
signal lexikon_requested

## Farben im Stil des Displays (80s Neon).
const FRAME_COLOR := Color("#8be9fd")
const FRAME_BG := Color("#1a1836aa")
const TITLE_COLOR := Color("#ff79c6")
const TEXT_COLOR := Color(1.35, 1.35, 1.3)  # überhelles Weiß (Glow)
const GOLD_COLOR := Color("#ffd319")
const ENERGY_COLOR := CasinoStyle.ENERGY

## Signaturfarbe je Fortschrittsstufe (1..10): der ganze Hub wechselt Rahmen- und
## Hintergrund-Farbe, damit die Stufe schon aus der Ferne ablesbar ist. Kühl über
## warm bis zur überhellen Krone der letzten Stufe (blüht).
const TIER_COLORS := [
	Color("#6478a8"),  # 1 Schiefer
	Color("#8be9fd"),  # 2 Cyan
	Color("#2dd4bf"),  # 3 Türkis
	Color("#50fa7b"),  # 4 Grün
	Color("#b6f24a"),  # 5 Limette
	Color("#ffd319"),  # 6 Gold
	Color("#ff9e3d"),  # 7 Bernstein
	Color("#ff79c6"),  # 8 Rosa
	Color("#b06bff"),  # 9 Violett
	Color("#ffe6a0"),  # 10 Weißgold (wird überhell)
]

var round_label: Label
var money_label: Label
## Ladungs-Börse (⚡ N/Deckel). Steht ab Lauf-Beginn da - vor der Entdeckung des
## Schwarzmarkts bewusst unerklärt.
var energy_label: Label
var shop_button: Button
var lexikon_button: Button
var _tier := 1
var _tier_shown := 0  # 0 = noch nie angewandt

## Blind-Bühne: oben der laufende Blind groß, darunter die sechs Seiten des
## Block-Würfels (Seite 6 = Boss). roadmap_row sammelt die Seiten.
var roadmap_stage: Control
var roadmap_row: HBoxContainer
var blind_caption: Label
var blind_label: Label
var _blind_target := -1
var _blind_shown := 0
var _blind_tween: Tween
var _blind_growth_pct := 0
const BLIND_FONT_UNITS := 13.0
const FACE_UNITS := 7.2
const FACE_UNITS_CURRENT := 9.0
var _roadmap_goals: Array[int] = []
var _roadmap_current := 0  # Position der laufenden Runde im Block (0-basiert)
var _roadmap_block := -1   # Kennung des gezeigten Blocks (-1 = noch keiner)
## Marker je Seite: GameRun.STRESS_MARKER oder "" (siehe goal_roadmap_markers).
var _roadmap_markers: Array[String] = []
## Hinweis-Karte der Boss-Seite, der Deal-Marken und der Lauf-Anzeigen (Hover).
var marker_hint: HintCard

## Deal-Marken unter der Seiten-Reihe; dieselbe Reihe liegt am oberen Grubenrand.
var deal_token_row: DealTokenRow

var info_page: Control  # Alias auf roadmap_stage (Rückwärts-Bezug)

## Lauf-Anzeigen der Blind-Bühne: Nächster Blind, Glück, Fumbles (Schlüssel STAT_*).
const STAT_BLIND := "blind"
const STAT_LUCK := "luck"
const STAT_FUMBLES := "fumbles"
const STAT_TITLES := {STAT_BLIND: "Nächster Blind", STAT_LUCK: "Glück", STAT_FUMBLES: "Fumbles"}
const STAT_COLORS := {STAT_BLIND: Color("#ff5555"), STAT_LUCK: Color("#9dff6b"), STAT_FUMBLES: Color("#ff8c42")}
const STAT_TICK_TIME := 0.45
var stat_labels: Dictionary = {}  # Schlüssel -> Label
var _stat_values: Dictionary = {}  # Schlüssel -> zuletzt gezeigter Zielwert
var _stat_shown: Dictionary = {}  # Schlüssel -> gerade angezeigte (tickende) Zahl
var _stat_hints: Dictionary = {}  # Schlüssel -> Hinweis-Text
var _stat_tweens: Dictionary = {}

## Einstellungen-Knopf unten rechts auf der Home-Seite (blendet mit ihr aus).
var settings_button: Button
## Aufklappbares Menü auf dem Display; öffnet nach OBEN über dem Knopf.
var settings_menu: PanelContainer
var _test_materials_button: Button
var _test_engravings_button: Button
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
## Rahmen-Grundzustand je Fortschrittsstufe: flash_frame/Gold-Ladung kehren HIERHIN
## zurück (nicht zum Stufe-1-Neon), damit die Stufe am Rahmen sichtbar bleibt.
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
	energy_label = Label.new()
	energy_label.name = "EnergyLabel"
	energy_label.text = "⚡ 0/0"
	energy_label.add_theme_font_size_override("font_size", int(u * 5.0))
	energy_label.modulate = ENERGY_COLOR
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	energy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(energy_label)

	# Blind-Bühne: großer Blind, Block-Würfel, Lauf-Anzeigen und Deal-Marken.
	roadmap_stage = Control.new()
	roadmap_stage.name = "RimStage"
	roadmap_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roadmap_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roadmap_stage.clip_contents = false
	column.add_child(roadmap_stage)
	info_page = roadmap_stage
	roadmap_stage.resized.connect(_on_stage_resized)
	_build_rim_stage(u)

	# Fußzeile: nur der Einstellungen-Knopf.
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
	# Das Lexikon steht ganz links: es ist immer da, anders als der Laden.
	lexikon_button = Button.new()
	lexikon_button.name = "LexikonButton"
	lexikon_button.text = "📖  Lexikon"
	lexikon_button.focus_mode = Control.FOCUS_NONE
	lexikon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	CasinoStyle.style_button(lexikon_button, CasinoStyle.BLUE, CasinoStyle.BLUE_DARK, int(u * 3.4))
	lexikon_button.pressed.connect(func() -> void: lexikon_requested.emit())
	footer.add_child(lexikon_button)
	# Der Laden steht LINKS daneben: er kommt und geht, die Einstellungen bleiben.
	shop_button = Button.new()
	shop_button.name = "ShopButton"
	shop_button.text = "🛒  Laden"
	shop_button.focus_mode = Control.FOCUS_NONE
	shop_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	shop_button.visible = false  # nur im Vorlauf der Runde, bis der Vertrag steht
	CasinoStyle.style_button(shop_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, int(u * 3.4))
	shop_button.pressed.connect(func() -> void: shop_reopen_requested.emit())
	footer.add_child(shop_button)
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
	# Ebenso ein Nachschlag-Knopf; der Speicherdeckel bleibt in Kraft.
	_make_menu_button(box, "Debug: +10 ⚡", CasinoStyle.BLUE, CasinoStyle.BLUE_DARK,
		u, debug_energy_requested.emit, true)
	_test_materials_button = _make_menu_button(box, "🧪 Testmaterialien: aus",
		CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, u, test_materials_requested.emit)
	# Kein Schalter, eine Lieferung - und sie bleibt offen fürs Nachlegen.
	_test_engravings_button = _make_menu_button(box, TEST_PACKS_LABEL,
		CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, u, test_engravings_requested.emit, true)
	# Würfelt die Ladung aller Vorrats-Würfel neu - Nachschlag-Knopf.
	_make_menu_button(box, "🧪 Ladung würfeln", CasinoStyle.GOLD, CasinoStyle.GOLD_DARK,
		u, test_charges_requested.emit, true)

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
	return TableScreen.interactive_under(self, point)

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

## Gold-Ladung des Hubs (Rampenlicht-Lichtlauf): voll geladen entlädt sich das
## Panel beim Abschuss in die Leiste RESTLOS (linear, ohne Nachglühen).
const PULSE_BORDER := Color(3.2, 2.5, 0.8)       # voll geladen (starker HDR-Bloom)
const PULSE_FILL := Color(0.82, 0.66, 0.18, 0.97)  # ganzes Panel kräftig golden

var _charge := 0.0  # 0..1 aktuelle Gold-Ladung

## Setzt die Energie direkt (fraction 0..1) - ein Schritt je angekommenem Chip.
func charge_gold(fraction: float) -> void:
	if _frame_style == null:
		return
	if _frame_tween != null:
		_frame_tween.kill()
	_apply_charge(clampf(fraction, 0.0, 1.0))

## Restlose Entladung: die gesamte Energie schießt in die Leiste, der Rahmen
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
		restore.modulate.a = 1.0
		if content_root != null:
			content_root.visible = false
	elif content_root != null:
		content_root.visible = true
		# Zurückgeholte Fläche IMMER sichtbar schalten: fade_page_out dimmt die
		# nachrückende Fläche vorab auf 0 und verlässt sich darauf, dass jemand
		# sie einblendet. Übernimmt in diesem dunklen Moment eine ANDERE Seite
		# die Fläche, bliebe Home danach unsichtbar stehen. fade_page_out setzt
		# seine 0 danach erneut - die absichtliche Dunkelheit gewinnt weiterhin.
		content_root.modulate.a = 1.0

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

## Eine Seite ist WIRKLICH zu: sie kehrt nicht mehr zurück, auch wenn eine fremde
## Seite sie eben verdrängt hat. Nötig für eine Seite, die im verdrängten Zustand
## schließt (der abräumende Laden) - sonst holte die Seitenregel sie später als
## totes Standbild zurück.
func forget_page(panel: Control) -> void:
	_suppressed.erase(panel)

## Eine Seite will die Fläche: ist gerade eine ANDERE offen (Titel, Lexikon), stellt
## sie sich hinten an und kommt beim Schließen jener zurück, sonst blendet sie ein.
func queue_page(panel: Control) -> void:
	if not is_instance_valid(panel) or panel.visible:
		return
	if _any_page_visible():
		if not _suppressed.has(panel):
			_suppressed.append(panel)
		return
	fade_page_in(panel)

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

## Stand der Ladungs-Börse; scene_root treibt sie, der Hub kennt keinen GameRun.
func set_energy_display(energy: int, cap: int) -> void:
	if _built and energy_label != null:
		energy_label.text = "⚡ %d/%d" % [energy, cap]

## Kurzer Pop der Börse - eine Energie ist eben eingetroffen.
func pulse_energy() -> void:
	if not _built or energy_label == null:
		return
	energy_label.pivot_offset = energy_label.size / 2.0
	var tween := create_tween()
	tween.tween_property(energy_label, "scale", Vector2.ONE * 1.3, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(energy_label, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Setzt die Fortschrittsstufe: Rahmen-Stufe (dicker + eine Spur goldener je Stufe).
func set_progress_tier(tier: int) -> void:
	if not _built or tier == _tier_shown:
		return
	_tier = tier
	_tier_shown = tier
	_apply_frame_tier()

## Zeigt den Laden-Knopf. Er steht NUR im Vorlauf der Runde: nach dem Schließen
## des Ladens bis zur Unterschrift (bzw. bis zum ersten Wurf) - dasselbe Fenster,
## in dem auch die Werkbank offen ist.
func set_shop_reopen_visible(shown: bool) -> void:
	if _built and shop_button != null:
		shop_button.visible = shown

## Voller Re-Skin des Hubs aus der Stufe: Rahmenfarbe = Signaturfarbe der Stufe,
## Rahmen dicker, Hintergrund leicht in die Farbe getönt (Fern-Erkennung).
## Höchststufe blüht überhell (Krone).
func _apply_frame_tier() -> void:
	if _frame_style == null:
		return
	var last := TIER_COLORS.size() - 1
	var tier: Color = TIER_COLORS[clampi(_tier - 1, 0, last)]
	if _tier > last:  # letzte Stufe: überheller Rahmen (Bloom = Krone)
		tier = Color(tier.r * 1.7, tier.g * 1.6, tier.b * 1.25)
	_frame_base_color = tier
	var t := clampf(float(_tier - 1) / float(maxi(1, last)), 0.0, 1.0)
	_frame_base_width_u = 0.3 + t * 0.5
	# Panel-Hintergrund eine Spur in die Tier-Farbe (dezent, damit Text lesbar bleibt).
	_frame_bg = FRAME_BG.lerp(Color(tier.r, tier.g, tier.b, FRAME_BG.a), 0.16)
	if _charge <= 0.0:  # nicht mitten in einer Gold-Ladung übermalen
		_frame_style.border_color = _frame_base_color
		_frame_style.bg_color = _frame_bg
		_frame_style.set_border_width_all(maxi(2, int((size.x / 100.0) * _frame_base_width_u)))
	if not _roadmap_goals.is_empty():
		_rebuild_roadmap()

# --- Blind-Anzeige + Block-Würfel (Home-Bänder) -------------------------------

## Setzt den Block: Blinds je Runde (gespielt / laufend / projiziert), die Position
## der laufenden Runde und die Marker. Groß steht nur der LAUFENDE Blind; die
## Würfelseiten zeigen den Fortschritt, gespielte Seiten ihren gespielten Blind.
## block_id: laufender Block (GameRun.block_of_round) - er entscheidet, ob ein
## Block WEITERläuft; die Zahlen taugen dafür nicht, Verträge heben sie mitten im Block.
func set_goal_roadmap(goals: Array[int], current: int = 0, markers: Array[String] = [],
		block_id: int = -1) -> void:
	if not _built:
		return
	var same_block := (block_id == _roadmap_block) if block_id >= 0 else (goals == _roadmap_goals)
	var cleared := same_block and current == _roadmap_current + 1
	var fresh_block := not same_block and not _roadmap_goals.is_empty()
	_roadmap_block = block_id
	_roadmap_goals = goals.duplicate()
	_roadmap_markers = markers.duplicate()
	_roadmap_current = clampi(current, 0, maxi(0, goals.size() - 1))
	_rebuild_roadmap()
	_set_blind_value(current_blind())
	_write_stat(STAT_BLIND, int(_stat_shown.get(STAT_BLIND, 0)))
	if cleared:
		_play_station_cleared()
	elif fresh_block:
		_play_roadmap_advance()

## Der Blind der laufenden Runde (0 = noch kein Block gesetzt).
func current_blind() -> int:
	if _roadmap_goals.is_empty():
		return 0
	return _roadmap_goals[_roadmap_current]

## Baut die sechs Würfelseiten neu: Seite i+1 = Runde i des Blocks.
func _rebuild_roadmap() -> void:
	if roadmap_row == null:
		return
	_hide_marker_hint()  # die gehoverte Seite wird gleich freigegeben
	for child in roadmap_row.get_children():
		# Sofort aushängen: queue_free allein ließe bei zwei Aufbauten im selben
		# Frame beide Generationen nebeneinander stehen.
		roadmap_row.remove_child(child)
		child.queue_free()
	var u := size.x / 100.0
	for i in _roadmap_goals.size():
		roadmap_row.add_child(_make_station(i, u))
	_layout_stage()

## Eine Block-Seite samt Unterschrift: gespielt = gedimmt mit gespieltem Blind,
## laufend = hell und größer, offen = leer; die Boss-Seite warnrot und anfassbar.
func _make_station(index: int, u: float) -> Control:
	var marker := _roadmap_markers[index] if index < _roadmap_markers.size() else ""
	var boss := marker != ""
	var current := index == _roadmap_current
	var done := index < _roadmap_current
	var station := VBoxContainer.new()
	station.alignment = BoxContainer.ALIGNMENT_CENTER
	station.add_theme_constant_override("separation", int(u * 0.5))
	station.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := DieFace.new()
	face.name = "Face"
	face.value = index + 1
	var edge := u * (FACE_UNITS_CURRENT if current else FACE_UNITS)
	face.custom_minimum_size = Vector2(edge, edge)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var accent := _marker_color(marker) if boss else _frame_base_color
	face.ring = accent
	face.state = DieFace.CURRENT if current else (DieFace.DONE if done else DieFace.OPEN)
	face.boss = boss
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	station.add_child(face)
	if boss:
		_make_hoverable(face, marker)
	var caption := Label.new()
	caption.name = "Caption"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", int(u * 2.2))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if boss and not done:
		caption.text = "BOSS"
		caption.modulate = accent
	elif done:
		caption.text = str(_roadmap_goals[index])
		caption.modulate = Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, 0.45)
	else:
		caption.text = " "
	station.add_child(caption)
	return station

## Farbe eines Block-Markers (heute nur die Boss-Runde).
func _marker_color(marker: String) -> Color:
	return ComboChipView.THROTTLE_COLOR if marker == GameRun.STRESS_MARKER else FRAME_COLOR

## Name + Wirkung eines Markers als [Titel, Beschreibung] für den Hinweis.
func _marker_text(marker: String) -> PackedStringArray:
	if marker == GameRun.STRESS_MARKER:
		return PackedStringArray([GameRun.STRESS_NAME, GameRun.STRESS_HINT])
	return PackedStringArray(["", ""])

## Macht die Boss-Seite anfassbar: Hover zeigt, was die Runde bringt.
func _make_hoverable(face: Control, marker: String) -> void:
	face.mouse_filter = Control.MOUSE_FILTER_PASS
	face.mouse_entered.connect(func() -> void: _show_marker_hint(face, marker))
	face.mouse_exited.connect(_hide_marker_hint)

## Rundensieg im Block: die eben gespielte Seite blitzt auf.
func _play_station_cleared() -> void:
	var stations := roadmap_row.get_children()
	var done_index := _roadmap_current - 1
	if done_index >= 0 and done_index < stations.size():
		var st := stations[done_index] as Control
		if st != null:
			st.modulate = Color(2.2, 2.2, 2.0)
			var tw := create_tween()
			tw.tween_property(st, "modulate", Color.WHITE, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Frischer Block: die Seiten zünden von links nach rechts auf.
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

## Eine gezeichnete Würfelseite mit ihren Augen.
class DieFace:
	extends Control
	const OPEN := 0
	const DONE := 1
	const CURRENT := 2
	const PIPS := {
		1: [Vector2(0.5, 0.5)],
		2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
		3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
		4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
		5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
		6: [Vector2(0.27, 0.25), Vector2(0.73, 0.25), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.75), Vector2(0.73, 0.75)],
	}
	var value := 1
	var state := OPEN
	var boss := false
	var ring := Color("#8be9fd")

	func _draw() -> void:
		var s := size
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(int(s.x * 0.2))
		var pip := ring
		match state:
			CURRENT:
				box.bg_color = Color(0.10, 0.09, 0.22, 0.95)
				box.border_color = ring
				box.set_border_width_all(maxi(2, int(s.x * 0.06)))
				box.shadow_color = Color(ring.r, ring.g, ring.b, 0.45)
				box.shadow_size = int(s.x * 0.18)
				pip = Color(1.5, 1.5, 1.45)
			DONE:
				box.bg_color = Color(ring.r, ring.g, ring.b, 0.18)
				box.border_color = Color(ring.r, ring.g, ring.b, 0.35)
				box.set_border_width_all(maxi(1, int(s.x * 0.04)))
				pip = Color(ring.r, ring.g, ring.b, 0.45)
			_:
				box.bg_color = Color(ring.r * 0.3, ring.g * 0.3, ring.b * 0.3, 0.85) if boss else Color("#161033cc")
				box.border_color = Color(ring.r, ring.g, ring.b, 0.95 if boss else 0.4)
				box.set_border_width_all(maxi(1, int(s.x * (0.06 if boss else 0.035))))
				pip = Color(ring.r, ring.g, ring.b, 0.95 if boss else 0.5)
		draw_style_box(box, Rect2(Vector2.ZERO, s))
		var r := s.x * 0.085
		for p: Vector2 in PIPS.get(value, []):
			draw_circle(p * s, r, pip, true, -1.0, true)

## Baut die Bühne: Blind-Kopf (Titel, große Zahl, Nächster-Zeile), die Reihe der
## Block-Seiten zwischen Glück und Fumbles, darunter die Deal-Marken.
func _build_rim_stage(u: float) -> void:
	blind_caption = _stage_label("BLIND", u * 2.6, Color(FRAME_COLOR.r, FRAME_COLOR.g, FRAME_COLOR.b, 0.75))
	blind_label = _stage_label("0", u * BLIND_FONT_UNITS, TEXT_COLOR)
	roadmap_row = HBoxContainer.new()
	roadmap_row.name = "RoadmapRow"
	roadmap_row.alignment = BoxContainer.ALIGNMENT_CENTER
	roadmap_row.add_theme_constant_override("separation", int(u * 1.6))
	roadmap_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roadmap_stage.add_child(roadmap_row)
	_build_run_stats(u)
	_build_deal_tokens(u)
	_build_marker_hint(u)  # zuletzt: der Hinweis liegt über allem

func _stage_label(text: String, font_px: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(font_px))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roadmap_stage.add_child(label)
	return label

## Die große Zahl: ein geänderter Blind tickt hin und blitzt.
func _set_blind_value(target: int) -> void:
	if blind_label == null or target == _blind_target:
		return
	var first := _blind_target < 0
	_blind_target = target
	if _blind_tween != null and _blind_tween.is_valid():
		_blind_tween.kill()
	if first:
		_write_blind(target)
		return
	_blind_tween = create_tween()
	_blind_tween.tween_method(_write_blind, _blind_shown, target, STAT_TICK_TIME)
	blind_label.modulate = Color(2.2, 2.0, 1.6)
	var flash := create_tween()
	flash.tween_property(blind_label, "modulate", TEXT_COLOR, STAT_TICK_TIME + 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _write_blind(value: int) -> void:
	_blind_shown = value
	blind_label.text = str(value)

## Marken-Reihe unten mittig auf der Bühne (Position setzt _layout_stage).
func _build_deal_tokens(_u: float) -> void:
	deal_token_row = DealTokenRow.new()
	deal_token_row.name = "DealTokens"
	deal_token_row.token_hovered.connect(_show_hint)
	deal_token_row.token_left.connect(_hide_marker_hint)
	roadmap_stage.add_child(deal_token_row)

## Setzt die wirkenden Deal-Seiten (GameRun.active_deal_sides).
func set_deal_tokens(sides: Array[Dictionary]) -> void:
	if not _built or deal_token_row == null:
		return
	_hide_marker_hint()  # die gehoverte Marke wird gleich freigegeben
	deal_token_row.set_sides(sides, size.x / 100.0)
	_layout_stage()

## Abrechnung: die Marken wischen fort. Liefert die Dauer, damit der Aufrufer
## den Shop erst danach öffnet.
func sweep_deal_tokens() -> float:
	if deal_token_row == null:
		return 0.0
	_hide_marker_hint()
	return deal_token_row.sweep(size.y * 0.12)

## Hinweis-Karte für Boss-Seite, Deal-Marken und Lauf-Anzeigen.
func _build_marker_hint(u: float) -> void:
	marker_hint = HintCard.new(u)
	marker_hint.name = "MarkerHint"
	roadmap_stage.add_child(marker_hint)

func _show_marker_hint(anchor_control: Control, marker: String) -> void:
	var text := _marker_text(marker)
	_show_hint(anchor_control, text[0], text[1], _marker_color(marker))

func _show_hint(anchor_control: Control, title: String, body: String, accent: Color) -> void:
	if marker_hint == null:
		return
	var u := size.x / 100.0
	marker_hint.show_for(anchor_control, roadmap_stage, title, body, accent, u * 1.2)

func _hide_marker_hint() -> void:
	if marker_hint != null:
		marker_hint.hide_card()

## Die Lauf-Anzeigen: die Nächster-Zeile unter der großen Zahl, Glück und Fumbles
## als Zeile unter den Block-Seiten - je mit Hover-Hinweis.
func _build_run_stats(u: float) -> void:
	for key: String in [STAT_BLIND, STAT_LUCK, STAT_FUMBLES]:
		var label := Label.new()
		label.name = "Stat_" + key
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", int(u * 3.0))
		label.modulate = STAT_COLORS[key]
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.mouse_entered.connect(func() -> void: _show_hint(label, String(STAT_TITLES[key]),
			String(_stat_hints.get(key, "")), STAT_COLORS[key]))
		label.mouse_exited.connect(_hide_marker_hint)
		roadmap_stage.add_child(label)
		stat_labels[key] = label
		_stat_shown[key] = 0
		_write_stat(key, 0)

## Setzt die Lauf-Anzeigen samt Hinweisen; eine geänderte Zahl tickt hoch und blitzt.
## growth_pct: natürliches Wachstum der nächsten Runde in Prozent (GameRun.blind_growth).
func set_run_stats(next_blind: int, luck: int, fumbles: int, hints: Dictionary = {},
		growth_pct: int = 0) -> void:
	if not _built or stat_labels.is_empty():
		return
	if growth_pct != _blind_growth_pct:
		_blind_growth_pct = growth_pct
		_write_stat(STAT_BLIND, int(_stat_shown.get(STAT_BLIND, 0)))
	for key in hints:
		_stat_hints[key] = String(hints[key])
	var values := {STAT_BLIND: next_blind, STAT_LUCK: luck, STAT_FUMBLES: fumbles}
	for key: String in values:
		var target := int(values[key])
		if _stat_values.has(key) and int(_stat_values[key]) == target:
			continue
		var first := not _stat_values.has(key)
		_stat_values[key] = target
		if first:
			_write_stat(key, target)
		else:
			_tick_stat(key, target)
	_layout_stage()

func _write_stat(key: String, value: int) -> void:
	_stat_shown[key] = value
	var label := stat_labels.get(key) as Label
	if label == null:
		return
	if key == STAT_BLIND:
		label.text = "nächster %d" % value
		if _blind_growth_pct != 0:
			label.text += "  (%+d %%)" % _blind_growth_pct
	else:
		label.text = "%s %d" % [STAT_TITLES[key], value]

func _tick_stat(key: String, target: int) -> void:
	var label := stat_labels.get(key) as Label
	if label == null:
		return
	if _stat_tweens.has(key) and (_stat_tweens[key] as Tween).is_valid():
		(_stat_tweens[key] as Tween).kill()
	var tween := create_tween()
	_stat_tweens[key] = tween
	tween.tween_method(func(v: int) -> void: _write_stat(key, v), int(_stat_shown[key]), target, STAT_TICK_TIME)
	var base: Color = STAT_COLORS[key]
	label.modulate = Color(base.r * 2.2, base.g * 2.2, base.b * 2.2)
	var flash := create_tween()
	flash.tween_property(label, "modulate", base, STAT_TICK_TIME + 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_stage_resized() -> void:
	_layout_stage()

## Stellt alles auf der Bühne: Kopf oben mittig, Seiten-Reihe darunter, darunter
## Glück und Fumbles, die Deal-Marken am Boden.
func _layout_stage() -> void:
	var s := roadmap_stage.size
	if s.x < 40.0 or s.y < 40.0 or blind_label == null:
		return
	# Die große Zahl gibt nach, wenn die Bühne flach ist - die Seiten-Reihe nie.
	var hero := int(minf((size.x / 100.0) * BLIND_FONT_UNITS, s.y * 0.26))
	if blind_label.get_theme_font_size("font_size") != hero:
		blind_label.add_theme_font_size_override("font_size", hero)
	var head: Array[Label] = [blind_caption, blind_label, stat_labels.get(STAT_BLIND) as Label]
	var luck := stat_labels.get(STAT_LUCK) as Label
	var fumbles := stat_labels.get(STAT_FUMBLES) as Label
	var gap := s.y * 0.06
	roadmap_row.reset_size()
	luck.reset_size()
	fumbles.reset_size()
	var stats_h := maxf(luck.size.y, fumbles.size.y)
	var block := gap + roadmap_row.size.y + gap * 0.5 + stats_h
	for label in head:
		label.reset_size()
		block += label.size.y
	# Alles steht gemeinsam etwas über der Mitte der Bühne; Kopfzeilen bühnenbreit,
	# damit eine tickende Zahl mittig bleibt.
	var y := maxf(0.0, (s.y - block) * 0.4)
	for label in head:
		label.position = Vector2(0.0, y)
		label.size = Vector2(s.x, label.size.y)
		y += label.size.y
	var row_y := y + gap
	roadmap_row.position = Vector2((s.x - roadmap_row.size.x) * 0.5, row_y)
	# Glück und Fumbles als EINE Zeile mittig unter den Seiten.
	var stats_y := row_y + roadmap_row.size.y + gap * 0.5
	var spread := (size.x / 100.0) * 4.0
	var pair := luck.size.x + spread + fumbles.size.x
	luck.position = Vector2((s.x - pair) * 0.5, stats_y)
	fumbles.position = Vector2(luck.position.x + luck.size.x + spread, stats_y)
	var below := stats_y + stats_h
	if deal_token_row != null:
		deal_token_row.reset_size()
		deal_token_row.position = Vector2((s.x - deal_token_row.size.x) * 0.5,
			maxf(below, s.y - deal_token_row.size.y))

func _make_h_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer
