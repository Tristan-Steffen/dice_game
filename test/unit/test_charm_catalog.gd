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

func test_small_fry_pays_base_and_mult_on_ones_and_twos():
	# BEIDE Anteile entspringen dem Charm - das Auge bleibt unberührt.
	assert_eq(CharmEffects.eye_value(1, _ids([Charm.SMALL_FRY])), 1)
	assert_eq(CharmEffects.eye_value(2, _ids([Charm.SMALL_FRY])), 2)
	var ids := _ids([Charm.SMALL_FRY])
	var dice := _d([1, 1, 3, 4, 5, 6])
	assert_eq(CharmEffects.die_charm_base_at(0, 0, DiceScoring.TWO_KIND, dice, ids), CharmEffects.SMALL_FRY_BASE)
	assert_eq(CharmEffects.die_charm_base_at(0, 4, DiceScoring.TWO_KIND, dice, ids), 0, "nur 1 und 2")
	assert_eq(CharmEffects.die_charm_mult_at(0, 0, dice, ids), CharmEffects.SMALL_FRY_MULT)
	assert_eq(CharmEffects.die_charm_mult_at(0, 4, dice, ids), 0, "nur 1 und 2")

func test_small_fry_stacks_on_the_equalizer_floor():
	# Der Equalizer hebt die AUGEN auf 10, Kleinvieh legt seine 5 daneben.
	var ids := _ids([Charm.EQUALIZER, Charm.SMALL_FRY])
	var dice := _d([1, 1])
	assert_eq(CharmEffects.eye_value(1, ids), CharmEffects.EQUALIZER_FLOOR)
	assert_eq(CharmEffects.die_charm_base_at(1, 0, DiceScoring.TWO_KIND, dice, ids), CharmEffects.SMALL_FRY_BASE)

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

func test_twin_ring_crits_by_the_number_of_pairs():
	var ids := _ids([Charm.TWIN_RING])
	assert_eq(CharmEffects.charm_crit_at(0, _d(PAIR), ids), 2.0, "ein Paar: Krit ×2")
	assert_eq(CharmEffects.charm_crit_at(0, _d([5, 5, 3, 3, 1, 6]), ids), 3.0, "zwei Paare: ×3")
	assert_eq(CharmEffects.charm_crit_at(0, _d([5, 5, 3, 3, 1, 1]), ids), 4.0, "drei Paare: ×4")
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, ids), 0,
		"kein Mult-Bonus mehr - der Ring kritet")

func test_twin_ring_counts_a_graved_pair():
	# Gruppiert wird nach der Kombinationsziffer wie bei der Hand-Erkennung: 11 und
	# 31 sind ein Paar.
	assert_eq(CharmEffects.charm_crit_at(0, _d([11, 31, 2, 3, 4, 6]), _ids([Charm.TWIN_RING])), 2.0)

func test_twin_ring_ignores_a_triple():
	# "Exaktes Paar" bleibt exakt: eine Dreiergruppe ist kein Krit.
	assert_eq(CharmEffects.charm_crit_at(0, _d([4, 4, 4, 1, 2, 6]), _ids([Charm.TWIN_RING])), 1.0)

func test_twin_ring_slots_point_at_the_lower_die():
	# Eine Quelle für Wirkung UND Pulse: der Slot des niedrigeren Würfels des
	# Paars, bei Gleichstand der kleinere.
	assert_eq(CharmEffects.twin_pair_slots(_d([11, 31, 2, 3, 4, 6])), [0] as Array[int])
	assert_eq(CharmEffects.twin_pair_slots(_d([5, 5, 3, 3, 1, 6])), [0, 2] as Array[int])
	assert_eq(CharmEffects.twin_pair_slots(_d([4, 4, 4, 1, 2, 6])), [] as Array[int])

# Pro-Würfel-Charms feuern IM Würfel-Schritt (die_charm_*_at), nicht in der
# Charm-Phase - die Hooks bekommen den einzelnen beteiligten Slot.

func test_street_sweeper_only_boosts_straights():
	var straight := _d([1, 2, 3, 4, 5, 3])
	assert_eq(CharmEffects.die_charm_base_at(0, 2, DiceScoring.SMALL_STRAIGHT, straight, _ids([Charm.STREET_SWEEPER])), 15, "+15 je Straßen-Würfel")
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
	# +4 Mult nur am beteiligten, spät gezogenen Würfel (der Hook sieht nur beteiligte Slots).
	var ids := _ids([Charm.SEDIMENT])
	assert_eq(CharmEffects.die_charm_mult_at(0, 0, _d(PAIR), ids, {"late_slots": [0, 5]}), 4)
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

func test_is_prime_stays_exact_after_the_memoization():
	# Der 6k±1-Schritt und der Merker dürfen kein Ergebnis verschieben - gegen die
	# naive Probedivision geprüft, zweimal (kalt und aus dem Merker).
	for value in range(-3, 200):
		var expected := _naive_prime(value)
		assert_eq(CharmEffects.is_prime(value), expected, "is_prime(%d)" % value)
		assert_eq(CharmEffects.is_prime(value), expected, "gemerkt: is_prime(%d)" % value)
	# Knochengewachsene Seiten reichen in die Milliarden - dort ist die Wurzelsuche
	# teuer und der Merker der Grund für den Umbau.
	assert_true(CharmEffects.is_prime(1000000007))
	assert_false(CharmEffects.is_prime(1000000008))
	assert_true(CharmEffects.is_prime(999999937))
	assert_false(CharmEffects.is_prime(999999939), "3 × 333333313")

## Probedivision ohne Tricks - der Maßstab für den Test oben.
func _naive_prime(value: int) -> bool:
	if value < 2:
		return false
	var d := 2
	while d * d <= value:
		if value % d == 0:
			return false
		d += 1
	return true

func test_front_runner_pays_the_whole_pit_once():
	# Statisch an seiner Dock-Position: die Augensumme ALLER liegenden Würfel,
	# gewertet oder nicht (5+5+1+2+3+6 = 22).
	var ids := _ids([Charm.FRONT_RUNNER])
	assert_eq(CharmEffects.charm_base_bonus_at(0, DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), ids), 22)
	assert_eq(CharmEffects.die_charm_base_at(0, 0, DiceScoring.TWO_KIND, _d(PAIR), ids, {}, _p([0, 1])), 0,
		"kein würfelgebundener Anteil mehr")
	# Ende-zu-Ende: (10 Punkte + 10 Augen + 22 Vorreiter) × Mult 2 = 84.
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids), 84)

func test_front_runner_does_not_care_about_the_full_counter():
	# Er zählt ohnehin die ganze Grube - der Vollzähler ändert an SEINEM Anteil nichts.
	var plain := CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]),
		_ids([Charm.FRONT_RUNNER]))
	var counted := CharmEffects.charm_base_bonus(DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1, 2, 3, 4, 5]),
		_ids([Charm.FRONT_RUNNER, Charm.FULL_COUNTER]))
	assert_eq(plain, 22)
	assert_eq(counted, 22)

# --- Mult-Boni ---------------------------------------------------------------------

func test_pendulum_reads_accumulated_mult_never_below_zero():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.PENDULUM]), {CharmEffects.CTX_PENDULUM: 4}), 4)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.PENDULUM]), {CharmEffects.CTX_PENDULUM: -3}), 0, "fällt nie unter 0")

func test_all_or_nothing_stacks_full_rerolls():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.ALL_OR_NOTHING]), {"full_rerolls": 1}), 15)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.ALL_OR_NOTHING]), {"full_rerolls": 3}), 45, "stapelt bis zum Nehmen")
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.ALL_OR_NOTHING]), {}), 0)

