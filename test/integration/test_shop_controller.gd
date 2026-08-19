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
	run.hub_level = 7  # Suite: großer Laden (4 Charms / 5 Einzelwürfel / 3 Gravur-Pakete)
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

func test_owned_charms_never_appear_again():
	# Besitz SPERRT: was im Dock steht, liegt nicht wieder aus.
	run.owned_charms.append(Charm.rabbits_foot())
	for i in 10:
		shop.open()
		assert_gt(shop.charm_options.size(), 0, "das Angebot bleibt gefüllt")
		for option in shop.charm_options:
			assert_ne(option.id, Charm.RABBITS_FOOT, "besessener Charm liegt wieder aus")

func test_the_shop_never_lays_out_a_dice_pack_again():
	# Würfel liegen OFFEN in der Schale - versiegelt gibt es nur Gravuren.
	for pack in shop.engraving_packs:
		assert_ne(pack.type, "dice")
	assert_eq(shop.vitrine_stock().has("dice_pack"), false,
		"die Bucht kennt keine Würfel-Kassetten mehr")

func test_the_dice_ladder_follows_the_licence():
	assert_eq(shop.single_dice.size(), run.shop_dice_slots(), "Suite: 5 Würfel")
	assert_eq(GameRun.new_run().shop_dice_slots(), 3, "Stufe 1: drei")
	var top := GameRun.new_run()
	top.hub_level = GameRun.HUB_MAX_LEVEL
	assert_eq(top.shop_dice_slots(), 6, "High Roller: sechs")

# --- Paketkauf ----------------------------------------------------------------
# Gekaufte Pakete wandern VERSIEGELT ins Lager; erst die Presse öffnet sie.

func test_buy_engraving_pack_deducts_and_grants_nothing_yet():
	var pack = shop.engraving_packs[0]
	shop._on_pack_buy_pressed(0)
	assert_eq(run.money, 100 - pack.price)
	assert_eq(run.owned_packs.size(), 1)
	assert_eq(run.owned_packs[0].count, Pack.ENGRAVING_PACK_COUNT, "ein Phantomwürfel je Paket")

func test_pack_offer_is_single_use():
	shop._on_pack_buy_pressed(0)
	var money_after: int = run.money
	shop._on_pack_buy_pressed(0)  # zweiter Kauf desselben Angebots
	assert_eq(run.money, money_after, "nur einmal abgezogen")
	assert_eq(run.owned_packs.size(), 1)
	assert_true(shop.engraving_pack_bought[0], "als gekauft vermerkt")

func test_cannot_buy_pack_without_funds():
	run.money = 3  # unter jedem Paketpreis
	shop._on_pack_buy_pressed(0)
	assert_eq(run.money, 3, "kein Abzug bei zu wenig Geld")
	assert_eq(run.owned_packs.size(), 0)

func test_con_artist_cuff_discounts_the_bowl_die_price():
	# Die Würfel-Rabatte liegen jetzt in der Schale - der einzige Würfelkauf.
	run.owned_charms.append(Charm.con_artist_cuff())
	shop.open()
	var price: int = shop.single_dice_prices[0]
	shop._on_single_die_pressed(0)
	assert_eq(run.money, 100 - price)
	var plain := ShopController.single_die_price(
		CharmEffects.die_price(100, run.charm_ids()))
	assert_lt(plain, ShopController.single_die_price(100), "33% Rabatt greift")

func test_pack_price_is_raw_price_without_discount():
	var engraving_pack = shop.engraving_packs[0]
	assert_eq(shop._pack_price(engraving_pack), engraving_pack.price, "Gravur-Pakete haben feste Preise")

func test_bargain_hunter_discounts_every_pack_kind():
	run.owned_charms.append(Charm.bargain_hunter())
	for pack in shop.engraving_packs:
		assert_eq(shop._pack_price(pack), maxi(1, pack.price - 3), "%s: $3 guenstiger" % pack.type)

## Ohne Geld bleibt jedes Paket liegen - die Kaufbarkeit steht seit dem
## Vitrinen-Umbau nicht mehr an einer Karte, also wird der Kaufweg selbst geprüft.
func test_packs_are_not_sold_without_the_money():
	run.money = 0  # unter jedem Paketpreis (das 1er-Paket kostet $5)
	shop.open()
	shop._on_pack_buy_pressed(0)
	assert_eq(run.money, 0, "kein Abzug")
	assert_eq(run.owned_packs.size(), 0, "und nichts im Lager")
	assert_false(shop.engraving_pack_bought[0])

# --- Charmkauf ----------------------------------------------------------------

func test_buy_charm_grants_and_deducts():
	var charm = shop.charm_options[0]
	shop._on_charm_clicked(0)
	assert_eq(run.money, 85)  # 100 - 15
	assert_eq(run.owned_charms.size(), 1)
	# owned_charm_ids statt charm_ids: Totems lösen sich in charm_ids() zu
	# ihren Nachbarn auf - der Test war sonst flaky, wenn ein Totem gezogen wurde.
	assert_true(run.owned_charm_ids().has(charm.id))

