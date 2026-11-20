extends GutTest
## Die Hülle eines Pakets: EIN Grundriß für Karten-Paket, Schale und Beutel, Sorte als Farbe.
## Das Karten-Paket kommt aus der Welt seines Datenträgers (Lochtasche, Kassettenfach,
## Tonhülle, Blister) und zeigt vorn die Karte, die es garantiert; das Würfel-Paket ist eine
## Schale mit sechs Mulden unter einer Klarsicht-Haube.

func _hull(pack_sort: String, pack_size: int, dice := false,
		quality := DicePack.QUALITY_STANDARD, front: Pack = null) -> CardPackView:
	var hull := CardPackView.new()
	add_child_autofree(hull)
	hull.setup_pack(pack_sort, pack_size, dice, quality, front)
	hull.set_body_scale(PackDrawerView.CASSETTE_SCALE)
	return hull

func _marks(hull: CardPackView) -> int:
	var count := 0
	for child in hull.find_child("Hull0", true, false).get_children():
		if String(child.name).begins_with("Mark"):
			count += 1
	return count

## Das EINE Netz des Karten-Pakets.
func _pack_mesh(hull: CardPackView) -> MeshInstance3D:
	return (hull.find_child("Cassette", true, false) as Node3D).find_children("*",
		"MeshInstance3D", true, false)[0] as MeshInstance3D

