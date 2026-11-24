class_name ChipTrayDress
extends Node3D
## Die FASSUNG des Chip-Trays als Schieberegister: ein Stahlrahmen um die unveränderte Grube,
## links je Rinne eine hinterleuchtete WERT-KAPPE in Chipfarbe (an der 10K-Kappe "×n"), die
## TAKT-SCHIENE mit sieben Abgängen (der Weg der Geld-Kometen), am Einlauf je Rinne eine
## Gabel-LICHTSCHRANKE, am Auslauf ein HUBMAGNET mit Statusring, auf dem Steg unter jeder
## Rinne FÜLLMARKEN bei 5/10/15/20, und der ÜBERTRAG als Lichtweg samt Pfeil auf der Schiene
## und Lampe rechts. Ursprung = Mitte der Grube (wie ChipTrayView), x Bild-oben, z Bild-rechts.

const RANKS := 7
const MARKS: Array[int] = [5, 10, 15, 20]
const FRAME_HEIGHT := 0.06
## Breite der offenen Lichtkanäle im Rahmen und der freie Saum an der Unterkante.
const SLOT := 0.12
const EDGE := 0.05
const CAP_HEIGHT := 0.06
const CAP_FILL := 0.82
## Höchster Punkt der Fassung (der Statusring der Hubmagnete).
const REST_TOP := 0.26
const SOLENOID_RADIUS := 0.2
const SOLENOID_INSET := 0.19
const SOLENOID_HEIGHT := 0.16
const LAMP_RADIUS := 0.07
const BEAM_FLASH_TIME := 0.35
const TOP_SHOWN_FROM := TreasureChestView.SLOTS
const MONO_WIDTH := 0.55
## Schrift längs der Kappe: sie läuft Bild-oben, ihre Oberkante zeigt Bild-links.
const SPINE := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
const LIT_MAX := 0.9

const COOL := Color(0.42, 0.78, 0.86)
const AMBER := Color(0.95, 0.62, 0.2)
const REST_WHITE := Color(0.42, 0.44, 0.48)
const MARK_OFF := Color(0.2, 0.21, 0.24)
const CAP_GLASS := Color(0.006, 0.006, 0.009)
const SEAM := Color(0.3, 0.38, 0.46)
const FORK := Color(0.015, 0.015, 0.018)
const COPPER := Color(0.62, 0.32, 0.17)
const LAMP_OFF := Color(0.12, 0.09, 0.04)

var _tray: ChipTrayView
var _rail_z := 0.0
var _built := false
var _key := ""
var _writes := 0
var _light_key := ""
var _counts: Array[int] = [0, 0, 0, 0, 0, 0, 0]
var _gates: Array[bool] = [false, false, false, false, false, false, false]
var _flow := Vector2i(-1, -1)
var _top := 0
var _rims: Array[StandardMaterial3D] = []
var _values: Array[Label3D] = []
var _times: Label3D
var _cap_tall := 0.0
var _rings: Array[MeshInstance3D] = []
var _ring_rest: StandardMaterial3D
var _ring_open: StandardMaterial3D
var _ring_flash: Array[StandardMaterial3D] = []
var _beams: Array[StandardMaterial3D] = []
var _beam_flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _marks: Array = []
var _mark_on: Array[StandardMaterial3D] = []
var _mark_off: StandardMaterial3D
var _mark_full: StandardMaterial3D
var _mark_rest_cap: StandardMaterial3D
var _paths: Array[Node3D] = []
var _arrows: Array[MeshInstance3D] = []
var _lamps: Array[MeshInstance3D] = []
var _lamp_on: StandardMaterial3D
var _lamp_off: StandardMaterial3D

## frame: der Stationsrahmen in lokalen Koordinaten (position/size = x Bild-oben, y = z Bild-
## rechts), rail_z: die Takt-Schiene. Der Körper steht genau über dem Tray.
func setup(tray: ChipTrayView, frame: Rect2, rail_z: float) -> void:
	_tray = tray
	global_position = tray.global_position
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rims.clear()
	_values.clear()
	_rings.clear()
	_ring_flash.clear()
	_beams.clear()
	_marks.clear()
	_mark_on.clear()
	_paths.clear()
	_arrows.clear()
	_lamps.clear()
	var half := tray.half_extents()
	_rail_z = rail_z
	_build_frame(half, frame)
	_build_caps(frame, rail_z)
	_build_rail(half, rail_z)
	_build_forks()
	_build_solenoids(half, frame)
	_build_marks()
	_built = true
	_key = ""
	_light_key = ""
	_write()
	set_lights(0.0, [], [])

