extends GutTest
## Tier-2-Tests des Magazins (PackDrawerView): EINE Grube in der Schürze, je Paket
## seine eigene STEHENDE Kassette in Spieler-Ordnung. Gezählt und arbitriert wird
## in WorkshopView - hier steht nur, was liegt.

## Fußabdruck einer stehenden Kassette (Kappe: breit und flach).
const CELL := Vector2(30, 12)

func _entry(pack: Pack, uid: int, withheld := false) -> Dictionary:
	pack.pack_uid = uid
	return {"uid": uid, "pack": pack, "withheld": withheld}

func _drawer(entries: Array[Dictionary], locked := false,
		row := Vector2(900, 150)) -> PackDrawerView:
	var drawer := PackDrawerView.new()
	add_child_autofree(drawer)
	drawer.size = row
	drawer.build(entries, 8.0, locked, CELL, row)
	return drawer

## Das FELD eines Streifens: die Grube, also der Streifen ohne seine Fassung -
## dort stehen die Kassetten, und daran misst sich jeder gerechnete Anker.
func _field(row := Vector2(900, 150)) -> Rect2:
	return PackDrawerView.pit_rect_in(Rect2(Vector2.ZERO, row), 8.0)

# --- Taxonomie: sie wohnt jetzt in data/ (Pack), die Farben hier ------------------

func test_a_dice_pack_belongs_only_to_the_dice_shelf() -> void:
	var pack := Pack.dice_pack(DiceOffer.TEMPLATES[0])
	assert_eq(Pack.shelf_of(pack), Pack.SHELF_DICE_PACK)
	for category in [Engraving.CATEGORY_NUMBER, Engraving.CATEGORY_MATERIAL,
			Engraving.CATEGORY_DICE, Pack.SHELF_SPECIAL]:
		assert_false(Pack.pack_belongs(pack, category), "%s zaehlt es nicht" % category)

func test_a_fixed_special_pack_lies_on_the_stockpile() -> void:
	var pack := Pack.fixed_engraving_pack(Engraving.pointer_engraving())
	assert_eq(Pack.shelf_of(pack), Pack.SHELF_SPECIAL)

func test_an_engraving_pack_lies_on_its_category() -> void:
	assert_eq(Pack.shelf_of(Pack.number_pack()), Engraving.CATEGORY_NUMBER)
	assert_eq(Pack.shelf_of(Pack.material_pack()), Engraving.CATEGORY_MATERIAL)

func test_the_delivery_route_reads_the_pack_type() -> void:
	assert_eq(Pack.shelf_for_pack_type(Pack.TYPE_DICE), Pack.SHELF_DICE_PACK)
	assert_eq(Pack.shelf_for_pack_type(Pack.TYPE_MATERIAL), Engraving.CATEGORY_MATERIAL)

func test_the_pack_type_map_reads_both_ways() -> void:
	for pack_type: String in [Pack.TYPE_DICE, Pack.TYPE_NUMBER, Pack.TYPE_MATERIAL,
			Pack.TYPE_DICE_MOD]:
		var category := Pack.shelf_for_pack_type(pack_type)
		assert_eq(Pack.pack_type_of_shelf(category), pack_type, "hin und zurück: %s" % pack_type)
	assert_eq(Pack.pack_type_of_shelf(Pack.SHELF_SPECIAL), "",
		"der Sonderbestand nennt seine Sorte nicht")

func test_every_shelf_order_key_has_a_colour() -> void:
	# Die Taxonomie wohnt in data/, die Farben in ui/ - ein fehlender Schlüssel
	# wäre ein stiller Rückfall auf Gold.
	for category: String in Pack.SHELF_ORDER:
		assert_true(PackDrawerView.COLORS.has(category), "%s hat seine Farbe" % category)

# --- Das Raster: feste Kartengröße, die Zeile fließt -------------------------------

func test_spots_run_row_major_in_owner_order() -> void:
	var field := _field().size
	var columns := PackDrawerView.columns_for(field, CELL, 4)
	var first := PackDrawerView.spot_for(0, 4, field, CELL)
	var second := PackDrawerView.spot_for(1, 4, field, CELL)
	assert_almost_eq(second.x - first.x, field.x / float(columns), 0.01,
		"nebeneinander in derselben Reihe")
	assert_almost_eq(second.y, first.y, 0.01)
	var below := PackDrawerView.spot_for(columns, columns + 1, field, CELL)
	assert_almost_eq(below.x, first.x, 0.01, "der zweite Rang beginnt wieder links")
	assert_gt(below.y, first.y)

