extends GutTest
## Tier-1-Tests der Zähl-Animation-Zerlegung (ScoreBreakdown): Die Schrittliste
## muss in JEDEM Szenario exakt die echte Wertung (DiceScoring.score_category)
## ergeben - sonst zeigt die Grubenanimation andere Punkte, als der Spieler
## bekommt. Dazu Struktur-Checks: welche Würfel zählen Augen, welche Charms
## welchen Schritten zugeordnet werden, und dass die Zwischenstände lückenlos
## aufeinander aufbauen.

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

const NO_MATS: Array[String] = []

## Baut die Zerlegung und prüft das Herzstück: total == score_category.
func _build_and_check(key: String, dice: Array[int], ids: Array[String] = [], first := false, mats: Array[String] = [], edges: Array[String] = [], levels: Dictionary = {}, ctx: Dictionary = {}) -> Dictionary:
	var breakdown := ScoreBreakdown.build(key, dice, ids, first, mats, edges, levels, ctx)
	var expected := DiceScoring.score_category(key, dice, ids, first, mats, edges, levels, ctx)
	assert_eq(breakdown["total"], expected, "Schrittliste ergibt die echte Wertung (%s)" % key)
	_check_continuity(breakdown)
	return breakdown

## Die Zwischenstände müssen lückenlos aufeinander aufbauen: jeder Schritt
## startet beim Nachher-Wert des vorigen, und der letzte Stand ist base/mult.
func _check_continuity(breakdown: Dictionary) -> void:
	var base: int = breakdown["combo"]["base_add"]
	var mult: int = breakdown["combo"]["mult_add"]
	var prev_slot := -1
	for step: Dictionary in breakdown["die_steps"]:
		assert_gt(int(step["slot"]), prev_slot, "Würfel zählen links nach rechts (Slot-Reihenfolge)")
		prev_slot = step["slot"]
		base += step["eye_add"]
		assert_eq(step["base_after_eye"], base, "Zwischenstand nach den Augen")
		assert_eq(step["mult_after_eye"], mult)
		base += step["mat_base_add"]
		mult += step["mat_mult_add"]
		assert_eq(step["base_after_mat"], base, "Zwischenstand nach dem Material")
		assert_eq(step["mult_after_mat"], mult)
		base += step["charm_base_add"]
		mult += step["charm_mult_add"]
		assert_eq(step["base_after"], base)
		assert_eq(step["mult_after"], mult)
	for step: Dictionary in breakdown["charm_steps"]:
		base = (base + step["base_add"]) * step["base_x"]
		mult = (mult + step["mult_add"]) * step["mult_x"]
		assert_eq(step["base_after"], base)
		assert_eq(step["mult_after"], mult)
	assert_eq(breakdown["base"], base, "Endstand Basis")
	assert_eq(breakdown["mult"], maxi(1, mult), "Endstand Mult (geklemmt)")
	assert_eq(breakdown["merge_total"], base * maxi(1, mult))
	var total: int = breakdown["merge_total"]
	for step: Dictionary in breakdown["post_steps"]:
		total = int(round((total + step["total_add"]) * step["total_x"]))
		assert_eq(step["total_after"], total)

# --- Grundfälle (charm-/materialfrei) -----------------------------------------

func test_plain_pair_matches_scoring():
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]))
	assert_eq(breakdown["combo"]["base_add"], 10, "feste Paar-Punkte")
	assert_eq(breakdown["combo"]["mult_add"], 2)
	assert_eq(breakdown["die_steps"].size(), 2, "nur die Paar-Würfel zählen Augen")
	assert_eq(breakdown["charm_steps"].size(), 0)
	assert_eq(breakdown["post_steps"].size(), 0)

func test_sum_category_counts_only_participating_dice():
	# Full House zählt nur die beteiligten Würfel; der unbeteiligte sechste
	# (die 1) bleibt außen vor.
	var breakdown := _build_and_check(DiceScoring.FULL_HOUSE, _d([2, 2, 2, 4, 4, 1]))
	assert_eq(breakdown["eye_slots"], [0, 1, 2, 3, 4])
	assert_eq(breakdown["die_steps"].size(), 5)

