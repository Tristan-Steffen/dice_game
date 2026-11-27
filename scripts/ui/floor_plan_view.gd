class_name FloorPlanView
extends Control
## Die ETAGEN-KARTE als GRUNDRISS (Welle 7): EINE Zeichnung in zwei Fassungen. DETAIL ist die
## Nahsicht (Grubenboden, Laden-Seite): der eigene Flurabschnitt füllt das Bild, Ziehen schiebt,
## das Rad zoomt bis zur ganzen Etage, ein Klick zieht. COMPACT ist der Hub-Streifen: die ganze
## laufende Etage, darunter die geschafften, darüber gestrichelt die nächste - ohne Klick.
## Kennt GameRun nicht: sie malt GameRun.floor_view_state; die Geometrie hält FloorPlanGeometry.

## Der gewählte Zug (Raum, Tür, Brandschutztür) aus dem Zustand.
signal move_chosen(move: Dictionary)
## Ziel unter dem Zeiger gewechselt - der Hub schreibt die Auskunft neben den Streifen.
signal hover_changed

enum Mode { COMPACT, DETAIL }

# --- Wörter ---------------------------------------------------------------------
const MOVE_HEAD := "Etage %d · Zug %d"
const OFFICE_HEAD := "Etage %d · Büro · Boss-Runde"
const NEXT_BLIND_HEAD := "Nächster Blind %s"
const BLIND_HEAD := "Blind %s"
const KEY_TAKEN_TEXT := "Schlüsselkarte"
const KEY_MISSING_TEXT := "Schlüsselkarte fehlt"
const HERE_TEXT := "DU BIST HIER"
const VISITED_TEXT := "besucht"
const OFFICE_SUB := "Boss-Runde"
const HOME_TEXT := "Zum Standort"
const MOVE_LINE := "Blind %s"
const AVERAGE_PART := " · dein Schnitt %s"
const TOLL_TEXT := "+%d %%"
const NEXT_FLOOR_TEXT := "Etage %d"
const DONE_FLOOR_TEXT := "Etage %d · geschafft"
const IDLE_TITLE := "Wähle einen Raum"
const IDLE_BODY := "Gewählt wird in der Grube."
const PICK_BODY := "Klick auf einen hell gerahmten Raum oder auf eine seiner Türen."
const STAND_TITLE := "Du bist hier: %s"
const STAND_BODY := "Zeig auf einen Raum oder eine Tür - hier steht ihre Klausel. Der nächste Zug folgt nach dem Laden."
const VISITED_BODY := "Besucht - der Bonus ist unterschrieben."
const KEY_BODY := " Hier liegt die Schlüsselkarte: sie öffnet das Büro."
const OFFICE_LOCKED_BODY := "Das Büro des Pit Boss ist verschlossen - erst die Schlüsselkarte holen."
const OFFICE_BODY := "Das Büro des Pit Boss: der Zug hierher ist die Boss-Runde. Die Tür bestimmt die Kondition."
const LIFT_TITLE := "Aufzug"
const LIFT_BODY := "Hier beginnt die Etage. Nach der Boss-Runde fährt er eine Etage höher."
const FIRE_TITLE := "Brandschutztür"
const FIRE_BODY := "Jede Durchquerung kostet einen Blind-Schritt ohne Runde - jetzt +%d %%."
const PASSED_TITLE := "Ausgebrannt"
const PASSED_BODY := "Schon durchschritten - nichts mehr zu unterschreiben."
const OPEN_TITLE := "Offene Tür"
const OPEN_BODY := "Nichts zu unterschreiben."
const UNKNOWN_TITLE := "Tür · %d %s"
const UNKNOWN_BODY := "Ihr Malus zeigt sich, sobald sie erreichbar ist."
const BOSS_TITLE := "Boss-Tür · %s"

# --- Farben ---------------------------------------------------------------------
const BACKGROUND := Color("#0c0f15")
const CORRIDOR := Color("#232a38")
const OUTER_WALL := Color("#eef1f6")
const INNER_WALL := Color("#7d889a")
const LIFT_FLOOR := Color("#151a24")
const LIFT_LINE := Color("#4a5468")
const TEXT_COLOR := Color("#e8ebf1")
const MUTED_COLOR := Color("#9aa3b3")
const YOU := Color.WHITE
const FIRE_RED := Color("#e0352b")
const BOSS_RED := Color("#ff3b30")
const KEY_CARD := Color("#f4f1e4")
const BAR_BG := Color(0.035, 0.045, 0.065, 0.96)
## Raumtür-Stufen: offen, leicht, mittel, schwer - eine eigene Skala, nicht die Raumfarben.
const DOOR_TIER_COLORS := [Color("#d6dbe4"), Color("#8fa3bf"), Color("#e0a840"), Color("#ff7a2e")]
## Ampel des Rundenschnitts (GameRun.margin_of).
const MARGIN_COLORS := {"gut": Color("#6fdc8c"), "knapp": Color("#f2c94c"), "rot": Color("#ff5a4f")}
const ROOM_ALPHA := 0.2
const OFFICE_ALPHA := 0.3
## Geschaffte Etagen stehen gedimmt unter der laufenden.
const HISTORY_ALPHA := 0.42

# --- Maße (in u bzw. Zellen) -----------------------------------------------------
## Einheit ohne Meldung: Breite / UNIT_DIV.
const UNIT_DIV := 100.0
const OUTER_WIDTH := 0.11
const INNER_WIDTH := 0.04
## Innenrand der Raum-Beschriftung in Zellen: tiefer innen als der Weg an der Wand.
const LABEL_PAD := 0.3
const HEAD_UNITS := 3.0
const HEAD_FONT := 1.35
const INFO_UNITS := 5.4
const INFO_TITLE_FONT := 1.4
const INFO_BODY := Vector2(1.3, 1.0)
const PAD_UNITS := 0.6
## Schriftleitern (Ober- und Untergrenze in u): Raumname > Bonus-Name > Text > Zug-Zeile.
const NAME := Vector2(1.7, 1.15)
const BONUS := Vector2(1.4, 1.05)
const TEXT := Vector2(1.3, 1.0)
const MOVE := Vector2(1.25, 1.0)
const DOOR_FONT := Vector2(1.15, 0.95)
const TOLL_FONT := 1.05
## Unter so vielen u je Zelle steht nur Symbol und Name (ganz herausgezoomt).
const FULL_TEXT_CELL := 4.5
## Das Rad zoomt hinein, bis höchstens so viele Zellen in der Höhe stehen (Lesen kleiner Räume).
const CLOSE_ROWS := 6.5
const HOME_PAD := 0.35
const ZOOM_STEP := 1.18
const HOME_TIME := 0.3
const BREATH_RATE := 2.4
const LINE_BOX := 1.12
## COMPACT: geschaffte Etagen kleiner, Bänder und Fuge in u.
const HISTORY_SCALE := 0.72
const NEXT_BAND_UNITS := 2.6
const STACK_GAP_UNITS := 1.2
const CAPTION_FONT := 1.5
const FOOT_UNITS := 3.2
const FOOT_FONT := 2.0
const COMPACT_UNIT_DIV := 30.0
## Fugen langer Wörter: hier darf umbrochen werden, sonst nie mitten im Wort.
const WORD_JOINTS := ["Standard|protokoll", "Zwangs|versteigerung", "Versicherungs|betrug",
	"Rück|versicherung", "Kalt|verfestigung", "Glücks|würfel", "Werkstatt|sperre",
	"Voll|bestückung", "Sonder|lieferung", "Meister|prägung", "Lohn|fortzahlung",
	"Glücks|strähne", "Sicherungs|fall", "Service|gebühr", "Rückkauf|recht", "Glücks|pfennig",
	"Wucher|klausel", "Wackel|kontakt", "Unglücks|zahl", "Hinter|zimmer", "Erwar|tungen",
	"Aus|zahlung", "Hand|schlag", "Blanko|scheck", "Supra|leiter", "Glücks|kind",
	"Neben|wetten", "Runden|beginn", "Wechsel|schalter", "Cocktail|bar", "Umspann|werk",
	"Technik|raum", "Schalt|raum", "Buch|macher", "Prüf|stelle", "Spiel|saal",
	"Schlüssel|karte", "Hinterzimmer-|Kontakt", "Versicherungs|police", "Rampen|licht"]

