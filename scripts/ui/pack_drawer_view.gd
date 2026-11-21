class_name PackDrawerView
extends Control
## Das MAGAZIN der Werkbank: VIER TRAYS nebeneinander unter der Walze, einer je SORTE
## (Pack.SHELF_ORDER), jeder mit eigener Grube und Fassung, dazwischen echter Filz. Jeder
## Tray ist EIN durchgehendes Regal aus REIHEN zu ACROSS Karten - Rang k liegt in Reihe
## k / ACROSS auf Querplatz k % ACROSS - und ROLLT für sich in ganzen Reihen; das Fenster
## zeigt je Tray PLACES Reihen, rechts daneben läuft die ROLLSCHIENE, unten die LICHTLEISTE.
## Die Karten LIEGEN flach, Netz nach oben; ShelfStackView baut Trays und fährt die Körper,
## diese Klasse rechnet die Rechtecke - die reine Rechnung wohnt hier, damit table/ sie
## liest statt umgekehrt.
## Die Karte hat ihr FESTES Maß (CASSETTE_SCALE); unbegrenzt ist der Bestand. Eine
## hinausgerollte Karte hat keinen Chip, ihr Liefer-Licht endet am Rand ihres Trays.
## Die Gruben sind echt (screen_glass, table_ground, PackPitView); gemalt wird hier nichts,
## diese Klasse trägt nur die Gesten: getippt wählt, gezogen rollt.
## Reiner Renderer: was liegt, was reserviert ist und was noch fliegt, entscheidet
## WorkshopView (drawer_entries).

## Eine Kassette wurde angetippt: sie wandert auf die nächste freie Scheibe.
signal pack_pressed(uid: int)
## Doppelklick auf leere Fach-Fläche: das Magazin soll sich aufräumen.
signal tidy_requested
## Ein ZUG über Spalte column: so weit (Display-px, Bild-unten positiv) ist der Zeiger
## seit dem Druck.
signal scroll_dragged(column: int, offset_px: float)
## Der Zug ist losgelassen - die Spalte soll auf einen ganzen Platz einrasten.
signal scroll_released(column: int, offset_px: float)

const GOLD := Color("#ffd319")

## Sorten-Farben - Schlüssel sind Pack.SHELF_ORDER: die Taxonomie wohnt in data/,
## die Farben hier (Rune.tint-Regel: data importiert nie ui).
const COLORS := {
	Engraving.CATEGORY_NUMBER: Color("#50fa7b"),
	Engraving.CATEGORY_MATERIAL: Color("#ff79c6"),
	Engraving.CATEGORY_DICE: Color("#ffd319"),
	Pack.SHELF_SPECIAL: Color("#bd93f9"),
}

## Das MULTIPLIKATOR-NETZ trägt LILA ("episch") statt Zahlen-Grün - tiefer und
## satter als das Lavendel des Sonderbestands. Die Größe stuft es wie jede Sorte.
const MULTIPLIER_TINT := Color("#9a4dff")

## Der ROHLING und die verdichtete Karte: ein kühles Stahlblau - sie gehören keiner
## Sorte, denn ihr Inhalt kommt aus mehreren.
const BLANK_TINT := Color("#5fa8c8")

## Die Farbe einer Kassette - die Sortenfarbe, der Rohling
## stahlblau, ein Netz mit Faktor-Zellen lila.
static func tint_of(shelf: String, catalyst_id := "", net: Array = [],
		blank := false) -> Color:
	if blank:
		return BLANK_TINT
	if catalyst_id == "" and StampNet.is_factor_net(net):
		return MULTIPLIER_TINT
	return COLORS.get(shelf, GOLD)

## Die Farbe eines PAKETS (CardPack-Sorte): die Sortenfarbe seiner Karten.
static func card_pack_tint(card_pack_sort: String) -> Color:
	if not CardPack.SORT_TYPES.has(card_pack_sort):
		return COLORS[Pack.SHELF_SPECIAL]
	var pack_type := String(CardPack.SORT_TYPES[card_pack_sort])
	return COLORS.get(Pack.shelf_for_pack_type(pack_type), GOLD)

