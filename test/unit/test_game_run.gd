extends GutTest
## Tier-1-Tests des GameRun (siehe scripts/game_run.gd): der persistente
## Run-Zustand (Geld, Pool, Charms, Gravuren, Rundenfortschritt) als reine
## Daten-Klasse - komplett ohne Szene testbar. Shop und Gravur-Station mutieren
## den Zustand ausschließlich über diese Methoden; die HUD hört auf die Signale.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	# Die Auslage aus new_run stört die Deal-Tests nicht, aber unterschrieben
	# ist noch nichts - der Lauf startet ohne Wirkungen.
	run.active_deals.clear()

# --- Startzustand -------------------------------------------------------------

func test_new_run_starts_empty_handed():
	assert_eq(run.money, 0)
	assert_eq(run.round_number, 1)
	assert_eq(run.round_goal, GameRun.BASE_GOAL)
	assert_eq(run.owned_charms.size(), 0)
	assert_eq(run.owned_packs.size(), 0)

func test_new_run_fills_pool_with_standard_dice():
	assert_eq(run.owned_pool.size(), GameRun.POOL_SIZE)
	for def in run.owned_pool:
		assert_eq(def.style_id, "normal")

func test_pool_entries_are_independent_instances():
	# Eine Ätzung auf Würfel 0 darf Würfel 1 nie mitverändern (siehe
	# DieDefinition-Klassenkommentar zum Resource-Teilen).
	run.owned_pool[0].faces[0] = 6
	assert_eq(run.owned_pool[1].faces[0], 1, "Nachbar-Würfel bleibt unberührt")

# --- Geld ----------------------------------------------------------------------

func test_add_money_accumulates_and_emits():
	watch_signals(run)
	run.add_money(5)
	run.add_money(3)
	assert_eq(run.money, 8)
	assert_signal_emit_count(run, "money_changed", 2)

# --- Ein Würfel nimmt einen Pool-Platz ein --------------------------------------
## EIN Weg für JEDEN Würfel: er wird hinterlegt (stash_die) und erst der Tausch am
## Vorrat gibt ihm einen Platz. Auch der Automaten-Gewinn geht ihn - still in den
## Pool schreibt seit 2026-08-31 niemand mehr.

## Gewinnt einen Würfel am Automaten.
func _win_die(def: DieDefinition) -> void:
	var prize := SlotPrize.new()
	prize.kind = SlotPrize.Kind.DIE
	prize.die = def
	run.book_slot_prize(prize)

func test_a_won_die_waits_in_the_out_tray():
	_win_die(DieDefinition.fixed(6, "Immer 6"))
	assert_eq(run.pending_dice.size(), 1, "er liegt im Ausgabefach")
	assert_eq(run.pending_dice[0].style_id, "fixed_6")
	assert_eq(_count_style("fixed_6"), 0, "und NICHTS im Vorrat wurde still überschrieben")

func test_a_won_die_stores_an_independent_copy():
	var template := DieDefinition.fixed(6, "Immer 6")
	_win_die(template)
	run.pending_dice[0].faces[0] = 1  # spätere Aufwertung des gewonnenen Würfels
	assert_eq(template.faces[0], 6, "die Vorlage des Gewinns bleibt unverändert")

## --- Ein Weg für alle Würfel-Anzeigen: pool_changed --------------------------
## Die Instanz wird NIE getauscht (become) - wer sie hält (Rundendeck, Trays,
## Raster, Dossier), zeigt den neuen Würfel sofort; das Signal löst nur das
## Neuzeichnen aus.

func test_the_exchange_overwrites_the_instance_in_place():
	var kept := run.owned_pool.duplicate()
	_win_die(DieDefinition.fixed(6, "Immer 6"))
	assert_true(run.exchange_pending_die(0, 4))
	for i in GameRun.POOL_SIZE:
		assert_same(run.owned_pool[i], kept[i], "kein Instanz-Tausch im Pool")
	assert_eq(kept[4].style_id, "fixed_6", "der gehaltene Würfel IST der gewonnene")

func test_a_won_die_emits_pending_dice_changed():
	watch_signals(run)
	_win_die(DieDefinition.fixed(6, "Immer 6"))
	assert_signal_emit_count(run, "pending_dice_changed", 1)
	assert_signal_emit_count(run, "pool_changed", 0)

func test_the_exchange_emits_pool_changed():
	run.stash_die(DieDefinition.fixed(3, "Drei"), 0)
	watch_signals(run)
	assert_true(run.exchange_pending_die(0, 4))
	assert_eq(run.owned_pool[4].style_id, "fixed_3")
	assert_signal_emit_count(run, "pool_changed", 1)

func test_note_pool_changed_reports_outside_mutations():
	# Gravur-Station und Nehmen-Effekte mutieren die Instanz direkt und melden
	# es hierüber - sonst zeigten Trays und Grube alte Augen.
	watch_signals(run)
	run.owned_pool[0].faces[0] = 9
	run.note_pool_changed()
	assert_signal_emit_count(run, "pool_changed", 1)

func test_midas_glove_reports_the_pool_change():
	run.owned_charms.append(Charm.midas_glove())
	var defs: Array[DieDefinition] = []
	var faces: Array[int] = []
	var participating: Array[int] = []
	for i in 6:
		defs.append(run.owned_pool[i])
		faces.append(0)
		participating.append(i)
	watch_signals(run)
	assert_eq(run.apply_midas_glove(defs, faces, participating).size(), 6)
	assert_signal_emit_count(run, "pool_changed", 1)

# --- Charms ---------------------------------------------------------------------

func test_purchase_charm_grants_deducts_and_emits():
	watch_signals(run)
	run.money = 30
	run.purchase_charm(Charm.rabbits_foot(), 25)
	assert_eq(run.money, 5)
	assert_eq(run.owned_charms.size(), 1)
	assert_signal_emitted(run, "charms_changed")

## --- Harte Obergrenze der Charm-Plätze (keine Warteschlange) --------------------

func _fill_charm_dock() -> void:
	for i in GameRun.CHARM_CAPACITY:
		run.owned_charms.append(Charm.rabbits_foot())

func test_charms_full_reports_the_capacity():
	assert_false(run.charms_full())
	_fill_charm_dock()
	assert_true(run.charms_full())
	assert_eq(run.owned_charms.size(), CharmRowView.SPOT_COUNT, "Plätze am Tisch = Obergrenze")

func test_purchase_charm_at_capacity_costs_nothing_and_grants_nothing():
	_fill_charm_dock()
	watch_signals(run)
	run.money = 30
	assert_false(run.purchase_charm(Charm.horseshoe(), 25))
	assert_eq(run.money, 30, "kein Abzug für einen Charm, der nicht einzieht")
	assert_eq(run.owned_charms.size(), GameRun.CHARM_CAPACITY, "keine unsichtbare Warteschlange")
	assert_signal_not_emitted(run, "charms_changed")

func test_selling_frees_a_slot_again():
	_fill_charm_dock()
	run.sell_charm(0)
	assert_false(run.charms_full())
	run.money = 30
	assert_true(run.purchase_charm(Charm.horseshoe(), 25))
	assert_eq(run.owned_charms.size(), GameRun.CHARM_CAPACITY)

func test_secret_market_charm_slot_is_barred_at_capacity():
	# Der Schwarzmarkt geht denselben Weg: voller Dock, keine Energie abgebucht.
	run.energy = GameRun.SECRET_CHARM_PRICE
	run.secret_stock.append({
		GameRun.OFFER_KIND: GameRun.KIND_CHARM,
		GameRun.OFFER_ITEM: Charm.horseshoe(),
		GameRun.OFFER_PRICE: GameRun.SECRET_CHARM_PRICE,
		GameRun.OFFER_SOLD: false,
	})
	_fill_charm_dock()
	assert_false(run.buy_secret_offer(0))
	assert_eq(run.energy, GameRun.SECRET_CHARM_PRICE, "kein Abzug")
	assert_false(bool(run.secret_stock[0][GameRun.OFFER_SOLD]), "der Platz bleibt liegen")

func test_charm_ids_lists_owned_ids_in_order():
	run.owned_charms.append(Charm.rabbits_foot())
	run.owned_charms.append(Charm.horseshoe())
	assert_eq(run.charm_ids(), [Charm.RABBITS_FOOT, Charm.HORSESHOE] as Array[String])

# --- Charms umsortieren (Drag-and-Drop auf dem Tisch, siehe scene_root) ----------

func _own_three_charms() -> void:
	run.owned_charms.append(Charm.rabbits_foot())
	run.owned_charms.append(Charm.horseshoe())
	run.owned_charms.append(Charm.magic_card())

func test_move_charm_reorders_and_emits():
	_own_three_charms()
	watch_signals(run)
	run.move_charm(0, 2)
	assert_eq(run.owned_charm_ids(), [Charm.HORSESHOE, Charm.MAGIC_CARD, Charm.RABBITS_FOOT] as Array[String])
	assert_signal_emitted(run, "charms_changed")

func test_move_charm_backwards_shifts_neighbors_up():
	_own_three_charms()
	run.move_charm(2, 0)
	assert_eq(run.owned_charm_ids(), [Charm.MAGIC_CARD, Charm.RABBITS_FOOT, Charm.HORSESHOE] as Array[String])

func test_move_charm_ignores_invalid_or_same_indices():
	_own_three_charms()
	watch_signals(run)
	run.move_charm(1, 1)
	run.move_charm(-1, 2)
	run.move_charm(0, 3)
	assert_eq(run.owned_charm_ids(), [Charm.RABBITS_FOOT, Charm.HORSESHOE, Charm.MAGIC_CARD] as Array[String])
	assert_signal_not_emitted(run, "charms_changed")

func test_move_charm_changes_totem_neighbor_resolution():
	# Die Reihenfolge ist spielrelevant: das Papagei-Totem kopiert seinen LINKEN
	# Nachbarn (siehe charm_ids) - nach dem Umsortieren also einen anderen Charm.
	run.owned_charms.append(Charm.rabbits_foot())
	run.owned_charms.append(Charm.horseshoe())
	run.owned_charms.append(Charm.parrot_totem())
	assert_eq(run.charm_ids(), [Charm.RABBITS_FOOT, Charm.HORSESHOE, Charm.HORSESHOE] as Array[String])
	run.move_charm(2, 1)
	assert_eq(run.charm_ids(), [Charm.RABBITS_FOOT, Charm.RABBITS_FOOT, Charm.HORSESHOE] as Array[String])

func test_sell_charm_removes_credits_and_emits():
	_own_three_charms()
	watch_signals(run)
	run.money = 10
	run.sell_charm(1)
	assert_eq(run.owned_charm_ids(), [Charm.RABBITS_FOOT, Charm.MAGIC_CARD] as Array[String])
	assert_eq(run.money, 15, "Basis-Verkaufswert $5 gutgeschrieben")
	assert_signal_emitted(run, "charms_changed")

func test_sell_charm_ignores_invalid_index():
	_own_three_charms()
	watch_signals(run)
	run.sell_charm(-1)
	run.sell_charm(3)
	assert_eq(run.owned_charms.size(), 3)
	assert_signal_not_emitted(run, "charms_changed")

func test_charm_sell_value_reads_the_charm_base():
	run.owned_charms.append(Charm.rabbits_foot())
	run.owned_charms[0].sell_value = 8
	assert_eq(run.charm_sell_value(0), 8)
	assert_eq(run.charm_sell_value(1), 0, "leerer Platz ist wertlos")

# --- Eine Aufwertung existiert nur versiegelt oder angewendet ---------------------

func test_a_material_find_lands_as_a_sealed_pack():
	run.grant_material_pack(DieMaterial.by_id(DieMaterial.GOLD))
	assert_eq(run.owned_packs.size(), 1)
	assert_eq(run.owned_packs[0].type, Pack.TYPE_MATERIAL)
	assert_eq(run.owned_packs[0].fixed_engraving.id, DieMaterial.GOLD)
	assert_eq(run.owned_packs[0].price, 0)

func test_granting_an_engraving_pack_ignores_nothing():
	run.grant_engraving_pack(null)
	assert_eq(run.owned_packs.size(), 0)

func test_new_run_starts_without_levels():
	assert_true(GameRun.new_run().combo_levels.is_empty())

# --- Stresstest-Belohnung: EIN beseelter Würfel ins Ausgabefach -------------------

func test_stress_reward_books_a_souled_die_into_the_tray():
	watch_signals(run)
	var die := run.grant_stress_reward()
	assert_not_null(die, "der Stresstest zahlt einen Würfel")
	assert_eq(run.pending_dice.size(), 1, "er liegt im Ausgabefach")
	assert_eq(run.pending_dice[0], die, "gemeldet wird genau das hinterlegte Exemplar")
	assert_ne(die.essence_id, "", "garantiert beseelt")
	assert_eq(run.owned_packs.size(), 0, "nichts wird versiegelt")
	assert_signal_emitted(run, "pending_dice_changed")

func test_stress_reward_costs_nothing_and_leaves_the_pool_alone():
	run.money = 40
	var before: Array[String] = []
	for pool_die in run.owned_pool:
		before.append(pool_die.style_id)
	run.grant_stress_reward()
	assert_eq(run.money, 40, "gewonnen, nicht gekauft")
	assert_eq(run.owned_pool.size(), GameRun.POOL_SIZE, "der Pool bleibt gleich groß")
	for i in run.owned_pool.size():
		assert_eq(run.owned_pool[i].style_id, before[i], "und unangetastet")

