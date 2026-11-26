extends GutTest
## Der Körper des LABORS (LaborBody): Teile im Grundriß, Felder je Zustand, die Haube nur im
## Lauf, der harte Weg schuldet nichts, EIN Schreiber, der Einsatz in echter Größe.

var view: LaborView
var body: LaborBody

func before_each() -> void:
	view = LaborView.new()
	add_child_autofree(view)
	view.size = LaborView.UNITS * 37.5
	body = LaborBody.new()
	add_child_autofree(body)
	body.setup(_parts())

func _parts() -> Dictionary:
	var parts := {}
	var center := view.size * 0.5
	for key: String in LaborView.PARTS:
		var rect := view.part_rect(key)
		parts[key] = Rect2((rect.position - center) / 37.5, rect.size / 37.5)
	return parts

func _seat(phase: String, die_value := 0, rounds_left := 0, hard := true, extra := {}) -> void:
	var state := {"open": true, "station": "seele", "phase": phase, "die_value": die_value,
		"rounds_left": rounds_left, "price": 1, "affordable": true}
	state.merge(extra, true)
	view.set_state(state)
	body.seat(view.body_state(), hard)

## Jedes sichtbare Teil liegt im Grundriß 28 × 10,6 (lokal x = Bild-oben, z = Bild-rechts).
func test_every_part_lies_inside_the_footprint() -> void:
	_seat("laeuft", 2, 3)
	var half := LaborView.UNITS * 0.5
	var box := _footprint()
	assert_gte(box.position.z, -half.x - 0.001, "links im Grundriß")
	assert_lte(box.end.z, half.x + 0.001, "rechts im Grundriß")
	assert_gte(box.position.x, -half.y - 0.001, "unten im Grundriß")
	assert_lte(box.end.x, half.y + 0.001, "oben im Grundriß")
	assert_gt(box.size.z, half.x * 1.85, "es füllt ihn auch")
	print("LABOR footprint ", box)

func _footprint() -> AABB:
	var box := AABB()
	var first := true
	for child in body.find_children("*", "GeometryInstance3D", true, false):
		var mesh := child as GeometryInstance3D
		if not mesh.is_visible_in_tree():
			continue
		var local := body.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box

func test_fields_per_state() -> void:
	_seat("laeuft", 2, 3)
	var want := ["wurf", "wurf", "runde", "aus", "aus", "aus"]
	for i in LaborView.FIELDS:
		assert_eq(body.field_state(i), want[i], "Feld %d" % i)
	assert_eq(body.field_color(0), LaborBody.GOLD_LIT, "Gold = Wurf")
	assert_eq(body.field_color(2), LaborBody.VIOLET, "Violett = Runde")
	assert_eq(body.field_color(5), LaborBody.FIELD_DIM)
	var dim := body.field_color(5)
	assert_gt(maxf(dim.r, maxf(dim.g, dim.b)), 0.15, "ein Feld ohne Licht liest noch als Feld")
	_seat("fertig", 6)
	for i in LaborView.FIELDS:
		assert_eq(body.field_color(i), LaborBody.GOLD_LIT, "eine 6: alles gold")
	assert_eq(body.status_shown(), "FERTIG")
	assert_eq(body.status_color(), LaborBody.GREEN)

func test_the_hood_only_stands_while_a_job_runs() -> void:
	_seat("bereit")
	assert_false(body.hood_shown(), "bereit: keine Haube")
	_seat("laeuft", 3, 3)
	assert_true(body.hood_shown())
	assert_eq(body.hood_share(), 1.0, "hart gesenkt")
	_seat("fertig", 3, 0, false)
	assert_true(body.riding(), "die Haube hebt sich")
	await wait_seconds(LaborBody.HOOD_TIME + 0.2)
	assert_false(body.hood_shown(), "und ist fort")
	_seat("laeuft", 1, 5, false)
	await wait_seconds(LaborBody.HOOD_TIME * 0.4)
	assert_true(body.hood_shown(), "sie senkt sich")
	assert_lt(body.hood_share(), 1.0)

func test_settle_hard_owes_nothing() -> void:
	_seat("bereit")
	_seat("laeuft", 4, 2, false)
	assert_true(body.riding())
	body.settle_hard()
	assert_false(body.riding(), "keine Fahrt läuft mehr")
	assert_eq(body.hood_share(), 1.0)
	for i in 4:
		assert_eq(body.field_color(i), LaborBody.GOLD_LIT, "die Felder stehen auf ihrem Ziel")

