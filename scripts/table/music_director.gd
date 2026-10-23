class_name MusicDirector
extends Node
## Der Musik-Takt: EIN Thema in vier Schichten (Pad, Bass, Keys, Drums), die je
## Spielphase ein- und ausblenden - und zwar auf der nächsten TAKTGRENZE, nie
## mitten im Takt; ein Einsatz zwischen zwei Schlägen liest als Fehler.
## Platzhalter-Loops werden beim Start synthetisiert; liegt unter MUSIC_DIR eine
## Datei gleichen Namens (.ogg/.wav), ersetzt sie die Schicht.
##
## Echte Stems müssen GLEICH LANG sein: jede Schicht läuft als eigener Player
## (nur so ist ihr Pegel je Bild blendbar), und gleich lange Schleifen sind das,
## was sie über Stunden synchron hält.

const MUSIC_DIR := "res://assets/music/"
const MIX_RATE := 22050

const BPM := 120.0
const BEATS_PER_BAR := 4
const LOOP_BARS := 4
## Taktlänge in Sekunden - jede Blende wartet auf sie und dauert sie.
const BAR_TIME := BEATS_PER_BAR * 60.0 / BPM
const LOOP_TIME := BAR_TIME * LOOP_BARS
## Sechzehntel: das Raster, in dem die Platzhalter-Figuren notiert sind.
const STEP_TIME := BAR_TIME / 16.0
const STEPS := LOOP_BARS * 16

enum Mood { TITLE, HUB, ROLL, SCORE, PAYOUT, SHOP, OVER }

const PAD := &"pad"
const BASS := &"bass"
const KEYS := &"keys"
const DRUMS := &"drums"
const LAYERS: Array[StringName] = [PAD, BASS, KEYS, DRUMS]

## Grundpegel je Schicht; die Mischung unten skaliert nur noch linear darauf.
const LAYER_DB := {PAD: -15.0, BASS: -10.0, KEYS: -12.0, DRUMS: -9.0}
const SILENT_DB := -60.0
## Spitzen-Deckel der Platzhalter: überschreitet eine Schicht ihn, wird sie
## heruntergezogen statt abgeschnitten - ein Clamp knickte die Transiente ab.
const PEAK_CEILING := 0.9

## Die Phasen-Tabelle - die ganze Regie steht hier und nirgends sonst.
const MIX := {
	Mood.TITLE:  {PAD: 1.0, BASS: 0.0, KEYS: 0.45, DRUMS: 0.0},
	Mood.HUB:    {PAD: 0.7, BASS: 1.0, KEYS: 0.9,  DRUMS: 0.0},
	Mood.ROLL:   {PAD: 0.6, BASS: 1.0, KEYS: 0.9,  DRUMS: 1.0},
	Mood.SCORE:  {PAD: 0.6, BASS: 1.0, KEYS: 1.0,  DRUMS: 1.0},
	Mood.PAYOUT: {PAD: 0.8, BASS: 1.0, KEYS: 1.0,  DRUMS: 0.8},
	Mood.SHOP:   {PAD: 1.0, BASS: 0.8, KEYS: 0.7,  DRUMS: 0.0},
	Mood.OVER:   {PAD: 0.5, BASS: 0.0, KEYS: 0.0,  DRUMS: 0.0},
}

var _players := {}  # StringName -> AudioStreamPlayer
var _fades := {}    # StringName -> Tween
var _mood: Mood = Mood.TITLE

func _ready() -> void:
	var bus := GameSettings.BUS_MUSIC if AudioServer.get_bus_index(GameSettings.BUS_MUSIC) != -1 else &"Master"
	var streams := {
		PAD: _load_or(PAD, _synth_pad),
		BASS: _load_or(BASS, _synth_bass),
		KEYS: _load_or(KEYS, _synth_keys),
		DRUMS: _load_or(DRUMS, _synth_drums),
	}
	for layer: StringName in LAYERS:
		var player := AudioStreamPlayer.new()
		player.name = String(layer).capitalize()
		player.stream = streams[layer]
		player.bus = bus
		player.volume_db = db_for(_mood, layer)
		add_child(player)
		_players[layer] = player
	# Alle im SELBEN Bild starten: derselbe Mix-Block, also derselbe Nullpunkt.
	for layer: StringName in LAYERS:
		_players[layer].play()

## Der Pegel einer Schicht in dieser Phase, linear 0..1.
static func gain_for(mood: Mood, layer: StringName) -> float:
	var row: Dictionary = MIX.get(mood, {})
	return float(row.get(layer, 0.0))

static func db_for(mood: Mood, layer: StringName) -> float:
	var gain := gain_for(mood, layer)
	if gain <= 0.001:
		return SILENT_DB
	return float(LAYER_DB[layer]) + linear_to_db(gain)

