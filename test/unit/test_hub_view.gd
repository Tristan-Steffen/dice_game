extends GutTest
## Tests der Seiten-Verwaltung des Hubs (HubView): zu jeder Zeit ist höchstens
## EINE angehängte Seite ODER die Home-Übersicht (content_root) sichtbar. Die
## Seiten öffnen/schließen sich selbst über ihr visible (wie Shop.open() /
## Shop.close()); der Hub hört auf visibility_changed und
## setzt die Regel durch. Verdrängte Seiten kehren beim Schließen der
## verdrängenden zurück (LIFO); reset_pages räumt hart auf (Spiel-Neustart).

var hub: HubView
var page_a: Control
var page_b: Control

func before_each() -> void:
	hub = HubView.new()
	hub.size = Vector2(1000, 600)
	add_child_autofree(hub)
	hub.layout()
	page_a = Control.new()
	page_a.visible = false
	page_b = Control.new()
	page_b.visible = false
	hub.attach_panel(page_a)
	hub.attach_panel(page_b)

## Anzahl der sichtbaren "Flächen" (Seiten + Home) - die Ein-Seiten-Regel
## verlangt genau 1.
func _visible_surfaces() -> int:
	var count := 0
	for surface in [page_a, page_b, hub.content_root]:
		if surface.visible:
			count += 1
	return count

func test_home_is_visible_while_no_page_is_open() -> void:
	assert_true(hub.content_root.visible)
	assert_eq(_visible_surfaces(), 1)

func test_opening_a_page_hides_home() -> void:
	page_a.visible = true
	assert_false(hub.content_root.visible, "Home weicht der Seite")
	assert_eq(_visible_surfaces(), 1)

func test_opening_a_second_page_suppresses_the_first() -> void:
	page_a.visible = true
	page_b.visible = true
	assert_false(page_a.visible, "die ältere Seite ist verdrängt")
	assert_true(page_b.visible)
	assert_false(hub.content_root.visible, "Home blutet nicht durch")
	assert_eq(_visible_surfaces(), 1)

func test_closing_the_top_page_restores_the_suppressed_one() -> void:
	page_a.visible = true
	page_b.visible = true
	page_b.visible = false  # z.B. Gravur-Station "Fertig"
	assert_true(page_a.visible, "die verdrängte Seite kehrt zurück (Shop-Fall)")
	assert_false(hub.content_root.visible)
	assert_eq(_visible_surfaces(), 1)

func test_closing_the_last_page_restores_home() -> void:
	page_a.visible = true
	page_a.visible = false
	assert_true(hub.content_root.visible, "ohne Seite zeigt der Hub die Übersicht")
	assert_eq(_visible_surfaces(), 1)

func test_a_manually_closed_page_does_not_come_back() -> void:
	# Wird eine VERDRÄNGTE Seite von außen wieder geöffnet und normal geschlossen,
	# ist sie aus dem Verdrängungs-Gedächtnis raus - sie taucht nicht doppelt auf.
	page_a.visible = true
	page_b.visible = true   # a verdrängt
	page_a.visible = true   # a von außen zurückgeholt -> b verdrängt
	assert_false(page_b.visible)
	page_a.visible = false  # a geschlossen -> b kehrt zurück, a wartet nirgends mehr
	assert_true(page_b.visible)
	page_b.visible = false
	assert_true(hub.content_root.visible, "danach ist Home dran, nicht wieder a")
	assert_false(page_a.visible)

func test_reset_pages_closes_everything_and_shows_home() -> void:
	page_a.visible = true
	page_b.visible = true  # a verdrängt, würde ohne Reset zurückkehren
	hub.reset_pages()
	assert_false(page_a.visible)
	assert_false(page_b.visible)
	assert_true(hub.content_root.visible)
	# Das Verdrängungs-Gedächtnis ist leer: eine neue Seite auf und zu -> Home.
	page_b.visible = true
	page_b.visible = false
	assert_false(page_a.visible, "a kehrt nach dem Reset nicht mehr zurück")
	assert_true(hub.content_root.visible)

func test_settings_button_sits_on_the_home_page() -> void:
	assert_not_null(hub.settings_button, "der Einstellungen-Knopf ist gebaut")
	assert_true(hub.content_root.is_ancestor_of(hub.settings_button), "auf der Home-Seite")
	assert_true(hub.settings_button.is_visible_in_tree(), "sichtbar, solange Home dran ist")

func test_settings_button_hides_with_the_home_page() -> void:
	page_a.visible = true  # eine Seite verdrängt Home
	assert_false(hub.settings_button.is_visible_in_tree(), "mit der Home-Seite ausgeblendet")
	page_a.visible = false
	assert_true(hub.settings_button.is_visible_in_tree(), "kehrt mit der Home-Seite zurück")

func test_shop_button_stays_hidden_until_it_is_allowed() -> void:
	assert_not_null(hub.shop_button, "der Laden-Knopf ist gebaut")
	assert_true(hub.content_root.is_ancestor_of(hub.shop_button), "auf der Home-Seite")
	assert_false(hub.shop_button.visible, "im Normalfall steht er nicht da")
	hub.set_shop_reopen_visible(true)
	assert_true(hub.shop_button.is_visible_in_tree())
	hub.set_shop_reopen_visible(false)
	assert_false(hub.shop_button.visible)

