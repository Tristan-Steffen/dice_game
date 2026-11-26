extends GutTest
## Die WÜRFEL-AUSKUNFT: Seele mit Element-Kachel, Seiten nach Augenzahl gruppiert in der
## Farbe ihres Materials, Summe und Schnitt.

var card: DieCardView

func before_each() -> void:
	card = DieCardView.new()
	card.size = Vector2(600, 250)
	add_child_autofree(card)

func _die(essence := "", faces: Array = [2, 2, 3, 5, 5, 5]) -> DieDefinition:
	var def := DieDefinition.standard()
	def.essence_id = essence
	for i in 6:
		def.faces[i] = int(faces[i])
	return def

func test_every_essence_has_a_symbol_and_a_number() -> void:
	var seen := {}
	for essence in Essence.all():
		assert_ne(Essence.symbol_of(essence.id), "", essence.display_name)
		assert_gte(Essence.number_of(essence.id), 0, essence.display_name)
		assert_false(seen.has(Essence.symbol_of(essence.id)), "Kürzel doppelt: %s" % essence.id)
		seen[Essence.symbol_of(essence.id)] = true
	assert_eq(Essence.symbol_of(Essence.SODIUM_VAPOR), "Na")
	assert_eq(Essence.number_of(Essence.SODIUM_VAPOR), 11)
	assert_eq(Essence.number_of(""), -1, "ohne Seele keine Zahl")

func test_faces_group_by_value() -> void:
	var groups := DieCardView.face_groups(_die())
	assert_eq(groups.size(), 3)
	assert_eq(groups[0], [2, [0, 1]])
	assert_eq(groups[2], [5, [3, 4, 5]])
	assert_eq(DieCardView.average_text(_die()), "3,7")
	var digits := DieCardView.face_groups(_die("", [8, 80008, 233458, 10, 3, 21]))
	assert_eq(digits.map(func(g: Array) -> int: return int(g[0])), [0, 1, 3, 8],
		"nur die Einer-Ziffer, von 0 bis 9")
	assert_eq(digits[3][1], [0, 1, 2], "8, 80008 und 233458 zählen als 8")
	assert_eq(DieCardView.average_text(_die("", [3, 3, 3, 3, 3, 3])), "3")

func test_effect_splits_its_value_from_the_words() -> void:
	assert_eq(DieCardView.effect_parts("+$1 je Mitwürfel"), ["+$1", FaceCardView.KIND_MONEY,
		"je Mitwürfel"])
	assert_eq(DieCardView.effect_parts("+4 Mult je Seite")[1], FaceCardView.KIND_MULT)
	assert_eq(DieCardView.effect_parts("zwei Runen je Seite")[0], "", "ohne Zahl spricht der Satz")

func test_the_card_names_the_soul_once() -> void:
	card.show_die(_die(Essence.SODIUM_VAPOR))
	var names := 0
	for label in card.find_children("*", "Label", true, false):
		if (label as Label).text == "Natriumdampf":
			names += 1
	assert_eq(names, 1, "der Name steht genau einmal")
	assert_eq((card.get_node("Seele/Kachel/Kuerzel") as Label).text, "Na")
	assert_eq((card.get_node("Seele/Kachel/Ordnungszahl") as Label).text, "11")
	assert_eq((card.get_node("Summe/Wert") as Label).text, "22")
	assert_eq((card.get_node("Schnitt/Wert") as Label).text, "3,7")

func test_a_lit_pip_wears_its_material() -> void:
	var def := _die()
	def.set_face_material(3, DieMaterial.GOLD)
	card.show_die(def)
	var pip := card.get_node("Seiten/Feld2_0") as Panel
	var box := pip.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(box.bg_color, DieMaterial.tint_for(DieMaterial.GOLD, 1), "Seite 3 ist Gold")
	var off := (card.get_node("Seiten/Feld2_5") as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(off.bg_color, DieCardView.PIP_OFF, "nur drei der sechs leuchten")

func test_a_soulless_die_says_normal() -> void:
	card.show_die(_die())
	assert_eq((card.get_node("Seele/Name") as Label).text, WorkshopInfoView.SOULLESS)
