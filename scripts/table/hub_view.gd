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

## Die Bühne der Startseite: links der TURM-Streifen, rechts Blind, Auskunft, Laufwerte,
## Diagramm und die Deal-Marken.
var roadmap_stage: Control
## Der Turm-Streifen: reine Übersicht, gezogen wird in der Grube.
var floor_map: FloorMapView
var blind_panel: Panel
var blind_title: Label
var blind_value: Label
var blind_step: Label
var info_panel: Panel
var info_title: Label
var info_body: Label
var info_move: Label
var values_grid: RunValuesGrid
var chart: RunChartView
var _floor_state: Dictionary = {}
## Maße der Bühne in u: Streifen-Anteil, Spalten-Fuge, die Höhen rechts von oben.
const STRIP_SHARE := 0.34
const MAP_BLEED_UNITS := 3.0
const COLUMN_GAP_UNITS := 2.2
const SECTION_GAP_UNITS := 1.2
const BLIND_UNITS := 10.2
const INFO_UNITS := 16.5
const GRID_ROWS_SHOWN := 2
const TOKEN_BAND_UNITS := 6.2
const CARD_PAD_UNITS := 1.2
## Die eine Schriftleiter der rechten Seite (in u).
const SMALL_FONT_UNITS := 2.1
const BODY_FONT_UNITS := 2.2
const TITLE_FONT_UNITS := 2.5
const BIG_FONT_UNITS := 4.6
const CARD_BG := Color(0.07, 0.065, 0.16, 0.85)
const BLIND_TITLE := "Blind"
const NEXT_BLIND_TITLE := "Nächster Blind"
const BOSS_TITLE := "Boss-Runde"
const STEP_TEXT := "Zug %d: %s%d %%"
const BLIND_COLOR := Color("#ff5555")
const BOSS_COLOR := Color("#ff3b3b")
## Hinweis-Karte der Deal-Marken und der Laufwerte (Hover).
var marker_hint: HintCard

## Deal-Marken unter der Seiten-Reihe; dieselbe Reihe liegt am oberen Grubenrand.
var deal_token_row: DealTokenRow

var info_page: Control  # Alias auf roadmap_stage (Rückwärts-Bezug)

## Laufwerte (Schlüssel und Farben; die Einträge reicht scene_root als Liste).
const STAT_CUSHION := "cushion"
const STAT_TREND := "trend"
const STAT_LUCK := "luck"
const STAT_FUMBLES := "fumbles"
const STAT_BEST := "best"
const STAT_STEP := "step"
const STAT_COLORS := {STAT_CUSHION: Color("#7fe0c8"), STAT_TREND: Color("#b8b0ff"),
	STAT_LUCK: Color("#9dff6b"), STAT_FUMBLES: Color("#ff8c42"), STAT_BEST: Color("#ecebff"),
	STAT_STEP: Color("#ff8f8f")}
## Polster unter ×1: der Blind ist typisch nicht zu schaffen.
const CUSHION_SHORT_COLOR := Color("#ff5555")
const NO_VALUE := "–"

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

# --- Die Bühne: Turm-Streifen, Blind, Auskunft, Laufwerte, Diagramm ----------

## Setzt den Stand der Etage (GameRun.floor_view_state); flash_door blitzt einmal rot.
func set_floor_state(view_state: Dictionary, deal_bonus_factor: int = 1,
		flash_door: String = "") -> void:
	if not _built or floor_map == null:
		return
	_floor_state = view_state
	floor_map.open(view_state, deal_bonus_factor, flash_door)
	_write_blind_card()
	_write_info()

## Ob ein Zug fällig ist: der Streifen hebt die gangbaren Räume hervor (scene_root je Bild).
func set_floor_moves_enabled(on: bool) -> void:
	if floor_map != null:
		floor_map.set_moves_enabled(on)

## Das Rad über Streifen oder Laufwerten rollt sie (true = verbraucht).
func wheel_at(pixel: Vector2, up: bool) -> bool:
	if not _built or content_root == null or not content_root.visible:
		return false
	if floor_map != null and floor_map.get_global_rect().has_point(pixel):
		floor_map.scroll_by(1.0 if up else -1.0)
		return true
	if values_grid != null and values_grid.get_global_rect().has_point(pixel):
		values_grid.scroll_by(-1.0 if up else 1.0)
		return true
	return false

