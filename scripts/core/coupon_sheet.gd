class_name CouponSheet
extends RefCounted
## Ein perforierter Coupon-Bogen: Raster, in das Coupons ihrer Fläche nach
## gelegt werden; Restzellen füllen Geld-Marken (festes Budget je Bogentyp)
## und Werbeflächen. Die Fläche IST die Rarität. Anzeige: CouponSheetView.

## Schnipsel 2×2, Bogen 3×3, Großbogen 5×5, Plakat 7×7, Riesenbogen 9×9.
enum Kind { SNIPPET, SHEET, LARGE, POSTER, JUMBO }

## ETCHING = echter Gravur-Coupon, MONEY = 1×1-Chip-Marke, AD = Werbefläche.
enum TileKind { ETCHING, MONEY, AD }

## Eine platzierte Kachel - typisiert, damit Feld-Tippfehler Compilerfehler sind.
class SheetTile:
	extends RefCounted

	var kind: CouponSheet.TileKind
	var coupon: Coupon = null  # nur bei ETCHING gesetzt
	var texture: String = ""
	var col: int = 0
	var row: int = 0
	var w: int = 1
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

const FILLER_CHIP := "chip_coupon.jpg"
const FILLER_ADS := ["ad_chip.jpg", "ad_cup.jpg", "ad_polish.jpg"]

## Festes Geld-Marken-Budget statt Flächen-Anteil: der Kaufpreis soll Coupons
## kaufen, nicht Geld wechseln - alle Zellen darüber sind Werbeflächen.
const CHIP_TILES_PER_KIND := {
	Kind.SNIPPET: 1, Kind.SHEET: 2, Kind.LARGE: 3, Kind.POSTER: 4, Kind.JUMBO: 5,
}

const REAL_COUPONS_PER_KIND := {
	Kind.SNIPPET: 1, Kind.SHEET: 2, Kind.LARGE: 3, Kind.POSTER: 5, Kind.JUMBO: 8,
}

var cols: int = 0
var rows: int = 0
var tiles: Array[SheetTile] = []  # Coupons zuerst, dann die Füller

func etching_count() -> int:
	var count := 0
	for tile in tiles:
		if tile.kind == TileKind.ETCHING:
			count += 1
	return count

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

## Würfelt einen Bogen aus: echte Coupons (gewichtet nach Seltenheit, nur wenn
## ihre Fläche passt) an freie Stellen, dann Restzellen füllen.
## allowed_kinds beschränkt auf diese Coupon-kinds (sortenreine Packs, leer =
## gemischt); extra_size vergrößert das Raster (Großformat-Charm); no_ads macht
## Werbeflächen zu Chip-Coupons (Hausmarke-Charm).
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
			continue  # kein Platz mehr
		sheet.tiles.append(SheetTile.new(TileKind.ETCHING, coupon.texture_path,
			spot.x, spot.y, coupon.width, coupon.height, coupon))
		_mark(occupied, spot, coupon.width, coupon.height)

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

## Zufälliger Coupon, dessen Fläche in size passt (und dessen kind erlaubt ist),
## gewichtet nach Seltenheit.
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

## Zufällige freie Position für einen w×h-Coupon; (-1,-1) = nirgends Platz.
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
