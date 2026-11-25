class_name PackChoiceView
extends Control
## Die PAKET-AUSWAHL: die Optionen eines geöffneten Pakets (die Körper stellt scene_root auf
## die gemeldeten PLÄTZE, in Display-Pixeln). Karten wie Würfel stehen als EIN Schirm in der
## ÖFFNUNGS-ZONE: Kopfzeile, Aufstellung (höchstens drei je Reihe, zwei Reihen), Auskunft,
## Knöpfe. Eine Würfel-Option ist eine Kachel: links liest der Würfel, rechts sein Netz.
## Gebucht ist schon (GameRun.pending_pack_choices); das Fenster sammelt nur die Wahl
## und meldet sie. Erst der Inhalt, dann die Zahl: der GLÜCKSWÜRFEL rollt (scene_root), und
## erst mit seinem Stillstand (die_landed) nennt das Fenster die Wahlen.

signal confirmed(indices: Array)
signal reshuffle_requested
## Eine Option wurde gewählt oder abgewählt (scene_root spielt den Ton).
signal pick_toggled(index: int, picked: bool)
## Ein Klick will den rollenden Glückswürfel ans Ende springen lassen (scene_root führt ihn).
signal roll_skip_requested
signal opening_finished

const TEXT_COLOR := Color(1.3, 1.3, 1.25)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const SLOT_RIM := Color(0.55, 0.91, 0.99, 0.35)
const SLOT_PICKED := Color(1.4, 1.1, 0.2)
const COUNT_COLOR := Color(1.5, 1.24, 0.15)
## Der Zähler springt mit dem Stillstand des Glückswürfels auf.
const COUNT_STEP := 0.35
## Die Optionen stehen mit dieser Luft um ihren Körper.
const SLOT_ROOM := 1.04
const SLOT_GAP_UNITS := 0.8
## Höchstens so viele Optionen nebeneinander (Karten wie Würfel): 5 stehen 3 + 2, 6 stehen 3 + 3.
const CARDS_PER_ROW := 3
## Luft (u) um die Aufstellung, damit die Zählung nie eine Spur darunter fällt.
const AREA_AIR_UNITS := 1.0

var choice: PackChoice = null
## Die Fußabdrücke der Körper in Display-Pixeln (gemeldet von scene_root).
var item_px := Vector2(60, 60)
var reshuffle_cost := -1
var energy := 0

var _selected: Array[int] = []
var _slots: Array[Button] = []
var _counting := false
var _counted := false
var _title: Label
var _counter: Label
var _info: Label
var _die_info: DieInfoBand
var _take_button: Button
var _reshuffle_button: Button
var _hovered := -1
var _energy_label: Label
## Auf dem Tisch trägt die Fläche ihren eigenen Schirm (wie jedes Fenster).
var backdrop := false

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

## Welche Seite der liegende Würfel oben zeigt (sein Netz rahmt sie golden).
var up_face := -1
## Die Einheit folgt der Höhe; der Kopf ist EINE Zeile: Name · Zähler · Energie.
const UNIT_DIV := 56.0
const HEAD_UNITS := 3.0
## Die Zone ist doppelt so breit wie die alte Fläche: Kopf und Knöpfe lesen eine Spur größer.
const FONT_UNITS := 2.0
const COUNT_FONT_UNITS := 2.2
const HEAD_TITLE_SHARE := 0.42
const HEAD_COUNT_SHARE := 0.32
const BUTTON_FONT_UNITS := 2.0
const BUTTON_UNITS := 4.2
const INFO_UNITS := 4.2
const INFO_FONT_UNITS := 2.0
## Die Würfel-Aufstellung hat immer Platz für zwei Reihen - die Kachel bleibt gleich hoch.
const DICE_ROWS := 2
const TILE_GAP_UNITS := 0.8
## Wie der liegende Würfel an der geneigten Kamera LIEST (in Würfelkanten): DIE_LOOK_HALF
## über und unter seinem Sitz, quer DIE_LOOK_WIDTH. Der Sitz liegt DIE_SEAT_DROP Kanten
## unter der Bandmitte, denn die Kamera projiziert den Würfel nach oben (gemessen).
const DIE_LOOK_HALF := 0.65
const DIE_LOOK_WIDTH := 2.4
const DIE_SEAT_DROP := 0.22
## Die Kachel: gleiche Luft links und rechts (sie trägt auch den Hub der Wahl).
const TILE_AIR_UNITS := 1.3
const NET_GAP_UNITS := 1.0
const NET_CELL_MAX_UNITS := 6.5
const NET_POP_TIME := 0.25
## Kein Hover auf einer Netz-Zelle.
const NO_FACE := -99
## ZUORDNEN (Würfel-Pakete): eine eingesetzte Option trägt diesen Saum und ihre Marke.
const SLOT_ASSIGNED := Color(0.35, 1.3, 0.9)
const MARK_FONT_UNITS := 1.7