func test_shop_button_emits_signal_when_pressed() -> void:
	watch_signals(hub)
	hub.set_shop_reopen_visible(true)
	hub.shop_button.pressed.emit()
	assert_signal_emitted(hub, "shop_reopen_requested")

func test_settings_button_emits_signal_when_pressed() -> void:
	watch_signals(hub)
	hub.settings_button.pressed.emit()
	assert_signal_emitted(hub, "settings_pressed")

func test_settings_menu_is_built_hidden_and_toggles_on_the_display() -> void:
	# Das Einstellungs-Menü lebt jetzt AUF dem Hub (kein 2D-Dropdown mehr):
	# anfangs verborgen, der Knopf klappt es auf und wieder zu.
	assert_not_null(hub.settings_menu, "das Menü ist gebaut")
	assert_false(hub.settings_menu.visible, "anfangs zu")
	hub.settings_button.pressed.emit()
	assert_true(hub.settings_menu.visible, "erster Druck öffnet")
	hub.settings_button.pressed.emit()
	assert_false(hub.settings_menu.visible, "zweiter Druck schließt")

func test_settings_menu_entries_emit_their_action_and_close_the_menu() -> void:
	watch_signals(hub)
	hub.settings_button.pressed.emit()  # aufklappen
	var box: VBoxContainer = hub.settings_menu.get_node("Box")
	var wanted := {
		"Neues Spiel": "new_game_requested",
		"Debug: Runde gewinnen": "debug_win_round_requested",
	}
	for button: Button in box.get_children():
		for label: String in wanted:
			if button.text == label:
				button.pressed.emit()
				assert_signal_emitted(hub, wanted[label], "'%s' meldet %s" % [label, wanted[label]])
	assert_false(hub.settings_menu.visible, "eine Aktion schließt das Menü wieder")

func test_debug_money_button_emits_and_keeps_menu_open() -> void:
	watch_signals(hub)
	hub.settings_button.pressed.emit()  # aufklappen
	var box: VBoxContainer = hub.settings_menu.get_node("Box")
	var found := false
	for button: Button in box.get_children():
		if button.text == "Debug: +100$":
			found = true
			button.pressed.emit()
			button.pressed.emit()  # zweimal für Mehrfach-Klick
	assert_true(found, "der +100$-Knopf ist im Menü")
	assert_signal_emit_count(hub, "debug_money_requested", 2, "je Klick ein Signal")
	assert_true(hub.settings_menu.visible, "Menü bleibt für Mehrfach-Klick offen")

func test_debug_energy_button_emits_and_keeps_menu_open() -> void:
	watch_signals(hub)
	hub.settings_button.pressed.emit()  # aufklappen
	var box: VBoxContainer = hub.settings_menu.get_node("Box")
	var found := false
	for button: Button in box.get_children():
		if button.text == "Debug: +10 ⚡":
			found = true
			button.pressed.emit()
			button.pressed.emit()  # zweimal für Mehrfach-Klick
	assert_true(found, "der Energie-Knopf ist im Menü")
	assert_signal_emit_count(hub, "debug_energy_requested", 2, "je Klick ein Signal")
	assert_true(hub.settings_menu.visible, "Menü bleibt für Mehrfach-Klick offen")

func test_settings_menu_hides_when_a_page_takes_the_hub() -> void:
	hub.settings_button.pressed.emit()  # Menü offen auf der Home-Seite
	assert_true(hub.settings_menu.visible)
	page_a.visible = true  # eine Seite verdrängt Home
	assert_false(hub.settings_menu.visible, "das Menü gehört zur Home-Seite und weicht mit ihr")

func test_interactive_at_detects_buttons_but_not_empty_felt() -> void:
	# Grundlage der neuen Klick-Regel (scene_root): ein Klick auf einen Knopf
	# DRÜCKT ihn, ein Klick auf leere Hub-Fläche ZOOMT in den Hub.
	await wait_frames(2)  # Container erst sortieren lassen (echte Knopf-Rechtecke)
	var on_button := hub.settings_button.get_global_rect().get_center()
	assert_true(hub.interactive_at(on_button), "der Einstellungen-Knopf ist ein interaktiver Punkt")
	# Ein Punkt WEIT über dem (unten sitzenden) Knopf - in der Kopfzeile (nur
	# Labels mit mouse IGNORE) - ist leere Fläche.
	var top_center := Vector2(hub.get_global_rect().get_center().x, hub.get_global_rect().position.y + 4)
	assert_false(hub.interactive_at(top_center),
		"die Kopfzeile ist leere Hub-Fläche (dort wird gezoomt, nicht gedrückt)")

