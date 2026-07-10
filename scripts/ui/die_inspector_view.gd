class_name DieInspectorView
extends Control
## Modale Gravur-Station für einen einzelnen Würfel: erscheint über allem
## anderen, dimmt den Hintergrund ab und zeigt den Würfel groß und frei drehbar
## (siehe RotatableDieView, hier mit genau einem Würfel). Wird von scene_root.gd
## geöffnet, sobald im gezoomten Pool-/Ablage-/Warteschlangen-Tray auf einen
## sichtbaren Würfel geklickt wird.
##
## Hier wendet der Spieler seine Ätzungs-Coupons an (siehe Coupon/EtchingEffects):
## Er klickt eine Würfelseite (Auswahl, gold hervorgehoben) und danach eine
## Ätzung im rechten Panel - beliebig oft, solange er Coupons hat. Ätzungen, die
## eine zweite Seite brauchen (Meißel = Quellseite, Schleifstein = −1-Seite),
## fragen diese per zweitem Seiten-Klick ab. Transplantat (tauscht zwischen zwei
## Würfeln) ist hier bewusst nicht anwendbar und bleibt deaktiviert.
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
## Seite (Meißel/Schleifstein/Doppelkerbe/Mittelung) oder Warten auf den Zielwert
## (Feingravur).
enum Mode { SELECT, AWAIT_SECOND_FACE, PICK_VALUE }

## Ätzungen, die einen ZWEITEN Würfel brauchen - in dieser Einzelwürfel-Station
## noch nicht anwendbar, daher sichtbar, aber gesperrt ("braucht 2 Würfel"). Die
## Zwei-Würfel-Auswahl kommt mit dem späteren Ausbau (siehe Obsidian: Anschluss/
## Abdruck/Blaupause/Transplantat).
const CROSS_DIE_COUPONS: Array[String] = [
	Coupon.TRANSPLANT, Coupon.CONNECT_UP, Coupon.IMPRINT, Coupon.BLUEPRINT,
]

## Der laufende Spiellauf (von scene_root gesetzt) - liefert den Coupon-Bestand
## (owned_coupons) und verbucht den Verbrauch (consume_coupon), siehe GameRun.
var run: GameRun

@onready var backdrop: ColorRect = $Backdrop
@onready var die_view: RotatableDieView = $Center/DieView

var current_def: DieDefinition = null
var selected_face: int = -1  # gewählte physische Seite (0..5), -1 = keine
var mode: int = Mode.SELECT
var active_coupon_id: String = ""  # Coupon, dessen zweiten Schritt wir gerade auflösen

# Rechts angebautes Gravur-Panel (komplett per Code, siehe _build_panel).
var panel: Panel
var prompt_label: Label
var coupon_list: VBoxContainer
var value_row: HBoxContainer
var coupon_entries: Array[Dictionary] = []  # [{button:Button, id:String}]

# Links angebaute Seiten-Übersicht (siehe _build_summary_panel): je vorkommendem
# Wert ein Mini-Würfelseiten-Chip mit "×Anzahl", darunter die Augensumme.
var summary_panel: Panel
var summary_list: VBoxContainer
var summary_sum_label: Label

func _ready() -> void:
	visible = false
	backdrop.gui_input.connect(_on_backdrop_input)
	die_view.face_clicked.connect(_on_face_clicked)
	_build_panel()
	_build_summary_panel()

## Öffnet die Station für def (die tatsächliche Pool-Instanz) und setzt den
## Auswahl-/Ablaufzustand zurück. Baut die Coupon-Liste frisch aus dem Bestand.
func show_die(def: DieDefinition) -> void:
	current_def = def
	selected_face = -1
	mode = Mode.SELECT
	active_coupon_id = ""
	die_view.set_dice([def])
	die_view.highlight_face(0, -1)
	_hide_value_picker()
	_build_coupon_buttons()
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
	mode = Mode.SELECT
	active_coupon_id = ""
	_hide_value_picker()
	die_view.highlight_face(0, selected_face)
	_refresh_face_summary()  # Chip des gewählten Werts hervorheben
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
func _on_coupon_pressed(coupon_id: String) -> void:
	if selected_face == -1 or mode != Mode.SELECT:
		return
	match coupon_id:
		Coupon.OVERCOUNT_ENGRAVING:
			EtchingEffects.overcount_engraving(current_def, selected_face)
			_finish_apply(coupon_id, "Überzahl-Gravur: Seite +1")
		Coupon.FINE_ENGRAVING:
			mode = Mode.PICK_VALUE
			active_coupon_id = coupon_id
			_show_value_picker()
			prompt_label.text = "Feingravur: Zielwert 1–6 wählen."
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
			if not EtchingEffects.can_notch(current_def, selected_face):
				prompt_label.text = "Doppelkerbe: gewählte Seite ist schon 6."
				return
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
		# Cross-Würfel-Ätzungen (siehe CROSS_DIE_COUPONS) sind hier gesperrt - kein Fall nötig.

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
			if not EtchingEffects.can_notch(current_def, second_face):
				prompt_label.text = "Doppelkerbe: diese Seite ist schon 6 – wähle eine andere."
				return
			EtchingEffects.double_notch(current_def, selected_face, second_face)
			_finish_apply(active_coupon_id, "Doppelkerbe: zwei Seiten +1")
		Coupon.AVERAGING:
			EtchingEffects.averaging(current_def, selected_face, second_face)
			_finish_apply(active_coupon_id, "Mittelung: zwei Seiten gemittelt")

