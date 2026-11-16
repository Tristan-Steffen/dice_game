extends GutTest
## Die Hülle eines Pakets: EIN Grundriß für Schachtel, Schatulle und Beutel, Sorte als Farbe.
## Das Karten-Paket ist eine bedruckte Pappschachtel mit Fenster, die Schatulle trägt die
## Würfelseite und die Banderole.

func _hull(pack_sort: String, pack_size: int, dice := false,
		quality := DicePack.QUALITY_STANDARD) -> CardPackView:
	var hull := CardPackView.new()
	add_child_autofree(hull)
	hull.setup_pack(pack_sort, pack_size, dice, quality)
	hull.set_body_scale(PackDrawerView.CASSETTE_SCALE)
	return hull

func _marks(hull: CardPackView) -> int:
	var count := 0
	for child in hull.find_child("Hull0", true, false).get_children():
		if String(child.name).begins_with("Mark"):
			count += 1
	return count

## Der Körper der Schachtel ohne Druck: Karton und Lasche.
func _board_parts(model: Node3D) -> Array[MeshInstance3D]:
	var parts: Array[MeshInstance3D] = []
	for part in ["Karton", "Lasche"]:
		parts.append(model.find_child(part, true, false) as MeshInstance3D)
	return parts

## Breite, Länge, Höhe der Schachtel (Roh-Maß, aus Karton und Lasche).
func _shell(hull: CardPackView) -> Vector3:
	var model := hull.find_child("Cassette", true, false) as Node3D
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in _board_parts(model):
		var local := (model.global_transform.affine_inverse() * mesh.global_transform) \
			* mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	# glTF: Blender (x, y, z) liegt als (x, z, -y).
	return Vector3(box.size.x, box.size.z, box.size.y)

## Die Halter der Treppe (je einer eine echte Karte, "Card").
func _stair(hull: CardPackView) -> Array[Node]:
	return hull.find_children("StairCard*", "Node3D", true, false)

func _stair_card(holder: Node) -> DataCellView:
	return holder.get_node("Card") as DataCellView

## Die Mitte der Schachtel in Welt (Karton samt Lasche) - im eigenen Raum gemessen, gekippte
## Hüllkästen wüchsen sonst schief.
func _center(hull: CardPackView) -> Vector3:
	var model := hull.find_child("Cassette", true, false) as Node3D
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in _board_parts(model):
		var local := (model.global_transform.affine_inverse() * mesh.global_transform) \
			* mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return model.global_transform * box.get_center()

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

func test_every_card_pack_has_one_footprint() -> void:
	var footprints := {}
	for pack_sort: String in CardPack.SORTS:
		for pack_size in CardPack.CARD_SIZES:
			var box := _shell(_hull(pack_sort, pack_size))
			footprints[Vector2(box.x, box.y)] = true
	assert_eq(footprints.size(), 1, "EIN Grundriß für alle Karten-Pakete")

func test_the_hull_is_a_touch_bigger_than_a_lying_card() -> void:
	var box := _shell(_hull(CardPack.SORT_NUMBER, 0))
	assert_gt(box.x, DataCellView.WIDTH)
	assert_gt(box.y, DataCellView.HEIGHT)
	assert_lt(box.y, DataCellView.HEIGHT * ShopController.PLACE_ROOM, "paßt in den Stellplatz")

## Gleich dick für jede Kartenzahl; im Inneren liegt je Option eine echte Karte.
func test_every_box_is_equally_thick_and_holds_one_card_per_option() -> void:
	var first := _shell(_hull(CardPack.SORT_MATERIAL, 0)).z
	assert_almost_eq(first, CardPackView.CASSETTE_THICKNESS, 0.002, "das Modell ist so dick")
	for pack_size in CardPack.CARD_SIZES:
		var hull := _hull(CardPack.SORT_MATERIAL, pack_size, false, DicePack.QUALITY_ROYAL)
		assert_almost_eq(_shell(hull).z, first, 0.0001, "die Kartenzahl ändert die Dicke nicht")
		assert_eq(_stair(hull).size(), CardPack.option_count(pack_size), "eine Karte je Option")
		assert_true(_stair_card(_stair(hull)[0]) is DataCellView, "eine echte Data-Card")