func test_momentum_follows_the_streak():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.MOMENTUM]), {"streak": 3}), 6)

func test_broken_mirror_stacks_with_farkles():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.BROKEN_MIRROR]), {"farkle_stacks": 4}), 4)

func test_parity_charms_check_the_whole_roll():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d([2, 2, 4, 6, 6, 4]), NO_MATS, _ids([Charm.EVEN_COMPANY])), 8)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.EVEN_COMPANY])), 0)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d([1, 1, 3, 5, 5, 3]), NO_MATS, _ids([Charm.ODD_PATH])), 8)

func test_hermit_crab_wants_few_charms():
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.HERMIT_CRAB])), 6)
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.HERMIT_CRAB, Charm.HORSESHOE, Charm.LADYBUG])), 0, "drei Charms sind zu viele")

func test_display_case_counts_face_up_materials():
	var materials := _m(["", "", DieMaterial.RUBY, DieMaterial.AMBER, "", ""])
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), materials, _ids([Charm.DISPLAY_CASE])),
		2 * CharmEffects.DISPLAY_CASE_MULT)

func test_display_case_pays_more_for_a_doped_side():
	# Veredelt zählt die Seite MEHR, nicht zusätzlich: 6 statt 2.
	var materials := _m(["", "", DieMaterial.RUBY, DieMaterial.AMBER, "", ""])
	var ctx := {DiceScoring.CTX_MATERIAL_LEVELS: {3: {"level": DieMaterial.MAX_LEVEL, "eye_sum": 0}}}
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), materials,
		_ids([Charm.DISPLAY_CASE]), ctx),
		CharmEffects.DISPLAY_CASE_MULT + CharmEffects.DISPLAY_CASE_DOPED_MULT)

func test_high_stacker_mult_follows_highest_counted_die():
	# Höchste Zahl 4: Mult 1 + 4 = 5, Basis (5 Punkte + 4 Augen) -> 45.
	var score := DiceScoring.score_category(DiceScoring.ONE_KIND, _d([1, 2, 3, 1, 2, 4]), _ids([Charm.HIGH_STACKER]))
	assert_eq(score, 45, "Basis (5+4) × Mult (1+4)")

func test_high_stacker_also_lights_other_combinations():
	# Paar Fünfer: der Hochstapler ist würfelgebunden und feuert MIT dem
	# höchsten gewerteten Würfel (+5 Mult an dessen Schritt).
	var ids := _ids([Charm.HIGH_STACKER])
	assert_eq(CharmEffects.die_charm_target_mult_at(0, 0, _d(PAIR), ids, _p([0, 1])), 5)
	assert_eq(CharmEffects.die_charm_target_mult_at(0, 1, _d(PAIR), ids, _p([0, 1])), 0, "nur am Zielwürfel (Gleichstand: der erste)")
	# Nur GEWERTETE Würfel leuchten - die unbeteiligte 6 zählt nicht.
	assert_eq(CharmEffects.die_charm_target_mult_at(0, 0, _d([2, 2, 1, 3, 4, 6]), ids, _p([0, 1])), 2)
	assert_eq(CharmEffects.die_charm_target_mult_at(0, 5, _d([2, 2, 1, 3, 4, 6]), ids, _p([0, 1])), 0)

func test_flat_charms_pay_without_a_condition():
	# Hausjoker und Freigetränk hängen an keiner Kombination: Paar Fünfer,
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
	# Der Hochstapler ist würfelgebunden und feuert in DESSEN Schritt, damit der
	# Spieler sieht, WER ausgelöst hat.
	var dice := _d([6, 6, 2, 3, 4, 5])
	var stacker := ScoreBreakdown.build(DiceScoring.TWO_KIND, dice, _ids([Charm.HIGH_STACKER]))
	var step: Dictionary = stacker["die_steps"][0]
	assert_eq(int(step["slot"]), 0, "erster der beiden Sechser")
	assert_eq(step["die_charm_indices"], [0], "der Hochstapler feuert an diesem Würfel")
	# Beherit zielt auf dieselbe Weise, schlägt aber statisch am Ende zu - und erst
	# ab drei gewerteten Würfeln, darum ein Dreierpasch.
	var beherit := ScoreBreakdown.build(DiceScoring.THREE_KIND, _d([4, 4, 4, 1, 2, 3]), _ids([Charm.BEHERIT]))
	for die_step: Dictionary in beherit["die_steps"]:
		assert_eq(die_step["crit_charm_indices"], [], "kein Krit mehr in der Würfelphase")
	var charm_steps: Array = beherit["charm_steps"]
	assert_eq(charm_steps.size(), 1, "ein statischer Krit-Schritt")
	assert_almost_eq(float(charm_steps[0]["crit_x"]), 5.0, 0.0001, "1 + niedrigste gewertete 4")

func test_high_stacker_matches_the_highest_counted_die():
	var ids := _ids([Charm.HIGH_STACKER])
	assert_eq(CharmEffects.die_charm_target_mult_at(0, 0, _d(PAIR), ids, _p([0, 1])), 5)
	# Nur GEWERTETE Würfel zählen - die unbeteiligte 6 bleibt außen vor.
	assert_eq(CharmEffects.die_charm_target_mult_at(0, 0, _d([2, 2, 1, 3, 4, 6]), ids, _p([0, 1])), 2)

## Krypton auf dem letzten Slot: er zählt mit, gehört aber nicht zur Kombination.
func _krypton_tail() -> Dictionary:
	return {DiceScoring.CTX_ESSENCES: {5: Essence.KRYPTON}}

func test_high_stacker_reaches_past_the_combination():
	# Paar Fünfer, die 6 auf Slot 5 zählt über Krypton mit: der Hochstapler meint
	# die GEWERTETE Menge, also die 6 - Basis (10 + 5+5+6) × Mult (2 + 6).
	var ids := _ids([Charm.HIGH_STACKER])
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids, false, NO_MATS, {}, _krypton_tail()),
		26 * 8, "der Hochstapler steigt auf den Krypton")
	# Kontrolle ohne Seele: nur die beiden Fünfer zählen.
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids), 20 * 7)

func test_high_stacker_fires_on_the_krypton_step():
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.HIGH_STACKER]),
		false, NO_MATS, {}, _krypton_tail())
	var fired: Array[int] = []
	for step: Dictionary in breakdown["die_steps"]:
		if not (step["die_charm_indices"] as Array).is_empty():
			fired.append(int(step["slot"]))
	assert_eq(fired, [5], "der Hochstapler feuert am Krypton-Würfel")

# --- Fallhöhe: die Spanne der gewerteten Hand ---------------------------------------

func test_drop_height_pays_the_spread_of_the_scored_hand():
	var ids := _ids([Charm.DROP_HEIGHT])
	assert_eq(CharmEffects.charm_mult_bonus_at(0, DiceScoring.TWO_PAIR, _d([1, 3, 3, 6]), NO_MATS,
		ids, {}, _p([]), _p([0, 1, 2, 3])), 5, "6 minus 1")
	assert_eq(CharmEffects.charm_mult_bonus_at(0, DiceScoring.ONE_KIND, _d([1, 3, 3, 6]), NO_MATS,
		ids, {}, _p([]), _p([2])), 0, "ein Würfel hat keine Spanne")
	assert_eq(CharmEffects.charm_mult_bonus_at(0, DiceScoring.TWO_KIND, _d([4, 4]), NO_MATS,
		ids, {}, _p([]), _p([0, 1])), 0, "gleiche Augen, keine Spanne")

