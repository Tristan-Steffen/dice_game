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
	assert_eq(run.owned_engravings.size(), 0)

func test_new_run_fills_pool_with_standard_dice():
	assert_eq(run.owned_pool.size(), GameRun.POOL_SIZE)
	for def in run.owned_pool:
		assert_eq(def.style_id, "normal")

func test_pool_entries_are_independent_instances():
	# Eine Ätzung auf Würfel 0 darf Würfel 1 nie mitverändern (siehe
	# DieDefinition-Klassenkommentar zum Resource-Teilen).
	run.owned_pool[0].faces[0] = 6
	assert_eq(run.owned_pool[1].faces[0], 1, "Nachbar-Würfel bleibt unberührt")

func test_edge_die_count_counts_owned_edge_dice():
	assert_eq(run.edge_die_count(), 0, "frischer Pool ohne Kanten-Material")
	run.owned_pool[0].edge_material = DieMaterial.GOLD
	run.owned_pool[3].edge_material = DieMaterial.MERCURY
	assert_eq(run.edge_die_count(), 2, "zwei Würfel mit Kanten-Material im ganzen Besitz")

# --- Geld ----------------------------------------------------------------------

func test_add_money_accumulates_and_emits():
	watch_signals(run)
	run.add_money(5)
	run.add_money(3)
	assert_eq(run.money, 8)
	assert_signal_emit_count(run, "money_changed", 2)

# --- Würfelkauf -----------------------------------------------------------------

func test_purchase_die_deducts_and_keeps_pool_size():
	run.money = 20
	run.purchase_die(DieDefinition.fixed(6, "Immer 6"), 15)
	assert_eq(run.money, 5)
	assert_eq(run.owned_pool.size(), GameRun.POOL_SIZE)
	assert_eq(_count_style("fixed_6"), 1)

func test_purchase_die_stores_independent_copy():
	var template := DieDefinition.fixed(6, "Immer 6")
	run.purchase_die(template, 0)
	for def in run.owned_pool:
		if def.style_id == "fixed_6":
			def.faces[0] = 1  # späteres "Upgrade" des gekauften Würfels
	assert_eq(template.faces[0], 6, "Shop-Vorlage bleibt unverändert")

func test_purchase_die_prefers_replacing_normal_dice():
	# Solange normale Würfel übrig sind, verdrängt ein Kauf nie einen früher
	# gekauften Spezialwürfel.
	for i in GameRun.POOL_SIZE - 1:
		run.purchase_die(DieDefinition.fixed(6, "Immer 6"), 0)
	assert_eq(_count_style("fixed_6"), GameRun.POOL_SIZE - 1)
	assert_eq(_count_style("normal"), 1)

func test_purchase_dice_bundle_deducts_once_and_adds_all():
	run.money = 30
	var bundle: Array[DieDefinition] = [
		DieDefinition.fixed(2, "A"), DieDefinition.fixed(2, "B"), DieDefinition.fixed(2, "C"),
	]
	for def in bundle:
		def.style_id = "low"
	run.purchase_dice(bundle, 15)
	assert_eq(run.money, 15, "nur ein Preis fürs ganze Bündel")
	assert_eq(run.owned_pool.size(), GameRun.POOL_SIZE, "Pool bleibt konstant groß")
	assert_eq(_count_style("low"), 3, "alle drei Würfel liegen im Pool")

## --- Ein Weg für alle Würfel-Anzeigen: pool_changed --------------------------
## Die Instanz wird NIE getauscht (become) - wer sie hält (Rundendeck, Trays,
## Raster, Station), zeigt den neuen Würfel sofort; das Signal löst nur das
## Neuzeichnen aus.

func test_purchase_die_overwrites_the_instance_in_place():
	var kept := run.owned_pool.duplicate()
	run.purchase_die(DieDefinition.fixed(6, "Immer 6"), 0)
	for i in GameRun.POOL_SIZE:
		assert_same(run.owned_pool[i], kept[i], "kein Instanz-Tausch im Pool")
	var styles: Array[String] = []
	for def in kept:
		styles.append(def.style_id)
	assert_true(styles.has("fixed_6"), "der gehaltene Würfel IST der gekaufte")

func test_purchase_die_emits_pool_changed():
	watch_signals(run)
	run.purchase_die(DieDefinition.fixed(6, "Immer 6"), 0)
	assert_signal_emit_count(run, "pool_changed", 1)

