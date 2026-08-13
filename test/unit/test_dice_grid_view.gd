extends GutTest
## Tests des gemeinsamen Würfel-Rasters (DiceGridView): je Platz eine Kachel mit
## Augensumme, leere Plätze bleiben stumm, Klick meldet den Index.

var grid: DiceGridView

func before_each() -> void:
	grid = DiceGridView.new()
	add_child_autofree(grid)
	grid.place(6, 8.0)

func _die(faces: Array, style := "normal", essence := "") -> DieDefinition:
	var def := DieDefinition.new()
	var typed: Array[int] = []
	typed.assign(faces)
	def.faces = typed
	def.style_id = style
	def.essence_id = essence
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

func test_tooltip_names_faces_and_the_essence() -> void:
	grid.fill(_defs([_die([3, 1, 2, 6, 5, 4], "power", Essence.NEON)]))
	var tip: String = grid.tiles[0].tooltip_text
	assert_string_contains(tip, "1 2 3 4 5 6", "Seiten aufsteigend")
	assert_string_contains(tip, "Augensumme 21")
	assert_string_contains(tip, Essence.by_id(Essence.NEON).display_name, "die Seele steht dabei")

# --- Essenz-Sichtbarkeit: die Seele muss im 30er-Raster auffallen -------------

func test_a_souled_tile_wears_a_thicker_glowing_seam() -> void:
	grid.fill(_defs([_die([1, 2, 3, 4, 5, 6]),
		_die([1, 2, 3, 4, 5, 6], "normal", Essence.NEON)]))
	var plain: StyleBoxFlat = grid.tiles[0].get_theme_stylebox("normal")
	var souled: StyleBoxFlat = grid.tiles[1].get_theme_stylebox("normal")
	assert_gt(souled.border_width_left, plain.border_width_left, "dickerer Saum")
	assert_gt(souled.shadow_size, 0, "und ein Außenschein")
	assert_eq(plain.shadow_size, 0, "den der gewöhnliche Würfel nicht hat")
	assert_ne(souled.bg_color, plain.bg_color, "der Grund ist getönt")
	assert_almost_eq(souled.bg_color.a, plain.bg_color.a, 0.001, "bei gleicher Deckkraft")

func test_the_highlight_keeps_gold_but_the_soul_keeps_its_width() -> void:
	grid.fill(_defs([_die([1, 2, 3, 4, 5, 6], "normal", Essence.NEON)]), 0)
	var box: StyleBoxFlat = grid.tiles[0].get_theme_stylebox("normal")
	assert_eq(box.border_color, DiceGridView.GOLD, "das Ziel bleibt gold umrandet")
	assert_gt(box.border_width_left, maxi(1, int(grid.u * DiceGridView.PLAIN_BORDER_U)),
		"die Saum-Dicke der Seele bleibt trotzdem")

# --- Seelen-Auskunft beim Überfahren einer Kachel -----------------------------

func test_hovering_a_souled_tile_names_its_essence() -> void:
	grid.fill(_defs([_die([1, 2, 3, 4, 5, 6], "normal", Essence.NEON)]))
	await wait_frames(2)
	var hint := grid.hint_at(grid.tiles[0].get_global_rect().get_center())
	assert_string_contains(hint, Essence.by_id(Essence.NEON).display_name,
		"die überfahrene Kachel nennt ihre Seele")
	assert_eq(hint, Essence.hint(Essence.NEON),
		"und zwar aus derselben Quelle wie der Essenz-Chip im Netz")

func test_a_soulless_tile_says_nothing() -> void:
	grid.fill(_defs([_die([1, 2, 3, 4, 5, 6])]))
	await wait_frames(2)
	assert_eq(grid.hint_at(grid.tiles[0].get_global_rect().get_center()), "",
		"ohne Seele gibt es nichts zu sagen")

