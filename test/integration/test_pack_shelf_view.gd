extends GutTest
## Tier-2-Tests der Regal-Leiste (PackShelfView): sie liegt seit dem Umbau IM
## Werkstatt-Fenster auf dessen Unterkante, nicht mehr als eigenes Schubladen-
## Fenster unter der Werkbank. Gezählt wird in WorkshopView - hier steht nur, was
## ankommt.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

func _shelf(entries: Array[Dictionary], locked := false) -> PackShelfView:
	var shelf := PackShelfView.new()
	add_child_autofree(shelf)
	shelf.build(entries, 8.0, locked)
	return shelf

func _entry(category: String, pack: Pack, count: int) -> Dictionary:
	return {"category": category, "pack": pack, "count": count}

# --- Taxonomie: welches Paket liegt auf welchem Stapel ---------------------------

func test_a_dice_pack_belongs_only_to_the_dice_shelf() -> void:
	var pack := Pack.dice_pack(DiceOffer.TEMPLATES[0])
	assert_eq(PackShelfView.shelf_of(pack), PackShelfView.CATEGORY_DICE_PACK)
	for category in [Engraving.CATEGORY_NUMBER, Engraving.CATEGORY_MATERIAL,
			Engraving.CATEGORY_DICE, PackShelfView.CATEGORY_SPECIAL]:
		assert_false(PackShelfView.pack_belongs(pack, category), "%s zaehlt es nicht" % category)

func test_a_fixed_special_pack_lies_on_the_stockpile_stack() -> void:
	# Sonderposten liegen nur im Sonderbestand - dieselbe Regel wie frueher.
	var pack := Pack.fixed_engraving_pack(Engraving.pointer_engraving())
	assert_eq(PackShelfView.shelf_of(pack), PackShelfView.CATEGORY_SPECIAL)

func test_an_engraving_pack_lies_on_its_category_stack() -> void:
	assert_eq(PackShelfView.shelf_of(Pack.number_pack()), Engraving.CATEGORY_NUMBER)
	assert_eq(PackShelfView.shelf_of(Pack.material_pack()), Engraving.CATEGORY_MATERIAL)

func test_the_delivery_route_reads_the_pack_type() -> void:
	# Der Laden kennt nur den Typ - nie einen Fixinhalt.
	assert_eq(PackShelfView.shelf_category_for_pack_type(Pack.TYPE_DICE),
		PackShelfView.CATEGORY_DICE_PACK)
	assert_eq(PackShelfView.shelf_category_for_pack_type(Pack.TYPE_MATERIAL),
		Engraving.CATEGORY_MATERIAL)

# --- Die Leiste selbst ------------------------------------------------------------

func test_every_sort_gets_its_bay_stocked_or_not() -> void:
	# Feste Plätze: die Leiste zeigt Geografie, nicht Bestand.
	var shelf := _shelf([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 2)])
	assert_eq(shelf.get_child_count(), PackShelfView.SHELF_ORDER.size(), "fünf Buchten, immer")
	assert_true(shelf.bay_stocked(Engraving.CATEGORY_NUMBER))
	assert_false(shelf.bay_stocked(Engraving.CATEGORY_MATERIAL), "diese Bucht steht leer")
	assert_gt(shelf.stack_anchor_px(Engraving.CATEGORY_NUMBER).x, -1.0)
	assert_gt(shelf.stack_anchor_px(Engraving.CATEGORY_MATERIAL).x, -1.0,
		"auch die leere Bucht hat ihren Anker - dorthin ploppt die nächste Lieferung")

func test_an_empty_shelf_still_shows_all_five_bays() -> void:
	var shelf := _shelf([])
	assert_eq(shelf.get_child_count(), PackShelfView.SHELF_ORDER.size())
	for category: String in PackShelfView.SHELF_ORDER:
		assert_not_null(shelf.segment_of(category), "%s behält ihren Sitz" % category)
		assert_true(shelf.stack_button(category).disabled, "%s fängt nichts" % category)

