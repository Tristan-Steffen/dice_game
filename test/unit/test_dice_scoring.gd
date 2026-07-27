extends GutTest
## Tier-1-Tests der reinen Wertungslogik (DiceScoring). Deckt Kategorie-
## Erkennung, Punktwerte, Priorität, charm-modifizierte Wertung und den
## Farkle-Vergleich (is_strictly_better) ab.
##
## Würfel bewusst OHNE versehentliche Straße (keine 5 aufeinanderfolgenden Werte)
## und ohne ungewollte höhere Kombination, damit wirklich die beabsichtigte
## Kategorie gewertet wird - genau die Falle, in die frühere Ad-hoc-Tests liefen.

# GDScript wandelt untypisierte Array-Literale nicht automatisch in die von
# DiceScoring erwarteten getypten Arrays - daher diese kleinen Helfer.
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

# --- Übertaktungs-Stufen (Systemkonsole, siehe GameRun.overclock_combo) ------------

func test_mult_for_scales_with_combo_levels():
	# Jede Stufe addiert den Basis-Multiplikator erneut: Paar ×2 -> ×4 -> ×6.
	assert_eq(DiceScoring.mult_for(DiceScoring.TWO_KIND), 2)
	assert_eq(DiceScoring.mult_for(DiceScoring.TWO_KIND, {DiceScoring.TWO_KIND: 1}), 4)
	assert_eq(DiceScoring.mult_for(DiceScoring.TWO_KIND, {DiceScoring.TWO_KIND: 2}), 6)

func test_points_for_scales_with_combo_levels():
	# Die festen Kategorie-Punkte wachsen mit den Übertaktungs-Stufen wie der Mult.
	assert_eq(DiceScoring.points_for(DiceScoring.TWO_KIND), 10)
	assert_eq(DiceScoring.points_for(DiceScoring.TWO_KIND, {DiceScoring.TWO_KIND: 1}), 20)
	assert_eq(DiceScoring.points_for(DiceScoring.SIX_KIND), 60)
	assert_eq(DiceScoring.points_for("not_a_category"), 0)

func test_score_category_uses_combo_levels():
	# Paar Fünfer: Basis (10 Punkte + 10 Augen) × Mult 2 = 40;
	# eine Stufe -> (20 + 10) × 4 = 120.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var no_mats: Array[String] = []
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, dice), 40)
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]), false, no_mats, no_mats, {DiceScoring.TWO_KIND: 1}), 120)

func test_best_hand_reports_upgraded_mult():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var no_mats: Array[String] = []
	var hand := DiceScoring.best_hand(dice, _ids([]), false, no_mats, no_mats, {DiceScoring.TWO_KIND: 1})
	assert_eq(hand["mult"], 4, "angezeigter Mult = aufgewerteter Mult")
	assert_eq(hand["score"], 120)

func test_levels_of_other_combos_do_not_leak():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var no_mats: Array[String] = []
	var hand := DiceScoring.best_hand(dice, _ids([]), false, no_mats, no_mats, {DiceScoring.SIX_KIND: 3})
	assert_eq(hand["score"], 40, "Stufe auf Sechserpasch ändert das Paar nicht")

# --- Kategorie-Erkennung: best_hand wählt die richtige Kombination ------------

func test_detects_six_of_a_kind():
	assert_eq(DiceScoring.best_hand(_d([4,4,4,4,4,4]))["key"], "six_kind")

func test_detects_five_of_a_kind():
	assert_eq(DiceScoring.best_hand(_d([5,5,5,5,5,1]))["key"], "five_kind")

func test_detects_large_straight():
	assert_eq(DiceScoring.best_hand(_d([1,2,3,4,5,6]))["key"], "large_straight")

func test_detects_four_kind_and_pair():
	assert_eq(DiceScoring.best_hand(_d([3,3,3,3,5,5]))["key"], "four_kind_and_pair")

func test_detects_double_three_kind():
	assert_eq(DiceScoring.best_hand(_d([2,2,2,5,5,5]))["key"], "double_three_kind")

func test_detects_three_pairs():
	assert_eq(DiceScoring.best_hand(_d([1,1,3,3,5,5]))["key"], "three_pairs")

func test_detects_four_of_a_kind():
	assert_eq(DiceScoring.best_hand(_d([6,6,6,6,2,3]))["key"], "four_kind")

