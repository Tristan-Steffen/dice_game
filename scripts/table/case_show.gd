class_name CaseShow
extends Node
## Die LICHT- und KLANG-SHOW der Schatulle: die Grund-Würfel kommen im ruhigen Takt, danach
## RÜTTELT sie - und jeder Zusatz-Würfel schießt heller, höher und schneller heraus als der
## vorige. Dazu die Töne der Walze. Die Stufen sind reine
## Funktionen; die Töne sind synthetisierte Platzhalter, eine Datei gleichen Namens unter
## SFX_DIR (.wav/.ogg) ersetzt sie.

const SFX_DIR := "res://assets/sfx/case/"
const BUS_NAME := "Score"
const MIX_RATE := 44100

const OPEN_DB := -7.0
const DIE_DB := -9.0
const CLIMAX_DB := -4.0
const SHUT_DB := -6.0
const RATTLE_DB := -10.0
const TICK_DB := -14.0
## Der ruhige Takt der Grund-Würfel.
const BEAT_BASE := 0.42
## Das Rütteln vor jedem Urteil: es wird mit jedem Zusatz-Würfel länger.
const RATTLE_TIME := 0.8
const RATTLE_GROWTH := 0.12
const RATTLE_MAX := 1.3
## Stufe 0 = Grund-Würfel, Stufe k = der k-te Zusatz-Würfel.
const GLOW_BASE := 0.9
const GLOW_STEP := 0.55
const SPEED_STEP := 0.16
const BEAM_COLOR := Color(1.0, 0.82, 0.42)
const BEAM_ALPHA := 0.3
const BEAM_PULSE_TIME := 0.35

var _streams := {}
var _playback: AudioStreamPlaybackPolyphonic

## Der Takt vor einem Grund-Würfel.
static func launch_beat() -> float:
	return BEAT_BASE

## Wie lange die Schatulle vor dem Urteil rüttelt (rounds = Zusatz-Würfel bisher).
static func rattle_time(rounds: int) -> float:
	return minf(RATTLE_TIME + RATTLE_GROWTH * float(maxi(rounds, 0)), RATTLE_MAX)

## Die Helligkeit eines Auswurfs (Strahl, Ring) und der Spitze des Rüttelns davor.
static func glow(level: int) -> float:
	return GLOW_BASE + GLOW_STEP * float(maxi(level, 0))

## Der Schub eines Auswurfs relativ zum Grund-Würfel.
static func launch_gain(level: int) -> float:
	return 1.0 + SPEED_STEP * float(maxi(level, 0))

## Seine Stufe auf der pentatonischen Leiter (ScoreAudio.LADDER, Tonart G): die Grund-
## Würfel alle auf derselben, jeder Zusatz zwei darüber.
static func pitch_step(level: int) -> int:
	return mini(2 * maxi(level, 0), ScoreAudio.LADDER.size() - 1)

static func pitch(level: int) -> float:
	return _semis(pitch_step(level))

## Der Ton einer Walzen-Zahl (1 … top): je höher, desto höher.
static func reel_pitch(value: int, top: int) -> float:
	var last := ScoreAudio.LADDER.size() - 1
	var share := clampf(float(value - 1) / float(maxi(top - 1, 1)), 0.0, 1.0)
	return _semis(roundi(share * float(last - 2)) + 2)

static func _semis(step: int) -> float:
	return pow(2.0, float(ScoreAudio.LADDER[clampi(step, 0, ScoreAudio.LADDER.size() - 1)]) / 12.0)

## Der Lichtstrahl aus der offenen Schatulle - ein additiver Zylinder, unsichtbar bis
## zum ersten Puls. Den Körper stellt scene_root.
static func build_beam(radius: float, height: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 1.35
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.cap_top = false
	mesh.cap_bottom = false
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(BEAM_COLOR, 0.0)
	var beam := MeshInstance3D.new()
	beam.name = "CaseBeam"
	beam.mesh = mesh
	beam.material_override = material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return beam

## Ein Puls des Strahls auf `strength` - er klingt in `time` auf seinen Ruhewert ab.
static func pulse_beam(beam: MeshInstance3D, strength: float, rest: float,
		time := BEAM_PULSE_TIME, ease_in := false) -> void:
	if beam == null or not is_instance_valid(beam):
		return
	var material := beam.material_override as StandardMaterial3D
	var tween := beam.create_tween()
	tween.tween_method(func(a: float) -> void:
		material.albedo_color = Color(BEAM_COLOR * maxf(a, 1.0), clampf(a, 0.0, 1.0) * BEAM_ALPHA),
		strength, rest, time).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN if ease_in else Tween.EASE_OUT)
	if beam.has_meta("pulse"):
		var old: Variant = beam.get_meta("pulse")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	beam.set_meta("pulse", tween)

func _ready() -> void:
	_streams = {
		"open": _load_or(&"open", _synth_open),
		"die": _load_or(&"die", _synth_die),
		"climax": _load_or(&"climax", _synth_climax),
		"shut": _load_or(&"shut", _synth_shut),
		"rattle": _load_or(&"rattle", _synth_rattle),
		"tick": _load_or(&"tick", _synth_tick),
	}
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 16
	var player := AudioStreamPlayer.new()
	player.name = "Voices"
	player.stream = poly
	player.bus = BUS_NAME if AudioServer.get_bus_index(BUS_NAME) != -1 else &"Master"
	add_child(player)
	player.play()
	_playback = player.get_stream_playback() as AudioStreamPlaybackPolyphonic

