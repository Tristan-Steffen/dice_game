extends GutTest
## Die Rechnung des Chip-Trays (ChipTrayView): die Belegung ist eine Funktion des
## Geldes, und jeder Übergang ist eine Schrittliste, die exakt auf der neuen
## Belegung endet - ohne daß eine Rinne je mehr trägt als ihr Verhältnis.

func _counts(values: Array) -> Array[int]:
	var out: Array[int] = []
	out.assign(values)
	return out

## Faltet die Schritte nach und hält dabei die Rinnen im Zaum.
func _walk(old: int, new: int) -> Array[Dictionary]:
	var from := ChipTrayView.belegung(old)
	var steps := ChipTrayView.transition(from, ChipTrayView.belegung(new))
	var counts := from
	for step: Dictionary in steps:
		counts = ChipTrayView.apply_step(counts, step)
		for r in ChipTrayView.TOP:
			assert_lte(counts[r], ChipTrayView.ratio(r),
				"%d -> %d: Rinne %d trägt nie mehr als ihr Verhältnis" % [old, new, r])
			assert_gte(counts[r], 0, "%d -> %d: Rinne %d nie negativ" % [old, new, r])
	assert_eq(counts, ChipTrayView.belegung(new), "%d -> %d endet auf der Belegung" % [old, new])
	return steps

func _kinds(steps: Array[Dictionary]) -> Array:
	var out: Array = []
	for step in steps:
		out.append(String(step["kind"]))
	return out

func test_the_ladder_goes_up_to_ten_thousand() -> void:
	assert_eq(ChipTrayView.VALUES.size(), 7, "sieben Rinnen")
	assert_eq(ChipTrayView.VALUES[0], 1, "die 1er liegen unten")
	assert_eq(ChipTrayView.VALUES[ChipTrayView.TOP], 10000)
	for r in ChipTrayView.TOP:
		assert_eq(ChipTrayView.VALUES[r] * ChipTrayView.ratio(r), ChipTrayView.VALUES[r + 1],
			"Rinne %d trägt genau ihr Verhältnis bis zur nächsten" % r)

func test_the_belegung_is_canonical() -> void:
	assert_eq(ChipTrayView.belegung(0), _counts([0, 0, 0, 0, 0, 0, 0]))
	assert_eq(ChipTrayView.belegung(3687), _counts([2, 2, 3, 1, 2, 1, 0]))
	assert_eq(ChipTrayView.belegung(99), _counts([4, 4, 3, 0, 0, 0, 0]))
	for money in [1, 4, 5, 24, 99, 100, 2499, 9999, 12_345, 99_999]:
		var counts := ChipTrayView.belegung(money)
		assert_eq(ChipTrayView.total(counts), money, "$%d bleibt $%d" % [money, money])
		for r in ChipTrayView.TOP:
			assert_lt(counts[r], ChipTrayView.ratio(r), "$%d: Rinne %d unter dem Verhältnis" % [money, r])

func test_a_carry_cascades_up_to_the_hundred() -> void:
	# 4·1 + 4·5 + 3·25 = 99, ein Dollar dazu: alles rutscht, ein 100er kommt.
	var steps := _walk(99, 100)
	assert_eq(_kinds(steps), [ChipTrayView.STEP_IN, ChipTrayView.STEP_CARRY,
		ChipTrayView.STEP_CARRY, ChipTrayView.STEP_CARRY])
	assert_eq(int(steps[0]["rank"]), 0, "der Dollar läuft unten ein")
	assert_eq(int(steps[3]["rank"]), 2, "der letzte Übertrag kommt aus den 25ern")
	assert_true(bool(steps[0]["comet"]), "ein Gewinn kommt als Komet")

func test_a_gain_never_overfills_a_groove() -> void:
	# 4 Einer liegen, 9 kommen: der fünfte trägt über, bevor der Rest einläuft.
	var steps := _walk(4, 13)
	assert_eq(_kinds(steps), [ChipTrayView.STEP_IN, ChipTrayView.STEP_CARRY,
		ChipTrayView.STEP_IN, ChipTrayView.STEP_IN])
	for money in [0, 3, 99, 3687, 9999]:
		for gain in [1, 4, 7, 26, 124, 2501, 13_333]:
			_walk(money, money + gain)

func test_borrowing_reaches_across_several_grooves() -> void:
	# Ein 10.000er zahlt 10: er rutscht in den Tisch, darunter kommt Wechselgeld.
	var steps := _walk(10_000, 9990)
	assert_eq(_kinds(steps), [ChipTrayView.STEP_BORROW, ChipTrayView.STEP_OUT])
	assert_eq(int(steps[0]["rank"]), ChipTrayView.TOP, "geborgt wird beim 10.000er")
	assert_eq(int(steps[0]["to"]), 1, "bis hinunter zu den 5ern")
	assert_eq(int(steps[1]["count"]), 2, "zwei 5er gehen als Zahlung")
	assert_true(bool(steps[1]["pay"]))

func test_a_payment_pays_what_lies_then_borrows() -> void:
	# $6 (5 + 1) zahlen $3: der Einer geht, der Fünfer wird gewechselt, zwei Einer folgen.
	var steps := _walk(6, 3)
	assert_eq(_kinds(steps), [ChipTrayView.STEP_OUT, ChipTrayView.STEP_BORROW,
		ChipTrayView.STEP_OUT])
	for money in [3, 100, 3687, 10_000, 26_000]:
		for price in [1, 3, 10, 99, 101, 2499]:
			if price <= money:
				_walk(money, money - price)

func test_the_tens_of_thousands_overflow_into_layers() -> void:
	var counts := ChipTrayView.belegung(73_000)
	assert_eq(counts[ChipTrayView.TOP], 7, "die 10.000er haben keine Grenze")
	assert_eq(ChipTrayView.shown_cap(ChipTrayView.TOP),
		ChipTrayView.SLOTS * 2 - 1, "die zweite Lage endet vor dem Einlauf")
	assert_eq(ChipTrayView.shown_cap(0), ChipTrayView.SLOTS)
	_walk(73_000, 140_000)
	_walk(140_000, 3)

func test_a_still_amount_has_no_steps() -> void:
	assert_true(ChipTrayView.transition(ChipTrayView.belegung(77),
		ChipTrayView.belegung(77)).is_empty())

func test_a_quiet_gain_carries_no_comet() -> void:
	var steps := ChipTrayView.transition(ChipTrayView.belegung(0),
		ChipTrayView.belegung(6), false)
	for step in steps:
		assert_false(bool(step.get("comet", false)), "unterdrückt läuft kein Komet")
