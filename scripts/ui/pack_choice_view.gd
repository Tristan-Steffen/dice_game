class_name PackChoiceView
extends Control
## Die PAKET-AUSWAHL: die Optionen eines geöffneten Pakets (die Körper stellt scene_root auf
## die gemeldeten PLÄTZE, in Display-Pixeln). KARTEN liegen auf der ÖFFNUNGS-FLÄCHE unter dem
## Lager (Kopf, Aufstellung, Auskunft, Knöpfe). WÜRFEL stehen ohne Schirm auf dem Filz als
## SCHIENE neben dem Vorrat: je Option eine Reihe (Würfel links, Netz rechts), höchstens
## drei je Spalte, darunter die Auskunft und der Knopf mit der Walze rechts daneben.
## Gebucht ist schon (GameRun.pending_pack_choices); das Fenster sammelt nur die Wahl
## und meldet sie. Erst der Inhalt, dann die Zahl: bei Karten klettert der Zähler 1 … K,
## bei Würfeln dreht die WALZE - ein Klick überspringt.

signal confirmed(indices: Array)
signal reshuffle_requested
## Eine Option wurde gewählt oder abgewählt (scene_root spielt den Ton).
signal pick_toggled(index: int, picked: bool)
## Die Bühne der Würfel-Pakete meldet ihre Momente (scene_root spielt Ton und Licht).
signal reel_stepped(value: int, top: int)
signal reel_stopped(value: int, top: int)
signal opening_finished

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
const SLOT_ROOM := 1.04
const SLOT_GAP_UNITS := 0.8

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
var _energy_label: Label
## Auf dem Tisch trägt die Fläche ihren eigenen Schirm (wie jedes Fenster).
var backdrop := false

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

## Welche Seite der liegende Würfel oben zeigt (sein Netz rahmt sie golden).
var up_face := -1
## Höchstens so viele Würfel stehen auf der Schiene.
const LINEUP_MAX := 10
## Leer sagt die Fläche nur, wie man sie füllt.
const IDLE_FONT_UNITS := 2.6
## Die Einheit folgt der Höhe; der Kopf ist so hoch wie sein Text.
const UNIT_DIV := 56.0
const TITLE_UNITS := 5.2
const FONT_UNITS := 1.6
## Der Zähler steht in EINER Zeile neben der Walze.
const COUNT_FONT_UNITS := 1.8
const BUTTON_FONT_UNITS := 1.7
const BUTTON_UNITS := 4.0
const INFO_UNITS := 4.2
## Die SCHIENE (Würfel-Pakete): höchstens RAIL_ROWS Reihen je Spalte, weitere Spalten
## rechts daneben. Ihre Einheit ist die Schienenhöhe / RAIL_UNITS; der Fuß (Auskunft, darunter
## Knopf und Walze) hängt darunter - einen Kopf hat sie nicht.
const RAIL_ROWS := 3
const RAIL_UNITS := 40.0
const RAIL_INFO_UNITS := 3.2
const RAIL_FOOT_UNITS := 8.5  # Fuge 0,6 + Auskunft 3,2 + Fuge 0,3 + Walze 4,4
const RAIL_GAP_UNITS := 0.8
const RAIL_INFO_FONT_UNITS := 1.5
const RAIL_BUTTON_SHARE := 0.45
## Wie der liegende Würfel an der geneigten Kamera LIEST (in Würfelkanten): DIE_LOOK_HALF
## über und unter seinem Sitz, quer DIE_LOOK_WIDTH. Der Sitz liegt RAIL_SEAT_DROP Kanten
## unter der Bandmitte, denn die Kamera projiziert den Würfel nach oben (gemessen).
const DIE_LOOK_HALF := 0.65
const DIE_LOOK_WIDTH := 1.7
const RAIL_SEAT_DROP := 0.22
## Die Kachel: gleiche Luft links und rechts (sie trägt auch den Hub der Wahl).
const TILE_AIR_UNITS := 1.3
const NET_GAP_UNITS := 1.0
const NET_CELL_MAX_UNITS := 6.5
const ENERGY_UNITS := 2.4
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
## Netze gehen auf) → Walze → Wahl.
const STAGE_LAUNCH := 0
const STAGE_LINEUP := 1
const STAGE_REEL := 2
const STAGE_PICK := 3
## Die WALZE der Wahlen: ein kleiner Automat, dessen eine Walze die Zahlen von der Grundzahl
## bis Würfelzahl − 1 durchdreht - mindestens so viele Schritte, vom schnellen zum langsamen Takt.
const REEL_MIN_SPINS := 14
const REEL_FAST := 0.05
const REEL_SLOW := 0.36
const REEL_HOLD := 0.5
const REEL_UNITS := 4.4
const REEL_WIDTH_UNITS := 7.0
const REEL_WINDOW_SHARE := 0.5
const REEL_CABINET := Color(0.09, 0.08, 0.14, 0.95)
const REEL_GLASS := Color(0.02, 0.02, 0.05, 1.0)

