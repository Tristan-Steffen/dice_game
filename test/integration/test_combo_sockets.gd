extends GutTest
## Die STECKPLÄTZE am Tisch (Welle B): Modul-Platz im Laden, die Belegung auf
## dem Chip-Deckel, der Weg aus pending_parts in einen Platz, Tausch und
## Umstecken nur im Bearbeitungs-Fenster und die Ware des Schwarzmarkts.

const ShopPanelScene := preload("res://scenes/shop_panel.tscn")

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 200

func _key(i := 0) -> String:
	return DiceScoring.HAND_PRIORITY[i]

func _chip(key: String) -> ComboChipView:
	var chip := ComboChipView.new()
	chip.combo_key = key
	add_child_autofree(chip)
	chip.setup(4.0, 1.5)
	chip.set_extended(true, 0.0)
	return chip

func _sync(chip: ComboChipView) -> void:
	var dimmed: Array = []
	for part in run.parts_of(chip.combo_key):
		dimmed.append(run.is_part_disabled(part))
	chip.set_sockets(run.parts_of(chip.combo_key), dimmed)

func _fill_every_socket() -> void:
	for key: String in DiceScoring.HAND_PRIORITY:
		for slot in run.socket_count(key):
			run.stash_part(ComboPart.resistor())
			run.install_pending_part(key, slot)

# --- Der Laden ------------------------------------------------------------------

func _shop() -> ShopController:
	var shop: ShopController = ShopPanelScene.instantiate()
	add_child_autofree(shop)
	shop.run = run
	shop.open()
	return shop

## Ein Modul-Paket liegt auf der Paket-Fläche wie jede andere Art.
func test_the_shop_can_lay_out_a_module_pack() -> void:
	var shop := _shop()
	var seen := false
	for i in 40:
		for pack in shop._build_spread().packs:
			if pack is ModulePack:
				seen = true
	assert_true(seen, "die Fläche würfelt auch Modul-Pakete")

func test_the_module_has_one_size_everywhere() -> void:
	assert_eq(VitrineView.part_side(), ComboPartBody.SIDE, "Bucht = Modul")
	var chip := _chip(_key())
	assert_eq(chip.socket_side(), ComboPartBody.SIDE, "Steckplatz = Modul")
	assert_eq(ComboPartBody.SIDE, ComboPartBody.PLATE.z, "die kurze Plattenkante")
	assert_eq(ComboPartBody.SOCKET_OUTER, Vector2(ComboPartBody.PLATE.x, ComboPartBody.PLATE.z)
		+ Vector2.ONE * 2.0 * ComboPartBody.SOCKET_RIM, "der Sockel ist die Platte plus ein dünner Rand")

# --- Der Chip-Deckel --------------------------------------------------------------

func test_the_lid_shows_the_socket_layout() -> void:
	var key := _key()
	var chip := _chip(key)
	_sync(chip)
	assert_eq(chip.socket_count(), GameRun.SOCKETS_PER_COMBO, "drei leere Mulden")
	for slot in chip.socket_count():
		assert_null(chip.socket_part(slot))
	run.stash_part(ComboPart.capacitor())
	run.install_pending_part(key, 1)
	_sync(chip)
	assert_eq(chip.socket_part(1), run.parts_of(key)[1], "der Deckel zeigt die Instanz")
	assert_null(chip.socket_part(0))

func test_the_three_sockets_lie_on_the_lid() -> void:
	var chip := _chip(_key())
	_sync(chip)
	for slot in chip.socket_count():
		assert_almost_eq(chip.socket_world(slot).y, chip.global_position.y
			+ ComboChipView.BODY_TOP * chip._sz, 0.001, "der Sockel liegt auf dem Deckel")
	assert_lt(chip.socket_world(0).x, chip.socket_world(1).x, "eine Reihe längs des Chips")

