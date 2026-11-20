extends GutTest
## Die Layout-Kette der Werkstatt (Layout C): gemessene Eingaben vom 2026-11-18,
## 1280 × 720. Rechts am Pool die Gleichung samt Podest, unter dem Pool Walze und
## Info-Schirm, darunter das breite Magazin.

const POOL := Rect2(2916.4, 1994.8, 585.0, 487.5)
const CARD := Vector2(194.4, 129.6)
const FACE := 55.46
const U := 5.042
const SEAM := 48.75
const HUB_BOTTOM := 3127.3
const DISPLAY_WIDTH := 5094.0

var lay: Dictionary

func before_each() -> void:
	lay = WorkshopView.drum_layout(POOL, CARD, FACE, U, 0.0, SEAM)

func test_the_drum_lies_under_the_pool_left_aligned() -> void:
	var pit: Rect2 = lay["pit"]
	assert_almost_eq(pit.position.x, POOL.position.x, 0.01, "linksbündig mit dem Pool")
	assert_gt(pit.position.y, POOL.end.y + SEAM, "eine Naht und die Nummern darunter")

func test_slices_run_left_to_right_inside_pit() -> void:
	var slices: Array = lay["slices"]
	var pit: Rect2 = lay["pit"]
	assert_eq(slices.size(), WorkshopView.DRUM_SLICES)
	for i in slices.size():
		var s: Rect2 = slices[i]
		assert_true(pit.encloses(s), "Scheibe %d im Graben" % (i + 1))
		assert_gt(s.size.x, CARD.x, "die Karte liegt mit ihrer Langseite längs der Achse")
		if i > 0:
			assert_gt(s.position.x, (slices[i - 1] as Rect2).end.x)

func test_drum_fits_on_edge_at_the_short_side() -> void:
	var pit: Rect2 = lay["pit"]
	assert_almost_eq(WorkshopView.drum_side_px(CARD), CARD.y * (1.0 + WorkshopView.DRUM_SIDE_AIR),
		0.001, "der Querschnitt mißt an der KURZEN Kartenseite")
	assert_gt(pit.size.y, WorkshopView.drum_side_px(CARD) * sqrt(2.0))

## Der INFO-SCHIRM steht am Walzen-Ende: eine Naht daneben, so hoch wie der Graben,
## rechts bündig mit dem Magazin.
func test_the_info_screen_closes_the_drum_row() -> void:
	var pit: Rect2 = lay["pit"]
	var info: Rect2 = lay["info"]
	var shelf: Rect2 = lay["shelf"]
	assert_almost_eq(info.position.x, pit.end.x + U * WorkshopView.STREET_GAP, 0.01,
		"eine Naht rechts am Graben")
	assert_almost_eq(info.position.y, pit.position.y, 0.01, "oben bündig mit dem Graben")
	assert_almost_eq(info.size.y, pit.size.y, 0.01, "so hoch wie er")
	assert_almost_eq(info.end.x, shelf.end.x, 0.01, "rechts bündig mit dem Magazin")

func test_the_chamber_is_the_podium_plate() -> void:
	var chamber: Rect2 = lay["chamber"]
	var plate: Rect2 = lay["podium_stage"]
	assert_true(chamber.is_equal_approx(plate), "die Grube ist so groß wie die Platte")
	assert_gte(chamber.size.x, WorkshopView.chamber_side_px(FACE, U), "Platz für die Kabel")
	assert_gte(chamber.get_center().y - plate.position.y,
		WorkshopView.PODIUM_TILT_TRIM + FACE * WorkshopView.PODIUM_HEAD_FACES,
		"oben Platz für den schwebenden Würfel")
	assert_false(chamber.intersects(lay["podium_net"]), "die Die-View liegt frei")
	for key in ["pit", "stamp", "shelf", "info", "upgrades", "result", "raster"]:
		assert_false(chamber.intersects(lay[key]), "die Kammer liegt nicht auf %s" % key)
	assert_false(chamber.intersects(POOL), "und nicht im Pool")

