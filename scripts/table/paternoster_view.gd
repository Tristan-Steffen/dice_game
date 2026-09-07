class_name PaternosterView
extends Node3D
## Das MAGAZIN als PATERNOSTER (2026-09-07, zweite Fassung): ein KREISLAUF aus ZEHN
## REIHEN, von dem immer ZWEI zugleich in der Fläche liegen - eine HINTERE (Bild-oben,
## Welt +X) und eine VORDERE (Bild-unten, Welt -X). Beide liegen auf Lese-Tiefe, jede
## eine liegende Karte tief; die acht übrigen parken darunter, gestapelt nach Abstand.
##
## EIN Hebelwurf bewegt den Kreislauf um EINE Reihe. Vorwärts (Hebel nach OBEN):
## die vordere Reihe VERSINKT, die hintere GLEITET in der Fläche nach vorn, und
## hinten TAUCHT die nächste aus der Tiefe AUF. Rückwärts ist das Spiegelbild.
## Ein echter Paternoster von oben gesehen: hinten hoch, oben nach vorn, vorn
## hinunter, unten zurück - zehn Würfe sind ein voller Umlauf.
##
## Der SITZ jeder Reihe ist eine reine Funktion von `head` (seat_of -> Lane und
## Park-Tiefe), also ist der ganze Kreislauf prüfbar, ohne einen Körper zu fahren.
##
## Die Karten LIEGEN flach auf ihrem Tablett (Netz nach oben, wie im Turm) und sind
## KINDER ihres Faches: eine Fahrt trägt sie mit. ALLE ZEHN Reihen werden gerendert -
## durch den SPALT zwischen den Lanes und die FUSSLUFT darunter liest man die
## geparkten Tabletts als Treppe in der Grube.
##
## Jedes Tablett trägt an seiner Bild-UNTEREN Kante die FRONT-BLENDE mit der
## Reihen-Nummer und je Platz einem SORTEN-TICK, damit es als Schublade liest.
##
## Die Maße kommen von außen (scene_root rechnet die gemeldete Grube in Welt), die
## HÖHEN gehören dem Paternoster. step/settle_hard schreiben den Endzustand hart.

const ROWS := PackDrawerView.ROWS

## Die zwei sichtbaren Lanes: HINTEN ist Bild-oben (Welt +X), VORN Bild-unten.
const LANE_BACK := 0
const LANE_FRONT := 1
## Wie tief der Parkstapel je Lane reicht: eine sichtbare Reihe plus vier geparkte.
const MAX_DEPTH := ROWS / 2 - 1

## Ein Tablett ist eine Platte; die Karte liegt eine Spur darüber (koplanar
## stritten sie im Tiefenpuffer - dieselbe Zahl wie im Turm).
const PLATE := 0.06
const PROUD := TowerView.FLOOR_PROUD
## Luft zwischen zwei geparkten Tabletts, über der liegenden Karte des unteren.
## GEMESSEN gegen die Fahrt: an der 15°-Station projiziert eine Welthöhe nur mit
## tan 15° in die Fläche, ein knapper Sprung läse sich also gar nicht - und tiefer
## als die Grube (4,6) darf der Stapel trotzdem nie werden.
const AIR := 0.18
## Die TEILUNG des Parkstapels: eine liegende Karte plus Platte plus Luft.
const PITCH := TowerView.CARD_THICKNESS + PLATE + AIR
## Die Luft, die die oberste Karte unter der Tischkante behält - dieselbe, die der
## GRUBEN-BOGEN einhält (keine Karte ragt je über die Kante).
const RIM_CLEAR := TowerView.CARD_THICKNESS * 0.5
## Und wie weit der GRIFF sie beim Überfahren aus der Grube zieht: bis eine
## Kartendicke über das Glas - nur der Hover darf über die Kante.
const HOVER_PROUD := TowerView.CARD_THICKNESS

## Der Anteil der LANE-Tiefe, den die FRONT-BLENDE am Bild-unteren Rand nimmt;
## die Karten liegen in dem, was bleibt (PackDrawerView schneidet ihre Plätze an
## derselben Zahl - EINE Quelle).
const FRONT_SHARE := PackDrawerView.FRONT_SHARE
const BAND_RISE := 0.05
const NUMBER_FONT := 48
## Wie weit die (mittig gesetzte) Nummer von der linken Blenden-Kante einrückt, in
## Blenden-Tiefen: GEMESSEN an "10/10" - bündig gesetzt schnitt die Grubenwand sie an.
const NUMBER_INSET := 2.2
## Ein Sorten-TICK: ein flacher Block auf der Blende, Anteil ihrer Maße.
const TICK_SHARE := Vector2(0.55, 0.34)
const TICK_RISE := 0.02
const TICK_EMPTY := Color(0.16, 0.155, 0.22)

