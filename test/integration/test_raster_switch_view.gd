extends GutTest
## Der RASTER-UMSCHALTER am Grubenrand: die Taste, die den Vorrat zwischen KÖRPER
## und RASTER umlegt. Geprüft werden ihr Platz (reine Funktion aus der Pool-
## Geometrie), ihre Aufschrift (sie nennt, was der Druck LIEFERT) und der blinde
## Zustand - sie verschwindet nie, sie antwortet nur nicht.

## Der Fußabdruck des Vorrats-Platzes: sein Slotraster plus einen halben Platz Saum
## (dieselbe Zahl wie in test_pit_carrier_stage).
const POOL_HALF := Vector2(4.5, 5.4)

func _switch() -> RasterSwitchView:
	var view := RasterSwitchView.new()
	add_child_autofree(view)
	view.setup(RasterSwitchView.spot_beside(Vector3.ZERO, POOL_HALF))
	return view

# --- Ihr Platz -------------------------------------------------------------------

func test_die_taste_steht_UEBER_dem_loch_und_beruehrt_es_nie() -> void:
	var view := _switch()
	assert_gt(view.bounds_min().x, POOL_HALF.x,
		"sie liegt ganz jenseits der Bildschirm-oberen Lochkante")
	assert_almost_eq(view.bounds_min().x - POOL_HALF.x, RasterSwitchView.GAP, 0.0001,
		"und zwar um genau die Fuge zurückgesetzt")

func test_sie_steht_buendig_mit_dem_bildschirm_rechten_ende_der_grube() -> void:
	var view := _switch()
	assert_almost_eq(view.bounds_max().y, POOL_HALF.y, 0.0001,
		"ihre rechte Kante ist die rechte Lochkante")
	assert_gt(view.bounds_max().y - view.bounds_min().y, 0.0,
		"und sie hat eine Breite")

func test_der_platz_folgt_dem_loch() -> void:
	# Reine Funktion: verschiebt sich das Loch, verschiebt sich die Taste mit.
	var moved := RasterSwitchView.spot_beside(Vector3(3.0, 0.0, -2.0), POOL_HALF)
	var home := RasterSwitchView.spot_beside(Vector3.ZERO, POOL_HALF)
	assert_almost_eq(moved.x - home.x, 3.0, 0.0001)
	assert_almost_eq(moved.z - home.z, -2.0, 0.0001)
	assert_almost_eq(home.y, 0.0, 0.0001, "sie liegt auf der Tischfläche")

func test_dieselben_masse_bauen_nichts_neu() -> void:
	var view := _switch()
	var plate := view.get_node("Taste")
	view.setup(RasterSwitchView.spot_beside(Vector3.ZERO, POOL_HALF))
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