func test_drop_height_grows_with_the_scored_set():
	# Paar Fünfer ohne Seele: Spanne 0. Mit Krypton zählt die 6 mit -> Spanne 1.
	var ids := _ids([Charm.DROP_HEIGHT])
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids), 20 * 2, "5 und 5 liegen gleich")
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids, false, NO_MATS, {}, _krypton_tail()),
		26 * 3, "6 minus 5 = +1 Mult")

# --- Inventur: die Material-Seiten des ganzen Pools ---------------------------------

func test_inventory_pays_per_painted_face_in_the_pool():
	var ids := _ids([Charm.INVENTORY])
	var ctx := {DiceScoring.CTX_POOL_MATERIALS: 7}
	assert_eq(CharmEffects.charm_base_bonus_at(0, DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), ids, ctx),
		7 * CharmEffects.INVENTORY_BASE_PER_MATERIAL)
	assert_eq(CharmEffects.charm_base_bonus_at(0, DiceScoring.TWO_KIND, _d(PAIR), _p([0, 1]), ids, {}), 0,
		"unbemalter Pool zahlt nichts")
	# Im Zug: Basis (10 + 10 Augen + 14) × Mult 2.
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids, false, NO_MATS, {}, ctx), 34 * 2)

# --- Krit (multipliziert den AKTUELLEN Mult) ----------------------------------------

func test_beherit_crits_with_the_lowest_counted_die():
	# Statisch am Ende der Zählung: Krit ×(1 + niedrigste GEWERTETE Augenzahl) -
	# Slot 3 (4), 4 (5) und 5 (6) gewertet -> ×5.
	var ids := _ids([Charm.BEHERIT])
	var dice := _d([1, 2, 3, 4, 5, 6])
	assert_almost_eq(CharmEffects.charm_crit_at(0, dice, ids, {}, _p([3, 4, 5]), "", _p([3, 4, 5])), 5.0, 0.0001)
	assert_almost_eq(CharmEffects.charm_crit_at(0, dice, ids, {}, _p([0, 4, 5]), "", _p([0, 4, 5])), 2.0, 0.0001,
		"die gewertete 1 kritet nur noch ×2")
	assert_almost_eq(CharmEffects.charm_crit_at(0, dice, ids, {}, _p([]), "", _p([])), 1.0, 0.0001,
		"ohne gewerteten Würfel kein Krit")
	# Ende-zu-Ende: Dreierpasch Vierer, Basis (18 + 12) × Mult (3 × Krit 5) = 450.
	assert_eq(DiceScoring.score_category(DiceScoring.THREE_KIND, _d([4, 4, 4, 1, 2, 3]), ids), 450)

func test_beherit_stays_silent_below_three_counted_dice():
	# Ein blankes Paar ruft nichts: Basis 20 × Mult 2 = 40, kein Krit.
	var ids := _ids([Charm.BEHERIT])
	var dice := _d([1, 2, 3, 4, 5, 6])
	assert_almost_eq(CharmEffects.charm_crit_at(0, dice, ids, {}, _p([3, 5]), "", _p([3, 5])), 1.0, 0.0001,
		"zwei gewertete Würfel sind zu wenig")
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids), 40)

func test_beherit_counts_the_dice_krypton_pulls_in():
	# Die Schwelle misst die GEWERTETE Menge: das Paar plus den Krypton-Würfel sind
	# drei - gezielt wird weiter auf die Kombination (niedrigste 4 -> ×5).
	var ids := _ids([Charm.BEHERIT])
	var dice := _d([1, 2, 3, 4, 5, 6])
	assert_almost_eq(CharmEffects.charm_crit_at(0, dice, ids, {}, _p([3, 5]), "", _p([1, 3, 5])), 5.0, 0.0001)
	# Ende-zu-Ende: Paar Vierer + Krypton auf der 1 -> Basis (10 + 4 + 4 + 1) × (2 × 5).
	var ctx := {DiceScoring.CTX_ESSENCES: {2: Essence.KRYPTON}}
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([4, 4, 1, 2, 3, 5]), ids, false, NO_MATS, {}, ctx), 190)

func test_beherit_reads_the_settled_value_not_the_running_one():
	# Er feuert NACH allen Würfeln: der Knochen ist längst gewachsen, gezählt wird
	# trotzdem die liegende 4 - ×5, nie ×7 aus dem Zwischenstand.
	var ids := _ids([Charm.BEHERIT])
	var mats := _m([DieMaterial.BONE, "", "", "", "", ""])
	var breakdown := ScoreBreakdown.build(DiceScoring.THREE_KIND, _d([4, 4, 4, 1, 2, 3]), ids,
		false, mats, {}, _argon(0))
	var charm_steps: Array = breakdown["charm_steps"]
	assert_eq(charm_steps.size(), 1)
	assert_almost_eq(float(charm_steps[0]["crit_x"]), 5.0, 0.0001)

# --- Die Verwandlung gilt für ALLES: Zielwahl, Gleichstand, Betrag -----------------
# Ein Fuchsschwanz macht aus der 3 eine 4 - für Reihenfolge, Zielwahl und jeden
# Betrag IST sie eine 4. Die Linse ist die Wahrheit, nur die Def bleibt roh.

func test_beherit_targets_and_pays_on_transformed_values():
	# Roh [3, 4, 4]: mit Fuchsschwanz zeigen ALLE DREI eine 4 - Gleichstand, also
	# der kleinste Slot, und der Krit ist ×5 (nie ×4 aus der rohen 3).
	var ids := _ids([Charm.FOX_TAIL, Charm.BEHERIT])
	var shown := DiceScoring.shown_values(_d([3, 4, 4]), ids)
	assert_eq(shown, _d([4, 4, 4]), "die 3 IST eine 4")
	assert_eq(CharmEffects.target_die(shown, _p([0, 1, 2]), false), 0, "Gleichstand -> kleinster Slot")
	assert_almost_eq(CharmEffects.charm_crit_at(1, shown, ids, {}, _p([0, 1, 2]), "", _p([0, 1, 2])), 5.0, 0.0001)
	# Ende-zu-Ende: Dreierpasch Vierer (Basis 18 + 12) × Mult 3 × Krit 5 = 450.
	assert_eq(DiceScoring.score_category(DiceScoring.THREE_KIND, _d([3, 4, 4]), ids), 450)

func test_high_stacker_ties_break_on_transformed_values():
	# Roh [5, 6]: mit dem Silberdollar zeigen beide eine 6 - der Hochstapler nimmt
	# den kleinsten Slot, nicht die natürliche 6.
	var ids := _ids([Charm.SILVER_DOLLAR, Charm.HIGH_STACKER])
	var shown := DiceScoring.shown_values(_d([5, 6]), ids)
	assert_eq(shown, _d([6, 6]))
	assert_eq(CharmEffects.target_die(shown, _p([0, 1]), true), 0, "Gleichstand -> kleinster Slot")
	assert_eq(CharmEffects.die_charm_target_mult_at(1, 0, shown, ids, _p([0, 1])), 6)
	assert_eq(CharmEffects.die_charm_target_mult_at(1, 1, shown, ids, _p([0, 1])), 0)

func test_front_runner_sums_transformed_values():
	# Vorreiter zählt die Augensumme der Grube - auf den GEZEIGTEN Werten.
	var ids := _ids([Charm.FOX_TAIL, Charm.FRONT_RUNNER])
	var shown := DiceScoring.shown_values(_d([3, 3]), ids)
	assert_eq(CharmEffects.charm_base_bonus_at(1, DiceScoring.TWO_KIND, shown, _p([0, 1]), ids), 8,
		"4 + 4, nicht 3 + 3")

