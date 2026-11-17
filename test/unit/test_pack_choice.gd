extends GutTest
## Die PAKET-AUSWAHL: Wahl-Tabelle samt Glück, Optionen, Würfel-Pakete, Öffnen beim KAUF,
## Bestätigen (Karten) und Einsetzen (Würfel), Neu mischen und die Charms und Klauseln.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 500

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

## Kauft ein Paket - es öffnet sofort (seit dem 2026-11-17).
func _buy_open(pack: Resource, price: int, rng: RandomNumberGenerator = null) -> PackChoice:
	if pack is DicePack:
		return run.purchase_dice_pack(pack as DicePack, price, rng)
	return run.purchase_card_pack(pack as CardPack, price, rng)

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
	assert_eq(run.stored_card_packs.size(), 0, "nie ins Lager")
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

func test_dice_pack_is_not_confirmed_as_cards() -> void:
	var choice := _buy_open(DicePack.make(DicePack.SORT_NORMAL, 5), 26, _rng(4))
	assert_true(choice.is_dice())
	assert_gte(choice.option_count(), 5)
	assert_eq(choice.base_count, 5)
	assert_eq(choice.base_picks, 2)
	assert_eq(run.confirm_pack_choice(choice, [0, 1])["cards"], [], "nur confirm_dice_choice")
	assert_eq(run.pending_dice.size(), 0, "nie durchs Ausgabefach")
	assert_same(run.current_pack_choice(), choice, "die Auswahl bleibt offen")

# --- Einsetzen: confirm_dice_choice -------------------------------------------------------

func _dice_choice(picks := 2) -> PackChoice:
	var choice := _buy_open(DicePack.make(DicePack.SORT_NORMAL, 5), 0, _rng(4))
	choice.picks = picks
	return choice

func test_dice_choice_books_every_pair_by_become() -> void:
	var choice := _dice_choice()
	var seat_a: DieDefinition = run.owned_pool[3]
	var seat_b: DieDefinition = run.owned_pool[7]
	var old_a := seat_a.faces.duplicate()
	var option_a: DieDefinition = choice.options[0]
	var option_b: DieDefinition = choice.options[2]
	var heard := [0]
	run.pool_changed.connect(func() -> void: heard[0] += 1)
	var pool_size := run.owned_pool.size()
	var booked := run.confirm_dice_choice(choice, {2: 7, 0: 3})
	assert_eq(booked.size(), 2)
	assert_eq(heard[0], 1, "EIN pool_changed")
	assert_eq(run.owned_pool.size(), pool_size, "der Vorrat bleibt gleich groß")
	assert_same(run.owned_pool[3], seat_a, "dieselbe Instanz bleibt")
	assert_same(run.owned_pool[7], seat_b)
	assert_eq(seat_a.faces, option_a.faces, "der Inhalt der Option")
	assert_eq(seat_b.faces, option_b.faces)
	assert_null(run.current_pack_choice(), "die Auswahl ist zu")
	assert_true(run.pending_dice.is_empty(), "nicht durch den ZWANG")
	var first: Dictionary = booked[0]
	assert_eq(int(first["option_index"]), 0, "nach Options-Index sortiert")
	assert_eq(int(first["pool_index"]), 3)
	assert_same(first["option"], seat_a)
	var replaced: DieDefinition = first["replaced"]
	assert_eq(replaced.faces, old_a, "die Kopie VOR dem become")
	assert_ne(replaced, seat_a)

func test_dice_choice_never_shares_the_option_reference() -> void:
	var choice := _dice_choice(1)
	var option: DieDefinition = choice.options[1]
	run.confirm_dice_choice(choice, {1: 0})
	assert_ne(run.owned_pool[0], option)
	assert_false(run.owned_pool.has(option), "die Option wandert nie selbst in den Vorrat")
	run.owned_pool[0].faces[0] = 99
	assert_ne(option.faces[0], 99, "keine geteilten Arrays")

func test_dice_choice_empty_assignments_take_nothing() -> void:
	var choice := _dice_choice()
	var before := run.owned_pool[0].faces.duplicate()
	var heard := [0]
	run.pool_changed.connect(func() -> void: heard[0] += 1)
	assert_eq(run.confirm_dice_choice(choice, {}), [])
	assert_null(run.current_pack_choice(), "Nichts nehmen schließt")
	assert_eq(heard[0], 0)
	assert_eq(run.owned_pool[0].faces, before)

