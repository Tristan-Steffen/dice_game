extends GutTest
## Tier-1-Tests der Seiten-Material-Wirkung (MaterialEffects) und ihrer
## Einrechnung in DiceScoring. Materialien wirken NUR auf beteiligte Seiten
## (participating) - genau die Seiten, die auch den Basiswert stellen.

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

# --- base_bonus (Bernstein / Quecksilber) --------------------------------------

func test_amber_adds_twenty_to_base():
	var bonus := MaterialEffects.base_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.AMBER, "", "", "", "", ""]), _p([0, 1]), NO_CHARMS)
	assert_eq(bonus, 20)

func test_mercury_counts_the_face_a_second_time():
	var bonus := MaterialEffects.base_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.MERCURY, "", "", "", "", ""]), _p([0, 1]), NO_CHARMS)
	assert_eq(bonus, 5, "die 5 zählt ein zweites Mal")

func test_mercury_stacks_with_charm_retriggers():
	# Hasenpfote +1 Auslösung auf jede 6, Quecksilber ×2 auf dem Träger:
	# Würfel 0 zählt 3× (2 Extra à 6), Würfel 1 zählt 2× (1 Extra à 6).
	var bonus := MaterialEffects.base_bonus(_d([6, 6, 1, 2, 3, 4]), _m([DieMaterial.MERCURY, "", "", "", "", ""]), _p([0, 1]), _ids([Charm.RABBITS_FOOT]))
	assert_eq(bonus, 18)

func test_base_bonus_ignores_non_participating_faces():
	var bonus := MaterialEffects.base_bonus(_d([5, 5, 1, 2, 3, 4]), _m(["", "", DieMaterial.AMBER, "", "", ""]), _p([0, 1]), NO_CHARMS)
	assert_eq(bonus, 0, "Bernstein außerhalb der Kombination wirkt nicht")

# --- mult_bonus (Rubin / Glas) ---------------------------------------------------

func test_ruby_adds_four_mult():
	var bonus := MaterialEffects.mult_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.RUBY, "", "", "", "", ""]), _p([0, 1]))
	assert_eq(bonus, 4)

func test_glass_adds_face_eyes_to_mult():
	var bonus := MaterialEffects.mult_bonus(_d([5, 5, 1, 2, 3, 4]), _m(["", DieMaterial.GLASS, "", "", "", ""]), _p([0, 1]))
	assert_eq(bonus, 5, "Glas: Mult += Augen der Seite")

func test_mult_bonus_ignores_non_participating_faces():
	var bonus := MaterialEffects.mult_bonus(_d([5, 5, 1, 2, 3, 4]), _m(["", "", "", "", "", DieMaterial.RUBY]), _p([0, 1]))
	assert_eq(bonus, 0)

func test_multiple_materials_stack():
	var bonus := MaterialEffects.mult_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.RUBY, DieMaterial.GLASS, "", "", "", ""]), _p([0, 1]))
	assert_eq(bonus, 9, "Rubin +4 und Glas +5 stapeln sich")

# --- apply_take_effects (Gold / Knochen / Glas) ----------------------------------

func _die(faces: Array, materials: Array = [], upgraded_faces: Array = []) -> DieDefinition:
	var def := DieDefinition.new()
	var typed_faces: Array[int] = []
	typed_faces.assign(faces)
	def.faces = typed_faces
	if not materials.is_empty():
		var typed_materials: Array[String] = []
		typed_materials.assign(materials)
		def.materials = typed_materials
	for face in upgraded_faces:
		def.upgraded[face] = true
	return def

func test_gold_pays_three_per_participating_face():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m([DieMaterial.GOLD, DieMaterial.GOLD]), _p([0, 1]))
	assert_eq(report.money, 6, "$3 je beteiligter Gold-Seite")
	assert_eq(defs[0].faces[0], 5, "Gold verändert die Seite nicht")

func test_gold_pays_twice_on_a_retriggered_six():
	# Hasenpfote löst die 6 erneut aus - wie Quecksilber inklusive Nehmen-Effekte.
	var defs: Array[DieDefinition] = [_die([6, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]), _m([]), _ids([Charm.RABBITS_FOOT]))
	assert_eq(report.money, 6, "Gold-Seite feuert je Auslösung")

func test_take_retrigger_checks_the_transformed_value():
	# Glückszigaretten: die 1 IST eine 6 - Hasenpfote löst auch sie erneut aus.
	var defs: Array[DieDefinition] = [_die([1, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]), _m([]),
		_ids([Charm.RABBITS_FOOT, Charm.LUCKY_CIGARETTES]))
	assert_eq(report.money, 6, "zwei Auslösungen à $3")

func test_gold_vein_pays_extra_per_other_carrier():
	# Zwei Gold-Seiten + eine Rubin-Seite: jeder Gold-Träger sieht einen anderen
	# Gold-Träger ($3) und einen anderen Material-Träger ($1) -> $3 + $4 je Seite.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6])]
	var faces := _m([DieMaterial.GOLD, DieMaterial.GOLD, DieMaterial.RUBY])
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0, 0]), faces, _p([0, 1, 2]),
		_m([]), _ids([Charm.GOLD_VEIN]))
	assert_eq(report.money, 14, "2 × ($3 Gold + $3 anderes Gold + $1 Rubin)")

