class_name DieInspectorView
extends Control
## Modale Gravur-Station für einen einzelnen Würfel: erscheint über allem
## anderen, dimmt den Hintergrund ab und zeigt den Würfel groß und frei drehbar
## (siehe RotatableDieView, hier mit genau einem Würfel). Wird von scene_root.gd
## geöffnet, sobald im gezoomten Pool-/Ablage-/Warteschlangen-Tray auf einen
## sichtbaren Würfel geklickt wird.
##
## Hier wendet der Spieler seine Ätzungs-Coupons an (siehe Coupon/EtchingEffects):
## Er klickt eine Würfelseite (Auswahl, gold hervorgehoben) und danach einen
## Coupon auf dem Gravur-Bord rechts - beliebig oft, solange er Coupons hat.
## Das Bord zeigt JEDEN Coupon-Archetyp auf seinem festen Platz (Reihenfolge =
## Coupon.all()): Besitz liegt als physischer Coupon darauf (Mehrfache als
## versetzter Stapel mit ×Anzahl), nicht Besessenes ist ausgegraut. Ätzungen, die
## eine zweite Seite brauchen (Meißel = Quellseite, Schleifstein = −1-Seite,
## Anschluss = Quellseite), fragen diese per zweitem Seiten-Klick ab. Jede Ätzung
## wirkt auf genau DIESEN Würfel - es gibt keine Zwei-Würfel-Ätzungen mehr.
##
## Der gezeigte Würfel ist DIESELBE DieDefinition-Instanz wie im Pool (siehe
## scene_root.gd: round_pool_kinds = owned_pool.duplicate() ist eine flache
## Kopie), die Ätzung wirkt also dauerhaft. Nach jeder Anwendung meldet changed,
## damit scene_root die Tray-Anzeigen neu zeichnet.
##
## Schließt bei Klick auf den abgedunkelten Hintergrund oder per Rechtsklick;
## läuft gerade eine mehrschrittige Ätzung (Zweitseite/Wertauswahl), bricht der
## Rechtsklick zunächst nur diese ab (siehe _cancel_pending).

## Nach dem Anwenden einer Ätzung ausgelöst - scene_root zeichnet die Trays neu.
signal changed

## Ablauf-Zustand der Station: normale Seiten-Auswahl, Warten auf die zweite
## Seite (Meißel/Schleifstein/Doppelkerbe/Mittelung/Anschluss) oder Warten auf
## den Zielwert (Feingravur).
enum Mode { SELECT, AWAIT_SECOND_FACE, PICK_VALUE }

## Der laufende Spiellauf (von scene_root gesetzt) - liefert den Coupon-Bestand
## (owned_coupons) und verbucht den Verbrauch (consume_coupon), siehe GameRun.
var run: GameRun

@onready var backdrop: ColorRect = $Backdrop
@onready var die_view: RotatableDieView = $Center/DieView

var current_def: DieDefinition = null
var selected_face: int = -1  # gewählte physische Seite (0..5), -1 = keine
## True, wenn statt einer Seite der KANTEN-Rahmen gewählt ist (Klick auf den
## Rahmen des 3D-Würfels oder den Kanten-Chip der Übersicht) - Ziel der
## Kanten-Coupons (siehe Coupon.KIND_EDGE). Schließt selected_face aus.
var edges_selected: bool = false
var mode: int = Mode.SELECT
var active_coupon_id: String = ""  # Coupon, dessen zweiten Schritt wir gerade auflösen

# Rechts angebautes Gravur-Panel (komplett per Code, siehe _build_panel).
var panel: Panel
var prompt_label: Label
var board_box: VBoxContainer  # Gravur-Bord: Abschnitts-Header + Slot-Raster (siehe _build_coupon_board)
var value_row: GridContainer  # Feingravur-Wertauswahl 1..FINE_ENGRAVING_MAX (6 Spalten)
var slot_entries: Array[Dictionary] = []  # [{button:Button, id:String, count:int}]

