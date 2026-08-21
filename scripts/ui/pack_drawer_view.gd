class_name PackDrawerView
extends Control
## Das MAGAZIN der Werkbank: EINE durchgehende GRUBE in der Schürze, in der jedes
## versiegelte Paket als EIGENE Kassette versenkt STEHT - wie Akten im Fach, Rang
## hinter Rang. Die Karte hat ihr FESTES Maß (CASSETTE_SCALE): eine Zeile fasst,
## was in ihrer Breite Platz hat, alles Weitere fließt in den nächsten Rang nach
## vorn. Eine Kassette SCHRUMPFT NIE - was nicht mehr in die Grube passt, kommt
## gar nicht erst herein: capacity_for misst den Deckel an der Grube, GameRun
## bekommt ihn hereingeschoben und sperrt Kauf wie Prämie daran.
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

const GOLD := Color("#ffd319")

## Sorten-Farben - Schlüssel sind Pack.SHELF_ORDER: die Taxonomie wohnt in data/,
## die Farben hier (Rune.tint-Regel: data importiert nie ui).
const COLORS := {
	Engraving.CATEGORY_NUMBER: Color("#50fa7b"),
	Engraving.CATEGORY_MATERIAL: Color("#ff79c6"),
	Engraving.CATEGORY_DICE: Color("#ffd319"),
	Pack.SHELF_SPECIAL: Color("#bd93f9"),
}

## Der EINE Anzeige-Maßstab einer Kassette - im Magazin wie im Leseschlitz
## (WorkshopView misst seine Schlitze daran, scene_root skaliert die Körper).
## Eine Karte behält damit ihre Größe ihr ganzes Leben lang: Fach -> Schlitz ->
## Fach ohne Schrumpfen und Wachsen auf dem Weg.
const CASSETTE_SCALE := 1.4

## Greifluft quer zum Kappen-Fußabdruck (die Kassetten STEHEN, gemessen wird ihre
## Kappe: Breite × Dicke) und die TIEFE eines Rangs. In der Tiefe braucht es mehr:
## der stehende Körper ragt im 15°-Blick über den Rang dahinter, ein Rangabstand
## im bloßen Kappenmaß verdeckte die Kappen seiner Vorgänger.
const CELL_SPAN := 1.15
const RANK_SPAN := 1.9
## Randluft im Platz.
const SLOT_INSET := 0.12
## Rückfall-Zellbreite (Einheiten u), solange niemand die Welt-Projektion gemeldet
## hat; die Tiefe folgt dem Kappen-Verhältnis.
const CELL_FALLBACK := 5.0
const CELL_FALLBACK_DEPTH := 0.41

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
## Kappe: Breite × Kappentiefe).
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
## uid -> Chip-Knopf (nur sichtbare Einträge).
var _chips: Dictionary = {}
var _count := 0
var _locked := false
## Kassette, auf der die Zieh-Geste begann (0 = keine). Getippt bleibt getippt:
## das Loslassen auf sich selbst feuert den normalen pressed-Klick.
var _drag_from := 0

func _init() -> void:
	name = "PackDrawer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Baut das Fach neu: entries = [{uid, pack, withheld}] in Magazin-Ordnung.
## Zurückgehaltene bekommen ihren PLATZ, aber keinen Chip - der Komet IST das
## Paket, und erst seine Landung deckt es auf.
func build(entries: Array[Dictionary], unit: float, locked: bool,
		footprint := Vector2.ZERO, row := Vector2.ZERO) -> void:
	u = maxf(unit, 1.0)
	_locked = locked
	strip = row if row.x > 0.0 and row.y > 0.0 else size
	cell_px = footprint if footprint.x > 0.0 and footprint.y > 0.0 else _fallback_cell()
	field = pit_rect_in(Rect2(Vector2.ZERO, strip), u)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_spots.clear()
	_chips.clear()
	_drag_from = 0
	_count = entries.size()
	_grid = grid_for(field.size, cell_px, _count)
	add_child(_well())
	add_child(_well_catch())
	for i in entries.size():
		var uid := int(entries[i].get("uid", 0))
		var spot := field.position + _spot_in(_grid, i, field.size, cell_px)
		_spots[uid] = spot
		if bool(entries[i].get("withheld", false)):
			continue
		var chip := _chip(entries[i].get("pack") as Pack, uid, spot)
		if chip != null:
			add_child(chip)
			_chips[uid] = chip

