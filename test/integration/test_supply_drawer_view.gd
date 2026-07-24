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

func test_hover_reports_the_description_even_at_the_station() -> void:
	# Regression: an der Station (Zeremonie) muss das Überfahren die Beschreibung
	# weiter melden - sonst friert die Info-Leiste auf dem gewählten Werkzeug ein.
	run.grant_engraving(Engraving.chisel())
	var drawer := _drawer(Engraving.CATEGORY_NUMBER)
	drawer.set_ceremony(true)
	var seen: Array[String] = []
	drawer.hovered.connect(func(info: String) -> void: seen.append(info))
	for entry in drawer.slots:
		if entry["id"] == Engraving.CHISEL:
			entry["button"].mouse_entered.emit()
			entry["button"].mouse_exited.emit()
	assert_eq(seen, [_chisel_info(), ""], "Beschreibung beim Überfahren, leer beim Verlassen")

func _chisel_info() -> String:
	# Nur Name und Wirkung - keine Seltenheits-Angabe.
	var chisel := Engraving.chisel()
	return "%s: %s" % [chisel.display_name, chisel.description]

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

# --- Reihenfolge der Plätze (vom alten Gravur-Bord übernommen) -----------------

func test_slots_run_common_before_uncommon_before_rare() -> void:
	var drawer := _drawer(Engraving.CATEGORY_NUMBER)
	var ranks: Array[int] = []
	for entry in drawer.slots:
		for archetype in Engraving.all():
			if archetype.id == entry["id"]:
				ranks.append(int(archetype.rarity))
	for i in range(1, ranks.size()):
		assert_true(ranks[i] >= ranks[i - 1], "Seltenheit steigt monoton")

func test_slots_cover_every_archetype_of_the_category() -> void:
	for category in Engraving.CATEGORIES:
		var expected := 0
		for archetype in Engraving.all():
			if archetype.category == category:
				expected += 1
		assert_eq(_drawer(category).slots.size(), expected, "%s vollständig" % category)

# --- Einschlag eines Meteors ----------------------------------------------------

func _chip_of(drawer: SupplyDrawerView, engraving_id: String) -> Button:
	for entry in drawer.slots:
		if entry["id"] == engraving_id:
			return entry["button"]
	return null

func test_a_plain_pop_leaves_no_afterglow() -> void:
	var drawer := _drawer(Engraving.CATEGORY_NUMBER)
	drawer.pop(Engraving.CHISEL)
	assert_null(_chip_of(drawer, Engraving.CHISEL).get_node_or_null("Afterglow"),
		"ohne Farbe bleibt der Platz, wie er war")

func test_a_meteor_hit_makes_its_slot_glow() -> void:
	var drawer := _drawer(Engraving.CATEGORY_NUMBER)
	drawer.pop(Engraving.CHISEL, Color("#ffd319"))
	var glow: Panel = _chip_of(drawer, Engraving.CHISEL).get_node_or_null("Afterglow")
	assert_not_null(glow, "der getroffene Platz glüht nach")
	var box: StyleBoxFlat = glow.get_theme_stylebox("panel")
	assert_eq(box.border_color, Color("#ffd319"), "in der Farbe des Meteors")

func test_the_afterglow_hangs_on_its_own_slot() -> void:
	# Am Chip, nicht am Fenster: ein Neuaufbau der Schublade nimmt es mit, und die
	# feste Platz-Geografie verschiebt sich nicht.
	var drawer := _drawer(Engraving.CATEGORY_NUMBER)
	drawer.pop(Engraving.CHISEL, Color("#ffd319"))
	var before := _chip_of(drawer, Engraving.CHISEL).position
	assert_eq(_chip_of(drawer, Engraving.CHISEL).position, before, "der Platz bleibt liegen")
	assert_null(drawer.get_node_or_null("Afterglow"), "es hängt nicht am Fenster")

func test_the_afterglow_fades_away() -> void:
	var drawer := _drawer(Engraving.CATEGORY_NUMBER)
	drawer.pop(Engraving.CHISEL, Color("#ffd319"))
	var glow: Control = _chip_of(drawer, Engraving.CHISEL).get_node_or_null("Afterglow")
	assert_gt(glow.modulate.a, 0.0, "es startet sichtbar")
	assert_gt(SupplyDrawerView.AFTERGLOW_TIME, 1.5, "und bleibt lange genug zum Lesen")
