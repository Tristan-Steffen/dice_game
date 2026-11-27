class_name FloorMapView
extends Control
## Die ETAGEN-KARTE auf dem Grubenboden: Räume als Kacheln an ihrem Rasterplatz,
## Türen als Stege dazwischen, der Puck auf dem Standraum. Ein Klick auf einen
## gangbaren Nachbarraum (oder seine Tür) ist der Zug der Runde. Kennt GameRun nicht:
## sie malt GameRun.floor_view_state.

## Der gewählte Zug (Tür-Id).
signal door_chosen(door_id: String)

const ENTRANCE_HEAD := "Etage %d · Eingang"
const MOVE_HEAD := "Etage %d · Zug %d"
const BLIND_HEAD := "Blind %d"
const FREE_TEXT := "frei"
const UNKNOWN_TEXT := "?"
const BLIND_LINE := "Blind nach diesem Zug: %d (+%d %%)"
const IDLE_TITLE := "Wähle den nächsten Raum"
const IDLE_BODY := "Der Zug unterschreibt den Malus der Tür und den Bonus des Raums."
const ENTRANCE_BODY := "Hier beginnt die Etage. Kein Bonus."
const OFFICE_BODY := "Das Büro des Pit Boss: der Zug hierher macht die Runde zur Boss-Runde."
const VISITED_BODY := "Besucht - der Bonus ist unterschrieben."
const FREE_TITLE := "Freie Tür"
const FREE_BODY := "Nichts zu unterschreiben."
const UNKNOWN_TITLE := "Unerkundete Tür"
const UNKNOWN_BODY := "Ihr Inhalt zeigt sich, sobald der Puck in einem ihrer Räume steht."
const LOCKED_TITLE := "Gesperrte Tür"
const LOCKED_BODY := "Ein Fumble hat sie für den Rest der Etage geschlossen."
const PASSED_TITLE := "Durchschritten"
const PASSED_BODY := "Ausgebrannt - nichts mehr zu unterschreiben."
const OFFICE_SUB := "Boss-Runde"

const TEXT_COLOR := Color("#e8e6ff")
const MUTED_COLOR := Color("#9a93c9")
const TILE_BG := Color(0.07, 0.06, 0.16, 0.96)
const FOOT_BG := Color(0.05, 0.045, 0.12, 0.97)
const PASSED_COLOR := Color(0.82, 0.95, 1.0, 0.95)
const UNKNOWN_COLOR := Color(0.55, 0.52, 0.72, 0.8)
const LOCKED_COLOR := Color("#ff3b3b")
const ENTRANCE_COLOR := Color("#8be9fd")
const BRASS := Color("#d4a94a")
const BRASS_DARK := Color("#8a6420")
const BRASS_LIGHT := Color("#f6dc93")
const VISITED_ALPHA := 0.45

## Raster: Spaltenbreiten in Teilen von Kachel, Eingang, Büro und Fuge.
const ROOM_PART := 1.0
const ENTRANCE_PART := 0.55
const OFFICE_PART := 0.85
const GAP_PART := 1.1
## Senkrechte Fuge zwischen zwei Reihen, in Teilen einer Kachelhöhe.
const ROW_GAP_PART := 0.5
## Maße in u (u = min(Breite/100, Höhe/46)).
const PAD_UNITS := 1.0
const HEAD_UNITS := 3.2
const FOOT_UNITS := 7.2
const BAND_GAP_UNITS := 0.6
const NAME_UNITS := 1.75
const BONUS_UNITS := 1.45
const MARK_BIG_UNITS := 1.45
const MARK_SMALL_UNITS := 1.0
const HEAD_FONT_UNITS := 2.3
const INFO_TITLE_UNITS := 1.8
const INFO_BODY_UNITS := 1.6
const PUCK_UNITS := 1.5
const FLASH_TIME := 1.1

## Der Zustand aus GameRun.floor_view_state (leer = geschlossen).
var state: Dictionary = {}
## Bonus-Faktor des Winkeladvokats für die Klausel-Texte.
var bonus_factor := 1

