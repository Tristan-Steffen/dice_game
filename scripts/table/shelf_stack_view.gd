class_name ShelfStackView
extends Node3D
## Das SORTEN-MAGAZIN (Layout A, 2026-11-18): VIER SPALTEN nebeneinander in EINER flachen
## Grube, eine je SORTE (Pack.SHELF_ORDER), alle auf derselben Höhe. Jede Spalte trägt EINE
## Lane auf ihrer Platte und ROLLT für sich senkrecht: ein Zug schiebt ihr FACH längs Welt-X,
## was das Fenster verläßt, gleitet durch die Schlitze der Wände oben und unten unter den Filz.
##
## Die Karten LIEGEN flach (Netz nach oben, Langseite quer) und sind KINDER des Faches ihrer
## Spalte: eine Fahrt trägt sie mit. Eine Karte, die das Fenster verlassen hat, ist
## WEGGESTECKT (DataCellView.set_tucked) - oben läge sie sonst unter dem Graben der Walze.
##
## Die Maße kommen von außen (scene_root rechnet die gemeldete Grube und die Spalten in
## Welt), die HÖHE gehört dem Magazin. Endzustand zuerst: der Roll-Stand ist gebucht,
## bevor das Fach fährt. Längs der Spalte zählt Bild-unten, also Welt -X.

const COLUMNS := PackDrawerView.COLUMNS

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

## Der Anteil der Spaltenbreite, den die BLENDE am linken Rand nimmt (PackDrawerView
## schneidet die Plätze an derselben Zahl - EINE Quelle).
const BAND_SHARE := PackDrawerView.BAND_SHARE
const NUMBER_FONT := 48
## Wie weit das Kürzel vom unteren Blenden-Ende einrückt, in Blenden-Breiten.
const NUMBER_INSET := 1.0
## Hervorgehoben (die Sorte der Option unter dem Zeiger) leuchten Kürzel und Saum heller.
const HIGHLIGHT_GAIN := 2.2
const HIGHLIGHT_RISE := 0.004
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
## Das GLIMMEN an der Wand, hinter der in dieser Spalte noch Karten liegen.
const HINT_WIDTH := 0.05
const HINT_HEIGHT := 0.05
const HINT_COLOR := Color(1.0, 0.83, 0.1)
const HINT_ENERGY := 1.2

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

## Die Platten sind UNDURCHSICHTIG (Spieler-Entscheid 2026-09-09): dunkles Blech, ohne
## Rand - nur die Karten und die Blende unterscheiden eine Spalte.
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
## Die gemeldete Spalten-Geometrie in WELT: je Spalte (Mitte relativ zur Grubenmitte in
## Welt-Z, Breite). Leer = der kopflose Rückfall, gleiche Streifen.
var _lanes: Array[Vector2] = []

var _columns: Array[Node3D] = []
var _fachs: Array[Node3D] = []
var _bands: Array[Node3D] = []
var _labels: Array[Label3D] = []
var _glows: Array[MeshInstance3D] = []
var _tints: Array = []          # Spalte -> Array[Color], zuletzt geschrieben
var _rolled := {}               # Spalte -> schon nach unten gerollt (Vorrat oben)
var _wall_material: ShaderMaterial
var _spare_below := {}           # Spalte -> Vorrats-Block unten
var _spare_above := {}           # Spalte -> Vorrats-Block oben (nur gerollt)
var _pitch := {}                 # Spalte -> Muldenteilung
var _bays: Array[Node3D] = []    # Spalte -> Mulden-Knoten
var _seams: Array = []          # Spalte -> Array[StandardMaterial3D], je Mulde
var _lip_material: StandardMaterial3D
var _floor_material: ShaderMaterial
var _plate_material: StandardMaterial3D
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
## Je Spalte zwei Glimm-Balken (oben, unten) und ob sie stehen sollen.
var _hints: Array = []
var _overflow: Array[Vector2i] = []
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
## GLASPUNKT der Grubenmitte, span = ihr Weltmaß (x quer/Bild-hoch, y längs/Bild-
## breit), cell_scale der Anzeige-Maßstab der Karten, lanes die gemeldeten Spalten.
func setup(at: Vector3, span: Vector2, cell_scale: float,
		lanes: Array[Vector2] = []) -> void:
	var wanted := Vector2(maxf(span.x, 0.01), maxf(span.y, 0.01))
	if _built and _seat.is_equal_approx(at) and _span.is_equal_approx(wanted) \
			and is_equal_approx(_scale, cell_scale) and _lanes == lanes:
		return
	_seat = at
	_span = wanted
	_scale = cell_scale
	_lanes = lanes.duplicate()
	global_position = at
	_tune_bay_floor()  # das Samt-Feld hängt an der Grube, nicht an der Spalte
	_ensure_columns()
	for column in COLUMNS:
		_build_column(column)
	_build_pocket()
	_build_hints()
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
		_bands.append(null)
		_labels.append(null)
		_glows.append(null)
		_bays.append(null)
		_tints.append([] as Array[Color])
		_seams.append([])
		_overflow.append(Vector2i.ZERO)

