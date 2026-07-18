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
	assert_true(shop.charm_options.size() <= 3, "Stufe 1: höchstens 3 Charms")
	assert_eq(shop.dice_offers.size(), 2, "Stufe 1: 2 Würfel-Bündel")
	assert_eq(shop.overclock_offers.size(), 1, "Stufe 1: 1 Übertaktung")

func test_level_one_hides_flip_navigation() -> void:
	var shop := _shop(1)
	assert_false(shop.page_next_button.visible, "Stufe 1: kein Vorblättern")
	assert_false(shop.page_back_button.visible)
	assert_true(shop.flip_hint_label.visible, "stattdessen der Hinweis")

func test_level_two_unlocks_flipping_and_third_dice() -> void:
	var shop := _shop(2)
	assert_eq(shop.dice_offers.size(), 3, "Stufe 2: 3 Würfel-Bündel")
	assert_true(shop.page_next_button.visible, "Stufe 2: Blättern frei")

func test_level_three_restores_full_grid() -> void:
	var shop := _shop(3)
	assert_true(shop.charm_options.size() <= 4 and shop.charm_options.size() >= 1)
	assert_eq(shop.overclock_offers.size(), 2, "Stufe 3: 2 Übertaktungen (voller Shop)")

func test_level_six_spread_contains_a_non_common_charm() -> void:
	# Über mehrere Läufe stabil: der erste Platz ist garantiert nicht-gewöhnlich.
	var shop := _shop(6)
	var has_premium := false
	for charm in shop.charm_options:
		if charm.rarity != Charm.RARITY_COMMON:
			has_premium = true
	assert_true(has_premium, "VIP-Lounge garantiert einen besseren Charm")
