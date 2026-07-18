extends GutTest
## Tests der Überladungs-Mathematik (GameRun): Stufengrößen, kumulative
## Schwellen, gefüllte Stufen (mit Deckelung) und der Balken-Fortschritt inkl.
## Überschuss-Übertrag.

func _run(goal: int = 150) -> GameRun:
	var run := GameRun.new_run()
	run.round_goal = goal
	return run

func test_stage_sizes_double_each_step() -> void:
	var run := _run(150)
	assert_eq(run.stage_size(1), 150)
	assert_eq(run.stage_size(2), 300)
	assert_eq(run.stage_size(3), 600)
	assert_eq(run.stage_size(4), 1200)
	assert_eq(run.stage_size(5), 2400)

func test_cumulative_thresholds() -> void:
	var run := _run(150)
	assert_eq(run.cumulative_threshold(1), 150)
	assert_eq(run.cumulative_threshold(2), 450)
	assert_eq(run.cumulative_threshold(3), 1050)
	assert_eq(run.cumulative_threshold(4), 2250)
	assert_eq(run.cumulative_threshold(5), 4650)

func test_stages_cleared_on_boundaries() -> void:
	var run := _run(150)
	assert_eq(run.stages_cleared(0), 0)
	assert_eq(run.stages_cleared(149), 0)
	assert_eq(run.stages_cleared(150), 1, "genau auf der Schwelle zählt als geräumt")
	assert_eq(run.stages_cleared(449), 1)
	assert_eq(run.stages_cleared(450), 2)
	assert_eq(run.stages_cleared(4650), 5)

func test_stages_cleared_caps_at_max() -> void:
	var run := _run(150)
	assert_eq(run.stages_cleared(999999), GameRun.OVERCHARGE_STAGES)

func test_stage_progress_carries_overflow() -> void:
	var run := _run(150)
	# 200 Punkte: Stufe 1 voll (150), 50 tragen in Stufe 2 (Größe 300) über.
	var p := run.stage_progress(200)
	assert_eq(p["stage"], 2)
	assert_eq(p["cleared"], 1)
	assert_eq(p["into_stage"], 50)
	assert_eq(p["stage_size"], 300)

func test_stage_progress_at_zero() -> void:
	var run := _run(150)
	var p := run.stage_progress(0)
	assert_eq(p["stage"], 1)
	assert_eq(p["cleared"], 0)
	assert_eq(p["into_stage"], 0)
	assert_eq(p["stage_size"], 150)

func test_stage_progress_full_overcharge_is_full_bar() -> void:
	var run := _run(150)
	var p := run.stage_progress(5000)  # über 4650
	assert_eq(p["cleared"], 5)
	assert_eq(p["stage"], GameRun.OVERCHARGE_STAGES)
	assert_eq(p["into_stage"], p["stage_size"], "letzte Stufe voll gefüllt")

func test_scales_with_round_goal() -> void:
	var run := _run(200)  # höheres Basisziel
	assert_eq(run.stage_size(2), 400)
	assert_eq(run.cumulative_threshold(3), 1400)  # 200 * 7

func test_thresholds_crossed_none_within_a_stage() -> void:
	var run := _run(150)
	assert_eq(run.thresholds_crossed(10, 140), [], "keine Schwelle zwischen 10 und 140")

func test_thresholds_crossed_single() -> void:
	var run := _run(150)
	assert_eq(run.thresholds_crossed(100, 200), [150], "eine Schwelle (150) überschritten")

func test_thresholds_crossed_several() -> void:
	var run := _run(150)
	# 100 -> 1200 kreuzt 150, 450, 1050.
	assert_eq(run.thresholds_crossed(100, 1200), [150, 450, 1050])

func test_thresholds_crossed_boundary_is_inclusive_on_upper() -> void:
	var run := _run(150)
	assert_eq(run.thresholds_crossed(0, 150), [150], "genau auf der Schwelle zählt")
	assert_eq(run.thresholds_crossed(150, 300), [], "Untergrenze exklusiv - 150 nicht erneut")

func test_thresholds_crossed_caps_at_last_stage() -> void:
	var run := _run(150)
	# 0 -> 99999 kreuzt alle fünf Schwellen, nicht mehr.
	assert_eq(run.thresholds_crossed(0, 99999).size(), GameRun.OVERCHARGE_STAGES)
