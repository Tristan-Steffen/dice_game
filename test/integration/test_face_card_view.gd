extends GutTest
## Die SEITEN-AUSKUNFT: drei Fächer - Zahl, Material, Rune(n) - und jede Wertungsart in
## ihrer Grubenfarbe.

var card: FaceCardView

func before_each() -> void:
	card = FaceCardView.new()
	card.size = Vector2(600, 250)
	add_child_autofree(card)

func _die(value: int, material_id := "", level := 1, runes: Array = []) -> DieDefinition:
	var def := DieDefinition.standard()
	def.faces[0] = value
	if material_id != "":
		def.set_face_material(0, material_id)
		def.levels[0] = level
	if runes.size() > 1:
		def.essence_id = Essence.VACUUM
	for i in runes.size():
		def.set_rune(0, runes[i], i, 2)
	return def

func test_every_material_and_rune_has_its_effect() -> void:
	for material in DieMaterial.all():
		assert_true(FaceCardView.MATERIAL_EFFECTS.has(material.id), material.display_name)
	for rune in Rune.all():
		assert_true(FaceCardView.RUNE_EFFECTS.has(rune.id), rune.display_name)

func test_each_scoring_kind_has_its_own_colour() -> void:
	var kinds := [FaceCardView.KIND_BASE, FaceCardView.KIND_MULT, FaceCardView.KIND_CRIT,
		FaceCardView.KIND_MONEY, FaceCardView.KIND_ENERGY]
	for i in kinds.size():
		for j in range(i + 1, kinds.size()):
			var a := FaceCardView.kind_color(kinds[i])
			var b := FaceCardView.kind_color(kinds[j])
			var apart := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
			assert_gt(apart, 0.35, "%s gegen %s" % [kinds[i], kinds[j]])

func test_glass_reads_the_eyes_of_its_face() -> void:
	assert_eq(FaceCardView.material_effect(DieMaterial.GLASS, 1, 9)[0], "+6", "höchstens 6")
	assert_eq(FaceCardView.material_effect(DieMaterial.GLASS, 2, 7)[0], "×3,5")
	assert_eq(FaceCardView.material_effect(DieMaterial.GLASS, 2, 8)[0], "×4")
	assert_true(FaceCardView.material_effect("", 0, 3).is_empty())

func test_three_slots_for_a_full_face() -> void:
	card.show_face(_die(560, DieMaterial.AMBER, 2, [Rune.STRAY_LIGHT]), 0)
	assert_eq((card.get_node("Zahl/Wert") as Label).text, "560", "die ganze Zahl")
	assert_not_null(card.get_node_or_null("Material/Seite"), "die Würfelseite als Grund")
	assert_eq((card.get_node("Material/Platte/Wert") as Label).text, "5×")
	assert_eq((card.get_node("Material/Name") as Label).text, "Bernstein · veredelt")
	assert_eq((card.get_node("Runen/Rune0/Wert") as Label).text, "+$1")
	assert_eq((card.get_node("Runen/Rune0/Wert") as Label).get_theme_color("font_color"),
		FaceCardView.kind_color(FaceCardView.KIND_MONEY), "Geld in der Grubenfarbe")

func test_a_plain_face_says_what_is_missing() -> void:
	card.show_face(_die(3), 0)
	assert_not_null(card.get_node_or_null("Material/Ohne"))
	assert_not_null(card.get_node_or_null("Runen/Ohne"))

func test_several_runes_share_the_slot() -> void:
	card.show_face(_die(12, DieMaterial.COPPER, 1,
		[Rune.BURN_IN, Rune.SPARK_FLIGHT, Rune.STRAY_LIGHT]), 0)
	for i in 3:
		assert_not_null(card.get_node_or_null("Runen/Rune%d" % i), "Streifen %d" % i)

func test_only_a_change_rebuilds() -> void:
	var def := _die(5, DieMaterial.RUBY)
	card.show_face(def, 0)
	var slot := card.get_node("Zahl")
	card.show_face(def, 0)
	assert_same(card.get_node("Zahl"), slot)
	card.show_face(null, -1)
	assert_eq(card.get_child_count(), 0, "ohne Seite leer")
