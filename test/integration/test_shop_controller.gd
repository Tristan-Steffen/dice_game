extends GutTest
## Tier-2-Integrationstests des Shops (ShopController auf shop_panel.tscn).
## Der Shop wird als eigene Szene instanziiert und mit einem ECHTEN GameRun
## verdrahtet (seit der GameRun-Extraktion braucht es kein Spiel-Double mehr,
## das die Kauflogik nachbauen müsste) - die Tests prüfen die Wirkung jedes
## Kaufs direkt am Run-Zustand (Geld, Pool, Charms) bzw. an seinen Signalen.

const ShopPanelScene := preload("res://scenes/shop_panel.tscn")

var shop
var run: GameRun

## Glück der gewünschten Fortschrittsstufe.
static func _luck_of(tier: int) -> int:
	return (tier - 1) * GameRun.LUCK_PER_TIER

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 100
	run.luck = _luck_of(7)
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

func test_open_shows_panel_and_offers_up_to_three_charms():
	assert_true(shop.visible)
	assert_gt(shop.charm_options.size(), 0, "mindestens ein Charm im Angebot")
	assert_true(shop.charm_options.size() <= run.shop_charm_slots(), "höchstens so viele wie die Stufe erlaubt")

func test_owned_charms_never_appear_again():
	# Besitz SPERRT: was im Dock steht, liegt nicht wieder aus.
	run.owned_charms.append(Charm.rabbits_foot())
	for i in 10:
		shop.open()
		assert_gt(shop.charm_options.size(), 0, "das Angebot bleibt gefüllt")
		for option in shop.charm_options:
			assert_ne(option.id, Charm.RABBITS_FOOT, "besessener Charm liegt wieder aus")


## Die Paket-Fläche: sechs Plätze, jede Art auf jedem Platz.
func test_the_pack_area_carries_six_places_on_every_tier():
	for tier in [1, 7, GameRun.TIER_MAX]:
		run.luck = _luck_of(tier)
		shop.spreads.clear()
		shop.open()
		assert_eq(shop.charm_options.size(), 3, "Stufe %d: drei Charms" % tier)
		assert_eq(shop.packs.size(), GameRun.SHOP_PACK_PLACES, "Stufe %d: sechs Pakete" % tier)
		assert_eq(shop.pack_prices.size(), shop.packs.size(), "je Platz ein Preis")
		assert_eq(shop.place_count(), 6)
		for pack in shop.packs:
			assert_true(pack is CardPack or pack is DicePack or pack is ModulePack or pack is Pack,
				"jeder Platz trägt ein Paket")

## Jeder Platz würfelt seine Art unabhängig, im Mittel 3 : 2 : 1.
func test_every_place_rolls_its_kind_three_two_one():
	assert_eq(GameRun.shop_pack_kind_for(0.0), GameRun.LANE_CARDS)
	assert_eq(GameRun.shop_pack_kind_for(0.49), GameRun.LANE_CARDS)
	assert_eq(GameRun.shop_pack_kind_for(0.51), GameRun.LANE_DICE)
	assert_eq(GameRun.shop_pack_kind_for(0.82), GameRun.LANE_DICE)
	assert_eq(GameRun.shop_pack_kind_for(0.84), GameRun.LANE_MODULES)
	assert_eq(GameRun.shop_pack_kind_for(0.999), GameRun.LANE_MODULES)
	run.luck = _luck_of(1)
	var counts := {GameRun.LANE_CARDS: 0, GameRun.LANE_DICE: 0, GameRun.LANE_MODULES: 0}
	for i in 100:
		var spread = shop._build_spread()
		for pack in spread.packs:
			counts[GameRun.store_lane_of(pack)] += 1
	var total := 600.0
	assert_almost_eq(counts[GameRun.LANE_CARDS] / total, 0.5, 0.08, "Karten ~1/2")
	assert_almost_eq(counts[GameRun.LANE_DICE] / total, 1.0 / 3.0, 0.08, "Würfel ~1/3")
	assert_almost_eq(counts[GameRun.LANE_MODULES] / total, 1.0 / 6.0, 0.06, "Module ~1/6")

# --- Paketkauf ----------------------------------------------------------------
# Ein gekauftes Paket wandert ins LAGER; erst das Öffnen würfelt Optionen und Wahlen.

## Stellt die Paket-Plätze der aktuellen Seite fest - das echte Angebot ist zufällig.
func _force_packs(list: Array) -> void:
	var spread = shop.spreads[shop.current_spread_index]
	var typed: Array[Resource] = []
	typed.assign(list)
	spread.packs = typed
	var prices: Array[int] = []
	for pack in typed:
		prices.append(shop._price_of(pack))
	spread.pack_prices = prices
	var bought: Array[bool] = []
	bought.resize(typed.size())
	bought.fill(false)
	spread.pack_bought = bought
	shop._show_spread()

## Karten, Karten, Würfel, Würfel, Modul, Karten - jede Art auf zwei Reihen.
func _mixed() -> Array:
	return [CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_SMALL),
		CardPack.make(CardPack.SORT_MATERIAL, CardPack.SIZE_SMALL),
		DicePack.make(DicePack.SORT_NORMAL, 2),
		DicePack.make(DicePack.SORT_SOUL, 3),
		ModulePack.make(CardPack.SIZE_SMALL, ModulePack.GRADE_COMMON),
		CardPack.make(CardPack.SORT_RUNE, CardPack.SIZE_SMALL)]

## Die Auswahl des zuletzt gekauften Pakets (gekauft ist geöffnet).
func _open_last(dice: bool) -> PackChoice:
	var choice: PackChoice = run.pending_pack_choices.back()
	assert_eq(choice.is_dice(), dice)
	return choice

func test_buying_a_card_pack_opens_it():
	_force_packs(_mixed())
	var pack: CardPack = shop.packs[0]
	var seats: Array = []
	shop.shop_pack_purchased.connect(func(seat: int) -> void: seats.append(seat))
	shop.buy_pack(0)
	assert_eq(run.money, 100 - pack.price)
	assert_true(run.stored_card_packs.is_empty(), "nie ins Lager")
	assert_eq(seats, [0], "der Kauf meldet SEINEN Platz")
	var choice := run.current_pack_choice()
	assert_not_null(choice, "gekauft ist geöffnet")
	assert_eq(choice.option_count(), CardPack.option_count(pack.size))
	run.confirm_pack_choice(choice, [0])
	assert_eq(run.owned_packs.size(), 1, "bestätigt liegt die Karte da")

