extends GutTest
## Tier-1-Tests des Coupon-Datensatzes und der Pack-Auswürfelung.

func test_all_returns_five_etchings():
	assert_eq(Coupon.all().size(), 5)

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

func test_rarities_match_the_spec():
	assert_eq(Coupon.chisel().rarity, Coupon.Rarity.COMMON)
	assert_eq(Coupon.transplant().rarity, Coupon.Rarity.COMMON)
	assert_eq(Coupon.grindstone().rarity, Coupon.Rarity.COMMON)
	assert_eq(Coupon.fine_engraving().rarity, Coupon.Rarity.UNCOMMON)
	assert_eq(Coupon.overcount_engraving().rarity, Coupon.Rarity.RARE)

func test_rarity_name_is_german():
	assert_eq(Coupon.rarity_name(Coupon.Rarity.COMMON), "häufig")
	assert_eq(Coupon.rarity_name(Coupon.Rarity.UNCOMMON), "ungewöhnlich")
	assert_eq(Coupon.rarity_name(Coupon.Rarity.RARE), "selten")

# --- Pack-Auswürfelung -------------------------------------------------------

func test_pack_has_requested_size():
	assert_eq(Coupon.random_etching_pack(3).size(), 3)
	assert_eq(Coupon.random_etching_pack(1).size(), 1)

func test_pack_only_contains_known_etchings():
	var valid_ids := {}
	for coupon in Coupon.all():
		valid_ids[coupon.id] = true
	for coupon in Coupon.random_etching_pack(20):
		assert_true(valid_ids.has(coupon.id), "unbekannte id im Pack: %s" % coupon.id)

func test_pack_entries_are_independent_instances():
	# Zwei gleiche Coupons im Pack dürfen nicht dieselbe Instanz sein
	# (Coupons sind verbrauchbar).
	var pack := Coupon.random_etching_pack(6)
	for i in pack.size():
		for j in range(i + 1, pack.size()):
			assert_ne(pack[i].get_instance_id(), pack[j].get_instance_id())
