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
	# Drei Regale zu je drei Plätzen, auf jeder Stufe.
	for tier in [1, 2, 3, 7, 10]:
		var shop := _shop(tier)
		assert_eq(shop.charm_options.size(), 3, "Stufe %d: 3 Charms" % tier)
		assert_eq(shop.module_packs.size(), 1, "Stufe %d: 1 Modul-Paket" % tier)
		assert_eq(shop.single_dice.size(), 2, "Stufe %d: 2 Würfel" % tier)
		assert_eq(shop.engraving_packs.size() + shop.single_specials.size(), 3,
			"Stufe %d: 3 Gravuren" % tier)

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

## Seit dem Schlitz-Umbau steckt jedes Paket in seiner Kerbe und nur die offenen
## Würfel liegen in der Bucht - der Bildschirm führt allein die Charm-Karten.
func test_every_offer_has_its_own_charm_card() -> void:
	var shop := _shop(7)
	assert_eq(shop.charm_buttons.size(), shop.charm_options.size(),
		"jeder Charm im Regal ist eine Karte")
	assert_eq(shop.slit_stock().size(), shop.slit_seats().size(),
		"jedes Paket steckt in seinem Schlitz, nicht auf dem Bildschirm")
	assert_eq(shop.vitrine_stock()[ShopController.KIND_DIE].size(), shop.single_dice.size())

## Die Karte füllt ihren Platz - zwischen den Karten bleibt nur die Spaltenfuge.
func test_charm_cards_fill_their_column() -> void:
	var shop := _shop(1)
	shop.size = Vector2(1068, 1125)
	assert_almost_eq(shop._charm_card_width(), shop.column_width(), 0.01)

# --- Blind-Bühne: großer Blind + Block-Würfel ---------------------------------

func _faces(hub: HubView) -> Array:
	var out := []
	for station in hub.roadmap_row.get_children():
		out.append(station.get_node("Face"))
	return out

func _captions(hub: HubView) -> Array:
	var out := []
	for station in hub.roadmap_row.get_children():
		out.append((station.get_node("Caption") as Label).text)
	return out