func test_a_line_holds_what_fits_and_the_rest_flows_into_the_next_rank() -> void:
	# Der Magazin-Deckel formt das Raster NICHT mehr: die Spaltenzahl folgt allein
	# aus der Breite der Grube und dem festen Kartenmaß.
	var field := _field().size
	var columns := PackDrawerView.columns_for(field, CELL, 1)
	var card := CELL.x * PackDrawerView.CELL_SPAN * PackDrawerView.CASSETTE_SCALE
	assert_eq(columns, int(field.x / card), "so viele, wie in ihrer Größe hineinpassen")
	assert_eq(PackDrawerView.rows_for(field, CELL, columns), 1, "eine volle Zeile")
	assert_eq(PackDrawerView.rows_for(field, CELL, columns + 1), 2,
		"die nächste Kassette eröffnet den nächsten Rang")

func test_the_ranks_start_at_the_top_of_the_pit_and_grow_forward() -> void:
	var field := _field().size
	var columns := PackDrawerView.columns_for(field, CELL, 1)
	var depth := PackDrawerView.slot_size(field, CELL, 1).y
	assert_almost_eq(PackDrawerView.spot_for(0, 1, field, CELL).y, depth * 0.5, 0.01,
		"der erste Rang liegt an der hinteren Kante")
	assert_almost_eq(PackDrawerView.spot_for(columns, columns + 1, field, CELL).y,
		depth * 1.5, 0.01, "und die neuen wachsen nach vorn in die leere Grube")

func test_the_card_keeps_its_size_however_many_packs_lie_there() -> void:
	# Der ganze Punkt: eine Kassette schrumpft NIE - auch nicht jenseits des
	# Deckels, den es nur gibt, damit es dort nie so weit kommt.
	var field := _field().size
	for count in [1, 12, 20, 40, 400]:
		assert_almost_eq(PackDrawerView.cell_scale_for(CELL, field, count),
			PackDrawerView.CASSETTE_SCALE, 0.001, "%d Pakete, dasselbe Maß" % count)

func test_the_capacity_is_columns_times_the_ranks_that_fit() -> void:
	var field := _field().size
	var columns := PackDrawerView.columns_for(field, CELL, 1)
	var ranks := int(field.y / (CELL.y * PackDrawerView.RANK_SPAN * PackDrawerView.CASSETTE_SCALE))
	assert_gt(ranks, 0)
	assert_eq(PackDrawerView.capacity_for(field, CELL), columns * ranks,
		"dieselbe Arithmetik wie das Raster")

func test_the_capacity_lays_out_without_shrinking_and_within_the_pit() -> void:
	# Der Deckel ist so gewählt, dass die volle Grube noch in voller Größe steht.
	var field := _field().size
	var capacity := PackDrawerView.capacity_for(field, CELL)
	var grid := PackDrawerView.grid_for(field, CELL, capacity)
	assert_almost_eq(float(grid["scale"]), PackDrawerView.CASSETTE_SCALE, 0.001,
		"am Deckel wird nichts gedrückt")
	var depth := float(grid["rows"]) * CELL.y * PackDrawerView.RANK_SPAN \
		* PackDrawerView.CASSETTE_SCALE
	assert_lte(depth, field.y + 0.001, "und die Ränge bleiben in der Grube")

func test_the_capacity_is_pure() -> void:
	var field := _field().size
	assert_eq(PackDrawerView.capacity_for(field, CELL),
		PackDrawerView.capacity_for(field, CELL), "dieselbe Rechnung")
	assert_gt(PackDrawerView.capacity_for(field * 2.0, CELL),
		PackDrawerView.capacity_for(field, CELL), "eine größere Grube fasst mehr")

func test_the_grid_is_deterministic() -> void:
	var field := _field().size
	for count in [3, 17, 55, 130]:
		assert_eq(PackDrawerView.grid_for(field, CELL, count),
			PackDrawerView.grid_for(field, CELL, count), "%d: dieselbe Rechnung" % count)

func test_a_rebuild_lays_the_same_drawer() -> void:
	var entries: Array[Dictionary] = [_entry(Pack.number_pack(), 7),
		_entry(Pack.material_pack(), 9)]
	var drawer := _drawer(entries)
	await wait_frames(2)
	var first := drawer.pack_anchor_px(7)
	drawer.build(entries, 8.0, false, CELL, Vector2(900, 150))
	await wait_frames(2)
	assert_eq(drawer.pack_anchor_px(7), first, "derselbe Platz, byteweise")

