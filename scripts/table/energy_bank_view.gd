class_name EnergyBankView
extends Node3D
## Die AKKU-BANK als KLINGEN-RACK: ein flacher Stahlkragen um einen dunklen Schacht, zehn
## Plätze; je freigegebener Fünfergruppe steckt eine Akku-KLINGE, von der nur die Oberkante
## über dem Tisch steht - fünf Lichtfenster (eine Energie je Fenster) und rechts der Hebel
## mit Lichtspitze. Leere Plätze zeigen die Kontaktleiste. Oben das Segment-Modul.
## Ein BATTERIE-RACK: die Batterie ist ein silberner Einschub mit Lüftungsschlitzen und
## Rändelschrauben, die fünf Fenster in einer schwarzen Leiste in der Mitte. Der Schacht ist
## versenkt (ein Loch der Anzeige, scene_root schneidet es): ein leerer Platz ist ein tiefes
## Fach - Trennwände, Bodenblech mit Lochung, hinten der Stecker, vorn die Ruf-Lampe.

const CELLS := GameRun.ENERGY_CAP_LIMIT
const ACROSS := GameRun.ENERGY_ROW
const ROWS := 10
## Grundriß in eigenen Einheiten: x = Bild-oben, y = Bild-rechts.
const SIZE := Vector2(15.0, 6.2)
const ROW_PITCH := 1.15
const ROW_START := -7.0
## Der Schacht (x = Bild-oben, z = Bild-rechts) und sein Kragen.
const SHAFT_X := Vector2(-7.05, 4.55)
const SHAFT_Z := Vector2(-2.35, 2.85)
const COLLAR := 0.2
const COLLAR_HEIGHT := 0.18
const NUMBER_Z := -2.82
## Die Klinge: Mitte quer, Länge, Dicke; ihre Oberkante, der Rumpf reicht in den Tisch.
const BLADE_Z := 0.25
const BLADE_LENGTH := 5.0
const BLADE_THICK := ROW_PITCH - 0.15
const BLADE_TOP := 0.36
## So tief liegt der Boden des Schachts unter dem Tisch; die Batterie reicht bis dorthin.
const BAY_DEPTH := 0.8
const BLADE_TALL := BLADE_TOP + BAY_DEPTH
## Fußpunkt einer steckenden Klinge.
const BASE_TOP := 0.0
## Fünf Lichtfenster: Breite quer zur Klinge, Länge längs, Teilung, Versatz zur Mitte.
const WINDOW := Vector2(0.36, 0.6)
const WINDOW_PITCH := 0.78
const WINDOW_OFFSET := -0.5
const WINDOW_TOP := BLADE_TOP + 0.046
## Höchster Punkt einer steckenden Klinge (Hebelspitze).
const TOP_LIMIT := 0.45
const TEETH := 26
const TOOTH_PITCH := 0.16
## So hoch steht eine neue Klinge über ihrem Platz: der Kontaktkamm über dem Tisch.
const LIFT := BLADE_TALL - BLADE_TOP + 0.1
const SINK_TIME := 0.35
const ROW_STAGGER := 0.08
## Trage-Bogen einer gekauften Klinge; die letzten SINK_SHARE senkt sie sich ein.
const FLY_TIME := 0.9
const FLY_PEAK := 3.5
const FLY_START_SCALE := 0.6
const SINK_SHARE := 0.3
## Das Segment-Modul am Kopf.
const HEAD_X := Vector2(5.65, 7.35)
const MODULE_Z := 0.1
const MODULE_SIZE := Vector2(1.2, 4.0)
const DIGIT_HEIGHT := 0.95

const CYAN := Color(0.25, 0.86, 0.95)
const AMBER := Color(0.95, 0.62, 0.22)
const TIP_OFF := Color(0.05, 0.06, 0.07)
const LENS := Color(0.03, 0.045, 0.055)
const SILK := Color(0.55, 0.6, 0.57)
const HOLE := Color(0.008, 0.01, 0.014)
const BLADE_BODY := Color(0.05, 0.055, 0.065)
const LACQUER := Color(0.025, 0.027, 0.032)
const GOLD := Color(0.42, 0.3, 0.12)
const KAPTON := Color(0.42, 0.22, 0.05)
const GHOST := Color(0.015, 0.05, 0.06)
const PLATE := Color(0.34, 0.36, 0.4)
const VENT := Color(0.006, 0.007, 0.009)
const BAY_FLOOR := Color(0.12, 0.125, 0.14)
const BAY_WALL := Color(0.06, 0.064, 0.074)
const BAY_HOLE := Color(0.03, 0.032, 0.038)
const CONNECTOR := Color(0.06, 0.062, 0.07)
const LED_OFF := Color(0.05, 0.06, 0.065)
const LIT_SHARE := 0.84
const LIT_BREATH := 0.12
const FLASH_GAIN := 0.6
const FLASH_TIME := 0.35
const SWEEP_TIME := 0.7
const SWEEP_WIDTH := 1.5