var _stage := STAGE_PICK
var _reel_box: Panel
var _reel_window: Control
var _reel_now: Label
var _reel_next: Label
var _reel_tween: Tween
var _reel_value := -1
var _reel_done := false
var _show_tween: Tween

func _unit() -> float:
	if lineup():
		return maxf(size.y / (RAIL_UNITS + RAIL_FOOT_UNITS), 1.0)
	return maxf(size.y / UNIT_DIV, 1.0)

## Die Texthöhe des Kopfs: Name, Walze bzw. Zähler, Energie.
func _head_text_units() -> float:
	return TITLE_UNITS + 0.2 + REEL_UNITS + 0.3 + ENERGY_UNITS

func head_height() -> float:
	return _unit() * _head_text_units()

func _draw() -> void:
	if backdrop:
		draw_style_box(TableScreen.window_style(), Rect2(Vector2.ZERO, size))

## Das Fenster der SCHIENE zu ihrem Rechteck (Display-Pixel, rein): oben bündig mit ihr,
## der Fuß darunter in ihrer Einheit.
static func rail_window_for(rail: Rect2) -> Rect2:
	if rail.size.x <= 0.0 or rail.size.y <= 0.0:
		return Rect2()
	var u := rail.size.y / RAIL_UNITS
	return Rect2(rail.position, Vector2(rail.size.x, rail.size.y + u * RAIL_FOOT_UNITS))

## Das Rechteck der ÖFFNUNGS-FLÄCHE in Display-Pixeln (rein, prüfbar): so breit wie das
## Lager, nahtlos an seiner Unterkante, unten bis bottom (die Unterkante der Die-View).
static func area_for(store: Rect2, bottom: float) -> Rect2:
	if store.size.x <= 0.0 or bottom <= store.end.y:
		return Rect2()
	return Rect2(Vector2(store.position.x, store.end.y),
		Vector2(store.size.x, bottom - store.end.y))

## Die festen Felder der Seite (Fenster-Pixel): Kopf (Text rechts der Hülle), Energie,
## Auskunft und die Knopfzeile.
func _frame_rects() -> Dictionary:
	if lineup():
		return _rail_frame_rects()
	var u := _unit()
	var head := Rect2(Vector2(u, u), Vector2(maxf(size.x - u * 2.0, u), u * _head_text_units()))
	var energy := Rect2(Vector2(head.position.x, head.end.y - u * ENERGY_UNITS),
		Vector2(head.size.x, u * ENERGY_UNITS))
	var buttons := Rect2(Vector2(u, size.y - u - u * BUTTON_UNITS),
		Vector2(size.x - u * 2.0, u * BUTTON_UNITS))
	var info := Rect2(Vector2(u, buttons.position.y - u * (INFO_UNITS + 0.4)),
		Vector2(size.x - u * 2.0, u * INFO_UNITS))
	return {"head": head, "buttons": buttons, "info": info, "energy": energy}

## Die Felder der SCHIENE (Fenster-Pixel): oben die Schiene, darunter die Auskunft über
## die volle Breite und zuunterst der Knopf, rechts daneben die Walze.
func _rail_frame_rects() -> Dictionary:
	var u := _unit()
	var rail := Rect2(Vector2.ZERO, Vector2(size.x, u * RAIL_UNITS))
	var info := Rect2(Vector2(0.0, rail.end.y + u * 0.6), Vector2(size.x, u * RAIL_INFO_UNITS))
	var row := info.end.y + u * 0.3
	var buttons := Rect2(Vector2(0.0, row), Vector2(size.x * RAIL_BUTTON_SHARE, u * REEL_UNITS))
	var reel := Rect2(Vector2(buttons.end.x + u, row), Vector2(u * REEL_WIDTH_UNITS, u * REEL_UNITS))
	return {"head": Rect2(), "reel": reel, "rail": rail, "info": info, "buttons": buttons,
		"energy": Rect2()}

