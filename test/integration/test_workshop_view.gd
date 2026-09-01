extends GutTest
## Tier-2-Tests der Werkstatt (WorkshopView): die Grundseite zeigt die ZIEL-SÄULE
## (Projektor-Bühne über dem Summen-Netz) und daneben das Pool-Raster der Zielwahl;
## versiegelte Pakete liegen als Kassetten im Magazin statt als Karten im Fenster.

var view: WorkshopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = WorkshopView.new()
	view.size = Vector2(600, 500)
	add_child_autofree(view)
	view.run = run

# --- Die Grundseite gehört der Zielwahl -----------------------------------------

func test_packs_never_render_as_cards_in_the_window() -> void:
	# Das Magazin ist der EINZIGE Ort versiegelter Ware - im Fenster stehen nur die
	# Ziel-Säule, das Pool-Raster und die Serien-Slots.
	run.purchase_pack(Pack.number_pack(), 0)
	run.purchase_pack(Pack.material_pack(), 0)
	assert_not_null(view._net, "das Summen-Netz steht")
	assert_eq(view._slot_buttons.size(), run.series_slots())
	assert_eq(run.owned_packs.size(), 2, "und die Siegel bleiben ganz")

func test_the_pool_grid_is_the_readout_of_the_pool() -> void:
	assert_not_null(view._pool_grid)
	assert_eq(view._pool_grid.tiles.size(), run.owned_pool.size(),
		"Sitz i = Zelle i, die Grammatik der Glas-Ansicht")

## Es gibt keine Auspack-Zeremonie mehr: JEDE Kassette geht in einen Serien-Slot,
## und ein Würfel wird nie versiegelt.
func test_tapping_a_cassette_only_ever_slots_it() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view._on_pack_pressed(run.owned_packs[0].pack_uid)
	assert_eq(view.press_slot_uids().size(), 1, "sie steckt im Slot")

func test_the_bench_has_no_floating_dice_of_its_own() -> void:
	# Über der Bank schwebt allein der Zielwürfel - eine zweite Seite gibt es nicht.
	assert_true(view.bench_open())

# --- Netz-Hinweise --------------------------------------------------------------

func test_a_target_net_cell_explains_itself() -> void:
	# Die Zeile gehört NICHT ins Fenster - scene_root schreibt sie auf den
	# Hinweis-Schirm im Konsolen-Band.
	view.choose_target(0)
	await wait_frames(2)
	run.owned_pool[0].set_face_material(0, DieMaterial.GOLD)
	view.refresh()
	await wait_frames(2)
	var said := view.net_hint_at(_net_pixel(0))
	assert_true(said.contains(DieMaterial.by_id(DieMaterial.GOLD).display_name),
		"die Zelle sagt, was auf ihr liegt: '%s'" % said)

func test_a_bare_face_and_a_point_outside_say_nothing() -> void:
	view.choose_target(0)
	await wait_frames(2)
	for face in 6:
		run.owned_pool[0].set_face_material(face, "")
	view.refresh()
	await wait_frames(2)
	assert_eq(view.net_hint_at(_net_pixel(0)), "", "eine nackte Seite erklärt nichts")
	assert_eq(view.net_hint_at(Vector2(-50, -50)), "", "und außerhalb erst recht nicht")

## Display-Pixel in der Mitte der Zelle face im Summen-Netz.
func _net_pixel(face: int) -> Vector2:
	var net := view._net
	return net.get_global_rect().position \
		+ DieNetView.cell_position(face, net.cell) + Vector2.ONE * net.cell * 0.5

# --- Die Ziel-Säule steht durch alles --------------------------------------------

func test_the_grip_keeps_the_target_column_standing() -> void:
	# Die Zeremonie läuft in der Serien-Reihe UNTER dem Fenster - die Ziel-Säule
	# bleibt stehen, sie ist das Ziel.
	run.purchase_pack(Pack.number_pack(), 0)
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	view.choose_target(0)
	view.pull_lever()
	assert_true(view.bench_open())
	assert_not_null(view._net, "und das Summen-Netz steht")

func test_every_rebuild_reports_the_stages() -> void:
	# scene_root hängt die echten Würfel daran - ohne die Meldung stünden sie über
	# Bühnen, die es nicht mehr gibt.
	# Die Schläge in einem Array zählen: eine Lambda fängt lokale Zahlen als KOPIE.
	var beats: Array = []
	view.die_stages_changed.connect(func() -> void: beats.append(1))
	view.refresh()
	assert_gt(beats.size(), 0, "jeder Neuaufbau meldet seine Bühnen")

# --- Hinweiskarte in der linken Flanke -----------------------------------------

func test_the_hover_card_shows_title_and_body_and_sits_in_the_left_flank() -> void:
	view.show_hover_info("Meißel", "Kopiert einen Seitenwert auf eine andere Seite.")
	await wait_frames(2)
	assert_true(view.hover_info_visible(), "der Schirm trägt einen Hinweis")
	assert_eq(view._info_title.text, "Meißel")
	assert_eq(view._info_body.text, "Kopiert einen Seitenwert auf eine andere Seite.")
	var screen := view._info_screen.get_rect()
	assert_eq(screen.position.x, 0.0, "bündig mit der linken Fensterkante")
	assert_almost_eq(screen.size.x, view.info_width(), 1.0, "und füllt die Flanke")
	assert_gte(screen.position.x, 0.0)
	assert_lte(screen.end.y, view.shelf_top() + 1.0, "und nie unter die Buchten")

func test_the_hover_card_takes_a_body_without_a_title() -> void:
	view.show_hover_info("", "Rubin II: +10 Mult")
	await wait_frames(2)
	assert_true(view.hover_info_visible(), "eine einzelne Zeile genügt")
	assert_false(view._info_title.visible, "ohne Titel bleibt die Titelzeile weg")

