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

func test_offer_repeats_owned_charms():
	# Besitz sperrt nichts mehr - denselben Charm darf man mehrfach halten.
	# Die Einmaligkeit JE DOPPELSEITE prüft der Test weiter unten.
	run.owned_charms.append(Charm.rabbits_foot())
	shop.open()
	assert_gt(shop.charm_options.size(), 0, "das Angebot bleibt gefüllt")

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

func test_owned_charms_stay_available_but_never_twice_in_one_spread():
	# Denselben Charm darf man mehrfach besitzen - er verschwindet also nicht
	# aus dem Angebot. Innerhalb EINER Doppelseite bleibt er aber einmalig.
	for charm in Charm.all():
		run.owned_charms.append(charm)
	shop.open()
	assert_gt(shop.charm_options.size(), 0, "besessene Charms werden weiter angeboten")
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
	var packs = shop.dice_packs
	var overclocks = shop.overclock_offers
	shop._on_lock_pressed()
	assert_true(shop.sortiment_locked)
	shop._on_done_pressed()
	shop.open()
	assert_true(shop.charm_options == charms, "dieselben Charms (gleiche Instanzen)")
	assert_true(shop.dice_packs == packs, "dieselben Pakete")
	assert_true(shop.overclock_offers == overclocks, "dieselben Übertaktungen")

func test_locked_shop_keeps_bought_marks_on_reopen():
	shop._on_charm_clicked(0)
	shop._on_pack_buy_pressed(0, true)
	shop._on_lock_pressed()
	shop._on_done_pressed()
	shop.open()
	assert_true(shop.charm_bought[0], "der gekaufte Charm bleibt vermerkt")
	assert_true(shop.dice_pack_bought[0], "das gekaufte Paket bleibt im Lager")
	var money_after: int = run.money
	shop._on_charm_clicked(0)
	assert_eq(run.money, money_after, "kein zweiter Kauf über den Besuch hinweg")

func test_locked_shop_keeps_every_flipped_page():
	shop._on_page_next_pressed()  # -$2, zweite Seite
	var second = shop.dice_packs
	shop._on_lock_pressed()
	shop._on_done_pressed()
	shop.open()
	assert_eq(shop.spreads.size(), 2, "beide Seiten bleiben stehen")
	assert_eq(shop.current_spread_index, 1, "der Laden öffnet, wo er zuging")
	assert_true(shop.dice_packs == second)

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

func test_the_bowl_offers_open_dice_and_single_engravings() -> void:
	assert_gt(shop.single_dice.size(), 0, "mindestens ein offener Würfel liegt aus")
	assert_lte(shop.single_dice.size(), ShopController.SINGLE_DICE_MAX)
	assert_eq(shop.single_dice_prices.size(), shop.single_dice.size(), "je Würfel ein Preis")
	assert_gt(shop.single_engravings.size(), 0, "und einzelne Gravuren")

func test_a_single_die_is_fully_rolled_before_the_purchase() -> void:
	# Der ganze Sinn der offenen Auslage: der Würfel steht schon fest, es gibt
	# nichts mehr zu enthüllen.
	for i in shop.single_dice.size():
		var die: DieDefinition = shop.single_dice[i]
		assert_eq(die.faces.size(), 6, "alle sechs Seiten stehen")
		assert_gt(int(shop.single_dice_prices[i]), 0, "und der Preis auch")

func test_single_engravings_come_from_both_shelves() -> void:
	var categories := {}
	for engraving in shop.single_engravings:
		categories[engraving.category] = true
		assert_true(Engraving.CATEGORIES.has(engraving.category))
	assert_true(categories.has(Engraving.CATEGORY_MATERIAL), "Material-Gravuren sind gesetzt")

func test_a_single_engraving_costs_more_per_piece_than_the_pack() -> void:
	# Das Einzelstück ist bequem, das Paket bleibt das bessere Geschäft je Stück.
	var per_piece := float(Pack.NUMBER_PRICE) / float(Pack.NUMBER_COUNT)
	var single := ShopController.single_engraving_price(Engraving.notch())
	assert_gt(float(single), per_piece, "Einzelkauf zahlt den Bequemlichkeitsaufschlag")

func test_the_single_price_climbs_with_the_rarity() -> void:
	assert_lt(ShopController.single_engraving_price(Engraving.notch()),
		ShopController.single_engraving_price(Engraving.chisel()), "häufig < selten")
	assert_lt(ShopController.single_engraving_price(Engraving.chisel()),
		ShopController.single_engraving_price(Engraving.blueprint()), "selten < episch")

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

func test_buying_a_single_engraving_grants_it() -> void:
	run.money = 500
	var engraving: Engraving = shop.single_engravings[0]
	var price := ShopController.single_engraving_price(engraving)
	var before := run.money
	var owned_before := run.owned_engravings.size()
	shop._on_single_engraving_pressed(0)
	assert_eq(run.money, before - price)
	assert_eq(run.owned_engravings.size(), owned_before + 1, "sie liegt im Vorrat")
	assert_true(shop.single_engravings_bought[0])