var _nets: Array[Control] = []
## Der ENTWURF: je Option ihr Vorrats-Platz (Index in owned_pool) und dessen Name.
## Gebucht ist nichts - erst „Einsetzen“ meldet ihn.
var _assign := {}
var _assign_label := {}
var _armed := -1
var _marks: Array[Label] = []
var _net_cell := 0.0
var _hover_face := NO_FACE

## Die BÜHNE der Würfel-Pakete: Auswurf (keine Plätze, kein Zähler) → Aufstellung (die
## Netze gehen auf) → der Glückswürfel rollt → Wahl.
const STAGE_LAUNCH := 0
const STAGE_LINEUP := 1
const STAGE_ROLL := 2
const STAGE_PICK := 3
var _stage := STAGE_PICK

func _unit() -> float:
	return maxf(size.y / UNIT_DIV, 1.0)

func head_height() -> float:
	return _unit() * HEAD_UNITS

func _draw() -> void:
	if backdrop:
		draw_style_box(TableScreen.window_style(), Rect2(Vector2.ZERO, size))

## Das Rechteck der ÖFFNUNGS-ZONE in Display-Pixeln (rein, prüfbar): sie VERWANDELT die
## Gleichung - links ab ihr, oben bündig mit der Pool-Reihe und so hoch wie sie, rechts
## bis end_x.
static func area_beside(pool: Rect2, equation: Rect2, end_x: float) -> Rect2:
	if pool.size.y <= 0.0 or end_x <= equation.position.x:
		return Rect2()
	return Rect2(Vector2(equation.position.x, pool.position.y),
		Vector2(end_x - equation.position.x, pool.size.y))

## Wie breit die Zone sein muß (rein): drei Würfel-Kacheln nebeneinander samt Fugen und
## Rand - die Würfel-Auswahl ist die größte, Karten passen hinein.
static func panel_width_for(height: float, die_px: float) -> float:
	var u := maxf(height / UNIT_DIV, 1.0)
	var top := u * (2.0 + HEAD_UNITS)
	var info_y := height - u - u * BUTTON_UNITS - u * (INFO_UNITS + 0.4)
	var lineup := maxf(info_y - u * 0.6 - top, 1.0)
	var gap := u * TILE_GAP_UNITS
	var tile_h := (lineup - gap * float(DICE_ROWS - 1)) / float(DICE_ROWS)
	var cell := tile_cell(u, die_px, tile_h, INF)
	return tile_width(u, die_px, cell) * float(CARDS_PER_ROW) + gap * float(CARDS_PER_ROW - 1) + u * 2.0

## Wie breit count liegende Karten samt Fugen und Rand stehen (rein).
static func cards_width_for(height: float, card: Vector2, count: int) -> float:
	var u := maxf(height / UNIT_DIV, 1.0)
	return card.x * SLOT_ROOM * float(count) + u * SLOT_GAP_UNITS * float(count - 1) \
		+ u * (2.0 + AREA_AIR_UNITS)

