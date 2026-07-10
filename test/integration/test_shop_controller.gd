extends GutTest
## Tier-2-Integrationstests des Shops (ShopController auf shop_panel.tscn).
## Der Shop wird als eigene Szene instanziiert und mit einem Fake-Spiel
## verdrahtet, das nur die vier von scene_root bereitgestellten API-Methoden
## nachbildet (player_money/owned_charm_ids/purchase_die/purchase_charm). So
## lässt sich die komplette Kauf-Interaktion ohne den echten Spielzustand prüfen.

const ShopPanelScene := preload("res://scenes/shop_panel.tscn")

## Minimales Spiel-Double: merkt sich Geld und Käufe, ohne echte Spiellogik.
class FakeGame extends RefCounted:
	var money: int = 100
	var owned: Array[String] = []
	var bought_dice: Array = []
	var bought_charms: Array = []

	func player_money() -> int:
		return money

	func owned_charm_ids() -> Array[String]:
		return owned

	func purchase_die(def, price: int) -> void:
		money -= price
		bought_dice.append(def)

	func purchase_charm(charm, price: int) -> void:
		money -= price
		bought_charms.append(charm)
		owned.append(charm.id)

	var bought_sheets: Array = []  # gekaufte Bogentypen (siehe buy_coupon_sheet)
	func buy_coupon_sheet(kind: int, price: int) -> int:
		money -= price
		bought_sheets.append(kind)
		var sheet := CouponSheet.generate(kind)
		var etch_count := 0
		for tile in sheet.tiles:
			if tile["kind"] == "etching":
				etch_count += 1
		return etch_count

var shop
var fake: FakeGame

func before_each() -> void:
	fake = FakeGame.new()
	shop = ShopPanelScene.instantiate()
	add_child_autofree(shop)  # löst _ready aus (baut Würfel-Angebot, verbindet Signale)
	shop.game = fake
	shop.open()

# --- Angebot ------------------------------------------------------------------

func test_open_shows_panel_and_offers_up_to_two_charms():
	assert_true(shop.visible)
	assert_gt(shop.charm_options.size(), 0, "mindestens ein Charm im Angebot")
	assert_true(shop.charm_options.size() <= 2, "höchstens zwei Charms")

func test_offer_excludes_already_owned_charms():
	fake.owned = [Charm.RABBITS_FOOT]
	shop.open()
	for charm in shop.charm_options:
		assert_ne(charm.id, Charm.RABBITS_FOOT, "besessener Charm nicht erneut angeboten")

# --- Würfelkauf ---------------------------------------------------------------

func test_buy_die_deducts_money_and_records():
	shop._on_die_clicked(0)
	assert_eq(fake.money, 85)  # 100 - 15
	assert_eq(fake.bought_dice.size(), 1)

func test_dice_are_repeatable():
	shop._on_die_clicked(0)
	shop._on_die_clicked(1)
	assert_eq(fake.money, 70)
	assert_eq(fake.bought_dice.size(), 2)

func test_cannot_buy_die_without_funds():
	fake.money = 10
	shop._on_die_clicked(0)
	assert_eq(fake.money, 10, "kein Abzug bei zu wenig Geld")
	assert_eq(fake.bought_dice.size(), 0)

func test_con_artist_cuff_discounts_dice_price():
	fake.owned = [Charm.CON_ARTIST_CUFF]
	shop.open()
	shop._on_die_clicked(0)
	assert_eq(fake.money, 88, "100 - 12 (20% Rabatt)")

# --- Charmkauf ----------------------------------------------------------------

func test_buy_charm_grants_and_deducts():
	var charm = shop.charm_options[0]
	shop._on_charm_clicked(0)
	assert_eq(fake.money, 75)  # 100 - 25
	assert_eq(fake.bought_charms.size(), 1)
	assert_true(fake.owned.has(charm.id))

func test_charm_cannot_be_bought_twice():
	shop._on_charm_clicked(0)
	var money_after_first: int = fake.money
	shop._on_charm_clicked(0)  # schon gekauft
	assert_eq(fake.money, money_after_first, "zweiter Klick zieht nichts weiter ab")

func test_charm_buttons_disabled_when_broke():
	fake.money = 10
	shop.open()  # neu bestücken mit wenig Geld
	for button in shop.charm_buttons:
		assert_true(button.disabled, "Charm bei zu wenig Geld nicht kaufbar")

# --- Coupon-Bögen -------------------------------------------------------------

func test_buy_snippet_sheet_deducts_price():
	shop._on_sheet_pressed(0)  # Schnipsel, $6
	assert_eq(fake.money, 94)  # 100 - 6
	assert_eq(fake.bought_sheets.size(), 1)
	assert_eq(fake.bought_sheets[0], CouponSheet.Kind.SNIPPET)

func test_sheets_are_repeatable():
	shop._on_sheet_pressed(0)  # -6
	shop._on_sheet_pressed(1)  # Bogen -10
	assert_eq(fake.money, 84)  # 100 - 6 - 10
	assert_eq(fake.bought_sheets.size(), 2)

func test_cannot_buy_sheet_without_funds():
	fake.money = 3
	shop._on_sheet_pressed(2)  # Großbogen, $16
	assert_eq(fake.money, 3, "kein Abzug bei zu wenig Geld")
	assert_eq(fake.bought_sheets.size(), 0)

func test_sheet_buttons_disabled_by_price():
	fake.money = 8  # reicht für Schnipsel ($6), nicht für Bogen ($10)/Großbogen ($16)
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
