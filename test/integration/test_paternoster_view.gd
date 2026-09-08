extends GutTest
## Der PATERNOSTER als KREISLAUF: ZEHN Reihen, von denen ZWEI zugleich in der Fläche
## liegen (hinten = Bild-oben, vorn = Bild-unten). Ein Schritt versenkt vorn, gleitet
## hinten nach vorn und hebt die nächste hinten heraus; zehn Schritte sind ein voller
## Umlauf. Die Karten sind Kinder ihres Faches und fahren mit. Keine Karte ragt je
## über die Tischkante.

## Die Grube in Welt: x quer (Bild-hoch, jetzt ZWEI Lanes), y längs (Bild-breit).
const SPAN := Vector2(4.8, 24.0)
const SCALE := PackDrawerView.CASSETTE_SCALE
## Die Invariante der Wurzel: nichts liegt höher als das im Tisch.
const RIM_LIMIT := -0.11
const ROWS := PackDrawerView.ROWS

var pater: PaternosterView

func before_each() -> void:
	pater = PaternosterView.new()
	add_child_autofree(pater)
	pater.setup(Vector3.ZERO, SPAN, SCALE)

func _ride_time() -> float:
	return PaternosterView.step_time() + 0.1

func _lane(row: int, head: int) -> int:
	return int(PaternosterView.seat_of(row, head)["lane"])

func _depth(row: int, head: int) -> int:
	return int(PaternosterView.seat_of(row, head)["depth"])

# --- Die reine SITZ-Rechnung -------------------------------------------------------

func test_zwei_reihen_liegen_und_der_rest_parkt() -> void:
	assert_eq(pater.row_count(), ROWS, "so viele wie das Magazin zählt")
	assert_eq(ROWS, 10, "zehn Reihen sind ein Umlauf")
	for head in [0, 7]:
		var lying: Array[int] = []
		for row in ROWS:
			if _depth(row, head) == 0:
				lying.append(row)
		assert_eq(lying, [head, posmod(head + 1, ROWS)] as Array[int],
			"head %d: hinten head, vorn die nächste" % head)
		assert_eq(_lane(head, head), PaternosterView.LANE_BACK)
		assert_eq(_lane(posmod(head + 1, ROWS), head), PaternosterView.LANE_FRONT)

func test_kein_zwei_reihen_teilen_sich_einen_sitz() -> void:
	for head in [0, 3, 7, 9]:
		var seen: Dictionary = {}
		for row in ROWS:
			var key := "%d/%d" % [_lane(row, head), _depth(row, head)]
			assert_false(seen.has(key),
				"head %d: Reihe %d säße auf %s" % [head, row + 1, key])
			seen[key] = true
		assert_eq(seen.size(), ROWS)

## Je Lane eine sichtbare plus vier geparkte, monoton nach Abstand gestapelt.
func test_die_parkplaetze_stapeln_sich_monoton_je_lane() -> void:
	for head in [0, 7]:
		for lane in [PaternosterView.LANE_BACK, PaternosterView.LANE_FRONT]:
			var depths: Array[int] = []
			for row in ROWS:
				if _lane(row, head) == lane:
					depths.append(_depth(row, head))
			depths.sort()
			assert_eq(depths, [0, 1, 2, 3, 4] as Array[int],
				"head %d, Lane %d" % [head, lane])
		# ... und tiefer wird es wirklich, nicht nur zählbar.
		for depth in range(1, PaternosterView.MAX_DEPTH + 1):
			assert_gt(PaternosterView.drop_of(depth, SCALE),
				PaternosterView.drop_of(depth - 1, SCALE))

## Die gegenüberliegende Reihe liegt zuunterst - deterministisch, nicht zufällig.
func test_die_gegenueberliegende_reihe_liegt_zuunterst() -> void:
	assert_eq(_depth(5, 0), PaternosterView.MAX_DEPTH, "head+5 ist die tiefste")
	assert_eq(_depth(6, 0), PaternosterView.MAX_DEPTH, "und head+6 ihr Gegenüber")

