extends GutTest
## Tier-2-Tests der Werkstatt (WorkshopView): die Grundseite zeigt die Aufspannung
## als Projektor- und Netzzeile, versiegelte Pakete liegen als Stapel in der
## Regal-Leiste statt als Karten im Fenster, und die Würfel-Pakete laufen hier
## ihre Zeremonie.

var view: WorkshopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = WorkshopView.new()
	view.size = Vector2(600, 500)
	add_child_autofree(view)
	view.run = run

# --- Die Grundseite gehört der Aufspannung --------------------------------------

func test_packs_never_render_as_cards_in_the_window() -> void:
	# Das Regal ist der EINZIGE Ort versiegelter Ware - im Fenster stehen nur die
	# Netze der Aufspannung und die Presse-Plätze.
	run.purchase_pack(Pack.number_pack(), 0)
	run.purchase_pack(Pack.dice_pack(DiceOffer.TEMPLATES[0]), 0)
	assert_eq(view._clamp_nets.size(), run.clamp_count(), "die Netzzeile steht")
	assert_eq(view._press_slot_buttons.size(), PhantomPress.BATCH_CAP)
	assert_eq(run.owned_packs.size(), 2, "und die Siegel bleiben ganz")

func test_the_net_row_is_the_readout_of_the_clamped_dice() -> void:
	assert_eq(view._clamp_nets.size(), run.clamped_dice.size())

func test_opening_the_top_dice_pack_reports_its_slot() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	run.purchase_pack(Pack.dice_pack(DiceOffer.TEMPLATES[0]), 0)
	var opened: Array[int] = []
	view.pack_activated.connect(func(index: int) -> void: opened.append(index))
	assert_true(view.open_top_dice_pack())
	assert_eq(opened, [1] as Array[int], "der Platz des Würfel-Pakets wird gemeldet")
	assert_eq(run.owned_packs.size(), 1, "das Würfel-Paket ist verbraucht")

func test_without_a_dice_pack_nothing_opens() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	assert_false(view.open_top_dice_pack())
	assert_eq(view._phase, WorkshopView.Phase.STASH)

# --- Zeremonie: Entsiegelung -----------------------------------------------------

## Gravur-Pakete laufen über die Presse (test_workshop_press) - open_pack ist der
## Weg der Würfel-Pakete und lässt sie unangetastet liegen.
func test_open_pack_leaves_an_engraving_pack_sealed() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view.open_pack(0)
	assert_eq(view._phase, WorkshopView.Phase.STASH, "keine Zeremonie")
	assert_eq(run.owned_packs.size(), 1, "und das Paket bleibt liegen")

func test_a_new_run_does_not_inherit_a_die_that_still_seeks_a_slot() -> void:
	# Der Würfel schwebt bis zum Einsetzen auf der Bank - er darf den Laufwechsel
	# nicht überleben und über dem frischen Vorrat stehen bleiben.
	_open_dice_pack()
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE)
	view.run = GameRun.new_run()
	assert_eq(view._phase, WorkshopView.Phase.STASH, "das Einsetzen verfällt mit dem Lauf")
	assert_true(view.revealed_dice().is_empty(), "und der Würfel mit ihm")

# --- Zeremonie: Würfel-Pakete ---------------------------------------------------

## Öffnet ein 3er-Paket UND wählt gleich einen Würfel - der Normalfall für die
## Einsetz-Tests. Wer den Wahlschritt selbst prüfen will, nimmt _reveal_dice_pack.
func _open_dice_pack() -> void:
	_reveal_dice_pack()
	view.choose_die(0)

## Öffnet ein 3er-Paket bis zur WAHL: alle drei liegen offen.
func _reveal_dice_pack() -> void:
	_open_pack_without_ceremony()
	view._unseal.finish_now()  # Entsiegelung überspringen: hier geht es ums Wählen

## Öffnet ein 3er-Paket, LÄSST die Zeremonie aber laufen - noch ist kein Würfel
## körperlich.
func _open_pack_without_ceremony() -> void:
	# "Niedrige Serie": 3 Würfel, damit die Wahl überhaupt eine ist.
	run.purchase_pack(Pack.dice_pack(DiceOffer.TEMPLATES[4]), 0)
	view.open_pack(0)

