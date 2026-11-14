extends GutTest
## Das MODUL-PAKET: Größe und Seltenheits-Stufe stehen beim Kauf fest, Optionen und Wahlen
## folgen der Karten-Tabelle; gewählte Module warten in pending_parts auf den EINBAU.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 500

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _buy_open(bag: ModulePack, rng: RandomNumberGenerator = null) -> PackChoice:
	var stored := run.purchase_module_pack(bag, bag.price, rng)
	return run.open_stored_pack(stored.store_uid, rng)

# --- Zahlen ---------------------------------------------------------------------

func test_the_choice_numbers_are_those_of_card_packs() -> void:
	for pack_size in CardPack.SIZES:
		var choice := _buy_open(ModulePack.make(pack_size, ModulePack.GRADE_COMMON), _rng(3))
		assert_eq(choice.kind, PackChoice.KIND_MODULES)
		assert_true(choice.is_modules())
		assert_gte(choice.option_count(), CardPack.option_count(pack_size),
			"Größe %d: mindestens die Optionen der Tabelle" % pack_size)
		assert_gte(choice.picks, CardPack.base_picks(pack_size))
		run.pending_pack_choices.clear()

func test_the_prices_follow_the_formula_and_the_grade_lifts_them() -> void:
	for pack_size in CardPack.SIZES:
		assert_almost_eq(float(ModulePack.PRICES[pack_size]),
			ModulePack.formula_price(pack_size), 0.6, "Größe %d" % pack_size)
		var last := 0
		for grade in ModulePack.GRADES:
			var price := ModulePack.price_of(pack_size, grade)
			assert_gt(price, last, "die Stufe hebt den Preis")
			last = price

func test_the_grade_shifts_the_rarity_weights_up() -> void:
	var common := ComboPart.resistor()
	var rare := ComboPart.relay()
	var epic := ComboPart.counter_part()
	for grade in range(1, ModulePack.GRADES.size()):
		assert_lt(ModulePack.weight_of(common, grade), ModulePack.weight_of(common, grade - 1),
			"gewöhnliche werden seltener")
		assert_gt(ModulePack.weight_of(epic, grade), ModulePack.weight_of(epic, grade - 1),
			"epische häufiger")
	assert_gt(ModulePack.weight_of(rare, ModulePack.GRADE_RARE),
		ModulePack.weight_of(rare, ModulePack.GRADE_COMMON))

func test_a_higher_grade_rolls_rarer_modules_on_average() -> void:
	var rng := _rng(11)
	var ranks := [0.0, 0.0]
	for i in 200:
		for side in 2:
			var bag := ModulePack.make(CardPack.SIZE_NORMAL,
				ModulePack.GRADE_COMMON if side == 0 else ModulePack.GRADE_LEGENDARY)
			for part in ModulePack.roll_contents(bag, -1, rng):
				ranks[side] += float(ModulePack.GRADE_RARITIES.find(part.rarity))
	assert_gt(ranks[1], ranks[0] * 1.3, "Legendär zieht deutlich höher")

func test_contents_are_shop_modules_without_duplicates_and_own_instances() -> void:
	var rng := _rng(5)
	for i in 30:
		var parts := ModulePack.roll_contents(ModulePack.make(CardPack.SIZE_HUGE, i % 4), -1, rng)
		assert_eq(parts.size(), 5)
		var ids := {}
		for part in parts:
			assert_false(part.secret, "nie ein Schwarzmarkt-Teil")
			assert_false(ids.has(part.id), "keine Dublette")
			ids[part.id] = true
	var a := ModulePack.roll_contents(ModulePack.make(0, 0), 1, _rng(1))
	var b := ModulePack.roll_contents(ModulePack.make(0, 0), 1, _rng(1))
	assert_eq(a[0].id, b[0].id)
	assert_ne(a[0], b[0], "je Wurf eigene Instanzen")

func test_the_shop_grade_weights_climb_with_the_tier() -> void:
	var low := ModulePack.shop_grade_weights(1)
	var high := ModulePack.shop_grade_weights(10)
	assert_eq(low, ModulePack.SHOP_GRADE_WEIGHTS)
	assert_lt(int(high[0]), int(low[0]))
	assert_gt(int(high[3]), int(low[3]))