func test_the_stress_die_never_carries_a_secret_soul():
	for _i in 20:
		var fresh := GameRun.new_run()
		var die := fresh.grant_stress_reward()
		var essence := Essence.by_id(die.essence_id)
		assert_ne(die.essence_id, "", "garantiert beseelt")
		assert_false(essence != null and essence.secret,
			"Schwarzmarkt-Seelen liegen nie im normalen Preis")

# --- Pakete (Kauf, Lager, Öffnen) ------------------------------------------------

func test_purchase_pack_deducts_and_stores_sealed():
	run.money = 20
	watch_signals(run)
	run.purchase_pack(Pack.number_pack(), Pack.NUMBER_PRICE)
	assert_eq(run.money, 20 - Pack.NUMBER_PRICE, "Preis abgezogen")
	assert_eq(run.owned_packs.size(), 1, "Paket liegt im Lager")
	assert_eq(run.owned_packs[0].count, Pack.ENGRAVING_PACK_COUNT, "ein Paket, ein Phantomwürfel")
	assert_signal_emitted(run, "packs_changed")

func test_a_pack_leaves_the_stock_only_through_the_press():
	# Es gibt keinen zweiten Weg mehr, ein Paket zu öffnen - die Serie ist es.
	run.purchase_pack(Pack.number_pack(), 0)
	assert_eq(run.owned_packs.size(), 1)
	var uids: Array[int] = [run.owned_packs[0].pack_uid]
	run.apply_series(uids, run.owned_pool[0], null, _seeded(4))
	assert_eq(run.owned_packs.size(), 0, "die Pressung verbraucht es")

# --- Das Magazin: uid, Ordnung, Deckel -------------------------------------------

func test_stashed_packs_carry_unique_uids():
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.material_pack())
	run.grant_packs([Pack.dice_mod_pack(), Pack.number_pack()] as Array[Pack])
	var seen := {}
	for pack in run.owned_packs:
		assert_gt(pack.pack_uid, 0, "jedes eingelagerte Paket trägt eine uid")
		assert_false(seen.has(pack.pack_uid), "keine uid doppelt")
		seen[pack.pack_uid] = true

# --- Der KREISLAUF: die ganze Pool-Ordnung auf einmal -------------------------

func test_reorder_pool_full_setzt_die_ganze_ordnung():
	# Am Rundenende IST der Pit-Inhalt der neue Pool: [Warteschlange][Rest][Ablage].
	var order: Array[DieDefinition] = []
	order.assign(run.owned_pool.duplicate())
	var tail: DieDefinition = order[order.size() - 1]
	order.remove_at(order.size() - 1)
	order.push_front(tail)
	watch_signals(run)
	assert_true(run.reorder_pool_full(order), "eine Permutation wird genommen")
	assert_eq(run.owned_pool[0], tail, "der letzte steht jetzt vorn")
	assert_eq(run.owned_pool.size(), order.size())
	assert_signal_emitted(run, "pool_changed")

func test_reorder_pool_full_verlangt_dieselben_instanzen():
	var order: Array[DieDefinition] = []
	order.assign(run.owned_pool.duplicate())
	var before := run.owned_pool.duplicate()
	order[0] = DieDefinition.standard()  # ein FREMDER Würfel
	assert_false(run.reorder_pool_full(order), "keine Ersetzung durch die Hintertür")
	assert_eq(run.owned_pool, before, "der Pool bleibt unberührt")

func test_reorder_pool_full_weist_luecken_und_doppel_zurueck():
	var before := run.owned_pool.duplicate()
	var short: Array[DieDefinition] = []
	short.assign(run.owned_pool.slice(0, run.owned_pool.size() - 1))
	assert_false(run.reorder_pool_full(short), "ein fehlender Würfel ist keine Ordnung")
	var doubled: Array[DieDefinition] = []
	doubled.assign(run.owned_pool.duplicate())
	doubled[1] = doubled[0]
	assert_false(run.reorder_pool_full(doubled), "und keiner steht zweimal")
	assert_eq(run.owned_pool, before)

func test_pack_by_uid_finds_its_pack_and_survives_reorder():
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.material_pack())
	var uid := run.owned_packs[0].pack_uid
	run.reorder_packs(0, 1)
	assert_eq(run.pack_index_of(uid), 1, "die uid folgt dem Paket, nicht dem Platz")
	assert_eq(run.pack_by_uid(uid).type, Pack.TYPE_NUMBER)
	assert_null(run.pack_by_uid(999), "unbekannte uid = kein Paket")

func test_reorder_packs_moves_one_and_closes_the_row():
	# remove/insert wie reorder_pool: das Gezogene landet GENAU am Ziel, alles
	# dazwischen rückt eine Stelle - nie ein Tausch.
	run.grant_packs([Pack.number_pack(), Pack.material_pack(), Pack.dice_mod_pack()] as Array[Pack])
	var first := run.owned_packs[0]
	watch_signals(run)
	run.reorder_packs(0, 2)
	assert_eq(run.owned_packs[2], first, "das gezogene Paket steht am Ziel")
	assert_eq(run.owned_packs[0].type, Pack.TYPE_MATERIAL, "die Reihe schließt sich")
	assert_signal_emitted(run, "packs_changed")
	run.reorder_packs(5, 0)  # außerhalb: nichts passiert
	assert_eq(run.owned_packs[2], first)

func test_tidy_packs_sorts_by_shelf_then_content_then_uid():
	run.grant_packs([Pack.dice_mod_pack(), Pack.number_pack(),
		Pack.catalyst(Pack.CATALYST_TIMER), Pack.number_pack()] as Array[Pack])
	run.tidy_packs()
	var shelves: Array[String] = []
	for pack in run.owned_packs:
		shelves.append(Pack.shelf_of(pack))
	assert_eq(shelves, [Engraving.CATEGORY_NUMBER, Engraving.CATEGORY_NUMBER,
		Engraving.CATEGORY_DICE, Pack.SHELF_SPECIAL] as Array[String],
		"Sortenfolge = SHELF_ORDER")
	assert_lt(run.owned_packs[0].pack_uid, run.owned_packs[1].pack_uid,
		"gleicher Inhalt: die uid bricht den Gleichstand")

## Der Deckel ist GEMESSEN und wird hereingeschoben: die Konstante trägt nur noch
## kopflos (Tests), und ein unbrauchbarer Wert lässt sie stehen.
func test_the_pack_capacity_is_injected_and_idempotent():
	assert_eq(run.pack_capacity, GameRun.PACK_CAPACITY, "ohne Grube der Rückfall")
	run.set_pack_capacity(51)
	assert_eq(run.pack_capacity, 51)
	run.set_pack_capacity(51)
	assert_eq(run.pack_capacity, 51, "dieselbe Zahl noch einmal ändert nichts")
	run.set_pack_capacity(0)
	run.set_pack_capacity(-3)
	assert_eq(run.pack_capacity, 51, "ungemessen überschreibt nichts")

func test_the_magazine_cap_is_hard_and_a_grant_fizzles_to_money():
	run.money = 500
	run.set_pack_capacity(4)
	for _i in 4:
		assert_not_null(run.grant_pack(Pack.number_pack()))
	assert_true(run.packs_full())
	var before := run.money
	assert_eq(run.purchase_pack(Pack.number_pack(), 5), 0)
	assert_eq(run.money, before, "ein voller Kauf zahlt nichts und liefert nichts")
	assert_eq(run.owned_packs.size(), 4)
	# Gewähr-Ware verdampft nicht, sie zerfällt zu Geld - eine Karte schrumpft nie.
	assert_null(run.grant_pack(Pack.material_pack()), "kein Platz, kein Paket")
	assert_eq(run.owned_packs.size(), 4, "der Deckel ist hart")
	assert_eq(run.money, before + GameRun.PACK_FIZZLE_MONEY, "dafür Geld")

func test_stash_pack_refuses_when_full():
	run.set_pack_capacity(1)
	assert_not_null(run._stash_pack(Pack.number_pack()))
	assert_null(run._stash_pack(Pack.material_pack()), "der EINE Engpass sagt nein")
	assert_eq(run.owned_packs.size(), 1)

func test_a_multi_grant_lands_what_fits_and_fizzles_the_rest():
	run.set_pack_capacity(2)
	var before := run.money
	var landed := run.grant_packs([Pack.number_pack(), Pack.material_pack(),
		Pack.dice_mod_pack(), Pack.number_pack()] as Array[Pack])
	assert_eq(landed.size(), 4, "je übergebenem Paket sein Platz in der Antwort")
	assert_not_null(landed[0])
	assert_not_null(landed[1])
	assert_null(landed[2], "ab hier ist das Magazin voll")
	assert_null(landed[3])
	assert_eq(run.owned_packs.size(), 2)
	assert_eq(run.money, before + 2 * GameRun.PACK_FIZZLE_MONEY,
		"je zerfallenem Paket einmal gebucht")

func test_every_grant_kind_fizzles_at_the_cap():
	run.set_pack_capacity(1)
	run.grant_pack(Pack.number_pack())
	var before := run.money
	assert_null(run.grant_engraving_pack(Engraving.pointer_engraving()))
	assert_null(run.grant_material_pack(DieMaterial.by_id(DieMaterial.GOLD)))
	run.owned_charms.append(Charm.encore())
	var encore := run.apply_encore(GameRun.ENCORE_STAGES)
	assert_eq(encore.size(), 1, "der Platz des Exemplars bleibt stehen")
	assert_null(encore[0], "aber leer")
	assert_eq(run.owned_packs.size(), 1, "nichts kam dazu")
	assert_eq(run.money, before + 3 * GameRun.PACK_FIZZLE_MONEY,
		"drei Prämien, drei Zerfälle")

func test_the_stress_reward_never_fizzles():
	# Der Deckel gilt fürs Magazin; ein Würfel geht ins Ausgabefach.
	run.set_pack_capacity(1)
	run.grant_pack(Pack.number_pack())
	var before := run.money
	assert_not_null(run.grant_stress_reward(), "der Preis kommt immer an")
	assert_eq(run.pending_dice.size(), 1)
	assert_eq(run.money, before, "und zerfällt nie zu Geld")

func test_the_hub_reward_remembers_what_fizzled():
	run.money = 10000
	while run.hub_level < 4:
		run.upgrade_hub()  # bis kurz vor Stufe 5, die als erste Pakete gewährt
	run.set_pack_capacity(1)
	run.grant_pack(Pack.number_pack())  # der eine Platz ist weg
	var price := run.hub_upgrade_price()
	var before := run.money
	run.upgrade_hub()
	assert_eq(run.owned_packs.size(), 1, "der Ausbau drückt nichts hinein")
	assert_true(run.last_hub_reward_packs.is_empty(), "die Merkliste kennt nur Gelandetes")
	assert_eq(run.last_hub_reward_fizzle, 3, "und zählt, wofür Geld fliegen muss")
	assert_eq(run.money, before - price
		+ run.last_hub_reward_fizzle * GameRun.PACK_FIZZLE_MONEY)

func test_a_secret_buy_checks_the_magazine_before_paying():
	run.secret_shop_unlocked = true
	run._roll_secret_stock()
	run.set_pack_capacity(1)
	run.grant_pack(Pack.number_pack())
	run.energy = 99
	for i in run.secret_stock.size():
		var kind := String(run.secret_stock[i][GameRun.OFFER_KIND])
		# Charm und Würfel hängen nicht am Magazin - der eine am Dock, der andere
		# am Ausgabefach, das keinen Deckel hat.
		if kind == GameRun.KIND_CHARM or kind == GameRun.KIND_DIE:
			continue
		assert_false(run.buy_secret_offer(i), "volles Magazin sperrt versiegelte Ware")
		assert_false(bool(run.secret_stock[i][GameRun.OFFER_SOLD]), "und der Platz bleibt")

## Der Einsatz verzehrt GENAU die benannte Sorte und Größe - und von hinten, wo die
## Neuzugänge liegen: was der Spieler nach vorn sortiert hat, bleibt ihm.
func test_a_pack_stake_consumes_exactly_the_named_packs():
	var packs: Array[Pack] = [Pack.material_pack(), Pack.number_pack(),
		Pack.material_pack(), Pack.material_pack()]
	run.grant_packs(packs)
	var keep := run.owned_packs[0]
	var spared := run.owned_packs[1]
	var bet := SideBet.new()
	bet.stake_kind = SideBet.Stake.PACKS
	bet.stake_packs = 2
	bet.stake_pack_type = Pack.TYPE_MATERIAL
	bet.stake_pack_tier = Pack.TIER_NORMAL
	assert_true(run.can_place_side_bet(bet), "drei Material-Pakete liegen da")
	var doomed := run.stake_packs_for(bet)
	assert_eq(doomed.size(), 2, "genau zwei werden geopfert")
	run.place_side_bet(bet)
	assert_eq(run.owned_packs.size(), 2)
	assert_eq(run.owned_packs[0], keep, "vorn bleibt liegen")
	assert_eq(run.owned_packs[1], spared, "und die falsche Sorte auch")
	for pack in doomed:
		assert_false(run.owned_packs.has(pack), "die gemerkten Kassetten sind fort")