func test_composite_hands_count_left_to_right():
	# Das Paar liegt LINKS vom Drilling - gezählt wird trotzdem in Slot-,
	# nie in Gruppenreihenfolge (Drilling zuerst wäre [2,3,4,0,1]).
	var breakdown := _build_and_check(DiceScoring.FULL_HOUSE, _d([4, 4, 2, 2, 2, 1]))
	assert_eq(breakdown["eye_slots"], [0, 1, 2, 3, 4])

func test_eye_order_counts_dice_in_the_given_order():
	# eye_order legt die Zähl-Reihenfolge fest (physische Grubenanordnung beim
	# Nehmen) - hier rückwärts. Die Schritte folgen ihr, die Summe bleibt gleich.
	var dice := _d([1, 2, 3, 4, 5, 6])  # Große Straße: alle sechs beteiligt
	var order := _d([5, 4, 3, 2, 1, 0])
	var breakdown := ScoreBreakdown.build(DiceScoring.LARGE_STRAIGHT, dice, [], false,
		NO_MATS, NO_MATS, {}, {}, order)
	assert_eq(breakdown["eye_slots"], order, "Würfel zählen in eye_order")
	var slots: Array[int] = []
	for step: Dictionary in breakdown["die_steps"]:
		slots.append(int(step["slot"]))
	assert_eq(slots, order, "auch die Schritte folgen eye_order")
	# Umsortieren ist rein kosmetisch: gleiche Summe wie in Slot-Reihenfolge.
	var default_bd := ScoreBreakdown.build(DiceScoring.LARGE_STRAIGHT, dice)
	assert_eq(breakdown["total"], default_bd["total"], "Reihenfolge ändert die Summe nicht")

func test_every_category_example_matches():
	# Jedes Anzeige-Beispiel der Bildschirmliste läuft einmal durch die Zerlegung.
	for key: String in DiceScoring.HAND_PRIORITY:
		_build_and_check(key, _d(DiceScoring.EXAMPLE_DICE[key]))

func test_combo_levels_flow_into_combo_step():
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), _ids([]), false, NO_MATS, NO_MATS, {DiceScoring.TWO_KIND: 1})
	assert_eq(breakdown["combo"]["base_add"], 20, "Übertaktungs-Stufe verdoppelt die festen Punkte")
	assert_eq(breakdown["combo"]["mult_add"], 4)

# --- Material-Schritte ----------------------------------------------------------

func test_material_bonuses_split_per_die():
	# Rubin auf Slot 0, Bernstein auf Slot 1: jeder Bonus landet an SEINEM Würfel,
	# die Summe entspricht der echten Wertung.
	var mats := _m([DieMaterial.RUBY, DieMaterial.AMBER, "", "", "", ""])
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), _ids([]), false, mats)
	var steps: Array = breakdown["die_steps"]
	assert_eq(steps[0]["mat_mult_add"], 4, "Rubin: +4 Mult am ersten Würfel")
	assert_eq(steps[0]["mat_base_add"], 0)
	assert_eq(steps[1]["mat_base_add"], 20, "Bernstein: +20 Basis am zweiten Würfel")
	assert_eq(steps[1]["mat_mult_add"], 0)

func test_mercury_edge_retrigger_stays_at_its_die():
	var mats := _m([DieMaterial.RUBY, "", "", "", "", ""])
	var edges := _m([DieMaterial.MERCURY, "", "", "", "", ""])
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), _ids([]), false, mats, edges)
	var steps: Array = breakdown["die_steps"]
	assert_eq(steps[0]["mat_base_add"], 5, "zweite Augen-Zählung am Quecksilber-Würfel")
	assert_eq(steps[0]["mat_mult_add"], 8, "Rubin feuert zweimal")

# --- Charm-Schritte --------------------------------------------------------------

func test_retrigger_charm_recounts_at_the_die():
	# Hasenpfote löst die 6 erneut aus - die Nachzählung erscheint als
	# Würfel-Bonus (wie Quecksilber), nicht als Augenwert-Änderung.
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([6, 6, 1, 2, 3, 5]), _ids([Charm.RABBITS_FOOT]))
	var steps: Array = breakdown["die_steps"]
	assert_eq(steps[0]["eye_add"], 6)
	assert_eq(steps[0]["mat_base_add"], 6, "zweite Augen-Zählung durch den Retrigger")
	assert_eq(steps[0]["eye_charm_indices"], [], "Augenwert selbst unverändert")
	assert_eq(breakdown["charm_steps"].size(), 0, "kein eigener Charm-Schritt")

