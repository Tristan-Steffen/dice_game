class_name DiceShell
extends Node3D
## Energie-Ikosaeder (d20-Hülle) am Grubenrand - ersetzt den Würfelbecher.
## Gezogene Würfel taumeln als ECHTE Physik-Körper (privater Layer) in der
## rotierenden Kollisionshülle; jeder Innen-Aufprall blitzt die getroffene
## Facette auf (Muster wie DicePit.flash_segment). Zum Mischen schwebt die
## Hülle über die Grubenmitte und rüttelt dort; packt der Spieler sie (Ziehen),
## rüttelt er selbst weiter, Loslassen kippt sofort aus: die Hülle birst
## (dissolve) und die Würfel fallen in die Grube. Wann Würfel hinein-/
## herausfliegen, orchestriert scene_root.

## Kollisions-Ebene fürs Anklicken (Klick = Würfeln-Button, Ziehen = Drehen).
const CLICK_LAYER := 32
## Privater Physik-Layer der Taumel-Würfel + Hüllenplatten - berührt nichts anderes.
const GHOST_LAYER := 64

const RADIUS := 3.0          # Umkreisradius der Hülle
const HOVER_HEIGHT := 4.2    # Schwebehöhe am Heimat-Platz
const BOB_AMPLITUDE := 0.12
const BOB_SPEED := 1.2
const PLATE_THICKNESS := 0.6  # dicke Platten gegen Tunneln

const GHOST_SCALE := 0.6      # Tray-Würfelgröße (DiceTrayView.DIE_SCALE)
const GHOST_GRAVITY := 1.6    # floatiger als Spielwürfel (3.5)
## Weicher Käfig knapp innerhalb der Platten (Inradius ~2.27 minus halber
## Würfel): hält heftig gerüttelte Würfel unsichtbar in der Hülle.
const NET_RADIUS := 1.9

const IDLE_SPIN := Vector3(0.12, 0.35, 0.08)  # ruhige Dauerdrehung
const SHUFFLE_SPEED := 4.0    # rad/s beim Rütteln
const MAX_SPIN := 7.0
const SPIN_DAMP := 1.6        # Rückfederung Richtung Ziel-Drehung (1/s)
const DRAG_SENSITIVITY := 0.06  # Maus-Pixel -> rad/s

const SHAKE_HEIGHT := 8.0     # Rüttel-Höhe des Hüllen-Zentrums über der Grube
const SHAKE_OFFSET_Z := 4.0   # Rüttel-Anker rechts der Grubenmitte (Screen-rechts = +Z)
const SHAKE_JITTER := 0.28    # Amplitude des feinen Positions-Zitterns
## Umherstreifen beim Auto-Rütteln: großes, langsames Treiben in alle
## Richtungen (x = Screen-hoch/runter, y = Höhe, z = links/rechts).
const ROAM := Vector3(2.2, 0.8, 4.0)
const ROAM_RAMP_TIME := 0.6   # Streifen nach der Ankunft sanft einblenden
const DRAG_FOLLOW := 14.0     # Zieh-Folgetempo (1/s) beim manuellen Rütteln
## Randabstand des Zieh-Ziels zur Grubenwand: > RADIUS, damit die Hülle
## samt Silhouette innerhalb der Wände bleibt.
const SHAKE_MARGIN := 4.0
const TRAVEL_TIME := 0.6      # Heimat-Platz -> Grubenmitte
const SHUFFLE_MIN_TIME := 1.0 # ungepackt kippt die Hülle nach dieser Zeit aus

const RELEASE_BURST_TIME := 0.15
const RELEASE_RETURN_TIME := 0.5

const FLASH_DECAY := 0.5
const SHELL_SHADER := preload("res://assets/shaders/energy_shell.gdshader")

## Feuert im Berst-Moment - scene_root räumt dann die Taumel-Würfel ab und
## wirft die echten ab mouth_position() los (Signalname wie beim Becher).
signal poured_out