func test_dice_choice_invalid_books_nothing() -> void:
	var choice := _dice_choice(1)
	var faces := []
	for die in run.owned_pool:
		faces.append(die.faces.duplicate())
	var invalid := [
		[{0: 1, 1: 2}, 1],  # mehr als die Wahlen
		[{0: 3, 1: 3}, 2],  # ein Sitz zweimal
		[{0: -1}, 1],
		[{0: run.owned_pool.size()}, 1],
		[{choice.option_count(): 0}, 1],  # keine solche Option
	]
	for case: Array in invalid:
		var assignments: Dictionary = case[0]
		choice.picks = int(case[1])
		assert_eq(run.confirm_dice_choice(choice, assignments), [], str(assignments))
		assert_same(run.current_pack_choice(), choice, "bleibt offen")
	for i in run.owned_pool.size():
		assert_eq(run.owned_pool[i].faces, faces[i], "nichts gebucht")

func test_dice_choice_refuses_card_choices_and_closed_ones() -> void:
	var cards := _buy_open(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_SMALL), 0, _rng(1))
	assert_eq(run.confirm_dice_choice(cards, {0: 0}), [], "nur Würfel-Pakete")
	assert_same(run.current_pack_choice(), cards)
	run.confirm_pack_choice(cards, [])
	var dice := _dice_choice(1)
	run.pending_pack_choices.clear()
	assert_eq(run.confirm_dice_choice(dice, {0: 0}), [], "nicht mehr offen")
	assert_eq(run.confirm_dice_choice(null, {}), [])

# --- Würfel-Pakete --------------------------------------------------------------------

func _has_rune(die: DieDefinition) -> bool:
	return die.runes.count(Rune.NONE) < die.runes.size()

func _rune_count(die: DieDefinition) -> int:
	return die.runes.size() - die.runes.count(Rune.NONE)

func test_four_sorts_with_names_and_weights() -> void:
	assert_eq(DicePack.SORTS, [DicePack.SORT_NORMAL, DicePack.SORT_SOUL, DicePack.SORT_MATERIAL,
		DicePack.SORT_RUNE])
	assert_eq(DicePack.sort_name(DicePack.SORT_NORMAL), "Würfel-Paket")
	assert_eq(DicePack.sort_name(DicePack.SORT_SOUL), "Seelen-Paket")
	assert_eq(DicePack.sort_name(DicePack.SORT_MATERIAL), "Material-Würfelpaket")
	assert_eq(DicePack.sort_name(DicePack.SORT_RUNE), "Runen-Würfelpaket")
	assert_eq(DicePack.SHOP_SORT_WEIGHTS, {DicePack.SORT_NORMAL: 50, DicePack.SORT_MATERIAL: 20,
		DicePack.SORT_SOUL: 15, DicePack.SORT_RUNE: 15})
	assert_eq(DicePack.make("power", CardPack.SIZE_NORMAL).sort, DicePack.SORT_NORMAL,
		"eine gestorbene Sorte fällt auf normal")
	var seen := {}
	for seed_value in 400:
		seen[DicePack.roll_shop(_rng(seed_value)).sort] = true
	assert_eq(seen.size(), 4, "alle vier Sorten liegen aus")

## Würfel-Pakete haben 2..6 Augen statt einer Größe; Karten-Pakete behalten Klein.
func test_dice_packs_count_two_to_six_pips() -> void:
	assert_eq(DicePack.SIZES, [2, 3, 4, 5, 6])
	assert_eq(DicePack.make(DicePack.SORT_NORMAL, 1).size, 2, "nie unter zwei")
	assert_eq(DicePack.make(DicePack.SORT_NORMAL, 9).size, 6, "nie über sechs")
	assert_eq(DicePack.SHOP_SIZE_WEIGHTS, [20, 35, 25, 13, 7])
	var seen := {}
	for seed_value in 400:
		var pips := DicePack.roll_shop(_rng(seed_value)).size
		assert_true(DicePack.SIZES.has(pips))
		seen[pips] = true
	assert_eq(seen.size(), 5, "alle fünf Augenzahlen liegen aus")
	assert_eq(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_SMALL).size, CardPack.SIZE_SMALL,
		"Karten-Pakete behalten Klein")

