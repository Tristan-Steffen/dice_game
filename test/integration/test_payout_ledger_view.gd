extends GutTest
## PayoutLedgerView: die Auszahlungs-Seite des Rundenendes. Zeilen entstehen bei
## ihrer ERSTEN Meldung (Reihenfolge = Zeremonie), ticken danach hoch, die
## ⚡-Zeile steht getrennt und zählt nicht mit, und der Kassieren-Knopf gibt es
## erst, wenn die Zählerei durch ist.

var view: PayoutLedgerView

func before_each() -> void:
	view = PayoutLedgerView.new()
	view.size = Vector2(900, 950)
	add_child_autofree(view)
	view.layout()

func _rows() -> int:
	return view._rows_box.get_child_count()

func test_a_row_is_born_with_its_first_report() -> void:
	assert_eq(_rows(), 0, "vor der ersten Meldung steht keine Zeile")
	view.add_money("benchmark", "Benchmark", 5)
	assert_eq(_rows(), 1, "die erste Meldung legt ihre Zeile an")
	assert_eq(view.money_of("benchmark"), 5)

func test_a_second_report_counts_the_same_row_up() -> void:
	view.add_money("dice", "Übrige Würfel", 1)
	view.add_money("dice", "Übrige Würfel", 1)
	view.add_money("dice", "Übrige Würfel", 2)
	assert_eq(_rows(), 1, "dieselbe Quelle bleibt EINE Zeile")
	assert_eq(view.money_of("dice"), 4, "die Zeile tickt hoch")

func test_zero_reports_open_no_row() -> void:
	view.add_money("gold_vein", "Goldader", 0)
	assert_eq(_rows(), 0, "wer nichts zahlt, bekommt keine Zeile")
	assert_eq(view.money_total(), 0)

func test_the_total_is_the_sum_of_the_money_reports() -> void:
	view.add_money("benchmark", "Benchmark", 5)
	view.add_money("interest", "Zinsen", 3)
	view.add_money("dice", "Übrige Würfel", 2)
	view.add_money("dice", "Übrige Würfel", 2)
	assert_eq(view.money_total(), 12)

func test_charge_stands_apart_and_never_enters_the_total() -> void:
	view.add_money("benchmark", "Benchmark", 5)
	view.add_charge(3)
	view.add_charge(2)
	assert_eq(view.charge_total(), 5, "⚡ zählt für sich")
	assert_eq(view.money_total(), 5, "⚡ fließt nicht in die Geld-Summe")
	assert_eq(_rows(), 1, "die ⚡-Zeile ist keine Geld-Zeile")
	assert_true(view._charge_row.visible, "sie erscheint mit der ersten Ladung")

func test_the_charge_row_stays_hidden_without_a_report() -> void:
	view.add_money("benchmark", "Benchmark", 5)
	assert_false(view._charge_row.visible, "ohne ⚡ keine ⚡-Zeile")

func test_the_row_order_is_the_report_order() -> void:
	view.add_money("benchmark", "Benchmark", 5)
	view.add_money("charm_2", "Zinsgroschen", 4)
	view.add_money("dice", "Übrige Würfel", 1)
	view.add_money("benchmark", "Benchmark", 1)  # ändert die Reihenfolge nicht
	assert_eq(view.row_ids(), ["benchmark", "charm_2", "dice"] as Array[String])

func test_reset_empties_everything() -> void:
	view.add_money("benchmark", "Benchmark", 5)
	view.add_charge(2)
	view.show_cashout()
	view.reset()
	await wait_frames(2)
	assert_eq(_rows(), 0, "keine Zeile überlebt")
	assert_eq(view.money_total(), 0)
	assert_eq(view.charge_total(), 0)
	assert_eq(view.row_ids(), [] as Array[String])
	assert_false(view._charge_row.visible)
	assert_false(view.cashout_button.visible, "und der Knopf ist wieder fort")

func test_the_cashout_button_shows_only_when_asked() -> void:
	assert_false(view.cashout_button.visible, "solange gezählt wird, gibt es nichts zu klicken")
	view.show_cashout()
	assert_true(view.cashout_button.visible)

