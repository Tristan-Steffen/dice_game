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

# --- Startseite: Turm-Streifen, Blind, Auskunft, Laufwerte, Diagramm ---------------

## Eine Liste Laufwerte wie die von scene_root, mit n Einträgen.
func _values(count: int) -> Array:
	var out := []
	for i in count:
		out.append({"key": "v%d" % i, "title": "Wert %d" % i, "text": BigNumber.short(1000 * (i + 1)),
			"sub": "Zusatz", "color": Color.WHITE, "hint": "Hinweis %d." % i})
	return out

func test_the_plan_strip_stands_on_the_start_page() -> void:
	var hub := _hub()
	await wait_frames(2)
	var run := GameRun.new_run()
	hub.set_floor_state(run.floor_view_state())
	await wait_frames(2)
	assert_true(hub.floor_plan.is_visible_in_tree(), "der Streifen steht auf der Startseite")
	assert_eq(hub.floor_plan.mode, FloorPlanView.Mode.COMPACT, "der ganze Umriß, ohne Text")
	assert_null(hub.find_child("OpenMapButton", true, false), "„Karte öffnen“ ist gestorben")
	assert_lt(hub.floor_plan.size.x, hub.roadmap_stage.size.x * 0.45, "rund ein Drittel der Breite")
	assert_almost_eq(hub.floor_plan.size.y, hub.roadmap_stage.size.y, 0.5)
	assert_eq(hub.blind_title.text, HubView.NEXT_BLIND_TITLE, "auch Runde 1 wartet auf ihren Zug")
	assert_eq(hub.blind_value.text, BigNumber.short(run.next_blind()))

func test_before_the_move_the_blind_card_names_the_next_blind() -> void:
	var hub := _hub()
	await wait_frames(2)
	var run := GameRun.new_run()
	run.advance_round()
	hub.set_floor_state(run.floor_view_state())
	assert_eq(hub.blind_title.text, HubView.NEXT_BLIND_TITLE)
	assert_eq(hub.blind_value.text, BigNumber.short(run.next_blind()), "nie der alte als laufend")
	assert_eq(hub.blind_step.text, "Zug 1: +10 %")

func test_the_office_names_the_boss_round() -> void:
	var hub := _hub()
	await wait_frames(2)
	var state := GameRun.new_run().floor_view_state()
	state["boss_round"] = true
	state["due"] = false
	hub.set_floor_state(state)
	assert_eq(hub.blind_title.text, HubView.BOSS_TITLE)
	assert_eq(hub.blind_title.modulate, HubView.BOSS_COLOR)

## Der Streifen ist reine Übersicht: auch ein fälliger Zug nimmt hier keinen Klick.
func test_the_strip_takes_no_move_and_opens_nothing() -> void:
	var hub := _hub()
	await wait_frames(2)
	var run := GameRun.new_run()
	hub.set_floor_state(run.floor_view_state())
	hub.set_floor_moves_enabled(true)
	await wait_frames(2)
	var chosen: Array[Dictionary] = []
	hub.floor_plan.move_chosen.connect(func(move: Dictionary) -> void: chosen.append(move))
	var map := hub.floor_plan
	var target := String(run.walkable_moves()[0]["room"])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = map.geometry().room_rect(target).get_center()
	map._gui_input(click)
	click = click.duplicate()
	click.pressed = false
	map._gui_input(click)
	assert_true(chosen.is_empty(), "gezogen wird in der Grube")
	assert_false(hub.has_signal("map_requested"), "kein Öffnen der großen Karte mehr")
	assert_false(hub.has_method("floor_move_at"))

func test_the_stage_parts_never_overlap() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_floor_state(GameRun.new_run().floor_view_state())
	hub.set_run_values(_values(6))
	await wait_frames(2)
	var rects := hub.stage_rects()
	var keys := rects.keys()
	var hub_rect := Rect2(Vector2.ZERO, hub.size)
	for i in keys.size():
		var a: Rect2 = rects[keys[i]]
		assert_gt(a.size.y, 10.0, "%s hat Höhe" % keys[i])
		var global := Rect2(hub.roadmap_stage.get_global_rect().position - hub.get_global_rect().position
			+ a.position, a.size)
		assert_true(hub_rect.encloses(global), "%s liegt im Hub" % keys[i])
		for j in range(i + 1, keys.size()):
			assert_false(a.intersects(rects[keys[j]]), "%s überdeckt %s" % [keys[i], keys[j]])
	assert_true((rects["chart"] as Rect2).size.y > hub.size.x / 100.0 * 15.0, "das Diagramm hat Platz")

