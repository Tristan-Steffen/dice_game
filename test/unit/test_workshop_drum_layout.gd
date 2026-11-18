extends GutTest
## Die Layout-Kette der WALZE (V1): gemessene Eingaben vom 2026-11-18, 1280 × 720.

const POOL := Rect2(2916.4, 1994.8, 585.0, 487.5)
const FACH := Rect2(3553.9, 1994.8, 86.3, 86.2)
const CARD := Vector2(194.4, 129.6)
const FACE := 55.46
const U := 5.042
const HUB_BOTTOM := 3127.3
## WorkshopInfoView.height_for(U), gemessen.
const INFO_H := 149.85

var lay: Dictionary

func before_each() -> void:
	lay = WorkshopView.drum_layout(POOL, FACH, CARD, FACE, U, INFO_H)

func test_info_keeps_its_height_and_shelf_moves_down() -> void:
	var info: Rect2 = lay["info"]
	var shelf: Rect2 = lay["shelf"]
	var first: Rect2 = lay["slices"][0]
	assert_almost_eq(info.size.y, INFO_H, 0.01)
	assert_gt(shelf.position.y, first.position.y)
	var bare := WorkshopView.drum_layout(POOL, FACH, CARD, FACE, U)
	assert_almost_eq((bare["shelf"] as Rect2).position.y, first.position.y, 0.01)

func test_column_starts_right_of_fach_at_pool_top() -> void:
	var pit: Rect2 = lay["pit"]
	var before: Rect2 = lay["before"]
	assert_gt(pit.position.x, FACH.end.x)
	assert_almost_eq(before.position.y, POOL.position.y, 0.01)

func test_slices_run_top_down_inside_pit() -> void:
	var slices: Array = lay["slices"]
	var pit: Rect2 = lay["pit"]
	assert_eq(slices.size(), WorkshopView.DRUM_SLICES)
	for i in slices.size():
		var s: Rect2 = slices[i]
		assert_true(pit.encloses(s), "Scheibe %d im Graben" % (i + 1))
		if i > 0:
			assert_gt(s.position.y, (slices[i - 1] as Rect2).end.y)

func test_drum_fits_on_edge() -> void:
	var pit: Rect2 = lay["pit"]
	assert_gt(pit.size.x, WorkshopView.drum_side_px(CARD) * sqrt(2.0))

func test_nets_frame_the_column() -> void:
	var before: Rect2 = lay["before"]
	var after: Rect2 = lay["after"]
	var pit: Rect2 = lay["pit"]
	assert_lt(before.end.y, pit.position.y)
	assert_gt(after.position.y, pit.end.y)
	assert_eq(before.size, CARD)
	assert_eq(after.size, CARD)

func test_column_ends_above_hub_bottom() -> void:
	var bounds: Rect2 = lay["bounds"]
	assert_lt(bounds.end.y, HUB_BOTTOM)

func test_shelf_right_of_pit_and_rows_inside() -> void:
	var shelf: Rect2 = lay["shelf"]
	assert_gt(shelf.position.x, (lay["pit"] as Rect2).end.x)
	var rows: Array = lay["rows"]
	assert_eq(rows.size(), PackDrawerView.ROWS)
	for r: Rect2 in rows:
		assert_true(shelf.encloses(r))
		assert_gt(r.size.x, CARD.x * float(PackDrawerView.COLUMNS))
		assert_gt(r.size.y, CARD.y, "die liegende Karte paßt in ihre Reihe")

func test_info_above_shelf_and_chamber_below() -> void:
	var shelf: Rect2 = lay["shelf"]
	var info: Rect2 = lay["info"]
	var chamber: Rect2 = lay["chamber"]
	var stamp: Rect2 = lay["stamp"]
	assert_lt(info.end.y, shelf.position.y)
	assert_gt(chamber.position.y, shelf.end.y)
	assert_gt(stamp.position.x, chamber.end.x)
	assert_almost_eq(stamp.get_center().y, chamber.get_center().y, 0.01)
