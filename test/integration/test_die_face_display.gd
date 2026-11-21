extends GutTest
## Die LADUNG am KÖRPER: vier Zustände auf EINEM Weg (apply_definition), dazu der
## transiente Zeremonie-Stand. Die Stufe färbt die ZIFFER (Weiß, Gelb, Orange, Rot),
## der Überschlag zittert und zündet die Eck-Lampen, und Ruß nimmt Lache, Lampen
## und Seelen-Bewegung fort.

## Die Bloom-Schwelle des Tisches (glow_hdr_threshold) - der kahle Würfel bleibt
## darunter, und Stufe 1 darf ihn nicht darüber heben.

func _display() -> DieFaceDisplay:
	var die: Node3D = autofree(DieBuilder.build())
	return die.get_node("RigidBody3D/Faces")

func _def(essence_id := "") -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = [1, 2, 3, 4, 5, 6]
	def.faces = faces
	def.essence_id = essence_id
	return def


func _digit(display: DieFaceDisplay) -> Color:
	return (display.labels.values()[0] as Label3D).modulate

func test_a_selection_tint_survives_a_repaint() -> void:
	var display := _display()
	display.apply_definition(_def())
	display.set_face_number_tint(0, DieFaceDisplay.SELECT_NUMBER_COLOR)
	display.set_tint(Color.WHITE)
	var tinted := false
	for label: Label3D in display.labels.values():
		tinted = tinted or label.modulate == DieFaceDisplay.SELECT_NUMBER_COLOR
	assert_true(tinted, "ein Neuanstrich löscht die Auswahl nicht")
	display.reset_number_tints()
	assert_eq(_digit(display), DieFaceDisplay.NUMBER_COLOR, "zurück auf die Ruhefarbe")

func test_material_faces_give_the_digit_a_wide_dark_halo() -> void:
	# Auf einer Material-Seite steht die Ziffer auf eigenem Dunkel.
	var display := _display()
	var def := _def()
	def.materials[0] = DieMaterial.GOLD
	def.levels[0] = 1
	display.apply_definition(def)
	for axis in display.labels:
		var label: Label3D = display.labels[axis]
		var want := DieFaceDisplay.LABEL_OUTLINE_MATERIAL if display.face_ids[axis] != "" else DieFaceDisplay.LABEL_OUTLINE_SIZE
		assert_eq(label.outline_size, want, "Hof der Seite %s" % axis)
	assert_gt(DieFaceDisplay.LABEL_OUTLINE_MATERIAL, DieFaceDisplay.LABEL_OUTLINE_SIZE)

func test_stumm_nimmt_funken_und_lache_fort() -> void:
	var legendary := ""
	for essence in Essence.all():
		if essence.rarity == Essence.Rarity.LEGENDARY:
			legendary = essence.id
			break
	assert_ne(legendary, "", "es gibt eine legendäre Seele")
	var display := _display()
	display.apply_definition(_def(legendary))
	assert_not_null(display.soul_motes, "die legendäre Seele funkt")
	assert_true(display.glow_pool.visible, "und wirft ihre Lache")

	display.effects_muted = true
	assert_null(display.soul_motes, "stumm funkt nichts")
	assert_false(display.glow_pool.visible, "und keine Lache")

	display.effects_muted = false
	assert_not_null(display.soul_motes)
	assert_true(display.glow_pool.visible)

## Ein STUMMER Würfel behält seine Stummheit über einen Neuaufbau der Anzeige -
## das Tray schreibt bei jeder Änderung neu.
func test_stumm_ueberlebt_ein_neues_apply_definition() -> void:
	var display := _display()
	display.effects_muted = true
	display.apply_definition(_def())
	assert_false(display.glow_pool.visible, "auch frisch gesetzt bleibt er stumm")