## Ikosaeder: 12 Vertices aus dem Goldenen Schnitt, 20 Dreiecks-Facetten.
const PHI := 1.618033988749895
const VERTS: Array[Vector3] = [
	Vector3(-1, PHI, 0), Vector3(1, PHI, 0), Vector3(-1, -PHI, 0), Vector3(1, -PHI, 0),
	Vector3(0, -1, PHI), Vector3(0, 1, PHI), Vector3(0, -1, -PHI), Vector3(0, 1, -PHI),
	Vector3(PHI, 0, -1), Vector3(PHI, 0, 1), Vector3(-PHI, 0, -1), Vector3(-PHI, 0, 1),
]
const FACES: Array = [
	[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
	[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
	[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
	[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
]

## Positions-Zustand der Hülle; _physics_process führt ihn (keine Positions-
## Tweens - ein Reset kann so nie eine wartende Koroutine hängen lassen).
enum State { HOME, TRAVEL, SHAKE, POISED, RETURN }

var shell_root: Node3D          # rotiert; trägt Facetten + Kollisionsplatten
var shell_body: AnimatableBody3D
var face_materials: Array[ShaderMaterial] = []
var face_normals: Array[Vector3] = []  # Facetten-Normalen im Hüllen-Lokalraum
var _flash_tweens: Array = []
var ghosts: Array[Node3D] = []  # Taumel-Würfel (Wurzelknoten, Kinder von self)

var state := State.HOME
var move_t := 0.0
var move_from := Vector3.ZERO
var grabbed := false            # Spieler hält die Hülle per Zieh-Geste
var shuffle_time_left := 0.0
var shake_pos := Vector3.ZERO   # ungezitterte Rüttel-Position (lokal)
var shake_ramp := 0.0           # blendet das Umherstreifen nach der Ankunft ein
var drag_point := Vector3.ZERO  # Zieh-Ziel (lokal, siehe drag_to)
var has_drag_point := false
var angular_velocity := Vector3.ZERO
var releasing := false
var _time := 0.0
var active_tween: Tween

func _ready() -> void:
	shell_root = Node3D.new()
	shell_root.name = "ShellRoot"
	shell_root.position = Vector3(0, HOVER_HEIGHT, 0)
	add_child(shell_root)

	shell_body = AnimatableBody3D.new()
	shell_body.name = "Plates"
	shell_body.sync_to_physics = true
	shell_body.collision_layer = GHOST_LAYER
	shell_body.collision_mask = 0
	shell_root.add_child(shell_body)

	face_materials.resize(FACES.size())
	face_normals.resize(FACES.size())
	_flash_tweens.resize(FACES.size())
	for i in FACES.size():
		_build_face(i)

	# Klickzone: Kugel um die Hülle (Layer wie beim alten Becher). Sie hängt an
	# shell_root und wandert damit zum Rüttel-Punkt mit - packbar bleibt die
	# Hülle dort, wo sie gerade schwebt.
	var zone := StaticBody3D.new()
	zone.name = "ClickZone"
	zone.collision_layer = CLICK_LAYER
	zone.collision_mask = 0
	var zone_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS + 0.4
	zone_shape.shape = sphere
	zone.add_child(zone_shape)
	shell_root.add_child(zone)

## Facette i: ein Dreiecks-Mesh (UV = baryzentrisch für den Rand-Glow im
## Shader) plus eine konvexe Platten-Prisma-Kollision, außen aufgesetzt -
## die Innenfläche bleibt bündig und lückenlos.
func _build_face(i: int) -> void:
	var idx: Array = FACES[i]
	var a: Vector3 = VERTS[idx[0]].normalized() * RADIUS
	var b: Vector3 = VERTS[idx[1]].normalized() * RADIUS
	var c: Vector3 = VERTS[idx[2]].normalized() * RADIUS
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot((a + b + c) / 3.0) < 0.0:
		normal = -normal
		var swap := b
		b = c
		c = swap
	face_normals[i] = normal

	var material := ShaderMaterial.new()
	material.shader = SHELL_SHADER
	face_materials[i] = material

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([a, b, c])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([normal, normal, normal])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(1, 0), Vector2(0, 1), Vector2(0, 0)])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var face := MeshInstance3D.new()
	face.name = "Face%d" % i
	face.mesh = mesh
	face.material_override = material
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell_root.add_child(face)

	var shape := ConvexPolygonShape3D.new()
	var out := normal * PLATE_THICKNESS
	shape.points = PackedVector3Array([a, b, c, a + out, b + out, c + out])
	var collision := CollisionShape3D.new()
	collision.name = "Plate%d" % i
	collision.shape = shape
	shell_body.add_child(collision)

## Weltposition des Hüllen-Zentrums - Flugziel hineinfliegender Würfel und
## Startpunkt der echten Wurf-Würfel (über der Grubenmitte beim Bersten).
func mouth_position() -> Vector3:
	return shell_root.global_position

## Rüttel-Anker: lokaler Ort des Hüllen-Zentrums über der Grube, etwas
## rechts der Mitte (Richtung Heimat-Platz).
func _pit_anchor() -> Vector3:
	return to_local(Vector3(DicePit.PIT_CENTER.x, SHAKE_HEIGHT, DicePit.PIT_CENTER.z + SHAKE_OFFSET_Z))

## Nimmt einen gezogenen Würfel auf: baut einen Taumel-Würfel in Tray-Größe
## (Optik über Faces skaliert, Kollisionsbox direkt - ein skalierter
## RigidBody wäre in Jolt tabu) und lässt ihn in der Hülle mittaumeln.
func capture_die(def: DieDefinition, world_pos: Vector3) -> void:
	var die := DieBuilder.build()
	add_child(die)
	ScreenReflection.mark_reflective(die)
	ghosts.append(die)

	var body: RigidBody3D = die.get_node("RigidBody3D")
	body.collision_layer = GHOST_LAYER
	body.collision_mask = GHOST_LAYER
	body.gravity_scale = GHOST_GRAVITY
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.body_entered.connect(_on_ghost_contact.bind(body))
	var shape: BoxShape3D = die.get_node("RigidBody3D/CollisionShape3D").shape
	shape.size = Vector3.ONE * DieBuilder.HALF_EXTENT * 2.0 * GHOST_SCALE
	var faces: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
	faces.scale = Vector3.ONE * GHOST_SCALE
	faces.apply_definition(def)
	faces.set_tint(DiceController.KIND_TINTS.get(def.style_id, Color.WHITE))

	body.global_position = world_pos
	body.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))

