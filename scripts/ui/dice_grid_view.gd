class_name DiceGridView
extends GridContainer
## Gemeinsames Würfel-Raster in zwei Ausführungen, dieselbe Geste:
##   kompakt   - nur die AUGENSUMME je Kachel, Seiten im Tooltip. Für die enge
##               Pool-Auswahl beim Öffnen eines Würfel-Pakets.
##   detailliert - Augensumme ÜBER einem 3×2-Raster der Seiten in Material-
##               farbe, Rahmen in der Kanten-Materialfarbe. Für den Würfel-Editor,
##               wo man die Seiten vergleicht, bevor man graviert.
## Die Werkstatt wählt damit den Pool-Platz eines Paket-Würfels, die Gravur-
## Station ihr Bearbeitungs-Ziel.

## Kachel index angeklickt (leere Plätze melden nichts).
signal slot_pressed(index: int)

const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")
const CYAN := Color("#8be9fd")

## Kantenlänge einer detaillierten Kachel und einer Seiten-Zelle (Einheiten u).
const DETAIL_TILE := 8.91
const DETAIL_CELL := 2.1

## Breiteneinheit; setzt der Aufrufer über place().
var u := 8.0
## Seiten je Kachel zeigen (Würfel-Editor) statt nur der Augensumme.
var detailed := false
var tiles: Array[Button] = []

var _defs: Array[DieDefinition] = []
## Hervorgehobene Plätze: EIN Ziel im Würfel-Editor, MEHRERE beim Einsetzen
## eines Würfel-Pakets.
var _highlights: Array[int] = []
## Augensummen der Detail-Kacheln (nach Index) - so wechselt die Hervorhebung
## ihre Farbe, ohne das teure Raster neu zu bauen.
var _totals: Array[Label] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Größte Maßeinheit, bei der ein detailliertes Raster columns×rows noch in avail
## passt - damit ein Aufrufer das Raster seinen Platz ausfüllen lassen kann.
static func unit_for(column_count: int, row_count: int, avail: Vector2) -> float:
	var span_w := column_count * DETAIL_TILE + (column_count - 1) * 0.6
	var span_h := row_count * DETAIL_TILE + (row_count - 1) * 0.6
	return maxf(1.0, minf(avail.x / span_w, avail.y / span_h))

## Spaltenzahl, Maßeinheit und Ausführung festlegen (vor fill).
func place(column_count: int, unit: float, with_faces: bool = false) -> void:
	columns = maxi(column_count, 1)
	u = unit
	detailed = with_faces
	add_theme_constant_override("h_separation", int(u * 0.6))
	add_theme_constant_override("v_separation", int(u * 0.6))

## Füllt das Raster; null-Einträge sind leere Plätze (stille Platzhalter).
func fill(defs: Array[DieDefinition], highlight_index: int = -1) -> void:
	_defs = defs
	_highlights.clear()
	if highlight_index >= 0:
		_highlights.append(highlight_index)
	tiles.clear()
	_totals.clear()
	_totals.resize(defs.size())
	for child in get_children():
		remove_child(child)  # erst abhängen: queue_free zählt sonst noch ins Mindestmaß
		child.queue_free()
	for i in defs.size():
		if defs[i] == null:
			add_child(_empty_tile())
			tiles.append(null)
		else:
			var tile := _tile(defs[i], i == highlight_index, i)
			add_child(tile)
			tiles.append(tile)

## Hebt einen anderen Platz hervor, ohne das Raster neu zu bauen.
func set_highlight(index: int) -> void:
	var single: Array[int] = []
	if index >= 0:
		single.append(index)
	set_highlights(single)

## Mehrere Plätze zugleich hervorheben (Paket-Würfel suchen ihre Plätze).
func set_highlights(indices: Array[int]) -> void:
	if indices == _highlights:
		return
	_highlights = indices.duplicate()
	for i in tiles.size():
		if tiles[i] == null or not is_instance_valid(tiles[i]):
			continue
		var on := _highlights.has(i)
		_style_tile(tiles[i], _defs[i], on)
		if i < _totals.size() and _totals[i] != null and is_instance_valid(_totals[i]):
			_totals[i].modulate = GOLD if on else TEXT_COLOR

func _tile(def: DieDefinition, highlighted: bool, index: int) -> Button:
	var tile := Button.new()
	tile.focus_mode = Control.FOCUS_NONE
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.custom_minimum_size = _tile_size()
	tile.tooltip_text = _describe(def)
	tile.pressed.connect(func() -> void: slot_pressed.emit(index))
	if detailed:
		_fill_detailed(tile, def, highlighted, index)
	else:
		tile.text = "%d" % DiceRowView.eye_total(def)
		tile.add_theme_font_size_override("font_size", maxi(8, int(u * 2.0)))
	_style_tile(tile, def, highlighted)
	return tile

