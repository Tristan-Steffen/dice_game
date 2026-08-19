extends GutTest
## Die VITRINE als Bucht mit Ware: geprüft wird der EINE Abgleich (je Platz ein
## Körper), die Innen-Aufteilung "versiegelt steht, offen liegt" und der Griff, der
## unter der Scheibe bleibt. Kein Kamerastrahl - die Bucht wird in WELT-Punkten
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

func test_in_der_bucht_liegt_alles_das_regal_hinten() -> void:
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	var shelf := bay.spot_of(ShopController.KIND_ENGRAVING_PACK, 0)
	var bowl := bay.spot_of(ShopController.KIND_DIE, 0)
	# HINTEN ist Welt-+X (der Bildschirm-oben der Anzeigefläche).
	assert_gt(shelf.x, bowl.x, "die Kassette liegt hinter der offenen Ware")
	var cell: DataCellView = bay.item_at(shelf)["cell"]
	assert_true(cell.lying(), "sie LIEGT - in der flachen Bucht steht nichts mehr")
	assert_almost_eq(shelf.y, bay.cell_y(), 0.0001, "und ruht auf dem Grubenboden")
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
	# Neben der Karte stünde die Marke in der Grubenwand - von oben gelesen gehört
	# sie auf die Fläche.
	var bundle := Pack.fixed_engraving_pack(Engraving.pointer_engraving(), 3)
	bay.present(_stock([bundle], [], []))
	await wait_frames(2)
	var cell: DataCellView = bay.item_at(
		bay.spot_of(ShopController.KIND_ENGRAVING_PACK, 0))["cell"]
	assert_true(cell.badge_on_face, "die Bucht stellt die Marke um")
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
		"an der Wand liegt nichts")

func test_die_auslage_bekommt_die_ganze_buchtflaeche() -> void:
	# Das Ausgabefach ist an die Werkbank gezogen - die Rinne rechts entfällt, und
	# die Auslage steht mittig in der ganzen Bucht.
	bay.present(_stock([], [_die(), _die(), _die()], []))
	await wait_frames(2)
	var left := bay.spot_of(ShopController.KIND_DIE, 0)
	var right := bay.spot_of(ShopController.KIND_DIE, 2)
	assert_almost_eq((left.z + right.z) * 0.5, CENTER.z, 0.0001,
		"die Reihe steht mittig in der Bucht, nicht in ihrer linken Hälfte")

# --- Die drei Ankunfts-Grade ---------------------------------------------------

## Alle Körper der Bucht mit ihrer Lage - der Vergleichsmaßstab jeder Ankunft.
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
	var roll := _probe(ShopController.GRADE_ROLL_IN, contents)
	# Übersprungene Tweens: der Endzustand steht trotzdem.
	rise.settle()
	roll.settle()
	await _await_appearance()
	var hard := _poses(bay)
	assert_gt(hard.keys().size(), 3, "die Probe trägt Regal und Schale")
	_assert_same_poses(_poses(rise), hard, "Aufsteigen")
	_assert_same_poses(_poses(roll), hard, "Anrollen")

func test_ein_zweiter_grad_mitten_in_der_fahrt_legt_hart_nach() -> void:
	var contents := _stock([Pack.roll_engraving_pack()], [_die()], [])
	var reference := VitrineView.new("HardProbe")
	add_child_autofree(reference)
	reference.setup(CENTER, HALF)
	reference.present(contents)
	bay.present_graded(contents, ShopController.GRADE_ROLL_IN)
	await wait_frames(2)
	bay.present(contents)  # neue Auslage mitten im Auftritt
	await _await_appearance()
	_assert_same_poses(_poses(bay), _poses(reference), "Laufwechsel")

func test_der_umschlag_raeumt_die_bucht_und_bleibt_im_budget() -> void:
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	var wait := bay.sink_all()
	assert_eq(bay.items.size(), 0, "was sinkt, ist nicht mehr zu greifen")
	assert_gt(wait, 0.0, "der Umschlag braucht seine Zeit")
	assert_lte(wait, VitrineView.SWAP_TIME + 0.0001)
	# Die Zielseite kommt danach ganz normal.
	bay.present_graded(_stock([Pack.roll_engraving_pack()], [_die()], []),
		ShopController.GRADE_ROLL_IN)
	await wait_frames(2)
	assert_eq(bay.items.size(), 2, "und liegt vollständig da")