func play_open() -> void:
	_play("open", OPEN_DB)

## Ein Auswurf: die Grund-Würfel ruhig, jeder Zusatz lauter, höher und mit Schlag.
func play_launch(level: int) -> void:
	_play("die", DIE_DB + 1.5 * float(level), pitch(level))
	if level > 0:
		_play("climax", CLIMAX_DB - 6.0 + 1.5 * float(level), 1.0 + 0.04 * float(level))

## Das Rütteln: mit jeder Runde etwas höher.
func play_rattle(rounds: int) -> void:
	_play("rattle", RATTLE_DB + float(rounds), 1.0 + 0.08 * float(rounds))

func play_shut() -> void:
	_play("shut", SHUT_DB)


func play_reel_step(value: int, top: int) -> void:
	_play("tick", TICK_DB + 2.0, reel_pitch(value, top))

func play_reel_stop(value: int, top: int) -> void:
	_play("shut", SHUT_DB + 2.0, 0.9)
	_play("die", DIE_DB + 2.0, reel_pitch(value, top))

func _play(key: String, db: float, pitch_scale := 1.0) -> void:
	if _playback == null or not _streams.has(key):
		return
	_playback.play_stream(_streams[key], 0.0, db, pitch_scale)

func _load_or(file_name: StringName, synth: Callable) -> AudioStream:
	for ext in ["wav", "ogg"]:
		var path := "%s%s.%s" % [SFX_DIR, file_name, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return synth.call()

#region Platzhalter-Synthese

## Aufschwung: ein steigender Hauch, darauf ein G-Moll-Klang.
func _synth_open() -> AudioStreamWAV:
	var phase := [0.0]
	return _render(0.9, func(t: float) -> float:
		var freq := 196.0 * pow(2.0, minf(t / 0.35, 1.0))
		phase[0] += TAU * freq / MIX_RATE
		var swell := sin(phase[0]) * minf(t / 0.35, 1.0) * exp(-maxf(t - 0.35, 0.0) / 0.2)
		var chord := 0.0
		for f: float in [392.0, 466.16, 587.33]:
			chord += sin(TAU * f * t) * exp(-maxf(t - 0.3, 0.0) / 0.35) \
				* clampf((t - 0.3) / 0.01, 0.0, 1.0)
		return (swell * 0.4 + chord * 0.15))

## Ein heller Glockenschlag mit Funkeln (G5), über die Leiter tonhöhenverschoben.
func _synth_die() -> AudioStreamWAV:
	var f := 784.0
	return _render(0.5, func(t: float) -> float:
		var env := clampf(t / 0.003, 0.0, 1.0)
		return env * (exp(-t / 0.16) * sin(TAU * f * t)
			+ 0.4 * exp(-t / 0.08) * sin(TAU * f * 2.0 * t)
			+ 0.2 * exp(-t / 0.05) * sin(TAU * f * 3.0 * t)
			+ 0.15 * exp(-t / 0.03) * randf_range(-1.0, 1.0)) * 0.5)

## Der Höhepunkt: tiefer Schlag plus breiter Akkord und Glanz.
func _synth_climax() -> AudioStreamWAV:
	var phase := [0.0]
	return _render(1.8, func(t: float) -> float:
		var thump_f := 50.0 + 70.0 * exp(-t / 0.05)
		phase[0] += TAU * thump_f / MIX_RATE
		var thump := sin(phase[0]) * exp(-t / 0.3)
		var chord := 0.0
		for f: float in [392.0, 587.33, 783.99, 932.33, 1174.66]:
			chord += sin(TAU * f * t) * exp(-t / 0.8)
		var sparkle := sin(TAU * 1567.98 * t) * exp(-t / 0.6) * (0.5 + 0.5 * sin(TAU * 9.0 * t))
		return (thump * 0.4 + chord * 0.07 + sparkle * 0.08) * clampf(t / 0.003, 0.0, 1.0))

## Der Deckel fällt zu: kurzer, dumpfer Schlag.
func _synth_shut() -> AudioStreamWAV:
	return _render(0.3, func(t: float) -> float:
		var thud := sin(TAU * (90.0 + 60.0 * exp(-t / 0.03)) * t) * exp(-t / 0.08)
		var click := randf_range(-1.0, 1.0) * exp(-t / 0.01)
		return thud * 0.6 + click * 0.15)

## Das Rütteln: Klicks, die dichter werden, über einem steigenden Brummen.
func _synth_rattle() -> AudioStreamWAV:
	var phase := [0.0]
	var next := [0.0]
	var hit := [-1.0]
	return _render(RATTLE_TIME, func(t: float) -> float:
		var share := t / RATTLE_TIME
		if t >= next[0]:
			hit[0] = t
			next[0] = t + lerpf(0.07, 0.025, share) * randf_range(0.7, 1.3)
		var click := randf_range(-1.0, 1.0) * exp(-(t - hit[0]) / 0.006) if hit[0] >= 0.0 else 0.0
		phase[0] += TAU * (70.0 + 90.0 * share) / MIX_RATE
		var hum := sin(phase[0]) * share * 0.25
		return (click * 0.5 + hum) * minf(share * 4.0, 1.0))

## Ein kurzes, helles Klicken (die Walze).
func _synth_tick() -> AudioStreamWAV:
	return _render(0.08, func(t: float) -> float:
		return sin(TAU * 1320.0 * t) * exp(-t / 0.018) * 0.6)

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