func test_the_info_follows_the_strip_and_rests_without_a_pointer() -> void:
	var hub := _hub()
	await wait_frames(2)
	var run := GameRun.new_run()
	hub.set_floor_state(run.floor_view_state())
	assert_string_contains(hub.info_text(), FloorPlanView.IDLE_TITLE, "ein Zug ist fällig")
	assert_string_contains(hub.info_text(), "Gewählt wird in der Grube.")
	var move: Dictionary = run.walkable_moves()[0]
	var target := String(move["room"])
	var rect := hub.floor_plan.geometry().room_rect(target)
	var at := rect.get_center()
	if hub.floor_plan.geometry().door_at(at) != "":
		at = rect.position + rect.size * 0.3
	hub.floor_plan.hover_at(at)
	var bonus := String(run.floor_plan.rooms[target]["bonus"])
	assert_string_contains(hub.info_text(), DealClause.text_for(bonus), "voller Klausel-Text")
	assert_string_contains(hub.info_text(), "Blind ")
	hub.floor_plan.clear_hover()
	assert_string_contains(hub.info_text(), FloorPlanView.IDLE_TITLE, "der Zeiger ist fort")
	run.move_to(move)
	hub.set_floor_state(run.floor_view_state())
	assert_string_contains(hub.info_text(), "Du bist hier")
	assert_eq(hub.info_text().find("Polster"), -1)

func test_the_values_grid_carries_round_average_and_key_card() -> void:
	var hub := _hub()
	await wait_frames(2)
	var values := _values(4)
	values.append({"key": HubView.STAT_AVERAGE, "title": HubView.AVERAGE_TITLE, "text": "300",
		"sub": "Blind 290", "color": Color.WHITE, "hint": "Mittel."})
	values.append({"key": HubView.STAT_KEY, "title": HubView.KEY_TITLE, "text": "fehlt",
		"sub": "Büro verschlossen", "color": Color.WHITE, "hint": "Karte."})
	hub.set_run_values(values)
	await wait_frames(1)
	assert_eq(HubView.AVERAGE_TITLE, "Rundenschnitt")
	assert_eq(HubView.KEY_TITLE, "Schlüsselkarte")
	assert_not_null(hub.values_grid.tile(HubView.STAT_AVERAGE))
	assert_not_null(hub.values_grid.tile(HubView.STAT_KEY))

func test_the_values_grid_takes_any_number_of_entries() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_run_values(_values(6))
	await wait_frames(1)
	var grid := hub.values_grid
	assert_eq(grid.entries.size(), 6)
	assert_eq(grid.max_scroll(), 0.0, "sechs passen")
	var a := grid.tile_rect(0)
	for i in range(1, 6):
		assert_eq(grid.tile_rect(i).size, a.size, "gleich große Kacheln")
		assert_false(grid.tile_rect(i).intersects(grid.tile_rect(i - 1)))
	hub.set_run_values(_values(7))
	assert_not_null(grid.tile("v6"), "ein weiterer Wert ist ein weiterer Eintrag")
	assert_gt(grid.max_scroll(), 0.0, "über zwei Reihen rollt das Raster")
	var pixel := grid.get_global_rect().get_center()
	assert_true(hub.wheel_at(pixel, false))
	assert_gt(grid.scroll, 0.0)
	assert_eq(((grid.tile("v0") as Panel).get_node("Value") as Label).text, BigNumber.short(1000))

func test_a_tile_explains_itself_on_hover() -> void:
	var hub := _hub()
	await wait_frames(2)
	hub.set_run_values(_values(2))
	(hub.values_grid.tile("v1") as Panel).mouse_entered.emit()
	assert_true(hub.marker_hint.visible)
	assert_eq(hub.marker_hint.title_label.text, "Wert 1")
	assert_string_contains(hub.marker_hint.body_label.text, "Hinweis 1.")

