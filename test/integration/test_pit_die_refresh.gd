extends GutTest
## Was ein Zug an den Würfel-Defs ändert, muss an den LIEGENDEN Grubenwürfeln
## sofort zu sehen sein: Knochen wächst, Glas schrumpft, Radon frisst sich an.
## Der Weg dahin ist apply_take_effects -> note_pool_changed -> refresh_faces,
## und er trägt nur, weil slot_defs dieselben Instanzen sind wie owned_pool.

const TOP_FACE := 3  # DiceController.AXIS_FACE_INDEX["OBEN"]

var dice: DiceController
var defs: Array[DieDefinition]

func _p(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _m(values: Array) -> Array[String]:
	var typed: Array[String] = []
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
	defs = [DieDefinition.standard(), DieDefinition.standard()]
	dice.set_slot_defs(defs)
	dice.face_indices = _p([TOP_FACE, TOP_FACE])
	dice.values = _p([defs[0].faces[TOP_FACE], defs[1].faces[TOP_FACE]])

## Die Ziffer, die der Würfel in slot auf seiner OBEREN Seite zeigt.
func _shown(slot: int) -> String:
	var display: DieFaceDisplay = dice.face_displays[slot]
	for axis: String in display.labels:
		if DiceController.AXIS_FACE_INDEX[axis] == TOP_FACE:
			return (display.labels[axis] as Label3D).text
	return ""

func _take(materials: Array[String], participating: Array[int]) -> MaterialEffects.TakeReport:
	return MaterialEffects.apply_take_effects(defs, dice.face_indices, materials, participating,
		[] as Array[String], -1, {}, participating, false, participating)

# --- Knochen/Glas: der Wertwandel steht sofort auf dem Würfel ----------------------

func test_bone_growth_shows_on_the_lying_die() -> void:
	defs[0].set_face_material(TOP_FACE, DieMaterial.BONE)
	var before: int = defs[0].faces[TOP_FACE]
	var report := _take(_m([DieMaterial.BONE, ""]), _p([0]))
	assert_eq(report.grown, [0] as Array[int], "Knochen ist gewachsen")
	assert_gt(defs[0].faces[TOP_FACE], before, "die Def trägt den neuen Wert")
	dice.refresh_faces()
	assert_eq(_shown(0), str(defs[0].faces[TOP_FACE]), "und der liegende Würfel zeigt ihn")

func test_glass_shrink_shows_on_the_lying_die() -> void:
	defs[0].set_face_material(TOP_FACE, DieMaterial.GLASS)
	var before: int = defs[0].faces[TOP_FACE]
	var report := _take(_m([DieMaterial.GLASS, ""]), _p([0]))
	assert_eq(report.shrunk, [0] as Array[int], "Glas hat sich gefressen")
	assert_lt(defs[0].faces[TOP_FACE], before)
	dice.refresh_faces()
	assert_eq(_shown(0), str(defs[0].faces[TOP_FACE]))

func test_an_untouched_die_keeps_its_number() -> void:
	var before := _shown(1)
	defs[0].set_face_material(TOP_FACE, DieMaterial.BONE)
	_take(_m([DieMaterial.BONE, ""]), _p([0]))
	dice.refresh_faces()
	assert_eq(_shown(1), before, "der unbeteiligte Würfel bleibt, wie er lag")

# --- Radon: der Zerfall reitet auf dem Auslöser ------------------------------------

func test_radon_decays_in_the_take_that_triggers_it() -> void:
	defs[0].essence_id = Essence.RADON
	var before := 0
	for value in defs[0].faces:
		before += value
	var report := _take(_m(["", ""]), _p([0]))
	assert_eq(report.decayed, [0] as Array[int], "der Zerfall fällt in DIESEN Zug")
	var after := 0
	for value in defs[0].faces:
		after += value
	assert_eq(after, before - 1, "genau ein Auge weniger")

func test_radon_that_never_played_does_not_decay() -> void:
	# Der Zerfall reitet auf dem Auslöser: wer nicht mitwertet, zerfällt nicht.
	defs[1].essence_id = Essence.RADON
	var before := defs[1].faces.duplicate()
	var report := _take(_m(["", ""]), _p([0]))
	assert_eq(report.decayed.size(), 0)
	assert_eq(defs[1].faces, before, "der liegengebliebene Radon-Würfel bleibt heil")

func test_a_soulless_die_never_decays() -> void:
	var before := defs[0].faces.duplicate()
	var report := _take(_m(["", ""]), _p([0]))
	assert_eq(report.decayed.size(), 0)
	assert_eq(defs[0].faces, before)

func test_the_decay_shows_on_the_lying_dice() -> void:
	defs[0].essence_id = Essence.RADON
	_take(_m(["", ""]), _p([0]))
	dice.refresh_faces()
	for face in 6:
		if face == TOP_FACE:
			assert_eq(_shown(0), str(defs[0].faces[TOP_FACE]),
				"was die Def sagt, steht auf dem Würfel")
