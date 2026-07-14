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
	for step: Dictionary in breakdown["die_steps"]:
		base += step["eye_add"]
		assert_eq(step["base_after_eye"], base, "Zwischenstand nach den Augen")
		base += step["mat_base_add"]
		mult += step["mat_mult_add"]
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
	# (die 1) bleibt außen vor (siehe DiceScoring._base_value).
	var breakdown := _build_and_check(DiceScoring.FULL_HOUSE, _d([2, 2, 2, 4, 4, 1]))
	assert_eq(breakdown["eye_slots"], [0, 1, 2, 3, 4])
	assert_eq(breakdown["die_steps"].size(), 5)

func test_every_category_example_matches():
	# Jedes Anzeige-Beispiel der Bildschirmliste läuft einmal durch die Zerlegung.
	for key: String in DiceScoring.HAND_PRIORITY:
		_build_and_check(key, _d(DiceScoring.EXAMPLE_DICE[key]))

func test_combo_levels_flow_into_combo_step():
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), _ids([]), false, NO_MATS, NO_MATS, {DiceScoring.TWO_KIND: 1})
	assert_eq(breakdown["combo"]["base_add"], 20, "Menü-Stufe verdoppelt die festen Punkte")
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

func test_eye_charm_lights_up_at_the_die():
	# Hasenpfote verdoppelt die 6 - der Würfel-Schritt nennt ihre Besitz-Position.
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([6, 6, 1, 2, 3, 5]), _ids([Charm.RABBITS_FOOT]))
	var steps: Array = breakdown["die_steps"]
	assert_eq(steps[0]["eye_add"], 12)
	assert_eq(steps[0]["eye_charm_indices"], [0])
	assert_eq(breakdown["charm_steps"].size(), 0, "reiner Augen-Charm hat keinen eigenen Schritt")

func test_additive_charm_gets_its_own_step():
	var breakdown := _build_and_check(DiceScoring.FULL_HOUSE, _d([2, 2, 2, 5, 5, 1]), _ids([Charm.HORSESHOE]))
	var steps: Array = breakdown["charm_steps"]
	assert_eq(steps.size(), 1)
	assert_eq(steps[0]["charm_indices"], [0])
	assert_eq(steps[0]["mult_add"], 12, "Hufeisen: Full House +12 Mult")

func test_prefix_marginals_attribute_stacked_charms():
	# Zwei Breitband (per Totem gestapelt wäre gleich): je +10 Basis, zwei Schritte.
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), _ids([Charm.BROADBAND, Charm.BROADBAND]))
	var steps: Array = breakdown["charm_steps"]
	assert_eq(steps.size(), 2)
	assert_eq(steps[0]["charm_indices"], [0])
	assert_eq(steps[0]["base_add"], 10)
	assert_eq(steps[1]["charm_indices"], [1])
	assert_eq(steps[1]["base_add"], 10)

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

func test_crit_pool_is_one_shared_step():
	var levels := {DiceScoring.TWO_KIND: 2}
	var ids := _ids([Charm.GALLOWS_HUMOR, Charm.RESTAURANT_CRITIC])
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), ids, false, NO_MATS, NO_MATS, levels, {"after_farkle": true})
	var crit_steps: Array = breakdown["charm_steps"].filter(func(s: Dictionary) -> bool: return s["mult_x"] > 1)
	assert_eq(crit_steps.size(), 1, "ein gemeinsamer Krit-Schritt")
	assert_eq(crit_steps[0]["mult_x"], 8, "×(1 + 3 + 4)")
	assert_eq(crit_steps[0]["charm_indices"], [0, 1], "beide Krit-Quellen blinken")

# --- Nach-Schritte (auf die fertige Punktzahl) ------------------------------------

func test_rainbow_trout_lands_after_the_merge():
	var breakdown := _build_and_check(DiceScoring.SMALL_STRAIGHT, _d([1, 2, 3, 4, 5, 5]), _ids([Charm.RAINBOW_TROUT]))
	var posts: Array = breakdown["post_steps"]
	assert_eq(posts.size(), 1)
	assert_eq(posts[0]["total_add"], 10)
	assert_eq(posts[0]["charm_indices"], [0])

func test_magic_card_and_beer_are_total_factors():
	var ids := _ids([Charm.MAGIC_CARD, Charm.AFTER_WORK_BEER])
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), ids, true, NO_MATS, NO_MATS, {}, {"last_hand": true})
	var posts: Array = breakdown["post_steps"]
	assert_eq(posts.size(), 2)
	assert_eq(posts[0]["total_x"], 2.0, "Zauberkarte zuerst (Reihenfolge wie score_category)")
	assert_eq(posts[0]["charm_indices"], [0])
	assert_eq(posts[1]["total_x"], 2.0, "Feierabendbier auf das Ergebnis")
	assert_eq(posts[1]["charm_indices"], [1])

# --- Großer Kombinationstest: alles gleichzeitig -----------------------------------

func test_kitchen_sink_scenario_matches_scoring():
	# Materialien + Augen-Charm + additive Charms + Einserkult + Krit + Totem-
	# aufgelöste ids + Menü-Stufen + Kontext: die Zerlegung muss exakt bleiben.
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
