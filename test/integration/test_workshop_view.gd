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

func test_clicking_a_card_asks_to_open_that_pack() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	run.purchase_pack(Pack.edge_pack(), 0)
	var opened: Array[int] = []
	view.pack_activated.connect(func(index: int) -> void: opened.append(index))
	view._pack_buttons[1].pressed.emit()
	assert_eq(opened, [1] as Array[int], "der geklickte Platz wird gemeldet")
