extends GutTest
## Die Hülle eines Pakets: EIN Grundriß, Sorte als Farbe; die Kassette wächst in die Dicke.

func _hull(pack_sort: String, pack_size: int, dice := false) -> CardPackView:
	var hull := CardPackView.new()
	add_child_autofree(hull)
	hull.setup_pack(pack_sort, pack_size, dice)
	hull.set_body_scale(PackDrawerView.CASSETTE_SCALE)
	return hull

func _marks(hull: CardPackView) -> int:
	var count := 0
	for child in hull.find_child("Hull0", true, false).get_children():
		if String(child.name).begins_with("Mark"):
			count += 1
	return count

func _shell(hull: CardPackView) -> Vector3:
	return ((hull.find_child("Shell", true, false) as MeshInstance3D).mesh as BoxMesh).size

func _edges(hull: CardPackView) -> int:
	var count := 0
	for child in hull.find_child("Hull0", true, false).get_children():
		if String(child.name).begins_with("CardEdge"):
			count += 1
	return count

func test_every_pack_has_one_footprint() -> void:
	var footprints := {}
	for pack_sort: String in CardPack.SORTS:
		for pack_size in CardPack.SIZES:
			var box := _shell(_hull(pack_sort, pack_size))
			footprints[Vector2(box.x, box.y)] = true
	assert_eq(footprints.size(), 1, "EIN Grundriß - Karten- wie Würfel-Pakete")

func test_the_hull_is_a_touch_bigger_than_a_lying_card() -> void:
	var box := _shell(_hull(CardPack.SORT_NUMBER, 0))
	assert_gt(box.x, DataCellView.WIDTH)
	assert_gt(box.y, DataCellView.HEIGHT)
	assert_lt(box.y, DataCellView.HEIGHT * ShopController.SLIT_ROOM, "paßt in den Stellplatz")

func test_a_cassette_grows_in_thickness_and_shows_one_edge_per_option() -> void:
	var last := 0.0
	for pack_size in CardPack.SIZES:
		var hull := _hull(CardPack.SORT_MATERIAL, pack_size)
		assert_gt(_shell(hull).z, last, "größer heißt dicker")
		last = _shell(hull).z
		assert_eq(_edges(hull), CardPack.option_count(pack_size))
	assert_null(_hull(CardPack.SORT_MATERIAL, CardPack.SIZE_SMALL).find_child("Band", true, false))
	assert_not_null(_hull(CardPack.SORT_MATERIAL, CardPack.SIZE_NORMAL).find_child("Band", true,
		false))
	assert_not_null(_hull(CardPack.SORT_MATERIAL, CardPack.SIZE_LARGE).find_child("FrameTop",
		true, false))
	assert_not_null(_hull(CardPack.SORT_MATERIAL, CardPack.SIZE_HUGE).find_child("Corner0",
		true, false), "Riesig trägt Goldecken")

func test_the_sort_reads_as_colour() -> void:
	assert_eq(_hull(CardPack.SORT_MATERIAL, 1).tint,
		PackDrawerView.COLORS[Engraving.CATEGORY_MATERIAL])
	assert_eq(_hull(DicePack.SORT_SOUL, 1, true).tint,
		PackDrawerView.dice_pack_tint(DicePack.SORT_SOUL))
	var mixed := _hull(CardPack.SORT_MIXED, 1)
	var first := (mixed.find_child("CardEdge0", true, false) as MeshInstance3D).material_override
	var second := (mixed.find_child("CardEdge1", true, false) as MeshInstance3D).material_override
	assert_ne(first, second, "Misch zeigt Kanten in den Regal-Farben")

func _visible_pips(hull: CardPackView) -> int:
	var count := 0
	for mesh: MeshInstance3D in hull.find_children("Auge?", "MeshInstance3D", true, false):
		if mesh.visible:
			count += 1
	return count

func test_a_dice_pack_is_the_case_with_a_tinted_seam() -> void:
	var hull := _hull(DicePack.SORT_POWER, CardPack.SIZE_NORMAL, true)
	assert_not_null(hull.find_child("Case", true, false), "die Schatulle aus Blender")
	var seam := hull.find_child("Naht", true, false) as MeshInstance3D
	assert_not_null(seam)
	var paint := seam.material_override as StandardMaterial3D
	assert_eq(paint.emission, DataCellView._scaled(PackDrawerView.dice_pack_tint(
		DicePack.SORT_POWER), 1.0), "die Naht trägt die Sortenfarbe")
	var other := _hull(DicePack.SORT_SOUL, CardPack.SIZE_NORMAL, true)
	assert_ne(((other.find_child("Naht", true, false) as MeshInstance3D).material_override
		as StandardMaterial3D).emission, paint.emission, "jede Sorte ihre Farbe")

