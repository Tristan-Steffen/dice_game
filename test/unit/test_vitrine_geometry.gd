extends GutTest
## Die Vitrine als AUSLAGE AUF der Tischfläche: ihre Maße sind gerechnet, nicht
## getippt. Geprüft wird nur die reine Mathematik - Auflage, Bänder und die Zeiten
## des Auftritts. Wer wo liegt, entscheidet erst die Auslage selbst.

func test_die_ware_liegt_auf_der_tischflaeche() -> void:
	# Es gibt keine Grube mehr: der Boden der Auslage IST die Anzeigefläche, und
	# alles Liegende ruht eine Haaresbreite darüber.
	var bay := VitrineView.new()
	bay.center = Vector3.ZERO
	bay.half = Vector2(10.0, 20.0)
	assert_almost_eq(bay.floor_y(), bay.center.y, 0.0001, "der Boden ist die Fläche")
	assert_almost_eq(bay.lie_y(0.0) - bay.floor_y(), VitrineView.FLOOR_CLEAR, 0.0001,
		"eine Haaresbreite darüber, sonst flimmert die Unterseite")
	var thick := DieBuilder.HALF_EXTENT * VitrineView.DIE_SCALE
	assert_almost_eq(bay.lie_y(thick) - thick, bay.lie_y(0.0), 0.0001,
		"dickere Ware steht genau um ihre halbe Höhe höher")
	assert_gt(bay.lie_y(thick), bay.center.y, "und steht ÜBER der Anzeige, nicht darunter")
	assert_almost_eq(bay.cell_y(),
		bay.lie_y(0.0) + DataCellView.lying_under(PackDrawerView.CASSETTE_SCALE), 0.0001,
		"die Kassette nur um ihre Finnen gehoben")
	bay.free()

func test_der_weg_durch_die_flaeche_misst_die_hoechste_ware() -> void:
	# Aufsteigen und Absinken messen sich am eigenen Körper: darunter deckt das
	# opake Display-Mesh alles weg. Eine Grubentiefe kommt darin nicht mehr vor.
	var die_top := DieBuilder.HALF_EXTENT * VitrineView.DIE_SCALE \
		* (1.0 + VitrineView.SILHOUETTE)
	var cell_top := DataCellView.lying_under(PackDrawerView.CASSETTE_SCALE) \
		+ DataCellView.lying_over(PackDrawerView.CASSETTE_SCALE)
	assert_almost_eq(VitrineView.content_depth(),
		VitrineView.FLOOR_CLEAR + maxf(die_top, cell_top), 0.0001)
	assert_almost_eq(VitrineView.sink_drop(), VitrineView.content_depth(), 0.0001)
	assert_gt(VitrineView.sink_drop(), die_top,
		"ein gesunkener Würfel steht mit keiner Ecke mehr über der Fläche")

func test_das_loch_liegt_in_der_fassung() -> void:
	# pit_rect_in ist die eine Rechnung, die Magazin UND Auslage teilen.
	var strip := Rect2(120.0, 40.0, 800.0, 400.0)
	var unit := 10.0
	var hole := PackDrawerView.pit_rect_in(strip, unit)
	var inset := PackDrawerView.rim_inset(unit)
	assert_true(strip.encloses(hole), "das Feld bleibt im Streifen")
	assert_almost_eq(hole.position.x - strip.position.x, inset, 0.0001)
	assert_almost_eq(strip.end.y - hole.end.y, inset, 0.0001)
	assert_almost_eq(hole.size.x, strip.size.x - inset * 2.0, 0.0001)

func test_keine_auslage_schneidet_ein_loch() -> void:
	# Die Buchten stehen flächig: kein Vorhang, kein Vitrinen-Loch. Das EINZIGE
	# Loch beider Shader ist die Magazin-Grube.
	var glass: String = load("res://assets/shaders/screen_glass.gdshader").code
	var ground: String = load("res://assets/shaders/table_ground.gdshader").code
	for gone: String in ["vitrine_rects", "vitrine_open", "vitrine_hole"]:
		assert_false(glass.contains(gone), "das Glas kennt %s nicht mehr" % gone)
	for gone: String in ["vitrine_min", "vitrine_max", "vitrine_open"]:
		assert_false(ground.contains(gone), "der Boden kennt %s nicht mehr" % gone)
	assert_true(glass.contains("pit_rect"), "die Magazin-Grube bleibt das eine Loch")
	assert_true(ground.contains("pit_min") and ground.contains("pit_max"),
		"und hinter ihr steht kein Filz")

# --- Die Plätze der Ware (reine Mathematik, keine Körper) ----------------------

func test_eine_reihe_steht_mittig_und_in_fester_teilung() -> void:
	var spots := VitrineView.row_spots(3, 100.0, 10.0)
	assert_eq(spots.size(), 3)
	assert_almost_eq(spots[0] + spots[2], 0.0, 0.0001, "mittig um die Feldmitte")
	assert_almost_eq(spots[1], 0.0, 0.0001)
	assert_almost_eq(spots[1] - spots[0], 10.0, 0.0001, "feste Teilung, solange sie passt")

