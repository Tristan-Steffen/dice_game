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
	run.hub_level = 7  # Suite: großer Laden (4 Charms / 3 Würfel-Pakete / 3 Gravur-Pakete / 2 Übertaktungen)
	shop = ShopPanelScene.instantiate()
	add_child_autofree(shop)  # löst _ready aus (baut Würfel-Angebot, verbindet Signale)
	shop.run = run
	shop.open()

## Anzahl Pool-Würfel, die KEIN Standardwürfel ("normal") sind - also eingesetzte
## Spezialwürfel (jede Vorlage vergibt nicht-"normale" style_ids, siehe DiceOffer).
func _count_special() -> int:
	var count := 0
	for def in run.owned_pool:
		if def.style_id != "normal":
			count += 1
	return count

# --- Angebot ------------------------------------------------------------------

func test_open_shows_panel_and_offers_up_to_four_charms():
	assert_true(shop.visible)
	assert_gt(shop.charm_options.size(), 0, "mindestens ein Charm im Angebot")
	assert_true(shop.charm_options.size() <= run.shop_charm_slots(), "höchstens so viele wie die Hub-Stufe erlaubt")

func test_offer_excludes_already_owned_charms():
	run.owned_charms.append(Charm.rabbits_foot())
	shop.open()
	for charm in shop.charm_options:
		assert_ne(charm.id, Charm.RABBITS_FOOT, "besessener Charm nicht erneut angeboten")

func test_open_rolls_three_dice_packs():
	assert_eq(shop.dice_packs.size(), 3, "drei Würfel-Pakete je Besuch")
	for pack in shop.dice_packs:
		assert_true(pack.is_dice_pack())
		assert_between(pack.count, 1, 3, "je Paket 1..3 Würfel")

# --- Paketkauf ----------------------------------------------------------------
# Gekaufte Pakete wandern VERSIEGELT ins Lager; erst das Öffnen in der Werkstatt
# würfelt den Inhalt aus (siehe GameRun.open_pack).

func test_buy_dice_pack_deducts_and_stores_it_sealed():
	var pack = shop.dice_packs[0]
	shop._on_pack_buy_pressed(0, true)
	assert_eq(run.money, 100 - pack.price)
	assert_eq(run.owned_packs.size(), 1, "Paket im Lager")
	assert_eq(_count_special(), 0, "der Pool ändert sich erst beim Einsetzen")

func test_buy_engraving_pack_deducts_and_grants_nothing_yet():
	var pack = shop.engraving_packs[0]
	shop._on_pack_buy_pressed(0, false)
	assert_eq(run.money, 100 - pack.price)
	assert_eq(run.owned_packs.size(), 1)
	assert_eq(run.owned_engravings.size(), 0, "Inhalt erst beim Öffnen")

func test_pack_offer_is_single_use():
	shop._on_pack_buy_pressed(0, true)
	var money_after: int = run.money
	shop._on_pack_buy_pressed(0, true)  # zweiter Kauf desselben Angebots
	assert_eq(run.money, money_after, "nur einmal abgezogen")
	assert_eq(run.owned_packs.size(), 1)
	assert_true(shop.dice_pack_bought[0], "als gekauft vermerkt")
	assert_true(shop.dice_pack_buttons[0].disabled, "Karte ist danach im Lager")

func test_cannot_buy_pack_without_funds():
	run.money = 3  # unter jedem Paketpreis
	shop._on_pack_buy_pressed(0, true)
	assert_eq(run.money, 3, "kein Abzug bei zu wenig Geld")
	assert_eq(run.owned_packs.size(), 0)

func test_con_artist_cuff_discounts_dice_pack_price():
	run.owned_charms.append(Charm.con_artist_cuff())
	shop.open()
	var pack = shop.dice_packs[0]
	shop._on_pack_buy_pressed(0, true)
	assert_eq(run.money, 100 - CharmEffects.die_price(pack.price, run.charm_ids(), pack.count),
		"33% Rabatt auf den Paketpreis")