## Die Treppe liegt im Hohlraum: die oberste unter der Folie zum Fuß hin, jede tiefere eine
## Stufe weiter zum Kopf (unter das Fenster), und keine Karte ragt durch Wand oder Lasche.
func test_the_stair_lies_inside_the_box() -> void:
	var hull := _hull(CardPack.SORT_RUNE, CardPack.SIZE_LARGE)
	var bottom := -DataCellView.DEPTH * 0.5
	var wall := CardPackView.BOX_WALL
	var inner_x := DataCellView.WIDTH * CardPackView.FOOT_ROOM * 0.5 - wall
	var head := DataCellView.HEIGHT * CardPackView.FOOT_ROOM * 0.5 - CardPackView.BOX_TAB - wall
	var foot := -DataCellView.HEIGHT * CardPackView.FOOT_ROOM * 0.5 + wall
	var last_y := INF
	var last_z := -INF
	for holder: Node3D in _stair(hull):
		var card := _stair_card(holder)
		var thick := DataCellView.DEPTH * holder.basis.get_scale().z
		assert_gt(holder.position.z - thick * 0.5, bottom + wall, holder.name)
		assert_lt(holder.position.z + thick * 0.5, bottom + CardPackView.CASSETTE_THICKNESS - wall,
			holder.name)
		assert_lt(holder.position.y, last_y, "jede höhere rückt zum Fuß - die tieferen lugen am Kopf hervor")
		assert_gt(holder.position.z, last_z, "und liegt höher")
		last_y = holder.position.y
		last_z = holder.position.z
		var half := Vector2(DataCellView.WIDTH, DataCellView.HEIGHT) * card.body_scale() * 0.5
		assert_lt(half.x, inner_x, "%s quer" % holder.name)
		assert_lt(holder.position.y + half.y, head, "%s am Kopf" % holder.name)
		assert_gt(holder.position.y - half.y, foot, "%s am Fuß" % holder.name)
		assert_gt(holder.basis.z.normalized().z, 0.99, "liegend schaut sie zum Deckel")

## Die Karten sind fast so groß wie die Schachtel, das Fenster nur halb so groß: man sieht
## nie alle ganz - so liest es als Fenster, nicht als Bild.
func test_the_window_shows_only_part_of_the_cards() -> void:
	var hull := _hull(CardPack.SORT_NUMBER, CardPack.SIZE_NORMAL)
	var card := _stair_card(_stair(hull)[0])
	var card_length := DataCellView.HEIGHT * card.body_scale()
	assert_gt(card_length, DataCellView.HEIGHT * CardPackView.FOOT_ROOM * 0.7, "fast so lang")
	var film := hull.find_child("Folie", true, false) as MeshInstance3D
	var window := film.get_aabb().size
	assert_lt(maxf(window.x, window.z), card_length * 0.8, "das Fenster zeigt nur einen Teil")
	var material := film.material_override as StandardMaterial3D
	assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "Klarsichtfolie")
	assert_lt(material.albedo_color.a, 0.2, "kaum Farbe")

## Stehend im Lager bleibt die Treppe: das Fenster liegt auf der Front, nicht am Kopf.
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

## Der Druck je Paket: Augen der Kartenzahl auf Front und Kopf, der Name der Sorte, das
## Sortenband - im Misch-Paket die drei Sortenfarben.
func test_the_print_tells_count_and_sort() -> void:
	for pack_size: int in CardPack.CARD_SIZES:
		var count := CardPack.option_count(pack_size)
		var hull := _hull(CardPack.SORT_NUMBER, pack_size)
		assert_eq(_visible_parts(hull, "AugeFront"), count, "ein Auge je Karte auf der Front")
		assert_eq(_visible_parts(hull, "AugeKopf"), count, "und am Kopf")
	var rune := _hull(CardPack.SORT_RUNE, 1)
	assert_eq(_visible_parts(rune, "DruckSorte_"), 1, "genau ein Sortenname")
	assert_true((rune.find_child("DruckSorte_rune", true, false) as MeshInstance3D).visible)
	assert_eq(_visible_parts(rune, "Streifen"), 0, "keine Misch-Streifen")
	var band := rune.find_child("DruckBand", true, false) as MeshInstance3D
	assert_true(band.visible)
	assert_eq(band.material_override, rune._edge_material, "das Band trägt Hover und Flare")
	var mixed := _hull(CardPack.SORT_MIXED, 1)
	assert_false((mixed.find_child("DruckBand", true, false) as MeshInstance3D).visible)
	assert_gt(_visible_parts(mixed, "Streifen"), 2, "Misch: die drei Sortenfarben")