## Die SCHIENE der Würfel-Pakete (sonst die Reihe der Karten-Pakete).
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
	if choice != null and choice.take_all and not lineup():
		for i in choice.option_count():
			_selected.append(i)
	_counted = counted
	_counting = false
	_kill_count()
	_kill_show()
	_stage = STAGE_LAUNCH if lineup() and not counted else STAGE_PICK
	_reel_done = _stage == STAGE_PICK
	_reel_value = choice.picks if choice != null and _reel_done else -1
	_build()
	visible = true
	queue_redraw()

## Zu: auf dem Tisch bleibt die Fläche stehen und zeigt ihren Leer-Zustand.
func close() -> void:
	_kill_count()
	_kill_show()
	choice = null
	_counted = false
	_counting = false
	_selected.clear()
	_assign.clear()
	_assign_label.clear()
	_armed = -1
	visible = backdrop
	_build()

## Der Leer-Zustand: ein ruhiger Hinweis, keine Knöpfe. Nur der Wechsel baut neu.
var idle_text := ""
var _idle_size := Vector2.ZERO

func set_idle_text(text: String) -> void:
	if text == idle_text and size == _idle_size:
		return
	idle_text = text
	if choice == null:
		_build()

func idle_label() -> Label:
	return get_node_or_null("Idle") as Label

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

## Das Magazin-Tablett einer Karten-Option (ihre Sorte, -1 = keine Karte).
func option_shelf_tray(index: int) -> int:
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
	var u := _unit()
	var slot := item_px.x * SLOT_ROOM
	var usable := lineup_area().size.x
	var fits := maxi(1, int((usable + u * SLOT_GAP_UNITS) / (slot + u * SLOT_GAP_UNITS)))
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

## Die Fläche der Aufstellung (bei Würfeln die Schiene) in Display-Pixeln.
func lineup_area_px() -> Rect2:
	var area := lineup_area()
	return Rect2(global_position + area.position, area.size)

## Wo die Hülle eines Karten-Pakets aufgeht: über der Mitte der Aufstellung.
func hull_seat_px() -> Vector2:
	return global_position + lineup_area().get_center()

## Die Fläche der Aufstellung: unter dem Kopf, über der Auskunft, volle Breite - bei
## Würfeln die Schiene selbst.
func lineup_area() -> Rect2:
	if lineup():
		return _rail_frame_rects()["rail"]
	var u := _unit()
	var top := u * 2.0 + head_height()
	var info: Rect2 = _frame_rects()["info"]
	return Rect2(Vector2(u, top),
		Vector2(size.x - u * 2.0, maxf(info.position.y - u * 0.6 - top, 1.0)))

## Spalten × Reihen der Schiene: höchstens RAIL_ROWS untereinander, dann die nächste
## Spalte rechts daneben.
static func rail_grid(count: int) -> Vector2i:
	var n := clampi(count, 1, LINEUP_MAX)
	return Vector2i(int(ceil(float(n) / float(RAIL_ROWS))), mini(n, RAIL_ROWS))

## Die Teilung der Schiene: drei Reihen füllen ihre Höhe, je Reihe bleibt eine Fuge.
func rail_pitch() -> float:
	return lineup_area().size.y / float(RAIL_ROWS)

func _rail_gap() -> float:
	return _unit() * RAIL_GAP_UNITS

## Die Netz-Zelle einer Kachel (rein): die Höhe der Reihe bindet, die Spaltenbreite deckelt.
static func rail_cell(u: float, die_px: float, pitch: float, column: float) -> float:
	var air := u * TILE_AIR_UNITS * 2.0
	var avail := Vector2(column - air - die_px * DIE_LOOK_WIDTH - u * NET_GAP_UNITS,
		pitch - u * RAIL_GAP_UNITS - air)
	if avail.x <= 0.0 or avail.y <= 0.0:
		return 0.0
	return minf(DieNetView.cell_for(avail), u * NET_CELL_MAX_UNITS)

## Die Breite einer Kachel: Luft, Würfel, Fuge, Netz, dieselbe Luft.
static func rail_tile_width(u: float, die_px: float, cell: float) -> float:
	return u * TILE_AIR_UNITS * 2.0 + die_px * DIE_LOOK_WIDTH + u * NET_GAP_UNITS \
		+ DieNetView.net_size(cell).x

