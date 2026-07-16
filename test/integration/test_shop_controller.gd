extends GutTest
## Tier-2-Integrationstests des Shops (ShopController auf shop_panel.tscn).
## Der Shop wird als eigene Szene instanziiert und mit einem ECHTEN GameRun
## verdrahtet (seit der GameRun-Extraktion braucht es kein Spiel-Double mehr,
## das die Kauflogik nachbauen müsste) - die Tests prüfen die Wirkung jedes
## Kaufs direkt am Run-Zustand (Geld, Pool, Charms) bzw. an seinen Signalen.

const ShopPanelScene := preload("res://scenes/shop_panel.tscn")

var shop
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 100
	shop = ShopPanelScene.instantiate()
	add_child_autofree(shop)  # löst _ready aus (baut Würfel-Angebot, verbindet Signale)
	shop.run = run
	shop.open()

## Anzahl Pool-Würfel, die KEIN Standardwürfel ("normal") sind - also gekaufte
## Spezialwürfel (jedes Angebot vergibt nicht-"normale" style_ids, siehe DiceOffer).
func _count_special() -> int:
	var count := 0
	for def in run.owned_pool:
		if def.style_id != "normal":
			count += 1
	return count

# --- Angebot ------------------------------------------------------------------

func test_open_shows_panel_and_offers_up_to_two_charms():
	assert_true(shop.visible)
	assert_gt(shop.charm_options.size(), 0, "mindestens ein Charm im Angebot")
	assert_true(shop.charm_options.size() <= 2, "höchstens zwei Charms")

func test_offer_excludes_already_owned_charms():
	run.owned_charms.append(Charm.rabbits_foot())
	shop.open()
	for charm in shop.charm_options:
		assert_ne(charm.id, Charm.RABBITS_FOOT, "besessener Charm nicht erneut angeboten")

func test_open_rolls_three_dice_offers():
	assert_eq(shop.dice_offers.size(), 3, "drei Würfel-Angebote je Besuch")
	for offer in shop.dice_offers:
		assert_between(offer.size(), 1, 3, "je Angebot 1..3 Würfel")

# --- Würfelkauf ---------------------------------------------------------------

func test_buy_offer_deducts_its_price_and_adds_its_dice():
	var offer = shop.dice_offers[0]
	shop._on_offer_pressed(0)
	assert_eq(run.money, 100 - offer.price)
	assert_eq(run.owned_pool.size(), GameRun.POOL_SIZE, "Pool bleibt konstant groß")
	assert_eq(_count_special(), offer.size(), "das ganze Bündel liegt jetzt im Pool")

func test_offers_are_repeatable():
	var first = shop.dice_offers[0]
	var second = shop.dice_offers[1]
	shop._on_offer_pressed(0)
	shop._on_offer_pressed(1)
	assert_eq(run.money, 100 - first.price - second.price)
	assert_eq(_count_special(), first.size() + second.size())

func test_cannot_buy_offer_without_funds():
	run.money = 3  # unter jedem Angebotspreis
	shop._on_offer_pressed(0)
	assert_eq(run.money, 3, "kein Abzug bei zu wenig Geld")
	assert_eq(_count_special(), 0, "kein Würfel in den Pool gelegt")

func test_con_artist_cuff_discounts_offer_price():
	run.owned_charms.append(Charm.con_artist_cuff())
	shop.open()
	var offer = shop.dice_offers[0]
	shop._on_offer_pressed(0)
	assert_eq(run.money, 100 - CharmEffects.die_price(offer.price, run.charm_ids(), offer.size()), "33% Rabatt auf den Angebotspreis")

func test_offer_price_is_raw_price_without_discount():
	var offer = shop.dice_offers[0]
	assert_eq(shop._offer_price(offer), offer.price, "ohne Rabatt-Charm der volle Preis")

func test_offer_buttons_disabled_by_price():
	run.money = 5  # unter jedem Angebotspreis (≥ $15)
	shop.open()
	for button in shop.offer_buy_buttons:
		assert_true(button.disabled, "Würfel-Angebot bei zu wenig Geld nicht kaufbar")

# --- Charmkauf ----------------------------------------------------------------

