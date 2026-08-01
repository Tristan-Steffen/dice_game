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
		assert_ne(essence.epithet, "", "Beiname fehlt bei %s" % essence.id)
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
	# Argon (×2) + Sauerstoff davor (+1) = 3, nie 4: nur die Essenz multipliziert.
	var count := MaterialEffects.activation_count(1, NO_CHARMS, 5, -1, _ids([Essence.ARGON]), false, 1)
	assert_eq(count, 3)

# --- Augen: Wasserstoff, Miasma, Antimaterie, Radon ------------------------------

func test_hydrogen_doubles_its_own_eyes():
	assert_eq(EssenceEffects.eye_value(Essence.HYDROGEN, 5), 10)

func test_miasma_keeps_the_rounded_up_half():
	assert_eq(EssenceEffects.eye_value(Essence.MIASMA, 5), 3, "aufgerundet")
	assert_eq(EssenceEffects.money_for(Essence.MIASMA, 5, 1), 2, "die andere Hälfte wird Geld")

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

func test_xenon_and_ball_lightning_only_crit_while_armed():
	assert_eq(EssenceEffects.crit_once_for(Essence.XENON, 5, 0, true), 2)
	assert_eq(EssenceEffects.crit_once_for(Essence.XENON, 5, 0, false), 1, "verschossen = kein Krit")
	assert_eq(EssenceEffects.crit_once_for(Essence.BALL_LIGHTNING, 5, 0, true), 2)
	assert_eq(EssenceEffects.crit_once_for(Essence.BALL_LIGHTNING, 5, 0, false), 1)

func test_ozone_grows_with_the_crits_before_it():
	assert_eq(EssenceEffects.crit_once_for(Essence.OZONE, 5, 0), 1, "ohne Vorgänger kein Schlag")
	assert_eq(EssenceEffects.crit_once_for(Essence.OZONE, 5, 2), 3, "1 + 2 Krits davor")

func test_antimatter_crits_with_its_eyes():
	assert_eq(EssenceEffects.crit_once_for(Essence.ANTIMATTER, 6), 6)
	assert_eq(EssenceEffects.crit_once_for(Essence.ANTIMATTER, 0), 1, "nie unter ×1")

func test_only_the_conditional_essences_ask_for_the_round_state():
	assert_true(EssenceEffects.has_armed_crit(Essence.XENON))
	assert_true(EssenceEffects.has_armed_crit(Essence.BALL_LIGHTNING))
	assert_false(EssenceEffects.has_armed_crit(Essence.OZONE), "Ozon liest die Hand, nicht die Runde")

# --- Grubengas: spät, nach den statischen Krits ----------------------------------

func test_firedamp_pays_only_after_a_crit_fired():
	var scored := _p([0])
	var essences := {0: Essence.FIREDAMP}
	assert_eq(EssenceEffects.firedamp_bonus(scored, essences, 0), 0, "ohne Krit kein Schlagwetter")
	assert_eq(EssenceEffects.firedamp_bonus(scored, essences, 1), EssenceEffects.FIREDAMP_BASE)

# --- Geld --------------------------------------------------------------------------

func test_neon_and_sodium_vapor_pay_on_the_take():
	assert_eq(EssenceEffects.money_for(Essence.NEON, 5, 3), EssenceEffects.NEON_MONEY)
	assert_eq(EssenceEffects.money_for(Essence.SODIUM_VAPOR, 5, 3), 2, "$1 je anderem Würfel")
	assert_eq(EssenceEffects.money_for(Essence.SODIUM_VAPOR, 5, 1), 0, "allein zahlt die Laterne nichts")

func test_essence_money_lands_in_the_take_report():
	var def := DieDefinition.new()
	def.essence_id = Essence.NEON
	var defs: Array[DieDefinition] = [def]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([""]), _p([0]),
		NO_CHARMS, -1, {0: Essence.NEON}, _p([0]))
	assert_eq(report.money, EssenceEffects.NEON_MONEY)

# --- Schutz und Sperren ------------------------------------------------------------