func clear_ghosts() -> void:
	for die in ghosts:
		die.queue_free()
	ghosts.clear()

func has_ghosts() -> bool:
	return not ghosts.is_empty()

## Mischen: die Hülle schwebt über die Grubenmitte und rüttelt dort mindestens
## SHUFFLE_MIN_TIME. Solange der Spieler sie gepackt hält (set_grabbed), läuft
## der Timer nicht ab - Loslassen kippt sofort aus. Kehrt zurück, sobald das
## Rütteln vorbei ist (Zustand POISED - bereit für play_release).
func play_shuffle() -> void:
	move_from = shell_root.position
	move_t = 0.0
	state = State.TRAVEL
	while state == State.TRAVEL or state == State.SHAKE:
		await get_tree().physics_frame
		if not is_inside_tree():
			return

## Packen/Loslassen per Zieh-Geste (scene_root): gepackt pausiert der
## Auskipp-Timer; Loslassen während des Rüttelns kippt sofort aus - dort,
## wo der Spieler die Hülle gerade hingezogen hat.
func set_grabbed(value: bool) -> void:
	if grabbed and not value and state == State.SHAKE:
		shuffle_time_left = 0.0
	grabbed = value
	if not value:
		has_drag_point = false

## Zieh-Ziel beim manuellen Rütteln: Weltpunkt (Maus auf der Rüttel-Ebene),
## auf den Grubeninnenraum geklemmt - der Spieler schiebt die Hülle frei
## über die ganze Grube.
func drag_to(world_point: Vector3) -> void:
	var lim_x := DicePit.PIT_HALF_X - SHAKE_MARGIN
	var lim_z := DicePit.PIT_HALF_Z - SHAKE_MARGIN
	drag_point = to_local(Vector3(
		clampf(world_point.x, DicePit.PIT_CENTER.x - lim_x, DicePit.PIT_CENTER.x + lim_x),
		SHAKE_HEIGHT,
		clampf(world_point.z, DicePit.PIT_CENTER.z - lim_z, DicePit.PIT_CENTER.z + lim_z)))
	has_drag_point = true