func test_heat_buildup_dims_the_part() -> void:
	var key := _key()
	var chip := _chip(key)
	run.stash_part(ComboPart.resistor())
	run.install_pending_part(key, 0)
	run.heat_disabled_parts[run.parts_of(key)[0].get_instance_id()] = true
	_sync(chip)
	assert_true(chip.socket_dimmed(0), "stillgelegt liest stumpf")
	assert_false(chip.socket_dimmed(1))

func test_a_plugged_module_sits_in_its_socket() -> void:
	var key := _key()
	var chip := _chip(key)
	run.stash_part(ComboPart.capacitor())
	run.install_pending_part(key, 2)
	_sync(chip)
	var body := chip._sockets[2]["body"] as ComboPartBody
	var mouth := chip.socket_world(2).y
	assert_almost_eq(body.global_position.y, mouth + ComboPartBody.SOCKET_SEAT, 0.001,
		"die Platte liegt über Kontaktfeld und Leitung")
	chip.play_plug(2)
	assert_gt(body.global_position.y, mouth, "der Einbau fährt von oben hinein")
	await wait_seconds(ComboChipView.PLUG_TIME + 0.1)
	assert_almost_eq(body.global_position.y, mouth + ComboPartBody.SOCKET_SEAT, 0.001, "und steckt")

func test_the_pick_bodies_name_their_socket() -> void:
	var key := _key(2)
	var chip := _chip(key)
	_sync(chip)
	var picks: Array = []
	for body in chip.find_children("*", "StaticBody3D", true, false):
		assert_eq(body.collision_layer, ComboChipView.SOCKET_PICK_LAYER)
		picks.append(ComboChipView.pick_of(body))
	assert_eq(picks.size(), 2 * GameRun.SOCKETS_PER_COMBO + 1, "je Platz Sockel und Pin, dazu der Chip")
	for pick: Dictionary in picks:
		assert_eq(pick["key"], key)
	assert_true(picks.any(func(p: Dictionary) -> bool: return p["slot"] == -1), "der Chip selbst")

func test_beckon_marks_free_and_swappable_sockets() -> void:
	var key := _key()
	var chip := _chip(key)
	run.stash_part(ComboPart.resistor())
	run.install_pending_part(key, 0)
	_sync(chip)
	chip.set_socket_beckon(true, false)
	assert_false(chip.socket_beckons(0), "belegt ruft nur im Bearbeitungs-Fenster")
	assert_true(chip.socket_beckons(1))
	chip.set_socket_beckon(true, true)
	assert_true(chip.socket_beckons(0))

# --- Der EINBAU ------------------------------------------------------------------

func test_a_tap_on_the_chip_takes_its_first_free_socket() -> void:
	var key := _key()
	run.stash_part(ComboPart.resistor())
	run.install_pending_part(key, 0)
	run.stash_part(ComboPart.coil())
	var target := run.install_target(key, -1, false)
	assert_eq(target, 1, "der Chip gibt seinen ersten freien Platz")
	assert_true(run.install_pending_part(key, target))
	assert_true(run.pending_parts.is_empty())
	assert_eq(run.parts_of(key)[1].id, ComboPart.COIL)

func test_an_occupied_socket_swaps_only_in_the_edit_window() -> void:
	var key := _key()
	run.stash_part(ComboPart.resistor())
	run.install_pending_part(key, 0)
	run.stash_part(ComboPart.capacitor())
	assert_eq(run.install_target(key, 0, false), -1, "mitten in der Runde kein Tausch")
	assert_eq(run.install_target(key, 1, false), 1, "ein freier Platz geht immer")
	assert_eq(run.install_target(key, 0, true), 0, "im Laden tauscht der Tipp")
	run.install_pending_part(key, 0)
	assert_eq(run.parts_of(key)[0].id, ComboPart.CAPACITOR)
	assert_eq(run.pending_parts[0].id, ComboPart.RESISTOR, "das alte wird der nächste Einbau")

func test_a_full_table_waits_outside_the_edit_window() -> void:
	_fill_every_socket()
	run.pending_parts.append(ComboPart.capacitor())
	assert_false(run.can_install_pending(false), "ohne Platz hält der Einbau niemanden fest")
	assert_true(run.can_install_pending(true), "im Laden geht es per Tausch")

