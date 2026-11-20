class_name ShelfStackView
extends Node3D
## Das SORTEN-MAGAZIN (Layout C, 2026-11-20): VIER TRAYS nebeneinander, einer je SORTE
## (Pack.SHELF_ORDER), jeder in seiner eigenen Grube, alle auf derselben Höhe; dazwischen
## liegt Filz. Jeder Tray (Knoten "Spalte%d") trägt auf seiner Platte REIHEN zu ACROSS
## Mulden und ROLLT für sich senkrecht: ein Zug schiebt sein FACH längs Welt-X, was das
## Fenster verläßt, gleitet durch die Schlitze der Wände oben und unten unter den Filz.
## Aussehen, Fassung und Lichtleiste sind das GERÄT seines Datenträgers (MagazinTrayDress);
## rechts in der Grube zeigt die ROLLSCHIENE, wie weit er gerollt ist.
##
## Die Karten LIEGEN flach (Netz nach oben, Langseite quer) und sind KINDER des Faches ihrer
## Spalte: eine Fahrt trägt sie mit. Eine Karte, die das Fenster verlassen hat, ist
## WEGGESTECKT (DataCellView.set_tucked) - oben läge sie sonst unter dem Graben der Walze.
##
## Die Maße kommen von außen (scene_root rechnet die gemeldeten Gruben in Welt), die
## HÖHE gehört dem Magazin. Endzustand zuerst: der Roll-Stand ist gebucht,
## bevor das Fach fährt. Längs der Spalte zählt Bild-unten, also Welt -X.

const COLUMNS := PackDrawerView.COLUMNS
const ACROSS := PackDrawerView.ACROSS

## Eine Spalte ist eine Platte; die Karte liegt eine Spur darüber (koplanar stritten
## sie im Tiefenpuffer).
const PLATE := 0.06
## Die Karte liegt in ihrer MULDE auf der Boden-Einlage - um BAY_FLOOR über der
## Platte; PROUD mißt vom Muldenboden aus. Lippen, Rippen und Deck reichen bis
## Kartenoberkante (deck_height), die liegende Karte ist bündig mit der Spalte.
const BAY_FLOOR := 0.05
## Die Dicke der liegenden Karte und ihre Spur über dem Boden (koplanar stritten
## sie im Tiefenpuffer).
const CARD_THICKNESS := DataCellView.DEPTH * PackDrawerView.CASSETTE_SCALE
const FLOOR_PROUD := 0.006
## Der Rand der BUCHSE über und unter der Karte (das Modell card_socket.glb).
const SOCKET_LIP := 0.05
const PROUD := BAY_FLOOR + FLOOR_PROUD
## Die Luft, die die Karte unter der Tischkante behält - keine Karte ragt je über
## die Kante.
const RIM_CLEAR := CARD_THICKNESS * 0.5
## Und wie weit der GRIFF sie beim Überfahren aus der Grube zieht: bis eine
## Kartendicke über das Glas - nur der Hover darf über die Kante.
const HOVER_PROUD := CARD_THICKNESS
## So tief unter ihrem Platz beginnt eine gelieferte Karte ihren Aufstieg: unter der
## Platte ihrer Spalte.
const RISE_DEPTH := CARD_THICKNESS + PLATE + PROUD

## Der Anteil der Grubenbreite, den die ROLLSCHIENE rechts nimmt (PackDrawerView
## schneidet die Plätze an derselben Zahl - EINE Quelle).
const RAIL_SHARE := PackDrawerView.RAIL_SHARE
## Hervorgehoben (die Sorte der Option unter dem Zeiger) leuchtet die Lichtleiste heller.
const HIGHLIGHT_GAIN := 2.2
## Die Fassung ohne Meldung (kopflos): Seite, oben, unten in Welt.
const MARGINS_FALLBACK := Vector3(0.21, 0.21, 0.9)
## Die MULDE je Stellplatz: die PLATTE ist ihr Boden, Lippen und Rippen ihr Rand bis
## Kartenhöhe, am Boden ein LICHTSAUM in der Sortenfarbe (leer kühl und stumpf) und am
## Bild-rechten Ende die BUCHSE, in der die Karte steckt.
const BAY_ROOM := 1.06
const LIP_MIN := 0.06
const SEAM_WIDTH := 0.05
const SEAM_RISE := 0.006
const FLOOR_RISE := 0.010
const BAY_EMPTY := Color(0.34, 0.38, 0.58)
## Ein Vorrats-Block ist ein Fenster plus so viele Mulden lang.
const SPARE_EXTRA := 2
const SNAP_TIME_MAX := 0.45
## So weit liegt die mitrollende Platte unter der festen.
const UNDERPLATE_SINK := 0.01
## Die Wand-Auskleidung einer Mulde: Stärke, Abstand zur Lippe, Luft unter dem Deck.
const WALL_LINING := 0.012
const WALL_INSET := 0.004
const WALL_TOP_GAP := 0.003
const SEAM_EMPTY_ENERGY := 0.85
const SEAM_FILLED_ENERGY := 0.9

## Das EINRASTEN nach einem Zug auf den nächsten ganzen Platz.
const SNAP_TIME := 0.16
## Eine Wandtasche faßt den hinausgerollten Platz samt Luft (in Kartenbreiten).
const POCKET_SHARE := 1.2
const POCKET_CLEAR := 0.3

## Die WANDTASCHE hinter dem Schlitz ist der Raum NEBEN der Grube, nicht ihr Ende:
## sie trägt dieselbe Archiv-Auskleidung wie die Grube selbst (PackPitView.tune_lining),
## und ihre Flanken setzen die Grubenwände in Weltmaß fort.
const POCKET_WALL := 0.06
## Ihr BODEN ist HELLER als der der Grube: in die Grube sieht man von oben, in die
## Tasche nur durch einen flachen Schlitz (gemessen 2026-10-26).
const POCKET_FLOOR_ALBEDO := Color(0.125, 0.115, 0.18)
const POCKET_FLOOR_ENERGY := 2.4

## Der BODEN einer MULDE bekommt DIESELBE Auskleidung, aber DUNKLER als die Tasche: in
## ein Kartenfach sieht die Station fast senkrecht hinein. GEMESSEN 2026-10-26.
const BAY_FLOOR_ALBEDO := Color(0.095, 0.088, 0.14)
const BAY_FLOOR_ENERGY := 1.8

## Das dunkle Blech der Laden-Mulden (CardRecessView); die Trays tragen ihr Gerät.
const PLATE_ALBEDO := Color(0.22, 0.212, 0.285)
const PLATE_EMISSION := Color(0.46, 0.48, 0.66)
const PLATE_ENERGY := 0.42