func test_gold_vein_counts_edges_as_carriers():
	# Einzelne Gold-Seite, dazu eine Gold-KANTE am selben Würfel: beide lösen aus
	# und sehen jeweils den anderen Träger.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]),
		_m([DieMaterial.GOLD]), _ids([Charm.GOLD_VEIN]))
	assert_eq(report.money, 12, "Seite und Kante je $3 + $3")

func test_gold_vein_without_other_carriers_pays_the_plain_rate():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]),
		_m([]), _ids([Charm.GOLD_VEIN]))
	assert_eq(report.money, 3, "allein bleibt Gold bei $3")

func test_bone_grows_the_face_permanently():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]))
	assert_eq(defs[0].faces[0], 6, "Knochen: Seite +1")
	assert_eq(report.grown, [0])

func test_glass_shrinks_the_face_permanently():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]))
	assert_eq(defs[0].faces[0], 4, "Glas: Seite −1")
	assert_eq(report.shrunk, [0])

func test_glass_never_shrinks_below_one():
	var defs: Array[DieDefinition] = [_die([1, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]))
	assert_eq(defs[0].faces[0], 1, "eine 1 schrumpft nicht weiter")
	assert_eq(report.shrunk.size(), 0)

func test_take_effects_ignore_non_participating_faces():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m([DieMaterial.GOLD, DieMaterial.BONE]), _p([0]))
	assert_eq(report.money, 3, "nur die beteiligte Gold-Seite zahlt")
	assert_eq(defs[1].faces[0], 5, "unbeteiligter Knochen wächst nicht")

# --- Einrechnung in DiceScoring ---------------------------------------------------

func test_ruby_raises_pair_score():
	# Paar Fünfer: Basis (10 Punkte + 10 Augen), Mult 2 -> 40.
	# Mit Rubin auf einer Paar-Seite: Mult 6 -> 120.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var plain: int = DiceScoring.best_hand(dice)["score"]
	var with_ruby: int = DiceScoring.best_hand(dice, NO_CHARMS, false, _m([DieMaterial.RUBY, "", "", "", "", ""]))["score"]
	assert_eq(plain, 40)
	assert_eq(with_ruby, 120, "(10+5+5) × (2+4)")

func test_ruby_outside_combo_changes_nothing():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var score: int = DiceScoring.best_hand(dice, NO_CHARMS, false, _m(["", "", DieMaterial.RUBY, "", "", ""]))["score"]
	assert_eq(score, 40, "Rubin auf der 1 (unbeteiligt) wirkt nicht")

func test_amber_raises_base_of_pair():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var score: int = DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, _m([DieMaterial.AMBER, "", "", "", "", ""]))
	assert_eq(score, 80, "(10+5+5+20) × 2")

func test_mercury_double_counts_in_pair():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var score: int = DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, _m([DieMaterial.MERCURY, "", "", "", "", ""]))
	assert_eq(score, 50, "(10+5+5+5) × 2")

func test_best_hand_mult_field_includes_material_bonus():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var hand := DiceScoring.best_hand(dice, NO_CHARMS, false, _m([DieMaterial.RUBY, "", "", "", "", ""]))
	assert_eq(hand["mult"], 6, "angezeigter Mult = 2 (Paar) + 4 (Rubin)")

func test_empty_materials_score_unchanged():
	var dice := _d([5, 5, 1, 2, 3, 6])
	assert_eq(DiceScoring.best_hand(dice, NO_CHARMS, false, _m(["", "", "", "", "", ""]))["score"],
		DiceScoring.best_hand(dice)["score"], "lauter leere Materialien = wie ohne")

func test_is_strictly_better_ignores_materials():
	# Der Farkle-Vergleich läuft allein über den RANG - ein Rubin macht die Hand
	# punktreicher, aber nicht ranghöher.
	var same := _d([5, 5, 1, 2, 3, 6])
	var ruby_first := _m([DieMaterial.RUBY, "", "", "", "", ""])
	var none := _m(["", "", "", "", "", ""])
	assert_false(DiceScoring.is_strictly_better(same, same, NO_CHARMS, ruby_first, none),
		"gleicher Rang bleibt Farkle, auch mit Rubin im neuen Wurf")
	assert_false(DiceScoring.is_strictly_better(same, same, NO_CHARMS, none, ruby_first))

# --- Randfälle & Stapelung über Effekt-Arten hinweg ------------------------------

func test_none_and_unknown_materials_have_no_effect():
	var vals := _d([5, 5, 1, 2, 3, 4])
	var part := _p([0, 1])
	assert_eq(MaterialEffects.base_bonus(vals, _m(["", "", "", "", "", ""]), part, NO_CHARMS), 0)
	assert_eq(MaterialEffects.mult_bonus(vals, _m([DieMaterial.NONE, DieMaterial.NONE, "", "", "", ""]), part), 0)
	# Eine unbekannte id (kein registriertes Material) wirkt ebenfalls nicht.
	assert_eq(MaterialEffects.mult_bonus(vals, _m(["chisel", "", "", "", "", ""]), part), 0,
		"Ätzungs-/Fremd-id ist kein Material")

