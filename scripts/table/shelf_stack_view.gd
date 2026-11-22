class_name ShelfStackView
extends Node3D
## Das SORTEN-MAGAZIN (Layout C, 2026-11-20): VIER TRAYS nebeneinander, einer je SORTE
## (Pack.SHELF_ORDER), jeder in seinem eigenen Schacht, alle auf derselben Höhe; dazwischen
## liegt Filz. Jeder Tray ist ein UMLAUFREGAL (Plan docs/plan_magazin_umlaufregal.md): je
## REIHE eine starre LAMELLE, und ein Zug rollt das Band längs Welt-X. Am Ende kippt die
## vorderste Lamelle samt ihren Karten über die ACHSE an der Kante in den Schacht, am anderen
## schwenkt die nächste hoch. Lage und Winkel sind eine reine Funktion des Roll-Versatzes
## (lamella_pose) - kein eigener Tween.
##
## Die Karten LIEGEN flach (Netz nach oben, Langseite quer) und sind KINDER des Faches ihrer
## Spalte: sein Versatz IST der Roll-Versatz. Ihr Körper folgt ihrer Lamelle (set_carry),
## erst ganz unten ist sie WEGGESTECKT (set_tucked).
##
## Die Maße kommen von außen (scene_root rechnet die gemeldeten Gruben in Welt), die
## HÖHE gehört dem Magazin. Endzustand zuerst: der Roll-Stand ist gebucht,
## bevor das Fach fährt. Längs der Spalte zählt Bild-unten, also Welt -X.

const COLUMNS := PackDrawerView.COLUMNS
const ACROSS := PackDrawerView.ACROSS

## Eine Lamelle hat eine Platte; die Karte liegt eine Spur darüber (koplanar stritten
## sie im Tiefenpuffer).
const PLATE := 0.06
## Die Karte liegt in ihrer MULDE auf der Boden-Einlage - um BAY_FLOOR über der
## Platte; PROUD mißt vom Muldenboden aus. Lippen und Rippen reichen bis Kartenoberkante
## (deck_height), die liegende Karte ist bündig mit der Lamelle.
const BAY_FLOOR := 0.05
## Die Dicke der liegenden Karte und ihre Spur über dem Boden (koplanar stritten
## sie im Tiefenpuffer).
const CARD_THICKNESS := DataCellView.DEPTH * PackDrawerView.CASSETTE_SCALE
const FLOOR_PROUD := 0.006
const PROUD := BAY_FLOOR + FLOOR_PROUD
## Die Luft, die die Karte unter der Tischkante behält - keine Karte ragt je über
## die Kante.
const RIM_CLEAR := CARD_THICKNESS * 0.5
## Und wie weit der GRIFF sie beim Überfahren aus der Grube zieht: bis eine
## Kartendicke über das Glas - nur der Hover darf über die Kante.
const HOVER_PROUD := CARD_THICKNESS
## So tief unter ihrem Platz beginnt eine gelieferte Karte ihren Aufstieg: unter der
## Platte ihrer Lamelle.
const RISE_DEPTH := CARD_THICKNESS + PLATE + PROUD

## Der Anteil der Grubenbreite, den die ROLLSCHIENE rechts nimmt (PackDrawerView
## schneidet die Plätze an derselben Zahl - EINE Quelle).
const RAIL_SHARE := PackDrawerView.RAIL_SHARE
## Hervorgehoben (die Sorte der Option unter dem Zeiger) leuchtet die Lichtleiste heller.
const HIGHLIGHT_GAIN := 2.2
## Die Fassung ohne Meldung (kopflos): Seite, oben, unten in Welt.
const MARGINS_FALLBACK := Vector3(0.21, 0.21, 0.9)
## Die MULDE je Stellplatz: die Platte der Lamelle ist ihr Boden, Lippen und Rippen ihr
## Rand bis Kartenhöhe, am Boden ein LICHTSAUM in der Sortenfarbe (leer kühl und stumpf).
const BAY_ROOM := 1.06
const LIP_MIN := 0.06
const SEAM_WIDTH := 0.05
const SEAM_RISE := 0.006
const FLOOR_RISE := 0.010
const BAY_EMPTY := Color(0.34, 0.38, 0.58)
const SNAP_TIME_MAX := 0.45
## Die Wand-Auskleidung einer Mulde: Stärke, Abstand zur Lippe, Luft unter dem Deck.
const WALL_LINING := 0.012
const WALL_INSET := 0.004
const WALL_TOP_GAP := 0.003
const SEAM_EMPTY_ENERGY := 0.85
const SEAM_FILLED_ENERGY := 0.9

