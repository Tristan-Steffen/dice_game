extends GutTest
## Die VITRINE als AUSLAGE mit Ware: geprüft wird der EINE Abgleich (je Platz ein
## Körper), die Aufteilung "Regal hinten, Schale vorn", der Auftritt durch die
## Fläche und der Griff. Kein Kamerastrahl - die Auslage wird in WELT-Punkten
## gefragt, das Übersetzen bleibt scene_root. Bezahlte Ware wartet hier NICHT mehr:
## sie liegt in der Schale an der Werkbank (AusgabefachView).

const CENTER := Vector3(-30.0, 0.0, 0.0)
const HALF := Vector2(9.0, 13.0)

var bay: VitrineView

func before_each() -> void:
	bay = VitrineView.new("ProbeVitrine")
	add_child_autofree(bay)
	bay.setup(CENTER, HALF)

func _stock(packs: Array, dice: Array, specials: Array) -> Dictionary:
	return {
		ShopController.KIND_ENGRAVING_PACK: packs,
		ShopController.KIND_DIE: dice,
		ShopController.KIND_SPECIAL: specials,
	}

func _die() -> DieDefinition:
	return DieDefinition.standard()

func test_je_platz_ein_koerper() -> void:
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	assert_eq(bay.items.size(), 2, "ein Paket und ein Würfel liegen darin")
	# Ein zweiter Abgleich derselben Auslage stellt nur nach - er verdoppelt nichts.
	bay.present(bay.stock)
	await wait_frames(2)
	assert_eq(bay.items.size(), 2, "derselbe Abgleich, dieselben zwei Stücke")

func test_in_der_auslage_liegt_alles_das_regal_hinten() -> void:
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	var shelf := bay.spot_of(ShopController.KIND_ENGRAVING_PACK, 0)
	var bowl := bay.spot_of(ShopController.KIND_DIE, 0)
	# HINTEN ist Welt-+X (der Bildschirm-oben der Anzeigefläche).
	assert_gt(shelf.x, bowl.x, "die Kassette liegt hinter der offenen Ware")
	var cell: DataCellView = bay.item_at(shelf)["cell"]
	assert_true(cell.lying(), "sie LIEGT - in der Auslage steht nichts")
	assert_almost_eq(shelf.y, bay.cell_y(), 0.0001, "und ruht auf der Tischfläche")
	assert_almost_eq(bowl.y,
		bay.lie_y(DieBuilder.HALF_EXTENT * VitrineView.DIE_SCALE), 0.0001,
		"der Würfel ebenso")

func test_die_liegende_kassette_zeigt_ihre_groesse_nach_oben() -> void:
	# Von oben sieht man ihre große Fläche: Sortenzeichen in der Mitte, die
	# Größen-Streifen auf dem Kopfbalken daneben - die Kappe zeigt zur Seite.
	var big := Pack.tiered(Pack.roll_engraving_pack(), Pack.TIER_KOLOSSAL)
	bay.present(_stock([big], [], []))
	await wait_frames(2)
	var cell: DataCellView = bay.item_at(
		bay.spot_of(ShopController.KIND_ENGRAVING_PACK, 0))["cell"]
	assert_not_null(cell.get_node_or_null("Body/Cell0/Glyph"),
		"das Sortenzeichen liegt auf der Fläche")
	for i in Pack.TIER_KOLOSSAL:
		assert_not_null(cell.get_node_or_null("Body/Cell0/TierFace%d" % i),
			"Streifen %d liegt mit nach oben" % i)

func test_ein_buendel_traegt_seine_zahl_auf_der_karte() -> void:
	# Von oben gelesen gehört die Marke auf die Fläche, nicht neben die Karte.
	var bundle := Pack.fixed_engraving_pack(Engraving.pointer_engraving(), 3)
	bay.present(_stock([bundle], [], []))
	await wait_frames(2)
	var cell: DataCellView = bay.item_at(
		bay.spot_of(ShopController.KIND_ENGRAVING_PACK, 0))["cell"]
	assert_true(cell.badge_on_face, "die Auslage stellt die Marke um")
	assert_eq(cell.badge_text(), "×3")
	var badge: Label3D = cell.get_node("Body/CountBadge")
	assert_true(badge.visible, "liegend zählt die Schwebemarke")
	assert_lt(absf(badge.global_position.z - cell.global_position.z),
		DataCellView.WIDTH * PackDrawerView.CASSETTE_SCALE * 0.5,
		"und sie liegt über der Karte, nicht neben ihr")