# --- Maße des Gravur-Bords: 5 Slots je Zeile, jeder Slot fest so breit wie
# Coupon-Kachel + Innenrand + Platz für den Stapel-Versatz (damit alle Slots
# gleich groß sind, egal ob gestapelt wird). ---
const SLOT_COLUMNS := 5
const TILE_SIZE := Vector2(52, 44)     # sichtbare Coupon-Kachel im Slot
const SLOT_PAD := 3.0                  # Innenrand des Slots um die Kachel
const STACK_OFFSET := Vector2(3.5, 3.5)  # Versatz je tieferem Coupon im Stapel
const STACK_MAX_VISIBLE := 3           # mehr Exemplare zeigt nur noch die ×Anzahl
## Ausgegraut-Färbung eines leeren Platzes: der Coupon liegt als dunkelgraue
## Silhouette auf seinem Platz - klar "noch nicht bekommen", aber die Form
## bleibt erkennbar (welcher Coupon hierher gehört, sagt auch der Tooltip).
const EMPTY_SLOT_TINT := Color(0.3, 0.3, 0.34, 0.9)

# Links angebaute Seiten-Übersicht (siehe _build_summary_panel): je vorkommendem
# Wert ein Mini-Würfelseiten-Chip mit "×Anzahl", darunter die Augensumme.
var summary_panel: Panel
var summary_list: VBoxContainer
var summary_sum_label: Label

func _ready() -> void:
	visible = false
	backdrop.gui_input.connect(_on_backdrop_input)
	die_view.face_clicked.connect(_on_face_clicked)
	die_view.edges_clicked.connect(_on_edges_clicked)
	# Der einzelne Würfel füllt die Vorschau fast ganz - der Kanten-Rahmen
	# (Silhouette) projiziert deutlich weiter von der Würfelmitte weg als die
	# Seiten-Mitten, darum braucht die Klick-Toleranz hier mehr Radius als der
	# Shop-Standardwert (mehrere kleine Würfel nebeneinander).
	die_view.pick_radius = 230.0
	_build_panel()
	_build_summary_panel()

## Öffnet die Station für def (die tatsächliche Pool-Instanz) und setzt den
## Auswahl-/Ablaufzustand zurück. Baut die Coupon-Liste frisch aus dem Bestand.
func show_die(def: DieDefinition) -> void:
	current_def = def
	selected_face = -1
	edges_selected = false
	mode = Mode.SELECT
	active_coupon_id = ""
	die_view.set_dice([def])
	die_view.highlight_face(0, -1)
	_hide_value_picker()
	_build_coupon_board()
	_refresh_face_summary()
	_update_prompt()
	visible = true

func close() -> void:
	visible = false

# --- Seiten-Auswahl / Ätzungs-Anwendung -------------------------------------

## Klick auf eine Würfelseite (siehe RotatableDieView.face_clicked). Je nach
## Modus wählt er die Seite oder liefert die zweite Seite einer laufenden Ätzung.
func _on_face_clicked(_die_index: int, face_index: int) -> void:
	if mode == Mode.AWAIT_SECOND_FACE:
		_complete_two_step(face_index)
		return
	# Neue Auswahl - bricht eine offene Wertauswahl (Feingravur) mit ab.
	selected_face = face_index
	edges_selected = false
	mode = Mode.SELECT
	active_coupon_id = ""
	_hide_value_picker()
	die_view.highlight_face(0, selected_face)
	_refresh_face_summary()  # Chip des gewählten Werts hervorheben
	_update_prompt()
	_refresh_coupon_enabled()

## Klick auf den KANTEN-Rahmen des 3D-Würfels (oder den Kanten-Chip der
## Übersicht): wählt die Kanten als Gravur-Ziel - danach lassen sich die
## Kanten-Coupons anwenden. Läuft gerade der zweite Schritt einer Ätzung,
## zählt der Rahmen nicht als Seite und wird ignoriert.
func _on_edges_clicked(_die_index: int = 0) -> void:
	if mode == Mode.AWAIT_SECOND_FACE:
		prompt_label.text = "Bitte eine SEITE anklicken - Kanten sind hier kein Ziel."
		return
	edges_selected = true
	selected_face = -1
	mode = Mode.SELECT
	active_coupon_id = ""
	_hide_value_picker()
	die_view.highlight_edges(0)
	_refresh_face_summary()  # Kanten-Chip hervorheben
	_update_prompt()
	_refresh_coupon_enabled()