## Der EINE Schreiber des Zustands: Füllmarken, Sperren, Übertrag, ×n - nur der Wechsel.
func set_state(counts: Array[int], gates: Array[bool], flow: Vector2i, top: int) -> void:
	var key := "%s|%s|%s|%d" % [str(counts), str(gates), str(flow), top]
	if key == _key:
		return
	_key = key
	_counts = counts.duplicate()
	_gates = gates.duplicate()
	_flow = flow
	_top = top
	_write()

## Die Blitze (aus der Fassung im Display): Gewinn auf alle Kappen, Einlauf auf eine Kappe,
## Auslauf auf einen Statusring. Nur der Wechsel schreibt.
func set_lights(glint: float, entry: Array, exit: Array) -> void:
	var key := "%.3f|%s|%s" % [glint, str(entry), str(exit)]
	if key == _light_key or not _built:
		return
	_light_key = key
	for r in RANKS:
		var hit := clampf(glint + (float(entry[r]) if r < entry.size() else 0.0), 0.0, 1.0)
		var base := chip_light(r)
		_rims[r].albedo_color = base * lerpf(0.75, 1.15, hit)
		_values[r].modulate = base.lerp(Color(1.0, 1.0, 1.0), hit * 0.4)
		var out := float(exit[r]) if r < exit.size() else 0.0
		_ring_flash[r].albedo_color = chip_light(r) * (0.6 + 0.6 * out)
		_paint_ring(r, out)

## Ein Chip ist eingelaufen: der Strahl seiner Lichtschranke blitzt.
func flash_beam(rank: int) -> void:
	if rank < 0 or rank >= RANKS:
		return
	_beam_flash[rank] = 1.0
	_paint_beam(rank)
	set_process(true)

## Der harte Weg: keine Blitze, der Zustand bleibt.
func settle_hard() -> void:
	for r in RANKS:
		_beam_flash[r] = 0.0
		if _built:
			_paint_beam(r)
	set_process(false)
	_light_key = ""
	set_lights(0.0, [], [])

func writes() -> int:
	return _writes

## Wie viele Füllmarken einer Rinne leuchten (in Chipfarbe oder voll).
func marks_lit(rank: int) -> int:
	var count := 0
	for mark: MeshInstance3D in _marks[rank]:
		if mark.material_override != _mark_off and mark.material_override != _mark_rest_cap:
			count += 1
	return count

func mark_full(rank: int) -> bool:
	return (_marks[rank][MARKS.size() - 1] as MeshInstance3D).material_override == _mark_full

## Die Schienen-Stücke r -> r + 1, auf denen der Übertrag gerade leuchtet.
func path_shown() -> Array[int]:
	var out: Array[int] = []
	for i in _paths.size():
		if _paths[i].visible:
			out.append(i)
	return out

func arrow_up(pair: int) -> bool:
	return _arrows[pair].basis.y.x > 0.0

func lamp_lit(pair: int) -> bool:
	return _lamps[pair].material_override == _lamp_on

func ring_open(rank: int) -> bool:
	return _rings[rank].material_override == _ring_open

func value_text(rank: int) -> String:
	return _values[rank].text

func times_text() -> String:
	return _times.text if _times.visible else ""

## Die Farbe einer Rinne als Eigenlicht unter der Bloom-Schwelle.
static func chip_light(rank: int) -> Color:
	var color := ChipStackView.denomination_color(ChipTrayView.VALUES[rank])
	var peak := maxf(maxf(color.r, color.g), maxf(color.b, 0.001))
	return Color(color.r, color.g, color.b) * (LIT_MAX / peak)

# --- Bau ----------------------------------------------------------------------------------