func test_die_geparkten_stapeln_sich_mit_fester_teilung() -> void:
	for depth in range(2, PaternosterView.MAX_DEPTH + 1):
		assert_almost_eq(PaternosterView.drop_of(depth, SCALE)
			- PaternosterView.drop_of(depth - 1, SCALE),
			PaternosterView.PITCH, 0.0001, "Stufe %d liegt eine Teilung tiefer" % depth)

## Der ganze Stapel muß in die Grube passen - sonst stünde ein Tablett im Boden.
func test_der_stapel_bleibt_in_der_grube() -> void:
	var pit := DataCellView.STAND_HEIGHT * SCALE * 1.3  # _pack_pit_depth
	assert_lt(PaternosterView.stack_depth(SCALE), pit,
		"tiefer als die Grube wäre ein Loch im Boden")

# --- Die zwei Lanes in der Fläche --------------------------------------------------

func test_die_hintere_lane_liegt_weiter_hinten_als_die_vordere() -> void:
	var back := pater.get_node("Tablett1") as Node3D  # Reihe 1 = head = hinten
	var front := pater.get_node("Tablett2") as Node3D
	assert_gt(back.global_position.x, front.global_position.x,
		"hinten ist Welt +X (Bild-oben)")
	assert_almost_eq(back.global_position.y, front.global_position.y, 0.0001,
		"beide liegen auf Lese-Tiefe")
	assert_almost_eq(back.global_position.x - front.global_position.x,
		pater.lane_depth(), 0.0001, "eine Lane Abstand")

func test_ohne_meldung_ist_eine_lane_die_halbe_grube() -> void:
	assert_almost_eq(pater.lane_depth(), SPAN.x * 0.5, 0.0001,
		"der kopflose Rückfall")
	assert_almost_eq(pater.band_depth(),
		pater.lane_depth() * PackDrawerView.FRONT_SHARE, 0.0001,
		"und die Blende nimmt den Anteil, den auch das Magazin für sie freihält")

## GEMELDET liegen die Lanes auf den genannten Mitten mit der genannten Tiefe - der
## SPALT dazwischen und die FUSSLUFT darunter stecken in dieser Meldung.
func test_die_lanes_liegen_auf_den_gemeldeten_mitten() -> void:
	var lanes: Array[Vector2] = [Vector2(1.6, 1.8), Vector2(-0.4, 1.8)]
	pater.setup(Vector3.ZERO, SPAN, SCALE, lanes)
	assert_almost_eq(pater.lane_depth(), 1.8, 0.0001, "die gemeldete Tiefe")
	assert_almost_eq(pater.lane_x(PaternosterView.LANE_BACK), 1.6, 0.0001)
	assert_almost_eq(pater.lane_x(PaternosterView.LANE_FRONT), -0.4, 0.0001)
	var back := pater.get_node("Tablett1") as Node3D
	var front := pater.get_node("Tablett2") as Node3D
	assert_almost_eq(back.position.x, 1.6, 0.0001)
	assert_almost_eq(front.position.x, -0.4, 0.0001)
	# Zwischen den beiden liegenden Tabletts bleibt ein echter SPALT.
	assert_gt(back.position.x - front.position.x, 1.8,
		"ihre Kanten berühren sich nicht - dazwischen sieht man in die Grube")

## Und die GLEICHEN Ränder der Meldung kommen aus dem Fenster: dieselbe eine Rechnung.
func test_der_spalt_und_die_fussluft_stecken_in_den_lane_rechtecken() -> void:
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
	assert_almost_eq(rects[0].size.y * 2.0 + PackDrawerView.LANE_GAP_PX * 3.0,
		field.y, 0.001, "zwei Lanes und drei Ränder sind die Feldtiefe")

# --- Die Invariante: nichts über der Tischkante ------------------------------------

