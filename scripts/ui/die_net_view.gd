class_name DieNetView
## Statischer Bauhelfer des Würfelnetzes: alle 6 Seiten eines Würfels als
## aufgeklapptes Kreuz. Zellfarbe = Seiten-Material, Zellrahmen = Essenzglühen
## (Echo der Kanten), Gold-Rahmen markiert die oben liegende Seite. In der leeren
## oberen linken Kreuz-Ecke sitzt der Essenz-Chip (eine getönte Raute) - fester
## Platz, an dem die Seele des Würfels lebt; leer bleibt er als schwacher Umriss.

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

## Leiterbahn-Pfeile: Farbe wie das Siegel (Ätzungs-Cyan).
const POINTER_COLOR := Color("#8be9fd")

## Stufen-Plakette (ab Stufe II) in der unteren RECHTEN Zellecke - Kantenanteil.
## Die Ecke ist frei: die Zeiger-Pfeile sitzen mittig auf den Zellrändern.
const LEVEL_BADGE := 0.34
## Je Seite: welcher Zellrand der gequerten Würfelkante zum Nachbarn entspricht,
## wenn das Kreuz gefaltet wird. Nachbarzellen liegen im Netz nicht immer
## nebeneinander (5->1 wickelt herum) - darum Pfeil AM Rand, kein Verbindungsstrich.
const POINTER_SIDES := {
	0: {3: Vector2.UP, 2: Vector2.DOWN, 1: Vector2.LEFT, 4: Vector2.RIGHT},
	1: {3: Vector2.UP, 2: Vector2.DOWN, 5: Vector2.LEFT, 0: Vector2.RIGHT},
	2: {0: Vector2.UP, 5: Vector2.DOWN, 1: Vector2.LEFT, 4: Vector2.RIGHT},
	3: {5: Vector2.UP, 0: Vector2.DOWN, 1: Vector2.LEFT, 4: Vector2.RIGHT},
	4: {3: Vector2.UP, 2: Vector2.DOWN, 0: Vector2.LEFT, 5: Vector2.RIGHT},
	5: {3: Vector2.UP, 2: Vector2.DOWN, 4: Vector2.LEFT, 1: Vector2.RIGHT},
}

## Gesamtgröße des Netzes bei Zellgröße cell (4 Spalten × 3 Zeilen + Lücken).
static func net_size(cell: float) -> Vector2:
	var gap := cell * GAP_FACTOR
	return Vector2(4.0 * cell + 3.0 * gap, 3.0 * cell + 2.0 * gap)

## Größte Zellgröße, bei der das Netz noch in avail passt.
static func cell_for(avail: Vector2) -> float:
	var span := net_size(1.0)
	return maxf(1.0, minf(avail.x / span.x, avail.y / span.y))

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
	for crack in rift_cracks(def, cell):
		root.add_child(crack)
	for badge in level_badges(def, cell):
		root.add_child(badge)
	for arrow in _pointer_arrows(def, cell):
		root.add_child(arrow)
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

## Kurz-Erklärzeile zu einer Netz-Zelle: Materialname + Kurzwirkung (face_hint),
## dazu die Leiterbahn und die Risse dieser Seite; der Kanten-Chip (EDGE) erklärt
## die Seele des Würfels. "" für eine nackte Seite oder außerhalb des Kreuzes.
## EINE Quelle für alle Netze - Grube wie Werkbank.
static func hint_for(def: DieDefinition, face: int) -> String:
	if def == null:
		return ""
	if face == EDGE:
		return Essence.hint(def.essence_id)
	if face < 0 or face >= def.materials.size():
		return ""
	var hint := DieMaterial.face_hint(def.materials[face], MaterialEffects.face_level(def, face))
	var target: int = def.pointers[face] if face < def.pointers.size() else -1
	if target >= 0:
		var pointer_hint := "Leiterbahn: löst die Seite mit Wert %d zu 50 %% einmal mit aus" % def.faces[target]
		hint = "%s  ·  %s" % [hint, pointer_hint] if hint != "" else pointer_hint
	for rift_id in def.rifts_on(face):
		var rift_hint := Rift.hint(rift_id)
		hint = "%s  ·  %s" % [hint, rift_hint] if hint != "" else rift_hint
	return hint

