extends GutTest
## Ein Würfel wird nie zweimal gezeigt. Wer sichtbar in der Grube liegt, hat auf
## der Werkbank nichts zu suchen - die Auskunft darüber gibt die Grube selbst
## (visible_slot_defs), und sie MELDET jeden Wechsel, statt abgefragt zu werden.

var dice: DiceController
var defs: Array[DieDefinition]

func before_each() -> void:
	var roots: Array[Node3D] = []
	var bodies: Array[RigidBody3D] = []
	var displays: Array[DieFaceDisplay] = []
	for i in 3:
		var die: Node3D = DieBuilder.build()
		add_child_autofree(die)
		roots.append(die)
		bodies.append(die.get_node("RigidBody3D"))
		displays.append(die.get_node("RigidBody3D/Faces"))
	dice = DiceController.new(roots, bodies, displays)
	defs = [DieDefinition.standard(), DieDefinition.standard(), DieDefinition.standard()]
	dice.set_slot_defs(defs)

# --- Was liegt sichtbar in der Grube? ----------------------------------------------

func test_a_fresh_pit_shows_nothing() -> void:
	assert_eq(dice.visible_slot_defs().size(), 0, "vor dem Wurf liegt nichts")

func test_only_the_visible_slots_count() -> void:
	dice.roots[0].visible = true
	dice.roots[2].visible = true
	var lying := dice.visible_slot_defs()
	assert_eq(lying.size(), 2)
	assert_true(lying.has(defs[0]))
	assert_true(lying.has(defs[2]))
	assert_false(lying.has(defs[1]), "der unsichtbare Rest-Slot liegt nicht mit")

func test_it_reports_the_LIVING_instances() -> void:
	# Nur so kann die Werkbank ihre Zwinge wiedererkennen - verglichen wird das
	# Exemplar, nie ein Wert.
	dice.roots[1].visible = true
	assert_same(dice.visible_slot_defs()[0], defs[1])

func test_the_reset_empties_it_again() -> void:
	dice.roots[0].visible = true
	dice.reset()
	assert_eq(dice.visible_slot_defs().size(), 0)

# --- Die Meldung -------------------------------------------------------------------

func test_setting_the_slot_defs_announces_itself() -> void:
	watch_signals(dice)
	dice.set_slot_defs(defs)
	assert_signal_emitted(dice, "pit_contents_changed")

func test_the_reset_announces_itself() -> void:
	watch_signals(dice)
	dice.reset()
	assert_signal_emitted(dice, "pit_contents_changed")

func test_a_foreign_write_reports_by_hand() -> void:
	# Die Grube hat keinen zweiten Weg, ihren Bestand bekanntzugeben.
	watch_signals(dice)
	dice.roots[0].visible = true
	dice.note_pit_changed()
	assert_signal_emitted(dice, "pit_contents_changed")
