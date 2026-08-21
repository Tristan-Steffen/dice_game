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

func test_der_auftritt_beginnt_unter_der_flaeche() -> void:
	# Steigen heißt: der Körper startet verdeckt und fährt herauf.
	bay.set_shown(true)
	bay.present_graded(_stock([], [_die()], []), ShopController.GRADE_RISE)
	var body: Node3D = bay.items[0]["node"]
	var spot: Vector3 = bay.items[0]["spot"]
	assert_almost_eq(body.global_position.y, spot.y - VitrineView.sink_drop(), 0.0001,
		"er beginnt seinen Weg unter der Anzeige")
	await wait_seconds(DataCellView.RISE_TIME + 0.1)
	assert_true(body.global_position.is_equal_approx(spot), "und endet auf seinem Platz")

func test_ein_zweiter_grad_mitten_in_der_fahrt_legt_hart_nach() -> void:
	var contents := _stock([Pack.roll_engraving_pack()], [_die()], [])
	var reference := VitrineView.new("HardProbe")
	add_child_autofree(reference)
	reference.setup(CENTER, HALF)
	reference.present(contents)
	bay.present_graded(contents, ShopController.GRADE_RISE)
	await wait_frames(2)
	bay.present(contents)  # neue Auslage mitten im Auftritt
	await _await_appearance()
	_assert_same_poses(_poses(bay), _poses(reference), "Laufwechsel")

func test_der_umschlag_raeumt_die_auslage_und_bleibt_im_budget() -> void:
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	var wait := bay.sink_all()
	assert_eq(bay.items.size(), 0, "was sinkt, ist nicht mehr zu greifen")
	assert_gt(wait, 0.0, "der Umschlag braucht seine Zeit")
	assert_lte(wait, VitrineView.SWAP_TIME + 0.0001)
	# Die Zielseite kommt danach ganz normal.
	bay.present_graded(_stock([Pack.roll_engraving_pack()], [_die()], []),
		ShopController.GRADE_RISE)
	await wait_frames(2)
	assert_eq(bay.items.size(), 2, "und liegt vollständig da")

func test_ein_leeres_fach_kostet_keinen_umschlag() -> void:
	assert_eq(bay.sink_all(), 0.0, "eine leere Auslage sinkt nicht")

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

func test_ein_laufwechsel_raeumt_die_auslage_hart() -> void:
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	bay.clear()
	assert_eq(bay.items.size(), 0, "nichts liegt mehr darin")
	assert_true(bay.half.x > 0.0, "der RAUM bleibt gestellt")