## Die WÜRFEL-PAKETE: die Farbe ihrer BANDEROLE (Material und Runen wie ihre Karten);
## das normale Paket trägt keine, sein neutraler Stahlton färbt nur Naht und Hover.
const DICE_PACK_TINTS := {
	DicePack.SORT_NORMAL: Color("#9aa6ba"),
	DicePack.SORT_SOUL: Color("#a66bff"),
	# Material und Runen tragen die Farben ihrer Karten: eine Farbe meint überall dieselbe Sorte.
	DicePack.SORT_MATERIAL: COLORS[Engraving.CATEGORY_MATERIAL],
	DicePack.SORT_RUNE: COLORS[Engraving.CATEGORY_DICE],
}

static func dice_pack_tint(dice_pack_sort: String) -> Color:
	return DICE_PACK_TINTS.get(dice_pack_sort, DICE_PACK_TINTS[DicePack.SORT_NORMAL])

static func pack_tint(pack: Pack) -> Color:
	if pack == null:
		return GOLD
	return tint_of(Pack.shelf_of(pack), pack.catalyst_id, pack.stamp_net, pack.from_blank())

## ... nach Größe getönt (DataCellView.tier_shade); Stahlblau kennt keine
## Stufe - seine Karten sind GRÖSSENLOS, und die Entsättigung wüsche ihren Ton zu Grau.
static func card_shade(shelf: String, tier: int, catalyst_id := "",
		net: Array = [], blank := false) -> Color:
	if blank:
		return BLANK_TINT
	return DataCellView.tier_shade(tint_of(shelf, catalyst_id, net, blank), tier)

## Der EINE Anzeige-Maßstab einer Kassette - ÜBERALL (Welle L).
const CASSETTE_SCALE := 3.2

## Seitenverhältnis der Kassette (Höhe / Breite, 2 : 3): daraus folgt ihr LIEGENDER
## Fußabdruck aus dem gemeldeten STEHENDEN. EINE Quelle - WorkshopView liest sie mit.
const CARD_ASPECT := 1.5
## Je SORTE ein Tray (Pack.SHELF_ORDER - ein Test hält beide gleich).
const COLUMNS := 4
## So viele Karten liegen in einem Tray NEBENEINANDER (Layout C).
const ACROSS := 2
## So viele REIHEN zeigt das Fenster je Tray.
const PLACES := 2
## Quer je Karte ihr Platz samt Luft und rechts die ROLLSCHIENE, in Kartenlängen.
const CARD_ROOM := 1.06
const RAIL_ROOM := 0.1
## Der Anteil der Grubenbreite, den die Rollschiene rechts nimmt.
const RAIL_SHARE := RAIL_ROOM / (RAIL_ROOM + CARD_ROOM * ACROSS)
## Längs je Reihe die Karte samt Luft (eigenes Maß - CELL_SPAN gehört dem Schwarzmarkt).
const ROW_SPAN := 1.10
## Luft über PLACES hinaus, mit der die Feldhöhe rechnet (so fällt die Zählung
## sicher auf PLACES, nie eine Spur darunter).
const PLACE_AIR := 0.01
## Die FASSUNG eines Trays (Display-px): links, rechts und oben schmal, unten das Band
## der LICHTLEISTE; zwischen zwei Trays liegt FELT_GAP_PX echter Filz.
const FRAME_PX := 8.0
const BAR_PX := 34.0
const FELT_GAP_PX := 12.0
const TRAY_GAP_PX := FRAME_PX * 2.0 + FELT_GAP_PX
## Die Ecken jedes Lochs, je Gerät (Display-px): das Deck rund, das Steinbett weich.
const PIT_RADII: Array[float] = [1.5, 5.0, 6.0, 2.0]
## Die Namen der Lichtleisten.
const BAR_NAMES := {
	Engraving.CATEGORY_NUMBER: "Zahl",
	Engraving.CATEGORY_MATERIAL: "Material",
	Engraving.CATEGORY_DICE: "Rune",
	Pack.SHELF_SPECIAL: "Sonder",
}
## Ab so vielen Display-px Weg wird aus dem Druck ein Zug.
const DRAG_THRESHOLD := 8.0
## Der Schieber wird sofort gegriffen.
const RAIL_THRESHOLD := 2.0

