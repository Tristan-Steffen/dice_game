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

const NEW_IDS := [DealClause.LUCKY_DAY, DealClause.CONNOISSEUR_EYE,
	DealClause.SOUL_MARKET, DealClause.FREE_FLIP, DealClause.BUYBACK, DealClause.MATH_WEEK,
	DealClause.REGULAR_CUSTOMER, DealClause.SPECIAL_DELIVERY, DealClause.BACK_ROOM_CONTACT,
	DealClause.REINSURANCE, DealClause.BIG_STORAGE, DealClause.EMPTY_SHELVES,
	DealClause.SHELF_WARMER, DealClause.SOULLESS, DealClause.FLIP_SURCHARGE]

func test_every_new_clause_is_in_the_catalogue():
	for clause_id in NEW_IDS:
		assert_true(DealClause.is_valid_id(clause_id), "%s im Katalog" % clause_id)
		assert_false(DealClause.tags_of(clause_id).is_empty(), "%s trägt ein Tag" % clause_id)

## Jede neue Bonus-Klausel mit Zahl hat ihre ausgeschriebene Winkeladvokat-Fassung.
func test_shyster_texts_are_written_out():
	var expected := {
		DealClause.LUCKY_DAY: "Glück +6 diese Runde.",
		DealClause.CONNOISSEUR_EYE: "Laden führt sicher zwei legendäre Charms.",
		DealClause.MATH_WEEK: "Glück +12 diese Runde.",
		DealClause.SPECIAL_DELIVERY: "Glück +20 diese Runde.",
		DealClause.FREE_FLIP: "Blättern im Laden 6× gratis.",
		DealClause.REGULAR_CUSTOMER: "Ladenpreise −28 % bis zur Boss-Runde.",
		DealClause.BACK_ROOM_CONTACT: "Schwarzmarkt: −2 ⚡ je Ware.",
		DealClause.BIG_STORAGE: "Zwei Powerbanks: Börse +10 ⚡ Platz.",
	}
	for clause_id: String in expected:
		assert_eq(DealClause.text_for(clause_id, 2), expected[clause_id])
		assert_ne(DealClause.text_for(clause_id, 1), expected[clause_id])

# --- Laden ----------------------------------------------------------------------

## Glück auf Zeit: mit der Unterschrift dazu, beim nächsten Rundenstart wieder fort.
func test_temporary_luck_is_lent_for_one_round():
	for pair in [[DealClause.LUCKY_DAY, 3], [DealClause.MATH_WEEK, 6], [DealClause.SPECIAL_DELIVERY, 10]]:
		run = GameRun.new_run()
		run.luck = 2
		_sign([pair[0]])
		assert_eq(run.luck, 2 + int(pair[1]), "%s leiht Glück" % pair[0])
		assert_eq(run.progress_tier(), 1 + (2 + int(pair[1])) / GameRun.LUCK_PER_TIER,
			"es wirkt wie echtes Glück")
		run.advance_round()
		assert_eq(run.luck, 3, "zurückgegeben, nur die +1 der geschafften Runde bleibt")

func test_temporary_luck_doubles_under_the_shyster():
	_shyster()
	run.luck = 0
	_sign([DealClause.SPECIAL_DELIVERY])
	assert_eq(run.luck, 20)
	run.advance_round()
	assert_eq(run.luck, 1)

func test_connoisseur_eye_guarantees_legendaries():
	assert_eq(run.shop_guaranteed_legendaries(), 0)
	_sign([DealClause.CONNOISSEUR_EYE])
	assert_eq(run.shop_guaranteed_legendaries(), 1)
	assert_eq(DealClause.find(DealClause.CONNOISSEUR_EYE).tier, DealClause.Tier.THREE)
	_shyster()
	assert_eq(run.shop_guaranteed_legendaries(), 2)

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
	for i in GameRun.FREE_FLIPS:
		run.note_shop_flip()
	assert_eq(run.free_flips_left(), 0)
	assert_eq(run.shop_flip_fee_factor(), 2.0, "nach drei Gratis-Seiten kostet es wieder")

func test_buyback_sells_at_full_price():
	run.owned_charms.append(Charm.odds_sheet())
	var half := run.charm_sell_value(0)
	_sign([DealClause.BUYBACK])
	assert_eq(run.charm_sell_value(0), run.owned_charms[0].price)
	assert_gt(run.charm_sell_value(0), half)

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

func test_empty_shelves_leave_two_places_empty():
	assert_eq(run.shop_packs_offered(), GameRun.SHOP_PACK_PLACES)
	_sign([DealClause.EMPTY_SHELVES])
	assert_eq(run.shop_packs_offered(), GameRun.SHOP_PACK_PLACES - GameRun.EMPTY_SHELVES_CUT)
	assert_eq(run.shop_pack_places(), GameRun.SHOP_PACK_PLACES, "die Plätze bleiben stehen")

func test_shelf_warmer_flags_common_charms():
	assert_false(run.shop_common_charms_only())
	_sign([DealClause.SHELF_WARMER])
	assert_true(run.shop_common_charms_only())

# --- Schwarzmarkt & Automaten ---------------------------------------------------

func test_back_room_contact_cuts_prices():
	var offer := {GameRun.OFFER_KIND: GameRun.KIND_CHARM, GameRun.OFFER_PRICE: 3}
	assert_eq(run.secret_offer_price(offer), 3)
	_sign([DealClause.BACK_ROOM_CONTACT])
	assert_eq(run.secret_offer_price(offer), 2)
	assert_eq(run.secret_reroll_cost(), GameRun.SECRET_REROLL_BASE, "der Neuwurf kostet weiter")
	var cheap := {GameRun.OFFER_KIND: GameRun.KIND_CHARM, GameRun.OFFER_PRICE: 1}
	assert_eq(run.secret_offer_price(cheap), 1, "nie unter 1")


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

## Wettsteuer: jede laufende Wette zahlt ihren Einsatz noch einmal - was nicht
## reicht, entfällt, und die Wette läuft trotzdem weiter.
func test_betting_tax_charges_every_stake_again():
	run.money = 20
	run.place_side_bet(_bet("two_pair"))
	assert_eq(run.money, 16)
	_sign([DealClause.BETTING_TAX])
	assert_eq(run.money, 12, "noch einmal $4")
	assert_eq(run.active_side_bets[0].paid_money, 8)
	assert_false(run.active_side_bets[0].voided)

func test_betting_tax_takes_only_what_is_there():
	run.money = 4
	run.place_side_bet(_bet("two_pair"))
	assert_eq(run.money, 0)
	_sign([DealClause.BETTING_TAX])
	assert_eq(run.money, 0, "leere Kasse zahlt nichts")
	assert_false(run.active_side_bets[0].voided, "die Wette läuft weiter")

func test_betting_tax_takes_energy_stakes_too():
	run.energy = 5
	run.place_side_bet(_bet("feedback_loop"))
	var after_bet := run.energy
	_sign([DealClause.BETTING_TAX])
	assert_lt(run.energy, after_bet)

# --- Werkstatt & Energie --------------------------------------------------------

func _stamp(die: DieDefinition) -> void:
	run.grant_pack(Pack.number_pack())
	var uids: Array[int] = [run.owned_packs[0].pack_uid]
	run.apply_series(uids, die)

func test_big_storage_is_not_offered_at_a_full_bank():
	run.storage_rows = run.max_storage_rows()
	for i in 40:
		run.settle_block_deals()
		for room_id: String in run.floor_map.rooms:
			assert_ne(String(run.floor_map.rooms[room_id]["bonus"]), DealClause.BIG_STORAGE)

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