func test_ein_verkaufter_platz_bleibt_leer_und_ruecht_nichts_nach() -> void:
	var second := Pack.roll_engraving_pack()
	bay.present(_stock([Pack.roll_engraving_pack(), second], [], []))
	await wait_frames(2)
	var right := bay.spot_of(ShopController.KIND_ENGRAVING_PACK, 1)
	bay.present(_stock([null, second], [], []))
	await wait_frames(2)
	assert_eq(bay.items.size(), 1, "der verkaufte Platz trägt nichts mehr")
	assert_true(bay.spot_of(ShopController.KIND_ENGRAVING_PACK, 1).is_equal_approx(right),
		"der Nachbar bleibt, wo er stand - die Lücke ist die Auskunft")

func test_der_griff_findet_das_stueck_unter_dem_punkt() -> void:
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	var spot := bay.spot_of(ShopController.KIND_DIE, 0)
	var hit := bay.item_at(Vector3(spot.x, CENTER.y, spot.z))
	assert_false(hit.is_empty(), "über dem Würfel liegt der Würfel")
	assert_eq(String(hit["kind"]), ShopController.KIND_DIE)
	assert_eq(int(hit["index"]), 0)
	assert_true(bay.item_at(Vector3(CENTER.x, CENTER.y, CENTER.z + HALF.y * 0.98)).is_empty(),
		"an der Kante liegt nichts")

func test_die_auslage_bekommt_die_ganze_flaeche() -> void:
	# Das Ausgabefach ist an die Werkbank gezogen - die Rinne rechts entfällt, und
	# die Auslage steht mittig in der ganzen Fläche.
	bay.present(_stock([], [_die(), _die(), _die()], []))
	await wait_frames(2)
	var left := bay.spot_of(ShopController.KIND_DIE, 0)
	var right := bay.spot_of(ShopController.KIND_DIE, 2)
	assert_almost_eq((left.z + right.z) * 0.5, CENTER.z, 0.0001,
		"die Reihe steht mittig in der Auslage, nicht in ihrer linken Hälfte")

# --- Die zwei Ankunfts-Grade ---------------------------------------------------

## Alle Körper der Auslage mit ihrer Lage - der Vergleichsmaßstab jeder Ankunft.
func _poses(view: VitrineView) -> Dictionary:
	var out: Dictionary = {}
	for item in view.items:
		var body: Node3D = item["node"]
		out[String(item["key"])] = [body.global_position, body.global_basis]
	return out

func _assert_same_poses(graded: Dictionary, hard: Dictionary, what: String) -> void:
	assert_eq(graded.keys().size(), hard.keys().size(), "%s: dieselben Körper" % what)
	for key: String in hard.keys():
		assert_true(graded.has(key), "%s: %s fehlt" % [what, key])
		if not graded.has(key):
			continue
		assert_true((graded[key][0] as Vector3).is_equal_approx(hard[key][0]),
			"%s: %s liegt auf seinem Platz" % [what, key])
		assert_true((graded[key][1] as Basis).is_equal_approx(hard[key][1]),
			"%s: %s liegt in seiner Ruhelage" % [what, key])

func _probe(grade: String, contents: Dictionary) -> VitrineView:
	var probe := VitrineView.new("GradeProbe")
	add_child_autofree(probe)
	probe.setup(CENTER, HALF)
	probe.present_graded(contents, grade)
	return probe

## Das Erscheinen einer frischen Kassette ist ein eigener Tween (materialize) und
## läuft in JEDEM Grad - er muss durch sein, bevor die Lagen vergleichbar sind.
func _await_appearance() -> void:
	await wait_seconds(DataCellView.MATERIALIZE_TIME + 0.1)

func test_jeder_grad_endet_dort_wo_ein_hartes_present_endet() -> void:
	var contents := _stock([Pack.roll_engraving_pack(), Pack.roll_engraving_pack()],
		[_die(), _die()], [])
	bay.present(contents)
	var rise := _probe(ShopController.GRADE_RISE, contents)
	# Übersprungene Tweens: der Endzustand steht trotzdem.
	rise.settle()
	await _await_appearance()
	var hard := _poses(bay)
	assert_gt(hard.keys().size(), 3, "die Probe trägt Regal und Schale")
	_assert_same_poses(_poses(rise), hard, "Aufsteigen")

func test_der_auftritt_beginnt_HINTER_und_UNTER_der_flaeche() -> void:
	# Die Ware wartet im Hohlraum HINTER dem Schacht (Welt-+X ist hinten) und auf
	# Schachttiefe - dort deckt das opake Display sie, bis sie hereinschiebt.
	bay.set_shown(true)
	bay.present_graded(_stock([], [_die()], []), ShopController.GRADE_RISE)
	var body: Node3D = bay.items[0]["node"]
	var spot: Vector3 = bay.items[0]["spot"]
	assert_almost_eq(body.global_position.y, spot.y - VitrineView.shaft_depth(), 0.0001,
		"er beginnt seinen Weg unter der Anzeige")
	assert_gt(body.global_position.x, spot.x, "und HINTER seinem Platz")
	# Es gibt keine Ankündigung mehr: die Maschine fährt sofort - erst senkt sich die
	# Platte, und solange wartet die Ware noch hinten.
	var waiting := body.global_position
	await wait_seconds(LiftShaftView.SINK_TIME * 0.5)
	assert_true(body.global_position.is_equal_approx(waiting),
		"im Senken wartet die Ware noch im Hohlraum")
	await wait_seconds(VitrineView.entry_time(1, ShopController.GRADE_RISE) + 0.1)
	assert_true(body.global_position.is_equal_approx(spot), "und endet auf seinem Platz")

