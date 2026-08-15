extends GutTest
## Die Essenz-Charms: je einer verstärkt genau eine Seele ab "selten". Geprüft
## wird die Wirkung (Tier 1, reine Logik) und die ANGEBOTS-KOPPLUNG - ohne die
## Seele im Pool darf kein solcher Charm im Laden liegen.

func _ids(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _p(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _m(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

const NO_CHARMS: Array[String] = []

func _die_with(essence_id: String) -> DieDefinition:
	var die := DieDefinition.standard()
	die.essence_id = essence_id
	return die

# --- Angebots-Kopplung -----------------------------------------------------------

func test_every_essence_charm_names_a_real_essence():
	for charm_id in Charm.ESSENCE_REQUIREMENT:
		assert_true(Essence.is_valid_id(Charm.essence_requirement(charm_id)),
			"unbekannte Essenz bei %s" % charm_id)

func test_every_essence_from_rare_upwards_has_exactly_one_charm():
	# Die Pflicht gilt ab "selten"; HÄUFIGE Seelen DÜRFEN einen Charm haben
	# (Tarnkappe/Krypton), müssen aber nicht - die Tabelle ist zugleich die
	# Angebots-Regel, und die trägt jede Kopplung.
	var claimed: Array[String] = []
	for charm_id in Charm.ESSENCE_REQUIREMENT:
		var essence_id := Charm.essence_requirement(charm_id)
		assert_false(claimed.has(essence_id), "zwei Charms auf %s" % essence_id)
		claimed.append(essence_id)
	for essence in Essence.all():
		if essence.rarity == Essence.Rarity.COMMON:
			continue
		assert_true(claimed.has(essence.id),
			"%s (%s) hat keinen Charm" % [essence.id, Essence.rarity_name(essence.rarity)])

func test_offerable_hides_charms_whose_soul_is_missing():
	var none: Array[String] = []
	var without := Charm.offerable(Charm.all(), none)
	for charm in without:
		assert_eq(Charm.essence_requirement(charm.id), "", "%s liegt ohne Seele aus" % charm.id)
	assert_eq(without.size(), Charm.all().size() - Charm.ESSENCE_REQUIREMENT.size())

func test_offerable_lets_the_owned_soul_through():
	var owned := _ids([Essence.PLASMA])
	var pool := Charm.offerable(Charm.all(), owned)
	var found := false
	for charm in pool:
		if charm.id == Charm.IGNITION_COIL:
			found = true
		assert_ne(charm.id, Charm.BELL_JAR, "das Vakuum fehlt im Pool")
	assert_true(found, "die Zündspule liegt zum Plasma-Würfel")

func test_the_shop_pool_follows_the_pool_of_dice():
	var run := GameRun.new_run()
	assert_eq(Charm.offerable(Charm.all(), run.owned_essence_ids()).size(),
		Charm.all().size() - Charm.ESSENCE_REQUIREMENT.size(), "seelenloser Start")
	run.owned_pool[0].essence_id = Essence.OZONE
	var pool := Charm.offerable(Charm.all(), run.owned_essence_ids())
	var ids: Array[String] = []
	for charm in pool:
		ids.append(charm.id)
	assert_true(ids.has(Charm.STORM_FRONT), "die Gewitterfront kommt mit dem Ozon-Würfel")

# --- Auslösungen -----------------------------------------------------------------

func test_amalgam_fires_the_mercury_die_itself_twice_more():
	var sets := {0: Essence.MERCURY_VAPOR}
	var order := _p([0, 1])
	assert_eq(EssenceEffects.extra_activations(0, order, sets, NO_CHARMS), 0, "ohne Charm nichts")
	assert_eq(EssenceEffects.extra_activations(0, order, sets, _ids([Charm.AMALGAM])),
		EssenceEffects.AMALGAM_EXTRA, "der Quecksilber-Würfel selbst")
	assert_eq(EssenceEffects.extra_activations(1, order, sets, _ids([Charm.AMALGAM])), 0,
		"der Nachbar bekommt nichts")

func test_solar_sail_counts_distinct_souls_twice():
	var sets := {0: Essence.ARGON, 1: Essence.ARGON, 2: Essence.XENON, 3: Essence.SOLAR_WIND}
	var order := _p([0, 1, 2, 3])
	assert_eq(EssenceEffects.extra_activations(3, order, sets, NO_CHARMS), 3,
		"ohne Segel: je Essenz-WÜRFEL eine")
	assert_eq(EssenceEffects.extra_activations(3, order, sets, _ids([Charm.SOLAR_SAIL])),
		2 * EssenceEffects.SOLAR_SAIL_PER_ESSENCE, "mit Segel: je VERSCHIEDENER Seele zwei")

func test_storm_glass_keeps_st_elmos_fire_in_the_storm():
	assert_eq(EssenceEffects.activation_factor(Essence.ST_ELMOS_FIRE, NO_CHARMS, false), 2)
	assert_eq(EssenceEffects.activation_factor(Essence.ST_ELMOS_FIRE, _ids([Charm.STORM_GLASS]), false),
		EssenceEffects.STORM_FACTOR)
	assert_eq(EssenceEffects.activation_factor(Essence.ARGON, _ids([Charm.STORM_GLASS]), false), 2,
		"das Glas gehört dem Elmsfeuer allein")

func test_swamp_lantern_lifts_the_tip_limit():
	var run := GameRun.new_run()
	var die := _die_with(Essence.WILL_O_WISP)
	assert_true(run.can_tip_die(die))
	run.consume_tip(die)
	assert_false(run.can_tip_die(die), "ohne Charm einmal je Runde")
	run.owned_charms.append(Charm.swamp_lantern())
	assert_true(run.can_tip_die(die), "mit Sumpflaterne beliebig oft")

# --- Knallgas: die Kettenreaktion im Stapel ----------------------------------------

func test_detonating_gas_pays_every_die_behind_it():
	var souls := _ids([Essence.DETONATING_GAS, "", ""])
	assert_eq(EssenceEffects.leftover_die_payouts(souls, 1, NO_CHARMS), _p([1, 2, 2]),
		"der Knallgas-Würfel selbst zahlt nur den Grundsatz")

func test_two_detonating_gas_dice_stack_for_the_rest():
	var souls := _ids([Essence.DETONATING_GAS, Essence.DETONATING_GAS, "", ""])
	assert_eq(EssenceEffects.leftover_die_payouts(souls, 1, NO_CHARMS), _p([1, 2, 3, 3]),
		"zwei Knallgas vorn: jeder dahinter zahlt $1 + $2")

func test_a_late_detonating_gas_helps_nobody():
	var souls := _ids(["", "", Essence.DETONATING_GAS])
	assert_eq(EssenceEffects.leftover_die_payouts(souls, 1, NO_CHARMS), _p([1, 1, 1]))

func test_without_detonating_gas_every_die_pays_the_same():
	var souls := _ids(["", "", ""])
	assert_eq(EssenceEffects.leftover_die_payouts(souls, 2, NO_CHARMS), _p([2, 2, 2]))

func test_the_fuse_raises_the_chain_to_three():
	assert_eq(EssenceEffects.detonating_gas_bonus(NO_CHARMS), 1)
	assert_eq(EssenceEffects.detonating_gas_bonus(_ids([Charm.FUSE])), 3)
	assert_eq(EssenceEffects.detonating_gas_bonus(_ids([Charm.FUSE, Charm.FUSE])), 5, "je Vorkommen +2")
	var souls := _ids([Essence.DETONATING_GAS, "", ""])
	assert_eq(EssenceEffects.leftover_die_payouts(souls, 1, _ids([Charm.FUSE])), _p([1, 4, 4]))

func test_detonating_gas_is_a_real_essence():
	assert_true(Essence.is_valid_id(Essence.DETONATING_GAS))
	assert_eq(Essence.by_id(Essence.DETONATING_GAS).rarity, Essence.Rarity.RARE)
	assert_false(Essence.by_id(Essence.DETONATING_GAS).secret, "handelbar, kein Schwarzmarkt")
	assert_false(Essence.by_id(Essence.DETONATING_GAS).unique)

# --- Krypton: zählt immer mit ------------------------------------------------------

func test_krypton_joins_the_scored_set_outside_the_combination():
	# Paar Fünfer plus ein Krypton-Würfel: er gehört nicht zur Kombination, tritt
	# aber trotzdem an - participating bleibt das reine Paar.
	var dice := _p([5, 5, 3])
	var ctx := {DiceScoring.CTX_ESSENCES: {2: Essence.KRYPTON}}
	var shape := DiceScoring.hand_shape(DiceScoring.TWO_KIND, dice, NO_CHARMS, ctx)
	assert_eq(shape["participating"], _p([0, 1]), "die Erkennung bleibt unberührt")
	assert_eq(shape["scored"], _p([0, 1, 2]), "der Krypton-Würfel zählt mit")

func test_the_krypton_die_brings_its_eyes_along():
	var dice := _p([5, 5, 3])
	var mats := _m(["", "", ""])
	var plain := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, {}, {})
	var krypton := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, {},
		{DiceScoring.CTX_ESSENCES: {2: Essence.KRYPTON}})
	assert_eq(plain, 20 * 2)
	assert_eq(krypton, 23 * 2, "die 3 des Krypton-Würfels zählt mit")

func test_krypton_does_not_change_the_combination_charms():
	# Kombi-Charms rechnen auf participating - der mitzählende Krypton-Würfel
	# darf die KOMBINATION nicht verschieben.
	var dice := _p([5, 5, 3])
	var ctx := {DiceScoring.CTX_ESSENCES: {2: Essence.KRYPTON}}
	var shape := DiceScoring.hand_shape(DiceScoring.TWO_KIND, dice, _ids([Charm.LADYBUG]), ctx)
	assert_eq(shape["participating"], _p([0, 1]))

func test_the_scored_set_stays_its_own_list():
	# Ohne Vollzähler liefert scored_indices dieselbe Liste wie participating -
	# das Erweitern darf sie nicht mitverändern.
	var dice := _p([5, 5, 3])
	var ctx := {DiceScoring.CTX_ESSENCES: {2: Essence.KRYPTON}}
	var shape := DiceScoring.hand_shape(DiceScoring.TWO_KIND, dice, NO_CHARMS, ctx)
	var participating: Array[int] = shape["participating"]
	var scored: Array[int] = shape["scored"]
	assert_eq(participating.size(), 2)
	assert_eq(scored.size(), 3)

func test_the_quintessence_borrows_the_always_scored_rule():
	var sets := EssenceEffects.effective_sets({0: Essence.QUINTESSENCE, 1: Essence.KRYPTON})
	assert_true(EssenceEffects.always_scored_of(sets, 0), "die geborgte Seele zählt auch immer mit")
	assert_true(EssenceEffects.always_scored_of(sets, 1))
	assert_false(EssenceEffects.always_scored_of({}, 0))

# --- Krits -----------------------------------------------------------------------

func test_lightning_rod_grows_with_the_ball_lightnings_in_the_hand():
	var sets := {0: Essence.BALL_LIGHTNING, 1: Essence.BALL_LIGHTNING}
	var scored := _p([0, 1])
	assert_eq(EssenceEffects.ball_crit_bonus(scored, sets, NO_CHARMS), 0)
	var bonus := EssenceEffects.ball_crit_bonus(scored, sets, _ids([Charm.LIGHTNING_ROD]))
	assert_eq(bonus, 2)
	assert_almost_eq(EssenceEffects.crit_of(_ids([Essence.BALL_LIGHTNING]), 5, 0, bonus), 4.0, 0.0001,
		"zwei Kugelblitze: ×(2+2)")
	assert_almost_eq(EssenceEffects.crit_of(_ids([Essence.XENON]), 5, 0, bonus),
		EssenceEffects.XENON_CRIT, 0.0001, "andere Seelen bleiben unberührt")

func test_polarizer_crits_with_the_number_the_wild_becomes():
	var wild := _ids([Essence.AURORA])
	assert_almost_eq(EssenceEffects.crit_of(wild, 3), 1.0, 0.0001, "ohne Filter kein Krit")
	assert_almost_eq(EssenceEffects.crit_of(wild, 3, 0, 0, 6), 6.0, 0.0001)

func test_the_wild_value_is_the_highest_number_that_carries():
	var ctx := {DiceScoring.CTX_ESSENCES: {0: Essence.AURORA}}
	# Ein Joker plus zwei Fünfen: als 5 trägt er den Dreierpasch.
	assert_eq(DiceScoring.wild_value(DiceScoring.THREE_KIND, _p([2, 5, 5]), ctx), 5)
	assert_eq(DiceScoring.wild_value(DiceScoring.THREE_KIND, _p([2, 5, 5]), {}), 0,
		"ohne Polarlicht keine angenommene Zahl")

func test_round_offsets_only_fire_with_their_charm():
	assert_eq(EssenceEffects.round_trigger_offset(NO_CHARMS, 7), 0)
	assert_eq(EssenceEffects.round_trigger_offset(_ids([Charm.DARKROOM]), 7), 7)
	assert_eq(EssenceEffects.round_crit_offset(NO_CHARMS, 3), 0)
	assert_eq(EssenceEffects.round_crit_offset(_ids([Charm.STORM_FRONT]), 3), 3)

func test_the_darkroom_lets_photon_gas_collect_across_hands():
	var dice := _p([4, 4])
	var essences := {0: Essence.PHOTON_GAS}
	var plain := {DiceScoring.CTX_ESSENCES: essences, DiceScoring.CTX_ROUND_TRIGGERS: 4}
	var lit := {DiceScoring.CTX_ESSENCES: essences, DiceScoring.CTX_ROUND_TRIGGERS: 4}
	var without := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, _m(["", ""]), {}, plain)
	var with_charm := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([Charm.DARKROOM]),
		false, _m(["", ""]), {}, lit)
	assert_gt(with_charm, without, "die Runde bringt ihr Licht mit")