func test_shelf_spans_four_columns_of_two_cards() -> void:
	var shelf: Rect2 = lay["shelf"]
	assert_almost_eq(shelf.position.x, POOL.position.x, 0.01, "linksbündig")
	assert_gt(shelf.position.y, (lay["pit"] as Rect2).end.y)
	var columns: Array = lay["columns"]
	assert_eq(columns.size(), PackDrawerView.COLUMNS)
	for i in columns.size():
		var c: Rect2 = columns[i]
		assert_true(shelf.encloses(c))
		assert_gt(c.size.x, CARD.x * float(PackDrawerView.ACROSS),
			"zwei liegende Karten nebeneinander")
		assert_gt(c.size.y, CARD.y * float(PackDrawerView.PLACES), "zwei Reihen untereinander")
		if i > 0:
			assert_gt(c.position.x, (columns[i - 1] as Rect2).end.x, "Spalten von links")

## Vier TRAYS samt Fassung: sie überlappen nicht, zwischen ihnen derselbe Filz, und das
## Magazin wird nicht höher als die eine Grube vor ihnen (Unterkante ≤ 3117,7).
func test_the_shelf_is_four_trays_no_taller_than_before() -> void:
	var shelf: Rect2 = lay["shelf"]
	var trays: Array = lay["trays"]
	var columns: Array = lay["columns"]
	assert_eq(trays.size(), PackDrawerView.COLUMNS)
	for i in trays.size():
		var tray: Rect2 = trays[i]
		assert_true(tray.encloses(columns[i]), "Tray %d umschließt seine Grube" % (i + 1))
		assert_true(shelf.grow(0.01).encloses(tray))
		if i > 0:
			assert_false(tray.intersects(trays[i - 1]), "Tray %d steht frei" % (i + 1))
			assert_almost_eq(tray.position.x - (trays[i - 1] as Rect2).end.x,
				PackDrawerView.FELT_GAP_PX, 0.01, "derselbe Filz dazwischen")
	assert_almost_eq((trays[0] as Rect2).position.x, shelf.position.x, 0.01)
	assert_almost_eq((trays[trays.size() - 1] as Rect2).end.x, shelf.end.x, 0.01)
	assert_lte(shelf.end.y, 3117.7, "nicht tiefer als die eine Grube vor den Trays")
	assert_lt(shelf.size.x, 1874.8, "schmaler: die Ränder sind gespart")
	assert_gte((lay["info"] as Rect2).size.x, CARD.x * 2.0, "der Info-Schirm bleibt breit genug")

## Die GLEICHUNG rechts am Pool: UPGRADES + ORIGINAL = ERGEBNIS, drei gleich große Netze,
## unten bündig.
func test_the_equation_stands_right_of_the_pool() -> void:
	var original: Rect2 = lay["podium_net"]
	var upgrades: Rect2 = lay["upgrades"]
	var result: Rect2 = lay["result"]
	var signs: Array = lay["signs"]
	assert_almost_eq(upgrades.position.x, POOL.end.x + U * WorkshopView.DRUM_SHELF_GAP, 0.01,
		"eine Fuge rechts vom Pool")
	assert_gt(original.position.x, upgrades.end.x, "ORIGINAL rechts von UPGRADES")
	assert_gt(result.position.x, original.end.x, "ERGEBNIS rechts davon")
	assert_eq(upgrades.size, original.size, "gleich groß wie die Die-View")
	assert_eq(result.size, original.size)
	assert_almost_eq(upgrades.end.y, original.end.y, 0.01, "unten bündig")
	assert_almost_eq(result.end.y, original.end.y, 0.01)
	assert_eq(lay["original"], original, "ORIGINAL IST die Die-View")
	assert_true((signs[0] as Rect2).position.x >= upgrades.end.x - 0.01, "+ hinter UPGRADES")
	assert_true((signs[0] as Rect2).end.x <= original.position.x + 0.01)
	assert_true((signs[1] as Rect2).position.x >= original.end.x - 0.01, "= vor ERGEBNIS")
	assert_true((signs[1] as Rect2).end.x <= result.position.x + 0.01)
	assert_true((lay["equation"] as Rect2).grow(0.05).encloses(upgrades.merge(result)))

