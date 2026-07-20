extends GutTest
## Tier-1-Tests der Effektkatalog-Charms (siehe Obsidian "12 Charms -
## Effektkatalog" / CharmEffects): Augenwerte, Basis-/Mult-/Flat-Boni mit
## Wurf-Kontext (ctx), Faktoren, Material-Verstärker, Geld-/Shop-Hooks,
## Totem-Auflösung und die Runden-Wirkungen im GameRun.

func _d(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _ids(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _m(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _p(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

const PAIR := [5, 5, 1, 2, 3, 6]  # Paar Fünfer: Basis (10 Punkte + 10 Augen), Mult 2 -> 40
const NO_MATS: Array[String] = []

# --- Augenwerte -------------------------------------------------------------------

func test_small_fry_boosts_ones_and_twos():
	assert_eq(CharmEffects.eye_value(1, _ids([Charm.SMALL_FRY])), 3)
	assert_eq(CharmEffects.eye_value(2, _ids([Charm.SMALL_FRY])), 4)
	assert_eq(CharmEffects.eye_value(5, _ids([Charm.SMALL_FRY])), 5)

func test_equalizer_floors_at_five_regardless_of_order():
	assert_eq(CharmEffects.eye_value(1, _ids([Charm.EQUALIZER])), 5)
	assert_eq(CharmEffects.eye_value(4, _ids([Charm.EQUALIZER])), 5)
	assert_eq(CharmEffects.eye_value(6, _ids([Charm.EQUALIZER])), 6)
	# Reihenfolge-unabhängig: Glückszigaretten (1 -> 6) gewinnen in beiden Ordnungen.
	assert_eq(CharmEffects.eye_value(1, _ids([Charm.LUCKY_CIGARETTES, Charm.EQUALIZER])),
		CharmEffects.eye_value(1, _ids([Charm.EQUALIZER, Charm.LUCKY_CIGARETTES])))

# --- Basis-Boni --------------------------------------------------------------------

func test_echo_chamber_counts_highest_die_again():
	var bonus := CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), _ids([Charm.ECHO_CHAMBER]))
	assert_eq(bonus, 6, "höchster Würfel (6) zählt erneut")

func test_twin_ring_adds_pair_value_to_mult():
	var bonus := CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.TWIN_RING]))
	assert_eq(bonus, 5, "nur die 5 liegt genau zweimal: +5 Mult")
	var two_pairs := CharmEffects.charm_mult_bonus(DiceScoring.TWO_PAIR, _d([5, 5, 3, 3, 1, 6]), NO_MATS, _ids([Charm.TWIN_RING]))
	assert_eq(two_pairs, 8, "zwei Paare (5 und 3): +8 Mult")

func test_double_six_adds_mult_beyond_second_six():
	var bonus := CharmEffects.charm_mult_bonus(DiceScoring.FOUR_KIND, _d([6, 6, 6, 6, 2, 3]), NO_MATS, _ids([Charm.DOUBLE_SIX]), {}, {}, _p([0, 1, 2, 3]))
	assert_eq(bonus, 2, "vier beteiligte Sechser: die 3. und 4. geben je +1 Mult")
	var pair_only := CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d([6, 6, 1, 2, 3, 4]), NO_MATS, _ids([Charm.DOUBLE_SIX]), {}, {}, _p([0, 1]))
	assert_eq(pair_only, 0, "bis zur zweiten 6 passiert nichts")

func test_street_sweeper_only_boosts_straights():
	var straight := _d([1, 2, 3, 4, 5, 3])
	var bonus := CharmEffects.charm_base_bonus(DiceScoring.SMALL_STRAIGHT, straight, _p([0, 1, 2, 3, 4]), _ids([Charm.STREET_SWEEPER]))
	assert_eq(bonus, 30, "+6 je Straßen-Würfel")
	assert_eq(CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), _ids([Charm.STREET_SWEEPER])), 0)