# --- Augen, Wachstum, Geld --------------------------------------------------------

func test_magnetic_trap_turns_antimatter_positive():
	var ids := _ids([Essence.ANTIMATTER])
	assert_eq(EssenceEffects.eye_value_of(ids, 5), -5)
	assert_eq(EssenceEffects.eye_value_of(ids, 5, _ids([Charm.MAGNETIC_TRAP])), 5)
	assert_almost_eq(EssenceEffects.crit_of(ids, 5), 5.0, 0.0001, "der Krit bleibt")

func test_lead_apron_raises_the_radiation_and_stops_the_decay():
	var soul := _ids([Essence.RADON])
	assert_eq(EssenceEffects.radon_eye_gift(soul), EssenceEffects.RADON_EYE_BONUS)
	assert_eq(EssenceEffects.radon_eye_gift(soul, _ids([Charm.LEAD_APRON])),
		EssenceEffects.RADON_EYE_BONUS_SHIELDED)
	var die := _die_with(Essence.RADON)
	assert_false(EssenceEffects.decay_die(die, _ids([Charm.LEAD_APRON])), "kein Zerfall unter Blei")
	assert_eq(die.faces, DieDefinition.standard().faces)
	assert_true(EssenceEffects.decay_die(die), "ohne Schürze frisst die Strahlung weiter")

