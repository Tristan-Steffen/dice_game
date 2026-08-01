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
const HOVER_HEIGHT := 5.6    # Schwebehöhe am Heimat-Platz (über dem Schatz-Screen)
const BOB_AMPLITUDE := 0.12
const BOB_SPEED := 1.2
const PLATE_THICKNESS := 0.6  # dicke Platten gegen Tunneln
## Verhältnis In-/Umkugel des Ikosaeders - die tiefste Facettenmitte.
const INRADIUS_FACTOR := 0.7947

## Projektor am Heimat-Platz: dieselbe Stasis-Station wie unter den Tray-
## Würfeln (Puck + Iris + Kegel, siehe DiceTrayView), nur größer.
const PUCK_SHADER := preload("res://assets/shaders/stasis_puck.gdshader")
const LENS_SHADER := preload("res://assets/shaders/stasis_lens.gdshader")
const BEAM_SHADER := preload("res://assets/shaders/stasis_beam.gdshader")
const PROJECTOR_TINT := Color(0.15, 0.75, 1.0)  # Feldfarbe der Hülle
const PUCK_RADIUS := 1.4
const PUCK_Y := 0.04
const LENS_RADIUS := 0.78
const BEAM_BOTTOM_RADIUS := 0.62
const BEAM_TOP_RADIUS := 1.5
const LOAD_AMOUNT := 0.5   # Last-Puls gegenphasig zum Schweben
const ENGAGE_FADE := 2.0   # 1/s: Strahl löst beim Abheben, greift bei Heimkehr

const GHOST_SCALE := 0.6      # Tray-Würfelgröße (DiceTrayView.DIE_SCALE)
const GHOST_GRAVITY := 1.6    # floatiger als Spielwürfel (3.5)
## Weicher Käfig knapp innerhalb der Platten (Inradius ~2.27 minus halber
## Würfel): hält heftig gerüttelte Würfel unsichtbar in der Hülle.
const NET_RADIUS := 1.9
## Die Platten federn deutlich härter als Grubenwände (DieBuilder.BOUNCE
## 0.25) und greifen kaum - die Würfel sollen im Becher rasseln, nicht
## kleben. GHOST_MAX_SPEED ist das Sicherheitsventil, damit sich zwischen
## zwei federnden Wänden nichts aufschaukelt (gemessen relativ zur Hülle).
const PLATE_BOUNCE := 0.85
const PLATE_FRICTION := 0.15
const GHOST_DAMP := 0.05
const GHOST_MAX_SPEED := 22.0
## Der weiche Käfig wirft die Würfel zurück, statt sie zu schlucken - sonst
## fräße er in den Ikosaeder-Ecken (dort ist die Wand weiter weg als
## NET_RADIUS) genau die Sprünge weg, die die Platten erzeugen sollen.
const NET_BOUNCE := 0.75

const IDLE_SPIN := Vector3(0.12, 0.35, 0.08)  # ruhige Dauerdrehung
const MAX_SPIN := 7.0
const SPIN_DAMP := 1.6        # Rückfederung Richtung Ziel-Drehung (1/s)
const DRAG_SENSITIVITY := 0.06  # Maus-Pixel -> rad/s

