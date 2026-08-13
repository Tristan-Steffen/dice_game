extends GutTest
## Tier-1-Tests des Gravur-Datensatzes (Kategorien, Materialien, Ikonensätze).

func test_all_returns_etchings_materials_and_runes():
	# 6 Zahl-Gravuren + Pointer + 6 Material-Gravuren + 6 Runen.
	assert_eq(Engraving.all().size(), 20)

func test_the_number_set_is_exactly_six():
	assert_eq(Engraving.NUMBER_IDS.size(), 6, "sechs Seiten, sechs Verben")
	var number_ids: Array[String] = []
	for engraving in Engraving.all():
		if engraving.category == Engraving.CATEGORY_NUMBER:
			number_ids.append(engraving.id)
	assert_eq(number_ids.size(), 6)
	for id in Engraving.NUMBER_IDS:
		assert_true(number_ids.has(id), "NUMBER_IDS nennt nur echte Archetypen: %s" % id)

func test_the_dead_archetypes_are_gone():
	# Feile, Mittelung, Begradigung, Stanze und Blaupause sind ersatzlos
	# gestorben - ihre Rollen stecken in den sechs Leitern.
	var dead := ["file_down", "averaging", "straighten", "sandpaper", "punch",
		"blueprint"]
	for engraving in Engraving.all():
		assert_false(dead.has(engraving.id), "toter Archetyp lebt noch: %s" % engraving.id)

func test_no_engraving_targets_the_edges_anymore():
	for engraving in Engraving.all():
		assert_false(engraving.id.begins_with("edge_"), "keine Kanten-Gravur mehr: %s" % engraving.id)
	var dice_ids: Array[String] = []
	for engraving in Engraving.all():
		if engraving.category == Engraving.CATEGORY_DICE:
			dice_ids.append(engraving.id)
	assert_eq(dice_ids.size(), 7, "Pointer + sechs Runen")
	assert_true(dice_ids.has(Engraving.POINTER))
	for rune in Rune.all():
		assert_true(dice_ids.has(Engraving.RUNE_PREFIX + rune.id), "Rune für %s" % rune.id)

func test_all_ids_are_unique():
	var seen := {}
	for engraving in Engraving.all():
		assert_false(seen.has(engraving.id), "doppelte id: %s" % engraving.id)
		seen[engraving.id] = true

func test_every_engraving_has_filled_metadata():
	for engraving in Engraving.all():
		assert_ne(engraving.id, "", "id fehlt")
		assert_ne(engraving.display_name, "", "display_name fehlt bei %s" % engraving.id)
		assert_ne(engraving.description, "", "description fehlt bei %s" % engraving.id)
		assert_true(engraving.category in [Engraving.CATEGORY_NUMBER, Engraving.CATEGORY_MATERIAL, Engraving.CATEGORY_DICE],
			"bekannter kind bei %s" % engraving.id)

func test_material_engravings_use_the_material_id():
	var material_ids := {}
	for engraving in Engraving.all():
		if engraving.category == Engraving.CATEGORY_MATERIAL and not Engraving.is_special_id(engraving.id):
			assert_true(DieMaterial.is_valid_id(engraving.id), "%s ist eine Material-id" % engraving.id)
			material_ids[engraving.id] = true
	assert_eq(material_ids.size(), DieMaterial.all().size(), "je Material genau ein Engraving")

func test_factory_id_matches_constant():
	assert_eq(Engraving.chisel().id, Engraving.CHISEL)
	assert_eq(Engraving.notch().id, Engraving.NOTCH)
	assert_eq(Engraving.overpressure().id, Engraving.OVERPRESSURE)
	assert_eq(Engraving.growth().id, Engraving.GROWTH)
	assert_eq(Engraving.polish().id, Engraving.POLISH)
	assert_eq(Engraving.grindstone().id, Engraving.GRINDSTONE)

func test_by_id_finds_every_archetype():
	for engraving in Engraving.all():
		assert_not_null(Engraving.by_id(engraving.id), "by_id findet %s" % engraving.id)
	assert_null(Engraving.by_id("gibt_es_nicht"))

func test_the_specials_are_the_pointer_and_the_doping():
	assert_eq(Engraving.SPECIAL_IDS, [Engraving.POINTER, Engraving.DOPING],
		"beide liegen im Sonderbestand, auf keinem Ikonensatz")
	for special in [Engraving.pointer_engraving(), Engraving.doping()]:
		assert_eq(special.material_id(), "", "%s belegt kein Material" % special.id)

## Die Veredelung behält die Material-Kategorie (und damit Paketsorte), belegt
## aber selbst nichts - sie sättigt, was schon liegt.
func test_the_doping_is_a_material_special_without_a_material():
	var doping := Engraving.doping()
	assert_eq(doping.id, Engraving.DOPING)
	assert_eq(doping.category, Engraving.CATEGORY_MATERIAL)
	assert_true(Engraving.is_special_id(doping.id))
	assert_false(DieMaterial.is_valid_id(doping.id), "\"doping\" ist keine Material-id")
	assert_eq(Pack.pack_type_for_category(doping.category), Pack.TYPE_MATERIAL,
		"versiegelt geht sie als Material-Paket raus")

func test_rarity_name_is_german():
	assert_eq(Engraving.rarity_name(Engraving.Rarity.COMMON), "häufig")
	assert_eq(Engraving.rarity_name(Engraving.Rarity.UNCOMMON), "ungewöhnlich")
	assert_eq(Engraving.rarity_name(Engraving.Rarity.RARE), "selten")
	assert_eq(Engraving.rarity_name(Engraving.Rarity.EPIC), "episch")
	assert_eq(Engraving.rarity_name(Engraving.Rarity.LEGENDARY), "legendär")

func test_every_material_has_a_rarity_entry():
	# Eine fehlende Zeile ist ein stiller Fallback - der Lichtsaum läge falsch.
	for material in DieMaterial.all():
		assert_true(Engraving.MATERIAL_RARITY.has(material.id),
			"MATERIAL_RARITY kennt %s" % material.id)
