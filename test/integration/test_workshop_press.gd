extends GutTest
## Tier-2-Tests der Werkbank-Grundseite und ihrer Presse: die Netzzeile der
## Aufspannung, die sechs Presse-Plätze (aus dem Paket-Regal befüllt statt aus
## Lagerkarten), der Wurf als Walzenlauf IN den Anzeigefeldern derselben Seite,
## die Reihen-Plaketten, der EINE Handlungs-Sitz und das Abrechnen auf die Bank.

var view: WorkshopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = WorkshopView.new()
	# Dasselbe Seitenverhältnis wie die echte Werkbank (gelöst über die
	# Dossier-Seite) - ein flacheres Prüffenster ließe den Inhalt unten austreten.
	view.size = Vector2(roundf(540.0 * WorkshopView.dossier_aspect()), 540)
	add_child_autofree(view)
	view.run = run

## Legt count Zahlen-Pakete ins Regal und schiebt sie alle in die Presse-Plätze.
func _select_number_packs(count: int) -> void:
	for i in count:
		run.grant_pack(Pack.number_pack())
	for i in count:
		view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)

# --- Die Grundseite: Aufspannung und Presse-Plätze ------------------------------

func test_the_bench_shows_one_net_per_clamp() -> void:
	assert_eq(view._clamp_nets.size(), run.clamped_dice.size(), "je Zwinge ein Netz")
	assert_eq(view._clamp_nets.size(), run.clamp_count())

func test_the_bench_carries_no_title_any_more() -> void:
	# Die Grundseite gehört der Aufspannung: jede Zeile Text ist Netzgröße.
	for child in view._content.get_children():
		assert_false(child is Label, "kein Titel, kein Hinweis - nur Netze und Plätze")

func test_a_fresh_clamping_rebuilds_the_net_row() -> void:
	var before := view._clamp_nets.duplicate()
	run.roll_clamped_dice()
	assert_eq(view._clamp_nets.size(), run.clamp_count(), "die Zeile steht neu")
	assert_ne(view._clamp_nets, before, "und zwar wirklich neu gebaut")

func test_the_stages_are_reported_over_the_net_columns() -> void:
	# scene_root stellt die ECHTEN Würfel über genau diese Spalten.
	await wait_frames(2)
	var centers := view.clamp_net_centers()
	assert_eq(centers.size(), run.clamp_count())
	for i in range(1, centers.size()):
		assert_lt(centers[i - 1].x, centers[i].x, "die Spalten stehen in ihrer Reihenfolge")

func test_the_clamp_dice_stand_clear_above_their_nets() -> void:
	# Die Zwingen sind Bestand: ihre Reihe steht über den Diagrammen, nicht darauf.
	await wait_frames(2)
	var u := maxf(view.size.x, 200.0) / 100.0
	for i in view._clamp_nets.size():
		var stage: Control = view._clamp_stage_hosts[i]
		var net: PressNetView = view._clamp_nets[i]
		assert_gte(net.get_global_rect().position.y - stage.get_global_rect().end.y,
			u * WorkshopView.CLAMP_NET_GAP, "Luft zwischen Bühne %d und ihrem Netz" % i)

func test_the_slot_row_always_shows_six_places() -> void:
	assert_eq(view._press_slot_buttons.size(), PhantomPress.BATCH_CAP)
	for slot in view._press_slot_buttons:
		assert_true(slot.disabled, "ein leerer Platz fängt keine Klicks")

# --- Die Leseschlitze (ein Schlitz ist ein Loch) ------------------------------------

func _slit(index: int) -> Panel:
	return view._press_slot_buttons[index].get_node("SlitColumn/Slit")

func _display(index: int) -> Panel:
	return view._press_slot_buttons[index].get_node("SlitColumn/SlitDisplay")

func _console() -> Panel:
	return view.get_node("PressBand/PressConsole")

func _seat() -> Control:
	return view.get_node("PressBand/ActionSeat")

## Die Reihen-Plakette eines Lesers ("" = keine).
func _run_badge(index: int) -> String:
	var badge := _display(index).get_node_or_null("RunLevel") as Label
	return badge.text if badge != null else ""

func test_the_slits_sit_in_one_raised_console_plate() -> void:
	# Dieselbe gemalte Tiefe wie die Regal-Schalen, nur neutral: die Sortenfarbe
	# gehört der Ware, nicht dem Gerät.
	await wait_frames(2)
	var console := _console()
	assert_true(console.is_ancestor_of(view._press_slot_buttons[0]),
		"die Reihe liegt IM Blech")
	assert_true(console.is_ancestor_of(view._press_slit_panels[5]), "alle sechs")
	var plate: StyleBoxFlat = console.get_theme_stylebox("panel")
	assert_eq(plate.bg_color, WorkshopView.CONSOLE_BASE, "neutrales Dunkelmetall")
	for sort: String in PackShelfView.SHELF_ORDER:
		assert_ne(plate.bg_color, PackShelfView.COLORS[sort],
			"%s: das Blech trägt keine Sortenfarbe" % sort)
	var licht: StyleBoxFlat = console.get_node("ConsoleLight").get_theme_stylebox("panel")
	var schatten: StyleBoxFlat = console.get_node("ConsoleShade").get_theme_stylebox("panel")
	assert_gte(licht.border_width_top, 2, "die Lichtkante trägt zwei Texturpixel")
	assert_gte(schatten.border_width_bottom, 2)
	assert_gt(licht.border_color.v, plate.bg_color.v, "oben hell")
	assert_lt(schatten.border_color.v, plate.bg_color.v, "unten dunkel")
	assert_gt(plate.shadow_size, 0, "und das Blech wirft seinen Schatten auf den Tisch")

func test_every_slot_lies_in_a_pocket_sunk_into_the_plate() -> void:
	await wait_frames(2)
	var pocket: Panel = view._press_slot_buttons[0].get_node("SlotPocket")
	var box: StyleBoxFlat = pocket.get_theme_stylebox("panel")
	var plate: StyleBoxFlat = _console().get_theme_stylebox("panel")
	assert_lt(box.bg_color.v, plate.bg_color.v, "die Tasche liegt tiefer als ihr Blech")
	var schatten: StyleBoxFlat = pocket.get_node("PocketShade").get_theme_stylebox("panel")
	var licht: StyleBoxFlat = pocket.get_node("PocketLight").get_theme_stylebox("panel")
	assert_gte(schatten.border_width_top, 2, "Schatten OBEN - eine Vertiefung ist die Umkehrung")
	assert_gte(licht.border_width_bottom, 2, "und das Licht unten")
	assert_gt(licht.border_color.v, schatten.border_color.v)
	assert_eq(pocket.mouse_filter, Control.MOUSE_FILTER_IGNORE, "geklickt wird der Knopf")
	assert_true(pocket.get_global_rect().encloses(
		view._press_slot_buttons[0].get_global_rect()),
		"sie greift um den ganzen Platz - ihr Band schneidet die Anzeige nicht an")

