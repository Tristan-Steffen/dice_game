extends GutTest
## Die Verstärker-Klauseln (Spec: Obsidian-Seite 42): jede Wirkung ist EINE
## GameRun-Abfrage, und jede Zahl liest der Winkeladvokat doppelt.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

func _sign(ids: Array) -> void:
	var typed: Array[String] = []
	typed.assign(ids)
	run.sign_clauses(typed)

func _shyster() -> void:
	run.owned_charms.append(Charm.shyster())

func _bet(id: String) -> SideBet:
	for t in SideBet.TEMPLATES:
		if t["id"] == id:
			return SideBet._from_template(t)
	return null

const NEW_IDS := [DealClause.LUCKY_DAY, DealClause.BULK_ORDER, DealClause.CONNOISSEUR_EYE,
	DealClause.SOUL_MARKET, DealClause.FREE_FLIP, DealClause.BUYBACK, DealClause.MATH_WEEK,
	DealClause.REGULAR_CUSTOMER, DealClause.SPECIAL_DELIVERY, DealClause.BACK_ROOM_CONTACT,
	DealClause.LOADED_REELS, DealClause.REINSURANCE, DealClause.HIGH_TABLE,
	DealClause.COLD_PRESS, DealClause.BIG_STORAGE, DealClause.EMPTY_SHELVES,
	DealClause.SHELF_WARMER, DealClause.SOULLESS, DealClause.FLIP_SURCHARGE]

func test_every_new_clause_is_in_the_catalogue():
	for clause_id in NEW_IDS:
		assert_true(DealClause.is_valid_id(clause_id), "%s im Katalog" % clause_id)
		assert_false(DealClause.tags_of(clause_id).is_empty(), "%s trägt ein Tag" % clause_id)

## Jede neue Bonus-Klausel mit Zahl hat ihre ausgeschriebene Winkeladvokat-Fassung.
func test_shyster_texts_are_written_out():
	var expected := {
		DealClause.LUCKY_DAY: "Laden würfelt mit Glück +6.",
		DealClause.CONNOISSEUR_EYE: "Seltene und legendäre Charms viermal so oft.",
		DealClause.MATH_WEEK: "Multiplikator-Karten sechsmal so oft.",
		DealClause.REGULAR_CUSTOMER: "Ladenpreise −28 % bis zur Boss-Runde.",
		DealClause.BACK_ROOM_CONTACT: "Schwarzmarkt: −2 ⚡ je Ware, Neuwurf gratis.",
		DealClause.HIGH_TABLE: "Nebenwetten: Einsatz ×1,5, Gewinn ×3.",
		DealClause.BIG_STORAGE: "Börse dauerhaft +10 ⚡ Platz.",
	}
	for clause_id: String in expected:
		assert_eq(DealClause.text_for(clause_id, 2), expected[clause_id])
		assert_ne(DealClause.text_for(clause_id, 1), expected[clause_id])

# --- Laden ----------------------------------------------------------------------

func test_lucky_day_lifts_only_the_shop_tier():
	run.luck = 0
	_sign([DealClause.LUCKY_DAY])
	assert_eq(run.progress_tier(), 1, "die echte Stufe bleibt")
	assert_eq(run.shop_tier(), 2, "der Laden würfelt mit Glück +3")
	_shyster()
	assert_eq(run.shop_tier(), 3, "der Winkeladvokat legt +6 drauf")

func test_lucky_day_feeds_the_shop_ladders():
	run.luck = 6 * GameRun.LUCK_PER_TIER  # Stufe 7
	var before := run.shop_multiplier_chance()
	assert_eq(run.shop_special_chance(), 0.0)
	_sign([DealClause.LUCKY_DAY])
	assert_eq(run.shop_tier(), 8)
	assert_gt(run.shop_multiplier_chance(), before)
	assert_gt(run.shop_special_chance(), 0.0, "Sonderposten ab Stufe 8")

func test_bulk_order_shifts_the_size_weights():
	assert_eq(run.shop_tier_weights(), Pack.TIER_WEIGHTS)
	_sign([DealClause.BULK_ORDER])
	assert_eq(run.shop_tier_weights(), GameRun.BULK_ORDER_TIER_WEIGHTS)