func test_eine_volle_reihe_rueckt_zusammen_statt_ueberzulaufen() -> void:
	var span := 30.0
	var spots := VitrineView.row_spots(6, span, 10.0)
	assert_eq(spots.size(), 6)
	assert_lte(spots[5] - spots[0], span, "die Reihe bleibt im Feld")
	assert_lt(spots[1] - spots[0], 10.0, "sie rückt zusammen")

func test_eine_leere_reihe_hat_keine_plaetze() -> void:
	assert_eq(VitrineView.row_spots(0, 100.0, 10.0).size(), 0)
	assert_eq(VitrineView.row_spots(3, 0.0, 10.0).size(), 0)

func test_gattung_und_index_sind_zusammen_der_platz() -> void:
	assert_eq(VitrineView.slot_key(ShopController.KIND_DIE, 2), "die:2")
	assert_ne(VitrineView.slot_key(ShopController.KIND_DIE, 2),
		VitrineView.slot_key(ShopController.KIND_SPECIAL, 2),
		"gleicher Index, andere Gattung - anderer Platz")

func test_der_greifradius_bleibt_unter_der_halben_teilung() -> void:
	# Überlappende Kreise ließen einen Griff am Rand den Nachbarn meinen.
	var tight := PackedFloat32Array([0.0, 4.0])
	assert_almost_eq(VitrineView.pick_radius(9.0, tight), 2.0, 0.0001)
	assert_almost_eq(VitrineView.pick_radius(1.0, tight), 1.0, 0.0001,
		"ein kleiner Wunsch bleibt klein")
	assert_almost_eq(VitrineView.pick_radius(9.0, PackedFloat32Array([0.0])), 9.0, 0.0001,
		"ein einzelnes Stück hat keinen Nachbarn")

# --- Die zwei Ankunfts-Grade (reiner Entscheid) --------------------------------

func test_was_liegt_bleibt_liegen_alles_andere_steigt() -> void:
	assert_eq(ShopController.grade_for(true), ShopController.GRADE_STAND,
		"was schon in der Auslage steht, bleibt liegen")
	assert_eq(ShopController.grade_for(false), ShopController.GRADE_RISE,
		"alles andere kommt durch die Fläche herauf")

func test_der_lautere_grad_gewinnt() -> void:
	# Sammeln sich Meldungen an, bis wirklich gestellt wird, darf die leiseste die
	# lauteste nicht verschlucken.
	assert_eq(ShopController.louder_grade(
		ShopController.GRADE_STAND, ShopController.GRADE_RISE),
		ShopController.GRADE_RISE)
	assert_eq(ShopController.louder_grade(
		ShopController.GRADE_RISE, ShopController.GRADE_STAND),
		ShopController.GRADE_RISE)
	assert_eq(ShopController.louder_grade(
		ShopController.GRADE_STAND, ShopController.GRADE_STAND),
		ShopController.GRADE_STAND)

func test_der_umschlag_bleibt_im_budget() -> void:
	# Stöbern darf nicht zäh werden: sinken plus Aufsteigen bleibt unter 1,2 s.
	var swap := VitrineView.swap_time(30)
	assert_lte(swap, VitrineView.SWAP_TIME + 0.0001, "die Staffelung ist gedeckelt")
	assert_almost_eq(VitrineView.swap_time(1), VitrineView.SWAP_SINK, 0.0001,
		"ein einzelnes Stück wartet auf niemanden")
	assert_eq(VitrineView.swap_time(0), 0.0, "eine leere Auslage sinkt nicht")
	var rise := VitrineView.entry_time(30, ShopController.GRADE_RISE)
	assert_lte(swap + rise, 1.2, "der ganze Umschlag bleibt unter 1,2 s")
	assert_eq(VitrineView.entry_time(30, ShopController.GRADE_STAND), 0.0,
		"Liegenbleiben kostet keine Zeit")
	assert_eq(VitrineView.entry_time(0, ShopController.GRADE_RISE), 0.0)

func test_der_auftritt_ist_gestaffelt_und_gedeckelt() -> void:
	var one := VitrineView.entry_time(1, ShopController.GRADE_RISE)
	assert_almost_eq(one, DataCellView.RISE_TIME, 0.0001, "der erste wartet auf niemanden")
	assert_lte(VitrineView.entry_time(30, ShopController.GRADE_RISE),
		VitrineView.ENTER_SPREAD_MAX + DataCellView.RISE_TIME + 0.0001,
		"eine volle Auslage sprengt die Staffelung nicht")

