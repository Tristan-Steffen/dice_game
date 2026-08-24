extends GutTest
## Tests der Chip-Börsen-Mathematik (ChipStackView): Zuwachs kommt gierig
## gestückelt herein (split_gain), Zahlung folgt dem Zahlplan (payment_plan) -
## möglichst exakt, sonst genau ein Chip zu viel, Rest als Wechselgeld. Zu hohe
## Chip-Stapel werten automatisch in höhere Stückelungen auf (consolidate).

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

func _wallet_value(counts: Dictionary) -> int:
	var total := 0
	for v in counts:
		total += int(v) * int(counts[v])
	return total

# --- consolidate (automatischer color-up ab >3 Türmen) -----------------------

func test_consolidate_leaves_tidy_wallets_untouched() -> void:
	# Alles unter der Grenze (3 Türme = 36 Chips) bleibt, wie es liegt.
	var wallet := {100: 5, 25: 3, 5: 2, 1: 4}
	assert_eq(ChipStackView.consolidate(wallet), wallet, "nichts über der Grenze -> unverändert")

func test_consolidate_colors_up_an_overflowing_denomination() -> void:
	# 37 Einser (>36) werten komplett auf: $37 = 1x$25 + 2x$5 + 2x$1.
	var out := ChipStackView.consolidate({100: 0, 25: 0, 5: 0, 1: 37})
	assert_eq(out, {100: 0, 25: 1, 5: 2, 1: 2})
	assert_lte(out[1], ChipStackView.STACK_LIMIT * ChipStackView.COLUMN_CAP, "Einser wieder unter der Grenze")

func test_consolidate_conserves_total_value() -> void:
	for wallet in [{100: 0, 25: 0, 5: 0, 1: 200}, {100: 1, 25: 50, 5: 40, 1: 41}, {100: 0, 25: 37, 5: 0, 1: 0}]:
		assert_eq(_wallet_value(ChipStackView.consolidate(wallet)), _wallet_value(wallet),
			"color-up erhält den Gesamtwert")

func test_consolidate_colors_up_all_the_way_to_the_top() -> void:
	# 200 Einser werten gierig komplett auf - $200 = 2x$100, nichts bleibt tief.
	var out := ChipStackView.consolidate({100: 0, 25: 0, 5: 0, 1: 200})
	assert_eq(out, {100: 2, 25: 0, 5: 0, 1: 0}, "voller color-up bis zur höchsten Stückelung")

func test_consolidate_never_colors_up_the_top_denomination() -> void:
	# $100 ist die höchste Stufe: auch 50 Türme bleiben Hunderter.
	var out := ChipStackView.consolidate({100: 50, 25: 0, 5: 0, 1: 0})
	assert_eq(int(out[100]), 50, "Hunderter steigen nicht weiter auf")

# --- Das RACK, ohne es zu bauen ----------------------------------------------
# Der Wett-Tresen mißt Sitz und Loch, bevor der Stapel steht - darum ist die
# Rechnung rein und liegt bei den Türmen.

func test_a_pile_has_one_tower_per_denomination_column() -> void:
	assert_eq(ChipStackView.pile_tower_count(0), 0, "nichts ist kein Turm")
	assert_eq(ChipStackView.pile_tower_count(25), 1, "$25 = ein Turm")
	assert_eq(ChipStackView.pile_tower_count(50), 1, "gleiche Stückelung stapelt")
	assert_eq(ChipStackView.pile_tower_count(26), 2, "$25 + $1 = zwei Türme")
	assert_eq(ChipStackView.pile_tower_count(34), 3, "$25 + $5 + 4x$1")

## Ein voller Turm läuft über: mehr als COLUMN_CAP Chips einer Stückelung stehen in
## zwei Spalten.
func test_a_column_overflows_at_its_cap() -> void:
	var over := ChipStackView.COLUMN_CAP + 1
	assert_eq(ChipStackView.pile_tower_count(over), 2,
		"%d x $1 passen nicht in eine Spalte" % over)

## Der Fußabdruck wächst mit den Türmen und schrumpft nie.
func test_the_pile_span_grows_with_its_towers() -> void:
	# Ein Turm ist einen Chip breit - plus seinen dezenten Rack-Versatz.
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

## Der geworfene Einsatz landet als EIN ordentlicher Stapel: das i-te Stück setzt
## genau auf dem schon liegenden auf, ein Chip je Schritt.
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