func test_place_pack_die_emits_pool_changed():
	watch_signals(run)
	run.place_pack_die(DieDefinition.fixed(3, "Drei"), 4)
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
	# Der Schwarzmarkt geht denselben Weg: voller Dock, keine Ladung abgebucht.
	run.charge = GameRun.SECRET_CHARM_PRICE
	run.secret_stock.append({
		GameRun.OFFER_KIND: GameRun.KIND_CHARM,
		GameRun.OFFER_ITEM: Charm.horseshoe(),
		GameRun.OFFER_PRICE: GameRun.SECRET_CHARM_PRICE,
		GameRun.OFFER_SOLD: false,
	})
	_fill_charm_dock()
	assert_false(run.buy_secret_offer(0))
	assert_eq(run.charge, GameRun.SECRET_CHARM_PRICE, "kein Abzug")
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

# --- Gravuren --------------------------------------------------------------------

func test_grant_and_consume_engraving():
	watch_signals(run)
	run.grant_engraving(Engraving.chisel())
	assert_eq(run.owned_engravings.size(), 1)
	assert_true(run.consume_engraving(Engraving.CHISEL))
	assert_eq(run.owned_engravings.size(), 0)
	assert_signal_emit_count(run, "engravings_changed", 2)

func test_consume_missing_engraving_returns_false_without_signal():
	watch_signals(run)
	assert_false(run.consume_engraving(Engraving.CHISEL))
	assert_signal_emit_count(run, "engravings_changed", 0)

func test_consume_removes_only_one_of_a_kind():
	run.grant_engraving(Engraving.chisel())
	run.grant_engraving(Engraving.chisel())
	run.consume_engraving(Engraving.CHISEL)
	assert_eq(run.owned_engravings.size(), 1)

func test_unlimited_engravings_consume_is_a_noop_and_reports_success():
	# Testmodus (siehe scene_root): Gravuren sind unerschöpflich - consume verbraucht
	# nichts, meldet aber Erfolg, auch wenn gar kein Exemplar im Inventar liegt.
	run.unlimited_engravings = true
	watch_signals(run)
	assert_true(run.consume_engraving(Engraving.CHISEL), "meldet Erfolg trotz leerem Inventar")
	assert_eq(run.owned_engravings.size(), 0, "nichts verbraucht")
	assert_signal_emit_count(run, "engravings_changed", 0, "kein Bestandswechsel")

func test_unlimited_engravings_toggle_reports_a_stock_change():
	# Bord und Schubladen bauen an engravings_changed neu - ohne das Signal
	# bliebe das Gravur-Bord beim Umschalten stehen (kein Rundenneustart).
	watch_signals(run)
	run.unlimited_engravings = true
	assert_signal_emit_count(run, "engravings_changed", 1)
	run.unlimited_engravings = true
	assert_signal_emit_count(run, "engravings_changed", 1, "gleicher Wert meldet nichts")
	run.unlimited_engravings = false
	assert_signal_emit_count(run, "engravings_changed", 2)

func test_unlimited_engravings_keeps_owned_stock_intact():
	run.unlimited_engravings = true
	run.grant_engraving(Engraving.chisel())
	run.consume_engraving(Engraving.CHISEL)
	assert_eq(run.owned_engravings.size(), 1, "vorhandene Gravuren bleiben liegen")

# --- Einzel-Gravur-Kauf ----------------------------------------------------------

func test_purchase_engraving_deducts_and_stores():
	run.money = 20
	run.purchase_engraving(Engraving.chisel(), 5)
	assert_eq(run.money, 15, "Preis abgezogen")
	assert_eq(run.owned_engravings.size(), 1, "Gravur im Inventar")

func test_granting_other_engravings_still_stores_them():
	run.grant_engraving(Engraving.chisel())
	assert_eq(run.owned_engravings.size(), 1)
	assert_false(run.combo_levels.has(Engraving.CHISEL))

func test_new_run_starts_without_levels():
	assert_true(GameRun.new_run().combo_levels.is_empty())

# --- Pakete (Kauf, Lager, Öffnen) ------------------------------------------------