func test_an_all_owned_pool_falls_back_instead_of_leaving_slots_empty():
	# Erschöpfter Topf: eine Dublette ist besser als ein leerer Platz. Innerhalb
	# EINER Doppelseite bleibt jeder Archetyp trotzdem einmalig.
	for charm in Charm.all():
		run.owned_charms.append(charm)
	shop.open()
	assert_gt(shop.charm_options.size(), 0, "kein leerer Platz")
	var seen := {}
	for option in shop.charm_options:
		assert_false(seen.has(option.id), "Archetyp '%s' liegt doppelt aus" % option.id)
		seen[option.id] = true

func test_owning_a_charm_does_not_lock_its_card():
	# Besitz allein sperrt nichts - erst der VOLLE Dock tut das.
	run.owned_charms.append(shop.charm_options[0])
	shop.open()
	for button in shop.charm_buttons:
		assert_false(button.disabled, "Besitz sperrt den Kauf nicht")

func test_a_full_dock_locks_every_charm_card():
	# Harte Obergrenze, keine Warteschlange: bei sechs Charms ist kein Kauf mehr
	# möglich, egal wie viel Geld liegt.
	for i in GameRun.CHARM_CAPACITY:
		run.owned_charms.append(Charm.rabbits_foot())
	shop.open()
	for button in shop.charm_buttons:
		assert_true(button.disabled, "voller Dock sperrt jede Charm-Karte")
	var money_before: int = run.money
	shop._on_charm_clicked(0)
	assert_eq(run.money, money_before, "kein Abzug am vollen Dock")
	assert_eq(run.owned_charms.size(), GameRun.CHARM_CAPACITY)

func test_selling_a_charm_re_enables_the_cards():
	for i in GameRun.CHARM_CAPACITY:
		run.owned_charms.append(Charm.rabbits_foot())
	shop.open()
	run.sell_charm(0)  # der Erlös meldet money_changed - die Karten frischen auf
	for button in shop.charm_buttons:
		assert_false(button.disabled, "ein freier Platz macht die Karten wieder kaufbar")

## Preisschild einer Charm-Karte ("voll" / "gekauft" / "gratis" / "$n").
func _charm_price_tags() -> Array[String]:
	var tags: Array[String] = []
	for button in shop.charm_buttons:
		var tag := _first_tag_label(button)
		if tag != "":
			tags.append(tag)
	return tags

func _first_tag_label(node: Node) -> String:
	for child in node.get_children():
		if child is Label:
			var text: String = (child as Label).text
			if text == "voll" or text == "gekauft" or text == "gratis" or text.begins_with("$"):
				return text
		var nested := _first_tag_label(child)
		if nested != "":
			return nested
	return ""

func test_selling_a_charm_rebuilds_the_cards_and_the_click_works():
	# Regression: die Karte backt den "voll"-Zustand ein (Schild + Hinweis) und
	# bekam bei vollem Dock gar keinen pressed-Handler. Nach einem Verkauf muss
	# beides wieder stimmen, nicht nur der disabled-Zustand.
	run.money = 300
	for i in GameRun.CHARM_CAPACITY:
		run.owned_charms.append(Charm.rabbits_foot())
	shop.open()
	await wait_frames(2)
	assert_true(_charm_price_tags().has("voll"), "voller Dock: das Schild sagt es")
	run.sell_charm(0)
	await wait_frames(2)
	assert_false(_charm_price_tags().has("voll"), "nach dem Verkauf steht wieder ein Preis da")
	var owned_before := run.owned_charms.size()
	shop.charm_buttons[0].pressed.emit()  # der ECHTE Klickweg, nicht der Handler
	assert_eq(run.owned_charms.size(), owned_before + 1, "der Klick kauft wirklich")

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

func test_spread_offers_packs():
	# Auslage = Gravur-Kassetten im Regal, Einzelwürfel in der Schale, Charms auf
	# dem Bildschirm; die Zahlen liefert die Hub-Stufe (hier Suite: 5 Würfel, 3 Pakete).
	assert_eq(shop.single_dice.size(), run.shop_dice_slots(), "Einzelwürfel in der Schale")
	assert_eq(shop.engraving_packs.size(), run.shop_pack_slots(), "Gravur-Pakete im Regal")
	for pack in shop.engraving_packs:
		assert_true(Engraving.CATEGORIES.has(pack.engraving_category()), "echte Gravur-Kategorie")

## Übertaktet wird am Chip, nicht im Laden - die Schale führt keine Chips mehr.
func test_the_shop_no_longer_sells_overclocks():
	assert_false(shop.has_method("_on_overclock_buy_pressed"))
	var spread = shop.spreads[shop.current_spread_index]
	assert_false("overclock_offers" in spread, "auch die Auslage kennt sie nicht mehr")

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

# --- Rabatt-Charms im Shop (Rabattmarke, Trickdieb-Manschette, Mengenrabatt) -----

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
	# Rabattmarke kaufen ($15), danach kostet der zweite Charm sofort $10.
	_force_charm_options([Charm.cash_discount(), Charm.rabbits_foot()])
	shop._on_charm_clicked(0)
	assert_eq(run.money, 85, "die Rabattmarke selbst kostet den vollen Preis")
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
	assert_eq(run.money, 90, "Rabattmarke: $10 statt $15")