func test_an_empty_bay_is_inert_but_names_its_sort() -> void:
	# Sie fängt keinen Klick - aber sie ist nicht mehr anonym.
	var shelf := _shelf([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 1)])
	var chip := shelf.stack_button(Engraving.CATEGORY_MATERIAL)
	assert_true(chip.disabled, "kein Klick")
	assert_eq(chip.tooltip_text, "", "kein Sprechblasen-Wort")
	assert_eq(chip.get_child_count(), 0, "keine Marke, kein Siegel am Griff")
	assert_eq(String(chip.get_meta("title", "")),
		PackShelfView.bay_name(Engraving.CATEGORY_MATERIAL), "aber sie nennt ihre Sorte")

# --- Die Schale: erhabene Lippe, farbiger Metallgrund ------------------------------

func _lip_box(shelf: PackShelfView, category: String) -> StyleBoxFlat:
	return shelf.segment_of(category).get_theme_stylebox("panel")

func _band_box(shelf: PackShelfView, category: String, band: String) -> StyleBoxFlat:
	var node: Panel = shelf.segment_of(category).get_node(band)
	return node.get_theme_stylebox("panel")

func _ramp(shelf: PackShelfView, category: String) -> Gradient:
	var texture: GradientTexture2D = shelf.well_of(category).texture
	return texture.gradient

func test_every_bay_well_carries_its_sort_colour() -> void:
	# Der Grund IST die Kennung - gefüllt wie leer, aus der EINEN Farbquelle.
	var shelf := _shelf([])
	for category: String in PackShelfView.SHELF_ORDER:
		assert_not_null(shelf.well_of(category), "%s hat ihren Grund" % category)
		var ramp := _ramp(shelf, category)
		assert_eq(ramp.colors.size(), PackShelfView.WELL_STOPS.size(), "%s: vier Stufen" % category)
		var sort: Color = PackShelfView.COLORS[category]
		for i in ramp.colors.size():
			var stufe: Color = ramp.colors[i]
			assert_eq(stufe, PackShelfView.well_color(category, float(PackShelfView.WELL_MIX[i])),
				"%s: Stufe %d kommt aus der Sortenquelle" % [category, i])
		# Der stärkste Kanal der Sorte bleibt der stärkste im Grund: er ist farbig.
		var glanz := PackShelfView.well_color(category, float(PackShelfView.WELL_MIX[1]))
		var sort_max := maxf(maxf(sort.r, sort.g), sort.b)
		var well_max := maxf(maxf(glanz.r, glanz.g), glanz.b)
		assert_almost_eq(well_max, _channel(glanz, _dominant(sort)), 0.001,
			"%s: derselbe Kanal führt" % category)
		assert_lt(well_max, sort_max * 0.55,
			"%s: aber deutlich dunkler als die Sorte - hell ist die Kassette" % category)

func test_the_well_is_darkest_under_the_lip_and_brightest_in_its_sheen() -> void:
	# Der Verlauf IST der Schalen-Read: Schatten oben, Glanzband, satter Mittelton,
	# dunklerer Boden.
	var mixes := PackShelfView.WELL_MIX
	assert_lt(float(mixes[0]), float(mixes[3]), "unter der Lippe am dunkelsten")
	assert_gt(float(mixes[1]), float(mixes[2]), "das Glanzband ist die hellste Stufe")
	assert_gt(float(mixes[2]), float(mixes[3]), "und darunter fällt es zum Boden ab")
	var stops := PackShelfView.WELL_STOPS
	for i in range(1, stops.size()):
		assert_gt(float(stops[i]), float(stops[i - 1]), "die Stufen laufen von oben nach unten")

func test_the_lip_reads_as_raised_light_from_above() -> void:
	var shelf := _shelf([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 1)])
	var lip := _lip_box(shelf, Engraving.CATEGORY_NUMBER)
	var licht := _band_box(shelf, Engraving.CATEGORY_NUMBER, "LipLight")
	var schatten := _band_box(shelf, Engraving.CATEGORY_NUMBER, "LipShade")
	assert_gt(licht.border_color.v, lip.bg_color.v, "die obere Kante fängt das Licht")
	assert_eq(licht.border_width_bottom, 0, "und nur sie")
	assert_gt(schatten.border_width_bottom, 0, "unten liegt der Gegenschatten")
	assert_eq(schatten.border_width_top, 0)
	assert_lt(schatten.border_color.v, lip.bg_color.v, "und der ist dunkler als das Blech")
	assert_gt(lip.shadow_size, 0, "und die Schale wirft einen Schlagschatten auf den Tisch")
	assert_gt(lip.shadow_offset.y, 0.0, "nach unten - das Licht kommt von oben")

