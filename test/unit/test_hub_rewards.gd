extends GutTest
## Belohnung des Hub-Ausbaus. Ab Stufe 2 IMMER EIN beseelter Würfel, direkt
## gewürfelt und ins Ausgabefach gelegt (pending_dice) - Würfel sind keine
## Paketware. HUB_REWARD_PACKS legt je Stufe versiegelte Gravur-Pakete obendrauf.

func _run_at(level: int) -> GameRun:
	var run := GameRun.new_run()
	run.money = 100000
	while run.hub_level < level:
		run.upgrade_hub()
	return run

func _counts(run: GameRun) -> Dictionary:
	var counts := {}
	for pack in run.owned_packs:
		counts[pack.type] = int(counts.get(pack.type, 0)) + 1
	return counts

func test_a_fresh_run_gets_nothing() -> void:
	var run := GameRun.new_run()
	assert_eq(run.owned_packs.size(), 0, "der Start ist keine Belohnung")
	assert_eq(run.pending_dice.size(), 0)

func test_every_level_from_two_grants_one_die_into_the_tray() -> void:
	for level in range(2, GameRun.HUB_MAX_LEVEL + 1):
		var run := _run_at(level)
		assert_eq(run.pending_dice.size(), level - 1,
			"Stufe %d: je Aufstieg ein Würfel im Ausgabefach" % level)

func test_the_reward_die_always_carries_a_soul() -> void:
	for _i in 30:
		var run := GameRun.new_run()
		run.money = 100000
		run.upgrade_hub()
		assert_eq(run.pending_dice.size(), 1)
		assert_ne(run.pending_dice[0].essence_id, "", "der Prämien-Würfel ist beseelt")

func test_the_reward_die_costs_nothing() -> void:
	var run := GameRun.new_run()
	run.money = 100000
	var price := run.hub_upgrade_price()
	run.upgrade_hub()
	assert_eq(run.money, 100000 - price, "bezahlt wird nur die Lizenz")

func test_a_normal_offer_die_still_rolls_soulless_sometimes() -> void:
	var soulless := 0
	for _i in 120:
		for offer in DiceOffer.roll_offers(1):
			for die in offer.dice:
				if die.essence_id == "":
					soulless += 1
	assert_gt(soulless, 0, "ohne Garantie bleibt die Chance eine Chance")

func test_an_owned_unique_is_never_offered_again() -> void:
	# Die Garantie hebelt den Unikat-Ausschluss nicht aus - sie überspringt nur
	# den Chancen-Wurf.
	var unique_id := ""
	for essence in Essence.all():
		if essence.unique and not essence.secret:
			unique_id = essence.id
			break
	assert_ne(unique_id, "", "es gibt handelbare Unikate")
	var owned: Array[String] = [unique_id]
	for _i in 300:
		assert_ne(DiceOffer.roll_essence(owned, true, true), unique_id,
			"ein besessenes Unikat fällt nicht noch einmal")

func test_the_guarantee_never_offers_a_secret_soul() -> void:
	for _i in 80:
		var die := DiceOffer.roll_reward_die()
		var essence := Essence.by_id(die.essence_id)
		assert_false(essence != null and essence.secret,
			"Schwarzmarkt-Seelen liegen nie im normalen Handel")

func test_the_guarantee_falls_back_rather_than_leaving_a_die_soulless() -> void:
	# Alle Unikate bereits im Besitz: es muss trotzdem eine Seele herauskommen.
	var owned: Array[String] = []
	for essence in Essence.all():
		if essence.unique:
			owned.append(essence.id)
	for _i in 40:
		var die := DiceOffer.roll_reward_die([], owned)
		assert_ne(die.essence_id, "", "lieber ein Nicht-Unikat als gar keine Seele")

# --- Die Tabelle ---------------------------------------------------------------------

func test_level_five_adds_two_number_and_one_material_pack() -> void:
	var before := _counts(_run_at(4))
	var after := _counts(_run_at(5))
	assert_eq(int(after.get(Pack.TYPE_NUMBER, 0)) - int(before.get(Pack.TYPE_NUMBER, 0)), 2)
	assert_eq(int(after.get(Pack.TYPE_MATERIAL, 0)) - int(before.get(Pack.TYPE_MATERIAL, 0)), 1)

func test_level_ten_adds_three_number_two_material_and_a_rune_pack() -> void:
	var before := _counts(_run_at(9))
	var after := _counts(_run_at(10))
	assert_eq(int(after.get(Pack.TYPE_NUMBER, 0)) - int(before.get(Pack.TYPE_NUMBER, 0)), 3)
	assert_eq(int(after.get(Pack.TYPE_MATERIAL, 0)) - int(before.get(Pack.TYPE_MATERIAL, 0)), 2)
	assert_eq(int(after.get(Pack.TYPE_DICE_MOD, 0)) - int(before.get(Pack.TYPE_DICE_MOD, 0)), 1)