## Je Reihe ein eigenes Licht der Fassung (Steck-LED, Ruf-Lampe oder Schachtlicht).
var _row_mats: Array[StandardMaterial3D] = []
var _energy := 0
var _cap := 0
var _blocks: Array[Node3D] = []
var _windows: Array[MeshInstance3D] = []
var _tips: Array[MeshInstance3D] = []
var _contacts: Array[Node3D] = []
var _calls: Array[Node3D] = []
## Laufende Fahrt je Platz (Senken oder Trage-Bogen).
var _rides := {}
var _lens_material: StandardMaterial3D
var _sweep_material: StandardMaterial3D
var _tip_full: StandardMaterial3D
var _tip_part: StandardMaterial3D
var _tip_off: StandardMaterial3D
var _lit_materials := {}
var _flashes := {}
var _number: Label3D
var _time := 0.0
var _sweep := -1.0
var _pulse_tween: Tween

func _ready() -> void:
	_build()
	_apply(false)

## Einziger Eingang: scene_root spiegelt GameRun.energy/energy_cap hierher.
func set_energy(energy: int, cap: int) -> void:
	var new_cap := clampi(cap, 0, CELLS)
	var new_energy := clampi(energy, 0, new_cap)
	for i in range(_energy, new_energy):
		_flashes[i] = 1.0
	var grew := _cap > 0 and new_cap > _cap
	_cap = new_cap
	_energy = new_energy
	if _blocks.is_empty():
		return
	if grew:
		_sweep = 0.0
	_apply(grew)

## Die zuletzt freigegebene Klinge fliegt von from_global (Welt) im Trage-Bogen über ihren
## Platz und senkt sich ein. Sie steckt schon (Endzustand zuerst).
func fly_in(from_global: Vector3) -> void:
	if _cap <= 0 or _blocks.is_empty():
		return
	var row := _row_of(_cap - 1)
	var block := _blocks[row]
	_end_ride(row)
	var rest := _rest(row)
	var over := rest + Vector3.UP * LIFT
	var start := to_local(from_global)
	var tween := block.create_tween()
	_rides[row] = tween
	_calls[row].visible = true
	var fly := func(t: float) -> void:
		var eased := smoothstep(0.0, 1.0, t)
		block.position = start.lerp(over, eased) + Vector3.UP * FLY_PEAK * sin(PI * t)
		block.scale = Vector3.ONE * lerpf(FLY_START_SCALE, 1.0, eased)
	fly.call(0.0)
	tween.tween_method(fly, 0.0, 1.0, FLY_TIME * (1.0 - SINK_SHARE))
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(block, "position", rest, FLY_TIME * SINK_SHARE)
	tween.tween_callback(func() -> void:
		_rides.erase(row)
		_calls[row].visible = false
		pulse())

## Harter Weg einer Fahrt: die Klinge steckt auf ihrem Platz.
func _end_ride(row: int) -> void:
	if _rides.has(row):
		var ride: Tween = _rides[row]
		if ride != null and ride.is_valid():
			ride.kill()
		_rides.erase(row)
	_blocks[row].position = _rest(row)
	_blocks[row].scale = Vector3.ONE
	_calls[row].visible = false

## Ecken des Schachts in Welt (für das Loch der Anzeige).
func shaft_world_corners() -> Array[Vector3]:
	return [to_global(Vector3(SHAFT_X.x, 0.0, SHAFT_Z.x)), to_global(Vector3(SHAFT_X.y, 0.0, SHAFT_Z.y))]

func riding(row: int) -> bool:
	return _rides.has(row)