func test_keine_karte_ragt_ueber_die_tischkante() -> void:
	for head in [0, 4]:
		pater.set_head(head)
		for row in ROWS:
			assert_lte(pater.card_top(row), RIM_LIMIT,
				"head %d, Reihe %d bleibt unter der Kante" % [head, row + 1])
	pater.set_head(0)
	# Und die liegenden liegen so hoch, wie es eben noch geht - beide Lanes.
	for row in pater.rows_shown():
		assert_gt(pater.card_top(row), RIM_LIMIT - DataCellView.lying_over(SCALE),
			"Reihe %d liegt knapp darunter, nicht irgendwo tief unten" % (row + 1))

func test_die_karte_liegt_auf_der_trittflaeche() -> void:
	assert_almost_eq(pater.card_seat(0), pater.tray_top(0) + PaternosterView.PROUD,
		0.0001, "eine Spur über der Platte, nicht koplanar")
	assert_almost_eq(pater.card_top(0) - pater.card_seat(0),
		DataCellView.lying_over(SCALE), 0.0001, "und ihre Dicke steht darüber")

## Der GRIFF zieht sie über die Kante - der Hover ist die eine erlaubte Ausnahme.
func test_der_griff_zieht_die_karte_ueber_die_kante() -> void:
	var lift := PaternosterView.hover_lift(SCALE) * DataCellView.STAND_HEIGHT * SCALE
	for row in pater.rows_shown():
		assert_gt(pater.card_top(row) + lift, 0.0, "gegriffen steht sie über dem Glas")

# --- Der KREISLAUF: ein Schritt bewegt ihn um eine Reihe ---------------------------

func test_ein_schritt_versenkt_vorn_und_hebt_hinten() -> void:
	assert_eq(pater.rows_shown(), [0, 1] as Array[int])
	pater.step(1)
	assert_eq(pater.head(), ROWS - 1, "die Wahl gilt sofort")
	assert_eq(pater.rows_shown(), [ROWS - 1, 0] as Array[int],
		"was hinten lag, liegt jetzt vorn - und hinten taucht die nächste auf")
	assert_true(pater.riding(), "und die Fahrt läuft")
	await wait_seconds(_ride_time())
	assert_false(pater.riding())
	assert_eq(_depth(1, pater.head()), 1, "die versunkene liegt eine Stufe tief")
	assert_eq(_lane(1, pater.head()), PaternosterView.LANE_FRONT, "und zwar vorn")

func test_vorwaerts_und_rueckwaerts_sind_zueinander_invers() -> void:
	for start in [0, 3, 9]:
		pater.set_head(start)
		pater.step(1)
		pater.step(-1)
		assert_eq(pater.head(), start, "hin und zurück ist dieselbe Lage")

func test_zehn_schritte_sind_ein_voller_umlauf() -> void:
	var seen: Dictionary = {}
	for i in ROWS:
		seen[pater.head()] = true
		pater.step(1)
	assert_eq(seen.size(), ROWS, "jede Reihe liegt einmal hinten")
	assert_eq(pater.head(), 0, "und danach steht wieder die erste da")

## Der Ring bewegt jede Reihe um GENAU EINEN Sitz - nichts springt.
func test_jede_reihe_rueckt_genau_einen_sitz_weiter() -> void:
	for delta in [1, -1]:
		for row in ROWS:
			var before := PaternosterView.seat_of(row, 0)
			var after := PaternosterView.seat_of(row, posmod(-delta, ROWS))
			var moved := int(before["lane"]) != int(after["lane"]) \
				or absi(int(before["depth"]) - int(after["depth"])) == 1
			assert_true(moved, "delta %d, Reihe %d fährt einen Sitz" % [delta, row + 1])

