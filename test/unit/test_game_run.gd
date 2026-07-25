extends GutTest
## Tier-1-Tests des GameRun (siehe scripts/game_run.gd): der persistente
## Run-Zustand (Geld, Pool, Charms, Gravuren, Rundenfortschritt) als reine
## Daten-Klasse - komplett ohne Szene testbar. Shop und Gravur-Station mutieren
## den Zustand ausschließlich über diese Methoden; die HUD hört auf die Signale.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

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

# --- Charms ---------------------------------------------------------------------

func test_purchase_charm_grants_deducts_and_emits():
	watch_signals(run)
	run.money = 30
	run.purchase_charm(Charm.rabbits_foot(), 25)
	assert_eq(run.money, 5)
	assert_eq(run.owned_charms.size(), 1)
	assert_signal_emitted(run, "charms_changed")

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
