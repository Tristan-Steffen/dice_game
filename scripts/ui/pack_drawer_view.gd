class_name PackDrawerView
extends Control
## Das MAGAZIN der Werkbank: EINE durchgehende GRUBE in der Schürze - und seit der
## Welle 29 ein REGALSTAPEL aus VIER TABLETTS, eines je SORTE (Pack.SHELF_ORDER), zu
## je ZWEI LANES, von denen genau EIN Tablett in der Fläche liegt.
## Ein Tablett ist EIN durchgehendes Regal: Platz k liegt in Spalte k / 2, Lane
## k % 2 (spaltenweise: hinten, vorn, nächste Spalte), und es ROLLT - ein Zug über
## das Magazin schiebt es waagerecht, das Fenster zeigt immer COLUMNS Spalten.
## Die Karten LIEGEN flach, Netz nach oben; ShelfStackView fährt die Körper, diese
## Klasse rechnet die Plätze - und die reine TABLETT-Rechnung wohnt hier, damit
## table/ sie liest statt umgekehrt.
## Die Karte hat ihr FESTES Maß (CASSETTE_SCALE) und ist so bemessen, daß genau
## COLUMNS liegende Karten in eine Reihe der Grube passen. Unbegrenzt ist der Bestand.
## Eine Karte auf einem verdeckten TABLETT hat keinen Chip: ihr Liefer-Licht endet an
## der TASTE ihres Tabletts; eine hinausgerollte am Grubenrand ihrer Seite.
## Die Grube ist echt: screen_glass verwirft sein Bild darin, table_ground seinen
## Filz, und PackPitView stellt Wände und Boden. Diese Klasse malt nur die FASSUNG
## darum herum und trägt die Gesten: getippt wählt, gezogen rollt.
## Reiner Renderer: was liegt, was reserviert ist und was noch fliegt, entscheidet
## WorkshopView (drawer_entries).

## Eine Kassette wurde angetippt: sie wandert in die nächste freie Etage.
signal pack_pressed(uid: int)
## Doppelklick auf leere Fach-Fläche: das Magazin soll sich aufräumen.
signal tidy_requested
## Ein ZUG über das Magazin: so weit (Display-px) ist der Zeiger seit dem Druck.
signal scroll_dragged(offset_px: float)
## Der Zug ist losgelassen - das Tablett soll auf eine ganze Spalte einrasten.
signal scroll_released(offset_px: float)

const GOLD := Color("#ffd319")

## Sorten-Farben - Schlüssel sind Pack.SHELF_ORDER: die Taxonomie wohnt in data/,
## die Farben hier (Rune.tint-Regel: data importiert nie ui).
const COLORS := {
	Engraving.CATEGORY_NUMBER: Color("#50fa7b"),
	Engraving.CATEGORY_MATERIAL: Color("#ff79c6"),
	Engraving.CATEGORY_DICE: Color("#ffd319"),
	Pack.SHELF_SPECIAL: Color("#bd93f9"),
}

## Die Reparatur-Karte trägt GOLD statt ihrer Sortenfarbe, und zwar in voller Stärke.
const REPAIR_TINT := CasinoStyle.GOLD_INTENSE
## Das MULTIPLIKATOR-NETZ trägt LILA ("episch") statt Zahlen-Grün - tiefer und
## satter als das Lavendel des Sonderbestands. Die Größe stuft es wie jede Sorte.
const MULTIPLIER_TINT := Color("#9a4dff")

## Die Farbe einer Kassette - die Sortenfarbe, die Reparatur-Karte golden, ein Netz
## mit Faktor-Zellen lila.
static func tint_of(shelf: String, catalyst_id := "", net: Array = []) -> Color:
	if catalyst_id == Pack.CATALYST_REPAIR:
		return REPAIR_TINT
	if catalyst_id == "" and StampNet.is_factor_net(net):
		return MULTIPLIER_TINT
	return COLORS.get(shelf, GOLD)

static func pack_tint(pack: Pack) -> Color:
	if pack == null:
		return GOLD
	return tint_of(Pack.shelf_of(pack), pack.catalyst_id, pack.stamp_net)

## ... nach Größe getönt (DataCellView.tier_shade); das Gold kennt keine Stufe.
static func card_shade(shelf: String, tier: int, catalyst_id := "",
		net: Array = []) -> Color:
	if catalyst_id == Pack.CATALYST_REPAIR:
		return REPAIR_TINT
	return DataCellView.tier_shade(tint_of(shelf, catalyst_id, net), tier)