func test_transformed_hands_keep_breakdown_and_score_in_step():
	# Die Schrittliste spiegelt die Formel 1:1 - auch durch die Linse.
	var cases := [
		[_d([3, 4]), [Charm.FOX_TAIL, Charm.BEHERIT]],
		[_d([5, 6]), [Charm.SILVER_DOLLAR, Charm.HIGH_STACKER]],
		[_d([3, 3]), [Charm.FOX_TAIL, Charm.FRONT_RUNNER]],
		[_d([1, 1, 2, 3, 4, 6]), [Charm.LUCKY_CIGARETTES, Charm.BEHERIT, Charm.SMALL_FRY]],
	]
	for case in cases:
		var dice: Array[int] = case[0]
		var ids := _ids(case[1])
		var key: String = DiceScoring.best_hand(dice, ids)["key"]
		var breakdown := ScoreBreakdown.build(key, dice, ids)
		assert_eq(int(breakdown["total"]), DiceScoring.score_category(key, dice, ids),
			"Schrittliste == Wertung (%s)" % str(case[1]))

# --- Schutzgeld: Aufschlag auf jeden gezeigten Wert, Gebühr beim Nehmen --------------

func test_protection_money_lifts_every_shown_value():
	var ids := _ids([Charm.PROTECTION_MONEY])
	assert_eq(CharmEffects.shown_by_charms(4, ids), 14)
	assert_eq(CharmEffects.shown_by_charms(4, _ids([Charm.PROTECTION_MONEY, Charm.PROTECTION_MONEY])), 24,
		"je Vorkommen erneut")
	assert_eq(CharmEffects.shown_by_charms(4, _ids([])), 4)

func test_protection_money_runs_after_the_transform_chain():
	# Erst die Kette (3 -> 4), dann der Aufschlag: 14, nicht 13.
	var ids := _ids([Charm.FOX_TAIL, Charm.PROTECTION_MONEY])
	assert_eq(CharmEffects.shown_by_charms(3, ids), 14)

func test_protection_money_leaves_the_detection_alone():
	# +10 ist ein Vielfaches von zehn - die Kombinationsziffer (%10) bleibt, also
	# bleibt auch die Erkennung, wo sie war.
	var ids := _ids([Charm.PROTECTION_MONEY])
	var straight := _d([1, 2, 3, 4, 5, 5])
	assert_eq(DiceScoring.best_hand(straight, _ids([]))["key"], DiceScoring.SMALL_STRAIGHT)
	assert_eq(DiceScoring.best_hand(straight, ids)["key"], DiceScoring.SMALL_STRAIGHT)

func test_protection_money_feeds_the_retrigger_charms():
	# Die Hasenpfote prüft den GEZEIGTEN Wert - eine 6 wird zur 16 und ist keine
	# 6 mehr; erst die verwandelte 1 (Glückszigaretten) trägt sie wieder.
	var ids := _ids([Charm.PROTECTION_MONEY, Charm.RABBITS_FOOT])
	var shown := DiceScoring.shown_values(_d([3, 3]), ids)
	assert_eq(shown, _d([13, 13]))
	assert_eq(MaterialEffects.face_trigger_count(shown[0], ids), 1)

func test_protection_money_charges_a_flat_fee_per_copy():
	# Flach je Hand und Exemplar, unabhängig davon, wie viele Würfel zählen.
	var one := _ids([Charm.PROTECTION_MONEY])
	assert_eq(CharmEffects.charm_fee_at(0, one), CharmEffects.PROTECTION_FEE)
	var two := _ids([Charm.PROTECTION_MONEY, Charm.HOUSE_JOKER])
	assert_eq(CharmEffects.charm_fee_at(1, two), 0, "andere Charms zahlen nichts")
	var both := _ids([Charm.PROTECTION_MONEY, Charm.PROTECTION_MONEY])
	assert_eq(CharmEffects.charm_fee_at(0, both) + CharmEffects.charm_fee_at(1, both),
		2 * CharmEffects.PROTECTION_FEE, "zwei Positionen, zwei Gebühren")

func test_the_protection_fee_rides_its_own_charm_step():
	# Die Gebühr bekommt einen Schritt (damit ihr Pad blitzt), rührt aber weder
	# Basis noch Mult noch die Summe an.
	var ids := _ids([Charm.PROTECTION_MONEY])
	var dice := _d(PAIR)
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, dice, ids)
	var fee_steps := 0
	for step: Dictionary in breakdown["charm_steps"]:
		if int(step.get("fee", 0)) > 0:
			fee_steps += 1
			assert_eq(int(step["fee"]), CharmEffects.PROTECTION_FEE)
			assert_eq(int(step["base_add"]), 0)
			assert_eq(int(step["mult_add"]), 0)
	assert_eq(fee_steps, 1, "genau ein Gebühren-Schritt")
	assert_eq(int(breakdown["total"]), DiceScoring.score_category(DiceScoring.TWO_KIND, dice, ids),
		"die Gebühr ändert die Wertung nicht")

# --- Dreifacher Boden: nur die Basispunkte der Kombination zählen dreifach ------------

func test_double_bottom_triples_only_the_combination_base():
	# Paar Fünfer: (10 + 10 Augen) × 2 = 40. Dreifach zählen NUR die Basispunkte
	# der Kombination: (10×3 + 10 Augen) × 2 = 80.
	var plain := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([]))
	var tripled := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.DOUBLE_BOTTOM]))
	assert_eq(plain, 40)
	assert_eq(tripled, 80)

func test_double_bottom_leaves_the_printed_level_alone():
	# points_for/mult_for bleiben die reine Stufe - Chips und Preise drucken sie.
	var ids := _ids([Charm.DOUBLE_BOTTOM])
	assert_eq(DiceScoring.points_for(DiceScoring.TWO_KIND), 10)
	assert_eq(DiceScoring.mult_for(DiceScoring.TWO_KIND), 2)
	assert_eq(CharmEffects.combo_factor(ids), 3)
	assert_eq(CharmEffects.combo_factor(_ids([Charm.DOUBLE_BOTTOM, Charm.DOUBLE_BOTTOM])), 9)
	assert_eq(CharmEffects.combo_factor(_ids([])), 1)

func test_the_breakdown_shows_the_combination_pure_and_the_tripling_as_its_own_step():
	# Die Schrittliste wird feiner, die Summe darf sich um keinen Punkt aendern.
	var ids := _ids([Charm.DOUBLE_BOTTOM])
	var plain := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d(PAIR), _ids([]))
	var tripled := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d(PAIR), ids)
	assert_eq(int(tripled["total"]),
		DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids),
		"die Summe bleibt die der Wertung")
	assert_eq(tripled["combo"]["base_add"], plain["combo"]["base_add"],
		"die Kombination reist pur, wie ohne den Charm")
	assert_eq(tripled["combo"]["mult_add"], plain["combo"]["mult_add"])
	var steps: Array = tripled["combo_factor_steps"]
	assert_eq(steps.size(), 1, "ein Schritt je Kopie")
	assert_eq(int(steps[0]["base_after"]), int(plain["combo"]["base_add"]) * 3)
	assert_almost_eq(float(steps[0]["mult_after"]), float(plain["combo"]["mult_add"]), 0.001,
		"der Mult der Kombination bleibt, wo er war")
	assert_eq(steps[0]["charm_indices"], [0], "das Pad der Kopie blinkt")

func test_two_copies_are_two_steps_not_one_times_nine():
	# Dieselbe Regel wie bei den Krits: jede Kopie ist ein eigener Einschlag.
	var ids := _ids([Charm.DOUBLE_BOTTOM, Charm.DOUBLE_BOTTOM])
	var tripled := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d(PAIR), ids)
	var steps: Array = tripled["combo_factor_steps"]
	assert_eq(steps.size(), 2)
	assert_eq(int(steps[0]["base_after"]), 30)
	assert_eq(int(steps[1]["base_after"]), 90)
	assert_eq(int(tripled["total"]),
		DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids))