func test_the_console_hugs_its_six_slots_and_fits_the_bench() -> void:
	# Gerechnet, nicht gedehnt: ein fensterbreites Blech unter sechs mittigen
	# Schlitzen wäre leere Fläche. Und die Restluft über ihm trägt es.
	await wait_frames(2)
	var u := view.size.x / 100.0
	var console := _console()
	assert_almost_eq(console.size.x, view.console_size(u).x, 1.0)
	assert_lt(console.size.x, view.size.x * 0.7, "es umfasst die Reihe, nicht das Fenster")
	assert_almost_eq(console.size.y - view.socket_size(u).y, u * WorkshopView.CONSOLE_PAD_Y * 2.0,
		1.0, "in der Höhe genau die Randluft der Reihe")
	assert_gt(view._content.get_node("BenchSlack").size.y, 0.0,
		"und darüber bleibt Luft - das Blech nimmt sie sich nicht von einer Arbeitsfläche")

func test_a_filled_slit_writes_no_word_of_its_own() -> void:
	# Im Schlitz STECKT die Datenzelle - ihre Kopfkante ist die ganze Anzeige, und
	# die Sorte sagt das Zeichen, nie ein Text.
	run.grant_pack(Pack.number_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	assert_eq(view._press_slot_buttons[0].find_children("*", "Label", true, false).size(), 0,
		"kein Wort im Platz")
	assert_eq(view._press_slot_buttons[0].text, "", "und keine Aufschrift auf dem Knopf")

func test_a_slit_is_never_narrower_than_the_cell_it_swallows() -> void:
	view.data_cell_px = Vector2(40, 60)
	await wait_frames(2)
	var u := maxf(view.size.x, 200.0) / 100.0
	assert_gte(view.slit_size(u).x, 40.0, "die Zelle geht hindurch, sie klemmt nicht")
	assert_lt(view.slit_size(u).y, view.slit_size(u).x * 0.5,
		"und flach bleibt er: ein Schlitz ist eine Kante, keine Bucht")
	assert_eq(view._press_slot_buttons[0].custom_minimum_size, view.socket_size(u))

func test_the_display_is_the_big_field_of_its_slot() -> void:
	# Der Leser ist die Anzeige: er nimmt fast den ganzen Platz und ist um ein
	# Mehrfaches höher als der Schlitz, in dem die Kassette steckt.
	await wait_frames(2)
	var u := view.size.x / 100.0
	var field := _display(0)
	assert_almost_eq(field.size.y, u * WorkshopView.SLIT_DISPLAY, 1.0)
	assert_almost_eq(field.size.x, view.socket_size(u).x, 1.0,
		"und er füllt die Breite seines Platzes")
	assert_gt(field.size.y, view.slit_size(u).y * 3.0, "ein Vielfaches des Schlitzes")

func test_an_empty_slit_stays_dark_and_a_filled_one_lights_in_its_sort() -> void:
	run.grant_pack(Pack.material_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_MATERIAL)
	await wait_frames(2)
	var lit: StyleBoxFlat = _slit(0).get_theme_stylebox("panel")
	assert_eq(lit.border_color, PackShelfView.COLORS[Engraving.CATEGORY_MATERIAL],
		"der belegte Schlitz brennt in seiner Sorte")
	var dark: StyleBoxFlat = _slit(1).get_theme_stylebox("panel")
	assert_eq(dark.border_color, WorkshopView.SOCKET_RIM, "der leere bleibt stumpf")

func test_only_a_filled_display_carries_its_glyph() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	await wait_frames(2)
	var portal: PressPortalView = view._press_portals[0]
	var icon: PackIconRenderer = portal.get_child(0)
	assert_eq(icon.pack_type, Pack.TYPE_NUMBER, "dasselbe Siegel wie auf der Zelle")
	assert_eq((view._press_portals[1] as PressPortalView).get_child_count(), 0,
		"über einem leeren Schlitz steht nichts")

func test_the_slit_anchor_is_the_slit_not_the_button() -> void:
	# Dort STECKT die Zelle; der Knopf reicht bis über das Anzeigefeld.
	run.grant_pack(Pack.number_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	await wait_frames(2)
	var anchor := view.press_slot_anchors()[0]
	assert_almost_eq(anchor.y, _slit(0).get_global_rect().get_center().y, 0.01)
	assert_gt(anchor.y, view._press_slot_buttons[0].get_global_rect().get_center().y,
		"der Schlitz sitzt unter seinem Feld")

func test_the_whole_slot_is_the_click_target_and_draws_only_from_its_children() -> void:
	# Die Chip-Schalen-Regel: der Knopf fängt alles und zeichnet nichts.
	run.grant_pack(Pack.number_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	var slot := view._press_slot_buttons[0]
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert_true(slot.get_theme_stylebox(state) is StyleBoxEmpty,
			"%s zeichnet nichts" % state)
	assert_eq(slot.get_node("SlitColumn").mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"nur der Knopf sieht die Maus")

func test_the_sockets_report_their_sorts_and_places() -> void:
	# scene_root legt daran seine Zellen ab.
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.material_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_MATERIAL)
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	await wait_frames(2)
	assert_eq(view.press_slot_sorts(),
		[Engraving.CATEGORY_MATERIAL, Engraving.CATEGORY_NUMBER] as Array[String])
	var anchors := view.press_slot_anchors()
	assert_eq(anchors.size(), PhantomPress.BATCH_CAP, "auch die leeren Buchten haben Plätze")
	assert_true(view.bench_rect().has_point(anchors[0]), "und die liegen auf der Bank")

func test_an_ejected_pack_reports_its_place_and_stack() -> void:
	# Die Zelle dieses Platzes muss sich ausklinken, BEVOR neu abgezählt wird.
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.material_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	view.slot_pack_from_stack(Engraving.CATEGORY_MATERIAL)
	var reported: Array = []
	view.pack_unslotted.connect(func(index: int, category: String) -> void:
		reported.append([index, category]))
	view.clear_press_slot(1)
	assert_eq(reported.size(), 1)
	assert_eq(int(reported[0][0]), 1)
	assert_eq(String(reported[0][1]), Engraving.CATEGORY_MATERIAL)

func test_the_press_announces_itself_while_the_sockets_still_stand() -> void:
	var seen: Array[int] = []
	view.press_started.connect(func() -> void: seen.append(view.press_slot_sorts().size()))
	_select_number_packs(2)
	view.start_press()
	assert_eq(seen, [2] as Array[int], "gemeldet wird VOR dem Pressen, mit vollen Buchten")

func test_the_press_leaves_the_base_page_standing() -> void:
	# Die Pressung ersetzt nichts: sie läuft IN den Lesern der Grundseite, ihre
	# Beute liegt darunter - Regal und Buchten stehen die ganze Zeit.
	assert_not_null(view._shelf, "Grundseite: Regal und Buchten stehen")
	assert_false(view.pressing())
	_select_number_packs(1)
	view.start_press()
	assert_not_null(view._shelf, "und sie stehen auch danach")
	assert_true(view.placing(), "die Beute liegt in der Ablage")
	assert_eq(view._phase, WorkshopView.Phase.STASH, "die Presse hat keine eigene Seite mehr")

## Nachlegen ist erlaubt: eine liegende Ablage sperrt das Regal NICHT.
func test_a_lying_pile_still_lets_the_shelf_be_used() -> void:
	_select_number_packs(1)
	view.start_press()
	assert_true(view.placing())
	assert_false(view.shelf_locked(), "der Haufen sperrt nichts")
	run.grant_pack(Pack.material_pack())
	assert_true(view.slot_pack_from_stack(Engraving.CATEGORY_MATERIAL),
		"das nächste Paket geht in seinen Platz")

## Solange Meteore fliegen, LÄUFT der Automat - da wird nichts nachgelegt.
func test_the_running_press_locks_the_shelf_until_the_last_piece_lands() -> void:
	_select_number_packs(1)
	view.start_press()
	var uids: Array[int] = []
	for piece in run.press_pieces:
		uids.append(int(piece["piece_uid"]))
	view.withhold_press_pieces(uids)
	assert_true(view.pressing(), "die Presse arbeitet")
	assert_true(view.shelf_locked())
	run.grant_pack(Pack.material_pack())
	assert_false(view.slot_pack_from_stack(Engraving.CATEGORY_MATERIAL),
		"kein Paket in einen laufenden Automaten")
	for uid in uids:
		view.land_press_piece(uid)
	assert_false(view.pressing(), "mit dem letzten Meteor ist sie fertig")
	assert_false(view.shelf_locked())

# --- Das Paket-Regal füllt die Plätze -------------------------------------------

func test_a_stack_click_fills_the_next_free_slot() -> void:
	run.grant_pack(Pack.number_pack())
	assert_true(view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER))
	assert_eq(view._selected_packs, [0] as Array[int], "der Platz ist belegt")
	assert_eq(view._phase, WorkshopView.Phase.STASH, "geöffnet wird noch nichts")
	assert_eq(run.owned_packs.size(), 1, "das Siegel bleibt ganz")
	assert_false(view._press_slot_buttons[0].disabled, "der belegte Platz ist anfassbar")

func test_an_empty_stack_fills_nothing() -> void:
	assert_false(view.slot_pack_from_stack(Engraving.CATEGORY_MATERIAL))
	assert_true(view._selected_packs.is_empty())

func test_clicking_a_filled_slot_returns_its_pack() -> void:
	_select_number_packs(2)
	view._press_slot_buttons[0].pressed.emit()
	assert_eq(view._selected_packs.size(), 1, "das Paket liegt wieder im Regal")

func test_a_dice_pack_never_reaches_a_slot() -> void:
	# Ein 1er-Paket steht nach dem Öffnen schon beim Einsetzen - Hauptsache, es
	# läuft nicht durch die Presse.
	run.grant_pack(Pack.dice_pack(DiceOffer.TEMPLATES[0]))
	assert_false(view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER),
		"das Würfel-Regal ist nicht das Zahlen-Regal")
	assert_true(view.open_top_dice_pack())
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE,
		"Würfel-Pakete laufen nicht durch die Presse")
	assert_true(view._selected_packs.is_empty(), "und belegen keinen Platz")

