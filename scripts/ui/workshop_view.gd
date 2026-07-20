class_name WorkshopView
extends Panel
## Tisch-Fenster rechts vom Hub: das Lager der gekauften, noch VERSIEGELTEN
## Pakete. Hier - und nur hier - werden sie geöffnet; der Laden verkauft nur.
## Zustands-Mutation läuft über GameRun (open_pack); die Zeremonie hängt an
## pack_activated und lebt in scene_root.

## Ein Paket wurde geöffnet (scene_root hängt Ton/Licht daran).
signal pack_activated(index: int)
## Ein Paket-Würfel hat einen Pool-Platz eingenommen.
signal die_placed(pool_index: int)

const TITLE_COLOR := Color("#8be9fd")
const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")

## Farbe je Paketsorte - dieselbe Zuordnung wie im Laden.
const PACK_COLORS := {
	Pack.TYPE_DICE: Color("#8be9fd"),
	Pack.TYPE_NUMBER: Color("#50fa7b"),
	Pack.TYPE_MATERIAL: Color("#ff79c6"),
	Pack.TYPE_EDGE: Color("#ffd319"),
}

var run: GameRun:
	set(value):
		if run == value:
			return
		if run != null and run.packs_changed.is_connected(refresh):
			run.packs_changed.disconnect(refresh)
			run.engravings_changed.disconnect(refresh)
		run = value
		if run != null:
			run.packs_changed.connect(refresh)
			run.engravings_changed.connect(refresh)  # das Vorräte-Regal zeigt den Bestand
		refresh()

## Werkbank-Zustand: das Lager, oder die Zeremonie eines offenen Pakets.
## Die Gravur-Station ist KEINE Phase - sie liegt als eigenes Panel darüber
## (siehe attach_station) und blendet den Lager-Inhalt aus, solange sie offen ist.
enum Phase { STASH, REVEAL_ENGRAVINGS, REVEAL_DICE, PICK_POOL }

var _content: VBoxContainer
## Öffnen-Knöpfe der Lagerkarten, Reihenfolge = owned_packs.
var _pack_buttons: Array[Button] = []

## Die Gravur-Station als angehängtes Vollflächen-Panel (setzt scene_root).
var _station: Control

var _phase: Phase = Phase.STASH
## Inhalt des gerade geöffneten Pakets.
var _revealed_engravings: Array[Engraving] = []
var _revealed_dice: Array[DieDefinition] = []
## Welcher Paket-Würfel gerade dran ist (Einsetzen oder Ablehnen).
var _die_index := 0
## Platz-Knöpfe der Pool-Auswahl (nur in PICK_POOL).
var _pool_buttons: Array[Button] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # die Knöpfe fangen selbst
	clip_contents = true
	add_theme_stylebox_override("panel", TableScreen.window_style())
	refresh()

## Hängt die Gravur-Station als Vollflächen-Panel an: ab jetzt gilt die
## Eine-Ansicht-Regel - solange sie sichtbar ist, ruht der Lager-Inhalt.
func attach_station(panel: Control) -> void:
	_station = panel
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visibility_changed.connect(refresh)
	refresh()

func _station_open() -> bool:
	return _station != null and is_instance_valid(_station) and _station.visible

func refresh() -> void:
	if not is_inside_tree():
		return
	var u := maxf(size.x, 200.0) / 100.0
	if _content != null and is_instance_valid(_content):
		remove_child(_content)
		_content.queue_free()
	_pack_buttons.clear()
	if _station_open():
		return  # die Station füllt das Fenster allein

	_content = VBoxContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = u * 3.0
	_content.offset_right = -u * 3.0
	_content.offset_top = u * 2.2
	_content.offset_bottom = -u * 2.2
	_content.add_theme_constant_override("separation", int(u * 1.6))
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_content.add_child(_label("WERKSTATT", u * 5.0, TITLE_COLOR))

	match _phase:
		Phase.REVEAL_ENGRAVINGS:
			_build_engraving_reveal(u)
			return
		Phase.REVEAL_DICE:
			_build_dice_reveal(u)
			return
		Phase.PICK_POOL:
			_build_pool_picker(u)
			return

	_build_pack_shelf(u)
	_build_supply_shelf(u)

## Oberes Regal: die versiegelten Pakete, je eines eine Karte.
func _build_pack_shelf(u: float) -> void:
	var packs: Array[Pack] = []
	if run != null:
		packs = run.owned_packs
	if packs.is_empty():
		var hint := _label("Kein Paket im Lager – im Laden gibt es welche.", u * 2.4, MUTED_COLOR)
		hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_content.add_child(hint)
		return

	var shelf := HFlowContainer.new()
	shelf.add_theme_constant_override("h_separation", int(u * 1.2))
	shelf.add_theme_constant_override("v_separation", int(u * 1.2))
	shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(shelf)
	for i in packs.size():
		shelf.add_child(_pack_card(packs[i], i, u))