func test_purchase_pack_deducts_and_stores_sealed():
	run.money = 20
	watch_signals(run)
	run.purchase_pack(Pack.number_pack(), Pack.NUMBER_PRICE)
	assert_eq(run.money, 20 - Pack.NUMBER_PRICE, "Preis abgezogen")
	assert_eq(run.owned_packs.size(), 1, "Paket liegt im Lager")
	assert_eq(run.owned_engravings.size(), 0, "Kauf würfelt noch keinen Inhalt aus")
	assert_signal_emitted(run, "packs_changed")

func test_open_engraving_pack_rolls_contents_and_clears_the_slot():
	run.purchase_pack(Pack.number_pack(), 0)
	var result := run.open_pack(0)
	var engravings: Array = result["engravings"]
	assert_eq(engravings.size(), Pack.NUMBER_COUNT)
	assert_eq(run.owned_engravings.size(), 0, "Öffnen bucht noch nicht - das tut die Zeremonie")
	assert_eq(run.owned_packs.size(), 0, "Paket ist verbraucht")

func test_stash_engravings_books_the_rolled_contents():
	run.purchase_pack(Pack.number_pack(), 0)
	var engravings: Array[Engraving] = []
	engravings.assign(run.open_pack(0)["engravings"])
	watch_signals(run)
	run.stash_engravings(engravings)
	assert_eq(run.owned_engravings.size(), Pack.NUMBER_COUNT, "Inhalt in den Vorräten")
	assert_signal_emitted(run, "engravings_changed")

func test_stash_engravings_ignores_empty_content():
	watch_signals(run)
	run.stash_engravings([] as Array[Engraving])
	assert_eq(run.owned_engravings.size(), 0)
	assert_signal_not_emitted(run, "engravings_changed")

func test_open_dice_pack_hands_the_dice_to_the_ceremony():
	run.purchase_pack(Pack.dice_pack(DiceOffer.TEMPLATES[2]), 0)
	var result := run.open_pack(0)
	var dice: Array = result["dice"]
	assert_eq(dice.size(), int(DiceOffer.TEMPLATES[2]["count"]))
	assert_eq(run.owned_engravings.size(), 0, "Würfel landen nicht in den Vorräten")
	assert_eq(_count_style("normal"), GameRun.POOL_SIZE, "Pool erst nach dem Einsetzen")

func test_open_pack_ignores_invalid_index():
	run.purchase_pack(Pack.number_pack(), 0)
	assert_eq(run.open_pack(-1)["engravings"].size(), 0)
	assert_eq(run.open_pack(5)["engravings"].size(), 0)
	assert_eq(run.owned_packs.size(), 1, "Lager unangetastet")

func test_place_pack_die_replaces_the_chosen_slot_only():
	var die := DieDefinition.fixed(6, "Immer 6")
	run.place_pack_die(die, 7)
	assert_eq(run.owned_pool[7].style_id, "fixed_6", "gewählter Platz getauscht")
	assert_eq(_count_style("fixed_6"), 1, "nur dieser eine Platz")
	assert_eq(run.owned_pool.size(), GameRun.POOL_SIZE)

func test_place_pack_die_stores_an_independent_copy():
	var die := DieDefinition.fixed(6, "Immer 6")
	run.place_pack_die(die, 3)
	run.owned_pool[3].faces[0] = 1
	assert_eq(die.faces[0], 6, "Paket-Vorlage bleibt unverändert")

func test_place_pack_die_ignores_slots_outside_the_pool():
	run.place_pack_die(DieDefinition.fixed(6, "Immer 6"), GameRun.POOL_SIZE)
	assert_eq(_count_style("fixed_6"), 0)
	assert_eq(run.owned_pool.size(), GameRun.POOL_SIZE, "Pool unverändert")

# --- Automaten-Gewinne (auswürfeln und buchen sind getrennt) ---------------------

## Wand mit einer 3er-Reihe des Symbols in der obersten Zeile; der Rest bildet in
## keiner Richtung eine Reihe.
func _winning_wall(symbol: int) -> void:
	var filler := [SlotPrize.Kind.CHARM, SlotPrize.Kind.FUMBLE]
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
	# füllten sich die Schubladen, bevor überhaupt etwas geflogen ist.
	_winning_wall(SlotPrize.Kind.MATERIAL)
	var result := run.redeem_slots()
	assert_gt(result["prizes"].size(), 0, "die Reihe löst sich in Preise auf")
	assert_eq(run.owned_engravings.size(), 0, "aber noch nichts in den Vorräten")
	assert_eq(run.slot_bank.hit_count(), 0, "die Sitzung ist zurückgesetzt")