## Jede Art geht über DENSELBEN Kaufweg: Karten und Würfel öffnen, Module warten im Einbau.
func test_every_kind_buys_through_the_one_path():
	run.money = 500
	_force_packs(_mixed())
	var seats: Array = []
	shop.shop_pack_purchased.connect(func(seat: int) -> void: seats.append(seat))
	for seat in 6:
		shop.buy_pack(seat)
	assert_eq(run.pending_pack_choices.size(), 5, "drei Karten- und zwei Würfel-Pakete")
	assert_false(run.pending_parts.is_empty(), "das Modul-Paket legt seine Module hin")
	assert_eq(run.stored_card_packs.size() + run.stored_dice_packs.size()
		+ run.stored_module_packs.size(), 0, "das Lager bekommt nichts")
	assert_eq(seats, [0, 1, 2, 3, 4, 5], "EIN Signal für jede Art")

func test_pack_offer_is_single_use():
	_force_packs(_mixed())
	shop.buy_pack(0)
	var money_after: int = run.money
	shop.buy_pack(0)  # zweiter Kauf desselben Angebots
	assert_eq(run.money, money_after, "nur einmal abgezogen")
	assert_true(shop.pack_bought[0], "als gekauft vermerkt")

## Ein Kauf läßt den Laden stehen: kein Abgang, kein closed, dieselbe Seite.
func test_a_purchase_leaves_the_shop_untouched():
	run.money = 500
	_force_packs(_mixed())
	var heard: Array = []
	shop.closed.connect(func() -> void: heard.append(true))
	var page: int = shop.current_spread_index
	shop.buy_pack(0)
	shop.buy_pack(2)
	assert_eq(run.pending_pack_choices.size(), 2, "zwei Käufe hintereinander gehen")
	assert_false(shop.leaving(), "der Laden tritt nicht ab")
	assert_true(shop.visible)
	assert_eq(heard.size(), 0)
	assert_eq(shop.current_spread_index, page)
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_STAND,
		"ein Kauf blättert nicht - die Seite bleibt liegen")

## Ein volles Lager sperrt nichts mehr - gekauft wird geöffnet.
func test_a_full_store_blocks_nothing():
	run.money = 5000
	run.debug_fill_store()
	shop.size = Vector2(1068, 1125)
	shop.open()
	_force_packs(_mixed())
	await wait_frames(2)
	assert_eq(shop._place_prices[0].text, ShopController.price_text(shop.pack_prices[0]),
		"das Schild nennt den Preis")
	for seat in [0, 2, 4]:
		shop.buy_pack(seat)
		assert_true(shop.pack_bought[seat], "Platz %d verkauft" % seat)

func test_cannot_buy_pack_without_funds():
	_force_packs(_mixed())
	run.money = 0
	var denied: Array = []
	shop.purchase_denied.connect(func() -> void: denied.append(true))
	for seat in 6:
		shop.buy_pack(seat)
	assert_eq(run.money, 0, "kein Abzug bei zu wenig Geld")
	assert_null(run.current_pack_choice(), "nichts geöffnet")
	assert_true(run.pending_parts.is_empty(), "keine Module")
	assert_eq(denied.size(), 6, "jeder Versuch klingt abgelehnt")

func test_con_artist_cuff_discounts_the_dice_pack_price():
	run.owned_charms.append(Charm.con_artist_cuff())
	_force_packs(_mixed())
	var dice_pack: DicePack = shop.packs[2]
	var price: int = shop.pack_prices[2]
	assert_eq(price, run.shop_price(CharmEffects.die_price(dice_pack.price, run.charm_ids())),
		"die Würfel-Rabatte greifen am Würfel-Paket")
	shop.buy_pack(2)
	assert_eq(run.money, 100 - price)

func test_pack_price_is_raw_price_without_discount():
	_force_packs(_mixed())
	assert_eq(shop.pack_prices[0], shop.packs[0].price, "Karten-Pakete haben feste Preise")
	assert_eq(shop.pack_prices[4], run.module_pack_shop_price(shop.packs[4]),
		"das Modul-Paket seinen Ladenpreis")

func test_bargain_hunter_discounts_every_card_pack():
	run.owned_charms.append(Charm.bargain_hunter())
	_force_packs(_mixed())
	for seat in [0, 1, 5]:
		var pack: CardPack = shop.packs[seat]
		assert_eq(shop.pack_prices[seat], maxi(1, roundi(pack.price * 0.7)),
			"%s: 30 %% guenstiger" % pack.sort)

func test_the_module_pack_sells_even_without_a_free_socket() -> void:
	_force_packs(_mixed())
	for key: String in DiceScoring.HAND_PRIORITY:
		for slot in run.socket_count(key):
			run.stash_part(ComboPart.resistor())
			run.install_pending_part(key, slot)
	assert_eq(run.free_socket_count(), 0)
	shop.buy_pack(4)
	assert_true(shop.pack_bought[4], "volle Steckplätze sperren das Paket nicht")
	assert_false(run.pending_parts.is_empty(), "die Module warten im EINBAU")
	assert_null(run.current_pack_choice(), "ohne Auswahl")

# --- Charmkauf ----------------------------------------------------------------

func test_buy_charm_grants_and_deducts():
	var charm = shop.charm_options[0]
	shop._on_charm_clicked(0)
	assert_eq(run.money, 100 - charm.price, "der Preis seiner Seltenheit")
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
	run.money = 5  # unter dem billigsten Charm ($6)
	shop.open()  # neu bestücken mit wenig Geld
	for button in shop.charm_buttons:
		assert_true(button.disabled, "Charm bei zu wenig Geld nicht kaufbar")

## Das Übertakten ist tot - die Auslage kennt seine Angebote nicht mehr.
func test_the_shop_no_longer_sells_overclocks():
	assert_false(shop.has_method("_on_overclock_buy_pressed"))
	var spread = shop.spreads[shop.current_spread_index]
	assert_false("overclock_offers" in spread, "auch die Auslage kennt sie nicht mehr")

