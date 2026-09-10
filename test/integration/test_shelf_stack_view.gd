extends GutTest
## Der REGALSTAPEL: FÜNF Tabletts zu je ZWEI Reihen liegen gestapelt in der
## Magazin-Grube. Tablett 1 zuoberst, jedes weitere eine Teilung tiefer - und KEINES
## wechselt je seine Höhe. Wählt der Spieler Tablett n, fahren die darüber seitlich
## in die Grubenwand, die darunter bleiben liegen (und sind darum unsichtbar).
## Die Karten sind Kinder des Faches ihres Tabletts und fahren mit. Keine Karte ragt
## je über die Tischkante.

## Die Grube in Welt: x quer (Bild-hoch, ZWEI Lanes), y längs (Bild-breit).
const SPAN := Vector2(4.8, 24.0)
const SCALE := PackDrawerView.CASSETTE_SCALE
## Die Invariante der Wurzel: nichts liegt höher als das im Tisch.
const RIM_LIMIT := -0.11
const ROWS := PackDrawerView.ROWS
const TRAYS := PackDrawerView.TRAYS

var stack: ShelfStackView

func before_each() -> void:
	stack = ShelfStackView.new()
	add_child_autofree(stack)
	stack.setup(Vector3.ZERO, SPAN, SCALE)

func _ride_time() -> float:
	return ShelfStackView.step_time() + 0.1

func _tray_node(tray: int) -> Node3D:
	return stack.get_node("Tablett%d" % (tray + 1)) as Node3D

# --- Die reine STAPEL-Rechnung -----------------------------------------------------

func test_zehn_reihen_liegen_auf_fuenf_tabletts() -> void:
	assert_eq(stack.row_count(), ROWS, "so viele wie das Magazin zählt")
	assert_eq(stack.tray_count(), 5, "fünf Tabletts zu je zwei Reihen")
	assert_eq(TRAYS * PackDrawerView.LANES, ROWS)
	for row in ROWS:
		assert_eq(ShelfStackView.tray_of(row), row / 2, "Reihe %d" % (row + 1))
		assert_eq(ShelfStackView.lane_of(row), row % 2)
	assert_eq(ShelfStackView.lane_of(0), ShelfStackView.LANE_BACK, "gerade = hinten")
	assert_eq(ShelfStackView.lane_of(1), ShelfStackView.LANE_FRONT)
	for tray in TRAYS:
		assert_eq(ShelfStackView.rows_of(tray),
			[tray * 2, tray * 2 + 1] as Array[int], "Tablett %d" % (tray + 1))

## Genau EIN Tablett liegt in der Fläche; darüber ist eingefahren, darunter vergraben.
func test_genau_ein_tablett_liegt_in_der_flaeche() -> void:
	for chosen in TRAYS:
		var shown: Array[int] = []
		for row in ROWS:
			if ShelfStackView.shows_row(row, chosen):
				shown.append(row)
		assert_eq(shown, ShelfStackView.rows_of(chosen) as Array[int],
			"Wahl %d zeigt genau seine zwei Reihen" % (chosen + 1))
		for row in ROWS:
			var tray := ShelfStackView.tray_of(row)
			var state := ShelfStackView.state_of(row, chosen)
			if tray < chosen:
				assert_eq(state, ShelfStackView.RETRACTED,
					"Tablett %d steht bei Wahl %d in der Wand" % [tray + 1, chosen + 1])
			elif tray > chosen:
				assert_eq(state, ShelfStackView.BURIED,
					"Tablett %d liegt bei Wahl %d darunter" % [tray + 1, chosen + 1])
			else:
				assert_eq(state, ShelfStackView.SHOWN)

## KEIN Tablett wechselt je seine Höhe - die Tiefe IST die Position im Stapel.
func test_kein_tablett_wechselt_je_seine_hoehe() -> void:
	for tray in TRAYS:
		var height := stack.tray_pose(tray, 0).y
		for chosen in TRAYS:
			assert_almost_eq(stack.tray_pose(tray, chosen).y, height, 0.0001,
				"Tablett %d bleibt bei Wahl %d auf seiner Höhe" % [tray + 1, chosen + 1])

