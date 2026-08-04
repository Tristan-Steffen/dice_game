extends GutTest
## Tier-1-Tests des Gravur-Datensatzes (Kategorien, Materialien, Ziehung).

func test_all_returns_etchings_materials_and_runes():
	# 10 Ätzungen + Leiterbahn + Dotierung + 5 Material-Gravuren + 6 Runen.
	assert_eq(Engraving.all().size(), 23)

func test_no_engraving_targets_the_edges_anymore():
	# Die Kanten sind als Ausbau-Slot gestrichen - es gibt keine Gravur mehr,
	# die den ganzen Würfel überzieht. Die Würfel-Kategorie füllen jetzt die
	# Runen neben der Leiterbahn.
	for engraving in Engraving.all():
		assert_false(engraving.id.begins_with("edge_"), "keine Kanten-Gravur mehr: %s" % engraving.id)
	var dice_ids: Array[String] = []
	for engraving in Engraving.all():
		if engraving.category == Engraving.CATEGORY_DICE:
			dice_ids.append(engraving.id)
	assert_eq(dice_ids.size(), 7, "Leiterbahn + sechs Runen")
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
	# Die Engraving-id eines Material-Gravuren IST die Material-id - so löst die
	# Gravur-Station die Anwendung direkt über DieMaterial auf. Sonderposten
	# (Dotierung) behalten nur die Kategorie und belegen kein Material.
	var material_ids := {}
	for engraving in Engraving.all():
		if engraving.category == Engraving.CATEGORY_MATERIAL and not Engraving.is_special_id(engraving.id):
			assert_true(DieMaterial.is_valid_id(engraving.id), "%s ist eine Material-id" % engraving.id)
			material_ids[engraving.id] = true
	assert_eq(material_ids.size(), DieMaterial.all().size(), "je Material genau ein Engraving")

func test_material_engravings_have_footprints():
	for engraving in Engraving.all():
		if engraving.category == Engraving.CATEGORY_MATERIAL:
			assert_true(engraving.width >= 1 and engraving.height >= 1)
			assert_true(Engraving.FOOTPRINT.has(engraving.id), "Fläche definiert für %s" % engraving.id)

func test_factory_id_matches_constant():
	assert_eq(Engraving.chisel().id, Engraving.CHISEL)
	assert_eq(Engraving.notch().id, Engraving.NOTCH)
	assert_eq(Engraving.file_down().id, Engraving.FILE_DOWN)
	assert_eq(Engraving.blueprint().id, Engraving.BLUEPRINT)

func test_rarities_match_the_spec():
	assert_eq(Engraving.notch().rarity, Engraving.Rarity.COMMON)
	assert_eq(Engraving.file_down().rarity, Engraving.Rarity.COMMON)
	assert_eq(Engraving.grindstone().rarity, Engraving.Rarity.COMMON)
	assert_eq(Engraving.averaging().rarity, Engraving.Rarity.UNCOMMON)
	assert_eq(Engraving.polish().rarity, Engraving.Rarity.UNCOMMON)
	assert_eq(Engraving.sandpaper().rarity, Engraving.Rarity.UNCOMMON)
	assert_eq(Engraving.chisel().rarity, Engraving.Rarity.RARE)
	assert_eq(Engraving.punch().rarity, Engraving.Rarity.RARE)
	assert_eq(Engraving.blueprint().rarity, Engraving.Rarity.EPIC)

func test_the_doping_is_an_epic_material_engraving_without_material():
	var doping := Engraving.doping()
	assert_eq(doping.category, Engraving.CATEGORY_MATERIAL)
	assert_eq(doping.rarity, Engraving.Rarity.EPIC)
	assert_eq(doping.material_id(), "", "die Dotierung belegt kein Material, sie hebt eines")
	assert_true(Engraving.is_special_id(Engraving.DOPING), "sie liegt im Sonderbestand")
	assert_true(Engraving.FOOTPRINT.has(Engraving.DOPING))

func test_all_categories_are_inventory_kinds():
	# Nach dem Wegfall der Menü-Gravuren sind alle Archetypen inventarfähig.
	for engraving in Engraving.all():
		assert_true(Engraving.DRAFT_CATEGORIES.has(engraving.category), "%s ist inventarfähig" % engraving.id)

func test_rarity_name_is_german():
	assert_eq(Engraving.rarity_name(Engraving.Rarity.COMMON), "häufig")
	assert_eq(Engraving.rarity_name(Engraving.Rarity.UNCOMMON), "ungewöhnlich")
	assert_eq(Engraving.rarity_name(Engraving.Rarity.RARE), "selten")
	assert_eq(Engraving.rarity_name(Engraving.Rarity.EPIC), "episch")

# --- Lichtgravur-Ziehung -----------------------------------------------------

func test_roll_draft_returns_distinct_inventory_engravings():
	var draft := Engraving.roll_draft(3, Engraving.Rarity.COMMON)
	assert_eq(draft.size(), 3, "drei Siegel")
	var seen := {}
	for engraving in draft:
		assert_true(Engraving.DRAFT_CATEGORIES.has(engraving.category), "nur inventarfähige Sorten (keine Menüs)")
		assert_false(seen.has(engraving.id), "keine Dubletten: %s" % engraving.id)
		seen[engraving.id] = true

func test_roll_draft_weights_towards_rarity_floor():
	# Die Untergrenze gewichtet: seltene Siegel dominieren, ohne die häufigen
	# ganz zu streichen.
	var high := 0
	var low := 0
	for i in 200:
		for engraving in Engraving.roll_draft(3, Engraving.Rarity.UNCOMMON):
			if engraving.rarity >= Engraving.Rarity.UNCOMMON:
				high += 1
			else:
				low += 1
	assert_gt(high, low * 2, "über der Grenze deutlich häufiger als darunter")

