extends GutTest
## Tier-1-Tests der Runen: Datensatz, Besitzregel (Stufen in der Glasur, Runen in
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

func _rune_ctx(slot: int, rune_ids: Array) -> Dictionary:
	return {DiceScoring.CTX_RUNES: {slot: _ids(rune_ids)}}

# --- Datensatz ---------------------------------------------------------------------

func test_all_six_runes_are_registered_and_filled():
	assert_eq(Rune.all().size(), 6)
	var seen := {}
	for rune in Rune.all():
		assert_false(seen.has(rune.id), "doppelte id: %s" % rune.id)
		seen[rune.id] = true
		assert_ne(rune.display_name, "", "display_name fehlt bei %s" % rune.id)
		assert_ne(rune.short, "", "short fehlt bei %s" % rune.id)
		assert_ne(rune.description, "", "description fehlt bei %s" % rune.id)
		assert_ne(rune.kind, "", "Klasse fehlt bei %s" % rune.id)
		assert_false(Rune.glyph_lines(rune.glyph).is_empty(), "Zeichen fehlt bei %s" % rune.id)

func test_spark_flight_wears_the_charge_cyan():
	# Der Funke ist derselbe Stoff, den das Casino als Energie abfüllt - die
	# Tönung muss der Ladungsfarbe entsprechen (CasinoStyle.CHARGE gespiegelt).
	assert_eq(Rune.by_id(Rune.SPARK_FLIGHT).tint, CasinoStyle.CHARGE)

func test_hint_and_tint_fall_back_without_a_rune():
	assert_eq(Rune.hint(""), "")
	assert_eq(Rune.tint_for(""), Color.BLACK)
	assert_true(Rune.hint(Rune.AFTERGLOW).contains("Nachglühen"))

# --- Besitzregel: Runen überleben das Übermalen ------------------------------------

func test_a_repaint_keeps_the_rune():
	# Die Dotierung wohnt in der Glasur, die Rune in der Struktur der Schale.
	var def := DieDefinition.new()
	def.set_face_material(0, DieMaterial.RUBY)
	def.set_rune(0, Rune.AFTERGLOW)
	def.dope(0)
	def.set_face_material(0, DieMaterial.GOLD)
	assert_eq(def.material_level(0), 1, "die Dotierung fängt neu an")
	assert_eq(def.runes_on(0), _ids([Rune.AFTERGLOW]), "der Rune bleibt")

func test_become_and_instantiate_copy_the_runes_independently():
	var def := DieDefinition.new()
	def.set_rune(2, Rune.BURN_IN)
	var copy := def.instantiate()
	assert_eq(copy.runes_on(2), _ids([Rune.BURN_IN]))
	copy.set_rune(2, "")
	assert_eq(def.runes_on(2), _ids([Rune.BURN_IN]), "die Kopie teilt das Array nicht")
	var host := DieDefinition.new()
	host.become(def)
	assert_eq(host.runes_on(2), _ids([Rune.BURN_IN]))
	host.set_rune(2, "")
	assert_eq(def.runes_on(2), _ids([Rune.BURN_IN]), "become teilt das Array nicht")

func test_a_fresh_definition_has_no_runes():
	var def := DieDefinition.new()
	for face in 6:
		assert_eq(def.runes_on(face), _ids([]), "Seite %d bricht erst durch eine Gravur" % face)

func test_breaking_an_occupied_face_replaces_the_rune():
	var def := DieDefinition.new()
	def.set_rune(0, Rune.AFTERGLOW)
	def.set_rune(0, Rune.STRAY_LIGHT)
	assert_eq(def.runes_on(0), _ids([Rune.STRAY_LIGHT]), "neu brechen ist erlaubt")

# --- Vakuum: zwei Runen je Seite, nur dort ------------------------------------------

func test_only_vacuum_carries_a_second_rune():
	var plain := DieDefinition.new()
	assert_eq(plain.rune_slots(), 1)
	assert_false(plain.set_rune(0, Rune.AFTERGLOW, 1), "ohne Vakuum kein Zweitriss")
	assert_eq(plain.runes_on(0), _ids([]))
	var vacuum := DieDefinition.new()
	vacuum.essence_id = Essence.VACUUM
	assert_eq(vacuum.rune_slots(), 2)
	assert_true(vacuum.set_rune(0, Rune.AFTERGLOW, 0))
	assert_true(vacuum.set_rune(0, Rune.SPARK_FLIGHT, 1))
	assert_eq(vacuum.runes_on(0), _ids([Rune.AFTERGLOW, Rune.SPARK_FLIGHT]))

