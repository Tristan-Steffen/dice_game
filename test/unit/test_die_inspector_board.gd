extends GutTest
## Tier-1-Tests des Gravur-Bestands an der Station (DieInspectorView): er
## entscheidet, ob ein Werkzeug nach dem Anwenden in der Hand bleibt. Die
## PLÄTZE selbst liegen in den Vorrats-Schubladen (test_supply_drawer_view).

func _view() -> DieInspectorView:
	return autofree(DieInspectorView.new())

func test_engraving_counts_reads_owned_inventory_normally():
	var view := _view()
	view.run = GameRun.new_run()
	view.run.grant_engraving(Engraving.chisel())
	var counts := view._engraving_counts()
	assert_eq(counts.get(Engraving.CHISEL, 0), 1)
	assert_eq(counts.get(Engraving.BLUEPRINT, 0), 0, "nicht besessene Gravuren fehlen")

func test_unlimited_engravings_reports_every_archetype_in_stock():
	# Testmodus: JEDER Engraving-Archetyp gilt als vorhanden (jede Ätzung, jedes
	# Material, jede Kante), damit die Schubladen alles freischalten.
	var view := _view()
	view.run = GameRun.new_run()
	view.run.unlimited_engravings = true
	var counts := view._engraving_counts()
	for archetype in Engraving.all():
		assert_gt(counts.get(archetype.id, 0), 0, "verfügbar: %s" % archetype.id)

func test_counts_are_empty_without_a_run():
	assert_true(_view()._engraving_counts().is_empty())