func test_pressure_vessel_swells_by_percent():
	var ids := _ids([Essence.RADIATION_PRESSURE])
	assert_eq(EssenceEffects.face_growth_of(ids, NO_CHARMS, 40), EssenceEffects.PRESSURE_GROWTH)
	var charmed := _ids([Charm.PRESSURE_VESSEL])
	assert_eq(EssenceEffects.face_growth_of(ids, charmed, 40), 4, "10 % von 40")
	assert_eq(EssenceEffects.face_growth_of(ids, charmed, 1), 1, "aufgerundet, nie null")

func test_pressure_vessel_writes_the_same_number_into_the_def():
	var die := _die_with(Essence.RADIATION_PRESSURE)
	die.faces = _p([10, 10, 10, 10, 10, 10])
	var defs: Array[DieDefinition] = [die]
	var charms := _ids([Charm.PRESSURE_VESSEL])
	var simulated := MaterialEffects.value_after_activations(10, 1, "", charms, 1,
		_ids([Essence.RADIATION_PRESSURE]))
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([""]), _p([0]), charms, -1,
		{0: Essence.RADIATION_PRESSURE}, _p([0]))
	assert_eq(die.faces[0], simulated, "Sim und Def landen auf derselben Zahl")
	assert_eq(die.faces[0], 11)
	assert_eq(die.faces[3], 11, "auch die Seiten, die nicht oben lagen")