## Seiten-Zelle im Look der Würfelseiten-Chips (DiceRowView).
static func _face_cell(def: DieDefinition, face_index: int, pos: Vector2, cell: float) -> Label:
	var value: int = def.faces[face_index] if face_index < def.faces.size() else 1
	var material_id: String = def.materials[face_index] if face_index < def.materials.size() else ""
	# Die Stufe sättigt die Zelle - der Blick von weitem. Die Balken der Plakette
	# bleiben daneben das genaue, zählbare Maß.
	var fill := DieMaterial.tint_for(material_id, def.material_level(face_index))
	var chip := Label.new()
	chip.text = str(value)
	chip.position = pos
	chip.size = Vector2(cell, cell)
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_font_size_override("font_size", maxi(8, int(cell * 0.5)))
	chip.add_theme_color_override("font_color", CasinoStyle.INK)
	# Saum in der Plattenfarbe: auf der Zelle unsichtbar, aber dort, wo eine
	# Risslinie die Ziffer kreuzt, hält er sie frei. Dasselbe Trennband wie am
	# 3D-Würfel, nur trennt es hier gegen die Linie statt gegen den Bloom.
	chip.add_theme_color_override("font_outline_color", fill)
	chip.add_theme_constant_override("outline_size", maxi(1, int(cell * 0.06)))
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	var has_essence := Essence.is_valid_id(def.essence_id)
	box.border_color = Essence.glow_for(def.essence_id) if has_essence else DiceRowView.CHIP_BORDER
	# Essenzglühen dick und farbig, sonst dezente Haarlinie.
	box.set_border_width_all(maxi(2, int(cell * (0.1 if has_essence else 0.04))))
	box.set_corner_radius_all(int(cell * 0.2))
	chip.add_theme_stylebox_override("normal", box)
	return chip

## Essenz-Chip in der leeren oberen linken Kreuz-Ecke: eine auf die Spitze
## gestellte Raute (der Würfel Kante-von-vorn) im Essenzglühen; ohne Essenz nur
## ein schwacher Umriss - der Platz bleibt, damit der Spieler die Seele des
## Würfels immer hier findet.
static func _edge_chip(def: DieDefinition, cell: float) -> Panel:
	var d := cell * 0.62
	var chip := Panel.new()
	chip.size = Vector2(d, d)
	chip.pivot_offset = Vector2(d, d) / 2.0
	chip.rotation = deg_to_rad(45.0)
	# Auf die Mitte der Ecke EDGE_CELL zentriert (Zeile 0, Spalte 0).
	chip.position = Vector2(EDGE_CELL.y, EDGE_CELL.x) * cell + Vector2(cell - d, cell - d) / 2.0
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var has_essence := Essence.is_valid_id(def.essence_id)
	var box := StyleBoxFlat.new()
	box.bg_color = Essence.glow_for(def.essence_id) if has_essence else Color(1, 1, 1, 0.04)
	box.border_color = DiceRowView.CHIP_BORDER if has_essence else Color(0.72, 0.76, 0.8, 0.3)
	box.set_border_width_all(maxi(2, int(cell * 0.08)))
	box.set_corner_radius_all(maxi(1, int(cell * 0.12)))
	chip.add_theme_stylebox_override("panel", box)
	return chip

## Zellposition eines Seiten-Index im Kreuz - damit fremde Aufrufer (die
## Gravur-Station) EIGENE, anklickbare Zellen im selben Kreuz platzieren können.
static func cell_position(face_index: int, cell: float) -> Vector2:
	return _cell_pos(face_index, cell)

## Augensumme in der leeren oberen RECHTEN Kreuz-Ecke: gegenüber dem Kanten-Chip
## und rechts neben der oberen Seite - der einzige tote Raum im Kreuz, und damit
## braucht die Kachel darüber keinen eigenen Streifen mehr.
static func total_badge(def: DieDefinition, cell: float) -> Label:
	var gap := cell * GAP_FACTOR
	var badge := Label.new()
	badge.text = str(DiceRowView.eye_total(def))
	badge.position = Vector2(2.0 * (cell + gap), 0.0)
	badge.size = Vector2(2.0 * cell + gap, cell)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_font_size_override("font_size", maxi(8, int(cell * 0.8)))
	return badge