func test_full_counter_adds_non_participating_dice():
	var bonus := CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), _ids([Charm.FULL_COUNTER]))
	assert_eq(bonus, 12, "1+2+3+6 außerhalb der Kombination")

func test_broadband_pays_per_combination_die():
	var bonus := CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), _ids([Charm.BROADBAND]))
	assert_eq(bonus, 10)

func test_straggler_needs_the_last_die_in_the_combo():
	var in_combo := CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), _ids([Charm.STRAGGLER]), {"last_settled": 0})
	assert_eq(in_combo, 5, "Nachzügler-5 zählt doppelt")
	var outside := CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), _ids([Charm.STRAGGLER]), {"last_settled": 3})
	assert_eq(outside, 0, "unbeteiligter Nachzügler zählt nicht")

func test_sediment_boosts_late_drawn_dice():
	var bonus := CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), _ids([Charm.SEDIMENT]), {"late_slots": [0, 5]})
	assert_eq(bonus, 5, "nur Slot 0 ist beteiligt UND spät gezogen")

func test_edge_gleam_scales_with_edge_dice_count():
	var edges := _m([DieMaterial.GOLD, DieMaterial.GOLD, "", "", "", ""])
	var bonus := CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), _ids([Charm.EDGE_GLEAM]), {}, NO_MATS, edges)
	assert_eq(bonus, 4, "zwei Kanten-Würfel, beide beteiligt: je +2")

# --- Mult-Boni ---------------------------------------------------------------------

func test_pendulum_swings_up_but_never_below_zero():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.PENDULUM]), {"rerolled": 3, "taken_dice": 2}), 4)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.PENDULUM]), {"rerolled": 0, "taken_dice": 6}), 0, "fällt nie unter 0")

func test_all_or_nothing_stacks_full_rerolls():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.ALL_OR_NOTHING]), {"full_rerolls": 1}), 5)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.ALL_OR_NOTHING]), {"full_rerolls": 3}), 15, "stapelt bis zum Nehmen")
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.ALL_OR_NOTHING]), {}), 0)

func test_momentum_follows_the_streak():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.MOMENTUM]), {"streak": 3}), 3)

func test_broken_mirror_stacks_with_farkles():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.BROKEN_MIRROR]), {"farkle_stacks": 4}), 4)

func test_parity_charms_check_the_whole_roll():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d([2, 2, 4, 6, 6, 4]), NO_MATS, _ids([Charm.EVEN_COMPANY])), 6)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.EVEN_COMPANY])), 0)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d([1, 1, 3, 5, 5, 3]), NO_MATS, _ids([Charm.ODD_PATH])), 5)

func test_hermit_crab_wants_few_charms():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.HERMIT_CRAB])), 6)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.HERMIT_CRAB, Charm.HORSESHOE, Charm.LADYBUG])), 0, "drei Charms sind zu viele")

func test_display_case_counts_face_up_materials():
	var materials := _m(["", "", DieMaterial.RUBY, DieMaterial.AMBER, "", ""])
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), materials, _ids([Charm.DISPLAY_CASE])), 2)

func test_lighthouse_mult_follows_highest_value():
	# Höchste Zahl 4: Mult 1 + 4 = 5, Basis (5 Punkte + 4 Augen) -> 45.
	var score := DiceScoring.score_category(DiceScoring.ONE_KIND, _d([1, 2, 3, 1, 2, 4]), _ids([Charm.LIGHTHOUSE]))
	assert_eq(score, 45, "Basis (5+4) × Mult (1+4)")

# --- Krit (multipliziert den Mult, siehe CharmEffects.crit_bonus) --------------------

