extends GutTest
## Die Datenzelle (DataCellView): das versiegelte Paket als Kassette auf dem
## Tisch. Geprüft wird, was der Bauplan festlegt - eine Farbquelle, ein
## versiegelter Sonderbestand ohne Kern, der Deckel des Stapels und die drei
## Leuchtzustände. Die Tween-Zeit selbst ist nie Gegenstand: geprüft werden
## Zielwerte.

func _cell(sort: String, net: Array = [], tier := Pack.TIER_NORMAL) -> DataCellView:
	var cell := DataCellView.new()
	# Erst in den Baum, dann bauen: der Siegel-Ofen ist ein SubViewport.
	add_child_autofree(cell)
	cell.setup(sort, tier, net)
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
	assert_null(sealed.get_node_or_null("Body/Cell0/Core"))
	assert_not_null(sealed.get_node_or_null("Body/Cell0/Seal"))

func test_an_open_sort_shows_its_core_and_no_band() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	assert_false(cell.sealed())
	assert_true(cell.has_core())
	assert_false(cell.has_band())
	assert_not_null(cell.get_node_or_null("Body/Cell0/Core"),
		"der Kern hinterleuchtet das Netz")
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
	assert_almost_eq(body.position.y, DataCellView.STAND_HEIGHT * 0.5, 0.001,
		"stehend auf halbe STANDHÖHE - quer gerollt ist das ihre Breite")

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
	assert_almost_eq(DataCellView.STAND_HEIGHT, DataCellView.WIDTH, 0.001,
		"quer gerollt steht sie auf ihrer Langseite - ihr aufrechtes Maß ist die Breite")

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
	assert_almost_eq(DataCellView.sunk_drop(0.0), DataCellView.STAND_HEIGHT, 0.001)
	assert_almost_eq(DataCellView.sunk_drop(DataCellView.SUNK_SHOW),
		DataCellView.STAND_HEIGHT * (1.0 - DataCellView.SUNK_SHOW), 0.001)
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
	assert_almost_eq(body.position.y, DataCellView.STAND_HEIGHT * 0.5, 0.001)
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

## Die Ankunft im MAGAZIN: die Kassette steigt aus dem Grubenboden. Geprüft wird
## nur der Endzustand - er ist derselbe wie lie_in_pit, sonst hinge die
## Richtigkeit des Magazins an einem Tween.
func test_the_pit_arrival_rises_onto_the_exact_standing_spot() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	var spot := Vector3(2.0, 0.0, -1.5)
	cell.lie_in_pit(spot)
	var standing := cell.global_position
	cell.rise_into_pit(spot, 3.0)
	assert_lt(cell.global_position.y, standing.y - 2.9, "sie startet unter dem Boden")
	assert_true(cell.gliding(), "und ist unterwegs - der Abgleich lässt sie in Ruhe")
	await wait_seconds(DataCellView.RISE_TIME + 0.2)
	assert_true(cell.global_position.is_equal_approx(standing),
		"am Ende liegt sie genau da, wo lie_in_pit sie hingelegt hätte")
	assert_true(cell.glass_position().is_equal_approx(spot), "auf ihrem Glaspunkt")

func test_a_pit_arrival_without_time_stands_hard() -> void:
	# Ein übersprungener Tween darf nichts schuldig bleiben (harter End-Schreiber).
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	var spot := Vector3(-1.0, 0.0, 4.0)
	cell.lie_in_pit(spot)
	var standing := cell.global_position
	cell.rise_into_pit(spot, 3.0, 0.0, 0.0)
	assert_eq(cell.global_position, standing, "byteweise derselbe Stand")
	assert_false(cell.gliding())
	assert_true(cell.visible)

## Dieselbe Ankunft AUF der Fläche - so kommt Ware in einem Laden an, wo es kein
## Loch gibt.
func test_the_arrival_rises_onto_the_exact_standing_spot() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	var spot := Vector3(2.0, 0.0, -1.5)
	cell.stand_on_glass(spot)
	var standing := cell.global_position
	cell.rise_through_glass(spot)
	assert_lt(cell.global_position.y, standing.y - cell.rise_depth() * 0.99,
		"sie startet unter der Fläche")
	assert_true(cell.gliding(), "und ist unterwegs - der Abgleich lässt sie in Ruhe")
	await wait_seconds(DataCellView.RISE_TIME + 0.2)
	assert_true(cell.global_position.is_equal_approx(standing),
		"am Ende steht sie genau da, wo stand_on_glass sie hingestellt hätte")
	assert_true(cell.glass_position().is_equal_approx(spot), "auf ihrem Glaspunkt")