## Zieh-Geste: Maus-Delta -> Drehimpuls (horizontal um die Hochachse, vertikal
## um die Kamera-Rechtsachse - gleiche Abbildung wie RotatableDieView).
func spin_impulse(relative: Vector2, camera: Camera3D) -> void:
	var axis_x := camera.global_basis.x.normalized() if camera != null else Vector3.RIGHT
	angular_velocity += (Vector3.UP * relative.x + axis_x * relative.y) * DRAG_SENSITIVITY
	angular_velocity = angular_velocity.limit_length(MAX_SPIN)

## Auskippen (an Ort und Stelle über der Grube): alle Facetten blitzen, die
## Hülle birst (dissolve), poured_out feuert im Berst-Moment - die Würfel
## fallen in die Grube. Danach kehrt die Hülle unsichtbar heim und
## rematerialisiert. Die Taumel-Würfel frieren für den Berst-Augenblick ein
## (scene_root räumt sie nach poured_out ab).
func play_release() -> Tween:
	_kill_active_tween()
	releasing = true
	state = State.POISED
	for die in ghosts:
		var body: RigidBody3D = die.get_node("RigidBody3D")
		body.freeze = true
	active_tween = create_tween()
	active_tween.tween_callback(func() -> void:
		for i in face_materials.size():
			flash_face(i, 1.0))
	active_tween.tween_method(_set_dissolve, 0.0, 1.0, RELEASE_BURST_TIME)
	active_tween.tween_callback(poured_out.emit)
	active_tween.tween_callback(_begin_return)
	active_tween.tween_method(_set_dissolve, 1.0, 0.0, RELEASE_RETURN_TIME)
	active_tween.tween_callback(func() -> void: releasing = false)
	return active_tween

## Defensiv-Reset (Spielneustart): Taumel-Würfel weg, Hülle kehrt heim. Ein
## laufendes Auskippen darf zu Ende spielen - es endet ohnehin am Heimat-Platz.
func reset_to_post() -> void:
	clear_ghosts()
	grabbed = false
	shuffle_time_left = 0.0
	if not releasing and state != State.HOME:
		_begin_return()

func _begin_return() -> void:
	move_from = shell_root.position
	move_t = 0.0
	state = State.RETURN

## Facette aufblitzen lassen; klingt über FLASH_DECAY ab (erneuter Treffer
## wird sofort wieder hell) - Muster wie DicePit.flash_segment.
func flash_face(index: int, strength: float) -> void:
	if index < 0 or index >= face_materials.size():
		return
	var tween: Tween = _flash_tweens[index]
	if tween != null and tween.is_valid():
		tween.kill()
	var material := face_materials[index]
	var peak := clampf(strength, 0.0, 1.0)
	material.set_shader_parameter("impact", peak)
	var decay := create_tween()
	decay.tween_method(func(v: float) -> void: material.set_shader_parameter("impact", v),
		peak, 0.0, FLASH_DECAY)
	_flash_tweens[index] = decay