func test_the_press_button_appears_with_the_first_slotted_pack() -> void:
	# Sein SITZ steht immer - sichtbar wird er erst mit dem ersten Paket.
	run.grant_pack(Pack.number_pack())
	assert_false(view._press_button.visible, "ohne belegten Platz zeigt sich kein Knopf")
	assert_not_null(_seat(), "der Sitz steht trotzdem")
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	assert_true(view._press_button.visible, "mit dem ersten Paket kommt er")

func test_the_batch_is_capped_at_six() -> void:
	_select_number_packs(8)
	assert_eq(view._selected_packs.size(), PhantomPress.BATCH_CAP,
		"sechs Seiten, sechs Plätze - mehr geht nicht in einen Wurf")

func test_slotted_packs_are_reserved_against_their_shelf() -> void:
	# Was im Platz liegt, fehlt im Stapel - sonst stünde dasselbe Siegel zweimal.
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.material_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	var reserved := view.press_reserved_counts()
	assert_eq(int(reserved.get(Engraving.CATEGORY_NUMBER, 0)), 1)
	assert_eq(int(reserved.get(Engraving.CATEGORY_MATERIAL, 0)), 0)

func test_a_locked_round_bars_the_press() -> void:
	run.grant_pack(Pack.number_pack())
	view.editing_locked = true
	assert_false(view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER),
		"unterschrieben wird nicht mehr gepresst")
	assert_true(view._selected_packs.is_empty())

# --- Die Pressung ------------------------------------------------------------------

func test_pressing_yields_pieces_per_pack() -> void:
	_select_number_packs(3)
	view.start_press()
	assert_eq(view._phase, WorkshopView.Phase.STASH, "die Presse hat keine eigene Seite")
	assert_gte(run.press_pieces.size(), 3, "je Paket mindestens ein Stück")
	assert_true(run.owned_packs.is_empty(), "pressen ist bindend")
	assert_true(view._selected_packs.is_empty(), "die Plätze sind leer geräumt")
	assert_true(view.placing(), "und die Beute liegt in der Ablage")

func test_the_press_reports_its_readers_and_its_price() -> void:
	run.add_charge(5)
	_select_number_packs(2)
	var seen: Array = []
	view.press_rolled.connect(func(sorts: Array, readers: Array, cost: int) -> void:
		seen.append([sorts, readers, cost]))
	view.start_press()
	assert_eq(seen.size(), 1, "eine Meldung, eine Pressung")
	assert_eq(seen[0][0], [Engraving.CATEGORY_NUMBER, Engraving.CATEGORY_NUMBER],
		"die Sorten der geschluckten Pakete")
	assert_eq(seen[0][1].size(), 2, "je Paket ein Leser")
	assert_eq(int(seen[0][2]), 0, "und die erste Pressung ist frei")

func test_a_second_press_costs_energy_and_says_so() -> void:
	run.add_charge(5)
	_select_number_packs(1)
	view.start_press()
	var before := run.charge
	_select_number_packs(1)
	view.start_press()
	assert_eq(run.charge, before - 1, "die zweite Pressung kostet eine Energie")

func test_an_unaffordable_press_refuses_and_darkens_its_seat() -> void:
	_select_number_packs(1)
	view.start_press()  # die freie erste
	_select_number_packs(1)
	await wait_frames(2)
	assert_false(view.can_press(), "die Bank ist leer")
	assert_true(view._press_button.disabled)
	var packs := run.owned_packs.size()
	view.start_press()
	assert_eq(run.owned_packs.size(), packs, "und das Paket bleibt versiegelt")