var _rooms: Dictionary = {}  # id -> Raum-Dictionary
var _doors: Dictionary = {}  # id -> Tür-Dictionary
var _walk_rooms: Dictionary = {}  # Zielraum -> Tür-Id der gangbaren Züge
var _hover: Dictionary = {}  # {kind, id} unter dem Zeiger
var _flash_door := ""
var _flash := 0.0
var _flash_tween: Tween
var _head_left: Label
var _head_right: Label
var _info_title: Label
var _info_body: Label

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

## Baut die Karte aus dem Zustand neu und zeigt sie; flash_door blitzt einmal rot.
func open(view_state: Dictionary, deal_bonus_factor: int = 1, flash_door: String = "") -> void:
	state = view_state.duplicate(true)
	bonus_factor = deal_bonus_factor
	_rooms.clear()
	_doors.clear()
	_walk_rooms.clear()
	for room: Dictionary in state.get("rooms", []):
		_rooms[String(room["id"])] = room
	for door: Dictionary in state.get("doors", []):
		_doors[String(door["id"])] = door
	var here := String(state.get("position", ""))
	for door_id: String in state.get("walkable", []):
		var door: Dictionary = _doors.get(door_id, {})
		if not door.is_empty():
			_walk_rooms[_other_side(door, here)] = door_id
	_hover = {}
	visible = true
	_build()
	_flash_door = flash_door if _doors.has(flash_door) else ""
	_start_flash()

func close() -> void:
	visible = false
	_hover = {}
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash = 0.0

func walkable_doors() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(state.get("walkable", []))
	return ids

## Die Tür, deren Zug der Klick auf den Raum wäre ("" = kein gangbarer Nachbar).
func door_to(room_id: String) -> String:
	return String(_walk_rooms.get(room_id, ""))

func flashing_door() -> String:
	return _flash_door if _flash > 0.0 else ""

# --- Geometrie ------------------------------------------------------------------

func _unit() -> float:
	return maxf(minf(size.x / 100.0, size.y / 46.0), 1.0)

func _map_rect() -> Rect2:
	var u := _unit()
	var top := u * (PAD_UNITS + HEAD_UNITS + BAND_GAP_UNITS)
	var bottom := size.y - u * (PAD_UNITS + FOOT_UNITS + BAND_GAP_UNITS)
	return Rect2(u * PAD_UNITS, top, size.x - u * PAD_UNITS * 2.0, maxf(bottom - top, 1.0))

func _foot_rect() -> Rect2:
	var u := _unit()
	return Rect2(u * PAD_UNITS, size.y - u * (PAD_UNITS + FOOT_UNITS),
		size.x - u * PAD_UNITS * 2.0, u * FOOT_UNITS)

func _grid_size() -> Vector2i:
	var cols := 1
	var rows := 1
	for room: Dictionary in _rooms.values():
		var cell: Vector2i = room["cell"]
		cols = maxi(cols, cell.x + 1)
		rows = maxi(rows, cell.y + 1)
	return Vector2i(cols, rows)

## Linke Kante und Breite der Kachel in Spalte col.
func _column_span(col: int) -> Vector2:
	var grid := _grid_size()
	var map := _map_rect()
	var parts := ENTRANCE_PART + OFFICE_PART + ROOM_PART * float(grid.x - 2) + GAP_PART * float(grid.x - 1)
	var part := map.size.x / parts
	var x := map.position.x
	for c in grid.x:
		var w := ROOM_PART
		if c == 0:
			w = ENTRANCE_PART
		elif c == grid.x - 1:
			w = OFFICE_PART
		if c == col:
			return Vector2(x, w * part)
		x += (w + GAP_PART) * part
	return Vector2(x, ROOM_PART * part)

## Kachelhöhe und Reihenteilung.
func _row_metrics() -> Vector2:
	var rows := _grid_size().y
	var map := _map_rect()
	var tile := map.size.y / (float(rows) + ROW_GAP_PART * float(rows - 1))
	return Vector2(tile, tile * (1.0 + ROW_GAP_PART))

