class_name PaternosterView
extends Node3D
## Das MAGAZIN als PATERNOSTER (2026-09-07): FÜNF TABLETTS übereinander in der
## Magazin-Grube. GEZEIGT wird immer genau EINES, knapp unter dem Glas; die anderen
## parken darunter in der Tiefe, jedes auf SEINER festen Park-Höhe. Blättern heißt
## darum: das gezeigte SINKT, danach STEIGT das gewählte - zwei Tabletts fahren,
## alle anderen stehen, und nichts durchdringt sich.
##
## Die Karten LIEGEN flach auf ihrem Tablett (Netz nach oben, wie im Turm) und sind
## KINDER ihres Faches: eine Fahrt trägt sie mit, und die SICHTBARKEIT einer Etage
## ist die ihres Faches - EIN Schreiber, kein Sichtbarkeits-Bit je Karte.
##
## Jedes Tablett trägt an seiner Bild-UNTEREN Kante die FRONT-BLENDE mit der
## Etagen-Nummer und je Platz einem SORTEN-TICK, damit es als Schublade liest.
##
## Die Maße kommen von außen (scene_root rechnet die gemeldete Grube in Welt), die
## HÖHEN gehören dem Paternoster. seat/settle_hard schreiben den Endzustand hart.

const PAGES := PackDrawerView.PAGES

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

## Der Anteil der Gruben-TIEFE, den die FRONT-BLENDE am Bild-unteren Rand nimmt;
## die Karten liegen in dem, was bleibt (PackDrawerView schneidet ihre Plätze an
## derselben Zahl - EINE Quelle).
const FRONT_SHARE := PackDrawerView.FRONT_SHARE
const BAND_RISE := 0.05
const NUMBER_FONT := 48
## Ein Sorten-TICK: ein flacher Block auf der Blende, Anteil ihrer Maße.
const TICK_SHARE := Vector2(0.55, 0.34)
const TICK_RISE := 0.02
const TICK_EMPTY := Color(0.16, 0.155, 0.22)

## Die Fahrt: erst sinkt das gezeigte, dann steigt das gewählte.
const SINK_TIME := 0.30
const RISE_TIME := 0.30

const PLATE_ALBEDO := TowerView.FRAME_ALBEDO
const PLATE_EMISSION := TowerView.FRAME_EMISSION
const PLATE_ENERGY := TowerView.FRAME_EMISSION_ENERGY
const BAND_ALBEDO := TowerView.BAR_ALBEDO
const BAND_EMISSION := TowerView.BAR_EMISSION
const BAND_ENERGY := 0.35

var _span := Vector2.ONE
var _seat := Vector3.ZERO
var _scale := PackDrawerView.CASSETTE_SCALE
var _shown := 0
var _leaving := -1
var _built := false

var _trays: Array[Node3D] = []
var _fachs: Array[Node3D] = []
var _bands: Array[Node3D] = []
var _ticks: Array = []          # Etage -> Array[Color], zuletzt geschrieben
var _plate_material: StandardMaterial3D
var _band_material: StandardMaterial3D
var _ride: Tween

func _init() -> void:
	name = "Paternoster"

# --- Die reine Höhen-Rechnung ------------------------------------------------------

## Wie weit die Trittfläche des GEZEIGTEN Tabletts unter dem Glas liegt: so tief,
## daß die flach darauf liegende Karte mit ihrer Oberseite unter der Tischkante
## bleibt.
static func read_drop(cell_scale: float) -> float:
	return DataCellView.lying_over(cell_scale) + PROUD + RIM_CLEAR

## Und wie weit die des Tabletts von Etage page: gezeigt die Lese-Tiefe, sonst sein
## FESTER Platz im Parkstapel - so fahren beim Blättern nur zwei Tabletts.
static func drop_for(page: int, shown: int, cell_scale: float) -> float:
	if page == shown:
		return read_drop(cell_scale)
	return read_drop(cell_scale) + DataCellView.lying_over(cell_scale) + PLATE + AIR \
		+ PITCH * float(maxi(page, 0))

## Der GRIFF im Magazin, als Anteil der Standhöhe (DataCellView.hover_lift): er
## zieht die liegende Karte aus der Grube bis eine Kartendicke über das Glas.
static func hover_lift(cell_scale: float) -> float:
	var reach := read_drop(cell_scale) + HOVER_PROUD
	return reach / maxf(DataCellView.STAND_HEIGHT * cell_scale, 0.001)

