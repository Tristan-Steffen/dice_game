extends GutTest
## Tier-1-Tests des Gravur-Bords (DieInspectorView): die Seltenheits-Sortierung
## der festen Engraving-Plätze. (Der Bord-Aufbau selbst braucht die Szene und wird
## visuell geprüft; der Wert→Seiten-Auflöser hat eigene Tests, siehe
## test_die_inspector_resolver.)

func _view() -> DieInspectorView:
	return autofree(DieInspectorView.new())

func test_sorted_by_rarity_puts_common_before_uncommon_before_rare():
	var input: Array[Engraving] = [Engraving.blueprint(), Engraving.averaging(), Engraving.chisel()]
	var sorted := _view()._sorted_by_rarity(input)
	var ids: Array[String] = []
	for engraving in sorted:
		ids.append(engraving.id)
	assert_eq(ids, [Engraving.CHISEL, Engraving.AVERAGING, Engraving.BLUEPRINT])

func test_sorted_by_rarity_is_stable_within_a_tier():
	# Innerhalb einer Seltenheit bleibt die Eingabe-Reihenfolge (= kanonische
	# Engraving.all()-Reihenfolge) erhalten, damit die Plätze stabil liegen.
	var input: Array[Engraving] = [Engraving.transplant(), Engraving.chisel(), Engraving.grindstone()]
	var sorted := _view()._sorted_by_rarity(input)
	assert_eq(sorted[0].id, Engraving.TRANSPLANT)
	assert_eq(sorted[1].id, Engraving.CHISEL)
	assert_eq(sorted[2].id, Engraving.GRINDSTONE)

func test_sorted_by_rarity_keeps_all_entries():
	var everything: Array[Engraving] = Engraving.all()
	assert_eq(_view()._sorted_by_rarity(everything).size(), everything.size())

# --- Testmodus: unbegrenzte Gravuren -------------------------------------------

func test_engraving_counts_reads_owned_inventory_normally():
	var view := _view()
	view.run = GameRun.new_run()
	view.run.grant_engraving(Engraving.chisel())
	var counts := view._engraving_counts()
	assert_eq(counts.get(Engraving.CHISEL, 0), 1)
	assert_eq(counts.get(Engraving.BLUEPRINT, 0), 0, "nicht besessene Gravuren fehlen")

func test_unlimited_engravings_reports_every_archetype_in_stock():
	# Testmodus: JEDER Engraving-Archetyp gilt als vorhanden (jede Ätzung, jedes
	# Material, jede Kante), damit das Gravur-Bord alles freischaltet.
	var view := _view()
	view.run = GameRun.new_run()
	view.run.unlimited_engravings = true
	var counts := view._engraving_counts()
	for archetype in Engraving.all():
		assert_gt(counts.get(archetype.id, 0), 0, "verfügbar: %s" % archetype.id)
