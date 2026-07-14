extends GutTest
## Tier-2-Test gegen Drift zwischen der auf dem Tisch-Display angezeigten
## Kombinationsliste (TableScreen/ComboCellView, Sic-Bo-Layout) und der
## Wertungslogik. Ändert jemand in DiceScoring einen Hand-Namen, ein Beispiel
## oder einen Multiplikator, muss die Bildschirmliste automatisch folgen -
## dieser Test prüft jede Zelle gegen label_for/EXAMPLE_DICE/mult_for.

var screen: TableScreen

func before_each() -> void:
	screen = TableScreen.new()
	add_child_autofree(screen)

func test_every_combo_has_a_cell_matching_scoring():
	for key in DiceScoring.HAND_PRIORITY:
		assert_true(screen.combo_cells.has(key), "Zelle fehlt für '%s'" % key)
		if not screen.combo_cells.has(key):
			continue
		var cell: ComboCellView = screen.combo_cells[key]
		assert_eq(cell.combo_name, DiceScoring.label_for(key))
		assert_eq(cell.values, DiceScoring.EXAMPLE_DICE[key])
		assert_eq(cell.points, DiceScoring.points_for(key))
		assert_eq(cell.mult, DiceScoring.mult_for(key))

func test_cell_count_matches_hand_priority():
	assert_eq(screen.combo_cells.size(), DiceScoring.HAND_PRIORITY.size(),
		"genau eine Zelle je Kombination")

func test_cells_stay_inside_the_screen():
	for key: String in screen.combo_cells:
		var cell: ComboCellView = screen.combo_cells[key]
		assert_true(cell.position.x >= 0.0 and cell.position.y >= 0.0,
			"Zelle '%s' ragt links/oben hinaus" % key)
		assert_true(cell.position.x + cell.size.x <= float(TableScreen.RESOLUTION.x)
			and cell.position.y + cell.size.y <= float(TableScreen.RESOLUTION.y),
			"Zelle '%s' ragt rechts/unten hinaus" % key)