## Die GÜTE ist die Prägefolie: weißer Druck, Silber, Gold - auf Front und Rücken.
func test_the_foil_tells_the_quality() -> void:
	var seen := {}
	for quality in DicePack.QUALITIES:
		var hull := _hull(CardPack.SORT_NUMBER, CardPack.SIZE_NORMAL, false, quality)
		var foils := hull.find_children("Praegung*", "MeshInstance3D", true, false)
		assert_gt(foils.size(), 2, "Marke, Linie und Rücken")
		var foil := (foils[0] as MeshInstance3D).material_override as StandardMaterial3D
		assert_eq(foil.albedo_color, CardPackView.FOIL_ALBEDOS[quality])
		for part: MeshInstance3D in foils:
			assert_eq(part.material_override, foil, "eine Folie je Schachtel")
		seen[foil.albedo_color] = true
	assert_eq(seen.size(), DicePack.QUALITIES.size(), "jede Güte eine eigene Folie")

## Innen ist die Schachtel roher Karton, außen schwarz bedruckt.
func test_the_box_is_board_outside_and_kraft_inside() -> void:
	var hull := _hull(CardPack.SORT_MATERIAL, CardPack.SIZE_NORMAL)
	var body := hull.find_child("Karton", true, false) as MeshInstance3D
	var kinds := {}
	for surface in body.get_surface_override_material_count():
		kinds[body.get_surface_override_material(surface)] = true
	assert_true(kinds.has(hull._shell_material), "außen der Karton")
	assert_true(kinds.has(hull._kraft_material()), "innen roher Karton")

func test_the_sort_reads_as_colour() -> void:
	assert_eq(_hull(CardPack.SORT_MATERIAL, 1).tint,
		PackDrawerView.COLORS[Engraving.CATEGORY_MATERIAL])
	assert_eq(_hull(DicePack.SORT_SOUL, 1, true).tint,
		PackDrawerView.dice_pack_tint(DicePack.SORT_SOUL))
	var mixed := _hull(CardPack.SORT_MIXED, 1)
	assert_ne(_stair_card(_stair(mixed)[0]).sort, _stair_card(_stair(mixed)[1]).sort,
		"Misch: Karten aller Sorten")

## Die Karten sind von der Sorte des Pakets und in der Größe, die die Güte verspricht.
func test_the_stair_cards_are_of_the_pack_sort() -> void:
	var sorts := {CardPack.SORT_NUMBER: Engraving.CATEGORY_NUMBER,
		CardPack.SORT_MATERIAL: Engraving.CATEGORY_MATERIAL,
		CardPack.SORT_RUNE: Engraving.CATEGORY_DICE}
	for pack_sort: String in sorts:
		for quality in DicePack.QUALITIES:
			var hull := _hull(pack_sort, 1, false, quality)
			for holder in _stair(hull):
				var card := _stair_card(holder)
				assert_eq(card.sort, String(sorts[pack_sort]), pack_sort)
				assert_eq(card.tier, quality, "Standard / Groß / Kolossal")

## In Ruhe stehen die Netze still; unter dem Griff und in der Öffnung laufen sie.
func test_the_nets_only_cycle_under_the_grip_or_when_opening() -> void:
	var hull := _hull(CardPack.SORT_NUMBER, CardPack.SIZE_SMALL)
	assert_false(hull.is_processing(), "in Ruhe still")
	var first := _stair_card(_stair(hull)[0])
	var net := first.stamp_net.duplicate()
	hull._process(CardPackView.NET_CYCLE * 3.0)
	assert_eq(first.stamp_net, net, "ohne Griff kein Wechsel")
	hull.set_hovered(true)
	assert_true(hull.is_processing(), "der Griff läßt sie laufen")
	hull.set_hovered(false)
	assert_false(hull.is_processing(), "losgelassen wieder still")
	hull.set_net_cycling(true)
	assert_true(hull.is_processing(), "auf dem Weg zur Öffnung laufen sie")

## Unter dem Griff wechseln die Netze - und kommen aus dem geteilten Vorrat ihrer Sorte.
func test_the_stair_nets_keep_changing_within_their_sort() -> void:
	var hull := _hull(CardPack.SORT_MATERIAL, CardPack.SIZE_SMALL)
	var cards: Array[DataCellView] = []
	var before: Array = []
	for holder in _stair(hull):
		cards.append(_stair_card(holder))
		before.append(_stair_card(holder).stamp_net.duplicate())
	hull.set_hovered(true)
	hull._cycle_clock = 0.0
	hull._process(CardPackView.NET_CYCLE + 0.01)
	var changed := 0
	for i in cards.size():
		var pool := CardPackView.net_pool(cards[i].sort, cards[i].tier)
		assert_true(pool.has(cards[i].stamp_net), "aus dem Vorrat")
		if cards[i].stamp_net != before[i]:
			changed += 1
	assert_eq(changed, cards.size(), "nach einem Umlauf zeigt jede Karte ein anderes Netz")