## Der Zustand aus GameRun.floor_view_state (leer = geschlossen).
var state: Dictionary = {}
var mode := Mode.DETAIL
## Nur ansehen (Laden): kein Zug, wie auch immer der Zustand steht.
var read_only := false
## Darf der fällige Zug JETZT gewählt werden (scene_root: die Runde wartet auf ihn)?
var moves_enabled := true
## Einheit in Display-px (Hub bzw. Seite melden ihre; 0 = selbst rechnen).
var unit_px := 0.0
## COMPACT: Ausschnitt des Stapels in px (0 = oben).
var scroll := 0.0

## Die laufende Etage und (COMPACT) die geschafften, je {geo, floor, done}.
var _floors: Array[Dictionary] = []
var _geo: FloorPlanGeometry
## DETAIL: Zoom (px je Zelle) und die Zellmitte des Ausschnitts.
var _cell := 0.0
var _center := Vector2.ZERO
var _home_tween: Tween
var _hover: Dictionary = {}
var _pointer_in := false
var _pressing := false
var _dragging := false
var _press_at := Vector2.ZERO
var _press_center := Vector2.ZERO
var _time := 0.0
var _home_key := ""
## Beschriftung je Raum, gerechnet für einen Zoom: Raum-Id → [{text, px, at, color, width}].
var _labels: Dictionary = {}
var _labels_cell := -1.0
var _home_button: Button
## Was die Malerei dieses Bilds schon belegt hat (Maut-Marken, Tür-Namen) - Tür-Namen weichen aus.
var _occupied: Array[Rect2] = []

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(false)
	_home_button = Button.new()
	_home_button.name = "ToHome"
	_home_button.text = HOME_TEXT
	_home_button.visible = false
	_home_button.focus_mode = Control.FOCUS_NONE
	_home_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_home_button.pressed.connect(func() -> void: snap_home(false))
	add_child(_home_button)

func detail() -> bool:
	return mode == Mode.DETAIL

# --- Zustand --------------------------------------------------------------------

## Zeigt den Zustand. Ein unveränderter baut nichts neu - der Hub fragt oft.
func open(view_state: Dictionary) -> void:
	if visible and view_state == state:
		return
	var kept := _hover
	state = view_state.duplicate(true)
	_floors.clear()
	_geo = FloorPlanGeometry.new(state) if not state.is_empty() else null
	if _geo != null:
		_floors.append({"geo": _geo, "floor": int(state.get("floor", 1)), "done": false})
		var history: Array = state.get("history", [])
		for i in range(history.size() - 1, -1, -1):
			_floors.append({"geo": FloorPlanGeometry.new(history[i]),
				"floor": int(history[i].get("floor_index", i)) + 1, "done": true})
	_labels_cell = -1.0
	visible = true
	set_process(true)
	var key := "%d:%s" % [current_floor(), String(state.get("position", ""))]
	if key != _home_key or _cell <= 0.0:
		_home_key = key
		snap_home(true)
	_layout()
	_hover = kept if not kept.is_empty() and not _entry(kept).is_empty() else {}
	queue_redraw()

func close() -> void:
	visible = false
	set_process(false)
	_hover = {}
	_pressing = false
	_dragging = false

## Die Geometrie der laufenden Etage (null = geschlossen).
func geometry() -> FloorPlanGeometry:
	return _geo

func current_floor() -> int:
	return int(state.get("floor", 1))

## Die gangbaren Züge des fälligen Zugs (leer = nur ansehen).
func walkable_moves() -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	if read_only or not moves_enabled:
		return moves
	moves.assign(state.get("moves", []))
	return moves

## Ob ein Klick hier je zieht: nur die Nahsicht, nie im Laden.
func takes_moves() -> bool:
	return detail() and not read_only

func set_moves_enabled(on: bool) -> void:
	if on == moves_enabled:
		return
	moves_enabled = on
	_labels_cell = -1.0
	_layout()
	_refresh_pointer()

func hovered() -> Dictionary:
	return _hover

func pointer_inside() -> bool:
	return _pointer_in

func pressing() -> bool:
	return _pressing

func dragging() -> bool:
	return _dragging

func clear_hover() -> void:
	hover_at(Vector2(-1, -1))

# --- Rahmen ---------------------------------------------------------------------

func unit() -> float:
	if unit_px > 0.0:
		return unit_px
	return maxf(size.x / (UNIT_DIV if detail() else COMPACT_UNIT_DIV), 1.0)

## Kopfzeile der Nahsicht.
func head_rect() -> Rect2:
	var u := unit()
	return Rect2(u * PAD_UNITS, 0.0, size.x - u * PAD_UNITS * 2.0, u * HEAD_UNITS)

## Die Auskunfts-Zeile am unteren Rand der Nahsicht.
func info_rect() -> Rect2:
	var u := unit()
	return Rect2(0.0, size.y - u * INFO_UNITS, size.x, u * INFO_UNITS)

## Die Fläche des Grundrisses.
func map_rect() -> Rect2:
	if not detail():
		return Rect2(0.0, 0.0, size.x, maxf(size.y - unit() * FOOT_UNITS, 1.0))
	var top := head_rect().end.y
	return Rect2(0.0, top, size.x, maxf(info_rect().position.y - top, 1.0))

func foot_rect() -> Rect2:
	var u := unit()
	return Rect2(0.0, size.y - u * FOOT_UNITS, size.x, u * FOOT_UNITS)

# --- Ausschnitt der Nahsicht --------------------------------------------------------

## Pixel je Zelle, wenn die ganze Etage ins Bild paßt.
func whole_cell() -> float:
	if _geo == null:
		return 1.0
	var box := _geo.bounds_cells().grow(HOME_PAD)
	var area := map_rect()
	return maxf(0.5, minf(area.size.x / box.size.x, area.size.y / box.size.y))

## [Zellmitte, px je Zelle] der Heimat: der eigene Flurabschnitt samt Räumen füllt das Bild,
## der Standraum immer ganz darin.
func home_view() -> Array:
	if _geo == null:
		return [Vector2.ZERO, 1.0]
	var area := map_rect()
	var box := _geo.section_box(_geo.home_section()).grow(HOME_PAD)
	var cell := minf(area.size.x / box.size.x, area.size.y / box.size.y)
	cell = maxf(cell, whole_cell())
	var center := box.get_center()
	var here := _geo.home_rect_cells().grow(HOME_PAD)
	var half := area.size / cell * 0.5
	for axis in 2:
		var low := here.end[axis] - half[axis]
		var high := here.position[axis] + half[axis]
		center[axis] = here.get_center()[axis] if low > high else clampf(center[axis], low, high)
	return [_clamp_center(center, cell), cell]

## Die Zellmitte so, daß der Ausschnitt nicht weiter als nötig über den Umriß hinausragt.
func _clamp_center(center: Vector2, cell: float) -> Vector2:
	if _geo == null:
		return center
	var bounds := _geo.bounds_cells().grow(HOME_PAD)
	var half := map_rect().size / cell * 0.5
	for axis in 2:
		var low := bounds.position[axis] + half[axis]
		var high := bounds.end[axis] - half[axis]
		center[axis] = (low + high) * 0.5 if low > high else clampf(center[axis], low, high)
	return center

