extends GutTest
## Die PAKET-AUSWAHL: Wahl-Tabelle samt Glück, Optionen, Würfel-Pakete, das LAGER,
## Buchung beim Öffnen und beim Bestätigen, Neu mischen und die Charms und Klauseln.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 500

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

## Kauft ein Paket ins Lager und öffnet es gleich - der Weg jedes Auswahl-Tests.
func _buy_open(pack: Resource, price: int, rng: RandomNumberGenerator = null) -> PackChoice:
	var stored: Resource = null
	if pack is DicePack:
		stored = run.purchase_dice_pack(pack as DicePack, price, rng)
	else:
		stored = run.purchase_card_pack(pack as CardPack, price, rng)
	return run.open_stored_pack(int(stored.get("store_uid")), rng)

func _sign(ids: Array) -> void:
	var typed: Array[String] = []
	typed.assign(ids)
	run.sign_clauses(typed)

# --- Die Wahl-Tabelle ---------------------------------------------------------------

func test_base_picks_and_options_per_size() -> void:
	assert_eq(CardPack.OPTION_COUNTS, [3, 4, 5, 5])
	assert_eq(CardPack.BASE_PICKS, [1, 1, 2, 2])
	for pack_size in CardPack.SIZES:
		var picks := {}
		for seed_value in 200:
			var rolled := CardPack.roll_picks(pack_size, 0, 1.0, _rng(seed_value))
			picks[int(rolled["picks"])] = true
		var base := CardPack.base_picks(pack_size)
		assert_true(picks.has(base), "Größe %d: Grundzahl" % pack_size)
		assert_true(picks.has(base + 1), "Größe %d: Glückswurf" % pack_size)

func test_luck_raises_the_chances_up_to_the_caps() -> void:
	assert_almost_eq(CardPack.lucky_chance(CardPack.SIZE_SMALL, 0), 0.20, 0.0001)
	assert_almost_eq(CardPack.lucky_chance(CardPack.SIZE_SMALL, 10), 0.30, 0.0001)
	assert_almost_eq(CardPack.lucky_chance(CardPack.SIZE_NORMAL, 100), CardPack.LUCKY_CAP, 0.0001)
	assert_almost_eq(CardPack.jackpot_chance(CardPack.SIZE_HUGE, 0), 0.03, 0.0001)
	assert_almost_eq(CardPack.jackpot_chance(CardPack.SIZE_HUGE, 4), 0.04, 0.0001)
	assert_almost_eq(CardPack.jackpot_chance(CardPack.SIZE_HUGE, 100), CardPack.JACKPOT_CAP, 0.0001)
	assert_eq(CardPack.jackpot_chance(CardPack.SIZE_LARGE, 100), 0.0, "nur Riesig")
	assert_almost_eq(CardPack.lucky_chance(CardPack.SIZE_SMALL, 0, 2.0), 0.40, 0.0001,
		"Glücksgriff verdoppelt")

func test_jackpot_takes_every_option() -> void:
	var hit := false
	for seed_value in 400:
		var rolled := CardPack.roll_picks(CardPack.SIZE_HUGE, 100, 1.0, _rng(seed_value))
		if bool(rolled["jackpot"]):
			hit = true
			assert_eq(int(rolled["picks"]), 5)
	assert_true(hit, "bei 10 % fällt der Hauptgewinn in 400 Würfen")

func test_options_never_below_picks_or_two() -> void:
	assert_eq(CardPack.options_after(CardPack.SIZE_SMALL, -1, 1), 2)
	assert_eq(CardPack.options_after(CardPack.SIZE_NORMAL, -1, 3), 3)
	assert_eq(CardPack.options_after(CardPack.SIZE_HUGE, 2, 2), 7)

# --- Kauf und Optionen ----------------------------------------------------------------

func test_purchase_books_price_options_and_picks() -> void:
	var choice := _buy_open(CardPack.make(CardPack.SORT_MATERIAL,
		CardPack.SIZE_LARGE), 27, _rng(3))
	assert_eq(run.money, 473, "der Preis ist bezahlt")
	assert_eq(run.stored_card_packs.size(), 0, "geöffnet verläßt es das Lager")
	assert_not_null(choice)
	assert_eq(choice.option_count(), 5)
	assert_true(choice.picks >= 2)
	assert_same(run.current_pack_choice(), choice, "die Auswahl wartet")
	assert_eq(run.owned_packs.size(), 0, "gebucht wird erst beim Bestätigen")

