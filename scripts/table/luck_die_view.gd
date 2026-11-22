class_name LuckDieView
extends Node3D
## Der GLÜCKSWÜRFEL am Tisch: golden, eine Spur kleiner als ein Würfel (EINE Größe überall),
## mit ECHTEN Augen statt Ziffern. Er leuchtet selbst unter der Bloom-Schwelle - der Tisch
## beleuchtet nichts. seat_hard ist der EINE Schreiber seiner Augen, settle_hard der harte Weg;
## gebucht ist immer längst (GameRun.luck_die), der Körper zeigt nur.

## Ein Wurf hat aufgesetzt (Ton) bzw. liegt (das Fenster nennt die Wahlen).
signal hopped(step: int)
signal rolled(face: int)
## Ein Auge kam (gain) oder ging - im Schlag, nicht bei der Buchung.
signal pip_changed(gain: bool, value: int)

const SCALE := 0.9 * DiceTrayView.DIE_SCALE
const HALF := DieBuilder.HALF_EXTENT
## Seite i zeigt in diese Richtung (Körper-Raum); 0 liegt in der Ruhe oben.
const FACE_DIRS: Array[Vector3] = [Vector3.UP, Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD,
	Vector3.LEFT, Vector3.DOWN]
## Die Augen-Lagen (LuckDie.PIP_LAYOUTS) mal PIP_SPREAD.
const PIP_SPREAD := 0.52
const PIP_RADIUS := 0.2
const PIP_PROUD := 0.004
## Die Augen sind versenkte Smaragde: eine Mulde mit Goldfase, gemalt auf einer flachen Scheibe.
const GEM := Color(0.05, 0.75, 0.5)
const GOLD := Color(0.9, 0.66, 0.22)
const EDGE_RADIUS := 0.16
## Die Ruhe-Bewegung: er schwebt eine Spur über dem Sitz, wiegt sich und dreht langsam.
const IDLE_TURN := 0.5
const IDLE_LIFT := 0.3
const IDLE_BOB := 0.09
const IDLE_BOB_SPEED := 1.6
const IDLE_RISE := 0.6
## Das Wiegen: zwei überlagerte Schwingungen je Achse (Winkel, Tempo) - nie derselbe Kreis.
const IDLE_SWAY := 0.17
const IDLE_SWAY_FINE := 0.07
const IDLE_YAW_DRIFT := 0.45
## Der Schubs: ein Zug dreht ihn, losgelassen läuft der Schwung aus (FLING_DAMP je Sekunde),
## und je langsamer er wird, desto stärker zieht ihn die Ruhe-Bewegung zurück.
const FLING_SENSITIVITY := 0.012
const FLING_MAX := 16.0
const FLING_DAMP := 1.4
const FLING_RETURN := 2.2
const FLING_CALM := 2.5
## Die Ruhe: ein Hauch gedreht, damit er auf der flachen Kamera als Körper liest.
const REST_YAW := 0.35
## In Ruhe neigt er die obere Seite zum Betrachter (Welt -X).
const REST_TILT := 0.4
## Der geführte Wurf: zwei Hüpfer und ein Trudeln aus, ~0,9 s.
const ROLL_TIME := 0.9
const HOP_HEIGHT := 1.5
const HOP_SMALL := 0.35
const HOP_SPLIT := 0.55
const HOP_SECOND := 0.8
const ROLL_DRIFT := 0.45
## Ein Auge kommt oder geht: die Seite dreht nach oben, das Auge poppt bzw. verglimmt.
const TURN_TIME := 0.25
const PIP_TIME := 0.35
const BEAT_HOLD := 0.25
const BEAT_LIFT := 0.35
const SPIN_SENSITIVITY := 0.01
const PICK_FACTOR := 1.35

## Die gebuchten Augen und die, die gerade zu sehen sind (sie halten den alten Stand bis zum Schlag).
var _target: Array[int] = [1, 1, 1, 1, 1, 1]
var _shown: Array[int] = [1, 1, 1, 1, 1, 1]
var _up_face := 0
var _queue: Array = []
var _body: Node3D
var _pips: Array[Node3D] = []
var _roll_tween: Tween
var _beat_tween: Tween
var _pose_tween: Tween
var _carry_tween: Tween
var _rolled_face := -1
var _idle_time := 0.0
## Von Hand gedreht oder in eine Lage gefahren: die Ruhe-Bewegung schweigt.
var _posed := false
## Am Wurfplatz LIEGT er flach und still, die gewürfelte Seite oben.
var _lying := false
## Der Schubs: die Drehung über der Ruhe-Bewegung, ihr Schwung, und ob der Spieler ihn hält.
var _nudge := Basis.IDENTITY
var _swing := Vector3.ZERO
var _pull := Vector3.ZERO
var _held := false
var _phase := randf() * 40.0