func test_dice_pack_contents_guarantee_their_sort() -> void:
	var owned: Array[String] = []
	var ids: Array[String] = []
	var second_rune := false
	for i in 40:
		var soul := DiceOffer.roll_pack_die(DicePack.SORT_SOUL, 1, ids, owned, {}, 0)
		assert_ne(soul.essence_id, "", "Seelen-Paket: immer eine Seele")
		var material := DiceOffer.roll_pack_die(DicePack.SORT_MATERIAL, 1, ids, owned, {}, 0)
		assert_gte(material.materials.size() - material.materials.count(""), 2)
		var rune := DiceOffer.roll_pack_die(DicePack.SORT_RUNE, 1, ids, owned, {}, 100)
		assert_true(_has_rune(rune), "Runen-Paket: mindestens eine Rune")
		if _rune_count(rune) >= 2:
			second_rune = true
	assert_true(second_rune, "mit der Runen-Chance eine zweite")

func test_every_sort_may_bring_soul_material_and_rune() -> void:
	var owned: Array[String] = []
	var ids: Array[String] = []
	var found := {"soul": false, "material": false, "rune": false}
	for i in 200:
		var die := DiceOffer.roll_pack_die(DicePack.SORT_NORMAL, 1, ids, owned, {}, 0)
		found["soul"] = found["soul"] or die.essence_id != ""
		found["material"] = found["material"] or die.materials.count("") < 6
		found["rune"] = found["rune"] or _has_rune(die)
		assert_false(DiceOffer.has_doped_side(die), "Veredelung kommt nicht aus Paketen")
	assert_eq(found, {"soul": true, "material": true, "rune": true})

func test_rune_chance_from_luck() -> void:
	assert_almost_eq(DiceOffer.pack_rune_chance(0), 0.15, 0.0001)
	assert_almost_eq(DiceOffer.pack_rune_chance(10), 0.30, 0.0001)
	assert_almost_eq(DiceOffer.pack_rune_chance(100), 0.5, 0.0001, "Deckel")
	var ids: Array[String] = []
	var hits := [0, 0]
	for i in 600:
		var owned: Array[String] = []
		hits[0] += 1 if _has_rune(DiceOffer.roll_pack_die(DicePack.SORT_NORMAL, 1, ids, owned,
			{}, 0)) else 0
		hits[1] += 1 if _has_rune(DiceOffer.roll_pack_die(DicePack.SORT_NORMAL, 1, ids, owned,
			{}, 100)) else 0
	assert_almost_eq(float(hits[0]) / 600.0, 0.15, 0.05)
	assert_almost_eq(float(hits[1]) / 600.0, 0.5, 0.06)

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
		var none := DiceOffer.roll_pack_die(DicePack.SORT_NORMAL, 1, ids, owned,
			{"chance": 0.0, "boost": 1.0}, 50)
		assert_eq(none.essence_id, "", "Seelenlos")

## Die Preise der Güte Standard stehen je Augenzahl fest (Vorgabe 2026-11-14); die Güte multipliziert.
func test_dice_price_table() -> void:
	assert_eq(DicePack.PRICES, {DicePack.SORT_NORMAL: [10, 14, 20, 26, 32],
		DicePack.SORT_SOUL: [20, 27, 38, 50, 60], DicePack.SORT_MATERIAL: [15, 21, 30, 38, 46],
		DicePack.SORT_RUNE: [15, 21, 30, 38, 46]})
	for pack_sort: String in DicePack.SORTS:
		for pips in DicePack.SIZES:
			var table := float(DicePack.PRICES[pack_sort][pips - DicePack.MIN_COUNT])
			for pack_quality in DicePack.QUALITIES:
				assert_eq(DicePack.price_of(pack_sort, pips, pack_quality),
					roundi(table * float(DicePack.QUALITY_PRICE_FACTORS[pack_quality])))
	assert_eq(DicePack.make(DicePack.SORT_SOUL, 6, DicePack.QUALITY_ROYAL).price, roundi(60 * 2.8))
	assert_eq(DicePack.price_of(DicePack.SORT_NORMAL, 2), 10, "das billigste Paket")
	assert_eq(SideBet.DICE_PACK_MIN, 10)

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
	var kept := false
	for seed_value in 20:
		var money := run.money
		var choice := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
			CardPack.SIZE_SMALL), 9, _rng(seed_value))
		assert_not_null(choice, "erstattet oder nicht: geöffnet wird immer")
		if run.last_card_pack_refund == 9:
			refunded = true
			assert_eq(run.money, money, "voll zurück")
		else:
			kept = true
			assert_eq(run.money, money - 9)
		run.pending_pack_choices.clear()
	assert_true(refunded, "das Kleingedruckte erstattet den Paketpreis")
	assert_true(kept, "aber nicht immer")