func test_nitrogen_keeps_the_glass_from_shrinking():
	assert_true(EssenceEffects.protects_face_value(Essence.NITROGEN))
	var kept := MaterialEffects.mutate_value_once(5, DieMaterial.GLASS, NO_CHARMS, 1, _ids([Essence.NITROGEN]))
	assert_eq(kept, 5, "Schutzatmosphäre: die Seite verliert nichts")
	var plain := MaterialEffects.mutate_value_once(5, DieMaterial.GLASS, NO_CHARMS, 1, _ids([]))
	assert_eq(plain, 4, "ohne Stickstoff schrumpft Glas normal")

func test_helium_grows_the_up_face():
	assert_eq(EssenceEffects.face_growth(Essence.HELIUM), 1)
	assert_eq(MaterialEffects.mutate_value_once(3, "", NO_CHARMS, 1, _ids([Essence.HELIUM])), 4)

func test_krypton_slips_past_a_dice_filter_but_not_past_a_throttle():
	# Nur ungerade: die 4 fiele raus - Krypton bleibt trotzdem legal.
	var ctx := _ctx({1: Essence.KRYPTON}, {DiceScoring.CTX_PARITY: DiceScoring.PARITY_ODD})
	assert_eq(DiceScoring.legal_indices(_d([1, 4, 2]), ctx), _p([0, 1]))
	# Die Kategorie-Drossel ist keine Würfel-Sperre: sie greift weiter.
	var throttled := _ctx({0: Essence.KRYPTON}, {DiceScoring.CTX_THROTTLED: _ids([DiceScoring.TWO_KIND])})
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), NO_CHARMS, false, NO_MATS, {}, throttled), 0)

# --- Zählreihenfolge: Photonengas zählt zuerst -----------------------------------

func test_photon_gas_counts_first():
	# Ohne Essenz zählt der höchste Würfel zuerst; Photonengas zieht seinen vor.
	var dice := _d([2, 6, 4])
	var scored := _p([0, 1, 2])
	assert_eq(DiceScoring.trigger_order(scored, dice), _p([1, 2, 0]), "sonst Wert absteigend")
	assert_eq(DiceScoring.trigger_order(scored, dice, {0: Essence.PHOTON_GAS}), _p([0, 1, 2]),
		"das Photonengas steht vorn, der Rest bleibt sortiert")

func test_photon_gas_dice_stay_sorted_among_themselves():
	var dice := _d([2, 6, 4])
	var scored := _p([0, 1, 2])
	var both := {0: Essence.PHOTON_GAS, 2: Essence.PHOTON_GAS}
	assert_eq(DiceScoring.trigger_order(scored, dice, both), _p([2, 0, 1]),
		"innerhalb des Blocks gilt wieder Wert absteigend")

# --- Wasserstoff: die rohe 1 fumbelt ----------------------------------------------

func test_hydrogen_forces_a_farkle_on_a_raw_one():
	var ctx := _ctx({1: Essence.HYDROGEN})
	assert_true(DiceScoring.forces_farkle(_d([5, 1, 3]), ctx), "Knallgas zündet")
	assert_false(DiceScoring.forces_farkle(_d([5, 2, 3]), ctx), "ohne 1 passiert nichts")
	assert_false(DiceScoring.forces_farkle(_d([1, 2, 3]), ctx), "die 1 eines fremden Würfels zählt nicht")

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

func test_xenon_flashes_once_per_round():
	var run := GameRun.new_run()
	var die := run.owned_pool[0]
	die.essence_id = Essence.XENON
	run.roll_essence_round_state()
	assert_true(run.essence_crit_armed(die, 0), "zu Rundenbeginn ist der Blitz frei")
	var defs: Array[DieDefinition] = [die]
	run.note_essence_take(defs, _p([0]))
	assert_false(run.essence_crit_armed(die, 0), "verschossen")
	run.roll_essence_round_state()
	assert_true(run.essence_crit_armed(die, 0), "die neue Runde lädt ihn nach")

func test_ball_lightning_strikes_one_of_its_own_faces():
	var run := GameRun.new_run()
	var die := run.owned_pool[0]
	die.essence_id = Essence.BALL_LIGHTNING
	run.roll_essence_round_state()
	var armed := 0
	for face in 6:
		if run.essence_crit_armed(die, face):
			armed += 1
	assert_eq(armed, 1, "genau eine Seite trägt den Einschlag")

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
	run.consume_smother(die)
	assert_eq(run.smother_slot(defs, _p([0])), -1, "verbraucht")
	run.roll_essence_round_state()
	assert_eq(run.smother_slot(defs, _p([0])), 0, "die neue Runde füllt nach")

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
	run.consume_smother(first)
	assert_eq(run.smother_slot(defs, _p([0, 1])), 1, "der zweite Würfel hat seine eigene Ladung")

