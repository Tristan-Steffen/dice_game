extends GutTest
## Der Körper des Schwarzmarkts (SecretShopBody): Zustände je Fach, verkauft bleibt zu,
## der Neuwurf je Fach fährt ein und aus, settle_hard, EIN Schreiber, massive Fächer, hinter
## der Rückwand ist nichts zu sehen, drei Entwürfe.

var view: SecretShopView
var body: SecretShopBody
var run: GameRun

func after_all() -> void:
	GameRun.secret_projector_chance = GameRun.SECRET_PROJECTOR_CHANCE
	GameRun.secret_powerbank_chance = GameRun.SECRET_POWERBANK_CHANCE

func before_each() -> void:
	GameRun.secret_projector_chance = 0.0
	GameRun.secret_powerbank_chance = 0.0
	run = GameRun.new_run()
	run.storage_rows = 4
	run.energy = run.energy_cap()
	view = SecretShopView.new()
	add_child_autofree(view)
	view.size = SecretShopView.UNITS * 37.5
	view.run = run
	body = SecretShopBody.new()
	add_child_autofree(body)
	body.setup(_parts())

func _parts() -> Dictionary:
	var parts := {}
	var center := view.size * 0.5
	for key: String in SecretShopView.PARTS:
		var rect := view.part_rect(key)
		parts[key] = Rect2((rect.position - center) / 37.5, rect.size / 37.5)
	return parts

func _bays() -> Array:
	var bays: Array = []
	for i in SecretShopView.BAYS:
		var bay := view.bay_state(i)
		var item: Variant = bay.get("item")
		bay["key"] = "%s:%d" % [String(bay["kind"]), (item as Object).get_instance_id() if item is Object else 0]
		bay["reroll"] = view.reroll_state(i)
		bays.append(bay)
	return bays

func _seat(hard := false) -> void:
	body.seat(_bays(), hard)

func test_a_hard_seat_stands_every_offer_open_with_its_ware() -> void:
	_seat(true)
	for i in run.secret_stock.size():
		assert_eq(body.share(i), 1.0, "Fach %d steht ausgefahren" % i)
		assert_not_null(body.ware(i), "mit seiner Ware")
		assert_true(body.ware(i).visible)
	assert_eq(body.name_shown(0), (run.secret_stock[0][GameRun.OFFER_ITEM] as Charm).display_name.to_upper())
	assert_true(body.ware(0) is CharmProjectorView, "der Charm steckt im Projektor")
	assert_true(body.ware(0).get_node_or_null("Diskette") is CharmDiskView, "als Diskette")
	assert_true((body.ware(0) as CharmProjectorView).projecting(), "offen zeigt er sein Hologramm")

func test_the_writer_writes_only_on_change() -> void:
	_seat(true)
	var writes := body.writes()
	_seat()
	_seat()
	assert_eq(body.writes(), writes, "derselbe Stand schreibt nichts")

func test_a_sold_bay_retracts_with_its_ware_and_stays_closed() -> void:
	_seat(true)
	run.secret_stock[1] = run._secret_engraving_offer()
	_seat(true)
	var ware := body.ware(1)
	assert_true(ware is DataCellView, "die Karte liegt im Fach")
	view.buy_offer(1)
	_seat()
	assert_true(body.riding(), "das Fach fährt ein")
	assert_eq(body.ware(1), ware, "MIT der Ware")
	await wait_seconds(SecretShopBody.close_time() + 0.2)
	assert_eq(body.share(1), 0.0, "verkauft bleibt es zu")
	assert_null(body.ware(1), "die Ware ist fort - sie reist als Licht")
	assert_eq(body.name_shown(1), SecretShopView.SOLD_NAME)
	assert_eq(body.bar_color(1), SecretShopBody.RED, "die Leiste ist rot")