# --- Nebenwetten -------------------------------------------------------------------------

func test_side_bet_pays_one_dice_pack() -> void:
	var bet := SideBet.new()
	bet.stake = 12
	bet.odds = SideBet.ODDS_HARD
	bet.payout_kind = SideBet.Payout.DICE_PACK
	bet.reward_dice_pack_sort = DicePack.SORT_SOUL
	var dice_pack := bet.reward_dice_pack()
	assert_not_null(dice_pack)
	assert_lte(dice_pack.price, bet.payout_value(), "der Preis passt in den Gewinnwert")
	assert_same(bet.reward_dice_pack(), dice_pack, "Knopf und Abrechnung meinen dasselbe")
	assert_eq(bet.reward_label(), "1 %s" % dice_pack.display_name)
	run._pay_side_bet(bet, 1.0)
	assert_not_null(bet.awarded_choice, "der Gewinn öffnet sofort")
	assert_same(run.current_pack_choice(), bet.awarded_choice)
	assert_true(bet.awarded_choice.is_dice())
	assert_true(bet.awarded_choice.from_bet)
	assert_true(run.stored_dice_packs.is_empty())

func test_side_bet_card_pack_opens_a_choice() -> void:
	var bet := SideBet.new()
	bet.stake = 12
	bet.odds = SideBet.ODDS_HARD
	bet.payout_kind = SideBet.Payout.CARD_PACK
	bet.reward_card_pack_sort = CardPack.SORT_MATERIAL
	run._pay_side_bet(bet, 1.0)
	assert_not_null(bet.awarded_choice, "geöffnet")
	assert_false(bet.awarded_choice.is_dice())
	assert_true(run.stored_card_packs.is_empty(), "nie ins Lager")
	assert_eq(run.owned_packs.size(), 0, "die Karten kommen erst mit der Wahl")

func test_side_bet_packs_queue_one_after_another() -> void:
	var choices: Array = []
	for i in 2:
		var bet := SideBet.new()
		bet.stake = 12
		bet.odds = SideBet.ODDS_HARD
		bet.payout_kind = SideBet.Payout.CARD_PACK
		bet.reward_card_pack_sort = CardPack.SORT_NUMBER
		run._pay_side_bet(bet, 1.0)
		choices.append(bet.awarded_choice)
	assert_eq(run.pending_pack_choices.size(), 2)
	assert_same(run.current_pack_choice(), choices[0], "das erste zuerst")

# --- Öffnen beim KAUF ---------------------------------------------------------------------

func test_purchase_opens_at_once_and_stores_nothing() -> void:
	var offer := DicePack.make(DicePack.SORT_NORMAL, 4, DicePack.QUALITY_FINE)
	var choice := run.purchase_dice_pack(offer, 40)
	assert_eq(run.money, 460, "bezahlt")
	assert_not_null(choice)
	assert_same(run.current_pack_choice(), choice, "die Auswahl wartet")
	assert_eq(choice.quality, DicePack.QUALITY_FINE)
	assert_eq(choice.size, 4)
	assert_false(choice.from_bet)
	assert_ne(choice.pack, offer, "die Auslage behält ihr Angebot")
	assert_true(run.stored_dice_packs.is_empty(), "das Lager bekommt nichts mehr")

func test_a_full_store_never_blocks_a_purchase() -> void:
	run.debug_fill_store()
	assert_true(run.store_full(GameRun.LANE_CARDS))
	var choice := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER,
		CardPack.SIZE_SMALL), 10)
	assert_not_null(choice, "das Lager sperrt nichts mehr")
	assert_eq(run.money, 490)
	assert_eq(run.stored_card_packs.size(), GameRun.STORE_CAPACITY, "und wächst nicht")