func test_a_dice_pack_is_the_case_with_a_band_in_its_colour() -> void:
	var soul := _hull(DicePack.SORT_SOUL, CardPack.SIZE_NORMAL, true)
	assert_not_null(soul.find_child("Case", true, false), "die Schatulle aus Blender")
	assert_true(soul.has_band())
	for part in ["Band", "BandDeckel"]:
		var band := soul.find_child(part, true, false) as MeshInstance3D
		assert_true(band.visible, part)
		assert_eq(band.material_override, soul._edge_material, "das Band trägt Hover und Flare")
	assert_eq((soul._edge_material as StandardMaterial3D).emission, DataCellView._scaled(
		PackDrawerView.dice_pack_tint(DicePack.SORT_SOUL), 1.0), "Banderole = Sortenfarbe")
	var seam := (soul.find_child("Naht", true, false) as MeshInstance3D).material_override \
		as StandardMaterial3D
	assert_ne(seam, soul._edge_material, "die Naht ist neutral")
	var rune := _hull(DicePack.SORT_RUNE, CardPack.SIZE_NORMAL, true)
	assert_eq(((rune.find_child("Naht", true, false) as MeshInstance3D).material_override
		as StandardMaterial3D).emission, seam.emission, "jede Naht im selben Stahlton")
	var plain := _hull(DicePack.SORT_NORMAL, CardPack.SIZE_NORMAL, true)
	assert_false(plain.has_band())
	assert_false((plain.find_child("Band", true, false) as MeshInstance3D).visible,
		"das normale Paket trägt keine Banderole")
	assert_eq(((plain.find_child("Naht", true, false) as MeshInstance3D).material_override
		as StandardMaterial3D).emission, seam.emission, "die Naht sagt die Güte, nicht die Sorte")
	var royal := _quality_hull(DicePack.QUALITY_ROYAL)
	var royal_seam := (royal.find_child("Naht", true, false) as MeshInstance3D).material_override \
		as StandardMaterial3D
	assert_gt(royal_seam.emission_energy_multiplier, seam.emission_energy_multiplier,
		"nur Royal glüht")
	assert_eq(plain.find_children("Auge*", "", true, false).size(),
		2 * CardPackView.case_pips(plain.card_pack_size),
		"eine Würfelseite je Deckel und Rücken")

func test_the_band_tints_are_the_card_colours() -> void:
	assert_eq(PackDrawerView.dice_pack_tint(DicePack.SORT_MATERIAL),
		PackDrawerView.card_pack_tint(CardPack.SORT_MATERIAL), "Material: dieselbe Farbe wie die Karten")
	assert_eq(PackDrawerView.dice_pack_tint(DicePack.SORT_RUNE),
		PackDrawerView.card_pack_tint(CardPack.SORT_RUNE), "Runen: dieselbe Farbe wie die Karten")
	assert_eq(PackDrawerView.dice_pack_tint(DicePack.SORT_SOUL), Color("#a66bff"))
	assert_eq(PackDrawerView.DICE_PACK_TINTS.size(), DicePack.SORTS.size())

func test_the_symbol_sits_on_lid_and_spine_only_with_a_band() -> void:
	var names := {DicePack.SORT_SOUL: "Raute", DicePack.SORT_MATERIAL: "Sechseck",
		DicePack.SORT_RUNE: "Ring"}
	for pack_sort: String in names:
		var hull := _hull(pack_sort, CardPack.SIZE_LARGE, true)
		for host in ["SymbolDeckel", "SymbolRuecken"]:
			var node := hull.find_child(host, true, false)
			assert_not_null(node, "%s: %s" % [pack_sort, host])
			assert_not_null(node.find_child(String(names[pack_sort]), false, false),
				"%s trägt sein Zeichen" % pack_sort)
		var hinge := hull.find_child("Scharnier", true, false)
		assert_true(hinge.is_ancestor_of(hull.find_child("SymbolDeckel", true, false)),
			"das große Zeichen geht mit dem Deckel auf")
	var plain := _hull(DicePack.SORT_NORMAL, CardPack.SIZE_LARGE, true)
	assert_null(plain.find_child("SymbolDeckel", true, false))

