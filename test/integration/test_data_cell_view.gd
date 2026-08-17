extends GutTest
## Die Datenzelle (DataCellView): das versiegelte Paket als Kassette auf dem
## Tisch. Geprüft wird, was der Bauplan festlegt - eine Farbquelle, ein
## versiegelter Sonderbestand ohne Kern, der Deckel des Stapels und die drei
## Leuchtzustände. Die Tween-Zeit selbst ist nie Gegenstand: geprüft werden
## Zielwerte.

func _cell(sort: String) -> DataCellView:
	var cell := DataCellView.new()
	# Erst in den Baum, dann bauen: der Siegel-Ofen ist ein SubViewport.
	add_child_autofree(cell)
	cell.setup(sort)
	return cell

func test_every_shelf_sort_builds() -> void:
	for sort: String in Pack.SHELF_ORDER:
		var cell := _cell(sort)
		assert_eq(cell.sort, sort)
		assert_eq(cell.stack_size(), 1, "%s steht als eine Kassette da" % sort)
		assert_not_null(cell.get_node_or_null("Body/Cell0/Glass"),
			"%s hat seine Scheibe" % sort)

func test_the_tint_comes_from_the_single_shelf_table() -> void:
	for sort: String in Pack.SHELF_ORDER:
		var cell := _cell(sort)
		var expected: Color = PackDrawerView.COLORS[sort]
		assert_eq(cell.tint, expected, "%s trägt die Regal-Farbe" % sort)
		var glow := cell.glow_color()
		assert_almost_eq(glow.r, expected.r, 0.001)
		assert_almost_eq(glow.g, expected.g, 0.001)
		assert_almost_eq(glow.b, expected.b, 0.001)

func test_the_sealed_sort_shows_a_band_and_no_core() -> void:
	var sealed := _cell(Pack.SHELF_SPECIAL)
	assert_true(sealed.sealed())
	assert_false(sealed.has_core(), "Fixinhalt: es gibt nichts zu sehen")
	assert_true(sealed.has_band(), "stattdessen das Siegelband")
	assert_null(sealed.get_node_or_null("Body/Cell0/CoreBar0"))
	assert_not_null(sealed.get_node_or_null("Body/Cell0/Seal"))

func test_an_open_sort_shows_its_core_bars_and_no_band() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	assert_false(cell.sealed())
	assert_true(cell.has_core())
	assert_false(cell.has_band())
	for i in DataCellView.CORE_BARS:
		assert_not_null(cell.get_node_or_null("Body/Cell0/CoreBar%d" % i))
	assert_null(cell.get_node_or_null("Body/Cell0/Seal"))

func test_the_physical_stack_is_capped_and_the_badge_carries_the_rest() -> void:
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	cell.set_count(3)
	assert_eq(cell.stack_size(), 3, "unter dem Deckel steht jede Kassette da")
	assert_eq(cell.badge_text(), "×3")
	cell.set_count(9)
	assert_eq(cell.stack_size(), DataCellView.STACK_CAP, "darüber deckelt der Körper")
	assert_eq(cell.count(), 9, "gezählt wird trotzdem voll")
	assert_eq(cell.badge_text(), "×9", "die Marke sagt die genaue Zahl")
	cell.set_count(1)
	assert_eq(cell.stack_size(), 1)
	assert_eq(cell.badge_text(), "", "eine einzelne Zelle braucht keine Marke")

func test_the_rest_glow_stays_under_the_bloom_threshold() -> void:
	# Dieselbe Ruheregel wie bei den Runen: Ruhelicht ja, Ruhe-Bloom nein.
	assert_lt(DataCellView.REST_ENERGY, Rune.IDLE_CEILING)
	assert_gt(DataCellView.FLARE_ENERGY, Rune.IDLE_CEILING, "der Ausbruch SOLL blühen")
	assert_lt(DataCellView.DIM_ENERGY, DataCellView.REST_ENERGY)
	var cell := _cell(Engraving.CATEGORY_DICE)
	assert_almost_eq(cell.glow_energy(), DataCellView.REST_ENERGY, 0.001)