## Die Fahrt: erst sinkt die vordere Reihe, dann gleiten und steigen die anderen.
const SINK_TIME := 0.30
const RIDE_TIME := 0.30

const PLATE_ALBEDO := TowerView.FRAME_ALBEDO
const PLATE_EMISSION := TowerView.FRAME_EMISSION
const PLATE_ENERGY := TowerView.FRAME_EMISSION_ENERGY
const BAND_ALBEDO := TowerView.BAR_ALBEDO
const BAND_EMISSION := TowerView.BAR_EMISSION
const BAND_ENERGY := 0.35
## Wie viel heller ein GEPARKTES Tablett glüht: in der dunklen Grube trifft es kein
## Szenenlicht, und durch Spalt und Fußluft sieht man nur seine schmalen STIRNFLÄCHEN.
## GEMESSEN am Bild - bei 1,0 liest der Parkstapel als schwarzer Schlitz, bei 3,0
## steht die Treppe der Front-Blenden im Bild, ohne die liegenden Reihen zu überstrahlen
## (Bloom-Schwelle 0,95: 0,42 × 3,0 = 1,26 trägt nur die winzigen Stirnflächen).
const PARK_GLOW := 3.0

var _span := Vector2.ONE
var _seat := Vector3.ZERO
var _scale := PackDrawerView.CASSETTE_SCALE
var _head := 0
var _built := false
## Die gemeldete LANE-Geometrie in WELT: je Lane (Mitte relativ zur Grubenmitte in
## Welt-X, Tiefe). Leer = der kopflose Rückfall, die halbe Grube je Lane.
var _lanes: Array[Vector2] = []

var _trays: Array[Node3D] = []
var _fachs: Array[Node3D] = []
var _bands: Array[Node3D] = []
var _plates: Array[MeshInstance3D] = []
var _blechs: Array[MeshInstance3D] = []
var _ticks: Array = []          # Reihe -> Array[Color], zuletzt geschrieben
var _plate_material: StandardMaterial3D
var _band_material: StandardMaterial3D
## Dieselben Materialien für den PARKSTAPEL, nur heller - siehe PARK_GLOW.
var _plate_material_parked: StandardMaterial3D
var _band_material_parked: StandardMaterial3D
var _ride: Tween

func _init() -> void:
	name = "Paternoster"

# --- Die reine SITZ-Rechnung -------------------------------------------------------

## Wo Reihe `row` liegt, wenn `head` hinten liegt: {"lane", "depth"}. Tiefe 0 heißt
## SICHTBAR (die zwei Lanes in der Fläche), alles darüber ist ein Parkplatz.
## Der Ring läuft: hinten unten -> hinten oben -> vorn oben -> vorn unten -> hinten
## unten. Was gerade vorn versunken ist (head+2 …), parkt darum unter der VORDEREN
## Lane; was als nächstes hinten auftaucht (head-1 …), unter der HINTEREN.
static func seat_of(row: int, head: int) -> Dictionary:
	var offset := posmod(row - head, ROWS)
	if offset == 0:
		return {"lane": LANE_BACK, "depth": 0}
	if offset == 1:
		return {"lane": LANE_FRONT, "depth": 0}
	if offset <= ROWS / 2:
		return {"lane": LANE_FRONT, "depth": offset - 1}
	return {"lane": LANE_BACK, "depth": ROWS - offset}

## Wie weit die Trittfläche einer SICHTBAREN Reihe unter dem Glas liegt: so tief,
## daß die flach darauf liegende Karte mit ihrer Oberseite unter der Tischkante
## bleibt.
static func read_drop(cell_scale: float) -> float:
	return DataCellView.lying_over(cell_scale) + PROUD + RIM_CLEAR

## Der erste Parkplatz unter einer Lane: unter der Karte, die dort liegt.
static func park_drop(cell_scale: float) -> float:
	return read_drop(cell_scale) + DataCellView.lying_over(cell_scale) + PLATE + AIR