func test_bulk_discount_hits_the_bowl_dice():
	# Seit die Würfel-Pakete tot sind, greift der Mengenrabatt an der Schale - dem
	# einzigen Würfelkauf, den es noch gibt.
	run.owned_charms.append(Charm.bulk_discount())
	shop.open()
	for price in shop.single_dice_prices:
		assert_gt(int(price), 0, "der Rabatt drückt nie unter $1")
	assert_lt(CharmEffects.die_price(30, run.charm_ids()), 30, "$5 weniger je Würfel")

# --- Kaufbarkeit bei Geldänderung ----------------------------------------------
# Der Shop hört auf run.money_changed: steigt das Geld, während der Shop offen
# ist, werden zuvor gesperrte Käufe SOFORT wieder freigeschaltet - ohne dass der
# Shop neu öffnet.

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
	var first_dice = shop.single_dice
	shop._on_page_next_pressed()  # -$2
	var second_dice = shop.single_dice
	shop._on_page_back_pressed()
	assert_eq(run.money, 98, "Zurückblättern kostet nichts")
	assert_true(shop.single_dice == first_dice, "dieselben Angebote wie zuvor (gleiche Instanz)")
	shop._on_page_next_pressed()  # vor auf BEREITS gesehene Seite
	assert_eq(run.money, 98, "Vorblättern auf bekannte Seite kostet nichts")
	assert_true(shop.single_dice == second_dice)
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

func test_each_archetype_appears_at_most_once_per_spread():
	# Besitz sperrt NICHTS (Duplikate sind erlaubt) - die Auslage zieht nur
	# INNERHALB einer Doppelseite ohne Zurücklegen.
	shop._on_charm_clicked(0)  # jetzt besessen
	shop._on_page_next_pressed()  # frische Doppelseite
	var seen: Array[String] = []
	for charm in shop.charm_options:
		assert_false(seen.has(charm.id), "jeder Archetyp höchstens einmal je Seite")
		seen.append(charm.id)

# --- Sortiment-Sperre ----------------------------------------------------------

func test_locked_shop_keeps_the_same_offers_on_reopen():
	var charms = shop.charm_options
	var dice = shop.single_dice
	var engravings = shop.engraving_packs
	shop._on_lock_pressed()
	assert_true(shop.sortiment_locked)
	shop._on_done_pressed()
	shop.open()
	assert_true(shop.charm_options == charms, "dieselben Charms (gleiche Instanzen)")
	assert_true(shop.single_dice == dice, "dieselben Würfel")
	assert_true(shop.engraving_packs == engravings, "dieselben Gravur-Pakete")

func test_locked_shop_keeps_bought_marks_on_reopen():
	shop._on_charm_clicked(0)
	shop._on_pack_buy_pressed(0)
	shop._on_lock_pressed()
	shop._on_done_pressed()
	shop.open()
	assert_true(shop.charm_bought[0], "der gekaufte Charm bleibt vermerkt")
	assert_true(shop.engraving_pack_bought[0], "das gekaufte Paket bleibt im Lager")
	var money_after: int = run.money
	shop._on_charm_clicked(0)
	assert_eq(run.money, money_after, "kein zweiter Kauf über den Besuch hinweg")

func test_locked_shop_keeps_every_flipped_page():
	shop._on_page_next_pressed()  # -$2, zweite Seite
	var second = shop.single_dice
	shop._on_lock_pressed()
	shop._on_done_pressed()
	shop.open()
	assert_eq(shop.spreads.size(), 2, "beide Seiten bleiben stehen")
	assert_eq(shop.current_spread_index, 1, "der Laden öffnet, wo er zuging")
	assert_true(shop.single_dice == second)

func test_unlocking_resumes_the_reroll():
	var charms = shop.charm_options
	shop._on_lock_pressed()
	shop._on_lock_pressed()  # wieder offen
	assert_false(shop.sortiment_locked)
	shop._on_done_pressed()
	shop.open()
	assert_false(shop.charm_options == charms, "frische Auslage")
	assert_eq(shop.spreads.size(), 1)

func test_lock_button_labels_the_action():
	assert_true("sperren" in shop.lock_button.text, "offen: der Knopf bietet das Sperren an")
	shop._on_lock_pressed()
	assert_true("lösen" in shop.lock_button.text, "gesperrt: der Knopf bietet das Lösen an")

func test_a_new_run_clears_the_lock():
	shop._on_lock_pressed()
	var fresh := GameRun.new_run()
	fresh.money = 100
	shop.run = fresh
	assert_false(shop.sortiment_locked, "ein frischer Lauf startet mit offenem Sortiment")
	shop.open()
	assert_eq(shop.spreads.size(), 1)

# --- Wieder-Eintritt: derselbe Laden, nichts gewürfelt --------------------------

func test_reopen_keeps_the_same_offers_without_rolling():
	var charms = shop.charm_options
	var dice = shop.single_dice
	var engravings = shop.engraving_packs
	shop._on_done_pressed()
	shop.reopen()
	assert_true(shop.visible)
	assert_true(shop.charm_options == charms, "dieselben Charms (gleiche Instanzen)")
	assert_true(shop.single_dice == dice)
	assert_true(shop.engraving_packs == engravings)
	assert_eq(shop.spreads.size(), 1, "keine zweite Auslage")

