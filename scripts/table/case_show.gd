class_name CaseShow
extends Node
## Die LICHT- und KLANG-SHOW der Schatulle: jeder Würfel, der sie verläßt, bekommt einen
## größeren Moment als der vorige - heller, höher, schneller -, der letzte den Höhepunkt.
## Die Stufen sind reine Funktionen; die Töne sind synthetisierte Platzhalter, eine
## Datei gleichen Namens unter SFX_DIR (.wav/.ogg) ersetzt sie.

const SFX_DIR := "res://assets/sfx/case/"
const BUS_NAME := "Score"
const MIX_RATE := 44100

const OPEN_DB := -7.0
const DIE_DB := -9.0
const CLIMAX_DB := -4.0
const SHUT_DB := -8.0
## Der Takt zwischen zwei Würfeln beschleunigt vom ersten zum letzten.
const BEAT_FIRST := 0.42
const BEAT_LAST := 0.2
## Vor dem letzten Würfel hält die Schatulle kurz den Atem an.
const CLIMAX_HOLD := 0.22
const GLOW_FIRST := 0.8
const GLOW_LAST := 2.0
const GLOW_CLIMAX := 1.4
const BEAM_COLOR := Color(1.0, 0.82, 0.42)
const BEAM_ALPHA := 0.3
const BEAM_PULSE_TIME := 0.35

var _streams := {}
var _playback: AudioStreamPlaybackPolyphonic

## Wie weit der Würfel index in der Reihe steht (0 = erster, 1 = letzter).
static func share(index: int, count: int) -> float:
	if count <= 1:
		return 1.0
	return clampf(float(index) / float(count - 1), 0.0, 1.0)

static func is_climax(index: int, count: int) -> bool:
	return index == count - 1

## Die Wartezeit VOR dem Sprung des Würfels index.
static func beat(index: int, count: int) -> float:
	var wait := lerpf(BEAT_FIRST, BEAT_LAST, share(index, count))
	return wait + (CLIMAX_HOLD if is_climax(index, count) and count > 1 else 0.0)

## Die Helligkeit seines Moments (Strahl und Ring).
static func glow(index: int, count: int) -> float:
	var level := lerpf(GLOW_FIRST, GLOW_LAST, share(index, count))
	return level + (GLOW_CLIMAX if is_climax(index, count) else 0.0)

## Seine Stufe auf der pentatonischen Leiter (ScoreAudio.LADDER, Tonart G).
static func pitch_step(index: int, count: int) -> int:
	var top: int = ScoreAudio.LADDER.size() - 1
	if is_climax(index, count):
		return top
	return roundi(share(index, count) * float(top - 2))

static func pitch(index: int, count: int) -> float:
	return pow(2.0, float(ScoreAudio.LADDER[pitch_step(index, count)]) / 12.0)

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

## Ein Puls des Strahls auf `strength` - er klingt auf seinen Ruhewert ab.
static func pulse_beam(beam: MeshInstance3D, strength: float, rest: float) -> void:
	if beam == null or not is_instance_valid(beam):
		return
	var material := beam.material_override as StandardMaterial3D
	var tween := beam.create_tween()
	tween.tween_method(func(a: float) -> void:
		material.albedo_color = Color(BEAM_COLOR * maxf(a, 1.0), clampf(a, 0.0, 1.0) * BEAM_ALPHA),
		strength, rest, BEAM_PULSE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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

## Der Ton des Würfels index - steigend, der letzte mit dem Höhepunkt darüber.
func play_die(index: int, count: int) -> void:
	_play("die", DIE_DB + 2.0 * share(index, count), pitch(index, count))
	if is_climax(index, count):
		_play("climax", CLIMAX_DB)

func play_shut() -> void:
	_play("shut", SHUT_DB)

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