func test_ein_leeres_fach_kostet_keinen_umschlag() -> void:
	assert_eq(bay.sink_all(), 0.0, "eine leere Bucht sinkt nicht")

# --- Der Vorhang deckt ALLES ab -------------------------------------------------

func test_bei_geschlossenem_vorhang_ist_kein_koerper_der_bucht_da() -> void:
	# Die Sichtbarkeit hängt am EINEN Vorhang - Grube, Ware und Klappe gehen
	# zusammen. Sonst flimmert die Grubenkontur durch die Hub-Startseite.
	assert_false(bay.visible, "eine frische Bucht steht zugedeckt da")
	bay.set_open(1.0)
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	assert_true(bay.visible)
	bay.set_open(0.0)
	assert_false(bay.visible, "zugedeckt heißt: gar nicht da")

## Jeder sichtbare Körper der Bucht, dessen Hülle die Glasebene erreicht.
func _above_glass(node: Node, out: PackedStringArray) -> PackedStringArray:
	var visual := node as VisualInstance3D
	if visual != null and visual.visible:
		var box := visual.get_aabb()
		for i in 8:
			var corner: Vector3 = visual.global_transform * (box.position + Vector3(
				box.size.x * float(i & 1), box.size.y * float((i >> 1) & 1),
				box.size.z * float((i >> 2) & 1)))
			if corner.y > CENTER.y - 0.001:
				out.append(String(node.name))
				break
	for child in node.get_children():
		_above_glass(child, out)
	return out

func test_nichts_in_der_bucht_ragt_ueber_die_glasebene() -> void:
	# Genau das leckte durch die Anzeige: Wandkanten endeten exakt auf dem Glas,
	# und die Silhouette der liegenden Würfel stand darüber.
	bay.set_open(1.0)
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	assert_eq(_above_glass(bay, PackedStringArray()), PackedStringArray(),
		"kein Körper der Bucht erreicht die Anzeigefläche")

func test_auch_das_gegriffene_stueck_bleibt_unter_der_scheibe() -> void:
	# Der Hub ist GEDECKELT: über der Bucht liegt sichtbares Glas, und ein Griff,
	# der hindurchstößt, ist kein Griff mehr.
	bay.set_open(1.0)
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	for kind: String in [ShopController.KIND_DIE, ShopController.KIND_ENGRAVING_PACK]:
		bay.set_hovered(kind, 0)
		await wait_seconds(VitrineView.HOVER_TIME + 0.05)
		assert_eq(_above_glass(bay, PackedStringArray()), PackedStringArray(),
			"%s bleibt gegriffen unter der Anzeigefläche" % kind)
	bay.set_hovered("", -1)

func test_der_gedeckelte_hub_bleibt_eine_bewegung() -> void:
	# Gedeckelt heißt nicht abgeschafft: das Stück muss sich sichtbar rühren.
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	var cell: DataCellView = bay.item_at(
		bay.spot_of(ShopController.KIND_ENGRAVING_PACK, 0))["cell"]
	assert_gt(cell.hover_lift, 0.0, "die Kassette hebt sich noch")
	assert_lt(cell.hover_lift, DataCellView.HOVER_LIFT,
		"aber nicht mehr so weit wie im Magazin - dort liegt keine Scheibe darüber")
	var fresh := DataCellView.new()
	assert_eq(fresh.hover_lift, DataCellView.HOVER_LIFT,
		"die Magazin-Geste bleibt unangetastet")
	fresh.free()

# --- Die Klappen der Anrollbahnen -----------------------------------------------

func test_die_klappen_sitzen_in_ihren_waenden_und_bleiben_unter_dem_kragen() -> void:
	var pit: PackPitView = bay.pit
	assert_gt(pit.hatch_width, 0.0, "der Laden hat Klappen")
	assert_gt(pit.hatch_height, 0.0)
	assert_gte(pit.hatch_count(), VitrineView.MIN_HATCHES, "und zwar mehrere")
	assert_lte(pit.hatch_sill + pit.hatch_height, -PackPitView.WALL_SINK + 0.0001,
		"ihre Oberkante bleibt unter dem Kragen")
	assert_almost_eq(pit.hatch_sill, bay.floor_y() - CENTER.y, 0.0001,
		"und ihre Schwelle IST der Grubenboden - kein Absatz vor der Liegefläche")
	for i in pit.hatch_count():
		var hinge: Vector3 = pit.hatch_hinge(i)
		var inward: Vector3 = pit.hatch_inward(i)
		# Angeschlagen ist jede an der INNENFLÄCHE ihrer Wand - eine Kante der Bucht.
		var on_wall := is_equal_approx(absf(hinge.z - CENTER.z), bay.half.y) \
			or is_equal_approx(absf(hinge.x - CENTER.x), bay.half.x)
		assert_true(on_wall, "Klappe %d hängt auf einer Buchtwand" % i)
		assert_almost_eq(inward.length(), 1.0, 0.0001)
		assert_almost_eq(inward.y, 0.0, 0.0001, "und wirft waagerecht herein")