## Kurzer Pop der Anzeige - eine Energie ist eben eingetroffen.
func pulse() -> void:
	if _number == null:
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_number.scale = Vector3.ONE * 1.2
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_number, "scale", Vector3.ONE, 0.35)

func energy_count() -> int:
	return _energy

func cap_count() -> int:
	return _cap

func number_text() -> String:
	return str(_energy) if _number != null else ""

func cap_text() -> String:
	return "/%d" % _cap if _number != null else ""

## Was das Segment-Modul zeigt ("12/15", auf zwei Stellen je Seite gesetzt).
static func display_text(energy: int, cap: int) -> String:
	return "%2d/%-2d" % [energy, cap]

## Das Lichtfenster der Energie index.
func segment(index: int) -> MeshInstance3D:
	return _windows[index]

## Steckt die Klinge der Energie index (unter dem Deckel)?
func cell_stands(index: int) -> bool:
	return _blocks[_row_of(index)].visible

func sweeping() -> bool:
	return _sweep >= 0.0

## Wie die Hebelspitze einer Reihe leuchtet: "voll", "halb" oder "leer".
func tip_state(row: int) -> String:
	var material := _tips[row].material_override
	if material == _tip_full:
		return "voll"
	return "halb" if material == _tip_part else "leer"

## Steht der Platz einer Reihe leer (Kontaktleiste sichtbar)?
func slot_bare(row: int) -> bool:
	return _contacts[row].visible

## Mitte des Fensters index in eigenen Einheiten: Klinge 0 Bild-unten, Fenster 0 links.
static func cell_spot(index: int) -> Vector3:
	return Vector3(row_x(_row_of(index)), WINDOW_TOP, BLADE_Z + _window_z(index % ACROSS))

static func row_x(row: int) -> float:
	return ROW_START + ROW_PITCH * (float(row) + 0.5)

static func _window_z(k: int) -> float:
	return WINDOW_OFFSET + (float(k) - float(ACROSS - 1) * 0.5) * WINDOW_PITCH

static func _row_of(index: int) -> int:
	@warning_ignore("integer_division")
	return index / ACROSS

static func _rest(row: int) -> Vector3:
	return Vector3(row_x(row), BASE_TOP, BLADE_Z)

func _build() -> void:
	_lens_material = StationParts.lit(LENS)
	_sweep_material = StationParts.lit(CYAN)
	_tip_full = StationParts.lit(CYAN)
	_tip_part = StationParts.lit(AMBER)
	_tip_off = StationParts.lit(TIP_OFF)
	var steel := StationParts.steel(ChipFrameView.STEEL, 0.4)
	var dark_steel := StationParts.steel(ChipFrameView.STEEL_DARK, 0.3)
	var gold := StationParts.steel(GOLD, 0.1, 0.05)
	var center := Vector2((SHAFT_X.x + SHAFT_X.y) * 0.5, (SHAFT_Z.x + SHAFT_Z.y) * 0.5)
	var inner := Vector2(SHAFT_X.y - SHAFT_X.x, SHAFT_Z.y - SHAFT_Z.x)
	# Der versenkte Schacht: dunkle Wände bis auf den Boden, der Boden selbst liegt je Fach.
	StationParts.box(self, "Schachtgrund", Vector3(inner.x, 0.01, inner.y),
		Vector3(center.x, -BAY_DEPTH - 0.01, center.y), StationParts.lit(HOLE))
	StationParts.swarm(self, "Schachtwand", StationParts.frame_boxes(center, inner + Vector2.ONE * 0.04, inner,
		-BAY_DEPTH * 0.5, BAY_DEPTH), StationParts.lit(BAY_WALL))
	StationParts.swarm(self, "Kragen", StationParts.frame_boxes(center,
		inner + Vector2.ONE * COLLAR * 2.0, inner, COLLAR_HEIGHT * 0.5, COLLAR_HEIGHT), steel)
	for row in ROWS:
		var x := row_x(row)
		StationParts.label(self, "Nummer%d" % row, "%02d" % (row + 1),
			Vector3(x, 0.003, NUMBER_Z), 0.3, SILK)
		_row_mats.append(StationParts.lit(LED_OFF))
		_contacts.append(_build_contacts(row, gold, steel))
		_calls.append(_build_call(row))
		_blocks.append(_build_blade(row, steel, dark_steel, gold))
	_dress_rack(steel)
	_dress_bays(steel)
	_build_head(steel)

