class_name DiceShell
extends Node3D
## Der WÜRFEL-WIRBEL über der Grube (2026-08-26: erst verlor die Hülle ihr
## sichtbares Ikosaeder samt Projektor, dann das Gerassel, zuletzt den
## Lichtring - sichtbar ist NUR der kreisende Schwarm selbst). Gemischt wird
## als ORBIT: jeder gezogene Würfel jagt auf seiner eigenen Kreisbahn um das
## Wirbel-Zentrum - eigener Radius, eigenes Tempo, sie überholen einander und
## taumeln um die eigene Achse. Die Choreographie ist DETERMINISTISCH
## (Spieler-Wunsch 2026-08-26): keine Zufalls-Phase, kein Zufalls-Drall,
## keine Rempler-Kollisionen, und jede Mischung beginnt auf derselben
## Bahnebene - dasselbe Mischen sieht jedes Mal gleich aus. Die Bahn-Anker
## liegen im
## LOKALRAUM von shell_root: die bestehende Handgelenk-Kippe neigt damit die
## ganze Bahn und die Schüttel-Strokes verschieben sie - der Kessel schwenkt
## wie eine Schale in der Hand. Packt der Spieler den Schwarm (Ziehen),
## schüttelt er selbst und der Wirbel dreht schneller; Loslassen kippt aus:
## die Bahnführung reißt ab, jeder Taumel-Würfel fliegt auf seiner Tangente
## weiter, poured_out feuert, und die echten Würfel ÜBERNEHMEN die Berst-
## Stände samt Lage und Bewegung (release_states - der Wurf setzt fort, was
## der Spieler losgelassen hat). Wann Würfel hinein-/herausfliegen,
## orchestriert scene_root; geworfen wird am Würfeln-Knopf.

## Kollisions-Ebene fürs Packen - scharf nur, solange Würfel darin taumeln:
## sichtbar heißt bedienbar, und sichtbar ist allein der Schwarm.
const CLICK_LAYER := 32

const RADIUS := 3.0          # Hüllmaß des Wirbels (Klickzone, Bahn-Umgriff)
const BOB_AMPLITUDE := 0.12
const BOB_SPEED := 1.2

## Die EINE Würfelgröße - kein eigenes Maß hier: ein Würfel ist überall gleich groß.
const GHOST_SCALE := DiceTrayView.DIE_SCALE
const GHOST_DAMP := 0.05
const GHOST_MAX_SPEED := 26.0  # Sicherheitsventil der Bahnführung (über r·ω·Puls)
## Fester Eigendrall je Bahn-Platz (rad/s) - das Taumeln ist Choreographie,
## kein Zufall, und die niedrige Dämpfung hält es die ganze Mischung.
const TUMBLE_RATE := 6.0

## DIE BAHNEN: Radien und Tempi je Würfel gestaffelt (Goldener Schnitt statt
## Zufall - deterministisch verschieden, nie zwei gleiche), alle in DERSELBEN
## Drehrichtung: wer schneller ist, überholt - das ist der Roulette-Kessel.
const ORBIT_RADIUS_MIN := 1.5
const ORBIT_RADIUS_MAX := 2.55
## Tempo-Band der Bahnen: 2,4-4,2 las sich träge (Spieler-Wort "sluggish"),
## jetzt jagt der Kessel spürbar.
const ORBIT_SPEED_MIN := 3.6   # rad/s
const ORBIT_SPEED_MAX := 6.4
## Eigenwelle je Würfel senkrecht zur Bahn (doppelter Umlauf-Takt): die Bahn
## ist ein flacher Kessel, kein Reifen. 0,35 las sich als schwebendes Irren -
## flacher wirkt der Kessel entschieden.
const ORBIT_BOB := 0.2
## Bahnführung als Feder auf GESCHWINDIGKEIT: Anker-Tempo plus Zugfehler.
## Straff (Spieler-Wort "quick, decisive"): der Würfel KLEBT an seiner Bahn,
## nur der Schüttel-Ruck schwingt noch sichtbar nach.
const ORBIT_STIFF := 12.0      # 1/s: Positionsfehler -> Zieltempo
const ORBIT_GRIP := 14.0       # 1/s: Angleich an das Zieltempo
## Der Takt treibt den Wirbel: ungepackt pulst das Tempo im Schüttel-Takt,
## gepackt dreht er mit dem Zieh-Tempo des Spielers hoch.
const ORBIT_PULSE := 0.35
const ORBIT_DRAG_GAIN := 0.10  # Einheit/s Zieh-Tempo -> Tempo-Aufschlag
const ORBIT_DRAG_MAX := 1.2

