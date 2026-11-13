extends GutTest
## Tests der Wertungs-Zahl (PitScoreView): asymptotische Hitze, Deckelung,
## Farbe aus Hitze und Überhitzung, stille Wertsetzung. Rein rechnerisch - kein
## Szenenbaum nötig (die Pop-/Hitze-Tweens laufen erst im Baum).

func _orb(k: float = 220.0) -> PitScoreView:
	var orb: PitScoreView = autofree(PitScoreView.new())
	orb.size = Vector2(100, 100)
	orb.growth_k = k
	return orb

func test_heat_grows_monotonically_with_value() -> void:
	var orb := _orb()
	var h0 := orb._target_heat()
	orb.value = 50
	var h1 := orb._target_heat()
	orb.value = 500
	var h2 := orb._target_heat()
	assert_eq(h0, 0.0, "bei 0 kalt")
	assert_lt(h0, h1, "größerer Wert -> heißer")
	assert_lt(h1, h2, "monoton steigend")

func test_heat_saturates_below_one() -> void:
	var orb := _orb()
	orb.value = 100000
	assert_almost_eq(orb._target_heat(), 1.0, 0.001, "riesige Werte sättigen")
	assert_lte(orb._target_heat(), 1.0)

func test_smaller_k_heats_faster() -> void:
	# Gleicher Wert: der Mult (kleines K) glüht stärker als die Basis (großes K).
	var base := _orb(260.0)
	var mult := _orb(20.0)
	base.value = 30
	mult.value = 30
	assert_gt(mult._target_heat(), base._target_heat())

func test_hot_number_is_brighter_than_cold() -> void:
	var orb := _orb()
	orb.set_value_silent(0)
	var cold := orb.number_color()
	orb.set_value_silent(100000)
	var hot := orb.number_color()
	assert_gt(hot.g + hot.b, cold.g + cold.b, "die Ziffer glüht mit dem Wert auf")
	assert_gt(maxf(hot.g, hot.b), 1.0, "gesättigt über der Bloom-Schwelle")

func test_set_value_silent_sets_value_and_heat() -> void:
	var orb := _orb()
	orb.set_value_silent(200)
	assert_eq(orb.value, 200)
	assert_almost_eq(orb._heat, orb._target_heat(), 0.001,
		"stille Setzung springt sofort auf die Ziel-Hitze")

func test_overbright_pulls_toward_white() -> void:
	var orb := _orb()
	assert_false(orb.overbright)
	var plain := orb.number_color()
	orb.set_overbright(true)
	assert_true(orb.overbright)
	assert_gt(orb.number_color().r, plain.r, "Cyan bekommt Rot dazu - Richtung Weiß-heiß")

func test_number_size_follows_the_goal_label() -> void:
	var orb := _orb()
	orb.number_px = TableScreen.SCORE_FONT_PX
	assert_eq(orb.font_px(), TableScreen.SCORE_FONT_PX)