func test_purchases_queue_their_choices() -> void:
	var a := run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_SMALL), 0)
	var b := run.purchase_card_pack(CardPack.make(CardPack.SORT_RUNE, CardPack.SIZE_NORMAL), 0)
	assert_eq(run.pending_pack_choices.size(), 2)
	assert_same(run.current_pack_choice(), a)
	run.confirm_pack_choice(a, [])
	assert_same(run.current_pack_choice(), b, "eines nach dem anderen")

func test_a_null_pack_books_nothing() -> void:
	assert_null(run.purchase_card_pack(null, 10))
	assert_null(run.purchase_dice_pack(null, 10))
	assert_eq(run.money, 500)

func test_a_new_run_has_no_open_choice() -> void:
	run.purchase_card_pack(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_SMALL), 0)
	var fresh := GameRun.new_run()
	assert_true(fresh.pending_pack_choices.is_empty())
	assert_eq(fresh.stored_card_packs.size(), 0)

# --- Würfel-Pakete: Größe, Güte-Glück und die zwei Ketten ------------------------------

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

func test_base_numbers_per_pips() -> void:
	assert_eq(DicePack.BASE_PICKS, [1, 1, 1, 2, 2])
	var picks := {2: 1, 3: 1, 4: 1, 5: 2, 6: 2}
	for pips in DicePack.SIZES:
		assert_eq(DicePack.base_count(pips), pips, "die Augen sind die Grundzahl")
		assert_eq(DicePack.base_picks(pips), picks[pips], "%der" % pips)
	assert_eq(DicePack.MAX_COUNT, 6)

func test_dice_count_chain_stays_in_bounds() -> void:
	var extra := 0
	var deep := false
	for seed_value in 1000:
		var low := DicePack.roll_count(3, 0, 1.0, _rng(seed_value))
		assert_between(low, 3, 6)
		if low > 3:
			extra += 1
		var high := DicePack.roll_count(2, 100, 1.0, _rng(seed_value))
		assert_between(high, 2, 6)
		if high >= 4:
			deep = true
		assert_eq(DicePack.roll_count(6, 100, 2.0, _rng(seed_value)), 6, "der 6er bekommt nichts dazu")
		assert_lte(DicePack.roll_count(8, 100, 1.0, _rng(seed_value)), DicePack.MAX_COUNT)
	assert_almost_eq(float(extra) / 1000.0, 0.20, 0.04, "20 % auf den ersten Zusatz")
	assert_true(deep, "die Kette reicht weiter als einen Würfel")

## Nie mehr als sechs Würfel - auch mit hohem Glück, Glücksgriff und Beigabe.
func test_never_more_than_six_dice() -> void:
	run.luck = 100
	run.owned_charms.append(Charm.extra_option())
	_sign([DealClause.LUCKY_GRAB])
	for pips in DicePack.SIZES:
		for seed_value in 30:
			var choice := _buy_open(DicePack.make(DicePack.SORT_NORMAL, pips,
				DicePack.QUALITY_ROYAL), 0, _rng(seed_value))
			assert_lte(choice.base_count, DicePack.MAX_COUNT, "Beigabe geklemmt")
			assert_between(choice.option_count(), mini(pips + 1, 6), 6, "%der" % pips)
			run.pending_pack_choices.clear()

func test_quality_is_luck_for_the_pack() -> void:
	assert_eq(DicePack.QUALITY_LUCK, [0, 6, 12])
	run.luck = 2
	for pack_quality in DicePack.QUALITIES:
		var dice_pack := DicePack.make(DicePack.SORT_NORMAL, CardPack.SIZE_NORMAL, pack_quality)
		assert_eq(run.pack_luck(dice_pack), 2 + int(DicePack.QUALITY_LUCK[pack_quality]))
	var tier := run.shop_tier()
	_buy_open(DicePack.make(DicePack.SORT_NORMAL, CardPack.SIZE_NORMAL, DicePack.QUALITY_ROYAL),
		0, _rng(1))
	assert_eq(run.shop_tier(), tier, "die Güte hebt die Augen-Vorlagen nicht")