## Kanten-Chip und Leiterbahn-Pfeile einzeln, für denselben Zweck.
static func edge_chip(def: DieDefinition, cell: float) -> Panel:
	return _edge_chip(def, cell)

static func pointer_arrows(def: DieDefinition, cell: float) -> Array[Control]:
	return _pointer_arrows(def, cell)

## Je gehobener Seite eine Plakette in ihrer unteren rechten Zellecke. Stufe I
## bleibt unmarkiert - sie ist der Normalfall, und eine Marke auf jeder Material-
## Zelle wäre Rauschen. Geometrie statt Schrift: im 30er-Raster misst eine Zelle
## nur ~17 px, eine Ziffer wäre dort Matsch - die helle Platte trägt allein, die
## Balken ("II"/"III") lösen erst an der Station auf.
static func level_badges(def: DieDefinition, cell: float) -> Array[Control]:
	var badges: Array[Control] = []
	for face in mini(6, def.levels.size()):
		var level: int = def.levels[face]
		if level < 2:
			continue
		var badge := LevelBadge.new()
		badge.level = level
		badge.tint = DieMaterial.tint_for(
			def.materials[face] if face < def.materials.size() else "", level)
		var side := cell * LEVEL_BADGE
		var inset := cell * 0.04
		badge.size = Vector2(side, side)
		badge.position = _cell_pos(face, cell) + Vector2.ONE * (cell - side - inset)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badges.append(badge)
	return badges

## Je gebrochener Seite die Risslinien AUSSEN UM DIE ZIFFER HERUM: die Mitte ist
## der unfreieste Platz der Zelle, nicht der freieste (Rift.GLYPH_KEEPOUT). Ein
## Bruch läuft ohnehin von Rand zu Rand, also fallen Echtheit und Lesbarkeit
## zusammen. Geometrie statt Typo: bei ~17 px Zelle liest sich ein Linienzug, eine
## Ziffer nicht. Das Vakuum bricht schwarz.
static func rift_cracks(def: DieDefinition, cell: float) -> Array[Control]:
	var cracks: Array[Control] = []
	for face in mini(6, def.rifts.size()):
		for rift_id in def.rifts_on(face):
			var rift := Rift.by_id(rift_id)
			if rift == null:
				continue
			var crack := RiftCrack.new()
			crack.face = face
			crack.lines = Rift.crack_lines(rift.pattern)
			crack.weights = Rift.crack_weights(rift.pattern)
			crack.tint = RiftEffects.crack_color(rift_id, def.essence_id)
			crack.core = rift.core
			crack.size = Vector2.ONE * cell
			crack.position = _cell_pos(face, cell)
			crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cracks.append(crack)
	return cracks

## Der Riss selbst: heller Linienzug auf dunklem Unterzug - dieselbe Sprache wie
## Zeiger-Pfeile und Stufen-Plakette, damit er auch auf einer hellen Material-
## Zelle steht.
##
## Das Netz animiert NICHT. 30 Würfel × bis zu 6 Risse hieße bis zu 180 Controls,
## die je Frame neu zeichnen - für eine Figur von 9 px Breite. Die Werkbank ist
## eine Lesefläche, keine Bühne. Einzige Ausnahme ist die Grubenkarte, die beim
## Zählen ohnehin schon lebt: sie setzt flare, und das wirkt allein auf Farbe und
## Breite. Ein wandernder Kopf ist bei Kartengröße nicht darstellbar; heller und
## dicker ist die ehrliche Übersetzung von "hat gefeuert".
class RiftCrack:
	extends Control
	## Seite, auf der dieser Riss sitzt - die Grubenkarte lässt gezielt SIE
	## aufblitzen, nie das ganze Netz.
	var face: int = -1
	var lines: Array[PackedVector2Array] = []
	var weights := PackedFloat32Array()
	var tint := Color.WHITE
	var core := Color.WHITE
	var flare: float = 0.0

	func _draw() -> void:
		for index in lines.size():
			var line: PackedVector2Array = lines[index]
			if line.size() < 2:
				continue
			var points := PackedVector2Array()
			for point in line:
				points.append(point * size)
			# 1-px-Boden: bei 17 px Zelle würde eine 0.45er Gabel sonst verschwinden.
			var weight: float = weights[index] if index < weights.size() else 1.0
			var width := maxf(1.0, size.x * 0.055 * weight) * (1.0 + 0.8 * flare)
			# Unterzug zuerst, dann die Kernlinie darüber.
			draw_polyline(points, Color(0.03, 0.05, 0.12, 0.9), width * 2.0)
			draw_polyline(points, tint.lerp(core, flare), width)

