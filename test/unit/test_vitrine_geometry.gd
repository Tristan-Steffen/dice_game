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
		TableScreen.PIT_SECRET_SHELF, TableScreen.PIT_SECRET_BOWL,
		TableScreen.PIT_SIDE_BET0, TableScreen.PIT_SIDE_BET1,
		TableScreen.PIT_SIDE_BET2, TableScreen.PIT_PAYOUT,
		TableScreen.PIT_SECRET_THIRD]
	for i in TableScreen.QUEUE_PIT_COUNT:
		slots.append(TableScreen.queue_pit(i))
	slots.append(TableScreen.PIT_POOL)
	for lane in TableScreen.SWALLOW_PIT_COUNT:
		slots.append(TableScreen.swallow_pit(lane))
	slots.append(TableScreen.PIT_TOWER)
	for slot: int in slots:
		assert_lt(slot, TableScreen.MAX_PITS, "jeder Schacht hat seinen Platz")
	assert_eq(slots.size(), TableScreen.MAX_PITS - 1, "und mehr gibt es nicht")
	# Die Würfel-Hebebühnen hängen ans ENDE, damit kein bestehender Platz
	# umnummeriert wird - und keine teilt ihr Loch mit einer anderen: die
	# Warteschlange fährt je Platz eine eigene Maschine (Fahrten überlappen),
	# der Schluck auf drei Bahnen, und die Aufspann-Wanderung je Zwinge eine.
	assert_gt(TableScreen.PIT_QUEUE0, TableScreen.PIT_SECRET_THIRD)
	assert_eq(TableScreen.PIT_QUEUE0, 10)
	assert_eq(TableScreen.queue_pit(TableScreen.QUEUE_PIT_COUNT - 1) + 1,
		TableScreen.PIT_POOL, "die Warteschlangen-Plätze liegen am Stück")
	assert_eq(TableScreen.PIT_SWALLOW0, TableScreen.PIT_POOL + 1)
	# Die TURM-BUCHT hängt ganz hinten dran - die vier toten Aufspann-Plätze sind
	# mit der Bühnen-Fahrt gestorben (Welle Y).
	assert_eq(TableScreen.PIT_TOWER,
		TableScreen.swallow_pit(TableScreen.SWALLOW_PIT_COUNT - 1) + 1)
	assert_eq(TableScreen.PIT_TOWER, TableScreen.MAX_PITS - 1)
	var source: String = load("res://scripts/table/table_screen.gd").source_code
	assert_false(source.contains("clamp_pit"), "clamp_pit ist tot")
	# Jeder Warteschlangen-Platz und jede Schluck-Bahn hat SEIN Loch.
	assert_eq(TableScreen.queue_pit(0), TableScreen.PIT_QUEUE0)
	assert_eq(TableScreen.queue_pit(99), TableScreen.PIT_QUEUE0 + 5, "geklemmt")
	assert_eq(TableScreen.swallow_pit(99), TableScreen.PIT_SWALLOW0 + 2, "geklemmt")
	# Die Ablage der Auszahlungs-Seite ist EINE Plattform, also EIN Loch - und ein
	# eigenes: die drei Wett-Gruben dürfen derweil offen stehen.
	for i in SideBetPanel.OFFER_COUNT:
		assert_ne(TableScreen.PIT_PAYOUT, TableScreen.side_bet_pit(i),
			"die Ablage teilt keinen Platz mit dem Tresen")
	# Jeder Wett-Plot hat SEINEN Platz: drei Gruben können gleichzeitig offen stehen.
	var seen: Array[int] = []
	for i in SideBetPanel.OFFER_COUNT:
		var slot := TableScreen.side_bet_pit(i)
		assert_false(seen.has(slot), "Plot %d bekommt ein eigenes Loch" % i)
		seen.append(slot)
	assert_eq(seen, [TableScreen.PIT_SIDE_BET0, TableScreen.PIT_SIDE_BET1,
		TableScreen.PIT_SIDE_BET2])
	# Der Schwarzmarkt fährt JEDES Stück aus seiner eigenen Sektion: drei Zonen,
	# drei eigene Plätze - und der dritte hängt ans ENDE, damit Wett- und
	# Auszahlungs-Plätze ihre Nummern behalten.
	var secret := TableScreen.secret_pits()
	assert_eq(secret.size(), 3, "drei Sektionen, drei Löcher")
	assert_eq(secret, [TableScreen.PIT_SECRET_SHELF, TableScreen.PIT_SECRET_BOWL,
		TableScreen.PIT_SECRET_THIRD])
	assert_gt(TableScreen.PIT_SECRET_THIRD, TableScreen.PIT_PAYOUT,
		"hinter die Wett- und Auszahlungs-Plätze gehängt")
	for slot: int in secret:
		assert_ne(slot, TableScreen.PIT_PAYOUT)
		for i in SideBetPanel.OFFER_COUNT:
			assert_ne(slot, TableScreen.side_bet_pit(i))

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

