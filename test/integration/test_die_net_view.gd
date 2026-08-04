extends GutTest
## Würfelnetz (DieNetView): Kreuz-Layout, Materialfarben, Kanten-Rahmen,
## Gold-Rahmen der oben liegenden Seite und die Erklärzeilen.

func _def_with_materials() -> DieDefinition:
	var def := DieDefinition.new()
	def.faces = [1, 2, 3, 4, 5, 6]
	def.materials = [DieMaterial.AMBER, "", DieMaterial.AMBER, "", DieMaterial.RUBY, ""]
	def.essence_id = Essence.NEON
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
	var glow := Essence.glow_for(Essence.NEON)
	var amber_cells := 0
	for cell in _cells(net):
		var box: StyleBoxFlat = cell.get_theme_stylebox("normal")
		if box.bg_color == amber:
			amber_cells += 1
		assert_eq(box.border_color, glow, "das Essenzglühen färbt jeden Zellrahmen")
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
	var def := _def_with_materials()  # essence_id = Neon
	var net := DieNetView.build(def, -1, 40.0)
	add_child_autofree(net)
	# Der Kanten-Chip ist eine gedrehte Panel-Raute (kein Face-Cell-Label).
	var chip: Panel = null
	for child in net.get_children():
		if child is Panel and not is_equal_approx(child.rotation, 0.0):
			chip = child
	assert_not_null(chip, "Essenz-Chip als gedrehte Raute vorhanden")
	var box: StyleBoxFlat = chip.get_theme_stylebox("panel")
	assert_eq(box.bg_color, Essence.glow_for(Essence.NEON), "Chip im Essenzglühen")


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

# --- Sättigung: Stufen-Plakette in der Zellecke ----------------------------------

func _badges(net: Control) -> Array:
	var found := []
	for child in net.get_children():
		if child is DieNetView.LevelBadge:
			found.append(child)
	return found

func test_gehobene_seiten_bekommen_eine_plakette() -> void:
	var def := _def_with_materials()
	def.levels[0] = 2
	def.levels[4] = 3
	var net := DieNetView.build(def, -1, 40.0)
	add_child_autofree(net)
	assert_eq(_badges(net).size(), 2, "je gehobener Seite eine Plakette")

func test_stufe_eins_bleibt_unmarkiert() -> void:
	# Stufe I ist der Normalfall - eine Marke auf jeder Material-Zelle wäre Rauschen.
	var def := _def_with_materials()
	for face in 6:
		if def.materials[face] != "":
			def.levels[face] = 1
	var net := DieNetView.build(def, -1, 40.0)
	add_child_autofree(net)
	assert_eq(_badges(net).size(), 0)

func test_die_plakette_zaehlt_ihre_balken() -> void:
	var def := _def_with_materials()
	def.levels[0] = 2
	def.levels[4] = 3
	var net := DieNetView.build(def, -1, 40.0)
	add_child_autofree(net)
	var levels := []
	for badge in _badges(net):
		levels.append(badge.level)
	levels.sort()
	assert_eq(levels, [2, 3], "die Plakette kennt ihre Stufe")

func test_die_plakette_sitzt_in_der_freien_zellecke() -> void:
	# Untere RECHTE Ecke der Quell-Zelle: dort liegt kein Zeiger-Pfeil (die sitzen
	# mittig auf den Zellrändern) und keine Ziffer (die steht in der Zellmitte).
	var def := _def_with_materials()
	def.levels[0] = 2  # Seite 0 = Kreuzmitte (Zeile 1, Spalte 1)
	var cell := 40.0
	var net := DieNetView.build(def, -1, cell)
	add_child_autofree(net)
	var badge: Control = _badges(net)[0]
	var cell_pos := DieNetView.cell_position(0, cell)
	assert_gt(badge.position.x, cell_pos.x + cell * 0.5, "rechte Zellhälfte")
	assert_gt(badge.position.y, cell_pos.y + cell * 0.5, "untere Zellhälfte")
	assert_true(Rect2(cell_pos, Vector2.ONE * cell).encloses(Rect2(badge.position, badge.size)),
		"die Plakette bleibt ganz in ihrer Zelle")

func test_die_plakette_traegt_die_materialfarbe() -> void:
	var def := _def_with_materials()
	def.levels[4] = 2  # Rubin
	var net := DieNetView.build(def, -1, 40.0)
	add_child_autofree(net)
	var badge: DieNetView.LevelBadge = _badges(net)[0]
	# In der Sättigung IHRER Stufe - die Plakette sitzt auf der Zelle und darf
	# nicht heller sein als der Grund, auf dem sie liegt.
	assert_eq(badge.tint, DieMaterial.tint_for(DieMaterial.RUBY, 2))

