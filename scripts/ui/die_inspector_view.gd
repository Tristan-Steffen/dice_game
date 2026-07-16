class_name DieInspectorView
extends Control
## Die Gravur-Station für einen einzelnen Würfel - ein Neon-Panel auf dem
## Tisch-Display (HubView.attach_panel). Der gegriffene Würfel schwebt als
## ECHTES Weltobjekt über der Bühne oben im Panel; darunter die Bedienung:
## Seite (oder Kanten) über die Chips wählen, dann einen Sigil auf dem
## Gravur-Bord klicken. Mehrstufige Ätzungen fragen die zweite Seite bzw. den
## Zielwert nach. Der gezeigte Würfel ist DIESELBE DieDefinition-Instanz wie
## im Pool - die Ätzung wirkt dauerhaft. Bedient über die Maus-Weiterleitung;
## Rechtsklick behandelt scene_root.

## Nach dem Anwenden einer Ätzung - scene_root zeichnet die Trays neu.
signal changed
## Nach dem Anwenden, mit Quelle für die Absorptions-Animation.
signal applied(sigil_id: String, slot_px: Vector2)
signal closed
## Zelle des Würfel-Rasters angeklickt: scene_root wechselt das Gravur-Ziel
## (slot = ECHTER Slot-Index im Ursprungs-Tray).
signal select_tray_die(slot: int)
## Dreh-Geste an der Projektion läuft/endet - scene_root sperrt derweil das
## Kamera-Rundschauen.
signal rotating_die(active: bool)

## Auswahl geändert: face_index (0..5, -1 = keine) bzw. edges - scene_root
## spiegelt das auf den echten schwebenden Würfel.
signal selection_changed(face_index: int, edges: bool)

## Ablauf-Zustand: normale Auswahl, Warten auf die zweite Seite oder auf den
## Feingravur-Zielwert.
enum Mode { SELECT, AWAIT_SECOND_FACE, PICK_VALUE }

## Farben im Display-Stil (80s Neon).
const NEON_CYAN := Color("#8be9fd")
const NEON_MAGENTA := Color("#ff79c6")
const NEON_GOLD := Color("#ffd319")
const NEON_TEXT := Color(1.35, 1.35, 1.3)
const NEON_MUTED := Color(0.75, 0.78, 0.9)
## Neutraler Rahmen unausgewählter Seiten-/Kanten-Chips.
const CHIP_BORDER := Color(0.72, 0.76, 0.8)

const SLOT_COLUMNS := 8  # Bord-Plätze je Zeile
const STACK_MAX_VISIBLE := 3  # mehr Exemplare zeigt nur noch die ×Anzahl

## Unter-Bildschirm der Würfel-Projektion: abgesetzte Grundfarbe (Petrol).
const DIE_VIEW_BG := Color("#0d2430")

## Anteil der Panel-Höhe, der oben als Bühne für den schwebenden Würfel frei
## bleibt - knapp, damit kein großer Leerraum entsteht.
const STAGE_FRACTION := 0.15
## Kantenlänge einer Kachel/eines Seiten-Chips (Breiteneinheiten u) - gilt für
## Seiten-Übersicht UND Würfel-Raster, eine Änderung skaliert beide.
const TRAY_TILE := 8.91

## Der laufende Spiellauf (setzt scene_root) - Sigil-Bestand und -Verbrauch.
var run: GameRun

var current_def: DieDefinition = null
var selected_face: int = -1  # gewählte physische Seite (0..5), -1 = keine
## True, wenn statt einer Seite der KANTEN-Rahmen gewählt ist (Ziel der
## Kanten-Sigille); schließt selected_face aus.
var edges_selected: bool = false
var mode: int = Mode.SELECT
var active_sigil_id: String = ""  # Sigil des laufenden Zweitschritts

## Breiteneinheit (size.x / 100), in _build_layout gesetzt.
var u := 8.0

# Gerüst-Referenzen (je show_die frisch gebaut).
var prompt_label: Label
var board_box: VBoxContainer  # Gravur-Bord
var value_row: GridContainer  # Feingravur-Wertauswahl
var slot_entries: Array[Dictionary] = []  # [{button:Button, id:String, count:int}]
var summary_list: VBoxContainer  # Seiten-Raster + Kanten-Chip + Augensumme
var summary_sum_label: Label

## Handgesteuerter Tooltip der Chips/Slots: Godots eingebautes Tooltip-System
## feuert im Tisch-SubViewport nicht zuverlässig - gesteuert über
## mouse_entered/mouse_exited (die Maus-Weiterleitung liefert Motion).
var face_tooltip: PanelContainer
var face_tooltip_title: Label
var face_tooltip_body: Label
## Würfel-Raster rechts: spiegelt das Ursprungs-Tray (Buchreihenfolge, leere
## Slots als leere Zellen); Klick meldet den ECHTEN Slot-Index. Der Kontext
## kommt von scene_root und übersteht den Neuaufbau des Gerüsts.
var tray_grid: GridContainer
var tray_context_defs: Array[DieDefinition] = []  # je ECHTEM Slot (null = leer)
var tray_context_current: int = -1
var tray_context_rows: int = 0
var tray_context_columns: int = 0

## Die Bühne: leere Landefläche, über der der ECHTE Würfel schwebt; ihre Mitte
## ist Landeziel und Endpunkt der Absorptions-Bahn.
var stage: Control
## Drehbare 3D-Projektion rechts neben der Bühne: Ziehen dreht, Klick auf
## Seite/Kanten wählt (gleiche Handler wie die Chips).
var die_view: RotatableDieView
var die_view_panel: PanelContainer

