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

## ctx mit einer Argon-Seele auf slot - seit dem Kanten-Umbau die Standard-Quelle
## zweier Auslösungen.
func _argon(slot: int) -> Dictionary:
	return {DiceScoring.CTX_ESSENCES: {slot: Essence.ARGON}}

# --- Augenwerte -------------------------------------------------------------------

func test_small_fry_gives_ten_base_points_on_ones_and_twos():
	assert_eq(CharmEffects.eye_value(1, _ids([Charm.SMALL_FRY])), 11)
	assert_eq(CharmEffects.eye_value(2, _ids([Charm.SMALL_FRY])), 12)
	assert_eq(CharmEffects.eye_value(5, _ids([Charm.SMALL_FRY])), 5)

func test_equalizer_floors_base_points_at_ten():
	assert_eq(CharmEffects.eye_value(1, _ids([Charm.EQUALIZER])), 10)
	assert_eq(CharmEffects.eye_value(6, _ids([Charm.EQUALIZER])), 10)
	assert_eq(CharmEffects.eye_value(14, _ids([Charm.EQUALIZER])), 14, "über dem Boden zählt der Wert")

func test_equalizer_never_changes_the_category():
	# Basispunkte ja, Kombination nein: ein Paar 1er bleibt ein Paar 1er.
	var hand := DiceScoring.best_hand(_d([1, 1, 2, 3, 4, 6]), _ids([Charm.EQUALIZER]))
	assert_eq(hand["key"], "two_kind")
	assert_eq(hand["score"], (10 + 10 + 10) * 2)

# --- Basis-Boni --------------------------------------------------------------------

func test_echo_chamber_retriggers_the_first_used_die():
	# Wie Quecksilber: der zuerst gewertete Würfel aktiviert sich ein zweites Mal.
	var ids := _ids([Charm.ECHO_CHAMBER])
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids)
	assert_eq(score, 50, "(10 + 5 + 5 + Echo 5) × Mult 2")

func test_echo_chamber_picks_the_first_slot_not_the_highest():
	# Zwei Paare: der vorderste gewertete Slot echot, nicht der höchste Wert.
	var ids := _ids([Charm.ECHO_CHAMBER])
	var bonus := MaterialEffects.base_bonus(_d([3, 3, 6, 6, 1, 2]), NO_MATS, _p([2, 3, 0, 1]), ids, 0)
	assert_eq(bonus, 3, "Slot 0 (die 3) echot, obwohl die 6 höher wäre")

func test_echo_chamber_also_fires_the_material_effects():
	# Rubin auf dem Echo-Slot zahlt doppelt - der Unterschied zum reinen Augen-Echo.
	var ids := _ids([Charm.ECHO_CHAMBER])
	var mats := _m([DieMaterial.RUBY, "", "", "", "", ""])
	var mult := MaterialEffects.mult_bonus(_d(PAIR), mats, _p([0, 1]), ids, 0)
	assert_eq(mult, 8, "+4 Rubin zweimal")
	var other_slot := MaterialEffects.mult_bonus(_d(PAIR), mats, _p([0, 1]), ids, 1)
	assert_eq(other_slot, 4, "echot ein anderer Slot, zahlt der Rubin einfach")

func test_twin_ring_adds_pair_value_to_mult():
	var bonus := CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.TWIN_RING]))
	assert_eq(bonus, 5, "nur die 5 liegt genau zweimal: +5 Mult")
	var two_pairs := CharmEffects.charm_mult_bonus(DiceScoring.TWO_PAIR, _d([5, 5, 3, 3, 1, 6]), NO_MATS, _ids([Charm.TWIN_RING]))
	assert_eq(two_pairs, 8, "zwei Paare (5 und 3): +8 Mult")

func test_twin_ring_pays_the_higher_value_of_a_graved_pair():
	# Gruppiert wird nach der Kombinationsziffer wie bei der Hand-Erkennung: 11 und
	# 31 sind ein Paar - und es zahlt die HÖHERE Augenzahl.
	var bonus := CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d([11, 31, 2, 3, 4, 6]),
		NO_MATS, _ids([Charm.TWIN_RING]))
	assert_eq(bonus, 31, "das Paar 11+31 zahlt 31")

func test_twin_ring_ignores_a_triple():
	# "Exaktes Paar" bleibt exakt: eine Dreiergruppe zahlt nichts.
	var bonus := CharmEffects.charm_mult_bonus(DiceScoring.THREE_KIND, _d([4, 4, 4, 1, 2, 6]),
		NO_MATS, _ids([Charm.TWIN_RING]))
	assert_eq(bonus, 0)

func test_twin_ring_slots_point_at_the_higher_die():
	# Eine Quelle für Wirkung UND Pulse: der Slot des höherwertigen Würfels des
	# Paars, bei Gleichstand der kleinere.
	assert_eq(CharmEffects.twin_pair_slots(_d([11, 31, 2, 3, 4, 6])), [1] as Array[int])
	assert_eq(CharmEffects.twin_pair_slots(_d([5, 5, 3, 3, 1, 6])), [0, 2] as Array[int])
	assert_eq(CharmEffects.twin_pair_slots(_d([4, 4, 4, 1, 2, 6])), [] as Array[int])