## Wie breit die Schiene zu ihrer Höhe sein muß (rein): ihre Spalten, mindestens zwei -
## der Fuß braucht neben dem Knopf Platz für den Vergleich.
static func rail_width_for(height: float, die_px: float, count: int) -> float:
	var u := height / RAIL_UNITS
	var cell := rail_cell(u, die_px, height / float(RAIL_ROWS), 1.0e9)
	var columns := maxi(rail_grid(count).x, 2)
	return rail_tile_width(u, die_px, cell) * float(columns) \
		+ u * RAIL_GAP_UNITS * float(columns - 1)

func _rail_net_cell(count: int) -> float:
	var grid := rail_grid(count)
	var column := (lineup_area().size.x - _rail_gap() * float(grid.x - 1)) / float(grid.x)
	return rail_cell(_unit(), item_px.y, rail_pitch(), column)

## Die Kachel liegt QUER und folgt dem INHALT; hoch ist sie eine Teilung ohne Fuge.
func block_size(count: int) -> Vector2:
	return Vector2(rail_tile_width(_unit(), item_px.y, _rail_net_cell(count)),
		rail_pitch() - _rail_gap())

## Die Kachel einer Option: Spalte = index / 3 von links, Reihe = index % 3 von oben.
func lineup_block(index: int, count: int) -> Rect2:
	var area := lineup_area()
	var cell := block_size(count)
	var column := index / RAIL_ROWS
	var row := index % RAIL_ROWS
	return Rect2(Vector2(area.position.x + float(column) * (cell.x + _rail_gap()),
		area.position.y + float(row) * rail_pitch()), cell)

## Das Band, in dem der Würfel liest.
func die_look() -> Vector2:
	return Vector2(item_px.y * DIE_LOOK_WIDTH, item_px.y * DIE_LOOK_HALF * 2.0)

func tile_air() -> float:
	return _unit() * TILE_AIR_UNITS

## Die Zellgröße der Netze - EINE für die ganze Schiene.
func net_cell(count: int) -> float:
	return _rail_net_cell(count)

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
			center.y += item_px.y * RAIL_SEAT_DROP
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
		_idle_size = size
		if idle_text != "":
			var idle := CasinoStyle.label(idle_text, _unit() * IDLE_FONT_UNITS, MUTED_COLOR,
				HORIZONTAL_ALIGNMENT_CENTER)
			idle.name = "Idle"
			idle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			idle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			idle.clip_text = true
			idle.mouse_filter = Control.MOUSE_FILTER_IGNORE
			idle.position = Vector2.ZERO
			idle.size = size
			add_child(idle)
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
		HORIZONTAL_ALIGNMENT_CENTER, 3)
	_title.position = head.position
	_title.size = Vector2(head.size.x, u * TITLE_UNITS)
	add_child(_title)
	_counter = CasinoStyle.label("", u * COUNT_FONT_UNITS, COUNT_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER, 3)
	_counter.position = head.position + Vector2(0.0, u * (TITLE_UNITS + 0.2))
	_counter.size = Vector2(head.size.x, u * REEL_UNITS)
	add_child(_counter)
	# Der schmale Kopf bricht Name und Zähler auf zwei Zeilen um.
	for label: Label in [_title, _counter]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = true
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if lineup():
		# Auf der Schiene stehen weder Name noch Zähler - die Walze am Knopf sagt die Zahl.
		_title.visible = false
		_counter.visible = false
		_build_reel(frame["reel"])
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
	_info = CasinoStyle.label("", u * (RAIL_INFO_FONT_UNITS if lineup() else 2.0), MUTED_COLOR,
		HORIZONTAL_ALIGNMENT_LEFT if lineup() else HORIZONTAL_ALIGNMENT_CENTER)
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
	var button_size := Vector2((buttons.size.x - u) * 0.5, buttons.size.y)
	_take_button.position = buttons.position
	_reshuffle_button.position = buttons.position + Vector2(button_size.x + u, 0.0)
	_reshuffle_button.size = button_size
	_take_button.size = button_size
	# Neu mischen kostet ⚡: der Stand steht klein im Kopf.
	_energy_label = CasinoStyle.label("", u * ENERGY_UNITS, CasinoStyle.ENERGY,
		HORIZONTAL_ALIGNMENT_CENTER)
	_energy_label.name = "Energy"
	_energy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var energy: Rect2 = frame["energy"]
	_energy_label.position = energy.position
	_energy_label.size = energy.size
	add_child(_energy_label)
	# Würfel-Pakete mischen nicht neu: kein Knopf, keine Energie-Anzeige.
	if choice != null and choice.is_dice():
		_reshuffle_button.visible = false
		_energy_label.visible = false
		_take_button.size.x = buttons.size.x
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
	if lineup():
		return  # die Bühne der Würfel überspringt scene_root (skip_to_pick), samt Körpern
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

