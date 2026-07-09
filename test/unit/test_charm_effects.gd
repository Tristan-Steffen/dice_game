extends GutTest
## Tier-1-Tests der reinen Charm-Effektlogik (CharmEffects). Ein Test je Wirkungs-
## Hook; die Charm-ids kommen als Konstanten aus Charm, damit ein Tippfehler ein
## Compilerfehler wäre statt eines stillen No-ops.

func _ids(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

# --- Augenwert (einzelner Würfel) --------------------------------------------

func test_eye_value_rabbits_foot_doubles_six():
	assert_eq(CharmEffects.eye_value(6, _ids([Charm.RABBITS_FOOT])), 12)
	assert_eq(CharmEffects.eye_value(5, _ids([Charm.RABBITS_FOOT])), 5, "nur 6 betroffen")

func test_eye_value_four_leaf_clover_doubles_four():
	assert_eq(CharmEffects.eye_value(4, _ids([Charm.FOUR_LEAF_CLOVER])), 8)

func test_eye_value_golden_scarab_doubles_five():
	assert_eq(CharmEffects.eye_value(5, _ids([Charm.GOLDEN_SCARAB])), 10)

func test_eye_value_lucky_cigarettes_one_counts_as_six():
	assert_eq(CharmEffects.eye_value(1, _ids([Charm.LUCKY_CIGARETTES])), 6)

func test_eye_value_fox_tail_three_counts_as_four():
	assert_eq(CharmEffects.eye_value(3, _ids([Charm.FOX_TAIL])), 4)

func test_eye_value_pencil_stub_two_counts_as_three():
	assert_eq(CharmEffects.eye_value(2, _ids([Charm.PENCIL_STUB])), 3)

func test_eye_value_no_charms_is_identity():
	assert_eq(CharmEffects.eye_value(3, _ids([])), 3)

func test_eye_value_multiple_charms_each_apply_to_their_face():
	var ids := _ids([Charm.RABBITS_FOOT, Charm.FOUR_LEAF_CLOVER])
	assert_eq(CharmEffects.eye_value(6, ids), 12)
	assert_eq(CharmEffects.eye_value(4, ids), 8)
	assert_eq(CharmEffects.eye_value(5, ids), 5, "von keinem betroffen")

# --- Wertung (ganze Hand) ----------------------------------------------------

func test_mult_bonus_horseshoe_only_full_house():
	assert_eq(CharmEffects.mult_bonus("full_house", _ids([Charm.HORSESHOE])), 1)
	assert_eq(CharmEffects.mult_bonus("two_kind", _ids([Charm.HORSESHOE])), 0)

func test_mult_bonus_ladybug_pairs():
	assert_eq(CharmEffects.mult_bonus("two_kind", _ids([Charm.LADYBUG])), 1)
	assert_eq(CharmEffects.mult_bonus("two_pair", _ids([Charm.LADYBUG])), 1)
	assert_eq(CharmEffects.mult_bonus("three_kind", _ids([Charm.LADYBUG])), 0)

func test_mult_bonus_pearl_big_combos():
	assert_eq(CharmEffects.mult_bonus("three_pairs", _ids([Charm.PEARL_NECKLACE])), 2)
	assert_eq(CharmEffects.mult_bonus("double_three_kind", _ids([Charm.PEARL_NECKLACE])), 2)
	assert_eq(CharmEffects.mult_bonus("full_house", _ids([Charm.PEARL_NECKLACE])), 0)

func test_flat_bonus_rainbow_trout_straights_only():
	assert_eq(CharmEffects.flat_bonus("small_straight", _ids([Charm.RAINBOW_TROUT])), 10)
	assert_eq(CharmEffects.flat_bonus("large_straight", _ids([Charm.RAINBOW_TROUT])), 10)
	assert_eq(CharmEffects.flat_bonus("full_house", _ids([Charm.RAINBOW_TROUT])), 0)

func test_flat_bonus_collectors_amulet_counts_other_charms():
	# 3 Charms -> +2 pro Hand; mit nur sich selbst -> +0
	assert_eq(CharmEffects.flat_bonus("two_kind", _ids([Charm.COLLECTORS_AMULET, Charm.HORSESHOE, Charm.LADYBUG])), 2)
	assert_eq(CharmEffects.flat_bonus("two_kind", _ids([Charm.COLLECTORS_AMULET])), 0)

func test_score_multiplier_magic_card_first_hand_only():
	assert_eq(CharmEffects.score_multiplier(_ids([Charm.MAGIC_CARD]), true), 2)
	assert_eq(CharmEffects.score_multiplier(_ids([Charm.MAGIC_CARD]), false), 1)
	assert_eq(CharmEffects.score_multiplier(_ids([]), true), 1)

# --- Geld --------------------------------------------------------------------

func test_round_clear_bonus_old_penny():
	assert_eq(CharmEffects.round_clear_bonus(_ids([Charm.OLD_PENNY])), 2)
	assert_eq(CharmEffects.round_clear_bonus(_ids([])), 0)

func test_unused_die_bonus_piggy_bank():
	assert_eq(CharmEffects.unused_die_bonus(_ids([Charm.PIGGY_BANK])), 1)

func test_farkle_survival_income_crystal_ball():
	assert_eq(CharmEffects.farkle_survival_income(_ids([Charm.CRYSTAL_BALL])), 1)

func test_die_price_con_artist_discount():
	assert_eq(CharmEffects.die_price(15, _ids([Charm.CON_ARTIST_CUFF])), 12)

func test_die_price_no_discount():
	assert_eq(CharmEffects.die_price(15, _ids([])), 15)

# --- Farkle-Milderung --------------------------------------------------------

func test_forgives_first_farkle_chimney_sweep():
	assert_true(CharmEffects.forgives_first_farkle(_ids([Charm.CHIMNEY_SWEEP])))
	assert_false(CharmEffects.forgives_first_farkle(_ids([])))

func test_farkle_kept_fraction_backwards_mirror():
	assert_almost_eq(CharmEffects.farkle_kept_fraction(_ids([Charm.BACKWARDS_MIRROR])), 0.5, 0.001)
	assert_almost_eq(CharmEffects.farkle_kept_fraction(_ids([])), 0.0, 0.001)

# --- Pool --------------------------------------------------------------------

func test_extra_round_dice_lucky_knot():
	assert_eq(CharmEffects.extra_round_dice(_ids([Charm.LUCKY_KNOT])), 1)

func test_draws_specials_first_dowsing_rod():
	assert_true(CharmEffects.draws_specials_first(_ids([Charm.DOWSING_ROD])))
	assert_false(CharmEffects.draws_specials_first(_ids([])))