static var _gold_shader: Shader
static var _pip_shader: Shader
static var _body_mesh: ArrayMesh
static var _pip_mesh: PlaneMesh

func _init() -> void:
	name = "LuckDie"
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var box := MeshInstance3D.new()
	box.name = "Gold"
	if _body_mesh == null:
		_body_mesh = rounded_box(HALF, HALF * EDGE_RADIUS)
	box.mesh = _body_mesh
	box.material_override = gold_material()
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(box)
	for face in FACE_DIRS.size():
		var holder := Node3D.new()
		holder.name = "Face%d" % face
		_body.add_child(holder)
		_pips.append(holder)
	_body.scale = Vector3.ONE * SCALE
	_rest_hard()
	_build_all()

## Die halbe Kante in Welt.
static func half_edge() -> float:
	return HALF * SCALE

## Die Lage, in der Seite face oben liegt (mit yaw um die Hochachse).
static func face_up_basis(face: int, yaw := REST_YAW, tilt := REST_TILT) -> Basis:
	var turn: Basis
	match clampi(face, 0, 5):
		1:
			turn = Basis(Vector3.BACK, PI / 2.0)
		2:
			turn = Basis(Vector3.RIGHT, -PI / 2.0)
		3:
			turn = Basis(Vector3.RIGHT, PI / 2.0)
		4:
			turn = Basis(Vector3.BACK, -PI / 2.0)
		5:
			turn = Basis(Vector3.RIGHT, PI)
		_:
			turn = Basis.IDENTITY
	return Basis(Vector3.BACK, tilt) * Basis(Vector3.UP, yaw) * turn

## Die Augen einer Zahl in Seiten-Koordinaten.
static func pip_layout(value: int) -> Array:
	return LuckDie.pip_layout(value)

static func gold_material() -> ShaderMaterial:
	if _gold_shader == null:
		_gold_shader = Shader.new()
		_gold_shader.code = """shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 base : source_color = vec3(0.9, 0.66, 0.22);
uniform float glow = 0.0;
uniform vec3 key_dir = vec3(0.45, 0.8, -0.35);
varying vec3 world_normal;
varying vec3 world_pos;
void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 n = normalize(world_normal);
	vec3 v = normalize(CAMERA_POSITION_WORLD - world_pos);
	vec3 r = reflect(-v, n);
	float lam = max(dot(n, normalize(key_dir)), 0.0);
	float top = smoothstep(0.35, 0.95, r.y);
	float strip = smoothstep(0.86, 0.99, sin(atan(r.z, r.x) * 2.0 + r.y * 2.5 + TIME * 0.35) * 0.5 + 0.5)
		* smoothstep(-0.3, 0.4, r.y);
	float rim = pow(1.0 - max(dot(n, v), 0.0), 4.0);
	vec3 c = base * (0.46 + 0.4 * lam) + base * (top * 0.1 + strip * 0.3)
		+ vec3(1.0, 0.85, 0.5) * rim * 0.25;
	ALBEDO = min(c + base * glow, vec3(0.93));
}
"""
	var material := ShaderMaterial.new()
	material.shader = _gold_shader
	return material

## Ein Würfel mit runden Kanten, glatt schattiert.
static func rounded_box(half: float, radius: float, steps := 10) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := half - radius
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			for i in steps:
				for j in steps:
					var quad: Array[Vector3] = []
					for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
						var p := Vector3.ZERO
						p[axis] = side * half
						p[(axis + 1) % 3] = (float(i + corner.x) / steps * 2.0 - 1.0) * half
						p[(axis + 2) % 3] = (float(j + corner.y) / steps * 2.0 - 1.0) * half
						quad.append(p)
					var order := [0, 2, 1, 0, 3, 2] if side > 0.0 else [0, 1, 2, 0, 2, 3]
					for k: int in order:
						var core := quad[k].clamp(Vector3.ONE * -inner, Vector3.ONE * inner)
						var out := quad[k] - core
						var normal := out.normalized()
						if out.length() < 0.0001:
							normal = Vector3.ZERO
							normal[axis] = side
						st.set_normal(normal)
						st.add_vertex(core + normal * radius)
	return st.commit()

