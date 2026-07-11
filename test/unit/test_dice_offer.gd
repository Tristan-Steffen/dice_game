extends GutTest
## Tier-1-Tests der Würfel-Angebots-Erzeugung (DiceOffer). Prüft, dass jedes
## Angebot 1..3 Würfel bündelt und die erzeugten Augen im erlaubten Bereich der
## Vorlage liegen - insbesondere die Regel "mehr Würfel = schwächer" (die
## 3er-Bündel bleiben niedrig, das 2er-Gerade-Bündel nur gerade).

## Sucht eine Vorlage nach style_id (siehe DiceOffer.TEMPLATES).
func _template(style_id: String) -> Dictionary:
	for t in DiceOffer.TEMPLATES:
		if t["style_id"] == style_id:
			return t
	return {}

## Erzeugt so lange Angebote, bis eines mit der gesuchten style_id dabei ist,
## und liefert dessen erzeugten Würfel (die Vorlagen werden zufällig gezogen).
func _sample_die(style_id: String) -> DieDefinition:
	for _attempt in 200:
		for offer in DiceOffer.roll_offers(DiceOffer.TEMPLATES.size()):
			if not offer.dice.is_empty() and offer.dice[0].style_id == style_id:
				return offer.dice[0]
	return null

func test_roll_offers_returns_requested_count():
	assert_eq(DiceOffer.roll_offers(3).size(), 3)
	assert_eq(DiceOffer.roll_offers(1).size(), 1)

func test_offers_have_one_to_three_dice_and_positive_price():
	for offer in DiceOffer.roll_offers(DiceOffer.TEMPLATES.size()):
		assert_between(offer.size(), 1, 3, "1..3 Würfel je Angebot")
		assert_gt(offer.price, 0, "Preis gesetzt")
		for die in offer.dice:
			assert_eq(die.faces.size(), 6, "sechs Seiten je Würfel")

func test_pack_dice_are_all_the_same_type():
	# Ein Angebot bündelt nur EINEN Würfeltyp: gleiche Seiten, nur die Anzahl
	# variiert - aber jeder Würfel ist eine eigene Instanz.
	for offer in DiceOffer.roll_offers(DiceOffer.TEMPLATES.size()):
		var first := offer.dice[0]
		var seen_ids := {}
		for die in offer.dice:
			assert_eq(die.faces, first.faces, "alle Würfel eines Bündels haben dieselben Seiten")
			assert_false(seen_ids.has(die.get_instance_id()), "eigene Instanz je Würfel")
			seen_ids[die.get_instance_id()] = true

func test_dice_carry_a_non_normal_style_id():
	# Gekaufte Würfel müssen "besonders" sein (nicht "normal"), sonst würden sie
	# im Pool verdrängt und nicht als Spezialwürfel behandelt (siehe GameRun).
	for offer in DiceOffer.roll_offers(DiceOffer.TEMPLATES.size()):
		for die in offer.dice:
			assert_ne(die.style_id, "normal")

# --- Veredelungen (Material-Seiten / Kanten, siehe _roll_refinements) -----------

func test_refinement_surcharge_matches_applied_content():
	# Der gemeldete Aufpreis passt exakt zu dem, was auf dem Würfel gelandet ist.
	for i in 60:
		var def := DieDefinition.standard()
		var surcharge: int = DiceOffer._roll_refinements(def)
		var expected := 0
		for material_id in def.materials:
			if material_id != "":
				expected += DiceOffer.FACE_MATERIAL_SURCHARGE
				assert_true(DieMaterial.is_valid_id(material_id), "gültiges Seiten-Material")
		if def.edge_material != "":
			expected += DiceOffer.EDGE_MATERIAL_SURCHARGE
			assert_true(DieMaterial.is_valid_id(def.edge_material), "gültiges Kanten-Material")
		assert_eq(surcharge, expected)

func test_refinements_apply_at_most_two_face_materials():
	for i in 60:
		var def := DieDefinition.standard()
		DiceOffer._roll_refinements(def)
		var count := 0
		for material_id in def.materials:
			if material_id != "":
				count += 1
		assert_lte(count, 2, "höchstens zwei Material-Seiten je Angebots-Würfel")

func test_refinements_appear_sometimes_but_not_always():
	# Über viele Angebote: Veredelungen kommen vor, aber nicht auf jedem Würfel.
	var refined := 0
	var total := 0
	for i in 80:
		var def := DieDefinition.standard()
		DiceOffer._roll_refinements(def)
		total += 1
		if def.edge_material != "" or def.materials.count("") < 6:
			refined += 1
	assert_gt(refined, 0, "Veredelungen tauchen auf")
	assert_lt(refined, total, "aber nicht auf jedem Würfel")

func test_bundle_copies_share_refinements_as_independent_instances():
	# Alle Würfel eines Bündels tragen dieselben Materialien/Kanten (ein Typ je
	# Angebot) - aber als eigene Kopien, damit spätere Gravuren nur einen treffen.
	for attempt in 120:
		for offer in DiceOffer.roll_offers(DiceOffer.TEMPLATES.size()):
			var first := offer.dice[0]
			for die in offer.dice:
				assert_eq(die.materials, first.materials, "gleiche Material-Seiten im Bündel")
				assert_eq(die.edge_material, first.edge_material, "gleiche Kanten im Bündel")
			if offer.size() > 1 and (first.edge_material != "" or first.materials.count("") < 6):
				offer.dice[1].materials[0] = "test_sentinel"
				assert_ne(first.materials[0], "test_sentinel", "Kopien sind unabhängig")
				return  # ein veredeltes Mehrfach-Bündel gefunden und geprüft - fertig
	fail_test("kein veredeltes Mehrfach-Bündel in 120 Versuchen gefunden")

func test_even_bundle_has_two_dice_with_only_even_faces():
	var t := _template("even")
	assert_eq(t["count"], 2, "Gerade Würfel bündelt zwei Würfel")
	var die := _sample_die("even")
	assert_not_null(die)
	for value in die.faces:
		assert_eq(value % 2, 0, "nur gerade Augen (2/4/6)")

func test_low_bundle_has_three_dice_all_below_three():
	var t := _template("low")
	assert_eq(t["count"], 3, "Niedrige Serie bündelt drei Würfel")
	var die := _sample_die("low")
	assert_not_null(die)
	for value in die.faces:
		assert_lt(value, 3, "alle Augen unter 3 (1/2)")

func test_power_die_is_a_single_high_value_die():
	var t := _template("power")
	assert_eq(t["count"], 1, "Kraftwürfel ist ein einzelner Würfel")
	var die := _sample_die("power")
	assert_not_null(die)
	for value in die.faces:
		assert_between(value, 3, 6, "nur hohe Augen (3..6)")

func test_pasch_die_has_at_least_three_equal_faces():
	var die := _sample_die("pasch")
	assert_not_null(die)
	var counts := {}
	for value in die.faces:
		counts[value] = counts.get(value, 0) + 1
	var best := 0
	for c in counts.values():
		best = maxi(best, c)
	assert_gte(best, 3, "mindestens drei gleiche Seiten (garantierter Pasch)")