## Das kürzere Maß des Grundrisses: die Breite (auch Riesig ist schmaler als lang).
func _across(hull: CardPackView) -> float:
	var lo := Vector3.ONE * INF
	var hi := -Vector3.ONE * INF
	for corner in hull.case_outline_local():
		lo = lo.min(corner)
		hi = hi.max(corner)
	var span := hi - lo
	return minf(span.x, span.z) if span.y < 0.001 else minf(minf(span.x, span.y), span.z)

## Jedes Paket hat dieselbe Schatulle; die Augen auf Deckel und Rücken sind die Würfelzahl.
func test_every_size_is_one_case_and_the_pips_tell_the_count() -> void:
	var widths: Array[float] = []
	for pack_size in DicePack.SIZES:
		var hull := _hull(DicePack.SORT_NORMAL, pack_size, true)
		widths.append(_across(hull))
		assert_eq(CardPackView.case_pips(pack_size), pack_size)
		assert_eq(CardPackView.pip_spots(pack_size).size(), pack_size)
		for face in ["SeiteDeckel", "SeiteRuecken"]:
			var host := hull.find_child(face, true, false)
			assert_not_null(host, face)
			assert_eq(host.find_children("Auge*", "", true, false).size(), pack_size,
				"%s %der" % [face, pack_size])
	for width in widths:
		assert_almost_eq(width, widths[0], 0.0001, "jede Schatulle gleich breit")

## Die Augen liegen im Klassik-Muster und nie aufeinander.
func test_the_pips_follow_the_classic_pattern() -> void:
	assert_eq(CardPackView.pip_spots(2), [Vector2(-1, -1), Vector2(1, 1)] as Array[Vector2])
	assert_true(CardPackView.pip_spots(3).has(Vector2.ZERO), "3: die Mitte")
	assert_false(CardPackView.pip_spots(4).has(Vector2.ZERO), "4: nur Ecken")
	assert_true(CardPackView.pip_spots(5).has(Vector2.ZERO), "5: Ecken und Mitte")
	assert_false(CardPackView.pip_spots(6).has(Vector2.ZERO), "6: zwei Reihen")
	for pips in DicePack.SIZES:
		var seen := {}
		for spot in CardPackView.pip_spots(pips):
			assert_false(seen.has(spot), "%d: kein Auge doppelt" % pips)
			seen[spot] = true

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

## Die GÜTE ist der Lack der ganzen Box; Kappen und Steine gibt es nicht mehr.
func test_the_whole_box_tells_the_quality() -> void:
	var plain := _quality_hull(DicePack.QUALITY_STANDARD, 6)
	var fine := _quality_hull(DicePack.QUALITY_FINE)
	var royal := _quality_hull(DicePack.QUALITY_ROYAL, 3, DicePack.SORT_RUNE)
	for hull in [plain, fine, royal]:
		assert_eq(_shown(hull, "Kappe"), 0, "keine Eckkappen")
		assert_eq(_shown(hull, "Stein"), 0, "keine Steine")
		assert_eq(hull.find_children("Kappe*", "", true, false).size(), 0, "nicht im Modell")
		assert_eq(hull.find_children("Stein*", "", true, false).size(), 0, "nicht im Modell")
	var lacquer := []
	for hull: CardPackView in [plain, fine, royal]:
		var lid := hull.find_child("Deckel", true, false) as MeshInstance3D
		var outside: StandardMaterial3D = null
		for i in lid.mesh.get_surface_count():
			if lid.get_surface_override_material(i) != hull._velvet_material():
				outside = lid.get_surface_override_material(i) as StandardMaterial3D
		assert_eq(outside, hull._shell_material, "der Deckel trägt den Lack")
		lacquer.append(outside.albedo_color)
	assert_ne(lacquer[0], lacquer[1], "Edel ist nicht Graphit")
	assert_ne(lacquer[1], lacquer[2], "Royal ist nicht Edel")
	assert_gt(lacquer[2].r, lacquer[2].b + 0.3, "Royal ist Gold")
	assert_almost_eq(lacquer[1].r, lacquer[1].b, 0.1, "Edel ist Silber")
	assert_gt(fine._shell_material.metallic, plain._shell_material.metallic, "Silber ist Metall")
	assert_gt(lacquer[1].get_luminance(), lacquer[0].get_luminance(), "Silber heller als Graphit")
	var clasp := (fine.find_child("Schliesse", true, false) as MeshInstance3D).material_override
	assert_eq(clasp, fine.case_metal(), "die Schließe bleibt Stahl")