# --- Der Stand ---------------------------------------------------------------------

## Der EINE Schreiber: gebuchter und gezeigter Stand fallen zusammen, nichts läuft mehr.
func seat_hard(faces: Array) -> void:
	_target.assign(faces)
	_shown.assign(faces)
	_queue.clear()
	_kill(_beat_tween)
	_build_all()
	if not rolling() and not carrying():
		_rest_hard()

## Der harte Weg: jede Fahrt fort, der gebuchte Stand steht in Ruhe.
func settle_hard() -> void:
	_kill(_roll_tween)
	_kill(_carry_tween)
	_kill(_pose_tween)
	_kill(_beat_tween)
	_queue.clear()
	_rolled_face = -1
	_shown.assign(_target)
	_build_all()
	_rest_hard()

func shown_faces() -> Array[int]:
	return _shown.duplicate()

func up_face() -> int:
	return _up_face

## Gebuchte Änderungen ({face, delta, value_after}) - nacheinander, jede ein Schlag. Der
## gebuchte Stand steht sofort (Endzustand zuerst), gezeigt wird er erst im Schlag.
func play_changes(changes: Array) -> void:
	for change: Dictionary in changes:
		var face := int(change["face"])
		_target[face] = int(change["value_after"])
		_queue.append(change)

func busy() -> bool:
	return rolling() or carrying() or _beating()

func pending_beats() -> int:
	return _queue.size()

func _process(delta: float) -> void:
	if busy():
		return
	if not _queue.is_empty():
		_play_beat(_queue.pop_front())
		return
	if _lying or _posed or (_pose_tween != null and _pose_tween.is_valid()):
		return
	_step_nudge(delta)
	if not _held:
		_idle_time += delta
	var t := _idle_time
	var w := t + _phase
	var ease := smoothstep(0.0, IDLE_RISE * 2.0, t)
	var yaw := REST_YAW + t * IDLE_TURN + ease * IDLE_YAW_DRIFT * (sin(w * 0.37) - sin(_phase * 0.37))
	var sway := Basis(Vector3.RIGHT, ease * (IDLE_SWAY * sin(w * 0.83) + IDLE_SWAY_FINE * sin(w * 1.9))) \
		* Basis(Vector3.BACK, ease * (IDLE_SWAY * sin(w * 0.61 + 1.7) + IDLE_SWAY_FINE * sin(w * 2.3)))
	_body.basis = (_nudge * sway * face_up_basis(_up_face, yaw)).orthonormalized() \
		.scaled(Vector3.ONE * SCALE)
	_body.position.y = _rest_y() + half_edge() * (IDLE_LIFT * smoothstep(0.0, IDLE_RISE, t)
		+ ease * (IDLE_BOB * sin(w * IDLE_BOB_SPEED) + IDLE_BOB * 0.4 * sin(w * 0.9)))

## Der Schubs je Bild: gehalten folgt er dem Zug, frei läuft der Schwung aus und die Ruhe holt ihn.
func _step_nudge(delta: float) -> void:
	if delta <= 0.0:
		return
	if _held:
		_swing = _swing.lerp(_pull / delta, 0.4).limit_length(FLING_MAX)
		_turn_nudge(_pull)
		_pull = Vector3.ZERO
		return
	var speed := _swing.length()
	if speed > 0.001:
		_turn_nudge(_swing * delta)
		_swing *= exp(-FLING_DAMP * delta)
	var calm := 1.0 - clampf(speed / FLING_CALM, 0.0, 1.0)
	_nudge = _nudge.slerp(Basis.IDENTITY, 1.0 - exp(-FLING_RETURN * calm * delta))

func _turn_nudge(turn: Vector3) -> void:
	var angle := turn.length()
	if angle > 0.00001:
		_nudge = (Basis(turn / angle, angle) * _nudge).orthonormalized()

## Der Spieler greift ihn am Sitz (kein Fokus): er hält an und folgt dem Zug.
func grab() -> void:
	if busy() or _posed or _lying:
		return
	_held = true
	_swing = Vector3.ZERO
	_pull = Vector3.ZERO

func drag(relative: Vector2, camera: Camera3D) -> void:
	if not _held or camera == null:
		return
	_pull += (camera.global_basis.y.normalized() * relative.x
		+ camera.global_basis.x.normalized() * relative.y) * FLING_SENSITIVITY