func test_dimming_lowers_the_core_but_keeps_the_body() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.set_count(2)
	cell.set_dimmed(true)
	assert_true(cell.dimmed())
	assert_almost_eq(cell.glow_energy(), DataCellView.DIM_ENERGY, 0.001)
	assert_eq(cell.stack_size(), 2, "gedimmt wird das Licht, nicht der Körper")
	assert_true(cell.visible)
	cell.set_dimmed(false)
	assert_almost_eq(cell.glow_energy(), DataCellView.REST_ENERGY, 0.001)

func test_the_flare_peaks_and_returns_to_the_rest_cap() -> void:
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	cell.flare()
	assert_almost_eq(cell.glow_energy(), DataCellView.FLARE_ENERGY, 0.001,
		"der Lesemoment schlägt sofort aus")
	await wait_seconds(DataCellView.FLARE_TIME + 0.15)
	assert_almost_eq(cell.glow_energy(), DataCellView.REST_ENERGY, 0.001,
		"und klingt auf das Ruhelicht zurück")

func test_a_dimmed_cell_flares_back_to_its_own_rest() -> void:
	# Der Ausklang zielt auf das AKTUELLE Ruhelicht - sonst leuchtete eine
	# gesperrte Zelle nach jedem Ausbruch wieder hell.
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.set_dimmed(true)
	cell.flare()
	await wait_seconds(DataCellView.FLARE_TIME + 0.15)
	assert_almost_eq(cell.glow_energy(), DataCellView.DIM_ENERGY, 0.001)

func test_the_cell_lies_by_default_and_stands_only_on_demand() -> void:
	# Die Tischkameras blicken fast senkrecht nach unten - liegend ist die Lage,
	# stehend nur noch das Schaufenster.
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	var body: Node3D = cell.get_node("Body")
	assert_true(cell.lying(), "sie liegt, ohne dass jemand sie hinlegt")
	assert_almost_eq(body.position.y, DataCellView.DEPTH * 0.5, 0.001,
		"liegend hebt der Ursprung auf halbe Dicke")
	cell.lay_flat(false)
	assert_false(cell.lying())
	assert_almost_eq(body.position.y, DataCellView.HEIGHT * 0.5, 0.001,
		"stehend auf halbe Höhe - beides setzt sie AUF das Glas")

func test_the_standing_height_grows_out_of_the_die_edge() -> void:
	# Sie bleibt Möbel neben den Würfeln - nur ein Drittel größer, damit sie im
	# Regal auf Bankdistanz liest. Alles andere hängt an dieser einen Zahl.
	var edge := DieBuilder.HALF_EXTENT * 2.0 * DiceTrayView.DIE_SCALE
	assert_almost_eq(DataCellView.HEIGHT, edge * DataCellView.SIZE_FACTOR, 0.001)
	assert_gt(DataCellView.SIZE_FACTOR, 1.0, "gewachsen, nicht geschrumpft")
	assert_almost_eq(DataCellView.UNIT, DataCellView.HEIGHT / 3.0, 0.001,
		"Breite, Tiefe, Stapel und Marke leiten sich weiter aus der Höhe ab")
	assert_lt(DataCellView.WIDTH, DataCellView.HEIGHT, "Streichholzschachtel, kein Quadrat")
	assert_lt(DataCellView.DEPTH, DataCellView.WIDTH)

# --- Die leuchtende Kopfkante -----------------------------------------------------
# Tief im Leseschlitz steht NUR sie über dem Glas - sie ist dort die ganze Anzeige.

func test_every_cell_carries_its_edge_strip() -> void:
	for sort: String in Pack.SHELF_ORDER:
		var cell := _cell(sort)
		assert_not_null(cell.get_node_or_null("Body/Cell0/EdgeStrip"),
			"%s hat seine Kopfkante" % sort)
	assert_lt(DataCellView.EDGE_STRIP_H, DataCellView.HEIGHT * 0.1, "ein Streifen, kein Balken")

