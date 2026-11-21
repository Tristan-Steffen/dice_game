extends GutTest
## Tier-2-Tests des Magazins (PackDrawerView): VIER TRAYS nebeneinander unter der Walze,
## einer je SORTE, jeder mit eigener Grube, dazwischen Filz; je Tray REIHEN zu ACROSS
## liegenden Kassetten - und jeder ROLLT für sich senkrecht, in ganzen Reihen. Gezählt wird
## in WorkshopView, gefahren in ShelfStackView.

## Fußabdruck einer STEHENDEN Kassette (Grifftiefe × Kartenbreite) - daraus folgt
## der liegende (lie_cell).
const CELL := Vector2(30, 12)
## Ein Streifen, in den die vier Trays samt Fassungen und zwei Reihen passen.
const STRIP := Vector2(640, 140)

func _entry(pack: Pack, uid: int, withheld := false, cell := -1) -> Dictionary:
	pack.pack_uid = uid
	return {"uid": uid, "pack": pack, "withheld": withheld,
		"column": Pack.shelf_rank(pack), "cell": cell}

func _drawer(entries: Array[Dictionary], locked := false,
		strip := STRIP, scrolls: Array[int] = []) -> PackDrawerView:
	var drawer := PackDrawerView.new()
	add_child_autofree(drawer)
	drawer.size = strip
	drawer.build(entries, 8.0, locked, CELL, strip, scrolls)
	return drawer

