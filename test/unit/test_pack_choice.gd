extends GutTest
## Die PAKET-AUSWAHL: Wahl-Tabelle samt Glück, Optionen, Würfel-Pakete, Buchung beim
## Kauf und beim Bestätigen, Neu mischen und die neuen Charms und Klauseln.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 500

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

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
	var choice := run.purchase_card_pack(CardPack.make(CardPack.SORT_MATERIAL,
		CardPack.SIZE_LARGE), 27, _rng(3))
	assert_eq(run.money, 473, "der Preis ist bezahlt")
	assert_not_null(choice)
	assert_eq(choice.option_count(), 5)
	assert_true(choice.picks >= 2)
	assert_same(run.current_pack_choice(), choice, "die Auswahl wartet")
	assert_eq(run.owned_packs.size(), 0, "gebucht wird erst beim Bestätigen")

func test_extra_options_from_charm_and_clauses() -> void:
	run.owned_charms.append(Charm.extra_option())
	var choice := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(1))
	assert_eq(choice.option_count(), 5, "Beigabe: eine Option mehr")
	run.pending_pack_choices.clear()
	_sign([DealClause.SUPPLEMENT])
	choice = run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(1))
	assert_eq(choice.option_count(), 6, "Beigabe und Beipack")

func test_sealed_takes_one_option_away() -> void:
	_sign([DealClause.SEALED])
	var choice := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(1))
	assert_eq(choice.option_count(), 3, "Verplombt")
	assert_lte(choice.picks, choice.option_count())

func test_bonus_pick_adds_a_pick() -> void:
	_sign([DealClause.BONUS_PICK])
	var choice := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_SMALL), 0, _rng(1))
	assert_true(choice.picks >= 2, "Zugabe: eine Wahl mehr")

func test_free_hand_only_for_the_first_pack() -> void:
	_sign([DealClause.FREE_HAND])
	var first := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(1))
	var second := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(2))
	assert_true(first.take_all)
	assert_eq(first.picks, first.option_count())
	assert_false(second.take_all, "nur das erste Paket der Runde")

# --- Bestätigen -------------------------------------------------------------------

func test_confirm_books_only_the_picks() -> void:
	var choice := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(5))
	var wanted: Object = choice.options[2]
	var result := run.confirm_pack_choice(choice, [2])
	assert_eq((result["cards"] as Array).size(), 1)
	assert_eq(run.owned_packs.size(), 1)
	assert_same(run.owned_packs[0], wanted, "genau die gewählte Karte")
	assert_null(run.current_pack_choice(), "Ungewähltes verfällt")

func test_confirm_with_nothing_forfeits_everything() -> void:
	var choice := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(5))
	run.confirm_pack_choice(choice, [])
	assert_eq(run.owned_packs.size(), 0)
	assert_null(run.current_pack_choice())

func test_confirm_refuses_too_many_picks() -> void:
	var choice := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_SMALL), 0, _rng(5))
	choice.picks = 1
	var result := run.confirm_pack_choice(choice, [0, 1])
	assert_eq((result["cards"] as Array).size(), 0)
	assert_same(run.current_pack_choice(), choice, "die Auswahl bleibt offen")

func test_dice_pack_books_into_pending_dice() -> void:
	var choice := run.purchase_dice_pack(DicePack.make(DicePack.SORT_POWER,
		CardPack.SIZE_LARGE), 36)
	assert_true(choice.is_dice())
	assert_eq(choice.option_count(), 5)
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

## Preise wie bei den Karten: erwartete Wahlen × Wert einer Option × Prämie.
func test_dice_price_table_matches_the_formula() -> void:
	for pack_sort: String in DicePack.SORTS:
		for pack_size in CardPack.SIZES:
			var expected := CardPack.expected_picks(pack_size) * _die_value(pack_sort) \
				* CardPack.CHOICE_PREMIUM
			assert_almost_eq(float(DicePack.price_of(pack_sort, pack_size)), expected, 2.0,
				"%s / %d" % [pack_sort, pack_size])

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
	var choice := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
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
	var choice := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(1))
	assert_false(run.reshuffle_pack_choice(choice))

func test_reshuffle_charm_is_free_once_per_round() -> void:
	run.energy = 0
	run.owned_charms.append(Charm.reshuffle())
	var first := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(1))
	assert_eq(run.pack_reshuffle_cost(first), 0)
	assert_true(run.reshuffle_pack_choice(first))
	run.confirm_pack_choice(first, [])
	var second := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_NORMAL), 0, _rng(2))
	assert_eq(run.pack_reshuffle_cost(second), GameRun.PACK_RESHUFFLE_ENERGY,
		"der Gratis-Neuwurf ist verbraucht")
	run.apply_round_start_charms()
	assert_eq(run.pack_reshuffle_cost(second), 0, "neue Runde, neuer Gratis-Neuwurf")

# --- Charms -----------------------------------------------------------------------------

func test_album_pays_per_opened_pack() -> void:
	run.owned_charms.append(Charm.album())
	run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_SMALL), 9)
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
	assert_not_null(bet.awarded_choice)
	assert_true(bet.awarded_choice.is_dice())
	assert_same(run.current_pack_choice(), bet.awarded_choice, "öffnet nach dem Kassieren")

func test_side_bet_card_pack_opens_a_choice() -> void:
	var bet := SideBet.new()
	bet.stake = 12
	bet.odds = SideBet.ODDS_HARD
	bet.payout_kind = SideBet.Payout.CARD_PACK
	bet.reward_card_pack_sort = CardPack.SORT_MATERIAL
	run._pay_side_bet(bet, 1.0)
	assert_not_null(bet.awarded_choice)
	assert_eq(run.owned_packs.size(), 0, "die Karten kommen erst mit der Wahl")