func test_connoisseur_eye_doubles_rare_and_legendary():
	assert_true(run.shop_charm_rarity_factors().is_empty())
	_sign([DealClause.CONNOISSEUR_EYE])
	var factors := run.shop_charm_rarity_factors()
	assert_eq(float(factors[Charm.RARITY_RARE]), 2.0)
	assert_eq(float(factors[Charm.RARITY_LEGENDARY]), 2.0)
	assert_false(factors.has(Charm.RARITY_COMMON))
	_shyster()
	assert_eq(float(run.shop_charm_rarity_factors()[Charm.RARITY_RARE]), 4.0)

func test_soul_market_always_sells_a_soul():
	_sign([DealClause.SOUL_MARKET])
	var rule := run.shop_soul_rule()
	assert_eq(float(rule["chance"]), 1.0)
	for offer in DiceOffer.roll_offers(6, [], [], 1, rule):
		assert_ne(offer.dice[0].essence_id, "", "jeder Laden-Würfel trägt eine Seele")

func test_soulless_sells_no_soul():
	_sign([DealClause.SOULLESS])
	for offer in DiceOffer.roll_offers(6, [], [], 1, run.shop_soul_rule()):
		assert_eq(offer.dice[0].essence_id, "", "kein Laden-Würfel trägt eine Seele")

func test_flip_fee_clauses():
	assert_eq(run.shop_flip_fee_factor(), 1.0)
	_sign([DealClause.FLIP_SURCHARGE])
	assert_eq(run.shop_flip_fee_factor(), 2.0, "Blätter-Aufschlag")
	_sign([DealClause.FREE_FLIP])
	assert_eq(run.shop_flip_fee_factor(), 0.0, "Freies Blättern schlägt alles")

func test_buyback_sells_at_full_price():
	run.owned_charms.append(Charm.odds_sheet())
	var half := run.charm_sell_value(0)
	_sign([DealClause.BUYBACK])
	assert_eq(run.charm_sell_value(0), run.owned_charms[0].price)
	assert_gt(run.charm_sell_value(0), half)

func test_math_week_triples_the_multiplier_chance():
	var base := run.shop_multiplier_chance()
	_sign([DealClause.MATH_WEEK])
	assert_almost_eq(run.shop_multiplier_chance(), base * 3.0, 0.0001)
	run.luck = 9 * GameRun.LUCK_PER_TIER
	assert_eq(run.shop_multiplier_chance(), GameRun.MULTIPLIER_CHANCE_CAP, "der Deckel bleibt")

## Der Stammkunde ist BLOCK: er überlebt seine Runde und stirbt mit der Abrechnung.
func test_regular_customer_lasts_until_the_settlement():
	run.round_number = 1
	_sign([DealClause.REGULAR_CUSTOMER])
	assert_almost_eq(run.shop_price_factor(), 0.85, 0.0001)
	run.round_number = 4
	assert_almost_eq(run.shop_price_factor(), 0.85, 0.0001, "drei Runden später noch")
	run.settle_block_deals()
	assert_almost_eq(run.shop_price_factor(), 1.0, 0.0001)

func test_regular_customer_is_applied_twice_under_the_shyster():
	_shyster()
	_sign([DealClause.REGULAR_CUSTOMER])
	assert_almost_eq(run.shop_price_factor(), 0.85 * 0.85, 0.0001)

func test_special_delivery_guarantees_a_special_from_round_one():
	assert_eq(run.shop_special_chance(), 0.0)
	_sign([DealClause.SPECIAL_DELIVERY])
	assert_eq(run.shop_special_chance(), 1.0)

func test_empty_shelves_leave_one_seat_each_empty():
	assert_eq(run.shop_dice_offered(), run.shop_dice_slots())
	_sign([DealClause.EMPTY_SHELVES])
	assert_eq(run.shop_dice_offered(), run.shop_dice_slots() - 1)
	assert_eq(run.shop_packs_offered(), run.shop_pack_slots() - 1)
	assert_eq(run.shop_pack_slots(), GameRun.SHOP_PACK_SLOTS, "die Plätze bleiben stehen")

func test_shelf_warmer_flags_common_charms():
	assert_false(run.shop_common_charms_only())
	_sign([DealClause.SHELF_WARMER])
	assert_true(run.shop_common_charms_only())

# --- Schwarzmarkt & Automaten ---------------------------------------------------

