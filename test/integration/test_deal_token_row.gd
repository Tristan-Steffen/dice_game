extends GutTest
## Die geteilte Marken-Reihe (DealTokenRow): dieselbe Grammatik am Hub-Rad und am
## Grubenrand. Hier steht, was die Reihe selbst leistet - der Hub-Test prüft ihr
## Zusammenspiel mit der Hinweis-Karte.

var row: DealTokenRow

func before_each() -> void:
	row = add_child_autofree(DealTokenRow.new())

func _sides(entries: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	typed.assign(entries)
	return typed

func _side(deal_id: String, bonus: bool) -> Dictionary:
	var deal := RouteDeal.find(deal_id)
	return {"id": deal_id, "bonus": bonus,
		"scope": deal.bonus_scope if bonus else deal.malus_scope}

func test_a_token_per_side_and_a_rebuild_replaces_them() -> void:
	row.set_sides(_sides([
		_side(RouteDeal.SAVINGS_BONUS, true), _side(RouteDeal.SAVINGS_BONUS, false)]), 10.0)
	assert_eq(row.get_child_count(), 2)
	row.set_sides(_sides([_side(RouteDeal.HAPPY_HOUR, true)]), 10.0)
	assert_eq(row.get_child_count(), 1, "keine Marke des vorigen Blocks bleibt stehen")

func test_the_unit_scales_the_tokens() -> void:
	row.set_sides(_sides([_side(RouteDeal.HAPPY_HOUR, true)]), 10.0)
	var small: float = (row.get_child(0) as Control).custom_minimum_size.x
	row.set_sides(_sides([_side(RouteDeal.HAPPY_HOUR, true)]), 20.0)
	assert_eq((row.get_child(0) as Control).custom_minimum_size.x, small * 2.0,
		"die Grube rechnet mit einem anderen u als der Hub")

func test_the_hint_carries_effect_and_duration() -> void:
	row.set_sides(_sides([_side(RouteDeal.SAVINGS_BONUS, false)]), 10.0)
	var hint := row.hint_for(row.get_child(0) as Control)
	var title: String = hint["title"]
	var body: String = hint["body"]
	assert_eq(title, RouteDeal.savings_bonus().display_name)
	assert_string_contains(body, RouteDeal.savings_bonus().malus_text)
	assert_string_contains(body, RouteDeal.scope_label(RouteDeal.Scope.BLOCK))
	assert_eq(hint["accent"], DealTokenRow.MALUS_COLOR)
	assert_true(row.hint_for(null).is_empty(), "ohne Marke kein Hinweis")

func test_token_at_finds_the_mark_under_the_pixel() -> void:
	# Der Weg in der Grube: dort erreicht keine Maus die Marken, scene_root fragt
	# je Frame mit dem Display-Pixel nach.
	row.set_sides(_sides([
		_side(RouteDeal.SAVINGS_BONUS, true), _side(RouteDeal.SAVINGS_BONUS, false)]), 10.0)
	await wait_frames(2)
	var second := row.get_child(1) as Control
	assert_eq(row.token_at(second.get_global_rect().get_center()), second)
	assert_null(row.token_at(row.get_global_rect().position - Vector2(50, 50)))

func test_an_invisible_row_reports_no_token() -> void:
	# Ausgeblendetes Mobiliar darf keinen Hinweis mehr auslösen.
	row.set_sides(_sides([_side(RouteDeal.SAVINGS_BONUS, true)]), 10.0)
	await wait_frames(2)
	var center := (row.get_child(0) as Control).get_global_rect().get_center()
	assert_not_null(row.token_at(center))
	row.visible = false
	assert_null(row.token_at(center))

func test_without_self_hover_the_tokens_swallow_nothing() -> void:
	row.self_hover = false
	row.set_sides(_sides([_side(RouteDeal.SAVINGS_BONUS, true)]), 10.0)
	assert_eq((row.get_child(0) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_hovering_reports_the_side() -> void:
	row.set_sides(_sides([_side(RouteDeal.SAVINGS_BONUS, true)]), 10.0)
	var seen := []
	row.token_hovered.connect(func(_a: Control, title: String, _b: String, _c: Color) -> void:
		seen.append(title))
	var left := [false]
	row.token_left.connect(func() -> void: left[0] = true)
	var token := row.get_child(0) as Panel
	token.mouse_entered.emit()
	token.mouse_exited.emit()
	assert_eq(seen, [RouteDeal.savings_bonus().display_name])
	assert_true(left[0])

func test_the_sweep_reports_its_duration() -> void:
	assert_eq(row.sweep(100.0), 0.0, "ohne Marken nichts zu wischen")
	row.set_sides(_sides([
		_side(RouteDeal.SAVINGS_BONUS, true), _side(RouteDeal.SAVINGS_BONUS, false)]), 10.0)
	var duration := row.sweep(100.0)
	assert_almost_eq(duration, DealTokenRow.SWEEP_GAP + DealTokenRow.SWEEP_TIME, 0.001)

func test_a_rebuild_undims_a_swept_row() -> void:
	row.set_sides(_sides([_side(RouteDeal.SAVINGS_BONUS, true)]), 10.0)
	row.sweep(100.0)
	row.modulate.a = 0.0  # Endzustand des Wischs vorwegnehmen
	row.set_sides(_sides([_side(RouteDeal.HAPPY_HOUR, true)]), 10.0)
	assert_eq(row.modulate.a, 1.0)
