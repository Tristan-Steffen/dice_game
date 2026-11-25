extends GutTest
## Die Layout-Kette der Werkstatt (Layout E): gemessene Eingaben, 1280 × 720. Rechts am
## Pool die VORSCHAU samt PRÄGEN, darunter der INFO-SCHIRM; unter dem Pool die Walze mit
## sechs Scheiben, an ihrem Ende UPGRADES, darüber "+" und das PODEST; darunter das Magazin,
## dessen Gruben auf der Hub-Unterkante enden.

const POOL := Rect2(2916.4, 1994.8, 585.0, 487.5)
const CARD := Vector2(194.4, 129.6)
const FACE := 55.46
const U := 5.042
const HUB_BOTTOM := 3127.3
const DISPLAY := Vector2(5094.0, 3180.0)

var lay: Dictionary

func before_each() -> void:
	lay = WorkshopView.drum_layout(POOL, CARD, FACE, U, HUB_BOTTOM)

func _numbers() -> float:
	return U * (WorkshopView.SLICE_NUMBER_UNITS + WorkshopView.SLICE_NUMBER_GAP)

func test_the_drum_lies_under_the_pool_left_aligned() -> void:
	var pit: Rect2 = lay["pit"]
	assert_almost_eq(pit.position.x, POOL.position.x, 0.01, "linksbündig mit dem Pool")
	assert_gte(pit.position.y - _numbers(), POOL.end.y, "die Nummern stehen unter dem Pool")

func test_six_slices_run_left_to_right_inside_pit() -> void:
	var slices: Array = lay["slices"]
	var pit: Rect2 = lay["pit"]
	assert_eq(WorkshopView.DRUM_SLICES, 6)
	assert_eq(WorkshopView.DRUM_SLICES, GameRun.SERIES_SLOT_CAP, "eine Scheibe je Serien-Platz")
	assert_eq(DrumView.SLICES, WorkshopView.DRUM_SLICES)
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

## Die Walze steht mittig zwischen Pool und Magazin: dieselbe Fuge über den Nummern wie
## unter dem Graben (Spieler-Wunsch 2026-11-25), und UPGRADES endet nie unter der Walze.
func test_the_drum_sits_midway_between_pool_and_magazine() -> void:
	var tall := Rect2(POOL.position, Vector2(661.5, 551.25))
	var big := WorkshopView.drum_layout(tall, CARD, 62.67, 5.697, HUB_BOTTOM)
	var pit: Rect2 = big["pit"]
	var shelf: Rect2 = big["shelf"]
	var above := pit.position.y - 5.697 * (WorkshopView.SLICE_NUMBER_UNITS
		+ WorkshopView.SLICE_NUMBER_GAP) - tall.end.y
	assert_almost_eq(above, shelf.position.y - pit.end.y, 0.01, "gleiche Fuge oben wie unten")
	assert_gt(above, 0.0)
	assert_lte((big["upgrades"] as Rect2).end.y, pit.end.y + 0.01, "UPGRADES endet mit der Walze")
	assert_eq((big["upgrades"] as Rect2).size, (big["preview"] as Rect2).size, "alle Die-Views gleich")

## UPGRADES am rechten Walzen-Ende, die Strecke des Eingangs-Busses daneben, senkrecht
## mittig zum Graben.
func test_upgrades_sit_at_the_drum_end() -> void:
	var pit: Rect2 = lay["pit"]
	var upgrades: Rect2 = lay["upgrades"]
	assert_almost_eq(upgrades.position.x - pit.end.x, U * WorkshopView.ENTRY_BUS_UNITS, 0.01,
		"der Eingangs-Bus zwischen Grabenwand und UPGRADES")
	assert_lt(absf(upgrades.get_center().y - pit.get_center().y), 10.0, "etwa mittig zum Graben")
	assert_lte(upgrades.end.y, pit.end.y + 0.01, "und nie unter ihn")
	assert_eq(upgrades.size, (lay["podium_net"] as Rect2).size, "Netz-Maß wie ORIGINAL")