func test_vacuum_cracks_are_black_whatever_the_rune():
	assert_ne(RuneEffects.glyph_color(Rune.SPARK_FLIGHT, ""), Color(0.02, 0.02, 0.04))
	assert_eq(RuneEffects.glyph_color(Rune.SPARK_FLIGHT, Essence.VACUUM), Color(0.02, 0.02, 0.04),
		"das Vakuum saugt das Kernlicht nach innen")

func test_vacuum_is_an_essence_without_its_own_effect():
	assert_eq(EssenceEffects.activation_factor(Essence.VACUUM), 1)
	assert_eq(EssenceEffects.eye_value(Essence.VACUUM, 5), 5)
	assert_eq(EssenceEffects.money_for(Essence.VACUUM, 5, 3), 0)

# --- Nachglühen: +1 Auslösung, additiv ----------------------------------------------

func test_afterglow_adds_one_activation():
	assert_eq(RuneEffects.extra_activations(_ids([Rune.AFTERGLOW])), 1)
	assert_eq(RuneEffects.extra_activations(_ids([Rune.STRAY_LIGHT])), 0)
	assert_eq(RuneEffects.extra_activations(_ids([Rune.AFTERGLOW, Rune.AFTERGLOW])), 2,
		"der Vakuum-Doppelriss glüht zweimal nach")

func test_afterglow_sits_on_the_face_axis():
	# Das Nachglühen addiert auf der SEITEN-Achse, Argon multipliziert die WÜRFEL-
	# Achse: 2 × 2 = 4 Zündungen. Innerhalb einer Achse bleibt alles additiv.
	var face := MaterialEffects.face_trigger_count(5, NO_CHARMS,
		RuneEffects.extra_activations(_ids([Rune.AFTERGLOW])))
	assert_eq(face, 2)
	assert_eq(MaterialEffects.die_trigger_count(0, NO_CHARMS, -1, _ids([Essence.ARGON])), 2)
	assert_eq(MaterialEffects.total_trigger_count(0, NO_CHARMS, 5, -1, _ids([Essence.ARGON]), false, 0,
		RuneEffects.extra_activations(_ids([Rune.AFTERGLOW]))), 4)

func test_afterglow_flows_through_the_score():
	# Paar Fünfer: Slot 0 zählt seine Augen zweimal.
	var plain := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), NO_CHARMS, false, NO_MATS)
	var glowing := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]),
		NO_CHARMS, false, NO_MATS, {}, _rune_ctx(0, [Rune.AFTERGLOW]))
	assert_eq(plain, 40)
	assert_eq(glowing, (10 + 5 + 5 + 5) * 2)

func test_the_two_axes_multiply_in_the_score():
	# Quecksilberdampf (×3 Antritte) × Nachglühen (2 Zündungen je Antritt) = 6.
	var ctx := _rune_ctx(0, [Rune.AFTERGLOW])
	ctx[DiceScoring.CTX_ESSENCES] = {0: Essence.MERCURY_VAPOR}
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]),
		NO_CHARMS, false, NO_MATS, {}, ctx)
	assert_eq(score, (10 + 5 * 6 + 5) * 2, "Slot 0 zählt sechsmal")

func test_the_farkle_comparison_sees_the_old_runes():
	# Das Nachglühen ändert Auslösungen - der Vergleich muss die alten Runen
	# kennen, sonst bewertet er die alte Seite mit den neuen.
	var same := _d([5, 5, 1, 2, 3, 6])
	var better := _d([5, 5, 5, 2, 3, 6])
	var new_ctx := _rune_ctx(0, [Rune.AFTERGLOW])
	var old_ctx := _rune_ctx(0, [])
	assert_false(DiceScoring.is_strictly_better(same, same, NO_CHARMS, NO_MATS, NO_MATS, {}, new_ctx, old_ctx),
		"gleicher Rang bleibt Farkle")
	assert_true(DiceScoring.is_strictly_better(better, same, NO_CHARMS, NO_MATS, NO_MATS, {}, new_ctx, old_ctx))

func test_links_never_fire_a_rune():
	# Eine Rune gehört der OBEN liegenden Seite; ein Glied ist per Definition eine
	# andere Seite und lässt ihn kalt.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var ctx := _rune_ctx(0, [Rune.AFTERGLOW])
	ctx[DiceScoring.CTX_POINTER_FIRES] = {0: [[{"face": 2, "value": 4, "material": "", "level": 1}]]}
	# Basis: Paar (10) + 5 + 5 (Nachglühen zählt Slot 0 zweimal) + 5 + Glied 4.
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, NO_MATS, {}, ctx),
		(10 + 5 + 5 + 5 + 4) * 2, "das Glied feuert einmal, ohne Nachglühen")

# --- Einbrand: der Wert ist eingebrannt ----------------------------------------------

func test_burn_in_protects_the_face_value():
	assert_true(RuneEffects.protects_face_value(_ids([Rune.BURN_IN])))
	assert_false(RuneEffects.protects_face_value(_ids([Rune.AFTERGLOW])))

