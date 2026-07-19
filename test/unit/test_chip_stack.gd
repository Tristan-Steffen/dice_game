extends GutTest
## Tests der Color-Up-Zerlegung (ChipStackView.chip_counts): Stückelungen
## behalten ihre Chips bis zur Kappe, nur der Überschuss wandert in exakten
## Gruppen nach oben (5×$5 → $25, 4×$25 → $100); $100 ist unbegrenzt.

func _total(c: Dictionary) -> int:
	return int(c[1]) + int(c[5]) * 5 + int(c[25]) * 25 + int(c[100]) * 100

func test_small_amount_stays_small_chips() -> void:
	var c := ChipStackView.chip_counts(4)
	assert_eq(int(c[1]), 4)
	assert_eq(int(c[5]), 0)
	assert_eq(int(c[25]), 0)

func test_fives_cap_holds_without_overflow() -> void:
	# $120 = genau die Kappe (24 Fünfer): noch kein Color-Up.
	var c := ChipStackView.chip_counts(120)
	assert_eq(int(c[5]), 24)
	assert_eq(int(c[25]), 0)

func test_overflow_colors_up_in_exact_groups() -> void:
	# $130 = 26 Fünfer > Kappe: EINE Fünfergruppe wird grün.
	var c := ChipStackView.chip_counts(130)
	assert_eq(int(c[5]), 21)
	assert_eq(int(c[25]), 1)

func test_quarters_overflow_into_hundreds() -> void:
	# $1000: Rot und Grün an der Kappe, der Rest sammelt sich schwarz-gold.
	var c := ChipStackView.chip_counts(1000)
	assert_lte(int(c[5]), ChipStackView.FIVES_CAP)
	assert_lte(int(c[25]), ChipStackView.QUARTERS_CAP)
	assert_gt(int(c[100]), 0)

func test_value_is_always_conserved() -> void:
	for amount in [0, 1, 7, 99, 120, 121, 288, 425, 1234]:
		assert_eq(_total(ChipStackView.chip_counts(amount)), maxi(0, amount),
			"Zerlegung von $%d erhält den Betrag" % amount)