## Endzustand zuerst: ein harter Abbruch mitten in der Fahrt schuldet nichts.
func test_ein_abbruch_setzt_jedes_tablett_hart() -> void:
	pater.step(1)
	await wait_frames(2)
	pater.settle_hard()
	assert_false(pater.riding())
	for row in ROWS:
		var tray := pater.get_node("Tablett%d" % (row + 1)) as Node3D
		var seat := PaternosterView.seat_of(row, pater.head())
		assert_almost_eq(tray.position.y,
			-PaternosterView.drop_of(int(seat["depth"]), SCALE), 0.0001,
			"Reihe %d steht auf ihrer Ruhehöhe" % (row + 1))
		assert_almost_eq(tray.position.x, pater.lane_x(int(seat["lane"])), 0.0001,
			"Reihe %d steht in ihrer Lane" % (row + 1))

## Ein Wurf mitten in der Fahrt wird angenommen - die alte endet hart.
func test_ein_wurf_waehrend_der_fahrt_wird_angenommen() -> void:
	pater.step(1)
	await wait_frames(2)
	pater.step(1)
	assert_eq(pater.head(), ROWS - 2)
	await wait_seconds(_ride_time())
	assert_false(pater.riding())
	assert_eq(pater.rows_shown(), [ROWS - 2, ROWS - 1] as Array[int])

## ALLE zehn Reihen werden gerendert - vor, während und nach einem Schritt. Durch
## Spalt und Fußluft sieht man die geparkten Tabletts in der Grube liegen.
func test_alle_zehn_faecher_sind_sichtbar() -> void:
	for row in ROWS:
		var fach := pater.get_node("Tablett%d/Fach" % (row + 1)) as Node3D
		assert_true(fach.visible, "Reihe %d steht vorher im Bild" % (row + 1))
	pater.step(-1)
	await wait_frames(2)
	for row in ROWS:
		var fach := pater.get_node("Tablett%d/Fach" % (row + 1)) as Node3D
		assert_true(fach.visible, "Reihe %d auch mitten in der Fahrt" % (row + 1))
	await wait_seconds(_ride_time())
	for row in ROWS:
		var fach := pater.get_node("Tablett%d/Fach" % (row + 1)) as Node3D
		assert_true(fach.visible, "Reihe %d auch danach" % (row + 1))
	# shows() bleibt die LOGIK-Antwort - sie schaltet nur nichts mehr.
	assert_true(pater.shows(1))
	assert_false(pater.shows(4))

## Ein GEPARKTES Tablett trägt DENSELBEN Glaston wie ein liegendes (Spieler-Entscheid
## 2026-09-08): nur das Glas darüber dämpft es - kein Nebel, kein Park-Glühen. Was
## die Ebene unterscheidet, ist allein die Zeichen-Priorität.
func test_ein_geparktes_tablett_traegt_denselben_glaston() -> void:
	pater.set_head(0)
	var lying := (pater.get_node("Tablett1/Platte") as MeshInstance3D) \
		.material_override as StandardMaterial3D
	var parked := (pater.get_node("Tablett5/Platte") as MeshInstance3D) \
		.material_override as StandardMaterial3D
	assert_not_null(lying, "die Platte ist schlichtes Glas")
	assert_ne(lying, parked, "zwei Materialien, nicht eins")
	assert_eq(parked.albedo_color, lying.albedo_color, "derselbe Ton")
	assert_almost_eq(parked.emission_energy_multiplier,
		lying.emission_energy_multiplier, 0.0001, "dasselbe Licht")
	assert_almost_eq(lying.albedo_color.a, PaternosterView.PLATE_ALPHA, 0.0001,
		"die Alpha bleibt, wie sie war")
	assert_lt(parked.render_priority, lying.render_priority,
		"die geparkte zeichnet HINTER der liegenden Reihe")
	# Die Fahrt trägt die Priorität ihres ALTEN Platzes, bis sie steht.
	pater.step(1)
	await wait_frames(2)
	assert_eq((pater.get_node("Tablett2/Platte") as MeshInstance3D).material_override,
		lying, "die sinkende Reihe wechselt nicht schon in der Fläche")
	await wait_seconds(_ride_time())
	var sunk := (pater.get_node("Tablett2/Platte") as MeshInstance3D) \
		.material_override as StandardMaterial3D
	assert_lt(sunk.render_priority, lying.render_priority,
		"unten zeichnet sie hinter der liegenden")

