class_name FloorMapView
extends Control
## Die ETAGEN-KARTE als TURM: die Etagen stapeln sich von unten nach oben, je Reihe bis zu
## drei Räume, über dem Büro einer Etage beginnt die nächste. Zwei Fassungen derselben
## Klasse: der STREIFEN der Hub-Startseite (compact: Kacheln ohne Text, der Ausschnitt
## folgt dem Puck) und die GROSSE Karte (Namen, Tür-Marken, Auskunft am Fuß). Regeln und
## Auskunft stehen nur hier. Kennt GameRun nicht: sie malt GameRun.floor_view_state.

## Der gewählte Zug (Tür-Id).
signal door_chosen(door_id: String)
## Klick auf den Streifen ohne Zug: die große Karte soll aufschlagen.
signal open_requested
## Ziel unter dem Zeiger gewechselt - der Hub schreibt die Auskunft neben den Streifen.
signal hover_changed

const ENTRANCE_HEAD := "Etage %d · Eingang"
const MOVE_HEAD := "Etage %d · Zug %d"
const OFFICE_HEAD := "Etage %d · Büro · Boss-Runde"
const BLIND_HEAD := "Blind %s"
const NEXT_BLIND_HEAD := "Nächster Blind %s"
const FREE_TEXT := "frei"
const UNKNOWN_TEXT := "?"
const BLIND_LINE := "Blind nach diesem Zug: %s (%s)"
const CUSHION_PART := " · Polster %s"
## Polster unter ×1: typisch nicht zu schaffen.
const SHORT_COLOR := Color("#ff5555")
const IDLE_TITLE := "Wähle den nächsten Raum"
const IDLE_BODY := "Der Zug unterschreibt den Malus der Tür und den Bonus des Raums."
const STAND_TITLE := "Der Puck steht: %s"
const STAND_BODY := "Zeig auf einen Raum oder eine Tür - hier steht ihre Klausel. Der nächste Zug folgt nach dem Laden."
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
const DONE_TITLE := "Etage %d · geschafft"
const OFFICE_SUB := "Boss-Runde"
const ENTRANCE_BAND := "Eingang"
const OFFICE_BAND := "Büro"
const DONE_BAND := "Etage %d geschafft"
const NEXT_BAND := "Etage %d"

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
## Geschaffte Etagen stehen gedimmt unter dem Puck.
const HISTORY_ALPHA := 0.42

## Querschnitt: drei Querplätze, dazwischen die Fuge (Anteil einer Kachelbreite).
const LANE_GAP := 0.55
const COMPACT_LANE_GAP := 0.38
## Höhen in Kachelhöhen: Band (Eingang/Büro), Reihenfuge, das verborgene Band darüber.
const BAND_SHARE := 0.42
const ROW_GAP_SHARE := 0.6
const HIDDEN_SHARE := 0.55
## Kachelhöhe aus der Kachelbreite (höchstens).
const TILE_ASPECT := 0.62
## Die große Karte zeigt die laufende Etage ganz: Band + 3 Reihen + Büro + Fugen + Rest.
const BIG_FLOOR_TILES := 6.74
## Der Puck steht im Streifen im unteren Drittel - man schaut nach oben.
const PUCK_SHARE := 0.33
const SNAP_TIME := 0.3
## So lange darf der Streifen frei gerollt stehen, wenn der Zeiger ihn verlassen hat.
const SNAP_BACK_DELAY := 1.2
## Maße der großen Karte in u (u = Breite/UNIT_WIDTH; die Kachelhöhe paßt sich an).
const UNIT_WIDTH := 100.0
## Der Streifen rechnet in der Einheit des Hubs; ohne Meldung Breite / COMPACT_UNIT_DIV.
const COMPACT_UNIT_DIV := 30.0
const PAD_UNITS := 0.6
const HEAD_UNITS := 3.6
const FOOT_UNITS := 9.0
const BAND_GAP_UNITS := 0.8
## Fußzeile des Streifens („Etage n · Zug m“).
const STRIP_FOOT_UNITS := 3.2
const STRIP_FOOT_FONT_UNITS := 2.2
const BAND_FONT_UNITS := 1.7
## Schriftleiter der großen Karte (Ober- und Untergrenze in u).
const NAME_UNITS := Vector2(2.9, 2.2)
const BONUS_UNITS := Vector2(2.3, 1.8)
const MARK_UNITS := Vector2(2.1, 1.8)
const HEAD_FONT_UNITS := 2.8
const INFO_TITLE_UNITS := 2.4
const INFO_BODY_UNITS := 2.1
const PUCK_UNITS := 1.7
const LINE_BOX := 1.12
const FLASH_TIME := 1.1
## Fugen langer Wörter: hier darf umbrochen werden, sonst nie mitten im Wort.
const WORD_JOINTS := ["Standard|protokoll", "Zwangs|versteigerung", "Versicherungs|betrug",
	"Rück|versicherung", "Kalt|verfestigung", "Glücks|würfel", "Werkstatt|sperre",
	"Voll|bestückung", "Sonder|lieferung", "Meister|prägung", "Lohn|fortzahlung",
	"Glücks|strähne", "Sicherungs|fall", "Service|gebühr", "Rückkauf|recht", "Glücks|pfennig",
	"Wucher|klausel", "Wackel|kontakt", "Unglücks|zahl", "Hinter|zimmer", "Erwar|tungen",
	"Aus|zahlung", "Hand|schlag", "Wandel|halle", "Spiegel|saal", "Treppen|haus",
	"Rauch|salon", "Garde|robe", "Blanko|scheck", "Supra|leiter", "Glücks|kind"]

## Der Zustand aus GameRun.floor_view_state (leer = geschlossen).
var state: Dictionary = {}
## Bonus-Faktor des Winkeladvokats für die Klausel-Texte.
var bonus_factor := 1
## Nur ansehen (die Karte im Laden): kein Zug, wie auch immer der Zustand steht.
var read_only := false
## Darf der fällige Zug JETZT gewählt werden (scene_root: die Runde wartet auf ihn)?
var moves_enabled := true
## Der STREIFEN der Startseite: ohne Text, der Ausschnitt folgt dem Puck.
var compact := false
## Einheit des Streifens in Display-px (der Hub meldet seine; 0 = selbst rechnen).
var unit_px := 0.0
## Ausschnitt: Inhalts-Höhe (von unten) an der Unterkante der Kartenfläche.
var scroll := 0.0