## Was ein LEERER Platz zeigt: ein tiefes Fach - helleres Bodenblech mit Lochung, hinten der
## Stecker mit Goldkontakten und vorn die Ruf-Lampe, die am nächsten freizuschaltenden Platz
## bernstein leuchtet.
func _build_contacts(row: int, gold: Material, steel: Material) -> Node3D:
	var empty := Node3D.new()
	empty.name = "Leer%d" % row
	add_child(empty)
	var x := row_x(row)
	var lo := SHAFT_Z.x + 0.05
	var hi := SHAFT_Z.y - 0.05
	var y := -BAY_DEPTH
	StationParts.box(empty, "Bodenblech", Vector3(BLADE_THICK, 0.012, hi - lo), Vector3(x, y + 0.006, (lo + hi) * 0.5),
		StationParts.lit(BAY_FLOOR))
	var holes: Array[Transform3D] = []
	for a in 4:
		for b in 16:
			var z := lo + 0.95 + float(b) * 0.22 + (0.11 if a % 2 == 1 else 0.0)
			if z < hi - 0.5:
				holes.append(StationParts.cube(Vector3(0.1, 0.004, 0.1), Vector3(x + (float(a) - 1.5) * 0.2, y + 0.014, z)))
	StationParts.swarm(empty, "Lochung", holes, StationParts.lit(BAY_HOLE))
	StationParts.box(empty, "Stecker", Vector3(0.62, 0.16, 0.16), Vector3(x, y + 0.08, hi - 0.12), StationParts.lit(CONNECTOR))
	var pins: Array[Transform3D] = []
	for j in 8:
		pins.append(StationParts.cube(Vector3(0.05, 0.006, 0.08), Vector3(x + (float(j) - 3.5) * 0.07, y + 0.163, hi - 0.12)))
	StationParts.swarm(empty, "Kontakte", pins, gold)
	StationParts.box(empty, "Ruf", Vector3(0.26, 0.02, 0.26), Vector3(x, y + 0.016, lo + 0.25), _row_mats[row])
	return empty

static func _tooth_z(j: int) -> float:
	return (float(j) - float(TEETH - 1) * 0.5) * TOOTH_PITCH

## Der Ruf um einen Platz, solange eine neue Klinge unterwegs ist.
func _build_call(row: int) -> Node3D:
	var boxes := StationParts.frame_boxes(Vector2(row_x(row), BLADE_Z),
		Vector2(BLADE_THICK + 0.2, BLADE_LENGTH + 0.14), Vector2(BLADE_THICK + 0.1, BLADE_LENGTH + 0.04),
		0.015, 0.01)
	var node := StationParts.swarm(self, "SchachtRuf%d" % row, boxes, StationParts.lit(CYAN))
	node.visible = false
	return node

## Die Batterie eines Platzes: ein silberner Einschub, Rumpf bis tief in den Tisch, oben die
## Stahlplatte mit zwei Reihen Lüftungsschlitzen, in der Mitte die schwarze Leiste mit den fünf
## Fenstern (eine Energie je Fenster), Rändelschrauben in den Ecken, rechts die Statuslampe.
func _build_blade(row: int, steel: Material, dark_steel: Material, gold: Material) -> Node3D:
	var block := Node3D.new()
	block.name = "Block%d" % row
	block.position = _rest(row)
	add_child(block)
	var hx := BLADE_LENGTH * 0.5
	var hw := BLADE_THICK * 0.5
	StationParts.box(block, "Rumpf", Vector3(BLADE_THICK, BLADE_TALL, BLADE_LENGTH),
		Vector3(0, BLADE_TOP - BLADE_TALL * 0.5, 0), StationParts.steel(PLATE, 0.6))
	var strip := _window_z(ACROSS - 1) - _window_z(0) + WINDOW.y + 0.12
	StationParts.box(block, "Fensterleiste", Vector3(WINDOW.x + 0.1, 0.012, strip),
		Vector3(0, BLADE_TOP + 0.006, WINDOW_OFFSET), StationParts.lit(VENT))
	for k in ACROSS:
		_windows.append(StationParts.box(block, "Fenster%d" % k,
			Vector3(WINDOW.x, 0.012, WINDOW.y), Vector3(0, BLADE_TOP + 0.014, _window_z(k)), _lens_material))
	var vents: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for b in 6:
			vents.append(StationParts.cube(Vector3(0.09, 0.004, 0.48),
				Vector3(side * 0.34, BLADE_TOP + 0.002, -1.75 + float(b) * 0.6)))
	StationParts.swarm(block, "Schlitze", vents, StationParts.lit(VENT))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		StationParts.cyl(block, "Schraube", 0.1, 0.05,
			Vector3(corner.x * (hw - 0.14), BLADE_TOP + 0.025, corner.y * (hx - 0.16)), steel, 16)
	StationParts.box(block, "Lampenfassung", Vector3(0.34, 0.012, 0.34), Vector3(0, BLADE_TOP + 0.006, hx - 0.62),
		StationParts.lit(VENT))
	_tips.append(StationParts.box(block, "HebelSpitze", Vector3(0.24, 0.02, 0.24),
		Vector3(0, BLADE_TOP + 0.014, hx - 0.62), _tip_off))
	var teeth: Array[Transform3D] = []
	for j in TEETH:
		teeth.append(StationParts.cube(Vector3(0.18, 0.12, 0.08),
			Vector3(0, BLADE_TOP - BLADE_TALL - 0.06, _tooth_z(j))))
	StationParts.swarm(block, "Kontaktkamm", teeth, gold)
	return block

