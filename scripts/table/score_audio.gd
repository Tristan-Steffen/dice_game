class_name ScoreAudio
extends Node
## Klang der Wertungs-Zeremonie: Punkt-Tick, Mult-Puls, Krit, Aufladen und
## Einschlag. Platzhalter-Töne werden beim Start synthetisiert; liegt unter
## SFX_DIR eine Datei gleichen Namens (.wav/.ogg), ersetzt sie den Ton.
## Nicht positionsgebunden: Wertung ist Anzeige, kein Ort im Raum.
## Der Bus samt Hall und Limiter steht in default_bus_layout.tres.

const SFX_DIR := "res://assets/sfx/score/"
const BUS_NAME := "Score"
const MIX_RATE := 44100

## Pentatonische Leiter in Halbtönen - aufsteigende Ticks klingen immer gefällig.
const LADDER := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
## Nahezu gleichzeitige Ticks verschmelzen, sonst knattert es.
const MIN_TICK_GAP_MS := 35

const TICK_DB := -9.0
const MULT_DB := -6.0
const CRIT_DB := -5.0
const RISER_DB := -12.0
const SLAM_DB := -3.0
const TOTAL_DB := -8.0

var _streams := {}
var _playback: AudioStreamPlaybackPolyphonic
var _base_step := 0
var _mult_step := 0
var _last_tick_ms := {}

func _ready() -> void:
	var riser_len := TableScreen.MERGE_CHARGE_TIME + TableScreen.MERGE_ORBIT_TIME + TableScreen.MERGE_HITSTOP
	_streams = {
		"tick": _load_or(&"tick", _synth_tick),
		"mult": _load_or(&"mult", _synth_mult),
		"crit": _load_or(&"crit", _synth_crit),
		"riser": _load_or(&"riser", _synth_riser.bind(riser_len)),
		"slam": _load_or(&"slam", _synth_slam.bind(false)),
		"slam_goal": _load_or(&"slam_goal", _synth_slam.bind(true)),
	}
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 24
	var player := AudioStreamPlayer.new()
	player.name = "Voices"
	player.stream = poly
	player.bus = BUS_NAME if AudioServer.get_bus_index(BUS_NAME) != -1 else &"Master"
	add_child(player)
	player.play()
	_playback = player.get_stream_playback() as AudioStreamPlaybackPolyphonic

## Neue Hand: beide Leitern beginnen wieder unten.
func begin_hand() -> void:
	_base_step = 0
	_mult_step = 0

func on_score_raised(base_up: bool, mult_up: bool) -> void:
	if base_up and _gap_ok("tick"):
		_play("tick", TICK_DB, _ladder_pitch(_base_step))
		_base_step += 1
	if mult_up and _gap_ok("mult"):
		_play("mult", MULT_DB, _ladder_pitch(_mult_step))
		_mult_step += 1

func on_crit() -> void:
	_play("crit", CRIT_DB)

func on_merge_started() -> void:
	_play("riser", RISER_DB)

func on_total_slammed(clears_goal: bool) -> void:
	_play("slam_goal" if clears_goal else "slam", SLAM_DB)

## Nach-Schritte auf der Summe: der Tick eine Oktave über dem aktuellen Leiterstand.
func on_total_raised() -> void:
	if _gap_ok("tick"):
		_play("tick", TOTAL_DB, _ladder_pitch(_base_step) * 2.0)
		_base_step += 1

func _ladder_pitch(step: int) -> float:
	var semis: int = LADDER[mini(step, LADDER.size() - 1)]
	return pow(2.0, semis / 12.0)

func _gap_ok(key: String) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_last_tick_ms.get(key, -1000)) < MIN_TICK_GAP_MS:
		return false
	_last_tick_ms[key] = now
	return true

func _play(key: String, db: float, pitch := 1.0) -> void:
	if _playback == null or not _streams.has(key):
		return
	_playback.play_stream(_streams[key], 0.0, db, pitch)

