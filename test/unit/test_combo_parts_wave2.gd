extends GutTest
## Die zweite Modul-Welle: Reihenklemme, Anlasser, Sperrdiode, Stromabnehmer,
## Nebenschluss, Parallelschaltung, Schwingkreis, Magnetron und die Brücken, die
## weitere Kombinationen samt ihrer Module mitzünden.

const PAIR := DiceScoring.TWO_KIND
const FIRST := {DiceScoring.CTX_HANDS_TAKEN: 0}
const LATER := {DiceScoring.CTX_HANDS_TAKEN: 1}

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.active_deals.clear()

func _d(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _m(count: int) -> Array[String]:
	var typed: Array[String] = []
	typed.resize(count)
	typed.fill("")
	return typed

func _key(index: int) -> String:
	return DiceScoring.HAND_PRIORITY[index]

func _score_with(key: String, values: Array, layout: Dictionary, ctx: Dictionary = LATER) -> int:
	return DiceScoring.score_category(key, _d(values), [] as Array[String], false, _m(values.size()), layout, ctx)

## Paar Fünfer: (10 + 10 Augen) × 2 = 40.
func _pair(parts: Array, ctx: Dictionary = LATER) -> int:
	return _score_with(PAIR, [5, 5], {PAIR: parts}, ctx)

func _breakdown(key: String, values: Array, layout: Dictionary, ctx: Dictionary = LATER) -> Dictionary:
	return ScoreBreakdown.build(key, _d(values), [] as Array[String], false, _m(values.size()), layout, ctx)

func test_the_catalog_carries_the_new_parts() -> void:
	assert_eq(ComboPart.all().size(), 26)
	for id in [ComboPart.PARALLEL_CIRCUIT, ComboPart.MAGNETRON, ComboPart.CROSS_BRIDGE, ComboPart.DOWN_BRIDGE]:
		var part := ComboPart.make(id)
		assert_eq(part.rarity, ComboPart.RARITY_LEGENDARY, id)
		assert_true(part.secret, id)
	assert_true(ComboPart.make(ComboPart.RESONATOR).secret)
	for id in [ComboPart.SERIES_TERMINAL, ComboPart.STARTER, ComboPart.BLOCKING_DIODE, ComboPart.POWER_PICKUP, ComboPart.SHUNT]:
		assert_false(ComboPart.make(id).secret, id)

func test_the_series_terminal_counts_every_part_of_its_chip() -> void:
	var parts := [ComboPart.series_terminal(), ComboPart.resistor(), null]
	assert_eq(_pair(parts), (10 + 10 + 15 + 10) * (2 + 2))
	assert_eq(ComboPartEffects.display_values({PAIR: parts}, PAIR), Vector2i(10 + 10 + 15, 2 + 2))

func test_the_starter_only_fires_in_the_first_hand() -> void:
	var parts := [ComboPart.starter(), null, null]
	assert_eq(_pair(parts, FIRST), 20 * (2 + 6))
	assert_eq(_pair(parts, LATER), 40)
	assert_eq(ComboPartEffects.display_values({PAIR: parts}, PAIR), Vector2i(10, 2), "der Chip zeigt nur Sicheres")

func test_the_parallel_circuit_retriggers_every_combination_die() -> void:
	assert_eq(_pair([ComboPart.parallel_circuit(), null, null]), (10 + 10 + 10) * 2)

func test_the_resonator_grows_with_every_scoring() -> void:
	var part := ComboPart.resonator()
	run.combo_parts[PAIR] = [part, null, null]
	assert_almost_eq(ComboPartEffects.resonator_crit(part), 1.1, 0.0001)
	assert_eq(_pair([part, null, null]), ceili(20.0 * 2.0 * 1.1))
	for _i in 9:
		run.book_combo_scored(PAIR)
	assert_almost_eq(ComboPartEffects.resonator_crit(part), 2.0, 0.0001)
	assert_eq(_pair([part, null, null]), 80)

func test_the_magnetron_triples_and_heats_the_combination_dice() -> void:
	assert_eq(_pair([ComboPart.magnetron(), null, null]), 120)
	run.combo_parts[PAIR] = [ComboPart.magnetron(), null, null]
	var inside := DieDefinition.standard()
	var outside := DieDefinition.standard()
	var defs: Array[DieDefinition] = [inside, outside]
	var changes := run.book_magnetrons(PAIR, defs, _d([0]))
	assert_eq(inside.charge, 1)
	assert_eq(outside.charge, 0, "nur Kombinationswürfel")
	assert_eq(changes.size(), 1)
	inside.charge = DieDefinition.CHARGE_MAX
	changes = run.book_magnetrons(PAIR, defs, _d([0]))
	assert_true(inside.burned_out, "an der Spitze brennt er sicher durch")
	assert_true(bool(changes[0]["burned"]))

func test_the_power_pickup_pays_energy_and_overflows_into_money() -> void:
	run.combo_parts[PAIR] = [ComboPart.power_pickup(), null, null]
	run.energy = 0
	assert_eq(run.book_part_energy(PAIR), 1)
	assert_eq(run.energy, 1)
	run.energy = run.energy_cap()
	var money := run.money
	assert_eq(run.book_part_energy(PAIR), 0)
	assert_gt(run.money, money, "was nicht paßt, zahlt bar")

func test_the_blocking_diode_shields_its_chip_from_the_heat_warning() -> void:
	var hot := _key(0)
	run.combo_parts[hot] = [ComboPart.blocking_diode(), ComboPart.resistor(), ComboPart.capacitor()]
	assert_false(run.hottest_combos(1).has(hot), "die Hitzewarnung trifft den nächsten")
	assert_true(run._chip_guarded(hot))

func test_a_fresh_diode_lifts_throttle_and_heat() -> void:
	var resistor := ComboPart.resistor()
	run.combo_parts[PAIR] = [resistor, null, null]
	run.heat_disabled_parts[resistor.get_instance_id()] = true
	run.throttled_combos = [PAIR] as Array[String]
	run.pending_parts.append(ComboPart.blocking_diode())
	assert_true(run.install_pending_part(PAIR, 1))
	assert_false(run.throttled_combos.has(PAIR))
	assert_false(run.is_part_disabled(resistor))

func test_the_shunt_counts_the_dice_beside_the_combination() -> void:
	var values := [5, 5, 2]
	var ctx := LATER.duplicate()
	assert_eq(_score_with(PAIR, values, {}, ctx), 40)
	ctx[DiceScoring.CTX_SHUNTED] = [PAIR]
	assert_eq(_score_with(PAIR, values, {}, ctx), (10 + 12) * 2)
	var shape := DiceScoring.hand_shape(PAIR, _d(values), [] as Array[String], ctx)
	assert_eq((shape["participating"] as Array).size(), 2, "die Kombination bleibt dieselbe")
	assert_eq((shape["scored"] as Array).size(), 3)
	var shunted := ComboPartEffects.shunted_keys({PAIR: [ComboPart.shunt(), null, null]})
	assert_eq(shunted, [PAIR] as Array[String])

func test_neighbours_follow_the_picture() -> void:
	assert_eq(ComboPartEffects.right_of(_key(0)), _key(1))
	assert_eq(ComboPartEffects.right_of(_key(2)), "", "am Reihenende nichts")
	assert_eq(ComboPartEffects.right_of(_key(12)), "")
	assert_eq(ComboPartEffects.below_of(_key(0)), _key(3))
	assert_eq(ComboPartEffects.below_of(_key(10)), _key(12), "die letzte Reihe steht mittig")
	assert_eq(ComboPartEffects.below_of(_key(9)), "")
	assert_eq(ComboPartEffects.below_of(_key(11)), "")
	assert_eq(ComboPartEffects.below_of(_key(12)), "")

func test_a_bridge_scores_the_neighbour_and_its_parts() -> void:
	var key := _key(10)
	var other := _key(11)
	var values := [5, 5, 3, 3]
	var alone := _score_with(key, values, {})
	var layout := {key: [ComboPart.cross_bridge(), null, null], other: [ComboPart.resistor(), null, null]}
	var points := DiceScoring.points_for(key) + DiceScoring.points_for(other) + 15 + 16
	var mult := DiceScoring.mult_for(key) + DiceScoring.mult_for(other)
	assert_gt(points * mult, alone)
	assert_eq(_score_with(key, values, layout), points * mult)
	var breakdown := _breakdown(key, values, layout)
	assert_eq(int(breakdown["total"]), points * mult, "Schrittliste und Wertung gleich")
	assert_eq(breakdown["chain_keys"], [key, other] as Array[String])
	var steps: Array = breakdown["part_steps"]
	assert_true(bool(steps[0]["activated"]))
	assert_eq(String(steps[0]["key"]), other)
	assert_eq(String(steps[1]["part_id"]), ComboPart.RESISTOR)

func test_a_throttled_neighbour_stays_dark() -> void:
	var key := _key(10)
	var layout := {key: [ComboPart.cross_bridge(), null, null]}
	var ctx := LATER.duplicate()
	ctx[DiceScoring.CTX_THROTTLED] = [_key(11)]
	assert_eq(_score_with(key, [5, 5, 3, 3], layout, ctx), _score_with(key, [5, 5, 3, 3], {}))

func test_die_parts_of_the_neighbour_fire_on_the_taken_dice() -> void:
	var key := _key(10)
	var other := _key(11)
	var layout := {key: [ComboPart.cross_bridge(), null, null], other: [ComboPart.solder_joint(), null, null]}
	var breakdown := _breakdown(key, [5, 5, 3, 3], layout)
	var firing: Dictionary = breakdown["die_steps"][0]["die_triggers"][0]["firings"][0]
	assert_eq((firing["part_slots"] as Array).size(), 0, "der eigene Chip blitzt nicht")
	assert_eq((firing["part_foreign"] as Array)[0], {"key": other, "slot": 0})
	assert_eq(int(firing["charm_mult_add"]), 1)

func test_crit_parts_of_the_neighbour_slam_on_its_chip() -> void:
	var key := _key(10)
	var other := _key(11)
	var layout := {key: [ComboPart.cross_bridge(), null, null], other: [ComboPart.magnetron(), null, null]}
	var crits: Array = _breakdown(key, [5, 5, 3, 3], layout)["part_crit_steps"]
	assert_eq(crits.size(), 1)
	assert_eq(String(crits[0]["key"]), other)

func test_scoring_books_the_whole_chain() -> void:
	var key := _key(10)
	var counter := ComboPart.counter_part()
	run.combo_parts[key] = [ComboPart.cross_bridge(), null, null]
	run.combo_parts[_key(11)] = [counter, ComboPart.coin_validator(), null]
	assert_eq(run.book_combo_scored(key), ComboPartEffects.COIN_VALIDATOR_MONEY)
	assert_eq(counter.counter, 1)

## Der Spieler-Fall: mit der richtigen Verdrahtung zündet ein Sechserpasch ALLES.
func test_the_perfect_wiring_reaches_every_combination() -> void:
	var layout := {}
	for index in [0, 1]:
		layout[_key(index)] = [ComboPart.cross_bridge(), ComboPart.down_bridge(), null]
	for index in [2, 3, 4, 5, 6, 7, 8, 10]:
		layout[_key(index)] = [ComboPart.down_bridge(), null, null]
	var chain := ComboPartEffects.chain_keys(layout, _key(0))
	assert_eq(chain.size(), DiceScoring.HAND_PRIORITY.size())
	var seen := {}
	for key in chain:
		seen[key] = true
	assert_eq(seen.size(), chain.size(), "jede höchstens einmal")
	var sum_points := 12
	var sum_mult := 0
	for key: String in DiceScoring.HAND_PRIORITY:
		sum_points += DiceScoring.points_for(key)
		sum_mult += DiceScoring.mult_for(key)
	assert_eq(_score_with(_key(0), [2, 2, 2, 2, 2, 2], layout), sum_points * sum_mult)

func test_new_parts_keep_score_and_breakdown_in_step() -> void:
	var parts := [ComboPart.series_terminal(), ComboPart.starter(), ComboPart.parallel_circuit(),
		ComboPart.resonator(), ComboPart.magnetron(), ComboPart.power_pickup()]
	var layout := {PAIR: parts}
	assert_eq(int(_breakdown(PAIR, [5, 5], layout, FIRST)["total"]), _score_with(PAIR, [5, 5], layout, FIRST))

func test_the_round_log_names_an_activation() -> void:
	var key := _key(10)
	var layout := {key: [ComboPart.cross_bridge(), null, null]}
	var labels: Array[String] = []
	for step in RoundLog.flatten(_breakdown(key, [5, 5, 3, 3], layout), [] as Array[String]):
		labels.append(String(step["label"]))
	assert_true(labels.any(func(l: String) -> bool: return l.contains("%s aktiviert" % DiceScoring.label_for(_key(11)))))
