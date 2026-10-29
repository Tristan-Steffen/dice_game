class_name ShelfStackView
extends Node3D
## Das MAGAZIN als REGALSTAPEL (2026-09-10): seit der Welle 29 VIER TABLETTS, eines
## je SORTE, gestapelt in der Magazin-Grube; jedes trägt ZWEI LANES auf EINER Platte -
## eine HINTERE (Bild-oben, Welt +X) und eine VORDERE (Bild-unten) - und ROLLT: ein
## Zug schiebt sein FACH waagerecht, die vorderen Spalten verschwinden durch den
## Schlitz der linken Wand in ihre Wandtasche.
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
## Die Karte liegt in ihrer MULDE auf der Boden-Einlage - um BAY_FLOOR über der
## Platte; PROUD mißt vom Muldenboden aus, wie im Turm. Seit dem 2026-10-28 ist die
## Mulde eine VERTIEFUNG: Lippen, Rippen und Deck reichen bis Kartenoberkante
## (deck_height), die liegende Karte ist bündig mit dem Tablett.
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
const NUMBER_FONT := 48
## Wie weit das (linksbündige) Kürzel von der linken Blenden-Kante einrückt, in
## Blenden-Tiefen: bündig gesetzt schnitt die Grubenwand es an.
const NUMBER_INSET := 1.0
## Die MULDE je Stellplatz (Spieler-Entscheid 2026-09-10, Kontakt-Schacht plus
## Mulde): die PLATTE ist ihr Boden, Lippen und Rippen ihr Rand bis Kartenhöhe, am
## Boden ein LICHTSAUM in der Sortenfarbe (leer kühl und stumpf) und am Bild-rechten
## Ende die BUCHSE, in der die Karte steckt.
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

## Die SCHUBFAHRT eines Tabletts in die Wand und zurück.
const SLIDE_TIME := 0.35
## Das EINRASTEN nach einem Zug auf die nächste ganze Spalte.
const SNAP_TIME := 0.16
## Die linke Wandtasche faßt die hinausgerollte Spalte samt Luft (in Kartenlängen).
const LEFT_POCKET_SHARE := 1.2
## Das GLIMMEN an der Wand, hinter der noch Karten liegen: ein schmaler Lichtbalken
## auf Kartenhöhe des gewählten Tabletts.
const HINT_WIDTH := 0.05
const HINT_HEIGHT := 0.05
const HINT_COLOR := Color(1.0, 0.83, 0.1)
const HINT_ENERGY := 1.2

## Die WANDTASCHE hinter dem Schlitz ist der Raum NEBEN der Grube, nicht ihr Ende
## (Spieler-Entscheid 2026-10-26; der fast schwarze Kasten davor las sich als Loch
## ins Nichts): sie trägt dieselbe Archiv-Auskleidung wie die Grube selbst
## (PackPitView.tune_lining) - Samtboden, Paneelwände mit der bestellten Haut -,
## und ihre Flanken setzen die Grubenwände in Weltmaß fort, also läuft deren
## Linienmuster ohne Versatz hinein.
const POCKET_WALL := 0.06
## Ihre FLANKEN tragen die Werte der Grubenwand unverändert - ein Helligkeitssprung
## an der Naht verriete, dass dort zwei Körper stoßen.
## Ihr BODEN dagegen ist HELLER als der der Grube: in die Grube sieht man von oben,
## in die Tasche nur durch einen flachen Schlitz, und mit dem Samt-Ton der Grube
## bliebe sie das schwarze Loch, das sie war (gemessen 2026-10-26: 0,046 las sich
## auch mit voller Auskleidung noch als Nichts).
const POCKET_FLOOR_ALBEDO := Color(0.125, 0.115, 0.18)
const POCKET_FLOOR_ENERGY := 2.4

## Der BODEN einer MULDE bekommt DIESELBE Auskleidung (flach schwarz las ein leerer
## Stellplatz als Loch statt als Fach), aber DUNKLER als die Tasche: in ein Kartenfach
## sieht die Station fast senkrecht hinein, in die Tasche nur durch einen flachen
## Schlitz. GEMESSEN 2026-10-26 an der Werkstatt-Weitsicht.
const BAY_FLOOR_ALBEDO := Color(0.095, 0.088, 0.14)
const BAY_FLOOR_ENERGY := 1.8

