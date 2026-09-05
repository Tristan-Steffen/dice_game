extends GutTest
## Tier-1-Tests des DieDefinition-Datensatzes. Kern ist der Unabhängigkeits-
## Vertrag von instantiate(): jeder in Besitz genommene Würfel (Kauf, Belohnung)
## MUSS eine eigene Kopie mit eigenem faces-Array bekommen, sonst verändert eine
## spätere Ätzung/ein Upgrade versehentlich alle Würfel, die dieselbe Definition
## teilen (siehe DieDefinition-Klassenkommentar, EtchingEffects, scene_root:
## owned_pool). Genau diese Annahme sichern die folgenden Tests ab.

func test_standard_has_default_faces():
	assert_eq(DieDefinition.standard().faces, [1, 2, 3, 4, 5, 6])

func test_fixed_sets_all_faces_and_meta():
	var die := DieDefinition.fixed(6, "Immer 6")
	assert_eq(die.faces, [6, 6, 6, 6, 6, 6])
	assert_eq(die.style_id, "fixed_6")
	assert_eq(die.display_name, "Immer 6")

func test_instantiate_preserves_values():
	var original := DieDefinition.fixed(4, "Immer 4")
	var copy := original.instantiate()
	assert_eq(copy.faces, original.faces, "Werte werden übernommen")
	assert_eq(copy.style_id, original.style_id)
	assert_eq(copy.display_name, original.display_name)

func test_instantiate_returns_new_instance():
	var original := DieDefinition.standard()
	var copy := original.instantiate()
	assert_ne(original.get_instance_id(), copy.get_instance_id(), "eigene Instanz")

func test_mutating_copy_does_not_touch_original():
	var original := DieDefinition.standard()
	var copy := original.instantiate()
	copy.faces[0] = 99
	assert_eq(original.faces[0], 1, "Original bleibt unverändert")
	assert_eq(copy.faces[0], 99, "Kopie trägt die Änderung")

func test_mutating_original_does_not_touch_copy():
	var original := DieDefinition.standard()
	var copy := original.instantiate()
	original.faces[5] = 42
	assert_eq(copy.faces[5], 6, "Kopie bleibt unverändert")

func test_two_standards_are_independent():
	# owned_pool wird aus lauter DieDefinition.standard() aufgebaut - jede muss
	# eine eigene Instanz mit eigenem faces-Array sein.
	var a := DieDefinition.standard()
	var b := DieDefinition.standard()
	a.faces[2] = 7
	assert_eq(b.faces[2], 3, "zweite Standard-Definition unberührt")

func test_standard_has_no_materials():
	assert_eq(DieDefinition.standard().materials, ["", "", "", "", "", ""])

func test_instantiate_copies_materials_independently():
	# Derselbe Unabhängigkeits-Vertrag wie für faces: ein Material auf der Kopie
	# darf nie auf dem Original (oder anderen Kopien) erscheinen.
	var original := DieDefinition.standard()
	original.materials[2] = DieMaterial.RUBY
	var copy := original.instantiate()
	assert_eq(copy.materials[2], DieMaterial.RUBY, "Material wird übernommen")
	copy.materials[0] = DieMaterial.GOLD
	assert_eq(original.materials[0], "", "Original bleibt unverändert")

func test_standard_has_no_essence():
	assert_eq(DieDefinition.standard().essence_id, "", "Startwürfel sind seelenlos")

func test_instantiate_copies_the_essence_independently():
	var original := DieDefinition.standard()
	original.essence_id = Essence.ARGON
	var copy := original.instantiate()
	assert_eq(copy.essence_id, Essence.ARGON, "die Essenz wird übernommen")
	copy.essence_id = Essence.NEON
	assert_eq(original.essence_id, Essence.ARGON, "Original bleibt unverändert")

# --- Ladung -----------------------------------------------------------------------

func test_a_fresh_die_is_cold_and_whole():
	var die := DieDefinition.standard()
	assert_eq(die.charge, 0)
	assert_false(die.burned_out)

func test_charge_names_are_one_source():
	assert_eq(DieDefinition.charge_name(0), "kalt")
	assert_eq(DieDefinition.charge_name(1), "Glimmen")
	assert_eq(DieDefinition.charge_name(2), "Kriechstrom")
	assert_eq(DieDefinition.charge_name(DieDefinition.CHARGE_MAX), "Überschlag")
	assert_eq(DieDefinition.charge_name(99), "Überschlag", "geklemmt statt außerhalb")

func test_charge_up_climbs_to_the_cap():
	var die := DieDefinition.standard()
	assert_false(die.charge_up(), "kein Durchbrennen auf dem Weg")
	assert_eq(die.charge, 1)
	die.charge_up()
	die.charge_up()
	assert_eq(die.charge, DieDefinition.CHARGE_MAX)
	assert_false(die.burned_out)

func test_charge_up_at_the_cap_burns_the_die():
	var die := DieDefinition.standard()
	die.charge = DieDefinition.CHARGE_MAX
	assert_true(die.charge_up(), "an der Spitze brennt er durch")
	assert_true(die.burned_out)
	assert_eq(die.charge, 0, "er trägt keine Ladung mehr")

func test_an_immune_die_holds_at_the_cap():
	var die := DieDefinition.standard()
	die.charge = DieDefinition.CHARGE_MAX
	assert_false(die.charge_up(DieDefinition.CHARGE_MAX, true))
	assert_false(die.burned_out)
	assert_eq(die.charge, DieDefinition.CHARGE_MAX)

func test_a_burned_die_neither_charges_nor_drains():
	var die := DieDefinition.standard()
	die.charge = 2
	die.burn_out()
	assert_false(die.charge_up())
	assert_false(die.charge_down())
	assert_eq(die.charge, 0)

func test_charge_down_stops_at_zero():
	var die := DieDefinition.standard()
	die.charge = 1
	assert_true(die.charge_down())
	assert_eq(die.charge, 0)
	assert_false(die.charge_down(), "kalt bleibt kalt")

func test_repair_clears_the_soot_and_the_charge():
	var die := DieDefinition.standard()
	die.burn_out()
	die.repair()
	assert_false(die.burned_out)
	assert_eq(die.charge, 0)

func test_instantiate_carries_charge_and_soot():
	var original := DieDefinition.standard()
	original.charge = 2
	original.burned_out = true
	var copy := original.instantiate()
	assert_eq(copy.charge, 2)
	assert_true(copy.burned_out)
	copy.charge = 0
	assert_eq(original.charge, 2, "Original bleibt unverändert")

func test_become_carries_charge_and_soot():
	# become schreibt IN die Instanz - eine Kopie ohne die beiden Felder verlöre
	# die Ladung des Würfels beim Tausch.
	var target := DieDefinition.standard()
	target.charge = 3
	var source := DieDefinition.standard()
	source.charge = 1
	source.burned_out = true
	target.become(source)
	assert_eq(target.charge, 1)
	assert_true(target.burned_out)