## Der EINE Anzeige-Maßstab einer Kassette - ÜBERALL (Welle L). 3,2 = das alte Maß
## 2,184 mal ~1,47 (Welle 29): genau VIER liegende Karten je Magazin-Reihe.
const CASSETTE_SCALE := 3.2

## Seitenverhältnis der Kassette (Höhe / Breite, 2 : 3): daraus folgt ihr LIEGENDER
## Fußabdruck aus dem gemeldeten STEHENDEN. EINE Quelle - WorkshopView liest sie mit.
const CARD_ASPECT := 1.5
## Der Anteil der LANE-Tiefe, den die FRONT-BLENDE des Tabletts am Bild-unteren
## Rand nimmt; die Karten liegen mittig in dem, was bleibt.
const FRONT_SHARE := 0.09
const LANES := 2
## Die zwei Lanes eines Tabletts: HINTEN ist Bild-oben (Welt +X), VORN Bild-unten.
const LANE_BACK := 0
const LANE_FRONT := 1
## Je SORTE ein Tablett (Pack.SHELF_ORDER - ein Test hält beide gleich).
const TRAYS := 4
const ROWS := TRAYS * LANES
## So viele Spalten zeigt das Fenster; der Streifen wächst, bis sie liegen.
const COLUMNS := 4
## Luft über COLUMNS hinaus, mit der die Mindestbreite rechnet (so fällt die Zählung
## sicher auf COLUMNS, nie eine Spur darunter).
const COLUMN_AIR := 0.3
## Ab so vielen Display-px Weg wird aus dem Druck ein Zug.
const DRAG_THRESHOLD := 8.0

## Die drei Zustände eines Tabletts (state_of): das GEWÄHLTE liegt in der Fläche,
## die darüber sind seitlich in die Grubenwand gefahren, die darunter liegen unter
## seiner Platte und sind darum unsichtbar.
const SHOWN := 0
const RETRACTED := 1
const BURIED := 2

## Die reine TABLETT-Rechnung. Eine REIHE ist Tablett mal Lane.
static func tray_of(row: int) -> int:
	return clampi(row, 0, ROWS - 1) / LANES

## Die LANE einer Reihe: 0 = hinten (Bild-oben, Welt +X), 1 = vorn.
static func lane_of(row: int) -> int:
	return clampi(row, 0, ROWS - 1) % LANES

## Die Reihe aus Tablett und Lane.
static func row_for(tray: int, lane: int) -> int:
	return clampi(tray, 0, TRAYS - 1) * LANES + clampi(lane, 0, LANES - 1)

## Die zwei Reihen eines Tabletts, hinten zuerst.
static func rows_of(tray: int) -> Array[int]:
	var first := clampi(tray, 0, TRAYS - 1) * LANES
	return [first, first + 1] as Array[int]

## Wo die Reihe steckt, wenn Tablett `selected` gewählt ist.
static func state_of(row: int, selected: int) -> int:
	var tray := tray_of(row)
	if tray == clampi(selected, 0, TRAYS - 1):
		return SHOWN
	return RETRACTED if tray < selected else BURIED

## Liegt sie damit in der Fläche?
static func shows_row(row: int, selected: int) -> bool:
	return state_of(row, selected) == SHOWN

## Platz k eines Tabletts: SPALTE k / 2 und LANE k % 2 - spaltenweise gefüllt, damit
## das Rollen ganze Spalten freilegt.
static func column_of_cell(cell: int) -> int:
	return maxi(cell, 0) / LANES

static func lane_of_cell(cell: int) -> int:
	return maxi(cell, 0) % LANES

## So viele Spalten belegt ein Tablett mit count Karten.
static func columns_used(count: int) -> int:
	return ceili(float(maxi(count, 0)) / float(LANES))

## Der Roll-Stand reicht von 0 bis max(0, Spalten - Fenster).
static func max_scroll(count: int, window: int = COLUMNS) -> int:
	return maxi(columns_used(count) - maxi(window, 1), 0)

static func clamp_scroll(scroll: int, count: int, window: int = COLUMNS) -> int:
	return clampi(scroll, 0, max_scroll(count, window))

## Wo das Tablett nach einem Zug um offset_px EINRASTET: die nächste ganze Spalte,
## in den Grenzen. Nach links gezogen (negativ) rollt es weiter.
static func snap_scroll(scroll: int, offset_px: float, slot_px: float, count: int,
		window: int = COLUMNS) -> int:
	if slot_px <= 0.0:
		return clamp_scroll(scroll, count, window)
	return clamp_scroll(scroll - roundi(offset_px / slot_px), count, window)