## Jedes Tablett trägt einen RAND in SEINER Reihenfarbe (Spieler-Entscheid
## 2026-09-08): vier massive Leisten an den Kanten, keine zwei Reihen im selben Ton,
## Nachbarn weit auseinander - und die Nummer spricht dieselbe Farbe.
func test_jedes_tablett_traegt_seinen_reihen_rand() -> void:
	var seen: Array[Color] = []
	for row in ROWS:
		var rim := pater.get_node("Tablett%d/Rand" % (row + 1)) as Node3D
		assert_eq(rim.get_child_count(), 4, "vier Leisten an Reihe %d" % (row + 1))
		var tint := PaternosterView.row_color(row)
		for leaf in rim.get_children():
			var material := (leaf as MeshInstance3D).material_override as StandardMaterial3D
			assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED,
				"massiv, nicht Alpha - sonst stanzte er durch das Glas")
			assert_eq(material.emission, tint, "in der Reihenfarbe")
			assert_lt(material.emission_energy_multiplier, 0.95, "unter der Bloom-Schwelle")
		for other in seen:
			assert_ne(other, tint, "keine zwei Reihen im selben Ton")
		seen.append(tint)
		var number := pater.get_node("Tablett%d/Blende/Nummer" % (row + 1)) as Label3D
		assert_eq(number.modulate, tint, "die Nummer trägt die Farbe ihres Rands")
	# Nachbarreihen liegen im Farbkreis weit auseinander (mehr als eine Viertel-
	# drehung), damit die zwei liegenden Reihen sich auf einen Blick trennen.
	for row in ROWS - 1:
		var a := PaternosterView.row_color(row).h
		var b := PaternosterView.row_color(row + 1).h
		var gap := absf(a - b)
		gap = minf(gap, 1.0 - gap)
		assert_gt(gap, 0.25, "Reihe %d und %d" % [row + 1, row + 2])
	# Und der Rand liegt AUF der Platte: seine Oberkante steht über der Trittfläche.
	var leaf := pater.get_node("Tablett1/Rand/Rand0") as MeshInstance3D
	var top := leaf.position.y + (leaf.mesh as BoxMesh).size.y * 0.5
	assert_almost_eq(top, PaternosterView.RIM_RISE, 0.0001)

# --- Die Karten sind Kinder ihres Faches -------------------------------------------

func test_eine_karte_wird_kind_ihres_faches_und_faehrt_mit() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	# Reihe 3 parkt bei head 0 - sie kommt beim Rückwärts-Schritt nach vorn.
	cell.global_position = Vector3(0.0, pater.card_seat(2), 3.0)
	pater.host_card(cell, 2)
	assert_eq(cell.get_parent().name, "Fach")
	assert_almost_eq(cell.position.y, PaternosterView.PROUD, 0.0001,
		"lokal liegt sie IMMER auf der Trittfläche")
	assert_almost_eq(cell.global_position.y, pater.card_seat(2), 0.0001)
	var before := cell.global_position.y
	pater.step(-1)
	await wait_seconds(_ride_time())
	assert_gt(cell.global_position.y, before, "sie ist mit ihrem Tablett gestiegen")
	assert_almost_eq(cell.global_position.y, pater.card_seat(2), 0.0001)