func test_extra_options_from_charm_and_clauses() -> void:
	run.owned_charms.append(Charm.extra_option())
	var choice := _buy_open(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(1))
	assert_eq(choice.option_count(), 5, "Beigabe: eine Option mehr")
	run.pending_pack_choices.clear()
	_sign([DealClause.SUPPLEMENT])
	choice = _buy_open(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(1))
	assert_eq(choice.option_count(), 6, "Beigabe und Beipack")

func test_sealed_takes_one_option_away() -> void:
	_sign([DealClause.SEALED])
	var choice := _buy_open(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(1))
	assert_eq(choice.option_count(), 3, "Verplombt")
	assert_lte(choice.picks, choice.option_count())

func test_bonus_pick_adds_a_pick() -> void:
	_sign([DealClause.BONUS_PICK])
	var choice := _buy_open(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_SMALL), 0, _rng(1))
	assert_true(choice.picks >= 2, "Zugabe: eine Wahl mehr")

func test_free_hand_only_for_the_first_pack() -> void:
	_sign([DealClause.FREE_HAND])
	var first := _buy_open(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(1))
	assert_true(first.take_all)
	assert_eq(first.picks, first.option_count())
	run.confirm_pack_choice(first, [])
	var second := _buy_open(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(2))
	assert_false(second.take_all, "nur das erste geöffnete Paket der Runde")

# --- Bestätigen -------------------------------------------------------------------

func test_confirm_books_only_the_picks() -> void:
	var choice := _buy_open(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(5))
	var wanted: Object = choice.options[2]
	var result := run.confirm_pack_choice(choice, [2])
	assert_eq((result["cards"] as Array).size(), 1)
	assert_eq(run.owned_packs.size(), 1)
	assert_same(run.owned_packs[0], wanted, "genau die gewählte Karte")
	assert_null(run.current_pack_choice(), "Ungewähltes verfällt")

func test_confirm_with_nothing_forfeits_everything() -> void:
	var choice := _buy_open(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(5))
	run.confirm_pack_choice(choice, [])
	assert_eq(run.owned_packs.size(), 0)
	assert_null(run.current_pack_choice())

func test_confirm_refuses_too_many_picks() -> void:
	var choice := _buy_open(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_SMALL), 0, _rng(5))
	choice.picks = 1
	var result := run.confirm_pack_choice(choice, [0, 1])
	assert_eq((result["cards"] as Array).size(), 0)
	assert_same(run.current_pack_choice(), choice, "die Auswahl bleibt offen")

func test_dice_pack_books_into_pending_dice() -> void:
	var choice := _buy_open(DicePack.make(DicePack.SORT_POWER,
		CardPack.SIZE_LARGE), 36, _rng(4))
	assert_true(choice.is_dice())
	assert_gte(choice.option_count(), 4)
	assert_eq(choice.base_count, 4)
	assert_eq(choice.base_picks, 2)
	assert_eq(choice.qualities.size(), choice.option_count(), "je Würfel seine Güte")
	run.confirm_pack_choice(choice, [0, 1])
	assert_eq(run.pending_dice.size(), 2, "der ZWANG übernimmt")

# --- Würfel-Pakete --------------------------------------------------------------------

func test_dice_pack_contents_follow_the_sort() -> void:
	var owned: Array[String] = []
	var ids: Array[String] = []
	for i in 30:
		var power := DiceOffer.roll_pack_die(DicePack.SORT_POWER, 1, ids, owned, {}, 0)
		assert_true(["power", "pasch"].has(power.style_id))
		var series := DiceOffer.roll_pack_die(DicePack.SORT_SERIES, 1, ids, owned, {}, 0)
		assert_true(["even", "odd", "small", "low"].has(series.style_id))
		var soul := DiceOffer.roll_pack_die(DicePack.SORT_SOUL, 1, ids, owned, {}, 0)
		assert_ne(soul.essence_id, "", "Seelen-Paket: immer eine Seele")
		var material := DiceOffer.roll_pack_die(DicePack.SORT_MATERIAL, 1, ids, owned, {}, 0)
		assert_gte(material.materials.size() - material.materials.count(""), 2)

func test_soul_lift_never_common() -> void:
	for i in 60:
		assert_gt(DiceOffer._lifted_rarity(), int(Essence.Rarity.COMMON))

func test_soul_chance_from_luck() -> void:
	assert_almost_eq(DiceOffer.pack_soul_chance(0), 0.15, 0.0001)
	assert_almost_eq(DiceOffer.pack_soul_chance(5), 0.30, 0.0001)
	assert_almost_eq(DiceOffer.pack_soul_chance(100), 0.75, 0.0001)

func test_soul_rule_overrides_the_pack_chance() -> void:
	var owned: Array[String] = []
	var ids: Array[String] = []
	for i in 20:
		var none := DiceOffer.roll_pack_die(DicePack.SORT_MIXED, 1, ids, owned,
			{"chance": 0.0, "boost": 1.0}, 50)
		assert_eq(none.essence_id, "", "Seelenlos")

## Preise: erwartete Wahlen bei Glück 0 × Wert eines Würfels × Prämie × Güte-Faktor.
func test_dice_price_table_matches_the_formula() -> void:
	for pack_sort: String in DicePack.SORTS:
		for pack_size in CardPack.SIZES:
			var expected := DicePack.expected_picks(pack_size) * _die_value(pack_sort) \
				* CardPack.CHOICE_PREMIUM
			assert_almost_eq(float(DicePack.price_of(pack_sort, pack_size)), expected, 2.0,
				"%s / %d" % [pack_sort, pack_size])
			var table := float(DicePack.PRICES[pack_sort][pack_size])
			for pack_quality in DicePack.QUALITIES:
				assert_eq(DicePack.price_of(pack_sort, pack_size, pack_quality),
					roundi(table * float(DicePack.QUALITY_PRICE_FACTORS[pack_quality])))
	assert_eq(DicePack.make(DicePack.SORT_POWER, CardPack.SIZE_LARGE,
		DicePack.QUALITY_ROYAL).price, roundi(35 * 2.8))

func _die_value(pack_sort: String) -> float:
	var templates := DiceOffer.pack_templates(pack_sort)
	var base := 0.0
	for t in templates:
		base += float(t["price"])
	base /= float(templates.size())
	var weights := DiceOffer.ESSENCE_RARITY_WEIGHTS
	var total := 0.0
	var surcharge := 0.0
	for rarity in weights:
		total += float(weights[rarity])
		surcharge += float(weights[rarity]) * float(DiceOffer.ESSENCE_SURCHARGE[rarity])
	var soul := DiceOffer.PACK_SOUL_CHANCE * surcharge / total
	var material := DiceOffer.FACE_MATERIAL_CHANCE * (1.0 + DiceOffer.SECOND_FACE_CHANCE) \
		* DiceOffer.FACE_MATERIAL_SURCHARGE
	match pack_sort:
		DicePack.SORT_SOUL:
			# Eine Stufe gehoben: gewöhnlich wird selten, und so weiter.
			var lifted := 0.0
			var rarities := weights.keys()
			rarities.sort()
			for rarity in rarities:
				var up := mini(int(rarity) + 1, int(Essence.Rarity.LEGENDARY))
				lifted += float(weights[rarity]) * float(DiceOffer.ESSENCE_SURCHARGE[up])
			soul = lifted / total
		DicePack.SORT_MATERIAL:
			material = float(DicePack.MATERIAL_MIN_FACES) * DiceOffer.FACE_MATERIAL_SURCHARGE
	return base + soul + material

# --- Neu mischen ----------------------------------------------------------------------

func test_reshuffle_costs_energy_once_per_pack() -> void:
	run.energy = 3
	var choice := _buy_open(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(1))
	var before := choice.options.duplicate()
	var picks := choice.picks
	assert_true(run.reshuffle_pack_choice(choice, _rng(99)))
	assert_eq(run.energy, 2, "1 ⚡")
	assert_ne(choice.options, before, "neue Optionen")
	assert_eq(choice.picks, picks, "die Wahlen bleiben")
	assert_false(run.reshuffle_pack_choice(choice), "einmal je Paket")

func test_reshuffle_needs_energy() -> void:
	run.energy = 0
	var choice := _buy_open(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(1))
	assert_false(run.reshuffle_pack_choice(choice))

func test_reshuffle_charm_is_free_once_per_round() -> void:
	run.energy = 0
	run.owned_charms.append(Charm.reshuffle())
	var first := _buy_open(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(1))
	assert_eq(run.pack_reshuffle_cost(first), 0)
	assert_true(run.reshuffle_pack_choice(first))
	run.confirm_pack_choice(first, [])
	var second := _buy_open(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(2))
	assert_eq(run.pack_reshuffle_cost(second), GameRun.PACK_RESHUFFLE_ENERGY,
		"der Gratis-Neuwurf ist verbraucht")
	run.apply_round_start_charms()
	assert_eq(run.pack_reshuffle_cost(second), 0, "neue Runde, neuer Gratis-Neuwurf")