var _floors: Array[Dictionary] = []  # je Etage {floor, rooms{id}, doors{id}, current, entrance, office, position}
var _walk_rooms: Dictionary = {}  # Zielraum -> Tür-Id der gangbaren Züge
var _hover: Dictionary = {}  # {kind, id, floor} unter dem Zeiger
var _flash_door := ""
var _flash := 0.0
var _flash_tween: Tween
var _scroll_tween: Tween
var _puck_key := ""
var _free_scroll := false
var _pointer_in := false
var _away := 0.0
var _built_scroll := INF
var _info_title: Label
var _info_body: Label
var _info_move: Label
var _info_row := Rect2()
## Die Kartenfläche als eigene, beschnittene Ebene: Turm und Namen enden an ihrem Rand.
var _layer: Control
var _canvas: CanvasItem = self

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(false)
	_layer = Control.new()
	_layer.name = "Map"
	_layer.clip_contents = true
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.draw.connect(_draw_map)
	add_child(_layer)

func _redraw() -> void:
	queue_redraw()
	_layer.queue_redraw()

## Baut die Karte aus dem Zustand und zeigt sie; flash_door blitzt einmal rot.
## Ein unveränderter Zustand baut nichts neu - der Hub fragt oft.
func open(view_state: Dictionary, deal_bonus_factor: int = 1, flash_door: String = "") -> void:
	if visible and flash_door == "" and deal_bonus_factor == bonus_factor and view_state == state:
		return
	var kept := _hover
	var first := state.is_empty() or not visible
	state = view_state.duplicate(true)
	bonus_factor = deal_bonus_factor
	_read_floors()
	_hover = {}
	if not kept.is_empty() and not _entry(kept).is_empty():
		_hover = kept
	visible = true
	var key := "%d:%s" % [current_floor(), String(state.get("position", ""))]
	if key != _puck_key or first:
		_puck_key = key
		snap_to_puck(first or not compact)
	_rebuild()
	if flash_door != "":
		_flash_door = flash_door if (_floors.back()["doors"] as Dictionary).has(flash_door) else ""
		_start_flash()

func close() -> void:
	visible = false
	_hover = {}
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash = 0.0

func _read_floors() -> void:
	_floors.clear()
	_walk_rooms.clear()
	for past: Dictionary in state.get("history", []):
		_floors.append(_floor_of(past, false))
	if state.has("rooms"):
		_floors.append(_floor_of(state, true))
	if _floors.is_empty():
		return
	var here := String(state.get("position", ""))
	var doors: Dictionary = _floors.back()["doors"]
	for door_id: String in state.get("walkable", []):
		if doors.has(door_id):
			_walk_rooms[_other_side(doors[door_id], here)] = door_id

func _floor_of(data: Dictionary, current: bool) -> Dictionary:
	var rooms := {}
	var doors := {}
	for room: Dictionary in data.get("rooms", []):
		rooms[String(room["id"])] = room
	for door: Dictionary in data.get("doors", []):
		doors[String(door["id"])] = door
	return {"floor": int(data.get("floor", 1)), "rooms": rooms, "doors": doors, "current": current,
		"entrance": String(data.get("entrance", "")), "office": String(data.get("office", "")),
		"position": String(data.get("position", ""))}

## Die laufende Etage (1-basiert).
func current_floor() -> int:
	return int(state.get("floor", 1))

## Die gangbaren Türen, die JETZT einen Klick nehmen (leer = nur ansehen).
func walkable_doors() -> Array[String]:
	var ids: Array[String] = []
	if read_only or not moves_enabled:
		return ids
	ids.assign(state.get("walkable", []))
	return ids

## Ob der fällige Zug gerade gewählt werden darf; nur der Wechsel malt neu.
func set_moves_enabled(on: bool) -> void:
	if on == moves_enabled:
		return
	moves_enabled = on
	_refresh_pointer()

## Die Auskunft unter dem Zeiger fällt weg (der Zeiger hat die Karte verlassen).
func clear_hover() -> void:
	hover_at(Vector2(-1, -1))

func hovered() -> Dictionary:
	return _hover

## Ob der Zeiger gerade über der Karte steht (auch über leerer Fläche).
func pointer_inside() -> bool:
	return _pointer_in

## Die Tür, deren Zug der Klick auf den Raum der laufenden Etage wäre ("" = keiner).
func door_to(room_id: String) -> String:
	if walkable_doors().is_empty():
		return ""
	return String(_walk_rooms.get(room_id, ""))

func flashing_door() -> String:
	return _flash_door if _flash > 0.0 else ""

# --- Geometrie ------------------------------------------------------------------

func unit() -> float:
	if compact:
		return unit_px if unit_px > 0.0 else maxf(size.x / COMPACT_UNIT_DIV, 1.0)
	return maxf(size.x / UNIT_WIDTH, 1.0)

## Die Fläche, in der der Turm steht (ohne Kopf, Fuß und Fußzeile).
func map_rect() -> Rect2:
	var u := unit()
	if compact:
		return Rect2(0.0, 0.0, size.x, maxf(size.y - u * STRIP_FOOT_UNITS, 1.0))
	var top := u * (PAD_UNITS + HEAD_UNITS + BAND_GAP_UNITS)
	var bottom := size.y - u * (PAD_UNITS + FOOT_UNITS + BAND_GAP_UNITS)
	return Rect2(u * PAD_UNITS, top, size.x - u * PAD_UNITS * 2.0, maxf(bottom - top, 1.0))

## Die Fußzeile des Streifens („Etage n · Zug m“) bzw. die Auskunft der großen Karte.
func foot_rect() -> Rect2:
	var u := unit()
	if compact:
		return Rect2(0.0, size.y - u * STRIP_FOOT_UNITS, size.x, u * STRIP_FOOT_UNITS)
	return Rect2(u * PAD_UNITS, size.y - u * (PAD_UNITS + FOOT_UNITS),
		size.x - u * PAD_UNITS * 2.0, u * FOOT_UNITS)

## {tile_w, lane_gap, tile_h, band_h, gap, hidden_h, block}
func metrics() -> Dictionary:
	var area := map_rect()
	var lane_gap_share := COMPACT_LANE_GAP if compact else LANE_GAP
	var tile_w := area.size.x / (float(FloorMap.LANES) + lane_gap_share * float(FloorMap.LANES - 1))
	var tile_h := tile_w * TILE_ASPECT
	if not compact:
		tile_h = minf(tile_h, area.size.y / BIG_FLOOR_TILES)
	var band_h := tile_h * BAND_SHARE
	var gap := tile_h * ROW_GAP_SHARE
	return {"tile_w": tile_w, "lane_gap": tile_w * lane_gap_share, "tile_h": tile_h,
		"band_h": band_h, "gap": gap, "hidden_h": tile_h * HIDDEN_SHARE,
		"block": band_h + tile_h * float(FloorMap.ROWS - 2) + gap * float(FloorMap.ROWS - 1)}

