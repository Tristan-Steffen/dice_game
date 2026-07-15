class_name HubView
extends Control
## Der Einstellungen-Knopf unten rechts auf der Home-Seite wurde gedrückt - der
## Hub klappt daraufhin sein eigenes Einstellungs-Menü auf dem Display auf/zu
## (siehe _toggle_settings_menu). Früher ein 2D-Knopf/Dropdown in der Fensterecke.
signal settings_pressed
## Einträge des Einstellungs-Menüs (auf dem Display, siehe _build_settings_menu):
## scene_root verbindet sie mit den bestehenden Aktionen (Neues Spiel, Debug-
## Rundensieg, Charm-Bibliothek, Testmaterialien umschalten).
signal new_game_requested
signal debug_win_round_requested
signal library_requested
signal test_materials_requested

## Der HUB auf dem Tisch-Display: ein fest reservierter Bildschirm-Abschnitt
## UNTER der Grube, zwischen Pool- und Ablage-Tray (Position/Größe siehe
## scene_root: ScreenAnchors/Hub + HUB_*_WORLD). Er bündelt alles, was nicht
## direkt zum Wurf gehört: die Lauf-Übersicht als HOME-SEITE (Runde oben links,
## Geld oben rechts, Rundenbonus-Zeilen) und beliebig viele angehängte SEITEN
## (Shop, Gravur-Station, künftige Panels - siehe attach_panel).
##
## Der Hub ist der EINZIGE Verwalter dessen, was auf seiner Fläche sichtbar ist:
## zu jeder Zeit genau eine Seite ODER die Home-Übersicht, nie mehreres zugleich.
## Die Seiten öffnen/schließen sich weiter selbst über ihr visible; der Hub hört
## auf die Sichtbarkeits-Signale und setzt die Regel durch (verdrängte Seiten
## kehren beim Schließen der verdrängenden zurück, siehe
## _on_page_visibility_changed).
##
## Alle Maße leiten sich aus der eigenen Größe ab (Einheit u = Breite/100,
## siehe _layout) - der Hub skaliert also mit, wenn scene_root ihn über den
## Anker/die Weltmaße anders aufspannt.

## Farben im Stil des Displays (siehe TableScreen: Neon-Rahmen des Kombi-Clusters).
const FRAME_COLOR := Color("#8be9fd")   # 80s Neon Cyan - Rahmen
const FRAME_BG := Color("#1a1836aa")    # dunkles Violett, leicht durchscheinend
const TITLE_COLOR := Color("#ff79c6")   # 80s Neon Magenta - Überschriften
const TEXT_COLOR := Color(1.35, 1.35, 1.3)  # überhelles Weiß (leichter Glow)
const GOLD_COLOR := Color("#ffd319")    # Gold - Geld

## Lauf-Übersicht: Runde (Kopfzeile links) und Geld (Kopfzeile rechts).
var round_label: Label
var money_label: Label
## Die beiden Rundenbonus-Zeilen - Nachfolger der alten 3D-Tischtexte
## (BlindPayoutLabel3D/DicePayoutLabel3D): scene_root lässt sie beim Auszählen
## des Rundenendes nacheinander golden aufleuchten (siehe
## _play_round_clear_payout/_light_up_payout_label).
var blind_payout_label: Label
var die_payout_label: Label

var info_page: VBoxContainer

## Der Einstellungen-Knopf unten rechts auf der Home-Seite (auf dem Display, Teil
## von content_root - blendet also mit der Home-Seite aus, wenn eine andere Seite
## offen ist). Bedient über die Maus-Weiterleitung im Hub (siehe
## scene_root._forward_screen_mouse); klappt das Einstellungs-Menü auf/zu.
var settings_button: Button
## Das aufklappbare Einstellungs-Menü auf dem Display (Neues Spiel, Debug,
## Charm-Bibliothek, Testmaterialien) - ersetzt das alte 2D-Dropdown. Liegt über
## dem Home-Inhalt und öffnet sich per settings_button nach OBEN über dem Knopf
## (siehe _toggle_settings_menu/_position_settings_menu).
var settings_menu: PanelContainer
var _test_materials_button: Button
var _menu_u := 1.0  # Breiteneinheit, für die Neupositionierung gemerkt

## Der eigene Inhalt (alles außer dem Rahmen) - die HOME-SEITE des Hubs. Sichtbar
## nur, solange KEINE angehängte Seite (Shop, Gravur-Station, ...) offen ist
## (siehe _on_page_visibility_changed).
var content_root: MarginContainer

