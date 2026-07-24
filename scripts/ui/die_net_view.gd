class_name DieNetView
## Statischer Bauhelfer des Würfelnetzes: alle 6 Seiten eines Würfels als
## aufgeklapptes Kreuz. Zellfarbe = Seiten-Material, Zellrahmen = Kanten-Material
## (Echo der Kante), Gold-Rahmen markiert die oben liegende Seite. In der leeren
## oberen linken Kreuz-Ecke sitzt der Kanten-Chip (eine getönte Raute) - fester
## Platz, an dem die Kante lebt; leer bleibt er als schwacher Umriss.

const GAP_FACTOR := 0.1  # Zellabstand relativ zur Zellgröße

# Kreuz-Layout Zelle -> physischer Face-Index (DiceController.AXIS_FACE_INDEX):
#          [OBEN=3]
# [LINKS=1][VORNE=0][RECHTS=4][HINTEN=5]
#          [UNTEN=2]
const NET_LAYOUT := [
	[-1, 3, -1, -1],
	[1, 0, 4, 5],
	[-1, 2, -1, -1],
]

## face_at-Sonderwert für den Kanten-Chip (kein Seiten-Index, kleiner als -1).
const EDGE := -2
## Kreuz-Ecke des Kanten-Chips (Zeile, Spalte) - leer im NET_LAYOUT.
const EDGE_CELL := Vector2i(0, 0)

## Gesamtgröße des Netzes bei Zellgröße cell (4 Spalten × 3 Zeilen + Lücken).
static func net_size(cell: float) -> Vector2:
	var gap := cell * GAP_FACTOR
	return Vector2(4.0 * cell + 3.0 * gap, 3.0 * cell + 2.0 * gap)

## Baut das Netz; up_face (-1 = keiner) bekommt den Gold-Rahmen.
static func build(def: DieDefinition, up_face: int, cell: float) -> Control:
	var root := Control.new()
	root.custom_minimum_size = net_size(cell)
	root.size = root.custom_minimum_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gap := cell * GAP_FACTOR
	for row in NET_LAYOUT.size():
		for col in NET_LAYOUT[row].size():
			var face_index: int = NET_LAYOUT[row][col]
			if face_index < 0:
				continue
			var pos := Vector2(col * (cell + gap), row * (cell + gap))
			if face_index == up_face:
				root.add_child(_up_frame(pos, cell))
			root.add_child(_face_cell(def, face_index, pos, cell))
	root.add_child(_edge_chip(def, cell))
	return root

## Face-Index der Zelle unter local (Netz-Lokalkoordinaten, Zellgröße cell);
## EDGE über der Kanten-Chip-Ecke, -1 in Lücken und außerhalb des Kreuzes.
static func face_at(local: Vector2, cell: float) -> int:
	var step := cell * (1.0 + GAP_FACTOR)
	var col := int(floorf(local.x / step))
	var row := int(floorf(local.y / step))
	if row < 0 or row >= NET_LAYOUT.size() or col < 0 or col >= NET_LAYOUT[row].size():
		return -1
	# In der Lücke zwischen den Zellen zählt nichts.
	if local.x - col * step > cell or local.y - row * step > cell:
		return -1
	if row == EDGE_CELL.x and col == EDGE_CELL.y:
		return EDGE
	return NET_LAYOUT[row][col]

## Seiten-Zelle im Look der Würfelseiten-Chips (DiceRowView).
static func _face_cell(def: DieDefinition, face_index: int, pos: Vector2, cell: float) -> Label:
	var value: int = def.faces[face_index] if face_index < def.faces.size() else 1
	var material_id: String = def.materials[face_index] if face_index < def.materials.size() else ""
	var chip := Label.new()
	chip.text = str(value)
	chip.position = pos
	chip.size = Vector2(cell, cell)
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_font_size_override("font_size", maxi(8, int(cell * 0.5)))
	chip.add_theme_color_override("font_color", CasinoStyle.INK)
	var box := StyleBoxFlat.new()
	box.bg_color = DieMaterial.tint_for(material_id)
	var has_edge := DieMaterial.is_valid_id(def.edge_material)
	box.border_color = DieMaterial.tint_for(def.edge_material) if has_edge else DiceRowView.CHIP_BORDER
	# Kanten-Material dick und farbig, sonst dezente Haarlinie.
	box.set_border_width_all(maxi(2, int(cell * (0.1 if has_edge else 0.04))))
	box.set_corner_radius_all(int(cell * 0.2))
	chip.add_theme_stylebox_override("normal", box)
	return chip

## Kanten-Chip in der leeren oberen linken Kreuz-Ecke: eine auf die Spitze
## gestellte Raute (der Würfel Kante-von-vorn) in der Kanten-Materialfarbe;
## ohne Kante nur ein schwacher Umriss - der Platz bleibt, damit der Spieler
## die Kante immer hier findet.
static func _edge_chip(def: DieDefinition, cell: float) -> Panel:
	var d := cell * 0.62
	var chip := Panel.new()
	chip.size = Vector2(d, d)
	chip.pivot_offset = Vector2(d, d) / 2.0
	chip.rotation = deg_to_rad(45.0)
	# Auf die Mitte der Ecke EDGE_CELL zentriert (Zeile 0, Spalte 0).
	chip.position = Vector2(EDGE_CELL.y, EDGE_CELL.x) * cell + Vector2(cell - d, cell - d) / 2.0
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var has_edge := DieMaterial.is_valid_id(def.edge_material)
	var box := StyleBoxFlat.new()
	box.bg_color = DieMaterial.tint_for(def.edge_material) if has_edge else Color(1, 1, 1, 0.04)
	box.border_color = DiceRowView.CHIP_BORDER if has_edge else Color(0.72, 0.76, 0.8, 0.3)
	box.set_border_width_all(maxi(2, int(cell * 0.08)))
	box.set_corner_radius_all(maxi(1, int(cell * 0.12)))
	chip.add_theme_stylebox_override("panel", box)
	return chip

## Gold-Rahmen um die oben liegende Seite (liegt HINTER der Zelle).
static func _up_frame(pos: Vector2, cell: float) -> Panel:
	var pad := cell * 0.09 + 2.0
	var frame := Panel.new()
	frame.position = pos - Vector2(pad, pad)
	frame.size = Vector2(cell + pad * 2.0, cell + pad * 2.0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = CasinoStyle.GOLD
	box.set_border_width_all(maxi(2, int(cell * 0.06)))
	box.set_corner_radius_all(int(cell * 0.26))
	frame.add_theme_stylebox_override("panel", box)
	return frame