func test_a_multi_die_pack_reveals_all_of_them_for_the_choice() -> void:
	_reveal_dice_pack()
	assert_eq(view._phase, WorkshopView.Phase.CHOOSE_DIE, "erst wählen, dann einsetzen")
	assert_eq(view._revealed_dice.size(), 3, "alle drei liegen offen")

# --- Die Würfel liegen auf der Bank ---------------------------------------------
# Die Wahl zeigt keine Karten mehr: je Würfel bleibt eine LEERE Bühne im Fenster,
# über der scene_root den echten Würfel schweben lässt. Das Fenster sagt nur noch,
# worum es geht.

func test_the_choice_leaves_one_empty_stage_per_die() -> void:
	_reveal_dice_pack()
	await wait_frames(2)  # Layout: vorher haben die Bühnen kein Rechteck
	assert_eq(view.die_stage_centers().size(), 3, "je Würfel eine Bühne")
	assert_eq(view.revealed_dice().size(), 3, "und je Bühne ein Würfel")
	for stage in view._die_stages:
		assert_eq(stage.get_child_count(), 0, "die Bühne selbst zeigt nichts")

func test_the_stages_stand_inside_the_window_side_by_side() -> void:
	# Der alte Kartenstapel ragte unten aus dem Fenster - die Bühnen dürfen das nie.
	_reveal_dice_pack()
	await wait_frames(2)
	var window := Rect2(Vector2.ZERO, view.size)
	var centers := view.die_stage_centers()
	for center in centers:
		assert_true(window.has_point(center - view.global_position),
			"die Bühne %s liegt im Fenster %s" % [center, window])
	assert_almost_eq(centers[0].y, centers[2].y, 0.5, "die drei stehen nebeneinander")
	assert_lt(centers[0].x, centers[1].x, "und in ihrer Reihenfolge")
	assert_lt(centers[1].x, centers[2].x)

func test_the_places_stand_before_the_seal_breaks() -> void:
	# Die Zeichen brauchen ihr Ziel schon während der Zeremonie - also liegen die
	# Plätze ab dem Öffnen. Verraten wird dabei nichts: kein Würfel ist körperlich,
	# kein Netz zu sehen.
	_open_pack_without_ceremony()
	await wait_frames(2)
	assert_eq(view._phase, WorkshopView.Phase.CHOOSE_DIE)
	assert_eq(view.die_stage_centers().size(), 3, "die Plätze stehen")
	for i in 3:
		assert_false(view.die_materialized(i), "noch steht kein Würfel auf der Bank")
		assert_false(view._die_nets[i].get_child(0).visible, "und kein Netz verrät ihn")

func test_a_net_appears_with_its_die_and_the_place_does_not_move() -> void:
	# Regression: das Netz belegte seinen Platz erst beim Auftauchen - die Bühne
	# darüber rutschte damit genau in dem Moment weg, in dem das Zeichen darauf
	# zuflog.
	_open_pack_without_ceremony()
	await wait_frames(2)
	var before := view.die_stage_centers()
	view._unseal.finish_now()
	await wait_frames(2)
	assert_eq(view.die_stage_centers(), before, "die Plätze bleiben, wo sie waren")
	for i in 3:
		assert_true(view.die_materialized(i), "jetzt stehen alle drei")
		assert_true(view._die_nets[i].get_child(0).visible, "und jedes Netz dazu")

func test_the_net_is_the_button_not_the_die() -> void:
	_reveal_dice_pack()
	var picked: DieDefinition = view.revealed_dice()[1]
	view._die_nets[1].pressed.emit()
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE)
	assert_same(view.revealed_dice()[0], picked, "das Netz wählt seinen Würfel")

func test_a_die_that_is_not_on_the_bench_yet_cannot_be_chosen() -> void:
	_open_pack_without_ceremony()
	view.choose_die(0)
	assert_eq(view._phase, WorkshopView.Phase.CHOOSE_DIE, "erst muss er da sein")
	assert_eq(view.revealed_dice().size(), 3)

