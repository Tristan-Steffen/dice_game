extends GutTest
## Integrationstest des Schwarzmarkt-Fensters (SecretShopView an einem ECHTEN
## GameRun). Aufgeteilt wie der Laden: Kopfstreifen und der feste KARTEN-SITZ mit
## genau EINER Charm-Karte bleiben Bildschirm, die Ware meldet das Fenster nur als
## Buchten-Rechteck plus Inhalt - aufgestellt wird sie von scene_root. Das Fenster
## misst wie am Tisch (flache Glas-Tasche unter den Automaten). Unten steht der
## vergitterte Zustand.

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

## Die eine Karte am Sitz (null = der legendäre Topf war erschöpft).
func _card() -> Button:
	var seat := view.card_slot_index()
	return null if seat < 0 else view.offer_buttons[seat]

func _live_buttons() -> Array[Button]:
	var live: Array[Button] = []
	for button in view.offer_buttons:
		if button != null:
			live.append(button)
	return live

# --- Der Karten-Sitz ------------------------------------------------------------

func test_exactly_one_card_sits_on_the_seat() -> void:
	await wait_frames(2)
	assert_eq(view.offer_buttons.size(), run.secret_stock.size(),
		"die Plätze bleiben index-treu, auch wo kein Knopf steht")
	assert_eq(_live_buttons().size(), 1, "genau EINE Karte - der Rest liegt in der Bucht")
	assert_eq(view.card_slot_index(), 0, "und sie sitzt auf dem legendären Platz")
	assert_gt(_card().get_global_rect().size.x, 0.0, "die Karte hat Fläche")

func test_the_seat_carries_the_legendary_charm() -> void:
	await wait_frames(2)
	assert_eq(run.secret_stock[view.card_slot_index()][GameRun.OFFER_KIND],
		GameRun.KIND_CHARM, "Lizenzen sind digitale Ware und bleiben Bildschirm")

## Die Tasche ist flach: der Inhalt muss IN das Fenster passen, sonst schneidet
## der Rahmen ihn ab.
func test_content_fits_the_flat_window() -> void:
	await wait_frames(2)
	var window: Rect2 = view.get_global_rect()
	assert_lt(_card().get_global_rect().end.y, window.end.y + 1.0,
		"die Karte ragt unten nicht heraus")
	assert_lt(view.reroll_button.get_global_rect().end.y, window.end.y + 1.0,
		"der Misch-Knopf steht im Fenster")
	assert_lt(view.reroll_button.get_global_rect().end.x, window.end.x + 1.0,
		"und er wird nicht aus dem Kopfstreifen geschoben")

func test_wallet_shows_charge_and_cap() -> void:
	await wait_frames(2)
	assert_eq(view.wallet_label.text, "⚡ %d/%d" % [run.charge, run.charge_cap()])

func test_buying_a_charm_through_the_card_books_it() -> void:
	await wait_frames(2)
	var seat := view.card_slot_index()
	var charm: Charm = run.secret_stock[seat][GameRun.OFFER_ITEM]
	var price: int = run.secret_stock[seat][GameRun.OFFER_PRICE]
	var before := run.charge
	_card().pressed.emit()
	assert_eq(run.charge, before - price, "in Ladung bezahlt")
	assert_true(run.owned_charm_ids().has(charm.id), "Charm im Dock")
	assert_true(bool(run.secret_stock[seat][GameRun.OFFER_SOLD]))

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
	assert_eq(_live_buttons().size(), 1, "der Sitz trägt wieder genau eine Karte")
	assert_string_contains(view.reroll_button.text, "⚡%d" % run.secret_reroll_cost(),
		"der Knopf trägt den Preis des nächsten Wurfs")

func test_reroll_is_disabled_without_charge() -> void:
	run.charge = 0
	await wait_frames(2)
	assert_true(view.reroll_button.disabled)
	for button in _live_buttons():
		assert_true(button.disabled, "ohne Ladung ist nichts kaufbar")

## Das Fenster kennt keinen Schließen-Knopf mehr - zurück geht es per Rechtsklick
## über die Kamera, wie bei jedem anderen Tisch-Fenster.
func test_window_has_no_close_button() -> void:
	await wait_frames(2)
	assert_false("close_button" in view, "Schließen macht die Kamera, nicht das Fenster")

# --- Die Bucht: gemeldete Geometrie, nie gezeichneter Inhalt --------------------

func test_the_market_reports_a_vitrine_rect() -> void:
	await wait_frames(2)
	var bay: Rect2 = view.vitrine_rect_px()
	assert_gt(bay.size.x, 0.0, "die Bucht hat eine Breite")
	assert_gt(bay.size.y, 0.0, "und eine Höhe")
	assert_true(view.get_global_rect().encloses(bay), "sie liegt ganz im Fenster")
	assert_gt(bay.position.x, view.card_seat.get_global_rect().end.x - 1.0,
		"und rechts neben dem Karten-Sitz")