func test_the_case_shows_the_base_count_in_pips() -> void:
	for pack_size in CardPack.SIZES:
		assert_eq(_visible_pips(_hull(DicePack.SORT_MIXED, pack_size, true)),
			DicePack.base_count(pack_size), "Augen = Grundzahl")
	var hull := _hull(DicePack.SORT_MIXED, CardPack.SIZE_SMALL, true)
	hull.set_pips(5)
	assert_eq(_visible_pips(hull), 5, "eine Auswahl mit Beigabe setzt nach")
	hull.set_pips(9)
	assert_eq(_visible_pips(hull), 5, "mehr als fünf Augen hat der Deckel nicht")

func _pip_metal(hull: CardPackView) -> StandardMaterial3D:
	return (hull.find_child("Auge0", true, false) as MeshInstance3D).material_override \
		as StandardMaterial3D

func test_the_metal_tells_the_quality_not_the_size() -> void:
	var steel := _quality_hull(DicePack.QUALITY_STANDARD, CardPack.SIZE_HUGE)
	var gold := _quality_hull(DicePack.QUALITY_FINE, CardPack.SIZE_SMALL)
	var royal := _quality_hull(DicePack.QUALITY_ROYAL, CardPack.SIZE_NORMAL)
	assert_ne(_pip_metal(steel).albedo_color, CasinoStyle.GOLD, "Riesig heißt kein Gold mehr")
	assert_eq(_pip_metal(gold).albedo_color, CasinoStyle.GOLD, "Edel trägt Gold")
	assert_eq(_pip_metal(royal).emission, DicePack.quality_tint(DicePack.QUALITY_ROYAL),
		"Royal schimmert violett")
	assert_lt(_pip_metal(royal).albedo_color.get_luminance(),
		_pip_metal(steel).albedo_color.get_luminance(), "Royal ist dunkles Chrom")
	var schliesse := royal.find_child("Schliesse", true, false) as MeshInstance3D
	if schliesse != null:
		assert_eq(schliesse.material_override, _pip_metal(royal), "Schließe und Augen ein Metall")

func test_only_the_royal_seam_pulses() -> void:
	var royal := _quality_hull(DicePack.QUALITY_ROYAL, CardPack.SIZE_NORMAL)
	var seam := (royal.find_child("Naht", true, false) as MeshInstance3D).material_override \
		as StandardMaterial3D
	var first := seam.emission_energy_multiplier
	await wait_seconds(0.4)
	assert_ne(seam.emission_energy_multiplier, first, "die Royal-Naht pulst")
	var plain := _quality_hull(DicePack.QUALITY_FINE, CardPack.SIZE_NORMAL)
	assert_false(plain.is_processing(), "Stahl und Gold stehen still")

func _quality_hull(quality: int, pack_size: int) -> CardPackView:
	var hull := CardPackView.new()
	add_child_autofree(hull)
	hull.setup_pack(DicePack.SORT_MIXED, pack_size, true, quality)
	return hull

func test_footprint_and_height_of_the_case() -> void:
	var hull := _hull(DicePack.SORT_MIXED, CardPack.SIZE_SMALL, true)
	assert_almost_eq(hull.thickness(), CardPackView.DICE_THICKNESS, 0.0001)
	assert_lte(hull.rise_depth(), CardPackView.lying_height(PackDrawerView.CASSETTE_SCALE))

func test_it_rises_by_its_own_height() -> void:
	var hull := _hull(CardPack.SORT_RUNE, 2)
	assert_almost_eq(hull.rise_depth(), hull.thickness() * PackDrawerView.CASSETTE_SCALE, 0.0001)
	assert_lte(hull.rise_depth(), CardPackView.lying_height(PackDrawerView.CASSETTE_SCALE),
		"die Schächte messen am dicksten Paket")
	assert_gt(hull.rise_depth(), DataCellView.lying_over(PackDrawerView.CASSETTE_SCALE),
		"ein Paket ist dicker als eine Karte")

