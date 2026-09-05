extends GutTest
## Die INHALTE der LADUNG (Welle 2): die zehn Charms, die zwei Seelen und die
## sieben Klauseln. Gewürfelt wird nie - die Ladungs-Würfe stehen als
## vorgewürfelte Floats im ctx, genau wie beim Zug.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

func _d(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _ids(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

## Vorgewürfelter Vorrat eines Slots: true = der Wurf trifft, false = daneben.
func _pool(hits: Array) -> Array[float]:
	var pool: Array[float] = []
	for hit in hits:
		pool.append(0.1 if bool(hit) else 0.9)
	return pool

func _score(key: String, dice: Array[int], ctx: Dictionary, charms: Array[String] = []) -> int:
	return DiceScoring.score_category(key, dice, charms, false, [], {}, ctx)

func _build(key: String, dice: Array[int], ctx: Dictionary, charms: Array[String] = []) -> Dictionary:
	return ScoreBreakdown.build(key, dice, charms, false, [], {}, ctx)

func _sign(clause_ids: Array) -> void:
	var typed: Array[String] = []
	typed.assign(clause_ids)
	run.sign_clauses(typed)

func _hot(die: DieDefinition, level: int) -> DieDefinition:
	die.charge = level
	return die

# --- Spannungsmesser -------------------------------------------------------------

func test_the_voltmeter_pays_two_mult_per_charge():
	# Paar aus 4en: Basis 18, Mult 2 + Grundregel 3 - der Messer legt 2 je Ladung drauf.
	var ctx := {DiceScoring.CTX_CHARGES: {0: 2, 1: 1}}
	assert_eq(_score(DiceScoring.TWO_KIND, _d([4, 4]), ctx), 18 * 5, "ohne Charm nur die Grundregel")
	assert_eq(_score(DiceScoring.TWO_KIND, _d([4, 4]), ctx, _ids([Charm.VOLTMETER])),
		18 * (5 + 2 * 3))

func test_the_voltmeter_stacks_per_copy():
	var ctx := {DiceScoring.CTX_CHARGES: {0: 2, 1: 0}}
	var two := _ids([Charm.VOLTMETER, Charm.VOLTMETER])
	assert_eq(_score(DiceScoring.TWO_KIND, _d([4, 4]), ctx, two), 18 * (4 + 2 * 2 * 2))

func test_the_voltmeter_reads_the_living_charges():
	# Beide Würfel laden in dieser Hand von 0 auf 1 - der Messer sieht den END-Stand.
	var ctx := {
		DiceScoring.CTX_CHARGES: {0: 0, 1: 0},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true]), 1: _pool([true])},
	}
	assert_eq(_score(DiceScoring.TWO_KIND, _d([4, 4]), ctx, _ids([Charm.VOLTMETER])),
		18 * (2 + 2 + 4))

func test_a_burned_die_counts_zero_for_the_voltmeter():
	var ctx := {
		DiceScoring.CTX_CHARGES: {0: 2, 1: 2},
		DiceScoring.CTX_BURNED: {1: true},
	}
	# Slot 1 liefert 0 Augen und 0 Ladung: Basis 14, Mult 2 + 2 + 4.
	assert_eq(_score(DiceScoring.TWO_KIND, _d([4, 4]), ctx, _ids([Charm.VOLTMETER])), 14 * 8)

# --- Sicherung -------------------------------------------------------------------

func test_the_fuse_arms_the_rule_until_it_held():
	run.owned_charms.append(Charm.safety_fuse())
	assert_true(bool(run.charge_rule()["fuse_armed"]))
	run.fuse_used_this_round = true
	assert_false(bool(run.charge_rule()["fuse_armed"]), "einmal je Runde")

func test_the_fuse_catches_the_first_forced_burnout():
	run.owned_charms.append(Charm.safety_fuse())
	var first := _hot(run.owned_pool[0], DieDefinition.CHARGE_MAX)
	var second := _hot(run.owned_pool[1], DieDefinition.CHARGE_MAX)
	assert_false(run.charge_up_forced(first), "die Sicherung hält")
	assert_false(first.burned_out)
	assert_eq(first.charge, 0, "er fällt auf 0 statt durchzubrennen")
	assert_true(run.charge_up_forced(second), "nur der ERSTE Durchbrenner")
	assert_true(second.burned_out)