func test_right_click_steps_back_from_the_placement_to_the_choice() -> void:
	# Der Zurück-Schritt: die Abgewählten sind nicht verfallen, sie standen nur
	# nicht mehr auf der Bank.
	_reveal_dice_pack()
	var all_three := view.revealed_dice().duplicate()
	view.choose_die(2)
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE)
	assert_true(view.go_back(), "von hier führt ein Weg zurück")
	assert_eq(view._phase, WorkshopView.Phase.CHOOSE_DIE)
	assert_eq(view.revealed_dice(), all_three, "alle drei stehen wieder zur Wahl")
	for i in 3:
		assert_true(view.die_materialized(i), "und zwar körperlich - sie standen ja schon")
	view.choose_die(0)
	assert_same(view.revealed_dice()[0], all_three[0], "die zweite Wahl gilt")

func test_a_single_die_pack_has_nowhere_to_go_back_to() -> void:
	run.purchase_pack(Pack.dice_pack(DiceOffer.TEMPLATES[0]), 0)
	view.open_pack(0)
	view._unseal.finish_now()
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE)
	assert_false(view.go_back(), "es gab nie eine Wahl")
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE)

func test_the_stash_never_goes_back() -> void:
	assert_false(view.go_back())

func test_the_choice_replaces_the_workshop_title_instead_of_adding_a_line() -> void:
	# Das Fenster gehört den Würfeln: eine Zeile weniger ist Platz für ein
	# größeres Netz.
	_reveal_dice_pack()
	var texts: Array[String] = []
	for child in view._content.get_children():
		if child is Label:
			texts.append((child as Label).text)
	assert_eq(texts, ["EINEN WÜRFEL WÄHLEN"] as Array[String],
		"nur der Titel - kein WERKSTATT, keine Hinweiszeile")

func test_a_net_cell_explains_itself() -> void:
	# Die Zeile gehört NICHT ins Fenster - scene_root schreibt sie in die Leiste
	# unter der Werkbank, wo auch die Schubladen sprechen.
	_reveal_dice_pack()
	await wait_frames(2)
	view.revealed_dice()[0].set_face_material(0, DieMaterial.GOLD)
	view.refresh()
	await wait_frames(2)
	var said := view.net_hint_at(_net_pixel(0, 0))
	assert_true(said.contains(DieMaterial.by_id(DieMaterial.GOLD).display_name),
		"die Zelle sagt, was auf ihr liegt: '%s'" % said)

func test_the_essence_chip_explains_the_soul() -> void:
	_reveal_dice_pack()
	view.revealed_dice()[0].essence_id = Essence.NEON
	view.refresh()
	await wait_frames(2)
	# Die Kanten-Chip-Ecke oben links im Kreuz.
	var said := view.net_hint_at(view._die_nets[0].get_global_rect().position + Vector2.ONE * 2.0)
	assert_true(said.contains(Essence.by_id(Essence.NEON).display_name),
		"der Chip erklärt die Seele: '%s'" % said)

func test_a_bare_face_and_a_point_outside_say_nothing() -> void:
	_reveal_dice_pack()
	await wait_frames(2)
	for face in 6:
		view.revealed_dice()[0].set_face_material(face, "")
	view.refresh()
	await wait_frames(2)
	assert_eq(view.net_hint_at(_net_pixel(0, 0)), "", "eine nackte Seite erklärt nichts")
	assert_eq(view.net_hint_at(Vector2(-50, -50)), "", "und außerhalb erst recht nicht")

func test_the_placement_net_explains_itself_too() -> void:
	# Auch das nicht mehr wählbare Netz erklärt seine Zellen - es ist Auskunft.
	_open_dice_pack()
	await wait_frames(2)
	view.revealed_dice()[0].set_face_material(0, DieMaterial.RUBY)
	view.refresh()
	await wait_frames(2)
	assert_true(view.net_hint_at(_net_pixel(0, 0)).contains(
		DieMaterial.by_id(DieMaterial.RUBY).display_name), "auch ein gesperrtes Netz spricht")