func test_carried_ware_leaves_the_bay_before_it_retracts() -> void:
	_seat(true)
	var disk := body.release_ware(0)
	assert_true(disk is CharmDiskView, "die Diskette wird frei")
	assert_eq(disk.get_parent(), body.get_parent(), "sie hängt am Eltern-Knoten")
	view.buy_offer(0)
	_seat()
	await wait_seconds(SecretShopBody.close_time() + 0.2)
	assert_eq(body.share(0), 0.0, "das leere Fach fährt ein")
	assert_true(is_instance_valid(disk), "der Körper fliegt - das Fach gibt ihn nicht frei")
	disk.queue_free()
	_forgive_hologram_frees()

func test_a_reroll_retracts_swaps_inside_and_extends_only_its_bay() -> void:
	_seat(true)
	var old := body.ware(2)
	var kept := body.ware(1)
	run.reroll_secret_offer(2)
	_seat()
	await wait_seconds(SecretShopBody.close_time() * 0.6)
	assert_lt(body.share(2), 1.0, "erst fährt das Fach mit der alten Ware ein")
	assert_eq(body.ware(2), old)
	assert_eq(body.share(1), 1.0, "die Nachbarn bleiben stehen")
	await wait_seconds(SecretShopBody.close_time() + SecretShopBody.OPEN_TIME + 0.3)
	assert_eq(body.share(2), 1.0, "dann mit der neuen aus")
	assert_ne(body.ware(2), old, "drinnen getauscht")
	assert_eq(body.ware(1), kept)

func test_a_rerolled_sold_bay_comes_back_out() -> void:
	run.secret_stock[1] = run._secret_engraving_offer()
	view.buy_offer(1)
	_seat(true)
	assert_eq(body.share(1), 0.0)
	run.reroll_secret_offer(1)
	_seat()
	await wait_seconds(SecretShopBody.OPEN_TIME + 0.3)
	assert_eq(body.share(1), 1.0, "frisch bestückt fährt es aus")
	assert_not_null(body.ware(1))

func test_settle_hard_owes_nothing() -> void:
	_seat(true)
	run.reroll_secret_offer(0)
	run.reroll_secret_offer(2)
	_seat()
	await wait_frames(3)
	body.settle_hard()
	assert_false(body.riding(), "keine Fahrt läuft mehr")
	for i in run.secret_stock.size():
		assert_eq(body.share(i), 1.0)
		assert_eq(body.ware_key(i), String(_bays()[i]["key"]), "die neue Ware steckt")
	_forgive_hologram_frees()

func test_a_projector_offer_fills_one_bay() -> void:
	GameRun.secret_projector_chance = 1.0
	run._roll_secret_stock()
	GameRun.secret_projector_chance = 0.0
	_seat(true)
	assert_true(body.ware(1) is CharmReaderView, "ein leerer Projektor")
	assert_eq(body.share(2), 1.0, "das dritte Fach trägt seine Ware")
	assert_not_null(body.ware(2))

## Das Fach ist EIN Stück: kein zweites Segment, Boden und Nase fahren gemeinsam.
func test_the_drawer_is_one_solid_piece() -> void:
	_seat(true)
	var slide := body.slide(0)
	assert_not_null(slide.get_node_or_null("Boden"))
	assert_not_null(slide.get_node_or_null("Nase"))
	assert_not_null(slide.get_node_or_null("Neuwurf"), "die Taste sitzt auf der Nase")
	assert_eq(body.get_node("Fach0").find_children("Aussen").size(), 0, "das Teleskop ist tot")
	assert_almost_eq(slide.position.x, 0.0, 0.001, "offen steht er vorn")
	run.secret_stock[0][GameRun.OFFER_SOLD] = true
	_seat(true)
	assert_almost_eq(slide.position.x, (SecretShopView.PARTS["bay0"] as Rect2).size.y, 0.001,
		"eingefahren um eine Fachtiefe zurück")
	_forgive_hologram_frees()