## Öffnet die Station für def (die echte Pool-Instanz) und setzt den Zustand
## zurück; baut Gerüst und Bord frisch.
func show_die(def: DieDefinition) -> void:
	# Gerüst + Bord nur beim frischen Öffnen bauen. Beim Ziel-Wechsel bleiben
	# beide stehen (sie hängen am Lauf, nicht am Würfel) - der Bord-Aufbau
	# kostet ~17 ms und verursachte den Ruckler bei jeder Neu-Auswahl.
	var fresh_open := not visible or board_box == null or not is_instance_valid(board_box)
	current_def = def
	selected_face = -1
	edges_selected = false
	mode = Mode.SELECT
	active_sigil_id = ""
	if fresh_open:
		_build_layout()
		_build_sigil_board()
	else:
		_refresh_sigil_enabled()
	die_view.set_dice([current_def] as Array[DieDefinition])
	_refresh_face_summary()
	_update_prompt()
	visible = true

func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

# --- Gerüst (Neon-Panel) -------------------------------------------------------

func _build_layout() -> void:
	for child in get_children():
		child.queue_free()
	u = maxf(size.x, 640.0) / 100.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true  # nichts ragt über den Hub-Rahmen hinaus

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(u * 3.0))
	margin.add_theme_constant_override("margin_right", int(u * 3.0))
	margin.add_theme_constant_override("margin_top", int(u * 1.2))
	margin.add_theme_constant_override("margin_bottom", int(u * 2.0))
	add_child(margin)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.add_theme_constant_override("separation", int(u * 1.2))
	margin.add_child(root)

	_build_header(root)
	_build_top_row(root)
	_build_prompt(root)
	_build_board(root)
	_build_value_row(root)

	_rebuild_tray_grid()  # aus dem gespeicherten Kontext
	_build_face_tooltip()  # zuletzt: liegt als Overlay über allem

func _build_header(root: Control) -> void:
	var header := HBoxContainer.new()
	header.name = "Header"
	root.add_child(header)
	var title := _label("GRAVUR", u * 4.5, NEON_MAGENTA)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var done := _neon_button("Fertig", NEON_GOLD, u * 3.0, Vector2(u * 18.0, u * 5.0))
	done.pressed.connect(close)
	header.add_child(done)

## Obere Reihe: links Seiten-Übersicht über der Bühne (+ Projektion daneben),
## rechts das Würfel-Raster; ein dehnbarer Platzhalter drückt beide an die Ränder.
func _build_top_row(root: Control) -> void:
	var top_row := HBoxContainer.new()
	top_row.name = "TopRow"
	top_row.add_theme_constant_override("separation", 0)
	top_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(top_row)

	var left_col := VBoxContainer.new()
	left_col.name = "LeftColumn"
	left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", int(u * 1.2))
	top_row.add_child(left_col)

	summary_list = VBoxContainer.new()
	summary_list.name = "FaceSummary"
	summary_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	summary_list.add_theme_constant_override("separation", int(u * 0.8))
	left_col.add_child(summary_list)

	var stage_row := HBoxContainer.new()
	stage_row.name = "StageRow"
	stage_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_row.add_theme_constant_override("separation", int(u * 2.5))
	left_col.add_child(stage_row)

	stage = CenterContainer.new()
	stage.name = "Stage"
	stage.custom_minimum_size = Vector2(u * 12.0, size.y * STAGE_FRACTION)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_row.add_child(stage)

	_build_die_view(stage_row)

	top_row.add_child(_expanding_spacer())

	tray_grid = GridContainer.new()
	tray_grid.name = "TrayGrid"
	tray_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tray_grid.add_theme_constant_override("h_separation", int(u * 0.6))
	tray_grid.add_theme_constant_override("v_separation", int(u * 0.6))
	top_row.add_child(tray_grid)

func _build_prompt(root: Control) -> void:
	prompt_label = _label("", u * 2.2, NEON_TEXT)
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.custom_minimum_size = Vector2(0, u * 5.5)
	root.add_child(prompt_label)

func _build_board(root: Control) -> void:
	board_box = VBoxContainer.new()
	board_box.name = "Board"
	board_box.add_theme_constant_override("separation", int(u * 0.8))
	board_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(board_box)

## Feingravur-Wertreihe (1..FINE_ENGRAVING_MAX), erst bei Bedarf sichtbar.
func _build_value_row(root: Control) -> void:
	value_row = GridContainer.new()
	value_row.name = "ValueRow"
	value_row.columns = 6
	value_row.add_theme_constant_override("h_separation", int(u * 0.6))
	value_row.add_theme_constant_override("v_separation", int(u * 0.6))
	value_row.visible = false
	for value in range(1, EtchingEffects.FINE_ENGRAVING_MAX + 1):
		var value_button := _neon_button(str(value), NEON_MAGENTA, u * 2.4, Vector2(0, u * 4.4))
		value_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_button.pressed.connect(_on_value_pressed.bind(value))
		value_row.add_child(value_button)
	root.add_child(value_row)

func _expanding_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