## Zellen-Ausschnitt anwenden (DETAIL) bzw. den Stapel legen (COMPACT).
func _layout() -> void:
	if _geo == null:
		return
	if detail():
		_geo.place(_center, _cell, map_rect())
		if not is_equal_approx(_labels_cell, _cell):
			_build_labels()
		_sync_home_button()
		return
	var u := unit()
	var area := map_rect()
	var pad := u * PAD_UNITS
	var y := pad + u * NEXT_BAND_UNITS + u * STACK_GAP_UNITS - scroll
	for i in _floors.size():
		var geo: FloorPlanGeometry = _floors[i]["geo"]
		var box := geo.bounds_cells()
		var width := (area.size.x - pad * 2.0) * (1.0 if i == 0 else HISTORY_SCALE)
		if i > 0:
			y += u * CAPTION_FONT * LINE_BOX
		var cell := width / box.size.x
		var top_left := Vector2((area.size.x - width) * 0.5, y)
		geo.place(box.get_center(), cell, Rect2(top_left, box.size * cell))
		y += box.size.y * cell + u * STACK_GAP_UNITS

## Die Höhe des ganzen Stapels (COMPACT) in px.
func stack_height() -> float:
	var u := unit()
	var area := map_rect()
	var pad := u * PAD_UNITS
	var y := pad + u * NEXT_BAND_UNITS + u * STACK_GAP_UNITS
	for i in _floors.size():
		var box: Rect2 = (_floors[i]["geo"] as FloorPlanGeometry).bounds_cells()
		var width := (area.size.x - pad * 2.0) * (1.0 if i == 0 else HISTORY_SCALE)
		if i > 0:
			y += u * CAPTION_FONT * LINE_BOX
		y += box.size.y * width / box.size.x + u * STACK_GAP_UNITS
	return y

## Holt Ausschnitt und Zoom auf den Standort (DETAIL) bzw. den Stapel nach oben (COMPACT).
func snap_home(hard: bool = true) -> void:
	if _home_tween != null and _home_tween.is_valid():
		_home_tween.kill()
	if not detail():
		scroll = 0.0
		_layout()
		queue_redraw()
		return
	if _geo == null:
		return
	var home := home_view()
	if hard or not is_inside_tree():
		_center = home[0]
		_cell = home[1]
		_layout()
		queue_redraw()
		return
	var from_center := _center
	var from_cell := _cell
	_home_tween = create_tween()
	_home_tween.tween_method(func(t: float) -> void:
		_center = from_center.lerp(home[0], t)
		_cell = lerpf(from_cell, home[1], t)
		_layout()
		queue_redraw(), 0.0, 1.0, HOME_TIME).set_trans(Tween.TRANS_SINE)

## Ob Ausschnitt oder Zoom von der Heimat abweichen (DETAIL) bzw. der Stapel gerollt ist.
func away_from_home() -> bool:
	if not detail():
		return scroll > 0.5
	if _geo == null:
		return false
	var home := home_view()
	return absf(_cell - float(home[1])) > 0.5 or _center.distance_to(home[0]) > 0.05

func zoom_cell() -> float:
	return _cell

func view_center() -> Vector2:
	return _center

## Zoomt stufenlos um den Punkt local, zwischen ganzer Etage und Heimat-Zoom.
func zoom_at(local: Vector2, steps: float) -> void:
	if not detail() or _geo == null:
		return
	if _home_tween != null and _home_tween.is_valid():
		_home_tween.kill()
	var anchor := _geo.to_cells(local)
	var low := whole_cell()
	var high := maxf(float(home_view()[1]), map_rect().size.y / CLOSE_ROWS)
	var cell := clampf(_cell * pow(ZOOM_STEP, steps), low, high)
	_center = _clamp_center(anchor - (local - map_rect().get_center()) / cell, cell)
	_cell = cell
	_layout()
	queue_redraw()

## Das Rad: DETAIL zoomt um den Zeiger, COMPACT rollt den Stapel (positiv = nach oben).
func wheel(local: Vector2, up: bool) -> void:
	if detail():
		zoom_at(local, 1.0 if up else -1.0)
	else:
		scroll_by(1.0 if up else -1.0)

## COMPACT: rollt den Stapel um steps Viertel der Höhe (positiv = nach oben, zur laufenden).
func scroll_by(steps: float) -> void:
	if detail():
		zoom_at(map_rect().get_center(), steps)
		return
	var high := maxf(0.0, stack_height() - map_rect().size.y)
	scroll = clampf(scroll - steps * map_rect().size.y * 0.25, 0.0, high)
	_layout()
	queue_redraw()

func _sync_home_button() -> void:
	var shown := detail() and _geo != null and away_from_home()
	_home_button.visible = shown
	if not shown:
		return
	var u := unit()
	var info := info_rect()
	var w := u * 13.0
	_home_button.position = Vector2(info.end.x - w - u * PAD_UNITS, info.position.y + u * 0.6)
	_home_button.size = Vector2(w, info.size.y - u * 1.2)
	CasinoStyle.style_button(_home_button, Color("#d4a94a"), Color("#8a6420"), int(u * HEAD_FONT))

# --- Treffer und Regeln aus dem Zustand ------------------------------------------------

## Was unter dem Punkt liegt: {kind: "room"|"door", id} der laufenden Etage ({} = nichts).
func target_at(local: Vector2) -> Dictionary:
	if _geo == null or not map_rect().has_point(local):
		return {}
	return _geo.target_at(local)

func _entry(target: Dictionary) -> Dictionary:
	if _geo == null or target.is_empty():
		return {}
	var pool: Dictionary = _geo.rooms if target["kind"] == "room" else _geo.doors
	return pool.get(String(target["id"]), {})

## Der gangbare Zug hinter dem Ziel: ein Raum nimmt den billigsten, eine Tür genau sich ({} = keiner).
func move_for(target: Dictionary) -> Dictionary:
	if target.is_empty():
		return {}
	var door_id := ""
	if target["kind"] == "room":
		door_id = String(_entry(target).get("cheapest_door", ""))
	else:
		door_id = String(target["id"])
	if door_id == "":
		return {}
	for move in walkable_moves():
		if String(move["door"]) == door_id:
			return move
	return {}

## Der gangbare Zug in einen Raum (sein billigster), {} = nicht gangbar.
func move_to_room(room_id: String) -> Dictionary:
	return move_for({"kind": "room", "id": room_id})

func _moves_by_room() -> Dictionary:
	var by := {}
	for move in walkable_moves():
		by[String(move["room"])] = true
	return by

# --- Eingabe --------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _pressing:
			drag_to(motion.position)
			accept_event()
			return
		hover_at(motion.position)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			if begin_press(button.position):
				accept_event()
		elif end_press(button.position):
			accept_event()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_EXIT, NOTIFICATION_VISIBILITY_CHANGED:
			if not _pressing:
				clear_hover()
		NOTIFICATION_RESIZED:
			if _geo != null:
				_labels_cell = -1.0
				snap_home(true)

func hover_at(local: Vector2) -> void:
	_pointer_in = local.x >= 0.0 and Rect2(Vector2.ZERO, size).has_point(local)
	var target := target_at(local) if _pointer_in else {}
	if target == _hover:
		return
	_hover = target
	_refresh_pointer()

func _refresh_pointer() -> void:
	var clickable := takes_moves() and not move_for(_hover).is_empty()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	queue_redraw()
	hover_changed.emit()

## Druck in der Nahsicht: eine MÖGLICHE Geste - erst das Loslassen sagt Klick oder Zug.
func begin_press(local: Vector2) -> bool:
	if not detail() or _geo == null or not Rect2(Vector2.ZERO, size).has_point(local):
		return false
	if _home_tween != null and _home_tween.is_valid():
		_home_tween.kill()
	_pressing = true
	_dragging = false
	_press_at = local
	_press_center = _center
	return true

## Über der Schwelle des Magazins wird der Druck zum ZUG: er schiebt den Ausschnitt in beide Richtungen.
func drag_to(local: Vector2) -> void:
	if not _pressing:
		return
	if not _dragging and local.distance_to(_press_at) > PackDrawerView.DRAG_THRESHOLD:
		_dragging = true
		_hover = {}
		_refresh_pointer()
	if _dragging:
		_center = _clamp_center(_press_center - (local - _press_at) / _cell, _cell)
		_layout()
		queue_redraw()

