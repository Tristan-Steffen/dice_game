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

func test_der_gesaeumte_sitz_ist_das_aktuelle_ziel() -> void:
	# Im DAUER-Modus wählt der Zell-Tipp das Werkstatt-Ziel - und die Zelle trägt
	# dessen Gold-Saum.
	await wait_frames(2)
	view.show_pool("Tippen wählt das Werkstatt-Ziel", run.owned_pool, 6, 7)
	await wait_frames(2)
	assert_eq(view.target_index(), 7)
	assert_eq(view.grid()._highlights, [7], "genau diese Zelle ist gesäumt")

func test_ein_gewechselter_saum_baut_das_teure_raster_NICHT_neu() -> void:
	await wait_frames(2)
	view.show_pool(view.title(), run.owned_pool, 6, 2)
	await wait_frames(2)
	var tile: Button = view.grid().tiles[2]
	view.show_pool(view.title(), run.owned_pool, 6, 9)
	await wait_frames(2)
	assert_eq(view.grid().tiles[2], tile, "dieselben Kacheln, nur umgestylt")
	assert_eq(view.grid()._highlights, [9], "der Saum ist umgezogen")

func test_ohne_ziel_ist_keine_zelle_gesaeumt() -> void:
	await wait_frames(2)
	view.show_pool(view.title(), run.owned_pool, 6, 4)
	await wait_frames(2)
	view.show_pool(view.title(), run.owned_pool, 6, -1)
	await wait_frames(2)
	assert_eq(view.target_index(), -1)
	assert_eq(view.grid()._highlights, [], "der Saum ist fort")

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

# --- Die LADUNG als FARBSTUFE ------------------------------------------------------
# Jede Kachel trägt ihre Ladung als Saum und Außenschein, durchgebrannte stehen
# dunkel mit gedimmtem Netz - so sortiert der Spieler den Vorrat nach Ladung, ohne
# jeden Würfel anzusehen.

func _box(index: int) -> StyleBoxFlat:
	return view.grid().tiles[index].get_theme_stylebox("normal")

func test_die_kachel_traegt_die_ladung_als_farbstufe() -> void:
	run.owned_pool[1].charge = 1
	run.owned_pool[2].charge = 3
	view.show_pool(view.title(), run.owned_pool, 6)
	await wait_frames(2)
	var cold := _box(0)
	var warm := _box(1)
	var hot := _box(2)
	assert_gt(warm.border_color.b, cold.border_color.b, "Glimmen zieht ins Violett")
	assert_gt(hot.border_color.b, warm.border_color.b, "und der Überschlag weiter")
	assert_eq(cold.shadow_size, 0, "kalt trägt keinen Schein")
	assert_gt(hot.shadow_color.a, warm.shadow_color.a, "die Stufe trägt den Schein")

func test_die_durchgebrannte_kachel_steht_dunkel() -> void:
	run.owned_pool[3].burn_out()
	view.show_pool(view.title(), run.owned_pool, 6)
	await wait_frames(2)
	var burned := _box(3)
	assert_lt(burned.bg_color.get_luminance(), _box(0).bg_color.get_luminance(),
		"tot, nicht heiß")
	assert_eq(burned.shadow_size, 0, "und ohne jeden Schein")
	var tile: Button = view.grid().tiles[3]
	var net: Control = tile.get_child(0).get_child(0)
	assert_eq(net.modulate, DiceGridView.BURNED_NET_DIM, "das Netz ist gedimmt")

## Das Raster prüft seine Frische am INHALT - die Ladung gehört dazu, sonst bliebe
## die Kachel auf ihrer alten Stufe stehen.
func test_eine_geaenderte_ladung_baut_das_raster_neu() -> void:
	await wait_frames(2)
	var before := _box(2).border_color
	run.owned_pool[2].charge = 3
	view.show_pool(view.title(), run.owned_pool, 6)
	await wait_frames(2)
	assert_ne(_box(2).border_color, before, "die Signatur sieht die Ladung")

## Seele UND Ladung kommen aus der EINEN Quelle (hint_for) - nichts steht doppelt.
func test_der_tooltip_nennt_die_ladung_und_die_seele_genau_einmal() -> void:
	run.owned_pool[4].essence_id = Essence.NEON
	run.owned_pool[4].charge = 2
	view.show_pool(view.title(), run.owned_pool, 6)
	await wait_frames(2)
	var text: String = view.grid().tiles[4].tooltip_text
	var soul: String = Essence.by_id(Essence.NEON).display_name
	assert_eq(text.count(soul), 1, "der Seelen-Name steht genau einmal")
	assert_string_contains(text, DieDefinition.charge_name(2), "und die Ladungs-Stufe dabei")

# --- Die HINWEIS-ZEILE am unteren Rand (2026-09-11) ---------------------------