## Wie tief der Parkstapel insgesamt reicht - daran mißt, ob die Grube ihn trägt.
static func stack_depth(cell_scale: float) -> float:
	return drop_for(PAGES - 1, -1, cell_scale) + PLATE

# --- Aufbau ------------------------------------------------------------------------

## Stellt den Paternoster (idempotent - dieselben Maße bauen nichts neu). at = der
## GLASPUNKT der Grubenmitte, span = ihr Weltmaß (x quer/Bild-hoch, y längs/Bild-
## breit), cell_scale der Anzeige-Maßstab der Karten.
func setup(at: Vector3, span: Vector2, cell_scale: float) -> void:
	var wanted := Vector2(maxf(span.x, 0.01), maxf(span.y, 0.01))
	if _built and _seat.is_equal_approx(at) and _span.is_equal_approx(wanted) \
			and is_equal_approx(_scale, cell_scale):
		return
	_seat = at
	_span = wanted
	_scale = cell_scale
	global_position = at
	_ensure_trays()
	for page in PAGES:
		_build_tray(page)
	_built = true
	settle_hard()

## Die Tabletts entstehen EINMAL - ihre Fächer tragen die Karten, ein Neuaufbau der
## Maße darf sie nicht mit wegräumen.
func _ensure_trays() -> void:
	if not _trays.is_empty():
		return
	for page in PAGES:
		var tray := Node3D.new()
		tray.name = "Tablett%d" % (page + 1)
		add_child(tray)
		_trays.append(tray)
		var fach := Node3D.new()
		fach.name = "Fach"
		tray.add_child(fach)
		_fachs.append(fach)
		_bands.append(null)
		_ticks.append([] as Array[Color])

## Platte und FRONT-BLENDE einer Etage. Das Fach bleibt stehen - es trägt die Karten.
func _build_tray(page: int) -> void:
	_ensure_materials()
	var tray := _trays[page]
	for child in tray.get_children():
		if child == _fachs[page]:
			continue
		tray.remove_child(child)
		child.queue_free()
	var plate := _box("Platte", Vector3(_span.x, PLATE, _span.y),
		Vector3(0.0, -PLATE * 0.5, 0.0), _plate_material, tray)
	plate.name = "Platte"
	var band := Node3D.new()
	band.name = "Blende"
	# Bild-UNTEN ist Welt -X: dort steht die Blende, wie die Front einer Schublade.
	band.position = Vector3(-_span.x * 0.5 + band_depth() * 0.5, 0.0, 0.0)
	tray.add_child(band)
	_bands[page] = band
	_box("Blech", Vector3(band_depth(), BAND_RISE, _span.y),
		Vector3(0.0, BAND_RISE * 0.5, 0.0), _band_material, band)
	var label := Label3D.new()
	label.name = "Nummer"
	label.text = number_text(page)
	label.font_size = NUMBER_FONT
	# Flach in Tisch-Leserichtung wie jede Aufschrift auf dem Filz.
	label.transform.basis = Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)
	label.pixel_size = band_depth() * 0.7 / (float(NUMBER_FONT) * 0.62)
	label.position = Vector3(0.0, BAND_RISE + 0.01, -_span.y * 0.5 + band_depth())
	label.outline_size = 12
	label.outline_modulate = Color(0.03, 0.03, 0.05)
	band.add_child(label)
	_write_ticks(page)

## Die Tiefe der Blende in Welt.
func band_depth() -> float:
	return _span.x * FRONT_SHARE

# --- Der Zustand -------------------------------------------------------------------

func shown() -> int:
	return _shown

func page_count() -> int:
	return PAGES

## Fährt gerade ein Tablett?
func riding() -> bool:
	return _ride != null and _ride.is_valid()

## Der EINE harte Schreiber: jedes Tablett auf seiner Ruhehöhe, nur das gezeigte
## Fach sichtbar. Jeder Abbruch und jeder Laufwechsel geht hier durch.
func settle_hard() -> void:
	_kill()
	_leaving = -1
	_write_hard()

