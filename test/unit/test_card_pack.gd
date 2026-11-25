extends GutTest
## Die KARTEN-PAKETE des Ladens: Optionen je Sorte und Kartenzahl, Güte, Garantien, Preise.

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func test_option_count_follows_the_card_count() -> void:
	for pack_size in CardPack.SIZES:
		var card_pack := CardPack.make(CardPack.SORT_NUMBER, pack_size)
		var cards := CardPack.roll_contents(card_pack, 0.0, _rng(pack_size + 1))
		assert_eq(cards.size(), [2, 3, 4, 5, 6][pack_size], "Größe %d" % pack_size)

func test_card_packs_run_from_two_to_six() -> void:
	assert_eq(CardPack.option_count(CardPack.SIZE_TINY), 2)
	assert_eq(CardPack.option_count(CardPack.SIZE_HUGE), 6)
	assert_eq(CardPack.make(CardPack.SORT_NUMBER, 9).size, CardPack.SIZE_HUGE, "geklemmt")
	for i in 60:
		var pack := CardPack.roll_shop(_rng(i))
		assert_true(CardPack.SIZES.has(pack.size))
		assert_true(DicePack.QUALITIES.has(pack.quality))

func test_quality_is_the_dice_pack_quality() -> void:
	for pack_quality in DicePack.QUALITIES:
		assert_eq(CardPack.quality_luck(pack_quality), DicePack.quality_luck(pack_quality))

func test_one_pack_sort_per_card_sort() -> void:
	assert_eq(CardPack.SORTS.size(), Pack.SHELF_ORDER.size(), "je Kartensorte ein Paket")
	assert_false(CardPack.SORTS.has("mixed"), "kein Misch-Paket mehr")
	for i in 40:
		assert_true(CardPack.SORTS.has(CardPack.roll_shop().sort))

## Die vorderste Karte steht fest und ist IMMER Option 0 - auch nach einem neuen Wurf.
func test_the_front_card_is_always_the_first_option() -> void:
	for pack_sort: String in CardPack.SORTS:
		for seed_value in 20:
			var card_pack := CardPack.make(pack_sort, CardPack.SIZE_NORMAL, DicePack.QUALITY_FINE)
			var shown := card_pack.front_card(0.0, _rng(seed_value))
			assert_eq(card_pack.front_card(), shown, "einmal gewürfelt, dann fest")
			var net := shown.stamp_net.duplicate(true)
			var first := CardPack.roll_contents(card_pack, 0.0, _rng(seed_value + 100))
			var again := CardPack.roll_contents(card_pack, 0.0, _rng(seed_value + 200))
			assert_eq(first[0], shown, "%s: Option 0 ist die sichtbare Karte" % pack_sort)
			assert_eq(again[0], shown, "auch nach Neu mischen")
			assert_eq(shown.stamp_net, net, "und sie bleibt, wie sie ist")
			assert_eq(Pack.shelf_of(shown), CardPackView.stair_shelf(pack_sort), "ihre Sorte")

func test_the_front_card_survives_a_copy_of_the_pack() -> void:
	var card_pack := CardPack.make(CardPack.SORT_RUNE, CardPack.SIZE_SMALL)
	var shown := card_pack.front_card()
	assert_eq((card_pack.duplicate() as CardPack).front_card(), shown, "der Kauf kopiert das Paket")

func test_special_packs_hold_only_special_cards() -> void:
	for seed_value in 40:
		for card in CardPack.roll_contents(CardPack.make(CardPack.SORT_SPECIAL,
				CardPack.SIZE_LARGE, DicePack.QUALITY_ROYAL), 0.3, _rng(seed_value)):
			assert_eq(Pack.shelf_of(card), Pack.SHELF_SPECIAL, "nur Sonderbestand")
	assert_eq(CardPack.make(CardPack.SORT_SPECIAL, 0, DicePack.QUALITY_ROYAL).guaranteed_tier(),
		-1, "Sonder-Karten kennen keine Größe, also keine Garantie")

func test_regular_sorts_hold_only_their_own_cards() -> void:
	var expected := {CardPack.SORT_NUMBER: Pack.TYPE_NUMBER,
		CardPack.SORT_MATERIAL: Pack.TYPE_MATERIAL, CardPack.SORT_RUNE: Pack.TYPE_DICE_MOD}
	for pack_sort: String in expected:
		for seed_value in 30:
			var cards := CardPack.roll_contents(CardPack.make(pack_sort, CardPack.SIZE_LARGE),
				0.0, _rng(seed_value))
			for card in cards:
				assert_eq(card.type, String(expected[pack_sort]), pack_sort)
				assert_false(card.is_catalyst() or card.is_operator(), "keine Sonderware")

func test_fine_and_royal_keep_their_guarantee_among_the_options() -> void:
	for pack_sort: String in [CardPack.SORT_NUMBER, CardPack.SORT_MATERIAL]:
		for seed_value in 60:
			var fine := CardPack.roll_contents(CardPack.make(pack_sort, CardPack.SIZE_SMALL,
				DicePack.QUALITY_FINE), 0.0, _rng(seed_value))
			var royal := CardPack.roll_contents(CardPack.make(pack_sort, CardPack.SIZE_SMALL,
				DicePack.QUALITY_ROYAL), 0.0, _rng(seed_value + 1000))
			assert_true(_max_tier(fine) >= Pack.TIER_GROSS, "Edel: mindestens eine Große")
			assert_true(_max_tier(royal) >= Pack.TIER_KOLOSSAL, "Royal: eine Kolossale")

