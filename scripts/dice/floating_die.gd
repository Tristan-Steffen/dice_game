class_name FloatingDie
extends Node3D
## Ein Würfel im Stasis-Feld: der ECHTE Würfel schwebt über seiner Station
## (StasisEmitter) und wippt wie ein Tray-Würfel. Er IST die Ansicht - gezeigt
## wird direkt auf ihn, über die BILDSCHIRM-Projektion seiner Seiten- und
## Kantenmitten (kein Physik-Strahl: er trägt keine Kollisionsform). Genutzt vom
## Werkstück der Gravur-Station, von der Aufspannung und vom PODEST am Ausgabefach.
## Wer ihn heranholt, dreht ihn - siehe CameraRig.die_focus.

## Ergebnis von pick(): nichts getroffen bzw. der Kanten-Rahmen (er gewinnt, wenn
## eine Kantenmitte näher am Zeiger liegt als jede Seitenmitte).
const PICK_NONE := -1
const PICK_FRAME := -2

## Greifradius als Vielfaches der projizierten Halbbreite - die Silhouette eines
## gedrehten Würfels reicht über seine Seitenmitte hinaus.
const PICK_FACTOR := 1.6
## Maus-Pixel -> Drehwinkel.
const SPIN_SENSITIVITY := 0.01
## Absorptions-Pop (Gravur eingeschlagen).
const PULSE_UP := 1.18
## Entstehen aus dem Zeichen: von diesem Bruchteil seiner Größe wächst er auf.
const MATERIALIZE_FROM := 0.15
const MATERIALIZE_TIME := 0.28
## Abtreten (das Fenster gehört gerade einem Paket): schneller als das Entstehen -
## Platz machen ist keine Zeremonie.
const DEMATERIALIZE_TIME := 0.16

var die: Node3D
var faces: DieFaceDisplay
var emitter: StasisEmitter
## Der gezeigte Würfel (geteilte Instanz) - daran erkennt der Aufrufer, ob eine
## stehende Bühne schon den richtigen Würfel trägt.
var def: DieDefinition

## Schwebehöhe der Würfel-MITTE über der Standfläche.
var hover_height := DiceTrayView.FLOAT_HEIGHT
## Ruhelage, um die das Wippen schwingt (erst mit land_at gesetzt).
var rest_y := 0.0
var _bob_phase := 0.0
var _fly_tween: Tween
var _pose_tween: Tween
## Die drei Stücke des Trage-Bogens (carry_to): Start, Ziel und die Scheitelhöhe
## über der Sehne.
var _carry_from := Vector3.ZERO
var _carry_to := Vector3.ZERO
var _carry_hump := 0.0
## Wachsen und Schrumpfen teilen sich EINEN Tween: sonst versteckte ein spätes
## Abtreten den Würfel, der längst wieder aufgeht.
var _scale_tween: Tween

## Freier, nicht-kollidierender Würfel in Tray-Größe und Tray-Ausrichtung - die
## Grundform jedes Würfels, der außerhalb von Grube und Tray gezeigt wird.
static func build_ghost(def: DieDefinition) -> Node3D:
	var ghost := DieBuilder.build()
	# 90° aus der Draufsicht wie im Tray: die Ziffer der Oben-Seite steht aufrecht.
	ghost.rotation.y = -PI / 2.0
	ghost.scale = Vector3.ONE * DiceTrayView.DIE_SCALE
	var body: RigidBody3D = ghost.get_node("RigidBody3D")
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	var display: DieFaceDisplay = ghost.get_node("RigidBody3D/Faces")
	display.apply_definition(def)
	display.set_tint(DiceController.KIND_TINTS.get(def.style_id, Color.WHITE))
	return ghost

## Baut Würfel und Station; der Würfel startet bei from und rastet mit land_at
## ein. tint ist die Feldfarbe der Station.
func setup(shown: DieDefinition, tint: Color, from: Vector3) -> void:
	def = shown
	die = build_ghost(def)
	add_child(die)
	faces = die.get_node("RigidBody3D/Faces")
	die.global_position = from

	emitter = StasisEmitter.new()
	emitter.name = "Emitter"
	add_child(emitter)
	emitter.build(hover_height, DiceTrayView.DIE_SCALE, tint)
	emitter.set_engaged(0.0)  # noch trägt sie nichts