func test_aqua_fortis_reaches_the_gold_of_the_others():
	var die := _die_with(Essence.CYANIDE)
	die.set_face_material(1, DieMaterial.GOLD)
	var mate := DieDefinition.standard()
	mate.set_face_material(0, DieMaterial.GOLD)
	mate.set_face_material(2, DieMaterial.GOLD)
	var defs: Array[DieDefinition] = [die, mate]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m(["", DieMaterial.GOLD]), _p([0, 1]),
		_ids([Charm.AQUA_FORTIS]), -1, {0: Essence.CYANIDE}, _p([0, 1]))
	# Eigene Gold-Seite + zwei fremde, dazu die Gold-Seite, auf der der Mitwürfel liegt.
	assert_eq(report.total_money(), EssenceEffects.CYANIDE_PER_GOLD + 2 * EssenceEffects.AQUA_FORTIS_PER_GOLD
		+ MaterialEffects.GOLD_PAYOUT)

# --- Seiten & Runen ---------------------------------------------------------------

func test_solar_eclipse_widens_the_corona_ring():
	var die := _die_with(Essence.CORONA)
	var ids := _ids([Essence.CORONA])
	var no_runes: Array[String] = []
	assert_eq(EssenceEffects.link_faces(die, 2, ids).size(), EssenceEffects.CORONA_FACES)
	assert_eq(EssenceEffects.link_faces(die, 2, ids, no_runes, _ids([Charm.SOLAR_ECLIPSE])).size(),
		EssenceEffects.CORONA_FACES_ECLIPSED)
	for face in EssenceEffects.link_faces(die, 2, ids, no_runes, _ids([Charm.SOLAR_ECLIPSE])):
		assert_ne(face, DieDefinition.opposite_face(2), "die Gegenseite bleibt dem Röntgenlicht")

