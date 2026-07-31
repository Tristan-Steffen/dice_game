extends GutTest
## Tests der Ladungs-Ökonomie (⚡) und des Schwarzmarkts in GameRun: Börsendeckel,
## Aufteilung in Börse und Überlauf, Freischalten, Auslage samt Ausschlüssen,
## Neuwurf-Preise und Kauf.

func _run() -> GameRun:
	return GameRun.new_run()

## Frischer Lauf mit freigeschaltetem Schwarzmarkt (erste Auslage liegt).
func _discovered() -> GameRun:
	var run := _run()
	run.charge = GameRun.SECRET_UNLOCK_PRICE
	run.unlock_secret_shop()
	return run

func _legendaries() -> Array[Charm]:
	var out: Array[Charm] = []
	for charm in Charm.all():
		if charm.rarity == Charm.RARITY_LEGENDARY:
			out.append(charm)
	return out

# --- Börse ---------------------------------------------------------------------

func test_fresh_run_starts_empty() -> void:
	var run := _run()
	assert_eq(run.charge, 0)
	assert_false(run.secret_shop_unlocked)
	assert_eq(run.secret_rerolls, 0)
	assert_eq(run.secret_stock.size(), 0)

func test_charge_cap_wakes_one_row_per_milestone() -> void:
	# Die Bank ist ein 5×5-Raster: der Deckel ist IMMER eine ganze Reihenzahl
	# (Vielfaches von CHARGE_ROW), eine Reihe je Meilenstein 1/3/5/7/10.
	var run := _run()
	assert_eq(run.charge_cap(), GameRun.CHARGE_ROW, "Hinterzimmer: eine Reihe")
	run.hub_level = 2
	assert_eq(run.charge_cap_rows(), 1)
	run.hub_level = 3
	assert_eq(run.charge_cap_rows(), 2)
	run.hub_level = 4
	assert_eq(run.charge_cap_rows(), 2)
	run.hub_level = 5
	assert_eq(run.charge_cap_rows(), 3)
	run.hub_level = 7
	assert_eq(run.charge_cap_rows(), 4)
	run.hub_level = 9
	assert_eq(run.charge_cap_rows(), 4)
	run.hub_level = GameRun.HUB_MAX_LEVEL
	assert_eq(run.charge_cap(), GameRun.CHARGE_ROW * GameRun.CHARGE_ROWS_MAX,
		"High Roller: das volle 5×5-Raster")

func test_add_charge_stores_to_cap_and_returns_overflow() -> void:
	var run := _run()  # Deckel 5 (eine Reihe)
	assert_eq(run.add_charge(3), 0)
	assert_eq(run.charge, 3)
	assert_eq(run.add_charge(5), 3, "2 passen noch, 3 laufen über")
	assert_eq(run.charge, 5)
	assert_eq(run.add_charge(3), 3, "volle Börse nimmt nichts mehr")
	assert_eq(run.charge, 5)

func test_add_charge_emits_new_value() -> void:
	var run := _run()
	var seen: Array[int] = []
	run.charge_changed.connect(func(value: int) -> void: seen.append(value))
	run.add_charge(3)
	run.add_charge(9)
	assert_eq(seen.size(), 2)
	assert_eq(seen[0], 3)
	assert_eq(seen[1], 5, "beim zweiten Mal bis zum Deckel")

func test_spend_charge_clamps_at_zero_and_emits() -> void:
	var run := _run()
	run.charge = 3
	var seen: Array[int] = []
	run.charge_changed.connect(func(value: int) -> void: seen.append(value))
	run.spend_charge(5)
	assert_eq(run.charge, 0)
	assert_eq(seen.size(), 1)
	assert_eq(seen[0], 0)

func test_charge_split_previews_without_mutating() -> void:
	var run := _run()  # Deckel 5
	run.charge = 3
	var split := run.charge_split(5)
	var stored: int = split["stored"]
	var overflow: int = split["overflow"]
	assert_eq(stored, 2)
	assert_eq(overflow, 3)
	assert_eq(run.charge, 3, "Vorschau ändert den Stand nicht")

func test_charge_split_on_empty_wallet_stores_everything() -> void:
	var run := _run()
	var split := run.charge_split(5)
	var stored: int = split["stored"]
	var overflow: int = split["overflow"]
	assert_eq(stored, 5)
	assert_eq(overflow, 0)

# --- Freischalten --------------------------------------------------------------

func test_unlock_price_is_one_full_row() -> void:
	assert_eq(GameRun.SECRET_UNLOCK_PRICE, 5)

