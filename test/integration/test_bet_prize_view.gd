extends GutTest
## Die Körper des Wett-Tresens (BetPrizeView): Chip-Stapel, Elko-Feld, geprägte
## Marke und Zählplatte. Sie sind reine ANZEIGE - hier wird geprüft, dass sie sich
## bauen, auf ihren Platz passen und der Griff sie hebt.

func _prize() -> BetPrizeView:
	var prize := BetPrizeView.new()
	add_child_autofree(prize)
	return prize

func test_chips_build_real_denominations():
	var prize := _prize()
	prize.setup_chips(26)
	assert_eq(prize.kind, BetPrizeView.KIND_CHIPS)
	# 26 = 25 + 1: zwei Türme, also zwei Stückelungen im Rack.
	var stack: ChipStackView = prize.get_node("Body/Chips")
	assert_eq(stack.wallet_total(), 26, "die Börse trägt genau den Preis")

func test_charge_builds_one_elko_per_point():
	var prize := _prize()
	prize.setup_charge(6)
	assert_eq(prize.kind, BetPrizeView.KIND_CHARGE)
	var body: Node3D = prize.get_node("Body")
	assert_eq(body.get_child_count(), 6, "sechs Dosen für sechs Energie")

func test_charge_caps_its_field():
	var prize := _prize()
	prize.setup_charge(999)
	var body: Node3D = prize.get_node("Body")
	assert_eq(body.get_child_count(), BetPrizeView.ELKO_CAP,
		"mehr als ELKO_CAP zeigt der Tresen nicht - die Zahl steht auf dem Knopf")

func test_token_carries_its_engraving():
	var prize := _prize()
	prize.setup_token("LVL+1", CasinoStyle.GOLD_INTENSE)
	assert_eq(prize.kind, BetPrizeView.KIND_TOKEN)
	var label: Label3D = prize.get_node("Body/Aufschrift")
	assert_eq(label.text, "LVL+1")

func test_tally_starts_empty_and_grows_per_booking():
	var prize := _prize()
	prize.setup_tally()
	assert_eq(prize.tally_total(), 0, "vor der ersten Hand liegt nichts auf der Platte")
	prize.add_tally(3)
	assert_eq(prize.tally_total(), 3)
	prize.add_tally(3)
	assert_eq(prize.tally_total(), 6, "jede Buchung legt nach")

func test_tally_of_a_body_that_is_not_one_stays_silent():
	var prize := _prize()
	prize.setup_token("PRESSE", CasinoStyle.GOLD_INTENSE)
	prize.add_tally(5)
	assert_eq(prize.tally_total(), 0, "eine Marke zählt nichts")

## Nichts schrumpft mehr auf seinen Platz: jeder Körper liegt in ECHTER Größe da und
## meldet sie, damit der Schacht an IHM messen kann.
func test_every_build_reports_its_real_size():
	for build in ["chips", "charge", "token", "tally"]:
		var prize := _prize()
		match build:
			"chips":
				prize.setup_chips(180)
			"charge":
				prize.setup_charge(12)
			"token":
				prize.setup_token("LVL+1", CasinoStyle.GOLD_INTENSE)
			"tally":
				prize.setup_tally()
		assert_gt(prize.natural_span().x, 0.0, "%s meldet seine Tiefe" % build)
		assert_gt(prize.natural_span().y, 0.0, "%s meldet seine Breite" % build)
		assert_gt(prize.body_height(), BetPrizeView.FLOOR_CLEAR,
			"%s steht über der Fläche" % build)
		var body: Node3D = prize.get_node("Body")
		assert_almost_eq(body.scale.x, 1.0, 0.0001,
			"%s wird nicht kleingerechnet" % build)

## Ein großer Einsatz liegt BREIT, statt zu schrumpfen (die Schatz-Grammatik).
func test_a_bigger_stake_grows_instead_of_shrinking():
	var small := _prize()
	small.setup_chips(5)
	var whale := _prize()
	whale.setup_chips(25)
	var wide := whale.natural_span().x >= small.natural_span().x - 0.0001
	var deep := whale.natural_span().y >= small.natural_span().y - 0.0001
	assert_true(wide and deep, "der größere Einsatz wird nie kleiner")

