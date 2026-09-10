class_name ShelfStackView
extends Node3D
## Das MAGAZIN als REGALSTAPEL (2026-09-10; der PATERNOSTER-Kreislauf ist damit
## gefallen - er verwirrte, weil jede Karte beim Blättern ihren Platz wechselte):
## FÜNF TABLETTS liegen gestapelt in der Magazin-Grube, jedes trägt ZWEI REIHEN auf
## EINER Platte - eine HINTERE (Bild-oben, Welt +X) und eine VORDERE (Bild-unten).
##
## Tablett 1 liegt zuoberst auf Lese-Tiefe, jedes weitere eine Teilung tiefer, und
## KEIN Tablett wechselt je seine Höhe: die Tiefe IST die Position im Stapel.
## Wählt der Spieler Tablett n, fahren alle DARÜBER seitlich nach Bild-rechts in die
## Grubenwand (RETRACTED), die DARUNTER bleiben liegen, wo sie sind - unter seiner
## Platte und damit unsichtbar (BURIED). Sichtbar ist genau EINES.
##
## Der Zustand ist eine reine Funktion (PackDrawerView.state_of), also ist der ganze
## Stapel prüfbar, ohne einen Körper zu fahren. Gewählt wird NUR vom Spieler, an der
## KNOPFLEISTE neben der Grube (ShelfSelectorView) - dieser Körper meldet nichts.
##
## Die Karten LIEGEN flach auf ihrem Tablett (Netz nach oben, wie im Turm) und sind
## KINDER seines Faches: eine Fahrt trägt sie mit.
##
## Die Maße kommen von außen (scene_root rechnet die gemeldete Grube in Welt), die
## HÖHEN gehören dem Stapel. select/settle_hard schreiben den Endzustand zuerst.

const ROWS := PackDrawerView.ROWS
const LANES := PackDrawerView.LANES
const TRAYS := PackDrawerView.TRAYS

const LANE_BACK := PackDrawerView.LANE_BACK
const LANE_FRONT := PackDrawerView.LANE_FRONT

const SHOWN := PackDrawerView.SHOWN
const RETRACTED := PackDrawerView.RETRACTED
const BURIED := PackDrawerView.BURIED

## Ein Tablett ist eine Platte; die Karte liegt eine Spur darüber (koplanar
## stritten sie im Tiefenpuffer - dieselbe Zahl wie im Turm).
const PLATE := 0.06
## Die Karte liegt in ihrer MULDE ÜBER Boden-Einlage, Kontaktzunge UND Lippe (der
## Stellplatz ist genau kartenbreit, die Karte deckt die Lippen quer) - also um
## BAY_FLOOR über der Platte; PROUD mißt vom Muldenboden aus, wie im Turm.
const BAY_FLOOR := 0.05
const PROUD := BAY_FLOOR + TowerView.FLOOR_PROUD
## Luft zwischen zwei gestapelten Tabletts, über der liegenden Karte des unteren.
## GEMESSEN: an der 15°-Station projiziert eine Welthöhe nur mit tan 15° in die
## Fläche, ein knapper Sprung läse sich also gar nicht - und tiefer als die Grube
## (4,6) darf der Stapel trotzdem nie werden.
const AIR := 0.18
## Die TEILUNG des Stapels: eine liegende Karte plus Platte plus Luft.
const PITCH := TowerView.CARD_THICKNESS + PLATE + AIR
## Die Luft, die die oberste Karte unter der Tischkante behält - dieselbe, die der
## GRUBEN-BOGEN einhält (keine Karte ragt je über die Kante).
const RIM_CLEAR := TowerView.CARD_THICKNESS * 0.5
## Und wie weit der GRIFF sie beim Überfahren aus der Grube zieht: bis eine
## Kartendicke über das Glas - nur der Hover darf über die Kante.
const HOVER_PROUD := TowerView.CARD_THICKNESS

## Wie weit ein eingefahrenes Tablett über seine eigene Länge hinaus in der Wand
## steht: ganz außerhalb des Lochs, die opake Anzeige deckt es von oben.
const RETRACT_CLEAR := 0.3

