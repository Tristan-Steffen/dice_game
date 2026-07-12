class_name CharmLibraryView
extends Panel
## Die Charm-Bibliothek: ein Nachschlage-Panel mit ALLEN Charms des Spiels
## (Charm.all(), alphabetisch), je Eintrag eine 3D-Miniatur des echten Modells
## (siehe CharmThumb; Platzhalter-Karte bei Charms ohne Modelldatei) plus Name
## und Beschreibung; bereits besessene Charms sind gold markiert. Klick auf
## einen Eintrag wechselt in die Nahansicht: das Modell groß und frei drehbar
## (Ziehen mit der Maus, wie die Würfel in der Gravur-Station) - "‹ Zurück"
## führt zur Liste. Aufgeklappt über den Bibliothek-Knopf im Einstellungs-Menü
## (siehe scene_root); die Zeilen werden bei jedem Öffnen frisch gebaut
## (Besitz ändert sich ja) und beim Schließen wieder freigegeben.

const THUMB_SIZE := 44          # Kantenlänge der Zeilen-Miniaturen
const INSPECT_THUMB_SIZE := 360  # Kantenlänge der drehbaren Nahansicht

## Der laufende Spiellauf - nur für die Besitz-Markierung (vom Besitzer
## scene_root bei jedem neuen Run gesetzt, siehe _connect_run).
var run: GameRun

var rows: VBoxContainer
var list_root: ScrollContainer

## Nahansicht-Knoten (einmal gebaut, pro inspect() neu befüllt).
var inspect_root: VBoxContainer
var inspect_name_label: Label
var inspect_desc_label: Label
var inspect_thumb: CharmThumb
var inspect_grant_button: Button
var inspect_charm: Charm  # gerade in der Nahansicht gezeigter Charm

func _ready() -> void:
	visible = false
	# Rechte Bildschirmseite, gleiche Zone wie früher die Würfel-Sammlung.
	offset_left = 812.0
	offset_top = 64.0
	offset_right = 1256.0
	offset_bottom = 726.0
	CasinoStyle.style_panel(self)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16.0
	vbox.offset_top = 14.0
	vbox.offset_right = -16.0
	vbox.offset_bottom = -14.0
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title := Label.new()
	title.text = "Charm-Bibliothek"
	CasinoStyle.style_score_label(title, 22, CasinoStyle.GOLD)
	vbox.add_child(title)

	list_root = ScrollContainer.new()
	list_root.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(list_root)

	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 9)
	list_root.add_child(rows)

	_build_inspect_root(vbox)

## Baut die (zunächst versteckte) Nahansicht: Zurück-Knopf, großes drehbares
## Modell (pro inspect() ersetzt), Name und Beschreibung.
func _build_inspect_root(parent: VBoxContainer) -> void:
	inspect_root = VBoxContainer.new()
	inspect_root.visible = false
	inspect_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspect_root.add_theme_constant_override("separation", 8)
	parent.add_child(inspect_root)

	var back := Button.new()
	back.text = "‹  Zurück"
	back.custom_minimum_size = Vector2(120, 32)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	CasinoStyle.style_button(back, CasinoStyle.BLUE, CasinoStyle.BLUE_DARK, 14)
	back.pressed.connect(close_inspect)
	inspect_root.add_child(back)

	inspect_name_label = Label.new()
	inspect_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CasinoStyle.style_score_label(inspect_name_label, 20, CasinoStyle.GOLD)
	inspect_root.add_child(inspect_name_label)

	inspect_desc_label = Label.new()
	inspect_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CasinoStyle.style_body_label(inspect_desc_label, 14)
	inspect_root.add_child(inspect_desc_label)

	# Debug-Knopf: den gezeigten Charm gratis in den laufenden Run legen (kein
	# Preis, siehe GameRun.purchase_charm) - zum Ausprobieren von Charm-Effekten.
	inspect_grant_button = Button.new()
	inspect_grant_button.custom_minimum_size = Vector2(0, 34)
	inspect_grant_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	CasinoStyle.style_button(inspect_grant_button, CasinoStyle.GREEN, CasinoStyle.GREEN_DARK, 14)
	inspect_grant_button.pressed.connect(_on_grant_pressed)
	inspect_root.add_child(inspect_grant_button)

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	close_inspect()
	_rebuild()
	visible = true