## Seiten-Verwaltung: der Hub zeigt zu JEDER ZEIT höchstens EINE Seite (oder die
## Home-Übersicht). Jedes über attach_panel angehängte Vollflächen-Panel ist eine
## Seite; öffnet sich eine (visible = true, z.B. shop.open()/show_die()), blendet
## der Hub alle anderen und den Home-Inhalt aus. Eine dabei VERDRÄNGTE Seite merkt
## er sich (LIFO) und holt sie zurück, sobald die verdrängende schließt - so kehrt
## z.B. der Shop wieder, wenn die zwischendurch geöffnete Gravur-Station zugeht.
## Ohne offene Seite zeigt der Hub die Home-Übersicht.
var _pages: Array[Control] = []
var _suppressed: Array[Control] = []  # verdrängte Seiten, kehren beim Schließen zurück
var _page_shown: Dictionary = {}  # Control -> zuletzt bekanntes visible (entprellt Baum-Signale)
var _switching := false  # wahr, während der Hub selbst Sichtbarkeiten umschaltet

var _built := false

## Der StyleBox des Neon-Rahmens (für flash_frame) + laufender Abkling-Tween.
var _frame_style: StyleBoxFlat
var _frame_tween: Tween

## Baut den Inhalt passend zur (von TableScreen.place_hub gesetzten) Größe auf -
## einmalig, direkt nach dem Platzieren.
func layout() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # der Rahmen selbst schluckt nichts
	var u := size.x / 100.0  # Breiteneinheit: alle Maße relativ zur Hub-Breite

	# Neon-Rahmen über die ganze Hub-Fläche (wie der Kombi-Cluster-Rahmen).
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

	# Kopfzeile: Runde links (an der Stelle des früheren "HUB"-Titels), Geld rechts.
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

	# --- Lauf-Übersicht: Rundenbonus-Zeilen ------------------------------------
	info_page = VBoxContainer.new()
	info_page.name = "InfoPage"
	info_page.add_theme_constant_override("separation", int(u * 1.6))
	info_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(info_page)

	_make_line(info_page, "Rundenbonus", u * 4.4, TITLE_COLOR)
	blind_payout_label = _make_line(info_page, "5$ pro Blind", u * 4.4, TEXT_COLOR)
	die_payout_label = _make_line(info_page, "1$ pro Würfel übrig", u * 4.4, TEXT_COLOR)

	# --- Einstellungen unten rechts --------------------------------------------
	# info_page dehnt sich senkrecht (SIZE_EXPAND_FILL), diese Fußzeile landet also
	# am unteren Rand; der dehnbare Platzhalter drückt den Knopf nach rechts.
	var footer := HBoxContainer.new()
	footer.name = "Footer"
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

## Baut das aufklappbare Einstellungs-Menü auf dem Display (Kind der Hub-Fläche,
## über allem, anfangs verborgen). Die Einträge melden ihre Aktionen als Signale;
## scene_root verbindet sie mit den bestehenden Handlern. Positioniert wird es
## erst beim Öffnen (siehe _position_settings_menu).
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
	_test_materials_button = _make_menu_button(box, "🧪 Testmaterialien: aus",
		CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, u, test_materials_requested.emit)

