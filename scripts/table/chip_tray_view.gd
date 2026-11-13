class_name ChipTrayView
extends Node3D
## Das CHIP-TRAY: eine Grube mit EINER geneigten, runden Rinne je Stückelung, die
## Chips stehen HOCHKANT darin wie in einem echten Tray. Die Belegung ist eine Funktion des Geldes
## (belegung, ein Abakus) - jede Geldänderung fährt als Schrittliste (transition):
## alles kommt LINKS herein, alles geht RECHTS durch Sperre und Wandschlitz in den
## Tisch. Die Rutsch-Physik ist eindimensional und gefühlt, kein Jolt.

## Ein Chip ist links eingelaufen (Komet oder Lift) bzw. rechts im Tisch verschwunden.
signal chip_entered(rank: int)
signal chip_left(rank: int, paid: bool)

## Rinne 0 liegt UNTEN (zum Betrachter, Welt -X), die 10.000er oben.
const VALUES: Array[int] = [1, 5, 25, 100, 500, 2500, 10000]
## Wie viele Chips einer Rinne einen der nächsten ergeben.
const RATIOS: Array[int] = [5, 5, 4, 5, 5, 4]
const TOP := 6
## So voll wird eine Rinne, bevor getauscht wird (die 10.000er kennen keine Grenze).
const CAP := 20
## So viele Chips zeigt eine Rinne höchstens - Luft über CAP für den Augenblick vor
## dem Übertrag; mehr 10.000er stehen als ×n am Kopf.
const TOP_SHOWN := 28

const STEP_IN := "in"
const STEP_OUT := "out"
const STEP_CARRY := "carry"
const STEP_BORROW := "borrow"

const R := ChipStackView.CHIP_RADIUS
const H := ChipStackView.CHIP_HEIGHT
## Neigung des Rinnenbodens (6°), rechts (Welt +Z) tiefer.
const TILT := 0.10472
## Teilung der hochkanten Chips längs der Rinne: eine Chipdicke plus Luft.
const PITCH := H + 0.02
## Die linke Chip-Oberkante liegt so tief unter der Fläche (unter dem Kragen).
const TOP_CLEAR := 0.1
## Luft zwischen Chip-Rand und runder Rinne.
const GAP := 0.04
const TROUGH_R := R + GAP
## Einlauf: Mitte des ersten Platzes, eine Kragenbreite von der Wand.
const ENTRY_S := PackPitView.RIM_IN + H + 0.1
const GATE_T := 0.12
## Der hochkante Chip lehnt mit der Rinne nach rechts - sein Rand braucht die Luft.
const GATE_AIR := 0.03 + R * 0.1046
const GATE_H := R * 1.1
const GATE_TIME := 0.12
const FLOOR_T := 0.12
## Hinter der Sperre: so weit rutscht ein Chip, bis er verschwindet.
const EXIT_RUN := R * 2.0 + 0.4
const POCKET_LEN := EXIT_RUN + 1.2
const DEPTH := 3.6
## Der Schlitz der rechten Wand (Tiefe von Ober- und Unterkante).
const SLOT_TOP := 0.85
## Ein Chip steigt aus dem Rinnenboden.
const LIFT_TIME := 0.18
const LIFT_DROP := R * 2.0 + 0.1
const POP_TIME := 0.12

## Die Rutsch-Physik (Welt/s²): Hangabtrieb minus Reibung, gefühlt.
const SLIDE_ACCEL := 38.0
const V_IN := 3.0
const V_LIFT := 1.5
const RESTITUTION := 0.22
const BOUNCE_V := 1.6
const NUDGE := 0.05
const NUDGE_DECAY := 16.0
## Zwischen zwei Einläufen derselben Rinne, und wie lange ein Einlauf höchstens auf
## seinen Kometen wartet.
const IN_GAP := 0.07
const COMET_WAIT_MAX := 3.0
## So viele Einläufe eines Schritts kommen höchstens als Komet.
const COMET_CAP := 5
const OUT_HOLD := 0.22
## Mehr Schritte stehen nie an - sonst springt das Tray ans Ende.
const OPS_CAP := 120

var wall_skin: Texture2D = null

var _half := Vector2.ZERO
var _pitch_x := 0.0
var _length := 0.0
var _built := false