## Die TRENNWÄNDE zwischen den Plätzen: Stahlbleche vom Schachtboden bis knapp über den Tisch.
func _dress_bays(steel: Material) -> void:
	var rails: Array[Transform3D] = []
	var lo := SHAFT_Z.x + 0.02
	var hi := SHAFT_Z.y - 0.02
	for k in ROWS + 1:
		var x := ROW_START + ROW_PITCH * float(k)
		x = clampf(x, SHAFT_X.x + 0.03, SHAFT_X.y - 0.03)
		rails.append(StationParts.cube(Vector3(0.06, BAY_DEPTH + 0.06, hi - lo),
			Vector3(x, (0.06 - BAY_DEPTH) * 0.5, (lo + hi) * 0.5)))
	StationParts.swarm(self, "Fuehrungsschienen", rails, steel)

## RACK: der Kragen als Rack-Schiene - je Platz zwei Vierkantlöcher links und rechts und
## eine Schraube.
func _dress_rack(steel: Material) -> void:
	var holes: Array[Transform3D] = []
	for row in ROWS:
		var x := row_x(row)
		for z in [SHAFT_Z.x - COLLAR * 0.5, SHAFT_Z.y + COLLAR * 0.5]:
			for d in [-0.3, 0.3]:
				holes.append(StationParts.cube(Vector3(0.12, 0.004, 0.12), Vector3(x + d, COLLAR_HEIGHT + 0.002, z)))
		StationParts.cyl(self, "RackSchraube%d" % row, 0.075, 0.04, Vector3(x, COLLAR_HEIGHT + 0.02, SHAFT_Z.y + COLLAR * 0.5),
			steel, 16)
	StationParts.swarm(self, "RackLoecher", holes, StationParts.lit(VENT))

## Das Segment-Modul auf der Kopfplatte, mit Flachband zum Schacht.
func _build_head(steel: Material) -> void:
	var mid := (HEAD_X.x + HEAD_X.y) * 0.5
	StationParts.box(self, "KopfPlatte", Vector3(HEAD_X.y - HEAD_X.x, 0.24, SIZE.y - 0.3),
		Vector3(mid, 0.12, 0), StationParts.lit(LACQUER))
	StationParts.box(self, "Modul", Vector3(MODULE_SIZE.x, 0.04, MODULE_SIZE.y),
		Vector3(mid, 0.26, MODULE_Z), StationParts.lit(Color(0.01, 0.014, 0.018)))
	for side in [-1.0, 1.0]:
		StationParts.box(self, "Schraube", Vector3(0.14, 0.03, 0.14), Vector3(mid, 0.255, side * 2.65), steel)
	var ribbon := SHAFT_X.y + COLLAR
	StationParts.box(self, "Flachband", Vector3(HEAD_X.x - ribbon, 0.02, 1.2),
		Vector3((ribbon + HEAD_X.x) * 0.5, 0.01, MODULE_Z),
		StationParts.lit(KAPTON))
	# Monospace: die Geister-Segmente "88/88" stehen genau unter der Anzeige.
	StationParts.label(self, "Geist", "88/88", Vector3(mid, 0.283, MODULE_Z), DIGIT_HEIGHT, GHOST)
	_number = StationParts.label(self, "Anzeige", "", Vector3(mid, 0.285, MODULE_Z), DIGIT_HEIGHT, CYAN)
	# Der Umriß in derselben Farbe macht die Striche so kräftig wie Segmente.
	_number.outline_size = 10
	_number.outline_modulate = CYAN * 0.7

