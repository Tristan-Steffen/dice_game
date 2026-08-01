extends GutTest
## Plätze tauschen im Vorrat. ANORDNUNG, nicht Ersetzung: die Würfel wandern
## mitsamt ihrer Identität, ihr Inhalt wird nie überschrieben - become gilt nur
## beim Ersetzen. Daran hängt, dass instanz-gebundener Zustand am richtigen
## Würfel bleibt.

func test_reorder_swaps_the_two_places() -> void:
	var run := GameRun.new_run()
	var a := run.owned_pool[0]
	var b := run.owned_pool[4]
	assert_true(run.reorder_pool(0, 4))
	assert_same(run.owned_pool[4], a, "A liegt jetzt auf Platz 4")
	assert_same(run.owned_pool[0], b, "und B auf Platz 0")

func test_the_instances_keep_their_identity() -> void:
	# Genau daran hängt der Xenon-/Kugelblitz-Zustand (nach get_instance_id).
	var run := GameRun.new_run()
	var ids := []
	for die in run.owned_pool:
		ids.append(die.get_instance_id())
	run.reorder_pool(2, 7)
	var after := []
	for die in run.owned_pool:
		after.append(die.get_instance_id())
	ids.sort()
	after.sort()
	assert_eq(after, ids, "dieselben Instanzen, nur an anderen Plätzen")

func test_the_contents_are_never_rewritten() -> void:
	var run := GameRun.new_run()
	run.owned_pool[1].essence_id = Essence.NEON
	run.owned_pool[3].essence_id = Essence.ARGON
	run.reorder_pool(1, 3)
	assert_eq(run.owned_pool[3].essence_id, Essence.NEON, "die Seele reist mit")
	assert_eq(run.owned_pool[1].essence_id, Essence.ARGON)

func test_reorder_reports_the_change_once() -> void:
	var run := GameRun.new_run()
	var emits := []
	run.pool_changed.connect(func() -> void: emits.append(1))
	run.reorder_pool(0, 1)
	assert_eq(emits.size(), 1, "ein Tausch, ein Signal")

func test_a_pointless_or_impossible_reorder_is_a_no_op() -> void:
	var run := GameRun.new_run()
	var emits := []
	run.pool_changed.connect(func() -> void: emits.append(1))
	assert_false(run.reorder_pool(3, 3), "auf sich selbst ist kein Tausch")
	assert_false(run.reorder_pool(-1, 2), "kein Platz unter null")
	assert_false(run.reorder_pool(0, 999), "und keiner hinter dem Ende")
	assert_eq(emits.size(), 0, "und nichts davon meldet sich")

func test_the_order_is_the_draw_order_and_stays_put() -> void:
	# Die Vorrats-Reihenfolge IST die Ziehreihenfolge - sie wird nirgends
	# nachträglich normalisiert.
	var run := GameRun.new_run()
	var first := run.owned_pool[0]
	run.reorder_pool(0, 9)
	run.note_pool_changed()
	assert_same(run.owned_pool[9], first, "ein Refresh ordnet nichts um")

# --- Das Raster: Umlegen ist eine BEWUSSTE Freischaltung ----------------------------

func _grid(enabled: bool) -> DiceGridView:
	var grid := DiceGridView.new()
	grid.reorder_enabled = enabled
	add_child_autofree(grid)
	grid.place(3, 8.0, false)
	var defs: Array[DieDefinition] = []
	for i in 6:
		defs.append(DieDefinition.standard())
	grid.fill(defs)
	return grid

func test_the_grid_does_not_reorder_by_default() -> void:
	# Die Tausch-Auswahl des Ladens ist dasselbe Raster in anderer Rolle - dort
	# wäre eine Zieh-Geste ein zweiter, ungewollter Weg in den Vorrat.
	var grid := _grid(false)
	await wait_frames(2)
	assert_false(grid.reorder_enabled, "voreingestellt AUS")
	var seen := []
	grid.slots_reordered.connect(func(a: int, b: int) -> void: seen.append([a, b]))
	grid._on_tile_input(_press(true), 0)
	grid._on_tile_input(_press(false), 1)
	assert_eq(seen.size(), 0, "ohne Freischaltung passiert nichts")

func test_an_enabled_grid_reports_the_two_places() -> void:
	var grid := _grid(true)
	await wait_frames(2)
	var seen := []
	grid.slots_reordered.connect(func(a: int, b: int) -> void: seen.append([a, b]))
	grid._on_tile_input(_press(true), 0)
	# Der Knopf fängt die Maus - das Ziel kommt aus der Zeigerposition.
	var release := _press(false)
	release.global_position = grid.tiles[4].get_global_rect().get_center()
	grid._on_tile_input(release, 0)
	assert_eq(seen, [[0, 4]], "Ausgang und Ziel")

func test_dropping_on_the_same_tile_reorders_nothing() -> void:
	var grid := _grid(true)
	await wait_frames(2)
	var seen := []
	grid.slots_reordered.connect(func(a: int, b: int) -> void: seen.append([a, b]))
	grid._on_tile_input(_press(true), 2)
	var release := _press(false)
	release.global_position = grid.tiles[2].get_global_rect().get_center()
	grid._on_tile_input(release, 2)
	assert_eq(seen.size(), 0, "ein Klick bleibt ein Klick")

func _press(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event

func test_slot_at_finds_the_tile_under_the_pointer() -> void:
	var grid := _grid(true)
	await wait_frames(2)
	assert_eq(grid.slot_at(grid.tiles[3].get_global_rect().get_center()), 3)
	assert_eq(grid.slot_at(Vector2(-500, -500)), -1, "daneben ist kein Platz")