## Der Anteil der LANE-Tiefe, den die FRONT-BLENDE am Bild-unteren Rand nimmt;
## die Karten liegen in dem, was bleibt (PackDrawerView schneidet ihre Plätze an
## derselben Zahl - EINE Quelle).
const FRONT_SHARE := PackDrawerView.FRONT_SHARE
const BAND_RISE := 0.05
const NUMBER_FONT := 48
## Wie weit die (mittig gesetzte) Nummer von der linken Blenden-Kante einrückt, in
## Blenden-Tiefen: bündig gesetzt schnitt die Grubenwand sie an.
const NUMBER_INSET := 2.2
## Die MULDE je Stellplatz (Spieler-Entscheid 2026-09-10, Kontakt-Schacht plus
## Mulde): die PLATTE ist ihr Boden, die LIPPEN stehen darauf, am Boden ein
## LICHTSAUM in der Sortenfarbe (leer kühl und stumpf) und am Bild-rechten Ende
## die goldene KONTAKTZUNGE, auf der die Karte einrastet - wie in der Kontaktleiste
## des Turms. Die Ticks der Blende sind damit gestorben.
const BAY_ROOM := 1.06
const BAY_LIP := 0.045
const LIP_MIN := 0.06
const SEAM_WIDTH := 0.05
const SEAM_RISE := 0.006
const FLOOR_RISE := 0.010
const TONGUE_RISE := 0.008
const TONGUE_SHARE := Vector2(0.42, 0.09)
const TONGUE_INSET := 0.03
const BAY_EMPTY := Color(0.34, 0.38, 0.58)
const SEAM_EMPTY_ENERGY := 0.85
const SEAM_FILLED_ENERGY := 0.9
const FLOOR_ALBEDO := Color(0.055, 0.052, 0.082)
const FLOOR_EMISSION := Color(0.12, 0.13, 0.20)
const FLOOR_ENERGY := 0.45

## Die SCHUBFAHRT eines Tabletts in die Wand und zurück.
const SLIDE_TIME := 0.35

## Die WANDTASCHE hinter dem Schlitz: ein fast schwarzer Kasten, zur Grube hin
## offen - durch den Schlitz sieht man in eine ehrliche Tiefe, nicht in den Raum.
const POCKET_WALL := 0.06
const POCKET_ALBEDO := Color(0.028, 0.026, 0.042)
const POCKET_EMISSION := Color(0.10, 0.11, 0.17)
const POCKET_ENERGY := 0.35

## Die Tabletts sind UNDURCHSICHTIG (Spieler-Entscheid 2026-09-09; das halbdurchsichtige
## Glas und der farbige Reihen-Rand sind gestorben): im Ton des Turm-Gestells, ohne
## Rand - nur die Karten und die Blende unterscheiden eine Reihe.
const PLATE_ALBEDO := TowerView.FRAME_ALBEDO
const PLATE_EMISSION := TowerView.FRAME_EMISSION
const PLATE_ENERGY := TowerView.FRAME_EMISSION_ENERGY

var _span := Vector2.ONE
var _seat := Vector3.ZERO
var _scale := PackDrawerView.CASSETTE_SCALE
var _selected := 0
var _built := false
## Die gemeldete LANE-Geometrie in WELT: je Lane (Mitte relativ zur Grubenmitte in
## Welt-X, Tiefe). Leer = der kopflose Rückfall, die halbe Grube je Lane.
var _lanes: Array[Vector2] = []

var _trays: Array[Node3D] = []
var _fachs: Array[Node3D] = []
## Blenden und Ticks sind REIHENWEISE (je Lane eine Blende), Platten tablettweise.
var _bands: Array[Node3D] = []
var _plates: Array[MeshInstance3D] = []
var _tints: Array = []          # Reihe -> Array[Color], zuletzt geschrieben
var _bays: Array[Node3D] = []    # Reihe -> Mulden-Knoten
var _seams: Array = []          # Reihe -> Array[StandardMaterial3D], je Mulde
var _lip_material: StandardMaterial3D
var _floor_material: StandardMaterial3D
var _tongue_material: StandardMaterial3D
var _plate_material: StandardMaterial3D
var _pocket: Node3D
var _ride: Tween

