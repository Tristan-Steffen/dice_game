extends GutTest
## Integrationstest des Schwarzmarkt-Fensters (SecretShopView an einem ECHTEN
## GameRun): die drei Karten stehen, und der Knopf-Weg bucht Kauf und Neuwurf
## über GameRun. Das Fenster misst wie am Tisch - flache Glas-Tasche unter den
## Automaten, nicht die alte Hub-Seite.

var view: SecretShopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.hub_level = GameRun.HUB_MAX_LEVEL  # volle Börse (25) - reicht für jeden Kauf
	run.note_round_stages(run.overcharge_frame())  # Schwarzmarkt entdeckt
	run.charge = run.charge_cap()
	view = SecretShopView.new()
	add_child_autofree(view)
	view.size = Vector2(448, 345)
	view.run = run
	view.refresh()

func test_window_shows_three_offer_cards() -> void:
	await wait_frames(2)
	assert_eq(view.offer_buttons.size(), 3, "drei Plätze")
	for button in view.offer_buttons:
		assert_gt(button.get_global_rect().size.x, 0.0, "jede Karte hat Fläche")

## Die Tasche ist flach: der Inhalt muss IN das Fenster passen, sonst schneidet
## der Rahmen die Karten ab.
func test_content_fits_the_flat_window() -> void:
	await wait_frames(2)
	for button in view.offer_buttons:
		assert_lt(button.get_global_rect().end.y, view.get_global_rect().end.y + 1.0,
			"keine Karte ragt unten heraus")
	assert_lt(view.reroll_button.get_global_rect().end.y, view.get_global_rect().end.y + 1.0,
		"der Misch-Knopf steht im Fenster")

func test_wallet_shows_charge_and_cap() -> void:
	await wait_frames(2)
	assert_eq(view.wallet_label.text, "⚡ %d/%d" % [run.charge, run.charge_cap()])

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

## Das Fenster kennt keinen Schließen-Knopf mehr - zurück geht es per Rechtsklick
## über die Kamera, wie bei jedem anderen Tisch-Fenster.
func test_window_has_no_close_button() -> void:
	await wait_frames(2)
	assert_false("close_button" in view, "Schließen macht die Kamera, nicht das Fenster")
