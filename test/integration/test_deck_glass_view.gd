extends GutTest
## Die GLAS-ANSICHT: das Netz-Raster des ganzen Vorrats, wie es auf dem geschlossenen
## Gruben-Glas liegt. Sitz i = Zelle i, in POOL-Spalten - die räumliche Entsprechung
## ist der Sinn der Übung. Bedienung wie am Pool-Tray: TIPPEN wählt, ZIEHEN legt um.
## Das Fenster malt nur und MELDET die zwei Gesten; gebucht wird draußen.

## Das Loch des Vorrats ist breiter als tief - das Fenster liegt genau darauf.
const RECT := Vector2(880, 700)

var view: DeckGlassView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = DeckGlassView.new()
	view.size = RECT
	add_child_autofree(view)
	view.visible = true
	view.show_pool("Wohin mit Sechser?", run.owned_pool, 6)

func test_das_raster_zeigt_den_GANZEN_vorrat_in_buch_ordnung() -> void:
	await wait_frames(2)
	var grid := view.grid()
	assert_not_null(grid, "das Raster steht")
	assert_eq(grid.tiles.size(), run.owned_pool.size(), "jede Kachel ein Besitz-Platz")
	assert_eq(grid.columns, 6, "und es liest in den POOL-Spalten")
	assert_true(grid.reorder_enabled, "Ziehen legt um")

func test_die_frage_steht_ueber_dem_raster() -> void:
	await wait_frames(2)
	assert_eq(view.title(), "Wohin mit Sechser?")
	var head: Label = view.get_node("Frage")
	assert_eq(head.text, "Wohin mit Sechser?")
	assert_lt(head.get_global_rect().end.y,
		view.get_node("RasterHost").get_global_rect().position.y + 1.0,
		"der Kopf steht über dem Raster, nicht darin")

func test_ein_tipp_meldet_den_pool_platz() -> void:
	await wait_frames(2)
	var seen := []
	view.cell_pressed.connect(func(index: int) -> void: seen.append(index))
	view.grid().tiles[11].pressed.emit()
	assert_eq(seen, [11], "genau der getippte Sitz")

func test_ein_zug_meldet_beide_plaetze() -> void:
	await wait_frames(2)
	var seen := []
	view.cells_reordered.connect(func(a: int, b: int) -> void: seen.append([a, b]))
	var grid := view.grid()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	grid._on_tile_input(press, 2)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = grid.tiles[9].get_global_rect().get_center()
	grid._on_tile_input(release, 2)
	assert_eq(seen, [[2, 9]], "Ausgang und Ziel")

func test_das_raster_folgt_der_buchung() -> void:
	await wait_frames(2)
	var moved := run.owned_pool[0]
	run.reorder_pool(0, 4)
	view.show_pool(view.title(), run.owned_pool, 6)
	await wait_frames(2)
	assert_eq(view.grid()._defs[4], moved, "Zelle 4 trägt jetzt den umgelegten Würfel")

func test_das_raster_sieht_den_TAUSCH_obwohl_die_referenzen_bleiben() -> void:
	# Der Tausch schreibt per become IN die Vorrats-Instanz: die Referenzliste ist
	# danach byteweise dieselbe. Die Frische muß darum den INHALT sehen.
	await wait_frames(2)
	var before: String = view.grid().tiles[5].tooltip_text
	run.stash_die(DieDefinition.fixed(6, "Immer 6"), 0)
	assert_true(run.exchange_pending_die(0, 5))
	view.show_pool(view.title(), run.owned_pool, 6)
	await wait_frames(2)
	assert_ne(view.grid().tiles[5].tooltip_text, before,
		"die Kachel trägt den neuen Inhalt, nicht den alten")
	assert_eq(DiceRowView.eye_total(run.owned_pool[5]), 36, "es ist wirklich der Sechser")

func test_gleicher_inhalt_baut_das_teure_raster_NICHT_neu() -> void:
	await wait_frames(2)
	var tile: Button = view.grid().tiles[3]
	view.show_pool(view.title(), run.owned_pool, 6)
	await wait_frames(2)
	assert_eq(view.grid().tiles[3], tile, "dieselbe Belegung, dieselben Kacheln")

func test_das_raster_fuellt_seinen_bereich() -> void:
	await wait_frames(2)
	var host: Control = view.get_node("RasterHost")
	var grid := view.grid().get_global_rect()
	assert_gt(grid.size.x, host.size.x * 0.8, "es nimmt die Breite, die es bekommt")
	assert_almost_eq(grid.get_center().x, host.get_global_rect().get_center().x, 4.0)
	assert_almost_eq(grid.get_center().y, host.get_global_rect().get_center().y, 4.0)

func test_die_zellen_nennen_ihre_seele_im_tooltip() -> void:
	# Die Kachel sagt es selbst - dieselbe Auskunft wie an jedem anderen Raster.
	run.owned_pool[3].essence_id = Essence.NEON
	# Frisch aufgeschlagen: die Seele steht, bevor das Raster den Vorrat liest.
	var fresh := DeckGlassView.new()
	fresh.size = RECT
	add_child_autofree(fresh)
	fresh.visible = true
	fresh.show_pool("Wohin mit Probe?", run.owned_pool, 6)
	await wait_frames(2)
	assert_true(fresh.grid().tiles[3].tooltip_text.contains(
		Essence.by_id(Essence.NEON).display_name), "die Seele steht an der Kachel")