func test_gallows_humor_gives_crit_after_a_farkle():
	assert_eq(CharmEffects.crit_bonus(DiceScoring.TWO_KIND, _ids([Charm.GALLOWS_HUMOR]), {"after_farkle": true}), 3)
	assert_eq(CharmEffects.crit_bonus(DiceScoring.TWO_KIND, _ids([Charm.GALLOWS_HUMOR]), {"after_farkle": false}), 0)
	# Ende-zu-Ende: Paar Fünfer, Mult 2 × (1 + 3 Krit) = 8 -> Basis 20 × 8 = 160.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.GALLOWS_HUMOR]), false, NO_MATS, NO_MATS, {}, {"after_farkle": true})
	assert_eq(score, 160)

func test_gallows_humor_crit_after_farkle():
	# Galgenhumor gibt nur nach einem Farkle +3 in den Krit-Pool.
	var ids := _ids([Charm.GALLOWS_HUMOR])
	assert_eq(CharmEffects.crit_bonus(DiceScoring.TWO_KIND, ids, {"after_farkle": true}), 3)
	assert_eq(CharmEffects.crit_bonus(DiceScoring.TWO_KIND, ids, {"after_farkle": false}), 0, "ohne Farkle kein Krit")

# --- Basis-Boni & Faktoren -----------------------------------------------------------

func test_blackjack_pays_50_bonus_eyes_on_sum_21():
	var dice := _d([6, 6, 1, 2, 2, 4])  # Summe des Wurfs = 21
	assert_eq(CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, dice, _p([0, 1]), _ids([Charm.BLACKJACK])), 50)
	assert_eq(CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), _ids([Charm.BLACKJACK])), 0, "Summe 22 zahlt nicht")

func test_snake_eyes_converts_bystanders_to_mult():
	# Genau ein 1er-Paar genommen: Mult += Augensumme der Unbeteiligten (3+4+5+6).
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d([1, 1, 3, 4, 5, 6]), NO_MATS, _ids([Charm.SNAKE_EYES]), {}, {}, _p([0, 1])), 18)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d([5, 5, 3, 4, 1, 6]), NO_MATS, _ids([Charm.SNAKE_EYES]), {}, {}, _p([0, 1])), 0, "ein 5er-Paar sind keine Snake Eyes")

func test_alloy_doubles_material_effects_of_dual_carriers():
	# Gold-Seite oben UND Gold-Kanten: die Legierung lässt den Nehmen-Effekt
	# der Gold-Seite doppelt feuern ($2 statt $1).
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]), _m([DieMaterial.GOLD]), _ids([Charm.ALLOY]))
	assert_eq(report.money, 2, "Seiten-Gold zahlt doppelt")
	# Ohne Kanten-Material bleibt alles einfach.
	var single: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var single_report := MaterialEffects.apply_take_effects(single, _p([0]), _m([DieMaterial.GOLD]), _p([0]), NO_MATS, _ids([Charm.ALLOY]))
	assert_eq(single_report.money, 1)

func test_cult_of_one_doubles_base_and_mult_per_one():
	# Paar Fünfer mit EINER 1: Basis 20×2 × Mult 2×2 = 160.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.CULT_OF_ONE]))
	assert_eq(score, 160)

func test_after_work_beer_doubles_the_last_hand():
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.AFTER_WORK_BEER]), false, NO_MATS, NO_MATS, {}, {"last_hand": true})
	assert_eq(score, 80)

func test_round_number_rewards_hand_sum_ending_on_zero():
	# Paar Fünfer: Augensumme der Kombination = 10 -> +100 Bonus-Augen: (10+10+100)×2.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.ROUND_NUMBER]))
	assert_eq(score, 240)
	var no_zero := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([4, 4, 1, 2, 3, 6]), _ids([Charm.ROUND_NUMBER]))
	assert_eq(no_zero, 36, "Augensumme 8 endet nicht auf 0")

# --- Material-Verstärker -------------------------------------------------------------

func test_amber_room_boosts_amber_to_fifty():
	var bonus := MaterialEffects.base_bonus(_d(PAIR), _m([DieMaterial.AMBER, "", "", "", "", ""]), _p([0, 1]), _ids([Charm.AMBER_ROOM]))
	assert_eq(bonus, 50)