func test_the_vitrine_hole_sits_inside_its_frame() -> void:
	await wait_frames(2)
	var bay: Rect2 = view.vitrine_rect_px()
	var hole: Rect2 = view.vitrine_pit_rect()
	assert_true(bay.encloses(hole), "das Loch liegt im Rahmen")
	assert_almost_eq(hole.position.x - bay.position.x,
		PackDrawerView.rim_inset(view.u), 0.51, "links um die Fassung eingerückt")
	assert_almost_eq(bay.end.y - hole.end.y,
		PackDrawerView.rim_inset(view.u), 0.51, "unten ebenso")

## Die Beschriftung misst in der EINHEIT DES FENSTERS - die Tasche ist die
## kleinste des Tisches, und die Buchtbreite allein schriebe dort Matsch.
func test_the_annotation_uses_the_window_unit() -> void:
	await wait_frames(2)
	assert_almost_eq(view.vitrine_unit(), view.u, 0.0001)
	assert_gt(view.vitrine_unit(), view.vitrine_rect_px().size.x / 100.0,
		"größer als eine an der Bucht hängende Einheit")

func test_the_stock_maps_every_slot_to_its_body() -> void:
	await wait_frames(2)
	var stock: Dictionary = view.vitrine_stock()
	var packs: Array = stock[ShopController.KIND_ENGRAVING_PACK]
	var dice: Array = stock[ShopController.KIND_DIE]
	assert_eq(packs.size(), run.secret_stock.size(), "je Auslage-Platz ein Regalplatz")
	assert_eq(dice.size(), run.secret_stock.size(), "und ein Schalenplatz")
	for i in run.secret_stock.size():
		var kind := String(run.secret_stock[i][GameRun.OFFER_KIND])
		if kind == GameRun.KIND_CHARM:
			assert_null(packs[i], "die Karte liegt nicht in der Bucht")
			assert_null(dice[i], "die Karte liegt nicht in der Bucht")
		elif kind == GameRun.KIND_DIE:
			assert_null(packs[i], "ein Würfel steht nicht versiegelt")
			assert_not_null(dice[i], "er liegt offen in der Schale")
		else:
			assert_not_null(packs[i], "Sonderbestand steht als versiegelte Kassette")
			assert_eq(Pack.shelf_of(packs[i]), Pack.SHELF_SPECIAL)
			assert_null(dice[i])

func test_a_bought_slot_stays_as_an_empty_place() -> void:
	await wait_frames(2)
	view.buy_offer(1)
	await wait_frames(2)
	assert_eq(run.owned_packs.size(), 1, "Ware versiegelt im Magazin")
	var stock: Dictionary = view.vitrine_stock()
	assert_eq(stock[ShopController.KIND_ENGRAVING_PACK].size(), run.secret_stock.size(),
		"der Platz verschwindet nicht, er wird leer")
	assert_null(stock[ShopController.KIND_ENGRAVING_PACK][1])
	assert_null(stock[ShopController.KIND_DIE][1])

func test_a_purchase_reports_the_pack_it_booked() -> void:
	await wait_frames(2)
	var seen: Array[int] = []
	view.goods_purchased.connect(func(uid: int) -> void: seen.append(uid))
	view.buy_offer(1)
	assert_eq(seen.size(), 1, "genau eine Meldung")
	assert_eq(seen[0], run.owned_packs.back().pack_uid, "und sie meint dieses Paket")

func test_a_charm_purchase_reports_no_goods() -> void:
	await wait_frames(2)
	var seen: Array[int] = []
	view.goods_purchased.connect(func(uid: int) -> void: seen.append(uid))
	_card().pressed.emit()
	assert_eq(seen.size(), 0, "eine Lizenz fährt nicht ins Magazin")

# --- Die Beschriftung auf der Scheibe -------------------------------------------

func test_the_annotation_prices_in_charge() -> void:
	await wait_frames(2)
	var data: Dictionary = view.vitrine_annotation(ShopController.KIND_ENGRAVING_PACK, 1)
	assert_true(bool(data["charge"]), "das Hinterzimmer zahlt in Energie")
	assert_eq(int(data["price"]), run.secret_offer_price(run.secret_stock[1]))
	assert_eq(int(data["money"]), run.charge, "kaufbar heißt hier: die Börse deckt es")
	assert_ne(String(data["title"]), "", "ein Stück ohne Namen wäre keins")