## Ihr Band ist RESERVIERT, auch wenn sie schweigt - sonst spränge das Raster bei
## jedem Überfahren. Dafür sitzt das Raster HÖHER als die Fenstermitte.
func test_das_band_der_hinweis_zeile_bleibt_frei_und_hebt_das_raster() -> void:
	await wait_frames(2)
	var foot: Label = view.get_node("Hinweis")
	var host: Control = view.get_node("RasterHost")
	var u := view.size.x / DeckGlassView.UNIT_DIV
	assert_almost_eq(foot.position.y + foot.size.y,
		view.size.y - u * DeckGlassView.MARGIN_UNITS, 0.5, "sie steht am unteren Rand")
	assert_lte(host.position.y + host.size.y, foot.position.y + 0.5,
		"und das Raster endet über ihr")
	var grid := view.grid()
	var below := view.size.y - (host.position.y + grid.position.y + grid.size.y)
	assert_gte(below, u * (DeckGlassView.FOOT_UNITS + DeckGlassView.FOOT_GAP_UNITS) - 0.5,
		"unter dem Raster bleibt das ganze Band frei - um so viel sitzt es höher")

## Sie sagt, was der Zeiger berührt - und schweigt, wo nichts liegt.
func test_die_hinweis_zeile_traegt_was_ihr_gereicht_wird() -> void:
	await wait_frames(2)
	var foot: Label = view.get_node("Hinweis")
	assert_eq(view.hint(), "", "ohne Zeiger schweigt sie")
	view.set_hint("Gold: zahlt beim Nehmen")
	assert_eq(view.hint(), "Gold: zahlt beim Nehmen")
	assert_eq(foot.text, "Gold: zahlt beim Nehmen", "und die Zeile trägt sie")
	view.set_hint("")
	assert_eq(foot.text, "", "leer heißt still")

## Und sie kommt aus dem RASTER: die Kachel unter dem Zeiger erklärt sich selbst.
func test_das_raster_beantwortet_den_zeiger_fuer_die_zeile() -> void:
	await wait_frames(2)
	var grid := view.grid()
	var at := grid.tiles[0].get_global_rect().get_center()
	assert_ne(grid.hint_at(at), "", "die Detail-Kachel schweigt nie")
	assert_eq(grid.hint_at(Vector2(-100, -100)), "", "außerhalb des Rasters schon")

## Der SCHIRM bleibt halb durchsichtig wie jeder andere - DECKEND ist allein der
## Grund unter der Hinweis-Zeile (Spieler-Wunsch 2026-09-11: der Vorrat darf
## durchschimmern, nur nicht durch den Text).
func test_nur_der_grund_der_hinweis_zeile_deckt() -> void:
	await wait_frames(2)
	var back: StyleBoxFlat = view.get_node("Schirm").get_theme_stylebox("panel")
	var foot_back: Panel = view.get_node("HinweisGrund")
	var solid: StyleBoxFlat = foot_back.get_theme_stylebox("panel")
	assert_lt(back.bg_color.a, 1.0, "der Schirm scheint durch")
	assert_eq(back.bg_color, TableScreen.window_style().bg_color,
		"und zwar in der Farbe jedes anderen Schirms")
	assert_eq(solid.bg_color.a, 1.0, "sein Zeilen-Grund deckt")
	assert_eq(solid.bg_color, TableScreen.BACKGROUND_COLOR.blend(TableScreen.FRAME_BG),
		"dieselbe Farbe, einmal über den Anzeige-Grund gemischt")

## Und er liegt WIRKLICH unter der Zeile: sie steht ganz in ihm.
func test_der_grund_traegt_die_ganze_zeile() -> void:
	await wait_frames(2)
	var foot_back: Panel = view.get_node("HinweisGrund")
	var foot: Label = view.get_node("Hinweis")
	assert_true(Rect2(foot_back.position, foot_back.size).encloses(
		Rect2(foot.position, foot.size)), "die Zeile liegt ganz auf ihrem Grund")
	assert_lt(foot_back.position.y, foot.position.y, "er beginnt über der Zeile")

## Er steht FREI: ringsum eingerückt wie der Rest des Schirms, an allen vier Ecken
## gerundet - er berührt weder Wand noch Boden (Spieler-Wunsch 2026-09-11).
func test_der_grund_steht_frei_und_ist_rundum_gerundet() -> void:
	await wait_frames(2)
	var foot_back: Panel = view.get_node("HinweisGrund")
	var margin := view.size.x / DeckGlassView.UNIT_DIV * DeckGlassView.MARGIN_UNITS
	assert_almost_eq(foot_back.position.x, margin, 0.5, "links eingerückt")
	assert_almost_eq(foot_back.position.x + foot_back.size.x, view.size.x - margin,
		0.5, "rechts ebenso")
	assert_almost_eq(foot_back.position.y + foot_back.size.y, view.size.y - margin,
		0.5, "und er endet über dem Boden")
	var style: StyleBoxFlat = foot_back.get_theme_stylebox("panel")
	assert_gt(style.corner_radius_top_left, 0, "oben links gerundet")
	assert_eq(style.corner_radius_top_right, style.corner_radius_top_left)
	assert_eq(style.corner_radius_bottom_left, style.corner_radius_top_left)
	assert_eq(style.corner_radius_bottom_right, style.corner_radius_top_left)