## Loslassen: unter der Schwelle ein Klick (er zieht), ein Zug bleibt liegen.
func end_press(local: Vector2) -> bool:
	if not _pressing:
		return false
	_pressing = false
	if not _dragging:
		press_at(local)
	_dragging = false
	hover_at(local)
	return true

## Das Loslassen kam nicht an (außerhalb der Anzeige): kein Klick.
func cancel_press() -> void:
	_pressing = false
	_dragging = false

## Klick: ein gangbarer Raum meldet seinen billigsten Zug, eine Tür genau ihren.
func press_at(local: Vector2) -> bool:
	if state.is_empty() or not takes_moves():
		return false
	var move := move_for(target_at(local))
	if move.is_empty():
		return false
	move_chosen.emit(move)
	return true

# --- Auskunft (die EINE Quelle für Nahsicht und Hub) ---------------------------------

## {title, body, color, move, move_color}: das Ziel unter dem Zeiger, sonst die Ruhe.
func info_parts() -> Dictionary:
	var parts := {"title": IDLE_TITLE, "body": IDLE_BODY if not detail() else PICK_BODY,
		"color": TEXT_COLOR, "move": "", "move_color": TEXT_COLOR}
	if state.is_empty():
		return parts
	if walkable_moves().is_empty():
		parts["title"] = STAND_TITLE % _place_name(String(state.get("position", "")))
		parts["body"] = STAND_BODY
	if _hover.is_empty():
		return parts
	var info := _hover_info()
	parts["title"] = info[0]
	parts["body"] = info[1]
	parts["color"] = info[2]
	var move := move_for(_hover)
	if not move.is_empty():
		var line := move_line(move)
		parts["move"] = line[0]
		parts["move_color"] = line[1]
	return parts

func info_text() -> String:
	var parts := info_parts()
	var text := String(parts["title"]) + "\n" + String(parts["body"])
	if String(parts["move"]) != "":
		text += "\n" + String(parts["move"])
	return text

func _place_name(room_id: String) -> String:
	if room_id == "" or _geo == null:
		return LIFT_TITLE
	return String(_geo.rooms.get(room_id, {}).get("name", ""))

## [Text, Farbe] der Zug-Zeile: „Blind 290 · dein Schnitt 300“ in der Ampel; Maut voran.
static func move_line(move: Dictionary) -> Array:
	var text := MOVE_LINE % BigNumber.short(float(move.get("blind_after", 0)))
	var typical := float(move.get("typical", 0.0))
	if typical > 0.0:
		text += AVERAGE_PART % BigNumber.short(typical)
	return [text, MARGIN_COLORS.get(String(move.get("margin", "")), TEXT_COLOR)]

func _hover_info() -> Array:
	var entry := _entry(_hover)
	if entry.is_empty():
		return [IDLE_TITLE, IDLE_BODY, TEXT_COLOR]
	if _hover["kind"] == "room":
		var tint: Color = entry["color"]
		var title := String(entry["name"])
		if bool(entry["is_office"]):
			var key := bool(state.get("key_taken", false))
			return [title, OFFICE_BODY if key else OFFICE_LOCKED_BODY, BOSS_RED]
		if bool(entry["current"]):
			title = STAND_TITLE % title
		if bool(entry["visited"]):
			return [title, VISITED_BODY, tint.lightened(0.3)]
		if String(entry["bonus_name"]) != "":
			title += " · " + String(entry["bonus_name"])
		var body := String(entry.get("bonus_text", ""))
		if bool(entry["has_key"]):
			body += KEY_BODY
		return [title, body, tint.lightened(0.3)]
	var tier := int(entry["tier"])
	match String(entry["kind"]):
		FloorPlan.DOOR_FIRE:
			return [FIRE_TITLE, FIRE_BODY % int(state.get("toll_percent", 0)), FIRE_RED]
		FloorPlan.DOOR_BOSS:
			var body := String(entry.get("boss_text", ""))
			if not bool(state.get("key_taken", false)):
				body += " " + OFFICE_LOCKED_BODY
			return [BOSS_TITLE % String(entry.get("boss_name", "")), body, BOSS_RED]
	if bool(entry["passed"]):
		return [PASSED_TITLE, PASSED_BODY, YOU]
	if tier <= FloorPlan.TIER_FREE:
		return [OPEN_TITLE, OPEN_BODY, DOOR_TIER_COLORS[0]]
	var color: Color = DOOR_TIER_COLORS[clampi(tier, 0, 3)]
	if String(entry.get("malus_name", "")) == "":
		return [UNKNOWN_TITLE % [tier, "Riegel"], UNKNOWN_BODY, color]
	return [String(entry["malus_name"]), String(entry["malus_text"]), color]

## Die Kopfzeile links: Etage und Zug (im Büro die Boss-Runde).
static func head_text(view_state: Dictionary) -> String:
	var floor_no := int(view_state.get("floor", 1))
	if bool(view_state.get("boss_round", false)):
		return OFFICE_HEAD % floor_no
	var moves := int(view_state.get("move_count", 0)) + (1 if bool(view_state.get("due", false)) else 0)
	return MOVE_HEAD % [floor_no, maxi(1, moves)]

## Die Kopfzeile rechts: vor dem Zug der nächste Blind, sonst der laufende.
static func blind_text(view_state: Dictionary) -> String:
	if bool(view_state.get("due", false)):
		return NEXT_BLIND_HEAD % BigNumber.short(int(view_state.get("next_blind", 0)))
	return BLIND_HEAD % BigNumber.short(int(view_state.get("blind", 0)))

static func is_boss(view_state: Dictionary) -> bool:
	return bool(view_state.get("boss_round", false))

# --- Text umbrechen: an Wortfugen, nie mitten im Wort ------------------------------

static func word_parts(word: String) -> PackedStringArray:
	for joint: String in WORD_JOINTS:
		if joint.replace("|", "") == word:
			var halves := joint.split("|")
			var head := halves[0] if halves[0].ends_with("-") else halves[0] + "-"
			return PackedStringArray([head, halves[1]])
	var dash := word.find("-")
	if dash > 0 and dash < word.length() - 1:
		return PackedStringArray([word.substr(0, dash + 1), word.substr(dash + 1)])
	return PackedStringArray([word])