## Der Aufstiegsweg ist ihr EIGENES Körpermaß: darunter ist nichts von ihr mehr
## über dem Glas, und das opake Display testet sie weg.
func test_the_rise_depth_is_the_cells_own_body() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.stand_on_glass(Vector3.ZERO)
	assert_almost_eq(cell.rise_depth(), DataCellView.STAND_HEIGHT, 0.001,
		"stehend ihre ganze Standhöhe")
	cell.lie_on_glass(Vector3.ZERO)
	assert_almost_eq(cell.rise_depth(), DataCellView.lying_over(1.0), 0.001,
		"liegend nur, was sie über der Fläche einnimmt")
	cell.stand_on_glass(Vector3.ZERO)
	cell.set_body_scale(2.0)
	assert_almost_eq(cell.rise_depth(), DataCellView.STAND_HEIGHT * 2.0, 0.001,
		"und der Anzeige-Maßstab fährt mit")

func test_an_arrival_without_time_stands_hard() -> void:
	# Ein übersprungener Tween darf nichts schuldig bleiben (harter End-Schreiber).
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	var spot := Vector3(-1.0, 0.0, 4.0)
	cell.stand_on_glass(spot)
	var standing := cell.global_position
	cell.rise_through_glass(spot, 0.0, 0.0)
	assert_eq(cell.global_position, standing, "byteweise derselbe Stand")
	assert_false(cell.gliding())
	assert_true(cell.visible)

func test_a_glide_without_time_seats_the_cell_hard() -> void:
	# Die Richtigkeit hängt an keinem Tween: Zeit 0 setzt sie sofort.
	var cell := _cell(Engraving.CATEGORY_DICE)
	cell.glide_to(Vector3(3.0, 0.0, -2.0), 0.0)
	assert_eq(cell.global_position, Vector3(3.0, 0.0, -2.0))
	assert_false(cell.gliding())

func test_the_glyph_comes_from_the_existing_seal_drawing() -> void:
	# Kein zweites Zeichen: die Sorte findet ihren Pakettyp über die vorhandene
	# Zuordnung zurück, der Sonderbestand fällt auf den Eckrahmen.
	for pair: Array in [[Engraving.CATEGORY_NUMBER, Pack.TYPE_NUMBER],
			[Engraving.CATEGORY_DICE, Pack.TYPE_DICE_MOD],
			[Pack.SHELF_SPECIAL, ""]]:
		var sort: String = pair[0]
		_cell(sort)
		var oven: SubViewport = DataCellView._glyph_ovens.get(sort)
		assert_not_null(oven, "%s hat ihren Ofen" % sort)
		if oven == null:
			continue
		var icon: PackIconRenderer = oven.get_child(0)
		assert_eq(icon.pack_type, String(pair[1]))

func test_alle_kassetten_einer_sorte_teilen_EINE_backung() -> void:
	# Ein eigener Ofen je Zelle kostete gemessene ~11,5 ms - das war der Ruck beim
	# Bestücken einer Bucht und beim Aufbau des Magazins.
	var sort := Engraving.CATEGORY_NUMBER
	var first := _cell(sort)
	var second := _cell(sort)
	assert_null(first.get_node_or_null("GlyphOven"), "keine Zelle backt selbst")
	assert_null(second.get_node_or_null("GlyphOven"))
	var shared: Texture2D = DataCellView.glyph_texture(sort)
	assert_not_null(shared, "die Sorte hat ihre eine Backung")
	assert_eq(DataCellView.glyph_texture(sort), shared, "und behält sie")

# --- Der Stand im MAGAZIN (die Grube) ---------------------------------------------
# Die Kassetten LIEGEN in einem echten Loch im Tisch (2026-09-04); nichts ruht
# über dem Rand, und von oben liest man ihr Prägenetz. AUF der Fläche steht sie
# nur dort, wo es kein Loch gibt - in den Läden.

