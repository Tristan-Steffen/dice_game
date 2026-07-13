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

const PAIR := [5, 5, 1, 2, 3, 6]  # Paar Fünfer: Basis 10, Mult 2 -> 20
const NO_MATS: Array[String] = []

# --- Augenwerte -------------------------------------------------------------------

func test_small_fry_boosts_ones_and_twos():
	assert_eq(CharmEffects.eye_value(1, _ids([Charm.SMALL_FRY])), 3)
	assert_eq(CharmEffects.eye_value(2, _ids([Charm.SMALL_FRY])), 4)
	assert_eq(CharmEffects.eye_value(5, _ids([Charm.SMALL_FRY])), 5)

func test_equalizer_floors_at_three_regardless_of_order():
	assert_eq(CharmEffects.eye_value(1, _ids([Charm.EQUALIZER])), 3)
	assert_eq(CharmEffects.eye_value(2, _ids([Charm.EQUALIZER])), 3)
	assert_eq(CharmEffects.eye_value(6, _ids([Charm.EQUALIZER])), 6)
	# Reihenfolge-unabhängig: Glückszigaretten (1 -> 6) gewinnen in beiden Ordnungen.
	assert_eq(CharmEffects.eye_value(1, _ids([Charm.LUCKY_CIGARETTES, Charm.EQUALIZER])),
		CharmEffects.eye_value(1, _ids([Charm.EQUALIZER, Charm.LUCKY_CIGARETTES])))

# --- Basis-Boni --------------------------------------------------------------------

func test_echo_chamber_counts_highest_die_again():
	var bonus := CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), _ids([Charm.ECHO_CHAMBER]))
	assert_eq(bonus, 6, "höchster Würfel (6) zählt erneut")

func test_twin_ring_doubles_exact_pairs():
	var bonus := CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), _ids([Charm.TWIN_RING]))
	assert_eq(bonus, 10, "nur die 5 liegt genau zweimal: beide zählen doppelt (+10)")

func test_double_six_clones_every_second_six():
	var bonus := CharmEffects.charm_base_bonus(DiceScoring.FOUR_KIND, _d([6, 6, 6, 6, 2, 3]), _p([0, 1, 2, 3]), _ids([Charm.DOUBLE_SIX]))
	assert_eq(bonus, 12, "vier Sechser -> zwei Klone")

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

func test_pendulum_swings_both_ways():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.PENDULUM]), {"rerolled": 3, "taken_dice": 2}), 4)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.PENDULUM]), {"rerolled": 0, "taken_dice": 6}), -6)

func test_pendulum_never_drops_total_mult_below_one():
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.PENDULUM]), false, NO_MATS, NO_MATS, {}, {"rerolled": 0, "taken_dice": 12})
	assert_eq(score, 10, "Mult klemmt bei 1: Basis 10 × 1")

func test_all_or_nothing_needs_a_full_reroll():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.ALL_OR_NOTHING]), {"full_reroll": true}), 5)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.ALL_OR_NOTHING]), {"full_reroll": false}), 0)

func test_momentum_follows_the_streak():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.MOMENTUM]), {"streak": 3}), 3)

func test_gallows_humor_after_a_farkle():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.GALLOWS_HUMOR]), {"after_farkle": true}), 3)

func test_broken_mirror_stacks_with_farkles():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.BROKEN_MIRROR]), {"farkle_stacks": 4}), 4)

func test_parity_charms_check_the_whole_roll():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d([2, 2, 4, 6, 6, 4]), NO_MATS, _ids([Charm.EVEN_COMPANY])), 3)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.EVEN_COMPANY])), 0)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d([1, 1, 3, 5, 5, 3]), NO_MATS, _ids([Charm.ODD_PATH])), 3)

func test_hermit_crab_wants_few_charms():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.HERMIT_CRAB])), 4)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.HERMIT_CRAB, Charm.HORSESHOE, Charm.LADYBUG])), 0, "drei Charms sind zu viele")

func test_display_case_counts_face_up_materials():
	var materials := _m(["", "", DieMaterial.RUBY, DieMaterial.AMBER, "", ""])
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), materials, _ids([Charm.DISPLAY_CASE])), 2)

func test_lighthouse_triples_high_card():
	var score := DiceScoring.score_category(DiceScoring.ONE_KIND, _d([1, 2, 3, 1, 2, 4]), _ids([Charm.LIGHTHOUSE]))
	assert_eq(score, 12, "Höchste Zahl 4 × Mult 3")

func test_restaurant_critic_rides_menu_levels():
	var levels := {DiceScoring.TWO_KIND: 2}
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.RESTAURANT_CRITIC]), {}, levels), 4)

# --- Flat-Boni & Faktoren -----------------------------------------------------------

func test_blackjack_pays_21_on_sum_21():
	var dice := _d([6, 6, 1, 2, 2, 4])  # Summe 21
	assert_eq(CharmEffects.charm_flat_bonus(dice, _p([0, 1]), _ids([Charm.BLACKJACK])), 21)
	assert_eq(CharmEffects.charm_flat_bonus(_d(PAIR), _p([0, 1]), _ids([Charm.BLACKJACK])), 0, "Summe 22 zahlt nicht")