## Gleiche Würfe, nur die Güte anders: Royal (+12 Glück) bringt mehr Würfel und mehr Wahlen.
func test_quality_luck_raises_the_chains() -> void:
	var dice := [0, 0]
	var picks := [0, 0]
	for seed_value in 300:
		for q in 2:
			var quality := DicePack.QUALITY_STANDARD if q == 0 else DicePack.QUALITY_ROYAL
			var choice := _buy_open(DicePack.make(DicePack.SORT_NORMAL, 3, quality), 0,
				_rng(seed_value))
			dice[q] += choice.option_count()
			picks[q] += choice.picks
			run.pending_pack_choices.clear()
	assert_gt(dice[1], dice[0] + 40, "mehr Würfel")
	assert_gt(picks[1], picks[0] + 15, "mehr Wahlen")

func test_quality_luck_reaches_souls_and_runes() -> void:
	var souls := [0, 0]
	var runes := [0, 0]
	for seed_value in 120:
		for q in 2:
			var quality := DicePack.QUALITY_STANDARD if q == 0 else DicePack.QUALITY_ROYAL
			var choice := _buy_open(DicePack.make(DicePack.SORT_NORMAL, 3, quality), 0,
				_rng(seed_value))
			for die: DieDefinition in choice.options:
				souls[q] += 1 if die.essence_id != "" else 0
				runes[q] += 1 if _has_rune(die) else 0
			run.pending_pack_choices.clear()
	assert_gt(souls[1], souls[0] * 2, "Seele: 15 % gegen 51 %")
	assert_gt(runes[1], runes[0] + 40, "Rune: 15 % gegen 33 %")

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
	for pack_size in DicePack.SIZES:
		for seed_value in 25:
			var choice := _buy_open(DicePack.make(DicePack.SORT_NORMAL, pack_size,
				DicePack.QUALITY_FINE), 0, _rng(seed_value))
			var count := choice.option_count()
			assert_between(count, DicePack.base_count(pack_size), DicePack.MAX_COUNT)
			assert_between(choice.picks, 1, count - 1)
			assert_lte(choice.base_picks, choice.picks)
			assert_false(choice.take_all, "kein Hauptgewinn bei Würfel-Paketen")
			run.pending_pack_choices.clear()

func test_option_clauses_move_the_base_count() -> void:
	_sign([DealClause.SEALED])
	var sealed := _buy_open(DicePack.make(DicePack.SORT_NORMAL, 3), 0, _rng(1))
	assert_eq(sealed.base_count, DicePack.MIN_COUNT, "Verplombt: 3 - 1")
	assert_eq(sealed.base_picks, 1)
	run.active_deals.clear()
	run.pending_pack_choices.clear()
	run.owned_charms.append(Charm.extra_option())
	var extra := _buy_open(DicePack.make(DicePack.SORT_NORMAL, 3), 0, _rng(1))
	assert_eq(extra.base_count, 4, "Beigabe: ein Würfel mehr")
	assert_gte(extra.option_count(), 4)

func test_lucky_grab_doubles_both_chains() -> void:
	assert_eq(run.pack_luck_factor(), 1.0)
	_sign([DealClause.LUCKY_GRAB])
	assert_eq(run.pack_luck_factor(), 2.0)
	var extra := 0
	for seed_value in 400:
		var choice := _buy_open(DicePack.make(DicePack.SORT_NORMAL, 3), 0, _rng(seed_value))
		if choice.option_count() > 3:
			extra += 1
		run.pending_pack_choices.clear()
	assert_almost_eq(float(extra) / 400.0, 0.40, 0.08, "Zugabe-Kette doppelt so oft")

func test_free_hand_gives_count_minus_one_and_bonus_pick_adds_one() -> void:
	_sign([DealClause.FREE_HAND])
	var free := _buy_open(DicePack.make(DicePack.SORT_NORMAL, 5), 0, _rng(2))
	assert_eq(free.picks, free.option_count() - 1, "Freie Hand: das Maximum")
	assert_false(free.take_all)
	run.active_deals.clear()
	run.pending_pack_choices.clear()
	_sign([DealClause.BONUS_PICK])
	var bonus := _buy_open(DicePack.make(DicePack.SORT_NORMAL, 5), 0, _rng(2))
	assert_eq(bonus.base_picks, 3, "Zugabe: +1 innerhalb des Deckels")
	assert_lte(bonus.picks, bonus.option_count() - 1)

