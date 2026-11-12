extends GutTest
## Die Show der Schatulle steigert sich mit jedem Würfel, der letzte ist der Höhepunkt.

func test_every_die_gets_a_bigger_moment_than_the_one_before() -> void:
	for count in [2, 5, 10]:
		for i in range(1, count):
			assert_gt(CaseShow.glow(i, count), CaseShow.glow(i - 1, count), "heller")
			assert_gte(CaseShow.pitch(i, count), CaseShow.pitch(i - 1, count), "höher")
		assert_gt(CaseShow.pitch(count - 1, count), CaseShow.pitch(0, count))

func test_the_beat_quickens_and_holds_before_the_climax() -> void:
	var count := 8
	for i in range(1, count - 1):
		assert_lt(CaseShow.beat(i, count), CaseShow.beat(i - 1, count), "der Takt beschleunigt")
	assert_gt(CaseShow.beat(count - 1, count), CaseShow.beat(count - 2, count),
		"vor dem letzten hält sie den Atem an")

func test_the_last_die_is_the_climax_on_the_top_of_the_ladder() -> void:
	assert_true(CaseShow.is_climax(4, 5))
	assert_false(CaseShow.is_climax(3, 5))
	assert_eq(CaseShow.pitch_step(4, 5), ScoreAudio.LADDER.size() - 1)
	assert_true(CaseShow.is_climax(0, 1), "ein einzelner Würfel ist sein eigener Höhepunkt")
	assert_gt(CaseShow.glow(9, 10) - CaseShow.glow(8, 10),
		CaseShow.glow(8, 10) - CaseShow.glow(7, 10), "der Höhepunkt springt")