## Ein eingefahrenes Tablett steht GANZ außerhalb des Lochs.
func test_ein_eingefahrenes_tablett_liegt_ausserhalb_der_grube() -> void:
	var out := stack.tray_pose(0, 2)
	assert_gt(out.z, SPAN.y, "seine nahe Kante steht hinter der Grubenwand")
	assert_almost_eq(out.z, SPAN.y + ShelfStackView.RETRACT_CLEAR, 0.0001)
	assert_almost_eq(stack.tray_pose(2, 2).z, 0.0, 0.0001, "das gewählte steht still")
	assert_almost_eq(stack.tray_pose(4, 2).z, 0.0, 0.0001, "und die darunter auch")

func test_die_tabletts_stapeln_sich_mit_fester_teilung() -> void:
	for tray in range(1, TRAYS):
		assert_almost_eq(ShelfStackView.drop_of(tray, SCALE)
			- ShelfStackView.drop_of(tray - 1, SCALE),
			ShelfStackView.PITCH, 0.0001, "Tablett %d liegt eine Teilung tiefer" % (tray + 1))
	assert_almost_eq(ShelfStackView.drop_of(0, SCALE),
		ShelfStackView.read_drop(SCALE), 0.0001, "Tablett 1 liegt auf Lese-Tiefe")

## Der ganze Stapel muß in die Grube passen - sonst stünde ein Tablett im Boden.
func test_der_stapel_bleibt_in_der_grube() -> void:
	var pit := DataCellView.STAND_HEIGHT * SCALE * 1.3  # _pack_pit_depth
	assert_lt(ShelfStackView.stack_depth(SCALE), pit,
		"tiefer als die Grube wäre ein Loch im Boden")

# --- Die zwei Lanes eines Tabletts -------------------------------------------------

func test_die_hintere_lane_liegt_weiter_hinten_als_die_vordere() -> void:
	assert_gt(stack.lane_x(ShelfStackView.LANE_BACK),
		stack.lane_x(ShelfStackView.LANE_FRONT), "hinten ist Welt +X (Bild-oben)")
	assert_almost_eq(stack.card_seat(0), stack.card_seat(1), 0.0001,
		"beide Reihen eines Tabletts liegen gleich hoch")

func test_ohne_meldung_ist_eine_lane_die_halbe_grube() -> void:
	assert_almost_eq(stack.lane_depth(), SPAN.x * 0.5, 0.0001, "der kopflose Rückfall")
	assert_almost_eq(stack.band_depth(),
		stack.lane_depth() * PackDrawerView.FRONT_SHARE, 0.0001,
		"und die Blende nimmt den Anteil, den auch das Magazin für sie freihält")

## GEMELDET liegen die Lanes auf den genannten Mitten mit der genannten Tiefe - der
## SPALT dazwischen steckt in dieser Meldung, und die Platte deckt beide samt Spalt.
func test_die_platte_deckt_beide_gemeldeten_lanes() -> void:
	var lanes: Array[Vector2] = [Vector2(1.6, 1.8), Vector2(-0.4, 1.8)]
	stack.setup(Vector3.ZERO, SPAN, SCALE, lanes)
	assert_almost_eq(stack.lane_depth(), 1.8, 0.0001, "die gemeldete Tiefe")
	assert_almost_eq(stack.lane_x(ShelfStackView.LANE_BACK), 1.6, 0.0001)
	assert_almost_eq(stack.lane_x(ShelfStackView.LANE_FRONT), -0.4, 0.0001)
	assert_almost_eq(stack.plate_span(), 1.6 - (-0.4) + 1.8, 0.0001,
		"von der Oberkante der hinteren bis zur Unterkante der vorderen")
	assert_almost_eq(stack.plate_center(), 0.6, 0.0001)
	var plate := stack.get_node("Tablett1/Platte") as MeshInstance3D
	assert_almost_eq((plate.mesh as BoxMesh).size.x, stack.plate_span(), 0.0001)
	assert_almost_eq(plate.position.x, stack.plate_center(), 0.0001)

