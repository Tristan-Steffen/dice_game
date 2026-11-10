extends GutTest
## Die Hülle eines Pakets: EINE Größe für alle, Sorte als Farbe, Größe als Striche.

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

func test_every_pack_has_the_same_hull() -> void:
	var sizes := {}
	for pack_sort: String in CardPack.SORTS:
		for pack_size in CardPack.max_size(pack_sort) + 1:
			var shell := _hull(pack_sort, pack_size).find_child("Shell", true, false) \
				as MeshInstance3D
			sizes[(shell.mesh as BoxMesh).size] = true
	for pack_sort: String in DicePack.SORTS:
		var dice_shell := _hull(pack_sort, CardPack.SIZE_HUGE, true).find_child("Shell", true,
			false) as MeshInstance3D
		sizes[(dice_shell.mesh as BoxMesh).size] = true
	assert_eq(sizes.size(), 1, "EINE Größe je Ding - Karten- wie Würfel-Pakete")

func test_the_hull_is_a_touch_bigger_than_a_lying_card() -> void:
	var shell := _hull(CardPack.SORT_NUMBER, 0).find_child("Shell", true, false) \
		as MeshInstance3D
	var box := (shell.mesh as BoxMesh).size
	assert_gt(box.x, DataCellView.WIDTH)
	assert_gt(box.y, DataCellView.HEIGHT)
	assert_lt(box.y, DataCellView.HEIGHT * ShopController.SLIT_ROOM, "paßt in den Stellplatz")

func test_the_size_reads_as_marks() -> void:
	for pack_size in CardPack.SIZES:
		assert_eq(_marks(_hull(CardPack.SORT_MATERIAL, pack_size)), pack_size + 1)

func test_the_sort_reads_as_colour() -> void:
	assert_eq(_hull(CardPack.SORT_MATERIAL, 1).tint,
		PackDrawerView.COLORS[Engraving.CATEGORY_MATERIAL])
	assert_eq(_hull(DicePack.SORT_SOUL, 1, true).tint,
		PackDrawerView.dice_pack_tint(DicePack.SORT_SOUL))
	var mixed := _hull(CardPack.SORT_MIXED, 1)
	assert_not_null(mixed.find_child("Seal0", true, false), "Misch trägt drei Farbstreifen")

func test_a_dice_pack_carries_pips_instead_of_a_seal() -> void:
	var hull := _hull(DicePack.SORT_POWER, 2, true)
	assert_not_null(hull.find_child("Pip0", true, false), "die Würfel-Kennung")
	assert_null(hull.find_child("Seal", true, false))
	assert_eq(_marks(hull), 3, "die Größe liest wie bei den Karten-Paketen")

func test_it_rises_by_its_own_height() -> void:
	var hull := _hull(CardPack.SORT_RUNE, 2)
	assert_almost_eq(hull.rise_depth(),
		CardPackView.lying_height(PackDrawerView.CASSETTE_SCALE), 0.0001)
	assert_gt(hull.rise_depth(), DataCellView.lying_over(PackDrawerView.CASSETTE_SCALE),
		"ein Paket ist dicker als eine Karte")

func test_burst_takes_the_hull_away() -> void:
	var hull := _hull(CardPack.SORT_NUMBER, 1)
	hull.burst()
	await wait_seconds(DataCellView.DEMATERIALIZE_TIME + 0.1)
	assert_false(hull.visible, "aufgebrochen ist die Hülle fort")