## Turm-Reihe (von unten, über alle Etagen) - je Etage vier: Band, drei Raumreihen.
func global_row(floor_no: int, local_row: int) -> int:
	return (floor_no - 1) * (FloorMap.ROWS - 1) + local_row

## Unterkante einer Turm-Reihe in Inhalts-px (von unten).
func row_bottom(row: int) -> float:
	var m := metrics()
	var per := FloorMap.ROWS - 1
	var base := floorf(float(row) / float(per)) * float(m["block"])
	var k := posmod(row, per)
	if k == 0:
		return base
	return base + float(m["band_h"]) + float(m["gap"]) + float(k - 1) * (float(m["tile_h"]) + float(m["gap"]))

func row_height(row: int) -> float:
	var m := metrics()
	return float(m["band_h"]) if posmod(row, FloorMap.ROWS - 1) == 0 else float(m["tile_h"])

## Inhalts-Höhe (von unten) -> lokale y.
func _local_y(content_y: float) -> float:
	return map_rect().end.y - (content_y - scroll)

func _row_rect(row: int, lane: int) -> Rect2:
	var m := metrics()
	var area := map_rect()
	var y := _local_y(row_bottom(row) + row_height(row))
	if lane < 0:
		return Rect2(area.position.x, y, area.size.x, row_height(row))
	var x := area.position.x + float(lane) * (float(m["tile_w"]) + float(m["lane_gap"]))
	return Rect2(x, y, float(m["tile_w"]), row_height(row))

## Reihe eines Raums im Turm; Eingang und Büro sind Bänder über die Breite.
func _room_row(floor_no: int, room: Dictionary) -> int:
	if bool(room.get("entrance", false)):
		return global_row(floor_no, 0)
	if bool(room.get("office", false)):
		return global_row(floor_no, FloorMap.ROWS - 1)
	return global_row(floor_no, int(room.get("row", (room["cell"] as Vector2i).x)))

func _is_band(room: Dictionary) -> bool:
	return bool(room.get("entrance", false)) or bool(room.get("office", false))

## Kachel bzw. Band eines Raums (floor 0 = laufende Etage). Der Eingang einer höheren
## Etage ist das Büro-Band der Etage darunter.
func room_rect(room_id: String, floor_no: int = 0) -> Rect2:
	var data := _floor_data(floor_no)
	if data.is_empty() or not (data["rooms"] as Dictionary).has(room_id):
		return Rect2()
	var room: Dictionary = data["rooms"][room_id]
	var row := _room_row(int(data["floor"]), room)
	if _is_band(room):
		return _row_rect(row, -1)
	return _row_rect(row, int(room.get("lane", (room["cell"] as Vector2i).y)))

func _floor_data(floor_no: int) -> Dictionary:
	if _floors.is_empty():
		return {}
	if floor_no <= 0:
		return _floors.back()
	for data in _floors:
		if int(data["floor"]) == floor_no:
			return data
	return {}

## Der Steg einer Tür als [Anfang, Ende] zwischen den Kanten ihrer Räume.
func door_segment(door_id: String, floor_no: int = 0) -> PackedVector2Array:
	var data := _floor_data(floor_no)
	if data.is_empty() or not (data["doors"] as Dictionary).has(door_id):
		return PackedVector2Array()
	var door: Dictionary = data["doors"][door_id]
	var f := int(data["floor"])
	var a: Dictionary = data["rooms"][String(door["a"])]
	var b: Dictionary = data["rooms"][String(door["b"])]
	var ra := room_rect(String(door["a"]), f)
	var rb := room_rect(String(door["b"]), f)
	var row_a := _room_row(f, a)
	var row_b := _room_row(f, b)
	if row_a != row_b:
		var lower := ra if row_a < row_b else rb
		var upper := rb if row_a < row_b else ra
		var tile := rb if _is_band(a) else ra
		var x := tile.get_center().x
		return PackedVector2Array([Vector2(x, lower.position.y), Vector2(x, upper.end.y)])
	var left := ra if ra.position.x < rb.position.x else rb
	var right := rb if ra.position.x < rb.position.x else ra
	var y := left.get_center().y
	return PackedVector2Array([Vector2(left.end.x, y), Vector2(right.position.x, y)])

func _door_vertical(seg: PackedVector2Array) -> bool:
	return seg.size() == 2 and is_equal_approx(seg[0].x, seg[1].x)

## Die Marke einer Tür: mittig auf dem Steg, nie auf einer Kachel.
func door_mark_rect(door_id: String, floor_no: int = 0) -> Rect2:
	var seg := door_segment(door_id, floor_no)
	if seg.size() != 2:
		return Rect2()
	var u := unit()
	var m := metrics()
	var mid := (seg[0] + seg[1]) * 0.5
	var gap := seg[0].distance_to(seg[1])
	var door: Dictionary = _floor_data(floor_no)["doors"][door_id]
	var plain := not bool(door.get("scouted", false)) or int(door["state"]) != FloorMap.DoorState.OPEN
	if compact or plain:
		var side := minf(gap * 0.82, minf(float(m["gap"]), float(m["lane_gap"])) * 0.82)
		if not compact:
			side = minf(gap - u * 0.4, u * 2.8)
		side = maxf(side, 4.0)
		return Rect2(mid - Vector2(side, side) * 0.5, Vector2(side, side))
	var size_px: Vector2
	if _door_vertical(seg):
		size_px = Vector2(float(m["tile_w"]), gap - u * 0.5)
	else:
		size_px = Vector2(gap - u * 0.5, float(m["tile_h"]) * 0.86)
	return Rect2(mid - size_px * 0.5, size_px)

## Oberkante des Inhalts: das verborgene Band über dem Büro der laufenden Etage.
func content_top() -> float:
	var row := global_row(current_floor() + 1, 1)
	return row_bottom(row) + float(metrics()["hidden_h"])

func _hidden_rect() -> Rect2:
	var row := global_row(current_floor() + 1, 1)
	var area := map_rect()
	var h := float(metrics()["hidden_h"])
	return Rect2(area.position.x, _local_y(row_bottom(row) + h), area.size.x, h)

func _scroll_range() -> Vector2:
	var u := unit()
	var low := -u * PAD_UNITS
	var high := maxf(low, content_top() + u * PAD_UNITS - map_rect().size.y)
	return Vector2(low, high)

## Wo der Ausschnitt für den Puck steht: im Streifen im unteren Drittel, groß die ganze Etage.
func puck_scroll() -> float:
	var target: float
	if compact:
		var here := _puck_rect()
		var center_content := map_rect().end.y - here.get_center().y + scroll
		target = center_content - map_rect().size.y * PUCK_SHARE
	else:
		target = row_bottom(global_row(current_floor(), 0)) - unit() * PAD_UNITS
	var span := _scroll_range()
	return clampf(target, span.x, span.y)