# --- Charms -----------------------------------------------------------------------------

func test_album_pays_per_opened_pack() -> void:
	run.owned_charms.append(Charm.album())
	_buy_open(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_SMALL), 9)
	assert_eq(run.money, 500 - 9 + GameRun.ALBUM_MONEY)

func test_lucky_mushroom_adds_luck() -> void:
	assert_eq(run.effective_luck(), 0)
	run.owned_charms.append(Charm.lucky_mushroom())
	assert_eq(run.effective_luck(), GameRun.LUCKY_MUSHROOM_LUCK)
	assert_eq(run.progress_tier(), 2, "die Fortschrittsstufe liest das wirkende Glück")

func test_fine_print_refunds_pack_prices() -> void:
	for i in 4:
		run.owned_charms.append(Charm.fine_print())
	var refunded := false
	for seed_value in 20:
		run.stored_card_packs.clear()
		run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_SMALL), 9,
			_rng(seed_value))
		if run.last_card_pack_refund == 9:
			refunded = true
	assert_true(refunded, "das Kleingedruckte erstattet den Paketpreis")

# --- Nebenwetten -------------------------------------------------------------------------

func test_side_bet_pays_one_dice_pack() -> void:
	var bet := SideBet.new()
	bet.stake = 12
	bet.odds = SideBet.ODDS_HARD
	bet.payout_kind = SideBet.Payout.DICE_PACK
	bet.reward_dice_pack_sort = DicePack.SORT_POWER
	var dice_pack := bet.reward_dice_pack()
	assert_not_null(dice_pack)
	assert_lte(dice_pack.price, bet.payout_value(), "der Preis passt in den Gewinnwert")
	assert_same(bet.reward_dice_pack(), dice_pack, "Knopf und Abrechnung meinen dasselbe")
	assert_eq(bet.reward_label(), "1 %s" % dice_pack.display_name)
	run._pay_side_bet(bet, 1.0)
	assert_null(bet.awarded_choice, "mit Platz geht es ins Lager")
	assert_true(bet.awarded_stored is DicePack)
	assert_true(run.stored_dice_packs.has(bet.awarded_stored))
	assert_true(bool(bet.awarded_stored.get("from_bet")))
	assert_null(run.current_pack_choice(), "geöffnet wird erst per Klick")
	var choice := run.open_stored_pack(int(bet.awarded_stored.get("store_uid")))
	assert_true(choice.is_dice())
	assert_true(choice.from_bet)

func test_side_bet_card_pack_opens_a_choice() -> void:
	var bet := SideBet.new()
	bet.stake = 12
	bet.odds = SideBet.ODDS_HARD
	bet.payout_kind = SideBet.Payout.CARD_PACK
	bet.reward_card_pack_sort = CardPack.SORT_MATERIAL
	run._pay_side_bet(bet, 1.0)
	assert_true(bet.awarded_stored is CardPack, "ins Lager")
	assert_eq(run.owned_packs.size(), 0, "die Karten kommen erst mit der Wahl")

func test_side_bet_pack_opens_at_once_when_the_store_is_full() -> void:
	for i in GameRun.STORE_CAPACITY:
		run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_SMALL), 0)
	var bet := SideBet.new()
	bet.stake = 12
	bet.odds = SideBet.ODDS_HARD
	bet.payout_kind = SideBet.Payout.CARD_PACK
	bet.reward_card_pack_sort = CardPack.SORT_MATERIAL
	run._pay_side_bet(bet, 1.0)
	assert_null(bet.awarded_stored, "das Lager ist voll")
	assert_not_null(bet.awarded_choice, "der Gewinn verfällt nicht - er öffnet sofort")
	assert_same(run.current_pack_choice(), bet.awarded_choice)
	assert_true(bet.awarded_choice.from_bet)
	assert_eq(run.stored_card_packs.size(), GameRun.STORE_CAPACITY)

# --- Das LAGER ----------------------------------------------------------------------------