## Die Phase wechselt: jede Schicht blendet über EINEN Takt - beginnend an der
## nächsten Taktgrenze. Idempotent, darf also je Bild gefragt werden.
func set_mood(mood: Mood) -> void:
	if mood == _mood or _players.is_empty():
		return
	_mood = mood
	var delay := _time_to_next_bar()
	for layer: StringName in LAYERS:
		_kill_fade(layer)
		var tween := create_tween()
		tween.tween_property(_players[layer], "volume_db", db_for(mood, layer),
			BAR_TIME).set_delay(delay)
		_fades[layer] = tween

## Harter Weg (Laufwechsel): kein Warten, keine Blende.
func apply_hard(mood: Mood) -> void:
	_mood = mood
	for layer: StringName in LAYERS:
		_kill_fade(layer)
		if _players.has(layer):
			_players[layer].volume_db = db_for(mood, layer)

func mood() -> Mood:
	return _mood

## Wie lange bis zum nächsten Taktbeginn. Die Schleife ist ein ganzzahliges
## Vielfaches des Takts, also genügt die Position in ihr.
func _time_to_next_bar() -> float:
	var clock: AudioStreamPlayer = _players.get(LAYERS[0])
	if clock == null or not clock.playing:
		return 0.0
	var rest := BAR_TIME - fmod(clock.get_playback_position(), BAR_TIME)
	return 0.0 if rest >= BAR_TIME - 0.02 else rest

func _kill_fade(layer: StringName) -> void:
	var tween: Tween = _fades.get(layer)
	if tween != null and tween.is_valid():
		tween.kill()
	_fades.erase(layer)

## Eine echte Datei gewinnt immer; sie muß nur schleifen können.
func _load_or(file_name: StringName, synth: Callable) -> AudioStream:
	for ext in ["ogg", "wav"]:
		var path := "%s%s.%s" % [MUSIC_DIR, file_name, ext]
		if not ResourceLoader.exists(path):
			continue
		var stream: AudioStream = load(path)
		if stream == null:
			continue
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = stream.data.size() / (4 if stream.stereo else 2)
		return stream
	return synth.call()

#region Platzhalter-Synthese
# G-Moll-Pentatonik bei 120 BPM - dieselbe Tonart, in der ScoreAudio seine
# Punkt-Ticks spielt (dessen LADDER sitzt auf G), damit das Zählen in der
# Musik liegt statt daneben.

const ROOT_HZ := 98.0  # G2
## Gm7 als Pad-Lage und als Keys-Akkord (Halbtöne über dem Grundton).
const CHORD := [0, 3, 7, 10]

## Figuren je zwei Takte, als [Sechzehntel, Halbton, Länge]; A trägt die
## Takte 1-2, B die Wendung in 3-4.
const BASS_A := [[0, 0, 3], [3, 0, 1], [6, 3, 2], [10, 0, 2], [14, -2, 2],
	[16, 0, 3], [19, 0, 1], [22, 5, 2], [26, 3, 2], [30, 7, 1]]
const BASS_B := [[0, 0, 3], [3, 0, 1], [6, 3, 2], [10, 0, 2], [14, -2, 2],
	[16, 5, 3], [19, 5, 1], [22, 3, 2], [26, 0, 2], [30, 10, 2]]
## Akkord-Stiche auf den Gegenschlag, als [Sechzehntel, Halbton].
const KEYS_A := [[6, 0], [14, 0], [22, 0], [30, 0]]
const KEYS_B := [[6, 0], [14, 0], [20, 5], [30, 3]]
const KICK_STEPS := [0, 6, 10, 16, 22, 26]
const SNARE_STEPS := [4, 12, 20, 28]
## Geisternoten zwischen den Achteln - sie machen den Groove.
const GHOST_STEPS := [7, 15, 23, 31]

func _frame_count() -> int:
	return int(LOOP_TIME * MIX_RATE)

func _synth_pad() -> AudioStreamWAV:
	var n := _frame_count()
	var out := PackedFloat32Array()
	out.resize(n)
	# Jede Teilfrequenz traegt eine GANZE Zahl Schwingungen in die Schleife,
	# sonst knackt der Rundumschluss.
	var voices := PackedFloat32Array()
	for semi: int in CHORD:
		var hz := _quantize(ROOT_HZ * pow(2.0, semi / 12.0))
		voices.append(hz)
		voices.append(_quantize(hz + 0.25))
	var swell := TAU / LOOP_TIME
	for i in n:
		var t := float(i) / MIX_RATE
		var sum := 0.0
		for hz: float in voices:
			sum += sin(TAU * hz * t)
		var env := 0.55 + 0.45 * sin(swell * t)
		out[i] = sum / voices.size() * env * 0.8
	return _wav(out)

