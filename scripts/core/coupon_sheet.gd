class_name CouponSheet
extends RefCounted
## Ein perforierter Coupon-Bogen (siehe Obsidian "02 Gravuren - Seiten editieren"):
## ein Raster, in das Coupons ihrer Fläche (Coupon.width/height) entsprechend
## gelegt werden; freie Zellen füllen wenige 1×1-Geld-Marken (festes Budget je
## Bogentyp, siehe CHIP_TILES_PER_KIND) und ansonsten Werbeflächen. Die Fläche
## IST die Rarität - ein 3×3-Coupon passt gar nicht auf einen kleinen Bogen.
## Reine Daten + Erzeugung; die Anzeige übernimmt CouponSheetView.

## Bogentypen mit ihren Rastergrößen (siehe Obsidian "10 Shop und Ökonomie").
## Schnipsel 2×2, Bogen 3×3, Großbogen 5×5, Plakat 7×7, Riesenbogen 9×9.
enum Kind { SNIPPET, SHEET, LARGE, POSTER, JUMBO }

## Was eine einzelne Kachel beim "Abreißen" bewirkt (siehe scene_root:
## _play_sheet_finish_animation): ETCHING = echter Gravur-Coupon (coupon
## gesetzt), MONEY = 1×1-Chip-Marke (kleine Auszahlung), AD = reine Werbefläche.
enum TileKind { ETCHING, MONEY, AD }

## Eine platzierte Kachel des Bogens - typisiert statt als Dictionary, damit
## Tippfehler in Feldnamen Compilerfehler sind statt stiller Animations-Bugs.
class SheetTile:
	extends RefCounted

	var kind: CouponSheet.TileKind
	var coupon: Coupon = null  # nur bei kind == ETCHING gesetzt
	var texture: String = ""  # Pfad der Motiv-Textur
	var col: int = 0  # linke obere Rasterzelle
	var row: int = 0
	var w: int = 1  # Fläche in Rasterzellen (siehe Coupon.width/height)
	var h: int = 1

	func _init(p_kind: CouponSheet.TileKind, p_texture: String, p_col: int, p_row: int,
			p_w: int = 1, p_h: int = 1, p_coupon: Coupon = null) -> void:
		kind = p_kind
		texture = p_texture
		col = p_col
		row = p_row
		w = p_w
		h = p_h
		coupon = p_coupon

## 1×1-Füller für die Restzellen (Texturdateien in Coupon.TEXTURE_DIR).
const FILLER_CHIP := "chip_coupon.jpg"  # Geld-Marke (kleine Auszahlung)
const FILLER_ADS := ["ad_chip.jpg", "ad_cup.jpg", "ad_polish.jpg"]  # reine Werbeflächen (Flavor)

## FESTES Geld-Marken-Budget je Bogentyp statt eines Flächen-Anteils: große
## Bögen haben viele Restzellen, und als Anteil gerechnet würde ein Riesenbogen
## fast seinen Kaufpreis in Chips zurückzahlen. Der Kaufpreis soll Coupons
## kaufen, nicht Geld wechseln - alle Zellen über dem Budget sind Werbeflächen.
const CHIP_TILES_PER_KIND := {
	Kind.SNIPPET: 1, Kind.SHEET: 2, Kind.LARGE: 3, Kind.POSTER: 4, Kind.JUMBO: 5,
}

## Wie viele "echte" Gravur-Coupons je Bogentyp platziert werden (Rest = Füller).
const REAL_COUPONS_PER_KIND := {
	Kind.SNIPPET: 1, Kind.SHEET: 2, Kind.LARGE: 3, Kind.POSTER: 5, Kind.JUMBO: 8,
}

var cols: int = 0
var rows: int = 0
## Platzierte Kacheln (siehe SheetTile) - Coupons zuerst, dann die Füller.
var tiles: Array[SheetTile] = []

## Anzahl echter Gravur-Coupons auf dem Bogen (der Rest sind 1×1-Marken/
## Werbeflächen) - z.B. für die Shop-Rückmeldung nach dem Kauf.
func etching_count() -> int:
	var count := 0
	for tile in tiles:
		if tile.kind == TileKind.ETCHING:
			count += 1
	return count

## Rastergröße (Spalten × Zeilen) eines Bogentyps.
static func grid_size(kind: int) -> Vector2i:
	match kind:
		Kind.SNIPPET:
			return Vector2i(2, 2)
		Kind.SHEET:
			return Vector2i(3, 3)
		Kind.LARGE:
			return Vector2i(5, 5)
		Kind.POSTER:
			return Vector2i(7, 7)
		Kind.JUMBO:
			return Vector2i(9, 9)
	return Vector2i(2, 2)