## Wo eine Spalte RASTEN darf (in Reihen): 0 bis zur Stellung, in der ihre letzte Reihe
## am unteren Fensterrand steht (leer: nur 0). count zählt Karten, window Reihen. GEZOGEN
## wird beliebig weit - beim Loslassen federt sie hierher zurück.
static func max_scroll(count: int, window: int = PLACES) -> int:
	return maxi(rows_for(count) - maxi(window, 1), 0)

## Wie viele Reihen so viele Karten belegen.
static func rows_for(count: int) -> int:
	return ceili(float(maxi(count, 0)) / float(ACROSS))

## Reihe und Querplatz eines Rangs (auch negativ: über dem Fenster).
static func row_of(rank: int) -> int:
	return floori(float(rank) / float(ACROSS))

static func across_of(rank: int) -> int:
	return posmod(rank, ACROSS)

static func clamp_scroll(scroll: int, count: int, window: int = PLACES) -> int:
	return clampi(scroll, 0, max_scroll(count, window))

## Wo die Spalte nach einem Zug um offset_px EINRASTET: die nächste ganze Reihe, in
## den Grenzen. Nach oben gezogen (negativ) rollt sie weiter.
static func snap_scroll(scroll: int, offset_px: float, slot_px: float, count: int,
		window: int = PLACES) -> int:
	if slot_px <= 0.0:
		return clamp_scroll(scroll, count, window)
	return clamp_scroll(scroll - roundi(offset_px / slot_px), count, window)

## Der SCHIEBER der Rollschiene als Anteile ihrer Länge (x = Anfang oben, y = Länge):
## so lang wie sichtbare durch alle Reihen, so weit unten wie gerollt. scroll darf
## gebrochen sein (ein laufender Zug) - er bleibt trotzdem ganz in der Schiene.
static func rail_thumb(total_rows: int, window_rows: int, scroll: float) -> Vector2:
	var whole := float(maxi(maxi(total_rows, window_rows), 1))
	var length := clampf(float(maxi(window_rows, 1)) / whole, 0.0, 1.0)
	return Vector2(clampf(scroll / whole, 0.0, 1.0 - length), length)

## Die Aufschrift der Lichtleiste: Name und Gesamtzahl.
static func bar_text(column: int, total: int) -> String:
	var shelf := String(Pack.SHELF_ORDER[clampi(column, 0, COLUMNS - 1)])
	var label := String(BAR_NAMES.get(shelf, Pack.shelf_short(shelf)))
	return "%s %d" % [label, maxi(total, 0)]

## Liegt die Feld-Breite x auf der ROLLSCHIENE ihres Trays? Der Griff reicht eine
## Schienenbreite in die Grube und über die Fassung daneben.
static func on_rail(field_size: Vector2, x: float) -> bool:
	var pit := column_rects(field_size)[column_at(field_size, x)]
	return x >= pit.end.x - rail_width(field_size) * 2.0 and x <= pit.end.x + FRAME_PX

## Der Zug am SCHIEBER als Roll-Versatz des Trays: der Schieber folgt dem Zeiger, also
## rollt der Inhalt um Reihen/Fenster schneller und gegenläufig - nie über die Enden.
static func rail_drag(dy: float, count: int, scroll: int, slot_px: float,
		window: int = PLACES) -> float:
	var rows := maxi(rows_for(count), maxi(window, 1))
	var up := float(clamp_scroll(scroll, count, window)) * slot_px
	var down := float(max_scroll(count, window)) * slot_px - up
	return clampf(-dy * float(rows) / float(maxi(window, 1)), -down, up)

