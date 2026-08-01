extends GutTest
## Belohnung des Hub-Ausbaus: jede neue Stufe legt versiegelte Ware ins Lager.
## Ab Stufe 2 IMMER ein 3er-Würfel-Paket, dessen drei Auswahl-Würfel alle eine
## Seele tragen; HUB_REWARD_PACKS legt je Stufe Gravur-Pakete obendrauf.

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
	assert_eq(GameRun.new_run().owned_packs.size(), 0, "der Start ist keine Belohnung")

func test_every_level_from_two_grants_a_dice_pack() -> void:
	for level in range(2, GameRun.HUB_MAX_LEVEL + 1):
		var run := _run_at(level)
		assert_eq(int(_counts(run).get(Pack.TYPE_DICE, 0)), level - 1,
			"Stufe %d: je Aufstieg ein Würfel-Paket" % level)

func test_the_dice_pack_is_a_bundle_of_three_with_guaranteed_souls() -> void:
	var run := _run_at(2)
	var dice_packs: Array[Pack] = []
	for pack in run.owned_packs:
		if pack.type == Pack.TYPE_DICE:
			dice_packs.append(pack)
	assert_eq(dice_packs.size(), 1)
	assert_eq(dice_packs[0].count, 3, "ein 3er-Paket - die Wahl ist echt")
	assert_true(dice_packs[0].essence_guaranteed)

func test_every_choice_die_of_a_guaranteed_pack_has_a_soul() -> void:
	var pack := Pack.dice_pack(DiceOffer.TEMPLATES[4])  # Niedrige Serie, count 3
	pack.essence_guaranteed = true
	for _i in 60:
		var dice := pack.roll_dice()
		assert_eq(dice.size(), 3)
		for die in dice:
			assert_ne(die.essence_id, "", "jeder Auswahl-Würfel trägt eine Seele")

func test_a_normal_pack_still_rolls_soulless_dice_sometimes() -> void:
	var pack := Pack.dice_pack(DiceOffer.TEMPLATES[4])
	var soulless := 0
	for _i in 80:
		for die in pack.roll_dice():
			if die.essence_id == "":
				soulless += 1
	assert_gt(soulless, 0, "ohne Garantie bleibt die Chance eine Chance")

func test_the_guarantee_keeps_the_uniqueness_rule() -> void:
	# Ein Unikat darf nie zweimal im selben Paket liegen - auch nicht mit Garantie.
	# Der Zähler hält den Test ehrlich: Unikate sind selten, und ohne ihn liefe er
	# durch, ohne je etwas geprüft zu haben.
	var pack := Pack.dice_pack(DiceOffer.TEMPLATES[4])
	pack.essence_guaranteed = true
	var packs_checked := 0
	for _i in 200:
		var seen: Array[String] = []
		for die in pack.roll_dice():
			var essence := Essence.by_id(die.essence_id)
			if essence != null and essence.unique:
				assert_false(seen.has(die.essence_id), "kein Unikat doppelt: %s" % die.essence_id)
				seen.append(die.essence_id)
		packs_checked += 1
	assert_eq(packs_checked, 200, "200 Pakete wirklich durchgesehen")

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
	var pack := Pack.dice_pack(DiceOffer.TEMPLATES[4])
	pack.essence_guaranteed = true
	for _i in 60:
		for die in pack.roll_dice():
			var essence := Essence.by_id(die.essence_id)
			assert_false(essence != null and essence.secret,
				"Schwarzmarkt-Seelen liegen nie im normalen Handel")

func test_the_guarantee_falls_back_rather_than_leaving_a_die_soulless() -> void:
	# Alle Unikate bereits im Besitz: es muss trotzdem eine Seele herauskommen.
	var owned: Array[String] = []
	for essence in Essence.all():
		if essence.unique:
			owned.append(essence.id)
	var pack := Pack.dice_pack(DiceOffer.TEMPLATES[4])
	pack.essence_guaranteed = true
	for _i in 40:
		for die in pack.roll_dice([], owned):
			assert_ne(die.essence_id, "", "lieber ein Nicht-Unikat als gar keine Seele")

# --- Die Tabelle ---------------------------------------------------------------------