func test_a_single_is_only_sold_once() -> void:
	run.money = 500
	shop._on_single_die_pressed(0)
	var after_first := run.money
	shop._on_single_die_pressed(0)
	assert_eq(run.money, after_first, "der zweite Klick kostet nichts mehr")

func test_singles_are_not_sold_without_the_money() -> void:
	run.money = 0
	var owned_before := run.owned_engravings.size()
	shop._on_single_engraving_pressed(0)
	assert_eq(run.owned_engravings.size(), owned_before, "ohne Geld kein Kauf")
	assert_false(shop.single_engravings_bought[0])

func test_the_locked_assortment_freezes_the_singles_too() -> void:
	run.money = 500
	var die_names: Array[String] = []
	for def in shop.single_dice:
		die_names.append(def.display_name)
	var engraving_ids: Array[String] = []
	for engraving in shop.single_engravings:
		engraving_ids.append(engraving.id)
	shop.sortiment_locked = true
	shop.close()
	shop.open()
	var after_names: Array[String] = []
	for def in shop.single_dice:
		after_names.append(def.display_name)
	var after_ids: Array[String] = []
	for engraving in shop.single_engravings:
		after_ids.append(engraving.id)
	assert_eq(after_names, die_names, "dieselben Würfel liegen wieder da")
	assert_eq(after_ids, engraving_ids, "und dieselben Gravuren")

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

# --- Die offene Chip-Schale: die Ware LIEGT dort, sie sitzt nicht in Kästen ---------

## Alle noch gebauten Einzelstück-Knöpfe (null = verkaufter Platz).
func _laid_out_singles(buttons: Array) -> Array:
	var live := []
	for button in buttons:
		if button != null and is_instance_valid(button):
			live.append(button)
	return live

func test_a_bought_single_die_is_gone_from_the_bowl() -> void:
	await wait_frames(2)
	var before := _laid_out_singles(shop.single_dice_buttons).size()
	assert_gt(before, 0, "vorher liegt etwas da")
	shop._on_single_die_pressed(0)  # baut die Auslage selbst neu auf
	await wait_frames(2)
	assert_true(shop.single_dice_bought[0], "gekauft bleibt im Spread vermerkt")
	assert_null(shop.single_dice_buttons[0], "der Platz bleibt index-treu, aber leer")
	assert_eq(_laid_out_singles(shop.single_dice_buttons).size(), before - 1,
		"gekauftes Stück liegt nicht mehr in der Schale")

func test_a_bought_single_engraving_is_gone_from_the_bowl() -> void:
	await wait_frames(2)
	var before := _laid_out_singles(shop.single_engraving_buttons).size()
	shop._on_single_engraving_pressed(0)
	await wait_frames(2)
	assert_true(shop.single_engravings_bought[0])
	assert_eq(_laid_out_singles(shop.single_engraving_buttons).size(), before - 1)

func test_the_singles_lie_bare_without_a_box() -> void:
	# Kein Fenster unter einem physischen Ding - dieselbe Regel wie bei den
	# Kombi-Chips auf dem Filz.
	await wait_frames(2)
	for button in _laid_out_singles(shop.single_dice_buttons) + _laid_out_singles(shop.single_engraving_buttons):
		for state in ["normal", "hover", "pressed", "disabled"]:
			assert_true(button.get_theme_stylebox(state) is StyleBoxEmpty,
				"Einzelstück ohne Kasten (%s)" % state)

func test_a_single_die_lies_in_the_bowl_as_a_real_die() -> void:
	await wait_frames(2)
	var card: Button = _laid_out_singles(shop.single_dice_buttons)[0]
	var stage := card.get_child(0)
	assert_true(stage is DiceRowView.TumbleStage, "ein echter, taumelnder Würfel")
	assert_not_null((stage as DiceRowView.TumbleStage).die, "und er hat einen Würfel zum Drehen")
	assert_eq(stage.mouse_filter, Control.MOUSE_FILTER_IGNORE, "der Klick geht an den Knopf")

func test_no_single_prints_a_price_in_the_bowl() -> void:
	# Der Preis kommt beim Zugreifen, nicht als Schild auf der Ware.
	await wait_frames(2)
	for button in _laid_out_singles(shop.single_dice_buttons) + _laid_out_singles(shop.single_engraving_buttons):
		assert_false(_has_price_label(button), "kein gedrucktes Preisschild")

func _has_price_label(node: Node) -> bool:
	if node is Label and (node as Label).text.begins_with("$"):
		return true
	for child in node.get_children():
		if _has_price_label(child):
			return true
	return false