## Blättern: das gezeigte Tablett SINKT, danach STEIGT das gewählte. Endzustand
## zuerst - ein abgebrochener Tween schuldet nichts.
func show_page(index: int) -> void:
	var wanted := clampi(index, 0, PAGES - 1)
	if _trays.is_empty():
		return
	# Wer schon oben liegt, fährt nicht - und eine LAUFENDE Fahrt dorthin bleibt
	# unberührt (sonst risse ein zweiter Aufruf im selben Bild sie ab).
	if wanted == _shown:
		return
	var leaving := _shown
	_shown = wanted
	_kill()
	_write_hard()
	if not is_inside_tree():
		return
	# ... und dann der Weg dorthin: beide Tabletts stehen zunächst wieder, wo sie
	# herkommen, und fahren NACHEINANDER.
	_leaving = leaving
	var down := _trays[leaving]
	var up := _trays[wanted]
	down.position.y = -drop_for(leaving, leaving, _scale)
	up.position.y = -drop_for(wanted, leaving, _scale)
	_fachs[leaving].visible = true  # solange es sinkt, ist es zu sehen
	_ride = create_tween()
	_ride.tween_property(down, "position:y", -drop_for(leaving, wanted, _scale),
		SINK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ride.tween_property(up, "position:y", -drop_for(wanted, wanted, _scale),
		RISE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ride.tween_callback(settle_hard)

func _write_hard() -> void:
	for page in _trays.size():
		_trays[page].position.y = -drop_for(page, _shown, _scale)
		_fachs[page].visible = page == _shown

func _kill() -> void:
	if _ride != null and _ride.is_valid():
		_ride.kill()
	_ride = null

# --- Die Plätze --------------------------------------------------------------------

## Welt-y der Trittfläche einer Etage (ihre RUHEHÖHE, nicht ihr Stand in der Fahrt).
func tray_top(page: int) -> float:
	return _seat.y - drop_for(clampi(page, 0, PAGES - 1), _shown, _scale)

## ... und die Höhe, auf der die Karte dieser Etage LIEGT.
func card_seat(page: int) -> float:
	return tray_top(page) + PROUD

## Der höchste Punkt einer Karte dieser Etage - daran mißt die Invariante.
func card_top(page: int) -> float:
	return card_seat(page) + DataCellView.lying_over(_scale)

## Das FACH einer Etage - der Wirt ihrer Karten (null = noch nicht gebaut).
func fach(page: int) -> Node3D:
	if _fachs.is_empty():
		return null
	return _fachs[clampi(page, 0, PAGES - 1)]

## Die Karte wird KIND ihres Faches - eine Fahrt trägt sie mit. Ihren Platz nennt
## der Sitz-Schreiber, die HÖHE gehört dem Tablett: lokal liegt sie IMMER PROUD
## über der Trittfläche, auch mitten in einer Fahrt.
func host_card(cell: Node3D, page: int) -> void:
	if _fachs.is_empty():
		return
	var fach := _fachs[clampi(page, 0, PAGES - 1)]
	if cell.get_parent() != fach:
		rehost(cell, fach)
	cell.position.y = PROUD

## Liegt diese Karte schon auf ihrem Platz? Verglichen wird in der TISCHEBENE und
## am Fach - die Höhe gehört dem Tablett, und die fährt.
func seated(cell: Node3D, page: int, at: Vector3) -> bool:
	if _fachs.is_empty() or cell.get_parent() != _fachs[clampi(page, 0, PAGES - 1)]:
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

func number_text(page: int) -> String:
	return "%d/%d" % [page + 1, PAGES]

## Je Platz ein TICK in der Sortenfarbe (leer = stumpf). Idempotent: dieselbe Liste
## schreibt nichts neu.
func set_ticks(page: int, tints: Array) -> void:
	if page < 0 or page >= PAGES or _ticks.is_empty():
		return
	if _ticks[page] == tints:
		return
	_ticks[page] = tints.duplicate()
	_write_ticks(page)

func tick_count(page: int) -> int:
	if page < 0 or page >= _ticks.size():
		return 0
	return (_ticks[page] as Array).size()

func tick_color(page: int, index: int) -> Color:
	if page < 0 or page >= _ticks.size():
		return TICK_EMPTY
	var row: Array = _ticks[page]
	if index < 0 or index >= row.size():
		return TICK_EMPTY
	return row[index]

func _write_ticks(page: int) -> void:
	var band: Node3D = _bands[page] if page < _bands.size() else null
	if band == null or not is_instance_valid(band):
		return
	for child in band.get_children():
		if child.name == "Blech" or child.name == "Nummer":
			continue
		band.remove_child(child)
		child.queue_free()
	var row: Array = _ticks[page]
	if row.is_empty():
		return
	# Die Ticks teilen sich, was die Nummer übrig läßt - ein Tick je Platz, mittig
	# in seiner Teilung, in derselben Reihenfolge wie die Karten darüber.
	var start := -_span.y * 0.5 + band_depth() * 1.6  # die Nummer steht links davor
	var room := _span.y * 0.5 - start
	var pitch := room / float(row.size())
	for i in row.size():
		var tint: Color = row[i]
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