## Der EINE RAND der Grube: GLEICH GROSS an allen drei Kanten.
const LANE_GAP_PX := 28.0

## Greifluft quer zum Fußabdruck der LIEGENDEN Kassette und die TIEFE einer Reihe.
const CELL_SPAN := 1.15
const RANK_SPAN := 1.1
## Randluft im Platz.
const SLOT_INSET := 0.12
## Rückfall-Fußabdruck (Einheiten u), solange niemand die Welt-Projektion gemeldet
## hat: CELL_FALLBACK ist das TIEFE Maß (die Kartenbreite), CELL_FALLBACK_DEPTH
## sein Verhältnis zur schmalen Grifftiefe.
const CELL_FALLBACK := 7.5
const CELL_FALLBACK_DEPTH := 2.463

## Der gemalte RAHMEN um die Grube - Schatten oben, Licht unten.
const RIM_BASE := Color("#34313f")
const RIM_WIDTH := 0.45
const EDGE := 0.33
const RADIUS := 0.9
const WELL_SHADOW := Color(0.0, 0.0, 0.0, 0.72)
const WELL_SHEEN := Color(0.66, 0.64, 0.76, 0.4)
const LOCK_DIM := Color(0.55, 0.55, 0.6)

const EMPTY_TITLE := "Magazin"
const EMPTY_BODY := "Das Magazin ist leer."

## Gemeinsame Maßeinheit der Werkbank (setzt WorkshopView über build).
var u := 8.0
## Fußabdruck einer STEHENDEN Datenzelle in Display-Pixeln (Grifftiefe × Breite).
var cell_px := Vector2.ZERO
## Der Streifen, in dem das Fach liegt (= die eigene Größe, von build gemerkt).
var strip := Vector2.ZERO
## Das FELD darin: die Grube selbst (lokale Koordinaten).
var field := Rect2()
var _grid: Dictionary = {}
## uid -> Platzmitte in LOKALEN Pixeln, für ALLE Einträge - auch hinausgerollte und
## zurückgehaltene: ihr Platz wartet.
var _spots: Dictionary = {}
## uid -> REIHE des Stapels und SPALTE im Fenster (0 .. columns-1 liegt im Bild).
var _rows: Dictionary = {}
var _cols: Dictionary = {}
## uid -> Chip-Knopf (nur Einträge im Fenster des gewählten Tabletts).
var _chips: Dictionary = {}
var _count := 0
var _locked := false
## Das gewählte TABLETT und die Anker der TASTEN in Display-Pixeln.
var _tray := 0
var _keys: Array[Vector2] = []
## Der laufende ZUG: Startpunkt, ob er schon rollt, und ob der Knopf-Klick danach
## geschluckt wird (ein Zug ist kein Tipp).
var _press_x := 0.0
var _press_live := false
var _dragging := false
var _swallow_press := false

func _init() -> void:
	name = "PackDrawer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Baut das Fach neu: entries = [{uid, pack, withheld, tray, cell}] in Magazin-Ordnung,
## scrolls je Tablett der Roll-Stand in Spalten.
func build(entries: Array[Dictionary], unit: float, locked: bool,
		footprint := Vector2.ZERO, row := Vector2.ZERO, tray := 0,
		keys: Array[Vector2] = [], scrolls: Array[int] = []) -> void:
	u = maxf(unit, 1.0)
	_locked = locked
	strip = row if row.x > 0.0 and row.y > 0.0 else size
	cell_px = footprint if footprint.x > 0.0 and footprint.y > 0.0 else _fallback_cell()
	field = pit_rect_in(Rect2(Vector2.ZERO, strip), u)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_spots.clear()
	_rows.clear()
	_cols.clear()
	_chips.clear()
	_press_live = false
	_dragging = false
	_count = entries.size()
	_tray = clampi(tray, 0, TRAYS - 1)
	_keys = keys.duplicate()
	_grid = grid_for(field.size, cell_px, _count)
	var columns := maxi(int(_grid.get("columns", 1)), 1)
	add_child(_well())
	add_child(_well_catch())
	for i in entries.size():
		var uid := int(entries[i].get("uid", 0))
		var pack := entries[i].get("pack") as Pack
		var owner := int(entries[i].get("tray", Pack.shelf_rank(pack) if pack != null else 0))
		var cell_index := int(entries[i].get("cell", i))
		var scroll := scrolls[owner] if owner >= 0 and owner < scrolls.size() else 0
		var column := column_of_cell(cell_index) - scroll
		var lane := lane_of_cell(cell_index)
		# Der PLATZ gilt IMMER - auch hinausgerollt oder verdeckt liegt der Körper dort,
		# nur eben unter dem Filz. Nur der CHIP hängt am Fenster.
		var spot := field.position + spot_for(column, field.size, cell_px, lane)
		_spots[uid] = spot
		_rows[uid] = row_for(owner, lane)
		_cols[uid] = column
		if bool(entries[i].get("withheld", false)) or owner != _tray \
				or column < 0 or column >= columns:
			continue
		var chip := _chip(pack, uid, spot)
		if chip != null:
			add_child(chip)
			_chips[uid] = chip