func test_the_edge_rests_below_the_bloom_and_burns_only_when_socketed() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	assert_lt(DataCellView.EDGE_REST_ENERGY, Rune.IDLE_CEILING, "im Regal kein Ruhe-Bloom")
	assert_gt(DataCellView.EDGE_LIVE_ENERGY, DataCellView.EDGE_REST_ENERGY)
	assert_lt(DataCellView.EDGE_LIVE_ENERGY, 1.5,
		"darüber clippen alle Kanäle und die Sortenfarbe geht verloren")
	assert_almost_eq(cell.edge_energy(), DataCellView.EDGE_REST_ENERGY, 0.001)
	cell.set_socketed(true)
	assert_true(cell.socketed())
	assert_almost_eq(cell.edge_energy(), DataCellView.EDGE_LIVE_ENERGY, 0.001)
	cell.set_socketed(false)
	assert_almost_eq(cell.edge_energy(), DataCellView.EDGE_REST_ENERGY, 0.001)

func test_a_locked_bench_darkens_the_edge_too() -> void:
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	cell.set_socketed(true)
	cell.set_dimmed(true)
	assert_almost_eq(cell.edge_energy(), DataCellView.EDGE_DIM_ENERGY, 0.001,
		"gesperrt verglimmt auch die Kante")
	cell.set_dimmed(false)
	assert_almost_eq(cell.edge_energy(), DataCellView.EDGE_LIVE_ENERGY, 0.001)

func test_the_edge_is_pulled_along_by_a_flare_and_falls_back() -> void:
	# Ein gesunkener Sliver zeigt keinen Kern mehr - ohne das Mitreißen bliebe der
	# Lesemoment im Schlitz unsichtbar.
	var cell := _cell(Engraving.CATEGORY_DICE)
	cell.set_socketed(true)
	cell.flare()
	assert_gt(cell.edge_energy(), DataCellView.EDGE_LIVE_ENERGY, "sie reißt mit")
	await wait_seconds(DataCellView.FLARE_TIME + 0.15)
	assert_almost_eq(cell.edge_energy(), DataCellView.EDGE_LIVE_ENERGY, 0.001)

# --- Der Anzeige-Maßstab des Regals ------------------------------------------------
# Die Bucht ist das untere Viertel der Bank; die Kassette wächst darin mit. REINE
# Anzeige: ihr Ursprung liegt weiter auf dem Glas, der Schlitz bleibt bei 1.

func test_the_body_scale_lifts_the_body_and_leaves_the_seat_alone() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.global_position = Vector3(1.5, 0.0, -2.0)
	assert_almost_eq(cell.body_scale(), 1.0, 0.001, "so wird sie geboren")
	var lying_lift: float = cell.get_node("Body").position.y
	cell.set_body_scale(1.34)
	assert_almost_eq(cell.body_scale(), 1.34, 0.001)
	assert_almost_eq(cell.get_node("Body").scale.x, 1.34, 0.001, "der KÖRPER wächst")
	assert_almost_eq(cell.get_node("Body").position.y, lying_lift * 1.34, 0.001,
		"und hebt genau so weit ab, dass sie weiter auf dem Glas liegt")
	assert_almost_eq(cell.global_position.x, 1.5, 0.001, "ihr Platz ändert sich nicht")
	assert_almost_eq(cell.global_position.y, 0.0, 0.001)
	assert_almost_eq(cell.global_position.z, -2.0, 0.001)

