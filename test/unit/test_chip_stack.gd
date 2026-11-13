extends GutTest
## Die Stückelungen und der Stapel-Körper (ChipStackView): bodenschwere Zerlegung
## für Gewinn-Stapel und Kometen-Pakete, die Rack-Rechnung, die Inlay-Ziffern. Die
## Börse selbst ist das Chip-Tray (test_chip_tray.gd).

func _sum(values: Array) -> int:
	var total := 0
	for v in values:
		total += int(v)
	return total

# --- Die Leiter ----------------------------------------------------------------

func test_the_ladder_has_seven_steps_up_to_ten_thousand() -> void:
	assert_eq(ChipStackView.VALUES, [10000, 2500, 500, 100, 25, 5, 1])
	assert_eq(ChipStackView.DENOMINATIONS.size(), ChipStackView.VALUES.size(),
		"jede Stufe hat ihre Farbe")
	var seen := {}
	for value: int in ChipStackView.VALUES:
		var color := ChipStackView.denomination_color(value)
		assert_ne(color, Color.WHITE, "$%d hat eine eigene Farbe" % value)
		assert_false(seen.has(color), "$%d teilt seine Farbe mit keinem" % value)
		seen[color] = true
	# Das Tray liest dieselbe Leiter, nur von unten nach oben.
	var up: Array = ChipStackView.VALUES.duplicate()
	up.reverse()
	for i in up.size():
		assert_eq(int(up[i]), ChipTrayView.VALUES[i], "Stufe %d" % i)

func test_big_values_read_short_on_the_inlay() -> void:
	assert_eq(ChipStackView.value_label(1), "1")
	assert_eq(ChipStackView.value_label(500), "500")
	assert_eq(ChipStackView.value_label(2500), "2,5K")
	assert_eq(ChipStackView.value_label(10000), "10K")

# --- split_gain / split_greedy -------------------------------------------------

func test_split_gain_greedy_highest_first() -> void:
	assert_eq(ChipStackView.split_gain(130), [100, 25, 5] as Array[int])
	assert_eq(ChipStackView.split_gain(26), [25, 1] as Array[int])
	assert_eq(ChipStackView.split_gain(13000), [10000, 2500, 500] as Array[int])

func test_split_gain_conserves_value() -> void:
	for amount in [0, 1, 4, 5, 99, 100, 288, 1234, 27_777]:
		assert_eq(_sum(ChipStackView.split_gain(amount)), maxi(0, amount),
			"split_gain($%d) erhält den Betrag" % amount)

func test_split_greedy_is_the_fewest_chips() -> void:
	assert_eq(ChipStackView.split_greedy(3687),
		[2500, 500, 500, 100, 25, 25, 25, 5, 5, 1, 1] as Array[int])
	assert_eq(_sum(ChipStackView.split_greedy(98_765)), 98_765)

# --- Das RACK, ohne es zu bauen ----------------------------------------------

func test_a_pile_has_one_tower_per_denomination_column() -> void:
	assert_eq(ChipStackView.pile_tower_count(0), 0, "nichts ist kein Turm")
	assert_eq(ChipStackView.pile_tower_count(25), 1, "$25 = ein Turm")
	assert_eq(ChipStackView.pile_tower_count(50), 1, "gleiche Stückelung stapelt")
	assert_eq(ChipStackView.pile_tower_count(26), 2, "$25 + $1 = zwei Türme")
	assert_eq(ChipStackView.pile_tower_count(34), 3, "$25 + $5 + 4x$1")

func test_a_column_overflows_at_its_cap() -> void:
	var over := ChipStackView.COLUMN_CAP + 1
	assert_eq(ChipStackView.pile_tower_count(over), 2,
		"%d x $1 passen nicht in eine Spalte" % over)

func test_the_pile_span_grows_with_its_towers() -> void:
	var one := ChipStackView.pile_span(25)
	var chip := ChipStackView.CHIP_RADIUS * 2.0
	var jitter := ChipStackView.COLUMN_JITTER
	assert_almost_eq(one.x, chip + jitter, jitter, "ein Turm ist einen Chip breit")
	assert_almost_eq(one.y, chip + jitter, jitter)
	var last := 0.0
	for amount in [25, 26, 34, 64]:
		var span := ChipStackView.pile_span(amount)
		assert_gte(span.y, last - 0.0001, "$%d wird nie schmaler" % amount)
		last = span.y

func test_a_thrown_salvo_stacks_chip_on_chip() -> void:
	assert_almost_eq(ChipStackView.stack_lift(0), 0.0, 0.0001,
		"das erste Stück liegt auf der Fläche")
	var last := ChipStackView.stack_lift(0)
	for i in range(1, 8):
		var lift := ChipStackView.stack_lift(i)
		assert_almost_eq(lift - last, ChipStackView.CHIP_HEIGHT, 0.0001,
			"Stück %d sitzt genau eine Chiphöhe über seinem Vorgänger" % i)
		last = lift
	assert_almost_eq(ChipStackView.stack_lift(-3), 0.0, 0.0001,
		"ein unsinniger Index stapelt nicht nach unten")

func test_the_dead_wallet_is_gone() -> void:
	var source: String = load("res://scripts/table/chip_stack_view.gd").source_code
	for dead in ["payment_plan", "consolidate", "exchange_values", "mint_chip",
			"seed_wallet", "_wallet"]:
		assert_false(source.contains(dead), "%s ist mit der Börse gestorben" % dead)
