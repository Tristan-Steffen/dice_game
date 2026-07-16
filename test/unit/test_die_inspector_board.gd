extends GutTest
## Tier-1-Tests des Gravur-Bords (DieInspectorView): die Seltenheits-Sortierung
## der festen Sigil-Plätze. (Der Bord-Aufbau selbst braucht die Szene und wird
## visuell geprüft; der Wert→Seiten-Auflöser hat eigene Tests, siehe
## test_die_inspector_resolver.)

func _view() -> DieInspectorView:
	return autofree(DieInspectorView.new())

func test_sorted_by_rarity_puts_common_before_uncommon_before_rare():
	var input: Array[Sigil] = [Sigil.blueprint(), Sigil.fine_engraving(), Sigil.chisel()]
	var sorted := _view()._sorted_by_rarity(input)
	var ids: Array[String] = []
	for sigil in sorted:
		ids.append(sigil.id)
	assert_eq(ids, [Sigil.CHISEL, Sigil.FINE_ENGRAVING, Sigil.BLUEPRINT])

func test_sorted_by_rarity_is_stable_within_a_tier():
	# Innerhalb einer Seltenheit bleibt die Eingabe-Reihenfolge (= kanonische
	# Sigil.all()-Reihenfolge) erhalten, damit die Plätze stabil liegen.
	var input: Array[Sigil] = [Sigil.transplant(), Sigil.chisel(), Sigil.grindstone()]
	var sorted := _view()._sorted_by_rarity(input)
	assert_eq(sorted[0].id, Sigil.TRANSPLANT)
	assert_eq(sorted[1].id, Sigil.CHISEL)
	assert_eq(sorted[2].id, Sigil.GRINDSTONE)

func test_sorted_by_rarity_keeps_all_entries():
	var everything: Array[Sigil] = Sigil.all()
	assert_eq(_view()._sorted_by_rarity(everything).size(), everything.size())

# --- Testmodus: unbegrenzte Sigille -------------------------------------------

func test_sigil_counts_reads_owned_inventory_normally():
	var view := _view()
	view.run = GameRun.new_run()
	view.run.grant_sigil(Sigil.chisel())
	var counts := view._sigil_counts()
	assert_eq(counts.get(Sigil.CHISEL, 0), 1)
	assert_eq(counts.get(Sigil.BLUEPRINT, 0), 0, "nicht besessene Sigille fehlen")

func test_unlimited_sigils_reports_every_archetype_in_stock():
	# Testmodus: JEDER Sigil-Archetyp gilt als vorhanden (jede Ätzung, jedes
	# Material, jede Kante), damit das Gravur-Bord alles freischaltet.
	var view := _view()
	view.run = GameRun.new_run()
	view.run.unlimited_sigils = true
	var counts := view._sigil_counts()
	for archetype in Sigil.all():
		assert_gt(counts.get(archetype.id, 0), 0, "verfügbar: %s" % archetype.id)