func test_contrast_agent_halves_the_top_and_triples_the_bottom():
	var die := _die_with(Essence.XRAY)
	die.faces = _p([8, 2, 3, 4, 5, 6])
	var defs: Array[DieDefinition] = [die]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([""]), _p([0]),
		_ids([Charm.CONTRAST_AGENT]), -1, {0: Essence.XRAY}, _p([0]))
	assert_eq(die.faces[0], 4, "obere Seite halbiert")
	assert_eq(die.faces[DieDefinition.opposite_face(0)], 18, "Gegenseite verdreifacht")

func test_the_bell_jar_opens_a_third_rune_only_on_the_vacuum():
	var vacuum := _die_with(Essence.VACUUM)
	assert_eq(vacuum.rune_slots(), 2, "ohne Charm zwei")
	assert_eq(vacuum.rune_slots(1), 3)
	assert_true(vacuum.set_rune(0, Rune.AFTERGLOW, 2, 1))
	assert_eq(vacuum.runes_on(0).size(), 1, "die ersten beiden Plätze sind noch leer")
	assert_true(vacuum.runes_on(0).has(Rune.AFTERGLOW))
	var plain := DieDefinition.standard()
	assert_eq(plain.rune_slots(1), 1, "ohne Vakuum bleibt es bei einer Rune")
	assert_false(plain.set_rune(0, Rune.AFTERGLOW, 2, 1))

func test_the_censer_spreads_without_paying():
	var miasma := _die_with(Essence.MIASMA)
	miasma.faces = _p([10, 2, 3, 4, 5, 6])
	var mate := DieDefinition.standard()
	var defs: Array[DieDefinition] = [miasma, mate]
	MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m(["", ""]), _p([0, 1]),
		_ids([Charm.CENSER]), -1, {0: Essence.MIASMA}, _p([0, 1]))
	assert_eq(miasma.faces[0], 10, "die Quelle verliert nichts mehr")
	assert_eq(mate.faces[0], 1 + 5, "angesteckt wird trotzdem")

func test_the_ignition_coil_fires_every_plasma_link_twice():
	var die := _die_with(Essence.PLASMA)
	die.pointers[0] = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var groups := DiceScoring.roll_pointer_fires(die, 0, 1, 1, _ids([Charm.IGNITION_COIL]),
		_ids([Essence.PLASMA]), rng)
	var fires: Array = groups[0]
	assert_gt(fires.size(), 0, "die doppelte Chance zündet")
	assert_eq(fires.size() % 2, 0, "jedes Glied steht zweimal in der Liste")
	assert_eq(int(fires[0]["face"]), 2)
	assert_eq(int(fires[1]["face"]), 2)

func test_plasma_gives_the_pointer_a_second_shot():
	# Aggregiert, nicht mal zwei: 1 − (1−p)². Die 100 % bleiben unerreichbar.
	assert_almost_eq(EssenceEffects.pointer_chance(Essence.PLASMA, 0.5), 0.75, 0.0001)
	assert_almost_eq(EssenceEffects.pointer_chance(Essence.PLASMA, 0.25), 0.4375, 0.0001)
	assert_lt(EssenceEffects.pointer_chance(Essence.PLASMA, 0.99), 1.0)
	assert_almost_eq(EssenceEffects.pointer_chance(Essence.NEON, 0.25), 0.25, 0.0001)