func test_purchase_stores_and_rolls_nothing() -> void:
	var stored := run.purchase_dice_pack(DicePack.make(DicePack.SORT_POWER, CardPack.SIZE_LARGE,
		DicePack.QUALITY_FINE), 40)
	assert_eq(run.money, 460, "bezahlt")
	assert_not_null(stored)
	assert_eq(stored.quality, DicePack.QUALITY_FINE, "Größe und Güte stehen beim Kauf")
	assert_eq(stored.size, CardPack.SIZE_LARGE)
	assert_gt(stored.store_uid, 0)
	assert_null(run.current_pack_choice(), "Optionen und Wahlen fallen erst beim Öffnen")
	assert_eq(run.stored_dice_packs, [stored] as Array[DicePack])

func test_store_holds_eight_per_kind_and_refuses_unpaid() -> void:
	for i in GameRun.STORE_CAPACITY:
		assert_not_null(run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
			CardPack.SIZE_SMALL), 10))
	assert_true(run.store_full(GameRun.LANE_CARDS))
	assert_false(run.store_full(GameRun.LANE_DICE), "jede Art hat ihre eigene Reihe")
	assert_false(run.store_full(GameRun.LANE_MODULES))
	var money := run.money
	assert_null(run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_SMALL),
		10), "voll: kein Kauf")
	assert_eq(run.money, money, "und kein Geld gebucht")
	assert_not_null(run.purchase_dice_pack(DicePack.make(DicePack.SORT_MIXED,
		CardPack.SIZE_SMALL), 10))

func test_opening_takes_it_out_of_the_store_one_at_a_time() -> void:
	var a := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_SMALL), 0)
	var b := run.purchase_card_pack(CardPack.make(CardPack.SORT_RUNE, CardPack.SIZE_NORMAL), 0)
	var heard: Array = []
	run.store_changed.connect(func() -> void: heard.append(true))
	var choice := run.open_stored_pack(a.store_uid, _rng(1))
	assert_not_null(choice)
	assert_eq(heard.size(), 1)
	assert_eq(run.stored_card_packs, [b] as Array[CardPack], "b rückt nach")
	assert_null(run.open_stored_pack(b.store_uid), "eines nach dem anderen")
	run.confirm_pack_choice(choice, [])
	assert_not_null(run.open_stored_pack(b.store_uid))
	assert_null(run.open_stored_pack(9999), "unbekannte uid")

func test_opening_rolls_with_the_luck_of_then() -> void:
	var stored := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0)
	run.owned_charms.append(Charm.extra_option())
	var choice := run.open_stored_pack(stored.store_uid, _rng(1))
	assert_eq(choice.option_count(), 5, "die Beigabe nach dem Kauf wirkt beim Öffnen")

func test_the_shop_offer_is_not_the_stored_pack() -> void:
	var offer := CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_SMALL)
	var stored := run.purchase_card_pack(offer, 0)
	assert_ne(stored, offer, "das Lager bekommt eine Kopie")
	assert_eq(offer.store_uid, 0)

## Ab dem siebten Paket einer Art liegt die zweite LAGE auf den ersten sechs; jedes Paket
## behält seinen Platz, und das oberste eines Stapels wird zuerst gegriffen.
func test_the_seventh_pack_stacks_on_the_first_and_slots_stay() -> void:
	var packs: Array = []
	for i in GameRun.STORE_CAPACITY:
		packs.append(run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
			CardPack.SIZE_SMALL), 0))
	for i in packs.size():
		assert_eq(packs[i].store_slot, i, "Paket %d auf Platz %d" % [i + 1, i])
	assert_eq(packs.size(), 12, "zwölf je Art")
	assert_same(run.top_stored_pack(GameRun.LANE_CARDS, 0), packs[6], "oben liegt das siebte")
	assert_same(run.top_stored_pack(GameRun.LANE_CARDS, 5), packs[11])
	var choice := run.open_stored_pack(packs[7].store_uid)
	run.confirm_pack_choice(choice, [])
	assert_same(run.top_stored_pack(GameRun.LANE_CARDS, 1), packs[1],
		"darunter liegt wieder das zweite")
	for i in [0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11]:
		assert_eq(packs[i].store_slot, i, "nichts rückt um")
	var again := run.purchase_card_pack(CardPack.make(CardPack.SORT_RUNE, CardPack.SIZE_SMALL), 0)
	assert_eq(again.store_slot, 7, "der neue nimmt den frei gewordenen Platz")
	assert_null(run.stored_pack_at(GameRun.LANE_DICE, 0), "die Würfel-Reihe ist eigen")

func test_a_new_run_has_an_empty_store() -> void:
	run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_SMALL), 0)
	var fresh := GameRun.new_run()
	assert_eq(fresh.stored_card_packs.size(), 0)
	assert_eq(fresh.stored_dice_packs.size(), 0)