func test_booking_a_prize_grants_its_goods():
	_winning_wall(SlotPrize.Kind.MATERIAL)
	var prizes: Array = run.redeem_slots()["prizes"]
	var expected := 0
	for prize: SlotPrize in prizes:
		expected += prize.engravings.size()
		run.book_slot_prize(prize)
	assert_eq(run.owned_engravings.size(), expected, "jetzt liegt die Ware im Vorrat")
	for engraving in run.owned_engravings:
		assert_eq(engraving.category, Engraving.CATEGORY_MATERIAL, "in der eigenen Sorte")

func test_booking_a_won_die_takes_a_pool_slot():
	var prize := SlotPrize.new()
	prize.kind = SlotPrize.Kind.DIE
	prize.die = DieDefinition.fixed(6, "Immer 6")
	run.book_slot_prize(prize)
	assert_eq(_count_style("fixed_6"), 1, "der gewonnene Würfel ersetzt einen Pool-Platz")
	assert_eq(run.owned_pool.size(), GameRun.POOL_SIZE, "der Pool bleibt gleich groß")

func test_booking_a_won_charm_puts_it_on_the_shelf():
	var prize := SlotPrize.new()
	prize.kind = SlotPrize.Kind.CHARM
	prize.charm = Charm.rabbits_foot()
	watch_signals(run)
	run.book_slot_prize(prize)
	assert_eq(run.owned_charms.size(), 1)
	assert_signal_emitted(run, "charms_changed")

func test_pack_content_floor_rises_with_the_hub():
	assert_eq(run.pack_engraving_floor(), Engraving.Rarity.COMMON, "Stufe 1: alles")
	run.hub_level = GameRun.HUB_RARITY_UNCOMMON_LEVEL
	assert_eq(run.pack_engraving_floor(), Engraving.Rarity.UNCOMMON)
	run.hub_level = GameRun.HUB_RARITY_RARE_LEVEL
	assert_eq(run.pack_engraving_floor(), Engraving.Rarity.RARE)

# --- Rundenfortschritt -----------------------------------------------------------

func test_advance_round_increments_number_and_goal():
	run.advance_round()
	run.advance_round()
	assert_eq(run.round_number, 3)
	assert_eq(run.round_goal, GameRun.BASE_GOAL + 2 * GameRun.GOAL_INCREMENT)

func test_goal_curve_doubles_its_step_every_block():
	# Erster Block 50er-Schritte, dann 100 / 200 / 400 - die Wertung wächst
	# multiplikativ, das Ziel muss mithalten.
	assert_eq(GameRun.goal_for_round(1), 150, "Startziel")
	assert_eq(GameRun.goal_for_round(6), 400, "Block 1 endet bei 400")
	assert_eq(GameRun.goal_for_round(7), 500, "erster 100er-Schritt")
	assert_eq(GameRun.goal_for_round(12), 1000)
	assert_eq(GameRun.goal_for_round(13), 1200, "erster 200er-Schritt")
	assert_eq(GameRun.goal_for_round(18), 2200)
	assert_eq(GameRun.goal_for_round(24), 4600, "vierter Block: 400er-Schritte")

func test_advance_round_follows_the_curve_across_a_block_edge():
	for i in 6:
		run.advance_round()
	assert_eq(run.round_number, 7)
	assert_eq(run.round_goal, GameRun.goal_for_round(7), "Rundenwechsel liest die Kurve")
	assert_eq(run.round_goal, 500)

# --- Testhilfen: Zufallsmaterialien (Testmodus) ----------------------------------

func test_randomize_all_materials_fills_every_face_and_edge():
	run.randomize_all_materials()
	for die in run.owned_pool:
		assert_eq(die.materials.size(), 6, "weiterhin 6 Seiten-Materialien")
		for material_id: String in die.materials:
			assert_true(DieMaterial.is_valid_id(material_id), "gültiges Seiten-Material (%s)" % material_id)
		assert_true(DieMaterial.is_valid_id(die.edge_material), "gültiges Kanten-Material (%s)" % die.edge_material)