## Die Tabletts sind UNDURCHSICHTIG (Spieler-Entscheid 2026-09-09; das halbdurchsichtige
## Glas und der farbige Reihen-Rand sind gestorben): im Ton des Turm-Gestells, ohne
## Rand - nur die Karten und die Blende unterscheiden eine Reihe.
const PLATE_ALBEDO := TowerView.FRAME_ALBEDO
const PLATE_EMISSION := TowerView.FRAME_EMISSION
const PLATE_ENERGY := TowerView.FRAME_EMISSION_ENERGY

## Die WANDHAUT der Wandtaschen: von draußen GEMELDET wie die der Grube selbst
## (PackPitView.wall_skin) - dieselbe Textur, damit der Raum neben der Grube nicht
## anders liest als sie.
var wall_skin: Texture2D = null:
	set(value):
		wall_skin = value
		if _built:
			_build_pocket()

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
var _rolled := {}               # Reihe -> schon nach rechts gerollt (Vorrat links)
var _wall_material: ShaderMaterial
var _spare_right := {}           # Reihe -> Vorrats-Block rechts
var _spare_left := {}            # Reihe -> Vorrats-Block links (nur gerollt)
var _pitch := {}                 # Reihe -> Muldenteilung
var _bays: Array[Node3D] = []    # Reihe -> Mulden-Knoten
var _seams: Array = []          # Reihe -> Array[StandardMaterial3D], je Mulde
var _lip_material: StandardMaterial3D
var _floor_material: ShaderMaterial
var _plate_material: StandardMaterial3D
var _pocket: Node3D
var _ride: Tween
## Der ROLL-Zug: läuft gerade einer (vom Zeiger geführt), und das Einrasten danach.
var _scrolling := false
var _snap: Tween
## Die beiden Glimm-Balken (links, rechts) und ob sie stehen sollen.
var _hints: Array[MeshInstance3D] = []
var _overflow := Vector2i.ZERO

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
	_tune_bay_floor()  # das Samt-Feld hängt an der Grube, nicht am Tablett
	_ensure_trays()
	for tray in TRAYS:
		_build_tray(tray)
	_build_pocket()
	_build_hints()
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
	var plate := TableProps.box(node, "Platte", Vector3(maxf(top - bottom, 0.05), PLATE, _span.y),
		Vector3((top + bottom) * 0.5, -PLATE * 0.5, 0.0), _plate_material)
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
	band.position = Vector3(lane_x(lane) + band_side(lane)
		* (lane_depth() * 0.5 - band_depth() * 0.5), 0.0, 0.0)
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
		# Linksbündig: das Kürzel ist unterschiedlich lang, sein Anfang steht fest.
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.position = Vector3(0.0, deck_height() + 0.01,
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
	host.name = "Wandtaschen"
	add_child(host)
	_pocket = host
	# Rechts fahren die Tabletts ein, links rollen die vorderen Spalten hinaus.
	_build_pocket_side(host, 1.0, retract_span() + RETRACT_CLEAR)
	_build_pocket_side(host, -1.0, left_pocket_depth())

## Wie tief die LINKE Wandtasche reicht: die hinausgerollte Spalte samt Luft - was
## weiter rollt, liegt unter dem Filz und hinter ihrer Rückwand.
func left_pocket_depth() -> float:
	return DataCellView.HEIGHT * _scale * LEFT_POCKET_SHARE + RETRACT_CLEAR

## EINE Wandtasche, außen an der Wand der Seite side (+1 = Bild-rechts, Welt +Z).
func _build_pocket_side(parent: Node3D, side: float, deep: float) -> void:
	var host := Node3D.new()
	host.name = "Wandtasche" if side > 0.0 else "WandtascheLinks"
	host.scale = Vector3(1.0, 1.0, side)
	parent.add_child(host)
	var near := _span.y * 0.5
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
	# Die Auskleidung misst sich an DIESER Tasche in WELT: ihre Flanken liegen auf
	# den Innenflächen der Grubenwände, also setzt die Haut deren Linien fort.
	var reach := near + deep
	var rect := Rect2(Vector2(_seat.x - wide * 0.5,
		_seat.z + (near if side > 0.0 else -reach)), Vector2(wide, deep))
	var skin := _lining(0.0, rect, high)
	var velvet := _lining(1.0, rect, high)
	TableProps.box(host, "Decke", Vector3(wide, POCKET_WALL, deep),
		Vector3(mid_x, top - POCKET_WALL * 0.5, mid_z), skin)
	TableProps.box(host, "Boden", Vector3(wide, POCKET_WALL, deep),
		Vector3(mid_x, bottom - POCKET_WALL * 0.5, mid_z), velvet)
	TableProps.box(host, "Rueckwand", Vector3(wide, high, POCKET_WALL),
		Vector3(mid_x, (top + bottom) * 0.5, near + deep + POCKET_WALL * 0.5),
		skin)
	for flank in 2:
		var dir := float(flank) * 2.0 - 1.0
		TableProps.box(host, "Flanke%d" % flank, Vector3(POCKET_WALL, high, deep),
			Vector3(mid_x + dir * (wide * 0.5 - POCKET_WALL * 0.5),
				(top + bottom) * 0.5, mid_z), skin)

## Die Grube in WELT-XZ - das Feld, an dem sich jede Auskleidung des Stapels mißt.
func _pit_field() -> Rect2:
	return Rect2(Vector2(_seat.x, _seat.z) - _span * 0.5, _span)

## Der BODEN einer MULDE trägt dieselbe ARCHIV-Auskleidung wie die Grube selbst
## (Spieler-Wunsch 2026-10-26): flach schwarz las ein leerer Stellplatz als LOCH,
## nicht als Fach - derselbe Befund wie an den Wandtaschen, also dieselben Werte.
## Sein Samt-Feld ist die GANZE Grube, nicht die einzelne Mulde: das Licht gehört
## der Grube, also wandert kein Muster mit, wenn ein Tablett fährt.
func _tune_bay_floor() -> void:
	if _floor_material == null:
		return
	PackPitView.tune_lining(_floor_material, 1.0, BAY_FLOOR_ALBEDO,
		BAY_FLOOR_ENERGY, _pit_field(), _seat.y, stack_depth(_scale),
		PackPitView.GLOW_COLOR, null)
	# Der Flor fährt mit der Mulde, wenn das Tablett rollt (Spieler-Wunsch 2026-10-28).
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

## Die Tiefe EINER Lane in Welt: sie wird GEMELDET (das Fenster schneidet die drei
## Ränder heraus); ohne Meldung bleibt die halbe Grube der kopflose Rückfall.
func lane_depth() -> float:
	if _lanes.is_empty():
		return _span.x * 0.5
	return maxf(_lanes[0].y, 0.01)

## Die Tiefe der Blende in Welt.
func band_depth() -> float:
	return lane_depth() * FRONT_SHARE

## Auf welcher Seite ihrer Lane die Blende liegt (Welt-X): die hintere OBEN (+X), die
## vordere UNTEN (-X) - gespiegelt, damit das Tablett oben wie unten gleich breit
## gerandet ist (PackDrawerView.band_before, Spieler-Wunsch 2026-10-28).
static func band_side(lane: int) -> float:
	return 1.0 if lane == LANE_BACK else -1.0

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

## Wie viele GRUBEN-BREITEN das Einfahren zurücklegt. Ein Tablett mit mehr Karten,
## als ins Fenster passen, ist LÄNGER als die Grube - mit nur EINER Breite lägen
## seine ersten Spalten wieder über dem Loch (gemessen 2026-10-26: vier Karten des
## verdeckten Tabletts standen über dem gewählten). Was weiter fährt, liegt unter
## dem Filz, genau wie eine hinausgerollte Karte. Gemeldet vom Fenster, das die
## Kartenzahl kennt; die WANDTASCHE bleibt bei ihrer einen Breite - sie ist die
## sichtbare Nähe, nicht der ganze Weg.
var _retract_windows := 1

func set_retract_windows(windows: int) -> void:
	var wanted := maxi(windows, 1)
	if _retract_windows == wanted:
		return
	_retract_windows = wanted
	_write_hard()

func retract_reach() -> float:
	return retract_span() * float(_retract_windows)

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

## Fährt gerade ein Tablett - in die Wand, unter dem Zeiger oder ins Einrasten?
func riding() -> bool:
	return (_ride != null and _ride.is_valid()) or _scrolling \
		or (_snap != null and _snap.is_valid())

# --- Das ROLLEN --------------------------------------------------------------------

## Der Zeiger führt das Fach des Tabletts: um z (Welt, + = Bild-rechts) gegen seinen
## Roll-Stand versetzt. Die Karten hängen am Fach und reisen mit.
func drag_scroll(tray: int, z: float) -> void:
	if tray < 0 or tray >= _fachs.size():
		return
	_kill_snap()
	_scrolling = true
	_roll_to(tray, z)

## Fach UND Mulden fahren gemeinsam (Spieler-Wunsch 2026-10-28): ausgeblendet ließen
## die Mulden eine graue Platte stehen, und die leeren Vorrats-Mulden rücken nach.
func _roll_to(tray: int, z: float) -> void:
	_fachs[tray].position.z = z
	for row in rows_of(tray):
		if row < _bays.size() and _bays[row] != null and is_instance_valid(_bays[row]):
			_bays[row].position.z = z
			_place_spares(row, z)

## Die Dauer des Einrastens: eine Spalte in SNAP_TIME, ein weiter Rückweg länger -
## mit der Wurzel der Strecke, gedeckelt (sonst spränge ein langer Zug zurück).
func snap_time_for(distance: float) -> float:
	var columns := distance / maxf(_span.y / float(PackDrawerView.COLUMNS), 0.001)
	return minf(SNAP_TIME * sqrt(maxf(columns, 1.0)), SNAP_TIME_MAX)

## Der Versatz des Fachs (0 = es liegt auf seinem Roll-Stand).
func scroll_offset(tray: int) -> float:
	if tray < 0 or tray >= _fachs.size():
		return 0.0
	return _fachs[tray].position.z

## Losgelassen: das Fach fährt von from auf to und RASTET dort ein - danach wird
## der Versatz in die Karten übernommen (der Roll-Stand ist längst gebucht, ihre
## Plätze stehen schon dort). on_done läuft danach, auch bei Zeit 0.
func snap_scroll(tray: int, from: float, to: float, on_done: Callable) -> void:
	if tray < 0 or tray >= _fachs.size():
		return
	_kill_snap()
	_scrolling = false
	_roll_to(tray, from)
	if not is_inside_tree() or is_equal_approx(from, to):
		_roll_to(tray, to)
		bake_scroll(tray)
		on_done.call()
		return
	_snap = create_tween()
	_snap.tween_method(func(z: float) -> void: _roll_to(tray, z), from, to,
		snap_time_for(absf(to - from))) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_snap.tween_callback(func() -> void:
		bake_scroll(tray)
		on_done.call())

## Der Versatz des Fachs geht in seine Karten über, das Fach steht wieder auf 0 -
## die Welt-Plätze bleiben byteweise, wo sie sind.
func bake_scroll(tray: int) -> void:
	if tray < 0 or tray >= _fachs.size():
		return
	var fach_node := _fachs[tray]
	var offset := fach_node.position.z
	# Die Mulden springen zurück auf ihre Fensterplätze - das Fenster färbt sie gleich
	# für den neuen Roll-Stand um, also liegt jede wieder unter ihrer Karte.
	_roll_to(tray, 0.0)
	_write_bands()
	if is_zero_approx(offset):
		return
	for child in fach_node.get_children():
		(child as Node3D).position.z += offset

## Der harte Weg: jedes Fach auf 0, jede Fahrt aus (Laufwechsel, Abbruch).
func settle_scroll_hard() -> void:
	_kill_snap()
	_scrolling = false
	for tray in _fachs.size():
		bake_scroll(tray)

func _kill_snap() -> void:
	if _snap != null and _snap.is_valid():
		_snap.kill()
	_snap = null

## Das GLIMMEN an den Wänden: links stehen noch hinausgerollte Spalten, rechts noch
## ungezeigte. Idempotent.
func set_overflow(left: bool, right: bool) -> void:
	_overflow = Vector2i(1 if left else 0, 1 if right else 0)
	_write_hints()

func overflow() -> Vector2i:
	return _overflow

func _build_hints() -> void:
	for hint in _hints:
		if is_instance_valid(hint):
			remove_child(hint)
			hint.queue_free()
	_hints.clear()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = HINT_COLOR * HINT_ENERGY
	for side in 2:
		var bar := MeshInstance3D.new()
		bar.name = "Glimmen%s" % ("Links" if side == 0 else "Rechts")
		var box := BoxMesh.new()
		box.size = Vector3(plate_span(), HINT_HEIGHT, HINT_WIDTH)
		bar.mesh = box
		bar.material_override = material
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bar)
		_hints.append(bar)
	_write_hints()

