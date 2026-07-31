extends GutTest
## Tier-2-Tests der Werkstatt (WorkshopView): das Lager zeigt je gekauftem Paket
## eine Karte, meldet den Öffnen-Wunsch als Signal und folgt dem Lagerbestand.

var view: WorkshopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = WorkshopView.new()
	view.size = Vector2(600, 500)
	add_child_autofree(view)
	view.run = run

func test_empty_stash_shows_a_hint_and_no_cards() -> void:
	assert_eq(view._pack_buttons.size(), 0, "leeres Lager hat keine Karten")

func test_each_pack_gets_its_own_card() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	run.purchase_pack(Pack.dice_pack(DiceOffer.TEMPLATES[0]), 0)
	assert_eq(view._pack_buttons.size(), 2, "je Paket eine Lagerkarte")

func test_stash_follows_the_run() -> void:
	run.purchase_pack(Pack.material_pack(), 0)
	assert_eq(view._pack_buttons.size(), 1, "Kauf erscheint sofort im Lager")
	view.open_pack(0)
	view._unseal.finish_now()
	assert_eq(view._pack_buttons.size(), 0, "geöffnetes Paket verschwindet")

func test_clicking_a_card_opens_that_pack() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	run.purchase_pack(Pack.material_pack(), 0)
	var opened: Array[int] = []
	view.pack_activated.connect(func(index: int) -> void: opened.append(index))
	view._pack_buttons[1].pressed.emit()
	assert_eq(opened, [1] as Array[int], "der geklickte Platz wird gemeldet")
	assert_eq(run.owned_packs.size(), 1, "das Kanten-Paket ist verbraucht")

# --- Lieferung aus dem Laden (das Licht IST das Paket) --------------------------

func test_pending_delivery_holds_the_newest_card_back() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	assert_eq(view._pack_buttons.size(), 1, "das ältere Paket liegt im Regal")
	run.purchase_pack(Pack.material_pack(), 0)
	view.expect_delivery()
	assert_eq(view._pack_buttons.size(), 1, "das unterwegs befindliche Paket fehlt noch")
	view.deliver_pack()
	assert_eq(view._pack_buttons.size(), 2, "bei Ankunft erscheint es")

func test_delivery_counter_survives_several_purchases_at_once() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	run.purchase_pack(Pack.material_pack(), 0)
	view.expect_delivery()
	view.expect_delivery()
	assert_eq(view._pack_buttons.size(), 0, "beide Lichter sind noch unterwegs")
	view.deliver_pack()
	assert_eq(view._pack_buttons.size(), 1, "eines nach dem anderen")
	view.deliver_pack()
	assert_eq(view._pack_buttons.size(), 2)

func test_extra_deliveries_are_ignored() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view.deliver_pack()  # ohne angemeldete Lieferung
	assert_eq(view._pack_buttons.size(), 1, "das Regal bleibt, wie es ist")

func test_a_new_run_cancels_pending_deliveries() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view.expect_delivery()
	var fresh := GameRun.new_run()
	fresh.purchase_pack(Pack.material_pack(), 0)
	view.run = fresh
	assert_eq(view._pack_buttons.size(), 1, "der neue Lauf zeigt sein Lager vollständig")

# --- Zeremonie: Entsiegelung -----------------------------------------------------

func test_opening_a_pack_starts_the_unsealing() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view.open_pack(0)
	assert_eq(view._phase, WorkshopView.Phase.UNSEAL)
	assert_eq(view._revealed_engravings.size(), Pack.NUMBER_COUNT, "Inhalt ist ausgewürfelt")
	assert_not_null(view._unseal, "die Zeremonie läuft")

func test_the_stash_is_not_booked_before_the_seal_breaks() -> void:
	# Die Schubladen hängen an engravings_changed - buchte das Öffnen sofort,
	# verrieten ihre Zähler die Seltenheit noch während des Ladens.
	run.purchase_pack(Pack.number_pack(), 0)
	view.open_pack(0)
	assert_eq(run.owned_engravings.size(), 0, "während des Ladens ist nichts verbucht")
	view._unseal.finish_now()
	assert_eq(run.owned_engravings.size(), Pack.NUMBER_COUNT, "erst der Bruch bucht")

func test_engraving_pack_returns_to_the_stash_on_its_own() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view.open_pack(0)
	view._unseal.finish_now()
	assert_eq(view._phase, WorkshopView.Phase.STASH, "kein Klick nötig")
	assert_null(view._unseal, "die Zeremonie ist abgeräumt")