## Eingang und Büro stehen über alle Reihen - so liegen ihre Türen waagerecht.
func _is_tall(room: Dictionary) -> bool:
	return bool(room.get("entrance", false)) or bool(room.get("office", false))

func room_rect(room_id: String) -> Rect2:
	var room: Dictionary = _rooms.get(room_id, {})
	if room.is_empty():
		return Rect2()
	var cell: Vector2i = room["cell"]
	var span := _column_span(cell.x)
	var map := _map_rect()
	if _is_tall(room):
		return Rect2(span.x, map.position.y, span.y, map.size.y)
	var rows := _row_metrics()
	return Rect2(span.x, map.position.y + rows.y * float(cell.y), span.y, rows.x)

## Der Steg einer Tür als [Anfang, Ende] zwischen den Kachelkanten.
func door_segment(door_id: String) -> PackedVector2Array:
	var door: Dictionary = _doors.get(door_id, {})
	if door.is_empty():
		return PackedVector2Array()
	var a: Dictionary = _rooms.get(String(door["a"]), {})
	var b: Dictionary = _rooms.get(String(door["b"]), {})
	var ra := room_rect(String(door["a"]))
	var rb := room_rect(String(door["b"]))
	var ca: Vector2i = a["cell"]
	var cb: Vector2i = b["cell"]
	if ca.x == cb.x:
		var upper := ra if ca.y < cb.y else rb
		var lower := rb if ca.y < cb.y else ra
		var x := upper.get_center().x
		return PackedVector2Array([Vector2(x, upper.end.y), Vector2(x, lower.position.y)])
	var left := ra if ca.x < cb.x else rb
	var right := rb if ca.x < cb.x else ra
	# Am hohen Eingang bzw. Büro liegt der Steg auf der Reihe des anderen Raums.
	var y := right.get_center().y if _is_tall(a if ca.x < cb.x else b) else left.get_center().y
	return PackedVector2Array([Vector2(left.end.x, y), Vector2(right.position.x, y)])

func _door_vertical(door_id: String) -> bool:
	var seg := door_segment(door_id)
	return seg.size() == 2 and is_equal_approx(seg[0].x, seg[1].x)

## Die Marke einer Tür: mittig auf dem Steg, nie auf einer Kachel.
func door_mark_rect(door_id: String) -> Rect2:
	var seg := door_segment(door_id)
	if seg.size() != 2:
		return Rect2()
	var u := _unit()
	var mid := (seg[0] + seg[1]) * 0.5
	var door: Dictionary = _doors[door_id]
	if not bool(door.get("scouted", false)) or int(door["state"]) != FloorMap.DoorState.OPEN:
		var side := u * 2.6
		return Rect2(mid - Vector2(side, side) * 0.5, Vector2(side, side))
	var gap := seg[0].distance_to(seg[1])
	var size_px: Vector2
	if _door_vertical(door_id):
		# In der Fuge zwischen zwei Reihen ist quer Platz bis knapp an die Nachbar-Spalte.
		var cell: Vector2i = _rooms[String(door["a"])]["cell"]
		size_px = Vector2(_column_span(cell.x).y * 1.5, minf(gap - u * 0.6, u * 2.9))
	else:
		size_px = Vector2(gap - u * 0.8, minf(_row_metrics().x * 0.86, u * 6.0))
	return Rect2(mid - size_px * 0.5, size_px)

## Was unter dem Punkt liegt: {kind: "room"|"door", id} (leer = nichts).
func target_at(local: Vector2) -> Dictionary:
	for door_id: String in _doors:
		if door_mark_rect(door_id).grow(_unit() * 0.3).has_point(local):
			return {"kind": "door", "id": door_id}
	for room_id: String in _rooms:
		if room_rect(room_id).has_point(local):
			return {"kind": "room", "id": room_id}
	for door_id: String in _doors:
		var seg := door_segment(door_id)
		if seg.size() == 2 and Rect2(seg[0], Vector2.ZERO).expand(seg[1]).grow(_unit() * 0.8).has_point(local):
			return {"kind": "door", "id": door_id}
	return {}

