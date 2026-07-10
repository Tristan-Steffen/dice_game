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

## Anzahl Pool-Würfel mit der gegebenen style_id (Spezialwürfel-Zählung).
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

# --- Abschluss ----------------------------------------------------------------

func test_done_hides_panel_and_emits_closed():
	watch_signals(shop)
	shop._on_done_pressed()
	assert_false(shop.visible)
	assert_signal_emitted(shop, "closed")