## Das PODEST genau über UPGRADES, oben bündig mit dem Pool, dazwischen das breite "+".
func test_the_podium_stands_over_upgrades() -> void:
	var podium: Rect2 = lay["podium"]
	var upgrades: Rect2 = lay["upgrades"]
	var net: Rect2 = lay["podium_net"]
	var signs: Array = lay["signs"]
	assert_eq(signs.size(), 1, "nur das +")
	var plus: Rect2 = signs[0]
	assert_almost_eq(podium.position.y, POOL.position.y, 0.01, "oben bündig mit dem Pool")
	assert_almost_eq(net.position.x, upgrades.position.x, 0.01, "gleiche x-Kanten")
	assert_almost_eq(net.end.x, upgrades.end.x, 0.01)
	assert_lt(net.end.y, plus.position.y, "+ unter der Die-View")
	assert_lt(plus.end.y, upgrades.position.y, "UPGRADES unter dem +")
	assert_gte(plus.size.y, U * WorkshopView.EQ_SIGN_UNITS - 0.01, "das Feld behält seine Höhe")
	assert_gte(plus.size.x, net.size.x - 0.01, "so breit wie die Netze")
	assert_false(lay.has("result"), "ERGEBNIS ist gestorben")
	assert_eq(lay["original"], net, "ORIGINAL IST die Die-View")

## VORSCHAU eine Fuge rechts am Pool, oben bündig; PRÄGEN mittig zu ihr und mittig im
## Feld zwischen Vorschau und Podest (über dem Info-Schirm).
func test_preview_then_stamp_in_the_head_row() -> void:
	var preview: Rect2 = lay["preview"]
	var stamp: Rect2 = lay["stamp"]
	assert_almost_eq(preview.position.x, POOL.end.x + U * WorkshopView.DRUM_SHELF_GAP, 0.01)
	assert_almost_eq(preview.position.y, POOL.position.y, 0.01, "oben bündig")
	assert_eq(preview.size, (lay["podium_net"] as Rect2).size, "Netz-Maß")
	assert_lt(POOL.end.x, preview.position.x)
	assert_lt(preview.end.x, stamp.position.x, "PRÄGEN rechts der Vorschau")
	assert_almost_eq(stamp.get_center().y, preview.get_center().y, 0.01, "mittig zu ihr")
	assert_gte(stamp.size.x, U * WorkshopView.ACTION_WIDTH - 0.01)
	var info: Rect2 = lay["info"]
	assert_almost_eq(stamp.get_center().x, (preview.end.x + info.end.x) * 0.5, 0.01,
		"mittig im Feld bis vor das Podest")

## Der INFO-SCHIRM: ein Block eine Fuge unter Vorschau und Prägen, links ab der Vorschau,
## rechts bündig mit dem Graben und bis zur Pool-Unterkante.
func test_the_info_is_a_block_under_preview_and_stamp() -> void:
	var info: Rect2 = lay["info"]
	var preview: Rect2 = lay["preview"]
	var podium: Rect2 = lay["podium"]
	assert_almost_eq(info.position.x, preview.position.x, 0.01)
	assert_gt(info.position.y, preview.end.y, "unter der Vorschau")
	assert_gt(info.position.y, (lay["stamp"] as Rect2).end.y, "und unter PRÄGEN")
	assert_almost_eq(info.end.y, POOL.end.y, 0.01, "bis zur Pool-Unterkante")
	assert_almost_eq(info.end.x, (lay["pit"] as Rect2).end.x, 0.01, "rechts bündig mit dem Graben")
	assert_lt(info.end.x, podium.position.x, "vor dem Podest")
	assert_almost_eq(info.position.y - preview.end.y, U * WorkshopView.DRUM_SHELF_GAP, 0.01,
		"eine Fuge unter der Vorschau")
	assert_gt(info.size.x, 600.0, "ein breiter Block")
	assert_gt(info.size.y, 200.0, "und ein hoher")