## Die Balken sitzen an den Innenkanten der Grube, auf der Kartenhöhe der Wahl.
func _write_hints() -> void:
	for side in _hints.size():
		var bar := _hints[side]
		if not is_instance_valid(bar):
			continue
		var dir := -1.0 if side == 0 else 1.0
		bar.position = Vector3(plate_center(),
			-drop_of(_selected, _scale) + PROUD + HINT_HEIGHT * 0.5,
			dir * (_span.y * 0.5 - HINT_WIDTH * 0.5))
		bar.visible = (_overflow.x if side == 0 else _overflow.y) > 0

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
	var previous := _selected
	_selected = wanted
	_kill()
	_write_bands()
	# Das ALTE Tablett behält seine Mulden, bis seine Fahrt zu Ende ist - nackt fuhr es
	# als graue Fläche davon (Spieler-Befund 2026-10-28). Sie sind deckend, stanzen
	# also durch keine Platte; die Aufschrift (Alpha) folgt weiter der Regel.
	for row in rows_of(previous):
		if row < _bays.size() and _bays[row] != null and is_instance_valid(_bays[row]):
			_bays[row].visible = true
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
	var out := retract_reach() if tray_state(tray, chosen) == RETRACTED else 0.0
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
	_write_hints()

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

## Die Aufschrift der vorderen Blende: das KÜRZEL der Sorte, dasselbe wie auf der
## Taste der Knopfleiste.
func number_text(row: int) -> String:
	return Pack.shelf_short(String(Pack.SHELF_ORDER[tray_of(row)]))