func test_lying_in_the_pit_puts_the_card_face_up_at_the_glass_point() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.lie_in_pit(Vector3(3.0, 0.0, -1.5))
	assert_true(cell.lying(), "im Magazin LIEGT sie - ihr Netz zeigt nach oben")
	assert_false(cell.socketed(), "und sie steckt in keinem Leser")
	assert_almost_eq(cell.show_share(), DataCellView.PIT_SHOW, 0.001)
	assert_lte(DataCellView.PIT_SHOW, 0.0,
		"bündig oder eine Spur darunter - nichts ragt über den Rand")
	assert_almost_eq(cell.global_position.x, 3.0, 0.001)
	assert_almost_eq(cell.global_position.z, -1.5, 0.001)
	assert_almost_eq(cell.global_position.y, -cell.drop_for(DataCellView.PIT_SHOW), 0.001)
	# Und wieder zurückgerechnet ist es genau ihr Glaspunkt.
	assert_almost_eq(cell.glass_position().y, 0.0, 0.001)

## Und sie rechnet dort FLACH: die Grube ist nur so tief wie die liegende Karte,
## eine stehende Rechnung versenkte sie weit unter ihrem eigenen Boden.
func test_the_pit_measures_the_lying_card_not_the_standing_one() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.set_body_scale(1.0)
	cell.lie_in_pit(Vector3.ZERO)
	assert_almost_eq(cell.stand_measure, DataCellView.lying_over(1.0), 0.0001,
		"das aufrechte Maß ist ihre Dicke, nicht ihre Standhöhe")
	assert_almost_eq(-cell.global_position.y,
		DataCellView.lying_over(1.0) * (1.0 - DataCellView.PIT_SHOW), 0.0001,
		"und genau so tief hängt sie unter ihrem Glaspunkt")
	cell.seat_hard(Vector3.ZERO)
	assert_almost_eq(cell.stand_measure, DataCellView.STAND_HEIGHT, 0.0001,
		"im Schlitz steht sie wieder - dort gilt die Standhöhe")

func test_a_grown_cell_hangs_deeper_so_its_card_stays_flush() -> void:
	# Der Anzeige-Maßstab verändert das aufrechte Maß: ohne Ausgleich ragte eine
	# große Kassette aus der Grube.
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	cell.set_body_scale(1.8)
	cell.lie_in_pit(Vector3.ZERO)
	assert_almost_eq(cell.glass_position().y, 0.0, 0.001)
	cell.set_body_scale(1.0)
	assert_almost_eq(cell.glass_position().y, 0.0, 0.001,
		"und beim Schrumpfen ebenso - der Glaspunkt bleibt")

func test_standing_on_the_glass_puts_the_whole_body_above_it() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.stand_on_glass(Vector3(3.0, 0.0, -1.5))
	assert_false(cell.lying(), "auf der Fläche STEHT sie")
	assert_false(cell.socketed(), "aber sie steckt in keinem Leser")
	assert_almost_eq(cell.show_share(), 1.0, 0.001, "und zwar mit voller Höhe")
	assert_false(cell.sunk(), "nichts von ihr steckt im Tisch")
	assert_almost_eq(cell.global_position.x, 3.0, 0.001)
	assert_almost_eq(cell.global_position.z, -1.5, 0.001)
	assert_almost_eq(cell.global_position.y, 0.0, 0.001,
		"ihr Ursprung IST der genannte Platz")
	# Und wieder zurückgerechnet ist es genau ihr Glaspunkt.
	assert_almost_eq(cell.glass_position().y, 0.0, 0.001)

func test_a_grown_cell_keeps_standing_on_its_glass_point() -> void:
	# Der Anzeige-Maßstab verändert die Standhöhe: sie wächst nach OBEN, ihr
	# Standplatz bleibt.
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	cell.set_body_scale(1.8)
	cell.stand_on_glass(Vector3.ZERO)
	assert_almost_eq(cell.glass_position().y, 0.0, 0.001)
	cell.set_body_scale(1.0)
	assert_almost_eq(cell.glass_position().y, 0.0, 0.001,
		"und beim Schrumpfen ebenso - der Glaspunkt bleibt")

