extends GutTest
## Die Deal-Wahl in der Grube (RouteChoiceView): drei Karten aus GameRun.route_view_state,
## Kopf mit Stufe und Hitze-Wirkung, volle Klausel-Texte, Fuß mit Blind und Schnitt.

var view: RouteChoiceView
var run: GameRun

## Das Maß des echten Grubenbodens (gemessen am Tisch).
const PIT_FLOOR := Vector2(985, 484)

func before_each() -> void:
	view = add_child_autofree(RouteChoiceView.new())
	view.size = PIT_FLOOR
	run = GameRun.new_run()

func _open_at(heat: int) -> void:
	run.heat = heat
	run.roll_route_offers()
	view.open(run.route_view_state())

func _cards() -> Array:
	var found := []
	_collect(view, found, "Button")
	return found

func _collect(node: Node, out: Array, kind: String) -> void:
	for child in node.get_children():
		if child.is_class(kind):
			out.append(child)
		_collect(child, out, kind)

func _label_texts() -> Array:
	var labels := []
	_collect(view, labels, "Label")
	var texts := []
	for label: Label in labels:
		texts.append(label.text)
	return texts

func _texts_contain(needle: String) -> bool:
	for text: String in _label_texts():
		if text.contains(needle):
			return true
	return false

func test_open_builds_three_cards() -> void:
	_open_at(3)
	assert_true(view.visible)
	assert_eq(_cards().size(), 3)

func test_the_head_names_level_and_heat_effect() -> void:
	_open_at(3)
	for name in ["Warm", "Heiß", "Glühend"]:
		assert_true(_label_texts().has(name), "Stufenname %s" % name)
	assert_true(_texts_contain("Hitze −1 · kein Malus"))
	assert_true(_texts_contain("Hitze +1"))
	assert_true(_texts_contain("Hitze %s" % HeatStyle.level_name(3)), "der Titel nennt die Hitze")

func test_white_heat_reads_as_such() -> void:
	_open_at(5)
	assert_true(_label_texts().has("Weißglut"))
	assert_true(_texts_contain("Hitze bleibt · Weißglut"))

func test_every_clause_stands_with_its_full_text() -> void:
	run.owned_charms.append(Charm.shyster())
	_open_at(4)
	for card: Dictionary in run.route_view_state()["cards"]:
		for clause: Dictionary in card["bonus"] + card["malus"]:
			assert_true(_texts_contain(String(clause["text"])), String(clause["id"]))
			assert_true(_texts_contain(String(clause["name"])))

func test_the_foot_names_blind_and_average() -> void:
	run.round_scores.assign([300])
	_open_at(2)
	var card: Dictionary = run.route_view_state()["cards"][1]
	assert_true(_texts_contain("Blind %s · dein Schnitt 300" % BigNumber.short(int(card["blind_after"]))))

func test_six_clauses_fit_on_a_white_heat_card() -> void:
	# Über viele Würfe: jede Karte trägt ihren ganzen Text, auch die Weißglut mit sechs Klauseln.
	for i in 30:
		_open_at(4 + i % 2)
		await wait_frames(2)
		for card: Button in _cards():
			var content: Control = card.get_child(0)
			assert_lte(content.get_combined_minimum_size().y, card.size.y + 0.5,
				"Hitze %d: %s ragt über die Karte" % [run.heat, card.name])

func test_clicking_a_card_signs_that_slot() -> void:
	_open_at(2)
	var chosen: Array[int] = []
	view.route_chosen.connect(func(index: int) -> void: chosen.append(index))
	(_cards()[1] as Button).pressed.emit()
	assert_eq(chosen, [1] as Array[int])

func test_the_boss_round_announces_itself() -> void:
	run.round_number = GameRun.GOAL_BLOCK
	run.roll_route_offers()
	view.open(run.route_view_state())
	assert_true(view.stress_round())
	assert_true(_label_texts().has(RouteChoiceView.STRESS_TITLE))
	run.round_number = 1
	_open_at(1)
	assert_false(view.stress_round())

func test_reopening_replaces_the_old_cards() -> void:
	_open_at(2)
	var state := run.route_view_state()
	state["cards"] = [state["cards"][0]]
	view.open(state)
	assert_eq(_cards().size(), 1)

func test_the_unit_never_follows_the_width_alone() -> void:
	view.size = Vector2(2000, 200)
	var flat := view._unit()
	assert_almost_eq(flat, 200.0 / 46.0, 0.01, "flache Grube -> die Höhe bremst")
	view.size = Vector2(2000, 1200)
	assert_almost_eq(view._unit(), 20.0, 0.01)

func test_the_heat_ladder_avoids_the_scoring_colours() -> void:
	var scoring := [TableScreen.TRAIL_BASE_COLOR, TableScreen.TRAIL_MULT_COLOR, TableScreen.CRIT_COLOR,
		CasinoStyle.MONEY, CasinoStyle.ENERGY]
	for level in range(1, GameRun.HEAT_WHITE + 1):
		var tint := HeatStyle.color(level)
		if tint.s < 0.3:
			continue  # Graublau und Weißglut tragen kaum Farbe
		for other: Color in scoring:
			var gap := absf(tint.h - other.h)
			gap = minf(gap, 1.0 - gap)
			assert_gt(gap, 0.05, "Stufe %d gleicht einer Wertungsfarbe" % level)

func test_close_hides_the_page() -> void:
	_open_at(1)
	view.close()
	assert_false(view.visible)