func test_too_little_charge_keeps_the_market_barred() -> void:
	var run := _run()
	run.charge = GameRun.SECRET_UNLOCK_PRICE - 1
	var fired: Array = []
	run.secret_shop_discovered.connect(func() -> void: fired.append(true))
	assert_false(run.unlock_secret_shop())
	assert_false(run.secret_shop_unlocked)
	assert_eq(run.charge, GameRun.SECRET_UNLOCK_PRICE - 1, "kein Abzug")
	assert_eq(run.secret_stock.size(), 0)
	assert_eq(fired.size(), 0)

func test_unlocking_spends_the_entry_fee_exactly_once() -> void:
	var run := _run()
	run.hub_level = GameRun.HUB_MAX_LEVEL  # Deckel 25, damit der Rest liegen bleibt
	run.charge = GameRun.SECRET_UNLOCK_PRICE + 2
	var fired: Array = []
	run.secret_shop_discovered.connect(func() -> void: fired.append(true))
	assert_true(run.unlock_secret_shop())
	assert_true(run.secret_shop_unlocked)
	assert_eq(run.charge, 2, "genau das Eintrittsgeld ist weg")
	assert_eq(run.secret_stock.size(), 3, "erste Auslage gratis gewürfelt")
	assert_eq(fired.size(), 1)
	assert_false(run.unlock_secret_shop(), "ein zweites Mal gibt es nichts zu öffnen")
	assert_eq(run.charge, 2, "und kostet auch nichts")
	assert_eq(fired.size(), 1, "kein zweites Signal")

# --- Auslage -------------------------------------------------------------------

func test_stock_slots_are_charm_special_wildcard() -> void:
	var run := _discovered()
	assert_eq(run.secret_stock[0][GameRun.OFFER_KIND], GameRun.KIND_CHARM)
	assert_eq(run.secret_stock[1][GameRun.OFFER_KIND], GameRun.KIND_ENGRAVING)
	# Der dritte Platz ist die Wildcard: Charm, Sonderposten ODER Essenzwürfel.
	var wildcard: String = run.secret_stock[2][GameRun.OFFER_KIND]
	assert_true(wildcard == GameRun.KIND_CHARM or wildcard == GameRun.KIND_ENGRAVING
		or wildcard == GameRun.KIND_DIE, "unbekannte Wildcard-Ware: %s" % wildcard)

	var charm: Charm = run.secret_stock[0][GameRun.OFFER_ITEM]
	assert_eq(charm.rarity, Charm.RARITY_LEGENDARY)
	assert_eq(int(run.secret_stock[0][GameRun.OFFER_PRICE]), GameRun.SECRET_CHARM_PRICE)
	var engraving: Engraving = run.secret_stock[1][GameRun.OFFER_ITEM]
	assert_true(Engraving.is_special_id(engraving.id), "Sonderbestand statt Regalware")
	assert_eq(int(run.secret_stock[1][GameRun.OFFER_PRICE]), GameRun.SECRET_ENGRAVING_PRICE)
	assert_false(bool(run.secret_stock[0][GameRun.OFFER_SOLD]))

func test_stock_never_lists_a_charm_twice() -> void:
	for i in 10:
		var run := _discovered()
		var ids: Array[String] = []
		for offer in run.secret_stock:
			if offer[GameRun.OFFER_KIND] == GameRun.KIND_CHARM:
				var charm: Charm = offer[GameRun.OFFER_ITEM]
				assert_false(ids.has(charm.id), "kein Charm doppelt in der Auslage")
				ids.append(charm.id)

func test_stock_never_lists_a_special_twice() -> void:
	# Zwei gleiche Sonderposten zum selben Preis lesen sich als Fehler. Nur wenn
	# mehr Plätze als Sonderposten da sind, sind Wiederholungen erlaubt.
	var specials := 0
	for engraving in Engraving.all():
		if Engraving.is_special_id(engraving.id):
			specials += 1
	for i in 20:
		var run := _discovered()
		var ids: Array[String] = []
		for offer in run.secret_stock:
			if offer[GameRun.OFFER_KIND] != GameRun.KIND_ENGRAVING:
				continue
			var engraving: Engraving = offer[GameRun.OFFER_ITEM]
			if ids.size() < specials:
				assert_false(ids.has(engraving.id), "kein Sonderposten doppelt in der Auslage")
			ids.append(engraving.id)

func test_owned_legendaries_are_excluded_from_the_roll() -> void:
	var run := _run()
	var pool := _legendaries()
	var spared: Charm = pool.pop_back()
	for charm in pool:
		run.owned_charms.append(charm)
	run.charge = GameRun.SECRET_UNLOCK_PRICE
	run.unlock_secret_shop()
	var offered: Charm = run.secret_stock[0][GameRun.OFFER_ITEM]
	assert_eq(offered.id, spared.id, "nur der noch nicht besessene Legendäre bleibt übrig")
	assert_ne(run.secret_stock[2][GameRun.OFFER_KIND], GameRun.KIND_CHARM,
		"er liegt schon in der Auslage - die Wildcard weicht auf Sonderbestand oder Essenzwürfel aus")