## Und die GLEICHEN Ränder der Meldung kommen aus dem Fenster: dieselbe eine Rechnung.
func test_die_drei_gleichen_raender_stecken_in_den_lane_rechtecken() -> void:
	var field := Vector2(900.0, 260.0)
	var rects := PackDrawerView.lane_rects(field)
	assert_eq(rects.size(), PackDrawerView.LANES)
	assert_almost_eq(rects[0].position.y, PackDrawerView.LANE_GAP_PX, 0.001,
		"der Rand über der hinteren Reihe")
	assert_almost_eq(rects[1].position.y - rects[0].end.y,
		PackDrawerView.LANE_GAP_PX, 0.001, "derselbe Rand zwischen den Lanes")
	assert_almost_eq(field.y - rects[1].end.y, PackDrawerView.LANE_GAP_PX, 0.001,
		"und derselbe unter der vorderen Reihe")
	assert_almost_eq(rects[0].size.y, rects[1].size.y, 0.001, "beide gleich tief")

# --- Die Invariante: nichts über der Tischkante ------------------------------------

func test_keine_karte_ragt_ueber_die_tischkante() -> void:
	for chosen in TRAYS:
		stack.set_selected(chosen)
		for row in ROWS:
			assert_lte(stack.card_top(row), RIM_LIMIT,
				"Wahl %d, Reihe %d bleibt unter der Kante" % [chosen + 1, row + 1])

## ... und tiefer wird es monoton: Tablett 1 liegt am höchsten.
func test_die_tabletts_liegen_monoton_tiefer() -> void:
	assert_lte(stack.card_top(0), RIM_LIMIT, "Tablett 1 knapp unter der Kante")
	assert_gt(stack.card_top(0), RIM_LIMIT - DataCellView.lying_over(SCALE),
		"nicht irgendwo tief unten")
	for tray in range(1, TRAYS):
		assert_lt(stack.card_top(tray * 2), stack.card_top((tray - 1) * 2),
			"Tablett %d liegt tiefer als das darüber" % (tray + 1))

func test_die_karte_liegt_auf_der_trittflaeche() -> void:
	assert_almost_eq(stack.card_seat(0), stack.tray_top(0) + ShelfStackView.PROUD,
		0.0001, "eine Spur über der Platte, nicht koplanar")
	assert_almost_eq(stack.card_top(0) - stack.card_seat(0),
		DataCellView.lying_over(SCALE), 0.0001, "und ihre Dicke steht darüber")

## Der GRIFF zieht sie über die Kante - aus JEDEM Tablett gleich weit: die Tiefe ist
## Stapel-Position, kein Lese-Hindernis.
func test_der_griff_zieht_jede_karte_ueber_die_kante() -> void:
	for tray in TRAYS:
		var lift := ShelfStackView.hover_lift(SCALE, tray) \
			* DataCellView.STAND_HEIGHT * SCALE
		assert_gt(stack.card_top(tray * 2) + lift, 0.0,
			"gegriffen steht auch Tablett %d über dem Glas" % (tray + 1))

# --- Die WAHL: ein Schub, keine Drehung --------------------------------------------

func test_eine_wahl_faehrt_die_tabletts_darueber_in_die_wand() -> void:
	assert_eq(stack.selected(), 0)
	assert_eq(stack.rows_shown(), [0, 1] as Array[int])
	stack.select(2)
	assert_eq(stack.selected(), 2, "die Wahl gilt sofort")
	assert_eq(stack.rows_shown(), [4, 5] as Array[int])
	assert_true(stack.riding(), "und die Fahrt läuft")
	await wait_seconds(_ride_time())
	assert_false(stack.riding())
	for tray in TRAYS:
		assert_almost_eq(_tray_node(tray).position.z, stack.tray_pose(tray, 2).z,
			0.0001, "Tablett %d steht auf seinem Sitz" % (tray + 1))
	assert_gt(_tray_node(0).position.z, SPAN.y, "Tablett 1 steckt in der Wand")
	assert_almost_eq(_tray_node(4).position.z, 0.0, 0.0001, "Tablett 5 blieb liegen")

func test_dieselbe_wahl_tut_nichts() -> void:
	stack.select(0)
	assert_false(stack.riding(), "dieselbe Wahl fährt nicht")
	assert_eq(stack.selected(), 0)

func test_die_wahl_ist_umkehrbar() -> void:
	stack.select(3)
	await wait_seconds(_ride_time())
	stack.select(0)
	await wait_seconds(_ride_time())
	for tray in TRAYS:
		assert_almost_eq(_tray_node(tray).position.z, 0.0, 0.0001,
			"Tablett %d steht wieder in der Grube" % (tray + 1))