## Je Platz ein TICK in der Sortenfarbe (leer = stumpf). Idempotent: dieselbe Liste
## schreibt nichts neu.
## Die Sortenfarben einer Reihe, je Stellplatz eine (BAY_EMPTY = leer). Sie färben
## den Lichtsaum der Mulden; ändert sich die Platzzahl, werden die Mulden neu gebaut,
## sonst nur umgefärbt. Idempotent.
## rolled = das Tablett ist schon nach rechts gerollt: erst dann liegen links
## Vorrats-Mulden (Spieler-Wunsch 2026-10-28 - auf Stand 0 endet es an der ersten).
func set_bay_tints(row: int, tints: Array, rolled := false) -> void:
	if row < 0 or row >= ROWS or _tints.is_empty():
		return
	var was_rolled: bool = _rolled.get(row, false)
	if _tints[row] == tints and was_rolled == rolled:
		return
	var rebuild := (_tints[row] as Array).size() != tints.size() or was_rolled != rolled
	_rolled[row] = rolled
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

## Die MULDEN einer Reihe: Lippen auf der Platte, je Platz Saum, Boden und Buchse.
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
	# Der Verlauf mißt an der Wandhöhe - die hängt am Kartenmaß.
	_wall_material.set_shader_parameter("height", deck_height() - WALL_TOP_GAP)
	var lane := lane_of(row)
	var slot_depth := lane_depth() * (1.0 - FRONT_SHARE)
	var bays := Node3D.new()
	bays.name = "Mulden%d" % (row + 1)
	# Die Karten liegen mittig in dem Teil der Lane, den die Blende übrig läßt.
	bays.position = Vector3(lane_x(lane) - band_side(lane)
		* (lane_depth() * 0.5 - slot_depth * 0.5), 0.0, 0.0)
	bays.visible = shows_row(row, _selected)
	host.add_child(bays)
	_bays[row] = bays
	var columns := tints.size()
	var pitch := _span.y / float(columns)
	var bay := bay_size(columns)
	var rail := (slot_depth - bay.x) * 0.5
	var rib := pitch - bay.y
	var rolled: bool = _rolled.get(row, false)
	for side in 2:
		var dir := float(side) * 2.0 - 1.0
		TableProps.box(bays, "Lippe%d" % side, Vector3(rail, deck_height(), _span.y),
			Vector3(dir * (bay.x + rail) * 0.5, deck_height() * 0.5, 0.0), _lip_material)
	for i in columns + 1:
		var z := -_span.y * 0.5 + pitch * float(i)
		var width := rib
		# Ohne Vorrat links steht die Randrippe halb so breit INNEN an der Kante.
		if i == 0 and not rolled:
			width = rib * 0.5
			z += width * 0.5
		TableProps.box(bays, "Rippe%d" % i, Vector3(bay.x, deck_height(), width),
			Vector3(0.0, deck_height() * 0.5, z), _lip_material)
	# Die hintere Reihe trägt die PLATTE mit, über die volle Tablett-Breite: die feste
	# Platte endet an der Grubenwand, und rollen die Mulden darüber hinaus, sah man
	# zwischen den Reihen in die Wandtasche (Spieler-Befund 2026-10-28).
	var under := Vector2.ZERO
	if lane == LANE_BACK:
		under = Vector2(plate_center() - bays.position.x, plate_span())
		_build_underplate(bays, under, _span.y, 0.0)
	var seams: Array = []
	for i in columns:
		var node := Node3D.new()
		node.name = "Mulde%d" % i
		node.position = Vector3(0.0, 0.0, -_span.y * 0.5 + pitch * (float(i) + 0.5))
		bays.add_child(node)
		var seam := _seam_material(BAY_EMPTY)
		_build_bay(node, bay, seam)
		seams.append(seam)
	# Die VORRATS-Mulden: rechts immer, links erst nach dem Rollen. Sie rollen mit,
	# und weil sie alle gleich sind, springen sie beim Zug um ganze Teilungen nach -
	# so ist das Fenster bei jedem Zug voll, wie weit er auch geht (Spieler-Wunsch
	# 2026-10-28), ohne je mehr als ein Fenster voll zu bauen.
	_spare_right[row] = _build_spares(bays, "VorratRechts", 1.0, columns, pitch, bay, rail,
		rib, under)
	_spare_left[row] = _build_spares(bays, "VorratLinks", -1.0, columns, pitch, bay, rail,
		rib, under) if rolled else null
	_pitch[row] = pitch
	_seams[row] = seams
	_write_bays(row)

