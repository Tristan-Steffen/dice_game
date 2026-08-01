extends GutTest
## Tier-1-Tests der Rifts: Datensatz, Besitzregel (Stufen in der Glasur, Risse in
## der Struktur), die vier Wirkungen und ihre Einrechnung.

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

func _rift_ctx(slot: int, rift_ids: Array) -> Dictionary:
	return {DiceScoring.CTX_RIFTS: {slot: _ids(rift_ids)}}

# --- Datensatz ---------------------------------------------------------------------

func test_all_four_rifts_are_registered_and_filled():
	assert_eq(Rift.all().size(), 4)
	var seen := {}
	for rift in Rift.all():
		assert_false(seen.has(rift.id), "doppelte id: %s" % rift.id)
		seen[rift.id] = true
		assert_ne(rift.display_name, "", "display_name fehlt bei %s" % rift.id)
		assert_ne(rift.short, "", "short fehlt bei %s" % rift.id)
		assert_ne(rift.description, "", "description fehlt bei %s" % rift.id)
		assert_ne(rift.kind, "", "Klasse fehlt bei %s" % rift.id)
		assert_false(Rift.crack_lines(rift.pattern).is_empty(), "Rissbild fehlt bei %s" % rift.id)

func test_spark_flight_wears_the_charge_cyan():
	# Der Funke ist derselbe Stoff, den das Casino als Energie abfüllt - die
	# Tönung muss der Ladungsfarbe entsprechen (CasinoStyle.CHARGE gespiegelt).
	assert_eq(Rift.by_id(Rift.SPARK_FLIGHT).tint, CasinoStyle.CHARGE)

func test_hint_and_tint_fall_back_without_a_rift():
	assert_eq(Rift.hint(""), "")
	assert_eq(Rift.tint_for(""), Color.BLACK)
	assert_true(Rift.hint(Rift.AFTERGLOW).contains("Nachglühen"))

# --- Besitzregel: Risse überleben das Übermalen ------------------------------------

func test_a_repaint_keeps_the_rift():
	# Stufen wohnen in der Glasur, Rifts in der Struktur der Schale.
	var def := DieDefinition.new()
	def.set_face_material(0, DieMaterial.RUBY)
	def.set_rift(0, Rift.AFTERGLOW)
	def.raise_level(0)
	def.set_face_material(0, DieMaterial.GOLD)
	assert_eq(def.material_level(0), 1, "die Stufe fängt neu an")
	assert_eq(def.rifts_on(0), _ids([Rift.AFTERGLOW]), "der Riss bleibt")

func test_become_and_instantiate_copy_the_rifts_independently():
	var def := DieDefinition.new()
	def.set_rift(2, Rift.BURN_IN)
	var copy := def.instantiate()
	assert_eq(copy.rifts_on(2), _ids([Rift.BURN_IN]))
	copy.set_rift(2, "")
	assert_eq(def.rifts_on(2), _ids([Rift.BURN_IN]), "die Kopie teilt das Array nicht")
	var host := DieDefinition.new()
	host.become(def)
	assert_eq(host.rifts_on(2), _ids([Rift.BURN_IN]))
	host.set_rift(2, "")
	assert_eq(def.rifts_on(2), _ids([Rift.BURN_IN]), "become teilt das Array nicht")

func test_a_fresh_definition_has_no_rifts():
	var def := DieDefinition.new()
	for face in 6:
		assert_eq(def.rifts_on(face), _ids([]), "Seite %d bricht erst durch eine Gravur" % face)

func test_breaking_an_occupied_face_replaces_the_rift():
	var def := DieDefinition.new()
	def.set_rift(0, Rift.AFTERGLOW)
	def.set_rift(0, Rift.STRAY_LIGHT)
	assert_eq(def.rifts_on(0), _ids([Rift.STRAY_LIGHT]), "neu brechen ist erlaubt")

# --- Vakuum: zwei Risse je Seite, nur dort ------------------------------------------

func test_only_vacuum_carries_a_second_rift():
	var plain := DieDefinition.new()
	assert_eq(plain.rift_slots(), 1)
	assert_false(plain.set_rift(0, Rift.AFTERGLOW, 1), "ohne Vakuum kein Zweitriss")
	assert_eq(plain.rifts_on(0), _ids([]))
	var vacuum := DieDefinition.new()
	vacuum.essence_id = Essence.VACUUM
	assert_eq(vacuum.rift_slots(), 2)
	assert_true(vacuum.set_rift(0, Rift.AFTERGLOW, 0))
	assert_true(vacuum.set_rift(0, Rift.SPARK_FLIGHT, 1))
	assert_eq(vacuum.rifts_on(0), _ids([Rift.AFTERGLOW, Rift.SPARK_FLIGHT]))

