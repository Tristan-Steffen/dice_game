extends GutTest
## Tier-1-Tests der Seiten-Material-Wirkung (MaterialEffects) und ihrer
## Einrechnung in DiceScoring. Materialien wirken NUR auf beteiligte Seiten
## (participating) - genau die Seiten, die auch den Basiswert stellen.
## Seit dem Kanten-Umbau gibt es nur noch SEITEN-Materialien; was den Würfel
## mehrfach auslöst, ist Essenz-Land.

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

## ctx mit einer Argon-Seele auf slot - seit dem Kanten-Umbau die Standard-Quelle
## zweier Auslösungen (früher tat das die Quecksilber-Kante).
func _argon(slot: int) -> Dictionary:
	return {DiceScoring.CTX_ESSENCES: {slot: Essence.ARGON}}

## Würfel für die Nehmen-Tests; levels dotiert einzelne Seiten (Seite -> Zustand),
## jede andere Material-Seite bleibt normal.
func _die(faces: Array, materials: Array = [], levels: Dictionary = {}) -> DieDefinition:
	var def := DieDefinition.new()
	var typed_faces: Array[int] = []
	typed_faces.assign(faces)
	def.faces = typed_faces
	if not materials.is_empty():
		var typed_materials: Array[String] = []
		typed_materials.assign(materials)
		def.materials = typed_materials
	for i in def.materials.size():
		def.levels[i] = 0 if def.materials[i] == "" else 1
	for face: int in levels:
		def.levels[face] = int(levels[face])
	return def

# --- Die beiden Auslöse-Achsen ---------------------------------------------------
# Würfel-Trigger × Seiten-Trigger. Innerhalb einer Achse addiert alles, die
# Achsen multiplizieren sich - mehr Achsen gibt es nicht.

func test_the_two_axes_multiply():
	# Quecksilberdampf (×3 Würfel) × Nachglühen (+1 Seite) = 6 Zündungen.
	var die_axis := MaterialEffects.die_trigger_count(0, NO_CHARMS, -1, _ids([Essence.MERCURY_VAPOR]))
	var face_axis := MaterialEffects.face_trigger_count(5, NO_CHARMS, 1)
	assert_eq(die_axis, 3)
	assert_eq(face_axis, 2)
	assert_eq(MaterialEffects.total_trigger_count(0, NO_CHARMS, 5, -1,
		_ids([Essence.MERCURY_VAPOR]), false, 0, 1), 6)

func test_a_retrigger_charm_sits_on_the_face_axis():
	# Argon (×2 Würfel) × Hasenpfote auf der 6 (+1 Seite) = 4, nie 3.
	var ids := _ids([Charm.RABBITS_FOOT])
	assert_eq(MaterialEffects.face_trigger_count(6, ids), 2, "die Hasenpfote zählt die SEITE erneut")
	assert_eq(MaterialEffects.face_trigger_count(5, ids), 1, "nur auf der 6")
	assert_eq(MaterialEffects.total_trigger_count(0, ids, 6, -1, _ids([Essence.ARGON])), 4)

func test_the_echo_chamber_sits_on_the_die_axis():
	# Ohne Seele: die Echo-Kammer addiert einen ANTRITT, die Seiten-Achse bleibt 1.
	var ids := _ids([Charm.ECHO_CHAMBER])
	assert_eq(MaterialEffects.die_trigger_count(0, ids, 0), 2, "der Echo-Slot tritt zweimal an")
	assert_eq(MaterialEffects.die_trigger_count(1, ids, 0), 1, "jeder andere Slot einmal")
	assert_eq(MaterialEffects.face_trigger_count(5, ids), 1)
	assert_eq(MaterialEffects.total_trigger_count(0, ids, 5, 0), 2)

func test_both_axes_never_fall_below_one():
	assert_eq(MaterialEffects.die_trigger_count(0, NO_CHARMS, -1, _ids([]), false, -5), 1)
	assert_eq(MaterialEffects.face_trigger_count(5, NO_CHARMS, -5), 1)

func test_the_six_pack_sits_on_the_die_axis():
	# Volle Hand: JEDER Slot tritt einmal öfter an, nicht nur ein ausgezeichneter.
	var ids := _ids([Charm.SIX_PACK])
	assert_eq(MaterialEffects.die_trigger_count(0, ids, -1, _ids([]), false, 0, 6), 2)
	assert_eq(MaterialEffects.die_trigger_count(3, ids, -1, _ids([]), false, 0, 6), 2)
	assert_eq(MaterialEffects.die_trigger_count(0, ids, -1, _ids([]), false, 0, 5), 1, "fünf Würfel reichen nicht")
	assert_eq(MaterialEffects.face_trigger_count(5, ids), 1, "die Seiten-Achse bleibt unberührt")

func test_the_six_pack_stacks_and_multiplies_with_the_face_axis():
	# Zwei Exemplare addieren auf der Würfel-Achse; die Hasenpfote multipliziert.
	var double := _ids([Charm.SIX_PACK, Charm.SIX_PACK])
	assert_eq(MaterialEffects.die_trigger_count(0, double, -1, _ids([]), false, 0, 6), 3)
	var mixed := _ids([Charm.SIX_PACK, Charm.RABBITS_FOOT])
	assert_eq(MaterialEffects.total_trigger_count(0, mixed, 6, -1, _ids([]), false, 0, 0, 6), 4)

# --- base_bonus (Bernstein) ------------------------------------------------------

func test_amber_adds_twenty_to_base():
	var bonus := MaterialEffects.base_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.AMBER, "", "", "", "", ""]), _p([0, 1]), NO_CHARMS)
	assert_eq(bonus, 20)

func test_charm_retriggers_count_the_face_again():
	# Hasenpfote +1 Auslösung auf jede 6: beide Würfel zählen zweimal, der
	# Bernstein-Träger auch sein Material.
	var bonus := MaterialEffects.base_bonus(_d([6, 6, 1, 2, 3, 4]), _m([DieMaterial.AMBER, "", "", "", "", ""]), _p([0, 1]), _ids([Charm.RABBITS_FOOT]))
	assert_eq(bonus, 52, "Bernstein 2 × 20 plus die zweite Augen-Zählung beider Sechser")

