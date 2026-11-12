class_name PackChoiceView
extends Control
## Die PAKET-AUSWAHL in der WURFGRUBE: über dem Grubenboden liegen die Optionen eines
## geöffneten Pakets (die Körper stellt scene_root auf die gemeldeten PLÄTZE), darüber
## Name und ZÄHLER der Wahlen, darunter Auskunft und die Knöpfe Nehmen / Neu mischen.
## Gebucht ist schon (GameRun.pending_pack_choices); das Fenster sammelt nur die Wahl
## und meldet sie. Erst der Inhalt, dann die Zahl: der Zähler klettert 1 … K, bevor
## gewählt werden darf - ein Klick überspringt.

signal confirmed(indices: Array)
signal reshuffle_requested

const TEXT_COLOR := Color(1.3, 1.3, 1.25)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const SLOT_RIM := Color(0.55, 0.91, 0.99, 0.35)
const SLOT_PICKED := Color(1.4, 1.1, 0.2)
const COUNT_COLOR := Color(1.5, 1.24, 0.15)
const JACKPOT_COLOR := Color(1.8, 0.6, 1.6)
## Der Zähler klettert in dieser Zeit je Schritt, und die ganze Enthüllung bleibt
## unter ~1,5 s.
const COUNT_STEP := 0.35
const COUNT_HOLD := 0.3
## Die Optionen stehen mit dieser Luft um ihren Körper.
const SLOT_ROOM := 1.12
const SLOT_GAP_UNITS := 1.2

var choice: PackChoice = null
## Die Fußabdrücke der Körper in Display-Pixeln (gemeldet von scene_root).
var item_px := Vector2(60, 60)
var reshuffle_cost := -1
var energy := 0

var _selected: Array[int] = []
var _slots: Array[Button] = []
var _counting := false
var _counted := false
var _count_tween: Tween
var _title: Label
var _counter: Label
var _info: Label
var _take_button: Button
var _reshuffle_button: Button
var _hovered := -1

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

## WÜRFEL-Pakete: die SCHATULLE steht oben in der Mitte (ihr Grundriß in Display-
## Pixeln, gemeldet von scene_root), links davon Name und Zähler, rechts die Knöpfe,
## darunter die AUFSTELLUNG - je Würfel sein Platz und darunter sein Netz.
var case_px := Vector2.ZERO
## Welche Seite der liegende Würfel oben zeigt (sein Netz rahmt sie golden).
var up_face := -1
const HEAD_TOP_UNITS := 1.0
const HEAD_MIN_UNITS := 13.0
const LINEUP_GAP_UNITS := 1.4
const LINEUP_PER_ROW := 5
const INFO_UNITS := 5.0
const DIE_BAND_SHARE := 1.2
const NET_GAP_UNITS := 1.0
const NET_CELL_MAX_UNITS := 4.2
const NET_POP_TIME := 0.25
const HEAD_GRADE := 0.72
## Kein Hover auf einer Netz-Zelle.
const NO_FACE := -99

var _nets: Array[Control] = []
var _net_cell := 0.0
var _hover_face := NO_FACE

func _unit() -> float:
	return maxf(minf(size.x / 100.0, size.y / 46.0), 1.0)

## Die Aufstellung der Würfel-Pakete (sonst die Reihe der Karten-Pakete).
func lineup() -> bool:
	return case_px.x > 0.0 and case_px.y > 0.0

## Baut die Auswahl neu auf. counted = der Zähler steht schon (Neuaufbau nach dem
## Neumischen, Wiedereintritt). case_footprint = Grundriß der Schatulle (Würfel-Paket).
func open(open_choice: PackChoice, footprint: Vector2, cost: int, have_energy: int,
		counted := false, case_footprint := Vector2.ZERO, die_up_face := -1) -> void:
	choice = open_choice
	item_px = footprint
	reshuffle_cost = cost
	energy = have_energy
	case_px = case_footprint
	up_face = die_up_face
	_selected.clear()
	if choice != null and choice.take_all:
		for i in choice.option_count():
			_selected.append(i)
	_counted = counted
	_counting = false
	_kill_count()
	_build()
	visible = true

func close() -> void:
	_kill_count()
	visible = false
	choice = null

func selected_indices() -> Array[int]:
	return _selected.duplicate()

func choosing() -> bool:
	return visible and _counted

func hovered_index() -> int:
	return _hovered

# --- Die Plätze -------------------------------------------------------------------