## Die höchste Zahl der Walze: Würfelzahl − 1.
static func reel_top(count: int) -> int:
	return DicePack.max_picks(count)

## Was die Walze nacheinander zeigt: von der Grundzahl an im Kreis durch alle möglichen
## Zahlen, mindestens REEL_MIN_SPINS Schritte, und sie hält auf der gebuchten (rein, prüfbar).
static func reel_path(base: int, picks: int, top: int) -> Array[int]:
	var high := maxi(top, 1)
	var low := clampi(base, 1, high)
	var goal := clampi(picks, low, high)
	var path: Array[int] = [low]
	var at := low
	var guard := 0
	while (path.size() < REEL_MIN_SPINS or at != goal) and guard < 200:
		at = low if at >= high else at + 1
		path.append(at)
		guard += 1
	return path

## Der Takt vor Schritt i von n: schnell am Anfang, immer langsamer zum Halt.
static func reel_beat(index: int, count: int) -> float:
	var share := clampf(float(index) / float(maxi(count - 1, 1)), 0.0, 1.0)
	return lerpf(REEL_FAST, REEL_SLOW, share * share * share)

## Die Zahl im Fenster der Walze (−1 = sie steht noch nicht).
func reel_value() -> int:
	return _reel_value

func reel_done() -> bool:
	return _reel_done

func reel_shown() -> bool:
	return _reel_box != null and is_instance_valid(_reel_box) and _reel_box.visible