func test_der_umschlag_ist_EIN_band_schritt() -> void:
	# Der Tausch ist kein Tauchgang plus Auftritt mehr, sondern EIN Förderband-
	# Schritt: die Zahl der Stücke sagt nur noch, OB etwas geht.
	var swap := VitrineView.swap_time(30)
	assert_almost_eq(swap, VitrineView.swap_time(1), 0.0001,
		"eine Zone fährt als Block - die Stückzahl ändert nichts")
	assert_eq(VitrineView.swap_time(0), 0.0, "eine leere Auslage tauscht nichts")
	assert_almost_eq(swap, LiftShaftView.swap_cycle_time(), 0.0001,
		"ohne Vorlauf ist es genau EIN Band-Schritt")
	assert_almost_eq(VitrineView.swap_time(1, 0.7), 0.7 + LiftShaftView.swap_cycle_time(),
		0.0001, "ein Vorlauf (die Absorption) legt sich davor")
	assert_almost_eq(swap, VitrineView.entry_time(1, ShopController.GRADE_RISE), 0.0001,
		"derselbe Zyklus wie ein Auftritt - der Einschub trägt nur zwei Fuhren")
	# Stöbern darf nicht zäh werden: EIN Schritt statt Tauchen und Steigen.
	assert_lte(swap, 2.0, "ein Seitenwechsel bleibt unter 2 s")
	assert_eq(VitrineView.entry_time(30, ShopController.GRADE_STAND), 0.0,
		"Liegenbleiben kostet keine Zeit")
	assert_eq(VitrineView.entry_time(0, ShopController.GRADE_RISE), 0.0)

func test_der_abgang_deckt_seine_fahrt() -> void:
	# Senken mit der Ware, vorn hinaus, LEER herauf, Loch zu - danach ist die
	# Auslage leer, und kein Schacht steht mehr offen.
	assert_eq(VitrineView.exit_time(0), 0.0, "eine leere Auslage hat nichts zu schlucken")
	assert_almost_eq(VitrineView.exit_time(1), LiftShaftView.exit_cycle_time(), 0.0001)
	assert_almost_eq(VitrineView.exit_time(9), VitrineView.exit_time(1), 0.0001,
		"auch der Abgang fährt als Block")
	assert_almost_eq(VitrineView.exit_time(1, 0.7),
		0.7 + LiftShaftView.exit_cycle_time(), 0.0001,
		"und trägt denselben Vorlauf wie der Umschlag")
	assert_almost_eq(LiftShaftView.exit_cycle_time(), LiftShaftView.cycle_time(), 0.0001,
		"es ist dieselbe Maschine - nur fährt die Platte leer herauf")

func test_es_gibt_keine_zonen_abhaengige_zeitquelle_mehr() -> void:
	# Der Zonenversatz ist tot: kein Aufrufer kann sich eine Zeit HOLEN, die von der
	# Zone abhängt - genau darum können die Zonen nicht mehr auseinanderlaufen.
	for gone: String in ["lift_delay", "swap_delay", "exit_delay", "plan_delay",
			"_mirror_lag"]:
		assert_false((VitrineView as GDScript).has_method(gone),
			"%s taktet keine Zone mehr" % gone)
	var constants := (VitrineView as GDScript).get_script_constant_map()
	for gone: String in ["LIFT_LAG", "SEAM_LEAD", "ZONE_COUNT"]:
		assert_false(constants.has(gone), "%s gehört keiner Auslage mehr" % gone)
	# Und alle drei Fahrpläne dauern gleich lang: EIN Maschinenzyklus.
	assert_almost_eq(VitrineView.entry_time(1, ShopController.GRADE_RISE),
		VitrineView.swap_time(1), 0.0001)
	assert_almost_eq(VitrineView.swap_time(1), VitrineView.exit_time(1), 0.0001)

func test_der_ausgang_spiegelt_den_eingang() -> void:
	# Der Schacht ist symmetrisch: so weit die Ware hinten wartet, so weit fährt sie
	# vorn hinaus. Beide Fuhren legen dasselbe Maß zurück, also bleibt ihr Abstand
	# über den ganzen Band-Schritt derselbe - sie können sich nicht einholen.
	var shaft: LiftShaftView = autofree(LiftShaftView.new())
	shaft.half = Vector2(2.0, 6.0)
	shaft.depth = VitrineView.shaft_depth()
	assert_almost_eq(shaft.exit_offset(), shaft.waiting_offset(), 0.0001)
	assert_gt(shaft.exit_offset(), shaft.half.x * 2.0,
		"das Stück ist ganz aus dem Schacht heraus, wenn es steht")

func test_der_auftritt_deckt_den_ganzen_maschinenzyklus() -> void:
	# Der Deckel ist genau EIN Zyklus (Senken, Einschub, Hub, Setz-Dip) - beide
	# Zonen fahren ihn gleichzeitig. Stünde eine später, hingen die Netze unter
	# fahrender Ware und ein Schacht bliebe nach dem Deckel offen.
	var full := VitrineView.entry_time(1, ShopController.GRADE_RISE)
	assert_almost_eq(full,
		LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME
			+ LiftShaftView.LIFT_TIME + LiftShaftView.DIP_TIME, 0.0001,
		"der ganze Zyklus, kein Versatz davor")
	assert_almost_eq(VitrineView.machine_time(), LiftShaftView.cycle_time(), 0.0001,
		"die Zeiten der Maschine gehören der Maschine")
	assert_eq(VitrineView.entry_time(30, ShopController.GRADE_RISE), full,
		"eine Zone fährt als Block - die Stückzahl ändert nichts")
	assert_almost_eq(full, VitrineView.machine_time(), 0.0001,
		"keine Zone steht später als der Deckel")