func test_randomize_gives_each_die_an_independent_array():
	# Kein geteiltes materials-Array: eine In-place-Änderung an einem Würfel darf
	# keinen anderen mitverändern (Sentinel-Wert, deterministisch).
	run.randomize_all_materials()
	run.owned_pool[0].materials[0] = "SENTINEL"
	for i in range(1, run.owned_pool.size()):
		assert_ne(run.owned_pool[i].materials[0], "SENTINEL", "Würfel %d teilt kein Array mit Würfel 0" % i)

func test_clear_all_materials_empties_faces_and_edges():
	run.randomize_all_materials()
	run.clear_all_materials()
	for die in run.owned_pool:
		for material_id: String in die.materials:
			assert_eq(material_id, "", "Seiten-Material geleert")
		assert_eq(die.edge_material, "", "Kanten-Material geleert")

func test_randomize_also_dopes_some_faces():
	# Testmodus zeigt die Stufe-II-Wirkungen ohne Gravur-Grind: ein Teil der
	# Material-Seiten kommt dotiert (30 Würfel × 6 Seiten - nie alles leer).
	run.randomize_all_materials()
	var doped := 0
	for die in run.owned_pool:
		assert_eq(die.upgraded.size(), 6, "weiterhin 6 Marken")
		doped += die.upgraded.count(true)
	assert_gt(doped, 0, "irgendeine Seite steht auf Stufe II")

func test_randomize_gives_each_die_an_independent_upgrade_array():
	run.randomize_all_materials()
	run.owned_pool[0].upgraded[0] = not run.owned_pool[0].upgraded[0]
	var sentinel: bool = run.owned_pool[0].upgraded[0]
	var differs := false
	for i in range(1, run.owned_pool.size()):
		if run.owned_pool[i].upgraded[0] != sentinel:
			differs = true
	assert_true(differs, "kein geteiltes upgraded-Array")

func test_clear_all_materials_also_clears_the_doping():
	run.randomize_all_materials()
	run.clear_all_materials()
	for die in run.owned_pool:
		assert_false(die.upgraded.has(true), "ohne Material keine Dotierung")

# --- Testhilfen: Zufalls-Leiterbahnen (Testmodus) --------------------------------

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
		assert_between(count, 1, 5, "1-5 Leiterbahnen je Würfel")

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
			assert_eq(target, -1, "Leiterbahn entfernt")

# --- Nebenwetten --------------------------------------------------------------

func test_place_side_bet_deducts_stake_and_stores():
	watch_signals(run)
	run.money = 20
	var bet := SideBet._from_template(_template("two_pair"))  # Geld-Einsatz
	run.place_side_bet(bet)
	assert_eq(run.money, 20 - bet.stake, "Einsatz sofort fällig")
	assert_eq(run.active_side_bets.size(), 1)
	assert_signal_emitted(run, "side_bets_changed")

func test_place_engraving_stake_consumes_engravings():
	run.grant_engraving(Engraving.chisel())
	run.grant_engraving(Engraving.file_down())
	var before := run.owned_engravings.size()
	var bet := SideBet._from_template(_template("pawn"))  # 1 Gravur Einsatz
	assert_true(run.can_place_side_bet(bet), "mit Gravuren bezahlbar")
	run.place_side_bet(bet)
	assert_eq(run.owned_engravings.size(), before - 1, "eine Gravur geopfert")

func test_cannot_place_engraving_stake_without_engravings():
	var bet := SideBet._from_template(_template("collateral"))  # 2 Gravuren Einsatz
	assert_false(run.can_place_side_bet(bet), "ohne genug Gravuren nicht setzbar")

func test_resolve_engraving_payout_grants_engravings_and_clears():
	run.money = 50
	var win := SideBet._from_template(_template("full_house"))  # Gravur-Gewinn
	var lose := SideBet._from_template(_template("big_hand"))
	run.place_side_bet(win)
	run.place_side_bet(lose)
	var before := run.owned_engravings.size()
	var result := {"cleared": true, "best_combo_rank": SideBet.combo_rank(DiceScoring.FULL_HOUSE),
		"best_hand_score": 0, "dice_taken": 0, "farkled": false}
	var won := run.resolve_side_bets(result)
	assert_eq(won.size(), 1, "nur das volle Haus gewinnt")
	assert_eq(won[0].id, "full_house")
	assert_eq(run.owned_engravings.size(), before + win.reward_engravings, "Gravuren ausgeschüttet")
	assert_eq(run.active_side_bets.size(), 0, "Auslage geleert")

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

# --- Übertakten (Systemkonsole) ------------------------------------------------

