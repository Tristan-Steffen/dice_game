extends GutTest
## Integrationstests der Kondensator-Bank (die physische ⚡-Börse). Sie ist reine
## Anzeige - geprüft wird, dass ihr fester 5×5-Zustand deckungsgleich zu dem ist,
## was scene_root ihr sagt: gesperrt / erwacht / geladen.

func _bank() -> CapacitorBankView:
	var bank := CapacitorBankView.new()
	add_child_autofree(bank)
	return bank

## Zellen-Knoten der Bank in Füllreihenfolge (Cell0..Cell24).
func _cells(bank: CapacitorBankView) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	out.resize(CapacitorBankView.GRID_COLS * CapacitorBankView.GRID_ROWS)
	for child in bank.get_children():
		if child.name.begins_with("Cell"):
			out[int(String(child.name).trim_prefix("Cell"))] = child
	return out

func test_grid_is_always_complete() -> void:
	# Das Raster steht von Anfang an ganz da - der Ausbau ist ein Umfärben,
	# nie ein Umbau (die Bank wächst nicht mehr).
	var bank := _bank()
	bank.set_charge(0, 5)
	assert_eq(_cells(bank).size(), 25, "alle 25 Zellen, unabhängig vom Deckel")
	bank.set_charge(0, 25)
	assert_eq(_cells(bank).size(), 25)
	assert_eq(bank.cap_count(), 25)

func test_three_states_locked_awake_charged() -> void:
	var bank := _bank()
	bank.set_charge(3, 10)
	var cells := _cells(bank)
	var awake: Material = cells[5].material_override
	var locked: Material = cells[24].material_override
	for i in 3:
		assert_ne(cells[i].material_override, awake, "Zelle %d ist geladen (flackert)" % i)
		assert_ne(cells[i].material_override, locked, "Zelle %d ist nicht gesperrt" % i)
	for i in range(3, 10):
		assert_eq(cells[i].material_override, awake, "Zelle %d glimmt leer" % i)
	for i in range(10, 25):
		assert_eq(cells[i].material_override, locked, "Zelle %d ist stromlos" % i)

func test_charged_cells_flicker_independently() -> void:
	# Jede geladene Zelle hat eine EIGENE Material-Instanz - nur so kann sie in
	# ihrem eigenen Takt flackern statt als synchroner Block.
	var bank := _bank()
	bank.set_charge(2, 5)
	var cells := _cells(bank)
	assert_ne(cells[0].material_override, cells[1].material_override,
		"zwei geladene Zellen teilen kein Material")
	assert_true(bank.is_processing(), "geladen: der Puls-Takt läuft")
	bank.set_charge(0, 5)
	assert_false(bank.is_processing(), "leer: kein Takt nötig")

func test_rising_cap_wakes_a_whole_row() -> void:
	var bank := _bank()
	bank.set_charge(0, 5)
	var cells := _cells(bank)
	var locked: Material = cells[24].material_override
	assert_eq(cells[7].material_override, locked, "Reihe 2 schläft noch")
	bank.set_charge(0, 10)  # Hub-Ausbau: die zweite Reihe erwacht
	assert_ne(cells[7].material_override, locked, "Reihe 2 glimmt jetzt")
	assert_eq(cells[12].material_override, locked, "Reihe 3 schläft weiter")

func test_charge_is_clamped_into_the_cap() -> void:
	var bank := _bank()
	bank.set_charge(99, 5)
	assert_eq(bank.charge_count(), 5, "mehr als der Deckel geht nicht")
	bank.set_charge(-4, 5)
	assert_eq(bank.charge_count(), 0)
	bank.set_charge(0, 99)
	assert_eq(bank.cap_count(), 25, "mehr als das Raster gibt es nicht")

## Der Chip-Platz ist 294×93 px (siehe TableScreen.free_cluster_slots): das
## Raster muss dieses Verhältnis fast treffen, sonst bleibt auf der kurzen Achse
## Filz frei - scene_root passt auf die KNAPPERE Achse ein.
const SLOT_ASPECT := 93.0 / 294.0

func test_footprint_matches_the_slot_aspect() -> void:
	var aspect := CapacitorBankView.max_width() / CapacitorBankView.max_length()
	assert_lt(aspect, SLOT_ASPECT, "passt in den Platz, keine Achse quillt über")
	assert_gt(aspect, SLOT_ASPECT * 0.97, "füllt die kurze Achse fast ganz aus")

func test_cells_fill_most_of_the_footprint() -> void:
	# Die Zellen selbst - nicht nur die Platte - müssen den Platz ausfüllen:
	# knappe Ränder, knappe Zellabstände.
	var lit_z := float(CapacitorBankView.GRID_COLS - 1) * CapacitorBankView.CELL_PITCH \
		+ CapacitorBankView.CELL_SIZE.z
	var lit_x := float(CapacitorBankView.GRID_ROWS - 1) * CapacitorBankView.ROW_PITCH \
		+ CapacitorBankView.CELL_SIZE.x
	assert_gt(lit_z / CapacitorBankView.max_length(), 0.93, "Leuchtfläche füllt die Länge")
	assert_gt(lit_x / CapacitorBankView.max_width(), 0.90, "Leuchtfläche füllt die Breite")
