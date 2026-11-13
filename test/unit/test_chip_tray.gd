extends GutTest
## Die Rechnung des Chip-Trays (ChipTrayView): die Belegung ist eine Funktion des
## Geldes - von unten gefüllt, jede Rinne bis CAP -, und jeder Übergang ist eine
## Schrittliste, die exakt auf der neuen Belegung endet.

func _counts(values: Array) -> Array[int]:
	var out: Array[int] = []
	out.assign(values)
	return out

## Faltet die Schritte nach und hält dabei die Rinnen im sichtbaren Raum.
func _walk(old: int, new: int) -> Array[Dictionary]:
	var from := ChipTrayView.belegung(old)
	var steps := ChipTrayView.transition(from, ChipTrayView.belegung(new))
	var counts := from
	for step: Dictionary in steps:
		counts = ChipTrayView.apply_step(counts, step)
		for r in ChipTrayView.TOP:
			assert_lte(counts[r], ChipTrayView.TOP_SHOWN,
				"%d -> %d: Rinne %d bleibt im sichtbaren Raum" % [old, new, r])
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

func test_the_belegung_fills_from_below() -> void:
	assert_eq(ChipTrayView.belegung(0), _counts([0, 0, 0, 0, 0, 0, 0]))
	assert_eq(ChipTrayView.belegung(20), _counts([20, 0, 0, 0, 0, 0, 0]), "20 Einer passen")
	assert_eq(ChipTrayView.belegung(21), _counts([16, 1, 0, 0, 0, 0, 0]), "der 21. tauscht")
	assert_eq(ChipTrayView.belegung(99), _counts([19, 16, 0, 0, 0, 0, 0]))
	assert_eq(ChipTrayView.belegung(3687), _counts([17, 19, 19, 16, 3, 0, 0]))
	for money in [1, 4, 5, 24, 99, 100, 2499, 9999, 12_345, 99_999, 1_000_000]:
		var counts := ChipTrayView.belegung(money)
		assert_eq(ChipTrayView.total(counts), money, "$%d bleibt $%d" % [money, money])
		for r in ChipTrayView.TOP:
			assert_lte(counts[r], ChipTrayView.CAP, "$%d: Rinne %d höchstens CAP" % [money, r])
			if counts[r] + ChipTrayView.ratio(r) <= ChipTrayView.CAP:
				for up in range(r + 1, ChipTrayView.VALUES.size()):
					assert_eq(counts[up], 0, "$%d: über einer nicht vollen Rinne liegt nichts" % money)

func test_a_full_groove_exchanges_and_cascades() -> void:
	# 20 Einer und 20 Fünfer liegen, ein Dollar dazu: beide Rinnen tauschen.
	var steps := _walk(120, 121)
	assert_eq(_kinds(steps), [ChipTrayView.STEP_IN, ChipTrayView.STEP_CARRY,
		ChipTrayView.STEP_CARRY])
	assert_eq(int(steps[0]["rank"]), 0, "der Dollar läuft unten ein")
	assert_eq(int(steps[2]["rank"]), 1, "dann tauschen die Fünfer")
	assert_true(bool(steps[0]["comet"]), "ein Gewinn kommt als Komet")
	assert_eq(_kinds(_walk(20, 21)), [ChipTrayView.STEP_IN, ChipTrayView.STEP_CARRY])

func test_gains_end_on_the_belegung() -> void:
	for money in [0, 3, 20, 99, 3687, 9999]:
		for gain in [1, 4, 7, 26, 124, 2501, 13_333]:
			_walk(money, money + gain)

func test_borrowing_reaches_across_several_grooves() -> void:
	# $10.000 zahlen $10: die Fünfer gehen, darüber wird gewechselt, bis alles stimmt.
	var steps := _walk(10_000, 9990)
	assert_has(_kinds(steps), ChipTrayView.STEP_BORROW, "es wird gewechselt")
	var paid := 0
	for step in steps:
		if String(step["kind"]) == ChipTrayView.STEP_OUT:
			assert_true(bool(step["pay"]))
			paid += int(step["count"]) * ChipTrayView.VALUES[int(step["rank"])]
	assert_eq(paid, 10, "gezahlt wird genau der Preis")

func test_a_payment_pays_with_what_lies() -> void:
	assert_eq(_kinds(_walk(6, 3)), [ChipTrayView.STEP_OUT], "drei Einer gehen, sonst nichts")
	# 16 Einer und ein Fünfer zahlen 3: die Einer gehen, der Fünfer füllt die Rinne auf.
	assert_eq(_kinds(_walk(21, 18)), [ChipTrayView.STEP_OUT, ChipTrayView.STEP_BORROW])
	for money in [3, 100, 3687, 10_000, 26_000]:
		for price in [1, 3, 10, 99, 101, 2499]:
			if price <= money:
				_walk(money, money - price)

func test_the_tens_of_thousands_have_no_cap() -> void:
	assert_gt(ChipTrayView.belegung(1_000_000)[ChipTrayView.TOP], ChipTrayView.CAP)
	assert_eq(ChipTrayView.shown_cap(ChipTrayView.TOP), ChipTrayView.TOP_SHOWN)
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
