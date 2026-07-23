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

func test_transform_is_idempotent():
	# best_hand -> score_category verwandelt doppelt - darf nichts ändern.
	var ids := _ids([Charm.LUCKY_CIGARETTES, Charm.PENCIL_STUB, Charm.FOX_TAIL])
	for v in range(1, 7):
		var once := CharmEffects.transform_value(v, ids)
		assert_eq(CharmEffects.transform_value(once, ids), once, "Wert %d" % v)

func test_transform_values_keeps_slots_aligned():
	assert_eq(CharmEffects.transform_values(_d([1, 5, 3]), _ids([Charm.LUCKY_CIGARETTES])), _d([6, 5, 3]))

# --- Retrigger (Würfel löst erneut aus) --------------------------------------

func test_retrigger_rabbits_foot_counts_sixes():
	assert_eq(CharmEffects.retrigger_count(6, _ids([Charm.RABBITS_FOOT])), 1)
	assert_eq(CharmEffects.retrigger_count(5, _ids([Charm.RABBITS_FOOT])), 0, "nur 6 betroffen")

func test_retrigger_clover_and_scarab_hit_their_face():
	assert_eq(CharmEffects.retrigger_count(4, _ids([Charm.FOUR_LEAF_CLOVER])), 1)
	assert_eq(CharmEffects.retrigger_count(5, _ids([Charm.GOLDEN_SCARAB])), 1)

func test_retrigger_stacks_per_copy():
	assert_eq(CharmEffects.retrigger_count(6, _ids([Charm.RABBITS_FOOT, Charm.RABBITS_FOOT])), 2)

# --- Basispunkte (erkennungsblind) -------------------------------------------

func test_eye_value_no_charms_is_identity():
	assert_eq(CharmEffects.eye_value(3, _ids([])), 3)

# --- Wertung (ganze Hand) ----------------------------------------------------

func test_mult_bonus_horseshoe_only_full_house():
	assert_eq(CharmEffects.mult_bonus("full_house", _ids([Charm.HORSESHOE])), 12)
	assert_eq(CharmEffects.mult_bonus("two_kind", _ids([Charm.HORSESHOE])), 0)

func test_mult_bonus_ladybug_pairs():
	assert_eq(CharmEffects.mult_bonus("two_kind", _ids([Charm.LADYBUG])), 4)
	assert_eq(CharmEffects.mult_bonus("two_pair", _ids([Charm.LADYBUG])), 0, "nur die Kategorie Paar")
	assert_eq(CharmEffects.mult_bonus("three_kind", _ids([Charm.LADYBUG])), 0)

func test_mult_bonus_pearl_three_kind():
	assert_eq(CharmEffects.mult_bonus("three_kind", _ids([Charm.PEARL_NECKLACE])), 8)
	assert_eq(CharmEffects.mult_bonus("three_pairs", _ids([Charm.PEARL_NECKLACE])), 0)
	assert_eq(CharmEffects.mult_bonus("full_house", _ids([Charm.PEARL_NECKLACE])), 0)

func test_rainbow_trout_gives_mult_on_straights_only():
	assert_eq(CharmEffects.mult_bonus("small_straight", _ids([Charm.RAINBOW_TROUT])), 10)
	assert_eq(CharmEffects.mult_bonus("large_straight", _ids([Charm.RAINBOW_TROUT])), 10)
	assert_eq(CharmEffects.mult_bonus("full_house", _ids([Charm.RAINBOW_TROUT])), 0)

func test_collectors_amulet_gives_mult_per_other_charm():
	# 3 Charms -> +2 Mult je anderem Charm (= +4); mit nur sich selbst -> +0.
	assert_eq(CharmEffects.charm_mult_bonus("two_kind", [] as Array[int], [] as Array[String], _ids([Charm.COLLECTORS_AMULET, Charm.HORSESHOE, Charm.LADYBUG])), 4)
	assert_eq(CharmEffects.charm_mult_bonus("two_kind", [] as Array[int], [] as Array[String], _ids([Charm.COLLECTORS_AMULET])), 0)

func test_total_factor_magic_card_first_hand_only():
	assert_eq(CharmEffects.charm_total_factor_at(0, _ids([Charm.MAGIC_CARD]), true), 2)
	assert_eq(CharmEffects.charm_total_factor_at(0, _ids([Charm.MAGIC_CARD]), false), 1)
	assert_eq(CharmEffects.charm_total_factor_at(0, _ids([Charm.HORSESHOE]), true), 1)

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