## Die festen Felder der Seite (Fenster-Pixel), EINE Quelle für Karten und Würfel: die
## Kopfzeile samt Energie rechts, Auskunft und die Knopfzeile.
func _frame_rects() -> Dictionary:
	var u := _unit()
	var head := Rect2(Vector2(u, u), Vector2(maxf(size.x - u * 2.0, u), u * HEAD_UNITS))
	var rest := head.size.x * (HEAD_TITLE_SHARE + HEAD_COUNT_SHARE)
	var energy := Rect2(Vector2(head.position.x + rest, head.position.y),
		Vector2(head.size.x - rest, head.size.y))
	var buttons := Rect2(Vector2(u, size.y - u - u * BUTTON_UNITS),
		Vector2(size.x - u * 2.0, u * BUTTON_UNITS))
	var info := Rect2(Vector2(u, buttons.position.y - u * (INFO_UNITS + 0.4)),
		Vector2(size.x - u * 2.0, u * INFO_UNITS))
	return {"head": head, "buttons": buttons, "info": info, "energy": energy}

## Ein Würfel-Paket ist offen: seine Optionen sind Kacheln (Würfel + Netz).
func lineup() -> bool:
	return choice != null and choice.is_dice()

## Baut die Auswahl neu auf. counted = der Zähler steht schon (Neuaufbau nach dem
## Neumischen, Wiedereintritt). die_up_face = die obere Seite des liegenden Würfels.
func open(open_choice: PackChoice, footprint: Vector2, cost: int, have_energy: int,
		counted := false, die_up_face := -1) -> void:
	choice = open_choice
	item_px = footprint
	reshuffle_cost = cost
	energy = have_energy
	up_face = die_up_face
	_selected.clear()
	_assign.clear()
	_assign_label.clear()
	_armed = -1
	_counted = counted
	_counting = false
	_stage = STAGE_LAUNCH if lineup() and not counted else STAGE_PICK
	_build()
	visible = true
	queue_redraw()

func close() -> void:
	choice = null
	_counted = false
	_counting = false
	_selected.clear()
	_assign.clear()
	_assign_label.clear()
	_armed = -1
	visible = backdrop
	_build()

func selected_indices() -> Array[int]:
	if assigning():
		var out: Array[int] = []
		for key in _assign:
			out.append(int(key))
		out.sort()
		return out
	return _selected.duplicate()

# --- ZUORDNEN (Würfel-Pakete) -------------------------------------------------------
# Wählen IST Einsetzen: jede Option bekommt einen Vorrats-Platz. Die Fläche hält nur den
# Entwurf und malt ihn; die Körper und die Treffer auf dem Vorrat gehören scene_root.

func assigning() -> bool:
	return choice != null and choice.is_dice() and lineup()

## option → Vorrats-Index (int), genau die Form, die GameRun.confirm_dice_choice bucht.
func assignments() -> Dictionary:
	return _assign.duplicate()

func assigned_count() -> int:
	return _assign.size()

## Der Vorrats-Index einer Option (-1 = keiner).
func assignment_of(option: int) -> int:
	return int(_assign.get(option, -1))

func assignment_label(option: int) -> String:
	return String(_assign_label.get(option, ""))

## Welche Option auf diesem Vorrats-Platz steht (-1 = keine).
func option_on_seat(seat: int) -> int:
	for key in _assign:
		if int(_assign[key]) == seat:
			return int(key)
	return -1

## Setzt eine Option auf einen Platz. Ein belegter Platz schickt seine Option zurück
## in die Aufstellung; mehr als K Zuordnungen gibt es nicht (false = nichts geändert).
func assign(option: int, seat: int, label: String) -> bool:
	if not assigning() or option < 0 or option >= choice.option_count() or seat < 0:
		return false
	var held := option_on_seat(seat)
	if held == option:
		_armed = -1
		_refresh()
		return true
	var count := _assign.size() - (1 if held >= 0 else 0)
	if not _assign.has(option) and count >= choice.picks:
		return false
	if held >= 0:
		_assign.erase(held)
		_assign_label.erase(held)
	_assign[option] = seat
	_assign_label[option] = label
	_armed = -1
	pick_toggled.emit(option, true)
	_refresh()
	return true

func unassign(option: int) -> void:
	if not _assign.has(option):
		return
	_assign.erase(option)
	_assign_label.erase(option)
	pick_toggled.emit(option, false)
	_refresh()