## Klick auf einen Wert-Chip der Seiten-Übersicht (siehe _face_chip): wählt eine
## Seite dieses Werts und leitet sie durch dieselbe Logik wie ein Klick auf die
## 3D-Würfelseite (_on_face_clicked) - so lassen sich Ätzungen auch komplett über
## die Übersicht setzen. Beim zweiten Schritt (Meißel-Quelle, Schleifstein-Minus)
## wird möglichst eine ANDERE Seite als die gewählte genommen (siehe
## _face_index_for_value), damit gleiche Werte nicht auf sich selbst verweisen.
func _on_chip_clicked(value: int) -> void:
	if current_def == null:
		return
	var exclude: int = selected_face if mode == Mode.AWAIT_SECOND_FACE else -1
	var face_index := _face_index_for_value(value, exclude)
	if face_index != -1:
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

## Klick auf einen Coupon-Button. Einstufige Ätzungen wirken sofort auf die
## gewählte Seite; mehrstufige gehen in den passenden Wart-Modus über.
## Material-Coupons (Coupon-id = Material-id, siehe DieMaterial) belegen die
## gewählte Seite sofort - ein neues Material ersetzt ein vorhandenes.
## Kanten-Coupons (siehe Coupon.KIND_EDGE) veredeln den GANZEN Würfel - ihr
## Ziel ist der gewählte KANTEN-Rahmen (edges_selected) statt einer Seite.
func _on_coupon_pressed(coupon_id: String) -> void:
	if mode != Mode.SELECT:
		return
	if Coupon.is_edge_id(coupon_id):
		if not edges_selected:
			return
		var material_id := coupon_id.trim_prefix(Coupon.EDGE_PREFIX)
		if current_def.edge_material == material_id:
			prompt_label.text = "Die Kanten tragen bereits %s." % DieMaterial.by_id(material_id).display_name
			return
		current_def.edge_material = material_id
		_finish_apply(coupon_id, "Kanten veredelt: %s" % DieMaterial.by_id(material_id).display_name)
		return
	if selected_face == -1:
		return
	if DieMaterial.is_valid_id(coupon_id):
		if current_def.materials[selected_face] == coupon_id:
			prompt_label.text = "Diese Seite trägt bereits %s." % DieMaterial.by_id(coupon_id).display_name
			return
		current_def.materials[selected_face] = coupon_id
		_finish_apply(coupon_id, "Material angebracht: %s" % DieMaterial.by_id(coupon_id).display_name)
		return
	match coupon_id:
		Coupon.OVERCOUNT_ENGRAVING:
			EtchingEffects.overcount_engraving(current_def, selected_face)
			_finish_apply(coupon_id, "Überzahl-Gravur: Seite +1")
		Coupon.FINE_ENGRAVING:
			mode = Mode.PICK_VALUE
			active_coupon_id = coupon_id
			_show_value_picker()
			prompt_label.text = "Feingravur: Zielwert 1–12 wählen."
			_refresh_coupon_enabled()
		Coupon.CHISEL:
			mode = Mode.AWAIT_SECOND_FACE
			active_coupon_id = coupon_id
			prompt_label.text = "Meißel: klicke die Quellseite (ihr Wert wird auf die gewählte Seite kopiert)."
			_refresh_coupon_enabled()
		Coupon.GRINDSTONE:
			mode = Mode.AWAIT_SECOND_FACE
			active_coupon_id = coupon_id
			prompt_label.text = "Schleifstein: gewählte Seite bekommt +1 – klicke jetzt die Seite für −1."
			_refresh_coupon_enabled()
		Coupon.FILE_DOWN:
			if not EtchingEffects.can_file_down(current_def, selected_face):
				prompt_label.text = "Feile: diese Seite ist schon 1."
				return
			EtchingEffects.file_down(current_def, selected_face)
			_finish_apply(coupon_id, "Feile: Seite −1")
		Coupon.DOUBLE_NOTCH:
			mode = Mode.AWAIT_SECOND_FACE
			active_coupon_id = coupon_id
			prompt_label.text = "Doppelkerbe: gewählte Seite +1 – klicke die zweite Seite (auch +1)."
			_refresh_coupon_enabled()
		Coupon.AVERAGING:
			mode = Mode.AWAIT_SECOND_FACE
			active_coupon_id = coupon_id
			prompt_label.text = "Mittelung: klicke die zweite Seite – beide werden ihr aufgerundeter Mittelwert."
			_refresh_coupon_enabled()
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
			mode = Mode.AWAIT_SECOND_FACE
			active_coupon_id = coupon_id
			prompt_label.text = "Anschluss: klicke die Quellseite – die gewählte Seite wird ihr Wert + 1."
			_refresh_coupon_enabled()
		Coupon.IMPRINT:
			EtchingEffects.imprint(current_def, selected_face)
			_finish_apply(coupon_id, "Abdruck: auf die zwei niedrigsten Seiten geprägt")
		Coupon.BLUEPRINT:
			EtchingEffects.blueprint(current_def, selected_face)
			_finish_apply(coupon_id, "Blaupause: ganzer Würfel auf den gewählten Wert gesetzt")

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

