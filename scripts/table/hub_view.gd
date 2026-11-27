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
signal debug_luck_requested
signal debug_energy_cap_requested
signal debug_parts_requested
signal debug_runes_requested
signal debug_random_faces_requested
signal library_requested
signal test_materials_requested
signal test_engravings_requested

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

## Die Bühne der Startseite: oben die ETAGEN-KARTE (ihr Kopf nennt Etage, Zug und
## Blind), darunter die Lauf-Anzeigen und die Deal-Marken.
var roadmap_stage: Control
## Die Etagen-Karte; ein Klick auf einen gangbaren Raum meldet door_chosen.
var floor_map: FloorMapView
var _blind_growth_pct := 0
## Zug der Etage samt fälligem (0 = Eingang) und ob er fällig ist - für die Nächster-Zeile.
var _floor_move := 0
var _move_due := false
## Band unter der Karte: Lauf-Anzeigen, dann die Deal-Marken (in u).
const STATS_GAP_UNITS := 1.2
const TOKEN_BAND_UNITS := 6.2
const MAP_BLEED_UNITS := 3.0
## Hinweis-Karte der Deal-Marken und der Lauf-Anzeigen (Hover).
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
	money_label.modulate = CasinoStyle.MONEY
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
	_make_menu_button(box, "Debug: +5 Glück", CasinoStyle.GOLD, CasinoStyle.GOLD_DARK,
		u, debug_luck_requested.emit, true)
	_make_menu_button(box, "Debug: +5 ⚡-Speicher", CasinoStyle.BLUE, CasinoStyle.BLUE_DARK,
		u, debug_energy_cap_requested.emit, true)
	_make_menu_button(box, "Debug: Runen auf alle Würfel", CasinoStyle.GOLD, CasinoStyle.GOLD_DARK,
		u, debug_runes_requested.emit, true)
	_make_menu_button(box, "Debug: Seiten 1–2000", CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK,
		u, debug_random_faces_requested.emit, true)
	if OS.is_debug_build():
		_make_menu_button(box, "Debug: Module", CasinoStyle.GOLD, CasinoStyle.GOLD_DARK,
			u, debug_parts_requested.emit)
	_test_materials_button = _make_menu_button(box, "🧪 Testmaterialien: aus",
		CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, u, test_materials_requested.emit)
	# Kein Schalter, eine Lieferung - und sie bleibt offen fürs Nachlegen.
	_test_engravings_button = _make_menu_button(box, TEST_PACKS_LABEL,
		CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, u, test_engravings_requested.emit, true)

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

# --- Etagen-Karte + Lauf-Anzeigen (Home-Bänder) ------------------------------

## Setzt den Stand der Etage (GameRun.floor_view_state); flash_door blitzt einmal rot.
func set_floor_state(view_state: Dictionary, deal_bonus_factor: int = 1,
		flash_door: String = "") -> void:
	if not _built or floor_map == null:
		return
	_move_due = bool(view_state.get("due", false))
	_floor_move = int(view_state.get("moves", 0)) + (1 if _move_due else 0)
	floor_map.open(view_state, deal_bonus_factor, flash_door)
	_write_stat(STAT_BLIND, int(_stat_shown.get(STAT_BLIND, 0)))
	_layout_stage()

## Ob der fällige Zug jetzt angenommen wird (scene_root fragt es je Bild).
func set_floor_moves_enabled(on: bool) -> void:
	if floor_map != null:
		floor_map.set_moves_enabled(on)

## Der Zug, den ein Klick auf dieses Display-Pixel wählen würde ("" = keiner) - so
## nimmt die Karte den Klick auch aus der Ferne, wo der Hub sonst nur Knöpfe bedient.
func floor_move_at(pixel: Vector2) -> String:
	if floor_map == null or not floor_map.is_visible_in_tree() or content_root == null \
			or not content_root.visible:
		return ""
	var rect := floor_map.get_global_rect()
	if not rect.has_point(pixel):
		return ""
	return floor_map.move_for(floor_map.target_at(pixel - rect.position))

## Baut die Bühne: die Etagen-Karte, die Lauf-Anzeigen und die Deal-Marken.
func _build_rim_stage(u: float) -> void:
	floor_map = FloorMapView.new()
	floor_map.name = "FloorMap"
	roadmap_stage.add_child(floor_map)
	_build_run_stats(u)
	_build_deal_tokens(u)
	_build_marker_hint(u)  # zuletzt: der Hinweis liegt über allem

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

## Hinweis-Karte für Deal-Marken und Lauf-Anzeigen.
func _build_marker_hint(u: float) -> void:
	marker_hint = HintCard.new(u)
	marker_hint.name = "MarkerHint"
	roadmap_stage.add_child(marker_hint)

func _show_hint(anchor_control: Control, title: String, body: String, accent: Color) -> void:
	if marker_hint == null:
		return
	var u := size.x / 100.0
	marker_hint.show_for(anchor_control, roadmap_stage, title, body, accent, u * 1.2)

func _hide_marker_hint() -> void:
	if marker_hint != null:
		marker_hint.hide_card()

## Die Lauf-Anzeigen: Nächster Blind, Glück und Fumbles als EINE Zeile unter der
## Karte - je mit Hover-Hinweis.
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
## growth_pct: Schritt des nächsten Zugs in Prozent (GameRun.blind_growth).
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
		# Vor dem Zug nennt der Kopf der Karte den nächsten Blind - hier nur sein Schritt.
		if _move_due:
			label.text = "Zug %d: %+d %%" % [_floor_move, _blind_growth_pct]
			return
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

## Stellt alles auf der Bühne: die Karte füllt sie, darunter die Lauf-Anzeigen als
## Zeile und zuunterst das Band der Deal-Marken.
func _layout_stage() -> void:
	var s := roadmap_stage.size
	if s.x < 40.0 or s.y < 40.0 or floor_map == null:
		return
	var u := size.x / 100.0
	var row: Array[Label] = [stat_labels.get(STAT_BLIND) as Label, stat_labels.get(STAT_LUCK) as Label,
		stat_labels.get(STAT_FUMBLES) as Label]
	var stats_h := 0.0
	var widths := 0.0
	for label in row:
		label.reset_size()
		stats_h = maxf(stats_h, label.size.y)
		widths += label.size.x
	var token_band := u * TOKEN_BAND_UNITS
	var gap := u * STATS_GAP_UNITS
	var map_h := maxf(s.y - token_band - stats_h - gap * 2.0, 40.0)
	# Die Karte darf in den Seitenrand der Startseite greifen: jede Spalte zählt.
	var bleed := u * MAP_BLEED_UNITS
	floor_map.position = Vector2(-bleed, 0.0)
	floor_map.size = Vector2(s.x + bleed * 2.0, map_h)
	var spread := u * 4.0
	var x := (s.x - widths - spread * float(row.size() - 1)) * 0.5
	var stats_y := map_h + gap
	for label in row:
		label.position = Vector2(x, stats_y)
		x += label.size.x + spread
	if deal_token_row != null:
		deal_token_row.reset_size()
		var band_top := stats_y + stats_h + gap
		deal_token_row.position = Vector2((s.x - deal_token_row.size.x) * 0.5,
			band_top + maxf(0.0, (s.y - band_top - deal_token_row.size.y) * 0.5))

func _make_h_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer
