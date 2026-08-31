extends GutTest
## Das AUSGABEFACH: die offene Schale an der Bildschirm-rechten Kante des Vorrats,
## in der der bezahlte Würfel liegt, bis der Spieler ihn auf einen Pool-Sitz zieht.
## OFFEN liegt genau EINER - was darüber hinaus hinterlegt ist, wartet unter dem
## Fachboden und rückt von unten nach. Geprüft wird der EINE Abgleich (je Würfel-
## INSTANZ ein Körper), das Nachrücken, die Ankunft aus dem Förderwerk, ihr
## Endzustand nach übersprungenem Tween und ihr PLATZ neben dem Pool-Loch. Kein
## Kamerastrahl - die Schale wird in WELT-Punkten gefragt.

const CENTER := Vector3(-24.0, 0.0, 50.0)

var fach: AusgabefachView
var half: Vector2

func before_each() -> void:
	half = AusgabefachView.single_half()
	fach = AusgabefachView.new("ProbeFach")
	add_child_autofree(fach)
	fach.setup(CENTER, half)

func _dice(count: int) -> Array[DieDefinition]:
	var out: Array[DieDefinition] = []
	for i in count:
		out.append(DieDefinition.fixed(i % 6 + 1, "Probe%d" % i))
	return out

# --- Der eine Abgleich ----------------------------------------------------------

func test_offen_liegt_genau_einer() -> void:
	fach.present(_dice(3))
	await wait_frames(2)
	assert_eq(fach.items.size(), 1, "einer liegt offen, mehr zeigt die Schale nicht")
	assert_eq(fach.waiting_count(), 2, "die anderen warten unter dem Fachboden")
	assert_eq(int(fach.items[0]["index"]), 0, "und es ist der zuerst hinterlegte")
	fach.present(fach._dice)  # derselbe Abgleich verdoppelt nichts
	await wait_frames(2)
	assert_eq(fach.items.size(), 1)

func test_der_wuerfel_liegt_auf_dem_fachboden_und_im_rechteck() -> void:
	fach.present(_dice(2))
	await wait_frames(2)
	var min_xz := fach.bounds_min()
	var max_xz := fach.bounds_max()
	for item in fach.items:
		var spot: Vector3 = item["spot"]
		assert_gt(spot.y, CENTER.y, "die Schale steht AUF dem Glas, nicht darin")
		assert_gte(spot.x, min_xz.x)
		assert_lte(spot.x, max_xz.x)
		assert_gte(spot.z, min_xz.y)
		assert_lte(spot.z, max_xz.y)

func test_der_koerper_haengt_am_wuerfel_nicht_am_platz() -> void:
	# Geht der vordere, ERBT der nächste seinen Platz - aber nie sein Mesh.
	var dice := _dice(2)
	fach.present(dice)
	await wait_frames(2)
	var first: Node3D = fach.items[0]["node"]
	var tail: Array[DieDefinition] = [dice[1]]
	fach.present(tail)
	await wait_frames(2)
	assert_eq(fach.items.size(), 1, "der Nachrücker liegt jetzt offen")
	assert_ne(fach.items[0]["node"], first, "und er bringt seinen eigenen Körper mit")

func test_der_griff_findet_den_wuerfel_unter_dem_punkt() -> void:
	fach.present(_dice(2))
	await wait_frames(2)
	var first: Vector3 = fach.items[0]["spot"]
	var hit := fach.item_at(Vector3(first.x, CENTER.y, first.z))
	assert_false(hit.is_empty(), "über dem Würfel liegt der Würfel")
	assert_eq(int(hit["index"]), 0)
	assert_true(fach.item_at(Vector3(CENTER.x + half.x * 3.0, CENTER.y, CENTER.z)).is_empty(),
		"neben der Schale liegt nichts")

