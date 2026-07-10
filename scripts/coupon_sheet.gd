class_name CouponSheet
extends RefCounted
## Ein perforierter Coupon-Bogen (siehe Obsidian "02 Gravuren - Seiten editieren"):
## ein Raster, in das Coupons ihrer Fläche (Coupon.width/height) entsprechend
## gelegt werden; freie Zellen füllen 1×1-Marken/Werbeflächen. Die Fläche IST die
## Rarität - ein 3×3-Coupon passt gar nicht auf einen kleinen Bogen. Reine Daten
## + Erzeugung; die Anzeige übernimmt CouponSheetView.

## Bogentypen mit ihren Rastergrößen (siehe Obsidian "10 Shop und Ökonomie").
enum Kind { SNIPPET, SHEET, LARGE }  # Schnipsel 2×2, Bogen 3×3, Großbogen 5×5

## 1×1-Füller für die Restzellen (Texturdateien in Coupon.TEXTURE_DIR).
const FILLER_CHIP := "Chip-coupon1x1.jpg"  # der Standard-Füller (kleine Auszahlung)
const FILLER_ADS := ["chip-ad1x1.jpg", "cup-ad1x1.jpg", "politur-ad1x1.jpg"]  # reine Werbeflächen (Flavor)
const AD_CHANCE := 0.3  # Anteil Werbeflächen unter den Füllern (Rest: Chip-Coupons)

## Wie viele "echte" Gravur-Coupons je Bogentyp platziert werden (Rest = Füller).
const REAL_COUPONS_PER_KIND := { Kind.SNIPPET: 1, Kind.SHEET: 2, Kind.LARGE: 3 }

var cols: int = 0
var rows: int = 0
## Platzierte Kacheln: je {coupon: Coupon|null, texture: String, col, row, w, h}.
## coupon == null bedeutet Füller (Marke/Werbung).
var tiles: Array[Dictionary] = []

## Anzahl echter Gravur-Coupons auf dem Bogen (der Rest sind 1×1-Marken/
## Werbeflächen) - z.B. für die Shop-Rückmeldung nach dem Kauf.
func etching_count() -> int:
	var count := 0
	for tile in tiles:
		if tile["kind"] == "etching":
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
	return Vector2i(2, 2)

## Würfelt einen Bogen aus: erst 1–3 echte Coupons (gewichtet nach Seltenheit,
## nur wenn ihre Fläche passt) an zufällige freie Stellen, dann alle Restzellen
## mit 1×1-Marken/Werbeflächen füllen.
static func generate(kind: int) -> CouponSheet:
	var sheet := CouponSheet.new()
	var size := grid_size(kind)
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
		var coupon := _pick_fitting_coupon(size)
		if coupon == null:
			continue
		var spot := _find_free_spot(occupied, size, coupon.width, coupon.height)
		if spot.x < 0:
			continue  # kein Platz mehr - überspringen
		sheet.tiles.append({
			"coupon": coupon, "texture": coupon.texture_path, "kind": "etching",
			"col": spot.x, "row": spot.y, "w": coupon.width, "h": coupon.height,
		})
		_mark(occupied, spot, coupon.width, coupon.height)

	for r in size.y:
		for c in size.x:
			if occupied[r][c]:
				continue
			var is_ad := randf() < AD_CHANCE
			var tex: String = FILLER_ADS[randi() % FILLER_ADS.size()] if is_ad else FILLER_CHIP
			sheet.tiles.append({
				"coupon": null, "texture": Coupon.TEXTURE_DIR + tex, "kind": "ad" if is_ad else "money",
				"col": c, "row": r, "w": 1, "h": 1,
			})
			occupied[r][c] = true
	return sheet

## Ein zufälliger Coupon, dessen Fläche in size passt, gewichtet nach Seltenheit
## (kleinere/häufigere öfter, siehe Coupon._rarity_weight).
static func _pick_fitting_coupon(size: Vector2i) -> Coupon:
	var candidates: Array[Coupon] = []
	var total := 0
	for coupon in Coupon.all():
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