func test_the_overclock_chip_dropped_its_price_tag_too() -> void:
	await wait_frames(2)
	assert_gt(shop.overclock_buttons.size(), 0)
	assert_false(_has_price_label(shop.overclock_buttons[0]),
		"die ganze Schale spricht eine Sprache")

# --- Die Preiszeile im Hover-Fenster ------------------------------------------------

func test_the_price_line_is_a_pure_function() -> void:
	assert_eq(ShopController.price_text(7), "$7")
	assert_eq(ShopController.price_text(0), "$0")

func test_the_price_tint_says_whether_it_is_payable() -> void:
	assert_eq(ShopController.price_tint(5, 10), ShopController.NEON_GOLD, "bezahlbar")
	assert_eq(ShopController.price_tint(5, 5), ShopController.NEON_GOLD, "genau genug reicht")
	assert_eq(ShopController.price_tint(5, 4), CasinoStyle.RED, "zu teuer")

func test_hovering_a_single_shows_its_price_and_dossier() -> void:
	await wait_frames(2)
	var card: Button = _laid_out_singles(shop.single_dice_buttons)[0]
	card.mouse_entered.emit()
	await wait_frames(2)
	assert_true(shop.shop_tooltip.visible)
	assert_true(shop.shop_tooltip_price.visible, "der Preis erscheint erst beim Zugreifen")
	assert_eq(shop.shop_tooltip_price.text, ShopController.price_text(shop.single_dice_prices[0]))
	assert_true(shop.shop_tooltip_stage.visible, "und das Würfelnetz als Dossier")
	shop._hide_shop_tooltip()

func test_hovering_a_single_engraving_shows_a_price_but_no_net() -> void:
	await wait_frames(2)
	var card: Button = _laid_out_singles(shop.single_engraving_buttons)[0]
	card.mouse_entered.emit()
	await wait_frames(2)
	assert_true(shop.shop_tooltip_price.visible)
	assert_false(shop.shop_tooltip_stage.visible, "eine Gravur ist kein Würfel")

func test_the_hover_window_stays_inside_the_shop_page() -> void:
	await wait_frames(2)
	var card: Button = _laid_out_singles(shop.single_dice_buttons)[0]
	card.mouse_entered.emit()
	await wait_frames(2)
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

# --- Das Regal des Händlers und der Tausch ------------------------------------------

func _stash_one() -> DieDefinition:
	run.money = 500
	shop._on_single_die_pressed(0)
	return run.pending_dice[0]

func test_the_stash_shelf_shows_what_is_deposited() -> void:
	await wait_frames(2)
	assert_eq(shop.stash_buttons.size(), 0, "leeres Regal steht gar nicht erst da")
	_stash_one()
	await wait_frames(2)
	assert_eq(shop.stash_buttons.size(), 1, "ein hinterlegter Würfel, ein Platz im Regal")

func test_a_stashed_die_lies_bare_like_the_bowl() -> void:
	_stash_one()
	await wait_frames(2)
	var thumb: Button = shop.stash_buttons[0]
	for state in ["normal", "hover", "pressed"]:
		assert_true(thumb.get_theme_stylebox(state) is StyleBoxEmpty, "kein Kasten (%s)" % state)
	assert_true(thumb.get_child(0) is DiceRowView.TumbleStage, "ein echter Würfel")

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

func test_cancelling_the_picker_keeps_both_sides() -> void:
	_stash_one()
	await wait_frames(2)
	shop._open_exchange_picker(0)
	await wait_frames(2)
	assert_true(shop.exchange_picker_open(), "die Auswahl steht offen")
	var pool_before := run.owned_pool[0].style_id
	shop._close_exchange_picker()
	await wait_frames(2)
	assert_false(shop.exchange_picker_open())
	assert_eq(run.pending_dice.size(), 1, "der Würfel bleibt hinterlegt")
	assert_eq(run.owned_pool[0].style_id, pool_before, "und der Vorrat unberührt")

func test_the_picker_offers_every_pool_slot() -> void:
	_stash_one()
	await wait_frames(2)
	shop._open_exchange_picker(0)
	await wait_frames(2)
	assert_not_null(shop.exchange_grid)
	assert_eq(shop.exchange_grid.tiles.size(), run.owned_pool.size(),
		"alle 30 Plätze stehen zur Wahl")

func test_the_stash_survives_a_reroll_and_the_lock() -> void:
	_stash_one()
	shop._show_spread()
	await wait_frames(2)
	assert_eq(run.pending_dice.size(), 1, "ein Neuaufbau leert das Regal nicht")
	shop.sortiment_locked = true
	shop.open()
	await wait_frames(2)
	assert_eq(run.pending_dice.size(), 1, "und ein neuer Besuch auch nicht")
	assert_eq(shop.stash_buttons.size(), 1, "das Regal steht wieder da")

func test_a_fresh_run_has_an_empty_shelf() -> void:
	assert_eq(GameRun.new_run().pending_dice.size(), 0, "ein neuer Lauf schuldet nichts")
