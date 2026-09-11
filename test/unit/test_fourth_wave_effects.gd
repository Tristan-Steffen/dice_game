extends GutTest
## Tier-3-Tests der vierten Inhalts-Welle: Ökonomie, Werkbank und Zeremonien -
## Supraleiter, Dynamo, Trostpreis, Hehlerware, Freispiel, Quotenblatt, Zwinge,
## Füllhorn, Pfandregal, Jackpotglocke, Politur, Stichel, Gießkanne, Härteofen und
## die Angebots-Sperren der Charms ohne ihr Spielzeug.

func _d(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _p(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _m(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _ids(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _defs(values: Array) -> Array[DieDefinition]:
	var typed: Array[DieDefinition] = []
	typed.assign(values)
	return typed

const NO_CHARMS: Array[String] = []
const PAIR := DiceScoring.TWO_KIND

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

## Würfel mit gesetzten Seitenwerten (und optional einem Material auf Seite 0).
func _die(faces: Array, face_material := "", level := 1) -> DieDefinition:
	var def := DieDefinition.new()
	def.faces = _d(faces)
	if face_material != "":
		def.set_face_material(0, face_material)
		if level >= DieMaterial.MAX_LEVEL:
			def.dope(0)
	return def

func _has_id(pool: Array[Charm], charm_id: String) -> bool:
	for charm in pool:
		if charm.id == charm_id:
			return true
	return false

## Ein Generator, dessen ERSTER Wurf unter (bzw. über) der Schwelle liegt - nur so
## lässt sich eine Chance in beide Ausgänge zwingen.
func _rng_rolling(below: bool, chance: float) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	for s in 500:
		rng.seed = s
		if (rng.randf() < chance) == below:
			rng.seed = s
			return rng
	return null

# --- Supraleiter: Übertakten kostet eine Energie weniger ---------------------------

func test_the_superconductor_shaves_a_energy_off_the_overclock_price():
	assert_eq(GameRun.overclock_cost_at(3), 4, "unverändert ohne Charm")
	assert_eq(GameRun.overclock_cost_at(3, _ids([Charm.SUPERCONDUCTOR])), 3)
	assert_eq(GameRun.overclock_cost_at(0, _ids([Charm.SUPERCONDUCTOR])), 1,
		"nie unter eine Energie - gratis übertaktet niemand")
	assert_eq(GameRun.overclock_cost_at(9, _ids([Charm.SUPERCONDUCTOR, Charm.SUPERCONDUCTOR])), 3,
		"der Deckel 5 minus zwei Exemplare")

func test_the_overclock_price_the_chip_shows_carries_the_charm():
	run.combo_levels[PAIR] = 2
	assert_eq(run.overclock_cost(PAIR), 3)
	run.owned_charms.append(Charm.superconductor())
	assert_eq(run.overclock_cost(PAIR), 2, "der Chip liest dieselbe Abfrage")
	run.energy = 2
	assert_true(run.can_overclock(PAIR))
	assert_true(run.overclock_combo(PAIR))
	assert_eq(run.energy, 0, "abgebucht wird der ermäßigte Preis")

# --- Dynamo & Trostpreis: zwei neue ⚡-Quellen -------------------------------------

func test_the_dynamo_mints_at_the_end_of_a_cleared_round():
	var ids := _ids([Charm.DYNAMO, Charm.HORSESHOE])
	assert_eq(CharmEffects.round_end_energy_at(0, ids), CharmEffects.DYNAMO_ENERGY)
	assert_eq(CharmEffects.round_end_energy_at(1, ids), 0, "nur der Dynamo prägt")
	# Je Exemplar ein eigener Schritt der Rundenende-Zeremonie, nie eine Summe.
	var twins := _ids([Charm.DYNAMO, Charm.DYNAMO])
	assert_eq(CharmEffects.round_end_energy_at(0, twins), CharmEffects.DYNAMO_ENERGY)
	assert_eq(CharmEffects.round_end_energy_at(1, twins), CharmEffects.DYNAMO_ENERGY)

func test_the_consolation_prize_books_its_energy_on_the_fumble():
	run.hub_level = 3  # zwei erwachte Reihen, der Deckel steht nicht im Weg
	assert_eq(run.note_fumble(false), 0, "ohne Charm prägt der Fumble nichts")
	assert_eq(run.energy, 0)
	run.owned_charms.append(Charm.consolation_prize())
	assert_eq(run.note_fumble(false), 1, "gebucht wird in GameRun, geflogen erst danach")
	assert_eq(run.energy, 1)
	assert_eq(run.round_fumbles, 2, "der Zähler läuft unabhängig weiter")

func test_the_consolation_energy_respects_the_full_wallet():
	run.owned_charms.append(Charm.consolation_prize())
	run.energy = run.energy_cap()
	run.note_fumble(false)
	assert_eq(run.energy, run.energy_cap(), "add_energy klemmt am Deckel")

# --- Hehlerware: Schwarzmarkt-Angebote werden billiger ------------------------------

func test_the_fenced_goods_cut_every_offer_price_but_never_below_one():
	var offer := {GameRun.OFFER_KIND: GameRun.KIND_CHARM, GameRun.OFFER_ITEM: null,
		GameRun.OFFER_PRICE: 6, GameRun.OFFER_SOLD: false}
	assert_eq(run.secret_offer_price(offer), 6)
	run.owned_charms.append(Charm.fenced_goods())
	assert_eq(run.secret_offer_price(offer), 5)
	offer[GameRun.OFFER_PRICE] = 1
	assert_eq(run.secret_offer_price(offer), 1, "mindestens eine Energie")

func test_the_reroll_price_stays_flat_under_the_fenced_goods():
	run.owned_charms.append(Charm.fenced_goods())
	assert_eq(run.secret_reroll_cost(), GameRun.SECRET_REROLL_BASE)

func test_the_back_room_energys_the_discounted_price():
	run.hub_level = GameRun.SECRET_UNLOCK_HUB_LEVEL
	run.unlock_secret_shop()
	run.owned_charms.append(Charm.fenced_goods())
	# Der Sonderposten-Platz führt seit den Katalysatoren zwei Familien - für diesen
	# Test muss die Gravur darin liegen.
	run.secret_stock[1] = run._secret_engraving_offer()
	var index := 1
	var price := run.secret_offer_price(run.secret_stock[index])
	assert_eq(price, int(run.secret_stock[index][GameRun.OFFER_PRICE]) - 1)
	run.energy = price
	assert_true(run.buy_secret_offer(index), "der ermäßigte Preis reicht")
	assert_eq(run.energy, 0)

# --- Freispiel: der erste Dreh je Ladenbesuch ---------------------------------------

func test_the_free_spin_pays_the_first_spin_of_a_visit():
	run.hub_level = 3  # Automat I steht
	run.energy = 0
	run.owned_charms.append(Charm.free_spin())
	assert_eq(run.slot_spin_energy(0), 0, "der erste Dreh geht aufs Haus")
	assert_true(run.can_spin_slot(0), "ohne Energie drehbar")
	assert_false(run.spin_slot(0).is_empty())
	assert_eq(run.energy, 0, "nichts abgebucht")
	assert_gt(run.slot_spin_energy(0), 0, "der zweite Dreh kostet wieder")
	assert_false(run.can_spin_slot(0), "und ohne Energie geht er nicht")

func test_the_free_spin_lives_up_again_when_the_shop_opens():
	run.hub_level = 3
	run.owned_charms.append(Charm.free_spin())
	run.spin_slot(0)
	assert_true(run.free_spin_used_this_visit)
	run.begin_shop_visit()
	assert_false(run.free_spin_used_this_visit)
	assert_eq(run.slot_spin_energy(0), 0)

func test_without_the_charm_the_spin_costs_as_before():
	run.hub_level = 3
	run.energy = 10
	var price := run.slot_spin_energy(0)
	assert_gt(price, 0)
	run.spin_slot(0)
	assert_eq(run.energy, 10 - price)

# --- Quotenblatt: Bargeld-Gewinne doppelt --------------------------------------------

func test_the_odds_sheet_doubles_the_money_payout():
	assert_eq(CharmEffects.side_bet_money(10, _ids([Charm.ODDS_SHEET])), 20)
	assert_eq(CharmEffects.side_bet_money(5, _ids([Charm.ODDS_SHEET])), 10)
	assert_eq(CharmEffects.side_bet_money(10, NO_CHARMS), 10)
	assert_eq(CharmEffects.side_bet_money(0, _ids([Charm.ODDS_SHEET])), 0)

func test_the_odds_sheet_lands_in_the_settlement():
	run.money = 50
	run.owned_charms.append(Charm.odds_sheet())
	var bet := SideBet._from_template(_template("jackpot"))
	run.place_side_bet(bet)
	var after_stake := run.money
	var result := {"cleared": true, "best_combo_rank": SideBet.combo_rank(DiceScoring.FULL_HOUSE),
		"best_hand_score": 0, "dice_taken": 0, "farkled": false}
	run.resolve_side_bets(result)
	assert_eq(run.money, after_stake + ceili(bet.payout_money * CharmEffects.ODDS_SHEET_FACTOR))

func test_the_odds_sheet_stands_on_the_bet_button():
	var bet := SideBet._from_template(_template("jackpot"))
	assert_eq(bet.reward_label(1, _ids([Charm.ODDS_SHEET])),
		"$%d" % ceili(bet.payout_money * CharmEffects.ODDS_SHEET_FACTOR), "der Knopf verspricht, was die Abrechnung zahlt")
	assert_eq(bet.reward_label(), "$%d" % bet.payout_money)

func test_a_energy_payout_stays_untouched_by_the_odds_sheet():
	run.owned_charms.append(Charm.odds_sheet())
	var bet := SideBet.new()
	bet.payout_kind = SideBet.Payout.ENERGY
	bet.payout_energy = 2
	run.hub_level = 3
	run._pay_side_bet(bet, 1)
	assert_eq(run.energy, 2, "Energie ist keine Barauszahlung")

func _template(id: String) -> Dictionary:
	for t in SideBet.TEMPLATES:
		if t["id"] == id:
			return t
	return {}

# --- Zwinge: die gepresste Datenzelle brennt manchmal nicht aus -------------------

func test_the_clamp_chance_stacks_and_caps():
	assert_eq(CharmEffects.pack_survive_chance(NO_CHARMS), 0.0)
	assert_almost_eq(CharmEffects.pack_survive_chance(_ids([Charm.CLAMP])), 0.25, 0.0001)
	var four := _ids([Charm.CLAMP, Charm.CLAMP, Charm.CLAMP, Charm.CLAMP])
	assert_almost_eq(CharmEffects.pack_survive_chance(four), CharmEffects.CLAMP_SURVIVE_CAP, 0.0001)

## Sucht einen Seed mit dem gewünschten Ausgang - der Überlebens-Wurf liegt in der
## Serie, also liest man ihn nur an einem echten Griff ab.
func _press_seed(keeps: bool) -> RandomNumberGenerator:
	for seed_value in 200:
		var probe := GameRun.new_run()
		probe.owned_charms.append(Charm.bench_clamp())
		var pack := probe.grant_pack(Pack.material_pack())
		var result := probe.apply_series([pack.pack_uid] as Array[int],
			probe.owned_pool[0], null, _rng(seed_value))
		if (int(result.get("kept", 0)) > 0) == keeps:
			return _rng(seed_value)
	return _rng(0)

func _press(rng: RandomNumberGenerator) -> Dictionary:
	var uids: Array[int] = []
	for pack in run.owned_packs:
		uids.append(pack.pack_uid)
	return run.apply_series(uids, run.owned_pool[0], null, rng)

func test_a_surviving_cell_stays_in_the_shelf_and_still_pays():
	run.owned_charms.append(Charm.bench_clamp())
	run.grant_pack(Pack.material_pack())
	var result := _press(_press_seed(true))
	assert_false(SeriesResolver.is_empty(result["projection"]),
		"die volle Projektion fällt trotzdem")
	assert_eq(int(result.get("kept", 0)), 1)
	assert_eq(run.owned_packs.size(), 1, "die Zelle liegt wieder im Regal")

func test_a_burnt_cell_is_gone():
	run.owned_charms.append(Charm.bench_clamp())
	run.grant_pack(Pack.material_pack())
	var result := _press(_press_seed(false))
	assert_false(SeriesResolver.is_empty(result["projection"]))
	assert_eq(int(result.get("kept", 0)), 0)
	assert_eq(run.owned_packs.size(), 0)

func test_without_the_clamp_every_cell_burns():
	run.grant_pack(Pack.material_pack())
	var result := _press(_press_seed(true))
	assert_eq(int(result.get("kept", 0)), 0, "ohne Zwinge überlebt nichts")
	assert_eq(run.owned_packs.size(), 0)

func test_a_survivor_can_be_used_again():
	run.owned_charms.append(Charm.bench_clamp())
	run.grant_pack(Pack.material_pack())
	_press(_press_seed(true))
	assert_eq(run.owned_packs.size(), 1)
	assert_false(_press(_rng(3)).is_empty(), "sie prägt ein zweites Mal")

# --- Füllhorn: ab fünf geräumten Überladungs-Stufen ein Sonderposten ------------------

func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng

func test_the_encore_pays_at_five_cleared_stages():
	run.owned_charms.append(Charm.encore())
	assert_eq(run.apply_encore(GameRun.ENCORE_STAGES - 1).size(), 0, "unter der Schwelle nichts")
	assert_eq(run.owned_packs.size(), 0)
	var granted := run.apply_encore(GameRun.ENCORE_STAGES)
	assert_eq(granted.size(), 1)
	assert_eq(run.owned_packs.size(), 1, "gebucht, nicht nur gemeldet")
	assert_true(Engraving.is_special_id(granted[0].fixed_engraving.id), "ein Sonderposten")
	assert_eq(granted[0].price, 0, "gefunden, nicht gekauft")
	assert_eq(Pack.shelf_of(granted[0]), Pack.SHELF_SPECIAL)

func test_two_encores_pay_twice():
	run.owned_charms.append(Charm.encore())
	run.owned_charms.append(Charm.encore())
	assert_eq(run.apply_encore(9).size(), 2, "je Exemplar ein Paket")
	assert_eq(run.owned_packs.size(), 2)

func test_without_the_encore_nothing_falls():
	assert_eq(run.apply_encore(9).size(), 0)
	assert_eq(run.owned_packs.size(), 0)

# --- Pfandregal: Rundenende-Einnahme aus dem Gravur-Vorrat --------------------------

func test_the_deposit_shelf_pays_per_three_engravings():
	var ids := _ids([Charm.DEPOSIT_SHELF])
	assert_eq(CharmEffects.round_end_income(0, 0, ids, 0, 8), 2, "$1 je volle drei")
	assert_eq(CharmEffects.round_end_income(0, 0, ids, 0, 2), 0)
	assert_eq(CharmEffects.round_end_income(0, 0, ids, 0, 999), CharmEffects.DEPOSIT_SHELF_CAP,
		"gedeckelt bei $15")
	assert_eq(CharmEffects.round_end_income(0, 0, NO_CHARMS, 0, 999), 0)

func test_the_deposit_shelf_names_itself_in_the_ceremony_entries():
	var entries := CharmEffects.round_end_income_entries(0, 0, _ids([Charm.DEPOSIT_SHELF]), 0, 9)
	assert_eq(entries.size(), 1)
	assert_eq(String(entries[0]["charm_id"]), Charm.DEPOSIT_SHELF)
	assert_eq(int(entries[0]["amount"]), 3)

# --- Jackpotglocke: die erste Hand schlägt das Rundenziel ---------------------------

func test_the_jackpot_bell_rings_only_over_the_goal_and_only_first():
	var ids := _ids([Charm.JACKPOT_BELL])
	assert_eq(CharmEffects.jackpot_income(ids, 200, 150, true), CharmEffects.JACKPOT_BELL_MONEY)
	assert_eq(CharmEffects.jackpot_income(ids, 150, 150, true), 0, "gleichauf reicht nicht")
	assert_eq(CharmEffects.jackpot_income(ids, 200, 150, false), 0, "nur die erste Hand")
	assert_eq(CharmEffects.jackpot_income(NO_CHARMS, 200, 150, true), 0)
	assert_eq(CharmEffects.jackpot_income(_ids([Charm.JACKPOT_BELL, Charm.JACKPOT_BELL]), 200, 150, true),
		2 * CharmEffects.JACKPOT_BELL_MONEY)

func test_the_jackpot_bell_measures_against_the_effective_goal():
	run.round_goal = 150
	run.owned_charms.append(Charm.jackpot_bell())
	assert_eq(CharmEffects.jackpot_income(run.charm_ids(), 151, run.effective_goal(), true),
		CharmEffects.JACKPOT_BELL_MONEY)

# --- Stichel: JEDE Rune wirkt doppelt (nur der Einbrand kennt keinen Betrag) --------

func test_the_burin_doubles_the_stray_light():
	var runes := _ids([Rune.STRAY_LIGHT])
	assert_eq(RuneEffects.stray_money(runes), RuneEffects.STRAY_LIGHT_MONEY)
	assert_eq(RuneEffects.stray_money(runes, _ids([Charm.BURIN])), 2)
	assert_eq(RuneEffects.stray_money(_ids([Rune.AFTERGLOW]), _ids([Charm.BURIN])), 0)

func test_the_doubled_stray_light_lands_in_the_take():
	# Der ungewertete Nachbar zeigt seine Streulicht-Seite: $1, mit Stichel $2.
	var idle := _die([1, 2, 3, 4, 5, 6])
	idle.runes[0] = Rune.STRAY_LIGHT
	var report := MaterialEffects.apply_take_effects(_defs([_die([1, 2, 3, 4, 5, 6]), idle]),
		_p([0, 0]), _m(["", ""]), _p([0]), _ids([Charm.BURIN]), -1, {}, _p([0]), false, _p([0, 1]))
	assert_eq(report.money, 2, "Streulicht zahlt doppelt")
	assert_eq(report.stray, _p([1]))

func test_the_burin_doubles_the_afterglow():
	var runes := _ids([Rune.AFTERGLOW])
	assert_eq(RuneEffects.extra_activations(runes), 1)
	assert_eq(RuneEffects.extra_activations(runes, _ids([Charm.BURIN])), 2)
	assert_eq(RuneEffects.extra_activations(_ids([Rune.AFTERGLOW, Rune.AFTERGLOW]),
		_ids([Charm.BURIN])), 4, "je Rune verdoppelt")

func test_the_burin_doubles_the_spark_flight():
	var runes := _ids([Rune.SPARK_FLIGHT])
	assert_eq(RuneEffects.energy_for_take(runes), RuneEffects.SPARK_FLIGHT_ENERGY)
	assert_eq(RuneEffects.energy_for_take(runes, _ids([Charm.BURIN])), 2)
	assert_eq(RuneEffects.energy_for_take(_ids([Rune.STRAY_LIGHT]), _ids([Charm.BURIN])), 0)

func test_the_burin_fires_the_reverse_twice():
	var reverse := _ids([Rune.REVERSE])
	assert_eq(EssenceEffects.det_link_fire_count(0, 5, reverse, NO_CHARMS), 1)
	assert_eq(EssenceEffects.det_link_fire_count(0, 5, reverse, _ids([Charm.BURIN])), 2)
	assert_eq(EssenceEffects.det_link_fire_count(0, 1, reverse, _ids([Charm.BURIN])), 1,
		"eine Nachbarseite ist keine Kehrseite")
	assert_eq(EssenceEffects.det_link_fire_count(0, 5, _ids([]), _ids([Charm.BURIN])), 1,
		"ohne Kehrseite verdoppelt der Stichel nichts")

func test_the_afterglow_activations_land_in_the_score():
	var ctx := {DiceScoring.CTX_RUNES: {0: _ids([Rune.AFTERGLOW])}}
	var plain := DiceScoring.score_category(PAIR, _d([5, 5]), NO_CHARMS, false, _m(["", ""]), {}, ctx)
	var burin := DiceScoring.score_category(PAIR, _d([5, 5]), _ids([Charm.BURIN]), false,
		_m(["", ""]), {}, ctx)
	# Slot 0 zündet dreimal statt zweimal: eine Augenzahl mehr auf der Basis.
	assert_eq(plain, (10 + 5 * 3) * 2)
	assert_eq(burin, (10 + 5 * 4) * 2)

func test_the_doubled_reverse_pays_its_gold_link_twice():
	var def := _die([1, 2, 3, 4, 5, 6])
	def.set_face_material(5, DieMaterial.GOLD)
	def.runes[0] = Rune.REVERSE
	var plain := MaterialEffects.apply_take_effects(_defs([def]), _p([0]), _m([""]), _p([0]),
		NO_CHARMS, -1, {}, _p([0]), false, _p([0]))
	assert_eq(plain.total_money(), MaterialEffects.GOLD_PAYOUT)
	var twin := _die([1, 2, 3, 4, 5, 6])
	twin.set_face_material(5, DieMaterial.GOLD)
	twin.runes[0] = Rune.REVERSE
	var doubled := MaterialEffects.apply_take_effects(_defs([twin]), _p([0]), _m([""]), _p([0]),
		_ids([Charm.BURIN]), -1, {}, _p([0]), false, _p([0]))
	assert_eq(doubled.total_money(), 2 * MaterialEffects.GOLD_PAYOUT, "die Kehrseite zündet zweimal")

# --- Härteofen: veredelte Materialien zahlen doppelt ----------------------------------

func test_the_kiln_only_repeats_the_doped_state():
	assert_eq(MaterialEffects.payoff_repeats(DieMaterial.MAX_LEVEL, _ids([Charm.KILN])), 2)
	assert_eq(MaterialEffects.payoff_repeats(1, _ids([Charm.KILN])), 1, "erst veredelt")
	assert_eq(MaterialEffects.payoff_repeats(DieMaterial.MAX_LEVEL, NO_CHARMS), 1)

func test_the_kiln_doubles_base_and_mult():
	var kiln := _ids([Charm.KILN])
	assert_eq(MaterialEffects.base_once_for(DieMaterial.AMBER, kiln, DieMaterial.MAX_LEVEL, 6),
		2 * MaterialEffects.base_once_for(DieMaterial.AMBER, NO_CHARMS, DieMaterial.MAX_LEVEL, 6))
	assert_eq(MaterialEffects.base_once_for(DieMaterial.AMBER, kiln, 1, 6),
		MaterialEffects.base_once_for(DieMaterial.AMBER, NO_CHARMS, 1, 6), "normal unberührt")
	# Veredelt addiert kein Material mehr von sich aus - der einzige additive Mult,
	# den der Ofen dort verdoppeln kann, sind die Blood-Diamond-Augen.
	var bloody := _ids([Charm.KILN, Charm.BLOOD_DIAMOND])
	assert_eq(MaterialEffects.mult_once_for(DieMaterial.RUBY, 5, bloody, DieMaterial.MAX_LEVEL), 10)
	assert_eq(MaterialEffects.mult_once_for(DieMaterial.RUBY, 5, _ids([Charm.BLOOD_DIAMOND]), DieMaterial.MAX_LEVEL), 5)

func test_the_kiln_doubles_the_growth_but_never_the_cost():
	var kiln := _ids([Charm.KILN])
	var lvl := DieMaterial.MAX_LEVEL
	var grown := MaterialEffects.mutate_value_once(10, DieMaterial.BONE, kiln, lvl)
	var plain := MaterialEffects.mutate_value_once(10, DieMaterial.BONE, NO_CHARMS, lvl)
	assert_gt(grown, plain, "das Wachstum ist eine Auszahlung")
	assert_eq(grown, MaterialEffects.grow_bone_value(plain, lvl, kiln,
		MaterialEffects.bone_trigger_count(kiln)),
		"genau zwei Wachstumsschritte")
	assert_eq(MaterialEffects.mutate_value_once(20, DieMaterial.GLASS, kiln, lvl),
		MaterialEffects.mutate_value_once(20, DieMaterial.GLASS, NO_CHARMS, lvl),
		"das Glas frisst sich weiter im alten Tempo")

func test_the_kiln_crit_strikes_twice_instead_of_squaring_once():
	var ctx := {DiceScoring.CTX_MATERIAL_LEVELS: {0: {"level": DieMaterial.MAX_LEVEL, "eye_sum": 0}}}
	var mats := _m([DieMaterial.RUBY, ""])
	var plain := DiceScoring.score_category(PAIR, _d([5, 5]), NO_CHARMS, false, mats, {}, ctx)
	var kiln := DiceScoring.score_category(PAIR, _d([5, 5]), _ids([Charm.KILN]), false, mats, {}, ctx)
	assert_eq(plain, 20 * 2 * MaterialEffects.RUBY_CRIT)
	assert_eq(kiln, 20 * 2 * MaterialEffects.RUBY_CRIT * MaterialEffects.RUBY_CRIT)

func test_the_breakdown_mirrors_the_doubled_material_steps():
	var ctx := {DiceScoring.CTX_MATERIAL_LEVELS: {0: {"level": DieMaterial.MAX_LEVEL, "eye_sum": 0}}}
	var ids := _ids([Charm.KILN])
	var mats := _m([DieMaterial.RUBY, ""])
	var breakdown := ScoreBreakdown.build(PAIR, _d([5, 5]), ids, false, mats, {}, ctx)
	assert_eq(int(breakdown["total"]),
		DiceScoring.score_category(PAIR, _d([5, 5]), ids, false, mats, {}, ctx))
	var step: Dictionary = breakdown["die_steps"][0]
	var firing: Dictionary = step["die_triggers"][0]["firings"][0]
	assert_eq((firing["crit_steps"] as Array).size(), 2,
		"zwei Schläge wie zwei Beherit-Kopien, nie einer im Quadrat")

func test_the_kiln_pays_its_gold_twice_and_the_def_follows_the_simulation():
	var kiln := _ids([Charm.KILN])
	var gold := _die([4, 2, 3, 4, 5, 6], DieMaterial.GOLD, DieMaterial.MAX_LEVEL)
	var report := MaterialEffects.apply_take_effects(_defs([gold]), _p([0]), _m([DieMaterial.GOLD]),
		_p([0]), kiln, -1, {}, _p([0]), false, _p([0]))
	var plain_die := _die([4, 2, 3, 4, 5, 6], DieMaterial.GOLD, DieMaterial.MAX_LEVEL)
	var plain := MaterialEffects.apply_take_effects(_defs([plain_die]), _p([0]),
		_m([DieMaterial.GOLD]), _p([0]), NO_CHARMS, -1, {}, _p([0]), false, _p([0]))
	assert_eq(report.total_money(), 2 * plain.total_money(), "die Auszahlung läuft zweimal")

func test_the_kiln_keeps_simulation_and_def_byte_identical():
	# Ein veredelter Knochen unter dem Härteofen: die Def muss exakt dort landen,
	# wo value_after_activations sie erwartet (Drift-Doktrin).
	var kiln := _ids([Charm.KILN])
	var bone := _die([8, 2, 3, 4, 5, 6], DieMaterial.BONE, DieMaterial.MAX_LEVEL)
	MaterialEffects.apply_take_effects(_defs([bone]), _p([0]), _m([DieMaterial.BONE]), _p([0]),
		kiln, -1, {}, _p([0]), false, _p([0]))
	var activations := MaterialEffects.total_trigger_count(0, kiln, 8)
	assert_eq(bone.faces[0], MaterialEffects.value_after_activations(8, activations,
		DieMaterial.BONE, kiln, DieMaterial.MAX_LEVEL))

# --- Angebots-Sperren: ein Charm ohne sein Spielzeug ---------------------------------

func test_the_offer_gate_hides_the_charms_without_their_toy():
	var no_souls: Array[String] = []
	var barred := Charm.offerable(Charm.all(), no_souls,
		{Charm.FEATURE_SECRET_SHOP: false, Charm.FEATURE_SLOT_MACHINE: false})
	assert_false(_has_id(barred, Charm.FENCED_GOODS), "kein Hinterzimmer, keine Hehlerware")
	assert_false(_has_id(barred, Charm.FREE_SPIN), "kein Automat, kein Freispiel")
	var open_table := Charm.offerable(Charm.all(), no_souls,
		{Charm.FEATURE_SECRET_SHOP: true, Charm.FEATURE_SLOT_MACHINE: true})
	assert_true(_has_id(open_table, Charm.FENCED_GOODS))
	assert_true(_has_id(open_table, Charm.FREE_SPIN))

func test_the_offer_gate_stays_permissive_without_features():
	var no_souls: Array[String] = []
	var pool := Charm.offerable(Charm.all(), no_souls)
	assert_true(_has_id(pool, Charm.FENCED_GOODS), "wer den Stand nicht kennt, verliert nichts")
	assert_true(_has_id(pool, Charm.FREE_SPIN))

func test_the_run_reports_what_stands_on_the_table():
	var features := run.charm_offer_features()
	assert_false(bool(features[Charm.FEATURE_SECRET_SHOP]))
	assert_false(bool(features[Charm.FEATURE_SLOT_MACHINE]))
	run.hub_level = 3
	assert_true(bool(run.charm_offer_features()[Charm.FEATURE_SLOT_MACHINE]), "Automat I steht")
	run.unlock_secret_shop()
	assert_true(bool(run.charm_offer_features()[Charm.FEATURE_SECRET_SHOP]))

func test_the_back_room_charm_slot_passes_the_gate():
	# Der Schwarzmarkt würfelt seine Charms durch dieselbe Schleuse - sein eigener
	# Stand ist beim Würfeln längst offen.
	run.hub_level = GameRun.SECRET_UNLOCK_HUB_LEVEL
	run.unlock_secret_shop()
	assert_eq(run.secret_stock.size(), 3, "die Auslage steht")

## Versiegelte Fixinhalt-Pakete dieser Gravur im Lager - lose wartet nichts mehr.
func _pack_stock(run: GameRun, id: String) -> int:
	var count := 0
	for pack in run.owned_packs:
		if pack.fixed_engraving != null and pack.fixed_engraving.id == id:
			count += 1
	return count