## Der Preis steht NICHT auf dem Knopf (sein Rechteck ist fest) - der Sitz sagt
## ihn dem Hinweis-Schirm.
func test_the_seat_names_its_price_on_the_hint_screen() -> void:
	_select_number_packs(1)
	await wait_frames(2)
	var hint := view.chip_hint_at(view._press_button.get_global_rect().get_center())
	assert_eq(String(hint.get("title", "")), "Pressung")
	assert_true(String(hint.get("body", "")).contains("frei"), "die erste ist frei")
	view.start_press()
	_select_number_packs(1)
	await wait_frames(2)
	var poor := view.chip_hint_at(view._press_button.get_global_rect().get_center())
	assert_true(String(poor.get("body", "")).contains("1 Energie"), "danach steht der Preis da")
	assert_eq(poor.get("tint"), CasinoStyle.RED, "und rot, weil die Bank ihn nicht deckt")

func test_the_seat_carries_one_rect_through_both_labels() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	await wait_frames(2)
	var rect := view._press_button.get_global_rect()
	assert_eq(view._press_button.text, "Pressen (2)")
	view.start_press()
	await wait_frames(2)
	assert_eq(view._apply_button.get_global_rect(), rect, "das Fertig füllt denselben Platz")
	assert_almost_eq(rect.size.x, view.action_size(view.size.x / 100.0).x, 0.01,
		"und zwar auf dem gerechneten Maß")

func test_the_widest_label_still_fits_its_seat() -> void:
	# Bemessen ist der Sitz an "Pressen (6)" - der Aufdruck darf nicht anstoßen.
	_select_number_packs(6)
	await wait_frames(2)
	assert_eq(view._press_button.text, "Pressen (6)")
	view._press_button.clip_text = false  # ungeklemmt messen
	assert_lte(view._press_button.get_combined_minimum_size().x,
		view.action_size(view.size.x / 100.0).x, "die breiteste Aufschrift passt hinein")

## Der EINE Sitz: rechts neben dem Blech, in jedem Zustand dasselbe Rechteck.
func test_the_action_seat_stands_right_of_the_console() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	await wait_frames(2)
	var seat := _seat().get_global_rect()
	var console := _console().get_global_rect()
	assert_gt(seat.position.x, console.end.x, "er sitzt rechts vom Blech")
	assert_lt(seat.end.x, view.get_global_rect().end.x, "und bleibt im Fenster")
	assert_almost_eq(seat.get_center().y, console.get_center().y, 1.0,
		"auf der Höhe der Reihe, nicht darüber")
	assert_almost_eq(console.get_center().x, view.get_global_rect().get_center().x, 1.0,
		"das Blech steht weiter mittig")

func test_a_fixed_content_pack_yields_exactly_its_piece() -> void:
	# Der Pointer liegt auf keinem Ikonensatz - geliefert wird er trotzdem
	# durch dieselbe Presse.
	run.grant_engraving_pack(Engraving.pointer_engraving())
	view.slot_pack_from_stack(PackShelfView.CATEGORY_SPECIAL)
	view.start_press()
	assert_eq(run.press_pieces.size(), 1)
	assert_eq(String(run.press_pieces[0]["id"]), Engraving.POINTER)

func test_a_locked_round_bars_the_press_button() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	view.editing_locked = true
	await wait_frames(2)
	assert_false(view.can_press())
	assert_true(view._press_button.disabled)

# --- Kein Wort über der Reihe ---------------------------------------------------
# Weder Prämientafel noch Güte-Zeile: was eine Pressung wert ist, liegt als
# Haufen auf dem Glas.

func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var hit := _find_named(child, wanted)
		if hit != null:
			return hit
	return null

func test_no_page_of_the_press_carries_a_paytable_or_a_grade_line() -> void:
	assert_null(_find_named(view, "QualityBoard"), "die Grundseite gehört den Netzen")
	assert_null(_find_named(view, "QualityHeader"))
	_select_number_packs(2)
	view.start_press()
	await wait_frames(2)
	assert_true(view.placing())
	assert_null(_find_named(view, "QualityBoard"))
	assert_null(_find_named(view, "QualityHeader"), "und auch die Beute trägt keine Güte")
	assert_null(_find_named(view, "RunLevel"), "keine Reihen-Plakette mehr")

# --- Die Portale in den Lesern ------------------------------------------------------
# Der Leser ist das Portal: dunkel, belegt, im Wirbel. Gewürfelt hat GameRun.

func test_every_slot_carries_its_portal() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	await wait_frames(2)
	assert_eq(view._press_portals.size(), PhantomPress.BATCH_CAP)
	var portal: PressPortalView = view._press_portals[0]
	assert_eq(portal.sort, Engraving.CATEGORY_NUMBER, "das belegte Portal kennt seine Sorte")
	assert_eq((view._press_portals[1] as PressPortalView).sort, "", "das leere bleibt dunkel")
	assert_false(portal.running(), "und es wirbelt erst, wenn gepresst wird")

func test_a_swirling_portal_reports_itself_and_stops_on_its_own() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	await wait_frames(2)
	view.swirl_press_portal(0, 0.0)
	assert_true((view._press_portals[0] as PressPortalView).running())
	await wait_seconds(PressPortalView.SWIRL_TIME + PressPortalView.DISCHARGE_TIME + 0.2)
	assert_false((view._press_portals[0] as PressPortalView).running(),
		"der Wirbel endet von selbst")

func test_the_readers_report_their_places() -> void:
	# Dort startet der Meteor jedes Stücks (scene_root fragt die Felder).
	_select_number_packs(2)
	await wait_frames(2)
	var anchors := view.press_display_anchors()
	assert_eq(anchors.size(), PhantomPress.BATCH_CAP, "auch die leeren Leser haben Plätze")
	for anchor in anchors:
		assert_true(view.bench_rect().has_point(anchor), "%s liegt auf der Bank" % anchor)
	assert_lt(anchors[0].y, view.press_slot_anchors()[0].y, "das Feld sitzt über seinem Schlitz")

func test_the_readers_keep_their_sort_colour_while_the_press_runs() -> void:
	_select_number_packs(1)
	view.start_press()
	var uids: Array[int] = [int(run.press_pieces[0]["piece_uid"])]
	view.withhold_press_pieces(uids)
	await wait_frames(2)
	assert_eq((view._press_portals[0] as PressPortalView).sort, Engraving.CATEGORY_NUMBER,
		"das Paket ist geschluckt, sein Leser brennt weiter")
	view.land_press_piece(uids[0])
	await wait_frames(2)
	assert_eq((view._press_portals[0] as PressPortalView).sort, "",
		"mit dem letzten Meteor wird er dunkel")

