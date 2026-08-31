extends GutTest
## Das PIT ist der PARK-Zustand der Vorrats-Hebebühne, und was darin steht, ist der
## TRÄGER: der Vorrat parkt SICHTBAR, rückt reihenweise vor, und hinten wächst die
## Ablage. Geprüft wird die Maschine (Park mit bleibendem Cargo, das Band im Stand)
## und die Arithmetik des Sitz-Plans - die Tests bauen ihren Schacht selbst (mit
## Schirm, um dessen Endzustand mitzuprüfen); der echte Pool-Schacht fährt seit
## 2026-08-31 flach und ohne Schirm (siehe scene_root.POOL_PARK_DEPTH).

## Der Fußabdruck des Vorrats-Platzes: sein Slotraster plus einen halben Platz Saum.
const POOL_HALF := Vector2(4.5, 5.4)

func _shaft(covered := true) -> LiftShaftView:
	var shaft := LiftShaftView.new()
	add_child_autofree(shaft)
	shaft.setup(Vector3.ZERO, POOL_HALF, _tray_depth())
	shaft.order_skin(PlaceholderTexture2D.new())
	if covered:
		shaft.order_cover("", Color.AQUA)
	return shaft

## Dieselbe Rechnung wie scene_root._tray_shaft_depth.
func _tray_depth() -> float:
	var top := DiceTrayView.FLOAT_HEIGHT + DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT
	return maxf(VitrineView.shaft_depth(), top * VitrineView.SHAFT_ROOM)

# --- Die Tiefe trägt einen SCHWEBENDEN Würfel ----------------------------------

func test_das_oeffnungsband_traegt_einen_schwebenden_wuerfel() -> void:
	# Der Träger fährt MIT seinen schwebenden Würfeln - die müssen unter dem Sturz
	# durchpassen, sonst streift der oberste beim Ein- und Ausfahren.
	var top := DiceTrayView.FLOAT_HEIGHT + DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT
	var shaft := _shaft(false)
	assert_gt(shaft.depth, top, "die Grube ist tiefer als das Stück hoch ist")
	assert_gt(shaft.mouth_height(), top,
		"und ihr Öffnungsband höher als der schwebende Würfel")
	assert_almost_eq(shaft.park_y(), shaft.depth, 0.0001,
		"der Park steht auf der Anzeige-Tiefe")
	assert_almost_eq(shaft.travel_share, 1.0, 0.0001,
		"die Würfel-Bühnen bestellen keine Tieffahrt - hier steht keine Nachbargrube")

# --- Der Park nimmt seinen TRÄGER mit und läßt ihn SICHTBAR stehen -------------

func test_ein_park_nur_mit_mitfahrer_ist_ein_ganzer_fahrplan() -> void:
	# Der Vorrat fährt als bleibendes Cargo hinab: kein Ein-, kein Ausgang, nur die
	# Plattform samt Ware auf den Parkstand. Das MUSS ein Fahrplan sein.
	var shaft := _shaft()
	var cargo := Node3D.new()
	add_child_autofree(cargo)
	var tween := shaft.run_park([], [], [], [], 0.0, Callable(), [cargo], [Vector3.ZERO])
	assert_not_null(tween, "die Plattform parkt mit ihrer stehenden Ware")

func test_ohne_irgendeine_ware_gibt_es_keinen_park() -> void:
	var shaft := _shaft()
	assert_null(shaft.run_park([], [], [], [], 0.0))

func test_der_geparkte_traeger_bleibt_stehen_und_der_schirm_liegt_zu() -> void:
	var shaft := _shaft()
	shaft.park_hard()
	assert_true(shaft.visible, "das Pit steht offen")
	assert_almost_eq(shaft.platform_y(), -shaft.park_y(), 0.0001,
		"die Plattform steht auf Park-Tiefe - der Träger darauf")
	assert_almost_eq(shaft.cover_share(), 1.0, 0.0001, "und das Glas darüber")

# --- Das BAND im Stand: die Ablage-Reihe schiebt herein -------------------------

func test_das_hintere_band_faehrt_im_stand_auf_und_wieder_zu() -> void:
	var shaft := _shaft()
	shaft.park_hard()
	assert_almost_eq(shaft.shutter_open(true), 0.0, 0.0001, "geparkt steht alles zu")
	shaft.run_band(LiftShaftView.BAND_BACK, true, 0.0)  # ohne Takt springt es hart
	assert_almost_eq(shaft.shutter_open(true), 1.0, 0.0001, "die Reihe kann herein")
	assert_almost_eq(shaft.shutter_open(false), 0.0, 0.0001,
		"und nur das Band, das der Schritt benutzt")
	# Die Plattform hat sich dabei NICHT gerührt - das Band ist kein Fahrplan.
	assert_almost_eq(shaft.platform_y(), -shaft.park_y(), 0.0001)
	shaft.run_band(LiftShaftView.BAND_BACK, false, 0.0)
	assert_almost_eq(shaft.shutter_open(true), 0.0, 0.0001)