# Pro-Würfel-Charms feuern IM Würfel-Schritt (die_charm_*_at), nicht in der
# Charm-Phase - die Hooks bekommen den einzelnen beteiligten Slot.

func test_street_sweeper_only_boosts_straights():
	var straight := _d([1, 2, 3, 4, 5, 3])
	assert_eq(CharmEffects.die_charm_base_at(0, 2, DiceScoring.SMALL_STRAIGHT, straight, _ids([Charm.STREET_SWEEPER])), 6, "+6 je Straßen-Würfel")
	assert_eq(CharmEffects.die_charm_base_at(0, 0, DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.STREET_SWEEPER])), 0)

func test_full_counter_scores_all_lying_dice():
	# Vollzähler weitet die gewertete Menge auf ALLE Würfel: die unbeteiligten
	# 1+2+3+6 zählen mit (Differenz zur nackten Wertung = ihre Summe × Mult).
	var dice := _d(PAIR)
	var with_counter := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([Charm.FULL_COUNTER]))
	var plain := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]))
	assert_eq(with_counter - plain, 12 * 2, "1+2+3+6 außerhalb der Kombination, ×2 Mult")

func test_broadband_pays_per_combination_die():
	assert_eq(CharmEffects.die_charm_base_at(0, 0, DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.BROADBAND])), 5, "+5 am Würfel selbst")
	assert_eq(CharmEffects.die_charm_base(1, DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.BROADBAND])), 5)

func test_sediment_boosts_late_drawn_dice():
	# +3 Mult nur am beteiligten, spät gezogenen Würfel (der Hook sieht nur beteiligte Slots).
	var ids := _ids([Charm.SEDIMENT])
	assert_eq(CharmEffects.die_charm_mult_at(0, 0, _d(PAIR), ids, {"late_slots": [0, 5]}), 3)
	assert_eq(CharmEffects.die_charm_mult_at(0, 1, _d(PAIR), ids, {"late_slots": [0, 5]}), 0, "Slot 1 wurde früh gezogen")

func test_prime_time_pays_prime_faces_as_mult():
	# 2, 3, 5 sind prim - 1, 4, 6 nicht; Knochen-Seiten über 6 werden echt geprüft.
	var ids := _ids([Charm.PRIME_TIME])
	var dice := _d([1, 2, 3, 4, 5, 6])
	for slot in [1, 2, 4]:
		assert_eq(CharmEffects.die_charm_mult_at(0, slot, dice, ids), dice[slot], "Primzahl gibt ihre Augen")
	for slot in [0, 3, 5]:
		assert_eq(CharmEffects.die_charm_mult_at(0, slot, dice, ids), 0, "keine Primzahl, kein Mult")
	assert_eq(CharmEffects.die_charm_mult(0, _d([7, 7, 7, 7, 7, 7]), ids), 7, "gewachsene Seite (7) ist prim")
	assert_eq(CharmEffects.die_charm_mult(0, _d([9, 9, 9, 9, 9, 9]), ids), 0, "9 = 3×3")

func test_front_runner_loads_the_first_die_with_the_whole_eye_sum():
	# Paar Fünfer: der vorderste gewertete Würfel (Slot 0) trägt 5+5 = 10 extra.
	var ids := _ids([Charm.FRONT_RUNNER])
	var scored := _p([0, 1])
	assert_eq(CharmEffects.die_charm_base_at(0, 0, DiceScoring.TWO_KIND, _d(PAIR), ids, {}, scored), 10)
	assert_eq(CharmEffects.die_charm_base_at(0, 1, DiceScoring.TWO_KIND, _d(PAIR), ids, {}, scored), 0, "nur der erste Würfel")
	assert_eq(CharmEffects.die_charm_base_at(0, 0, DiceScoring.TWO_KIND, _d(PAIR), ids), 0, "ohne gewertete Slots nichts")
	# Ende-zu-Ende: (10 Punkte + 10 Augen + 10 Vorreiter) × Mult 2 = 60.
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids), 60)

func test_front_runner_follows_the_full_counter():
	# Vollzähler wertet ALLE Würfel - der Vorreiter trägt dann die ganze Grube.
	var ids := _ids([Charm.FRONT_RUNNER, Charm.FULL_COUNTER])
	var all := _p([0, 1, 2, 3, 4, 5])
	assert_eq(CharmEffects.die_charm_base_at(0, 0, DiceScoring.TWO_KIND, _d(PAIR), ids, {}, all), 22, "5+5+1+2+3+6")

# --- Mult-Boni ---------------------------------------------------------------------

func test_pendulum_reads_accumulated_mult_never_below_zero():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.PENDULUM]), {CharmEffects.CTX_PENDULUM: 4}), 4)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.PENDULUM]), {CharmEffects.CTX_PENDULUM: -3}), 0, "fällt nie unter 0")

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