func test_die_ware_schiebt_von_hinten_auf_die_gesenkte_plattform() -> void:
	# Die drei Schläge der Maschine, jeder an seinem Punkt gemessen.
	bay.set_shown(true)
	bay.present_graded(_stock([], [_die()], []), ShopController.GRADE_RISE)
	var body: Node3D = bay.items[0]["node"]
	var spot: Vector3 = bay.items[0]["spot"]
	var drop := VitrineView.shaft_depth()
	var waiting := body.global_position
	# Mitten im SENKEN: die Plattform fährt, die Ware wartet noch hinten.
	await wait_seconds(LiftShaftView.SINK_TIME * 0.5)
	assert_almost_eq(body.global_position.x, waiting.x, 0.001,
		"die Schale wartet noch im Hohlraum")
	# Mitten im EINSCHUB: unterwegs nach vorn, aber noch auf der gesenkten Platte.
	await wait_seconds(LiftShaftView.SINK_TIME * 0.5 + LiftShaftView.PUSH_TIME * 0.5)
	assert_lt(body.global_position.x, waiting.x, "sie schiebt herein")
	assert_gt(body.global_position.x, spot.x, "und ist noch nicht auf ihrem Platz")
	assert_almost_eq(body.global_position.y, spot.y - drop, 0.001,
		"dabei liegt sie auf der gesenkten Plattform")
	# Mitten im HUB: sie steht auf ihrem Platz in x/z und fährt herauf.
	await wait_seconds(LiftShaftView.PUSH_TIME * 0.5 + LiftShaftView.LIFT_TIME * 0.5)
	assert_almost_eq(body.global_position.x, spot.x, 0.01)
	assert_lt(body.global_position.y, spot.y, "sie ist mitten auf der Fahrt")
	assert_gt(body.global_position.y, spot.y - drop, "und schon über der Sohle")

func test_eine_zone_faehrt_als_block() -> void:
	# Kein Stück-Stagger mehr: alle Würfel der Schale stehen zu jedem Zeitpunkt auf
	# DERSELBEN Höhe - das ist die ganze Lesart der Hebebühne.
	bay.set_shown(true)
	bay.present_graded(_stock([], [_die(), _die(), _die()], []),
		ShopController.GRADE_RISE)
	await wait_seconds(LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME
		+ LiftShaftView.LIFT_TIME * 0.5)
	var heights: Array[float] = []
	for item in bay.items:
		heights.append((item["node"] as Node3D).global_position.y)
	assert_eq(heights.size(), 3, "drei Würfel fahren")
	for y in heights:
		assert_almost_eq(y, heights[0], 0.0001, "alle auf gleicher Höhe")
	assert_lt(heights[0], (bay.items[0]["spot"] as Vector3).y,
		"und sie sind mitten auf der Fahrt")

# --- Der Schacht: kein Loch bleibt offen ---------------------------------------
# Der wichtigste Test der Maschine. Ein Loch, das nach dem Auftritt, nach dem
# Vorhangfall oder nach einem Laufwechsel offen stünde, wäre ein Blick ins Nichts.

## Welche Zonen gerade ein offenes Loch melden.
func _open_zones(view: VitrineView) -> Array:
	var open: Array = []
	view.shaft_opened.connect(func(zone: int, _at: Vector3, _half: Vector2) -> void:
		if not open.has(zone):
			open.append(zone))
	view.shaft_closed.connect(func(zone: int) -> void: open.erase(zone))
	return open

func test_der_schacht_versteckt_seine_wartende_ware() -> void:
	# Sie wartet am ENDE des Hohlraums, hinter dem Sturz - dort deckt das opake
	# Display sie, und der Blick durch das Öffnungsband reicht nicht bis zu ihr.
	var shaft: LiftShaftView = LiftShaftView.new()
	add_child_autofree(shaft)
	shaft.setup(Vector3.ZERO, Vector2(2.0, 6.0), VitrineView.shaft_depth())
	assert_gt(shaft.waiting_offset(), 2.0 + VitrineView.shaft_depth() * 0.9,
		"die Wartestellung liegt hinter der Rückwand, nicht dicht dahinter")
	assert_almost_eq(shaft.drop(), VitrineView.shaft_depth(), 0.0001,
		"und so tief, wie die Plattform fährt")
	assert_false(shaft.visible, "im Ruhezustand ist keine Maschine da")
	assert_almost_eq(shaft.platform_y(), 0.0, 0.0001, "und ihre Platte steht bündig")