## Losgelassen: der Schwung des Zugs trägt ihn weiter.
func release() -> void:
	_held = false
	_pull = Vector3.ZERO

func held() -> bool:
	return _held

func _drop_nudge() -> void:
	_held = false
	_nudge = Basis.IDENTITY
	_swing = Vector3.ZERO
	_pull = Vector3.ZERO

func _play_beat(change: Dictionary) -> void:
	var face := int(change["face"])
	var after := int(change["value_after"])
	var before := _shown[face]
	var gain := int(change["delta"]) > 0
	var turn := face_up_basis(face)
	var rest := face_up_basis(_up_face)
	var from := _body.basis.orthonormalized()
	_beat_tween = create_tween()
	_beat_tween.tween_method(func(t: float) -> void:
		_body.basis = from.slerp(turn, t).scaled(Vector3.ONE * SCALE)
		_body.position.y = _rest_y() + BEAT_LIFT * sin(PI * t * 0.5),
		0.0, 1.0, TURN_TIME).set_trans(Tween.TRANS_SINE)
	_beat_tween.tween_callback(func() -> void:
		_shown[face] = after
		_morph_face(face, before, after, gain)
		pip_changed.emit(gain, after))
	_beat_tween.tween_interval(PIP_TIME + BEAT_HOLD)
	_beat_tween.tween_method(func(t: float) -> void:
		_body.basis = turn.slerp(rest, t).scaled(Vector3.ONE * SCALE)
		_body.position.y = _rest_y() + BEAT_LIFT * cos(PI * t * 0.5),
		0.0, 1.0, TURN_TIME).set_trans(Tween.TRANS_SINE)
	_beat_tween.tween_callback(_rest_hard)

func _beating() -> bool:
	return _beat_tween != null and _beat_tween.is_valid()

# --- Die Augen ----------------------------------------------------------------------

func _build_all() -> void:
	for face in FACE_DIRS.size():
		_build_face(face, _shown[face])

func _build_face(face: int, value: int) -> void:
	var holder := _pips[face]
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	for at: Vector2 in pip_layout(value):
		holder.add_child(_make_pip(face, at, _pip_material(0.0)))