## Baut die drehbare 3D-Projektion samt Unter-Bildschirm. Der SubViewport
## kommt per Code (eigene World3D, sonst filmt die Kamera die Tischszene).
func _build_die_view(parent: Control) -> void:
	die_view_panel = PanelContainer.new()
	die_view_panel.name = "DieViewScreen"
	var style := StyleBoxFlat.new()
	style.bg_color = DIE_VIEW_BG
	style.border_color = NEON_CYAN
	style.set_border_width_all(maxi(2, int(u * 0.3)))
	style.set_corner_radius_all(int(u * 1.2))
	style.set_content_margin_all(int(u * 0.8))
	die_view_panel.add_theme_stylebox_override("panel", style)
	die_view_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(die_view_panel)

	die_view = RotatableDieView.new()
	die_view.name = "DieView"
	var sub := SubViewport.new()
	sub.name = "SubViewport"
	sub.transparent_bg = true
	sub.own_world_3d = true
	die_view.add_child(sub)
	die_view.stretch = true  # Container-Pixel == Viewport-Pixel (Pick-Mathe)
	die_view.custom_minimum_size = Vector2(u * 20.0, u * 16.0)
	die_view.pick_radius = u * 10.0
	die_view.face_clicked.connect(_on_face_clicked)
	die_view.edges_clicked.connect(_on_edges_clicked)
	die_view.drag_started.connect(func() -> void: rotating_die.emit(true))
	die_view.drag_ended.connect(func() -> void: rotating_die.emit(false))
	die_view_panel.add_child(die_view)

## Spiegelt Zustand und Auswahl in die 3D-Projektion (Seitenwerte + Highlight).
func _sync_die_view() -> void:
	if current_def == null:
		return
	selection_changed.emit(selected_face, edges_selected)
	if die_view == null:
		return
	die_view.refresh_faces([current_def] as Array[DieDefinition])
	if edges_selected:
		die_view.highlight_edges(0)
	else:
		die_view.highlight_face(0, selected_face)

# --- Bühne ----------------------------------------------------------------------

## Bühnen-Mitte in Display-Pixeln (Landeziel/Endpunkt der Absorptions-Bahn);
## Panel-Mitte als Rückfall.
func stage_center_px() -> Vector2:
	if stage != null and is_instance_valid(stage):
		return stage.get_global_rect().get_center()
	return get_global_rect().get_center()

# --- Würfel-Raster (Umwählen) ----------------------------------------------------

## Übernimmt das Raster des Ursprungs-Trays (je ECHTEM Slot eine Def, null =
## leer) und welcher Slot gerade bearbeitet wird.
func set_tray_grid(rows: int, columns: int, defs: Array[DieDefinition], current_slot: int) -> void:
	tray_context_rows = rows
	tray_context_columns = columns
	tray_context_defs = defs
	tray_context_current = current_slot
	_rebuild_tray_grid()

func _rebuild_tray_grid() -> void:
	if tray_grid == null:
		return
	for child in tray_grid.get_children():
		child.queue_free()
	tray_grid.columns = maxi(tray_context_columns, 1)
	for i in tray_context_defs.size():
		var def: DieDefinition = tray_context_defs[i]
		if def == null:
			tray_grid.add_child(_empty_tray_cell())
		else:
			tray_grid.add_child(_tray_tile(def, i == tray_context_current, i))

## Würfel-Kachel: Augensumme über einem 3×2-Raster der Seiten (in Material-
## farbe); der Kachel-Rahmen trägt die Farbe des Kanten-Materials, gold beim
## gerade bearbeiteten Würfel. Klick meldet den Slot-Index.
func _tray_tile(def: DieDefinition, highlighted: bool, slot: int) -> Button:
	var tile := Button.new()
	tile.focus_mode = Control.FOCUS_NONE
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.custom_minimum_size = Vector2(u * TRAY_TILE, u * TRAY_TILE)
	var total := 0
	var values: Array[int] = []
	for v in def.faces:
		total += v
		values.append(v)
	values.sort()
	var value_text := ""
	for v in values:
		value_text += ("%d " % v)
	value_text = value_text.strip_edges()
	tile.tooltip_text = "Augensumme %d\nSeiten: %s" % [total, value_text]
	tile.pressed.connect(func() -> void: select_tray_die.emit(slot))

	var edge_tint := DieMaterial.tint_for(def.edge_material)
	var border := NEON_GOLD if highlighted else edge_tint
	var bg := Color("#2c2757dd") if highlighted else Color("#221e46cc")
	tile.add_theme_stylebox_override("normal", _tile_box(bg, border))
	tile.add_theme_stylebox_override("hover", _tile_box(Color("#2c2757dd"), NEON_GOLD))
	tile.add_theme_stylebox_override("pressed", _tile_box(Color("#3a2f66"), NEON_GOLD))
	tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", maxi(1, int(u * 0.3)))
	tile.add_child(box)
	var sum_label := _label(str(total), u * 2.08, NEON_GOLD if highlighted else NEON_TEXT)
	sum_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sum_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(sum_label)
	box.add_child(_tray_face_grid(def))
	return tile

func _tray_face_grid(def: DieDefinition) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", maxi(1, int(u * 0.25)))
	grid.add_theme_constant_override("v_separation", maxi(1, int(u * 0.25)))
	for face_index in _faces_sorted_by_value(def):
		grid.add_child(_tray_face_cell(def.faces[face_index], _material_of(def, face_index)))
	return grid

## Seiten-Indizes nach Augenzahl aufsteigend (bei Gleichstand nach Index) -
## Raster und Kacheln lesen wie "1-6", jede Kachel bleibt ihre EIGENE Seite.
func _faces_sorted_by_value(def: DieDefinition) -> Array[int]:
	var order: Array[int] = []
	for i in def.faces.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if def.faces[a] != def.faces[b]:
			return def.faces[a] < def.faces[b]
		return a < b)
	return order

func _material_of(def: DieDefinition, face_index: int) -> String:
	return def.materials[face_index] if face_index < def.materials.size() else ""