## Der LIEGENDE Fußabdruck einer Kassette in Display-Pixeln, aus dem gemeldeten
## STEHENDEN gerechnet: quer liegt ihre LANGSEITE, in der Tiefe ihre Breite.
static func lie_cell(cell: Vector2) -> Vector2:
	return Vector2(cell.y * CARD_ASPECT, cell.y) * CASSETTE_SCALE

## Das gelöste Raster eines FELDES: {"columns", "scale"} - reine Funktion.
static func grid_for(field_size: Vector2, cell: Vector2, _count_now: int) -> Dictionary:
	return {"columns": _columns_at(field_size, cell), "scale": CASSETTE_SCALE}

## Wie viele Kassetten in ihrer festen Größe nebeneinander in die Grube liegen.
static func _columns_at(field_size: Vector2, cell: Vector2) -> int:
	var wide := lie_cell(cell).x * CELL_SPAN
	if field_size.x <= 0.0 or wide <= 0.0:
		return 1
	return maxi(int(field_size.x / wide), 1)

## Spalten im Fenster einer Reihe.
static func columns_for(field_size: Vector2, cell: Vector2, count: int) -> int:
	return int(grid_for(field_size, cell, count)["columns"])

## Die Mindestbreite der GRUBE, in der genau COLUMNS Karten liegen.
static func min_field_width(cell: Vector2) -> float:
	return lie_cell(cell).x * CELL_SPAN * (float(COLUMNS) + COLUMN_AIR)

## Die LANE-Geometrie EINER Grube, hinten zuerst: drei gleiche Ränder.
static func lane_rects(field_size: Vector2) -> Array[Rect2]:
	var deep := lane_depth(field_size)
	var rects: Array[Rect2] = []
	for lane in LANES:
		rects.append(Rect2(Vector2(0.0, LANE_GAP_PX + (deep + LANE_GAP_PX) * float(lane)),
			Vector2(field_size.x, deep)))
	return rects

## Die TIEFE einer Lane: was von der Grube bleibt, wenn die drei Ränder ab sind.
static func lane_depth(field_size: Vector2) -> float:
	return maxf((field_size.y - LANE_GAP_PX * float(LANES + 1)) / float(LANES), 1.0)

## Platzmitte einer SPALTE im Fenster (relativ zur Feldecke) - eine Spalte links oder
## rechts des Fensters liegt einfach außerhalb, unter dem Filz.
static func spot_for(column: int, field_size: Vector2, cell: Vector2,
		lane := LANE_BACK) -> Vector2:
	var slot := slot_size(field_size, cell)
	var lane_top := lane_rects(field_size)[clampi(lane, 0, LANES - 1)].position.y
	return Vector2(slot.x * (float(column) + 0.5), lane_top + slot.y * 0.5)

## Der PLATZ einer Spalte: die Feldbreite geteilt durch die Spalten im Fenster, in der
## Tiefe die LANE ohne die Blende.
static func slot_size(field_size: Vector2, cell: Vector2) -> Vector2:
	return Vector2(field_size.x / float(_columns_at(field_size, cell)),
		lane_depth(field_size) * (1.0 - FRONT_SHARE))

## Der GRIFF einer Kassette: ihr ganzer Platz abzüglich der Randluft.
static func grip_for(field_size: Vector2, cell: Vector2) -> Vector2:
	return slot_size(field_size, cell) * (1.0 - SLOT_INSET * 2.0)

## Die Grube selbst: das Rechteck INNERHALB des gemalten Rahmens.
static func pit_rect_in(row_rect: Rect2, unit: float) -> Rect2:
	var inset := rim_inset(unit)
	return row_rect.grow(-inset)