## Der Zug hinter dem Ziel ("" = es nimmt keinen Klick).
func move_for(target: Dictionary) -> String:
	if target.is_empty():
		return ""
	if target["kind"] == "room":
		return door_to(String(target["id"]))
	var door_id := String(target["id"])
	return door_id if walkable_doors().has(door_id) else ""

# --- Eingabe --------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_at((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			press_at(button.position)
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover_at(Vector2(-1, -1))

func hover_at(local: Vector2) -> void:
	var target := target_at(local) if local.x >= 0.0 else {}
	if target == _hover:
		return
	_hover = target
	_write_info()
	var shape := Control.CURSOR_POINTING_HAND if move_for(target) != "" else Control.CURSOR_ARROW
	mouse_default_cursor_shape = shape
	queue_redraw()

## Klick an der Stelle: ein gangbarer Nachbar meldet seinen Zug.
func press_at(local: Vector2) -> bool:
	var door_id := move_for(target_at(local))
	if door_id == "":
		return false
	door_chosen.emit(door_id)
	return true

# --- Auskunft -------------------------------------------------------------------

func info_text() -> String:
	if _info_title == null:
		return ""
	return _info_title.text + "\n" + _info_body.text

func _write_info() -> void:
	if _info_title == null:
		return
	var title := IDLE_TITLE
	var body := IDLE_BODY + " " + _blind_line()
	var tint := TEXT_COLOR
	if not _hover.is_empty():
		var parts := _hover_info()
		title = parts[0]
		body = parts[1]
		tint = parts[2]
		if move_for(_hover) != "":
			body += "  " + _blind_line()
	_info_title.text = title
	_info_title.modulate = tint
	_info_body.text = body
	_info_body.add_theme_font_size_override("font_size",
		_fit(body, _info_body.size.x, _info_body.size.y, INFO_BODY_UNITS, 1.15))

func _blind_line() -> String:
	return BLIND_LINE % [int(state.get("next_blind", 0)), int(state.get("step_percent", 0))]

func _hover_info() -> Array:
	var id := String(_hover["id"])
	if _hover["kind"] == "room":
		var room: Dictionary = _rooms[id]
		if bool(room.get("entrance", false)):
			return [String(room["name"]), ENTRANCE_BODY, ENTRANCE_COLOR]
		if bool(room.get("office", false)):
			return [String(room["name"]), OFFICE_BODY, CasinoStyle.contract_tier_color(DealClause.Tier.BOSS)]
		var tint := _room_color(room)
		if bool(room["visited"]):
			return [String(room["name"]), VISITED_BODY, tint]
		var bonus := String(room["bonus"])
		var clause := DealClause.find(bonus)
		var name_text := "%s · %s" % [room["name"], clause.display_name] if clause != null else String(room["name"])
		return [name_text, DealClause.text_for(bonus, bonus_factor), tint]
	var door: Dictionary = _doors[id]
	match int(door["state"]):
		FloorMap.DoorState.LOCKED:
			return [LOCKED_TITLE, LOCKED_BODY, LOCKED_COLOR]
		FloorMap.DoorState.PASSED:
			return [PASSED_TITLE, PASSED_BODY, PASSED_COLOR]
	if not bool(door["scouted"]):
		return [UNKNOWN_TITLE, UNKNOWN_BODY, MUTED_COLOR]
	if String(door["clause"]) == "":
		return [FREE_TITLE, FREE_BODY, _door_color(door)]
	var door_clause := DealClause.find(String(door["clause"]))
	var title := door_clause.display_name if door_clause != null else String(door["clause"])
	return [title,DealClause.text_for(String(door["clause"]), bonus_factor), _door_color(door)]

# --- Farben ---------------------------------------------------------------------

func _room_color(room: Dictionary) -> Color:
	if bool(room.get("entrance", false)):
		return ENTRANCE_COLOR
	if bool(room.get("office", false)):
		return CasinoStyle.contract_tier_color(DealClause.Tier.BOSS)
	return CasinoStyle.contract_tier_color(maxi(0, int(room["tier"])))