## Das gelöste Raster eines FELDES (der Grube selbst, nicht des Streifens):
## {"columns", "rows", "scale"}. EINE Rechnung, aus der Platz, Griff, Maßstab und
## Anker folgen - reine Funktion, damit ein Neuaufbau dasselbe Raster legt und ein
## Komet es RECHNEN kann.
## Der Maßstab ist FEST: eine Kassette schrumpft nie. Die Zeile fasst, was in ihrer
## Breite Platz hat, der Rest fließt in den nächsten Rang - und dass die Ränge nie
## tiefer laufen als die Grube, sichert der Deckel (capacity_for), nicht das Raster.
static func grid_for(field_size: Vector2, cell: Vector2, count: int) -> Dictionary:
	var columns := _columns_at(field_size, cell)
	return {"columns": columns,
		"rows": ceili(float(maxi(count, 1)) / float(columns)),
		"scale": CASSETTE_SCALE}

## Wie viele Kassetten in ihrer festen Größe nebeneinander in die Grube stehen.
static func _columns_at(field_size: Vector2, cell: Vector2) -> int:
	var wide := cell.x * CELL_SPAN * CASSETTE_SCALE
	if field_size.x <= 0.0 or wide <= 0.0:
		return 1
	return maxi(int(field_size.x / wide), 1)

## Wie viele Ränge in ihrer festen Tiefe hintereinander in die Grube passen.
static func _ranks_at(field_size: Vector2, cell: Vector2) -> int:
	var deep := cell.y * RANK_SPAN * CASSETTE_SCALE
	if field_size.y <= 0.0 or deep <= 0.0:
		return 1
	return maxi(int(field_size.y / deep), 1)

## Der DECKEL des Magazins: so viele Kassetten stehen in voller Größe in dieser
## Grube - Spalten mal Ränge, dieselbe Arithmetik wie das Raster. Gemessen, nicht
## autoriert: scene_root schiebt die Zahl in GameRun, und dort sperrt sie Kauf wie
## Prämie. Darüber hinaus legt das Raster nichts mehr an, weil nichts mehr kommt.
static func capacity_for(field_size: Vector2, cell: Vector2) -> int:
	return _columns_at(field_size, cell) * _ranks_at(field_size, cell)

## Spalten einer Zeile - wie viele Kassetten in ihrer festen Größe nebeneinander
## stehen. Der Magazin-Deckel formt das Raster NICHT; er begrenzt den Bestand.
static func columns_for(field_size: Vector2, cell: Vector2, count: int) -> int:
	return int(grid_for(field_size, cell, count)["columns"])

## Ränge, die dieser Bestand füllt.
static func rows_for(field_size: Vector2, cell: Vector2, count: int) -> int:
	return int(grid_for(field_size, cell, count)["rows"])

## Platzmitte des Eintrags index im Feld (relativ zu dessen Ecke).
static func spot_for(index: int, count: int, field_size: Vector2,
		cell: Vector2) -> Vector2:
	return _spot_in(grid_for(field_size, cell, count), index, field_size, cell)

static func _spot_in(grid: Dictionary, index: int, field_size: Vector2,
		cell: Vector2) -> Vector2:
	var columns := maxi(int(grid.get("columns", 1)), 1)
	var slot := _slot_in(grid, field_size, cell)
	var column := index % columns
	var line := floori(float(index) / float(columns))
	# Von OBEN angelegt: neue Ränge wachsen nach vorn in die leere Grube, und ein
	# halbvolles Magazin liest als vordere Zeile Ware, nicht als schwebendes Band.
	return Vector2(slot.x * (float(column) + 0.5), slot.y * (float(line) + 0.5))