func test_detects_full_house():
	assert_eq(DiceScoring.best_hand(_d([2,2,2,4,4,1]))["key"], "full_house")

func test_detects_small_straight():
	assert_eq(DiceScoring.best_hand(_d([1,2,3,4,5,5]))["key"], "small_straight")

func test_detects_three_of_a_kind():
	assert_eq(DiceScoring.best_hand(_d([4,4,4,1,2,6]))["key"], "three_kind")

func test_detects_two_pair():
	assert_eq(DiceScoring.best_hand(_d([2,2,5,5,1,6]))["key"], "two_pair")

func test_detects_two_of_a_kind():
	assert_eq(DiceScoring.best_hand(_d([3,3,1,2,4,6]))["key"], "two_kind")

# --- Priorität: Rang schlägt rohen Punktwert ---------------------------------

func test_straight_beats_the_pair_hidden_inside_it():
	# 1-2-3-4-5 ist eine kleine Straße, obwohl auch ein Paar 5er vorhanden ist.
	assert_eq(DiceScoring.best_hand(_d([1,2,3,4,5,5]))["key"], "small_straight")

func test_four_kind_and_pair_beats_full_house():
	# 4x3 + 2x5 erfüllt auch Full House, ist aber prestigeträchtiger.
	assert_eq(DiceScoring.best_hand(_d([3,3,3,3,5,5]))["key"], "four_kind_and_pair")

# --- Punktwerte: Basis (charm-frei) ------------------------------------------
# Basis = feste Kategorie-Punkte (points_for) + beteiligte Würfelaugen.

func test_score_six_of_a_kind():
	# (60 Punkte + 4×6 Augen) × Mult 15
	assert_eq(DiceScoring.best_hand(_d([4,4,4,4,4,4]))["score"], (60 + 4 * 6) * 15)

func test_score_full_house_sums_participating_dice():
	# Nur die beteiligten Würfel (2+2+2+4+4 = 14), der unbeteiligte 1er zählt
	# NICHT; plus 28 feste Punkte, mult 4.
	assert_eq(DiceScoring.best_hand(_d([2,2,2,4,4,1]))["score"], (28 + 14) * 4)

func test_score_two_of_a_kind():
	# Paar 3er: 10 Punkte + eye(3)=3 ×2 Würfel, mult 2
	assert_eq(DiceScoring.best_hand(_d([3,3,1,2,4,6]))["score"], (10 + 3 * 2) * 2)

func test_score_large_straight():
	assert_eq(DiceScoring.best_hand(_d([1,2,3,4,5,6]))["score"], (45 + 21) * 8)

func test_score_category_one_kind_directly():
	# one_kind ist als beste Hand bei 6 Würfeln unerreichbar (alle verschieden =
	# Straße), aber score_category selbst muss den Zweig korrekt rechnen.
	assert_eq(DiceScoring.score_category("one_kind", _d([6,6,1,1,2,2])), (5 + 6) * 1)

# --- Charm-modifizierte Wertung ----------------------------------------------

func test_rabbits_foot_retriggers_sixes():
	# Paar 6er: 10 Punkte + Augen (6+6) + Retrigger-Nachzählung (6+6), mult 2.
	assert_eq(DiceScoring.best_hand(_d([6,6,1,2,3,5]), _ids([Charm.RABBITS_FOOT]))["score"], (10 + 12 + 12) * 2)

func test_rabbits_foot_retriggers_material_effects_too():
	# Retrigger wie Quecksilber: der Rubin auf der beteiligten 6 feuert doppelt.
	var mats := _m([DieMaterial.RUBY, "", "", "", "", ""])
	var hand := DiceScoring.best_hand(_d([6,6,1,2,3,5]), _ids([Charm.RABBITS_FOOT]), false, mats)
	# Mult: 2 (Paar) + 4×2 (Rubin, zwei Aktivierungen) = 10.
	assert_eq(hand["mult"], 10)

func test_horseshoe_raises_full_house_mult():
	var hand := DiceScoring.best_hand(_d([2,2,2,5,5,1]), _ids([Charm.HORSESHOE]))
	assert_eq(hand["mult"], 16, "Full-House-Mult inkl. Hufeisen-Bonus (+12)")
	# Beteiligt 2 2 2 5 5 = 16 (der 1er zählt nicht), plus 28 Punkte, × (4+12).
	assert_eq(hand["score"], (28 + 16) * 16)