func test_unlisted_levels_grant_only_the_die() -> void:
	for level in [2, 3, 4, 6, 7, 8, 9]:
		var before := _run_at(level - 1).owned_packs.size()
		var after := _run_at(level).owned_packs.size()
		assert_eq(after - before, 0, "Stufe %d: nur der Würfel, kein Paket" % level)

## --- Merkliste für die Reveal-Zeremonie ------------------------------------------

func test_the_upgrade_remembers_its_die_and_its_packs() -> void:
	var run := GameRun.new_run()
	run.money = 100000
	run.upgrade_hub()  # Stufe 2: nur der beseelte Würfel
	assert_eq(run.last_hub_reward_packs.size(), 0)
	assert_not_null(run.last_hub_reward_die)
	assert_eq(run.last_hub_reward_die, run.pending_dice[0],
		"die Zeremonie fliegt genau das hinterlegte Exemplar an")

func test_the_reward_list_holds_only_the_extra_packs() -> void:
	var run := _run_at(5)  # Stufe 5: Würfel + 2x Zahlen + Material
	assert_eq(run.last_hub_reward_packs.size(), 3)
	var extras: Array[String] = []
	for pack in run.last_hub_reward_packs:
		extras.append(pack.type)
	assert_eq(extras.count(Pack.TYPE_NUMBER), 2)
	assert_true(extras.has(Pack.TYPE_MATERIAL))

func test_the_reward_list_holds_the_packs_that_really_went_into_stock() -> void:
	# Die Zeremonie darf nichts zeigen, was nicht im Lager liegt - sie bucht nicht.
	var run := _run_at(5)
	for pack in run.last_hub_reward_packs:
		assert_true(run.owned_packs.has(pack), "gezeigt wird nur, was gebucht ist")

func test_each_upgrade_replaces_the_reward_memory() -> void:
	var run := GameRun.new_run()
	run.money = 100000
	run.upgrade_hub()
	var first := run.last_hub_reward_die
	run.upgrade_hub()
	assert_ne(run.last_hub_reward_die, first, "die Merkliste erzählt vom JÜNGSTEN Ausbau")
	assert_eq(run.pending_dice.size(), 2, "im Fach liegen aber beide")

func test_an_unaffordable_upgrade_leaves_the_reward_memory_alone() -> void:
	var run := GameRun.new_run()
	run.money = 100000
	run.upgrade_hub()
	var first := run.last_hub_reward_die
	run.money = 0
	run.upgrade_hub()  # scheitert
	assert_eq(run.last_hub_reward_die, first, "ohne Aufstieg keine neue Merkliste")

func test_the_upgrade_reports_its_packs_once() -> void:
	var run := GameRun.new_run()
	run.money = 100000
	while run.hub_level < 4:
		run.upgrade_hub()
	var emits := []
	run.packs_changed.connect(func() -> void: emits.append(1))
	run.upgrade_hub()  # Stufe 5 bringt drei Gravur-Pakete
	assert_eq(emits.size(), 1, "das Lager meldet sich genau einmal")

func test_the_upgrade_reports_its_die() -> void:
	var run := GameRun.new_run()
	run.money = 100000
	var emits := []
	run.pending_dice_changed.connect(func() -> void: emits.append(1))
	run.upgrade_hub()
	assert_eq(emits.size(), 1, "das Ausgabefach meldet sich genau einmal")

func test_an_unaffordable_upgrade_grants_nothing() -> void:
	var run := GameRun.new_run()
	run.money = 0
	run.upgrade_hub()
	assert_eq(run.hub_level, 1, "kein Aufstieg")
	assert_eq(run.owned_packs.size(), 0, "und keine Belohnung")
	assert_eq(run.pending_dice.size(), 0)

func test_a_full_magazine_never_swallows_the_die() -> void:
	# Der Deckel gilt fürs Magazin, nicht fürs Ausgabefach.
	var run := GameRun.new_run()
	run.money = 100000
	while run.hub_level < 4:
		run.upgrade_hub()
	run.pack_capacity = run.owned_packs.size()
	var before := run.pending_dice.size()
	run.upgrade_hub()  # Stufe 5: die Pakete zerfallen, der Würfel nicht
	assert_eq(run.pending_dice.size(), before + 1, "der Würfel kommt immer an")
	assert_eq(run.last_hub_reward_fizzle, 3, "die drei Pakete sind zu Geld zerfallen")