# --- UMSTECKEN -------------------------------------------------------------------

func test_moving_a_part_reaches_the_lids_of_both_chips() -> void:
	var a := _chip(_key(0))
	var b := _chip(_key(1))
	run.stash_part(ComboPart.relay())
	run.install_pending_part(a.combo_key, 0)
	_sync(a)
	_sync(b)
	a.set_socket_lifted(0)
	assert_eq(a.socket_lifted(), 0, "in der Hand zeigt der Platz leer")
	assert_false(run.move_part(a.combo_key, 0, b.combo_key, 2, false), "außerhalb des Fensters nichts")
	assert_true(run.move_part(a.combo_key, 0, b.combo_key, 2, true))
	a.set_socket_lifted(-1)
	_sync(a)
	_sync(b)
	assert_null(a.socket_part(0))
	assert_eq(b.socket_part(2).id, ComboPart.RELAY)

# --- Der SCHWARZMARKT ------------------------------------------------------------

func test_a_secret_part_offer_lies_as_a_body_and_sells() -> void:
	run.luck = (GameRun.TIER_MAX - 1) * GameRun.LUCK_PER_TIER
	run.stress_tests_passed = 4  # volle Börse (25)
	run.energy = run.energy_cap()
	var view := SecretShopView.new()
	add_child_autofree(view)
	view.size = Vector2(786, 437)
	view.run = run
	run.secret_stock[1] = run._secret_part_offer()
	view.refresh()
	await wait_frames(2)
	var stock := view.vitrine_stock()
	var part: ComboPart = stock[ShopController.KIND_PART][1]
	assert_not_null(part, "das Modul liegt in der Bucht")
	assert_eq(String(stock[VitrineView.STOCK_ROW_KINDS][1]), ShopController.KIND_PART)
	var bay := VitrineView.new("PartBay")
	bay.single_row = true
	add_child_autofree(bay)
	bay.setup(Vector3(-30.0, 0.0, 0.0), Vector2(4.0, 12.0))
	bay.present(stock)
	await wait_frames(2)
	# Die übrigen Plätze dürfen zufällig auch ein Modul ziehen - gemeint ist Platz 1.
	var found := bay.items.filter(func(item: Dictionary) -> bool:
		return item["kind"] == ShopController.KIND_PART and int(item["index"]) == 1)
	assert_eq(found.size(), 1, "ein Körper für das Modul")
	assert_true(found[0]["node"] is ComboPartBody)
	assert_eq(view.vitrine_annotation(ShopController.KIND_PART, 1)["title"], part.display_name)
	var bought: Array = []
	view.part_purchased.connect(func(p: ComboPart) -> void: bought.append(p))
	view.buy_offer(1)
	assert_eq(run.pending_parts.size(), 1, "gekauft wartet es auf den Einbau")
	assert_eq(bought.size(), 1, "und meldet sein Licht")
	assert_eq(run.pending_parts[0].id, part.id)

# --- Die Wertung ---------------------------------------------------------------

func test_a_scoring_part_flashes_its_socket_and_fades() -> void:
	var key := _key()
	run.stash_part(ComboPart.amplifier_tube())
	run.install_pending_part(key, 1)
	var chip := _chip(key)
	_sync(chip)
	var body := chip._sockets[1]["body"] as ComboPartBody
	chip.flash_socket(1, 2.0)
	await wait_frames(2)
	assert_gt(body.flash_level(), 0.5, "der Körper leuchtet auf")
	assert_gt(chip.socket_flash(1), 0.5, "und sein Rand mit")
	assert_gt(body.scale.x, 1.0, "der Krit-Schlag poppt")
	await wait_seconds(ComboPartBody.FLASH_TIME * 2.0 + 0.2)
	assert_almost_eq(body.flash_level(), 0.0, 0.001, "und klingt ab")
	assert_almost_eq(body.scale.x, 1.0, 0.001)