const SHAKE_HEIGHT := 8.0     # Rüttel-Höhe des Hüllen-Zentrums über der Grube
const SHAKE_OFFSET_Z := 4.0   # Rüttel-Anker rechts der Grubenmitte (Screen-rechts = +Z)
## Becher-Schlag beim Auto-Rütteln: EIN fester Schlagvektor (quer über die
## Grube, dabei auf/ab), im Takt hin und her - kein zufälliges Umherstreifen.
## Ausschlag plus RADIUS bleibt klar innerhalb PIT_HALF_X/Z.
const SHAKE_STROKE := Vector3(0.85, 0.7, 2.2)
## Oberwelle quer zum Schlag (doppelter Takt): macht aus der Geraden die
## flache Acht, die eine Hand beim Schütteln beschreibt. Taktgebunden, also
## rhythmisch statt zufällig.
const SHAKE_ARC := Vector3(0.35, 0.6, 0.0)
const SHAKE_RATE := 14.0      # rad/s des Schlags (~2,2 Hz = ~4,5 Schläge/s)
## 0 = reiner Sinus (weiche Umkehr), 1 = Dreieck (konstantes Tempo, harte
## Umkehr). Dazwischen liegt der Handgelenk-Schlag.
const SHAKE_SNAP := 0.6
const ROCK_SPEED := 5.0       # rad/s: Kippen quer zur Schlagrichtung
const SHAKE_SPIN_DAMP := 14.0 # das Kippen muss dem schnellen Takt folgen
const DRAG_FOLLOW := 14.0     # Zieh-Folgetempo (1/s) beim manuellen Rütteln
## Manuelles Rütteln: die Maus liefert nur X/Z, das Auf/Ab entsteht daraus.
## Der Zieh-Rückstand (drag_point minus shake_pos) ist dabei das fertig
## geglättete Maß dafür, wie hart der Spieler gerade reißt - DRAG_FOLLOW
## hinkt absichtlich hinterher.
const DRAG_ROCK_GAIN := 0.11  # Zieh-Tempo -> Kipp-Rate (rad/s je Einheit/s)
const LIFT_SAG := 0.28        # Ruhelage sinkt je Einheit Mehr-Rückstand
## Gleitendes Mittel des Rückstands (1/s). Getrieben wird die Feder nur von
## der ABWEICHUNG davon - sonst hinge die Hülle bei Dauerschütteln bloß
## dauerhaft tief, statt um die Rüttel-Ebene zu schwingen.
const LAG_AVG_RATE := 1.5
const LIFT_STIFF := 240.0     # Federhärte (~2,5 Hz - Tempo eines Handgelenks)
const LIFT_DAMP := 11.0       # Dämpfungsgrad ~0,35: federt sichtbar nach
const LIFT_MAX := 1.6         # Federweg-Grenze (Grubenwände sind 16 hoch)
## Scheinkraft auf die Taumel-Würfel: der Ruck der Hülle als Trägheit des
## Schwarms. Der Ruck kommt aus (sofortige - nachlaufende) Geschwindigkeit -
## proportional zur Beschleunigung, aber ohne deren Frame-Rauschen.
const GHOST_INERTIA := 4.0
const GHOST_JOLT_MAX := 12.0
const VEL_SMOOTH := 10.0      # 1/s: Nachlauf der geglätteten Geschwindigkeit
const REVERSAL_MIN_SPEED := 4.0
const REVERSAL_KICK := 2.2    # Aufwärts-Stoß bei jeder Schlagumkehr
const REVERSAL_TUMBLE := 1.4  # Drall dazu, damit sich die Würfel überschlagen
const REVERSAL_COOLDOWN := 0.1
## Randabstand des Zieh-Ziels zur Grubenwand: > RADIUS, damit die Hülle
## samt Silhouette innerhalb der Wände bleibt.
const SHAKE_MARGIN := 4.0
const TRAVEL_TIME := 0.6      # Heimat-Platz -> Grubenmitte
## Ungepackt kippt die Hülle nach dieser Zeit aus - knapp, aber lang genug,
## dass das Umherstreifen als Bewegung lesbar wird.
const SHUFFLE_MIN_TIME := 0.8

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
var shake_pos := Vector3.ZERO   # Mittelpunkt-Position der Hülle (lokal)
var shake_t := 0.0              # Takt-Zeit des Schlags (0 bei Rüttel-Beginn)
var drag_point := Vector3.ZERO  # Zieh-Ziel (lokal, siehe drag_to)
var has_drag_point := false
var lift := 0.0                 # Federweg der Hülle über der Rüttel-Ebene
var lift_vel := 0.0
var _lag_avg := 0.0             # Grundtempo des Schüttelns (siehe LAG_AVG_RATE)
var _shell_vel := Vector3.ZERO  # nachlaufende Weltgeschwindigkeit der Hülle
var _prev_shell_pos := Vector3.ZERO
var _prev_flat := Vector2.ZERO  # waagerechte Richtung des letzten Frames
var _reversal_cd := 0.0

