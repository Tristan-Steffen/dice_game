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

func test_mercury_respects_charm_eye_values():
	# Hasenpfote: jede 6 zählt doppelt - Quecksilber zählt den ANGEPASSTEN Wert nach.
	var bonus := MaterialEffects.base_bonus(_d([6, 6, 1, 2, 3, 4]), _m([DieMaterial.MERCURY, "", "", "", "", ""]), _p([0, 1]), _ids([Charm.RABBITS_FOOT]))
	assert_eq(bonus, 12, "6 zählt mit Hasenpfote als 12 - auch beim Nachzählen")

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

func _die(faces: Array, materials: Array = []) -> DieDefinition:
	var def := DieDefinition.new()
	var typed_faces: Array[int] = []
	typed_faces.assign(faces)
	def.faces = typed_faces
	if not materials.is_empty():
		var typed_materials: Array[String] = []
		typed_materials.assign(materials)
		def.materials = typed_materials
	return def

func test_gold_pays_one_per_participating_face():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m([DieMaterial.GOLD, DieMaterial.GOLD]), _p([0, 1]))
	assert_eq(report.money, 2, "$1 je beteiligter Gold-Seite")
	assert_eq(defs[0].faces[0], 5, "Gold verändert die Seite nicht")

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
	assert_eq(report.money, 1, "nur die beteiligte Gold-Seite zahlt")
	assert_eq(defs[1].faces[0], 5, "unbeteiligter Knochen wächst nicht")

# --- Einrechnung in DiceScoring ---------------------------------------------------

func test_ruby_raises_pair_score():
	# Paar Fünfer: Basis 10, Mult 2 -> 20. Mit Rubin auf einer Paar-Seite: Mult 6 -> 60.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var plain: int = DiceScoring.best_hand(dice)["score"]
	var with_ruby: int = DiceScoring.best_hand(dice, NO_CHARMS, false, _m([DieMaterial.RUBY, "", "", "", "", ""]))["score"]
	assert_eq(plain, 20)
	assert_eq(with_ruby, 60, "(5+5) × (2+4)")

func test_ruby_outside_combo_changes_nothing():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var score: int = DiceScoring.best_hand(dice, NO_CHARMS, false, _m(["", "", DieMaterial.RUBY, "", "", ""]))["score"]
	assert_eq(score, 20, "Rubin auf der 1 (unbeteiligt) wirkt nicht")

func test_amber_raises_base_of_pair():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var score: int = DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, _m([DieMaterial.AMBER, "", "", "", "", ""]))
	assert_eq(score, 60, "(5+5+20) × 2")

func test_mercury_double_counts_in_pair():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var score: int = DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, _m([DieMaterial.MERCURY, "", "", "", "", ""]))
	assert_eq(score, 30, "(5+5+5) × 2")

func test_best_hand_mult_field_includes_material_bonus():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var hand := DiceScoring.best_hand(dice, NO_CHARMS, false, _m([DieMaterial.RUBY, "", "", "", "", ""]))
	assert_eq(hand["mult"], 6, "angezeigter Mult = 2 (Paar) + 4 (Rubin)")

func test_empty_materials_score_unchanged():
	var dice := _d([5, 5, 1, 2, 3, 6])
	assert_eq(DiceScoring.best_hand(dice, NO_CHARMS, false, _m(["", "", "", "", "", ""]))["score"],
		DiceScoring.best_hand(dice)["score"], "lauter leere Materialien = wie ohne")