## Würfelt einen Bogen aus: erst 1–3 echte Coupons (gewichtet nach Seltenheit,
## nur wenn ihre Fläche passt) an zufällige freie Stellen, dann alle Restzellen
## mit 1×1-Marken/Werbeflächen füllen.
##
## allowed_kinds (optional): beschränkt die echten Coupons auf diese
## Coupon-kinds (siehe Coupon.KIND_*) - Grundlage der sortenreinen Packs im
## Shop (Werkstatt-Prospekt nur Ätzungen, Tageskarte nur Gerichte, ...).
## Leer = alle Arten gemischt.
##
## extra_size (optional): vergrößert das Raster um N in beide Richtungen
## (Großformat-Charm: alle Packs 1×1 größer). no_ads (optional): Werbeflächen
## werden zu Chip-Coupons (Hausmarke-Charm für das gemischte Heft).
static func generate(kind: int, allowed_kinds: Array[String] = [], extra_size: int = 0, no_ads: bool = false) -> CouponSheet:
	var sheet := CouponSheet.new()
	var size := grid_size(kind) + Vector2i(extra_size, extra_size)
	sheet.cols = size.x
	sheet.rows = size.y

	var occupied: Array = []  # rows × cols
	for r in size.y:
		var row_cells: Array = []
		for c in size.x:
			row_cells.append(false)
		occupied.append(row_cells)

	var wanted: int = REAL_COUPONS_PER_KIND.get(kind, 1)
	for i in wanted:
		var coupon := _pick_fitting_coupon(size, allowed_kinds)
		if coupon == null:
			continue
		var spot := _find_free_spot(occupied, size, coupon.width, coupon.height)
		if spot.x < 0:
			continue  # kein Platz mehr - überspringen
		sheet.tiles.append(SheetTile.new(TileKind.ETCHING, coupon.texture_path,
			spot.x, spot.y, coupon.width, coupon.height, coupon))
		_mark(occupied, spot, coupon.width, coupon.height)

	# Restzellen füllen: zufällig verteilte Geld-Marken bis zum festen Budget
	# (siehe CHIP_TILES_PER_KIND), alles darüber sind Werbeflächen - außer mit
	# no_ads (Hausmarke-Charm), das auch die Werbeflächen zu Geld-Marken macht.
	var free_cells: Array[Vector2i] = []
	for r in size.y:
		for c in size.x:
			if not occupied[r][c]:
				free_cells.append(Vector2i(c, r))
	free_cells.shuffle()
	var chip_budget: int = CHIP_TILES_PER_KIND.get(kind, 1)
	for i in free_cells.size():
		var cell := free_cells[i]
		var is_money := i < chip_budget or no_ads
		var tex: String = FILLER_CHIP if is_money else FILLER_ADS[randi() % FILLER_ADS.size()]
		sheet.tiles.append(SheetTile.new(TileKind.MONEY if is_money else TileKind.AD,
			Coupon.TEXTURE_DIR + tex, cell.x, cell.y))
		occupied[cell.y][cell.x] = true
	return sheet

## Ein zufälliger Coupon, dessen Fläche in size passt (und dessen kind in
## allowed_kinds liegt, falls gesetzt), gewichtet nach Seltenheit
## (kleinere/häufigere öfter, siehe Coupon._rarity_weight).
static func _pick_fitting_coupon(size: Vector2i, allowed_kinds: Array[String] = []) -> Coupon:
	var candidates: Array[Coupon] = []
	var total := 0
	for coupon in Coupon.all():
		if not allowed_kinds.is_empty() and not allowed_kinds.has(coupon.kind):
			continue
		if coupon.width <= size.x and coupon.height <= size.y:
			candidates.append(coupon)
			total += Coupon._rarity_weight(coupon.rarity)
	if candidates.is_empty():
		return null
	var roll := randi() % total
	for coupon in candidates:
		roll -= Coupon._rarity_weight(coupon.rarity)
		if roll < 0:
			return coupon
	return candidates[0]

## Sucht eine zufällige freie Position, an der ein w×h-Coupon vollständig ins
## Raster passt und alle Zellen frei sind. Vector2i(-1,-1), wenn nirgends Platz.
static func _find_free_spot(occupied: Array, size: Vector2i, w: int, h: int) -> Vector2i:
	var spots: Array[Vector2i] = []
	for r in size.y - h + 1:
		for c in size.x - w + 1:
			if _area_free(occupied, c, r, w, h):
				spots.append(Vector2i(c, r))
	if spots.is_empty():
		return Vector2i(-1, -1)
	return spots[randi() % spots.size()]

static func _area_free(occupied: Array, col: int, row: int, w: int, h: int) -> bool:
	for r in range(row, row + h):
		for c in range(col, col + w):
			if occupied[r][c]:
				return false
	return true

static func _mark(occupied: Array, spot: Vector2i, w: int, h: int) -> void:
	for r in range(spot.y, spot.y + h):
		for c in range(spot.x, spot.x + w):
			occupied[r][c] = true
