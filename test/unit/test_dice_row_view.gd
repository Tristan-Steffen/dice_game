extends GutTest
## Tier-1-Tests der gemeinsamen Würfel-Zeile (DiceRowView, genutzt von Shop und
## Sammlung): Zwei-Zeilen-Aufbau - Kopf "Anzahl × [Vorschau] = Augensumme",
## darunter die Seiten-Chips (je vorkommender Wert eine Gruppe mit ×Anzahl).

func _lines(def: DieDefinition, quantity: int) -> Array:
	var row: PanelContainer = autofree(DiceRowView.build_row(def, 52, quantity))
	var column: VBoxContainer = row.get_child(0)
	return [column.get_child(0), column.get_child(1)]

func _label_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for child in node.get_children():
		if child is Label:
			texts.append(child.text)
	return texts

func test_eye_total_sums_faces():
	assert_eq(DiceRowView.eye_total(DieDefinition.standard()), 21)
	assert_eq(DiceRowView.eye_total(DieDefinition.fixed(4, "Vier")), 24)

func test_row_has_head_and_chip_line():
	var lines := _lines(DieDefinition.standard(), 1)
	assert_true(lines[0] is HBoxContainer, "Zeile 1: Kopf")
	assert_true(lines[1] is HBoxContainer, "Zeile 2: Zusammensetzung")

func test_head_reads_quantity_die_equals_total():
	# "3× [Würfel] = 21" - Stückzahl, Gleichheitszeichen, Augensumme.
	var lines := _lines(DieDefinition.standard(), 3)
	assert_eq(_label_texts(lines[0]), ["3×", "=", "21"])

func test_single_die_has_no_quantity_label():
	var lines := _lines(DieDefinition.standard(), 1)
	assert_eq(_label_texts(lines[0]), ["=", "21"], "ohne Bündel keine Stückzahl")
	assert_true(lines[0].get_child(0) is SubViewportContainer, "Vorschau steht vorn")

func test_chip_line_groups_by_distinct_value():
	var standard_lines := _lines(DieDefinition.standard(), 1)
	assert_eq(standard_lines[1].get_child_count(), 6, "Standardwürfel: 6 verschiedene Werte")
	var fixed_lines := _lines(DieDefinition.fixed(2, "Zwei"), 1)
	assert_eq(fixed_lines[1].get_child_count(), 1, "Einheitswürfel: eine Gruppe")
	assert_eq(_label_texts(fixed_lines[1].get_child(0)), ["6×", "2"], "6 × [2]")

func test_material_faces_get_their_own_group():
	# Ein Einheitswürfel mit EINER Bernstein-Seite: die Material-Seite zählt
	# getrennt von den fünf einfachen Seiten desselben Werts.
	var def := DieDefinition.fixed(2, "Zwei")
	def.materials[0] = DieMaterial.AMBER
	var lines := _lines(def, 1)
	assert_eq(lines[1].get_child_count(), 2, "einfache und Material-Seiten getrennt")
	assert_eq(_label_texts(lines[1].get_child(0)), ["5×", "2"], "fünf einfache Zweien zuerst")
	assert_eq(_label_texts(lines[1].get_child(1)), ["2"], "die Material-Zwei einzeln")
	var material_chip: Label = lines[1].get_child(1).get_child(0)
	var box: StyleBoxFlat = material_chip.get_theme_stylebox("normal")
	assert_eq(box.bg_color, DieMaterial.tint_for(DieMaterial.AMBER), "Chip trägt die Materialfarbe")
	assert_true(material_chip.tooltip_text.begins_with("Bernstein"), "Tooltip nennt das Material")

func test_same_material_faces_group_together():
	var def := DieDefinition.fixed(4, "Vier")
	def.materials[1] = DieMaterial.GOLD
	def.materials[3] = DieMaterial.GOLD
	var lines := _lines(def, 1)
	assert_eq(lines[1].get_child_count(), 2)
	assert_eq(_label_texts(lines[1].get_child(0)), ["4×", "4"], "vier einfache Vieren")
	assert_eq(_label_texts(lines[1].get_child(1)), ["2×", "4"], "zwei Gold-Vieren gebündelt")