func test_transform_charm_lights_up_at_the_die():
	# Glückszigaretten: die 1 zeigt eine 6 - der Würfel-Schritt nennt die
	# Besitz-Position des Verwandlers.
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([1, 1, 2, 3, 4, 4]), _ids([Charm.LUCKY_CIGARETTES]))
	var steps: Array = breakdown["die_steps"]
	assert_eq(steps[0]["eye_add"], 6, "verwandelte 1 zählt als 6")
	assert_eq(steps[0]["eye_charm_indices"], [0])

func test_additive_charm_gets_its_own_step():
	var breakdown := _build_and_check(DiceScoring.FULL_HOUSE, _d([2, 2, 2, 5, 5, 1]), _ids([Charm.HORSESHOE]))
	var steps: Array = breakdown["charm_steps"]
	assert_eq(steps.size(), 1)
	assert_eq(steps[0]["charm_indices"], [0])
	assert_eq(steps[0]["mult_add"], 12, "Hufeisen: Full House +12 Mult")

func test_per_die_charm_fires_inside_the_die_step():
	# Breitband feuert MIT jedem beteiligten Würfel, nicht in der Charm-Phase:
	# zwei Kopien -> +10 im Schritt jedes Paar-Würfels, beide Positionen genannt.
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), _ids([Charm.BROADBAND, Charm.BROADBAND]))
	var steps: Array = breakdown["die_steps"]
	assert_eq(steps.size(), 2)
	for step: Dictionary in steps:
		assert_eq(step["charm_base_add"], 10, "beide Breitband-Kopien am Würfel selbst")
		assert_eq(step["die_charm_indices"], [0, 1])
	assert_eq(breakdown["charm_steps"].size(), 0, "kein Charm-Phase-Schritt mehr")

func test_nonlinear_charms_still_sum_exactly():
	# Einsiedlerkrebs (+6 nur bei ≤2 Charms) + Sammler-Amulett (je anderem Charm):
	# verschränkte Beiträge - die Teleskopsumme muss trotzdem exakt stimmen.
	_build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), _ids([Charm.HERMIT_CRAB, Charm.COLLECTORS_AMULET]))

func test_cult_of_one_becomes_factor_step():
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 1, 3, 6]), _ids([Charm.CULT_OF_ONE]))
	var steps: Array = breakdown["charm_steps"]
	assert_eq(steps.size(), 1)
	assert_eq(steps[0]["base_x"], 4, "×2 je gewürfelter 1 (zwei Einsen)")
	assert_eq(steps[0]["mult_x"], 4)
	assert_eq(steps[0]["charm_indices"], [0])

func test_gallows_humor_is_a_positioned_crit_step():
	var ids := _ids([Charm.GALLOWS_HUMOR])
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), ids, false, NO_MATS, NO_MATS, {}, {"after_farkle": true})
	var crit_steps: Array = breakdown["charm_steps"].filter(func(s: Dictionary) -> bool: return s["crit_x"] > 1)
	assert_eq(crit_steps.size(), 1)
	assert_eq(crit_steps[0]["mult_x"], 4, "Krit ×4 an der eigenen Position")
	assert_eq(crit_steps[0]["crit_x"], 4, "als Krit markiert - die UI kann ihn inszenieren")
	assert_eq(crit_steps[0]["charm_indices"], [0])

func test_non_crit_factor_steps_carry_crit_one():
	# Einserkult ist KEIN Krit (Faktor auf Basis UND Mult) - crit_x bleibt 1.
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 1, 3, 6]), _ids([Charm.CULT_OF_ONE]))
	assert_eq(breakdown["charm_steps"][0]["crit_x"], 1)

func test_factor_charm_respects_dock_order():
	# KEINE Ausnahmen: Einserkult VOR Momentum verdoppelt dessen +3 nicht,
	# dahinter schon - und die Schrittliste läuft in Besitz-Reihenfolge.
	var ctx := {CharmEffects.CTX_STREAK: 3}
	var dice := _d([5, 5, 1, 2, 3, 6])
	var cult_first := _build_and_check(DiceScoring.TWO_KIND, dice, _ids([Charm.CULT_OF_ONE, Charm.MOMENTUM]), false, NO_MATS, NO_MATS, {}, ctx)
	var cult_last := _build_and_check(DiceScoring.TWO_KIND, dice, _ids([Charm.MOMENTUM, Charm.CULT_OF_ONE]), false, NO_MATS, NO_MATS, {}, ctx)
	# Eine 1 im Wurf: ×2. Vorn: (2×2 + 3) = 7 Mult, Basis 40 -> 280.
	# Hinten: (2 + 3) × 2 = 10 Mult, Basis 40 -> 400.
	assert_eq(cult_first["total"], 280)
	assert_eq(cult_last["total"], 400)
	assert_eq(cult_first["charm_steps"][0]["charm_indices"], [0], "Schritte folgen der Dock-Reihenfolge")
	assert_eq(cult_first["charm_steps"][1]["charm_indices"], [1])

