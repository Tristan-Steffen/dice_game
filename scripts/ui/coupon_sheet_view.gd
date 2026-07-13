class_name CouponSheetView
extends Control
## Zeigt einen CouponSheet als perforierten Bogen: cremefarbenes "Papier" mit
## einem Raster aus Coupon-Texturen (jede auf ihre Zellfläche gestreckt, siehe
## show_sheet). Zwischen den Coupons - und um den Bogen herum - laufen gestrichelte
## Perforationslinien wie bei echten Coupon-Bögen; sie werden nur entlang echter
## Kanten zwischen VERSCHIEDENEN Coupons gezogen (ein 2×2-Coupon hat also keine
## Perforation quer durch seine Mitte). Reine Anzeige - die Daten liefert CouponSheet.

const SHEET_PAD := 16.0    # Papierrand um das Raster
const TILE_MARGIN := 9.0   # Abstand der Textur zur Zellkante (Perforation läuft dazwischen)

const PAPER_COLOR := Color("efe4c8")  # cremefarbenes Bogenpapier (passt zum Coupon-Vintage-Look)
const PERF_COLOR := Color("6b4a2f")   # warmes Braun für die Perforationslinien
const FILLER_TINT := Color(1, 1, 1, 0.82)  # Marken/Werbeflächen leicht zurückgenommen

## Eine gezeigte Kachel: ihr Anzeige-Control (TextureRect oder Platzhalter für
## Coupons ohne Motiv-Datei) plus die Bogen-Daten dahinter - Grundlage der
## Abschluss-Animation (siehe scene_root, das die Nodes zum Fliegen in seine
## Overlay-Ebene umhängt).
class TileView:
	extends RefCounted

	var node: Control
	var tile: CouponSheet.SheetTile

	func _init(p_node: Control, p_tile: CouponSheet.SheetTile) -> void:
		node = p_node
		tile = p_tile

var tile_views: Array[TileView] = []

## Baut die Kacheln des Bogens neu auf. cell_px = Kantenlänge einer Rasterzelle
## in Pixeln; die Gesamtgröße (inkl. Papierrand) ergibt sich daraus.
func show_sheet(sheet: CouponSheet, cell_px: float) -> void:
	for child in get_children():
		child.queue_free()
	tile_views.clear()

	var full := Vector2(sheet.cols * cell_px + SHEET_PAD * 2.0, sheet.rows * cell_px + SHEET_PAD * 2.0)
	custom_minimum_size = full
	size = full

	var paper := Panel.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_theme_stylebox_override("panel", _paper_box())
	add_child(paper)

	# Zelle -> Kachelindex, damit die Perforation nur zwischen VERSCHIEDENEN
	# Coupons gezogen wird (siehe _Perforation).
	var cell_tile: Array = []
	for r in sheet.rows:
		var row_cells: Array = []
		for c in sheet.cols:
			row_cells.append(-1)
		cell_tile.append(row_cells)

	for i in sheet.tiles.size():
		var tile: CouponSheet.SheetTile = sheet.tiles[i]
		for r in range(tile.row, tile.row + tile.h):
			for c in range(tile.col, tile.col + tile.w):
				cell_tile[r][c] = i

		var node := _tile_node(tile)
		node.position = Vector2(
			SHEET_PAD + tile.col * cell_px + TILE_MARGIN,
			SHEET_PAD + tile.row * cell_px + TILE_MARGIN)
		node.size = Vector2(
			tile.w * cell_px - TILE_MARGIN * 2.0,
			tile.h * cell_px - TILE_MARGIN * 2.0)
		node.modulate = Color.WHITE if tile.kind == CouponSheet.TileKind.ETCHING else FILLER_TINT
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(node)
		tile_views.append(TileView.new(node, tile))

	var perforation := _Perforation.new()
	perforation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	perforation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	perforation.setup(sheet.cols, sheet.rows, cell_px, SHEET_PAD, cell_tile)
	add_child(perforation)  # zuletzt = über den Texturen

## Anzeige-Node einer Kachel: das Motiv als TextureRect, oder - falls die
## Motiv-Datei (noch) fehlt, z.B. bei neuen Material-Coupons ohne Artwork - ein
## Platzhalter in Material-/Papierfarbe mit dem Coupon-Namen.
func _tile_node(tile: CouponSheet.SheetTile) -> Control:
	if ResourceLoader.exists(tile.texture):
		var tex := TextureRect.new()
		tex.texture = load(tile.texture)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_SCALE  # auf die Zelle strecken - Quell-Seitenverhältnis egal
		return tex

	var placeholder := Panel.new()
	var box := StyleBoxFlat.new()
	var tint := DieMaterial.tint_for(tile.coupon.material_id()) if tile.coupon != null else PAPER_COLOR
	box.bg_color = tint.lerp(PAPER_COLOR, 0.35)
	box.border_color = PERF_COLOR
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	placeholder.add_theme_stylebox_override("panel", box)

	var label := Label.new()
	label.text = tile.coupon.display_name if tile.coupon != null else ""
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", PERF_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.add_child(label)
	return placeholder

func _paper_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER_COLOR
	box.set_corner_radius_all(10)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 12
	box.shadow_offset = Vector2(0, 4)
	return box

## Zeichnet die gestrichelten Perforationslinien über dem Raster: entlang jeder
## Zellkante zwischen zwei VERSCHIEDENEN Coupons (nie mitten durch einen) plus
## der Außenkante des ganzen Bogens.
class _Perforation:
	extends Control

	const DASH := 6.0
	const DASH_GAP := 5.0
	const LINE_WIDTH := 2.0
	const LINE_COLOR := Color("6b4a2f")

	var cols: int
	var rows: int
	var cell: float
	var pad: float
	var cell_tile: Array

	func setup(p_cols: int, p_rows: int, p_cell: float, p_pad: float, p_cell_tile: Array) -> void:
		cols = p_cols
		rows = p_rows
		cell = p_cell
		pad = p_pad
		cell_tile = p_cell_tile
		queue_redraw()

	func _draw() -> void:
		# Senkrechte Kanten zwischen benachbarten Spalten.
		for r in rows:
			for c in range(1, cols):
				if cell_tile[r][c] != cell_tile[r][c - 1]:
					var x := pad + c * cell
					_dashed(Vector2(x, pad + r * cell), Vector2(x, pad + (r + 1) * cell))
		# Waagerechte Kanten zwischen benachbarten Zeilen.
		for r in range(1, rows):
			for c in cols:
				if cell_tile[r][c] != cell_tile[r - 1][c]:
					var y := pad + r * cell
					_dashed(Vector2(pad + c * cell, y), Vector2(pad + (c + 1) * cell, y))
		# Außenkante des Bogens.
		var tl := Vector2(pad, pad)
		var tr := Vector2(pad + cols * cell, pad)
		var bl := Vector2(pad, pad + rows * cell)
		var br := Vector2(pad + cols * cell, pad + rows * cell)
		_dashed(tl, tr)
		_dashed(bl, br)
		_dashed(tl, bl)
		_dashed(tr, br)

	func _dashed(from: Vector2, to: Vector2) -> void:
		var delta := to - from
		var length := delta.length()
		if length <= 0.0:
			return
		var dir := delta / length
		var t := 0.0
		while t < length:
			var seg_end: float = minf(t + DASH, length)
			draw_line(from + dir * t, from + dir * seg_end, LINE_COLOR, LINE_WIDTH)
			t += DASH + DASH_GAP