func test_die_plakette_skaliert_mit_der_zelle() -> void:
	# Sie muss auch im 30er-Raster (Zelle ~17 px) noch eine Fläche haben.
	var def := _def_with_materials()
	def.levels[0] = 2
	for cell: float in [17.0, 35.0, 46.0]:
		var net := DieNetView.build(def, -1, cell)
		add_child_autofree(net)
		var badge: Control = _badges(net)[0]
		assert_almost_eq(badge.size.x, cell * DieNetView.LEVEL_BADGE, 0.01,
			"Plakette skaliert mit der Zelle (%d)" % int(cell))
		assert_gt(badge.size.x, 4.0, "auch bei Zelle %d noch sichtbar" % int(cell))

# --- Runen: Glyphenlinien quer durch die Zellmitte ---------------------------------

func _cracks(net: Control) -> Array:
	var found := []
	for child in net.get_children():
		if child is DieNetView.RuneGlyph:
			found.append(child)
	return found

func test_gebrochene_seiten_zeigen_ihre_risslinien() -> void:
	var def := _def_with_materials()
	def.set_rune(0, Rune.AFTERGLOW)
	def.set_rune(4, Rune.SPARK_FLIGHT)
	var net := DieNetView.build(def, -1, 40.0)
	add_child_autofree(net)
	assert_eq(_cracks(net).size(), 2, "je gebrochener Seite ein Linienzug")

func test_ohne_rune_keine_risse() -> void:
	var net := DieNetView.build(_def_with_materials(), -1, 40.0)
	add_child_autofree(net)
	assert_eq(_cracks(net).size(), 0)

func test_der_riss_traegt_die_runefarbe_und_sitzt_in_seiner_zelle() -> void:
	var def := _def_with_materials()
	def.set_rune(0, Rune.AFTERGLOW)  # Seite 0 = Kreuzmitte
	var cell := 40.0
	var net := DieNetView.build(def, -1, cell)
	add_child_autofree(net)
	var crack: DieNetView.RuneGlyph = _cracks(net)[0]
	assert_eq(crack.tint, Rune.tint_for(Rune.AFTERGLOW))
	assert_eq(crack.position, DieNetView.cell_position(0, cell), "der Rune liegt auf seiner Zelle")
	assert_false(crack.lines.is_empty(), "das Runenzeichen kommt aus dem Datensatz")

func test_vakuum_bricht_schwarz() -> void:
	var def := _def_with_materials()
	def.essence_id = Essence.VACUUM
	def.set_rune(0, Rune.SPARK_FLIGHT)
	var net := DieNetView.build(def, -1, 40.0)
	add_child_autofree(net)
	var crack: DieNetView.RuneGlyph = _cracks(net)[0]
	assert_ne(crack.tint, Rune.tint_for(Rune.SPARK_FLIGHT), "nicht die Runefarbe")
	assert_eq(crack.tint, RuneEffects.glyph_color(Rune.SPARK_FLIGHT, Essence.VACUUM))

func test_der_vakuum_doppelriss_zeigt_zwei_linienzuege() -> void:
	var def := _def_with_materials()
	def.essence_id = Essence.VACUUM
	def.set_rune(0, Rune.AFTERGLOW, 0)
	def.set_rune(0, Rune.STRAY_LIGHT, 1)
	var net := DieNetView.build(def, -1, 40.0)
	add_child_autofree(net)
	assert_eq(_cracks(net).size(), 2, "beide Runen einer Seite werden gezeichnet")

# --- Sättigung im Netz --------------------------------------------------------------

func _cell_for(net: Control, value: String) -> Label:
	for cell in _cells(net):
		if (cell as Label).text == value:
			return cell
	return null

func test_die_zellfuellung_folgt_der_materialstufe() -> void:
	var def := _def_with_materials()
	def.raise_level(0)  # Bernstein auf Stufe II
	var net := DieNetView.build(def, -1, 40.0)
	add_child_autofree(net)
	var box: StyleBoxFlat = _cell_for(net, "1").get_theme_stylebox("normal")
	assert_eq(box.bg_color, DieMaterial.tint_for(DieMaterial.AMBER, 2),
		"gehobene Seite: die Zelle wird satter")
	var plain: StyleBoxFlat = _cell_for(net, "3").get_theme_stylebox("normal")
	assert_eq(plain.bg_color, DieMaterial.tint_for(DieMaterial.AMBER),
		"dasselbe Material auf Stufe I bleibt exakt wie vorher")
	assert_gt(box.bg_color.s, plain.bg_color.s, "und zwar SATTER, nicht nur anders")

func test_die_stufen_plakette_traegt_dieselbe_saettigung() -> void:
	var def := _def_with_materials()
	def.raise_level(0)
	def.raise_level(0)  # Stufe III
	var badges := DieNetView.level_badges(def, 40.0)
	assert_eq(badges.size(), 1, "nur die gehobene Seite bekommt eine Plakette")
	assert_eq((badges[0] as DieNetView.LevelBadge).tint,
		DieMaterial.tint_for(DieMaterial.AMBER, 3))
	# Die Balken selbst bleiben das genaue Maß - die Sättigung ist der Blick von weitem.
	assert_eq((badges[0] as DieNetView.LevelBadge).level, 3)