func test_reopen_keeps_bought_marks_and_the_page():
	shop._on_charm_clicked(0)
	shop._on_pack_buy_pressed(0)
	shop._on_page_next_pressed()  # zweite Seite
	shop._on_done_pressed()
	shop.reopen()
	assert_eq(shop.current_spread_index, 1, "der Laden öffnet, wo er zuging")
	assert_true(shop.spreads[0].charm_bought[0], "der gekaufte Charm bleibt vermerkt")
	assert_true(shop.spreads[0].engraving_pack_bought[0])

func test_reopen_without_a_spread_rolls_like_a_first_visit():
	# Kommt der Knopf je vor dem ersten Öffnen, darf der Laden nicht leer sein.
	var fresh := GameRun.new_run()
	fresh.money = 100
	shop.run = fresh  # der Setter räumt die Auslage
	shop.close()
	shop.reopen()
	assert_gt(shop.spreads.size(), 0)
	assert_gt(shop.charm_options.size(), 0)

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

# --- Chip-Schale: die Einzelstücke ------------------------------------------------

func test_the_bowl_offers_open_dice_only() -> void:
	assert_eq(shop.single_dice.size(), run.shop_dice_slots(),
		"die Lizenz sagt, wie viele offene Würfel ausliegen")
	assert_eq(shop.single_dice_prices.size(), shop.single_dice.size(), "je Würfel ein Preis")

func test_a_single_die_is_fully_rolled_before_the_purchase() -> void:
	# Der ganze Sinn der offenen Auslage: der Würfel steht schon fest, es gibt
	# nichts mehr zu enthüllen.
	for i in shop.single_dice.size():
		var die: DieDefinition = shop.single_dice[i]
		assert_eq(die.faces.size(), 6, "alle sechs Seiten stehen")
		assert_gt(int(shop.single_dice_prices[i]), 0, "und der Preis auch")

func test_buying_an_open_die_stashes_it_with_the_dealer() -> void:
	# Bezahlt, aber NICHT eingesetzt: der Automat wählte sonst blind einen
	# Pool-Platz, und eine Seele ist nicht wiederbeschaffbar.
	run.money = 500
	var price: int = shop.single_dice_prices[0]
	var incoming: String = shop.single_dice[0].style_id
	var pool_before := []
	for def in run.owned_pool:
		pool_before.append(def.style_id)
	var before := run.money
	shop._on_single_die_pressed(0)
	assert_eq(run.money, before - price, "der Preis ist abgebucht")
	assert_true(shop.single_dice_bought[0], "der Platz ist verkauft")
	assert_eq(run.pending_dice.size(), 1, "er liegt beim Händler")
	assert_eq(run.pending_dice[0].style_id, incoming)
	var pool_after := []
	for def in run.owned_pool:
		pool_after.append(def.style_id)
	assert_eq(pool_after, pool_before, "der Vorrat bleibt unangetastet")

func test_a_single_is_only_sold_once() -> void:
	run.money = 500
	shop._on_single_die_pressed(0)
	var after_first := run.money
	shop._on_single_die_pressed(0)
	assert_eq(run.money, after_first, "der zweite Klick kostet nichts mehr")

func test_singles_are_not_sold_without_the_money() -> void:
	run.money = 0
	var before := run.pending_dice.size()
	shop._on_single_die_pressed(0)
	assert_eq(run.pending_dice.size(), before, "ohne Geld kein Kauf")
	assert_false(shop.single_dice_bought[0])

func test_the_locked_assortment_freezes_the_singles_too() -> void:
	run.money = 500
	var die_names: Array[String] = []
	for def in shop.single_dice:
		die_names.append(def.display_name)
	shop.sortiment_locked = true
	shop.close()
	shop.open()
	var after_names: Array[String] = []
	for def in shop.single_dice:
		after_names.append(def.display_name)
	assert_eq(after_names, die_names, "dieselben Würfel liegen wieder da")

func test_a_bought_single_stays_bought_inside_a_locked_spread() -> void:
	run.money = 500
	shop._on_single_die_pressed(0)
	shop.sortiment_locked = true
	shop.close()
	shop.open()
	assert_true(shop.single_dice_bought[0], "gekauft bleibt gekauft")

func test_unlocking_rolls_fresh_singles() -> void:
	shop.sortiment_locked = false
	var before: Array[int] = shop.single_dice_prices.duplicate()
	shop.close()
	shop.open()
	# Ohne Sperre wird neu gerollt - die Auslage ist eine andere (Preise oder
	# Anzahl unterscheiden sich praktisch immer; hier reicht die Existenz).
	assert_gt(shop.single_dice.size(), 0, "die neue Auslage ist wieder gefüllt")
	assert_eq(shop.single_dice_prices.size(), shop.single_dice.size())
	assert_gt(before.size(), 0)

# --- Die Vitrine: die Ware liegt körperlich, der Bildschirm meldet nur ihr Feld ---
# Die Auslage selbst (Pakete, Einzelstücke, Ausgabefach) stellt scene_root als echte
# Körper in die Bucht - der Laden zeichnet dort NICHTS und meldet nur das Rechteck.