func test_greifen_hebt_nur_den_wechsel() -> void:
	fach.present(_dice(2))
	await wait_frames(2)
	var key := int(fach.items[0]["key"])
	var spot: Vector3 = fach.items[0]["spot"]
	var body: Node3D = fach.items[0]["node"]
	fach.set_hovered(key)
	assert_eq(fach.hovered_key(), key)
	await wait_seconds(AusgabefachView.HOVER_TIME + 0.05)
	assert_gt(body.global_position.y, spot.y + 0.01, "das gegriffene Stück steht höher")
	fach.set_hovered(0)
	await wait_seconds(AusgabefachView.HOVER_TIME + 0.05)
	assert_almost_eq(body.global_position.y, spot.y, 0.01, "und legt sich wieder hin")

# --- Die Ankunft aus dem Förderwerk ---------------------------------------------

func test_ein_unterwegs_gemeldeter_wuerfel_haelt_seinen_platz_ohne_koerper() -> void:
	var dice := _dice(1)
	fach.expect_arrival(dice[0])
	fach.present(dice)
	await wait_frames(2)
	assert_true(fach.awaiting(dice[0]), "er ist noch unterwegs")
	assert_eq(fach.items.size(), 0, "sein Körper wartet auf das Förderwerk")
	assert_true(fach.deliver(dice[0]), "und kommt mit dem Unterlicht an")
	await wait_frames(2)
	assert_eq(fach.items.size(), 1, "jetzt liegt er da")
	assert_false(fach.awaiting(dice[0]))

func test_die_ankunft_endet_dort_wo_ein_hartes_present_endet() -> void:
	# Übersprungener Tween: der Endzustand steht trotzdem (die seat_hard-Regel).
	var dice := _dice(2)
	var reference := AusgabefachView.new("HartProbe")
	add_child_autofree(reference)
	reference.setup(CENTER, half)
	reference.present(dice)
	fach.expect_arrival(dice[0])
	fach.present(dice)
	fach.deliver(dice[0])
	fach.settle()  # der Laufwechsel legt hart
	await wait_frames(2)
	assert_eq(fach.items.size(), reference.items.size())
	for i in fach.items.size():
		var here: Node3D = fach.items[i]["node"]
		var there: Node3D = reference.items[i]["node"]
		assert_true(here.global_position.is_equal_approx(there.global_position),
			"Platz %d liegt, wo ein hartes present ihn legte" % i)

func test_eine_ankunft_ohne_anmeldung_faehrt_nicht() -> void:
	var dice := _dice(1)
	fach.present(dice)
	await wait_frames(2)
	assert_false(fach.deliver(dice[0]), "wer nie unterwegs war, kommt nicht an")

func test_ein_laufwechsel_raeumt_die_schale_hart() -> void:
	var dice := _dice(2)
	fach.expect_arrival(dice[0])
	fach.present(dice)
	await wait_frames(2)
	fach.clear()
	assert_eq(fach.items.size(), 0, "nichts liegt mehr darin")
	assert_false(fach.awaiting(dice[0]), "und keine Fahrt bleibt hängen")
	assert_not_null(fach.floor_plate, "die SCHALE bleibt stehen")

func test_was_nicht_mehr_hinterlegt_ist_ist_auch_nicht_mehr_unterwegs() -> void:
	var dice := _dice(2)
	fach.expect_arrival(dice[1])
	fach.present(dice)
	var head: Array[DieDefinition] = [dice[0]]
	fach.present(head)
	assert_false(fach.awaiting(dice[1]), "seine Fahrt endet mit seinem Platz")

# --- Ihr Platz neben dem Pool-Loch ----------------------------------------------