func test_the_fuse_also_holds_inside_the_scoring():
	var rule := DiceScoring.default_charge_rule()
	rule["fuse_armed"] = true
	var ctx := {
		DiceScoring.CTX_CHARGES: {0: 3, 1: 3},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true]), 1: _pool([true])},
		DiceScoring.CTX_CHARGE_RULE: rule,
	}
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	assert_true(bool(breakdown["fuse_used"]))
	assert_eq(int(breakdown["charges_after"][0]), 0, "der erste fällt auf 0")
	assert_eq(breakdown["burned_after"], _d([1]), "der zweite brennt durch")

# --- Kühlkörper ------------------------------------------------------------------

func test_the_heat_sink_caps_at_two_and_forbids_burning():
	run.owned_charms.append(Charm.heat_sink())
	var rule := run.charge_rule()
	assert_eq(int(rule["cap"]), GameRun.HEAT_SINK_CAP)
	assert_false(bool(rule["can_burn"]))

func test_the_heat_sink_never_lowers_a_die_that_already_stands_at_three():
	run.owned_charms.append(Charm.heat_sink())
	var die := _hot(run.owned_pool[0], DieDefinition.CHARGE_MAX)
	assert_false(run.charge_up_forced(die), "er brennt nicht durch")
	assert_eq(die.charge, DieDefinition.CHARGE_MAX, "und fällt auch nicht")
	var warm := _hot(run.owned_pool[1], 1)
	run.charge_up_forced(warm)
	assert_eq(warm.charge, GameRun.HEAT_SINK_CAP)
	run.charge_up_forced(warm)
	assert_eq(warm.charge, GameRun.HEAT_SINK_CAP, "über den Deckel geht nichts")

func test_the_heat_sink_also_caps_the_noise_filter():
	run.owned_charms.append(Charm.heat_sink())
	_hot(run.owned_pool[0], DieDefinition.CHARGE_MAX)
	_sign([DealClause.NOISE_FILTER])
	assert_eq(run.owned_pool[0].charge, 1, "min(1, cap)")

# --- Isolierband -----------------------------------------------------------------

func test_the_tape_swaps_the_repair_price_for_money():
	var burned := run.owned_pool[0]
	burned.burn_out()
	assert_eq(run.repair_price(), {"energy": GameRun.REPAIR_ENERGY})
	run.owned_charms.append(Charm.insulation_tape())
	assert_eq(run.repair_price(), {"money": GameRun.REPAIR_MONEY})
	run.money = 20
	var money_before := run.money
	var energy_before := run.energy
	assert_true(run.repair_die(burned))
	assert_eq(run.money, money_before - GameRun.REPAIR_MONEY)
	assert_eq(run.energy, energy_before, "Energie bleibt liegen")
	assert_false(burned.burned_out)

func test_the_tape_repair_checks_before_it_spends():
	var burned := run.owned_pool[0]
	burned.burn_out()
	run.owned_charms.append(Charm.insulation_tape())
	run.money = GameRun.REPAIR_MONEY - 1
	assert_false(run.repair_die(burned), "zu wenig Geld")
	assert_eq(run.money, GameRun.REPAIR_MONEY - 1, "nichts gebucht")
	assert_true(burned.burned_out)

# --- Lichtbogen ------------------------------------------------------------------

func test_the_arc_flash_pays_per_copy():
	assert_eq(CharmEffects.burnout_base(_ids([])), 0)
	assert_eq(CharmEffects.burnout_base(_ids([Charm.ARC_FLASH])), CharmEffects.ARC_FLASH_BASE)
	assert_eq(CharmEffects.burnout_base(_ids([Charm.ARC_FLASH, Charm.ARC_FLASH])),
		2 * CharmEffects.ARC_FLASH_BASE)