func test_das_magazin_hat_keine_klappe() -> void:
	# Die Grube ist geteilt, die Klappe ist Buchten-Sache: sie wird bestellt.
	var magazin := PackPitView.new()
	add_child_autofree(magazin)
	magazin.setup(CENTER, HALF, 3.0)
	assert_eq(magazin.hatch_width, 0.0)
	assert_eq(magazin.hatch_count(), 0, "kein Blatt, keine Fuge")
	assert_not_null(magazin.get_node_or_null("WallZMinus"), "die Wand bleibt ganz")

func test_nur_die_genutzten_klappen_oeffnen() -> void:
	for i in bay.pit.hatch_count():
		assert_almost_eq(bay.pit.hatch_open_amount(i), 0.0, 0.0001, "zu ist der Ruhezustand")
	bay.present_graded(_stock([], [_die()], []), ShopController.GRADE_ROLL_IN)
	await wait_seconds(VitrineView.HATCH_OPEN + 0.05)
	var open := 0
	for i in bay.pit.hatch_count():
		if bay.pit.hatch_open_amount(i) > 0.9:
			open += 1
	assert_eq(open, 1, "EIN Würfel, EIN Tor - die anderen rühren sich nicht")
	bay.settle()  # Laufwechsel: hart zu, wie jede andere Bewegung auch
	for i in bay.pit.hatch_count():
		assert_almost_eq(bay.pit.hatch_open_amount(i), 0.0, 0.0001)

func test_der_wuerfel_startet_in_der_bucht_statt_hinter_der_wand() -> void:
	# Vorher begann seine Bahn halb in der Wand - jetzt steht er GANZ in der Bucht,
	# und genau darum ist der Käfig ein geschlossener Kasten.
	bay.present_graded(_stock([], [_die()], []), ShopController.GRADE_ROLL_IN)
	var body: Node3D = bay.items[0]["node"]
	var edge := DieBuilder.HALF_EXTENT * VitrineView.DIE_SCALE * 2.0
	assert_gte(VitrineView.ROLL_ENTRY, 0.5,
		"die Mündung liegt weiter innen als der halbe Würfel breit ist")
	assert_gte(body.global_position.x, bay.bounds_min().x - 0.0001)
	assert_between(body.global_position.z, bay.bounds_min().y - edge,
		bay.bounds_max().y + edge, "und beginnt an einem Tor seiner Bucht")

func test_eine_volle_schale_streut_sich_ueber_die_tore() -> void:
	# Ohne Zurücklegen gezogen: solange der Topf trägt, teilt sich kein Würfel sein
	# Tor - eine Auslage, die immer durch dieselbe Klappe kommt, wäre eine Rutsche.
	var dice: Array = [_die(), _die(), _die(), _die(), _die(), _die()]
	assert_gte(bay.pit.hatch_count(), dice.size(),
		"die Ladenbucht trägt für jeden Würfel ein Tor")
	bay.present_graded(_stock([], dice, []), ShopController.GRADE_ROLL_IN)
	await wait_seconds(VitrineView.HATCH_OPEN + 0.05)
	var open := 0
	for i in bay.pit.hatch_count():
		if bay.pit.hatch_open_amount(i) > 0.9:
			open += 1
	assert_eq(open, dice.size(), "sechs Würfel, sechs offene Tore")

func test_ein_steigender_auftritt_laesst_die_klappen_zu() -> void:
	bay.present_graded(_stock([Pack.roll_engraving_pack()], [], []),
		ShopController.GRADE_RISE)
	await wait_seconds(VitrineView.HATCH_OPEN + 0.05)
	for i in bay.pit.hatch_count():
		assert_almost_eq(bay.pit.hatch_open_amount(i), 0.0, 0.0001,
			"eine Kassette wird abgerufen, nicht geworfen - nichts rollt an")