func test_base_bonus_stacks_amber_and_mercury():
	# Bernstein (+20) und Quecksilber (+Augen) auf zwei beteiligten Seiten stapeln.
	var bonus := MaterialEffects.base_bonus(_d([5, 4, 1, 2, 3, 6]), _m([DieMaterial.AMBER, DieMaterial.MERCURY, "", "", "", ""]), _p([0, 1]), NO_CHARMS)
	assert_eq(bonus, 24, "Bernstein 20 + Quecksilber (4) = 24")

func test_multiple_amber_faces_each_add_twenty():
	var bonus := MaterialEffects.base_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.AMBER, DieMaterial.AMBER, "", "", "", ""]), _p([0, 1]), NO_CHARMS)
	assert_eq(bonus, 40, "zwei Bernstein-Seiten = 2 × 20")

func test_materials_shorter_than_values_are_safe():
	# materials kürzer als die beteiligten Indizes: der Guard überspringt still.
	var bonus := MaterialEffects.base_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.AMBER]), _p([0, 1]), NO_CHARMS)
	assert_eq(bonus, 20, "nur Slot 0 hat ein Material; Slot 1 wird übersprungen")
	var mult := MaterialEffects.mult_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.RUBY]), _p([0, 1]))
	assert_eq(mult, 4)

# --- apply_take_effects: weitere Randfälle ---------------------------------------

func test_bone_grows_without_upper_cap():
	# Knochen ist nach oben offen (wie Überzahlen) - eine 6 wächst zu 7.
	var defs: Array[DieDefinition] = [_die([6, 2, 3, 4, 5, 1])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]))
	assert_eq(defs[0].faces[0], 7, "Knochen kennt keine Obergrenze")

func test_take_effects_skip_unrolled_face():
	# face_indices[i] < 0 (Slot lag nicht oben / kein Wert) -> kein Effekt.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([-1]), _m([DieMaterial.GOLD]), _p([0]))
	assert_eq(report.money, 0, "ohne oben liegende Seite zahlt Gold nicht")
	assert_eq(defs[0].faces[0], 5)

func test_take_effects_combined_report_across_slots():
	# Gold + Knochen + Glas gleichzeitig auf drei beteiligten Seiten.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0, 0]), _m([DieMaterial.GOLD, DieMaterial.BONE, DieMaterial.GLASS]), _p([0, 1, 2]))
	assert_eq(report.money, 3, "eine Gold-Seite")
	assert_eq(report.grown, [1], "Slot 1 ist gewachsen")
	assert_eq(report.shrunk, [2], "Slot 2 ist geschrumpft")
	assert_eq(defs[1].faces[0], 6)
	assert_eq(defs[2].faces[0], 4)

func test_multiple_bone_faces_each_grow():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6]), _die([3, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m([DieMaterial.BONE, DieMaterial.BONE]), _p([0, 1]))
	assert_eq(report.grown, [0, 1])
	assert_eq(defs[0].faces[0], 6)
	assert_eq(defs[1].faces[0], 4)

# --- Glas: Mult fließt durch best_hand, abhängig vom aktuellen Seitenwert --------

func test_glass_mult_flows_through_best_hand():
	# Paar Sechser: Basis (10+12), Mult 2 -> 44. Glas auf einer Paar-Seite: Mult += 6.
	var dice := _d([6, 6, 1, 2, 3, 5])
	var glass_first := _m([DieMaterial.GLASS, "", "", "", "", ""])
	assert_eq(DiceScoring.best_hand(dice)["score"], 44)
	assert_eq(DiceScoring.best_hand(dice, NO_CHARMS, false, glass_first)["score"], 176, "(10+6+6) × (2+6)")

func test_glass_mult_scales_with_face_value():
	# Dieselbe Position, kleinerer Augenwert -> kleinerer Glas-Bonus.
	var high := MaterialEffects.mult_bonus(_d([6, 6, 1, 2, 3, 4]), _m([DieMaterial.GLASS, "", "", "", "", ""]), _p([0]))
	var low := MaterialEffects.mult_bonus(_d([2, 2, 1, 3, 4, 5]), _m([DieMaterial.GLASS, "", "", "", "", ""]), _p([0]))
	assert_eq(high, 6)
	assert_eq(low, 2, "Glas skaliert mit der Augenzahl der Seite")

# --- Kanten-Materialien (edge_materials: ganzer Würfel, siehe DieDefinition) -----

const NO_FACE_MATS: Array[String] = ["", "", "", "", "", ""]

func test_amber_edge_adds_twenty():
	var bonus := MaterialEffects.base_bonus(_d([5, 5, 1, 2, 3, 4]), _m(NO_FACE_MATS), _p([0, 1]), NO_CHARMS, _m([DieMaterial.AMBER, "", "", "", "", ""]))
	assert_eq(bonus, 20, "Bernstein-Kanten wirken egal, welche Seite oben liegt")

func test_amber_face_and_edge_stack():
	var bonus := MaterialEffects.base_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.AMBER, "", "", "", "", ""]), _p([0, 1]), NO_CHARMS, _m([DieMaterial.AMBER, "", "", "", "", ""]))
	assert_eq(bonus, 40, "Seite +20 und Kanten +20 stapeln")

