extends GutTest
## Das Schwarzmarkt-Fenster seit den SCHUBFÄCHERN (2026-11-26): es malt nichts, MELDET die
## Teile in Stations-Einheiten und je Fach Name, Preis und Zustand; unsichtbare Knöpfe über
## Fach und Neuwurf-Taste tragen den Klick. Gemessen an einem ECHTEN GameRun.

var view: SecretShopView
var run: GameRun

func after_all() -> void:
	GameRun.secret_projector_chance = GameRun.SECRET_PROJECTOR_CHANCE
	GameRun.secret_powerbank_chance = GameRun.SECRET_POWERBANK_CHANCE

func before_each() -> void:
	GameRun.secret_projector_chance = 0.0
	GameRun.secret_powerbank_chance = 0.0
	run = GameRun.new_run()
	run.luck = (GameRun.TIER_MAX - 1) * GameRun.LUCK_PER_TIER
	run.storage_rows = 4
	run.energy = run.energy_cap()
	view = SecretShopView.new()
	add_child_autofree(view)
	view.size = SecretShopView.UNITS * 37.5  # die Welt-Maße am Tisch
	view.run = run
	view.refresh()

# --- Rechtecke ------------------------------------------------------------------------

func test_the_unit_is_one_world_unit_at_the_table() -> void:
	assert_almost_eq(view.unit(), 37.5, 0.001, "die Teile stehen in Welt-Maßen")

## Nur die Kontaktleiste liegt rechts daneben auf dem Deck, auf halber Höhe: dort mündet die Ader.
func test_every_part_lies_inside_the_footprint() -> void:
	var frame := Rect2(Vector2.ZERO, view.size).grow(0.01)
	for key: String in SecretShopView.PARTS:
		if key == "contacts":
			continue
		assert_true(frame.encloses(view.part_rect(key)), "%s liegt im Grundriß" % key)
	var contacts := view.part_rect("contacts")
	assert_gte(contacts.position.x, frame.end.x - 0.02, "die Kontaktleiste liegt rechts daneben")
	assert_almost_eq(contacts.get_center().y, view.size.y * 0.5, 0.5, "auf halber Höhe")

func test_the_rects_are_stable_through_every_state() -> void:
	var before := view.layout()
	view.buy_offer(0)
	run.reroll_secret_offer(1)
	view.refresh()
	assert_eq(view.layout(), before, "kein Zustand verschiebt ein Teil")

func test_three_equal_bays_side_by_side_under_the_housing() -> void:
	var housing := view.part_rect("housing")
	for i in SecretShopView.BAYS:
		var bay := view.bay_rect(i)
		assert_eq(bay.size, view.bay_rect(0).size, "gleich groß")
		assert_almost_eq(bay.position.y, housing.end.y, 0.01, "es fährt aus der Gehäusefront")
		assert_almost_eq(view.nose_rect(i).position.y, bay.end.y, 0.01, "die Nase vorn daran")
		if i > 0:
			assert_false(bay.intersects(view.bay_rect(i - 1)), "Fächer berühren sich nicht")

## EINE Größe je Ding: der größte Körper liegt ganz im Fach, nichts wird skaliert.
func test_the_largest_ware_fits_a_bay() -> void:
	var inner := SecretShopView.BAY_INNER
	var reader := CharmReaderView.local_bounds()
	assert_lte(reader.size.z, inner.x, "der Projektor quer")
	assert_lte(reader.size.x, inner.y, "und längs")
	assert_lte(CharmDiskView.SIZE.z, inner.x, "die Diskette quer")
	assert_lte(CharmDiskView.SIZE.x, inner.y, "und längs")

# --- Fach und Angebot -----------------------------------------------------------------

func test_bay_i_carries_offer_i() -> void:
	for i in run.secret_stock.size():
		var state := view.bay_state(i)
		assert_eq(String(state["kind"]), String(run.secret_stock[i][GameRun.OFFER_KIND]))
		assert_true(bool(state["open"]), "unverkauft steht es offen")
		assert_eq(String(state["price"]), str(run.secret_offer_price(run.secret_stock[i])))
	assert_eq(String(view.bay_state(0)["name"]), (run.secret_stock[0][GameRun.OFFER_ITEM] as Charm).display_name)

func test_a_click_on_the_bay_button_buys() -> void:
	var charms := run.owned_charms.size()
	var order: Array[String] = []
	view.offer_buying.connect(func(i: int) -> void: order.append("fach%d" % i))
	view.charm_buying.connect(func() -> void: order.append("charm"))
	view.bay_buttons[0].pressed.emit()
	assert_eq(run.owned_charms.size(), charms + 1, "gebucht über GameRun")
	assert_eq(order, ["fach0", "charm"], "erst das Fach, dann die Diskette - beides vor der Buchung")
	assert_false(view.bay_open(0), "verkauft fährt es ein")
	assert_eq(String(view.bay_state(0)["state"]), SecretShopView.STATE_SOLD)
	assert_eq(String(view.bay_state(0)["name"]), SecretShopView.SOLD_NAME)

func test_the_buttons_cover_tray_and_nose() -> void:
	for i in SecretShopView.BAYS:
		var button := view.bay_buttons[i]
		assert_eq(Rect2(button.position, button.size), view.bay_hit_rect(i))
		var key := view.reroll_buttons[i]
		assert_eq(Rect2(key.position, key.size), view.reroll_rect(i))
		assert_true(view.nose_rect(i).encloses(view.reroll_rect(i)), "die Taste sitzt auf der Nase")
		assert_gt(key.get_index(), button.get_index(), "sie liegt über dem Fach-Knopf")

