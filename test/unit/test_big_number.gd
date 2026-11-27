extends GutTest
## BigNumber: die Grenzen des Zahlenformats.

func test_small_numbers_stand_in_full_with_a_thousands_dot() -> void:
	assert_eq(BigNumber.short(0), "0")
	assert_eq(BigNumber.short(999), "999")
	assert_eq(BigNumber.short(1000), "1.000")
	assert_eq(BigNumber.short(12345), "12.345")
	assert_eq(BigNumber.short(99999), "99.999")
	assert_eq(BigNumber.short(-4500), "-4.500")

func test_from_a_hundred_thousand_on_it_shortens() -> void:
	assert_eq(BigNumber.short(99999.6), "100 Tsd", "aufgerundet zählt die Grenze")
	assert_eq(BigNumber.short(100000), "100 Tsd")
	assert_eq(BigNumber.short(123456), "123 Tsd")
	assert_eq(BigNumber.short(999999), "1 Mio", "999,999 Tsd rundet in die nächste Einheit")
	assert_eq(BigNumber.short(1234567), "1,2 Mio")
	assert_eq(BigNumber.short(2000000), "2 Mio", "die ,0 entfällt")
	assert_eq(BigNumber.short(3.4e9), "3,4 Mrd")
	assert_eq(BigNumber.short(5.6e12), "5,6 Bio")
	assert_eq(BigNumber.short(456.7e12), "457 Bio")

func test_beyond_billions_it_writes_a_power_of_ten() -> void:
	assert_eq(BigNumber.short(1.2e15), "1,2e15")
	assert_eq(BigNumber.short(999.9e12), "1e15")
	assert_eq(BigNumber.short(9.96e20), "1e21")

func test_factors_have_one_decimal() -> void:
	assert_eq(BigNumber.factor(3.6), "×3,6")
	assert_eq(BigNumber.factor(3.64), "×3,6")
	assert_eq(BigNumber.factor(2.0), "×2", "die ,0 entfällt")
	assert_eq(BigNumber.factor(0.84), "×0,8")
	assert_eq(BigNumber.factor(1.318, 2), "×1,32")
	assert_eq(BigNumber.factor(99.97), "×100")
	assert_eq(BigNumber.factor(1234.4), "×1.234")
	assert_eq(BigNumber.factor(250000), "×250 Tsd")