func test_mercury_edge_counts_die_twice():
	var bonus := MaterialEffects.base_bonus(_d([5, 5, 1, 2, 3, 4]), _m(NO_FACE_MATS), _p([0, 1]), NO_CHARMS, _m([DieMaterial.MERCURY, "", "", "", "", ""]))
	assert_eq(bonus, 5, "Quecksilber-Kanten: der Würfel zählt ein zweites Mal")

func test_mercury_face_plus_edge_counts_four_times():
	# DER Spezialfall aus dem Design: Quecksilber-Kanten UND Quecksilber-Seite
	# oben -> der Würfel zählt vierfach (Bonus = 3× der Wert zusätzlich zur Basis).
	var bonus := MaterialEffects.base_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.MERCURY, "", "", "", "", ""]), _p([0, 1]), NO_CHARMS, _m([DieMaterial.MERCURY, "", "", "", "", ""]))
	assert_eq(bonus, 15, "vierfach = Basis (5) + Bonus 3×5")

func test_ruby_edge_adds_mult():
	var bonus := MaterialEffects.mult_bonus(_d([5, 5, 1, 2, 3, 4]), _m(NO_FACE_MATS), _p([0, 1]), _m([DieMaterial.RUBY, "", "", "", "", ""]))
	assert_eq(bonus, 4)

func test_glass_edge_adds_up_face_eyes_to_mult():
	var bonus := MaterialEffects.mult_bonus(_d([5, 5, 1, 2, 3, 4]), _m(NO_FACE_MATS), _p([0, 1]), _m(["", DieMaterial.GLASS, "", "", "", ""]))
	assert_eq(bonus, 5, "Glas-Kanten: Mult += Augen der oben liegenden Seite")

func test_edge_materials_ignore_non_participating_dice():
	var bonus := MaterialEffects.mult_bonus(_d([5, 5, 1, 2, 3, 4]), _m(NO_FACE_MATS), _p([0, 1]), _m(["", "", DieMaterial.RUBY, "", "", ""]))
	assert_eq(bonus, 0, "Kanten wirken nur, wenn der Würfel in der Kombination liegt")

func test_bone_edge_grows_the_up_face():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([""]), _p([0]), _m([DieMaterial.BONE]))
	assert_eq(defs[0].faces[0], 6, "Knochen-Kanten: die oben liegende Seite wächst")
	assert_eq(report.grown, [0])

func test_bone_face_and_edge_grow_twice():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6], [DieMaterial.BONE, "", "", "", "", ""])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]), _m([DieMaterial.BONE]))
	assert_eq(defs[0].faces[0], 7, "Knochen-Seite +1 und Knochen-Kanten +1")
	assert_eq(report.grown, [0], "trotzdem nur ein Eintrag je Slot")

func test_glass_edge_shrinks_and_respects_minimum():
	var defs: Array[DieDefinition] = [_die([2, 2, 3, 4, 5, 6])]
	# Glas-Seite UND Glas-Kanten: zwei Schrumpf-Schritte, aber nie unter 1.
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]), _m([DieMaterial.GLASS]))
	assert_eq(defs[0].faces[0], 1, "2 − 2 wäre 0, geklemmt auf 1")
	assert_eq(report.shrunk, [0])

func test_gold_edge_pays_on_take():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([""]), _p([0]), _m([DieMaterial.GOLD]))
	assert_eq(report.money, 3, "Gold-Kanten zahlen beim Nehmen, wie die Gold-Seite")

func test_gold_edge_stays_quiet_for_uncounted_dice():
	# Kein Wurf-Einkommen mehr: nur die genommene Kombination zahlt.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6])]
	var edges := _m([DieMaterial.GOLD, DieMaterial.GOLD])
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m(["", ""]), _p([0]), edges)
	assert_eq(report.money, 3, "nur der beteiligte Würfel zahlt")

func test_gold_edge_and_face_stack_on_the_same_die():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]), _m([DieMaterial.GOLD]))
	assert_eq(report.money, 6, "Seite $3 + Kante $3")

func test_edge_materials_flow_through_best_hand():
	# Paar Fünfer: Basis (10+10), Mult 2 -> 40. Rubin-Kanten auf einem Paar-Würfel:
	# Mult 6 -> 120 - unabhängig davon, welche Seite oben liegt.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var score: int = DiceScoring.best_hand(dice, NO_CHARMS, false, _m(NO_FACE_MATS), _m([DieMaterial.RUBY, "", "", "", "", ""]))["score"]
	assert_eq(score, 120, "(10+5+5) × (2+4) über Kanten-Rubin")

func test_is_strictly_better_ignores_edge_materials():
	# Wie die Seiten-Materialien: sie zahlen mehr, heben aber keinen Rang.
	var same := _d([5, 5, 1, 2, 3, 6])
	var ruby_edges := _m([DieMaterial.RUBY, "", "", "", "", ""])
	var none := _m(["", "", "", "", "", ""])
	assert_false(DiceScoring.is_strictly_better(same, same, NO_CHARMS, none, none, ruby_edges, none))

