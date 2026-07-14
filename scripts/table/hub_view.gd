class_name HubView
extends Control
## Der HUB auf dem Tisch-Display: ein fest reservierter Bildschirm-Abschnitt
## UNTER der Grube, zwischen Pool- und Ablage-Tray (Position/Größe siehe
## scene_root: ScreenAnchors/Hub + HUB_*_WORLD). Er bündelt alles, was nicht
## direkt zum Wurf gehört - heute die Lauf-Übersicht (Runde, Geld, Rundenziel,
## die Rundenbonus-Zeilen, die früher als 3D-Tischtexte neben der Ablage lagen)
## und eine Boss-Vorschau (Platzhalter, Bosse folgen); später zieht hier der
## Shop zwischen den Runden und die Würfel-Aufwertung ein.
##
## Der Hub ist das erste ECHT INTERAKTIVE Stück Display: seine Buttons (Seiten-
## Tabs) funktionieren über die Maus-Weiterleitung in scene_root
## (_forward_screen_mouse) - Klicks/Hover werden per Strahl auf die Tischebene
## in Display-Pixel übersetzt und in den SubViewport gereicht, sobald die
## Kamera auf den Hub gezoomt ist (CameraRig.Mode.HUB).
##
## Alle Maße leiten sich aus der eigenen Größe ab (Einheit u = Breite/100,
## siehe _layout) - der Hub skaliert also mit, wenn scene_root ihn über den
## Anker/die Weltmaße anders aufspannt.

## Farben im Stil des Displays (siehe TableScreen: Neon-Rahmen des Kombi-Clusters).
const FRAME_COLOR := Color("#8be9fd")   # 80s Neon Cyan - Rahmen
const FRAME_BG := Color("#1a1836aa")    # dunkles Violett, leicht durchscheinend
const TITLE_COLOR := Color("#ff79c6")   # 80s Neon Magenta - Überschriften
const TEXT_COLOR := Color(1.35, 1.35, 1.3)  # überhelles Weiß (leichter Glow)
const GOLD_COLOR := Color("#ffd319")    # Gold - Geld/aktiver Tab
const MUTED_COLOR := Color(0.75, 0.78, 0.9)  # gedämpft - Hinweistexte

enum Page { INFO, BOSS }

var current_page: Page = Page.INFO

## Lauf-Übersicht (Seite INFO).
var round_label: Label
var money_label: Label
var goal_label: Label
## Die beiden Rundenbonus-Zeilen - Nachfolger der alten 3D-Tischtexte
## (BlindPayoutLabel3D/DicePayoutLabel3D): scene_root lässt sie beim Auszählen
## des Rundenendes nacheinander golden aufleuchten (siehe
## _play_round_clear_payout/_light_up_payout_label).
var blind_payout_label: Label
var die_payout_label: Label

## Boss-Vorschau (Seite BOSS) - Platzhalter, bis Bosse implementiert sind.
var boss_name_label: Label

var info_page: VBoxContainer
var boss_page: VBoxContainer
var info_tab: Button
var boss_tab: Button

## Der eigene Inhalt (alles außer dem Rahmen) - wird ausgeblendet, solange der
## Shop die Hub-Fläche belegt (siehe attach_shop/set_content_visible).
var content_root: MarginContainer

