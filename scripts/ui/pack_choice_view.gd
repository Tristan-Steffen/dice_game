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

func _unit() -> float:
	return maxf(minf(size.x / 100.0, size.y / 46.0), 1.0)

## Baut die Auswahl neu auf. counted = der Zähler steht schon (Neuaufbau nach dem
## Neumischen, Wiedereintritt).
func open(open_choice: PackChoice, footprint: Vector2, cost: int, have_energy: int,
		counted := false) -> void:
	choice = open_choice
	item_px = footprint
	reshuffle_cost = cost
	energy = have_energy
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
	var u := _unit()
	_title = CasinoStyle.label(choice.display_name, u * 3.6, TEXT_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER, 3)
	_title.position = Vector2(0.0, u * 0.8)
	_title.size = Vector2(size.x, u * 4.6)
	add_child(_title)
	_counter = CasinoStyle.label("", u * 3.4, COUNT_COLOR, HORIZONTAL_ALIGNMENT_CENTER, 3)
	_counter.position = Vector2(0.0, u * 5.4)
	_counter.size = Vector2(size.x, u * 4.4)
	add_child(_counter)
	var count := choice.option_count()
	for i in count:
		var slot := Button.new()
		slot.name = "Option%d" % i
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var rect := slot_rect(i, count)
		slot.position = rect.position
		slot.size = rect.size
		slot.pressed.connect(_on_slot_pressed.bind(i))
		slot.mouse_entered.connect(_on_slot_hover.bind(i, true))
		slot.mouse_exited.connect(_on_slot_hover.bind(i, false))
		add_child(slot)
		_slots.append(slot)
	_info = CasinoStyle.label("", u * 2.0, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.clip_text = true
	_info.position = Vector2(u * 3.0, size.y - u * 10.6)
	_info.size = Vector2(size.x - u * 6.0, u * 4.8)
	add_child(_info)
	var row_y := size.y - u * 5.6
	_reshuffle_button = _button("", u, false)
	_reshuffle_button.position = Vector2(size.x * 0.5 - u * 31.0, row_y)
	_reshuffle_button.size = Vector2(u * 28.0, u * 4.6)
	_reshuffle_button.pressed.connect(func() -> void:
		if choosing():
			reshuffle_requested.emit())
	add_child(_reshuffle_button)
	_take_button = _button("", u, true)
	_take_button.position = Vector2(size.x * 0.5 + u * 3.0, row_y)
	_take_button.size = Vector2(u * 28.0, u * 4.6)
	_take_button.pressed.connect(_on_take_pressed)
	add_child(_take_button)
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
	_refresh_info()

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
		_info.text = option_text(choice.options[_hovered])
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