# --- Quecksilber als Retrigger: der Würfel aktiviert sich doppelt -----------------
# Jede Aktivierung zählt die Augen UND feuert die übrigen Material-Effekte des
# Würfels erneut (siehe MaterialEffects.activation_count).

func test_activation_count_doubles_per_mercury_carrier():
	var mercury_first := _m([DieMaterial.MERCURY, "", "", "", "", ""])
	var none := _m(["", "", "", "", "", ""])
	assert_eq(MaterialEffects.activation_count(0, none, none, NO_CHARMS), 1)
	assert_eq(MaterialEffects.activation_count(0, mercury_first, none, NO_CHARMS), 2)
	assert_eq(MaterialEffects.activation_count(0, none, mercury_first, NO_CHARMS), 2)
	assert_eq(MaterialEffects.activation_count(0, mercury_first, mercury_first, NO_CHARMS), 4, "Seite × Kanten stapeln multiplikativ")

func test_mercury_edge_doubles_amber_face_on_same_die():
	# Bernstein-Seite (20) feuert je Aktivierung; Quecksilber-Kanten aktivieren
	# den Würfel doppelt: 2×20 + Augen (5) ein zweites Mal = 45.
	var bonus := MaterialEffects.base_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.AMBER, "", "", "", "", ""]), _p([0, 1]), NO_CHARMS, _m([DieMaterial.MERCURY, "", "", "", "", ""]))
	assert_eq(bonus, 45, "Bernstein 2×20 + zweite Augen-Zählung 5")

func test_mercury_edge_doubles_ruby_face_mult():
	var bonus := MaterialEffects.mult_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.RUBY, "", "", "", "", ""]), _p([0, 1]), _m([DieMaterial.MERCURY, "", "", "", "", ""]))
	assert_eq(bonus, 8, "Rubin +4 feuert zweimal")

func test_mercury_edge_doubles_glass_face_mult():
	var bonus := MaterialEffects.mult_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.GLASS, "", "", "", "", ""]), _p([0, 1]), _m([DieMaterial.MERCURY, "", "", "", "", ""]))
	assert_eq(bonus, 10, "Glas (+5 Augen) feuert zweimal")

func test_mercury_face_doubles_ruby_edge_mult():
	# Umgekehrte Träger: Quecksilber-SEITE oben, Rubin-KANTEN -> Rubin zweimal.
	var bonus := MaterialEffects.mult_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.MERCURY, "", "", "", "", ""]), _p([0, 1]), _m([DieMaterial.RUBY, "", "", "", "", ""]))
	assert_eq(bonus, 8, "Rubin-Kanten +4 feuern zweimal")

func test_mercury_edge_doubles_gold_face_payout():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]), _m([DieMaterial.MERCURY]))
	assert_eq(report.money, 6, "Gold-Seite zahlt je Aktivierung: 2 × $3")

func test_mercury_edge_doubles_bone_face_growth():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]), _m([DieMaterial.MERCURY]))
	assert_eq(defs[0].faces[0], 7, "Knochen wächst je Aktivierung: +1 zweimal")

func test_mercury_edge_doubles_glass_face_shrink():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]), _m([DieMaterial.MERCURY]))
	assert_eq(defs[0].faces[0], 3, "Glas schrumpft je Aktivierung: −1 zweimal")

func test_mercury_vapor_triples_activations_of_take_effects():
	# Quecksilberdampf: Quecksilber aktiviert dreifach -> Gold zahlt 3 × $3.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]), _m([DieMaterial.MERCURY]), _ids([Charm.MERCURY_VAPOR]))
	assert_eq(report.money, 9)

func test_mercury_retrigger_flows_through_best_hand():
	# Paar Fünfer, Slot 0 mit Rubin-Seite + Quecksilber-Kanten:
	# Basis (10+10) + zweite Augen-Zählung 5 = 25; Mult 2 + 2×4 (Rubin) = 10 -> 250.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var score: int = DiceScoring.best_hand(dice, NO_CHARMS, false, _m([DieMaterial.RUBY, "", "", "", "", ""]), _m([DieMaterial.MERCURY, "", "", "", "", ""]))["score"]
	assert_eq(score, 250, "(10+5+5+5) × (2+8)")

# --- Dotierung (Stufe II): ein gehobenes SEITEN-Material ------------------------
# Regel für alle sechs: der gehobene Träger ERSETZT den Grundwert und behält den
# Charm-Aufschlag über dem Grundwert (Bernsteinzimmer, Knochenleim, Dampf ...).

## Dotierungs-Infos eines Slots (Form wie DiceScoring.CTX_MATERIAL_UPGRADES).
func _up(slot: int, eye_sum := 0, mercury_faces := 0) -> Dictionary:
	return {slot: {"upgraded": true, "eye_sum": eye_sum, "mercury_faces": mercury_faces}}