func test_too_dear_dims_and_disables() -> void:
	run.energy = 0
	view.refresh()
	for i in run.secret_stock.size():
		assert_eq(String(view.bay_state(i)["state"]), SecretShopView.STATE_DEAR)
		assert_true(view.bay_buttons[i].disabled)
		assert_true(view.reroll_buttons[i].disabled, "auch die Taste")
		assert_false(bool(view.reroll_state(i)["afford"]))

func test_a_purchase_reports_its_goods() -> void:
	run.secret_stock[1] = run._secret_engraving_offer()
	var reported: Array = []
	view.goods_purchased.connect(func(uids: Array[int]) -> void: reported.append(uids))
	view.buy_offer(1)
	assert_eq(reported.size(), 1, "die Karte reist als Licht ins Magazin")

func test_a_die_offer_reports_the_die_and_its_net() -> void:
	run.secret_stock[2] = run._secret_die_offer()
	var info := view.bay_info(2)
	assert_eq(info["net"], run.secret_stock[2][GameRun.OFFER_ITEM], "das INFO-DISPLAY zeigt sein Netz")
	var bought: Array = []
	view.die_purchased.connect(func(def: DieDefinition) -> void: bought.append(def))
	view.buy_offer(2)
	assert_eq(bought.size(), 1)

func test_a_projector_offer_takes_one_bay() -> void:
	GameRun.secret_projector_chance = 1.0
	run._roll_secret_stock()
	GameRun.secret_projector_chance = 0.0
	assert_eq(run.secret_stock.size(), 3)
	assert_eq(String(view.bay_state(1)["kind"]), GameRun.KIND_PROJECTOR)
	assert_true(view.bay_open(2), "das dritte Fach trägt seine Ware")
	var order: Array[String] = []
	view.projector_buying.connect(func() -> void: order.append("projektor"))
	view.buy_offer(1)
	assert_eq(order, ["projektor"], "der Körper fliegt vor der Buchung")
	assert_eq(run.projectors, GameRun.START_PROJECTORS + 1)

func test_a_powerbank_reports_its_bay() -> void:
	GameRun.secret_powerbank_chance = 1.0
	run._roll_secret_stock()
	GameRun.secret_powerbank_chance = 0.0
	var bay := -1
	for i in run.secret_stock.size():
		if run.secret_stock[i][GameRun.OFFER_KIND] == GameRun.KIND_POWERBANK:
			bay = i
	assert_gt(bay, -1, "eine Powerbank liegt aus")
	var from: Array = []
	view.powerbank_purchased.connect(func(px: Vector2) -> void: from.append(px))
	view.buy_offer(bay)
	assert_eq(from.size(), 1)
	assert_true(Rect2(view.position + view.bay_rect(bay).position, view.bay_rect(bay).size).has_point(from[0]),
		"sie fliegt aus ihrem Fach")

func test_a_sold_bay_says_nothing_and_takes_no_pointer() -> void:
	view.buy_offer(0)
	assert_eq(view.bay_info(0), {})
	assert_eq(view.bay_at(view.bay_rect(0).get_center()), -1, "eingefahren ist dort nichts")
	assert_eq(view.bay_at(view.bay_rect(1).get_center()), 1)

func test_a_reroll_key_swaps_only_its_bay_and_reports_energy() -> void:
	var before := run.secret_stock.duplicate()
	var spent: Array = []
	view.energy_spent.connect(func(amount: int) -> void: spent.append(amount))
	view.reroll_buttons[2].pressed.emit()
	assert_eq(spent, [GameRun.SECRET_REROLL_BASE])
	assert_ne(run.secret_stock[2], before[2], "Fach 2 ist neu")
	assert_same(run.secret_stock[0], before[0], "die übrigen bleiben")
	assert_same(run.secret_stock[1], before[1])

## Eingefahren steht die Taste eine Fachtiefe weiter oben - dort, wo die Nase dann ist.
func test_the_key_of_a_sold_bay_rides_in_with_the_nose_and_restocks() -> void:
	var open_key := view.reroll_rect(0)
	view.buy_offer(0)
	var closed_key := view.reroll_rect(0)
	assert_almost_eq(open_key.position.y - closed_key.position.y, view.bay_rect(0).size.y, 0.01)
	assert_eq(Rect2(view.reroll_buttons[0].position, view.reroll_buttons[0].size), closed_key,
		"der Knopf folgt ihr")
	view.reroll_buttons[0].pressed.emit()
	assert_true(view.bay_open(0), "der verkaufte Platz ist neu bestückt")
	assert_eq(view.reroll_rect(0), open_key)

func test_a_full_dock_blocks_the_charm_bay() -> void:
	while not run.charms_full():
		run.owned_charms.append(Charm.rabbits_foot())
	assert_eq(String(view.bay_state(0)["state"]), SecretShopView.STATE_BLOCKED)
	assert_ne(SecretShopView.blocked_tag(GameRun.KIND_CHARM), "")

func test_the_window_paints_nothing() -> void:
	for child in view.get_children():
		assert_true(child is Button, "nur unsichtbare Knöpfe")
		for style in ["normal", "hover", "pressed", "disabled"]:
			assert_true((child as Button).get_theme_stylebox(style) is StyleBoxEmpty)
