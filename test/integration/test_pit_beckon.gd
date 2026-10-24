extends GutTest
## Der LOCKRUF der Grube: Wände atmen grün, im Boden steht WÜRFELN.

func test_walls_take_the_beckon_on_every_segment() -> void:
	var pit := DicePit.new()
	add_child_autofree(pit)
	pit.set_beckon(1.0, 0.0, CasinoStyle.GREEN)
	for material in pit.field_materials:
		assert_eq(material.get_shader_parameter("beckon"), 1.0)
		assert_almost_eq(float(material.get_shader_parameter("beckon_glow")), 0.35, 0.001,
			"der Atem fällt nie ganz auf null")
	pit.set_beckon(0.0, 1.0, CasinoStyle.GREEN)
	assert_eq(pit.field_materials[0].get_shader_parameter("beckon_glow"), 0.0, "aus heißt aus")

func test_floor_sign_shows_only_while_beckoning() -> void:
	var screen := TableScreen.new()
	add_child_autofree(screen)
	await wait_frames(1)
	screen.place_pit_window(Rect2(0, 0, 400, 200), 10.0)
	screen.set_pit_beckon(0.0, 1.0, "Klick auf die Grube")
	assert_false(screen.pit_beckon.visible)
	screen.set_pit_beckon(1.0, 1.0, "Klick auf die Grube")
	assert_true(screen.pit_beckon.visible)
	assert_eq((screen.pit_beckon.get_child(0) as Label).text, "WÜRFELN")
	assert_eq((screen.pit_beckon.get_child(1) as Label).text, "Klick auf die Grube")
