extends GutTest
## Die Show der Schatulle: die Grund-Würfel kommen ruhig, jeder Zusatz-Würfel kommt
## größer als der vorige, und das Rütteln davor wird länger.

func test_the_base_dice_come_at_a_calm_beat() -> void:
	assert_gt(CaseShow.launch_beat(), 0.2)
	assert_eq(CaseShow.pitch(0), CaseShow.pitch(0), "alle Grund-Würfel auf demselben Ton")
	assert_almost_eq(CaseShow.launch_gain(0), 1.0, 0.0001)

func test_every_extra_die_is_bigger_than_the_one_before() -> void:
	for level in range(1, 6):
		assert_gt(CaseShow.glow(level), CaseShow.glow(level - 1), "heller")
		assert_gt(CaseShow.launch_gain(level), CaseShow.launch_gain(level - 1), "höher")
		assert_gt(CaseShow.pitch(level), CaseShow.pitch(level - 1), "höherer Ton")

func test_the_rattle_grows_but_stays_short() -> void:
	for rounds in range(1, 6):
		assert_gte(CaseShow.rattle_time(rounds), CaseShow.rattle_time(rounds - 1))
	assert_lte(CaseShow.rattle_time(10), CaseShow.RATTLE_MAX)
	assert_gt(CaseShow.rattle_time(0), 0.0, "das Rütteln vor dem Zuschlagen gibt es immer")

func test_the_reel_rises_in_pitch() -> void:
	for value in range(2, 10):
		assert_gte(CaseShow.reel_pitch(value, 9), CaseShow.reel_pitch(value - 1, 9))
	assert_gt(CaseShow.reel_pitch(9, 9), CaseShow.reel_pitch(1, 9))