func test_the_double_bottom_never_shows_up_twice():
	# Er hat keinen charm_*_at-Hook - stuende er auch in charm_steps, zaehlte die
	# Zeremonie ihn zweimal.
	var doubled := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.DOUBLE_BOTTOM]))
	var mentions := 0
	for step: Dictionary in doubled["combo_factor_steps"]:
		if step.get("charm_indices", []).has(0):
			mentions += 1
	for step: Dictionary in doubled["charm_steps"]:
		if step.get("charm_indices", []).has(0):
			mentions += 1
	for step: Dictionary in doubled["post_steps"]:
		if step.get("charm_indices", []).has(0):
			mentions += 1
	assert_eq(mentions, 1, "genau ein Schritt gehört dem Doppelten Boden")

# --- Wasserfall: nur fallende Augenzahlen legen nach ----------------------------------

func test_the_waterfall_only_fires_on_a_falling_value():
	var ids := _ids([Charm.WATERFALL])
	assert_eq(CharmEffects.cascade_mult(5, CharmEffects.CASCADE_UNSET, ids), 5, "die erste zählt immer")
	assert_eq(CharmEffects.cascade_mult(3, 5, ids), 3)
	assert_eq(CharmEffects.cascade_mult(5, 5, ids), 0, "gleich ist nicht niedriger")
	assert_eq(CharmEffects.cascade_mult(6, 5, ids), 0)
	assert_eq(CharmEffects.cascade_mult(3, 5, _ids([Charm.WATERFALL, Charm.WATERFALL])), 6, "je Vorkommen")
	assert_eq(CharmEffects.cascade_mult(3, 5, _ids([])), 0)

func test_the_waterfall_pays_a_whole_descending_straight():
	# Große Straße, Reihen-Ordnung 6,5,4,3,2,1: jede Zahl fällt, alle sechs zahlen.
	var ids := _ids([Charm.WATERFALL])
	var straight := _d([1, 2, 3, 4, 5, 6])
	var plain := DiceScoring.score_category(DiceScoring.LARGE_STRAIGHT, straight, _ids([]))
	var cascaded := DiceScoring.score_category(DiceScoring.LARGE_STRAIGHT, straight, ids)
	# Basis 45 + 21 Augen = 66; Mult 8 -> 8 + 21 = 29.
	assert_eq(plain, 66 * 8)
	assert_eq(cascaded, 66 * 29)

func test_the_waterfall_takes_only_the_first_of_each_pair():
	# Zwei Paare 5,5,3,3: die erste 5 und die erste 3 lösen aus, die Zwillinge nicht.
	var ids := _ids([Charm.WATERFALL])
	var dice := _d([5, 5, 3, 3])
	var plain := DiceScoring.score_category(DiceScoring.TWO_PAIR, dice, _ids([]))
	var cascaded := DiceScoring.score_category(DiceScoring.TWO_PAIR, dice, ids)
	# Basis 15 + 16 Augen = 31; Mult 3 -> 3 + 5 + 3 = 11 (die Zwillinge fallen nicht).
	assert_eq(plain, 31 * 3)
	assert_eq(cascaded, 31 * 11)

func test_the_waterfall_never_retriggers_on_the_same_value():
	# Argon lässt den Würfel zweimal antreten - die zweite Zündung zeigt dieselbe
	# Zahl und legt darum nichts nach.
	var ids := _ids([Charm.WATERFALL])
	var ctx := _argon(0)
	var once := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids, false, NO_MATS, {}, {})
	var twice := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids, false, NO_MATS, {}, ctx)
	# Zweite Zündung: +5 Augen, aber KEIN zweiter Wasserfall-Schlag.
	assert_eq(twice, (20 + 5) * (2 + 5))
	assert_eq(once, 20 * (2 + 5))

# --- Tarnkappe: der Krypton-Würfel tritt einmal mehr an --------------------------------

func test_camouflage_gives_krypton_an_extra_die_trigger():
	var sets := {0: [Essence.KRYPTON] as Array[String]}
	var order := _p([0, 1])
	assert_eq(EssenceEffects.extra_activations(0, order, sets, _ids([])), 0, "ohne Charm nichts")
	assert_eq(EssenceEffects.extra_activations(0, order, sets, _ids([Charm.CAMOUFLAGE])), 1)
	assert_eq(EssenceEffects.extra_activations(1, order, sets, _ids([Charm.CAMOUFLAGE])), 0,
		"nur am Krypton-Würfel")

func test_camouflage_needs_its_soul_to_be_offered():
	var none: Array[String] = []
	var without := Charm.offerable(Charm.all(), none)
	for charm in without:
		assert_ne(charm.id, Charm.CAMOUFLAGE, "die Tarnkappe liegt ohne Krypton aus")
	var owned := _ids([Essence.KRYPTON])
	var found := false
	for charm in Charm.offerable(Charm.all(), owned):
		if charm.id == Charm.CAMOUFLAGE:
			found = true
	assert_true(found)

func test_gallows_humor_gives_crit_after_a_farkle():
	var ids := _ids([Charm.GALLOWS_HUMOR])
	assert_eq(CharmEffects.charm_crit_at(0, _d(PAIR), ids, {"after_farkle": true}), 4, "Krit ×4")
	assert_eq(CharmEffects.charm_crit_at(0, _d(PAIR), ids, {"after_farkle": false}), 1, "ohne Farkle kein Krit")
	# Ende-zu-Ende: Paar Fünfer, Mult 2 × Krit 4 = 8 -> Basis 20 × 8 = 160.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids, false, NO_MATS, {}, {"after_farkle": true})
	assert_eq(score, 160)

# --- Retrigger-Regel: würfelgebundene Charms feuern je Aktivierung ihres Würfels ----

func test_high_stacker_retriggers_with_its_die():
	# Argon auf dem Zielwürfel: Basis (10 + 5 + Nachzählung 5 + 5)
	# × Mult (2 + Hochstapler 5 je Auslösung) = 25 × 12 = 300.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.HIGH_STACKER]), false, NO_MATS, {}, _argon(0))
	assert_eq(score, 300)

func test_beherit_crits_once_no_matter_how_often_the_die_fires():
	# Er hängt an der Hand, nicht am Würfel: Argon lässt Slot 0 zweimal zünden,
	# der Krit schlägt trotzdem genau einmal. Basis (18 + 4×4) × (3 × 5) = 510.
	var score := DiceScoring.score_category(DiceScoring.THREE_KIND, _d([4, 4, 4, 1, 2, 3]), _ids([Charm.BEHERIT]), false, NO_MATS, {}, _argon(0))
	assert_eq(score, 510)

func test_per_die_charms_retrigger_with_their_die():
	# Mehrfachstecker feuert je Auslösung seines Würfels: Basis (10 + (5+5)×2 + 5+5)
	# × Mult 2 = 40 × 2 = 80.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.BROADBAND]), false, NO_MATS, {}, _argon(0))
	assert_eq(score, 80)

# --- Basis-Boni & Faktoren -----------------------------------------------------------

