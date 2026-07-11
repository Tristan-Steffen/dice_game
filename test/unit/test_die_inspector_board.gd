extends GutTest
## Tier-1-Tests des Gravur-Bords (DieInspectorView): die Seltenheits-Sortierung
## der festen Coupon-Plätze. (Der Bord-Aufbau selbst braucht die Szene und wird
## visuell geprüft; der Wert→Seiten-Auflöser hat eigene Tests, siehe
## test_die_inspector_resolver.)

func _view() -> DieInspectorView:
	return autofree(DieInspectorView.new())

func test_sorted_by_rarity_puts_common_before_uncommon_before_rare():
	var input: Array[Coupon] = [Coupon.blueprint(), Coupon.fine_engraving(), Coupon.chisel()]
	var sorted := _view()._sorted_by_rarity(input)
	var ids: Array[String] = []
	for coupon in sorted:
		ids.append(coupon.id)
	assert_eq(ids, [Coupon.CHISEL, Coupon.FINE_ENGRAVING, Coupon.BLUEPRINT])

func test_sorted_by_rarity_is_stable_within_a_tier():
	# Innerhalb einer Seltenheit bleibt die Eingabe-Reihenfolge (= kanonische
	# Coupon.all()-Reihenfolge) erhalten, damit die Plätze stabil liegen.
	var input: Array[Coupon] = [Coupon.transplant(), Coupon.chisel(), Coupon.grindstone()]
	var sorted := _view()._sorted_by_rarity(input)
	assert_eq(sorted[0].id, Coupon.TRANSPLANT)
	assert_eq(sorted[1].id, Coupon.CHISEL)
	assert_eq(sorted[2].id, Coupon.GRINDSTONE)

func test_sorted_by_rarity_keeps_all_entries():
	var everything: Array[Coupon] = Coupon.all()
	assert_eq(_view()._sorted_by_rarity(everything).size(), everything.size())
