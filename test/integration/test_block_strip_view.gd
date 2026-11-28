extends GutTest
## Der BLOCK-STREIFEN der Hub-Startseite (BlockStripView): Hitze-Pegel und sechs Stops
## aus GameRun.block_strip_state.

var view: BlockStripView
var run: GameRun

func before_each() -> void:
	view = add_child_autofree(BlockStripView.new())
	view.unit_px = 10.0
	view.size = Vector2(970, 170)
	run = GameRun.new_run()

func test_six_stops_in_one_row() -> void:
	view.set_state(run.block_strip_state())
	var rects := view.stop_rects()
	assert_eq(rects.size(), GameRun.GOAL_BLOCK)
	for i in range(1, rects.size()):
		assert_almost_eq(rects[i].position.y, rects[0].position.y, 0.01, "eine Reihe")
		assert_false(rects[i].intersects(rects[i - 1]))
		assert_true(Rect2(Vector2.ZERO, view.size).encloses(rects[i]))
	assert_false(view.meter_rect().intersects(rects[0]), "der Pegel liegt darüber")

func test_the_meter_has_five_fields_and_white_heat_behind() -> void:
	view.set_state(run.block_strip_state())
	var cells := view.meter_cells()
	assert_eq(cells.size(), GameRun.HEAT_WHITE, "fünf Felder plus Weißglut")
	for i in range(1, cells.size()):
		assert_gt(cells[i].position.x, cells[i - 1].end.x - 0.01)

func test_stop_lines_name_blind_pick_and_boss() -> void:
	run.heat = 2
	run.roll_route_offers()
	run.take_route(2)
	run.advance_round()
	var stops: Array = run.block_strip_state()["stops"]
	var done := BlockStripView.stop_lines(stops[0])
	assert_eq(done[0], "Runde 1")
	assert_eq(done[1], BigNumber.short(int(stops[0]["blind"])))
	assert_eq(done[2], "heißer")
	var boss := BlockStripView.stop_lines(stops[5])
	assert_eq(boss[0], BlockStripView.BOSS_NAME)
	assert_eq(boss[2], BlockStripView.BOSS_PAYS)

func test_done_stops_wear_the_colour_of_their_heat() -> void:
	run.heat = 2
	run.roll_route_offers()
	run.take_route(2)
	run.advance_round()
	view.set_state(run.block_strip_state())
	var stops := view.stops()
	assert_eq(view.stop_color(stops[0]), HeatStyle.color(3))
	assert_eq(view.stop_color(stops[1]), HeatStyle.color(run.heat), "der laufende in der Hitze von jetzt")
	assert_eq(view.stop_color(stops[2]), HeatStyle.MUTED_COLOR, "kommende gedämpft")
	assert_eq(view.stop_color(stops[5]), HeatStyle.BOSS_COLOR)

func test_the_pick_words_come_from_one_source() -> void:
	assert_eq(HeatStyle.pick_word(GameRun.PICK_COOL), "kühler")
	assert_eq(HeatStyle.pick_word(GameRun.PICK_KEEP), "gleich")
	assert_eq(HeatStyle.pick_word(GameRun.PICK_HOT), "heißer")
	for level in range(1, GameRun.HEAT_WHITE + 1):
		assert_ne(HeatStyle.level_name(level), "")

func test_it_draws_without_errors() -> void:
	run.heat = 4
	view.set_state(run.block_strip_state())
	await wait_frames(2)
	assert_eq(view.heat(), 4)
