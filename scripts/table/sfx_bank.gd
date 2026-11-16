class_name SfxBank
extends Node
## Platzhalter-Klänge für Oberfläche, Laden, Werkstatt, Wetten und Runde.
## Liegt unter SFX_DIR eine Datei gleichen Namens (.wav/.ogg), ersetzt sie den Ton.

## Die Klang-Tafel liest genau diese Konstante und die _load_or-Aufrufe per Regex.
const SFX_DIR := "res://assets/sfx/game/"
const BUS_UI := "UI"
const BUS_SFX := "SFX"
const MIX_RATE := 44100
const POLYPHONY := 24
const SILENT_META := &"sfx_silent"
const NAME_PATTERN := "^[a-z]+_[a-z_]+$"

## G-Moll-Pentatonik, wie Musik und Wertung.
const G2 := 98.0
const D3 := 146.83
const G3 := 196.0
const BB3 := 233.08
const C4 := 261.63
const D4 := 293.66
const F4 := 349.23
const G4 := 392.0
const BB4 := 466.16
const C5 := 523.25
const D5 := 587.33
const F5 := 698.46
const G5 := 783.99
const BB5 := 932.33
const D6 := 1174.66

const DEFAULT_DB := -10.0
const LEVEL_DB := {
	&"ui_click": -14.0, &"ui_hover": -26.0, &"ui_denied": -11.0, &"cam_zoom": -20.0,
	&"chip_in": -16.0, &"chip_out": -17.0, &"money_arrive": -15.0,
	&"energy_gain": -14.0, &"energy_spend": -15.0, &"shelf_snap": -20.0,
	&"light_pass": -13.0, &"card_burnout": -18.0, &"dice_swallow": -16.0,
	&"round_fumble": -8.0, &"round_won": -7.0, &"game_over": -6.0,
}
## Mindestpause je Name - gegen Geknatter bei vielen gleichzeitigen Auslösern.
const MIN_GAP_MS := {
	&"ui_click": 30, &"ui_hover": 60, &"chip_in": 30, &"chip_out": 30,
	&"money_arrive": 50, &"dice_swallow": 45, &"card_burnout": 60,
	&"store_land": 50, &"energy_gain": 40, &"energy_spend": 40, &"cam_zoom": 150,
	&"shelf_snap": 60, &"pack_pick": 30, &"bench_latch": 40,
}
const DEFAULT_SPREAD := 0.02
const PITCH_SPREAD := {
	&"chip_in": 0.05, &"chip_out": 0.05, &"dice_swallow": 0.06, &"ui_hover": 0.0,
	&"light_pass": 0.0, &"card_burnout": 0.05,
}

