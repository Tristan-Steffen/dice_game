extends GutTest
## Würfelnetz (DieNetView): Kreuz-Layout, Materialfarben, Kanten-Rahmen,
## Gold-Rahmen der oben liegenden Seite und die Erklärzeilen.

func _def_with_materials() -> DieDefinition:
	var def := DieDefinition.new()
	def.faces = [1, 2, 3, 4, 5, 6]
	def.materials = [DieMaterial.AMBER, "", DieMaterial.AMBER, "", DieMaterial.RUBY, ""]
	def.edge_material = DieMaterial.GOLD
	return def

func _cells(net: Control) -> Array:
	var cells := []
	for child in net.get_children():
		if child is Label:
			cells.append(child)
	return cells

func test_net_zeigt_alle_sechs_seiten_im_kreuz() -> void:
	var def := _def_with_materials()
	var net := DieNetView.build(def, -1, 40.0)
	add_child_autofree(net)
	var cells := _cells(net)
	assert_eq(cells.size(), 6, "6 Seiten-Zellen")
	# Jede Zelle trägt den Wert ihres Face-Index laut NET_LAYOUT.
	var texts := []
	for cell in cells:
		texts.append(cell.text)
	texts.sort()
	assert_eq(texts, ["1", "2", "3", "4", "5", "6"], "alle Seitenwerte einmal")

func test_zellfarben_folgen_material_und_kanten() -> void:
	var def := _def_with_materials()
	var net := DieNetView.build(def, -1, 40.0)
	add_child_autofree(net)
	var amber := DieMaterial.tint_for(DieMaterial.AMBER)
	var gold := DieMaterial.tint_for(DieMaterial.GOLD)
	var amber_cells := 0
	for cell in _cells(net):
		var box: StyleBoxFlat = cell.get_theme_stylebox("normal")
		if box.bg_color == amber:
			amber_cells += 1
		assert_eq(box.border_color, gold, "Kanten-Material färbt jeden Zellrahmen")
	assert_eq(amber_cells, 2, "zwei Bernstein-Seiten")

func test_gold_rahmen_markiert_oben_liegende_seite() -> void:
	var def := _def_with_materials()
	var net := DieNetView.build(def, 3, 40.0)
	add_child_autofree(net)
	assert_eq(_up_frames(net).size(), 1, "genau ein Oben-Rahmen")
	# Ohne up_face kein Rahmen (der gedrehte Kanten-Chip zählt nicht).
	var bare := DieNetView.build(def, -1, 40.0)
	add_child_autofree(bare)
	assert_eq(_up_frames(bare).size(), 0, "kein Rahmen ohne up_face")

## Oben-Rahmen = ungedrehte Panels (der Kanten-Chip ist um 45° gedreht).
func _up_frames(net: Control) -> Array:
	var frames := []
	for child in net.get_children():
		if child is Panel and is_equal_approx(child.rotation, 0.0):
			frames.append(child)
	return frames

func test_face_at_findet_zellen_kanten_chip_und_luecken() -> void:
	var cell := 40.0
	var step := cell * (1.0 + DieNetView.GAP_FACTOR)
	# Zellmitten: (Spalte 1, Zeile 0) = OBEN = Face 3; Mittelzeile 0..3 = 1,0,4,5.
	assert_eq(DieNetView.face_at(Vector2(step + cell / 2.0, cell / 2.0), cell), 3)
	assert_eq(DieNetView.face_at(Vector2(cell / 2.0, step + cell / 2.0), cell), 1)
	assert_eq(DieNetView.face_at(Vector2(3.0 * step + cell / 2.0, step + cell / 2.0), cell), 5)
	# Obere linke Kreuz-Ecke = Kanten-Chip.
	assert_eq(DieNetView.face_at(Vector2(cell / 2.0, cell / 2.0), cell), DieNetView.EDGE)
	# Andere leere Kreuz-Ecke, Lücke zwischen Zellen, außerhalb.
	assert_eq(DieNetView.face_at(Vector2(2.0 * step + cell / 2.0, cell / 2.0), cell), -1)
	assert_eq(DieNetView.face_at(Vector2(cell + cell * 0.05, step + cell / 2.0), cell), -1)
	assert_eq(DieNetView.face_at(Vector2(-5.0, 10.0), cell), -1)

func test_kanten_chip_traegt_die_kanten_materialfarbe() -> void:
	var def := _def_with_materials()  # edge_material = Gold
	var net := DieNetView.build(def, -1, 40.0)
	add_child_autofree(net)
	# Der Kanten-Chip ist eine gedrehte Panel-Raute (kein Face-Cell-Label).
	var chip: Panel = null
	for child in net.get_children():
		if child is Panel and not is_equal_approx(child.rotation, 0.0):
			chip = child
	assert_not_null(chip, "Kanten-Chip als gedrehte Raute vorhanden")
	var box: StyleBoxFlat = chip.get_theme_stylebox("panel")
	assert_eq(box.bg_color, DieMaterial.tint_for(DieMaterial.GOLD), "Chip in Kanten-Materialfarbe")