func test_der_schacht_ist_tiefer_als_das_hoechste_stueck() -> void:
	# Sonst stünde ein Würfel auf der gesenkten Plattform noch über der Fläche.
	assert_gt(VitrineView.shaft_depth(), VitrineView.content_depth(),
		"über dem höchsten Stück bleibt Kopffreiheit")
	assert_gt(VitrineView.shaft_depth(), VitrineView.sink_drop(),
		"und der Würfel verschwindet ganz darin")
	# Und die Öffnungsbänder müssen das höchste Stück durchlassen, sonst schöbe es
	# sich am Sturz fest - vorn wie hinten, denn der Schacht ist symmetrisch.
	assert_gt(VitrineView.shaft_depth() * LiftShaftView.MOUTH_SHARE,
		VitrineView.content_depth(), "die Öffnungsbänder lassen das höchste Stück durch")
	assert_lt(LiftShaftView.MOUTH_SHARE, 1.0, "und darüber bleibt ein Sturz stehen")
	# Die Ware wartet am ENDE des Hohlraums, nicht knapp hinter dem Sturz - sonst
	# läge sie im Blickwinkel durch das Öffnungsband.
	assert_gte(LiftShaftView.CAVITY_SHARE, 1.0,
		"der Hohlraum ist so tief wie der Schacht")

## Wer KEINE Reichweite meldet, merkt vom Sicherheitsabstand nichts: Laden, Hinterzimmer,
## Schlitzreihe und Magazin fahren dieselbe Maschine wie zuvor.
func test_ohne_gemeldete_reichweite_bleibt_der_hohlraum_unveraendert() -> void:
	var shaft: LiftShaftView = autofree(LiftShaftView.new())
	shaft.depth = 2.0
	assert_almost_eq(shaft.cavity_span(), 2.0 * LiftShaftView.CAVITY_SHARE, 0.0001,
		"ohne Meldung nimmt der Hohlraum sein volles Wunschmaß")
	shaft.cavity_reach = 0.4
	assert_almost_eq(shaft.cavity_span(), 0.4 - LiftShaftView.REACH_CLEAR, 0.0001,
		"gemeldet heißt eingehalten - und nie ganz bis an die Nachbarwand")

## Der Pool-Schacht meldet NUR VORN: dort beginnt eine Naht unter ihm die Turm-Bucht,
## hinten schiebt die Ablage herein und braucht die volle Länge.
func test_die_vordere_meldung_kuerzt_nur_die_vordere_seite() -> void:
	var shaft := LiftShaftView.new()
	add_child_autofree(shaft)
	shaft.front_cavity_reach = 0.5
	shaft.setup(Vector3.ZERO, Vector2(1.0, 3.0), 2.0)
	var wanted := 2.0 * LiftShaftView.CAVITY_SHARE
	assert_almost_eq(shaft.cavity_span(1.0), wanted, 0.0001,
		"hinten bleibt der Hohlraum unbegrenzt")
	assert_almost_eq(shaft.cavity_span(-1.0), 0.5 - LiftShaftView.REACH_CLEAR, 0.0001,
		"vorn hält er die Meldung ein")
	assert_almost_eq(shaft.exit_offset(), 1.5 - LiftShaftView.REACH_CLEAR, 0.0001,
		"und das abgehende Stück fährt nur bis an das neue Ende")
	# Kein Bauteil - Hohlraum wie Sohle - reicht VORN über Wand plus Meldung hinaus.
	var front_limit := 1.0 + 0.5 + LiftShaftView.WALL * 2.0
	var back_reach := 0.0
	for child in shaft.get_children():
		if not (child is MeshInstance3D) or not ((child as MeshInstance3D).mesh is BoxMesh):
			continue
		var box: BoxMesh = (child as MeshInstance3D).mesh
		var near: float = -(child.position.x - box.size.x * 0.5)
		assert_lte(near, front_limit + 0.0001,
			"%s bleibt vorn in der gemeldeten Reichweite" % child.name)
		back_reach = maxf(back_reach, child.position.x + box.size.x * 0.5)
	assert_almost_eq(back_reach, 1.0 + LiftShaftView.WALL * 2.0 + wanted, 0.0001,
		"hinten steht die Stirnwand am vollen Wunschmaß")

## Ohne die vordere Meldung ist der Schacht symmetrisch wie eh und je.
func test_ohne_vordere_meldung_bleibt_der_schacht_symmetrisch() -> void:
	var shaft := LiftShaftView.new()
	add_child_autofree(shaft)
	shaft.setup(Vector3.ZERO, Vector2(1.0, 3.0), 2.0)
	assert_almost_eq(shaft.cavity_span(-1.0), shaft.cavity_span(1.0), 0.0001,
		"beide Hohlräume sind gleich tief")
	var sole: MeshInstance3D = shaft.get_node("Sole")
	assert_almost_eq(sole.position.x, 0.0, 0.0001, "und die Sohle steht mittig")