## Das Netz unter der Zeremonie (scene_root deckt nach der letzten planmäßigen
## Ankunft auf, was noch verdeckt liegt): dafür muss ein zweites Landen folgenlos
## sein - sonst plusterte jedes Stück ein zweites Mal auf.
func test_landing_a_piece_twice_changes_nothing() -> void:
	_select_number_packs(2)
	view.start_press()
	var uids: Array[int] = []
	for piece in run.press_pieces:
		uids.append(int(piece["piece_uid"]))
	view.withhold_press_pieces(uids)
	await wait_frames(2)
	for uid in uids:
		view.land_press_piece(uid)
	await wait_frames(2)
	var chips := view._ablage_chips.size()
	for uid in uids:
		view.land_press_piece(uid)  # das Netz greift nach - es findet nichts mehr
	await wait_frames(2)
	assert_eq(view._ablage_chips.size(), chips, "kein Stück liegt doppelt")
	assert_eq(view._withheld.size(), 0)

## Bleibt ein Einschlag aus, darf die Beute nicht FÜR IMMER verdeckt bleiben:
## nachträgliches Landen deckt jedes Stück auf und gibt die Bank wieder frei.
func test_a_missed_impact_can_still_be_landed_afterwards() -> void:
	_select_number_packs(3)
	view.start_press()
	var uids: Array[int] = []
	for piece in run.press_pieces:
		uids.append(int(piece["piece_uid"]))
	view.withhold_press_pieces(uids)
	await wait_frames(2)
	assert_eq(view._ablage_chips.size(), 0, "verdeckt liegt nichts auf dem Glas")
	assert_true(view.pressing(), "und die Bank ist gesperrt, solange etwas fliegt")
	for uid in uids:
		view.land_press_piece(uid)
	await wait_frames(2)
	assert_eq(view._ablage_chips.size(), uids.size(), "jedes Stück liegt")
	assert_false(view.pressing(), "die Bank ist wieder frei")
	assert_eq(view._press_sorts, [] as Array[String], "und die Leser sind dunkel")

# --- Die Ablage: die Beute liegt auf dem Glas ---------------------------------------

func test_the_pressed_pieces_lie_in_the_strip_below_the_nets() -> void:
	_select_number_packs(1)
	view.start_press()
	await wait_frames(2)
	var strip := view.ablage_rect()
	for piece in run.press_pieces:
		var spot := view.ablage_spot(int(piece["piece_uid"]))
		assert_true(strip.has_point(spot), "%s liegt im Streifen" % spot)
	assert_lt(strip.end.y, view.size.y, "der Streifen endet im Fenster")
	if not view._clamp_nets.is_empty():
		var net: Control = view._clamp_nets[0]
		assert_gt(strip.position.y + view.get_global_rect().position.y,
			net.get_global_rect().end.y, "und liegt unter der Netzzeile")

## Der Platz eines Stücks folgt allein aus seiner Nummer: ein Neuaufbau legt
## denselben Haufen, und ein gesetztes Stück verrückt keinen Nachbarn.
func test_a_chip_keeps_its_spot_through_rebuilds_and_placements() -> void:
	_select_number_packs(2)
	view.start_press()
	await wait_frames(2)
	var last := int(run.press_pieces[run.press_pieces.size() - 1]["piece_uid"])
	var spot := view.ablage_spot(last)
	view.refresh()
	await wait_frames(2)
	assert_eq(view.ablage_spot(last), spot, "derselbe Haufen nach dem Neuaufbau")
	view.hold_piece(int(run.press_pieces[0]["piece_uid"]))
	view._on_net_face_pressed(0, run.clamped_dice[0])
	await wait_frames(2)
	assert_eq(view.ablage_spot(last), spot, "und der Nachbar bleibt liegen, wo er lag")

func test_a_withheld_piece_shows_nothing_until_it_lands() -> void:
	_select_number_packs(1)
	view.start_press()
	var uid := int(run.press_pieces[0]["piece_uid"])
	view.withhold_press_pieces([uid])
	await wait_frames(2)
	assert_false(view._ablage_chips.has(uid), "was noch fliegt, liegt nicht")
	view.land_press_piece(uid)
	await wait_frames(2)
	assert_true(view._ablage_chips.has(uid), "erst die Landung deckt es auf")

# --- Das Aufräumen: der Haufen richtet sich zur Reihe aus ---------------------------

## Legt EIN Beutestück (so, wie die Pressung es täte) und liefert seine Nummer.
func _seed_piece(sort: String, id: String) -> int:
	run.press_piece_serial += 1
	run.press_pieces.append({"sort": sort, "id": id, "stufe": 1, "applications": 1,
		"piece_uid": run.press_piece_serial})
	run.press_changed.emit()
	return run.press_piece_serial

## Legt die fünf Stücke hin und lässt jeden Meteor landen - der letzte räumt auf.
func _land_mixed_loot() -> Array[int]:
	var uids: Array[int] = [
		_seed_piece(Engraving.CATEGORY_DICE, Engraving.RUNE_PREFIX + Rune.STRAY_LIGHT),
		_seed_piece(Engraving.CATEGORY_NUMBER, Engraving.NOTCH),
		_seed_piece(Engraving.CATEGORY_MATERIAL, DieMaterial.RUBY),
		_seed_piece(Engraving.CATEGORY_NUMBER, Engraving.CHISEL),
		_seed_piece(Engraving.CATEGORY_MATERIAL, DieMaterial.GOLD),
	]
	view.withhold_press_pieces(uids)
	await wait_frames(2)
	for uid in uids:
		view.land_press_piece(uid)
	await wait_frames(2)
	return uids

func test_the_loot_lines_up_by_sort_and_then_by_rarity() -> void:
	var uids := await _land_mixed_loot()
	var expected: Array[int] = [uids[1], uids[3], uids[4], uids[2], uids[0]]
	assert_eq(view.ablage_order(), expected,
		"Zahlen (Kerbe vor Meißel), dann Material (Gold vor Rubin), zuletzt die Rune")

## Eine Reihe ist eine Reihe: von links nach rechts, auf einer Höhe, ohne
## Streuung - und ein Neuaufbau legt sie hart genauso hin.
func test_the_tidy_row_runs_left_to_right_and_survives_a_rebuild() -> void:
	await _land_mixed_loot()
	var order := view.ablage_order()
	var spots: Array[Vector2] = []
	for uid in order:
		spots.append(view.ablage_spot(uid))
	for i in range(1, spots.size()):
		assert_gt(spots[i].x, spots[i - 1].x, "Platz %d steht rechts vom Vorgänger" % i)
		assert_almost_eq(spots[i].y, spots[0].y, 0.01, "und in derselben Zeile")
	assert_true(view.ablage_rect().has_point(spots[spots.size() - 1]), "im Streifen")
	view.refresh()
	await wait_frames(2)
	for i in order.size():
		assert_eq(view.ablage_spot(order[i]), spots[i], "derselbe Platz nach dem Neuaufbau")