func test_snake_eyes_crits_with_the_bystanders():
	# Genau ein 1er-Paar genommen: Krit ×Augensumme der Unbeteiligten (3+4+5+6).
	var ids := _ids([Charm.SNAKE_EYES])
	assert_eq(CharmEffects.charm_crit_at(0, _d([1, 1, 3, 4, 5, 6]), ids, {}, _p([0, 1]), DiceScoring.TWO_KIND), 18.0)
	assert_eq(CharmEffects.charm_crit_at(0, _d([5, 5, 3, 4, 1, 6]), ids, {}, _p([0, 1]), DiceScoring.TWO_KIND), 1.0,
		"ein 5er-Paar sind keine Snake Eyes")

func test_snake_eyes_never_crits_below_one():
	# Ohne (oder mit fast keinen) Unbeteiligten darf der Krit den Mult nicht fressen.
	var ids := _ids([Charm.SNAKE_EYES])
	assert_eq(CharmEffects.charm_crit_at(0, _d([1, 1]), ids, {}, _p([0, 1]), DiceScoring.TWO_KIND), 1.0)
	assert_eq(CharmEffects.charm_crit_at(0, _d([1, 1, 1]), ids, {}, _p([0, 1]), DiceScoring.TWO_KIND), 1.0,
		"Augensumme 1 ist kein Krit")

func test_cult_of_one_crits_per_one():
	# Paar Fünfer mit EINER 1: Basis 20 × (Mult 2, Krit ×2) = 80.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.CULT_OF_ONE]))
	assert_eq(score, 80)

func test_after_work_beer_crits_when_the_pool_is_empty():
	# Paar Fünfer: Basis 20 × (Mult 2, Krit ×5) = 200; mit Würfeln im Stapel nur 40.
	var ids := _ids([Charm.AFTER_WORK_BEER])
	var empty := {CharmEffects.CTX_POOL_EMPTY: true}
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids, false, NO_MATS, {}, empty), 200)
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), ids), 40)

# --- Material-Verstärker -------------------------------------------------------------

func test_amber_room_adds_its_flat_surplus_to_amber():
	var bonus := MaterialEffects.base_bonus(_d(PAIR), _m([DieMaterial.AMBER, "", "", "", "", ""]), _p([0, 1]), _ids([Charm.AMBER_ROOM]))
	assert_eq(bonus, MaterialEffects.AMBER_BASE + MaterialEffects.AMBER_ROOM_SURPLUS)

func test_blood_diamond_adds_the_face_value_to_the_ruby_mult():
	# Rubin auf der gewerteten 5: +4 fest + 5 Augen - EINMAL, nie je Exemplar.
	var mats := _m([DieMaterial.RUBY, "", "", "", "", ""])
	assert_eq(MaterialEffects.mult_bonus(_d(PAIR), mats, _p([0, 1]), _ids([Charm.BLOOD_DIAMOND])), 9)
	assert_eq(MaterialEffects.mult_bonus(_d(PAIR), mats, _p([0, 1]), _ids([Charm.BLOOD_DIAMOND, Charm.BLOOD_DIAMOND])), 9)
	# Ohne den Diamanten bleibt es beim festen +4.
	var plain := MaterialEffects.mult_bonus(_d(PAIR), mats, _p([0, 1]))
	assert_eq(plain, 4)

func test_bone_marrow_adds_one_flat_trigger():
	# Knochenmark verlängert nicht den Schritt, sondern die Zahl der Auslösungen.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]), _ids([Charm.BONE_MARROW]))
	assert_eq(defs[0].faces[0], 9, "zwei Auslösungen à +2")
	var twice: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	MaterialEffects.apply_take_effects(twice, _p([0]), _m([DieMaterial.BONE]), _p([0]),
		_ids([Charm.BONE_MARROW, Charm.BONE_MARROW, Charm.BONE_GLUE]))
	assert_eq(twice[0].faces[0], 15, "Leim setzt den Satz 5, das Mark bleibt bei zwei Auslösungen")

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
	assert_eq(report.total_money(), 6, "Goldschmied legt $3 auf die $3")
	assert_eq(defs[1].faces[0], 10, "Knochenleim wächst +5: Stufe I +2 plus Aufschlag +3")

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
	assert_eq(report.total_money(), 12, "$6 je beteiligter Gold-Seite")

func _die(faces: Array) -> DieDefinition:
	var def := DieDefinition.new()
	var typed: Array[int] = []
	typed.assign(faces)
	def.faces = typed
	return def

# --- Gleichschliff: sechs gleiche Seiten -----------------------------------------------

func test_equal_grind_pays_the_common_face_value():
	var ids := _ids([Charm.EQUAL_GRIND])
	var dice := _d([4, 5, 1, 2, 3, 6])
	var ctx := {DiceScoring.CTX_EQUAL_FACES: {0: 4}}
	assert_eq(CharmEffects.die_charm_mult_at(0, 0, dice, ids, ctx), 4)
	assert_eq(CharmEffects.die_charm_mult_at(0, 1, dice, ids, ctx), 0, "gemischte Seiten geben nichts")
	assert_eq(CharmEffects.die_charm_mult_at(0, 0, dice, ids, {}), 0, "ohne Eintrag kein Schliff")

func test_equal_grind_fires_per_counted_die_and_per_firing():
	var ids := _ids([Charm.EQUAL_GRIND])
	# Paar Vierer, beide gleichgeschliffen: Basis 18, Mult 2 + 4 + 4 = 10 -> 180.
	var both := {DiceScoring.CTX_EQUAL_FACES: {0: 4, 1: 4}}
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([4, 4]), ids, false, NO_MATS, {}, both), 180)
	# Nur einer: Mult 2 + 4 = 6 -> 108.
	var one := {DiceScoring.CTX_EQUAL_FACES: {0: 4}}
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([4, 4]), ids, false, NO_MATS, {}, one), 108)
	# Unbeteiligte zählen nicht mit - der Schliff auf Slot 2 bleibt stumm.
	var idle := {DiceScoring.CTX_EQUAL_FACES: {2: 6}}
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([4, 4, 6, 1, 2, 3]), ids, false, NO_MATS, {}, idle),
		DiceScoring.score_category(DiceScoring.TWO_KIND, _d([4, 4, 6, 1, 2, 3]), _ids([]), false, NO_MATS, {}, idle))

func test_equal_grind_fires_again_on_a_retrigger():
	# Argon lässt Slot 0 zweimal zünden - der Schliff feuert mit ihm.
	var ids := _ids([Charm.EQUAL_GRIND])
	var ctx := _argon(0)
	ctx[DiceScoring.CTX_EQUAL_FACES] = {0: 4}
	# Basis 10 + 4 + 4 + 4 = 22, Mult 2 + 4 + 4 = 10 -> 220.
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([4, 4]), ids, false, NO_MATS, {}, ctx), 220)

# --- Trinkgeldglas: jeder Krit zahlt seinen ×-Wert -------------------------------------

func test_tip_jar_pays_each_crit_its_rounded_factor():
	var one := _ids([Charm.TIP_JAR])
	assert_eq(CharmEffects.tip_money(1.5, one), 2, "×1,5 zahlt $2")
	assert_eq(CharmEffects.tip_money(2.25, one), 3, "×2,25 zahlt $3")
	assert_eq(CharmEffects.tip_money(4.0, one), 4)
	assert_eq(CharmEffects.tip_money(1.0, one), 0, "×1 ist kein Krit")
	assert_eq(CharmEffects.tip_money(1.5, _ids([Charm.TIP_JAR, Charm.TIP_JAR])), 4, "je Exemplar")
	assert_eq(CharmEffects.tip_money(2.0, _ids([])), 0, "ohne Glas kein Trinkgeld")