func test_the_chamber_is_the_podium_plate() -> void:
	var chamber: Rect2 = lay["chamber"]
	var plate: Rect2 = lay["podium_stage"]
	assert_true(chamber.is_equal_approx(plate), "die Grube ist so groß wie die Platte")
	assert_gte(chamber.size.x, WorkshopView.chamber_side_px(FACE, U), "Platz für die Kabel")
	assert_gte(chamber.get_center().y - plate.position.y,
		WorkshopView.PODIUM_TILT_TRIM + FACE * WorkshopView.PODIUM_HEAD_FACES,
		"oben Platz für den schwebenden Würfel")
	assert_false(chamber.intersects(lay["podium_net"]), "die Die-View liegt frei")
	for key in ["pit", "stamp", "shelf", "info", "upgrades", "preview"]:
		assert_false(chamber.intersects(lay[key]), "die Kammer liegt nicht auf %s" % key)
	assert_false(chamber.intersects(POOL), "und nicht im Pool")

## Das Magazin rückt so tief, daß die Unterkante der GRUBEN auf der Hub-Unterkante liegt;
## Fassung und Lichtleisten bleiben auf der Anzeige.
func test_the_shelf_pits_end_on_the_hub_bottom() -> void:
	var shelf: Rect2 = lay["shelf"]
	var columns: Array = lay["columns"]
	for c: Rect2 in columns:
		assert_almost_eq(c.end.y, HUB_BOTTOM, 0.01, "Gruben bündig mit dem Hub")
	assert_lte(shelf.end.y, DISPLAY.y, "über dem Displayrand")
	assert_gte(shelf.position.y - (lay["pit"] as Rect2).end.y,
		U * WorkshopView.DRUM_SHELF_GAP - 0.01, "mindestens eine Fuge unter der Walze")

func test_without_floor_the_shelf_hangs_one_gap_below() -> void:
	var free := WorkshopView.drum_layout(POOL, CARD, FACE, U)
	assert_almost_eq((free["shelf"] as Rect2).position.y - (free["pit"] as Rect2).end.y,
		U * WorkshopView.DRUM_SHELF_GAP, 0.01)

func test_shelf_spans_four_columns_of_two_cards() -> void:
	var shelf: Rect2 = lay["shelf"]
	assert_almost_eq(shelf.position.x, POOL.position.x, 0.01, "linksbündig")
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

## Vier TRAYS samt Fassung: sie überlappen nicht, zwischen ihnen derselbe Filz.
func test_the_shelf_is_four_trays() -> void:
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

## Kein Rechteck der Kette überdeckt ein anderes.
func test_no_two_parts_overlap() -> void:
	var parts := {
		"pit": (lay["pit"] as Rect2).grow_individual(0.0, _numbers(), 0.0, 0.0),
		"info": lay["info"], "shelf": lay["shelf"], "preview": lay["preview"],
		"upgrades": lay["upgrades"], "plate": lay["podium_stage"], "net": lay["podium_net"],
		"stamp": lay["stamp"], "plus": lay["signs"][0], "pool": POOL}
	var keys := parts.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Rect2 = parts[keys[i]]
			var b: Rect2 = parts[keys[j]]
			assert_false(a.intersection(b).get_area() > 1.0,
				"%s und %s überlappen nicht" % [keys[i], keys[j]])

func test_everything_stays_on_the_display() -> void:
	var bounds: Rect2 = lay["bounds"]
	assert_lte(bounds.end.x, DISPLAY.x, "nichts über den Displayrand")
	assert_lte(bounds.end.y, DISPLAY.y)
	assert_gte(bounds.position.y, POOL.end.y, "und nichts in den Pool")
	assert_lte((lay["equation"] as Rect2).end.x, DISPLAY.x)
	var equation: Rect2 = (lay["equation"] as Rect2).grow(0.05)
	for key in ["preview", "stamp", "info", "podium", "upgrades"]:
		assert_true(equation.encloses(lay[key]), "die Gleichung umfaßt %s" % key)

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
	assert_lte(podium.size.y, POOL.size.y + 0.01, "höchstens so hoch wie die Pool-Reihe")