## Die Chips gleiten wirklich dorthin, wo die Ordnung sie hinschreibt.
func test_the_chips_glide_onto_their_places() -> void:
	var order := await _land_mixed_loot()
	await wait_seconds(WorkshopView.ABLAGE_TIDY_DELAY + WorkshopView.ABLAGE_TIDY_TIME
		+ float(order.size()) * WorkshopView.ABLAGE_TIDY_STAGGER + 0.2)
	var corner := view.ablage_rect().position + Vector2.ONE * view.ablage_chip_size() * 0.5
	for uid in view.ablage_order():
		var chip: Button = view._ablage_chips[uid]
		assert_almost_eq(chip.position.distance_to(view.ablage_spot(uid) - corner), 0.0, 0.5,
			"Chip %d liegt auf seinem Platz" % uid)

## Gleiche Gravuren teilen sich einen Platz und liegen DECKUNGSGLEICH - nur die
## Zahl auf dem obersten Icon sagt, wie viele es sind.
func test_identical_pieces_stack_on_one_place() -> void:
	var twins: Array[int] = [
		_seed_piece(Engraving.CATEGORY_NUMBER, Engraving.NOTCH),
		_seed_piece(Engraving.CATEGORY_NUMBER, Engraving.NOTCH),
		_seed_piece(Engraving.CATEGORY_NUMBER, Engraving.NOTCH),
	]
	var other := _seed_piece(Engraving.CATEGORY_MATERIAL, DieMaterial.GOLD)
	view.withhold_press_pieces(twins + [other])
	await wait_frames(2)
	for uid in twins + [other]:
		view.land_press_piece(uid)
	await wait_frames(2)
	var chip := view.ablage_chip_size()
	var marks: Array[String] = []
	for i in twins.size():
		assert_eq(view.ablage_spot(twins[i]), view.ablage_spot(twins[0]),
			"Kopie %d liegt auf demselben Platz" % i)
		var badge: Label = view._ablage_chips[twins[i]].get_node_or_null("Count")
		if badge != null:
			marks.append(badge.text)
	assert_eq(marks, ["×3"] as Array[String], "GENAU ein Icon des Platzes trägt die Zahl")
	# Die Kopien fahren erst zusammen und decken sich AM ZIEL ab.
	await wait_seconds(WorkshopView.ABLAGE_TIDY_DELAY + WorkshopView.ABLAGE_TIDY_TIME
		+ 4.0 * WorkshopView.ABLAGE_TIDY_STAGGER + 0.2)
	var shown := 0
	for uid in twins:
		if view._ablage_chips[uid].visible:
			shown += 1
	assert_eq(shown, 1, "und nur EINES wird gezeichnet - die Scheine addieren sich nicht")
	assert_gt(absf(view.ablage_spot(other).x - view.ablage_spot(twins[0]).x), chip,
		"eine andere Gravur bekommt ihren eigenen Platz")
	assert_null(view._ablage_chips[other].get_node_or_null("Count"),
		"ein einzelnes Stück trägt keine")

## Die Zahl liegt VORN: das geführte Stück darf sie nicht zudecken.
func test_the_held_copy_carries_the_count() -> void:
	var twins: Array[int] = [
		_seed_piece(Engraving.CATEGORY_NUMBER, Engraving.NOTCH),
		_seed_piece(Engraving.CATEGORY_NUMBER, Engraving.NOTCH),
	]
	view.withhold_press_pieces(twins)
	await wait_frames(2)
	for uid in twins:
		view.land_press_piece(uid)
	await wait_frames(2)
	view.hold_piece(twins[0])
	await wait_frames(2)
	var held: Button = view._ablage_chips[twins[0]]
	var badge: Label = held.get_node_or_null("Count")
	assert_not_null(badge, "das geführte Icon trägt die Zahl")
	assert_eq(badge.text, "×2")
	assert_null(view._ablage_chips[twins[1]].get_node_or_null("Count"),
		"und die Kopie darunter keine")
	assert_eq(held.get_index(), held.get_parent().get_child_count() - 1,
		"es liegt auch wirklich vorn")

## --- Die Hand nach einer Setzung -------------------------------------------------
## Sie soll BLEIBEN, wo sie war: eine Reihe Kerben setzt man am Stück.

func test_the_hand_stays_on_the_same_engraving_after_a_placement() -> void:
	var twins: Array[int] = [
		_seed_piece(Engraving.CATEGORY_NUMBER, Engraving.NOTCH),
		_seed_piece(Engraving.CATEGORY_NUMBER, Engraving.NOTCH),
	]
	# Ein Material daneben, damit die Hand überhaupt abrutschen KÖNNTE.
	_seed_piece(Engraving.CATEGORY_MATERIAL, DieMaterial.RUBY)
	await wait_frames(2)
	view.hold_piece(twins[0])
	view._on_net_face_pressed(0, run.clamped_dice[0])
	await wait_frames(2)
	assert_eq(view.held_piece_id(), Engraving.NOTCH, "dieselbe Gravur bleibt in der Hand")
	assert_eq(view.held_uid(), twins[1], "und zwar die zweite Kerbe")

func test_the_hand_falls_to_the_left_end_when_the_stack_is_spent() -> void:
	var notch := _seed_piece(Engraving.CATEGORY_NUMBER, Engraving.NOTCH)
	_seed_piece(Engraving.CATEGORY_MATERIAL, DieMaterial.RUBY)
	_seed_piece(Engraving.CATEGORY_DICE, Engraving.RUNE_PREFIX + Rune.STRAY_LIGHT)
	await wait_frames(2)
	view.hold_piece(notch)
	view._on_net_face_pressed(0, run.clamped_dice[0])
	await wait_frames(2)
	assert_eq(view.held_uid(), view.ablage_order()[0],
		"die einzige Kerbe ist weg - die Hand greift ans linke Ende")

func test_the_last_placement_empties_the_hand() -> void:
	var notch := _seed_piece(Engraving.CATEGORY_NUMBER, Engraving.NOTCH)
	await wait_frames(2)
	view.hold_piece(notch)
	view._on_net_face_pressed(0, run.clamped_dice[0])
	await wait_frames(2)
	assert_eq(view.held_uid(), 0, "leere Ablage, leere Hand")
	assert_eq(view.held_piece_id(), "")

## Die Zahl ist LEBEND: eine gesetzte Kopie fehlt auf dem Platz.
func test_the_stack_count_drops_with_a_placed_copy() -> void:
	var twins: Array[int] = [
		_seed_piece(Engraving.CATEGORY_NUMBER, Engraving.NOTCH),
		_seed_piece(Engraving.CATEGORY_NUMBER, Engraving.NOTCH),
		_seed_piece(Engraving.CATEGORY_NUMBER, Engraving.NOTCH),
	]
	view.withhold_press_pieces(twins)
	await wait_frames(2)
	for uid in twins:
		view.land_press_piece(uid)
	await wait_frames(2)
	view.hold_piece(twins[0])
	view._on_net_face_pressed(0, run.clamped_dice[0])
	await wait_frames(2)
	var marks: Array[String] = []
	for uid in view.ablage_order():
		var badge: Label = view._ablage_chips[uid].get_node_or_null("Count")
		if badge != null:
			marks.append(badge.text)
	assert_eq(marks, ["×2"] as Array[String], "der Platz zählt nur noch, was liegt")