func test_vacuum_cracks_are_black_whatever_the_rift():
	assert_ne(RiftEffects.crack_color(Rift.SPARK_FLIGHT, ""), Color(0.02, 0.02, 0.04))
	assert_eq(RiftEffects.crack_color(Rift.SPARK_FLIGHT, Essence.VACUUM), Color(0.02, 0.02, 0.04),
		"das Vakuum saugt das Kernlicht nach innen")

func test_vacuum_is_an_essence_without_its_own_effect():
	assert_eq(EssenceEffects.activation_factor(Essence.VACUUM), 1)
	assert_eq(EssenceEffects.eye_value(Essence.VACUUM, 5), 5)
	assert_eq(EssenceEffects.money_for(Essence.VACUUM, 5, 3), 0)

# --- Nachglühen: +1 Auslösung, additiv ----------------------------------------------

func test_afterglow_adds_one_activation():
	assert_eq(RiftEffects.extra_activations(_ids([Rift.AFTERGLOW])), 1)
	assert_eq(RiftEffects.extra_activations(_ids([Rift.STRAY_LIGHT])), 0)
	assert_eq(RiftEffects.extra_activations(_ids([Rift.AFTERGLOW, Rift.AFTERGLOW])), 2,
		"der Vakuum-Doppelriss glüht zweimal nach")

func test_afterglow_stays_additive_next_to_the_essence_factor():
	# Argon (×2) + Nachglühen (+1) = 3, nie 4 - die Essenz bleibt der einzige Faktor.
	var count := MaterialEffects.activation_count(0, NO_CHARMS, 5, -1, _ids([Essence.ARGON]), false,
		RiftEffects.extra_activations(_ids([Rift.AFTERGLOW])))
	assert_eq(count, 3)

func test_afterglow_flows_through_the_score():
	# Paar Fünfer: Slot 0 zählt seine Augen zweimal.
	var plain := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), NO_CHARMS, false, NO_MATS)
	var glowing := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]),
		NO_CHARMS, false, NO_MATS, {}, _rift_ctx(0, [Rift.AFTERGLOW]))
	assert_eq(plain, 40)
	assert_eq(glowing, (10 + 5 + 5 + 5) * 2)

func test_the_farkle_comparison_sees_the_old_rifts():
	# Das Nachglühen ändert Auslösungen - der Vergleich muss die alten Risse
	# kennen, sonst bewertet er die alte Seite mit den neuen.
	var same := _d([5, 5, 1, 2, 3, 6])
	var better := _d([5, 5, 5, 2, 3, 6])
	var new_ctx := _rift_ctx(0, [Rift.AFTERGLOW])
	var old_ctx := _rift_ctx(0, [])
	assert_false(DiceScoring.is_strictly_better(same, same, NO_CHARMS, NO_MATS, NO_MATS, {}, new_ctx, old_ctx),
		"gleicher Rang bleibt Farkle")
	assert_true(DiceScoring.is_strictly_better(better, same, NO_CHARMS, NO_MATS, NO_MATS, {}, new_ctx, old_ctx))

func test_links_never_fire_a_rift():
	# Ein Riss gehört der OBEN liegenden Seite; ein Glied ist per Definition eine
	# andere Seite und lässt ihn kalt.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var ctx := _rift_ctx(0, [Rift.AFTERGLOW])
	ctx[DiceScoring.CTX_POINTER_LINKS] = {0: [{"face": 2, "value": 4, "material": "", "level": 1}]}
	# Basis: Paar (10) + 5 + 5 (Nachglühen zählt Slot 0 zweimal) + 5 + Glied 4.
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, NO_MATS, {}, ctx),
		(10 + 5 + 5 + 5 + 4) * 2, "das Glied feuert einmal, ohne Nachglühen")

# --- Einbrand: der Wert ist eingebrannt ----------------------------------------------

func test_burn_in_protects_the_face_value():
	assert_true(RiftEffects.protects_face_value(_ids([Rift.BURN_IN])))
	assert_false(RiftEffects.protects_face_value(_ids([Rift.AFTERGLOW])))

func test_burn_in_stops_the_glass_from_shrinking():
	var kept := MaterialEffects.mutate_value_once(5, DieMaterial.GLASS, NO_CHARMS, 1, _ids([]), _ids([Rift.BURN_IN]))
	assert_eq(kept, 5, "eingebrannt: die Seite verliert nichts")
	var plain := MaterialEffects.mutate_value_once(5, DieMaterial.GLASS, NO_CHARMS, 1, _ids([]), _ids([]))
	assert_eq(plain, 4, "ohne Einbrand schrumpft Glas normal")