func test_die_zonen_fahren_gleichzeitig() -> void:
	# Regal und Schale starten im selben Augenblick und stehen im selben - in JEDER
	# Zeremonie. Gemessen an derselben Stelle beider Fahrpläne, dem Deckel.
	for lead: float in [0.0, 0.55]:
		assert_almost_eq(VitrineView.swap_time(1, lead),
			VitrineView.exit_time(1, lead), 0.0001,
			"Umschlag und Abgang tragen denselben Vorlauf für alle Zonen")
	assert_almost_eq(VitrineView.entry_time(1, ShopController.GRADE_RISE),
		VitrineView.machine_time(), 0.0001, "und der Auftritt ist der nackte Zyklus")

func test_die_zone_haengt_am_platz_nicht_am_koerper() -> void:
	assert_eq(VitrineView.zone_of(ShopController.KIND_DIE), VitrineView.ZONE_BOWL,
		"offene Ware liegt in der Schale")
	assert_eq(VitrineView.zone_of(ShopController.KIND_ENGRAVING_PACK),
		VitrineView.ZONE_SHELF, "Versiegeltes ins Regal")
	assert_eq(VitrineView.zone_of_key(
		VitrineView.slot_key(ShopController.KIND_DIE, 3)), VitrineView.ZONE_BOWL,
		"und der Schlüssel trägt seine Gattung mit")

# --- Der Schwarzmarkt: EINE Reihe, je Stück eine eigene Sektion ----------------

func test_single_row_legt_beide_baender_auf_eine_tiefe() -> void:
	# In single_row liegt ALLES auf center.x: nur EIN Schacht (ZONE_BOWL) geht auf,
	# statt zweier überlappender Löcher an derselben Tiefe.
	var bay := VitrineView.new()
	bay.center = Vector3(-30.0, 0.0, 0.0)
	bay.half = Vector2(9.0, 13.0)
	bay.single_row = true
	var bands: Vector2 = bay._band_depths()
	assert_almost_eq(bands.x, bay.center.x, 0.0001, "das Regalband fällt auf die Mitte")
	assert_almost_eq(bands.y, bay.center.x, 0.0001, "die Schale ebenso - EINE Tiefe")
	bay.free()

func test_single_row_gibt_jedem_platz_seine_eigene_zone() -> void:
	var bay := VitrineView.new()
	bay.single_row = true
	# Die Zone IST der Offer-Index: je Stück ein eigenes Loch, gleich welcher Sorte.
	assert_eq(bay._zone_of_key(
		VitrineView.slot_key(ShopController.KIND_ENGRAVING_PACK, 1)), 1)
	assert_eq(bay._zone_of_key(VitrineView.slot_key(ShopController.KIND_DIE, 2)), 2)
	assert_eq(bay._zone_of_key(VitrineView.slot_key(ShopController.KIND_DIE, 0)), 0)
	# Der Laden (kein single_row) liest weiter die statische Regel.
	var shop := VitrineView.new()
	assert_eq(shop._zone_of_key(
		VitrineView.slot_key(ShopController.KIND_ENGRAVING_PACK, 1)), VitrineView.ZONE_SHELF)
	assert_eq(shop._zone_of_key(
		VitrineView.slot_key(ShopController.KIND_DIE, 2)), VitrineView.ZONE_BOWL)
	bay.free()
	shop.free()

func test_die_einzel_loecher_einer_reihe_beruehren_sich_nie() -> void:
	# Zwei Nachbar-Sektionen dürfen sich nicht überlappen, sonst lugte eine unter
	# dem Stück daneben hervor: die halbe Spannweite bleibt unter der halben Teilung.
	var bay := VitrineView.new()
	bay.center = Vector3(-30.0, 0.0, 0.0)
	bay.half = Vector2(9.0, 13.0)
	bay.single_row = true
	bay._row_pitch = 4.0
	var margin := VitrineView.bowl_reach() * VitrineView.SHAFT_MARGIN_SHARE
	var span: float = bay._section_span(9.0, 9.0, margin)
	assert_lt(span, 2.0, "gedeckelt auf die halbe Teilung, minus Fuge")
	assert_almost_eq(span,
		2.0 * (1.0 - VitrineView.ROW_SHAFT_GAP_SHARE), 0.0001)
	# Ein kleines Stück bekommt sein eigenes Maß, nicht den Deckel.
	assert_almost_eq(bay._section_span(0.2, 9.0, margin), 0.2 + margin, 0.0001,
		"das Loch deckt SEIN Stück, nicht die Reihe")
	# Der Laden misst weiter an der Zonen-Reichweite.
	var shop := VitrineView.new()
	shop.center = Vector3.ZERO
	shop.half = Vector2(9.0, 13.0)
	assert_almost_eq(shop._section_span(0.2, 3.0, margin), 3.0 + margin, 0.0001)
	bay.free()
	shop.free()

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
	assert_almost_eq(ShopController.FLIP_DELAY, VitrineView.belt_moment(), 0.0001,
		"die neuen Karten erscheinen im Augenblick des Band-Schritts")
	# Der Band-Schritt beginnt, wenn die Plattform unten ist - dort ist die alte
	# Ware verschwunden und die neue rückt nach.
	assert_almost_eq(VitrineView.belt_moment(), LiftShaftView.SINK_TIME, 0.0001)
	assert_almost_eq(VitrineView.belt_moment(0.7), 0.7 + LiftShaftView.SINK_TIME,
		0.0001, "ein Vorlauf schiebt auch den Seitenwechsel")
	assert_lt(ShopController.FLIP_DELAY, VitrineView.swap_time(1),
		"und die Seite ist gewechselt, bevor der Umschlag steht")