## Breite, Länge, Höhe des Pakets (Roh-Maß).
func _shell(hull: CardPackView) -> Vector3:
	var model := hull.find_child("Cassette", true, false) as Node3D
	var mesh := _pack_mesh(hull)
	var box := (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
	# glTF: Blender (x, y, z) liegt als (x, z, -y).
	return Vector3(box.size.x, box.size.z, box.size.y)

## Die Mitte des Pakets in Welt - im eigenen Raum gemessen, gekippte Hüllkästen wüchsen
## sonst schief.
func _center(hull: CardPackView) -> Vector3:
	var model := hull.find_child("Cassette", true, false) as Node3D
	var mesh := _pack_mesh(hull)
	var box := (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
	return model.global_transform * box.get_center()

## Die Materialien, die das Paket trägt.
func _materials(hull: CardPackView) -> Array:
	var mesh := _pack_mesh(hull)
	var out: Array = []
	for surface in mesh.get_surface_override_material_count():
		out.append(mesh.get_surface_override_material(surface))
	return out

## Die Halter der Treppe (je einer eine echte Karte, "Card").
func _stair(hull: CardPackView) -> Array[Node]:
	return hull.find_children("StairCard*", "Node3D", true, false)

func _stair_card(holder: Node) -> DataCellView:
	return holder.get_node("Card") as DataCellView

## Wie viele Teile mit diesem Namensanfang sichtbar sind.
func _visible_parts(hull: CardPackView, prefix: String) -> int:
	var count := 0
	for mesh: MeshInstance3D in hull.find_children(prefix + "*", "MeshInstance3D", true, false):
		if mesh.visible:
			count += 1
	return count

## Die Lage der Zelle: x Breite, y Kopf, z Deckel-Normale.
func _cell_basis(hull: CardPackView) -> Basis:
	return (hull.find_child("Hull0", true, false) as Node3D).global_basis

## EIN Grundriß und EINE Dicke für jede Sorte und Kartenzahl (Zierteile ragen eine Spur vor).
func test_every_card_pack_has_one_footprint_and_one_thickness() -> void:
	var foot := Vector2(DataCellView.WIDTH, DataCellView.HEIGHT) * CardPackView.FOOT_ROOM
	for pack_sort: String in CardPack.SORTS:
		for pack_size in CardPack.CARD_SIZES:
			var box := _shell(_hull(pack_sort, pack_size))
			assert_almost_eq(box.x, foot.x, 0.02, "%s quer" % pack_sort)
			assert_almost_eq(box.y, foot.y, 0.02, "%s längs" % pack_sort)
			assert_almost_eq(box.z, CardPackView.CASSETTE_THICKNESS, 0.045, "%s dick" % pack_sort)

func test_the_hull_is_a_touch_bigger_than_a_lying_card() -> void:
	var box := _shell(_hull(CardPack.SORT_NUMBER, 0))
	assert_gt(box.x, DataCellView.WIDTH)
	assert_gt(box.y, DataCellView.HEIGHT)
	assert_lt(box.y, DataCellView.HEIGHT * ShopController.PLACE_ROOM, "paßt in den Stellplatz")

## Je Sorte und Kartenzahl liegt ein Modell bereit.
func test_every_sort_and_count_has_its_model() -> void:
	for pack_sort: String in CardPack.SORTS:
		for count in [3, 4, 5]:
			assert_not_null(CardPackView.pack_model(pack_sort, count), "%s %d" % [pack_sort, count])

## Im Inneren liegt je Option eine echte Karte in der Sorte des Pakets, und keine ragt
## durch Boden, Deckel oder Wand.
func test_the_stair_lies_inside_the_pack() -> void:
	var half := Vector2(DataCellView.WIDTH, DataCellView.HEIGHT) * CardPackView.FOOT_ROOM * 0.5
	var bottom := -DataCellView.DEPTH * 0.5
	for pack_sort: String in CardPack.SORTS:
		var rank := Pack.SHELF_ORDER.find(CardPackView.stair_shelf(pack_sort))
		for pack_size in CardPack.CARD_SIZES:
			var hull := _hull(pack_sort, pack_size)
			var holders := _stair(hull)
			assert_eq(holders.size(), CardPack.option_count(pack_size), "eine Karte je Option")
			var last_z := -INF
			for holder: Node3D in holders:
				var card := _stair_card(holder)
				assert_eq(card.sort, CardPackView.stair_shelf(pack_sort), pack_sort)
				var thick := float(DataCellView.CARRIER_TOPS[rank]) * card.body_scale() \
					* holder.basis.get_scale().z
				assert_gt(holder.position.z, bottom, "%s über dem Boden" % pack_sort)
				assert_lt(holder.position.z + thick, bottom + CardPackView.CASSETTE_THICKNESS,
					"%s unter dem Deckel" % pack_sort)
				assert_gt(holder.position.z, last_z, "jede liegt höher als die davor")
				last_z = holder.position.z
				var reach := Vector2(DataCellView.WIDTH, DataCellView.HEIGHT) * card.body_scale() * 0.5
				assert_lt(reach.x, half.x, "%s quer" % pack_sort)
				assert_lt(absf(holder.position.y) + reach.y, half.y, "%s längs" % pack_sort)

## Die VORDERSTE Karte ist die des Pakets, mit ihrem Netz; die übrigen sind leer.
func test_the_front_card_shows_the_pack_card() -> void:
	for pack_sort: String in CardPack.SORTS:
		var card_pack := CardPack.make(pack_sort, CardPack.SIZE_NORMAL, DicePack.QUALITY_ROYAL)
		var shown := card_pack.front_card()
		var hull := _hull(pack_sort, card_pack.size, false, card_pack.quality, shown)
		var front := hull.front_cell()
		assert_eq(front, _stair_card(_stair(hull).back()), "die oberste Karte")
		assert_eq(front.stamp_net, shown.stamp_net, "%s: ihr Netz" % pack_sort)
		assert_eq(front.tier, shown.tier, "ihre Größe")
		assert_eq(front.sort, Pack.shelf_of(shown), "ihre Sorte")
		for holder in _stair(hull).slice(0, -1):
			assert_eq(_stair_card(holder).stamp_net, StampNet.empty_net(), "darunter leer")

## Stehend bleibt die Treppe, wo sie ist.
func test_standing_keeps_the_stair() -> void:
	var hull := _hull(CardPack.SORT_NUMBER, CardPack.SIZE_LARGE)
	var flat: Array[Transform3D] = []
	for holder: Node3D in _stair(hull):
		flat.append(holder.transform)
	hull.set_standing(true)
	hull._set_hover_share(0.7)
	var holders := _stair(hull)
	for i in holders.size():
		assert_eq((holders[i] as Node3D).transform, flat[i], "die Treppe rührt sich nicht")

## Der Sortendruck trägt Hover und Flare; die GÜTE ist Folie bzw. Metall.
func test_the_print_carries_sort_and_quality() -> void:
	for pack_sort: String in CardPack.SORTS:
		var seen := {}
		for quality in DicePack.QUALITIES:
			var hull := _hull(pack_sort, CardPack.SIZE_NORMAL, false, quality)
			var materials := _materials(hull)
			assert_true(materials.has(hull._edge_material) or materials.has(hull._core_material),
				"%s: Sortenfarbe" % pack_sort)
			assert_false(materials.has(null), "jede Fläche hat ihr Material")
			var marks := []
			for material in materials:
				if material != hull._edge_material and material != hull._core_material:
					marks.append(material.albedo_color)
			seen[marks] = true
		assert_eq(seen.size(), DicePack.QUALITIES.size(), "%s: jede Güte liest anders" % pack_sort)

## Die GÜTE liest an JEDEM Paket gleich: Standard ohne Zeichen; Edel und Royal tragen die
## Schärpe mit ihrem Namen, und die Hülle schimmert silbern bzw. golden.
func test_every_pack_shows_its_quality_the_same_way() -> void:
	var hulls := {}
	for pack_sort: String in CardPack.SORTS:
		hulls[pack_sort] = false
	hulls[DicePack.SORT_NORMAL] = true
	for pack_sort: String in hulls:
		var model := "Case" if hulls[pack_sort] else "Cassette"
		var plain := _hull(pack_sort, 1, hulls[pack_sort], DicePack.QUALITY_STANDARD)
		assert_null(plain.find_child("QualitySash", true, false), "%s: Standard ohne" % pack_sort)
		for mesh: MeshInstance3D in (plain.find_child(model, true, false) as Node3D) \
				.find_children("*", "MeshInstance3D", true, false):
			assert_null(mesh.material_overlay, "%s: Standard schimmert nicht" % pack_sort)
		for quality in [DicePack.QUALITY_FINE, DicePack.QUALITY_ROYAL]:
			var hull := _hull(pack_sort, 1, hulls[pack_sort], quality)
			var sash := hull.find_child("QualitySash", true, false) as Node3D
			assert_not_null(sash, "%s: Schärpe ab Edel" % pack_sort)
			assert_eq((sash.get_node("Name") as Label3D).text, CardPackView.SASH_NAMES[quality])
			assert_eq(((sash.get_node("Band") as MeshInstance3D).material_override
				as StandardMaterial3D).albedo_color, CardPackView.QUALITY_TINTS[quality])
			for mesh: MeshInstance3D in (hull.find_child(model, true, false) as Node3D) \
					.find_children("*", "MeshInstance3D", true, false):
				var shimmer := mesh.material_overlay as ShaderMaterial
				assert_not_null(shimmer, "%s: die Hülle schimmert" % pack_sort)
				assert_eq(shimmer.get_shader_parameter("tint"), CardPackView.QUALITY_TINTS[quality],
					"silbern bzw. golden")
				assert_eq(float(shimmer.get_shader_parameter("glitter")) > 0.0,
					quality == DicePack.QUALITY_ROYAL, "nur Royal funkelt")

func test_the_sort_reads_as_colour() -> void:
	assert_eq(_hull(CardPack.SORT_MATERIAL, 1).tint,
		PackDrawerView.COLORS[Engraving.CATEGORY_MATERIAL])
	assert_eq(_hull(CardPack.SORT_SPECIAL, 1).tint, PackDrawerView.COLORS[Pack.SHELF_SPECIAL])
	assert_eq(_hull(DicePack.SORT_SOUL, 1, true).tint,
		PackDrawerView.dice_pack_tint(DicePack.SORT_SOUL))

func test_a_dice_pack_is_the_tray_in_its_colour() -> void:
	for pack_sort: String in DicePack.SORTS:
		var hull := _hull(pack_sort, 4, true)
		assert_not_null(hull.find_child("Case", true, false), "die Schale aus Blender")
		var tray := (hull.find_child("Schale", true, false) as MeshInstance3D).material_override \
			as StandardMaterial3D
		assert_eq(tray.albedo_color, PackDrawerView.dice_pack_tint(pack_sort),
			"%s: die Schale trägt die Sortenfarbe" % pack_sort)
		for part in ["DruckBand", "AugeKopf4_0"]:
			assert_eq((hull.find_child(part, true, false) as MeshInstance3D).material_override,
				hull._edge_material, "%s: %s trägt Hover und Flare" % [pack_sort, part])
		var names := 0
		for mesh: MeshInstance3D in hull.find_children("SchwarzSorte_*", "MeshInstance3D", true,
				false):
			if mesh.visible:
				names += 1
				assert_true(String(mesh.name).ends_with("_" + pack_sort), "der eigene Name")
		assert_eq(names, 1, "%s: genau ein Name auf der Banderole" % pack_sort)

func test_the_band_tints_are_the_card_colours() -> void:
	assert_eq(PackDrawerView.dice_pack_tint(DicePack.SORT_MATERIAL),
		PackDrawerView.card_pack_tint(CardPack.SORT_MATERIAL), "Material: dieselbe Farbe wie die Karten")
	assert_eq(PackDrawerView.dice_pack_tint(DicePack.SORT_RUNE),
		PackDrawerView.card_pack_tint(CardPack.SORT_RUNE), "Runen: dieselbe Farbe wie die Karten")
	assert_eq(PackDrawerView.dice_pack_tint(DicePack.SORT_SOUL), Color("#a66bff"))
	assert_eq(PackDrawerView.DICE_PACK_TINTS.size(), DicePack.SORTS.size())

## Das kürzere Maß des Grundrisses: die Breite (auch Riesig ist schmaler als lang).
func _across(hull: CardPackView) -> float:
	var lo := Vector3.ONE * INF
	var hi := -Vector3.ONE * INF
	for corner in hull.case_outline_local():
		lo = lo.min(corner)
		hi = hi.max(corner)
	var span := hi - lo
	return minf(span.x, span.z) if span.y < 0.001 else minf(minf(span.x, span.y), span.z)

## Jedes Paket hat dieselbe Schale; so viele Mulden sind gefüllt, wie die Grundzahl sagt, und
## Banderole und Kopf tragen sie als Augen.
func test_every_size_is_one_tray_and_fills_its_wells() -> void:
	var widths: Array[float] = []
	for pack_size in DicePack.SIZES:
		var hull := _hull(DicePack.SORT_RUNE, pack_size, true)
		widths.append(_across(hull))
		assert_eq(CardPackView.case_pips(pack_size), pack_size)
		assert_eq(hull.tray_dice_shown(), pack_size, "%der: so viele Würfel in den Mulden" % pack_size)
		assert_eq(_shown(hull, "Muldenboden"), 6, "%der: alle sechs Mulden sichtbar" % pack_size)
		assert_eq(_shown(hull, "AugeKopf"), pack_size, "%der: Augen am Kopf" % pack_size)
		assert_eq(_shown(hull, "AugeBand"), pack_size, "%der: Augen auf der Banderole" % pack_size)
	for width in widths:
		assert_almost_eq(width, widths[0], 0.0001, "jede Schale gleich breit")

## Die Würfel einer Mulde sprechen ihre Sorte: nur deren Zeichnung steht.
func test_the_dice_in_the_wells_show_their_sort() -> void:
	for pack_sort: String in DicePack.SORTS:
		var hull := _hull(pack_sort, 6, true)
		for mesh: MeshInstance3D in hull.find_children("Deko*", "MeshInstance3D", true, false):
			assert_eq(mesh.visible, String(mesh.name).contains("_%s_" % pack_sort),
				"%s: %s" % [pack_sort, mesh.name])

func _quality_hull(quality: int, pack_size := CardPack.SIZE_NORMAL,
		pack_sort := DicePack.SORT_NORMAL) -> CardPackView:
	var hull := CardPackView.new()
	add_child_autofree(hull)
	hull.setup_pack(pack_sort, pack_size, true, quality)
	return hull

func _shown(hull: CardPackView, prefix: String) -> int:
	var count := 0
	for mesh: MeshInstance3D in hull.find_children(prefix + "*", "MeshInstance3D", true, false):
		if mesh.visible:
			count += 1
	return count

## Die GÜTE ist die Prägefolie auf der Banderole: weißer Druck, Silber, Gold.
func test_the_foil_tells_the_quality_of_a_tray() -> void:
	var foils := []
	for quality in [DicePack.QUALITY_STANDARD, DicePack.QUALITY_FINE, DicePack.QUALITY_ROYAL]:
		var hull := _quality_hull(quality)
		var foil := (hull.find_child("PraegungBandA", true, false) as MeshInstance3D) \
			.material_override as StandardMaterial3D
		assert_eq(foil, hull._foil_material())
		foils.append(foil)
	assert_lt(foils[0].metallic, foils[1].metallic, "Edel ist Metall")
	assert_gt(foils[2].albedo_color.r, foils[2].albedo_color.b + 0.3, "Royal ist Gold")
	assert_almost_eq(foils[1].albedo_color.r, foils[1].albedo_color.b, 0.1, "Edel ist Silber")

func test_nothing_on_the_tray_pulses() -> void:
	var royal := _quality_hull(DicePack.QUALITY_ROYAL)
	assert_false(royal.is_processing(), "Royal steht still")

func _global_box(mesh: MeshInstance3D) -> AABB:
	return mesh.global_transform * mesh.get_aabb()

## Kein Teil der Schatulle teilt eine Fläche mit einem anderen (Band über dem Lack, das
## Zeichen über dem Band) - sonst flimmerte sie.
func test_no_two_case_parts_share_a_face() -> void:
	for pack_sort: String in DicePack.SORTS:
		for pack_size in DicePack.SIZES:
			var hull := _quality_hull(DicePack.QUALITY_ROYAL, pack_size, pack_sort)
			var meshes: Array[MeshInstance3D] = []
			for mesh: MeshInstance3D in hull.find_children("*", "MeshInstance3D", true, false):
				if mesh.is_visible_in_tree():
					meshes.append(mesh)
			var fights: Array[String] = []
			for i in meshes.size():
				for j in range(i + 1, meshes.size()):
					var a := meshes[i]
					var b := meshes[j]
					if a.material_override == b.material_override and a.material_override != null:
						continue
					if _share_face(_global_box(a), _global_box(b)):
						fights.append("%s/%s" % [a.name, b.name])
			assert_eq(fights, [] as Array[String], "%s Größe %d" % [pack_sort, pack_size])

func _share_face(a: AABB, b: AABB) -> bool:
	for axis in 3:
		for side in 2:
			var fa: float = a.end[axis] if side == 1 else a.position[axis]
			var fb: float = b.end[axis] if side == 1 else b.position[axis]
			if absf(fa - fb) > 0.0005:
				continue
			var overlap := true
			for other in 3:
				if other == axis:
					continue
				if minf(a.end[other], b.end[other]) - maxf(a.position[other], b.position[other]) <= 0.0005:
					overlap = false
			if overlap:
				return true
	return false

func test_footprint_and_height_of_the_case() -> void:
	var hull := _hull(DicePack.SORT_NORMAL, CardPack.SIZE_SMALL, true)
	assert_almost_eq(hull.thickness(), CardPackView.DICE_THICKNESS, 0.0001)
	assert_lte(hull.rise_depth(), CardPackView.lying_height(PackDrawerView.CASSETTE_SCALE))

func test_it_rises_by_its_own_height() -> void:
	var hull := _hull(CardPack.SORT_RUNE, 2)
	assert_almost_eq(hull.rise_depth(), hull.thickness() * PackDrawerView.CASSETTE_SCALE, 0.0001)
	assert_lte(hull.rise_depth(), CardPackView.lying_height(PackDrawerView.CASSETTE_SCALE),
		"die Schächte messen am dicksten Paket")
	assert_gt(hull.rise_depth(), DataCellView.lying_over(PackDrawerView.CASSETTE_SCALE),
		"ein Paket ist dicker als eine Karte")

func test_the_hood_and_the_upper_band_hang_on_the_hinge() -> void:
	var hull := _hull(DicePack.SORT_MATERIAL, CardPack.SIZE_LARGE, true)
	var hinge := hull.find_child("Scharnier", true, false)
	assert_not_null(hinge, "die Schale hat ein Scharnier")
	for part in ["Haube", "BanderoleDeckel", "DruckBand", "SchwarzMarke", "AugeBand4_0"]:
		var node := hull.find_child(part, true, false)
		assert_not_null(node, part)
		assert_true(hinge.is_ancestor_of(node), "%s geht mit der Haube auf" % part)
	for part in ["Boden", "Schale", "BanderoleBoden", "Wuerfel0", "AugeKopf4_0"]:
		var node := hull.find_child(part, true, false)
		assert_not_null(node, part)
		assert_false(hinge.is_ancestor_of(node), "%s bleibt am Boden" % part)
	assert_eq((hull.find_child("Haube", true, false) as MeshInstance3D).material_override,
		hull._film_material(), "die Haube ist Klarsichtfolie")
	assert_null(_hull(CardPack.SORT_NUMBER, 1).find_child("Scharnier", true, false),
		"die Schachtel hat keine Haube")

func test_burst_takes_the_hull_away() -> void:
	var hull := _hull(CardPack.SORT_NUMBER, 1)
	hull.burst()
	await wait_seconds(DataCellView.DEMATERIALIZE_TIME + 0.1)
	assert_false(hull.visible, "aufgebrochen ist die Hülle fort")

## Zwei Flächen verschiedener Teile in DERSELBEN Ebene, gleich gerichtet und überlappend,
## streiten im Tiefenpuffer - das Flimmern der Kassette im Lager.
func _coplanar_fights(hull: CardPackView) -> Array[String]:
	var boxes: Array[MeshInstance3D] = []
	for child in hull.find_child("Hull0", true, false).get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
			boxes.append(child)
	var fights: Array[String] = []
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a := boxes[i]
			var b := boxes[j]
			if a.material_override == b.material_override:
				continue
			var ha: Vector3 = (a.mesh as BoxMesh).size * 0.5
			var hb: Vector3 = (b.mesh as BoxMesh).size * 0.5
			for axis in 3:
				for side: float in [-1.0, 1.0]:
					if absf((a.position[axis] + side * ha[axis]) - (b.position[axis] + side * hb[axis])) > 0.0005:
						continue
					var overlap := true
					for other in 3:
						if other == axis:
							continue
						var lo := maxf(a.position[other] - ha[other], b.position[other] - hb[other])
						var hi := minf(a.position[other] + ha[other], b.position[other] + hb[other])
						if hi - lo <= 0.0005:
							overlap = false
					if overlap:
						fights.append("%s/%s" % [a.name, b.name])
	return fights

func test_no_two_cassette_parts_share_a_face() -> void:
	for pack_sort: String in CardPack.SORTS:
		for pack_size in CardPack.CARD_SIZES:
			var fights := _coplanar_fights(_hull(pack_sort, pack_size))
			assert_eq(fights, [] as Array[String], "%s Größe %d" % [pack_sort, pack_size])

# --- Der ESD-BEUTEL des Modul-Pakets ------------------------------------------------

func _bag(pack_size: int, grade: int) -> CardPackView:
	var bag := CardPackView.new()
	add_child_autofree(bag)
	bag.setup_module_bag(pack_size, grade)
	bag.set_body_scale(PackDrawerView.CASSETTE_SCALE)
	return bag

func _bag_parts(bag: CardPackView, prefix: String) -> int:
	return bag.find_children(prefix + "*", "", true, false).size()

func test_the_bag_shares_the_one_footprint_and_grows_only_in_thickness() -> void:
	var cassette := Vector2(DataCellView.WIDTH, DataCellView.HEIGHT) * CardPackView.FOOT_ROOM
	var last := 0.0
	for pack_size in CardPack.SIZES:
		var bag := _bag(pack_size, ModulePack.GRADE_COMMON)
		var film := ((bag.find_child("Film", true, false) as MeshInstance3D).mesh as BoxMesh).size
		var seal := ((bag.find_child("Seal", true, false) as MeshInstance3D).mesh as BoxMesh).size
		assert_almost_eq(film.y, cassette.y, 0.001, "dieselbe Länge wie jede Hülle")
		assert_almost_eq(film.x + seal.x, cassette.x, 0.001, "Folie und Naht füllen die Breite")
		assert_gt(bag.thickness(), last, "die Größe macht ihn dicker")
		last = bag.thickness()
	assert_lte(last, CardPackView.lying_height(1.0), "nie höher als die höchste Hülle")

func test_the_bag_carries_grade_stripe_label_and_contacts() -> void:
	for pack_size in CardPack.SIZES:
		var bag := _bag(pack_size, ModulePack.GRADE_EPIC)
		assert_true(bag.module_bag)
		assert_eq(bag.tint, ModulePack.grade_tint(ModulePack.GRADE_EPIC), "Streifen = Stufe")
		assert_eq(_bag_parts(bag, "Contact"), CardPack.option_count(pack_size),
			"goldene Kontakte = Grund-Optionen")
		assert_eq(_bag_parts(bag, "Ridge"), CardPackView.BAG_RIDGES, "Quetschrillen")
		assert_not_null(bag.find_child("Notch", true, false), "die Reißkerbe")
		assert_eq((bag.find_child("Esd", true, false) as Label3D).text, "ESD")

func test_tearing_writes_the_end_state_first() -> void:
	var bag := _bag(CardPack.SIZE_NORMAL, 0)
	var strip := bag.find_child("TearStrip", true, false) as Node3D
	assert_true(strip.visible)
	assert_gt(bag.tear_open(), 0.0)
	assert_true(bag.torn(), "gerissen ist er sofort")
	bag.set_torn(true)
	assert_false(strip.visible, "hart gesetzt ist der Streifen fort")
	assert_eq(bag.case_outline_local().size(), 4, "sein Grundriß trägt die Einzugs-Sektion")

# --- HOCHKANT im LAGER ---------------------------------------------------------------

## Stehend hängt die Hülle unter ihrem Rücken: der Ursprung ist oben, die Fläche zeigt
## nach Bild-rechts (+Z), die lange Seite senkrecht.
func test_a_standing_pack_hangs_below_its_spine() -> void:
	var hull := _hull(CardPack.SORT_NUMBER, CardPack.SIZE_LARGE)
	hull.rotation.y = -PI / 2.0  # wie scene_root._spawn_hull
	hull.add_spine()
	hull.stand_on(Vector3.ZERO)
	var length := DataCellView.HEIGHT * CardPackView.FOOT_ROOM * PackDrawerView.CASSETTE_SCALE
	var center := _center(hull)
	assert_almost_eq(center.y, -length * 0.5, 0.01, "die Mitte eine halbe Länge tief")
	assert_almost_eq(center.z, 0.0, 0.03, "mittig im Platz")
	assert_gt(_cell_basis(hull).z.normalized().z, 0.99, "die Fläche zeigt nach Bild-rechts")
	assert_gt(_cell_basis(hull).y.normalized().y, 0.99, "der Kopf zeigt nach oben")
	assert_null(hull.find_child("Spine", true, false), "der Kopfdruck liest von selbst")
	assert_true(hull.standing())

## Der Griff hebt sie aus der Rinne und legt ihre Fläche zur Kamera - über dem Filz.
func test_hover_presents_the_face_above_the_felt() -> void:
	var hull := _hull(CardPack.SORT_RUNE, CardPack.SIZE_NORMAL)
	hull.rotation.y = -PI / 2.0  # wie scene_root._spawn_hull
	hull.stand_on(Vector3.ZERO)
	hull._set_hover_share(CardPackView.PRESENT_RISE_SHARE)
	var length := DataCellView.HEIGHT * CardPackView.FOOT_ROOM * PackDrawerView.CASSETTE_SCALE
	assert_gt(_center(hull).y - length * 0.5, 0.0, "gehoben steht sie ganz über dem Filz")
	hull._set_hover_share(1.0)
	assert_gt(_cell_basis(hull).z.normalized().y, 0.99, "gekippt liegt die Fläche oben")
	assert_gt(_center(hull).y, 0.0, "über dem Filz")
	for share in [0.6, 0.7, 0.8, 0.9]:
		hull._set_hover_share(share)
		var turn := _cell_basis(hull)
		var low := _center(hull).y - absf(turn.y.normalized().y) * length * 0.5 \
			- absf(turn.z.normalized().y) * hull.thickness() * PackDrawerView.CASSETTE_SCALE * 0.5
		assert_gt(low, 0.0, "beim Kippen taucht kein Ende unter den Filz (%.1f)" % share)

## Hinlegen gibt die gewohnte Liege-Lage byteweise zurück; der Grundriß kennt nur sie.
func test_lying_down_restores_the_lying_pose() -> void:
	var lying := _hull(DicePack.SORT_NORMAL, CardPack.SIZE_HUGE, true)
	lying.lie_on_glass(Vector3.ZERO)
	var body: Node3D = lying.get_node("Body")
	var rest := body.transform
	var outline := lying.case_outline_local()
	lying.stand_on(Vector3.ZERO)
	assert_ne(body.transform, rest)
	assert_eq(lying.case_outline_local(), outline, "der Grundriß gilt liegend, auch im Stand")
	lying.set_standing(false)
	assert_eq(body.transform, rest)

## Weder Schachtel noch Schale tragen eine Rücken-Marke: ihr Kopfdruck liest von selbst.
func test_no_spine_mark_on_cassette_or_case() -> void:
	var cassette := _hull(CardPack.SORT_MATERIAL, CardPack.SIZE_NORMAL)
	cassette.add_spine()
	assert_null(cassette.find_child("Spine", true, false), "der Druck trägt den Rücken")
	var plain := _quality_hull(DicePack.QUALITY_ROYAL)
	plain.add_spine()
	assert_null(plain.find_child("Spine", true, false), "die Augen am Kopf tragen den Rücken")
	var banded := _quality_hull(DicePack.QUALITY_STANDARD, CardPack.SIZE_HUGE, DicePack.SORT_SOUL)
	banded.add_spine()
	assert_null(banded.find_child("Spine", true, false), "auch die Seele keine Marke")