# --- Würfel-Pakete: Größe, Güte und die drei Ketten -------------------------------------

func test_dice_chain_chances_follow_luck_up_to_the_caps() -> void:
	assert_almost_eq(DicePack.extra_die_chance(0), 0.20, 0.0001)
	assert_almost_eq(DicePack.extra_die_chance(10), 0.35, 0.0001)
	assert_almost_eq(DicePack.extra_die_chance(100), DicePack.EXTRA_DIE_CAP, 0.0001)
	assert_almost_eq(DicePack.extra_die_chance(0, 2.0), 0.40, 0.0001, "Glücksgriff verdoppelt")
	assert_almost_eq(DicePack.extra_die_chance(20, 2.0), DicePack.EXTRA_DIE_CAP, 0.0001,
		"der Deckel bleibt")
	assert_almost_eq(DicePack.extra_pick_chance(0), 0.20, 0.0001)
	assert_almost_eq(DicePack.extra_pick_chance(10), 0.30, 0.0001)
	assert_almost_eq(DicePack.extra_pick_chance(100), DicePack.EXTRA_PICK_CAP, 0.0001)
	assert_almost_eq(DicePack.upgrade_chance(0), 0.10, 0.0001)
	assert_almost_eq(DicePack.upgrade_chance(10), 0.20, 0.0001)
	assert_almost_eq(DicePack.upgrade_chance(100), DicePack.UPGRADE_CAP, 0.0001)

func test_base_numbers_per_size() -> void:
	assert_eq(DicePack.BASE_COUNTS, [2, 3, 4, 5])
	assert_eq(DicePack.BASE_PICKS, [1, 1, 2, 2])

func test_dice_count_chain_stays_in_bounds() -> void:
	var extra := 0
	var deep := false
	for seed_value in 1000:
		var low := DicePack.roll_count(3, 0, 1.0, _rng(seed_value))
		assert_between(low, 3, 8)
		if low > 3:
			extra += 1
		var high := DicePack.roll_count(5, 100, 1.0, _rng(seed_value))
		assert_between(high, 5, 10)
		if high >= 7:
			deep = true
		assert_lte(DicePack.roll_count(8, 100, 1.0, _rng(seed_value)), DicePack.MAX_COUNT)
	assert_almost_eq(float(extra) / 1000.0, 0.20, 0.04, "20 % auf den ersten Zusatz")
	assert_true(deep, "die Kette reicht weiter als einen Würfel")

func test_quality_never_below_the_pack_and_climbs_with_luck() -> void:
	var climbed := 0
	var royal := false
	for seed_value in 1000:
		var plain := DicePack.roll_quality(DicePack.QUALITY_STANDARD, 0, _rng(seed_value))
		if plain > DicePack.QUALITY_STANDARD:
			climbed += 1
		var fine := DicePack.roll_quality(DicePack.QUALITY_FINE, 100, _rng(seed_value))
		assert_between(fine, DicePack.QUALITY_FINE, DicePack.QUALITY_ROYAL)
		if DicePack.roll_quality(DicePack.QUALITY_STANDARD, 100, _rng(seed_value)) \
				== DicePack.QUALITY_ROYAL:
			royal = true
		assert_eq(DicePack.roll_quality(DicePack.QUALITY_ROYAL, 100, _rng(seed_value)),
			DicePack.QUALITY_ROYAL, "nie über Royal")
	assert_almost_eq(float(climbed) / 1000.0, 0.10, 0.03)
	assert_true(royal, "zwei Aufstiege sind möglich")

func test_picks_always_between_one_and_count_minus_one() -> void:
	for count in range(2, 11):
		for base in [1, 2, 3, 9]:
			for seed_value in 40:
				var picks := DicePack.roll_picks(base, 100, count, 2.0, _rng(seed_value))
				assert_between(picks, 1, count - 1, "%d Würfel, Grundzahl %d" % [count, base])
	assert_eq(DicePack.roll_picks(1, 100, 2, 2.0, _rng(1)), 1, "zwei Würfel: genau eine Wahl")

