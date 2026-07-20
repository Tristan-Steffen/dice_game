class_name DiceGridView
extends GridContainer
## Gemeinsames Würfel-Raster: je Platz eine Kachel mit der AUGENSUMME (der Wert,
## nach dem man Würfel vergleicht); Seiten und Veredelungen stehen im Tooltip -
## in den flachen Tisch-Fenstern ist für ein Seiten-Raster je Kachel kein Platz.
## Zwei Nutzer, dieselbe Geste: die Werkstatt wählt damit den Pool-Platz eines
## Paket-Würfels, die Gravur-Station ihr Bearbeitungs-Ziel.

## Kachel index angeklickt (leere Plätze melden nichts).
signal slot_pressed(index: int)

const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")
const CYAN := Color("#8be9fd")

## Breiteneinheit; setzt der Aufrufer über place().
var u := 8.0
var tiles: Array[Button] = []

var _defs: Array[DieDefinition] = []
var _highlight := -1

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Spaltenzahl und Maßeinheit festlegen (vor fill).
func place(column_count: int, unit: float) -> void:
	columns = maxi(column_count, 1)
	u = unit
	add_theme_constant_override("h_separation", int(u * 0.6))
	add_theme_constant_override("v_separation", int(u * 0.6))

## Füllt das Raster; null-Einträge sind leere Plätze (stille Platzhalter).
func fill(defs: Array[DieDefinition], highlight_index: int = -1) -> void:
	_defs = defs
	_highlight = highlight_index
	tiles.clear()
	for child in get_children():
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
	if index == _highlight:
		return
	_highlight = index
	for i in tiles.size():
		if tiles[i] != null and is_instance_valid(tiles[i]):
			_style_tile(tiles[i], _defs[i], i == index)

func _tile(def: DieDefinition, highlighted: bool, index: int) -> Button:
	var tile := Button.new()
	tile.focus_mode = Control.FOCUS_NONE
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.custom_minimum_size = Vector2(u * 6.4, u * 4.6)
	tile.text = "%d" % DiceRowView.eye_total(def)
	tile.tooltip_text = _describe(def)
	tile.add_theme_font_size_override("font_size", maxi(8, int(u * 2.0)))
	tile.pressed.connect(func() -> void: slot_pressed.emit(index))
	_style_tile(tile, def, highlighted)
	return tile

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
	cell.custom_minimum_size = Vector2(u * 6.4, u * 4.6)
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