## Getippt wählt aus: die Option trägt den Gold-Saum, bis ein Vorrats-Würfel sie nimmt.
func arm(option: int) -> void:
	if not assigning() or option < -1 or option >= choice.option_count():
		return
	_armed = -1 if option == _armed else option
	_refresh()

func armed_index() -> int:
	return _armed

## Die Option, deren Block unter einem Display-Pixel liegt (-1 = keine).
func option_at_px(pixel: Vector2) -> int:
	if choice == null or not slots_shown():
		return -1
	var local := pixel - global_position
	var count := choice.option_count()
	for i in count:
		var rect := lineup_block(i, count) if lineup() else slot_rect(i, count)
		if rect.has_point(local):
			return i
	return -1

## Die Magazin-Spalte einer Karten-Option (ihre Sorte, -1 = keine Karte).
func option_shelf_column(index: int) -> int:
	if choice == null or index < 0 or index >= choice.option_count():
		return -1
	var option: Variant = choice.options[index]
	return Pack.shelf_rank(option as Pack) if option is Pack else -1

func choosing() -> bool:
	return visible and _counted

func hovered_index() -> int:
	return _hovered

# --- Die Plätze -------------------------------------------------------------------

## Wie viele Plätze in eine Reihe passen.
func per_row(count: int) -> int:
	var fits := CARDS_PER_ROW
	if not lineup():
		var u := _unit()
		var slot := item_px.x * SLOT_ROOM
		var usable := lineup_area().size.x
		fits = clampi(int((usable + u * SLOT_GAP_UNITS) / (slot + u * SLOT_GAP_UNITS)), 1,
			CARDS_PER_ROW)
	if count <= fits:
		return count
	return int(ceil(float(count) / ceil(float(count) / float(fits))))

## Das Rechteck des Platzes index in Pixeln des Fensters (rein, prüfbar). Bei Würfeln
## ist es das Band, in dem der liegende Würfel LIEST - links neben seinem Netz.
func slot_rect(index: int, count: int) -> Rect2:
	if lineup():
		var tile := lineup_block(index, count)
		var look := die_look()
		return Rect2(Vector2(tile.position.x + tile_air(), tile.get_center().y - look.y * 0.5),
			look)
	var u := _unit()
	var slot := item_px * SLOT_ROOM
	var gap := u * SLOT_GAP_UNITS
	var columns := per_row(count)
	var rows := int(ceil(float(count) / float(columns)))
	var row := index / columns
	var in_row := mini(columns, count - row * columns)
	var row_width := float(in_row) * slot.x + float(in_row - 1) * gap
	var area := lineup_area()
	var block := float(rows) * slot.y + float(rows - 1) * gap
	var top := area.position.y + maxf((area.size.y - block) * 0.5, 0.0)
	var x := area.position.x + (area.size.x - row_width) * 0.5 \
		+ float(index - row * columns) * (slot.x + gap)
	return Rect2(Vector2(x, top + float(row) * (slot.y + gap)), slot)

## Die ganze Seite in Display-Pixeln.
func page_rect_px() -> Rect2:
	return Rect2(global_position, size)

## Die Fläche der Aufstellung in Display-Pixeln.
func lineup_area_px() -> Rect2:
	var area := lineup_area()
	return Rect2(global_position + area.position, area.size)

## Wo die Hülle eines Karten-Pakets aufgeht: über der Mitte der Aufstellung.
func hull_seat_px() -> Vector2:
	return global_position + lineup_area().get_center()

## Die Fläche der Aufstellung: unter dem Kopf, über der Auskunft, volle Breite - für
## Karten wie Würfel.
func lineup_area() -> Rect2:
	var u := _unit()
	var top := u * 2.0 + head_height()
	var info: Rect2 = _frame_rects()["info"]
	return Rect2(Vector2(u, top),
		Vector2(size.x - u * 2.0, maxf(info.position.y - u * 0.6 - top, 1.0)))

func _tile_gap() -> float:
	return _unit() * TILE_GAP_UNITS