## Die Tiefe einer Park-Stufe (0 = die Lese-Tiefe).
static func drop_of(depth: int, cell_scale: float) -> float:
	if depth <= 0:
		return read_drop(cell_scale)
	return park_drop(cell_scale) + PITCH * float(depth - 1)

## ... und dieselbe Tiefe für Reihe `row` bei `head`.
static func drop_for(row: int, head: int, cell_scale: float) -> float:
	return drop_of(int(seat_of(row, head)["depth"]), cell_scale)

## Der GRIFF im Magazin, als Anteil der Standhöhe (DataCellView.hover_lift): er
## zieht die liegende Karte aus der Grube bis eine Kartendicke über das Glas.
static func hover_lift(cell_scale: float) -> float:
	var reach := read_drop(cell_scale) + HOVER_PROUD
	return reach / maxf(DataCellView.STAND_HEIGHT * cell_scale, 0.001)

## Wie tief der Parkstapel insgesamt reicht - daran mißt, ob die Grube ihn trägt.
static func stack_depth(cell_scale: float) -> float:
	return drop_of(MAX_DEPTH, cell_scale) + PLATE

# --- Aufbau ------------------------------------------------------------------------

## Stellt den Paternoster (idempotent - dieselben Maße bauen nichts neu). at = der
## GLASPUNKT der Grubenmitte, span = ihr Weltmaß (x quer/Bild-hoch, y längs/Bild-
## breit), cell_scale der Anzeige-Maßstab der Karten. Die Grube trägt ZWEI Lanes,
## ein Tablett ist also nur ihre halbe Tiefe.
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
	for row in ROWS:
		_build_tray(row)
	_built = true
	settle_hard()

## Die Tabletts entstehen EINMAL - ihre Fächer tragen die Karten, ein Neuaufbau der
## Maße darf sie nicht mit wegräumen.
func _ensure_trays() -> void:
	if not _trays.is_empty():
		return
	for row in ROWS:
		var tray := Node3D.new()
		tray.name = "Tablett%d" % (row + 1)
		add_child(tray)
		_trays.append(tray)
		var fach := Node3D.new()
		fach.name = "Fach"
		tray.add_child(fach)
		_fachs.append(fach)
		_bands.append(null)
		_plates.append(null)
		_blechs.append(null)
		_ticks.append([] as Array[Color])

## Platte und FRONT-BLENDE einer Reihe. Das Fach bleibt stehen - es trägt die Karten.
func _build_tray(row: int) -> void:
	_ensure_materials()
	var tray := _trays[row]
	for child in tray.get_children():
		if child == _fachs[row]:
			continue
		tray.remove_child(child)
		child.queue_free()
	var plate := _box("Platte", Vector3(lane_depth(), PLATE, _span.y),
		Vector3(0.0, -PLATE * 0.5, 0.0), _plate_material, tray)
	plate.name = "Platte"
	_plates[row] = plate
	var band := Node3D.new()
	band.name = "Blende"
	# Bild-UNTEN ist Welt -X: dort steht die Blende, wie die Front einer Schublade.
	band.position = Vector3(-lane_depth() * 0.5 + band_depth() * 0.5, 0.0, 0.0)
	tray.add_child(band)
	_bands[row] = band
	_blechs[row] = _box("Blech", Vector3(band_depth(), BAND_RISE, _span.y),
		Vector3(0.0, BAND_RISE * 0.5, 0.0), _band_material, band)
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
	_write_ticks(row)

## Die Tiefe EINER Lane in Welt: sie wird GEMELDET (das Fenster schneidet Spalt und
## Fußluft heraus); ohne Meldung bleibt die halbe Grube der kopflose Rückfall.
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

# --- Der Zustand -------------------------------------------------------------------

## Die Reihe, die HINTEN liegt; vorn liegt die nächste.
func head() -> int:
	return _head

func front() -> int:
	return posmod(_head + 1, ROWS)

func row_count() -> int:
	return ROWS

## Die zwei sichtbaren Reihen, hinten zuerst.
func rows_shown() -> Array[int]:
	return [_head, front()] as Array[int]

## Liegt diese Reihe in der Fläche?
func shows(row: int) -> bool:
	return int(seat_of(row, _head)["depth"]) == 0

## Fährt gerade ein Tablett?
func riding() -> bool:
	return _ride != null and _ride.is_valid()

