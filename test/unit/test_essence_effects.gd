extends GutTest
## Tier-1-Tests der Essenzen: Datensatz, Aktivierungs-Mathe (die Essenz ist die
## EINZIGE multiplikative Quelle), Augen, Krits, Geld, Schutz und die Eingriffe
## in Zählreihenfolge und Farkle-Regel.

func _d(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _m(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _ids(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _p(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

const NO_CHARMS: Array[String] = []
const NO_MATS: Array[String] = []

func _ctx(essences: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var ctx := {DiceScoring.CTX_ESSENCES: essences}
	for key in extra:
		ctx[key] = extra[key]
	return ctx

# --- Datensatz -------------------------------------------------------------------

func test_all_ids_are_unique_and_filled():
	var seen := {}
	for essence in Essence.all():
		assert_false(seen.has(essence.id), "doppelte id: %s" % essence.id)
		seen[essence.id] = true
		assert_ne(essence.display_name, "", "display_name fehlt bei %s" % essence.id)
		assert_ne(essence.description, "", "description fehlt bei %s" % essence.id)
		assert_ne(essence.short, "", "short fehlt bei %s" % essence.id)

func test_every_legendary_is_a_unique():
	for essence in Essence.all():
		if essence.rarity == Essence.Rarity.LEGENDARY:
			assert_true(essence.unique, "%s ist legendär und damit Unikat" % essence.id)

func test_tradeable_excludes_the_black_market():
	var ids: Array[String] = []
	for essence in Essence.tradeable():
		ids.append(essence.id)
		assert_false(essence.secret, "%s gehört in den Schwarzmarkt" % essence.id)
	assert_false(ids.has(Essence.MERCURY_VAPOR), "Quecksilberdampf nur im Hinterzimmer")
	assert_false(ids.has(Essence.ANTIMATTER))
	assert_true(ids.has(Essence.ARGON), "Handelsgase liegen im normalen Handel")

func test_glow_and_hint_fall_back_without_an_essence():
	assert_eq(Essence.glow_for(""), Color.BLACK, "essenzlose Würfel glühen nicht")
	assert_eq(Essence.hint(""), "")
	assert_true(Essence.hint(Essence.ARGON).contains("Argon"))

# --- Aktivierungs-Mathe: EIN Faktor je Würfel ------------------------------------

func test_the_essence_is_the_only_multiplicative_source():
	assert_eq(EssenceEffects.activation_factor(Essence.ARGON), 2)
	assert_eq(EssenceEffects.activation_factor(Essence.MERCURY_VAPOR), 3)
	assert_eq(EssenceEffects.activation_factor(Essence.NEON), 1, "wer nicht stapelt, bleibt bei einmal")
	assert_eq(EssenceEffects.activation_factor(""), 1)

func test_st_elmos_fire_burns_brighter_in_the_storm():
	assert_eq(EssenceEffects.activation_factor(Essence.ST_ELMOS_FIRE, NO_CHARMS, false), 2)
	assert_eq(EssenceEffects.activation_factor(Essence.ST_ELMOS_FIRE, NO_CHARMS, true), 4, "im Stresstest vierfach")

func test_mercury_vapor_charm_lifts_every_retrigger_essence():
	var vapor := _ids([Charm.MERCURY_VAPOR])
	assert_eq(EssenceEffects.activation_factor(Essence.ARGON, vapor), 3)
	assert_eq(EssenceEffects.activation_factor(Essence.MERCURY_VAPOR, vapor), 4)
	assert_eq(EssenceEffects.activation_factor(Essence.ST_ELMOS_FIRE, vapor, true), 5)
	assert_eq(EssenceEffects.activation_factor(Essence.NEON, vapor), 1, "der Dampf hebt nur echte Faktoren")

func test_argon_doubles_the_die_in_the_score():
	# Paar Fünfer, Argon auf Slot 0: die Augen zählen zweimal.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]),
		NO_CHARMS, false, NO_MATS, {}, _ctx({0: Essence.ARGON}))
	assert_eq(score, (10 + 5 + 5 + 5) * 2)

# --- Additive Auslösungen aus der Zählreihenfolge --------------------------------

func test_oxygen_fans_the_next_die_in_the_order():
	var order := _p([0, 1, 2])
	var essences := {0: Essence.OXYGEN}
	assert_eq(EssenceEffects.extra_activations(1, order, essences), 1, "der NÄCHSTE bekommt den Zug")
	assert_eq(EssenceEffects.extra_activations(0, order, essences), 0, "nie sich selbst")
	assert_eq(EssenceEffects.extra_activations(2, order, essences), 0, "nur der direkte Nachbar")

func test_solar_wind_rides_every_essence_counted_before_it():
	var order := _p([0, 1, 2])
	var essences := {0: Essence.NEON, 1: Essence.KRYPTON, 2: Essence.SOLAR_WIND}
	assert_eq(EssenceEffects.extra_activations(2, order, essences), 2, "zwei Seelen vor ihm")
	var alone := {2: Essence.SOLAR_WIND}
	assert_eq(EssenceEffects.extra_activations(2, order, alone), 0, "ohne Vorläufer kein Rückenwind")

func test_extra_activations_stay_additive_next_to_the_factor():
	# Argon (×2) + Sauerstoff davor (+1) = 3, nie 4: auf der Würfel-Achse
	# multipliziert nur die Essenz, alles andere addiert.
	var count := MaterialEffects.die_trigger_count(1, NO_CHARMS, -1, _ids([Essence.ARGON]), false, 1)
	assert_eq(count, 3)

# --- Augen: Wasserstoff-Linse, Antimaterie, Radon --------------------------------

func test_hydrogen_is_a_lens_on_the_shown_value():
	assert_eq(EssenceEffects.lens_value(Essence.HYDROGEN, 5), 10)
	assert_eq(EssenceEffects.lens_value(Essence.NEON, 5), 5)
	# Die Linse sitzt NICHT mehr im Augen-Nachschlag - sonst verdoppelte sie zweimal.
	assert_eq(EssenceEffects.eye_value(Essence.HYDROGEN, 5), 5)

func test_the_hydrogen_lens_follows_the_charm_transform():
	# Verwandlung zuerst (1 -> 6 durch Glückszigaretten), dann die Linse: 12.
	assert_eq(DiceScoring.shown_value(1, _ids([Charm.LUCKY_CIGARETTES]), _ids([Essence.HYDROGEN])), 12)
	assert_eq(DiceScoring.shown_value(6, NO_CHARMS, _ids([Essence.HYDROGEN])), 12)

func test_the_hydrogen_lens_uses_the_overrun_digit_for_combinations():
	# Eine 6 zeigt 12 - Kombinationsziffer 2, Augen 12.
	var ctx := _ctx({0: Essence.HYDROGEN, 1: Essence.HYDROGEN})
	var dice := _d([6, 6, 2, 2])
	# Die beiden Wasserstoffe zeigen 12/12 (Ziffer 2), dazu zwei echte Zweien:
	# das ist ein Viererpasch, kein Zwei-Paare.
	assert_eq(DiceScoring.best_hand(dice, NO_CHARMS, false, NO_MATS, {}, ctx)["key"],
		DiceScoring.FOUR_KIND)
	assert_eq(DiceScoring.score_category(DiceScoring.FOUR_KIND, dice, NO_CHARMS, false, NO_MATS, {}, ctx),
		(25 + 12 + 12 + 2 + 2) * 4, "gezählt werden die verdoppelten Augen")

func test_the_hydrogen_die_never_fumbles_a_hand_anymore():
	# Das Knallgas ist weg: eine rohe 1 ist einfach eine 2.
	var ctx := _ctx({0: Essence.HYDROGEN})
	assert_eq(DiceScoring.shown_value(1, NO_CHARMS, _ids([Essence.HYDROGEN])), 2)
	assert_eq(DiceScoring.best_hand(_d([1, 2, 3]), NO_CHARMS, false, NO_MATS, {}, ctx)["key"],
		DiceScoring.TWO_KIND, "die verdoppelte 1 bildet mit der echten 2 ein Paar")

func test_antimatter_counts_negative_but_never_below_zero_base():
	assert_eq(EssenceEffects.eye_value(Essence.ANTIMATTER, 5), -5)
	# Ein Paar Fünfer mit Antimaterie auf beiden Seiten: die Basis klemmt bei 0.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]),
		NO_CHARMS, false, NO_MATS, {}, _ctx({0: Essence.ANTIMATTER, 1: Essence.ANTIMATTER}))
	assert_gte(score, 0, "die Basis fällt nie unter null")

func test_radon_irradiates_the_others_not_itself():
	var scored := _p([0, 1, 2])
	var essences := {0: Essence.RADON}
	assert_eq(EssenceEffects.foreign_eye_bonus(1, scored, essences), EssenceEffects.RADON_EYE_BONUS)
	assert_eq(EssenceEffects.foreign_eye_bonus(0, scored, essences), 0, "sich selbst bestrahlt es nicht")

# --- Krits ------------------------------------------------------------------------

func test_xenon_and_ball_lightning_crit_unconditionally():
	assert_almost_eq(EssenceEffects.crit_once_for(Essence.XENON, 5), 1.5, 0.0001)
	assert_almost_eq(EssenceEffects.crit_once_for(Essence.BALL_LIGHTNING, 5), 2.0, 0.0001)

func test_a_single_xenon_crit_rounds_up_only_at_the_end():
	# Paar Fünfer, Xenon auf Slot 0: Basis 20, Mult 2 × 1,5 = 3.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]),
		NO_CHARMS, false, NO_MATS, {}, _ctx({0: Essence.XENON}))
	assert_eq(score, (10 + 5 + 5) * 3)

func test_two_xenon_crits_multiply_to_two_and_a_quarter():
	# Zwei Xenon-Würfel: ×1,5 × 1,5 = ×2,25 auf den Kombi-Mult 2 -> 4,5.
	# Basis 20 × 4,5 = 90 - und NUR hier wird gerundet.
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]),
		NO_CHARMS, false, NO_MATS, {}, _ctx({0: Essence.XENON, 1: Essence.XENON}))
	assert_eq(score, 90, "×2,25 - nie zweimal auf ×2 gerundet")