func _init() -> void:
	name = "ShelfStack"

# --- Die reine STAPEL-Rechnung -----------------------------------------------------
# Gerechnet wird im Fenster (PackDrawerView), hier stehen nur die Namen - EINE Quelle.

static func tray_of(row: int) -> int:
	return PackDrawerView.tray_of(row)

static func lane_of(row: int) -> int:
	return PackDrawerView.lane_of(row)

static func rows_of(tray: int) -> Array[int]:
	return PackDrawerView.rows_of(tray)

static func state_of(row: int, selected: int) -> int:
	return PackDrawerView.state_of(row, selected)

static func shows_row(row: int, selected: int) -> bool:
	return PackDrawerView.shows_row(row, selected)

## Wie weit die Trittfläche des OBERSTEN Tabletts unter dem Glas liegt: so tief,
## daß die flach darauf liegende Karte mit ihrer Oberseite unter der Tischkante
## bleibt.
static func read_drop(cell_scale: float) -> float:
	return DataCellView.lying_over(cell_scale) + PROUD + RIM_CLEAR

## Und die Tiefe von Tablett `tray` - eine Teilung je Stufe. Sie ändert sich NIE.
static func drop_of(tray: int, cell_scale: float) -> float:
	return read_drop(cell_scale) + PITCH * float(clampi(tray, 0, TRAYS - 1))

## Dieselbe Tiefe für eine Reihe.
static func drop_for(row: int, cell_scale: float) -> float:
	return drop_of(tray_of(row), cell_scale)

## Der GRIFF im Magazin, als Anteil der Standhöhe (DataCellView.hover_lift): er
## zieht die liegende Karte JEDES Tabletts bis über das Glas - die Tiefe ist
## Stapel-Position, kein Lese-Hindernis.
static func hover_lift(cell_scale: float, tray := 0) -> float:
	var reach := drop_of(tray, cell_scale) + HOVER_PROUD
	return reach / maxf(DataCellView.STAND_HEIGHT * cell_scale, 0.001)

## Wie tief der Stapel insgesamt reicht - daran mißt, ob die Grube ihn trägt.
static func stack_depth(cell_scale: float) -> float:
	return drop_of(TRAYS - 1, cell_scale) + PLATE

## Die Dauer einer Wahl - der ehrliche Deckel, den scene_root abwartet.
static func step_time() -> float:
	return SLIDE_TIME

## Der Prioritäts-Versatz einer STAPEL-EBENE: je tiefer, desto früher gezeichnet.
static func layer_bias(level: int) -> int:
	return -DataCellView.LAYER_SPAN * maxi(level, 0)

# --- Aufbau ------------------------------------------------------------------------

## Stellt den Stapel (idempotent - dieselben Maße bauen nichts neu). at = der
## GLASPUNKT der Grubenmitte, span = ihr Weltmaß (x quer/Bild-hoch, y längs/Bild-
## breit), cell_scale der Anzeige-Maßstab der Karten, lanes die gemeldete
## Lane-Geometrie.
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
	_ensure_trays()
	for tray in TRAYS:
		_build_tray(tray)
	_build_pocket()
	_built = true
	settle_hard()

## Die Tabletts entstehen EINMAL - ihre Fächer tragen die Karten, ein Neuaufbau der
## Maße darf sie nicht mit wegräumen.
func _ensure_trays() -> void:
	if not _trays.is_empty():
		return
	for tray in TRAYS:
		var node := Node3D.new()
		node.name = "Tablett%d" % (tray + 1)
		add_child(node)
		_trays.append(node)
		var fach := Node3D.new()
		fach.name = "Fach"
		node.add_child(fach)
		_fachs.append(fach)
		_plates.append(null)
	for row in ROWS:
		_bands.append(null)
		_bays.append(null)
		_tints.append([] as Array[Color])
		_seams.append([])

