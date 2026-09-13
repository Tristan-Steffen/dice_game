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
		var cell := _cell(sort, [], Pack.TIER_KOLOSSAL)
		var expected: Color = PackDrawerView.COLORS[sort]
		assert_eq(cell.tint, expected, "%s trägt die Regal-Farbe" % sort)
		# Kolossal ist die volle Sättigung - dort steht die Sortenfarbe unverändert.
		var glow := cell.glow_color()
		assert_almost_eq(glow.r, expected.r, 0.001)
		assert_almost_eq(glow.g, expected.g, 0.001)
		assert_almost_eq(glow.b, expected.b, 0.001)

## Das SIEGELBAND des Sonderbestands ist am 2026-09-11 gestorben (Spieler-Entscheid:
## der Querbalken verkleinerte sein Netz) - er trägt Kern und Netz wie jede Sorte.
func test_the_special_sort_carries_core_and_net_like_any_other() -> void:
	var special := _cell(Pack.SHELF_SPECIAL, _number_net())
	var plain := _cell(Engraving.CATEGORY_NUMBER, _number_net())
	assert_true(special.has_core(), "der Kern hinterleuchtet auch den Sonderbestand")
	assert_not_null(special.get_node_or_null("Body/Cell0/Core"))
	assert_null(special.get_node_or_null("Body/Cell0/Seal"), "kein Band mehr")
	assert_null(special.get("has_band"), "und keine Vokabel dafür")
	assert_eq(special.net_size(), plain.net_size(), "das Netz ist GENAU so groß")
	assert_eq((special.get_node("Body/Cell0/StampNet") as Node3D).position,
		(plain.get_node("Body/Cell0/StampNet") as Node3D).position,
		"und liegt an derselben Stelle")

func test_an_open_sort_shows_its_core() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	assert_true(cell.has_core())
	assert_not_null(cell.get_node_or_null("Body/Cell0/Core"),
		"der Kern hinterleuchtet das Netz")
	assert_null(cell.get_node_or_null("Body/Cell0/Seal"))

## Die Karte ist GANZ aus GETÖNTEM GLAS - Körper, Kopfkante, Blende, Kragen und
## Finnen alle halb durchsichtig; nur das Netz (die "die-view") bleibt deckend.
func test_the_body_is_tinted_glass_and_cap_and_frame_stay_solid() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	var shade := cell.tier_tint()
	var shell: StandardMaterial3D = cell.get_node("Body/Cell0/Back").material_override
	assert_eq(shell.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "der Körper ist Glas")
	assert_almost_eq(shell.albedo_color.a, DataCellView.GLASS_BODY_ALPHA, 0.001)
	assert_almost_eq(shell.albedo_color.r, shade.r, 0.001, "in der Sortenfarbe")
	assert_almost_eq(shell.albedo_color.g, shade.g, 0.001)
	assert_almost_eq(shell.albedo_color.b, shade.b, 0.001)
	assert_lt(DataCellView.GLASS_BODY_EMISSION, Rune.IDLE_CEILING, "kein Ruhe-Bloom")
	assert_eq(cell.get_node("Body/Cell0/BarLeft").material_override, shell,
		"die Gehäusebalken teilen dasselbe Glas")
	for glassy in ["EdgeStrip", "BezelLeft", "CollarLeft", "Fin0"]:
		var part: StandardMaterial3D = cell.get_node("Body/Cell0/%s" % glassy).material_override
		assert_eq(part.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA,
			"%s ist jetzt halb durchsichtig" % glassy)
		assert_almost_eq(part.albedo_color.a, DataCellView.GLASS_FRAME_ALPHA, 0.001,
			"%s auf halber Deckkraft" % glassy)