## Greifluft längs der Spalte des SCHWARZMARKTS (die Kartenbreite).
const CELL_SPAN := 1.15
## Randluft im Platz.
const SLOT_INSET := 0.12
## Rückfall-Fußabdruck (Einheiten u), solange niemand die Welt-Projektion gemeldet
## hat: CELL_FALLBACK ist das TIEFE Maß (die Kartenbreite), CELL_FALLBACK_DEPTH
## sein Verhältnis zur schmalen Grifftiefe.
const CELL_FALLBACK := 7.5
const CELL_FALLBACK_DEPTH := 2.463

## Der gemalte RAHMEN einer Grube - Schatten oben, Licht unten (der Schwarzmarkt malt ihn;
## das Magazin trägt seit den Trays körperliche Fassungen).
const RIM_BASE := Color("#34313f")
const RIM_WIDTH := 0.45
const EDGE := 0.33
const RADIUS := 0.9
const WELL_SHADOW := Color(0.0, 0.0, 0.0, 0.72)
const WELL_SHEEN := Color(0.66, 0.64, 0.76, 0.4)

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
## uid -> Platzmitte in LOKALEN Pixeln, für ALLE Einträge - auch hinausgerollte und
## zurückgehaltene: ihr Platz wartet.
var _spots: Dictionary = {}
## uid -> SPALTE und PLATZ im Fenster (0 .. PLACES-1 liegt im Bild).
var _columns: Dictionary = {}
var _places: Dictionary = {}
## uid -> Chip-Knopf (nur Einträge im Fenster).
var _chips: Dictionary = {}
var _locked := false
## Der laufende ZUG: Spalte und Startpunkt, ob er schon rollt, und ob der Knopf-Klick
## danach geschluckt wird (ein Zug ist kein Tipp).
var _press_column := 0
var _press_y := 0.0
var _press_live := false
## Greift der Zug den SCHIEBER der Rollschiene? Dazu Kartenzahl und Roll-Stand je Tray.
var _press_rail := false
var _counts: Array[int] = []
var _scrolls: Array[int] = []
var _dragging := false
var _swallow_press := false

func _init() -> void:
	name = "PackDrawer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Baut das Fach neu: entries = [{uid, pack, withheld, column, cell}] in Magazin-Ordnung,
## scrolls je Spalte der Roll-Stand in Plätzen.
func build(entries: Array[Dictionary], unit: float, locked: bool,
		footprint := Vector2.ZERO, strip_size := Vector2.ZERO,
		scrolls: Array[int] = []) -> void:
	u = maxf(unit, 1.0)
	_locked = locked
	strip = strip_size if strip_size.x > 0.0 and strip_size.y > 0.0 else size
	cell_px = footprint if footprint.x > 0.0 and footprint.y > 0.0 else _fallback_cell()
	field = field_in(Rect2(Vector2.ZERO, strip))
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_spots.clear()
	_columns.clear()
	_places.clear()
	_chips.clear()
	_press_live = false
	_dragging = false
	_scrolls = scrolls.duplicate()
	_counts.assign([0, 0, 0, 0])
	for entry in entries:
		var at := clampi(int(entry.get("column", 0)), 0, COLUMNS - 1)
		_counts[at] = maxi(_counts[at], int(entry.get("cell", 0)) + 1)
	var shown := window_cards()
	add_child(_well_catch())
	for i in entries.size():
		var uid := int(entries[i].get("uid", 0))
		var pack := entries[i].get("pack") as Pack
		var column := clampi(int(entries[i].get("column",
			Pack.shelf_rank(pack) if pack != null else 0)), 0, COLUMNS - 1)
		var scroll := scrolls[column] if column < scrolls.size() else 0
		var place := int(entries[i].get("cell", i)) - scroll * ACROSS
		# Der PLATZ gilt IMMER - auch hinausgerollt liegt der Körper dort, nur eben
		# unter dem Filz. Nur der CHIP hängt am Fenster.
		var spot := field.position + spot_for(place, field.size, cell_px, column)
		_spots[uid] = spot
		_columns[uid] = column
		_places[uid] = place
		if bool(entries[i].get("withheld", false)) or place < 0 or place >= shown:
			continue
		var chip := _chip(pack, uid, spot)
		if chip != null:
			add_child(chip)
			_chips[uid] = chip

## Der LIEGENDE Fußabdruck einer Kassette in Display-Pixeln, aus dem gemeldeten
## STEHENDEN gerechnet: quer liegt ihre LANGSEITE, in der Tiefe ihre Breite.
static func lie_cell(cell: Vector2) -> Vector2:
	return Vector2(cell.y * CARD_ASPECT, cell.y) * CASSETTE_SCALE

## Das FELD für eine LIEGENDE Karte: die Vereinigung der vier GRUBEN (je ACROSS Plätze
## samt Rollschiene, dazwischen Fassung, Filz, Fassung), PLACES Reihen samt Luft.
static func field_for(card: Vector2) -> Vector2:
	return Vector2(pit_width_for(card) * float(COLUMNS) + TRAY_GAP_PX * float(COLUMNS - 1),
		card.y * ROW_SPAN * (float(PLACES) + PLACE_AIR))

## Die Breite EINER Grube: ACROSS Plätze und die Rollschiene.
static func pit_width_for(card: Vector2) -> float:
	return card.x * (CARD_ROOM * float(ACROSS) + RAIL_ROOM)

## Das ganze MAGAZIN: das Feld samt der Fassungen links, rechts, oben und dem
## Leisten-Band unten.
static func shelf_for(card: Vector2) -> Vector2:
	return field_for(card) + Vector2(FRAME_PX * 2.0, FRAME_PX + BAR_PX)

## Das Feld im Magazin-Rechteck (die Umkehrung von shelf_for).
static func field_in(shelf: Rect2) -> Rect2:
	return Rect2(shelf.position + Vector2(FRAME_PX, FRAME_PX),
		shelf.size - Vector2(FRAME_PX * 2.0, FRAME_PX + BAR_PX))

## Wie viele Kassetten in ihrer festen Größe untereinander in die Grube liegen.
static func _places_at(field_size: Vector2, cell: Vector2) -> int:
	var high := lie_cell(cell).y * ROW_SPAN
	if field_size.y <= 0.0 or high <= 0.0:
		return 1
	return maxi(int(field_size.y / high), 1)

## REIHEN im Fenster eines Trays.
static func places_for(field_size: Vector2, cell: Vector2) -> int:
	return _places_at(field_size, cell)

## KARTEN im Fenster eines Trays.
static func window_cards_for(field_size: Vector2, cell: Vector2) -> int:
	return _places_at(field_size, cell) * ACROSS

## Die GRUBEN der Trays im Feld, links zuerst: dazwischen je TRAY_GAP_PX.
static func column_rects(field_size: Vector2) -> Array[Rect2]:
	var wide := column_width(field_size)
	var rects: Array[Rect2] = []
	for column in COLUMNS:
		rects.append(Rect2(Vector2((wide + TRAY_GAP_PX) * float(column), 0.0),
			Vector2(wide, field_size.y)))
	return rects

## Die TRAYS samt Fassung (dieselben Koordinaten wie die Gruben).
static func tray_rects(field_size: Vector2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for pit in column_rects(field_size):
		rects.append(tray_of(pit))
	return rects

## Ein Tray um seine Grube: Fassung links, rechts und oben, unten das Leisten-Band.
static func tray_of(pit: Rect2) -> Rect2:
	return pit.grow_individual(FRAME_PX, FRAME_PX, FRAME_PX, BAR_PX)

## Die BREITE einer Grube: was vom Feld bleibt, wenn die Fugen ab sind.
static func column_width(field_size: Vector2) -> float:
	return maxf((field_size.x - TRAY_GAP_PX * float(COLUMNS - 1)) / float(COLUMNS), 1.0)

## Der Tray unter einer Feld-Breite (lokal zum Feld): die Grenzen liegen mitten im Filz,
## also gehört jeder Punkt des Magazins einem Tray.
static func column_at(field_size: Vector2, x: float) -> int:
	var pitch := column_width(field_size) + TRAY_GAP_PX
	return clampi(int(floorf((x + TRAY_GAP_PX * 0.5) / pitch)), 0, COLUMNS - 1)

## Platzmitte eines PLATZES im Fenster (Rang ab dem obersten sichtbaren, relativ zur
## Feldecke): Reihe place / ACROSS, Querplatz place % ACROSS - ein Platz über oder unter
## dem Fenster liegt einfach außerhalb, unter dem Filz.
static func spot_for(place: int, field_size: Vector2, cell: Vector2, column := 0) -> Vector2:
	var slot := slot_size(field_size, cell)
	var left := column_rects(field_size)[clampi(column, 0, COLUMNS - 1)].position.x
	return Vector2(left + slot.x * (float(across_of(place)) + 0.5),
		slot.y * (float(row_of(place)) + 0.5))

## Die ROLLSCHIENE rechts in der Grube eines Trays.
static func rail_width(field_size: Vector2) -> float:
	return column_width(field_size) * RAIL_SHARE

## Der PLATZ einer Karte: in der Breite ein ACROSS-tel der Grube ohne die Schiene, in der
## Höhe die Feldhöhe geteilt durch die Reihen im Fenster.
static func slot_size(field_size: Vector2, cell: Vector2) -> Vector2:
	return Vector2(column_width(field_size) * (1.0 - RAIL_SHARE) / float(ACROSS),
		field_size.y / float(_places_at(field_size, cell)))

## Der GRIFF einer Kassette: ihr ganzer Platz abzüglich der Randluft.
static func grip_for(field_size: Vector2, cell: Vector2) -> Vector2:
	return slot_size(field_size, cell) * (1.0 - SLOT_INSET * 2.0)

## Eine gemalte Grube (Schwarzmarkt): das Rechteck INNERHALB des Rahmens.
static func pit_rect_in(rect: Rect2, unit: float) -> Rect2:
	var inset := rim_inset(unit)
	return rect.grow(-inset)

## Breite der gemalten Fassung (Rahmen plus Kantenband).
static func rim_inset(unit: float) -> float:
	return maxf(2.0, unit * RIM_WIDTH) + maxf(2.0, unit * EDGE)

func cell_scale() -> float:
	return CASSETTE_SCALE

## KENNT das Fach den Platz dieser Karte? Ein Platz darf LEGITIM negativ sein (weit
## hinausgerollt liegt er über der Anzeige) - ein Koordinaten-Test taugt nicht.
func knows_pack(uid: int) -> bool:
	return _spots.has(uid)

## Display-Pixel des PLATZES dieser uid ((-1,-1) = liegt nicht im Fach).
func pack_seat_px(uid: int) -> Vector2:
	if not _spots.has(uid):
		return Vector2(-1, -1)
	var spot: Vector2 = _spots[uid]
	return get_global_rect().position + spot

## Und wohin ihr Liefer-Licht fliegt: auf den Platz, wenn er im Fenster liegt; ist er
## hinausgerollt, an den Rand ihrer Spalte auf dieser Seite.
func pack_anchor_px(uid: int) -> Vector2:
	if not _spots.has(uid):
		return Vector2(-1, -1)
	var place := int(_places.get(uid, 0))
	var seat := pack_seat_px(uid)
	var origin := get_global_rect().position
	if place < 0:
		return Vector2(seat.x, origin.y + field.position.y)
	if place >= window_cards():
		return Vector2(seat.x, origin.y + field.end.y)
	return seat

## Die SPALTE (= Sorte) einer Kassette (-1 = liegt nicht im Fach).
func column_of_pack(uid: int) -> int:
	return int(_columns.get(uid, -1))

## Ihr PLATZ im Fenster (kann außerhalb liegen).
func place_of_pack(uid: int) -> int:
	return int(_places.get(uid, 0))

## Reihen im Fenster.
func places() -> int:
	return places_for(field.size, cell_px)

## Karten im Fenster einer Spalte.
func window_cards() -> int:
	return places() * ACROSS

## Liegt sie im FENSTER ihrer Spalte?
func shows_pack(uid: int) -> bool:
	if not _columns.has(uid):
		return false
	var place := int(_places.get(uid, 0))
	return place >= 0 and place < window_cards()

## Derselbe Platz, GERECHNET statt gemessen (Platz im Fenster).
static func anchor_in(field_rect: Rect2, place: int, cell: Vector2, column := 0) -> Vector2:
	if field_rect.size.x <= 0.0 or field_rect.size.y <= 0.0:
		return Vector2(-1, -1)
	return field_rect.position + spot_for(place, field_rect.size, cell, column)

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

## DER ZUG: gedrückt merkt Punkt und Spalte, gezogen über die Schwelle rollt die Spalte,
## losgelassen rastet sie ein - und der Knopf-Klick danach wird geschluckt.
func _track_drag(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null:
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_press_y = click.global_position.y
			var at := click.global_position.x - get_global_rect().position.x - field.position.x
			_press_column = column_at(field.size, at)
			_press_rail = on_rail(field.size, at)
			_press_live = true
			_dragging = false
			return
		if _dragging:
			_swallow_press = true
			_clear_swallow.call_deferred()
			# Gemeldet wird NACH dem Ereignis: der Neuaufbau nähme sonst dem Knopf, der
			# gerade sein Loslassen verarbeitet, den Baum unter den Füßen weg.
			scroll_released.emit.call_deferred(_press_column,
				_drag_offset(click.global_position.y - _press_y))
		_press_live = false
		_dragging = false
		return
	var motion := event as InputEventMouseMotion
	if motion == null or not _press_live:
		return
	if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		_press_live = false
		return
	var offset := motion.global_position.y - _press_y
	if not _dragging and absf(offset) >= (RAIL_THRESHOLD if _press_rail else DRAG_THRESHOLD):
		_dragging = true
	if _dragging:
		scroll_dragged.emit(_press_column, _drag_offset(offset))

## Der Roll-Versatz eines Zeigerwegs: über den Karten 1:1, am Schieber übersetzt.
func _drag_offset(dy: float) -> float:
	if not _press_rail:
		return dy
	var scroll := _scrolls[_press_column] if _press_column < _scrolls.size() else 0
	var count := _counts[_press_column] if _press_column < _counts.size() else 0
	return rail_drag(dy, count, scroll, slot_size(field.size, cell_px).y,
		places_for(field.size, cell_px))

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

## Der unsichtbare Fang der Fach-Fläche: ein Doppelklick räumt auf, ein Zug rollt.
## Als KNOPF, damit die Werkbank-Nahsicht hier nicht mitzündet.
func _well_catch() -> Button:
	var catch := Button.new()
	catch.name = "WellCatch"
	catch.set_meta(&"sfx_silent", true)  # unsichtbarer Fang
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
## Kassette selbst. Getippt wählt sie, gezogen rollt die Spalte.
func _chip(pack: Pack, uid: int, spot: Vector2) -> Button:
	if pack == null:
		return null
	var chip := Button.new()
	chip.name = "PackCell"
	chip.set_meta(&"sfx_silent", true)  # die Karte klingt selbst
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
