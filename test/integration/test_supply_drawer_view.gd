extends GutTest
## Tier-2-Tests der Vorrats-Schubladen (SupplyDrawerView): feste Geografie je
## Kategorie, Bestand als ×Anzahl, und der Moduswechsel Lager <-> Werkzeug-Bord.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

func _drawer(category: String) -> SupplyDrawerView:
	var drawer := SupplyDrawerView.new()
	drawer.category = category
	add_child_autofree(drawer)
	drawer.place(Rect2(Vector2.ZERO, SupplyDrawerView.size_for(category, 8.0)), 8.0)
	drawer.run = run
	return drawer

func _ids(drawer: SupplyDrawerView) -> Array[String]:
	var out: Array[String] = []
	for entry in drawer.slots:
		out.append(entry["id"])
	return out

func test_each_drawer_holds_exactly_its_category() -> void:
	for category in Engraving.CATEGORIES:
		var drawer := _drawer(category)
		assert_gt(drawer.slots.size(), 0, "%s hat Plätze" % category)
		for id in _ids(drawer):
			var found := false
			for archetype in Engraving.all():
				if archetype.id == id:
					assert_eq(archetype.category, category, "%s gehört in %s" % [id, category])
					found = true
			assert_true(found, "%s ist ein echter Archetyp" % id)

func test_geography_is_fixed_regardless_of_stock() -> void:
	var empty := _ids(_drawer(Engraving.CATEGORY_NUMBER))
	run.grant_engraving(Engraving.chisel())
	var stocked := _ids(_drawer(Engraving.CATEGORY_NUMBER))
	assert_eq(stocked, empty, "Besitz verschiebt keine Plätze")

func test_stock_counts_land_on_their_slot() -> void:
	run.grant_engraving(Engraving.chisel())
	run.grant_engraving(Engraving.chisel())
	var drawer := _drawer(Engraving.CATEGORY_NUMBER)
	for entry in drawer.slots:
		var expected: int = 2 if entry["id"] == Engraving.CHISEL else 0
		assert_eq(int(entry["count"]), expected, "Bestand auf %s" % entry["id"])

func test_stock_follows_the_run() -> void:
	var drawer := _drawer(Engraving.CATEGORY_NUMBER)
	run.grant_engraving(Engraving.notch())
	for entry in drawer.slots:
		if entry["id"] == Engraving.NOTCH:
			assert_eq(int(entry["count"]), 1, "Zuwachs erscheint ohne Zutun")

func test_stash_mode_ignores_clicks_ceremony_mode_takes_them() -> void:
	run.grant_engraving(Engraving.chisel())
	var drawer := _drawer(Engraving.CATEGORY_NUMBER)
	var owned: Button = null
	for entry in drawer.slots:
		if entry["id"] == Engraving.CHISEL:
			owned = entry["button"]
	assert_true(owned.disabled, "im Lager fängt kein Platz Klicks")
	drawer.set_ceremony(true)
	assert_false(owned.disabled, "an der Station ist der besessene Platz nutzbar")

func test_unowned_slots_stay_disabled_in_ceremony() -> void:
	var drawer := _drawer(Engraving.CATEGORY_NUMBER)
	drawer.set_ceremony(true)
	for entry in drawer.slots:
		assert_true(entry["button"].disabled, "ohne Bestand kein Werkzeug")

func test_pressing_a_tool_reports_its_id() -> void:
	run.grant_engraving(Engraving.chisel())
	var drawer := _drawer(Engraving.CATEGORY_NUMBER)
	drawer.set_ceremony(true)
	var picked: Array[String] = []
	drawer.tool_pressed.connect(func(id: String) -> void: picked.append(id))
	for entry in drawer.slots:
		if entry["id"] == Engraving.CHISEL:
			entry["button"].pressed.emit()
	assert_eq(picked, [Engraving.CHISEL] as Array[String])

func test_enabled_ids_narrow_the_usable_slots() -> void:
	run.grant_engraving(Engraving.chisel())
	run.grant_engraving(Engraving.notch())
	var drawer := _drawer(Engraving.CATEGORY_NUMBER)
	drawer.set_ceremony(true)
	drawer.set_state("", [Engraving.NOTCH] as Array[String])
	for entry in drawer.slots:
		if entry["id"] == Engraving.CHISEL:
			assert_true(entry["button"].disabled, "nicht angebotenes Werkzeug ist gesperrt")
		elif entry["id"] == Engraving.NOTCH:
			assert_false(entry["button"].disabled)

func test_number_drawer_is_the_widest() -> void:
	var number := SupplyDrawerView.size_for(Engraving.CATEGORY_NUMBER, 8.0)
	var material := SupplyDrawerView.size_for(Engraving.CATEGORY_MATERIAL, 8.0)
	var edges := SupplyDrawerView.size_for(Engraving.CATEGORY_DICE, 8.0)
	assert_gt(number.x, material.x, "Zahlen breiter als Materialien")
	assert_eq(material.x, edges.x, "Materialien und Kanten teilen die Spaltenzahl")