func test_interactive_at_ignores_a_hidden_button() -> void:
	# Ist der Knopf verborgen (eine Seite hat die Home-Übersicht verdrängt), ist
	# seine Fläche NICHT interaktiv - der Klick dort zoomt.
	await wait_frames(2)
	var center := hub.settings_button.get_global_rect().get_center()
	page_a.visible = true
	assert_false(hub.settings_button.is_visible_in_tree())
	assert_false(hub.interactive_at(center), "ein verborgener Knopf zählt nicht")

func test_test_materials_label_can_be_updated() -> void:
	hub.set_test_materials_label("🧪 Testmaterialien: AN")
	hub.settings_button.pressed.emit()
	var box: VBoxContainer = hub.settings_menu.get_node("Box")
	var found := false
	for button: Button in box.get_children():
		if button.text == "🧪 Testmaterialien: AN":
			found = true
	assert_true(found, "die Testmaterialien-Beschriftung ist aktualisiert")

func test_test_pointers_label_can_be_updated() -> void:
	hub.set_test_pointers_label("🧪 Testpointer: AN")
	hub.settings_button.pressed.emit()
	var box: VBoxContainer = hub.settings_menu.get_node("Box")
	var found := false
	for button: Button in box.get_children():
		if button.text == "🧪 Testpointer: AN":
			found = true
	assert_true(found, "die Testpointer-Beschriftung ist aktualisiert")

func test_the_pointer_test_button_reports_its_own_signal() -> void:
	# Eigener Schalter, nicht an die Materialien gekoppelt.
	var fired := [0, 0]
	hub.test_pointers_requested.connect(func() -> void: fired[0] += 1)
	hub.test_materials_requested.connect(func() -> void: fired[1] += 1)
	var box: VBoxContainer = hub.settings_menu.get_node("Box")
	for button: Button in box.get_children():
		if button.text.begins_with("🧪 Testpointer"):
			button.pressed.emit()
	assert_eq(fired, [1, 0], "nur der Pointer-Schalter meldet sich")

func test_attaching_an_already_visible_panel_takes_the_page() -> void:
	var eager := Control.new()
	eager.visible = true
	hub.attach_panel(eager)
	assert_false(hub.content_root.visible, "die sichtbar angehängte Seite übernimmt sofort")
	assert_true(eager.visible)

# --- Weiche Wechsel ----------------------------------------------------------
# Der harte Schnitt fiel auf, solange die Kamera noch fährt (Titel-HUD): jetzt
# blendet die Seite aus, DANN blendet die nachrückende Fläche ein.

func test_a_fading_page_holds_the_surface_until_it_is_gone() -> void:
	page_a.visible = true
	hub.fade_page_out(page_a)
	assert_true(page_a.visible, "während der Blende steht die Seite noch")
	await wait_seconds(HubView.PAGE_FADE * 3.0)
	assert_false(page_a.visible)
	assert_almost_eq(page_a.modulate.a, 1.0, 0.001, "fürs nächste Öffnen wieder deckend")
	assert_true(hub.content_root.visible, "Home ist nachgerückt")
	assert_almost_eq(hub.content_root.modulate.a, 1.0, 0.001, "und fertig eingeblendet")
	assert_eq(_visible_surfaces(), 1)

func test_the_hand_over_gets_a_dark_moment_to_work_in() -> void:
	# Der Spiel-Neustart hängt hier ein: die alte Fläche ist weg, die neue steht
	# dunkel bereit - sein Aufbau-Ruck sitzt so in keiner Blende. Das Einblenden
	# übernimmt dann der Aufrufer.
	page_a.visible = true
	var seen := []
	hub.fade_page_out(page_a, func() -> void:
		seen.append([page_a.visible, hub.content_root.modulate.a]))
	await wait_seconds(HubView.PAGE_FADE * 3.0)
	assert_eq(seen.size(), 1, "genau einmal aufgerufen")
	assert_eq(seen[0], [false, 0.0], "alte Seite weg, nachrückende dunkel")
	assert_almost_eq(hub.content_root.modulate.a, 0.0, 0.001,
		"ohne fade_current_in bleibt sie dunkel - der Aufrufer entscheidet, wann")
	hub.fade_current_in()
	await wait_seconds(HubView.PAGE_FADE * 2.0)
	assert_almost_eq(hub.content_root.modulate.a, 1.0, 0.001)

func test_fading_a_page_in_still_obeys_the_one_page_rule() -> void:
	hub.fade_page_in(page_a)
	assert_true(page_a.visible)
	assert_false(hub.content_root.visible, "Home weicht sofort")
	await wait_seconds(HubView.PAGE_FADE * 2.0)
	assert_almost_eq(page_a.modulate.a, 1.0, 0.001)
	assert_eq(_visible_surfaces(), 1)

func test_a_reset_cancels_a_running_fade() -> void:
	page_a.visible = true
	hub.fade_page_out(page_a)
	hub.reset_pages()
	assert_false(page_a.visible)
	assert_almost_eq(page_a.modulate.a, 1.0, 0.001, "keine halbe Blende bleibt kleben")
	await wait_seconds(HubView.PAGE_FADE * 3.0)
	assert_false(page_a.visible, "die abgebrochene Blende holt die Seite nicht zurück")
	assert_true(hub.content_root.visible)