func test_the_derived_anchor_matches_the_measured_one() -> void:
	var entries: Array[Dictionary] = [_entry(Pack.number_pack(), 3),
		_entry(Pack.dice_mod_pack(), 5)]
	var drawer := _drawer(entries)
	await wait_frames(2)
	var field := PackDrawerView.pit_rect_in(drawer.get_global_rect(), 8.0)
	for i in entries.size():
		var uid := int(entries[i]["uid"])
		var measured := drawer.pack_anchor_px(uid)
		var derived := PackDrawerView.anchor_in(field, i, entries.size(), CELL)
		assert_almost_eq(measured.x, derived.x, 0.5, "uid %d: gleiche Spalte" % uid)
		assert_almost_eq(measured.y, derived.y, 0.5, "uid %d: gleiche Höhe" % uid)

func test_a_withheld_pack_keeps_its_spot_but_shows_no_chip() -> void:
	# Der Komet IST das Paket: sein Platz wartet, sein Chip erscheint erst mit der
	# Landung - und die Plätze der Nachbarn stehen, als läge es schon da.
	var entries: Array[Dictionary] = [_entry(Pack.number_pack(), 1),
		_entry(Pack.material_pack(), 2, true), _entry(Pack.dice_mod_pack(), 3)]
	var drawer := _drawer(entries)
	await wait_frames(2)
	assert_null(drawer.pack_button(2), "kein Chip für das fliegende Paket")
	assert_gt(drawer.pack_anchor_px(2).x, -1.0, "aber sein Platz steht")
	var third := drawer.pack_anchor_px(3)
	var derived := PackDrawerView.anchor_in(
		PackDrawerView.pit_rect_in(drawer.get_global_rect(), 8.0), 2, 3, CELL)
	assert_almost_eq(third.x, derived.x, 0.5, "der Nachbar zählt es mit")

# --- Chip-Schalen-Regel: der Knopf zeichnet nichts --------------------------------

func test_a_chip_draws_nothing_at_all() -> void:
	# Kein gemalter Schein mehr: er läge unter dem Loch. Gegriffen wird die
	# Kassette selbst, indem sie sich aus der Grube zieht.
	var drawer := _drawer([_entry(Pack.number_pack(), 4)] as Array[Dictionary])
	var chip := drawer.pack_button(4)
	assert_not_null(chip)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert_true(chip.get_theme_stylebox(state) is StyleBoxEmpty,
			"%s zeichnet nichts" % state)
	assert_null(chip.get_node_or_null("Halo"), "der Schein ist fort")

func test_the_drawer_names_the_pack_under_the_pointer() -> void:
	# GEFRAGT statt gemeldet: der Zeiger liegt auf dem Tisch, ein mouse_entered
	# käme nie an - scene_root hebt daran den Körper aus der Grube.
	var drawer := _drawer([_entry(Pack.number_pack(), 4),
		_entry(Pack.material_pack(), 5)] as Array[Dictionary])
	await wait_frames(2)
	assert_eq(drawer.hover_uid_at(drawer.pack_button(5).get_global_rect().get_center()), 5)
	assert_eq(drawer.hover_uid_at(Vector2(-500, -500)), 0, "daneben greift niemand")

func test_a_chip_reports_its_uid_when_pressed() -> void:
	var drawer := _drawer([_entry(Pack.number_pack(), 11)] as Array[Dictionary])
	var pressed: Array[int] = []
	drawer.pack_pressed.connect(func(uid: int) -> void: pressed.append(uid))
	drawer.pack_button(11).pressed.emit()
	assert_eq(pressed, [11] as Array[int])

func test_the_lock_bars_every_chip_and_dims_the_well() -> void:
	var drawer := _drawer([_entry(Pack.number_pack(), 6)] as Array[Dictionary], true)
	await wait_frames(2)
	assert_true(drawer.pack_button(6).disabled, "unterschrieben wird nicht gegriffen")
	var well: Panel = drawer.get_node("DrawerWell")
	assert_eq(well.modulate, PackDrawerView.LOCK_DIM)
	assert_eq(drawer.hover_uid_at(drawer.pack_button(6).get_global_rect().get_center()), 0,
		"und die Sperre schlägt das Überfahren")