func test_a_bundle_in_the_pit_is_one_card_with_its_count_on_its_face() -> void:
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	cell.set_count(4)
	assert_eq(cell.shown_cells(), 4, "auf der Fläche liegt der Stapel da")
	assert_eq(cell.cap_badge_text(), "", "und die Zahl schwebt darüber")
	cell.lie_in_pit(Vector3.ZERO)
	assert_eq(cell.shown_cells(), 1, "in der Grube ist das Bündel EINE Karte")
	assert_eq(cell.cap_badge_text(), "", "ihre Kappe zeigt dort zur Seite")
	assert_true((cell.get_node("Body/CountBadge") as Label3D).visible,
		"die Zahl liegt AUF ihr - so ragt nichts aus dem Loch")
	cell.seat_hard(Vector3.ZERO)
	assert_eq(cell.cap_badge_text(), "×4", "stehend trägt die Kappe sie wieder")
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
	cell.lie_in_pit(Vector3.ZERO)
	var body: Node3D = cell.get_node("Body")
	var resting: float = body.position.y
	cell.set_hovered(true)
	assert_true(cell.hovered())
	await wait_seconds(DataCellView.HOVER_TIME + 0.1)
	assert_almost_eq(body.position.y,
		resting + DataCellView.lying_over(1.0) * DataCellView.HOVER_LIFT, 0.01,
		"sie zieht sich um ihre eigene Dicke aus der flachen Grube")
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

# --- Das PRÄGENETZ auf der Fläche -------------------------------------------------
# Die Karte trägt ihr Netz, der Rahmen ihre Sorte und dessen Stärke ihre Größe.

func _number_net(amount := 2) -> Array:
	var net := StampNet.empty_net()
	net[0] = StampNet.value_cell(amount)
	net[3] = StampNet.value_cell(amount)
	return net

func test_die_flaeche_traegt_das_praegenetz_ihres_pakets() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER, _number_net())
	var plate: MeshInstance3D = cell.get_node_or_null("Body/Cell0/StampNet")
	assert_not_null(plate, "das Netz liegt auf der Karte")
	assert_not_null(cell.net_texture(), "und ist gebacken")
	var quad: QuadMesh = plate.mesh
	assert_almost_eq(quad.size.x, cell.net_size().x, 0.0001)
	assert_almost_eq(quad.size.y, cell.net_size().y, 0.0001)
	var span := StampNetOven.span()
	assert_almost_eq(quad.size.x / quad.size.y, span.x / span.y, 0.001,
		"unverzerrt: Quad und Backung teilen ihr Seitenverhältnis")
	assert_almost_eq(quad.size.x, DataCellView.opening_size().x, 0.0001,
		"und füllt den Fensterausschnitt ganz aus - ohne Rand")

func test_gleiche_netze_teilen_EINE_backung() -> void:
	# Das Netz steht ab der Erzeugung fest - gebacken wird EINMAL, je Inhalt.
	var first := _cell(Engraving.CATEGORY_NUMBER, _number_net())
	var second := _cell(Engraving.CATEGORY_NUMBER, _number_net())
	assert_eq(first.net_texture(), second.net_texture(), "dasselbe Bild, EIN Ofen")
	var other := _cell(Engraving.CATEGORY_NUMBER, _number_net(5))
	assert_ne(other.net_texture(), first.net_texture(), "ein anderes Netz backt neu")

func test_der_aufgenommene_zustand_dunkelt_die_zellen_und_kehrt_zurueck() -> void:
	# Die Schablonen-Fahrt nimmt Zellen auf: sie verglimmen, sie verschwinden nicht.
	var cell := _cell(Engraving.CATEGORY_NUMBER, _number_net())
	var resting := cell.net_texture()
	cell.set_net_drained([true, false, false, false, false, false])
	var drained := cell.net_texture()
	assert_ne(drained, resting, "abgedunkelt ist ein anderes Bild")
	assert_eq(cell.net_drained(), [true, false, false, false, false, false])
	cell.set_net_drained([true, false, false, false, false, false])
	assert_eq(cell.net_texture(), drained, "derselbe Ruf schreibt nichts (idempotent)")
	cell.clear_net_drained()
	assert_eq(cell.net_texture(), resting, "und der Ruhestand ist wieder der geteilte")
	assert_true(cell.net_drained().is_empty())