func test_snake_eyes_wants_exactly_two_ones():
	assert_eq(CharmEffects.charm_flat_bonus(_d([1, 1, 3, 4, 5, 6]), _p([0, 1]), _ids([Charm.SNAKE_EYES])), 15)
	assert_eq(CharmEffects.charm_flat_bonus(_d([1, 1, 1, 4, 5, 6]), _p([0, 1, 2]), _ids([Charm.SNAKE_EYES])), 0, "drei 1er sind keine Snake Eyes")

func test_alloy_wants_face_and_edge_material():
	var materials := _m([DieMaterial.GOLD, "", "", "", "", ""])
	var edges := _m([DieMaterial.GOLD, DieMaterial.GOLD, "", "", "", ""])
	assert_eq(CharmEffects.charm_flat_bonus(_d(PAIR), _p([0, 1]), _ids([Charm.ALLOY]), materials, edges), 10,
		"nur Slot 0 hat Seite UND Kanten")

func test_cult_of_one_doubles_base_and_mult_per_one():
	# Paar Fünfer mit EINER 1: Basis 10×2 × Mult 2×2 = 80.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.CULT_OF_ONE]))
	assert_eq(score, 80)

func test_after_work_beer_doubles_the_last_hand():
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.AFTER_WORK_BEER]), false, NO_MATS, NO_MATS, {}, {"last_hand": true})
	assert_eq(score, 40)

func test_serial_offender_boosts_repeats():
	var ctx := {"prev_key": DiceScoring.TWO_KIND}
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.SERIAL_OFFENDER]), false, NO_MATS, NO_MATS, {}, ctx)
	assert_eq(score, 30, "20 × 1,5")

func test_round_number_rewards_trailing_zero():
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.ROUND_NUMBER]))
	assert_eq(score, 40, "20 endet auf 0: +20")

# --- Material-Verstärker -------------------------------------------------------------

func test_amber_room_boosts_amber_to_thirty():
	var bonus := MaterialEffects.base_bonus(_d(PAIR), _m([DieMaterial.AMBER, "", "", "", "", ""]), _p([0, 1]), _ids([Charm.AMBER_ROOM]))
	assert_eq(bonus, 30)

func test_ruby_grinder_boosts_ruby_to_six():
	var bonus := MaterialEffects.mult_bonus(_d(PAIR), _m([DieMaterial.RUBY, "", "", "", "", ""]), _p([0, 1]), NO_MATS, _ids([Charm.RUBY_GRINDER]))
	assert_eq(bonus, 6)

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
	assert_eq(CharmEffects.take_income(_ids([Charm.STREET_MUSICIAN])), 1)
	assert_eq(CharmEffects.farkle_shard_income(6, _ids([Charm.SHARD_COURT])), 6)
	assert_true(CharmEffects.gold_rush_applies(_ids([Charm.GOLD_RUSH]), 6))
	assert_false(CharmEffects.gold_rush_applies(_ids([Charm.GOLD_RUSH]), 5))

func test_rag_collector_counts_lucky_values():
	assert_eq(CharmEffects.rag_collector_income(_d([4, 4, 1, 4, 2, 3]), 4, _ids([Charm.RAG_COLLECTOR])), 3)
	assert_eq(CharmEffects.rag_collector_income(_d([4, 4, 1, 4, 2, 3]), 0, _ids([Charm.RAG_COLLECTOR])), 0, "ohne Glückszahl kein Geld")

func test_round_end_income_combines_sources():
	# Zinsgroschen: $37 -> +3; Überflieger: 60 über Ziel -> +2; Vollversammlung: 6 Charms -> +3.
	var ids := _ids([Charm.INTEREST_PENNY, Charm.HIGH_FLYER, Charm.FULL_ASSEMBLY])
	assert_eq(CharmEffects.round_end_income(37, 6, 60, ids), 8)
	assert_eq(CharmEffects.round_end_income(9, 3, 10, ids), 0)

func test_money_floor_only_with_emergency_fund():
	assert_eq(CharmEffects.money_floor(_ids([Charm.EMERGENCY_FUND])), 5)
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
	assert_eq(CharmEffects.pack_price(13, "tageskarte", _ids([Charm.GOURMET])), 7, "Tageskarte halbiert (gerundet)")
	assert_eq(CharmEffects.pack_price(13, "werkstatt", _ids([Charm.GOURMET])), 13, "andere Packs unberührt")
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

func test_regular_guest_eats_double_portions():
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.regular_guest())
	run.eat_meal(DiceScoring.TWO_KIND)
	assert_eq(run.combo_levels[DiceScoring.TWO_KIND], 2)