func test_der_schacht_geht_auf_und_wieder_zu() -> void:
	bay.set_shown(true)
	var open := _open_zones(bay)
	bay.present_graded(_stock([], [_die()], []), ShopController.GRADE_RISE)
	assert_true(open.is_empty(), "vor dem Anfahren gibt es keine Maschine")
	await wait_seconds(LiftShaftView.SINK_TIME * 0.5)
	assert_eq(open, [VitrineView.ZONE_BOWL], "während der Fahrt steht ihr Loch offen")
	await wait_seconds(VitrineView.entry_time(1, ShopController.GRADE_RISE) + 0.1)
	assert_true(open.is_empty(), "und danach ist es zu")

func test_jeder_abbruch_schliesst_jedes_loch() -> void:
	for abort: String in ["settle", "abdecken", "laufwechsel"]:
		var probe := VitrineView.new("AbortProbe")
		add_child_autofree(probe)
		probe.setup(CENTER, HALF)
		probe.set_shown(true)
		var open := _open_zones(probe)
		probe.present_graded(_stock([Pack.roll_engraving_pack()], [_die()], []),
			ShopController.GRADE_RISE)
		await wait_seconds(LiftShaftView.SINK_TIME * 0.5)
		assert_false(open.is_empty(), "%s: mitten im Auftritt steht ein Loch offen" % abort)
		match abort:
			"settle": probe.settle()
			"abdecken": probe.set_shown(false)
			_: probe.clear()
		assert_true(open.is_empty(), "%s: danach ist jedes Loch zu" % abort)
		# Und es bleibt zu - kein Rest-Tween öffnet es nach.
		await wait_seconds(VitrineView.entry_time(1, ShopController.GRADE_RISE) + 0.1)
		assert_true(open.is_empty(), "%s: und es bleibt zu" % abort)

func test_jeder_abbruch_raeumt_umschlag_und_abgang_restlos() -> void:
	# Zwei Reste sind jetzt denkbar, und beide sind hier verboten: ein offenes LOCH
	# und ein verwaister ABGANGS-KÖRPER, den ein Abbruch nie freigab.
	for plan: String in [VitrineView.PLAN_SWAP, VitrineView.PLAN_EXIT]:
		# Beide Zonen fahren gleichzeitig los: gesenkt, im Band-Schritt, hebend.
		var stops := [
			LiftShaftView.SINK_TIME * 0.5,
			LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME * 0.5,
			LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME
				+ LiftShaftView.LIFT_TIME * 0.5,
		]
		# Bis zum Ende des Band-Schritts liegt die alte Ware in der Abgangs-Liste;
		# danach hat der Band-Schritt sie freigegeben und nur noch das Loch steht offen.
		var swept := LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME
		for stop: float in stops:
			for abort: String in ["settle", "abdecken", "laufwechsel"]:
				var probe := VitrineView.new("SwapAbortProbe")
				add_child_autofree(probe)
				probe.setup(CENTER, HALF)
				probe.set_shown(true)
				var open := _open_zones(probe)
				probe.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
				await wait_frames(2)
				if plan == VitrineView.PLAN_SWAP:
					probe.swap_to(_stock([Pack.roll_engraving_pack()], [_die()], []))
				else:
					probe.exit_all()
				await wait_seconds(stop)
				var what := "%s/%.2f/%s" % [plan, stop, abort]
				assert_false(open.is_empty(), "%s: die Maschine fährt wirklich" % what)
				if stop < swept:
					assert_gt(probe.leaving_count(), 0,
						"%s: es fährt wirklich etwas hinaus" % what)
				match abort:
					"settle": probe.settle()
					"abdecken": probe.set_shown(false)
					_: probe.clear()
				assert_true(open.is_empty(), "%s: jedes Loch ist zu" % what)
				assert_eq(probe.leaving_count(), 0,
					"%s: kein verwaister Abgangs-Körper" % what)
				var standing := probe.items.size()
				await wait_seconds(VitrineView.swap_time(1) + 0.1)
				assert_true(open.is_empty(), "%s: und es bleibt zu" % what)
				assert_eq(probe.leaving_count(), 0, "%s: und leer" % what)
				assert_eq(probe.items.size(), standing,
					"%s: der Bestand steht, wie der Abbruch ihn hinterließ" % what)

# --- Der KAUF: eine SEKTION der Plattform --------------------------------------
# Ein gekauftes Stück wird nicht mehr übergeben, es FÄHRT: die Sektion unter ihm
# senkt sich MIT ihm, es geht durch die HINTERE Öffnung ab (Gegenrichtung zum
# Abgang - Gekauftes reist zur Werkbank), die leere Sektion hebt sich wieder.