## Breite der gemalten Fassung (Rahmen plus Kantenband).
static func rim_inset(unit: float) -> float:
	return maxf(2.0, unit * RIM_WIDTH) + maxf(2.0, unit * EDGE)

func cell_scale() -> float:
	if _grid.has("scale"):
		return float(_grid["scale"])
	return CASSETTE_SCALE

static func cell_scale_for(_cell: Vector2, _field_size: Vector2, _count_now: int) -> float:
	return CASSETTE_SCALE

## Display-Pixel des PLATZES dieser uid ((-1,-1) = liegt nicht im Fach).
func pack_seat_px(uid: int) -> Vector2:
	if not _spots.has(uid):
		return Vector2(-1, -1)
	var spot: Vector2 = _spots[uid]
	return get_global_rect().position + spot

## Und wohin ihr Liefer-Licht fliegt: auf den Platz, wenn er im Fenster liegt; ist er
## hinausgerollt, an den Grubenrand seiner Seite; ist das Tablett verdeckt, an
## dessen TASTE - eine Maschine, die keiner sieht, hat nicht gespielt.
func pack_anchor_px(uid: int) -> Vector2:
	if not _spots.has(uid):
		return Vector2(-1, -1)
	if tray_of(int(_rows[uid])) != _tray:
		return key_px(tray_of(int(_rows[uid])))
	var column := int(_cols.get(uid, 0))
	var seat := pack_seat_px(uid)
	var origin := get_global_rect().position
	if column < 0:
		return Vector2(origin.x + field.position.x, seat.y)
	if column >= columns():
		return Vector2(origin.x + field.end.x, seat.y)
	return seat

## Die gemeldete TASTE eines Tabletts (ohne Leiste: die Fach-Mitte).
func key_px(tray: int) -> Vector2:
	var index := clampi(tray, 0, TRAYS - 1)
	if index < _keys.size() and _keys[index].x >= 0.0:
		return _keys[index]
	return get_global_rect().get_center()

## Die REIHE einer Kassette (-1 = liegt nicht im Fach).
func row_of_pack(uid: int) -> int:
	return int(_rows.get(uid, -1))

## Ihre SPALTE im Fenster (kann außerhalb liegen).
func column_of_pack(uid: int) -> int:
	return int(_cols.get(uid, 0))

## Spalten im Fenster.
func columns() -> int:
	return maxi(int(_grid.get("columns", 1)), 1)

## Liegt sie im FENSTER des gewählten Tabletts?
func shows_pack(uid: int) -> bool:
	if not _rows.has(uid) or tray_of(int(_rows[uid])) != _tray:
		return false
	var column := int(_cols.get(uid, 0))
	return column >= 0 and column < columns()

## Das gewählte Tablett.
func tray() -> int:
	return _tray

## Derselbe Platz, GERECHNET statt gemessen (Spalte im Fenster).
static func anchor_in(field_rect: Rect2, column: int,
		cell: Vector2, lane := LANE_BACK) -> Vector2:
	if field_rect.size.x <= 0.0 or field_rect.size.y <= 0.0:
		return Vector2(-1, -1)
	return field_rect.position + spot_for(column, field_rect.size, cell, lane)

## Der Chip einer uid (null = keiner).
func pack_button(uid: int) -> Button:
	var chip: Button = _chips.get(uid)
	return chip if chip != null and is_instance_valid(chip) else null

## Die Kassette unter der globalen Position (0 = keine).
func pack_at(global_point: Vector2) -> int:
	for uid: int in _chips:
		var chip: Button = _chips[uid]
		if is_instance_valid(chip) and chip.get_global_rect().has_point(global_point):
			return uid
	return 0

## Die Kassette unter dem Display-Pixel (0 = keine) - GEFRAGT, nicht gemeldet.
## Solange gerollt wird, greift der Zeiger nichts.
func hover_uid_at(pixel: Vector2) -> int:
	if not visible or _locked or _dragging:
		return 0
	return pack_at(pixel)

## Rollt gerade ein Zug?
func dragging() -> bool:
	return _dragging