func test_all_legendaries_owned_falls_back_to_specials() -> void:
	var run := _run()
	for charm in _legendaries():
		run.owned_charms.append(charm)
	run.charge = GameRun.SECRET_UNLOCK_PRICE
	run.unlock_secret_shop()
	assert_eq(run.secret_stock.size(), 3)
	for offer in run.secret_stock:
		# Ohne Charms bleiben Sonderposten und Essenzwürfel - tot wird die
		# Auslage nie.
		assert_ne(offer[GameRun.OFFER_KIND], GameRun.KIND_CHARM, "die Auslage kann nie tot sein")

# --- Neuwurf -------------------------------------------------------------------

func test_reroll_cost_escalates_and_never_resets() -> void:
	var run := _discovered()
	run.hub_level = GameRun.HUB_MAX_LEVEL
	run.charge = 25
	assert_eq(run.secret_reroll_cost(), 3)
	assert_true(run.reroll_secret_stock())
	assert_eq(run.charge, 22)
	assert_eq(run.secret_reroll_cost(), 5)
	assert_true(run.reroll_secret_stock())
	assert_eq(run.charge, 17)
	assert_eq(run.secret_reroll_cost(), 8)
	assert_true(run.reroll_secret_stock())
	assert_eq(run.charge, 9)
	assert_eq(run.secret_reroll_cost(), 13, "der Zähler läuft weiter")
	assert_eq(run.secret_rerolls, 3)

func test_reroll_cost_climbs_the_golden_ladder() -> void:
	var run := _discovered()
	var ladder: Array[int] = []
	for i in 5:
		run.secret_rerolls = i
		ladder.append(run.secret_reroll_cost())
	assert_eq(ladder, [3, 5, 8, 13, 21] as Array[int])

func test_reroll_replaces_the_whole_stock() -> void:
	var run := _discovered()
	run.charge = 3
	var before: Resource = run.secret_stock[0][GameRun.OFFER_ITEM]
	assert_true(run.reroll_secret_stock())
	assert_eq(run.secret_stock.size(), 3)
	var after: Resource = run.secret_stock[0][GameRun.OFFER_ITEM]
	assert_ne(after, before, "frisch gewürfelte Instanzen")

func test_reroll_without_charge_changes_nothing() -> void:
	var run := _discovered()
	run.charge = 2  # Neuwurf kostet 3
	var before: Resource = run.secret_stock[0][GameRun.OFFER_ITEM]
	assert_false(run.reroll_secret_stock())
	assert_eq(run.charge, 2)
	assert_eq(run.secret_rerolls, 0)
	var after: Resource = run.secret_stock[0][GameRun.OFFER_ITEM]
	assert_eq(after, before, "Auslage unverändert")

# --- Kauf ----------------------------------------------------------------------

func test_buying_a_charm_spends_charge_and_docks_it() -> void:
	var run := _discovered()
	run.charge = GameRun.SECRET_CHARM_PRICE
	var charm: Charm = run.secret_stock[0][GameRun.OFFER_ITEM]
	assert_true(run.buy_secret_offer(0))
	assert_eq(run.charge, 0)
	assert_true(run.owned_charm_ids().has(charm.id))
	assert_true(bool(run.secret_stock[0][GameRun.OFFER_SOLD]))

func test_buying_a_special_engraving_stocks_it() -> void:
	var run := _discovered()
	run.charge = GameRun.SECRET_ENGRAVING_PRICE
	var engraving: Engraving = run.secret_stock[1][GameRun.OFFER_ITEM]
	assert_true(run.buy_secret_offer(1))
	assert_eq(run.charge, 0)
	assert_eq(run.owned_engravings.size(), 1)
	assert_eq(run.owned_engravings[0].id, engraving.id)

func test_sold_slot_cannot_be_bought_twice() -> void:
	var run := _discovered()
	run.hub_level = GameRun.HUB_MAX_LEVEL
	run.charge = GameRun.SECRET_ENGRAVING_PRICE * 2  # reicht für zwei Gravur-Käufe
	assert_true(run.buy_secret_offer(1))
	var charge_after := run.charge
	var owned := run.owned_engravings.size()
	assert_false(run.buy_secret_offer(1), "der Platz ist leer")
	assert_eq(run.charge, charge_after, "kein zweiter Abzug")
	assert_eq(run.owned_engravings.size(), owned)

func test_buying_without_charge_is_rejected() -> void:
	var run := _discovered()
	run.charge = GameRun.SECRET_CHARM_PRICE - 1
	assert_false(run.buy_secret_offer(0))
	assert_eq(run.owned_charms.size(), 0)
	assert_false(bool(run.secret_stock[0][GameRun.OFFER_SOLD]))