func test_overclock_price_scales_with_combo_strength():
	# Basis = 4 + Basis-Mult: schwache Chips billig, starke teuer.
	assert_eq(GameRun.overclock_price_at(DiceScoring.TWO_KIND, 0), 6)
	assert_eq(GameRun.overclock_price_at(DiceScoring.SIX_KIND, 0), 19)

func test_overclock_price_rises_per_stage_without_cap():
	var base := GameRun.overclock_price_at(DiceScoring.FULL_HOUSE, 0)
	assert_eq(GameRun.overclock_price_at(DiceScoring.FULL_HOUSE, 1), base * 2)
	assert_eq(GameRun.overclock_price_at(DiceScoring.FULL_HOUSE, 7), base * 8, "kein Limit, Preis steigt weiter")

func test_overclock_combo_deducts_and_levels():
	watch_signals(run)
	run.money = 50
	var price := run.overclock_price(DiceScoring.FULL_HOUSE)
	run.overclock_combo(DiceScoring.FULL_HOUSE)
	assert_eq(run.money, 50 - price, "Preis abgezogen")
	assert_eq(run.combo_level(DiceScoring.FULL_HOUSE), 1)
	assert_signal_emitted(run, "combo_upgraded")

func test_overclock_raises_scoring():
	run.money = 100
	run.overclock_combo(DiceScoring.TWO_KIND)
	assert_eq(DiceScoring.mult_for(DiceScoring.TWO_KIND, run.combo_levels), 4, "Stufe 1 verdoppelt den Mult")
	assert_eq(DiceScoring.points_for(DiceScoring.TWO_KIND, run.combo_levels), 20)

func test_can_overclock_checks_money():
	run.money = GameRun.overclock_price_at(DiceScoring.TWO_KIND, 0)
	assert_true(run.can_overclock(DiceScoring.TWO_KIND))
	run.money -= 1
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

func test_midas_glove_clears_the_doping_of_the_face_it_gilds():
	# Neues Material auf der Seite - die alte Dotierung gehoert dem alten Exemplar.
	run.owned_charms.append(Charm.midas_glove())
	var defs: Array[DieDefinition] = []
	for i in 6:
		var die := DieDefinition.standard()
		die.set_face_material(i, DieMaterial.RUBY)
		die.upgraded[i] = true
		defs.append(die)
	var faces := _p([0, 1, 2, 3, 4, 5])
	run.apply_midas_glove(defs, faces, _p([0, 1, 2, 3, 4, 5]))
	for i in 6:
		assert_eq(defs[i].materials[faces[i]], DieMaterial.GOLD)
		assert_false(defs[i].upgraded[faces[i]], "die Rubin-Dotierung ist mit dem Rubin weg")

func test_jewelry_box_clears_the_doping_of_the_face_it_hits():
	run.owned_charms.append(Charm.jewelry_box())
	var many: Array[DieDefinition] = []
	for i in 200:
		var die := DieDefinition.standard()
		die.upgraded.fill(true)
		many.append(die)
	run.apply_jewelry_box(many)
	for die in many:
		for face in 6:
			if die.materials[face] != "":
				assert_false(die.upgraded[face], "belegte Seite verliert ihre Dotierung")

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
	assert_eq(run.hottest_combo(), DiceScoring.FOUR_KIND)

func test_hottest_combo_breaks_ties_by_rank():
	run.combo_levels[DiceScoring.TWO_KIND] = 3
	run.combo_levels[DiceScoring.FOUR_KIND] = 3
	assert_eq(run.hottest_combo(), DiceScoring.FOUR_KIND, "Gleichstand -> der ranghöhere Chip")

func test_hottest_combo_never_throttles_the_fallback_category():
	# "Höchste Zahl" ist die Rückfall-Kategorie jeder Hand: gedrosselt könnte eine
	# Hand ohne jede wertbare Kategorie enden.
	run.combo_levels[DiceScoring.ONE_KIND] = 9
	run.combo_levels[DiceScoring.TWO_KIND] = 2
	assert_eq(run.hottest_combo(), DiceScoring.TWO_KIND)

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

func test_instant_charge_clauses_book_immediately():
	_sign([DealClause.SEED_CAPITAL_II])
	assert_eq(run.charge, GameRun.SEED_CAPITAL_II_CHARGE)
	_sign([DealClause.DISCHARGE])
	assert_eq(run.charge, 0, "unter null geht die Börse nie")