## Seite face wechselt von before auf after: neue Plätze poppen golden auf, verschwundene
## verglimmen; was bleibt, bleibt.
func _morph_face(face: int, before: int, after: int, gain: bool) -> void:
	var old_spots := pip_layout(before)
	var new_spots := pip_layout(after)
	_build_face(face, after)
	var holder := _pips[face]
	for pip: MeshInstance3D in holder.get_children():
		var spot: Vector2 = pip.get_meta("spot")
		if old_spots.has(spot):
			continue
		var material := _pip_material(1.0 if gain else 0.0)
		pip.material_override = material
		pip.scale = Vector3.ONE * 0.05
		var pop := pip.create_tween().set_parallel(true)
		pop.tween_property(pip, "scale", Vector3.ONE, PIP_TIME).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
		pop.tween_property(material, "shader_parameter/flash", 0.0, PIP_TIME * 1.6)
	for spot: Vector2 in old_spots:
		if new_spots.has(spot):
			continue
		var ghost := _make_pip(face, spot, _pip_material(1.0 if not gain else 0.0))
		holder.add_child(ghost)
		var fade := ghost.create_tween()
		fade.tween_property(ghost, "scale", Vector3.ONE * 0.05, PIP_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade.tween_callback(ghost.queue_free)

func _make_pip(face: int, at: Vector2, material: Material) -> MeshInstance3D:
	var pip := MeshInstance3D.new()
	if _pip_mesh == null:
		_pip_mesh = PlaneMesh.new()
		_pip_mesh.size = Vector2.ONE * PIP_RADIUS * HALF * 2.0
	pip.mesh = _pip_mesh
	pip.material_override = material
	pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var out := face_up_basis(face, 0.0, 0.0).inverse()
	var spot := at * PIP_SPREAD * HALF
	pip.transform = Transform3D(out, out * Vector3(spot.x, HALF + PIP_PROUD, spot.y))
	pip.set_meta("spot", at)
	return pip

## Die Mulde: die Normale einer Schale gerechnet, darin der Stein, außen die Goldfase.
func _pip_material(flash: float) -> ShaderMaterial:
	if _pip_shader == null:
		_pip_shader = Shader.new()
		_pip_shader.code = """shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 gem : source_color = vec3(0.05, 0.75, 0.5);
uniform vec3 gold : source_color = vec3(0.9, 0.66, 0.22);
uniform float radius = 0.2;
uniform float flash = 0.0;
varying vec3 lp;
varying vec3 wp;
void vertex() {
	lp = VERTEX;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = lp.xz / radius;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	vec3 bowl = normalize(vec3(-p.x, sqrt(max(1.0 - 0.85 * r * r, 0.04)), -p.y));
	vec3 n = normalize((MODEL_MATRIX * vec4(bowl, 0.0)).xyz);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	float lam = max(dot(n, normalize(vec3(0.45, 0.8, -0.35))), 0.0);
	float spec = smoothstep(0.8, 0.98, reflect(-v, n).y);
	float shade = mix(1.0, 0.3, smoothstep(0.25, 0.85, r) * (1.0 - lam));
	float wall = 1.0 - 0.55 * smoothstep(0.5, 0.74, r);
	vec3 stone = (gem * (0.3 + 0.9 * lam) + gem * 0.3 * (1.0 - r)) * shade * wall + vec3(1.0) * spec * 0.12;
	vec3 bevel = gold * (0.2 + 0.85 * lam);
	vec3 c = mix(stone, bevel, smoothstep(0.76, 0.84, r));
	ALBEDO = min(mix(c, vec3(1.0, 0.92, 0.6), flash), vec3(0.93));
}
"""
	var material := ShaderMaterial.new()
	material.shader = _pip_shader
	material.set_shader_parameter("gem", GEM)
	material.set_shader_parameter("gold", GOLD)
	material.set_shader_parameter("radius", PIP_RADIUS * HALF)
	material.set_shader_parameter("flash", flash)
	return material

## Wie viele Augen eine Seite gerade ZEIGT (gezählt an den Körpern, ohne verglimmende).
func pips_on(face: int) -> int:
	var count := 0
	for pip in _pips[face].get_children():
		if _spot_alive(face, pip):
			count += 1
	return count

func _spot_alive(face: int, pip: Node) -> bool:
	return pip_layout(_shown[face]).has(pip.get_meta("spot")) and not pip.is_queued_for_deletion()

# --- Der WURF ---------------------------------------------------------------------

## Der geführte Wurf: gebucht ist längst - zwei Hüpfer, Trudeln, Aufsetzer, und er liegt
## mit face oben. Endzustand zuerst: die Ruhe-Seite steht sofort.
func roll_to(face: int, time := ROLL_TIME) -> void:
	_kill(_roll_tween)
	_kill(_beat_tween)
	_kill(_pose_tween)
	_shown.assign(_target)
	_queue.clear()
	_build_all()
	_up_face = clampi(face, 0, 5)
	_rolled_face = _up_face
	if time <= 0.0:
		finish_roll()
		return
	var start := _body.basis.orthonormalized()
	var mid := Basis.from_euler(Vector3(randf_range(-PI, PI), randf_range(-PI, PI),
		randf_range(-PI, PI)))
	var end := _rest_basis()
	var axis := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	if axis == Vector3.ZERO:
		axis = Vector3.RIGHT
	var drift := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) \
		* ROLL_DRIFT * half_edge()
	var hops := [false, false]
	_roll_tween = create_tween()
	_roll_tween.tween_method(func(t: float) -> void:
		_apply_roll(t, start, mid, end, axis, drift)
		if t >= HOP_SPLIT and not hops[0]:
			hops[0] = true
			hopped.emit(1)
		if t >= HOP_SECOND and not hops[1]:
			hops[1] = true
			hopped.emit(2),
		0.0, 1.0, time)
	_roll_tween.tween_callback(finish_roll)

## Die Lage des Wurfs zur Zeit t (0..1): erst der große Hüpfer mit Überschlag, dann ein
## kleiner, dann rutscht er in die Ruhe.
func _apply_roll(t: float, start: Basis, mid: Basis, end: Basis, axis: Vector3,
		drift: Vector3) -> void:
	var lift := 0.0
	var turn: Basis
	if t < HOP_SPLIT:
		var s := t / HOP_SPLIT
		lift = HOP_HEIGHT * 4.0 * s * (1.0 - s)
		turn = start.slerp(mid, s) * Basis(axis, TAU * s)
	elif t < HOP_SECOND:
		var s := (t - HOP_SPLIT) / (HOP_SECOND - HOP_SPLIT)
		lift = HOP_SMALL * 4.0 * s * (1.0 - s)
		turn = mid.slerp(end, s)
	else:
		turn = end
	var share := smoothstep(0.0, 1.0, t)
	_body.basis = turn.orthonormalized().scaled(Vector3.ONE * SCALE)
	_body.position = Vector3(drift.x * (1.0 - share), _rest_y() + lift * half_edge() * 2.0,
		drift.z * (1.0 - share))