func test_lighthouse_mult_follows_highest_counted_die():
	# Höchste Zahl 4: Mult 1 + 4 = 5, Basis (5 Punkte + 4 Augen) -> 45.
	var score := DiceScoring.score_category(DiceScoring.ONE_KIND, _d([1, 2, 3, 1, 2, 4]), _ids([Charm.LIGHTHOUSE]))
	assert_eq(score, 45, "Basis (5+4) × Mult (1+4)")

func test_lighthouse_also_lights_other_combinations():
	# Paar Fünfer: der Leuchtturm ist würfelgebunden und feuert MIT dem
	# höchsten gewerteten Würfel (+5 Mult an dessen Schritt).
	var ids := _ids([Charm.LIGHTHOUSE])
	assert_eq(CharmEffects.die_charm_target_mult_at(0, 0, _d(PAIR), ids, _p([0, 1])), 5)
	assert_eq(CharmEffects.die_charm_target_mult_at(0, 1, _d(PAIR), ids, _p([0, 1])), 0, "nur am Zielwürfel (Gleichstand: der erste)")
	# Nur GEWERTETE Würfel leuchten - die unbeteiligte 6 zählt nicht.
	assert_eq(CharmEffects.die_charm_target_mult_at(0, 0, _d([2, 2, 1, 3, 4, 6]), ids, _p([0, 1])), 2)
	assert_eq(CharmEffects.die_charm_target_mult_at(0, 5, _d([2, 2, 1, 3, 4, 6]), ids, _p([0, 1])), 0)

func test_flat_charms_pay_without_a_condition():
	# Hausjoker und Gratis Getränk hängen an keiner Kombination: Paar Fünfer,
	# Basis (10 + 10 Augen + 50) × Mult (2 + 4) = 420.
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.HOUSE_JOKER])), 4)
	assert_eq(CharmEffects.charm_base_bonus(DiceScoring.ONE_KIND, _d(PAIR), _p([0]), _ids([Charm.FREE_DRINK])), 50)
	var both := _ids([Charm.FREE_DRINK, Charm.HOUSE_JOKER])
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), both), 420)

func test_midas_glove_needs_the_full_hand():
	var ids := _ids([Charm.MIDAS_GLOVE])
	assert_true(CharmEffects.midas_applies(ids, 6))
	assert_false(CharmEffects.midas_applies(ids, 5), "fünf Würfel reichen nicht")
	assert_false(CharmEffects.midas_applies(_ids([]), 6), "ohne Charm passiert nichts")

func test_target_die_takes_the_first_match_on_a_tie():
	# Allgemeine Regel: meint ein Charm EINEN Würfel, gewinnt bei Gleichstand
	# der erste passende (kleinster Slot) - Paar Sechsen auf Slot 1 und 3.
	var dice := _d([2, 6, 4, 6, 1, 3])
	var all := _p([0, 1, 2, 3, 4, 5])
	assert_eq(CharmEffects.target_die(dice, all, true), 1, "höchster: erster Sechser")
	assert_eq(CharmEffects.target_die(dice, _p([1, 3]), true), 1)
	var lows := _d([3, 1, 5, 1, 6, 2])
	assert_eq(CharmEffects.target_die(lows, all, false), 1, "niedrigster: erste Eins")
	assert_eq(CharmEffects.target_die(dice, _p([]), true), -1, "ohne Kandidaten kein Ziel")

func test_tie_breaking_charms_name_the_first_die():
	# Hochstapler und Beherit lesen denselben Zielwürfel - die Zerlegung feuert
	# in DESSEN Würfel-Schritt, damit der Spieler sieht, WER ausgelöst hat.
	var dice := _d([6, 6, 2, 3, 4, 5])
	var stacker := ScoreBreakdown.build(DiceScoring.TWO_KIND, dice, _ids([Charm.HIGH_STACKER]))
	var step: Dictionary = stacker["die_steps"][0]
	assert_eq(int(step["slot"]), 0, "erster der beiden Sechser")
	assert_eq(step["die_charm_indices"], [0], "der Hochstapler feuert an diesem Würfel")
	var beherit := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d([4, 4, 1, 2, 3, 5]), _ids([Charm.BEHERIT]))
	var crit_step: Dictionary = beherit["die_steps"][0]
	assert_eq(int(crit_step["slot"]), 0, "erster der beiden Vierer")
	assert_eq(crit_step["crit_charm_indices"], [0])

func test_high_stacker_matches_the_highest_counted_die():
	var ids := _ids([Charm.HIGH_STACKER])
	assert_eq(CharmEffects.die_charm_target_mult_at(0, 0, _d(PAIR), ids, _p([0, 1])), 5)
	# Nur GEWERTETE Würfel zählen - die unbeteiligte 6 bleibt außen vor.
	assert_eq(CharmEffects.die_charm_target_mult_at(0, 0, _d([2, 2, 1, 3, 4, 6]), ids, _p([0, 1])), 2)

# --- Krit (multipliziert den AKTUELLEN Mult) ----------------------------------------

