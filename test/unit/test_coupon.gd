extends GutTest
## Tier-1-Tests des Coupon-Datensatzes (die Bogen-Auswürfelung testet
## CouponSheet, siehe scripts/coupon_sheet.gd).

func test_all_returns_thirteen_etchings():
	assert_eq(Coupon.all().size(), 13)

func test_all_ids_are_unique():
	var seen := {}
	for coupon in Coupon.all():
		assert_false(seen.has(coupon.id), "doppelte id: %s" % coupon.id)
		seen[coupon.id] = true

func test_every_coupon_has_filled_metadata():
	for coupon in Coupon.all():
		assert_ne(coupon.id, "", "id fehlt")
		assert_ne(coupon.display_name, "", "display_name fehlt bei %s" % coupon.id)
		assert_ne(coupon.description, "", "description fehlt bei %s" % coupon.id)
		assert_eq(coupon.kind, Coupon.KIND_ETCHING, "aktuell sind alle Coupons Ätzungen")

func test_factory_id_matches_constant():
	assert_eq(Coupon.chisel().id, Coupon.CHISEL)
	assert_eq(Coupon.overcount_engraving().id, Coupon.OVERCOUNT_ENGRAVING)
	assert_eq(Coupon.file_down().id, Coupon.FILE_DOWN)
	assert_eq(Coupon.blueprint().id, Coupon.BLUEPRINT)

func test_rarities_match_the_spec():
	assert_eq(Coupon.chisel().rarity, Coupon.Rarity.COMMON)
	assert_eq(Coupon.transplant().rarity, Coupon.Rarity.COMMON)
	assert_eq(Coupon.grindstone().rarity, Coupon.Rarity.COMMON)
	assert_eq(Coupon.fine_engraving().rarity, Coupon.Rarity.UNCOMMON)
	assert_eq(Coupon.overcount_engraving().rarity, Coupon.Rarity.RARE)
	assert_eq(Coupon.file_down().rarity, Coupon.Rarity.COMMON)
	assert_eq(Coupon.double_notch().rarity, Coupon.Rarity.COMMON)
	assert_eq(Coupon.averaging().rarity, Coupon.Rarity.UNCOMMON)
	assert_eq(Coupon.blueprint().rarity, Coupon.Rarity.RARE)

func test_rarity_name_is_german():
	assert_eq(Coupon.rarity_name(Coupon.Rarity.COMMON), "häufig")
	assert_eq(Coupon.rarity_name(Coupon.Rarity.UNCOMMON), "ungewöhnlich")
	assert_eq(Coupon.rarity_name(Coupon.Rarity.RARE), "selten")