func test_back_room_contact_cuts_prices_and_rerolls():
	var offer := {GameRun.OFFER_KIND: GameRun.KIND_CHARM, GameRun.OFFER_PRICE: 3}
	assert_eq(run.secret_offer_price(offer), 3)
	_sign([DealClause.BACK_ROOM_CONTACT])
	assert_eq(run.secret_offer_price(offer), 2)
	assert_eq(run.secret_reroll_cost(), 0)
	var cheap := {GameRun.OFFER_KIND: GameRun.KIND_CHARM, GameRun.OFFER_PRICE: 1}
	assert_eq(run.secret_offer_price(cheap), 1, "nie unter 1")

func test_loaded_reels_roll_no_fumble():
	_sign([DealClause.LOADED_REELS])
	assert_true(run.slots_fumble_free())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 30:
		run.slot_bank.reset_session()
		for col in run.slot_bank.roll(0, rng, 0, run.slots_fumble_free()):
			assert_false((col as Array).has(SlotPrize.Kind.FUMBLE))

# --- Nebenwetten ----------------------------------------------------------------

func _lose() -> void:
	run.resolve_side_bets({"cleared": false})

func test_reinsurance_returns_a_lost_money_stake():
	_sign([DealClause.REINSURANCE])
	run.money = 20
	run.place_side_bet(_bet("two_pair"))
	assert_eq(run.money, 16)
	_lose()
	assert_eq(run.money, 20, "der Einsatz kommt zurück")

func test_reinsurance_returns_the_very_same_cards():
	_sign([DealClause.REINSURANCE])
	run.grant_pack(Pack.number_pack())
	var pack := run.owned_packs[0]
	run.place_side_bet(_bet("pawn"))
	assert_eq(run.owned_packs.size(), 0)
	_lose()
	assert_eq(run.owned_packs.size(), 1)
	assert_same(run.owned_packs[0], pack, "dieselbe Karte, kein Ersatz")

func test_reinsurance_returns_energy_and_paid_tax():
	_sign([DealClause.REINSURANCE])
	run.energy = 4
	run.place_side_bet(_bet("feedback_loop"))
	run.money = 10
	run.place_side_bet(_bet("table_fee"))
	run.tax_side_bets(2)
	assert_eq(run.money, 7)
	_lose()
	assert_eq(run.energy, 4, "die Energie kommt zurück")
	assert_eq(run.money, 10, "und die gezahlte Steuer")

func test_without_reinsurance_a_lost_stake_is_gone():
	run.money = 20
	run.place_side_bet(_bet("two_pair"))
	_lose()
	assert_eq(run.money, 16)

func test_high_table_lifts_stake_and_prize():
	var bet := _bet("two_pair")
	bet.payout_kind = SideBet.Payout.MONEY
	_sign([DealClause.HIGH_TABLE])
	assert_eq(run.side_bet_stake(bet), 6, "$4 × 1,5")
	assert_eq(run.side_bet_payout_factor(), 1.5)
	assert_eq(bet.reward_money(run.side_bet_payout_factor()), 12)
	_shyster()
	assert_eq(run.side_bet_payout_factor(), 3.0, "der Advokat verdoppelt den Gewinn")
	assert_eq(run.side_bet_stake(bet), 6, "den Einsatz nicht")

# --- Werkstatt & Energie --------------------------------------------------------

func _stamp(die: DieDefinition) -> void:
	run.grant_pack(Pack.number_pack())
	var uids: Array[int] = [run.owned_packs[0].pack_uid]
	run.apply_series(uids, die)

func test_cold_press_does_not_heat():
	var die := run.owned_pool[0]
	_stamp(die)
	assert_eq(die.charge, 1, "ohne Klausel heizt das Prägen")
	var cold := run.owned_pool[1]
	_sign([DealClause.COLD_PRESS])
	_stamp(cold)
	assert_eq(cold.charge, 0, "Kaltpressung")

func test_big_storage_widens_the_bank_for_good():
	assert_eq(run.energy_cap(), GameRun.ENERGY_ROW)
	_sign([DealClause.BIG_STORAGE])
	assert_eq(run.energy_cap(), GameRun.ENERGY_ROW * 2)
	run.advance_round()
	assert_eq(run.energy_cap(), GameRun.ENERGY_ROW * 2, "dauerhaft")
	_shyster()
	_sign([DealClause.BIG_STORAGE])
	assert_eq(run.energy_cap(), GameRun.ENERGY_ROW * 4, "+10 unter dem Advokaten")
	assert_eq(GameRun.new_run().energy_cap(), GameRun.ENERGY_ROW, "ein neuer Lauf beginnt leer")
