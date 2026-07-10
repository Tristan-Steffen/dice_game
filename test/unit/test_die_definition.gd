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