func test_the_hand_mult_is_reported_as_a_float():
	var hand := DiceScoring.best_hand(_d([5, 5]), NO_CHARMS, false, NO_MATS, {}, _ctx({0: Essence.XENON}))
	assert_almost_eq(float(hand["mult"]), 3.0, 0.0001)

func test_ozone_grows_with_the_crits_before_it():
	assert_almost_eq(EssenceEffects.crit_once_for(Essence.OZONE, 5, 0), 1.0, 0.0001)
	assert_almost_eq(EssenceEffects.crit_once_for(Essence.OZONE, 5, 2), 3.0, 0.0001)

func test_antimatter_crits_with_its_eyes():
	assert_almost_eq(EssenceEffects.crit_once_for(Essence.ANTIMATTER, 6), 6.0, 0.0001)
	assert_almost_eq(EssenceEffects.crit_once_for(Essence.ANTIMATTER, 0), 1.0, 0.0001)

func test_the_mult_format_rule_drops_trailing_zeros():
	assert_eq(ScoreBreakdown.format_mult(2.0), "×2")
	assert_eq(ScoreBreakdown.format_mult(1.5), "×1.5")
	assert_eq(ScoreBreakdown.format_mult(2.25), "×2.25")
	assert_eq(ScoreBreakdown.format_number(10.0), "10")

# --- Grubengas: an JEDEM Krit der Hand -------------------------------------------

func test_firedamp_fires_with_every_crit():
	var scored := _p([0])
	var essences := {0: Essence.FIREDAMP}
	assert_eq(EssenceEffects.firedamp_step(scored, essences), EssenceEffects.FIREDAMP_BASE)
	assert_eq(EssenceEffects.firedamp_step(scored, {0: Essence.NEON}), 0)

func test_firedamp_scales_with_the_number_of_crits():
	# Kugelblitz kritet je Auslösung ×2; das Grubengas legt je Krit +20 auf die Basis.
	var one := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]),
		NO_CHARMS, false, NO_MATS, {}, _ctx({0: Essence.FIREDAMP, 1: Essence.BALL_LIGHTNING}))
	assert_eq(one, (10 + 5 + 5 + 20) * 4, "ein Krit, ein Schlagwetter")
	# Zwei Kugelblitze = zwei Krits: +40 Basis, Mult 2 × 2 × 2.
	var two := DiceScoring.score_category(DiceScoring.THREE_KIND, _d([5, 5, 5]),
		NO_CHARMS, false, NO_MATS, {},
		_ctx({0: Essence.FIREDAMP, 1: Essence.BALL_LIGHTNING, 2: Essence.BALL_LIGHTNING}))
	assert_eq(two, (18 + 5 + 5 + 5 + 40) * 12)

# --- Halogen: Flutlicht, additiv je Auslösung ------------------------------------

func test_halogen_adds_its_mult_per_activation():
	assert_eq(EssenceEffects.mult_bonus_once(Essence.HALOGEN), EssenceEffects.HALOGEN_MULT)
	assert_eq(EssenceEffects.mult_bonus_once(Essence.NEON), 0)
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]),
		NO_CHARMS, false, NO_MATS, {}, _ctx({0: Essence.HALOGEN}))
	assert_eq(score, (10 + 5 + 5) * (2 + 5))

func test_halogen_pays_once_per_activation_not_once_per_hand():
	# Die Hasenpfote lässt jede 6 ein zweites Mal auslösen: +5 Mult zweimal.
	var ctx := _ctx({0: Essence.HALOGEN})
	var plain := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([6, 6]), NO_CHARMS, false, NO_MATS, {}, ctx)
	assert_eq(plain, (10 + 6 + 6) * (2 + 5))
	var doubled := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([6, 6]), _ids([Charm.RABBITS_FOOT]),
		false, NO_MATS, {}, ctx)
	assert_eq(doubled, (10 + 6 + 6 + 6 + 6) * (2 + 5 + 5), "die zweite Auslösung legt erneut +5 Mult auf")

# --- Photonengas: Langzeitbelichtung ---------------------------------------------

func test_photon_gas_collects_the_triggers_before_it():
	assert_eq(EssenceEffects.trigger_eye_bonus(Essence.PHOTON_GAS, 0), 0, "als Erster sammelt es nichts")
	assert_eq(EssenceEffects.trigger_eye_bonus(Essence.PHOTON_GAS, 3),
		3 * EssenceEffects.PHOTON_EYE_PER_TRIGGER)
	assert_eq(EssenceEffects.trigger_eye_bonus(Essence.NEON, 3), 0)

