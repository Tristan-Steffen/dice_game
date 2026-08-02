extends GutTest
## Tier-2-Tests der Werkstatt (WorkshopView): das Lager zeigt je gekauftem Paket
## eine Karte, meldet den Öffnen-Wunsch als Signal und folgt dem Lagerbestand.

var view: WorkshopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = WorkshopView.new()
	view.size = Vector2(600, 500)
	add_child_autofree(view)
	view.run = run

func test_empty_stash_shows_a_hint_and_no_cards() -> void:
	assert_eq(view._pack_buttons.size(), 0, "leeres Lager hat keine Karten")

func test_each_pack_gets_its_own_card() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	run.purchase_pack(Pack.dice_pack(DiceOffer.TEMPLATES[0]), 0)
	assert_eq(view._pack_buttons.size(), 2, "je Paket eine Lagerkarte")

func test_stash_follows_the_run() -> void:
	run.purchase_pack(Pack.material_pack(), 0)
	assert_eq(view._pack_buttons.size(), 1, "Kauf erscheint sofort im Lager")
	view.open_pack(0)
	view._unseal.finish_now()
	assert_eq(view._pack_buttons.size(), 0, "geöffnetes Paket verschwindet")

func test_clicking_a_card_opens_that_pack() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	run.purchase_pack(Pack.material_pack(), 0)
	var opened: Array[int] = []
	view.pack_activated.connect(func(index: int) -> void: opened.append(index))
	view._pack_buttons[1].pressed.emit()
	assert_eq(opened, [1] as Array[int], "der geklickte Platz wird gemeldet")
	assert_eq(run.owned_packs.size(), 1, "das Kanten-Paket ist verbraucht")

# --- Lieferung aus dem Laden (das Licht IST das Paket) --------------------------

func test_pending_delivery_holds_the_newest_card_back() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	assert_eq(view._pack_buttons.size(), 1, "das ältere Paket liegt im Regal")
	run.purchase_pack(Pack.material_pack(), 0)
	view.expect_delivery()
	assert_eq(view._pack_buttons.size(), 1, "das unterwegs befindliche Paket fehlt noch")
	view.deliver_pack()
	assert_eq(view._pack_buttons.size(), 2, "bei Ankunft erscheint es")

func test_delivery_counter_survives_several_purchases_at_once() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	run.purchase_pack(Pack.material_pack(), 0)
	view.expect_delivery()
	view.expect_delivery()
	assert_eq(view._pack_buttons.size(), 0, "beide Lichter sind noch unterwegs")
	view.deliver_pack()
	assert_eq(view._pack_buttons.size(), 1, "eines nach dem anderen")
	view.deliver_pack()
	assert_eq(view._pack_buttons.size(), 2)

func test_extra_deliveries_are_ignored() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view.deliver_pack()  # ohne angemeldete Lieferung
	assert_eq(view._pack_buttons.size(), 1, "das Regal bleibt, wie es ist")

func test_a_new_run_cancels_pending_deliveries() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view.expect_delivery()
	var fresh := GameRun.new_run()
	fresh.purchase_pack(Pack.material_pack(), 0)
	view.run = fresh
	assert_eq(view._pack_buttons.size(), 1, "der neue Lauf zeigt sein Lager vollständig")

# --- Zeremonie: Entsiegelung -----------------------------------------------------

func test_opening_a_pack_starts_the_unsealing() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view.open_pack(0)
	assert_eq(view._phase, WorkshopView.Phase.UNSEAL)
	assert_eq(view._revealed_engravings.size(), Pack.NUMBER_COUNT, "Inhalt ist ausgewürfelt")
	assert_not_null(view._unseal, "die Zeremonie läuft")

func test_the_stash_is_not_booked_before_the_seal_breaks() -> void:
	# Die Schubladen hängen an engravings_changed - buchte das Öffnen sofort,
	# verrieten ihre Zähler die Seltenheit noch während des Ladens.
	run.purchase_pack(Pack.number_pack(), 0)
	view.open_pack(0)
	assert_eq(run.owned_engravings.size(), 0, "während des Ladens ist nichts verbucht")
	view._unseal.finish_now()
	assert_eq(run.owned_engravings.size(), Pack.NUMBER_COUNT, "erst der Bruch bucht")

func test_engraving_pack_returns_to_the_stash_on_its_own() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view.open_pack(0)
	view._unseal.finish_now()
	assert_eq(view._phase, WorkshopView.Phase.STASH, "kein Klick nötig")
	assert_null(view._unseal, "die Zeremonie ist abgeräumt")

func test_every_engraving_is_dispatched_exactly_once() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	var sent: Array[String] = []
	view.engraving_dispatched.connect(func(id: String, _px: Vector2, _rarity: int) -> void:
		sent.append(id))
	view.open_pack(0)
	view._unseal.finish_now()
	assert_eq(sent.size(), Pack.NUMBER_COUNT, "je Stück ein Licht in die Schublade")

func test_the_content_is_booked_only_once() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view.open_pack(0)
	view._unseal.finish_now()
	view.finish_ceremony()  # doppelter Abschluss darf nicht nachbuchen
	assert_eq(run.owned_engravings.size(), Pack.NUMBER_COUNT)