## Das EINRASTEN nach einem Zug auf den nächsten ganzen Platz.
const SNAP_TIME := 0.16

## Der BODEN einer Laden-MULDE (CardRecessView): Archiv-Auskleidung, dunkel - in ein
## Kartenfach sieht die Station fast senkrecht hinein. GEMESSEN 2026-10-26.
const BAY_FLOOR_ALBEDO := Color(0.095, 0.088, 0.14)
const BAY_FLOOR_ENERGY := 1.8

## Das dunkle Blech der Laden-Mulden (CardRecessView); die Trays tragen ihr Gerät.
const PLATE_ALBEDO := Color(0.22, 0.212, 0.285)
const PLATE_EMISSION := Color(0.46, 0.48, 0.66)
const PLATE_ENERGY := 0.42

## Die Lagen einer Lamelle (lamella_pose): flach im Fenster, am Ende im Kippen, darunter
## hängend, ganz unten fort.
const LAM_FLAT := 0
const LAM_TIP := 1
const LAM_HANG := 2
const LAM_GONE := 3
## So viele Lamellen hält ein Tray über das Fenster hinaus vorrätig (je Ende kippt eine,
## hängt eine, und eine Teilung Spiel).
const LAMELLA_SPARE := 4
## Die ACHSE an jeder Kante: Welle und Kettenräder (Welt). Ihre Mitte liegt im Streifen
## zwischen Fassungslippe und Kartenende und eine Spur unter der Oberkante - so liest sie
## auch in Ruhe, ohne über eine Karte zu ragen.
const AXLE_RADIUS := 0.06
const AXLE_DROP := 0.03
const SPROCKET_RADIUS := 0.2
const SPROCKET_WIDTH := 0.06
const SPROCKET_TEETH := 10
const SPROCKET_INSET := 0.11
## Luft zwischen dem, was über die Kante kippt, und der Schachtwand; unter der tiefsten
## Lamelle bis zum Boden.
const SHAFT_CLEAR := 0.06
const SHAFT_AIR := 0.04
const REACH_SAMPLES := 64

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
var _tints: Array = []          # Spalte -> Array[Color] je RANG der Spalte
var _frames: Array[Node3D] = []  # Spalte -> Fassung auf dem Filz
var _bars: Array = []           # Spalte -> {bar, label, material} der Lichtleiste
var _bar_texts: Array[String] = []
## Die ROLLSCHIENE je Tray: Schieber, Reihen (gesamt, im Fenster) und der gebuchte
## Roll-Stand (ein laufender Zug kommt live dazu).
var _thumbs: Array[MeshInstance3D] = []
var _rail_rows: Array[Vector2i] = []
var _rail_scroll: Array[int] = []
## Der Roll-Stand, für den das Fach auf 0 steht - er wechselt erst, wenn der Versatz in
## die Karten übergeht (bake_scroll), nie mitten in einer Fahrt.
var _fach_base: Array[int] = []
var _wall_material: ShaderMaterial
var _lamellae: Array = []       # Spalte -> Array[Node3D], der Vorrat an Lamellen
var _lam_rows: Array = []       # Spalte -> Array[int], die Reihe, die jede gerade trägt
var _seams: Array = []          # Spalte -> je Lamelle Array[StandardMaterial3D]
var _lamps: Array = []          # Spalte -> je Lamelle die Leuchttische (nur Kartenzufuhr)
var _axles: Array = []          # Spalte -> [oben, unten] die drehenden Räder
var _grips: Array = []          # Spalte -> Griffrillen des Schiebers
## Der ROLL-Zug: welche Spalte gerade vom Zeiger geführt wird (-1 = keine), und das
## Einrasten danach.
var _scrolling := -1
var _snap: Tween
var _snap_column := -1
var _snap_to := 0.0
var _highlight := -1