func test_beherit_crits_with_the_lowest_counted_die():
	# Würfelgebunden: der Krit feuert im Schritt des NIEDRIGSTEN gewerteten
	# Würfels - Slot 3 (4) und 5 (6) gewertet -> ×4 an Slot 3.
	var ids := _ids([Charm.BEHERIT])
	assert_eq(CharmEffects.die_charm_crit_at(0, 3, _d([1, 2, 3, 4, 5, 6]), ids, _p([3, 5])), 4, "Krit ×4 am Zielwürfel")
	assert_eq(CharmEffects.die_charm_crit_at(0, 5, _d([1, 2, 3, 4, 5, 6]), ids, _p([3, 5])), 1, "der höhere Würfel kritet nicht")
	assert_eq(CharmEffects.die_charm_crit_at(0, 0, _d([1, 2, 3, 4, 5, 6]), ids, _p([0, 5])), 1, "gewertete 1 = kein Krit")
	# Ende-zu-Ende: Paar Fünfer, Mult 2 × Krit 5 = 10 -> Basis 20 × 10 = 200.
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids), 200)

func test_gallows_humor_gives_crit_after_a_farkle():
	var ids := _ids([Charm.GALLOWS_HUMOR])
	assert_eq(CharmEffects.charm_crit_at(0, _d(PAIR), ids, {"after_farkle": true}), 4, "Krit ×4")
	assert_eq(CharmEffects.charm_crit_at(0, _d(PAIR), ids, {"after_farkle": false}), 1, "ohne Farkle kein Krit")
	# Ende-zu-Ende: Paar Fünfer, Mult 2 × Krit 4 = 8 -> Basis 20 × 8 = 160.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids, false, NO_MATS, {}, {"after_farkle": true})
	assert_eq(score, 160)

# --- Retrigger-Regel: würfelgebundene Charms feuern je Aktivierung ihres Würfels ----

func test_lighthouse_retriggers_with_its_die():
	# Argon auf dem Zielwürfel: Basis (10 + 5 + Nachzählung 5 + 5)
	# × Mult (2 + Leuchtturm 5 je Auslösung) = 25 × 12 = 300.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.LIGHTHOUSE]), false, NO_MATS, {}, _argon(0))
	assert_eq(score, 300)

func test_beherit_crits_once_per_activation_of_its_die():
	# Paar Vierer, Argon auf dem Zielwürfel: Basis (10 + 4 + 4 + 4)
	# × Mult (2 ×4 ×4) = 22 × 32 = 704.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([4, 4, 1, 2, 3, 5]), _ids([Charm.BEHERIT]), false, NO_MATS, {}, _argon(0))
	assert_eq(score, 704)

func test_per_die_charms_retrigger_with_their_die():
	# Breitband feuert je Auslösung seines Würfels: Basis (10 + (5+5)×2 + 5+5)
	# × Mult 2 = 40 × 2 = 80.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.BROADBAND]), false, NO_MATS, {}, _argon(0))
	assert_eq(score, 80)

# --- Basis-Boni & Faktoren -----------------------------------------------------------

func test_blackjack_pays_50_only_when_the_counted_dice_sum_to_21():
	# Große Straße: alle sechs zählen, Augensumme 1+2+3+4+5+6 = 21.
	var straight := _d([1, 2, 3, 4, 5, 6])
	assert_eq(CharmEffects.charm_base_bonus(DiceScoring.LARGE_STRAIGHT, straight, _p([0, 1, 2, 3, 4, 5]), _ids([Charm.BLACKJACK])), 50)
	# Nur das Paar zählt (12); die mitgenommenen 3 und 6 dürfen NICHT auf 21 aufaddieren.
	var padded := _d([6, 6, 3, 6, 1, 2])  # ganze Auswahl summiert 24, das Paar aber nur 12
	assert_eq(CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, padded, _p([0, 1]), _ids([Charm.BLACKJACK])), 0, "unbeteiligte Würfel zählen nicht mit")

func test_snake_eyes_converts_bystanders_to_mult():
	# Genau ein 1er-Paar genommen: Mult += Augensumme der Unbeteiligten (3+4+5+6).
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d([1, 1, 3, 4, 5, 6]), NO_MATS, _ids([Charm.SNAKE_EYES]), {}, _p([0, 1])), 18)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d([5, 5, 3, 4, 1, 6]), NO_MATS, _ids([Charm.SNAKE_EYES]), {}, _p([0, 1])), 0, "ein 5er-Paar sind keine Snake Eyes")

func test_cult_of_one_doubles_base_and_mult_per_one():
	# Paar Fünfer mit EINER 1: Basis 20×2 × Mult 2×2 = 160.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.CULT_OF_ONE]))
	assert_eq(score, 160)

func test_after_work_beer_doubles_the_base_and_crits_when_the_pool_is_empty():
	# Paar Fünfer: Basis 20×2 × (Mult 2, Krit ×2) = 160; mit Würfeln im Stapel nur 40.
	var ids := _ids([Charm.AFTER_WORK_BEER])
	var empty := {CharmEffects.CTX_POOL_EMPTY: true}
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids, false, NO_MATS, {}, empty), 160)
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids), 40)

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