func _puck_rect() -> Rect2:
	return room_rect(String(state.get("position", "")))

## Rastet auf den Puck zurück (hard = ohne Fahrt).
func snap_to_puck(hard: bool = true) -> void:
	_free_scroll = false
	_away = 0.0
	set_process(false)
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	if _floors.is_empty():
		return
	var target := puck_scroll()
	if hard or not is_inside_tree():
		_set_scroll(target)
		return
	_scroll_tween = create_tween()
	_scroll_tween.tween_method(_set_scroll, scroll, target, SNAP_TIME).set_trans(Tween.TRANS_SINE)

## Rollt den Ausschnitt um steps Reihen (positiv = nach oben).
func scroll_by(steps: float) -> void:
	if _floors.is_empty():
		return
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	var m := metrics()
	var span := _scroll_range()
	_set_scroll(clampf(scroll + steps * (float(m["tile_h"]) + float(m["gap"])), span.x, span.y))
	_free_scroll = true
	_away = 0.0
	set_process(compact)

func scrolled_free() -> bool:
	return _free_scroll

func _set_scroll(value: float) -> void:
	scroll = value
	if not compact and not is_equal_approx(_built_scroll, scroll):
		_rebuild()
	_redraw()

func _process(delta: float) -> void:
	if not _free_scroll or _pointer_in:
		_away = 0.0
		return
	_away += delta
	if _away >= SNAP_BACK_DELAY:
		snap_to_puck(false)

## Etagen, deren Reihen im Ausschnitt liegen - nur sie werden gezeichnet und gebaut.
func visible_floors() -> Array[int]:
	var found: Array[int] = []
	var low := scroll
	var high := scroll + map_rect().size.y
	for data in _floors:
		var f := int(data["floor"])
		var y0 := row_bottom(global_row(f, 0))
		var y1 := row_bottom(global_row(f, FloorMap.ROWS - 1)) + float(metrics()["band_h"])
		if y1 >= low and y0 <= high:
			found.append(f)
	return found

## "Etage/Raum" je Raum, dessen Kachel im Ausschnitt liegt.
func visible_room_keys() -> Array[String]:
	var keys: Array[String] = []
	var area := map_rect()
	for f in visible_floors():
		var data := _floor_data(f)
		for room_id: String in data["rooms"]:
			if _hidden_entrance(data, room_id):
				continue
			if room_rect(room_id, f).intersects(area):
				keys.append("%d/%s" % [f, room_id])
	return keys

## Der Eingang einer höheren Etage wird nicht gezeichnet: das Büro darunter steht dort.
func _hidden_entrance(data: Dictionary, room_id: String) -> bool:
	return int(data["floor"]) > 1 and room_id == String(data["entrance"])

## Was unter dem Punkt liegt: {kind: "room"|"door", id, floor} (leer = nichts).
func target_at(local: Vector2) -> Dictionary:
	if not map_rect().has_point(local):
		return {}
	var floors := visible_floors()
	floors.reverse()  # die laufende Etage zuerst: ihr Eingang IST das Büro darunter
	for f in floors:
		var data := _floor_data(f)
		for door_id: String in data["doors"]:
			if door_mark_rect(door_id, f).grow(unit() * 0.3).has_point(local):
				return {"kind": "door", "id": door_id, "floor": f}
		for room_id: String in data["rooms"]:
			if _hidden_entrance(data, room_id) and not bool(data["current"]):
				continue
			if room_rect(room_id, f).has_point(local):
				return {"kind": "room", "id": room_id, "floor": f}
		for door_id: String in data["doors"]:
			var seg := door_segment(door_id, f)
			if seg.size() == 2 and Rect2(seg[0], Vector2.ZERO).expand(seg[1]).grow(unit() * 0.8).has_point(local):
				return {"kind": "door", "id": door_id, "floor": f}
	return {}

func _entry(target: Dictionary) -> Dictionary:
	var data := _floor_data(int(target.get("floor", 0)))
	if data.is_empty():
		return {}
	var pool: Dictionary = data["rooms"] if target["kind"] == "room" else data["doors"]
	return pool.get(String(target["id"]), {})

func _on_current(target: Dictionary) -> bool:
	return not target.is_empty() and int(target.get("floor", current_floor())) == current_floor()

## Der Zug hinter dem Ziel ("" = es nimmt keinen Klick).
func move_for(target: Dictionary) -> String:
	if not _on_current(target):
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
			if press_at(button.position):
				accept_event()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_EXIT, NOTIFICATION_VISIBILITY_CHANGED:
			clear_hover()
		NOTIFICATION_RESIZED:
			if not state.is_empty():
				snap_to_puck(true)
				_rebuild()

func hover_at(local: Vector2) -> void:
	_pointer_in = local.x >= 0.0 and Rect2(Vector2.ZERO, size).has_point(local)
	var target := target_at(local) if _pointer_in and not state.is_empty() else {}
	if target == _hover:
		return
	_hover = target
	_refresh_pointer()

func _refresh_pointer() -> void:
	_write_info()
	var shape := Control.CURSOR_POINTING_HAND if move_for(_hover) != "" or compact else Control.CURSOR_ARROW
	mouse_default_cursor_shape = shape
	_redraw()
	hover_changed.emit()

## Klick an der Stelle: ein gangbarer Nachbar meldet seinen Zug; im Streifen rastet die
## Fußzeile auf den Puck zurück, und jeder andere Klick schlägt die große Karte auf.
func press_at(local: Vector2) -> bool:
	if state.is_empty():
		return false
	if compact and foot_rect().has_point(local):
		snap_to_puck(false)
		return true
	var door_id := move_for(target_at(local))
	if door_id != "":
		door_chosen.emit(door_id)
		return true
	if compact and map_rect().has_point(local):
		open_requested.emit()
		return true
	return false

# --- Auskunft (die EINE Quelle für Karte und Hub) ---------------------------------

## {title, body, color, move, move_color}: das Ziel unter dem Zeiger, sonst die Ruhe.
func info_parts() -> Dictionary:
	var parts := {"title": IDLE_TITLE, "body": IDLE_BODY, "color": TEXT_COLOR, "move": "",
		"move_color": TEXT_COLOR}
	if state.is_empty():
		return parts
	var move := _blind_line(float(state.get("next_blind", 0)), int(state.get("step_percent", 0)),
		float(state.get("cushion_next", 0.0)))
	if walkable_doors().is_empty():
		var here: Dictionary = (_floors.back()["rooms"] as Dictionary).get(String(state.get("position", "")), {})
		parts["title"] = STAND_TITLE % String(here.get("name", ""))
		parts["body"] = STAND_BODY
		move = []
	if not _hover.is_empty():
		var hover := _hover_info()
		parts["title"] = hover[0]
		parts["body"] = hover[1]
		parts["color"] = hover[2]
		move = []
		var door_id := move_for(_hover)
		if door_id != "":
			var door: Dictionary = (_floors.back()["doors"] as Dictionary).get(door_id, {})
			move = _blind_line(float(door.get("blind_after", state.get("next_blind", 0))),
				int(door.get("after_percent", state.get("step_percent", 0))),
				float(door.get("cushion_after", 0.0)))
	if not move.is_empty():
		parts["move"] = move[0]
		parts["move_color"] = move[1]
	return parts