# --- Nach-Schritte (auf die fertige Punktzahl) ------------------------------------

func test_rainbow_trout_is_a_mult_step():
	var breakdown := _build_and_check(DiceScoring.SMALL_STRAIGHT, _d([1, 2, 3, 4, 5, 5]), _ids([Charm.RAINBOW_TROUT]))
	var steps: Array = breakdown["charm_steps"]
	assert_eq(steps.size(), 1)
	assert_eq(steps[0]["mult_add"], 10)
	assert_eq(steps[0]["charm_indices"], [0])
	assert_true(breakdown["post_steps"].is_empty(), "kein Nach-Schritt mehr")

func test_magic_card_is_a_total_factor():
	var ids := _ids([Charm.MAGIC_CARD])
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), ids, true)
	var posts: Array = breakdown["post_steps"]
	assert_eq(posts.size(), 1)
	assert_eq(posts[0]["total_x"], 2.0)
	assert_eq(posts[0]["charm_indices"], [0])

func test_after_work_beer_doubles_the_base_and_crits():
	# Leerer Nachziehstapel: ein Schritt, der die Basis verdoppelt UND krittet.
	var ids := _ids([Charm.AFTER_WORK_BEER])
	var ctx := {CharmEffects.CTX_POOL_EMPTY: true}
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), ids, false, NO_MATS, NO_MATS, {}, ctx)
	var steps: Array = breakdown["charm_steps"]
	assert_eq(steps.size(), 1)
	assert_eq(steps[0]["base_x"], 2, "Basis verdoppelt")
	assert_eq(steps[0]["mult_x"], 2, "Krit steckt im Mult-Faktor")
	assert_eq(steps[0]["crit_x"], 2, "und bleibt als Krit sichtbar")
	assert_eq(steps[0]["charm_indices"], [0])
	assert_true(breakdown["post_steps"].is_empty(), "kein Nach-Schritt mehr")

func test_after_work_beer_stays_quiet_while_the_pool_has_dice():
	var ids := _ids([Charm.AFTER_WORK_BEER])
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), ids)
	assert_true(breakdown["charm_steps"].is_empty())

# --- Großer Kombinationstest: alles gleichzeitig -----------------------------------

func test_kitchen_sink_scenario_matches_scoring():
	# Materialien + Augen-Charm + additive Charms + Einserkult + Krit + Totem-
	# aufgelöste ids + Übertaktungs-Stufen + Kontext: die Zerlegung muss exakt bleiben.
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.broadband())
	run.owned_charms.append(Charm.parrot_totem())
	run.owned_charms.append(Charm.cult_of_one())
	run.owned_charms.append(Charm.gallows_humor())
	run.owned_charms.append(Charm.rabbits_foot())
	var dice := _d([6, 6, 6, 1, 2, 5])
	var mats := _m([DieMaterial.RUBY, "", DieMaterial.AMBER, "", "", ""])
	var edges := _m(["", DieMaterial.MERCURY, "", "", "", ""])
	var levels := {DiceScoring.THREE_KIND: 1}
	var ctx := {"after_farkle": true, "streak": 2}
	_build_and_check(DiceScoring.THREE_KIND, dice, run.charm_ids(), true, mats, edges, levels, ctx)

# --- Pro-Würfel-Meteor -------------------------------------------------------------