func test_base_bonus_ignores_non_participating_faces():
	var bonus := MaterialEffects.base_bonus(_d([5, 5, 1, 2, 3, 4]), _m(["", "", DieMaterial.AMBER, "", "", ""]), _p([0, 1]), NO_CHARMS)
	assert_eq(bonus, 0, "Bernstein außerhalb der Kombination wirkt nicht")

func test_multiple_amber_faces_each_add_twenty():
	var bonus := MaterialEffects.base_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.AMBER, DieMaterial.AMBER, "", "", "", ""]), _p([0, 1]), NO_CHARMS)
	assert_eq(bonus, 40, "zwei Bernstein-Seiten = 2 × 20")

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

func test_glass_mult_scales_with_face_value():
	var high := MaterialEffects.mult_bonus(_d([6, 6, 1, 2, 3, 4]), _m([DieMaterial.GLASS, "", "", "", "", ""]), _p([0]))
	var low := MaterialEffects.mult_bonus(_d([2, 2, 1, 3, 4, 5]), _m([DieMaterial.GLASS, "", "", "", "", ""]), _p([0]))
	assert_eq(high, 6)
	assert_eq(low, 2, "Glas skaliert mit der Augenzahl der Seite")

# --- Randfälle ---------------------------------------------------------------------

func test_none_and_unknown_materials_have_no_effect():
	var vals := _d([5, 5, 1, 2, 3, 4])
	var part := _p([0, 1])
	assert_eq(MaterialEffects.base_bonus(vals, _m(["", "", "", "", "", ""]), part, NO_CHARMS), 0)
	assert_eq(MaterialEffects.mult_bonus(vals, _m([DieMaterial.NONE, DieMaterial.NONE, "", "", "", ""]), part), 0)
	# Eine unbekannte id (kein registriertes Material) wirkt ebenfalls nicht.
	assert_eq(MaterialEffects.mult_bonus(vals, _m(["chisel", "", "", "", "", ""]), part), 0,
		"Ätzungs-/Fremd-id ist kein Material")

func test_materials_shorter_than_values_are_safe():
	# materials kürzer als die beteiligten Indizes: der Guard überspringt still.
	var bonus := MaterialEffects.base_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.AMBER]), _p([0, 1]), NO_CHARMS)
	assert_eq(bonus, 20, "nur Slot 0 hat ein Material; Slot 1 wird übersprungen")
	var mult := MaterialEffects.mult_bonus(_d([5, 5, 1, 2, 3, 4]), _m([DieMaterial.RUBY]), _p([0, 1]))
	assert_eq(mult, 4)

# --- apply_take_effects (Gold / Knochen / Glas) ----------------------------------

func test_gold_pays_three_per_participating_face():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m([DieMaterial.GOLD, DieMaterial.GOLD]), _p([0, 1]))
	assert_eq(report.total_money(), 6, "$3 je beteiligter Gold-Seite")
	assert_eq(defs[0].faces[0], 5, "Gold verändert die Seite nicht")

func test_gold_pays_twice_on_a_retriggered_six():
	# Hasenpfote löst die 6 erneut aus - inklusive Nehmen-Effekte.
	var defs: Array[DieDefinition] = [_die([6, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]), _ids([Charm.RABBITS_FOOT]))
	assert_eq(report.total_money(), 6, "Gold-Seite feuert je Auslösung")

func test_take_retrigger_checks_the_transformed_value():
	# Glückszigaretten: die 1 IST eine 6 - Hasenpfote löst auch sie erneut aus.
	var defs: Array[DieDefinition] = [_die([1, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]),
		_ids([Charm.RABBITS_FOOT, Charm.LUCKY_CIGARETTES]))
	assert_eq(report.total_money(), 6, "zwei Auslösungen à $3")

func test_gold_vein_pays_extra_per_other_carrier():
	# Zwei Gold-Seiten + eine Rubin-Seite: jeder Gold-Träger sieht einen anderen
	# Gold-Träger ($2) und einen anderen Material-Träger ($1) -> $3 + $3 je Seite.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6])]
	var faces := _m([DieMaterial.GOLD, DieMaterial.GOLD, DieMaterial.RUBY])
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0, 0]), faces, _p([0, 1, 2]), _ids([Charm.GOLD_VEIN]))
	assert_eq(report.total_money(), 12, "2 × ($3 Gold + $2 anderes Gold + $1 Rubin)")

func test_gold_vein_without_other_carriers_pays_the_plain_rate():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]), _ids([Charm.GOLD_VEIN]))
	assert_eq(report.total_money(), 3, "allein bleibt Gold bei $3")

func test_bone_grows_the_face_permanently():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]))
	assert_eq(defs[0].faces[0], 7, "Knochen: Seite +2")
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
	assert_eq(report.total_money(), 3, "nur die beteiligte Gold-Seite zahlt")
	assert_eq(defs[1].faces[0], 5, "unbeteiligter Knochen wächst nicht")

func test_bone_grows_without_upper_cap():
	# Knochen ist nach oben offen (wie Überzahlen) - eine 6 wächst zu 8.
	var defs: Array[DieDefinition] = [_die([6, 2, 3, 4, 5, 1])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]))
	assert_eq(defs[0].faces[0], 8, "Knochen kennt keine Obergrenze")

func test_take_effects_skip_unrolled_face():
	# face_indices[i] < 0 (Slot lag nicht oben / kein Wert) -> kein Effekt.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([-1]), _m([DieMaterial.GOLD]), _p([0]))
	assert_eq(report.money, 0, "ohne oben liegende Seite zahlt Gold nicht")
	assert_eq(defs[0].faces[0], 5)

func test_take_effects_combined_report_across_slots():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0, 0]), _m([DieMaterial.GOLD, DieMaterial.BONE, DieMaterial.GLASS]), _p([0, 1, 2]))
	assert_eq(report.total_money(), 3, "eine Gold-Seite")
	assert_eq(report.grown, [1], "Slot 1 ist gewachsen")
	assert_eq(report.shrunk, [2], "Slot 2 ist geschrumpft")
	assert_eq(defs[1].faces[0], 7)
	assert_eq(defs[2].faces[0], 4)