# --- Das Anrollen ist echte Physik ----------------------------------------------

## Jeder Kollisionskörper, den die Bucht gerade selbst hält (Käfig und
## Stellvertreter). Freigegebene zählen nicht mehr mit.
func _roll_bodies(view: VitrineView) -> Array[Node]:
	var out: Array[Node] = []
	for child in view.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is RigidBody3D or child is StaticBody3D:
			out.append(child)
	return out

func test_der_wuerfel_rollt_wirklich_los_und_dreht_sich_dabei() -> void:
	bay.present_graded(_stock([], [_die()], []), ShopController.GRADE_ROLL_IN)
	var body: Node3D = bay.items[0]["node"]
	var start := body.global_position
	var pose := body.global_basis
	await wait_frames(10)
	assert_gt(body.global_position.distance_to(start), 0.5,
		"er läuft wirklich - das ist keine gezeichnete Bahn mehr")
	assert_false(body.global_basis.is_equal_approx(pose), "und er kollert dabei")

func test_der_rollende_wuerfel_sieht_nur_seinen_kaefig() -> void:
	bay.present_graded(_stock([], [_die()], []), ShopController.GRADE_ROLL_IN)
	await wait_frames(3)
	var proxies := 0
	var cages := 0
	for node in _roll_bodies(bay):
		var proxy := node as RigidBody3D
		if proxy == null:
			cages += 1
			continue
		proxies += 1
		assert_eq(proxy.collision_layer, VitrineView.ROLL_LAYER, "eigene Schicht")
		assert_eq(proxy.collision_mask, VitrineView.ROLL_LAYER,
			"und er sieht auch nur sie")
	assert_eq(proxies, 1, "ein Würfel, ein Stellvertreter")
	assert_eq(cages, 1, "und EIN Käfig für die ganze Bucht")
	# Der GEZEIGTE Würfel bleibt körperlos - Kollision trägt allein sein Vertreter.
	var ghost: Node3D = bay.items[0]["node"]
	var inner: RigidBody3D = ghost.get_node("RigidBody3D")
	assert_eq(inner.collision_layer, 0, "der Ghost trägt keine Schicht")
	assert_true(inner.freeze, "und keine Simulation")

func test_das_anrollen_endet_von_selbst_auf_den_verkaufsplaetzen() -> void:
	# Ohne settle, ohne Nachhelfen: die Physik läuft aus, die Würfel gleiten in ihre
	# Reihe, und der Endzustand ist derselbe, den ein hartes present schriebe.
	var contents := _stock([Pack.roll_engraving_pack()], [_die(), _die(), _die()], [])
	var reference := VitrineView.new("HardProbe")
	add_child_autofree(reference)
	reference.setup(CENTER, HALF)
	reference.present(contents)
	bay.present_graded(contents, ShopController.GRADE_ROLL_IN)
	await wait_seconds(VitrineView.ROLL_BUDGET + 0.3)
	_assert_same_poses(_poses(bay), _poses(reference), "ausgerollt")
	assert_eq(_roll_bodies(bay).size(), 0,
		"und kein Kollisionskörper bleibt zurück - in Ruhe ist die Bucht körperlos")

func test_ein_laufwechsel_mitten_im_wurf_raeumt_die_physik_ab() -> void:
	bay.present_graded(_stock([], [_die(), _die()], []), ShopController.GRADE_ROLL_IN)
	await wait_frames(4)
	assert_gt(_roll_bodies(bay).size(), 0, "während des Wurfs steht der Käfig")
	bay.settle()
	await wait_frames(2)
	assert_eq(_roll_bodies(bay).size(), 0, "der Laufwechsel nimmt ihn mit")
	assert_true((bay.items[0]["node"] as Node3D).global_position.is_equal_approx(
		bay.items[0]["spot"]), "und legt den Würfel hart auf seinen Platz")

func test_ein_laufwechsel_raeumt_die_bucht_hart() -> void:
	bay.present(_stock([Pack.roll_engraving_pack()], [_die()], []))
	await wait_frames(2)
	bay.clear()
	assert_eq(bay.items.size(), 0, "nichts liegt mehr darin")
	assert_not_null(bay.pit, "der RAUM bleibt stehen")