func test_ruby_grinder_adds_the_face_value_to_the_ruby_mult():
	# Rubin auf der gewerteten 5: +4 fest + 5 Augen.
	var bonus := MaterialEffects.mult_bonus(_d(PAIR), _m([DieMaterial.RUBY, "", "", "", "", ""]), _p([0, 1]), _ids([Charm.RUBY_GRINDER]))
	assert_eq(bonus, 9)
	# Ohne den Schleifer bleibt es beim festen +4.
	var plain := MaterialEffects.mult_bonus(_d(PAIR), _m([DieMaterial.RUBY, "", "", "", "", ""]), _p([0, 1]))
	assert_eq(plain, 4)

func test_carbuncle_stacks_the_face_value_per_copy():
	# Blood Diamond wie der Schleifer (+5), aber je Exemplar erneut - und beide
	# zusammen legen zweimal die Augenzahl auf die festen +4.
	var mats := _m([DieMaterial.RUBY, "", "", "", "", ""])
	assert_eq(MaterialEffects.mult_bonus(_d(PAIR), mats, _p([0, 1]), _ids([Charm.BLOOD_DIAMOND])), 9)
	assert_eq(MaterialEffects.mult_bonus(_d(PAIR), mats, _p([0, 1]), _ids([Charm.BLOOD_DIAMOND, Charm.BLOOD_DIAMOND])), 14)
	assert_eq(MaterialEffects.mult_bonus(_d(PAIR), mats, _p([0, 1]), _ids([Charm.RUBY_GRINDER, Charm.BLOOD_DIAMOND])), 14)

func test_bone_marrow_stacks_the_triggers_per_copy():
	# Knochenmark verlängert nicht den Schritt, sondern die Zahl der Auslösungen.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]), _ids([Charm.BONE_MARROW]))
	assert_eq(defs[0].faces[0], 7, "zwei Auslösungen à +1")
	var twice: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	MaterialEffects.apply_take_effects(twice, _p([0]), _m([DieMaterial.BONE]), _p([0]),
		_ids([Charm.BONE_MARROW, Charm.BONE_MARROW, Charm.BONE_GLUE]))
	assert_eq(twice[0].faces[0], 11, "Leim setzt den Satz 2, zwei Marke machen 3 Auslösungen")

func test_mercury_vapor_lifts_every_retrigger_essence():
	# Das verbannte Material lebt als Verstärker weiter: es hebt JEDEN Essenz-
	# Faktor um eins - Argon 2 -> 3, Quecksilberdampf 3 -> 4.
	var vapor := _ids([Charm.MERCURY_VAPOR])
	assert_eq(EssenceEffects.activation_factor(Essence.ARGON, vapor), 3)
	assert_eq(EssenceEffects.activation_factor(Essence.MERCURY_VAPOR, vapor), 4)
	assert_eq(EssenceEffects.activation_factor(Essence.NEON, vapor), 1, "wer nicht stapelt, bleibt bei einmal")

func test_goldsmith_and_bone_glue_strengthen_takes():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m([DieMaterial.GOLD, DieMaterial.BONE]), _p([0, 1]), _ids([Charm.GOLDSMITH, Charm.BONE_GLUE]))
	assert_eq(report.money, 6, "Goldschmied zahlt $6")
	assert_eq(defs[1].faces[0], 7, "Knochenleim wächst +2")

func test_glassblower_lung_holds_the_glass_floor_at_six():
	var defs: Array[DieDefinition] = [_die([6, 2, 3, 4, 5, 6])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]), _ids([Charm.GLASSBLOWER_LUNG]))
	assert_eq(defs[0].faces[0], 6, "auf dem Boden bleibt die Seite stehen")
	var big: Array[DieDefinition] = [_die([8, 2, 3, 4, 5, 6])]
	MaterialEffects.apply_take_effects(big, _p([0]), _m([DieMaterial.GLASS]), _p([0]), _ids([Charm.GLASSBLOWER_LUNG]))
	assert_eq(big[0].faces[0], 7, "darüber schrumpft Glas weiter normal")

func test_goldsmith_lifts_every_gold_face():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6])]
	var faces := _m([DieMaterial.GOLD, DieMaterial.GOLD])
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), faces, _p([0, 1]), _ids([Charm.GOLDSMITH]))
	assert_eq(report.money, 12, "$6 je beteiligter Gold-Seite")

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
	assert_false(CharmEffects.gold_rush_applies(_ids([Charm.GOLD_RUSH]), 6, 6, false), "nur die erste Hand der Runde")

func test_gold_rush_grows_money_by_a_fifth_capped_at_fifty():
	assert_eq(CharmEffects.gold_rush_income(100), 20)
	assert_eq(CharmEffects.gold_rush_income(4), 0, "unter $5 wächst nichts")
	assert_eq(CharmEffects.gold_rush_income(1000), 50, "gedeckelt")