func test_the_writer_writes_only_on_change() -> void:
	_seat("laeuft", 2, 3)
	var writes := body.writes()
	_seat("laeuft", 2, 3, false)
	_seat("laeuft", 2, 3, false)
	assert_eq(body.writes(), writes, "derselbe Stand schreibt nichts")
	_seat("laeuft", 2, 2, false)
	assert_eq(body.writes(), writes + 1)

func test_labels_follow_the_state() -> void:
	_seat("bereit", 0, 0, true, {"station": "modul", "price": 3})
	assert_eq(body.name_shown(), "MODUL-KOPIERER")
	assert_eq(body.start_shown(), "START")
	assert_eq(body.price_shown(), "3")
	assert_true(body.start_lit())
	_seat("bereit", 0, 0, true, {"station": "modul", "price": 3, "affordable": false})
	assert_false(body.start_lit(), "ohne Energie gedimmt")
	_seat("laeuft", 2, 3, true, {"station": "modul"})
	assert_eq(body.start_shown(), "LÄUFT")
	assert_eq(body.price_shown(), "", "im Lauf kein Preis")
	assert_eq(body.status_shown(), "NOCH 3")

func test_soul_dice_lie_apart_in_the_chamber() -> void:
	_seat("laeuft", 2, 3)
	var run := GameRun.new_run()
	body.set_items([{"kind": GameRun.KIND_DIE, "item": run.owned_pool[0]},
		{"kind": GameRun.KIND_DIE, "item": run.owned_pool[1]}])
	assert_eq(body.items().size(), 2)
	for i in 2:
		var at := body.items()[i].global_position
		var seat := body.seat_point(i)
		assert_almost_eq(Vector2(at.x, at.z), Vector2(seat.x, seat.z), Vector2.ONE * 0.001, "Würfel %d auf seinem Platz" % i)
		assert_gt(at.y, seat.y, "er steht auf dem Boden")
	assert_lt(body.items()[0].position.z, body.items()[1].position.z, "Quelle links, Ziel rechts")
	assert_gt(body.lid_point().y, body.seat_point(0).y + LaborBody.HOOD_HEIGHT, "der Wurf liegt auf der Haube")

func test_six_cards_lie_as_a_stair_under_the_hood() -> void:
	_seat("laeuft", 2, 3, true, {"station": "karten"})
	var run := GameRun.new_run()
	var items: Array = []
	for k in 6:
		items.append({"kind": GameRun.KIND_ENGRAVING, "item": run._secret_engraving_offer()[GameRun.OFFER_ITEM]})
	body.set_items(items)
	assert_eq(body.items().size(), 6)
	var radius := LaborView.CHAMBER_RADIUS
	for i in 6:
		var cell := body.items()[i] as DataCellView
		assert_not_null(cell, "eine echte Karte")
		var p := cell.position
		if i > 0:
			assert_gt(p.y, body.items()[i - 1].position.y, "jede liegt höher")
			assert_gt(p.z, body.items()[i - 1].position.z, "und weiter Bild-rechts")
		var half := Vector2(DataCellView.HEIGHT, DataCellView.WIDTH) * PackDrawerView.CASSETTE_SCALE * 0.5
		assert_lte(Vector2(absf(p.z) + half.x, absf(p.x) + half.y).length(), radius + 0.05,
			"Karte %d bleibt in der Kammer" % i)
		assert_lt(p.y, LaborBody.HOOD_HEIGHT, "unter der Haube")

func test_charm_and_module_lie_in_the_middle() -> void:
	var run := GameRun.new_run()
	_seat("bereit", 0, 0, true, {"station": "charm"})
	body.set_items([{"kind": GameRun.KIND_CHARM, "item": run._secret_charm_offer()[GameRun.OFFER_ITEM]}])
	assert_true(body.items()[0] is CharmDiskView, "die nackte Diskette")
	assert_almost_eq(body.items()[0].position.z, 0.0, 0.001)
	_seat("bereit", 0, 0, true, {"station": "modul"})
	body.set_items([{"kind": GameRun.KIND_PART, "item": run._secret_part_offer()[GameRun.OFFER_ITEM]}])
	assert_true(body.items()[0] is ComboPartBody, "das Modul als Pin")
	assert_almost_eq(body.items()[0].position.y, LaborBody.MODULE_PAD.y + VitrineView.FLOOR_CLEAR, 0.001,
		"es steht auf seinem Sockel")

