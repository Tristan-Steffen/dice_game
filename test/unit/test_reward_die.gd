extends GutTest
## Der Prämien-Würfel (Stresstest): direkt gewürfelt, garantiert beseelt und gratis
## ins Ausgabefach gelegt (pending_dice) - Würfel sind keine Paketware.

func test_a_fresh_run_gets_nothing() -> void:
	var run := GameRun.new_run()
	assert_eq(run.owned_packs.size(), 0, "der Start ist keine Belohnung")
	assert_eq(run.pending_dice.size(), 0)

func test_the_reward_die_always_carries_a_soul() -> void:
	for _i in 30:
		var run := GameRun.new_run()
		var die := run.grant_stress_reward()
		assert_eq(run.pending_dice.size(), 1)
		assert_eq(run.pending_dice[0], die, "geliefert wird das hinterlegte Exemplar")
		assert_ne(die.essence_id, "", "der Prämien-Würfel ist beseelt")

func test_the_reward_die_costs_nothing() -> void:
	var run := GameRun.new_run()
	run.money = 50
	run.grant_stress_reward()
	assert_eq(run.money, 50, "eine Prämie kostet nichts")

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