func test_signing_a_card_clears_the_offers_and_signals():
	run.roll_route_offers()
	watch_signals(run)
	run.take_route(1)  # der Risikovertrag trägt immer beide Seiten
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
	# Lieber eine bekannte Klausel als ein leerer Platz.
	var ids: Array[String] = []
	ids.assign(DealClause.ids_for(DealClause.Tier.TWO, DealClause.Kind.MALUS))
	_sign(ids)
	run.round_number = 2
	run.roll_route_offers()
	assert_ne(String(run.route_offers[1][GameRun.CARD_MALUS]), "",
		"der Risikovertrag hat trotzdem ein Kleingedrucktes")

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

func test_maintenance_engraving_is_a_per_hand_grant():
	_sign([DealClause.MAINTENANCE_ENGRAVING])
	assert_true(run.grants_engraving_per_hand())
	var before := run.owned_engravings.size()
	run.apply_round_start_charms()
	assert_eq(run.owned_engravings.size(), before, "der Rundenbeginn schenkt nichts mehr")

func test_high_voltage_and_stage_cap_resolve_in_order():
	assert_eq(run.max_overcharge_stages(), 3, "Hinterzimmer ohne Vertrag")
	_sign([DealClause.HIGH_VOLTAGE])
	assert_eq(run.max_overcharge_stages(), 3 + GameRun.HIGH_VOLTAGE_STAGES, "kein Deckel bei 5")
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

func test_mains_hum_raises_every_stage_by_a_quarter():
	var plain := run.stage_size(2)
	_sign([DealClause.MAINS_HUM])
	assert_eq(run.stage_size(2), roundi(plain * GameRun.MAINS_HUM_FACTOR))

func test_double_loader_mints_two_charges_per_stage():
	_sign([DealClause.DOUBLE_LOADER])
	assert_eq(run.charge_per_stage(), 2)
	var split := run.charge_split(2)
	assert_eq(int(split["stored"]), 4, "zwei Stufen prägen vier Ladungen")

func test_shop_price_clauses_multiply():
	_sign([DealClause.INFLATION])
	assert_eq(run.shop_price(100), 125)
	_sign([DealClause.CASH_DISCOUNT])
	assert_eq(run.shop_price(100), 100, "Inflation und Skonto heben sich fast auf")
	run.settle_block_deals()
	_sign([DealClause.CASH_DISCOUNT])
	assert_eq(run.shop_price(100), 80)

func test_the_first_charm_of_the_block_is_free():
	_sign([DealClause.OVERCLOCK_DISCOUNT])
	assert_true(run.charm_is_free())
	run.consume_free_charm()
	assert_false(run.charm_is_free(), "der Gutschein verbraucht sich")

func test_free_spins_are_one_per_machine():
	run.hub_level = 10  # alle drei Automaten frei
	_sign([DealClause.FREE_SPINS])
	assert_eq(run.slot_spin_price(0), 0)
	run.money = 0
	assert_true(run.can_spin_slot(0), "gratis geht auch ohne Geld")
	run.spin_slot(0)
	assert_gt(run.slot_spin_price(0), 0, "der Gratisdreh ist verbraucht")
	assert_eq(run.slot_spin_price(1), 0, "der nächste Automat hat seinen noch")

func test_power_cut_switches_the_slots_off():
	run.hub_level = 10
	run.money = 999
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

func test_tournament_night_doubles_engraving_rewards():
	_sign([DealClause.TOURNAMENT_NIGHT])
	var bet := SideBet._from_template(_template("full_house"))  # Gravur-Gewinn
	run.money = 50
	run.place_side_bet(bet)
	var before := run.owned_engravings.size()
	var result := {"cleared": true, "best_combo_rank": SideBet.combo_rank(DiceScoring.FULL_HOUSE),
		"best_hand_score": 0, "dice_taken": 0, "farkled": false}
	run.resolve_side_bets(result)
	assert_eq(run.owned_engravings.size(), before + bet.reward_engravings * 2)

func test_power_spike_spotlights_without_the_charm():
	_sign([DealClause.POWER_SPIKE])
	run.apply_round_start_charms()
	assert_true(DiceScoring.HAND_PRIORITY.has(run.spotlight_combo), "Rampenlicht ohne Charm")

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

# --- Helfer -----------------------------------------------------------------------

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