func _tray_face_cell(value: int, material_id: String) -> Control:
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2.ONE * u * 2.1
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = DieMaterial.tint_for(material_id)
	box.border_color = Color(0, 0, 0, 0.35)
	box.set_border_width_all(maxi(1, int(u * 0.1)))
	box.set_corner_radius_all(maxi(1, int(u * 0.3)))
	cell.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = str(value)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", maxi(8, int(u * 1.54)))
	label.add_theme_color_override("font_color", CasinoStyle.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(label)
	return cell

## Leerer Slot: stiller Platzhalter, damit das Raster die Tray-Lücken spiegelt.
func _empty_tray_cell() -> Control:
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(u * TRAY_TILE, u * TRAY_TILE)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#181534aa")
	box.border_color = Color("#282350")
	box.set_border_width_all(maxi(1, int(u * 0.15)))
	box.set_corner_radius_all(int(u * 0.9))
	cell.add_theme_stylebox_override("panel", box)
	return cell

func _tile_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.33)))
	box.set_corner_radius_all(int(u * 0.9))
	return box

# --- Seiten-Auswahl / Ätzungs-Anwendung ------------------------------------------

## Wählt eine Seite - oder liefert die zweite Seite einer laufenden Ätzung.
func _on_face_clicked(_die_index: int, face_index: int) -> void:
	if mode == Mode.AWAIT_SECOND_FACE:
		_complete_two_step(face_index)
		return
	# Neue Auswahl - bricht eine offene Wertauswahl (Feingravur) mit ab.
	selected_face = face_index
	edges_selected = false
	_refresh_after_selection()

## Wählt die Kanten als Gravur-Ziel; im Zweitschritt sind sie kein Ziel.
func _on_edges_clicked(_die_index: int = 0) -> void:
	if mode == Mode.AWAIT_SECOND_FACE:
		prompt_label.text = "Bitte eine SEITE anklicken - Kanten sind hier kein Ziel."
		return
	edges_selected = true
	selected_face = -1
	_refresh_after_selection()

## Gemeinsamer Nachlauf nach neuer Ziel-Auswahl: Grundmodus, offene
## Wertauswahl schließen, Anzeige/Sperren anpassen.
func _refresh_after_selection() -> void:
	mode = Mode.SELECT
	active_sigil_id = ""
	_hide_value_picker()
	_refresh_face_summary()
	_update_prompt()
	_refresh_sigil_enabled()

## Klick auf einen Seiten-Chip. Im Zweitschritt wird möglichst eine ANDERE
## Seite desselben Werts genommen, damit gleiche Werte nicht auf sich selbst verweisen.
func _on_chip_clicked(value: int, face_index: int) -> void:
	if current_def == null:
		return
	if mode == Mode.AWAIT_SECOND_FACE:
		var second := _face_index_for_value(value, selected_face)
		if second != -1:
			_on_face_clicked(0, second)
		return
	_on_face_clicked(0, face_index)

## Index einer Seite mit dem Wert, möglichst ungleich exclude; -1, wenn der
## Wert nicht vorkommt.
func _face_index_for_value(value: int, exclude: int) -> int:
	var fallback := -1
	for i in current_def.faces.size():
		if current_def.faces[i] == value:
			if i != exclude:
				return i
			fallback = i
	return fallback

## Verteilt einen Sigil-Klick nach Art: Kanten-Sigille brauchen den
## Kanten-Chip, Material-/Ätzungs-Sigille eine gewählte Seite. Nur im
## Grundmodus - im Zweitschritt ist das Bord gesperrt.
func _on_sigil_pressed(sigil_id: String) -> void:
	if mode != Mode.SELECT:
		return
	if Sigil.is_edge_id(sigil_id):
		_apply_edge_sigil(sigil_id)
	elif selected_face == -1:
		return
	elif DieMaterial.is_valid_id(sigil_id):
		_apply_material_sigil(sigil_id)
	else:
		_apply_number_sigil(sigil_id)

## Setzt das Kanten-Material (ein neues ersetzt ein vorhandenes).
func _apply_edge_sigil(sigil_id: String) -> void:
	if not edges_selected:
		return
	var material_id := sigil_id.trim_prefix(Sigil.EDGE_PREFIX)
	if current_def.edge_material == material_id:
		prompt_label.text = "Die Kanten tragen bereits %s." % DieMaterial.by_id(material_id).display_name
		return
	current_def.edge_material = material_id
	_finish_apply(sigil_id, "Kanten veredelt: %s" % DieMaterial.by_id(material_id).display_name)

## Belegt die gewählte Seite; ein neues Material ersetzt ein vorhandenes.
func _apply_material_sigil(sigil_id: String) -> void:
	if current_def.materials[selected_face] == sigil_id:
		prompt_label.text = "Diese Seite trägt bereits %s." % DieMaterial.by_id(sigil_id).display_name
		return
	current_def.materials[selected_face] = sigil_id
	_finish_apply(sigil_id, "Material angebracht: %s" % DieMaterial.by_id(sigil_id).display_name)