## Der Wurf liegt (auch der Klick dorthin): Ruhe, Signal - idempotent.
func finish_roll() -> void:
	_kill(_roll_tween)
	_rest_hard()
	if _rolled_face < 0:
		return
	var face := _rolled_face
	_rolled_face = -1
	rolled.emit(face)

func rolling() -> bool:
	return _roll_tween != null and _roll_tween.is_valid()

# --- Wege, Inspektion, Zeiger -------------------------------------------------------

## Ein TRAGE-BOGEN zu target (die Wurfgrube der Modul-Pakete und zurück).
func carry_to(target: Vector3, time: float, peak: float) -> Tween:
	_kill(_carry_tween)
	var from := global_position
	if time <= 0.0:
		global_position = target
		return null
	_carry_tween = create_tween()
	_carry_tween.tween_method(func(t: float) -> void:
		global_position = from.lerp(target, t) + Vector3.UP * peak * 4.0 * t * (1.0 - t),
		0.0, 1.0, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return _carry_tween

func carrying() -> bool:
	return _carry_tween != null and _carry_tween.is_valid()

## Steht hart auf at (der harte Weg jedes Fluges).
func land_at(at: Vector3) -> void:
	_kill(_carry_tween)
	global_position = at

func center() -> Vector3:
	return _body.global_position

## Zieht ihn um die Bild-Achsen (die Inspektion).
func spin(relative: Vector2, camera: Camera3D) -> void:
	if camera == null:
		return
	_kill(_pose_tween)
	_posed = true
	_body.global_rotate(camera.global_basis.y.normalized(), relative.x * SPIN_SENSITIVITY)
	_body.global_rotate(camera.global_basis.x.normalized(), relative.y * SPIN_SENSITIVITY)

## In eine Lage (Welt-Basis, ohne Skalierung) und an einen Hub über dem Tisch.
func pose_to(target: Basis, time: float, lift := 0.0) -> void:
	_kill(_pose_tween)
	_posed = true
	_drop_nudge()
	var from := _body.global_basis.orthonormalized()
	var y0 := _body.position.y
	var y1 := _rest_y() + lift
	_pose_tween = create_tween()
	_pose_tween.tween_method(func(t: float) -> void:
		_body.global_basis = from.slerp(target, t).scaled(Vector3.ONE * SCALE)
		_body.position.y = lerpf(y0, y1, t),
		0.0, 1.0, time).set_trans(Tween.TRANS_SINE)

## Zurück in die Ruhe (die Inspektion endet).
func rest_to(time: float) -> void:
	pose_to(_rest_basis(), time)
	_pose_tween.tween_callback(_rest_hard)

## Liegen (Wurfplatz) oder schweben (Station). Zurück zur Station richtet er sich weich auf.
func set_lying(on: bool) -> void:
	if _lying == on:
		return
	_lying = on
	if rolling():
		return
	if on:
		_rest_hard()
	else:
		rest_to(TURN_TIME)

func lying() -> bool:
	return _lying

## Die Ruhelage: liegend flach und gerade, sonst zum Betrachter geneigt.
func _rest_basis() -> Basis:
	return face_up_basis(_up_face, 0.0, 0.0) if _lying else face_up_basis(_up_face)

func under(camera: Camera3D, screen_pos: Vector2) -> bool:
	if camera == null or not is_visible_in_tree():
		return false
	var middle := center()
	if camera.is_position_behind(middle):
		return false
	var c := camera.unproject_position(middle)
	var edge := camera.unproject_position(middle + camera.global_basis.x * half_edge())
	return c.distance_to(screen_pos) <= c.distance_to(edge) * PICK_FACTOR

func _rest_y() -> float:
	if _lying:
		return half_edge()
	return half_edge() * (cos(REST_TILT) + sin(REST_TILT) * (absf(cos(REST_YAW)) + absf(sin(REST_YAW))))

func _rest_hard() -> void:
	_kill(_pose_tween)
	_posed = false
	_idle_time = 0.0
	_drop_nudge()
	_body.basis = _rest_basis().scaled(Vector3.ONE * SCALE)
	_body.position = Vector3(0.0, _rest_y(), 0.0)

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