## Und darum liest das Netz auch von HINTEN: EINE Backung, beidseitig gezeigt, mit
## einem durchscheinenden Kern dahinter und einer festen Zeichen-Reihenfolge.
func test_the_net_reads_from_behind_through_the_body() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	var net: StandardMaterial3D = cell.get_node("Body/Cell0/StampNet").material_override
	assert_eq(net.cull_mode, BaseMaterial3D.CULL_DISABLED,
		"die Rückseite des Quads zeigt dieselbe Textur gespiegelt")
	var core: StandardMaterial3D = cell.get_node("Body/Cell0/Core").material_override
	assert_eq(core.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_almost_eq(core.albedo_color.a, DataCellView.CORE_ALPHA, 0.001,
		"die Hinterleuchtung blockt den Blick nicht mehr")
	var shell: StandardMaterial3D = cell.get_node("Body/Cell0/Back").material_override
	var pane: StandardMaterial3D = cell.get_node("Body/Cell0/Glass").material_override
	assert_lt(shell.render_priority, core.render_priority, "Körper hinter Kern")
	assert_lt(core.render_priority, pane.render_priority, "Kern hinter Scheibe")
	assert_lt(pane.render_priority, net.render_priority, "Scheibe hinter Netz")

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
	# Dieselbe Ruheregel wie bei den Runen: Ruhelicht ja, Ruhe-Bloom nein - und die
	# Größen-Leiter dämpft nur, sie hebt nie über die Schwelle.
	assert_lt(DataCellView.REST_ENERGY, Rune.IDLE_CEILING)
	assert_gt(DataCellView.FLARE_ENERGY, Rune.IDLE_CEILING, "der Ausbruch SOLL blühen")
	assert_lt(DataCellView.DIM_ENERGY, DataCellView.REST_ENERGY)
	for tier: int in [Pack.TIER_NORMAL, Pack.TIER_GROSS, Pack.TIER_KOLOSSAL]:
		var cell := _cell(Engraving.CATEGORY_DICE, [], tier)
		assert_almost_eq(cell.glow_energy(),
			DataCellView.REST_ENERGY * cell.tier_energy(), 0.001)
		assert_lt(cell.glow_energy(), Rune.IDLE_CEILING, "Stufe %d bleibt darunter" % tier)

func test_dimming_lowers_the_core_but_keeps_the_body() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.set_count(2)
	cell.set_dimmed(true)
	assert_true(cell.dimmed())
	assert_almost_eq(cell.glow_energy(), DataCellView.DIM_ENERGY, 0.001)
	assert_eq(cell.stack_size(), 2, "gedimmt wird das Licht, nicht der Körper")
	assert_true(cell.visible)
	cell.set_dimmed(false)
	assert_almost_eq(cell.glow_energy(), cell.rest_energy(), 0.001)

func test_the_flare_peaks_and_returns_to_the_rest_cap() -> void:
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	cell.flare()
	assert_almost_eq(cell.glow_energy(), DataCellView.FLARE_ENERGY, 0.001,
		"der Lesemoment schlägt sofort aus")
	await wait_seconds(DataCellView.FLARE_TIME + 0.15)
	assert_almost_eq(cell.glow_energy(), cell.rest_energy(), 0.001,
		"und klingt auf das Ruhelicht zurück")

func test_a_dimmed_cell_flares_back_to_its_own_rest() -> void:
	# Der Ausklang zielt auf das AKTUELLE Ruhelicht - sonst leuchtete eine
	# gesperrte Zelle nach jedem Ausbruch wieder hell.
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.set_dimmed(true)
	cell.flare()
	await wait_seconds(DataCellView.FLARE_TIME + 0.15)
	assert_almost_eq(cell.glow_energy(), DataCellView.DIM_ENERGY, 0.001)

func test_the_cell_lies_by_default() -> void:
	# Die Tischkameras blicken fast senkrecht nach unten - liegend ist die Lage.
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	var body: Node3D = cell.get_node("Body")
	assert_almost_eq(body.position.y, DataCellView.DEPTH * 0.5, 0.001,
		"liegend hebt der Ursprung auf halbe Dicke")

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
	assert_almost_eq(DataCellView.STAND_HEIGHT, DataCellView.HEIGHT, 0.001,
		"ihr aufrechtes Maß ist ihre Höhe")

# --- Die leuchtende Kopfkante -----------------------------------------------------
# Tief im Leseschlitz steht NUR sie über dem Glas - sie ist dort die ganze Anzeige.

func test_every_cell_carries_its_edge_strip() -> void:
	for sort: String in Pack.SHELF_ORDER:
		var cell := _cell(sort)
		assert_not_null(cell.get_node_or_null("Body/Cell0/EdgeStrip"),
			"%s hat seine Kopfkante" % sort)
	assert_lt(DataCellView.EDGE_STRIP_H, DataCellView.HEIGHT * 0.1, "ein Streifen, kein Balken")

func test_the_edge_rests_below_the_bloom_and_burns_only_when_socketed() -> void:
	# Die volle Stufe (Kolossal) trägt die authored Energien - dort binden die
	# beiden Deckel, und die kleineren Größen bleiben darunter.
	var cell := _cell(Engraving.CATEGORY_NUMBER, [], Pack.TIER_KOLOSSAL)
	assert_almost_eq(cell.tier_energy(), 1.0, 0.0001)
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
	assert_almost_eq(cell.edge_energy(), cell.edge_rest_energy(), 0.001)

func test_the_edge_is_pulled_along_by_a_flare_and_falls_back() -> void:
	# Ein gesunkener Sliver zeigt keinen Kern mehr - ohne das Mitreißen bliebe der
	# Lesemoment im Schlitz unsichtbar.
	var cell := _cell(Engraving.CATEGORY_DICE)
	cell.set_socketed(true)
	cell.flare()
	assert_gt(cell.edge_energy(), cell.edge_rest_energy(), "sie reißt mit")
	await wait_seconds(DataCellView.FLARE_TIME + 0.15)
	assert_almost_eq(cell.edge_energy(), cell.edge_rest_energy(), 0.001)

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

## Die Ankunft AUF der Fläche - so kommt Ware in einem Laden an, wo es kein Loch
## gibt. Geprüft wird nur der Endzustand - er ist derselbe wie lie_on_glass.
func test_the_arrival_rises_onto_the_exact_lying_spot() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	var spot := Vector3(2.0, 0.0, -1.5)
	cell.lie_on_glass(spot)
	var lying := cell.global_position
	cell.rise_through_glass(spot)
	assert_lt(cell.global_position.y, lying.y - cell.rise_depth() * 0.99,
		"sie startet unter der Fläche")
	assert_true(cell.gliding(), "und ist unterwegs - der Abgleich lässt sie in Ruhe")
	await wait_seconds(DataCellView.RISE_TIME + 0.2)
	assert_true(cell.global_position.is_equal_approx(lying),
		"am Ende liegt sie genau da, wo lie_on_glass sie hingelegt hätte")
	assert_true(cell.glass_position().is_equal_approx(spot), "auf ihrem Glaspunkt")

## Der Aufstiegsweg ist ihr EIGENES Körpermaß: darunter ist nichts von ihr mehr
## über dem Glas, und das opake Display testet sie weg.
func test_the_rise_depth_is_the_cells_own_body() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.lie_on_glass(Vector3.ZERO)
	assert_almost_eq(cell.rise_depth(), DataCellView.lying_over(1.0), 0.001,
		"liegend nur, was sie über der Fläche einnimmt")
	cell.set_body_scale(2.0)
	assert_almost_eq(cell.rise_depth(), DataCellView.lying_over(2.0), 0.001,
		"und der Anzeige-Maßstab fährt mit")

func test_an_arrival_without_time_lands_hard() -> void:
	# Ein übersprungener Tween darf nichts schuldig bleiben (harter End-Schreiber).
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	var spot := Vector3(-1.0, 0.0, 4.0)
	cell.lie_on_glass(spot)
	var lying := cell.global_position
	cell.rise_through_glass(spot, 0.0, 0.0)
	assert_eq(cell.global_position, lying, "byteweise dieselbe Lage")
	assert_false(cell.gliding())
	assert_true(cell.visible)

func test_a_glide_without_time_seats_the_cell_hard() -> void:
	# Die Richtigkeit hängt an keinem Tween: Zeit 0 setzt sie sofort.
	var cell := _cell(Engraving.CATEGORY_DICE)
	cell.glide_to(Vector3(3.0, 0.0, -2.0), 0.0)
	assert_eq(cell.global_position, Vector3(3.0, 0.0, -2.0))
	assert_false(cell.gliding())

## Die SORTE sagt die FARBE (Welle R): das Zeichen auf der Kappe ist mit ihr
## gestorben, vier Sorten liefern vier Töne aus der EINEN Farbquelle.
func test_die_sorte_sagt_die_farbe() -> void:
	var seen: Array[Color] = []
	for sort: String in Pack.SHELF_ORDER:
		var cell := _cell(sort, [], Pack.TIER_KOLOSSAL)
		assert_eq(cell.tint, PackDrawerView.COLORS[sort] as Color,
			"%s aus PackDrawerView.COLORS" % sort)
		assert_false(seen.has(cell.tier_tint()), "%s hat einen eigenen Ton" % sort)
		seen.append(cell.tier_tint())
	assert_eq(seen.size(), Pack.SHELF_ORDER.size(), "vier Sorten, vier Töne")
	# Die eine Farbtrennung der Serie: eine Operator-Karte rechnet und liest amber.
	var op := _cell(Engraving.CATEGORY_NUMBER,
		StampNet.operator_net(StampNet.OP_DOUBLER), Pack.TIER_KOLOSSAL)
	assert_eq(op.tier_tint(), PressNetView.OPERATOR_TINT)

## Und die GRÖSSE ihre INTENSITÄT: derselbe Farbton, steigende Sättigung UND
## steigendes Glühen - Standard blaß und schwach, Kolossal voll.
func test_die_groesse_sagt_die_intensitaet() -> void:
	var sort := Engraving.CATEGORY_MATERIAL
	var base: Color = PackDrawerView.COLORS[sort]
	var last_sat := -1.0
	var last_gain := -1.0
	for tier: int in [Pack.TIER_NORMAL, Pack.TIER_GROSS, Pack.TIER_KOLOSSAL]:
		var cell := _cell(sort, [], tier)
		var shade := cell.tier_tint()
		assert_almost_eq(shade.h, base.h, 0.002, "Stufe %d: derselbe Farbton" % tier)
		assert_gt(shade.s, last_sat, "Stufe %d: satter als die kleinere" % tier)
		assert_gt(cell.tier_energy(), last_gain, "Stufe %d: heller" % tier)
		assert_lte(cell.tier_energy(), 1.0, "aber nie über die authored Energie")
		last_sat = shade.s
		last_gain = cell.tier_energy()
	assert_almost_eq(last_gain, 1.0, 0.0001, "das Kolossale bekommt sie ganz")

# --- Der Stand im MAGAZIN (die Grube) ---------------------------------------------
# Die Kassetten STEHEN in einem echten Loch im Tisch (Welle O), versenkt bis zur
# Kappe; nichts ruht über dem Rand. AUF der Fläche liegt sie nur dort, wo es kein
# Loch gibt - in den Läden.

func test_lying_on_the_glass_puts_the_whole_body_above_it() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.lie_on_glass(Vector3(3.0, 0.0, -1.5))
	assert_false(cell.socketed(), "sie steckt in keinem Kontakt")
	assert_almost_eq(cell.global_position.x, 3.0, 0.001)
	assert_almost_eq(cell.global_position.z, -1.5, 0.001)
	assert_almost_eq(cell.global_position.y, 0.0, 0.001,
		"ihr Ursprung IST der genannte Platz")
	assert_true(cell.glass_position().is_equal_approx(cell.global_position),
		"und zugleich ihr Glaspunkt")
	cell.set_body_scale(1.8)
	assert_almost_eq(cell.global_position.y, 0.0, 0.001,
		"der Anzeige-Maßstab wächst nach oben - der Platz bleibt")

## Ein Bündel liegt als Stapel da, und in einer Auslage trägt seine FLÄCHE die
## Zahl - die Kappe, die sie früher trug, gibt es nicht mehr.
func test_a_bundle_carries_its_count_on_the_face() -> void:
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	var badge: Label3D = cell.get_node("Body/CountBadge")
	cell.set_count(4)
	assert_eq(cell.stack_size(), 4, "liegend liegt der Stapel da")
	assert_eq(cell.badge_text(), "×4")
	assert_gt(badge.position.y, DataCellView.HEIGHT * 0.5, "frei: über dem Stapel")
	cell.badge_on_face = true
	cell.lie_on_glass(Vector3.ZERO)
	assert_gt(badge.position.z, DataCellView.DEPTH * 0.5, "in der Auslage AUF der Fläche")
	assert_true(badge.visible)
	cell.set_count(1)
	assert_eq(cell.badge_text(), "", "ein Einzelstück zählt nichts")

func test_no_cell_carries_a_cap_any_more() -> void:
	# Die KAPPE ist am 2026-09-04 gestorben: ihr Zeichen sagte nur die Sorte, und
	# die sagt jetzt die Farbe. Über dem Blech steht nur noch die Kopfkante.
	for sort: String in Pack.SHELF_ORDER:
		var cell := _cell(sort, [], Pack.TIER_KOLOSSAL)
		for gone in ["Cap", "CapGlyph", "TierStripe0", "TierStripe1"]:
			assert_null(cell.get_node_or_null("Body/Cell0/%s" % gone),
				"%s: kein %s mehr" % [sort, gone])
		assert_null(cell.get_node_or_null("Body/CapBadge"))
		assert_not_null(cell.get_node_or_null("Body/Cell0/EdgeStrip"),
			"%s behält seine Kopfkante" % sort)
	# Das GRIFFMASS überlebt als reine Rechnung: Reihe und Magazin teilen danach,
	# und es ist byteweise das alte Kappenmaß - die Teilung bleibt dieselbe.
	assert_gt(DataCellView.GRIP_DEPTH, DataCellView.DEPTH,
		"die Griff-Zelle ist breiter als die Karte dick - sonst fände der Zeiger sie nie")
	assert_almost_eq(DataCellView.GRIP_DEPTH, DataCellView.DEPTH * 2.9, 0.000001)
	assert_gt(DataCellView.GRIP_DEPTH, DataCellView.FIN_DEPTH,
		"und bleibt die Greifluft um den steckenden Körper")

func test_hovering_lifts_the_cell_and_lets_it_sink_back() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.lie_on_glass(Vector3.ZERO)
	var body: Node3D = cell.get_node("Body")
	var resting: float = body.position.y
	cell.set_hovered(true)
	assert_true(cell.hovered())
	await wait_seconds(DataCellView.HOVER_TIME + 0.1)
	assert_almost_eq(body.position.y,
		resting + DataCellView.STAND_HEIGHT * DataCellView.HOVER_LIFT, 0.01,
		"sie hebt sich um einen Teil ihrer Standhöhe")
	assert_almost_eq(cell.glow_energy(), DataCellView.HOVER_ENERGY, 0.001,
		"und hellt auf")
	assert_lt(DataCellView.HOVER_ENERGY, DataCellView.FLARE_ENERGY,
		"greifen ist kein Lesen")
	cell.set_hovered(false)
	await wait_seconds(DataCellView.HOVER_TIME + 0.1)
	assert_almost_eq(body.position.y, resting, 0.01, "und sinkt zurück")
	assert_almost_eq(cell.glow_energy(), cell.rest_energy(), 0.001)

## Der ZWEITE Hover-Kanal (Welle X): im TURM wird nicht gehoben, sondern LÄNGS
## herausgezogen - nach Bild-links, damit das Netz frei liest. EIN Tween für beide.
func test_hover_slide_pulls_the_lying_cell_along_its_own_axis() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.set_body_scale(PackDrawerView.CASSETTE_SCALE)
	cell.lie_on_glass(Vector3.ZERO)
	var body: Node3D = cell.get_node("Body")
	var resting := body.position
	assert_almost_eq(cell.hover_slide, 0.0, 0.001, "die Auslagen schieben nichts")
	cell.hover_lift = 0.0
	cell.hover_slide = TowerView.HOVER_SLIDE
	cell.set_hovered(true)
	await wait_seconds(DataCellView.HOVER_TIME + 0.1)
	assert_almost_eq(body.position.x, resting.x - DataCellView.STAND_HEIGHT
		* TowerView.HOVER_SLIDE * PackDrawerView.CASSETTE_SCALE, 0.01,
		"sie fährt längs ihrer Achse heraus")
	assert_almost_eq(body.position.y, resting.y, 0.01, "und hebt sich dabei NICHT")
	cell.set_hovered(false)
	await wait_seconds(DataCellView.HOVER_TIME + 0.1)
	assert_almost_eq(body.position.x, resting.x, 0.01, "und rutscht zurück")

## Und im FACH einer Auslage hebt derselbe Griff die LIEGENDE Karte weiter AN - der
## Hub gilt in BEIDEN Lagen, gemessen an ihrer Standhöhe.
func test_hovering_lifts_the_lying_cell_in_its_fach() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.set_body_scale(PackDrawerView.CASSETTE_SCALE)
	cell.lie_on_glass(Vector3.ZERO)
	var body: Node3D = cell.get_node("Body")
	var resting: float = body.position.y
	cell.set_hovered(true)
	await wait_seconds(DataCellView.HOVER_TIME + 0.1)
	assert_almost_eq(body.position.y, resting + DataCellView.STAND_HEIGHT
		* DataCellView.HOVER_LIFT * PackDrawerView.CASSETTE_SCALE, 0.01,
		"sie hebt sich aus ihrem Fach")
	cell.set_hovered(false)
	await wait_seconds(DataCellView.HOVER_TIME + 0.1)
	assert_almost_eq(body.position.y, resting, 0.01, "und legt sich zurück")

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
	# Der Block nimmt Zellen auf: sie verglimmen, sie verschwinden nicht.
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
	# Die Größe sagt die INTENSITÄT; die Rahmenstärke bleibt der stille zweite Kanal.
	var normal := _cell(Engraving.CATEGORY_NUMBER, _number_net(), Pack.TIER_NORMAL)
	var big := _cell(Engraving.CATEGORY_NUMBER, _number_net(), Pack.TIER_GROSS)
	var huge := _cell(Engraving.CATEGORY_NUMBER, _number_net(), Pack.TIER_KOLOSSAL)
	assert_almost_eq(normal.bezel_lip(), DataCellView.BEZEL_LIP, 0.0001)
	assert_gt(big.bezel_lip(), normal.bezel_lip())
	assert_gt(huge.bezel_lip(), big.bezel_lip())
	assert_lt(huge.bezel_lip(), DataCellView.SIDE_BAR,
		"aber nie breiter als der Seitenbalken, der ihn trägt")
	# ... und beide Kanäle laufen gleich herum: stärker heißt satter und heller.
	assert_gt(huge.tier_tint().s, normal.tier_tint().s)
	assert_gt(huge.tier_energy(), normal.tier_energy())
	var frame: StandardMaterial3D = huge.get_node("Body/Cell0/BezelLeft").material_override
	var pale: StandardMaterial3D = normal.get_node("Body/Cell0/BezelLeft").material_override
	assert_gt(frame.emission_energy_multiplier, pale.emission_energy_multiplier,
		"der Rahmen des Kolossalen glüht stärker")

# --- KORREKTUR-WELLE K: die Karte im SCHACHT liegt QUER ----------------------------

func _quad(cell: DataCellView) -> QuadMesh:
	return (cell.get_node("Body/Cell0/StampNet") as MeshInstance3D).mesh as QuadMesh

# --- WELLE O/P: ROLL und YAW folgen der LAGE --------------------------------------

## LIEGEND ist die Karte quer gerollt und flach gekippt: ihre Breite zeigt nach
## Bild-oben (lokal -Z), ihre Fläche nach oben. Die EINE hochkante Backung bleibt.
func test_liegend_quer() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER, _number_net())
	var body: Node3D = cell.get_node("Body")
	cell.lie_on_glass(Vector3.ZERO)
	assert_almost_eq(body.transform.basis.x.normalized().z, -1.0, 0.001,
		"lie_on_glass: quer gerollt und flach gelegt")
	assert_almost_eq(body.transform.basis.z.normalized().y, 1.0, 0.001,
		"ihre Fläche zeigt nach oben")
	assert_gt(_quad(cell).size.y, _quad(cell).size.x,
		"die EINE Backung bleibt hochkant - liegend liest sie darum aufrecht")