func test_multiple_bone_faces_each_grow():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6]), _die([3, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m([DieMaterial.BONE, DieMaterial.BONE]), _p([0, 1]))
	assert_eq(report.grown, [0, 1])
	assert_eq(defs[0].faces[0], 7)
	assert_eq(defs[1].faces[0], 5)

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

func test_glass_mult_flows_through_best_hand():
	# Paar Sechser: Basis (10+12), Mult 2 -> 44. Glas auf einer Paar-Seite: Mult += 6.
	var dice := _d([6, 6, 1, 2, 3, 5])
	var glass_first := _m([DieMaterial.GLASS, "", "", "", "", ""])
	assert_eq(DiceScoring.best_hand(dice)["score"], 44)
	assert_eq(DiceScoring.best_hand(dice, NO_CHARMS, false, glass_first)["score"], 176, "(10+6+6) × (2+6)")

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

func test_is_strictly_better_judges_each_side_with_its_own_levels():
	# Die alte Seite bringt ihren Zustand als eigenes old_ctx mit (Momentaufnahme
	# vor dem Neuwurf); auf den Vergleich wirkt er so wenig wie die Materialien.
	var same := _d([5, 5, 1, 2, 3, 6])
	var better := _d([5, 5, 5, 2, 3, 6])
	var ruby := _m([DieMaterial.RUBY, "", "", "", "", ""])
	var new_ctx := {DiceScoring.CTX_MATERIAL_LEVELS: {0: {"level": 2, "eye_sum": 21}}}
	var old_ctx := {DiceScoring.CTX_MATERIAL_LEVELS: {0: {"level": 1, "eye_sum": 21}}}
	assert_false(DiceScoring.is_strictly_better(same, same, NO_CHARMS, ruby, ruby, {}, new_ctx, old_ctx),
		"gleicher Rang bleibt Farkle, auch wenn die neue Seite dotiert ist")
	assert_true(DiceScoring.is_strictly_better(better, same, NO_CHARMS, ruby, ruby, {}, new_ctx, old_ctx),
		"Dreierpasch schlägt das Paar - unabhängig von der Dotierung")

# --- Dotierung: normal vs. dotiert ----------------------------------------------
# Der dotierte Zustand ist von Hand gesetzt - mal Skalierung (Bernstein, Gold,
# Knochen), mal Verwandlung (Rubin und Glas kriten). Charm-Aufschläge liegen über
# BEIDEN Zuständen (Bernsteinzimmer, Knochenleim, Goldschmied ...), nie als Faktor.

## Material-Infos eines Slots (Form wie DiceScoring.CTX_MATERIAL_LEVELS).
func _ctx_lvl(slot: int, level: int, eye_sum := 0) -> Dictionary:
	return {DiceScoring.CTX_MATERIAL_LEVELS: {slot: {"level": level, "eye_sum": eye_sum}}}

# Bernstein: +20 Basis plus Augensumme, dotiert nur die fünffache Augensumme.

func test_amber_pays_the_eye_sum_in_both_states():
	assert_eq(MaterialEffects.base_once_for(DieMaterial.AMBER, NO_CHARMS, 1, 21), 41, "20 + 21")
	assert_eq(MaterialEffects.base_once_for(DieMaterial.AMBER, NO_CHARMS, 2, 21), 105,
		"dotiert: 5 × 21, ohne festen Zuschlag")

func test_amber_keeps_the_amber_room_surplus_in_both_states():
	var surplus := MaterialEffects.AMBER_ROOM_SURPLUS
	assert_eq(MaterialEffects.base_once_for(DieMaterial.AMBER, _ids([Charm.AMBER_ROOM]), 1, 21),
		MaterialEffects.AMBER_BASE + surplus + 21, "20 + Aufschlag + 21")
	assert_eq(MaterialEffects.base_once_for(DieMaterial.AMBER, _ids([Charm.AMBER_ROOM]), 2, 21),
		MaterialEffects.AMBER_EYE_FACTOR * 21 + surplus,
		"5 × 21 + Aufschlag - der Aufschlag wird nie zum Faktor")

func test_amber_doping_flows_through_the_score():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m([DieMaterial.AMBER, "", "", "", "", ""])
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, {}, _ctx_lvl(0, 1, 21)),
		122, "(10+5+5+20+21) × 2")
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, {}, _ctx_lvl(0, 2, 21)),
		250, "(10+5+5+105) × 2")

# Rubin: +4 Mult, dotiert ein Krit ×2.

func test_ruby_crits_when_doped():
	assert_eq(MaterialEffects.mult_once_for(DieMaterial.RUBY, 5, NO_CHARMS, 1), 4)
	assert_eq(MaterialEffects.mult_once_for(DieMaterial.RUBY, 5, NO_CHARMS, 2), 0, "dotiert addiert nicht mehr")
	assert_eq(MaterialEffects.mult_crit_once_for(DieMaterial.RUBY, 5, NO_CHARMS, 2), 2)
	assert_eq(MaterialEffects.mult_crit_once_for(DieMaterial.RUBY, 5, NO_CHARMS, 1), 1, "normal kritet nicht")

func test_ruby_keeps_the_blood_diamond_additive_in_both_states():
	# Sonst würde der Aufschlag den Krit exponentiell machen.
	assert_eq(MaterialEffects.mult_once_for(DieMaterial.RUBY, 5, _ids([Charm.BLOOD_DIAMOND]), 1), 9, "4 + 5")
	assert_eq(MaterialEffects.mult_once_for(DieMaterial.RUBY, 5, _ids([Charm.BLOOD_DIAMOND]), 2), 5,
		"dotiert bleibt nur der Aufschlag additiv")
	assert_eq(MaterialEffects.mult_once_for(DieMaterial.RUBY, 5, _ids([Charm.BLOOD_DIAMOND, Charm.BLOOD_DIAMOND]), 2), 5,
		"kein Stapeln je Exemplar")
	assert_eq(MaterialEffects.mult_crit_once_for(DieMaterial.RUBY, 5, _ids([Charm.BLOOD_DIAMOND]), 2), 2,
		"der Krit bleibt ×2")

func test_ruby_doping_flows_through_the_score():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m([DieMaterial.RUBY, "", "", "", "", ""])
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, {}, _ctx_lvl(0, 1)),
		120, "20 × (2 + 4)")
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, {}, _ctx_lvl(0, 2)),
		80, "20 × (2 ×2)")

