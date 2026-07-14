extends GutTest
## Tier-1-Tests des GameRun (siehe scripts/game_run.gd): der persistente
## Run-Zustand (Geld, Pool, Charms, Coupons, Rundenfortschritt) als reine
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
	assert_eq(run.owned_coupons.size(), 0)

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

# --- Coupons --------------------------------------------------------------------

func test_grant_and_consume_coupon():
	watch_signals(run)
	run.grant_coupon(Coupon.chisel())
	assert_eq(run.owned_coupons.size(), 1)
	assert_true(run.consume_coupon(Coupon.CHISEL))
	assert_eq(run.owned_coupons.size(), 0)
	assert_signal_emit_count(run, "coupons_changed", 2)

func test_consume_missing_coupon_returns_false_without_signal():
	watch_signals(run)
	assert_false(run.consume_coupon(Coupon.CHISEL))
	assert_signal_emit_count(run, "coupons_changed", 0)

func test_consume_removes_only_one_of_a_kind():
	run.grant_coupon(Coupon.chisel())
	run.grant_coupon(Coupon.chisel())
	run.consume_coupon(Coupon.CHISEL)
	assert_eq(run.owned_coupons.size(), 1)

# --- Coupon-Bögen ---------------------------------------------------------------

func test_buy_coupon_sheet_deducts_and_emits_the_sheet():
	run.money = 20
	var captured: Array = []
	run.sheet_purchased.connect(func(sheet: CouponSheet, kind: int) -> void: captured.append([sheet, kind]))
	var sheet := run.buy_coupon_sheet(CouponSheet.Kind.SNIPPET, 6)
	assert_eq(run.money, 14)
	assert_eq(captured.size(), 1)
	assert_eq(captured[0][0], sheet, "Signal liefert denselben Bogen wie der Rückgabewert")
	assert_eq(captured[0][1], CouponSheet.Kind.SNIPPET)

func test_buy_coupon_sheet_respects_allowed_kinds():
	# Sortenreine Packs (siehe ShopController.PACKS): der Filter wird bis in die
	# Auswürfelung durchgereicht.
	run.money = 100
	var allowed: Array[String] = [Coupon.KIND_MEAL]
	var sheet := run.buy_coupon_sheet(CouponSheet.Kind.LARGE, 16, allowed)
	for tile in sheet.tiles:
		if tile.kind == CouponSheet.TileKind.ETCHING:
			assert_eq(tile.coupon.kind, Coupon.KIND_MEAL, "nur Gerichte im Food-Pack")

func test_buy_coupon_sheet_does_not_grant_coupons_immediately():
	# Die Gutschrift der Kacheln übernimmt erst die Abschluss-Animation
	# (grant_coupon/add_money je Kachel, siehe scene_root).
	run.money = 20
	run.buy_coupon_sheet(CouponSheet.Kind.LARGE, 16)
	assert_eq(run.owned_coupons.size(), 0)

# --- Menü-Stufen (Meal Deals) ------------------------------------------------------

func test_eat_meal_raises_the_combo_level():
	run.eat_meal(DiceScoring.TWO_KIND)
	run.eat_meal(DiceScoring.TWO_KIND)
	run.eat_meal(DiceScoring.SIX_KIND)
	assert_eq(run.combo_levels[DiceScoring.TWO_KIND], 2)
	assert_eq(run.combo_levels[DiceScoring.SIX_KIND], 1)

func test_eat_meal_emits_combo_upgraded():
	watch_signals(run)
	run.eat_meal(DiceScoring.FULL_HOUSE)
	assert_signal_emitted_with_parameters(run, "combo_upgraded", [DiceScoring.FULL_HOUSE, 1])

func test_granting_a_meal_coupon_eats_it_immediately():
	# Menü-Coupons landen NIE im Inventar - das Gericht wirkt sofort als Stufe.
	run.grant_coupon(Coupon.meal_coupon(DiceScoring.THREE_KIND))
	assert_eq(run.owned_coupons.size(), 0, "kein Inventar-Eintrag")
	assert_eq(run.combo_levels[DiceScoring.THREE_KIND], 1, "Stufe sofort erhöht")

func test_granting_other_coupons_still_stores_them():
	run.grant_coupon(Coupon.chisel())
	assert_eq(run.owned_coupons.size(), 1)
	assert_false(run.combo_levels.has(Coupon.CHISEL))

func test_new_run_starts_without_levels():
	assert_true(GameRun.new_run().combo_levels.is_empty())

# --- Rundenfortschritt -----------------------------------------------------------

func test_advance_round_increments_number_and_goal():
	run.advance_round()
	run.advance_round()
	assert_eq(run.round_number, 3)
	assert_eq(run.round_goal, GameRun.BASE_GOAL + 2 * GameRun.GOAL_INCREMENT)

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

func test_grant_charms_adds_missing_without_duplicates():
	watch_signals(run)
	var charms: Array[Charm] = [Charm.golden_scarab(), Charm.goldsmith()]
	run.grant_charms(charms)
	assert_eq(run.owned_charm_ids(), [Charm.GOLDEN_SCARAB, Charm.GOLDSMITH])
	assert_signal_emitted(run, "charms_changed")
	# Erneutes Gewähren fügt nichts hinzu (schon besessen).
	run.grant_charms([Charm.golden_scarab()])
	assert_eq(run.owned_charm_ids().count(Charm.GOLDEN_SCARAB), 1, "kein Duplikat")

func test_remove_charms_strips_given_ids():
	run.grant_charms([Charm.golden_scarab(), Charm.goldsmith(), Charm.small_fry()])
	run.remove_charms([Charm.GOLDSMITH])
	assert_eq(run.owned_charm_ids(), [Charm.GOLDEN_SCARAB, Charm.SMALL_FRY], "nur Goldschmied entfernt")

# --- Helfer -----------------------------------------------------------------------

func _count_style(style_id: String) -> int:
	var count := 0
	for def in run.owned_pool:
		if def.style_id == style_id:
			count += 1
	return count