func test_sediment_fires_in_the_die_steps():
	# Bodensatz: Paar Fünfer, beide Slots spät gezogen -> +3 Mult IM Schritt
	# jedes beteiligten Würfels, keine Charm-Phase.
	var ctx := {CharmEffects.CTX_LATE_SLOTS: [0, 1]}
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]),
		_ids([Charm.SEDIMENT]), false, NO_MATS, NO_MATS, {}, ctx)
	var steps: Array = breakdown["die_steps"]
	assert_eq(steps.size(), 2)
	for step: Dictionary in steps:
		assert_eq(step["charm_mult_add"], 3, "+3 Mult mit dem Würfel selbst")
		assert_eq(step["die_charm_indices"], [0])
	assert_eq(breakdown["charm_steps"].size(), 0)

func test_full_counter_scores_bystanders_as_die_steps():
	# Vollzähler macht ALLE liegenden Würfel zu Würfel-Schritten - auch die
	# Unbeteiligten leuchten und zählen ihre Augen, kein eigener Charm-Schritt.
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]),
		_ids([Charm.FULL_COUNTER]))
	assert_eq(breakdown["die_steps"].size(), 6, "alle sechs Würfel als Schritt")
	assert_eq(breakdown["eye_slots"], _d([0, 1, 2, 3, 4, 5]))
	assert_eq(breakdown["charm_steps"].size(), 0, "kein eigener Vollzähler-Schritt")
	assert_eq(int(breakdown["die_steps"][2]["eye_add"]), 1, "unbeteiligter Würfel (Auge 1) zählt mit")

func test_bonus_that_is_not_per_die_carries_no_pulses():
	# Marienkäfer gibt +4 Mult aufs Paar - ein Schritt, aber kein Pro-Würfel-Charm.
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]),
		_ids([Charm.LADYBUG]), false)
	var steps: int = breakdown["charm_steps"].size()
	assert_gt(steps, 0, "Marienkäfer erzeugt einen Schritt")
	for step: Dictionary in breakdown["charm_steps"]:
		assert_false(step.has("pulses"), "Nicht-pro-Würfel-Schritt trägt keine Pulse")

# --- Systematischer Deckungstest: build == score_category über die Matrix ----------
# ScoreBreakdown und DiceScoring komponieren dieselben ~9 Charm-Hooks in eigener
# Reihenfolge. Dieser Fächer prüft NUR die Deckungsgleichheit (nicht Einzelwerte):
# jede Kombination aus Charm-Satz × Wurf × Umgebung muss in beiden Pfaden exakt
# gleich fallen - so kann keine künftige Hook-Änderung die zwei still auseinander-
# laufen lassen (wie schon einmal bei Anzeige/Buchung geschehen).

## Ein Vertreter je Hook-Typ plus ein paar Stapel - Wert egal, nur Deckung zählt.
func _prop_charm_sets() -> Array:
	return [
		[],
		[Charm.LIGHTHOUSE], [Charm.TWIN_RING], [Charm.SNAKE_EYES],
		[Charm.PENDULUM], [Charm.ALL_OR_NOTHING], [Charm.MOMENTUM], [Charm.BROKEN_MIRROR],
		[Charm.EVEN_COMPANY], [Charm.ODD_PATH], [Charm.HERMIT_CRAB], [Charm.DISPLAY_CASE],
		[Charm.COLLECTORS_AMULET], [Charm.ECHO_CHAMBER], [Charm.STREET_SWEEPER],
		[Charm.FULL_COUNTER], [Charm.BROADBAND], [Charm.SEDIMENT],
		[Charm.EDGE_GLEAM], [Charm.BLACKJACK], [Charm.ROUND_NUMBER], [Charm.HORSESHOE],
		[Charm.LADYBUG], [Charm.PEARL_NECKLACE], [Charm.RAINBOW_TROUT], [Charm.MAGIC_CARD],
		[Charm.CULT_OF_ONE], [Charm.GALLOWS_HUMOR], [Charm.AFTER_WORK_BEER],
		[Charm.LUCKY_CIGARETTES], [Charm.PENCIL_STUB], [Charm.FOX_TAIL],
		[Charm.SMALL_FRY], [Charm.EQUALIZER],
		[Charm.RABBITS_FOOT], [Charm.FOUR_LEAF_CLOVER], [Charm.GOLDEN_SCARAB],
		[Charm.CULT_OF_ONE, Charm.GALLOWS_HUMOR, Charm.MAGIC_CARD],
		[Charm.LUCKY_CIGARETTES, Charm.ECHO_CHAMBER, Charm.BLACKJACK],
		[Charm.EQUALIZER, Charm.SMALL_FRY, Charm.ECHO_CHAMBER, Charm.FULL_COUNTER],
	]