# --- Der KAUF: eine Sektion der Plattform --------------------------------------

func test_der_kauf_faehrt_die_sektion_und_der_komet_wartet_nur_auf_den_abgang() -> void:
	# Senken und Band-Schritt: dann ist das Stück außer Sicht und die Lieferung
	# fährt los - auf die leer hochfahrende Sektion wartet kein Komet.
	assert_almost_eq(VitrineView.take_out_time(),
		LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME, 0.0001)
	assert_almost_eq(VitrineView.take_time(), LiftShaftView.cycle_time(), 0.0001,
		"der ganze Zyklus ist derselbe wie bei jeder anderen Zeremonie")
	assert_lt(VitrineView.take_out_time(), VitrineView.take_time(),
		"der Komet startet vor dem leeren Hub")
	assert_lt(VitrineView.take_out_time(), 0.9, "Kaufen darf nicht zäh werden")

func test_der_kauf_ist_ein_zyklus_der_maschine_kein_eigener_weg() -> void:
	# Es gibt keine Übergabe-Zeiten mehr: der Kauf liest ALLE seine Zahlen aus der
	# Hebebühne, genau wie Auftritt, Umschlag und Abgang.
	assert_lt(VitrineView.take_out_time(),
		VitrineView.entry_time(1, ShopController.GRADE_RISE),
		"eine Sektion ist außer Sicht, bevor die ganze Bühne steht")
	var constants := (VitrineView as GDScript).get_script_constant_map()
	for gone: String in ["TAKE_LIFT_TIME", "TAKE_SINK_TIME", "TAKE_PLUNGE"]:
		assert_false(constants.has(gone), "%s gehört keiner Auslage mehr" % gone)

func test_ankommen_darf_sich_setzen() -> void:
	assert_gt(LiftShaftView.LIFT_TIME, LiftShaftView.SINK_TIME,
		"Aufsteigen dauert länger als Absinken - die Ankunft ist die Aussage")
	assert_gt(LiftShaftView.DIP, 0.0, "und sie rastet mit einem Setz-Dip ein")
	# Die alte Morph-Hebebühne der Zelle ist ersetzt: es gibt nur noch die Maschine.
	var cell: DataCellView = autofree(DataCellView.new())
	assert_false(cell.has_method("lift_through_glass"),
		"eine Kassette steigt nicht mehr von selbst durch die Fläche")
	assert_false(cell.has_method("sink_through_glass"),
		"und sie sinkt auch nicht mehr von selbst hindurch - sie fährt")

# --- Die ABSORPTION der Netz-Blöcke (reiner Deckel) ----------------------------

func test_die_absorption_deckt_ihr_schrumpfen_samt_staffelung() -> void:
	# Der Vorlauf, den beide Zonen abwarten: das Schrumpfen plus die rückwärts
	# laufende Staffelung. Ohne Netz ist er 0 - ein leerer Laden wartet nicht.
	assert_eq(ShopController.absorb_time(0), 0.0, "kein Netz, kein Vorlauf")
	assert_almost_eq(ShopController.absorb_time(1), ShopController.NET_GROW_TIME, 0.0001,
		"ein Block schrumpft schlicht seine Zeit")
	assert_almost_eq(ShopController.absorb_time(4),
		ShopController.NET_GROW_TIME + ShopController.NET_GROW_STAGGER * 3.0, 0.0001,
		"vier Blöcke tragen ihre Staffelung mit")
	assert_gt(ShopController.absorb_time(6), ShopController.absorb_time(3),
		"mehr Blöcke, längerer Vorlauf")
	# Und der Deckel der Zeremonie deckt ihn wirklich: erst saugen, dann fahren.
	var lead := ShopController.absorb_time(6)
	assert_gt(VitrineView.exit_time(1, lead), lead + LiftShaftView.SINK_TIME,
		"die Maschine fährt erst nach der Absorption")
	assert_almost_eq(VitrineView.swap_time(1, lead) - lead,
		VitrineView.swap_time(1), 0.0001, "und dann ihren ganzen Zyklus")

# --- Die PHYSISCHE Regel des Ankunfts-Grades -----------------------------------

func test_eine_bucht_ohne_koerper_zeigt_ware_immer_als_ankunft() -> void:
	# Die Seite mag glauben, sie liege noch da - seit dem Abgang ist sie körperlich
	# fort. Der Wiedereintritt über den Laden-Knopf hängt genau daran.
	assert_eq(ShopController.grade_on_stand(ShopController.GRADE_STAND, false),
		ShopController.GRADE_RISE, "leere Bucht: die Ware kommt an")
	assert_eq(ShopController.grade_on_stand(ShopController.GRADE_STAND, true),
		ShopController.GRADE_STAND, "was wirklich liegt, bleibt liegen")
	assert_eq(ShopController.grade_on_stand(ShopController.GRADE_RISE, true),
		ShopController.GRADE_RISE, "und ein lauter Grad bleibt laut")
	assert_eq(ShopController.grade_on_stand(ShopController.GRADE_RISE, false),
		ShopController.GRADE_RISE)