func test_quality_lifts_the_card_sizes() -> void:
	var sums := [0, 0, 0]
	for pack_quality in DicePack.QUALITIES:
		for seed_value in 150:
			for card in CardPack.roll_contents(CardPack.make(CardPack.SORT_NUMBER,
					CardPack.SIZE_LARGE, pack_quality), 0.0, _rng(seed_value)):
				sums[pack_quality] += card.tier
	assert_gt(sums[1], sums[0], "Edel größer als Standard")
	assert_gt(sums[2], sums[1], "Royal größer als Edel")

func _max_tier(cards: Array[Pack]) -> int:
	var best := -1
	for card in cards:
		best = maxi(best, card.tier)
	return best

func test_never_a_blank() -> void:
	for seed_value in 80:
		var cards := CardPack.roll_contents(CardPack.make(CardPack.SORT_SPECIAL,
			CardPack.SIZE_LARGE), 0.2, _rng(seed_value))
		for card in cards:
			assert_false(card.from_blank(), "nie ein Rohling")

func test_no_duplicate_net_inside_one_pack() -> void:
	for seed_value in 60:
		var cards := CardPack.roll_contents(CardPack.make(CardPack.SORT_RUNE,
			CardPack.SIZE_LARGE, DicePack.QUALITY_ROYAL), 0.0, _rng(seed_value))
		var keys := {}
		for card in cards:
			keys[CardPack.content_key(card)] = true
		assert_eq(keys.size(), cards.size(), "keine Dublette (Seed %d)" % seed_value)

## Der Preis ist die Formel: Preis-Wahlen × Ladenwert einer Option × Auswahl-Prämie.
## Sonder rechnet mit dem Regalpreis der Sonder-Karte.
func test_price_follows_the_formula() -> void:
	for pack_sort: String in CardPack.SORTS:
		for pack_size in CardPack.SIZES:
			for pack_quality in DicePack.QUALITIES:
				var premium := CardPack.CHOICE_PREMIUM + CardPack.OPTION_PREMIUM_STEP \
					* float(CardPack.option_count(pack_size) - 3)
				var expected := float(CardPack.PRICE_PICKS[pack_size][pack_quality]) \
					* _option_value(pack_sort, pack_quality) * premium
				assert_almost_eq(float(CardPack.price_of(pack_sort, pack_size, pack_quality)),
					expected, 1.0, "%s / %d / %d" % [pack_sort, pack_size, pack_quality])

## Der Glückswürfel hat die Preise nicht bewegt (2026-11-21): Zahl für Zahl wie vorher -
## Sorte, dann Kartenzahl 3er/4er/5er, dann Güte Standard/Edel/Royal.
const FROZEN_PRICES := [9, 12, 17, 10, 13, 19, 17, 24, 34, 11, 15, 21, 12, 17, 24, 22, 30, 42,
	13, 18, 25, 15, 20, 29, 26, 36, 51, 25, 30, 38, 28, 34, 43, 51, 61, 76]

func test_prices_stay_frozen() -> void:
	var i := 0
	for pack_sort: String in CardPack.SORTS:
		for pack_size in [CardPack.SIZE_SMALL, CardPack.SIZE_NORMAL, CardPack.SIZE_LARGE]:
			for pack_quality in DicePack.QUALITIES:
				assert_eq(CardPack.price_of(pack_sort, pack_size, pack_quality),
					int(FROZEN_PRICES[i]), "%s / %d / %d" % [pack_sort, pack_size, pack_quality])
				i += 1

func test_more_cards_and_better_quality_cost_more() -> void:
	for pack_sort: String in CardPack.SORTS:
		for pack_quality in DicePack.QUALITIES:
			for pack_size in range(1, CardPack.SIZES.size()):
				assert_true(CardPack.price_of(pack_sort, pack_size - 1, pack_quality)
					< CardPack.price_of(pack_sort, pack_size, pack_quality), "mehr Karten kosten mehr")
		for pack_size in CardPack.SIZES:
			assert_true(CardPack.price_of(pack_sort, pack_size, DicePack.QUALITY_STANDARD)
				< CardPack.price_of(pack_sort, pack_size, DicePack.QUALITY_FINE))
			assert_true(CardPack.price_of(pack_sort, pack_size, DicePack.QUALITY_FINE)
				< CardPack.price_of(pack_sort, pack_size, DicePack.QUALITY_ROYAL))

func _option_value(pack_sort: String, pack_quality: int) -> float:
	var weights: Array = CardPack.QUALITY_TIER_WEIGHTS[pack_quality]
	var tier_factor := 0.0
	for i in weights.size():
		tier_factor += float(weights[i]) * Pack.tier_price_factor(i)
	if pack_sort == CardPack.SORT_SPECIAL:
		return float(Pack.SPECIAL_PRICE) * float(CardPack.SPECIAL_QUALITY_FACTORS[pack_quality])
	return Pack.type_price(String(CardPack.SORT_TYPES[pack_sort])) * tier_factor

func test_names_and_info_never_tell_the_contents() -> void:
	assert_eq(CardPack.make(CardPack.SORT_SPECIAL, CardPack.SIZE_LARGE).display_name,
		"5er Sonder-Paket")
	assert_eq(CardPack.make(CardPack.SORT_MATERIAL, CardPack.SIZE_NORMAL,
		DicePack.QUALITY_FINE).display_name, "4er Material-Paket · Edel")
	var info := CardPack.info_body(CardPack.make(CardPack.SORT_NUMBER, CardPack.SIZE_LARGE,
		DicePack.QUALITY_ROYAL))
	assert_string_contains(info, "5 Optionen")
	assert_string_contains(info, CardPack.DIE_SAYS)
	assert_string_contains(info, "Kolossale")
	assert_string_contains(info, "+12 Glück")

func test_bargain_hunter_works_on_packs() -> void:
	var ids: Array[String] = [Charm.BARGAIN_HUNTER]
	assert_eq(CharmEffects.pack_price(20, "", ids), 14, "30 % weniger")