## Die Plakette selbst: dunkle Platte mit einem hellen Balken je Stufe in der
## Materialfarbe - dieselbe Sprache wie die Zeiger-Pfeile (heller Strich auf
## dunklem Unterzug). Die dunkle Platte trägt allein, wenn die Balken bei
## winzigen Zellen zu Textur zerfallen: jede Material-Zelle ist hell.
class LevelBadge:
	extends Control
	var tint := Color.WHITE
	var level := 2

	func _draw() -> void:
		var mark := tint.lightened(0.35)
		mark.a = 1.0
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.12, 0.95), true)
		draw_rect(Rect2(Vector2.ZERO, size), mark, false, maxf(1.0, size.x * 0.09))
		var bars := clampi(level, 2, DieMaterial.MAX_LEVEL)
		# Drei Balken brauchen schmalere Striche, sonst laufen sie zusammen.
		var bar_w := maxf(1.0, size.x * (0.15 if bars < 3 else 0.11))
		var bar_h := size.y * 0.46
		var top := (size.y - bar_h) * 0.5
		var step := size.x * 0.26
		for b in bars:
			var cx: float = size.x * 0.5 + (float(b) - float(bars - 1) * 0.5) * step - bar_w * 0.5
			draw_rect(Rect2(Vector2(cx, top), Vector2(bar_w, bar_h)), mark, true)

## Zellposition eines Seiten-Index im Kreuz.
static func _cell_pos(face_index: int, cell: float) -> Vector2:
	var gap := cell * GAP_FACTOR
	for row in NET_LAYOUT.size():
		for col in NET_LAYOUT[row].size():
			if NET_LAYOUT[row][col] == face_index:
				return Vector2(col * (cell + gap), row * (cell + gap))
	return Vector2.ZERO

## Je Leiterbahn ein Pfeil auf dem Zellrand der gequerten Kante, nach außen zeigend.
static func _pointer_arrows(def: DieDefinition, cell: float) -> Array[Control]:
	var arrows: Array[Control] = []
	for face in def.pointers.size():
		var target: int = def.pointers[face]
		if target < 0:
			continue
		var sides: Dictionary = POINTER_SIDES.get(face, {})
		if not sides.has(target):
			continue  # keine Nachbarseite - ungültiger Zeiger bleibt stumm
		var dir: Vector2 = sides[target]
		var arrow := PointerArrow.new()
		arrow.dir = dir
		var side := cell * 0.5
		arrow.size = Vector2(side, side)
		arrow.position = _cell_pos(face, cell) + Vector2(cell, cell) * 0.5 \
			+ dir * cell * 0.5 - Vector2(side, side) * 0.5
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrows.append(arrow)
	return arrows

## Der Pfeil selbst: Schaft + Spitze mit dunklem Unterzug, damit er auch auf
## hellen Material-Zellen lesbar bleibt.
class PointerArrow:
	extends Control
	var dir := Vector2.RIGHT

	func _draw() -> void:
		var center := size * 0.5
		var half := size.x * 0.40
		var w := maxf(2.0, size.x * 0.13)
		var perp := Vector2(-dir.y, dir.x)
		var tip := center + dir * half
		var tail := center - dir * half
		var shaft_end := tip - dir * w * 2.2
		var head := PackedVector2Array([tip, shaft_end + perp * w * 1.7, shaft_end - perp * w * 1.7])
		var under := Color(0.03, 0.05, 0.12, 0.9)
		draw_line(tail, shaft_end, under, w * 2.2)
		var grown := PackedVector2Array()
		for p in head:
			grown.append(center + (p - center) * 1.35)
		draw_colored_polygon(grown, under)
		draw_line(tail, shaft_end, DieNetView.POINTER_COLOR, w)
		draw_colored_polygon(head, DieNetView.POINTER_COLOR)

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
