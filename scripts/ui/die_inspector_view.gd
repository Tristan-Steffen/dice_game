class_name DieInspectorView
extends Control
## Die Gravur-Station für einen einzelnen Würfel - seit dem Hub-Umbau ein
## NEON-PANEL auf dem Tisch-Display (siehe HubView.attach_panel): der geklickte
## Würfel wird von scene_root "gegriffen" und schwebt als echter 3D-Würfel über
## der BÜHNEN-Fläche im oberen Teil dieses Panels (siehe scene_root:
## _open_engraving/ENGRAVE_*), während hier darunter die Bedienung liegt.
##
## Der Spieler wählt eine Seite über die SEITEN-CHIPS (oder den Kanten-Chip) und
## klickt danach einen Coupon auf dem Gravur-Bord - beliebig oft, solange er
## Coupons hat. Das Bord zeigt JEDEN Coupon-Archetyp auf seinem festen Platz
## (Reihenfolge = Coupon.all(), nach Seltenheit sortiert): Besitz liegt als
## physischer Coupon darauf (Mehrfache als versetzter Stapel mit ×Anzahl), nicht
## Besessenes ist ausgegraut. Ätzungen, die eine zweite Seite brauchen (Meißel,
## Schleifstein, Doppelkerbe, Mittelung, Anschluss), fragen diese per zweitem
## Chip-Klick ab; die Feingravur fragt den Zielwert über die Wert-Reihe.
##
## Der gezeigte Würfel ist DIESELBE DieDefinition-Instanz wie im Pool (siehe
## scene_root.gd: round_pool_kinds = owned_pool.duplicate() ist eine flache
## Kopie), die Ätzung wirkt also dauerhaft. Nach jeder Anwendung meldet changed
## (Trays neu zeichnen) und applied (Absorptions-Animation des schwebenden
## Würfels, siehe scene_root._on_engraving_applied).
##
## Bedient über die Maus-Weiterleitung in den Tisch-SubViewport (siehe
## scene_root._forward_screen_mouse); Rechtsklick behandelt scene_root (bricht
## erst einen laufenden Zweitschritt ab, dann schließt er die Zeremonie).

## Nach dem Anwenden einer Ätzung ausgelöst - scene_root zeichnet die Trays neu.
signal changed
## Nach dem Anwenden zusätzlich mit Quelle für die Absorptions-Animation:
## coupon_id + Display-Pixel der Bord-Kachel, von der die Kraft ausgeht.
signal applied(coupon_id: String, slot_px: Vector2)
## Der Spieler hat die Station geschlossen (Fertig-Knopf oder Rechtsklick über
## scene_root) - scene_root beendet die Zeremonie (Würfel fliegt zurück).
signal closed
## Eine Zelle des Würfel-Rasters wurde angeklickt (siehe set_tray_grid) -
## scene_root wechselt das Gravur-Ziel auf diesen Würfel (slot = ECHTER Slot-
## Index im Ursprungs-Tray).
signal select_tray_die(slot: int)

## Ablauf-Zustand der Station: normale Seiten-Auswahl, Warten auf die zweite
## Seite (Meißel/Schleifstein/Doppelkerbe/Mittelung/Anschluss) oder Warten auf
## den Zielwert (Feingravur).
enum Mode { SELECT, AWAIT_SECOND_FACE, PICK_VALUE }

## Farben im Display-Stil (siehe HubView/ShopController: 80s Neon).
const NEON_CYAN := Color("#8be9fd")
const NEON_MAGENTA := Color("#ff79c6")
const NEON_GOLD := Color("#ffd319")
const NEON_TEXT := Color(1.35, 1.35, 1.3)
const NEON_MUTED := Color(0.75, 0.78, 0.9)
## Neutraler Rahmen der Seiten-/Kanten-Chips, solange sie nicht gewählt sind.
const CHIP_BORDER := Color(0.72, 0.76, 0.8)

const SLOT_COLUMNS := 8  # Bord-Plätze je Zeile (breites Hub-Panel)
const STACK_MAX_VISIBLE := 3  # mehr Exemplare zeigt nur noch die ×Anzahl
## Ausgegraut-Färbung eines leeren Platzes: der Coupon liegt als dunkelgraue
## Silhouette auf seinem Platz - klar "noch nicht bekommen", aber die Form
## bleibt erkennbar (welcher Coupon hierher gehört, sagt auch der Tooltip).
const EMPTY_SLOT_TINT := Color(0.3, 0.3, 0.34, 0.9)

## Anteil der Panel-Höhe, der oben als BÜHNE frei bleibt - dort schwebt der ECHTE
## Würfel (Weltobjekt in Tray-Größe, fliegt aus dem Tray herüber, siehe
## scene_root), kein im Panel gerendertes Abbild. Knapp gehalten, damit über dem
## (kleinen) Würfel kein großer Leerraum steht und die UI weiter oben sitzt.
const STAGE_FRACTION := 0.15
## Kantenlänge einer Zelle des Würfel-Rasters (Breiteneinheiten u) - groß genug,
## dass Augensumme UND alle Seitenwerte lesbar sind, klein genug, dass das ganze
## rows×columns-Tray neben Bühne und Seiten-Übersicht in die Reihe passt.
## Kantenlänge einer Kachel/eines Seiten-Chips (Breiteneinheiten u): gilt für die
## Seiten-Übersicht (3×2, links) UND das Würfel-Raster (6 Spalten, rechts) - eine
## Änderung skaliert beide Listen gemeinsam (siehe _build_top_row).
const TRAY_TILE := 8.91

## Der laufende Spiellauf (von scene_root gesetzt) - liefert den Coupon-Bestand
## (owned_coupons) und verbucht den Verbrauch (consume_coupon), siehe GameRun.
var run: GameRun

var current_def: DieDefinition = null
var selected_face: int = -1  # gewählte physische Seite (0..5), -1 = keine
## True, wenn statt einer Seite der KANTEN-Rahmen gewählt ist (Klick auf den
## Kanten-Chip) - Ziel der Kanten-Coupons (siehe Coupon.KIND_EDGE). Schließt
## selected_face aus.
var edges_selected: bool = false
var mode: int = Mode.SELECT
var active_coupon_id: String = ""  # Coupon, dessen zweiten Schritt wir gerade auflösen

