extends GutTest
## Integrationstests der drei Schwarzmarkt-Requisiten (Kondensator-Bank, Kiosk,
## Boden-Ader). Sie sind reine Anzeige - geprüft wird, dass ihr Zustand
## deckungsgleich zu dem ist, was scene_root ihnen sagt.

# --- Kondensator-Bank ---------------------------------------------------------

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

# --- Kiosk --------------------------------------------------------------------

func _stand() -> SecretShopStandView:
	var stand := SecretShopStandView.new()
	add_child_autofree(stand)
	return stand

func test_locked_stand_shows_only_the_standby_lamp() -> void:
	var stand := _stand()
	stand.set_lit(false)
	assert_false(stand.is_lit())
	var lamp := stand.find_child("StandbyLamp", false, false) as MeshInstance3D
	assert_true(lamp.visible, "das Lämpchen brennt, solange alles aus ist")
	var light := stand.find_child("PoolLight", false, false) as OmniLight3D
	assert_false(light.visible, "keine Lichtpfütze vor der Entdeckung")
	var sign_node := stand.find_child("Sign", false, false) as MeshInstance3D
	assert_false(sign_node.visible)

func test_lit_stand_swaps_lamp_for_neon() -> void:
	var stand := _stand()
	stand.set_lit(true)
	assert_true(stand.is_lit())
	assert_false((stand.find_child("StandbyLamp", false, false) as MeshInstance3D).visible,
		"das Standby-Lämpchen weicht dem Neon")
	assert_true((stand.find_child("PoolLight", false, false) as OmniLight3D).visible)
	assert_true((stand.find_child("Sign", false, false) as MeshInstance3D).visible)

func test_stand_state_is_idempotent() -> void:
	var stand := _stand()
	stand.set_lit(true)
	stand.set_lit(true)
	stand.set_lit(false)
	stand.set_lit(false)
	assert_false(stand.is_lit())
	assert_true((stand.find_child("StandbyLamp", false, false) as MeshInstance3D).visible)

func test_stand_uses_exactly_one_light() -> void:
	var stand := _stand()
	stand.set_lit(true)
	var lights := 0
	for child in stand.get_children():
		if child is Light3D:
			lights += 1
	assert_eq(lights, 1, "der gekachelte Boden verträgt keine Lichter-Batterie")

# --- Boden-Ader ---------------------------------------------------------------

func _vein() -> FloorVeinView:
	var vein := FloorVeinView.new()
	add_child_autofree(vein)
	return vein

func _segments(vein: FloorVeinView) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in vein.get_children():
		if child.name.begins_with("Segment"):
			out.append(child)
	return out

func test_vein_is_segmented_along_its_run() -> void:
	var vein := _vein()
	vein.lay(Vector3(-40.0, 0.0, 34.0), Vector3(-39.0, 0.0, 40.0))
	assert_gt(_segments(vein).size(), 2, "mehrere Segmente für den Zündlauf")
	for seg in _segments(vein):
		assert_almost_eq(seg.position.y, FloorVeinView.VEIN_Y, 0.001,
			"die Ader liegt knapp über dem Boden")

func test_unlit_vein_is_invisible() -> void:
	var vein := _vein()
	vein.lay(Vector3(-40.0, 0.0, 34.0), Vector3(-39.0, 0.0, 40.0))
	vein.set_lit(false)
	for seg in _segments(vein):
		assert_false(seg.visible, "vor der Entdeckung liegt dort nichts")

func test_lit_vein_glows_along_its_whole_run() -> void:
	var vein := _vein()
	vein.lay(Vector3(-40.0, 0.0, 34.0), Vector3(-39.0, 0.0, 40.0))
	vein.set_lit(true)
	for seg in _segments(vein):
		assert_true(seg.visible, "nach der Entdeckung brennt sie durchgehend")

func test_relaying_replaces_the_old_run() -> void:
	var vein := _vein()
	vein.lay(Vector3(-40.0, 0.0, 34.0), Vector3(-39.0, 0.0, 44.0))
	var before := _segments(vein).size()
	vein.lay(Vector3(-40.0, 0.0, 34.0), Vector3(-39.5, 0.0, 36.0))
	await wait_frames(2)  # die alten Segmente sind queue_free'd
	assert_lt(_segments(vein).size(), before, "die kürzere Strecke hat weniger Segmente")