func _init() -> void:
	name = "ShelfStack"

## Gleitet eine Karte im Fach auf einen neuen Platz, folgt ihre Lamelle ihr je Bild.
func _process(_delta: float) -> void:
	for column in _fachs.size():
		_write_cards(column)

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

## Wie tief eine FLACHE Lamelle reicht - Trittfläche plus Platte.
static func stack_depth(cell_scale: float) -> float:
	return read_drop(cell_scale) + PLATE

## Die Oberkante einer Lamelle (Lippen, Rippen) unter dem Glas: dort liegt ihr Scharnier.
static func deck_drop(cell_scale: float) -> float:
	return read_drop(cell_scale) - deck_height_for(cell_scale)

## Der KIPPWINKEL über den Weg, auf dem die Lamelle das Fenster verläßt (share 0..1):
## glatt von flach bis senkrecht, früh steil genug, daß ihr Ende nur knapp über die Kante
## hinausreicht.
static func tip_angle(share: float) -> float:
	return PI * 0.5 * sin(PI * 0.5 * clampf(share, 0.0, 1.0))

## DIE KIPP-FUNKTION: die Lage einer Lamelle aus ihrer FLACHEN Mitte x (Spalten-lokal,
## jenseits des Fensters erlaubt), der halben Fensterlänge half, ihrer Länge pitch und der
## Höhe top ihrer Oberkante. {state, transform, angle}: transform führt die flache Lamelle
## in ihre Lage. Ihr Scharnier ist die hintere Oberkante; es SINKT beim Kippen um die Dicke
## der Lamelle, so daß sie senkrecht ganz UNTER der flachen Nachbarin steht - auf Deckhöhe
## deckte ihr Ende sonst die Randreihe des Fensters zu. Die nächste hängt senkrecht unter
## ihrer vorderen Unterkante.
static func lamella_pose(x: float, half: float, pitch: float, top: float) -> Dictionary:
	var side := 1.0 if x >= 0.0 else -1.0
	var u := x * side
	var way := u + pitch * 0.5 - half
	if way <= 0.0:
		return {"state": LAM_FLAT, "transform": Transform3D.IDENTITY, "angle": 0.0}
	if way >= pitch * 2.0:
		return {"state": LAM_GONE, "transform": Transform3D.IDENTITY, "angle": PI * 0.5}
	var hinge := Vector2(u - pitch * 0.5, top)
	var thick := top + PLATE
	if way < pitch:
		var angle := tip_angle(way / pitch)
		var sunk := hinge - Vector2(0.0, thick * (1.0 - cos(angle)))
		return {"state": LAM_TIP, "transform": _tip_transform(side, hinge, sunk, angle),
			"angle": angle}
	# Sie hängt an der vorderen Unterkante der kippenden Lamelle davor.
	var inner := tip_angle((way - pitch) / pitch)
	var corner := Vector2(u - pitch * 1.5 + pitch * cos(inner) - thick * sin(inner),
		top - thick - pitch * sin(inner))
	return {"state": LAM_HANG, "transform": _tip_transform(side, hinge, corner, PI * 0.5),
		"angle": PI * 0.5}

## Drehung um die Scharnier-Kante (längs Z) nach unten zum Ende side hin, dann aufs Ziel.
static func _tip_transform(side: float, hinge: Vector2, to: Vector2, angle: float) -> Transform3D:
	var basis := Basis(Vector3.BACK, -side * angle)
	var pivot := Vector3(hinge.x * side, hinge.y, 0.0)
	return Transform3D(basis, Vector3(to.x * side, to.y, 0.0) - basis * pivot)

## Wie weit eine Lamelle beim Kippen höchstens über die Kante hinausreicht (ihre Vorderkante;
## der Körper liegt dahinter).
static func tip_reach(pitch: float) -> float:
	var most := 0.0
	for i in REACH_SAMPLES + 1:
		var share := float(i) / float(REACH_SAMPLES)
		most = maxf(most, pitch * (share - 1.0 + cos(tip_angle(share))))
	return most