func test_eine_auslage_ohne_regal_stellt_ihren_block_mittig() -> void:
	# Der Laden führt keine Regalware mehr: dann gehört die Tiefe der Schale
	# allein, und der BLOCK aus Würfel plus Beschriftung steht mittig darin - was
	# die Beschriftung nicht braucht, liegt zu gleichen Teilen davor und dahinter.
	var bay := VitrineView.new()
	bay.center = Vector3.ZERO
	bay.half = Vector2(9.0, 13.0)
	var margin := bay.half.x * 2.0 * VitrineView.EDGE_MARGIN
	var back := bay.center.x + bay.half.x - margin
	var front := bay.center.x - bay.half.x + margin
	bay.label_reserve = 4.0
	var bands: Vector2 = bay._band_depths()
	var behind := back - (bands.y + VitrineView.bowl_reach())
	var ahead := (bands.y - bay.label_reserve) - front
	assert_almost_eq(behind, ahead, 0.0001, "vor und hinter dem Block liegt gleich viel Luft")
	assert_gt(behind, 0.0, "und der Block bleibt im Feld")
	# Ohne Beschriftung rückt die Ware nach vorn, mit zu viel davon an die Kante.
	bay.label_reserve = 0.0
	assert_lt(bay._band_depths().y, bands.y,
		"je mehr Beschriftung, desto weiter hinten steht die Ware")
	bay.label_reserve = 999.0
	assert_almost_eq(bay._band_depths().y, back - VitrineView.bowl_reach(), 0.0001,
		"paßt sie nicht mehr, steht die Schale auf Anschlag an der hinteren Kante")
	bay.free()

func test_eine_enge_auslage_rueckt_ihre_baender_an_die_kanten() -> void:
	# Liegend ist eine Kassette länger als das Regalband einer kleinen Auslage
	# (Hinterzimmer) - dann stehen beide Bänder auf Anschlag statt ineinander.
	var shelf := {ShopController.KIND_ENGRAVING_PACK: [Pack.roll_engraving_pack()]}
	var narrow := VitrineView.new()
	narrow.center = Vector3.ZERO
	narrow.half = Vector2(2.5, 3.8)
	narrow.stock = shelf
	var bands: Vector2 = narrow._band_depths()
	var margin := narrow.half.x * 2.0 * VitrineView.EDGE_MARGIN
	assert_lte(bands.x + VitrineView.shelf_reach(), narrow.half.x - margin + 0.0001,
		"die liegende Kassette bleibt vor der hinteren Kante")
	assert_gte(bands.y - VitrineView.bowl_reach(), -narrow.half.x + margin - 0.0001,
		"und die Schale vor der vorderen")
	assert_gte(bands.x - bands.y,
		VitrineView.shelf_reach() + VitrineView.bowl_reach() - 0.0001,
		"Regal und Schale greifen nicht ineinander")
	narrow.free()
	# Eine weite Auslage (der Laden) bleibt bei ihren Anteilen.
	var wide := VitrineView.new()
	wide.center = Vector3.ZERO
	wide.half = Vector2(9.0, 13.0)
	wide.stock = shelf
	var roomy: Vector2 = wide._band_depths()
	assert_almost_eq(roomy.x, wide._depth_at(0.0, VitrineView.SHELF_DEPTH_SHARE), 0.0001)
	assert_almost_eq(roomy.y, wide._depth_at(VitrineView.SHELF_DEPTH_SHARE, 1.0), 0.0001)
	wide.free()

func test_die_oben_liegende_seite_der_auslage_ist_gestellt_nicht_geraten() -> void:
	assert_eq(VitrineView.die_up_face(), DiceController.AXIS_FACE_INDEX["OBEN"])

func test_die_charm_zeile_blaettert_mit_der_ware() -> void:
	# ui/ greift nicht in table/ - also spiegelt der Laden die Zahl, und dieser
	# Test hält die beiden gleich.
	assert_almost_eq(ShopController.FLIP_DELAY, VitrineView.SWAP_TIME, 0.0001,
		"die neuen Karten erscheinen, wenn auch die neue Ware kommt")

# --- Die Übergabe an die Lieferung ---------------------------------------------

func test_die_uebergabe_hebt_erst_an_und_sinkt_dann() -> void:
	# Die Lieferung holt die Ware erst ab, wenn sie durch die Fläche ist - die
	# Fahrt danach richtet sich nach genau dieser einen Zahl.
	assert_almost_eq(VitrineView.take_out_time(),
		VitrineView.LIFT_TIME + VitrineView.SINK_TIME, 0.0001)
	assert_lt(VitrineView.LIFT_TIME, VitrineView.SINK_TIME,
		"das Anheben ist die Geste, das Absinken die Fahrt")
	assert_lt(VitrineView.take_out_time(), 0.6, "Kaufen darf nicht zäh werden")

func test_ankommen_darf_sich_setzen() -> void:
	assert_gt(DataCellView.RISE_TIME, VitrineView.SINK_TIME,
		"Aufsteigen dauert länger als Absinken - die Ankunft ist die Aussage")