func test_photon_gas_counts_the_hand_before_it_in_the_score():
	# Dreierpasch 5-5-5, Photonengas auf dem KLEINSTEN Slot: Wert absteigend,
	# Gleichstand -> Slot 0 zählt zuerst, also sammelt es nichts.
	var first := DiceScoring.score_category(DiceScoring.THREE_KIND, _d([5, 5, 5]),
		NO_CHARMS, false, NO_MATS, {}, _ctx({0: Essence.PHOTON_GAS}))
	assert_eq(first, (18 + 5 + 5 + 5) * 3, "als Erster sammelt es nichts")
	# Auf Slot 2 zählt es als DRITTES: +5 je Auslösung davor = +10.
	var last := DiceScoring.score_category(DiceScoring.THREE_KIND, _d([5, 5, 5]),
		NO_CHARMS, false, NO_MATS, {}, _ctx({2: Essence.PHOTON_GAS}))
	assert_eq(last, (18 + 5 + 5 + 5 + 10) * 3)

func test_photon_gas_counts_its_own_earlier_activations():
	# Argon + Photonengas auf demselben Würfel (2 Auslösungen), Slot 1 von zweien:
	# die Auslösungen sind 1 (Slot 0), dann 2× Slot 1 -> Boni 5 und 10.
	var sets := {1: [Essence.PHOTON_GAS, Essence.ARGON] as Array[String]}
	var ctx := {DiceScoring.CTX_ESSENCE_SET: sets}
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]),
		NO_CHARMS, false, NO_MATS, {}, ctx)
	assert_eq(score, (10 + 5 + (5 + 5) + (5 + 10)) * 2)

# --- Geld --------------------------------------------------------------------------

func test_neon_and_sodium_vapor_pay_on_the_take():
	# Die Reklame zählt sich SELBST mit, die Laterne nur die anderen.
	assert_eq(EssenceEffects.money_for(Essence.NEON, 5, 3), 6, "$2 je gezähltem Würfel")
	assert_eq(EssenceEffects.money_for(Essence.NEON, 5, 1), EssenceEffects.NEON_MONEY_PER_DIE,
		"allein bleibt der eigene Würfel")
	assert_eq(EssenceEffects.money_for(Essence.SODIUM_VAPOR, 5, 3), 2, "$1 je anderem Würfel")
	assert_eq(EssenceEffects.money_for(Essence.SODIUM_VAPOR, 5, 1), 0, "allein zahlt die Laterne nichts")

func test_essence_money_lands_in_the_take_report():
	var def := DieDefinition.new()
	def.essence_id = Essence.NEON
	var defs: Array[DieDefinition] = [def]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([""]), _p([0]),
		NO_CHARMS, -1, {0: Essence.NEON}, _p([0]))
	assert_eq(report.total_money(), EssenceEffects.NEON_MONEY_PER_DIE, "ein gezählter Würfel = $2")

# --- Schutz und Sperren ------------------------------------------------------------

func test_nitrogen_keeps_the_glass_from_shrinking():
	assert_true(EssenceEffects.protects_face_value(Essence.NITROGEN))
	var kept := MaterialEffects.mutate_value_once(5, DieMaterial.GLASS, NO_CHARMS, 1, _ids([Essence.NITROGEN]))
	assert_eq(kept, 5, "Schutzatmosphäre: die Seite verliert nichts")
	var plain := MaterialEffects.mutate_value_once(5, DieMaterial.GLASS, NO_CHARMS, 1, _ids([]))
	assert_eq(plain, 4, "ohne Stickstoff schrumpft Glas normal")

func test_helium_grows_the_up_face():
	assert_eq(EssenceEffects.face_growth(Essence.HELIUM), EssenceEffects.HELIUM_GROWTH)
	assert_eq(MaterialEffects.mutate_value_once(3, "", NO_CHARMS, 1, _ids([Essence.HELIUM])),
		3 + EssenceEffects.HELIUM_GROWTH)

## Zwei Fünfer plus ein gerader Krypton, der NICHT zur Kombination gehört.
const KRYPTON_DICE := [5, 5, 4]

func test_a_parity_clause_locks_krypton_out_like_any_other_die():
	# Nur ungerade: die 4 fällt raus, auch mit Seele - Krypton weitet die gewertete
	# Menge, er hebelt keine Klausel aus.
	var ctx := _ctx({2: Essence.KRYPTON}, {DiceScoring.CTX_PARITY: DiceScoring.PARITY_ODD})
	assert_eq(DiceScoring.legal_indices(_d(KRYPTON_DICE), ctx), _p([0, 1]))
	var shape := DiceScoring.hand_shape(DiceScoring.TWO_KIND, _d(KRYPTON_DICE), NO_CHARMS, ctx)
	assert_eq(Array(shape["scored"]), [0, 1], "gesperrt bleibt gesperrt")
	# Ohne Klausel zählt er weiter immer mit.
	var free := DiceScoring.hand_shape(DiceScoring.TWO_KIND, _d(KRYPTON_DICE), NO_CHARMS,
		_ctx({2: Essence.KRYPTON}))
	assert_eq(Array(free["scored"]), [0, 1, 2], "ohne Sperre bleibt der Vollzähler-Effekt")
	# Die Kategorie-Drossel ist keine Würfel-Sperre: sie greift weiter.
	var throttled := _ctx({0: Essence.KRYPTON}, {DiceScoring.CTX_THROTTLED: _ids([DiceScoring.TWO_KIND])})
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), NO_CHARMS, false, NO_MATS, {}, throttled), 0)

func test_a_locked_krypton_scores_nothing():
	var locked := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(KRYPTON_DICE), NO_CHARMS, false,
		NO_MATS, {}, _ctx({2: Essence.KRYPTON}, {DiceScoring.CTX_PARITY: DiceScoring.PARITY_ODD}))
	var free := DiceScoring.score_category(DiceScoring.TWO_KIND, _d(KRYPTON_DICE), NO_CHARMS, false,
		NO_MATS, {}, _ctx({2: Essence.KRYPTON}))
	assert_eq(locked, (10 + 5 + 5) * 2, "nur die beiden legalen Fünfer zählen")
	assert_eq(free, (10 + 5 + 5 + 4) * 2, "ohne Klausel zählen seine Augen mit")

# --- Zählreihenfolge: keine Essenz greift ein -------------------------------------

func test_no_essence_reorders_the_hand():
	var dice := _d([2, 6, 4])
	var scored := _p([0, 1, 2])
	assert_eq(DiceScoring.trigger_order(scored, dice), _p([1, 2, 0]), "Wert absteigend")

# --- Angebot: Rollen, Gating, Aufpreis --------------------------------------------

func test_start_dice_are_soulless():
	var run := GameRun.new_run()
	for die in run.owned_pool:
		assert_eq(die.essence_id, "", "das erste Glühen kommt aus dem Shop")

func test_rolled_essences_are_tradeable_and_priced():
	for i in 200:
		var id := DiceOffer.roll_essence()
		if id == "":
			continue
		var essence := Essence.by_id(id)
		assert_not_null(essence, "gerollte id ist ein echter Archetyp: %s" % id)
		assert_false(essence.secret, "Schwarzmarkt-Essenzen liegen nie im Handel")
		assert_gt(DiceOffer.essence_surcharge(id), 0, "jede Seele kostet Aufpreis")
	assert_eq(DiceOffer.essence_surcharge(""), 0, "ohne Seele kein Aufpreis")

func test_the_surcharge_climbs_with_the_rarity():
	assert_lt(DiceOffer.essence_surcharge(Essence.NEON), DiceOffer.essence_surcharge(Essence.PHOTON_GAS))
	assert_lt(DiceOffer.essence_surcharge(Essence.PHOTON_GAS), DiceOffer.essence_surcharge(Essence.SOLAR_WIND))