func test_invalid_index_is_rejected() -> void:
	var run := _discovered()
	run.charge = GameRun.SECRET_CHARM_PRICE
	assert_false(run.buy_secret_offer(-1))
	assert_false(run.buy_secret_offer(run.secret_stock.size()))
	assert_eq(run.charge, GameRun.SECRET_CHARM_PRICE)

func test_buy_emits_stock_changed() -> void:
	var run := _discovered()
	run.charge = GameRun.SECRET_CHARM_PRICE
	var fired: Array = []
	run.secret_stock_changed.connect(func() -> void: fired.append(true))
	assert_true(run.buy_secret_offer(0))
	assert_eq(fired.size(), 1)

## Beide Kaufwege gehen durch _grant_charm - der Lumpensammler würfelt seine
## Glückszahl also auch auf dem Schwarzmarkt sofort.
func test_rag_collector_rolls_its_number_on_either_path() -> void:
	var shop := _run()
	shop.purchase_charm(Charm.rag_collector(), 0)
	assert_between(shop.lumpensammler_value, 1, 6)

	var market := _run()
	market.charge = 8
	market.secret_stock.append({
		GameRun.OFFER_KIND: GameRun.KIND_CHARM,
		GameRun.OFFER_ITEM: Charm.rag_collector(),
		GameRun.OFFER_PRICE: 8,
		GameRun.OFFER_SOLD: false,
	})
	assert_true(market.buy_secret_offer(0))
	assert_between(market.lumpensammler_value, 1, 6)

# --- Essenzwürfel: der einzige Weg an eine Schwarzmarkt-Seele --------------------

func test_the_wildcard_can_offer_an_essence_die() -> void:
	# Über viele Auslagen muss der Würfel-Platz vorkommen - er ist die einzige
	# Quelle der geheimen Essenzen.
	var run := _run()
	run.charge = GameRun.SECRET_UNLOCK_PRICE
	run.unlock_secret_shop()
	var seen_die := false
	for i in 200:
		run._roll_secret_stock()
		if run.secret_stock[2][GameRun.OFFER_KIND] == GameRun.KIND_DIE:
			seen_die = true
			var die: DieDefinition = run.secret_stock[2][GameRun.OFFER_ITEM]
			var essence := Essence.by_id(die.essence_id)
			assert_not_null(essence, "der Würfel trägt eine echte Seele")
			assert_true(essence.secret, "und zwar eine, die es nur hier gibt")
			assert_gt(int(run.secret_stock[2][GameRun.OFFER_PRICE]), 0, "und sie kostet ⚡")
	assert_true(seen_die, "der Wildcard-Platz zeigt auch Essenzwürfel")

func test_the_die_price_climbs_with_the_rarity() -> void:
	assert_lt(int(GameRun.SECRET_DIE_PRICES[Essence.Rarity.RARE]),
		int(GameRun.SECRET_DIE_PRICES[Essence.Rarity.EPIC]))
	assert_lt(int(GameRun.SECRET_DIE_PRICES[Essence.Rarity.EPIC]),
		int(GameRun.SECRET_DIE_PRICES[Essence.Rarity.LEGENDARY]))

func test_buying_an_essence_die_takes_a_soulless_pool_slot() -> void:
	var run := _run()
	run.charge = 40
	run.unlock_secret_shop()
	var die := DiceOffer.make_die(DiceOffer.TEMPLATES[0])
	die.essence_id = Essence.RADON
	run.secret_stock[2] = {
		GameRun.OFFER_KIND: GameRun.KIND_DIE, GameRun.OFFER_ITEM: die,
		GameRun.OFFER_PRICE: 6, GameRun.OFFER_SOLD: false,
	}
	for pool_die in run.owned_pool:
		pool_die.essence_id = Essence.NEON
	run.owned_pool[4].essence_id = ""
	var before := run.charge
	assert_true(run.buy_secret_offer(2))
	assert_eq(run.owned_pool[4].essence_id, Essence.RADON, "der seelenlose Platz nimmt die neue Seele auf")
	assert_eq(run.charge, before - 6, "der Preis ist abgebucht")
	assert_true(bool(run.secret_stock[2][GameRun.OFFER_SOLD]), "der Platz bleibt leer")

func test_an_owned_unique_never_returns_to_the_black_market() -> void:
	var run := _run()
	run.charge = GameRun.SECRET_UNLOCK_PRICE
	run.unlock_secret_shop()
	run.owned_pool[0].essence_id = Essence.ANTIMATTER
	for i in 200:
		run._roll_secret_stock()
		if run.secret_stock[2][GameRun.OFFER_KIND] != GameRun.KIND_DIE:
			continue
		var die: DieDefinition = run.secret_stock[2][GameRun.OFFER_ITEM]
		assert_ne(die.essence_id, Essence.ANTIMATTER, "Unikat schon im Besitz")