## Platte, BLENDE und MULDEN einer Spalte. Das Fach bleibt stehen - es trägt die Karten.
func _build_column(column: int) -> void:
	_ensure_materials()
	var node := _columns[column]
	node.position = Vector3(0.0, -read_drop(_scale), 0.0)
	for child in node.get_children():
		if child == _fachs[column]:
			continue
		node.remove_child(child)
		child.queue_free()
	# Die Platten der Spalten kacheln die ganze Grube: Ränder und Rand gehören ihnen mit.
	_build_plate(node, "Platte", plate_span(column), plate_center(column), _span.x, 0.0, 0.0)
	_build_band(node, column)
	_build_bays(node, column)

## Die BLENDE einer Spalte: am linken Rand IHRER Lane, unten das Kürzel ihrer Sorte in
## ihrer Sortenfarbe, von unten nach oben zu lesen.
func _build_band(host: Node3D, column: int) -> void:
	var band := Node3D.new()
	band.name = "Blende%d" % (column + 1)
	band.position = Vector3(0.0, 0.0,
		lane_z(column) - lane_width(column) * 0.5 + band_width(column) * 0.5)
	host.add_child(band)
	_bands[column] = band
	var label := Label3D.new()
	label.name = "Kuerzel"
	label.text = column_label(column)
	label.font_size = NUMBER_FONT
	# Flach auf dem Filz, die Schrift läuft Bild-aufwärts (Welt +X).
	label.transform.basis = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	label.pixel_size = band_width(column) * 0.7 / (float(NUMBER_FONT) * 0.62)
	# Der Anfang steht fest: das Kürzel ist unterschiedlich lang.
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position = Vector3(-_span.x * 0.5 + band_width(column) * NUMBER_INSET,
		deck_height() + 0.01, 0.0)
	label.outline_size = 12
	label.outline_modulate = Color(0.03, 0.03, 0.05)
	band.add_child(label)
	_labels[column] = label
	# Der Saum der Hervorhebung liegt über die volle Länge der Blende auf dem Deck.
	var glow := MeshInstance3D.new()
	glow.name = "Hervorhebung"
	var box := BoxMesh.new()
	box.size = Vector3(_span.x, HIGHLIGHT_RISE, band_width(column) * 0.25)
	glow.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = column_tint(column) * HIGHLIGHT_GAIN
	glow.material_override = material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = Vector3(0.0, deck_height() + HIGHLIGHT_RISE * 0.5,
		band_width(column) * 0.25)
	band.add_child(glow)
	_glows[column] = glow
	_write_highlight()

## Die WANDTASCHEN hinter den Schlitzen der Wände oben und unten: geschlossene Kästen von
## der Wand weg, so tief wie ein hinausgerollter Platz samt Luft, zur Grube hin offen. Sie
## liegen außerhalb des Lochs, also sieht man sie NUR durch den Schlitz.
func _build_pocket() -> void:
	if _pocket != null and is_instance_valid(_pocket):
		remove_child(_pocket)
		_pocket.queue_free()
	var host := Node3D.new()
	host.name = "Wandtaschen"
	add_child(host)
	_pocket = host
	_build_pocket_side(host, 1.0, top_pocket_depth())
	_build_pocket_side(host, -1.0, bottom_pocket_depth())

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

## EINE Wandtasche, außen an der Wand der Seite side (+1 = Bild-oben, Welt +X).
func _build_pocket_side(parent: Node3D, side: float, deep: float) -> void:
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
	# So breit wie die GANZE Grube - der Schlitz läuft über deren volle Breite.
	var wide := _span.y + POCKET_WALL * 2.0
	var mid_x := near + deep * 0.5
	var reach := near + deep
	var rect := Rect2(Vector2(_seat.x + (near if side > 0.0 else -reach),
		_seat.z - wide * 0.5), Vector2(deep, wide))
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