func test_ein_kauf_faehrt_die_sektion_und_das_stueck_nach_hinten_hinaus() -> void:
	bay.set_shown(true)
	var keep := _die()
	bay.present(_stock([], [_die(), keep], []))
	await wait_frames(2)
	var spot := bay.spot_of(ShopController.KIND_DIE, 0)
	var sold: Node3D = bay.item_at(spot)["node"]
	var open := _open_zones(bay)
	bay.present(_stock([], [null, keep], []))
	assert_eq(bay.leaving_count(), 1, "das gekaufte Stück gehört keinem Platz mehr")
	# Mitten im SENKEN: es steht über seinem Platz und fährt hinunter.
	await wait_seconds(LiftShaftView.SINK_TIME * 0.5)
	assert_eq(open, [VitrineView.ZONE_BOWL], "die Sektion hat ihr Loch geöffnet")
	assert_lt(sold.global_position.y, spot.y, "das Stück senkt sich MIT der Sektion")
	assert_almost_eq(sold.global_position.x, spot.x, 0.01, "noch auf seiner Spur")
	# Mitten im BAND-SCHRITT: nach HINTEN, die Gegenrichtung des Abgangs.
	await wait_seconds(LiftShaftView.SINK_TIME * 0.5 + LiftShaftView.PUSH_TIME * 0.5)
	assert_gt(sold.global_position.x, spot.x, "es fährt durch die HINTERE Öffnung ab")
	assert_almost_eq(sold.global_position.y, spot.y - VitrineView.shaft_depth(), 0.05,
		"und dabei auf der gesenkten Sektion")
	# Danach ist es fort, die leere Sektion oben und das Loch zu.
	await wait_seconds(VitrineView.take_time() + 0.2)
	assert_eq(bay.leaving_count(), 0, "der Band-Schritt hat es freigegeben")
	assert_true(open.is_empty(), "und die leere Sektion hat ihr Loch geschlossen")
	assert_eq(bay.items.size(), 1, "der Nachbar steht unbeirrt")

func test_die_sektion_ist_schmaler_als_die_ganze_buehne() -> void:
	# "Nur die Sektion, auf der es steht": ihr Loch ist am Stück geschnitten, nicht
	# an der Reihe - sonst zersägte der Kauf die halbe Auslage.
	bay.set_shown(true)
	bay.present(_stock([], [_die(), _die(), _die()], []))
	await wait_frames(2)
	var holes: Array[Vector2] = []
	bay.shaft_opened.connect(func(_zone: int, _at: Vector3, hole: Vector2) -> void:
		holes.append(hole))
	var row: Array = bay.stock[ShopController.KIND_DIE]
	var keep: DieDefinition = row[1]
	var last: DieDefinition = row[2]
	bay.present(_stock([], [null, keep, last], []))
	await wait_seconds(LiftShaftView.SINK_TIME * 0.5)
	assert_eq(holes.size(), 1, "genau ein Loch geht auf")
	var band := VitrineView.pick_radius(VitrineView.bowl_reach() * VitrineView.PICK_FACTOR,
		VitrineView.row_spots(3, HALF.y * 2.0 * (1.0 - VitrineView.EDGE_MARGIN * 2.0),
			HALF.y * 2.0))
	assert_lt(holes[0].y, HALF.y, "die Sektion nimmt nicht die ganze Breite")
	assert_gt(holes[0].y, band * 0.5, "aber sie fasst ihr Stück")

func test_ein_abbruch_mitten_im_kauf_laesst_kein_loch_und_keinen_koerper() -> void:
	# Beide denkbaren Reste, wieder: ein offenes LOCH und ein verwaister Körper.
	var stops := [
		LiftShaftView.SINK_TIME * 0.5,
		LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME * 0.4,
	]
	for stop: float in stops:
		for abort: String in ["settle", "abdecken", "laufwechsel", "zweiter kauf"]:
			var probe := VitrineView.new("TakeAbortProbe")
			add_child_autofree(probe)
			probe.setup(CENTER, HALF)
			probe.set_shown(true)
			var open := _open_zones(probe)
			var second := _die()
			probe.present(_stock([], [_die(), second], []))
			await wait_frames(2)
			probe.present(_stock([], [null, second], []))
			await wait_seconds(stop)
			var what := "%.2f/%s" % [stop, abort]
			assert_gt(probe.leaving_count(), 0, "%s: es fährt wirklich etwas hinaus" % what)
			match abort:
				"settle": probe.settle()
				"abdecken": probe.set_shown(false)
				"zweiter kauf": probe.present(_stock([], [null, null], []))
				_: probe.clear()
			if abort == "zweiter kauf":
				# Der zweite Kauf beendet den ersten hart und fährt selbst los.
				assert_eq(probe.leaving_count(), 1,
					"%s: nur noch das zweite Stück fährt" % what)
				probe.settle()
			assert_true(open.is_empty(), "%s: jedes Loch ist zu" % what)
			assert_eq(probe.leaving_count(), 0, "%s: kein verwaister Körper" % what)
			await wait_seconds(VitrineView.take_time() + 0.1)
			assert_true(open.is_empty(), "%s: und es bleibt zu" % what)
			assert_eq(probe.leaving_count(), 0, "%s: und leer" % what)