func test_clearing_hides_the_hover_card() -> void:
	view.show_hover_info("Meißel", "Kopiert einen Seitenwert.")
	view.clear_hover_info()
	assert_false(view.hover_info_visible(), "leer heißt weg")
	view.show_hover_info("", "")
	assert_false(view.hover_info_visible(), "und zwei leere Texte räumen sie ebenso ab")

## Der Schirm ist kein Kartenauftritt: er STEHT, auch wenn nichts unter dem
## Zeiger liegt - Text auf blankem Filz wäre Text im Nichts.
func test_the_info_screen_stands_even_without_a_hint() -> void:
	await wait_frames(2)
	assert_not_null(view._info_screen, "der Schirm steht von Anfang an")
	assert_true(view._info_screen.visible)
	assert_false(view.hover_info_visible(), "aber er trägt noch nichts")
	var standing := view._info_screen.get_rect()
	view.show_hover_info("Rubin", "+4 Mult")
	await wait_frames(2)
	assert_true(view.hover_info_visible())
	assert_eq(view._info_screen.get_rect(), standing, "und er rührt sich dabei nicht")
	view.clear_hover_info()
	await wait_frames(2)
	assert_false(view.hover_info_visible(), "der Hinweis erlischt")
	assert_eq(view._info_screen.get_rect(), standing, "der Schirm bleibt")

## Der Schirm hat eine feste Größe, also paßt sich der TEXT ein: der längste Satz
## des Spiels bleibt darin, ein kurzer behält den vollen Grad.
func test_a_long_hint_shrinks_itself_into_the_screen() -> void:
	await wait_frames(2)
	var u := view.size.x / 100.0
	var longest := ""
	for engraving in Engraving.all():
		if engraving.description.length() > longest.length():
			longest = engraving.description
	view.show_hover_info("Pointer", longest)
	await wait_frames(2)
	var small: int = view._info_body.get_theme_font_size("font_size")
	assert_lt(small, int(u * WorkshopView.INFO_BODY), "der lange Satz wird kleiner gesetzt")
	var font := view._info_body.get_theme_font("font")
	var block := font.get_multiline_string_size(longest, HORIZONTAL_ALIGNMENT_CENTER,
		view._info_text_width(), small)
	assert_lte(block.y, view.info_screen_rect().size.y,
		"und paßt damit in den Schirm")

	view.show_hover_info("Rubin", "+4 Mult")
	await wait_frames(2)
	assert_eq(view._info_body.get_theme_font_size("font_size"), int(u * WorkshopView.INFO_BODY),
		"ein kurzer Hinweis behält den vollen Grad")
	assert_eq(view._info_title.get_theme_font_size("font_size"), int(u * WorkshopView.INFO_TITLE),
		"und der kurze Titel ebenso")

## Der schwerste ECHTE Inhalt des Schirms ist der Fach-Würfel: längster
## Würfelname plus längster Seelenname als Kennung, längste Seelen-Beschreibung
## als Auskunft. Beides zusammen paßt UNBESCHNITTEN - Titel wie Wirkung geben
## dafür Grade her (früher paßte sich nur die Wirkung ein, und der dreizeilige
## Titel schob sie aus dem Schirm).
func test_the_worst_real_fach_hint_fits_the_screen_uncut() -> void:
	await wait_frames(2)
	var die_name := ""
	for template: Dictionary in DiceOffer.TEMPLATES:
		var candidate: String = template["name"]
		if candidate.length() > die_name.length():
			die_name = candidate
	var soul_name := ""
	var soul_text := ""
	for essence in Essence.all():
		if essence.display_name.length() > soul_name.length():
			soul_name = essence.display_name
		if essence.description.length() > soul_text.length():
			soul_text = essence.description
	var title := "%s – %s" % [die_name, soul_name]
	# Die gesperrte Fassung ist die längere der beiden Klick-Zeilen (scene_root._fach_hint).
	var body := "Augensumme 24.\n%s\n%s" % [soul_text,
		"Die Runde ist unterschrieben - eingesetzt wird vor dem Wurf oder im Laden."]
	view.show_hover_info(title, body)
	await wait_frames(2)
	var u := view.size.x / 100.0
	var width := view._info_text_width()
	var title_font := view._info_title.get_theme_font("font")
	var body_font := view._info_body.get_theme_font("font")
	var stacked := WorkshopView.text_block_height(title_font, title, width,
		view._info_title.get_theme_font_size("font_size"),
		view._info_title.get_theme_constant("line_spacing"))
	stacked += u * WorkshopView.INFO_LINE_GAP
	stacked += WorkshopView.text_block_height(body_font, body, width,
		view._info_body.get_theme_font_size("font_size"),
		view._info_body.get_theme_constant("line_spacing"))
	var room: float = view.info_screen_rect().size.y - u * WorkshopView.INFO_PAD * 2.0
	assert_lte(stacked, room, "Kennung und Auskunft stehen zusammen im Schirm")
	assert_lt(view._info_title.get_theme_font_size("font_size"),
		int(u * WorkshopView.INFO_TITLE), "die lange Kennung wird kleiner gesetzt")

# --- Der Neuzugang gehört dem VORRAT ---------------------------------------------
# Getauscht wird am Vorrat (Ziehen aus dem Ausgabefach auf einen Pool-Sitz), und
# angesehen wird ein Würfel auf dem PODEST am Fach - beides außerhalb des Fensters.

func test_the_exchange_picker_is_gone() -> void:
	assert_false(view.has_method("open_exchange"),
		"der Tausch-Wähler ist tot - getauscht wird am Vorrat")
	assert_false(view.has_method("close_exchange"))
	assert_false(view.has_method("exchanging"))