func test_name_and_info_say_size_and_grade_never_the_modules() -> void:
	var bag := ModulePack.make(CardPack.SIZE_LARGE, ModulePack.GRADE_EPIC)
	assert_eq(bag.display_name, "Großes Modul-Paket · Episch")
	assert_eq(ModulePack.make(CardPack.SIZE_NORMAL, 0).display_name, "Modul-Paket")
	assert_string_contains(ModulePack.info_body(bag), CardPack.choice_line(CardPack.SIZE_LARGE))
	assert_eq(ModulePack.grade_tint(ModulePack.GRADE_RARE),
		ComboPart.RARITY_COLORS[ComboPart.RARITY_RARE], "die Farbe der Seltenheit")

# --- Lager ------------------------------------------------------------------------

func test_buying_stores_a_copy_in_its_own_lane() -> void:
	var bag := ModulePack.make(CardPack.SIZE_NORMAL, ModulePack.GRADE_RARE)
	var stored := run.purchase_module_pack(bag, 12)
	assert_eq(run.money, 488)
	assert_eq(run.stored_module_packs, [stored] as Array[ModulePack])
	assert_ne(stored, bag, "die Auslage behält ihr Angebot")
	assert_eq(GameRun.store_lane_of(stored), GameRun.LANE_MODULES)
	assert_same(run.stored_pack_at(GameRun.LANE_MODULES, 0), stored, "Platz 0 der Rinne")
	assert_true(run.stored_card_packs.is_empty() and run.stored_dice_packs.is_empty())
	assert_true(run.pending_pack_choices.is_empty(), "geöffnet wird erst im Lager")

func test_a_full_lane_refuses_without_booking() -> void:
	for i in GameRun.STORE_CAPACITY:
		assert_not_null(run.purchase_module_pack(ModulePack.make(0, 0), 1))
	assert_true(run.store_full(GameRun.LANE_MODULES))
	assert_null(run.purchase_module_pack(ModulePack.make(0, 0), 1))
	assert_eq(run.money, 500 - GameRun.STORE_CAPACITY)
	assert_false(run.store_full(GameRun.LANE_CARDS), "die anderen Reihen bleiben frei")
	assert_not_null(run.stored_pack_at(GameRun.LANE_MODULES, GameRun.STORE_CAPACITY - 1),
		"der letzte steht auf dem letzten Platz")

func test_no_free_socket_does_not_block_buying_or_opening() -> void:
	for key: String in DiceScoring.HAND_PRIORITY:
		run.combo_parts[key] = [ComboPart.resistor(), ComboPart.resistor(), ComboPart.resistor()]
	assert_false(run.parts_room())
	var choice := _buy_open(ModulePack.make(CardPack.SIZE_SMALL, 0))
	assert_not_null(choice, "kauf- und öffenbar ohne freien Steckplatz")

func test_a_new_run_has_an_empty_module_lane() -> void:
	run.purchase_module_pack(ModulePack.make(0, 0), 1)
	assert_true(GameRun.new_run().stored_module_packs.is_empty())

# --- Öffnen und Bestätigen --------------------------------------------------------

func test_confirm_sends_the_picked_modules_to_pending_parts() -> void:
	var choice := _buy_open(ModulePack.make(CardPack.SIZE_LARGE, ModulePack.GRADE_EPIC), _rng(7))
	assert_true(run.stored_module_packs.is_empty(), "das Paket hat das Lager verlassen")
	for option in choice.options:
		assert_true(option is ComboPart)
	var picked: ComboPart = choice.options[1]
	var booked := run.confirm_pack_choice(choice, [1])
	var parts: Array[ComboPart] = booked["parts"]
	assert_eq(parts.size(), 1)
	assert_eq(run.pending_parts.size(), 1)
	assert_eq(run.pending_parts[0].id, picked.id)
	assert_true(run.pending_parts[0].from_pack, "aus dem Paket: sein Einbau darf verdrängen")
	assert_true(run.pending_pack_choices.is_empty(), "Ungewähltes verfällt")

func test_reshuffle_rolls_new_modules_once() -> void:
	run.energy = 3
	var choice := _buy_open(ModulePack.make(CardPack.SIZE_HUGE, 0), _rng(2))
	var count := choice.option_count()
	assert_true(run.reshuffle_pack_choice(choice, _rng(9)))
	assert_eq(choice.option_count(), count, "die Zahl bleibt")
	for option in choice.options:
		assert_true(option is ComboPart)
	assert_false(run.reshuffle_pack_choice(choice, _rng(9)), "einmal je Paket")
