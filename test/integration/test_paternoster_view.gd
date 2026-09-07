extends GutTest
## Der PATERNOSTER: fünf TABLETTS in der Magazin-Grube, gezeigt wird genau EINES.
## Blättern heißt sinken und steigen; die Karten sind Kinder ihres Faches und fahren
## mit. Keine Karte ragt je über die Tischkante.

## Die Grube in Welt: x quer (Bild-hoch), y längs (Bild-breit).
const SPAN := Vector2(2.4, 24.0)
const SCALE := PackDrawerView.CASSETTE_SCALE
## Die Invariante der Wurzel: nichts liegt höher als das im Tisch.
const RIM_LIMIT := -0.11

var pater: PaternosterView

func before_each() -> void:
	pater = PaternosterView.new()
	add_child_autofree(pater)
	pater.setup(Vector3.ZERO, SPAN, SCALE)

func _ride_time() -> float:
	return PaternosterView.SINK_TIME + PaternosterView.RISE_TIME + 0.1

# --- Die fünf Etagen -------------------------------------------------------------

func test_es_gibt_fuenf_tabletts_und_eines_steht_oben() -> void:
	assert_eq(pater.page_count(), PackDrawerView.PAGES, "so viele wie das Magazin zählt")
	assert_eq(pater.shown(), 0, "und Etage 1 liegt zuerst oben")
	for page in range(1, PackDrawerView.PAGES):
		assert_lt(pater.tray_top(page), pater.tray_top(0),
			"Etage %d parkt darunter" % (page + 1))

func test_die_geparkten_stapeln_sich_mit_fester_teilung() -> void:
	for page in range(2, PackDrawerView.PAGES):
		assert_almost_eq(pater.tray_top(page - 1) - pater.tray_top(page),
			PaternosterView.PITCH, 0.0001, "Etage %d liegt eine Teilung tiefer" % (page + 1))

## Der ganze Stapel muß in die Grube passen - sonst stünde ein Tablett im Boden.
func test_der_stapel_bleibt_in_der_grube() -> void:
	var pit := DataCellView.STAND_HEIGHT * SCALE * 1.3  # _pack_pit_depth
	assert_lt(PaternosterView.stack_depth(SCALE), pit,
		"fünf Tabletts tiefer als die Grube wäre ein Loch im Boden")

# --- Die Invariante: nichts über der Tischkante ------------------------------------

func test_keine_karte_ragt_ueber_die_tischkante() -> void:
	for page in PackDrawerView.PAGES:
		assert_lte(pater.card_top(page), RIM_LIMIT,
			"Etage %d bleibt unter der Kante" % (page + 1))
	# Und die gezeigte liegt so hoch, wie es eben noch geht - sie soll gelesen werden.
	assert_gt(pater.card_top(0), RIM_LIMIT - DataCellView.lying_over(SCALE),
		"aber knapp darunter, nicht irgendwo tief unten")

func test_die_karte_liegt_auf_der_trittflaeche() -> void:
	assert_almost_eq(pater.card_seat(0), pater.tray_top(0) + PaternosterView.PROUD,
		0.0001, "eine Spur über der Platte, nicht koplanar")
	assert_almost_eq(pater.card_top(0) - pater.card_seat(0),
		DataCellView.lying_over(SCALE), 0.0001, "und ihre Dicke steht darüber")

## Der GRIFF zieht sie über die Kante - der Hover ist die eine erlaubte Ausnahme.
func test_der_griff_zieht_die_karte_ueber_die_kante() -> void:
	var lift := PaternosterView.hover_lift(SCALE) * DataCellView.STAND_HEIGHT * SCALE
	assert_gt(pater.card_top(0) + lift, 0.0, "gegriffen steht sie über dem Glas")

# --- Blättern: das gezeigte sinkt, das gewählte steigt -----------------------------