func test_pack_price_is_raw_price_without_discount():
	var pack = shop.dice_packs[0]
	assert_eq(shop._pack_price(pack), pack.price, "ohne Rabatt-Charm der volle Preis")
	var engraving_pack = shop.engraving_packs[0]
	assert_eq(shop._pack_price(engraving_pack), engraving_pack.price, "Gravur-Pakete haben feste Preise")

func test_bargain_hunter_discounts_every_pack_kind():
	run.owned_charms.append(Charm.bargain_hunter())
	for pack in shop.dice_packs + shop.engraving_packs:
		var plain: int = CharmEffects.die_price(pack.price, [] as Array[String], pack.count) if pack.is_dice_pack() else pack.price
		assert_eq(shop._pack_price(pack), maxi(1, plain - 3), "%s: $3 guenstiger" % pack.type)

func test_pack_buttons_disabled_by_price():
	run.money = 5  # unter jedem Paketpreis
	shop.open()
	for button in shop.dice_pack_buttons:
		assert_true(button.disabled, "Würfel-Paket bei zu wenig Geld nicht kaufbar")
	for button in shop.engraving_pack_buttons:
		assert_true(button.disabled, "Gravur-Paket bei zu wenig Geld nicht kaufbar")

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

func test_spread_offers_packs_and_overclocks():
	# Angebot = Lager (Würfel- + Gravur-Pakete) links, Übertaktungs-Chips rechts;
	# die Zahlen liefert die Hub-Stufe (hier Suite: 3 Würfel, 3 Pakete, 2 Übertaktungen).
	assert_eq(shop.dice_packs.size(), run.shop_dice_slots(), "drei Würfel-Pakete")
	assert_eq(shop.engraving_packs.size(), run.shop_pack_slots(), "Gravur-Pakete im Regal")
	assert_eq(shop.overclock_offers.size(), run.shop_overclock_slots(), "zwei Übertaktungen")
	for pack in shop.engraving_packs:
		assert_false(pack.is_dice_pack())
		assert_true(Engraving.CATEGORIES.has(pack.engraving_category())
			or pack.type == Pack.TYPE_MIXED, "echte Gravur-Kategorie oder gemischt")

# --- Übertaktungen ---------------------------------------------------------------

## Erzwingt ein bestimmtes Übertaktungs-Sortiment auf der aktuellen Doppelseite.
func _force_overclock_offers(keys: Array) -> void:
	var spread = shop.spreads[shop.current_spread_index]
	var typed: Array[String] = []
	typed.assign(keys)
	spread.overclock_offers = typed
	spread.overclock_bought.resize(typed.size())
	spread.overclock_bought.fill(false)
	shop._show_spread()

func test_overclock_offers_are_distinct_valid_combos():
	var seen := {}
	for key in shop.overclock_offers:
		assert_true(DiceScoring.HAND_PRIORITY.has(key), "%s ist eine echte Kombination" % key)
		assert_false(seen.has(key), "keine doppelte Kombination: %s" % key)
		seen[key] = true

func test_buy_overclock_levels_combo_and_deducts():
	_force_overclock_offers([DiceScoring.FULL_HOUSE])
	var price := run.overclock_price(DiceScoring.FULL_HOUSE)
	shop._on_overclock_buy_pressed(0)
	assert_eq(run.combo_level(DiceScoring.FULL_HOUSE), 1, "Stufe gekauft")
	assert_eq(run.money, 100 - price, "Preis abgezogen")
	assert_true(shop.overclock_bought[0], "als gekauft vermerkt")

func test_overclock_offer_is_single_use():
	_force_overclock_offers([DiceScoring.TWO_KIND])
	shop._on_overclock_buy_pressed(0)
	var money_after := run.money
	shop._on_overclock_buy_pressed(0)  # zweiter Kauf desselben Angebots
	assert_eq(run.combo_level(DiceScoring.TWO_KIND), 1, "nur eine Stufe")
	assert_eq(run.money, money_after, "nur einmal abgezogen")
	assert_true(shop.overclock_buttons[0].disabled, "Karte ist danach gekauft")

