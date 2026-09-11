extends GutTest
## Der RASTER-UMSCHALTER am Grubenrand: die Taste, die den Vorrat zwischen KÖRPER
## und RASTER umlegt. Geprüft werden ihr Platz (reine Funktion aus der Pool-
## Geometrie), ihre Aufschrift (sie nennt, was der Druck LIEFERT) und der blinde
## Zustand - sie verschwindet nie, sie antwortet nur nicht.

## Der ANKER der Taste: die Unterkante der Die-View-Säule rechts des Vorrats, als
## Weltpunkt (scene_root rechnet ihn aus dem gemeldeten Display-Rechteck).
const ANCHOR := Vector3(-11.0, 0.0, 26.5)

func _switch() -> RasterSwitchView:
	var view := RasterSwitchView.new()
	add_child_autofree(view)
	view.setup(RasterSwitchView.spot_under(ANCHOR))
	return view

# --- Ihr Platz -------------------------------------------------------------------

func test_die_taste_haengt_eine_fuge_UNTER_ihrem_anker() -> void:
	var view := _switch()
	# Bildschirm-unten ist Welt -X: ihre Oberkante liegt um die Fuge unter dem Anker.
	assert_almost_eq(ANCHOR.x - view.bounds_max().x, RasterSwitchView.GAP, 0.0001,
		"um genau die Fuge zurückgesetzt")
	assert_lt(view.bounds_max().x, ANCHOR.x, "und ganz unterhalb")

func test_sie_steht_mittig_unter_ihrem_anker() -> void:
	var view := _switch()
	assert_almost_eq((view.bounds_min().y + view.bounds_max().y) * 0.5, ANCHOR.z,
		0.0001, "ihre Mitte ist die Mitte der Säule")
	assert_gt(view.bounds_max().y - view.bounds_min().y, 0.0, "und sie hat eine Breite")

## Sie paßt UNTER die Säule (gemessen 4,37 Welt breit) - sonst stünde sie breiter
## da als das, woran sie hängt.
func test_sie_bleibt_schmaler_als_die_saeule_ueber_ihr() -> void:
	assert_lt(RasterSwitchView.HALF.y * 2.0, 4.37, "schmaler als die Säule")
	assert_gt(RasterSwitchView.HALF.y * 2.0, 3.0, "aber breit genug für die Aufschrift")

func test_der_platz_folgt_dem_anker() -> void:
	# Reine Funktion: verschiebt sich die Säule, verschiebt sich die Taste mit.
	var moved := RasterSwitchView.spot_under(ANCHOR + Vector3(3.0, 0.0, -2.0))
	var home := RasterSwitchView.spot_under(ANCHOR)
	assert_almost_eq(moved.x - home.x, 3.0, 0.0001)
	assert_almost_eq(moved.z - home.z, -2.0, 0.0001)
	assert_almost_eq(home.y, 0.0, 0.0001, "sie liegt auf der Tischfläche")

func test_dieselben_masse_bauen_nichts_neu() -> void:
	var view := _switch()
	var plate := view.get_node("Taste")
	view.setup(RasterSwitchView.spot_under(ANCHOR))
	assert_eq(view.get_node("Taste"), plate, "idempotent")

# --- Ihre Aufschrift -------------------------------------------------------------

func test_die_aufschrift_nennt_was_der_druck_LIEFERT() -> void:
	assert_eq(RasterSwitchView.caption_for(false), RasterSwitchView.TEXT_TO_GRID,
		"stehen die Körper, holt der Druck das Raster")
	assert_eq(RasterSwitchView.caption_for(true), RasterSwitchView.TEXT_TO_BODIES,
		"liegt das Raster, holt er die Körper zurück")

func test_umlegen_tauscht_die_aufschrift() -> void:
	var view := _switch()
	assert_eq(view.caption(), RasterSwitchView.TEXT_TO_GRID)
	view.set_open(true)
	assert_eq(view.caption(), RasterSwitchView.TEXT_TO_BODIES)
	view.set_open(false)
	assert_eq(view.caption(), RasterSwitchView.TEXT_TO_GRID)

func test_blind_bleibt_sie_STEHEN_und_wechselt_nur_den_ton() -> void:
	var view := _switch()
	var label: Label3D = view.get_node("Aufschrift")
	var lit := label.modulate
	view.set_live(false)
	assert_false(view.live())
	assert_eq(label.text, RasterSwitchView.TEXT_TO_GRID, "die Aufschrift bleibt")
	assert_true(view.visible, "und die Taste steht")
	assert_ne(label.modulate, lit, "nur ihr Ton wird grau")
	view.set_live(true)
	assert_eq(label.modulate, lit, "und kommt zurück")

func test_die_aufschrift_liegt_auf_der_taste_und_liest_in_tisch_richtung() -> void:
	var view := _switch()
	var label: Label3D = view.get_node("Aufschrift")
	assert_gt(label.position.y, 0.0, "sie liegt ÜBER der Tastenfläche")
	# Der Text läuft entlang Welt +Z (Bildschirm rechts), Oberkante nach Welt +X.
	assert_almost_eq(label.transform.basis.x.z, 1.0, 0.0001)
	assert_almost_eq(label.transform.basis.y.x, 1.0, 0.0001)

func test_der_griff_hebt_sie_und_laesst_sie_wieder_los() -> void:
	var view := _switch()
	view.set_hovered(true)
	await wait_seconds(RasterSwitchView.HOVER_TIME + 0.05)
	assert_almost_eq(view.position.y, RasterSwitchView.HOVER_LIFT, 0.01)
	view.set_hovered(false)
	await wait_seconds(RasterSwitchView.HOVER_TIME + 0.05)
	assert_almost_eq(view.position.y, 0.0, 0.01)