func test_the_well_paints_only_its_frame() -> void:
	# Die Mitte ist ein echtes Loch (screen_glass.pit_rect) - ein gemalter Grund
	# läge hinter nichts.
	var drawer := _drawer([] as Array[Dictionary])
	var well: Panel = drawer.get_node("DrawerWell")
	var box: StyleBoxFlat = well.get_theme_stylebox("panel")
	assert_false(box.draw_center, "die Fassung, nicht der Grund")
	assert_gt(box.border_width_left, 0)

func test_the_pit_is_the_strip_minus_its_painted_frame() -> void:
	var strip := Rect2(Vector2(40, 200), Vector2(900, 150))
	var inset := PackDrawerView.rim_inset(8.0)
	assert_gt(inset, 0.0)
	assert_eq(PackDrawerView.pit_rect_in(strip, 8.0), strip.grow(-inset),
		"das Loch endet, wo der Rahmen beginnt")

# --- Auskunft ---------------------------------------------------------------------

func test_a_chip_explains_itself_on_hover() -> void:
	var drawer := _drawer([_entry(Pack.number_pack(), 8)] as Array[Dictionary])
	await wait_frames(2)
	var hint := drawer.hint_at(drawer.pack_button(8).get_global_rect().get_center())
	assert_eq(String(hint.get("title", "")), Pack.number_pack().display_name)
	assert_ne(String(hint.get("body", "")), "", "und seine Wirkung")
	assert_true(drawer.hint_at(Vector2(-500, -500)).is_empty(), "daneben schweigt es")

func test_a_bundle_carries_its_count_in_the_title() -> void:
	var bundle := Pack.fixed_engraving_pack(Engraving.pointer_engraving(), 5)
	var drawer := _drawer([_entry(bundle, 12)] as Array[Dictionary])
	await wait_frames(2)
	var hint := drawer.hint_at(drawer.pack_button(12).get_global_rect().get_center())
	assert_true(String(hint.get("title", "")).begins_with("5×"),
		"das Bündel nennt seine Zahl: '%s'" % hint.get("title", ""))

func test_an_empty_drawer_names_itself() -> void:
	var drawer := _drawer([] as Array[Dictionary])
	await wait_frames(2)
	var hint := drawer.hint_at(drawer.get_global_rect().get_center())
	assert_eq(String(hint.get("title", "")), PackDrawerView.EMPTY_TITLE)
	assert_eq(String(hint.get("body", "")), PackDrawerView.EMPTY_BODY,
		"Auskunft, keine Anweisung")
	assert_true(bool(hint.get("stock", false)),
		"die Marke, an der WorkshopView den Füllstand einsetzt")

func test_the_surface_answers_even_with_cards_lying_there() -> void:
	# Der Bestand am Deckel steht auf der FLÄCHE, nicht auf den Karten - eine
	# Kassette nennt ihren Inhalt, das Fach seinen Füllstand.
	var drawer := _drawer([_entry(Pack.number_pack(), 1)] as Array[Dictionary])
	await wait_frames(2)
	var corner := drawer.get_global_rect().position + Vector2(2, 2)
	assert_true(bool(drawer.hint_at(corner).get("stock", false)))
	var on_chip := drawer.hint_at(drawer.pack_button(1).get_global_rect().get_center())
	assert_false(on_chip.has("stock"), "auf der Kassette spricht die Kassette")

# --- Maßstab ----------------------------------------------------------------------

func test_the_drawer_reports_the_scale_it_built_with() -> void:
	var drawer := _drawer([_entry(Pack.number_pack(), 1)] as Array[Dictionary])
	assert_almost_eq(drawer.cell_scale(), PackDrawerView.CASSETTE_SCALE, 0.001)
	assert_almost_eq(drawer.cell_scale(),
		PackDrawerView.cell_scale_for(CELL, drawer.field.size, 1), 0.001,
		"gemessen und gerechnet sind dasselbe Maß")

func test_the_grip_is_the_whole_slot_minus_its_air() -> void:
	# In der Grube gäbe ein Knopf im Kappenmaß einen Streifen von wenigen Pixeln.
	var drawer := _drawer([_entry(Pack.number_pack(), 1)] as Array[Dictionary])
	await wait_frames(2)
	var slot := PackDrawerView.slot_size(drawer.field.size, CELL, 1)
	assert_almost_eq(drawer.pack_button(1).size.x,
		slot.x * (1.0 - PackDrawerView.SLOT_INSET * 2.0), 0.5)
	assert_gt(drawer.pack_button(1).size.y, CELL.y, "und er ist tiefer als die Kappe")