func test_packs_persist_when_flipping_back():
	var first_types: Array = []
	for pack in shop.packs:
		first_types.append(pack.display_name)
	shop._on_page_next_pressed()  # neue Doppelseite (kostet Gebühr)
	shop._on_page_back_pressed()
	var back_types: Array = []
	for pack in shop.packs:
		back_types.append(pack.display_name)
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
	# Rabattmarke kaufen ($8, ungewöhnlich), danach kostet der Hasenfuß ($6) sofort $4.
	_force_charm_options([Charm.cash_discount(), Charm.rabbits_foot()])
	shop._on_charm_clicked(0)
	assert_eq(run.money, 92, "die Rabattmarke selbst kostet den vollen Preis")
	shop._on_charm_clicked(1)
	assert_eq(run.money, 88, "der nächste Charm kostet im selben Besuch 40 % weniger")
	assert_true(shop.charm_bought[0] and shop.charm_bought[1], "beide als gekauft vermerkt")

func test_cash_discount_lowers_charm_price():
	run.owned_charms.append(Charm.cash_discount())
	shop.open()  # Seite mit Rabatt neu bestücken
	run.money = 100
	if shop.charm_options.is_empty():
		pass_test("keine Charm-Angebote auf dieser Seite ausgewürfelt")
		return
	var full: int = shop.charm_options[0].price
	shop._on_charm_clicked(0)
	assert_eq(run.money, 100 - roundi(full * 0.6), "Rabattmarke: 40 % weniger")


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

func test_flip_to_new_page_energys_increasing_fee():
	shop._on_page_next_pressed()  # neue Seite: -$2
	assert_eq(run.money, 98)
	assert_eq(shop.spreads.size(), 2)
	assert_eq(shop.current_spread_index, 1)
	shop._on_page_next_pressed()  # nächste neue Seite: -$3
	assert_eq(run.money, 95)
	assert_eq(shop.spreads.size(), 3)


func test_flip_back_is_free_and_shows_same_offers():
	var first_packs = shop.packs
	shop._on_page_next_pressed()  # -$2
	var second_packs = shop.packs
	shop._on_page_back_pressed()
	assert_eq(run.money, 98, "Zurückblättern kostet nichts")
	assert_true(shop.packs == first_packs, "dieselben Angebote wie zuvor (gleiche Instanz)")
	shop._on_page_next_pressed()  # vor auf BEREITS gesehene Seite
	assert_eq(run.money, 98, "Vorblättern auf bekannte Seite kostet nichts")
	assert_true(shop.packs == second_packs)
	assert_eq(shop.spreads.size(), 2, "keine neue Seite ausgewürfelt")

# --- Sortiment-Sperre ----------------------------------------------------------

func test_locked_shop_keeps_the_same_offers_on_reopen():
	var charms = shop.charm_options
	var packs = shop.packs
	shop._on_lock_pressed()
	assert_true(shop.sortiment_locked)
	shop._on_done_pressed()
	shop.open()
	assert_true(shop.charm_options == charms, "dieselben Charms (gleiche Instanzen)")
	assert_true(shop.packs == packs, "dieselben Pakete")

func test_locked_shop_keeps_bought_marks_on_reopen():
	_force_packs(_mixed())
	shop._on_charm_clicked(0)
	shop.buy_pack(0)
	shop._on_lock_pressed()
	shop._on_done_pressed()
	shop.open()
	assert_true(shop.charm_bought[0], "der gekaufte Charm bleibt vermerkt")
	assert_true(shop.pack_bought[0], "das gekaufte Paket bleibt verkauft")
	var money_after: int = run.money
	shop._on_charm_clicked(0)
	shop.buy_pack(0)
	assert_eq(run.money, money_after, "kein zweiter Kauf über den Besuch hinweg")

func test_locked_shop_keeps_every_flipped_page():
	shop._on_page_next_pressed()  # -$2, zweite Seite
	var second = shop.packs
	shop._on_lock_pressed()
	shop._on_done_pressed()
	shop.open()
	assert_eq(shop.spreads.size(), 2, "beide Seiten bleiben stehen")
	assert_eq(shop.current_spread_index, 1, "der Laden öffnet, wo er zuging")
	assert_true(shop.packs == second)
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
	shop._on_charm_clicked(0)  # Kauf auf Seite 1
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
	var packs = shop.packs
	shop._on_done_pressed()
	shop.reopen()
	assert_true(shop.visible)
	assert_true(shop.charm_options == charms, "dieselben Charms (gleiche Instanzen)")
	assert_true(shop.packs == packs)
	assert_eq(shop.spreads.size(), 1, "keine zweite Auslage")

func test_reopen_keeps_bought_marks_and_the_page():
	_force_packs(_mixed())
	shop._on_charm_clicked(0)
	shop.buy_pack(0)
	shop._on_page_next_pressed()  # zweite Seite
	shop._on_done_pressed()
	shop.reopen()
	assert_eq(shop.current_spread_index, 1, "der Laden öffnet, wo er zuging")
	assert_true(shop.spreads[0].charm_bought[0], "der gekaufte Charm bleibt vermerkt")
	assert_true(shop.spreads[0].pack_bought[0])
## Das Abtreten für eine Paket-Öffnung ist gestorben (2026-11-13): es gibt keinen Weg dorthin.
func test_the_shop_no_longer_suspends():
	assert_false(shop.has_method("suspend"))
	assert_false(shop.has_method("suspended"))
	assert_false(shop.has_method("cancel_suspend"))

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

func test_the_footer_stays_inside_the_panel_on_every_tier() -> void:
	# Regression: auf hohen Stufen schob das Lager (bis zu 7 Pakete) den Fuß aus
	# dem Panel - der Shop war ohne "Fertig" nicht mehr verlassbar.
	shop.size = Vector2(1068, 1125)  # Maß der Hub-Fläche auf dem Tisch-Display
	for level in range(1, GameRun.TIER_MAX + 1):
		run.luck = _luck_of(level)
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
	assert_signal_emitted(shop, "closed")
	# Die SEITE steht noch: auf ihr spielt die Abräum-Zeremonie der Auslage. Erst
	# finish_close() gibt die Fläche ab.
	assert_true(shop.visible)
	shop.finish_close()
	assert_false(shop.visible)


func test_every_change_of_the_area_is_reported() -> void:
	_force_packs(_mixed())
	var beats := []
	shop.vitrine_changed.connect(func() -> void: beats.append(1))
	shop.buy_pack(0)
	assert_gt(beats.size(), 0, "der Kauf meldet die neue Auslage")
	beats.clear()
	shop._on_page_next_pressed()
	assert_gt(beats.size(), 0, "und das Blättern auch")

# --- Die PAKET-FLÄCHE: zwei Reihen zu drei Plätzen ------------------------------