func test_the_wheel_rolls_the_strip() -> void:
	var hub := _hub()
	await wait_frames(2)
	var run := GameRun.new_run()
	# Flache Etagen passen zu dritt in den Streifen: so viele stapeln, bis er überläuft.
	for i in 12:
		run.settle_block_deals()
		hub.set_floor_state(run.floor_view_state())
		await wait_frames(2)
		if hub.floor_plan.stack_height() > hub.floor_plan.size.y + 20.0:
			break
	assert_eq(hub.floor_plan.scroll, 0.0)
	assert_true(hub.wheel_at(hub.floor_plan.get_global_rect().get_center(), false))
	assert_gt(hub.floor_plan.scroll, 0.0, "das Rad rollt den Stapel in die Geschichte")
	assert_false(hub.wheel_at(Vector2(-50, -50), true), "daneben verbraucht es nichts")

func test_the_chart_with_zero_one_and_twelve_rounds() -> void:
	var hub := _hub()
	await wait_frames(2)
	var chart := hub.chart
	var run := GameRun.new_run()
	hub.set_chart(run.run_chart())
	assert_true(chart.is_empty_state(), "Noch keine Runde beendet")
	run.round_points = 300
	run.advance_round()
	hub.set_chart(run.run_chart())
	assert_false(chart.is_empty_state())
	assert_eq(chart.shown_count(), 2, "eine Runde und der laufende Blind")
	var blinds := []
	var scores := []
	for i in 14:
		blinds.append(int(150.0 * pow(3.0, i)))
		scores.append(int(400.0 * pow(3.2, i)))
	blinds.append(int(150.0 * pow(3.0, 14)))
	hub.set_chart({"blinds": blinds, "scores": scores})
	assert_eq(chart.shown_count(), RunChartView.SHOWN_ROUNDS, "die letzten zwölf")
	var dec := chart.decade_range()
	assert_lte(pow(10.0, dec.x), float(scores[chart.first_shown()]), "die Achse schließt alles ein")
	assert_gte(pow(10.0, dec.y), float(blinds[-1]))
	var low := chart.point_at(chart.first_shown(), float(blinds[chart.first_shown()]))
	var high := chart.point_at(blinds.size() - 1, float(blinds[-1]))
	assert_gt(low.y, high.y, "logarithmisch nach oben")
	assert_true(chart.plot_rect().grow(1.0).has_point(high))

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
	assert_eq(page.map_view.mode, FloorPlanView.Mode.DETAIL, "dieselbe Nahsicht wie in der Grube")
	assert_true(page.map_view.read_only, "im Laden nur ansehen")
	assert_eq(page.back_button.text, FloorMapPage.BACK_SHOP_TEXT)
	assert_true(page.map_view.walkable_moves().is_empty())
	page.back_button.pressed.emit()
	assert_false(page.visible)
	assert_true(shop.visible, "die Seitenregel holt den Laden zurück")
	assert_false(hub.content_root.visible, "nicht die Startseite")

## Die Laden-Seite zieht nie, auch wenn ein Zug fällig wäre - Ziehen und Rad sehen sich um.
func test_the_shop_page_only_looks() -> void:
	var hub := _hub()
	var page := FloorMapPage.new()
	hub.attach_panel(page)
	page.layout()
	var run := GameRun.new_run()
	page.show_state(run.floor_view_state())
	page.visible = true
	await wait_frames(2)
	var map := page.map_view
	var chosen: Array[Dictionary] = []
	map.move_chosen.connect(func(move: Dictionary) -> void: chosen.append(move))
	var at := map.geometry().room_rect(String(run.walkable_moves()[0]["room"])).get_center()
	map.begin_press(at)
	map.end_press(at)
	assert_true(chosen.is_empty(), "nur ansehen")
	var home := map.view_center()
	map.begin_press(at)
	map.drag_to(at + Vector2(60, 60))
	map.end_press(at + Vector2(60, 60))
	assert_true(map.away_from_home() or map.view_center() == home, "ziehen sieht sich um")
	map.snap_home(true)
	var cell := map.zoom_cell()
	assert_true(page.wheel_at(map.get_global_rect().get_center(), false), "das Rad zoomt")
	assert_lt(map.zoom_cell(), cell)

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

