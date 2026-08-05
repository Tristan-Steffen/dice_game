extends GutTest
## Tier-1-Tests der reinen Charm-Effektlogik (CharmEffects). Ein Test je Wirkungs-
## Hook; die Charm-ids kommen als Konstanten aus Charm, damit ein Tippfehler ein
## Compilerfehler wäre statt eines stillen No-ops.

func _ids(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _d(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

# --- Verwandlung (Wert für Kombination UND Punkte) ---------------------------

func test_transform_lucky_cigarettes_one_becomes_six():
	assert_eq(CharmEffects.transform_value(1, _ids([Charm.LUCKY_CIGARETTES])), 6)
	assert_eq(CharmEffects.transform_value(2, _ids([Charm.LUCKY_CIGARETTES])), 2, "nur 1 betroffen")

func test_transform_fox_tail_three_becomes_four():
	assert_eq(CharmEffects.transform_value(3, _ids([Charm.FOX_TAIL])), 4)

func test_transform_pencil_stub_two_becomes_three():
	assert_eq(CharmEffects.transform_value(2, _ids([Charm.PENCIL_STUB])), 3)

func test_transform_chains_pencil_into_fox_tail():
	# Feste Kettenreihenfolge: die verwandelte 2 wird zur 3 und weiter zur 4.
	var ids := _ids([Charm.PENCIL_STUB, Charm.FOX_TAIL])
	assert_eq(CharmEffects.transform_value(2, ids), 4)
	assert_eq(CharmEffects.transform_value(2, _ids([Charm.FOX_TAIL, Charm.PENCIL_STUB])), 4, "Besitz-Reihenfolge egal")

func test_transform_top_hat_four_becomes_five():
	assert_eq(CharmEffects.transform_value(4, _ids([Charm.TOP_HAT])), 5)
	assert_eq(CharmEffects.transform_value(3, _ids([Charm.TOP_HAT])), 3, "nur 4 betroffen")

func test_transform_silver_dollar_five_becomes_six():
	assert_eq(CharmEffects.transform_value(5, _ids([Charm.SILVER_DOLLAR])), 6)
	assert_eq(CharmEffects.transform_value(4, _ids([Charm.SILVER_DOLLAR])), 4, "nur 5 betroffen")

func test_transform_eight_knot_pulls_seven_and_nine_to_eight():
	var ids := _ids([Charm.EIGHT_KNOT])
	assert_eq(CharmEffects.transform_value(7, ids), 8)
	assert_eq(CharmEffects.transform_value(9, ids), 8)
	assert_eq(CharmEffects.transform_value(8, ids), 8, "die 8 bleibt")
	assert_eq(CharmEffects.transform_value(6, ids), 6, "unter 7 rührt er nichts an")

func test_transform_chain_lifts_a_two_all_the_way_to_six():
	# Aufsteigende Kette: 2 -> 3 -> 4 -> 5 -> 6.
	var ids := _ids([Charm.PENCIL_STUB, Charm.FOX_TAIL, Charm.TOP_HAT, Charm.SILVER_DOLLAR])
	assert_eq(CharmEffects.transform_value(2, ids), 6)
	assert_eq(CharmEffects.transform_value(4, ids), 6, "auch von der Mitte aus")

func test_transform_is_idempotent():
	# best_hand -> score_category verwandelt doppelt - darf nichts ändern.
	var ids := _ids([Charm.LUCKY_CIGARETTES, Charm.PENCIL_STUB, Charm.FOX_TAIL,
		Charm.TOP_HAT, Charm.SILVER_DOLLAR, Charm.EIGHT_KNOT])
	for v in range(1, 13):
		var once := CharmEffects.transform_value(v, ids)
		assert_eq(CharmEffects.transform_value(once, ids), once, "Wert %d" % v)

func test_transform_values_keeps_slots_aligned():
	assert_eq(CharmEffects.transform_values(_d([1, 5, 3]), _ids([Charm.LUCKY_CIGARETTES])), _d([6, 5, 3]))

# --- Retrigger (Würfel löst erneut aus) --------------------------------------

func test_retrigger_rabbits_foot_counts_sixes():
	assert_eq(CharmEffects.retrigger_count(6, _ids([Charm.RABBITS_FOOT])), 1)
	assert_eq(CharmEffects.retrigger_count(5, _ids([Charm.RABBITS_FOOT])), 0, "nur 6 betroffen")

func test_retrigger_clover_hits_its_face():
	assert_eq(CharmEffects.retrigger_count(4, _ids([Charm.FOUR_LEAF_CLOVER])), 1)
	assert_eq(CharmEffects.retrigger_count(5, _ids([Charm.FOUR_LEAF_CLOVER])), 0, "nur 4 betroffen")

func test_retrigger_stacks_per_copy():
	assert_eq(CharmEffects.retrigger_count(6, _ids([Charm.RABBITS_FOOT, Charm.RABBITS_FOOT])), 2)

func test_full_hand_retriggers_arm_only_on_all_six():
	var ids := _ids([Charm.SIX_PACK])
	assert_eq(CharmEffects.full_hand_retriggers(ids, 6), 1)
	assert_eq(CharmEffects.full_hand_retriggers(ids, 5), 0, "fünf Würfel reichen nicht")
	assert_eq(CharmEffects.full_hand_retriggers(ids, 0), 0)
	assert_eq(CharmEffects.full_hand_retriggers(_ids([]), 6), 0, "ohne Charm nichts")

func test_full_hand_retriggers_stack_per_copy():
	assert_eq(CharmEffects.full_hand_retriggers(_ids([Charm.SIX_PACK, Charm.SIX_PACK]), 6), 2)

# --- Quadratur (würfelgebunden, ab vier gewerteten Würfeln) ------------------

func test_quadrature_squares_the_lowest_of_four():
	# Vier gewertete Würfel: die 2 auf Slot 1 ist die niedrigste, 2² = 4.
	var ids := _ids([Charm.QUADRATURE])
	var values := _d([5, 2, 4, 3, 6, 6])
	var scored := _d([0, 1, 2, 3])
	assert_eq(CharmEffects.die_charm_base_at(0, 1, DiceScoring.FOUR_KIND, values, ids, {}, scored), 4)
	for slot in [0, 2, 3]:
		assert_eq(CharmEffects.die_charm_base_at(0, slot, DiceScoring.FOUR_KIND, values, ids, {}, scored), 0,
			"nur der niedrigste Würfel, Slot %d" % slot)

func test_quadrature_stays_quiet_below_four_dice():
	var ids := _ids([Charm.QUADRATURE])
	var values := _d([5, 2, 4, 3, 6, 6])
	assert_eq(CharmEffects.die_charm_base_at(0, 1, DiceScoring.THREE_KIND, values, ids, {}, _d([0, 1, 2])), 0,
		"drei gewertete Würfel sind zu wenig")
	assert_eq(CharmEffects.die_charm_base_at(0, 1, DiceScoring.THREE_KIND, values, ids), 0,
		"ohne gewertete Slots nichts")

func test_quadrature_breaks_ties_toward_the_smallest_slot():
	# Zwei gleich niedrige Zweien: der kleinere Slot gewinnt (target_die).
	var ids := _ids([Charm.QUADRATURE])
	var values := _d([2, 5, 2, 6])
	var scored := _d([0, 1, 2, 3])
	assert_eq(CharmEffects.die_charm_base_at(0, 0, DiceScoring.TWO_PAIR, values, ids, {}, scored), 4)
	assert_eq(CharmEffects.die_charm_base_at(0, 2, DiceScoring.TWO_PAIR, values, ids, {}, scored), 0)

# --- Gewertete Menge (Vollzähler) --------------------------------------------

func test_scored_indices_is_participating_without_full_counter():
	assert_eq(CharmEffects.scored_indices(_d([0, 1]), 6, _ids([])), _d([0, 1]))

func test_scored_indices_expands_to_all_dice_with_full_counter():
	assert_eq(CharmEffects.scored_indices(_d([0, 1]), 4, _ids([Charm.FULL_COUNTER])), _d([0, 1, 2, 3]))

# --- Basispunkte (erkennungsblind) -------------------------------------------

func test_eye_value_no_charms_is_identity():
	assert_eq(CharmEffects.eye_value(3, _ids([])), 3)

# --- Wertung (ganze Hand) ----------------------------------------------------

func test_mult_bonus_horseshoe_only_full_house():
	assert_eq(CharmEffects.mult_bonus("full_house", _ids([Charm.HORSESHOE])), 8)
	assert_eq(CharmEffects.mult_bonus("two_kind", _ids([Charm.HORSESHOE])), 0)

func test_mult_bonus_ladybug_pairs():
	assert_eq(CharmEffects.mult_bonus("two_kind", _ids([Charm.LADYBUG])), 4)
	assert_eq(CharmEffects.mult_bonus("two_pair", _ids([Charm.LADYBUG])), 0, "nur die Kategorie Paar")
	assert_eq(CharmEffects.mult_bonus("three_kind", _ids([Charm.LADYBUG])), 0)

func test_mult_bonus_pearl_three_kind():
	assert_eq(CharmEffects.mult_bonus("three_kind", _ids([Charm.PEARL_NECKLACE])), 6)
	assert_eq(CharmEffects.mult_bonus("three_pairs", _ids([Charm.PEARL_NECKLACE])), 0)
	assert_eq(CharmEffects.mult_bonus("full_house", _ids([Charm.PEARL_NECKLACE])), 0)

func test_rainbow_trout_gives_mult_on_straights_only():
	assert_eq(CharmEffects.mult_bonus("small_straight", _ids([Charm.RAINBOW_TROUT])), 8)
	assert_eq(CharmEffects.mult_bonus("large_straight", _ids([Charm.RAINBOW_TROUT])), 8)
	assert_eq(CharmEffects.mult_bonus("full_house", _ids([Charm.RAINBOW_TROUT])), 0)

func test_collectors_amulet_gives_mult_per_other_charm():
	# 3 Charms -> +2 Mult je anderem Charm (= +4); mit nur sich selbst -> +0.
	assert_eq(CharmEffects.charm_mult_bonus("two_kind", [] as Array[int], [] as Array[String], _ids([Charm.COLLECTORS_AMULET, Charm.HORSESHOE, Charm.LADYBUG])), 4)
	assert_eq(CharmEffects.charm_mult_bonus("two_kind", [] as Array[int], [] as Array[String], _ids([Charm.COLLECTORS_AMULET])), 0)

func test_magic_card_retriggers_only_the_first_hand():
	var card := _ids([Charm.MAGIC_CARD])
	assert_eq(CharmEffects.first_hand_retriggers(card, true, true), 1)
	assert_eq(CharmEffects.first_hand_retriggers(card, false, true), 0, "nur die erste Hand")
	assert_eq(CharmEffects.first_hand_retriggers(card, true, false), 0, "nur Kombinations-Würfel")
	assert_eq(CharmEffects.first_hand_retriggers(_ids([Charm.MAGIC_CARD, Charm.MAGIC_CARD]), true, true), 2)
	assert_eq(CharmEffects.first_hand_retriggers(_ids([Charm.HORSESHOE]), true, true), 0)

func test_the_magic_card_rides_the_die_axis():
	# Additiv wie das Sechserpack: ein Antritt mehr, nie ein Faktor - und nur am
	# Würfel der Kombination.
	var ids := _ids([Charm.MAGIC_CARD])
	assert_eq(MaterialEffects.die_trigger_count(0, ids, -1, [] as Array[String], false, 0, 2, -1, true, true), 2)
	assert_eq(MaterialEffects.die_trigger_count(0, ids, -1, [] as Array[String], false, 0, 2, -1, true, false), 1)
	assert_eq(MaterialEffects.die_trigger_count(0, ids, -1, [] as Array[String], false, 0, 2, -1, false, true), 1)

# --- Geld --------------------------------------------------------------------

func test_old_penny_pays_three_first_and_grows_afterwards():
	var penny := _ids([Charm.OLD_PENNY])
	assert_eq(CharmEffects.round_end_income(0, 0, penny), 3, "erste Auszahlung: $3")
	assert_eq(CharmEffects.round_end_income(0, 0, penny, 2), 5, "nach zwei Auszahlungen: $5")
	assert_eq(CharmEffects.round_end_income(0, 0, _ids([]), 3), 0)

func test_unused_die_bonus_piggy_bank():
	assert_eq(CharmEffects.unused_die_bonus(_ids([Charm.PIGGY_BANK])), 1)

func test_farkle_survival_income_crystal_ball():
	assert_eq(CharmEffects.farkle_survival_income(_ids([Charm.CRYSTAL_BALL])), 7)

func test_die_price_con_artist_discount():
	assert_eq(CharmEffects.die_price(15, _ids([Charm.CON_ARTIST_CUFF])), 10, "33% Rabatt")

func test_die_price_no_discount():
	assert_eq(CharmEffects.die_price(15, _ids([])), 15)

# --- Farkle-Milderung --------------------------------------------------------

func test_forgives_first_farkle_chimney_sweep():
	assert_true(CharmEffects.forgives_first_farkle(_ids([Charm.CHIMNEY_SWEEP])))
	assert_false(CharmEffects.forgives_first_farkle(_ids([])))