func test_every_engraving_is_dispatched_exactly_once() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	var sent: Array[String] = []
	view.engraving_dispatched.connect(func(id: String, _px: Vector2, _rarity: int) -> void:
		sent.append(id))
	view.open_pack(0)
	view._unseal.finish_now()
	assert_eq(sent.size(), Pack.NUMBER_COUNT, "je Stück ein Licht in die Schublade")

func test_the_content_is_booked_only_once() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view.open_pack(0)
	view._unseal.finish_now()
	view.finish_ceremony()  # doppelter Abschluss darf nicht nachbuchen
	assert_eq(run.owned_engravings.size(), Pack.NUMBER_COUNT)

func test_an_interrupted_ceremony_still_books_its_content() -> void:
	# Die Gravur-Station legt sich über die Werkbank und beendet die Zeremonie -
	# der schon ausgewürfelte Inhalt darf dabei nicht verfallen.
	run.purchase_pack(Pack.number_pack(), 0)
	view.open_pack(0)
	var station := Control.new()
	view.attach_station(station)
	assert_eq(run.owned_engravings.size(), Pack.NUMBER_COUNT, "Inhalt ist gerettet")
	assert_eq(view._phase, WorkshopView.Phase.STASH)

func test_a_new_run_does_not_inherit_the_open_content() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view.open_pack(0)
	var fresh := GameRun.new_run()
	view.run = fresh
	assert_eq(run.owned_engravings.size(), Pack.NUMBER_COUNT, "der alte Lauf behält ihn")
	assert_eq(fresh.owned_engravings.size(), 0, "der neue erbt nichts")

# --- Zeremonie: Würfel-Pakete ---------------------------------------------------

## Öffnet ein 3er-Paket UND wählt gleich einen Würfel - der Normalfall für die
## Einsetz-Tests. Wer den Wahlschritt selbst prüfen will, nimmt _reveal_dice_pack.
func _open_dice_pack() -> void:
	_reveal_dice_pack()
	view._choose_die(0)

## Öffnet ein 3er-Paket bis zur WAHL: alle drei liegen offen.
func _reveal_dice_pack() -> void:
	# "Niedrige Serie": 3 Würfel, damit die Wahl überhaupt eine ist.
	run.purchase_pack(Pack.dice_pack(DiceOffer.TEMPLATES[4]), 0)
	view.open_pack(0)
	view._unseal.finish_now()  # Entsiegelung überspringen: hier geht es ums Wählen

func test_a_multi_die_pack_reveals_all_of_them_for_the_choice() -> void:
	_reveal_dice_pack()
	assert_eq(view._phase, WorkshopView.Phase.CHOOSE_DIE, "erst wählen, dann einsetzen")
	assert_eq(view._revealed_dice.size(), 3, "alle drei liegen offen")

func test_choosing_keeps_exactly_one_die() -> void:
	_reveal_dice_pack()
	var picked: DieDefinition = view._revealed_dice[1]
	view._choose_die(1)
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE)
	assert_eq(view._revealed_dice.size(), 1, "der Rest bleibt im Paket")
	assert_same(view._revealed_dice[0], picked, "und zwar genau der gewählte")

func test_a_single_die_pack_skips_the_choice() -> void:
	# Ein Würfel, keine Entscheidung: direkt einsetzen.
	run.purchase_pack(Pack.dice_pack(DiceOffer.TEMPLATES[0]), 0)
	view.open_pack(0)
	view._unseal.finish_now()
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE, "nichts zu wählen")
	assert_eq(view._revealed_dice.size(), 1)

func test_dice_pack_shows_its_die_and_the_pool_on_one_page() -> void:
	_open_dice_pack()
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE)
	assert_eq(view._revealed_dice.size(), 1)
	assert_eq(view._pool_grid.tiles.size(), GameRun.POOL_SIZE, "je Pool-Platz eine Kachel")
	assert_true(view._selected_slots.is_empty(), "noch nichts gewählt")
	assert_true(view._place_button.disabled, "ohne Auswahl bleibt Einsetzen dunkel")

func test_selecting_a_slot_lights_up_the_place_button() -> void:
	_open_dice_pack()
	view.toggle_slot(4)
	assert_eq(view._selected_slots, [4] as Array[int])
	assert_false(view._place_button.disabled, "ab dem ersten Platz leuchtet Einsetzen")
	assert_eq(view._remaining_label.text, "0", "der eine Würfel hat seinen Platz")