func _new_lit_material() -> StandardMaterial3D:
	return StationParts.lit(CYAN * LIT_SHARE)

func _apply(grew: bool) -> void:
	_number.text = display_text(_energy, _cap)
	for row in _blocks.size():
		var stands := row * ACROSS < _cap
		_stand(row, stands, grew)
		_contacts[row].visible = not stands
		var charge := clampi(_energy - row * ACROSS, 0, ACROSS)
		_tips[row].material_override = _tip_full if charge == ACROSS else (
			_tip_part if charge > 0 else _tip_off)
		_row_mats[row].albedo_color = _row_light(row, stands, charge)
	for i in _windows.size():
		if i >= _energy:
			_lit_materials.erase(i)
		_paint(i)
	_sync_process()

## Endzustand zuerst: die Klinge steckt, eine neu freigegebene senkt sich nur dorthin.
func _stand(row: int, stands: bool, grew: bool) -> void:
	var block := _blocks[row]
	var was := block.visible
	block.visible = stands
	if stands and was:
		return  # eine laufende Fahrt bleibt, sonst steht sie ohnehin
	_end_ride(row)
	if not stands or not grew:
		return
	block.position.y = BASE_TOP + LIFT
	_calls[row].visible = true
	var tween := block.create_tween()
	_rides[row] = tween
	tween.tween_interval(ROW_STAGGER * float(row % 5))
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(block, "position:y", BASE_TOP, SINK_TIME)
	tween.tween_callback(func() -> void:
		_rides.erase(row)
		_calls[row].visible = false)

## Das Licht der Fassung je Reihe.
func _row_light(row: int, stands: bool, _charge: int) -> Color:
	@warning_ignore("integer_division")
	return AMBER * 0.85 if not stands and row == _cap / ACROSS else LED_OFF

func _paint(index: int) -> void:
	var window := _windows[index]
	if _sweep >= 0.0 and index < _cap and absf(float(index) - _sweep) < SWEEP_WIDTH:
		window.material_override = _sweep_material
	elif index < _energy:
		if not _lit_materials.has(index):
			_lit_materials[index] = _new_lit_material()
		window.material_override = _lit_materials[index]
	else:
		window.material_override = _lens_material

func _is_full() -> bool:
	return _cap > 0 and _energy >= _cap

func _sync_process() -> void:
	set_process(not _lit_materials.is_empty() or not _flashes.is_empty() or _sweep >= 0.0)

## Jedes geladene Fenster atmet in eigener Phase; neu geladene blitzen kurz, der volle
## Speicher flackert in der Anzeige.
func _process(delta: float) -> void:
	_time += delta
	for i: int in _flashes.keys():
		_flashes[i] = float(_flashes[i]) - delta / FLASH_TIME
		if float(_flashes[i]) <= 0.0:
			_flashes.erase(i)
	for i: int in _lit_materials:
		var breath := 0.5 + 0.5 * sin(_time * 2.6 + float(i) * 2.39) * sin(_time * 1.7 + float(i) * 5.7)
		var flash := float(_flashes.get(i, 0.0))
		var material: StandardMaterial3D = _lit_materials[i]
		material.albedo_color = CYAN * (LIT_SHARE + LIT_BREATH * breath + FLASH_GAIN * flash)
	if _sweep >= 0.0:
		_sweep += delta / SWEEP_TIME * float(_cap)
		if _sweep > float(_cap) + SWEEP_WIDTH:
			_sweep = -1.0
		for i in _cap:
			_paint(i)
	var restless := 0.75 + 0.25 * absf(sin(_time * 7.3) * sin(_time * 3.1)) if _is_full() else 1.0
	_number.modulate = CYAN * restless
	_sync_process()