# --- Die Plattform trägt das Bild der Anzeige ----------------------------------

func test_die_deckhaut_bildet_die_welt_genau_wie_world_to_pixel_ab() -> void:
	# Der Shader rechnet Weltposition -> Display-UV. Die Abbildung MUSS die von
	# world_to_pixel sein, sonst zeigte die Platte ein verschobenes Bild.
	var code: String = load("res://assets/shaders/display_skin.gdshader").code
	assert_true(code.contains("render_mode unshaded"), "unbeleuchtet wie das Glas")
	assert_true(code.contains("(world_position.z - display_map.x) / display_map.y"),
		"u = (z - z_min) / z_span")
	assert_true(code.contains("(display_map.z - world_position.x) / display_map.w"),
		"v = (x_max - x) / x_span - die Tiefenachse ist gespiegelt")
	assert_true(code.contains("MODEL_MATRIX"),
		"gerechnet wird aus der Weltposition, nicht aus einer UV")
	# Die gemessenen Farbton-Konstanten sind tot - der bündige Stand ist jetzt per
	# Konstruktion pixelidentisch.
	assert_false((LiftShaftView as GDScript).get_script_constant_map().has("DECK_TOP"),
		"kein gemessener Deckel-Ton mehr")
	for gone: String in ["BAY_GROUND"]:
		assert_false((ShopController as GDScript).get_script_constant_map().has(gone),
			"der Laden mißt keinen Buchtgrund mehr")
		assert_false((SecretShopView as GDScript).get_script_constant_map().has(gone),
			"das Hinterzimmer ebenso wenig")

# --- Kein Rahmen mehr: weder Lichtfuge noch Kragen -----------------------------

func test_die_lichtfuge_und_der_kragen_sind_restlos_fort() -> void:
	# Die Schnittkante steht nackt: kein Kragen auf der Fläche, keine Fuge davor.
	# Was den Schacht lesbar macht, liegt IN ihm.
	var shaft := (LiftShaftView as GDScript).get_script_constant_map()
	for gone: String in ["RIM_IN", "RIM_OUT", "RIM_H", "RIM_SINK", "RIM_ALBEDO",
			"RIM_EMISSION", "RIM_EMISSION_ENERGY"]:
		assert_false(shaft.has(gone), "%s gehört keinem Schacht mehr" % gone)
	assert_true(shaft.has("GLOW_H"), "der innere Lichtsaum bleibt")
	for source: String in ["res://scripts/table/lift_shaft_view.gd",
			"res://scripts/ui/shop_controller.gd",
			"res://scripts/ui/secret_shop_view.gd",
			"res://scripts/table/vitrine_view.gd"]:
		var code: String = FileAccess.get_file_as_string(source)
		assert_false(code.contains("lift_seam"), "%s kennt keine Lichtfuge" % source)
		assert_false(code.contains("SEAM_"), "%s trägt kein SEAM_-Symbol" % source)
	var machine: String = FileAccess.get_file_as_string(
		"res://scripts/table/lift_shaft_view.gd")
	assert_false(machine.contains("RIM_"), "und der Schacht kein RIM_-Symbol")
	assert_false(machine.contains("_rim_material"), "auch kein Kragen-Material")
	# Der Takt der Fugen ist mit ihnen gestorben.
	var root: String = FileAccess.get_file_as_string("res://scripts/scene_root.gd")
	for gone: String in ["_play_shop_seams", "_play_secret_seam", "_seam_token",
			"_secret_seam_token", "set_lift_seam", "hide_lift_seam"]:
		assert_false(root.contains(gone), "scene_root taktet kein %s mehr" % gone)

# --- Der PARK ist die VOLLE Tiefe, und die halbe Parkung ist restlos fort ---------

func test_die_halbe_parkhoehe_ist_tot() -> void:
	var shaft := (LiftShaftView as GDScript).get_script_constant_map()
	assert_false(shaft.has("PARK_SHARE"),
		"es gibt keinen Anteil mehr - der Park IST die Fahrstrecke")
	var code: String = FileAccess.get_file_as_string(
		"res://scripts/table/lift_shaft_view.gd")
	assert_false(code.contains("PARK_SHARE"), "auch nicht als Wort")
	# Die Restlogik der halben Parkung: ein Stück zurück heben bzw. vor dem Band-Schritt
	# noch nachsenken. Beides ist bei voller Tiefe die Strecke NULL.
	assert_false(code.contains("depth - park_y()"),
		"kein Rest-Hub zwischen Parkhöhe und Sohle mehr")
	for gone: String in ["res://scripts/scene_root.gd",
			"res://test/integration/test_side_bet_counter.gd"]:
		assert_false(FileAccess.get_file_as_string(gone).contains("PARK_SHARE"),
			"%s kennt keinen Park-Anteil" % gone)