## Endzustand zuerst: ein harter Abbruch mitten in der Fahrt schuldet nichts.
func test_ein_abbruch_setzt_jedes_tablett_hart() -> void:
	stack.select(3)
	await wait_frames(2)
	stack.settle_hard()
	assert_false(stack.riding())
	for tray in TRAYS:
		assert_almost_eq(_tray_node(tray).position.y,
			-ShelfStackView.drop_of(tray, SCALE), 0.0001,
			"Tablett %d steht auf seiner Ruhehöhe" % (tray + 1))
		assert_almost_eq(_tray_node(tray).position.z, stack.tray_pose(tray, 3).z,
			0.0001, "... und auf seinem Schub-Platz")

## Eine Wahl mitten in der Fahrt wird angenommen - die alte endet hart.
func test_eine_wahl_waehrend_der_fahrt_wird_angenommen() -> void:
	stack.select(4)
	await wait_frames(2)
	stack.select(1)
	assert_eq(stack.selected(), 1)
	await wait_seconds(_ride_time())
	assert_false(stack.riding())
	assert_eq(stack.rows_shown(), [2, 3] as Array[int])
	assert_gt(_tray_node(0).position.z, SPAN.y, "nur Tablett 1 steht in der Wand")
	assert_almost_eq(_tray_node(2).position.z, 0.0, 0.0001)

## Der harte Sprung (Laufwechsel, Neuaufbau) fährt nicht.
func test_der_harte_sprung_faehrt_nicht() -> void:
	stack.set_selected(3)
	assert_false(stack.riding())
	assert_eq(stack.selected(), 3)
	assert_gt(_tray_node(1).position.z, SPAN.y)

# --- Die Karten sind Kinder ihres Faches -------------------------------------------

func test_beide_reihen_eines_tabletts_teilen_sein_fach() -> void:
	assert_eq(stack.fach(0), stack.fach(1), "hinten und vorn fahren gemeinsam")
	assert_ne(stack.fach(0), stack.fach(2), "das nächste Tablett hat sein eigenes")

func test_eine_karte_faehrt_mit_ihrem_tablett_in_die_wand_und_zurueck() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	cell.global_position = Vector3(0.0, stack.card_seat(0), 3.0)
	stack.host_card(cell, 0)
	assert_eq(cell.get_parent().name, "Fach")
	assert_almost_eq(cell.position.y, ShelfStackView.PROUD, 0.0001,
		"lokal liegt sie IMMER auf der Trittfläche")
	var home := cell.global_position
	stack.select(2)
	await wait_seconds(_ride_time())
	assert_gt(cell.global_position.z, SPAN.y * 0.5,
		"sie steckt mit ihrem Tablett außerhalb der Grube")
	assert_almost_eq(cell.global_position.y, home.y, 0.0001, "dieselbe Höhe wie je")
	stack.select(0)
	await wait_seconds(_ride_time())
	assert_almost_eq(cell.global_position.z, home.z, 0.0001, "und wieder auf ihrem Platz")
	assert_almost_eq(cell.global_position.y, home.y, 0.0001)

func test_sie_meldet_ob_eine_karte_schon_liegt() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	var at := Vector3(0.0, stack.card_seat(0), 2.0)
	assert_false(stack.seated(cell, 0, at), "noch gehört sie nicht dazu")
	cell.global_position = at
	stack.host_card(cell, 0)
	assert_true(stack.seated(cell, 0, at))
	assert_false(stack.seated(cell, 2, at), "und nur auf IHREM Tablett")
	assert_false(stack.seated(cell, 0, at + Vector3(0.0, 0.0, 1.0)),
		"ein anderer Platz ist ein anderer Platz")

func test_der_umzug_behaelt_den_weltplatz() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	cell.global_position = Vector3(1.0, -2.0, 3.0)
	stack.host_card(cell, 4)
	var host := Node3D.new()
	add_child_autofree(host)
	var at := cell.global_position
	ShelfStackView.rehost(cell, host)
	assert_eq(cell.get_parent(), host)
	assert_almost_eq(cell.global_position.x, at.x, 0.0001)
	assert_almost_eq(cell.global_position.z, at.z, 0.0001)

# --- Die FRONT-BLENDE ---------------------------------------------------------------

