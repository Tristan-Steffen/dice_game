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
	# Stufe 1: wenige, große Angebote (2 Charms / 1 Würfel-Paket / 1 Gravur-Paket).
	assert_eq(run.shop_charm_slots(), 2)
	assert_eq(run.shop_dice_slots(), 1)
	assert_eq(run.shop_pack_slots(), 1)
	run.upgrade_hub()  # 2 Spielecke: noch kein 2. Paket
	assert_eq(run.shop_dice_slots(), 1)
	run.upgrade_hub()  # 3 Lizenz: größerer Laden
	assert_eq(run.shop_charm_slots(), 3)
	assert_eq(run.shop_dice_slots(), 2)
	for i in 4:
		run.upgrade_hub()  # -> 7 Suite: 3. Würfel-Paket
	assert_eq(run.shop_dice_slots(), 3)
	assert_eq(run.shop_pack_slots(), 3)
	for i in 3:
		run.upgrade_hub()  # -> 10 High Roller: voller Laden
	assert_eq(run.shop_charm_slots(), 5)
	assert_eq(run.shop_pack_slots(), 4)

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
	assert_eq(run.goal_roadmap(6), [150, 225, 300, 375, 450, 525] as Array[int])
	assert_eq(run.goal_roadmap_index(6), 0, "Runde 1 = erste Station")

func test_goal_roadmap_block_stays_fixed_while_position_advances() -> void:
	var run := _run()
	run.advance_round()  # Runde 2, Ziel 225
	run.advance_round()  # Runde 3, Ziel 300
	assert_eq(run.goal_roadmap(6), [150, 225, 300, 375, 450, 525] as Array[int],
		"derselbe Block wie in Runde 1")
	assert_eq(run.goal_roadmap_index(6), 2, "dritte Station ist dran")

func test_goal_roadmap_rolls_to_a_fresh_block_after_the_sixth() -> void:
	var run := _run()
	for i in 6:
		run.advance_round()  # -> Runde 7, Ziel 675
	# Der zweite Block steigt in 150er-Schritten (Zuwachs verdoppelt sich je Block).
	assert_eq(run.goal_roadmap(6), [675, 825, 975, 1125, 1275, 1425] as Array[int],
		"nach dem sechsten Sieg liegt ein frischer Block aus")
	assert_eq(run.goal_roadmap_index(6), 0, "wieder die erste Station")

func test_goal_roadmap_matches_the_curve_across_blocks() -> void:
	# Der Fahrplan zeigt exakt die Ziel-Kurve, auch im dritten Block (300er-Schritte).
	var run := _run()
	for i in 12:
		run.advance_round()  # -> Runde 13
	assert_eq(run.goal_roadmap(6), [1725, 2025, 2325, 2625, 2925, 3225] as Array[int])

# --- Fumble-Automaten (Freischaltung + Ökonomie) ------------------------------

func test_slots_unlock_one_after_another() -> void:
	var run := _run(9999)
	assert_eq(run.slots_unlocked(), 0, "Stufe 1: kein Automat")
	for i in 2:
		run.upgrade_hub()  # -> 3 Lizenz
	assert_eq(run.slots_unlocked(), 1, "Lizenz: Automat I")
	for i in 3:
		run.upgrade_hub()  # -> 6 VIP-Lounge
	assert_eq(run.slots_unlocked(), 2, "VIP-Lounge: Automat II")
	for i in 3:
		run.upgrade_hub()  # -> 9 Privatclub
	assert_eq(run.slots_unlocked(), 3, "Privatclub: Automat III")

func test_spin_slot_pays_and_gates_on_unlock() -> void:
	var run := _run(100)
	run.hub_level = 3  # Automat I frei
	run.slot_bank.fumble_chance = 0.0
	assert_false(run.can_spin_slot(1), "Automat II noch gesperrt")
	assert_true(run.can_spin_slot(0))
	var before := run.money
	run.spin_slot(0)
	assert_eq(run.money, before - run.slot_spin_price(0), "Einsatz abgezogen")
	assert_false(run.slot_bank.can_spin(0), "Automat gedreht")

func test_cannot_spin_slot_without_money() -> void:
	var run := _run(2)  # Einsatz Automat I = 8
	run.hub_level = 3
	assert_false(run.can_spin_slot(0))

func test_redeem_books_run_prizes() -> void:
	const M := SlotPrize.Kind.MATERIAL
	const S := SlotPrize.Kind.ENGRAVING
	const C := SlotPrize.Kind.CHARM
	const D := SlotPrize.Kind.DIE
	var run := _run(9999)
	run.hub_level = 9  # alle drei frei
	# Handgebaute 5×9-Wand: obere Zeile drei Zahlen-Symbole in Automat 0 (3er-Reihe
	# ⇒ 1 Zahlen-Paket). Restzeilen im mod-4-Muster bilden in KEINER Richtung eine
	# Reihe (nur so ist die Zahlen-Reihe die einzige).
	var syms := [M, S, C, D]
	for c in SlotMachine.TOTAL_COLS:
		var col: Array = []
		for r in SlotMachine.ROWS:
			if r == 0:
				col.append(S if c < 3 else [M, S, C, M, C, M, C, M, C][c])
			else:
				col.append(syms[(c + 2 * r) % 4])
		run.slot_bank.cells[c] = col
	run.slot_bank.spun = [true, true, true]
	assert_eq(run.slot_bank.hit_count(), 1, "genau eine Reihe")
	var money_before := run.money
	var packs_before := run.owned_packs.size()
	# Auswürfeln und Buchen sind getrennt: gebucht wird erst, wenn der Gewinn als
	# Licht den Automaten verlässt (book_slot_prize).
	for prize: SlotPrize in run.redeem_slots()["prizes"]:
		run.book_slot_prize(prize)
	assert_eq(run.owned_packs.size(), packs_before + 1, "3er-Zahlen-Reihe gebucht")
	assert_eq(run.money, money_before, "der Automat zahlt kein Geld")
	assert_eq(run.slot_bank.hit_count(), 0, "Sitzung zurückgesetzt")