func _ctx_up(slot: int, eye_sum := 0, mercury_faces := 0) -> Dictionary:
	return {DiceScoring.CTX_MATERIAL_UPGRADES: _up(slot, eye_sum, mercury_faces)}

# Bernstein II: +Augensumme statt +20.

func test_upgraded_amber_gives_the_eye_sum():
	assert_eq(MaterialEffects.base_once_for(DieMaterial.AMBER, "", NO_CHARMS, true, 21), 21)
	assert_eq(MaterialEffects.base_once_for(DieMaterial.AMBER, "", NO_CHARMS, false, 21), 20,
		"ohne Dotierung bleibt es beim Grundwert")

func test_upgraded_amber_keeps_the_amber_room_surplus():
	assert_eq(MaterialEffects.base_once_for(DieMaterial.AMBER, "", _ids([Charm.AMBER_ROOM]), true, 21), 51,
		"Augensumme 21 + Aufschlag (50 − 20)")

func test_upgraded_amber_flows_through_the_score():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m([DieMaterial.AMBER, "", "", "", "", ""])
	var score: int = DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, _m([]), {}, _ctx_up(0, 21))
	assert_eq(score, 82, "(10+5+5+21) × 2")

func test_upgraded_amber_leaves_the_edge_carrier_alone():
	# Kanten sind nie dotierbar - die Kante zahlt weiter ihre 20.
	assert_eq(MaterialEffects.base_once_for(DieMaterial.AMBER, DieMaterial.AMBER, NO_CHARMS, true, 21), 41)

# Rubin II: Krit ×4 statt +4 Mult.

func test_upgraded_ruby_crits_instead_of_adding():
	assert_eq(MaterialEffects.mult_once_for(DieMaterial.RUBY, "", 5, NO_CHARMS, true), 0)
	assert_eq(MaterialEffects.mult_crit_once_for(DieMaterial.RUBY, 5, NO_CHARMS, true), 4)
	assert_eq(MaterialEffects.mult_crit_once_for(DieMaterial.RUBY, 5, NO_CHARMS, false), 1, "undotiert kein Krit")

func test_upgraded_ruby_keeps_grinder_and_blood_diamond_additive():
	# Sonst würde der Aufschlag den Krit exponentiell machen.
	assert_eq(MaterialEffects.mult_once_for(DieMaterial.RUBY, "", 5, _ids([Charm.RUBY_GRINDER]), true), 5)
	assert_eq(MaterialEffects.mult_once_for(DieMaterial.RUBY, "", 5, _ids([Charm.RUBY_GRINDER, Charm.BLOOD_DIAMOND]), true), 10)
	assert_eq(MaterialEffects.mult_crit_once_for(DieMaterial.RUBY, 5, _ids([Charm.RUBY_GRINDER]), true), 4,
		"der Krit bleibt ×4")

func test_upgraded_ruby_flows_through_the_score():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m([DieMaterial.RUBY, "", "", "", "", ""])
	var score: int = DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, _m([]), {}, _ctx_up(0))
	assert_eq(score, 160, "20 × (2 ×4)")

# Glas II: Krit ×Augen statt +Augen; schrumpft um 5 bzw. 20 %.

func test_upgraded_glass_crits_with_its_eyes():
	assert_eq(MaterialEffects.mult_once_for(DieMaterial.GLASS, "", 5, NO_CHARMS, true), 0)
	assert_eq(MaterialEffects.mult_crit_once_for(DieMaterial.GLASS, 5, NO_CHARMS, true), 5)
	assert_eq(MaterialEffects.mult_crit_once_for(DieMaterial.GLASS, 0, NO_CHARMS, true), 1, "nie unter ×1")

func test_upgraded_glass_leaves_the_edge_carrier_additive():
	assert_eq(MaterialEffects.mult_once_for(DieMaterial.GLASS, DieMaterial.GLASS, 5, NO_CHARMS, true), 5,
		"nur die Seite kritet, die Kante addiert weiter")

## Eine Seite trägt genau EIN Material - also höchstens ein Material-Krit.
func test_only_the_face_carrier_can_crit():
	assert_eq(MaterialEffects.mult_crit_once_for("", 5, NO_CHARMS, true), 1)
	assert_eq(MaterialEffects.mult_crit_once_for(DieMaterial.AMBER, 5, NO_CHARMS, true), 1)

# Der Material-Krit schlägt an der Position SEINES Würfels ein.

func test_material_crit_fires_at_its_own_die_not_at_the_end():
	# Rubin II auf Slot 0 (Krit ×4), Glas auf Slot 1 (+5 Mult danach).
	# Feuerte der Krit erst am Ende, wäre es (2+5)×4 = 28 statt 13.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m([DieMaterial.RUBY, DieMaterial.GLASS, "", "", "", ""])
	var score: int = DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, _m([]), {}, _ctx_up(0))
	assert_eq(score, 260, "20 × (2 ×4 + 5)")

func test_material_crit_lands_before_beherit_on_the_same_die():
	# Slot 0: Mult 2 -> Material-Krit ×4 -> Beherit ×5 = 40, dann Glas +5 = 45.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m([DieMaterial.RUBY, DieMaterial.GLASS, "", "", "", ""])
	var score: int = DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([Charm.BEHERIT]), false, mats, _m([]), {}, _ctx_up(0))
	assert_eq(score, 900, "20 × 45")