## Eingefahren reicht das Fach hinten über das Gehäuse: jedes Teil dort schneidet die Haut
## an der Rückwand ab, sichtbar endet alles vor ihr, und die Nase bleibt vorn.
func test_nothing_is_visible_behind_the_back_wall() -> void:
	for i in SecretShopView.BAYS:
		run.secret_stock[i][GameRun.OFFER_SOLD] = true
	_seat(true)
	var plane := body.clip_plane()
	assert_almost_eq(plane.d, body.housing_back(), 0.001, "die Ebene IST die Rückwand")
	var nose_depth := (SecretShopView.PARTS["nose0"] as Rect2).size.y
	for i in SecretShopView.BAYS:
		var reaches := 0
		for child in body.slide(i).find_children("*", "GeometryInstance3D", true, false):
			var mesh := child as GeometryInstance3D
			var local := body.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			if local.end.x > body.housing_back() + 0.001:
				reaches += 1
				assert_true(body.clips(mesh), "%s schneidet sich ab" % mesh.name)
				var material := mesh.material_override as ShaderMaterial
				var value: Vector4 = material.get_shader_parameter("clip_plane")
				assert_almost_eq(value.w, plane.d, 0.001, "an der Rückwand")
		assert_gt(reaches, 0, "das massive Fach reicht wirklich hinaus")
		var foot := body.drawer_footprint(i)
		assert_lte(foot.end.x, body.housing_back() + 0.001, "sichtbar endet Fach %d an der Rückwand" % i)
		assert_gte(foot.position.x, body.housing_front() - nose_depth - 0.001,
			"nur die Nase steht vor der Front")
	_forgive_hologram_frees()

## Die Ware fährt mit dem Fach und ist fort, bevor sie die Rückwand erreicht.
func test_a_ware_is_never_shown_behind_the_back_wall() -> void:
	for kind: String in [GameRun.KIND_CHARM, GameRun.KIND_DIE, GameRun.KIND_PART,
			GameRun.KIND_ENGRAVING, GameRun.KIND_POWERBANK, GameRun.KIND_PROJECTOR]:
		for step in 51:
			var share := float(step) / 50.0
			if body.ware_shown(kind, share):
				assert_lte(body.ware_center(kind, share) + SecretShopBody.ware_reach(kind),
					body.housing_back() + 0.001, "%s sichtbar bei %.2f, aber hinter der Wand" % [kind, share])
		assert_true(body.ware_shown(kind, 1.0), "%s zeigt sich ganz draußen" % kind)
		assert_false(body.ware_shown(kind, 0.0), "%s ist eingefahren verborgen" % kind)
	assert_gt(body.ware_shown_share(GameRun.KIND_PROJECTOR), 0.99, "der Projektor zeigt sich nur ganz draußen")

func test_each_key_reads_its_price_and_dims_without_energy() -> void:
	_seat(true)
	for i in SecretShopView.BAYS:
		assert_eq(body.reroll_price_shown(i), str(run.secret_reroll_cost()))
		assert_true(body.reroll_lit(i))
	run.energy = 0
	_seat()
	for i in SecretShopView.BAYS:
		assert_false(body.reroll_lit(i), "ohne Energie gedimmt")

## Die Haut leuchtet selbst, aber unter der Bloom-Schwelle.
func test_the_look_stays_under_the_bloom_threshold() -> void:
	for color_key: String in ["body", "top", "trim", "floor", "dot", "bevel"]:
		var color: Color = SecretShopBody.LOOK[color_key]
		assert_lt(maxf(color.r, maxf(color.g, color.b)), 0.95, "%s unter der Bloom-Schwelle" % color_key)

## Der Kopflos-Renderer meldet beim Freigeben eines Hologramm-Modells ein fehlendes
## Material (nur dort; das Spiel bleibt still) - nur diese Meldung gilt als erwartet.
func _forgive_hologram_frees() -> void:
	for error in get_errors():
		if error.is_engine_error() and "material_get_instance_shader_parameters" in str(error.code) \
				+ str(error.function) + str(error.rationale):
			error.handled = true
