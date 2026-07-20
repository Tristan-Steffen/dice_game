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

# --- Vorräte-Regal ---------------------------------------------------------------

func test_supply_shelf_counts_each_engraving_once() -> void:
	run.grant_engraving(Engraving.chisel())
	run.grant_engraving(Engraving.chisel())
	run.grant_engraving(Engraving.notch())
	var counts := view._engraving_counts()
	assert_eq(counts.size(), 2, "je Sorte EIN Eintrag")
	assert_eq(counts[Engraving.CHISEL], 2, "Stückzahl gebündelt")
	assert_eq(counts[Engraving.NOTCH], 1)

func test_supply_shelf_is_empty_without_stock() -> void:
	assert_true(view._engraving_counts().is_empty())

func test_supply_shelf_follows_the_run() -> void:
	# Der Bestand hängt an engravings_changed - auch ein Paket-Inhalt taucht auf.
	run.purchase_pack(Pack.number_pack(), 0)
	run.open_pack(0)
	var total := 0
	for id in view._engraving_counts():
		total += view._engraving_counts()[id]
	assert_eq(total, Pack.NUMBER_COUNT, "Paket-Inhalt liegt im Regal")

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

func test_dice_pack_offers_its_dice_one_after_another() -> void:
	_open_dice_pack()
	assert_eq(view._phase, WorkshopView.Phase.REVEAL_DICE)
	assert_eq(view._revealed_dice.size(), 3)
	assert_eq(view._die_index, 0, "der erste Würfel ist dran")
	assert_eq(run.owned_pool.size(), GameRun.POOL_SIZE, "noch nichts eingesetzt")

func test_placing_a_die_replaces_the_chosen_pool_slot() -> void:
	_open_dice_pack()
	var incoming: DieDefinition = view._revealed_dice[0]
	view.begin_placement()
	assert_eq(view._phase, WorkshopView.Phase.PICK_POOL)
	assert_eq(view._pool_buttons.size(), GameRun.POOL_SIZE, "je Pool-Platz ein Knopf")
	view.place_current_die(4)
	assert_eq(run.owned_pool[4].style_id, incoming.style_id, "Platz 4 trägt den neuen Würfel")
	assert_eq(run.owned_pool[5].style_id, "normal", "Nachbarplatz unberührt")
	assert_eq(view._die_index, 1, "der nächste Würfel ist dran")
	assert_eq(view._phase, WorkshopView.Phase.REVEAL_DICE)

func test_refusing_a_die_drops_it_without_touching_the_pool() -> void:
	_open_dice_pack()
	view.refuse_current_die()
	assert_eq(view._die_index, 1)
	for def in run.owned_pool:
		assert_eq(def.style_id, "normal", "abgelehnte Würfel verfallen")

func test_ceremony_ends_after_the_last_die() -> void:
	_open_dice_pack()
	for i in 3:
		view.refuse_current_die()
	assert_eq(view._phase, WorkshopView.Phase.STASH, "danach wieder das Lager")
	assert_eq(view._revealed_dice.size(), 0, "Inhalt ist abgeräumt")

func test_placement_can_be_cancelled_back_to_the_die() -> void:
	_open_dice_pack()
	view.begin_placement()
	view._cancel_placement()
	assert_eq(view._phase, WorkshopView.Phase.REVEAL_DICE, "zurück zur Entscheidung")
	assert_eq(view._die_index, 0, "derselbe Würfel steht weiter zur Wahl")