func _tile_size() -> Vector2:
	if detailed:
		return Vector2.ONE * u * DETAIL_TILE
	return Vector2(u * 6.4, u * 4.6)

## Detail-Kachel: Augensumme über dem 3×2-Raster der Seiten (Material-Tönung).
func _fill_detailed(tile: Button, def: DieDefinition, highlighted: bool, index: int) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", maxi(1, int(u * 0.3)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(box)

	var total := Label.new()
	total.text = str(DiceRowView.eye_total(def))
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	total.add_theme_font_size_override("font_size", maxi(8, int(u * 2.08)))
	total.modulate = GOLD if highlighted else TEXT_COLOR
	total.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(total)
	if index < _totals.size():
		_totals[index] = total

	var faces := GridContainer.new()
	faces.columns = 3
	faces.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faces.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	faces.add_theme_constant_override("h_separation", maxi(1, int(u * 0.25)))
	faces.add_theme_constant_override("v_separation", maxi(1, int(u * 0.25)))
	for face_index in _faces_sorted_by_value(def):
		var material_id: String = def.materials[face_index] if face_index < def.materials.size() else ""
		faces.add_child(_face_cell(def.faces[face_index], material_id))
	box.add_child(faces)

## Seiten-Indizes nach Augenzahl aufsteigend - die Kachel liest wie "1-6".
func _faces_sorted_by_value(def: DieDefinition) -> Array[int]:
	var order: Array[int] = []
	for i in def.faces.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if def.faces[a] != def.faces[b]:
			return def.faces[a] < def.faces[b]
		return a < b)
	return order

## Eine Seite: Ziffer auf der Materialfarbe (Weiß ohne Material).
func _face_cell(value: int, material_id: String) -> Control:
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2.ONE * u * DETAIL_CELL
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = DieMaterial.tint_for(material_id)
	box.border_color = Color(0, 0, 0, 0.35)
	box.set_border_width_all(maxi(1, int(u * 0.1)))
	box.set_corner_radius_all(maxi(1, int(u * 0.3)))
	cell.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = str(value)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", maxi(8, int(u * 1.54)))
	label.add_theme_color_override("font_color", CasinoStyle.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(label)
	return cell

## Kachel-Saum: gold für das aktuelle Ziel, sonst die Farbe des Kanten-Materials
## bzw. Cyan bei normalen Würfeln - Spezialwürfel sind so vor Versehen geschützt.
func _style_tile(tile: Button, def: DieDefinition, highlighted: bool) -> void:
	var accent := CYAN
	if def.edge_material != "":
		accent = DieMaterial.tint_for(def.edge_material)
	elif def.style_id != "normal":
		accent = GOLD
	var border := GOLD if highlighted else accent
	var bg := Color("#2c2757dd") if highlighted else Color("#221e46cc")
	tile.add_theme_color_override("font_color", GOLD if highlighted else TEXT_COLOR)
	tile.add_theme_stylebox_override("normal", _box(bg, border))
	tile.add_theme_stylebox_override("hover", _box(Color("#2c2757dd"), GOLD))
	tile.add_theme_stylebox_override("pressed", _box(Color("#3a2f66"), GOLD))
	tile.add_theme_stylebox_override("focus", _box(bg, border))

## Tooltip: Name, Augensumme, Seiten (aufsteigend) und Veredelungen.
func _describe(def: DieDefinition) -> String:
	var values: Array[int] = []
	for v in def.faces:
		values.append(v)
	values.sort()
	var parts := PackedStringArray()
	for v in values:
		parts.append(str(v))
	var text := "%s\nAugensumme %d\nSeiten: %s" % [
		def.display_name, DiceRowView.eye_total(def), " ".join(parts)]
	if def.edge_material != "":
		text += "\n%s-Kanten" % DieMaterial.by_id(def.edge_material).display_name
	return text

## Leerer Platz: stiller Platzhalter, damit das Raster die Lücken spiegelt.
func _empty_tile() -> Control:
	var cell := Panel.new()
	cell.custom_minimum_size = _tile_size()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#181534aa")
	box.border_color = Color("#282350")
	box.set_border_width_all(maxi(1, int(u * 0.15)))
	box.set_corner_radius_all(int(u * 0.7))
	cell.add_theme_stylebox_override("panel", box)
	return cell

func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.2)))
	box.set_corner_radius_all(int(u * 0.7))
	box.set_content_margin_all(int(u * 0.3))
	return box