func test_tip_jar_collects_every_crit_of_the_hand():
	# Zwei Xenon-Seelen: ZWEI Einschläge ×1,5, also zweimal $2 - nie einmal am
	# Produkt ×2,25.
	var ids := _ids([Charm.TIP_JAR])
	var ctx := {DiceScoring.CTX_ESSENCES: {0: Essence.XENON, 1: Essence.XENON}}
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d(PAIR), ids, false, NO_MATS, {}, ctx)
	assert_eq(ScoreBreakdown.tip_money_total(breakdown), 4)
	var plain := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d(PAIR), ids)
	assert_eq(ScoreBreakdown.tip_money_total(plain), 0, "ohne Krit kein Trinkgeld")

func test_tip_jar_pays_each_kiln_slam_separately():
	# Härteofen: der veredelte Rubin schlägt zweimal ×2 - also zweimal $2.
	var ids := _ids([Charm.KILN, Charm.TIP_JAR])
	var mats := _m([DieMaterial.RUBY, "", "", "", "", ""])
	var ctx := {DiceScoring.CTX_MATERIAL_LEVELS: {0: {"level": 2}}}
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d(PAIR), ids, false, mats, {}, ctx)
	assert_eq(ScoreBreakdown.tip_money_total(breakdown), 4)

func test_tip_jar_also_pays_the_static_crits():
	# Beherit schlägt in der Charm-Phase zu (×5) - auch der zahlt.
	var ids := _ids([Charm.BEHERIT, Charm.TIP_JAR])
	var breakdown := ScoreBreakdown.build(DiceScoring.THREE_KIND, _d([4, 4, 4, 1, 2, 3]), ids)
	assert_eq(ScoreBreakdown.tip_money_total(breakdown), 5)
	var doubled := _ids([Charm.BEHERIT, Charm.TIP_JAR, Charm.TIP_JAR])
	assert_eq(ScoreBreakdown.tip_money_total(
		ScoreBreakdown.build(DiceScoring.THREE_KIND, _d([4, 4, 4, 1, 2, 3]), doubled)), 10,
		"zwei Gläser zahlen doppelt")

func test_tip_jar_leaves_base_and_mult_alone():
	# Es zahlt bar, es wertet nicht: dieselbe Punktzahl mit und ohne Glas.
	var ctx := {DiceScoring.CTX_ESSENCES: {0: Essence.XENON}}
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([Charm.TIP_JAR]), false, NO_MATS, {}, ctx),
		DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), _ids([]), false, NO_MATS, {}, ctx))

# --- Geld-Hooks -----------------------------------------------------------------------

func test_take_and_farkle_incomes():
	assert_eq(CharmEffects.take_income(_ids([Charm.STREET_MUSICIAN]), 3), 3, "$1 je beteiligtem Würfel")
	assert_eq(CharmEffects.farkle_shard_income(6, _ids([Charm.SHARD_COURT])), 12, "$2 je verworfenem Würfel")
	assert_true(CharmEffects.gold_rush_applies(_ids([Charm.GOLD_RUSH]), 6))
	assert_false(CharmEffects.gold_rush_applies(_ids([Charm.GOLD_RUSH]), 5))
	assert_false(CharmEffects.gold_rush_applies(_ids([Charm.GOLD_RUSH]), 3),
		"ein Rest-Wurf aus drei Würfeln ist keine volle Hand")
	assert_false(CharmEffects.gold_rush_applies(_ids([Charm.GOLD_RUSH]), 6, false), "nur die erste Hand der Runde")

func test_gold_rush_grows_money_by_a_fifth_capped_at_thirty():
	assert_eq(CharmEffects.gold_rush_income(100), 20)
	assert_eq(CharmEffects.gold_rush_income(4), 0, "unter $5 wächst nichts")
	assert_eq(CharmEffects.gold_rush_income(1000), 30, "gedeckelt")

func test_rag_collector_counts_lucky_values():
	assert_eq(CharmEffects.rag_collector_income(_d([4, 4, 1, 4, 2, 3]), 4, _ids([Charm.RAG_COLLECTOR])), 12, "$4 je Treffer")
	assert_eq(CharmEffects.rag_collector_income(_d([4, 4, 1, 4, 2, 3]), 0, _ids([Charm.RAG_COLLECTOR])), 0, "ohne Glückszahl kein Geld")

func test_round_end_income_combines_sources_with_caps():
	# Zinsgroschen: $37 -> +3; Überflieger: 2 geräumte Stufen -> +10.
	var ids := _ids([Charm.INTEREST_PENNY, Charm.HIGH_FLYER])
	assert_eq(CharmEffects.round_end_income(37, 2, ids), 13)
	assert_eq(CharmEffects.round_end_income(9, 0, ids), 0)
	# Nur der Zinsgroschen ist gedeckelt - die Stufen deckelt der Balken selbst.
	assert_eq(CharmEffects.round_end_income(10000, 5, ids), 45, "Zinsen max. $20, Stufen 5×$5")

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
	assert_eq(entries[0]["amount"], CharmEffects.INTEREST_PENNY_CAP)
	assert_eq(entries[1]["amount"], CharmEffects.INTEREST_PENNY_CAP)

func test_the_emergency_fund_tops_up_the_running_balance():
	# Er füllt auf, was NACH den Charms vor ihm noch fehlt - sonst ersetzte er
	# deren Zahlung, statt sie zu ergänzen.
	var late := CharmEffects.round_end_income_entries(10, 0,
		_ids([Charm.OLD_PENNY, Charm.EMERGENCY_FUND]))
	assert_eq(late[0]["amount"], 3, "Glücksgroschen zuerst")
	assert_eq(late[1]["amount"], 32, "$13 -> auffüllen auf $45")
	var early := CharmEffects.round_end_income_entries(10, 0,
		_ids([Charm.EMERGENCY_FUND, Charm.OLD_PENNY]))
	assert_eq(early[0]["amount"], 35, "$10 -> auffüllen auf $45")
	assert_eq(early[1]["amount"], 3, "und der Glücksgroschen legt obendrauf")

func test_a_full_purse_needs_no_emergency_fund():
	var entries := CharmEffects.round_end_income_entries(50, 0, _ids([Charm.EMERGENCY_FUND]))
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
	assert_eq(CharmEffects.money_floor(_ids([Charm.EMERGENCY_FUND])), 45)
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
	assert_eq(CharmEffects.die_price(15, _ids([Charm.BULK_DISCOUNT])), 10, "jedes Bündel, auch das einzelne")
	assert_almost_eq(CharmEffects.pack_refund_chance(_ids([Charm.FINE_PRINT])), 0.2, 0.001)

func test_seal_of_quality_forces_refinements():
	for offer in DiceOffer.roll_offers(DiceOffer.TEMPLATES.size(), _ids([Charm.SEAL_OF_QUALITY])):
		for die in offer.dice:
			assert_lt(die.materials.count(""), die.materials.size(),
				"%s trägt mindestens eine Material-Seite" % offer.display_name)
			assert_true(DiceOffer.has_doped_side(die),
				"%s trägt mindestens eine VEREDELTE Seite" % offer.display_name)

func test_seal_of_quality_also_dopes_a_pack_die():
	var pack := Pack.dice_pack(DiceOffer.TEMPLATES[0])
	for die in pack.roll_dice(_ids([Charm.SEAL_OF_QUALITY])):
		assert_lt(die.materials.count(""), die.materials.size(), "auch im Paket belegt")
		assert_true(DiceOffer.has_doped_side(die), "auch im Paket veredelt")

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