## Die WANDHAUT der Wandtaschen: von draußen GEMELDET wie die der Grube selbst.
var wall_skin: Texture2D = null:
	set(value):
		wall_skin = value
		if _built:
			_build_pocket()

var _span := Vector2.ONE
var _seat := Vector3.ZERO
var _scale := PackDrawerView.CASSETTE_SCALE
var _built := false
## Die gemeldeten GRUBEN in WELT: je Tray (Mitte relativ zur Mitte des Feldes in Welt-Z,
## Breite). Leer = der kopflose Rückfall, gleiche Streifen ohne Filz dazwischen.
var _lanes: Array[Vector2] = []
## Die Fassung in Welt: Seite, oben, unten (dort liegt die Lichtleiste).
var _margins := MARGINS_FALLBACK

var _columns: Array[Node3D] = []
var _fachs: Array[Node3D] = []
var _tints: Array = []          # Spalte -> Array[Color], zuletzt geschrieben
var _rolled := {}               # Spalte -> schon nach unten gerollt (Vorrat oben)
var _frames: Array[Node3D] = []  # Spalte -> Fassung auf dem Filz
var _bars: Array = []           # Spalte -> {bar, label, material} der Lichtleiste
var _bar_texts: Array[String] = []
## Die ROLLSCHIENE je Tray: Schieber, Reihen (gesamt, im Fenster) und der gebuchte
## Roll-Stand (ein laufender Zug kommt live dazu).
var _thumbs: Array[MeshInstance3D] = []
var _rail_rows: Array[Vector2i] = []
var _rail_scroll: Array[int] = []
var _wall_material: ShaderMaterial
var _spare_below := {}           # Spalte -> Vorrats-Block unten
var _spare_above := {}           # Spalte -> Vorrats-Block oben (nur gerollt)
var _pitch := {}                 # Spalte -> Muldenteilung
var _bays: Array[Node3D] = []    # Spalte -> Mulden-Knoten
var _seams: Array = []          # Spalte -> Array[StandardMaterial3D], je Mulde
var _lamps: Array = []          # Spalte -> Leuchttische je Platz (nur die Kartenzufuhr)
var _grips: Array = []          # Spalte -> Griffrillen des Schiebers
var _pocket: Node3D
## Wie weit (Welt +X) die OBERE Wandtasche höchstens reicht: bis vor den Graben der Walze.
var top_pocket_limit_x := INF:
	set(value):
		if top_pocket_limit_x == value:
			return
		top_pocket_limit_x = value
		if _built:
			_build_pocket()
## Und wie weit (Welt -X) die UNTERE höchstens reicht: der Displayrand.
var bottom_pocket_limit_x := -INF:
	set(value):
		if bottom_pocket_limit_x == value:
			return
		bottom_pocket_limit_x = value
		if _built:
			_build_pocket()
## Der ROLL-Zug: welche Spalte gerade vom Zeiger geführt wird (-1 = keine), und das
## Einrasten danach.
var _scrolling := -1
var _snap: Tween
var _snap_column := -1
var _snap_to := 0.0
var _highlight := -1

func _init() -> void:
	name = "ShelfStack"

## Gleitet eine Karte im Fach auf einen neuen Platz, folgt das Wegstecken ihr je Bild.
func _process(_delta: float) -> void:
	for column in _fachs.size():
		_write_tuck(column)

# --- Die reine Rechnung --------------------------------------------------------------

## Wie weit die Trittfläche jeder Spalte unter dem Glas liegt: so tief, daß die flach
## darauf liegende Karte mit ihrer Oberseite unter der Tischkante bleibt.
static func read_drop(cell_scale: float) -> float:
	return DataCellView.lying_over(cell_scale) + PROUD + RIM_CLEAR

## Der GRIFF im Magazin, als Anteil der Standhöhe (DataCellView.hover_lift): er zieht
## die liegende Karte bis über das Glas.
static func hover_lift(cell_scale: float) -> float:
	var reach := read_drop(cell_scale) + HOVER_PROUD
	return reach / maxf(DataCellView.STAND_HEIGHT * cell_scale, 0.001)

## Wie tief das Magazin reicht - eine Lage, daran mißt die Grube.
static func stack_depth(cell_scale: float) -> float:
	return read_drop(cell_scale) + PLATE

# --- Aufbau ------------------------------------------------------------------------

## Stellt das Magazin (idempotent - dieselben Maße bauen nichts neu). at = der
## GLASPUNKT der Feldmitte (Vereinigung der Gruben), span = ihr Weltmaß (x quer/Bild-
## hoch, y längs/Bild-breit), cell_scale der Anzeige-Maßstab der Karten, lanes die
## gemeldeten Gruben, margins die Fassung (Seite, oben, unten) in Welt.
func setup(at: Vector3, span: Vector2, cell_scale: float,
		lanes: Array[Vector2] = [], margins := MARGINS_FALLBACK) -> void:
	var wanted := Vector2(maxf(span.x, 0.01), maxf(span.y, 0.01))
	if _built and _seat.is_equal_approx(at) and _span.is_equal_approx(wanted) \
			and is_equal_approx(_scale, cell_scale) and _lanes == lanes \
			and _margins.is_equal_approx(margins):
		return
	_seat = at
	_span = wanted
	_scale = cell_scale
	_lanes = lanes.duplicate()
	_margins = margins
	global_position = at
	_ensure_columns()
	for column in COLUMNS:
		_build_column(column)
		_build_frame(column)
	_build_pocket()
	_built = true
	settle_scroll_hard()

## Die Spalten entstehen EINMAL - ihre Fächer tragen die Karten, ein Neuaufbau der
## Maße darf sie nicht mit wegräumen.
func _ensure_columns() -> void:
	if not _columns.is_empty():
		return
	for column in COLUMNS:
		var node := Node3D.new()
		node.name = "Spalte%d" % (column + 1)
		add_child(node)
		_columns.append(node)
		var fach := Node3D.new()
		fach.name = "Fach"
		node.add_child(fach)
		_fachs.append(fach)
		_bays.append(null)
		_tints.append([] as Array[Color])
		_seams.append([])
		_lamps.append([])
		_grips.append(null)
		_frames.append(null)
		_bars.append({})
		_bar_texts.append("")
		_thumbs.append(null)
		_rail_rows.append(Vector2i(0, PackDrawerView.PLACES))
		_rail_scroll.append(0)

