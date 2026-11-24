extends GutTest
## Das Klingen-Rack ist reine Anzeige: je Lichtfenster eine Energie, je Klinge fünf, bis
## zum Limit; über dem Tisch steht nur die Oberkante.

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
		assert_not_null(bank.segment(i), "Fenster %d ist gebaut" % i)
		seen[bank.segment(i).get_instance_id()] = true
	assert_eq(seen.size(), 50, "je Energie ein eigenes Fenster")

func test_only_rows_under_the_cap_stand() -> void:
	var bank := _bank()
	bank.set_energy(3, 10)
	for i in 10:
		assert_true(bank.cell_stands(i), "Fenster %d steht" % i)
	for i in range(10, 50):
		assert_false(bank.cell_stands(i), "Fenster %d fehlt noch" % i)
	assert_false(bank.slot_bare(1), "unter einer Klinge liegt keine Kontaktleiste offen")
	assert_true(bank.slot_bare(2), "der leere Platz zeigt seine Kontaktleiste")

func test_stored_cells_differ_from_empty_ones() -> void:
	var bank := _bank()
	bank.set_energy(3, 10)
	var empty: Material = bank.segment(5).material_override
	for i in 3:
		assert_ne(bank.segment(i).material_override, empty, "Fenster %d ist geladen" % i)
	for i in range(3, 10):
		assert_eq(bank.segment(i).material_override, empty, "Fenster %d ist dunkel" % i)

func test_the_lever_tip_says_full_partial_or_empty() -> void:
	var bank := _bank()
	bank.set_energy(7, 15)
	assert_eq(bank.tip_state(0), "voll")
	assert_eq(bank.tip_state(1), "halb")
	assert_eq(bank.tip_state(2), "leer")

func test_the_display_names_stock_and_cap() -> void:
	var bank := _bank()
	bank.set_energy(12, 25)
	assert_eq(bank.number_text(), "12")
	assert_eq(bank.cap_text(), "/25")
	assert_eq(EnergyBankView.display_text(3, 5).length(), EnergyBankView.display_text(50, 50).length(),
		"die Anzeige steht immer auf ihren Geister-Segmenten")

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
	assert_true(bank.cell_stands(9), "Endzustand zuerst: die neue Klinge steckt sofort")
	assert_true(bank.riding(1), "und senkt sich noch ein")
	assert_true((bank.get_node("SchachtRuf1") as Node3D).visible, "ihr Platz ruft")

func test_cells_fill_bottom_row_first_and_stay_inside_the_frame() -> void:
	assert_lt(EnergyBankView.cell_spot(0).x, EnergyBankView.cell_spot(5).x, "Klinge 0 liegt Bild-unten")
	assert_lt(EnergyBankView.cell_spot(0).z, EnergyBankView.cell_spot(4).z, "Fenster 0 liegt links")
	for i in EnergyBankView.CELLS:
		var spot := EnergyBankView.cell_spot(i)
		assert_lt(absf(spot.x) + EnergyBankView.WINDOW.x * 0.5, EnergyBankView.SIZE.x * 0.5)
		assert_lt(absf(spot.z) + EnergyBankView.WINDOW.y * 0.5, EnergyBankView.SIZE.y * 0.5)

func test_nothing_rises_above_the_allowed_height() -> void:
	var bank := _bank()
	bank.set_energy(50, 50)
	var inverse := bank.global_transform.affine_inverse()
	var top := -INF
	for node in bank.find_children("*", "GeometryInstance3D", true, false):
		var shape := node as GeometryInstance3D
		if shape is Label3D or not shape.is_visible_in_tree():
			continue
		var box := (inverse * shape.global_transform) * shape.get_aabb()
		top = maxf(top, box.end.y)
	assert_lte(top, EnergyBankView.TOP_LIMIT + 0.001, "nur die Oberkante steht über dem Tisch")

func test_a_bought_blade_flies_from_its_source_and_sinks_in() -> void:
	var bank := _bank()
	bank.set_energy(0, 5)
	bank.set_energy(0, 10)
	var from := Vector3(-20.0, 0.0, -30.0)
	bank.fly_in(from)
	var block: Node3D = bank.get_node("Block1")
	assert_true(bank.cell_stands(5), "Endzustand zuerst: sie steckt schon")
	assert_true(bank.riding(1))
	assert_almost_eq(block.global_position.x, from.x, 0.01, "sie startet an der Quelle")
	assert_almost_eq(block.global_position.z, from.z, 0.01)
	await wait_seconds(EnergyBankView.FLY_TIME + 0.2)
	assert_false(bank.riding(1), "gelandet")
	assert_almost_eq(block.position.x, EnergyBankView.row_x(1), 0.001)
	assert_almost_eq(block.position.y, EnergyBankView.BASE_TOP, 0.001)
	assert_almost_eq(block.scale.x, 1.0, 0.001)
	assert_false((bank.get_node("SchachtRuf1") as Node3D).visible)

func test_a_shrinking_cap_ends_a_flight_hard() -> void:
	var bank := _bank()
	bank.set_energy(0, 5)
	bank.set_energy(0, 10)
	bank.fly_in(Vector3(-20.0, 0.0, -30.0))
	bank.set_energy(0, 5)
	assert_false(bank.riding(1))
	assert_false(bank.cell_stands(5))
	assert_almost_eq((bank.get_node("Block1") as Node3D).position.x, EnergyBankView.row_x(1), 0.001)