func test_stamp_machine_mints_sealed_packs_for_the_ceremony():
	# Die Rundenende-Zeremonie (scene_root) fliegt je Paket einen Meteor und
	# bucht bei Ankunft - hier die Logik: jedes gewürfelte Paket ist ein 1er-Paket
	# einer Regal-Sorte, und erst grant_pack legt es ins Lager.
	var run := GameRun.new_run()
	assert_eq(run.owned_packs.size(), 0)
	for i in GameRun.STAMP_PACKS:
		var pack := run.roll_stamp_pack()
		assert_true(Pack.SHELF_WEIGHTS.has(pack.type), "eine Regal-Sorte")
		assert_eq(pack.count, Pack.ENGRAVING_PACK_COUNT)
		assert_eq(run.owned_packs.size(), i, "roll allein bucht nicht")
		run.grant_pack(pack)
	assert_eq(run.owned_packs.size(), GameRun.STAMP_PACKS)

func test_jewelry_box_grants_sealed_material_packs_and_leaves_the_dice_alone():
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.jewelry_box())
	# 10% je Würfel: bei 300 Würfeln ist "kein Fund" praktisch ausgeschlossen.
	var many: Array[DieDefinition] = []
	for i in 300:
		many.append(DieDefinition.standard())
	var grants := run.apply_jewelry_box(many)
	assert_gt(grants.size(), 0, "bei 300 Würfeln findet das Schmuckkästchen praktisch sicher")
	assert_eq(run.owned_packs.size(), grants.size(), "je Fund ein versiegeltes Mini-Paket")
	for pack in run.owned_packs:
		assert_eq(pack.type, Pack.TYPE_MATERIAL)
		assert_not_null(pack.fixed_engraving, "Fixinhalt: genau das gefundene Material")
	# Die Würfel bleiben unberührt - der Charm malt keine Seite mehr an.
	for def in many:
		assert_eq(def.materials.count(""), def.materials.size(), "keine Seite wurde belegt")
	for grant in grants:
		assert_ne(DieMaterial.by_id(String(grant["material_id"])), null, "ein echtes Material")
		assert_eq(int(grant["copy"]), 0, "ein Exemplar - alles gehört Dock-Platz 0")
	assert_eq(run.apply_jewelry_box([] as Array[DieDefinition]).size(), 0,
		"ohne übrige Würfel passiert nichts")

func test_jewelry_box_does_nothing_without_the_charm():
	var run := GameRun.new_run()
	var many: Array[DieDefinition] = []
	for i in 50:
		many.append(DieDefinition.standard())
	assert_eq(run.apply_jewelry_box(many).size(), 0)
	assert_eq(run.owned_packs.size(), 0)

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
	assert_eq(CharmEffects.die_charm_base(0, DiceScoring.TWO_KIND, _d(PAIR), twice), 10, "zweimal Mehrfachstecker: +10 je Würfel")
	assert_eq(CharmEffects.charm_mult_bonus(DiceScoring.TWO_KIND, _d(PAIR), NO_MATS, _ids([Charm.MOMENTUM, Charm.MOMENTUM]), {"streak": 3}), 12)
	assert_eq(CharmEffects.round_end_income(30, 0, _ids([Charm.INTEREST_PENNY, Charm.INTEREST_PENNY])), 6)
	assert_eq(CharmEffects.take_income(_ids([Charm.STREET_MUSICIAN, Charm.STREET_MUSICIAN]), 2), 4)

func test_totem_copy_actually_doubles_a_scoring_charm():
	# Ende-zu-Ende: Papagei neben Mehrfachstecker -> +10 Basis wird +20.
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.broadband())
	run.owned_charms.append(Charm.parrot_totem())
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), run.charm_ids())
	assert_eq(score, 80, "(10 Punkte + 10 Augen + 2×10) × 2")

func test_totem_chain_resolves_each_neighbor_independently():
	# [Mehrfachstecker, Papagei, Echo, Hufeisen]: Papagei kopiert links (Mehrfachstecker),
	# Echo kopiert rechts (Hufeisen).
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.broadband())
	run.owned_charms.append(Charm.parrot_totem())
	run.owned_charms.append(Charm.echo_totem())
	run.owned_charms.append(Charm.horseshoe())
	assert_eq(run.charm_ids(), ["broadband", "broadband", "horseshoe", "horseshoe"])

# --- Zusammenspiel mit Augenwert-Charms ---------------------------------------------

func test_echo_chamber_respects_base_point_charms():
	# Der Equalizer hebt die Basispunkte einer 2 auf 10 - auch beim Echo-Nachzählen
	# des zuerst GEWERTETEN Würfels (hier das Paar Zweier).
	var bonus := MaterialEffects.base_bonus(_d([2, 2, 1, 3, 4, 6]), NO_MATS, _p([0, 1]), _ids([Charm.ECHO_CHAMBER, Charm.EQUALIZER]), 0)
	assert_eq(bonus, CharmEffects.EQUALIZER_FLOOR, "Echo der gewerteten 2 zählt mit Equalizer als 10")

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

## Der Wurf hängt am Kauf, nicht am Charm allein: purchase_pack ist die einzige
## Stelle, an der das Kleingedruckte greift.

func test_without_the_charm_a_pack_purchase_never_refunds():
	var run := GameRun.new_run()
	run.money = 100
	for _i in 40:
		assert_eq(run.purchase_pack(Pack.number_pack(), 5), 0, "ohne Kleingedrucktes nie")
	assert_eq(run.money, 100 - 40 * 5)

func test_the_capped_charm_refunds_the_full_price_and_reports_it():
	# Fünf Exemplare deckeln bei 80 % - ein Wurf unter 0.8 trifft sicher.
	var run := GameRun.new_run()
	for _i in 5:
		run.owned_charms.append(Charm.fine_print())
	run.money = 100
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hits := 0
	for _i in 200:
		if run.purchase_pack(Pack.number_pack(), 5, rng) == 5:
			hits += 1
	assert_between(float(hits) / 200.0, 0.7, 0.9, "rund 80 % der Käufe kommen zurück")
	assert_eq(run.money, 100 - (200 - hits) * 5, "erstattet wird GENAU der Kaufpreis")

func test_a_refund_ignores_the_income_factor():
	# Eine Erstattung ist die Rücknahme einer AUSGABE - liefe sie durch add_money,
	# machte die Happy Hour aus jedem Paketkauf ein Geschäft.
	var run := GameRun.new_run()
	for _i in 5:
		run.owned_charms.append(Charm.fine_print())
	run.sign_clauses([DealClause.HAPPY_HOUR] as Array[String])
	assert_gt(run.money_gain_factor(), 1.0, "die Happy Hour steht")
	run.money = 100
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for _i in 60:
		var before := run.money
		var refunded := run.purchase_pack(Pack.number_pack(), 5, rng)
		assert_true(refunded == 0 or refunded == 5)
		assert_lte(run.money, before, "ein Kauf macht nie reicher")

func test_a_free_pack_has_nothing_to_refund():
	var run := GameRun.new_run()
	for _i in 5:
		run.owned_charms.append(Charm.fine_print())
	assert_eq(run.purchase_pack(Pack.number_pack(), 0, null), 0)

# --- Wertungs-Reihenfolge: Krits wirken an ihrer Besitz-Position -------------------

func test_static_crits_apply_at_their_dock_position():
	# KEINE Ausnahmen von der Trigger-Reihenfolge: Einserkult vor dem Hausjoker
	# kritet nur den Kombi-Mult (2×2 = 4, dann +4 = 8, ×20 Basis = 160); dahinter
	# kritet er auch den Charm-Mult ((2+4)×2 = 12, ×20 = 240).
	var cult_first := _ids([Charm.CULT_OF_ONE, Charm.HOUSE_JOKER])
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), cult_first), 160)
	var cult_last := _ids([Charm.HOUSE_JOKER, Charm.CULT_OF_ONE])
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d(PAIR), cult_last), 240)

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