## Platte, die zwei FRONT-BLENDEN und die MULDEN eines Tabletts. Das Fach bleibt
## stehen - es trägt die Karten.
func _build_tray(tray: int) -> void:
	_ensure_materials()
	var node := _trays[tray]
	for child in node.get_children():
		if child == _fachs[tray]:
			continue
		node.remove_child(child)
		child.queue_free()
	# EINE Platte deckt BEIDE Lanes samt dem Spalt dazwischen: von der Oberkante der
	# hinteren bis zur Unterkante der vorderen.
	var top := lane_x(LANE_BACK) + lane_depth() * 0.5
	var bottom := lane_x(LANE_FRONT) - lane_depth() * 0.5
	var plate := _box("Platte", Vector3(maxf(top - bottom, 0.05), PLATE, _span.y),
		Vector3((top + bottom) * 0.5, -PLATE * 0.5, 0.0), _plate_material, node)
	_plates[tray] = plate
	for row in rows_of(tray):
		_build_band(node, row)
		_build_bays(node, row)

## Die FRONT-BLENDE einer Reihe: an der Bild-UNTEREN Kante IHRER Lane, wie die
## Front einer Schublade. Die NUMMER (die des TABLETTS) steht nur an der vorderen.
func _build_band(host: Node3D, row: int) -> void:
	var lane := lane_of(row)
	var band := Node3D.new()
	band.name = "Blende%d" % (row + 1)
	band.position = Vector3(lane_x(lane) - lane_depth() * 0.5 + band_depth() * 0.5,
		0.0, 0.0)
	host.add_child(band)
	_bands[row] = band
	if lane == LANE_FRONT:
		var label := Label3D.new()
		label.name = "Nummer"
		label.text = number_text(row)
		label.font_size = NUMBER_FONT
		# Flach in Tisch-Leserichtung wie jede Aufschrift auf dem Filz.
		label.transform.basis = Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)
		label.pixel_size = band_depth() * 0.7 / (float(NUMBER_FONT) * 0.62)
		label.position = Vector3(0.0, BAND_RISE + 0.01,
			-_span.y * 0.5 + band_depth() * NUMBER_INSET)
		label.outline_size = 12
		label.outline_modulate = Color(0.03, 0.03, 0.05)
		band.add_child(label)

## Die WANDTASCHE hinter dem Schlitz der Bild-rechten Grubenwand: ein geschlossener
## Kasten von der Wand nach +Z, so lang wie der Fahrweg und so hoch wie der Stapel,
## zur Grube hin offen. Er liegt außerhalb des Lochs, also sieht man ihn NUR durch
## den Schlitz.
func _build_pocket() -> void:
	if _pocket != null and is_instance_valid(_pocket):
		remove_child(_pocket)
		_pocket.queue_free()
	var host := Node3D.new()
	host.name = "Wandtasche"
	add_child(host)
	_pocket = host
	var material := _metal(POCKET_ALBEDO, POCKET_EMISSION, POCKET_ENERGY)
	var near := _span.y * 0.5
	var deep := retract_span() + RETRACT_CLEAR
	# Die DECKE hängt UNTER der Tischfläche (auf der Höhe der Wandoberkante) und reicht
	# bis unter den Sturz des Schlitzes: über ihr deckt die opake Anzeige, unter ihr
	# sieht man durch den Schlitz nicht an ihr vorbei. Auf der Glasebene selbst läge
	# sie AUF dem Filz - als schwarzer Balken neben der Grube (Sichtprobe 2026-09-10).
	var top := -PackPitView.WALL_SINK
	var bottom := -stack_depth(_scale) - POCKET_WALL
	var high := top - bottom
	# Und sie ist so breit wie die GANZE Grube - der Schlitz läuft über deren volle
	# Länge, an einer schmaleren Tasche sähe man an den Enden vorbei.
	var wide := _span.x + POCKET_WALL * 2.0
	var mid_x := 0.0
	var mid_z := near + deep * 0.5
	_box("Decke", Vector3(wide, POCKET_WALL, deep),
		Vector3(mid_x, top - POCKET_WALL * 0.5, mid_z), material, host)
	_box("Boden", Vector3(wide, POCKET_WALL, deep),
		Vector3(mid_x, bottom - POCKET_WALL * 0.5, mid_z), material, host)
	_box("Rueckwand", Vector3(wide, high, POCKET_WALL),
		Vector3(mid_x, (top + bottom) * 0.5, near + deep + POCKET_WALL * 0.5),
		material, host)
	for side in 2:
		var dir := float(side) * 2.0 - 1.0
		_box("Flanke%d" % side, Vector3(POCKET_WALL, high, deep),
			Vector3(mid_x + dir * (wide * 0.5 - POCKET_WALL * 0.5),
				(top + bottom) * 0.5, mid_z), material, host)