## Wie weit die Wand des Schachts hinter der Lochkante steht: Platz für Kippen und Achse.
static func shaft_setback(pitch: float) -> float:
	return maxf(tip_reach(pitch), SPROCKET_RADIUS - SPROCKET_INSET) + SHAFT_CLEAR

## Wie tief der SCHACHT unter dem Glas reicht: bis unter die senkrecht hängende Lamelle, die
## um ihre eigene Dicke unter dem Deck beginnt.
static func shaft_depth(cell_scale: float, pitch: float) -> float:
	return stack_depth(cell_scale) + pitch + SHAFT_AIR

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
		_tints.append([] as Array[Color])
		_lamellae.append([])
		_lam_rows.append([])
		_seams.append([])
		_lamps.append([])
		_axles.append([])
		_grips.append(null)
		_frames.append(null)
		_bars.append({})
		_bar_texts.append("")
		_thumbs.append(null)
		_rail_rows.append(Vector2i(0, PackDrawerView.PLACES))
		_rail_scroll.append(0)
		_fach_base.append(0)

## Platte der Schiene, ROLLSCHIENE, LAMELLEN und ACHSEN eines Trays. Das Fach bleibt
## stehen - es trägt die Karten.
func _build_column(column: int) -> void:
	var node := _columns[column]
	node.position = Vector3(0.0, -read_drop(_scale), 0.0)
	for child in node.get_children():
		if child == _fachs[column]:
			continue
		node.remove_child(child)
		child.queue_free()
	# Fest steht nur noch die Platte unter der Schiene - die Plätze tragen ihre Lamellen.
	_build_plate(node, "Platte", rail_width(column), rail_z(column), _span.x, 0.0, 0.0,
		MagazinTrayDress.inside_material(column))
	_build_rail(node, column)
	_build_lamellae(node, column)
	_build_axles(node, column)

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

## Die Grenzen der Grube eines Trays (Welt-Z, von links nach rechts).
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

## Fach, Lamellen, Achsen und Schieber folgen demselben Versatz.
func _roll_to(column: int, x: float) -> void:
	_fachs[column].position.x = x
	_write_lamellae(column)
	_write_cards(column)
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

## Der Versatz des Fachs geht in seine Karten über, das Fach steht wieder auf 0 und auf dem
## gebuchten Stand - die Welt-Plätze bleiben byteweise, wo sie sind.
func bake_scroll(column: int) -> void:
	if column < 0 or column >= _fachs.size():
		return
	var fach_node := _fachs[column]
	var offset := fach_node.position.x
	if not is_zero_approx(offset):
		for child in fach_node.get_children():
			(child as Node3D).position.x += offset
	fach_node.position.x = 0.0
	_fach_base[column] = _rail_scroll[column]
	_roll_to(column, 0.0)

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

## Die Länge einer Lamelle - die Reihen-Teilung des Fensters.
func lamella_length(column := 0) -> float:
	return _row_pitch(column)

## Die Lage der Lamelle, auf der ein Punkt mit FLACHER Spalten-Position x liegt (der
## Fach-Versatz eingerechnet): die Teilung des Bandes wird am Versatz gemessen.
func pose_at(column: int, x: float) -> Dictionary:
	var pitch := _row_pitch(column)
	var half := _span.x * 0.5
	var shift := _fachs[column].position.x if column >= 0 and column < _fachs.size() else 0.0
	var j := roundi((half + shift - x) / pitch - 0.5)
	return lamella_pose(half - pitch * (float(j) + 0.5) + shift, half, pitch, deck_height())

## Liegt diese Karte gerade flach im Fenster (greifbar)? Eine kippende ist es nicht.
func card_flat(cell: Node3D) -> bool:
	for column in _fachs.size():
		if cell != null and cell.get_parent() == _fachs[column]:
			return int(pose_at(column, _fachs[column].position.x + cell.position.x)["state"]) \
				== LAM_FLAT
	return true