func test_raster_and_stamp_stand_over_their_nets() -> void:
	var raster: Rect2 = lay["raster"]
	var stamp: Rect2 = lay["stamp"]
	var upgrades: Rect2 = lay["upgrades"]
	var result: Rect2 = lay["result"]
	var plate: Rect2 = lay["podium_stage"]
	assert_almost_eq(raster.get_center().x, upgrades.get_center().x, 0.01, "mittig über UPGRADES")
	assert_almost_eq(stamp.get_center().x, result.get_center().x, 0.01, "mittig über ERGEBNIS")
	assert_almost_eq(raster.get_center().y, plate.get_center().y, 0.01, "auf halber Plattenhöhe")
	assert_almost_eq(stamp.get_center().y, plate.get_center().y, 0.01)
	var heads := U * WorkshopView.EQ_HEAD_UNITS
	assert_lte(raster.end.y, upgrades.position.y - heads + 0.01, "über der Überschrift")
	assert_lte(stamp.end.y, result.position.y - heads + 0.01)
	assert_gte(raster.position.y, POOL.position.y - 0.01, "nicht über dem Pool")
	assert_false(stamp.intersects(plate) or raster.intersects(plate), "neben der Platte")
	# Die echte Raster-Taste (Welt 1,84 × 4,08 bei 37,5 px/Welt) paßt hinein.
	assert_gte(raster.size.x, RasterSwitchView.HALF.y * 2.0 * 37.5)
	assert_gte(raster.size.y, RasterSwitchView.HALF.x * 2.0 * 37.5)

## Kein Rechteck der Kette überdeckt ein anderes.
func test_no_two_parts_overlap() -> void:
	var heads := U * WorkshopView.EQ_HEAD_UNITS
	var parts := {
		"pit": (lay["pit"] as Rect2).grow_individual(0.0,
			U * (WorkshopView.SLICE_NUMBER_UNITS + WorkshopView.SLICE_NUMBER_GAP), 0.0, 0.0),
		"info": lay["info"], "shelf": lay["shelf"],
		"upgrades": (lay["upgrades"] as Rect2).grow_individual(0.0, heads, 0.0, 0.0),
		"result": (lay["result"] as Rect2).grow_individual(0.0, heads, 0.0, 0.0),
		"plate": lay["podium_stage"], "net": lay["podium_net"], "raster": lay["raster"],
		"stamp": lay["stamp"], "plus": lay["signs"][0], "equals": lay["signs"][1],
		"pool": POOL}
	var keys := parts.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Rect2 = parts[keys[i]]
			var b: Rect2 = parts[keys[j]]
			assert_false(a.intersection(b).get_area() > 1.0,
				"%s und %s überlappen nicht" % [keys[i], keys[j]])

func test_the_height_fits_under_the_pool() -> void:
	var bounds: Rect2 = lay["bounds"]
	assert_lte(bounds.end.y, HUB_BOTTOM, "nichts reicht unter die Hub-Unterkante")
	assert_lte(bounds.end.x, DISPLAY_WIDTH, "nichts über den Displayrand")
	assert_gte(bounds.position.y, POOL.end.y + SEAM - 0.01, "und nichts in den Pool")
	assert_lte((lay["equation"] as Rect2).end.x, DISPLAY_WIDTH)

func test_the_podium_stands_in_the_equation_row() -> void:
	var podium: Rect2 = lay["podium"]
	assert_almost_eq(podium.position.y, POOL.position.y, 0.01, "oben bündig mit dem Pool")
	assert_lte(podium.size.y, POOL.size.y + 0.01, "höchstens so hoch wie die Pool-Reihe")
	assert_almost_eq(podium.size.x, maxf((lay["podium_net"] as Rect2).size.x,
		(lay["podium_stage"] as Rect2).size.x), 0.01, "so breit wie Die-View bzw. Platte")
	assert_false(podium.intersects(lay["bounds"]), "die Werkstatt berührt ihn nicht")

