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
		assert_eq(chip.socket_carrier(slot), -1, "Platz %d gehört dem Chip" % slot)
		assert_almost_eq(chip.socket_world(slot).y, chip.global_position.y
			+ ComboChipView.BODY_TOP * chip._sz, 0.001, "der Sockel liegt auf dem Deckel")
	assert_lt(chip.socket_world(0).x, chip.socket_world(1).x, "eine Reihe längs des Chips")

func test_an_expansion_board_is_a_riser_with_two_sockets_on_top() -> void:
	var key := _key()
	var chip := _chip(key)
	run.stash_part(ComboPart.expansion_board())
	run.install_pending_part(key, 1)
	_sync(chip)
	assert_eq(chip.socket_count(), GameRun.SOCKETS_PER_COMBO + 2, "netto +1 Platz, zwei neue")
	assert_eq(chip.socket_count(), run.socket_count(key))
	assert_eq(chip.socket_carrier(3), 1, "die neuen Plätze sitzen auf der Platine")
	assert_eq(chip.socket_carrier(4), 1)
	assert_gt(chip.socket_world(3).y, chip.socket_world(1).y, "oben auf ihr")
	var riser := chip._sockets[1]["body"] as ComboPartBody
	assert_true((chip._sockets[3]["node"] as Node3D).get_parent() == riser, "sie reisen mit ihr")

func test_a_riser_on_a_riser_stacks_crosswise() -> void:
	var key := _key()
	var chip := _chip(key)
	run.stash_part(ComboPart.expansion_board())
	run.install_pending_part(key, 0)
	run.stash_part(ComboPart.expansion_board())
	assert_true(run.install_pending_part(key, 3), "eine Platine trägt eine Platine")
	run.stash_part(ComboPart.relay())
	assert_true(run.install_pending_part(key, 5))
	_sync(chip)
	assert_eq(chip.socket_count(), 7)
	assert_eq(chip.socket_carrier(5), 3, "das zweite Paar sitzt auf der zweiten Platine")
	var upper := chip._sockets[3]["body"] as ComboPartBody
	assert_almost_eq(absf(upper.rotation.y), PI * 0.5, 0.001, "quer zu ihrer Trägerin")
	assert_eq(chip.socket_part(5).id, ComboPart.RELAY)

func test_a_riser_never_plugs_into_its_own_pair() -> void:
	var key := _key()
	run.stash_part(ComboPart.expansion_board())
	run.install_pending_part(key, 0)
	run.stash_part(ComboPart.expansion_board())
	run.install_pending_part(key, 3)
	assert_false(run.move_part(key, 3, key, 5, true), "nicht in ihr eigenes Paar")
	assert_eq(run.parts_of(key)[3].id, ComboPart.EXPANSION_BOARD)

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
	assert_eq(picks.size(), GameRun.SOCKETS_PER_COMBO + 1, "je Platz einer plus der Chip")
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

func test_pulling_an_overfull_expansion_board_snaps_back() -> void:
	var key := _key()
	run.stash_part(ComboPart.expansion_board())
	run.install_pending_part(key, 0)
	for slot in range(1, run.socket_count(key)):
		run.stash_part(ComboPart.resistor())
		run.install_pending_part(key, slot)
	var other := _key(1)
	for slot in run.socket_count(other):
		run.stash_part(ComboPart.capacitor())
		run.install_pending_part(other, slot)
	# Fünf Teile auf dem Chip, die Platine fort: vier blieben für drei Plätze.
	assert_false(run.move_part(key, 0, other, 0, true), "GameRun weist ab - das Teil bleibt")
	assert_eq(run.parts_of(key)[0].id, ComboPart.EXPANSION_BOARD)

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

# --- Die Platine ----------------------------------------------------------------------

## Ein Chip in seiner echten Tischgröße und Lage (37,5 Display-px je Welt, Modell-X = Welt+Z).
func _real_chip(key: String) -> ComboChipView:
	var chip := ComboChipView.new()
	chip.combo_key = key
	add_child_autofree(chip)
	chip.rotation.y = -PI / 2.0
	var size := TableScreen.CELL_SIZE / 37.5
	chip.setup(size.x, size.y)
	return chip

## Die Ecken einer Platine im Chip-Raum.
func _riser_box(chip: ComboChipView, slot: int) -> AABB:
	var body := chip._sockets[slot]["body"] as ComboPartBody
	var box := AABB(chip.to_local(body.global_transform * ComboPartBody.riser_corners()[0]), Vector3.ZERO)
	for corner in ComboPartBody.riser_corners():
		box = box.expand(chip.to_local(body.global_transform * corner))
	return box