## DER ZUG: gedrückt merkt den Punkt, gezogen über die Schwelle rollt das Tablett,
## losgelassen rastet es ein - und der Knopf-Klick danach wird geschluckt.
func _track_drag(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null:
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_press_x = click.global_position.x
			_press_live = true
			_dragging = false
			return
		if _dragging:
			_swallow_press = true
			_clear_swallow.call_deferred()
			# Gemeldet wird NACH dem Ereignis: der Neuaufbau nähme sonst dem Knopf, der
			# gerade sein Loslassen verarbeitet, den Baum unter den Füßen weg.
			scroll_released.emit.call_deferred(click.global_position.x - _press_x)
		_press_live = false
		_dragging = false
		return
	var motion := event as InputEventMouseMotion
	if motion == null or not _press_live:
		return
	if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		_press_live = false
		return
	var offset := motion.global_position.x - _press_x
	if not _dragging and absf(offset) >= DRAG_THRESHOLD:
		_dragging = true
	if _dragging:
		scroll_dragged.emit(offset)

func _clear_swallow() -> void:
	_swallow_press = false

## Name und Wirkung dessen, was unter pixel liegt ({} = nichts).
func hint_at(pixel: Vector2) -> Dictionary:
	if not visible:
		return {}
	for uid: int in _chips:
		var chip: Button = _chips[uid]
		if not is_instance_valid(chip) or not chip.has_meta("title"):
			continue
		if not chip.get_global_rect().has_point(pixel):
			continue
		return {"title": String(chip.get_meta("title", "")),
			"body": String(chip.get_meta("body", ""))}
	if get_global_rect().has_point(pixel):
		return {"title": EMPTY_TITLE, "body": EMPTY_BODY, "stock": true}
	return {}

## Eine gemalte Kante: Lichtband oben ODER Schattenband unten.
static func edge_band(band_name: String, tint: Color, edge: int, radius: int,
		top: bool) -> Panel:
	var band := Panel.new()
	band.name = band_name
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = tint
	if top:
		box.border_width_top = edge
	else:
		box.border_width_bottom = edge
	box.set_corner_radius_all(radius)
	band.add_theme_stylebox_override("panel", box)
	return band

func _fallback_cell() -> Vector2:
	return fallback_cell(u)

static func fallback_cell(unit: float) -> Vector2:
	var deep := unit * CELL_FALLBACK * 2.0 / 3.0
	return Vector2(deep / CELL_FALLBACK_DEPTH, deep)

## Die FASSUNG der Grube; ihre Mitte ist ein echtes Loch.
func _well() -> Panel:
	var well := Panel.new()
	well.name = "DrawerWell"
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var radius := int(u * RADIUS)
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = RIM_BASE
	box.set_border_width_all(maxi(2, int(u * RIM_WIDTH)))
	box.set_corner_radius_all(radius)
	well.add_theme_stylebox_override("panel", box)
	var edge := maxi(2, int(u * EDGE))
	well.add_child(edge_band("WellShade", WELL_SHADOW, edge, radius, true))
	well.add_child(edge_band("WellSheen", WELL_SHEEN, edge, radius, false))
	well.modulate = LOCK_DIM if _locked else Color.WHITE
	return well

## Der unsichtbare Fang der Fach-Fläche: ein Doppelklick räumt auf, ein Zug rollt.
## Als KNOPF, damit die Werkbank-Nahsicht hier nicht mitzündet.
func _well_catch() -> Button:
	var catch := Button.new()
	catch.name = "WellCatch"
	catch.focus_mode = Control.FOCUS_NONE
	catch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		catch.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	catch.gui_input.connect(_on_well_input)
	return catch

func _on_well_input(event: InputEvent) -> void:
	_track_drag(event)
	var click := event as InputEventMouseButton
	if _locked or click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if click.pressed and click.double_click:
		tidy_requested.emit()

## Der unsichtbare Griff einer Kassette: er zeichnet NICHTS - das Greifen zeigt die
## Kassette selbst. Getippt wählt sie, gezogen rollt das Tablett.
func _chip(pack: Pack, uid: int, spot: Vector2) -> Button:
	if pack == null:
		return null
	var chip := Button.new()
	chip.name = "PackCell"
	chip.focus_mode = Control.FOCUS_NONE
	var grip := grip_for(field.size, cell_px)
	chip.size = grip
	chip.position = spot - grip * 0.5
	chip.disabled = _locked
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		chip.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var title := pack.display_name if pack.count <= 1 \
		else "%d× %s" % [pack.count, pack.display_name]
	var body := pack.description
	var net := Pack.net_line(pack)
	if net != "" and not body.contains(net):
		body = "%s\n%s" % [body, net]
	chip.set_meta("title", title)
	chip.set_meta("body", body)
	chip.tooltip_text = "%s\n%s" % [title, body]
	if not _locked:
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.pressed.connect(func() -> void:
		if not _swallow_press:
			pack_pressed.emit(uid))
	chip.gui_input.connect(_track_drag)
	return chip