## Der kleine Automat im Kopf: Gehäuse mit Goldrand, dunkles Fenster, EINE Walze.
func _build_reel(rect: Rect2) -> void:
	var u := _unit()
	var box := rect.size
	_reel_box = Panel.new()
	_reel_box.name = "PickReel"
	_reel_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reel_box.position = rect.position
	_reel_box.size = box
	_reel_box.pivot_offset = box * 0.5
	add_child(_reel_box)
	var window := Vector2(box.x * REEL_WINDOW_SHARE, box.y - u * 0.9)
	var glass := Panel.new()
	glass.name = "Glass"
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.position = (box - window) * 0.5
	glass.size = window
	glass.add_theme_stylebox_override("panel", CasinoStyle.flat_box(REEL_GLASS,
		CasinoStyle.GOLD_DARK, u * 0.15, u * 0.4, 0.0))
	_reel_box.add_child(glass)
	_reel_window = Control.new()
	_reel_window.name = "Window"
	_reel_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reel_window.clip_contents = true
	_reel_window.position = glass.position
	_reel_window.size = window
	_reel_box.add_child(_reel_window)
	_reel_now = _reel_symbol(window)
	_reel_next = _reel_symbol(window)
	_reel_next.position.y = -window.y
	# Die Zahllinie: zwei Marken links und rechts vom Fenster.
	for side in [-1.0, 1.0]:
		var mark := CasinoStyle.label("\u25B8" if side < 0.0 else "\u25C2", window.y * 0.5,
			CasinoStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gap := (box.x - window.x) * 0.5
		mark.position = Vector2(0.0 if side < 0.0 else box.x - gap, 0.0)
		mark.size = Vector2(gap, box.y)
		_reel_box.add_child(mark)

func _reel_symbol(window: Vector2) -> Label:
	var symbol := CasinoStyle.label("", window.y * 0.78, TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER, 3)
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	symbol.size = window
	_reel_window.add_child(symbol)
	return symbol

## Der EINE Maler der Walze: sichtbar ab ihrer Phase, die gehaltene Zahl in Gold.
func _paint_reel() -> void:
	if _reel_box == null or not is_instance_valid(_reel_box):
		return
	var u := _unit()
	_reel_box.visible = lineup() and _stage >= STAGE_REEL
	_reel_box.add_theme_stylebox_override("panel", CasinoStyle.flat_box(REEL_CABINET,
		COUNT_COLOR if _reel_done else CasinoStyle.GOLD, u * 0.3, u * 0.9, 0.0))
	if _reel_tween != null and _reel_tween.is_valid():
		return
	_reel_now.text = "%d" % _reel_value if _reel_value > 0 else ""
	_reel_now.position.y = 0.0
	_reel_now.add_theme_color_override("font_color", COUNT_COLOR if _reel_done else TEXT_COLOR)
	_reel_next.position.y = -_reel_window.size.y

## Ein Schritt der Walze: die neue Zahl rollt von oben ins Fenster, die alte unten hinaus.
func _roll_reel(value: int, time: float, last: bool) -> void:
	if _reel_box == null or not is_instance_valid(_reel_box):
		return
	_kill_reel()
	var drop := _reel_window.size.y
	_reel_next.text = "%d" % value
	_reel_next.add_theme_color_override("font_color", COUNT_COLOR if last else TEXT_COLOR)
	_reel_next.position.y = -drop
	_reel_now.position.y = 0.0
	_reel_tween = create_tween().set_parallel(true)
	var ease_out := Tween.TRANS_BACK if last else Tween.TRANS_LINEAR
	_reel_tween.tween_property(_reel_next, "position:y", 0.0, time).set_trans(ease_out) \
		.set_ease(Tween.EASE_OUT)
	_reel_tween.tween_property(_reel_now, "position:y", drop, time).set_trans(ease_out) \
		.set_ease(Tween.EASE_OUT)
	_reel_tween.chain().tween_callback(_land_reel)

func _land_reel() -> void:
	_reel_tween = null
	var swap := _reel_now
	_reel_now = _reel_next
	_reel_next = swap
	_paint_reel()

func _kill_reel() -> void:
	var rolling := _reel_tween != null and _reel_tween.is_valid()
	if rolling:
		_reel_tween.kill()
	_reel_tween = null
	if rolling and _reel_box != null and is_instance_valid(_reel_box):
		_land_reel()

## Die Walze läuft als EIN Ablauf; ein Klick springt ans Ende (skip_to_pick).
func play_reel() -> void:
	if not lineup() or choice == null or _stage >= STAGE_REEL:
		return
	for i in _nets.size():
		reveal_net(i)
	_kill_show()
	_start_reel()
	_show_tween = create_tween()
	var top := reel_top(choice.option_count())
	var path := reel_path(choice.base_picks, choice.picks, top)
	for k in range(1, path.size()):
		var beat := reel_beat(k, path.size())
		_show_tween.tween_callback(_reel_to.bind(path[k], k == path.size() - 1, beat))
		_show_tween.tween_interval(beat)
	_show_tween.tween_interval(REEL_HOLD)
	_show_tween.tween_callback(_finish_opening)

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

func _start_reel() -> void:
	_stage = STAGE_REEL
	_reel_value = choice.base_picks if choice != null else -1
	_refresh()

func _reel_to(value: int, last: bool, time: float) -> void:
	if choice == null:
		return
	_reel_value = value
	var top := reel_top(choice.option_count())
	if last:
		_reel_done = true
	_roll_reel(value, time, last)
	if last:
		_paint_reel()
		_reel_box.scale = Vector2.ONE * 1.18
		_reel_box.create_tween().tween_property(_reel_box, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reel_stopped.emit(value, top)
	else:
		reel_stepped.emit(value, top)

func _finish_opening() -> void:
	_show_tween = null
	_stage = STAGE_PICK
	_reel_done = true
	_reel_value = choice.picks if choice != null else -1
	_counting = false
	_counted = true
	_refresh()
	opening_finished.emit()

## Endzustand zuerst: jedes Netz steht, die Walze auf der gebuchten Zahl.
func skip_to_pick() -> void:
	if choice == null or not lineup() or _stage == STAGE_PICK:
		return
	_kill_show()
	for i in _nets.size():
		_show_net_hard(i)
	_finish_opening()

func _kill_show() -> void:
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
	_show_tween = null
	_kill_reel()

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
	_paint_reel()
	if _counter != null and is_instance_valid(_counter) and _counted:
		_counter.scale = Vector2.ONE
		if choice.take_all:
			_counter.text = "ALLE nehmen"
		else:
			_counter.text = counter_text()
	if _take_button != null and is_instance_valid(_take_button):
		_take_button.disabled = not _counted
		# Ohne Schirm steht auf der Schiene kein grauer Knopf: er kommt mit der Wahl.
		_take_button.visible = not lineup() or _counted
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
	elif assigning():
		_info.text = assign_text()
	elif choice.take_all:
		_info.text = "Alles gehört dir."
	else:
		_info.text = "Ungewähltes verfällt."

## Der Zähler: nur „Wähle K von N“ - wie viele gewählt sind, sagt der Nehmen-Knopf.
func counter_text() -> String:
	if choice == null:
		return ""
	return "Wähle %d von %d" % [choice.picks, choice.option_count()]

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
	if option is DieDefinition:
		return ShopController.die_foot_text(option as DieDefinition)
	return ""