## Breiteneinheit (size.x / 100) wie HubView/ShopController - in _build_layout
## gesetzt (Mindestwert für freistehende Instanzen ohne Größe, siehe Tests).
var u := 8.0

# Gerüst-Referenzen (je show_die in _build_layout frisch gebaut).
var prompt_label: Label
var board_box: VBoxContainer  # Gravur-Bord: Abschnitts-Header + Slot-Raster (siehe _build_coupon_board)
var value_row: GridContainer  # Feingravur-Wertauswahl 1..FINE_ENGRAVING_MAX (6 Spalten)
var slot_entries: Array[Dictionary] = []  # [{button:Button, id:String, count:int}]
var summary_list: VBoxContainer  # Seiten als 2×3-Raster (je physische Seite ein Chip) + Kanten-Chip darunter
var summary_sum_label: Label

## Handgesteuerter Material-Tooltip der Seiten-Chips (Charm-Look) - ein Overlay im
## Panel selbst, das beim Überfahren eines Seiten-Chips mit Material erscheint.
## NICHT über Godots eingebautes Tooltip-System: dessen Timer feuert im
## Tisch-SubViewport nicht zuverlässig (deshalb rollt auch der Charm-Tooltip in
## scene_root seinen eigenen, siehe _update_charm_tooltip). Gesteuert über die
## mouse_entered/mouse_exited der Chips (die Maus-Weiterleitung liefert Motion,
## siehe scene_root._forward_screen_mouse - daher greifen Hover-Signale hier).
var face_tooltip: PanelContainer
var face_tooltip_title: Label
var face_tooltip_body: Label
## Würfel-Raster rechts neben der Bühne: SPIEGELT das Ursprungs-Tray (gleiches
## rows×columns-Raster, gleiche Buchreihenfolge, leere Slots als leere Zellen),
## der aktuell bearbeitete ist hervorgehoben. Ein Klick meldet den ECHTEN Slot-
## Index (siehe set_tray_grid/select_tray_die). Der Kontext kommt von scene_root
## und übersteht den Neuaufbau des Gerüsts (in _build_layout neu gezeichnet).
var tray_grid: GridContainer
var tray_context_defs: Array[DieDefinition] = []  # je ECHTEM Slot ein Eintrag (null = leer)
var tray_context_current: int = -1                # echter Slot des gegriffenen Würfels
var tray_context_rows: int = 0
var tray_context_columns: int = 0

## Die BÜHNE: leere Landefläche oben im Panel, über der der ECHTE Würfel schwebt
## (er fliegt aus seinem Tray herüber, siehe scene_root._grab_engraving_die - kein
## im Panel gerendertes Abbild mehr). Reserviert nur den Platz; ihre Mitte
## (stage_center_px) ist das Landeziel und der Endpunkt der Absorptions-Bahn.
var stage: Control

## Öffnet die Station für def (die tatsächliche Pool-Instanz) und setzt den
## Auswahl-/Ablaufzustand zurück. Baut Gerüst und Coupon-Bord frisch aus der
## aktuellen Größe bzw. dem Bestand.
func show_die(def: DieDefinition) -> void:
	current_def = def
	selected_face = -1
	edges_selected = false
	mode = Mode.SELECT
	active_coupon_id = ""
	_build_layout()
	_build_coupon_board()
	_refresh_face_summary()
	_update_prompt()
	visible = true

## Schließt die Station und meldet das (scene_root beendet dann die Zeremonie -
## der schwebende Würfel fliegt zurück in sein Tray).
func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

# --- Gerüst (Neon-Panel) --------------------------------------------------------

## Baut das feste Gerüst: Kopfzeile (Titel + Fertig), obere Reihe (links Seiten-
## Übersicht über der Würfel-Bühne, rechts das Würfel-Raster), Hinweiszeile, das
## Gravur-Bord und die (zunächst verborgene) Feingravur-Wertreihe.
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

	_rebuild_tray_grid()  # aus dem gespeicherten Kontext (übersteht den Neuaufbau)
	_build_face_tooltip()  # zuletzt: liegt als Overlay über allem im Panel

## Kopfzeile: Titel links (Magenta), Fertig rechts (Gold).
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

## Obere Reihe: LINKS eine Spalte aus Seiten-Übersicht (3×2-Seiten-Raster + Kanten,
## siehe _refresh_face_summary - gleiche linke Kante wie das Gravur-Bord darunter)
## und DARUNTER die BÜHNE, über der der ECHTE Würfel als Weltobjekt landet (er
## fliegt aus seinem Tray herüber, siehe scene_root._grab_engraving_die). RECHTS,
## bündig am rechten Rand, das Würfel-Raster (spiegelt das Tray). Ein dehnbarer
## Platzhalter DAZWISCHEN drückt beide Seiten an ihre Ränder.
func _build_top_row(root: Control) -> void:
	var top_row := HBoxContainer.new()
	top_row.name = "TopRow"
	top_row.add_theme_constant_override("separation", 0)
	top_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(top_row)

	# Linke Spalte: Seiten-Übersicht oben, darunter der schwebende Würfel.
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

	stage = CenterContainer.new()
	stage.name = "Stage"
	stage.custom_minimum_size = Vector2(0, size.y * STAGE_FRACTION)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_col.add_child(stage)

	top_row.add_child(_expanding_spacer())

	tray_grid = GridContainer.new()
	tray_grid.name = "TrayGrid"
	tray_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tray_grid.add_theme_constant_override("h_separation", int(u * 0.6))
	tray_grid.add_theme_constant_override("v_separation", int(u * 0.6))
	top_row.add_child(tray_grid)

## Hinweiszeile unter den beiden Listen (Auswahl-/Ätzungs-Aufforderungen).
func _build_prompt(root: Control) -> void:
	prompt_label = _label("", u * 2.2, NEON_TEXT)
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.custom_minimum_size = Vector2(0, u * 5.5)
	root.add_child(prompt_label)