func test_ruby_grinder_boosts_ruby_to_ten():
	var bonus := MaterialEffects.mult_bonus(_d(PAIR), _m([DieMaterial.RUBY, "", "", "", "", ""]), _p([0, 1]), NO_MATS, _ids([Charm.RUBY_GRINDER]))
	assert_eq(bonus, 10)

func test_mercury_vapor_triples_mercury():
	var bonus := MaterialEffects.base_bonus(_d(PAIR), _m([DieMaterial.MERCURY, "", "", "", "", ""]), _p([0, 1]), _ids([Charm.MERCURY_VAPOR]))
	assert_eq(bonus, 10, "5 zählt zwei ZUSÄTZLICHE Male (Faktor 3)")

func test_goldsmith_and_bone_glue_strengthen_takes():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m([DieMaterial.GOLD, DieMaterial.BONE]), _p([0, 1]), NO_MATS, _ids([Charm.GOLDSMITH, Charm.BONE_GLUE]))
	assert_eq(report.money, 2, "Goldschmied zahlt $2")
	assert_eq(defs[1].faces[0], 7, "Knochenleim wächst +2")

func test_glassblower_lung_protects_low_faces():
	var defs: Array[DieDefinition] = [_die([3, 2, 3, 4, 5, 6])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]), NO_MATS, _ids([Charm.GLASSBLOWER_LUNG]))
	assert_eq(defs[0].faces[0], 3, "unter 3 schrumpft nichts mehr")

func test_frame_gilder_doubles_edge_gold():
	var edges := _m([DieMaterial.GOLD, "", DieMaterial.GOLD, "", "", ""])
	assert_eq(MaterialEffects.roll_money(edges, _p([0, 1, 2, 3, 4, 5]), _ids([Charm.FRAME_GILDER])), 4)

func _die(faces: Array) -> DieDefinition:
	var def := DieDefinition.new()
	var typed: Array[int] = []
	typed.assign(faces)
	def.faces = typed
	return def

# --- Geld-Hooks -----------------------------------------------------------------------

func test_take_and_farkle_incomes():
	assert_eq(CharmEffects.take_income(_ids([Charm.STREET_MUSICIAN]), 3), 3, "$1 je beteiligtem Würfel")
	assert_eq(CharmEffects.farkle_shard_income(6, _ids([Charm.SHARD_COURT])), 12, "$2 je verworfenem Würfel")
	assert_true(CharmEffects.gold_rush_applies(_ids([Charm.GOLD_RUSH]), 6, 6))
	assert_false(CharmEffects.gold_rush_applies(_ids([Charm.GOLD_RUSH]), 5, 6))
	assert_true(CharmEffects.gold_rush_applies(_ids([Charm.GOLD_RUSH]), 5, 5), "alle LIEGENDEN Würfel zählen, nicht fix 6")

func test_rag_collector_counts_lucky_values():
	assert_eq(CharmEffects.rag_collector_income(_d([4, 4, 1, 4, 2, 3]), 4, _ids([Charm.RAG_COLLECTOR])), 12, "$4 je Treffer")
	assert_eq(CharmEffects.rag_collector_income(_d([4, 4, 1, 4, 2, 3]), 0, _ids([Charm.RAG_COLLECTOR])), 0, "ohne Glückszahl kein Geld")

func test_round_end_income_combines_sources_with_caps():
	# Zinsgroschen: $37 -> +3; Überflieger: 60 über Ziel -> +2.
	var ids := _ids([Charm.INTEREST_PENNY, Charm.HIGH_FLYER])
	assert_eq(CharmEffects.round_end_income(37, 60, ids), 5)
	assert_eq(CharmEffects.round_end_income(9, 10, ids), 0)
	# Beide Quellen sind bei $50 gedeckelt.
	assert_eq(CharmEffects.round_end_income(10000, 100000, ids), 100, "je Quelle max. $50")