func test_opened_dice_packs_keep_the_hard_pick_rule() -> void:
	run.luck = 30
	_sign([DealClause.BONUS_PICK, DealClause.LUCKY_GRAB])
	for pack_size in CardPack.SIZES:
		for seed_value in 25:
			var choice := _buy_open(DicePack.make(DicePack.SORT_MIXED, pack_size,
				DicePack.QUALITY_FINE), 0, _rng(seed_value))
			var count := choice.option_count()
			assert_between(count, DicePack.base_count(pack_size), DicePack.MAX_COUNT)
			assert_between(choice.picks, 1, count - 1)
			assert_lte(choice.base_picks, choice.picks)
			assert_false(choice.take_all, "kein Hauptgewinn bei Würfel-Paketen")
			for i in count:
				assert_gte(choice.quality_of(i), DicePack.QUALITY_FINE, "nie unter dem Paket")
			run.pending_pack_choices.clear()

func test_option_clauses_move_the_base_count() -> void:
	_sign([DealClause.SEALED])
	var sealed := _buy_open(DicePack.make(DicePack.SORT_MIXED,
		CardPack.SIZE_SMALL), 0, _rng(1))
	assert_eq(sealed.base_count, DicePack.MIN_COUNT, "Verplombt: nie unter 2")
	assert_eq(sealed.base_picks, 1)
	run.active_deals.clear()
	run.pending_pack_choices.clear()
	run.owned_charms.append(Charm.extra_option())
	var extra := _buy_open(DicePack.make(DicePack.SORT_MIXED,
		CardPack.SIZE_NORMAL), 0, _rng(1))
	assert_eq(extra.base_count, 4, "Beigabe: ein Würfel mehr")
	assert_gte(extra.option_count(), 4)

func test_lucky_grab_doubles_both_chains() -> void:
	assert_eq(run.pack_luck_factor(), 1.0)
	_sign([DealClause.LUCKY_GRAB])
	assert_eq(run.pack_luck_factor(), 2.0)
	var extra := 0
	for seed_value in 400:
		var choice := _buy_open(DicePack.make(DicePack.SORT_SERIES,
			CardPack.SIZE_NORMAL), 0, _rng(seed_value))
		if choice.option_count() > 3:
			extra += 1
		run.pending_pack_choices.clear()
	assert_almost_eq(float(extra) / 400.0, 0.40, 0.08, "Zugabe-Kette doppelt so oft")

func test_free_hand_gives_count_minus_one_and_bonus_pick_adds_one() -> void:
	_sign([DealClause.FREE_HAND])
	var free := _buy_open(DicePack.make(DicePack.SORT_MIXED,
		CardPack.SIZE_LARGE), 0, _rng(2))
	assert_eq(free.picks, free.option_count() - 1, "Freie Hand: das Maximum")
	assert_false(free.take_all)
	run.active_deals.clear()
	run.pending_pack_choices.clear()
	_sign([DealClause.BONUS_PICK])
	var bonus := _buy_open(DicePack.make(DicePack.SORT_MIXED,
		CardPack.SIZE_LARGE), 0, _rng(2))
	assert_eq(bonus.base_picks, 3, "Zugabe: +1 innerhalb des Deckels")
	assert_lte(bonus.picks, bonus.option_count() - 1)

func test_reshuffle_rerolls_count_dice_and_picks() -> void:
	run.energy = 100
	run.luck = 30
	var changed := false
	for seed_value in 30:
		var choice := _buy_open(DicePack.make(DicePack.SORT_MIXED,
			CardPack.SIZE_NORMAL), 0, _rng(seed_value))
		var before: Array = choice.options.duplicate()
		var signature := [choice.option_count(), choice.picks, choice.qualities.duplicate()]
		assert_true(run.reshuffle_pack_choice(choice, _rng(seed_value + 1000)))
		assert_true(choice.rerolled)
		assert_ne(choice.options, before, "neue Würfel")
		assert_eq(choice.qualities.size(), choice.option_count())
		assert_between(choice.picks, 1, choice.option_count() - 1)
		if [choice.option_count(), choice.picks, choice.qualities] != signature:
			changed = true
		run.pending_pack_choices.clear()
	assert_true(changed, "Zahl, Wahlen oder Güten fallen neu")