## Der PLATZ eines Eintrags. Quer teilt sich die Zeile die GANZE Feldbreite - die
## Karte behält ihr Maß, die Luft dazwischen wächst; in der Tiefe ist der Platz
## genau ein Rang, sonst rückten die Ränge mit jedem neuen Paket auseinander.
static func slot_size(field_size: Vector2, cell: Vector2, count: int) -> Vector2:
	return _slot_in(grid_for(field_size, cell, count), field_size, cell)

static func _slot_in(grid: Dictionary, field_size: Vector2, cell: Vector2) -> Vector2:
	var columns := maxf(float(grid.get("columns", 1)), 1.0)
	var scale := float(grid.get("scale", CASSETTE_SCALE))
	return Vector2(field_size.x / columns, cell.y * RANK_SPAN * scale)

## Der GRIFF einer Kassette: ihr ganzer Platz abzüglich der Randluft. Er ist
## bewusst größer als die Kappe - in der Grube gäbe ein Knopf im Kappenmaß einen
## Streifen von wenigen Pixeln, und der Zeiger fände ihn nie.
static func grip_for(field_size: Vector2, cell: Vector2, count: int) -> Vector2:
	return _grip_in(grid_for(field_size, cell, count), field_size, cell)

static func _grip_in(grid: Dictionary, field_size: Vector2, cell: Vector2) -> Vector2:
	return _slot_in(grid, field_size, cell) * (1.0 - SLOT_INSET * 2.0)

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

## Display-Pixel der Kassette dieser uid - Standplatz ihres Körpers und Ziel der
## Liefer-Kometen. Antwortet auch für zurückgehaltene Einträge ((-1,-1) = liegt
## nicht im Fach). Es IST die Platzmitte: die Kassette steht in der Grube, über
## ihr schwebt nichts mehr.
func pack_anchor_px(uid: int) -> Vector2:
	if not _spots.has(uid):
		return Vector2(-1, -1)
	var spot: Vector2 = _spots[uid]
	return get_global_rect().position + spot

## Derselbe Standplatz, GERECHNET statt gemessen - der Weg, wenn das Fach gerade
## nicht steht (Presse, Paket-Wahl); dieselbe Formel wie oben, damit ein Komet
## nicht springt, sobald es zurückkommt. field_rect ist die GRUBE (pit_rect_in),
## nicht der Streifen: die Kassetten stehen im Loch, nicht unter der Fassung.
static func anchor_in(field_rect: Rect2, index: int, count: int,
		cell: Vector2) -> Vector2:
	if index < 0 or field_rect.size.x <= 0.0 or field_rect.size.y <= 0.0:
		return Vector2(-1, -1)
	return field_rect.position + spot_for(index, count, field_rect.size, cell)

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
	var target := pack_at((event as InputEventMouseButton).global_position)
	if _drag_from > 0 and target > 0 and target != _drag_from:
		packs_reordered.emit(_drag_from, target)
	_drag_from = 0

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
	var wide := unit * CELL_FALLBACK * 2.0 / 3.0
	return Vector2(wide, wide * CELL_FALLBACK_DEPTH)

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
	var grip := _grip_in(_grid, field.size, cell_px)
	chip.size = grip
	chip.position = spot - grip * 0.5
	chip.disabled = _locked
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		chip.add_theme_stylebox_override(state, StyleBoxEmpty.new())

	var title := pack.display_name if pack.count <= 1 \
		else "%d× %s" % [pack.count, pack.display_name]
	chip.set_meta("title", title)
	chip.set_meta("body", pack.description)
	chip.tooltip_text = "%s\n%s" % [title, pack.description]
	if not _locked:
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.pressed.connect(func() -> void: pack_pressed.emit(uid))
	chip.gui_input.connect(_on_chip_input.bind(uid))
	return chip
