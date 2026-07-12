class_name DiceAudio
extends Node3D
## Physik-Sound der 6 Spielwürfel: Aufprall-Klicks (Würfel↔Würfel, Boden,
## Grubenwand), Roll-Ticks während des Taumelns und ein kleines Wackeln beim
## Zur-Ruhe-Kommen. Hört direkt auf die Kontakte der RigidBodys (siehe setup) -
## die Lautstärke skaliert mit der Aufprallgeschwindigkeit, denn nichts klingt
## künstlicher als sechs gleichlaute Klicks.
##
## Die Samples liegen als kleine Bänke unter SFX_DIR (Platzhalter, synthetisch
## erzeugt - echte Aufnahmen einfach gleich benennen und ersetzen). Je Bank ein
## AudioStreamRandomizer mit Pitch-/Lautstärke-Streuung: 4-6 Dateien klingen so
## wie Dutzende. Der Ordner ist nach Würfel-Material benannt (plastic/), damit
## Glas-/Metallwürfel später eigene Bänke bekommen können (siehe DieMaterial).

## Materialordner der Sample-Bänke; Dateinamen je Kontaktart siehe _BANKS.
const SFX_DIR := "res://assets/sfx/dice/plastic/"

## Dateilisten je Kontaktart (Bank-Name -> Dateinamen ohne Ordner).
const _BANKS := {
	"click": ["click_1.wav", "click_2.wav", "click_3.wav", "click_4.wav", "click_5.wav"],
	"floor": ["floor_1.wav", "floor_2.wav", "floor_3.wav", "floor_4.wav", "floor_5.wav"],
	"wall": ["wall_1.wav", "wall_2.wav", "wall_3.wav", "wall_4.wav"],
	"tick": ["tick_1.wav", "tick_2.wav", "tick_3.wav", "tick_4.wav"],
	"settle": ["settle_1.wav", "settle_2.wav", "settle_3.wav"],
}

## Zufallsstreuung je Abspielvorgang - macht aus wenigen Samples viele.
const RANDOM_PITCH := 1.1
const RANDOM_VOLUME_DB := 2.5

## Aufpralle unterhalb dieser Relativgeschwindigkeit bleiben stumm (werden vom
## Roll-Ticken abgedeckt) - verhindert Dauergeklicker beim Ausrollen.
const MIN_IMPACT_SPEED := 1.5
## Ab dieser Geschwindigkeit spielt ein Aufprall mit voller Lautstärke.
const FULL_VOLUME_SPEED := 14.0
## Leisester Aufprall (bei MIN_IMPACT_SPEED); dazwischen wird interpoliert.
const MIN_VOLUME_DB := -22.0

## Frühestens alle so viele Millisekunden ein Aufprall-Sound je Würfel - sechs
## Würfel in der Grube feuern sonst wie ein Maschinengewehr.
const IMPACT_COOLDOWN_MS := 60

## Roll-Ticks: nur wenn der Würfel Bodenkontakt hat und schneller dreht als
## TICK_MIN_ANGULAR; Abstand und Lautstärke folgen der Drehgeschwindigkeit.
const TICK_MIN_ANGULAR := 3.0
const TICK_FULL_ANGULAR := 12.0
const TICK_INTERVAL_MIN := 0.05
const TICK_INTERVAL_MAX := 0.12
const TICK_MIN_DB := -20.0
const TICK_MAX_DB := -8.0

const SETTLE_VOLUME_DB := -10.0

## Gleichzeitig spielende 3D-Player; bei Vollauslastung wird der älteste
## überschrieben (Voice Stealing).
const PLAYER_POOL_SIZE := 12
## Ab dieser Entfernung (in Einheiten) beginnt die 3D-Abschwächung spürbar zu
## greifen - grob auf Grubenradius und Kamerahöhe abgestimmt.
const UNIT_SIZE := 14.0

var bodies: Array[RigidBody3D] = []
## Ruheerkennung fürs Settle-Geräusch (siehe _physics_process); optional.
var controller: DiceController

var _streams := {}  # Bank-Name -> AudioStreamRandomizer (leer, wenn Dateien fehlen)
var _players: Array[AudioStreamPlayer3D] = []
var _player_started_ms: Array[int] = []  # Startzeit je Pool-Player (Voice Stealing)
var _last_impact_ms: Array[int] = []  # je Würfel: letzter Aufprall-Sound (Cooldown)
var _tick_timers: Array[float] = []  # je Würfel: Restzeit bis zum nächsten Roll-Tick
var _prev_settled: Array[bool] = []  # Ruhezustand des letzten Ticks (Flanke -> Settle-Sound)

