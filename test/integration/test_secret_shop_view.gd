extends GutTest
## Integrationstest des Schwarzmarkt-Fensters (SecretShopView an einem ECHTEN
## GameRun): die drei Karten stehen, und der Knopf-Weg bucht Kauf und Neuwurf
## über GameRun. Das Fenster misst wie am Tisch - flache Glas-Tasche unter den
## Automaten, nicht die alte Hub-Seite. Unten steht der vergitterte Zustand.

var view: SecretShopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.hub_level = GameRun.HUB_MAX_LEVEL  # volle Börse (25) - reicht für jeden Kauf
	run.unlock_secret_shop()  # Schwarzmarkt freigeschaltet
	run.charge = run.charge_cap()
	view = SecretShopView.new()
	add_child_autofree(view)
	view.size = Vector2(451, 251)  # gemessene Glas-Tasche unter den Automaten
	view.run = run
	view.set_locked(false)
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
	assert_string_contains(view.reroll_button.text, "⚡%d" % run.secret_reroll_cost(),
		"der Knopf trägt den Preis des nächsten Wurfs")

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

# --- Vergittert: der Laden steht da, aber zu -----------------------------------

## Frischer Lauf: das Fenster steht, das Gitter liegt davor.
func _barred() -> SecretShopView:
	var barred_run := GameRun.new_run()
	var barred := SecretShopView.new()
	add_child_autofree(barred)
	barred.size = Vector2(448, 345)
	barred.run = barred_run
	barred.set_locked(true)
	barred.refresh()
	return barred

func test_locked_window_names_the_condition_under_the_veil() -> void:
	var barred := _barred()
	await wait_frames(2)
	assert_true(barred.lock_overlay.visible, "der Schleier liegt über der Auslage")
	assert_string_contains(barred.lock_notice.text, str(GameRun.SECRET_UNLOCK_HUB_LEVEL))
	assert_false("unlock_button" in barred, "nichts zu kaufen: der Zutritt kommt mit der Lizenz")
	assert_eq(barred.offer_buttons.size(), 0, "vergittert ist nichts kaufbar")
	assert_false(barred.reroll_button.visible, "es gibt noch nichts zu mischen")

func test_unlocking_lifts_the_veil_and_lays_out_the_stock() -> void:
	var barred := _barred()
	await wait_frames(2)
	assert_true(barred.run.unlock_secret_shop())
	barred.set_locked(false)
	await wait_frames(2)
	assert_false(barred.lock_overlay.visible)
	assert_eq(barred.offer_buttons.size(), 3, "die Auslage liegt")
	assert_true(barred.reroll_button.visible)