var _streams := {}
var _playbacks := {}
var _last_ms := {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 2611
	_streams = {
		&"ui_click": _load_or(&"ui_click", _click.bind(G5, 0.05)),
		&"ui_hover": _load_or(&"ui_hover", _blip.bind(D6, 0.04, 0.0)),
		&"ui_denied": _load_or(&"ui_denied", _buzz),
		&"cam_zoom": _load_or(&"cam_zoom", _whoosh.bind(0.35, true)),
		&"round_start": _load_or(&"round_start", _chime.bind([G4, BB4, D5], 0.9, 0.07)),
		&"round_commit": _load_or(&"round_commit", _latch.bind(0.06)),
		&"dice_throw": _load_or(&"dice_throw", _whoosh.bind(0.4, false)),
		&"dice_take": _load_or(&"dice_take", _chime.bind([D5, G5], 0.45, 0.04)),
		&"dice_swallow": _load_or(&"dice_swallow", _thud.bind(G2, 0.22)),
		&"round_fumble": _load_or(&"round_fumble", _zap.bind(G4, G2, 0.7)),
		&"round_won": _load_or(&"round_won", _chime.bind([G4, BB4, D5, G5], 1.4, 0.09)),
		&"game_over": _load_or(&"game_over", _chime.bind([D4, BB3, G3, D3], 2.0, 0.22)),
		&"chip_in": _load_or(&"chip_in", _clack.bind(D6)),
		&"chip_out": _load_or(&"chip_out", _clack.bind(G5)),
		&"money_arrive": _load_or(&"money_arrive", _blip.bind(G5, 0.18, 0.4)),
		&"energy_gain": _load_or(&"energy_gain", _zap.bind(D5, G5, 0.16)),
		&"energy_spend": _load_or(&"energy_spend", _zap.bind(G5, D5, 0.16)),
		&"shop_buy": _load_or(&"shop_buy", _chime.bind([G5, D6], 0.4, 0.05)),
		&"shop_refund": _load_or(&"shop_refund", _chime.bind([D6, G5], 0.4, 0.05)),
		&"shop_flip": _load_or(&"shop_flip", _whoosh.bind(0.3, true)),
		&"store_land": _load_or(&"store_land", _thud.bind(D3, 0.18)),
		&"store_open": _load_or(&"store_open", _latch.bind(0.08)),
		&"pack_burst": _load_or(&"pack_burst", _tear.bind(0.3)),
		&"bag_tear": _load_or(&"bag_tear", _tear.bind(0.5)),
		&"pack_pick": _load_or(&"pack_pick", _blip.bind(D5, 0.1, 0.3)),
		&"pack_confirm": _load_or(&"pack_confirm", _chime.bind([G4, D5, G5], 0.6, 0.05)),
		&"pack_reshuffle": _load_or(&"pack_reshuffle", _whoosh.bind(0.45, true)),
		&"card_lift": _load_or(&"card_lift", _blip.bind(C5, 0.1, 0.2)),
		&"card_drop": _load_or(&"card_drop", _click.bind(D4, 0.08)),
		&"shelf_switch": _load_or(&"shelf_switch", _whoosh.bind(0.25, false)),
		&"shelf_snap": _load_or(&"shelf_snap", _click.bind(F4, 0.04)),
		&"bench_target": _load_or(&"bench_target", _blip.bind(G4, 0.2, 0.5)),
		&"bench_press": _load_or(&"bench_press", _thud.bind(G3, 0.3)),
		&"bench_latch": _load_or(&"bench_latch", _latch.bind(0.05)),
		&"light_pass": _load_or(&"light_pass", _blip.bind(G4, 0.25, 0.5)),
		&"light_strike": _load_or(&"light_strike", _zap.bind(D6, G4, 0.35)),
		&"card_burnout": _load_or(&"card_burnout", _tear.bind(0.2)),
		&"raster_toggle": _load_or(&"raster_toggle", _click.bind(C5, 0.06)),
		&"pool_swap": _load_or(&"pool_swap", _blip.bind(BB4, 0.18, 0.5)),
		&"bet_place": _load_or(&"bet_place", _clack.bind(BB5)),
		&"bet_win": _load_or(&"bet_win", _chime.bind([D5, G5, BB5], 0.8, 0.06)),
		&"bet_lose": _load_or(&"bet_lose", _thud.bind(D3, 0.45)),
		&"slot_spin": _load_or(&"slot_spin", _whoosh.bind(0.5, true)),
		&"slot_win": _load_or(&"slot_win", _chime.bind([G5, BB5, D6], 0.7, 0.05)),
		&"part_install": _load_or(&"part_install", _latch.bind(0.07)),
		&"part_move": _load_or(&"part_move", _click.bind(BB4, 0.06)),
		&"charge_burn": _load_or(&"charge_burn", _zap.bind(F5, D3, 0.6)),
	}
	_playbacks = {
		BUS_UI: _make_player(BUS_UI),
		BUS_SFX: _make_player(BUS_SFX),
	}
	get_tree().node_added.connect(_on_node_added)
	_hook_existing(get_tree().root)

## Unbekannte Namen und zu dichte Wiederholungen bleiben still.
func play(sfx: StringName, db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sfx) or not _gap_ok(sfx):
		return
	var playback: AudioStreamPlaybackPolyphonic = _playbacks.get(bus_of(sfx))
	if playback == null:
		return
	var spread: float = PITCH_SPREAD.get(sfx, DEFAULT_SPREAD)
	var jitter := _rng.randf_range(1.0 - spread, 1.0 + spread) if spread > 0.0 else 1.0
	playback.play_stream(_streams[sfx], 0.0, float(LEVEL_DB.get(sfx, DEFAULT_DB)) + db,
		pitch * jitter)

func names() -> Array:
	return _streams.keys()

func stream_of(sfx: StringName) -> AudioStream:
	return _streams.get(sfx)

static func bus_of(sfx: StringName) -> String:
	return BUS_UI if String(sfx).begins_with("ui_") else BUS_SFX

func _make_player(bus: String) -> AudioStreamPlaybackPolyphonic:
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = POLYPHONY
	var player := AudioStreamPlayer.new()
	player.name = "Voices" + bus
	player.stream = poly
	player.bus = bus if AudioServer.get_bus_index(bus) != -1 else &"Master"
	add_child(player)
	player.play()
	return player.get_stream_playback() as AudioStreamPlaybackPolyphonic

func _gap_ok(sfx: StringName) -> bool:
	var gap: int = MIN_GAP_MS.get(sfx, 0)
	var now := Time.get_ticks_msec()
	if gap > 0 and now - int(_last_ms.get(sfx, -100000)) < gap:
		return false
	_last_ms[sfx] = now
	return true

func _load_or(file_name: StringName, synth: Callable) -> AudioStream:
	for ext in ["wav", "ogg"]:
		var path := "%s%s.%s" % [SFX_DIR, file_name, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return synth.call()

#region Knöpfe

func _hook_existing(node: Node) -> void:
	if node is BaseButton:
		hook_button(node)
	for child in node.get_children():
		_hook_existing(child)

## Erst im nächsten Bild verbinden - so zählt auch ein sfx_silent, das nach add_child gesetzt wird.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		hook_button.call_deferred(node)

func hook_button(button: Variant) -> void:
	if not is_instance_valid(button) or not button is BaseButton:
		return
	if button.get_meta(SILENT_META, false):
		return
	var press := _on_button_pressed.bind(button)
	if not button.pressed.is_connected(press):
		button.pressed.connect(press)
	var hover := _on_button_hovered.bind(button)
	if not button.mouse_entered.is_connected(hover):
		button.mouse_entered.connect(hover)

func _on_button_pressed(button: BaseButton) -> void:
	if is_instance_valid(button) and not button.get_meta(SILENT_META, false):
		play(&"ui_click")

func _on_button_hovered(button: BaseButton) -> void:
	if is_instance_valid(button) and not button.disabled \
			and not button.get_meta(SILENT_META, false):
		play(&"ui_hover")

#endregion

#region Platzhalter-Synthese

## Sehr kurzer Klick: Rauschspitze plus schnell verklingender Ton.
func _click(freq: float, length: float) -> AudioStreamWAV:
	return _render(length, func(t: float) -> float:
		var tone := sin(TAU * freq * t) * exp(-t / (length * 0.3))
		var noise := _rng.randf_range(-1.0, 1.0) * exp(-t / 0.004)
		return (tone * 0.5 + noise * 0.25) * _attack(t, 0.002))

## Sinus mit einer Prise Oktave, abklingend.
func _blip(freq: float, length: float, octave: float) -> AudioStreamWAV:
	return _render(length, func(t: float) -> float:
		var env := _attack(t, 0.003) * exp(-t / (length * 0.35))
		return env * (sin(TAU * freq * t) + octave * sin(TAU * freq * 2.0 * t)) * 0.45)

## Glocken-Akkord, die Töne um stagger versetzt angeschlagen.
func _chime(chord: Array, length: float, stagger: float) -> AudioStreamWAV:
	return _render(length, func(t: float) -> float:
		var v := 0.0
		for i in chord.size():
			var local := t - stagger * i
			if local <= 0.0:
				continue
			var f: float = chord[i]
			v += (sin(TAU * f * local) + 0.25 * sin(TAU * f * 2.0 * local)) \
				* exp(-local / (length * 0.3)) * _attack(local, 0.003)
		return v * 0.28)

## Gefiltertes Rauschen mit weicher Hüllkurve; up läßt den Filter öffnen.
func _whoosh(length: float, up: bool) -> AudioStreamWAV:
	var state := [0.0]
	return _render(length, func(t: float) -> float:
		var p := t / length
		var sweep := p if up else 1.0 - p
		var alpha := lerpf(0.02, 0.25, sweep)
		state[0] += alpha * (_rng.randf_range(-1.0, 1.0) - state[0])
		return state[0] * sin(PI * p) * 1.6)

## Tiefer, abfallender Schlag.
func _thud(freq: float, length: float) -> AudioStreamWAV:
	var phase := [0.0]
	return _render(length, func(t: float) -> float:
		var f := freq * (1.0 + exp(-t / 0.03))
		phase[0] += TAU * f / MIX_RATE
		var noise := _rng.randf_range(-1.0, 1.0) * exp(-t / 0.006) * 0.2
		return (sin(phase[0]) * exp(-t / (length * 0.35)) * 0.8 + noise) * _attack(t, 0.002))

## Dumpfer Fehlerton: zwei tiefe, weich angezerrte Töne nacheinander.
func _buzz() -> AudioStreamWAV:
	return _render(0.26, func(t: float) -> float:
		var f := D3 if t < 0.12 else G2 * 1.5
		var local := fmod(t, 0.13)
		var env := _attack(local, 0.004) * exp(-local / 0.06)
		return tanh(2.5 * sin(TAU * f * t)) * env * 0.35)

## Chip: kurzer Rausch-Klick plus hoher, harter Ton.
func _clack(freq: float) -> AudioStreamWAV:
	return _render(0.09, func(t: float) -> float:
		var noise := _rng.randf_range(-1.0, 1.0) * exp(-t / 0.003)
		var tone := sin(TAU * freq * t) * exp(-t / 0.02) + 0.4 * sin(TAU * freq * 1.47 * t) * exp(-t / 0.01)
		return (noise * 0.35 + tone * 0.35) * _attack(t, 0.002))

## Gleitender Ton von from_f nach to_f.
func _zap(from_f: float, to_f: float, length: float) -> AudioStreamWAV:
	var phase := [0.0]
	return _render(length, func(t: float) -> float:
		var p := t / length
		var f := from_f * pow(to_f / from_f, p)
		phase[0] += TAU * f / MIX_RATE
		var env := _attack(t, 0.004) * (1.0 - p) * (1.0 - p)
		return (sin(phase[0]) + 0.25 * tanh(2.0 * sin(phase[0]))) * env * 0.4)

## Rauschstoß mit knisternder Modulation - Reißen, Aufbrechen, Ausbrennen.
func _tear(length: float) -> AudioStreamWAV:
	var state := [0.0]
	return _render(length, func(t: float) -> float:
		var p := t / length
		state[0] += 0.35 * (_rng.randf_range(-1.0, 1.0) - state[0])
		var crackle := 0.5 + 0.5 * signf(sin(TAU * 37.0 * t + 6.0 * sin(TAU * 11.0 * t)))
		return state[0] * crackle * _attack(t, 0.003) * (1.0 - p) * 1.4)

## Metallischer Doppel-Klick.
func _latch(gap: float) -> AudioStreamWAV:
	return _render(gap + 0.12, func(t: float) -> float:
		var v := 0.0
		for start in [0.0, gap]:
			var local: float = t - start
			if local <= 0.0:
				continue
			v += (sin(TAU * 1830.0 * local) + 0.6 * sin(TAU * 2710.0 * local)
				+ 0.4 * sin(TAU * 4170.0 * local)) * exp(-local / 0.018) * _attack(local, 0.002)
		return v * 0.22)

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