func close() -> void:
	visible = false
	close_inspect()
	for child in rows.get_children():
		child.queue_free()

## Wechselt in die Nahansicht des Charms: großes, frei drehbares Modell
## (CharmThumb rotatable, dreht wie die Würfel der Gravur-Station).
func inspect(charm: Charm) -> void:
	inspect_charm = charm
	if inspect_thumb != null:
		inspect_thumb.queue_free()
	inspect_thumb = CharmThumb.new(charm, INSPECT_THUMB_SIZE, true)
	inspect_thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inspect_root.add_child(inspect_thumb)
	inspect_root.move_child(inspect_thumb, 1)  # zwischen Zurück-Knopf und Name
	inspect_name_label.text = _display_name(charm, _owned_ids().has(charm.id))
	inspect_desc_label.text = charm.description
	_refresh_grant_button()
	list_root.visible = false
	inspect_root.visible = true

## Aktualisiert den Debug-Grant-Knopf: bereits besessene Charms sind nicht mehr
## holbar (deaktiviert, Text zeigt den Besitz).
func _refresh_grant_button() -> void:
	if run != null and _owned_ids().has(inspect_charm.id):
		inspect_grant_button.text = "Debug: bereits im Run"
		inspect_grant_button.disabled = true
	else:
		inspect_grant_button.text = "Debug: Für diesen Run holen"
		inspect_grant_button.disabled = run == null

## Debug: legt den gezeigten Charm gratis in den laufenden Run (siehe
## GameRun.purchase_charm mit Preis 0 - meldet charms_changed, sodass Tisch und
## HUD ihn sofort übernehmen). Danach Name (✓) und Knopf auffrischen.
func _on_grant_pressed() -> void:
	if run == null or _owned_ids().has(inspect_charm.id):
		return
	run.purchase_charm(inspect_charm, 0)
	inspect_name_label.text = _display_name(inspect_charm, true)
	_refresh_grant_button()

## Zurück zur Liste; gibt das drehbare Modell frei (rendert sonst weiter).
func close_inspect() -> void:
	if inspect_thumb != null:
		inspect_thumb.queue_free()
		inspect_thumb = null
	if inspect_root != null:
		inspect_root.visible = false
	if list_root != null:
		list_root.visible = true

## Baut die Einträge frisch: alle Charms alphabetisch, besessene gold markiert.
func _rebuild() -> void:
	for child in rows.get_children():
		child.queue_free()
	var charms := Charm.all()
	charms.sort_custom(func(a: Charm, b: Charm) -> bool:
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	var owned := _owned_ids()
	for charm in charms:
		rows.add_child(_build_row(charm, owned.has(charm.id)))

func _owned_ids() -> Array[String]:
	return run.owned_charm_ids() if run != null else []

func _display_name(charm: Charm, is_owned: bool) -> String:
	return "%s  ✓" % charm.display_name if is_owned else charm.display_name

func _build_row(charm: Charm, is_owned: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.tooltip_text = "Anklicken für die Nahansicht"
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			inspect(charm))

	row.add_child(CharmThumb.new(charm, THUMB_SIZE))

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_PASS  # Klicks auf den Text treffen die Zeile
	row.add_child(text)

	var name_label := Label.new()
	name_label.text = _display_name(charm, is_owned)
	CasinoStyle.style_body_label(name_label, 15, CasinoStyle.GOLD if is_owned else CasinoStyle.PURPLE)
	text.add_child(name_label)

	var desc := Label.new()
	desc.text = charm.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CasinoStyle.style_body_label(desc, 13)
	text.add_child(desc)
	return row