func test_a_riser_stays_within_the_chip_length_and_overhangs_front_and_back() -> void:
	for slot in GameRun.SOCKETS_PER_COMBO:
		run = GameRun.new_run()
		var key := _key()
		run.stash_part(ComboPart.expansion_board())
		run.install_pending_part(key, slot)
		var chip := _real_chip(key)
		_sync(chip)
		var box := _riser_box(chip, slot)
		var half_x := ComboChipView.BODY_LENGTH * chip._sx * 0.5
		assert_lte(absf(box.end.x), half_x + 0.001, "Platine auf Platz %d bleibt längs im Chip" % slot)
		assert_gte(box.position.x, chip.display_right(), "und neben der Anzeige")
		var z_min := ComboChipView.MODEL_Z_MIN * chip._sz + chip._z_shift
		var z_max := ComboChipView.MODEL_Z_MAX * chip._sz + chip._z_shift
		assert_lt(box.position.z, z_min, "sie ragt hinten über")
		assert_gt(box.end.z, z_max, "und vorn")
		var a := chip.to_local(chip.socket_world(3))
		var b := chip.to_local(chip.socket_world(4))
		assert_almost_eq(a.x, b.x, 0.001, "zwei Plätze hintereinander quer zum Chip")
		assert_gt(absf(a.z - b.z), ComboPartBody.SOCKET_OUTER.x, "ohne sich zu überdecken")

func test_the_name_yields_to_a_riser() -> void:
	var key := DiceScoring.DOUBLE_THREE_KIND
	var chip := _real_chip(key)
	var cell := ComboCellView.new()
	add_child_autofree(cell)
	cell.combo_name = "Doppelter Dreierpasch"
	chip.sync_cell(cell)
	_sync(chip)
	var free_size: float = chip._name_label.pixel_size
	run.stash_part(ComboPart.expansion_board())
	run.install_pending_part(key, 0)
	_sync(chip)
	var right: float = chip._name_label.position.x + chip._text_width(chip._name_label) * 0.5
	assert_lt(right, chip._riser_name_limit(), "der Name endet vor der Platine")
	assert_lte(chip._name_label.pixel_size, free_size)

# --- Der große Chip: Anzeige, Abdeckung, Leitung -------------------------------------

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

func test_an_empty_chip_is_covered_and_its_sockets_take_no_pick() -> void:
	var key := _key()
	var chip := _real_chip(key)
	_sync(chip)
	assert_false(chip.cover_open(), "ohne Modul liegt die Abdeckung")
	assert_eq(_picks_enabled(chip), 0, "zu nimmt kein Sockel den Zeiger")
	var cover := chip.find_child("Abdeckung", true, false) as Node3D
	assert_eq(cover.find_children("Wuerfel*", "", false, false).size(),
		DiceScoring.EXAMPLE_DICE[key].size(), "das Würfelbild der Kombination")
	chip.set_cover_called(true)
	assert_true(chip.cover_open(), "der Zeiger an der Station öffnet sie")
	assert_eq(_picks_enabled(chip), GameRun.SOCKETS_PER_COMBO, "Endzustand zuerst: sofort pickbar")
	chip.set_cover_called(false)
	chip.set_socket_beckon(true, false)
	assert_true(chip.cover_open(), "der Einbau öffnet sie")
	chip.set_socket_beckon(false, false)
	assert_false(chip.cover_open())
	run.stash_part(ComboPart.resistor())
	run.install_pending_part(key, 2)
	_sync(chip)
	assert_true(chip.cover_open(), "ein Modul hält sie offen")
	chip.settle_cover_hard()
	assert_false(cover.visible, "hart: sofort fort")

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
	assert_true(chip.line_pulsing(), "die Leitung pulst mit")

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
	chip.set_glow(1.0)
	assert_eq(rim.emission, rim_before, "Sockel bleiben")
	assert_eq(body.light_energy(), light_before, "Module bleiben")
	assert_gt(chip.line_energy(0), line_before, "die Leitung geht ins Gold")

func test_the_line_shows_the_strength_behind_each_socket() -> void:
	var key := _key()
	run.stash_part(ComboPart.resistor())
	run.install_pending_part(key, 0)
	run.stash_part(ComboPart.magnetron())
	run.install_pending_part(key, 2)
	var chip := _real_chip(key)
	_sync(chip)
	assert_eq(chip.line_style(0), ComboChipView.LINE_STYLES["gleich"], "vor dem ersten Sockel")
	assert_eq(chip.line_style(1), ComboChipView.LINE_STYLES["dick"], "hinter dem Widerstand")
	assert_eq(chip.line_style(2), ComboChipView.LINE_STYLES["dick"], "ein leerer Sockel hält das Maximum")
	var strong: Vector3 = ComboChipView.LINE_STYLES["stark"]
	assert_eq(chip.line_style(3).x, strong.x, "hinter dem Magnetron stark")
	chip.set_throttled(true)
	assert_eq(chip.line_energy(3), 0.0, "gedrosselt ist die Leitung aus")