## Die Bündelzahl schaut MIT der Fläche: sie ist ein Kind des Körpers und dreht mit
## ihm, also liegt sie in der Auslage richtig herum auf der Karte - und liest von
## hinten durchs Glas gespiegelt mit.
func test_die_marke_schaut_mit_der_flaeche() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER, _number_net())
	cell.set_count(3)
	cell.badge_on_face = true
	cell.lie_on_glass(Vector3.ZERO)
	var badge: Node3D = cell.get_node("Body/CountBadge")
	var plate: Node3D = cell.get_node("Body/Cell0/StampNet")
	var into := cell.global_transform.affine_inverse()
	var badge_normal := (into.basis * badge.global_transform.basis).z.normalized()
	var plate_normal := (into.basis * plate.global_transform.basis).z.normalized()
	assert_almost_eq(badge_normal.dot(plate_normal), 1.0, 0.001,
		"sie schaut in dieselbe Richtung wie das Netz")
	assert_lt(badge.position.y, 0.0, "auf der Fußhälfte der Karte")
	assert_gt(badge.position.z, DataCellView.DEPTH * 0.5, "und VOR ihrer Fläche")

## DER TRAGE-BOGEN: was der SPIELER bewegt, fliegt ÜBER dem Tisch. Er endet exakt
## auf dem genannten Glaspunkt und unterschreitet das Glas nie.
func test_der_trage_bogen_endet_auf_dem_glaspunkt_und_bleibt_ueber_dem_glas() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.lie_on_glass(Vector3.ZERO)
	var target := Vector3(4.0, 0.0, -2.0)
	cell.arc_to(target, 0.3, 1.0)
	assert_true(cell.busy(), "während des Bogens hält sie jeden Schreiber fern")
	var lowest := cell.global_position.y
	var highest := cell.global_position.y
	for step in 5:
		await wait_seconds(0.05)
		lowest = minf(lowest, cell.global_position.y)
		highest = maxf(highest, cell.global_position.y)
	await wait_seconds(0.15)
	assert_gte(lowest, -0.001, "kein Punkt des Bogens liegt unter dem Glas")
	assert_gt(highest, 0.2, "und er ist wirklich ein Bogen, keine Gerade")
	assert_true(cell.global_position.is_equal_approx(target),
		"am Ende steht sie auf dem Punkt")
	assert_true(cell.glass_position().is_equal_approx(target),
		"und ihr Glaspunkt IST das genannte Ziel")