## Die Grube in WELT-XZ - das Feld, an dem sich jede Auskleidung des Magazins mißt.
func _pit_field() -> Rect2:
	return Rect2(Vector2(_seat.x, _seat.z) - _span * 0.5, _span)

## Der BODEN einer MULDE trägt dieselbe ARCHIV-Auskleidung wie die Grube selbst; sein
## Samt-LICHT mißt an der ganzen Grube, sein MUSTER fährt mit der Mulde.
func _tune_bay_floor() -> void:
	if _floor_material == null:
		return
	PackPitView.tune_lining(_floor_material, 1.0, BAY_FLOOR_ALBEDO,
		BAY_FLOOR_ENERGY, _pit_field(), _seat.y, stack_depth(_scale),
		PackPitView.GLOW_COLOR, null)
	_floor_material.set_shader_parameter("pattern_local", 1.0)

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

## Die Breite der Blende in Welt.
func band_width(column := 0) -> float:
	return lane_width(column) * BAND_SHARE

## Die Grenzen der PLATTE einer Spalte (Welt-Z, von links nach rechts): die Grubenkante
## bzw. die Mitte des Randes zur Nachbarspalte.
func plate_bounds(column: int) -> Vector2:
	var left := -_span.y * 0.5
	var right := _span.y * 0.5
	if column > 0:
		left = (lane_z(column - 1) + lane_width(column - 1) * 0.5
			+ lane_z(column) - lane_width(column) * 0.5) * 0.5
	if column < COLUMNS - 1:
		right = (lane_z(column) + lane_width(column) * 0.5
			+ lane_z(column + 1) - lane_width(column + 1) * 0.5) * 0.5
	return Vector2(left, right)

func plate_span(column: int) -> float:
	var bounds := plate_bounds(column)
	return maxf(bounds.y - bounds.x, 0.05)

func plate_center(column: int) -> float:
	var bounds := plate_bounds(column)
	return (bounds.x + bounds.y) * 0.5

## Die Mitte der Plätze einer Spalte (Welt-Z): ihre Lane ohne die Blende.
func slot_z(column: int) -> float:
	return lane_z(column) + band_width(column) * 0.5

func slot_width(column: int) -> float:
	return lane_width(column) * (1.0 - BAND_SHARE)

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

## Das GLIMMEN an den Wänden einer Spalte: oben stehen noch hinausgerollte Karten,
## unten noch ungezeigte. Idempotent.
func set_overflow(column: int, above: bool, below: bool) -> void:
	if column < 0 or column >= _overflow.size():
		return
	_overflow[column] = Vector2i(1 if above else 0, 1 if below else 0)
	_write_hints()

func overflow(column: int) -> Vector2i:
	if column < 0 or column >= _overflow.size():
		return Vector2i.ZERO
	return _overflow[column]

## Die HERVORHEBUNG einer Spalte (-1 = keine): Kürzel und Saum leuchten heller.
func set_highlight(column: int) -> void:
	var wanted := column if column >= 0 and column < COLUMNS else -1
	if wanted == _highlight:
		return
	_highlight = wanted
	_write_highlight()

func highlighted() -> int:
	return _highlight

func _write_highlight() -> void:
	for column in _labels.size():
		var on := column == _highlight
		var label := _labels[column]
		if label != null and is_instance_valid(label):
			label.modulate = column_tint(column) * (HIGHLIGHT_GAIN if on else 1.0)
		var glow := _glows[column]
		if glow != null and is_instance_valid(glow):
			glow.visible = on

func _build_hints() -> void:
	for pair: Array in _hints:
		for bar: MeshInstance3D in pair:
			if is_instance_valid(bar) and bar.get_parent() != null:
				bar.get_parent().remove_child(bar)
				bar.queue_free()
	_hints.clear()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = HINT_COLOR * HINT_ENERGY
	for column in COLUMNS:
		var pair: Array[MeshInstance3D] = []
		for side in 2:
			var bar := MeshInstance3D.new()
			bar.name = "Glimmen%s" % ("Oben" if side == 0 else "Unten")
			var box := BoxMesh.new()
			box.size = Vector3(HINT_WIDTH, HINT_HEIGHT, slot_width(column))
			bar.mesh = box
			bar.material_override = material
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var dir := 1.0 if side == 0 else -1.0
			bar.position = Vector3(dir * (_span.x * 0.5 - HINT_WIDTH * 0.5),
				PROUD + HINT_HEIGHT * 0.5, slot_z(column))
			_columns[column].add_child(bar)
			pair.append(bar)
		_hints.append(pair)
	_write_hints()