func test_every_painted_band_is_at_least_two_texture_pixels() -> void:
	# Gemessen, nicht gewählt: bei EINEM Pixel löst die weite Werkbank-Sicht das
	# Band auf - dieselbe Lehre, an der schon der alte Saum hing.
	var shelf := PackShelfView.new()
	add_child_autofree(shelf)
	shelf.build([], 4.0, false, Vector2(30, 45), Vector2(400, 90))
	for category: String in PackShelfView.SHELF_ORDER:
		assert_gte(_band_box(shelf, category, "LipLight").border_width_top, 2,
			"%s: Lichtkante" % category)
		assert_gte(_band_box(shelf, category, "LipShade").border_width_bottom, 2,
			"%s: Schattenkante" % category)
		var sink := _band_box(shelf, category, "WellSink")
		assert_gte(sink.border_width_left, 2, "%s: Innenschatten" % category)
		assert_gte(sink.border_width_top, sink.border_width_left,
			"%s: oben am breitesten - dort steht die Wand am tiefsten" % category)
		assert_gte(_band_box(shelf, category, "LipRing").border_width_top, 2,
			"%s: Lippenring" % category)

func test_an_empty_bay_looks_exactly_like_a_stocked_one() -> void:
	# Die alte Saum-Unterscheidung ist erledigt: der farbige Grund trägt die Sorte
	# in beiden Fällen, und was darin liegt, sagt die Kassette selbst.
	var shelf := _shelf([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 2)])
	assert_eq(_ramp(shelf, Engraving.CATEGORY_MATERIAL).colors,
		PackShelfView.well_gradient(Engraving.CATEGORY_MATERIAL).gradient.colors,
		"die leere Bucht trägt genau den Grund ihrer Sorte")
	assert_eq(_band_box(shelf, Engraving.CATEGORY_MATERIAL, "WellSink").border_width_top,
		_band_box(shelf, Engraving.CATEGORY_NUMBER, "WellSink").border_width_top,
		"und denselben Innenschatten wie die gefüllte")
	assert_eq(shelf.segment_of(Engraving.CATEGORY_NUMBER).modulate,
		shelf.segment_of(Engraving.CATEGORY_MATERIAL).modulate, "und denselben Zustand")

func test_no_bay_carries_a_glyph_or_a_word_empty_or_stocked() -> void:
	# Das Wasserzeichen ist tot: die Bucht liest über Lippe und Grund allein, das
	# Siegel lebt nur noch auf der Kassette (eine eigene Schicht).
	var shelf := _shelf([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 2)])
	for category: String in PackShelfView.SHELF_ORDER:
		for node in [shelf.segment_of(category), shelf.stack_button(category)]:
			assert_eq(node.find_children("*", "Label", true, false).size(), 0,
				"%s: kein Wort" % category)
			assert_eq(node.find_children("*", "PackIconRenderer", true, false).size(), 0,
				"%s: kein Zeichen" % category)

func test_reaching_for_a_stack_lifts_its_whole_dish() -> void:
	var shelf := _shelf([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 2)])
	var seat := shelf.segment_of(Engraving.CATEGORY_NUMBER)
	assert_eq(seat.modulate, PackShelfView.BAY_REST)
	shelf.stack_button(Engraving.CATEGORY_NUMBER).mouse_entered.emit()
	assert_eq(seat.modulate, PackShelfView.BAY_HOVER_LIFT, "Lippe und Grund heben sich zusammen")
	shelf.stack_button(Engraving.CATEGORY_NUMBER).mouse_exited.emit()
	assert_eq(seat.modulate, PackShelfView.BAY_REST)
	assert_gt(PackShelfView.BAY_HOVER_LIFT.r, 1.0, "greifen heißt heller")