func test_the_case_has_a_hinged_lid_and_a_velvet_interior() -> void:
	var hull := _hull(DicePack.SORT_MIXED, CardPack.SIZE_LARGE, true)
	assert_true(hull.has_lid(), "die Schatulle hat ein Scharnier")
	var hinge := hull.find_child("Scharnier", true, false)
	for part in ["Deckel", "Lasche", "Auge0", "AugeMulde0"]:
		var node := hull.find_child(part, true, false)
		assert_not_null(node, part)
		assert_true(hinge.is_ancestor_of(node), "%s hängt am Deckel" % part)
	assert_false(hinge.is_ancestor_of(hull.find_child("Naht", true, false)),
		"die Naht bleibt am Boden")
	var velvet := 0
	for part in ["Boden", "Deckel"]:
		var mesh := hull.find_child(part, true, false) as MeshInstance3D
		for i in mesh.mesh.get_surface_count():
			if mesh.get_surface_override_material(i) == hull._velvet_material():
				velvet += 1
	assert_eq(velvet, 2, "Boden und Deckel sind innen mit Samt ausgekleidet")
	assert_false(_hull(CardPack.SORT_NUMBER, 1).has_lid(), "die Kassette hat keinen Deckel")

func test_opening_swings_the_lid_up() -> void:
	var hull := _hull(DicePack.SORT_MIXED, CardPack.SIZE_LARGE, true)
	hull.lie_on_glass(Vector3.ZERO)
	await wait_frames(1)
	# Auge2 sitzt auf der Seite der Schließe, fern vom Scharnier.
	var pip := hull.find_child("Auge2", true, false) as Node3D
	var closed := pip.global_position
	hull.set_lid_open(1.0)
	assert_gt(pip.global_position.y, closed.y + 1.0, "der Deckel steht auf")
	hull.set_lid_open(0.0)
	assert_almost_eq(pip.global_position.distance_to(closed), 0.0, 0.001, "zu ist zu")
	assert_almost_eq(hull.swing_lid(true), CardPackView.LID_TIME, 0.0001)
	assert_true(hull.lid_swinging())
	await wait_seconds(CardPackView.LID_TIME + 0.1)
	assert_almost_eq(hull.lid_share(), 1.0, 0.001)

func test_the_interior_lies_inside_the_outline() -> void:
	var hull := _hull(DicePack.SORT_MIXED, CardPack.SIZE_HUGE, true)
	hull.rotation.y = -PI / 2.0
	hull.lie_on_glass(Vector3.ZERO)
	var inner := hull.case_interior_local()
	var outer := hull.case_outline_local()
	assert_eq(inner.size(), 4)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for corner in outer:
		var at := hull.global_transform * corner
		lo = Vector2(minf(lo.x, at.x), minf(lo.y, at.z))
		hi = Vector2(maxf(hi.x, at.x), maxf(hi.y, at.z))
	var ilo := Vector2(INF, INF)
	var ihi := Vector2(-INF, -INF)
	for corner in inner:
		var at := hull.global_transform * corner
		assert_gt(at.y, 0.0, "der Samt liegt über dem Glas")
		ilo = Vector2(minf(ilo.x, at.x), minf(ilo.y, at.z))
		ihi = Vector2(maxf(ihi.x, at.x), maxf(ihi.y, at.z))
	assert_gt(ilo.x, lo.x)
	assert_gt(ilo.y, lo.y)
	assert_lt(ihi.x, hi.x)
	assert_lt(ihi.y, hi.y)
	# Ein Würfel in DIE_SCALE paßt durch den Mund, und geschlossen deckt der Deckel ihn ganz.
	var edge := DieBuilder.HALF_EXTENT * 2.0 * DiceTrayView.DIE_SCALE
	var span := ihi - ilo
	assert_gte(minf(span.x, span.y), edge)
	var floor_y := (hull.global_transform * inner[0]).y
	var top := hull.thickness() * hull.body_scale()
	assert_lt(floor_y + edge, top, "die Würfel passen unter den Deckel")

func test_burst_takes_the_hull_away() -> void:
	var hull := _hull(CardPack.SORT_NUMBER, 1)
	hull.burst()
	await wait_seconds(DataCellView.DEMATERIALIZE_TIME + 0.1)
	assert_false(hull.visible, "aufgebrochen ist die Hülle fort")