## Die Tiefe EINER Lane in Welt: sie wird GEMELDET (das Fenster schneidet die drei
## Ränder heraus); ohne Meldung bleibt die halbe Grube der kopflose Rückfall.
func lane_depth() -> float:
	if _lanes.is_empty():
		return _span.x * 0.5
	return maxf(_lanes[0].y, 0.01)

## Die Tiefe der Blende in Welt.
func band_depth() -> float:
	return lane_depth() * FRONT_SHARE

## Die Mitte einer Lane, quer zur Grube (Welt-X, relativ zur Grubenmitte) - gemeldet
## wie ihre Tiefe.
func lane_x(lane: int) -> float:
	if _lanes.is_empty():
		return lane_depth() * 0.5 * (1.0 if lane == LANE_BACK else -1.0)
	return _lanes[clampi(lane, 0, _lanes.size() - 1)].x

## Die QUER-Ausdehnung einer Tablett-Platte und ihre Mitte (beide Lanes samt Spalt).
func plate_span() -> float:
	return maxf(lane_x(LANE_BACK) - lane_x(LANE_FRONT) + lane_depth(), 0.05)

func plate_center() -> float:
	return (lane_x(LANE_BACK) + lane_x(LANE_FRONT)) * 0.5

## Wie weit ein eingefahrenes Tablett nach Bild-rechts fährt: seine ganze Länge
## plus Luft, damit es außerhalb des Lochs steht.
func retract_span() -> float:
	return _span.y + RETRACT_CLEAR

# --- Der Zustand -------------------------------------------------------------------

## Das gewählte Tablett.
func selected() -> int:
	return _selected

func tray_count() -> int:
	return TRAYS

func row_count() -> int:
	return ROWS

## Die zwei sichtbaren Reihen, hinten zuerst.
func rows_shown() -> Array[int]:
	return rows_of(_selected)

## Liegt diese Reihe in der Fläche?
func shows(row: int) -> bool:
	return shows_row(row, _selected)

## Fährt gerade ein Tablett?
func riding() -> bool:
	return _ride != null and _ride.is_valid()

## Der EINE harte Schreiber: jedes Tablett auf seinem Sitz. Jeder Abbruch und jeder
## Laufwechsel geht hier durch.
func settle_hard() -> void:
	_kill()
	_write_hard()

## Der Stapel springt HART auf dieses Tablett (Laufwechsel, Neuaufbau) - keine Fahrt.
func set_selected(tray: int) -> void:
	_selected = clampi(tray, 0, TRAYS - 1)
	settle_hard()