func test_roll_draft_lowers_floor_when_pool_too_small():
	# Mehr Siegel verlangt als es seltene+ gibt (8) -> der Topf traegt trotzdem,
	# weil die Untergrenze nur gewichtet.
	var draft := Engraving.roll_draft(9, Engraving.Rarity.RARE)
	assert_eq(draft.size(), 9, "Auslage voll trotz knapper seltener Siegel")

func test_every_archetype_reachable_under_every_floor():
	# Der Fehler, den das verhindert: eine hohe Untergrenze schloss die häufigen
	# Archetypen komplett aus, sie kamen in keinem Paket mehr vor.
	seed(20260804)
	for floor in [Engraving.Rarity.COMMON, Engraving.Rarity.UNCOMMON,
			Engraving.Rarity.RARE, Engraving.Rarity.EPIC]:
		for category in Engraving.CATEGORIES:
			var expected := {}
			for engraving in Engraving.all():
				if engraving.category == category:
					expected[engraving.id] = true
			var seen := {}
			for i in 600:
				for engraving in Engraving.roll_in_category(category, 2, floor):
					seen[engraving.id] = true
			for id in expected:
				assert_true(seen.has(id), "%s bleibt bei Untergrenze %s erreichbar"
					% [id, Engraving.rarity_name(floor)])

func test_high_floor_still_favours_rare_archetypes():
	seed(20260805)
	var rare_hits := 0
	var common_hits := 0
	for i in 400:
		for engraving in Engraving.roll_in_category(Engraving.CATEGORY_NUMBER, 2, Engraving.Rarity.RARE):
			if engraving.rarity >= Engraving.Rarity.RARE:
				rare_hits += 1
			elif engraving.rarity == Engraving.Rarity.COMMON:
				common_hits += 1
	assert_gt(rare_hits, common_hits * 3, "die Untergrenze muss sich noch lohnen")

func test_roll_in_category_stays_in_category():
	for category in Engraving.CATEGORIES:
		var offers := Engraving.roll_in_category(category, 2)
		assert_eq(offers.size(), 2, "zwei Angebote je Kategorie")
		var seen := {}
		for engraving in offers:
			assert_eq(engraving.category, category, "bleibt in der Kategorie")
			assert_false(seen.has(engraving.id), "keine Dubletten: %s" % engraving.id)
			seen[engraving.id] = true

# --- Dubletten-Kosten: mehrere Stücke einer id auf einmal ---------------------------

func _run_with(id: String, count: int) -> GameRun:
	var run := GameRun.new_run()
	run.owned_engravings.clear()
	for _i in count:
		run.grant_engraving(Engraving.material_engraving(DieMaterial.by_id(id), Engraving.Rarity.COMMON))
	return run

func test_consume_engravings_is_all_or_nothing() -> void:
	# Sättigen kostet die Zielstufe in Dubletten - ein halber Abzug wäre ein
	# verlorenes Stück ohne Wirkung.
	var run := _run_with(DieMaterial.RUBY, 2)
	assert_false(run.consume_engravings(DieMaterial.RUBY, 3), "drei sind nicht da")
	assert_eq(run.engraving_stock(DieMaterial.RUBY), 2, "und nichts wurde angerührt")
	assert_true(run.consume_engravings(DieMaterial.RUBY, 2))
	assert_eq(run.engraving_stock(DieMaterial.RUBY), 0)

func test_consume_engravings_emits_once() -> void:
	# Array statt int: GDScript-Lambdas fangen Zahlen als KOPIE, ein Zähler
	# darin bliebe stumm auf 0 und der Test grün, ohne etwas zu prüfen.
	var run := _run_with(DieMaterial.RUBY, 3)
	var emits := []
	run.engravings_changed.connect(func() -> void: emits.append(1))
	run.consume_engravings(DieMaterial.RUBY, 3)
	assert_eq(emits.size(), 1, "ein Abzug, ein Signal")

func test_a_failed_consume_stays_silent() -> void:
	var run := _run_with(DieMaterial.RUBY, 1)
	var emits := []
	run.engravings_changed.connect(func() -> void: emits.append(1))
	assert_false(run.consume_engravings(DieMaterial.RUBY, 2))
	assert_eq(emits.size(), 0, "was nicht passiert ist, meldet auch nichts")

func test_consume_engravings_takes_only_its_own_id() -> void:
	var run := _run_with(DieMaterial.RUBY, 2)
	run.grant_engraving(Engraving.chisel())
	assert_true(run.consume_engravings(DieMaterial.RUBY, 2))
	assert_eq(run.engraving_stock(Engraving.CHISEL), 1, "fremde Gravuren bleiben liegen")

func test_the_test_mode_keeps_paying() -> void:
	var run := GameRun.new_run()
	run.unlimited_engravings = true
	assert_true(run.consume_engravings(DieMaterial.RUBY, 3), "Testmodus deckt jede Stufe")
	assert_gte(run.engraving_stock(DieMaterial.RUBY), DieMaterial.MAX_LEVEL)

func test_a_single_consume_still_works() -> void:
	var run := _run_with(DieMaterial.RUBY, 1)
	assert_true(run.consume_engraving(DieMaterial.RUBY), "der alte Weg bleibt")
	assert_eq(run.engraving_stock(DieMaterial.RUBY), 0)
