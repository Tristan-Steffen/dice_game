extends GutTest
## Integrationstests der Fortschrittsstufe über die Ansichten: HubView-Plakette +
## Rahmen-Stufe, TableScreen.set_side_bet_installed (Fenster + Fork), und der
## Laden, der mit der Stufe wächst.

# --- HubView-Plakette ----------------------------------------------------------

func _hub() -> HubView:
	var hub: HubView = add_child_autofree(HubView.new())
	hub.size = Vector2(1068, 1125)  # das Maß des echten Hubs
	hub.layout()
	return hub

func test_hub_frame_thickens_with_the_tier() -> void:
	var hub := _hub()
	hub.set_progress_tier(1)
	var thin: int = hub._frame_style.border_width_left
	hub.set_progress_tier(10)
	var thick: int = hub._frame_style.border_width_left
	assert_gt(thick, thin, "höhere Stufe -> dickerer Rahmen")

func test_hub_frame_recolors_per_tier() -> void:
	var hub := _hub()
	hub.set_progress_tier(1)
	var low: Color = hub._frame_style.border_color
	hub.set_progress_tier(6)
	var high: Color = hub._frame_style.border_color
	assert_ne(low, high, "jede Stufe hat eine eigene Signaturfarbe")

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

func test_side_bet_window_always_visible() -> void:
	var ts := _screen()
	# Das Fenster steht immer.
	assert_true(ts.side_bet_window.visible, "Fenster immer sichtbar")
	ts.set_side_bet_installed(false)
	assert_true(ts.side_bet_window.visible, "auch nach false bleibt es sichtbar")

func test_side_bet_fork_always_present() -> void:
	var ts := _screen()
	# Der Fork liegt immer, weil das Fenster immer sichtbar ist.
	assert_true(ts.treasure_strip.branch_path.size() >= 2, "Fork immer vorhanden")

# --- Der Laden wächst mit der Stufe (ShopController) ---------------------------

const ShopPanelScene := preload("res://scenes/shop_panel.tscn")

func _shop(tier: int) -> ShopController:
	var run := GameRun.new_run()
	run.money = 999
	run.luck = (tier - 1) * GameRun.LUCK_PER_TIER
	var shop: ShopController = ShopPanelScene.instantiate()
	add_child_autofree(shop)
	shop.run = run
	shop.open()
	return shop

func test_every_tier_lays_out_three_of_each() -> void:
	# Drei Charms und sechs Paket-Plätze, auf jeder Stufe.
	for tier in [1, 2, 3, 7, 10]:
		var shop := _shop(tier)
		assert_eq(shop.charm_options.size(), 3, "Stufe %d: 3 Charms" % tier)
		assert_eq(shop.packs.size(), 6, "Stufe %d: 6 Pakete" % tier)

func test_flipping_is_open_from_round_one() -> void:
	var shop := _shop(1)
	assert_true(shop.page_next_button.visible, "Stufe 1: Blättern frei")
	assert_false(shop.page_next_button.disabled, "und bezahlbar")
	assert_string_contains(shop.page_next_button.text, "›")

func test_tier_six_spread_contains_a_non_common_charm() -> void:
	# Über mehrere Läufe stabil: der erste Platz ist garantiert nicht-gewöhnlich.
	var shop := _shop(6)
	var has_premium := false
	for charm in shop.charm_options:
		if charm.rarity != Charm.RARITY_COMMON:
			has_premium = true
	assert_true(has_premium, "Stufe 6 garantiert einen besseren Charm")

# --- Elastisches Layout (wenige, große Karten -> viele, kleine) --------------

## Jedes Paket liegt körperlich auf seinem Platz - der Bildschirm führt allein die
## Charm-Karten.
func test_every_offer_has_its_own_charm_card() -> void:
	var shop := _shop(7)
	assert_eq(shop.charm_buttons.size(), shop.charm_options.size(),
		"jeder Charm im Regal ist eine Karte")
	assert_eq(shop.place_stock().size(), shop.place_count(),
		"jedes Paket liegt auf seinem Platz, nicht auf dem Bildschirm")

## Die Karte füllt ihren Platz - zwischen den Karten bleibt nur die Spaltenfuge.
func test_charm_cards_fill_their_column() -> void:
	var shop := _shop(1)
	shop.size = Vector2(1068, 1125)
	assert_almost_eq(shop._charm_card_width(), shop.column_width(), 0.01)

# --- Startseite: die Etagen-Karte samt Lauf-Anzeigen ---------------------------

func test_the_floor_map_stands_on_the_start_page() -> void:
	var hub := _hub()
	await wait_frames(2)
	var run := GameRun.new_run()
	hub.set_floor_state(run.floor_view_state())
	await wait_frames(2)
	assert_true(hub.floor_map.is_visible_in_tree(), "die Karte steht auf der Startseite")
	assert_eq((hub.floor_map.get_node("Head") as Label).text, "Etage 1 · Eingang")
	assert_eq((hub.floor_map.get_node("HeadBlind") as Label).text,
		FloorMapView.BLIND_HEAD % run.effective_goal())
	assert_gt(hub.floor_map.size.y, hub.roadmap_stage.size.y * 0.6, "die Karte ist der Hauptteil")