func test_rag_collector_counts_lucky_values():
	assert_eq(CharmEffects.rag_collector_income(_d([4, 4, 1, 4, 2, 3]), 4, _ids([Charm.RAG_COLLECTOR])), 12, "$4 je Treffer")
	assert_eq(CharmEffects.rag_collector_income(_d([4, 4, 1, 4, 2, 3]), 0, _ids([Charm.RAG_COLLECTOR])), 0, "ohne Glückszahl kein Geld")

func test_round_end_income_combines_sources_with_caps():
	# Zinsgroschen: $37 -> +3; Überflieger: 2 geräumte Stufen -> +10.
	var ids := _ids([Charm.INTEREST_PENNY, Charm.HIGH_FLYER])
	assert_eq(CharmEffects.round_end_income(37, 2, ids), 13)
	assert_eq(CharmEffects.round_end_income(9, 0, ids), 0)
	# Nur der Zinsgroschen ist gedeckelt - die Stufen deckelt der Balken selbst.
	assert_eq(CharmEffects.round_end_income(10000, 5, ids), 75, "Zinsen max. $50, Stufen 5×$5")

func test_high_flyer_pays_per_cleared_overcharge_stage():
	# Grundlage ist der BALKEN, nicht die geprägte Ladung: der Doppellader
	# verdoppelt die ⚡ je Stufe, ändert am Überflieger aber nichts.
	var ids := _ids([Charm.HIGH_FLYER])
	assert_eq(CharmEffects.round_end_income(0, 1, ids), 5)
	assert_eq(CharmEffects.round_end_income(0, 3, ids), 15)
	assert_eq(CharmEffects.round_end_income(0, 0, ids), 0, "ohne geräumte Stufe kein Geld")

func test_round_end_income_entries_name_the_paying_charm():
	# Grundlage der Auszahlungs-Zeremonie: je Posten die Besitz-Position.
	var ids := _ids([Charm.HORSESHOE, Charm.INTEREST_PENNY, Charm.HIGH_FLYER])
	var entries := CharmEffects.round_end_income_entries(37, 2, ids)
	assert_eq(entries.size(), 2, "das Hufeisen zahlt nichts")
	assert_eq(entries[0]["charm_index"], 1)
	assert_eq(entries[0]["charm_id"], Charm.INTEREST_PENNY)
	assert_eq(entries[0]["amount"], 3)
	assert_eq(entries[1]["charm_index"], 2)
	assert_eq(entries[1]["amount"], 10)

func test_income_entries_always_sum_to_the_total():
	# Zeremonie und Buchung dürfen nie auseinanderlaufen.
	var ids := _ids([Charm.INTEREST_PENNY, Charm.HIGH_FLYER, Charm.INTEREST_PENNY])
	for money in [0, 9, 37, 250, 10000]:
		var sum := 0
		for entry in CharmEffects.round_end_income_entries(money, 2, ids):
			sum += int(entry["amount"])
		assert_eq(sum, CharmEffects.round_end_income(money, 2, ids), "$%d" % money)

func test_income_entries_compound_between_charms():
	# Zinseszins: der zweite Zinsgroschen rechnet auf dem Stand, den der erste
	# schon gezahlt hat. $100 -> +$10 -> $110 -> +$11.
	var ids := _ids([Charm.INTEREST_PENNY, Charm.INTEREST_PENNY])
	var entries := CharmEffects.round_end_income_entries(100, 0, ids)
	assert_eq(entries[0]["amount"], 10)
	assert_eq(entries[1]["amount"], 11, "der zweite sieht die Zahlung des ersten")

func test_dock_order_decides_the_money_too():
	# Genau wie in der Wertung: die Reihenfolge im Dock verschiebt Beträge.
	var after := CharmEffects.round_end_income_entries(100, 0,
		_ids([Charm.OLD_PENNY, Charm.INTEREST_PENNY]))
	assert_eq(after[0]["amount"], 3, "Glücksgroschen zahlt $3")
	assert_eq(after[1]["amount"], 10, "$103 -> +$10")
	var before := CharmEffects.round_end_income_entries(100, 0,
		_ids([Charm.INTEREST_PENNY, Charm.OLD_PENNY]))
	assert_eq(before[0]["amount"], 10, "vor dem Glücksgroschen sieht er nur die $100")
	assert_eq(before[1]["amount"], 3)

func test_the_interest_cap_holds_per_copy():
	# Der Deckel gilt je Exemplar auf DESSEN Grundlage, nicht auf der Summe.
	var ids := _ids([Charm.INTEREST_PENNY, Charm.INTEREST_PENNY])
	var entries := CharmEffects.round_end_income_entries(10000, 0, ids)
	assert_eq(entries[0]["amount"], 50)
	assert_eq(entries[1]["amount"], 50)