const IDLE_SPIN := Vector3(0.12, 0.35, 0.08)  # ruhige Dauerdrehung der Bahnebene
const MAX_SPIN := 7.0
const SPIN_DAMP := 1.6        # Rückfederung Richtung Ziel-Drehung (1/s)
const DRAG_SENSITIVITY := 0.06  # Maus-Pixel -> rad/s

const SHAKE_HEIGHT := 8.0     # Rüttel-Höhe des Wirbel-Zentrums über der Grube
const SHAKE_OFFSET_Z := 4.0   # Rüttel-Anker rechts der Grubenmitte (Screen-rechts = +Z)
## Becher-Schlag beim Auto-Rütteln: EIN fester Schlagvektor (quer über die
## Grube, dabei auf/ab), im Takt hin und her - kein zufälliges Umherstreifen.
## Ausschlag plus RADIUS bleibt klar innerhalb PIT_HALF_X/Z.
const SHAKE_STROKE := Vector3(0.85, 0.7, 2.2)
## Oberwelle quer zum Schlag (doppelter Takt): macht aus der Geraden die
## flache Acht, die eine Hand beim Schütteln beschreibt. Taktgebunden, also
## rhythmisch statt zufällig.
const SHAKE_ARC := Vector3(0.35, 0.6, 0.0)
## Schlag-Takt: 14 (~2,2 Hz) las sich lahm - jetzt ~3,2 Hz = ~6,4 Schläge/s,
## das Tempo einer wirklich schüttelnden Hand.
const SHAKE_RATE := 20.0      # rad/s des Schlags
## 0 = reiner Sinus (weiche Umkehr), 1 = Dreieck (konstantes Tempo, harte
## Umkehr). Dazwischen liegt der Handgelenk-Schlag.
const SHAKE_SNAP := 0.6
const ROCK_SPEED := 5.0       # rad/s: Kippen quer zur Schlagrichtung
const SHAKE_SPIN_DAMP := 20.0 # das Kippen muss dem schnellen Takt folgen
const DRAG_FOLLOW := 14.0     # Zieh-Folgetempo (1/s) beim manuellen Rütteln
## Manuelles Rütteln: die Maus liefert nur X/Z, das Auf/Ab entsteht daraus.
## Der Zieh-Rückstand (drag_point minus shake_pos) ist dabei das fertig
## geglättete Maß dafür, wie hart der Spieler gerade reißt - DRAG_FOLLOW
## hinkt absichtlich hinterher.
const DRAG_ROCK_GAIN := 0.11  # Zieh-Tempo -> Kipp-Rate (rad/s je Einheit/s)
const LIFT_SAG := 0.28        # Ruhelage sinkt je Einheit Mehr-Rückstand
## Gleitendes Mittel des Rückstands (1/s). Getrieben wird die Feder nur von
## der ABWEICHUNG davon - sonst hinge der Wirbel bei Dauerschütteln bloß
## dauerhaft tief, statt um die Rüttel-Ebene zu schwingen.
const LAG_AVG_RATE := 1.5
const LIFT_STIFF := 240.0     # Federhärte (~2,5 Hz - Tempo eines Handgelenks)
const LIFT_DAMP := 11.0       # Dämpfungsgrad ~0,35: federt sichtbar nach
const LIFT_MAX := 1.6         # Federweg-Grenze (Grubenwände sind 16 hoch)
const VEL_SMOOTH := 10.0      # 1/s: Nachlauf der geglätteten Wirbel-Geschwindigkeit
## Randabstand des Zieh-Ziels zur Grubenwand: > RADIUS, damit die Bahn samt
## Ring innerhalb der Wände bleibt.
const SHAKE_MARGIN := 4.0
const TRAVEL_TIME := 0.6      # Anlauf des Wirbels (Heimat = Rüttel-Anker)
## Ungepackt kippt der Wirbel nach dieser Zeit aus - knapp, aber lang genug,
## dass die Bahn als Bewegung lesbar wird.
const SHUFFLE_MIN_TIME := 0.8

## Der kurze Tangenten-Flug zwischen Bahn-Abriss und Auskippen - der
## Berst-Moment, der Taktgeber von poured_out.
const RELEASE_BURST_TIME := 0.15
const RELEASE_RETURN_TIME := 0.5