## Display-Pixel in der Mitte der Zelle face im Netz index.
func _net_pixel(index: int, face: int) -> Vector2:
	var cell := maxf(view.size.x, 200.0) / 100.0 * WorkshopView.CHOICE_CELL
	return view._die_nets[index].get_global_rect().position \
		+ DieNetView.cell_position(face, cell) + Vector2.ONE * cell * 0.5

func test_the_placement_step_keeps_its_window_free_of_text() -> void:
	# Regression: eine Hinweiszeile ohne Umbruch riss mit ihrer Mindestbreite die
	# Würfel-Spalte über das halbe Fenster, und das Raster blieb ein Briefmarken-
	# Feld. Das Fenster gehört dem Würfel und dem Raster.
	_open_dice_pack()
	await wait_frames(2)
	for child in view._content.get_children():
		assert_false(child is Label, "kein Text im Fenster - das gehört Würfel und Raster")

func test_the_pool_grid_gets_the_room_the_die_column_leaves() -> void:
	# Wie an der Gravur-Station: links der Würfel, der Rest gehört dem Raster.
	_open_dice_pack()
	await wait_frames(2)
	assert_gt(view._pool_grid.size.x, view.size.x * 0.5,
		"das Raster füllt mehr als die halbe Fensterbreite")
	assert_gt(view._pool_grid.get_global_rect().position.x,
		view._die_nets[0].get_global_rect().end.x, "und steht rechts neben der Würfel-Spalte")

func test_the_pool_grid_reports_the_soul_under_the_pointer() -> void:
	# Dieselbe Frage wie ans Netz: scene_root fragt je Bild EINE Stelle ab, also
	# muss auch die Raster-Kachel darüber antworten.
	_open_dice_pack()
	await wait_frames(2)
	run.owned_pool[0].essence_id = Essence.NEON
	view._pool_grid.fill(view._pool_defs())
	await wait_frames(2)
	assert_eq(view.net_hint_at(view._pool_grid.tiles[0].get_global_rect().get_center()),
		Essence.hint(Essence.NEON), "die beseelte Kachel nennt ihre Seele")
	assert_eq(view.net_hint_at(view._pool_grid.tiles[1].get_global_rect().get_center()), "",
		"die seelenlose daneben schweigt")

func test_the_placement_net_is_information_not_a_button() -> void:
	_open_dice_pack()
	await wait_frames(2)
	assert_eq(view._die_nets.size(), 1, "auch der gewählte Würfel hat sein Netz")
	assert_true(view._die_nets[0].disabled, "dort gibt es nichts mehr zu wählen")

func test_the_net_is_as_big_as_a_die_one_decides_about() -> void:
	# Wer ÜBER einen Würfel entscheidet, sieht ihn in der Entscheidungs-Größe.
	_reveal_dice_pack()
	await wait_frames(2)
	var u := maxf(view.size.x, 200.0) / 100.0
	assert_almost_eq(view._die_nets[0].size,
		DieNetView.net_size(u * DieNetView.TRAY_TILE),
		Vector2.ONE * 1.0)  # der Container rundet auf ganze Pixel

func test_the_placement_step_keeps_a_stage_for_the_chosen_die() -> void:
	_open_dice_pack()
	await wait_frames(2)
	assert_eq(view.die_stage_centers().size(), 1, "auch der gewählte Würfel schwebt")

func test_the_stash_has_no_stages_at_all() -> void:
	assert_eq(view.die_stage_centers().size(), 0)
	assert_true(view.revealed_dice().is_empty())

# --- Die Aufspannung räumt dem Paket das Fenster ---------------------------------
# Solange ein Paket das Fenster füllt, gibt es keine Netzzeile - und damit keine
# Spalte, über der ein Zwingen-Würfel stehen dürfte. scene_root lässt sie abtreten.