func test_money_floor_only_with_emergency_fund():
	assert_eq(CharmEffects.money_floor(_ids([Charm.EMERGENCY_FUND])), 25)
	assert_eq(CharmEffects.money_floor(_ids([Charm.HORSESHOE])), 0)

# --- Farkle-Hooks -----------------------------------------------------------------------

func test_anchor_saves_only_the_first_reroll():
	assert_true(CharmEffects.anchor_saves(_ids([Charm.ANCHOR]), 1))
	assert_false(CharmEffects.anchor_saves(_ids([Charm.ANCHOR]), 2))
	assert_false(CharmEffects.anchor_saves(_ids([Charm.HORSESHOE]), 1))

# --- Shop-Hooks -------------------------------------------------------------------------

func test_shop_price_hooks():
	assert_eq(CharmEffects.charm_price(25, _ids([Charm.CASH_DISCOUNT])), 20)
	assert_eq(CharmEffects.flip_fee(2, _ids([Charm.SMALL_CHANGE])), 1)
	assert_eq(CharmEffects.flip_fee(1, _ids([Charm.SMALL_CHANGE])), 1, "nie unter $1")
	assert_eq(CharmEffects.pack_price(10, "general", _ids([Charm.BARGAIN_HUNTER])), 8)
	assert_eq(CharmEffects.die_price(15, _ids([Charm.BULK_DISCOUNT]), 3), 10)
	assert_eq(CharmEffects.die_price(15, _ids([Charm.BULK_DISCOUNT]), 1), 15, "kein Rabatt auf Einzelwürfel")
	assert_eq(CharmEffects.chip_coupon_value(1, _ids([Charm.DOUBLE_PERFORATION])), 2)
	assert_almost_eq(CharmEffects.pack_refund_chance(_ids([Charm.FINE_PRINT])), 0.2, 0.001)

func test_seal_of_quality_forces_refinements():
	for offer in DiceOffer.roll_offers(DiceOffer.TEMPLATES.size(), _ids([Charm.SEAL_OF_QUALITY])):
		var die := offer.dice[0]
		var refined: bool = die.edge_material != "" or die.materials.count("") < die.materials.size()
		assert_true(refined, "%s kommt veredelt" % offer.display_name)

# --- GameRun: Totems, Stammgast, Rundenbeginn ---------------------------------------------

func test_parrot_totem_copies_left_neighbor():
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.rabbits_foot())
	run.owned_charms.append(Charm.parrot_totem())
	assert_eq(run.charm_ids(), ["rabbits_foot", "rabbits_foot"])

func test_echo_totem_copies_right_neighbor():
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.echo_totem())
	run.owned_charms.append(Charm.horseshoe())
	assert_eq(run.charm_ids(), ["horseshoe", "horseshoe"])

func test_totems_do_not_copy_totems_or_nothing():
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.parrot_totem())  # links ist nichts
	run.owned_charms.append(Charm.echo_totem())  # rechts ist nichts
	assert_eq(run.charm_ids(), [], "Totems ohne kopierbare Nachbarn sind wirkungslos")
	assert_eq(run.owned_charm_ids(), ["parrot_totem", "echo_totem"], "die rohen ids bleiben sichtbar")

func test_round_start_charms_grant_their_gifts():
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.stamp_machine())
	run.gravierstift_used_this_round = true
	run.apply_round_start_charms()
	assert_false(run.gravierstift_used_this_round, "Gravierstift-Marke zurückgesetzt")
	assert_eq(run.owned_engravings.size(), 3, "Frankiermaschine schenkt drei Gravuren")
	for engraving in run.owned_engravings:
		assert_eq(engraving.category, Engraving.CATEGORY_NUMBER)