var beam_material: ShaderMaterial   # Projektor-Säule am Heimat-Platz
var lens_material: ShaderMaterial
var _engaged := 1.0                 # 1 = Strahl trägt die Hülle (nur zu Hause)
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
	var plate_physics := PhysicsMaterial.new()
	plate_physics.bounce = PLATE_BOUNCE
	plate_physics.friction = PLATE_FRICTION
	shell_body.physics_material_override = plate_physics
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

	_build_projector()
	_prev_shell_pos = shell_root.global_position

## Projektor am Heimat-Platz: Leuchtscheibe + Iris auf der Tischfläche und
## darüber der Kraftfeld-Kegel bis zur Hülle - die sichtbare Ursache, dass sie
## dort schwebt. Bleibt liegen, wenn die Hülle zur Grube zieht (engaged -> 0).
func _build_projector() -> void:
	var puck_material := ShaderMaterial.new()
	puck_material.shader = PUCK_SHADER
	puck_material.set_shader_parameter("tint", PROJECTOR_TINT)
	var puck_mesh := PlaneMesh.new()
	puck_mesh.size = Vector2.ONE * PUCK_RADIUS * 2.0
	puck_mesh.material = puck_material
	var puck := MeshInstance3D.new()
	puck.name = "ProjectorPuck"
	puck.mesh = puck_mesh
	puck.position = Vector3(0, PUCK_Y, 0)
	add_child(puck)

	lens_material = ShaderMaterial.new()
	lens_material.shader = LENS_SHADER
	lens_material.set_shader_parameter("tint",
		Vector3(PROJECTOR_TINT.r, PROJECTOR_TINT.g, PROJECTOR_TINT.b))
	var lens_mesh := PlaneMesh.new()
	lens_mesh.size = Vector2.ONE * LENS_RADIUS * 2.0
	lens_mesh.material = lens_material
	var lens := MeshInstance3D.new()
	lens.name = "ProjectorLens"
	lens.mesh = lens_mesh
	lens.position = Vector3(0, PUCK_Y + 0.01, 0)  # knapp über dem Puck-Dial
	add_child(lens)

	# Der Griff-Ring sitzt an der Unterseite der Hülle (tiefste Facettenmitte).
	beam_material = ShaderMaterial.new()
	beam_material.shader = BEAM_SHADER
	beam_material.set_shader_parameter("beam_height", HOVER_HEIGHT)
	beam_material.set_shader_parameter("grip_h",
		clampf((HOVER_HEIGHT - RADIUS * INRADIUS_FACTOR) / HOVER_HEIGHT, 0.0, 1.0))
	beam_material.set_shader_parameter("beam_color",
		Vector3(PROJECTOR_TINT.r, PROJECTOR_TINT.g, PROJECTOR_TINT.b))
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = BEAM_TOP_RADIUS
	beam_mesh.bottom_radius = BEAM_BOTTOM_RADIUS
	beam_mesh.height = HOVER_HEIGHT
	beam_mesh.radial_segments = 20
	var beam := MeshInstance3D.new()
	beam.name = "ProjectorBeam"
	beam.mesh = beam_mesh
	beam.material_override = beam_material
	beam.position = Vector3(0, HOVER_HEIGHT * 0.5, 0)
	add_child(beam)

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