## Gemessen an der echten Werkbank (scene_root._data_cell_lying_px).
const LIE_PX := Vector2(60.75, 40.5)

func _lay_out_page() -> void:
	shop.size = Vector2(1069, 1125)
	shop.data_cell_lie_px = LIE_PX
	shop.open()

## Die Bänder der Seite in globalen Display-Pixeln (Kopfzeile inbegriffen) - der
## jüngste Aufbau zählt, der alte hängt bis zum Frame-Ende noch im Baum.
func _band_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var margin: Control = shop.get_child(shop.get_child_count() - 1)
	for band in margin.get_child(0).get_children():
		out.append((band as Control).get_global_rect())
	return out

func test_the_bands_stand_on_every_tier() -> void:
	shop.size = Vector2(1068, 1125)
	run.luck = _luck_of(1)
	shop.sortiment_locked = false
	shop.spreads.clear()
	shop.open()
	await wait_frames(2)
	var low := _band_rects()
	assert_eq(low.size(), 5, "Kopf, Charms, Pakete, Auskunfts-Band, Fuß")
	run.luck = _luck_of(GameRun.TIER_MAX)
	shop.spreads.clear()
	shop.open()
	await wait_frames(2)
	var high := _band_rects()
	assert_eq(high.size(), low.size(), "dieselben Bänder")
	for i in low.size():
		assert_true(high[i].is_equal_approx(low[i]),
			"Band %d steht auf jeder Stufe gleich (%s vs %s)" % [i, low[i], high[i]])
	assert_eq(shop.charm_options.size(), 3, "auch auf Stufe 10 ist das Regal voll")

## Zwei Reihen zu drei Plätzen auf dem Spaltenraster der Charms.
func test_the_places_stand_in_two_rows_of_three() -> void:
	assert_almost_eq(ShopController.column_width_in(320.0, 10.0), 100.0, 0.001)
	assert_almost_eq(ShopController.column_x(320.0, 10.0, 2), 220.0, 0.001)
	_lay_out_page()
	await wait_frames(2)
	var anchors: Array[Vector2] = shop.place_anchors()
	assert_eq(anchors.size(), 6, "sechs Plätze")
	for i in 3:
		var card: Rect2 = shop.charm_buttons[i].get_global_rect()
		assert_almost_eq(anchors[i].x, card.get_center().x, 0.5, "Platz %d unter Karte %d" % [i, i])
		assert_almost_eq(anchors[i + 3].x, anchors[i].x, 0.5, "Spalte %d in beiden Reihen" % i)
		assert_almost_eq(anchors[i + 3].y - anchors[3].y, 0.0, 0.5, "die untere Reihe liegt gerade")
		assert_almost_eq(anchors[i].y - anchors[0].y, 0.0, 0.5, "die obere auch")
	assert_gt(anchors[3].y, anchors[0].y, "die zweite Reihe liegt UNTER der ersten")
	var charms: Rect2 = shop.content_root.get_global_rect()
	assert_lte(charms.end.y, shop.place_rects()[0].position.y, "die Charms stehen über den Paketen")
	assert_null(shop.find_child("DieNets", true, false), "die Würfel-Bucht ist fort")
	assert_null(shop.find_child("SlitRow", true, false), "und die Gravuren-Zeile")

## Name und Preis stehen ÜBER dem Paket, die Auskunft darunter - für jede Art.
func test_name_and_price_stand_over_the_pack_and_the_info_under_it() -> void:
	_lay_out_page()
	_force_packs(_mixed())
	await wait_frames(2)
	var rects: Array[Rect2] = shop.place_rects()
	for seat in 6:
		var pack: Resource = shop.packs[seat]
		var name_label: Label = shop._place_names[seat]
		var price: Label = shop._place_prices[seat]
		var info: Label = shop._place_infos[seat]
		assert_eq(name_label.text, pack.display_name, "der Name (%d)" % seat)
		assert_eq(name_label.modulate, ShopController.ware_tint(pack), "in seiner Farbe (%d)" % seat)
		assert_eq(price.text, ShopController.price_text(shop.pack_prices[seat]), "der Preis (%d)" % seat)
		assert_eq(info.text, ShopController.ware_info(pack), "die Auskunft (%d)" % seat)
		assert_lte(price.get_global_rect().end.y, rects[seat].position.y + 0.5,
			"Name und Preis über dem Paket (%d)" % seat)
		assert_gte(info.get_global_rect().position.y, rects[seat].end.y - 0.5,
			"die Auskunft darunter (%d)" % seat)
		assert_almost_eq(info.get_global_rect().get_center().x, rects[seat].get_center().x, 0.5)

## Jeder Platz ist für das GRÖSSTE Paket bemessen: Karte wie Schatulle quer.
func test_every_place_fits_the_largest_pack() -> void:
	_lay_out_page()
	await wait_frames(2)
	var small: Vector2 = shop.place_pad_size()
	assert_almost_eq(small.x, LIE_PX.x * PackDrawerView.CASSETTE_SCALE * ShopController.PLACE_ROOM,
		0.01, "die liegende Karte samt Luft")
	shop.dice_case_across_px = small.y * 2.0
	await wait_frames(2)
	assert_almost_eq(shop.place_pad_size().y, small.y * 2.0 * ShopController.CASE_ROOM, 0.01,
		"eine breitere Schatulle macht den Platz tiefer")
	for rect in shop.place_rects():
		assert_almost_eq(rect.size.y, shop.place_pad_size().y, 0.5, "und jeden Platz gleich")

func test_the_place_stock_stays_index_true_across_a_purchase() -> void:
	_lay_out_page()
	_force_packs(_mixed())
	await wait_frames(2)
	run.money = 500
	var before: Array = shop.place_stock()
	shop.buy_pack(2)
	await wait_frames(2)
	var after: Array = shop.place_stock()
	assert_eq(after.size(), before.size(), "der Platz verschwindet nicht, er wird leer")
	assert_null(after[2], "verkauft = leerer Platz")
	assert_eq(after[3], before[3], "der Nachbar rückt nicht auf")
	assert_eq(shop._place_prices[2].text, "", "verkauft heißt: kein Schild mehr")
	assert_eq(shop._place_names[2].text, "", "und kein Name")

