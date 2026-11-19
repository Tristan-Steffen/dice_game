extends GutTest
## Die Layout-Kette der Werkstatt unter dem Pool (Layout A): gemessene Eingaben vom
## 2026-11-18, 1280 × 720.

const POOL := Rect2(2916.4, 1994.8, 585.0, 487.5)
const CARD := Vector2(194.4, 129.6)
const FACE := 55.46
const U := 5.042
const SEAM := 48.75
const HUB_BOTTOM := 3127.3
const DISPLAY_WIDTH := 5094.0
## WorkshopInfoView.height_for(U), gemessen.
const INFO_H := 149.85

var lay: Dictionary

func before_each() -> void:
	lay = WorkshopView.drum_layout(POOL, CARD, FACE, U, INFO_H, SEAM)

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
	assert_almost_eq(WorkshopView.drum_side_px(CARD), CARD.y * (1.0 + WorkshopView.DRUM_AIR),
		0.001, "der Querschnitt mißt an der KURZEN Kartenseite")
	assert_gt(pit.size.y, WorkshopView.drum_side_px(CARD) * sqrt(2.0))

func test_chamber_and_stamp_close_the_drum_row() -> void:
	var pit: Rect2 = lay["pit"]
	var chamber: Rect2 = lay["chamber"]
	var stamp: Rect2 = lay["stamp"]
	assert_gt(chamber.position.x, pit.end.x, "die Kammer am rechten Ende der Walze")
	assert_almost_eq(chamber.position.y, pit.position.y, 0.01, "in derselben Zeile")
	assert_gte(chamber.size.x, CARD.x, "der liegende Rohling paßt hinein")
	assert_gte(chamber.size.y, CARD.y)
	assert_gt(stamp.position.x, chamber.end.x)
	assert_almost_eq(stamp.get_center().y, chamber.get_center().y, 0.01)

func test_shelf_under_the_drum_with_four_columns() -> void:
	var shelf: Rect2 = lay["shelf"]
	assert_almost_eq(shelf.position.x, POOL.position.x, 0.01, "linksbündig")
	assert_gt(shelf.position.y, (lay["pit"] as Rect2).end.y)
	var columns: Array = lay["columns"]
	assert_eq(columns.size(), PackDrawerView.COLUMNS)
	for i in columns.size():
		var c: Rect2 = columns[i]
		assert_true(shelf.encloses(c))
		assert_gt(c.size.x, CARD.x, "die liegende Karte paßt in ihre Spalte")
		assert_gt(c.size.y, CARD.y * float(PackDrawerView.PLACES), "zwei Plätze untereinander")
		if i > 0:
			assert_gt(c.position.x, (columns[i - 1] as Rect2).end.x, "Spalten von links")

func test_the_equation_stands_right_of_the_shelf_with_the_info_above() -> void:
	var shelf: Rect2 = lay["shelf"]
	var info: Rect2 = lay["info"]
	var original: Rect2 = lay["original"]
	var upgrades: Rect2 = lay["upgrades"]
	var result: Rect2 = lay["result"]
	var signs: Array = lay["signs"]
	assert_gt(original.position.x, shelf.end.x)
	assert_almost_eq(info.size.y, INFO_H, 0.01)
	assert_lt(info.end.y, original.position.y, "der Info-Schirm über der Gleichung")
	assert_gt(upgrades.position.x, original.end.x)
	assert_gt(result.position.x, upgrades.end.x)
	assert_eq(original.size, CARD, "drei gleich große Netze")
	assert_eq(upgrades.size, CARD)
	assert_eq(result.size, CARD)
	assert_true((signs[0] as Rect2).position.x >= original.end.x - 0.01, "+ zwischen den ersten")
	assert_true((signs[1] as Rect2).end.x <= result.position.x + 0.01, "= vor dem Ergebnis")
	assert_almost_eq(original.end.y, shelf.end.y, 0.01, "unten bündig mit dem Magazin")
	assert_gt(original.position.x, (lay["chamber"] as Rect2).position.x - CARD.x * 2.0,
		"unter der Kammer")

func test_the_height_fits_under_the_pool() -> void:
	var bounds: Rect2 = lay["bounds"]
	assert_lte(bounds.end.y, HUB_BOTTOM, "nichts reicht unter die Hub-Unterkante")
	assert_lte(bounds.end.x, DISPLAY_WIDTH, "nichts über den Displayrand")
	assert_gte(bounds.position.y, POOL.end.y + SEAM - 0.01, "und nichts in den Pool")

func test_the_podium_stands_right_next_to_the_pool() -> void:
	var podium: Rect2 = lay["podium"]
	assert_almost_eq(podium.position.x, POOL.end.x + U * WorkshopView.DRUM_SHELF_GAP, 0.01,
		"eine Fuge rechts vom Pool")
	assert_almost_eq(podium.position.y, POOL.position.y, 0.01, "auf Pool-Höhe")
	assert_almost_eq(podium.size.x, (lay["podium_net"] as Rect2).size.x, 0.01,
		"so breit wie seine Die-View")
	assert_almost_eq(podium.size.y, U * WorkshopView.PODIUM_PLACE_UNITS.y, 0.01)
	assert_false(podium.intersects(lay["bounds"]), "die Werkstatt berührt ihn nicht")

## Oben die Platte, auf der der Würfel schwebt, unten seine Die-View in Würfelgröße.
func test_the_podium_carries_its_plate_over_its_die_view() -> void:
	var podium: Rect2 = lay["podium"]
	var plate: Rect2 = lay["podium_stage"]
	var net: Rect2 = lay["podium_net"]
	var span := DieNetView.net_size(FACE * WorkshopView.PODIUM_FACE_GAIN)
	assert_gt(net.size.x, span.x, "ihre Zellen sind so groß wie die Flächen der Würfel")
	assert_gt(net.size.y, span.y)
	assert_almost_eq(net.end.y, podium.end.y, 0.01, "unten bündig im Platz")
	assert_almost_eq(net.get_center().x, podium.get_center().x, 0.01, "mittig")
	assert_lt(plate.end.y, net.position.y, "die Platte darüber, eine Fuge davor")
	assert_true(podium.encloses(plate) and podium.encloses(net), "beides im Platz")
	assert_gt(plate.size.y, FACE * WorkshopView.STAGE_FACES, "die Bühne paßt auf die Platte")