func test_a_unique_is_never_offered_twice():
	var owned := _ids([Essence.ANTIMATTER])
	for i in 200:
		assert_ne(DiceOffer.roll_essence(owned), Essence.ANTIMATTER, "Unikat schon im Besitz")
	for i in 200:
		# Antimaterie ist ohnehin Schwarzmarkt - im Bündel darf kein Unikat fallen.
		var id := DiceOffer.roll_essence([] as Array[String], false)
		if id != "":
			assert_false(Essence.by_id(id).unique, "Unikate nur im Einzel-Bündel")

# --- Rundenzustand im GameRun -------------------------------------------------------

func test_radon_decays_one_face_when_it_triggers():
	var run := GameRun.new_run()
	var die := run.owned_pool[0]
	die.essence_id = Essence.RADON
	var before := 0
	for value in die.faces:
		before += value
	assert_true(EssenceEffects.decay_die(die), "der Zerfall greift")
	var after := 0
	for value in die.faces:
		after += value
	assert_eq(after, before - 1, "eine zufällige Seite verliert ein Auge")

func test_owned_essence_ids_lists_every_soul_once():
	var run := GameRun.new_run()
	run.owned_pool[0].essence_id = Essence.ARGON
	run.owned_pool[1].essence_id = Essence.ARGON
	run.owned_pool[2].essence_id = Essence.NEON
	var ids := run.owned_essence_ids()
	assert_eq(ids.size(), 2, "keine Dubletten")
	assert_true(ids.has(Essence.ARGON) and ids.has(Essence.NEON))

func test_a_purchase_prefers_a_soulless_pool_slot():
	# Eine Essenz ist angeboren und nicht wiederbeschaffbar - sie wird zuletzt
	# übermalt.
	var run := GameRun.new_run()
	for die in run.owned_pool:
		die.essence_id = Essence.NEON
	run.owned_pool[7].essence_id = ""
	var fresh := DieDefinition.standard()
	fresh.display_name = "Neuling"
	run._replace_pool_entry(fresh)
	assert_eq(run.owned_pool[7].display_name, "Neuling", "der seelenlose Platz wird zuerst geräumt")

# --- Kohlendioxid: das Löschgas schluckt einen Fumble je Runde ---------------------

func test_carbon_dioxide_is_the_only_smotherer():
	assert_true(EssenceEffects.smothers_farkle(Essence.CARBON_DIOXIDE))
	assert_false(EssenceEffects.smothers_farkle(Essence.NEON))

func test_the_smother_charge_holds_once_per_round_per_die():
	var run := GameRun.new_run()
	var die := run.owned_pool[0]
	die.essence_id = Essence.CARBON_DIOXIDE
	run.roll_essence_round_state()
	var defs: Array[DieDefinition] = [die]
	assert_eq(run.smother_slot(defs, _p([0])), 0, "zu Rundenbeginn steht die Ladung")
	run.consume_smother(die, 0)
	assert_eq(run.smother_slot(defs, _p([0])), -1, "verbraucht")
	run.roll_essence_round_state()
	assert_eq(run.smother_slot(defs, _p([0])), 0, "die neue Runde füllt nach")

func test_smothering_costs_the_up_face():
	var run := GameRun.new_run()
	var die := run.owned_pool[0]
	die.essence_id = Essence.CARBON_DIOXIDE
	die.faces[2] = 6
	die.set_face_material(2, DieMaterial.GOLD)
	die.dope(2)
	die.set_rune(2, Rune.AFTERGLOW)
	run.roll_essence_round_state()
	run.consume_smother(die, 2)
	assert_eq(die.faces[2], 1, "die obere Seite fällt auf 1")
	assert_eq(die.materials[2], "", "und verliert ihr Material")
	assert_eq(die.material_level(2), 0, "der Zustand geht mit dem Material")
	assert_true(die.has_rune(2, Rune.AFTERGLOW), "die Rune sitzt in der Schale, nicht in der Glasur")

func test_smothering_without_a_face_only_burns_the_charge():
	var run := GameRun.new_run()
	var die := run.owned_pool[0]
	die.essence_id = Essence.CARBON_DIOXIDE
	run.roll_essence_round_state()
	run.consume_smother(die, -1)
	assert_eq(die.faces, [1, 2, 3, 4, 5, 6] as Array[int], "ohne obere Seite passiert nichts")

func test_the_smother_only_counts_dice_in_the_throw():
	var run := GameRun.new_run()
	var die := run.owned_pool[0]
	die.essence_id = Essence.CARBON_DIOXIDE
	run.roll_essence_round_state()
	var defs: Array[DieDefinition] = [DieDefinition.new(), die]
	assert_eq(run.smother_slot(defs, _p([0])), -1, "der CO2-Würfel liegt gar nicht im Wurf")
	assert_eq(run.smother_slot(defs, _p([0, 1])), 1, "beteiligt: er löscht")

func test_each_carbon_dioxide_die_brings_its_own_charge():
	var run := GameRun.new_run()
	var first := run.owned_pool[0]
	var second := run.owned_pool[1]
	first.essence_id = Essence.CARBON_DIOXIDE
	second.essence_id = Essence.CARBON_DIOXIDE
	run.roll_essence_round_state()
	var defs: Array[DieDefinition] = [first, second]
	run.consume_smother(first, 0)
	assert_eq(run.smother_slot(defs, _p([0, 1])), 1, "der zweite Würfel hat seine eigene Ladung")

# --- Irrlicht: einmal je Runde auf eine Nachbarseite kippen ------------------------

func test_will_o_wisp_is_the_only_tipper():
	assert_true(EssenceEffects.can_tip(Essence.WILL_O_WISP))
	assert_false(EssenceEffects.can_tip(Essence.NEON))

func test_the_tip_holds_once_per_round_per_die():
	var run := GameRun.new_run()
	var die := run.owned_pool[0]
	die.essence_id = Essence.WILL_O_WISP
	run.roll_essence_round_state()
	assert_true(run.can_tip_die(die), "zu Rundenbeginn darf er kippen")
	run.consume_tip(die)
	assert_false(run.can_tip_die(die), "verbraucht")
	run.roll_essence_round_state()
	assert_true(run.can_tip_die(die), "die neue Runde erlaubt es wieder")

func test_a_die_without_the_wisp_never_tips():
	var run := GameRun.new_run()
	assert_false(run.can_tip_die(run.owned_pool[0]))
	assert_false(run.can_tip_die(null))

func test_tipping_targets_are_the_four_neighbours():
	# Die Gegenseite ist nie dabei - gekippt wird über eine Kante.
	for face in 6:
		var neighbours := DieDefinition.adjacent_faces(face)
		assert_eq(neighbours.size(), 4)
		assert_false(neighbours.has(face))
		assert_false(neighbours.has(DieDefinition.opposite_face(face)))

# --- Polarlicht: Joker der Kombinationssuche, nie der Augen ------------------------

func _wild(slot: int) -> Dictionary:
	return _ctx({slot: Essence.AURORA})

func test_aurora_is_the_only_wild_and_a_unique():
	assert_true(EssenceEffects.is_wild(Essence.AURORA))
	assert_false(EssenceEffects.is_wild(Essence.NEON))
	# Die Erkennung verlässt sich darauf, dass es NIE zwei Joker geben kann.
	assert_true(Essence.by_id(Essence.AURORA).unique, "Legendär und damit Unikat")
	assert_eq(Essence.by_id(Essence.AURORA).rarity, Essence.Rarity.LEGENDARY)

