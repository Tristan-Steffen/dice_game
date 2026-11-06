extends GutTest
## Die eigenen Modul-Modelle: fester Aufbau, Grenzen des Aufbaus und die Lage im Bild.

const REACH := ComboPartBody.SIDE * 0.5
const PLATFORM_TOP := 0.345
## Macht zeigt sich in der Höhe, nicht in der Farbe.
const RISE_BUDGET := {
	ComboPart.RARITY_COMMON: 0.10,
	ComboPart.RARITY_RARE: 0.15,
	ComboPart.RARITY_EPIC: 0.20,
	ComboPart.RARITY_LEGENDARY: 0.25,
}

func _body(part_id: String) -> ComboPartBody:
	var body := ComboPartBody.new()
	add_child_autofree(body)
	body.setup(ComboPart.make(part_id))
	return body

## Die Platine ist breiter als ein Modul, sie trägt zwei Buchsen.
func _modules() -> Array[ComboPart]:
	var out: Array[ComboPart] = []
	for part in ComboPart.all():
		if not ComboPartBody.is_riser(part):
			out.append(part)
	return out

func test_every_part_has_its_own_model_with_the_fixed_nodes() -> void:
	for part in ComboPart.all():
		if not ComboPartBody.is_riser(part):
			assert_string_contains(ComboPartBody.model_path(part), part.id)
		var body := _body(part.id)
		for node_name in ["Stecker", "Gehaeuse", "Plattform", "Korpus"]:
			assert_not_null(body.find_child(node_name, true, false), "%s: %s" % [part.id, node_name])
		if not ComboPartBody.is_riser(part):
			assert_not_null(body.find_child("Licht", true, false), "%s: Licht" % part.id)

func test_a_part_without_its_own_model_keeps_the_basic_housing() -> void:
	var unknown := ComboPart.new()
	unknown.id = "ohne_modell"
	assert_eq(ComboPartBody.model_path(unknown), ComboPartBody.MODULE_SCENE)
	assert_eq(ComboPartBody.model_path(ComboPart.make(ComboPart.EXPANSION_BOARD)), ComboPartBody.RISER_SCENE)

func test_the_superstructure_stays_inside_its_limits() -> void:
	for part in _modules():
		var id := part.id
		var body := _body(id)
		for node_name in ["Korpus", "Licht"]:
			var mesh := body.find_child(node_name, true, false) as MeshInstance3D
			var box := mesh.get_aabb()
			assert_true(absf(box.position.x) <= REACH and absf(box.end.x) <= REACH, "%s %s x" % [id, node_name])
			assert_true(absf(box.position.z) <= REACH and absf(box.end.z) <= REACH, "%s %s z" % [id, node_name])
			assert_lte(box.end.y - PLATFORM_TOP, RISE_BUDGET[part.rarity] + 0.001, "%s %s Höhe" % [id, node_name])

func test_the_platform_hints_the_rarity_and_the_light_the_phase() -> void:
	var part := ComboPart.magnetron()
	var body := _body(ComboPart.MAGNETRON)
	var plate := (body.find_child("Plattform", true, false) as MeshInstance3D).material_override as StandardMaterial3D
	var light := (body.find_child("Licht", true, false) as MeshInstance3D).material_override as StandardMaterial3D
	assert_eq(plate.albedo_color, ComboPartBody.PLATE_STEEL.lerp(part.rarity_color(), ComboPartBody.PLATE_RARITY_SHARE))
	assert_true(plate.vertex_color_use_as_albedo, "das Licht ist eingemalt")
	assert_eq(light.emission, part.tint())
	body.set_dimmed(true)
	assert_eq(plate.albedo_color, ComboPartBody.DIM_ALBEDO)

func test_the_rarities_stay_apart_on_the_platform() -> void:
	var legendary := ComboPartBody.PLATE_STEEL.lerp(ComboPart.RARITY_COLORS[ComboPart.RARITY_LEGENDARY], ComboPartBody.PLATE_RARITY_SHARE)
	var rare := ComboPartBody.PLATE_STEEL.lerp(ComboPart.RARITY_COLORS[ComboPart.RARITY_RARE], ComboPartBody.PLATE_RARITY_SHARE)
	assert_gt(legendary.r, rare.r)
	assert_gt(rare.b, legendary.b)

func test_a_module_on_a_turned_chip_reads_upright() -> void:
	var chip := ComboChipView.new()
	add_child_autofree(chip)
	chip.rotation.y = -PI / 2.0
	chip.combo_key = DiceScoring.TWO_KIND
	chip.setup(10.0, 4.0)
	chip.set_sockets([ComboPart.cross_bridge(), null, null])
	var body := chip._sockets[0]["body"] as ComboPartBody
	assert_almost_eq(body.global_basis.z.z, 1.0, 0.001, "der Pfeil zeigt im Bild nach rechts")