## Einstufige Ätzungen wirken sofort; mehrstufige gehen in den Wart-Modus.
func _apply_number_sigil(sigil_id: String) -> void:
	match sigil_id:
		Sigil.OVERCOUNT_ENGRAVING:
			EtchingEffects.overcount_engraving(current_def, selected_face)
			_finish_apply(sigil_id, "Überzahl-Gravur: Seite +1")
		Sigil.FINE_ENGRAVING:
			_begin_value_pick(sigil_id)
		Sigil.CHISEL:
			_await_second_face(sigil_id, "Meißel: klicke die Quellseite (ihr Wert wird auf die gewählte Seite kopiert).")
		Sigil.GRINDSTONE:
			_await_second_face(sigil_id, "Schleifstein: gewählte Seite bekommt +1 – klicke jetzt die Seite für −1.")
		Sigil.FILE_DOWN:
			if not EtchingEffects.can_file_down(current_def, selected_face):
				prompt_label.text = "Feile: diese Seite ist schon 1."
				return
			EtchingEffects.file_down(current_def, selected_face)
			_finish_apply(sigil_id, "Feile: Seite −1")
		Sigil.DOUBLE_NOTCH:
			_await_second_face(sigil_id, "Doppelkerbe: gewählte Seite +1 – klicke die zweite Seite (auch +1).")
		Sigil.AVERAGING:
			_await_second_face(sigil_id, "Mittelung: klicke die zweite Seite – beide werden ihr aufgerundeter Mittelwert.")
		Sigil.MIRROR:
			EtchingEffects.mirror_die(current_def)
			_finish_apply(sigil_id, "Spiegelung: Würfel invertiert")
		Sigil.STRAIGHTEN:
			EtchingEffects.straighten(current_def)
			_finish_apply(sigil_id, "Begradigung: ungerade Seiten +1")
		Sigil.TRANSPLANT:
			if not EtchingEffects.can_transplant(current_def, selected_face):
				prompt_label.text = "Transplantat: diese Seite ist schon der Höchstwert."
				return
			EtchingEffects.transplant(current_def, selected_face)
			_finish_apply(sigil_id, "Transplantat: Seite auf Höchstwert gehoben")
		Sigil.CONNECT_UP:
			_await_second_face(sigil_id, "Anschluss: klicke die Quellseite – die gewählte Seite wird ihr Wert + 1.")
		Sigil.IMPRINT:
			EtchingEffects.imprint(current_def, selected_face)
			_finish_apply(sigil_id, "Abdruck: auf die zwei niedrigsten Seiten geprägt")
		Sigil.BLUEPRINT:
			EtchingEffects.blueprint(current_def, selected_face)
			_finish_apply(sigil_id, "Blaupause: ganzer Würfel auf den gewählten Wert gesetzt")

func _await_second_face(sigil_id: String, prompt: String) -> void:
	mode = Mode.AWAIT_SECOND_FACE
	active_sigil_id = sigil_id
	prompt_label.text = prompt
	_refresh_sigil_enabled()

func _begin_value_pick(sigil_id: String) -> void:
	mode = Mode.PICK_VALUE
	active_sigil_id = sigil_id
	_show_value_picker()
	prompt_label.text = "Feingravur: Zielwert 1–12 wählen."
	_refresh_sigil_enabled()

func _on_value_pressed(value: int) -> void:
	if mode != Mode.PICK_VALUE or selected_face == -1:
		return
	EtchingEffects.fine_engraving(current_def, selected_face, value)
	_hide_value_picker()
	_finish_apply(Sigil.FINE_ENGRAVING, "Feingravur: Seite = %d" % value)

## Schließt eine mehrschrittige Ätzung mit der zweiten Seite ab.
func _complete_two_step(second_face: int) -> void:
	if second_face == selected_face:
		prompt_label.text = "Bitte eine ANDERE Seite als die gewählte anklicken."
		return
	match active_sigil_id:
		Sigil.CHISEL:
			EtchingEffects.chisel(current_def, second_face, selected_face)  # Quelle=zweite, Ziel=gewählte
			_finish_apply(active_sigil_id, "Meißel: Seite kopiert")
		Sigil.GRINDSTONE:
			if not EtchingEffects.can_grindstone_minus(current_def, second_face):
				prompt_label.text = "Diese Seite ist schon 1 – wähle eine andere für −1."
				return  # Wart-Modus bleibt, Sigil noch nicht verbraucht
			EtchingEffects.grindstone(current_def, second_face, selected_face)  # −1=zweite, +1=gewählte
			_finish_apply(active_sigil_id, "Schleifstein: +1 / −1 angewandt")
		Sigil.DOUBLE_NOTCH:
			EtchingEffects.double_notch(current_def, selected_face, second_face)
			_finish_apply(active_sigil_id, "Doppelkerbe: zwei Seiten +1")
		Sigil.AVERAGING:
			EtchingEffects.averaging(current_def, selected_face, second_face)
			_finish_apply(active_sigil_id, "Mittelung: zwei Seiten gemittelt")
		Sigil.CONNECT_UP:
			EtchingEffects.connect_up(current_def, second_face, selected_face)  # Quelle=zweite, Ziel=gewählte
			_finish_apply(active_sigil_id, "Anschluss: gewählte Seite = Quellwert + 1")

## Verbraucht den Sigil, aktualisiert die Anzeige und meldet changed/applied.
## Die gewählte Seite bleibt gewählt (direkt weitergravieren).
func _finish_apply(sigil_id: String, message: String) -> void:
	if run != null:
		# Gravierstift: einmal pro Runde wird eine ÄTZUNG nicht verbraucht.
		var is_etching := not DieMaterial.is_valid_id(sigil_id) and not Sigil.is_edge_id(sigil_id)
		if is_etching and CharmEffects.has_engraving_pen(run.charm_ids()) and not run.gravierstift_used_this_round:
			run.gravierstift_used_this_round = true
			message += " Gravierstift: Sigil nicht verbraucht!"
		else:
			run.consume_sigil(sigil_id)
	mode = Mode.SELECT
	active_sigil_id = ""
	changed.emit()
	applied.emit(sigil_id, _slot_center_px(sigil_id))
	_build_sigil_board()  # Anzahl hat sich geändert
	_refresh_face_summary()
	_rebuild_tray_grid()  # Augensumme kann sich geändert haben
	prompt_label.text = "%s. Weiter gravieren oder Rechtsklick zum Schließen." % message

