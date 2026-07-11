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