func test_the_places_are_byte_stable_across_purchase_and_flip() -> void:
	_lay_out_page()
	await wait_frames(2)
	var before: Array[Rect2] = shop.place_rects()
	assert_eq(before.size(), 6)
	run.money = 500
	shop.buy_pack(0)
	await wait_frames(2)
	for i in before.size():
		assert_true(shop.place_rects()[i].is_equal_approx(before[i]),
			"ein verkaufter Platz bleibt stehen (%d)" % i)
	shop._on_page_next_pressed()
	await wait_frames(2)
	shop._on_page_back_pressed()
	await wait_frames(2)
	for i in before.size():
		assert_true(shop.place_rects()[i].is_equal_approx(before[i]),
			"geblättert wird die Ware, nicht das Möbel (%d)" % i)

func test_the_ware_price_turns_red_when_the_purse_is_short() -> void:
	_lay_out_page()
	_force_packs(_mixed())
	await wait_frames(2)
	run.money = 999
	await wait_frames(2)
	assert_eq(shop._place_prices[0].modulate, ShopController.NEON_GOLD, "bezahlbar")
	run.money = 0
	await wait_frames(2)
	assert_eq(shop._place_prices[0].modulate, CasinoStyle.RED,
		"und der Geldstand färbt es nach, ohne daß jemand pollt")

## Der Laden meldet die Stellplatz-Mitte - dort startet ein gekauftes Stück.
func test_a_pack_purchase_starts_at_its_own_place() -> void:
	_lay_out_page()
	await wait_frames(2)
	var rects: Array[Rect2] = shop.place_rects()
	for seat in 6:
		assert_true(rects[seat].has_point(shop.place_anchor(seat)), "Platz %d" % seat)

func test_the_pack_seat_is_a_real_buy_button() -> void:
	_lay_out_page()
	_force_packs(_mixed())
	await wait_frames(2)
	var button: Button = shop._place_pads[3].get_parent()
	button.pressed.emit()  # der ECHTE Klickweg
	assert_true(shop.pack_bought[3], "der Klick auf den Platz kauft")

# --- Sonder-Karte ---------------------------------------------------------------

## Die Sonder-Karte ERSETZT einen zufälligen Platz - die Fläche bleibt gleich voll.
func test_a_special_card_replaces_a_random_place() -> void:
	run.luck = _luck_of(GameRun.TIER_MAX)
	var seen := {}
	for i in 120:
		var spread = shop._build_spread()
		assert_eq(spread.packs.size(), GameRun.SHOP_PACK_PLACES, "die Fläche behält ihre Plätze")
		var specials := 0
		for seat in spread.packs.size():
			if spread.packs[seat] is Pack:
				specials += 1
				seen[seat] = true
				assert_false((spread.packs[seat] as Pack).is_repair(), "nie die Reparatur-Karte")
		assert_lte(specials, 1, "höchstens eine je Auslage")
	assert_gt(seen.size(), 2, "sie liegt mal hier, mal dort - nicht immer hinten")

## Unter der Schwelle nie - die Sonder-Karte kommt erst mit der Stufe.
func test_a_low_tier_shop_never_carries_one() -> void:
	run.luck = _luck_of(GameRun.SHOP_SPECIAL_TIER - 1)
	for i in 60:
		for pack in shop._build_spread().packs:
			assert_false(pack is Pack, "vor Stufe %d keine Sonder-Karte" % GameRun.SHOP_SPECIAL_TIER)

## Der Kauf zahlt und liefert die Karte versiegelt ins Magazin.
func test_the_special_card_goes_straight_to_the_magazine() -> void:
	run.money = 999
	var list := _mixed()
	list[3] = Pack.catalyst(Pack.CATALYST_COOL)
	_force_packs(list)
	var seats: Array = []
	shop.shop_pack_purchased.connect(func(seat: int) -> void: seats.append(seat))
	var before := run.money
	shop.buy_pack(3)
	assert_eq(run.owned_packs.size(), 1, "die Karte liegt im Magazin")
	assert_eq(seats, [3], "derselbe Melder wie jede Art")
	assert_eq(shop.pack_at(3).pack_uid, run.owned_packs[0].pack_uid,
		"scene_root findet die Karte über ihren Platz")
	assert_null(run.current_pack_choice(), "keine Auswahl - sie ist eine Einzelkarte")
	assert_lt(run.money, before, "und sie ist bezahlt")
	assert_true(shop.pack_bought[3], "sie liegt nicht mehr aus")

# --- Die Auskunft im Band --------------------------------------------------------

func test_the_band_names_the_pack_under_the_pointer() -> void:
	_lay_out_page()
	_force_packs(_mixed())
	await wait_frames(2)
	for seat in 6:
		var pack: Resource = shop.packs[seat]
		shop.set_place_hover(seat)
		assert_true(shop.place_info.visible, "gegriffen heißt: das Band spricht (%d)" % seat)
		assert_eq(shop.place_info_name.text, pack.display_name)
		assert_eq(shop.place_info_body.text, ShopController.ware_info(pack))
	shop.set_place_hover(2, "Zelle: +3")
	assert_eq(shop.place_info_body.text, "Zelle: +3", "die Netz-Zelle übersteuert die Beschreibung")
	shop.set_place_hover(-1)
	assert_false(shop.place_info.visible, "ohne Zeiger steht dort NICHTS")

func test_the_band_stands_under_the_pack_area() -> void:
	_lay_out_page()
	await wait_frames(2)
	var flank: Rect2 = shop.place_flank_rect()
	var rects: Array[Rect2] = shop.place_rects()
	assert_gt(flank.size.y, 0.0, "das Band steht")
	assert_gte(flank.position.y, rects[5].end.y, "UNTER den Paketen, nicht darauf")
	assert_lt(flank.end.y, shop.get_global_rect().end.y, "innerhalb der Seite")

func test_a_sold_place_explains_nothing() -> void:
	_lay_out_page()
	_force_packs(_mixed())
	await wait_frames(2)
	run.money = 500
	shop.set_place_hover(1)
	assert_true(shop.place_info.visible)
	shop.buy_pack(1)
	shop.set_place_hover(1)
	assert_false(shop.place_info.visible, "auf einem leeren Platz liegt nichts, was spräche")

func test_the_longest_real_description_fits_the_band() -> void:
	_lay_out_page()
	await wait_frames(2)
	var list := _mixed()
	list[0] = _longest_pack()
	_force_packs(list)
	shop.set_place_hover(0)
	assert_eq(shop.place_info_body.text, CardPack.info_body(list[0]), "nichts wird beschnitten")
	var block: Rect2 = shop.place_flank_rect()
	assert_lte(shop.place_info_body.position.y + shop.place_info_body.size.y, block.size.y + 0.5,
		"und der Block bleibt im Band")
	assert_gte(shop.place_info_name.position.y, -0.5, "oben läuft er auch nicht heraus")