## Wie viele Plätze in eine Reihe passen.
func per_row(count: int) -> int:
	var u := _unit()
	var slot := item_px.x * SLOT_ROOM
	var usable := size.x - u * 4.0
	var fits := maxi(1, int((usable + u * SLOT_GAP_UNITS) / (slot + u * SLOT_GAP_UNITS)))
	if count <= fits:
		return count
	return int(ceil(float(count) / ceil(float(count) / float(fits))))

## Das Rechteck des Platzes index in Pixeln des Fensters (rein, prüfbar).
func slot_rect(index: int, count: int) -> Rect2:
	if lineup():
		var block := lineup_block(index, count)
		var side := minf(die_band(), block.size.x)
		return Rect2(Vector2(block.get_center().x - side * 0.5, block.position.y),
			Vector2.ONE * side)
	var u := _unit()
	var slot := item_px * SLOT_ROOM
	var gap := u * SLOT_GAP_UNITS
	var columns := per_row(count)
	var rows := int(ceil(float(count) / float(columns)))
	var row := index / columns
	var in_row := mini(columns, count - row * columns)
	var row_width := float(in_row) * slot.x + float(in_row - 1) * gap
	var area_top := u * 12.0
	var area_height := size.y - area_top - u * 11.0
	var block := float(rows) * slot.y + float(rows - 1) * gap
	var top := area_top + maxf((area_height - block) * 0.5, 0.0)
	var x := (size.x - row_width) * 0.5 + float(index - row * columns) * (slot.x + gap)
	return Rect2(Vector2(x, top + float(row) * (slot.y + gap)), slot)

## Wo die Schatulle steht (Fenster-Pixel): oben in der Mitte.
func case_rect_local() -> Rect2:
	return Rect2(Vector2((size.x - case_px.x) * 0.5, _unit() * HEAD_TOP_UNITS), case_px)

## Ihr Platz in Display-Pixeln - dort stellt scene_root sie hin.
func case_seat_px() -> Vector2:
	return position + case_rect_local().get_center()

func _head_height() -> float:
	return maxf(case_px.y, _unit() * HEAD_MIN_UNITS)

## Die Fläche der Aufstellung: unter dem Kopf, über der Auskunfts-Zeile.
func lineup_area() -> Rect2:
	var u := _unit()
	var top := u * HEAD_TOP_UNITS + _head_height() + u * LINEUP_GAP_UNITS
	var bottom := size.y - u * (INFO_UNITS + 0.6)
	return Rect2(Vector2(u * 2.0, top), Vector2(size.x - u * 4.0, maxf(bottom - top, 1.0)))

## Spalten × Reihen: höchstens LINEUP_PER_ROW je Reihe, die Reihen gleich voll.
static func lineup_grid(count: int) -> Vector2i:
	var rows := maxi(int(ceil(float(maxi(count, 1)) / float(LINEUP_PER_ROW))), 1)
	return Vector2i(int(ceil(float(maxi(count, 1)) / float(rows))), rows)

## Der Block eines Würfels (Platz + Netz); die letzte Reihe steht mittig.
func lineup_block(index: int, count: int) -> Rect2:
	var area := lineup_area()
	var grid := lineup_grid(count)
	var gap := _unit() * SLOT_GAP_UNITS
	var cell := Vector2((area.size.x - gap * float(grid.x - 1)) / float(grid.x),
		(area.size.y - gap * float(grid.y - 1)) / float(grid.y))
	var row := index / grid.x
	var in_row := mini(grid.x, count - row * grid.x)
	var row_width := cell.x * float(in_row) + gap * float(in_row - 1)
	var left := area.position.x + (area.size.x - row_width) * 0.5
	return Rect2(Vector2(left + float(index - row * grid.x) * (cell.x + gap),
		area.position.y + float(row) * (cell.y + gap)), cell)

## Die Höhe des Würfel-Platzes über seinem Netz.
func die_band() -> float:
	return item_px.y * DIE_BAND_SHARE

## Die Zellgröße der Netze - EINE für die ganze Aufstellung.
func net_cell(count: int) -> float:
	var block := lineup_block(0, count)
	var avail := Vector2(block.size.x * 0.96,
		block.size.y - die_band() - _unit() * NET_GAP_UNITS)
	return minf(DieNetView.cell_for(avail), _unit() * NET_CELL_MAX_UNITS)