## Und ohne die BENANNTE Ware ist er unbezahlbar, egal wie voll das Magazin ist.
func test_a_pack_stake_checks_the_named_type_not_the_shelf_size():
	run.grant_packs([Pack.number_pack(), Pack.number_pack(),
		Pack.number_pack()] as Array[Pack])
	var bet := SideBet.new()
	bet.stake_kind = SideBet.Stake.PACKS
	bet.stake_packs = 1
	bet.stake_pack_type = Pack.TYPE_MATERIAL
	bet.stake_pack_tier = Pack.TIER_NORMAL
	assert_false(run.can_place_side_bet(bet), "drei Zahlen-Pakete zahlen kein Material")
	run.grant_packs([Pack.material_pack()] as Array[Pack])
	assert_true(run.can_place_side_bet(bet), "eines genügt")
	bet.stake_pack_tier = Pack.TIER_GROSS
	assert_false(run.can_place_side_bet(bet), "und die GRÖSSE zählt mit")

## Die Inventar-Sicht der Auslage: Sorte+Größe -> Anzahl, reine Daten. Fixinhalt und
## Katalysator zählen nicht mit - ein Einsatz nimmt normale Regal-Ware.
func test_the_pack_stock_counts_by_type_and_tier():
	run.grant_packs([Pack.number_pack(),
		Pack.roll_engraving_pack(Pack.TIER_GROSS)] as Array[Pack])
	run.grant_packs([Pack.catalyst(Pack.CATALYST_TIMER)] as Array[Pack])
	var stock := run.pack_stock()
	var plain := 0
	for key: String in stock:
		plain += int(stock[key])
	assert_eq(plain, 2, "der Katalysator zählt nicht als Einsatz-Ware")
	assert_eq(int(stock.get(SideBet.pack_stock_key(Pack.TYPE_NUMBER,
		Pack.TIER_NORMAL), 0)), 1)

func test_the_exchange_replaces_the_chosen_slot_only():
	run.stash_die(DieDefinition.fixed(6, "Immer 6"), 0)
	assert_true(run.exchange_pending_die(0, 7))
	assert_eq(run.owned_pool[7].style_id, "fixed_6", "gewählter Platz getauscht")
	assert_eq(_count_style("fixed_6"), 1, "nur dieser eine Platz")
	assert_eq(run.owned_pool.size(), GameRun.POOL_SIZE)
	assert_eq(run.pending_dice.size(), 0, "und das Fach ist wieder leer")

func test_the_stashed_die_is_an_independent_copy():
	var die := DieDefinition.fixed(6, "Immer 6")
	run.stash_die(die, 0)
	run.exchange_pending_die(0, 3)
	run.owned_pool[3].faces[0] = 1
	assert_eq(die.faces[0], 6, "die Auslage-Vorlage bleibt unverändert")

func test_die_serie_reicht_immer_den_OBERSTEN_neuzugang_nach():
	# Die SERIEN-Platzierung setzt einen nach dem anderen: nach jedem Tausch
	# rutschen die pending-Indizes, offen liegt darum IMMER Index 0.
	run.stash_die(DieDefinition.fixed(6, "Immer 6"), 0)
	run.stash_die(DieDefinition.fixed(5, "Immer 5"), 0)
	run.stash_die(DieDefinition.fixed(4, "Immer 4"), 0)
	assert_eq(run.pending_dice.size(), 3, "drei Neuzugänge warten")
	assert_true(run.exchange_pending_die(0, 2))
	assert_eq(run.owned_pool[2].style_id, "fixed_6", "der erste sitzt")
	assert_eq(run.pending_dice.size(), 2, "zwei stehen noch aus")
	assert_eq(run.pending_dice[0].style_id, "fixed_5", "und der nächste ist Index 0")
	assert_true(run.exchange_pending_die(0, 9))
	assert_eq(run.owned_pool[9].style_id, "fixed_5")
	assert_eq(run.pending_dice[0].style_id, "fixed_4", "der letzte rückt nach")
	assert_true(run.exchange_pending_die(0, 11))
	assert_true(run.pending_dice.is_empty(), "erst jetzt ist die Serie zu Ende")

func test_the_exchange_ignores_slots_outside_the_pool():
	run.stash_die(DieDefinition.fixed(6, "Immer 6"), 0)
	assert_false(run.exchange_pending_die(0, GameRun.POOL_SIZE))
	assert_eq(_count_style("fixed_6"), 0)
	assert_eq(run.owned_pool.size(), GameRun.POOL_SIZE, "Pool unverändert")
	assert_eq(run.pending_dice.size(), 1, "und der Würfel bleibt liegen")

# --- Automaten-Gewinne (auswürfeln und buchen sind getrennt) ---------------------

## Wand mit einer 3er-Reihe des Symbols in der obersten Zeile; der Rest bildet in
## keiner Richtung eine Reihe.
func _winning_wall(symbol: int) -> void:
	var filler := [SlotPrize.Kind.ENERGY, SlotPrize.Kind.FUMBLE]
	for c in SlotMachine.TOTAL_COLS:
		var col: Array = []
		for r in SlotMachine.ROWS:
			if r == 0 and c < 3:
				col.append(symbol)
			else:
				col.append(filler[(c + r) % 2])
		run.slot_bank.cells[c] = col
	run.slot_bank.spun = [true, true, true]

func test_redeeming_rolls_the_prizes_without_booking_them():
	# Gebucht wird erst, wenn der Gewinn als Licht den Automaten verlässt - sonst
	# füllte sich das Lager, bevor überhaupt etwas geflogen ist.
	_winning_wall(SlotPrize.Kind.MATERIAL)
	var packs_before := run.owned_packs.size()
	var result := run.redeem_slots()
	assert_gt(result["prizes"].size(), 0, "die Reihe löst sich in Preise auf")
	assert_eq(run.owned_packs.size(), packs_before, "aber noch nichts im Lager")
	assert_eq(run.slot_bank.hit_count(), 0, "die Sitzung ist zurückgesetzt")

func test_booking_a_prize_grants_its_packs():
	_winning_wall(SlotPrize.Kind.MATERIAL)
	var packs_before := run.owned_packs.size()
	var prizes: Array = run.redeem_slots()["prizes"]
	var expected := 0
	for prize: SlotPrize in prizes:
		expected += prize.packs.size()
		run.book_slot_prize(prize)
	assert_gt(expected, 0, "die Reihe zahlt Pakete")
	assert_eq(run.owned_packs.size(), packs_before + expected, "jetzt liegt die Ware im Lager")
	for i in range(packs_before, run.owned_packs.size()):
		assert_eq(run.owned_packs[i].type, Pack.TYPE_MATERIAL, "in der eigenen Sorte")

func test_booking_a_prize_multiple_times_gives_separate_packs():
	var prize := SlotPrize.new()
	prize.kind = SlotPrize.Kind.ENGRAVING
	prize.packs = [Pack.number_pack(), Pack.number_pack()] as Array[Pack]
	run._book_slot_prize(prize, 2)
	assert_eq(run.owned_packs.size(), 4, "Multiplikator vervielfacht die Pakete")
	assert_false(run.owned_packs[0] == run.owned_packs[2], "keine geteilte Resource")

func test_booking_carries_the_pack_size_into_the_magazine():
	# Der Automat ist die zweite Größenquelle - die Kopie des Multiplikators darf
	# die Größe nicht unterwegs verlieren.
	var prize := SlotPrize.from_spec({"kind": "pack", "symbol": SlotPrize.Kind.MATERIAL,
		"count": 2, "tier": Pack.TIER_KOLOSSAL})
	run._book_slot_prize(prize, 2)
	assert_eq(run.owned_packs.size(), 4)
	for pack: Pack in run.owned_packs:
		assert_eq(pack.tier, Pack.TIER_KOLOSSAL, "die Größe überlebt die Buchung")
		assert_eq(pack.display_name, "Kolossales Material-Paket")

func test_a_full_magazine_turns_a_slot_prize_into_money():
	# Auch die dickste Reihe zerfällt am vollen Magazin Paket für Paket zu Geld -
	# der Automat kennt dafür keine eigene Zeremonie, aber verschlucken darf er nichts.
	run.set_pack_capacity(2)
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	var money_before := run.money
	var prize := SlotPrize.from_spec({"kind": "pack", "symbol": SlotPrize.Kind.ENGRAVING,
		"count": 3, "tier": Pack.TIER_KOLOSSAL})
	run.book_slot_prize(prize)
	assert_eq(run.owned_packs.size(), 2, "das Magazin bleibt voll")
	assert_eq(run.money, money_before + 3 * GameRun.PACK_FIZZLE_MONEY,
		"je zerfallenem Paket eine Münze")

func test_a_slot_pack_is_a_plain_sealed_pack():
	# Der Raritäts-Boden ist gestorben: alle sechs Seiten sind gleich wahrscheinlich,
	# die Stärke kommt aus der Hand.
	var prize := SlotPrize.from_spec({"kind": "pack", "symbol": SlotPrize.Kind.DICE_ENGRAVING,
		"count": 1})
	assert_eq(prize.packs.size(), 1)
	assert_eq(prize.packs[0].type, Pack.TYPE_DICE_MOD)
	assert_eq(prize.packs[0].count, Pack.ENGRAVING_PACK_COUNT)
	run.book_slot_prize(prize)
	assert_eq(run.owned_packs.size(), 1, "versiegelt ins Lager")

func test_booking_a_won_die_lands_in_the_out_tray():
	var prize := SlotPrize.new()
	prize.kind = SlotPrize.Kind.DIE
	prize.die = DieDefinition.fixed(6, "Immer 6")
	run.book_slot_prize(prize)
	assert_eq(run.pending_dice.size(), 1, "der gewonnene Würfel wartet im Ausgabefach")
	assert_eq(_count_style("fixed_6"), 0, "der Vorrat bleibt unberührt")
	assert_eq(run.owned_pool.size(), GameRun.POOL_SIZE, "und gleich groß")

## Das ⚡-Symbol ersetzt den Charm: eine Reihe zahlt Energie in denselben Speicher
## wie jede andere Quelle - und was nicht mehr hineinpaßt, zahlt bar.
func test_booking_a_won_energy_fills_the_capacitor():
	var prize := SlotPrize.from_spec({"kind": "energy", "amount": 3})
	assert_eq(prize.kind, SlotPrize.Kind.ENERGY)
	assert_eq(prize.energy, 3)
	assert_eq(prize.label, "3⚡", "der Zwischenspeicher nennt die Menge")
	run.energy = 0
	run.book_slot_prize(prize)
	assert_eq(run.energy, 3, "die Energie liegt in der Bank")

func test_a_full_capacitor_pays_the_slot_energy_in_money():
	var prize := SlotPrize.from_spec({"kind": "energy", "amount": 4})
	run.energy = run.energy_cap()
	var money_before := run.money
	run.book_slot_prize(prize)
	assert_eq(run.energy, run.energy_cap(), "der Speicher bleibt voll")
	assert_eq(run.money, money_before + 4 * GameRun.ENERGY_OVERFLOW_MONEY,
		"der Überlauf zahlt bar - dieselbe Grammatik wie die ⚡-Wette")

func test_the_multiplier_scales_the_won_energy():
	var prize := SlotPrize.from_spec({"kind": "energy", "amount": 2})
	run.energy = 0
	run._book_slot_prize(prize, 2)
	assert_eq(run.energy, 4)


# --- Rundenfortschritt -----------------------------------------------------------

func test_advance_round_increments_number_and_goal():
	run.advance_round()
	run.advance_round()
	assert_eq(run.round_number, 3)
	assert_eq(run.round_goal, GameRun.BASE_GOAL + 2 * GameRun.GOAL_INCREMENT)

func test_goal_curve_doubles_its_step_every_block():
	# Erster Block 75er-Schritte, dann 150 / 300 / 600 - die Wertung wächst
	# multiplikativ, das Ziel muss mithalten.
	assert_eq(GameRun.goal_for_round(1), 150, "Startziel")
	assert_eq(GameRun.goal_for_round(6), 525, "Block 1 endet bei 525")
	assert_eq(GameRun.goal_for_round(7), 675, "erster 150er-Schritt")
	assert_eq(GameRun.goal_for_round(12), 1425)
	assert_eq(GameRun.goal_for_round(13), 1725, "erster 300er-Schritt")
	assert_eq(GameRun.goal_for_round(18), 3225)
	assert_eq(GameRun.goal_for_round(24), 6825, "vierter Block: 600er-Schritte")

func test_advance_round_follows_the_curve_across_a_block_edge():
	for i in 6:
		run.advance_round()
	assert_eq(run.round_number, 7)
	assert_eq(run.round_goal, GameRun.goal_for_round(7), "Rundenwechsel liest die Kurve")
	assert_eq(run.round_goal, 675)

# --- Testhilfen: Zufallsmaterialien (Testmodus) ----------------------------------

func test_randomize_gives_each_die_an_independent_array():
	# Kein geteiltes materials-Array: eine In-place-Änderung an einem Würfel darf
	# keinen anderen mitverändern (Sentinel-Wert, deterministisch).
	run.randomize_all_materials()
	run.owned_pool[0].materials[0] = "SENTINEL"
	for i in range(1, run.owned_pool.size()):
		assert_ne(run.owned_pool[i].materials[0], "SENTINEL", "Würfel %d teilt kein Array mit Würfel 0" % i)