## Oben die Platte, eine Naht darunter die Die-View in Würfelgröße.
func test_the_podium_carries_its_plate_over_its_die_view() -> void:
	var podium: Rect2 = lay["podium"]
	var plate: Rect2 = lay["podium_stage"]
	var net: Rect2 = lay["podium_net"]
	var span := DieNetView.net_size(FACE * WorkshopView.PODIUM_FACE_GAIN)
	assert_gt(net.size.x, span.x, "ihre Zellen sind so groß wie die Flächen der Würfel")
	assert_gt(net.size.y, span.y)
	assert_almost_eq(net.end.y, podium.end.y, 0.01, "unten bündig im Platz")
	assert_almost_eq(net.get_center().x, podium.get_center().x, 0.01, "mittig")
	assert_almost_eq(net.position.y, plate.end.y + U * WorkshopView.STREET_GAP, 0.01,
		"eine Naht unter der Platte")
	assert_true(podium.grow(0.05).encloses(plate) and podium.grow(0.05).encloses(net),
		"beides im Platz")

## Reicht die Pool-Höhe nicht, schrumpft die Zelle - die Kammer bleibt so hoch.
func test_a_short_pool_shrinks_the_die_view_not_the_chamber() -> void:
	var short := Rect2(POOL.position, Vector2(POOL.size.x, 420.0))
	var small := WorkshopView.drum_layout(short, CARD, FACE, U, 0.0, SEAM)
	assert_lte((small["podium"] as Rect2).size.y, 420.01)
	assert_almost_eq((small["chamber"] as Rect2).size.y, (lay["chamber"] as Rect2).size.y, 0.01)
	assert_lt((small["podium_net"] as Rect2).size.y, (lay["podium_net"] as Rect2).size.y)
	assert_eq((small["upgrades"] as Rect2).size, (small["podium_net"] as Rect2).size)

func test_the_plate_is_as_wide_as_the_die_view() -> void:
	var plate: Rect2 = lay["podium_stage"]
	var net: Rect2 = lay["podium_net"]
	assert_almost_eq(plate.size.x, net.size.x, 0.01)
	assert_almost_eq(plate.position.x, net.position.x, 0.01)

## Die Leiterbahnen: je Scheibe eine, vom Nummern-Rand ins UPGRADES-Netz, kreuzungsfrei.
func test_the_traces_run_from_each_slice_into_the_upgrades_net() -> void:
	var band: Rect2 = lay["trace_band"]
	var upgrades: Rect2 = lay["upgrades"]
	var paths := WorkshopView.trace_paths(lay["slices"], upgrades, band)
	assert_eq(paths.size(), WorkshopView.DRUM_SLICES)
	assert_gte(band.position.y, POOL.end.y, "das Spur-Band liegt unter dem Pool")
	for i in paths.size():
		var path: PackedVector2Array = paths[i]
		var first := path[0]
		var last := path[path.size() - 1]
		assert_almost_eq(first.x, (lay["slices"][i] as Rect2).get_center().x, 0.01)
		assert_almost_eq(last.y, upgrades.end.y, 0.01, "sie endet an der Netz-Unterkante")
		assert_between(last.x, upgrades.position.x, upgrades.end.x)
		for k in range(1, path.size() - 1):
			assert_between(path[k].y, band.position.y, band.end.y, "die Spur bleibt im Band")
	for a in paths.size():
		for b in range(a + 1, paths.size()):
			assert_false(_cross(paths[a], paths[b]), "Bahn %d kreuzt Bahn %d nicht" % [a + 1, b + 1])

func _cross(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for i in a.size() - 1:
		for k in b.size() - 1:
			if Geometry2D.segment_intersects_segment(a[i], a[i + 1], b[k], b[k + 1]) != null:
				return true
	return false