## Die WAHL: die Tabletts über dem gewählten fahren in die Wand, die anderen zurück.
## Endzustand zuerst - eine Wahl mitten in der Fahrt beendet sie hart und fährt neu,
## sie schuldet nichts.
func select(tray: int) -> void:
	var wanted := clampi(tray, 0, TRAYS - 1)
	if _trays.is_empty() or wanted == _selected:
		return
	_selected = wanted
	_kill()
	_write_bands()
	for i in _trays.size():
		_bias_cards(i)
	if not is_inside_tree():
		_write_hard()
		return
	# Nur die Z-Komponente ändert sich je Tablett - die Höhe ist Stapel-Position.
	_ride = create_tween()
	_ride.set_parallel(true)
	var moving := false
	for i in _trays.size():
		var to := tray_pose(i, _selected)
		if _trays[i].position.is_equal_approx(to):
			continue
		moving = true
		_ride.tween_property(_trays[i], "position", to, SLIDE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not moving:
		_kill()
		_write_hard()
		return
	_ride.chain().tween_callback(settle_hard)

## Wo ein Tablett liegt: seine Höhe ist seine Stapel-Position und ändert sich NIE;
## eingefahren steht es um seine ganze Länge nach Bild-rechts (Welt +Z) versetzt.
func tray_pose(tray: int, chosen: int) -> Vector3:
	var out := retract_span() if tray_state(tray, chosen) == RETRACTED else 0.0
	return Vector3(0.0, -drop_of(tray, _scale), out)

## Der Zustand eines TABLETTS - dieselbe Regel wie die seiner Reihen.
static func tray_state(tray: int, chosen: int) -> int:
	return state_of(clampi(tray, 0, TRAYS - 1) * LANES, chosen)

## Alle fünf Tabletts werden gerendert - was eingefahren ist, steckt in der Wand,
## was tiefer liegt, unter der Platte darüber.
func _write_hard() -> void:
	for tray in _trays.size():
		_trays[tray].position = tray_pose(tray, _selected)
		_bias_cards(tray)
	_write_bands()

## Nummer und Mulden nur auf dem GEWÄHLTEN Tablett: Alpha-Flächen stanzten sonst
## durch die Platte darüber, und verdeckt liest sie ohnehin keiner.
func _write_bands() -> void:
	for row in _bands.size():
		var on := shows_row(row, _selected)
		if _bands[row] != null and is_instance_valid(_bands[row]):
			_bands[row].visible = on
		if row < _bays.size() and _bays[row] != null and is_instance_valid(_bays[row]):
			_bays[row].visible = on

## Die Karten eines Tabletts zeichnen in der Priorität IHRER Stapel-Ebene - sonst
## zeichnete das Netz einer tiefen Karte (höchste Priorität) über die darüber.
func _bias_cards(tray: int) -> void:
	if tray >= _fachs.size() or _fachs[tray] == null or not is_instance_valid(_fachs[tray]):
		return
	var level := maxi(tray - _selected, 0)
	for child in _fachs[tray].get_children():
		if child is DataCellView:
			(child as DataCellView).set_layer_depth(level)

func _kill() -> void:
	if _ride != null and _ride.is_valid():
		_ride.kill()
	_ride = null

# --- Die Plätze --------------------------------------------------------------------

## Welt-y der Trittfläche einer Reihe (sie ist zugleich die ihres Tabletts).
func tray_top(row: int) -> float:
	return _seat.y - drop_for(row, _scale)

## ... und die Höhe, auf der die Karte dieser Reihe LIEGT.
func card_seat(row: int) -> float:
	return tray_top(row) + PROUD

## Der höchste Punkt einer Karte dieser Reihe - daran mißt die Invariante.
func card_top(row: int) -> float:
	return card_seat(row) + DataCellView.lying_over(_scale)

## Der SCHUB ihres Tabletts (Welt-Z): 0, solange es in der Grube liegt, sonst der
## Weg in die Wand. Das Fenster meldet den Heimatplatz einer Karte; wo sie WIRKLICH
## liegt, sagt erst er - sonst risse der Sitz-Schreiber jede eingefahrene Karte
## zurück in die Grube.
func retract_offset(row: int) -> float:
	return tray_pose(tray_of(row), _selected).z

## Das FACH einer Reihe - der Wirt ihrer Karten (null = noch nicht gebaut). Beide
## Reihen eines Tabletts teilen es: sie fahren ohnehin gemeinsam.
func fach(row: int) -> Node3D:
	if _fachs.is_empty():
		return null
	return _fachs[tray_of(row)]

## Die Karte wird KIND des Faches ihres Tabletts - eine Fahrt trägt sie mit. Ihren
## Platz nennt der Sitz-Schreiber, die HÖHE gehört dem Tablett: lokal liegt sie
## IMMER PROUD über der Trittfläche, auch mitten in einer Fahrt.
func host_card(cell: Node3D, row: int) -> void:
	if _fachs.is_empty():
		return
	var tray := tray_of(row)
	var fach_node := _fachs[tray]
	if cell.get_parent() != fach_node:
		rehost(cell, fach_node)
	cell.position.y = PROUD
	if cell is DataCellView:
		(cell as DataCellView).set_layer_depth(maxi(tray - _selected, 0))

## Liegt diese Karte schon auf ihrem Platz? Verglichen wird in der TISCHEBENE und
## am Fach - die Höhe gehört dem Tablett, und die fährt.
func seated(cell: Node3D, row: int, at: Vector3) -> bool:
	if _fachs.is_empty() or cell.get_parent() != _fachs[tray_of(row)]:
		return false
	if not is_equal_approx(cell.position.y, PROUD):
		return false
	return Vector2(cell.global_position.x, cell.global_position.z) \
		.distance_to(Vector2(at.x, at.z)) < 0.01

## Ein Körper wechselt den Wirt und behält seinen Weltplatz - der eine Umzug, den
## das Magazin kennt (hinein ins Fach, hinaus zum Turm).
static func rehost(node: Node3D, host: Node) -> void:
	if node == null or not is_instance_valid(node) or host == null:
		return
	if node.get_parent() == host:
		return
	var at := node.global_position
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	host.add_child(node)
	node.global_position = at

# --- Die FRONT-BLENDE ----------------------------------------------------------------

## Die Aufschrift der vorderen Blende: die TABLETT-Nummer, dieselbe Zahl wie auf der
## Taste der Knopfleiste.
func number_text(row: int) -> String:
	return "%d" % (tray_of(row) + 1)

## Je Platz ein TICK in der Sortenfarbe (leer = stumpf). Idempotent: dieselbe Liste
## schreibt nichts neu.
## Die Sortenfarben einer Reihe, je Stellplatz eine (BAY_EMPTY = leer). Sie färben
## den Lichtsaum der Mulden; ändert sich die Platzzahl, werden die Mulden neu gebaut,
## sonst nur umgefärbt. Idempotent.
func set_bay_tints(row: int, tints: Array) -> void:
	if row < 0 or row >= ROWS or _tints.is_empty():
		return
	if _tints[row] == tints:
		return
	var rebuild := (_tints[row] as Array).size() != tints.size()
	_tints[row] = tints.duplicate()
	if rebuild and row < _trays.size() * LANES:
		_build_bays(_trays[tray_of(row)], row)
	else:
		_write_bays(row)

func bay_count(row: int) -> int:
	if row < 0 or row >= _tints.size():
		return 0
	return (_tints[row] as Array).size()

func bay_tint(row: int, index: int) -> Color:
	if row < 0 or row >= _tints.size():
		return BAY_EMPTY
	var line: Array = _tints[row]
	if index < 0 or index >= line.size():
		return BAY_EMPTY
	return line[index]

## Das Maß EINER Mulde bei so vielen Plätzen: die liegende Karte plus Luft, gedeckelt
## von Teilung und Lane, so daß zwischen zwei Mulden immer eine Lippe steht.
func bay_size(columns: int) -> Vector2:
	var slot_depth := lane_depth() * (1.0 - FRONT_SHARE)
	var pitch := _span.y / float(maxi(columns, 1))
	return Vector2(
		minf(DataCellView.WIDTH * _scale * BAY_ROOM, slot_depth - LIP_MIN * 2.0),
		minf(DataCellView.HEIGHT * _scale * BAY_ROOM, pitch - LIP_MIN))

## Die MULDEN einer Reihe: Lippen auf der Platte, je Platz Saum, Boden und Zunge.
func _build_bays(host: Node3D, row: int) -> void:
	var old: Node3D = _bays[row] if row < _bays.size() else null
	if old != null and is_instance_valid(old):
		# Ein Neubau des Tabletts hat den Knoten schon ausgehängt - dann nur freigeben.
		if old.get_parent() != null:
			old.get_parent().remove_child(old)
		old.queue_free()
	_bays[row] = null
	_seams[row] = []
	var tints: Array = _tints[row]
	if tints.is_empty():
		return
	_ensure_materials()
	var lane := lane_of(row)
	var slot_depth := lane_depth() * (1.0 - FRONT_SHARE)
	var bays := Node3D.new()
	bays.name = "Mulden%d" % (row + 1)
	# Die Karten liegen mittig in dem Teil der Lane, den die Blende übrig läßt.
	bays.position = Vector3(lane_x(lane) + lane_depth() * 0.5 - slot_depth * 0.5, 0.0, 0.0)
	bays.visible = shows_row(row, _selected)
	host.add_child(bays)
	_bays[row] = bays
	var columns := tints.size()
	var pitch := _span.y / float(columns)
	var bay := bay_size(columns)
	var rail := (slot_depth - bay.x) * 0.5
	var rib := pitch - bay.y
	for side in 2:
		var dir := float(side) * 2.0 - 1.0
		_box("Lippe%d" % side, Vector3(rail, BAY_LIP, _span.y),
			Vector3(dir * (bay.x + rail) * 0.5, BAY_LIP * 0.5, 0.0), _lip_material, bays)
	for i in columns + 1:
		var z := -_span.y * 0.5 + pitch * float(i)
		var width := rib
		# Die Randrippen stehen halb so breit INNEN an der Plattenkante.
		if i == 0:
			width = rib * 0.5
			z += width * 0.5
		elif i == columns:
			width = rib * 0.5
			z -= width * 0.5
		_box("Rippe%d" % i, Vector3(bay.x, BAY_LIP, width),
			Vector3(0.0, BAY_LIP * 0.5, z), _lip_material, bays)
	var seams: Array = []
	for i in columns:
		var node := Node3D.new()
		node.name = "Mulde%d" % i
		node.position = Vector3(0.0, 0.0, -_span.y * 0.5 + pitch * (float(i) + 0.5))
		bays.add_child(node)
		var seam := StandardMaterial3D.new()
		seam.metallic = 0.2
		seam.roughness = 0.5
		seam.emission_enabled = true
		_box("Saum", Vector3(bay.x, SEAM_RISE, bay.y),
			Vector3(0.0, SEAM_RISE * 0.5, 0.0), seam, node)
		_box("Boden", Vector3(bay.x - SEAM_WIDTH * 2.0, FLOOR_RISE, bay.y - SEAM_WIDTH * 2.0),
			Vector3(0.0, FLOOR_RISE * 0.5, 0.0), _floor_material, node)
		var tongue := Vector3(bay.x * TONGUE_SHARE.x, TONGUE_RISE, bay.y * TONGUE_SHARE.y)
		_box("Zunge", tongue,
			Vector3(0.0, FLOOR_RISE + TONGUE_RISE * 0.5,
				bay.y * 0.5 - SEAM_WIDTH - TONGUE_INSET - tongue.z * 0.5),
			_tongue_material, node)
		seams.append(seam)
	_seams[row] = seams
	_write_bays(row)

## Der EINE Schreiber der Saum-Farben: Sortenfarbe hell, leer kühl und stumpf.
func _write_bays(row: int) -> void:
	if row < 0 or row >= _seams.size():
		return
	var seams: Array = _seams[row]
	var tints: Array = _tints[row]
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
	# Die Lippe ist Platte; der Muldenboden liegt dunkler, die Zunge trägt das Gold
	# der Turm-Kontaktleiste (EINE Quelle).
	_lip_material = _plate_material
	_floor_material = _metal(FLOOR_ALBEDO, FLOOR_EMISSION, FLOOR_ENERGY)
	_tongue_material = _metal(TowerView.BAR_ALBEDO, TowerView.BAR_EMISSION,
		TowerView.BAR_EMISSION_ENERGY)

func _metal(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = 0.35
	material.roughness = 0.55
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _box(box_name: String, box_size: Vector3, at: Vector3, material: Material,
		host: Node3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(instance)
	return instance
