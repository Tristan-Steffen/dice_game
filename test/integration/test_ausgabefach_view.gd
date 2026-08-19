extends GutTest
## Das AUSGABEFACH: die offene Schale rechts der Werkbank, in der die bezahlten
## Würfel liegen, bis der Spieler ihren Pool-Platz wählt. Geprüft wird der EINE
## Abgleich (je Würfel-INSTANZ ein Körper), das Gleiten der Nachbarn, die Ankunft
## aus dem Förderwerk und ihr Endzustand nach übersprungenem Tween. Kein
## Kamerastrahl - die Schale wird in WELT-Punkten gefragt.

const CENTER := Vector3(-24.0, 0.0, 50.0)
const HALF := Vector2(4.1, 2.2)

var fach: AusgabefachView

func before_each() -> void:
	fach = AusgabefachView.new("ProbeFach")
	add_child_autofree(fach)
	fach.setup(CENTER, HALF)

func _dice(count: int) -> Array[DieDefinition]:
	var out: Array[DieDefinition] = []
	for i in count:
		out.append(DieDefinition.fixed(i % 6 + 1, "Probe%d" % i))
	return out

# --- Der eine Abgleich ----------------------------------------------------------

func test_je_wuerfel_ein_koerper() -> void:
	fach.present(_dice(3))
	await wait_frames(2)
	assert_eq(fach.items.size(), 3, "drei liegen darin")
	fach.present(fach._dice)  # derselbe Abgleich verdoppelt nichts
	await wait_frames(2)
	assert_eq(fach.items.size(), 3)

func test_die_wuerfel_liegen_auf_dem_fachboden_und_im_rechteck() -> void:
	fach.present(_dice(4))
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
	# Fällt Nummer 0 heraus, GLEITET der Rest nach vorn, statt fremde Meshes zu
	# erben - genau das war die Regel des alten Fachs, und sie zieht mit um.
	var dice := _dice(2)
	fach.present(dice)
	await wait_frames(2)
	var spot: Vector3 = fach.items[1]["spot"]
	var second: Node3D = fach.item_at(spot)["node"]
	var tail: Array[DieDefinition] = [dice[1]]
	fach.present(tail)
	await wait_frames(2)
	assert_eq(fach.items.size(), 1, "einer liegt noch darin")
	assert_eq(fach.items[0]["node"], second,
		"es ist DERSELBE Körper - er gleitet nach vorn")

func test_der_griff_findet_den_wuerfel_unter_dem_punkt() -> void:
	fach.present(_dice(2))
	await wait_frames(2)
	var first: Vector3 = fach.items[0]["spot"]
	var hit := fach.item_at(Vector3(first.x, CENTER.y, first.z))
	assert_false(hit.is_empty(), "über dem Würfel liegt der Würfel")
	assert_eq(int(hit["index"]), 0)
	assert_true(fach.item_at(Vector3(CENTER.x + HALF.x * 3.0, CENTER.y, CENTER.z)).is_empty(),
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
	var dice := _dice(2)
	fach.expect_arrival(dice[1])
	fach.present(dice)
	await wait_frames(2)
	assert_true(fach.awaiting(dice[1]), "er ist noch unterwegs")
	assert_eq(fach.items.size(), 1, "sein Körper wartet auf das Förderwerk")
	assert_true(fach.deliver(dice[1]), "und kommt mit dem Unterlicht an")
	await wait_frames(2)
	assert_eq(fach.items.size(), 2, "jetzt liegen beide da")
	assert_false(fach.awaiting(dice[1]))

func test_die_ankunft_endet_dort_wo_ein_hartes_present_endet() -> void:
	# Übersprungener Tween: der Endzustand steht trotzdem (die seat_hard-Regel).
	var dice := _dice(3)
	var reference := AusgabefachView.new("HartProbe")
	add_child_autofree(reference)
	reference.setup(CENTER, HALF)
	reference.present(dice)
	fach.expect_arrival(dice[2])
	fach.present(dice)
	fach.deliver(dice[2])
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
	fach.expect_arrival(dice[1])
	fach.present(dice)
	await wait_frames(2)
	fach.clear()
	assert_eq(fach.items.size(), 0, "nichts liegt mehr darin")
	assert_false(fach.awaiting(dice[1]), "und keine Fahrt bleibt hängen")
	assert_not_null(fach.floor_plate, "die SCHALE bleibt stehen")

func test_was_nicht_mehr_hinterlegt_ist_ist_auch_nicht_mehr_unterwegs() -> void:
	var dice := _dice(2)
	fach.expect_arrival(dice[1])
	fach.present(dice)
	var head: Array[DieDefinition] = [dice[0]]
	fach.present(head)
	assert_false(fach.awaiting(dice[1]), "seine Fahrt endet mit seinem Platz")

# --- Das Raster (reine Mathematik) ----------------------------------------------

func test_die_schale_misst_ihre_plaetze_selbst() -> void:
	var inner := fach.inner()
	assert_gt(inner.x, 0.0)
	assert_gt(inner.y, 0.0)
	assert_eq(fach.capacity(),
		AusgabefachView.fits(inner.x) * AusgabefachView.fits(inner.y),
		"die Kapazität ist gemessen, nicht getippt")
	assert_gte(fach.capacity(), 4, "für die üblichen Käufe reicht sie")

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