func test_flashing_an_empty_or_foreign_socket_is_harmless() -> void:
	var chip := _chip(_key())
	_sync(chip)
	chip.flash_socket(0)
	chip.flash_socket(99)
	chip.flash_socket(-1)
	await wait_frames(2)
	assert_gt(chip.socket_flash(0), 0.0, "ein leerer Platz blitzt nur am Rand")
	assert_eq(chip.socket_flash(99), 0.0)

func test_the_spotlight_pulse_has_a_truthful_name() -> void:
	var screen: TableScreen = autofree(TableScreen.new())
	assert_true(screen.has_method("play_combo_pulse"))
	assert_false(screen.has_method("play_overclock_pulse"), "das Übertakten ist tot")
	var chip: ComboChipView = autofree(ComboChipView.new())
	assert_true(chip.has_method("play_arrival_flash"))
	assert_false(chip.has_method("play_upgrade_flash"))

# --- Der Chip in Tischgröße -----------------------------------------------------------

## Ein Chip in seiner echten Tischgröße und Lage (37,5 Display-px je Welt, Modell-X = Welt+Z).
func _real_chip(key: String) -> ComboChipView:
	var chip := ComboChipView.new()
	chip.combo_key = key
	add_child_autofree(chip)
	chip.rotation.y = -PI / 2.0
	var size := TableScreen.CELL_SIZE / 37.5
	chip.setup(size.x, size.y)
	return chip

# --- Der Chip: Anzeige, Sockelzone, Pins, Leitungen ------------------------------------

func _picks_enabled(chip: ComboChipView) -> int:
	var on := 0
	for slot in chip.socket_count():
		if not (chip._sockets[slot]["pick"] as CollisionShape3D).disabled:
			on += 1
	return on

func test_the_display_lies_left_and_the_sockets_right() -> void:
	var chip := _real_chip(_key())
	_sync(chip)
	var half := ComboChipView.BODY_LENGTH * chip._sx * 0.5
	assert_gt(chip.display_right(), -half + 4.5, "die Anzeige hat Platz für Name und Wertung")
	for slot in chip.socket_count():
		var at := chip.to_local(chip.socket_world(slot))
		assert_gt(at.x - ComboPartBody.SOCKET_OUTER.y * 0.5, chip.display_right(), "Sockel %d rechts" % slot)
		assert_lt(at.x + ComboPartBody.SOCKET_OUTER.y * 0.5, half, "und im Gehäuse")
	assert_almost_eq(chip.socket_x(1) - chip.socket_x(0), ComboChipView.SOCKET_PITCH, 0.0001)
	assert_almost_eq(chip._sx, chip._sz, 0.001, "der Chip ist nicht verzerrt")

func test_the_base_value_shows_dimmed_only_when_it_differs() -> void:
	var chip := _real_chip(_key())
	var cell := ComboCellView.new()
	add_child_autofree(cell)
	cell.combo_name = "Paar"
	cell.set_score(10, 2, Vector2i(10, 2))
	chip.sync_cell(cell)
	assert_false(chip.shows_base())
	assert_eq(chip._base_label.text, "")
	cell.set_score(25, 2, Vector2i(10, 2))
	chip.sync_cell(cell)
	assert_true(chip.shows_base())
	assert_eq(chip._base_label.text, "10 ×2")
	assert_lt(chip._base_label.pixel_size, chip._points_label.pixel_size, "klein")
	assert_lt(chip._base_label.modulate.a, 1.0, "und gedimmt")
	assert_gt(chip._base_label.position.x, chip._mult_label.position.x, "neben der Wertung")
	assert_lt(chip._base_label.position.x, chip.display_right(), "in der Anzeige")

func test_a_resting_module_glows_dimmed_and_flashes_full() -> void:
	var key := _key()
	run.stash_part(ComboPart.capacitor())
	run.install_pending_part(key, 0)
	var chip := _real_chip(key)
	_sync(chip)
	var body := chip._sockets[0]["body"] as ComboPartBody
	assert_true(body.resting())
	assert_almost_eq(body.light_energy(), ComboPartBody.WINDOW_ENERGY * ComboPartBody.REST_SHARE, 0.001)
	chip.flash_socket(0)
	await wait_frames(1)
	assert_gt(body.light_energy(), ComboPartBody.WINDOW_ENERGY, "feuernd voll")
	assert_gt(chip.pin_body(0).flash_level(), 0.5, "und sein Pin blitzt mit")