func test_seat_hard_keeps_the_origin_on_the_glass_point():
	var prize := _prize()
	prize.setup_token("LVL+1", CasinoStyle.GOLD_INTENSE)
	var at := Vector3(3.0, 0.0, -2.0)
	prize.seat_hard(at)
	assert_almost_eq(prize.global_position.x, at.x, 0.0001)
	assert_almost_eq(prize.global_position.y, at.y, 0.0001)
	assert_almost_eq(prize.global_position.z, at.z, 0.0001)

func test_body_rests_clear_of_the_display():
	var prize := _prize()
	prize.setup_tally()
	var body: Node3D = prize.get_node("Body")
	assert_almost_eq(body.position.y, BetPrizeView.FLOOR_CLEAR, 0.0001,
		"der Körper steht FLOOR_CLEAR über der Anzeige")

func test_hover_lifts_the_body_and_lets_it_down():
	var prize := _prize()
	prize.setup_chips(10)
	var body: Node3D = prize.get_node("Body")
	prize.set_hovered(true)
	assert_true(prize.hovered())
	await wait_seconds(BetPrizeView.HOVER_TIME + 0.05)
	assert_gt(body.position.y, BetPrizeView.FLOOR_CLEAR + 0.001, "der Griff hebt")
	prize.set_hovered(false)
	await wait_seconds(BetPrizeView.HOVER_TIME + 0.05)
	assert_almost_eq(body.position.y, BetPrizeView.FLOOR_CLEAR, 0.001,
		"und läßt wieder ab")

# --- Der Fußabdruck OHNE Körper -------------------------------------------------
# Sitz und Loch werden gemessen, bevor der Körper steht. Also gibt es EINE Rechnung,
# und der gebaute Körper meldet genau sie - sonst säße er nicht, wo das Loch ist.

func test_the_static_span_is_the_one_the_body_reports():
	for amount in [1, 4, 6, 18, 26, 34, 64, 90, 180, 400]:
		var prize := _prize()
		prize.setup_chips(amount)
		assert_true(prize.natural_span().is_equal_approx(
			BetPrizeView.span_for(BetPrizeView.KIND_CHIPS, amount)),
			"Chip-Stapel %d: gemeldet wie gerechnet" % amount)
	for count in [1, 3, 4, 8, 12, 16, 99]:
		var prize := _prize()
		prize.setup_charge(count)
		assert_true(prize.natural_span().is_equal_approx(
			BetPrizeView.span_for(BetPrizeView.KIND_CHARGE, count)),
			"Elko-Feld %d: gemeldet wie gerechnet" % count)
	var token := _prize()
	token.setup_token("LVL+1", CasinoStyle.GOLD_INTENSE)
	assert_true(token.natural_span().is_equal_approx(
		BetPrizeView.span_for(BetPrizeView.KIND_TOKEN)))
	var tally := _prize()
	tally.setup_tally()
	assert_true(tally.natural_span().is_equal_approx(
		BetPrizeView.span_for(BetPrizeView.KIND_TALLY)))

## Der gerechnete Fußabdruck DECKT das wirklich gebaute Rack - das Loch lügt nicht
## über den Platz.
func test_the_static_span_covers_the_built_rack():
	for amount in [6, 18, 34, 64, 90, 180]:
		var prize := _prize()
		prize.setup_chips(amount)
		var stack: ChipStackView = prize.get_node("Body/Chips")
		var span := BetPrizeView.span_for(BetPrizeView.KIND_CHIPS, amount)
		for tower: Dictionary in stack.towers():
			var at: Vector2 = tower["at"]
			assert_lte(absf(at.x) + ChipStackView.CHIP_RADIUS, span.x * 0.5 + 0.0001,
				"Turm bei %d bleibt in der Tiefe" % amount)
			assert_lte(absf(at.y) + ChipStackView.CHIP_RADIUS, span.y * 0.5 + 0.0001,
				"Turm bei %d bleibt in der Breite" % amount)

## Eine unbekannte Bauform meldet nichts, statt etwas zu erfinden.
func test_an_unknown_build_reports_no_span():
	assert_eq(BetPrizeView.span_for("gibtsnicht", 5), Vector2.ZERO)

func test_rebuild_drops_the_old_body():
	var prize := _prize()
	prize.setup_charge(4)
	prize.setup_token("PRESSE", CasinoStyle.GOLD_INTENSE)
	assert_eq(prize.kind, BetPrizeView.KIND_TOKEN)
	var body: Node3D = prize.get_node("Body")
	assert_null(body.get_node_or_null("Elko"), "kein Rest der alten Bauform")