func _write_hints() -> void:
	for column in _hints.size():
		var pair: Array = _hints[column]
		for side in pair.size():
			var bar: MeshInstance3D = pair[side]
			if is_instance_valid(bar):
				bar.visible = (_overflow[column].x if side == 0 else _overflow[column].y) > 0

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

# --- Die BLENDE ----------------------------------------------------------------------

## Die Aufschrift der Blende: das KÜRZEL der Sorte.
static func column_label(column: int) -> String:
	return Pack.shelf_short(String(Pack.SHELF_ORDER[clampi(column, 0, COLUMNS - 1)]))

## Die Sortenfarbe der Spalte.
static func column_tint(column: int) -> Color:
	return PackDrawerView.COLORS.get(Pack.SHELF_ORDER[clampi(column, 0, COLUMNS - 1)],
		PackDrawerView.GOLD)

## Die Sortenfarben einer Spalte, je Stellplatz eine (BAY_EMPTY = leer). Sie färben
## den Lichtsaum der Mulden; ändert sich die Platzzahl, werden die Mulden neu gebaut,
## sonst nur umgefärbt. Idempotent.
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

## Das Maß EINER Mulde bei so vielen Plätzen (x längs der Spalte, y quer): die liegende
## Karte plus Luft, gedeckelt von Teilung und Spalte, so daß zwischen zwei Mulden immer
## eine Lippe steht.
func bay_size(places: int, column := 0) -> Vector2:
	var pitch := _span.x / float(maxi(places, 1))
	return Vector2(
		minf(DataCellView.WIDTH * _scale * BAY_ROOM, pitch - LIP_MIN),
		minf(DataCellView.HEIGHT * _scale * BAY_ROOM, slot_width(column) - LIP_MIN * 2.0))

## Welt-X eines Platzes einer Spalte bei so vielen Plätzen: Platz 0 oben.
func _place_x(index: float, pitch: float) -> float:
	return _span.x * 0.5 - pitch * (index + 0.5)

## Die MULDEN einer Spalte: je Platz EIN Stück aus Platte, Deck, Lippen, Rippe und
## Mulde (Saum, Boden, Buchse) - in Stücken, damit hinausgerollte für sich verschwinden.
func _build_bays(host: Node3D, column: int) -> void:
	var old: Node3D = _bays[column] if column < _bays.size() else null
	if old != null and is_instance_valid(old):
		# Ein Neubau der Spalte hat den Knoten schon ausgehängt - dann nur freigeben.
		if old.get_parent() != null:
			old.get_parent().remove_child(old)
		old.queue_free()
	_bays[column] = null
	_seams[column] = []
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
	var places := tints.size()
	var pitch := _span.x / float(places)
	var shape := _segment_shape(column, places)
	var rolled: bool = _rolled.get(column, false)
	var seams: Array = []
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
		var seam := _seam_material(BAY_EMPTY)
		_build_segment(node, column, pitch, shape, ribs, seam)
		seams.append(seam)
	# Die VORRATS-Mulden: unten immer, oben erst nach dem Rollen. Sie rollen mit und
	# springen beim Zug um ganze Teilungen nach - so ist das Fenster bei jedem Zug voll.
	_spare_below[column] = _build_spares(bays, column, "VorratUnten", 1.0, places, pitch,
		shape)
	_spare_above[column] = _build_spares(bays, column, "VorratOben", -1.0, places, pitch,
		shape) if rolled else null
	_pitch[column] = pitch
	_seams[column] = seams
	_place_spares(column, bays.position.x)
	_write_bays(column)
	_write_segments(column)

## Die Quer-Maße eines Stücks: Mulde, Lippe, Rippe und die mitrollende Platte (Mitte
## quer relativ zu den Plätzen, Breite).
func _segment_shape(column: int, places: int) -> Dictionary:
	var bay := bay_size(places, column)
	var pitch := _span.x / float(maxi(places, 1))
	return {"bay": bay, "rail": (slot_width(column) - bay.y) * 0.5, "rib": pitch - bay.x,
		"under": Vector2(plate_center(column) - slot_z(column), plate_span(column))}