func test_blaettern_stellt_die_gewaehlte_etage_nach_oben() -> void:
	pater.show_page(3)
	assert_eq(pater.shown(), 3, "die Wahl gilt sofort")
	assert_true(pater.riding(), "und die Fahrt läuft")
	await wait_seconds(_ride_time())
	assert_false(pater.riding())
	assert_almost_eq(pater.tray_top(3), -PaternosterView.read_drop(SCALE), 0.0001,
		"Etage 4 liegt oben")
	for page in [0, 1, 2, 4]:
		assert_lt(pater.tray_top(page), pater.tray_top(3),
			"Etage %d parkt" % (page + 1))

## Endzustand zuerst: ein harter Abbruch mitten in der Fahrt schuldet nichts.
func test_ein_abbruch_setzt_jedes_tablett_hart() -> void:
	pater.show_page(2)
	await wait_frames(2)
	pater.settle_hard()
	assert_false(pater.riding())
	for page in PackDrawerView.PAGES:
		var tray := pater.get_node("Tablett%d" % (page + 1)) as Node3D
		assert_almost_eq(tray.position.y,
			-PaternosterView.drop_for(page, 2, SCALE), 0.0001,
			"Etage %d steht auf ihrer Ruhehöhe" % (page + 1))

func test_nur_die_gezeigte_etage_ist_zu_sehen() -> void:
	for page in PackDrawerView.PAGES:
		var fach := pater.get_node("Tablett%d/Fach" % (page + 1)) as Node3D
		assert_eq(fach.visible, page == 0, "Etage %d" % (page + 1))
	pater.show_page(2)
	await wait_seconds(_ride_time())
	for page in PackDrawerView.PAGES:
		var fach := pater.get_node("Tablett%d/Fach" % (page + 1)) as Node3D
		assert_eq(fach.visible, page == 2, "nach dem Blättern: Etage %d" % (page + 1))

func test_dieselbe_etage_noch_einmal_faehrt_nicht() -> void:
	pater.show_page(0)
	assert_false(pater.riding(), "wer schon oben liegt, fährt nicht")

# --- Die Karten sind Kinder ihres Faches -------------------------------------------

func test_eine_karte_wird_kind_ihres_faches_und_faehrt_mit() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	cell.global_position = Vector3(0.0, pater.card_seat(1), 3.0)
	pater.host_card(cell, 1)
	assert_eq(cell.get_parent().name, "Fach")
	assert_almost_eq(cell.position.y, PaternosterView.PROUD, 0.0001,
		"lokal liegt sie IMMER auf der Trittfläche")
	assert_almost_eq(cell.global_position.y, pater.card_seat(1), 0.0001)
	var before := cell.global_position.y
	pater.show_page(1)
	await wait_seconds(_ride_time())
	assert_gt(cell.global_position.y, before, "sie ist mit ihrem Tablett gestiegen")
	assert_almost_eq(cell.global_position.y, pater.card_seat(1), 0.0001)

func test_sie_meldet_ob_eine_karte_schon_liegt() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	var at := Vector3(0.0, pater.card_seat(0), 2.0)
	assert_false(pater.seated(cell, 0, at), "noch gehört sie nicht dazu")
	cell.global_position = at
	pater.host_card(cell, 0)
	assert_true(pater.seated(cell, 0, at))
	assert_false(pater.seated(cell, 1, at), "und nur auf IHRER Etage")
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
	for page in PackDrawerView.PAGES:
		var label := pater.get_node("Tablett%d/Blende/Nummer" % (page + 1)) as Label3D
		assert_eq(label.text, pater.number_text(page))
		assert_true(label.text.begins_with(str(page + 1)),
			"die Etage nennt sich selbst: '%s'" % label.text)

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
	assert_almost_eq(pater.band_depth(), SPAN.x * PackDrawerView.FRONT_SHARE, 0.0001,
		"und sie nimmt genau den Anteil, den das Magazin für sie freihält")

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