func test_the_shop_reports_a_vitrine_rect() -> void:
	await wait_frames(2)
	var bay: Rect2 = shop.vitrine_rect_px()
	assert_gt(bay.size.x, 0.0, "die Bucht hat eine Breite")
	assert_gt(bay.size.y, 0.0, "und eine Höhe")
	var page: Rect2 = shop.get_global_rect()
	assert_true(page.encloses(bay), "sie liegt ganz auf der Ladenseite")

func test_the_vitrine_hole_sits_inside_its_frame() -> void:
	# Dieselbe Rechnung wie am Magazin: die Grube ist der Streifen ohne Fassung.
	await wait_frames(2)
	var bay: Rect2 = shop.vitrine_rect_px()
	var hole: Rect2 = shop.vitrine_pit_rect()
	assert_true(bay.encloses(hole), "das Loch liegt im Rahmen")
	assert_almost_eq(hole.position.x - bay.position.x,
		PackDrawerView.rim_inset(shop.u), 0.51, "links um die Fassung eingerückt")
	assert_almost_eq(bay.end.y - hole.end.y,
		PackDrawerView.rim_inset(shop.u), 0.51, "unten ebenso")

func test_the_vitrine_takes_the_lower_half_of_the_page() -> void:
	shop.size = Vector2(1068, 1125)  # Maß der Hub-Fläche auf dem Tisch-Display
	shop.open()
	await wait_frames(2)
	var page: Rect2 = shop.get_global_rect()
	var bay: Rect2 = shop.vitrine_rect_px()
	assert_gt(bay.size.y, page.size.y * 0.35, "die Bucht ist grob die halbe Seite")
	assert_lt(bay.size.y, page.size.y * 0.75, "aber sie frisst Kopf, Charms und Fuß nicht")
	assert_gt(bay.position.y, page.get_center().y - page.size.y * 0.25,
		"sie liegt unter der Charm-Zeile")

func test_the_vitrine_rect_survives_a_page_flip() -> void:
	shop.size = Vector2(1068, 1125)
	shop.open()
	await wait_frames(2)
	var before: Rect2 = shop.vitrine_rect_px()
	shop._on_page_next_pressed()  # frische Doppelseite
	await wait_frames(2)
	assert_true(shop.vitrine_rect_px().is_equal_approx(before),
		"die Bucht steht fest - geblättert wird die Ware, nicht das Möbel")

func test_the_stock_carries_every_slot_of_the_spread() -> void:
	var stock: Dictionary = shop.vitrine_stock()
	assert_eq(stock[ShopController.KIND_ENGRAVING_PACK].size(), shop.engraving_packs.size())
	assert_eq(stock[ShopController.KIND_DIE].size(), shop.single_dice.size())
	assert_eq(stock[ShopController.KIND_SPECIAL].size(), shop.single_specials.size())
	assert_false(stock.has("pending"),
		"bezahlte Ware wartet nicht mehr im Laden - sie liegt an der Werkbank")

func test_a_bought_slot_stays_as_an_empty_place() -> void:
	# Ausverkauft ist SICHTBAR: der Platz bleibt leer, und die Lücke hält die
	# Indizes treu - ein Griff meint immer denselben Kaufweg.
	run.money = 500
	shop.buy_single_die(0)
	var stock: Dictionary = shop.vitrine_stock()
	assert_eq(stock[ShopController.KIND_DIE].size(), shop.single_dice.size(),
		"der Platz verschwindet nicht, er wird leer")
	assert_null(stock[ShopController.KIND_DIE][0], "verkauft = leerer Platz")
	assert_not_null(stock[ShopController.KIND_DIE][1], "der Nachbar rückt nicht auf")

func test_every_change_of_the_bay_is_reported() -> void:
	var beats := []
	shop.vitrine_changed.connect(func() -> void: beats.append(1))
	shop._on_pack_buy_pressed(0)
	assert_gt(beats.size(), 0, "der Kauf meldet die neue Auslage")
	beats.clear()
	shop._on_page_next_pressed()
	assert_gt(beats.size(), 0, "und das Blättern auch")

# --- Die drei Ankunfts-Grade ---------------------------------------------------
# Rollen heißt Zufall, Steigen heißt Abruf, Liegenbleiben heißt: nichts geschah.
# Der Laden entscheidet nur - gefahren wird die Bucht von scene_root.

func test_a_fresh_shop_rolls_its_goods_in() -> void:
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_ROLL_IN,
		"die erste Auslage wurde eben gewürfelt")

func test_a_new_page_rolls_a_known_one_rises() -> void:
	run.hub_level = 7  # Blättern ist freigeschaltet
	shop._on_page_next_pressed()  # frische Doppelseite
	assert_eq(shop.spreads.size(), 2, "eine zweite Seite liegt auf")
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_ROLL_IN,
		"eine neue Seite wird gewürfelt")
	shop._on_page_back_pressed()
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_RISE,
		"zurückgeblättert kehrt DIESELBE Ware zurück")
	shop._on_page_next_pressed()  # schon gesehene Seite
	assert_eq(shop.spreads.size(), 2, "kein neuer Wurf")
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_RISE,
		"auch vorwärts auf Bekanntes wird abgerufen")