func test_buy_charm_grants_and_deducts():
	var charm = shop.charm_options[0]
	shop._on_charm_clicked(0)
	assert_eq(run.money, 85)  # 100 - 15
	assert_eq(run.owned_charms.size(), 1)
	# owned_charm_ids statt charm_ids: Totems lösen sich in charm_ids() zu
	# ihren Nachbarn auf - der Test war sonst flaky, wenn ein Totem gezogen wurde.
	assert_true(run.owned_charm_ids().has(charm.id))

func test_charm_cannot_be_bought_twice():
	shop._on_charm_clicked(0)
	var money_after_first: int = run.money
	shop._on_charm_clicked(0)  # schon gekauft
	assert_eq(run.money, money_after_first, "zweiter Klick zieht nichts weiter ab")
	assert_eq(run.owned_charms.size(), 1)

func test_charm_buttons_disabled_when_broke():
	run.money = 10
	shop.open()  # neu bestücken mit wenig Geld
	for button in shop.charm_buttons:
		assert_true(button.disabled, "Charm bei zu wenig Geld nicht kaufbar")

# --- Coupon-Packs ---------------------------------------------------------------

## Sammelt die kinds aller sheet_purchased-Signale ein (siehe GameRun) - die
## Enthüllung selbst zeigt im echten Spiel scene_root, hier zählt nur das Signal.
func _capture_sheet_kinds() -> Array:
	var kinds: Array = []
	run.sheet_purchased.connect(func(_sheet: CouponSheet, kind: int) -> void: kinds.append(kind))
	return kinds

## Erzwingt ein bestimmtes Pack-Sortiment auf der aktuellen Doppelseite (das echte
## ist zufällig, siehe _build_spread) und setzt die "vergriffen"-Marken zurück, um
## einen bestimmten Pack-Typ gezielt kaufen zu können. Die _on_sheet_pressed-Aufrufe
## adressieren danach die Angebote per Index in dieser Reihenfolge.
func _force_pack_offers(offers: Array) -> void:
	var spread = shop.spreads[shop.current_spread_index]
	var typed: Array[Vector2i] = []
	typed.assign(offers)
	spread.pack_offers = typed
	spread.pack_bought.resize(typed.size())
	spread.pack_bought.fill(false)
	shop._show_spread()

func test_buy_general_snippet_deducts_price_and_emits_sheet():
	var kinds := _capture_sheet_kinds()
	_force_pack_offers([Vector2i(0, 0)])  # Coupon-Heft 2×2, $6
	shop._on_sheet_pressed(0)
	assert_eq(run.money, 94)  # 100 - 6
	assert_eq(kinds, [CouponSheet.Kind.SNIPPET])

func test_pack_offer_is_single_use():
	# Jedes Pack-Angebot lässt sich nur EINMAL kaufen; der zweite Klick prallt ab
	# und die Karte ist danach "vergriffen".
	var kinds := _capture_sheet_kinds()
	_force_pack_offers([Vector2i(0, 0)])  # Coupon-Heft 2×2, $6
	shop._on_sheet_pressed(0)
	shop._on_sheet_pressed(0)  # zweiter Kauf desselben Angebots
	assert_eq(run.money, 94, "nur einmal abgezogen")
	assert_eq(kinds, [CouponSheet.Kind.SNIPPET], "nur ein Bogen ausgewürfelt")
	assert_true(shop.sheet_buttons[0].disabled, "Karte ist danach vergriffen")
	assert_true(shop.pack_bought[0], "als gekauft vermerkt")

func test_cannot_buy_pack_without_funds():
	var kinds := _capture_sheet_kinds()
	run.money = 3
	_force_pack_offers([Vector2i(0, 2)])  # Coupon-Heft 5×5, $16
	shop._on_sheet_pressed(0)
	assert_eq(run.money, 3, "kein Abzug bei zu wenig Geld")
	assert_eq(kinds.size(), 0, "kein Bogen ausgewürfelt")

func test_pack_buttons_disabled_by_price():
	# Das Sortiment ist zufällig - erwartete Preise daher aus den Angeboten der
	# Seite (pack_offers) abgeleitet statt über feste Button-Indizes.
	run.money = 8
	shop.open()
	assert_eq(shop.sheet_buttons.size(), shop.pack_offers.size())
	for i in shop.pack_offers.size():
		var offer: Vector2i = shop.pack_offers[i]
		var price: int = ShopController.PACKS[offer.x]["prices"][offer.y]
		assert_eq(shop.sheet_buttons[i].disabled, run.money < price,
			"Kaufbarkeit von %s (%s)" % [ShopController.PACKS[offer.x]["name"], ShopController.PACK_SIZES[offer.y]["label"]])