## Ein Menü-Eintrag (voll breit, im Display-Stil). Gibt den Knopf zurück, damit
## der Aufrufer ihn behalten kann (Testmaterialien-Beschriftung, siehe
## set_test_materials_label).
func _make_menu_button(parent: Control, text: String, accent: Color, dark: Color,
		u: float, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(u * 34.0, u * 6.0)
	CasinoStyle.style_button(button, accent, dark, int(u * 3.0))
	button.pressed.connect(func() -> void:
		on_pressed.call()
		settings_menu.visible = false)
	parent.add_child(button)
	return button

## Aktualisiert die Beschriftung des Testmaterialien-Eintrags (AN/aus) - scene_root
## ruft das nach dem Umschalten auf (siehe _refresh_test_materials_button).
func set_test_materials_label(text: String) -> void:
	if _test_materials_button != null:
		_test_materials_button.text = text

## Klappt das Einstellungs-Menü auf/zu. settings_pressed bleibt als Signal
## erhalten (Rückwärtskompatibilität/Tests), meldet jetzt aber das Umschalten.
func _toggle_settings_menu() -> void:
	settings_pressed.emit()
	if settings_menu == null:
		return
	settings_menu.visible = not settings_menu.visible
	if settings_menu.visible:
		_position_settings_menu()

## Setzt das Menü rechtsbündig ÜBER den Einstellungen-Knopf (klappt nach oben auf,
## damit es nicht über den unteren Rahmen hinausragt).
func _position_settings_menu() -> void:
	settings_menu.reset_size()
	var anchor := settings_button.get_global_rect()
	var top_left := Vector2(
		anchor.end.x - settings_menu.size.x,
		anchor.position.y - settings_menu.size.y - _menu_u * 1.2)
	settings_menu.position = top_left - global_position  # Viewport -> Hub-lokal

## Ob unter dem Display-Pixel point (Viewport-/Display-Koordinaten) ein
## interaktiver Punkt liegt - ein sichtbarer, nicht deaktivierter Knopf. Damit
## unterscheidet scene_root: ein Klick auf eine HUD-Option DRÜCKT den Knopf,
## ein Klick auf leere Hub-Fläche ZOOMT in den Hub (siehe _try_zoom_click).
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

## Lässt den Neon-Rahmen kurz in color aufleuchten und zur Grundfarbe (Cyan)
## abklingen - Teil der Geld-Lichtanimation: Gold bei Gutschriften, Chip-Farbe
## je ankommendem Kauf-Puls (siehe scene_root._play_money_light).
func flash_frame(color: Color) -> void:
	if _frame_style == null:
		return
	if _frame_tween != null:
		_frame_tween.kill()
	_frame_style.border_color = color
	_frame_tween = create_tween()
	_frame_tween.tween_property(_frame_style, "border_color", FRAME_COLOR, 0.5) \
		.set_delay(0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Hängt ein Vollflächen-Panel (Shop, Gravur-Station, ...) als SEITE über die
## Hub-Fläche und meldet es bei der Seiten-Verwaltung an: ab jetzt sorgt der Hub
## selbst dafür, dass immer nur diese ODER eine andere Seite ODER die Home-
## Übersicht sichtbar ist - die Panels öffnen/schließen sich weiter selbst über
## ihr visible (shop.open(), die_inspector.show_die()/close(), ...). Der
## Neon-Rahmen des Hubs bleibt stehen und rahmt auch die Seite.
func attach_panel(panel: Control) -> void:
	add_child(panel)
	# set_anchors_AND_offsets: eine Standardgröße aus einer .tscn (für
	# freistehende Instanzen, siehe Tests) würde sonst als Offset stehen bleiben.
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pages.append(panel)
	_page_shown[panel] = panel.visible
	panel.visibility_changed.connect(_on_page_visibility_changed.bind(panel))
	if panel.visible:
		_apply_page_opened(panel)

## Reagiert auf JEDE Sichtbarkeits-Änderung einer Seite - egal ob durch die Seite
## selbst (open()/close()) oder von außen - und stellt die EINE-SEITE-Regel wieder
## her. Entprellt über _page_shown: Baum-Signale (ein Vorfahr wurde umgeschaltet)
## ändern das eigene visible nicht und werden ignoriert; _switching verhindert
## Kaskaden, während der Hub selbst umschaltet.
func _on_page_visibility_changed(panel: Control) -> void:
	if _switching or not is_instance_valid(panel):
		return
	if _page_shown.get(panel, false) == panel.visible:
		return  # nur ein Baum-Signal - die Seite selbst hat nicht gewechselt
	_page_shown[panel] = panel.visible
	if panel.visible:
		_apply_page_opened(panel)
	else:
		_apply_page_closed(panel)

## Eine Seite hat sich geöffnet: alle anderen offenen Seiten verdrängen (sie
## kehren beim Schließen zurück) und den Home-Inhalt ausblenden.
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
		settings_menu.visible = false  # das Menü gehört zur Home-Seite, weicht mit ihr
	_switching = false

## Eine Seite hat sich geschlossen: die zuletzt verdrängte Seite zurückholen -
## oder, wenn keine mehr wartet, die Home-Übersicht zeigen. Schließt sie sich,
## während eine ANDERE Seite offen ist, passiert nichts (die bleibt vorn).
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

## Harter Reset (Spiel-Neustart, siehe scene_root._reset_game): alle Seiten zu,
## Verdrängungs-Gedächtnis leer, die Home-Übersicht zeigt sich wieder.
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

## Die zuletzt verdrängte, noch gültige Seite (LIFO) - null, wenn keine wartet.
func _pop_suppressed() -> Control:
	while not _suppressed.is_empty():
		var candidate: Control = _suppressed.pop_back()
		if is_instance_valid(candidate):
			return candidate
	return null

## Aktualisiert die Lauf-Übersicht (siehe scene_root._refresh_hub_info).
## Das Rundenziel wird nicht mehr im Hub gezeigt (es steht auf der Tisch-Zielleiste,
## siehe table_screen.set_goal_progress), deshalb nur noch Runde und Geld.
func set_run_info(round_number: int, money: int) -> void:
	if not _built:
		return
	round_label.text = "Runde %d" % round_number
	money_label.text = "$%d" % money

func _make_line(parent: Control, text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(font_size))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

## Ein waagerecht dehnbarer, durchsichtiger Platzhalter (drückt den Einstellungen-
## Knopf in der Fußzeile nach rechts).
func _make_h_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer
