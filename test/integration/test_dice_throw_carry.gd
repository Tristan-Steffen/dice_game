extends GutTest
## Die Berst-Übernahme des Wurfs (DiceController.throw_slots mit carry): der
## echte Würfel setzt Tempo und Eigendrehung des Taumel-Würfels fort, statt
## Bahn-Lösung und Zufalls-Drall neu zu würfeln; nur Klemmung und Entzerrung
## der Landepunkte korrigieren.

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

func _carry(velocity: Vector3, spin: Vector3) -> Dictionary:
	return {"velocity": velocity, "spin": spin}

func test_der_wurf_setzt_das_berst_tempo_fort() -> void:
	# Liegt der natürliche Auftreffpunkt der Tangente im Wurffeld, reproduziert
	# die Bahn-Lösung das übergebene Tempo EXAKT - kein Bruch beim Loslassen.
	dice.start_transforms[0] = Transform3D(Basis.IDENTITY, Vector3(0.0, 8.0, 0.0))
	var vel := Vector3(1.0, 1.0, 2.0)
	var spin := Vector3(2.0, -3.0, 1.0)
	var carry: Array[Dictionary] = [_carry(vel, spin)]
	dice.throw_slots(_p([0]), 50.0, 3.0, Vector3.ZERO, carry)
	assert_lt(dice.bodies[0].linear_velocity.distance_to(vel), 0.01,
		"das Tempo des Berst-Moments reist unverändert mit")
	assert_lt(dice.bodies[0].angular_velocity.distance_to(spin), 0.001,
		"die Eigendrehung reist mit - kein Zufalls-Drall obendrauf")

func test_die_tangente_wird_ins_wurffeld_geklemmt() -> void:
	# Eine Tangente, die aus der Grube schösse, landet am Feldrand - Richtung
	# bleibt, nur das Maß wird gekappt.
	dice.start_transforms[0] = Transform3D(Basis.IDENTITY, Vector3(0.0, 8.0, 0.0))
	var carry: Array[Dictionary] = [_carry(Vector3(40.0, 0.0, 40.0), Vector3.ZERO)]
	var lands := dice._carry_landings(_p([0]), carry, Vector3.ZERO)
	assert_eq(lands.size(), 1)
	var to: Vector3 = lands[0]["to"]
	assert_lte(to.x, DiceController.CARRY_HALF_X + 0.001, "quer am Feldrand gekappt")
	assert_lte(to.z, DiceController.CARRY_HALF_Z + 0.001, "längs am Feldrand gekappt")
	assert_gt(to.x, 0.0, "die Richtung der Tangente bleibt")
	assert_gt(to.z, 0.0)

func test_zu_nahe_landepunkte_werden_entzerrt() -> void:
	# Zwei fast senkrecht fallende Würfel träfen sich am Aufschlag - die
	# Entzerrung hält den Bahn-Mindestabstand auf der langen Achse.
	dice.start_transforms[0] = Transform3D(Basis.IDENTITY, Vector3(0.0, 8.0, 0.1))
	dice.start_transforms[1] = Transform3D(Basis.IDENTITY, Vector3(0.0, 8.0, -0.1))
	var carry: Array[Dictionary] = [
		_carry(Vector3.ZERO, Vector3.ZERO), _carry(Vector3.ZERO, Vector3.ZERO)]
	var lands := dice._carry_landings(_p([0, 1]), carry, Vector3.ZERO)
	assert_eq(lands.size(), 2)
	var z0: float = lands[0]["to"].z
	var z1: float = lands[1]["to"].z
	assert_gte(absf(z0 - z1), DiceController.DIE_HALF_DIAGONAL * 2.0 - 0.001,
		"Mindestabstand wie zwischen zwei Bahnen von _spread_targets")

func test_ohne_carry_bleibt_der_klassische_wurf() -> void:
	# _rethrow_slot wirft ohne carry nach - der alte Pfad muss unangetastet
	# funktionieren (Bahn-Lösung Richtung Streuziel plus Zufalls-Drall).
	dice.start_transforms[0] = Transform3D(Basis.IDENTITY, Vector3(0.0, 8.0, 0.0))
	dice.throw_slots(_p([0]), 10.0, 1.0)
	assert_gt(dice.bodies[0].linear_velocity.length(), 0.0, "der Wurf startet")
	assert_false(dice.settled[0])