## Die NUMMER steht nur an der VORDEREN Blende und nennt die TABLETT-Nummer - dieselbe
## Zahl wie auf der Taste der Knopfleiste.
func test_die_nummer_steht_nur_am_vorderen_band_und_nennt_das_tablett() -> void:
	for tray in TRAYS:
		var rows := ShelfStackView.rows_of(tray)
		assert_null(stack.get_node_or_null("Tablett%d/Blende%d/Nummer"
			% [tray + 1, rows[0] + 1]), "die hintere Blende trägt keine")
		var label := stack.get_node("Tablett%d/Blende%d/Nummer"
			% [tray + 1, rows[1] + 1]) as Label3D
		assert_eq(label.text, "%d" % (tray + 1),
			"Tablett %d nennt sich selbst: '%s'" % [tray + 1, label.text])
		assert_eq(label.text, stack.number_text(rows[0]), "beide Reihen dieselbe Zahl")

## Nur das GEWÄHLTE Tablett zeigt seine Blenden - sonst stanzte ein Text durch die
## Platte darüber.
func test_nur_das_gewaehlte_tablett_zeigt_seine_blenden() -> void:
	for row in ROWS:
		stack.set_bay_tints(row, [ShelfStackView.BAY_EMPTY])
	stack.set_selected(2)
	for row in ROWS:
		var band := stack.get_node("Tablett%d/Blende%d"
			% [ShelfStackView.tray_of(row) + 1, row + 1]) as Node3D
		assert_eq(band.visible, ShelfStackView.tray_of(row) == 2,
			"Reihe %d" % (row + 1))
		var bays := stack.get_node("Tablett%d/Mulden%d"
			% [ShelfStackView.tray_of(row) + 1, row + 1]) as Node3D
		assert_eq(bays.visible, ShelfStackView.tray_of(row) == 2, "und ihre Mulden ebenso")

func test_je_platz_eine_mulde_mit_saum_in_der_sortenfarbe() -> void:
	var tints: Array[Color] = [PackDrawerView.COLORS[Engraving.CATEGORY_NUMBER],
		PackDrawerView.COLORS[Engraving.CATEGORY_MATERIAL],
		ShelfStackView.BAY_EMPTY]
	stack.set_bay_tints(3, tints)
	assert_eq(stack.bay_count(3), 3)
	assert_eq(stack.bay_tint(3, 0), tints[0])
	assert_eq(stack.bay_tint(3, 2), ShelfStackView.BAY_EMPTY, "leer ist stumpf")
	var bays := stack.get_node("Tablett2/Mulden4")
	var count := 0
	for child in bays.get_children():
		if String(child.name).begins_with("Mulde"):
			count += 1
			for part in ["Saum", "Boden", "Zunge"]:
				assert_not_null(child.get_node_or_null(part), "%s trägt %s" % [child.name, part])
	assert_eq(count, 3, "je Platz eine Mulde auf dem Tablett IHRER Reihe")
	var lit := (bays.get_node("Mulde0/Saum") as MeshInstance3D).material_override \
		as StandardMaterial3D
	var dull := (bays.get_node("Mulde2/Saum") as MeshInstance3D).material_override \
		as StandardMaterial3D
	assert_eq(lit.emission, tints[0], "der Saum trägt die Sorte")
	assert_gt(lit.emission_energy_multiplier, dull.emission_energy_multiplier,
		"belegt leuchtet heller als leer")

## Die Karte liegt AUF Boden und Zunge der Mulde, nie in ihnen: alles unter ihr bleibt
## unter BAY_FLOOR, und die Lippe bleibt unter der Kartendicke.
func test_die_mulde_bleibt_unter_der_karte() -> void:
	stack.set_bay_tints(0, [ShelfStackView.BAY_EMPTY, ShelfStackView.BAY_EMPTY])
	assert_lt(ShelfStackView.FLOOR_RISE + ShelfStackView.TONGUE_RISE, ShelfStackView.BAY_FLOOR)
	assert_gt(ShelfStackView.PROUD, ShelfStackView.BAY_LIP, "die Karte liegt über der Lippe")
	var bay := stack.bay_size(2)
	assert_gt(bay.x, 0.0, "quer bleibt eine Mulde")
	assert_gt(bay.y, DataCellView.HEIGHT * SCALE, "längs weiter als die Karte")
	assert_lt(bay.y, stack._span.y * 0.5, "und zwei passen mit Lippe nebeneinander")