# Glas: +Augen, normal bei 6 gedeckelt, dotiert Krit ×(Augen/2) statt additiv.

func test_glass_caps_the_eyes_when_undoped():
	assert_eq(MaterialEffects.mult_once_for(DieMaterial.GLASS, 5, NO_CHARMS, 1), 5)
	assert_eq(MaterialEffects.mult_once_for(DieMaterial.GLASS, 9, NO_CHARMS, 1), 6, "normal zählt höchstens eine 6")
	assert_eq(MaterialEffects.mult_once_for(DieMaterial.GLASS, 5, NO_CHARMS, 2), 0, "dotiert addiert nicht mehr")

func test_glass_crits_only_when_doped():
	assert_eq(MaterialEffects.mult_crit_once_for(DieMaterial.GLASS, 6, NO_CHARMS, 1), 1)
	assert_eq(MaterialEffects.mult_crit_once_for(DieMaterial.GLASS, 6, NO_CHARMS, 2), 3, "Krit ×(Augen/2)")
	assert_almost_eq(MaterialEffects.mult_crit_once_for(DieMaterial.GLASS, 5, NO_CHARMS, 2), 2.5, 0.0001)
	assert_eq(MaterialEffects.mult_crit_once_for(DieMaterial.GLASS, 1, NO_CHARMS, 2), 1, "nie unter ×1")

func test_doped_glass_only_crits_in_the_score():
	# Paar Fünfer, dotiertes Glas auf Slot 0: Mult 2 ×2,5 = 5, nichts Additives dazu.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m([DieMaterial.GLASS, "", "", "", "", ""])
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, {}, _ctx_lvl(0, 2)),
		100, "20 × 5")

## Eine Seite trägt genau EIN Material - also höchstens ein Material-Krit.
func test_only_the_face_carrier_can_crit():
	assert_eq(MaterialEffects.mult_crit_once_for("", 5, NO_CHARMS, 2), 1)
	assert_eq(MaterialEffects.mult_crit_once_for(DieMaterial.AMBER, 5, NO_CHARMS, 2), 1)

# Der Material-Krit schlägt an der Position SEINES Würfels ein.

func test_material_crit_fires_at_its_own_die_not_at_the_end():
	# Dotierter Rubin auf Slot 0 (Krit ×2), Glas auf Slot 1 (+5 Mult danach).
	# Feuerte der Krit erst am Ende, wäre es (2+5)×2 = 14 statt 9.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m([DieMaterial.RUBY, DieMaterial.GLASS, "", "", "", ""])
	var score: int = DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, {}, _ctx_lvl(0, 2))
	assert_eq(score, 180, "20 × (2 ×2 + 5)")

func test_the_material_crit_lands_in_the_die_phase_beherit_only_after_it():
	# Slot 0: Mult 2 -> Material-Krit ×2 = 4, dann Glas +5 = 9 - und ERST in der
	# Charm-Phase Beherit ×6 (1 + niedrigste gewertete 5) = 54.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m([DieMaterial.RUBY, DieMaterial.GLASS, "", "", "", ""])
	var score: int = DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([Charm.BEHERIT]), false, mats, {}, _ctx_lvl(0, 2))
	assert_eq(score, 1080, "20 × 54")

func test_breakdown_mirrors_the_material_crit():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m([DieMaterial.RUBY, DieMaterial.GLASS, "", "", "", ""])
	var ctx := _ctx_lvl(0, 2)
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, {}, ctx)
	assert_eq(int(breakdown["total"]), DiceScoring.score_category(DiceScoring.TWO_KIND, dice, NO_CHARMS, false, mats, {}, ctx))
	var first_step: Dictionary = breakdown["die_steps"][0]
	assert_eq(int(first_step["crit_x"]), 2, "der Material-Krit steht im Schritt")
	assert_eq((first_step["crit_charm_indices"] as Array).size(), 0, "kein Charm-Index dafür")
	var activation: Dictionary = ((first_step["die_triggers"] as Array)[0]["firings"] as Array)[0]
	assert_true(bool(activation["crit_from_die"]), "der Strahl kommt vom Würfel, nicht vom Dock-Pad")

# Gold: $3, dotiert $7 plus $1 je ausgelöster Gold-Seite dieser Nahme.

func test_gold_pays_three_when_undoped():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]))
	assert_eq(report.total_money(), 3, "normal zahlt fest, ohne Zähler")

func test_doped_gold_pays_seven_plus_one_per_gold_face():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6], [], {0: 2})]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]))
	assert_eq(report.total_money(), 8, "$7 + $1 für die eigene Auslösung")

func test_doped_gold_counts_every_gold_face_of_the_take():
	# Drei Gold-Seiten, davon eine dotiert: der Zähler steht bei 3.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6], [], {0: 2}), _die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6])]
	var gold := _m([DieMaterial.GOLD, DieMaterial.GOLD, DieMaterial.GOLD])
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0, 0]), gold, _p([0, 1, 2]))
	assert_eq(report.total_money(), 16, "($7+$3) + $3 + $3")

func test_gold_keeps_the_goldsmith_surplus_when_doped():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6], [], {0: 2})]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GOLD]), _p([0]), _ids([Charm.GOLDSMITH]))
	assert_eq(report.total_money(), 11, "$7 + $1 Zähler + $3 Aufschlag")

# Knochen: +2, dotiert mind. +10 bzw. 20 % - je Aktivierung neu gerechnet.

func test_bone_grows_by_two_when_undoped():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]))
	assert_eq(defs[0].faces[0], 7, "normal wächst flach +2")
	assert_eq(report.grown, [0])

func test_doped_bone_grows_by_a_fifth():
	var defs: Array[DieDefinition] = [_die([100, 2, 3, 4, 5, 6], [], {0: 2})]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]))
	assert_eq(defs[0].faces[0], 120, "20 % von 100")
	var small: Array[DieDefinition] = [_die([40, 2, 3, 4, 5, 6], [], {0: 2})]
	MaterialEffects.apply_take_effects(small, _p([0]), _m([DieMaterial.BONE]), _p([0]))
	assert_eq(small[0].faces[0], 50, "20 % von 40 wären 8 - die Untergrenze +10 greift")