## Endzustand (gebucht) und der Stand, den die Zeremonie gerade fährt.
var _target: Array[int] = [0, 0, 0, 0, 0, 0, 0]
var _live: Array[int] = [0, 0, 0, 0, 0, 0, 0]
## Je Rinne die liegenden Körper, vorderster (an der Sperre) zuerst.
var _rows: Array = [[], [], [], [], [], [], []]
var _leaving: Array = []
var _ops: Array = []
var _landed: Array[int] = [0, 0, 0, 0, 0, 0, 0]
var _nudge: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _gate_t: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _gate_open: Array[bool] = [false, false, false, false, false, false, false]
var _gate_nodes: Array[Node3D] = []
var _lift_nodes: Array[Node3D] = []
var _bodies_root: Node3D
var _pit: PackPitView

# --- Die Leiter (rein statisch) ----------------------------------------------

## Die kanonische Belegung eines Betrags: von UNTEN gefüllt, jede Rinne so voll wie
## möglich bis CAP - erst was darüber hinausgeht, ist getauscht.
static func belegung(money: int) -> Array[int]:
	var counts: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	var units := maxi(money, 0)
	for r in TOP:
		var k := ratio(r)
		var residue := units % k
		@warning_ignore("integer_division")
		counts[r] = residue + k * ((mini(CAP, units) - residue) / k)
		@warning_ignore("integer_division")
		units = (units - counts[r]) / k
	counts[TOP] = units
	return counts

static func total(counts: Array[int]) -> int:
	var sum := 0
	for r in mini(counts.size(), VALUES.size()):
		sum += counts[r] * VALUES[r]
	return sum

## Die Rinne einer Stückelung (-1 = keine).
static func rank_of(value: int) -> int:
	return VALUES.find(value)

static func ratio(rank: int) -> int:
	return RATIOS[rank] if rank < TOP else 0

## Ein Schritt auf eine Belegung angewandt.
static func apply_step(counts: Array[int], step: Dictionary) -> Array[int]:
	var out: Array[int] = counts.duplicate()
	var r: int = int(step.get("rank", 0))
	match String(step.get("kind", "")):
		STEP_IN:
			out[r] += int(step["count"])
		STEP_OUT:
			out[r] -= int(step["count"])
		STEP_CARRY:
			out[r] -= ratio(r)
			out[r + 1] += 1
		STEP_BORROW:
			var to: int = int(step["to"])
			out[r] -= 1
			for j in range(to + 1, r):
				out[j] += ratio(j) - 1
			out[to] += ratio(to)
	return out

## Der Übergang zweier Belegungen als Schrittliste, Rinne für Rinne von unten: es
## läuft so viel ein bzw. geht so viel als Zahlung, wie die Rinne zu ihrem Ziel
## braucht; was dann noch fehlt oder übersteht, trägt über oder wird geborgt.
static func transition(old: Array[int], new: Array[int], comet := true) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var counts: Array[int] = old.duplicate()
	var delta := total(new) - total(old)
	if delta == 0 and counts == new:
		return steps
	var gain := delta >= 0
	var rest := absi(delta)
	for r in VALUES.size():
		@warning_ignore("integer_division")
		var units := rest / VALUES[r]
		var k := units
		if r < TOP:
			var q := ratio(r)
			if gain:
				k = posmod(new[r] - counts[r], q)
				@warning_ignore("integer_division")
				k += q * maxi(0, mini((new[r] - counts[r] - k) / q, (units - k) / q))
			else:
				k = posmod(counts[r] - new[r], q)
				while counts[r] < k:
					if not _borrow_into(counts, steps, r):
						break
				@warning_ignore("integer_division")
				k += q * maxi(0, mini(mini((counts[r] - new[r] - k) / q, (units - k) / q),
					(counts[r] - k) / q))
		if k > 0:
			if gain:
				steps.append({"kind": STEP_IN, "rank": r, "count": k, "comet": comet})
			else:
				steps.append({"kind": STEP_OUT, "rank": r, "count": k, "pay": true})
			counts = apply_step(counts, steps.back())
			rest -= k * VALUES[r]
		if r == TOP:
			break
		while counts[r] > new[r]:
			steps.append({"kind": STEP_CARRY, "rank": r})
			counts = apply_step(counts, steps.back())
		while counts[r] < new[r]:
			if not _borrow_into(counts, steps, r):
				break
	return steps