func test_the_emergency_fund_tops_up_the_running_balance():
	# Er füllt auf, was NACH den Charms vor ihm noch fehlt - sonst ersetzte er
	# deren Zahlung, statt sie zu ergänzen.
	var late := CharmEffects.round_end_income_entries(10, 0,
		_ids([Charm.OLD_PENNY, Charm.EMERGENCY_FUND]))
	assert_eq(late[0]["amount"], 3, "Glücksgroschen zuerst")
	assert_eq(late[1]["amount"], 12, "$13 -> auffüllen auf $25")
	var early := CharmEffects.round_end_income_entries(10, 0,
		_ids([Charm.EMERGENCY_FUND, Charm.OLD_PENNY]))
	assert_eq(early[0]["amount"], 15, "$10 -> auffüllen auf $25")
	assert_eq(early[1]["amount"], 3, "und der Glücksgroschen legt obendrauf")

func test_a_full_purse_needs_no_emergency_fund():
	var entries := CharmEffects.round_end_income_entries(40, 0, _ids([Charm.EMERGENCY_FUND]))
	assert_eq(entries.size(), 0, "über dem Mindeststand zahlt er nichts")

func test_the_projected_end_total_matches_the_bookings():
	# Vorausrechnung und Buchungen dürfen nie auseinanderlaufen.
	var ids := _ids([Charm.INTEREST_PENNY, Charm.OLD_PENNY, Charm.INTEREST_PENNY, Charm.EMERGENCY_FUND])
	for start_money in [0, 7, 30, 100, 999]:
		var start: int = start_money
		var booked := start
		for entry in CharmEffects.round_end_income_entries(start, 1, ids):
			booked += int(entry["amount"])
		assert_eq(booked, start + CharmEffects.round_end_income(start, 1, ids), "$%d" % start)

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
	assert_eq(CharmEffects.pack_price(10, Pack.TYPE_NUMBER, _ids([Charm.BARGAIN_HUNTER])), 7)
	assert_eq(CharmEffects.pack_price(10, Pack.TYPE_DICE, _ids([Charm.BARGAIN_HUNTER])), 7, "jede Sorte")
	assert_eq(CharmEffects.pack_price(2, Pack.TYPE_MATERIAL, _ids([Charm.BARGAIN_HUNTER])), 1, "nie unter $1")
	assert_eq(CharmEffects.die_price(15, _ids([Charm.BULK_DISCOUNT]), 3), 10)
	assert_eq(CharmEffects.die_price(15, _ids([Charm.BULK_DISCOUNT]), 1), 15, "kein Rabatt auf Einzelwürfel")
	assert_almost_eq(CharmEffects.pack_refund_chance(_ids([Charm.FINE_PRINT])), 0.2, 0.001)

func test_seal_of_quality_forces_refinements():
	for offer in DiceOffer.roll_offers(DiceOffer.TEMPLATES.size(), _ids([Charm.SEAL_OF_QUALITY])):
		var die := offer.dice[0]
		var refined: bool = die.essence_id != "" or die.materials.count("") < die.materials.size()
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

func test_charm_slots_map_effects_back_to_their_holograms():
	# Ein wirkungsloses Totem faellt aus charm_ids() heraus - ohne Umrechnung
	# blitzte danach der falsche Charm.
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.parrot_totem())  # links ist nichts -> faellt raus
	run.owned_charms.append(Charm.high_flyer())
	assert_eq(run.charm_ids(), ["high_flyer"])
	assert_eq(run.charm_slots(), [1], "Ueberflieger sitzt auf Besitz-Slot 1")

func test_a_totem_flashes_its_own_slot_not_the_copied_one():
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.rabbits_foot())
	run.owned_charms.append(Charm.parrot_totem())
	assert_eq(run.charm_ids(), ["rabbits_foot", "rabbits_foot"])
	assert_eq(run.charm_slots(), [0, 1], "das Totem zeigt auf sich selbst")

func test_charm_slots_always_match_charm_ids():
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.echo_totem())
	run.owned_charms.append(Charm.horseshoe())
	run.owned_charms.append(Charm.echo_totem())  # rechts ist nichts
	assert_eq(run.charm_slots().size(), run.charm_ids().size())
	assert_eq(run.charm_slots(), [0, 1], "das wirkungslose Totem hinten faellt weg")

func test_round_start_resets_the_gravierstift_mark():
	var run := GameRun.new_run()
	run.gravierstift_used_this_round = true
	run.apply_round_start_charms()
	assert_false(run.gravierstift_used_this_round, "Gravierstift-Marke zurückgesetzt")

func test_stamp_machine_rolls_number_engravings_for_the_ceremony():
	# Die Rundenende-Zeremonie (scene_root) fliegt je Gravur einen Meteor und
	# grantet bei Ankunft - hier die Logik: jede gewürfelte Gravur ist eine
	# Zahl-Gravur, und erst grant_engraving legt sie in den Vorrat.
	var run := GameRun.new_run()
	assert_eq(run.owned_engravings.size(), 0)
	for i in GameRun.STAMP_ENGRAVINGS:
		var engraving := run.roll_stamp_engraving()
		assert_eq(engraving.category, Engraving.CATEGORY_NUMBER)
		assert_eq(run.owned_engravings.size(), i, "roll allein grantet nicht")
		run.grant_engraving(engraving)
	assert_eq(run.owned_engravings.size(), GameRun.STAMP_ENGRAVINGS)

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
	assert_eq(CharmEffects.die_charm_base(0, DiceScoring.TWO_KIND, _d(PAIR), twice), 10, "zweimal Breitband: +10 je Würfel")
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