func test_clicking_a_selected_slot_again_deselects_it() -> void:
	_open_dice_pack()
	view.toggle_slot(4)
	view.toggle_slot(4)
	assert_true(view._selected_slots.is_empty(), "derselbe Platz wählt wieder ab")
	assert_true(view._place_button.disabled)

func test_selection_stops_at_the_number_of_dice_in_the_pack() -> void:
	_open_dice_pack()
	for slot in [0, 1, 2, 3]:
		view.toggle_slot(slot)
	assert_eq(view._selected_slots, [0] as Array[int], "ein Würfel, ein Platz")
	assert_eq(view._remaining_label.text, "0")

func test_confirming_replaces_the_selected_slot() -> void:
	_open_dice_pack()
	var incoming: String = view._revealed_dice[0].style_id
	view.toggle_slot(4)
	view.confirm_placement()
	assert_eq(run.owned_pool[4].style_id, incoming, "Platz 4 trägt den Paket-Würfel")
	assert_eq(run.owned_pool[5].style_id, "normal", "Nachbarplatz unberührt")
	assert_eq(view._phase, WorkshopView.Phase.STASH, "danach wieder das Lager")

func test_placement_keeps_the_pool_instance_so_the_trays_follow() -> void:
	# Die Trays und das Rundendeck halten dieselbe DieDefinition wie der Pool -
	# ein Tausch der Instanz ließe sie den alten Würfel zeigen.
	_open_dice_pack()
	var held: DieDefinition = run.owned_pool[4]
	view.toggle_slot(4)
	view.confirm_placement()
	assert_same(run.owned_pool[4], held, "der Pool-Platz behält seine Instanz")
	assert_eq(held.style_id, "low", "und trägt jetzt den Paket-Würfel")

func test_the_unchosen_dice_of_the_pack_are_lost() -> void:
	# Drei aufgedeckt, einer genommen: die anderen beiden verfallen ersatzlos.
	_reveal_dice_pack()
	view._choose_die(0)
	var incoming: String = view._revealed_dice[0].style_id
	view.toggle_slot(4)
	view.confirm_placement()
	var placed := 0
	for def in run.owned_pool:
		if def.style_id == incoming:
			placed += 1
	assert_eq(placed, 1, "genau ein Platz wurde ersetzt")
	assert_eq(view._revealed_dice.size(), 0, "der Rest ist verfallen")

func test_confirming_without_a_selection_does_nothing() -> void:
	_open_dice_pack()
	view.confirm_placement()
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE, "die Zeremonie läuft weiter")
	for def in run.owned_pool:
		assert_eq(def.style_id, "normal", "der Pool bleibt unberührt")

func test_grid_follows_the_tray_order_not_the_pool_order() -> void:
	# scene_root reicht die Tray-Reihenfolge herein (der Pool liegt dort gemischt):
	# Kachel 0 muss den Würfel treffen, der auf dem Tisch oben links liegt.
	_open_dice_pack()
	var order: Array[DieDefinition] = []
	order.append(run.owned_pool[7])   # Kachel 0 = Pool-Platz 7
	order.append(null)                # gezogener Würfel: leerer Platz
	order.append(run.owned_pool[2])
	view.set_pool_order(order, 3)
	var incoming: String = view._revealed_dice[0].style_id
	view.toggle_slot(0)
	view.confirm_placement()
	assert_eq(run.owned_pool[7].style_id, incoming, "Kachel 0 traf Pool-Platz 7")
	assert_eq(run.owned_pool[0].style_id, "normal", "NICHT der Pool-Platz 0")

func test_empty_tray_slots_cannot_be_selected() -> void:
	_open_dice_pack()
	var order: Array[DieDefinition] = []
	order.append(null)
	order.append(run.owned_pool[3])
	view.set_pool_order(order, 2)
	view.toggle_slot(0)
	assert_true(view._selected_slots.is_empty(), "auf einem leeren Platz ist nichts zu ersetzen")
	view.toggle_slot(1)
	assert_eq(view._selected_slots, [1] as Array[int], "der belegte Platz geht")

func test_discarding_drops_the_whole_content() -> void:
	_open_dice_pack()
	view.discard_dice()
	assert_eq(view._phase, WorkshopView.Phase.STASH, "danach wieder das Lager")
	assert_eq(view._revealed_dice.size(), 0, "Inhalt ist abgeräumt")
	for def in run.owned_pool:
		assert_eq(def.style_id, "normal", "verworfene Würfel verfallen")