func test_the_magic_card_grows_only_the_combination_bone():
	# Die Nehmen-Seite muss dieselbe Grenze ziehen wie die Wertung: die Zauberkarte
	# gibt dem Kombinations-Würfel einen zweiten Antritt, dem nur mitgewerteten
	# (Vollzähler/Krypton) nicht - sonst liefen Simulation und Def auseinander.
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6]), _die([5, 2, 3, 4, 5, 6])]
	MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m([DieMaterial.BONE, DieMaterial.BONE]),
		_p([0, 1]), _ids([Charm.MAGIC_CARD]), -1, {}, _p([0, 1]), false, _p([0, 1]), {}, 0, 0,
		[] as Array[DieDefinition], _p([0]))
	assert_eq(defs[0].faces[0], 9, "Kombinations-Würfel: zwei Auslösungen à +2")
	assert_eq(defs[1].faces[0], 7, "nur mitgewertet: eine Auslösung")

func test_bone_keeps_the_glue_surplus():
	# Knochenleim = Aufschlag +3 über den Schritt (+2).
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]), _ids([Charm.BONE_GLUE]))
	assert_eq(defs[0].faces[0], 10, "+2 (normal) +3 (Aufschlag)")

func test_doped_bone_compounds_per_marrow_trigger():
	# Knochenmark gibt eine zweite Auslösung; dotiert rechnet die ihren
	# Prozentschritt am schon gewachsenen Wert neu (40 -> +10+3 = 53 -> +11+3 = 67),
	# nie 2 × denselben Schritt.
	var defs: Array[DieDefinition] = [_die([40, 2, 3, 4, 5, 6], [], {0: 2})]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.BONE]), _p([0]),
		_ids([Charm.BONE_GLUE, Charm.BONE_MARROW]))
	assert_eq(defs[0].faces[0], 67)

# Glas: −1, dotiert die halbe Seite.

func test_glass_shrinks_by_one_when_undoped():
	var defs: Array[DieDefinition] = [_die([40, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]))
	assert_eq(defs[0].faces[0], 39, "normal frisst flach 1")
	assert_eq(report.shrunk, [0])

func test_doped_glass_halves_the_face():
	var defs: Array[DieDefinition] = [_die([40, 2, 3, 4, 5, 6], [], {0: 2})]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]))
	assert_eq(defs[0].faces[0], 20, "dotiert halbiert sich")

func test_doped_glass_always_loses_at_least_one():
	# Die Hälfte wird aufgerundet, damit auch eine kleine Seite wirklich fällt.
	var defs: Array[DieDefinition] = [_die([3, 2, 3, 4, 5, 6], [], {0: 2})]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]))
	assert_eq(defs[0].faces[0], 1, "3 verliert 2")

func test_glass_stops_at_the_floor():
	var defs: Array[DieDefinition] = [_die([1, 2, 3, 4, 5, 6])]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]))
	assert_eq(defs[0].faces[0], EtchingEffects.MIN_FACE_VALUE, "unter den Boden geht nichts")
	assert_eq(report.shrunk, [], "was nicht fällt, meldet auch nichts")

func test_glass_shrinks_to_the_lungs_floor():
	# Die Glasbläserpfeife hebt nur den Boden: der Schritt läuft weiter.
	var defs: Array[DieDefinition] = [_die([40, 2, 3, 4, 5, 6])]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([DieMaterial.GLASS]), _p([0]), _ids([Charm.GLASSBLOWER_LUNG]))
	assert_eq(defs[0].faces[0], 39, "normal frisst 1 - auch mit Lunge")
	var low: Array[DieDefinition] = [_die([7, 2, 3, 4, 5, 6])]
	MaterialEffects.apply_take_effects(low, _p([0]), _m([DieMaterial.GLASS]), _p([0]), _ids([Charm.GLASSBLOWER_LUNG]))
	assert_eq(low[0].faces[0], MaterialEffects.GLASSBLOWER_LUNG_FLOOR, "7 − 1 = 6, der Boden hält")

# --- Wertwandel ZWISCHEN den Aktivierungen --------------------------------------
# Knochen wächst, Glas schrumpft und Helium hebt mitten im Zug: die zweite
# Auslösung zählt schon den neuen Wert. Simulation (DiceScoring) und Buchung
# (apply_take_effects) rechnen dieselbe Kette - dieser Block sichert das ab.

## Fälle: [Seitenwert, Seiten-Material, Charms, Zustand, Essenz].
func _mutation_cases() -> Array:
	return [
		[5, DieMaterial.BONE, [], 1, ""],
		[5, DieMaterial.BONE, [Charm.BONE_GLUE], 1, ""],
		[5, DieMaterial.BONE, [Charm.BONE_MARROW], 1, ""],
		[5, DieMaterial.BONE, [Charm.BONE_GLUE, Charm.BONE_MARROW], 2, ""],
		[40, DieMaterial.BONE, [], 1, ""],
		[40, DieMaterial.BONE, [], 2, ""],
		[40, DieMaterial.GLASS, [], 1, ""],
		[40, DieMaterial.GLASS, [], 2, ""],
		[8, DieMaterial.GLASS, [Charm.GLASSBLOWER_LUNG], 2, ""],
		[3, DieMaterial.GLASS, [], 2, ""],
		[6, "", [], 1, Essence.HELIUM],
		[6, DieMaterial.BONE, [], 1, Essence.HELIUM],
		[40, DieMaterial.GLASS, [], 2, Essence.NITROGEN],
	]

func test_take_effects_land_on_the_simulated_running_value():
	# Die Zeremonie zeigt den Zwischenstand aus der Simulation - endet sie
	# woanders als die Def, springt die Zahl nach dem Zählen.
	for case in _mutation_cases():
		var value: int = case[0]
		var face_material: String = case[1]
		var level: int = case[3]
		var essence_id: String = case[4]
		# Die Echo-Kammer stapelt Aktivierungen, ohne die Essenz zu belegen -
		# so lässt sich jeder Fall ein-, zwei- und dreifach prüfen.
		for echoes in 3:
			var ids := _ids(case[2])
			for _e in echoes:
				ids.append(Charm.ECHO_CHAMBER)
			var defs: Array[DieDefinition] = [
				_die([value, 2, 3, 4, 5, 6], [face_material, "", "", "", "", ""], {0: level})]
			defs[0].essence_id = essence_id
			var essences := {0: essence_id} if essence_id != "" else {}
			MaterialEffects.apply_take_effects(defs, _p([0]), _m([face_material]), _p([0]),
				ids, 0, essences, _p([0]))
			var activations := MaterialEffects.total_trigger_count(0, ids, value, 0, _ids([essence_id] if essence_id != "" else []))
			assert_eq(defs[0].faces[0],
				MaterialEffects.value_after_activations(value, activations, face_material,
					ids, level, _ids([essence_id] if essence_id != "" else [])),
				"Wert %d, Seite '%s', Zustand %d, Essenz '%s', %d Echos" % [value, face_material, level, essence_id, echoes])

func test_the_six_pack_take_lands_on_the_simulated_running_value():
	# Volle Hand: der Knochen tritt zweimal an, wächst also 5 -> 7 -> 9. Die
	# Buchung muss exakt dort landen, wo die Simulation aufhört.
	var ids := _ids([Charm.SIX_PACK])
	var defs: Array[DieDefinition] = []
	for _i in 6:
		defs.append(_die([5, 2, 3, 4, 5, 6], [DieMaterial.BONE, "", "", "", "", ""]))
	var slots := _p([0, 1, 2, 3, 4, 5])
	var mats := _m([DieMaterial.BONE, DieMaterial.BONE, DieMaterial.BONE,
		DieMaterial.BONE, DieMaterial.BONE, DieMaterial.BONE])
	MaterialEffects.apply_take_effects(defs, _p([0, 0, 0, 0, 0, 0]), mats, slots, ids, -1, {}, slots)
	var activations := MaterialEffects.total_trigger_count(0, ids, 5, -1, _ids([]), false, 0, 0, 6)
	assert_eq(activations, 2)
	assert_eq(defs[0].faces[0],
		MaterialEffects.value_after_activations(5, activations, DieMaterial.BONE, ids))

func test_a_single_activation_is_unchanged_by_the_running_value():
	# Ohne zweite Auslösung darf der Wertwandel nichts verschieben.
	var mats := _m([DieMaterial.BONE, "", "", "", "", ""])
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 4]), NO_CHARMS, false, mats)
	assert_eq(score, (10 + 5 + 5) * 2)

## Alle Zündungen eines Würfel-Schritts, über die Trigger-Gruppen hinweg.
func _firings(step: Dictionary) -> Array:
	var out: Array = []
	for group in step["die_triggers"]:
		out.append_array(group["firings"])
	return out

func test_the_second_activation_counts_the_grown_bone():
	# Argon löst zweimal aus: 5 Augen, dann 7 (der Knochen wuchs dazwischen).
	var mats := _m([DieMaterial.BONE, "", "", "", "", ""])
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 4]),
		NO_CHARMS, false, mats, {}, _argon(0))
	assert_eq(score, (10 + 5 + 7 + 5) * 2)

func test_the_second_activation_counts_the_shrunken_glass():
	# Glas zählt seine Augen als Mult UND als Basis: 6 dann 5.
	var mats := _m([DieMaterial.GLASS, "", "", "", "", ""])
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([6, 6, 1, 2, 3, 4]),
		NO_CHARMS, false, mats, {}, _argon(0))
	assert_eq(score, (10 + 6 + 5 + 6) * (2 + 6 + 5))

func test_preview_and_take_agree_on_a_growing_bone():
	# Vorschau (best_hand) und Nahme (score_category) laufen durch dieselbe
	# Rechnung - der laufende Wert darf sie nicht auseinanderbringen.
	var mats := _m([DieMaterial.BONE, "", "", "", "", ""])
	var dice := _d([5, 5, 1, 2, 3, 4])
	var hand := DiceScoring.best_hand(dice, NO_CHARMS, false, mats, {}, _argon(0))
	assert_eq(int(hand["score"]),
		DiceScoring.score_category(String(hand["key"]), dice, NO_CHARMS, false, mats, {}, _argon(0)))

func test_the_running_value_rides_the_physical_face_not_the_transform():
	# Glückszigaretten zeigen die 1 als 6, gewachsen wird die ECHTE Seite:
	# Auslösung 1 zählt 6, Auslösung 2 die gewachsene 3.
	var mats := _m([DieMaterial.BONE, "", "", "", "", ""])
	var ids := _ids([Charm.LUCKY_CIGARETTES])
	var score := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([1, 1, 3, 4, 5, 2]),
		ids, false, mats, {}, _argon(0))
	assert_eq(score, (10 + 6 + 3 + 6) * 2)

func test_breakdown_carries_the_value_of_every_activation():
	var mats := _m([DieMaterial.BONE, "", "", "", "", ""])
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 4]),
		NO_CHARMS, false, mats, {}, _argon(0))
	var acts: Array = _firings(breakdown["die_steps"][0])
	assert_eq(acts.size(), 2, "Argon löst zweimal aus")
	assert_eq(acts[0]["value"], 5)
	assert_eq(acts[0]["value_after"], 7, "zwischen den Zählungen gewachsen")
	assert_eq(acts[1]["value"], 7)
	assert_eq(acts[1]["value_after"], 9)

# --- Gleichrichter: der LETZTE Wertwandel des Zuges ------------------------------

## Drei gewertete Würfel mit den Werten a/b/c, alle ohne Material.
func _rectifier_defs(values: Array) -> Array[DieDefinition]:
	var defs: Array[DieDefinition] = []
	for v: int in values:
		defs.append(_die([v, 2, 3, 4, 5, 6]))
	return defs

func test_the_rectifier_levels_the_scored_faces_to_the_rounded_mean():
	# 2 + 3 + 6 = 11, /3 = 3,67 -> aufgerundet 4.
	var defs := _rectifier_defs([2, 3, 6])
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0, 0]), _m(["", "", ""]),
		_p([0, 1, 2]), _ids([Charm.RECTIFIER]))
	for i in 3:
		assert_eq(defs[i].faces[0], 4, "Slot %d steht auf dem Mittelwert" % i)
	assert_eq(report.grown, [0, 1], "die beiden niedrigen sind gewachsen")
	assert_eq(report.shrunk, [2], "der hohe ist geschrumpft")

