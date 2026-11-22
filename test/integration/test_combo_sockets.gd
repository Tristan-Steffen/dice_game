extends GutTest
## Die STECKPLÄTZE am Tisch (Welle D: nur noch Pins): Modul-Paket im Laden, die Belegung an
## den drei Plätzen des Chips, der Weg aus pending_parts in einen Platz, Tausch und
## Umstecken nur im Bearbeitungs-Fenster, die Ware des Schwarzmarkts und das Feld.

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
	chip.setup(1.5)
	return chip

## Ein Chip in seiner echten Tischgröße und Lage (37,5 Display-px je Welt, Modell-X = Welt+Z).
func _real_chip(key: String) -> ComboChipView:
	var chip := ComboChipView.new()
	chip.combo_key = key
	add_child_autofree(chip)
	chip.rotation.y = -PI / 2.0
	chip.setup(TableScreen.CELL_SIZE.y / 37.5)
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
	assert_eq(ComboPartBody.SIDE, ComboPartBody.HULL.x, "die lange Kante des Pins")
	var chip := _real_chip(_key())
	run.stash_part(ComboPart.capacitor())
	run.install_pending_part(chip.combo_key, 0)
	_sync(chip)
	assert_almost_eq(chip.pin_body(0).global_basis.get_scale().x, 1.0, 0.001, "am Chip in seiner einen Größe")

# --- Die Plätze ------------------------------------------------------------------

func test_the_chip_shows_the_socket_layout() -> void:
	var key := _key()
	var chip := _chip(key)
	_sync(chip)
	assert_eq(chip.socket_count(), GameRun.SOCKETS_PER_COMBO, "drei freie Plätze")
	for slot in chip.socket_count():
		assert_null(chip.socket_part(slot))
	run.stash_part(ComboPart.capacitor())
	run.install_pending_part(key, 1)
	_sync(chip)
	assert_eq(chip.socket_part(1), run.parts_of(key)[1], "der Chip zeigt die Instanz")
	assert_null(chip.socket_part(0))

func test_the_three_places_lie_at_the_right_edge() -> void:
	var chip := _real_chip(_key())
	_sync(chip)
	for slot in chip.socket_count():
		var at := chip.to_local(chip.pin_world(slot))
		assert_almost_eq(at.y, 0.0, 0.001, "der Platz liegt auf dem Tisch")
		assert_almost_eq(at.x, chip.half_length() + ComboPartBody.HULL.x * 0.5, 0.001, "rechts am Gehäuse")
	assert_gt(chip.row_z(1) - chip.row_z(0) - ComboPartBody.HULL.y, 0.0, "die Pins berühren sich nicht")
	assert_lt(chip.row_z(0) - ComboPartBody.HULL.y * 0.5 - chip._z_shift, 0.0, "oben")
	assert_gt(chip.row_z(0) - ComboPartBody.HULL.y * 0.5,
		chip._z_shift - ComboChipView.BODY_WIDTH * chip._s * 0.5, "und noch vor der Gehäusekante")

func test_heat_buildup_dims_the_part() -> void:
	var key := _key()
	var chip := _chip(key)
	run.stash_part(ComboPart.resistor())
	run.install_pending_part(key, 0)
	run.heat_disabled_parts[run.parts_of(key)[0].get_instance_id()] = true
	_sync(chip)
	assert_true(chip.socket_dimmed(0), "stillgelegt liest stumpf")
	assert_true(chip.pin_body(0).dimmed())
	assert_false(chip.socket_dimmed(1))

func test_a_plugged_module_is_its_pin() -> void:
	var key := _key()
	var chip := _chip(key)
	run.stash_part(ComboPart.capacitor())
	run.install_pending_part(key, 2)
	_sync(chip)
	var pin := chip.pin_body(2)
	assert_eq(pin.position, Vector3.ZERO, "der Pin steht auf seinem Platz")
	chip.play_plug(2)
	assert_gt(pin.position.y, 0.0, "der Einbau fährt von oben hinein")
	await wait_seconds(ComboChipView.PLUG_TIME + 0.1)
	assert_almost_eq(pin.position.y, 0.0, 0.001, "und steckt")

func test_the_pick_bodies_name_their_socket() -> void:
	var key := _key(2)
	var chip := _chip(key)
	_sync(chip)
	var picks: Array = []
	for body in chip.find_children("*", "StaticBody3D", true, false):
		assert_eq(body.collision_layer, ComboChipView.SOCKET_PICK_LAYER)
		picks.append(ComboChipView.pick_of(body))
	assert_eq(picks.size(), GameRun.SOCKETS_PER_COMBO + 1, "je Platz einer, dazu der Chip")
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