## Zeilen im Grad px, die in width passen (leer = ein Teil ist zu breit).
static func wrap_text(text: String, font: Font, px: int, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	# Eine Einheit bleibt an ihrer Zahl („−10 %“ bricht nie).
	text = text.replace(" %", char(0xA0) + "%")
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

## Größter Grad von biggest bis smallest, in dem der Text umbrochen in die Fläche paßt:
## {lines, px, fits}.
static func fit_text(text: String, font: Font, width: float, height: float, biggest: int,
		smallest: int) -> Dictionary:
	for px in range(biggest, smallest - 1, -1):
		var lines := wrap_text(text, font, px, width)
		if not lines.is_empty() and text_height(font, px, lines.size()) <= height:
			return {"lines": lines, "px": px, "fits": true}
	return {"lines": PackedStringArray(), "px": smallest, "fits": false}

static func text_height(font: Font, px: int, lines: int) -> float:
	return font.get_height(px) * LINE_BOX * float(lines)

func _font() -> Font:
	var font := get_theme_font("font", "Label")
	return font if font != null else ThemeDB.fallback_font

# --- Beschriftung der Räume (gerechnet je Zoom) ----------------------------------------

## Ob der Zoom vollen Text trägt (sonst nur Symbol und Name); die Heimat trägt ihn immer.
func full_text() -> bool:
	var home := float(home_view()[1]) if _geo != null else 0.0
	return _cell >= minf(unit() * FULL_TEXT_CELL, home - 0.5)

## Je Raum die Zeilen relativ zur Raumecke: {lines, px, at, color, kind}.
func _build_labels() -> void:
	_labels.clear()
	_labels_cell = _cell
	if _geo == null:
		return
	var font := _font()
	var u := unit()
	var full := full_text()
	var walkable := _moves_by_room()
	for room_id: String in _geo.rooms:
		var info: Dictionary = _geo.rooms[room_id]
		var size_px := Vector2(Rect2(info["rect"]).size) * _cell
		var pad := maxf(_cell * LABEL_PAD, 3.0)
		var inner := Rect2(Vector2(pad, pad), size_px - Vector2(pad, pad) * 2.0)
		var items: Array[Dictionary] = []
		var y := inner.position.y
		var name_px_max := int(u * NAME.x)
		var icon := float(name_px_max) * 0.95
		var name_w := inner.size.x - icon * 1.3
		if bool(info["has_key"]):
			name_w -= key_card_size().x + u * 0.4  # die Schlüsselkarte steht rechts oben
		var name_x := inner.position.x + icon * 1.3
		var name_fit := fit_text(String(info["name"]), font, name_w,
			text_height(font, name_px_max, 1 if full else 2), name_px_max, int(u * NAME.y))
		if not name_fit["fits"]:
			name_fit = fit_text(String(info["name"]), font, name_w, inner.size.y, int(u * NAME.y), int(u * NAME.y))
		var head_color := BOSS_RED.lightened(0.25) if bool(info["is_office"]) else TEXT_COLOR
		if bool(info["visited"]) and not bool(info["current"]):
			head_color = MUTED_COLOR
		items.append({"kind": "icon", "at": Vector2(inner.position.x, y), "px": icon})
		if not name_fit["fits"]:
			# Zu schmal neben dem Symbol: der Name steht darunter über die ganze Breite.
			y += icon * 1.1
			name_x = inner.position.x
			name_fit = fit_text(String(info["name"]), font, inner.size.x, text_height(font, name_px_max, 2),
				name_px_max, int(u * NAME.y))
		if name_fit["fits"]:
			items.append({"kind": "text", "lines": name_fit["lines"], "px": name_fit["px"],
				"at": Vector2(name_x, y), "color": head_color, "role": "name"})
			y += text_height(font, int(name_fit["px"]), (name_fit["lines"] as PackedStringArray).size())
		y += u * 0.15
		var bottom := inner.end.y
		var move: Dictionary = {}
		if walkable.has(room_id):
			move = move_to_room(room_id)
		if bool(info["current"]):
			var pill_h := text_height(font, int(u * MOVE.y), 1) + u * 0.3
			items.append({"kind": "here", "at": Vector2(inner.position.x, bottom - pill_h), "px": int(u * MOVE.y),
				"height": pill_h})
			bottom -= pill_h + u * 0.2
		elif not move.is_empty() and full:
			var line := move_line(move)
			var fit := fit_text(String(line[0]), font, inner.size.x, text_height(font, int(u * MOVE.x), 1),
				int(u * MOVE.x), int(u * MOVE.y))
			if not fit["fits"]:
				line = [MOVE_LINE % BigNumber.short(float(move.get("blind_after", 0))), line[1]]
				fit = fit_text(String(line[0]), font, inner.size.x, text_height(font, int(u * MOVE.x), 1),
					int(u * MOVE.x), int(u * MOVE.y))
			if fit["fits"]:
				var h := text_height(font, int(fit["px"]), 1)
				items.append({"kind": "text", "lines": fit["lines"], "px": fit["px"],
					"at": Vector2(inner.position.x, bottom - h), "color": line[1], "role": "move"})
				bottom -= h + u * 0.15
		if not full:
			_labels[room_id] = items
			continue
		var sub := String(info["bonus_name"])
		var sub_color: Color = (info["color"] as Color).lightened(0.35)
		if bool(info["is_office"]):
			sub = OFFICE_SUB if bool(state.get("key_taken", false)) else KEY_MISSING_TEXT
			sub_color = BOSS_RED.lightened(0.2)
		elif bool(info["visited"]):
			sub = VISITED_TEXT
			sub_color = MUTED_COLOR
		if sub != "":
			var fit := fit_text(sub, font, inner.size.x, minf(bottom - y, text_height(font, int(u * BONUS.x), 2)),
				int(u * BONUS.x), int(u * BONUS.y))
			if fit["fits"]:
				items.append({"kind": "text", "lines": fit["lines"], "px": fit["px"],
					"at": Vector2(inner.position.x, y), "color": sub_color, "role": "bonus_name"})
				y += text_height(font, int(fit["px"]), (fit["lines"] as PackedStringArray).size()) + u * 0.2
		var text := String(info.get("bonus_text", ""))
		var shows_text := text != "" and not bool(info["visited"]) and not bool(info["is_office"])
		if shows_text and bottom - y > 0.0:
			var fit := fit_text(text, font, inner.size.x, bottom - y, int(u * TEXT.x), int(u * TEXT.y))
			if fit["fits"]:
				items.append({"kind": "text", "lines": fit["lines"], "px": fit["px"],
					"at": Vector2(inner.position.x, y), "color": MUTED_COLOR.lightened(0.25), "role": "bonus_text"})
		_labels[room_id] = items

## Alle Texte, die die Nahsicht gerade im Grundriß trägt (für Tests und Sichtproben).
func label_texts() -> Array[String]:
	var out: Array[String] = []
	for room_id: String in _labels:
		for item: Dictionary in _labels[room_id]:
			if item["kind"] == "text":
				out.append("\n".join(item["lines"]))
	return out

## Ob der volle Bonus-Text eines Raums im Grundriß steht.
func room_shows_text(room_id: String) -> bool:
	for item: Dictionary in _labels.get(room_id, []):
		if item.get("role", "") == "bonus_text":
			return true
	return false

## Schriftgrad (px) einer Rolle im Grundriß: name, bonus_name, bonus_text, move (0 = keine).
func label_px(role: String) -> int:
	var best := 0
	for room_id: String in _labels:
		for item: Dictionary in _labels[room_id]:
			if item.get("role", "") == role:
				best = maxi(best, int(item["px"]))
	return best

# --- Malerei --------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _breath() -> float:
	return 0.5 + 0.5 * sin(_time * BREATH_RATE)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if _geo == null:
		return
	var area := map_rect()
	if detail():
		_draw_plan(_geo, 1.0, true)
		_draw_head()
		_draw_info()
		return
	_draw_next_band()
	for i in _floors.size():
		var geo: FloorPlanGeometry = _floors[i]["geo"]
		var box := geo.bounds_px()
		if box.end.y < area.position.y or box.position.y > area.end.y:
			continue
		if i > 0:
			var u := unit()
			_text_line(DONE_FLOOR_TEXT % int(_floors[i]["floor"]), Vector2(box.position.x,
				box.position.y - u * 0.35), u * CAPTION_FONT, MUTED_COLOR, box.size.x)
		_draw_plan(geo, 1.0 if i == 0 else HISTORY_ALPHA, i == 0)
	_draw_foot()

func _draw_next_band() -> void:
	var u := unit()
	var pad := u * PAD_UNITS
	var band := Rect2(pad, pad - scroll, size.x - pad * 2.0, u * NEXT_BAND_UNITS)
	_dashed_rect(band, Color(MUTED_COLOR, 0.6), maxf(1.0, u * 0.12))
	_text_centered(NEXT_FLOOR_TEXT % (current_floor() + 1), band, u * CAPTION_FONT, MUTED_COLOR)

func _draw_foot() -> void:
	var u := unit()
	var foot := foot_rect()
	draw_rect(foot, BACKGROUND)
	_text_centered(head_text(state), foot, u * FOOT_FONT, BOSS_RED if is_boss(state) else TEXT_COLOR)

func _draw_head() -> void:
	var u := unit()
	var head := head_rect()
	draw_rect(Rect2(0, 0, size.x, head.end.y), BAR_BG)
	var px := u * HEAD_FONT
	var font := _font()
	var tint := BOSS_RED if is_boss(state) else TEXT_COLOR
	var base := head.position.y + head.size.y * 0.5 + font.get_ascent(int(px)) * 0.4
	var left := head_text(state)
	draw_string(font, Vector2(head.position.x, base), left, HORIZONTAL_ALIGNMENT_LEFT, -1, int(px), tint)
	var x := head.position.x + font.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, int(px)).x + u * 2.5
	var card := Vector2(px * 1.5, px * 1.0)
	var taken := bool(state.get("key_taken", false))
	_draw_key_card(Rect2(Vector2(x, head.get_center().y - card.y * 0.5), card), taken)
	draw_string(font, Vector2(x + card.x + u * 0.6, base), KEY_TAKEN_TEXT if taken else KEY_MISSING_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(px), TEXT_COLOR if taken else MUTED_COLOR)
	draw_string(font, Vector2(head.position.x, base), blind_text(state), HORIZONTAL_ALIGNMENT_RIGHT,
		head.size.x, int(px), tint)

