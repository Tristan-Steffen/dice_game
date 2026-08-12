extends GutTest
## Die Stufen-Zeile eines Beutestücks: sie muss die Leiter nennen, auf der es
## WIRKLICH steht. Geprüft wird deshalb nicht der Wortlaut, sondern dass jede
## Zahl im Text auch die Zahl der Wirkung ist (siehe EtchingEffects).

func _faces(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _die() -> DieDefinition:
	return DieDefinition.standard()

# --- Zahlen-Spur: jede Sprosse steht im Text ------------------------------------

func test_the_notch_line_names_its_ladder_step() -> void:
	for stufe in range(1, EtchingEffects.MAX_STUFE + 1):
		var step := EtchingEffects.step_of(EtchingEffects.NOTCH_LADDER, stufe)
		var die := _die()
		var before: int = die.faces[0]
		EtchingEffects.notch(die, 0, stufe)
		assert_eq(die.faces[0] - before, step, "Stufe %d hebt um %d" % [stufe, step])
		assert_true(Engraving.stufe_text(Engraving.NOTCH, stufe).contains("+%d" % step),
			"und die Zeile nennt genau das: %s" % Engraving.stufe_text(Engraving.NOTCH, stufe))

func test_the_number_lines_all_name_their_step() -> void:
	var ladders := {
		Engraving.OVERPRESSURE: EtchingEffects.OVERPRESSURE_LADDER,
		Engraving.POLISH: EtchingEffects.POLISH_LADDER,
		Engraving.GROWTH: EtchingEffects.GROWTH_LADDER,
	}
	for id: String in ladders:
		for stufe in range(1, EtchingEffects.MAX_STUFE + 1):
			var step := EtchingEffects.step_of(ladders[id], stufe)
			var line := Engraving.stufe_text(id, stufe)
			assert_true(line.contains("+%d" % step), "%s Stufe %d: %s" % [id, stufe, line])
			assert_true(line.contains("Stufe %d" % stufe), "und nennt seine Stufe")

func test_the_grindstone_line_names_the_eyes_it_moves() -> void:
	for stufe in range(1, EtchingEffects.MAX_STUFE + 1):
		var want := EtchingEffects.step_of(EtchingEffects.GRINDSTONE_LADDER, stufe)
		var line := Engraving.stufe_text(Engraving.GRINDSTONE, stufe)
		if want == EtchingEffects.GRINDSTONE_ALL:
			assert_true(line.contains("ALLE"), "die letzte Sprosse nimmt alles: %s" % line)
			continue
		assert_true(line.contains(str(want)), "Stufe %d verschiebt %d: %s" % [stufe, want, line])
		# Und sie tut es auch: eine hohe Quellseite gibt genau so viele Augen ab.
		var die := _die()
		die.faces = _faces([50, 1, 1, 1, 1, 1])
		assert_eq(EtchingEffects.grindstone(die, 0, 1, stufe), want)

func test_the_chisel_line_tracks_its_target_count_and_its_riders() -> void:
	for stufe in range(1, EtchingEffects.MAX_STUFE + 1):
		var line := Engraving.stufe_text(Engraving.CHISEL, stufe)
		var targets := EtchingEffects.chisel_target_count(stufe)
		if targets >= 5:
			assert_true(line.contains("fünf"), "Stufe %d trifft alle: %s" % [stufe, line])
		elif targets > 1:
			assert_true(line.contains(str(targets)), "Stufe %d trifft %d: %s" % [stufe, targets, line])
		assert_eq(line.contains("Material"), stufe >= EtchingEffects.CHISEL_MATERIAL_STUFE,
			"das Material wandert ab Stufe %d mit" % EtchingEffects.CHISEL_MATERIAL_STUFE)
		assert_eq(line.contains("Rune"), stufe >= EtchingEffects.CHISEL_RUNE_STUFE,
			"die Rune ab Stufe %d" % EtchingEffects.CHISEL_RUNE_STUFE)

## Über der obersten Sprosse gibt es nichts mehr: eine Reihe von acht darf keine
## "Stufe 8" versprechen, die die Leiter gar nicht hat.
func test_the_number_line_is_capped_at_the_top_rung() -> void:
	assert_eq(Engraving.stufe_text(Engraving.NOTCH, 9),
		Engraving.stufe_text(Engraving.NOTCH, EtchingEffects.MAX_STUFE))

# --- Runen: die Reihe zählt Anwendungen, nicht Stärke ---------------------------

func test_a_rune_line_counts_its_applications() -> void:
	var id := Engraving.RUNE_PREFIX + Rune.AFTERGLOW
	assert_false(Engraving.stufe_text(id, 1).contains("×"), "eine einzelne Setzung zählt nicht")
	for runs in [2, 3, 6, 8]:
		assert_true(Engraving.stufe_text(id, runs).contains("%d×" % runs),
			"%d Anwendungen - ungedeckelt, die Reihe darf länger als sechs werden" % runs)

# --- Material und Sonderposten steigen nicht -------------------------------------

func test_material_and_specials_have_no_ladder() -> void:
	for id: String in [DieMaterial.GOLD, DieMaterial.BONE, DieMaterial.COPPER,
			Engraving.POINTER]:
		for stufe in [1, 3, 6]:
			assert_eq(Engraving.stufe_text(id, stufe), "",
				"%s skaliert nicht - der Grundtext gilt" % id)

## Jedes Icon der Presse hat entweder eine Stufen-Zeile oder eine description -
## ein Leser darf beim Überfahren nie stumm bleiben.
func test_every_press_icon_says_something() -> void:
	for sort: String in PhantomPress.ICONS:
		for face in PhantomPress.FACE_COUNT:
			var id := PhantomPress.icon_of(sort, face)
			var archetype := Engraving.by_id(id)
			assert_not_null(archetype, "%s hat einen Archetyp" % id)
			var line := Engraving.stufe_text(id, 3)
			if line == "":
				line = archetype.description
			assert_ne(line, "", "%s sagt auf Stufe 3 etwas" % id)
