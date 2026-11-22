extends GutTest
## Die Akku-Bank ist reine Anzeige: je Ladefenster eine Energie, je Block fünf, bis zum Limit.

func _bank() -> EnergyBankView:
	var bank := EnergyBankView.new()
	add_child_autofree(bank)
	return bank

func test_every_cell_of_the_limit_is_built() -> void:
	var bank := _bank()
	bank.set_energy(0, 5)
	assert_eq(EnergyBankView.CELLS, 50)
	assert_eq(EnergyBankView.ROWS * EnergyBankView.ACROSS, EnergyBankView.CELLS)
	var seen := {}
	for i in EnergyBankView.CELLS:
		assert_not_null(bank.segment(i), "Zelle %d ist gebaut" % i)
		seen[bank.segment(i).get_instance_id()] = true
	assert_eq(seen.size(), 50, "je Energie ein eigener Körper")

func test_only_rows_under_the_cap_stand() -> void:
	var bank := _bank()
	bank.set_energy(3, 10)
	for i in 10:
		assert_true(bank.cell_stands(i), "Zelle %d steht" % i)
	for i in range(10, 50):
		assert_false(bank.cell_stands(i), "Zelle %d fehlt noch" % i)

func test_stored_cells_differ_from_empty_ones() -> void:
	var bank := _bank()
	bank.set_energy(3, 10)
	var empty: Material = bank.segment(5).material_override
	for i in 3:
		assert_ne(bank.segment(i).material_override, empty, "Zelle %d ist geladen" % i)
	for i in range(3, 10):
		assert_eq(bank.segment(i).material_override, empty, "Zelle %d glimmt leer" % i)

func test_the_display_names_stock_and_cap() -> void:
	var bank := _bank()
	bank.set_energy(12, 25)
	assert_eq(bank.number_text(), "12")
	assert_eq(bank.cap_text(), "/ 25")

func test_values_are_clamped_to_cap_and_limit() -> void:
	var bank := _bank()
	bank.set_energy(99, 5)
	assert_eq(bank.energy_count(), 5)
	bank.set_energy(-4, 5)
	assert_eq(bank.energy_count(), 0)
	bank.set_energy(0, 99)
	assert_eq(bank.cap_count(), 50)

func test_a_rising_cap_sweeps_and_a_first_set_does_not() -> void:
	var bank := _bank()
	bank.set_energy(0, 5)
	assert_false(bank.sweeping(), "der Laufstart ist kein Ausbau")
	bank.set_energy(0, 10)
	assert_true(bank.sweeping())
	assert_true(bank.cell_stands(9), "Endzustand zuerst: die neue Reihe steht sofort")

func test_cells_fill_bottom_row_first_and_stay_inside_the_frame() -> void:
	assert_lt(EnergyBankView.cell_spot(0).x, EnergyBankView.cell_spot(5).x, "Reihe 0 liegt Bild-unten")
	assert_lt(EnergyBankView.cell_spot(0).z, EnergyBankView.cell_spot(4).z, "Platz 0 liegt links")
	for i in EnergyBankView.CELLS:
		var spot := EnergyBankView.cell_spot(i)
		assert_lt(absf(spot.x) + EnergyBankView.WINDOW.x * 0.5, EnergyBankView.SIZE.x * 0.5)
		assert_lt(absf(spot.z) + EnergyBankView.WINDOW.y * 0.5, EnergyBankView.SIZE.y * 0.5)