## Platte, ROLLSCHIENE und MULDEN eines Trays. Das Fach bleibt stehen - es trägt die Karten.
func _build_column(column: int) -> void:
	var node := _columns[column]
	node.position = Vector3(0.0, -read_drop(_scale), 0.0)
	for child in node.get_children():
		if child == _fachs[column]:
			continue
		node.remove_child(child)
		child.queue_free()
	_build_plate(node, "Platte", plate_span(column), plate_center(column), _span.x, 0.0, 0.0,
		MagazinTrayDress.inside_material(column))
	_build_rail(node, column)
	_build_bays(node, column)

## Die ROLLSCHIENE rechts in der Grube: ein Bett bündig mit dem Deck, darin die Rinne und
## der SCHIEBER in Sortenfarbe. Sie steht fest - nur der Schieber wandert.
func _build_rail(host: Node3D, column: int) -> void:
	var rail := Node3D.new()
	rail.name = "Rollschiene"
	rail.position = Vector3(0.0, 0.0, rail_z(column))
	host.add_child(rail)
	var wide := rail_width(column)
	var groove := wide * MagazinTrayDress.RAIL_GROOVE_SHARE
	var bed := (wide - groove) * 0.5
	var top := deck_height()
	var floor_y := top - CARD_THICKNESS * 0.35
	var inside := MagazinTrayDress.inside_material(column)
	for side in 2:
		var dir := float(side) * 2.0 - 1.0
		TableProps.box(rail, "Bett%d" % side, Vector3(_span.x, top, bed),
			Vector3(0.0, top * 0.5, dir * (groove + bed) * 0.5), inside)
	TableProps.box(rail, "Rinne", Vector3(_span.x, floor_y, groove),
		Vector3(0.0, floor_y * 0.5, 0.0), MagazinTrayDress.groove_material(column))
	# Zwei Führungsschienen fassen die Rinne, der SCHIEBER ist ein Knopf mit Griffrillen.
	for side in 2:
		var dir := float(side) * 2.0 - 1.0
		TableProps.box(rail, "Fuehrung%d" % side, Vector3(_span.x, 0.014, 0.018),
			Vector3(0.0, top + 0.007, dir * groove * 0.5), MagazinTrayDress.rail_steel())
	var knob := CARD_THICKNESS * 0.6
	var across := wide * MagazinTrayDress.RAIL_THUMB_SHARE
	var thumb := TableProps.box(rail, "Schieber", Vector3(1.0, knob, across),
		Vector3(0.0, floor_y + knob * 0.5, 0.0), MagazinTrayDress.thumb_material(column))
	_thumbs[column] = thumb
	var grip := Node3D.new()
	grip.name = "Griff"
	grip.position.y = floor_y + knob
	rail.add_child(grip)
	for i in 3:
		TableProps.box(grip, "Rille%d" % i, Vector3(0.028, 0.012, across * 0.8),
			Vector3((float(i) - 1.0) * 0.075, 0.006, 0.0), MagazinTrayDress.grip_material())
	_grips[column] = grip
	_write_rail(column)

## Die FASSUNG eines Trays auf dem Filz samt Lichtleiste - sein Gerät.
func _build_frame(column: int) -> void:
	var old := _frames[column]
	if old != null and is_instance_valid(old):
		remove_child(old)
		old.queue_free()
	var frame := Node3D.new()
	frame.name = "Fassung%d" % (column + 1)
	frame.position = Vector3(0.0, 0.0, lane_z(column))
	add_child(frame)
	_frames[column] = frame
	_bars[column] = MagazinTrayDress.build_frame(frame, column,
		Vector2(_span.x, lane_width(column)), _margins)
	_write_bar(column)

## Die WANDTASCHEN hinter den Schlitzen der Wände oben und unten, je Tray zwei:
## geschlossene Kästen von der Wand weg, so tief wie ein hinausgerollter Platz samt Luft,
## zur Grube hin offen. Sie liegen außerhalb des Lochs, man sieht sie NUR durch den Schlitz.
func _build_pocket() -> void:
	if _pocket != null and is_instance_valid(_pocket):
		remove_child(_pocket)
		_pocket.queue_free()
	var host := Node3D.new()
	host.name = "Wandtaschen"
	add_child(host)
	_pocket = host
	for column in COLUMNS:
		var tray := Node3D.new()
		tray.name = "Spalte%d" % (column + 1)
		tray.position = Vector3(0.0, 0.0, lane_z(column))
		host.add_child(tray)
		_build_pocket_side(tray, column, 1.0, top_pocket_depth())
		_build_pocket_side(tray, column, -1.0, bottom_pocket_depth())

## Wie tief eine Wandtasche ohne Grenze reicht: eine Kartenbreite samt Luft.
func pocket_depth() -> float:
	return DataCellView.WIDTH * _scale * POCKET_SHARE + POCKET_CLEAR

## Die OBERE endet vor dem Graben der Walze, die UNTERE spätestens am Displayrand.
func top_pocket_depth() -> float:
	return maxf(minf(pocket_depth(),
		top_pocket_limit_x - _seat.x - _span.x * 0.5 - POCKET_WALL), POCKET_WALL)

func bottom_pocket_depth() -> float:
	return maxf(minf(pocket_depth(),
		_seat.x - _span.x * 0.5 - POCKET_WALL - bottom_pocket_limit_x), POCKET_WALL)

## EINE Wandtasche, außen an der Wand der Seite side (+1 = Bild-oben, Welt +X), so breit
## wie die Grube ihres Trays.
func _build_pocket_side(parent: Node3D, column: int, side: float, deep: float) -> void:
	var host := Node3D.new()
	host.name = "WandtascheOben" if side > 0.0 else "WandtascheUnten"
	host.scale = Vector3(side, 1.0, 1.0)
	parent.add_child(host)
	var near := _span.x * 0.5
	# Die DECKE hängt UNTER der Tischfläche (auf der Höhe der Wandoberkante): auf der
	# Glasebene selbst läge sie AUF dem Filz - als schwarzer Balken neben der Grube.
	var top := -PackPitView.WALL_SINK
	var bottom := -stack_depth(_scale) - POCKET_WALL
	var high := top - bottom
	# So breit wie die Grube - der Schlitz läuft über deren volle Breite.
	var wide := lane_width(column) + POCKET_WALL * 2.0
	var mid_x := near + deep * 0.5
	var reach := near + deep
	var rect := Rect2(Vector2(_seat.x + (near if side > 0.0 else -reach),
		_seat.z + lane_z(column) - wide * 0.5), Vector2(deep, wide))
	var skin := _lining(0.0, rect, high)
	var velvet := _lining(1.0, rect, high)
	TableProps.box(host, "Decke", Vector3(deep, POCKET_WALL, wide),
		Vector3(mid_x, top - POCKET_WALL * 0.5, 0.0), skin)
	TableProps.box(host, "Boden", Vector3(deep, POCKET_WALL, wide),
		Vector3(mid_x, bottom - POCKET_WALL * 0.5, 0.0), velvet)
	TableProps.box(host, "Rueckwand", Vector3(POCKET_WALL, high, wide),
		Vector3(near + deep + POCKET_WALL * 0.5, (top + bottom) * 0.5, 0.0), skin)
	for flank in 2:
		var dir := float(flank) * 2.0 - 1.0
		TableProps.box(host, "Flanke%d" % flank, Vector3(deep, high, POCKET_WALL),
			Vector3(mid_x, (top + bottom) * 0.5, dir * (wide * 0.5 - POCKET_WALL * 0.5)),
			skin)

