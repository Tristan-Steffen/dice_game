extends GutTest
## Integrationstests der Vertragswahl (RouteChoiceView): Auslage aufbauen, Karten
## zeigen, Unterschrift melden. Die Seite ist der Torwächter vor jeder Runde -
## ohne Klick darf sie nichts melden und nicht verschwinden.

var view: RouteChoiceView

func before_each() -> void:
	view = add_child_autofree(RouteChoiceView.new())
	view.size = Vector2(900, 500)

## Eine Vertragskarte wie GameRun.route_offers sie liefert.
func _card(tier: DealClause.Tier, bonus_id: String, malus_id: String = "") -> Dictionary:
	return {GameRun.CARD_TIER: tier, GameRun.CARD_BONUS: bonus_id, GameRun.CARD_MALUS: malus_id}

func _cards_in(entries: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	typed.assign(entries)
	return typed

## Alle Karten-Knöpfe der Seite (die Karte IST der Knopf).
func _cards() -> Array:
	var found := []
	_collect(view, found)
	return found

func _collect(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Button:
			out.append(child)
		_collect(child, out)

func _three_offers() -> Array[Dictionary]:
	return _cards_in([
		_card(DealClause.Tier.ONE, DealClause.SAVINGS_BONUS, DealClause.BENCHMARK_SURCHARGE),
		_card(DealClause.Tier.TWO, DealClause.HIGH_VOLTAGE, DealClause.HALF_PAYOUT),
		_card(DealClause.Tier.TREAT, DealClause.HAPPY_HOUR),
	])

func test_open_builds_a_card_per_offer() -> void:
	view.open(_three_offers())
	assert_true(view.visible)
	assert_eq(_cards().size(), 3, "je Angebot eine Karte")

func test_a_card_shows_both_clause_effects() -> void:
	view.open(_cards_in([
		_card(DealClause.Tier.ONE, DealClause.ADVANCE_PAYMENT, DealClause.EMPTIES)]))
	var texts := _label_texts()
	assert_true(texts.has(DealClause.tier_label(DealClause.Tier.ONE)),
		"die Stufe steht als Titel auf der Karte")
	assert_true(_texts_contain(texts, DealClause.advance_payment().text))
	assert_true(_texts_contain(texts, DealClause.empties().text))

func test_a_card_never_prints_the_scope_labels() -> void:
	# Entrümpelt: die kleine graue Laufzeit-Zeile steht nicht mehr auf der Karte.
	view.open(_cards_in([
		_card(DealClause.Tier.ONE, DealClause.ADVANCE_PAYMENT, DealClause.EMPTIES)]))
	var texts := _label_texts()
	for scope: DealClause.Scope in [DealClause.Scope.INSTANT, DealClause.Scope.ROUND,
			DealClause.Scope.BLOCK]:
		assert_false(texts.has(DealClause.scope_label(scope)), "keine Laufzeit-Zeile")

func test_a_card_never_prints_the_clause_names() -> void:
	# Entrümpelt: die Wirkung steht da, der Klausel-NAME nicht mehr.
	view.open(_cards_in([
		_card(DealClause.Tier.ONE, DealClause.ADVANCE_PAYMENT, DealClause.EMPTIES)]))
	var texts := _label_texts()
	for text: String in texts:
		assert_ne(text, DealClause.advance_payment().display_name, "kein Bonus-Name")
		assert_ne(text, DealClause.empties().display_name, "kein Malus-Name")

func test_a_treat_card_shows_only_its_bonus() -> void:
	view.open(_cards_in([_card(DealClause.Tier.TREAT, DealClause.HAPPY_HOUR)]))
	var texts := _label_texts()
	assert_true(_texts_contain(texts, DealClause.happy_hour().text))
	assert_false(_texts_contain(texts, DealClause.empties().text), "kein Malus auf dem Werbegeschenk")

func test_a_boss_card_shows_only_the_condition() -> void:
	view.open(_cards_in([_card(DealClause.Tier.BOSS, "", DealClause.ALL_IN)]), true)
	var texts := _label_texts()
	assert_true(_texts_contain(texts, DealClause.all_in().text))
	assert_true(texts.has(DealClause.tier_label(DealClause.Tier.BOSS)))

func test_clicking_a_card_signs_that_slot() -> void:
	view.open(_three_offers())
	var chosen: Array[int] = []
	view.route_chosen.connect(func(index: int) -> void: chosen.append(index))
	(_cards()[1] as Button).pressed.emit()
	assert_eq(chosen, [1] as Array[int])

func test_the_stress_round_announces_itself() -> void:
	view.open(_cards_in([
		_card(DealClause.Tier.BOSS, "", DealClause.ALL_IN),
		_card(DealClause.Tier.BOSS, "", DealClause.TILTED_FLOOR)]), true)
	assert_true(view.stress_round)
	assert_true(_label_texts().has(RouteChoiceView.STRESS_TITLE))
	view.open(_three_offers())
	assert_false(view.stress_round)
	assert_true(_label_texts().has(RouteChoiceView.TITLE), "danach wieder die normale Wahl")

func test_reopening_replaces_the_old_offers() -> void:
	view.open(_three_offers())
	view.open(_cards_in([_card(DealClause.Tier.ONE, DealClause.ADVANCE_PAYMENT)]))
	assert_eq(_cards().size(), 1, "keine Karten der vorigen Runde bleiben stehen")

func test_the_unit_never_follows_the_width_alone() -> void:
	# Der Grubenboden ist breit und flach: aus der Breite allein gerechnet würde
	# die Schrift riesig, darum bremst die Höhe mit.
	view.size = Vector2(2000, 200)
	var flat := view._unit()
	assert_almost_eq(flat, 200.0 / 46.0, 0.01, "flache Grube -> die Höhe bremst")
	view.size = Vector2(2000, 1200)
	assert_almost_eq(view._unit(), 20.0, 0.01, "hoch genug -> die Breite bestimmt")
	assert_lt(flat, view._unit())

func test_close_hides_the_page() -> void:
	view.open(_three_offers())
	view.close()
	assert_false(view.visible)

## Alle Label-Texte der Seite (rekursiv).
func _label_texts() -> Array:
	var texts := []
	_collect_labels(view, texts)
	return texts

## Die Klauselzeile ist nur die Wirkung; Teilstring reicht (Autowrap kann sie
## an Leerzeichen aufteilen, der Label-Text bleibt aber ganz).
func _texts_contain(texts: Array, needle: String) -> bool:
	for text: String in texts:
		if text.contains(needle):
			return true
	return false

func _collect_labels(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Label:
			out.append((child as Label).text)
		_collect_labels(child, out)