func test_burn_in_stops_the_glass_from_shrinking():
	var kept := MaterialEffects.mutate_value_once(5, DieMaterial.GLASS, NO_CHARMS, 1, _ids([]), _ids([Rune.BURN_IN]))
	assert_eq(kept, 5, "eingebrannt: die Seite verliert nichts")
	var plain := MaterialEffects.mutate_value_once(5, DieMaterial.GLASS, NO_CHARMS, 1, _ids([]), _ids([]))
	assert_eq(plain, 4, "ohne Einbrand schrumpft Glas normal")

func test_burn_in_survives_a_take():
	var def := DieDefinition.new()
	def.faces[0] = 5
	def.set_face_material(0, DieMaterial.GLASS)
	def.set_rune(0, Rune.BURN_IN)
	var defs: Array[DieDefinition] = [def]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]))
	assert_eq(def.faces[0], 5, "auch beim Nehmen bleibt der Wert stehen")

func test_burn_in_skips_the_radon_decay():
	var run := GameRun.new_run()
	var die := run.owned_pool[0]
	die.essence_id = Essence.RADON
	for face in 6:
		die.set_rune(face, Rune.BURN_IN)
	var before := die.faces.duplicate()
	assert_false(EssenceEffects.decay_die(die), "kein Kandidat, kein Zerfall")
	assert_eq(die.faces, before, "eingebrannte Seiten zerfallen nicht")

# --- Funkenflug: +1 ⚡ je Zug ---------------------------------------------------------

func test_spark_flight_pays_one_charge():
	assert_eq(RuneEffects.charge_for_take(_ids([Rune.SPARK_FLIGHT])), RuneEffects.SPARK_FLIGHT_CHARGE)
	assert_eq(RuneEffects.charge_for_take(_ids([Rune.AFTERGLOW])), 0)

func test_spark_flight_books_once_per_take_not_per_activation():
	# Argon löst den Würfel zweimal aus - der Funke springt trotzdem einmal.
	var def := DieDefinition.new()
	def.essence_id = Essence.ARGON
	def.set_rune(0, Rune.SPARK_FLIGHT)
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
	scored.set_rune(0, Rune.STRAY_LIGHT)
	var idle := DieDefinition.new()
	idle.set_rune(0, Rune.STRAY_LIGHT)
	var defs: Array[DieDefinition] = [scored, idle]
	# Slot 0 wertet, Slot 1 liegt ungewertet daneben.
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m(["", ""]), _p([0]),
		NO_CHARMS, -1, {}, _p([0]), false, _p([0, 1]))
	assert_eq(report.money, RuneEffects.STRAY_LIGHT_MONEY, "nur der ungewertete Würfel streut")

func test_stray_light_needs_its_own_face_up():
	var idle := DieDefinition.new()
	idle.set_rune(3, Rune.STRAY_LIGHT)  # die Rune sitzt auf einer ANDEREN Seite
	var defs: Array[DieDefinition] = [DieDefinition.new(), idle]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m(["", ""]), _p([0]),
		NO_CHARMS, -1, {}, _p([0]), false, _p([0, 1]))
	assert_eq(report.money, 0, "liegt der Rune unten, streut nichts")

func test_stray_light_stays_silent_without_lying_dice():
	var idle := DieDefinition.new()
	idle.set_rune(0, Rune.STRAY_LIGHT)
	var defs: Array[DieDefinition] = [DieDefinition.new(), idle]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m(["", ""]), _p([0]))
	assert_eq(report.money, 0, "ohne gemeldete Grube kein Streulicht")

# --- Rune: die Würfel-Kategorie ------------------------------------------------

func test_every_rune_has_its_break_pattern():
	var dice_ids: Array[String] = []
	for engraving in Engraving.all():
		if engraving.category == Engraving.CATEGORY_DICE:
			dice_ids.append(engraving.id)
	for rune in Rune.all():
		var id := Engraving.RUNE_PREFIX + rune.id
		assert_true(dice_ids.has(id), "Rune für %s" % rune.id)
		assert_eq(Engraving.rune_id_of(id), rune.id, "die Gravur-id trägt die Runen-id")

func test_break_patterns_are_not_special_items():
	# Sie gehören in die Würfel-Schublade, nicht in die Sonderbestand-Vitrine.
	for rune in Rune.all():
		assert_false(Engraving.is_special_id(Engraving.RUNE_PREFIX + rune.id))

func test_rune_id_of_rejects_everything_else():
	assert_eq(Engraving.rune_id_of(Engraving.POINTER), "")
	assert_eq(Engraving.rune_id_of(DieMaterial.GOLD), "")
	assert_eq(Engraving.rune_id_of(Engraving.RUNE_PREFIX + "unobtainium"), "")
	assert_false(Engraving.is_rune_id(Engraving.CHISEL))

