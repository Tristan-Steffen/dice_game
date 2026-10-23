extends GutTest
## Tests der Musik-Regie: die Phasen-Tabelle (MusicDirector.MIX) und die Takt-
## Konstanten, die jede Blende benutzt. Die Player selbst bleiben hier außen vor -
## sie fassen den AudioServer an, das gehört nicht in einen Unit-Test.

const MOODS := [MusicDirector.Mood.TITLE, MusicDirector.Mood.HUB,
	MusicDirector.Mood.ROLL, MusicDirector.Mood.SCORE, MusicDirector.Mood.PAYOUT,
	MusicDirector.Mood.SHOP, MusicDirector.Mood.OVER]

func test_every_phase_names_every_layer() -> void:
	for mood: int in MOODS:
		var row: Dictionary = MusicDirector.MIX[mood]
		assert_eq(row.size(), MusicDirector.LAYERS.size(),
			"Phase %d nennt nicht genau die vier Schichten" % mood)
		for layer: StringName in MusicDirector.LAYERS:
			assert_true(row.has(layer), "Phase %d fehlt die Schicht %s" % [mood, layer])
			var gain := MusicDirector.gain_for(mood, layer)
			assert_between(gain, 0.0, 1.0, "Pegel von %s in Phase %d" % [layer, mood])

func test_every_phase_is_audible() -> void:
	for mood: int in MOODS:
		var loudest := 0.0
		for layer: StringName in MusicDirector.LAYERS:
			loudest = maxf(loudest, MusicDirector.gain_for(mood, layer))
		assert_gt(loudest, 0.0, "Phase %d wäre still" % mood)

func test_a_silent_layer_is_muted_not_quiet() -> void:
	# Pegel 0 muss auf den Stille-Wert fallen - linear_to_db(0) wäre -inf.
	assert_eq(MusicDirector.db_for(MusicDirector.Mood.TITLE, MusicDirector.DRUMS),
		MusicDirector.SILENT_DB)
	assert_gt(MusicDirector.db_for(MusicDirector.Mood.ROLL, MusicDirector.DRUMS),
		MusicDirector.SILENT_DB)

## Volle Lautstärke heißt genau der Grundpegel der Schicht, ohne Zuschlag.
func test_full_gain_is_the_layer_level() -> void:
	assert_almost_eq(MusicDirector.db_for(MusicDirector.Mood.ROLL, MusicDirector.DRUMS),
		float(MusicDirector.LAYER_DB[MusicDirector.DRUMS]), 0.0001)

## Die Drums sind der Einsatz: ruhige Phasen tragen keine.
func test_drums_mark_the_active_phases() -> void:
	for mood: int in [MusicDirector.Mood.TITLE, MusicDirector.Mood.HUB,
			MusicDirector.Mood.SHOP, MusicDirector.Mood.OVER]:
		assert_eq(MusicDirector.gain_for(mood, MusicDirector.DRUMS), 0.0,
			"Phase %d sollte ohne Schlagzeug stehen" % mood)
	for mood: int in [MusicDirector.Mood.ROLL, MusicDirector.Mood.SCORE,
			MusicDirector.Mood.PAYOUT]:
		assert_gt(MusicDirector.gain_for(mood, MusicDirector.DRUMS), 0.0,
			"Phase %d sollte Schlagzeug tragen" % mood)

## Die Schleife ist ein ganzzahliges Vielfaches des Takts - sonst liefe die
## Taktrechnung von _time_to_next_bar aus dem Ruder.
func test_the_loop_is_whole_bars() -> void:
	assert_almost_eq(MusicDirector.BAR_TIME, 2.0, 0.0001)
	assert_almost_eq(MusicDirector.LOOP_TIME,
		MusicDirector.BAR_TIME * MusicDirector.LOOP_BARS, 0.0001)
	assert_eq(MusicDirector.STEPS, MusicDirector.LOOP_BARS * 16)
	assert_almost_eq(MusicDirector.STEP_TIME * 16.0, MusicDirector.BAR_TIME, 0.0001)

## Jede Figur liegt innerhalb ihrer zwei Takte, sonst stampfte sie in den
## nächsten Durchlauf.
func test_the_figures_fit_their_two_bars() -> void:
	for note: Array in MusicDirector.BASS_A + MusicDirector.BASS_B:
		assert_between(int(note[0]), 0, 31, "Bass-Schritt außerhalb der zwei Takte")
	for stab: Array in MusicDirector.KEYS_A + MusicDirector.KEYS_B:
		assert_between(int(stab[0]), 0, 31, "Keys-Schritt außerhalb der zwei Takte")
	for step: int in MusicDirector.KICK_STEPS + MusicDirector.SNARE_STEPS \
			+ MusicDirector.GHOST_STEPS:
		assert_between(step, 0, 31, "Drum-Schritt außerhalb der zwei Takte")