func test_the_wild_slot_is_found_in_the_ctx():
	assert_eq(DiceScoring.wild_slot(_wild(3)), 3)
	assert_eq(DiceScoring.wild_slot(_ctx({3: Essence.NEON})), -1)
	assert_eq(DiceScoring.wild_slot({}), -1)

func test_the_wild_completes_a_pasch():
	# 5,5,5,5,W: ohne Joker ein Viererpasch, mit ihm der Fünferpasch.
	var dice := _d([5, 5, 5, 5, 2])
	assert_false(DiceScoring.qualifies(DiceScoring.FIVE_KIND, dice))
	assert_true(DiceScoring.qualifies(DiceScoring.FIVE_KIND, dice, _wild(4)))
	assert_eq(DiceScoring.best_hand(dice, NO_CHARMS, false, NO_MATS, {}, _wild(4))["key"],
		DiceScoring.FIVE_KIND, "der Rang steigt")
	assert_eq(DiceScoring.participating_indices(DiceScoring.FIVE_KIND, dice, [], _wild(4)),
		_p([0, 1, 2, 3, 4]), "der Joker zählt mit")

func test_the_wild_scores_its_printed_eyes():
	# Fünferpasch mit Joker: Basis = 50 Punkte + 5+5+5+5 + die AUFGEDRUCKTE 2.
	var dice := _d([5, 5, 5, 5, 2])
	var score := DiceScoring.score_category(DiceScoring.FIVE_KIND, dice, NO_CHARMS, false, NO_MATS, {}, _wild(4))
	assert_eq(score, (50 + 5 + 5 + 5 + 5 + 2) * 10, "der Joker bringt seine echten Augen mit")

func test_a_wild_that_completes_nothing_better_falls_through():
	# Zwei Fünfer und lauter Einzelgänger: der Joker macht daraus höchstens einen
	# Dreierpasch - mehr trägt die Hand nicht.
	var dice := _d([5, 5, 1, 2, 3])
	assert_eq(DiceScoring.best_hand(dice, NO_CHARMS, false, NO_MATS, {}, _wild(4))["key"],
		DiceScoring.THREE_KIND, "er füllt das Paar zum Dreierpasch")
	assert_false(DiceScoring.qualifies(DiceScoring.FOUR_KIND, dice, _wild(4)))

func test_the_parity_filter_judges_the_wilds_printed_value():
	# Sperren sind Kryptons Revier: unter "nur ungerade" fällt der Joker mit
	# seiner AUFGEDRUCKTEN 2 raus und kann nichts mehr vervollständigen.
	var dice := _d([5, 5, 5, 5, 2])
	var ctx := _ctx({4: Essence.AURORA}, {DiceScoring.CTX_PARITY: DiceScoring.PARITY_ODD})
	assert_false(DiceScoring.qualifies(DiceScoring.FIVE_KIND, dice, ctx),
		"der gefilterte Joker spielt gar nicht mit")
	assert_true(DiceScoring.qualifies(DiceScoring.FOUR_KIND, dice, ctx), "die vier Fünfer bleiben")

func test_no_essence_takes_a_die_out_of_the_parity_lock():
	# Gegenprobe zur Regel: auch Krypton bleibt gesperrt - keine Seele hebelt eine
	# Würfel-Sperre aus.
	var dice := _d([5, 5, 5, 5, 2])
	var ctx := _ctx({4: Essence.KRYPTON}, {DiceScoring.CTX_PARITY: DiceScoring.PARITY_ODD})
	assert_eq(DiceScoring.legal_indices(dice, ctx), _p([0, 1, 2, 3]), "die gerade 2 fällt raus")
	assert_eq(DiceScoring.legal_indices(dice, _wild(4)).size(), 5, "ohne Filter ist ohnehin alles legal")

func test_a_throttled_wild_hand_falls_one_rank():
	# Die Drossel sperrt Kategorien, nicht Würfel: der Joker rutscht mit.
	var dice := _d([5, 5, 5, 5, 2])
	var ctx := _ctx({4: Essence.AURORA}, {DiceScoring.CTX_THROTTLED: _ids([DiceScoring.FIVE_KIND])})
	assert_eq(DiceScoring.best_hand(dice, NO_CHARMS, false, NO_MATS, {}, ctx)["key"],
		DiceScoring.FOUR_KIND, "eine Stufe tiefer, weiter mit Joker")

func test_the_farkle_verdict_sees_the_wild_on_both_sides():
	# Der Joker verschiebt, WELCHE Kategorie zutrifft - der Vergleich braucht ihn
	# darum auf beiden Seiten (alte Seite über old_ctx).
	var before := _d([5, 5, 5, 5, 2])
	var after := _d([5, 5, 5, 5, 2])
	var wild_ctx := _wild(4)
	# NICHT {} - ein leeres old_ctx bedeutet laut is_strictly_better "beide Seiten
	# teilen den ctx"; die joker-freie Seite braucht darum einen echten Eintrag.
	var plain_ctx := _ctx({})
	# Alte Seite MIT Joker (Fünferpasch), neue ohne: kein Fortschritt.
	assert_false(DiceScoring.is_strictly_better(after, before, NO_CHARMS, NO_MATS, NO_MATS, {}, plain_ctx, wild_ctx),
		"gegen einen Fünferpasch ist der Viererpasch kein Aufstieg")
	# Umgekehrt: alte Seite ohne Joker, neue mit - der Rang steigt.
	assert_true(DiceScoring.is_strictly_better(after, before, NO_CHARMS, NO_MATS, NO_MATS, {}, wild_ctx, plain_ctx))

# --- Quintessenz: der fünfte Stoff borgt sich die anderen Seelen -------------------

func test_quintessence_borrows_every_other_lying_soul():
	var sets := EssenceEffects.effective_sets({0: Essence.QUINTESSENCE, 1: Essence.NEON, 2: Essence.RADON})
	var borrowed := EssenceEffects.set_at(sets, 0)
	assert_true(borrowed.has(Essence.QUINTESSENCE), "die eigene Seele bleibt")
	assert_true(borrowed.has(Essence.NEON))
	assert_true(borrowed.has(Essence.RADON))
	assert_eq(EssenceEffects.set_at(sets, 1), _ids([Essence.NEON]), "die anderen borgen nichts")

func test_a_plain_die_keeps_exactly_its_own_soul():
	var sets := EssenceEffects.effective_sets({0: Essence.ARGON, 1: Essence.NEON})
	assert_eq(EssenceEffects.set_at(sets, 0), _ids([Essence.ARGON]))
	assert_eq(EssenceEffects.set_at(sets, 1), _ids([Essence.NEON]))

func test_the_borrowed_factor_is_the_max_never_the_product():
	# DIE Invariante: Argon (2) + Quecksilberdampf (3) ergeben 3, nie 6.
	var sets := EssenceEffects.effective_sets(
		{0: Essence.QUINTESSENCE, 1: Essence.ARGON, 2: Essence.MERCURY_VAPOR})
	var factor := EssenceEffects.activation_factor_of(EssenceEffects.set_at(sets, 0))
	assert_eq(factor, 3, "das Maximum der geborgten Faktoren")
	assert_ne(factor, 6, "niemals das Produkt")

func test_the_borrowed_factor_still_takes_the_vapor_charm_bonus():
	var sets := EssenceEffects.effective_sets({0: Essence.QUINTESSENCE, 1: Essence.ARGON})
	assert_eq(EssenceEffects.activation_factor_of(EssenceEffects.set_at(sets, 0),
		_ids([Charm.MERCURY_VAPOR])), 3, "Argon 2 + Dampf 1")