func test_the_gold_rule_spares_sockets_and_modules() -> void:
	var key := _key()
	run.stash_part(ComboPart.capacitor())
	run.install_pending_part(key, 0)
	var chip := _real_chip(key)
	_sync(chip)
	var body := chip._sockets[0]["body"] as ComboPartBody
	var rim := chip._sockets[1]["rim"] as StandardMaterial3D
	var rim_before := rim.emission
	var light_before := body.light_energy()
	var line_before := chip.line_energy(0)
	var tile_before := chip.tile_color(0)
	var pin_before := chip.pin_body(0).light_energy()
	chip.set_glow(1.0)
	assert_eq(rim.emission, rim_before, "Sockel bleiben")
	assert_eq(body.light_energy(), light_before, "Module bleiben")
	assert_eq(chip.line_energy(0), line_before, "Leitungen bleiben")
	assert_eq(chip.tile_color(0), tile_before, "Kacheln bleiben")
	assert_eq(chip.pin_body(0).light_energy(), pin_before, "Modul-Pins bleiben")
	assert_eq(chip._epoxy_material.emission, chip.EPOXY_ALBEDO.lerp(ComboChipView.HIGHLIGHT_COLOR, 1.0),
		"das Gehäuse samt Endkappe geht ins Gold")

func test_each_socket_has_its_own_line_in_its_module_colour() -> void:
	var key := _key()
	run.stash_part(ComboPart.resistor())
	run.install_pending_part(key, 0)
	run.stash_part(ComboPart.high_voltage_tube())
	run.install_pending_part(key, 2)
	var chip := _real_chip(key)
	_sync(chip)
	for slot in GameRun.SOCKETS_PER_COMBO:
		assert_not_null(chip.find_child("Leitung_%d" % slot, true, false), "Leitung %d" % slot)
	assert_eq(chip.tile_color(0), ComboPart.resistor().tint(), "die Kachel trägt die Modulfarbe")
	assert_eq(chip.tile_color(2), ComboPart.high_voltage_tube().tint())
	assert_gt(chip.line_energy(0), chip.line_energy(1), "ein leerer Sockel bleibt dunkel")
	assert_null(chip.find_child("Abdeckung", true, false), "die Abdeckung ist tot")
	chip.set_throttled(true)
	assert_eq(chip.line_energy(0), 0.0, "gedrosselt sind die Leitungen aus")
	assert_true(chip.pin_body(0).dimmed(), "und die Pins dunkel")

# --- KOMPAKT und AUSGEFAHREN ----------------------------------------------------------

func test_a_chip_starts_compact_with_its_sockets_sunk_and_unpickable() -> void:
	var chip := _real_chip(_key())
	_sync(chip)
	assert_false(chip.extended())
	assert_eq(chip.extension(), 0.0)
	assert_eq(_picks_enabled(chip), 0, "kompakt nimmt kein Sockel den Zeiger")
	var sockets := chip.find_child("Sockets", false, false) as Node3D
	assert_false(sockets.visible, "die Sockelzone ist eingefahren")
	assert_almost_eq(chip.shift_now(), ComboChipView.compact_shift(), 0.0001, "die Anzeige rückt nach rechts")

func test_extending_writes_the_end_state_first_and_rides_after() -> void:
	var chip := _real_chip(_key())
	_sync(chip)
	chip.set_extended(true)
	assert_true(chip.extended(), "Endzustand sofort")
	assert_eq(_picks_enabled(chip), GameRun.SOCKETS_PER_COMBO, "und sofort pickbar")
	assert_lt(chip.extension(), 1.0, "der Körper fährt erst noch")
	await wait_seconds(ComboChipView.EXTEND_TIME + 0.15)
	assert_eq(chip.extension(), 1.0)
	assert_eq(chip.shift_now(), 0.0)
	assert_true((chip.find_child("Sockets", false, false) as Node3D).visible)
	chip.set_extended(false)
	assert_eq(_picks_enabled(chip), 0)
	chip.settle_extension_hard()
	assert_eq(chip.extension(), 0.0, "der harte Weg steht sofort")
	assert_false(chip.extension_running())