## Aufgeräumt heißt eingefroren: eine Setzung verrückt keinen Nachbarn.
func test_a_placement_does_not_reflow_the_tidy_row() -> void:
	await _land_mixed_loot()
	var order := view.ablage_order()
	var last := order[order.size() - 1]
	var spot := view.ablage_spot(last)
	view.hold_piece(order[0])
	view._on_net_face_pressed(0, run.clamped_dice[0])
	await wait_frames(2)
	assert_eq(view.ablage_spot(last), spot, "der Nachbar bleibt liegen, wo er lag")

func test_a_lapse_takes_the_flying_pieces_with_it() -> void:
	_select_number_packs(1)
	view.start_press()
	var uids: Array[int] = []
	for piece in run.press_pieces:
		uids.append(int(piece["piece_uid"]))
	view.withhold_press_pieces(uids)
	assert_true(view.pressing())
	run.lapse_press()
	await wait_frames(2)
	assert_false(view.pressing(), "ohne Beute läuft keine Presse mehr")
	assert_false(view.placing())

# --- Abschluss ---------------------------------------------------------------------

func test_a_new_run_drops_a_running_press() -> void:
	_select_number_packs(2)
	view.start_press()
	view.run = GameRun.new_run()
	assert_eq(view._phase, WorkshopView.Phase.STASH, "die Pressung gehörte dem alten Lauf")
	assert_true(view._selected_packs.is_empty())
	assert_false(view.placing())

# --- Die Grundseite: Projektoren im Fenster --------------------------------------

func test_every_clamp_gets_a_projector_stage_above_its_net() -> void:
	# Der Filzstreifen zwischen Trays und Bank ist fort: die Bühne der Zwinge
	# liegt IM Fenster, ihr Netz direkt darunter.
	await wait_frames(2)
	assert_eq(view._clamp_stage_hosts.size(), run.clamp_count(), "je Zwinge eine Bühne")
	for i in view._clamp_stage_hosts.size():
		assert_eq(view._clamp_stage_hosts[i].get_child_count(), 0, "die Bühne zeigt selbst nichts")
		assert_lt(view._clamp_stage_hosts[i].get_global_rect().end.y,
			view._clamp_nets[i].get_global_rect().position.y + 1.0,
			"sie steht über ihrem Netz")

func test_the_projector_row_sits_inside_the_window_with_a_margin() -> void:
	await wait_frames(2)
	var top := view.global_position.y
	var row := view.clamp_projector_y()
	assert_gt(row, top, "die Zeile liegt IM Fenster")
	assert_gt(row - top, view.size.x / 100.0, "und mit sichtbarem Abstand zum oberen Rand")
	assert_lt(row, view.clamp_net_centers()[0].y, "über den Netzen")

## Prüft die Zeile für die gerade eingestellte Lizenzstufe: N Spalten, mittig,
## gleiche Abstände, die ganze Fensterbreite genutzt.
func _assert_columns_spread() -> void:
	var centers := view.clamp_net_centers()
	assert_eq(centers.size(), run.clamp_count(), "je Zwinge eine Spalte")
	var left := centers[0].x - view.global_position.x
	var right := view.global_position.x + view.size.x - centers[centers.size() - 1].x
	# Auf eine Einheit genau: die Container runden ihre Spalten auf ganze Pixel.
	assert_almost_eq(left, right, view.size.x / 100.0, "die Zeile steht mittig im Fenster")
	assert_gt(centers[centers.size() - 1].x - centers[0].x, view.size.x * 0.4,
		"und nutzt die Fensterbreite, statt in der Mitte zu kleben")
	var step := centers[1].x - centers[0].x
	for i in range(2, centers.size()):
		assert_almost_eq(centers[i].x - centers[i - 1].x, step, 1.0, "gleiche Abstände")

func test_the_columns_spread_across_the_whole_window() -> void:
	# Jede Spalte nimmt ihr Viertel der GANZEN Fensterbreite.
	await wait_frames(2)
	_assert_columns_spread()

func test_the_highest_licence_spreads_the_same_way() -> void:
	run.hub_level = 10
	run.roll_clamped_dice()
	await wait_frames(2)
	assert_eq(run.clamp_count(), 4, "auch die höchste Lizenz spannt vier auf")
	_assert_columns_spread()

func test_the_net_row_stays_inside_the_window() -> void:
	# Die Netzzeile teilt sich EINE Breite - alle Spalten müssen darin bleiben,
	# und der Deckel hält die Zellen davon ab, auszuufern.
	await wait_frames(2)
	var u := view.size.x / 100.0
	assert_true(view.clamp_cell(u) <= u * WorkshopView.CLAMP_CELL_MAX + 0.01, "die Zelle ist gedeckelt")
	var window := view.get_global_rect()
	var first := view._clamp_nets[0].get_global_rect()
	var last := view._clamp_nets[view._clamp_nets.size() - 1].get_global_rect()
	assert_gt(first.position.x, window.position.x - 1.0, "die erste Spalte bleibt im Fenster")
	assert_lt(last.end.x, window.end.x + 1.0, "und die letzte auch")

func test_the_press_bar_is_lower_than_the_net_row() -> void:
	# Siegelgroß statt kartenhoch - die Presse ist eine flache Leiste.
	await wait_frames(2)
	var u := view.size.x / 100.0
	assert_lt(view._press_slot_buttons[0].size.y,
		DieNetView.net_size(view.clamp_cell(u)).y, "der Platz ist flacher als ein Netz")

# --- Die Regal-Leiste im Fenster ---------------------------------------------------

func test_the_shelf_counts_its_sealed_packs() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.material_pack())
	assert_eq(view.sealed_pack_count(Engraving.CATEGORY_NUMBER), 2)
	assert_eq(view.sealed_pack_count(Engraving.CATEGORY_MATERIAL), 1)
	assert_eq(view.sealed_pack_count(Engraving.CATEGORY_DICE), 0)
	assert_eq(view.shelf_entries().size(), 2, "je belegter Sorte ein Stapel")