## EINE Mulde: Saum, Boden und die BUCHSE am Bild-rechten Ende (Spieler-Entscheid
## 2026-10-27) - ihr Mund sitzt auf dem Kartenfuß, die Stifte stecken darin.
func _build_bay(node: Node3D, bay: Vector2, seam: StandardMaterial3D) -> void:
	build_bay(node, bay, seam, _scale, _wall_material, _floor_material)

## Die EINE Bauregel einer Mulde - auch der Laden legt seine Kassetten so hinein
## (Spieler-Wunsch 2026-10-29). Der Knoten sitzt auf dem Muldenboden.
static func build_bay(node: Node3D, bay: Vector2, seam: StandardMaterial3D,
		cell_scale: float, wall_material: Material, floor_material: Material) -> void:
	TableProps.box(node, "Saum", Vector3(bay.x, SEAM_RISE, bay.y),
		Vector3(0.0, SEAM_RISE * 0.5, 0.0), seam)
	# Die WÄNDE der Vertiefung tragen ihr EIGENES Material (Spieler-Wunsch 2026-10-28):
	# im Ton des Decks las sie flach. Eine Spur in die Mulde gerückt und unter der
	# Oberkante, damit sie mit Lippe und Rippe nie eine Fläche teilen.
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
		socket.scale.y = thick / (thick + TowerView.SOCKET_LIP * 2.0)
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

