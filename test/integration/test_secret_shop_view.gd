extends GutTest
## Integrationstest des Schwarzmarkts (SecretShopView an einem ECHTEN GameRun):
## die drei Karten stehen, und der Knopf-Weg bucht Kauf und Neuwurf über GameRun.

var view: SecretShopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.hub_level = GameRun.HUB_MAX_LEVEL  # Börse fasst 15 - reicht für jeden Kauf
	run.note_round_stages(GameRun.OVERCHARGE_STAGES)  # Schwarzmarkt entdeckt
	run.charge = GameRun.CHARGE_CAP_HIGH_ROLLER
	view = SecretShopView.new()
	add_child_autofree(view)
	view.size = Vector2(1400, 700)
	view.run = run
	view.open()

func test_open_shows_three_offer_cards() -> void:
	await wait_frames(2)
	assert_true(view.visible)
	assert_eq(view.offer_buttons.size(), 3, "drei Plätze")
	for button in view.offer_buttons:
		assert_gt(button.get_global_rect().size.x, 0.0, "jede Karte hat Fläche")

func test_wallet_shows_charge_and_cap() -> void:
	await wait_frames(2)
	assert_eq(view.wallet_label.text, "⚡ 15/15")

func test_buying_a_charm_through_the_card_books_it() -> void:
	await wait_frames(2)
	var charm: Charm = run.secret_stock[0][GameRun.OFFER_ITEM]
	var price: int = run.secret_stock[0][GameRun.OFFER_PRICE]
	var before := run.charge
	view.offer_buttons[0].pressed.emit()
	assert_eq(run.charge, before - price, "in Ladung bezahlt")
	assert_true(run.owned_charm_ids().has(charm.id), "Charm im Dock")
	assert_true(bool(run.secret_stock[0][GameRun.OFFER_SOLD]))

func test_sold_slot_becomes_a_dead_placeholder() -> void:
	await wait_frames(2)
	view.offer_buttons[1].pressed.emit()
	await wait_frames(2)
	assert_eq(run.owned_engravings.size(), 1, "Gravur im Vorrat")
	assert_true(view.offer_buttons[1].disabled, "der verkaufte Platz ist tot")

func test_reroll_button_swaps_the_whole_stock() -> void:
	await wait_frames(2)
	var before: Resource = run.secret_stock[0][GameRun.OFFER_ITEM]
	var cost := run.secret_reroll_cost()
	var charge_before := run.charge
	view.reroll_button.pressed.emit()
	await wait_frames(2)
	assert_eq(run.charge, charge_before - cost)
	assert_eq(run.secret_rerolls, 1)
	var after: Resource = run.secret_stock[0][GameRun.OFFER_ITEM]
	assert_ne(after, before, "frisch gewürfelte Auslage")
	assert_eq(view.offer_buttons.size(), 3, "die Karten stehen neu")

func test_reroll_is_disabled_without_charge() -> void:
	run.charge = 0
	await wait_frames(2)
	assert_true(view.reroll_button.disabled)
	for button in view.offer_buttons:
		assert_true(button.disabled, "ohne Ladung ist nichts kaufbar")

func test_close_hides_the_page() -> void:
	await wait_frames(2)
	view.close_button.pressed.emit()
	assert_false(view.visible, "der Hub holt Home von selbst zurück")