func test_the_socket_stands_on_the_one_cassette_scale() -> void:
	# Eine Karte behält ihre Größe ihr ganzes Leben lang: der Leseschlitz ist auf
	# genau das Maß geschnitten, in dem sie auch im Magazin steht.
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	cell.set_body_scale(1.0)
	cell.seat_hard(Vector3.ZERO)
	assert_almost_eq(cell.body_scale(), PackDrawerView.CASSETTE_SCALE, 0.001)
	assert_almost_eq(cell.global_position.y,
		-cell.drop_for(DataCellView.SUNK_SHOW), 0.001,
		"und hängt so tief darunter, wie sie groß ist")
	assert_almost_eq(cell.glass_position().y, 0.0, 0.001, "ihr Glaspunkt bleibt")

# --- Der Steckplatz (tief im Tisch) -----------------------------------------------

func test_the_socket_pose_stands_upright_and_sinks_to_its_share() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	assert_gt(DataCellView.SUNK_SHOW, 0.0, "etwas muss überstehen")
	assert_lt(DataCellView.SUNK_SHOW, 0.3, "aber sie STECKT, sie steht nicht daneben")
	cell.seat_hard(Vector3(2.0, 0.0, -1.0))
	assert_false(cell.lying(), "im Schlitz steht sie senkrecht")
	assert_true(cell.sunk())
	assert_almost_eq(cell.show_share(), DataCellView.SUNK_SHOW, 0.001)
	assert_almost_eq(cell.global_position.y,
		-cell.drop_for(DataCellView.SUNK_SHOW), 0.001,
		"der Rest hängt unter dem Glas")
	assert_almost_eq(cell.global_position.x, 2.0, 0.001, "über ihrem Schlitz")
	assert_almost_eq(cell.global_position.z, -1.0, 0.001)
	assert_true(cell.socketed(), "und ihre Kopfkante brennt")

func test_the_drop_is_the_hidden_part_of_the_height() -> void:
	assert_almost_eq(DataCellView.sunk_drop(1.0), 0.0, 0.001, "ganz oben: kein Versatz")
	assert_almost_eq(DataCellView.sunk_drop(0.0), DataCellView.HEIGHT, 0.001)
	assert_almost_eq(DataCellView.sunk_drop(DataCellView.SUNK_SHOW),
		DataCellView.HEIGHT * (1.0 - DataCellView.SUNK_SHOW), 0.001)
	assert_lt(DataCellView.SUNK_GONE, 0.0,
		"ganz geschluckt liegt sie eine Spur UNTER dem Glas")

func test_a_plunge_without_time_lands_hard() -> void:
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	cell.raise_upright(0.0)
	assert_false(cell.lying())
	cell.plunge(DataCellView.SUNK_SHOW, 0.0)
	assert_almost_eq(cell.global_position.y,
		-DataCellView.sunk_drop(DataCellView.SUNK_SHOW), 0.001)
	cell.plunge(1.0, 0.0)
	assert_almost_eq(cell.global_position.y, 0.0, 0.001, "und wieder ganz heraus")
	assert_false(cell.sunk())

func test_a_sunk_cell_shows_no_badge() -> void:
	# Sie ist einzeln, und die Zahl stünde als einziges Stück Schrift aus dem Tisch.
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.set_count(4)
	var badge: Label3D = cell.get_node("Body/CountBadge")
	assert_true(badge.visible)
	cell.seat_hard(Vector3.ZERO)
	assert_false(badge.visible)

func test_a_glide_target_is_always_a_glass_point() -> void:
	# Wie tief sie unter ihrem Platz hängt, weiß die Zelle selbst - der Aufrufer
	# nennt nur den Punkt auf dem Glas.
	var cell := _cell(Engraving.CATEGORY_DICE)
	cell.seat_hard(Vector3.ZERO)
	cell.glide_to(Vector3(1.0, 0.0, 4.0), 0.0)
	assert_almost_eq(cell.global_position.x, 1.0, 0.001)
	assert_almost_eq(cell.global_position.z, 4.0, 0.001)
	assert_almost_eq(cell.global_position.y,
		-cell.drop_for(DataCellView.SUNK_SHOW), 0.001,
		"sie behält ihre Steck-Tiefe")

