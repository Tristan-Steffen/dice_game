extends GutTest
## Tests der Orb-Zustandswechsel im TableScreen: Zähler-Orbs vs. Gesamt-Orb,
## Wertsetzung und Ziel-Blitz, Reset auf Ruhe. Baut einen echten TableScreen.

func _screen() -> TableScreen:
	var ts: TableScreen = add_child_autofree(TableScreen.new())
	ts.configure_pit_score(Vector2(600, 600), Vector2(1800, 600), Vector2(400, 400))
	return ts

func test_update_pit_score_shows_side_orbs_and_hides_total() -> void:
	var ts := _screen()
	ts.total_orb.visible = true
	ts.update_pit_score(120, 6)
	assert_true(ts.base_counter.visible, "Basis-Orb sichtbar")
	assert_true(ts.mult_counter.visible, "Mult-Orb sichtbar")
	assert_false(ts.total_orb.visible, "Gesamt-Orb ausgeblendet")
	assert_eq(ts.base_counter.value, 120)
	assert_eq(ts.mult_counter.value, 6)

func test_update_pit_total_sets_value_and_goal_flash() -> void:
	var ts := _screen()
	ts.update_pit_total(900, true)
	assert_eq(ts.total_orb.value, 900)
	assert_true(ts.total_orb.overbright, "Ziel geknackt -> überheiß")

func test_update_pit_total_without_clearing_goal_stays_normal() -> void:
	var ts := _screen()
	ts.update_pit_total(300, false)
	assert_eq(ts.total_orb.value, 300)
	assert_false(ts.total_orb.overbright)

func test_reset_collapses_to_dormant_side_orbs() -> void:
	var ts := _screen()
	ts.update_pit_score(120, 6)
	ts.reset_pit_score()
	assert_false(ts.total_orb.visible, "Gesamt-Orb weg")
	assert_true(ts.base_counter.visible)
	assert_true(ts.mult_counter.visible)
	assert_eq(ts.base_counter.value, 0, "Basis auf 0")
	assert_eq(ts.mult_counter.value, 0, "Mult auf 0")

func test_merge_orbs_eventually_shows_total() -> void:
	var ts := _screen()
	ts.update_pit_score(240, 12)
	ts.merge_orbs(2880, false)
	# Der Einschlag folgt nach der Bogen-Animation (MERGE_ORBIT_TIME).
	await wait_seconds(TableScreen.MERGE_ORBIT_TIME + 0.1)
	assert_true(ts.total_orb.visible, "nach dem Einschlag trägt der Gesamt-Orb")
	assert_eq(ts.total_orb.value, 2880)
	assert_false(ts.base_counter.visible, "Seiten-Orbs verschmolzen")
	assert_false(ts.mult_counter.visible)