func test_quality_raises_faces_souls_and_materials() -> void:
	var ids: Array[String] = []
	var sums := [0, 0]
	var souls := [0, 0]
	var materials := [0, 0]
	for i in 300:
		var owned: Array[String] = []
		var plain := DiceOffer.roll_pack_die(DicePack.SORT_MIXED, 1, ids, owned, {}, 0,
			DicePack.QUALITY_STANDARD)
		var fine := DiceOffer.roll_pack_die(DicePack.SORT_MIXED, 1, ids, owned, {}, 0,
			DicePack.QUALITY_FINE)
		var royal := DiceOffer.roll_pack_die(DicePack.SORT_MIXED, 1, ids, owned, {}, 0,
			DicePack.QUALITY_ROYAL)
		for f in 6:
			sums[0] += plain.faces[f]
			sums[1] += royal.faces[f]
		souls[0] += 1 if plain.essence_id != "" else 0
		souls[1] += 1 if fine.essence_id != "" else 0
		materials[0] += 1 if plain.materials.count("") < 6 else 0
		materials[1] += 1 if fine.materials.count("") < 6 else 0
		assert_true(DiceOffer.has_doped_side(royal), "Royal: eine veredelte Seite")
		assert_lt(royal.runes.count(Rune.NONE), 6, "Royal: eine Rune sicher")
	assert_gt(sums[1], sums[0] * 2, "Royal: zwei Stufen höhere Augen")
	assert_gt(souls[1], souls[0] + 30, "Edel: +20 Punkte Seele")
	assert_gt(materials[1], materials[0] + 30, "Edel: öfter Material")

func test_soulless_stays_soulless_whatever_the_quality() -> void:
	var ids: Array[String] = []
	var owned: Array[String] = []
	for i in 30:
		var royal := DiceOffer.roll_pack_die(DicePack.SORT_MIXED, 1, ids, owned,
			{"chance": 0.0, "boost": 1.0}, 50, DicePack.QUALITY_ROYAL)
		assert_eq(royal.essence_id, "")
		var soul := DiceOffer.roll_pack_die(DicePack.SORT_SOUL, 1, ids, owned, {}, 0,
			DicePack.QUALITY_ROYAL)
		assert_gte(int(Essence.by_id(soul.essence_id).rarity), int(Essence.Rarity.EPIC),
			"Seelen-Paket und Royal heben zweimal")

func test_shop_quality_weights_shift_with_the_tier() -> void:
	assert_eq(DicePack.shop_quality_weights(1), [65, 27, 8])
	assert_eq(DicePack.shop_quality_weights(3), [55, 33, 12])
	assert_eq(DicePack.shop_quality_weights(10), [20, 54, 26])
	assert_eq(run.shop_dice_pack_quality_weights(), [65, 27, 8])
	var seen := {}
	for seed_value in 300:
		seen[DicePack.roll_shop(_rng(seed_value)).quality] = true
	assert_eq(seen.size(), 3, "alle drei Güten liegen aus")

func test_shop_text_names_floors_and_quality_but_no_odds() -> void:
	var dice_pack := DicePack.make(DicePack.SORT_POWER, CardPack.SIZE_LARGE,
		DicePack.QUALITY_FINE)
	assert_eq(dice_pack.display_name, "Großes Kraft-Paket · Edel")
	assert_eq(DicePack.make(DicePack.SORT_POWER, CardPack.SIZE_NORMAL).display_name,
		"Kraft-Paket")
	var text := DicePack.info_body(dice_pack)
	assert_string_contains(text, "Mindestens 4 Würfel")
	assert_string_contains(text, "Mindestens 2 Wahlen")
	assert_string_contains(text, "Edel")
	assert_false(text.contains("%"), "keine Chancen")
	assert_string_contains(DicePack.info_body(DicePack.make(DicePack.SORT_MIXED,
		CardPack.SIZE_SMALL)), "Mindestens 1 Wahl ")

func test_side_bet_takes_the_dearest_affordable_pair() -> void:
	assert_eq(SideBet.reward_dice_pair(DicePack.SORT_POWER, 60),
		Vector2i(CardPack.SIZE_HUGE, DicePack.QUALITY_FINE), "gleicher Preis: die größere Größe")
	assert_eq(SideBet.reward_dice_pair(DicePack.SORT_POWER, 50),
		Vector2i(CardPack.SIZE_SMALL, DicePack.QUALITY_ROYAL))
	assert_eq(SideBet.reward_dice_pair(DicePack.SORT_POWER, 5),
		Vector2i(CardPack.SIZE_SMALL, DicePack.QUALITY_STANDARD))
	var bet := SideBet.new()
	bet.stake = 30
	bet.odds = SideBet.ODDS_HARD
	bet.payout_kind = SideBet.Payout.DICE_PACK
	bet.reward_dice_pack_sort = DicePack.SORT_SERIES
	var dice_pack := bet.reward_dice_pack()
	assert_lte(dice_pack.price, bet.payout_value())
	assert_same(bet.reward_dice_pack(), dice_pack)
