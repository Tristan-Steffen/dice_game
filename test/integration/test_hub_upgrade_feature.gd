extends GutTest
## Integrationstests des Hub-Ausbaus über die Ansichten: HubView-Plakette/Knopf +
## Rahmen-Stufe, TableScreen.set_side_bet_installed (Fenster + Fork), und die
## Shop-Gating (kleiner Laden + verstecktes Blättern auf Stufe 1, Raritäts-Schub
## auf Stufe 4).

# --- HubView-Plakette + Aufstieg-Knopf ---------------------------------------

func _hub() -> HubView:
	var hub: HubView = add_child_autofree(HubView.new())
	hub.size = Vector2(1000, 600)
	hub.layout()
	return hub

func test_hub_plate_and_button_show_next_unlock() -> void:
	var hub := _hub()
	hub.set_hub_level(1, "Hinterzimmer", "Lizenz", "Voller Shop + Blättern", 10)
	assert_string_contains(hub.hub_level_label.text, "Hinterzimmer")
	# Plan-Zeile trägt die nächste Stufe + Freischaltung, der Knopf nur den Preis.
	assert_string_contains(hub.hub_next_label.text, "Lizenz")
	assert_string_contains(hub.hub_next_label.text, "Voller Shop")
	assert_true(hub.upgrade_button.visible, "Aufstieg-Knopf sichtbar unter Max")
	assert_string_contains(hub.upgrade_button.text, "10")

func test_hub_button_hidden_at_max_level() -> void:
	var hub := _hub()
	hub.set_hub_level(10, "High Roller", "", "", 0)
	assert_false(hub.upgrade_button.visible, "auf Maximalstufe kein Aufstieg-Knopf")

func test_hub_upgrade_button_emits_signal() -> void:
	var hub := _hub()
	hub.set_hub_level(1, "Hinterzimmer", "Lizenz", "x", 10)
	watch_signals(hub)
	hub.upgrade_button.pressed.emit()
	assert_signal_emitted(hub, "hub_upgrade_requested")

func test_hub_frame_thickens_with_level() -> void:
	var hub := _hub()
	hub.set_hub_level(1, "Hinterzimmer", "Spielecke", "x", 8)
	var thin: int = hub._frame_style.border_width_left
	hub.set_hub_level(10, "High Roller", "", "", 0)
	var thick: int = hub._frame_style.border_width_left
	assert_gt(thick, thin, "höhere Stufe -> dickerer Rahmen")

func test_hub_frame_recolors_per_tier() -> void:
	var hub := _hub()
	hub.set_hub_level(1, "Hinterzimmer", "Spielecke", "x", 8)
	var low: Color = hub._frame_style.border_color
	hub.set_hub_level(6, "VIP-Lounge", "Suite", "x", 55)
	var high: Color = hub._frame_style.border_color
	assert_ne(low, high, "jede Stufe hat eine eigene Signaturfarbe")

func test_hub_affordable_toggles_button_disabled() -> void:
	var hub := _hub()
	hub.set_hub_level(1, "Hinterzimmer", "Lizenz", "x", 10)
	hub.set_hub_upgrade_affordable(false)
	assert_true(hub.upgrade_button.disabled, "nicht bezahlbar -> ausgegraut")
	hub.set_hub_upgrade_affordable(true)
	assert_false(hub.upgrade_button.disabled)

# --- Nebenwetten-Installation (TableScreen) ----------------------------------

func _screen() -> TableScreen:
	var ts: TableScreen = add_child_autofree(TableScreen.new())
	ts.configure_pit_score(Vector2(1500, 650), Vector2(3180, 650), Vector2(900, 400))
	ts.place_goal_bar(Vector2(2340, 650))
	ts.place_combo_cluster(Vector2(700, 650))
	ts.place_score_screen()
	ts.place_hub(Vector2(2340, 2500), Vector2(1700, 520))
	ts.place_pit_window(Rect2(Vector2(1640, 1150), Vector2(1400, 760)), 60.0)
	ts.place_treasure_window(Rect2(Vector2(3400, 1600), Vector2(700, 430)))
	ts.place_side_bet_window(Rect2(Vector2(3400, 1150), Vector2(700, 430)))
	ts.link_hub_to_treasure()
	return ts