## Die Laufwerte als Liste {key, title, text, sub, color, hint} - ein weiterer Wert ist
## ein weiterer Eintrag.
func set_run_values(values: Array) -> void:
	if _built and values_grid != null:
		values_grid.set_values(values)

## Das Diagramm aus GameRun.run_chart ({blinds, scores}).
func set_chart(data: Dictionary) -> void:
	if _built and chart != null:
		chart.set_series(data.get("blinds", []), data.get("scores", []))

## Baut die Bühne: Streifen samt Knopf, die Karten rechts, Raster, Diagramm, Marken.
func _build_rim_stage(u: float) -> void:
	floor_map = FloorMapView.new()
	floor_map.name = "FloorMap"
	floor_map.mode = FloorMapView.Mode.COMPACT
	floor_map.unit_px = u
	floor_map.hover_changed.connect(_write_info)
	roadmap_stage.add_child(floor_map)
	blind_panel = _card_panel("BlindCard", u)
	blind_title = _stage_label("BlindTitle", SMALL_FONT_UNITS, u)
	blind_value = _stage_label("BlindValue", BIG_FONT_UNITS, u)
	blind_step = _stage_label("BlindStep", TITLE_FONT_UNITS, u)
	blind_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_panel = _card_panel("InfoCard", u)
	info_title = _stage_label("InfoTitle", TITLE_FONT_UNITS, u)
	info_move = _stage_label("InfoMove", SMALL_FONT_UNITS, u)
	info_body = _stage_label("InfoBody", BODY_FONT_UNITS, u)
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	values_grid = RunValuesGrid.new()
	values_grid.name = "RunValues"
	values_grid.unit_px = u
	values_grid.tile_hovered.connect(func(tile: Control, title: String, hint: String, color: Color) -> void:
		_show_hint(tile, title, hint, color))
	values_grid.tile_left.connect(_hide_marker_hint)
	roadmap_stage.add_child(values_grid)
	chart = RunChartView.new()
	chart.name = "RunChart"
	chart.unit_px = u
	roadmap_stage.add_child(chart)
	_build_deal_tokens(u)
	_build_marker_hint(u)  # zuletzt: der Hinweis liegt über allem

func _card_panel(node_name: String, u: float) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = CARD_BG
	box.set_corner_radius_all(int(u * 0.9))
	panel.add_theme_stylebox_override("panel", box)
	roadmap_stage.add_child(panel)
	return panel

func _stage_label(node_name: String, font_units: float, u: float) -> Label:
	var label := CasinoStyle.label("", u * font_units, FloorMapView.TEXT_COLOR)
	label.name = node_name
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	roadmap_stage.add_child(label)
	return label

## Die Blind-Karte: vor dem Zug der nächste Blind, im Büro die Boss-Runde.
func _write_blind_card() -> void:
	if blind_title == null or _floor_state.is_empty():
		return
	var due := bool(_floor_state.get("due", false))
	var boss := FloorMapView.is_boss(_floor_state)
	blind_title.text = BOSS_TITLE if boss else (NEXT_BLIND_TITLE if due else BLIND_TITLE)
	blind_title.modulate = BOSS_COLOR if boss else FloorMapView.MUTED_COLOR.lightened(0.2)
	blind_value.text = BigNumber.short(int(_floor_state.get("next_blind" if due else "blind", 0)))
	blind_value.modulate = BOSS_COLOR if boss else BLIND_COLOR
	var percent := int(_floor_state.get("step_percent", 0))
	# Vor dem Zug sein eigener Schritt, danach der des nächsten.
	var move := int(_floor_state.get("moves", 0)) + 1
	blind_step.text = FloorMapView.head_text(_floor_state) if boss \
		else STEP_TEXT % [move, "+" if percent >= 0 else "−", absi(percent)]

## Die Auskunft: was der Streifen unter dem Zeiger hat, sonst die ruhige Zeile.
func _write_info() -> void:
	if info_title == null or floor_map == null:
		return
	var parts := floor_map.info_parts()
	info_title.text = String(parts["title"])
	info_title.modulate = parts["color"]
	info_body.text = String(parts["body"])
	info_body.modulate = FloorMapView.MUTED_COLOR.lightened(0.4)
	info_move.text = String(parts["move"])
	info_move.modulate = parts["move_color"]