# --- EIN Takt für BEIDE Zonen ---------------------------------------------------
# Regal und Schale fahren GLEICHZEITIG - und in derselben Fahrt fahren Kassette und
# Würfel dieselbe Strecke. Gemessen wird in EINER Probe an derselben Stelle beider
# Fahrpläne: dort wäre ein Versatz am größten, wenn es einen gäbe.

func _measure(contents: Dictionary, plan: String, into: float) -> Array[float]:
	var probe := VitrineView.new("TaktProbe")
	add_child_autofree(probe)
	probe.setup(CENTER, HALF)
	probe.set_shown(true)
	var spots: Array[Vector3] = []
	match plan:
		VitrineView.PLAN_ENTER:
			probe.present_graded(contents, ShopController.GRADE_RISE)
		_:
			probe.present(contents)
			await wait_frames(2)
			for item in probe.items:
				spots.append(item["spot"])
			if plan == VitrineView.PLAN_SWAP:
				probe.swap_to(contents)
			else:
				probe.exit_all()
	var bodies: Array[Node3D] = []
	if spots.is_empty():
		for item in probe.items:
			spots.append(item["spot"])
			bodies.append(item["node"])
	else:
		for body in probe._leaving:
			bodies.append(body)
	await wait_seconds(into)
	var out: Array[float] = []
	for i in bodies.size():
		out.append(spots[i].y - bodies[i].global_position.y)
	return out

func test_beide_zonen_stehen_in_jeder_zeremonie_gleich_tief() -> void:
	# Regal (Kassette) und Schale (Würfel) in EINER Auslage, gemessen mitten im
	# Band-Schritt. Gleich tief heißt: gleichzeitig losgefahren.
	var into := LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME * 0.5
	for plan: String in [VitrineView.PLAN_ENTER, VitrineView.PLAN_SWAP,
			VitrineView.PLAN_EXIT]:
		var depths: Array[float] = await _measure(
			_stock([Pack.roll_engraving_pack()], [_die()], []), plan, into)
		assert_eq(depths.size(), 2, "%s: Kassette und Würfel fahren" % plan)
		if depths.size() < 2:
			continue
		assert_almost_eq(depths[0], depths[1], 0.02,
			"%s: beide Zonen stehen gleich tief - kein Versatz" % plan)
		assert_gt(depths[0], 0.0, "%s: und sie sind wirklich unterwegs" % plan)

func test_die_zeiten_kennen_keine_koerperart() -> void:
	# Alle Deckel der Auslage kommen aus der MASCHINE - kein Aufrufer darf für eine
	# Kassette eine andere Zahl bekommen als für einen Würfel.
	assert_almost_eq(VitrineView.machine_time(), LiftShaftView.cycle_time(), 0.0001)
	assert_almost_eq(VitrineView.take_time(), LiftShaftView.take_cycle_time(), 0.0001)
	assert_almost_eq(VitrineView.take_out_time(), LiftShaftView.take_out_time(), 0.0001)
	assert_almost_eq(VitrineView.entry_time(1, ShopController.GRADE_RISE),
		VitrineView.entry_time(9, ShopController.GRADE_RISE), 0.0001,
		"eine Zone fährt als Block - die Zahl der Stücke ändert die Dauer nicht")
	assert_almost_eq(VitrineView.swap_time(1), VitrineView.swap_time(9), 0.0001)
	assert_almost_eq(VitrineView.exit_time(1), VitrineView.exit_time(9), 0.0001)

func test_der_umschlag_endet_dort_wo_ein_hartes_present_endet() -> void:
	# Der Band-Schritt ist ein WEG, kein Ergebnis: sein Endzustand ist byte-gleich
	# dem, was ein hartes present des neuen Bestands schriebe.
	var target := _stock([Pack.roll_engraving_pack(), Pack.roll_engraving_pack()],
		[_die(), _die()], [])
	var reference := VitrineView.new("HardTarget")
	add_child_autofree(reference)
	reference.setup(CENTER, HALF)
	reference.present(target)
	bay.set_shown(true)
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	var wait := bay.swap_to(target)
	await wait_seconds(wait + DataCellView.MATERIALIZE_TIME + 0.1)
	_assert_same_poses(_poses(bay), _poses(reference), "Umschlag")