func _synth_bass() -> AudioStreamWAV:
	var out := _empty()
	for pass_index in 2:
		var figure: Array = BASS_A if pass_index == 0 else BASS_B
		for note: Array in figure:
			var step: int = pass_index * 32 + int(note[0])
			var hz := ROOT_HZ * pow(2.0, int(note[1]) / 12.0)
			_stamp(out, step, _bass_voice(hz, int(note[2]) * STEP_TIME))
	return _wav(out)

func _synth_keys() -> AudioStreamWAV:
	var out := _empty()
	for pass_index in 2:
		var figure: Array = KEYS_A if pass_index == 0 else KEYS_B
		for stab: Array in figure:
			var step: int = pass_index * 32 + int(stab[0])
			_stamp(out, step, _keys_voice(int(stab[1])))
	return _wav(out)

func _synth_drums() -> AudioStreamWAV:
	var out := _empty()
	var kick := _kick_voice()
	var snare := _snare_voice()
	var hat := _hat_voice(1.0)
	var hat_soft := _hat_voice(0.35)
	for pass_index in 2:
		var base: int = pass_index * 32
		for step: int in KICK_STEPS:
			_stamp(out, base + step, kick)
		for step: int in SNARE_STEPS:
			_stamp(out, base + step, snare)
		for step: int in GHOST_STEPS:
			_stamp(out, base + step, hat_soft)
	for step in range(0, STEPS, 2):
		_stamp(out, step, hat if step % 8 == 0 else hat_soft)
	return _wav(out)

## Bass: Sägezahn-Andeutung aus drei Teiltönen, kurzer Anschlag.
func _bass_voice(hz: float, length: float) -> PackedFloat32Array:
	var n := int((length + 0.12) * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := clampf(t / 0.005, 0.0, 1.0) * exp(-t / (length * 0.6 + 0.05))
		out[i] = (sin(TAU * hz * t) + 0.5 * sin(TAU * hz * 2.0 * t)
			+ 0.22 * sin(TAU * hz * 3.0 * t)) * env * 0.5
	return out

## Keys: vierstimmiger Stich eine Oktave über dem Bass, kurz und perkussiv.
func _keys_voice(transpose: int) -> PackedFloat32Array:
	var n := int(0.34 * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var hz := PackedFloat32Array()
	for semi: int in CHORD:
		hz.append(ROOT_HZ * 4.0 * pow(2.0, (semi + transpose) / 12.0))
	for i in n:
		var t := float(i) / MIX_RATE
		var env := clampf(t / 0.004, 0.0, 1.0) * exp(-t / 0.085)
		var sum := 0.0
		for f: float in hz:
			sum += sin(TAU * f * t)
		out[i] = sum / hz.size() * env * 0.75
	return out

func _kick_voice() -> PackedFloat32Array:
	var n := int(0.3 * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var hz := 45.0 + 70.0 * exp(-t / 0.035)
		phase += TAU * hz / MIX_RATE
		var click := randf_range(-1.0, 1.0) * exp(-t / 0.003) * 0.25
		out[i] = (sin(phase) * exp(-t / 0.085) + click) * 0.8
	return out

func _snare_voice() -> PackedFloat32Array:
	var n := int(0.18 * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var noise := randf_range(-1.0, 1.0) * exp(-t / 0.05)
		var body := sin(TAU * 185.0 * t) * exp(-t / 0.032)
		out[i] = (noise * 0.7 + body * 0.45) * 0.5
	return out

## Hi-Hat: Rauschen, per Differenz hochpassgefiltert - das hebt die Energie
## nach oben, ohne eine echte Filterbank.
func _hat_voice(gain: float) -> PackedFloat32Array:
	var n := int(0.06 * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var noise := randf_range(-1.0, 1.0)
		var high := noise - prev
		prev = noise
		out[i] = high * 0.5 * exp(-t / 0.011) * 0.4 * gain
	return out

func _empty() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_frame_count())
	return out

## Mischt eine Stimme auf das Sechzehntel - was hinten übersteht, läuft vorn
## wieder ein. Nur so schließt die Schleife ohne Knacken.
func _stamp(buffer: PackedFloat32Array, step: int, voice: PackedFloat32Array) -> void:
	var n := buffer.size()
	var start := int(step * STEP_TIME * MIX_RATE)
	for i in voice.size():
		var at := (start + i) % n
		buffer[at] = buffer[at] + voice[i]

## Auf ein Vielfaches der Schleifenfrequenz runden (ganze Schwingungen).
func _quantize(hz: float) -> float:
	return roundf(hz * LOOP_TIME) / LOOP_TIME

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var n := samples.size()
	var peak := 0.0
	for i in n:
		peak = maxf(peak, absf(samples[i]))
	var gain := 1.0 if peak <= PEAK_CEILING else PEAK_CEILING / peak
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav

#endregion