## Die Höhe einer Würfel-Kachel: zwei Reihen füllen die Aufstellung, immer.
func tile_height() -> float:
	return (lineup_area().size.y - _tile_gap() * float(DICE_ROWS - 1)) / float(DICE_ROWS)

## Die Netz-Zelle einer Kachel (rein): Höhe und Spaltenbreite binden, ein Deckel hält sie
## vernünftig.
static func tile_cell(u: float, die_px: float, height: float, column: float) -> float:
	var air := u * TILE_AIR_UNITS * 2.0
	var avail := Vector2(column - air - die_px * DIE_LOOK_WIDTH - u * NET_GAP_UNITS,
		height - air)
	if avail.x <= 0.0 or avail.y <= 0.0:
		return 0.0
	return minf(DieNetView.cell_for(avail), u * NET_CELL_MAX_UNITS)

## Die Breite einer Kachel: Luft, Würfel, Fuge, Netz, dieselbe Luft.
static func tile_width(u: float, die_px: float, cell: float) -> float:
	return u * TILE_AIR_UNITS * 2.0 + die_px * DIE_LOOK_WIDTH + u * NET_GAP_UNITS \
		+ DieNetView.net_size(cell).x

func _tile_net_cell() -> float:
	var column := (lineup_area().size.x - _tile_gap() * float(CARDS_PER_ROW - 1)) \
		/ float(CARDS_PER_ROW)
	return tile_cell(_unit(), item_px.y, tile_height(), column)

## Die Kachel liegt QUER und folgt dem INHALT; hoch ist sie eine halbe Aufstellung.
func block_size(_count: int) -> Vector2:
	return Vector2(tile_width(_unit(), item_px.y, _tile_net_cell()), tile_height())

## Die Kachel einer Option: wie die Karten höchstens drei je Reihe, der Block mittig.
func lineup_block(index: int, count: int) -> Rect2:
	var area := lineup_area()
	var tile := block_size(count)
	var gap := _tile_gap()
	var columns := per_row(count)
	var rows := int(ceil(float(count) / float(columns)))
	var row := index / columns
	var in_row := mini(columns, count - row * columns)
	var row_width := float(in_row) * tile.x + float(in_row - 1) * gap
	var block := float(rows) * tile.y + float(rows - 1) * gap
	var top := area.position.y + maxf((area.size.y - block) * 0.5, 0.0)
	return Rect2(Vector2(area.position.x + (area.size.x - row_width) * 0.5
		+ float(index - row * columns) * (tile.x + gap), top + float(row) * (tile.y + gap)), tile)

## Das Band, in dem der Würfel liest.
func die_look() -> Vector2:
	return Vector2(item_px.y * DIE_LOOK_WIDTH, item_px.y * DIE_LOOK_HALF * 2.0)

func tile_air() -> float:
	return _unit() * TILE_AIR_UNITS

## Die Zellgröße der Netze - EINE für die ganze Aufstellung.
func net_cell(_count: int) -> float:
	return _tile_net_cell()

## Das Netz rechts neben seinem Würfel (Fenster-Pixel).
func net_rect(index: int, count: int) -> Rect2:
	var block := lineup_block(index, count)
	var span := DieNetView.net_size(net_cell(count))
	return Rect2(Vector2(block.end.x - tile_air() - span.x,
		block.get_center().y - span.y * 0.5), span)

## Ein Netz geht auf, wenn die Güte seines Würfels einrastet.
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

func net_shown(index: int) -> bool:
	return index >= 0 and index < _nets.size() and _nets[index].visible

## Die MITTEN der Plätze in Display-Pixeln - dort stellt scene_root die Körper hin.
func slot_centers() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if choice == null:
		return out
	for i in choice.option_count():
		var center := global_position + slot_rect(i, choice.option_count()).get_center()
		# Die geneigte Kamera projiziert den Würfel nach oben - er sitzt tiefer.
		if lineup():
			center.y += item_px.y * DIE_SEAT_DROP
		out.append(center)
	return out