## Unteres Regal: der Gravur-Bestand auf einen Blick - je Sorte EIN Chip mit
## ×Anzahl. Nur Anzeige; angewandt wird an der Station.
func _build_supply_shelf(u: float) -> void:
	var counts := _engraving_counts()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u * 1.0))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(row)
	row.add_child(_label("VORRÄTE", u * 2.2, TITLE_COLOR))
	if counts.is_empty():
		row.add_child(_label("leer", u * 2.2, MUTED_COLOR))
		return

	var strip := HFlowContainer.new()
	strip.add_theme_constant_override("h_separation", int(u * 0.8))
	strip.add_theme_constant_override("v_separation", int(u * 0.6))
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(strip)
	# Kanonische Reihenfolge (Engraving.all()), damit die Chips nicht springen.
	for archetype in Engraving.all():
		if counts.has(archetype.id):
			strip.add_child(_supply_chip(archetype, counts[archetype.id], u))

## Bestand je Gravur-id (leer, wenn nichts auf Lager liegt).
func _engraving_counts() -> Dictionary:
	var counts := {}
	if run == null:
		return counts
	for engraving in run.owned_engravings:
		counts[engraving.id] = counts.get(engraving.id, 0) + 1
	return counts

## Ein Vorrats-Chip: Siegel im Seltenheits-Saum, daneben die Stückzahl.
func _supply_chip(archetype: Engraving, count: int, u: float) -> Control:
	var chip := PanelContainer.new()
	chip.tooltip_text = "%s – %s" % [archetype.display_name, archetype.description]
	chip.mouse_filter = Control.MOUSE_FILTER_STOP  # nur für den Tooltip
	var seam: Color = EngravingRenderer.SEAM_COLORS[archetype.rarity]
	chip.add_theme_stylebox_override("panel", _button_box(Color("#1b1738cc"), seam))

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", int(u * 0.4))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(box)
	var face := EngravingRenderer.for_engraving(archetype)
	face.custom_minimum_size = Vector2(u * 3.4, u * 3.4)
	box.add_child(face)
	box.add_child(_label("×%d" % count, u * 2.0, GOLD))
	return chip

## Lagerkarte: Siegel, Sorte, Inhaltsmenge - und der Öffnen-Knopf.
func _pack_card(pack: Pack, index: int, u: float) -> Control:
	var accent: Color = PACK_COLORS.get(pack.type, TITLE_COLOR)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(u * 22.0, u * 20.0)
	button.tooltip_text = pack.description
	_style_button(button, accent)
	button.pressed.connect(open_pack.bind(index))
	_pack_buttons.append(button)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(u * 0.5))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)

	var seal := _label("✦", u * 4.6, accent)
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(seal)
	var name_label := _label(pack.display_name, u * 2.4, TEXT_COLOR)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)
	var count_label := _label(_content_text(pack), u * 2.0, MUTED_COLOR)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(count_label)
	var open_label := _label("Öffnen", u * 2.2, GOLD)
	open_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(open_label)
	return button

func _content_text(pack: Pack) -> String:
	if pack.is_dice_pack():
		return "%d Würfel" % pack.count
	return "%d %s" % [pack.count, Engraving.CATEGORY_NAMES[pack.engraving_category()]]

# --- Zeremonie: öffnen, zeigen, verwenden --------------------------------------

## Öffnet das Paket auf Platz index. Der Inhalt entsteht ERST JETZT (GameRun);
## Gravuren sind damit schon gebucht, Würfel warten auf ihren Platz.
func open_pack(index: int) -> void:
	if run == null or index < 0 or index >= run.owned_packs.size():
		return
	var was_dice := run.owned_packs[index].is_dice_pack()
	# Phase VOR dem Öffnen setzen: packs_changed baut sofort neu auf.
	_phase = Phase.REVEAL_DICE if was_dice else Phase.REVEAL_ENGRAVINGS
	_die_index = 0
	var result := run.open_pack(index)
	_revealed_engravings.assign(result["engravings"])
	_revealed_dice.assign(result["dice"])
	pack_activated.emit(index)
	refresh()

## Zurück ans Lager - der Inhalt ist verbucht bzw. abgelehnt.
func finish_ceremony() -> void:
	_phase = Phase.STASH
	_revealed_engravings.clear()
	_revealed_dice.clear()
	_die_index = 0
	refresh()

## Der aktuelle Paket-Würfel sucht seinen Platz im Pool.
func begin_placement() -> void:
	if _die_index >= _revealed_dice.size():
		return
	_phase = Phase.PICK_POOL
	refresh()

## Setzt den aktuellen Würfel auf pool_index und geht zum nächsten weiter.
func place_current_die(pool_index: int) -> void:
	if run == null or _die_index >= _revealed_dice.size():
		return
	run.place_pack_die(_revealed_dice[_die_index], pool_index)
	die_placed.emit(pool_index)
	_advance_die()