func test_level_five_adds_a_number_and_a_combination_pack() -> void:
	var before := _counts(_run_at(4))
	var after := _counts(_run_at(5))
	assert_eq(int(after.get(Pack.TYPE_NUMBER, 0)) - int(before.get(Pack.TYPE_NUMBER, 0)), 1)
	assert_eq(int(after.get(Pack.TYPE_MIXED, 0)) - int(before.get(Pack.TYPE_MIXED, 0)), 1)

func test_level_ten_adds_two_number_and_three_combination_packs() -> void:
	var before := _counts(_run_at(9))
	var after := _counts(_run_at(10))
	assert_eq(int(after.get(Pack.TYPE_NUMBER, 0)) - int(before.get(Pack.TYPE_NUMBER, 0)), 2)
	assert_eq(int(after.get(Pack.TYPE_MIXED, 0)) - int(before.get(Pack.TYPE_MIXED, 0)), 3)

func test_unlisted_levels_grant_only_the_dice_pack() -> void:
	for level in [2, 3, 4, 6, 7, 8, 9]:
		var before := _run_at(level - 1).owned_packs.size()
		var after := _run_at(level).owned_packs.size()
		assert_eq(after - before, 1, "Stufe %d: nur das Würfel-Paket" % level)

## --- Merkliste für die Reveal-Zeremonie ------------------------------------------

func test_the_upgrade_remembers_exactly_the_packs_it_granted() -> void:
	var run := GameRun.new_run()
	run.money = 100000
	run.upgrade_hub()  # Stufe 2: nur das beseelte Würfel-Paket
	assert_eq(run.last_hub_reward_packs.size(), 1)
	assert_eq(run.last_hub_reward_packs[0].type, Pack.TYPE_DICE)
	assert_true(run.last_hub_reward_packs[0].essence_guaranteed)

func test_the_reward_list_leads_with_the_dice_pack() -> void:
	var run := _run_at(5)  # Stufe 5: Würfel + Zahlen + Gemischt
	assert_eq(run.last_hub_reward_packs.size(), 3)
	assert_eq(run.last_hub_reward_packs[0].type, Pack.TYPE_DICE, "das beseelte Paket zuerst")
	var extras: Array[String] = []
	for i in range(1, run.last_hub_reward_packs.size()):
		extras.append(run.last_hub_reward_packs[i].type)
	assert_true(extras.has(Pack.TYPE_NUMBER))
	assert_true(extras.has(Pack.TYPE_MIXED))

func test_the_reward_list_holds_the_packs_that_really_went_into_stock() -> void:
	# Die Zeremonie darf nichts zeigen, was nicht im Lager liegt - sie bucht nicht.
	var run := _run_at(5)
	for pack in run.last_hub_reward_packs:
		assert_true(run.owned_packs.has(pack), "gezeigt wird nur, was gebucht ist")

func test_each_upgrade_replaces_the_reward_list() -> void:
	var run := GameRun.new_run()
	run.money = 100000
	run.upgrade_hub()
	run.upgrade_hub()
	assert_eq(run.last_hub_reward_packs.size(), 1, "die Liste erzählt nur vom JÜNGSTEN Ausbau")
	assert_eq(run.owned_packs.size(), 2, "im Lager liegen aber beide")

func test_an_unaffordable_upgrade_leaves_the_reward_list_alone() -> void:
	var run := GameRun.new_run()
	run.money = 100000
	run.upgrade_hub()
	run.money = 0
	run.upgrade_hub()  # scheitert
	assert_eq(run.last_hub_reward_packs.size(), 1, "ohne Aufstieg keine neue Merkliste")

func test_the_upgrade_reports_its_packs() -> void:
	var run := GameRun.new_run()
	run.money = 100000
	var emits := []
	run.packs_changed.connect(func() -> void: emits.append(1))
	run.upgrade_hub()
	assert_eq(emits.size(), 1, "das Lager meldet sich genau einmal")

func test_an_unaffordable_upgrade_grants_nothing() -> void:
	var run := GameRun.new_run()
	run.money = 0
	run.upgrade_hub()
	assert_eq(run.hub_level, 1, "kein Aufstieg")
	assert_eq(run.owned_packs.size(), 0, "und keine Belohnung")