# --- Aufbau -----------------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_slots.clear()
	_marks.clear()
	_hovered = -1
	if choice == null:
		return
	_nets.clear()
	_hover_face = NO_FACE
	var u := _unit()
	var count := choice.option_count()
	var frame := _frame_rects()
	var head: Rect2 = frame["head"]
	var buttons: Rect2 = frame["buttons"]
	var info: Rect2 = frame["info"]
	_title = CasinoStyle.label(choice.display_name, u * FONT_UNITS, TEXT_COLOR,
		HORIZONTAL_ALIGNMENT_LEFT, 3)
	_title.position = head.position
	_title.size = Vector2(head.size.x * HEAD_TITLE_SHARE, head.size.y)
	add_child(_title)
	_counter = CasinoStyle.label("", u * COUNT_FONT_UNITS, COUNT_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER, 3)
	_counter.position = head.position + Vector2(_title.size.x, 0.0)
	_counter.size = Vector2(head.size.x * HEAD_COUNT_SHARE, head.size.y)
	add_child(_counter)
	for label: Label in [_title, _counter]:
		label.clip_text = true
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
		slot.set_meta(&"sfx_silent", true)  # die Wahl klingt selbst
		slot.mouse_entered.connect(_on_slot_hover.bind(i, true))
		slot.mouse_exited.connect(_on_slot_hover.bind(i, false))
		slot.gui_input.connect(_on_slot_input.bind(i))
		add_child(slot)
		_slots.append(slot)
		if lineup() and choice.options[i] is DieDefinition:
			var net := DieNetView.build(choice.options[i] as DieDefinition, up_face, _net_cell)
			net.position = net_rect(i, count).position
			net.visible = _stage >= STAGE_LINEUP
			add_child(net)
			_nets.append(net)
			# Die Marke steht im leeren Lese-Band, sobald der Würfel auf seinem Platz schwebt.
			var mark := CasinoStyle.label("", u * MARK_FONT_UNITS, SLOT_ASSIGNED,
				HORIZONTAL_ALIGNMENT_CENTER, 3)
			mark.name = "Mark%d" % i
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			mark.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var band := slot_rect(i, count)
			mark.position = band.position
			mark.size = band.size
			mark.visible = false
			add_child(mark)
			_marks.append(mark)
	_info = CasinoStyle.label("", u * INFO_FONT_UNITS, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.clip_text = true
	_info.position = info.position
	_info.size = info.size
	add_child(_info)
	_die_info = DieInfoBand.new()
	_die_info.layout = DieInfoBand.Layout.LINE
	_die_info.position = info.position
	_die_info.size = info.size
	_die_info.visible = false
	add_child(_die_info)
	_reshuffle_button = _button("", u, false)
	_reshuffle_button.pressed.connect(func() -> void:
		if choosing():
			reshuffle_requested.emit())
	add_child(_reshuffle_button)
	_take_button = _button("", u, true)
	_take_button.pressed.connect(_on_take_pressed)
	add_child(_take_button)
	var button_size := Vector2((buttons.size.x - u) * 0.5, buttons.size.y)
	_take_button.position = buttons.position
	_reshuffle_button.position = buttons.position + Vector2(button_size.x + u, 0.0)
	_reshuffle_button.size = button_size
	_take_button.size = button_size
	# Neu mischen kostet ⚡: der Stand steht rechts in der Kopfzeile.
	_energy_label = CasinoStyle.label("", u * FONT_UNITS, CasinoStyle.ENERGY,
		HORIZONTAL_ALIGNMENT_RIGHT)
	_energy_label.name = "Energy"
	_energy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var energy: Rect2 = frame["energy"]
	_energy_label.position = energy.position
	_energy_label.size = energy.size
	add_child(_energy_label)
	# Würfel-Pakete mischen nicht neu: kein Knopf, keine Energie - der Knopf steht mittig.
	if choice != null and choice.is_dice():
		_reshuffle_button.visible = false
		_energy_label.visible = false
		_take_button.position.x = buttons.position.x + (buttons.size.x - button_size.x) * 0.5
	# Ein Klick ins Leere überspringt die Enthüllung.
	var skip := Button.new()
	skip.name = "Skip"
	skip.set_meta(&"sfx_silent", true)  # unsichtbarer Fang
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
	button.add_theme_font_size_override("font_size", maxi(8, int(u * BUTTON_FONT_UNITS)))
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

# --- Der ZÄHLER und der GLÜCKSWÜRFEL --------------------------------------------

## Die Optionen liegen: jetzt rollt der Glückswürfel (scene_root). Bis er liegt, steht
## keine Zahl - bei Würfel-Paketen gehen dabei die Netze auf.
func await_roll() -> void:
	if choice == null or _counted:
		return
	if lineup():
		_stage = STAGE_ROLL
		for i in _nets.size():
			reveal_net(i)
	_counting = true
	_refresh()

## Wartet das Fenster auf den Glückswürfel?
func awaiting_roll() -> bool:
	return choice != null and _counting and not _counted

## Der Glückswürfel liegt: das Fenster nennt die Wahlen (Endzustand, idempotent).
func die_landed() -> void:
	if choice == null or _counted:
		return
	if lineup():
		for i in _nets.size():
			_show_net_hard(i)
		_finish_opening()
	else:
		_finish_count()
	_pop(_counter)

## Ein Klick: der rollende Glückswürfel soll liegen (das führt scene_root).
func skip_count() -> void:
	if _counted or choice == null or lineup():
		return  # die Bühne der Würfel überspringt scene_root (skip_to_pick), samt Körpern
	roll_skip_requested.emit()

func _pop(label: Label) -> void:
	if label == null or not is_instance_valid(label):
		return
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * 1.35
	label.create_tween().tween_property(label, "scale", Vector2.ONE, COUNT_STEP * 0.8) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _finish_count() -> void:
	_counting = false
	_counted = true
	_refresh()

# --- Die BÜHNE der Würfel-Pakete --------------------------------------------------

func stage() -> int:
	return _stage

## Plätze gibt es erst ab der Aufstellung - beim Auswurf soll niemand mitzählen.
func slots_shown() -> bool:
	return not lineup() or _stage >= STAGE_LINEUP

## Die Würfel stehen in der Aufstellung: ihre Plätze erscheinen, und ihre Netze gehen auf.
func show_lineup() -> void:
	if not lineup() or _stage != STAGE_LAUNCH:
		return
	_stage = STAGE_LINEUP
	for i in _nets.size():
		reveal_net(i)
	_refresh()

## Der Saum eines Platzes: neutral.
func slot_rim(_index: int) -> Color:
	return SLOT_RIM

func _show_net_hard(index: int) -> void:
	if index < 0 or index >= _nets.size():
		return
	var net := _nets[index]
	var pop: Variant = net.get_meta("pop") if net.has_meta("pop") else null
	if pop is Tween and (pop as Tween).is_valid():
		(pop as Tween).kill()
	net.visible = true
	net.scale = Vector2.ONE
	net.modulate.a = 1.0

func _finish_opening() -> void:
	_stage = STAGE_PICK
	_counting = false
	_counted = true
	_refresh()
	opening_finished.emit()

## Endzustand zuerst: jedes Netz steht, die Zahl der Wahlen auch.
func skip_to_pick() -> void:
	if choice == null or not lineup() or _stage == STAGE_PICK:
		return
	for i in _nets.size():
		_show_net_hard(i)
	_finish_opening()

# --- Wählen -----------------------------------------------------------------------

func _on_slot_pressed(index: int) -> void:
	if not _counted:
		skip_count()
		return
	if assigning():
		arm(index)
		return
	toggle(index)

## Eine Option wählen oder abwählen; mehr als die Wahlen geht nicht.
func toggle(index: int) -> void:
	if choice == null or index < 0 or index >= choice.option_count():
		return
	if _selected.has(index):
		_selected.erase(index)
		pick_toggled.emit(index, false)
	elif _selected.size() < choice.picks:
		_selected.append(index)
		pick_toggled.emit(index, true)
	_refresh()

func _on_take_pressed() -> void:
	if not choosing():
		skip_count()
		return
	confirmed.emit(selected_indices())

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
	var assign_mode := assigning()
	for i in _slots.size():
		var placed := assign_mode and _assign.has(i)
		var picked := _armed == i if assign_mode else _selected.has(i)
		var taken := _assign.size() if assign_mode else _selected.size()
		var open := _counted and (picked or placed or taken < choice.picks)
		var rim := SLOT_PICKED if picked else (SLOT_ASSIGNED if placed else slot_rim(i))
		var width := 0.5 if picked else (0.35 if placed else 0.2)

		var box := CasinoStyle.flat_box(Color(1.0, 0.8, 0.2, 0.08) if picked else Color(0, 0, 0, 0),
			rim, u * width, u * 1.2, 0.0)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			_slots[i].add_theme_stylebox_override(state, box)
		_slots[i].modulate.a = 1.0 if open or not _counted else 0.45
		_slots[i].visible = slots_shown()
	for i in _marks.size():
		var label := assignment_label(i)
		_marks[i].text = "→ %s" % label if label != "" else ""
		_marks[i].visible = slots_shown() and label != ""
	if _counter != null and is_instance_valid(_counter):
		_counter.text = counter_text() if _counted else ""
	if _take_button != null and is_instance_valid(_take_button):
		_take_button.disabled = not _counted
		if assign_mode:
			_take_button.text = "Einsetzen (%d)" % _assign.size() if not _assign.is_empty() \
				else "Nichts nehmen"
		else:
			_take_button.text = "Nehmen (%d)" % _selected.size() if not _selected.is_empty() \
				else "Nichts nehmen"
	if _reshuffle_button != null and is_instance_valid(_reshuffle_button):
		var free := reshuffle_cost == 0
		_reshuffle_button.text = "Neu mischen (gratis)" if free \
			else "Neu mischen (%d ⚡)" % maxi(reshuffle_cost, 1)
		_reshuffle_button.disabled = not _counted or reshuffle_cost < 0 \
			or energy < reshuffle_cost
	if _energy_label != null and is_instance_valid(_energy_label):
		_energy_label.text = energy_text()
	_refresh_info()

func _refresh_info() -> void:
	if _info == null or not is_instance_valid(_info) or choice == null:
		return
	var die: DieDefinition = null
	var hovering := _hovered >= 0 and _hovered < choice.option_count()
	if hovering:
		var option: Variant = choice.options[_hovered]
		die = option as DieDefinition
		if die == null:
			_info.text = option_text(option)
			_info.modulate = TEXT_COLOR
	# Ein Würfel spricht über die EINE Würfel-Auskunft, die Zeile schweigt dann.
	if _die_info != null and is_instance_valid(_die_info):
		_die_info.show_info(die, _hover_face if _hover_face != NO_FACE else -1)
		_die_info.visible = die != null
	_info.visible = die == null
	if hovering:
		return
	_info.modulate = MUTED_COLOR
	if not _counted:
		_info.text = ""
	elif assigning():
		_info.text = assign_text()
	else:
		_info.text = "Ungewähltes verfällt."

## Der Zähler: nur „Wähle K von N“ - wie viele gewählt sind, sagt der Nehmen-Knopf.
func counter_text() -> String:
	if choice == null:
		return ""
	var text := "Wähle %d von %d" % [choice.picks, choice.option_count()]
	if choice.free_bonus > 0:
		text += " · Freie Hand +%d" % choice.free_bonus
	return text

## Die Ruhe-Zeile beim Zuordnen: wie weit der Entwurf ist.
func assign_text() -> String:
	if choice == null:
		return ""
	return "%d von %d eingesetzt" % [_assign.size(), choice.picks]

## Die Energie-Zeile: was Neu mischen bezahlen könnte.
func energy_text() -> String:
	return "Energie ⚡ %d" % energy

## Die Auskunft einer Option in EINER Zeile - aus den Quellen, die überall sprechen.
static func option_text(option: Variant) -> String:
	if option is Pack:
		var info := WorkshopInfoView.pack_info(option as Pack)
		return "%s · %s - %s" % [info["title"], info["sub"],
			String(info["body"]).replace("\n", " ")]
	return ""