## Feuert im Berst-Moment - scene_root schnappt release_states(), räumt die
## Taumel-Würfel ab und wirft die echten damit los (Signalname wie beim Becher).
signal poured_out

## Positions-Zustand des Wirbels; _physics_process führt ihn (keine Positions-
## Tweens - ein Reset kann so nie eine wartende Koroutine hängen lassen).
enum State { HOME, TRAVEL, SHAKE, POISED, RETURN }

var shell_root: Node3D          # das Wirbel-Zentrum; seine Drehung IST die Bahnebene
var ghosts: Array[Node3D] = []  # Taumel-Würfel (Wurzelknoten, Kinder von self)
## Bahn je Taumel-Würfel (index-parallel zu ghosts): radius, speed, phase,
## bob_phase, prev_anchor.
var _orbits: Array[Dictionary] = []
var _orbit_t := 0.0             # gemeinsame Bahn-Zeit (das Tempo pulst darauf)
var _click_zone: StaticBody3D   # Griff am Schwarm - scharf nur mit Würfeln darin

var state := State.HOME
var move_t := 0.0
var move_from := Vector3.ZERO
var grabbed := false            # Spieler hält den Wirbel per Zieh-Geste
var shuffle_time_left := 0.0
var shake_pos := Vector3.ZERO   # Mittelpunkt-Position des Wirbels (lokal)
var shake_t := 0.0              # Takt-Zeit des Schlags (0 bei Rüttel-Beginn)
var drag_point := Vector3.ZERO  # Zieh-Ziel (lokal, siehe drag_to)
var has_drag_point := false
var lift := 0.0                 # Federweg des Wirbels über der Rüttel-Ebene
var lift_vel := 0.0
var _lag_avg := 0.0             # Grundtempo des Schüttelns (siehe LAG_AVG_RATE)
var _shell_vel := Vector3.ZERO  # nachlaufende Weltgeschwindigkeit des Zentrums
var _prev_shell_pos := Vector3.ZERO

var angular_velocity := Vector3.ZERO
var releasing := false
var _time := 0.0
var active_tween: Tween

func _ready() -> void:
	shell_root = Node3D.new()
	shell_root.name = "ShellRoot"
	add_child(shell_root)
	# Der Heimat-Platz ist der Rüttel-Anker über der Grube: ein unsichtbarer
	# Wirbel hat keinen Sockel - er wartet dort, wo gemischt wird, und die
	# gezogenen Würfel sammeln sich direkt über der Grube.
	shell_root.position = _pit_anchor()

	# Klickzone: Kugel um den Wirbel. Sie hängt an shell_root und wandert zum
	# Rüttel-Punkt mit - packbar ist der SCHWARM, wo er gerade kreist, und nur
	# solange Würfel taumeln (sichtbar heißt bedienbar; _sync_zone).
	_click_zone = StaticBody3D.new()
	_click_zone.name = "ClickZone"
	_click_zone.collision_layer = 0
	_click_zone.collision_mask = 0
	var zone_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS + 0.4
	zone_shape.shape = sphere
	_click_zone.add_child(zone_shape)
	shell_root.add_child(_click_zone)
	_prev_shell_pos = shell_root.global_position

## Der Griff lebt nur, solange etwas zu sehen ist: ohne Taumel-Würfel gibt es
## nichts zu packen - geworfen wird am Würfeln-Knopf.
func _sync_zone() -> void:
	if _click_zone != null:
		_click_zone.collision_layer = CLICK_LAYER if has_ghosts() else 0

## Weltposition des Wirbel-Zentrums - Flugziel hineinfliegender Würfel und
## Rückfall-Startpunkt der echten Wurf-Würfel.
func mouth_position() -> Vector3:
	return shell_root.global_position

## Die Berst-Stände des Wirbels: Ort, Lage, Bahn- und Eigendrehung jedes
## Taumel-Würfels im Auskipp-Moment. Die echten Wurf-Würfel übernehmen alle
## vier - der Wurf setzt die Bewegung fort, die der Spieler losgelassen hat,
## statt sie durch eine neue zu ersetzen.
func release_states() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for die in ghosts:
		if die == null or not is_instance_valid(die):
			continue
		var body: RigidBody3D = die.get_node("RigidBody3D")
		out.append({
			"position": body.global_position,
			"basis": body.global_basis.orthonormalized(),
			"velocity": body.linear_velocity,
			"spin": body.angular_velocity,
		})
	return out

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