# --- Speicher & Vorrat ------------------------------------------------------------

func test_the_phosphor_store_accumulates_and_survives_the_round():
	var run := GameRun.new_run()
	var die := _die_with(Essence.PHOSPHORESCENCE)
	var defs: Array[DieDefinition] = [die]
	run.note_phosphor_stores(defs, {"die_steps": [{"slot": 0, "base_contribution": 30}]})
	assert_eq(run.phosphor_store(die), 30)
	run.note_phosphor_stores(defs, {"die_steps": [{"slot": 0, "base_contribution": 12}]})
	assert_eq(run.phosphor_store(die), 42, "der Speicher sammelt, er überschreibt nicht")
	run.roll_essence_round_state()
	assert_eq(run.phosphor_store(die), 42, "und überlebt die Runde")

func test_the_fluorescent_tube_stores_the_mult_too():
	var run := GameRun.new_run()
	var die := _die_with(Essence.PHOSPHORESCENCE)
	var defs: Array[DieDefinition] = [die]
	var step := {"die_steps": [{"slot": 0, "base_contribution": 10, "mult_contribution": 4.0}]}
	run.note_phosphor_stores(defs, step)
	assert_almost_eq(run.phosphor_mult(die), 0.0, 0.0001, "ohne Röhre kein Mult-Speicher")
	run.owned_charms.append(Charm.fluorescent_tube())
	run.note_phosphor_stores(defs, step)
	assert_almost_eq(run.phosphor_mult(die), 4.0, 0.0001)

func test_the_mult_store_never_counts_a_crit():
	# Der Krit vervielfacht den laufenden Mult der ganzen Hand - gespeichert wird
	# nur, was DIESER Würfel selbst dazugelegt hat (hier: Halogens +5).
	var essences := {0: [Essence.PHOSPHORESCENCE, Essence.HALOGEN, Essence.XENON] as Array[String]}
	var ctx := {DiceScoring.CTX_ESSENCE_SET: essences}
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, _p([4, 4]), NO_CHARMS, false,
		_m(["", ""]), {}, ctx)
	var step: Dictionary = breakdown["die_steps"][0]
	assert_almost_eq(float(step["crit_x"]), EssenceEffects.XENON_CRIT, 0.0001, "der Krit zündet wirklich")
	assert_almost_eq(float(step["mult_contribution"]), float(EssenceEffects.HALOGEN_MULT), 0.0001,
		"nur der eigene Mult-Anteil, nie der Krit")

func test_the_round_counters_reset_with_the_round():
	var run := GameRun.new_run()
	run.note_hand_counters({"triggers": 6, "crits": 2})
	run.note_hand_counters({"triggers": 3, "crits": 1})
	assert_eq(run.round_trigger_count, 9)
	assert_eq(run.round_crit_count, 3)
	run.roll_essence_round_state()
	assert_eq(run.round_trigger_count, 0)
	assert_eq(run.round_crit_count, 0)

func test_the_glaze_brush_grants_a_doping_pack_on_a_capped_face():
	var run := GameRun.new_run()
	var die := _die_with(Essence.VARNISH)
	die.set_face_material(0, DieMaterial.GOLD)
	var defs: Array[DieDefinition] = [die]
	assert_eq(run.apply_glaze_brush(defs, _p([0]), _p([0])), 0, "ohne Charm kein Paket")
	run.owned_charms.append(Charm.glaze_brush())
	assert_eq(run.apply_glaze_brush(defs, _p([0]), _p([0])), 0, "Stufe I lässt sich noch heben")
	die.levels[0] = DieMaterial.MAX_LEVEL
	assert_eq(run.apply_glaze_brush(defs, _p([0]), _p([0])), 1)
	assert_eq(_pack_stock(run, Engraving.DOPING), 1, "ein versiegeltes Veredelungs-Paket")
	assert_eq(_pack_stock(run, DieMaterial.GOLD), 0, "keine Material-Kopie mehr")
	assert_eq(PackShelfView.shelf_of(run.owned_packs[0]), PackShelfView.CATEGORY_SPECIAL,
		"es liegt im Sonderbestand")

# --- Ethylen: die Ernte und ihre Druckerpresse -----------------------------------

