extends GutTest
## Das MODUL-PAKET: Größe und Seltenheits-Stufe stehen beim Kauf fest. Es hat KEINE Wahl:
## der Kauf würfelt 1-3 Module und legt ALLE nach pending_parts (Spieler-Entscheid 2026-11-17).

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 500

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

## Ein rng, dessen erster Wurf den Glückswurf sicher trifft bzw. sicher verfehlt.
func _luck_rng(hit: bool) -> RandomNumberGenerator:
	for seed_value in 500:
		var rng := _rng(seed_value)
		var roll := rng.randf()
		if (roll < 0.05) == hit and (roll > 0.95 or hit):
			return _rng(seed_value)
	return null

func _sign(ids: Array) -> void:
	var typed: Array[String] = []
	typed.assign(ids)
	run.sign_clauses(typed)

# --- Inhalt ---------------------------------------------------------------------

func test_the_content_table_is_one_two_two_three() -> void:
	assert_eq(ModulePack.CONTENT_COUNTS, [1, 2, 2, 3])
	for pack_size in CardPack.SIZES:
		assert_eq(ModulePack.content_count(pack_size, 0, 1.0, _luck_rng(false)),
			ModulePack.CONTENT_COUNTS[pack_size], "Größe %d ohne Glück" % pack_size)

func test_the_luck_roll_adds_one_but_never_past_three() -> void:
	assert_eq(ModulePack.content_count(CardPack.SIZE_SMALL, 0, 1.0, _luck_rng(true)), 2)
	assert_eq(ModulePack.content_count(CardPack.SIZE_LARGE, 0, 1.0, _luck_rng(true)), 3)
	assert_eq(ModulePack.content_count(CardPack.SIZE_HUGE, 99, 4.0, _luck_rng(true)), 3,
		"Riesig steht am Deckel")
	assert_eq(ModulePack.content_lucky_chance(CardPack.SIZE_HUGE, 50), 0.0)
	assert_gt(ModulePack.content_lucky_chance(CardPack.SIZE_SMALL, 10),
		ModulePack.content_lucky_chance(CardPack.SIZE_SMALL, 0), "Glück hebt die Chance")
	assert_lte(ModulePack.content_lucky_chance(CardPack.SIZE_SMALL, 1000, 2.0), CardPack.LUCKY_CAP)

func test_the_prices_follow_the_formula_and_the_grade_lifts_them() -> void:
	var last_size := 0
	for pack_size in CardPack.SIZES:
		assert_almost_eq(float(ModulePack.PRICES[pack_size]),
			ModulePack.formula_price(pack_size), 0.6, "Größe %d" % pack_size)
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
		assert_eq(parts.size(), 3, "der Grundinhalt")
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
	assert_string_contains(ModulePack.info_body(bag), "2 Module, alle behalten")
	assert_string_contains(ModulePack.info_body(ModulePack.make(CardPack.SIZE_SMALL, 0)),
		"1 Modul, alle behalten - mit Glück mehr.")
	assert_eq(ModulePack.grade_tint(ModulePack.GRADE_RARE),
		ComboPart.RARITY_COLORS[ComboPart.RARITY_RARE], "die Farbe der Seltenheit")

# --- Kauf -------------------------------------------------------------------------

func test_buying_stashes_every_module_and_opens_no_choice() -> void:
	var bag := ModulePack.make(CardPack.SIZE_HUGE, ModulePack.GRADE_RARE)
	var parts := run.purchase_module_pack(bag, 24, _rng(4))
	assert_eq(run.money, 476)
	assert_eq(parts.size(), 3)
	assert_eq(run.pending_parts.size(), 3, "alle behalten")
	for i in parts.size():
		assert_same(run.pending_parts[i], parts[i], "geliefert wird, was wartet")
		assert_true(parts[i].from_pack, "aus dem Paket: sein Einbau darf verdrängen")
	assert_true(run.pending_pack_choices.is_empty(), "keine Auswahl")
	assert_true(run.stored_module_packs.is_empty(), "nie ins Lager")

func test_zugabe_adds_one_module_up_to_the_cap() -> void:
	_sign([DealClause.BONUS_PICK])
	assert_eq(run.purchase_module_pack(ModulePack.make(CardPack.SIZE_SMALL, 0), 1,
		_luck_rng(false)).size(), 2, "Klein + Zugabe")
	run.pending_parts.clear()
	assert_eq(run.purchase_module_pack(ModulePack.make(CardPack.SIZE_HUGE, 0), 1,
		_luck_rng(true)).size(), 3, "der Deckel gilt auch mit Zugabe")

func test_supplement_and_sealed_do_not_touch_module_packs() -> void:
	_sign([DealClause.SUPPLEMENT])
	assert_eq(run.purchase_module_pack(ModulePack.make(CardPack.SIZE_NORMAL, 0), 1,
		_luck_rng(false)).size(), 2)
	run.active_deals.clear()
	run.pending_parts.clear()
	_sign([DealClause.SEALED])
	assert_eq(run.purchase_module_pack(ModulePack.make(CardPack.SIZE_NORMAL, 0), 1,
		_luck_rng(false)).size(), 2)

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