func test_a_full_magazine_shows_on_the_annotation() -> void:
	await wait_frames(2)
	run.set_pack_capacity(1)
	run.owned_packs.append(Pack.number_pack())  # Magazin voll
	var data: Dictionary = view.vitrine_annotation(ShopController.KIND_ENGRAVING_PACK, 1)
	assert_eq(String(data["blocked"]), ShopController.FULL_TAG,
		"volles Magazin steht statt des Preises")

func test_an_essence_die_carries_its_net_and_its_soul() -> void:
	var die := DiceOffer.make_die(DiceOffer.TEMPLATES[0])
	die.essence_id = Essence.RADON
	run.secret_stock[2] = {
		GameRun.OFFER_KIND: GameRun.KIND_DIE, GameRun.OFFER_ITEM: die,
		GameRun.OFFER_PRICE: 6, GameRun.OFFER_COUNT: 1, GameRun.OFFER_SOLD: false,
	}
	view.refresh()
	await wait_frames(2)
	var data: Dictionary = view.vitrine_annotation(ShopController.KIND_DIE, 2)
	assert_eq(data["net"], die, "der Würfel zeigt sein volles Netz")
	assert_string_contains(String(data["title"]), Essence.by_id(Essence.RADON).display_name)

func test_a_sold_slot_has_nothing_to_say() -> void:
	await wait_frames(2)
	view.buy_offer(1)
	assert_true(view.vitrine_annotation(ShopController.KIND_ENGRAVING_PACK, 1).is_empty(),
		"ein leerer Platz beschriftet sich nicht")

# --- Die Ankunfts-Grade ---------------------------------------------------------

func test_a_fresh_stock_rolls_its_goods_in() -> void:
	# Der ERSTE Bericht einer frisch gewürfelten Auslage rollt sie an; ein zweiter
	# Bericht derselben Ware lässt sie liegen - scene_root sammelt den lauteren
	# Grad, solange die Bucht noch zugedeckt ist.
	var barred := _barred()
	await wait_frames(2)
	var grades: Array[String] = []
	barred.vitrine_changed.connect(func() -> void: grades.append(barred.vitrine_grade()))
	assert_true(barred.run.unlock_secret_shop())
	barred.set_locked(false)
	assert_gt(grades.size(), 0, "die neue Auslage meldet sich")
	assert_eq(grades[0], ShopController.GRADE_ROLL_IN, "die erste Auslage rollt an")
	barred.refresh()
	assert_eq(barred.vitrine_grade(), ShopController.GRADE_STAND,
		"dieselbe Ware ein zweites Mal gemeldet wurde nicht neu gewürfelt")

func test_a_purchase_leaves_the_rest_lying() -> void:
	await wait_frames(2)
	view.buy_offer(1)
	assert_eq(view.vitrine_grade(), ShopController.GRADE_STAND,
		"ein Kauf würfelt nichts - die übrige Ware bleibt liegen")

func test_a_reroll_rolls_in_again() -> void:
	await wait_frames(2)
	view.buy_offer(1)
	assert_eq(view.vitrine_grade(), ShopController.GRADE_STAND)
	assert_true(run.reroll_secret_stock())
	await wait_frames(2)
	assert_eq(view.vitrine_grade(), ShopController.GRADE_ROLL_IN,
		"ein Neuwurf ist ein voller Warenumschlag")

func test_every_change_of_the_bay_is_reported() -> void:
	await wait_frames(2)
	var beats := []
	view.vitrine_changed.connect(func() -> void: beats.append(1))
	view.buy_offer(1)
	assert_gt(beats.size(), 0, "der Kauf meldet die neue Auslage")
	beats.clear()
	assert_true(run.reroll_secret_stock())
	assert_gt(beats.size(), 0, "und der Neuwurf auch")

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

func test_a_locked_market_keeps_its_bay_empty() -> void:
	var barred := _barred()
	await wait_frames(2)
	var stock: Dictionary = barred.vitrine_stock()
	assert_eq(stock[ShopController.KIND_ENGRAVING_PACK].size(), 0,
		"vergittert liegt keine Ware in der Bucht")
	assert_eq(stock[ShopController.KIND_DIE].size(), 0)
	assert_eq(barred.card_slot_index(), -1, "und keine Karte auf dem Sitz")

func test_unlocking_lifts_the_veil_and_lays_out_the_stock() -> void:
	var barred := _barred()
	await wait_frames(2)
	assert_true(barred.run.unlock_secret_shop())
	barred.set_locked(false)
	await wait_frames(2)
	assert_false(barred.lock_overlay.visible)
	assert_eq(barred.offer_buttons.size(), 3, "die Plätze liegen index-treu")
	assert_eq(barred.card_slot_index(), 0, "und der Sitz trägt seine Karte")
	assert_true(barred.reroll_button.visible)
	assert_eq(barred.vitrine_grade(), ShopController.GRADE_ROLL_IN,
		"die erste Auslage rollt an")