func test_side_bet_installed_toggles_window_visibility() -> void:
	var ts := _screen()
	ts.set_side_bet_installed(false)
	assert_false(ts.side_bet_window.visible, "vor Stufe 3: nicht installiert")
	ts.set_side_bet_installed(true)
	assert_true(ts.side_bet_window.visible, "ab Stufe 3: installiert")

func test_side_bet_fork_follows_installation() -> void:
	var ts := _screen()
	ts.set_side_bet_installed(true)
	assert_true(ts.treasure_strip.branch_path.size() >= 2, "Fork zur Hardware vorhanden")
	ts.set_side_bet_installed(false)
	assert_eq(ts.treasure_strip.branch_path.size(), 0, "ohne Installation kein Fork")

# --- Shop-Gating (ShopController) --------------------------------------------

const ShopPanelScene := preload("res://scenes/shop_panel.tscn")

func _shop(level: int) -> ShopController:
	var run := GameRun.new_run()
	run.money = 999
	run.hub_level = level
	var shop: ShopController = ShopPanelScene.instantiate()
	add_child_autofree(shop)
	shop.run = run
	shop.open()
	return shop

func test_level_one_shop_is_smaller() -> void:
	var shop := _shop(1)
	assert_eq(shop.charm_options.size(), 2, "Stufe 1: 2 Charms")
	assert_eq(shop.dice_packs.size(), 1, "Stufe 1: 1 Würfel-Paket")
	assert_eq(shop.overclock_offers.size(), 1, "Stufe 1: 1 Übertaktung")
	assert_eq(shop.engraving_packs.size(), 1, "Stufe 1: 1 Gravur-Paket")

func test_level_one_hides_flip_navigation() -> void:
	var shop := _shop(1)
	assert_false(shop.page_next_button.visible, "Stufe 1: kein Vorblättern")
	assert_false(shop.page_back_button.visible)
	assert_true(shop.flip_hint_label.visible, "stattdessen der Hinweis")

func test_level_two_unlocks_flipping() -> void:
	var shop := _shop(2)
	assert_eq(shop.engraving_packs.size(), 1, "Stufe 2: noch 1 Gravur-Paket")
	assert_eq(shop.dice_packs.size(), 1, "Stufe 2: 2. Paket erst später")
	assert_true(shop.page_next_button.visible, "Stufe 2: Blättern frei")

func test_level_three_grows_the_shop() -> void:
	var shop := _shop(3)
	assert_eq(shop.charm_options.size(), 3, "Stufe 3: 3 Charms")
	assert_eq(shop.dice_packs.size(), 2, "Stufe 3: 2 Würfel-Pakete")
	assert_eq(shop.engraving_packs.size(), 2, "Stufe 3: 2 Gravur-Pakete")

func test_level_seven_unlocks_third_pack_and_second_overclock() -> void:
	var shop := _shop(7)
	assert_eq(shop.dice_packs.size(), 3, "Suite: 3. Würfel-Paket")
	assert_eq(shop.overclock_offers.size(), 2, "Suite: 2. Übertaktung")
	assert_eq(shop.engraving_packs.size(), 3, "Suite: 3 Gravur-Pakete")

func test_level_six_spread_contains_a_non_common_charm() -> void:
	# Über mehrere Läufe stabil: der erste Platz ist garantiert nicht-gewöhnlich.
	var shop := _shop(6)
	var has_premium := false
	for charm in shop.charm_options:
		if charm.rarity != Charm.RARITY_COMMON:
			has_premium = true
	assert_true(has_premium, "VIP-Lounge garantiert einen besseren Charm")

# --- Elastisches Layout (wenige, große Karten -> viele, kleine) --------------