func test_spread_offers_distinct_packs():
	# PACK_OFFER_COUNT aus den 12 möglichen Sorte-×-Größe-Kombinationen, ohne Doppelte.
	assert_eq(shop.pack_offers.size(), ShopController.PACK_OFFER_COUNT)
	var seen := {}
	for offer in shop.pack_offers:
		assert_true(offer.x >= 0 and offer.x < ShopController.PACKS.size(), "gültige Pack-Sorte")
		assert_true(offer.y >= 0 and offer.y < ShopController.PACK_SIZES.size(), "gültige Größe")
		assert_false(seen.has(offer), "doppeltes Angebot %s" % offer)
		seen[offer] = true

func test_pack_offers_persist_when_flipping_back():
	var first_offers: Array[Vector2i] = shop.pack_offers.duplicate()
	shop._on_page_next_pressed()  # neue Doppelseite (kostet Gebühr)
	shop._on_page_back_pressed()
	assert_eq(shop.pack_offers, first_offers, "zurückgeblättert = dasselbe Sortiment")

func test_specialized_pack_only_contains_its_kinds():
	# Tageskarte (nur Gerichte) und Juwelier-Katalog (nur Veredelungen): jeder
	# echte Coupon des gekauften Bogens trägt eine erlaubte Art.
	var sheets: Array = []
	run.sheet_purchased.connect(func(sheet: CouponSheet, _kind: int) -> void: sheets.append(sheet))
	run.money = 1000
	for i in 5:
		# Jedes Angebot ist einmalig - je Generation das Sortiment neu erzwingen.
		_force_pack_offers([Vector2i(3, 2), Vector2i(2, 2)])  # Tageskarte, Juwelier (5×5)
		shop._on_sheet_pressed(0)  # Tageskarte 5×5
		shop._on_sheet_pressed(1)  # Juwelier-Katalog 5×5
	for s in sheets.size():
		var expected: Array = [Coupon.KIND_MEAL] if s % 2 == 0 else [Coupon.KIND_MATERIAL, Coupon.KIND_EDGE]
		for tile in sheets[s].tiles:
			if tile.kind == CouponSheet.TileKind.ETCHING:
				assert_true(expected.has(tile.coupon.kind),
					"%s gehört nicht in dieses Pack" % tile.coupon.id)

func test_general_pack_is_cheaper_than_specialized():
	for size_index in ShopController.PACK_SIZES.size():
		var general_price: int = ShopController.PACKS[0]["prices"][size_index]
		for pack_index in range(1, ShopController.PACKS.size()):
			assert_gt(int(ShopController.PACKS[pack_index]["prices"][size_index]), general_price,
				"%s teurer als das gemischte Heft" % ShopController.PACKS[pack_index]["name"])

func test_every_pack_has_a_price_per_size():
	# Fünf Bogengrößen (2×2..9×9) - jede Preisliste muss genauso lang sein,
	# und größere Bögen kosten strikt mehr.
	assert_eq(ShopController.PACK_SIZES.size(), 5)
	for pack in ShopController.PACKS:
		var prices: Array = pack["prices"]
		assert_eq(prices.size(), ShopController.PACK_SIZES.size(),
			"Preisliste von %s deckt alle Größen ab" % pack["id"])
		for i in range(1, prices.size()):
			assert_gt(int(prices[i]), int(prices[i - 1]),
				"%s: Größe %d teurer als %d" % [pack["id"], i, i - 1])

# --- Rabatt-Charms im Shop (Skonto, Wechselgeld, Feinschmecker, Mengenrabatt) ----

## Zwingt bestimmte Charms als Angebot auf die aktuelle Doppelseite (das echte
## Angebot ist zufällig) - für Tests, die einen Shop-Charm IM Besuch kaufen.
func _force_charm_options(charms: Array) -> void:
	var spread = shop.spreads[shop.current_spread_index]
	var typed: Array[Charm] = []
	typed.assign(charms)
	spread.charm_options = typed
	var bought: Array[bool] = []
	bought.resize(typed.size())
	bought.fill(false)
	spread.charm_bought = bought
	shop._show_spread()

