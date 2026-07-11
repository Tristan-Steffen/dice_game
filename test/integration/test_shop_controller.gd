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
	assert_eq(run.money, 100 - int(round(offer.price * 0.8)), "20% Rabatt auf den Angebotspreis")

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
	assert_eq(run.money, 75)  # 100 - 25
	assert_eq(run.owned_charms.size(), 1)
	assert_true(run.charm_ids().has(charm.id))

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

# --- Coupon-Bögen -------------------------------------------------------------

## Sammelt die kinds aller sheet_purchased-Signale ein (siehe GameRun) - die
## Enthüllung selbst zeigt im echten Spiel scene_root, hier zählt nur das Signal.
func _capture_sheet_kinds() -> Array:
	var kinds: Array = []
	run.sheet_purchased.connect(func(_sheet: CouponSheet, kind: int) -> void: kinds.append(kind))
	return kinds

func test_buy_snippet_sheet_deducts_price_and_emits_sheet():
	var kinds := _capture_sheet_kinds()
	shop._on_sheet_pressed(0)  # Schnipsel, $6
	assert_eq(run.money, 94)  # 100 - 6
	assert_eq(kinds, [CouponSheet.Kind.SNIPPET])

func test_sheets_are_repeatable():
	var kinds := _capture_sheet_kinds()
	shop._on_sheet_pressed(0)  # -6
	shop._on_sheet_pressed(1)  # Bogen -10
	assert_eq(run.money, 84)  # 100 - 6 - 10
	assert_eq(kinds, [CouponSheet.Kind.SNIPPET, CouponSheet.Kind.SHEET])

func test_cannot_buy_sheet_without_funds():
	var kinds := _capture_sheet_kinds()
	run.money = 3
	shop._on_sheet_pressed(2)  # Großbogen, $16
	assert_eq(run.money, 3, "kein Abzug bei zu wenig Geld")
	assert_eq(kinds.size(), 0, "kein Bogen ausgewürfelt")

func test_sheet_buttons_disabled_by_price():
	run.money = 8  # reicht für Schnipsel ($6), nicht für Bogen ($10)/Großbogen ($16)
	shop.open()
	assert_false(shop.sheet_buttons[0].disabled, "Schnipsel leistbar")
	assert_true(shop.sheet_buttons[1].disabled, "Bogen zu teuer")
	assert_true(shop.sheet_buttons[2].disabled, "Großbogen zu teuer")

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
	shop._on_charm_clicked(0)  # -$25 auf Seite 1
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