## Der EINE harte Schreiber: jedes Tablett auf seinem Sitz. Jeder Abbruch und jeder
## Laufwechsel geht hier durch.
func settle_hard() -> void:
	_kill()
	_write_hard()

## Der Kreislauf springt HART auf diese Reihe (Laufwechsel, Neuaufbau) - keine Fahrt.
func set_head(row: int) -> void:
	_head = posmod(row, ROWS)
	settle_hard()

## EIN Schritt des Kreislaufs. delta > 0 = VORWÄRTS (Hebel nach oben): vorn versinkt,
## hinten gleitet nach vorn, hinten taucht die nächste auf. Endzustand zuerst - ein
## Wurf mitten in einer Fahrt beendet sie hart und fährt neu, er schuldet nichts.
func step(delta: int) -> void:
	if _trays.is_empty() or delta == 0:
		return
	var before := _head
	# Vorwärts läuft der Ring gegen die Numerierung: die Reihe, die hinten auftaucht,
	# ist head-1 (siehe seat_of).
	_head = posmod(_head - signi(delta), ROWS)
	_kill()
	_write_hard()
	if not is_inside_tree():
		return
	_ride = create_tween()
	_ride.set_parallel(true)
	for row in ROWS:
		var from := _tray_pose(row, before)
		var to := _tray_pose(row, _head)
		if from.is_equal_approx(to):
			continue
		_trays[row].position = from
		var was := int(seat_of(row, before)["depth"])
		# Der Park-Glanz gehört dem SITZ, nicht der Fahrt: unterwegs trägt ein Tablett
		# den Ton seines ALTEN Platzes (settle_hard richtet ihn am Ende) - sonst
		# flammte ein sinkendes noch in der Fläche auf.
		_paint_tray(row, was != 0)
		if was == 0 and not shows(row):
			# Der SINKER fährt ZUERST - er räumt den Platz, in den gleich gegleitet wird.
			_ride.tween_property(_trays[row], "position", to, SINK_TIME) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			continue
		# Alles andere folgt: Gleiten in der Fläche, Aufsteigen aus der Tiefe und
		# das Nachrücken der Parkplätze - zugleich, hinter dem Sinken.
		_ride.tween_property(_trays[row], "position", to, RIDE_TIME) \
			.set_delay(SINK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ride.chain().tween_callback(settle_hard)

## Die Dauer eines Schritts.
static func step_time() -> float:
	return SINK_TIME + RIDE_TIME

func _tray_pose(row: int, head_row: int) -> Vector3:
	var seat := seat_of(row, head_row)
	return Vector3(lane_x(int(seat["lane"])),
		-drop_of(int(seat["depth"]), _scale), 0.0)

## Alle ZEHN Reihen werden gerendert - durch Spalt, Fußluft und die Ritzen zwischen
## den Schienen sieht man die geparkten Tabletts in der Grube liegen. `shows(row)`
## bleibt die LOGIK-Antwort (Lese-Tiefe), sie schaltet nur nichts mehr.
func _write_hard() -> void:
	for row in _trays.size():
		_trays[row].position = _tray_pose(row, _head)
		_paint_tray(row, not shows(row))

## Ein GEPARKTES Tablett glüht heller: in der Grube trifft es kein Szenenlicht, und
## sichtbar ist durch den SPALT nur seine schmale Stirnfläche.
func _paint_tray(row: int, parked: bool) -> void:
	if row >= _plates.size():
		return
	if _plates[row] != null and is_instance_valid(_plates[row]):
		_plates[row].material_override = \
			_plate_material_parked if parked else _plate_material
	if _blechs[row] != null and is_instance_valid(_blechs[row]):
		_blechs[row].material_override = \
			_band_material_parked if parked else _band_material

func _kill() -> void:
	if _ride != null and _ride.is_valid():
		_ride.kill()
	_ride = null

# --- Die Plätze --------------------------------------------------------------------

## Welt-y der Trittfläche einer Reihe (ihr RUHE-Sitz, nicht ihr Stand in der Fahrt).
func tray_top(row: int) -> float:
	return _seat.y - drop_for(clampi(row, 0, ROWS - 1), _head, _scale)

## ... und die Höhe, auf der die Karte dieser Reihe LIEGT.
func card_seat(row: int) -> float:
	return tray_top(row) + PROUD

## Der höchste Punkt einer Karte dieser Reihe - daran mißt die Invariante.
func card_top(row: int) -> float:
	return card_seat(row) + DataCellView.lying_over(_scale)

## Das FACH einer Reihe - der Wirt ihrer Karten (null = noch nicht gebaut).
func fach(row: int) -> Node3D:
	if _fachs.is_empty():
		return null
	return _fachs[clampi(row, 0, ROWS - 1)]

## Die Karte wird KIND ihres Faches - eine Fahrt trägt sie mit. Ihren Platz nennt
## der Sitz-Schreiber, die HÖHE gehört dem Tablett: lokal liegt sie IMMER PROUD
## über der Trittfläche, auch mitten in einer Fahrt.
func host_card(cell: Node3D, row: int) -> void:
	if _fachs.is_empty():
		return
	var fach_node := _fachs[clampi(row, 0, ROWS - 1)]
	if cell.get_parent() != fach_node:
		rehost(cell, fach_node)
	cell.position.y = PROUD

## Liegt diese Karte schon auf ihrem Platz? Verglichen wird in der TISCHEBENE und
## am Fach - die Höhe gehört dem Tablett, und die fährt.
func seated(cell: Node3D, row: int, at: Vector3) -> bool:
	if _fachs.is_empty() or cell.get_parent() != _fachs[clampi(row, 0, ROWS - 1)]:
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

func number_text(row: int) -> String:
	return "%d/%d" % [row + 1, ROWS]

## Je Platz ein TICK in der Sortenfarbe (leer = stumpf). Idempotent: dieselbe Liste
## schreibt nichts neu.
func set_ticks(row: int, tints: Array) -> void:
	if row < 0 or row >= ROWS or _ticks.is_empty():
		return
	if _ticks[row] == tints:
		return
	_ticks[row] = tints.duplicate()
	_write_ticks(row)

func tick_count(row: int) -> int:
	if row < 0 or row >= _ticks.size():
		return 0
	return (_ticks[row] as Array).size()

func tick_color(row: int, index: int) -> Color:
	if row < 0 or row >= _ticks.size():
		return TICK_EMPTY
	var line: Array = _ticks[row]
	if index < 0 or index >= line.size():
		return TICK_EMPTY
	return line[index]

func _write_ticks(row: int) -> void:
	var band: Node3D = _bands[row] if row < _bands.size() else null
	if band == null or not is_instance_valid(band):
		return
	for child in band.get_children():
		if child.name == "Blech" or child.name == "Nummer":
			continue
		band.remove_child(child)
		child.queue_free()
	var line: Array = _ticks[row]
	if line.is_empty():
		return
	# Die Ticks teilen sich, was die Nummer übrig läßt - ein Tick je Platz, mittig
	# in seiner Teilung, in derselben Reihenfolge wie die Karten darüber.
	var start := -_span.y * 0.5 + band_depth() * (NUMBER_INSET + 1.6)  # Nummer links davor
	var room := _span.y * 0.5 - start
	var pitch := room / float(line.size())
	for i in line.size():
		var tint: Color = line[i]
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 0.9 if tint != TICK_EMPTY else 0.25
		_box("Tick%d" % i,
			Vector3(band_depth() * TICK_SHARE.x, TICK_RISE, pitch * TICK_SHARE.y),
			Vector3(0.0, BAND_RISE + TICK_RISE * 0.5, start + pitch * (float(i) + 0.5)),
			material, band)

# --- Bausteine -----------------------------------------------------------------------

func _ensure_materials() -> void:
	if _plate_material != null:
		return
	_plate_material = StandardMaterial3D.new()
	_plate_material.albedo_color = PLATE_ALBEDO
	_plate_material.metallic = 0.35
	_plate_material.roughness = 0.55
	_plate_material.emission_enabled = true
	_plate_material.emission = PLATE_EMISSION
	_plate_material.emission_energy_multiplier = PLATE_ENERGY
	_band_material = StandardMaterial3D.new()
	_band_material.albedo_color = BAND_ALBEDO
	_band_material.metallic = 0.6
	_band_material.roughness = 0.35
	_band_material.emission_enabled = true
	_band_material.emission = BAND_EMISSION
	_band_material.emission_energy_multiplier = BAND_ENERGY
	_plate_material_parked = _plate_material.duplicate()
	_plate_material_parked.emission_energy_multiplier = PLATE_ENERGY * PARK_GLOW
	_band_material_parked = _band_material.duplicate()
	_band_material_parked.emission_energy_multiplier = BAND_ENERGY * PARK_GLOW

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
