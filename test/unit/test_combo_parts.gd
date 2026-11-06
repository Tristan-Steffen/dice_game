extends GutTest
## Steckplätze und Module: jede Wirkung, die feste Reihenfolge der Schritte,
## die Spiegelgleichheit von Wertung, Schrittliste und Nehmen-Effekten und die
## GameRun-Wege (Einbau, Umstecken, Kauf, Schwarzmarkt, Zählwerk, Hitzestau).

const PAIR := DiceScoring.TWO_KIND

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.active_deals.clear()

func _d(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _m(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _ids(values: Array) -> Array[String]:
	return _m(values)

## Paar Fünfer, nur die zwei Würfel: Grundwert (10 + 10 Augen) × 2 = 40.
func _score(parts: Array, ctx: Dictionary = {}) -> int:
	return DiceScoring.score_category(PAIR, _d([5, 5]), _ids([]), false, _m(["", ""]),
		{PAIR: parts}, ctx)

func _breakdown(parts: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	return ScoreBreakdown.build(PAIR, _d([5, 5]), _ids([]), false, _m(["", ""]), parts, ctx)

# --- Katalog -------------------------------------------------------------------

func test_the_catalog_has_fourteen_parts_with_unique_ids():
	var ids: Array[String] = []
	for part in ComboPart.all():
		assert_false(ids.has(part.id), "doppelte id %s" % part.id)
		ids.append(part.id)
		assert_ne(part.display_name, "")
		assert_true(ComboPart.RARITY_WEIGHTS.has(part.rarity))
	assert_eq(ids.size(), 14)

func test_only_the_multiplying_and_legendary_parts_are_secret():
	var secret: Array[String] = []
	for part in ComboPart.pool(true):
		secret.append(part.id)
	secret.sort()
	var expected: Array[String] = [ComboPart.AMPLIFIER_TUBE, ComboPart.COUPLING,
		ComboPart.EXPANSION_BOARD, ComboPart.HIGH_VOLTAGE_TUBE]
	expected.sort()
	assert_eq(secret, expected)

func test_a_shop_roll_never_yields_a_secret_part():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		assert_false(ComboPart.roll_shop(rng).secret)

func test_instantiate_gives_an_own_counter():
	var a := ComboPart.counter_part()
	var b := a.instantiate()
	b.counter = 4
	assert_eq(a.counter, 0, "die Kopie trägt ihren eigenen Stand")

func test_the_cluster_columns_mirror_the_table():
	assert_eq(ComboPartEffects.CLUSTER_COLUMNS, TableScreen.CLUSTER_COLUMNS)

# --- Wirkungen je Teil -----------------------------------------------------------

func test_plain_pair_baseline():
	assert_eq(_score([]), 40)

func test_resistor_capacitor_coil():
	assert_eq(_score([ComboPart.resistor()]), (25 + 10) * 2)
	assert_eq(_score([ComboPart.capacitor()]), 20 * 5)
	assert_eq(_score([ComboPart.coil()]), (18 + 10) * 3)

func test_counter_reads_its_growth():
	var counter := ComboPart.counter_part()
	assert_eq(_score([counter]), 20 * 3)
	counter.counter = 2
	assert_eq(_score([counter]), 20 * 5)

func test_relay_and_output_stage_retrigger_head_and_tail():
	assert_eq(_score([ComboPart.relay()]), (10 + 15) * 2, "der Kopf löst einmal mehr aus")
	assert_eq(_score([ComboPart.output_stage()]), (10 + 15) * 2, "der Schluss ebenso")

func test_two_relays_stack():
	assert_eq(_score([ComboPart.relay(), ComboPart.relay()]), (10 + 20) * 2)

func test_relay_counts_on_the_die_axis():
	var chip: Array = [ComboPart.relay()]
	assert_eq(MaterialEffects.die_trigger_count(0, _ids([]), -1, _ids([]), false, 0, 2, -1,
		false, true, chip, 0, 1), 2)
	assert_eq(MaterialEffects.die_trigger_count(1, _ids([]), -1, _ids([]), false, 0, 2, -1,
		false, true, chip, 0, 1), 1, "nur der Kopf")

func test_solder_joint_and_series_resistor_fire_per_firing():
	assert_eq(_score([ComboPart.solder_joint()]), 20 * 4)
	assert_eq(_score([ComboPart.series_resistor()]), 28 * 2)

func test_die_parts_skip_dice_outside_the_combination():
	# Paar Fünfer mit einer losen 2: der Vollzähler zählt sie, die Kombination nicht.
	var ids := _ids([Charm.FULL_COUNTER])
	var plain := DiceScoring.score_category(PAIR, _d([5, 5, 2]), ids, false, _m(["", "", ""]), {})
	var with_part := DiceScoring.score_category(PAIR, _d([5, 5, 2]), ids, false, _m(["", "", ""]),
		{PAIR: [ComboPart.series_resistor()]})
	assert_eq(plain, (10 + 12) * 2)
	assert_eq(with_part, (10 + 12 + 8) * 2, "nur die zwei Kombinationswürfel bekommen +4")

func test_thermistor_reads_the_live_charge():
	var ctx := {DiceScoring.CTX_CHARGES: {0: 2, 1: 0}}
	# Grundregel +2 Mult (zwei Ladungen), Thermistor +2 je Ladung an Würfel 0.
	assert_eq(_score([], ctx), 20 * 4)
	assert_eq(_score([ComboPart.thermistor()], ctx), 20 * 8)

func test_crit_tubes_multiply():
	assert_eq(_score([ComboPart.amplifier_tube()]), 60)
	assert_eq(_score([ComboPart.high_voltage_tube()]), 80)
	assert_eq(_score([ComboPart.amplifier_tube(), ComboPart.high_voltage_tube()]), 120)

func test_crit_parts_strike_after_the_charge_rule():
	var ctx := {DiceScoring.CTX_CHARGES: {0: 1, 1: 1}}
	assert_eq(_score([ComboPart.high_voltage_tube()], ctx), 20 * 8, "(2 + 2) × 2")

func test_coupling_copies_the_strongest_combo_part_on_its_left():
	assert_eq(ComboPartEffects.left_of(PAIR), DiceScoring.TWO_PAIR)
	assert_eq(ComboPartEffects.left_of(DiceScoring.FOUR_KIND), "", "erste Spalte hat keinen")
	var parts := {
		DiceScoring.TWO_PAIR: [ComboPart.resistor(), ComboPart.capacitor()],
		PAIR: [ComboPart.coupling()],
	}
	assert_eq(DiceScoring.score_category(PAIR, _d([5, 5]), _ids([]), false, _m(["", ""]), parts),
		20 * 5, "der Kondensator (mehr Mult) wird kopiert")
	assert_eq(_score([ComboPart.coupling()]), 40, "ohne Nachbar-Teile nichts")

func test_coin_validator_pays_when_booked():
	run.combo_parts[PAIR] = [ComboPart.coin_validator(), null, null]
	assert_eq(_score([ComboPart.coin_validator()]), 40, "die Wertung bleibt unberührt")
	run.money = 0
	assert_eq(run.book_combo_scored(PAIR), ComboPartEffects.COIN_VALIDATOR_MONEY)
	assert_eq(run.money, ComboPartEffects.COIN_VALIDATOR_MONEY)

func test_the_counter_grows_with_every_scoring():
	run.combo_parts[PAIR] = [ComboPart.counter_part(), null, null]
	run.book_combo_scored(PAIR)
	run.book_combo_scored(PAIR)
	assert_eq((run.parts_of(PAIR)[0] as ComboPart).counter, 2)
	run.book_combo_scored(DiceScoring.THREE_KIND)
	assert_eq((run.parts_of(PAIR)[0] as ComboPart).counter, 2, "nur die eigene Kombination zählt")

func test_the_expansion_board_adds_two_sockets():
	assert_eq(run.socket_count(PAIR), GameRun.SOCKETS_PER_COMBO)
	run.stash_part(ComboPart.expansion_board())
	assert_true(run.install_pending_part(PAIR, 0))
	assert_eq(run.socket_count(PAIR), GameRun.SOCKETS_PER_COMBO + 2, "netto +1 Platz")
	assert_eq(run.parts_of(PAIR).size(), 5)

# --- Reihenfolge und Spiegel -----------------------------------------------------

func test_each_combo_part_is_its_own_step_in_socket_order():
	var parts := {PAIR: [ComboPart.capacitor(), ComboPart.resistor(), ComboPart.coil()]}
	var breakdown := _breakdown(parts)
	var steps: Array = breakdown["part_steps"]
	assert_eq(steps.size(), 3)
	assert_eq(String(steps[0]["part_id"]), ComboPart.CAPACITOR)
	assert_eq(int(steps[1]["slot"]), 1)
	assert_eq(int(steps[2]["base_after"]), 10 + 15 + 8)
	assert_almost_eq(float(steps[2]["mult_after"]), 2.0 + 3.0 + 1.0, 0.0001)

func test_each_crit_part_strikes_alone():
	var parts := {PAIR: [ComboPart.amplifier_tube(), ComboPart.amplifier_tube()]}
	var steps: Array = _breakdown(parts)["part_crit_steps"]
	assert_eq(steps.size(), 2, "zwei Röhren, zwei Schläge")

func test_die_parts_name_their_sockets_in_the_firing():
	var parts := {PAIR: [ComboPart.resistor(), ComboPart.solder_joint()]}
	var step: Dictionary = _breakdown(parts)["die_steps"][0]
	var firing: Dictionary = step["die_triggers"][0]["firings"][0]
	assert_eq(firing["part_slots"], [1])
	assert_eq(int(firing["charm_mult_add"]), 1)

func test_breakdown_totals_match_scoring_with_parts():
	var all_parts: Array = [ComboPart.resistor(), ComboPart.capacitor(), ComboPart.coil(),
		ComboPart.relay(), ComboPart.output_stage(), ComboPart.solder_joint(),
		ComboPart.series_resistor(), ComboPart.thermistor(), ComboPart.amplifier_tube(),
		ComboPart.counter_part(), ComboPart.coin_validator(), ComboPart.high_voltage_tube()]
	var ctx := {DiceScoring.CTX_CHARGES: {0: 1, 1: 2}}
	for a in all_parts.size():
		for b in all_parts.size():
			var parts := {PAIR: [all_parts[a], all_parts[b], ComboPart.relay()],
				DiceScoring.TWO_PAIR: [ComboPart.capacitor()]}
			var bd := ScoreBreakdown.build(PAIR, _d([5, 5]), _ids([]), false, _m(["", ""]), parts, ctx)
			var expected := DiceScoring.score_category(PAIR, _d([5, 5]), _ids([]), false, _m(["", ""]), parts, ctx)
			assert_eq(int(bd["merge_total"]), expected, "%s + %s" % [all_parts[a].id, all_parts[b].id])

func test_trigger_counts_match_between_scoring_and_take():
	# Knochen wächst je Zündung: die Def muss genau dort landen, wo die Schrittliste endet.
	for chip: Array in [[ComboPart.relay()], [ComboPart.output_stage()], [ComboPart.relay(), ComboPart.relay()]]:
		var defs: Array[DieDefinition] = [DieDefinition.standard(), DieDefinition.standard()]
		defs[0].faces[0] = 5
		defs[1].faces[0] = 5
		defs[0].set_face_material(0, DieMaterial.BONE)
		defs[1].set_face_material(0, DieMaterial.BONE)
		var mats := _m([DieMaterial.BONE, DieMaterial.BONE])
		var bd := ScoreBreakdown.build(PAIR, _d([5, 5]), _ids([]), false, mats, {PAIR: chip})
		var order: Array[int] = []
		order.assign(bd["eye_slots"])
		MaterialEffects.apply_take_effects(defs, _d([0, 0]), mats, _d([0, 1]), _ids([]), -1, {},
			order, false, [] as Array[int], 0, 0, [] as Array[DieDefinition], _d([0, 1]), 0,
			[] as Array[int], chip)
		for step: Dictionary in bd["die_steps"]:
			var slot: int = step["slot"]
			var groups: Array = step["die_triggers"]
			var last_group: Dictionary = groups[groups.size() - 1]
			var firings: Array = last_group["firings"]
			assert_eq(defs[slot].faces[0], int(firings[firings.size() - 1]["value_after"]),
				"Slot %d: Wertung und Def zählen gleich oft" % slot)

# --- Einbau, Umstecken, Kauf ------------------------------------------------------

func test_install_puts_the_pending_part_into_the_socket():
	run.stash_part(ComboPart.resistor())
	assert_true(run.install_pending_part(PAIR, 1))
	assert_eq((run.parts_of(PAIR)[1] as ComboPart).id, ComboPart.RESISTOR)
	assert_true(run.pending_parts.is_empty())
	assert_false(run.install_pending_part(PAIR, 0), "nichts mehr wartend")

func test_install_on_an_occupied_socket_swaps():
	run.stash_part(ComboPart.resistor())
	run.install_pending_part(PAIR, 0)
	run.stash_part(ComboPart.capacitor())
	assert_true(run.install_pending_part(PAIR, 0))
	assert_eq((run.parts_of(PAIR)[0] as ComboPart).id, ComboPart.CAPACITOR)
	assert_eq(run.pending_parts.size(), 1, "der Widerstand ist der nächste Einbau")
	assert_eq(run.pending_parts[0].id, ComboPart.RESISTOR)

func test_install_refuses_a_missing_socket():
	run.stash_part(ComboPart.resistor())
	assert_false(run.install_pending_part(PAIR, GameRun.SOCKETS_PER_COMBO))
	assert_false(run.install_pending_part("nonsense", 0))

func test_move_swaps_between_chips():
	run.combo_parts[PAIR] = [ComboPart.resistor(), null, null]
	run.combo_parts[DiceScoring.THREE_KIND] = [ComboPart.capacitor(), null, null]
	assert_true(run.move_part(PAIR, 0, DiceScoring.THREE_KIND, 0))
	assert_eq((run.parts_of(PAIR)[0] as ComboPart).id, ComboPart.CAPACITOR)
	assert_eq((run.parts_of(DiceScoring.THREE_KIND)[0] as ComboPart).id, ComboPart.RESISTOR)
	assert_true(run.move_part(PAIR, 0, PAIR, 2), "innerhalb eines Chips")
	assert_null(run.parts_of(PAIR)[0])
	assert_eq((run.parts_of(PAIR)[2] as ComboPart).id, ComboPart.CAPACITOR)

func test_move_respects_the_edit_window():
	run.combo_parts[PAIR] = [ComboPart.resistor(), null, null]
	assert_false(run.move_part(PAIR, 0, PAIR, 1, false), "Fenster zu - nichts bewegt sich")
	assert_false(run.move_part(PAIR, 1, PAIR, 2), "ein leerer Platz hat nichts umzustecken")

func test_moving_the_expansion_board_away_compacts_or_refuses():
	run.combo_parts[PAIR] = [ComboPart.expansion_board(), null, null, ComboPart.resistor(), null]
	assert_true(run.move_part(PAIR, 0, DiceScoring.THREE_KIND, 0))
	var left := run.parts_of(PAIR)
	assert_eq(left.size(), GameRun.SOCKETS_PER_COMBO)
	assert_eq(ComboPartEffects.part_count(left), 1, "der Widerstand rückt nach vorn")
	run.combo_parts[DiceScoring.FULL_HOUSE] = [ComboPart.expansion_board(), ComboPart.resistor(),
		ComboPart.resistor(), ComboPart.resistor(), ComboPart.resistor()]
	assert_false(run.move_part(DiceScoring.FULL_HOUSE, 0, DiceScoring.SIX_KIND, 0),
		"kein Platz für die übrigen vier")

func test_purchase_pays_and_stashes():
	run.money = 20
	assert_true(run.purchase_part(ComboPart.resistor(), 6))
	assert_eq(run.money, 14)
	assert_eq(run.pending_parts.size(), 1)

func test_purchase_refuses_without_money():
	run.money = 2
	assert_false(run.purchase_part(ComboPart.resistor(), 6))
	assert_eq(run.money, 2)
	assert_true(run.pending_parts.is_empty())

func test_purchase_refuses_when_every_socket_is_spoken_for():
	for key: String in DiceScoring.HAND_PRIORITY:
		run.combo_parts[key] = [ComboPart.resistor(), ComboPart.resistor(), ComboPart.resistor()]
	run.combo_parts[PAIR] = [ComboPart.resistor(), ComboPart.resistor(), null]
	run.money = 100
	assert_eq(run.free_socket_count(), 1)
	run.stash_part(ComboPart.capacitor())
	assert_false(run.parts_room(), "der wartende belegt den letzten Platz schon")
	assert_false(run.purchase_part(ComboPart.resistor(), 6))
	assert_eq(run.money, 100, "nichts abgebucht")

# --- Schwarzmarkt ---------------------------------------------------------------

func test_the_secret_part_offer_is_secret_only_and_priced_in_energy():
	for i in 20:
		var offer := run._secret_part_offer()
		var part: ComboPart = offer[GameRun.OFFER_ITEM]
		assert_true(part.secret)
		assert_eq(int(offer[GameRun.OFFER_PRICE]), GameRun.secret_energy_price(part.price))

func test_buying_a_secret_part_stashes_it():
	run.secret_stock = [run._secret_part_offer()]
	run.energy = 20
	assert_true(run.buy_secret_offer(0))
	assert_eq(run.pending_parts.size(), 1)
	assert_true(run.pending_parts[0].secret)

func test_the_superconductor_cuts_the_energy_price_too():
	var offer := run._secret_part_offer()
	var plain := run.secret_offer_price(offer)
	run.owned_charms.append(Charm.superconductor())
	assert_lte(run.secret_offer_price(offer), plain)
	assert_eq(run.secret_offer_price(offer), CharmEffects.part_price(int(offer[GameRun.OFFER_PRICE]), run.charm_ids()))

# --- Hitzestau ------------------------------------------------------------------

func _sign(ids: Array) -> void:
	var typed: Array[String] = []
	typed.assign(ids)
	run.sign_clauses(typed)

func test_heat_buildup_disables_the_last_live_part_for_the_round():
	_sign([DealClause.HEAT_BUILDUP])
	run.combo_parts[PAIR] = [ComboPart.resistor(), ComboPart.capacitor(), null]
	assert_true(run.apply_heat_buildup(PAIR))
	assert_true(run.is_part_disabled(run.parts_of(PAIR)[1]), "der hinterste belegte Platz zuerst")
	var live: Array = ComboPartEffects.chip(run.scoring_parts(), PAIR)
	assert_null(live[1], "stillgelegt wertet nicht")
	assert_eq(DiceScoring.score_category(PAIR, _d([5, 5]), _ids([]), false, _m(["", ""]),
		run.scoring_parts()), 35 * 2)
	assert_true(run.apply_heat_buildup(PAIR))
	assert_false(run.apply_heat_buildup(PAIR), "alles aus")
	run.apply_round_start_charms()
	assert_true(run.heat_disabled_parts.is_empty(), "die neue Runde startet kalt")

func test_heat_buildup_needs_its_clause():
	run.combo_parts[PAIR] = [ComboPart.resistor(), null, null]
	assert_false(run.apply_heat_buildup(PAIR))

# --- Platinen-Baum ---------------------------------------------------------------

func test_socket_parents_follow_the_risers():
	var parts := [ComboPart.expansion_board(), null, null, ComboPart.expansion_board(), null, null, null]
	var parents := ComboPartEffects.socket_parents(parts, GameRun.SOCKETS_PER_COMBO)
	assert_eq(parents[0], ComboPartEffects.CHIP_SOCKET)
	assert_eq(parents[3], 0, "das erste Paar trägt die erste Platine")
	assert_eq(parents[4], 0)
	assert_eq(parents[5], 3, "das zweite die Platine darauf")

func test_a_riser_left_without_its_carrier_drops_onto_the_chip():
	run.combo_parts[PAIR] = [ComboPart.expansion_board(), null, null,
		ComboPart.expansion_board(), null, ComboPart.resistor(), null]
	assert_true(run.move_part(PAIR, 0, DiceScoring.THREE_KIND, 0))
	var left := run.parts_of(PAIR)
	assert_eq(left.size(), GameRun.SOCKETS_PER_COMBO + 2)
	var parents := ComboPartEffects.socket_parents(left, GameRun.SOCKETS_PER_COMBO)
	for slot in left.size():
		if left[slot] != null:
			assert_ne(parents[slot], ComboPartEffects.UNREACHABLE, "Platz %d hängt am Chip" % slot)
	assert_eq(ComboPartEffects.part_count(left), 2, "nichts geht verloren")