## Die mitrollende PLATTE (under = Mitte quer, Breite): eine Spur UNTER der festen,
## also sichtbar nur, wo die fehlt - jenseits der Grubenwand. Koplanar stritten sie.
func _build_underplate(host: Node3D, under: Vector2, length: float, mid_z: float) -> void:
	TableProps.box(host, "Unterplatte", Vector3(under.y, PLATE - UNDERPLATE_SINK, length),
		Vector3(under.x, -(PLATE + UNDERPLATE_SINK) * 0.5, mid_z), _plate_material)
	# Das DECK auf Kartenhöhe außerhalb der Mulden-Lanes: beide Blenden-Streifen und der
	# Steg zwischen den Lanes. Mit Lippen und Rippen ist die ganze Oberfläche eben, und
	# die Mulden sind Vertiefungen darin (Spieler-Wunsch 2026-10-28).
	var offset := under.x - plate_center()
	for strip: Vector2 in _deck_strips():
		TableProps.box(host, "Deck", Vector3(strip.y - strip.x, deck_height(), length),
			Vector3(offset + (strip.x + strip.y) * 0.5, deck_height() * 0.5, mid_z),
			_lip_material)

## Die DECK-Streifen in Tablett-X (von, bis): Blende hinten, Steg, Blende vorn.
func _deck_strips() -> Array[Vector2]:
	var half := lane_depth() * 0.5
	var back := lane_x(LANE_BACK)
	var front := lane_x(LANE_FRONT)
	var strips: Array[Vector2] = [
		Vector2(back + half - band_depth(), back + half),
		Vector2(front + half, back - half),
		Vector2(front - half, front - half + band_depth())]
	return strips.filter(func(strip: Vector2) -> bool: return strip.y - strip.x > 0.001)

