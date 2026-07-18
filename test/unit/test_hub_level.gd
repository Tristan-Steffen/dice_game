extends GutTest
## Tests des Hub-Ausbaus (GameRun): Preis-Leiter, Geld-Gate, Maximalstufe, die
## abgeleiteten Struktur-Freischaltungen und der Überladungs-Deckel je Stufe.

func _run(money: int = 0) -> GameRun:
	var run := GameRun.new_run()
	run.money = money
	return run

func test_starts_at_level_one() -> void:
	var run := _run()
	assert_eq(run.hub_level, 1)
	assert_eq(run.hub_level_name(), "Hinterzimmer")

func test_upgrade_price_ladder() -> void:
	var run := _run(999)
	assert_eq(run.hub_upgrade_price(), 8)
	run.upgrade_hub()
	assert_eq(run.hub_upgrade_price(), 12)
	run.upgrade_hub()
	assert_eq(run.hub_upgrade_price(), 18)
	# Obere Stufen sind teuer: der letzte Aufstieg (9→10) kostet am meisten.
	for i in 6:
		run.upgrade_hub()
	assert_eq(run.hub_level, 9)
	assert_eq(run.hub_upgrade_price(), 170, "9→10 der teuerste Aufstieg")

func test_upgrade_deducts_money_and_raises_level() -> void:
	var run := _run(30)
	run.upgrade_hub()
	assert_eq(run.hub_level, 2)
	assert_eq(run.money, 22, "8 abgezogen")

func test_cannot_upgrade_without_money() -> void:
	var run := _run(5)  # Aufstieg kostet 8
	assert_false(run.can_upgrade_hub())
	run.upgrade_hub()
	assert_eq(run.hub_level, 1, "kein Aufstieg ohne Geld")
	assert_eq(run.money, 5, "Geld unangetastet")

func test_upgrade_emits_signal() -> void:
	var run := _run(30)
	watch_signals(run)
	run.upgrade_hub()
	assert_signal_emitted_with_parameters(run, "hub_level_changed", [2])

func test_caps_at_max_level() -> void:
	var run := _run(9999)
	for i in 15:
		run.upgrade_hub()
	assert_eq(run.hub_level, GameRun.HUB_MAX_LEVEL)
	assert_eq(run.hub_level, 10)
	assert_eq(run.hub_upgrade_price(), 0, "keine weitere Stufe")
	assert_false(run.can_upgrade_hub())

func test_side_bets_unlock_at_level_four() -> void:
	var run := _run(9999)
	for i in 2:
		run.upgrade_hub()  # -> 3
	assert_false(run.side_bets_unlocked(), "Stufe 3: noch gesperrt")
	run.upgrade_hub()  # 4
	assert_true(run.side_bets_unlocked(), "Stufe 4 (Parkett): Nebenwetten frei")

func test_flipping_unlocks_at_level_two() -> void:
	var run := _run(9999)
	assert_false(run.shop_flipping_unlocked())
	run.upgrade_hub()  # 2
	assert_true(run.shop_flipping_unlocked())

func test_rarity_tiers_scale_with_level() -> void:
	var run := _run(9999)
	assert_eq(run.shop_rarity_tier(), 0, "Stufe 1: keine")
	for i in 5:
		run.upgrade_hub()  # -> 6 VIP-Lounge
	assert_eq(run.shop_rarity_tier(), 1, "Stufe 6: ungewöhnlich")
	for i in 3:
		run.upgrade_hub()  # -> 9 Privatclub
	assert_eq(run.shop_rarity_tier(), 2, "Stufe 9: selten")
	run.upgrade_hub()  # 10 High Roller
	assert_eq(run.shop_rarity_tier(), 3, "Stufe 10: legendär")

func test_cheap_flipping_at_penthouse() -> void:
	var run := _run(9999)
	assert_eq(run.shop_flip_fee_factor(), 1.0)
	for i in 7:
		run.upgrade_hub()  # -> 8 Penthouse
	assert_eq(run.shop_flip_fee_factor(), 0.5, "Penthouse halbiert die Blätter-Gebühr")