func _build_frame(half: Vector2, frame: Rect2) -> void:
	var x0 := frame.position.x
	var x1 := frame.end.x
	var z0 := frame.position.y
	var z1 := frame.end.y
	var low := x0 + EDGE
	var exit_z := (half.y + z1) * 0.5
	# Zwei Lichtkanäle bleiben offen: die Takt-Schiene und der Rücklauf am Auslauf - dort
	# laufen die Geld-Kometen der Anzeige.
	var plates: Array[Transform3D] = [
		_plate(half.x, x1, z0, z1),
		_plate(low, half.x, z0, _rail_z - SLOT * 0.5),
		_plate(low, half.x, _rail_z + SLOT * 0.5, -half.y),
		_plate(low, -half.x, -half.y, exit_z - SLOT * 0.5),
		_plate(low, half.x, half.y, exit_z - SLOT * 0.5),
		_plate(low, half.x, exit_z + SLOT * 0.5, z1),
	]
	StationParts.swarm(self, "Rahmen", plates, StationParts.steel(ChipFrameView.STEEL_DARK, 0.4))
	StationParts.swarm(self, "Innensaum", StationParts.frame_boxes(Vector2.ZERO,
		half * 2.0 + Vector2.ONE * 0.05, half * 2.0, FRAME_HEIGHT + 0.002, 0.004), StationParts.lit(SEAM))
	var lips: Array[Transform3D] = []
	for z: float in [_rail_z, exit_z]:
		for side in [-1.0, 1.0]:
			lips.append(StationParts.cube(Vector3(half.x - low, 0.004, 0.014),
				Vector3((low + half.x) * 0.5, FRAME_HEIGHT + 0.002, z + side * (SLOT * 0.5 - 0.007))))
	StationParts.swarm(self, "Kanalsaum", lips, StationParts.lit(COOL * 0.6))

## Eine Rahmenplatte über x a..b (Bild-oben) und z c..d (Bild-rechts).
static func _plate(a: float, b: float, c: float, d: float) -> Transform3D:
	return StationParts.cube(Vector3(absf(b - a), FRAME_HEIGHT, absf(d - c)),
		Vector3((a + b) * 0.5, FRAME_HEIGHT * 0.5, (c + d) * 0.5))

func _build_caps(frame: Rect2, rail_z: float) -> void:
	var z0 := frame.position.y + 0.05
	var z1 := rail_z - SLOT * 0.5 - 0.03
	var width := z1 - z0
	var cz := (z0 + z1) * 0.5
	var tall := _tray.groove_pitch() * CAP_FILL
	var steel := StationParts.steel(ChipFrameView.STEEL, 0.4)
	var bodies: Array[Transform3D] = []
	var glass: Array[Transform3D] = []
	var top := FRAME_HEIGHT + CAP_HEIGHT
	for r in RANKS:
		var x := _tray.rank_x(r)
		bodies.append(StationParts.cube(Vector3(tall, CAP_HEIGHT, width), Vector3(x, FRAME_HEIGHT + CAP_HEIGHT * 0.5, cz)))
		glass.append(StationParts.cube(Vector3(tall - 0.1, 0.006, width - 0.08), Vector3(x, top + 0.003, cz)))
		var rim := StationParts.lit(chip_light(r) * 0.75)
		_rims.append(rim)
		StationParts.swarm(self, "KappenSaum%d" % r, StationParts.frame_boxes(Vector2(x, cz),
			Vector2(tall - 0.1, width - 0.08), Vector2(tall - 0.15, width - 0.13), top + 0.008, 0.004), rim)
		# Die Kopfspalte ist schmal: der Wert läuft längs der Kappe, von unten nach oben.
		var text := ChipStackView.value_label(ChipTrayView.VALUES[r])
		var label := StationParts.label(self, "Wert%d" % r, text, Vector3(x, top + 0.012, cz),
			minf(width * 0.78, (tall - 0.3) / (float(text.length()) * MONO_WIDTH)), chip_light(r))
		label.basis = SPINE
		label.outline_size = 6
		label.outline_modulate = chip_light(r) * 0.5
		_values.append(label)
	StationParts.swarm(self, "Kappen", bodies, steel)
	StationParts.swarm(self, "KappenGlas", glass, StationParts.lit(CAP_GLASS))
	_cap_tall = tall
	_times = StationParts.label(self, "Mal", "", Vector3(_tray.rank_x(ChipTrayView.TOP) - tall * 0.27,
		top + 0.012, cz), width * 0.62, Color(0.9, 0.9, 0.92))
	_times.basis = SPINE