func test_die_schale_steht_ausserhalb_des_pool_lochs() -> void:
	# Das Loch des Vorrats: sein 5x6-Slotraster plus einen halben Platz Saum ringsum.
	var at := Vector3(-24.0, 0.0, 21.75)
	var hole := Vector2(4.5, 5.4)
	var spot := AusgabefachView.spot_beside(at, hole, LiftShaftView.WALL)
	var probe := AusgabefachView.new("LochProbe")
	add_child_autofree(probe)
	probe.setup(spot, half)
	assert_gt(probe.bounds_min().y, at.z + hole.y,
		"kein Rand ragt ins offene Pit - die Neuzugänge stehen auch in der Runde")
	assert_almost_eq(probe.bounds_min().y - (at.z + hole.y + LiftShaftView.WALL),
		AusgabefachView.POOL_GAP, 0.001,
		"zwischen Schachtwand und Schalenrand steht genau die Fuge")
	assert_almost_eq(probe.bounds_max().x, at.x + hole.x, 0.001,
		"und sie steht bündig an der oberen Lochkante - darunter braucht die Säule Platz")

func test_die_schale_traegt_genau_EINEN_platz() -> void:
	assert_eq(AusgabefachView.fits(fach.inner().x), 1, "quer genau eine Spalte")
	assert_eq(AusgabefachView.fits(fach.inner().y), 1, "und längs genau eine Reihe")
	assert_eq(fach.capacity(), 1, "die Schale ist auf den einen Platz getrimmt")
	assert_eq(fach.visible_cap(), AusgabefachView.VISIBLE_CAP,
		"und offen liegt genau dieser eine")

# --- Das Raster (reine Mathematik) ----------------------------------------------

func test_die_schale_misst_ihre_plaetze_selbst() -> void:
	var inner := fach.inner()
	assert_gt(inner.x, 0.0)
	assert_gt(inner.y, 0.0)
	assert_eq(fach.capacity(),
		AusgabefachView.fits(inner.x) * AusgabefachView.fits(inner.y),
		"die Kapazität ist gemessen, nicht getippt")
	assert_eq(fach.visible_cap(), mini(AusgabefachView.VISIBLE_CAP, fach.capacity()),
		"der Deckel ist das Minimum aus gemessener Kapazität und VISIBLE_CAP")

func test_das_raster_faellt_aus_der_innenflaeche() -> void:
	var inner := Vector2(AusgabefachView.CELL * 2.4, AusgabefachView.CELL * 3.4)
	assert_eq(AusgabefachView.grid_for(inner, 0), Vector2i(2, 0), "leer = keine Zeile")
	assert_eq(AusgabefachView.grid_for(inner, 3), Vector2i(2, 2))
	assert_eq(AusgabefachView.grid_for(inner, 4), Vector2i(2, 2))
	assert_eq(AusgabefachView.grid_for(inner, 5), Vector2i(2, 3))

func test_eine_volle_reihe_rueckt_zusammen_statt_ueberzulaufen() -> void:
	var spots := AusgabefachView.row_spots(6, 30.0, 10.0)
	assert_eq(spots.size(), 6)
	assert_lte(spots[5] - spots[0], 30.0, "die Reihe bleibt im Feld")
	assert_lt(spots[1] - spots[0], 10.0, "sie rückt zusammen")

func test_der_schluessel_ist_die_wuerfel_instanz() -> void:
	var first := DieDefinition.standard()
	var second := DieDefinition.standard()
	assert_ne(AusgabefachView.body_key(first), AusgabefachView.body_key(second),
		"zwei Würfel sind zwei Körper, auch wenn sie gleich aussehen")
	assert_eq(AusgabefachView.body_key(first), AusgabefachView.body_key(first))
	assert_eq(AusgabefachView.body_key(null), 0, "ohne Würfel kein Körper")

# --- Einer liegt offen, der Rest rückt von unten nach -----------------------------