func test_the_flash_crits_are_borrowable_now():
	# Xenon und Kugelblitz kriten unbedingt - kein Speicher mehr am Würfel, also
	# borgt die Quintessenz sie mit: ×1,5 × ×2 = ×3.
	var sets := EssenceEffects.effective_sets(
		{0: Essence.QUINTESSENCE, 1: Essence.XENON, 2: Essence.BALL_LIGHTNING})
	var borrowed := EssenceEffects.set_at(sets, 0)
	assert_true(borrowed.has(Essence.XENON))
	assert_true(borrowed.has(Essence.BALL_LIGHTNING))
	assert_almost_eq(EssenceEffects.crit_of(borrowed, 5), 3.0, 0.0001)

func test_the_state_carrying_souls_are_never_borrowed():
	# Die Phosphoreszenz führt einen Speicher am Würfel-Exemplar - geborgt
	# gehörte der zwei Würfeln.
	var sets := EssenceEffects.effective_sets(
		{0: Essence.QUINTESSENCE, 1: Essence.PHOSPHORESCENCE})
	var borrowed := EssenceEffects.set_at(sets, 0)
	assert_false(borrowed.has(Essence.PHOSPHORESCENCE))
	assert_eq(borrowed.size(), 1, "nur die eigene Seele bleibt übrig")

func test_the_wild_is_never_borrowed_either():
	# Sonst gäbe es zwei Joker und die Erkennung verlöre ihre Unikat-Annahme.
	var sets := EssenceEffects.effective_sets({0: Essence.QUINTESSENCE, 1: Essence.AURORA})
	assert_false(EssenceEffects.set_at(sets, 0).has(Essence.AURORA))

func test_borrowed_radon_irradiates_the_others():
	# Die Quintessenz strahlt wie ein Radon-Würfel auf ihre Mitwürfel.
	var sets := EssenceEffects.effective_sets({0: Essence.QUINTESSENCE, 1: Essence.RADON})
	assert_eq(EssenceEffects.foreign_eye_bonus(2, _p([0, 1, 2]), sets),
		EssenceEffects.RADON_EYE_BONUS * 2, "beide Quellen strahlen")

func test_borrowed_lenses_chain():
	var sets := EssenceEffects.effective_sets({0: Essence.QUINTESSENCE, 1: Essence.HYDROGEN})
	assert_eq(EssenceEffects.lens_value_of(EssenceEffects.set_at(sets, 0), 5), 10,
		"der geborgte Wasserstoff verdoppelt auch die Quintessenz")

func test_borrowed_protection_and_growth():
	var sets := EssenceEffects.effective_sets(
		{0: Essence.QUINTESSENCE, 1: Essence.NITROGEN, 2: Essence.HELIUM})
	var borrowed := EssenceEffects.set_at(sets, 0)
	assert_true(EssenceEffects.protects_face_value_of(borrowed), "Schutzatmosphäre geborgt")
	assert_eq(EssenceEffects.face_growth_of(borrowed), EssenceEffects.HELIUM_GROWTH,
		"Helium hebt auch sie")

# --- Die sieben neuen Seelen ------------------------------------------------------

func _die_with(essence_id: String) -> DieDefinition:
	var die := DieDefinition.standard()
	die.essence_id = essence_id
	return die

func test_radiation_pressure_blows_up_every_face_and_the_sim_agrees():
	var die := _die_with(Essence.RADIATION_PRESSURE)
	var defs: Array[DieDefinition] = [die]
	var ids := _ids([Essence.RADIATION_PRESSURE])
	# Simulation der oberen Seite: dieselbe Schiene wie Knochen/Helium.
	var simulated := MaterialEffects.value_after_activations(die.faces[0], 1, "", NO_CHARMS, 1, ids)
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([""]), _p([0]), NO_CHARMS, -1,
		{0: Essence.RADIATION_PRESSURE}, _p([0]))
	assert_eq(die.faces[0], simulated, "Sim und Def landen auf derselben Zahl")
	assert_eq(die.faces[0], 1 + EssenceEffects.PRESSURE_GROWTH)
	assert_eq(die.faces[3], 4 + EssenceEffects.PRESSURE_GROWTH, "auch die Seiten, die nicht oben lagen")

func test_cyanide_pays_per_own_gold_face_once_per_turn():
	var die := _die_with(Essence.CYANIDE)
	die.set_face_material(1, DieMaterial.GOLD)
	die.set_face_material(4, DieMaterial.GOLD)
	var ids := _ids([Essence.CYANIDE])
	assert_eq(EssenceEffects.gold_face_money_of(ids, die.materials), 2 * EssenceEffects.CYANIDE_PER_GOLD)
	# Zwei Auslösungen (Argon) dürfen NICHT zweimal zahlen.
	var defs: Array[DieDefinition] = [die]
	var sets := {0: [Essence.CYANIDE, Essence.ARGON] as Array[String]}
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([""]), _p([0]),
		NO_CHARMS, -1, sets, _p([0]))
	assert_eq(report.money, 2 * EssenceEffects.CYANIDE_PER_GOLD, "je Zug, nie je Auslösung")

func test_xray_fires_the_opposite_face_once():
	var die := _die_with(Essence.XRAY)
	var faces := EssenceEffects.link_faces(die, 1, _ids([Essence.XRAY]))
	assert_eq(faces, _p([DieDefinition.opposite_face(1)]), "genau die Gegenseite")

func test_essence_links_ignore_the_pointer_wiring():
	var die := _die_with(Essence.XRAY)
	# Die Leiterbahn läuft getrennt (auf Chance, je Würfel-Trigger) - hier steht
	# nur, was die Seele deterministisch mitzieht.
	die.pointers[1] = 0
	var faces := EssenceEffects.link_faces(die, 1, _ids([Essence.XRAY]))
	assert_eq(faces, _p([DieDefinition.opposite_face(1)]), "der Zeiger gehört nicht hierher")
	var ring := EssenceEffects.link_faces(die, 1, _ids([Essence.CORONA, Essence.XRAY]))
	assert_eq(ring.count(DieDefinition.opposite_face(1)), 1, "jede Seite feuert höchstens einmal")

func test_corona_fires_one_neighbour():
	var die := _die_with(Essence.CORONA)
	var faces := EssenceEffects.link_faces(die, 2, _ids([Essence.CORONA]))
	assert_eq(faces, _p([DieDefinition.adjacent_faces(2)[0]]), "die erste Nachbarseite")
	assert_false(faces.has(DieDefinition.opposite_face(2)), "die Gegenseite gehört dem Röntgenlicht")

func test_corona_ring_comes_before_the_xray_face():
	var die := _die_with(Essence.CORONA)
	var faces := EssenceEffects.link_faces(die, 2, _ids([Essence.CORONA, Essence.XRAY]))
	assert_eq(faces.size(), 2)
	assert_eq(faces[1], DieDefinition.opposite_face(2), "Ring zuerst, dann die Gegenseite")

func test_varnish_clamps_at_doped_and_spares_bare_faces():
	var varnish := _ids([Essence.VARNISH])
	assert_eq(EssenceEffects.boosted_level(0, varnish), 0, "eine nackte Seite bleibt nackt")
	assert_eq(EssenceEffects.boosted_level(1, varnish), DieMaterial.MAX_LEVEL)
	assert_eq(EssenceEffects.boosted_level(DieMaterial.MAX_LEVEL, varnish), DieMaterial.MAX_LEVEL,
		"dotiert bleibt dotiert")
	assert_eq(EssenceEffects.boosted_level(1, _ids([Essence.NEON])), 1, "ohne Firnis keine Schicht")

