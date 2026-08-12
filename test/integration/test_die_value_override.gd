extends GutTest
## Anzeige-Überschreibung der oberen Seite (DiceController.set_value_overrides)
## an ECHTEN DieBuilder-Würfeln. Zwei Quellen, ein Mechanismus: Verwandlungs-
## Charms zeigen den wirksamen Wert GRÜN (vorläufig), der Wertwandel während des
## Zählens zeigt ihn normal (dauerhaft). Rein Anzeige - values bleibt unberührt.

const TOP_FACE := 3  # DiceController.AXIS_FACE_INDEX["OBEN"]

var dice: DiceController

func _p(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func before_each() -> void:
	var roots: Array[Node3D] = []
	var bodies: Array[RigidBody3D] = []
	var displays: Array[DieFaceDisplay] = []
	for i in 2:
		var die: Node3D = DieBuilder.build()
		add_child_autofree(die)
		roots.append(die)
		bodies.append(die.get_node("RigidBody3D"))
		displays.append(die.get_node("RigidBody3D/Faces"))
	dice = DiceController.new(roots, bodies, displays)
	var defs: Array[DieDefinition] = [DieDefinition.standard(), DieDefinition.standard()]
	dice.set_slot_defs(defs)
	dice.face_indices = _p([TOP_FACE, TOP_FACE])
	dice.values = _p([defs[0].faces[TOP_FACE], defs[1].faces[TOP_FACE]])

func _top_label(slot: int) -> Label3D:
	var display := dice.face_displays[slot]
	for axis in display.labels:
		if DiceController.AXIS_FACE_INDEX[axis] == TOP_FACE:
			return display.labels[axis]
	return null

func test_the_green_is_the_same_one_the_workbench_uses() -> void:
	# "Grün heißt vorläufig" muss überall dasselbe Grün sein.
	assert_eq(PressNetView.PREVIEW_UP, DieFaceDisplay.PREVIEW_NUMBER_COLOR)

func test_override_writes_the_top_face_in_green() -> void:
	dice.set_value_overrides({0: 6})
	assert_eq(_top_label(0).text, "6")
	assert_eq(_top_label(0).modulate, DieFaceDisplay.PREVIEW_NUMBER_COLOR, "vorläufig = grün")
	assert_eq(_top_label(1).text, "4", "der Nachbar bleibt bei seinem Def-Wert")
	assert_eq(_top_label(1).modulate, DieFaceDisplay.NUMBER_COLOR)

func test_override_leaves_the_other_faces_alone() -> void:
	dice.set_value_overrides({0: 6})
	var display := dice.face_displays[0]
	for axis in display.labels:
		if DiceController.AXIS_FACE_INDEX[axis] == TOP_FACE:
			continue
		assert_eq(display.labels[axis].modulate, DieFaceDisplay.NUMBER_COLOR,
			"nur die obere Seite ist überschrieben (%s)" % axis)

func test_untinted_override_keeps_the_normal_number_color() -> void:
	# Der Wertwandel beim Zählen ist DAUERHAFT - er darf nicht wie eine Vorschau
	# aussehen.
	dice.set_value_overrides({0: 8}, false)
	assert_eq(_top_label(0).text, "8")
	assert_eq(_top_label(0).modulate, DieFaceDisplay.NUMBER_COLOR)

func test_clearing_restores_the_definition_value() -> void:
	dice.set_value_overrides({0: 6})
	dice.clear_value_overrides()
	assert_eq(_top_label(0).text, "4")
	assert_eq(_top_label(0).modulate, DieFaceDisplay.NUMBER_COLOR)

func test_override_never_touches_the_scored_values() -> void:
	dice.set_value_overrides({0: 6})
	assert_eq(dice.values, _p([4, 4]), "die Wertung liest weiter, was gewürfelt wurde")

func test_a_slot_without_a_rolled_face_shows_nothing_new() -> void:
	dice.face_indices = _p([TOP_FACE, -1])
	dice.set_value_overrides({1: 6})
	assert_eq(_top_label(1).text, "4", "ohne obere Seite gibt es keine Ziffer zu heben")

func test_refresh_faces_re_applies_the_override() -> void:
	# _on_pool_changed zeichnet die Würfel neu - die Überschreibung muss überleben,
	# sonst malt der Refresh den rohen Wert zurück.
	dice.set_value_overrides({0: 6})
	dice.refresh_faces()
	assert_eq(_top_label(0).text, "6")

func test_throwing_a_slot_drops_its_override() -> void:
	dice.set_value_overrides({0: 6, 1: 6})
	dice.throw_slots(_p([0]), 10.0, 1.0)
	assert_false(dice.value_overrides.has(0), "der geworfene Würfel verliert seine Vorschau")
	assert_true(dice.value_overrides.has(1), "der gehaltene behält sie")

func test_reset_clears_every_override() -> void:
	dice.set_value_overrides({0: 6})
	dice.reset()
	assert_true(dice.value_overrides.is_empty())