## Borgt EINEN Chip der nächsten belegten Rinne darüber in Rinne r hinunter.
static func _borrow_into(counts: Array[int], steps: Array[Dictionary], r: int) -> bool:
	var from := r + 1
	while from <= TOP and counts[from] == 0:
		from += 1
	if from > TOP:
		return false
	steps.append({"kind": STEP_BORROW, "rank": from, "to": r})
	var out := apply_step(counts, steps.back())
	for j in counts.size():
		counts[j] = out[j]
	return true

static func fold(counts: Array[int], steps: Array) -> Array[int]:
	var out: Array[int] = counts.duplicate()
	for step: Dictionary in steps:
		out = apply_step(out, step)
	return out

# --- Aufbau ------------------------------------------------------------------

## Mitte der Grube auf dem Glas, halbe Ausdehnung in Welt-X (Rinnen) und Welt-Z
## (Länge). Baut alles neu; die Belegung bleibt.
func setup(at: Vector3, half_extents: Vector2) -> void:
	global_position = at
	_half = half_extents
	_pitch_x = _half.x * 2.0 / float(VALUES.size())
	_length = _half.y * 2.0 / cos(TILT)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_gate_nodes.clear()
	_lift_nodes.clear()
	_build_pit()
	_build_grooves()
	_bodies_root = Node3D.new()
	_bodies_root.name = "Chips"
	add_child(_bodies_root)
	_built = true
	seat_hard(_target)

func _build_pit() -> void:
	_pit = PackPitView.new("TrayPit")
	_pit.wall_skin = wall_skin
	_pit.slot_walls = [PackPitView.WALL_Z_PLUS] as Array[int]
	_pit.slot = Vector2(SLOT_TOP, DEPTH - 0.05)
	add_child(_pit)
	_pit.setup(global_position, _half, DEPTH)
	# Hinter dem Schlitz ein geschlossener Kasten unter der Anzeige.
	var lining: Shader = load("res://assets/shaders/pit_lining.gdshader")
	var rect := Rect2(Vector2(global_position.x, global_position.z) - _half, _half * 2.0)
	var wall_mat := ShaderMaterial.new()
	wall_mat.shader = lining
	PackPitView.tune_lining(wall_mat, 0.0, PackPitView.WALL_ALBEDO,
		PackPitView.WALL_FIELD_ENERGY, rect, global_position.y, DEPTH,
		PackPitView.GLOW_COLOR, wall_skin)
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = lining
	PackPitView.tune_lining(floor_mat, 1.0, PackPitView.FLOOR_ALBEDO,
		PackPitView.FLOOR_FIELD_ENERGY, rect, global_position.y, DEPTH,
		PackPitView.GLOW_COLOR, null)
	var pocket := Node3D.new()
	pocket.name = "Tasche"
	add_child(pocket)
	var w := PackPitView.WALL
	var top := -PackPitView.WALL_SINK
	var z0 := _half.y + w
	var mid_z := z0 + POCKET_LEN * 0.5
	var span_x := _half.x * 2.0 + w * 2.0
	TableProps.box(pocket, "Decke", Vector3(span_x, w, POCKET_LEN),
		Vector3(0.0, top - w * 0.5, mid_z), wall_mat)
	TableProps.box(pocket, "Boden", Vector3(span_x, w, POCKET_LEN),
		Vector3(0.0, top - DEPTH - w * 0.5, mid_z), floor_mat)
	TableProps.box(pocket, "Rueckwand", Vector3(span_x, DEPTH, w),
		Vector3(0.0, top - DEPTH * 0.5, z0 + POCKET_LEN + w * 0.5), wall_mat)
	for side: float in [-1.0, 1.0]:
		TableProps.box(pocket, "Flanke", Vector3(w, DEPTH, POCKET_LEN),
			Vector3(side * (_half.x + w * 0.5), top - DEPTH * 0.5, mid_z), wall_mat)

