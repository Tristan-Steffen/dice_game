extends GutTest
## Integrationstests der Routenwahl-Seite (RouteChoiceView): Auslage aufbauen,
## Karten zeigen, Unterschrift melden. Die Seite ist der Torwächter vor jeder
## Runde - ohne Klick darf sie nichts melden und nicht verschwinden.

var view: RouteChoiceView

func before_each() -> void:
	view = add_child_autofree(RouteChoiceView.new())
	view.size = Vector2(900, 500)

func _ids(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
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

func test_open_builds_a_card_per_offer() -> void:
	view.open(_ids([RouteDeal.SAVINGS_BONUS, RouteDeal.HIGH_VOLTAGE, RouteDeal.HAPPY_HOUR]))
	assert_true(view.visible)
	assert_eq(_cards().size(), 3, "je Angebot eine Karte")

func test_a_card_names_both_sides_and_their_durations() -> void:
	view.open(_ids([RouteDeal.ADVANCE_PAYMENT]))
	var deal := RouteDeal.advance_payment()
	var texts := _label_texts()
	assert_true(texts.has(deal.display_name), "der Name steht auf der Karte")
	assert_true(texts.has(deal.bonus_text))
	assert_true(texts.has(deal.malus_text))
	# Der Vorschuss zahlt sofort, sein Malus läuft bis zur Abrechnung - genau
	# dieser Unterschied ist die Entscheidung.
	assert_true(texts.has(RouteDeal.scope_label(RouteDeal.Scope.INSTANT)))
	assert_true(texts.has(RouteDeal.scope_label(RouteDeal.Scope.BLOCK)))

func test_a_pure_bonus_card_shows_no_malus_line() -> void:
	view.open(_ids([RouteDeal.HAPPY_HOUR]))
	var texts := _label_texts()
	assert_true(texts.has(RouteDeal.happy_hour().bonus_text))
	assert_eq(texts.count(RouteDeal.scope_label(RouteDeal.Scope.ROUND)), 1,
		"nur eine Seite, also nur ein Laufzeit-Etikett")

func test_clicking_a_card_signs_that_deal() -> void:
	view.open(_ids([RouteDeal.SAVINGS_BONUS, RouteDeal.HIGH_VOLTAGE, RouteDeal.HAPPY_HOUR]))
	var chosen: Array[String] = []
	view.route_chosen.connect(func(deal_id: String) -> void: chosen.append(deal_id))
	(_cards()[1] as Button).pressed.emit()
	assert_eq(chosen, [RouteDeal.HIGH_VOLTAGE] as Array[String])

func test_the_stress_round_announces_itself() -> void:
	view.open(_ids([RouteDeal.DOUBLE_LOAD, RouteDeal.GOODWILL, RouteDeal.STANDARD_PROTOCOL]), true)
	assert_true(view.stress_round)
	assert_true(_label_texts().has(RouteChoiceView.STRESS_TITLE))
	view.open(_ids([RouteDeal.SAVINGS_BONUS]))
	assert_false(view.stress_round)
	assert_true(_label_texts().has(RouteChoiceView.TITLE), "danach wieder die normale Wahl")

func test_reopening_replaces_the_old_offers() -> void:
	view.open(_ids([RouteDeal.SAVINGS_BONUS, RouteDeal.HIGH_VOLTAGE, RouteDeal.HAPPY_HOUR]))
	view.open(_ids([RouteDeal.ADVANCE_PAYMENT]))
	assert_eq(_cards().size(), 1, "keine Karten der vorigen Runde bleiben stehen")

func test_close_hides_the_page() -> void:
	view.open(_ids([RouteDeal.SAVINGS_BONUS]))
	view.close()
	assert_false(view.visible)

## Alle Label-Texte der Seite (rekursiv).
func _label_texts() -> Array:
	var texts := []
	_collect_labels(view, texts)
	return texts

func _collect_labels(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Label:
			out.append((child as Label).text)
		_collect_labels(child, out)