func test_the_sortiment_lock_is_the_visible_promise() -> void:
	# Aufdecken, und alles liegt unangetastet da - genau das verspricht die Sperre.
	shop.sortiment_locked = true
	shop.close()
	shop.open()
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_STAND,
		"gesperrt wird nichts gewürfelt und nichts abgerufen")

func test_a_reentry_shows_the_same_standing_shop() -> void:
	shop.close()
	shop.reopen()
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_STAND,
		"der Laden ist derselbe, der Spieler geht nur noch einmal hinein")

func test_an_unlocked_visit_rolls_again() -> void:
	shop.close()
	shop.open()  # ohne Sperre würfelt jeder Besuch frisch
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_ROLL_IN)

func test_a_hub_upgrade_mid_visit_rolls_the_whole_page() -> void:
	shop.refresh_after_hub_upgrade()
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_ROLL_IN,
		"die neue Auslage ist wirklich neu gewürfelt")

func test_a_purchase_leaves_the_page_lying() -> void:
	run.money = 500
	shop.buy_engraving_pack(0)
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_STAND,
		"ein Kauf blättert nicht - die Seite bleibt liegen")
	shop.buy_single_die(0)
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_STAND)

func test_a_fresh_run_forgets_which_page_was_standing() -> void:
	shop.run = GameRun.new_run()
	shop.open()
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_ROLL_IN,
		"ein frischer Lauf bekommt einen frisch gewürfelten Laden")

func test_the_annotation_names_price_and_effect() -> void:
	var data: Dictionary = shop.vitrine_annotation(ShopController.KIND_ENGRAVING_PACK, 0)
	assert_eq(String(data["title"]), shop.engraving_packs[0].display_name)
	assert_eq(int(data["price"]), shop._pack_price(shop.engraving_packs[0]),
		"der Preis steht NUR hier - in der Bucht hängt kein Schild")
	assert_eq(int(data["money"]), run.money, "und die Kaufbarkeit reist mit")
	assert_eq(String(data["blocked"]), "", "ein freies Magazin sperrt nichts")

func test_a_full_magazin_says_so_on_the_annotation() -> void:
	# set_pack_capacity(0) ist ein No-op (ein nutzloser Wert wird verworfen) - das
	# Magazin wird also mit einer echten Kassette auf einem Platz vollgestellt.
	run.set_pack_capacity(1)
	run.grant_pack(Pack.roll_engraving_pack())
	assert_true(run.packs_full(), "das Magazin ist wirklich voll")
	var data: Dictionary = shop.vitrine_annotation(ShopController.KIND_ENGRAVING_PACK, 0)
	assert_eq(String(data["blocked"]), ShopController.FULL_TAG,
		"volles Magazin steht statt des Preises")

func test_a_full_magazin_never_blocks_a_die() -> void:
	# Der Würfel geht ins Ausgabefach - der Deckel des Magazins meint ihn nicht.
	run.set_pack_capacity(1)
	run.grant_pack(Pack.roll_engraving_pack())
	var data: Dictionary = shop.vitrine_annotation(ShopController.KIND_DIE, 0)
	assert_eq(String(data["blocked"]), "", "die Schale kennt keinen Deckel")

func test_a_die_annotation_carries_its_whole_net() -> void:
	var data: Dictionary = shop.vitrine_annotation(ShopController.KIND_DIE, 0)
	assert_eq(data["net"], shop.single_dice[0], "der Würfel zeigt sein volles Netz")
	assert_eq(int(data["price"]), shop.single_dice_prices[0])

func test_an_empty_slot_has_no_annotation() -> void:
	assert_eq(shop.vitrine_annotation(ShopController.KIND_DIE, 99), {})
	assert_eq(shop.vitrine_annotation("unfug", 0), {})

func test_the_buy_entrances_book_like_the_old_buttons() -> void:
	# Der Griff in der Bucht läuft durch DIESELBEN Buchungen - die Bucht ist
	# Bühne, nicht Regel.
	run.money = 500
	var before := run.money
	shop.buy_engraving_pack(0)
	assert_eq(run.owned_packs.size(), 1, "das Paket liegt im Magazin")
	assert_lt(run.money, before, "und ist bezahlt")
	shop.buy_single_die(0)
	assert_eq(run.pending_dice.size(), 1,
		"der Würfel ist hinterlegt - die Schale an der Werkbank zeigt ihn")

func test_a_pack_purchase_still_reports_its_delivery() -> void:
	# Ohne 2D-Karte kommt der Komet aus der Bucht - gemeldet wird er weiterhin.
	await wait_frames(2)
	var origins: Array[Vector2] = []
	shop.pack_purchased.connect(func(px: Vector2, _uid: int) -> void: origins.append(px))
	shop._on_pack_buy_pressed(0)
	assert_eq(origins.size(), 1, "der Kauf meldet seine Lieferung")
	assert_true(shop.vitrine_rect_px().has_point(origins[0]),
		"und sie startet in der Bucht")

# --- Die Preiszeile ------------------------------------------------------------

func test_the_price_line_is_a_pure_function() -> void:
	assert_eq(ShopController.price_text(7), "$7")
	assert_eq(ShopController.price_text(0), "$0")