func test_der_harte_aufraeum_pfad_nimmt_das_offene_band_mit() -> void:
	var shaft := _shaft()
	shaft.park_hard()
	shaft.run_band(LiftShaftView.BAND_BACK, true, 0.0)
	shaft.settle_hard()
	assert_almost_eq(shaft.shutter_open(true), 0.0, 0.0001, "kein Loch in der Wand")
	assert_almost_eq(shaft.cover_share(), 0.0, 0.0001, "der Schirm ist eingefahren")
	assert_almost_eq(shaft.platform_y(), 0.0, 0.0001, "und die Platte bündig")

func test_der_park_stellt_das_band_hart_wieder_zu() -> void:
	var shaft := _shaft()
	shaft.park_hard()
	shaft.run_band(LiftShaftView.BAND_BACK, true, 0.0)
	shaft.park_hard()
	assert_almost_eq(shaft.shutter_open(true), 0.0, 0.0001,
		"ein Endzustand duldet kein halb offenes Band")

func test_ohne_wandhaut_gibt_es_kein_band_zu_fahren() -> void:
	var shaft := LiftShaftView.new()
	add_child_autofree(shaft)
	shaft.setup(Vector3.ZERO, POOL_HALF, _tray_depth())
	assert_null(shaft.run_band(LiftShaftView.BAND_BACK, true))
	assert_almost_eq(shaft.shutter_open(true), 0.0, 0.0001,
		"was es nicht gibt, steht auch nicht offen")

# --- Der SITZ-PLAN: Buch-Ordnung, und er reicht HINTER den Pool -----------------

func _tray() -> DiceTrayView:
	var tray: DiceTrayView = load("res://scenes/dice_pool_tray.tscn").instantiate()
	add_child_autofree(tray)
	return tray

func test_die_ablage_sitze_haengen_hinter_dem_pool_block() -> void:
	var tray := _tray()
	var width := tray.columns
	var last_pool := tray.slot_offset(width * tray.rows - 1)
	var first_ablage := tray.slot_offset(width * tray.rows)
	assert_almost_eq(first_ablage.x, last_pool.x - DiceTrayView.SPACING.x, 0.0001,
		"die Ablage beginnt genau eine Reihen-Teilung hinter dem Pool")
	assert_almost_eq(first_ablage.z, tray.slot_offset(0).z, 0.0001,
		"und in derselben Spalte wie der erste Platz - das Raster läuft durch")

func test_der_sitz_plan_liest_wie_ein_buch() -> void:
	var tray := _tray()
	var width := tray.columns
	for row in 3:
		var head := tray.slot_offset(row * width)
		assert_almost_eq(head.x, tray.slot_offset(0).x - float(row) * DiceTrayView.SPACING.x,
			0.0001, "Reihe %d liegt eine Teilung weiter" % row)
		for col in width:
			var seat := tray.slot_offset(row * width + col)
			assert_almost_eq(seat.x, head.x, 0.0001, "eine Reihe steht auf EINER Höhe")

# --- Die Reihen-Vorrück-Bedingung ----------------------------------------------

func test_der_traeger_rueckt_erst_vor_wenn_die_reihe_GANZ_leer_ist() -> void:
	assert_eq(DiceTrayView.rows_before(0, 6), 0, "nichts gezogen, nichts gefahren")
	assert_eq(DiceTrayView.rows_before(5, 6), 0, "fünf von sechs reichen nicht")
	assert_eq(DiceTrayView.rows_before(6, 6), 1, "die erste Reihe ist leer")
	assert_eq(DiceTrayView.rows_before(11, 6), 1)
	assert_eq(DiceTrayView.rows_before(12, 6), 2)
	assert_eq(DiceTrayView.rows_before(30, 6), 5, "der ganze Vorrat ist durch")

func test_die_vorrueck_rechnung_haelt_auch_unsinn_aus() -> void:
	assert_eq(DiceTrayView.rows_before(-3, 6), 0)
	assert_eq(DiceTrayView.rows_before(7, 0), 7, "ohne Spalten wird jede Reihe eine")

# --- Die EINE Reststreuung: die Ablage-Reihe mischt Def UND Seite gemeinsam -----

func _row(count: int) -> Array:
	var items: Array = []
	for i in count:
		var def := DieDefinition.standard()
		def.style_id = "row%d" % i
		items.append({"def": def, "face": i})
	return items

func test_die_ablage_reihe_wird_gemischt_und_bleibt_vollzaehlig() -> void:
	var items := _row(6)
	var mixed := DiceTrayView.shuffle_row(items)
	assert_eq(mixed.size(), items.size())
	for item: Dictionary in items:
		assert_true(mixed.has(item), "kein Würfel geht verloren")

func test_der_wuerfel_nimmt_seine_gemerkte_seite_MIT() -> void:
	# Def und Seite reisen als EIN Eintrag - sie können nicht auseinanderlaufen.
	for pass_index in 20:
		var mixed := DiceTrayView.shuffle_row(_row(6))
		for entry: Dictionary in mixed:
			var def: DieDefinition = entry["def"]
			assert_eq(def.style_id, "row%d" % int(entry["face"]),
				"Seite und Würfel bleiben dasselbe Paar")

func test_eine_leere_reihe_mischt_sich_zu_nichts() -> void:
	assert_eq(DiceTrayView.shuffle_row([]), [])