func test_an_empty_bay_never_lifts() -> void:
	# Dort ist nichts zu greifen - das Heben ist die Ankündigung des Griffs.
	var shelf := _shelf([])
	shelf.stack_button(Engraving.CATEGORY_MATERIAL).mouse_entered.emit()
	assert_eq(shelf.segment_of(Engraving.CATEGORY_MATERIAL).modulate, PackShelfView.BAY_REST)

func test_the_lock_dims_the_whole_dish() -> void:
	# Unterschrieben verglimmt die ganze Schale - Lippe, Grund und Schatten zugleich.
	var shelf := _shelf([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 1)], true)
	for category: String in PackShelfView.SHELF_ORDER:
		assert_eq(shelf.segment_of(category).modulate, PackShelfView.BAY_LOCK_DIM,
			"%s ist gesperrt" % category)
	assert_lt(PackShelfView.BAY_LOCK_DIM.v, PackShelfView.BAY_REST.v,
		"gesperrt dunkler als offen")
	shelf.stack_button(Engraving.CATEGORY_NUMBER).mouse_entered.emit()
	assert_eq(shelf.segment_of(Engraving.CATEGORY_NUMBER).modulate, PackShelfView.BAY_LOCK_DIM,
		"und die Sperre schlägt das Überfahren")

## Der stärkste Kanal einer Farbe (0=r, 1=g, 2=b) und sein Wert in einer anderen.
func _dominant(color: Color) -> int:
	if color.r >= color.g and color.r >= color.b:
		return 0
	return 1 if color.g >= color.b else 2

func _channel(color: Color, index: int) -> float:
	if index == 0:
		return color.r
	return color.g if index == 1 else color.b

func test_an_empty_bay_reports_its_sort_on_hover() -> void:
	var shelf := PackShelfView.new()
	add_child_autofree(shelf)
	shelf.size = Vector2(900, 150)
	shelf.build([], 8.0, false, Vector2(30, 45), Vector2(900, 150))
	await wait_frames(2)
	for category: String in PackShelfView.SHELF_ORDER:
		var hint := shelf.hint_at(shelf.stack_button(category).get_global_rect().get_center())
		assert_eq(String(hint.get("title", "")), PackShelfView.bay_name(category),
			"%s nennt sich beim Überfahren" % category)
		assert_eq(String(hint.get("body", "")), PackShelfView.BAY_EMPTY_BODY,
			"%s sagt, dass sie leer ist - Auskunft, keine Anweisung" % category)

func test_every_bay_name_comes_from_the_pack_names() -> void:
	assert_eq(PackShelfView.bay_name(Engraving.CATEGORY_NUMBER),
		Pack.TYPE_NAMES[Pack.TYPE_NUMBER])
	assert_eq(PackShelfView.bay_name(PackShelfView.CATEGORY_DICE_PACK),
		Pack.TYPE_NAMES[Pack.TYPE_DICE])
	assert_eq(PackShelfView.bay_name(PackShelfView.CATEGORY_SPECIAL),
		PackShelfView.BAY_NAME_SPECIAL, "nur der Sonderbestand nennt sich selbst")

func test_a_stack_reports_its_sort_when_pressed() -> void:
	var shelf := _shelf([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 1)])
	var pressed: Array[String] = []
	shelf.stack_pressed.connect(func(id: String) -> void: pressed.append(id))
	shelf.stack_button(Engraving.CATEGORY_NUMBER).pressed.emit()
	assert_eq(pressed, [Engraving.CATEGORY_NUMBER] as Array[String])

func test_a_signed_round_bars_every_stack() -> void:
	var shelf := _shelf([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 1)], true)
	assert_true(shelf.stack_button(Engraving.CATEGORY_NUMBER).disabled,
		"unterschrieben wird nicht mehr gegriffen")

func test_the_stack_explains_itself_on_hover() -> void:
	var shelf := _shelf([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 2)])
	await wait_frames(2)
	var hint := shelf.hint_at(
		shelf.stack_button(Engraving.CATEGORY_NUMBER).get_global_rect().get_center())
	assert_true(String(hint.get("title", "")).begins_with("2 ×"),
		"der Stapel nennt seine Zahl: '%s'" % hint.get("title", ""))
	assert_ne(String(hint.get("body", "")), "", "und seine Wirkung")
	assert_true(shelf.hint_at(Vector2(-500, -500)).is_empty(), "daneben schweigt sie")