## Und beim GLEITEN in der Fläche fährt sie quer mit, ohne die Höhe zu wechseln.
func test_eine_karte_gleitet_mit_ihrer_reihe_nach_vorn() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	cell.global_position = Vector3(pater.lane_x(PaternosterView.LANE_BACK),
		pater.card_seat(0), 3.0)
	pater.host_card(cell, 0)
	var before := cell.global_position
	pater.step(1)
	await wait_seconds(_ride_time())
	assert_almost_eq(cell.global_position.y, before.y, 0.0001, "dieselbe Höhe")
	assert_almost_eq(cell.global_position.x, before.x - pater.lane_depth(), 0.0001,
		"eine Lane nach vorn")

func test_sie_meldet_ob_eine_karte_schon_liegt() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	var at := Vector3(0.0, pater.card_seat(0), 2.0)
	assert_false(pater.seated(cell, 0, at), "noch gehört sie nicht dazu")
	cell.global_position = at
	pater.host_card(cell, 0)
	assert_true(pater.seated(cell, 0, at))
	assert_false(pater.seated(cell, 1, at), "und nur in IHRER Reihe")
	assert_false(pater.seated(cell, 0, at + Vector3(0.0, 0.0, 1.0)),
		"ein anderer Platz ist ein anderer Platz")

func test_der_umzug_behaelt_den_weltplatz() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	cell.global_position = Vector3(1.0, -2.0, 3.0)
	pater.host_card(cell, 2)
	var host := Node3D.new()
	add_child_autofree(host)
	var at := cell.global_position
	PaternosterView.rehost(cell, host)
	assert_eq(cell.get_parent(), host)
	assert_almost_eq(cell.global_position.x, at.x, 0.0001)
	assert_almost_eq(cell.global_position.z, at.z, 0.0001)

# --- Die FRONT-BLENDE ---------------------------------------------------------------

func test_jedes_tablett_traegt_seine_nummer() -> void:
	for row in ROWS:
		var label := pater.get_node("Tablett%d/Blende/Nummer" % (row + 1)) as Label3D
		assert_eq(label.text, pater.number_text(row))
		assert_true(label.text.begins_with(str(row + 1)),
			"die Reihe nennt sich selbst: '%s'" % label.text)
	var last := pater.get_node("Tablett%d/Blende/Nummer" % ROWS) as Label3D
	assert_eq(last.text, "%d/%d" % [ROWS, ROWS], "bis zehn hinauf")

func test_die_blende_traegt_je_karte_einen_tick_in_der_sortenfarbe() -> void:
	var tints: Array[Color] = [PackDrawerView.COLORS[Engraving.CATEGORY_NUMBER],
		PackDrawerView.COLORS[Engraving.CATEGORY_MATERIAL],
		PaternosterView.TICK_EMPTY]
	pater.set_ticks(0, tints)
	assert_eq(pater.tick_count(0), 3)
	assert_eq(pater.tick_color(0, 0), tints[0])
	assert_eq(pater.tick_color(0, 2), PaternosterView.TICK_EMPTY, "leer ist stumpf")
	var band := pater.get_node("Tablett1/Blende")
	var ticks := 0
	for child in band.get_children():
		if String(child.name).begins_with("Tick"):
			ticks += 1
	assert_eq(ticks, 3, "je Platz ein Block auf der Blende")

func test_die_ticks_liegen_auf_der_blende_am_bild_unteren_rand() -> void:
	var band := pater.get_node("Tablett1/Blende") as Node3D
	# Bild-UNTEN ist Welt -X: dort steht die Front, wie die einer Schublade.
	assert_lt(band.position.x, 0.0)

# --- Möbel, keine Fahrt --------------------------------------------------------------

func test_dieselben_masse_bauen_nichts_neu() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	pater.host_card(cell, 0)
	pater.setup(Vector3.ZERO, SPAN, SCALE)
	assert_eq(cell.get_parent().name, "Fach", "und die Karten überleben einen Neuaufbau")
	pater.setup(Vector3.ZERO, SPAN * 1.2, SCALE)
	assert_eq(cell.get_parent().name, "Fach",
		"auch einen mit neuen Maßen - das Fach gehört nicht der Platte")