func info_text() -> String:
	var parts := info_parts()
	var text := String(parts["title"]) + "\n" + String(parts["body"])
	if String(parts["move"]) != "":
		text += "\n" + String(parts["move"])
	return text

## [Text, Farbe] der Zug-Zeile: Blind samt Schritt, mit typischem Wert dazu das Polster.
static func _blind_line(blind: float, percent: int, cushion: float) -> Array:
	var prefix := "+" if percent >= 0 else "−"
	var text := BLIND_LINE % [BigNumber.short(blind), "%s%d %%" % [prefix, absi(percent)]]
	if cushion <= 0.0:
		return [text, TEXT_COLOR]
	return [text + CUSHION_PART % BigNumber.factor(cushion), SHORT_COLOR if cushion < 1.0 else TEXT_COLOR]

func _hover_info() -> Array:
	var entry := _entry(_hover)
	if entry.is_empty():
		return [IDLE_TITLE, IDLE_BODY, TEXT_COLOR]
	var done := not _on_current(_hover)
	if _hover["kind"] == "room":
		if bool(entry.get("entrance", false)):
			return [String(entry["name"]), ENTRANCE_BODY, ENTRANCE_COLOR]
		if bool(entry.get("office", false)):
			if done:
				return [DONE_TITLE % int(_hover["floor"]), OFFICE_BODY, MUTED_COLOR]
			return [String(entry["name"]), OFFICE_BODY, CasinoStyle.contract_tier_color(DealClause.Tier.BOSS)]
		var tint := _room_color(entry)
		if bool(entry["visited"]):
			return [String(entry["name"]), VISITED_BODY, tint]
		var bonus := String(entry["bonus"])
		var clause := DealClause.find(bonus)
		var name_text := "%s · %s" % [entry["name"], clause.display_name] if clause != null else String(entry["name"])
		return [name_text, DealClause.text_for(bonus, bonus_factor), tint]
	match int(entry["state"]):
		FloorMap.DoorState.LOCKED:
			return [LOCKED_TITLE, LOCKED_BODY, LOCKED_COLOR]
		FloorMap.DoorState.PASSED:
			return [PASSED_TITLE, PASSED_BODY, PASSED_COLOR]
	if not bool(entry["scouted"]):
		return [UNKNOWN_TITLE, UNKNOWN_BODY, MUTED_COLOR]
	if String(entry["clause"]) == "":
		return [FREE_TITLE, FREE_BODY, _door_color(entry)]
	var door_clause := DealClause.find(String(entry["clause"]))
	var title := door_clause.display_name if door_clause != null else String(entry["clause"])
	return [title, DealClause.text_for(String(entry["clause"]), bonus_factor), _door_color(entry)]

## Die Kopfzeile links: Etage und Zug (am Eingang „Eingang“, im Büro die Boss-Runde).
static func head_text(view_state: Dictionary) -> String:
	var floor_no := int(view_state.get("floor", 1))
	if is_boss(view_state):
		return OFFICE_HEAD % floor_no
	var moves := int(view_state.get("moves", 0)) + (1 if bool(view_state.get("due", false)) else 0)
	return ENTRANCE_HEAD % floor_no if moves == 0 else MOVE_HEAD % [floor_no, moves]

## Die Kopfzeile rechts: der laufende Blind, vor dem Zug der Blind NACH ihm.
static func blind_text(view_state: Dictionary) -> String:
	if bool(view_state.get("due", false)):
		return NEXT_BLIND_HEAD % BigNumber.short(int(view_state.get("next_blind", 0)))
	return BLIND_HEAD % BigNumber.short(int(view_state.get("blind", 0)))

## Der Puck steht im Büro und kein Zug ist fällig: die laufende Runde ist die Boss-Runde.
static func is_boss(view_state: Dictionary) -> bool:
	return not bool(view_state.get("due", false)) and view_state.has("office") \
		and String(view_state.get("position", "")) == String(view_state["office"])

# --- Farben ---------------------------------------------------------------------

static func _room_color(room: Dictionary) -> Color:
	if bool(room.get("entrance", false)):
		return ENTRANCE_COLOR
	if bool(room.get("office", false)):
		return CasinoStyle.contract_tier_color(DealClause.Tier.BOSS)
	return CasinoStyle.contract_tier_color(maxi(0, int(room["tier"])))

static func _door_color(door: Dictionary) -> Color:
	if bool(door.get("office", false)):
		return CasinoStyle.contract_tier_color(DealClause.Tier.BOSS)
	if bool(door.get("free", false)):
		return CasinoStyle.contract_tier_color(DealClause.Tier.TREAT)
	return CasinoStyle.contract_tier_color(maxi(0, int(door["tier"])))

static func _other_side(door: Dictionary, room_id: String) -> String:
	return String(door["b"]) if String(door["a"]) == room_id else String(door["a"])

# --- Namen umbrechen: an Wortfugen, nie mitten im Wort -----------------------------

## Die Teile eines Wortes: an einem Bindestrich und an einer bekannten Wortfuge.
static func word_parts(word: String) -> PackedStringArray:
	for joint: String in WORD_JOINTS:
		if joint.replace("|", "") == word:
			var halves := joint.split("|")
			return PackedStringArray([halves[0] + "-", halves[1]])
	var dash := word.find("-")
	if dash > 0 and dash < word.length() - 1:
		return PackedStringArray([word.substr(0, dash + 1), word.substr(dash + 1)])
	return PackedStringArray([word])

