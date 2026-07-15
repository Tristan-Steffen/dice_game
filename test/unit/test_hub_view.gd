extends GutTest
## Tests der Seiten-Verwaltung des Hubs (HubView): zu jeder Zeit ist höchstens
## EINE angehängte Seite ODER die Home-Übersicht (content_root) sichtbar. Die
## Seiten öffnen/schließen sich selbst über ihr visible (wie Shop.open() /
## DieInspectorView.show_die()/close()); der Hub hört auf visibility_changed und
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

func test_settings_button_emits_signal_when_pressed() -> void:
	watch_signals(hub)
	hub.settings_button.pressed.emit()
	assert_signal_emitted(hub, "settings_pressed")

func test_attaching_an_already_visible_panel_takes_the_page() -> void:
	var eager := Control.new()
	eager.visible = true
	hub.attach_panel(eager)
	assert_false(hub.content_root.visible, "die sichtbar angehängte Seite übernimmt sofort")
	assert_true(eager.visible)