## Display-Pixel der Bord-Kachel eines Sigille (Quelle der Absorptions-Bahn);
## Panel-Mitte als Rückfall.
func _slot_center_px(sigil_id: String) -> Vector2:
	for entry in slot_entries:
		if entry["id"] == sigil_id and is_instance_valid(entry["button"]):
			return (entry["button"] as Control).get_global_rect().get_center()
	return get_global_rect().get_center()

## Bricht einen laufenden Zweitschritt/eine Wertauswahl ab (Rechtsklick,
## siehe scene_root).
func cancel_pending() -> void:
	mode = Mode.SELECT
	active_sigil_id = ""
	_hide_value_picker()
	_update_prompt()
	_refresh_sigil_enabled()

func _update_prompt() -> void:
	if edges_selected:
		prompt_label.text = "Kanten gewählt. Wähle ein Kanten-Material."
	elif selected_face == -1:
		prompt_label.text = ""
	else:
		prompt_label.text = "Seite gewählt (Wert %d). Wähle eine Ätzung." % current_def.faces[selected_face]

# --- Seiten-Übersicht -------------------------------------------------------------

## Baut die Seiten-Übersicht neu: je physischer Seite ein Chip (Wert +
## Material-Tönung) im 3×2-Raster, nach Wert sortiert; darunter Kanten-Chip
## und Augensumme. Klick wählt genau diese Seite.
func _refresh_face_summary() -> void:
	if summary_list == null:
		return
	_hide_face_tooltip()  # die alten Chips (mit Hover-Verbindungen) fallen weg
	for child in summary_list.get_children():
		child.queue_free()
	if current_def == null:
		return

	var face_grid := GridContainer.new()
	face_grid.columns = 3
	face_grid.add_theme_constant_override("h_separation", int(u * 0.8))
	face_grid.add_theme_constant_override("v_separation", int(u * 0.8))
	summary_list.add_child(face_grid)
	var total := 0
	for face_index in _faces_sorted_by_value(current_def):
		var value: int = current_def.faces[face_index]
		total += value
		face_grid.add_child(_face_chip(value, _material_of(current_def, face_index), \
			selected_face == face_index, face_index))

	var edge_group := HBoxContainer.new()
	edge_group.add_theme_constant_override("separation", int(u * 0.4))
	edge_group.add_child(_edge_chip(edges_selected))
	var edge_label := _label(DieMaterial.by_id(current_def.edge_material).display_name \
		if DieMaterial.is_valid_id(current_def.edge_material) else "ohne", u * 2.0, NEON_MUTED)
	edge_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	edge_group.add_child(edge_label)
	summary_list.add_child(edge_group)

	summary_sum_label = _label("Augensumme: %d" % total, u * 2.2, NEON_MUTED)
	summary_list.add_child(summary_sum_label)

	_sync_die_view()

## Anklickbarer Seiten-Chip im Look der echten Würfel; highlighted = violetter
## Auswahl-Look. Material-Tooltip handgesteuert (siehe face_tooltip).
func _face_chip(value: int, material_id: String, highlighted: bool, face_index: int) -> Button:
	var chip := Button.new()
	chip.text = str(value)
	chip.custom_minimum_size = Vector2.ONE * u * TRAY_TILE
	chip.add_theme_font_size_override("font_size", int(u * TRAY_TILE * 0.5))
	_style_chip(chip, DieMaterial.tint_for(material_id), highlighted)
	if DieMaterial.is_valid_id(material_id):
		var material := DieMaterial.by_id(material_id)
		chip.mouse_entered.connect(_show_face_tooltip.bind(chip, material.display_name, material.description))
		chip.mouse_exited.connect(_hide_face_tooltip)
	chip.pressed.connect(_on_chip_clicked.bind(value, face_index))
	return chip

## Der "Kanten"-Chip: gefüllt mit dem Tint des Kanten-Materials, hervorgehoben,
## wenn die Kanten das Gravur-Ziel sind.
func _edge_chip(highlighted: bool) -> Button:
	var chip := Button.new()
	chip.text = "Kanten"
	chip.custom_minimum_size = Vector2(u * TRAY_TILE * 1.7, u * TRAY_TILE)
	chip.add_theme_font_size_override("font_size", int(u * TRAY_TILE * 0.34))
	var material_tint := DieMaterial.tint_for(current_def.edge_material)
	var base := material_tint if material_tint != Color.WHITE else DieFaceDisplay.EDGE_COLOR
	_style_chip(chip, base, highlighted)
	if DieMaterial.is_valid_id(current_def.edge_material):
		var edge := DieMaterial.by_id(current_def.edge_material)
		chip.mouse_entered.connect(_show_face_tooltip.bind(chip, edge.display_name, edge.edge_description))
		chip.mouse_exited.connect(_hide_face_tooltip)
	chip.pressed.connect(_on_edges_clicked)
	return chip