func test_burn_in_survives_a_take():
	var def := DieDefinition.new()
	def.faces[0] = 5
	def.set_face_material(0, DieMaterial.GLASS)
	def.set_rift(0, Rift.BURN_IN)
	var defs: Array[DieDefinition] = [def]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]))
	assert_eq(def.faces[0], 5, "auch beim Nehmen bleibt der Wert stehen")

func test_burn_in_skips_the_radon_decay():
	var run := GameRun.new_run()
	var die := run.owned_pool[0]
	die.essence_id = Essence.RADON
	for face in 6:
		die.set_rift(face, Rift.BURN_IN)
	var before := die.faces.duplicate()
	assert_false(EssenceEffects.decay_die(die), "kein Kandidat, kein Zerfall")
	assert_eq(die.faces, before, "eingebrannte Seiten zerfallen nicht")

# --- Funkenflug: +1 ⚡ je Zug ---------------------------------------------------------

func test_spark_flight_pays_one_charge():
	assert_eq(RiftEffects.charge_for_take(_ids([Rift.SPARK_FLIGHT])), RiftEffects.SPARK_FLIGHT_CHARGE)
	assert_eq(RiftEffects.charge_for_take(_ids([Rift.AFTERGLOW])), 0)

func test_spark_flight_books_once_per_take_not_per_activation():
	# Argon löst den Würfel zweimal aus - der Funke springt trotzdem einmal.
	var def := DieDefinition.new()
	def.essence_id = Essence.ARGON
	def.set_rift(0, Rift.SPARK_FLIGHT)
	var defs: Array[DieDefinition] = [def]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([""]), _p([0]),
		NO_CHARMS, -1, {0: Essence.ARGON}, _p([0]))
	assert_eq(report.charge, 1, "je Zug ein Funke, nicht je Auslösung")

func test_a_take_without_a_spark_carries_no_charge():
	var defs: Array[DieDefinition] = [DieDefinition.new()]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([""]), _p([0]))
	assert_eq(report.charge, 0)

# --- Streulicht: das ungewertete Zugende ---------------------------------------------

func test_stray_light_pays_only_for_unscored_lying_dice():
	var scored := DieDefinition.new()
	scored.set_rift(0, Rift.STRAY_LIGHT)
	var idle := DieDefinition.new()
	idle.set_rift(0, Rift.STRAY_LIGHT)
	var defs: Array[DieDefinition] = [scored, idle]
	# Slot 0 wertet, Slot 1 liegt ungewertet daneben.
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m(["", ""]), _p([0]),
		NO_CHARMS, -1, {}, _p([0]), false, _p([0, 1]))
	assert_eq(report.money, RiftEffects.STRAY_LIGHT_MONEY, "nur der ungewertete Würfel streut")

func test_stray_light_needs_its_own_face_up():
	var idle := DieDefinition.new()
	idle.set_rift(3, Rift.STRAY_LIGHT)  # der Riss sitzt auf einer ANDEREN Seite
	var defs: Array[DieDefinition] = [DieDefinition.new(), idle]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m(["", ""]), _p([0]),
		NO_CHARMS, -1, {}, _p([0]), false, _p([0, 1]))
	assert_eq(report.money, 0, "liegt der Riss unten, streut nichts")

func test_stray_light_stays_silent_without_lying_dice():
	var idle := DieDefinition.new()
	idle.set_rift(0, Rift.STRAY_LIGHT)
	var defs: Array[DieDefinition] = [DieDefinition.new(), idle]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m(["", ""]), _p([0]))
	assert_eq(report.money, 0, "ohne gemeldete Grube kein Streulicht")

# --- Bruchmuster: die Würfel-Kategorie ------------------------------------------------

func test_every_rift_has_its_break_pattern():
	var dice_ids: Array[String] = []
	for engraving in Engraving.all():
		if engraving.category == Engraving.CATEGORY_DICE:
			dice_ids.append(engraving.id)
	for rift in Rift.all():
		var id := Engraving.BREAK_PREFIX + rift.id
		assert_true(dice_ids.has(id), "Bruchmuster für %s" % rift.id)
		assert_eq(Engraving.rift_id_of(id), rift.id, "die Gravur-id trägt die Rift-id")

func test_break_patterns_are_not_special_items():
	# Sie gehören in die Würfel-Schublade, nicht in die Sonderbestand-Vitrine.
	for rift in Rift.all():
		assert_false(Engraving.is_special_id(Engraving.BREAK_PREFIX + rift.id))

func test_rift_id_of_rejects_everything_else():
	assert_eq(Engraving.rift_id_of(Engraving.POINTER), "")
	assert_eq(Engraving.rift_id_of(DieMaterial.GOLD), "")
	assert_eq(Engraving.rift_id_of(Engraving.BREAK_PREFIX + "unobtainium"), "")
	assert_false(Engraving.is_rift_id(Engraving.CHISEL))