## Und er hält sein Versprechen auch bei SCHRÄGER Sehne: der höchste Punkt liegt
## `peak` über dem HÖHEREN Ende, nie darüber hinaus - sonst stiege eine Karte auf
## dem Weg vom Magazin in die unterste Turm-Etage über die Tischkante (gemessen
## 0,31 Welt, bevor der Hub gekappt wurde).
func test_der_trage_bogen_steigt_nie_ueber_sein_hoeheres_ende() -> void:
	# Die reine Rechnung, für jede Neigung und beide Richtungen.
	for pair in [[-0.55, -4.35], [-4.35, -0.55], [-0.55, -0.55], [0.0, -2.0]]:
		var a: float = pair[0]
		var b: float = pair[1]
		for peak in [0.0, 0.4]:
			var hump := minf(maxf(maxf(a, b) + peak - (a + b) * 0.5, 0.0),
				DataCellView.arc_hump_cap(a, b, peak))
			var top := -99.0
			for i in 201:
				var s := float(i) / 200.0
				top = maxf(top, lerpf(a, b, s) + 4.0 * hump * s * (1.0 - s))
			assert_lte(top, maxf(a, b) + peak + 0.001,
				"%.2f -> %.2f, Scheitel %.2f: hoechster Punkt %.3f" % [a, b, peak, top])
	# ... und die FAHRT selbst: aus dem Magazin tief in den Turm bleibt sie unter
	# ihrem Startpunkt.
	var cell := _cell(Engraving.CATEGORY_NUMBER)
	cell.lie_on_glass(Vector3(0.0, -0.55, 0.0))
	cell.arc_to(Vector3(2.0, -4.35, 0.0), 0.3, 0.0)
	var highest := cell.global_position.y
	for step in 6:
		await wait_seconds(0.05)
		highest = maxf(highest, cell.global_position.y)
	assert_lte(highest, -0.55 + 0.001, "sie steigt auf dem Weg nach unten nicht")