func test_the_arc_flash_fires_when_a_die_burns_in_the_scoring():
	var ctx := {
		DiceScoring.CTX_CHARGES: {0: 3, 1: 0},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true]), 1: _pool([false])},
	}
	var plain := _score(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	var lit := _score(DiceScoring.TWO_KIND, _d([4, 4]), ctx, _ids([Charm.ARC_FLASH]))
	assert_eq(lit - plain, CharmEffects.ARC_FLASH_BASE * 2, "Basis × Mult 2")

func test_the_arc_flash_stays_silent_without_a_burnout():
	var ctx := {DiceScoring.CTX_CHARGES: {0: 0, 1: 0}}
	assert_eq(_score(DiceScoring.TWO_KIND, _d([4, 4]), ctx, _ids([Charm.ARC_FLASH])),
		_score(DiceScoring.TWO_KIND, _d([4, 4]), ctx))

func test_the_breakdown_mirrors_the_arc_flash():
	var ctx := {
		DiceScoring.CTX_CHARGES: {0: 3, 1: 0},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true]), 1: _pool([false])},
	}
	var ids := _ids([Charm.ARC_FLASH])
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx, ids)
	assert_eq(breakdown["merge_total"], _score(DiceScoring.TWO_KIND, _d([4, 4]), ctx, ids))
	var firing: Dictionary = breakdown["die_steps"][0]["die_triggers"][0]["firings"][0]
	assert_true(bool(firing["burned"]))
	assert_eq(int(firing["charm_base_add"]), CharmEffects.ARC_FLASH_BASE)
	assert_eq(firing["die_charm_indices"], _d([0]), "das Dock-Pad blitzt")

# --- Erdung & Dauerbetrieb --------------------------------------------------------

func test_grounding_cools_the_played_dice_too():
	var played := _hot(run.owned_pool[0], 2)
	var spare := _hot(run.owned_pool[1], 2)
	run.note_dice_scored([played], _d([0]))
	assert_eq(run.cool_unplayed_dice().size(), 1, "ohne Erdung nur der ungespielte")
	assert_eq(played.charge, 2)
	assert_eq(spare.charge, 1)
	run.owned_charms.append(Charm.grounding())
	run.cool_unplayed_dice()
	assert_eq(played.charge, 1, "die Erdung erwischt auch den gespielten")

func test_continuous_duty_spares_the_unplayed_dice():
	run.owned_charms.append(Charm.continuous_duty())
	var spare := _hot(run.owned_pool[0], 2)
	assert_true(run.cool_unplayed_dice().is_empty())
	assert_eq(spare.charge, 2)

func test_grounding_and_continuous_duty_split_the_pool():
	# Gespielte entladen (Erdung), ungespielte nicht (Dauerbetrieb).
	run.owned_charms.append(Charm.grounding())
	run.owned_charms.append(Charm.continuous_duty())
	var played := _hot(run.owned_pool[0], 2)
	var spare := _hot(run.owned_pool[1], 2)
	run.note_dice_scored([played], _d([0]))
	var cooled := run.cool_unplayed_dice()
	assert_eq(cooled.size(), 1)
	assert_eq(played.charge, 1)
	assert_eq(spare.charge, 2)

# --- Transformator ----------------------------------------------------------------

func test_the_transformer_crits_only_at_the_top():
	var ids := _ids([Charm.TRANSFORMER])
	assert_almost_eq(CharmEffects.charge_crit_at(0, 2, ids), 1.0, 0.0001)
	assert_almost_eq(CharmEffects.charge_crit_at(0, DieDefinition.CHARGE_MAX, ids),
		CharmEffects.TRANSFORMER_CRIT, 0.0001)
	assert_almost_eq(CharmEffects.charge_crit_at(0, DieDefinition.CHARGE_MAX, _ids([Charm.HOUSE_JOKER])),
		1.0, 0.0001)