## Jede Karte des Faches folgt IHRER Lamelle: Lage und Drehung am Körper, und erst ganz
## unten ist sie weggesteckt.
func _write_cards(column: int) -> void:
	if column < 0 or column >= _fachs.size():
		return
	var fach_node := _fachs[column]
	for child in fach_node.get_children():
		var cell := child as DataCellView
		if cell == null:
			continue
		var pose := pose_at(column, fach_node.position.x + cell.position.x)
		var state := int(pose["state"])
		if state == LAM_FLAT or state == LAM_GONE:
			cell.set_carry(Transform3D.IDENTITY)
		else:
			# Der Körper hängt am Ursprung der Karte: die Lage des Bandes in ihren Rahmen.
			var frame := fach_node.transform * cell.transform
			cell.set_carry(frame.affine_inverse() * (pose["transform"] as Transform3D) * frame)
		cell.set_tucked(state == LAM_GONE)

# --- Die LAMELLEN ------------------------------------------------------------------------

## Die Lamellen eines Trays: ein Vorrat, der das Fenster samt beider Enden deckt. Jede
## nimmt je Bild die Reihe, die gerade an ihrem Platz im Band läuft.
func _build_lamellae(host: Node3D, column: int) -> void:
	_ensure_materials()
	_wall_material.set_shader_parameter("height", deck_height() - WALL_TOP_GAP)
	var band := Node3D.new()
	band.name = "Lamellen"
	band.position = Vector3(0.0, 0.0, slot_z(column))
	host.add_child(band)
	var window := maxi(_rail_rows[column].y, 1)
	var pitch := _row_pitch(column)
	var shape := _segment_shape(column, window)
	var nodes: Array[Node3D] = []
	var rows: Array[int] = []
	var seams: Array = []
	var lamps: Array = []
	for i in window + LAMELLA_SPARE:
		var node := Node3D.new()
		node.name = "Lamelle%d" % i
		band.add_child(node)
		var row_seams := _row_seams()
		var row_lamps := _row_lamps(column)
		_build_segment(node, column, pitch, shape, [-0.5, 0.5] as Array[float], row_seams,
			row_lamps)
		nodes.append(node)
		rows.append(-2147483648)
		seams.append(row_seams)
		lamps.append(row_lamps)
	_lamellae[column] = nodes
	_lam_rows[column] = rows
	_seams[column] = seams
	_lamps[column] = lamps
	_write_lamellae(column)

## Der EINE Schreiber der Lamellen: Lage, Sichtbarkeit und - wenn sie eine andere Reihe
## übernimmt - ihre Farben.
func _write_lamellae(column: int) -> void:
	if column < 0 or column >= _lamellae.size():
		return
	var nodes: Array = _lamellae[column]
	if nodes.is_empty():
		return
	var count := nodes.size()
	var pitch := _row_pitch(column)
	var half := _span.x * 0.5
	var shift := _fachs[column].position.x
	var first := floori(shift / pitch - 2.0) + 1
	var rows: Array = _lam_rows[column]
	for i in count:
		var j := first + posmod(i - first, count)
		var x := half - pitch * (float(j) + 0.5) + shift
		var pose := lamella_pose(x, half, pitch, deck_height())
		var node: Node3D = nodes[i]
		node.visible = int(pose["state"]) != LAM_GONE
		node.transform = (pose["transform"] as Transform3D) \
			* Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0))
		var row := j + _fach_base[column]
		if int(rows[i]) != row:
			rows[i] = row
			_write_lamella_tint(column, i)
	_write_axles(column)

## Die Farben EINER Lamelle aus den Rängen ihrer Reihe: Sortenfarbe hell, leer kühl.
func _write_lamella_tint(column: int, index: int) -> void:
	var row: int = _lam_rows[column][index]
	var seams: Array = _seams[column][index]
	var lamps: Array = _lamps[column][index]
	for across in ACROSS:
		var tint := bay_tint(column, row * ACROSS + across)
		if across < seams.size():
			var seam: StandardMaterial3D = seams[across]
			seam.albedo_color = tint
			seam.emission = tint
			seam.emission_energy_multiplier = \
				SEAM_EMPTY_ENERGY if tint == BAY_EMPTY else SEAM_FILLED_ENERGY
		if across < lamps.size():
			MagazinTrayDress.write_lamp(lamps[across], tint, tint != BAY_EMPTY, column)

## Welche Reihe eine Lamelle gerade trägt (Test und Probe).
func lamella_row(column: int, index: int) -> int:
	return int(_lam_rows[column][index])

