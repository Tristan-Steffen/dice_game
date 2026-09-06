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

## Zellgröße des Würfelnetzes (Einheiten u) und der Rand der Kachel darum; die
## Kachelgröße wird DARAUS abgeleitet (detail_tile_size), damit Netz und Kachel
## nie auseinanderlaufen. TOTAL_BAND ist die Zeile der Augensumme über dem Netz.
## Zellgröße des Würfelnetzes und der Rand der Kachel darum. Die Augensumme
## braucht KEINEN eigenen Streifen mehr: sie sitzt in der leeren unteren rechten
## Kreuz-Ecke (DieNetView.total_badge), also wird die Kachel genau so groß wie
## das Netz - alle 30 Kacheln teilen sich eine feste Fläche, jeder gesparte
## Streifen wird zu größeren Zellen.
const DETAIL_CELL := 2.0
const TILE_PAD := 0.4
## Fuge zwischen zwei Kacheln (Einheiten u). EINE Quelle: place() setzt sie, und
## detail_span rechnet mit derselben Zahl - sonst löst ein Aufrufer sein Raster
## auf eine Breite auf, die der Kasten nachher gar nicht einnimmt.
const SEPARATION := 0.6

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

## Erklärzeile zur Kachel unter pixel ("" = leerer Platz, keine Kachel oder ein
## Würfel ohne Seele). Die Seele ist das EINZIGE, was die Kachel nicht selbst
## zeigt: Materialien, Stufen und Pointer stehen im Netz, aber das Glühen
## des Saums nennt keinen Namen. GEFRAGT statt gemeldet - dieselbe Lösung wie am
## Netzfeld der Grube, und dieselbe Quelle wie der Essenz-Chip (Essence.hint).
func hint_at(pixel: Vector2) -> String:
	var index := slot_at(pixel)
	if index < 0 or index >= _defs.size() or _defs[index] == null:
		return ""
	return Essence.hint(_defs[index].essence_id)

## Maße einer detaillierten Kachel bei Einheit unit: das Würfelnetz plus Rand.
static func detail_tile_size(unit: float) -> Vector2:
	return DieNetView.net_size(unit * DETAIL_CELL) + Vector2.ONE * unit * TILE_PAD * 2.0

## Maße eines detaillierten Rasters columns×rows bei Einheit 1 - daraus folgt die
## Einheit (unit_for), mit der ein Aufrufer sein Raster den Platz ausfüllen läßt.
static func detail_span(column_count: int, row_count: int) -> Vector2:
	var tile := detail_tile_size(1.0)
	return Vector2(column_count * tile.x + (column_count - 1) * SEPARATION,
		row_count * tile.y + (row_count - 1) * SEPARATION)

## Größte Maßeinheit, bei der ein detailliertes Raster columns×rows noch in avail
## passt - damit ein Aufrufer das Raster seinen Platz ausfüllen lassen kann.
static func unit_for(column_count: int, row_count: int, avail: Vector2) -> float:
	var span := detail_span(column_count, row_count)
	return maxf(1.0, minf(avail.x / span.x, avail.y / span.y))

## Spaltenzahl, Maßeinheit und Ausführung festlegen (vor fill).
func place(column_count: int, unit: float, with_faces: bool = false) -> void:
	columns = maxi(column_count, 1)
	u = unit
	detailed = with_faces
	add_theme_constant_override("h_separation", int(u * SEPARATION))
	add_theme_constant_override("v_separation", int(u * SEPARATION))

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
## UND Pointer hier wie dort gelesen werden - die Augensumme sitzt in der
## leeren unteren rechten Kreuz-Ecke, die Ladungs-Lampen oben rechts. Keine oben
## liegende Seite: im Lager liegt kein Würfel.
func _fill_detailed(tile: Button, def: DieDefinition, highlighted: bool, index: int) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(center)

	var cell := u * DETAIL_CELL
	var net := DieNetView.build(def, -1, cell)
	if def.burned_out:
		net.modulate = BURNED_NET_DIM  # tot, nicht heiß
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

## Die LADUNG als FARBSTUFE über der Seelen-Grundlage: der Saum wandert stufenweise
## in die Ladungsfarbe und bekommt ihren Außenschein - so sortiert der Spieler den
## Vorrat nach Ladung, ohne jeden Würfel anzusehen. EINE Farbquelle ist der Würfel
## selbst (DieFaceDisplay.CHARGE_COLOR).
const CHARGE_TINT := DieFaceDisplay.CHARGE_COLOR
const CHARGE_STEPS := [0.0, 0.35, 0.7, 1.0]
const CHARGE_GLOW_ALPHA := 0.55
## Durchgebrannt: dunkle Kachel, matter Saum, gedimmtes Netz.
const BURNED_BG := Color("#17141fff")
const BURNED_BORDER := Color(0.32, 0.29, 0.31)
const BURNED_NET_DIM := Color(0.45, 0.42, 0.45, 1.0)