## EINE Fläche der Tasche, ausgekleidet von derselben Hand wie die Grube: velvet = 1
## der Boden, 0 die Wand. Die Haut bekommt NUR die Wand - auf dem Samt läge sie quer.
func _lining(velvet: float, rect: Rect2, high: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/pit_lining.gdshader")
	var wall := velvet <= 0.5
	var base := PackPitView.WALL_ALBEDO if wall else POCKET_FLOOR_ALBEDO
	var field := PackPitView.WALL_FIELD_ENERGY if wall else POCKET_FLOOR_ENERGY
	PackPitView.tune_lining(material, velvet, base, field, rect,
		_seat.y, high, PackPitView.GLOW_COLOR, wall_skin if wall else null)
	return material

## Die Breite EINER Spalte in Welt: GEMELDET (das Fenster schneidet die Ränder heraus);
## ohne Meldung ein gleicher Streifen.
func lane_width(column := 0) -> float:
	if _lanes.is_empty():
		return _span.y / float(COLUMNS)
	return maxf(_lanes[clampi(column, 0, _lanes.size() - 1)].y, 0.01)

## Die Mitte einer Spalte, quer zur Grube (Welt-Z, relativ zur Grubenmitte; Spalte 0
## liegt Bild-links, also bei -Z).
func lane_z(column: int) -> float:
	if _lanes.is_empty():
		return -_span.y * 0.5 + _span.y / float(COLUMNS) * (float(column) + 0.5)
	return _lanes[clampi(column, 0, _lanes.size() - 1)].x

## Die Grenzen der PLATTE eines Trays (Welt-Z, von links nach rechts): seine Grube.
func plate_bounds(column: int) -> Vector2:
	return Vector2(lane_z(column) - lane_width(column) * 0.5,
		lane_z(column) + lane_width(column) * 0.5)

func plate_span(column: int) -> float:
	var bounds := plate_bounds(column)
	return maxf(bounds.y - bounds.x, 0.05)

func plate_center(column: int) -> float:
	var bounds := plate_bounds(column)
	return (bounds.x + bounds.y) * 0.5

## Die ROLLSCHIENE rechts in der Grube (Welt-Z): Breite und Mitte.
func rail_width(column := 0) -> float:
	return lane_width(column) * RAIL_SHARE

func rail_z(column: int) -> float:
	return lane_z(column) + lane_width(column) * 0.5 - rail_width(column) * 0.5

## Die Mitte der Plätze eines Trays (Welt-Z): seine Grube ohne die Schiene.
func slot_z(column: int) -> float:
	return lane_z(column) - rail_width(column) * 0.5

func slot_width(column: int) -> float:
	return lane_width(column) * (1.0 - RAIL_SHARE)

## Die Breite EINES Querplatzes (Welt-Z) und seine Mitte relativ zu slot_z.
func card_slot_width(column: int) -> float:
	return slot_width(column) / float(ACROSS)

func across_z(column: int, across: int) -> float:
	return (float(across) - float(ACROSS - 1) * 0.5) * card_slot_width(column)

# --- Der Zustand -------------------------------------------------------------------

func column_count() -> int:
	return COLUMNS

## Fährt gerade eine Spalte - unter dem Zeiger oder ins Einrasten?
func riding() -> bool:
	return _scrolling >= 0 or (_snap != null and _snap.is_valid())

# --- Das ROLLEN --------------------------------------------------------------------

## Der Zeiger führt das Fach der Spalte: um x (Welt, - = Bild-unten) gegen ihren
## Roll-Stand versetzt. Die Karten hängen am Fach und reisen mit.
func drag_scroll(column: int, x: float) -> void:
	if column < 0 or column >= _fachs.size():
		return
	if _snap_column != column:
		_finish_snap()
	else:
		_kill_snap()
	_scrolling = column
	_roll_to(column, x)

## Fach UND Mulden fahren gemeinsam: ausgeblendet ließen die Mulden eine graue Platte
## stehen, und die leeren Vorrats-Mulden rücken nach.
func _roll_to(column: int, x: float) -> void:
	_fachs[column].position.x = x
	if _bays[column] != null and is_instance_valid(_bays[column]):
		_bays[column].position.x = x
		_place_spares(column, x)
		_write_segments(column)
	_write_tuck(column)
	_write_rail(column)

## Die Dauer des Einrastens: ein Platz in SNAP_TIME, ein weiter Rückweg länger -
## mit der Wurzel der Strecke, gedeckelt (sonst spränge ein langer Zug zurück).
func snap_time_for(distance: float) -> float:
	var places := distance / maxf(_span.x / float(PackDrawerView.PLACES), 0.001)
	return minf(SNAP_TIME * sqrt(maxf(places, 1.0)), SNAP_TIME_MAX)

## Der Versatz des Fachs (0 = es liegt auf seinem Roll-Stand).
func scroll_offset(column: int) -> float:
	if column < 0 or column >= _fachs.size():
		return 0.0
	return _fachs[column].position.x

## Losgelassen: das Fach fährt von from auf to und RASTET dort ein - danach wird der
## Versatz in die Karten übernommen (der Roll-Stand ist längst gebucht, ihre Plätze
## stehen schon dort). on_done läuft danach, auch bei Zeit 0.
func snap_scroll(column: int, from: float, to: float, on_done: Callable) -> void:
	if column < 0 or column >= _fachs.size():
		return
	_finish_snap()
	if _scrolling == column:
		_scrolling = -1
	_roll_to(column, from)
	if not is_inside_tree() or is_equal_approx(from, to):
		_roll_to(column, to)
		bake_scroll(column)
		on_done.call()
		return
	_snap_column = column
	_snap_to = to
	_snap = create_tween()
	_snap.tween_method(func(x: float) -> void: _roll_to(column, x), from, to,
		snap_time_for(absf(to - from))) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_snap.tween_callback(func() -> void:
		_snap_column = -1
		bake_scroll(column)
		on_done.call())

## Der Versatz des Fachs geht in seine Karten über, das Fach steht wieder auf 0 -
## die Welt-Plätze bleiben byteweise, wo sie sind.
func bake_scroll(column: int) -> void:
	if column < 0 or column >= _fachs.size():
		return
	var fach_node := _fachs[column]
	var offset := fach_node.position.x
	_roll_to(column, 0.0)
	if not is_zero_approx(offset):
		for child in fach_node.get_children():
			(child as Node3D).position.x += offset
	_write_tuck(column)

## Der harte Weg: jedes Fach auf 0, jede Fahrt aus (Laufwechsel, Abbruch).
func settle_scroll_hard() -> void:
	_kill_snap()
	_scrolling = -1
	for column in _fachs.size():
		bake_scroll(column)

## Ein laufendes Einrasten einer ANDEREN Spalte springt an sein Ende - es schuldet nichts.
func _finish_snap() -> void:
	var column := _snap_column
	var to := _snap_to
	_kill_snap()
	if column >= 0:
		_roll_to(column, to)
		bake_scroll(column)

func _kill_snap() -> void:
	if _snap != null and _snap.is_valid():
		_snap.kill()
	_snap = null
	_snap_column = -1

## WEGGESTECKT ist, was die Spalte aus dem Fenster gerollt hat: ganz draußen, mit der
## fernen Kante jenseits der Tasche, oder - ist die Tasche kürzer als die Karte - schon,
## sobald die Mitte die Wand passiert. Oben liegt dahinter der offene Graben der Walze.
func hidden_at(x: float, half: float) -> bool:
	var edge := _span.x * 0.5
	for side: float in [1.0, -1.0]:
		var room := top_pocket_depth() if side > 0.0 else bottom_pocket_depth()
		var at := x * side
		if at - half > edge or at + half > edge + room:
			return true
		if at > edge and room < half * 2.0:
			return true
	return false

func _write_tuck(column: int) -> void:
	if column < 0 or column >= _fachs.size():
		return
	var fach_node := _fachs[column]
	var half := DataCellView.WIDTH * _scale * 0.5
	for child in fach_node.get_children():
		var cell := child as DataCellView
		if cell != null:
			cell.set_tucked(hidden_at(fach_node.position.x + cell.position.x, half))

## Dieselbe Regel für die Mulden-Stücke der Spalte (Fenster und Vorrat).
func _write_segments(column: int) -> void:
	var bays: Node3D = _bays[column] if column < _bays.size() else null
	if bays == null or not is_instance_valid(bays):
		return
	var half := float(_pitch.get(column, 0.0)) * 0.5
	for node in _segments_of(bays):
		var x := bays.position.x + node.position.x
		if node.get_parent() != bays:
			x += (node.get_parent() as Node3D).position.x
		node.visible = not hidden_at(x, half)

func _segments_of(bays: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child in bays.get_children():
		if String(child.name).begins_with("Mulde"):
			out.append(child as Node3D)
		elif String(child.name).begins_with("Vorrat"):
			for spare in child.get_children():
				out.append(spare as Node3D)
	return out

## Die HERVORHEBUNG eines Trays (-1 = keiner): seine Lichtleiste leuchtet heller.
func set_highlight(column: int) -> void:
	var wanted := column if column >= 0 and column < COLUMNS else -1
	if wanted == _highlight:
		return
	_highlight = wanted
	for each in _bars.size():
		_write_bar(each)

func highlighted() -> int:
	return _highlight

# --- Die LICHTLEISTE ---------------------------------------------------------------

## Die Aufschrift der Lichtleiste (Name sichtbar/gesamt - das Fenster formuliert).
## Idempotent.
func set_bar(column: int, text: String) -> void:
	if column < 0 or column >= _bar_texts.size() or _bar_texts[column] == text:
		return
	_bar_texts[column] = text
	_write_bar(column)

func bar_text(column: int) -> String:
	if column < 0 or column >= _bar_texts.size():
		return ""
	return _bar_texts[column]

## Wie hell die Lichtleiste gerade leuchtet (die Hervorhebung hebt sie).
func bar_energy(column: int) -> float:
	var parts: Dictionary = _bars[column] if column >= 0 and column < _bars.size() else {}
	var material := parts.get("material") as StandardMaterial3D
	return material.emission_energy_multiplier if material != null else 0.0

func _write_bar(column: int) -> void:
	if column < 0 or column >= _bars.size():
		return
	var parts: Dictionary = _bars[column]
	var on := column == _highlight
	var material := parts.get("material") as StandardMaterial3D
	if material != null:
		material.emission_energy_multiplier = MagazinTrayDress.BAR_HIGHLIGHT_ENERGY if on \
			else MagazinTrayDress.BAR_ENERGY
	var label := parts.get("label") as Label3D
	if label != null and is_instance_valid(label):
		label.text = _bar_texts[column]
		var color := column_tint(column).lerp(Color.WHITE, 0.7)
		label.modulate = color.lerp(Color.WHITE, 0.6) if on else color

# --- Die ROLLSCHIENE ---------------------------------------------------------------

## Der Stand der Rollschiene: Reihen gesamt und im Fenster, der GEBUCHTE Roll-Stand.
func set_rail(column: int, total_rows: int, window_rows: int, scroll: int) -> void:
	if column < 0 or column >= _rail_rows.size():
		return
	_rail_rows[column] = Vector2i(maxi(total_rows, 0), maxi(window_rows, 1))
	_rail_scroll[column] = scroll
	_write_rail(column)

## Der Schieber als Anteile der Schiene (x = Anfang oben, y = Länge), live samt Zug: ein
## Zug liegt über dem gebuchten Stand, ein Einrasten fährt auf ihn zu (gebucht ist da
## schon das Ziel).
func rail_thumb(column: int) -> Vector2:
	if column < 0 or column >= _rail_rows.size():
		return Vector2(0.0, 1.0)
	var rows := _rail_rows[column]
	var offset := scroll_offset(column)
	if _snap_column == column:
		offset -= _snap_to
	var live := float(_rail_scroll[column]) + offset / _row_pitch(column)
	return PackDrawerView.rail_thumb(rows.x, rows.y, live)

func _row_pitch(column: int) -> float:
	var rows := _rail_rows[column].y if column >= 0 and column < _rail_rows.size() else 1
	return maxf(_span.x / float(maxi(rows, 1)), 0.001)

## Der Schieber fährt längs der Schiene (Welt-X, oben = +X); paßt alles ins Fenster,
## füllt er sie gedimmt.
func _write_rail(column: int) -> void:
	if column < 0 or column >= _thumbs.size():
		return
	var thumb := _thumbs[column]
	if thumb == null or not is_instance_valid(thumb):
		return
	var share := rail_thumb(column)
	var inset := 0.04
	var run := maxf(_span.x - inset * 2.0, 0.01)
	var length := clampf(run * share.y, minf(MagazinTrayDress.RAIL_THUMB_MIN, run), run)
	var way := share.x / (1.0 - share.y) if share.y < 1.0 else 0.0
	thumb.scale.x = length
	thumb.position.x = run * 0.5 - (run - length) * way - length * 0.5
	var grip: Node3D = _grips[column] if column < _grips.size() else null
	if grip != null and is_instance_valid(grip):
		grip.position.x = thumb.position.x
	var full := _rail_rows[column].x <= _rail_rows[column].y
	var material := thumb.material_override as StandardMaterial3D
	if material != null:
		material.emission_energy_multiplier = MagazinTrayDress.RAIL_THUMB_ENERGY \
			* (MagazinTrayDress.RAIL_THUMB_DIM if full else 1.0)

# --- Die Plätze --------------------------------------------------------------------

## Welt-y der Trittfläche einer Spalte - alle Spalten liegen gleich hoch.
func tray_top(_column := 0) -> float:
	return _seat.y - read_drop(_scale)

## ... und die Höhe, auf der die Karte dieser Spalte LIEGT.
func card_seat(column := 0) -> float:
	return tray_top(column) + PROUD

## Der höchste Punkt einer Karte - daran mißt die Invariante.
func card_top(column := 0) -> float:
	return card_seat(column) + DataCellView.lying_over(_scale)

## Das FACH einer Spalte - der Wirt ihrer Karten (null = noch nicht gebaut).
func fach(column: int) -> Node3D:
	if _fachs.is_empty():
		return null
	return _fachs[clampi(column, 0, _fachs.size() - 1)]

## Die Karte wird KIND des Faches ihrer Spalte - ein Zug trägt sie mit. Ihren Platz
## nennt der Sitz-Schreiber, die HÖHE gehört der Spalte: lokal liegt sie IMMER PROUD
## über der Trittfläche.
func host_card(cell: Node3D, column: int) -> void:
	var fach_node := fach(column)
	if fach_node == null:
		return
	if cell.get_parent() != fach_node:
		rehost(cell, fach_node)
	cell.position.y = PROUD
	if cell is DataCellView:
		(cell as DataCellView).set_layer_depth(0)
	_write_tuck(clampi(column, 0, _fachs.size() - 1))

## Liegt diese Karte schon auf ihrem Platz? Verglichen wird in der TISCHEBENE und am
## Fach.
func seated(cell: Node3D, column: int, at: Vector3) -> bool:
	if _fachs.is_empty() or cell.get_parent() != fach(column):
		return false
	if not is_equal_approx(cell.position.y, PROUD):
		return false
	return Vector2(cell.global_position.x, cell.global_position.z) \
		.distance_to(Vector2(at.x, at.z)) < 0.01

## Ein Körper wechselt den Wirt und behält seinen Weltplatz - der eine Umzug, den
## das Magazin kennt (hinein ins Fach, hinaus zur Walze). Wer das Fach verläßt, ist
## nie mehr weggesteckt.
static func rehost(node: Node3D, host: Node) -> void:
	if node == null or not is_instance_valid(node) or host == null:
		return
	if node.get_parent() == host:
		return
	if node is DataCellView:
		(node as DataCellView).set_tucked(false)
	var at := node.global_position
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	host.add_child(node)
	node.global_position = at

# --- Die MULDEN ----------------------------------------------------------------------

## Die Sortenfarbe eines Trays.
static func column_tint(column: int) -> Color:
	return PackDrawerView.COLORS.get(Pack.SHELF_ORDER[clampi(column, 0, COLUMNS - 1)],
		PackDrawerView.GOLD)

## Die Sortenfarben einer Spalte, je Stellplatz eine (Reihe mal ACROSS plus Querplatz,
## BAY_EMPTY = leer). Sie färben den Lichtsaum der Mulden; ändert sich die Platzzahl,
## werden die Mulden neu gebaut, sonst nur umgefärbt. Idempotent.
## rolled = die Spalte ist schon nach unten gerollt: erst dann liegen oben
## Vorrats-Mulden (auf Stand 0 endet sie an der ersten).
func set_bay_tints(column: int, tints: Array, rolled := false) -> void:
	if column < 0 or column >= COLUMNS or _tints.is_empty():
		return
	var was_rolled: bool = _rolled.get(column, false)
	if _tints[column] == tints and was_rolled == rolled:
		return
	var rebuild := (_tints[column] as Array).size() != tints.size() or was_rolled != rolled
	_rolled[column] = rolled
	_tints[column] = tints.duplicate()
	if rebuild and column < _columns.size():
		_build_bays(_columns[column], column)
	else:
		_write_bays(column)

func bay_count(column: int) -> int:
	if column < 0 or column >= _tints.size():
		return 0
	return (_tints[column] as Array).size()

func bay_tint(column: int, index: int) -> Color:
	if column < 0 or column >= _tints.size():
		return BAY_EMPTY
	var line: Array = _tints[column]
	if index < 0 or index >= line.size():
		return BAY_EMPTY
	return line[index]

## Das Maß EINER Mulde bei so vielen Reihen (x längs der Spalte, y quer): die liegende
## Karte plus Luft, gedeckelt von Teilung und Querplatz, so daß zwischen zwei Mulden immer
## eine Lippe steht.
func bay_size(places: int, column := 0) -> Vector2:
	var pitch := _span.x / float(maxi(places, 1))
	return Vector2(
		minf(DataCellView.WIDTH * _scale * BAY_ROOM, pitch - LIP_MIN),
		minf(DataCellView.HEIGHT * _scale * BAY_ROOM, card_slot_width(column) - LIP_MIN * 2.0))

## Welt-X eines Platzes einer Spalte bei so vielen Plätzen: Platz 0 oben.
func _place_x(index: float, pitch: float) -> float:
	return _span.x * 0.5 - pitch * (index + 0.5)

## Die MULDEN einer Spalte: je REIHE EIN Stück aus Platte, Deck, Lippen, Rippen und ACROSS
## Mulden (Saum, Boden, Buchse) - in Stücken, damit hinausgerollte für sich verschwinden.
func _build_bays(host: Node3D, column: int) -> void:
	var old: Node3D = _bays[column] if column < _bays.size() else null
	if old != null and is_instance_valid(old):
		# Ein Neubau der Spalte hat den Knoten schon ausgehängt - dann nur freigeben.
		if old.get_parent() != null:
			old.get_parent().remove_child(old)
		old.queue_free()
	_bays[column] = null
	_seams[column] = []
	_lamps[column] = []
	var tints: Array = _tints[column]
	if tints.is_empty():
		return
	_ensure_materials()
	# Der Verlauf mißt an der Wandhöhe - die hängt am Kartenmaß.
	_wall_material.set_shader_parameter("height", deck_height() - WALL_TOP_GAP)
	var bays := Node3D.new()
	bays.name = "Mulden%d" % (column + 1)
	bays.position = Vector3(_fachs[column].position.x, 0.0, slot_z(column))
	host.add_child(bays)
	_bays[column] = bays
	var places := PackDrawerView.rows_for(tints.size())
	var pitch := _span.x / float(places)
	var shape := _segment_shape(column, places)
	var rolled: bool = _rolled.get(column, false)
	var seams: Array = []
	var lamps: Array = []
	for i in places:
		var node := Node3D.new()
		node.name = "Mulde%d" % i
		node.position = Vector3(_place_x(float(i), pitch), 0.0, 0.0)
		bays.add_child(node)
		# Die Rippe oben gehört dem Stück; ohne Vorrat oben steht die erste halb so
		# breit INNEN an der Kante, die letzte trägt auch die untere.
		var ribs: Array[float] = [-1.0 if i > 0 or rolled else -0.5]
		if i == places - 1:
			ribs.append(1.0)
		var row_seams := _row_seams()
		var row_lamps := _row_lamps(column)
		_build_segment(node, column, pitch, shape, ribs, row_seams, row_lamps)
		seams.append_array(row_seams)
		lamps.append_array(row_lamps)
	# Die VORRATS-Mulden: unten immer, oben erst nach dem Rollen. Sie rollen mit und
	# springen beim Zug um ganze Teilungen nach - so ist das Fenster bei jedem Zug voll.
	_spare_below[column] = _build_spares(bays, column, "VorratUnten", 1.0, places, pitch,
		shape)
	_spare_above[column] = _build_spares(bays, column, "VorratOben", -1.0, places, pitch,
		shape) if rolled else null
	_pitch[column] = pitch
	_seams[column] = seams
	_lamps[column] = lamps
	_place_spares(column, bays.position.x)
	_write_bays(column)
	_write_segments(column)

## Die Quer-Maße eines Stücks: Mulde, Lippe, Rippe und die mitrollende Platte (Mitte
## quer relativ zu den Plätzen, Breite).
func _segment_shape(column: int, places: int) -> Dictionary:
	var bay := bay_size(places, column)
	var pitch := _span.x / float(maxi(places, 1))
	return {"bay": bay, "rail": (card_slot_width(column) - bay.y) * 0.5, "rib": pitch - bay.x,
		"under": Vector2(plate_center(column) - slot_z(column), plate_span(column))}

## EIN Stück des Trays (eine Reihe), pitch lang um seinen Knoten (längs Welt-X): die
## mitrollende PLATTE eine Spur UNTER der festen (sichtbar nur jenseits der Grubenwand),
## je Querplatz Lippen bis Kartenhöhe, Rippen an den genannten Rändern (-1 oben, +1 unten,
## ±0.5 halb und innen) und die Mulde selbst samt dem, was ihr Gerät hineinlegt (Kind
## "Platz<a>"). Die Schiene rechts daneben steht fest.
func _build_segment(node: Node3D, column: int, pitch: float, shape: Dictionary,
		ribs: Array[float], seams: Array, lamps: Array = []) -> void:
	var bay: Vector2 = shape["bay"]
	var rail: float = shape["rail"]
	var rib: float = shape["rib"]
	var under: Vector2 = shape["under"]
	var lip := MagazinTrayDress.inside_material(column)
	_build_plate(node, "Unterplatte", under.y, under.x, pitch, 0.0, UNDERPLATE_SINK, lip)
	for across in ACROSS:
		var at_z := across_z(column, across)
		var tag := "" if across == 0 else str(across)
		for side in 2:
			var dir := float(side) * 2.0 - 1.0
			TableProps.box(node, "Lippe%d" % (across * 2 + side), Vector3(pitch, deck_height(),
				rail), Vector3(0.0, deck_height() * 0.5, at_z + dir * (bay.y + rail) * 0.5),
				lip)
		for edge: float in ribs:
			var width := rib * (0.5 if absf(edge) < 0.75 else 1.0)
			# Längs der Spalte zählt Bild-unten: +1 ist der untere Rand, also Welt -X.
			var down := signf(edge) * pitch * 0.5
			if absf(edge) < 0.75:
				down -= signf(edge) * width * 0.5
			TableProps.box(node, "Rippe%s%s" % ["O" if edge < 0.0 else "U", tag],
				Vector3(width, deck_height(), bay.y), Vector3(-down, deck_height() * 0.5, at_z),
				lip)
		var place := Node3D.new()
		place.name = "Platz%d" % across
		place.position = Vector3(0.0, 0.0, at_z)
		node.add_child(place)
		build_bay(place, bay, seams[across] if across < seams.size() else _seam_material(BAY_EMPTY),
			_scale, _wall_material, lamps[across] if across < lamps.size()
				else MagazinTrayDress.floor_material(column))
		MagazinTrayDress.dress_bay(place, column, bay, FLOOR_RISE, PROUD)

## Die EINE Bauregel einer Mulde - auch der Laden legt seine Kassetten so hinein
## (Spieler-Wunsch 2026-10-29). Der Knoten sitzt auf dem Muldenboden; bay ist
## (Welt-X, Welt-Z).
static func build_bay(node: Node3D, bay: Vector2, seam: StandardMaterial3D,
		cell_scale: float, wall_material: Material, floor_material: Material) -> void:
	TableProps.box(node, "Saum", Vector3(bay.x, SEAM_RISE, bay.y),
		Vector3(0.0, SEAM_RISE * 0.5, 0.0), seam)
	# Die WÄNDE der Vertiefung tragen ihr EIGENES Material, eine Spur in die Mulde
	# gerückt und unter der Oberkante, damit sie mit Lippe und Rippe nie eine Fläche teilen.
	var high := deck_height_for(cell_scale) - WALL_TOP_GAP
	var lining := WALL_LINING
	for side in [-1.0, 1.0]:
		TableProps.box(node, "WandL%s" % ("A" if side < 0.0 else "B"),
			Vector3(lining, high, bay.y), Vector3(side * (bay.x - lining) * 0.5 - side
				* WALL_INSET, high * 0.5, 0.0), wall_material)
		TableProps.box(node, "WandQ%s" % ("A" if side < 0.0 else "B"),
			Vector3(bay.x - WALL_INSET * 2.0, high, lining), Vector3(0.0, high * 0.5,
				side * (bay.y - lining) * 0.5 - side * WALL_INSET), wall_material)
	TableProps.box(node, "Boden",
		Vector3(bay.x - SEAM_WIDTH * 2.0, FLOOR_RISE, bay.y - SEAM_WIDTH * 2.0),
		Vector3(0.0, FLOOR_RISE * 0.5, 0.0), floor_material)
	var socket := DataCellView.socket_model()
	if socket != null:
		socket.position = Vector3(0.0,
			PROUD + DataCellView.DEPTH * cell_scale * 0.5,
			DataCellView.HEIGHT * cell_scale * 0.5)
		# In der Mulde trägt sie keinen Rand über der Karte - sie endet bündig im Deck.
		var thick := DataCellView.DEPTH * cell_scale
		socket.scale.y = thick / (thick + SOCKET_LIP * 2.0)
		node.add_child(socket)

## Das Wand-Material einer Mulde: sein Verlauf mißt an der Wandhöhe.
static func bay_wall_material(cell_scale: float) -> ShaderMaterial:
	var wall := ShaderMaterial.new()
	wall.shader = load("res://assets/shaders/bay_wall.gdshader")
	wall.set_shader_parameter("height", deck_height_for(cell_scale) - WALL_TOP_GAP)
	return wall

## Das Maß EINER Mulde für eine Karte dieses Maßstabs, ohne Deckel durch die Teilung.
static func bay_size_for(cell_scale: float) -> Vector2:
	return Vector2(DataCellView.WIDTH, DataCellView.HEIGHT) * cell_scale * BAY_ROOM

## Eine PLATTE über die Breite span (Welt-Z) um center, length lang (Welt-X).
func _build_plate(host: Node3D, plate_name: String, span: float, center: float,
		length: float, mid_x: float, sink: float, material: Material) -> void:
	TableProps.box(host, plate_name, Vector3(length, PLATE - sink, span),
		Vector3(mid_x, -(PLATE + sink) * 0.5, center), material)

## Die Oberfläche der Spalte: genau Kartenoberkante - eine Karte in ihrer Mulde liegt
## bündig (Spieler-Wunsch 2026-10-28).
func deck_height() -> float:
	return deck_height_for(_scale)

static func deck_height_for(cell_scale: float) -> float:
	return PROUD + DataCellView.DEPTH * cell_scale

## Je Querplatz einer Reihe ein eigener Saum.
func _row_seams() -> Array:
	var seams: Array = []
	for across in ACROSS:
		seams.append(_seam_material(BAY_EMPTY))
	return seams

## Die Leuchttische einer Reihe - nur die Kartenzufuhr hat welche.
func _row_lamps(column: int) -> Array:
	var lamps: Array = []
	if column == MagazinTrayDress.ZAHL:
		for across in ACROSS:
			lamps.append(MagazinTrayDress.lamp_material())
	return lamps

func _seam_material(tint: Color) -> StandardMaterial3D:
	var seam := StandardMaterial3D.new()
	seam.metallic = 0.2
	seam.roughness = 0.5
	seam.emission_enabled = true
	seam.albedo_color = tint
	seam.emission = tint
	seam.emission_energy_multiplier = SEAM_EMPTY_ENERGY
	return seam

## Ein Block leerer Mulden, ein Fenster plus SPARE_EXTRA lang, ab der Kante der
## Fenster-Mulden nach dir (+1 Bild-unten, -1 Bild-oben). Seine Lage schreibt
## _place_spares.
func _build_spares(bays: Node3D, column: int, block_name: String, dir: float, places: int,
		pitch: float, shape: Dictionary) -> Node3D:
	var block := Node3D.new()
	block.name = block_name
	bays.add_child(block)
	for i in places + SPARE_EXTRA:
		var node := Node3D.new()
		node.name = "Vorrat%d" % i
		node.position = Vector3(-dir * pitch * (float(i) + 0.5), 0.0, 0.0)
		block.add_child(node)
		# Die Rippe am äußeren Rand: die innere trägt schon der Nachbar.
		_build_segment(node, column, pitch, shape, [dir] as Array[float], _row_seams(),
			_row_lamps(column))
	block.position.x = -dir * _span.x * 0.5
	return block

## Die Vorrats-Blöcke einer Spalte bei Zug-Versatz x: am Rand der Fenster-Mulden, und
## wo der schon aus dem Fenster gerollt ist, um ganze Teilungen nachgerückt. Gerechnet
## wird längs der Spalte (r = -x, Bild-unten positiv).
func _place_spares(column: int, x: float) -> void:
	var pitch: float = _pitch.get(column, 0.0)
	if pitch <= 0.0:
		return
	var half := _span.x * 0.5
	var r := -x
	var below: Node3D = _spare_below.get(column)
	if below != null and is_instance_valid(below):
		var lag := ceili(((-half - pitch) - (r + half)) / pitch)
		below.position.x = -(half + pitch * float(maxi(lag, 0)))
	var above: Node3D = _spare_above.get(column)
	if above != null and is_instance_valid(above):
		var lead := ceili(((r - half) - (half + pitch)) / pitch)
		above.position.x = half + pitch * float(maxi(lead, 0))

## Der EINE Schreiber der Saum-Farben: Sortenfarbe hell, leer kühl und stumpf.
func _write_bays(column: int) -> void:
	if column < 0 or column >= _seams.size():
		return
	var seams: Array = _seams[column]
	var tints: Array = _tints[column]
	for i in seams.size():
		var tint: Color = tints[i] if i < tints.size() else BAY_EMPTY
		var material: StandardMaterial3D = seams[i]
		material.albedo_color = tint
		material.emission = tint
		material.emission_energy_multiplier = \
			SEAM_EMPTY_ENERGY if tint == BAY_EMPTY else SEAM_FILLED_ENERGY
	var lamps: Array = _lamps[column] if column < _lamps.size() else []
	for i in lamps.size():
		var lit: Color = tints[i] if i < tints.size() else BAY_EMPTY
		MagazinTrayDress.write_lamp(lamps[i], lit, lit != BAY_EMPTY)

# --- Bausteine -----------------------------------------------------------------------

func _ensure_materials() -> void:
	if _wall_material != null:
		return
	_wall_material = ShaderMaterial.new()
	_wall_material.shader = load("res://assets/shaders/bay_wall.gdshader")