## Verdrahtet die Würfelkörper: aktiviert deren Kontaktmeldung und baut den
## Player-Pool. controller liefert die Ruheerkennung (Settle-Sound) und die
## Sichtbarkeit (reset() lässt sonst unsichtbare Würfel "einrasten").
func setup(p_bodies: Array[RigidBody3D], p_controller: DiceController) -> void:
	bodies = p_bodies
	controller = p_controller
	_load_banks()

	for i in bodies.size():
		var body := bodies[i]
		body.contact_monitor = true
		body.max_contacts_reported = 6
		body.body_entered.connect(_on_die_contact.bind(i))
		_last_impact_ms.append(0)
		_tick_timers.append(0.0)
		_prev_settled.append(true)

	for i in PLAYER_POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.name = "Voice%d" % i
		player.unit_size = UNIT_SIZE
		add_child(player)
		_players.append(player)
		_player_started_ms.append(0)

## Aufprall eines Würfels (body_entered): Kontaktart am Gegenüber ablesen und
## mit geschwindigkeitsabhängiger Lautstärke abspielen.
func _on_die_contact(other: Node, index: int) -> void:
	var body := bodies[index]
	var speed := body.linear_velocity.length()
	if other is RigidBody3D:
		speed = (body.linear_velocity - (other as RigidBody3D).linear_velocity).length()
	if speed < MIN_IMPACT_SPEED:
		return

	var now := Time.get_ticks_msec()
	if now - _last_impact_ms[index] < IMPACT_COOLDOWN_MS:
		return
	_last_impact_ms[index] = now

	var bank := "floor"
	if other is RigidBody3D:
		bank = "click"
	elif other.is_in_group("pit_wall"):
		bank = "wall"

	var strength := clampf((speed - MIN_IMPACT_SPEED) / (FULL_VOLUME_SPEED - MIN_IMPACT_SPEED), 0.0, 1.0)
	_play(bank, body.global_position, lerpf(MIN_VOLUME_DB, 0.0, strength))

func _physics_process(delta: float) -> void:
	for i in bodies.size():
		_process_rolling(i, delta)
		_process_settle(i)

## Roll-Ticks: Ein taumelnder Würfel erzeugt keine body_entered-Ereignisse
## (Dauerkontakt), also streuen wir leise Ticks, solange er sich in Kontakt
## drehend bewegt - Abstand zufällig, Lautstärke nach Drehgeschwindigkeit.
func _process_rolling(index: int, delta: float) -> void:
	var body := bodies[index]
	var angular := body.angular_velocity.length()
	if angular < TICK_MIN_ANGULAR or body.get_colliding_bodies().is_empty():
		return
	_tick_timers[index] -= delta
	if _tick_timers[index] > 0.0:
		return
	_tick_timers[index] = randf_range(TICK_INTERVAL_MIN, TICK_INTERVAL_MAX)
	var strength := clampf((angular - TICK_MIN_ANGULAR) / (TICK_FULL_ANGULAR - TICK_MIN_ANGULAR), 0.0, 1.0)
	_play("tick", body.global_position, lerpf(TICK_MIN_DB, TICK_MAX_DB, strength))

## Settle-Wackeln genau auf der Flanke "kommt zur Ruhe" (settled false -> true).
## Nur für sichtbare Würfel - controller.reset() setzt settled ebenfalls auf
## true, aber dann liegen die Würfel unsichtbar außerhalb des Spiels.
func _process_settle(index: int) -> void:
	if controller == null:
		return
	var now_settled: bool = controller.settled[index]
	var was_settled: bool = _prev_settled[index]
	_prev_settled[index] = now_settled
	if now_settled and not was_settled and controller.roots[index].visible:
		_play("settle", bodies[index].global_position, SETTLE_VOLUME_DB)

## Spielt eine Bank an einer Weltposition über den Pool ab; sind alle Player
## beschäftigt, wird der am längsten laufende geopfert (unhörbar bei so kurzen
## Samples). Fehlende Bänke (Dateien nicht importiert/gelöscht) sind stumm.
func _play(bank: String, at: Vector3, volume_db: float) -> void:
	var stream: AudioStreamRandomizer = _streams.get(bank)
	if stream == null:
		return
	var best := 0
	var best_started: int = _player_started_ms[0]
	for i in _players.size():
		if not _players[i].playing:
			best = i
			break
		if _player_started_ms[i] < best_started:
			best = i
			best_started = _player_started_ms[i]
	var player := _players[best]
	player.stream = stream
	player.global_position = at
	player.volume_db = volume_db
	player.play()
	_player_started_ms[best] = Time.get_ticks_msec()

## Lädt jede Bank in einen AudioStreamRandomizer; fehlende Dateien werden
## übersprungen, eine komplett leere Bank bleibt aus dem Dictionary (siehe
## _play) - so bricht weder ein Headless-Testlauf noch ein halb gefüllter
## Sample-Ordner irgendetwas.
func _load_banks() -> void:
	for bank: String in _BANKS:
		var randomizer := AudioStreamRandomizer.new()
		randomizer.random_pitch = RANDOM_PITCH
		randomizer.random_volume_offset_db = RANDOM_VOLUME_DB
		var count := 0
		for file_name: String in _BANKS[bank]:
			var path: String = SFX_DIR + file_name
			if not ResourceLoader.exists(path):
				continue
			var stream: AudioStream = load(path)
			if stream == null:
				continue
			randomizer.add_stream(count, stream)
			count += 1
		if count > 0:
			_streams[bank] = randomizer