func _build_rail(half: Vector2, rail_z: float) -> void:
	var y := FRAME_HEIGHT + 0.004
	# Die Schiene selbst ist der offene Kanal; von ihm gehen die sieben Abgänge zur Rinne.
	var lines: Array[Transform3D] = []
	var from := rail_z + SLOT * 0.5
	for r in RANKS:
		var x := _tray.rank_x(r)
		lines.append(StationParts.cube(Vector3(0.03, 0.006, -half.y - from), Vector3(x, y, (from - half.y) * 0.5)))
		lines.append(StationParts.cube(Vector3(0.07, 0.008, 0.05), Vector3(x, y + 0.001, from + 0.025)))
	StationParts.swarm(self, "Takt", lines, StationParts.lit(COOL * 0.7))
	var amber := StationParts.lit(AMBER)
	for pair in RANKS - 1:
		var a := _tray.rank_x(pair)
		var b := _tray.rank_x(pair + 1)
		var path := StationParts.box(self, "UebertragWeg%d" % pair, Vector3(b - a, 0.008, 0.07),
			Vector3((a + b) * 0.5, y + 0.004, rail_z), amber)
		path.visible = false
		_paths.append(path)
		var prism := PrismMesh.new()
		prism.size = Vector3(0.16, 0.18, 0.01)
		var arrow := MeshInstance3D.new()
		arrow.name = "UebertragPfeil"
		arrow.mesh = prism
		arrow.material_override = amber
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arrow.transform = Transform3D(StationParts.FLAT, Vector3((a + b) * 0.5, y + 0.012, rail_z))
		path.add_child(arrow)
		arrow.position = Vector3(0, 0.008, 0)
		_arrows.append(arrow)

## Die Gabel-Lichtschranke steht am Einlauf über der Rinne; ihr Strahl kreuzt sie.
func _build_forks() -> void:
	var posts: Array[Transform3D] = []
	var bars: Array[Transform3D] = []
	var span := ChipTrayView.TROUGH_R * 2.0
	for r in RANKS:
		var at := _tray.to_local(_tray.entry_point(r))
		var steg := at.y + ChipTrayView.TROUGH_R - ChipTrayView.R
		var tall := 0.1 - steg
		for side in [-1.0, 1.0]:
			posts.append(StationParts.cube(Vector3(0.08, tall, 0.06),
				Vector3(at.x + side * (ChipTrayView.TROUGH_R + 0.04), steg + tall * 0.5, at.z)))
		bars.append(StationParts.cube(Vector3(span + 0.16, 0.03, 0.04), Vector3(at.x, 0.105, at.z - 0.05)))
		var beam := StationParts.lit(REST_WHITE)
		_beams.append(beam)
		StationParts.box(self, "Strahl%d" % r, Vector3(span, 0.012, 0.016), Vector3(at.x, 0.07, at.z), beam)
	var fork := StationParts.lit(FORK)
	StationParts.swarm(self, "Gabeln", posts, fork)
	StationParts.swarm(self, "GabelBruecken", bars, fork)

func _build_solenoids(half: Vector2, frame: Rect2) -> void:
	# Über der Sperre, an der Grubenkante; der Rücklauf-Kanal daneben bleibt frei.
	var z := half.y - SOLENOID_INSET
	var outer := (half.y + frame.end.y) * 0.5 - SLOT * 0.5 - 0.03
	var copper := StationParts.steel(COPPER, 0.2)
	var steel := StationParts.steel(ChipFrameView.STEEL, 0.4)
	_ring_rest = StationParts.lit(REST_WHITE)
	_ring_open = StationParts.lit(AMBER)
	_lamp_on = StationParts.lit(AMBER)
	_lamp_off = StationParts.lit(LAMP_OFF)
	var arms: Array[Transform3D] = []
	for r in RANKS:
		var x := _tray.rank_x(r)
		StationParts.cyl(self, "Spule%d" % r, SOLENOID_RADIUS, SOLENOID_HEIGHT,
			Vector3(x, FRAME_HEIGHT + SOLENOID_HEIGHT * 0.5, z), copper, 28)
		StationParts.cyl(self, "SpulenKappe%d" % r, SOLENOID_RADIUS * 0.82, 0.02,
			Vector3(x, FRAME_HEIGHT + SOLENOID_HEIGHT + 0.01, z), steel, 28)
		_rings.append(StationParts.ring(self, "Status%d" % r, SOLENOID_RADIUS * 0.55, 0.05,
			Vector3(x, FRAME_HEIGHT + SOLENOID_HEIGHT + 0.024, z), _ring_rest))
		_ring_flash.append(StationParts.lit(chip_light(r)))
		arms.append(StationParts.cube(Vector3(0.08, 0.02, outer + 0.03 - z), Vector3(x, FRAME_HEIGHT + 0.01,
			(z + outer + 0.03) * 0.5)))
	StationParts.swarm(self, "Arme", arms, steel)
	var arrow_mesh := PrismMesh.new()
	arrow_mesh.size = Vector3(0.1, 0.1, 0.01)
	for pair in RANKS - 1:
		var x := (_tray.rank_x(pair) + _tray.rank_x(pair + 1)) * 0.5
		StationParts.cyl(self, "LampenSockel%d" % pair, LAMP_RADIUS, 0.03, Vector3(x, FRAME_HEIGHT + 0.015, z),
			StationParts.lit(FORK), 20)
		var lamp := MeshInstance3D.new()
		lamp.name = "Lampe%d" % pair
		lamp.mesh = arrow_mesh
		lamp.material_override = _lamp_off
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.transform = Transform3D(StationParts.FLAT, Vector3(x, FRAME_HEIGHT + 0.034, z))
		add_child(lamp)
		_lamps.append(lamp)

