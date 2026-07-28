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


func test_leiterbahn_pfeile_sitzen_am_zellrand() -> void:
	# Zeiger 3 -> 0 (im Kreuz direkt untereinander) und 5 -> 1 (wickelt herum):
	# je ein Pfeil, positioniert auf dem Rand der QUELL-Zelle in Kanten-Richtung.
	var def := DieDefinition.new()
	def.pointers[3] = 0
	def.pointers[5] = 1
	var cell := 40.0
	var net := DieNetView.build(def, -1, cell)
	add_child_autofree(net)
	var arrows := []
	for child in net.get_children():
		if child is DieNetView.PointerArrow:
			arrows.append(child)
	assert_eq(arrows.size(), 2, "je Zeiger ein Pfeil")
	# 3 -> 0: Ziel liegt gefaltet UNTER der Quelle - der Pfeil zeigt nach unten
	# und sitzt mittig auf der Unterkante der Zelle von Seite 3.
	var down: Control = arrows[0]
	assert_eq(down.dir, Vector2.DOWN)
	var gap := cell * DieNetView.GAP_FACTOR
	var source_pos := Vector2(1 * (cell + gap), 0.0)  # Seite 3: Zeile 0, Spalte 1
	var expected := source_pos + Vector2(cell, cell) * 0.5 + Vector2.DOWN * cell * 0.5
	assert_almost_eq((down.position + down.size * 0.5).distance_to(expected), 0.0, 0.5,
		"Pfeilmitte auf der Unterkante")
	# 5 -> 1: im Netz nicht benachbart - der Pfeil zeigt trotzdem über die
	# gefaltete Kante (rechts aus Zelle 5 hinaus), nie quer durchs Kreuz.
	var wrap: Control = arrows[1]
	assert_eq(wrap.dir, Vector2.RIGHT)

func test_ohne_zeiger_keine_pfeile() -> void:
	var net := DieNetView.build(DieDefinition.new(), -1, 40.0)
	add_child_autofree(net)
	for child in net.get_children():
		assert_false(child is DieNetView.PointerArrow, "kein Pfeil ohne Leiterbahn")

# --- Dotierung: Stufe-II-Marke in der Zellecke -----------------------------------

func _badges(net: Control) -> Array:
	var found := []
	for child in net.get_children():
		if child is DieNetView.DopingBadge:
			found.append(child)
	return found

func test_dotierte_seiten_bekommen_eine_marke() -> void:
	var def := _def_with_materials()
	def.upgraded[0] = true
	def.upgraded[4] = true
	var net := DieNetView.build(def, -1, 40.0)
	add_child_autofree(net)
	assert_eq(_badges(net).size(), 2, "je dotierter Seite eine Marke")

func test_ohne_dotierung_keine_marke() -> void:
	var net := DieNetView.build(_def_with_materials(), -1, 40.0)
	add_child_autofree(net)
	assert_eq(_badges(net).size(), 0)

func test_die_marke_sitzt_in_der_freien_zellecke() -> void:
	# Untere RECHTE Ecke der Quell-Zelle: dort liegt kein Zeiger-Pfeil (die sitzen
	# mittig auf den Zellrändern) und keine Ziffer (die steht in der Zellmitte).
	var def := _def_with_materials()
	def.upgraded[0] = true  # Seite 0 = Kreuzmitte (Zeile 1, Spalte 1)
	var cell := 40.0
	var net := DieNetView.build(def, -1, cell)
	add_child_autofree(net)
	var badge: Control = _badges(net)[0]
	var cell_pos := DieNetView.cell_position(0, cell)
	assert_gt(badge.position.x, cell_pos.x + cell * 0.5, "rechte Zellhälfte")
	assert_gt(badge.position.y, cell_pos.y + cell * 0.5, "untere Zellhälfte")
	assert_true(Rect2(cell_pos, Vector2.ONE * cell).encloses(Rect2(badge.position, badge.size)),
		"die Marke bleibt ganz in ihrer Zelle")

func test_die_marke_traegt_die_materialfarbe() -> void:
	var def := _def_with_materials()
	def.upgraded[4] = true  # Rubin
	var net := DieNetView.build(def, -1, 40.0)
	add_child_autofree(net)
	var badge: DieNetView.DopingBadge = _badges(net)[0]
	assert_eq(badge.tint, DieMaterial.tint_for(DieMaterial.RUBY))

func test_die_marke_skaliert_mit_der_zelle() -> void:
	# Sie muss auch im 30er-Raster (Zelle ~17 px) noch eine Fläche haben.
	var def := _def_with_materials()
	def.upgraded[0] = true
	for cell: float in [17.0, 35.0, 46.0]:
		var net := DieNetView.build(def, -1, cell)
		add_child_autofree(net)
		var badge: Control = _badges(net)[0]
		assert_almost_eq(badge.size.x, cell * DieNetView.DOPING_BADGE, 0.01,
			"Marke skaliert mit der Zelle (%d)" % int(cell))
		assert_gt(badge.size.x, 4.0, "auch bei Zelle %d noch sichtbar" % int(cell))