func _load_or(file_name: StringName, synth: Callable) -> AudioStream:
	for ext in ["wav", "ogg"]:
		var path := "%s%s.%s" % [SFX_DIR, file_name, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return synth.call()

#region Platzhalter-Synthese

## Gläsernes Klingen: Grundton plus schnell verklingende, leicht unharmonische Obertöne.
func _synth_tick() -> AudioStreamWAV:
	var f := 784.0  # G5
	return _render(0.35, func(t: float) -> float:
		var env := _attack(t, 0.003)
		return env * (exp(-t / 0.09) * sin(TAU * f * t)
			+ 0.35 * exp(-t / 0.05) * sin(TAU * f * 2.0 * t)
			+ 0.15 * exp(-t / 0.035) * sin(TAU * f * 3.01 * t)
			+ 0.08 * exp(-t / 0.015) * sin(TAU * f * 4.2 * t)) * 0.6)

## Wärmerer, tieferer Puls mit Sub-Oktave und leichter Schwebung.
func _synth_mult() -> AudioStreamWAV:
	var f := 392.0  # G4
	return _render(0.6, func(t: float) -> float:
		var env := _attack(t, 0.006) * exp(-t / 0.18)
		return env * (sin(TAU * f * t) + 0.6 * sin(TAU * f * 1.006 * t)
			+ 0.25 * sin(TAU * f * 2.0 * t) + 0.4 * sin(TAU * f * 0.5 * t)) * 0.4)

## Elektrischer Schlag: abwärts gleitender, angezerrter Ton plus Rauschstoß.
func _synth_crit() -> AudioStreamWAV:
	var phase := [0.0]
	return _render(0.4, func(t: float) -> float:
		var freq := 1800.0 * pow(300.0 / 1800.0, minf(t / 0.25, 1.0))
		phase[0] += TAU * freq / MIX_RATE
		var zap := tanh(3.0 * sin(phase[0])) * exp(-t / 0.12)
		var noise := randf_range(-1.0, 1.0) * exp(-t / 0.02)
		var bell := sin(TAU * 1568.0 * t) * exp(-t / 0.15) * 0.3
		return (zap * 0.35 + noise * 0.25 + bell * 0.8) * _attack(t, 0.002))

## Aufladen bis zum Einschlag: steigender Ton mit schneller werdendem Tremolo.
func _synth_riser(length: float) -> AudioStreamWAV:
	var phase := [0.0]
	return _render(length, func(t: float) -> float:
		var p := t / length
		var freq := 220.0 * pow(4.0, p * p)
		phase[0] += TAU * freq / MIX_RATE
		var trem := 0.75 + 0.25 * sin(TAU * lerpf(6.0, 22.0, p) * t)
		return (sin(phase[0]) + 0.3 * sin(2.0 * phase[0])) * p * p * trem * 0.5)

## Einschlag: tiefer Schlag plus Dur-Akkord; mit Ziel zusätzlich hoher Glanz.
func _synth_slam(clears_goal: bool) -> AudioStreamWAV:
	var chord := [523.25, 659.25, 783.99, 1046.5]  # C-Dur
	var length := 2.0 if clears_goal else 1.4
	var phase := [0.0]
	return _render(length, func(t: float) -> float:
		var thump_f := 45.0 + 65.0 * exp(-t / 0.05)
		phase[0] += TAU * thump_f / MIX_RATE
		var thump := sin(phase[0]) * exp(-t / 0.25)
		var bell := 0.0
		for f: float in chord:
			bell += sin(TAU * f * t) * exp(-t / 0.6)
		var sparkle := 0.0
		if clears_goal:
			sparkle = (sin(TAU * 1567.98 * t) + sin(TAU * 2093.0 * t)) * exp(-maxf(t - 0.08, 0.0) / 0.9) \
				* clampf((t - 0.08) / 0.01, 0.0, 1.0)
		return (thump * 0.45 + bell * 0.1 + sparkle * 0.08) * _attack(t, 0.002))

func _attack(t: float, time: float) -> float:
	return clampf(t / time, 0.0, 1.0)

## Rendert 16-Bit-Mono; die letzten 10 ms blenden aus, damit nichts knackt.
func _render(length: float, sample: Callable) -> AudioStreamWAV:
	var count := int(length * MIX_RATE)
	var fade := int(0.01 * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var v: float = sample.call(float(i) / MIX_RATE)
		if i > count - fade:
			v *= float(count - i) / fade
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav

#endregion