## Verbraucht den Coupon, aktualisiert Würfel- und Panel-Anzeige und meldet die
## Änderung. Die gewählte Seite bleibt gewählt, damit man direkt weitergravieren kann.
func _finish_apply(coupon_id: String, message: String) -> void:
	if run != null:
		run.consume_coupon(coupon_id)
	mode = Mode.SELECT
	active_coupon_id = ""
	die_view.refresh_faces([current_def])
	if edges_selected:
		die_view.highlight_edges(0)
	else:
		die_view.highlight_face(0, selected_face)
	changed.emit()
	_build_coupon_board()  # Anzahl hat sich geändert
	_refresh_face_summary()
	prompt_label.text = "%s. Weiter gravieren oder Rechtsklick zum Schließen." % message

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
		prompt_label.text = "Klicke eine Würfelseite (oder die Kanten), um sie zu wählen."
	else:
		prompt_label.text = "Seite gewählt (Wert %d). Wähle eine Ätzung." % current_def.faces[selected_face]

# --- Panel-Aufbau ------------------------------------------------------------

## Baut das rechte Gravur-Panel einmalig per Code auf (Titel, Hinweiszeile,
## Gravur-Bord, Wertauswahl-Reihe). Die Slots des Bords entstehen später je
## Öffnung neu aus dem Bestand (_build_coupon_board).
func _build_panel() -> void:
	panel = Panel.new()
	panel.offset_left = 858.0
	panel.offset_top = 110.0
	panel.offset_right = 1240.0
	panel.offset_bottom = 812.0
	CasinoStyle.style_panel(panel)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16.0
	vbox.offset_top = 16.0
	vbox.offset_right = -16.0
	vbox.offset_bottom = -16.0
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Gravur"
	CasinoStyle.style_score_label(title, 24, CasinoStyle.GOLD)
	vbox.add_child(title)

	prompt_label = Label.new()
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.custom_minimum_size = Vector2(0, 56)
	CasinoStyle.style_body_label(prompt_label, 15, CasinoStyle.CREAM)
	vbox.add_child(prompt_label)

	board_box = VBoxContainer.new()
	board_box.add_theme_constant_override("separation", 8)
	board_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(board_box)

	value_row = GridContainer.new()
	value_row.columns = 6  # 1..6 in der oberen, 7..FINE_ENGRAVING_MAX in der unteren Reihe
	value_row.add_theme_constant_override("h_separation", 6)
	value_row.add_theme_constant_override("v_separation", 6)
	value_row.visible = false
	for value in range(1, EtchingEffects.FINE_ENGRAVING_MAX + 1):
		var value_button := Button.new()
		value_button.text = str(value)
		value_button.custom_minimum_size = Vector2(0, 44)
		value_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_button.pressed.connect(_on_value_pressed.bind(value))
		CasinoStyle.style_button(value_button, CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, 18)
		value_row.add_child(value_button)
	vbox.add_child(value_row)