func test_the_compact_display_ends_before_the_end_cap() -> void:
	var chip := _real_chip(_key())
	var cap_left := chip._half - ComboChipView.CAP
	assert_almost_eq(chip.display_right() + ComboChipView.compact_shift(),
		cap_left - ComboChipView.DISPLAY_CAP_GAP, 0.0001, "kompakt schließt die Anzeige an die Endkappe")
	assert_lt(chip.socket_x(2) + ComboPartBody.SOCKET_OUTER.y * 0.5, cap_left, "ausgefahren vor der Endkappe")

func test_the_body_mesh_telescopes_without_distortion() -> void:
	assert_eq(ComboChipView.stretched_x(-40.0, 10.0), -30.0, "links rückt alles voll")
	assert_eq(ComboChipView.stretched_x(40.0, 10.0), 40.0, "rechts bleibt alles")
	assert_almost_eq(ComboChipView.stretched_x(0.0, 10.0), 5.0, 0.0001, "die Mitte staucht")
	var chip := _real_chip(_key())
	var pins := chip.find_child("Pins", true, false) as MeshInstance3D
	assert_lt(pins.get_aabb().end.x, 0.0, "die rechten glb-Pins sind fort - dort stehen die Sockel-Pins")

func test_every_socket_has_a_pin_that_takes_the_form_of_its_module() -> void:
	var key := _key()
	var chip := _real_chip(key)
	_sync(chip)
	for slot in GameRun.SOCKETS_PER_COMBO:
		assert_null(chip.pin_body(slot), "leer: der Stahlpin")
	run.stash_part(ComboPart.counter_part())
	run.install_pending_part(key, 1)
	_sync(chip)
	var pin := chip.pin_body(1)
	assert_not_null(pin)
	assert_true(pin.is_pin())
	assert_eq(pin.part, run.parts_of(key)[1], "der Pin IST das Modul")
	assert_eq(ComboPartBody.pin_path(pin.part), ComboPartBody.PIN_MODEL % ComboPart.COUNTER)
	var top := chip.to_local(chip.pin_world(0))
	var bottom := chip.to_local(chip.pin_world(2))
	assert_lt(top.z, bottom.z, "Sockel 0 = oberer Pin, 2 = unterer")
	chip.set_socket_lifted(1)
	assert_false(pin.visible, "in der Hand zeigt der Platz leer - auch am Pin")

func test_the_pin_reads_the_state_through_the_same_writer() -> void:
	var key := _key()
	run.stash_part(ComboPart.counter_part())
	run.install_pending_part(key, 0)
	run.parts_of(key)[0].counter = 4
	var chip := _real_chip(key)
	_sync(chip)
	var body := chip._sockets[0]["body"] as ComboPartBody
	var pin := chip.pin_body(0)
	assert_eq(pin.digits_text(), body.digits_text(), "Zählwerk-Ziffern am Pin wie am Modul")
	assert_eq(pin.digits_text(), "005")
	chip.set_part_context({"first_hand": false})
	assert_false(bool(pin.state().get("first_hand", true)), "derselbe Kontext erreicht den Pin")

func test_a_flash_reaches_pin_and_tile() -> void:
	var key := _key()
	run.stash_part(ComboPart.resistor())
	run.install_pending_part(key, 2)
	var chip := _real_chip(key)
	_sync(chip)
	var rest := chip.tile_energy(2)
	chip.flash_socket(2, 2.0)
	await wait_frames(2)
	assert_gt(chip.pin_body(2).flash_level(), 0.5, "der Pin blitzt")
	assert_gt(chip.tile_energy(2), rest, "die Kachel mit")