func test_randomize_also_raises_some_faces():
	# Testmodus zeigt die Stufen-Wirkungen ohne Gravur-Grind: ein Teil der
	# Material-Seiten kommt gehoben (30 Würfel × 6 Seiten - nie alles auf I).
	run.randomize_all_materials()
	var raised := 0
	for die in run.owned_pool:
		assert_eq(die.levels.size(), 6, "weiterhin 6 Stufen")
		for level: int in die.levels:
			assert_true(level >= 1 and level <= DieMaterial.MAX_LEVEL, "Stufe im Rahmen: %d" % level)
			if level >= 2:
				raised += 1
	assert_gt(raised, 0, "irgendeine Seite steht über Stufe I")

func test_randomize_gives_each_die_an_independent_level_array():
	run.randomize_all_materials()
	run.owned_pool[0].levels[0] = 0  # ein Wert, den der Würfelwurf nie erzeugt
	var differs := false
	for i in range(1, run.owned_pool.size()):
		if run.owned_pool[i].levels[0] != 0:
			differs = true
	assert_true(differs, "kein geteiltes levels-Array")

func test_clear_all_materials_also_clears_the_levels():
	run.randomize_all_materials()
	run.clear_all_materials()
	for die in run.owned_pool:
		for level: int in die.levels:
			assert_eq(level, 0, "ohne Material keine Stufe")

# --- Testhilfen: Zufalls-Pointer (Testmodus) --------------------------------

func test_randomize_all_pointers_gives_every_die_one_to_five_valid_links():
	run.randomize_all_pointers()
	for die in run.owned_pool:
		assert_eq(die.pointers.size(), 6, "weiterhin 6 Seiten")
		var count := 0
		for face in 6:
			var target: int = die.pointers[face]
			if target < 0:
				continue
			count += 1
			assert_true(die.can_point(face, target),
				"Seite %d zeigt auf einen Nachbarn (%d)" % [face, target])
		assert_between(count, 1, 5, "1-5 Pointer je Würfel")

func test_randomize_pointers_gives_each_die_an_independent_array():
	run.randomize_all_pointers()
	run.owned_pool[0].pointers[0] = 99
	for i in range(1, run.owned_pool.size()):
		assert_ne(run.owned_pool[i].pointers[0], 99, "Würfel %d teilt kein Array mit Würfel 0" % i)

func test_randomize_pointers_varies_between_dice():
	# Zufällig heißt: nicht alle 30 Würfel bekommen dieselbe Anzahl.
	run.randomize_all_pointers()
	var counts := {}
	for die in run.owned_pool:
		var count := 0
		for target: int in die.pointers:
			if target >= 0:
				count += 1
		counts[count] = true
	assert_gt(counts.size(), 1, "die Anzahl streut über den Pool")

func test_clear_all_pointers_removes_every_link():
	run.randomize_all_pointers()
	run.clear_all_pointers()
	for die in run.owned_pool:
		for target: int in die.pointers:
			assert_eq(target, -1, "Pointer entfernt")

# --- Testhilfen: Zufalls-Seelen (Testmodus) -------------------------------------

func test_randomize_all_essences_gives_every_die_a_real_soul():
	run.randomize_all_essences()
	for die in run.owned_pool:
		assert_not_null(Essence.by_id(die.essence_id), "echte Seele: %s" % die.essence_id)

func test_randomize_all_essences_deals_instead_of_drawing():
	# Ausgeteilt, nicht gewürfelt: 30 Würfel aus 33 Seelen heißt 30 verschiedene -
	# nur so liegen alle Raritätsstufen zum Vergleich nebeneinander.
	run.randomize_all_essences()
	var seen := {}
	for die in run.owned_pool:
		seen[die.essence_id] = true
	assert_eq(seen.size(), run.owned_pool.size(), "keine Seele doppelt")

func test_randomize_all_essences_covers_every_rarity():
	# Gesät: ausgeteilt werden 30 von 33 Seelen - fielen die drei Übrigen zufällig
	# alle auf eine Stufe, wäre der Test flatterhaft statt aussagekräftig.
	seed(20260808)
	run.randomize_all_essences()
	var rarities := {}
	for die in run.owned_pool:
		rarities[Essence.by_id(die.essence_id).rarity] = true
	for rarity in [Essence.Rarity.COMMON, Essence.Rarity.RARE, Essence.Rarity.EPIC,
			Essence.Rarity.LEGENDARY]:
		assert_true(rarities.has(rarity), "%s liegt im Pool" % Essence.rarity_name(rarity))

func test_randomize_all_essences_keeps_uniques_unique():
	run.randomize_all_essences()
	var counts := {}
	for die in run.owned_pool:
		counts[die.essence_id] = int(counts.get(die.essence_id, 0)) + 1
	for id: String in counts:
		if Essence.by_id(id).unique:
			assert_eq(counts[id], 1, "%s bleibt Unikat" % id)

func test_clear_all_essences_also_takes_the_second_break():
	# Ohne Vakuum trägt die Schale keinen zweite Rune mehr.
	run.randomize_all_essences()
	run.owned_pool[0].essence_id = Essence.VACUUM
	run.owned_pool[0].set_rune(0, Rune.AFTERGLOW, 1)
	run.clear_all_essences()
	for die in run.owned_pool:
		assert_eq(die.essence_id, "", "Seele entfernt")
		for rune_id: String in die.second_runes:
			assert_eq(rune_id, "", "zweiter Bruch entfernt")

# --- Nebenwetten --------------------------------------------------------------

func test_place_side_bet_deducts_stake_and_stores():
	watch_signals(run)
	run.money = 20
	var bet := SideBet._from_template(_template("two_pair"))  # Geld-Einsatz
	run.place_side_bet(bet)
	assert_eq(run.money, 20 - bet.stake, "Einsatz sofort fällig")
	assert_eq(run.active_side_bets.size(), 1)
	assert_signal_emitted(run, "side_bets_changed")

func test_place_pack_stake_consumes_packs():
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.material_pack())
	var before := run.owned_packs.size()
	var bet := SideBet._from_template(_template("pawn"))  # 1 Paket Einsatz
	assert_true(run.can_place_side_bet(bet), "mit Paketen bezahlbar")
	run.place_side_bet(bet)
	assert_eq(run.owned_packs.size(), before - 1, "ein Paket geopfert")

func test_cannot_place_pack_stake_without_packs():
	var bet := SideBet._from_template(_template("collateral"))  # 2 Pakete Einsatz
	assert_false(run.can_place_side_bet(bet), "ohne genug Pakete nicht setzbar")

func test_resolve_pack_payout_grants_packs_and_clears():
	run.money = 50
	var win := SideBet._from_template(_template("full_house"))  # Gravur-Gewinn
	var lose := SideBet._from_template(_template("big_hand"))
	run.place_side_bet(win)
	run.place_side_bet(lose)
	var before := run.owned_packs.size()
	var result := {"cleared": true, "best_combo_rank": SideBet.combo_rank(DiceScoring.FULL_HOUSE),
		"best_hand_score": 0, "dice_taken": 0, "farkled": false}
	var won := run.resolve_side_bets(result)
	assert_eq(won.size(), 1, "nur das volle Haus gewinnt")
	assert_eq(won[0].id, "full_house")
	assert_eq(run.owned_packs.size(), before + win.reward_packs, "Pakete ausgeschüttet")
	assert_eq(run.active_side_bets.size(), 0, "Auslage geleert")
	# JEDES gewährte Paket ist GEMERKT: die Auszahlungs-Seite hält genau diese
	# Kassetten bis zum Kassieren zurück und zielt dann auf ihre uids.
	assert_eq(win.awarded_packs.size(), win.reward_packs,
		"alle Gravur-Paket-Gewinne stehen in awarded_packs")
	for pack: Pack in win.awarded_packs:
		assert_gt(pack.pack_uid, 0, "und jeder trägt seine Magazin-uid")
	assert_eq(win.awarded_fizzled, 0, "nichts zerfallen")

func test_resolve_pack_payout_counts_fizzles_at_full_magazine():
	run.money = 50
	var win := SideBet._from_template(_template("full_house"))  # Gravur-Gewinn
	run.place_side_bet(win)
	while not run.packs_full():
		run.grant_pack(Pack.roll_engraving_pack())
	var money_before := run.money
	var result := {"cleared": true, "best_combo_rank": SideBet.combo_rank(DiceScoring.FULL_HOUSE),
		"best_hand_score": 0, "dice_taken": 0, "farkled": false}
	run.resolve_side_bets(result)
	assert_eq(win.awarded_packs.size(), 0, "volles Magazin: nichts gewährt")
	assert_eq(win.awarded_fizzled, win.reward_packs, "jeder Zerfall ist gezählt")
	assert_eq(run.money, money_before + win.reward_packs * GameRun.PACK_FIZZLE_MONEY,
		"und zahlt sein Fizzle-Geld")

func test_resolve_money_payout_adds_cash():
	run.money = 50
	var bet := SideBet._from_template(_template("jackpot"))  # Geld-Gewinn
	run.place_side_bet(bet)
	var after_stake := run.money  # Einsatz bereits abgezogen
	var result := {"cleared": true, "best_combo_rank": SideBet.combo_rank(DiceScoring.FULL_HOUSE),
		"best_hand_score": 0, "dice_taken": 0, "farkled": false}
	run.resolve_side_bets(result)
	assert_eq(run.money, after_stake + bet.payout_money, "Barauszahlung gutgeschrieben")

func _template(id: String) -> Dictionary:
	for t in SideBet.TEMPLATES:
		if t["id"] == id:
			return t
	return {}

# --- Übertakten (am Chip, bezahlt mit Energie) ---------------------------------

func test_overclock_cost_climbs_per_stage_and_caps():
	# 1 ⚡ plus eine je erklommener Stufe, gedeckelt bei 5 - unabhängig davon,
	# WELCHE Kombination übertaktet wird.
	assert_eq(GameRun.overclock_cost_at(0), 1)
	assert_eq(GameRun.overclock_cost_at(1), 2)
	assert_eq(GameRun.overclock_cost_at(4), 5)
	assert_eq(GameRun.overclock_cost_at(7), 5, "gedeckelt, aber ohne Stufen-Limit")

func test_overclock_cost_is_the_same_for_every_combination():
	assert_eq(run.overclock_cost(DiceScoring.TWO_KIND), run.overclock_cost(DiceScoring.SIX_KIND))

func test_overclock_combo_spends_energy_and_levels():
	watch_signals(run)
	run.energy = 5
	assert_true(run.overclock_combo(DiceScoring.FULL_HOUSE))
	assert_eq(run.energy, 4, "eine Energie für die erste Stufe")
	assert_eq(run.combo_level(DiceScoring.FULL_HOUSE), 1)
	assert_signal_emitted(run, "combo_upgraded")
	assert_true(run.overclock_combo(DiceScoring.FULL_HOUSE))
	assert_eq(run.energy, 2, "die zweite Stufe kostet zwei")

func test_overclock_without_energy_changes_nothing():
	watch_signals(run)
	run.energy = 0
	assert_false(run.overclock_combo(DiceScoring.FULL_HOUSE))
	assert_eq(run.combo_level(DiceScoring.FULL_HOUSE), 0)
	assert_eq(run.energy, 0, "nichts abgebucht")
	assert_signal_not_emitted(run, "combo_upgraded")

func test_overclock_raises_scoring():
	run.energy = 5
	run.overclock_combo(DiceScoring.TWO_KIND)
	assert_eq(DiceScoring.mult_for(DiceScoring.TWO_KIND, run.combo_levels), 4, "Paar: +2 je Stufe")
	assert_eq(DiceScoring.points_for(DiceScoring.TWO_KIND, run.combo_levels), 20)

func test_can_overclock_checks_energy():
	run.energy = GameRun.overclock_cost_at(0)
	assert_true(run.can_overclock(DiceScoring.TWO_KIND))
	run.energy -= 1
	assert_false(run.can_overclock(DiceScoring.TWO_KIND))

# --- Rampenlicht & Midashandschuh -------------------------------------------------

func test_spotlight_picks_a_combination_each_round():
	run.apply_round_start_charms()
	assert_eq(run.spotlight_combo, "", "ohne Charm steht nichts im Licht")
	run.owned_charms.append(Charm.spotlight())
	run.apply_round_start_charms()
	assert_true(DiceScoring.HAND_PRIORITY.has(run.spotlight_combo), "eine echte Kombination")
	assert_false(run.spotlight_claimed_this_round)

func test_spotlight_levels_the_combination_once_per_round():
	run.owned_charms.append(Charm.spotlight())
	run.apply_round_start_charms()
	var key: String = run.spotlight_combo
	assert_false(run.claim_spotlight("nonsense"), "eine andere Kombination zählt nicht")
	assert_true(run.claim_spotlight(key))
	assert_eq(run.combo_level(key), 1, "dauerhaft eine Stufe höher")
	assert_false(run.claim_spotlight(key), "zweimal in derselben Runde nicht")
	run.apply_round_start_charms()
	assert_false(run.spotlight_claimed_this_round, "neue Runde, neue Chance")

func test_midas_glove_gilds_every_shown_face_of_a_full_hand():
	run.owned_charms.append(Charm.midas_glove())
	var defs: Array[DieDefinition] = []
	for i in 6:
		defs.append(DieDefinition.standard())
	var faces := _p([0, 1, 2, 3, 4, 5])
	var gilded := run.apply_midas_glove(defs, faces, _p([0, 1, 2, 3, 4, 5]))
	assert_eq(gilded.size(), 6, "alle sechs oben liegenden Seiten")
	for i in 6:
		assert_eq(defs[i].materials[faces[i]], DieMaterial.GOLD)
		assert_eq(defs[i].materials[(faces[i] + 1) % 6], "", "andere Seiten bleiben unberührt")

func test_midas_glove_stays_cold_below_six_dice():
	run.owned_charms.append(Charm.midas_glove())
	var defs: Array[DieDefinition] = []
	for i in 5:
		defs.append(DieDefinition.standard())
	assert_eq(run.apply_midas_glove(defs, _p([0, 0, 0, 0, 0]), _p([0, 1, 2, 3, 4])).size(), 0)
	assert_eq(defs[0].materials[0], "", "nichts vergoldet")

func test_midas_glove_resets_the_level_of_the_face_it_gilds():
	# Neues Material auf der Seite - die alte Stufe gehoert dem alten Exemplar.
	run.owned_charms.append(Charm.midas_glove())
	var defs: Array[DieDefinition] = []
	for i in 6:
		var die := DieDefinition.standard()
		die.set_face_material(i, DieMaterial.RUBY)
		die.levels[i] = DieMaterial.MAX_LEVEL
		defs.append(die)
	var faces := _p([0, 1, 2, 3, 4, 5])
	run.apply_midas_glove(defs, faces, _p([0, 1, 2, 3, 4, 5]))
	for i in 6:
		assert_eq(defs[i].materials[faces[i]], DieMaterial.GOLD)
		assert_eq(defs[i].material_level(faces[i]), 1, "die Rubin-Stufe ist mit dem Rubin weg")

func test_the_jewelry_box_never_touches_a_die():
	# Sie füllt den Vorrat, nicht den Würfel - Seiten und Zustände bleiben, wie
	# sie waren, egal wie oft sie zuschlägt.
	run.owned_charms.append(Charm.jewelry_box())
	run.pack_capacity = 500  # der Magazin-Deckel ist hier nicht das Thema
	var many: Array[DieDefinition] = []
	for i in 200:
		var die := DieDefinition.standard()
		die.set_face_material(0, DieMaterial.RUBY)
		die.levels[0] = DieMaterial.MAX_LEVEL
		many.append(die)
	var grants := run.apply_jewelry_box(many)
	assert_gt(grants.size(), 0, "bei 200 Würfeln findet sie praktisch sicher")
	assert_eq(run.owned_packs.size(), grants.size(), "je Fund ein versiegeltes Mini-Paket")
	for die in many:
		assert_eq(die.materials[0], DieMaterial.RUBY)
		assert_eq(die.material_level(0), DieMaterial.MAX_LEVEL, "die Veredelung bleibt stehen")
		for face in range(1, 6):
			assert_eq(die.materials[face], "", "keine neue Seite wurde belegt")

# --- Stresstest (Thermal Throttling) ----------------------------------------------

func test_stress_round_is_every_last_block_station():
	assert_false(GameRun.is_stress_round(1))
	assert_false(GameRun.is_stress_round(5))
	assert_true(GameRun.is_stress_round(6))
	assert_false(GameRun.is_stress_round(7))
	assert_true(GameRun.is_stress_round(12))

func test_hottest_combo_takes_the_highest_level():
	run.combo_levels[DiceScoring.TWO_KIND] = 3
	run.combo_levels[DiceScoring.FOUR_KIND] = 5
	assert_eq(run.hottest_combos(1)[0], DiceScoring.FOUR_KIND)

func test_hottest_combo_breaks_ties_by_rank():
	run.combo_levels[DiceScoring.TWO_KIND] = 3
	run.combo_levels[DiceScoring.FOUR_KIND] = 3
	assert_eq(run.hottest_combos(1)[0], DiceScoring.FOUR_KIND, "Gleichstand -> der ranghöhere Chip")

func test_hottest_combo_never_throttles_the_fallback_category():
	# "Höchste Zahl" ist die Rückfall-Kategorie jeder Hand: gedrosselt könnte eine
	# Hand ohne jede wertbare Kategorie enden.
	run.combo_levels[DiceScoring.ONE_KIND] = 9
	run.combo_levels[DiceScoring.TWO_KIND] = 2
	assert_eq(run.hottest_combos(1)[0], DiceScoring.TWO_KIND)

func test_hottest_combos_rank_by_level_then_priority():
	run.combo_levels[DiceScoring.TWO_KIND] = 5
	run.combo_levels[DiceScoring.FOUR_KIND] = 5
	run.combo_levels[DiceScoring.FULL_HOUSE] = 3
	var hottest := run.hottest_combos(3)
	assert_eq(hottest[0], DiceScoring.FOUR_KIND, "Gleichstand -> der ranghöhere zuerst")
	assert_eq(hottest[1], DiceScoring.TWO_KIND)
	assert_eq(hottest[2], DiceScoring.FULL_HOUSE, "dann die nächstniedrigere Stufe")

func test_round_start_throttles_only_under_a_clause():
	run.combo_levels[DiceScoring.FULL_HOUSE] = 4
	run.apply_round_start_charms()
	assert_eq(run.throttled_combos, [], "ohne Klausel drosselt nichts")
	run.sign_clauses([DealClause.HEAT_WARNING] as Array[String])
	run.apply_round_start_charms()
	assert_eq(run.throttled_combos, [DiceScoring.FULL_HOUSE])

func test_spotlight_avoids_the_throttled_combo():
	# Der gedrosselte Chip wertet nicht - ein Rampenlicht darauf wäre verschenkt.
	run.owned_charms.append(Charm.spotlight())
	run.sign_clauses([DealClause.HEAT_WARNING] as Array[String])
	run.combo_levels[DiceScoring.SIX_KIND] = 4
	for i in 40:
		run.apply_round_start_charms()
		assert_ne(run.spotlight_combo, DiceScoring.SIX_KIND)

# --- Verträge: Laufzeiten ----------------------------------------------------------

## Unterschreibt Klauseln direkt (ohne Auslage) - Basis fast aller Vertrags-Tests.
func _sign(clause_ids: Array, in_round: int = 1) -> void:
	run.round_number = in_round
	var typed: Array[String] = []
	typed.assign(clause_ids)
	run.sign_clauses(typed)

func test_no_clause_outlives_its_round():
	# Kein Deal überlebt seine Runde mehr - auch der Bonus verfällt mit ihr.
	_sign([DealClause.SAVINGS_BONUS])
	assert_eq(run.deal_unused_die_bonus(), GameRun.SAVINGS_DIE_BONUS)
	run.advance_round()
	assert_eq(run.deal_unused_die_bonus(), 0, "die Runde ist vorbei, die Klausel auch")

func test_every_clause_of_the_catalogue_is_instant_or_round():
	for clause in DealClause.all():
		assert_ne(clause.scope, DealClause.Scope.BLOCK,
			"%s müsste sofort oder rundenweise wirken" % clause.id)

func test_round_clause_dies_with_its_round():
	_sign([DealClause.HAPPY_HOUR])
	assert_eq(run.money_gain_factor(), 2.0)
	run.advance_round()
	assert_eq(run.money_gain_factor(), 1.0, "nur die Runde der Unterschrift")

func test_the_scope_arbiter_knows_all_three_durations():
	# _scope_reaches bleibt der einzige Schiedsrichter - auch für BLOCK, das
	# aktuell keine Klausel trägt.
	var entry := {"id": DealClause.SAVINGS_BONUS, "round": 2}
	assert_false(run._scope_reaches(entry, DealClause.Scope.INSTANT, 2))
	assert_true(run._scope_reaches(entry, DealClause.Scope.ROUND, 2))
	assert_false(run._scope_reaches(entry, DealClause.Scope.ROUND, 3))
	assert_true(run._scope_reaches(entry, DealClause.Scope.BLOCK, 3), "noch im Block")
	assert_false(run._scope_reaches(entry, DealClause.Scope.BLOCK, GameRun.GOAL_BLOCK + 1))

func test_the_signature_locks_the_clause_for_the_whole_block():
	# Die Wirkung endet mit der Runde, der Eintrag bleibt: er sperrt seine Klausel
	# bis zur Abrechnung gegen ein zweites Angebot.
	_sign([DealClause.SAVINGS_BONUS])
	run.advance_round()
	assert_true(run._taken_this_block(DealClause.SAVINGS_BONUS))
	run.settle_block_deals()
	assert_false(run._taken_this_block(DealClause.SAVINGS_BONUS))

func test_instant_clause_pays_once_on_signing():
	var before := run.money
	_sign([DealClause.ADVANCE_PAYMENT])
	assert_eq(run.money, before + GameRun.ADVANCE_PAYMENT_MONEY, "sofort auf die Hand")
	run.advance_round()
	assert_eq(run.money, before + GameRun.ADVANCE_PAYMENT_MONEY, "aber nur einmal")

func test_instant_energy_clauses_book_immediately():
	_sign([DealClause.SEED_CAPITAL])
	assert_eq(run.energy, GameRun.SEED_CAPITAL_ENERGY)
	_sign([DealClause.DISCHARGE])
	assert_eq(run.energy, 0, "unter null geht die Börse nie")

func test_signing_a_card_clears_the_offers_and_signals():
	run.roll_route_offers()
	watch_signals(run)
	# Ein Platz kann als Werbegeschenk ohne Kleingedrucktes liegen (~9 %) - für
	# die Zwei-Seiten-Zusicherung braucht es eine Karte, die beide trägt.
	var slot := 1
	for i in run.route_offers.size():
		if String(run.route_offers[i].get(GameRun.CARD_MALUS, "")) != "":
			slot = i
			break
	run.take_route(slot)
	assert_true(run.route_offers.is_empty(), "die Auslage ist verbraucht")
	assert_eq(run.active_deals.size(), 2, "Bonus UND Kleingedrucktes ziehen ein")
	assert_signal_emitted(run, "deals_changed")

# --- Verträge: Auslage -------------------------------------------------------------