func test_ein_zweiter_grad_mitten_in_der_fahrt_legt_hart_nach() -> void:
	var contents := _stock([Pack.roll_engraving_pack()], [_die()], [])
	var reference := VitrineView.new("HardProbe")
	add_child_autofree(reference)
	reference.setup(CENTER, HALF)
	reference.present(contents)
	bay.present_graded(contents, ShopController.GRADE_RISE)
	# Mitten in der FAHRT: der harte Endzustand muss auch einen abgeräumten
	# Zonen-Tween überstehen.
	await wait_seconds(LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME * 0.5)
	bay.present(contents)  # neue Auslage mitten im Auftritt
	await _await_appearance()
	_assert_same_poses(_poses(bay), _poses(reference), "Laufwechsel")

# --- Der BAND-SCHRITT: Umschlag und Abgang --------------------------------------

func test_der_umschlag_zeigt_sofort_den_neuen_bestand() -> void:
	bay.set_shown(true)
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	var wait := bay.swap_to(_stock([Pack.roll_engraving_pack()], [_die(), _die()], []))
	assert_eq(bay.items.size(), 3, "ab dem ersten Bild trägt items den NEUEN Bestand")
	assert_eq(bay.leaving_count(), 2, "und die alte Ware fährt nur noch hinaus")
	assert_gt(wait, 0.0, "der Band-Schritt braucht seine Zeit")
	assert_lte(wait, VitrineView.swap_time(1) + 0.0001)
	await wait_seconds(wait + 0.1)
	assert_eq(bay.leaving_count(), 0, "danach ist die alte Ware freigegeben")
	assert_eq(bay.items.size(), 3, "und die neue liegt vollständig da")

func test_im_band_schritt_fahren_beide_fuhren_in_dieselbe_richtung() -> void:
	# Der ganze Trick: alte und neue Stücke legen ZEITGLEICH dasselbe Maß nach vorn
	# zurück. Ihr Abstand bleibt konstant, sie können sich nicht einholen.
	bay.set_shown(true)
	bay.present(_stock([], [_die()], []))
	await wait_frames(2)
	var old_body: Node3D = bay.items[0]["node"]
	var old_spot: Vector3 = bay.items[0]["spot"]
	bay.swap_to(_stock([], [_die()], []))
	var fresh: Node3D = bay.items[0]["node"]
	var fresh_spot: Vector3 = bay.items[0]["spot"]
	assert_ne(fresh, old_body, "eine neue Seite bringt neue Körper")
	# Mitten im BAND-SCHRITT: beide liegen auf Plattformebene, das alte VOR seinem
	# Platz, das neue noch dahinter - und beide sichtbar.
	await wait_seconds(VitrineView.belt_moment() + LiftShaftView.PUSH_TIME * 0.5)
	var drop := VitrineView.shaft_depth()
	assert_almost_eq(old_body.global_position.y, old_spot.y - drop, 0.01,
		"das alte Stück liegt auf der gesenkten Plattform")
	assert_almost_eq(fresh.global_position.y, fresh_spot.y - drop, 0.01,
		"das neue ebenso - eine Ebene, ein Band")
	assert_lt(old_body.global_position.x, old_spot.x, "das alte schiebt nach vorn hinaus")
	assert_gt(fresh.global_position.x, fresh_spot.x, "das neue rückt von hinten nach")
	assert_gt(fresh.global_position.x - old_body.global_position.x,
		DieBuilder.HALF_EXTENT * VitrineView.DIE_SCALE * 2.0,
		"und zwischen ihnen bleibt mehr als eine Würfelbreite Luft")

func test_der_abgang_laesst_die_auslage_leer_zurueck() -> void:
	bay.set_shown(true)
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	var wait := bay.exit_all()
	assert_eq(bay.items.size(), 0, "was hinausfährt, ist nicht mehr zu greifen")
	assert_eq(bay.leaving_count(), 2, "beide Stücke fahren hinaus")
	assert_gt(wait, 0.0)
	await wait_seconds(wait + 0.1)
	assert_eq(bay.leaving_count(), 0, "danach ist die Auslage wirklich leer")
	assert_eq(bay.items.size(), 0)

func test_ein_leeres_fach_kostet_keinen_umschlag() -> void:
	assert_eq(bay.swap_to({}), 0.0, "eine leere Auslage tauscht nichts")
	assert_eq(bay.exit_all(), 0.0, "und hat nichts zu schlucken")

# --- Abgedeckt heißt: gar nicht da ---------------------------------------------

func test_abgedeckt_ist_kein_koerper_der_auslage_da() -> void:
	assert_false(bay.visible, "eine frische Auslage steht abgedeckt da")
	bay.set_shown(true)
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	assert_true(bay.visible)
	bay.set_shown(false)
	assert_false(bay.visible, "abgedeckt heißt: gar nicht da")