func test_the_rectifier_runs_after_the_value_mutations():
	# Der Knochen wächst erst von 5 auf 7, DANN wird gemittelt: (7 + 2) / 2 = 4,5 -> 5.
	var defs := _rectifier_defs([5, 2])
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]),
		_m([DieMaterial.BONE, ""]), _p([0, 1]), _ids([Charm.RECTIFIER]))
	assert_eq(defs[0].faces[0], 5, "der gewachsene Knochen fällt auf den Mittelwert")
	assert_eq(defs[1].faces[0], 5)
	assert_true(report.grown.has(0), "gewachsen ist er trotzdem gemeldet")

func test_the_rectifier_never_shrinks_a_protected_face():
	# Stickstoff schützt Slot 0 (6): er bleibt, zählt aber in den Mittelwert
	# (6 + 2) / 2 = 4, auf den Slot 1 steigt.
	var defs := _rectifier_defs([6, 2])
	defs[0].essence_id = Essence.NITROGEN
	MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m(["", ""]), _p([0, 1]),
		_ids([Charm.RECTIFIER]), -1, {0: Essence.NITROGEN})
	assert_eq(defs[0].faces[0], 6, "die geschützte Seite schrumpft nicht")
	assert_eq(defs[1].faces[0], 4, "sie zählt aber in den Mittelwert")

func test_the_rectifier_still_grows_a_protected_face():
	# Schutz wehrt nur den Verlust ab: (2 + 6) / 2 = 4, Slot 0 steigt.
	var defs := _rectifier_defs([2, 6])
	defs[0].essence_id = Essence.NITROGEN
	MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m(["", ""]), _p([0, 1]),
		_ids([Charm.RECTIFIER]), -1, {0: Essence.NITROGEN})
	assert_eq(defs[0].faces[0], 4)

func test_the_rectifier_leaves_unscored_dice_alone():
	var defs := _rectifier_defs([2, 6, 5])
	MaterialEffects.apply_take_effects(defs, _p([0, 0, 0]), _m(["", "", ""]), _p([0, 1]),
		_ids([Charm.RECTIFIER]), -1, {}, _p([]), false, _p([0, 1, 2]))
	assert_eq(defs[0].faces[0], 4, "(2 + 6) / 2 = 4")
	assert_eq(defs[1].faces[0], 4)
	assert_eq(defs[2].faces[0], 5, "der ungewertete Würfel bleibt, wie er liegt")

func test_without_the_rectifier_nothing_levels():
	var defs := _rectifier_defs([2, 3, 6])
	MaterialEffects.apply_take_effects(defs, _p([0, 0, 0]), _m(["", "", ""]), _p([0, 1, 2]))
	assert_eq(defs[0].faces[0], 2)
	assert_eq(defs[2].faces[0], 6)

# --- Datensatz: der Zustand gehört dem Würfel, nicht der geteilten Vorlage ------

func test_instantiate_and_become_copy_the_levels():
	var def := _die([5, 2, 3, 4, 5, 6], [], {2: 2})
	var copy := def.instantiate()
	assert_eq(copy.levels[2], 2)
	copy.levels[2] = 1
	assert_eq(def.levels[2], 2, "die Kopie teilt das Array nicht")
	var host := DieDefinition.new()
	host.become(def)
	assert_eq(host.levels[2], 2)
	host.levels[2] = 1
	assert_eq(def.levels[2], 2, "become teilt das Array nicht")

func test_a_fresh_definition_has_no_levels():
	assert_eq(DieDefinition.new().levels, [0, 0, 0, 0, 0, 0] as Array[int])

# --- dope: der einzige Weg in den dotierten Zustand ------------------------------

func test_dope_lifts_the_face_once():
	var def := DieDefinition.new()
	def.set_face_material(0, DieMaterial.RUBY)
	assert_eq(def.material_level(0), 1, "ein frisches Material steht normal")
	assert_true(def.dope(0))
	assert_eq(def.material_level(0), DieMaterial.MAX_LEVEL)
	assert_false(def.dope(0), "dotiert ist der Deckel")
	assert_eq(def.material_level(0), DieMaterial.MAX_LEVEL)

func test_dope_needs_a_material():
	var def := DieDefinition.new()
	assert_false(def.dope(0), "eine nackte Seite hat nichts zu dotieren")
	assert_eq(def.material_level(0), 0)

func test_dope_ignores_faces_out_of_range():
	var def := DieDefinition.new()
	assert_false(def.dope(-1))
	assert_false(def.dope(9))

# --- set_face_material: EINZIGER Schreibweg, setzt den Zustand zurück -----------

func test_set_face_material_resets_the_level():
	var def := _die([5, 2, 3, 4, 5, 6], [DieMaterial.RUBY, "", "", "", "", ""], {0: 2})
	def.set_face_material(0, DieMaterial.GOLD)
	assert_eq(def.materials[0], DieMaterial.GOLD)
	assert_eq(def.material_level(0), 1, "die Dotierung wohnt in der Glasur, nicht in der Seite")

func test_set_face_material_clears_the_level_when_wiped():
	var def := _die([5, 2, 3, 4, 5, 6], [DieMaterial.RUBY, "", "", "", "", ""], {0: 2})
	def.set_face_material(0, "")
	assert_eq(def.material_level(0), 0, "ohne Material kein Zustand")

func test_set_face_material_leaves_other_faces_alone():
	var def := _die([5, 2, 3, 4, 5, 6], [DieMaterial.RUBY, DieMaterial.GOLD, "", "", "", ""], {0: 1, 1: 2})
	def.set_face_material(0, DieMaterial.AMBER)
	assert_eq(def.material_level(1), 2, "die Nachbarseite bleibt dotiert")

func test_set_face_material_ignores_faces_out_of_range():
	var def := _die([5, 2, 3, 4, 5, 6])
	def.set_face_material(-1, DieMaterial.GOLD)
	def.set_face_material(9, DieMaterial.GOLD)
	assert_eq(def.materials, _m(["", "", "", "", "", ""]), "nichts geschrieben")