## Gravur-Bord (Ätzungen/Materialien/Kanten) über die volle Breite unter der oberen
## Reihe. Der schwebende Würfel sitzt jetzt links unter der Seiten-Übersicht (siehe
## _build_top_row/stage), nicht mehr neben dem Bord.
func _build_board(root: Control) -> void:
	board_box = VBoxContainer.new()
	board_box.name = "Board"
	board_box.add_theme_constant_override("separation", int(u * 0.8))
	board_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(board_box)

## Feingravur-Wertreihe (1..FINE_ENGRAVING_MAX) - erst sichtbar, wenn die
## Feingravur eine Zielwert-Auswahl verlangt (siehe _show_value_picker).
func _build_value_row(root: Control) -> void:
	value_row = GridContainer.new()
	value_row.name = "ValueRow"
	value_row.columns = 6  # 1..6 in der oberen, 7..FINE_ENGRAVING_MAX in der unteren Reihe
	value_row.add_theme_constant_override("h_separation", int(u * 0.6))
	value_row.add_theme_constant_override("v_separation", int(u * 0.6))
	value_row.visible = false
	for value in range(1, EtchingEffects.FINE_ENGRAVING_MAX + 1):
		var value_button := _neon_button(str(value), NEON_MAGENTA, u * 2.4, Vector2(0, u * 4.4))
		value_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_button.pressed.connect(_on_value_pressed.bind(value))
		value_row.add_child(value_button)
	root.add_child(value_row)

## Ein durchsichtiger, waagerecht dehnbarer Platzhalter (zentriert das Listen-Paar).
func _expanding_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

# --- Bühne (Landefläche des schwebenden Würfels) -------------------------------

## Mittelpunkt der Bühne in Display-Pixeln: Landeziel des herüberfliegenden
## Würfels und Endpunkt der Absorptions-Bahn (siehe scene_root). Panel-Mitte als
## Rückfall, falls die Bühne (noch) nicht existiert.
func stage_center_px() -> Vector2:
	if stage != null and is_instance_valid(stage):
		return stage.get_global_rect().get_center()
	return get_global_rect().get_center()

# --- Würfel-Raster (Umwählen) --------------------------------------------------

## Übernimmt das Raster des Ursprungs-Trays: rows×columns, je ECHTEM Slot eine Def
## (null = leer) in Buchreihenfolge, und welcher Slot gerade bearbeitet wird
## (current_slot) - von scene_root nach jedem Öffnen/Wechsel gesetzt (siehe
## _refresh_engraving_tray_strip) und danach als Raster gezeigt.
func set_tray_grid(rows: int, columns: int, defs: Array[DieDefinition], current_slot: int) -> void:
	tray_context_rows = rows
	tray_context_columns = columns
	tray_context_defs = defs
	tray_context_current = current_slot
	_rebuild_tray_grid()

## Zeichnet das Würfel-Raster neu: es SPIEGELT das Tray (columns Spalten, Slots in
## Buchreihenfolge). Belegte Slots werden zu anklickbaren Kacheln (Augensumme),
## leere zu stillen Platzhaltern; der aktuell bearbeitete trägt den goldenen
## Auswahl-Look. Ein Klick meldet select_tray_die mit dem echten Slot-Index.
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

## Eine Würfel-Kachel des Rasters: Augensumme (klein) über einem 3×2-Raster der
## sechs Seiten, jede in ihrer MATERIALFARBE getönt (weiß ohne Material). Der
## Kachel-RAHMEN trägt die Farbe des KANTEN-Materials (die "Kanten" des Würfels);
## highlighted = goldener Rahmen (der gerade bearbeitete Würfel). Ein Klick meldet
## den Slot-Index.
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

	# Rahmen = Kanten-Material des Würfels (gold, solange dieser Würfel bearbeitet wird).
	var edge_tint := DieMaterial.tint_for(def.edge_material)  # Weiß ohne Kanten-Material
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
	var sum_label := _label(str(total), u * 2.08, NEON_GOLD if highlighted else NEON_TEXT)  # ~30% größer als früher (1.6)
	sum_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sum_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(sum_label)
	box.add_child(_tray_face_grid(def))
	return tile

## Das 3×2-Raster der sechs Seiten einer Tray-Kachel: jede Seite als kleine
## Farbfläche in ihrer Materialfarbe (weiß ohne Material) mit dunkler Augenzahl,
## nach Wert sortiert - dieselbe Optik wie die Seiten-Chips der Übersicht, nur
## kompakt und nicht anklickbar.
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

## Die Seiten-Indizes eines Würfels, nach Augenzahl aufsteigend sortiert (bei
## Gleichstand nach physischem Seitenindex) - damit Seiten-Raster und Tray-Kacheln
## einheitlich wie "1-6" lesen, jede Kachel aber ihre EIGENE physische Seite bleibt.
func _faces_sorted_by_value(def: DieDefinition) -> Array[int]:
	var order: Array[int] = []
	for i in def.faces.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if def.faces[a] != def.faces[b]:
			return def.faces[a] < def.faces[b]
		return a < b)
	return order

## Material-id der Seite face_index (leerer String, falls die Materialliste kürzer
## als die Seitenliste ist - defensiv gegen unvollständige Definitionen).
func _material_of(def: DieDefinition, face_index: int) -> String:
	return def.materials[face_index] if face_index < def.materials.size() else ""

