extends GutTest
## Die EINE Würfel-Auskunft: Würfel = Seele, Seite = Augen | Material | Runen.

var band: DieInfoBand

func before_each() -> void:
	band = DieInfoBand.new()
	add_child_autofree(band)
	band.size = Vector2(620, 44)

func _die() -> DieDefinition:
	var die := DieDefinition.standard()
	die.faces[0] = 2500000
	die.materials[0] = DieMaterial.GOLD
	return die

func test_a_soulless_die_says_nothing() -> void:
	band.show_info(_die())
	assert_true(band.is_empty(), "kein Füllsatz ohne Seele")
	assert_eq(band.plain_text(), "")
	band.show_info(null)
	assert_true(band.is_empty())

func test_a_souled_die_names_soul_and_effect() -> void:
	var die := _die()
	var essence := Essence.all()[0]
	die.essence_id = essence.id
	band.show_info(die)
	assert_eq(band.mode(), "die")
	assert_string_contains(band.plain_text(), essence.display_name)
	assert_string_contains(band.plain_text(), essence.description)
	assert_false(band.plain_text().contains(die.display_name), "der Würfelname steht nirgends")

func test_a_face_fills_its_three_places() -> void:
	var data := DieInfoBand.face_data(_die(), 0)
	assert_eq(String(data["pips"]), "2.500.000", "die Augen stehen ausgeschrieben da")
	assert_eq(String(data["material"]), DieMaterial.by_id(DieMaterial.GOLD).display_name)
	assert_eq(String(data["material_text"]), DieMaterial.by_id(DieMaterial.GOLD).short)
	assert_eq(String(data["runes"]), "", "ohne Rune bleibt ihr Platz leer")

func test_a_bare_face_shows_only_its_pips() -> void:
	band.show_info(_die(), 1)
	assert_eq(band.mode(), "face")
	assert_eq(band.plain_text(), DieInfoBand.JOIN.join(["Augen", "2", "Material", "Runen"]),
		"die Etiketten stehen, ihre Plätze bleiben leer")
	band.layout = DieInfoBand.Layout.LINE
	assert_eq(band.plain_text(), DieInfoBand.JOIN.join(["Augen", "2"]))

func test_the_places_never_move() -> void:
	for layout: DieInfoBand.Layout in [DieInfoBand.Layout.ROWS, DieInfoBand.Layout.LINE]:
		band.layout = layout
		band.show_info(_die(), 0)
		var with_material := [band.place_rect(0), band.place_rect(1), band.place_rect(2)]
		band.show_info(_die(), 1)
		assert_eq([band.place_rect(0), band.place_rect(1), band.place_rect(2)], with_material)
	assert_lt(band.place_rect(0).position.x, band.place_rect(1).position.x, "die Zeile: Spalten")
	band.layout = DieInfoBand.Layout.ROWS
	assert_lt(band.place_rect(0).position.y, band.place_rect(1).position.y, "die Zeilen: untereinander")

func test_the_soul_chip_and_gaps_fall_back_to_the_die() -> void:
	var die := _die()
	die.essence_id = Essence.all()[0].id
	assert_eq(DieInfoBand.face_data(die, DieNetView.EDGE), DieInfoBand.die_data(die))
	assert_eq(DieInfoBand.face_data(die, -1), DieInfoBand.die_data(die))

## Jedes Ding trägt seine Farbe: Augen weiß, Material und Rune ihre eigene.
func test_every_place_has_its_own_colour() -> void:
	var die := _die()
	die.runes[0] = Rune.all()[0].id
	band.show_info(die, 0)
	assert_eq(band.head_color(0), DieInfoBand.PIPS_COLOR)
	assert_eq(band.head_color(1), DieInfoBand.readable(DieMaterial.tint_for(DieMaterial.GOLD)))
	assert_eq(band.head_color(2), DieInfoBand.readable(Rune.tint_for(Rune.all()[0].id)))
	assert_ne(band.head_color(1), band.head_color(2))

## Die eine Zeile der Grube steigt für eine lange Seite die Leiter hinab, statt zu schneiden.
func test_the_line_shrinks_for_a_long_face() -> void:
	band.layout = DieInfoBand.Layout.LINE
	band.show_info(_die(), 1)
	var roomy := band.font_px()
	var die := _die()
	die.faces[0] = 6
	die.materials[0] = DieMaterial.BONE
	die.levels[0] = DieMaterial.MAX_LEVEL
	band.show_info(die, 0)
	assert_lt(band.font_px(), roomy)

## Gemessen: jede Zeile paßt samt Etikett, wenn das Band ROW_EM Grade breit ist.
func test_every_material_and_rune_fits_its_row() -> void:
	var font := ThemeDB.fallback_font
	var px := 20
	var room := px * (DieInfoBand.ROW_EM - DieInfoBand.TAG_EM - DieInfoBand.GAP_EM)
	var rows: Array[String] = []
	for material in DieMaterial.all():
		rows.append(material.display_name + material.short)
		rows.append(material.display_name + DieInfoBand.JOIN + DieInfoBand.DOPED + material.short_doped)
	for rune in Rune.all():
		rows.append(rune.display_name + rune.short)
	for text in rows:
		assert_lte(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x, room, text)
