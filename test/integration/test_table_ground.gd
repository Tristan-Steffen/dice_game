extends GutTest
## Der endlose Filzboden: Kachel-Geometrie, geteiltes Material, Lage unter dem
## Screen. Die Kachelung ist die Versicherung gegen max_lights_per_object -
## deshalb wird die Mittelkachel (alter Tisch-Fußabdruck) explizit geprüft.

func test_kacheln_decken_die_flaeche_ohne_ueberlappung() -> void:
	var rects := TableGround.tile_rects()
	assert_eq(rects.size(), 9, "3x3-Gitter")
	var area := 0.0
	for rect in rects:
		area += rect.size.x * rect.size.y
	var full := (TableGround.OUTER_HALF.x * 2.0) * (TableGround.OUTER_HALF.y * 2.0)
	assert_almost_eq(area, full, 0.01, "Summe der Kacheln = Gesamtfläche (lückenlos, überlappungsfrei)")

func test_mittelkachel_ist_der_alte_tisch_fussabdruck() -> void:
	var center := Rect2(-TableGround.CENTER_HALF, TableGround.CENTER_HALF * 2.0)
	var found := false
	for rect in TableGround.tile_rects():
		if rect.is_equal_approx(center):
			found = true
	assert_true(found, "eine Kachel deckt exakt den alten Tisch (120x160)")

func test_boden_reicht_weit_ueber_den_alten_tisch_hinaus() -> void:
	assert_gt(TableGround.OUTER_HALF.x, TableGround.CENTER_HALF.x * 2.0)
	assert_gt(TableGround.OUTER_HALF.y, TableGround.CENTER_HALF.y * 2.0)

func test_aufbau_teilt_ein_material_und_liegt_unter_dem_screen() -> void:
	var ground := TableGround.new()
	add_child_autofree(ground)
	await wait_frames(2)
	var tiles: Array[MeshInstance3D] = []
	for child in ground.get_children():
		if child is MeshInstance3D:
			tiles.append(child)
	assert_eq(tiles.size(), 9, "je Kachel ein Mesh")
	assert_lt(TableGround.SURFACE_Y, 0.0, "unter der Screen-Oberfläche (kein Z-Fighting)")
	for tile in tiles:
		assert_eq(tile.material_override, ground.felt_material, "EIN Material, Welt-UVs machen es nahtlos")
		assert_almost_eq(tile.position.y, TableGround.SURFACE_Y, 0.001)
		assert_eq(tile.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

func test_shader_nutzt_weltkoordinaten() -> void:
	var ground := TableGround.new()
	add_child_autofree(ground)
	await wait_frames(2)
	var code: String = ground.felt_material.shader.code
	assert_string_contains(code, "MODEL_MATRIX", "Welt-UVs: Muster läuft nahtlos über Kachelgrenzen")

func test_raum_szene_traegt_den_boden() -> void:
	var room: Node = load("res://scenes/room.tscn").instantiate()
	add_child_autofree(room)
	await wait_frames(2)
	assert_not_null(room.get_node_or_null("TableGround"), "room.tscn stellt den Boden")
	assert_not_null(room.find_child("Screen", true, false), "das Screen-Mesh bleibt erhalten")