## Die ACHSEN an der oberen und unteren Kante: Welle und Kettenräder, eine Spur ins
## Fenster gerückt, knapp unter der Oberkante der Lamellen.
func _build_axles(host: Node3D, column: int) -> void:
	var wide := slot_width(column)
	# Die Räder laufen in den Lippen: außen an beiden Seiten und zwischen den Plätzen.
	var wheels := PackedFloat32Array([-wide * 0.5 + SPROCKET_WIDTH * 0.5, 0.0,
		wide * 0.5 - SPROCKET_WIDTH * 0.5])
	var turns: Array = []
	for side: float in [1.0, -1.0]:
		var node := Node3D.new()
		node.name = "AchseOben" if side > 0.0 else "AchseUnten"
		node.position = Vector3(side * (_span.x * 0.5 - SPROCKET_INSET),
			deck_height() - AXLE_DROP, slot_z(column))
		host.add_child(node)
		turns.append(MagazinTrayDress.build_axle(node, column, wide, AXLE_RADIUS,
			SPROCKET_RADIUS, SPROCKET_WIDTH, wheels, SPROCKET_TEETH))
	_axles[column] = turns

## Die Räder drehen mit dem Band: der Weg durch ihren Radius.
func _write_axles(column: int) -> void:
	var travel := _fachs[column].position.x + float(_fach_base[column]) * _row_pitch(column)
	for turn: Node3D in _axles[column]:
		if turn != null and is_instance_valid(turn):
			turn.rotation.z = -travel / SPROCKET_RADIUS

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

## Der Stand der Rollschiene: Reihen gesamt und im Fenster, der GEBUCHTE Roll-Stand. Ruht
## das Fach, steht es von da an auf diesem Stand; zählt das Fenster anders, entstehen die
## Lamellen neu.
func set_rail(column: int, total_rows: int, window_rows: int, scroll: int) -> void:
	if column < 0 or column >= _rail_rows.size():
		return
	var window := maxi(window_rows, 1)
	var rebuild := _rail_rows[column].y != window
	_rail_rows[column] = Vector2i(maxi(total_rows, 0), window)
	_rail_scroll[column] = scroll
	if not riding() and is_zero_approx(_fachs[column].position.x):
		_fach_base[column] = scroll
	if rebuild and _built:
		_build_column(column)
	_write_lamellae(column)
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
	_write_cards(clampi(column, 0, _fachs.size() - 1))

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
## das Magazin kennt (hinein ins Fach, hinaus zur Walze). Wer das Fach verläßt, liegt
## flach und ist nie mehr weggesteckt.
static func rehost(node: Node3D, host: Node) -> void:
	if node == null or not is_instance_valid(node) or host == null:
		return
	if node.get_parent() == host:
		return
	if node is DataCellView:
		(node as DataCellView).set_tucked(false)
		(node as DataCellView).set_carry(Transform3D.IDENTITY)
	var at := node.global_position
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	host.add_child(node)
	node.global_position = at

# --- Die MULDEN -----------------------------------------------------------------------

## Die Sortenfarbe eines Trays.
static func column_tint(column: int) -> Color:
	return PackDrawerView.COLORS.get(Pack.SHELF_ORDER[clampi(column, 0, COLUMNS - 1)],
		PackDrawerView.GOLD)

## Die Sortenfarben einer Spalte, je RANG eine (Reihe mal ACROSS plus Querplatz, BAY_EMPTY
## = leer). Jede Lamelle färbt sich danach mit der Reihe, die sie gerade trägt - auch eine,
## die erst hereinschwenkt. Idempotent; gebaut wird dabei nichts.
func set_bay_tints(column: int, tints: Array) -> void:
	if column < 0 or column >= COLUMNS or _tints.is_empty():
		return
	if _tints[column] == tints:
		return
	_tints[column] = tints.duplicate()
	var nodes: Array = _lamellae[column]
	for i in nodes.size():
		_write_lamella_tint(column, i)

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

