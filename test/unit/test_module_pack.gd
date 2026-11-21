extends GutTest
## Das MODUL-PAKET: Größe und Seltenheits-Stufe stehen beim Kauf fest. Der Kauf würfelt die
## Optionen der Größe (3/4/5/5) nach pending_parts, und der Glückswürfel sagt, wie viele davon
## eingebaut werden dürfen - der Rest verfällt mit dem Beutel.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 500

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _sign(ids: Array) -> void:
	var typed: Array[String] = []
	typed.assign(ids)
	run.sign_clauses(typed)

# --- Inhalt ---------------------------------------------------------------------

func test_the_options_follow_the_size() -> void:
	for pack_size in CardPack.SIZES:
		assert_eq(ModulePack.option_count(pack_size), CardPack.OPTION_COUNTS[pack_size])
		var parts := run.purchase_module_pack(ModulePack.make(pack_size, 0), 0, _rng(pack_size))
		assert_eq(parts.size(), CardPack.OPTION_COUNTS[pack_size], "Größe %d" % pack_size)
		run.pending_parts.clear()
		run.module_keeps = 0

func test_the_prices_stay_frozen_and_the_grade_lifts_them() -> void:
	assert_eq(ModulePack.PRICES, [7, 10, 18, 20, 24])
	var last_size := 0
	for pack_size in CardPack.SIZES:
		assert_gt(int(ModulePack.PRICES[pack_size]), last_size, "größer kostet mehr")
		last_size = int(ModulePack.PRICES[pack_size])
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
			var bag := ModulePack.make(CardPack.SIZE_HUGE,
				ModulePack.GRADE_COMMON if side == 0 else ModulePack.GRADE_LEGENDARY)
			for part in ModulePack.roll_contents(bag, -1, rng):
				ranks[side] += float(ModulePack.GRADE_RARITIES.find(part.rarity))
	assert_gt(ranks[1], ranks[0] * 1.3, "Legendär zieht deutlich höher")

func test_contents_are_shop_modules_without_duplicates_and_own_instances() -> void:
	var rng := _rng(5)
	for i in 30:
		var parts := ModulePack.roll_contents(ModulePack.make(CardPack.SIZE_HUGE, i % 4), -1, rng)
		assert_eq(parts.size(), 6, "die Optionen der Größe")
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
	assert_eq(bag.display_name, "5er Modul-Paket · Episch")
	assert_eq(ModulePack.make(CardPack.SIZE_NORMAL, 0).display_name, "4er Modul-Paket")
	assert_string_contains(ModulePack.info_body(bag), "5 Module")
	assert_string_contains(ModulePack.info_body(ModulePack.make(CardPack.SIZE_SMALL, 0)),
		"3 Module. " + CardPack.DIE_SAYS)
	assert_eq(ModulePack.grade_tint(ModulePack.GRADE_RARE),
		ComboPart.RARITY_COLORS[ComboPart.RARITY_RARE], "die Farbe der Seltenheit")

# --- Kauf -------------------------------------------------------------------------

func test_buying_stashes_every_module_and_opens_no_choice() -> void:
	var bag := ModulePack.make(CardPack.SIZE_HUGE, ModulePack.GRADE_RARE)
	var parts := run.purchase_module_pack(bag, 24, _rng(4))
	assert_eq(run.money, 476)
	assert_eq(parts.size(), 6)
	assert_eq(run.pending_parts.size(), 6, "alle liegen in der Grube")
	assert_eq(run.module_keeps, 1, "der frische Glückswürfel: eines einbauen")
	assert_eq(int(run.last_module_roll["keeps"]), 1)
	for i in parts.size():
		assert_same(run.pending_parts[i], parts[i], "geliefert wird, was wartet")
		assert_true(parts[i].from_pack, "aus dem Paket: sein Einbau darf verdrängen")
	assert_true(run.pending_pack_choices.is_empty(), "keine Auswahl")

func test_the_roll_caps_what_may_be_installed() -> void:
	run.luck_die.faces.assign([4, 4, 4, 4, 4, 4])
	run.purchase_module_pack(ModulePack.make(CardPack.SIZE_SMALL, 0), 0, _rng(1))
	assert_eq(run.module_keeps, 3, "nie mehr als Optionen")

func test_installing_the_last_kept_module_lapses_the_rest() -> void:
	run.luck_die.faces.assign([2, 2, 2, 2, 2, 2])
	var parts := run.purchase_module_pack(ModulePack.make(CardPack.SIZE_NORMAL, 0), 0, _rng(2))
	assert_eq(run.module_keeps, 2)
	var key := String(DiceScoring.HAND_PRIORITY[0])
	assert_true(run.install_pending_part_at(0, key, 0))
	assert_eq(run.pending_parts.size(), 3, "noch einer darf")
	assert_true(run.last_lapsed_parts.is_empty())
	assert_true(run.install_pending_part_at(0, key, 1))
	assert_true(run.pending_parts.is_empty(), "der Wurf ist aufgebraucht")
	assert_eq(run.last_lapsed_parts.size(), 2, "zwei verfallen mit dem Beutel")
	for part in run.last_lapsed_parts:
		assert_true(parts.has(part))
	assert_eq(run.module_keeps, 0)

func test_discarding_everything_clears_the_keeps() -> void:
	run.luck_die.faces.assign([2, 2, 2, 2, 2, 2])
	run.purchase_module_pack(ModulePack.make(CardPack.SIZE_SMALL, 0), 0, _rng(3))
	while not run.pending_parts.is_empty():
		assert_true(run.discard_pending_part(0))
	assert_eq(run.module_keeps, 0)

func test_free_hand_adds_an_install() -> void:
	_sign([DealClause.FREE_HAND])
	run.purchase_module_pack(ModulePack.make(CardPack.SIZE_NORMAL, 0), 0, _rng(5))
	assert_eq(run.module_keeps, 2, "Wurf 1 + Freie Hand")

func test_bet_modules_never_lapse() -> void:
	run.stash_part(ComboPart.resistor())
	run.luck_die.faces.assign([1, 1, 1, 1, 1, 1])
	run.purchase_module_pack(ModulePack.make(CardPack.SIZE_SMALL, 0), 0, _rng(6))
	var key := String(DiceScoring.HAND_PRIORITY[0])
	assert_true(run.install_pending_part_at(1, key, 0))
	assert_eq(run.pending_parts.size(), 1, "das Wett-Modul bleibt")
	assert_false(run.pending_parts[0].from_pack)

func test_no_free_socket_does_not_block_buying() -> void:
	for key: String in DiceScoring.HAND_PRIORITY:
		run.combo_parts[key] = [ComboPart.resistor(), ComboPart.resistor(), ComboPart.resistor()]
	assert_false(run.parts_room())
	assert_false(run.purchase_module_pack(ModulePack.make(CardPack.SIZE_SMALL, 0), 1).is_empty(),
		"kaufbar ohne freien Steckplatz")

func test_a_null_pack_books_nothing() -> void:
	assert_true(run.purchase_module_pack(null, 10).is_empty())
	assert_eq(run.money, 500)
	assert_true(run.pending_parts.is_empty())

func test_the_choice_record_knows_no_module_kind() -> void:
	assert_false(PackChoice.new().has_method("is_modules"))