## EIN Stück der Spalte, pitch lang um seinen Knoten (längs Welt-X): die mitrollende
## PLATTE eine Spur UNTER der festen (sichtbar nur jenseits der Grubenwand), darauf das
## DECK auf Kartenhöhe neben der Mulden-Lane, die Lippen, die Rippen an den genannten
## Rändern (-1 oben, +1 unten, ±0.5 halb und innen) und die Mulde selbst.
func _build_segment(node: Node3D, column: int, pitch: float, shape: Dictionary,
		ribs: Array[float], seam: StandardMaterial3D) -> void:
	var bay: Vector2 = shape["bay"]
	var rail: float = shape["rail"]
	var rib: float = shape["rib"]
	var under: Vector2 = shape["under"]
	_build_plate(node, "Unterplatte", under.y, under.x, pitch, 0.0, UNDERPLATE_SINK)
	for strip: Vector2 in _deck_strips(column):
		TableProps.box(node, "Deck", Vector3(pitch, deck_height(), strip.y - strip.x),
			Vector3(0.0, deck_height() * 0.5, (strip.x + strip.y) * 0.5), _lip_material)
	for side in 2:
		var dir := float(side) * 2.0 - 1.0
		TableProps.box(node, "Lippe%d" % side, Vector3(pitch, deck_height(), rail),
			Vector3(0.0, deck_height() * 0.5, dir * (bay.y + rail) * 0.5), _lip_material)
	for edge: float in ribs:
		var width := rib * (0.5 if absf(edge) < 0.75 else 1.0)
		# Längs der Spalte zählt Bild-unten: +1 ist der untere Rand, also Welt -X.
		var down := signf(edge) * pitch * 0.5
		if absf(edge) < 0.75:
			down -= signf(edge) * width * 0.5
		TableProps.box(node, "Rippe%s" % ("O" if edge < 0.0 else "U"),
			Vector3(width, deck_height(), bay.y), Vector3(-down, deck_height() * 0.5, 0.0),
			_lip_material)
	_build_bay(node, bay, seam)

## EINE Mulde: Saum, Boden und die BUCHSE am Bild-rechten Ende.
func _build_bay(node: Node3D, bay: Vector2, seam: StandardMaterial3D) -> void:
	build_bay(node, bay, seam, _scale, _wall_material, _floor_material)

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
		length: float, mid_x: float, sink: float) -> void:
	TableProps.box(host, plate_name, Vector3(length, PLATE - sink, span),
		Vector3(mid_x, -(PLATE + sink) * 0.5, center), _plate_material)

## Die DECK-Streifen einer Spalte, relativ zur Mitte ihrer Plätze (von, bis; Welt-Z):
## links Blende und halber Rand, rechts der halbe Rand.
func _deck_strips(column: int) -> Array[Vector2]:
	var bounds := plate_bounds(column)
	var slot_left := lane_z(column) - lane_width(column) * 0.5 + band_width(column)
	var slot_right := lane_z(column) + lane_width(column) * 0.5
	var mid := slot_z(column)
	var strips: Array[Vector2] = [
		Vector2(bounds.x - mid, slot_left - mid),
		Vector2(slot_right - mid, bounds.y - mid)]
	return strips.filter(func(strip: Vector2) -> bool: return strip.y - strip.x > 0.001)

## Die Oberfläche der Spalte: genau Kartenoberkante - eine Karte in ihrer Mulde liegt
## bündig (Spieler-Wunsch 2026-10-28).
func deck_height() -> float:
	return deck_height_for(_scale)

static func deck_height_for(cell_scale: float) -> float:
	return PROUD + DataCellView.DEPTH * cell_scale

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
		_build_segment(node, column, pitch, shape, [dir] as Array[float],
			_seam_material(BAY_EMPTY))
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

# --- Bausteine -----------------------------------------------------------------------

func _ensure_materials() -> void:
	if _plate_material != null:
		return
	_plate_material = _metal(PLATE_ALBEDO, PLATE_EMISSION, PLATE_ENERGY)
	# Die Lippe ist Platte; der Muldenboden liegt dunkler.
	_lip_material = _plate_material
	_wall_material = ShaderMaterial.new()
	_wall_material.shader = load("res://assets/shaders/bay_wall.gdshader")
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = load("res://assets/shaders/pit_lining.gdshader")
	_tune_bay_floor()

func _metal(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	return TableProps.metal(albedo, emission, energy, 0.35, 0.55)