## Lehnt den aktuellen Würfel ab - er verfällt ersatzlos.
func refuse_current_die() -> void:
	_advance_die()

func _advance_die() -> void:
	_die_index += 1
	if _die_index >= _revealed_dice.size():
		finish_ceremony()
		return
	_phase = Phase.REVEAL_DICE
	refresh()

# --- Zeremonie-Ansichten -------------------------------------------------------

## Gravur-Inhalt: nur zeigen - eingesteckt ist er bereits (GameRun.open_pack).
func _build_engraving_reveal(u: float) -> void:
	_content.add_child(_label("In die Vorräte gelegt:", u * 2.6, MUTED_COLOR))
	var shelf := HFlowContainer.new()
	shelf.add_theme_constant_override("h_separation", int(u * 1.2))
	shelf.add_theme_constant_override("v_separation", int(u * 1.2))
	shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(shelf)
	for engraving in _revealed_engravings:
		shelf.add_child(_engraving_card(engraving, u))
	_content.add_child(_action_button("Fertig", GOLD, u, finish_ceremony))

func _engraving_card(engraving: Engraving, u: float) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(u * 19.0, u * 12.5)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var seam: Color = EngravingRenderer.SEAM_COLORS[engraving.rarity]
	panel.add_theme_stylebox_override("panel", _button_box(Color("#221e46cc"), seam))
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var face := EngravingRenderer.for_engraving(engraving)
	face.custom_minimum_size = Vector2(u * 5.5, u * 5.5)
	var stage := CenterContainer.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(face)
	column.add_child(stage)
	var name_label := _label(engraving.display_name, u * 2.1, TEXT_COLOR)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)
	return panel

## Würfel-Inhalt: einer nach dem anderen, jeder mit Einsetzen/Ablehnen.
func _build_dice_reveal(u: float) -> void:
	if _die_index >= _revealed_dice.size():
		return
	_content.add_child(_label("Würfel %d von %d" % [_die_index + 1, _revealed_dice.size()],
		u * 2.6, MUTED_COLOR))
	var stage := CenterContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(DiceRowView.build_row(_revealed_dice[_die_index], int(u * 9.0)))
	_content.add_child(stage)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", int(u * 1.4))
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(_action_button("Einsetzen", GOLD, u, begin_placement))
	actions.add_child(_action_button("Ablehnen", MUTED_COLOR, u, refuse_current_die))
	_content.add_child(actions)

## Pool-Auswahl: welchen der Würfel im Pool ersetzt der Neue? Die Augensumme
## macht die schwachen Plätze auf einen Blick sichtbar.
func _build_pool_picker(u: float) -> void:
	_pool_buttons.clear()
	_content.add_child(_label("Welchen Würfel ersetzen?", u * 2.6, MUTED_COLOR))
	# Zehn Spalten: die 30 Plätze passen in drei Reihen ins flache Fenster.
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", int(u * 0.6))
	grid.add_theme_constant_override("v_separation", int(u * 0.6))
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(grid)
	var pool: Array[DieDefinition] = []
	if run != null:
		pool = run.owned_pool
	for i in pool.size():
		var slot := Button.new()
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.custom_minimum_size = Vector2(u * 6.4, u * 4.6)
		slot.text = "%d" % DiceRowView.eye_total(pool[i])
		slot.tooltip_text = pool[i].display_name
		slot.add_theme_font_size_override("font_size", maxi(8, int(u * 2.0)))
		# Spezialwürfel tragen ihre Signatur, damit man sie nicht versehentlich opfert.
		_style_button(slot, TITLE_COLOR if pool[i].style_id == "normal" else GOLD)
		slot.pressed.connect(place_current_die.bind(i))
		_pool_buttons.append(slot)
		grid.add_child(slot)
	_content.add_child(_action_button("Doch nicht", MUTED_COLOR, u, _cancel_placement))

func _cancel_placement() -> void:
	_phase = Phase.REVEAL_DICE
	refresh()

func _action_button(text: String, accent: Color, u: float, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(u * 22.0, u * 6.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", maxi(8, int(u * 2.6)))
	_style_button(button, accent)
	button.pressed.connect(handler)
	return button

# --- Bausteine -----------------------------------------------------------------

func _label(text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_stylebox_override("normal", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("hover", _button_box(Color("#2c2757dd"), GOLD))
	button.add_theme_stylebox_override("pressed", _button_box(Color("#3a2f66"), GOLD))
	button.add_theme_stylebox_override("focus", _button_box(Color("#221e46cc"), accent))

func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var u := maxf(size.x, 200.0) / 100.0
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.2)))
	box.set_corner_radius_all(int(u * 0.9))
	box.set_content_margin_all(int(u * 0.6))
	return box