func test_cashout_is_requested_only_after_the_press() -> void:
	# Zähler im Array: eine Lambda fängt Zahlen als KOPIE ein.
	var seen: Array[int] = [0]
	view.cashout_pressed.connect(func() -> void: seen[0] += 1)
	view.show_cashout()
	assert_false(view.cashout_requested, "der bloße Knopf verlangt nichts")
	view.cashout_button.pressed.emit()
	assert_true(view.cashout_requested)
	assert_eq(seen[0], 1)
	view.cashout_button.pressed.emit()
	assert_eq(seen[0], 1, "ein zweiter Druck kassiert nicht noch einmal")

func test_reset_reopens_the_button_for_the_next_round() -> void:
	view.show_cashout()
	view.cashout_button.pressed.emit()
	view.reset()
	view.show_cashout()
	assert_false(view.cashout_requested)
	assert_false(view.cashout_button.disabled, "die nächste Runde darf wieder kassieren")

# --- Die WETT-ZEILE trägt ihre BEDINGUNG ---------------------------------------
# Sie kommt aus der EINEN bestehenden Textquelle (SideBet.description, dieselbe, die
# der Setzen-Knopf und der Gruben-Schirm drucken) - hier wird nichts formuliert.

func _bet(id: String) -> SideBet:
	for t: Dictionary in SideBet.TEMPLATES:
		if t["id"] == id:
			return SideBet._from_template(t, 300)
	return null

func _note_of(id: String) -> Label:
	var row: Dictionary = view._rows[id]
	var host: Control = row["host"]
	return host.get_child(0).get_node_or_null("Bedingung")

func test_a_bet_row_carries_its_condition_under_the_name() -> void:
	var bet := _bet("jackpot")
	view.add_money("bet_0", bet.display_name, 18, bet.description)
	var note := _note_of("bet_0")
	assert_not_null(note, "die Wett-Zeile trägt eine zweite Zeile")
	assert_eq(note.text, bet.description,
		"und zwar den Bedingungs-Satz der Wette selbst")
	var host: Control = view._rows["bet_0"]["host"]
	assert_eq(String(host.get_child(1).text), "+18$", "der Betrag steht rechts wie überall")

func test_a_row_without_a_note_keeps_the_old_single_line_shape() -> void:
	view.add_money("benchmark", "Benchmark", 5)
	var host: Control = view._rows["benchmark"]["host"]
	assert_true(host.get_child(0) is Label, "ohne Untertitel bleibt es EIN Label")
	assert_eq(String(host.get_child(0).text), "Benchmark")

func test_a_second_report_keeps_the_condition() -> void:
	var bet := _bet("jackpot")
	view.add_money("bet_0", bet.display_name, 18, bet.description)
	view.add_money("bet_0", bet.display_name, 3, bet.description)
	assert_eq(view.money_of("bet_0"), 21, "die Zeile tickt wie jede andere")
	assert_eq(_note_of("bet_0").text, bet.description, "und behält ihre Bedingung")

# --- Die ABLAGE der Gewinn-Körper ----------------------------------------------
# EINE Plattform trägt die ganze Ware nebeneinander, darüber ihre Namen als
# kompakte Liste im Zeilenmaß der Seite.