## Die Auskunft UNTER jedem Paket paßt ungeschnitten - für das längste jeder Art.
func test_the_longest_info_fits_under_its_pack() -> void:
	_lay_out_page()
	await wait_frames(2)
	var list := _mixed()
	list[0] = _longest_pack()
	_force_packs(list)
	var font := ThemeDB.fallback_font
	for seat in 6:
		var info: Label = shop._place_infos[seat]
		var px := info.get_theme_font_size("font_size")
		assert_lte(ShopController.wrapped_height(font, info.text, info.size.x, px,
			info.get_theme_constant("line_spacing")), info.size.y + 0.5,
			"die Auskunft paßt (%d)" % seat)

## Das Paket mit der längsten Auskunft, das im Laden je liegen kann.
func _longest_pack() -> CardPack:
	var worst: CardPack = null
	for pack_sort: String in CardPack.SORTS:
		for pack_size in CardPack.max_size(pack_sort) + 1:
			var pack := CardPack.make(pack_sort, pack_size)
			if worst == null or CardPack.info_body(pack).length() \
					> CardPack.info_body(worst).length():
				worst = pack
	return worst

func test_the_hover_moves_no_band() -> void:
	_lay_out_page()
	await wait_frames(2)
	var bands := _band_rects()
	var seats: Array[Rect2] = shop.place_rects()
	shop.set_place_hover(0)
	await wait_frames(2)
	var after := _band_rects()
	assert_eq(after.size(), bands.size())
	for i in bands.size():
		assert_true(after[i].is_equal_approx(bands[i]),
			"Band %d steht mit und ohne Auskunft gleich (%s vs %s)" % [i, after[i], bands[i]])
	for i in seats.size():
		assert_true(shop.place_rects()[i].is_equal_approx(seats[i]), "und die Plätze (%d)" % i)

# --- Die frisch gebaute Fläche hat noch kein Rechteck --------------------------

func test_a_freshly_built_area_says_it_does_not_stand_yet() -> void:
	_lay_out_page()
	await wait_frames(2)
	assert_true(shop.places_laid_out(), "die ausgelegte Fläche steht")
	shop.rebuild_places()
	assert_false(shop.places_laid_out(),
		"frische Knöpfe haben noch kein Rechteck - hier darf niemand messen")
	await wait_frames(2)
	assert_true(shop.places_laid_out(), "und im nächsten Layout steht sie wieder")

func test_after_a_rebuild_the_places_stand_apart() -> void:
	_lay_out_page()
	await wait_frames(2)
	shop.rebuild_places()
	await wait_frames(2)
	var anchors: Array = shop.place_anchors()
	assert_eq(anchors.size(), 6)
	for i in [1, 2, 4, 5]:
		assert_gt((anchors[i] as Vector2).x, (anchors[i - 1] as Vector2).x,
			"Platz %d liegt NEBEN seinem Nachbarn, nicht auf ihm" % i)
# --- Die zwei Ankunfts-Grade ---------------------------------------------------
# Steigen heißt Auftritt, Liegenbleiben heißt: nichts geschah. Der Laden
# entscheidet nur - gefahren wird die Auslage von scene_root.

func test_a_fresh_shop_raises_its_goods() -> void:
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_RISE,
		"die erste Auslage steigt auf")

func test_every_page_change_raises_its_goods() -> void:
	shop._on_page_next_pressed()  # frische Doppelseite
	assert_eq(shop.spreads.size(), 2, "eine zweite Seite liegt auf")
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_RISE,
		"eine neue Seite steigt auf")
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
		"gesperrt wird nichts gewürfelt und nichts gehoben")
	# Die Ware ist dieselbe - aber wenn die Bucht seit dem Abgang körperlich LEER
	# ist, kommt sie trotzdem an. Die physische Regel schlägt die Seiten-Regel.
	assert_eq(ShopController.grade_on_stand(shop.vitrine_grade(), false),
		ShopController.GRADE_RISE, "eine leere Bucht zeigt sie als Ankunft")

func test_a_reentry_shows_the_same_standing_shop() -> void:
	shop.close()
	shop.reopen()
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_STAND,
		"der Laden ist derselbe, der Spieler geht nur noch einmal hinein")
	assert_eq(ShopController.grade_on_stand(shop.vitrine_grade(), false),
		ShopController.GRADE_RISE,
		"aber seine Ware ist hinausgefahren - der Wiedereintritt ist eine Ankunft")
	assert_eq(ShopController.grade_on_stand(shop.vitrine_grade(), true),
		ShopController.GRADE_STAND,
		"eine bloß verdrängte Auslage behält ihre Körper und bleibt liegen")

func test_an_unlocked_visit_raises_again() -> void:
	shop.close()
	shop.open()  # ohne Sperre würfelt jeder Besuch frisch
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_RISE)


func test_a_fresh_run_forgets_which_page_was_standing() -> void:
	shop.run = GameRun.new_run()
	shop.open()
	assert_eq(shop.vitrine_grade(), ShopController.GRADE_RISE,
		"ein frischer Lauf bekommt einen frisch gewürfelten Laden - er tritt auf")

# --- Die Preiszeile ------------------------------------------------------------

func test_the_price_line_is_a_pure_function() -> void:
	assert_eq(ShopController.price_text(7), "$7")
	assert_eq(ShopController.price_text(0), "$0")

func test_the_price_tint_says_whether_it_is_payable() -> void:
	assert_eq(ShopController.price_tint(5, 10), ShopController.NEON_GOLD, "bezahlbar")
	assert_eq(ShopController.price_tint(5, 5), ShopController.NEON_GOLD, "genau genug reicht")
	assert_eq(ShopController.price_tint(5, 4), CasinoStyle.RED, "zu teuer")


func test_a_dark_glow_is_lifted_to_a_readable_tint() -> void:
	# Vakuum glüht schwarz - als Schriftfarbe wäre das ein Loch auf dunklem Grund.
	var raw := Essence.glow_for(Essence.VACUUM)
	var lifted := ShopController.soul_tint(Essence.VACUUM)
	assert_lt(raw.get_luminance(), ShopController.SOUL_MIN_LUMINANCE, "wirklich dunkel")
	assert_gt(lifted.get_luminance(), raw.get_luminance(), "und wird angehoben")
	# Ein helles Glühen bleibt, wie es ist - der Ton IST die Auskunft.
	var bright := Essence.glow_for(Essence.ARGON)
	if bright.get_luminance() >= ShopController.SOUL_MIN_LUMINANCE:
		assert_eq(ShopController.soul_tint(Essence.ARGON), bright)

