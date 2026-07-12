extends GutTest
## Tier-1-Tests der Bogen-Auswürfelung (CouponSheet.generate) - vor allem der
## sortenreinen Packs (allowed_kinds, siehe ShopController.PACKS): ein
## gefilterter Bogen darf ausschließlich Coupons der erlaubten Arten tragen.
## Die Auswürfelung ist zufällig, daher laufen die Filter-Tests über mehrere
## Generationen.

const RUNS := 8  # Generationen je Zufalls-Test

func _real_coupons(sheet: CouponSheet) -> Array[Coupon]:
	var result: Array[Coupon] = []
	for tile in sheet.tiles:
		if tile.kind == CouponSheet.TileKind.ETCHING:
			result.append(tile.coupon)
	return result

func _kinds(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func test_generate_fills_every_cell():
	var sheet := CouponSheet.generate(CouponSheet.Kind.LARGE)
	var covered := 0
	for tile in sheet.tiles:
		covered += tile.w * tile.h
	assert_eq(covered, sheet.cols * sheet.rows, "keine Lücken auf dem Bogen")

func test_generate_places_at_least_one_real_coupon():
	for i in RUNS:
		assert_gt(_real_coupons(CouponSheet.generate(CouponSheet.Kind.SNIPPET)).size(), 0)

func test_all_kinds_have_grid_sizes():
	# Schnipsel 2×2 bis Riesenbogen 9×9 (siehe CouponSheet.Kind).
	assert_eq(CouponSheet.grid_size(CouponSheet.Kind.SNIPPET), Vector2i(2, 2))
	assert_eq(CouponSheet.grid_size(CouponSheet.Kind.SHEET), Vector2i(3, 3))
	assert_eq(CouponSheet.grid_size(CouponSheet.Kind.LARGE), Vector2i(5, 5))
	assert_eq(CouponSheet.grid_size(CouponSheet.Kind.POSTER), Vector2i(7, 7))
	assert_eq(CouponSheet.grid_size(CouponSheet.Kind.JUMBO), Vector2i(9, 9))

func test_jumbo_sheet_fills_completely_with_many_coupons():
	# Der 9×9-Riesenbogen: lückenlos gefüllt und deutlich mehr echte Coupons als
	# die kleinen Bögen (siehe REAL_COUPONS_PER_KIND; einzelne können mangels
	# Platz/Kandidat übersprungen werden, daher > 2 statt == 8).
	for i in RUNS:
		var sheet := CouponSheet.generate(CouponSheet.Kind.JUMBO)
		assert_eq(Vector2i(sheet.cols, sheet.rows), Vector2i(9, 9))
		var covered := 0
		for tile in sheet.tiles:
			covered += tile.w * tile.h
		assert_eq(covered, 81, "auch der Riesenbogen ist lückenlos")
		assert_gt(sheet.etching_count(), 2, "Riesenbogen trägt mehr echte Coupons")

func test_meal_filter_yields_only_meals():
	for i in RUNS:
		var sheet := CouponSheet.generate(CouponSheet.Kind.LARGE, _kinds([Coupon.KIND_MEAL]))
		var coupons := _real_coupons(sheet)
		assert_gt(coupons.size(), 0, "auch gefiltert liegen echte Coupons auf dem Bogen")
		for coupon in coupons:
			assert_eq(coupon.kind, Coupon.KIND_MEAL, "%s ist kein Gericht" % coupon.id)

func test_modifier_filter_yields_only_materials_and_edges():
	for i in RUNS:
		var sheet := CouponSheet.generate(CouponSheet.Kind.LARGE, _kinds([Coupon.KIND_MATERIAL, Coupon.KIND_EDGE]))
		for coupon in _real_coupons(sheet):
			assert_true(coupon.kind in [Coupon.KIND_MATERIAL, Coupon.KIND_EDGE],
				"%s ist keine Veredelung" % coupon.id)

func test_etching_filter_works_on_the_smallest_sheet():
	# Auch der 2×2-Schnipsel findet gefiltert passende (kleine) Ätzungen.
	for i in RUNS:
		var sheet := CouponSheet.generate(CouponSheet.Kind.SNIPPET, _kinds([Coupon.KIND_ETCHING]))
		var coupons := _real_coupons(sheet)
		assert_gt(coupons.size(), 0)
		for coupon in coupons:
			assert_eq(coupon.kind, Coupon.KIND_ETCHING)
			assert_true(coupon.width <= 2 and coupon.height <= 2, "passt auf den Schnipsel")

func test_extra_size_grows_the_grid_and_stays_filled():
	# Großformat-Charm (siehe GameRun.buy_coupon_sheet): Raster +1 je Richtung.
	var sheet := CouponSheet.generate(CouponSheet.Kind.SNIPPET, _kinds([]), 1)
	assert_eq(Vector2i(sheet.cols, sheet.rows), Vector2i(3, 3))
	var covered := 0
	for tile in sheet.tiles:
		covered += tile.w * tile.h
	assert_eq(covered, 9, "auch das vergrößerte Raster ist lückenlos")

func test_money_tiles_are_capped_by_the_kind_budget():
	# Geld-Marken sind je Bogentyp fest gedeckelt (siehe CHIP_TILES_PER_KIND) -
	# auch der Riesenbogen zahlt nur wenige Chips zurück, egal wie viel Fläche
	# frei bleibt. Beim Riesenbogen ist immer genug Platz frei, dort ist das
	# Budget exakt ausgeschöpft.
	for i in RUNS:
		for kind in [CouponSheet.Kind.SNIPPET, CouponSheet.Kind.LARGE, CouponSheet.Kind.JUMBO]:
			var sheet := CouponSheet.generate(kind)
			var money := 0
			for tile in sheet.tiles:
				if tile.kind == CouponSheet.TileKind.MONEY:
					money += 1
			var budget: int = CouponSheet.CHIP_TILES_PER_KIND[kind]
			assert_true(money <= budget, "höchstens %d Geld-Marken (Bogentyp %d)" % [budget, kind])
			if kind == CouponSheet.Kind.JUMBO:
				assert_eq(money, budget, "Riesenbogen schöpft sein Budget aus")

func test_no_ads_turns_fillers_into_chip_coupons():
	# Hausmarke-Charm: Werbeflächen werden zu Chip-Coupons.
	for i in RUNS:
		var sheet := CouponSheet.generate(CouponSheet.Kind.LARGE, _kinds([]), 0, true)
		for tile in sheet.tiles:
			assert_ne(tile.kind, CouponSheet.TileKind.AD, "keine Werbefläche mit no_ads")

func test_empty_filter_means_all_kinds():
	# Ohne Filter tauchen über genug Generationen mehrere Arten auf (gemischt).
	var seen := {}
	for i in 40:
		for coupon in _real_coupons(CouponSheet.generate(CouponSheet.Kind.LARGE)):
			seen[coupon.kind] = true
	assert_gt(seen.size(), 1, "gemischtes Heft zieht aus mehreren Arten")
