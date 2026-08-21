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

func test_beide_shader_fuehren_dieselbe_loecherliste() -> void:
	# Eine STÄNDIGE Grube (das Magazin, Platz 0) plus die flüchtigen Schächte der
	# Hebebühnen. Beide Shader lesen dieselbe Liste - hinter einem Loch darf weder
	# Anzeige noch Filz stehen.
	var glass: String = load("res://assets/shaders/screen_glass.gdshader").code
	var ground: String = load("res://assets/shaders/table_ground.gdshader").code
	assert_true(glass.contains("pit_rects[MAX_PITS]"), "das Glas kennt die Liste")
	assert_true(glass.contains("pit_count") and glass.contains("discard"))
	assert_true(ground.contains("pit_bounds[MAX_PITS]"), "der Boden ebenso")
	assert_true(ground.contains("pit_count"))
	for code: String in [glass, ground]:
		assert_true(code.contains("const int MAX_PITS = %d" % TableScreen.MAX_PITS),
			"und beide auf demselben Deckel wie TableScreen")
	# Die alten Einzel-Uniforms sind fort - sonst schriebe irgendwer noch an ihnen.
	assert_false(ground.contains("pit_min"), "der Boden kennt pit_min nicht mehr")
	assert_false(glass.contains("uniform float pit_radius"),
		"und das Glas keinen einzelnen Radius")

func test_die_magazin_grube_bleibt_auf_platz_null() -> void:
	# Sie ist Möbel, kein Auftritt: ihr Platz wird nie geräumt.
	assert_eq(TableScreen.PIT_MAGAZIN, 0)
	assert_gt(TableScreen.PIT_SHOP_SLITS, TableScreen.PIT_MAGAZIN)
	var slots := [TableScreen.PIT_SHOP_SLITS, TableScreen.PIT_SHOP_BOWL,
		TableScreen.PIT_SECRET_SHELF, TableScreen.PIT_SECRET_BOWL]
	for slot: int in slots:
		assert_lt(slot, TableScreen.MAX_PITS, "jeder Schacht hat seinen Platz")
	assert_eq(slots.size(), TableScreen.MAX_PITS - 1, "und mehr gibt es nicht")
	# Die Zonen einer Auslage liegen hintereinander - scene_root addiert sie auf
	# ihren Sockel.
	assert_eq(TableScreen.PIT_SHOP_SLITS + VitrineView.ZONE_BOWL,
		TableScreen.PIT_SHOP_BOWL)
	assert_eq(TableScreen.PIT_SECRET_SHELF + VitrineView.ZONE_BOWL,
		TableScreen.PIT_SECRET_BOWL)

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
	# Eine ZONE taucht als Block: die Zahl der Stücke sagt nur noch, OB etwas geht.
	var swap := VitrineView.swap_time(30)
	assert_almost_eq(swap, VitrineView.SWAP_TIME, 0.0001, "die Zone taucht als Block")
	assert_almost_eq(VitrineView.swap_time(1), VitrineView.SWAP_TIME, 0.0001,
		"ein einzelnes Stück fährt denselben Zyklus")
	assert_eq(VitrineView.swap_time(0), 0.0, "eine leere Auslage sinkt nicht")
	var rise := VitrineView.entry_time(30, ShopController.GRADE_RISE)
	# Der ganze Maschinenzyklus (Senken, Einschub, Hub) ist bewußt länger als das
	# alte Durchscheinen - aber Stöbern darf nicht zäh werden.
	assert_lte(swap + rise, 2.8, "der ganze Umschlag bleibt unter 2,8 s")
	assert_eq(VitrineView.entry_time(30, ShopController.GRADE_STAND), 0.0,
		"Liegenbleiben kostet keine Zeit")
	assert_eq(VitrineView.entry_time(0, ShopController.GRADE_RISE), 0.0)

func test_der_auftritt_deckt_den_ganzen_maschinenzyklus() -> void:
	# Der Deckel muss die ANKÜNDIGUNG, den Zonenversatz UND den ganzen Zyklus
	# (Senken, Einschub, Hub, Setz-Dip) tragen - sonst hingen die Netze unter
	# fahrender Ware, und ein Schacht stünde nach dem Deckel noch offen.
	var full := VitrineView.entry_time(1, ShopController.GRADE_RISE)
	assert_almost_eq(full,
		VitrineView.SEAM_LEAD + VitrineView.LIFT_LAG
			+ LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME
			+ LiftShaftView.LIFT_TIME + LiftShaftView.DIP_TIME, 0.0001,
		"Fuge, Versatz bis zur letzten Zone und deren ganzer Zyklus")
	assert_almost_eq(VitrineView.machine_time(), LiftShaftView.cycle_time(), 0.0001,
		"die Zeiten der Maschine gehören der Maschine")
	assert_eq(VitrineView.entry_time(30, ShopController.GRADE_RISE), full,
		"eine Zone fährt als Block - die Stückzahl ändert nichts")
	assert_gt(full, VitrineView.lift_delay(VitrineView.ZONE_BOWL)
		+ VitrineView.machine_time() - 0.0001,
		"keine Zone steht später als der Deckel")