func test_discount_charm_applies_within_the_same_visit():
	# Schnäppchenjäger IM Shop kaufen: alle Pack-Preisschilder (und die
	# Kaufbarkeits-Schwellen, siehe sheet_button_prices) rabattieren sofort -
	# nicht erst beim nächsten Besuch.
	_force_charm_options([Charm.bargain_hunter()])
	var before: Array[int] = shop.sheet_button_prices.duplicate()
	shop._on_charm_clicked(0)
	assert_eq(shop.sheet_button_prices.size(), before.size(), "Sortiment bleibt dasselbe")
	for i in before.size():
		assert_eq(shop.sheet_button_prices[i], maxi(1, before[i] - 2),
			"Pack-Preis %d sofort $2 günstiger" % i)

func test_cash_discount_lowers_the_second_charm_in_the_same_visit():
	# Skonto kaufen ($15), danach kostet der zweite Charm sofort $10.
	_force_charm_options([Charm.cash_discount(), Charm.rabbits_foot()])
	shop._on_charm_clicked(0)
	assert_eq(run.money, 85, "Skonto selbst kostet den vollen Preis")
	shop._on_charm_clicked(1)
	assert_eq(run.money, 75, "der nächste Charm kostet im selben Besuch $10")
	assert_true(shop.charm_bought[0] and shop.charm_bought[1], "beide als gekauft vermerkt")

func test_cash_discount_lowers_charm_price():
	run.owned_charms.append(Charm.cash_discount())
	shop.open()  # Seite mit Rabatt neu bestücken
	run.money = 100
	if shop.charm_options.is_empty():
		pass_test("keine Charm-Angebote auf dieser Seite ausgewürfelt")
		return
	shop._on_charm_clicked(0)
	assert_eq(run.money, 90, "Skonto: $10 statt $15")

func test_small_change_lowers_flip_fee():
	run.owned_charms.append(Charm.small_change())
	run.money = 100
	shop.open()
	shop._on_page_next_pressed()
	assert_eq(run.money, 99, "Blätter-Gebühr $1 statt $2")

func test_gourmet_halves_tageskarte_packs():
	run.owned_charms.append(Charm.gourmet())
	run.money = 100
	# Tageskarte ist Pack-Index 3 (siehe ShopController.PACKS); Größe 3×3 kostet
	# normal $13 - mit Feinschmecker $7.
	_force_pack_offers([Vector2i(3, 1)])
	shop._on_sheet_pressed(0)
	assert_eq(run.money, 93)

func test_bulk_discount_only_hits_triple_bundles():
	run.owned_charms.append(Charm.bulk_discount())
	for offer in shop.dice_offers:
		var expected: int = offer.price - 5 if offer.size() >= 3 else offer.price
		assert_eq(shop._offer_price(offer), maxi(1, expected))

func test_every_pack_has_valid_kinds():
	var known := [Coupon.KIND_ETCHING, Coupon.KIND_MATERIAL, Coupon.KIND_EDGE, Coupon.KIND_MEAL]
	for pack in ShopController.PACKS:
		for kind in pack["kinds"]:
			assert_true(known.has(kind), "unbekannter kind %s in %s" % [kind, pack["id"]])

# --- Kaufbarkeit bei Geldänderung (Chip-Coupons o.ä.) --------------------------
# Der Shop hört auf run.money_changed: steigt das Geld, während der Shop offen
# ist (z.B. durch die Chip-Coupons der Bogen-Abschluss-Animation), werden zuvor
# gesperrte Käufe SOFORT wieder freigeschaltet - ohne dass der Shop neu öffnet.

func test_money_gain_re_enables_offer_buttons():
	run.money = 5
	assert_true(shop.offer_buy_buttons[0].disabled, "erst gesperrt")
	run.add_money(50)
	assert_false(shop.offer_buy_buttons[0].disabled, "nach Geldzuwachs wieder kaufbar")

func test_money_gain_re_enables_flip_corner():
	run.money = 1  # unter der Blätter-Gebühr ($2)
	assert_true(shop.page_next_button.disabled, "Umblättern erst gesperrt")
	run.add_money(10)
	assert_false(shop.page_next_button.disabled, "nach Geldzuwachs wieder umblätterbar")

# --- Blättern (Menü-Seiten) -----------------------------------------------------