# --- Zündungs-Geld: was an einer Zündung hängt, zahlt in ihrem Moment ------------
# plan_activation_money plant es in derselben Verschachtelung, die der Zug läuft;
# der Zug meldet es nur noch als Summe (activation_money) und bucht es NICHT.
# Diese Batterie hält Plan, Bericht und Schrittliste auf einer Zahl.

## Summiert einen Plan von Hand - so bleibt der Test unabhängig von der Summe,
## die MaterialEffects selbst zieht.
func _plan_sum(plan: Dictionary) -> int:
	var total := 0
	for slot in plan:
		var entry: Dictionary = plan[slot]
		for group: Dictionary in entry["groups"]:
			for amount: int in group["firings"]:
				total += amount
			for amount: int in group["links"]:
				total += amount
		for amount: int in entry["det_links"]:
			total += amount
	return total

## Fälle: [Name, Seiten-Material, Zustand, Charms, Seelen, Leiterbahn-Zündungen].
func _activation_money_cases() -> Array:
	return [
		["Neon einfach", "", 1, [], [Essence.NEON], {}],
		["Neon × Argon", "", 1, [], [Essence.NEON, Essence.ARGON], {}],
		["Neon × Quecksilberdampf", "", 1, [], [Essence.NEON, Essence.MERCURY_VAPOR], {}],
		["Gold normal", DieMaterial.GOLD, 1, [], [], {}],
		["Gold dotiert", DieMaterial.GOLD, 2, [], [], {}],
		["Gold im Härteofen", DieMaterial.GOLD, 2, [Charm.KILN], [], {}],
		["Gold + Seele", DieMaterial.GOLD, 1, [], [Essence.NEON], {}],
		["Gold-Glied", "", 1, [], [],
			{0: [[{"face": 2, "value": 3, "material": DieMaterial.GOLD, "level": 1}]]}],
	]

func test_activation_money_is_planned_exactly_as_the_take_reports_it():
	for case in _activation_money_cases():
		var label: String = case[0]
		var mats := _m([case[1], "", DieMaterial.GOLD, "", "", ""])
		var def := _die([5, 2, 3, 4, 5, 6], mats, {0: int(case[2]), 2: 1})
		var ids := _ids(case[3])
		var souls := _ids(case[4])
		var essences := {0: souls} if not souls.is_empty() else {}
		var fires: Dictionary = case[5]
		var plan := MaterialEffects.plan_activation_money([def] as Array[DieDefinition], _p([0]),
			_m([case[1]]), _p([0]), ids, -1, essences, _p([0]), false, fires)
		var report := MaterialEffects.apply_take_effects([def] as Array[DieDefinition], _p([0]),
			_m([case[1]]), _p([0]), ids, -1, essences, _p([0]), false, _p([0]), fires)
		assert_eq(report.activation_money, _plan_sum(plan), "%s: Plan == Bericht" % label)
		assert_eq(report.money, 0, "%s: nichts davon bleibt in money" % label)
		assert_gt(report.total_money(), 0, "%s: es floss überhaupt Geld" % label)

func test_the_breakdown_carries_the_same_activation_money():
	# Argon-Neon-Gold: zwei Würfel-Trigger, je eine Zündung - jede zahlt selbst.
	var mats := _m([DieMaterial.GOLD, "", "", "", "", ""])
	var def := _die([5, 5, 3, 4, 5, 6], mats)
	var defs: Array[DieDefinition] = [def, _die([5, 2, 3, 4, 5, 6])]
	var essences := {0: Essence.ARGON}
	var ctx := {DiceScoring.CTX_ESSENCES: essences}
	var plan := MaterialEffects.plan_activation_money(defs, _p([0, 0]),
		_m([DieMaterial.GOLD, ""]), _p([0, 1]), NO_CHARMS, -1, essences, _p([0, 1]))
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d([5, 5]), NO_CHARMS,
		false, _m([DieMaterial.GOLD, ""]), {}, ctx)
	ScoreBreakdown.attach_activation_money(breakdown, plan)
	var shown := 0
	for step: Dictionary in breakdown["die_steps"]:
		for group: Dictionary in step["die_triggers"]:
			for firing: Dictionary in group["firings"]:
				shown += int(firing.get("money", 0))
			for link: Dictionary in group["links"]:
				shown += int(link.get("money", 0))
		for link: Dictionary in step.get("det_links", []):
			shown += int(link.get("money", 0))
	assert_eq(shown, _plan_sum(plan), "die Zeremonie zeigt exakt den Plan")
	assert_eq(shown, 2 * MaterialEffects.GOLD_PAYOUT, "zwei Argon-Zündungen à $3")

func test_per_turn_money_stays_out_of_the_activation_plan():
	# Streulicht (ungewertete Seite) und Schwarzlicht zahlen je ZUG - sie gehören
	# weiter in money, damit der Schluss-Komet sie trägt.
	var lit := _die([5, 2, 3, 4, 5, 6])
	lit.essence_id = Essence.BLACK_LIGHT
	var idle := _die([5, 2, 3, 4, 5, 6])
	idle.runes[0] = Rune.STRAY_LIGHT
	var defs: Array[DieDefinition] = [lit, idle]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0]), _m(["", ""]), _p([0]),
		NO_CHARMS, -1, {0: Essence.BLACK_LIGHT}, _p([0]), false, _p([0, 1]))
	assert_eq(report.activation_money, 0, "nichts davon hängt an einer Zündung")
	assert_eq(report.money, EssenceEffects.BLACK_LIGHT_PER_DIE + RuneEffects.STRAY_LIGHT_MONEY)

func test_packet_bookings_sum_like_one_booking_under_a_money_factor():
	# Zündungs-Geld bucht Paket für Paket (Straßenmusiker-Grammatik). Die
	# Rundenfaktoren sind ganzzahlig, also kann die Stückelung nichts verlieren.
	var run := GameRun.new_run()
	run.sign_clauses(_ids([DealClause.HAPPY_HOUR]))
	var factor := run.money_gain_factor()
	assert_almost_eq(factor, 2.0, 0.0001)
	var before := run.money
	for value in ChipStackView.split_gain(7):
		run.add_money(value)
	var packets := run.money - before
	run.money = before
	run.add_money(7)
	assert_eq(packets, run.money - before, "Pakete und Summe landen auf derselben Zahl")