## Zeilen in Schriftgrad px, die in width passen (leer = ein Teil ist zu breit).
static func wrap_name(text: String, font: Font, px: int, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var joined := word if line == "" else line + " " + word
		if font.get_string_size(joined, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width:
			line = joined
			continue
		var parts := word_parts(word)
		if line != "" and parts.size() > 1:
			var head := line + " " + parts[0]
			if font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width:
				lines.append(head)
				line = parts[1]
				if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
					return PackedStringArray()
				continue
		if line != "":
			lines.append(line)
			line = ""
		if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width:
			line = word
			continue
		for part in parts:
			if font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
				return PackedStringArray()
		for i in parts.size() - 1:
			lines.append(parts[i])
		line = parts[parts.size() - 1]
	if line != "":
		lines.append(line)
	return lines

## Größter Grad von biggest bis smallest, in dem der Name umbrochen in die Fläche paßt:
## {lines, px}. Paßt er nicht einmal klein, steht er klein in ganzen Wörtern.
static func fit_name(text: String, font: Font, width: float, height: float, biggest: int,
		smallest: int) -> Dictionary:
	for px in range(biggest, smallest - 1, -1):
		var lines := wrap_name(text, font, px, width)
		if not lines.is_empty() and font.get_height(px) * LINE_BOX * float(lines.size()) <= height:
			return {"lines": lines, "px": px}
	var fallback := wrap_name(text, font, smallest, width)
	if fallback.is_empty():
		fallback = text.split(" ", false)
	return {"lines": fallback, "px": smallest}

func _font() -> Font:
	var font := get_theme_font("font", "Label")
	return font if font != null else ThemeDB.fallback_font

# --- Aufbau (nur die große Karte baut Schrift) --------------------------------------

func _rebuild() -> void:
	_built_scroll = scroll
	var area := map_rect()
	_layer.position = area.position
	_layer.size = area.size
	if compact:
		_redraw()
		return
	for host: Node in [self, _layer]:
		for child in host.get_children():
			if child == _layer:
				continue
			host.remove_child(child)
			child.queue_free()
	if state.is_empty():
		return
	var u := unit()
	var head := Rect2(u * PAD_UNITS, u * PAD_UNITS, size.x - u * PAD_UNITS * 2.0, u * HEAD_UNITS)
	var head_tint := LOCKED_COLOR if is_boss(state) else TEXT_COLOR
	var left := _place_label("Head", head_text(state), head, u * HEAD_FONT_UNITS, head_tint,
		HORIZONTAL_ALIGNMENT_LEFT)
	left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var right := _place_label("HeadBlind", blind_text(state), head, u * HEAD_FONT_UNITS, head_tint,
		HORIZONTAL_ALIGNMENT_RIGHT)
	right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for f in visible_floors():
		var data := _floor_data(f)
		for room_id: String in data["rooms"]:
			if not _hidden_entrance(data, room_id) and room_rect(room_id, f).intersects(area):
				_build_room(data, room_id, u)
		for door_id: String in data["doors"]:
			if door_mark_rect(door_id, f).intersects(area):
				_build_mark(data, door_id, u)
	var foot := foot_rect().grow_individual(-u * 1.2, -u * 0.6, -u * 1.2, -u * 0.6)
	var title_h := u * INFO_TITLE_UNITS * 1.35
	_info_row = Rect2(foot.position, Vector2(foot.size.x, title_h))
	_info_title = _place_label("InfoTitle", "", _info_row, u * INFO_TITLE_UNITS, TEXT_COLOR,
		HORIZONTAL_ALIGNMENT_LEFT)
	_info_move = _place_label("InfoMove", "", _info_row, u * INFO_BODY_UNITS, TEXT_COLOR,
		HORIZONTAL_ALIGNMENT_RIGHT)
	_info_move.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_body = _place_label("InfoBody", "", Rect2(foot.position + Vector2(0.0, title_h),
		Vector2(foot.size.x, foot.size.y - title_h)), u * INFO_BODY_UNITS, MUTED_COLOR.lightened(0.35),
		HORIZONTAL_ALIGNMENT_LEFT)
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_write_info()
	_redraw()

## Name der Kachel-Knoten: die laufende Etage schlicht, die Geschichte mit Etage davor.
func _node_name(data: Dictionary, kind: String, id: String) -> String:
	return "%s_%s" % [kind, id] if bool(data["current"]) else "H%d_%s_%s" % [int(data["floor"]), kind, id]

func _build_room(data: Dictionary, room_id: String, u: float) -> void:
	var room: Dictionary = data["rooms"][room_id]
	var f := int(data["floor"])
	var rect := room_rect(room_id, f).grow(-u * 0.5)
	var tint := _room_color(room)
	var current := bool(data["current"])
	var standing := current and room_id == String(state.get("position", ""))
	var fade := 1.0 if current else HISTORY_ALPHA
	if _is_band(room):
		var text := _band_text(data, room)
		# Links, damit der Puck in der Mitte des Bandes nichts verdeckt.
		var band := _place_label(_node_name(data, "Room", room_id), text, rect.grow_individual(-u, 0, -u, 0),
			u * NAME_UNITS.y, tint if current else MUTED_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
		band.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		band.modulate.a = fade
		return
	var dim := bool(room["visited"]) and not standing
	var name_fit := fit_name(String(room["name"]), _font(), rect.size.x - u, rect.size.y * 0.42,
		int(u * NAME_UNITS.x), int(u * NAME_UNITS.y))
	var name_h := rect.size.y * 0.42
	var name_rect := Rect2(rect.position + Vector2(0.0, rect.size.y * 0.08), Vector2(rect.size.x, name_h))
	var name_label := _place_label(_node_name(data, "Room", room_id),
		"\n".join(name_fit["lines"]), name_rect, float(name_fit["px"]), TEXT_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.modulate.a = fade * (VISITED_ALPHA + 0.25 if dim else 1.0)
	if standing:
		return  # dort steht der Puck
	var clause := DealClause.find(String(room["bonus"]))
	if clause == null:
		return
	var sub_rect := Rect2(Vector2(rect.position.x, name_rect.end.y),
		Vector2(rect.size.x, rect.end.y - name_rect.end.y - u * 0.3))
	var sub_fit := fit_name(clause.display_name, _font(), sub_rect.size.x - u, sub_rect.size.y,
		int(u * BONUS_UNITS.x), int(u * BONUS_UNITS.y))
	var sub := _place_label(_node_name(data, "Bonus", room_id), "\n".join(sub_fit["lines"]),
		sub_rect, float(sub_fit["px"]), tint, HORIZONTAL_ALIGNMENT_CENTER)
	sub.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	sub.modulate.a = fade * (VISITED_ALPHA if dim else 1.0)

func _band_text(data: Dictionary, room: Dictionary) -> String:
	if bool(room.get("entrance", false)):
		return ENTRANCE_BAND
	if not bool(data["current"]):
		return DONE_BAND % int(data["floor"])
	return "%s · %s" % [OFFICE_BAND, OFFICE_SUB]

func _build_mark(data: Dictionary, door_id: String, u: float) -> void:
	var door: Dictionary = data["doors"][door_id]
	if int(door["state"]) != FloorMap.DoorState.OPEN:
		return  # ausgebrannt: heller Weg; gesperrt: Kreuz - beides gemalt, ohne Text
	var f := int(data["floor"])
	var inner := door_mark_rect(door_id, f).grow(-u * 0.3)
	var fade := 1.0 if bool(data["current"]) else HISTORY_ALPHA
	if not bool(door["scouted"]):
		var unknown := _place_label(_node_name(data, "Mark", door_id), UNKNOWN_TEXT, inner,
			u * MARK_UNITS.x, UNKNOWN_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
		unknown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unknown.modulate.a *= fade
		return
	var text := FREE_TEXT
	if String(door["clause"]) != "":
		var clause := DealClause.find(String(door["clause"]))
		text = clause.display_name if clause != null else String(door["clause"])
	var fit := fit_name(text, _font(), inner.size.x, inner.size.y, int(u * MARK_UNITS.x),
		int(u * MARK_UNITS.y))
	var label := _place_label(_node_name(data, "Mark", door_id), "\n".join(fit["lines"]), inner,
		float(fit["px"]), _door_color(door), HORIZONTAL_ALIGNMENT_CENTER)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate.a *= fade

func _place_label(node_name: String, text: String, rect: Rect2, font_px: float, color: Color,
		align: int) -> Label:
	var label := CasinoStyle.label(text, font_px, color, align)
	label.name = node_name
	label.clip_text = true
	label.size = rect.size
	# Kopf und Auskunft stehen auf der Karte, alles andere in der beschnittenen Kartenfläche.
	if node_name.begins_with("Head") or node_name.begins_with("Info"):
		label.position = rect.position
		add_child(label)
	else:
		label.position = rect.position - _layer.position
		_layer.add_child(label)
	return label

func _write_info() -> void:
	if compact or _info_title == null or not is_instance_valid(_info_title):
		return
	var parts := info_parts()
	_info_title.text = String(parts["title"])
	_info_title.modulate = parts["color"]
	_info_body.text = String(parts["body"])
	_info_move.text = String(parts["move"])
	_info_move.modulate = parts["move_color"]
	_fit_info_row()

## Die Zug-Zeile steht rechts in der Titelzeile, der Titel nimmt den Rest.
func _fit_info_row() -> void:
	var u := unit()
	var width := 0.0
	if _info_move.text != "":
		var font := _info_move.get_theme_font("font")
		var px := _info_move.get_theme_font_size("font_size")
		width = minf(font.get_string_size(_info_move.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + u,
			_info_row.size.x * 0.65) if font != null else _info_row.size.x * 0.5
	_info_move.position = Vector2(_info_row.end.x - width, _info_row.position.y)
	_info_move.size = Vector2(width, _info_row.size.y)
	_info_title.size = Vector2(maxf(_info_row.size.x - width - u, 1.0), _info_row.size.y)

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
	_redraw()

func _draw() -> void:
	if state.is_empty():
		return
	var u := unit()
	if compact:
		_draw_strip_foot(u)
		return
	var foot := StyleBoxFlat.new()
	foot.bg_color = FOOT_BG
	foot.border_color = Color(MUTED_COLOR.r, MUTED_COLOR.g, MUTED_COLOR.b, 0.35)
	foot.set_border_width_all(maxi(1, int(u * 0.15)))
	foot.set_corner_radius_all(int(u * 1.0))
	draw_style_box(foot, foot_rect())

## Der Turm in der beschnittenen Kartenfläche (in Koordinaten der Karte gemalt).
func _draw_map() -> void:
	if state.is_empty():
		return
	_canvas = _layer
	_layer.draw_set_transform(-_layer.position)
	var u := unit()
	var area := map_rect()
	for f in visible_floors():
		var data := _floor_data(f)
		for door_id: String in data["doors"]:
			_draw_door(data, door_id, u)
		for room_id: String in data["rooms"]:
			if not _hidden_entrance(data, room_id) and room_rect(room_id, f).intersects(area):
				_draw_room(data, room_id, u)
		for door_id: String in data["doors"]:
			_draw_mark(data, door_id, u)
	_draw_hidden(u)
	var here := _puck_rect()
	if here.intersects(area):
		_draw_puck(_puck_center(here, u), u * PUCK_UNITS * (0.8 if compact else 1.0))
	_canvas = self

func _draw_door(data: Dictionary, door_id: String, u: float) -> void:
	var f := int(data["floor"])
	var seg := door_segment(door_id, f)
	if seg.size() != 2:
		return
	var door: Dictionary = data["doors"][door_id]
	var current := bool(data["current"])
	var walk := current and walkable_doors().has(door_id)
	var hovered := walk and move_for(_hover) == door_id
	var color: Color
	var width := u * 0.4
	match int(door["state"]):
		FloorMap.DoorState.PASSED:
			color = PASSED_COLOR
			width = u * 0.7
		FloorMap.DoorState.LOCKED:
			color = Color(LOCKED_COLOR.r, LOCKED_COLOR.g, LOCKED_COLOR.b, 0.8)
		_:
			color = UNKNOWN_COLOR if not bool(door["scouted"]) else _door_color(door)
			color.a = 1.0 if walk else 0.55
	if not current:
		color.a *= HISTORY_ALPHA
	if walk:
		width = u * (0.75 if hovered else 0.55)
		_canvas.draw_line(seg[0], seg[1], Color(color.r, color.g, color.b, 0.25), width * 3.0, true)
	_canvas.draw_line(seg[0], seg[1], color, width, true)
	if int(door["state"]) == FloorMap.DoorState.LOCKED:
		var mid := (seg[0] + seg[1]) * 0.5
		if current and door_id == _flash_door and _flash > 0.0:
			_canvas.draw_circle(mid, u * (2.0 + 2.5 * _flash), Color(LOCKED_COLOR.r, LOCKED_COLOR.g,
				LOCKED_COLOR.b, 0.55 * _flash))
		var r := minf(u * 1.0, door_mark_rect(door_id, f).size.x * 0.45)
		var cross := Color(LOCKED_COLOR.r, LOCKED_COLOR.g, LOCKED_COLOR.b, 1.0 if current else HISTORY_ALPHA)
		_canvas.draw_line(mid + Vector2(-r, -r), mid + Vector2(r, r), cross, u * 0.4, true)
		_canvas.draw_line(mid + Vector2(-r, r), mid + Vector2(r, -r), cross, u * 0.4, true)

func _draw_room(data: Dictionary, room_id: String, u: float) -> void:
	var room: Dictionary = data["rooms"][room_id]
	var f := int(data["floor"])
	var rect := room_rect(room_id, f)
	var current := bool(data["current"])
	var tint := _room_color(room)
	if _is_band(room):
		_draw_band(data, room, rect, u)
		return
	var standing := current and room_id == String(state.get("position", ""))
	var walk := current and door_to(room_id) != ""
	var hovered := walk and move_for(_hover) == door_to(room_id)
	var dim := (bool(room["visited"]) and not standing) or not current
	var box := StyleBoxFlat.new()
	var mix := 0.32 if hovered else (0.2 if walk else (0.1 if dim else 0.16))
	if compact:
		mix += 0.14  # ohne Text trägt die Fläche die Stufe
	box.bg_color = TILE_BG.lerp(Color(tint.r, tint.g, tint.b, TILE_BG.a), mix)
	box.border_color = Color(tint.r, tint.g, tint.b, 1.0 if walk else (0.4 if dim else 0.75))
	if not current:
		box.bg_color.a *= 0.6
		box.border_color.a *= HISTORY_ALPHA
	elif dim:
		box.bg_color.a = 0.7
	box.set_border_width_all(maxi(1, int(u * (0.4 if walk else 0.2))))
	box.set_corner_radius_all(int(u * (0.7 if compact else 1.0)))
	if walk:
		box.shadow_color = Color(tint.r, tint.g, tint.b, 0.55 if hovered else 0.32)
		box.shadow_size = int(u * (1.3 if hovered else 0.8))
	_canvas.draw_style_box(box, rect)

func _draw_band(data: Dictionary, room: Dictionary, rect: Rect2, u: float) -> void:
	var current := bool(data["current"])
	var office := bool(room.get("office", false))
	var tint := _room_color(room) if current else MUTED_COLOR
	var box := StyleBoxFlat.new()
	box.bg_color = TILE_BG.lerp(Color(tint.r, tint.g, tint.b, TILE_BG.a), 0.28 if office and current else 0.12)
	box.border_color = Color(tint.r, tint.g, tint.b, 0.85 if current else 0.4)
	var walk := current and door_to(String(room["id"])) != ""
	box.set_border_width_all(maxi(1, int(u * (0.4 if walk else 0.2))))
	box.set_corner_radius_all(int(u * 0.6))
	if walk:
		box.shadow_color = Color(tint.r, tint.g, tint.b, 0.4)
		box.shadow_size = int(u * 0.9)
	_canvas.draw_style_box(box, rect)
	if compact:
		_draw_centered(_band_text(data, room), rect.grow_individual(-u * 0.8, 0, -u * 0.8, 0),
			u * BAND_FONT_UNITS, Color(tint.r, tint.g, tint.b, 1.0 if current else 0.75),
			HORIZONTAL_ALIGNMENT_LEFT)

func _draw_hidden(u: float) -> void:
	var rect := _hidden_rect()
	if not rect.intersects(map_rect()):
		return
	var dash := u * 0.8
	var c := Color(MUTED_COLOR.r, MUTED_COLOR.g, MUTED_COLOR.b, 0.6)
	var w := maxf(1.0, u * 0.15)
	_canvas.draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), c, w, dash)
	_canvas.draw_dashed_line(Vector2(rect.position.x, rect.end.y), rect.end, c, w, dash)
	_canvas.draw_dashed_line(rect.position, Vector2(rect.position.x, rect.end.y), c, w, dash)
	_canvas.draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, c, w, dash)
	_draw_centered(NEXT_BAND % (current_floor() + 1), rect,
		u * (BAND_FONT_UNITS if compact else NAME_UNITS.y), c)

func _draw_strip_foot(u: float) -> void:
	var rect := foot_rect()
	var free := _free_scroll
	var color := TEXT_COLOR if not free else BRASS_LIGHT
	_draw_centered(head_text(state), rect, u * STRIP_FOOT_FONT_UNITS,
		LOCKED_COLOR if is_boss(state) else color)

func _draw_centered(text: String, rect: Rect2, px: float, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var font := _font()
	var size_px := maxi(8, int(px))
	var y := rect.get_center().y + (font.get_ascent(size_px) - font.get_descent(size_px)) * 0.5
	_canvas.draw_string(font, Vector2(rect.position.x, y), text, align, rect.size.x,
		size_px, color)

func _puck_center(rect: Rect2, u: float) -> Vector2:
	if compact or rect.size.y < row_height(global_row(1, 1)) * 0.9:
		return rect.get_center()
	var inner := rect.grow(-u * 0.5)
	return Vector2(inner.get_center().x, inner.get_center().y + u * (PUCK_UNITS + 0.8))

## Der Puck: eine Messing-Scheibe mit Rand und Glanz.
func _draw_puck(center: Vector2, radius: float) -> void:
	_canvas.draw_circle(center + Vector2(radius * 0.12, radius * 0.18), radius, Color(0, 0, 0, 0.45))
	_canvas.draw_circle(center, radius, BRASS_DARK)
	_canvas.draw_circle(center, radius * 0.86, BRASS)
	_canvas.draw_arc(center, radius * 0.62, 0.0, TAU, 32, BRASS_DARK, maxf(1.0, radius * 0.1), true)
	_canvas.draw_arc(center, radius * 0.86, PI * 1.05, PI * 1.6, 12, BRASS_LIGHT, maxf(1.0, radius * 0.12), true)

func _draw_mark(data: Dictionary, door_id: String, u: float) -> void:
	var door: Dictionary = data["doors"][door_id]
	if int(door["state"]) != FloorMap.DoorState.OPEN:
		return
	var f := int(data["floor"])
	var rect := door_mark_rect(door_id, f)
	var current := bool(data["current"])
	var color := UNKNOWN_COLOR if not bool(door["scouted"]) else _door_color(door)
	var walk := current and walkable_doors().has(door_id)
	var box := StyleBoxFlat.new()
	box.bg_color = TILE_BG
	box.border_color = Color(color.r, color.g, color.b, 1.0 if walk else 0.7)
	if compact and bool(door["scouted"]):
		# Ohne Text trägt die Marke ihre Stufe als Fläche.
		box.bg_color = TILE_BG.lerp(Color(color.r, color.g, color.b, TILE_BG.a), 0.7)
	if not current:
		box.bg_color.a *= HISTORY_ALPHA
		box.border_color.a *= HISTORY_ALPHA
	box.set_border_width_all(maxi(1, int(u * (0.3 if walk else 0.16))))
	box.set_corner_radius_all(int(minf(u * 0.6, rect.size.y * 0.3)))
	if move_for(_hover) == door_id and walk:
		box.bg_color = box.bg_color.lerp(Color(color.r, color.g, color.b, box.bg_color.a), 0.3)
	_canvas.draw_style_box(box, rect)
	if compact and not bool(door["scouted"]):
		_draw_centered(UNKNOWN_TEXT, rect, rect.size.y * 0.8,
			Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, 1.0 if current else HISTORY_ALPHA))
