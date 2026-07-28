extends GutTest
## Integrationstests der Kondensator-Bank (die physische ⚡-Börse). Sie ist reine
## Anzeige - geprüft wird, dass ihr Zustand deckungsgleich zu dem ist, was
## scene_root ihr sagt.

func _bank() -> CapacitorBankView:
	var bank := CapacitorBankView.new()
	add_child_autofree(bank)
	return bank

## Zellen-Knoten der Bank in Füllreihenfolge.
func _cells(bank: CapacitorBankView) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in bank.get_children():
		if child.name.begins_with("Cell"):
			out.append(child)
	return out

func test_cell_count_follows_the_cap() -> void:
	var bank := _bank()
	bank.set_charge(0, 8)
	assert_eq(_cells(bank).size(), 8, "eine Zelle je Deckel-Einheit")
	assert_eq(bank.cap_count(), 8)

func test_growing_cap_rebuilds_the_bank() -> void:
	var bank := _bank()
	bank.set_charge(3, 8)
	assert_eq(_cells(bank).size(), 8)
	bank.set_charge(3, 12)  # Hub-Ausbau: die Bank wird sichtbar länger
	assert_eq(_cells(bank).size(), 12)
	assert_eq(bank.charge_count(), 3, "der Bestand überlebt den Neuaufbau")

func test_lit_cells_match_the_charge() -> void:
	var bank := _bank()
	bank.set_charge(5, 8)
	var cells := _cells(bank)
	var lit: Material = cells[0].material_override
	for i in 5:
		assert_eq(cells[i].material_override, lit, "Zelle %d leuchtet" % i)
	for i in range(5, 8):
		assert_ne(cells[i].material_override, lit, "Zelle %d ist leer" % i)

func test_charge_is_clamped_into_the_bank() -> void:
	var bank := _bank()
	bank.set_charge(99, 8)
	assert_eq(bank.charge_count(), 8, "mehr als der Deckel geht nicht")
	bank.set_charge(-4, 8)
	assert_eq(bank.charge_count(), 0)

func test_large_cap_wraps_into_a_second_row() -> void:
	var bank := _bank()
	bank.set_charge(0, 15)
	assert_eq(_cells(bank).size(), 15)
	# Ausgewogen aufgeteilt (8/7): die längere Reihe bestimmt die Baulänge, die
	# Bank wächst also NICHT über die Schatz-Ecke hinaus.
	var lengthwise: Dictionary = {}
	for cell in _cells(bank):
		var row := snappedf(cell.position.x, 0.01)
		lengthwise[row] = int(lengthwise.get(row, 0)) + 1
	assert_eq(lengthwise.size(), 2, "zwei Reihen")
	var counts: Array = lengthwise.values()
	counts.sort()
	assert_eq(counts, [7, 8])
	assert_almost_eq(bank.bank_length(),
		8.0 * CapacitorBankView.CELL_PITCH + CapacitorBankView.RAIL_MARGIN * 2.0, 0.001)