# --- Die Charm-Karte tauscht Bild gegen Text ------------------------------------
# Ruhezustand: Name, Modell, Preis. Hover: an der Stelle des Modells die volle
# Beschreibung. Das Rechteck der Karte rührt sich dabei nicht.

func test_the_card_shows_its_model_at_rest_and_no_text() -> void:
	shop.size = Vector2(1068, 1125)
	shop.open()
	await wait_frames(2)
	for i in shop.charm_buttons.size():
		assert_true(shop.charm_stages[i].visible, "im Ruhezustand steht das Modell (%d)" % i)
		assert_false(shop.charm_effects[i].visible, "und kein Text (%d)" % i)

func test_hovering_swaps_the_model_for_the_whole_effect_text() -> void:
	shop.size = Vector2(1068, 1125)
	shop.open()
	await wait_frames(2)
	shop.set_charm_hover(0, true)
	assert_false(shop.charm_stages[0].visible, "das Modell weicht")
	assert_true(shop.charm_effects[0].visible, "und der Text tritt an seine Stelle")
	assert_eq(shop.charm_effects[0].source, shop.charm_options[0].description,
		"ungekürzt - es gibt keinen Schirm, der nachreichte")
	# Die Nachbarn bleiben, wie sie waren: gehovert ist immer nur eine Karte.
	for i in range(1, shop.charm_buttons.size()):
		assert_true(shop.charm_stages[i].visible, "der Nachbar zeigt weiter sein Modell (%d)" % i)
	shop.set_charm_hover(0, false)
	assert_true(shop.charm_stages[0].visible, "und zurück")
	assert_false(shop.charm_effects[0].visible)

func test_the_card_rect_survives_the_swap_byte_identically() -> void:
	shop.size = Vector2(1068, 1125)
	shop.open()
	await wait_frames(2)
	var before: Array[Rect2] = []
	for card in shop.charm_buttons:
		before.append(card.get_global_rect())
	shop.set_charm_hover(0, true)
	await wait_frames(2)
	for i in shop.charm_buttons.size():
		assert_eq(shop.charm_buttons[i].get_global_rect(), before[i],
			"der Tausch bewegt kein Rechteck (%d)" % i)
	# Auch der Name und der Preis stehen still.
	var column := shop.charm_buttons[0].get_child(0) as Control
	var name_y: float = (column.get_child(0) as Control).global_position.y
	var price_y: float = (column.get_child(2) as Control).global_position.y
	shop.set_charm_hover(0, false)
	await wait_frames(2)
	assert_almost_eq((column.get_child(0) as Control).global_position.y, name_y, 0.01,
		"der Name bleibt oben stehen")
	assert_almost_eq((column.get_child(2) as Control).global_position.y, price_y, 0.01,
		"und der Preis unten")

func test_a_sold_card_swaps_just_the_same() -> void:
	# Der Text ist bei einer gesperrten Karte erst recht die einzige Auskunft.
	shop.size = Vector2(1068, 1125)
	shop.open()
	await wait_frames(2)
	shop._on_charm_clicked(0)
	await wait_frames(2)
	assert_true(shop.charm_buttons[0].disabled, "die gekaufte Karte ist gesperrt")
	assert_gt(shop.charm_buttons[0].get_signal_connection_list("mouse_entered").size(), 0,
		"ihr Hover ist trotzdem verdrahtet - ein gesperrter Knopf meldet ihn weiter")
	shop.set_charm_hover(0, true)
	assert_true(shop.charm_effects[0].visible, "und tauscht trotzdem auf ihren Text")

func test_every_card_reports_its_own_hover() -> void:
	# Der Zeiger liegt auf dem Tisch; die Bewegung wird in den SubViewport
	# weitergeleitet, also meldet der Kartenknopf seinen Hover selbst.
	shop.size = Vector2(1068, 1125)
	shop.open()
	await wait_frames(2)
	for i in shop.charm_buttons.size():
		assert_gt(shop.charm_buttons[i].get_signal_connection_list("mouse_entered").size(), 0,
			"Eintritt verdrahtet (%d)" % i)
		assert_gt(shop.charm_buttons[i].get_signal_connection_list("mouse_exited").size(), 0,
			"Austritt verdrahtet (%d)" % i)
		assert_ne(shop.charm_buttons[i].mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"und der Knopf sieht die Maus überhaupt (%d)" % i)

func test_every_real_description_fits_the_one_card_grade() -> void:
	# Der EINE Grad aller Karten muß jede echte Beschreibung umgebrochen tragen.
	shop.size = Vector2(1068, 1125)
	run.luck = _luck_of(GameRun.TIER_MAX)
	shop.spreads.clear()
	shop.open()
	await wait_frames(2)
	var font := ThemeDB.fallback_font
	var text_w: float = shop._card_text_width()
	var block: float = shop.card_mid_height()
	var px: int = shop.card_effect_px()
	var worst := ""
	for charm in Charm.all():
		if WorkshopView.text_block_height(font, charm.description, text_w, px, 0) > block:
			worst = charm.description
	assert_eq(worst, "", "keine einzige Beschreibung fällt aus der Mittelfläche")

func test_every_card_writes_the_same_grade() -> void:
	shop.size = Vector2(1068, 1125)
	shop.open()
	await wait_frames(2)
	var effect_px: int = shop.card_effect_px()
	for effect in shop.charm_effects:
		assert_eq(effect.font_px, effect_px,
			"die Wirkung steht auf jeder Karte gleich groß")

func test_the_mid_area_is_the_same_on_every_card() -> void:
	shop.size = Vector2(1068, 1125)
	shop.open()
	await wait_frames(2)
	var block: float = shop.card_mid_height()
	for i in shop.charm_effects.size():
		assert_almost_eq(shop.charm_effects[i].custom_minimum_size.y, block, 0.01,
			"die Mittelfläche ist fix - die Karten bleiben bündig (%d)" % i)

# --- Die Hierarchie des Fußes ---------------------------------------------------