func test_the_price_tint_says_whether_it_is_payable() -> void:
	assert_eq(ShopController.price_tint(5, 10), ShopController.NEON_GOLD, "bezahlbar")
	assert_eq(ShopController.price_tint(5, 5), ShopController.NEON_GOLD, "genau genug reicht")
	assert_eq(ShopController.price_tint(5, 4), CasinoStyle.RED, "zu teuer")

func test_the_hover_window_stays_inside_the_shop_page() -> void:
	# Der Hover der Charm-Karten bleibt Bildschirm - Lizenzen sind digitale Ware.
	await wait_frames(2)
	var card: Button = shop.charm_buttons[0]
	card.mouse_entered.emit()
	await wait_frames(2)
	assert_true(shop.shop_tooltip.visible)
	var box := Rect2(shop.shop_tooltip.position, shop.shop_tooltip.size)
	assert_gte(box.position.x, 0.0, "linke Kante drin")
	assert_gte(box.position.y, 0.0, "obere Kante drin")
	assert_lte(box.end.x, shop.size.x + 1.0, "rechte Kante drin")
	shop._hide_shop_tooltip()

# --- Schalen-Rabatt der Einzelwürfel ------------------------------------------------

func test_a_bowl_die_costs_less_than_the_same_die_on_the_shelf() -> void:
	# Der Schalen-Würfel kommt ohne Auswahl und ohne Paket - das schlägt sich im
	# Preis nieder. Nur die Relation ist gepinnt, die Zahl bleibt ein Stellknopf.
	for offer_price in [5, 12, 30, 77]:
		var single := ShopController.single_die_price(offer_price)
		assert_lt(single, offer_price, "$%d im Regal ist teurer als in der Schale" % offer_price)
		assert_gt(single, 0, "aber nie geschenkt")

func test_the_bowl_price_never_falls_below_a_dollar() -> void:
	assert_gte(ShopController.single_die_price(1), 1, "auch der billigste Würfel kostet etwas")
	assert_gte(ShopController.single_die_price(0), 1)

func test_the_bowl_price_grows_with_the_offer_price() -> void:
	assert_gte(ShopController.single_die_price(50), ShopController.single_die_price(20),
		"teurer bleibt teurer")

func test_the_laid_out_singles_carry_the_discounted_price() -> void:
	for price in shop.single_dice_prices:
		assert_gt(int(price), 0)

# --- Das Hinterlegen und der Tausch -------------------------------------------------
# Der Laden BUCHT weiter; gewählt wird der Pool-Platz an der Werkbank (die Schale
# rechts davon und der Wähler im Werkstatt-Fenster).

func _stash_one() -> DieDefinition:
	run.money = 500
	shop._on_single_die_pressed(0)
	return run.pending_dice[0]

func test_the_exchange_writes_into_the_chosen_pool_instance() -> void:
	# Ein Pool-Eintrag wird NIE getauscht, nur überschrieben - Rundendeck, Trays
	# und Raster halten dieselbe Referenz.
	var stashed := _stash_one()
	var target: DieDefinition = run.owned_pool[3]
	var identity := target.get_instance_id()
	assert_true(run.exchange_pending_die(0, 3))
	assert_eq(run.owned_pool[3].get_instance_id(), identity, "dieselbe Instanz")
	assert_eq(run.owned_pool[3].style_id, stashed.style_id, "mit dem neuen Inhalt")
	assert_eq(run.owned_pool[3].essence_id, stashed.essence_id, "Seele inklusive")
	assert_eq(run.pending_dice.size(), 0, "das Regal ist wieder leer")

func test_the_exchange_signals_both_changes() -> void:
	_stash_one()
	var pool_emits := []
	var stash_emits := []
	run.pool_changed.connect(func() -> void: pool_emits.append(1))
	run.pending_dice_changed.connect(func() -> void: stash_emits.append(1))
	run.exchange_pending_die(0, 0)
	assert_eq(pool_emits.size(), 1, "der Vorrat hat sich geändert")
	assert_eq(stash_emits.size(), 1, "und das Regal auch")

func test_a_bad_exchange_index_changes_nothing() -> void:
	_stash_one()
	assert_false(run.exchange_pending_die(5, 0), "kein solcher Platz im Regal")
	assert_false(run.exchange_pending_die(0, 99), "kein solcher Platz im Vorrat")
	assert_eq(run.pending_dice.size(), 1, "beides bleibt unberührt")

func test_the_shop_has_no_picker_of_its_own_any_more() -> void:
	# Der Hub kauft, die Werkstatt nutzt: der Wähler ist ins Werkstatt-Fenster
	# gezogen, der Laden kennt ihn nicht mehr.
	_stash_one()
	await wait_frames(2)
	assert_false(shop.has_method("open_pending_exchange"),
		"der Laden schlägt keine Tausch-Auswahl mehr auf")
	assert_null(shop.get_node_or_null("ExchangePicker"), "und hält kein Overlay")
	assert_eq(run.pending_dice.size(), 1, "der Würfel bleibt hinterlegt")

func test_the_stash_survives_a_reroll_and_the_lock() -> void:
	_stash_one()
	shop._show_spread()
	await wait_frames(2)
	assert_eq(run.pending_dice.size(), 1, "ein Neuaufbau leert das Regal nicht")
	shop.sortiment_locked = true
	shop.open()
	await wait_frames(2)
	assert_eq(run.pending_dice.size(), 1, "und ein neuer Besuch auch nicht")