func test_beckon_and_hover_light_the_frame_of_a_place() -> void:
	var chip := _real_chip(_key())
	_sync(chip)
	var rest := chip.frame_color(0)
	chip.set_socket_beckon(true, false)
	assert_eq(chip.frame_color(0), ComboChipView.SOCKET_BECKON_COLOR, "der freie Platz ruft")
	chip.set_socket_hover(0)
	assert_eq(chip.frame_color(0), ComboChipView.SOCKET_HOVER_COLOR, "der Zeiger säumt golden")
	chip.set_socket_hover(-1)
	chip.set_socket_beckon(false, false)
	assert_eq(chip.frame_color(0), rest)

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

func test_moving_a_part_reaches_both_chips() -> void:
	var a := _chip(_key(0))
	var b := _chip(_key(1))
	run.stash_part(ComboPart.relay())
	run.install_pending_part(a.combo_key, 0)
	_sync(a)
	_sync(b)
	a.set_socket_lifted(0)
	assert_eq(a.socket_lifted(), 0, "in der Hand zeigt der Platz leer")
	assert_false(a.pin_body(0).visible)
	assert_false(run.move_part(a.combo_key, 0, b.combo_key, 2, false), "außerhalb des Fensters nichts")
	assert_true(run.move_part(a.combo_key, 0, b.combo_key, 2, true))
	a.set_socket_lifted(-1)
	_sync(a)
	_sync(b)
	assert_null(a.socket_part(0))
	assert_eq(b.socket_part(2).id, ComboPart.RELAY)
	assert_not_null(b.pin_body(2))

# --- Der SCHWARZMARKT ------------------------------------------------------------

func test_a_secret_part_offer_lies_as_a_pin_and_sells() -> void:
	run.luck = (GameRun.TIER_MAX - 1) * GameRun.LUCK_PER_TIER
	run.storage_rows = 4  # volle Börse (25)
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
	assert_eq((found[0]["node"] as ComboPartBody).part, part, "der Pin des Moduls")
	assert_eq(view.vitrine_annotation(ShopController.KIND_PART, 1)["title"], part.display_name)
	var bought: Array = []
	view.part_purchased.connect(func(p: ComboPart) -> void: bought.append(p))
	view.buy_offer(1)
	assert_eq(run.pending_parts.size(), 1, "gekauft wartet es auf den Einbau")
	assert_eq(bought.size(), 1, "und meldet sein Licht")
	assert_eq(run.pending_parts[0].id, part.id)

# --- Die Wertung ---------------------------------------------------------------

func test_a_scoring_part_flashes_its_place_and_fades() -> void:
	var key := _key()
	run.stash_part(ComboPart.amplifier_tube())
	run.install_pending_part(key, 1)
	var chip := _chip(key)
	_sync(chip)
	var pin := chip.pin_body(1)
	var rest := chip.tile_energy(1)
	chip.flash_socket(1, 2.0)
	await wait_frames(2)
	assert_gt(pin.flash_level(), 0.5, "der Pin leuchtet auf")
	assert_gt(chip.socket_flash(1), 0.5, "und sein Rahmen mit")
	assert_gt(chip.tile_energy(1), rest, "und die Kachel")
	assert_gt(pin.scale.x, 1.0, "der Krit-Schlag poppt")
	await wait_seconds(ComboPartBody.FLASH_TIME * 2.0 + 0.2)
	assert_almost_eq(pin.flash_level(), 0.0, 0.001, "und klingt ab")
	assert_almost_eq(pin.scale.x, 1.0, 0.001)

func test_flashing_an_empty_or_foreign_socket_is_harmless() -> void:
	var chip := _chip(_key())
	_sync(chip)
	chip.flash_socket(0)
	chip.flash_socket(99)
	chip.flash_socket(-1)
	await wait_frames(2)
	assert_gt(chip.socket_flash(0), 0.0, "ein leerer Platz blitzt nur am Rahmen")
	assert_eq(chip.socket_flash(99), 0.0)

func test_the_spotlight_pulse_has_a_truthful_name() -> void:
	var screen: TableScreen = autofree(TableScreen.new())
	assert_true(screen.has_method("play_combo_pulse"))
	assert_false(screen.has_method("play_overclock_pulse"), "das Übertakten ist tot")
	var chip: ComboChipView = autofree(ComboChipView.new())
	assert_true(chip.has_method("play_arrival_flash"))
	assert_false(chip.has_method("play_upgrade_flash"))

# --- Der Chip: Anzeige, Endkappe, Plätze -----------------------------------------------