func _build_grooves() -> void:
	var lining: Shader = load("res://assets/shaders/pit_lining.gdshader")
	var rect := Rect2(Vector2(global_position.x, global_position.z) - _half, _half * 2.0)
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = lining
	PackPitView.tune_lining(floor_mat, 1.0, PackPitView.FLOOR_ALBEDO,
		PackPitView.FLOOR_FIELD_ENERGY, rect, global_position.y, DEPTH,
		PackPitView.GLOW_COLOR, null)
	var steg_mat := TableProps.metal(PackPitView.RIM_ALBEDO, PackPitView.RIM_EMISSION, 0.55)
	var gate_mat := TableProps.metal(Color(0.30, 0.25, 0.12), Color(1.0, 0.78, 0.35), 0.8)
	var basis := Basis(Vector3.RIGHT, TILT)
	var normal := basis.y
	var run_end := _length + POCKET_LEN
	var grooves := Node3D.new()
	grooves.name = "Rinnen"
	add_child(grooves)
	# Die Rinne ist ein umgestülpter Zylinder: von oben sieht man nur seine untere Hälfte.
	var trough := CylinderMesh.new()
	trough.top_radius = TROUGH_R
	trough.bottom_radius = TROUGH_R
	trough.height = run_end
	trough.radial_segments = 40
	trough.rings = 1
	trough.cap_top = false
	trough.cap_bottom = false
	trough.flip_faces = true
	var along := basis * Basis(Vector3.RIGHT, PI * 0.5)
	var steg_w := maxf(_pitch_x - TROUGH_R * 2.0 + 0.04, 0.06)
	var steg_h := TROUGH_R + FLOOR_T
	for r in VALUES.size():
		var x := rank_x(r)
		var groove := MeshInstance3D.new()
		groove.name = "Rinne%d" % r
		groove.mesh = trough
		groove.material_override = floor_mat
		groove.transform = Transform3D(along,
			_floor_point(x, run_end * 0.5) + normal * TROUGH_R)
		grooves.add_child(groove)
		var gate := TableProps.box(grooves, "Sperre%d" % r,
			Vector3(R * 2.0, GATE_H, GATE_T),
			_floor_point(x, gate_s() + GATE_T * 0.5) + normal * (GATE_H * 0.5), gate_mat)
		gate.basis = basis
		gate.set_meta("base", gate.position)
		_gate_nodes.append(gate)
	# Stege bis zur Achshöhe zwischen und neben den Rinnen - die Chips ragen darüber.
	for k in VALUES.size() + 1:
		var bx := -_half.x + _pitch_x * float(k)
		var steg := TableProps.box(grooves, "Steg%d" % k,
			Vector3(steg_w, steg_h, run_end),
			_floor_point(bx, run_end * 0.5) + normal * (TROUGH_R - steg_h * 0.5), steg_mat)
		steg.basis = basis

# --- Geometrie -----------------------------------------------------------------

func rank_x(rank: int) -> float:
	return -_half.x + _pitch_x * (float(rank) + 0.5)

## Vorderkante der Sperre längs der Rinne.
func gate_s() -> float:
	return _length - GATE_T - GATE_AIR

func slot_s(index: int) -> float:
	return gate_s() - H * 0.5 - float(index) * PITCH

func exit_s() -> float:
	return _length + EXIT_RUN

## Der tiefste Punkt der Rinne (lokal) an der Rinnen-Länge s.
func _floor_point(x: float, s: float) -> Vector3:
	return Vector3(x, -(TOP_CLEAR + R * 2.0) - s * sin(TILT), -_half.y + s * cos(TILT))

## Die Mitte des hochkanten Chips (lokal) an s.
func _chip_point(rank: int, s: float) -> Vector3:
	var normal := Basis(Vector3.RIGHT, TILT).y
	return _floor_point(rank_x(rank), s) + normal * R

## Die Mitte des i-ten Chips einer Rinne, in Welt.
func groove_point(rank: int, index: int) -> Vector3:
	return to_global(_chip_point(rank, slot_s(index)))

## Wo ein Chip links erscheint bzw. rechts in den Tisch geht, in Welt.
func entry_point(rank: int) -> Vector3:
	return to_global(_chip_point(rank, ENTRY_S))

func exit_point(rank: int) -> Vector3:
	return to_global(_chip_point(rank, _length))

func half_extents() -> Vector2:
	return _half

# --- Zustand -------------------------------------------------------------------