## Je Rinne vier Marken auf dem Steg darunter, geneigt wie er.
func _build_marks() -> void:
	_mark_off = StationParts.lit(MARK_OFF)
	_mark_full = StationParts.lit(AMBER)
	_mark_rest_cap = StationParts.lit(REST_WHITE)
	var tilt := Basis(Vector3.RIGHT, ChipTrayView.TILT)
	var steg := maxf(_tray.groove_pitch() - ChipTrayView.TROUGH_R * 2.0, 0.06) * 0.8
	for r in RANKS:
		_mark_on.append(StationParts.lit(chip_light(r)))
		var row: Array = []
		for m in MARKS:
			var at := _tray.mark_point(r, m)
			var mark := StationParts.box(self, "Marke%d_%d" % [r, m],
				Vector3(steg, 0.01, 0.1 if m == ChipTrayView.CAP else 0.05), Vector3.ZERO, _mark_off)
			mark.transform = Transform3D(tilt, at + tilt.y * 0.006)
			row.append(mark)
		_marks.append(row)

# --- Zustand ------------------------------------------------------------------------------

func _write() -> void:
	if not _built:
		return
	_writes += 1
	for r in RANKS:
		var count: int = _counts[r] if r < _counts.size() else 0
		var row: Array = _marks[r]
		for i in MARKS.size():
			var mark: MeshInstance3D = row[i]
			var reached := count >= MARKS[i]
			if MARKS[i] == ChipTrayView.CAP:
				mark.material_override = _mark_full if reached else _mark_rest_cap
			else:
				mark.material_override = _mark_on[r] if reached else _mark_off
		_paint_ring(r, 0.0)
	var low := mini(_flow.x, _flow.y)
	var high := maxi(_flow.x, _flow.y)
	for pair in _paths.size():
		var on := _flow.x >= 0 and pair >= low and pair < high
		_paths[pair].visible = on
		_lamps[pair].material_override = _lamp_on if on else _lamp_off
		var up := _flow.y > _flow.x
		var basis := StationParts.FLAT if up else Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))
		_arrows[pair].basis = basis
		_lamps[pair].basis = basis
	var many := _top > TOP_SHOWN_FROM
	_times.text = "×%d" % _top if many else ""
	_times.visible = many
	# Steht das ×n auf der 10K-Kappe, rückt ihr Wert nach oben.
	_values[ChipTrayView.TOP].position.x = _tray.rank_x(ChipTrayView.TOP) + (_cap_tall * 0.2 if many else 0.0)

func _paint_ring(rank: int, flash: float) -> void:
	var open: bool = _gates[rank] if rank < _gates.size() else false
	if flash > 0.01:
		_rings[rank].material_override = _ring_flash[rank]
	else:
		_rings[rank].material_override = _ring_open if open else _ring_rest

func _paint_beam(rank: int) -> void:
	var t := _beam_flash[rank]
	_beams[rank].albedo_color = REST_WHITE.lerp(AMBER, t)

func _process(delta: float) -> void:
	var any := false
	for r in RANKS:
		if _beam_flash[r] <= 0.0:
			continue
		_beam_flash[r] = maxf(_beam_flash[r] - delta / BEAM_FLASH_TIME, 0.0)
		_paint_beam(r)
		any = any or _beam_flash[r] > 0.0
	set_process(any)