## Das Netz unter seinem Würfel (Fenster-Pixel).
func net_rect(index: int, count: int) -> Rect2:
	var block := lineup_block(index, count)
	var span := DieNetView.net_size(net_cell(count))
	return Rect2(Vector2(block.get_center().x - span.x * 0.5,
		block.position.y + die_band() + _unit() * NET_GAP_UNITS), span)

## Ein Netz erscheint, wenn sein Würfel landet.
func reveal_net(index: int) -> void:
	if index < 0 or index >= _nets.size() or _nets[index].visible:
		return
	var net := _nets[index]
	net.visible = true
	net.pivot_offset = net.size * 0.5
	net.scale = Vector2.ONE * 0.4
	net.modulate.a = 0.0
	var pop := net.create_tween().set_parallel(true)
	pop.tween_property(net, "scale", Vector2.ONE, NET_POP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(net, "modulate:a", 1.0, NET_POP_TIME * 0.6)
	net.set_meta("pop", pop)

## Alle Netze stehen sofort (Überspringen, Abbruch).
func reveal_all_nets() -> void:
	for net in _nets:
		var pop: Variant = net.get_meta("pop") if net.has_meta("pop") else null
		if pop is Tween and (pop as Tween).is_valid():
			(pop as Tween).kill()
		net.visible = true
		net.scale = Vector2.ONE
		net.modulate.a = 1.0

func hide_nets() -> void:
	for net in _nets:
		net.visible = false

func net_shown(index: int) -> bool:
	return index >= 0 and index < _nets.size() and _nets[index].visible

## Die MITTEN der Plätze in Display-Pixeln - dort stellt scene_root die Körper hin.
func slot_centers() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if choice == null:
		return out
	for i in choice.option_count():
		out.append(position + slot_rect(i, choice.option_count()).get_center())
	return out

# --- Aufbau -----------------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_slots.clear()
	_hovered = -1
	if choice == null:
		return
	_nets.clear()
	_hover_face = NO_FACE
	var u := _unit()
	var count := choice.option_count()
	# Karten: Kopf oben, Knöpfe unten. Würfel: Kopf links und Knöpfe rechts der Schatulle.
	var head := Rect2(Vector2.ZERO, Vector2(size.x, u * 10.0))
	var buttons := Rect2(Vector2(0.0, size.y - u * 5.6), Vector2(size.x, u * 4.6))
	var info := Rect2(Vector2(u * 3.0, size.y - u * 10.6), Vector2(size.x - u * 6.0, u * 4.8))
	if lineup():
		var case_rect := case_rect_local()
		var top := u * HEAD_TOP_UNITS
		head = Rect2(Vector2(u, top), Vector2(case_rect.position.x - u * 2.5, _head_height()))
		buttons = Rect2(Vector2(case_rect.end.x + u * 2.0, top),
			Vector2(size.x - case_rect.end.x - u * 4.0, _head_height()))
		info = Rect2(Vector2(u * 3.0, size.y - u * INFO_UNITS), Vector2(size.x - u * 6.0,
			u * (INFO_UNITS - 0.4)))
	# Neben der Schatulle ist der Kopf schmal - er spricht eine Spur kleiner.
	var grade := HEAD_GRADE if lineup() else 1.0
	_title = CasinoStyle.label(choice.display_name, u * 3.6 * grade, TEXT_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER, 3)
	_title.position = head.position + Vector2(0.0, u * 0.8)
	_title.size = Vector2(head.size.x, u * 4.6)
	add_child(_title)
	_counter = CasinoStyle.label("", u * 3.4 * grade, COUNT_COLOR, HORIZONTAL_ALIGNMENT_CENTER, 3)
	_counter.position = head.position + Vector2(0.0, u * 5.4)
	_counter.size = Vector2(head.size.x, u * 4.4)
	add_child(_counter)
	if lineup():
		_net_cell = net_cell(count)
	for i in count:
		var slot := Button.new()
		slot.name = "Option%d" % i
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var rect := lineup_block(i, count) if lineup() else slot_rect(i, count)
		slot.position = rect.position
		slot.size = rect.size
		slot.pressed.connect(_on_slot_pressed.bind(i))
		slot.mouse_entered.connect(_on_slot_hover.bind(i, true))
		slot.mouse_exited.connect(_on_slot_hover.bind(i, false))
		slot.gui_input.connect(_on_slot_input.bind(i))
		add_child(slot)
		_slots.append(slot)
		if lineup() and choice.options[i] is DieDefinition:
			var net := DieNetView.build(choice.options[i] as DieDefinition, up_face, _net_cell)
			net.position = net_rect(i, count).position
			net.visible = false
			add_child(net)
			_nets.append(net)
	_info = CasinoStyle.label("", u * 2.0, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.clip_text = true
	_info.position = info.position
	_info.size = info.size
	add_child(_info)
	_reshuffle_button = _button("", u, false)
	_reshuffle_button.pressed.connect(func() -> void:
		if choosing():
			reshuffle_requested.emit())
	add_child(_reshuffle_button)
	_take_button = _button("", u, true)
	_take_button.pressed.connect(_on_take_pressed)
	add_child(_take_button)
	var button_size := Vector2(minf(u * 28.0, buttons.size.x), u * 4.6)
	if lineup():
		# Übereinander, mittig neben der Schatulle.
		var stack_top := buttons.position.y + (buttons.size.y - button_size.y * 2.0 - u) * 0.5
		var x := buttons.position.x + (buttons.size.x - button_size.x) * 0.5
		_take_button.position = Vector2(x, stack_top)
		_reshuffle_button.position = Vector2(x, stack_top + button_size.y + u)
	else:
		_reshuffle_button.position = Vector2(size.x * 0.5 - u * 31.0, buttons.position.y)
		_take_button.position = Vector2(size.x * 0.5 + u * 3.0, buttons.position.y)
	_reshuffle_button.size = button_size
	_take_button.size = button_size
	# Ein Klick ins Leere überspringt die Enthüllung.
	var skip := Button.new()
	skip.name = "Skip"
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		skip.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	skip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skip.pressed.connect(skip_count)
	add_child(skip)
	move_child(skip, 0)
	_refresh()

func _button(text: String, u: float, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", maxi(8, int(u * 2.4)))
	if primary:
		CasinoStyle.style_primary_button(button, CasinoStyle.GOLD, u)
	else:
		for state in ["normal", "focus"]:
			button.add_theme_stylebox_override(state, CasinoStyle.flat_box(
				Color("#221e46cc"), CasinoStyle.ENERGY, u * 0.22, u * 0.9, u * 0.8))
		button.add_theme_stylebox_override("hover", CasinoStyle.flat_box(
			Color("#2c2757dd"), CasinoStyle.GOLD, u * 0.22, u * 0.9, u * 0.8))
		button.add_theme_stylebox_override("pressed", CasinoStyle.flat_box(
			Color("#3a2f66"), CasinoStyle.GOLD, u * 0.22, u * 0.9, u * 0.8))
		button.add_theme_stylebox_override("disabled", CasinoStyle.flat_box(
			Color("#1a183666"), CasinoStyle.DISABLED_BORDER, u * 0.22, u * 0.9, u * 0.8))
		button.add_theme_color_override("font_color", TEXT_COLOR)
		button.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.7, 0.5))
	return button

# --- Der ZÄHLER -------------------------------------------------------------------

## Erst der Inhalt, dann die Zahl: der Zähler klettert auf die Zahl der Wahlen.
func start_count() -> void:
	if choice == null or _counted or _counting:
		return
	_counting = true
	_kill_count()
	_count_tween = create_tween()
	var target := choice.picks
	var steps := mini(target, 3)
	for step in steps:
		var shown := target if step == steps - 1 else step + 1
		_count_tween.tween_callback(_show_count.bind(shown))
		_count_tween.tween_interval(COUNT_STEP)
	_count_tween.tween_interval(COUNT_HOLD)
	_count_tween.tween_callback(_finish_count)

## Ein Klick: sofort zur Wahl.
func skip_count() -> void:
	if _counted or choice == null:
		return
	_kill_count()
	_finish_count()

func _show_count(value: int) -> void:
	if _counter == null or not is_instance_valid(_counter):
		return
	_counter.text = "%d" % value
	_counter.pivot_offset = _counter.size * 0.5
	var pop := create_tween()
	_counter.scale = Vector2.ONE * 1.35
	pop.tween_property(_counter, "scale", Vector2.ONE, COUNT_STEP * 0.8) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _finish_count() -> void:
	_counting = false
	_counted = true
	_refresh()
	if choice != null and choice.take_all and _counter != null and is_instance_valid(_counter):
		var flash := create_tween().set_loops(3)
		flash.tween_property(_counter, "modulate", JACKPOT_COLOR, 0.12)
		flash.tween_property(_counter, "modulate", COUNT_COLOR, 0.12)

func _kill_count() -> void:
	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	_count_tween = null

# --- Wählen -----------------------------------------------------------------------

func _on_slot_pressed(index: int) -> void:
	if not _counted:
		skip_count()
		return
	toggle(index)

## Eine Option wählen oder abwählen; mehr als die Wahlen geht nicht.
func toggle(index: int) -> void:
	if choice == null or index < 0 or index >= choice.option_count():
		return
	if _selected.has(index):
		_selected.erase(index)
	elif _selected.size() < choice.picks:
		_selected.append(index)
	_refresh()

func _on_take_pressed() -> void:
	if not choosing():
		skip_count()
		return
	confirmed.emit(_selected.duplicate())

func _on_slot_hover(index: int, inside: bool) -> void:
	if inside:
		_hovered = index
	elif _hovered == index:
		_hovered = -1
		_hover_face = NO_FACE
	_refresh_info()

## Über dem Netz nennt die Zelle unter dem Zeiger sich selbst.
func _on_slot_input(event: InputEvent, index: int) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or choice == null:
		return
	var face := net_face_at(index, _slots[index].position + motion.position)
	if face != _hover_face:
		_hover_face = face
		_refresh_info()

## Die Netz-Zelle unter einem Fenster-Pixel (NO_FACE = keine, auch bei verdecktem Netz).
func net_face_at(index: int, local: Vector2) -> int:
	if not lineup() or not net_shown(index):
		return NO_FACE
	var rect := net_rect(index, choice.option_count())
	if not rect.has_point(local):
		return NO_FACE
	var face := DieNetView.face_at(local - rect.position, _net_cell)
	return face if face >= 0 or face == DieNetView.EDGE else NO_FACE

func _refresh() -> void:
	if choice == null:
		return
	var u := _unit()
	for i in _slots.size():
		var picked := _selected.has(i)
		var open := _counted and (picked or _selected.size() < choice.picks)
		var rim := SLOT_PICKED if picked else SLOT_RIM
		var box := CasinoStyle.flat_box(Color(1.0, 0.8, 0.2, 0.08) if picked else Color(0, 0, 0, 0),
			rim, u * (0.5 if picked else 0.2), u * 1.2, 0.0)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			_slots[i].add_theme_stylebox_override(state, box)
		_slots[i].modulate.a = 1.0 if open or not _counted else 0.45
	if _counter != null and is_instance_valid(_counter) and _counted:
		_counter.scale = Vector2.ONE
		if choice.take_all:
			_counter.text = "ALLE nehmen"
		else:
			_counter.text = "Wähle %d von %d  ·  %d gewählt" % [choice.picks,
				choice.option_count(), _selected.size()]
	if _take_button != null and is_instance_valid(_take_button):
		_take_button.disabled = not _counted
		_take_button.text = "Nehmen (%d)" % _selected.size() if not _selected.is_empty() \
			else "Nichts nehmen"
	if _reshuffle_button != null and is_instance_valid(_reshuffle_button):
		var free := reshuffle_cost == 0
		_reshuffle_button.text = "Neu mischen (gratis)" if free \
			else "Neu mischen (%d ⚡)" % maxi(reshuffle_cost, 1)
		_reshuffle_button.disabled = not _counted or reshuffle_cost < 0 \
			or energy < reshuffle_cost
	_refresh_info()

func _refresh_info() -> void:
	if _info == null or not is_instance_valid(_info) or choice == null:
		return
	if _hovered >= 0 and _hovered < choice.option_count():
		var option: Variant = choice.options[_hovered]
		var cell := ""
		if _hover_face != NO_FACE and option is DieDefinition:
			cell = DieNetView.hint_for(option as DieDefinition, _hover_face)
		_info.text = cell if cell != "" else option_text(option)
		_info.modulate = TEXT_COLOR
		return
	_info.modulate = MUTED_COLOR
	if not _counted:
		_info.text = ""
	elif choice.take_all:
		_info.text = "Alles gehört dir."
	else:
		_info.text = "Ungewähltes verfällt."

## Die Auskunft einer Option in EINER Zeile - aus den Quellen, die überall sprechen.
static func option_text(option: Variant) -> String:
	if option is Pack:
		var info := WorkshopInfoView.pack_info(option as Pack)
		return "%s · %s - %s" % [info["title"], info["sub"],
			String(info["body"]).replace("\n", " ")]
	if option is DieDefinition:
		return ShopController.die_foot_text(option as DieDefinition)
	return ""