## Ethylen-Würfel mit Gold auf zwei Seiten und Rubin auf einer - zwei
## VERSCHIEDENE Materialien, also zwei Kopien je Ernte.
func _ethylene_die() -> DieDefinition:
	var die := _die_with(Essence.ETHYLENE)
	die.set_face_material(0, DieMaterial.GOLD)
	die.set_face_material(1, DieMaterial.GOLD)
	die.set_face_material(2, DieMaterial.RUBY)
	return die

func test_ethylene_harvests_each_material_once():
	var run := GameRun.new_run()
	var defs: Array[DieDefinition] = [_ethylene_die()]
	assert_eq(run.apply_material_harvest(defs, _p([0]), {0: Essence.ETHYLENE}), 2,
		"je verschiedenem Material eine Gravur, nicht je Seite")
	assert_eq(_pack_stock(run, DieMaterial.GOLD), 1)
	assert_eq(_pack_stock(run, DieMaterial.RUBY), 1)

func test_the_harvest_fires_once_per_round_per_die():
	var run := GameRun.new_run()
	var defs: Array[DieDefinition] = [_ethylene_die()]
	assert_eq(run.apply_material_harvest(defs, _p([0]), {0: Essence.ETHYLENE}), 2)
	assert_eq(run.apply_material_harvest(defs, _p([0]), {0: Essence.ETHYLENE}), 0,
		"die zweite Hand derselben Runde erntet nicht erneut")
	run.roll_essence_round_state()
	assert_eq(run.apply_material_harvest(defs, _p([0]), {0: Essence.ETHYLENE}), 2,
		"die neue Runde reift nach")

func test_the_printing_press_prints_every_copy_twice():
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.printing_press())
	var defs: Array[DieDefinition] = [_ethylene_die()]
	assert_eq(run.apply_material_harvest(defs, _p([0]), {0: Essence.ETHYLENE}), 4)
	assert_eq(_pack_stock(run, DieMaterial.GOLD), 2)
	assert_eq(_pack_stock(run, DieMaterial.RUBY), 2)

func test_the_quintessence_borrows_the_harvest():
	var run := GameRun.new_run()
	var die := _ethylene_die()
	die.essence_id = Essence.QUINTESSENCE
	var defs: Array[DieDefinition] = [die]
	var sets := EssenceEffects.effective_sets({0: Essence.QUINTESSENCE}, _ids([Essence.ETHYLENE]))
	assert_eq(run.apply_material_harvest(defs, _p([0]), sets), 2,
		"die geborgte Seele erntet die EIGENEN Materialien")

func test_a_soulless_die_harvests_nothing():
	var run := GameRun.new_run()
	var bare := _die_with(Essence.ETHYLENE)
	var defs: Array[DieDefinition] = [_die_with(""), bare]
	assert_eq(run.apply_material_harvest(defs, _p([0]), {}), 0, "ohne Ethylen keine Ernte")
	assert_eq(run.apply_material_harvest(defs, _p([1]), {1: Essence.ETHYLENE}), 0,
		"ohne Material auf den Seiten nichts zu ernten")

func test_an_unscored_ethylene_die_stays_unharvested():
	var run := GameRun.new_run()
	var defs: Array[DieDefinition] = [_ethylene_die(), _ethylene_die()]
	assert_eq(run.apply_material_harvest(defs, _p([0]), {0: Essence.ETHYLENE, 1: Essence.ETHYLENE}), 2,
		"nur der gewertete Würfel erntet")

func test_alkahest_lends_the_discarded_souls_to_the_quintessence():
	var lying := {0: Essence.QUINTESSENCE}
	var borrowed := EssenceEffects.set_at(
		EssenceEffects.effective_sets(lying, _ids([Essence.XENON])), 0)
	assert_true(borrowed.has(Essence.XENON), "die Ablage zählt mit")
	assert_false(EssenceEffects.set_at(EssenceEffects.effective_sets(lying), 0).has(Essence.XENON))
	var uncopyable := EssenceEffects.set_at(
		EssenceEffects.effective_sets(lying, _ids([Essence.AURORA, Essence.PHOSPHORESCENCE])), 0)
	assert_eq(uncopyable.size(), 1, "die Unikat-Sperre gilt auch für die Ablage")

## Versiegelte Fixinhalt-Pakete dieser Gravur im Lager - lose wartet nichts mehr.
func _pack_stock(run: GameRun, id: String) -> int:
	var count := 0
	for pack in run.owned_packs:
		if pack.fixed_engraving != null and pack.fixed_engraving.id == id:
			count += 1
	return count