# --- Halogen: die Werkstattlampe brennt weiter ---------------------------------------

func test_halogen_is_the_only_bench_lock_exception():
	assert_true(EssenceEffects.ignores_bench_lock(Essence.HALOGEN))
	assert_false(EssenceEffects.ignores_bench_lock(Essence.NEON))
	assert_false(EssenceEffects.ignores_bench_lock(""))

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

func test_a_krypton_wild_would_still_be_filtered_by_its_own_parity():
	# Gegenprobe zur Regel: Krypton nimmt einen Würfel aus der Sperre - der
	# Joker selbst tut das nicht.
	var dice := _d([5, 5, 5, 5, 2])
	var ctx := _ctx({4: Essence.KRYPTON}, {DiceScoring.CTX_PARITY: DiceScoring.PARITY_ODD})
	assert_eq(DiceScoring.legal_indices(dice, ctx), _p([0, 1, 2, 3, 4]), "Krypton bleibt legal")
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

func test_conditional_crits_are_never_borrowed():
	# Xenons Blitz und der Einschlag des Kugelblitzes hängen am Rundenzustand
	# ihres eigenen Würfels - sie wandern nicht mit.
	var sets := EssenceEffects.effective_sets(
		{0: Essence.QUINTESSENCE, 1: Essence.XENON, 2: Essence.BALL_LIGHTNING})
	var borrowed := EssenceEffects.set_at(sets, 0)
	assert_false(borrowed.has(Essence.XENON))
	assert_false(borrowed.has(Essence.BALL_LIGHTNING))
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

func test_borrowed_downsides_come_along():
	# Knallgas kopiert sich MIT seiner Kehrseite: die rohe 1 der Quintessenz
	# fumbelt jetzt genauso.
	var sets := EssenceEffects.effective_sets({0: Essence.QUINTESSENCE, 1: Essence.HYDROGEN})
	assert_true(EssenceEffects.forces_farkle(_d([1, 5, 3]), sets), "die eigene 1 zündet")
	assert_true(EssenceEffects.forces_farkle(_d([5, 1, 3]), sets), "die des Wasserstoffs auch")
	assert_false(EssenceEffects.forces_farkle(_d([5, 5, 3]), sets))

func test_borrowed_eye_transforms_chain():
	var sets := EssenceEffects.effective_sets({0: Essence.QUINTESSENCE, 1: Essence.HYDROGEN})
	assert_eq(EssenceEffects.eye_value_of(EssenceEffects.set_at(sets, 0), 5), 10, "Knallgas verdoppelt")

func test_borrowed_protection_and_growth():
	var sets := EssenceEffects.effective_sets(
		{0: Essence.QUINTESSENCE, 1: Essence.NITROGEN, 2: Essence.HELIUM})
	var borrowed := EssenceEffects.set_at(sets, 0)
	assert_true(EssenceEffects.protects_face_value_of(borrowed), "Schutzatmosphäre geborgt")
	assert_eq(EssenceEffects.face_growth_of(borrowed), 1, "Helium hebt auch sie")

func test_borrowed_krypton_slips_past_a_filter():
	var dice := _d([2, 4])
	var ctx := {
		DiceScoring.CTX_ESSENCE_SET: EssenceEffects.effective_sets(
			{0: Essence.QUINTESSENCE, 1: Essence.KRYPTON}),
		DiceScoring.CTX_PARITY: DiceScoring.PARITY_ODD,
	}
	assert_eq(DiceScoring.legal_indices(dice, ctx), _p([0, 1]),
		"geborgte Tarnung nimmt auch die Quintessenz aus der Sperre")

func test_borrowed_money_adds_up():
	var sets := EssenceEffects.effective_sets({0: Essence.QUINTESSENCE, 1: Essence.NEON})
	assert_eq(EssenceEffects.money_of(EssenceEffects.set_at(sets, 0), 5, 2),
		EssenceEffects.NEON_MONEY, "die geborgte Reklame zahlt")

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
