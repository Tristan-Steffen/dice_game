extends GutTest
## Tier-1-Tests der sechs Zahl-Gravuren (EtchingEffects). Geprüft werden die
## LEITERN: jede Stufe 1..6 ist eine eigene Sprosse, und die Reihe in der Presse
## setzt sie. Seiten-Indizes 0..5.

func _die(faces: Array) -> DieDefinition:
	var d := DieDefinition.new()
	var typed: Array[int] = []
	typed.assign(faces)
	d.faces = typed
	return d

func _targets(list: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(list)
	return typed

# --- Kerbe -------------------------------------------------------------------

func test_notch_climbs_its_ladder():
	for stufe in range(1, 7):
		var d := _die([1, 2, 3, 4, 5, 6])
		EtchingEffects.notch(d, 0, stufe)
		assert_eq(d.faces[0], 1 + int(EtchingEffects.NOTCH_LADDER[stufe - 1]),
			"Kerbe Stufe %d" % stufe)

func test_notch_ladder_is_the_authored_one():
	assert_eq(EtchingEffects.NOTCH_LADDER, [1, 2, 3, 5, 8, 12])

func test_notch_may_exceed_six():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.notch(d, 5)  # 6 -> 7
	assert_eq(d.faces[5], 7, "Kerbe: darf über 6 hinaus")

# --- Überdruck ---------------------------------------------------------------

func test_overpressure_hits_the_highest_face():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.overpressure(d, 1)
	assert_eq(d.faces, [1, 2, 3, 4, 5, 8], "die höchste Seite +2")

func test_overpressure_breaks_ties_on_the_smallest_face_index():
	var d := _die([6, 2, 6, 4, 5, 6])
	EtchingEffects.overpressure(d, 1)
	assert_eq(d.faces, [8, 2, 6, 4, 5, 6], "Gleichstand: die kleinste Seitenzahl")

func test_overpressure_climbs_its_ladder():
	for stufe in range(1, 7):
		var d := _die([1, 1, 1, 1, 1, 1])
		EtchingEffects.overpressure(d, stufe)
		assert_eq(d.faces[0], 1 + int(EtchingEffects.OVERPRESSURE_LADDER[stufe - 1]),
			"Überdruck Stufe %d" % stufe)

# --- Aufholen ----------------------------------------------------------------

func test_growth_hits_the_lowest_face():
	var d := _die([3, 2, 3, 4, 5, 6])
	EtchingEffects.growth(d, 1)
	assert_eq(d.faces, [3, 4, 3, 4, 5, 6], "die niedrigste Seite +2")

func test_growth_breaks_ties_on_the_smallest_face_index():
	var d := _die([1, 2, 1, 4, 5, 6])
	EtchingEffects.growth(d, 1)
	assert_eq(d.faces, [3, 2, 1, 4, 5, 6])

func test_growth_climbs_its_ladder():
	for stufe in range(1, 7):
		var d := _die([1, 9, 9, 9, 9, 9])
		EtchingEffects.growth(d, stufe)
		assert_eq(d.faces[0], 1 + int(EtchingEffects.GROWTH_LADDER[stufe - 1]),
			"Aufholen Stufe %d" % stufe)

# --- Politur -----------------------------------------------------------------

func test_polish_bumps_every_face():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.polish(d)
	assert_eq(d.faces, [2, 3, 4, 5, 6, 7], "Politur: alle Seiten +1, auch über 6")

func test_polish_climbs_its_ladder():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.polish(d, 6)
	assert_eq(d.faces, [11, 12, 13, 14, 15, 16], "Stufe 6: +10 auf alle")

# --- Schleifstein ------------------------------------------------------------

func test_grindstone_preserves_sum():
	var d := _die([1, 2, 3, 4, 5, 6])
	var before := 0
	for v in d.faces:
		before += v
	assert_eq(EtchingEffects.grindstone(d, 5, 0), 2, "Stufe 1 verschiebt 2 Augen")
	assert_eq(d.faces, [3, 2, 3, 4, 5, 4])
	var after := 0
	for v in d.faces:
		after += v
	assert_eq(after, before, "Augensumme bleibt gleich")

func test_grindstone_moves_only_what_the_source_can_give():
	var d := _die([1, 2, 3, 4, 5, 6])
	assert_eq(EtchingEffects.grindstone(d, 1, 0, 4), 1, "die 2 gibt genau 1 ab")
	assert_eq(d.faces, [2, 1, 3, 4, 5, 6], "die Quelle fällt nie unter 1")

func test_grindstone_on_a_one_moves_nothing():
	var d := _die([1, 2, 3, 4, 5, 6])
	assert_eq(EtchingEffects.grindstone(d, 0, 5, 6), 0)
	assert_eq(d.faces, [1, 2, 3, 4, 5, 6])

func test_grindstone_stufe_six_moves_everything_above_one():
	var d := _die([1, 2, 3, 4, 5, 20])
	assert_eq(EtchingEffects.grindstone(d, 5, 0, 6), 19, "alles über der 1")
	assert_eq(d.faces, [20, 2, 3, 4, 5, 1])

func test_can_grindstone_minus_respects_floor():
	var d := _die([1, 2, 3, 4, 5, 6])
	assert_false(EtchingEffects.can_grindstone_minus(d, 0), "eine 1 darf nicht auf 0")
	assert_true(EtchingEffects.can_grindstone_minus(d, 1), "eine 2 darf auf 1")

# --- Meißel ------------------------------------------------------------------

func test_chisel_copies_source_onto_dest():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.chisel(d, 5, _targets([4]))
	assert_eq(d.faces, [1, 2, 3, 4, 6, 6])

func test_chisel_leaves_source_unchanged():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.chisel(d, 0, _targets([3]))
	assert_eq(d.faces[0], 1, "Quelle bleibt")
	assert_eq(d.faces[3], 1, "Ziel übernimmt Quellwert")

func test_chisel_target_count_is_the_blueprint_from_stufe_four():
	assert_eq(EtchingEffects.CHISEL_TARGETS, [1, 2, 3, 5, 5, 5])
	assert_eq(EtchingEffects.chisel_target_count(4), 5, "ab Stufe 4 alle fünf anderen")

func test_chisel_stufe_four_is_the_blueprint():
	var d := _die([1, 2, 3, 4, 5, 6])
	EtchingEffects.chisel(d, 5, _targets([0, 1, 2, 3, 4]), 4)
	assert_eq(d.faces, [6, 6, 6, 6, 6, 6])

func test_chisel_below_stufe_five_carries_no_material():
	var d := _die([1, 2, 3, 4, 5, 6])
	d.set_face_material(5, DieMaterial.GOLD)
	EtchingEffects.chisel(d, 5, _targets([0]), 4)
	assert_eq(d.materials[0], "", "Stufe 4 kopiert nur den Wert")

func test_chisel_stufe_five_copies_the_material_with_its_doping():
	var d := _die([1, 2, 3, 4, 5, 6])
	d.set_face_material(5, DieMaterial.GOLD)
	d.dope(5)
	EtchingEffects.chisel(d, 5, _targets([0]), 5)
	assert_eq(d.materials[0], DieMaterial.GOLD)
	assert_eq(d.material_level(0), DieMaterial.MAX_LEVEL, "die Veredelung wandert mit")

func test_chisel_stufe_five_copies_an_undoped_material_undoped():
	var d := _die([1, 2, 3, 4, 5, 6])
	d.set_face_material(5, DieMaterial.RUBY)
	EtchingEffects.chisel(d, 5, _targets([0]), 5)
	assert_eq(d.materials[0], DieMaterial.RUBY)
	assert_eq(d.material_level(0), 1, "unveredelt bleibt unveredelt")

func test_chisel_never_strips_a_target_when_the_source_is_bare():
	var d := _die([1, 2, 3, 4, 5, 6])
	d.set_face_material(0, DieMaterial.GOLD)
	EtchingEffects.chisel(d, 5, _targets([0]), 6)
	assert_eq(d.materials[0], DieMaterial.GOLD, "eine leere Quelle nimmt nichts weg")

func test_burn_in_blocks_the_material_copy_but_not_the_value():
	var d := _die([1, 2, 3, 4, 5, 6])
	d.set_face_material(5, DieMaterial.GOLD)
	d.set_rune(0, Rune.BURN_IN)
	EtchingEffects.chisel(d, 5, _targets([0]), 5)
	assert_eq(d.faces[0], 6, "der Wert kommt trotzdem")
	assert_eq(d.materials[0], "", "der Einbrand sperrt das Übermalen")

func test_chisel_stufe_six_copies_the_rune():
	var d := _die([1, 2, 3, 4, 5, 6])
	d.set_rune(5, Rune.AFTERGLOW)
	EtchingEffects.chisel(d, 5, _targets([0]), 6)
	assert_eq(d.runes[0], Rune.AFTERGLOW)

func test_chisel_stufe_five_leaves_the_rune_alone():
	var d := _die([1, 2, 3, 4, 5, 6])
	d.set_rune(5, Rune.AFTERGLOW)
	EtchingEffects.chisel(d, 5, _targets([0]), 5)
	assert_eq(d.runes[0], "", "erst Stufe 6 nimmt die Rune mit")

# --- Leitern allgemein --------------------------------------------------------

func test_every_ladder_has_six_rungs():
	for ladder in [EtchingEffects.NOTCH_LADDER, EtchingEffects.OVERPRESSURE_LADDER,
			EtchingEffects.POLISH_LADDER, EtchingEffects.GROWTH_LADDER,
			EtchingEffects.GRINDSTONE_LADDER, EtchingEffects.CHISEL_TARGETS]:
		assert_eq(ladder.size(), EtchingEffects.MAX_STUFE)

func test_step_of_clamps_outside_the_ladder():
	assert_eq(EtchingEffects.step_of(EtchingEffects.NOTCH_LADDER, 0), 1)
	assert_eq(EtchingEffects.step_of(EtchingEffects.NOTCH_LADDER, 99), 12)