func test_raising_and_laying_over_are_the_two_ends_of_one_blend() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	var body: Node3D = cell.get_node("Body")
	cell.raise_upright(0.0)
	assert_almost_eq(body.position.y, DataCellView.HEIGHT * 0.5, 0.001)
	cell.lay_over(0.0)
	assert_almost_eq(body.position.y, DataCellView.DEPTH * 0.5, 0.001)
	assert_true(cell.lying())

func test_a_full_stack_stays_a_flat_pile() -> void:
	# Wofür die Zelle dünn ist: fünf davon sollen als Haufen lesen, nicht als Turm -
	# der volle Stapel bleibt flacher als eine einzelne Kassette lang ist.
	var pile := DataCellView.STACK_PITCH * float(DataCellView.STACK_CAP - 1) + DataCellView.DEPTH
	assert_lt(pile, DataCellView.HEIGHT * 0.6, "%f ist kein Turm" % pile)

func test_the_body_grows_in_and_shrinks_out_without_being_freed() -> void:
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	cell.dematerialize()
	await wait_seconds(DataCellView.DEMATERIALIZE_TIME + 0.1)
	assert_false(cell.visible, "abgetreten - aber derselbe Körper steht noch da")
	assert_eq(cell.stack_size(), 1)
	cell.materialize()
	await wait_seconds(DataCellView.MATERIALIZE_TIME + 0.1)
	assert_true(cell.visible)
	assert_almost_eq(cell.scale.x, 1.0, 0.01, "und wieder in voller Größe")

func test_a_glide_without_time_seats_the_cell_hard() -> void:
	# Die Richtigkeit hängt an keinem Tween: Zeit 0 setzt sie sofort.
	var cell := _cell(Engraving.CATEGORY_DICE)
	cell.glide_to(Vector3(3.0, 0.0, -2.0), 0.0)
	assert_eq(cell.global_position, Vector3(3.0, 0.0, -2.0))
	assert_false(cell.gliding())

func test_the_glyph_comes_from_the_existing_seal_drawing() -> void:
	# Kein zweites Zeichen: die Sorte findet ihren Pakettyp über die vorhandene
	# Zuordnung zurück, der Sonderbestand fällt auf den Eckrahmen.
	var dice := _cell(Pack.SHELF_DICE_PACK)
	var oven: SubViewport = dice.get_node("GlyphOven")
	var icon: PackIconRenderer = oven.get_child(0)
	assert_eq(icon.pack_type, Pack.TYPE_DICE)
	var runes := _cell(Engraving.CATEGORY_DICE)
	var rune_icon: PackIconRenderer = runes.get_node("GlyphOven").get_child(0)
	assert_eq(rune_icon.pack_type, Pack.TYPE_DICE_MOD)
	var special := _cell(Pack.SHELF_SPECIAL)
	var special_icon: PackIconRenderer = special.get_node("GlyphOven").get_child(0)
	assert_eq(special_icon.pack_type, "", "der Sonderbestand nennt seine Sorte nicht")

# --- Der Stand im MAGAZIN (die Grube) ---------------------------------------------
# Die Kassetten stehen in einem echten Loch im Tisch; nichts ruht über dem Rand,
# und die ganze Auskunft liegt auf der Kappe.

func test_standing_in_the_pit_puts_the_cap_at_the_glass_point() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.stand_in_pit(Vector3(3.0, 0.0, -1.5))
	assert_false(cell.lying(), "im Magazin STEHT sie")
	assert_false(cell.socketed(), "aber sie steckt in keinem Leser")
	assert_almost_eq(cell.show_share(), DataCellView.PIT_SHOW, 0.001)
	assert_lte(DataCellView.PIT_SHOW, 0.0,
		"bündig oder eine Spur darunter - nichts ragt über den Rand")
	assert_almost_eq(cell.global_position.x, 3.0, 0.001)
	assert_almost_eq(cell.global_position.z, -1.5, 0.001)
	assert_almost_eq(cell.global_position.y, -cell.drop_for(DataCellView.PIT_SHOW), 0.001)
	# Und wieder zurückgerechnet ist es genau ihr Glaspunkt.
	assert_almost_eq(cell.glass_position().y, 0.0, 0.001)