func test_empty_slots_and_the_space_outside_stay_silent() -> void:
	grid.fill(_defs([null, _die([1, 2, 3, 4, 5, 6], "normal", Essence.NEON)]))
	await wait_frames(2)
	var placeholder: Control = grid.get_child(0)
	assert_eq(grid.hint_at(placeholder.get_global_rect().get_center()), "",
		"der leere Platz bleibt stumm")
	assert_eq(grid.hint_at(Vector2(-100, -100)), "", "außerhalb des Rasters ebenso")
	assert_ne(grid.hint_at(grid.tiles[1].get_global_rect().get_center()), "",
		"der beseelte Nachbar spricht trotzdem")

# --- Detail-Kacheln: dieselbe Darstellung wie im Netzfeld der Grube -----------

func _detail_grid() -> DiceGridView:
	var detail := DiceGridView.new()
	add_child_autofree(detail)
	detail.place(6, 8.0, true)
	return detail

## Alle Nachfahren der Kachel, die Zellen des Würfelnetzes sein könnten.
func _net_of(tile: Button) -> Control:
	for child in tile.get_child(0).get_children():
		if child.name != "" and child is Control and not (child is Label):
			return child
	return null

func test_detail_tiles_draw_the_die_net() -> void:
	var detail := _detail_grid()
	var def := _die([1, 2, 3, 4, 5, 6], "normal", Essence.NEON)
	detail.fill(_defs([def]))
	await wait_frames(2)
	var net := _net_of(detail.tiles[0])
	assert_not_null(net, "die Kachel trägt ein Würfelnetz")
	assert_almost_eq(net.size, DieNetView.net_size(detail.u * DiceGridView.DETAIL_CELL),
		Vector2.ONE * 0.5, "in Netzmaßen - dieselbe Geometrie wie in der Grube")

func test_detail_tiles_show_pointers() -> void:
	# Der eigentliche Zweck des Wechsels: Pointer sind im Lager sichtbar.
	var detail := _detail_grid()
	var plain := _die([1, 2, 3, 4, 5, 6])
	var wired := _die([1, 2, 3, 4, 5, 6])
	var pointers: Array[int] = [4, -1, -1, -1, -1, -1]
	wired.pointers = pointers
	detail.fill(_defs([plain, wired]))
	await wait_frames(2)
	assert_eq(_arrow_count(_net_of(detail.tiles[0])), 0, "ohne Pointer kein Pfeil")
	assert_eq(_arrow_count(_net_of(detail.tiles[1])), 1, "je Pointer ein Pfeil")

func _arrow_count(net: Control) -> int:
	var count := 0
	for child in net.get_children():
		if child is DieNetView.PointerArrow:
			count += 1
	return count

func test_the_tile_is_derived_from_the_net_not_guessed() -> void:
	var tile := DiceGridView.detail_tile_size(10.0)
	var net := DieNetView.net_size(10.0 * DiceGridView.DETAIL_CELL)
	assert_almost_eq(tile - net, Vector2.ONE * 10.0 * DiceGridView.TILE_PAD * 2.0,
		Vector2.ONE * 0.01, "genau das Netz plus Rand - kein Streifen für die Augensumme")
	assert_gt(tile.x, tile.y, "das Netz ist breit und flach, die Kachel darum auch")

func test_the_eye_total_sits_in_the_free_cross_corner_opposite_the_essence_chip() -> void:
	var detail := _detail_grid()
	detail.fill(_defs([_die([1, 2, 3, 4, 5, 6])]))
	await wait_frames(2)
	var cell := detail.u * DiceGridView.DETAIL_CELL
	var badge: Label = null
	for child in _net_of(detail.tiles[0]).get_children():
		if child is Label and (child as Label).text == "21":
			badge = child
	assert_not_null(badge, "die Augensumme steht im Netz")
	# Der Essenz-Chip sitzt in der Ecke oben LINKS, die Plakette gegenüber.
	assert_gt(badge.position.x, DieNetView.cell_position(3, cell).x,
		"rechts neben der oberen Seite")
	assert_almost_eq(badge.position.y, 0.0, 0.01, "in der obersten Zeile")