func test_cannot_buy_overclock_without_funds():
	run.money = 0
	_force_overclock_offers([DiceScoring.SIX_KIND])
	shop._on_overclock_buy_pressed(0)
	assert_eq(run.combo_level(DiceScoring.SIX_KIND), 0, "ohne Geld keine Stufe")
	assert_eq(run.money, 0)

func test_engraving_packs_persist_when_flipping_back():
	var first_types: Array = []
	for pack in shop.engraving_packs:
		first_types.append(pack.type)
	shop._on_page_next_pressed()  # neue Doppelseite (kostet Gebühr)
	shop._on_page_back_pressed()
	var back_types: Array = []
	for pack in shop.engraving_packs:
		back_types.append(pack.type)
	assert_eq(back_types, first_types, "zurückgeblättert = dasselbe Sortiment")

# --- Rabatt-Charms im Shop (Skonto, Wechselgeld, Mengenrabatt) -------------------

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

func test_bulk_discount_only_hits_triple_packs():
	run.owned_charms.append(Charm.bulk_discount())
	for pack in shop.dice_packs:
		var expected: int = pack.price - 5 if pack.count >= 3 else pack.price
		assert_eq(shop._pack_price(pack), maxi(1, expected))

# --- Kaufbarkeit bei Geldänderung ----------------------------------------------
# Der Shop hört auf run.money_changed: steigt das Geld, während der Shop offen
# ist, werden zuvor gesperrte Käufe SOFORT wieder freigeschaltet - ohne dass der
# Shop neu öffnet.

func test_money_gain_re_enables_pack_buttons():
	run.money = 5
	assert_true(shop.dice_pack_buttons[0].disabled, "erst gesperrt")
	run.add_money(50)
	assert_false(shop.dice_pack_buttons[0].disabled, "nach Geldzuwachs wieder kaufbar")

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
	var first_packs = shop.dice_packs
	shop._on_page_next_pressed()  # -$2
	var second_packs = shop.dice_packs
	shop._on_page_back_pressed()
	assert_eq(run.money, 98, "Zurückblättern kostet nichts")
	assert_true(shop.dice_packs == first_packs, "dieselben Angebote wie zuvor (gleiche Instanz)")
	shop._on_page_next_pressed()  # vor auf BEREITS gesehene Seite
	assert_eq(run.money, 98, "Vorblättern auf bekannte Seite kostet nichts")
	assert_true(shop.dice_packs == second_packs)
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

# --- Kein Überlauf (der Fuß mit "Fertig" bleibt auf JEDER Stufe im Panel) -------

func test_the_footer_stays_inside_the_panel_on_every_hub_level() -> void:
	# Regression: auf hohen Stufen schob das Lager (bis zu 7 Pakete) den Fuß aus
	# dem Panel - der Shop war ohne "Fertig" nicht mehr verlassbar.
	shop.size = Vector2(1068, 1125)  # Maß der Hub-Fläche auf dem Tisch-Display
	for level in range(1, GameRun.HUB_MAX_LEVEL + 1):
		run.hub_level = level
		shop.open()
		await wait_frames(2)
		var vroot: Control = shop.done_button.get_parent().get_parent()  # Footer -> Root
		var need: Vector2 = vroot.get_combined_minimum_size()
		assert_true(need.y <= vroot.size.y + 0.5,
			"Stufe %d: Inhalt (%d) höher als das Panel (%d)" % [level, need.y, vroot.size.y])
		assert_true(need.x <= vroot.size.x + 0.5,
			"Stufe %d: Inhalt (%d) breiter als das Panel (%d)" % [level, need.x, vroot.size.x])
		assert_true(shop.done_button.get_global_rect().end.y
			<= shop.get_global_rect().end.y + 0.5,
			"Stufe %d: Fertig liegt im Panel" % level)

# --- Abschluss ----------------------------------------------------------------

func test_done_hides_panel_and_emits_closed():
	watch_signals(shop)
	shop._on_done_pressed()
	assert_false(shop.visible)
	assert_signal_emitted(shop, "closed")