func test_der_schacht_ist_tiefer_als_das_hoechste_stueck() -> void:
	# Sonst stünde ein Würfel auf der gesenkten Plattform noch über der Fläche.
	assert_gt(VitrineView.shaft_depth(), VitrineView.content_depth(),
		"über dem höchsten Stück bleibt Kopffreiheit")
	assert_gt(VitrineView.shaft_depth(), VitrineView.die_drop(),
		"und der Würfel verschwindet ganz darin")
	# Und das Öffnungsband der Rückwand muß das höchste Stück durchlassen, sonst
	# schöbe es sich am Sturz fest.
	assert_gt(VitrineView.shaft_depth() * LiftShaftView.MOUTH_SHARE,
		VitrineView.content_depth(), "die Rückwandöffnung läßt das höchste Stück durch")
	assert_lt(LiftShaftView.MOUTH_SHARE, 1.0, "und darunter bleibt ein Sturz stehen")
	# Die Ware wartet am ENDE des Hohlraums, nicht knapp hinter dem Sturz - sonst
	# läge sie im Blickwinkel durch das Öffnungsband.
	assert_gte(LiftShaftView.CAVITY_SHARE, 1.0,
		"der Hohlraum ist so tief wie der Schacht")

func test_die_zonen_fahren_nacheinander_und_tauchen_gespiegelt() -> void:
	assert_almost_eq(VitrineView.lift_delay(VitrineView.ZONE_SHELF),
		VitrineView.SEAM_LEAD, 0.0001, "das Regal fährt zuerst - nach der Ankündigung")
	assert_almost_eq(VitrineView.lift_delay(VitrineView.ZONE_BOWL),
		VitrineView.SEAM_LEAD + VitrineView.LIFT_LAG, 0.0001,
		"die Schale kommt um die Überlappung später")
	assert_lt(VitrineView.LIFT_LAG, LiftShaftView.cycle_time(),
		"Überlappung: Zone 2 fährt an, bevor Zone 1 steht")
	# GESPIEGELT: beim Blättern taucht die Schale zuerst.
	assert_eq(VitrineView.sink_delay(VitrineView.ZONE_BOWL), 0.0,
		"die Schale taucht zuerst")
	assert_almost_eq(VitrineView.sink_delay(VitrineView.ZONE_SHELF),
		VitrineView.ZONE_LAG, 0.0001, "die Gravuren danach")

func test_jeder_koerper_faehrt_seinen_eigenen_weg() -> void:
	# Eine flache Kassette aus der Tiefe eines Würfels verbrächte ihre Fahrt
	# unsichtbar und ploppte am Ende heraus - jedes Stück startet an SEINEM Maß.
	assert_lt(VitrineView.cell_drop(), VitrineView.die_drop(),
		"die liegende Karte ist flacher als ein Würfel samt Silhouette")
	assert_almost_eq(VitrineView.die_drop(), VitrineView.sink_drop(), 0.0001,
		"der Würfel IST das höchste Stück der Auslage")
	assert_almost_eq(VitrineView.body_drop(autofree(DataCellView.new())),
		VitrineView.cell_drop(), 0.0001)

func test_die_zone_haengt_am_platz_nicht_am_koerper() -> void:
	assert_eq(VitrineView.zone_of(ShopController.KIND_DIE), VitrineView.ZONE_BOWL,
		"offene Ware liegt in der Schale")
	assert_eq(VitrineView.zone_of(ShopController.KIND_ENGRAVING_PACK),
		VitrineView.ZONE_SHELF, "Versiegeltes ins Regal")
	assert_eq(VitrineView.zone_of_key(
		VitrineView.slot_key(ShopController.KIND_DIE, 3)), VitrineView.ZONE_BOWL,
		"und der Schlüssel trägt seine Gattung mit")

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
		VitrineView.TAKE_LIFT_TIME + VitrineView.TAKE_SINK_TIME, 0.0001)
	assert_lt(VitrineView.TAKE_LIFT_TIME, VitrineView.TAKE_SINK_TIME,
		"das Anheben ist die Geste, das Absinken die Fahrt")
	assert_lt(VitrineView.take_out_time(), 0.6, "Kaufen darf nicht zäh werden")

func test_der_einzelkauf_faehrt_keinen_maschinenzyklus() -> void:
	# Die Hebebühne gehört dem AUFDECKEN; eine Übergabe bleibt eine Übergabe.
	assert_lt(VitrineView.take_out_time(),
		VitrineView.entry_time(1, ShopController.GRADE_RISE),
		"der Kauf ist kürzer als ein Auftritt")

func test_ankommen_darf_sich_setzen() -> void:
	assert_gt(LiftShaftView.LIFT_TIME, VitrineView.SWAP_SINK,
		"Aufsteigen dauert länger als Absinken - die Ankunft ist die Aussage")
	assert_gt(LiftShaftView.DIP, 0.0, "und sie rastet mit einem Setz-Dip ein")
	# Die alte Morph-Hebebühne der Zelle ist ersetzt: es gibt nur noch die Maschine.
	assert_false(autofree(DataCellView.new()).has_method("lift_through_glass"),
		"eine Kassette steigt nicht mehr von selbst durch die Fläche")