# --- Kein Panel unter einem physischen Ding ---------------------------------------
# Der Stapel LIEGT als Kassette auf dem Glas (DataCellView, aufgestellt von
# scene_root); im Fenster bleibt nur sein unsichtbarer Griff.

func test_a_stack_draws_nothing_at_all() -> void:
	var shelf := _shelf([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 3)])
	var chip := shelf.stack_button(Engraving.CATEGORY_NUMBER)
	assert_eq(chip.get_child_count(), 0, "kein Siegel, keine Marke, keine Fußzeile")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert_true(chip.get_theme_stylebox(state) is StyleBoxEmpty,
			"%s zeichnet nichts" % state)

func test_the_footprint_follows_the_real_cell() -> void:
	# Die Kassette ist ein WELTMASS - der Griff misst sich an ihr, nicht umgekehrt.
	var cell := Vector2(30, 45)
	var shelf := PackShelfView.new()
	add_child_autofree(shelf)
	shelf.build([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 1)], 8.0, false, cell)
	var chip := shelf.stack_button(Engraving.CATEGORY_NUMBER)
	assert_almost_eq(chip.custom_minimum_size.x, cell.x * PackShelfView.STACK_SPAN, 0.01)
	assert_gt(chip.custom_minimum_size.y, cell.y, "darüber steht die ×n-Marke")
	assert_almost_eq(shelf.custom_minimum_size.y, shelf.segment_footprint().y, 0.01,
		"die Zeile ist genau so hoch wie ein Segment")

# --- Die Segmente: der SITZ eines Stapels ------------------------------------------
# Bewusste, in CLAUDE.md dokumentierte Ausnahme von der Filz-Regel: die Bucht ist
# Möbel wie die Leseschlitze, kein Schild neben der Ware.

func test_every_sort_gets_its_own_segment() -> void:
	var shelf := _shelf([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 2),
		_entry(Engraving.CATEGORY_MATERIAL, Pack.material_pack(), 1)])
	for category: String in PackShelfView.SHELF_ORDER:
		assert_not_null(shelf.segment_of(category), "%s hat ihren Sitz" % category)

func test_a_segment_holds_the_whole_stack_footprint() -> void:
	var cell := Vector2(30, 45)
	var shelf := PackShelfView.new()
	add_child_autofree(shelf)
	shelf.build([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 3)], 8.0, false, cell)
	var seat := shelf.segment_of(Engraving.CATEGORY_NUMBER)
	var stack := shelf.stack_footprint()
	assert_gt(seat.custom_minimum_size.x, stack.x, "der Sitz reicht um den Stapel herum")
	assert_gt(seat.custom_minimum_size.y, stack.y)
	assert_lt(seat.custom_minimum_size.x, stack.x * 1.5, "aber knapp - er ist kein Panel")

func test_a_segment_is_drawing_only_and_never_sees_the_mouse() -> void:
	# Der Name steht auf der Hinweiskarte, das Zeichen auf der Zelle - hier liegen
	# nur die gemalten Schichten der Schale.
	var shelf := _shelf([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 3)])
	var seat := shelf.segment_of(Engraving.CATEGORY_NUMBER)
	assert_eq(seat.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"geklickt wird der Griff, nie der Sitz")
	for child in seat.get_children():
		var layer: Control = child
		assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s sieht die Maus ebenso wenig" % layer.name)

func test_the_lip_carries_a_hint_of_its_sort_but_stays_dark_metal() -> void:
	var shelf := _shelf([_entry(Engraving.CATEGORY_MATERIAL, Pack.material_pack(), 1)])
	var lip := _lip_box(shelf, Engraving.CATEGORY_MATERIAL).bg_color
	assert_ne(lip, PackShelfView.LIP_BASE, "ein Hauch Sortenfarbe steckt darin")
	var neutral := _lip_box(shelf, PackShelfView.CATEGORY_DICE_PACK).bg_color
	assert_ne(lip, neutral, "und der unterscheidet zwei Sorten")
	assert_lt(maxf(maxf(lip.r, lip.g), lip.b), 0.4,
		"aber die Lippe bleibt dunkles Blech - hell ist die Kassette")
	var glanz := PackShelfView.well_color(Engraving.CATEGORY_MATERIAL,
		float(PackShelfView.WELL_MIX[1]))
	assert_gt(lip.v, glanz.v, "und sie steht heller als ihr Grund: sie ist erhaben")