func test_pearl_necklace_boosts_only_three_kind():
	# Dreierpasch 3er: Basis (18 + 9) × (3+8).
	assert_eq(DiceScoring.best_hand(_d([3,3,3,1,2,6]), _ids([Charm.PEARL_NECKLACE]))["score"], (18 + 9) * 11)
	# Drei Zweierpäsche bleiben unberührt: (32 + _sum 18) × 5.
	assert_eq(DiceScoring.best_hand(_d([1,1,3,3,5,5]), _ids([Charm.PEARL_NECKLACE]))["score"], (32 + 18) * 5)

func test_rainbow_trout_adds_mult_to_straight():
	# kleine Straße: beteiligt 1 2 3 4 5 = 15 (die zweite 5 zählt nicht),
	# (22 + 15) × (4 + 10).
	assert_eq(DiceScoring.best_hand(_d([1,2,3,4,5,5]), _ids([Charm.RAINBOW_TROUT]))["score"], (22 + 15) * 14)

func test_magic_card_only_doubles_first_hand():
	var ids := _ids([Charm.MAGIC_CARD])
	assert_eq(DiceScoring.best_hand(_d([3,3,1,2,4,6]), ids, true)["score"], 64, "erste Hand verdoppelt")
	assert_eq(DiceScoring.best_hand(_d([3,3,1,2,4,6]), ids, false)["score"], 32, "spätere Hand normal")

func test_collectors_amulet_adds_mult_per_other_charm():
	# Nur das Amulett greift bei einem Paar 3er; die anderen sind neutral.
	# +2 Mult je anderem Charm: Basis (10 + 6) × (2 + 4) = 96.
	var ids := _ids([Charm.COLLECTORS_AMULET, Charm.RABBITS_FOOT, Charm.GOLDEN_SCARAB])
	assert_eq(DiceScoring.best_hand(_d([3,3,1,2,4,6]), ids)["score"], 96)

func test_retrigger_charms_never_change_the_category():
	# Ein Paar bleibt ein Paar - Retrigger zählt nach, verwandelt aber nicht.
	var key: String = DiceScoring.best_hand(_d([6,6,1,2,3,5]), _ids([Charm.RABBITS_FOOT]))["key"]
	assert_eq(key, "two_kind")

# --- Verwandlungs-Charms: Augen ändern sich VOR der Erkennung ------------------

func test_lucky_cigarettes_pair_ones_into_sixes():
	# [1,1,x]: die verwandelten 1er bilden ein echtes 6er-Paar.
	var hand := DiceScoring.best_hand(_d([1,1,3,4,4,5]), _ids([Charm.LUCKY_CIGARETTES]))
	assert_eq(hand["key"], "two_pair", "6er-Paar aus 1ern + 4er-Paar")

func test_fox_tail_builds_combinations_from_threes():
	# 3+4 sind ohne Charm nur Höchste Zahl - mit Fuchsschwanz ein 4er-Paar.
	var hand := DiceScoring.best_hand(_d([3,4,1,2,6,6]), _ids([Charm.FOX_TAIL]))
	assert_eq(hand["key"], "two_pair")
	# Beteiligt: 4er-Paar (4 + verwandelte 3->4) und 6er-Paar.
	assert_eq(hand["score"], (15 + 4 + 4 + 6 + 6) * 3)

func test_pencil_stub_chains_through_fox_tail():
	# 2 -> 3 -> 4: mit beiden Charms wird aus [2,4] ein 4er-Paar.
	var hand := DiceScoring.best_hand(_d([2,4,1,3,5,6]), _ids([Charm.PENCIL_STUB, Charm.FOX_TAIL]))
	assert_ne(hand["key"], "one_kind", "verwandelte Werte bilden eine Kombination")

func test_transformed_values_count_for_points_too():
	# Das 6er-Paar aus 1ern zählt auch die Augen als 6er.
	var score: int = DiceScoring.score_category("two_kind", _d([1,1,3,4,2,4]), _ids([Charm.LUCKY_CIGARETTES]))
	assert_eq(DiceScoring.score_category("two_kind", _d([1,1,3,5,2,5])), (10 + 5 + 5) * 2)
	assert_eq(score, (10 + 6 + 6) * 2)

# --- Nur die letzte Ziffer zählt für die Kombination (Überzahlen) --------------

