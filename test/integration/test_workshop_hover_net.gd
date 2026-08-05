extends GutTest
## Werkstatt-Hover: der überfahrene Tray-Würfel zeigt sein Netz auf dem
## Werkbank-Schirm. Nur bei geschlossener Station - sie füllt das Fenster allein.

var view: WorkshopView

func before_each() -> void:
	view = WorkshopView.new()
	view.size = Vector2(900, 460)
	add_child_autofree(view)
	view.run = GameRun.new_run()

func _die(name := "Prüfwürfel") -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = [2, 3, 5, 1, 6, 4]
	def.faces = faces
	def.display_name = name
	def.set_face_material(0, DieMaterial.RUBY)
	def.dope(0)
	def.set_rune(1, Rune.AFTERGLOW)
	def.essence_id = Essence.NEON
	return def

func _card() -> Control:
	return view.get_node_or_null("HoverNet")

func test_hovering_a_die_builds_the_net_card() -> void:
	assert_false(view.hover_net_visible(), "anfangs steht keine Karte")
	view.show_hover_net(_die())
	await wait_frames(2)
	assert_true(view.hover_net_visible())
	assert_not_null(_card(), "die Karte hängt im Fenster")

func test_leaving_the_die_removes_the_card() -> void:
	view.show_hover_net(_die())
	await wait_frames(2)
	view.clear_hover_net()
	await wait_frames(2)
	assert_false(view.hover_net_visible())
	assert_null(_card(), "und sie ist wirklich weg")

func test_the_card_names_the_die_and_its_eye_total() -> void:
	var def := _die("Kraftwürfel")
	view.show_hover_net(def)
	await wait_frames(2)
	var texts := _labels_of(_card())
	assert_true(texts.has("Kraftwürfel"), "der Name steht drauf: %s" % str(texts))
	var total := "Augensumme %d" % DiceRowView.eye_total(def)
	assert_true(texts.has(total), "und die Augensumme: %s" % str(texts))

func _labels_of(node: Node) -> Array:
	var out := []
	if node == null:
		return out
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		out.append_array(_labels_of(child))
	return out

func test_the_card_shows_the_net_of_the_die_it_was_given() -> void:
	# Materialfarben, Stufen, Runen und der Essenz-Chip kommen alle aus dem Netz.
	view.show_hover_net(_die())
	await wait_frames(2)
	assert_gt(_count_of_type(_card(), "RuneGlyph"), 0, "der Rune ist im Netz")
	assert_gt(_count_of_type(_card(), "LevelBadge"), 0, "und die Stufen-Plakette")

func _count_of_type(node: Node, type_name: String) -> int:
	var count := 0
	if node == null:
		return 0
	if node.get_class() == "Control" and node.get_script() != null \
			and String(node.get_script().resource_path).contains("die_net_view"):
		pass
	for child in node.get_children():
		if (child is DieNetView.RuneGlyph and type_name == "RuneGlyph") \
				or (child is DieNetView.LevelBadge and type_name == "LevelBadge"):
			count += 1
		count += _count_of_type(child, type_name)
	return count

func test_an_open_station_wins_over_the_card() -> void:
	# Eine-Ansicht-Regel: die Station füllt das Fenster allein.
	var station := Control.new()
	view.attach_station(station)
	await wait_frames(2)
	view.show_hover_net(_die())
	await wait_frames(2)
	assert_false(view.hover_net_visible(), "bei offener Station keine Karte")

func test_a_closed_station_lets_the_card_through() -> void:
	var station := Control.new()
	view.attach_station(station)
	station.visible = false
	await wait_frames(2)
	view.show_hover_net(_die())
	await wait_frames(2)
	assert_true(view.hover_net_visible())

func test_a_null_die_clears_instead_of_building() -> void:
	view.show_hover_net(_die())
	await wait_frames(2)
	view.show_hover_net(null)
	await wait_frames(2)
	assert_false(view.hover_net_visible(), "nichts unter der Maus, nichts auf dem Schirm")

func test_refreshing_rebuilds_with_current_data() -> void:
	# Die Defs sind geteilte Instanzen - ändert sich der Würfel, zieht die Karte nach.
	var def := _die()
	view.show_hover_net(def)
	await wait_frames(2)
	def.faces[0] = 12
	view.refresh_hover_net()
	await wait_frames(2)
	var total := "Augensumme %d" % DiceRowView.eye_total(def)
	assert_true(_labels_of(_card()).has(total), "die Karte zeigt den neuen Stand")

func test_refreshing_without_a_card_does_nothing() -> void:
	view.refresh_hover_net()
	assert_false(view.hover_net_visible())