## Rüttel-Anker: lokaler Ort des Wirbel-Zentrums über der Grube, etwas
## rechts der Mitte.
func _pit_anchor() -> Vector3:
	return to_local(Vector3(DicePit.PIT_CENTER.x, SHAKE_HEIGHT, DicePit.PIT_CENTER.z + SHAKE_OFFSET_Z))

## Nimmt einen gezogenen Würfel auf: baut einen Taumel-Würfel in Tray-Größe
## (Optik über Faces skaliert, Kollisionsbox direkt - ein skalierter
## RigidBody wäre in Jolt tabu) und setzt ihn auf SEINE Bahn: Radius und Tempo
## über den Goldenen Schnitt gestaffelt, Phase, Bob und Eigendrall FEST aus
## dem Bahn-Platz - kein Würfel würfelt hier, die Mischung ist Choreographie
## und sieht jedes Mal gleich aus.
func capture_die(def: DieDefinition, world_pos: Vector3) -> void:
	if ghosts.is_empty():
		# Jeder Schwarm beginnt auf DERSELBEN Bahnebene und am selben Bahn-Stand:
		# frei akkumulierte Ruhe-Drehung und weiterlaufende Bahn-Zeit sind die
		# zwei Zufallsquellen, die kein Platz-Schlüssel deckt.
		shell_root.basis = Basis.IDENTITY
		angular_velocity = Vector3.ZERO
		_orbit_t = 0.0
	var die := DieBuilder.build()
	add_child(die)
	ScreenReflection.mark_reflective(die)
	ghosts.append(die)
	var slot := ghosts.size() - 1
	var spread := TAU * float(slot) / 6.0
	_orbits.append({
		"radius": lerpf(ORBIT_RADIUS_MIN, ORBIT_RADIUS_MAX,
			fmod(float(slot) * 0.6180339887, 1.0)),
		"speed": lerpf(ORBIT_SPEED_MIN, ORBIT_SPEED_MAX,
			fmod(float(slot) * 0.3819660113 + 0.19, 1.0)),
		"phase": spread,
		"bob_phase": TAU * fmod(float(slot) * 0.6180339887, 1.0),
	})

	var body: RigidBody3D = die.get_node("RigidBody3D")
	# Kollisionsfrei nach ALLEN Seiten: die Feder hält jeden Würfel auf seiner
	# Bahn, Rempler wären Rauschen in der Choreographie - und liegen gebliebene
	# echte Würfel in der Grube gehen den Wirbel nichts an.
	body.collision_layer = 0
	body.collision_mask = 0
	body.gravity_scale = 0.0  # die Bahn trägt - Schwerkraft zöge den Kessel schief
	body.linear_damp = GHOST_DAMP
	body.angular_damp = GHOST_DAMP
	var shape: BoxShape3D = die.get_node("RigidBody3D/CollisionShape3D").shape
	shape.size = Vector3.ONE * DieBuilder.HALF_EXTENT * 2.0 * GHOST_SCALE
	var faces: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
	faces.scale = Vector3.ONE * GHOST_SCALE
	# Die Taumel-Würfel kreisen über der Grube - eine Lache am Grubenboden
	# hätte keinen Bezug und würde unter dem Wirbel flackern.
	faces.set_pool_enabled(false)
	faces.apply_definition(def)
	faces.set_tint(DiceController.KIND_TINTS.get(def.style_id, Color.WHITE))

	body.global_position = world_pos
	# Fester Taumel: die Drehachse wandert mit dem Bahn-Platz um den Kreis.
	body.angular_velocity = Vector3(cos(spread), 0.7, sin(spread)).normalized() * TUMBLE_RATE
	_sync_zone()

func clear_ghosts() -> void:
	for die in ghosts:
		die.queue_free()
	ghosts.clear()
	_orbits.clear()
	_sync_zone()

func has_ghosts() -> bool:
	return not ghosts.is_empty()

## Mischen: der Wirbel läuft an und kreist mindestens SHUFFLE_MIN_TIME über der
## Grube. Solange der Spieler ihn gepackt hält (set_grabbed), läuft der Timer
## nicht ab - Loslassen kippt sofort aus. Kehrt zurück, sobald das Mischen
## vorbei ist (Zustand POISED - bereit für play_release).
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
## wo der Spieler den Wirbel gerade hingezogen hat.
func set_grabbed(value: bool) -> void:
	if grabbed and not value and state == State.SHAKE:
		shuffle_time_left = 0.0
	grabbed = value
	if not value:
		has_drag_point = false