## Gemeinsamer Chip-Look: Füllung bleibt die Material-/Kantenfarbe; gewählt
## leuchten Ziffer + Rahmen in der Auswahl-Farbe (mit dunklem Umriss, damit
## das Violett auf hellen Seiten lesbar bleibt).
func _style_chip(chip: Button, base_fill: Color, highlighted: bool) -> void:
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var font_color := RotatableDieView.SELECT_FACE_COLOR if highlighted else CasinoStyle.INK
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		chip.add_theme_color_override(state, font_color)
	chip.add_theme_color_override("font_outline_color", CasinoStyle.INK)
	chip.add_theme_constant_override("outline_size", int(u * 0.45) if highlighted else 0)
	var border := RotatableDieView.SELECT_FACE_COLOR if highlighted else CHIP_BORDER
	var border_width := int(u * 0.6) if highlighted else maxi(2, int(u * 0.2))
	chip.add_theme_stylebox_override("normal", _chip_box(base_fill, border, border_width))
	chip.add_theme_stylebox_override("hover", _chip_box(base_fill.lightened(0.12), border, border_width))
	chip.add_theme_stylebox_override("pressed", _chip_box(base_fill.darkened(0.1), border, border_width))
	chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _chip_box(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(maxi(1, border_width))
	box.set_corner_radius_all(int(u * 1.0))
	return box

# --- Gravur-Bord -------------------------------------------------------------------

## Baut das Bord neu: JEDER Sigil-Archetyp hat seinen festen Platz (nach
## Seltenheit sortiert, getrennt nach Ätzungen/Materialien/Kanten). Besitz
## liegt als Sigil-Stapel darauf, nicht Besessenes als Schatten.
func _build_sigil_board() -> void:
	if board_box == null:
		return
	_hide_face_tooltip()  # die alten Slots (mit Hover-Verbindungen) fallen weg
	slot_entries.clear()
	for child in board_box.get_children():
		child.queue_free()

	var counts := _sigil_counts()
	var etchings: Array[Sigil] = []
	var materials: Array[Sigil] = []
	var edges: Array[Sigil] = []
	for archetype in Sigil.all():
		match archetype.category:
			Sigil.CATEGORY_NUMBER:
				etchings.append(archetype)
			Sigil.CATEGORY_MATERIAL:
				materials.append(archetype)
			Sigil.CATEGORY_DICE:
				edges.append(archetype)
			_:
				pass  # Menü-Sigille wirken sofort und liegen nie im Bestand
	_add_board_section("Zahlen", _sorted_by_rarity(etchings), counts)
	_add_board_section("Materialien", _sorted_by_rarity(materials), counts)
	_add_board_section("Würfel", _sorted_by_rarity(edges), counts)
	_refresh_sigil_enabled()

## Nach Seltenheit sortiert; innerhalb einer Seltenheit bleibt die kanonische
## Reihenfolge, damit die Plätze stabil liegen.
func _sorted_by_rarity(archetypes: Array[Sigil]) -> Array[Sigil]:
	var sorted: Array[Sigil] = []
	for rarity in [Sigil.Rarity.COMMON, Sigil.Rarity.UNCOMMON, Sigil.Rarity.RARE]:
		for archetype in archetypes:
			if archetype.rarity == rarity:
				sorted.append(archetype)
	return sorted

func _add_board_section(title: String, archetypes: Array[Sigil], counts: Dictionary) -> void:
	var header := _label(title, u * 2.0, NEON_CYAN)
	board_box.add_child(header)

	var grid := GridContainer.new()
	grid.columns = SLOT_COLUMNS
	grid.add_theme_constant_override("h_separation", int(u * 0.6))
	grid.add_theme_constant_override("v_separation", int(u * 0.6))
	board_box.add_child(grid)

	for archetype in archetypes:
		var count: int = counts.get(archetype.id, 0)
		var slot := _sigil_slot(archetype, count)
		grid.add_child(slot)
		slot_entries.append({"button": slot, "id": archetype.id, "count": count})

func _tile_size() -> Vector2:
	return Vector2(u * 6.0, u * 5.0)

## Ein Bord-Platz: Button als "Mulde", darin der Sigil als Kachel - bei
## Mehrfachbesitz als versetzter Stapel plus ×Anzahl; ohne Besitz nur der
## ausgegraute Schatten. Klick = anwenden.
func _sigil_slot(archetype: Sigil, count: int) -> Button:
	var slot := Button.new()
	var pad := u * 0.35
	var stack_offset := Vector2.ONE * u * 0.4
	var stack_margin := stack_offset * float(STACK_MAX_VISIBLE - 1)
	slot.custom_minimum_size = _tile_size() + Vector2.ONE * (pad * 2.0) + stack_margin
	slot.focus_mode = Control.FOCUS_NONE
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.mouse_entered.connect(_show_face_tooltip.bind(slot, archetype.display_name, archetype.description))
	slot.mouse_exited.connect(_hide_face_tooltip)
	slot.pressed.connect(_on_sigil_pressed.bind(archetype.id))
	slot.add_theme_stylebox_override("normal", _slot_box(Color(0.545, 0.914, 0.992, 0.35)))
	slot.add_theme_stylebox_override("hover", _slot_box(NEON_GOLD))
	slot.add_theme_stylebox_override("pressed", _slot_box(NEON_GOLD.darkened(0.25)))
	slot.add_theme_stylebox_override("disabled", _slot_box(Color(1, 1, 1, 0.08)))
	slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# Stapel von hinten nach vorn (tiefere Exemplare zuerst).
	var depth: int = clampi(count, 1, STACK_MAX_VISIBLE)
	for i in range(depth - 1, -1, -1):
		var tile := _sigil_tile(archetype, count > 0)
		tile.position = Vector2.ONE * pad + stack_offset * float(i)
		tile.size = _tile_size()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if count > 0 and i > 0:
			tile.modulate = Color(0.78, 0.78, 0.78)
		slot.add_child(tile)

	if count > 1:
		var badge := Label.new()
		badge.text = "×%d" % count
		badge.position = Vector2(pad + _tile_size().x - u * 3.0, pad + _tile_size().y - u * 2.0)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_font_size_override("font_size", int(u * 1.6))
		badge.add_theme_color_override("font_color", NEON_GOLD)
		var badge_box := StyleBoxFlat.new()
		badge_box.bg_color = Color(0, 0, 0, 0.72)
		badge_box.set_corner_radius_all(int(u * 0.6))
		badge_box.set_content_margin_all(int(u * 0.3))
		badge.add_theme_stylebox_override("normal", badge_box)
		slot.add_child(badge)
	return slot

## Sigil-Kachel: prozedurales Lichtgravur-Siegel; owned = besessen (sonst
## unbeleuchtete Gravur-Rille als "noch nicht bekommen").
func _sigil_tile(archetype: Sigil, owned: bool) -> Control:
	var sigil := SigilRenderer.for_sigil(archetype)
	sigil.owned = owned
	return sigil

func _slot_box(border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.28)
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(int(u * 0.7))
	return box

## Sigil-Bestand nach id (id -> Anzahl). Testmodus: jeder Archetyp gilt als
## im Bestand und wird nicht verbraucht.
func _sigil_counts() -> Dictionary:
	var counts := {}
	if run == null:
		return counts
	if run.unlimited_sigils:
		for archetype in Sigil.all():
			counts[archetype.id] = 1
		return counts
	for sigil in run.owned_sigils:
		counts[sigil.id] = counts.get(sigil.id, 0) + 1
	return counts

## Sperrt Bord-Slots ohne passendes Ziel, während eines Zweitschritts oder
## bei leerem Platz.
func _refresh_sigil_enabled() -> void:
	for entry in slot_entries:
		var is_edge: bool = Sigil.is_edge_id(entry["id"])
		var has_target: bool = edges_selected if is_edge else selected_face != -1
		entry["button"].disabled = entry["count"] == 0 or mode != Mode.SELECT or not has_target

func _show_value_picker() -> void:
	value_row.visible = true

func _hide_value_picker() -> void:
	if value_row != null:
		value_row.visible = false

# --- Neon-Bausteine ----------------------------------------------------------------

func _label(text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _neon_button(text: String, accent: Color, font_size: float, min_size: Vector2 = Vector2.ZERO) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	button.add_theme_color_override("font_color", NEON_TEXT)
	button.add_theme_color_override("font_hover_color", NEON_GOLD)
	button.add_theme_color_override("font_pressed_color", NEON_GOLD)
	button.add_theme_color_override("font_disabled_color", Color(NEON_MUTED.r, NEON_MUTED.g, NEON_MUTED.b, 0.45))
	button.add_theme_stylebox_override("normal", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("hover", _button_box(Color("#2c2757dd"), NEON_GOLD))
	button.add_theme_stylebox_override("pressed", _button_box(Color("#3a2f66"), NEON_GOLD))
	button.add_theme_stylebox_override("focus", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("disabled", _button_box(Color("#1a183666"), Color(accent.r, accent.g, accent.b, 0.25)))
	return button

func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.22)))
	box.set_corner_radius_all(int(u * 0.9))
	box.set_content_margin_all(int(u * 0.8))
	return box

# --- Tooltip-Overlay ----------------------------------------------------------------

## Baut das (verborgene) Tooltip-Overlay im Charm-Look, u-skaliert für das
## hochaufgelöste Display; liegt als letztes Kind über allem im Panel.
func _build_face_tooltip() -> void:
	face_tooltip = PanelContainer.new()
	face_tooltip.name = "FaceTooltip"
	face_tooltip.visible = false
	face_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_panel(face_tooltip)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", int(u * 0.4))
	face_tooltip.add_child(box)
	face_tooltip_title = Label.new()
	face_tooltip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_score_label(face_tooltip_title, int(u * 2.6), CasinoStyle.GOLD)
	box.add_child(face_tooltip_title)
	face_tooltip_body = Label.new()
	face_tooltip_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	face_tooltip_body.custom_minimum_size = Vector2(u * 26.0, 0)
	CasinoStyle.style_body_label(face_tooltip_body, int(u * 1.9), CasinoStyle.CREAM)
	box.add_child(face_tooltip_body)
	add_child(face_tooltip)

## Zeigt den Tooltip unter (oder notfalls über) dem überfahrenen Element,
## immer im Panel eingeklemmt (clip_contents schneidet Überstände ab).
func _show_face_tooltip(chip: Control, title: String, body: String) -> void:
	if face_tooltip == null:
		return
	face_tooltip_title.text = title
	face_tooltip_body.text = body
	face_tooltip.visible = true
	face_tooltip.reset_size()
	var local := chip.get_global_rect().position - get_global_rect().position
	var below := local.y + chip.size.y + u * 0.6
	var above := local.y - face_tooltip.size.y - u * 0.6
	var pos := Vector2(local.x, below)
	if below + face_tooltip.size.y > size.y - u * 1.0 and above >= u * 1.0:
		pos.y = above  # unten kein Platz -> über das Element klappen
	pos.x = clampf(pos.x, u * 1.0, maxf(u * 1.0, size.x - face_tooltip.size.x - u * 1.0))
	pos.y = clampf(pos.y, u * 1.0, maxf(u * 1.0, size.y - face_tooltip.size.y - u * 1.0))
	face_tooltip.position = pos

func _hide_face_tooltip() -> void:
	if face_tooltip != null:
		face_tooltip.visible = false