func target_counts() -> Array[int]:
	return _target.duplicate()

## Wie viele Körper je Rinne gerade liegen (ohne die abgehenden).
func body_counts() -> Array[int]:
	var out: Array[int] = []
	for r in VALUES.size():
		out.append((_rows[r] as Array).size())
	return out

func busy() -> bool:
	if not _ops.is_empty() or not _leaving.is_empty():
		return true
	for r in VALUES.size():
		if _gate_t[r] > 0.0:
			return true
		for body: Dictionary in _rows[r]:
			if _moving(body):
				return true
	return false

## Wie viele Körper eine Rinne höchstens zeigt.
static func shown_cap(_rank: int) -> int:
	return TOP_SHOWN

## Der EINE harte Schreiber: jeder Chip steht auf seinem Platz der Belegung.
func seat_hard(counts: Array[int]) -> void:
	_target = counts.duplicate()
	_live = counts.duplicate()
	_ops.clear()
	for body: Dictionary in _leaving:
		_free_body(body)
	_leaving.clear()
	for r in VALUES.size():
		_landed[r] = 0
		_nudge[r] = 0.0
		_gate_t[r] = 0.0
		_gate_open[r] = false
		var row: Array = _rows[r]
		for body: Dictionary in row:
			_free_body(body)
		row.clear()
		if not _built:
			continue
		for i in mini(counts[r], shown_cap(r)):
			row.append(_new_body(r, slot_s(i), 0.0, -1.0, 1.0))
	_write_all()

func settle_hard() -> void:
	seat_hard(_target)

## Ein Komet ist am Kopf einer Rinne gelandet - der wartende Einlauf darf.
func land(rank: int) -> void:
	if rank >= 0 and rank < VALUES.size():
		_landed[rank] += 1

## Spielt eine Schrittliste ab; der Endzustand steht sofort.
func play(steps: Array) -> void:
	_target = fold(_target, steps)
	for step: Dictionary in steps:
		var r: int = int(step["rank"])
		match String(step["kind"]):
			STEP_IN:
				_ops.append({"kind": STEP_IN, "comet": bool(step.get("comet", false)),
					"parts": [_part(r, int(step["count"]), false)]})
			STEP_OUT:
				_ops.append({"kind": STEP_OUT, "rank": r, "count": int(step["count"]),
					"pay": bool(step.get("pay", false))})
			STEP_CARRY:
				_ops.append({"kind": STEP_OUT, "rank": r, "count": ratio(r), "pay": false})
				_ops.append({"kind": STEP_IN, "comet": false, "parts": [_part(r + 1, 1, true)]})
			STEP_BORROW:
				var to: int = int(step["to"])
				_ops.append({"kind": STEP_OUT, "rank": r, "count": 1, "pay": false})
				var parts: Array = []
				for j in range(r - 1, to, -1):
					parts.append(_part(j, ratio(j) - 1, true))
				parts.append(_part(to, ratio(to), true))
				_ops.append({"kind": STEP_IN, "comet": false, "parts": parts})
	if _ops.size() > OPS_CAP or not _built:
		settle_hard()

func _part(rank: int, count: int, lift: bool) -> Dictionary:
	return {"rank": rank, "count": count, "spawned": 0, "timer": 0.0, "wait": 0.0, "lift": lift}

# --- Die Zeremonie ---------------------------------------------------------------

func _process(delta: float) -> void:
	if _built:
		step(delta)

## Ein Takt der Zeremonie (öffentlich, damit Tests ihn fahren).
func step(dt: float) -> void:
	_run_ops(dt)
	for r in VALUES.size():
		_integrate_row(r, dt)
		_nudge[r] *= exp(-NUDGE_DECAY * dt)
	_integrate_leaving(dt)
	_drive_gates(dt)
	_write_all()

func _run_ops(dt: float) -> void:
	var guard := 0
	while not _ops.is_empty() and guard < 8:
		guard += 1
		var op: Dictionary = _ops[0]
		if String(op["kind"]) == STEP_OUT:
			if not op.has("timer"):
				if _row_moving(int(op["rank"])):
					return
				_start_out(int(op["rank"]), int(op["count"]), bool(op["pay"]))
				op["timer"] = OUT_HOLD
				return
			op["timer"] = float(op["timer"]) - dt
			if float(op["timer"]) > 0.0:
				return
			_ops.pop_front()
			continue
		var done := true
		for part: Dictionary in op["parts"]:
			if int(part["spawned"]) < int(part["count"]):
				done = false
				_run_part(part, bool(op["comet"]), dt)
		if not done:
			return
		_ops.pop_front()