func test_the_clamps_leave_the_bench_while_a_pack_holds_the_window() -> void:
	assert_true(view.clamps_on_bench(), "auf der Grundseite stehen sie")
	_open_pack_without_ceremony()
	assert_eq(view._phase, WorkshopView.Phase.CHOOSE_DIE)
	assert_false(view.clamps_on_bench(), "die Wahl gehört dem Paket")
	view._unseal.finish_now()
	view.choose_die(0)
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE)
	assert_false(view.clamps_on_bench(), "und das Einsetzen ebenso")
	view.finish_ceremony()
	assert_true(view.clamps_on_bench(), "danach kommen sie zurück")

func test_opening_a_pack_already_clears_the_bench() -> void:
	# Die Entsiegelung ist der erste Moment - die Zeichen fliegen schon.
	run.purchase_pack(Pack.dice_pack(DiceOffer.TEMPLATES[0]), 0)
	var beats: Array = []
	view.die_stages_changed.connect(func() -> void: beats.append(1))
	view.open_pack(0)
	assert_gt(beats.size(), 0, "scene_root erfährt vom Wechsel")
	assert_false(view.clamps_on_bench())

func test_the_press_keeps_the_clamps_standing() -> void:
	# Die Pressung läuft UNTER der Netzzeile, und ihre Beute liegt darunter - die
	# Zwingen bleiben stehen, sie sind die Ziele.
	run.purchase_pack(Pack.number_pack(), 0)
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	view.start_press()
	assert_eq(view._phase, WorkshopView.Phase.STASH)
	assert_true(view.placing(), "die Beute liegt")
	assert_true(view.clamps_on_bench())

func test_every_rebuild_reports_the_stages() -> void:
	# scene_root hängt die echten Würfel daran - ohne die Meldung stünden sie über
	# Bühnen, die es nicht mehr gibt.
	# Die Schläge in einem Array zählen: eine Lambda fängt lokale Zahlen als KOPIE.
	var beats: Array = []
	view.die_stages_changed.connect(func() -> void: beats.append(1))
	_reveal_dice_pack()
	assert_gt(beats.size(), 0, "die Wahl meldet ihre Bühnen")
	beats.clear()
	view.choose_die(0)
	assert_gt(beats.size(), 0, "der Einsetz-Schritt ebenso")
	beats.clear()
	view.discard_dice()
	assert_gt(beats.size(), 0, "und das Ende meldet, dass keine mehr stehen")

func test_choosing_keeps_exactly_one_die() -> void:
	_reveal_dice_pack()
	var picked: DieDefinition = view._revealed_dice[1]
	view.choose_die(1)
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE)
	assert_eq(view._revealed_dice.size(), 1, "der Rest bleibt im Paket")
	assert_same(view._revealed_dice[0], picked, "und zwar genau der gewählte")

func test_a_single_die_pack_skips_the_choice() -> void:
	# Ein Würfel, keine Entscheidung: direkt einsetzen.
	run.purchase_pack(Pack.dice_pack(DiceOffer.TEMPLATES[0]), 0)
	view.open_pack(0)
	view._unseal.finish_now()
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE, "nichts zu wählen")
	assert_eq(view._revealed_dice.size(), 1)

func test_dice_pack_shows_its_die_and_the_pool_on_one_page() -> void:
	_open_dice_pack()
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE)
	assert_eq(view._revealed_dice.size(), 1)
	assert_eq(view._pool_grid.tiles.size(), GameRun.POOL_SIZE, "je Pool-Platz eine Kachel")
	assert_eq(view._selected_slot, -1, "noch nichts gewählt")
	assert_true(view._place_button.disabled, "ohne Auswahl bleibt Einsetzen dunkel")

func test_selecting_a_slot_lights_up_the_place_button() -> void:
	_open_dice_pack()
	view.toggle_slot(4)
	assert_eq(view._selected_slot, 4)
	assert_false(view._place_button.disabled, "mit dem Platz leuchtet Einsetzen")

func test_clicking_a_selected_slot_again_deselects_it() -> void:
	_open_dice_pack()
	view.toggle_slot(4)
	view.toggle_slot(4)
	assert_eq(view._selected_slot, -1, "derselbe Platz wählt wieder ab")
	assert_true(view._place_button.disabled)