func test_a_slotted_pack_leaves_its_stack() -> void:
	run.grant_pack(Pack.number_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	assert_eq(view.sealed_pack_count(Engraving.CATEGORY_NUMBER), 0,
		"was im Platz liegt, steht nicht mehr im Stapel")
	view.clear_press_slot(0)
	assert_eq(view.sealed_pack_count(Engraving.CATEGORY_NUMBER), 1)

func test_a_pending_delivery_holds_its_seal_back() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	view.expect_pack_delivery(Engraving.CATEGORY_NUMBER)
	assert_eq(view.sealed_pack_count(Engraving.CATEGORY_NUMBER), 1,
		"das unterwegs befindliche Paket fehlt noch")
	view.deliver_pack(Engraving.CATEGORY_NUMBER)
	assert_eq(view.sealed_pack_count(Engraving.CATEGORY_NUMBER), 2, "bei Ankunft wächst der Stapel")

func test_an_extra_delivery_is_ignored() -> void:
	run.grant_pack(Pack.number_pack())
	view.deliver_pack(Engraving.CATEGORY_NUMBER)  # ohne angemeldete Lieferung
	assert_eq(view.sealed_pack_count(Engraving.CATEGORY_NUMBER), 1, "der Stapel bleibt, wie er ist")

func test_a_new_run_cancels_pending_deliveries() -> void:
	run.grant_pack(Pack.number_pack())
	view.expect_pack_delivery(Engraving.CATEGORY_NUMBER)
	var fresh := GameRun.new_run()
	fresh.grant_pack(Pack.number_pack())
	view.run = fresh
	assert_eq(view.sealed_pack_count(Engraving.CATEGORY_NUMBER), 1,
		"der neue Lauf zählt sein eigenes Regal")

func test_the_stack_anchor_lands_in_the_apron() -> void:
	# Ziel der Liefer-Kometen: seit dem Umbau ein Punkt in der SCHÜRZE, also unter
	# der Fensterkante - dort liegen die Buchten.
	run.grant_pack(Pack.number_pack())
	await wait_frames(2)
	var anchor := view.stack_anchor_px(Engraving.CATEGORY_NUMBER)
	assert_true(view.bench_rect().has_point(anchor), "%s liegt auf der Bank" % anchor)
	assert_gt(anchor.y, view.get_global_rect().end.y, "und unter dem Fenster")

func test_a_delivery_during_the_press_still_finds_its_stack() -> void:
	# Die Pressung lässt die Leiste stehen - der Komet trifft denselben Platz wie
	# vorher, nicht die Fenstermitte.
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	await wait_frames(2)
	var resting := view.stack_anchor_px(Engraving.CATEGORY_NUMBER)
	view.start_press()
	await wait_frames(2)
	assert_true(view.placing(), "die Beute liegt")
	var during := view.stack_anchor_px(Engraving.CATEGORY_NUMBER)
	assert_almost_eq(during.x, resting.x, 1.0, "derselbe Platz wie im Regal")
	assert_almost_eq(during.y, resting.y, 1.0)
	assert_ne(during, view.get_global_rect().get_center(), "und nicht die Fenstermitte")

func test_a_delivery_during_a_pack_flow_lands_at_once() -> void:
	# Die Schürze steht auch, während ein Würfel-Paket das Fenster füllt: der
	# Stapel wächst und ploppt sofort, es gibt nichts mehr zu warten.
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.dice_pack(DiceOffer.TEMPLATES[0]))
	view.open_top_dice_pack()
	await wait_frames(2)
	assert_not_null(view._shelf, "die Wahl nimmt der Schürze nichts weg")
	assert_true(view.shelf_locked(), "sie ist nur zu")
	var popped: Array[String] = []
	view.stack_popped.connect(func(category: String) -> void: popped.append(category))
	view.expect_pack_delivery(Engraving.CATEGORY_NUMBER)
	view.deliver_pack(Engraving.CATEGORY_NUMBER)
	assert_true(view._queued_pops.is_empty(), "nichts wartet mehr auf seine Leiste")
	assert_eq(popped, [Engraving.CATEGORY_NUMBER] as Array[String], "der Pluster geht sofort raus")

func test_a_pop_during_the_placement_lands_at_once() -> void:
	# Die Ablage nimmt der Schürze nichts weg - das Regal steht auch mit Beute.
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	view.start_press()
	await wait_frames(2)
	assert_true(view.placing())
	view.expect_pack_delivery(Engraving.CATEGORY_NUMBER)
	var popped: Array[String] = []
	view.stack_popped.connect(func(category: String) -> void: popped.append(category))
	view.deliver_pack(Engraving.CATEGORY_NUMBER)
	assert_eq(popped, [Engraving.CATEGORY_NUMBER] as Array[String])
	assert_true(view._queued_pops.is_empty())

func test_a_pop_during_the_press_lands_at_once() -> void:
	# Die Leiste steht durch die Pressung - da wartet nichts.
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	view.expect_pack_delivery(Engraving.CATEGORY_NUMBER)
	view.start_press()
	var popped: Array[String] = []
	view.stack_popped.connect(func(category: String) -> void: popped.append(category))
	view.deliver_pack(Engraving.CATEGORY_NUMBER)
	assert_eq(popped, [Engraving.CATEGORY_NUMBER] as Array[String])
	assert_true(view._queued_pops.is_empty())

func test_a_dice_stack_click_opens_its_choice_instead_of_a_slot() -> void:
	run.grant_pack(Pack.dice_pack(DiceOffer.TEMPLATES[0]))
	view._on_stack_pressed(PackShelfView.CATEGORY_DICE_PACK)
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE, "Würfel-Pakete laufen nie durch die Presse")
	assert_true(view._selected_packs.is_empty())

func test_an_engraving_stack_click_fills_the_next_free_slot() -> void:
	run.grant_pack(Pack.number_pack())
	view._on_stack_pressed(Engraving.CATEGORY_NUMBER)
	assert_eq(view._selected_packs, [0] as Array[int])

# --- Die Beute der Pressung ------------------------------------------------------------
# Ihr Innenleben steht in test_workshop_placement; hier zählt nur der Übergang.

func test_pressing_opens_the_placement_step() -> void:
	_select_number_packs(2)
	view.start_press()
	await wait_frames(2)
	var counts := view.press_piece_counts()
	var total := 0
	for id: String in counts:
		total += int(counts[id])
	assert_eq(total, run.press_pieces.size(), "je Stück eine offene Anwendung")
	assert_true(view.placing(), "und die Bank geht in den Platzierungs-Schritt")
	assert_true(view.bench_rect().has_point(
		view.piece_anchor_px(int(run.press_pieces[0]["piece_uid"]))),
		"der Chip des ersten Stücks liegt auf der Bank")

func test_the_pieces_carry_their_sorts_into_the_pile() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.material_pack())
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	view.slot_pack_from_stack(Engraving.CATEGORY_MATERIAL)
	view.start_press()
	var sorts := {}
	for piece in run.press_pieces:
		sorts[String(piece["sort"])] = true
	assert_true(sorts.has(Engraving.CATEGORY_NUMBER), "das Zahlen-Paket hat geliefert")
	assert_true(sorts.has(Engraving.CATEGORY_MATERIAL), "und das Material-Paket auch")

func test_without_loot_the_pile_is_empty() -> void:
	assert_true(view.press_piece_counts().is_empty())
	assert_false(view.placing())
	assert_null(view._ablage_host, "die Grundseite trägt keinen Haufen")