func test_jewelry_box_upgrades_unused_dice_at_payout():
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.jewelry_box())
	# 10% je Würfel: bei 300 Würfeln ist "keiner veredelt" praktisch ausgeschlossen.
	var many: Array[DieDefinition] = []
	for i in 300:
		many.append(DieDefinition.standard())
	var upgraded := run.apply_jewelry_box(many)
	assert_gt(upgraded, 0, "bei 300 Würfeln veredelt das Schmuckkästchen praktisch sicher")
	var material_faces := 0
	for def in many:
		material_faces += def.materials.size() - def.materials.count("")
	assert_eq(material_faces, upgraded, "jede Veredelung sitzt auf genau einer Seite")
	assert_eq(run.apply_jewelry_box([] as Array[DieDefinition]), 0, "ohne übrige Würfel passiert nichts")

func test_jewelry_box_does_nothing_without_the_charm():
	var run := GameRun.new_run()
	var many: Array[DieDefinition] = []
	for i in 50:
		many.append(DieDefinition.standard())
	assert_eq(run.apply_jewelry_box(many), 0)

func test_rag_collector_rolls_lucky_value_on_purchase():
	var run := GameRun.new_run()
	run.money = 50
	run.purchase_charm(Charm.rag_collector(), 25)
	assert_between(run.lumpensammler_value, 1, 6)

func test_rag_collector_rerolls_lucky_value_each_round():
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.rag_collector())
	run.apply_round_start_charms()
	assert_between(run.lumpensammler_value, 1, 6, "die Glückszahl wird jede Runde (neu) gewürfelt")

# --- Stapelung je Vorkommen (der Mechanismus hinter den Totems) --------------------

func test_additive_bonuses_stack_per_occurrence():
	# Genau das machen die Totems: dieselbe id liegt zweimal in der Liste.
	var twice := _ids([Charm.BROADBAND, Charm.BROADBAND])
	assert_eq(CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), twice), 20)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.MOMENTUM, Charm.MOMENTUM]), {"streak": 3}), 6)
	assert_eq(CharmEffects.round_end_income(30, 0, _ids([Charm.INTEREST_PENNY, Charm.INTEREST_PENNY])), 6)
	assert_eq(CharmEffects.take_income(_ids([Charm.STREET_MUSICIAN, Charm.STREET_MUSICIAN]), 2), 4)

func test_totem_copy_actually_doubles_a_scoring_charm():
	# Ende-zu-Ende: Papagei neben Breitband -> +10 Basis wird +20.
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.broadband())
	run.owned_charms.append(Charm.parrot_totem())
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), run.charm_ids())
	assert_eq(score, 80, "(10 Punkte + 10 Augen + 2×10) × 2")

func test_totem_chain_resolves_each_neighbor_independently():
	# [Breitband, Papagei, Echo, Hufeisen]: Papagei kopiert links (Breitband),
	# Echo kopiert rechts (Hufeisen).
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.broadband())
	run.owned_charms.append(Charm.parrot_totem())
	run.owned_charms.append(Charm.echo_totem())
	run.owned_charms.append(Charm.horseshoe())
	assert_eq(run.charm_ids(), ["broadband", "broadband", "horseshoe", "horseshoe"])

# --- Zusammenspiel mit Augenwert-Charms ---------------------------------------------

func test_echo_chamber_respects_eye_charms():
	# Hasenpfote verdoppelt die 6 - auch beim Echo-Nachzählen.
	var bonus := CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), _ids([Charm.ECHO_CHAMBER, Charm.RABBITS_FOOT]))
	assert_eq(bonus, 12, "höchster Würfel (6) zählt als 12 erneut")

func test_full_counter_respects_eye_charms():
	# Glückszigaretten: die unbeteiligte 1 zählt als 6.
	var bonus := CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), _ids([Charm.FULL_COUNTER, Charm.LUCKY_CIGARETTES]))
	assert_eq(bonus, 17, "6+2+3+6 statt 1+2+3+6")