func test_a_second_slot_replaces_the_first() -> void:
	# Aus einem Paket kommt GENAU EIN Würfel - es gibt nur einen Platz zu wählen,
	# und der nächste Klick verschiebt ihn.
	_open_dice_pack()
	for slot in [0, 1, 2, 3]:
		view.toggle_slot(slot)
	assert_eq(view._selected_slot, 3, "der zuletzt geklickte Platz gilt")

func test_confirming_replaces_the_selected_slot() -> void:
	_open_dice_pack()
	var incoming: String = view._revealed_dice[0].style_id
	view.toggle_slot(4)
	view.confirm_placement()
	assert_eq(run.owned_pool[4].style_id, incoming, "Platz 4 trägt den Paket-Würfel")
	assert_eq(run.owned_pool[5].style_id, "normal", "Nachbarplatz unberührt")
	assert_eq(view._phase, WorkshopView.Phase.STASH, "danach wieder das Lager")

func test_placement_keeps_the_pool_instance_so_the_trays_follow() -> void:
	# Die Trays und das Rundendeck halten dieselbe DieDefinition wie der Pool -
	# ein Tausch der Instanz ließe sie den alten Würfel zeigen.
	_open_dice_pack()
	var held: DieDefinition = run.owned_pool[4]
	view.toggle_slot(4)
	view.confirm_placement()
	assert_same(run.owned_pool[4], held, "der Pool-Platz behält seine Instanz")
	assert_eq(held.style_id, "low", "und trägt jetzt den Paket-Würfel")

func test_the_unchosen_dice_of_the_pack_are_lost() -> void:
	# Drei aufgedeckt, einer genommen: die anderen beiden verfallen ersatzlos.
	_reveal_dice_pack()
	view.choose_die(0)
	var incoming: String = view._revealed_dice[0].style_id
	view.toggle_slot(4)
	view.confirm_placement()
	var placed := 0
	for def in run.owned_pool:
		if def.style_id == incoming:
			placed += 1
	assert_eq(placed, 1, "genau ein Platz wurde ersetzt")
	assert_eq(view._revealed_dice.size(), 0, "der Rest ist verfallen")

func test_confirming_without_a_selection_does_nothing() -> void:
	_open_dice_pack()
	view.confirm_placement()
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE, "die Zeremonie läuft weiter")
	for def in run.owned_pool:
		assert_eq(def.style_id, "normal", "der Pool bleibt unberührt")

func test_grid_follows_the_tray_order_not_the_pool_order() -> void:
	# scene_root reicht die Tray-Reihenfolge herein (der Pool liegt dort gemischt):
	# Kachel 0 muss den Würfel treffen, der auf dem Tisch oben links liegt.
	_open_dice_pack()
	var order: Array[DieDefinition] = []
	order.append(run.owned_pool[7])   # Kachel 0 = Pool-Platz 7
	order.append(null)                # gezogener Würfel: leerer Platz
	order.append(run.owned_pool[2])
	view.set_pool_order(order, 3)
	var incoming: String = view._revealed_dice[0].style_id
	view.toggle_slot(0)
	view.confirm_placement()
	assert_eq(run.owned_pool[7].style_id, incoming, "Kachel 0 traf Pool-Platz 7")
	assert_eq(run.owned_pool[0].style_id, "normal", "NICHT der Pool-Platz 0")

func test_empty_tray_slots_cannot_be_selected() -> void:
	_open_dice_pack()
	var order: Array[DieDefinition] = []
	order.append(null)
	order.append(run.owned_pool[3])
	view.set_pool_order(order, 2)
	view.toggle_slot(0)
	assert_eq(view._selected_slot, -1, "auf einem leeren Platz ist nichts zu ersetzen")
	view.toggle_slot(1)
	assert_eq(view._selected_slot, 1, "der belegte Platz geht")

func test_discarding_drops_the_whole_content() -> void:
	_open_dice_pack()
	view.discard_dice()
	assert_eq(view._phase, WorkshopView.Phase.STASH, "danach wieder das Lager")
	assert_eq(view._revealed_dice.size(), 0, "Inhalt ist abgeräumt")
	for def in run.owned_pool:
		assert_eq(def.style_id, "normal", "verworfene Würfel verfallen")

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