## Die Texte der Auskunft (für Tests und Sichtproben).
func info_text() -> String:
	if info_title == null:
		return ""
	var text := info_title.text + "\n" + info_body.text
	if info_move.text != "":
		text += "\n" + info_move.text
	return text

## Marken-Reihe unten rechts auf der Bühne (Position setzt _layout_stage).
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

## Hinweis-Karte für Deal-Marken und Laufwerte.
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

func _on_stage_resized() -> void:
	_layout_stage()

## Rechtecke der Bühne (Bühnen-Koordinaten): strip, blind, info, grid, chart, tokens.
func stage_rects() -> Dictionary:
	var s := roadmap_stage.size
	var u := size.x / 100.0
	var gap := u * SECTION_GAP_UNITS
	var bleed := u * MAP_BLEED_UNITS
	var strip_w := s.x * STRIP_SHARE
	var rects := {}
	# Der Streifen darf in den Seitenrand greifen: jede Spalte zählt.
	rects["strip"] = Rect2(-bleed, 0.0, strip_w + bleed, maxf(s.y, 1.0))
	var x := strip_w + u * COLUMN_GAP_UNITS
	var w := maxf(s.x + bleed - x, 1.0)
	var y := 0.0
	rects["blind"] = Rect2(x, y, w, u * BLIND_UNITS)
	y += u * BLIND_UNITS + gap
	rects["info"] = Rect2(x, y, w, u * INFO_UNITS)
	y += u * INFO_UNITS + gap
	var tile_h := u * RunValuesGrid.TILE_HEIGHT_UNITS
	var grid_h := tile_h * float(GRID_ROWS_SHOWN) + u * RunValuesGrid.GAP_UNITS * float(GRID_ROWS_SHOWN - 1)
	rects["grid"] = Rect2(x, y, w, grid_h)
	y += grid_h + gap
	var tokens_h := u * TOKEN_BAND_UNITS
	rects["tokens"] = Rect2(x, s.y - tokens_h, w, tokens_h)
	rects["chart"] = Rect2(x, y, w, maxf(s.y - tokens_h - gap - y, 1.0))
	return rects

## Stellt alles auf der Bühne nach stage_rects.
func _layout_stage() -> void:
	var s := roadmap_stage.size
	if s.x < 40.0 or s.y < 40.0 or floor_map == null:
		return
	var u := size.x / 100.0
	var pad := u * CARD_PAD_UNITS
	var r := stage_rects()
	_place(floor_map, r["strip"])
	var blind: Rect2 = r["blind"]
	_place(blind_panel, blind)
	var inner := blind.grow(-pad)
	var title_h := u * SMALL_FONT_UNITS * 1.5
	_place(blind_title, Rect2(inner.position, Vector2(inner.size.x * 0.55, title_h)))
	# Der große Wert nimmt die Karte bis zur Unterkante, sonst ragt er über ihren Rand.
	_place(blind_value, Rect2(inner.position + Vector2(0.0, title_h),
		Vector2(inner.size.x * 0.6, blind.end.y - inner.position.y - title_h)))
	_place(blind_step, Rect2(inner.position + Vector2(inner.size.x * 0.4, title_h),
		Vector2(inner.size.x * 0.6, inner.size.y - title_h)))
	var info: Rect2 = r["info"]
	_place(info_panel, info)
	inner = info.grow(-pad)
	var row_h := u * TITLE_FONT_UNITS * 1.4
	_place(info_title, Rect2(inner.position, Vector2(inner.size.x, row_h)))
	var move_h := u * SMALL_FONT_UNITS * 1.5
	_place(info_move, Rect2(Vector2(inner.position.x, inner.end.y - move_h), Vector2(inner.size.x, move_h)))
	_place(info_body, Rect2(inner.position + Vector2(0.0, row_h),
		Vector2(inner.size.x, inner.size.y - row_h - move_h)))
	_place(values_grid, r["grid"])
	_place(chart, r["chart"])
	if deal_token_row != null:
		deal_token_row.reset_size()
		var band: Rect2 = r["tokens"]
		deal_token_row.position = Vector2(band.position.x + (band.size.x - deal_token_row.size.x) * 0.5,
			band.position.y + maxf(0.0, (band.size.y - deal_token_row.size.y) * 0.5))

func _place(control: Control, rect: Rect2) -> void:
	if control == null:
		return
	control.position = rect.position
	control.size = rect.size

func _make_h_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer
