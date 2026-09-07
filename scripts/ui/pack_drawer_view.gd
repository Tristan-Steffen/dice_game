class_name PackDrawerView
extends Control
## Das MAGAZIN der Werkbank: EINE durchgehende GRUBE in der Schürze - und seit dem
## 2026-09-07 ein PATERNOSTER mit ZEHN REIHEN, von denen ZWEI zugleich in der Fläche
## liegen (die HINTERE in der oberen Hälfte der Grube, die VORDERE in der unteren).
## Die Karten LIEGEN flach, Netz nach oben (lesbar ohne Hover), in EINER Reihe je
## Kreislauf-Reihe; PaternosterView fährt die Körper, diese Klasse rechnet die Plätze.
## Die Karte hat ihr FESTES Maß (CASSETTE_SCALE): eine Reihe fasst, was in ihrer
## Breite Platz hat, alles Weitere liegt auf der nächsten Reihe.
## Eine Kassette SCHRUMPFT NIE - was nicht mehr hineinpasst, kommt gar nicht erst
## herein: capacity_for misst den Deckel an Reihe mal ROWS, GameRun bekommt ihn
## hereingeschoben und sperrt Kauf wie Prämie daran.
## Eine Karte auf einer PARKENDEN Reihe hat keinen Chip und keinen Anker im Feld:
## ihr Liefer-Licht endet am HEBEL (der Anker wird von scene_root gemeldet).
## Die Grube ist echt: screen_glass verwirft sein Bild darin, table_ground seinen
## Filz, und PackPitView stellt Wände und Boden. Diese Klasse malt nur noch die
## FASSUNG darum herum und trägt die Gesten. Sie ist die EINZIGE Grube des Tisches -
## die Verkaufs-Auslagen stehen flächig darauf.
## Die Reihenfolge ist die Magazin-Ordnung des Spielers (run.owned_packs); eine
## Lieferung landet hinten und verrückt nichts.
## Chip-Schalen-Regel: je Paket ein leerer Knopf (StyleBoxEmpty in jedem Zustand),
## der KÖRPER steht als DataCellView in der Grube (scene_root). Gegriffen wird
## nicht durch einen gemalten Schein - der läge unter dem Loch -, sondern indem
## sich die Kassette selbst ein Stück herauszieht.
## Reiner Renderer: was liegt, was reserviert ist und was noch fliegt, entscheidet
## WorkshopView (drawer_entries).

## Eine Kassette wurde angetippt: Gravur-Pakete wandern in den nächsten freien
## Presse-Platz, Würfel-Pakete öffnen ihre Wahl.
signal pack_pressed(uid: int)
## Kassette auf Kassette gezogen: from soll an tos Platz rücken (remove/insert,
## die Reihe schließt sich - dieselbe Semantik wie reorder_pool).
signal packs_reordered(from_uid: int, to_uid: int)
## Doppelklick auf leere Fach-Fläche: das Magazin soll sich aufräumen.
signal tidy_requested
## Kassette auf einen LEEREN Platz einer liegenden Reihe gezogen: sie soll sich
## hinten an diese Reihe hängen (volle Reihe verweigert der Lauf).
signal pack_placed(uid: int, row: int)

const GOLD := Color("#ffd319")

## Sorten-Farben - Schlüssel sind Pack.SHELF_ORDER: die Taxonomie wohnt in data/,
## die Farben hier (Rune.tint-Regel: data importiert nie ui).
const COLORS := {
	Engraving.CATEGORY_NUMBER: Color("#50fa7b"),
	Engraving.CATEGORY_MATERIAL: Color("#ff79c6"),
	Engraving.CATEGORY_DICE: Color("#ffd319"),
	Pack.SHELF_SPECIAL: Color("#bd93f9"),
}

## Der EINE Anzeige-Maßstab einer Kassette - ÜBERALL (Welle L): Magazin,
## Schacht-Reihe, Laden-Vitrine, Schwarzmarkt, Wett-Gewinn, geworfener Einsatz,
## Auszahlungs-Ablage. Es gibt keinen kontext-eigenen Maßstab mehr; wer eine Karte
## stellt, stellt sie in diesem Maß. 2,184 = das alte Magazin-Maß 1,4 plus 30 %
## plus noch einmal 20 % (Spieler-Entscheide 2026-09-04: die Schrift blieb zu klein).
const CASSETTE_SCALE := 2.184

## Die REIHEN des Paternoster-Kreislaufs: zehn Tabletts, EINE Karten-Reihe je
## Tablett, zwei davon zugleich sichtbar. Der Deckel ist Reihe mal ROWS. Die Zahl
## wohnt im Lauf (die Reihe ist Spielstand), ui liest sie von dort.
const ROWS := GameRun.PACK_ROWS
## Seitenverhältnis der Kassette (Höhe / Breite, 2 : 3): daraus folgt ihr LIEGENDER
## Fußabdruck aus dem gemeldeten STEHENDEN. EINE Quelle - WorkshopView liest sie mit.
const CARD_ASPECT := 1.5
## Der Anteil der LANE-Tiefe, den die FRONT-BLENDE des Tabletts am Bild-unteren
## Rand nimmt; die Karten liegen mittig in dem, was bleibt (PaternosterView baut die
## Blende an derselben Zahl). Eine LANE ist die halbe Grube: zwei liegen übereinander.
const FRONT_SHARE := 0.09
const LANES := 2
## Der SPALT zwischen hinterer und vorderer Reihe: durch ihn sieht man in die Grube
## auf die geparkten Tabletts. GEMESSEN an der Werkstatt-Weitsicht (1280 × 720):
## 6,3 Anzeige-px lesen dort als ~8 Bildschirm-px (die geneigte Kamera bildet die
## Grubentiefe größer ab, als die Anzeige sie mißt).
const ROW_GAP_PX := 6.3
## Die FUSSLUFT unter der vorderen Reihe bis zur Bild-unteren Grubenwand: durch sie
## liest man von der Seite das PROFIL der fünf Ebenen der vorderen Lane. Sie liegt
## NÄHER an der Kamera als der Spalt, bildet sich also je Anzeige-Pixel größer ab -
## GEMESSEN lesen 10,3 Anzeige-px als ~15 Bildschirm-px.
const FOOT_GAP_PX := 10.3

## Greifluft quer zum Fußabdruck der LIEGENDEN Kassette und die TIEFE einer Reihe.
## Es gibt genau EINE Reihe je Lane - RANK_SPAN ist ihre Luft, und der Streifen mißt
## sie mal LANES (shelf_min_height).
const CELL_SPAN := 1.15
const RANK_SPAN := 1.1
## Randluft im Platz.
const SLOT_INSET := 0.12
## Rückfall-Fußabdruck (Einheiten u), solange niemand die Welt-Projektion gemeldet
## hat: CELL_FALLBACK ist das TIEFE Maß (die Kartenbreite), CELL_FALLBACK_DEPTH
## sein Verhältnis zur schmalen Grifftiefe.
const CELL_FALLBACK := 7.5
const CELL_FALLBACK_DEPTH := 2.463

## Der gemalte RAHMEN um die Grube - Schatten oben, Licht unten, die Umkehrung
## der Konsolenkante. Die Fläche darin ist ein echtes Loch (screen_glass schneidet
## es, PackPitView stellt die Wände), gemalt wird also nur noch die Fassung.
## Neutrales Dunkelmetall: die Sorte trägt jede Kassette selbst, das Fach ist Möbel.
const RIM_BASE := Color("#34313f")
const RIM_WIDTH := 0.45
const EDGE := 0.33
const RADIUS := 0.9
const WELL_SHADOW := Color(0.0, 0.0, 0.0, 0.72)
const WELL_SHEEN := Color(0.66, 0.64, 0.76, 0.4)
const LOCK_DIM := Color(0.55, 0.55, 0.6)

## Schlagschatten-Rezept, geteilt mit dem Konsolen-Blech (siehe edge_band).
const LIP_DROP := Color(0.0, 0.0, 0.0, 0.55)
const LIP_DROP_SIZE := 0.34
const LIP_DROP_DOWN := 0.22

const EMPTY_TITLE := "Magazin"
const EMPTY_BODY := "Das Magazin ist leer."
## Auskunft der Fach-Fläche: der Bestand steht IM Titel, damit der Deckel dort
## sichtbar ist, wo die Karten liegen.
const STOCK_TITLE := "Magazin (%d/%d)"
const STOCK_BODY := "Platz für %d weitere Kassetten."
const FULL_BODY := "Voll - jede weitere Prämie zerfällt zu Geld."

## Gemeinsame Maßeinheit der Werkbank (setzt WorkshopView über build).
var u := 8.0
## Fußabdruck einer STEHENDEN Datenzelle in Display-Pixeln (Welt-Projektion ihrer
## GRIFF-Zelle; hochkant seit der Welle P: Grifftiefe × Kartenbreite).
var cell_px := Vector2.ZERO
## Der Streifen, in dem das Fach liegt (= die eigene Größe, von build gemerkt).
var strip := Vector2.ZERO
## Das FELD darin: die Grube selbst, also der Streifen ohne seine gemalte Fassung -
## dort und nur dort stehen die Kassetten (lokale Koordinaten).
var field := Rect2()
## Das gelöste Raster des letzten Aufbaus (siehe grid_for).
var _grid: Dictionary = {}
## uid -> Platzmitte in LOKALEN Pixeln, für ALLE Einträge - auch zurückgehaltene:
## ihr Platz wartet auf die Landung ihres Lichts.
var _spots: Dictionary = {}
## uid -> REIHE des Kreislaufs. Nur ZWEI liegen im Bild; die anderen parken darunter.
var _rows: Dictionary = {}
## uid -> Chip-Knopf (nur sichtbare Einträge der zwei liegenden Reihen).
var _chips: Dictionary = {}
## Die freien Plätze der LIEGENDEN Reihen als Ablage-Ziele: [{rect, row}].
var _empty_spots: Array[Dictionary] = []
var _count := 0
var _locked := false
## Die HINTERE Reihe (0-basiert; vorn liegt die nächste) und der Anker des HEBELS in
## Display-Pixeln ((-1,-1) = er steht nicht) - dorthin fliegt, was parkend landet.
var _head := 0
var _lever := Vector2(-1, -1)
## Kassette, auf der die Zieh-Geste begann (0 = keine). Getippt bleibt getippt:
## das Loslassen auf sich selbst feuert den normalen pressed-Klick.
var _drag_from := 0

func _init() -> void:
	name = "PackDrawer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Baut das Fach neu: entries = [{uid, pack, withheld}] in Magazin-Ordnung.
## Zurückgehaltene bekommen ihren PLATZ, aber keinen Chip - der Komet IST das
## Paket, und erst seine Landung deckt es auf. Einen Chip bekommt ohnehin nur, was
## in einer der ZWEI liegenden Reihen liegt: was parkt, sieht man nicht.
func build(entries: Array[Dictionary], unit: float, locked: bool,
		footprint := Vector2.ZERO, row := Vector2.ZERO, head := 0,
		lever := Vector2(-1, -1)) -> void:
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
	_chips.clear()
	_empty_spots.clear()
	_drag_from = 0
	_count = entries.size()
	_head = posmod(head, ROWS)
	_lever = lever
	_grid = grid_for(field.size, cell_px, _count)
	var columns := maxi(int(_grid.get("columns", 1)), 1)
	add_child(_well())
	add_child(_well_catch())
	var filled: Dictionary = {}  # Reihe -> Array[int] belegter Plätze
	for i in entries.size():
		var uid := int(entries[i].get("uid", 0))
		# REIHE und PLATZ kommen aus dem Lauf (das Fenster rechnet die Ordnung nicht
		# nach); ohne Meldung bleibt der kopflose Abschnitts-Rückfall.
		var line := int(entries[i].get("row", -1))
		if line < 0:
			line = row_of(i, columns)
		var cell_index := int(entries[i].get("cell", -1))
		if cell_index < 0:
			cell_index = cell_of(i, columns)
		var seat := PaternosterView.seat_of(line, _head)
		# Der PLATZ gilt IMMER - auch parkend liegt der Körper in der Lane seiner
		# Reihe, nur eben darunter. Nur der CHIP hängt an der Sichtbarkeit.
		var spot := field.position \
			+ spot_for(cell_index, field.size, cell_px, int(seat["lane"]))
		_spots[uid] = spot
		_rows[uid] = line
		if not filled.has(line):
			filled[line] = []
		(filled[line] as Array).append(cell_index)
		if bool(entries[i].get("withheld", false)) or int(seat["depth"]) != 0:
			continue
		var chip := _chip(entries[i].get("pack") as Pack, uid, spot)
		if chip != null:
			add_child(chip)
			_chips[uid] = chip
	_lay_empty_spots(filled, columns)

## Je LIEGENDER Reihe bekommt jeder freie Platz ein Ablage-Ziel: ein Zug darauf hängt
## die Karte hinten an diese Reihe. Es sind reine RECHTECKE, kein Knopf - ein Knopf
## läge über der Fach-Fläche und schluckte den Aufräum-Doppelklick.
func _lay_empty_spots(filled: Dictionary, columns: int) -> void:
	var grip := grip_for(field.size, cell_px)
	for line in ROWS:
		if int(PaternosterView.seat_of(line, _head)["depth"]) != 0:
			continue
		var taken: Array = filled.get(line, [])
		var lane := int(PaternosterView.seat_of(line, _head)["lane"])
		for cell_index in columns:
			if taken.has(cell_index):
				continue
			var spot := field.position + spot_for(cell_index, field.size, cell_px, lane)
			_empty_spots.append({"rect": Rect2(spot - grip * 0.5, grip), "row": line})

## Der LIEGENDE Fußabdruck einer Kassette in Display-Pixeln, aus dem gemeldeten
## STEHENDEN gerechnet: quer liegt ihre LANGSEITE, in der Tiefe ihre Breite. Es gibt
## nur EINE Kartengröße, also folgt alles daraus.
static func lie_cell(cell: Vector2) -> Vector2:
	return Vector2(cell.y * CARD_ASPECT, cell.y) * CASSETTE_SCALE

## Das gelöste Raster eines FELDES (der Grube selbst, nicht des Streifens):
## {"columns", "pages", "scale"}. EINE Rechnung, aus der Platz, Griff, Maßstab und
## Anker folgen - reine Funktion, damit ein Neuaufbau dasselbe Raster legt und ein
## Komet es RECHNEN kann.
## Der Maßstab ist FEST: eine Kassette schrumpft nie. Die Reihe fasst, was in ihrer
## Breite Platz hat, der Rest liegt auf der nächsten ETAGE - und dass es nie mehr
## Etagen werden als PAGES, sichert der Deckel (capacity_for), nicht das Raster.
static func grid_for(field_size: Vector2, cell: Vector2, count: int) -> Dictionary:
	var columns := _columns_at(field_size, cell)
	return {"columns": columns,
		"rows": ceili(float(maxi(count, 1)) / float(columns)),
		"scale": CASSETTE_SCALE}

## Wie viele Kassetten in ihrer festen Größe nebeneinander in die Grube liegen.
static func _columns_at(field_size: Vector2, cell: Vector2) -> int:
	var wide := lie_cell(cell).x * CELL_SPAN
	if field_size.x <= 0.0 or wide <= 0.0:
		return 1
	return maxi(int(field_size.x / wide), 1)

## Der DECKEL des Magazins: eine Reihe mal die REIHEN des Kreislaufs. Gemessen,
## nicht autoriert: scene_root schiebt die Zahl in GameRun, und dort sperrt sie Kauf
## wie Prämie. Darüber hinaus legt das Raster nichts mehr an, weil nichts mehr kommt.
static func capacity_for(field_size: Vector2, cell: Vector2) -> int:
	return _columns_at(field_size, cell) * ROWS

## Spalten einer Reihe - wie viele Kassetten in ihrer festen Größe nebeneinander
## liegen. Der Magazin-Deckel formt das Raster NICHT; er begrenzt den Bestand.
static func columns_for(field_size: Vector2, cell: Vector2, count: int) -> int:
	return int(grid_for(field_size, cell, count)["columns"])

## Reihen, die dieser Bestand füllt.
static func rows_for(field_size: Vector2, cell: Vector2, count: int) -> int:
	return int(grid_for(field_size, cell, count)["rows"])

## Die REIHE eines Eintrags (0 = die erste) - der KOPFLOSE RÜCKFALL, wenn kein Lauf
## eine Reihe meldet. Die echte Ordnung wohnt als Pack.shelf_row im Lauf: eine Karte
## rutscht nur INNERHALB ihrer Reihe nach.
static func row_of(index: int, columns: int) -> int:
	return floori(float(maxi(index, 0)) / float(maxi(columns, 1)))

## ... und sein PLATZ in ihr, derselbe Rückfall.
static func cell_of(index: int, columns: int) -> int:
	return maxi(index, 0) % maxi(columns, 1)

## Die LANE-Geometrie EINER Grube, hinten zuerst: hintere Reihe an der Oberkante,
## darunter der SPALT, dann die vordere, darunter die FUSSLUFT bis zur Wand. Es ist
## die EINE Rechnung - Plätze, Mindesttiefe und der Körper lesen alle sie.
static func lane_rects(field_size: Vector2) -> Array[Rect2]:
	var deep := lane_depth(field_size)
	var rects: Array[Rect2] = []
	for lane in LANES:
		rects.append(Rect2(Vector2(0.0, (deep + ROW_GAP_PX) * float(lane)),
			Vector2(field_size.x, deep)))
	return rects

## Die TIEFE einer Lane: was von der Grube bleibt, wenn Spalt und Fußluft ab sind.
static func lane_depth(field_size: Vector2) -> float:
	return maxf((field_size.y - ROW_GAP_PX - FOOT_GAP_PX) / float(LANES), 1.0)

## Platzmitte eines PLATZES im Feld (relativ zu dessen Ecke), in der LANE, die seine
## Reihe gerade belegt - hinten oben, vorn darunter.
static func spot_for(cell_index: int, field_size: Vector2, cell: Vector2,
		lane := PaternosterView.LANE_BACK) -> Vector2:
	var slot := slot_size(field_size, cell)
	var lane_top := lane_rects(field_size)[clampi(lane, 0, LANES - 1)].position.y
	# Die Reihe liegt mittig in dem, was die FRONT-BLENDE ihres Tabletts übrig läßt -
	# die sitzt an der Bild-unteren Kante IHRER Lane.
	return Vector2(slot.x * (float(maxi(cell_index, 0)) + 0.5), lane_top + slot.y * 0.5)

## Der PLATZ eines Eintrags. Quer teilt sich die Reihe die GANZE Feldbreite - die
## Karte behält ihr Maß, die Luft dazwischen wächst; in der Tiefe ist der Platz
## seine LANE ohne die Blende.
static func slot_size(field_size: Vector2, cell: Vector2) -> Vector2:
	return Vector2(field_size.x / float(_columns_at(field_size, cell)),
		lane_depth(field_size) * (1.0 - FRONT_SHARE))

## Der GRIFF einer Kassette: ihr ganzer Platz abzüglich der Randluft. Er ist
## bewusst größer als die Karte - in der Grube gäbe ein Knopf im Kartenmaß einen
## Streifen von wenigen Pixeln, und der Zeiger fände ihn nie.
static func grip_for(field_size: Vector2, cell: Vector2) -> Vector2:
	return slot_size(field_size, cell) * (1.0 - SLOT_INSET * 2.0)

## Die Grube selbst: das Rechteck INNERHALB des gemalten Rahmens - genau dort
## schneidet screen_glass sein Loch, und der Rahmen überlebt es rings herum.
static func pit_rect_in(row_rect: Rect2, unit: float) -> Rect2:
	var inset := rim_inset(unit)
	return row_rect.grow(-inset)

## Breite der gemalten Fassung (Rahmen plus Kantenband).
static func rim_inset(unit: float) -> float:
	return maxf(2.0, unit * RIM_WIDTH) + maxf(2.0, unit * EDGE)

## Anzeige-Maßstab der Kassetten: das feste Maß, solange die Ränge in die Grube
## passen. REINE Darstellung - der Schlitz misst sich am selben Maß.
func cell_scale() -> float:
	if _grid.has("scale"):
		return float(_grid["scale"])
	return cell_scale_for(cell_px, field.size, _count)

static func cell_scale_for(cell: Vector2, field_size: Vector2, count: int) -> float:
	return float(grid_for(field_size, cell, count)["scale"])

## Display-Pixel des PLATZES dieser uid - dort liegt ihr Körper auf dem Tablett
## seiner Reihe, in der LANE, die diese Reihe gerade belegt ((-1,-1) = liegt nicht
## im Fach). Es IST die Platzmitte: die Karte liegt in der Grube, über ihr schwebt
## nichts.
func pack_seat_px(uid: int) -> Vector2:
	if not _spots.has(uid):
		return Vector2(-1, -1)
	var spot: Vector2 = _spots[uid]
	return get_global_rect().position + spot

## Und wohin ihr Liefer-Licht fliegt: auf den Platz, wenn ihre Reihe LIEGT - sonst
## an den HEBEL, denn eine Maschine, die keiner sieht, hat nicht gespielt.
func pack_anchor_px(uid: int) -> Vector2:
	if not _spots.has(uid):
		return Vector2(-1, -1)
	if not shows_pack(uid):
		return _lever if _lever.x >= 0.0 else get_global_rect().get_center()
	return pack_seat_px(uid)

## Die REIHE einer Kassette (-1 = liegt nicht im Fach).
func row_of_pack(uid: int) -> int:
	return int(_rows.get(uid, -1))

## Liegt ihre Reihe gerade in der Fläche?
func shows_pack(uid: int) -> bool:
	if not _rows.has(uid):
		return false
	return int(PaternosterView.seat_of(int(_rows[uid]), _head)["depth"]) == 0

## Die HINTERE der beiden liegenden Reihen.
func head() -> int:
	return _head

## Derselbe Standplatz, GERECHNET statt gemessen - der Weg, wenn das Fach gerade
## nicht steht (Presse, Paket-Wahl); dieselbe Formel wie oben, damit ein Komet
## nicht springt, sobald es zurückkommt. field_rect ist die GRUBE (pit_rect_in),
## nicht der Streifen: die Kassetten stehen im Loch, nicht unter der Fassung.
static func anchor_in(field_rect: Rect2, cell_index: int,
		cell: Vector2, lane := PaternosterView.LANE_BACK) -> Vector2:
	if cell_index < 0 or field_rect.size.x <= 0.0 or field_rect.size.y <= 0.0:
		return Vector2(-1, -1)
	return field_rect.position + spot_for(cell_index, field_rect.size, cell, lane)

## Der Chip einer uid (null = keiner).
func pack_button(uid: int) -> Button:
	var chip: Button = _chips.get(uid)
	return chip if chip != null and is_instance_valid(chip) else null

## Die Kassette unter der globalen Position (0 = keine) - das Loslassen landet
## auf dem Chip unter dem Zeiger, nicht auf dem, auf dem gedrückt wurde.
func pack_at(global_point: Vector2) -> int:
	for uid: int in _chips:
		var chip: Button = _chips[uid]
		if is_instance_valid(chip) and chip.get_global_rect().has_point(global_point):
			return uid
	return 0

## Die Kassette unter dem Display-Pixel (0 = keine) - GEFRAGT, nicht gemeldet:
## der Zeiger liegt auf dem Tisch, ein mouse_entered käme nie an. scene_root hebt
## daran den Körper aus der Grube.
func hover_uid_at(pixel: Vector2) -> int:
	if not visible or _locked:
		return 0
	return pack_at(pixel)