func test_open_starts_on_first_spread():
	assert_eq(shop.spreads.size(), 1, "eine Doppelseite beim Öffnen")
	assert_eq(shop.current_spread_index, 0)

func test_flip_to_new_page_charges_increasing_fee():
	shop._on_page_next_pressed()  # neue Seite: -$2
	assert_eq(run.money, 98)
	assert_eq(shop.spreads.size(), 2)
	assert_eq(shop.current_spread_index, 1)
	shop._on_page_next_pressed()  # nächste neue Seite: -$3
	assert_eq(run.money, 95)
	assert_eq(shop.spreads.size(), 3)

func test_flip_back_is_free_and_shows_same_offers():
	var first_offers = shop.dice_offers
	shop._on_page_next_pressed()  # -$2
	var second_offers = shop.dice_offers
	shop._on_page_back_pressed()
	assert_eq(run.money, 98, "Zurückblättern kostet nichts")
	assert_true(shop.dice_offers == first_offers, "dieselben Angebote wie zuvor (gleiche Instanz)")
	shop._on_page_next_pressed()  # vor auf BEREITS gesehene Seite
	assert_eq(run.money, 98, "Vorblättern auf bekannte Seite kostet nichts")
	assert_true(shop.dice_offers == second_offers)
	assert_eq(shop.spreads.size(), 2, "keine neue Seite ausgewürfelt")

func test_cannot_flip_to_new_page_without_money():
	run.money = 1
	shop._on_page_next_pressed()
	assert_eq(run.money, 1, "keine Gebühr abgezogen")
	assert_eq(shop.spreads.size(), 1, "keine neue Seite")
	assert_eq(shop.current_spread_index, 0)

func test_fee_resets_on_reopen():
	shop._on_page_next_pressed()  # -$2
	shop._on_done_pressed()
	shop.open()
	assert_eq(shop.spreads.size(), 1, "frisches Menü beim nächsten Besuch")
	shop._on_page_next_pressed()
	assert_eq(run.money, 96, "Gebühr beginnt wieder bei $2 (100 - 2 - 2)")

func test_charm_bought_stays_bought_after_flipping():
	shop._on_charm_clicked(0)  # -$15 auf Seite 1
	var money_after := run.money
	shop._on_page_next_pressed()  # -$2, neue Seite
	shop._on_page_back_pressed()  # zurück zu Seite 1
	assert_true(shop.charm_bought[0], "Kauf bleibt auf der Seite vermerkt")
	shop._on_charm_clicked(0)  # erneuter Klick darf nichts abziehen
	assert_eq(run.money, money_after - 2, "nur die Blätter-Gebühr, kein Doppelkauf")

func test_bought_charm_not_offered_on_next_new_spread():
	var bought_id = shop.charm_options[0].id
	shop._on_charm_clicked(0)  # jetzt besessen
	shop._on_page_next_pressed()  # frische Doppelseite
	for charm in shop.charm_options:
		assert_ne(charm.id, bought_id, "besessener Charm nicht auf der neuen Seite")

# --- Blätter-Ecken (Navigation auf den Seiten) --------------------------------

func test_back_corner_disabled_on_first_spread():
	assert_true(shop.page_back_button.disabled, "auf Seite 1 kein Zurückblättern")
	shop._on_page_next_pressed()  # neue Doppelseite
	assert_false(shop.page_back_button.disabled, "ab Seite 2 zurückblätterbar")

func test_next_corner_shows_increasing_flip_fee():
	assert_true("$2" in shop.page_next_button.text, "Blätter-Ecke zeigt die fällige Gebühr")
	shop._on_page_next_pressed()  # jetzt letzte Seite; nächste NEUE kostet $3
	assert_true("$3" in shop.page_next_button.text)

func test_next_corner_is_free_on_already_seen_page():
	shop._on_page_next_pressed()  # -$2, neue Seite 2
	shop._on_page_back_pressed()  # zurück auf Seite 1
	assert_false(shop.page_next_button.disabled, "Vor auf bekannte Seite immer möglich")
	assert_false("$" in shop.page_next_button.text, "keine Gebühr für eine bereits gesehene Seite")

# --- Abschluss ----------------------------------------------------------------

func test_done_hides_panel_and_emits_closed():
	watch_signals(shop)
	shop._on_done_pressed()
	assert_false(shop.visible)
	assert_signal_emitted(shop, "closed")