func test_the_transformer_doubles_the_hand_of_a_die_on_three():
	# Ohne Würfe bleibt der Stand liegen: Slot 0 steht auf 3, Slot 1 kalt. Der
	# Krit schlägt IN der Würfelphase, also auf den Kombi-Mult 2 - die Grundregel
	# (+3) kommt erst danach dazu: (2 × 2) + 3.
	var ctx := {DiceScoring.CTX_CHARGES: {0: 3, 1: 0}}
	assert_eq(_score(DiceScoring.TWO_KIND, _d([4, 4]), ctx), 18 * 5)
	assert_eq(_score(DiceScoring.TWO_KIND, _d([4, 4]), ctx, _ids([Charm.TRANSFORMER])), 18 * 7)

func test_the_transformer_reads_the_charge_before_the_roll():
	# Der Würfel steigt in dieser Zündung erst auf 3 - der Krit gehört der
	# NÄCHSTEN Zündung, weil der Wurf am Ende sitzt.
	var ctx := {
		DiceScoring.CTX_CHARGES: {0: 2, 1: 0},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true]), 1: _pool([false])},
	}
	# Ladungen danach: 3 und 0 -> Grundregel +3, kein Krit (Stand VOR dem Wurf war 2).
	assert_eq(_score(DiceScoring.TWO_KIND, _d([4, 4]), ctx, _ids([Charm.TRANSFORMER])), 18 * 5)

func test_the_breakdown_mirrors_the_transformer():
	var ctx := {DiceScoring.CTX_CHARGES: {0: 3, 1: 0}}
	var ids := _ids([Charm.TRANSFORMER])
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx, ids)
	assert_eq(breakdown["merge_total"], _score(DiceScoring.TWO_KIND, _d([4, 4]), ctx, ids))
	var firing: Dictionary = breakdown["die_steps"][0]["die_triggers"][0]["firings"][0]
	var steps: Array = firing["crit_steps"]
	assert_eq(steps.size(), 1, "ein eigener Schlag")
	assert_eq(steps[0]["charm_indices"], _d([0]), "mit Dock-Index")

# --- Glutkern ----------------------------------------------------------------------

func test_the_ember_core_turns_the_lowest_burned_slot_into_a_joker():
	var ctx := {DiceScoring.CTX_BURNED: {1: true, 3: true}}
	assert_eq(DiceScoring.wild_slot(ctx), -1, "ohne Charm kein Joker")
	ctx[DiceScoring.CTX_EMBER_CORE] = true
	assert_eq(DiceScoring.wild_slot(ctx), 1, "der NIEDRIGSTE durchgebrannte")

func test_the_ember_core_lifts_the_combination():
	var dice := _d([4, 4, 1, 2, 3, 6])
	var ctx := {DiceScoring.CTX_BURNED: {2: true}}
	assert_false(DiceScoring.qualifies(DiceScoring.THREE_KIND, dice, ctx))
	ctx[DiceScoring.CTX_EMBER_CORE] = true
	assert_true(DiceScoring.qualifies(DiceScoring.THREE_KIND, dice, ctx),
		"der dunkle Würfel gilt als jede Zahl")

func test_the_polar_light_still_wins_the_joker_seat():
	var ctx := {
		DiceScoring.CTX_ESSENCES: {4: Essence.AURORA},
		DiceScoring.CTX_BURNED: {1: true},
		DiceScoring.CTX_EMBER_CORE: true,
	}
	assert_eq(DiceScoring.wild_slot(ctx), 4, "das Unikat zuerst")

func test_the_burned_joker_still_delivers_no_eyes():
	# Er trägt die Kombination, zählt aber 0 Augen (Welle-1-Skip).
	var dice := _d([4, 4, 1])
	var ctx := {DiceScoring.CTX_BURNED: {2: true}, DiceScoring.CTX_EMBER_CORE: true}
	assert_eq(_score(DiceScoring.THREE_KIND, dice, ctx),
		(DiceScoring.points_for(DiceScoring.THREE_KIND) + 8) * DiceScoring.mult_for(DiceScoring.THREE_KIND))

# --- Funkenstrecke & Zündkerze ------------------------------------------------------