func test_der_park_endet_auf_der_anzeigetiefe() -> void:
	var shaft := LiftShaftView.new()
	autofree(shaft)
	shaft.depth = 2.4
	assert_almost_eq(shaft.park_y(), shaft.depth, 0.0001,
		"geparkt wird auf der ANZEIGE-Tiefe - das ist das Gruben-Bild")
	assert_almost_eq(shaft.drop(), shaft.depth, 0.0001,
		"ohne bestellte Tieffahrt fällt die Band-Ebene damit zusammen")
	assert_almost_eq(shaft.park_rise(), 0.0, 0.0001, "und es gibt keinen Weg dazwischen")

## Die Takte, ehrlich nachgerechnet: ohne Tieffahrt hebt der Park nichts mehr zurück,
## dafür fährt der SCHIRM - und jede Fahrt aus dem Park beginnt damit, ihn einzuziehen.
func test_die_takte_des_parkens_rechnen_den_schirm_mit() -> void:
	var shaft := LiftShaftView.new()
	autofree(shaft)
	shaft.depth = 2.4
	assert_almost_eq(shaft.park_cycle_time(),
		LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME + LiftShaftView.COVER_TIME,
		0.0001, "senken, Band-Schritt, Schirm - kein Rest-Hub")
	assert_almost_eq(LiftShaftView.rise_cycle_time(),
		LiftShaftView.COVER_TIME + LiftShaftView.LIFT_TIME + LiftShaftView.DIP_TIME,
		0.0001, "Schirm ein, dann hebt die Ware")
	assert_almost_eq(shaft.leave_park_time(),
		LiftShaftView.COVER_TIME + LiftShaftView.PUSH_TIME + LiftShaftView.LIFT_TIME
			+ LiftShaftView.DIP_TIME, 0.0001,
		"Schirm ein, Band-Schritt, leere Platte herauf - kein Vor-Senken mehr")
	assert_lt(shaft.leave_park_time(), LiftShaftView.swap_cycle_time(),
		"und der Abgang aus dem Park bleibt unter dem Deckel der Abrechnung")
	# Mit Tieffahrt liegen Park und Band-Ebene auseinander: der Weg dazwischen ist ein
	# eigener Schlag, und die beiden Deckel rechnen ihn ehrlich mit.
	shaft.travel_share = 2.0
	assert_almost_eq(shaft.park_cycle_time(),
		LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME + LiftShaftView.LIFT_TIME
			+ LiftShaftView.COVER_TIME, 0.0001, "der Park hebt aus der Tiefe zurück")
	assert_almost_eq(shaft.leave_park_time(),
		LiftShaftView.COVER_TIME + LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME
			+ LiftShaftView.LIFT_TIME + LiftShaftView.DIP_TIME, 0.0001,
		"und der Abgang sinkt erst auf sie hinunter")
	assert_almost_eq(LiftShaftView.rise_cycle_time(),
		LiftShaftView.COVER_TIME + LiftShaftView.LIFT_TIME + LiftShaftView.DIP_TIME,
		0.0001, "die AUFFAHRT kennt nur den Parkstand und bleibt, wie sie war")

## Der Schirm hat EINE Textquelle: die Gewinn-Beschriftung der Wette. Sie wird genau
## einmal formuliert - der Setzen-Knopf und der Deckel lesen dieselbe Zeile.
func test_die_gewinn_beschriftung_hat_genau_eine_quelle() -> void:
	var panel: String = FileAccess.get_file_as_string(
		"res://scripts/ui/side_bet_panel.gd")
	assert_eq(panel.count("reward_label("), 1,
		"das Fenster formuliert den Gewinn an EINER Stelle (prize_label)")
	for foreign: String in ["res://scripts/scene_root.gd",
			"res://scripts/table/lift_shaft_view.gd",
			"res://scripts/table/bet_prize_view.gd"]:
		var code: String = FileAccess.get_file_as_string(foreign)
		assert_false(code.contains("reward_label"),
			"%s formuliert keinen Gewinn - er bekommt ihn gemeldet" % foreign)
	# Und die Maschine kennt keine Wetten: sie nimmt eine fertige Zeile entgegen.
	var machine: String = FileAccess.get_file_as_string(
		"res://scripts/table/lift_shaft_view.gd")
	for foreign: String in ["SideBet", "side_bet"]:
		assert_false(machine.contains(foreign),
			"der Schacht weiß nichts von %s" % foreign)

# --- Die WANDHAUT wird BESTELLT, und nur der Tresen bestellt ----------------------

## JEDE Grube des Tisches trägt dieselbe Wand, und die Textur hat EINE Quelle:
## scene_root nennt sie, alle anderen bekommen sie GEMELDET.
func test_die_wandhaut_hat_eine_quelle_und_deckt_jede_grube() -> void:
	var root: String = FileAccess.get_file_as_string("res://scripts/scene_root.gd")
	assert_true(root.contains("shop_vitrine.wall_skin = PIT_SKIN"),
		"die Laden-Auslage trägt sie")
	assert_true(root.contains("secret_vitrine.wall_skin = PIT_SKIN"),
		"das Hinterzimmer trägt sie")
	assert_true(root.contains("slit_shaft.order_skin(PIT_SKIN)"),
		"die Kassetten-Schlitzreihe trägt sie")
	assert_true(root.contains("pack_pit.wall_skin = PIT_SKIN"),
		"die Magazin-Grube trägt sie")
	assert_true(root.contains("shaft.order_skin(PIT_SKIN)"),
		"und die Sektion eines Wett-Plots ebenso")
	for foreign: String in ["res://scripts/table/vitrine_view.gd",
			"res://scripts/table/pack_pit_view.gd",
			"res://scripts/table/lift_shaft_view.gd"]:
		var code: String = FileAccess.get_file_as_string(foreign)
		assert_false(code.contains("gruben_paneel"),
			"%s greift nicht selbst nach der Textur - sie wird gemeldet" % foreign)