func test_the_display_lies_left_and_the_places_right() -> void:
	var chip := _real_chip(_key())
	_sync(chip)
	var half := chip.half_length()
	assert_gt(chip.display_right(), -half + 4.0, "die Anzeige hat Platz für Name und Wertung")
	assert_almost_eq(chip.display_right(), half - ComboChipView.CAP - ComboChipView.DISPLAY_CAP_GAP, 0.0001,
		"die Anzeige schließt an die Endkappe")
	assert_almost_eq(chip._s * ComboChipView.BODY_COMPACT, half * 2.0, 0.0001)
	assert_null(chip.find_child("Sockets", true, false), "keine Sockelzone mehr")
	assert_null(chip.find_child("Leitung_0", true, false), "keine Leitungen mehr")
	assert_false(chip.has_method("set_extended"), "der Chip fährt nicht mehr aus")

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

func test_a_resting_module_glows_bright_and_flashes_full() -> void:
	var key := _key()
	run.stash_part(ComboPart.capacitor())
	run.install_pending_part(key, 0)
	var chip := _real_chip(key)
	_sync(chip)
	var pin := chip.pin_body(0)
	assert_true(pin.resting())
	assert_almost_eq(pin.light_energy(), ComboPartBody.WINDOW_ENERGY * ComboPartBody.REST_SHARE, 0.001)
	chip.flash_socket(0)
	await wait_frames(1)
	assert_gt(pin.light_energy(), ComboPartBody.WINDOW_ENERGY, "feuernd voll")

func test_the_gold_rule_spares_the_places() -> void:
	var key := _key()
	run.stash_part(ComboPart.capacitor())
	run.install_pending_part(key, 0)
	var chip := _real_chip(key)
	_sync(chip)
	var frame_before := chip.frame_color(1)
	var tile_before := chip.tile_color(0)
	var pin_before := chip.pin_body(0).light_energy()
	chip.set_glow(1.0)
	assert_eq(chip.frame_color(1), frame_before, "Rahmen bleiben")
	assert_eq(chip.tile_color(0), tile_before, "Kacheln bleiben")
	assert_eq(chip.pin_body(0).light_energy(), pin_before, "Modul-Pins bleiben")
	assert_eq(chip._epoxy_material.emission, chip.EPOXY_ALBEDO.lerp(ComboChipView.HIGHLIGHT_COLOR, 1.0),
		"das Gehäuse samt Endkappe geht ins Gold")

func test_each_tile_carries_its_module_colour() -> void:
	var key := _key()
	run.stash_part(ComboPart.resistor())
	run.install_pending_part(key, 0)
	run.stash_part(ComboPart.high_voltage_tube())
	run.install_pending_part(key, 2)
	var chip := _real_chip(key)
	_sync(chip)
	assert_eq(chip.tile_color(0), ComboPart.resistor().tint(), "die Kachel trägt die Modulfarbe")
	assert_eq(chip.tile_color(2), ComboPart.high_voltage_tube().tint())
	assert_gt(chip.tile_energy(0), chip.tile_energy(1), "ein leerer Platz bleibt dunkel")
	chip.set_throttled(true)
	assert_lt(chip.tile_energy(0), 0.2, "gedrosselt sind die Kacheln aus")
	assert_true(chip.pin_body(0).dimmed(), "und die Pins dunkel")

func test_the_body_mesh_is_compacted_without_distortion() -> void:
	assert_eq(ComboChipView.stretched_x(-40.0, 10.0), -30.0, "links rückt alles voll")
	assert_eq(ComboChipView.stretched_x(40.0, 10.0), 40.0, "rechts bleibt alles")
	assert_almost_eq(ComboChipView.stretched_x(0.0, 10.0), 5.0, 0.0001, "die Mitte staucht")
	var chip := _real_chip(_key())
	var body := chip.find_child("Body", true, false) as MeshInstance3D
	var box := chip.global_transform.affine_inverse() * body.global_transform * body.get_aabb()
	assert_almost_eq(box.get_center().x, 0.0, 0.05, "das gestauchte Gehäuse steht mittig")
	assert_almost_eq(box.size.x, chip.half_length() * 2.0, 0.05)
	var pins := chip.find_child("Pins", true, false) as MeshInstance3D
	assert_lt(pins.get_aabb().end.x, 0.0, "die rechten glb-Pins sind fort - dort stehen die Plätze")