func test_every_offer_has_its_own_button() -> void:
	var shop := _shop(7)
	assert_eq(shop.overclock_buttons.size(), shop.run.shop_overclock_slots(),
		"jeder Chip der Schale ist ein Knopf")
	assert_eq(shop.dice_pack_buttons.size() + shop.engraving_pack_buttons.size(),
		shop.run.shop_dice_slots() + shop.run.shop_pack_slots(),
		"jedes Paket im Lager ist ein Knopf")

func test_charm_cards_grow_when_there_are_fewer() -> void:
	var shop := _shop(1)
	var few: Vector2 = shop._charm_metrics(2)
	var many: Vector2 = shop._charm_metrics(5)
	assert_gt(few.x, many.x, "wenige Charms -> höhere Karten")
	assert_gt(few.y, many.y, "wenige Charms -> größeres Modell")

func test_chip_diameter_shrinks_as_the_tray_fills() -> void:
	var shop := _shop(1)
	assert_gt(shop._chip_dia(3), shop._chip_dia(10), "volle Schale -> kleinere Chips")

# --- Roulette-Rim: Rad-Rand (Fahrplan) + Lizenz-Nabe -------------------------

func _stations(hub: HubView) -> Array:
	# Stationen tragen ein Label-Kind (das Ziel); der Rand/Chips nicht.
	var out := []
	for child in hub.roadmap_row.get_children():
		for sub in child.get_children():
			if sub is Label:
				out.append(child)
				break
	return out

func _filled_pips(hub: HubView) -> int:
	var count := 0
	for pip in hub._pips:
		var ps := pip.get_theme_stylebox("panel") as StyleBoxFlat
		if ps != null and ps.bg_color.a > 0.5:
			count += 1
	return count

func test_roadmap_builds_a_station_per_goal() -> void:
	var hub := _hub()
	await wait_frames(2)  # der Bühne Zeit geben, ihre Größe zu bekommen (Radgeometrie)
	hub.set_goal_roadmap([300, 350, 400, 450, 500, 550] as Array[int])
	var goals: Array = []
	for st in _stations(hub):
		for sub in st.get_children():
			if sub is Label:
				goals.append((sub as Label).text)
	assert_eq(goals, ["300", "350", "400", "450", "500", "550"],
		"jede Station trägt ihr Ziel in Reihenfolge")

func test_roadmap_current_station_is_largest() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([300, 350, 400] as Array[int])
	var stations := _stations(hub)
	assert_gt(stations[0].custom_minimum_size.x, stations[1].custom_minimum_size.x,
		"die aktuelle Station (jetzt) ist die größte")

func test_stations_lie_on_the_wheel_rim() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([300, 350, 400] as Array[int])
	assert_gt(hub._rim_radius, 0.0, "Radgeometrie berechnet")
	for st in _stations(hub):
		var stc: Vector2 = st.position + st.size * 0.5
		assert_almost_eq(stc.distance_to(hub._rim_center), hub._rim_radius, hub._rim_radius * 0.06,
			"Station sitzt auf dem Rad-Rand")

func test_current_station_carries_the_ball() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([300, 350, 400] as Array[int])
	var non_label := 0
	for child in _stations(hub)[0].get_children():
		if not (child is Label):
			non_label += 1
	assert_eq(non_label, 1, "die aktuelle Station trägt die Kugel")