func _run_part(part: Dictionary, comet: bool, dt: float) -> void:
	var r: int = int(part["rank"])
	part["timer"] = float(part["timer"]) - dt
	if float(part["timer"]) > 0.0 or not _entry_free(r):
		return
	var needs_comet := comet and int(part["spawned"]) < COMET_CAP
	if needs_comet and _landed[r] <= 0:
		part["wait"] = float(part["wait"]) + dt
		if float(part["wait"]) < COMET_WAIT_MAX:
			return
	if needs_comet and _landed[r] > 0:
		_landed[r] -= 1
	part["spawned"] = int(part["spawned"]) + 1
	part["timer"] = IN_GAP
	part["wait"] = 0.0
	_live[r] += 1
	var row: Array = _rows[r]
	if row.size() < shown_cap(r):
		var lift := bool(part["lift"])
		var body := _new_body(r, ENTRY_S, 0.0 if lift else V_IN, 0.0 if lift else -1.0,
			1.0 if lift else 0.0)
		row.append(body)
	chip_entered.emit(r)

func _entry_free(rank: int) -> bool:
	var row: Array = _rows[rank]
	if row.is_empty():
		return true
	if row.size() >= shown_cap(rank):
		return true
	var last: Dictionary = row.back()
	return float(last["lift"]) < 0.0 and float(last["s"]) >= ENTRY_S + PITCH - 0.02

func _start_out(rank: int, count: int, pay: bool) -> void:
	var row: Array = _rows[rank]
	var before := mini(_live[rank], shown_cap(rank))
	_live[rank] -= count
	var after := mini(maxi(_live[rank], 0), shown_cap(rank))
	var leave := clampi(before - after, 0, row.size())
	for _i in leave:
		var body: Dictionary = row.pop_front()
		body["rank"] = rank
		body["paid"] = pay
		_leaving.append(body)
	# Was nicht sichtbar ging, meldet sich trotzdem ab.
	for _i in count - leave:
		chip_left.emit(rank, pay)
	for i in row.size():
		var body: Dictionary = row[i]
		body["hold"] = true
	if leave > 0:
		_gate_open[rank] = true

func _row_moving(rank: int) -> bool:
	for body: Dictionary in _rows[rank]:
		if _moving(body):
			return true
	for body: Dictionary in _leaving:
		if int(body["rank"]) == rank:
			return true
	return false

func _moving(body: Dictionary) -> bool:
	return float(body["lift"]) >= 0.0 or absf(float(body["v"])) > 0.0001 \
		or float(body["pop"]) < 1.0 or bool(body.get("hold", false))

func _integrate_row(rank: int, dt: float) -> void:
	var row: Array = _rows[rank]
	var holding := false
	for i in row.size():
		var body: Dictionary = row[i]
		if float(body["pop"]) < 1.0:
			body["pop"] = minf(1.0, float(body["pop"]) + dt / POP_TIME)
		if bool(body.get("hold", false)):
			holding = true
			continue
		if float(body["lift"]) >= 0.0:
			body["lift"] = float(body["lift"]) + dt / LIFT_TIME
			if float(body["lift"]) >= 1.0:
				body["lift"] = -1.0
				body["v"] = V_LIFT
			continue
		var limit := gate_s() - H * 0.5
		var front_v := 0.0
		if i > 0:
			var front: Dictionary = row[i - 1]
			limit = float(front["s"]) - PITCH
			front_v = maxf(float(front["v"]), 0.0)
		var v := float(body["v"]) + SLIDE_ACCEL * dt
		var s := float(body["s"]) + v * dt
		if s >= limit:
			s = limit
			if front_v > 0.0:
				v = minf(v, front_v)
			elif v > BOUNCE_V:
				_nudge[rank] = maxf(_nudge[rank], NUDGE * clampf(v / 8.0, 0.2, 1.0))
				v = -v * RESTITUTION
			else:
				v = 0.0
		body["s"] = s
		body["v"] = v
	if holding and not _gate_open[rank] and _gate_t[rank] <= 0.02 and not _leaving_in(rank):
		for body: Dictionary in row:
			body.erase("hold")