## Lässt den Würfel auf target gleiten; die Station steht senkrecht darunter auf
## der Fläche und greift während des Flugs zu.
func land_at(target: Vector3, time: float) -> void:
	rest_y = target.y
	_bob_phase = 0.0
	emitter.global_position = Vector3(target.x, target.y - hover_height, target.z)
	_kill(_fly_tween)
	if time <= 0.0:
		die.global_position = target
		emitter.set_engaged(1.0)
		emitter.ripple()
		return
	_fly_tween = create_tween()
	_fly_tween.tween_property(die, "global_position", target, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fly_tween.parallel().tween_method(emitter.set_engaged, 0.0, 1.0, time)
	_fly_tween.tween_callback(emitter.ripple)  # das Feld rastet ein

## Der Würfel wandert auf einen anderen Platz - SAMT seiner Station: er ist ein
## Ding, er springt nicht und lässt sein Feld nicht zurück.
func move_to(target: Vector3, time: float) -> void:
	if die == null or not is_instance_valid(die):
		return
	rest_y = target.y
	_kill(_fly_tween)
	_fly_tween = create_tween()
	_fly_tween.set_parallel(true)
	_fly_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fly_tween.tween_property(die, "global_position", target, time)
	_fly_tween.tween_property(emitter, "global_position",
		Vector3(target.x, target.y - hover_height, target.z), time)

## Der TRAGE-BOGEN: was der SPIELER bewegt, fliegt ÜBER dem Tisch. Der Würfel reist
## samt seiner Station in einem flachen Bogen auf einen anderen Platz - XZ gerade,
## Y als Parabel über der Sehne, ohne Trudeln; unter die Sehne kommt er nie, also
## nie unter die Fläche. Liefert die Fahrt (null = kein Körper).
func carry_to(target: Vector3, time: float, peak: float) -> Tween:
	if die == null or not is_instance_valid(die):
		return null
	rest_y = target.y
	_bob_phase = 0.0
	_kill(_fly_tween)
	_carry_from = die.global_position
	_carry_to = target
	var chord := (_carry_from.y + target.y) * 0.5
	_carry_hump = maxf(maxf(_carry_from.y, target.y) + maxf(peak, 0.0) - chord, 0.0)
	if time <= 0.0:
		_set_carry_share(1.0)
		return null
	# Sofort auf den Start setzen: die Station steht sonst ein Bild lang im
	# Weltursprung (setup legt sie nicht hin, das tat bisher land_at).
	_set_carry_share(0.0)
	_fly_tween = create_tween()
	_fly_tween.tween_method(_set_carry_share, 0.0, 1.0, time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return _fly_tween

func _set_carry_share(share: float) -> void:
	var seat := _carry_from.lerp(_carry_to, share)
	seat.y += 4.0 * _carry_hump * share * (1.0 - share)
	die.global_position = seat
	emitter.global_position = Vector3(seat.x, seat.y - hover_height, seat.z)

## Steht die Station schon an diesem Platz? (Der Würfel selbst wippt, sein Feld
## nicht - also fragt die Station.)
func stands_at(target: Vector3) -> bool:
	if emitter == null or not is_instance_valid(emitter):
		return false
	var here := emitter.global_position
	return Vector2(here.x, here.z).distance_to(Vector2(target.x, target.z)) <= 0.05

## Wippen im Feld; die Station pulst gegenphasig mit (sinkt der Würfel, arbeitet
## sie härter). Während des Flugs führt der Tween.
func _process(delta: float) -> void:
	if die == null or not is_instance_valid(die) or is_flying():
		return
	_bob_phase += delta * DiceTrayView.BOB_SPEED
	var bob := sin(_bob_phase)
	die.global_position.y = rest_y + bob * DiceTrayView.BOB_AMPLITUDE
	emitter.set_load(StasisEmitter.load_for(bob))

func is_flying() -> bool:
	return _fly_tween != null and _fly_tween.is_valid()

func center() -> Vector3:
	return die.global_position if die != null and is_instance_valid(die) else global_position

## Zeichnet die Augenzahlen neu (nach einer Ätzung); Tönungen setzt der Aufrufer.
func apply_definition(shown: DieDefinition) -> void:
	if faces == null or not is_instance_valid(faces):
		return
	def = shown
	faces.apply_definition(def)
	faces.set_tint(DiceController.KIND_TINTS.get(def.style_id, Color.WHITE))

## Malt einen HYBRID der Aufdeckung, OHNE def anzufassen: def bleibt die geteilte
## Instanz, an der _rebuild_bench_stage den Körper wiedererkennt.
func show_faces(shown: DieDefinition) -> void:
	if faces == null or not is_instance_valid(faces) or shown == null:
		return
	faces.apply_definition(shown)
	faces.set_tint(DiceController.KIND_TINTS.get(shown.style_id, Color.WHITE))

## Aus dem Zeichen wird der Körper: der Würfel wächst an Ort und Stelle ins Feld
## hinein - er fliegt nirgends her, sein Zeichen stand schon hier.
## delay: das Kleinwerden geschieht SOFORT, nur das Wachsen wartet - eine ganze
## Aufspannung entsteht gestaffelt, ohne dass ein Würfel vorher in voller Größe
## dastünde.
func materialize(delay: float = 0.0) -> void:
	if die == null or not is_instance_valid(die):
		return
	_kill(_scale_tween)
	visible = true
	var base := Vector3.ONE * DiceTrayView.DIE_SCALE
	die.scale = base * MATERIALIZE_FROM
	_scale_tween = create_tween()
	if delay > 0.0:
		_scale_tween.tween_interval(delay)
	_scale_tween.tween_property(die, "scale", base, MATERIALIZE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Abtreten, ohne freigegeben zu werden: der Würfel schrumpft an Ort und Stelle
## und wird unsichtbar - das Feld geht als Kind mit aus. Derselbe Körper steht
## später wieder auf (materialize), er hat nur Platz gemacht.
func dematerialize() -> void:
	if die == null or not is_instance_valid(die) or not visible:
		return
	_kill(_scale_tween)
	_scale_tween = create_tween()
	var shrink := _scale_tween.tween_property(die, "scale",
		Vector3.ONE * DiceTrayView.DIE_SCALE * MATERIALIZE_FROM, DEMATERIALIZE_TIME)
	shrink.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_scale_tween.tween_callback(_hide_body)

func _hide_body() -> void:
	visible = false

## Aufpluster-Pop: der Würfel schluckt eine Gravur.
func pulse() -> void:
	if die == null or not is_instance_valid(die):
		return
	var base := Vector3.ONE * DiceTrayView.DIE_SCALE
	var pop := create_tween()
	pop.tween_property(die, "scale", base * PULSE_UP, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(die, "scale", base, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- Zeigen und Greifen ----------------------------------------------------------

## Projizierte Halbbreite in Bildschirmpixeln (-1 = nicht im Bild). Aus der
## Projektion gerechnet, damit Greifen und Picken in JEDER Zoomstufe stimmen.
func screen_half(camera: Camera3D) -> float:
	if camera == null or die == null or not is_instance_valid(die):
		return -1.0
	var middle := die.global_position
	if camera.is_position_behind(middle):
		return -1.0
	var edge := middle + camera.global_basis.x * DieBuilder.HALF_EXTENT * DiceTrayView.DIE_SCALE
	return camera.unproject_position(middle).distance_to(camera.unproject_position(edge))

func pick_radius(camera: Camera3D) -> float:
	return screen_half(camera) * PICK_FACTOR

## Liegt der Bildschirmpunkt auf dem Würfel? Ein abgetretener Würfel liegt
## nirgends - die Sperre steht HIER, damit kein Aufrufer sie vergessen kann.
func under(camera: Camera3D, screen_pos: Vector2) -> bool:
	if not is_visible_in_tree():
		return false
	var radius := pick_radius(camera)
	if radius <= 0.0:
		return false
	return camera.unproject_position(die.global_position).distance_to(screen_pos) <= radius

## Was liegt unter dem Zeiger: eine Seite (0..5), der Rahmen oder nichts.
func pick(camera: Camera3D, screen_pos: Vector2) -> int:
	var radius := pick_radius(camera)
	if radius <= 0.0 or faces == null or not is_instance_valid(faces):
		return PICK_NONE
	var face_pick := faces.pick_face(camera, screen_pos, radius)
	if faces.edge_distance(camera, screen_pos, radius) < float(face_pick[1]):
		return PICK_FRAME
	return int(face_pick[0])

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()

## Maus-Delta -> Drehung um die BILD-Achsen: waagerecht um die Hochachse des
## Bildes, senkrecht um seine Querachse.
func spin(relative: Vector2, camera: Camera3D) -> void:
	if camera == null or die == null or not is_instance_valid(die):
		return
	_kill(_pose_tween)  # der Spieler übernimmt die Lage
	die.global_rotate(camera.global_basis.y.normalized(), relative.x * SPIN_SENSITIVITY)
	die.global_rotate(camera.global_basis.x.normalized(), relative.y * SPIN_SENSITIVITY)

## Legt den Würfel über die angegebene Zeit in eine Ziel-Lage. Die Skalierung
## steckt in der Basis - sie muss beim Setzen wieder mit hinein.
func pose_to(target: Basis, time: float) -> void:
	if die == null or not is_instance_valid(die):
		return
	_kill(_pose_tween)
	var from := die.global_basis.orthonormalized()
	_pose_tween = create_tween()
	_pose_tween.tween_method(
		func(t: float) -> void: _apply_pose(from.slerp(target, t)),
		0.0, 1.0, time).set_trans(Tween.TRANS_SINE)

## Die Schwebe-Ruhelage der Tray-Würfel - dorthin legt sich der Würfel zurück.
static func rest_pose() -> Basis:
	return Basis(Vector3.UP, -PI / 2.0)

func _apply_pose(basis: Basis) -> void:
	if die == null or not is_instance_valid(die):
		return
	die.global_basis = basis.scaled(Vector3.ONE * DiceTrayView.DIE_SCALE)