func _markers(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func test_the_block_shows_one_die_face_per_round() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([150, 165, 180, 200, 220, 240] as Array[int])
	var faces := _faces(hub)
	assert_eq(faces.size(), 6)
	for i in faces.size():
		assert_eq(faces[i].value, i + 1, "Seite %d zeigt %d Augen" % [i, i + 1])

func test_the_big_number_is_the_current_blind() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([150, 165, 180, 200, 220, 240] as Array[int], 2)
	assert_eq(hub.blind_label.text, "180", "nur der laufende Blind steht groß")

func test_only_played_faces_carry_their_blind() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([150, 165, 180, 200, 220, 240] as Array[int], 2,
		_markers(["", "", "", "", "", GameRun.STRESS_MARKER]))
	assert_eq(_captions(hub), ["150", "165", " ", " ", " ", "BOSS"],
		"keine geratene Zukunft - gespielte Seiten nennen ihren Blind, die Boss-Seite sich selbst")

func test_face_states_read_apart() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([150, 165, 180, 200, 220, 240] as Array[int], 2)
	var faces := _faces(hub)
	assert_eq(faces[0].state, HubView.DieFace.DONE)
	assert_eq(faces[2].state, HubView.DieFace.CURRENT)
	assert_eq(faces[4].state, HubView.DieFace.OPEN)
	assert_gt(faces[2].custom_minimum_size.x, faces[4].custom_minimum_size.x,
		"die laufende Seite ist die größte")

func test_the_boss_face_is_red_and_explains_itself() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([150, 165, 180] as Array[int], 0,
		_markers(["", "", GameRun.STRESS_MARKER]))
	var faces := _faces(hub)
	assert_true(faces[2].boss)
	assert_almost_eq(faces[2].ring.h, ComboChipView.THROTTLE_COLOR.h, 0.02, "Boss-Seite warnrot")
	assert_eq(faces[0].mouse_filter, Control.MOUSE_FILTER_IGNORE, "gewöhnliche Seite bleibt Deko")
	assert_false(hub.marker_hint.visible)
	faces[2].mouse_entered.emit()
	assert_true(hub.marker_hint.visible)
	assert_eq(hub.marker_hint.title_label.text, GameRun.STRESS_NAME)
	assert_string_contains(hub.marker_hint.body_label.text, "Konditionen")
	faces[2].mouse_exited.emit()
	assert_false(hub.marker_hint.visible)

func test_rebuilding_the_block_drops_a_standing_hint() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([150, 165, 180] as Array[int], 0, _markers(["", GameRun.STRESS_MARKER, ""]))
	_faces(hub)[1].mouse_entered.emit()
	assert_true(hub.marker_hint.visible)
	hub.set_goal_roadmap([300, 350, 400] as Array[int], 0, _markers(["", "", ""]))
	assert_false(hub.marker_hint.visible)

func test_a_raised_blind_ticks_the_big_number() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([150, 165, 180] as Array[int], 0, _markers([]), 0)
	hub.set_goal_roadmap([200, 220, 240] as Array[int], 0, _markers([]), 0)
	assert_eq(hub.blind_label.text, "150", "die Zahl tickt erst")
	await wait_seconds(HubView.STAT_TICK_TIME + 0.1)
	assert_eq(hub.blind_label.text, "200")

func test_the_stage_stays_inside_its_bounds() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([150, 165, 180, 200, 220, 240] as Array[int], 0,
		_markers(["", "", "", "", "", GameRun.STRESS_MARKER]))
	hub.set_run_stats(165, 12, 34)
	await wait_frames(2)
	var stage := Rect2(Vector2.ZERO, hub.roadmap_stage.size)
	for c: Control in [hub.blind_label, hub.roadmap_row, hub.stat_labels[HubView.STAT_LUCK],
			hub.stat_labels[HubView.STAT_FUMBLES]]:
		var r := Rect2(c.position, c.size)
		assert_true(stage.grow(1.0).encloses(r), "%s liegt in der Bühne" % c.name)
	var luck := Rect2(hub.stat_labels[HubView.STAT_LUCK].position, hub.stat_labels[HubView.STAT_LUCK].size)
	var row := Rect2(hub.roadmap_row.position, hub.roadmap_row.size)
	assert_false(luck.intersects(row), "Glück steht unter den Seiten, nicht darauf")
	assert_gt(luck.position.y, row.end.y - 1.0, "die Lauf-Werte stehen UNTER der Reihe")
	var next: Label = hub.stat_labels[HubView.STAT_BLIND]
	assert_almost_eq(next.position.x + next.size.x * 0.5, hub.roadmap_stage.size.x * 0.5, 1.0, "die Nächster-Zeile steht mittig")

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

func test_a_quota_deal_lifts_the_current_and_every_future_station() -> void:
	# Der Aufschlag ist DAUERHAFT: die laufende Station und alle künftigen springen mit.
	var run := GameRun.new_run()
	var before := run.goal_roadmap(GameRun.GOAL_BLOCK)
	run.sign_clauses([DealClause.QUOTA_SHOCK] as Array[String])
	var after := run.goal_roadmap(GameRun.GOAL_BLOCK)
	for i in before.size():
		assert_gt(after[i], before[i], "Station %d trägt den Aufschlag" % i)

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

func test_the_roadmap_tracks_blocks_by_id_not_by_numbers() -> void:
	# Sonst gälte ein mitten im Block unterschriebener Quota-Malus als
	# frischer Block und der Fahrplan spielte die falsche Animation.
	var hub := _hub()
	await wait_frames(2)
	hub.set_goal_roadmap([150, 200, 250] as Array[int], 0, _markers([]), 0)
	hub.set_goal_roadmap([188, 250, 313] as Array[int], 0, _markers([]), 0)
	assert_eq(hub._roadmap_block, 0, "immer noch derselbe Block")
	assert_eq(hub._roadmap_goals, [188, 250, 313] as Array[int], "aber neue Zahlen")