func test_done_is_the_one_filled_button_of_the_page() -> void:
	await wait_frames(2)
	var done: StyleBoxFlat = shop.done_button.get_theme_stylebox("normal")
	assert_almost_eq(done.bg_color.r, ShopController.NEON_GOLD.r, 0.01,
		"Fertig steht auf sattem Gold")
	assert_eq(shop.done_button.get_theme_color("font_color"), CasinoStyle.INK,
		"und trägt dunkle Schrift - die Umkehr IST der Rang")

func test_an_open_pager_carries_its_fee() -> void:
	# Die Pfeile tragen ihre Gebühr selbst - mehr sagt niemand dazu.
	run.luck = _luck_of(1)
	shop.spreads.clear()
	shop.open()
	await wait_frames(2)
	assert_eq(shop.page_next_button.text, "$2 ›", "offen: die Gebühr steht am Pfeil")

# --- Das Hinterlegen und der Tausch -------------------------------------------------
# Der Laden BUCHT weiter; gewählt wird der Pool-Platz am VORRAT - der Neuzugang
# wird aus dem Ausgabefach auf den Sitz gezogen, den er ersetzt.

func _stash_one() -> DieDefinition:
	# Paket-Würfel gehen nicht mehr durchs Ausgabefach - der Tausch lebt für die übrigen Quellen.
	run.stash_die(run.owned_pool[0], 0)
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
	# Der Hub kauft, der Vorrat nimmt auf: der Laden kennt keinen Wähler.
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
# --- Der Laden schließt, seine SEITE bleibt stehen ------------------------------
# Auf ihr spielt die Abräum-Zeremonie der Auslage. Die Spiel-Logik wartet nicht,
# nur der Seitenwechsel.

func test_closing_keeps_the_page_standing_and_dead() -> void:
	_lay_out_page()
	await wait_frames(2)
	var heard: Array = []
	shop.closed.connect(func() -> void: heard.append(true))
	shop.close()
	assert_eq(heard.size(), 1, "die Spiel-Logik hört sofort")
	assert_true(shop.visible, "die Ladenseite steht noch - dort spielt der Abgang")
	assert_true(shop.leaving(), "und sie ist tot")
	shop.close()
	assert_eq(heard.size(), 1, "ein Laden schließt nur einmal")
	shop.finish_close()
	assert_false(shop.visible, "erst finish_close gibt die Fläche ab")
	assert_false(shop.leaving())

func test_a_reopening_shop_aborts_a_standing_page_hard() -> void:
	_lay_out_page()
	await wait_frames(2)
	shop.close()
	assert_true(shop.leaving())
	shop.reopen()
	assert_false(shop.leaving(), "ein Wieder-Eintritt bricht den Abgang hart ab")
	assert_true(shop.visible, "und deckt frisch auf")
	shop.finish_close()
	assert_true(shop.visible, "ein Nachzügler des alten Abgangs schließt nichts mehr")

func test_a_displaced_page_that_closes_never_comes_back() -> void:
	# Der Laden raeumt ab, eine fremde Seite verdraengt ihn - danach ist er WIRKLICH
	# zu und die Seitenregel holt kein totes Standbild zurueck.
	var hub := HubView.new()
	add_child_autofree(hub)
	hub.size = Vector2(600, 600)
	await wait_frames(2)
	var other := Panel.new()
	other.visible = false
	hub.attach_panel(other)
	var page := Panel.new()
	page.visible = true
	hub.attach_panel(page)
	other.visible = true  # verdraengt die Seite
	assert_false(page.visible, "die Seite ist verdrängt")
	hub.forget_page(page)
	other.visible = false
	assert_false(page.visible, "und sie kehrt nicht zurück")

func test_a_closing_shop_stops_pulling_anything_after() -> void:
	_lay_out_page()
	await wait_frames(2)
	var pages: Array = []
	shop.vitrine_changed.connect(func() -> void: pages.append(true))
	shop.close()
	run.add_money(50)
	run.charms_changed.emit()
	await wait_frames(2)
	assert_eq(pages.size(), 0, "eine abräumende Seite baut nichts mehr um")

# --- Verträge im Laden (Seite 42) -------------------------------------------------

func _sign(ids: Array) -> void:
	var typed: Array[String] = []
	typed.assign(ids)
	run.sign_clauses(typed)
	shop.spreads.clear()
	shop.open()

## Leere Regale: die hinteren Plätze stehen leer wie verkauft, die Fläche bleibt.
func test_empty_shelves_leave_the_last_places_empty() -> void:
	_sign([DealClause.EMPTY_SHELVES])
	assert_eq(run.shop_packs_offered(), GameRun.SHOP_PACK_PLACES - GameRun.EMPTY_SHELVES_CUT)
	assert_eq(shop.packs.size(), GameRun.SHOP_PACK_PLACES, "die Plätze bleiben")
	for seat in GameRun.SHOP_PACK_PLACES:
		assert_eq(shop.pack_bought[seat], seat >= run.shop_packs_offered(),
			"Platz %d" % seat)
	assert_null(shop.place_stock()[GameRun.SHOP_PACK_PLACES - 1], "der letzte steht leer")

## Die Sonder-Karte meidet die geleerten Plätze.
func test_a_special_never_lands_on_an_emptied_place() -> void:
	_sign([DealClause.EMPTY_SHELVES, DealClause.SPECIAL_DELIVERY])
	for i in 40:
		var spread = shop._build_spread()
		for seat in range(run.shop_packs_offered(), spread.packs.size()):
			assert_false(spread.packs[seat] is Pack, "kein Sonderposten auf Platz %d" % seat)

func test_shelf_warmer_lays_out_only_common_charms() -> void:
	_sign([DealClause.SHELF_WARMER])
	for charm in shop.charm_options:
		assert_eq(charm.rarity, Charm.RARITY_COMMON)

func test_soul_market_fills_the_dice_packs_with_souls() -> void:
	_sign([DealClause.SOUL_MARKET])
	run.money = 500
	_force_packs(_mixed())
	shop.buy_pack(2)
	for die in _open_last(true).options:
		assert_ne((die as DieDefinition).essence_id, "")

func test_free_flip_costs_nothing() -> void:
	_sign([DealClause.FREE_FLIP])
	assert_eq(shop._next_flip_fee(), 0)

func test_special_delivery_puts_a_special_on_the_shelf() -> void:
	_sign([DealClause.SPECIAL_DELIVERY])
	var specials := 0
	for pack in shop.packs:
		if pack is Pack:
			specials += 1
	assert_eq(specials, 1)