## Ändert sich nur die Farbe, wird nichts neu gebaut; ändert sich die Platzzahl, schon.
func test_umfaerben_baut_nichts_neu_umzaehlen_schon() -> void:
	stack.set_bay_tints(1, [ShelfStackView.BAY_EMPTY, ShelfStackView.BAY_EMPTY])
	var before := stack.get_node("Tablett1/Mulden2")
	stack.set_bay_tints(1, [PackDrawerView.GOLD, ShelfStackView.BAY_EMPTY])
	assert_eq(stack.get_node("Tablett1/Mulden2"), before, "derselbe Knoten")
	stack.set_bay_tints(1, [PackDrawerView.GOLD, ShelfStackView.BAY_EMPTY, PackDrawerView.GOLD])
	assert_eq(stack.bay_count(1), 3)
	assert_ne(stack.get_node("Tablett1/Mulden2"), before, "drei Plätze sind ein neuer Bau")

func test_die_blenden_liegen_an_der_bild_unteren_kante_ihrer_lane() -> void:
	var back := stack.get_node("Tablett1/Blende1") as Node3D
	var front := stack.get_node("Tablett1/Blende2") as Node3D
	# Bild-UNTEN ist Welt -X: die Blende sitzt an der Unterkante IHRER Lane.
	assert_almost_eq(back.position.x,
		stack.lane_x(ShelfStackView.LANE_BACK) - stack.lane_depth() * 0.5
			+ stack.band_depth() * 0.5, 0.0001)
	assert_lt(front.position.x, back.position.x, "die vordere liegt weiter unten")

## Die Tabletts sind UNDURCHSICHTIG und tragen keinen Rand (Spieler-Entscheid
## 2026-09-09): EIN massives Material für jedes.
func test_die_tabletts_sind_undurchsichtig_und_ohne_rand() -> void:
	var top := (stack.get_node("Tablett1/Platte") as MeshInstance3D) \
		.material_override as StandardMaterial3D
	var deep := (stack.get_node("Tablett5/Platte") as MeshInstance3D) \
		.material_override as StandardMaterial3D
	assert_not_null(top, "die Platte ist schlichtes Material")
	assert_eq(top.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "undurchsichtig")
	assert_almost_eq(top.albedo_color.a, 1.0, 0.0001, "keine Alpha")
	assert_eq(deep, top, "oben und unten teilen das eine Material")
	for tray in TRAYS:
		assert_null(stack.get_node_or_null("Tablett%d/Rand" % (tray + 1)),
			"kein Rand an Tablett %d" % (tray + 1))

## Die WANDTASCHE hinter dem Schlitz: sie liegt AUSSERHALB der Grube (Welt +Z) und
## deckt die Tiefe des Stapels - durch den Schlitz sieht man in sie, nicht in den Raum.
func test_die_wandtasche_liegt_hinter_der_grubenwand() -> void:
	var back := stack.get_node("Wandtasche/Rueckwand") as MeshInstance3D
	assert_gt(back.position.z, SPAN.y * 0.5 + stack.retract_span() * 0.5,
		"ihre Rückwand steht hinter dem eingefahrenen Tablett")
	var floor_plate := stack.get_node("Wandtasche/Boden") as MeshInstance3D
	assert_lt(floor_plate.position.y, -ShelfStackView.stack_depth(SCALE),
		"ihr Boden liegt unter dem untersten Tablett")
	assert_not_null(stack.get_node_or_null("Wandtasche/Decke"))
	assert_null(stack.get_node_or_null("Wandtasche/Vorderwand"),
		"zur Grube hin ist sie offen")

# --- Möbel, keine Fahrt --------------------------------------------------------------

func test_dieselben_masse_bauen_nichts_neu() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	stack.host_card(cell, 0)
	stack.setup(Vector3.ZERO, SPAN, SCALE)
	assert_eq(cell.get_parent().name, "Fach", "und die Karten überleben einen Neuaufbau")
	stack.setup(Vector3.ZERO, SPAN * 1.2, SCALE)
	assert_eq(cell.get_parent().name, "Fach",
		"auch einen mit neuen Maßen - das Fach gehört nicht der Platte")
