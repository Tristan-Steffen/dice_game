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

## Zellgröße des Würfelnetzes (Einheiten u) und der Rand der Kachel darum; die
## Kachelgröße wird DARAUS abgeleitet (detail_tile_size), damit Netz und Kachel
## nie auseinanderlaufen. TOTAL_BAND ist die Zeile der Augensumme über dem Netz.
## Zellgröße des Würfelnetzes und der Rand der Kachel darum. Die Augensumme
## braucht KEINEN eigenen Streifen mehr: sie sitzt in der leeren oberen rechten
## Kreuz-Ecke (DieNetView.total_badge), also wird die Kachel genau so groß wie
## das Netz - alle 30 Kacheln teilen sich eine feste Fläche, jeder gesparte
## Streifen wird zu größeren Zellen.
const DETAIL_CELL := 2.0
const TILE_PAD := 0.4

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

## Maße einer detaillierten Kachel bei Einheit unit: das Würfelnetz plus Rand.
static func detail_tile_size(unit: float) -> Vector2:
	return DieNetView.net_size(unit * DETAIL_CELL) + Vector2.ONE * unit * TILE_PAD * 2.0

## Größte Maßeinheit, bei der ein detailliertes Raster columns×rows noch in avail
## passt - damit ein Aufrufer das Raster seinen Platz ausfüllen lassen kann.
static func unit_for(column_count: int, row_count: int, avail: Vector2) -> float:
	var tile := detail_tile_size(1.0)
	var span_w := column_count * tile.x + (column_count - 1) * 0.6
	var span_h := row_count * tile.y + (row_count - 1) * 0.6
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
		return detail_tile_size(u)
	return Vector2(u * 6.4, u * 4.6)

## Detail-Kachel: das WÜRFELNETZ wie im Netzfeld der Grube, damit Materialien
## UND Leiterbahnen hier wie dort gelesen werden - die Augensumme sitzt in der
## leeren oberen rechten Kreuz-Ecke. Keine oben liegende Seite: im Lager liegt
## kein Würfel.
func _fill_detailed(tile: Button, def: DieDefinition, highlighted: bool, index: int) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(center)

	var cell := u * DETAIL_CELL
	var net := DieNetView.build(def, -1, cell)
	center.add_child(net)

	var total := DieNetView.total_badge(def, cell)
	total.modulate = GOLD if highlighted else TEXT_COLOR
	net.add_child(total)
	if index < _totals.size():
		_totals[index] = total

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