## Alle Klausel-ids einer Karte.
func _card_ids(card: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for key in [GameRun.CARD_BONUS, GameRun.CARD_MALUS]:
		var clause_id := String(card.get(key, ""))
		if clause_id != "":
			ids.append(clause_id)
	return ids

func test_the_first_round_gets_no_offers():
	# Die erste Runde eines Laufs gehört dem Spieler allein - erst danach legt
	# das Haus Konditionen auf den Tisch.
	var fresh := GameRun.new_run()
	assert_true(fresh.route_offers.is_empty(), "Runde 1 ohne Auslage")
	fresh.advance_round()
	assert_eq(fresh.route_offers.size(), GameRun.ROUTE_OFFER_COUNT, "ab Runde 2 liegt sie aus")

func test_offers_are_always_one_of_each_tier():
	# Grundauslage von links nach rechts: Standard-, Risiko-, Knebelvertrag. Ein
	# Platz KANN stattdessen ein Werbegeschenk sein, sonst steht dort seine Stufe.
	var base := [DealClause.Tier.ONE, DealClause.Tier.TWO, DealClause.Tier.THREE]
	var saw_pure := false
	for i in 60:
		run.route_offers.clear()
		run.roll_route_offers()
		assert_eq(run.route_offers.size(), GameRun.ROUTE_OFFER_COUNT)
		var treats := 0
		for slot in 3:
			var tier := int(run.route_offers[slot][GameRun.CARD_TIER])
			assert_true(tier == int(base[slot]) or tier == int(DealClause.Tier.TREAT),
				"Platz %d: seine Stufe oder ein Werbegeschenk" % slot)
			if tier == int(DealClause.Tier.TREAT):
				treats += 1
			for clause_id in _card_ids(run.route_offers[slot]):
				assert_true(DealClause.is_valid_id(clause_id))
		assert_lte(treats, 1, "höchstens EIN Werbegeschenk je Auslage")
		if treats == 0:
			saw_pure = true
	assert_true(saw_pure, "meist liegt die reine Dreier-Auslage aus")

func test_block_one_already_offers_a_knebelvertrag():
	# Der Knebelvertrag liegt ab der ersten Auslage aus, nicht erst ab Block 2.
	var saw_harsh := false
	for i in 40:
		run.route_offers.clear()
		run.round_number = 2  # Block 1
		run.roll_route_offers()
		var tier := int(run.route_offers[2][GameRun.CARD_TIER])
		assert_true(tier == int(DealClause.Tier.THREE) or tier == int(DealClause.Tier.TREAT),
			"Platz 3: Knebelvertrag (oder selten ein Werbegeschenk)")
		if tier == int(DealClause.Tier.THREE):
			saw_harsh = true
	assert_true(saw_harsh, "der Knebelvertrag kommt schon in Block 1")

func test_a_werbegeschenk_can_land_on_any_slot():
	# Über viele Würfe trifft das Werbegeschenk jeden der drei Plätze mindestens
	# einmal (Knebelplatz nur selten - darum viele Wiederholungen), und wo eins
	# liegt, hat es nie ein Kleingedrucktes.
	var hit := {0: false, 1: false, 2: false}
	for i in 400:
		run.route_offers.clear()
		run.roll_route_offers()
		for slot in 3:
			if int(run.route_offers[slot][GameRun.CARD_TIER]) == int(DealClause.Tier.TREAT):
				hit[slot] = true
				assert_eq(String(run.route_offers[slot][GameRun.CARD_MALUS]), "",
					"ein Werbegeschenk hat kein Kleingedrucktes")
	assert_true(hit[0] and hit[1] and hit[2], "jeder Platz kann zum Werbegeschenk werden")

## Das Werbegeschenk hat keinen eigenen Klauseltopf mehr: sein Bonus kommt aus dem
## normalen Topf des Platzes, auf dem es liegt - nur der Malus fehlt.
func test_a_werbegeschenk_draws_its_bonus_from_its_own_tier():
	var tiers: Array[DealClause.Tier] = [
		DealClause.Tier.ONE, DealClause.Tier.TWO, DealClause.Tier.THREE]
	var seen := 0
	for i in 200:
		run.route_offers.clear()
		run.roll_route_offers()
		for slot in 3:
			if int(run.route_offers[slot][GameRun.CARD_TIER]) != int(DealClause.Tier.TREAT):
				continue
			seen += 1
			var pool := DealClause.ids_for(tiers[slot], DealClause.Kind.BONUS)
			assert_true(pool.has(String(run.route_offers[slot][GameRun.CARD_BONUS])),
				"Platz %d schenkt aus seinem eigenen Topf" % slot)
	assert_gt(seen, 0, "über 200 Würfe liegt mindestens ein Werbegeschenk")

# --- Werbetrommel: der erste Charm am Vertragswesen -------------------------------

func test_the_ad_drum_triples_the_treat_chance():
	assert_almost_eq(run.treat_chance(), GameRun.TREAT_CHANCE, 0.0001, "ohne Charm die Grundchance")
	run.owned_charms.append(Charm.ad_drum())
	assert_almost_eq(run.treat_chance(), GameRun.TREAT_CHANCE * 3.0, 0.0001)
	assert_lte(run.treat_chance(), 1.0, "die Chance bleibt eine Chance")

func test_the_ad_drum_floods_the_offers_with_treats():
	# Gegenrichtung zum reinen Dreier-Test: bei 90 % Chance MUSS das
	# Werbegeschenk die große Mehrheit der Auslagen tragen (Erwartung 54/60).
	run.owned_charms.append(Charm.ad_drum())
	var with_treat := 0
	for i in 60:
		run.route_offers.clear()
		run.roll_route_offers()
		for slot in 3:
			if int(run.route_offers[slot][GameRun.CARD_TIER]) == int(DealClause.Tier.TREAT):
				with_treat += 1
				break
	assert_gt(with_treat, 30, "die Werbetrommel schlägt durch")

# --- Winkeladvokat: Bonus-Klauseln doppelt ----------------------------------------

## Lauf mit dem Winkeladvokaten im Dock.
func _shyster() -> void:
	run.owned_charms.append(Charm.shyster())

func test_the_shyster_doubles_the_instant_money():
	_shyster()
	_sign([DealClause.ADVANCE_PAYMENT])
	assert_eq(run.money, GameRun.ADVANCE_PAYMENT_MONEY * 2)
	assert_eq(run.deal_bonus_factor(), 2)

func test_the_shyster_doubles_the_instant_energy():
	_shyster()
	_sign([DealClause.SEED_CAPITAL])
	assert_eq(run.energy, GameRun.SEED_CAPITAL_ENERGY * 2)
	assert_eq(GameRun.instant_clause_energy(DealClause.SEED_CAPITAL, 2),
		GameRun.SEED_CAPITAL_ENERGY * 2, "die Zeremonie liest dieselbe Quelle")

func test_the_shyster_doubles_the_linear_bonuses():
	_shyster()
	_sign([DealClause.SAVINGS_BONUS, DealClause.INSURANCE_FRAUD, DealClause.GOLD_VEIN,
		DealClause.DOUBLE_LOADER, DealClause.ODDS_BONUS, DealClause.HIGH_VOLTAGE])
	assert_eq(run.deal_unused_die_bonus(), GameRun.SAVINGS_DIE_BONUS * 2)
	assert_eq(run.farkle_consolation(), GameRun.INSURANCE_FRAUD_MONEY * 2)
	assert_eq(run.gold_vein_income(), GameRun.GOLD_VEIN_MONEY * 2)
	assert_eq(run.energy_per_stage(), 4)
	assert_eq(run.side_bet_payout_factor(), 4)
	assert_eq(run.max_overcharge_stages(),
		run.overcharge_frame() + GameRun.HIGH_VOLTAGE_STAGES * 2)

func test_the_shyster_doubles_the_interest():
	_shyster()
	run.money = 40
	_sign([DealClause.INTEREST])
	assert_eq(run.interest_income(), 8, "4 volle Zehner, doppelt")

func test_the_shyster_multiplies_the_money_factors():
	_shyster()
	_sign([DealClause.HAPPY_HOUR])
	assert_almost_eq(run.money_gain_factor(), 4.0, 0.0001)
	run.active_deals.clear()
	_sign([DealClause.ALL_ON_RED])
	assert_almost_eq(run.money_gain_factor(), 6.0, 0.0001)

func test_the_shyster_applies_the_reductions_twice():
	# Nachlässe werden ein zweites Mal angewandt, nicht in der Zahl verdoppelt -
	# sonst höbe die Eichung das Rundenziel ganz auf.
	_shyster()
	_sign([DealClause.CASH_DISCOUNT, DealClause.CALIBRATION])
	assert_almost_eq(run.shop_price_factor(),
		GameRun.SHOP_DISCOUNT_FACTOR * GameRun.SHOP_DISCOUNT_FACTOR, 0.0001)
	assert_eq(run.effective_goal(),
		roundi(run.round_goal * GameRun.CALIBRATION_FACTOR * GameRun.CALIBRATION_FACTOR))
	assert_gt(run.effective_goal(), 0, "das Ziel bleibt erreichbar")

func test_work_hardening_grows_every_fired_face():
	assert_eq(run.clause_face_growth(), 0, "ohne Unterschrift wächst nichts")
	_sign([DealClause.WORK_HARDENING])
	assert_eq(run.clause_face_growth(), GameRun.WORK_HARDENING_GROWTH)

func test_the_shyster_doubles_the_work_hardening():
	_shyster()
	_sign([DealClause.WORK_HARDENING])
	assert_eq(run.clause_face_growth(), 2 * GameRun.WORK_HARDENING_GROWTH)

func test_the_shyster_never_touches_a_malus():
	_shyster()
	run.add_energy(5)
	var before := run.energy
	_sign([DealClause.DISCHARGE, DealClause.BETTING_TAX, DealClause.HALF_PAYOUT])
	assert_eq(run.energy, before - GameRun.DISCHARGE_ENERGY, "die Entladung bleibt einfach")
	assert_eq(run.side_bet_stake_factor(), 2, "die Wettsteuer bleibt einfach")
	assert_almost_eq(run.round_payout_factor(), 0.5, 0.0001)

func test_the_shyster_does_not_stack():
	_shyster()
	_shyster()
	assert_eq(run.deal_bonus_factor(), 2, "zwei Exemplare wirken wie eines")

func test_active_deal_sides_carry_the_doubled_text():
	_shyster()
	_sign([DealClause.SAVINGS_BONUS, DealClause.BETTING_TAX])
	for side in run.active_deal_sides():
		var expected := DealClause.text_for(String(side["id"]), 2 if side["bonus"] else 1)
		assert_eq(String(side["text"]), expected, "Marke und Buchung lesen dieselbe Quelle")

func test_a_card_never_pairs_two_clauses_of_the_same_tag():
	for i in 60:
		run.route_offers.clear()
		run.round_number = GameRun.GOAL_BLOCK + 1
		run.roll_route_offers()
		for card in run.route_offers:
			var bonus_id := String(card[GameRun.CARD_BONUS])
			var malus_id := String(card[GameRun.CARD_MALUS])
			if bonus_id == "" or malus_id == "":
				continue
			for tag in DealClause.tags_of(bonus_id):
				assert_false(DealClause.tags_of(malus_id).has(tag),
					"%s und %s teilen das Tag %s" % [bonus_id, malus_id, tag])

func test_no_clause_appears_twice_in_one_offer():
	for i in 40:
		run.route_offers.clear()
		run.round_number = GameRun.GOAL_BLOCK + 1
		run.roll_route_offers()
		var seen: Array[String] = []
		for card in run.route_offers:
			for clause_id in _card_ids(card):
				assert_false(seen.has(clause_id), "%s liegt doppelt aus" % clause_id)
				seen.append(clause_id)

func test_offers_never_repeat_a_clause_taken_this_block():
	# Den Stufe-1-Malustopf leerspielen: solange er reicht, darf keine Klausel
	# zweimal kommen.
	var seen: Array[String] = []
	for i in DealClause.ids_for(DealClause.Tier.ONE, DealClause.Kind.MALUS).size() - 1:
		run.route_offers.clear()
		run.roll_route_offers()
		var card: Dictionary = run.route_offers[0]
		if int(card[GameRun.CARD_TIER]) != int(DealClause.Tier.ONE):
			continue  # ein Werbegeschenk hat kein Kleingedrucktes
		var offer := String(card[GameRun.CARD_MALUS])
		assert_false(seen.has(offer), "%s wurde zweimal angeboten" % offer)
		seen.append(offer)
		run.take_route(0)

func test_offers_gate_a_second_benchmark_malus():
	# Ein zweiter Aufschlag könnte ein unerreichbares Ziel bauen (geprüft in der
	# Runde der Unterschrift - länger wirkt keine Klausel).
	_sign([DealClause.BENCHMARK_SURCHARGE])
	for i in 20:
		run.route_offers.clear()
		run.roll_route_offers()
		for card in run.route_offers:
			for clause_id in _card_ids(card):
				assert_false(GameRun.BENCHMARK_MALUS.has(clause_id),
					"%s hebt den Benchmark ein zweites Mal" % clause_id)

func test_the_boss_pool_gates_high_expectations_too():
	_sign([DealClause.USURY_CLAUSE], GameRun.GOAL_BLOCK)
	for i in 20:
		run.route_offers.clear()
		run.roll_route_offers()
		for card in run.route_offers:
			assert_ne(String(card[GameRun.CARD_MALUS]), DealClause.HIGH_EXPECTATIONS)

func test_a_round_benchmark_malus_stops_gating_next_round():
	_sign([DealClause.BENCHMARK_SHOCK])  # nur diese Runde
	run.advance_round()
	var found := false
	for i in 40:
		run.route_offers.clear()
		run.roll_route_offers()
		for card in run.route_offers:
			for clause_id in _card_ids(card):
				found = found or GameRun.BENCHMARK_MALUS.has(clause_id)
	assert_true(found, "nach Ablauf des Malus sind Aufschläge wieder möglich")

func test_stress_round_offers_the_boss_conditions():
	run.round_number = GameRun.GOAL_BLOCK
	run.roll_route_offers()
	assert_eq(run.route_offers.size(), GameRun.ROUTE_OFFER_COUNT)
	for card in run.route_offers:
		assert_eq(int(card[GameRun.CARD_TIER]), int(DealClause.Tier.BOSS))
		assert_eq(String(card[GameRun.CARD_BONUS]), "", "Boss-Karten haben keinen Bonus")
		assert_eq(DealClause.find(card[GameRun.CARD_MALUS]).tier, DealClause.Tier.BOSS)

func test_exhausted_pool_falls_back_to_repeats():
	# Lieber eine bekannte Klausel als ein leerer Platz. Das Werbegeschenk darf
	# den Malus-Slot legitim leeren (~9 %) - darum über mehrere Würfe prüfen:
	# ohne Fallback bliebe das Kleingedruckte in JEDEM Wurf leer.
	var ids: Array[String] = []
	ids.assign(DealClause.ids_for(DealClause.Tier.TWO, DealClause.Kind.MALUS))
	_sign(ids)
	run.round_number = 2
	var repeated := false
	for i in 40:
		run.roll_route_offers()
		if String(run.route_offers[1][GameRun.CARD_MALUS]) != "":
			repeated = true
			break
	assert_true(repeated, "der Risikovertrag hat trotzdem ein Kleingedrucktes")

# --- Klausel-Wirkungen -------------------------------------------------------------

func test_benchmark_malus_inflates_the_whole_bar():
	var base := run.effective_goal()
	_sign([DealClause.BENCHMARK_SURCHARGE])
	assert_eq(run.effective_goal(), roundi(base * 1.5))
	assert_eq(run.stage_size(1), run.effective_goal(), "der Balken zieht mit")
	assert_eq(run.cumulative_threshold(2), run.effective_goal() * 3)

func test_calibration_halves_the_benchmark():
	var base := run.effective_goal()
	_sign([DealClause.CALIBRATION])
	assert_eq(run.effective_goal(), roundi(base * GameRun.CALIBRATION_FACTOR))

func test_benchmark_surcharge_and_calibration_cancel_out():
	_sign([DealClause.BENCHMARK_SURCHARGE_II, DealClause.CALIBRATION])
	assert_eq(run.effective_goal(), run.round_goal, "×2 und ×0,5 heben sich auf")

func test_the_roadmap_only_lifts_the_signing_round():
	_sign([DealClause.BENCHMARK_SURCHARGE], 2)
	assert_eq(run.effective_goal_for_round(2), roundi(GameRun.goal_for_round(2) * 1.5),
		"die Station der laufenden Runde zeigt den Aufschlag")
	assert_eq(run.effective_goal_for_round(3), GameRun.goal_for_round(3),
		"die kommenden Stationen bleiben frei - kein Deal überlebt seine Runde")

func test_a_round_malus_only_inflates_its_own_round():
	_sign([DealClause.BENCHMARK_SHOCK], 2)
	assert_eq(run.effective_goal_for_round(2), roundi(GameRun.goal_for_round(2) * 3.5))
	assert_eq(run.effective_goal_for_round(3), GameRun.goal_for_round(3))

func test_payout_factors_multiply():
	_sign([DealClause.DEDUCTION, DealClause.HALF_PAYOUT])
	assert_almost_eq(run.round_payout_factor(), 0.375, 0.001)

func test_money_gain_factor_only_touches_income():
	_sign([DealClause.HAPPY_HOUR])
	run.money = 0
	run.add_money(10)
	assert_eq(run.money, 20, "Einnahmen verdoppeln sich")
	run.add_money(-10)
	assert_eq(run.money, 10, "Ausgaben bleiben unangetastet")

func test_all_on_red_triples_income():
	_sign([DealClause.ALL_ON_RED])
	run.money = 0
	run.add_money(7)
	assert_eq(run.money, 21)

func test_leftover_clauses_silence_the_die_row():
	_sign([DealClause.EMPTIES])
	assert_false(run.unused_dice_pay())
	run.settle_block_deals()
	_sign([DealClause.BLACKOUT])
	assert_false(run.unused_dice_pay(), "Blackout wirkt genauso, nur eine Runde")

func test_high_voltage_and_stage_cap_resolve_in_order():
	assert_eq(run.max_overcharge_stages(), 5, "Hinterzimmer ohne Vertrag: voller Rahmen")
	_sign([DealClause.HIGH_VOLTAGE])
	assert_eq(run.max_overcharge_stages(), 5 + GameRun.HIGH_VOLTAGE_STAGES, "kein Deckel bei 5")
	_sign([DealClause.STAGE_CAP])
	assert_eq(run.max_overcharge_stages(), GameRun.STAGE_CAP_LIMIT + GameRun.HIGH_VOLTAGE_STAGES,
		"erst der Deckel (2), dann der Bonus (+3)")

func test_superconductor_lifts_the_cap_entirely():
	_sign([DealClause.SUPERCONDUCTOR])
	assert_eq(run.max_overcharge_stages(), GameRun.UNLIMITED_OVERCHARGE_STAGES)

func test_fuse_failure_scales_the_stages_by_four():
	_sign([DealClause.FUSE_FAILURE])
	assert_eq(run.stage_size(1), run.effective_goal())
	assert_eq(run.stage_size(2), run.effective_goal() * 4)
	assert_eq(run.cumulative_threshold(2), run.effective_goal() * 5)

func test_mains_hum_scales_the_stages_by_three():
	assert_eq(run.stage_size(2), run.effective_goal() * 2, "ohne Klausel wächst es ×2")
	_sign([DealClause.MAINS_HUM])
	assert_eq(run.stage_size(1), run.effective_goal(), "die erste Stufe bleibt das Ziel")
	assert_eq(run.stage_size(2), run.effective_goal() * 3)
	assert_eq(run.cumulative_threshold(2), run.effective_goal() * 4)

## Beide drehen an derselben Skalierung - der Sicherungsfall ist der schärfere.
func test_fuse_failure_beats_the_mains_hum():
	_sign([DealClause.MAINS_HUM, DealClause.FUSE_FAILURE])
	assert_eq(run.stage_scale(), GameRun.FUSE_FAILURE_SCALE)

func test_double_loader_mints_two_energys_per_stage():
	_sign([DealClause.DOUBLE_LOADER])
	assert_eq(run.energy_per_stage(), 2)
	var split := run.energy_split(2)
	assert_eq(int(split["stored"]), 4, "zwei Stufen prägen vier ⚡")

## Die Zeremonie fliegt EINEN Kometen je STUFE und bucht dessen Prägung bei der
## Ankunft. energy_split rechnet weiterhin in LADUNGEN - beide Zahlen müssen
## zusammenpassen, sonst plant die Vorschau anders, als gebucht wird.
func test_the_stage_arithmetic_behind_one_comet_per_stage():
	_sign([DealClause.DOUBLE_LOADER])
	run.hub_level = 1  # Deckel 5
	assert_eq(run.energy_cap(), 5)
	var stages := 4
	var split := run.energy_split(stages)
	assert_eq(int(split["stored"]), 5, "die Börse nimmt fünf")
	assert_eq(int(split["overflow"]), 3, "die übrigen drei zahlen bar")
	# Je Stufe: erst was noch hineinpaßt, der Rest bar - genau die Aufteilung, die
	# _play_bank_discharge je Einschlag bucht. Eine Stufe kann GETEILT ankommen.
	var per_stage := run.energy_per_stage()
	var minted := 0
	var energys: Array[int] = []
	var cash: Array[int] = []
	for i in stages:
		var take := clampi(int(split["stored"]) - minted, 0, per_stage)
		energys.append(take)
		cash.append(per_stage - take)
		minted += per_stage
	assert_eq(energys, [2, 2, 1, 0] as Array[int], "die dritte Stufe kommt geteilt an")
	assert_eq(cash, [0, 0, 1, 2] as Array[int])
	var booked := 0
	for c in energys:
		booked += c
	assert_eq(booked, int(split["stored"]), "gebucht wird exakt die Vorschau")
	assert_eq(energys.size(), stages, "ein Komet je Stufe, nie zwei")

func test_shop_price_clauses_multiply():
	_sign([DealClause.INFLATION])
	assert_eq(run.shop_price(100), 125)
	_sign([DealClause.CASH_DISCOUNT])
	assert_eq(run.shop_price(100), 100, "Inflation und Skonto heben sich fast auf")
	run.settle_block_deals()
	_sign([DealClause.CASH_DISCOUNT])
	assert_eq(run.shop_price(100), 80)

func test_the_first_charm_of_the_block_is_free():
	_sign([DealClause.FREE_CHARM])
	assert_true(run.charm_is_free())
	run.consume_free_charm()
	assert_false(run.charm_is_free(), "der Gutschein verbraucht sich")

func test_free_spins_are_one_per_machine():
	run.hub_level = 10  # alle drei Automaten frei
	_sign([DealClause.FREE_SPINS])
	assert_eq(run.slot_spin_energy(0), 0)
	run.energy = 0
	assert_true(run.can_spin_slot(0), "gratis geht auch ohne Energie")
	run.spin_slot(0)
	assert_gt(run.slot_spin_energy(0), 0, "der Gratisdreh ist verbraucht")
	assert_eq(run.slot_spin_energy(1), 0, "der nächste Automat hat seinen noch")

func test_power_cut_switches_the_slots_off():
	run.hub_level = 10
	run.energy = 9
	assert_true(run.can_spin_slot(0))
	_sign([DealClause.POWER_CUT])
	assert_false(run.slots_enabled())
	assert_false(run.can_spin_slot(0))

func test_fees_and_consolations_are_plain_queries():
	_sign([DealClause.SERVICE_FEE, DealClause.RIP_OFF])
	assert_eq(run.hand_fee(), GameRun.SERVICE_FEE_MONEY)
	assert_eq(run.scored_die_fee(), GameRun.RIP_OFF_PER_DIE)
	run.settle_block_deals()
	_sign([DealClause.INSURANCE_FRAUD])
	assert_eq(run.farkle_consolation(), GameRun.INSURANCE_FRAUD_MONEY)

func test_interest_pays_per_full_ten():
	_sign([DealClause.INTEREST])
	run.money = 37
	assert_eq(run.interest_income(), 3)

func test_gold_vein_pays_per_stage():
	assert_eq(run.gold_vein_income(), 0)
	_sign([DealClause.GOLD_VEIN])
	assert_eq(run.gold_vein_income(), GameRun.GOLD_VEIN_MONEY)

func test_odds_bonus_and_betting_tax_are_separate_clauses():
	var bet := SideBet._from_template(_template("jackpot"))
	_sign([DealClause.ODDS_BONUS])
	assert_eq(run.side_bet_payout_factor(), 2)
	assert_eq(run.side_bet_stake(bet), bet.stake, "der Bonus verteuert nichts")
	_sign([DealClause.BETTING_TAX])
	assert_eq(run.side_bet_stake(bet), bet.stake * 2)
	run.money = bet.stake  # der einfache Einsatz reicht nicht mehr
	assert_false(run.can_place_side_bet(bet))
	run.money = bet.stake * 2
	run.place_side_bet(bet)
	assert_eq(run.money, 0, "der doppelte Einsatz wird abgebucht")

func test_odds_bonus_doubles_pack_rewards():
	_sign([DealClause.ODDS_BONUS])
	var bet := SideBet._from_template(_template("full_house"))  # Paket-Gewinn
	run.money = 50
	run.place_side_bet(bet)
	var before := run.owned_packs.size()
	var result := {"cleared": true, "best_combo_rank": SideBet.combo_rank(DiceScoring.FULL_HOUSE),
		"best_hand_score": 0, "dice_taken": 0, "farkled": false}
	run.resolve_side_bets(result)
	assert_eq(run.owned_packs.size(), before + bet.reward_packs * 2)

func test_the_spotlight_clause_lights_a_combo_without_the_charm():
	_sign([DealClause.SPOTLIGHT])
	run.apply_round_start_charms()
	assert_true(DiceScoring.HAND_PRIORITY.has(run.spotlight_combo), "Rampenlicht ohne Charm")

## --- Goldener Handschlag ------------------------------------------------------

func test_golden_handshake_needs_a_hand_that_clears_the_benchmark():
	_sign([DealClause.GOLDEN_HANDSHAKE])
	run.round_goal = 300
	var die := DieDefinition.standard()
	assert_false(run.apply_golden_handshake(die, 299), "knapp darunter zählt nicht")
	assert_eq(die.materials.count(DieMaterial.GOLD), 0)

func test_golden_handshake_gilds_the_whole_die_once_per_round():
	_sign([DealClause.GOLDEN_HANDSHAKE])
	run.round_goal = 300
	var die := DieDefinition.standard()
	assert_true(run.apply_golden_handshake(die, 300))
	assert_eq(die.materials.count(DieMaterial.GOLD), die.materials.size(), "alle Seiten Gold")
	assert_false(run.apply_golden_handshake(DieDefinition.standard(), 900),
		"je Runde nur ein Handschlag")
	run.apply_round_start_charms()
	assert_true(run.apply_golden_handshake(DieDefinition.standard(), 900), "neue Runde, neuer Griff")

func test_golden_handshake_spares_a_burned_in_material_face():
	_sign([DealClause.GOLDEN_HANDSHAKE])
	run.round_goal = 100
	var die := DieDefinition.standard()
	die.set_face_material(2, DieMaterial.RUBY)
	die.runes[2] = Rune.BURN_IN
	assert_true(run.apply_golden_handshake(die, 100))
	assert_eq(die.materials[2], DieMaterial.RUBY, "Einbrand sperrt das Übermalen")
	assert_eq(die.materials[0], DieMaterial.GOLD, "der Rest wird trotzdem Gold")

# --- Drossel & Stresstest-Konditionen ----------------------------------------------

func test_the_stress_round_no_longer_throttles_on_its_own():
	run.combo_levels[DiceScoring.SIX_KIND] = 5
	run.round_number = GameRun.GOAL_BLOCK
	run.apply_round_start_charms()
	assert_eq(run.throttled_combos, [], "gedrosselt wird nur noch per Klausel")

func test_heat_warning_throttles_the_hottest_chip():
	run.combo_levels[DiceScoring.SIX_KIND] = 5
	run.combo_levels[DiceScoring.FULL_HOUSE] = 4
	_sign([DealClause.HEAT_WARNING])
	run.apply_round_start_charms()
	assert_eq(run.throttled_combos, [DiceScoring.SIX_KIND], "nur der heißeste")

func test_all_rounder_locks_each_played_combination():
	_sign([DealClause.ALL_ROUNDER], GameRun.GOAL_BLOCK)
	assert_true(run.note_hand_taken(DiceScoring.TWO_KIND))
	assert_eq(run.throttled_combos, [DiceScoring.TWO_KIND])
	assert_false(run.note_hand_taken(DiceScoring.TWO_KIND), "zweimal sperren ändert nichts")
	run.note_hand_taken(DiceScoring.THREE_KIND)
	assert_eq(run.throttled_combos.size(), 2)

func test_standard_protocol_locks_every_other_combination():
	_sign([DealClause.STANDARD_PROTOCOL], GameRun.GOAL_BLOCK)
	run.note_hand_taken(DiceScoring.TWO_KIND)
	assert_eq(run.throttled_combos.size(), DiceScoring.HAND_PRIORITY.size() - 1)
	assert_false(run.throttled_combos.has(DiceScoring.TWO_KIND))
	assert_true(run.throttled_combos.has(DiceScoring.ONE_KIND),
		"auch die Rückfall-Kategorie fällt weg")

func test_all_in_caps_the_round_at_one_hand():
	assert_gt(run.max_hands_this_round(), 1)
	_sign([DealClause.ALL_IN], GameRun.GOAL_BLOCK)
	assert_eq(run.max_hands_this_round(), 1)

func test_parity_conditions_set_the_filter():
	assert_eq(run.parity_filter(), DiceScoring.PARITY_ANY)
	_sign([DealClause.TILTED_FLOOR], GameRun.GOAL_BLOCK)
	assert_eq(run.parity_filter(), DiceScoring.PARITY_ODD)
	run.settle_block_deals()
	_sign([DealClause.BALANCED_SCALES], GameRun.GOAL_BLOCK)
	assert_eq(run.parity_filter(), DiceScoring.PARITY_EVEN)

func test_heat_buildup_never_falls_below_the_baseline():
	_sign([DealClause.HEAT_BUILDUP], GameRun.GOAL_BLOCK)
	run.combo_levels[DiceScoring.TWO_KIND] = 1
	watch_signals(run)
	assert_true(run.apply_heat_buildup(DiceScoring.TWO_KIND))
	assert_eq(run.combo_level(DiceScoring.TWO_KIND), 0)
	assert_signal_emitted(run, "combo_upgraded")
	assert_false(run.apply_heat_buildup(DiceScoring.TWO_KIND), "die Grundform bleibt")

func test_active_deal_sides_feed_the_hub_tokens():
	_sign([DealClause.SAVINGS_BONUS, DealClause.EMPTIES, DealClause.HAPPY_HOUR])
	var sides := run.active_deal_sides()
	assert_eq(sides.size(), 3)
	assert_true(bool(sides[0]["bonus"]), "die Sparprämie ist ein Bonus")
	assert_false(bool(sides[1]["bonus"]), "das Leergut ist Kleingedrucktes")
	run.advance_round()
	assert_eq(run.active_deal_sides().size(), 0, "mit der Runde sind alle Seiten fort")

func test_roadmap_markers_flag_the_stress_station():
	var markers := run.goal_roadmap_markers(GameRun.GOAL_BLOCK)
	assert_eq(markers.size(), GameRun.GOAL_BLOCK)
	assert_eq(markers[GameRun.GOAL_BLOCK - 1], GameRun.STRESS_MARKER)
	assert_eq(markers[0], "", "normale Stationen bleiben unmarkiert")

# --- Nebenwetten: Steuer-Einsätze und neue Ausschüttungen -------------------------

func _place(id: String) -> SideBet:
	var bet := SideBet._from_template(_template(id))
	run.place_side_bet(bet)
	return bet

func test_tax_bets_are_placeable_without_money():
	run.money = 0
	var bet := SideBet._from_template(_template("table_fee"))
	assert_true(run.can_place_side_bet(bet), "die Gebühr kommt erst beim Nehmen")
	run.place_side_bet(bet)
	assert_eq(run.money, 0, "beim Platzieren wird nichts abgebucht")

func test_per_hand_tax_is_energyd_at_every_take():
	run.money = 20
	var bet := _place("table_fee")  # $3 je Hand
	assert_eq(run.tax_side_bets(4), bet.stake)
	assert_eq(run.money, 20 - bet.stake)
	run.tax_side_bets(2)
	assert_eq(run.money, 20 - bet.stake * 2)

func test_per_die_tax_scales_with_the_hand():
	run.money = 20
	var bet := _place("dice_toll")  # $1 je Würfel
	assert_eq(run.tax_side_bets(5), bet.stake * 5)
	assert_eq(run.money, 20 - bet.stake * 5)

func test_insolvency_voids_the_tax_bet():
	run.money = 2
	var bet := _place("table_fee")  # $3 je Hand
	run.tax_side_bets(1)
	assert_true(bet.voided, "zu wenig Geld reißt die Wette ab")
	assert_eq(run.money, 2, "eine verfallene Wette bucht nichts ab")
	run.money = 50
	run.tax_side_bets(1)
	assert_eq(run.money, 50, "sie wird auch später nicht mehr besteuert")
	var won := run.resolve_side_bets({"cleared": true})
	assert_eq(won.size(), 0, "verfallen = verloren")

func test_energy_stake_is_paid_from_the_capacitor():
	var bet := SideBet._from_template(_template("feedback_loop"))
	run.energy = bet.stake_energy - 1
	assert_false(run.can_place_side_bet(bet))
	run.energy = bet.stake_energy + 1
	assert_true(run.can_place_side_bet(bet))
	run.place_side_bet(bet)
	assert_eq(run.energy, 1)

func test_energy_payout_overflows_into_money():
	var bet := SideBet._from_template(_template("feedback_loop"))  # 8 ⚡ Gewinn
	run.energy = bet.stake_energy
	run.place_side_bet(bet)
	run.energy = run.energy_cap() - 1  # nur noch EINE passt hinein
	run.money = 0
	run.resolve_side_bets({"cleared": true, "stages_cleared": bet.target})
	assert_eq(run.energy, run.energy_cap(), "die Börse läuft voll")
	assert_eq(run.money, (bet.payout_energy - 1) * GameRun.ENERGY_OVERFLOW_MONEY,
		"der Rest fällt bar an")

func test_pack_payout_lands_sealed_in_the_stash():
	var bet := SideBet._from_template(_template("shipment"))
	run.money = 100
	run.place_side_bet(bet)
	run.resolve_side_bets({"cleared": true, "dice_taken": bet.target})
	assert_eq(run.owned_packs.size(), 1, "ein versiegeltes Paket im Lager")
	assert_not_null(bet.awarded_pack, "die Zeremonie erfährt die Sorte")

func test_grant_pack_costs_nothing():
	run.money = 10
	run.grant_pack(Pack.number_pack())
	assert_eq(run.owned_packs.size(), 1)
	assert_eq(run.money, 10)

func test_grant_combo_level_lifts_the_chip():
	var before := run.combo_level(DiceScoring.FULL_HOUSE)
	run.grant_combo_level(DiceScoring.FULL_HOUSE)
	assert_eq(run.combo_level(DiceScoring.FULL_HOUSE), before + 1)

func test_combo_level_payout_upgrades_the_named_chip():
	var bet := SideBet._from_template(_template("patent"))
	run.money = 100
	run.place_side_bet(bet)
	var before := run.combo_level(DiceScoring.FULL_HOUSE)
	run.resolve_side_bets({"cleared": true,
		"best_combo_rank": SideBet.combo_rank(DiceScoring.FULL_HOUSE)})
	assert_eq(run.combo_level(DiceScoring.FULL_HOUSE), before + 1)

func test_special_payout_grants_the_sonderposten():
	var bet := SideBet._from_template(_template("circuit_contract"))
	run.money = 100
	run.place_side_bet(bet)
	run.resolve_side_bets({"cleared": true, "stages_cleared": bet.target})
	assert_eq(run.owned_packs.size(), 1, "auch der Sonderposten kommt versiegelt")
	assert_eq(run.owned_packs[0].fixed_engraving.id, Engraving.POINTER)

func test_the_odds_bonus_spares_unique_goods():
	_sign([DealClause.ODDS_BONUS])
	var bet := SideBet._from_template(_template("circuit_contract"))
	run.money = 100
	run.place_side_bet(bet)
	run.resolve_side_bets({"cleared": true, "stages_cleared": bet.target})
	assert_eq(run.owned_packs.size(), 1, "ein Sonderposten bleibt einer")

# --- Die SERIENLÄNGE: fester Sockel, Klauseln, Wett-Schub -------------------------

func test_the_series_length_is_six_on_every_licence_level():
	# Die Hub-Leiter ist gefallen (2026-09-04): SECHS Schächte ab Runde 1.
	for level: int in range(1, 11):
		run.hub_level = level
		assert_eq(run.series_slots(), 6, "Stufe %d" % level)

## Der DECKEL ist die BLOCK-GRÖSSE (Welle U, 2026-09-05): mehr als sechs gibt es
## nie - auch nicht mit Taktgeber, Wett-Schub und Kettentreiber zusammen.
func test_more_than_six_slots_never_exist():
	run.hub_level = 10
	run.series_slot_bonus = 4
	run.grant_press_boost()
	run.owned_charms.append(Charm.shyster())
	_sign([DealClause.CHAIN_DRIVER])
	assert_eq(GameRun.SERIES_SLOT_CAP, 6, "sechs Karten sind der Block")
	assert_eq(run.series_slots(), 6, "Taktgeber, Schub und Klausel heben ihn nicht")

func test_the_chain_driver_no_longer_lengthens_the_series():
	run.hub_level = 1
	_sign([DealClause.CHAIN_DRIVER])
	assert_eq(run.series_slots(), 6, "der Deckel klemmt ihn weg")

func test_the_shyster_doubles_the_quantitative_series_bonus():
	run.hub_level = 1
	run.owned_charms.append(Charm.shyster())
	_sign([DealClause.CHAIN_DRIVER])
	assert_eq(run.deal_bonus_factor(), 2, "der Faktor lebt - nur der Deckel klemmt")
	assert_eq(run.series_slots(), 6)

func test_the_short_circuit_overrides_the_length_absolutely():
	run.hub_level = 10
	run.grant_press_boost()
	_sign([DealClause.CHAIN_DRIVER, DealClause.SHORT_CIRCUIT])
	assert_eq(run.series_slots(), 1, "Kurzschluss schlägt Sockel, Klausel und Schub")

func test_the_length_is_capped():
	run.hub_level = 10
	run.series_slot_bonus = 99
	assert_eq(run.series_slots(), GameRun.SERIES_SLOT_CAP)

func test_the_press_boost_is_spent_by_one_series():
	run.hub_level = 1
	run.grant_press_boost()
	assert_eq(run.series_slots(), 6, "der Deckel klemmt den Schub weg")
	var pack := run.grant_pack(Pack.number_pack())
	run.apply_series([pack.pack_uid] as Array[int], run.owned_pool[0], null, _seeded(7))
	assert_false(run.press_boost_pending, "ein Schub, eine Serie")
	assert_eq(run.series_slots(), 6)

func test_a_fresh_run_carries_no_press_boost():
	run.grant_press_boost()
	assert_false(GameRun.new_run().press_boost_pending)

## Die Presse steht im LADEN der Runde - eine ROUND-Klausel muss dort noch leben,
## sonst wären die Serien-Klauseln tote Buchstaben.
func test_a_round_clause_still_reaches_the_shop_of_its_round():
	run.hub_level = 1
	_sign([DealClause.CHAIN_DRIVER], 3)
	assert_eq(run.round_number, 3)
	# Der Laden öffnet nach der Auszahlung, die Runde rückt erst beim Schließen vor.
	assert_true(run.active_deal_sides().any(func(entry: Dictionary) -> bool:
		return String(entry["id"]) == DealClause.CHAIN_DRIVER),
		"im Laden derselben Runde wirkt sie noch")
	run.advance_round()
	assert_false(run.active_deal_sides().any(func(entry: Dictionary) -> bool:
		return String(entry["id"]) == DealClause.CHAIN_DRIVER),
		"in der nächsten Runde ist sie tot")

func test_the_chain_reaction_bet_grants_the_boost_once():
	var bet := SideBet._from_template(_template("chain_reaction"))
	assert_eq(bet.payout_kind, SideBet.Payout.PRESS_BOOST)
	assert_eq(bet.unlock_level, SideBet.UNLOCK_BASE)
	run.money = 100
	run.place_side_bet(bet)
	run.resolve_side_bets({"cleared": true,
		"best_combo_rank": SideBet.combo_rank(DiceScoring.LARGE_STRAIGHT)})
	assert_true(run.press_boost_pending, "der Gewinn merkt die nächste Serie vor")

func test_the_press_boost_is_no_doubled_good():
	# Einzelstück wie der Sonderposten: der Quotenbonus verdoppelt es nicht.
	_sign([DealClause.ODDS_BONUS])
	var bet := SideBet._from_template(_template("chain_reaction"))
	run.money = 100
	run.place_side_bet(bet)
	run.resolve_side_bets({"cleared": true,
		"best_combo_rank": SideBet.combo_rank(DiceScoring.LARGE_STRAIGHT)})
	run.hub_level = 1
	assert_true(run.press_boost_pending, "EIN Schub, nicht zwei")
	assert_eq(run.series_slots(), 6, "und der Deckel klemmt ihn ohnehin weg")

func test_the_chain_reaction_button_states_its_prize():
	var bet := SideBet._from_template(_template("chain_reaction"))
	assert_eq(bet.reward_label(), "Nächste Serie: +1 Slot")
	assert_eq(bet.reward_label(2), bet.reward_label(), "der Quotenbonus rührt es nicht an")

# --- Helfer -----------------------------------------------------------------------

func _seeded(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng

func _p(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _count_style(style_id: String) -> int:
	var count := 0
	for def in run.owned_pool:
		if def.style_id == style_id:
			count += 1
	return count