## Ein Becher-Schlag: Hin und Her entlang SHAKE_STROKE, dessen Kurve zwischen
## Sinus (weiche Umkehr) und Dreieck (konstantes Tempo, harte Umkehr) liegt -
## das ist der Handgelenk-Schlag. Dazu eine Oberwelle im doppelten Takt quer
## dazu, die die Gerade zur flachen Acht macht. Beide Anteile hängen am selben
## Takt: die Bahn wiederholt sich, statt zufällig zu wandern.
func _stroke_offset(phase: float) -> Vector3:
	var wave := sin(phase)
	var triangle := asin(wave) * 2.0 / PI
	return SHAKE_STROKE * lerpf(wave, triangle, SHAKE_SNAP) + SHAKE_ARC * sin(phase * 2.0)

## Kipp-Achse des Handgelenks: waagerecht und quer zur Schlagrichtung.
func _rock_axis() -> Vector3:
	var axis := SHAKE_STROKE.cross(Vector3.UP)
	return axis.normalized() if axis.length() > 0.01 else Vector3.RIGHT

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
	body.linear_damp = GHOST_DAMP
	body.angular_damp = GHOST_DAMP
	# Eigenes Material: der Spielwürfel-Wert (0.25) wäre in der Hülle zu zahm.
	var ghost_physics := PhysicsMaterial.new()
	ghost_physics.bounce = PLATE_BOUNCE
	ghost_physics.friction = PLATE_FRICTION
	body.physics_material_override = ghost_physics
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.body_entered.connect(_on_ghost_contact.bind(body))
	var shape: BoxShape3D = die.get_node("RigidBody3D/CollisionShape3D").shape
	shape.size = Vector3.ONE * DieBuilder.HALF_EXTENT * 2.0 * GHOST_SCALE
	var faces: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
	faces.scale = Vector3.ONE * GHOST_SCALE
	# Die Taumel-Würfel schweben in der Hülle - eine Lache am Grubenboden
	# hätte keinen Bezug und würde unter der Hülle flackern.
	faces.set_pool_enabled(false)
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
## um die Kamera-Rechtsachse - dieselbe Abbildung wie am Werkstück der Station).
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
	move_from = shell_root.position  # inklusive Federweg - kein Sprung
	lift = 0.0
	lift_vel = 0.0
	_lag_avg = 0.0
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
	var bob := sin(_time * BOB_SPEED)
	match state:
		State.HOME:
			shell_root.position = home + Vector3.UP * (bob * BOB_AMPLITUDE)
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
				shake_t = 0.0  # Takt bei 0 - der erste Schlag startet aus der Ruhe
				_lag_avg = 0.0
		State.SHAKE:
			# Gepackt folgt die Hülle EXAKT dem Zieh-Ziel (kein Eigenleben - der
			# Spieler schüttelt selbst), sonst schlägt sie im festen Takt hin und
			# her wie ein Becher in der Hand. Die Platten stoßen die Würfel dabei
			# physisch an. Timer-Ablauf ZUERST prüfen - nach dem Loslassen darf
			# kein Schlag die Hülle vom Loslass-Punkt wegreißen.
			var lag := 0.0
			if grabbed:
				if has_drag_point:
					lag = Vector2(drag_point.x - shake_pos.x, drag_point.z - shake_pos.z).length()
					shake_pos = shake_pos.lerp(drag_point, clampf(DRAG_FOLLOW * delta, 0.0, 1.0))
			else:
				shuffle_time_left -= delta
				if shuffle_time_left <= 0.0:
					state = State.POISED
				else:
					shake_t += delta
					shake_pos = _pit_anchor() + _stroke_offset(shake_t * SHAKE_RATE)
			_update_lift(delta, lag)
			shell_root.position = shake_pos + Vector3.UP * lift
		State.POISED:
			# Auskipp-Bereitschaft GENAU dort, wo das Rütteln endete - beim
			# manuellen Rütteln also am Loslass-Punkt des Spielers.
			_update_lift(delta, 0.0)
			shell_root.position = shake_pos + Vector3.UP * lift
		State.RETURN:
			move_t += delta
			var k := smoothstep(0.0, 1.0, clampf(move_t / RELEASE_RETURN_TIME, 0.0, 1.0))
			shell_root.position = move_from.lerp(home, k)
			if move_t >= RELEASE_RETURN_TIME:
				state = State.HOME

	# Projektor: der Strahl trägt nur am Heimat-Platz, unterwegs löst er sich.
	# Last pulst gegenphasig zum Schweben (sinkt die Hülle, arbeitet das Feld
	# härter) - dieselbe Rückkopplung wie bei den Tray-Emittern.
	_engaged = move_toward(_engaged, 1.0 if state == State.HOME else 0.0, ENGAGE_FADE * delta)
	beam_material.set_shader_parameter("engaged", _engaged)
	var load := 1.0 - LOAD_AMOUNT * bob * _engaged
	beam_material.set_shader_parameter("load", load)
	lens_material.set_shader_parameter("pulse", load)

	# Drehung: ruhiges Kreiseln, beim Rütteln stattdessen das Kippen des
	# Handgelenks - quer zur Schlagrichtung, damit Weg und Drehung als eine
	# Bewegung lesen. Ungepackt gibt der Takt die Kippe vor, gepackt das
	# Zieh-Tempo des Spielers. Spieler-Impulse federn dorthin zurück.
	var target := IDLE_SPIN
	var damp := SPIN_DAMP
	if state == State.SHAKE and not grabbed:
		target = _rock_axis() * cos(shake_t * SHAKE_RATE) * ROCK_SPEED
		damp = SHAKE_SPIN_DAMP  # träge Federung würde den schnellen Takt wegglätten
	elif grabbed and (state == State.SHAKE or state == State.POISED):
		# Gepackt kippt die Hülle wie ein Becher in der schwingenden Hand: sie
		# hängt der Zugrichtung hinterher, jede Umkehr peitscht sie zurück. Das
		# schwenkt die Schwerkraft IN der Hülle - daher kommt das Auf und Ab der
		# Würfel, nicht aus der Höhe der Hülle.
		var flat := Vector3(_shell_vel.x, 0.0, _shell_vel.z)
		target = (flat.cross(Vector3.UP) * DRAG_ROCK_GAIN + IDLE_SPIN).limit_length(MAX_SPIN)
		damp = SHAKE_SPIN_DAMP
	angular_velocity = angular_velocity.lerp(target, clampf(damp * delta, 0.0, 1.0))
	var speed := angular_velocity.length()
	if speed > 0.001:
		shell_root.global_rotate(angular_velocity / speed, speed * delta)

	_track_jolt(delta)
	_reversal_cd = maxf(_reversal_cd - delta, 0.0)

	# Weicher Käfig: Würfel jenseits NET_RADIUS auf die Kugel zurückklemmen und
	# die RADIALE Auswärts-Geschwindigkeit federnd umkehren (NET_BOUNCE), damit
	# er sich wie die Platten anfühlt; das Taumeln läuft tangential weiter.
	var center := shell_root.global_position
	for die in ghosts:
		var body: RigidBody3D = die.get_node("RigidBody3D")
		if body.freeze:
			continue
		var offset := body.global_position - center
		if offset.length() > NET_RADIUS:
			var radial := offset.normalized()
			body.global_position = center + radial * NET_RADIUS
			var outward := maxf(body.linear_velocity.dot(radial), 0.0)
			body.linear_velocity -= radial * outward * (1.0 + NET_BOUNCE)
			if outward > 1.0:
				flash_face(_face_toward(radial), clampf(outward / 8.0, 0.35, 1.0))
		# Deckel RELATIV zur Hülle: absolut geklemmt blieben die Würfel bei
		# schnellem Rütteln hinter der Hülle zurück und klebten an der
		# nachlaufenden Platte, statt zu springen.
		var rel := body.linear_velocity - _shell_vel
		if rel.length() > GHOST_MAX_SPEED:
			body.linear_velocity = _shell_vel + rel.limit_length(GHOST_MAX_SPEED)