## Drücken merkt sich die Kassette, Loslassen über einer ANDEREN legt sie dorthin
## um. Losgelassen über derselben bleibt es ein Klick - dessen Signal hängt
## ohnehin am Knopf (dieselbe Geste wie DiceGridView: getippt wählt, gezogen
## sortiert, und beide können nie zugleich feuern).
func _on_chip_input(event: InputEvent, uid: int) -> void:
	if _locked or not (event is InputEventMouseButton) \
			or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	if (event as InputEventMouseButton).pressed:
		_drag_from = uid
		return
	var at := (event as InputEventMouseButton).global_position
	var target := pack_at(at)
	if _drag_from > 0 and target > 0 and target != _drag_from:
		packs_reordered.emit(_drag_from, target)
	elif _drag_from > 0 and target <= 0:
		var row := empty_row_at(at)
		if row >= 0 and row != row_of_pack(_drag_from):
			pack_placed.emit(_drag_from, row)
	_drag_from = 0

## Die REIHE des freien Platzes unter der globalen Position (-1 = keiner). Die
## Rechtecke liegen lokal wie die Plätze; global wird hier gerechnet.
func empty_row_at(global_point: Vector2) -> int:
	var origin := get_global_rect().position
	for spot in _empty_spots:
		if (spot["rect"] as Rect2).has_point(global_point - origin):
			return int(spot["row"])
	return -1

## Name und Wirkung dessen, was unter pixel liegt ({} = nichts). Ein leeres Fach
## nennt sich selbst. GEFRAGT statt gemeldet: der Zeiger liegt auf dem Tisch, ein
## mouse_exited käme nie an.
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
	# Die Fläche selbst spricht IMMER, nicht nur leer: sie nennt den Füllstand am
	# Deckel. Die Zahlen holt WorkshopView live vom Lauf (Marke "stock") - der
	# gemessene Deckel steht erst nach dem Layout, ein eingebackener wäre alt.
	if get_global_rect().has_point(pixel):
		return {"title": EMPTY_TITLE, "body": EMPTY_BODY, "stock": true}
	return {}

## Eine gemalte Kante: Lichtband oben ODER Schattenband unten, gerundet wie das
## Blech, auf dem es liegt. Die EINE Rezeptur der gemalten Tiefe - Fach wie
## Konsole holen sie hier.
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

## Die FASSUNG der Grube: Schatten fällt von oben herein, das Licht fängt sich an
## der unteren Kante. Ihre Mitte wird nicht mehr gemalt - dort ist ein echtes Loch
## (screen_glass.pit_rect), und ein gemalter Grund läge hinter nichts.
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

## Der unsichtbare Fang der leeren Fach-Fläche: ein Doppelklick darauf räumt das
## Magazin auf. Als KNOPF, damit die Werkbank-Nahsicht (Doppelklick auf leere
## Fläche) hier nicht mitzündet - das Fach ist Möbel, keine leere Bank.
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
	var click := event as InputEventMouseButton
	if _locked or click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if click.pressed and click.double_click:
		tidy_requested.emit()

## Der unsichtbare Griff einer Kassette: er zeichnet NICHTS - der Körper steht in
## der Grube, und ein gemalter Schein läge unter dem Loch. Das Greifen zeigt die
## Kassette selbst, indem sie sich ein Stück herauszieht (DataCellView.set_hovered).
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
	# Der Deckel nennt das PRÄGENETZ mit: was die Karte prägt, ist ihr Inhalt.
	var body := pack.description
	var net := Pack.net_line(pack)
	if net != "" and not body.contains(net):
		body = "%s\n%s" % [body, net]
	chip.set_meta("title", title)
	chip.set_meta("body", body)
	chip.tooltip_text = "%s\n%s" % [title, body]
	if not _locked:
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.pressed.connect(func() -> void: pack_pressed.emit(uid))
	chip.gui_input.connect(_on_chip_input.bind(uid))
	return chip