func test_echo_chamber_respects_base_point_charms():
	# Kleinvieh hebt die Basispunkte einer 2 auf 12 - auch beim Echo-Nachzählen des
	# zuerst GEWERTETEN Würfels (hier das Paar Zweier).
	var bonus := MaterialEffects.base_bonus(_d([2, 2, 1, 3, 4, 6]), NO_MATS, _p([0, 1]), _ids([Charm.ECHO_CHAMBER, Charm.SMALL_FRY]), 0)
	assert_eq(bonus, 12, "Echo der gewerteten 2 zählt mit Kleinvieh als 12")

func test_full_counter_sees_transformed_values():
	# Glückszigaretten verwandeln VOR der Wertung: die unbeteiligte 1 IST eine 6,
	# der Vollzähler zählt sie entsprechend. End-to-end über score_category.
	var ids := _ids([Charm.FULL_COUNTER, Charm.LUCKY_CIGARETTES])
	# Paar 5er ohne echte 6 (sonst bildete die verwandelte 1 ein 6er-Paar und
	# das Paar wechselte); Unbeteiligte nach Verwandlung 6+2+3+4 = 15 statt 10.
	var dice := _d([5, 5, 1, 2, 3, 4])
	var with_charms := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, ids)
	var only_counter := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([Charm.FULL_COUNTER]))
	assert_eq(with_charms - only_counter, (15 - 10) * 2, "die verwandelte 1 zählt als 6")

# --- Kombinierte Shop-Preise ---------------------------------------------------------

func test_refund_chance_caps_at_eighty_percent():
	var five := _ids([Charm.FINE_PRINT, Charm.FINE_PRINT, Charm.FINE_PRINT, Charm.FINE_PRINT, Charm.FINE_PRINT])
	assert_almost_eq(CharmEffects.pack_refund_chance(five), 0.8, 0.001)

# --- GameRun: Kauf-Verfolgung ---------------------------------------------------------

func test_purchased_dice_land_in_the_pool_as_independent_copies():
	var run := GameRun.new_run()
	run.money = 100
	var offer_die := DieDefinition.fixed(6, "Sechser")
	var bundle: Array[DieDefinition] = [offer_die, offer_die.instantiate()]
	run.purchase_dice(bundle, 20)
	var bought := 0
	for def in run.owned_pool:
		if def.style_id == "fixed_6":
			bought += 1
			assert_false(bundle.has(def), "Pool hält eine eigene Kopie, nicht die Auslage")
	assert_eq(bought, 2)

# --- Wertungs-Reihenfolge: Faktoren wirken an ihrer Besitz-Position ----------------

func test_factor_charms_apply_at_their_dock_position():
	# KEINE Ausnahmen von der Trigger-Reihenfolge: Feierabendbier vor Runde Sache
	# verdoppelt nur die 20 Basis (40 + 100 = 140, ×4 Mult inkl. Krit = 560);
	# dahinter verdoppelt es auch den +100-Bonus ((20+100)×2 = 240, ×4 = 960).
	var ctx := {CharmEffects.CTX_POOL_EMPTY: true}
	var beer_first := _ids([Charm.AFTER_WORK_BEER, Charm.ROUND_NUMBER])
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), beer_first, false, NO_MATS, {}, ctx), 560)
	var beer_last := _ids([Charm.ROUND_NUMBER, Charm.AFTER_WORK_BEER])
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), beer_last, false, NO_MATS, {}, ctx), 960)

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
	randomize()  # der feste Seed darf nicht in spätere Test-Skripte lecken

func test_owned_charms_weigh_half():
	# Besitz dämpft das Ziehgewicht, sperrt aber nichts - der Archetyp bleibt
	# in der Auslage möglich.
	var charm := Charm.rabbits_foot()
	assert_eq(charm.pick_weight(), charm.rarity_weight(), "unbesessen: volles Raritätsgewicht")
	assert_almost_eq(charm.pick_weight(_ids([Charm.RABBITS_FOOT])),
		charm.rarity_weight() * Charm.OWNED_WEIGHT_FACTOR, 0.0001)
	assert_almost_eq(charm.pick_weight(_ids([Charm.HORSESHOE])), charm.rarity_weight(), 0.0001,
		"fremder Besitz ändert nichts")

func test_pick_weighted_still_returns_an_owned_only_pool():
	# Alles besessen: die Gewichte sinken gleichmäßig, die Ziehung bleibt gültig.
	var candidates: Array[Charm] = [Charm.rabbits_foot(), Charm.horseshoe()]
	var owned := _ids([Charm.RABBITS_FOOT, Charm.HORSESHOE])
	for i in 20:
		assert_true(owned.has(Charm.pick_weighted(candidates, owned).id))
