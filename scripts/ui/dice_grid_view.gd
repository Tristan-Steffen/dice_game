class_name DiceGridView
extends GridContainer
## Gemeinsames Würfel-Raster in zwei Ausführungen, dieselbe Geste:
##   kompakt   - nur die AUGENSUMME je Kachel, Seiten im Tooltip. Für die enge
##               Pool-Auswahl beim Öffnen eines Würfel-Pakets.
##   detailliert - Augensumme ÜBER einem 3×2-Raster der Seiten in Material-
##               farbe, Rahmen im Essenzglühen. Für den Würfel-Editor,
##               wo man die Seiten vergleicht, bevor man graviert.
## Die Werkstatt wählt damit den Pool-Platz eines Paket-Würfels, die Gravur-
## Station ihr Bearbeitungs-Ziel.

## Kachel index angeklickt (leere Plätze melden nichts).
signal slot_pressed(index: int)
## Zwei Plätze sollen die Position tauschen (nur bei reorder_enabled).
signal slots_reordered(from_index: int, to_index: int)

## Umlegen per Ziehen - bewusst ABGESCHALTET voreingestellt: dasselbe Raster
## dient auch als reines Auswahl-Ziel (Tausch-Auswahl des Ladens), und dort
## wäre eine Zieh-Geste ein zweiter, ungewollter Weg in den Vorrat.
var reorder_enabled := false
## Platz, auf dem die Zieh-Geste begann (-1 = keine).
var _drag_from := -1

const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")
const CYAN := Color("#8be9fd")
## Tönung eines gesperrten Platzes: erkennbar tot, aber noch lesbar.
const LOCKED_TINT := Color(0.45, 0.45, 0.5)

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
## Gesperrte Plätze (laufende Runde) - gedimmt, aber weiter sichtbar.
var _locked: Array[int] = []
## Augensummen der Detail-Kacheln (nach Index) - so wechselt die Hervorhebung
## ihre Farbe, ohne das teure Raster neu zu bauen.
var _totals: Array[Label] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Drücken merkt sich den Platz, Loslassen über einer ANDEREN Kachel tauscht die
## beiden. Losgelassen über derselben Kachel bleibt es ein Klick - das Signal
## dafür hängt ohnehin schon am Knopf.
func _on_tile_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_drag_from = index
		return
	# Der Knopf fängt die Maus, das Loslassen meldet also IMMER die Ausgangs-
	# kachel - das Ziel muss über die Zeigerposition gesucht werden.
	var target := slot_at((event as InputEventMouseButton).global_position)
	if _drag_from >= 0 and target >= 0 and target != _drag_from:
		slots_reordered.emit(_drag_from, target)
	_drag_from = -1

## Platz unter der globalen Position (-1 = keiner) - das Loslassen landet auf der
## Kachel unter dem Zeiger, nicht auf der, auf der gedrückt wurde.
func slot_at(global_point: Vector2) -> int:
	for i in tiles.size():
		var tile := tiles[i]
		if tile != null and is_instance_valid(tile) and tile.get_global_rect().has_point(global_point):
			return i
	return -1

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
			if _locked.has(i):
				tile.modulate = LOCKED_TINT
			add_child(tile)
			tiles.append(tile)

## Plätze, die die laufende Runde sperrt - sie werden gedimmt. Halogen-Würfel
## stehen NICHT drin: ihre Werkstattlampe brennt weiter, also bleiben sie hell.
func set_locked_indices(indices: Array[int]) -> void:
	if indices == _locked:
		return
	_locked = indices.duplicate()
	for i in tiles.size():
		if tiles[i] != null:
			tiles[i].modulate = LOCKED_TINT if _locked.has(i) else Color.WHITE

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
	if reorder_enabled:
		tile.gui_input.connect(_on_tile_input.bind(index))
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

## Saum-Breite (in u) einer beseelten Kachel gegen die eines gewöhnlichen Würfels;
## bei ~17 px Zellgröße ist ein dünner Saum die Seele nicht zu finden wert.
const SOUL_BORDER_U := 0.45
const PLAIN_BORDER_U := 0.2
const SOUL_GLOW_ALPHA := 0.35

## Kachel-Saum: gold für das aktuelle Ziel, sonst das Essenzglühen
## bzw. Cyan bei normalen Würfeln - Spezialwürfel sind so vor Versehen geschützt.
## Eine Seele trägt zusätzlich dickeren Saum, Außenschein und getönten Grund; der
## Gold-Saum des Ziels gewinnt weiterhin, die Dicke bleibt.
func _style_tile(tile: Button, def: DieDefinition, highlighted: bool) -> void:
	var accent := CYAN
	var souled := def.essence_id != ""
	var glow := Color.TRANSPARENT
	if souled:
		glow = Essence.glow_for(def.essence_id)
		var lit := glow.lightened(0.15)
		accent = Color(lit.r * 1.25, lit.g * 1.25, lit.b * 1.25, glow.a)
	elif def.style_id != "normal":
		accent = GOLD
	var border := GOLD if highlighted else accent
	var bg := Color("#2c2757dd") if highlighted else Color("#221e46cc")
	if souled:
		var tinted := bg.lerp(glow, 0.16)
		bg = Color(tinted.r, tinted.g, tinted.b, bg.a)
	var width_u := SOUL_BORDER_U if souled else PLAIN_BORDER_U
	var glow_alpha := SOUL_GLOW_ALPHA if souled else 0.0
	tile.add_theme_color_override("font_color", GOLD if highlighted else TEXT_COLOR)
	tile.add_theme_stylebox_override("normal", _box(bg, border, width_u, glow_alpha))
	tile.add_theme_stylebox_override("hover", _box(Color("#2c2757dd"), GOLD))
	tile.add_theme_stylebox_override("pressed", _box(Color("#3a2f66"), GOLD))
	tile.add_theme_stylebox_override("focus", _box(bg, border, width_u, glow_alpha))

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
	if Essence.is_valid_id(def.essence_id):
		var essence := Essence.by_id(def.essence_id)
		text += "\n%s" % essence.display_name
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

func _box(bg: Color, border: Color, width_u := PLAIN_BORDER_U, glow_alpha := 0.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * width_u)))
	box.set_corner_radius_all(int(u * 0.7))
	box.set_content_margin_all(int(u * 0.3))
	if glow_alpha > 0.0:
		box.shadow_color = Color(border.r, border.g, border.b, glow_alpha)
		box.shadow_size = maxi(1, int(u * 0.6))
	return box