## Kachel-Saum: gold für das aktuelle Ziel, sonst das Essenzglühen
## bzw. Cyan bei normalen Würfeln - Spezialwürfel sind so vor Versehen geschützt.
## Eine Seele trägt zusätzlich dickeren Saum, Außenschein und getönten Grund; der
## Gold-Saum des Ziels gewinnt weiterhin, die Dicke bleibt.
func _style_tile(tile: Button, def: DieDefinition, highlighted: bool) -> void:
	tile.add_theme_color_override("font_color", GOLD if highlighted else TEXT_COLOR)
	tile.add_theme_stylebox_override("normal", tile_box(def, u, highlighted))
	tile.add_theme_stylebox_override("hover", box(u, Color("#2c2757ff"), GOLD))
	tile.add_theme_stylebox_override("pressed", box(u, Color("#3a2f66"), GOLD))
	tile.add_theme_stylebox_override("focus", tile_box(def, u, highlighted))

## Die FASSUNG einer Würfel-Kachel als reine Funktion - EINE Quelle für das
## Raster der Glas-Ansicht UND für die Zellen der Reparatur-Bucht.
static func tile_box(def: DieDefinition, unit: float, highlighted: bool) -> StyleBoxFlat:
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
	# Voll deckend: auf dem Gruben-Glas darf durch eine Kachel kein versenkter Würfel
	# durchscheinen (die Fuge trägt das durchsichtige Glas, nicht die Kachel).
	var bg := Color("#2c2757ff") if highlighted else Color("#221e46ff")
	if souled:
		var tinted := bg.lerp(glow, 0.16)
		bg = Color(tinted.r, tinted.g, tinted.b, bg.a)
	var width_u := SOUL_BORDER_U if souled else PLAIN_BORDER_U
	var glow_alpha := SOUL_GLOW_ALPHA if souled else 0.0
	# Die LADUNG legt sich ALS ZWEITER SAUM über die Seelen-Grundlage; Ruß nimmt
	# beides zurück (der Würfel ist tot, nicht heiß).
	if def.burned_out:
		if not highlighted:
			border = BURNED_BORDER  # der Gold-Saum des Ziels gewinnt weiterhin
		bg = BURNED_BG
		width_u = PLAIN_BORDER_U
		glow_alpha = 0.0
	elif def.charge > 0:
		var heat := float(CHARGE_STEPS[clampi(def.charge, 0, DieDefinition.CHARGE_MAX)])
		if not highlighted:
			border = border.lerp(CHARGE_TINT, heat)
		width_u = maxf(width_u, SOUL_BORDER_U * heat)
		glow_alpha = maxf(glow_alpha, CHARGE_GLOW_ALPHA * heat)
	return box(unit, bg, border, width_u, glow_alpha)

## Tooltip: Name, Augensumme, Seiten (aufsteigend) und Material-Seiten.
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
	# Seele UND Ladung kommen aus der EINEN Quelle - der Kanten-Chip erklärt beide,
	# und ein zweiter Seelen-Name stünde sonst doppelt.
	var edge := DieNetView.hint_for(def, DieNetView.EDGE)
	if edge != "":
		text += "\n%s" % edge
	return text

## Leerer Platz: stiller Platzhalter, damit das Raster die Lücken spiegelt.
func _empty_tile() -> Control:
	var cell := Panel.new()
	cell.custom_minimum_size = _tile_size()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#181534ff")  # voll deckend wie die belegten Kacheln
	box.border_color = Color("#282350")
	box.set_border_width_all(maxi(1, int(u * 0.15)))
	box.set_corner_radius_all(int(u * 0.7))
	cell.add_theme_stylebox_override("panel", box)
	return cell

## Die eine Kachel-Fassung, in Einheiten von unit gerechnet.
static func box(unit: float, bg: Color, border: Color, width_u := PLAIN_BORDER_U,
		glow_alpha := 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(maxi(1, int(unit * width_u)))
	style.set_corner_radius_all(int(unit * 0.7))
	style.set_content_margin_all(int(unit * 0.3))
	if glow_alpha > 0.0:
		style.shadow_color = Color(border.r, border.g, border.b, glow_alpha)
		style.shadow_size = maxi(1, int(unit * 0.6))
	return style