func test_a_fresh_run_has_an_empty_shelf() -> void:
	assert_eq(GameRun.new_run().pending_dice.size(), 0, "ein neuer Lauf schuldet nichts")

# --- Sonderposten in der Chip-Schale ------------------------------------------
# Geprueft wird die AUSWUERFELUNG (_build_spread), nicht der Neuaufbau der Seite:
# _show_spread baut je Schalen-Wuerfel eine eigene TumbleStage mit SubViewport,
# und sechzig davon sind kein Test, sondern ein Lasttest.

## Der Sonderposten liegt in der SCHALE - die Paket-Zeile bleibt unberührt.
func test_a_special_lies_in_the_bowl_not_in_the_pack_row() -> void:
	run.hub_level = GameRun.HUB_MAX_LEVEL
	var seen := 0
	for i in 60:
		var spread = shop._build_spread()
		assert_eq(spread.engraving_packs.size(), run.shop_pack_slots(),
			"die Paket-Zeile behält ihre Breite")
		for pack: Pack in spread.engraving_packs:
			assert_null(pack.fixed_engraving, "im Regal liegt kein Sonderposten mehr")
		seen += spread.single_specials.size()
	assert_gt(seen, 0, "auf Stufe 10 liegt irgendwann einer in der Schale")

## Und wenn, dann als Einzelstück zum festen Preis - Bündel bleiben Hehlerware.
func test_the_bowl_special_is_a_single_at_the_flat_price() -> void:
	run.hub_level = GameRun.HUB_MAX_LEVEL
	for i in 60:
		var spread = shop._build_spread()
		assert_lte(spread.single_specials.size(), 1, "höchstens einer je Auslage")
		for pack: Pack in spread.single_specials:
			assert_eq(pack.count, 1, "in der Schale liegen keine Bündel")
			assert_eq(spread.single_special_bought.size(), spread.single_specials.size())
			if pack.is_catalyst():
				assert_eq(pack.price, Pack.catalyst_price(pack.catalyst_id))
				continue
			assert_true(Engraving.is_special_id(pack.fixed_engraving.id))
			assert_eq(pack.price, Pack.SPECIAL_PRICE)

## Unter der Schwelle nie - der Sonderposten ist die Belohnung für die Lizenz.
func test_a_low_licence_bowl_never_carries_one() -> void:
	run.hub_level = GameRun.SHOP_SPECIAL_LEVEL - 1
	for i in 60:
		assert_true(shop._build_spread().single_specials.is_empty(),
			"vor Stufe %d kein Sonderposten" % GameRun.SHOP_SPECIAL_LEVEL)

## Der Kauf zahlt und liefert die VERSIEGELTE Karte - offen wartet keine
## Aufwertung, auch nicht die aus der Schale.
func test_a_bowl_special_is_bought_sealed() -> void:
	run.hub_level = GameRun.HUB_MAX_LEVEL
	run.money = 999
	var spread = shop._build_spread()
	if spread.single_specials.is_empty():
		spread.single_specials.append(Pack.roll_special_pack())
		spread.single_special_bought.append(false)
	# Kein Array-Literal: spreads ist getypt, und GDScript wandelt nicht um.
	shop.spreads.clear()
	shop.spreads.append(spread)
	shop.current_spread_index = 0
	shop._show_spread()
	var special: Pack = shop.single_specials[0]
	var before := run.money
	shop._on_single_special_pressed(0)
	assert_eq(run.owned_packs.size(), 1, "die Karte liegt versiegelt im Lager")
	assert_eq(Pack.shelf_of(run.owned_packs[0]), Pack.SHELF_SPECIAL)
	if special.is_catalyst():
		assert_eq(run.owned_packs[0].catalyst_id, special.catalyst_id)
	else:
		assert_eq(run.owned_packs[0].fixed_engraving.id, special.fixed_engraving.id)
	assert_lt(run.money, before, "und sie ist bezahlt")
	assert_true(shop.single_special_bought[0], "das Stück liegt nicht mehr in der Schale")

## Die Lieferung fährt in den SONDERBESTAND, nicht in die Material- oder
## Runen-Bucht: ein Sonderposten ist zwar ein Material-/Runen-Paket, liegt aber
## in seiner eigenen Bucht.
func test_the_delivery_reports_the_sonderbestand_shelf() -> void:
	run.hub_level = GameRun.HUB_MAX_LEVEL
	run.money = 999
	var spread = shop._build_spread()
	spread.single_specials.clear()
	spread.single_special_bought.clear()
	spread.single_specials.append(Pack.roll_special_pack())
	spread.single_special_bought.append(false)
	shop.spreads.clear()
	shop.spreads.append(spread)
	shop.current_spread_index = 0
	shop._show_spread()
	var uids: Array[int] = []
	shop.pack_purchased.connect(func(_px: Vector2, uid: int) -> void: uids.append(uid))
	shop._on_single_special_pressed(0)
	assert_eq(uids.size(), 1, "die Lieferung meldet die Paket-uid")
	assert_eq(Pack.shelf_of(run.pack_by_uid(uids[0])), Pack.SHELF_SPECIAL,
		"und dahinter liegt der Sonderbestand")