func test_breakdown_mirrors_the_material_crit():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m([DieMaterial.RUBY, DieMaterial.GLASS, "", "", "", ""])
	var ctx := _ctx_up(0)
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, _m([]), {}, ctx)
	assert_eq(int(breakdown["total"]), DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, _m([]), {}, ctx))
	var first_step: Dictionary = breakdown["die_steps"][0]
	assert_eq(int(first_step["crit_x"]), 4, "der Material-Krit steht im Schritt")
	assert_eq((first_step["crit_charm_indices"] as Array).size(), 0, "kein Charm-Index dafür")
	var activation: Dictionary = (first_step["activations"] as Array)[0]
	assert_true(bool(activation["crit_from_die"]), "der Strahl kommt vom Würfel, nicht vom Dock-Pad")

# Quecksilber II: so oft, wie der Würfel Quecksilber-Seiten hat, +1.

func test_upgraded_mercury_counts_the_dies_mercury_faces():
	var mercury_first := _m([DieMaterial.MERCURY, "", "", "", "", ""])
	var none := _m(["", "", "", "", "", ""])
	assert_eq(MaterialEffects.activation_count(0, mercury_first, none, NO_CHARMS, 5, -1, true, 3), 4)
	assert_eq(MaterialEffects.activation_count(0, mercury_first, none, NO_CHARMS, 5, -1, true, 1), 2,
		"eine einzige Quecksilber-Seite bleibt bei doppelt")
	assert_eq(MaterialEffects.activation_count(0, mercury_first, none, NO_CHARMS, 5, -1, false, 3), 2,
		"undotiert bleibt es beim festen ×2")

func test_upgraded_mercury_keeps_the_vapor_surplus():
	var mercury_first := _m([DieMaterial.MERCURY, "", "", "", "", ""])
	var none := _m(["", "", "", "", "", ""])
	assert_eq(MaterialEffects.activation_count(0, mercury_first, none, _ids([Charm.MERCURY_VAPOR]), 5, -1, true, 3), 5,
		"3 Seiten + 1, dazu der Dampf-Aufschlag (+1)")

func test_upgraded_mercury_still_stacks_with_the_edge():
	var mercury_first := _m([DieMaterial.MERCURY, "", "", "", "", ""])
	assert_eq(MaterialEffects.activation_count(0, mercury_first, mercury_first, NO_CHARMS, 5, -1, true, 3), 8,
		"Seite (×4) und Kante (×2) stapeln multiplikativ")

func test_upgraded_mercury_flows_through_the_score():
	# Paar Fünfer, Slot 0 löst 4× aus: Basis 10 + 5×4 + 5 = 35, Mult 2 -> 70.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m([DieMaterial.MERCURY, "", "", "", "", ""])
	var ctx := {DiceScoring.CTX_MATERIAL_UPGRADES: _up(0, 21, 3)}
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, _m([]), {}, ctx), 70)

# Gold II: $5 + $1 je ausgelöster Gold-SEITE dieser Nahme.

func test_upgraded_gold_pays_five_plus_one_per_gold_face():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6], [], [0])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]))
	assert_eq(report.money, 6, "$5 + $1 für die eigene Auslösung")

func test_upgraded_gold_counts_every_gold_face_of_the_take():
	# Drei Gold-Seiten, davon eine dotiert: der Zähler steht bei 3.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6], [], [0]), _die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6])]
	var gold := _m([DieMaterial.GOLD, DieMaterial.GOLD, DieMaterial.GOLD])
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0, 0]), gold, _p([0, 1, 2]))
	assert_eq(report.money, 14, "($5+$3) + $3 + $3")

func test_upgraded_gold_counts_activations_not_carriers():
	# Quecksilber-Kanten verdoppeln die Auslösung: Zähler 2, Satz $7, zweimal.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6], [], [0])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]), _m([DieMaterial.MERCURY]))
	assert_eq(report.money, 14, "2 × ($5 + $2)")

func test_upgraded_gold_keeps_the_goldsmith_surplus():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6], [], [0])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]), _m([]), _ids([Charm.GOLDSMITH]))
	assert_eq(report.money, 9, "$5 + $1 Zähler + $3 Aufschlag")

func test_upgraded_gold_edge_stays_at_the_plain_rate():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6], [], [0])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([""]), _p([0]), _m([DieMaterial.GOLD]))
	assert_eq(report.money, 3, "die Kante ist nie dotiert")

# Knochen II: +3 oder +10 %, je Aktivierung neu gerechnet.

func test_upgraded_bone_grows_by_at_least_three():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6], [], [0])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]))
	assert_eq(defs[0].faces[0], 8, "10 % von 5 sind zu wenig - es bleibt bei +3")
	assert_eq(report.grown, [0])

func test_upgraded_bone_compounds_per_activation():
	# 40 -> +4 = 44 -> +ceil(4,4) = 5 -> 49: die zweite Auslösung rechnet neu.
	var defs: Array[DieDefinition] = [_die([40, 2, 3, 4, 5, 6], [], [0])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]), _m([DieMaterial.MERCURY]))
	assert_eq(defs[0].faces[0], 49)