func test_shop_slots_scale_with_level() -> void:
	var run := _run(9999)
	# Stufe 1: wenige, große Angebote (2 Charms / 1 Würfel / 2 Chips = 1 Übertaktung + 1 Sigill).
	assert_eq(run.shop_charm_slots(), 2)
	assert_eq(run.shop_dice_slots(), 1)
	assert_eq(run.shop_chip_slots(), 2)
	assert_eq(run.shop_overclock_slots(), 1)
	assert_eq(run.shop_sigil_slots(), 1)
	run.upgrade_hub()  # 2 Spielecke: mehr Chips, aber noch kein 3. Bündel
	assert_eq(run.shop_chip_slots(), 3)
	assert_eq(run.shop_dice_slots(), 1)
	run.upgrade_hub()  # 3 Lizenz: größerer Laden
	assert_eq(run.shop_charm_slots(), 3)
	assert_eq(run.shop_dice_slots(), 2)
	assert_eq(run.shop_chip_slots(), 5)
	assert_eq(run.shop_overclock_slots(), 1)
	for i in 4:
		run.upgrade_hub()  # -> 7 Suite: 3. Würfel-Bündel + 2. Übertaktung
	assert_eq(run.shop_dice_slots(), 3)
	assert_eq(run.shop_chip_slots(), 8)
	assert_eq(run.shop_overclock_slots(), 2)
	assert_eq(run.shop_sigil_slots(), 6)
	for i in 3:
		run.upgrade_hub()  # -> 10 High Roller: voller Laden
	assert_eq(run.shop_charm_slots(), 5)
	assert_eq(run.shop_chip_slots(), 10)
	assert_eq(run.shop_overclock_slots(), 3, "Übertaktungen gedeckelt bei 3")
	assert_eq(run.shop_sigil_slots(), 7)

func test_overcharge_capped_at_three_below_salon() -> void:
	var run := _run()
	run.round_goal = 150
	assert_eq(run.max_overcharge_stages(), 3, "bis Parkett: Deckel 3")
	# 4650 wäre Stufe 5, aber gedeckelt auf 3.
	assert_eq(run.stages_cleared(4650), 3)
	var p := run.stage_progress(4650)
	assert_eq(p["cleared"], 3)
	assert_eq(p["stage"], 3)
	assert_eq(p["into_stage"], p["stage_size"], "gedeckelte Stufe voll")

func test_overcharge_cap_steps_four_then_five() -> void:
	var run := _run(9999)
	run.round_goal = 150
	for i in 4:
		run.upgrade_hub()  # -> 5 Salon
	assert_eq(run.max_overcharge_stages(), 4, "Salon: Deckel 4")
	for i in 2:
		run.upgrade_hub()  # -> 7 Suite
	assert_eq(run.max_overcharge_stages(), 5, "Suite: volle 5")
	assert_eq(run.stages_cleared(4650), 5)

func test_thresholds_crossed_respects_cap() -> void:
	var run := _run()  # Stufe 1, Deckel 3
	run.round_goal = 150
	# 0 -> 99999 kreuzt nur die ersten drei Schwellen.
	assert_eq(run.thresholds_crossed(0, 99999).size(), 3)

# --- Fahrplan (Ziel-Block bleibt stehen, bis er geschafft ist) ----------------

func test_goal_roadmap_block_starts_at_round_one() -> void:
	var run := _run()  # Runde 1, Ziel 150
	assert_eq(run.goal_roadmap(6), [150, 200, 250, 300, 350, 400] as Array[int])
	assert_eq(run.goal_roadmap_index(6), 0, "Runde 1 = erste Station")

func test_goal_roadmap_block_stays_fixed_while_position_advances() -> void:
	var run := _run()
	run.advance_round()  # Runde 2, Ziel 200
	run.advance_round()  # Runde 3, Ziel 250
	assert_eq(run.goal_roadmap(6), [150, 200, 250, 300, 350, 400] as Array[int],
		"derselbe Block wie in Runde 1")
	assert_eq(run.goal_roadmap_index(6), 2, "dritte Station ist dran")

func test_goal_roadmap_rolls_to_a_fresh_block_after_the_sixth() -> void:
	var run := _run()
	for i in 6:
		run.advance_round()  # -> Runde 7, Ziel 450
	assert_eq(run.goal_roadmap(6), [450, 500, 550, 600, 650, 700] as Array[int],
		"nach dem sechsten Sieg liegt ein frischer Block aus")
	assert_eq(run.goal_roadmap_index(6), 0, "wieder die erste Station")
