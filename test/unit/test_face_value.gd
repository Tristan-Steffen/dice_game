extends GutTest

func test_small_values_stay_exact() -> void:
	for value in [0, 6, 42, 999]:
		assert_false(FaceValue.is_big(value))
		assert_eq(FaceValue.main_text(value), str(value))
		assert_eq(FaceValue.magnitude(value), "")
		assert_eq(FaceValue.inline(value), str(value))

func test_from_four_digits_the_combination_digit_leads() -> void:
	assert_true(FaceValue.is_big(1000))
	assert_eq(FaceValue.main_text(1004), "4")
	assert_eq(FaceValue.main_text(1_000_006), "6")
	assert_eq(FaceValue.digit(12547), DiceScoring._digit(12547), "dieselbe Ziffer wie die Wertung")

func test_magnitude_keeps_three_digits_and_rounds_down() -> void:
	assert_eq(FaceValue.magnitude(1004), "1.00k")
	assert_eq(FaceValue.magnitude(9999), "9.99k", "abgerundet, nie 10.0k")
	assert_eq(FaceValue.magnitude(12547), "12.5k")
	assert_eq(FaceValue.magnitude(148000), "148k")
	assert_eq(FaceValue.magnitude(2_300_000), "2.30M")
	assert_eq(FaceValue.magnitude(-1500), "-1.50k")

func test_inline_joins_both_parts() -> void:
	assert_eq(FaceValue.inline(1_000_004), "1.00M·4")