func test_the_pack_type_map_reads_both_ways() -> void:
	# EINE Zuordnung - Zelle und Schlitz-Anzeige holen ihr Zeichen daraus.
	for pack_type: String in [Pack.TYPE_DICE, Pack.TYPE_NUMBER, Pack.TYPE_MATERIAL,
			Pack.TYPE_DICE_MOD]:
		var category := PackShelfView.shelf_category_for_pack_type(pack_type)
		assert_eq(PackShelfView.pack_type_of(category), pack_type, "hin und zurück: %s" % pack_type)
	assert_eq(PackShelfView.pack_type_of(PackShelfView.CATEGORY_SPECIAL), "",
		"der Sonderbestand nennt seine Sorte nicht")

func test_the_anchor_sits_where_the_cell_lies_not_in_the_footprints_middle() -> void:
	var cell := Vector2(30, 45)
	var shelf := PackShelfView.new()
	add_child_autofree(shelf)
	shelf.size = Vector2(800, 80)
	shelf.build([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 1)], 8.0, false, cell)
	await wait_frames(2)
	var chip := shelf.stack_button(Engraving.CATEGORY_NUMBER)
	var anchor := shelf.stack_anchor_px(Engraving.CATEGORY_NUMBER)
	assert_almost_eq(anchor.x, chip.get_global_rect().get_center().x, 0.01)
	assert_almost_eq(anchor.y, chip.get_global_rect().end.y - cell.y * 0.5, 0.01,
		"die Zelle liegt im unteren Band, der Kopfraum gehört der Marke")

func test_the_bays_split_the_whole_row_in_fixed_places() -> void:
	# Dieselbe Aufteilung wie die Netzzeile darüber: jede Sorte ihr Fünftel abzüglich
	# der Nähte - und zwar unabhängig davon, wer gerade Ware führt.
	var row := Vector2(900, 80)
	var shelf := PackShelfView.new()
	add_child_autofree(shelf)
	shelf.size = row
	shelf.build([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 1),
		_entry(Engraving.CATEGORY_MATERIAL, Pack.material_pack(), 1)], 8.0, false,
		Vector2(30, 45), row)
	await wait_frames(2)
	var bay := PackShelfView.bay_size_for(row).x
	var pitch := bay + PackShelfView.bay_gap_for(row)
	var previous := -INF
	for i in PackShelfView.SHELF_ORDER.size():
		var category: String = PackShelfView.SHELF_ORDER[i]
		var anchor := shelf.stack_anchor_px(category)
		assert_almost_eq(anchor.x - shelf.get_global_rect().position.x,
			pitch * float(i) + bay * 0.5, 1.0, "%s liegt in ihrer Schale" % category)
		assert_gt(anchor.x, previous, "und die Buchten stehen in SHELF_ORDER")
		previous = anchor.x

# --- Der Streifen: das untere Viertel der Bank ------------------------------------

func _docked(row: Vector2, cell := Vector2(40.5, 60.75)) -> PackShelfView:
	var shelf := PackShelfView.new()
	add_child_autofree(shelf)
	shelf.size = row
	shelf.build([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 3)], 9.15, false,
		cell, row)
	return shelf

