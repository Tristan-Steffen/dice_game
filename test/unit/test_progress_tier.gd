extends GutTest
## Tests der Fortschrittsstufe (GameRun.progress_tier): die Abbildung aus der Runde,
## die Leitern, die an ihr hängen, und der Überladungs-Deckel.

func _run(money: int = 0) -> GameRun:
	var run := GameRun.new_run()
	run.money = money
	return run

## Erste Runde der gewünschten Stufe.
func _run_at(tier: int) -> GameRun:
	var run := _run(9999)
	run.round_number = 1 + (tier - 1) * GameRun.ROUNDS_PER_TIER
	return run

func test_the_tier_follows_the_round() -> void:
	var run := _run()
	var expected := {1: 1, 3: 1, 4: 2, 6: 2, 7: 3, 25: 9, 27: 9, 28: 10, 40: 10, 999: 10}
	for round_number: int in expected:
		run.round_number = round_number
		assert_eq(run.progress_tier(), int(expected[round_number]), "Runde %d" % round_number)

func test_the_tier_never_drops_below_one() -> void:
	var run := _run()
	run.round_number = 0
	assert_eq(run.progress_tier(), 1)

func test_the_tier_climbs_with_advance_round() -> void:
	var run := _run()
	for i in GameRun.ROUNDS_PER_TIER:
		run.advance_round()
	assert_eq(run.progress_tier(), 2, "nach drei Runden die zweite Stufe")

func test_rarity_tiers_scale_with_the_tier() -> void:
	assert_eq(_run_at(1).shop_rarity_tier(), 0, "Stufe 1: keine")
	assert_eq(_run_at(6).shop_rarity_tier(), 1, "Stufe 6: ungewöhnlich")
	assert_eq(_run_at(9).shop_rarity_tier(), 2, "Stufe 9: selten")
	assert_eq(_run_at(10).shop_rarity_tier(), 3, "Stufe 10: legendär")

func test_cheap_flipping_from_tier_eight() -> void:
	assert_eq(_run_at(7).shop_flip_fee_factor(), 1.0)
	assert_eq(_run_at(8).shop_flip_fee_factor(), 0.5, "Stufe 8 halbiert die Blätter-Gebühr")

func test_shop_slots_scale_with_the_tier() -> void:
	var run := _run_at(1)
	# Stufe 1: wenige, große Angebote (2 Charms / 3 Einzelwürfel).
	# Charm- und Würfel-Leiter springen auf denselben Stufen (3/6/9); die
	# Gravuren-Spalte ist FLACH - drei Plätze auf jeder Stufe.
	assert_eq(run.shop_charm_slots(), 2)
	assert_eq(run.shop_dice_slots(), 3)
	assert_eq(run.shop_pack_slots(), 3)
	run = _run_at(2)  # noch kein 4. Würfel
	assert_eq(run.shop_dice_slots(), 3)
	run = _run_at(3)  # größerer Laden
	assert_eq(run.shop_charm_slots(), 3)
	assert_eq(run.shop_dice_slots(), 4)
	run = _run_at(7)
	assert_eq(run.shop_dice_slots(), 5)
	assert_eq(run.shop_pack_slots(), 3, "die Reihe war schon auf Stufe 1 voll")
	run = _run_at(10)  # voller Laden
	assert_eq(run.shop_charm_slots(), 5)
	assert_eq(run.shop_dice_slots(), 6, "die Schale trägt sechs")
	assert_eq(run.shop_pack_slots(), 3)

func test_overcharge_frame_is_five_from_the_first_tier() -> void:
	var run := _run()
	run.round_goal = 150
	assert_eq(run.overcharge_frame(), 5, "Stufe 1: schon der volle Rahmen")
	assert_eq(run.max_overcharge_stages(), 5)
	assert_eq(run.stages_cleared(4650), 5)
	var p := run.stage_progress(4650)
	assert_eq(p["cleared"], 5)
	assert_eq(p["stage"], 5)
	assert_eq(p["into_stage"], p["stage_size"], "volle Stufe")

func test_the_tier_does_not_move_the_frame() -> void:
	var run := _run_at(7)
	run.round_goal = 150
	assert_eq(run.max_overcharge_stages(), 5, "der Rahmen wächst nicht mit der Stufe")
	assert_eq(run.stages_cleared(4650), 5)

func test_thresholds_crossed_respects_cap() -> void:
	var run := _run()  # Stufe 1, Rahmen 5
	run.round_goal = 150
	# 0 -> 99999 kreuzt genau die fünf Schwellen des Rahmens.
	assert_eq(run.thresholds_crossed(0, 99999).size(), 5)

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

# --- Fumble-Automaten (Ökonomie) ---------------------------------------------

func test_every_machine_spins_from_round_one() -> void:
	var run := _run(100)
	run.energy = 5
	run.slot_bank.fumble_chance = 0.0
	for machine in SlotMachine.MACHINE_COUNT:
		assert_true(run.can_spin_slot(machine), "Automat %d steht ab Runde 1 offen" % machine)
	var before := run.energy
	run.spin_slot(0)
	assert_eq(run.energy, before - run.slot_spin_energy(0), "Einsatz abgezogen")
	assert_false(run.slot_bank.can_spin(0), "Automat gedreht")

func test_cannot_spin_slot_without_energy() -> void:
	var run := _run(100)  # Geld hilft nicht: der Dreh kostet Energie
	run.energy = 0
	assert_false(run.can_spin_slot(0))

func test_redeem_books_run_prizes() -> void:
	const M := SlotPrize.Kind.MATERIAL
	const S := SlotPrize.Kind.ENGRAVING
	const C := SlotPrize.Kind.ENERGY
	const D := SlotPrize.Kind.DIE
	var run := _run(9999)
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

# --- Sonderposten im normalen Regal (ab Stufe 8) ------------------------------

## Vor der Schwelle gibt es sie einzig im Hinterzimmer.
func test_the_shelf_carries_no_special_before_its_tier() -> void:
	for tier in range(1, GameRun.SHOP_SPECIAL_TIER):
		assert_eq(_run_at(tier).shop_special_chance(), 0.0, "Stufe %d führt keinen" % tier)

## Ab der Schwelle steigt die Chance mit jeder Stufe - nie fällt sie.
func test_the_special_chance_climbs_with_the_tier() -> void:
	var previous := 0.0
	for tier in range(GameRun.SHOP_SPECIAL_TIER, GameRun.TIER_MAX + 1):
		var chance := _run_at(tier).shop_special_chance()
		assert_gt(chance, previous, "Stufe %d liegt über der vorigen" % tier)
		assert_lte(chance, 1.0, "eine Chance bleibt eine Chance")
		previous = chance

## Eine Runde weit hinter der letzten Stufe behält die Spitzen-Chance.
func test_a_round_beyond_the_cap_keeps_the_top_chance() -> void:
	var top := _run_at(GameRun.TIER_MAX).shop_special_chance()
	var run := _run()
	run.round_number = 999
	assert_eq(run.shop_special_chance(), top)