func _draw_info() -> void:
	var u := unit()
	var bar := info_rect()
	draw_rect(bar, BAR_BG)
	draw_line(bar.position, Vector2(bar.end.x, bar.position.y), Color(INNER_WALL, 0.5), 1.0)
	var parts := info_parts()
	var font := _font()
	var inner := bar.grow(-u * PAD_UNITS)
	if _home_button.visible:
		inner.size.x -= u * 14.0
	var title_px := int(u * INFO_TITLE_FONT)
	var move := String(parts["move"])
	var move_w := 0.0
	if move != "":
		move_w = font.get_string_size(move, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x
		draw_string(font, Vector2(inner.position.x, inner.position.y + font.get_ascent(title_px)), move,
			HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x, title_px, parts["move_color"])
	_text_line(String(parts["title"]), Vector2(inner.position.x, inner.position.y + font.get_ascent(title_px)),
		title_px, parts["color"], inner.size.x - move_w - u)
	var body_top := inner.position.y + text_height(font, title_px, 1)
	var fit := fit_text(String(parts["body"]), font, inner.size.x, inner.end.y - body_top,
		int(u * INFO_BODY.x), int(u * INFO_BODY.y))
	var lines: PackedStringArray = fit["lines"] if fit["fits"] else PackedStringArray([String(parts["body"])])
	_draw_lines(lines, Vector2(inner.position.x, body_top), int(fit["px"]), MUTED_COLOR.lightened(0.3),
		inner.size.x)

## Ein Grundriß: Flure, Aufzug, Räume, Weg, Wände, Türen, Marken; strong = die laufende Etage.
func _draw_plan(geo: FloorPlanGeometry, alpha: float, live: bool) -> void:
	var unit_cell := geo.cell
	var plan := geo.plan
	if live:
		_occupied.clear()
	draw_rect(geo.bounds_px().grow(unit_cell * 0.2), Color(BACKGROUND.lightened(0.02), alpha))
	for info: Dictionary in plan.get("corridors", []):
		for rect: Rect2i in info["rects"]:
			draw_rect(geo.rect_px(Rect2(rect)), Color(CORRIDOR, alpha))
	_draw_elevator(geo, alpha, live)
	for info: Dictionary in plan.get("rooms", []):
		_draw_room_floor(geo, info, alpha)
	_draw_trail(geo, alpha)
	for wall: Dictionary in plan.get("walls", []):
		var outer := bool(wall["outer"])
		var width := maxf(1.0, (OUTER_WIDTH if outer else INNER_WIDTH) * unit_cell)
		var color := Color(OUTER_WALL if outer else INNER_WALL, alpha)
		var a := geo.to_px(wall["a"])
		var b := geo.to_px(wall["b"])
		draw_line(a, b, color, width)
		if outer:
			draw_rect(Rect2(a - Vector2.ONE * width * 0.5, Vector2.ONE * width), color)
			draw_rect(Rect2(b - Vector2.ONE * width * 0.5, Vector2.ONE * width), color)
	for entry: Dictionary in plan.get("doors", []):
		_draw_door(geo, entry, alpha, live)
	for info: Dictionary in plan.get("rooms", []):
		_draw_room_marks(geo, info, alpha, live)
	if live and detail() and full_text():
		for entry: Dictionary in plan.get("doors", []):
			if bool(entry.get("reachable", false)) and String(entry.get("malus_name", "")) != "" \
					and String(entry.get("section", "")) != "" and not bool(entry["passed"]):
				_draw_door_label(geo, entry, DOOR_TIER_COLORS[clampi(int(entry["tier"]), 0, 3)])

func _draw_elevator(geo: FloorPlanGeometry, alpha: float, live: bool) -> void:
	var box := geo.elevator_rect()
	if box.size == Vector2.ZERO:
		return
	var unit_cell := geo.cell
	draw_rect(box, Color(LIFT_FLOOR, alpha))
	var line := Color(LIFT_LINE, alpha * (1.0 if live else 0.6))
	var steps := 7
	for i in range(1, steps):
		var t := float(i) / steps
		var a := box.position + Vector2(box.size.x * t, 0.0)
		var b := box.position + Vector2(0.0, box.size.y * t)
		draw_line(a, b, line, maxf(1.0, unit_cell * 0.025))
		draw_line(box.end - Vector2(box.size.x * t, 0.0), box.end - Vector2(0.0, box.size.y * t), line,
			maxf(1.0, unit_cell * 0.025))
	var mid := box.get_center()
	var arrow := Color(TEXT_COLOR if live else MUTED_COLOR, alpha)
	var tip := mid - Vector2(0, unit_cell * 0.42)
	draw_colored_polygon(PackedVector2Array([tip, mid + Vector2(-unit_cell * 0.28, -unit_cell * 0.08),
		mid + Vector2(unit_cell * 0.28, -unit_cell * 0.08)]), arrow)
	draw_line(mid - Vector2(0, unit_cell * 0.1), mid + Vector2(0, unit_cell * 0.38), arrow, maxf(1.0, unit_cell * 0.1))
	if live and String(geo.plan.get("position", "")) == "":
		_draw_you_rim(box, unit_cell)
		if detail() and full_text():
			var px := int(unit() * MOVE.y)
			var h := text_height(_font(), px, 1) + unit() * 0.3
			_draw_here_pill(Vector2(box.position.x + unit_cell * 0.3, box.end.y - unit_cell * 0.3 - h), px, h)

func _room_tint(info: Dictionary) -> Color:
	var color: Color = info["color"]
	if bool(info["visited"]) and not bool(info["current"]):
		var grey := color.get_luminance()
		color = color.lerp(Color(grey, grey, grey), 0.7)
	return color

func _draw_room_floor(geo: FloorPlanGeometry, info: Dictionary, alpha: float) -> void:
	var color := _room_tint(info)
	color.a = (OFFICE_ALPHA if bool(info["is_office"]) else ROOM_ALPHA) * alpha
	draw_rect(geo.room_rect(String(info["id"])), color)

func _draw_room_marks(geo: FloorPlanGeometry, info: Dictionary, alpha: float, live: bool) -> void:
	var room_id := String(info["id"])
	var box := geo.room_rect(room_id)
	var unit_cell := geo.cell
	var walkable := live and _moves_by_room().has(room_id)
	if live and detail():
		for item: Dictionary in _labels.get(room_id, []):
			var at: Vector2 = box.position + item["at"]
			match String(item["kind"]):
				"icon":
					var s := float(item["px"])
					_draw_symbol(_symbol_of(info), Rect2(at, Vector2(s, s)), _room_tint(info).lightened(0.35))
				"here":
					_draw_here_pill(at, int(item["px"]), float(item["height"]))
				_:
					_draw_lines(item["lines"], at, int(item["px"]), item["color"], box.size.x)
	else:
		var s := minf(box.size.x, box.size.y) * 0.42
		var symbol_color := _room_tint(info).lightened(0.3)
		symbol_color.a = alpha
		_draw_symbol(_symbol_of(info), Rect2(box.get_center() - Vector2(s, s) * 0.5, Vector2(s, s)), symbol_color)
	if bool(info["has_key"]):
		var card := key_card_size() if live and detail() else Vector2(unit_cell * 0.5, unit_cell * 0.33)
		var pad := maxf(unit_cell * LABEL_PAD, 3.0)
		var at := Vector2(box.end.x - pad - card.x, box.position.y + pad)
		_draw_key_card(Rect2(at, card), true, alpha)
	if live and bool(info["current"]):
		_draw_you_rim(box, unit_cell)
	elif walkable:
		var rim := Color(1, 1, 1, 0.5 + 0.2 * _breath())
		draw_rect(box.grow(-unit_cell * 0.07), rim, false, maxf(1.0, unit_cell * 0.045))
		var move := move_to_room(room_id)
		if detail() and int(move.get("toll_percent", 0)) > 0:
			# Auf der oberen Wand, rechts - über dem Rand, nie über dem Namen.
			var tag := _toll_size(int(move["toll_percent"]))
			_draw_toll(Vector2(box.end.x - unit_cell * 0.2, box.position.y - tag.y * 0.5),
				int(move["toll_percent"]), true)
	if live and _hover.get("kind", "") == "room" and _hover.get("id", "") == room_id:
		draw_rect(box.grow(-unit_cell * 0.04), Color(1, 1, 1, 0.08))

func _draw_you_rim(box: Rect2, unit_cell: float) -> void:
	var glow := 0.55 + 0.45 * _breath()
	draw_rect(box.grow(-unit_cell * 0.08), Color(1, 1, 1, 0.18 * glow), false, maxf(2.0, unit_cell * 0.16))
	draw_rect(box.grow(-unit_cell * 0.08), Color(1, 1, 1, 0.75 + 0.25 * glow), false, maxf(1.5, unit_cell * 0.06))

func _draw_here_pill(at: Vector2, px: int, height: float) -> void:
	var font := _font()
	var w := font.get_string_size(HERE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + height * 0.8
	var pill := Rect2(at, Vector2(w, height))
	draw_rect(pill, YOU)
	draw_string(font, Vector2(at.x + height * 0.4, at.y + (height + font.get_ascent(px) - font.get_descent(px)) * 0.5),
		HERE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, px, BACKGROUND)

func _toll_size(percent: int) -> Vector2:
	var font := _font()
	var px := int(unit() * TOLL_FONT)
	var w := font.get_string_size(TOLL_TEXT % percent, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + px * 0.7
	return Vector2(w, text_height(font, px, 1) + px * 0.15)

## Die Maut-Marke: rot-weiß, „+14 %“; corner = rechte obere Ecke bei at, sonst mittig.
func _draw_toll(at: Vector2, percent: int, corner: bool) -> void:
	var font := _font()
	var px := int(unit() * TOLL_FONT)
	var text := TOLL_TEXT % percent
	var w := _toll_size(percent).x
	var h := _toll_size(percent).y
	var box := Rect2(at - Vector2(w, 0.0), Vector2(w, h)) if corner else Rect2(at - Vector2(w, h) * 0.5, Vector2(w, h))
	_occupied.append(box)
	draw_rect(box, FIRE_RED)
	draw_rect(box, Color.WHITE, false, maxf(1.0, px * 0.1))
	draw_string(font, Vector2(box.position.x + px * 0.35, box.position.y + (h + font.get_ascent(px) - font.get_descent(px)) * 0.5),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)

## Die Schlüsselkarte am Raum der Nahsicht, in Schrifthöhe des Namens.
func key_card_size() -> Vector2:
	var h := unit() * NAME.x * 0.95
	return Vector2(h * 1.5, h)

func _draw_key_card(card: Rect2, filled: bool, alpha: float = 1.0) -> void:
	if not filled:
		draw_rect(card, Color(MUTED_COLOR, alpha), false, maxf(1.0, card.size.y * 0.08))
		return
	draw_rect(card, Color(KEY_CARD, alpha))
	draw_rect(Rect2(card.position + Vector2(0, card.size.y * 0.2), Vector2(card.size.x, card.size.y * 0.18)),
		Color(Color("#2b3240"), alpha))
	draw_rect(Rect2(card.position + Vector2(card.size.x * 0.12, card.size.y * 0.55),
		Vector2(card.size.x * 0.22, card.size.y * 0.3)), Color(Color("#c9a84a"), alpha))

func _draw_door(geo: FloorPlanGeometry, entry: Dictionary, alpha: float, live: bool) -> void:
	var frame := geo.door_frame(entry)
	var c: Vector2 = frame["center"]
	var along: Vector2 = frame["along"]
	var unit_cell := geo.cell
	var half := unit_cell * FloorPlanGeometry.DOOR_GAP * 0.5
	var pulse := 1.0
	if live and bool(entry.get("reachable", false)) and not walkable_moves().is_empty():
		pulse = 0.65 + 0.35 * _breath()
	match String(entry["kind"]):
		FloorPlan.DOOR_FIRE:
			_draw_fire_door(c, along, unit_cell, alpha)
			if live and detail():
				_draw_toll(c, int(state.get("toll_percent", 0)), false)
			return
		FloorPlan.DOOR_BOSS:
			var red := Color(BOSS_RED, alpha * pulse)
			draw_line(c - along * half, c + along * half, red, maxf(2.0, unit_cell * 0.12))
			draw_rect(Rect2(c - Vector2.ONE * unit_cell * 0.07, Vector2.ONE * unit_cell * 0.14), Color("#2a0d0b", alpha))
			return
	var into_b := Vector2(entry["side"])
	var hinge := c - along * half
	if bool(entry["passed"]):
		var white := Color(YOU, alpha * 0.9)
		draw_line(hinge, hinge + into_b * half * 2.0, white, maxf(1.0, unit_cell * 0.04))
		_draw_swing(hinge, along, into_b, half * 2.0, Color(YOU, alpha * 0.4))
		return
	var tier := int(entry["tier"])
	if tier <= FloorPlan.TIER_FREE:
		return
	var color: Color = DOOR_TIER_COLORS[clampi(tier, 0, DOOR_TIER_COLORS.size() - 1)]
	color.a = alpha * pulse
	draw_line(c - along * half, c + along * half, color, maxf(1.5, unit_cell * 0.05))
	_draw_swing(hinge, along, into_b, half * 2.0, Color(color, color.a * 0.35))
	var across := Vector2(along.y, along.x)
	for i in tier:
		var at := c + along * half * ((i + 1.0) / (tier + 1.0) * 2.0 - 1.0)
		draw_line(at - across * unit_cell * 0.1, at + across * unit_cell * 0.1, color, maxf(1.5, unit_cell * 0.05))

## Der Malus-Name einer Flurtür im Flur davor, auf der Seite der Tür - nie über die Flurmitte.
func _draw_door_label(geo: FloorPlanGeometry, entry: Dictionary, color: Color) -> void:
	var font := _font()
	var u := unit()
	var side := Vector2(entry["side"])
	if side.x != 0.0:
		return  # Türen zu Seitenfluren: der Name steht in der Auskunft
	var center: Vector2 = geo.to_px(entry["center"])
	var width := geo.cell * 1.9
	var fit := fit_text(String(entry["malus_name"]), font, width, text_height(font, int(u * DOOR_FONT.x), 1),
		int(u * DOOR_FONT.x), int(u * DOOR_FONT.y))
	if not fit["fits"]:
		return
	var px := int(fit["px"])
	var h := text_height(font, px, 1)
	var y := center.y + geo.cell * 0.06 if side.y > 0.0 else center.y - geo.cell * 0.06 - h
	var text := String(fit["lines"][0])
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var box := Rect2(center.x - w * 0.5, y, w, h).grow(u * 0.2)
	for taken in _occupied:
		if taken.intersects(box):
			return  # kein Platz: der Name steht in der Auskunft
	_occupied.append(box)
	draw_string(font, Vector2(center.x - w * 0.5, y + font.get_ascent(px)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
		color.lightened(0.2))

func _draw_swing(hinge: Vector2, along: Vector2, into: Vector2, radius: float, color: Color) -> void:
	var start := along.angle()
	var end := into.angle()
	var delta := wrapf(end - start, -PI, PI)
	draw_arc(hinge, radius, start, start + delta, 12, color, 1.0, true)

## Zweiflügelig quer über den Flur, rot-weiß gesäumt.
func _draw_fire_door(c: Vector2, along: Vector2, unit_cell: float, alpha: float) -> void:
	var half := unit_cell * 0.5
	var a := c - along * half
	var b := c + along * half
	draw_line(a, b, Color(FIRE_RED, alpha), maxf(2.0, unit_cell * 0.13))
	draw_line(a, b, Color(1, 1, 1, alpha), maxf(1.0, unit_cell * 0.035))
	draw_line(c - along * unit_cell * 0.02, c + along * unit_cell * 0.02, BACKGROUND, maxf(2.0, unit_cell * 0.14))
	for end in [a, b]:
		draw_rect(Rect2(end - Vector2.ONE * unit_cell * 0.07, Vector2.ONE * unit_cell * 0.14), Color(FIRE_RED, alpha))

func _draw_trail(geo: FloorPlanGeometry, alpha: float) -> void:
	var cells := geo.trail_points()
	if cells.size() < 2:
		return
	var points := PackedVector2Array()
	for point in cells:
		points.append(geo.to_px(point))
	draw_polyline(points, Color(1, 1, 1, 0.7 * alpha), maxf(1.5, geo.cell * 0.05), true)

# --- Symbole der Themen (gezeichnet, keine Bilder) ----------------------------------

func _symbol_of(info: Dictionary) -> String:
	return String(info.get("symbol", "")) if not bool(info["is_office"]) else "schloss"

## Ein einfaches Piktogramm je Thema in der Box.
func _draw_symbol(key: String, box: Rect2, color: Color) -> void:
	var c := box.get_center()
	var r := minf(box.size.x, box.size.y) * 0.5
	var w := maxf(1.0, r * 0.16)
	match key:
		"muenze":
			draw_arc(c, r * 0.85, 0.0, TAU, 20, color, w, true)
			draw_line(c + Vector2(0, -r * 0.45), c + Vector2(0, r * 0.45), color, w)
			draw_arc(c, r * 0.35, -PI * 0.5, PI * 0.5, 8, color, w * 0.8, true)
		"glas":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.75, -r * 0.75), c + Vector2(r * 0.75, -r * 0.75),
				c + Vector2(0, r * 0.05)]), color)
			draw_line(c + Vector2(0, 0), c + Vector2(0, r * 0.75), color, w)
			draw_line(c + Vector2(-r * 0.4, r * 0.8), c + Vector2(r * 0.4, r * 0.8), color, w)
		"tasche":
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.25), Vector2(r * 1.4, r * 1.05)), color)
			draw_arc(c + Vector2(0, -r * 0.25), r * 0.38, PI, TAU, 10, color, w, true)
		"schluessel":
			draw_arc(c + Vector2(-r * 0.45, 0), r * 0.38, 0.0, TAU, 14, color, w, true)
			draw_line(c + Vector2(-r * 0.07, 0), c + Vector2(r * 0.85, 0), color, w)
			draw_line(c + Vector2(r * 0.55, 0), c + Vector2(r * 0.55, r * 0.35), color, w)
			draw_line(c + Vector2(r * 0.8, 0), c + Vector2(r * 0.8, r * 0.3), color, w)
		"blitz":
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.15, -r), c + Vector2(-r * 0.55, r * 0.12),
				c + Vector2(-r * 0.02, r * 0.12), c + Vector2(-r * 0.2, r), c + Vector2(r * 0.55, -r * 0.15),
				c + Vector2(r * 0.02, -r * 0.15)]), color)
		"klee":
			for angle in [-PI * 0.5, PI / 6.0, PI * 5.0 / 6.0]:
				draw_circle(c + Vector2.from_angle(angle) * r * 0.4, r * 0.33, color)
			draw_line(c, c + Vector2(r * 0.3, r * 0.9), color, w)
		"schein":
			var bill := Rect2(c - Vector2(r * 0.9, r * 0.55), Vector2(r * 1.8, r * 1.1))
			draw_rect(bill, color, false, w)
			draw_arc(c, r * 0.28, 0.0, TAU, 12, color, w, true)
		"diskette":
			var disk := Rect2(c - Vector2(r * 0.8, r * 0.8), Vector2(r * 1.6, r * 1.6))
			draw_rect(disk, color, false, w)
			draw_rect(Rect2(disk.position + Vector2(r * 0.35, 0), Vector2(r * 0.8, r * 0.5)), color)
			draw_rect(Rect2(disk.position + Vector2(r * 0.3, r * 0.95), Vector2(r * 1.0, r * 0.55)), color, false, w)
		"chip":
			var core := Rect2(c - Vector2(r * 0.5, r * 0.5), Vector2(r, r))
			draw_rect(core, color, false, w)
			for i in 3:
				var t := -0.3 + 0.3 * i
				draw_line(c + Vector2(-r * 0.5, r * t), c + Vector2(-r * 0.9, r * t), color, w)
				draw_line(c + Vector2(r * 0.5, r * t), c + Vector2(r * 0.9, r * t), color, w)
				draw_line(c + Vector2(r * t, -r * 0.5), c + Vector2(r * t, -r * 0.9), color, w)
				draw_line(c + Vector2(r * t, r * 0.5), c + Vector2(r * t, r * 0.9), color, w)
		"auge":
			draw_arc(c + Vector2(0, r * 0.55), r * 0.95, -PI * 0.82, -PI * 0.18, 12, color, w, true)
			draw_arc(c - Vector2(0, r * 0.55), r * 0.95, PI * 0.18, PI * 0.82, 12, color, w, true)
			draw_circle(c, r * 0.26, color)
		"waage":
			draw_line(c + Vector2(0, -r * 0.8), c + Vector2(0, r * 0.75), color, w)
			draw_line(c + Vector2(-r * 0.85, -r * 0.5), c + Vector2(r * 0.85, -r * 0.5), color, w)
			draw_line(c + Vector2(-r * 0.4, r * 0.8), c + Vector2(r * 0.4, r * 0.8), color, w)
			for sx in [-1.0, 1.0]:
				draw_arc(c + Vector2(sx * r * 0.65, -r * 0.05), r * 0.28, 0.0, PI, 8, color, w, true)
		"schloss":
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.1), Vector2(r * 1.2, r * 0.95)), color)
			draw_arc(c + Vector2(0, -r * 0.1), r * 0.4, PI, TAU, 10, color, w * 1.2, true)
		_:
			draw_circle(c, r * 0.3, color)

# --- Schrift --------------------------------------------------------------------

func _draw_lines(lines: PackedStringArray, at: Vector2, px: int, color: Color, width: float) -> void:
	var font := _font()
	var step := font.get_height(px) * LINE_BOX
	for i in lines.size():
		draw_string(font, Vector2(at.x, at.y + font.get_ascent(px) + step * i), lines[i],
			HORIZONTAL_ALIGNMENT_LEFT, width, px, color)

## Eine Zeile an der Grundlinie, verkleinert bis sie in width paßt.
func _text_line(text: String, baseline: Vector2, font_px: float, color: Color, width: float) -> void:
	var font := _font()
	var px := int(font_px)
	while px > 7 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		px -= 1
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, width, px, color)

func _text_centered(text: String, box: Rect2, font_px: float, color: Color) -> void:
	var font := _font()
	var px := int(font_px)
	while px > 7 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > box.size.x:
		px -= 1
	var base := box.position.y + (box.size.y + font.get_ascent(px) - font.get_descent(px)) * 0.5
	draw_string(font, Vector2(box.position.x, base), text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, px, color)

func _dashed_rect(box: Rect2, color: Color, width: float) -> void:
	var corners := [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], color, width, width * 5.0)