func test_ein_trage_bogen_ohne_zeit_landet_hart() -> void:
	var cell := _cell(Engraving.CATEGORY_MATERIAL)
	cell.lie_on_glass(Vector3.ZERO)
	cell.arc_to(Vector3(1.0, 0.0, 2.0), 0.0, 1.0)
	assert_false(cell.gliding(), "kein Tween, der etwas schuldig bliebe")
	assert_true(cell.glass_position().is_equal_approx(Vector3(1.0, 0.0, 2.0)))

## Und das gedrehte Netz füllt die Karte fast ganz - dafür ist es gedreht.
func test_das_gedrehte_netz_fuellt_die_karte_fast_ganz() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER, _number_net())
	var opening := DataCellView.opening_size()
	var net := cell.net_size()
	assert_gt(net.y / opening.y, 0.9, "es deckt die Karte fast ganz")
	assert_almost_eq(net.x, opening.x * DataCellView.NET_WIDTH_SHARE, 0.0001,
		"und bleibt an der Kartenbreite")
	assert_eq(_quad(cell).size, net, "die Fläche folgt dem Maß")

func test_ein_sonderbestands_stueck_fuellt_sein_fenster_wie_jedes_andere() -> void:
	var cell := _cell(Pack.SHELF_SPECIAL, _number_net())
	var opening := DataCellView.opening_size()
	assert_lte(cell.net_size().y * 0.5, opening.y * 0.5 + 0.001, "es bleibt im Fenster")
	assert_gt(cell.net_size().y / opening.y, 0.9, "und deckt es fast ganz")

# --- Die Karte beantwortet den Zeiger SELBST (2026-09-04) -------------------------
# Sie schneidet den Zeigerstrahl gegen die Ebene ihrer Netz-Platte, statt dass
# irgendwer ihre Projektion nachrechnet - so antwortet sie in JEDER Lage.

func _aim(camera: Camera3D, at: Vector3) -> Vector2:
	return camera.unproject_position(at)

func _net_plate(cell: DataCellView) -> MeshInstance3D:
	return cell.get_node("Body/Cell0/StampNet") as MeshInstance3D

func test_the_card_reports_the_net_cell_under_the_pointer() -> void:
	var cell := _cell(Engraving.CATEGORY_NUMBER, _number_net())
	cell.lie_on_glass(Vector3.ZERO)
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
	cell.lie_on_glass(Vector3.ZERO)
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