func test_jedes_stueck_ruht_ueber_der_anzeige() -> void:
	# Es gibt keine Grube mehr: jeder Platz liegt ÜBER der Tischfläche, sonst
	# verschluckte das opake Display-Mesh die Ware.
	bay.set_shown(true)
	bay.present(_stock([Pack.roll_engraving_pack()], [_die(), _die()], []))
	await wait_frames(2)
	assert_gt(bay.items.size(), 0)
	for item in bay.items:
		var spot: Vector3 = item["spot"]
		assert_gt(spot.y, CENTER.y, "%s ruht auf der Fläche" % item["key"])

func test_der_griff_hebt_voll_wie_im_magazin() -> void:
	# Über der Auslage liegt nichts mehr, was den Hub deckeln müsste.
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	var cell: DataCellView = bay.item_at(
		bay.spot_of(ShopController.KIND_ENGRAVING_PACK, 0))["cell"]
	assert_almost_eq(cell.hover_lift, DataCellView.HOVER_LIFT, 0.0001,
		"dieselbe Geste wie im Magazin")
	var spot := bay.spot_of(ShopController.KIND_DIE, 0)
	bay.set_hovered(ShopController.KIND_DIE, 0)
	await wait_seconds(VitrineView.HOVER_TIME + 0.05)
	var die_body: Node3D = bay.item_at(spot)["node"]
	assert_almost_eq(die_body.global_position.y, spot.y + VitrineView.HOVER_LIFT, 0.01,
		"der Würfel hebt sich um seinen vollen Hub")
	bay.set_hovered("", -1)

func test_ein_vorlauf_haelt_BEIDE_zonen_gleich_lange_still() -> void:
	# Der Vorlauf der Abräum-Zeremonie (die Absorption der Netze) gehört BEIDEN
	# Zonen: solange er läuft, rührt sich in keiner etwas - die Ware steht noch.
	var lead := 0.45
	bay.set_shown(true)
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	var starts: Dictionary = {}
	for item in bay.items:
		starts[(item["node"] as Node3D).get_instance_id()] = item["spot"]
	var wait := bay.exit_all(lead)
	assert_almost_eq(wait, VitrineView.exit_time(2, lead), 0.0001,
		"der Deckel deckt den Vorlauf mit")
	var bodies := bay._leaving.duplicate()
	assert_eq(bodies.size(), 2, "beide Zonen fahren")
	await wait_seconds(lead * 0.6)
	for body: Node3D in bodies:
		var seat: Vector3 = starts[body.get_instance_id()]
		assert_true(body.global_position.is_equal_approx(seat),
			"im Vorlauf steht die Ware noch auf ihrem Platz")
	# Und danach fahren sie - gleich tief, denn sie fuhren gemeinsam los.
	await wait_seconds(lead * 0.4 + LiftShaftView.SINK_TIME * 0.6)
	var drops: Array[float] = []
	for body: Node3D in bodies:
		var seat: Vector3 = starts[body.get_instance_id()]
		drops.append(seat.y - body.global_position.y)
	assert_gt(drops[0], 0.0, "die erste Zone fährt")
	assert_almost_eq(drops[0], drops[1], 0.02,
		"und die zweite genau mit ihr - kein Zonenversatz")

func test_die_deckhaut_der_schaechte_kommt_von_aussen() -> void:
	# Die Plattform trägt die ANZEIGE - gemeldet, nie gesucht. Die Auslage reicht sie
	# an jeden ihrer Schächte durch, auch an einen, der erst später entsteht.
	var skin := StandardMaterial3D.new()
	bay.deck_skin = skin
	bay.set_shown(true)
	bay.present_graded(_stock([], [_die()], []), ShopController.GRADE_RISE)
	await wait_seconds(LiftShaftView.SINK_TIME * 0.5)
	var shaft: LiftShaftView = bay._shafts[VitrineView.ZONE_BOWL]
	assert_eq(shaft.deck_skin, skin, "der Schacht trägt die gemeldete Haut")
	var top: MeshInstance3D = shaft.get_node("Platform/DeckTop")
	assert_eq(top.material_override, skin, "und sie liegt wirklich auf der Deckfläche")
	assert_null(shaft.get_node_or_null("RimBack"), "einen Kragen gibt es nicht mehr")
	assert_not_null(shaft.get_node_or_null("GlowBack"), "der innere Lichtsaum bleibt")
	bay.settle()

func test_ein_laufwechsel_raeumt_die_auslage_hart() -> void:
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	bay.clear()
	assert_eq(bay.items.size(), 0, "nichts liegt mehr darin")
	assert_true(bay.half.x > 0.0, "der RAUM bleibt gestellt")