func test_varnish_lifts_the_level_only_in_the_score():
	assert_eq(EssenceEffects.level_boost(Essence.VARNISH), 1)
	assert_eq(EssenceEffects.level_boost(Essence.NEON), 0)
	# Rubin zahlt normal +4 Mult, dotiert kritet er ×2 - der Firnis hebt eine
	# echte Normal-Seite in den Krit-Zweig.
	var plain := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), NO_CHARMS, false,
		_m([DieMaterial.RUBY, ""]), {}, {DiceScoring.CTX_MATERIAL_LEVELS: {0: {"level": 1}}})
	var doped := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), NO_CHARMS, false,
		_m([DieMaterial.RUBY, ""]), {}, {DiceScoring.CTX_MATERIAL_LEVELS: {0: {"level": DieMaterial.MAX_LEVEL}}})
	assert_eq(plain, 20 * 6)
	assert_eq(doped, 20 * 4, "dotiert kritet statt zu addieren")

func test_varnish_never_writes_the_level_into_the_def():
	var die := _die_with(Essence.VARNISH)
	die.set_face_material(0, DieMaterial.GOLD)
	var defs: Array[DieDefinition] = [die]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]),
		NO_CHARMS, -1, {0: Essence.VARNISH}, _p([0]))
	assert_eq(die.material_level(0), 1, "die Def bleibt auf ihrem echten Zustand")
	assert_eq(report.total_money(), MaterialEffects.GOLD_PAYOUT, "Gold zahlt den echten, undotierten Satz")

func test_phosphorescence_stores_and_repeats_its_base():
	var run := GameRun.new_run()
	var die := run.owned_pool[0]
	die.essence_id = Essence.PHOSPHORESCENCE
	run.roll_essence_round_state()
	assert_eq(run.phosphor_store(die), 0, "zu Rundenbeginn leer")
	var defs: Array[DieDefinition] = [die, run.owned_pool[1]]
	var ctx := _ctx({0: Essence.PHOSPHORESCENCE})
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d([5, 5]), NO_CHARMS, false,
		_m(["", ""]), {}, ctx)
	run.note_phosphor_stores(defs, breakdown)
	assert_eq(run.phosphor_store(die), 5, "sein Basis-Anteil: die eigenen Augen")
	# Der nächste Zug legt den Speicher obendrauf.
	var loaded := _ctx({0: Essence.PHOSPHORESCENCE}, {DiceScoring.CTX_PHOSPHOR_STORE: {0: 5}})
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), NO_CHARMS, false, NO_MATS, {}, loaded),
		(10 + 5 + 5 + 5) * 2)

func test_the_phosphor_store_never_feeds_itself():
	# Ein Speicher, keine Kette: der eben ausgeschüttete Betrag darf nicht wieder
	# mit eingelagert werden, sonst wächst der Würfel Zug um Zug aus sich selbst.
	var run := GameRun.new_run()
	var die := run.owned_pool[0]
	die.essence_id = Essence.PHOSPHORESCENCE
	run.roll_essence_round_state()
	var defs: Array[DieDefinition] = [die, run.owned_pool[1]]
	var loaded := _ctx({0: Essence.PHOSPHORESCENCE}, {DiceScoring.CTX_PHOSPHOR_STORE: {0: 5}})
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d([5, 5]), NO_CHARMS, false,
		_m(["", ""]), {}, loaded)
	run.note_phosphor_stores(defs, breakdown)
	assert_eq(run.phosphor_store(die), 5, "nur die eigenen Augen, nicht die 5 aus dem Speicher")

func test_the_phosphor_store_accumulates_and_outlives_the_round():
	var run := GameRun.new_run()
	var die := run.owned_pool[0]
	die.essence_id = Essence.PHOSPHORESCENCE
	run.roll_essence_round_state()
	var defs: Array[DieDefinition] = [die, run.owned_pool[1]]
	var ctx := _ctx({0: Essence.PHOSPHORESCENCE})
	run.note_phosphor_stores(defs, ScoreBreakdown.build(DiceScoring.TWO_KIND, _d([6, 6]),
		NO_CHARMS, false, _m(["", ""]), {}, ctx))
	assert_eq(run.phosphor_store(die), 6)
	run.note_phosphor_stores(defs, ScoreBreakdown.build(DiceScoring.TWO_KIND, _d([2, 2]),
		NO_CHARMS, false, _m(["", ""]), {}, ctx))
	assert_eq(run.phosphor_store(die), 8, "erneutes Werten legt oben drauf")
	run.roll_essence_round_state()
	assert_eq(run.phosphor_store(die), 8, "der Speicher überlebt die Runde")

# --- Miasma: Ansteckung statt fauler Handel ---------------------------------------

func test_miasma_halves_itself_and_grows_the_hand():
	var sick := _die_with(Essence.MIASMA)
	sick.faces[0] = 7
	var other := DieDefinition.standard()
	other.faces[0] = 2
	var defs: Array[DieDefinition] = [sick, other]
	MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m(["", ""]), _p([0, 1]),
		NO_CHARMS, -1, {0: Essence.MIASMA}, _p([0, 1]))
	assert_eq(sick.faces[0], 4, "7 verliert die abgerundete Hälfte (3)")
	assert_eq(other.faces[0], 5, "und genau die wächst nebenan")

func test_a_miasma_one_gives_nothing_away():
	var sick := _die_with(Essence.MIASMA)
	sick.faces[0] = 1
	var other := DieDefinition.standard()
	var defs: Array[DieDefinition] = [sick, other]
	MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m(["", ""]), _p([0, 1]),
		NO_CHARMS, -1, {0: Essence.MIASMA}, _p([0, 1]))
	assert_eq(sick.faces[0], 1)
	assert_eq(other.faces[0], 1, "ohne Verlust kein Zuwachs")

func test_nitrogen_and_the_brand_block_the_infection():
	var sick := _die_with(Essence.MIASMA)
	sick.faces[0] = 8
	var other := DieDefinition.standard()
	var defs: Array[DieDefinition] = [sick, other]
	var sets := {0: [Essence.MIASMA, Essence.NITROGEN] as Array[String]}
	MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m(["", ""]), _p([0, 1]),
		NO_CHARMS, -1, sets, _p([0, 1]))
	assert_eq(sick.faces[0], 8, "Stickstoff hält die Seite")
	assert_eq(other.faces[0], 1, "und niemand bekommt etwas")
	# Einbrand auf DER Seite tut dasselbe.
	var burned := _die_with(Essence.MIASMA)
	burned.faces[0] = 8
	burned.set_rune(0, Rune.BURN_IN)
	var third := DieDefinition.standard()
	var burned_defs: Array[DieDefinition] = [burned, third]
	MaterialEffects.apply_take_effects(burned_defs, _p([0, 0]), _m(["", ""]), _p([0, 1]),
		NO_CHARMS, -1, {0: Essence.MIASMA}, _p([0, 1]))
	assert_eq(burned.faces[0], 8, "der Einbrand hält seine Seite")
	assert_eq(third.faces[0], 1)

func test_miasma_no_longer_pays_money():
	assert_eq(EssenceEffects.money_for(Essence.MIASMA, 6, 3), 0)

# --- Ansteckung: verschachtelt in die Zählung, nicht im Schwanz -------------------
# Ein Paar Achter zählt in Slot-Reihenfolge; das Miasma gibt NACH jeder Zündung
# ab, der Mitwürfel trägt den Zuwachs also schon in seine eigene Zündung.