func test_last_digit_forms_a_pasch():
	# 1, 11, 21 enden alle auf 1 -> Dreierpasch (nur die letzte Ziffer zählt).
	var hand := DiceScoring.best_hand(_d([1, 11, 21, 2, 3, 6]))
	assert_eq(hand["key"], "three_kind")
	# Punkte: die ECHTEN Werte der beteiligten Würfel zählen (1+11+21 = 33),
	# plus 18 feste Punkte, × Mult 3.
	assert_eq(hand["score"], (18 + 33) * 3)

func test_last_digit_pairs_use_real_values():
	# 6 und 16 enden beide auf 6 -> Paar; Basis = eye(6)+eye(16) = 22.
	var dice := _d([6, 16, 1, 2, 3, 5])
	assert_eq(DiceScoring.best_hand(dice)["key"], "two_kind")
	assert_eq(DiceScoring.best_hand(dice)["score"], (10 + 22) * 2)

func test_last_digit_forms_a_straight():
	# 11-12-13-14-15 (Ziffern 1-5) gilt wie 1-2-3-4-5 -> Kleine Straße (der
	# zusätzliche 22er = Ziffer 2 vervollständigt sie NICHT zur großen Straße).
	assert_eq(DiceScoring.best_hand(_d([11, 12, 13, 14, 15, 22]))["key"], "small_straight")

func test_last_digit_holds_for_arbitrarily_large_faces():
	# Beliebig große Seiten: 1/11/51/1991/31 enden alle auf 1 -> 5 of a Kind,
	# und 1-2-3-44-15-26 deckt die Ziffern 1-6 -> Große Straße.
	assert_eq(DiceScoring.best_hand(_d([1, 11, 51, 1991, 31]))["key"], "five_kind")
	assert_eq(DiceScoring.best_hand(_d([1, 2, 3, 44, 15, 26]))["key"], "large_straight")

func test_two_pair_with_overcounts_sums_real_values():
	# 5-5 und 11-11 (Ziffern 5 und 1): Zwei Paare; die Basis summiert die ECHTEN
	# Werte aller vier beteiligten Würfel (5+5+11+11 = 32), plus 15, × Mult 3.
	var dice := _d([5, 5, 11, 11, 2, 3])
	var hand := DiceScoring.best_hand(dice)
	assert_eq(hand["key"], "two_pair")
	assert_eq(hand["score"], (15 + 32) * 3)

# --- Farkle-Vergleich (is_strictly_better) -----------------------------------

func test_reroll_with_more_points_is_better():
	# Drilling 6er (54) schlägt Paar 3er (12)
	assert_true(DiceScoring.is_strictly_better(_d([6,6,6,1,2,4]), _d([3,3,1,2,4,6])))

func test_equal_points_is_not_strictly_better():
	var same := _d([3,3,1,2,4,6])
	assert_false(DiceScoring.is_strictly_better(same, same))

func test_fewer_points_is_not_better():
	assert_false(DiceScoring.is_strictly_better(_d([2,2,1,3,4,6]), _d([6,6,1,2,3,5])))

# --- best_hand nimmt die punktträchtigste Kombination, nicht die ranghöchste ---

func test_best_hand_prefers_the_higher_scoring_combo_over_rank():
	# [6,6,2,3,4,5] ist zugleich Kleine Straße (rang-höher) UND Paar 6er. Mit
	# Paar-Stufe 4 bringt das Paar (620) mehr als die Straße (168) - best_hand
	# nimmt das Paar.
	var dice := _d([6, 6, 2, 3, 4, 5])
	var no_mats: Array[String] = []
	var hand := DiceScoring.best_hand(dice, _ids([]), false, no_mats, no_mats, {DiceScoring.TWO_KIND: 4})
	assert_eq(hand["key"], "two_kind", "das aufgewertete Paar schlägt die schwache Straße")
	assert_eq(hand["score"], (50 + 12) * 10)

func test_without_boosts_the_higher_rank_still_wins_on_points():
	# Ohne Aufwertung bringt die Kleine Straße (168) mehr als das Paar (44) -
	# der Rang deckt sich mit den Punkten, best_hand bleibt bei der Straße.
	assert_eq(DiceScoring.best_hand(_d([6, 6, 2, 3, 4, 5]))["key"], "small_straight")