# --- Kombinierte Shop-Preise ---------------------------------------------------------

func test_refund_chance_caps_at_eighty_percent():
	var five := _ids([Charm.FINE_PRINT, Charm.FINE_PRINT, Charm.FINE_PRINT, Charm.FINE_PRINT, Charm.FINE_PRINT])
	assert_almost_eq(CharmEffects.pack_refund_chance(five), 0.8, 0.001)

# --- GameRun: Frische Ware / Kauf-Verfolgung ------------------------------------------

func test_purchases_are_tracked_as_fresh_pool_instances():
	var run := GameRun.new_run()
	run.money = 100
	var offer_die := DieDefinition.fixed(6, "Sechser")
	var bundle: Array[DieDefinition] = [offer_die, offer_die.instantiate()]
	run.purchase_dice(bundle, 20)
	assert_eq(run.newly_purchased.size(), 2)
	for fresh in run.newly_purchased:
		assert_true(run.owned_pool.has(fresh), "frische Referenz IST die Pool-Instanz")

# --- Wertungs-Reihenfolge: Bonus-Augen vor Faktoren --------------------------------

func test_round_number_bonus_is_multiplied_by_hand_factor():
	# Runde Sache legt +100 auf den Basiswert (20 -> 120), Paar-Mult 2 -> 240,
	# Feierabendbier verdoppelt die ganze Hand -> 480.
	var ids := _ids([Charm.AFTER_WORK_BEER, Charm.ROUND_NUMBER])
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids, false, NO_MATS, NO_MATS, {}, {"last_hand": true})
	assert_eq(score, 480)

# --- Raritäten (siehe Obsidian "12 Charms": Abschnitt "Raritäten") -------------

func test_every_charm_has_an_explicit_rarity():
	# Jeder Charm aus all() muss in Charm.RARITIES stehen (Katalog-Sync) und
	# eine der vier bekannten Raritäten tragen - sonst fiele ein neuer Charm
	# still auf COMMON zurück.
	var valid := [Charm.RARITY_COMMON, Charm.RARITY_UNCOMMON, Charm.RARITY_RARE, Charm.RARITY_LEGENDARY]
	for charm in Charm.all():
		assert_true(Charm.RARITIES.has(charm.id), "Rarität fehlt für '%s'" % charm.id)
		assert_true(valid.has(charm.rarity), "unbekannte Rarität '%s' für '%s'" % [charm.rarity, charm.id])

func test_rarities_table_has_no_orphan_ids():
	var known: Array[String] = []
	for charm in Charm.all():
		known.append(charm.id)
	for charm_id: String in Charm.RARITIES:
		assert_true(known.has(charm_id), "RARITIES-Eintrag '%s' gehört zu keinem Charm" % charm_id)

func test_rarity_spot_checks_match_the_catalog():
	# Stichproben gegen die Obsidian-Tabellen: eine je Rarität.
	assert_eq(Charm.rabbits_foot().rarity, Charm.RARITY_COMMON)
	assert_eq(Charm.pendulum().rarity, Charm.RARITY_UNCOMMON)
	assert_eq(Charm.anchor().rarity, Charm.RARITY_RARE)
	assert_eq(Charm.broken_mirror().rarity, Charm.RARITY_LEGENDARY)

func test_pick_weighted_favors_common_over_legendary():
	# Deterministisch (fester Seed): Gewicht 1.0 vs 0.1 - der Gewöhnliche muss
	# in einer längeren Ziehreihe klar vorn liegen.
	seed(12345)
	var candidates: Array[Charm] = [Charm.rabbits_foot(), Charm.broken_mirror()]
	var common_hits := 0
	for i in 200:
		if Charm.pick_weighted(candidates).id == Charm.RABBITS_FOOT:
			common_hits += 1
	assert_gt(common_hits, 140, "Gewöhnlich (Gewicht 1.0) schlägt Legendär (0.1) deutlich")