## sets = fertige Essenz-MENGEN je Slot, mats = Seiten-Material je Slot.
## Wertung, Schrittliste und Nahme laufen über dieselbe Hand - nur so lässt sich
## prüfen, dass Simulation und Def auf derselben Zahl enden.
func _infection_hand(sets: Dictionary, charm_ids: Array[String] = NO_CHARMS,
		mats: Array[String] = _m(["", ""])) -> Dictionary:
	var dice := _d([8, 8])
	var ctx := {DiceScoring.CTX_ESSENCE_SET: sets}
	var defs: Array[DieDefinition] = []
	for i in 2:
		var die := DieDefinition.new()
		die.faces = _d([8, 2, 3, 4, 5, 6])
		if i < mats.size() and mats[i] != "":
			die.set_face_material(0, mats[i])
		defs.append(die)
	MaterialEffects.apply_take_effects(defs, _p([0, 0]), mats, _p([0, 1]),
		charm_ids, -1, sets, _p([0, 1]))
	return {
		"score": DiceScoring.score_category(DiceScoring.TWO_KIND, dice, charm_ids, false, mats, {}, ctx),
		"breakdown": ScoreBreakdown.build(DiceScoring.TWO_KIND, dice, charm_ids, false, mats, {}, ctx),
		"defs": defs,
	}

## Endwert der Simulation je Slot: die LETZTE Zündung trägt ihn als value_after.
func _simulated_values(breakdown: Dictionary) -> Dictionary:
	var out := {}
	for step: Dictionary in breakdown["die_steps"]:
		var last := 0
		for group: Dictionary in step["die_triggers"]:
			for firing: Dictionary in group["firings"]:
				last = int(firing["value_after"])
		out[int(step["slot"])] = last
	return out

func test_the_infection_reaches_the_later_die_before_it_counts():
	var hand := _infection_hand({0: _ids([Essence.MIASMA])})
	# Slot 0 zählt 8 und gibt 4 ab - Slot 1 zählt darum 12 statt 8.
	assert_eq(int(hand["score"]), (10 + 8 + 12) * 2)
	var defs: Array = hand["defs"]
	assert_eq(defs[0].faces[0], 4)
	assert_eq(defs[1].faces[0], 12)

func test_a_later_miasma_leaves_the_eyes_of_the_earlier_die_alone():
	var hand := _infection_hand({1: _ids([Essence.MIASMA])})
	assert_eq(int(hand["score"]), (10 + 8 + 8) * 2, "Slot 0 hat längst gezählt")
	var defs: Array = hand["defs"]
	assert_eq(defs[0].faces[0], 12, "seine Def wächst trotzdem")
	assert_eq(defs[1].faces[0], 4)

func test_the_infection_compounds_over_two_triggers():
	var hand := _infection_hand({0: _ids([Essence.MIASMA, Essence.ARGON])})
	# 8 gibt 4 ab (4 / 12), der zweite Antritt zählt 4 und gibt 2 ab (2 / 14).
	assert_eq(int(hand["score"]), (10 + 8 + 4 + 14) * 2)
	var defs: Array = hand["defs"]
	assert_eq(defs[0].faces[0], 2)
	assert_eq(defs[1].faces[0], 14)

func test_the_censer_spreads_the_same_amount_every_trigger():
	# Ohne Selbstverlust schrumpft die Quelle nie - sie steckt zweimal mit 4 an.
	var hand := _infection_hand({0: _ids([Essence.MIASMA, Essence.ARGON])}, _ids([Charm.CENSER]))
	assert_eq(int(hand["score"]), (10 + 8 + 8 + 16) * 2)
	var defs: Array = hand["defs"]
	assert_eq(defs[0].faces[0], 8)
	assert_eq(defs[1].faces[0], 16)

func test_nitrogen_blocks_the_infection_at_every_trigger():
	var hand := _infection_hand({0: _ids([Essence.MIASMA, Essence.ARGON, Essence.NITROGEN])})
	assert_eq(int(hand["score"]), (10 + 8 + 8 + 8) * 2, "nichts wandert")
	var defs: Array = hand["defs"]
	assert_eq(defs[0].faces[0], 8)
	assert_eq(defs[1].faces[0], 8)

func test_the_bone_grows_first_then_the_infection_halves():
	# 8 +2 = 10 gibt 5 ab (5 / 13); 5 +2 = 7 gibt 3 ab (4 / 16).
	var hand := _infection_hand({0: _ids([Essence.MIASMA, Essence.ARGON])}, NO_CHARMS,
		_m([DieMaterial.BONE, ""]))
	assert_eq(int(hand["score"]), (10 + 8 + 5 + 16) * 2)
	var defs: Array = hand["defs"]
	assert_eq(defs[0].faces[0], 4)
	assert_eq(defs[1].faces[0], 16)
	var simulated := _simulated_values(hand["breakdown"])
	assert_eq(int(simulated[0]), defs[0].faces[0], "Simulation und Def enden gleich")
	assert_eq(int(simulated[1]), defs[1].faces[0])

func test_the_breakdown_mirrors_the_infection():
	# merge_total ist die EIGENE Summe der Schrittliste - das Sicherheitsnetz in
	# build() würde total sonst still auf die Wertung ziehen.
	for sets: Dictionary in [{0: _ids([Essence.MIASMA])}, {1: _ids([Essence.MIASMA])},
			{0: _ids([Essence.MIASMA, Essence.ARGON])}]:
		var hand := _infection_hand(sets)
		assert_eq(int(hand["breakdown"]["merge_total"]), int(hand["score"]),
			"Schrittliste und Wertung zählen dieselbe Ansteckung")

func test_borrowed_krypton_still_counts_every_lying_die():
	var sets := EssenceEffects.effective_sets({0: Essence.QUINTESSENCE, 1: Essence.KRYPTON})
	var ctx := {DiceScoring.CTX_ESSENCE_SET: sets}
	var shape := DiceScoring.hand_shape(DiceScoring.ONE_KIND, _d([2, 4]), NO_CHARMS, ctx)
	assert_eq(Array(shape["scored"]), [0, 1], "die geborgte Seele zählt beide mit")

func test_borrowed_money_adds_up():
	var sets := EssenceEffects.effective_sets({0: Essence.QUINTESSENCE, 1: Essence.NEON})
	assert_eq(EssenceEffects.money_of(EssenceEffects.set_at(sets, 0), 5, 2),
		2 * EssenceEffects.NEON_MONEY_PER_DIE, "die geborgte Reklame zahlt")

func test_quintessence_is_a_unique_so_it_never_copies_itself():
	assert_true(Essence.by_id(Essence.QUINTESSENCE).unique)
	assert_eq(Essence.by_id(Essence.QUINTESSENCE).rarity, Essence.Rarity.LEGENDARY)

func test_the_set_reader_takes_both_ctx_shapes():
	# CTX_ESSENCES trägt die Identität (Slot -> id), CTX_ESSENCE_SET die Wirkung
	# (Slot -> Menge) - set_at liest beide.
	assert_eq(EssenceEffects.set_at({0: Essence.NEON}, 0), _ids([Essence.NEON]))
	assert_eq(EssenceEffects.set_at({0: [Essence.NEON, Essence.RADON]}, 0),
		_ids([Essence.NEON, Essence.RADON]))
	assert_eq(EssenceEffects.set_at({0: ""}, 0), _ids([]))
	assert_eq(EssenceEffects.set_at({}, 0), _ids([]))