## Federweg der Hülle: sie hängt wie ein Gewicht an der Zieh-Hand. Je weiter
## sie hinterherhinkt, desto tiefer sinkt die Ruhelage; beim Stoppen oder
## Umkehren wirft die Feder sie hoch - gemessen am eigenen Grundtempo, damit
## sie um die Rüttel-Ebene schwingt statt dauerhaft tief zu hängen. So
## entsteht das Auf und Ab aus einer Maus, die nur X/Z liefert. Ungepackt
## (lag = 0) klingt sie aus - das Auto-Rütteln hat sein Auf/Ab schon in
## SHAKE_STROKE.
func _update_lift(delta: float, lag: float) -> void:
	_lag_avg = lerpf(_lag_avg, lag, clampf(LAG_AVG_RATE * delta, 0.0, 1.0))
	var rest := LIFT_SAG * (_lag_avg - lag)
	lift_vel += (LIFT_STIFF * (rest - lift) - LIFT_DAMP * lift_vel) * delta
	lift = clampf(lift + lift_vel * delta, -LIFT_MAX, LIFT_MAX)

## Ruck der Hülle und daraus die Trägheit des Würfelschwarms. Die Differenz
## zwischen sofortiger und nachlaufender Geschwindigkeit ist proportional zur
## Beschleunigung, aber schon geglättet - sie wirkt als Scheinkraft GEGEN die
## Bewegung: beim Reißen sacken alle Würfel nach hinten, beim Stoppen schießen
## sie nach vorn. Jede Schlagumkehr wirft sie zusätzlich hoch; das ist der
## sichtbare Wurf im Becher.
func _track_jolt(delta: float) -> void:
	var raw := (shell_root.global_position - _prev_shell_pos) / maxf(delta, 0.0001)
	_prev_shell_pos = shell_root.global_position
	var jolt := (raw - _shell_vel).limit_length(GHOST_JOLT_MAX)
	_shell_vel = _shell_vel.lerp(raw, clampf(VEL_SMOOTH * delta, 0.0, 1.0))
	if state != State.SHAKE and state != State.POISED:
		return
	var flat := Vector2(_shell_vel.x, _shell_vel.z)
	var swung := flat.length() > REVERSAL_MIN_SPEED and flat.dot(_prev_flat) < 0.0
	var reversal := swung and _reversal_cd <= 0.0
	_prev_flat = flat
	if reversal:
		_reversal_cd = REVERSAL_COOLDOWN
	for die in ghosts:
		var body: RigidBody3D = die.get_node("RigidBody3D")
		if body.freeze:
			continue
		body.apply_central_force(-jolt * GHOST_INERTIA * body.mass)
		if reversal:
			body.apply_central_impulse(Vector3.UP * REVERSAL_KICK)
			body.angular_velocity += Vector3(randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * REVERSAL_TUMBLE

## Innen-Aufprall eines Taumel-Würfels: die Facette in seiner Richtung blitzt,
## Stärke nach Aufprallgeschwindigkeit.
func _on_ghost_contact(other: Node, body: RigidBody3D) -> void:
	if other != shell_body:
		return
	var dir := (body.global_position - shell_root.global_position).normalized()
	flash_face(_face_toward(dir), clampf(body.linear_velocity.length() / 8.0, 0.35, 1.0))

## Facette, die in Weltrichtung dir zeigt.
func _face_toward(dir: Vector3) -> int:
	var local_dir := shell_root.global_basis.inverse() * dir
	var best := 0
	var best_dot := -INF
	for i in face_normals.size():
		var d := face_normals[i].dot(local_dir)
		if d > best_dot:
			best_dot = d
			best = i
	return best

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