func test_an_interrupted_ceremony_still_books_its_content() -> void:
	# Die Gravur-Station legt sich über die Werkbank und beendet die Zeremonie -
	# der schon ausgewürfelte Inhalt darf dabei nicht verfallen.
	run.purchase_pack(Pack.number_pack(), 0)
	view.open_pack(0)
	var station := Control.new()
	view.attach_station(station)
	assert_eq(run.owned_engravings.size(), Pack.NUMBER_COUNT, "Inhalt ist gerettet")
	assert_eq(view._phase, WorkshopView.Phase.STASH)

func test_a_new_run_does_not_inherit_a_die_that_still_seeks_a_slot() -> void:
	# Der Würfel schwebt bis zum Einsetzen auf der Bank - er darf den Laufwechsel
	# nicht überleben und über dem frischen Vorrat stehen bleiben.
	_open_dice_pack()
	assert_eq(view._phase, WorkshopView.Phase.PLACE_DICE)
	view.run = GameRun.new_run()
	assert_eq(view._phase, WorkshopView.Phase.STASH, "das Einsetzen verfällt mit dem Lauf")
	assert_true(view.revealed_dice().is_empty(), "und der Würfel mit ihm")

func test_a_new_run_does_not_inherit_the_open_content() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view.open_pack(0)
	var fresh := GameRun.new_run()
	view.run = fresh
	assert_eq(run.owned_engravings.size(), Pack.NUMBER_COUNT, "der alte Lauf behält ihn")
	assert_eq(fresh.owned_engravings.size(), 0, "der neue erbt nichts")

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
	# Regression: die Hinweiszeile hatte keinen Umbruch - ihre Mindestbreite riss
	# die Würfel-Spalte über das halbe Fenster, und das Raster blieb ein Briefmarken-
	# Feld. Die Führung gehört in die Info-Leiste, wie an der Gravur-Station.
	_open_dice_pack()
	await wait_frames(2)
	for child in view._content.get_children():
		assert_false(child is Label, "kein Text im Fenster - das gehört Würfel und Raster")
	assert_true(view.prompt().contains("Platz"), "geführt wird in der Leiste: '%s'" % view.prompt())
	assert_true(view.prompt().contains("Rechtsklick"), "samt Rückweg, wenn es einen gibt")

func test_only_the_placement_step_has_a_prompt() -> void:
	assert_eq(view.prompt(), "", "das Lager führt niemanden")
	_reveal_dice_pack()
	assert_eq(view.prompt(), "", "und die Wahl spricht durch die Würfel selbst")

func test_a_single_die_pack_promises_no_way_back() -> void:
	run.purchase_pack(Pack.dice_pack(DiceOffer.TEMPLATES[0]), 0)
	view.open_pack(0)
	view._unseal.finish_now()
	assert_false(view.prompt().contains("Rechtsklick"), "dort gibt es keine Wahl zurück")

func test_the_pool_grid_gets_the_room_the_die_column_leaves() -> void:
	# Wie an der Gravur-Station: links der Würfel, der Rest gehört dem Raster.
	_open_dice_pack()
	await wait_frames(2)
	assert_gt(view._pool_grid.size.x, view.size.x * 0.5,
		"das Raster füllt mehr als die halbe Fensterbreite")
	assert_gt(view._pool_grid.get_global_rect().position.x,
		view._die_nets[0].get_global_rect().end.x, "und steht rechts neben der Würfel-Spalte")

func test_the_placement_net_is_information_not_a_button() -> void:
	_open_dice_pack()
	await wait_frames(2)
	assert_eq(view._die_nets.size(), 1, "auch der gewählte Würfel hat sein Netz")
	assert_true(view._die_nets[0].disabled, "dort gibt es nichts mehr zu wählen")

func test_the_net_is_as_big_as_the_one_in_the_engraving_station() -> void:
	# Wer ÜBER einen Würfel entscheidet, sieht ihn in derselben Größe wie an der
	# Gravur-Station - nicht in der kleineren Auskunfts-Größe der Hover-Karte.
	_reveal_dice_pack()
	await wait_frames(2)
	var u := maxf(view.size.x, 200.0) / 100.0
	assert_almost_eq(view._die_nets[0].size,
		DieNetView.net_size(u * DieInspectorView.TRAY_TILE),
		Vector2.ONE * 1.0)  # der Container rundet auf ganze Pixel
	assert_gt(view._die_nets[0].size.x, DieNetView.net_size(u * WorkshopView.HOVER_CELL).x,
		"und damit größer als die Hover-Karte")

func test_the_placement_step_keeps_a_stage_for_the_chosen_die() -> void:
	_open_dice_pack()
	await wait_frames(2)
	assert_eq(view.die_stage_centers().size(), 1, "auch der gewählte Würfel schwebt")

func test_the_stash_has_no_stages_at_all() -> void:
	assert_eq(view.die_stage_centers().size(), 0)
	assert_true(view.revealed_dice().is_empty())

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
