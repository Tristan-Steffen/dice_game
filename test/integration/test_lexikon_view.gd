extends GutTest
## LexikonView: Index-Aufbau, Eintrags-Anzeige, Verweis-Historie und das
## Zusammenspiel mit der Seiten-Regel des Hubs (Laden -> Lexikon -> zurück).

var view: LexikonView


func before_each() -> void:
	view = LexikonView.new()
	view.size = Vector2(900, 600)
	add_child_autofree(view)
	view.layout()


func _buttons_containing(node: Node, text: String) -> int:
	var count := 0
	if node is Button and (node as Button).text.contains(text):
		count += 1
	for child in node.get_children():
		count += _buttons_containing(child, text)
	return count


func _count_buttons(node: Node) -> int:
	var count := 1 if node is Button else 0
	for child in node.get_children():
		count += _count_buttons(child)
	return count


func _visible_entries(category: String) -> bool:
	return (view.category_grids[category] as GridContainer).visible


func test_index_lists_every_category_section() -> void:
	await wait_frames(2)
	for category in Lexikon.CATEGORIES:
		assert_gt(_buttons_containing(view, category), 0,
			"Kategorie fehlt im Index: %s" % category)


func test_category_headers_start_collapsed_and_toggle() -> void:
	var category: String = Lexikon.CATEGORIES[0]
	var header: Button = view.category_buttons[category]
	assert_false(_visible_entries(category), "der Index startet zugeklappt")
	assert_string_contains(header.text, "▶")
	header.pressed.emit()
	assert_true(_visible_entries(category), "der Kopfknopf klappt auf")
	assert_string_contains(header.text, "▼")
	assert_string_contains(header.text, "(%d)" % Lexikon.ids_in_category(category).size())
	header.pressed.emit()
	assert_false(_visible_entries(category), "der zweite Druck klappt zu")
	assert_string_contains(header.text, "▶")


func test_categories_toggle_independently() -> void:
	var first: String = Lexikon.CATEGORIES[0]
	var second: String = Lexikon.CATEGORIES[1]
	(view.category_buttons[first] as Button).pressed.emit()
	(view.category_buttons[second] as Button).pressed.emit()
	assert_true(_visible_entries(first), "die erste bleibt offen")
	assert_true(_visible_entries(second), "kein Akkordeon-Zwang")


func test_reset_collapses_categories() -> void:
	var category: String = Lexikon.CATEGORIES[0]
	(view.category_buttons[category] as Button).pressed.emit()
	assert_true(_visible_entries(category))
	view.reset()
	assert_false(_visible_entries(category), "der frische Lauf startet gefaltet")


func test_index_carries_a_button_per_entry() -> void:
	var expected := 0
	for category in Lexikon.CATEGORIES:
		expected += Lexikon.ids_in_category(category).size()
	# Dazu je Karte ein Schließen-Knopf und der Zurück-Knopf der Eintrags-Karte.
	assert_gte(_count_buttons(view), expected, "je Eintrag ein Verweis-Knopf")


func test_open_entry_shows_item_title_and_body() -> void:
	view.open_entry("charm:%s" % Charm.RABBITS_FOOT)
	assert_eq(view.entry_title.text, "Hasenpfote")
	assert_false(view.entry_body.text.is_empty(), "der Text steht im RichTextLabel")
	assert_eq(view.shown_entry(), "charm:%s" % Charm.RABBITS_FOOT)


func test_unknown_entry_falls_back_to_index() -> void:
	view.open_entry("gibt_es_nicht")
	assert_eq(view.shown_entry(), "", "unbekannte id landet am Index")


func test_link_follow_builds_history_and_go_back_walks_it() -> void:
	view.open_entry("charm:%s" % Charm.RABBITS_FOOT)
	view.open_entry(Lexikon.KRIT)  # wie ein Verweis-Klick im Text
	assert_eq(view.shown_entry(), Lexikon.KRIT)
	assert_true(view.go_back(), "Historie-Schritt ist verbraucht")
	assert_eq(view.shown_entry(), "charm:%s" % Charm.RABBITS_FOOT)
	assert_true(view.go_back(), "Eintrag -> Index ist verbraucht")
	assert_eq(view.shown_entry(), "")
	assert_false(view.go_back(), "am Index ist nichts mehr zu verbrauchen")


func test_reset_clears_history() -> void:
	view.open_entry("charm:%s" % Charm.RABBITS_FOOT)
	view.open_entry(Lexikon.KRIT)
	view.reset()
	assert_eq(view.shown_entry(), "")
	assert_false(view.go_back(), "nach dem Reset wartet keine Historie")


func test_landing_entry_has_no_way_back() -> void:
	view.open_landing("charm:%s" % Charm.RABBITS_FOOT)
	assert_eq(view.shown_entry(), "charm:%s" % Charm.RABBITS_FOOT)
	assert_false(view.go_back(), "der Aufschlag verbraucht keinen Rückschritt")
	assert_eq(view.shown_entry(), "charm:%s" % Charm.RABBITS_FOOT,
		"die Karte bleibt stehen - das Zuklappen ist Sache des scene_root")


func test_landing_walks_its_own_history_then_stops() -> void:
	view.open_landing("charm:%s" % Charm.RABBITS_FOOT)
	view.open_entry(Lexikon.KRIT)  # wie ein Verweis-Klick im Text
	assert_true(view.go_back(), "der Verweis-Schritt ist verbraucht")
	assert_eq(view.shown_entry(), "charm:%s" % Charm.RABBITS_FOOT)
	assert_false(view.go_back(), "am Aufschlag endet der Rückweg")


func test_show_index_restores_index_home() -> void:
	view.open_landing("charm:%s" % Charm.RABBITS_FOOT)
	view.show_index()
	view.open_entry(Lexikon.KRIT, false)
	assert_true(view.go_back(), "vom Index aus führt der Rückweg zum Index")
	assert_eq(view.shown_entry(), "")


func test_entry_body_carries_links_but_no_self_link() -> void:
	view.open_entry(Lexikon.KRIT)
	assert_string_contains(view.entry_body.text, "[url=mult]")
	assert_false(view.entry_body.text.contains("[url=krit]"), "kein Selbstverweis")


func test_hub_page_rule_restores_suppressed_shop() -> void:
	# Der Laden-Fall: Lexikon über der offenen Laden-Seite -> Laden verdrängt,
	# Lexikon zu -> Laden steht wieder (LIFO der Seiten-Regel).
	var hub := HubView.new()
	hub.size = Vector2(1000, 600)
	add_child_autofree(hub)
	hub.layout()
	var shop_stub := Control.new()
	shop_stub.visible = false
	hub.attach_panel(shop_stub)
	var lexikon := LexikonView.new()
	lexikon.visible = false
	hub.attach_panel(lexikon)
	lexikon.layout()

	shop_stub.visible = true
	lexikon.visible = true
	assert_false(shop_stub.visible, "das Lexikon verdrängt den Laden")
	lexikon.visible = false
	assert_true(shop_stub.visible, "der Laden kehrt nach dem Lexikon zurück")
	assert_false(hub.content_root.visible, "Home bleibt draußen")