var _built := false

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

	# Kopfzeile: Titel links, Seiten-Tabs rechts.
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", int(u * 2.0))
	column.add_child(header)
	var title := Label.new()
	title.name = "Title"
	title.text = "HUB"
	title.add_theme_font_size_override("font_size", int(u * 6.0))
	title.modulate = TITLE_COLOR
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	info_tab = _make_tab("Übersicht", u, _show_info_page)
	boss_tab = _make_tab("Boss", u, _show_boss_page)
	header.add_child(info_tab)
	header.add_child(boss_tab)

	# --- Seite ÜBERSICHT: Runde / Geld / Ziel + Rundenbonus-Zeilen -------------
	info_page = VBoxContainer.new()
	info_page.name = "InfoPage"
	info_page.add_theme_constant_override("separation", int(u * 1.6))
	info_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(info_page)

	round_label = _make_line(info_page, "Runde 1", u * 5.0, TEXT_COLOR)
	money_label = _make_line(info_page, "$0", u * 5.0, GOLD_COLOR)
	goal_label = _make_line(info_page, "Rundenziel: 0 Punkte", u * 4.4, TEXT_COLOR)

	info_page.add_child(_make_spacer(u * 2.0))
	_make_line(info_page, "Rundenbonus", u * 4.4, TITLE_COLOR)
	blind_payout_label = _make_line(info_page, "5$ pro Blind", u * 4.4, TEXT_COLOR)
	die_payout_label = _make_line(info_page, "1$ pro Würfel übrig", u * 4.4, TEXT_COLOR)

	# --- Seite BOSS: Platzhalter-Vorschau --------------------------------------
	boss_page = VBoxContainer.new()
	boss_page.name = "BossPage"
	boss_page.add_theme_constant_override("separation", int(u * 1.6))
	boss_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(boss_page)

	_make_line(boss_page, "Nächster Boss", u * 4.4, TITLE_COLOR)
	boss_name_label = _make_line(boss_page, "???", u * 7.0, TEXT_COLOR)
	var hint := _make_line(boss_page, "Bosse sind noch nicht implementiert – hier erscheint künftig, welcher Boss auf diesen Run wartet.", u * 3.4, MUTED_COLOR)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_show_info_page()

## Hängt ein Vollflächen-Panel (Shop, Gravur-Station, ...) über die Hub-Fläche -
## es bleibt unsichtbar, bis scene_root es öffnet. Der Neon-Rahmen des Hubs
## bleibt dabei stehen und rahmt auch das Panel.
func attach_panel(panel: Control) -> void:
	add_child(panel)
	# set_anchors_AND_offsets: eine Standardgröße aus einer .tscn (für
	# freistehende Instanzen, siehe Tests) würde sonst als Offset stehen bleiben.
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## Blendet den EIGENEN Inhalt (Titel, Tabs, Seiten) aus/ein - aus, solange der
## Shop die Fläche belegt (siehe scene_root._on_round_complete/_on_shop_closed).
func set_content_visible(content_visible: bool) -> void:
	if content_root != null:
		content_root.visible = content_visible

## Aktualisiert die Lauf-Übersicht (siehe scene_root._refresh_hub_info).
func set_run_info(round_number: int, money: int, goal: int) -> void:
	if not _built:
		return
	round_label.text = "Runde %d" % round_number
	money_label.text = "$%d" % money
	goal_label.text = "Rundenziel: %d Punkte" % goal

func _show_info_page() -> void:
	current_page = Page.INFO
	_refresh_pages()

func _show_boss_page() -> void:
	current_page = Page.BOSS
	_refresh_pages()

func _refresh_pages() -> void:
	info_page.visible = current_page == Page.INFO
	boss_page.visible = current_page == Page.BOSS
	_style_tab(info_tab, current_page == Page.INFO)
	_style_tab(boss_tab, current_page == Page.BOSS)

## Ein Seiten-Tab im Neon-Stil; der aktive Tab bekommt einen goldenen Rahmen.
func _make_tab(text: String, u: float, on_pressed: Callable) -> Button:
	var tab := Button.new()
	tab.text = text
	tab.focus_mode = Control.FOCUS_NONE
	tab.add_theme_font_size_override("font_size", int(u * 3.6))
	tab.add_theme_color_override("font_color", TEXT_COLOR)
	tab.add_theme_color_override("font_hover_color", GOLD_COLOR)
	tab.add_theme_color_override("font_pressed_color", GOLD_COLOR)
	tab.custom_minimum_size = Vector2(u * 20.0, u * 6.4)
	tab.pressed.connect(on_pressed)
	return tab

func _style_tab(tab: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#241f4add") if active else Color("#1a183688")
	style.border_color = GOLD_COLOR if active else FRAME_COLOR
	style.set_border_width_all(maxi(2, int(size.x / 100.0 * 0.25)))
	style.set_corner_radius_all(int(size.x / 100.0 * 1.0))
	for state in ["normal", "hover", "pressed", "focus"]:
		tab.add_theme_stylebox_override(state, style)

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