func _plots(values: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v in values:
		out.append({"id": String(v), "label": "Ware %s" % v})
	return out

## Auf der Schicht liegen NUR die Namens-ZEILEN (vom selben Bauer wie die
## Geld-Zeilen, nur ohne Betrag) - eine Fassung gibt es nicht.
func _row_of(index: int) -> Control:
	return view._plot_layer.get_child(index) as Control

func _label_of(index: int) -> Label:
	return _row_of(index).get_child(0) as Label

func test_without_wins_the_strip_stays_empty() -> void:
	assert_eq(view.payout_platform().size.x, 0.0, "0 Gewinne = keine Ablage")
	assert_eq(view.payout_cells().size(), 0)
	assert_eq(view._plot_layer.get_child_count(), 0, "und keine Zeile")

## EINE Plattform, je Ware EINE Zelle darauf - nebeneinander, lückenlos.
func test_all_goods_share_one_platform_side_by_side() -> void:
	view.set_plots(_plots(["bet_0", "bet_1", "bet_2"]))
	await wait_frames(2)
	assert_eq(view._plot_layer.get_child_count(), 3, "je Ware EIN Name, sonst nichts")
	var deck := view.payout_local_platform()
	var cells := view.payout_local_cells()
	assert_eq(cells.size(), 3)
	for cell in cells:
		assert_almost_eq(cell.position.y, deck.position.y, 0.001, "eine Höhe")
		assert_almost_eq(cell.size.y, deck.size.y, 0.001)
	for i in range(1, cells.size()):
		assert_almost_eq(cells[i].position.x, cells[i - 1].end.x, 0.001,
			"Zelle %d schließt an ihre Nachbarin an" % i)
	assert_almost_eq(cells[0].position.x, deck.position.x, 0.001)
	assert_almost_eq(cells[2].end.x, deck.end.x, 0.001, "und sie füllen die Plattform")

func test_the_platform_rect_is_byte_stable() -> void:
	view.set_plots(_plots(["bet_0", "bet_1"]))
	var before := view.payout_local_platform()
	var cells := view.payout_local_cells()
	view.add_money("benchmark", "Benchmark", 5)
	view.add_money("bet_0", "Jackpot", 18, "Nimm ein Full House oder besser.")
	view.add_charge(3)
	view.show_cashout()
	assert_eq(view.payout_local_platform(), before,
		"keine Zeile verrückt die Plattform - sie hängt allein an der Seitengröße")
	assert_eq(view.payout_local_cells(), cells)
	view.set_plots(_plots(["bet_0", "bet_1"]))
	assert_eq(view.payout_local_platform(), before, "dieselbe Meldung liefert dasselbe")

## Die Ablage hat KEINE Fassung: ist die Ware oben, steht nichts mehr da.
func test_the_ablage_draws_no_frame_at_all() -> void:
	view.set_plots(_plots(["bet_0", "bet_1"]))
	await wait_frames(2)
	for child in view._plot_layer.get_children():
		assert_false(child is Panel, "kein gemalter Rahmen auf der Ablage: %s" % child.name)

## Die Namen stehen KOMPAKT LINKS NEBEN der Ware: dasselbe Zeilenmaß und derselbe
## linke Rand wie "Benchmark" - EIN Schriftbild auf der ganzen Seite.
func test_the_goods_names_share_the_spacing_of_the_money_rows() -> void:
	view.set_plots(_plots(["bet_0", "bet_1", "bet_2"]))
	# ZWEI Geld-Zeilen, damit ihr Takt wirklich GEMESSEN wird statt gerechnet.
	view.add_money("benchmark", "Benchmark", 5)
	view.add_money("dice", "Übrige Würfel", 22)
	await wait_frames(2)
	assert_eq(view.plot_labels(),
		["Ware bet_0", "Ware bet_1", "Ware bet_2"] as Array[String])
	var first: Control = view._rows["benchmark"]["host"]
	var second: Control = view._rows["dice"]["host"]
	var row_pitch := second.global_position.y - first.global_position.y
	var row_left := first.global_position.x - view.global_position.x
	var deck := view.payout_local_platform()
	for i in 3:
		assert_eq(_label_of(i).text, "Ware bet_%d" % i)
		assert_almost_eq(_row_of(i).position.x, row_left, 0.001, "derselbe linke Rand")
		if i > 0:
			assert_almost_eq(_row_of(i).position.y - _row_of(i - 1).position.y, row_pitch,
				0.001, "und derselbe Zeilentakt wie oben (Abstand %d)" % i)
	for i in 3:
		assert_lt(_row_of(i).position.x + _row_of(i).size.x, deck.position.x + 0.001,
			"Name %d endet vor der Ware rechts" % i)

## Die Ablage liegt in der LEERZONE: unter GESAMT und über dem Kassieren-Knopf.
func test_the_strip_lies_between_the_total_and_the_button() -> void:
	view.set_plots(_plots(["bet_0", "bet_1"]))
	view.add_money("benchmark", "Benchmark", 5)
	view.show_cashout()
	await wait_frames(2)
	var deck := view.payout_local_platform()
	var page := Rect2(Vector2.ZERO, view.size)
	# Beide Marken in SEITEN-Pixeln: Summe und Knopf hängen in der Spalte, ihr
	# position zählt von deren Ecke.
	var total_bottom := view.total_value.global_position.y - view.global_position.y \
		+ view.total_value.size.y
	var button_top := view.cashout_button.global_position.y - view.global_position.y
	assert_true(page.encloses(deck), "die Plattform liegt auf der Seite: %s" % deck)
	assert_lt(deck.end.y, button_top, "über dem Knopf")
	assert_gt(deck.position.y, total_bottom, "und unter GESAMT")
	# Sie ist KNAPP: nur ihre Zellen breit, nicht die halbe Seite.
	assert_lt(deck.size.x, view.size.x * 0.35,
		"eine knappe Plattform in der Betrags-Spalte, keine Bank quer über die Seite")
	assert_gt(_row_of(0).position.y, total_bottom, "die Namen stehen unter GESAMT")

func test_the_plot_index_maps_the_row_id() -> void:
	view.set_plots(_plots(["bet_0", "bet_2"]))
	assert_eq(view.plot_index("bet_0"), 0)
	assert_eq(view.plot_index("bet_2"), 1)
	assert_eq(view.plot_index("bet_1"), -1, "wer nicht gewonnen hat, hat keinen Platz")
	assert_eq(view.plot_count(), 2)

func test_reset_takes_the_strip_away() -> void:
	view.set_plots(_plots(["bet_0", "bet_1"]))
	view.reset()
	await wait_frames(2)
	assert_eq(view.payout_platform().size.x, 0.0)
	assert_eq(view.plot_count(), 0)
	assert_eq(view._plot_layer.get_child_count(), 0)

## Der gemeldete Radius schneidet das LOCH - gemalt wird davon nichts.
func test_the_reported_radius_stays_for_the_hole() -> void:
	view.set_plots(_plots(["bet_0"]))
	await wait_frames(2)
	assert_gt(view.payout_plot_radius(), 0.0, "eine Rundung für den Schnitt")

## Die ZIEL-Lichter fliegen erst beim Kassieren: beim Zählen liegt der Gewinn
## sichtbar auf der Seite, also gibt es dort kein zweites Ziel mehr.
func test_the_counting_fires_no_target_light_any_more() -> void:
	var code := FileAccess.get_file_as_string("res://scripts/scene_root.gd")
	for dead in ["_fly_side_bet_payout", "_fly_side_bet_to_treasure",
			"_fly_side_bet_to_hub", "_fly_side_bet_special", "_fly_side_bet_pack",
			"_play_side_bet_charge_volley"]:
		assert_false(code.contains(dead), "%s ist tot" % dead)

## Und die Körper der Ablage sind NIE Buchungsträger: kein Zeremonie-Pfad ruft eine
## GameRun-Buchung - jede Zahl steht längst dort, wo sie hingehört.
func test_the_payout_bodies_never_book() -> void:
	var code := FileAccess.get_file_as_string("res://scripts/scene_root.gd")
	var start := code.find("# --- Die ABLAGE der AUSZAHLUNGS-SEITE")
	assert_gt(start, 0, "die Region steht")
	var stop := code.find("## Die Magazin-Plätze der Pakete", start)
	assert_gt(stop, start)
	var region := code.substr(start, stop - start)
	for booking in ["run.add_money", "run.add_charge", "run.spend_charge",
			"run.grant_", "place_side_bet", "resolve_side_bets"]:
		assert_false(region.contains(booking),
			"die Ablage bucht nicht (%s)" % booking)

func test_only_scene_root_reports_no_ui_window_knows_the_page() -> void:
	# ui/ malt nur - GEMELDET wird aus scene_root, sonst wüßte ein Fenster von der
	# Buchung. Ein Grep hält das fest.
	var dir := DirAccess.open("res://scripts/ui")
	assert_not_null(dir, "scripts/ui/ ist lesbar")
	for file in dir.get_files():
		if not file.ends_with(".gd") or file == "payout_ledger_view.gd":
			continue
		var text := FileAccess.get_file_as_string("res://scripts/ui/%s" % file)
		assert_false(text.contains("payout_ledger") or text.contains("PayoutLedgerView"),
			"%s greift auf die Auszahlungs-Seite zu" % file)