func test_before_the_move_the_head_names_the_next_blind() -> void:
	var hub := _hub()
	await wait_frames(2)
	var run := GameRun.new_run()
	run.advance_round()
	hub.set_floor_state(run.floor_view_state())
	hub.set_run_stats(run.next_blind(), 0, 0, {}, 12)
	assert_eq((hub.floor_map.get_node("HeadBlind") as Label).text,
		FloorMapView.NEXT_BLIND_HEAD % run.next_blind(), "nie der alte als laufend")
	assert_eq((hub.stat_labels[HubView.STAT_BLIND] as Label).text, "Zug 1: +12 %")

func test_a_due_move_is_clickable_from_afar_only_on_a_walkable_room() -> void:
	var hub := _hub()
	await wait_frames(2)
	var run := GameRun.new_run()
	hub.set_floor_state(run.floor_view_state())
	await wait_frames(2)
	var map := hub.floor_map
	var origin := map.get_global_rect().position
	for room_id in run.floor_map.room_ids():
		assert_eq(hub.floor_move_at(origin + map.room_rect(room_id).get_center()), "",
			"Runde 1: kein Zug fällig")
	run.advance_round()
	hub.set_floor_state(run.floor_view_state())
	var door_id := String(run.walkable_doors()[0])
	var target := run.floor_map.other_side(run.floor_map.door(door_id), run.floor_map.position)
	assert_eq(hub.floor_move_at(origin + map.room_rect(target).get_center()), door_id)
	hub.set_floor_moves_enabled(false)
	assert_eq(hub.floor_move_at(origin + map.room_rect(target).get_center()), "")

func test_the_stage_stays_inside_its_bounds() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_floor_state(GameRun.new_run().floor_view_state())
	hub.set_run_stats(165, 12, 34)
	await wait_frames(2)
	var stage := Rect2(Vector2.ZERO, hub.roadmap_stage.size)
	var map := Rect2(hub.floor_map.position, hub.floor_map.size)
	assert_true(hub.get_global_rect().encloses(hub.floor_map.get_global_rect()),
		"die Karte greift höchstens in den Seitenrand")
	assert_true(map.position.y >= 0.0 and map.end.y <= stage.size.y, "und liegt der Höhe nach in der Bühne")
	for key: String in [HubView.STAT_BLIND, HubView.STAT_LUCK, HubView.STAT_FUMBLES]:
		var c: Control = hub.stat_labels[key]
		var r := Rect2(c.position, c.size)
		assert_true(stage.grow(1.0).encloses(r), "%s liegt in der Bühne" % c.name)
		assert_false(r.intersects(map), "%s steht unter der Karte, nicht darauf" % c.name)

func test_the_etage_button_shows_the_map_and_leads_back() -> void:
	var hub := _hub()
	var shop: ShopController = ShopPanelScene.instantiate()
	hub.attach_panel(shop)
	var run := GameRun.new_run()
	run.money = 999
	shop.run = run
	shop.open()
	var page := FloorMapPage.new()
	hub.attach_panel(page)
	page.layout()
	# Die Verdrahtung von scene_root: der Knopf blättert auf, „Zurück“ blättert heim.
	shop.floor_requested.connect(func() -> void:
		page.show_state(run.floor_view_state())
		page.visible = true)
	page.close_requested.connect(func() -> void: page.visible = false)
	await wait_frames(2)
	assert_true(shop.visible)
	shop.floor_button.pressed.emit()
	assert_true(page.visible, "die Karte steht")
	assert_false(shop.visible, "die Ladenseite ist verdrängt - ihre Ware weicht mit")
	assert_true(page.map_view.read_only, "im Laden nur ansehen")
	assert_true(page.map_view.walkable_doors().is_empty())
	page.back_button.pressed.emit()
	assert_false(page.visible)
	assert_true(shop.visible, "die Seitenregel holt den Laden zurück")
	assert_false(hub.content_root.visible, "nicht die Startseite")

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

func test_a_quota_deal_lifts_the_current_and_the_next_blind() -> void:
	# Der Aufschlag ist DAUERHAFT: der laufende und der nächste Blind springen mit.
	var run := GameRun.new_run()
	var now := run.effective_goal()
	var next := run.next_blind()
	run.sign_clauses([DealClause.QUOTA_SHOCK] as Array[String])
	assert_gt(run.effective_goal(), now)
	assert_gt(run.next_blind(), next)

func test_the_run_stats_tick_and_carry_their_hints() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_run_stats(300, 4, 7, {HubView.STAT_LUCK: "Stufe 2."})
	var label: Label = hub.stat_labels[HubView.STAT_BLIND]
	assert_eq(label.text, "nächster 300", "der erste Stand steht sofort")
	hub.set_run_stats(300, 4, 7, {}, 10)
	assert_eq(label.text, "nächster 300  (+10 %)", "sie nennt das Wachstum der Kurve, nicht den gerundeten Sprung")
	assert_eq((hub.stat_labels[HubView.STAT_LUCK] as Label).text, "Glück 4")
	assert_eq((hub.stat_labels[HubView.STAT_FUMBLES] as Label).text, "Fumbles 7")
	assert_eq(hub._stat_hints[HubView.STAT_LUCK], "Stufe 2.")
	hub.set_run_stats(300, 4, 9)
	assert_eq((hub.stat_labels[HubView.STAT_FUMBLES] as Label).text, "Fumbles 7", "die Zahl tickt erst")
	await wait_seconds(HubView.STAT_TICK_TIME + 0.1)
	assert_eq((hub.stat_labels[HubView.STAT_FUMBLES] as Label).text, "Fumbles 9")