func test_wird_der_platz_frei_rueckt_der_naechste_von_unten_nach() -> void:
	# Genau der Tausch-Fall: der offene geht, der nächste kommt DURCH DEN BODEN.
	var dice := _dice(2)
	fach.present(dice)
	await wait_frames(2)
	assert_eq(fach.waiting_count(), 1, "er wartet noch unter dem Boden")
	var tail: Array[DieDefinition] = [dice[1]]
	fach.present(tail)
	# SOFORT nach dem Abgleich: der Nachrücker steht noch UNTER seinem Platz.
	var rising := fach.item_at(_spot_of(dice[1]))
	assert_false(rising.is_empty(), "er ist jetzt der offene")
	var body: Node3D = rising["node"]
	var spot: Vector3 = rising["spot"]
	assert_lt(body.global_position.y, spot.y - 0.1, "und startet unter dem Fachboden")
	await wait_seconds(AusgabefachView.ARRIVE_TIME + 0.1)
	assert_almost_eq(body.global_position.y, spot.y, 0.01, "dann liegt er oben")
	assert_eq(fach.waiting_count(), 0, "und es wartet keiner mehr")

func test_ein_frisch_gestelltes_fach_laesst_niemanden_steigen() -> void:
	# Der erste Aufbau ist keine Ankunft: was von Anfang an hinterlegt ist, LIEGT.
	fach.present(_dice(2))
	for item in fach.items:
		var body: Node3D = item["node"]
		var spot: Vector3 = item["spot"]
		assert_almost_eq(body.global_position.y, spot.y, 0.01, "sein Platz steht sofort")

# --- Der VORHANG: das PODEST nimmt dem Fach seinen Platz --------------------------

func test_der_vorhang_versenkt_die_neuzugaenge_im_fachboden() -> void:
	fach.present(_dice(1))
	await wait_frames(2)
	assert_eq(fach.items.size(), 1, "vorher liegt einer offen")
	fach.set_curtain(true)
	assert_true(fach.curtained())
	assert_eq(fach.items.size(), 0, "hinter dem Vorhang liegt nichts mehr offen")

func test_der_gehobene_vorhang_laesst_sie_wieder_STEIGEN() -> void:
	# Kein Aufpoppen: sie kommen denselben Weg zurueck, den jede Ankunft nimmt.
	var dice := _dice(1)
	fach.present(dice)
	await wait_frames(2)
	fach.set_curtain(true)
	await wait_frames(2)
	fach.set_curtain(false)
	var rising := fach.item_at(_spot_of(dice[0]))
	assert_false(rising.is_empty(), "er liegt wieder offen")
	var body: Node3D = rising["node"]
	var spot: Vector3 = rising["spot"]
	assert_lt(body.global_position.y, spot.y - 0.1, "und startet unter dem Fachboden")
	await wait_seconds(AusgabefachView.ARRIVE_TIME + 0.1)
	assert_almost_eq(body.global_position.y, spot.y, 0.01, "dann liegt er oben")

func test_der_platz_des_podests_ist_eine_reine_rechnung() -> void:
	# Er steht AUCH, wenn gerade keiner liegt - das Podest fragt ihn hinter dem Vorhang.
	var dice := _dice(1)
	fach.present(dice)
	await wait_frames(2)
	var lying: Vector3 = _spot_of(dice[0])
	assert_almost_eq(fach.open_spot(), lying, Vector3.ONE * 0.001,
		"derselbe Platz, den der liegende Wuerfel hat")
	fach.set_curtain(true)
	assert_almost_eq(fach.open_spot(), lying, Vector3.ONE * 0.001,
		"und er bleibt es hinter dem Vorhang")
	assert_almost_eq(fach.floor_top_y(),
		CENTER.y + AusgabefachView.FLOOR_LIFT + AusgabefachView.FLOOR_HEIGHT, 0.0001)

func test_ein_laufwechsel_hebt_den_vorhang() -> void:
	fach.present(_dice(1))
	fach.set_curtain(true)
	fach.clear()
	assert_false(fach.curtained(), "die leere Schale haelt nichts mehr zurueck")

func _spot_of(def: DieDefinition) -> Vector3:
	for item in fach.items:
		if int(item["key"]) == AusgabefachView.body_key(def):
			return item["spot"]
	return Vector3.INF