func test_the_spark_gap_crits_with_the_charge():
	assert_almost_eq(EssenceEffects.crit_once_for(Essence.SPARK_GAP, 5, 0, 0, 0, _ids([]), 0, false, 0, true, 0),
		1.0, 0.0001, "kalt kein Krit")
	assert_almost_eq(EssenceEffects.crit_once_for(Essence.SPARK_GAP, 5, 0, 0, 0, _ids([]), 0, false, 0, true, 2),
		3.0, 0.0001)
	assert_almost_eq(EssenceEffects.crit_once_for(Essence.SPARK_GAP, 5, 0, 0, 0, _ids([]), 0, false, 0, true, 3),
		4.0, 0.0001)

func test_the_spark_plug_lifts_the_base_by_one():
	var plug := _ids([Charm.SPARK_PLUG])
	assert_almost_eq(EssenceEffects.crit_once_for(Essence.SPARK_GAP, 5, 0, 0, 0, plug, 0, false, 0, true, 0),
		2.0, 0.0001, "auch kalt kritet sie mit Kerze")
	assert_almost_eq(EssenceEffects.crit_once_for(Essence.SPARK_GAP, 5, 0, 0, 0, plug, 0, false, 0, true, 3),
		5.0, 0.0001)

func test_the_spark_plug_is_the_charm_of_the_spark_gap():
	assert_eq(Charm.essence_requirement(Charm.SPARK_PLUG), Essence.SPARK_GAP)

func test_the_spark_gap_crits_inside_the_scoring():
	var ctx := {
		DiceScoring.CTX_CHARGES: {0: 2, 1: 0},
		DiceScoring.CTX_ESSENCES: {0: Essence.SPARK_GAP},
	}
	# Krit ×(1 + 2) auf den Kombi-Mult 2, danach die Grundregel: (2 × 3) + 2.
	assert_eq(_score(DiceScoring.TWO_KIND, _d([4, 4]), ctx), 18 * 8)

# --- Bogenlampe ---------------------------------------------------------------------

func test_the_arc_lamp_is_immune_to_burnout():
	assert_true(EssenceEffects.immune_to_burnout(_ids([Essence.ARC_LAMP])))
	assert_false(EssenceEffects.immune_to_burnout(_ids([Essence.ARGON])))

func test_the_arc_lamp_survives_a_forced_step():
	var die := _hot(run.owned_pool[0], DieDefinition.CHARGE_MAX)
	die.essence_id = Essence.ARC_LAMP
	assert_false(run.charge_up_forced(die))
	assert_false(die.burned_out)
	assert_eq(die.charge, DieDefinition.CHARGE_MAX, "sie bleibt stehen")

func test_the_arc_lamp_survives_the_scoring():
	var ctx := {
		DiceScoring.CTX_CHARGES: {0: 3, 1: 3},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true]), 1: _pool([true])},
		DiceScoring.CTX_ESSENCE_SET: {0: [Essence.ARC_LAMP]},
	}
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	assert_eq(breakdown["burned_after"], _d([1]), "nur der Mitwürfel brennt durch")

func test_both_new_souls_reach_the_normal_trade():
	var ids: Array[String] = []
	for essence in Essence.tradeable():
		ids.append(essence.id)
	assert_true(ids.has(Essence.SPARK_GAP))
	assert_true(ids.has(Essence.ARC_LAMP))

# --- Klauseln -------------------------------------------------------------------------

func test_the_drain_turns_the_step_around():
	_sign([DealClause.DRAIN])
	assert_eq(int(run.charge_rule()["step"]), -1)
	run.owned_charms.append(Charm.shyster())
	assert_eq(int(run.charge_rule()["step"]), -2, "der Winkeladvokat verdoppelt")

func test_the_drain_lowers_the_charge_per_firing():
	var rule := DiceScoring.default_charge_rule()
	rule["step"] = -1
	var ctx := {DiceScoring.CTX_CHARGES: {0: 2, 1: 2}, DiceScoring.CTX_CHARGE_RULE: rule}
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	assert_eq(int(breakdown["charges_after"][0]), 1, "ohne Wurf, sicher")
	assert_eq(int(breakdown["charges_after"][1]), 1)