func test_a_grown_cell_hangs_deeper_so_its_cap_stays_flush() -> void:
	# Der Anzeige-Maßstab verändert die Standhöhe: ohne Ausgleich ragte eine große
	# Kassette aus der Grube.
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	cell.set_body_scale(1.8)
	cell.stand_in_pit(Vector3.ZERO)
	assert_almost_eq(cell.glass_position().y, 0.0, 0.001)
	cell.set_body_scale(1.0)
	assert_almost_eq(cell.glass_position().y, 0.0, 0.001,
		"und beim Schrumpfen ebenso - der Glaspunkt bleibt")

func test_a_standing_bundle_is_one_card_with_its_count_on_the_cap() -> void:
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	cell.set_count(4)
	assert_eq(cell.shown_cells(), 4, "liegend liegt der Stapel da")
	assert_eq(cell.cap_badge_text(), "", "und die Zahl schwebt darüber")
	cell.stand_in_pit(Vector3.ZERO)
	assert_eq(cell.shown_cells(), 1, "stehend ist das Bündel EINE Karte")
	assert_eq(cell.cap_badge_text(), "×4", "und die Zahl liegt auf ihrer Kappe")
	assert_false((cell.get_node("Body/CountBadge") as Label3D).visible,
		"die Schwebemarke ragte aus der Grube")
	cell.set_count(1)
	assert_eq(cell.cap_badge_text(), "", "ein Einzelstück zählt nichts")

func test_every_cell_carries_its_sort_cap() -> void:
	for sort: String in Pack.SHELF_ORDER:
		var cell := _cell(sort)
		assert_not_null(cell.get_node_or_null("Body/Cell0/Cap"), "%s hat seine Kappe" % sort)
		assert_not_null(cell.get_node_or_null("Body/Cell0/CapGlyph"),
			"%s trägt sein Zeichen darauf" % sort)
	assert_gt(DataCellView.CAP_DEPTH, DataCellView.DEPTH,
		"die Kappe kragt über die Dicke - sonst wäre sie ein Strich")
	assert_lt(DataCellView.CAP_REST_ENERGY, Rune.IDLE_CEILING, "kein Ruhe-Bloom")

func test_hovering_lifts_the_cell_out_of_the_pit_and_lets_it_sink_back() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.stand_in_pit(Vector3.ZERO)
	var body: Node3D = cell.get_node("Body")
	var resting: float = body.position.y
	cell.set_hovered(true)
	assert_true(cell.hovered())
	await wait_seconds(DataCellView.HOVER_TIME + 0.1)
	assert_almost_eq(body.position.y,
		resting + DataCellView.HEIGHT * DataCellView.HOVER_LIFT, 0.01,
		"sie zieht sich aus der Grube")
	assert_almost_eq(cell.glow_energy(), DataCellView.HOVER_ENERGY, 0.001,
		"und hellt auf")
	assert_lt(DataCellView.HOVER_ENERGY, DataCellView.FLARE_ENERGY,
		"greifen ist kein Lesen")
	cell.set_hovered(false)
	await wait_seconds(DataCellView.HOVER_TIME + 0.1)
	assert_almost_eq(body.position.y, resting, 0.01, "und sinkt zurück")
	assert_almost_eq(cell.glow_energy(), DataCellView.REST_ENERGY, 0.001)

func test_a_lying_cell_is_deliberately_not_mirrored() -> void:
	# Dieselbe Regel wie beim Phantomwürfel: sie LIEGT auf dem Glas, ihr
	# Spiegelbild fiele neben sie und schmierte Stapel und Marke zu.
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	var glass: MeshInstance3D = cell.get_node("Body/Cell0/Glass")
	assert_eq(glass.layers & ScreenReflection.LAYER, 0, "kein zweites ×n neben dem echten")
