extends GutTest
## Tier-2-Tests der Charm-Bibliothek (CharmLibraryView): das Nachschlage-Panel
## listet beim Öffnen ALLE registrierten Charms (Charm.all()) mit Beschreibung,
## markiert besessene gold und räumt seine Zeilen beim Schließen wieder ab.

var library: CharmLibraryView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	library = CharmLibraryView.new()
	add_child_autofree(library)
	library.run = run

## Alle Label-Texte unterhalb der Zeilenliste (Namen + Beschreibungen).
func _row_texts() -> Array[String]:
	var texts: Array[String] = []
	var stack: Array = [library.rows]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Label:
			texts.append((node as Label).text)
		for child in node.get_children():
			stack.push_back(child)
	return texts

func test_starts_hidden():
	assert_false(library.visible)

func test_open_lists_every_charm():
	library.open()
	assert_true(library.visible)
	assert_eq(library.rows.get_child_count(), Charm.all().size(), "eine Zeile je Charm")

func test_rows_carry_names_and_descriptions():
	library.open()
	var texts := _row_texts()
	var rabbit := Charm.rabbits_foot()
	assert_has(texts, rabbit.display_name, "Name steht in der Bibliothek")
	assert_has(texts, rabbit.description, "Beschreibung steht daneben")

func test_owned_charms_are_marked():
	run.owned_charms.append(Charm.rabbits_foot())
	library.open()
	var texts := _row_texts()
	assert_has(texts, "%s  ✓" % Charm.rabbits_foot().display_name, "besessener Charm trägt den Haken")
	assert_has(texts, Charm.horseshoe().display_name, "unbesessene bleiben unmarkiert")

func test_toggle_open_and_close_frees_rows():
	library.toggle()
	assert_true(library.visible)
	library.toggle()
	assert_false(library.visible)
	# queue_free wird erst am Frame-Ende wirksam - hier reicht: alles ist zum
	# Freigeben angemeldet.
	for child in library.rows.get_children():
		assert_true(child.is_queued_for_deletion(), "Zeilen werden beim Schließen freigegeben")

func test_reopening_does_not_duplicate_rows():
	library.open()
	library.close()
	library.open()
	var live := 0
	for child in library.rows.get_children():
		if not child.is_queued_for_deletion():
			live += 1
	assert_eq(live, Charm.all().size(), "kein Aufsummieren über mehrere Öffnungen")

func test_rows_carry_model_thumbs():
	library.open()
	var first: Node = library.rows.get_child(0)
	var has_thumb := false
	for child in first.get_children():
		if child is CharmThumb:
			has_thumb = true
	assert_true(has_thumb, "jede Zeile trägt eine 3D-Miniatur (siehe CharmThumb)")

func test_inspect_switches_to_detail_view():
	library.open()
	var charm := Charm.rabbits_foot()
	library.inspect(charm)
	assert_true(library.inspect_root.visible, "Nahansicht offen")
	assert_false(library.list_root.visible, "Liste versteckt")
	assert_eq(library.inspect_name_label.text, charm.display_name)
	assert_eq(library.inspect_desc_label.text, charm.description)
	assert_not_null(library.inspect_thumb, "drehbares Modell steht in der Nahansicht")

func test_close_inspect_returns_to_list():
	library.open()
	library.inspect(Charm.rabbits_foot())
	library.close_inspect()
	assert_false(library.inspect_root.visible)
	assert_true(library.list_root.visible)
	assert_null(library.inspect_thumb, "das drehbare Modell wird freigegeben")

func test_inspecting_another_charm_replaces_the_thumb():
	library.open()
	library.inspect(Charm.rabbits_foot())
	var first_thumb: Node = library.inspect_thumb
	library.inspect(Charm.horseshoe())
	assert_true(first_thumb.is_queued_for_deletion(), "altes Modell wird freigegeben")
	assert_eq(library.inspect_name_label.text, Charm.horseshoe().display_name)

func test_open_resets_a_leftover_inspect():
	library.open()
	library.inspect(Charm.rabbits_foot())
	library.close()
	library.open()
	assert_true(library.list_root.visible, "frisch geöffnet startet in der Liste")
	assert_false(library.inspect_root.visible)

func test_owned_charm_is_marked_in_inspect():
	run.owned_charms.append(Charm.rabbits_foot())
	library.open()
	library.inspect(Charm.rabbits_foot())
	assert_eq(library.inspect_name_label.text, "%s  ✓" % Charm.rabbits_foot().display_name)

func test_debug_grant_adds_charm_to_run():
	run.money = 30
	library.open()
	library.inspect(Charm.ladybug())
	assert_false(library.inspect_grant_button.disabled, "holbar, solange nicht besessen")
	library._on_grant_pressed()
	assert_true(run.owned_charm_ids().has(Charm.LADYBUG), "Charm liegt jetzt im Run")
	assert_eq(run.money, 30, "Debug-Grant kostet nichts (Geld unverändert)")
	assert_true(library.inspect_grant_button.disabled, "danach nicht erneut holbar")
	assert_eq(library.inspect_name_label.text, "%s  ✓" % Charm.ladybug().display_name)

func test_debug_grant_disabled_for_owned_charm():
	run.owned_charms.append(Charm.ladybug())
	library.open()
	library.inspect(Charm.ladybug())
	assert_true(library.inspect_grant_button.disabled, "bereits besessen = nicht holbar")

func test_debug_grant_is_idempotent():
	library.open()
	library.inspect(Charm.ladybug())
	library._on_grant_pressed()
	library._on_grant_pressed()  # zweiter Aufruf prallt ab
	var count := 0
	for id in run.owned_charm_ids():
		if id == Charm.LADYBUG:
			count += 1
	assert_eq(count, 1, "kein doppelter Eintrag")