func _physics_process(delta: float) -> void:
	_time += delta
	var home := Vector3(0, HOVER_HEIGHT, 0)
	match state:
		State.HOME:
			shell_root.position = home + Vector3.UP * (sin(_time * BOB_SPEED) * BOB_AMPLITUDE)
		State.TRAVEL:
			move_t += delta
			var k := smoothstep(0.0, 1.0, clampf(move_t / TRAVEL_TIME, 0.0, 1.0))
			var prev := shell_root.position
			shell_root.position = move_from.lerp(_pit_anchor(), k)
			# Reiseflug: die Taumel-Würfel starr mitnehmen - bei dem Tempo
			# würden die Platten sie sonst verlieren.
			_shift_ghosts(shell_root.position - prev)
			if move_t >= TRAVEL_TIME:
				state = State.SHAKE
				shuffle_time_left = SHUFFLE_MIN_TIME
				shake_pos = shell_root.position
				shake_ramp = 0.0
		State.SHAKE:
			# Grobe Bewegung: gepackt folgt die Hülle EXAKT dem Zieh-Ziel (kein
			# Eigenleben - der Spieler rüttelt selbst), sonst streift sie in
			# allen Richtungen umher und zittert dabei fein. Die Platten stoßen
			# die Würfel jeweils physisch an. Timer-Ablauf ZUERST prüfen - nach
			# dem Loslassen darf das Streifen die Hülle nicht mehr vom
			# Loslass-Punkt wegreißen.
			if grabbed:
				if has_drag_point:
					shake_pos = shake_pos.lerp(drag_point, clampf(DRAG_FOLLOW * delta, 0.0, 1.0))
			else:
				shuffle_time_left -= delta
				if shuffle_time_left <= 0.0:
					state = State.POISED
				else:
					shake_ramp = minf(shake_ramp + delta / ROAM_RAMP_TIME, 1.0)
					shake_pos = _pit_anchor() + Vector3(
						sin(_time * 2.1) * ROAM.x,
						sin(_time * 3.3 + 0.8) * ROAM.y,
						sin(_time * 1.7 + 2.1) * ROAM.z) * shake_ramp
			# Eigen-Zittern nur beim Auto-Rütteln (nicht gepackt, Timer läuft noch).
			if grabbed or state != State.SHAKE:
				shell_root.position = shake_pos
			else:
				shell_root.position = shake_pos + Vector3(
					sin(_time * 29.0), sin(_time * 35.0 + 1.3), cos(_time * 31.0)) * SHAKE_JITTER
		State.POISED:
			# Auskipp-Bereitschaft GENAU dort, wo das Rütteln endete - beim
			# manuellen Rütteln also am Loslass-Punkt des Spielers.
			shell_root.position = shake_pos
		State.RETURN:
			move_t += delta
			var k := smoothstep(0.0, 1.0, clampf(move_t / RELEASE_RETURN_TIME, 0.0, 1.0))
			shell_root.position = move_from.lerp(home, k)
			if move_t >= RELEASE_RETURN_TIME:
				state = State.HOME

	# Drehung: Ziel ist ruhiges Kreiseln bzw. Rüttel-Wirbel; Spieler-Impulse
	# federn über SPIN_DAMP dorthin zurück.
	var target := IDLE_SPIN
	if state == State.SHAKE:
		# wandernde Wirbelachse - wirkt chaotisch, bleibt aber ruckelfrei
		target = Vector3(sin(_time * 3.1), sin(_time * 2.3 + 1.7), cos(_time * 2.7)) \
			.normalized() * SHUFFLE_SPEED
	angular_velocity = angular_velocity.lerp(target, clampf(SPIN_DAMP * delta, 0.0, 1.0))
	var speed := angular_velocity.length()
	if speed > 0.001:
		shell_root.global_rotate(angular_velocity / speed, speed * delta)

	# Weicher Käfig: Würfel jenseits NET_RADIUS auf die Kugel zurückklemmen und
	# nur die RADIALE Auswärts-Geschwindigkeit schlucken - kein sichtbarer Pop,
	# das Taumeln läuft tangential weiter.
	var center := shell_root.global_position
	for die in ghosts:
		var body: RigidBody3D = die.get_node("RigidBody3D")
		if body.freeze:
			continue
		var offset := body.global_position - center
		if offset.length() > NET_RADIUS:
			var radial := offset.normalized()
			body.global_position = center + radial * NET_RADIUS
			body.linear_velocity -= radial * maxf(body.linear_velocity.dot(radial), 0.0)

## Innen-Aufprall eines Taumel-Würfels: die Facette in seiner Richtung blitzt,
## Stärke nach Aufprallgeschwindigkeit.
func _on_ghost_contact(other: Node, body: RigidBody3D) -> void:
	if other != shell_body:
		return
	var dir := (body.global_position - shell_root.global_position).normalized()
	var local_dir := shell_root.global_basis.inverse() * dir
	var best := 0
	var best_dot := -INF
	for i in face_normals.size():
		var d := face_normals[i].dot(local_dir)
		if d > best_dot:
			best_dot = d
			best = i
	flash_face(best, clampf(body.linear_velocity.length() / 8.0, 0.35, 1.0))

## Versetzt die aktiven Taumel-Würfel um den Reiseflug-Schritt der Hülle.
func _shift_ghosts(local_shift: Vector3) -> void:
	var shift := global_transform.basis * local_shift
	for die in ghosts:
		var body: RigidBody3D = die.get_node("RigidBody3D")
		if not body.freeze:
			body.global_position += shift

func _set_dissolve(value: float) -> void:
	for material in face_materials:
		material.set_shader_parameter("dissolve", value)

func _kill_active_tween() -> void:
	if active_tween:
		active_tween.kill()
		active_tween = null