## Die Quer-Maße einer Lamelle: Mulde, Lippe, Rippe und ihre Platte (Mitte quer relativ zu
## den Plätzen, Breite - nur die Plätze, die Schiene steht fest).
func _segment_shape(column: int, places: int) -> Dictionary:
	var bay := bay_size(places, column)
	var pitch := _span.x / float(maxi(places, 1))
	return {"bay": bay, "rail": (card_slot_width(column) - bay.y) * 0.5, "rib": pitch - bay.x,
		"under": Vector2(0.0, slot_width(column))}

## EINE Lamelle (eine Reihe), pitch lang um ihren Knoten (längs Welt-X): ihre PLATTE, je
## Querplatz Lippen bis Kartenhöhe, Rippen an den genannten Rändern (-1 oben, +1 unten,
## ±0.5 halb und innen) und die Mulde selbst samt dem, was ihr Gerät hineinlegt (Kind
## "Platz<a>"). Die Schiene rechts daneben steht fest.
func _build_segment(node: Node3D, column: int, pitch: float, shape: Dictionary,
		ribs: Array[float], seams: Array, lamps: Array = []) -> void:
	var bay: Vector2 = shape["bay"]
	var rail: float = shape["rail"]
	var rib: float = shape["rib"]
	var under: Vector2 = shape["under"]
	var lip := MagazinTrayDress.inside_material(column)
	_build_plate(node, "Platte", under.y, under.x, pitch, 0.0, 0.0, lip)
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
			_scale, _wall_material, MagazinTrayDress.floor_material(column))
		var light: Material = lamps[across] if across < lamps.size() else null
		if light != null and column == MagazinTrayDress.ZAHL:
			MagazinTrayDress.build_dots(place, FLOOR_RISE, _scale, light)
		MagazinTrayDress.dress_bay(place, column, bay, FLOOR_RISE, PROUD, _scale, light)

## Die EINE Bauregel einer Mulde - auch der Laden legt seine Kassetten so hinein
## (Spieler-Wunsch 2026-10-29), die Walze ohne Wandauskleidung (lined). Der Knoten sitzt
## auf dem Muldenboden; bay ist (Welt-X, Welt-Z).
static func build_bay(node: Node3D, bay: Vector2, seam: StandardMaterial3D,
		cell_scale: float, wall_material: Material, floor_material: Material,
		lined := true) -> void:
	TableProps.box(node, "Saum", Vector3(bay.x, SEAM_RISE, bay.y),
		Vector3(0.0, SEAM_RISE * 0.5, 0.0), seam)
	# Die WÄNDE der Vertiefung tragen ihr EIGENES Material, eine Spur in die Mulde
	# gerückt und unter der Oberkante, damit sie mit Lippe und Rippe nie eine Fläche teilen.
	var high := deck_height_for(cell_scale) - WALL_TOP_GAP
	var lining := WALL_LINING
	for side: float in ([-1.0, 1.0] if lined else []):
		TableProps.box(node, "WandL%s" % ("A" if side < 0.0 else "B"),
			Vector3(lining, high, bay.y), Vector3(side * (bay.x - lining) * 0.5 - side
				* WALL_INSET, high * 0.5, 0.0), wall_material)
		TableProps.box(node, "WandQ%s" % ("A" if side < 0.0 else "B"),
			Vector3(bay.x - WALL_INSET * 2.0, high, lining), Vector3(0.0, high * 0.5,
				side * (bay.y - lining) * 0.5 - side * WALL_INSET), wall_material)
	TableProps.box(node, "Boden",
		Vector3(bay.x - SEAM_WIDTH * 2.0, FLOOR_RISE, bay.y - SEAM_WIDTH * 2.0),
		Vector3(0.0, FLOOR_RISE * 0.5, 0.0), floor_material)

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

## Das Licht je Platz einer Reihe: Dioden, Bandweg, Etikett und die Lampe an der Matte.
func _row_lamps(column: int) -> Array:
	var lamps: Array = []
	for across in ACROSS:
		lamps.append(MagazinTrayDress.lamp_material(column))
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

# --- Bausteine -----------------------------------------------------------------------

func _ensure_materials() -> void:
	if _wall_material != null:
		return
	_wall_material = ShaderMaterial.new()
	_wall_material.shader = load("res://assets/shaders/bay_wall.gdshader")