func test_eine_kassette_ohne_paket_zeigt_das_leere_kreuz_ihrer_sorte() -> void:
	# Der Wett-Gewinn kennt Sorte und Größe, aber noch kein Netz.
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	assert_true(StampNet.is_blank(cell.stamp_net), "leer, nicht ungebaut")
	assert_not_null(cell.get_node_or_null("Body/Cell0/StampNet"))
	assert_not_null(cell.net_texture(), "das leere Kreuz steht trotzdem da")
	assert_eq(cell.net_accent(), PackDrawerView.COLORS[Engraving.CATEGORY_MATERIAL],
		"und trägt die Sortenfarbe")

func test_eine_operator_karte_liest_amber() -> void:
	# Die eine Farbtrennung der Serie: Wert cyan, Operator amber.
	var net := StampNet.operator_net(StampNet.OP_DOUBLER)
	var cell := _cell(Pack.SHELF_SPECIAL, net)
	assert_true(cell.has_operator())
	assert_eq(cell.net_accent(), PressNetView.OPERATOR_TINT)
	var plain := _cell(Pack.SHELF_SPECIAL, _number_net())
	assert_false(plain.has_operator())
	assert_eq(plain.net_accent(), PackDrawerView.COLORS[Pack.SHELF_SPECIAL])

func test_die_groesse_steht_in_der_rahmenstaerke_statt_in_streifen() -> void:
	# Auf der Fläche liegt jetzt das Netz - die Größe trägt der Rahmen.
	var normal := _cell(Engraving.CATEGORY_NUMBER, _number_net(), Pack.TIER_NORMAL)
	var big := _cell(Engraving.CATEGORY_NUMBER, _number_net(), Pack.TIER_GROSS)
	var huge := _cell(Engraving.CATEGORY_NUMBER, _number_net(), Pack.TIER_KOLOSSAL)
	assert_almost_eq(normal.bezel_lip(), DataCellView.BEZEL_LIP, 0.0001)
	assert_gt(big.bezel_lip(), normal.bezel_lip())
	assert_gt(huge.bezel_lip(), big.bezel_lip())
	assert_lt(huge.bezel_lip(), DataCellView.SIDE_BAR,
		"aber nie breiter als der Seitenbalken, der ihn trägt")
	assert_null(normal.get_node_or_null("Body/Cell0/TierFace0"),
		"die Streifen der Vorderseite sind gestorben")
	assert_not_null(huge.get_node_or_null("Body/Cell0/TierStripe0"),
		"auf der KAPPE bleiben sie - von oben ist sie die ganze Auskunft")

# --- KORREKTUR-WELLE K: die Karte im SCHACHT liegt QUER ----------------------------

func _quad(cell: DataCellView) -> QuadMesh:
	return (cell.get_node("Body/Cell0/StampNet") as MeshInstance3D).mesh as QuadMesh

# --- WELLE L: EINE Ausrichtung, überall -------------------------------------------

## Jede Kassette liegt QUER (um die Blickachse gerollt) und trägt darum die
## hochkante Backung - im Schacht, in der Grube, in jeder Auslage.
func test_jede_kassette_liegt_quer_und_traegt_das_gedrehte_netz() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER, _number_net())
	var body: Node3D = cell.get_node("Body")
	# STEHEND (Auslage, Schlitz, Schacht) zeigt ihre Breite nach OBEN ...
	for hard in ["stand_on_glass", "seat_hard"]:
		cell.call(hard, Vector3.ZERO)
		assert_almost_eq(body.transform.basis.x.normalized().y, 1.0, 0.001,
			"%s: eine Vierteldrehung um die Blickachse" % hard)
		assert_almost_eq(body.transform.basis.y.normalized().x, -1.0, 0.001,
			"%s: ... und ihre Langseite liegt waagerecht" % hard)
	cell.stand_in_shaft(Vector3.ZERO, 1.0)
	assert_almost_eq(body.transform.basis.x.normalized().y, 1.0, 0.001,
		"und im Schacht ebenso")
	# ... LIEGEND kippt die Kippung sie nach hinten, der Roll bleibt: ihre Breite
	# zeigt dann nach Bild-oben (lokal -Z), nie mehr entlang der Weltachse X.
	for flat in ["lie_on_glass", "lie_in_pit"]:
		cell.call(flat, Vector3.ZERO)
		assert_almost_eq(body.transform.basis.x.normalized().z, -1.0, 0.001,
			"%s: derselbe Roll, nur flach gelegt" % flat)
	assert_gt(_quad(cell).size.y, _quad(cell).size.x,
		"auf der Karte steht das Netz darum hochkant - im Bild liest es aufrecht")