func test_the_cooling_break_forbids_burning():
	_sign([DealClause.COOLING_BREAK])
	assert_false(bool(run.charge_rule()["can_burn"]))
	var die := _hot(run.owned_pool[0], DieDefinition.CHARGE_MAX)
	assert_false(run.charge_up_forced(die), "die Pause deckelt")
	assert_false(die.burned_out)

func test_the_noise_filter_sets_the_whole_pool_to_one():
	_hot(run.owned_pool[0], DieDefinition.CHARGE_MAX)
	_hot(run.owned_pool[1], 0)
	var burned := run.owned_pool[2]
	burned.burn_out()
	_sign([DealClause.NOISE_FILTER])
	assert_eq(run.owned_pool[0].charge, 1, "auch von 3 herunter")
	assert_eq(run.owned_pool[1].charge, 1, "und von 0 herauf")
	assert_true(burned.burned_out, "der Dunkle bleibt dunkel")
	assert_eq(burned.charge, 0)

func test_the_overload_makes_every_roll_hit():
	_sign([DealClause.OVERLOAD])
	assert_almost_eq(float(run.charge_rule()["chance"]), GameRun.FORCED_CHARGE_CHANCE, 0.0001)

func test_the_standing_current_keeps_the_spares_hot():
	_sign([DealClause.STANDING_CURRENT])
	var spare := _hot(run.owned_pool[0], 2)
	assert_true(run.cool_unplayed_dice().is_empty())
	assert_eq(spare.charge, 2)

func test_the_maintenance_contract_locks_the_bay_until_the_next_round_is_committed():
	run.round_number = 3
	_sign([DealClause.MAINTENANCE_CONTRACT])
	assert_eq(run.repair_lock_round, 4)
	assert_true(run.repair_locked(), "schon in der Runde der Unterschrift")
	run.note_round_committed()
	assert_true(run.repair_locked(), "das Zurren von Runde 3 löst sie nicht")
	run.round_number = 4
	assert_true(run.repair_locked(), "auch im Fenster davor")
	run.note_round_committed()
	assert_false(run.repair_locked(), "das Zurren von Runde 4 macht sie frei")

func test_a_locked_bay_books_nothing():
	var burned := run.owned_pool[0]
	burned.burn_out()
	_hot(run.owned_pool[1], 2)
	_sign([DealClause.MAINTENANCE_CONTRACT])
	var energy_before := run.energy
	assert_false(run.repair_die(burned))
	assert_false(run.drain_die(run.owned_pool[1]))
	assert_false(run.discharge_all())
	assert_eq(run.energy, energy_before)

func test_the_power_failure_lies_in_the_boss_pool():
	var boss := DealClause.ids_for(DealClause.Tier.BOSS, DealClause.Kind.MALUS)
	assert_true(boss.has(DealClause.POWER_FAILURE))
	_sign([DealClause.POWER_FAILURE])
	assert_almost_eq(float(run.charge_rule()["chance"]), GameRun.FORCED_CHARGE_CHANCE, 0.0001)

func test_every_charge_clause_carries_the_charge_tag():
	for clause_id in [DealClause.DRAIN, DealClause.COOLING_BREAK, DealClause.NOISE_FILTER,
			DealClause.OVERLOAD, DealClause.STANDING_CURRENT, DealClause.MAINTENANCE_CONTRACT,
			DealClause.POWER_FAILURE]:
		assert_true(DealClause.tags_of(clause_id).has(DealClause.TAG_CHARGE), clause_id)
	assert_true(DealClause.TAG_COLORS.has(DealClause.TAG_CHARGE), "eigene Farbe")
	assert_ne(DealClause.TAG_COLORS[DealClause.TAG_CHARGE], DealClause.TAG_COLORS[DealClause.TAG_ENERGY],
		"nicht das Energie-Cyan")