## Zieh-Ziel beim manuellen Rütteln: Weltpunkt (Maus auf der Rüttel-Ebene),
## auf den Grubeninnenraum geklemmt - der Spieler schiebt den Wirbel frei
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
## um die Kamera-Rechtsachse) - er neigt die Bahnebene des Wirbels.
func spin_impulse(relative: Vector2, camera: Camera3D) -> void:
	var axis_x := camera.global_basis.x.normalized() if camera != null else Vector3.RIGHT
	angular_velocity += (Vector3.UP * relative.x + axis_x * relative.y) * DRAG_SENSITIVITY
	angular_velocity = angular_velocity.limit_length(MAX_SPIN)

## Auskippen (an Ort und Stelle über der Grube): die Bahnführung reißt ab -
## jeder Taumel-Würfel fliegt den Berst-Augenblick auf seiner Tangente frei
## weiter (kein Einfrieren: ein stehender Schwarm bräche die Bewegung, die der
## Wurf fortsetzen soll). poured_out feuert im Berst-Moment, scene_root
## schnappt release_states() und räumt ab; der unsichtbare Wirbel kehrt heim.
func play_release() -> Tween:
	_kill_active_tween()
	releasing = true
	state = State.POISED
	active_tween = create_tween()
	active_tween.tween_interval(RELEASE_BURST_TIME)
	active_tween.tween_callback(poured_out.emit)
	active_tween.tween_callback(_begin_return)
	active_tween.tween_interval(RELEASE_RETURN_TIME)
	active_tween.tween_callback(func() -> void: releasing = false)
	return active_tween

## Defensiv-Reset (Spielneustart): Taumel-Würfel weg, Wirbel kehrt heim. Ein
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

func _physics_process(delta: float) -> void:
	_time += delta
	var home := _pit_anchor()
	var bob := sin(_time * BOB_SPEED)
	match state:
		State.HOME:
			shell_root.position = home + Vector3.UP * (bob * BOB_AMPLITUDE)
		State.TRAVEL:
			move_t += delta
			var k := smoothstep(0.0, 1.0, clampf(move_t / TRAVEL_TIME, 0.0, 1.0))
			shell_root.position = move_from.lerp(_pit_anchor(), k)
			if move_t >= TRAVEL_TIME:
				state = State.SHAKE
				shuffle_time_left = SHUFFLE_MIN_TIME
				shake_pos = shell_root.position
				shake_t = 0.0  # Takt bei 0 - der erste Schlag startet aus der Ruhe
				_lag_avg = 0.0
		State.SHAKE:
			# Gepackt folgt der Wirbel EXAKT dem Zieh-Ziel (kein Eigenleben - der
			# Spieler schüttelt selbst), sonst schlägt er im festen Takt hin und
			# her wie ein Becher in der Hand; die Bahn-Anker nehmen die Würfel
			# federnd mit. Timer-Ablauf ZUERST prüfen - nach dem Loslassen darf
			# kein Schlag den Wirbel vom Loslass-Punkt wegreißen.
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

	# Drehung: ruhiges Kreiseln, beim Rütteln stattdessen das Kippen des
	# Handgelenks - quer zur Schlagrichtung, damit Weg und Drehung als eine
	# Bewegung lesen. Die Drehung von shell_root IST die Bahnebene: mit ihr
	# kippt der ganze Kessel samt Ring. Spieler-Impulse federn dorthin zurück.
	var target := IDLE_SPIN
	var damp := SPIN_DAMP
	if state == State.SHAKE and not grabbed:
		target = _rock_axis() * cos(shake_t * SHAKE_RATE) * ROCK_SPEED
		damp = SHAKE_SPIN_DAMP  # träge Federung würde den schnellen Takt wegglätten
	elif grabbed and (state == State.SHAKE or state == State.POISED):
		# Gepackt kippt die Bahn wie eine Schale in der schwingenden Hand: sie
		# hängt der Zugrichtung hinterher, jede Umkehr peitscht sie zurück.
		var flat := Vector3(_shell_vel.x, 0.0, _shell_vel.z)
		target = (flat.cross(Vector3.UP) * DRAG_ROCK_GAIN + IDLE_SPIN).limit_length(MAX_SPIN)
		damp = SHAKE_SPIN_DAMP
	angular_velocity = angular_velocity.lerp(target, clampf(damp * delta, 0.0, 1.0))
	var speed := angular_velocity.length()
	if speed > 0.001:
		shell_root.global_rotate(angular_velocity / speed, speed * delta)

	_track_shell_vel(delta)
	_drive_orbit(delta)