func _door_color(door: Dictionary) -> Color:
	if bool(door.get("office", false)):
		return CasinoStyle.contract_tier_color(DealClause.Tier.BOSS)
	if bool(door.get("free", false)):
		return CasinoStyle.contract_tier_color(DealClause.Tier.TREAT)
	return CasinoStyle.contract_tier_color(maxi(0, int(door["tier"])))

func _other_side(door: Dictionary, room_id: String) -> String:
	return String(door["b"]) if String(door["a"]) == room_id else String(door["a"])

# --- Aufbau ---------------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var u := _unit()
	var head := Rect2(u * PAD_UNITS, u * PAD_UNITS, size.x - u * PAD_UNITS * 2.0, u * HEAD_UNITS)
	var moves := int(state.get("moves", 0)) + (1 if bool(state.get("due", false)) else 0)
	var floor_no := int(state.get("floor", 1))
	var head_text := ENTRANCE_HEAD % floor_no if moves == 0 else MOVE_HEAD % [floor_no, moves]
	_head_left = _place_label("Head", head_text, head, u * HEAD_FONT_UNITS, TEXT_COLOR,
		HORIZONTAL_ALIGNMENT_LEFT)
	_head_right = _place_label("HeadBlind", BLIND_HEAD % int(state.get("blind", 0)), head,
		u * HEAD_FONT_UNITS, TEXT_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	for room_id: String in _rooms:
		_build_room(room_id, u)
	for door_id: String in _doors:
		_build_mark(door_id, u)
	var foot := _foot_rect().grow_individual(-u * 1.2, -u * 0.5, -u * 1.2, -u * 0.5)
	var title_h := u * INFO_TITLE_UNITS * 1.35
	_info_title = _place_label("InfoTitle", "", Rect2(foot.position, Vector2(foot.size.x, title_h)),
		u * INFO_TITLE_UNITS, TEXT_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	_info_body = _place_label("InfoBody", "", Rect2(foot.position + Vector2(0.0, title_h),
		Vector2(foot.size.x, foot.size.y - title_h)), u * INFO_BODY_UNITS, MUTED_COLOR.lightened(0.35),
		HORIZONTAL_ALIGNMENT_LEFT)
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_write_info()
	queue_redraw()

func _build_room(room_id: String, u: float) -> void:
	var room: Dictionary = _rooms[room_id]
	var rect := room_rect(room_id).grow(-u * 0.5)
	var tint := _room_color(room)
	var standing := room_id == String(state.get("position", ""))
	var dim := bool(room["visited"]) and not standing and not bool(room.get("entrance", false))
	var name_h := u * NAME_UNITS * 1.4
	var name_rect := Rect2(rect.position, Vector2(rect.size.x, name_h))
	if _is_tall(room):
		name_rect.position.y = rect.get_center().y - name_h - u * 0.6
	var name_label := _place_label("Room_" + room_id, String(room["name"]), name_rect,
		_fit(String(room["name"]), rect.size.x, name_h, NAME_UNITS, 1.2), TEXT_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if dim:
		name_label.modulate.a = VISITED_ALPHA + 0.2
	var sub := ""
	if bool(room.get("office", false)):
		sub = OFFICE_SUB
	elif not bool(room.get("entrance", false)) and not standing:
		var clause := DealClause.find(String(room["bonus"]))
		sub = clause.display_name if clause != null else ""
	if sub == "":
		return
	var sub_rect := Rect2(rect.position + Vector2(0.0, name_h), Vector2(rect.size.x, rect.size.y - name_h))
	if _is_tall(room):
		sub_rect = Rect2(Vector2(rect.position.x, rect.get_center().y), Vector2(rect.size.x, name_h * 1.6))
	var sub_label := _place_label("Bonus_" + room_id, sub, sub_rect,
		_fit(sub, sub_rect.size.x, sub_rect.size.y, BONUS_UNITS, 1.1), tint, HORIZONTAL_ALIGNMENT_CENTER)
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if dim:
		sub_label.modulate.a = VISITED_ALPHA

func _build_mark(door_id: String, u: float) -> void:
	var door: Dictionary = _doors[door_id]
	var state_id := int(door["state"])
	if state_id != FloorMap.DoorState.OPEN:
		return  # ausgebrannt: heller Weg; gesperrt: Kreuz - beides gemalt, ohne Text
	var rect := door_mark_rect(door_id)
	var inner := rect.grow(-u * 0.3)
	if not bool(door["scouted"]):
		var unknown := _place_label("Mark_" + door_id, UNKNOWN_TEXT, inner, u * MARK_BIG_UNITS * 1.1,
			UNKNOWN_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
		unknown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return
	var text := FREE_TEXT
	if String(door["clause"]) != "":
		var clause := DealClause.find(String(door["clause"]))
		text = clause.display_name if clause != null else String(door["clause"])
	var label := _place_label("Mark_" + door_id, text, inner,
		_fit(text, inner.size.x, inner.size.y, MARK_BIG_UNITS, MARK_SMALL_UNITS), _door_color(door),
		HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _place_label(node_name: String, text: String, rect: Rect2, font_px: float, color: Color,
		align: int) -> Label:
	var label := CasinoStyle.label(text, font_px, color, align)
	label.name = node_name
	label.clip_text = true
	label.position = rect.position
	label.size = rect.size
	add_child(label)
	return label

## Größte Schrift (in u-Schritten von biggest abwärts bis smallest), in der der Text
## umbrochen in die Fläche paßt.
func _fit(text: String, width: float, height: float, biggest: float, smallest: float) -> float:
	var u := _unit()
	var font := get_theme_font("font", "Label")
	var px := int(u * biggest)
	var floor_px := maxi(8, int(u * smallest))
	if font == null:
		return float(px)
	while px > floor_px:
		var box := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, px)
		var widest := 0.0
		for word in text.split(" ", false):
			widest = maxf(widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
		if box.y * 1.08 <= height and widest <= width:
			return float(px)
		px -= 1
	return float(floor_px)

# --- Malen ----------------------------------------------------------------------

func _start_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash = 0.0
	if _flash_door == "":
		return
	_flash = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, 1.0, 0.0, FLASH_TIME).set_trans(Tween.TRANS_SINE)

func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()

func _draw() -> void:
	if state.is_empty():
		return
	var u := _unit()
	for door_id: String in _doors:
		_draw_door(door_id, u)
	for room_id: String in _rooms:
		_draw_room(room_id, u)
	for door_id: String in _doors:
		_draw_mark(door_id, u)
	var foot := StyleBoxFlat.new()
	foot.bg_color = FOOT_BG
	foot.border_color = Color(MUTED_COLOR.r, MUTED_COLOR.g, MUTED_COLOR.b, 0.35)
	foot.set_border_width_all(maxi(1, int(u * 0.15)))
	foot.set_corner_radius_all(int(u * 1.0))
	draw_style_box(foot, _foot_rect())

func _draw_door(door_id: String, u: float) -> void:
	var seg := door_segment(door_id)
	if seg.size() != 2:
		return
	var door: Dictionary = _doors[door_id]
	var walk := walkable_doors().has(door_id)
	var hovered := _hover_move() == door_id
	var color: Color
	var width := u * 0.45
	match int(door["state"]):
		FloorMap.DoorState.PASSED:
			color = PASSED_COLOR
			width = u * 0.75
		FloorMap.DoorState.LOCKED:
			color = Color(LOCKED_COLOR.r, LOCKED_COLOR.g, LOCKED_COLOR.b, 0.8)
		_:
			if not bool(door["scouted"]):
				color = UNKNOWN_COLOR
			else:
				color = _door_color(door)
				color.a = 1.0 if walk else 0.6
	if walk:
		width = u * (0.8 if hovered else 0.6)
		draw_line(seg[0], seg[1], Color(color.r, color.g, color.b, 0.25), width * 3.0, true)
	draw_line(seg[0], seg[1], color, width, true)
	if int(door["state"]) == FloorMap.DoorState.LOCKED:
		var mid := (seg[0] + seg[1]) * 0.5
		if door_id == _flash_door and _flash > 0.0:
			draw_circle(mid, u * (2.0 + 2.5 * _flash), Color(LOCKED_COLOR.r, LOCKED_COLOR.g,
				LOCKED_COLOR.b, 0.55 * _flash))
		var r := u * 1.1
		draw_line(mid + Vector2(-r, -r), mid + Vector2(r, r), LOCKED_COLOR, u * 0.45, true)
		draw_line(mid + Vector2(-r, r), mid + Vector2(r, -r), LOCKED_COLOR, u * 0.45, true)

func _draw_room(room_id: String, u: float) -> void:
	var room: Dictionary = _rooms[room_id]
	var rect := room_rect(room_id)
	var tint := _room_color(room)
	var standing := room_id == String(state.get("position", ""))
	var walk := _walk_rooms.has(room_id)
	var hovered := walk and _hover_move() == door_to(room_id)
	var dim := bool(room["visited"]) and not standing and not bool(room.get("entrance", false))
	var box := StyleBoxFlat.new()
	var strength := 1.0 if walk else (0.4 if dim else 0.7)
	box.bg_color = TILE_BG.lerp(Color(tint.r, tint.g, tint.b, TILE_BG.a), 0.32 if hovered else (0.12 if walk else 0.06))
	if dim:
		box.bg_color.a = 0.75
	box.border_color = Color(tint.r, tint.g, tint.b, strength)
	box.set_border_width_all(maxi(2, int(u * (0.45 if walk else 0.22))))
	box.set_corner_radius_all(int(u * 1.0))
	if walk:
		box.shadow_color = Color(tint.r, tint.g, tint.b, 0.5 if hovered else 0.3)
		box.shadow_size = int(u * (1.4 if hovered else 0.9))
	draw_style_box(box, rect)
	if standing:
		_draw_puck(_puck_center(room_id, u), u * PUCK_UNITS)

func _puck_center(room_id: String, u: float) -> Vector2:
	var rect := room_rect(room_id).grow(-u * 0.5)
	if _is_tall(_rooms[room_id]):
		return Vector2(rect.get_center().x, rect.get_center().y + u * NAME_UNITS * 1.6)
	var name_h := u * NAME_UNITS * 1.4
	return Vector2(rect.get_center().x, rect.position.y + name_h + (rect.size.y - name_h) * 0.5)

## Der Puck: eine Messing-Scheibe mit Rand und Glanz.
func _draw_puck(center: Vector2, radius: float) -> void:
	draw_circle(center + Vector2(radius * 0.12, radius * 0.18), radius, Color(0, 0, 0, 0.45))
	draw_circle(center, radius, BRASS_DARK)
	draw_circle(center, radius * 0.86, BRASS)
	draw_arc(center, radius * 0.62, 0.0, TAU, 32, BRASS_DARK, maxf(1.0, radius * 0.1), true)
	draw_arc(center, radius * 0.86, PI * 1.05, PI * 1.6, 12, BRASS_LIGHT, maxf(1.0, radius * 0.12), true)

func _draw_mark(door_id: String, u: float) -> void:
	var door: Dictionary = _doors[door_id]
	if int(door["state"]) != FloorMap.DoorState.OPEN:
		return
	var rect := door_mark_rect(door_id)
	var color := UNKNOWN_COLOR if not bool(door["scouted"]) else _door_color(door)
	var walk := walkable_doors().has(door_id)
	var box := StyleBoxFlat.new()
	box.bg_color = TILE_BG
	box.border_color = Color(color.r, color.g, color.b, 1.0 if walk else 0.7)
	box.set_border_width_all(maxi(1, int(u * (0.3 if walk else 0.18))))
	box.set_corner_radius_all(int(u * 0.6))
	if _hover_move() == door_id and walk:
		box.bg_color = TILE_BG.lerp(Color(color.r, color.g, color.b, TILE_BG.a), 0.2)
	draw_style_box(box, rect)

## Der Zug, den der Zeiger gerade anbietet ("" = keiner).
func _hover_move() -> String:
	return move_for(_hover)