func test_dice_packs_never_reshuffle() -> void:
	run.energy = 100
	run.owned_charms.append(Charm.reshuffle())
	var choice := _buy_open(DicePack.make(DicePack.SORT_NORMAL, 3), 0, _rng(4))
	var before: Array = choice.options.duplicate()
	assert_eq(run.pack_reshuffle_cost(choice), -1)
	assert_false(run.reshuffle_pack_choice(choice, _rng(5)))
	assert_eq(choice.options, before)
	assert_eq(run.energy, 100, "keine Energie verbraucht")

func test_soulless_stays_soulless_and_the_soul_pack_lifts_once() -> void:
	var ids: Array[String] = []
	var owned: Array[String] = []
	for i in 30:
		var none := DiceOffer.roll_pack_die(DicePack.SORT_NORMAL, 1, ids, owned,
			{"chance": 0.0, "boost": 1.0}, 50)
		assert_eq(none.essence_id, "")
		var soul := DiceOffer.roll_pack_die(DicePack.SORT_SOUL, 1, ids, owned, {}, 0)
		assert_gte(int(Essence.by_id(soul.essence_id).rarity), int(Essence.Rarity.RARE),
			"Seelen-Paket: eine Stufe gehoben")

func test_shop_quality_weights_shift_with_the_tier() -> void:
	assert_eq(DicePack.shop_quality_weights(1), [65, 27, 8])
	assert_eq(DicePack.shop_quality_weights(3), [55, 33, 12])
	assert_eq(DicePack.shop_quality_weights(10), [20, 54, 26])
	assert_eq(run.shop_dice_pack_quality_weights(), [65, 27, 8])
	var seen := {}
	for seed_value in 300:
		seen[DicePack.roll_shop(_rng(seed_value)).quality] = true
	assert_eq(seen.size(), 3, "alle drei Güten liegen aus")

func test_shop_text_names_floors_and_quality_luck_but_no_odds() -> void:
	var dice_pack := DicePack.make(DicePack.SORT_SOUL, 5, DicePack.QUALITY_FINE)
	assert_eq(dice_pack.display_name, "5er Seelen-Paket · Edel")
	assert_eq(DicePack.make(DicePack.SORT_NORMAL, 3).display_name, "3er Würfel-Paket")
	assert_eq(DicePack.make(DicePack.SORT_NORMAL, 6, DicePack.QUALITY_ROYAL).display_name,
		"6er Würfel-Paket · Royal")
	var text := DicePack.info_body(dice_pack)
	assert_string_contains(text, "Mindestens 5 Würfel")
	assert_string_contains(text, "Mindestens 2 Wahlen")
	assert_string_contains(text, "+6 Glück")
	assert_false(text.contains("%"), "keine Chancen")
	assert_string_contains(DicePack.info_body(DicePack.make(DicePack.SORT_RUNE, 6,
		DicePack.QUALITY_ROYAL)), "+12 Glück")
	var plain := DicePack.info_body(DicePack.make(DicePack.SORT_NORMAL, 4))
	assert_string_contains(plain, "Mindestens 4 Würfel")
	assert_string_contains(plain, "Mindestens 1 Wahl")
	assert_false(plain.contains("Glück"), "Standard nennt kein Glück")

func test_side_bet_takes_the_dearest_affordable_pair() -> void:
	assert_eq(SideBet.reward_dice_pair(DicePack.SORT_NORMAL, 60),
		Vector2i(4, DicePack.QUALITY_ROYAL), "56 ist das teuerste bis 60")
	assert_eq(SideBet.reward_dice_pair(DicePack.SORT_NORMAL, 40),
		Vector2i(3, DicePack.QUALITY_ROYAL))
	assert_eq(SideBet.reward_dice_pair(DicePack.SORT_NORMAL, 5),
		Vector2i(2, DicePack.QUALITY_STANDARD), "nichts bezahlbar: der 2er")
	var bet := SideBet.new()
	bet.stake = 30
	bet.odds = SideBet.ODDS_HARD
	bet.payout_kind = SideBet.Payout.DICE_PACK
	bet.reward_dice_pack_sort = DicePack.SORT_RUNE
	var dice_pack := bet.reward_dice_pack()
	assert_lte(dice_pack.price, bet.payout_value())
	assert_true(DicePack.SIZES.has(dice_pack.size))
	assert_same(bet.reward_dice_pack(), dice_pack)
