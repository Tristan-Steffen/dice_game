class_name HubView
extends Control
## Der HUB auf dem Tisch-Display: ein fest reservierter Bildschirm-Abschnitt
## UNTER der Grube, zwischen Pool- und Ablage-Tray (Position/Größe siehe
## scene_root: ScreenAnchors/Hub + HUB_*_WORLD). Er bündelt alles, was nicht
## direkt zum Wurf gehört - heute die Lauf-Übersicht (Runde oben links, Geld oben
## rechts, Rundenziel und die Rundenbonus-Zeilen, die früher als 3D-Tischtexte
## neben der Ablage lagen); später zieht hier der Shop zwischen den Runden und
## die Würfel-Aufwertung ein.
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

## Der eigene Inhalt (alles außer dem Rahmen) - wird ausgeblendet, solange der
## Shop die Hub-Fläche belegt (siehe attach_shop/set_content_visible).
var content_root: MarginContainer

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