func test_the_anchor_is_the_centre_of_its_spot() -> void:
	# In der Grube STEHT die Kassette mittig auf ihrem Platz - über ihr schwebt
	# nichts mehr, für das Kopfraum abzuziehen wäre.
	var drawer := _drawer([_entry(Pack.number_pack(), 2)] as Array[Dictionary])
	await wait_frames(2)
	var chip := drawer.pack_button(2)
	var anchor := drawer.pack_anchor_px(2)
	assert_almost_eq(anchor.x, chip.get_global_rect().get_center().x, 0.01)
	assert_almost_eq(anchor.y, chip.get_global_rect().get_center().y, 0.01)

# --- Gesten: getippt wählt, gezogen sortiert, Doppelklick räumt auf ----------------

func _click(pressed: bool, at := Vector2.ZERO, double := false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.global_position = at
	event.double_click = double
	return event

func test_a_drag_onto_another_cell_reorders_and_never_presses() -> void:
	var drawer := _drawer([_entry(Pack.number_pack(), 1),
		_entry(Pack.material_pack(), 2)] as Array[Dictionary])
	await wait_frames(2)
	var moves: Array = []
	drawer.packs_reordered.connect(func(from_uid: int, to_uid: int) -> void:
		moves.append([from_uid, to_uid]))
	drawer._on_chip_input(_click(true), 1)
	drawer._on_chip_input(_click(false,
		drawer.pack_button(2).get_global_rect().get_center()), 1)
	assert_eq(moves, [[1, 2]], "losgelassen über der anderen Kassette = umgelegt")

func test_a_release_on_the_same_cell_stays_a_tap() -> void:
	var drawer := _drawer([_entry(Pack.number_pack(), 1),
		_entry(Pack.material_pack(), 2)] as Array[Dictionary])
	await wait_frames(2)
	var moves: Array = []
	drawer.packs_reordered.connect(func(from_uid: int, to_uid: int) -> void:
		moves.append([from_uid, to_uid]))
	drawer._on_chip_input(_click(true), 1)
	drawer._on_chip_input(_click(false,
		drawer.pack_button(1).get_global_rect().get_center()), 1)
	assert_true(moves.is_empty(), "auf sich selbst gelassen ist kein Umlegen - der Klick feuert am Knopf")

func test_a_release_over_nothing_drops_the_drag() -> void:
	var drawer := _drawer([_entry(Pack.number_pack(), 1)] as Array[Dictionary])
	await wait_frames(2)
	var moves: Array = []
	drawer.packs_reordered.connect(func(from_uid: int, to_uid: int) -> void:
		moves.append([from_uid, to_uid]))
	drawer._on_chip_input(_click(true), 1)
	drawer._on_chip_input(_click(false, Vector2(-999, -999)), 1)
	assert_true(moves.is_empty(), "ins Leere gelassen passiert nichts")

func test_a_double_click_on_the_empty_well_requests_a_tidy() -> void:
	var drawer := _drawer([_entry(Pack.number_pack(), 1)] as Array[Dictionary])
	await wait_frames(2)
	var tidies: Array[int] = []  # Lambda-Fänge kopieren ints - ein Array trägt die Referenz
	drawer.tidy_requested.connect(func() -> void: tidies.append(1))
	assert_not_null(drawer.get_node("WellCatch"), "die Fläche fängt selbst")
	drawer._on_well_input(_click(true, Vector2.ZERO, true))
	assert_eq(tidies.size(), 1, "der Doppelklick auf die Fläche räumt auf")
	drawer._on_well_input(_click(true))
	assert_eq(tidies.size(), 1, "ein einfacher Klick nicht")

func test_the_lock_bars_drag_and_tidy() -> void:
	var drawer := _drawer([_entry(Pack.number_pack(), 1),
		_entry(Pack.material_pack(), 2)] as Array[Dictionary], true)
	await wait_frames(2)
	var fired: Array[int] = []
	drawer.packs_reordered.connect(func(_a: int, _b: int) -> void: fired.append(1))
	drawer.tidy_requested.connect(func() -> void: fired.append(1))
	drawer._on_chip_input(_click(true), 1)
	drawer._on_chip_input(_click(false,
		drawer.pack_button(2).get_global_rect().get_center()), 1)
	drawer._on_well_input(_click(true, Vector2.ZERO, true))
	assert_eq(fired.size(), 0, "gesperrt wird weder gezogen noch aufgeräumt")