func test_five_dishes_and_four_seams_fill_the_reported_strip() -> void:
	var row := Vector2(915.0, 147.6)
	var shelf := _docked(row)
	assert_almost_eq(shelf.custom_minimum_size.y, row.y, 0.01,
		"die Leiste ist genau so hoch wie ihr Streifen")
	var bay := shelf.segment_footprint()
	var gap := PackShelfView.bay_gap_for(row)
	var bays := float(PackShelfView.SHELF_ORDER.size())
	assert_almost_eq(bay.y, row.y, 0.01, "eine Schale nimmt die GANZE Streifenhöhe")
	assert_gte(gap, PackShelfView.BAY_GAP_MIN, "die Naht trägt mindestens zwei Texturpixel")
	assert_lt(bay.x, row.x / bays, "eine Schale ist schmaler als ein volles Fünftel")
	assert_almost_eq(bay.x * bays + gap * (bays - 1.0), row.x, 0.01,
		"fünf Schalen und vier Nähte ergeben den Streifen")
	assert_eq(shelf.get_theme_constant("separation"), int(gap),
		"und der Kasten legt genau diese Naht")
	for category: String in PackShelfView.SHELF_ORDER:
		assert_eq(shelf.segment_of(category).custom_minimum_size, bay,
			"%s ist genauso groß wie jede andere" % category)

func test_the_cells_grow_with_their_bays_and_stop_at_the_cap() -> void:
	var cell := Vector2(40.5, 60.75)
	var shelf := _docked(Vector2(915.0, 147.6), cell)
	var scale := shelf.cell_scale()
	assert_gt(scale, 1.0, "im Viertel wächst die Kassette")
	assert_lte(scale, PackShelfView.SHELF_SCALE_MAX, "aber nie über den Deckel")
	var base := PackShelfView.base_stack_footprint(cell)
	var room := shelf.segment_footprint() * (1.0 - PackShelfView.BAY_INSET * 2.0)
	assert_almost_eq(scale, minf(room.x / base.x, room.y / base.y), 0.001,
		"der Maßstab ist abgeleitet, nicht geraten")
	assert_almost_eq(scale, 1.34, 0.02, "höhengebunden wie zuvor (~1,34)")
	assert_lt(room.y / base.y, room.x / base.x,
		"die Höhe bindet - die schmaleren Schalen heben die Kassette nicht")
	assert_gt(shelf.segment_footprint().y * PackShelfView.BAY_INSET,
		float(shelf._lip_px()) + float(shelf.u) * PackShelfView.WELL_SINK,
		"die Randluft trägt Lippe und Innenschatten - die Kassette liegt IM Grund")
	assert_lte(shelf.stack_footprint().y, room.y + 0.01, "der Stapel passt in seine Bucht")
	assert_lte(shelf.stack_footprint().x, room.x + 0.01)
	assert_almost_eq(shelf.scaled_cell_px().y, cell.y * scale, 0.001)

func test_a_giant_strip_never_lifts_the_cell_past_the_cap() -> void:
	var shelf := _docked(Vector2(2400.0, 600.0))
	assert_almost_eq(shelf.cell_scale(), PackShelfView.SHELF_SCALE_MAX, 0.001,
		"das Regal darf die Zwingen-Würfel nicht überragen")

func test_without_a_strip_the_bay_still_measures_itself_at_the_footprint() -> void:
	# Rückfall (kein Streifen gemeldet): die alte Regel, Maßstab 1.
	var shelf := PackShelfView.new()
	add_child_autofree(shelf)
	shelf.build([_entry(Engraving.CATEGORY_NUMBER, Pack.number_pack(), 1)], 8.0, false,
		Vector2(30, 45))
	assert_almost_eq(shelf.cell_scale(), 1.0, 0.001)
	assert_gt(shelf.segment_footprint().y, shelf.stack_footprint().y)

func test_the_anchor_follows_the_grown_cell() -> void:
	var cell := Vector2(40.5, 60.75)
	var shelf := _docked(Vector2(915.0, 147.6), cell)
	await wait_frames(2)
	var chip := shelf.stack_button(Engraving.CATEGORY_NUMBER)
	var anchor := shelf.stack_anchor_px(Engraving.CATEGORY_NUMBER)
	assert_almost_eq(anchor.y, chip.get_global_rect().end.y - cell.y * shelf.cell_scale() * 0.5,
		0.01, "die gewachsene Kassette liegt im unteren Band ihrer Bucht")

# Die Hand-Leiste ist fort: die Beute bleibt in den Lesern der Presse liegen, aus
# denen sie kam (test_workshop_placement), und was schon SITZT, trägt seine
# Plakette auf der Netzzelle, an der es hängt (test_press_net_view).
