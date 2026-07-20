extends GutTest
## Tests des gemeinsamen Würfel-Rasters (DiceGridView): je Platz eine Kachel mit
## Augensumme, leere Plätze bleiben stumm, Klick meldet den Index.

var grid: DiceGridView

func before_each() -> void:
	grid = DiceGridView.new()
	add_child_autofree(grid)
	grid.place(6, 8.0)

func _die(faces: Array, style := "normal", edge := "") -> DieDefinition:
	var def := DieDefinition.new()
	var typed: Array[int] = []
	typed.assign(faces)
	def.faces = typed
	def.style_id = style
	def.edge_material = edge
	def.display_name = style.capitalize()
	return def

func _defs(list: Array) -> Array[DieDefinition]:
	var out: Array[DieDefinition] = []
	out.assign(list)
	return out

func test_tile_per_slot_shows_the_eye_total() -> void:
	grid.fill(_defs([_die([1, 1, 1, 1, 1, 1]), _die([6, 6, 6, 6, 6, 6])]))
	assert_eq(grid.tiles.size(), 2)
	assert_eq(grid.tiles[0].text, "6", "sechs Einsen = 6")
	assert_eq(grid.tiles[1].text, "36")

func test_empty_slots_stay_silent() -> void:
	grid.fill(_defs([_die([1, 2, 3, 4, 5, 6]), null]))
	assert_eq(grid.tiles.size(), 2)
	assert_null(grid.tiles[1], "leerer Platz hat keine Kachel")
	assert_eq(grid.get_child_count(), 2, "der Platzhalter steht trotzdem im Raster")

func test_pressing_a_tile_reports_its_index() -> void:
	grid.fill(_defs([_die([1, 2, 3, 4, 5, 6]), _die([2, 2, 2, 2, 2, 2])]))
	var pressed: Array[int] = []
	grid.slot_pressed.connect(func(index: int) -> void: pressed.append(index))
	grid.tiles[1].pressed.emit()
	assert_eq(pressed, [1] as Array[int])

func test_highlight_can_move_without_a_rebuild() -> void:
	grid.fill(_defs([_die([1, 2, 3, 4, 5, 6]), _die([1, 2, 3, 4, 5, 6])]), 0)
	var first := grid.tiles[0]
	grid.set_highlight(1)
	assert_same(first, grid.tiles[0], "dieselben Kacheln bleiben stehen")
	assert_eq(grid.tiles[1].get_theme_color("font_color"), DiceGridView.GOLD,
		"das neue Ziel trägt Gold")

func test_tooltip_names_faces_and_edges() -> void:
	grid.fill(_defs([_die([3, 1, 2, 6, 5, 4], "power", DieMaterial.GOLD)]))
	var tip: String = grid.tiles[0].tooltip_text
	assert_string_contains(tip, "1 2 3 4 5 6", "Seiten aufsteigend")
	assert_string_contains(tip, "Augensumme 21")
	assert_string_contains(tip, "Kanten")