func test_upgraded_bone_keeps_the_glue_surplus():
	# Knochenleim (Satz 2) = Aufschlag +1 über den Dotierungs-Schritt (+3).
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6], [], [0])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]), _m([]),
		_ids([Charm.BONE_GLUE]))
	assert_eq(defs[0].faces[0], 9, "+3 (Dotierung) +1 (Aufschlag)")

func test_upgraded_bone_compounds_per_marrow_trigger():
	# Knochenmark gibt eine zweite Auslösung; die rechnet ihren Schritt am schon
	# gewachsenen Wert neu (5 -> +4 = 9 -> +4 = 13), nie 2 × derselbe Schritt.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6], [], [0])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]), _m([]),
		_ids([Charm.BONE_GLUE, Charm.BONE_MARROW]))
	assert_eq(defs[0].faces[0], 13)

# Glas II: −5 oder −20 %, nie unter das Floor.

func test_upgraded_glass_shrinks_by_a_fifth():
	var defs: Array[DieDefinition] = [_die([40, 2, 3, 4, 5, 6], [], [0])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]))
	assert_eq(defs[0].faces[0], 32, "20 % von 40 sind 8")
	assert_eq(report.shrunk, [0])

func test_upgraded_glass_shrinks_at_least_five():
	var defs: Array[DieDefinition] = [_die([12, 2, 3, 4, 5, 6], [], [0])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]))
	assert_eq(defs[0].faces[0], 7, "20 % von 12 wären 3 - der Mindestschritt greift")

func test_upgraded_glass_stops_at_the_floor():
	var defs: Array[DieDefinition] = [_die([3, 2, 3, 4, 5, 6], [], [0])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]))
	assert_eq(defs[0].faces[0], EtchingEffects.MIN_FACE_VALUE, "3 − 5 wäre negativ, geklemmt")
	assert_eq(report.shrunk, [0])

func test_upgraded_glass_shrinks_to_the_lungs_floor():
	# Die Glasbläserlunge hebt nur den Boden: der Prozent-Schritt läuft weiter.
	var defs: Array[DieDefinition] = [_die([40, 2, 3, 4, 5, 6], [], [0])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]), _m([]),
		_ids([Charm.GLASSBLOWER_LUNG]))
	assert_eq(defs[0].faces[0], 32, "20 % von 40 sind 8 - auch mit Lunge")
	assert_eq(report.shrunk, [0])
	var low: Array[DieDefinition] = [_die([8, 2, 3, 4, 5, 6], [], [0])]
	var low_report := MaterialEffects.apply_take_effects(low, _p([0]), _m([DieMaterial.GLASS]), _p([0]), _m([]),
		_ids([Charm.GLASSBLOWER_LUNG]))
	assert_eq(low[0].faces[0], MaterialEffects.GLASSBLOWER_LUNG_FLOOR, "8 − 5 wäre 3, geklemmt auf 6")
	assert_eq(low_report.shrunk, [0])

# --- Datensatz: die Marke gehört dem Würfel, nicht der geteilten Vorlage --------

func test_instantiate_and_become_copy_the_upgrade_marks():
	var def := _die([5, 2, 3, 4, 5, 6], [], [2])
	var copy := def.instantiate()
	assert_true(copy.upgraded[2])
	copy.upgraded[2] = false
	assert_true(def.upgraded[2], "die Kopie teilt das Array nicht")
	var host := DieDefinition.new()
	host.become(def)
	assert_true(host.upgraded[2])
	host.upgraded[2] = false
	assert_true(def.upgraded[2], "become teilt das Array nicht")

func test_a_fresh_definition_has_no_upgrades():
	assert_eq(DieDefinition.new().upgraded, [false, false, false, false, false, false] as Array[bool])

# --- set_face_material: EINZIGER Schreibweg, löscht die Dotierung mit -----------

func test_set_face_material_clears_the_doping():
	var def := _die([5, 2, 3, 4, 5, 6], [DieMaterial.RUBY, "", "", "", "", ""], [0])
	assert_true(def.upgraded[0])
	def.set_face_material(0, DieMaterial.GOLD)
	assert_eq(def.materials[0], DieMaterial.GOLD)
	assert_false(def.upgraded[0], "die Marke hängt am Material, nicht an der Seite")

func test_set_face_material_leaves_other_faces_alone():
	var def := _die([5, 2, 3, 4, 5, 6], [DieMaterial.RUBY, DieMaterial.GOLD, "", "", "", ""], [0, 1])
	def.set_face_material(0, DieMaterial.AMBER)
	assert_true(def.upgraded[1], "die Nachbarseite behält ihre Dotierung")

func test_set_face_material_ignores_faces_out_of_range():
	var def := _die([5, 2, 3, 4, 5, 6])
	def.set_face_material(-1, DieMaterial.GOLD)
	def.set_face_material(9, DieMaterial.GOLD)
	assert_eq(def.materials, _m(["", "", "", "", "", ""]), "nichts geschrieben")