# --- Abguss: greift in den Vorrat, nicht in die Wertung ------------------------

func _cast_die(material_id: String) -> DieDefinition:
	var def := DieDefinition.new()
	def.faces = _p([3, 3, 3, 3, 3, 3])
	if material_id != "":
		def.set_face_material(0, material_id)
	def.set_rune(0, Rune.CAST)
	return def

## Versiegelte Fixinhalt-Pakete dieser Gravur im Lager - lose wartet nichts mehr.
func _stock(run: GameRun, id: String) -> int:
	var count := 0
	for pack in run.owned_packs:
		if pack.fixed_engraving != null and pack.fixed_engraving.id == id:
			count += 1
	return count

func test_the_cast_copies_the_material_engraving_once_per_round_and_die():
	var run := GameRun.new_run()
	var defs: Array[DieDefinition] = [_cast_die(DieMaterial.GOLD)]
	var before := _stock(run, DieMaterial.GOLD)
	assert_eq(run.apply_rune_cast(defs, _p([0]), _p([0])), 1, "ein Abguss")
	assert_eq(_stock(run, DieMaterial.GOLD), before + 1, "die Kopie liegt versiegelt im Lager")
	assert_eq(run.apply_rune_cast(defs, _p([0]), _p([0])), 0,
		"derselbe Würfel gießt in derselben Runde nicht noch einmal ab")
	assert_eq(_stock(run, DieMaterial.GOLD), before + 1)
	run.roll_essence_round_state()
	assert_eq(run.apply_rune_cast(defs, _p([0]), _p([0])), 1, "die neue Runde macht die Form frei")

func test_the_cast_of_nothing_is_nothing():
	var run := GameRun.new_run()
	var defs: Array[DieDefinition] = [_cast_die("")]
	assert_eq(run.apply_rune_cast(defs, _p([0]), _p([0])), 0,
		"eine Seite ohne Material hat nichts abzuformen")

func test_the_cast_only_fires_on_the_scored_face():
	var run := GameRun.new_run()
	var defs: Array[DieDefinition] = [_cast_die(DieMaterial.GOLD)]
	# Seite 2 liegt oben, die Rune sitzt auf Seite 0.
	assert_eq(run.apply_rune_cast(defs, _p([2]), _p([0])), 0)

func test_the_cast_never_inherits_the_saturation():
	# Der Abguss ist eine frische Gravur der Stufe I - sonst wäre eine Stufe-III-
	# Seite eine Druckerpresse für Stufe-III-Material.
	var run := GameRun.new_run()
	var def := _cast_die(DieMaterial.RUBY)
	def.levels[0] = 3
	var defs: Array[DieDefinition] = [def]
	assert_eq(run.apply_rune_cast(defs, _p([0]), _p([0])), 1)
	assert_eq(_stock(run, DieMaterial.RUBY), 1, "genau eine, nicht drei")

# --- Kehrseite: ein deterministisches Glied, kein zweiter Pfad -----------------

func _reverse_die() -> DieDefinition:
	var def := DieDefinition.new()
	def.faces = _p([1, 2, 3, 4, 5, 6])
	def.set_rune(0, Rune.REVERSE)
	return def

func test_the_reverse_links_the_opposite_face():
	var no_essence: Array[String] = []
	var faces := EssenceEffects.link_faces(_reverse_die(), 0, no_essence, _ids([Rune.REVERSE]))
	assert_eq(faces, [DieDefinition.opposite_face(0)], "die Gegenseite, deterministisch")

func test_the_reverse_and_the_xray_never_link_the_same_face_twice():
	# Beide meinen die Gegenseite - zusammen bleibt es EIN Glied.
	var faces := EssenceEffects.link_faces(_reverse_die(), 0, _ids([Essence.XRAY]),
		_ids([Rune.REVERSE]))
	assert_eq(faces.size(), 1, "jede Seite höchstens einmal")

func test_a_die_without_the_reverse_links_nothing():
	var no_essence: Array[String] = []
	var faces := EssenceEffects.link_faces(_reverse_die(), 0, no_essence, _ids([Rune.AFTERGLOW]))
	assert_true(faces.is_empty())

func test_a_link_fires_no_runes_of_its_own():
	# Eine Rune gehört der OBEREN Seite. Stünde auf der Gegenseite eine zweite
	# Kehrseite, schaukelten sich beide sonst gegenseitig hoch.
	var def := _reverse_die()
	def.set_rune(DieDefinition.opposite_face(0), Rune.REVERSE)
	var no_essence: Array[String] = []
	var faces := EssenceEffects.link_faces(def, 0, no_essence, def.runes_on(0))
	assert_eq(faces.size(), 1, "das Glied zündet keine weitere Kehrseite")