func test_every_place_shows_its_module_or_the_empty_place() -> void:
	var key := _key()
	var chip := _real_chip(key)
	_sync(chip)
	for slot in GameRun.SOCKETS_PER_COMBO:
		assert_null(chip.pin_body(slot), "leer: der freie Platz")
	run.stash_part(ComboPart.counter_part())
	run.install_pending_part(key, 1)
	_sync(chip)
	var pin := chip.pin_body(1)
	assert_not_null(pin)
	assert_eq(pin.part, run.parts_of(key)[1], "der Pin IST das Modul")
	var top := chip.to_local(chip.pin_world(0))
	var bottom := chip.to_local(chip.pin_world(2))
	assert_lt(top.z, bottom.z, "Platz 0 = oberer Pin, 2 = unterer")
	chip.set_socket_lifted(1)
	assert_false(pin.visible, "in der Hand zeigt der Platz leer")

func test_the_pin_reads_the_state_of_its_chip() -> void:
	var key := _key()
	run.stash_part(ComboPart.counter_part())
	run.install_pending_part(key, 0)
	run.parts_of(key)[0].counter = 4
	var chip := _real_chip(key)
	_sync(chip)
	var pin := chip.pin_body(0)
	assert_eq(pin.digits_text(), "005")
	chip.set_part_context({"first_hand": false})
	assert_false(bool(pin.state().get("first_hand", true)), "der Kontext erreicht den Pin")

func test_pin_offsets_center_the_tips_in_the_cell() -> void:
	var cell := TableScreen.CELL_SIZE
	var tip: float = ComboChipView.pin_offsets_px(cell)["tip_dx"]
	assert_lt(tip, cell.x * 0.5, "die Pin-Spitzen bleiben in der Zelle")
	assert_gt(tip, cell.x * 0.5 - 8.0, "und füllen sie fast")
	var ppw := ComboChipView.px_per_world(cell)
	assert_almost_eq(ppw, 37.5, 0.05, "der echte Tisch")
	var chip := _real_chip(_key())
	var left_tip := -chip.half_length() - (ComboChipView.MODEL_LENGTH - ComboChipView.BODY_LENGTH) * 0.5 * chip._s
	var right_tip := chip.half_length() + ComboPartBody.HULL.x
	assert_almost_eq((right_tip - left_tip) * ppw, tip * 2.0, 0.5, "Spanne Pin zu Pin")
	assert_almost_eq((left_tip + right_tip) * 0.5, -chip.origin_offset(), 0.001, "die Zelle zentriert die Spitzen")

# --- Das Feld des Clusters ------------------------------------------------------------------

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

func test_the_field_stands_flush_right_at_the_pit() -> void:
	var screen := _screen()
	var pit := Rect2(1801.5, 1304.8, 1071.0, 570.0)
	screen.place_combo_cluster(Vector2(1000, 1500), pit)
	assert_false(screen.has_method("set_cluster_extended"), "EIN Layout")
	var key: String = DiceScoring.HAND_PRIORITY[2]
	var cell := screen.combo_cells[key] as ComboCellView
	var tip: float = ComboChipView.pin_offsets_px(TableScreen.CELL_SIZE)["tip_dx"]
	assert_almost_eq(cell.position.x + cell.size.x * 0.5 + tip, pit.position.x - TableScreen.PIT_SIDE_GAP, 0.01,
		"Pin-Spitzen vor der Grube")
	assert_gt(screen.cluster_rect.position.x, 0.0, "nichts über den linken Rand")
	assert_lte(screen.cluster_rect.end.y, pit.end.y + TableScreen.CLUSTER_PADDING + 0.01, "nichts unter die Grube")
	var paths := screen.wiring_paths_to_cell(2)
	assert_false(paths.is_empty())
	assert_almost_eq(paths[0][paths[0].size() - 1].x, cell.position.x + cell.size.x * 0.5 - tip, 0.01,
		"die Kometen fahren die Pins an")

## Zwischen zwei Spalten steht die Sammelschiene frei zwischen Modul-Pin und linkem Pin.
func test_the_column_gap_holds_pin_and_bus() -> void:
	var screen := _screen()
	screen.place_combo_cluster(Vector2(1000, 1500), Rect2(1801.5, 1304.8, 1071.0, 570.0))
	var a := screen.combo_cells[DiceScoring.HAND_PRIORITY[0]] as ComboCellView
	var b := screen.combo_cells[DiceScoring.HAND_PRIORITY[1]] as ComboCellView
	var tip: float = ComboChipView.pin_offsets_px(TableScreen.CELL_SIZE)["tip_dx"]
	var free := (b.position.x + b.size.x * 0.5 - tip) - (a.position.x + a.size.x * 0.5 + tip)
	assert_gt(free, TableScreen.COMBO_WIRING_WIDTH + 8.0, "die Schiene steht frei zwischen den Spitzen")