## Die Haube verjüngt sich nach oben, ihr Rand ist dünn, und sie steht über dem höchsten Einsatz.
func test_the_hood_tapers_and_clears_the_tallest_stake() -> void:
	_seat("laeuft", 2, 3)
	var run := GameRun.new_run()
	body.set_items([{"kind": GameRun.KIND_DIE, "item": run.owned_pool[0]},
		{"kind": GameRun.KIND_DIE, "item": run.owned_pool[1]}])
	var glass := body.get_node("Haube/Glas") as MeshInstance3D
	var mesh := glass.mesh as CylinderMesh
	assert_lt(mesh.top_radius, mesh.bottom_radius - 0.5, "oben schmaler")
	assert_lte(LaborBody.RIM_HEIGHT, 0.03, "ein dünner Rand")
	var die_top := body.items()[0].global_position.y + DieBuilder.HALF_EXTENT * DiceTrayView.DIE_SCALE
	assert_gt(LaborBody.COLLAR_TOP + LaborBody.HOOD_HEIGHT, die_top, "über dem Würfel")
	assert_almost_eq(body.lid_point().y, LaborBody.COLLAR_TOP + LaborBody.HOOD_HEIGHT + LaborBody.RIM_HEIGHT,
		0.001, "der Glückswürfel liegt auf dem Deckel")

## Der Flug in die Kammer endet auf dem Platz, und der harte Weg legt ihn sofort dorthin.
func test_a_stake_flies_in_and_the_hard_path_owes_nothing() -> void:
	_seat("laeuft", 2, 3)
	var run := GameRun.new_run()
	body.set_items([{"kind": GameRun.KIND_DIE, "item": run.owned_pool[0]},
		{"kind": GameRun.KIND_DIE, "item": run.owned_pool[1]}])
	var seat := body.items()[0].global_position
	body.fly_in(0, seat + Vector3(20.0, 0.0, -5.0))
	assert_true(body.flying())
	await wait_seconds(LaborBody.FLY_TIME * 0.4)
	assert_gt(body.items()[0].global_position.distance_to(seat), 0.5, "unterwegs")
	body.settle_hard()
	assert_false(body.flying())
	assert_almost_eq(body.items()[0].global_position, seat, Vector3.ONE * 0.001, "hart auf dem Platz")
	body.fly_in(1, body.items()[1].global_position + Vector3(5.0, 0.0, 5.0))
	await wait_seconds(LaborBody.FLY_TIME + 0.2)
	assert_almost_eq(body.items()[1].global_position, body.seat_point(1) + Vector3.UP * (seat.y - body.seat_point(0).y),
		Vector3.ONE * 0.001, "gelandet")

func test_appear_grows_and_the_hard_path_ends_it() -> void:
	_seat("bereit")
	body.appear()
	assert_true(body.appearing())
	assert_lt(body.scale.y, 0.5, "es wächst aus dem Tisch")
	body.settle_hard()
	assert_false(body.appearing())
	assert_almost_eq(body.scale, Vector3.ONE, Vector3.ONE * 0.001)

func test_hover_lifts_the_key() -> void:
	body.set_hovered("start")
	assert_eq(body.hovered(), "start")
	assert_almost_eq((body.get_node("StartKappe") as Node3D).position.y, LaborBody.KEY_LIFT, 0.001)
	body.set_hovered("")
	assert_almost_eq((body.get_node("StartKappe") as Node3D).position.y, 0.0, 0.001)

## Hell, aber unter der Bloom-Schwelle.
func test_the_light_stays_under_the_bloom_threshold() -> void:
	for color: Color in [LaborBody.VIOLET, LaborBody.GOLD_LIT, LaborBody.FLOOR_LIT, LaborBody.DOT, LaborBody.GREEN]:
		assert_lt(maxf(color.r, maxf(color.g, color.b)), 0.95)
	assert_gt(LaborBody.FLOOR_READY.v, 0.6, "der Leuchtboden ist hell")