## Die Oberfläche des Tabletts: genau Kartenoberkante - eine Karte in ihrer Mulde liegt
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
## Fenster-Mulden nach dir (+1 Bild-rechts, -1 Bild-links). Seine Lage schreibt
## _place_spares.
func _build_spares(bays: Node3D, block_name: String, dir: float, columns: int,
		pitch: float, bay: Vector2, rail: float, rib: float, under: Vector2) -> Node3D:
	var block := Node3D.new()
	block.name = block_name
	bays.add_child(block)
	var count := columns + SPARE_EXTRA
	var reach := pitch * float(count)
	if under.y > 0.0:
		_build_underplate(block, under, reach, dir * reach * 0.5)
	for side in 2:
		var across := float(side) * 2.0 - 1.0
		TableProps.box(block, "Lippe%d" % side, Vector3(rail, deck_height(), reach),
			Vector3(across * (bay.x + rail) * 0.5, deck_height() * 0.5, dir * reach * 0.5),
			_lip_material)
	for i in count:
		TableProps.box(block, "Rippe%d" % i, Vector3(bay.x, deck_height(), rib),
			Vector3(0.0, deck_height() * 0.5, dir * pitch * float(i + 1)), _lip_material)
		var node := Node3D.new()
		node.name = "Vorrat%d" % i
		node.position = Vector3(0.0, 0.0, dir * pitch * (float(i) + 0.5))
		block.add_child(node)
		_build_bay(node, bay, _seam_material(BAY_EMPTY))
	block.position.z = dir * _span.y * 0.5
	return block

## Die Vorrats-Blöcke einer Reihe bei Zug-Versatz z: am Rand der Fenster-Mulden, und
## wo der schon aus dem Fenster gerollt ist, um ganze Teilungen nachgerückt.
func _place_spares(row: int, z: float) -> void:
	var pitch: float = _pitch.get(row, 0.0)
	if pitch <= 0.0:
		return
	var half := _span.y * 0.5
	var right: Node3D = _spare_right.get(row)
	if right != null and is_instance_valid(right):
		var lag := ceili(((-half - pitch) - (z + half)) / pitch)
		right.position.z = half + pitch * float(maxi(lag, 0))
	var left: Node3D = _spare_left.get(row)
	if left != null and is_instance_valid(left):
		var lead := ceili(((z - half) - (half + pitch)) / pitch)
		left.position.z = -half - pitch * float(maxi(lead, 0))

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
	# Die Lippe ist Platte; der Muldenboden liegt dunkler.
	_lip_material = _plate_material
	_wall_material = ShaderMaterial.new()
	_wall_material.shader = load("res://assets/shaders/bay_wall.gdshader")
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = load("res://assets/shaders/pit_lining.gdshader")
	_tune_bay_floor()

func _metal(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	return TableProps.metal(albedo, emission, energy, 0.35, 0.55)