## Verbraucht den Coupon, aktualisiert Würfel- und Panel-Anzeige und meldet die
## Änderung. Die gewählte Seite bleibt gewählt, damit man direkt weitergravieren kann.
func _finish_apply(coupon_id: String, message: String) -> void:
	if run != null:
		run.consume_coupon(coupon_id)
	mode = Mode.SELECT
	active_coupon_id = ""
	die_view.refresh_faces([current_def])
	die_view.highlight_face(0, selected_face)
	changed.emit()
	_build_coupon_buttons()  # Anzahl hat sich geändert
	_refresh_face_summary()
	prompt_label.text = "%s. Weiter gravieren oder Rechtsklick zum Schließen." % message

func _cancel_pending() -> void:
	mode = Mode.SELECT
	active_coupon_id = ""
	_hide_value_picker()
	_update_prompt()
	_refresh_coupon_enabled()

func _update_prompt() -> void:
	if selected_face == -1:
		prompt_label.text = "Klicke eine Würfelseite, um sie zu wählen."
	else:
		prompt_label.text = "Seite gewählt (Wert %d). Wähle eine Ätzung." % current_def.faces[selected_face]

# --- Panel-Aufbau ------------------------------------------------------------

## Baut das rechte Gravur-Panel einmalig per Code auf (Titel, Hinweiszeile,
## Coupon-Liste, Wertauswahl-Reihe). Die Coupon-Buttons selbst entstehen später
## je Öffnung neu aus dem Bestand (_build_coupon_buttons).
func _build_panel() -> void:
	panel = Panel.new()
	panel.offset_left = 858.0
	panel.offset_top = 150.0
	panel.offset_right = 1240.0
	panel.offset_bottom = 752.0
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

	coupon_list = VBoxContainer.new()
	coupon_list.add_theme_constant_override("separation", 8)
	coupon_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(coupon_list)

	value_row = HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 6)
	value_row.visible = false
	for value in range(1, EtchingEffects.MAX_ENGRAVING_VALUE + 1):
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

	summary_sum_label.text = "Augensumme: %d" % total
	# Panel-Höhe an die Zeilenzahl anpassen (46er-Chips + 8 Abstand + Kopf/Fuß).
	summary_panel.offset_bottom = summary_panel.offset_top + 124.0 + values.size() * 54.0

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

## Baut die Coupon-Buttons neu aus dem Bestand (run.owned_coupons), gruppiert
## nach Typ mit Anzahl. Reihenfolge = kanonische Coupon.all()-Reihenfolge.
func _build_coupon_buttons() -> void:
	coupon_entries.clear()
	for child in coupon_list.get_children():
		child.queue_free()

	var counts := _coupon_counts()
	if counts.is_empty():
		var empty := Label.new()
		empty.text = "Keine Ätzungen im Bestand.\nKaufe Coupon-Packs im Shop."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		CasinoStyle.style_body_label(empty, 15, CasinoStyle.MUTED)
		coupon_list.add_child(empty)
		return

	for archetype in Coupon.all():
		var count: int = counts.get(archetype.id, 0)
		if count == 0:
			continue
		var button := Button.new()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 62)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = archetype.description
		var accent := _rarity_accent(archetype.rarity)
		if archetype.id in CROSS_DIE_COUPONS:
			# Hier nicht anwendbar (braucht zwei Würfel) - sichtbar, aber gesperrt.
			button.text = "%s ×%d\nHier nicht anwendbar (braucht 2 Würfel)" % [archetype.display_name, count]
			CasinoStyle.style_button(button, CasinoStyle.GREEN, CasinoStyle.GREEN_DARK, 14)
			button.disabled = true
		else:
			button.text = "%s ×%d\n%s" % [archetype.display_name, count, archetype.description]
			button.pressed.connect(_on_coupon_pressed.bind(archetype.id))
			CasinoStyle.style_button(button, accent[0], accent[1], 14)
		coupon_list.add_child(button)
		coupon_entries.append({"button": button, "id": archetype.id})
	_refresh_coupon_enabled()

## Zählt den Coupon-Bestand nach id (id -> Anzahl).
func _coupon_counts() -> Dictionary:
	var counts := {}
	if run == null:
		return counts
	for coupon in run.owned_coupons:
		counts[coupon.id] = counts.get(coupon.id, 0) + 1
	return counts

## Sperrt Coupon-Buttons, wenn keine Seite gewählt ist oder gerade ein zweiter
## Schritt läuft; Cross-Würfel-Ätzungen (CROSS_DIE_COUPONS) bleiben immer gesperrt.
func _refresh_coupon_enabled() -> void:
	var can_apply: bool = selected_face != -1 and mode == Mode.SELECT
	for entry in coupon_entries:
		if entry["id"] in CROSS_DIE_COUPONS:
			entry["button"].disabled = true
		else:
			entry["button"].disabled = not can_apply

func _show_value_picker() -> void:
	value_row.visible = true

func _hide_value_picker() -> void:
	value_row.visible = false

## Akzentfarbe (Füllung, Rand) je Seltenheit - häufig blau, ungewöhnlich lila,
## selten gold (siehe CasinoStyle).
func _rarity_accent(rarity: int) -> Array:
	match rarity:
		Coupon.Rarity.COMMON:
			return [CasinoStyle.BLUE, CasinoStyle.BLUE_DARK]
		Coupon.Rarity.UNCOMMON:
			return [CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK]
		Coupon.Rarity.RARE:
			return [CasinoStyle.GOLD, CasinoStyle.GOLD_DARK]
	return [CasinoStyle.GREEN, CasinoStyle.GREEN_DARK]

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