## Und die TIEFFAHRT ebenso: nur eine Grube, die OFFEN stehen bleibt, hat eine
## Nachbarin, in deren Loch die wartende Ware erschiene. Alle anderen fahren flach.
func test_die_tieffahrt_hat_genau_einen_besteller() -> void:
	var root: String = FileAccess.get_file_as_string("res://scripts/scene_root.gd")
	assert_eq(root.count("travel_share"), 1,
		"scene_root bestellt die Tieffahrt an EINER Stelle (_bet_shaft_on)")
	assert_eq(root.count("BET_PIT_DIVE"), 2,
		"eine Quelle für das Maß - Deklaration und die eine Bestellung")
	for foreign: String in ["res://scripts/table/vitrine_view.gd",
			"res://scripts/table/pack_pit_view.gd",
			"res://scripts/ui/shop_controller.gd",
			"res://scripts/ui/secret_shop_view.gd",
			"res://scripts/ui/pack_drawer_view.gd"]:
		var code: String = FileAccess.get_file_as_string(foreign)
		assert_false(code.contains("travel_share"),
			"%s fährt flach - seine Grube steht nie offen" % foreign)
	# Ungebeten ist die Fahrt genau die Anzeige-Tiefe: kein Laden merkt etwas davon.
	var shaft := LiftShaftView.new()
	autofree(shaft)
	shaft.depth = VitrineView.shaft_depth()
	assert_almost_eq(shaft.travel_share, 1.0, 0.0001)
	assert_almost_eq(shaft.drop(), VitrineView.shaft_depth(), 0.0001)

## Der Takt der Blenden liegt IN den bestehenden Schlägen: die Zyklus-Deckel bleiben
## Zahl für Zahl dieselben, ein Öffnungsband kostet keine Zeit.
func test_die_blenden_verlaengern_keinen_takt() -> void:
	var shaft := LiftShaftView.new()
	autofree(shaft)
	assert_almost_eq(LiftShaftView.cycle_time(),
		LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME + LiftShaftView.LIFT_TIME
			+ LiftShaftView.DIP_TIME, 0.0001)
	assert_almost_eq(shaft.park_cycle_time(),
		LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME + LiftShaftView.COVER_TIME,
		0.0001)
	for takt: float in [LiftShaftView.SINK_TIME, LiftShaftView.LIFT_TIME,
			LiftShaftView.COVER_TIME]:
		assert_lte(LiftShaftView.SHUTTER_TIME, takt,
			"eine Blende paßt in jeden Schlag, neben dem sie fährt")

# --- Der Rundenend-Takt der Wuerfel-Buehne --------------------------------------

func test_das_rundenende_ist_ein_vier_schlag_in_dieser_reihenfolge() -> void:
	var root: String = FileAccess.get_file_as_string("res://scripts/scene_root.gd")
	var takt := root.find("func _play_tray_return")
	assert_gt(takt, 0, "die Zeremonie steht im Koordinator")
	var flush_at := root.find("_flush_ablage_tail(", takt)
	var exit_at := root.find("await exit.finished", takt)
	var order_at := root.find("_reorder_pool_from_pit()", takt)
	var rise_at := root.find("run_rise", takt)
	assert_gt(flush_at, takt, "erst fährt die letzte Ablage-Reihe ein")
	assert_lt(flush_at, exit_at, "dann geht die Warteschlange ab")
	assert_lt(exit_at, order_at, "dann IST der Pit-Inhalt der neue Pool")
	assert_lt(order_at, rise_at, "und erst danach fährt der Träger herauf")

func test_das_blinde_glas_und_der_tausch_dahinter_sind_tot() -> void:
	var root: String = FileAccess.get_file_as_string("res://scripts/scene_root.gd")
	var shaft: String = FileAccess.get_file_as_string("res://scripts/table/lift_shaft_view.gd")
	for dead: String in ["KUHLE", "fade_cover_opacity", "set_cover_opacity",
			"run_cover_hatch"]:
		assert_false(root.contains(dead), "%s ist im Koordinator fort" % dead)
		assert_false(shaft.contains(dead), "%s ist in der Maschine fort" % dead)

func test_das_rundenstart_mischen_ist_gestorben() -> void:
	# Spielregel 2026-08-30: gezogen wird in Pool-Reihenfolge; die EINZIGE Streuung
	# ist die Ablage-Reihe beim Erscheinen.
	var root: String = FileAccess.get_file_as_string("res://scripts/scene_root.gd")
	assert_false(root.contains("round_pool_kinds.shuffle()"),
		"der Stapel wird beim Zurren nicht mehr gemischt")
	assert_true(root.contains("DiceTrayView.shuffle_row("),
		"gemischt wird nur die erscheinende Ablage-Reihe")
