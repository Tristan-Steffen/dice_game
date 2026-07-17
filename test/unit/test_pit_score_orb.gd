extends GutTest
## Tests des Wertungs-Orbs (PitScoreView): asymptotisches Radius-Wachstum,
## Deckelung, Ruhezustand und stille Wertsetzung. Rein rechnerisch - kein
## Szenenbaum nötig (die Pop-/Wachstums-Tweens laufen erst im Baum).

func _orb(k: float = 220.0) -> PitScoreView:
	var orb: PitScoreView = autofree(PitScoreView.new())
	orb.size = Vector2(100, 100)
	orb.growth_k = k
	return orb

func test_radius_grows_monotonically_with_value() -> void:
	var orb := _orb()
	var r0 := orb._target_glow_radius()
	orb.value = 50
	var r1 := orb._target_glow_radius()
	orb.value = 500
	var r2 := orb._target_glow_radius()
	assert_lt(r0, r1, "größerer Wert -> größerer Radius")
	assert_lt(r1, r2, "monoton steigend")

func test_radius_capped_below_r_max() -> void:
	var orb := _orb()
	orb.value = 100000
	var r := orb._target_glow_radius()
	var cap := orb.size.y * PitScoreView.R_MAX_FRAC
	assert_lt(r, cap + 0.001, "nie über R_MAX")
	assert_almost_eq(r, cap, orb.size.y * 0.02, "riesige Werte sättigen an R_MAX")

func test_dormant_radius_at_zero() -> void:
	var orb := _orb()  # value 0
	assert_almost_eq(orb._target_glow_radius(),
		orb.size.y * PitScoreView.R_MIN_FRAC, 0.001)

func test_smaller_k_saturates_faster() -> void:
	# Gleicher Wert: der Mult-Orb (kleines K) leuchtet stärker als Basis (großes K).
	var base := _orb(260.0)
	var mult := _orb(20.0)
	base.value = 30
	mult.value = 30
	assert_gt(mult._target_glow_radius(), base._target_glow_radius())

func test_set_value_silent_sets_value_and_radius() -> void:
	var orb := _orb()
	orb.set_value_silent(200)
	assert_eq(orb.value, 200)
	assert_almost_eq(orb._glow_radius, orb._target_glow_radius(), 0.001,
		"stille Setzung springt sofort auf den Zielradius")

func test_overbright_flag_toggles() -> void:
	var orb := _orb()
	assert_false(orb.overbright)
	orb.set_overbright(true)
	assert_true(orb.overbright)