## Würfe mit unbeteiligten Würfeln, geraden/ungeraden Läufen, Einsen und Sechsen -
## deckt die wertabhängigen Verzweigungen der Hooks ab.
func _prop_dice() -> Array:
	return [
		[1, 2, 3, 4, 5, 6], [6, 6, 6, 1, 1, 2], [5, 5, 1, 2, 3, 4],
		[1, 1, 2, 4, 6, 6], [2, 2, 2, 4, 4, 6], [1, 3, 5, 5, 5, 5],
		[2, 4, 6, 2, 4, 6], [1, 3, 5, 1, 3, 5],
	]

func test_breakdown_matches_scoring_across_the_matrix():
	var levels := {DiceScoring.TWO_KIND: 1, DiceScoring.THREE_KIND: 1}
	# Zwei Umgebungen: nackt, und voll (Materialien + Kanten + reicher Kontext +
	# Übertaktung + erste Hand) - so laufen auch die Material-/Krit-Zweige mit.
	var full_mats := _m([DieMaterial.RUBY, "", DieMaterial.AMBER, DieMaterial.GLASS, "", DieMaterial.BONE])
	var full_edges := _m(["", DieMaterial.MERCURY, "", "", DieMaterial.GOLD, ""])
	var rich_ctx := {
		CharmEffects.CTX_PENDULUM: 4,
		CharmEffects.CTX_FULL_REROLLS: 2, CharmEffects.CTX_STREAK: 3,
		CharmEffects.CTX_POOL_EMPTY: true, CharmEffects.CTX_AFTER_FARKLE: true,
		CharmEffects.CTX_FARKLE_STACKS: 2,
		CharmEffects.CTX_LATE_SLOTS: [4, 5],
	}
	# Nur die Deckung (total == score_category) je Zelle - die Zwischenstände
	# prüfen die gezielten Tests oben. Abweichungen sammeln und EINMAL asserten,
	# sonst ertränkt der Fächer (~640 Zellen) das Log.
	var mismatches: Array[String] = []
	var checked := 0
	for set: Array in _prop_charm_sets():
		var ids := _ids(set)
		for raw: Array in _prop_dice():
			var dice := _d(raw)
			var key: String = DiceScoring.best_hand(dice, ids, false, NO_MATS, NO_MATS, {}, {})["key"]
			var first_key: String = DiceScoring.best_hand(dice, ids, true, full_mats, full_edges, levels, rich_ctx)["key"]
			_collect_mismatch(mismatches, key, dice, ids, false, NO_MATS, NO_MATS, {}, {})
			_collect_mismatch(mismatches, first_key, dice, ids, true, full_mats, full_edges, levels, rich_ctx)
			checked += 2
	assert_eq(mismatches, [] as Array[String],
		"%d/%d Zellen weichen ab: %s" % [mismatches.size(), checked, ", ".join(mismatches)])

## Hängt eine Beschreibung an, WENN build["total"] von score_category abweicht -
## und prüft zugleich, dass jeder Pro-Würfel-Puls-Schritt sich exakt zu seiner
## Marginale summiert (sonst zeigte die Meteor-je-Würfel-Animation falsche Zahlen).
func _collect_mismatch(into: Array[String], key: String, dice: Array[int], ids: Array[String], first: bool, mats: Array[String], edges: Array[String], levels: Dictionary, ctx: Dictionary) -> void:
	var breakdown := ScoreBreakdown.build(key, dice, ids, first, mats, edges, levels, ctx)
	var total: int = breakdown["total"]
	var expected := DiceScoring.score_category(key, dice, ids, first, mats, edges, levels, ctx)
	if total != expected:
		into.append("%s%s/%s/%s: %d≠%d" % ["erste " if first else "", key, str(ids), str(dice), total, expected])
	for step: Dictionary in breakdown["charm_steps"]:
		if not step.has("pulses"):
			continue
		var sum_base := 0
		var sum_mult := 0
		for p: Dictionary in step["pulses"]:
			sum_base += int(p["base"])
			sum_mult += int(p["mult"])
		if sum_base != int(step["base_add"]) or sum_mult != int(step["mult_add"]):
			into.append("PULSE-SUMME %s/%s: %d/%d≠%d/%d" % [key, str(ids), sum_base, sum_mult, step["base_add"], step["mult_add"]])