func _leaving_in(rank: int) -> bool:
	for body: Dictionary in _leaving:
		if int(body["rank"]) == rank:
			return true
	return false

func _integrate_leaving(dt: float) -> void:
	var gone: Array = []
	var last_s := {}
	for body: Dictionary in _leaving:
		var r: int = int(body["rank"])
		var limit := INF
		if last_s.has(r):
			limit = float(last_s[r]) - PITCH
		if _gate_t[r] < 0.8 and float(body["s"]) <= gate_s() - H * 0.5 + 0.001:
			limit = minf(limit, gate_s() - H * 0.5)
		var v := float(body["v"]) + SLIDE_ACCEL * dt
		var s := minf(float(body["s"]) + v * dt, limit)
		if s >= limit:
			v = 0.0
		body["s"] = s
		body["v"] = v
		last_s[r] = s
		if s >= exit_s():
			gone.append(body)
	for body: Dictionary in gone:
		_leaving.erase(body)
		chip_left.emit(int(body["rank"]), bool(body["paid"]))
		_free_body(body)
	# Ist der letzte Abgang durch, steht die Sperre wieder.
	for r in VALUES.size():
		if not _gate_open[r]:
			continue
		var through := true
		for body: Dictionary in _leaving:
			if int(body["rank"]) == r and float(body["s"]) < _length + H:
				through = false
		if through:
			_gate_open[r] = false

func _drive_gates(dt: float) -> void:
	for r in VALUES.size():
		_gate_t[r] = move_toward(_gate_t[r], 1.0 if _gate_open[r] else 0.0, dt / GATE_TIME)

# --- Körper ----------------------------------------------------------------------

func _new_body(rank: int, s: float, v: float, lift: float, pop: float) -> Dictionary:
	var node := ChipStackView.make_chip(VALUES[rank], false)
	node.name = "Chip%d" % VALUES[rank]
	_bodies_root.add_child(node)
	return {"node": node, "s": s, "v": v, "lift": lift, "pop": pop, "rank": rank}

func _free_body(body: Dictionary) -> void:
	var node: Node3D = body.get("node")
	if node != null and is_instance_valid(node):
		node.queue_free()

func _write_all() -> void:
	if not _built:
		return
	# Hochkant: die Chip-Achse läuft längs der Rinne.
	var basis := Basis(Vector3.RIGHT, TILT) * Basis(Vector3.RIGHT, PI * 0.5)
	var normal := Basis(Vector3.RIGHT, TILT).y
	for r in VALUES.size():
		var lift_off := 0.0
		for i in (_rows[r] as Array).size():
			var body: Dictionary = _rows[r][i]
			var s := float(body["s"])
			if absf(float(body["v"])) <= 0.0001 and float(body["lift"]) < 0.0:
				s += _nudge[r]
			var at := _chip_point(r, s)
			if float(body["lift"]) >= 0.0:
				var rise := ease(clampf(float(body["lift"]), 0.0, 1.0), 0.4)
				lift_off = (1.0 - rise) * LIFT_DROP
				at -= normal * lift_off
			_place(body, at, basis)
		if r < _lift_nodes.size():
			var lift: Node3D = _lift_nodes[r]
			if not lift.has_meta("base"):
				lift.set_meta("base", lift.position)
			lift.position = Vector3(lift.get_meta("base")) - normal * lift_off
		if r < _gate_nodes.size():
			var gate: Node3D = _gate_nodes[r]
			gate.position = Vector3(gate.get_meta("base")) - normal * (_gate_t[r] * (GATE_H + 0.02))
	for body: Dictionary in _leaving:
		_place(body, _chip_point(int(body["rank"]), float(body["s"])), basis)

func _place(body: Dictionary, at: Vector3, basis: Basis) -> void:
	var node: Node3D = body["node"]
	if node == null or not is_instance_valid(node):
		return
	var pop := clampf(float(body["pop"]), 0.0, 1.0)
	node.transform = Transform3D(basis.scaled(Vector3.ONE * maxf(ease(pop, 0.5), 0.01)), at)
