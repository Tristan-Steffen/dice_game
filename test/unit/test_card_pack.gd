extends GutTest
## Die KARTEN-PAKETE des Ladens: Optionen je Sorte und Größe, Garantien, Preise.

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func test_option_count_follows_the_size() -> void:
	for pack_size in CardPack.SIZES:
		var card_pack := CardPack.make(CardPack.SORT_NUMBER, pack_size)
		var cards := CardPack.roll_contents(card_pack, 0.0, false, _rng(pack_size + 1))
		assert_eq(cards.size(), [3, 4, 5, 5][pack_size], "Größe %d" % pack_size)

func test_no_special_pack_sort_any_more() -> void:
	assert_false(CardPack.SORTS.has("special"), "die Sonder-Karte kommt einzeln")
	for i in 40:
		assert_true(CardPack.SORTS.has(CardPack.roll_shop().sort))

func test_regular_sorts_hold_only_their_own_cards() -> void:
	var expected := {CardPack.SORT_NUMBER: Pack.TYPE_NUMBER,
		CardPack.SORT_MATERIAL: Pack.TYPE_MATERIAL, CardPack.SORT_RUNE: Pack.TYPE_DICE_MOD}
	for pack_sort: String in expected:
		for seed_value in 30:
			var cards := CardPack.roll_contents(CardPack.make(pack_sort, CardPack.SIZE_HUGE),
				0.0, false, _rng(seed_value))
			for card in cards:
				assert_eq(card.type, String(expected[pack_sort]), pack_sort)
				assert_false(card.is_catalyst() or card.is_operator(), "keine Sonderware")

func test_large_and_huge_keep_their_guarantee_among_the_options() -> void:
	for pack_sort: String in [CardPack.SORT_NUMBER, CardPack.SORT_MIXED]:
		for seed_value in 60:
			var large := CardPack.roll_contents(CardPack.make(pack_sort, CardPack.SIZE_LARGE),
				0.0, false, _rng(seed_value))
			var huge := CardPack.roll_contents(CardPack.make(pack_sort, CardPack.SIZE_HUGE),
				0.0, false, _rng(seed_value + 1000))
			assert_true(_max_tier(large) >= Pack.TIER_GROSS, "Groß: mindestens eine Große")
			assert_true(_max_tier(huge) >= Pack.TIER_KOLOSSAL, "Riesig: eine Kolossale")

func _max_tier(cards: Array[Pack]) -> int:
	var best := -1
	for card in cards:
		best = maxi(best, card.tier)
	return best

func test_never_repair_card_or_blank() -> void:
	for seed_value in 80:
		var cards := CardPack.roll_contents(CardPack.make(CardPack.SORT_MIXED,
			CardPack.SIZE_HUGE), 0.2, false, _rng(seed_value))
		for card in cards:
			assert_false(card.is_repair(), "nie die Reparatur-Karte")
			assert_false(card.from_blank(), "nie ein Rohling")

func test_no_duplicate_net_inside_one_pack() -> void:
	for seed_value in 60:
		var cards := CardPack.roll_contents(CardPack.make(CardPack.SORT_RUNE,
			CardPack.SIZE_HUGE), 0.0, false, _rng(seed_value))
		var keys := {}
		for card in cards:
			keys[CardPack.content_key(card)] = true
		assert_eq(keys.size(), cards.size(), "keine Dublette (Seed %d)" % seed_value)

func test_mixed_packs_mix_the_sorts() -> void:
	var seen := {}
	for seed_value in 60:
		for card in CardPack.roll_contents(CardPack.make(CardPack.SORT_MIXED,
				CardPack.SIZE_HUGE), 0.0, false, _rng(seed_value)):
			seen[Pack.shelf_of(card)] = true
	assert_eq(seen.size(), Pack.SHELF_ORDER.size(), "alle vier Sorten kommen vor")

func test_bulk_order_lifts_the_card_sizes() -> void:
	var plain := 0
	var bulk := 0
	for seed_value in 200:
		for card in CardPack.roll_contents(CardPack.make(CardPack.SORT_NUMBER,
				CardPack.SIZE_NORMAL), 0.0, false, _rng(seed_value)):
			plain += card.tier
		for card in CardPack.roll_contents(CardPack.make(CardPack.SORT_NUMBER,
				CardPack.SIZE_NORMAL), 0.0, true, _rng(seed_value)):
			bulk += card.tier
	assert_gt(bulk, plain, "Großauftrag würfelt größer")

## Die Preistabelle ist festgeschrieben; sie muss zur Formel passen: erwartete Wahlen
## × Ladenwert einer Option × Auswahl-Prämie. Misch rechnet mit dem Regal-Mittel.
func test_price_table_matches_the_formula() -> void:
	for pack_sort: String in CardPack.SORTS:
		for pack_size in CardPack.SIZES:
			var expected := CardPack.expected_picks(pack_size) \
				* _option_value(pack_sort, pack_size) * CardPack.CHOICE_PREMIUM
			assert_almost_eq(float(CardPack.price_of(pack_sort, pack_size)), expected, 2.0,
				"%s / %d" % [pack_sort, pack_size])

func _option_value(pack_sort: String, pack_size: int) -> float:
	var weights: Array = CardPack.CARD_TIER_WEIGHTS[pack_size]
	var tier_factor := 0.0
	for i in weights.size():
		tier_factor += float(weights[i]) * Pack.tier_price_factor(i)
	if pack_sort == CardPack.SORT_MIXED:
		var total := 0.0
		var weight_sum := 0.0
		for pack_type: String in Pack.SHELF_WEIGHTS:
			total += float(Pack.SHELF_WEIGHTS[pack_type]) * Pack.type_price(pack_type)
			weight_sum += float(Pack.SHELF_WEIGHTS[pack_type])
		return total / weight_sum * tier_factor
	return Pack.type_price(String(CardPack.SORT_TYPES[pack_sort])) * tier_factor

func test_names_and_info_never_tell_the_contents() -> void:
	assert_eq(CardPack.make(CardPack.SORT_MIXED, CardPack.SIZE_LARGE).display_name,
		"Großes Misch-Paket")
	assert_eq(CardPack.make(CardPack.SORT_MATERIAL, CardPack.SIZE_NORMAL).display_name,
		"Material-Paket")
	var info := CardPack.info_body(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_HUGE))
	assert_string_contains(info, "2 von 5")
	assert_string_contains(info, "mit Glück mehr")
	assert_string_contains(info, "Kolossale")

func test_bargain_hunter_works_on_packs() -> void:
	var ids: Array[String] = [Charm.BARGAIN_HUNTER]
	assert_eq(CharmEffects.pack_price(20, "", ids), 14, "30 % weniger")
