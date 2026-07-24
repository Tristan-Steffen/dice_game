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
	var frames := []
	for child in net.get_children():
		if child is Panel:
			frames.append(child)
	assert_eq(frames.size(), 1, "genau ein Oben-Rahmen")
	# Ohne up_face kein Rahmen.
	var bare := DieNetView.build(def, -1, 40.0)
	add_child_autofree(bare)
	var bare_frames := 0
	for child in bare.get_children():
		if child is Panel:
			bare_frames += 1
	assert_eq(bare_frames, 0, "kein Rahmen ohne up_face")