## Reicht die Pool-Höhe nicht, schrumpft die Zelle - die Kammer bleibt so hoch.
func test_a_short_pool_shrinks_the_die_view_not_the_chamber() -> void:
	var short := Rect2(POOL.position, Vector2(POOL.size.x, 420.0))
	var small := WorkshopView.drum_layout(short, CARD, FACE, U)
	assert_lte((small["podium"] as Rect2).size.y, 420.01)
	assert_almost_eq((small["chamber"] as Rect2).size.y, (lay["chamber"] as Rect2).size.y, 0.01)
	assert_lt((small["podium_net"] as Rect2).size.y, (lay["podium_net"] as Rect2).size.y)
	assert_eq((small["upgrades"] as Rect2).size, (small["podium_net"] as Rect2).size)

func test_the_plate_is_as_wide_as_the_die_view() -> void:
	var plate: Rect2 = lay["podium_stage"]
	var net: Rect2 = lay["podium_net"]
	assert_almost_eq(plate.size.x, net.size.x, 0.01)
	assert_almost_eq(plate.position.x, net.position.x, 0.01)

## Der EINGANGS-BUS: vier gerade Spuren von der rechten Grabenwand in die linke Kante von
## UPGRADES.
func test_the_entry_bus_runs_from_the_drum_into_upgrades() -> void:
	var pit: Rect2 = lay["pit"]
	var upgrades: Rect2 = lay["upgrades"]
	var paths := WorkshopView.entry_paths(pit, upgrades, WorkshopView.TRACE_LANES, U * 1.3)
	assert_eq(paths.size(), WorkshopView.TRACE_LANES)
	for path in paths:
		assert_almost_eq(path[0].x, pit.end.x, 0.01, "an der Grabenwand")
		assert_almost_eq(path[path.size() - 1].x, upgrades.position.x, 0.01, "an UPGRADES")
		assert_almost_eq(path[0].y, path[1].y, 0.001, "waagerecht")
		assert_between(path[0].y, pit.position.y, pit.end.y)
	_assert_no_crossing(paths)

## Der AUSGANGS-BUS: vier gerade Spuren aus der Oberkante von UPGRADES durch das "+" in
## die Unterkante der Die-View des Podests.
func test_the_feed_bus_runs_up_into_the_die_view() -> void:
	var upgrades: Rect2 = lay["upgrades"]
	var net: Rect2 = lay["podium_net"]
	var plus: Rect2 = lay["signs"][0]
	var paths := WorkshopView.feed_paths(upgrades, net, WorkshopView.TRACE_LANES, U * 1.3)
	assert_eq(paths.size(), WorkshopView.TRACE_LANES)
	for path in paths:
		assert_almost_eq(path[0].y, upgrades.position.y, 0.01)
		assert_almost_eq(path[path.size() - 1].y, net.end.y, 0.01)
		assert_almost_eq(path[0].x, path[1].x, 0.001, "senkrecht")
		assert_between(path[0].x, plus.position.x, plus.end.x, "durch das +-Feld")
	_assert_no_crossing(paths)

func _assert_no_crossing(paths: Array[PackedVector2Array]) -> void:
	for a in paths.size():
		for b in range(a + 1, paths.size()):
			assert_false(_cross(paths[a], paths[b]), "Spur %d kreuzt Spur %d nicht" % [a, b])

func _cross(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for i in a.size() - 1:
		for k in b.size() - 1:
			if Geometry2D.segment_intersects_segment(a[i], a[i + 1], b[k], b[k + 1]) != null:
				return true
	return false
