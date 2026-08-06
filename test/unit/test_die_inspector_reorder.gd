extends GutTest
## Umlegen im Würfel-Raster der Gravur-Station: Ziehen greift in denselben
## Vorrat wie am Tray - die Kachel wird am Ziel eingesetzt, die anderen rücken
## auf. Reine Handler-Logik über target_defs, ohne Szenenbaum.

func _view(run: GameRun) -> DieInspectorView:
	var view: DieInspectorView = autofree(DieInspectorView.new())
	view.run = run
	var defs: Array[DieDefinition] = []
	defs.assign(run.owned_pool)
	view.target_defs = defs
	return view

func test_dragging_a_tile_puts_the_die_on_the_target_place() -> void:
	var run := GameRun.new_run()
	var moved := run.owned_pool[0]
	_view(run)._on_target_slots_reordered(0, 3)
	assert_same(run.owned_pool[3], moved, "der Würfel sitzt auf der Zielkachel")

func test_the_others_move_up_the_line() -> void:
	var run := GameRun.new_run()
	var before: Array[DieDefinition] = []
	for die in run.owned_pool:
		before.append(die)
	_view(run)._on_target_slots_reordered(0, 2)
	assert_same(run.owned_pool[0], before[1], "die Lücke schließt sich")
	assert_same(run.owned_pool[1], before[2])
	assert_same(run.owned_pool[2], before[0])

func test_dragging_backwards_works_too() -> void:
	var run := GameRun.new_run()
	var moved := run.owned_pool[5]
	_view(run)._on_target_slots_reordered(5, 1)
	assert_same(run.owned_pool[1], moved)

func test_a_signed_round_locks_the_grid() -> void:
	var run := GameRun.new_run()
	var first := run.owned_pool[0]
	var view := _view(run)
	view.editing_locked = true
	view._on_target_slots_reordered(0, 4)
	assert_same(run.owned_pool[0], first, "nach der Unterschrift steht der Vorrat")

func test_an_empty_tile_is_no_target() -> void:
	var run := GameRun.new_run()
	var first := run.owned_pool[0]
	var view := _view(run)
	view.target_defs[4] = null  # ein leerer Platz im Raster
	view._on_target_slots_reordered(0, 4)
	assert_same(run.owned_pool[0], first, "auf nichts legt man nichts")

func test_places_outside_the_grid_are_ignored() -> void:
	var run := GameRun.new_run()
	var first := run.owned_pool[0]
	var view := _view(run)
	view._on_target_slots_reordered(0, 999)
	view._on_target_slots_reordered(-1, 2)
	assert_same(run.owned_pool[0], first)

func test_without_a_run_nothing_happens() -> void:
	var run := GameRun.new_run()
	var view := _view(run)
	view.run = null
	view._on_target_slots_reordered(0, 3)
	assert_same(run.owned_pool[0], run.owned_pool[0], "kein Absturz ohne Partie")

func test_the_pool_keeps_its_size_and_its_dice() -> void:
	var run := GameRun.new_run()
	var size := run.owned_pool.size()
	_view(run)._on_target_slots_reordered(7, 2)
	assert_eq(run.owned_pool.size(), size)
	var seen := []
	for die in run.owned_pool:
		assert_false(seen.has(die.get_instance_id()), "kein Würfel liegt doppelt")
		seen.append(die.get_instance_id())