## Und das gedrehte Netz füllt die Karte fast ganz - dafür ist es gedreht.
func test_das_gedrehte_netz_fuellt_die_karte_fast_ganz() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER, _number_net())
	var opening := DataCellView.opening_size()
	var net := cell.net_size()
	assert_gt(net.y / opening.y, 0.9, "es deckt die Karte fast ganz")
	assert_almost_eq(net.x, opening.x * DataCellView.NET_WIDTH_SHARE, 0.0001,
		"und bleibt an der Kartenbreite")
	assert_eq(_quad(cell).size, net, "die Fläche folgt dem Maß")

func test_ein_versiegeltes_stueck_haelt_sein_netz_ueber_dem_band() -> void:
	# Das Siegelband liegt vor der Fläche; quer gedreht wird das Netz darum gedeckelt.
	var cell := _cell(Pack.SHELF_SPECIAL, _number_net())
	var opening := DataCellView.opening_size()
	assert_lte(cell.net_size().y * 0.5 + opening.y * DataCellView.NET_SEALED_LIFT,
		opening.y * 0.5 + 0.001, "es bleibt im Fenster")

# --- Die Karte beantwortet den Zeiger SELBST (2026-09-04) -------------------------
# Sie schneidet den Zeigerstrahl gegen die Ebene ihrer Netz-Platte, statt dass
# irgendwer ihre Projektion nachrechnet - so antwortet sie in JEDER Lage.

func _aim(camera: Camera3D, at: Vector3) -> Vector2:
	return camera.unproject_position(at)

func _net_plate(cell: DataCellView) -> MeshInstance3D:
	return cell.get_node("Body/Cell0/StampNet") as MeshInstance3D

func test_the_card_reports_the_net_cell_under_the_pointer() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER, _number_net())
	cell.lie_in_pit(Vector3.ZERO)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = Vector3(0.0, 6.0, 0.0)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	await wait_frames(1)
	var plate := _net_plate(cell)
	var span: Vector2 = (plate.mesh as QuadMesh).size
	for face in StampNet.FACES:
		# Der Anteil der Zellmitte, aus der EINEN 2D-Rechnung geholt ...
		var share := _share_of(face)
		# ... in Plattenkoordinaten und von dort in die Welt.
		var local := Vector3((share.x - 0.5) * span.x, (0.5 - share.y) * span.y, 0.0)
		var world: Vector3 = plate.global_transform * local
		assert_eq(cell.net_face_at(camera, _aim(camera, world)), face,
			"Seite %d wird unter dem Zeiger erkannt" % face)

func test_beside_the_card_the_pointer_hits_nothing() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER, _number_net())
	cell.lie_in_pit(Vector3.ZERO)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = Vector3(0.0, 6.0, 0.0)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	await wait_frames(1)
	var plate := _net_plate(cell)
	var span: Vector2 = (plate.mesh as QuadMesh).size
	var outside: Vector3 = plate.global_transform * Vector3(span.x, span.y, 0.0)
	assert_eq(cell.net_face_at(camera, _aim(camera, outside)), -1,
		"neben der Netz-Fläche liegt keine Zelle")
	assert_eq(cell.net_face_at(null, Vector2.ZERO), -1, "und ohne Kamera erst recht")

## Die Mitte einer Zelle als Anteil der HOCHKANTEN Fläche - dieselbe Drehung wie
## in stamp_net_upright, nur einmal ausgeschrieben.
func _share_of(face: int) -> Vector2:
	var flat := DieNetView.net_size(1.0)
	var middle := DieNetView.cell_position(face, 1.0) + Vector2.ONE * 0.5
	return Vector2((flat.y - middle.y) / flat.y, middle.x / flat.x)