func test_reroll_into_a_higher_scoring_hand_is_not_a_farkle():
	# Regression der Farkle-Falle: der Neuwurf [6,6,2,3,4,5] kann als aufgewertetes
	# Paar (620) mehr bringen als die alte Große Straße (528) - obwohl seine
	# RANGhöchste Kombination (Kleine Straße, 168) weniger brächte. Kein Farkle.
	var levels := {DiceScoring.TWO_KIND: 4}
	var no_mats: Array[String] = []
	var new_dice := _d([6, 6, 2, 3, 4, 5])
	var old_dice := _d([1, 2, 3, 4, 5, 6])
	assert_true(DiceScoring.is_strictly_better(new_dice, old_dice, _ids([]),
		no_mats, no_mats, no_mats, no_mats, levels),
		"die real punktträchtigere Hand zählt - kein Farkle")

# --- Kleine Helfer-APIs ------------------------------------------------------

func test_mult_for_known_and_unknown_keys():
	assert_eq(DiceScoring.mult_for("six_kind"), 15)
	assert_eq(DiceScoring.mult_for("not_a_category"), 1)

func test_label_for_falls_back_to_key():
	assert_eq(DiceScoring.label_for("nope"), "nope")

func test_qualifies_two_pair_needs_two_groups():
	assert_true(DiceScoring.qualifies("two_pair", _d([2,2,5,5,1,6])))
	assert_false(DiceScoring.qualifies("two_pair", _d([2,2,1,3,4,6])))

func test_example_dice_score_their_own_category():
	# Die Piktogramm-Beispiele der Bildschirmliste (siehe EXAMPLE_DICE/ComboCellView)
	# müssen echte Vertreter ihrer Kategorie sein: best_hand über genau diese
	# Würfel liefert genau den zugehörigen Key - sonst zeigt der Tisch ein Bild,
	# das die Wertung so nie einordnen würde.
	for key in DiceScoring.HAND_PRIORITY:
		assert_true(DiceScoring.EXAMPLE_DICE.has(key), "Beispiel fehlt für %s" % key)
		var example := _d(DiceScoring.EXAMPLE_DICE[key])
		assert_eq(DiceScoring.best_hand(example)["key"], key,
			"Beispiel %s wertet als seine eigene Kategorie" % key)

# --- Stresstest-Drossel (CTX_THROTTLED) --------------------------------------------

func test_throttled_category_scores_zero():
	var ctx := {DiceScoring.CTX_THROTTLED: _ids([DiceScoring.FOUR_KIND])}
	assert_gt(DiceScoring.score_category(DiceScoring.FOUR_KIND, _d([6, 6, 6, 6])), 0)
	assert_eq(DiceScoring.score_category(DiceScoring.FOUR_KIND, _d([6, 6, 6, 6]),
		[], false, [], [], {}, ctx), 0)

func test_best_hand_falls_back_past_the_throttle():
	# Vier Sechser mit gedrosseltem Viererpasch werten als Dreierpasch - die
	# Drossel schaltet die Kategorie ab, nicht die Würfel.
	var ctx := {DiceScoring.CTX_THROTTLED: _ids([DiceScoring.FOUR_KIND])}
	var hand := DiceScoring.best_hand(_d([6, 6, 6, 6]), [], false, [], [], {}, ctx)
	assert_eq(hand["key"], DiceScoring.THREE_KIND)

func test_best_hand_falls_past_two_throttled_categories():
	# Doppelbelastung schaltet zwei Chips ab - die Hand rutscht entsprechend tiefer.
	var ctx := {DiceScoring.CTX_THROTTLED: _ids([DiceScoring.FOUR_KIND, DiceScoring.THREE_KIND])}
	var hand := DiceScoring.best_hand(_d([6, 6, 6, 6]), [], false, [], [], {}, ctx)
	assert_eq(hand["key"], DiceScoring.TWO_KIND)

func test_best_hand_survives_a_throttled_fallback_category():
	# Nur Absicherung: hottest_combos drosselt "Höchste Zahl" nie, aber best_hand
	# darf auch dann nicht mit Score -1 enden.
	var ctx := {DiceScoring.CTX_THROTTLED: _ids([DiceScoring.ONE_KIND])}
	var hand := DiceScoring.best_hand(_d([4]), [], false, [], [], {}, ctx)
	assert_eq(int(hand["score"]), 0)