## DER WIRBEL: jeder Taumel-Würfel wird federnd auf seinen wandernden
## Bahn-Anker gezogen. Die Anker liegen im Lokalraum von shell_root - Kippe
## und Strokes des Schüttelns bewegen also die ganze Bahn, und die Feder
## lässt den Schwarm sichtbar nachschwingen. Das Tempo pulst ungepackt im
## Schüttel-Takt und dreht gepackt mit dem Zieh-Tempo hoch.
func _drive_orbit(delta: float) -> void:
	if releasing:
		return  # Bahn-Abriss: die Würfel fliegen ihre Tangente frei zu Ende
	var rate := 1.0
	if state == State.SHAKE or state == State.POISED:
		if grabbed:
			rate = 1.0 + clampf(_shell_vel.length() * ORBIT_DRAG_GAIN, 0.0, ORBIT_DRAG_MAX)
		elif state == State.SHAKE:
			rate = 1.0 + ORBIT_PULSE * (0.5 + 0.5 * sin(shake_t * SHAKE_RATE))
	_orbit_t += delta * rate
	for g in ghosts.size():
		var die := ghosts[g]
		if die == null or not is_instance_valid(die) or g >= _orbits.size():
			continue
		var body: RigidBody3D = die.get_node("RigidBody3D")
		if body.freeze:
			continue
		var o: Dictionary = _orbits[g]
		var th: float = float(o["phase"]) + _orbit_t * float(o["speed"])
		var local := Vector3(cos(th) * float(o["radius"]),
			sin(th * 2.0 + float(o["bob_phase"])) * ORBIT_BOB,
			sin(th) * float(o["radius"]))
		var anchor: Vector3 = shell_root.global_transform * local
		var prev: Vector3 = o.get("prev_anchor", anchor)
		o["prev_anchor"] = anchor
		var anchor_vel := ((anchor - prev) / maxf(delta, 0.0001)).limit_length(GHOST_MAX_SPEED)
		var desired := anchor_vel + (anchor - body.global_position) * ORBIT_STIFF
		body.linear_velocity = body.linear_velocity.lerp(
			desired.limit_length(GHOST_MAX_SPEED), clampf(ORBIT_GRIP * delta, 0.0, 1.0))

## Federweg des Wirbels: er hängt wie ein Gewicht an der Zieh-Hand. Je weiter
## er hinterherhinkt, desto tiefer sinkt die Ruhelage; beim Stoppen oder
## Umkehren wirft die Feder ihn hoch - gemessen am eigenen Grundtempo, damit
## er um die Rüttel-Ebene schwingt statt dauerhaft tief zu hängen. So
## entsteht das Auf und Ab aus einer Maus, die nur X/Z liefert. Ungepackt
## (lag = 0) klingt sie aus - das Auto-Rütteln hat sein Auf/Ab schon in
## SHAKE_STROKE.
func _update_lift(delta: float, lag: float) -> void:
	_lag_avg = lerpf(_lag_avg, lag, clampf(LAG_AVG_RATE * delta, 0.0, 1.0))
	var rest := LIFT_SAG * (_lag_avg - lag)
	lift_vel += (LIFT_STIFF * (rest - lift) - LIFT_DAMP * lift_vel) * delta
	lift = clampf(lift + lift_vel * delta, -LIFT_MAX, LIFT_MAX)

## Nachlaufende Geschwindigkeit des Wirbel-Zentrums - das geglättete Maß, aus
## dem gepackte Kippe und Tempo-Aufschlag lesen.
func _track_shell_vel(delta: float) -> void:
	var raw := (shell_root.global_position - _prev_shell_pos) / maxf(delta, 0.0001)
	_prev_shell_pos = shell_root.global_position
	_shell_vel = _shell_vel.lerp(raw, clampf(VEL_SMOOTH * delta, 0.0, 1.0))

func _kill_active_tween() -> void:
	if active_tween:
		active_tween.kill()
		active_tween = null