## Eine einzelne Seiten-Fläche einer Tray-Kachel: Panel in der Materialfarbe der
## Seite (weiß ohne Material), Augenzahl dunkel zentriert.
func _tray_face_cell(value: int, material_id: String) -> Control:
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2.ONE * u * 2.1  # ~40% größer als früher (1.5)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = DieMaterial.tint_for(material_id)  # Weiß ohne Material
	box.border_color = Color(0, 0, 0, 0.35)
	box.set_border_width_all(maxi(1, int(u * 0.1)))
	box.set_corner_radius_all(maxi(1, int(u * 0.3)))
	cell.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = str(value)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", maxi(8, int(u * 1.54)))  # mit der Zelle mitgewachsen (~40%)
	label.add_theme_color_override("font_color", CasinoStyle.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(label)
	return cell

## Ein leerer Slot des Rasters: stiller Platzhalter, damit das Raster die Lücken
## des Trays exakt spiegelt (kein Klick, gedämpfter Rahmen).
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
	box.set_border_width_all(maxi(1, int(u * 0.33)))  # ~30% dicker als früher (0.25)
	box.set_corner_radius_all(int(u * 0.9))
	return box

# --- Seiten-Auswahl / Ätzungs-Anwendung -------------------------------------

## Wählt eine physische Seite (über die Seiten-Chips, siehe _on_chip_clicked).
## Je nach Modus wählt der Klick die Seite oder liefert die zweite Seite einer
## laufenden Ätzung.
func _on_face_clicked(_die_index: int, face_index: int) -> void:
	if mode == Mode.AWAIT_SECOND_FACE:
		_complete_two_step(face_index)
		return
	# Neue Auswahl - bricht eine offene Wertauswahl (Feingravur) mit ab.
	selected_face = face_index
	edges_selected = false
	_refresh_after_selection()  # Chip des gewählten Werts hervorheben

## Klick auf den KANTEN-Chip: wählt die Kanten als Gravur-Ziel - danach lassen
## sich die Kanten-Coupons anwenden. Läuft gerade der zweite Schritt einer
## Ätzung, zählen die Kanten nicht als Seite und werden ignoriert.
func _on_edges_clicked(_die_index: int = 0) -> void:
	if mode == Mode.AWAIT_SECOND_FACE:
		prompt_label.text = "Bitte eine SEITE anklicken - Kanten sind hier kein Ziel."
		return
	edges_selected = true
	selected_face = -1
	_refresh_after_selection()  # Kanten-Chip hervorheben

## Gemeinsamer Nachlauf nach einer neuen Ziel-Auswahl (Seite ODER Kanten): zurück
## in den Grundmodus, offene Feingravur-Wertauswahl schließen, Übersicht/Hinweis/
## Bord-Sperren an den neuen Auswahlzustand anpassen.
func _refresh_after_selection() -> void:
	mode = Mode.SELECT
	active_coupon_id = ""
	_hide_value_picker()
	_refresh_face_summary()
	_update_prompt()
	_refresh_coupon_enabled()

## Klick auf einen Chip der Seiten-Übersicht (siehe _face_chip): wählt die Seite
## zum Gravieren. Normalerweise genau die Seite face_index der Chip-Gruppe
## (Wert + Material). Beim zweiten Schritt (Meißel-Quelle, Schleifstein-Minus)
## wird stattdessen möglichst eine ANDERE Seite desselben Werts genommen (siehe
## _face_index_for_value), damit gleiche Werte nicht auf sich selbst verweisen.
func _on_chip_clicked(value: int, face_index: int) -> void:
	if current_def == null:
		return
	if mode == Mode.AWAIT_SECOND_FACE:
		var second := _face_index_for_value(value, selected_face)
		if second != -1:
			_on_face_clicked(0, second)
		return
	_on_face_clicked(0, face_index)

## Index einer Seite mit dem gegebenen Wert, möglichst ungleich exclude (für den
## Zweitschritt einer Ätzung). Fällt auf die passende Seite zurück, wenn nur die
## ausgeschlossene den Wert trägt; -1, wenn der Wert gar nicht vorkommt.
func _face_index_for_value(value: int, exclude: int) -> int:
	var fallback := -1
	for i in current_def.faces.size():
		if current_def.faces[i] == value:
			if i != exclude:
				return i
			fallback = i
	return fallback

## Klick auf einen Coupon-Button - verteilt nach Coupon-Art an den passenden
## Handler. Kanten-Coupons (siehe Coupon.KIND_EDGE) veredeln den GANZEN Würfel und
## brauchen den gewählten KANTEN-Chip; Material- und Ätzungs-Coupons brauchen eine
## gewählte SEITE. Nur im Grundmodus - während eines Zweitschritts ist der Bord
## ohnehin gesperrt (siehe _refresh_coupon_enabled).
func _on_coupon_pressed(coupon_id: String) -> void:
	if mode != Mode.SELECT:
		return
	if Coupon.is_edge_id(coupon_id):
		_apply_edge_coupon(coupon_id)
	elif selected_face == -1:
		return  # Material-/Ätzungs-Coupons brauchen eine gewählte Seite
	elif DieMaterial.is_valid_id(coupon_id):
		_apply_material_coupon(coupon_id)
	else:
		_apply_etching_coupon(coupon_id)

## Kanten-Coupon: setzt das Kanten-Material des ganzen Würfels (ein neues ersetzt
## ein vorhandenes), sofern es nicht schon anliegt.
func _apply_edge_coupon(coupon_id: String) -> void:
	if not edges_selected:
		return
	var material_id := coupon_id.trim_prefix(Coupon.EDGE_PREFIX)
	if current_def.edge_material == material_id:
		prompt_label.text = "Die Kanten tragen bereits %s." % DieMaterial.by_id(material_id).display_name
		return
	current_def.edge_material = material_id
	_finish_apply(coupon_id, "Kanten veredelt: %s" % DieMaterial.by_id(material_id).display_name)

## Material-Coupon (Coupon-id = Material-id, siehe DieMaterial): belegt die
## gewählte Seite; ein neues Material ersetzt ein vorhandenes.
func _apply_material_coupon(coupon_id: String) -> void:
	if current_def.materials[selected_face] == coupon_id:
		prompt_label.text = "Diese Seite trägt bereits %s." % DieMaterial.by_id(coupon_id).display_name
		return
	current_def.materials[selected_face] = coupon_id
	_finish_apply(coupon_id, "Material angebracht: %s" % DieMaterial.by_id(coupon_id).display_name)

## Ätzungs-Coupon: einstufige Ätzungen wirken sofort auf die gewählte Seite (bzw.
## den ganzen Würfel); mehrstufige gehen in den passenden Wart-Modus über
## (_await_second_face / _begin_value_pick).
func _apply_etching_coupon(coupon_id: String) -> void:
	match coupon_id:
		Coupon.OVERCOUNT_ENGRAVING:
			EtchingEffects.overcount_engraving(current_def, selected_face)
			_finish_apply(coupon_id, "Überzahl-Gravur: Seite +1")
		Coupon.FINE_ENGRAVING:
			_begin_value_pick(coupon_id)
		Coupon.CHISEL:
			_await_second_face(coupon_id, "Meißel: klicke die Quellseite (ihr Wert wird auf die gewählte Seite kopiert).")
		Coupon.GRINDSTONE:
			_await_second_face(coupon_id, "Schleifstein: gewählte Seite bekommt +1 – klicke jetzt die Seite für −1.")
		Coupon.FILE_DOWN:
			if not EtchingEffects.can_file_down(current_def, selected_face):
				prompt_label.text = "Feile: diese Seite ist schon 1."
				return
			EtchingEffects.file_down(current_def, selected_face)
			_finish_apply(coupon_id, "Feile: Seite −1")
		Coupon.DOUBLE_NOTCH:
			_await_second_face(coupon_id, "Doppelkerbe: gewählte Seite +1 – klicke die zweite Seite (auch +1).")
		Coupon.AVERAGING:
			_await_second_face(coupon_id, "Mittelung: klicke die zweite Seite – beide werden ihr aufgerundeter Mittelwert.")
		Coupon.MIRROR:
			EtchingEffects.mirror_die(current_def)
			_finish_apply(coupon_id, "Spiegelung: Würfel invertiert")
		Coupon.STRAIGHTEN:
			EtchingEffects.straighten(current_def)
			_finish_apply(coupon_id, "Begradigung: ungerade Seiten +1")
		Coupon.TRANSPLANT:
			if not EtchingEffects.can_transplant(current_def, selected_face):
				prompt_label.text = "Transplantat: diese Seite ist schon der Höchstwert."
				return
			EtchingEffects.transplant(current_def, selected_face)
			_finish_apply(coupon_id, "Transplantat: Seite auf Höchstwert gehoben")
		Coupon.CONNECT_UP:
			_await_second_face(coupon_id, "Anschluss: klicke die Quellseite – die gewählte Seite wird ihr Wert + 1.")
		Coupon.IMPRINT:
			EtchingEffects.imprint(current_def, selected_face)
			_finish_apply(coupon_id, "Abdruck: auf die zwei niedrigsten Seiten geprägt")
		Coupon.BLUEPRINT:
			EtchingEffects.blueprint(current_def, selected_face)
			_finish_apply(coupon_id, "Blaupause: ganzer Würfel auf den gewählten Wert gesetzt")

## Wechselt in den Wart-Modus für die ZWEITE Seite einer mehrstufigen Ätzung und
## zeigt die passende Aufforderung (der zweite Chip-Klick löst _complete_two_step aus).
func _await_second_face(coupon_id: String, prompt: String) -> void:
	mode = Mode.AWAIT_SECOND_FACE
	active_coupon_id = coupon_id
	prompt_label.text = prompt
	_refresh_coupon_enabled()

## Wechselt in den Wart-Modus für die Zielwert-Auswahl der Feingravur und blendet
## die Wertreihe ein (der Klick auf einen Wert löst _on_value_pressed aus).
func _begin_value_pick(coupon_id: String) -> void:
	mode = Mode.PICK_VALUE
	active_coupon_id = coupon_id
	_show_value_picker()
	prompt_label.text = "Feingravur: Zielwert 1–12 wählen."
	_refresh_coupon_enabled()

## Wertauswahl der Feingravur (siehe _show_value_picker).
func _on_value_pressed(value: int) -> void:
	if mode != Mode.PICK_VALUE or selected_face == -1:
		return
	EtchingEffects.fine_engraving(current_def, selected_face, value)
	_hide_value_picker()
	_finish_apply(Coupon.FINE_ENGRAVING, "Feingravur: Seite = %d" % value)

## Schließt eine mehrschrittige Ätzung mit der zweiten Seite ab.
func _complete_two_step(second_face: int) -> void:
	if second_face == selected_face:
		prompt_label.text = "Bitte eine ANDERE Seite als die gewählte anklicken."
		return
	match active_coupon_id:
		Coupon.CHISEL:
			EtchingEffects.chisel(current_def, second_face, selected_face)  # Quelle=zweite, Ziel=gewählte
			_finish_apply(active_coupon_id, "Meißel: Seite kopiert")
		Coupon.GRINDSTONE:
			if not EtchingEffects.can_grindstone_minus(current_def, second_face):
				prompt_label.text = "Diese Seite ist schon 1 – wähle eine andere für −1."
				return  # Wart-Modus bleibt, Coupon noch nicht verbraucht
			EtchingEffects.grindstone(current_def, second_face, selected_face)  # −1=zweite, +1=gewählte
			_finish_apply(active_coupon_id, "Schleifstein: +1 / −1 angewandt")
		Coupon.DOUBLE_NOTCH:
			EtchingEffects.double_notch(current_def, selected_face, second_face)
			_finish_apply(active_coupon_id, "Doppelkerbe: zwei Seiten +1")
		Coupon.AVERAGING:
			EtchingEffects.averaging(current_def, selected_face, second_face)
			_finish_apply(active_coupon_id, "Mittelung: zwei Seiten gemittelt")
		Coupon.CONNECT_UP:
			EtchingEffects.connect_up(current_def, second_face, selected_face)  # Quelle=zweite, Ziel=gewählte
			_finish_apply(active_coupon_id, "Anschluss: gewählte Seite = Quellwert + 1")

## Verbraucht den Coupon, aktualisiert die Panel-Anzeige und meldet die Änderung
## (changed für die Trays, applied für die Absorptions-Animation des schwebenden
## Würfels). Die gewählte Seite bleibt gewählt, damit man direkt weitergravieren kann.
func _finish_apply(coupon_id: String, message: String) -> void:
	if run != null:
		# Gravierstift: einmal pro Runde wird eine ÄTZUNG (kein Material/Kanten-
		# Coupon) beim Anwenden nicht verbraucht (siehe CharmEffects).
		var is_etching := not DieMaterial.is_valid_id(coupon_id) and not Coupon.is_edge_id(coupon_id)
		if is_etching and CharmEffects.has_engraving_pen(run.charm_ids()) and not run.gravierstift_used_this_round:
			run.gravierstift_used_this_round = true
			message += " Gravierstift: Coupon nicht verbraucht!"
		else:
			run.consume_coupon(coupon_id)
	mode = Mode.SELECT
	active_coupon_id = ""
	changed.emit()
	applied.emit(coupon_id, _slot_center_px(coupon_id))
	_build_coupon_board()  # Anzahl hat sich geändert
	_refresh_face_summary()
	_rebuild_tray_grid()  # Augensumme des bearbeiteten Würfels kann sich geändert haben
	prompt_label.text = "%s. Weiter gravieren oder Rechtsklick zum Schließen." % message

## Display-Pixel der Bord-Kachel eines Coupons (Quelle der Absorptions-Bahn) -
## Mitte des Panels als Rückfall, falls der Platz nicht (mehr) existiert.
func _slot_center_px(coupon_id: String) -> Vector2:
	for entry in slot_entries:
		if entry["id"] == coupon_id and is_instance_valid(entry["button"]):
			return (entry["button"] as Control).get_global_rect().get_center()
	return get_global_rect().get_center()

func _cancel_pending() -> void:
	mode = Mode.SELECT
	active_coupon_id = ""
	_hide_value_picker()
	_update_prompt()
	_refresh_coupon_enabled()

func _update_prompt() -> void:
	if edges_selected:
		prompt_label.text = "Kanten gewählt. Wähle ein Kanten-Material."
	elif selected_face == -1:
		prompt_label.text = ""  # kein Aufforderungstext, solange nichts gewählt ist
	else:
		prompt_label.text = "Seite gewählt (Wert %d). Wähle eine Ätzung." % current_def.faces[selected_face]

# --- Seiten-Übersicht ----------------------------------------------------------

## Baut die Seiten-Übersicht neu aus current_def.faces: JEDE der sechs physischen
## Seiten bekommt einen eigenen Chip (Wert + Material-Tönung) in einem 2×3-Raster,
## nach Wert sortiert; ein Klick wählt genau diese Seite zum Gravieren, die
## gewählte trägt den goldenen Auswahl-Look. Darunter der Kanten-Chip (eigene
## Zeile), dahinter die Augensumme.
func _refresh_face_summary() -> void:
	if summary_list == null:
		return
	_hide_face_tooltip()  # die alten Chips (mit ihren Hover-Verbindungen) fallen weg
	for child in summary_list.get_children():
		child.queue_free()
	if current_def == null:
		return

	# Seiten-Chips im 3 breiten, 2 hohen Raster, nach Wert sortiert (siehe
	# _faces_sorted_by_value) - jede Kachel bleibt aber ihre EIGENE Seite.
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

	# Kanten-Chip DARUNTER (wählt den Kanten-Rahmen als Gravur-Ziel) + aktuelles Material.
	var edge_group := HBoxContainer.new()
	edge_group.add_theme_constant_override("separation", int(u * 0.4))
	edge_group.add_child(_edge_chip(edges_selected))
	var edge_label := _label(DieMaterial.by_id(current_def.edge_material).display_name \
		if DieMaterial.is_valid_id(current_def.edge_material) else "ohne", u * 2.0, NEON_MUTED)
	edge_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	edge_group.add_child(edge_label)
	summary_list.add_child(edge_group)

	# Augensumme unter der Übersicht (frisch, da summary_list bei jedem Neuaufbau
	# geleert wird).
	summary_sum_label = _label("Augensumme: %d" % total, u * 2.2, NEON_MUTED)
	summary_list.add_child(summary_sum_label)

## Ein anklickbarer Mini-Würfelseiten-Chip im Look der echten Würfel (getönt in
## der Materialfarbe der Seite - weiß ohne Material - mit dunkler Ziffer);
## highlighted = goldener Auswahl-Look (siehe RotatableDieView.SELECT_FACE_COLOR).
## Trägt die Seite ein Material, nennt der Tooltip dessen Wirkung. Ein Klick
## wählt die Seite face_index zum Gravieren (siehe _on_chip_clicked).
func _face_chip(value: int, material_id: String, highlighted: bool, face_index: int) -> Button:
	var chip := Button.new()
	chip.text = str(value)
	chip.custom_minimum_size = Vector2.ONE * u * TRAY_TILE  # so groß wie eine Kachel der Würfelliste
	chip.add_theme_font_size_override("font_size", int(u * TRAY_TILE * 0.5))
	# Gewählt: Ziffer + Rahmen leuchten in der Pit-Auswahlfarbe; sonst die
	# Materialfarbe der Seite (weiß ohne).
	_style_chip(chip, DieMaterial.tint_for(material_id), highlighted)
	if DieMaterial.is_valid_id(material_id):
		var material := DieMaterial.by_id(material_id)
		# Material-Tooltip im Charm-Look direkt auf dem Display: handgesteuert über
		# die Hover-Signale des Chips (siehe face_tooltip / _show_face_tooltip),
		# weil Godots eingebauter Tooltip im Tisch-SubViewport nicht feuert.
		chip.mouse_entered.connect(_show_face_tooltip.bind(chip, material.display_name, material.description))
		chip.mouse_exited.connect(_hide_face_tooltip)
	chip.pressed.connect(_on_chip_clicked.bind(value, face_index))
	return chip

## Der anklickbare "Kanten"-Chip der Seiten-Übersicht: gefüllt mit dem Tint des
## aktuellen Kanten-Materials (Rahmen-Neutral ohne), gold hervorgehoben, wenn
## der Kanten-Rahmen gerade das Gravur-Ziel ist.
func _edge_chip(highlighted: bool) -> Button:
	var chip := Button.new()
	chip.text = "Kanten"
	chip.custom_minimum_size = Vector2(u * TRAY_TILE * 1.7, u * TRAY_TILE)  # gleiche Höhe wie ein Seiten-Chip
	chip.add_theme_font_size_override("font_size", int(u * TRAY_TILE * 0.34))
	var material_tint := DieMaterial.tint_for(current_def.edge_material)
	var base := material_tint if material_tint != Color.WHITE else DieFaceDisplay.EDGE_COLOR
	_style_chip(chip, base, highlighted)
	if DieMaterial.is_valid_id(current_def.edge_material):
		var edge := DieMaterial.by_id(current_def.edge_material)
		# Gleicher handgesteuerter Charm-Tooltip wie bei den Seiten-Chips - hier mit
		# der KANTEN-Wirkung (siehe RotatableDieView._get_tooltip).
		chip.mouse_entered.connect(_show_face_tooltip.bind(chip, edge.display_name, edge.edge_description))
		chip.mouse_exited.connect(_hide_face_tooltip)
	chip.pressed.connect(_on_edges_clicked)
	return chip

## Gemeinsamer Look der Seiten-/Kanten-Chips: die FÜLLUNG bleibt immer die Material-/
## Kantenfarbe (base_fill). Ist der Chip GEWÄHLT, leuchten stattdessen die ZIFFER
## und der RAHMEN in der Pit-Auswahlfarbe (überhelles Gold, das dank HDR-2D bloomt -
## siehe TableScreen.GLOW_COLOR, dasselbe Leuchten wie unter den gewählten Würfeln in
## der Grube), und der Rahmen wird dicker. Sonst dunkle Ziffer (INK) auf einem dünnen,
## neutralen Rahmen. Größe/Schrift/Text setzt der Aufrufer.
func _style_chip(chip: Button, base_fill: Color, highlighted: bool) -> void:
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var font_color := TableScreen.GLOW_COLOR if highlighted else CasinoStyle.INK
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		chip.add_theme_color_override(state, font_color)
	# Gewählt: schwarzer Umriss um die leuchtende Ziffer, damit sie auf jeder
	# Materialfarbe lesbar bleibt (sonst geht das helle Gold auf hellen Seiten unter).
	chip.add_theme_color_override("font_outline_color", CasinoStyle.INK)
	chip.add_theme_constant_override("outline_size", int(u * 0.45) if highlighted else 0)
	var border := TableScreen.GLOW_COLOR if highlighted else CHIP_BORDER
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

# --- Gravur-Bord ---------------------------------------------------------------

## Baut das Gravur-Bord neu: JEDER Coupon-Archetyp bekommt seinen festen Platz
## (Reihenfolge = kanonische Coupon.all()-Reihenfolge, getrennt nach Ätzungen
## und Materialien). Besitz liegt als physischer Coupon auf dem Platz - Mehrfache
## als versetzter Stapel mit ×Anzahl -, nicht Besessenes als ausgegrauter Schatten.
func _build_coupon_board() -> void:
	if board_box == null:
		return
	slot_entries.clear()
	for child in board_box.get_children():
		child.queue_free()

	var counts := _coupon_counts()
	var etchings: Array[Coupon] = []
	var materials: Array[Coupon] = []
	var edges: Array[Coupon] = []
	for archetype in Coupon.all():
		match archetype.kind:
			Coupon.KIND_ETCHING:
				etchings.append(archetype)
			Coupon.KIND_MATERIAL:
				materials.append(archetype)
			Coupon.KIND_EDGE:
				edges.append(archetype)
			_:
				pass  # Menü-Coupons (KIND_MEAL) wirken sofort und liegen nie im Bestand
	_add_board_section("Ätzungen", _sorted_by_rarity(etchings), counts)
	_add_board_section("Materialien", _sorted_by_rarity(materials), counts)
	_add_board_section("Kanten", _sorted_by_rarity(edges), counts)
	_refresh_coupon_enabled()

## Sortiert Archetypen nach Seltenheit (häufig → ungewöhnlich → selten);
## innerhalb einer Seltenheit bleibt die kanonische Coupon.all()-Reihenfolge
## erhalten, damit die Plätze über Sitzungen hinweg stabil liegen.
func _sorted_by_rarity(archetypes: Array[Coupon]) -> Array[Coupon]:
	var sorted: Array[Coupon] = []
	for rarity in [Coupon.Rarity.COMMON, Coupon.Rarity.UNCOMMON, Coupon.Rarity.RARE]:
		for archetype in archetypes:
			if archetype.rarity == rarity:
				sorted.append(archetype)
	return sorted

## Ein Bord-Abschnitt: kleiner Header (Cyan) + festes Slot-Raster (SLOT_COLUMNS breit).
func _add_board_section(title: String, archetypes: Array[Coupon], counts: Dictionary) -> void:
	var header := _label(title, u * 2.0, NEON_CYAN)
	board_box.add_child(header)

	var grid := GridContainer.new()
	grid.columns = SLOT_COLUMNS
	grid.add_theme_constant_override("h_separation", int(u * 0.6))
	grid.add_theme_constant_override("v_separation", int(u * 0.6))
	board_box.add_child(grid)

	for archetype in archetypes:
		var count: int = counts.get(archetype.id, 0)
		var slot := _coupon_slot(archetype, count)
		grid.add_child(slot)
		slot_entries.append({"button": slot, "id": archetype.id, "count": count})

## Sichtbare Coupon-Kachel im Slot (u-skaliert).
func _tile_size() -> Vector2:
	return Vector2(u * 6.0, u * 5.0)

## Ein einzelner Bord-Platz: Button als "Mulde" (fester Rahmen), darin der
## Coupon als Kachel - bei Mehrfachbesitz als Stapel (bis STACK_MAX_VISIBLE
## sichtbar versetzte Exemplare, die tieferen leicht abgedunkelt) plus
## ×Anzahl-Abzeichen. Ohne Besitz liegt nur der ausgegraute Schatten der Kachel
## im Slot. Klick = Coupon anwenden (siehe _on_coupon_pressed).
func _coupon_slot(archetype: Coupon, count: int) -> Button:
	var slot := Button.new()
	var pad := u * 0.35
	var stack_offset := Vector2.ONE * u * 0.4
	var stack_margin := stack_offset * float(STACK_MAX_VISIBLE - 1)
	slot.custom_minimum_size = _tile_size() + Vector2.ONE * (pad * 2.0) + stack_margin
	slot.focus_mode = Control.FOCUS_NONE
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var state := ("×%d im Bestand" % count) if count > 0 else "nicht im Bestand"
	slot.tooltip_text = "%s (%s)\n%s" % [archetype.display_name, state, archetype.description]
	slot.pressed.connect(_on_coupon_pressed.bind(archetype.id))
	slot.add_theme_stylebox_override("normal", _slot_box(Color(0.545, 0.914, 0.992, 0.35)))
	slot.add_theme_stylebox_override("hover", _slot_box(NEON_GOLD))
	slot.add_theme_stylebox_override("pressed", _slot_box(NEON_GOLD.darkened(0.25)))
	slot.add_theme_stylebox_override("disabled", _slot_box(Color(1, 1, 1, 0.08)))
	slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# Stapel von hinten nach vorn aufbauen (tiefere Exemplare zuerst = untendrunter).
	var depth: int = clampi(count, 1, STACK_MAX_VISIBLE)
	for i in range(depth - 1, -1, -1):
		var tile := _coupon_tile(archetype)
		tile.position = Vector2.ONE * pad + stack_offset * float(i)
		tile.size = _tile_size()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if count == 0:
			tile.modulate = EMPTY_SLOT_TINT  # nur der Schatten des Coupons
		elif i > 0:
			tile.modulate = Color(0.78, 0.78, 0.78)  # tiefere Stapel-Exemplare dunkler
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

## Die Coupon-Kachel eines Slots: das Motiv als TextureRect - oder, falls die
## Motiv-Datei (noch) fehlt (z.B. Material-Coupons ohne Artwork), derselbe
## Platzhalter-Look wie auf den Bögen (siehe CouponSheetView._tile_node):
## Material-/Papierfarbe mit dem Coupon-Namen.
func _coupon_tile(archetype: Coupon) -> Control:
	if ResourceLoader.exists(archetype.texture_path):
		var tex := TextureRect.new()
		tex.texture = load(archetype.texture_path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_SCALE  # auf den Slot strecken - Quell-Seitenverhältnis egal
		return tex

	var placeholder := Panel.new()
	var box := StyleBoxFlat.new()
	var tint := DieMaterial.tint_for(archetype.material_id())
	box.bg_color = tint.lerp(CouponSheetView.PAPER_COLOR, 0.35)
	box.border_color = CouponSheetView.PERF_COLOR
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	placeholder.add_theme_stylebox_override("panel", box)

	var label := Label.new()
	label.text = archetype.display_name
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_font_size_override("font_size", int(u * 1.3))
	label.add_theme_color_override("font_color", CouponSheetView.PERF_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.add_child(label)
	return placeholder

## Die "Mulde" eines Bord-Platzes: dunkel eingelassene Fläche mit dünnem Rand.
func _slot_box(border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.28)
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(int(u * 0.7))
	return box

## Zählt den Coupon-Bestand nach id (id -> Anzahl).
func _coupon_counts() -> Dictionary:
	var counts := {}
	if run == null:
		return counts
	for coupon in run.owned_coupons:
		counts[coupon.id] = counts.get(coupon.id, 0) + 1
	return counts

## Sperrt Bord-Slots, wenn kein passendes Ziel gewählt ist, gerade ein zweiter
## Schritt läuft (dann ist nur der zweite Seiten-Klick dran) - oder der Platz
## leer ist. Ätzungen/Seiten-Materialien brauchen eine gewählte SEITE,
## Kanten-Coupons den gewählten KANTEN-Chip (edges_selected).
func _refresh_coupon_enabled() -> void:
	for entry in slot_entries:
		var is_edge: bool = Coupon.is_edge_id(entry["id"])
		var has_target: bool = edges_selected if is_edge else selected_face != -1
		entry["button"].disabled = entry["count"] == 0 or mode != Mode.SELECT or not has_target

func _show_value_picker() -> void:
	value_row.visible = true

func _hide_value_picker() -> void:
	if value_row != null:
		value_row.visible = false

# --- Neon-Bausteine --------------------------------------------------------------

func _label(text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Ein Knopf im Neon-Stil des Displays (wie ShopController._neon_button).
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

# --- Material-Tooltip der Seiten-Chips (handgesteuertes Overlay) ----------------

## Baut das (zunächst verborgene) Tooltip-Overlay im Charm-Look: Casino-Panel,
## Name in Gold, Wirkung in Creme darunter. Die Schriftgrößen/Textbreite sind
## u-skaliert, damit der Tooltip auf dem hoch aufgelösten Tisch-Display lesbar
## bleibt (die Charm-Standardgrößen wären dort winzig). Als LETZTES Kind des Panels
## angehängt, liegt es über allem im Panel; folgt keiner Maus, sondern erscheint
## über dem überfahrenen Chip (siehe _show_face_tooltip).
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

## Zeigt den Material-Tooltip über dem überfahrenen Seiten-Chip (chip): Text setzen,
## Größe neu messen und knapp unter dem Chip platzieren, dabei innerhalb des Panels
## eingeklemmt (clip_contents schneidet Überstände sonst ab).
func _show_face_tooltip(chip: Control, title: String, body: String) -> void:
	if face_tooltip == null:
		return
	face_tooltip_title.text = title
	face_tooltip_body.text = body
	face_tooltip.visible = true
	face_tooltip.reset_size()
	var local := chip.get_global_rect().position - get_global_rect().position
	var pos := local + Vector2(0.0, chip.size.y + u * 0.6)
	pos.x = clampf(pos.x, u * 1.0, maxf(u * 1.0, size.x - face_tooltip.size.x - u * 1.0))
	pos.y = clampf(pos.y, u * 1.0, maxf(u * 1.0, size.y - face_tooltip.size.y - u * 1.0))
	face_tooltip.position = pos

func _hide_face_tooltip() -> void:
	if face_tooltip != null:
		face_tooltip.visible = false
