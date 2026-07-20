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
	run.open_pack(0)
	assert_eq(view._pack_buttons.size(), 0, "geöffnetes Paket verschwindet")

func test_clicking_a_card_opens_that_pack() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	run.purchase_pack(Pack.edge_pack(), 0)
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
	fresh.purchase_pack(Pack.edge_pack(), 0)
	view.run = fresh
	assert_eq(view._pack_buttons.size(), 1, "der neue Lauf zeigt sein Lager vollständig")

# --- Zeremonie: Gravur-Pakete ---------------------------------------------------

func test_opening_an_engraving_pack_shows_and_books_its_contents() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view.open_pack(0)
	assert_eq(view._phase, WorkshopView.Phase.REVEAL_ENGRAVINGS)
	assert_eq(view._revealed_engravings.size(), Pack.NUMBER_COUNT, "Inhalt liegt aus")
	assert_eq(run.owned_engravings.size(), Pack.NUMBER_COUNT, "und ist schon in den Vorräten")
	view.finish_ceremony()
	assert_eq(view._phase, WorkshopView.Phase.STASH, "danach wieder das Lager")

# --- Zeremonie: Würfel-Pakete ---------------------------------------------------

func _open_dice_pack() -> void:
	# "Niedrige Serie": 3 Würfel, damit das Durchreichen mehrerer Würfel greift.
	run.purchase_pack(Pack.dice_pack(DiceOffer.TEMPLATES[4]), 0)
	view.open_pack(0)

func test_dice_pack_shows_its_dice_and_the_pool_on_one_page() -> void:
	_open_dice_pack()
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE)
	assert_eq(view._revealed_dice.size(), 3)
	assert_eq(view._pool_grid.tiles.size(), GameRun.POOL_SIZE, "je Pool-Platz eine Kachel")
	assert_true(view._selected_slots.is_empty(), "noch nichts gewählt")
	assert_true(view._place_button.disabled, "ohne Auswahl bleibt Einsetzen dunkel")

func test_selecting_a_slot_lights_up_the_place_button() -> void:
	_open_dice_pack()
	view.toggle_slot(4)
	assert_eq(view._selected_slots, [4] as Array[int])
	assert_false(view._place_button.disabled, "ab dem ersten Platz leuchtet Einsetzen")
	assert_eq(view._remaining_label.text, "2", "der Zähler zählt runter")

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
	assert_eq(view._selected_slots, [0, 1, 2] as Array[int], "mehr Plätze als Würfel gehen nicht")
	assert_eq(view._remaining_label.text, "0")

func test_confirming_replaces_every_selected_slot() -> void:
	_open_dice_pack()
	var incoming: String = view._revealed_dice[0].style_id
	view.toggle_slot(4)
	view.toggle_slot(9)
	view.confirm_placement()
	assert_eq(run.owned_pool[4].style_id, incoming, "Platz 4 trägt einen Paket-Würfel")
	assert_eq(run.owned_pool[9].style_id, incoming, "Platz 9 auch")
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

func test_unplaced_dice_of_the_pack_are_lost() -> void:
	# Drei Würfel, ein Platz: die anderen beiden verfallen ersatzlos.
	_open_dice_pack()
	var incoming: String = view._revealed_dice[0].style_id
	view.toggle_slot(4)
	view.confirm_placement()
	var placed := 0
	for def in run.owned_pool:
		if def.style_id == incoming:
			placed += 1
	assert_eq(placed, 1, "nur der gewählte Platz wurde ersetzt")
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