func test_nothing_on_the_case_pulses() -> void:
	var royal := _quality_hull(DicePack.QUALITY_ROYAL)
	assert_false(royal.is_processing(), "Royal steht still")
	var naht := royal.find_child("Naht", true, false) as MeshInstance3D
	var seam := naht.material_override as StandardMaterial3D
	var rest := seam.emission_energy_multiplier
	await wait_seconds(0.2)
	assert_eq(seam.emission_energy_multiplier, rest, "die Naht pulst nicht")

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

func test_the_case_has_a_hinged_lid_and_a_velvet_interior() -> void:
	var hull := _hull(DicePack.SORT_MATERIAL, CardPack.SIZE_LARGE, true)
	assert_true(hull.has_lid(), "die Schatulle hat ein Scharnier")
	var hinge := hull.find_child("Scharnier", true, false)
	for part in ["Deckel", "Lasche", "BandDeckel", "SymbolDeckel"]:
		var node := hull.find_child(part, true, false)
		assert_not_null(node, part)
		assert_true(hinge.is_ancestor_of(node), "%s hängt am Deckel" % part)
	for part in ["Naht", "Band", "SymbolRuecken"]:
		assert_false(hinge.is_ancestor_of(hull.find_child(part, true, false)),
			"%s bleibt am Boden" % part)
	var velvet := 0
	for part in ["Boden", "Deckel"]:
		var mesh := hull.find_child(part, true, false) as MeshInstance3D
		for i in mesh.mesh.get_surface_count():
			if mesh.get_surface_override_material(i) == hull._velvet_material():
				velvet += 1
	assert_eq(velvet, 2, "Boden und Deckel sind innen mit Samt ausgekleidet")
	assert_false(_hull(CardPack.SORT_NUMBER, 1).has_lid(), "die Kassette hat keinen Deckel")

func test_opening_swings_the_lid_up() -> void:
	var hull := _hull(DicePack.SORT_NORMAL, CardPack.SIZE_LARGE, true)
	hull.lie_on_glass(Vector3.ZERO)
	await wait_frames(1)
	# Die Lasche sitzt auf der Seite der Schließe, fern vom Scharnier.
	var tab := hull.find_child("Lasche", true, false) as Node3D
	var closed := tab.global_position
	hull.set_lid_open(1.0)
	assert_gt(tab.global_position.y, closed.y + 1.0, "der Deckel steht auf")
	hull.set_lid_open(0.0)
	assert_almost_eq(tab.global_position.distance_to(closed), 0.0, 0.001, "zu ist zu")
	assert_almost_eq(hull.swing_lid(true), CardPackView.LID_TIME, 0.0001)
	assert_true(hull.lid_swinging())
	await wait_seconds(CardPackView.LID_TIME + 0.1)
	assert_almost_eq(hull.lid_share(), 1.0, 0.001)

func test_the_interior_lies_inside_the_outline() -> void:
	for pack_size in DicePack.SIZES:
		var hull := _hull(DicePack.SORT_NORMAL, pack_size, true)
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
	var cassette := _shell(_hull(CardPack.SORT_NUMBER, 0))
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
	assert_almost_eq(center.z, 0.0, 0.001, "mittig im Platz")
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

## Weder Schachtel noch Schatulle tragen eine Rücken-Marke: Kopfdruck bzw. Würfelseite und
## Banderole lesen von selbst.
func test_no_spine_mark_on_cassette_or_case() -> void:
	var cassette := _hull(CardPack.SORT_MATERIAL, CardPack.SIZE_NORMAL)
	cassette.add_spine()
	assert_null(cassette.find_child("Spine", true, false), "der Druck trägt den Rücken")
	var plain := _quality_hull(DicePack.QUALITY_ROYAL)
	plain.add_spine()
	assert_null(plain.find_child("Spine", true, false), "die Würfelseite trägt den Rücken")
	var banded := _quality_hull(DicePack.QUALITY_STANDARD, CardPack.SIZE_HUGE, DicePack.SORT_SOUL)
	banded.add_spine()
	assert_null(banded.find_child("Spine", true, false), "auch mit Banderole keine Marke")