func test_pin_offsets_center_the_tips_in_both_layouts() -> void:
	var cell := TableScreen.CELL_SIZE
	var wide: float = ComboChipView.pin_offsets_px(cell, true)["tip_dx"]
	var compact: float = ComboChipView.pin_offsets_px(cell, false)["tip_dx"]
	assert_lt(wide, cell.x * 0.5, "die Pin-Spitzen bleiben in der Zelle")
	assert_almost_eq(wide - compact, ComboChipView.compact_shift() * ComboChipView.px_per_world(cell) * 0.5,
		0.01, "kompakt fehlt die Sockelzone")
	var compact_cell := ComboChipView.compact_cell_width(cell)
	assert_almost_eq(cell.x * 0.5 - wide, compact_cell * 0.5 - compact, 0.01, "gleicher Rand in beiden")
	var chip := _real_chip(_key())
	var span_px := (chip.origin_offset(true) - chip.origin_offset(false)) * ComboChipView.px_per_world(cell)
	assert_almost_eq(span_px, ComboChipView.compact_shift() * ComboChipView.px_per_world(cell) * 0.5, 0.01)

# --- Die zwei Layouts des Clusters ------------------------------------------------------

func _screen() -> TableScreen:
	var world := Node3D.new()
	add_child_autofree(world)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(31.2, 0.2, 21.2)
	mesh.mesh = box
	world.add_child(mesh)
	mesh.global_transform = Transform3D(Basis(Vector3(0, 0, 4), Vector3(0, 4, 0), Vector3(-4, 0, 0)),
		Vector3(0, -3.8, 0))
	var screen := TableScreen.new()
	world.add_child(screen)
	screen.attach_to(mesh)
	return screen

func test_both_layouts_stand_flush_right_at_the_pit() -> void:
	var screen := _screen()
	var pit := Rect2(1801.5, 1304.8, 1071.0, 570.0)
	screen.place_combo_cluster(Vector2(1000, 1500), pit)
	assert_false(screen.cluster_extended, "die Regel ist kompakt")
	var key: String = DiceScoring.HAND_PRIORITY[2]
	for extended in [false, true]:
		var cell := screen.cell_rect_for(key, extended)
		var tip: float = ComboChipView.pin_offsets_px(TableScreen.CELL_SIZE, extended)["tip_dx"]
		assert_almost_eq(cell.get_center().x + tip, pit.position.x - TableScreen.PIT_SIDE_GAP, 0.01,
			"Pin-Spitzen vor der Grube (%s)" % ("ausgefahren" if extended else "kompakt"))
		var rect := screen.cluster_rect_for(extended)
		assert_gt(rect.position.x, 0.0, "nichts über den linken Rand")
		assert_lte(rect.end.y, pit.end.y + TableScreen.CLUSTER_PADDING + 0.01, "nichts unter die Grube")
	assert_lt(screen.cluster_rect_for(false).size.x, 1285.0, "kompakt schmaler als vor dem großen Chip")
	var cell := screen.combo_cells[key] as ComboCellView
	assert_true(Rect2(cell.position, cell.size).is_equal_approx(screen.cell_rect_for(key, false)))
	screen.set_cluster_extended(true)
	assert_true(Rect2(cell.position, cell.size).is_equal_approx(screen.cell_rect_for(key, true)),
		"Endzustand sofort")
	assert_eq(screen.cluster_rect, screen.cluster_rect_for(true))
	var paths := screen.wiring_paths_to_cell(2)
	assert_false(paths.is_empty())
	var tip_x := cell.position.x + cell.size.x * 0.5 \
		+ float(ComboChipView.pin_offsets_px(TableScreen.CELL_SIZE, true)["tip_dx"])
	assert_almost_eq(paths[0][paths[0].size() - 1].x, cell.position.x + cell.size.x * 0.5
		- float(ComboChipView.pin_offsets_px(TableScreen.CELL_SIZE, true)["tip_dx"]), 0.01,
		"die Kometen fahren die Pins des Endzustands an")
	assert_gt(tip_x, 0.0)