func test_done_current_and_upcoming_states_read_differently() -> void:
	var hub := _hub()
	await wait_frames(2)
	# Block von 6, dritte Station (Index 2) ist dran: 0+1 geschafft, 3..5 offen.
	hub.set_goal_roadmap([150, 200, 250, 300, 350, 400] as Array[int], 2)
	var stations := _stations(hub)
	var done_box := (stations[0] as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	var open_box := (stations[4] as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	assert_gt(done_box.bg_color.a, 0.4, "geschaffte Station ist gefüllt")
	assert_lt(open_box.bg_color.v, done_box.bg_color.v, "offene Station bleibt dunkel")
	assert_gt(stations[2].custom_minimum_size.x, stations[0].custom_minimum_size.x,
		"die aktuelle Station ist die größte")
	# Die Kugel sitzt auf der AKTUELLEN Station (Index 2), nirgendwo sonst.
	for i in stations.size():
		var extras := 0
		for child in stations[i].get_children():
			if not (child is Label):
				extras += 1
		assert_eq(extras, 1 if i == 2 else 0, "Kugel nur auf Station %d" % 2)

func test_same_block_keeps_station_goals_as_position_advances() -> void:
	var hub := _hub()
	await wait_frames(2)
	var block: Array[int] = [150, 200, 250, 300, 350, 400]
	hub.set_goal_roadmap(block, 0)
	hub.set_goal_roadmap(block, 1)  # Rundensieg im selben Block
	var goals: Array = []
	for st in _stations(hub):
		for sub in st.get_children():
			if sub is Label:
				goals.append((sub as Label).text)
	assert_eq(goals, ["150", "200", "250", "300", "350", "400"],
		"die Stationen bleiben stehen - nur die Position rückt vor")

# --- Fahrplan-Marker: der Stresstest ------------------------------------------

func _markers(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func test_markers_color_the_station_itself() -> void:
	# Die Besonderheit färbt die KUGEL - aus der Übersichts-Distanz ist ein
	# Punkt darunter nicht zu sehen.
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([150, 200, 250, 300, 350, 400] as Array[int], 0,
		_markers(["", "", "", "", "", GameRun.STRESS_MARKER]))
	var stations := _stations(hub)
	var plain := (stations[2] as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	var stress := (stations[5] as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	assert_almost_eq(stress.border_color.h, ComboChipView.THROTTLE_COLOR.h, 0.02,
		"Stresstest-Station warnrot")
	assert_gt(stress.border_color.a, plain.border_color.a,
		"markierte Station tritt hervor - auch als hinterste des Blocks")
	assert_almost_eq(stress.bg_color.h, ComboChipView.THROTTLE_COLOR.h, 0.05,
		"ihre Füllung ist in Markerfarbe getönt")

func test_only_marked_stations_listen_for_hover() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([150, 200, 250] as Array[int], 0,
		_markers(["", GameRun.STRESS_MARKER, ""]))
	var stations := _stations(hub)
	assert_eq(stations[0].mouse_filter, Control.MOUSE_FILTER_IGNORE, "graue Station bleibt Deko")
	assert_eq(stations[1].mouse_filter, Control.MOUSE_FILTER_PASS, "markierte Station ist anfassbar")

func test_hovering_a_marker_names_its_effect() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([150, 200, 250] as Array[int], 0,
		_markers(["", "", GameRun.STRESS_MARKER]))
	var stations := _stations(hub)
	assert_false(hub.marker_hint.visible, "ohne Hover kein Hinweis")
	(stations[2] as Panel).mouse_entered.emit()
	assert_true(hub.marker_hint.visible)
	assert_eq(hub.marker_hint.title_label.text, GameRun.STRESS_NAME)
	assert_string_contains(hub.marker_hint.body_label.text, "Konditionen")
	(stations[2] as Panel).mouse_exited.emit()
	assert_false(hub.marker_hint.visible, "Hinweis verschwindet mit dem Zeiger")

func test_marker_hint_stays_inside_the_stage() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([150, 200, 250] as Array[int], 0,
		_markers([GameRun.STRESS_MARKER, "", ""]))
	# Station 0 sitzt am linken Rad-Rand - der Hinweis darf nicht hinausragen.
	(_stations(hub)[0] as Panel).mouse_entered.emit()
	await wait_frames(2)
	var rect := Rect2(hub.marker_hint.position, hub.marker_hint.size)
	assert_gte(rect.position.x, 0.0)
	assert_gte(rect.position.y, 0.0)
	assert_lte(rect.end.x, hub.roadmap_stage.size.x + 1.0)

func test_rebuilding_the_roadmap_drops_a_standing_hint() -> void:
	# Die gehoverte Station wird beim Neuaufbau freigegeben - der Hinweis dürfte
	# nicht als Geist über dem neuen Block stehenbleiben.
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([150, 200, 250] as Array[int], 0,
		_markers(["", GameRun.STRESS_MARKER, ""]))
	(_stations(hub)[1] as Panel).mouse_entered.emit()
	assert_true(hub.marker_hint.visible)
	hub.set_goal_roadmap([300, 350, 400] as Array[int], 0, _markers(["", "", ""]))
	assert_false(hub.marker_hint.visible)

# --- Deal-Marken --------------------------------------------------------------

func _sides(entries: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	typed.assign(entries)
	return typed

## Wie GameRun.active_deal_sides: Bonus/Malus steckt in der Klausel selbst.
func _side(clause_id: String) -> Dictionary:
	var clause := DealClause.find(clause_id)
	return {"id": clause_id, "bonus": clause.kind == DealClause.Kind.BONUS,
		"scope": clause.scope}

func test_tokens_show_one_mark_per_active_side() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_deal_tokens(_sides([
		_side(DealClause.SAVINGS_BONUS), _side(DealClause.EMPTIES),
		_side(DealClause.HAPPY_HOUR)]))
	assert_eq(hub.deal_token_row.get_child_count(), 3)
	hub.set_deal_tokens(_sides([]))
	assert_eq(hub.deal_token_row.get_child_count(), 0, "Abrechnung räumt die Reihe")

func test_the_token_size_carries_the_duration() -> void:
	# Die Größe ist die Laufzeit-Anzeige. Keine Klausel trägt mehr BLOCK, die
	# Grammatik der Reihe kennt die Stufe aber weiter - hier direkt gesetzt.
	var hub := _hub()
	await wait_frames(2)
	var long_side := _side(DealClause.SAVINGS_BONUS)
	long_side["scope"] = DealClause.Scope.BLOCK
	hub.set_deal_tokens(_sides([long_side, _side(DealClause.HAPPY_HOUR)]))
	var block_token: Control = hub.deal_token_row.get_child(0)
	var round_token: Control = hub.deal_token_row.get_child(1)
	assert_gt(block_token.custom_minimum_size.x, round_token.custom_minimum_size.x)

func test_bonus_and_malus_tokens_read_apart() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_deal_tokens(_sides([
		_side(DealClause.SAVINGS_BONUS), _side(DealClause.EMPTIES)]))
	var bonus := (hub.deal_token_row.get_child(0) as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	var malus := (hub.deal_token_row.get_child(1) as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(bonus.border_color, DealTokenRow.BONUS_COLOR)
	assert_eq(malus.border_color, DealTokenRow.MALUS_COLOR)

func test_hovering_a_token_explains_that_side() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_deal_tokens(_sides([_side(DealClause.EMPTIES)]))
	var token: Panel = hub.deal_token_row.get_child(0)
	token.mouse_entered.emit()
	assert_true(hub.marker_hint.visible)
	assert_eq(hub.marker_hint.title_label.text, DealClause.empties().display_name)
	assert_string_contains(hub.marker_hint.body_label.text, DealClause.empties().text)
	assert_string_contains(hub.marker_hint.body_label.text,
		DealClause.scope_label(DealClause.empties().scope), "die Laufzeit steht dabei")
	token.mouse_exited.emit()
	assert_false(hub.marker_hint.visible)

func test_rebuilding_tokens_drops_a_standing_hint() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_deal_tokens(_sides([_side(DealClause.SAVINGS_BONUS)]))
	(hub.deal_token_row.get_child(0) as Panel).mouse_entered.emit()
	assert_true(hub.marker_hint.visible)
	hub.set_deal_tokens(_sides([]))
	assert_false(hub.marker_hint.visible, "kein Geist über der leeren Reihe")

func test_the_settlement_sweep_reports_its_duration() -> void:
	var hub := _hub()
	await wait_frames(2)
	assert_eq(hub.sweep_deal_tokens(), 0.0, "ohne Marken nichts zu wischen")
	hub.set_deal_tokens(_sides([
		_side(DealClause.SAVINGS_BONUS), _side(DealClause.EMPTIES)]))
	assert_gt(hub.sweep_deal_tokens(), 0.0, "der Aufrufer wartet darauf")

func test_a_fresh_block_restores_swept_tokens() -> void:
	# Nach dem Wisch steht die Reihe verschoben und durchsichtig da - der
	# nächste Block muss sie wieder voll sichtbar bekommen.
	var hub := _hub()
	await wait_frames(2)
	hub.set_deal_tokens(_sides([_side(DealClause.SAVINGS_BONUS)]))
	hub.sweep_deal_tokens()
	hub.deal_token_row.modulate.a = 0.0  # Endzustand des Wischs vorwegnehmen
	hub.set_deal_tokens(_sides([_side(DealClause.HAPPY_HOUR)]))
	assert_eq(hub.deal_token_row.modulate.a, 1.0)

func test_a_benchmark_deal_lifts_the_current_station() -> void:
	# Der Fahrplan zeigt die WIRKSAMEN Ziele: unterschreibt der Spieler einen
	# Aufschlag, springt seine Station sofort mit - und nur sie, denn kein Deal
	# überlebt seine Runde.
	var run := GameRun.new_run()
	var before := run.goal_roadmap(GameRun.GOAL_BLOCK)
	run.sign_clauses([DealClause.BENCHMARK_SURCHARGE] as Array[String])
	var after := run.goal_roadmap(GameRun.GOAL_BLOCK)
	var here := run.goal_roadmap_index(GameRun.GOAL_BLOCK)
	for i in before.size():
		if i == here:
			assert_gt(after[i], before[i], "die laufende Station trägt den Aufschlag")
		else:
			assert_eq(after[i], before[i], "Station %d bleibt frei" % i)

func test_the_roadmap_tracks_blocks_by_id_not_by_numbers() -> void:
	# Sonst gälte ein mitten im Block unterschriebener Benchmark-Malus als
	# frischer Block und der Fahrplan spielte die falsche Animation.
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([150, 200, 250] as Array[int], 0, _markers([]), 0)
	hub.set_goal_roadmap([188, 250, 313] as Array[int], 0, _markers([]), 0)
	assert_eq(hub._roadmap_block, 0, "immer noch derselbe Block")
	assert_eq(hub._roadmap_goals, [188, 250, 313] as Array[int], "aber neue Zahlen")

func test_bonus_chips_flank_the_center_and_hold_the_payout_labels() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([300] as Array[int])
	assert_eq(hub._chips.size(), 2, "zwei Bonus-Chips")
	var lc: float = hub._chips[0].position.x + hub._chips[0].size.x * 0.5
	var rc: float = hub._chips[1].position.x + hub._chips[1].size.x * 0.5
	assert_lt(lc, hub._rim_center.x, "linker Chip links der Mitte")
	assert_gt(rc, hub._rim_center.x, "rechter Chip rechts der Mitte")
	assert_true(hub._chips[0].is_ancestor_of(hub.blind_payout_label), "Blind-Label lebt im linken Chip")
	assert_true(hub._chips[1].is_ancestor_of(hub.die_payout_label), "Würfel-Label lebt im rechten Chip")

func test_plaque_medallion_and_pips_track_level() -> void:
	var hub := _hub()
	hub.set_hub_level(3, "Lizenz", "Parkett", "Nebenwetten", 25)
	assert_eq(hub.medallion_label.text, "3", "das Medaillon zeigt die Stufe")
	assert_eq(_filled_pips(hub), 3, "genau 3 Pips gefüllt")
	hub.set_hub_level(10, "High Roller", "", "", 0)
	assert_eq(hub.medallion_label.text, "10")
	assert_eq(_filled_pips(hub), 10, "auf Maximalstufe alle Pips gefüllt")