## Baut das linke Seiten-Übersichts-Panel einmalig auf (Titel + Listen-Container
## + Augensummen-Zeile). Die Wert-Chips selbst baut _refresh_face_summary bei
## jeder Änderung neu; die Panel-Höhe wächst dabei mit der Zeilenzahl mit.
func _build_summary_panel() -> void:
	summary_panel = Panel.new()
	summary_panel.offset_left = 40.0
	summary_panel.offset_top = 150.0
	summary_panel.offset_right = 280.0
	summary_panel.offset_bottom = 620.0
	CasinoStyle.style_panel(summary_panel)
	add_child(summary_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16.0
	vbox.offset_top = 14.0
	vbox.offset_right = -16.0
	vbox.offset_bottom = -14.0
	vbox.add_theme_constant_override("separation", 10)
	summary_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Seiten"
	CasinoStyle.style_score_label(title, 24, CasinoStyle.GOLD)
	vbox.add_child(title)

	summary_list = VBoxContainer.new()
	summary_list.add_theme_constant_override("separation", 8)
	vbox.add_child(summary_list)

	summary_sum_label = Label.new()
	CasinoStyle.style_chip_label(summary_sum_label, 16, CasinoStyle.GOLD)
	vbox.add_child(summary_sum_label)

## Baut die Wert-Chips der Seiten-Übersicht neu aus current_def.faces: je
## vorkommendem Wert (aufsteigend) ein Mini-Würfelseiten-Chip mit "×Anzahl";
## der Wert der gerade gewählten Seite bekommt den goldenen Auswahl-Look des
## 3D-Würfels. Darunter die Augensumme (bleibt z.B. beim Schleifstein gleich).
func _refresh_face_summary() -> void:
	for child in summary_list.get_children():
		child.queue_free()
	if current_def == null:
		return

	var counts := {}
	var total := 0
	for value in current_def.faces:
		counts[value] = counts.get(value, 0) + 1
		total += value
	var values := counts.keys()
	values.sort()
	var selected_value: int = current_def.faces[selected_face] if selected_face != -1 else -1

	for value in values:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(_face_chip(value, value == selected_value))
		var count_label := Label.new()
		count_label.text = "× %d" % counts[value]
		count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		CasinoStyle.style_score_label(count_label, 20, CasinoStyle.CREAM)
		row.add_child(count_label)
		summary_list.add_child(row)

	# Kanten-Zeile: anklickbarer Chip (wählt den Kanten-Rahmen als Gravur-Ziel,
	# wie ein Klick auf den Rahmen des 3D-Würfels) + aktuelles Kanten-Material.
	var edge_row := HBoxContainer.new()
	edge_row.add_theme_constant_override("separation", 12)
	edge_row.add_child(_edge_chip(edges_selected))
	var edge_label := Label.new()
	edge_label.text = DieMaterial.by_id(current_def.edge_material).display_name \
		if DieMaterial.is_valid_id(current_def.edge_material) else "ohne"
	edge_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	CasinoStyle.style_body_label(edge_label, 15, CasinoStyle.CREAM)
	edge_row.add_child(edge_label)
	summary_list.add_child(edge_row)

	summary_sum_label.text = "Augensumme: %d" % total
	# Panel-Höhe an die Zeilenzahl anpassen (46er-Chips + 8 Abstand + Kopf/Fuß)
	# plus die Kanten-Zeile.
	summary_panel.offset_bottom = summary_panel.offset_top + 124.0 + (values.size() + 1) * 54.0

## Ein anklickbarer Mini-Würfelseiten-Chip im Look der echten Würfel (weiß,
## abgerundet, dunkle Ziffer); highlighted = goldener Auswahl-Look (siehe
## RotatableDieView.SELECT_FACE_COLOR). Ein Klick wählt eine Seite dieses Werts
## zum Gravieren - dieselbe Wirkung wie ein Klick auf die 3D-Würfelseite (siehe
## _on_chip_clicked), damit man Ätzungen auch über die Übersicht steuern kann.
func _face_chip(value: int, highlighted: bool) -> Button:
	var chip := Button.new()
	chip.text = str(value)
	chip.custom_minimum_size = Vector2(46, 46)
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.add_theme_font_size_override("font_size", 24)
	chip.add_theme_color_override("font_color", CasinoStyle.INK)
	chip.add_theme_color_override("font_hover_color", CasinoStyle.INK)
	chip.add_theme_color_override("font_pressed_color", CasinoStyle.INK)
	var fill := RotatableDieView.SELECT_FACE_COLOR if highlighted else Color.WHITE
	var border := CasinoStyle.GOLD_DARK if highlighted else Color(0.72, 0.76, 0.8)
	chip.add_theme_stylebox_override("normal", _chip_box(fill, border))
	chip.add_theme_stylebox_override("hover", _chip_box(fill.lightened(0.12), CasinoStyle.GOLD))
	chip.add_theme_stylebox_override("pressed", _chip_box(fill.darkened(0.1), border))
	chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	chip.pressed.connect(_on_chip_clicked.bind(value))
	return chip

## Der anklickbare "Kanten"-Chip der Seiten-Übersicht: gefüllt mit dem Tint des
## aktuellen Kanten-Materials (Rahmen-Neutral ohne), gold hervorgehoben, wenn
## der Kanten-Rahmen gerade das Gravur-Ziel ist. Ein Klick wählt die Kanten -
## dieselbe Wirkung wie ein Klick auf den Rahmen des 3D-Würfels.
func _edge_chip(highlighted: bool) -> Button:
	var chip := Button.new()
	chip.text = "Kanten"
	chip.custom_minimum_size = Vector2(86, 46)
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.add_theme_font_size_override("font_size", 16)
	chip.add_theme_color_override("font_color", CasinoStyle.INK)
	chip.add_theme_color_override("font_hover_color", CasinoStyle.INK)
	chip.add_theme_color_override("font_pressed_color", CasinoStyle.INK)
	var material_tint := DieMaterial.tint_for(current_def.edge_material)
	var neutral := material_tint if material_tint != Color.WHITE else DieFaceDisplay.EDGE_COLOR
	var fill := RotatableDieView.SELECT_FACE_COLOR if highlighted else neutral
	var border := CasinoStyle.GOLD_DARK if highlighted else Color(0.72, 0.76, 0.8)
	chip.add_theme_stylebox_override("normal", _chip_box(fill, border))
	chip.add_theme_stylebox_override("hover", _chip_box(fill.lightened(0.12), CasinoStyle.GOLD))
	chip.add_theme_stylebox_override("pressed", _chip_box(fill.darkened(0.1), border))
	chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	chip.pressed.connect(_on_edges_clicked)
	return chip

func _chip_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.shadow_color = CasinoStyle.SHADOW
	box.shadow_size = 3
	box.shadow_offset = Vector2(0, 2)
	return box

## Baut das Gravur-Bord neu: JEDER Coupon-Archetyp bekommt seinen festen Platz
## (Reihenfolge = kanonische Coupon.all()-Reihenfolge, getrennt nach Ätzungen
## und Materialien). Besitz liegt als physischer Coupon auf dem Platz - Mehrfache
## als versetzter Stapel mit ×Anzahl -, nicht Besessenes als ausgegrauter Schatten.
func _build_coupon_board() -> void:
	slot_entries.clear()
	for child in board_box.get_children():
		child.queue_free()

	var counts := _coupon_counts()
	var etchings: Array[Coupon] = []
	var materials: Array[Coupon] = []
	var edges: Array[Coupon] = []
	for archetype in Coupon.all():
		match archetype.kind:
			Coupon.KIND_MATERIAL:
				materials.append(archetype)
			Coupon.KIND_EDGE:
				edges.append(archetype)
			_:
				etchings.append(archetype)
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

## Ein Bord-Abschnitt: kleiner Header + festes Slot-Raster (SLOT_COLUMNS breit).
func _add_board_section(title: String, archetypes: Array[Coupon], counts: Dictionary) -> void:
	var header := Label.new()
	header.text = title
	CasinoStyle.style_body_label(header, 14, CasinoStyle.MUTED)
	board_box.add_child(header)

	var grid := GridContainer.new()
	grid.columns = SLOT_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	board_box.add_child(grid)

	for archetype in archetypes:
		var count: int = counts.get(archetype.id, 0)
		var slot := _coupon_slot(archetype, count)
		grid.add_child(slot)
		slot_entries.append({"button": slot, "id": archetype.id, "count": count})

## Ein einzelner Bord-Platz: Button als "Mulde" (fester Rahmen), darin der
## Coupon als Kachel - bei Mehrfachbesitz als Stapel (bis STACK_MAX_VISIBLE
## sichtbar versetzte Exemplare, die tieferen leicht abgedunkelt) plus
## ×Anzahl-Abzeichen. Ohne Besitz liegt nur der ausgegraute Schatten der Kachel
## im Slot. Klick = Coupon anwenden (wie bisher _on_coupon_pressed).
func _coupon_slot(archetype: Coupon, count: int) -> Button:
	var slot := Button.new()
	var stack_margin := STACK_OFFSET * float(STACK_MAX_VISIBLE - 1)
	slot.custom_minimum_size = TILE_SIZE + Vector2.ONE * (SLOT_PAD * 2.0) + stack_margin
	slot.focus_mode = Control.FOCUS_NONE
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var state := ("×%d im Bestand" % count) if count > 0 else "nicht im Bestand"
	slot.tooltip_text = "%s (%s)\n%s" % [archetype.display_name, state, archetype.description]
	slot.pressed.connect(_on_coupon_pressed.bind(archetype.id))
	slot.add_theme_stylebox_override("normal", _slot_box(Color(1, 1, 1, 0.12)))
	slot.add_theme_stylebox_override("hover", _slot_box(CasinoStyle.GOLD))
	slot.add_theme_stylebox_override("pressed", _slot_box(CasinoStyle.GOLD_DARK))
	slot.add_theme_stylebox_override("disabled", _slot_box(Color(1, 1, 1, 0.08)))
	slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# Stapel von hinten nach vorn aufbauen (tiefere Exemplare zuerst = untendrunter).
	var depth: int = clampi(count, 1, STACK_MAX_VISIBLE)
	for i in range(depth - 1, -1, -1):
		var tile := _coupon_tile(archetype)
		tile.position = Vector2.ONE * SLOT_PAD + STACK_OFFSET * float(i)
		tile.size = TILE_SIZE
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if count == 0:
			tile.modulate = EMPTY_SLOT_TINT  # nur der Schatten des Coupons
		elif i > 0:
			tile.modulate = Color(0.78, 0.78, 0.78)  # tiefere Stapel-Exemplare dunkler
		slot.add_child(tile)

	if count > 1:
		var badge := Label.new()
		badge.text = "×%d" % count
		badge.position = Vector2(SLOT_PAD + TILE_SIZE.x - 26.0, SLOT_PAD + TILE_SIZE.y - 16.0)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", CasinoStyle.GOLD)
		var badge_box := StyleBoxFlat.new()
		badge_box.bg_color = Color(0, 0, 0, 0.72)
		badge_box.set_corner_radius_all(6)
		badge_box.set_content_margin_all(3)
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
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", CouponSheetView.PERF_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.add_child(label)
	return placeholder

## Die "Mulde" eines Bord-Platzes: dunkel eingelassene Fläche mit dünnem Rand.
func _slot_box(border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.22)
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
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
## Kanten-Coupons den gewählten KANTEN-Rahmen (edges_selected).
func _refresh_coupon_enabled() -> void:
	for entry in slot_entries:
		var is_edge: bool = Coupon.is_edge_id(entry["id"])
		var has_target: bool = edges_selected if is_edge else selected_face != -1
		entry["button"].disabled = entry["count"] == 0 or mode != Mode.SELECT or not has_target

func _show_value_picker() -> void:
	value_row.visible = true

func _hide_value_picker() -> void:
	value_row.visible = false

# --- Schließen ---------------------------------------------------------------

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

## Rechtsklick über _input (statt _gui_input), damit er auch direkt über dem
## Würfel-Viewport greift und die Kamera nicht gleichzeitig rauszoomt. Bricht
## zuerst eine laufende mehrschrittige Ätzung ab, sonst schließt er die Station.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if mode != Mode.SELECT:
			_cancel_pending()
		else:
			close()
		get_viewport().set_input_as_handled()
