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

# --- Die GLAS-ANSICHT: der Schirm trägt die ANZEIGE ----------------------------
# Für die Glas-Ansicht bestellt der Vorrats-Schacht ZWEITENS eine Anzeige-Haut. Sie
# kommt seit 2026-08-31 FERTIG von draußen (TableScreen.deck_glass_skin, aus dem
# eigenen Viewport des Rasters) - der Schacht legt sie nur auf, er tönt nichts mehr.
# Danach steht die RUNDEN-Konfiguration wieder unverändert da - flach, ohne Schirm.

func _skinned_shaft() -> LiftShaftView:
	var shaft := _shaft(true)
	shaft.deck_skin = StandardMaterial3D.new()  # die Plattform-Haut, hier eine Attrappe
	shaft.order_cover_skin(StandardMaterial3D.new())  # und die des Schirms
	return shaft

func test_die_anzeige_liegt_nur_auf_dem_GESCHLOSSENEN_glas() -> void:
	var shaft := _skinned_shaft()
	assert_true(shaft.has_cover_skin(), "die Haut ist bestellt")
	assert_false(shaft.cover_skin_shown(), "eingefahren zeigt der Schirm nichts")
	shaft.park_hard()
	assert_almost_eq(shaft.cover_share(), 1.0, 0.0001, "geparkt liegt das Glas zu")
	assert_true(shaft.cover_skin_shown(), "und trägt die Anzeige")
	shaft.settle_hard()
	assert_false(shaft.cover_skin_shown(), "bündig ist sie wieder fort")

func test_plattform_und_schirm_tragen_ZWEI_gemeldete_haeute() -> void:
	# Die Plattform zeigt die Anzeige, der Schirm sein eigenes Raster - zwei
	# Meldungen, und der Schacht reicht beide UNVERÄNDERT durch.
	var platform := ShaderMaterial.new()
	platform.shader = load("res://assets/shaders/display_skin.gdshader")
	var glass := ShaderMaterial.new()
	glass.shader = load("res://assets/shaders/display_skin_sheer.gdshader")
	glass.set_shader_parameter("display_map", Vector4(1.0, 2.0, 3.0, 4.0))
	var shaft := _shaft(true)
	shaft.deck_skin = platform
	shaft.order_cover_skin(glass)
	shaft.park_hard()
	assert_eq(shaft._deck_top.material_override, platform,
		"die Plattform trägt die gemeldete Haut unverändert")
	assert_eq(shaft._cover_skin.material_override, glass,
		"und der Schirm die SEINE - hier wird nichts zweitgetönt")
	assert_eq(glass.get_shader_parameter("display_map"), Vector4(1.0, 2.0, 3.0, 4.0),
		"die Abbildung ist die GEMELDETE")

func test_ohne_gemeldete_haut_bleibt_das_glas_nackt() -> void:
	var shaft := _shaft(true)  # keine Haut gemeldet (Probe, Test ohne Tisch)
	shaft.order_cover_skin(null)
	shaft.park_hard()
	assert_false(shaft.has_cover_skin(), "nichts bestellt")
	assert_false(shaft.cover_skin_shown(), "ohne Bild gibt es nichts zu zeigen")

func test_der_park_faehrt_die_haut_mit_dem_glas_aus() -> void:
	var shaft := _skinned_shaft()
	var rider := Node3D.new()
	add_child_autofree(rider)
	var tween := shaft.run_park([], [], [], [], 0.0, Callable(), [rider], [Vector3.ZERO])
	assert_not_null(tween)
	await wait_seconds(LiftShaftView.SINK_TIME + LiftShaftView.PUSH_TIME * 0.5)
	assert_false(shaft.cover_skin_shown(), "unterwegs schmiert nichts")
	await wait_seconds(shaft.park_cycle_time())
	assert_true(shaft.cover_skin_shown(), "am Ende steht die Anzeige auf dem Glas")

func test_die_runden_konfiguration_kehrt_unveraendert_zurueck() -> void:
	# Der EINE Schreiber baut aus derselben Maschine zwei Konfigurationen. Nach der
	# Glas-Ansicht MUSS die flache, schirmlose der Runde wieder byte-gleich stehen.
	var flat := DiceTrayView.FLOAT_HEIGHT
	var reference := LiftShaftView.new("Flach")
	add_child_autofree(reference)
	reference.order_skin(PlaceholderTexture2D.new())
	reference.setup(Vector3.ZERO, POOL_HALF, flat)

	var shaft := _skinned_shaft()
	shaft.park_hard()
	shaft.settle_hard()
	shaft.drop_cover()  # nimmt die Anzeige-Haut mit
	shaft.setup(Vector3.ZERO, POOL_HALF, flat)

	assert_false(shaft.has_cover(), "kein Schirm mehr")
	assert_false(shaft.has_cover_skin(), "und keine Anzeige darauf")
	assert_eq(shaft.has_cover(), reference.has_cover())
	assert_almost_eq(shaft.depth, reference.depth, 0.0001, "flach wie zuvor")
	assert_almost_eq(shaft.park_y(), reference.park_y(), 0.0001)
	assert_almost_eq(shaft.mouth_height(), reference.mouth_height(), 0.0001)
	assert_almost_eq(shaft.cover_share(), 0.0, 0.0001, "und nichts liegt darüber")
	assert_false(shaft.visible, "die Maschine steht wieder fort")