## So viele Zahlen-Karten wie gewünscht, Platz k = k.
func _fill(count: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for i in count:
		entries.append(_entry(Pack.number_pack(), i + 1, false, i))
	return entries

func _field(strip := STRIP) -> Rect2:
	return PackDrawerView.field_in(Rect2(Vector2.ZERO, strip))

# --- Taxonomie: sie wohnt in data/ (Pack), die Farben hier -----------------------

func test_the_magazine_has_no_dice_shelf_any_more() -> void:
	assert_eq(Pack.SHELF_ORDER.size(), 4)
	assert_false(Pack.SHELF_ORDER.has("dice_pack"))

func test_an_engraving_pack_belongs_to_exactly_one_shelf() -> void:
	var pack := Pack.number_pack()
	assert_eq(Pack.shelf_of(pack), Engraving.CATEGORY_NUMBER)
	for category in [Engraving.CATEGORY_MATERIAL, Engraving.CATEGORY_DICE,
			Pack.SHELF_SPECIAL]:
		assert_false(Pack.pack_belongs(pack, category), "%s zaehlt es nicht" % category)

func test_a_fixed_special_pack_lies_on_the_stockpile() -> void:
	var pack := Pack.fixed_engraving_pack(Engraving.pointer_engraving())
	assert_eq(Pack.shelf_of(pack), Pack.SHELF_SPECIAL)

func test_the_pack_type_map_reads_both_ways() -> void:
	for pack_type: String in [Pack.TYPE_NUMBER, Pack.TYPE_MATERIAL,
			Pack.TYPE_DICE_MOD]:
		var category := Pack.shelf_for_pack_type(pack_type)
		assert_eq(Pack.pack_type_of_shelf(category), pack_type, "hin und zurück: %s" % pack_type)
	assert_eq(Pack.pack_type_of_shelf(Pack.SHELF_SPECIAL), "",
		"der Sonderbestand nennt seine Sorte nicht")

func test_every_shelf_order_key_has_a_colour_and_a_short_name() -> void:
	for category: String in Pack.SHELF_ORDER:
		assert_true(PackDrawerView.COLORS.has(category), "%s hat seine Farbe" % category)
		assert_ne(Pack.shelf_short(category), category, "%s hat ein Kürzel" % category)

# --- Sorte -> Spalte ---------------------------------------------------------------

## Je SORTE eine Spalte: COLUMNS ist SHELF_ORDER, und shelf_rank ordnet zu.
func test_one_column_per_sort() -> void:
	assert_eq(PackDrawerView.COLUMNS, Pack.SHELF_ORDER.size(), "vier Spalten, eine je Sorte")
	assert_eq(Pack.shelf_rank(Pack.number_pack()), 0)
	assert_eq(Pack.shelf_rank(Pack.material_pack()), 1)
	assert_eq(Pack.shelf_rank(Pack.dice_mod_pack()), 2)
	assert_eq(Pack.shelf_rank(Pack.catalyst(Pack.CATALYST_GROUND)), 3)
	assert_eq(Pack.shelf_rank(Pack.fixed_engraving_pack(Engraving.pointer_engraving())), 3)

# --- Das Raster: feste Kartengröße, ein Fenster aus PLACES Plätzen je Spalte --------

func test_die_liegende_karte_folgt_aus_der_stehenden() -> void:
	var lie := PackDrawerView.lie_cell(CELL)
	assert_almost_eq(lie.y, CELL.y * PackDrawerView.CASSETTE_SCALE, 0.001)
	assert_almost_eq(lie.x, lie.y * PackDrawerView.CARD_ASPECT, 0.001)

## Das FELD trägt je Spalte genau PLACES Reihen zu ACROSS Karten - nie eine weniger.
func test_the_field_carries_exactly_the_window_places() -> void:
	var field := PackDrawerView.field_for(PackDrawerView.lie_cell(CELL))
	assert_eq(PackDrawerView.places_for(field, CELL), PackDrawerView.PLACES)
	assert_eq(PackDrawerView.PLACES, 2, "zwei Reihen je Spalte")
	assert_eq(PackDrawerView.ACROSS, 2, "zu je zwei Karten nebeneinander")
	assert_eq(PackDrawerView.window_cards_for(field, CELL), 4, "vier sichtbar je Sorte")
	var lie := PackDrawerView.lie_cell(CELL)
	assert_almost_eq(PackDrawerView.column_width(field), PackDrawerView.pit_width_for(lie),
		0.001)
	assert_almost_eq(PackDrawerView.pit_width_for(lie), lie.x * (PackDrawerView.RAIL_ROOM
		+ PackDrawerView.CARD_ROOM * float(PackDrawerView.ACROSS)), 0.001)
	assert_gt(PackDrawerView.slot_size(field, CELL).x, lie.x, "die Karte paßt in ihren Platz")

## Rang k liegt in Reihe k / ACROSS auf Querplatz k % ACROSS.
func test_a_rank_maps_to_row_and_across() -> void:
	assert_eq(PackDrawerView.row_of(0), 0)
	assert_eq(PackDrawerView.row_of(1), 0)
	assert_eq(PackDrawerView.row_of(2), 1)
	assert_eq(PackDrawerView.across_of(3), 1)
	assert_eq(PackDrawerView.row_of(-1), -1, "über dem Fenster")
	assert_eq(PackDrawerView.across_of(-1), 1)
	assert_eq(PackDrawerView.rows_for(5), 3)

func test_spots_fill_a_row_then_run_down_the_column() -> void:
	var field := _field().size
	var places := PackDrawerView.places_for(field, CELL)
	var first := PackDrawerView.spot_for(0, field, CELL)
	var beside := PackDrawerView.spot_for(1, field, CELL)
	var second := PackDrawerView.spot_for(PackDrawerView.ACROSS, field, CELL)
	assert_almost_eq(beside.y, first.y, 0.01, "Rang 1 liegt in derselben Reihe")
	assert_almost_eq(beside.x - first.x, PackDrawerView.slot_size(field, CELL).x, 0.01,
		"einen Platz rechts daneben")
	assert_almost_eq(second.y - first.y, field.y / float(places), 0.01, "Rang 2 eine Reihe tiefer")
	assert_almost_eq(second.x, first.x, 0.01)
	for column in range(1, PackDrawerView.COLUMNS):
		var right := PackDrawerView.spot_for(0, field, CELL, column)
		assert_almost_eq(right.y, first.y, 0.01)
		assert_almost_eq(right.x - first.x, (PackDrawerView.column_width(field)
			+ PackDrawerView.TRAY_GAP_PX) * float(column), 0.01)
	var rail := PackDrawerView.rail_width(field)
	var last := PackDrawerView.spot_for(1, field, CELL)
	assert_almost_eq(PackDrawerView.column_width(field) - rail
		- (last.x + PackDrawerView.slot_size(field, CELL).x * 0.5), 0.0, 0.01,
		"rechts neben dem letzten Platz liegt nur noch die Rollschiene")

## Das Feld ist die Vereinigung der Gruben: sie füllen es ganz, dazwischen je Fassung,
## Filz, Fassung.
func test_the_pits_fill_the_field_with_equal_gaps() -> void:
	var field := _field().size
	var rects := PackDrawerView.column_rects(field)
	assert_eq(rects.size(), PackDrawerView.COLUMNS)
	assert_almost_eq(rects[0].position.x, 0.0, 0.001)
	for i in range(1, rects.size()):
		assert_almost_eq(rects[i].position.x - rects[i - 1].end.x,
			PackDrawerView.TRAY_GAP_PX, 0.001)
	assert_almost_eq(field.x - rects[rects.size() - 1].end.x, 0.0, 0.001)

## Die TRAYS samt Fassung überlappen nie, und zwischen je zwei liegt derselbe Filz.
func test_the_trays_never_overlap_and_leave_the_same_felt() -> void:
	var trays := PackDrawerView.tray_rects(_field().size)
	assert_eq(trays.size(), PackDrawerView.COLUMNS)
	for i in range(1, trays.size()):
		assert_false(trays[i].intersects(trays[i - 1]), "Tray %d steht frei" % (i + 1))
		assert_almost_eq(trays[i].position.x - trays[i - 1].end.x,
			PackDrawerView.FELT_GAP_PX, 0.001, "derselbe Filz")
	var field := _field()
	var shelf := Rect2(Vector2.ZERO, STRIP)
	var outer := trays[0]
	for tray in trays:
		outer = outer.merge(tray)
	assert_true(Rect2(outer.position + field.position, outer.size).is_equal_approx(shelf),
		"zusammen sind sie das ganze Magazin")
	assert_almost_eq(trays[0].end.y - field.size.y, PackDrawerView.BAR_PX, 0.001,
		"unten das Band der Lichtleiste")

func test_shelf_and_field_invert_each_other() -> void:
	var card := PackDrawerView.lie_cell(CELL)
	var shelf := Rect2(Vector2(40, 200), PackDrawerView.shelf_for(card))
	var field := PackDrawerView.field_in(shelf)
	assert_true(field.size.is_equal_approx(PackDrawerView.field_for(card)))
	assert_true(shelf.encloses(field))

## Jeder Punkt der Grube gehört einer Spalte: die Grenzen liegen mitten in den Rändern.
func test_column_at_splits_in_the_gaps() -> void:
	var field := _field().size
	var rects := PackDrawerView.column_rects(field)
	for i in rects.size():
		assert_eq(PackDrawerView.column_at(field, rects[i].get_center().x), i)
	assert_eq(PackDrawerView.column_at(field, -50.0), 0)
	assert_eq(PackDrawerView.column_at(field, field.x + 50.0), PackDrawerView.COLUMNS - 1)

# --- Das ROLLEN --------------------------------------------------------------------

## RASTEN darf eine Spalte nur 0 .. bis ihre letzte Karte am Fensterrand steht (leer:
## nur 0) - gezogen wird beliebig weit, losgelassen federt sie dorthin zurück.
func test_the_scroll_clamps_and_snaps_to_whole_rows() -> void:
	assert_eq(PackDrawerView.max_scroll(0, 2), 0, "leer rastet sie am Anfang")
	assert_eq(PackDrawerView.max_scroll(4, 2), 0, "vier Karten füllen genau das Fenster")
	assert_eq(PackDrawerView.max_scroll(5, 2), 1, "die fünfte öffnet eine dritte Reihe")
	assert_eq(PackDrawerView.max_scroll(10, 2), 3)
	assert_eq(PackDrawerView.clamp_scroll(-2, 10, 2), 0)
	assert_eq(PackDrawerView.clamp_scroll(99, 10, 2), 3)
	assert_eq(PackDrawerView.snap_scroll(0, -900.0, 100.0, 0, 2), 0,
		"eine leere Spalte federt nach jedem Zug an den Anfang zurück")
	assert_eq(PackDrawerView.snap_scroll(0, -100.0, 100.0, 10, 2), 1,
		"einen Platz nach oben gezogen rollt sie einen weiter")
	assert_eq(PackDrawerView.snap_scroll(0, -140.0, 100.0, 10, 2), 1, "abgerundet")
	assert_eq(PackDrawerView.snap_scroll(0, -160.0, 100.0, 10, 2), 2, "aufgerundet")
	assert_eq(PackDrawerView.snap_scroll(2, 900.0, 100.0, 10, 2), 0, "nie unter 0")
	assert_eq(PackDrawerView.snap_scroll(5, -900.0, 100.0, 10, 2), 3, "nie über das Ende")

## Eine gerollte Spalte legt ihre vorderen Karten unter den Filz: kein Chip, aber der
## Platz steht weiter - über dem Fenster. Die anderen Spalten rollen nicht mit.
func test_a_rolled_out_card_keeps_its_place_but_carries_no_chip() -> void:
	var places := PackDrawerView.places_for(_field().size, CELL)
	var entries := _fill(places * PackDrawerView.ACROSS + 4)
	entries.append(_entry(Pack.material_pack(), 99, false, 0))
	var drawer := _drawer(entries, false, STRIP, [1, 0, 0, 0] as Array[int])
	await wait_frames(2)
	assert_null(drawer.pack_button(1), "Rang 0 ist mit seiner Reihe hinausgerollt")
	assert_null(drawer.pack_button(2), "Rang 1 ebenso")
	assert_lt(drawer.place_of_pack(1), 0)
	assert_lt(drawer.pack_seat_px(1).y, drawer.get_global_rect().position.y
		+ drawer.field.position.y, "sie liegt oben unter der Wand")
	assert_not_null(drawer.pack_button(3), "Rang 2 liegt jetzt vorn im Fenster")
	assert_eq(drawer.place_of_pack(3), 0)
	assert_false(drawer.shows_pack(1))
	assert_true(drawer.shows_pack(3))
	assert_not_null(drawer.pack_button(99), "die Material-Spalte steht, wo sie stand")
	assert_eq(drawer.place_of_pack(99), 0)

## Das Liefer-Licht einer hinausgerollten Karte endet am RAND ihrer Spalte.
func test_a_rolled_out_card_aims_at_the_column_edge() -> void:
	var places := PackDrawerView.places_for(_field().size, CELL)
	var cards := places * PackDrawerView.ACROSS * 3
	var drawer := _drawer(_fill(cards), false, STRIP, [1, 0, 0, 0] as Array[int])
	await wait_frames(2)
	var origin := drawer.get_global_rect().position
	assert_almost_eq(drawer.pack_anchor_px(1).y, origin.y + drawer.field.position.y, 0.5,
		"oben hinaus: der obere Rand")
	assert_almost_eq(drawer.pack_anchor_px(1).x, drawer.pack_seat_px(1).x, 0.5,
		"in ihrer Spalte")
	var far := cards
	assert_almost_eq(drawer.pack_anchor_px(far).y, origin.y + drawer.field.end.y, 0.5,
		"unten noch nicht gezeigt: der untere Rand")

## ALLE VIER Sorten liegen zugleich im Bild, jede in ihrer Spalte, Platz 0 oben.
func test_every_sort_shows_in_its_own_column() -> void:
	var entries: Array[Dictionary] = [_entry(Pack.number_pack(), 1, false, 0),
		_entry(Pack.material_pack(), 2, false, 0), _entry(Pack.dice_mod_pack(), 3, false, 0),
		_entry(Pack.catalyst(Pack.CATALYST_GROUND), 4, false, 0)]
	var drawer := _drawer(entries)
	await wait_frames(2)
	for uid in [1, 2, 3, 4]:
		assert_not_null(drawer.pack_button(uid), "uid %d trägt einen Chip" % uid)
		assert_eq(drawer.column_of_pack(uid), uid - 1)
		assert_almost_eq(drawer.pack_seat_px(uid).y, drawer.pack_seat_px(1).y, 0.5)
		if uid > 1:
			assert_gt(drawer.pack_seat_px(uid).x, drawer.pack_seat_px(uid - 1).x,
				"die nächste Sorte liegt rechts daneben")

func test_a_withheld_pack_keeps_its_spot_but_shows_no_chip() -> void:
	var entries: Array[Dictionary] = [_entry(Pack.number_pack(), 1, false, 0),
		_entry(Pack.number_pack(), 2, true, 1), _entry(Pack.number_pack(), 3, false, 2)]
	var drawer := _drawer(entries)
	await wait_frames(2)
	assert_null(drawer.pack_button(2))
	assert_gt(drawer.pack_anchor_px(2).x, -1.0, "aber sein Platz steht")

func test_a_rebuild_lays_the_same_drawer() -> void:
	var entries: Array[Dictionary] = [_entry(Pack.number_pack(), 7, false, 0),
		_entry(Pack.number_pack(), 9, false, 1)]
	var drawer := _drawer(entries)
	await wait_frames(2)
	var first := drawer.pack_anchor_px(7)
	drawer.build(entries, 8.0, false, CELL, STRIP)
	await wait_frames(2)
	assert_eq(drawer.pack_anchor_px(7), first, "derselbe Platz, byteweise")

func test_the_derived_anchor_matches_the_measured_one() -> void:
	var entries := _fill(2)
	entries.append(_entry(Pack.material_pack(), 50, false, 0))
	entries.append(_entry(Pack.material_pack(), 51, false, 1))
	var drawer := _drawer(entries)
	await wait_frames(2)
	var field := PackDrawerView.field_in(drawer.get_global_rect())
	for entry in entries:
		var uid := int(entry["uid"])
		var measured := drawer.pack_anchor_px(uid)
		var derived := PackDrawerView.anchor_in(field, int(entry["cell"]), CELL,
			int(entry["column"]))
		assert_almost_eq(measured.x, derived.x, 0.5)
		assert_almost_eq(measured.y, derived.y, 0.5)
# --- Chip-Schalen-Regel -------------------------------------------------------------

func test_a_chip_draws_nothing_at_all() -> void:
	var drawer := _drawer([_entry(Pack.number_pack(), 4, false, 0)] as Array[Dictionary])
	var chip := drawer.pack_button(4)
	assert_not_null(chip)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert_true(chip.get_theme_stylebox(state) is StyleBoxEmpty, "%s zeichnet nichts" % state)

func test_the_drawer_names_the_pack_under_the_pointer() -> void:
	var drawer := _drawer(_fill(2))
	await wait_frames(2)
	assert_eq(drawer.hover_uid_at(drawer.pack_button(2).get_global_rect().get_center()), 2)
	assert_eq(drawer.hover_uid_at(Vector2(-500, -500)), 0)

func test_a_chip_reports_its_uid_when_pressed() -> void:
	var drawer := _drawer([_entry(Pack.number_pack(), 11, false, 0)] as Array[Dictionary])
	var pressed: Array[int] = []
	drawer.pack_pressed.connect(func(uid: int) -> void: pressed.append(uid))
	drawer.pack_button(11).pressed.emit()
	assert_eq(pressed, [11] as Array[int])

func test_the_lock_bars_every_chip() -> void:
	var drawer := _drawer([_entry(Pack.number_pack(), 6, false, 0)] as Array[Dictionary], true)
	await wait_frames(2)
	assert_true(drawer.pack_button(6).disabled)
	assert_eq(drawer.hover_uid_at(drawer.pack_button(6).get_global_rect().get_center()), 0)

## Die Fassungen sind Körper der Trays: das Fenster malt keinen Rahmen mehr.
func test_the_drawer_paints_no_frame() -> void:
	var drawer := _drawer([] as Array[Dictionary])
	assert_null(drawer.get_node_or_null("DrawerWell"), "der graue Gesamtrahmen ist tot")
	for child in drawer.get_children():
		assert_false(child is Panel, "%s malt nichts" % child.name)

# --- Rollschiene und Lichtleiste ----------------------------------------------------

## Der Schieber ist so lang wie sichtbare durch alle Reihen und steht, wo gerollt ist.
func test_the_rail_thumb_reads_rows_and_scroll() -> void:
	assert_eq(PackDrawerView.rail_thumb(0, 2, 0.0), Vector2(0.0, 1.0), "leer füllt er die Schiene")
	assert_eq(PackDrawerView.rail_thumb(2, 2, 0.0), Vector2(0.0, 1.0), "alles im Fenster ebenso")
	assert_eq(PackDrawerView.rail_thumb(4, 2, 0.0), Vector2(0.0, 0.5))
	assert_eq(PackDrawerView.rail_thumb(4, 2, 2.0), Vector2(0.5, 0.5), "ganz unten")
	assert_eq(PackDrawerView.rail_thumb(4, 2, 1.0), Vector2(0.25, 0.5))
	assert_eq(PackDrawerView.rail_thumb(4, 2, 0.5), Vector2(0.125, 0.5), "ein Zug: gebrochen")
	assert_eq(PackDrawerView.rail_thumb(4, 2, 9.0), Vector2(0.5, 0.5), "nie aus der Schiene")
	assert_eq(PackDrawerView.rail_thumb(4, 2, -3.0), Vector2(0.0, 0.5))

## Die Lichtleiste nennt Namen und sichtbar/gesamt, leer nur den Namen und 0.
func test_the_bar_names_the_sort_and_counts() -> void:
	assert_eq(PackDrawerView.bar_text(0, 7), "Zahl 7", "nur die Gesamtzahl")
	assert_eq(PackDrawerView.bar_text(1, 2), "Material 2")
	assert_eq(PackDrawerView.bar_text(2, 0), "Rune 0")

## Der Zug am Schieber: er folgt dem Zeiger, der Inhalt rollt übersetzt und gegenläufig.
func test_dragging_the_rail_thumb_rolls_the_tray() -> void:
	# 8 Karten = 4 Reihen, 2 im Fenster: der Schieber ist halb so lang wie die Schiene.
	assert_almost_eq(PackDrawerView.rail_drag(50.0, 8, 0, 100.0), -100.0, 0.001,
		"50 px am Schieber = eine Reihe weiter")
	assert_almost_eq(PackDrawerView.rail_drag(500.0, 8, 0, 100.0), -200.0, 0.001,
		"nie über das Ende")
	assert_almost_eq(PackDrawerView.rail_drag(-500.0, 8, 1, 100.0), 100.0, 0.001,
		"nie über den Anfang")
	assert_eq(PackDrawerView.rail_drag(80.0, 4, 0, 100.0), 0.0, "alles sichtbar: nichts rollt")

func test_the_rail_grip_lies_at_the_right_edge_of_each_tray() -> void:
	var field := PackDrawerView.field_for(Vector2(194.4, 129.6))
	for pit in PackDrawerView.column_rects(field):
		assert_true(PackDrawerView.on_rail(field, pit.end.x - 2.0))
		assert_false(PackDrawerView.on_rail(field, pit.get_center().x), "über den Karten nicht")
	for column in PackDrawerView.COLUMNS:
		assert_true(PackDrawerView.BAR_NAMES.has(Pack.SHELF_ORDER[column]))

# --- Auskunft -----------------------------------------------------------------------

func test_a_chip_explains_itself_on_hover() -> void:
	var drawer := _drawer([_entry(Pack.number_pack(), 8, false, 0)] as Array[Dictionary])
	await wait_frames(2)
	var hint := drawer.hint_at(drawer.pack_button(8).get_global_rect().get_center())
	assert_eq(String(hint.get("title", "")), Pack.number_pack().display_name)
	assert_ne(String(hint.get("body", "")), "")
	assert_true(drawer.hint_at(Vector2(-500, -500)).is_empty())

func test_a_bundle_carries_its_count_in_the_title() -> void:
	var bundle := Pack.fixed_engraving_pack(Engraving.pointer_engraving(), 5)
	var drawer := _drawer([_entry(bundle, 12, false, 0)] as Array[Dictionary])
	await wait_frames(2)
	var hint := drawer.hint_at(drawer.pack_button(12).get_global_rect().get_center())
	assert_true(String(hint.get("title", "")).begins_with("5×"))

func test_an_empty_drawer_names_itself() -> void:
	var drawer := _drawer([] as Array[Dictionary])
	await wait_frames(2)
	var hint := drawer.hint_at(drawer.get_global_rect().get_center())
	assert_eq(String(hint.get("title", "")), PackDrawerView.EMPTY_TITLE)
	assert_eq(String(hint.get("body", "")), PackDrawerView.EMPTY_BODY)
	assert_true(bool(hint.get("stock", false)))

func test_the_grip_is_the_whole_slot_minus_its_air() -> void:
	var drawer := _drawer([_entry(Pack.number_pack(), 1, false, 0)] as Array[Dictionary])
	await wait_frames(2)
	var slot := PackDrawerView.slot_size(drawer.field.size, CELL)
	assert_almost_eq(drawer.pack_button(1).size.y,
		slot.y * (1.0 - PackDrawerView.SLOT_INSET * 2.0), 0.5)

# --- Gesten: getippt wählt, gezogen rollt, Doppelklick räumt auf -------------------

func _click(pressed: bool, at := Vector2.ZERO, double := false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.global_position = at
	event.double_click = double
	return event

func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event

## Ein Zug über die Schwelle ROLLT seine Spalte: gemeldet werden Spalte und Weg,
## losgelassen das Einrasten - und der Knopf-Klick danach wird geschluckt.
func test_a_drag_scrolls_and_swallows_the_press() -> void:
	var entries := _fill(2)
	entries.append(_entry(Pack.dice_mod_pack(), 40, false, 0))
	var drawer := _drawer(entries)
	await wait_frames(2)
	var dragged: Array[float] = []
	var released: Array[float] = []
	var columns: Array[int] = []
	var pressed: Array[int] = []
	drawer.scroll_dragged.connect(func(column: int, px: float) -> void:
		columns.append(column)
		dragged.append(px))
	drawer.scroll_released.connect(func(column: int, px: float) -> void:
		columns.append(column)
		released.append(px))
	drawer.pack_pressed.connect(func(uid: int) -> void: pressed.append(uid))
	var start := drawer.pack_button(40).get_global_rect().get_center()
	drawer._track_drag(_click(true, start))
	drawer._track_drag(_motion(start + Vector2(0, -3)))
	assert_true(dragged.is_empty(), "unter der Schwelle rollt nichts")
	drawer._track_drag(_motion(start + Vector2(0, -60)))
	assert_eq(dragged, [-60.0] as Array[float])
	assert_true(drawer.dragging())
	drawer._track_drag(_click(false, start + Vector2(0, -60)))
	drawer.pack_button(40).pressed.emit()
	assert_true(pressed.is_empty(), "ein Zug ist kein Tipp")
	await wait_frames(1)
	assert_eq(released, [-60.0] as Array[float], "gemeldet nach dem Ereignis")
	assert_eq(columns, [2, 2] as Array[int], "es rollt die Spalte unter dem Druck: Runen")
	assert_false(drawer.dragging())

func test_a_tap_stays_a_tap() -> void:
	var drawer := _drawer(_fill(1))
	await wait_frames(2)
	var pressed: Array[int] = []
	drawer.pack_pressed.connect(func(uid: int) -> void: pressed.append(uid))
	var at := drawer.pack_button(1).get_global_rect().get_center()
	drawer._track_drag(_click(true, at))
	drawer._track_drag(_click(false, at))
	drawer.pack_button(1).pressed.emit()
	assert_eq(pressed, [1] as Array[int])

func test_a_drag_on_the_well_scrolls_too() -> void:
	var drawer := _drawer(_fill(1))
	await wait_frames(2)
	var dragged: Array[float] = []
	drawer.scroll_dragged.connect(func(_column: int, px: float) -> void: dragged.append(px))
	drawer._on_well_input(_click(true, Vector2(100, 40)))
	drawer._on_well_input(_motion(Vector2(100, 80)))
	assert_eq(dragged, [40.0] as Array[float], "über der leeren Fläche rollt es ebenso")

func test_a_double_click_on_the_empty_well_requests_a_tidy() -> void:
	var drawer := _drawer(_fill(1))
	await wait_frames(2)
	var tidies: Array[int] = []
	drawer.tidy_requested.connect(func() -> void: tidies.append(1))
	drawer._on_well_input(_click(true, Vector2.ZERO, true))
	assert_eq(tidies.size(), 1)
	drawer._on_well_input(_click(true))
	assert_eq(tidies.size(), 1, "ein einfacher Klick nicht")

func test_the_lock_bars_the_tidy() -> void:
	var drawer := _drawer(_fill(2), true)
	await wait_frames(2)
	var fired: Array[int] = []
	drawer.tidy_requested.connect(func() -> void: fired.append(1))
	drawer._on_well_input(_click(true, Vector2.ZERO, true))
	assert_eq(fired.size(), 0)

## Das MULTIPLIKATOR-NETZ trägt Lila statt Zahlen-Grün, gestuft wie jede Sorte.
func test_a_multiplier_card_is_purple() -> void:
	var pack := Pack.multiplier_pack()
	assert_eq(PackDrawerView.pack_tint(pack), PackDrawerView.MULTIPLIER_TINT)
	assert_ne(PackDrawerView.pack_tint(Pack.number_pack()), PackDrawerView.MULTIPLIER_TINT)
	assert_eq(PackDrawerView.card_shade(Pack.shelf_of(pack), Pack.TIER_NORMAL, "",
		pack.stamp_net), DataCellView.tier_shade(PackDrawerView.MULTIPLIER_TINT, Pack.TIER_NORMAL))
	assert_ne(PackDrawerView.MULTIPLIER_TINT, PackDrawerView.COLORS[Pack.SHELF_SPECIAL],
		"und liest nicht als Sonderbestand")

## Der ROHLING traegt STAHLBLAU - leer wie gefuellt, und auch am KOERPER: die Farbe
## ist das einzige, woran der Spieler ihn im Magazin erkennt (Spieler-Wunsch
## 2026-10-26; bis dahin las er als Sonderbestand).
func test_a_blank_card_is_steel_blue() -> void:
	var blank := Pack.blank_card()
	assert_eq(PackDrawerView.pack_tint(blank), PackDrawerView.BLANK_TINT)
	blank.stamp_net[0] = StampNet.compound_cell(4, 9)
	assert_eq(PackDrawerView.pack_tint(blank), PackDrawerView.BLANK_TINT,
		"verdichtet bleibt sie es")
	assert_eq(PackDrawerView.card_shade(Pack.shelf_of(blank), blank.tier, "",
		blank.stamp_net, true), PackDrawerView.BLANK_TINT,
		"groessenlos wie das Gold: keine Stufe wuescht den Ton zu Grau")
	assert_ne(PackDrawerView.BLANK_TINT, PackDrawerView.COLORS[Pack.SHELF_SPECIAL],
		"und liest nicht als Sonderbestand")
	var cell := DataCellView.new()
	add_child_autofree(cell)
	cell.setup(Pack.shelf_of(blank), blank.tier, blank.stamp_net, true)
	assert_eq(cell.tint, PackDrawerView.BLANK_TINT, "der Koerper traegt denselben Ton")

## Die Faktor-Zelle schreibt ihren Faktor, im Karten-Netz wie in der Summe.
func test_a_factor_cell_reads_as_its_factor() -> void:
	var net := StampNet.empty_net()
	net[2] = StampNet.factor_cell(4)
	var card := PressNetView.stamp_net(net, 30.0)
	add_child_autofree(card)
	assert_true(_texts(card).has("×4"), "die Karte zeigt ×4")
	var sum := PressNetView.sum_net(SeriesResolver.resolve([net], null), 30.0)
	add_child_autofree(sum)
	assert_true(_texts(sum).has("×4"), "die Summe ohne Bonus zeigt den Faktor")

func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		out.append_array(_texts(child))
	return out