func test_round_start_charms_grant_their_gifts():
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.midnight_snack())
	run.owned_charms.append(Charm.stamp_machine())
	run.owned_charms.append(Charm.jewelry_box())
	run.gravierstift_used_this_round = true
	run.apply_round_start_charms()
	assert_false(run.gravierstift_used_this_round, "Gravierstift-Marke zurückgesetzt")
	assert_eq(run.owned_coupons.size(), 1, "Frankiermaschine schenkt einen Coupon")
	assert_eq(run.owned_coupons[0].kind, Coupon.KIND_ETCHING)
	var total_levels := 0
	for key in run.combo_levels:
		total_levels += int(run.combo_levels[key])
	assert_gt(total_levels, 0, "Mitternachtssnack hat gegessen")
	var material_faces := 0
	for def in run.owned_pool:
		material_faces += def.materials.size() - def.materials.count("")
	assert_eq(material_faces, 1, "Schmuckkästchen hat genau eine Seite veredelt")

func test_rag_collector_rolls_lucky_value_on_purchase():
	var run := GameRun.new_run()
	run.money = 50
	run.purchase_charm(Charm.rag_collector(), 25)
	assert_between(run.lumpensammler_value, 1, 6)

func test_large_format_grows_sheets():
	var run := GameRun.new_run()
	run.money = 100
	run.owned_charms.append(Charm.large_format())
	var sheet := run.buy_coupon_sheet(CouponSheet.Kind.SNIPPET, 6)
	assert_eq(Vector2i(sheet.cols, sheet.rows), Vector2i(3, 3), "2×2 wird 3×3")

func test_house_brand_removes_ads_from_general_sheets():
	var run := GameRun.new_run()
	run.money = 1000
	run.owned_charms.append(Charm.house_brand())
	for i in 6:
		var sheet := run.buy_coupon_sheet(CouponSheet.Kind.LARGE, 16)  # leerer Filter = gemischtes Heft
		for tile in sheet.tiles:
			assert_ne(tile.kind, CouponSheet.TileKind.AD, "Hausmarke: keine Werbeflächen")

# --- Stapelung je Vorkommen (der Mechanismus hinter den Totems) --------------------

func test_additive_bonuses_stack_per_occurrence():
	# Genau das machen die Totems: dieselbe id liegt zweimal in der Liste.
	var twice := _ids([Charm.BROADBAND, Charm.BROADBAND])
	assert_eq(CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), twice), 20)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.MOMENTUM, Charm.MOMENTUM]), {"streak": 3}), 6)
	assert_eq(CharmEffects.round_end_income(30, 0, 0, _ids([Charm.INTEREST_PENNY, Charm.INTEREST_PENNY])), 6)
	assert_eq(CharmEffects.take_income(_ids([Charm.STREET_MUSICIAN, Charm.STREET_MUSICIAN])), 2)

func test_totem_copy_actually_doubles_a_scoring_charm():
	# Ende-zu-Ende: Papagei neben Breitband -> +10 Basis wird +20.
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.broadband())
	run.owned_charms.append(Charm.parrot_totem())
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), run.charm_ids())
	assert_eq(score, 60, "(10 + 2×10) × 2")

func test_totem_chain_resolves_each_neighbor_independently():
	# [Breitband, Papagei, Echo, Hufeisen]: Papagei kopiert links (Breitband),
	# Echo kopiert rechts (Hufeisen).
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.broadband())
	run.owned_charms.append(Charm.parrot_totem())
	run.owned_charms.append(Charm.echo_totem())
	run.owned_charms.append(Charm.horseshoe())
	assert_eq(run.charm_ids(), ["broadband", "broadband", "horseshoe", "horseshoe"])

func test_two_regular_guests_eat_triple_portions():
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.regular_guest())
	run.owned_charms.append(Charm.parrot_totem())  # kopiert den Stammgast
	run.eat_meal(DiceScoring.SIX_KIND)
	assert_eq(run.combo_levels[DiceScoring.SIX_KIND], 3, "1 + 2× Stammgast")

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

func test_gourmet_and_bargain_hunter_combine():
	var ids := _ids([Charm.GOURMET, Charm.BARGAIN_HUNTER])
	assert_eq(CharmEffects.pack_price(13, "tageskarte", ids), 5, "erst halbiert (7), dann −2")
	assert_eq(CharmEffects.pack_price(6, "tageskarte", _ids([Charm.GOURMET, Charm.BARGAIN_HUNTER, Charm.BARGAIN_HUNTER])), 1, "nie unter $1")

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

# --- Wertungs-Reihenfolge: Nachjustierung nach Faktoren --------------------------------

func test_round_number_applies_after_hand_factor():
	# Feierabendbier verdoppelt 20 -> 40; Runde Sache sieht die 40 und legt +20 drauf.
	var ids := _ids([Charm.AFTER_WORK_BEER, Charm.ROUND_NUMBER])
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids, false, NO_MATS, NO_MATS, {}, {"last_hand": true})
	assert_eq(score, 60)

func test_serial_offender_rounds_half_scores():
	# Höchste Zahl 5 × 1 = 5 -> ×1,5 = 7,5 -> gerundet 8.
	var ctx := {"prev_key": DiceScoring.ONE_KIND}
	var score := DiceScoring.score_category(DiceScoring.ONE_KIND, _d([5, 1, 2, 2, 3, 3]), _ids([Charm.SERIAL_OFFENDER]), false, NO_MATS, NO_MATS, {}, ctx)
	assert_eq(score, 8)