func test_is_strictly_better_uses_materials_on_both_sides():
	# Gleiche Werte: ohne Materialien wäre der neue Wurf NICHT strikt besser.
	var old_dice := _d([5, 5, 1, 2, 3, 6])
	var new_dice := _d([5, 5, 1, 2, 3, 6])
	var ruby_first := _m([DieMaterial.RUBY, "", "", "", "", ""])
	var none := _m(["", "", "", "", "", ""])
	assert_true(DiceScoring.is_strictly_better(new_dice, old_dice, NO_CHARMS, ruby_first, none),
		"Rubin im neuen Wurf macht ihn strikt besser")
	assert_false(DiceScoring.is_strictly_better(new_dice, old_dice, NO_CHARMS, none, ruby_first),
		"Rubin im alten Wurf: der neue ist schlechter")

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
	assert_eq(report.money, 1, "eine Gold-Seite")
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
	# Paar Sechser: Basis 12, Mult 2 -> 24. Glas auf einer Paar-Seite: Mult += 6.
	var dice := _d([6, 6, 1, 2, 3, 5])
	var glass_first := _m([DieMaterial.GLASS, "", "", "", "", ""])
	assert_eq(DiceScoring.best_hand(dice)["score"], 24)
	assert_eq(DiceScoring.best_hand(dice, NO_CHARMS, false, glass_first)["score"], 96, "(6+6) × (2+6)")

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

func test_gold_edge_does_not_pay_on_take():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([""]), _p([0]), _m([DieMaterial.GOLD]))
	assert_eq(report.money, 0, "Gold-Kanten zahlen je Wurf (roll_money), nicht beim Nehmen")

func test_roll_money_pays_per_thrown_gold_edge():
	var edges := _m([DieMaterial.GOLD, "", DieMaterial.GOLD, DieMaterial.RUBY, "", DieMaterial.GOLD])
	assert_eq(MaterialEffects.roll_money(edges, _p([0, 1, 2, 3, 4, 5])), 3, "$1 je geworfenem Gold-Kanten-Würfel")
	assert_eq(MaterialEffects.roll_money(edges, _p([0, 1])), 1, "geschützte (nicht geworfene) Würfel zahlen nicht")
	assert_eq(MaterialEffects.roll_money(_m(["", "", "", "", "", ""]), _p([0, 1, 2, 3, 4, 5])), 0)

func test_edge_materials_flow_through_best_hand():
	# Paar Fünfer: Basis 10, Mult 2 -> 20. Rubin-Kanten auf einem Paar-Würfel:
	# Mult 6 -> 60 - unabhängig davon, welche Seite oben liegt.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var score: int = DiceScoring.best_hand(dice, NO_CHARMS, false, _m(NO_FACE_MATS), _m([DieMaterial.RUBY, "", "", "", "", ""]))["score"]
	assert_eq(score, 60, "(5+5) × (2+4) über Kanten-Rubin")

func test_is_strictly_better_sees_edge_materials():
	var same := _d([5, 5, 1, 2, 3, 6])
	var ruby_edges := _m([DieMaterial.RUBY, "", "", "", "", ""])
	var none := _m(["", "", "", "", "", ""])
	assert_true(DiceScoring.is_strictly_better(same, same, NO_CHARMS, none, none, ruby_edges, none),
		"Rubin-Kanten im neuen Wurf machen ihn strikt besser")

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
	assert_eq(report.money, 2, "Gold-Seite zahlt je Aktivierung: 2 × $1")

func test_mercury_edge_doubles_bone_face_growth():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]), _m([DieMaterial.MERCURY]))
	assert_eq(defs[0].faces[0], 7, "Knochen wächst je Aktivierung: +1 zweimal")

func test_mercury_edge_doubles_glass_face_shrink():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]), _m([DieMaterial.MERCURY]))
	assert_eq(defs[0].faces[0], 3, "Glas schrumpft je Aktivierung: −1 zweimal")

func test_mercury_vapor_triples_activations_of_take_effects():
	# Quecksilberdampf: Quecksilber aktiviert dreifach -> Gold zahlt 3 × $1.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]), _m([DieMaterial.MERCURY]), _ids([Charm.MERCURY_VAPOR]))
	assert_eq(report.money, 3)

func test_mercury_retrigger_flows_through_best_hand():
	# Paar Fünfer, Slot 0 mit Rubin-Seite + Quecksilber-Kanten:
	# Basis 10 + zweite Augen-Zählung 5 = 15; Mult 2 + 2×4 (Rubin) = 10 -> 150.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var score: int = DiceScoring.best_hand(dice, NO_CHARMS, false, _m([DieMaterial.RUBY, "", "", "", "", ""]), _m([DieMaterial.MERCURY, "", "", "", "", ""]))["score"]
	assert_eq(score, 150, "(5+5+5) × (2+8)")
