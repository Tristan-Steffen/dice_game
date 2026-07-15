class_name DiceAudio
extends Node3D
## Physik-Sound der 6 Spielwürfel: Aufprall-Klicks, Roll-Ticks und ein
## Settle-Wackeln. Lautstärke skaliert mit der Aufprallgeschwindigkeit.
## Samples: kleine Bänke unter SFX_DIR, je Bank ein AudioStreamRandomizer
## mit Pitch-/Lautstärke-Streuung. Ordner nach Würfel-Material benannt,
## damit Glas-/Metallwürfel später eigene Bänke bekommen können.

const SFX_DIR := "res://assets/sfx/dice/plastic/"

const _BANKS := {
	"click": ["click_1.mp3", "click_2.mp3", "click_3.mp3", "click_4.mp3", "click_5.mp3", "click_6.mp3"],
	"floor": ["floor_1.mp3", "floor_2.mp3", "floor_3.mp3"],
	"wall": ["wall_1.mp3", "wall_2.mp3", "wall_3.mp3", "wall_4.mp3"],
	"tick": ["tick_1.mp3", "tick_2.mp3", "tick_3.mp3"],
	"settle": ["settle_1.mp3", "settle_2.mp3", "settle_3.mp3"],
}

const RANDOM_PITCH := 1.1
const RANDOM_VOLUME_DB := 2.5

## Leisere Aufpralle bleiben stumm (das Roll-Ticken deckt sie ab).
const MIN_IMPACT_SPEED := 1.5
const FULL_VOLUME_SPEED := 14.0
const MIN_VOLUME_DB := -22.0

## Cooldown je Würfel - sechs Würfel feuern sonst wie ein Maschinengewehr.
const IMPACT_COOLDOWN_MS := 60

## Roll-Ticks nur bei Bodenkontakt und ausreichender Drehgeschwindigkeit.
const TICK_MIN_ANGULAR := 3.0
const TICK_FULL_ANGULAR := 12.0
const TICK_INTERVAL_MIN := 0.05
const TICK_INTERVAL_MAX := 0.12
const TICK_MIN_DB := -20.0
const TICK_MAX_DB := -8.0

const SETTLE_VOLUME_DB := -10.0

## Gleichzeitige 3D-Player; bei Vollauslastung wird der älteste geopfert.
const PLAYER_POOL_SIZE := 12
## Ab hier greift die 3D-Abschwächung spürbar (auf Grube/Kamerahöhe abgestimmt).
const UNIT_SIZE := 14.0

var bodies: Array[RigidBody3D] = []
var controller: DiceController  # Ruheerkennung fürs Settle-Geräusch

var _streams := {}  # Bank-Name -> AudioStreamRandomizer (fehlt bei leerer Bank)
var _players: Array[AudioStreamPlayer3D] = []
var _player_started_ms: Array[int] = []
var _last_impact_ms: Array[int] = []
var _tick_timers: Array[float] = []
var _prev_settled: Array[bool] = []

## Verdrahtet die Würfelkörper (aktiviert deren Kontaktmeldung) und baut den Player-Pool.
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

## Ein taumelnder Würfel erzeugt keine body_entered-Ereignisse (Dauerkontakt) -
## darum gestreute Ticks, solange er sich in Kontakt drehend bewegt.
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

## Settle-Wackeln auf der Flanke false -> true; nur für sichtbare Würfel
## (reset() setzt settled ebenfalls, aber unsichtbar außerhalb des Spiels).
func _process_settle(index: int) -> void:
	if controller == null:
		return
	var now_settled: bool = controller.settled[index]
	var was_settled: bool = _prev_settled[index]
	_prev_settled[index] = now_settled
	if now_settled and not was_settled and controller.roots[index].visible:
		_play("settle", bodies[index].global_position, SETTLE_VOLUME_DB)

## Spielt eine Bank über den Pool; fehlende Bänke sind stumm.
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

## Fehlende Dateien werden übersprungen, leere Bänke bleiben aus dem
## Dictionary - weder Headless-Tests noch halbe Sample-Ordner brechen etwas.
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
