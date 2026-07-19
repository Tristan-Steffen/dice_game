extends GutTest
## Tests der Chip-Börsen-Mathematik (ChipStackView): Zuwachs kommt gierig
## gestückelt herein (split_gain), Zahlung folgt dem Zahlplan (payment_plan) -
## möglichst exakt, sonst genau ein Chip zu viel, Rest als Wechselgeld. Chips
## werden nie zusammengelegt oder geteilt, sobald sie liegen.

func _sum(values: Array) -> int:
	var total := 0
	for v in values:
		total += int(v)
	return total

func _spent_value(spend: Dictionary) -> int:
	var total := 0
	for v in spend:
		total += int(v) * int(spend[v])
	return total

# --- split_gain --------------------------------------------------------------

func test_split_gain_greedy_highest_first() -> void:
	assert_eq(ChipStackView.split_gain(130), [100, 25, 5] as Array[int])
	assert_eq(ChipStackView.split_gain(26), [25, 1] as Array[int])

func test_split_gain_conserves_value() -> void:
	for amount in [0, 1, 4, 5, 99, 100, 288, 1234]:
		assert_eq(_sum(ChipStackView.split_gain(amount)), maxi(0, amount),
			"split_gain($%d) erhält den Betrag" % amount)

# --- payment_plan ------------------------------------------------------------

func test_pays_exactly_when_possible() -> void:
	var plan := ChipStackView.payment_plan({100: 0, 25: 1, 5: 1, 1: 0}, 30)
	assert_eq(_spent_value(plan["spend"]), 30)
	assert_eq(int(plan["change"]), 0)

func test_breaks_a_big_chip_and_returns_change() -> void:
	# Nur ein $100-Chip, Preis $5: den $100 zahlen, $95 Wechselgeld.
	var plan := ChipStackView.payment_plan({100: 1, 25: 0, 5: 0, 1: 0}, 5)
	assert_eq(int(plan["spend"][100]), 1)
	assert_eq(int(plan["change"]), 95)

func test_overpay_is_a_single_extra_chip() -> void:
	# $25 + $1, Preis $6: exakt unmöglich -> den $25 zahlen (nicht $25+$1),
	# $19 Wechselgeld. Der zuerst gegriffene $1 wird wieder einbehalten.
	var plan := ChipStackView.payment_plan({100: 0, 25: 1, 5: 0, 1: 1}, 6)
	assert_eq(int(plan["spend"][25]), 1)
	assert_eq(int(plan["spend"][1]), 0)
	assert_eq(int(plan["change"]), 19)

func test_payment_conserves_value() -> void:
	# Für viele Börsen/Preise: gezahlt - Wechselgeld == Preis, und der Zahlplan
	# überschreitet nie den Bestand.
	var wallet := {100: 1, 25: 2, 5: 3, 1: 4}  # Summe $169
	for price in [1, 5, 6, 24, 26, 30, 77, 100, 169]:
		var plan := ChipStackView.payment_plan(wallet, price)
		assert_eq(_spent_value(plan["spend"]) - int(plan["change"]), price,
			"Zahlung von $%d: gezahlt - Wechselgeld == Preis" % price)
		for v in plan["spend"]:
			assert_lte(int(plan["spend"][v]), int(wallet[v]),
				"$%d: nie mehr Chips zahlen als vorhanden (Wert %d)" % [price, int(v)])

# --- exchange_values (Turm-Umtausch am Schlitz) ------------------------------

func test_exchange_upgrades_full_groups() -> void:
	assert_eq(ChipStackView.exchange_values(5, 5), [25] as Array[int])
	assert_eq(ChipStackView.exchange_values(25, 4), [100] as Array[int])
	# $60 in Fünfern: zwei Grüne entstehen, der Rest kommt als Fünfer zurück.
	assert_eq(ChipStackView.exchange_values(5, 12), [25, 25, 5, 5] as Array[int])

func test_exchange_rejects_pointless_swaps() -> void:
	assert_true(ChipStackView.exchange_values(5, 3).is_empty(), "$15 ergibt keinen höheren Chip")
	assert_true(ChipStackView.exchange_values(1, 4).is_empty(), "$4 ergibt keinen höheren Chip")
	assert_true(ChipStackView.exchange_values(100, 7).is_empty(), "$100 ist schon die höchste Stufe")

func test_overpay_is_minimal() -> void:
	# Kein einzelner gezahlter Chip ist überflüssig: seine Rücknahme würde die
	# Zahlung unter den Preis drücken (minimale Überzahlung).
	var wallet := {100: 1, 25: 2, 5: 3, 1: 4}
	for price in [6, 26, 31, 77, 99]:
		var plan := ChipStackView.payment_plan(wallet, price)
		var paid := _spent_value(plan["spend"])
		for v in plan["spend"]:
			if int(plan["spend"][v]) > 0:
				assert_lt(paid - int(v), price,
					"$%d: der $%d-Chip ist überflüssig" % [price, int(v)])
