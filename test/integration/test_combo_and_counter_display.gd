extends GutTest
## Zwei Anzeige-Regeln: ein Chip zeigt sofort den sicheren Wert seiner
## Module, und ein Zähler-Charm zeigt seinen laufenden Stand dauerhaft am
## Dock-Pad.

# --- Kombinations-Chip: Zelle rechnet, Chip spiegelt --------------------------------

func _cell(key: String) -> ComboCellView:
	var cell := ComboCellView.new()
	cell.combo_name = DiceScoring.label_for(key)
	add_child_autofree(cell)
	return cell

func test_fixed_combo_parts_raise_the_shown_values() -> void:
	var key: String = DiceScoring.HAND_PRIORITY[0]
	var flat := ComboPartEffects.display_values({}, key)
	var raised := ComboPartEffects.display_values({key: [ComboPart.coil()]}, key)
	assert_eq(raised.x, flat.x + ComboPartEffects.COIL_POINTS, "die Spule hebt die Basispunkte")
	assert_eq(raised.y, flat.y + ComboPartEffects.COIL_MULT)

func test_die_and_crit_parts_do_not_show_on_the_chip() -> void:
	# Der Chip zeigt, was die Kombination SICHER bringt - nicht das Würfelglück.
	var key: String = DiceScoring.HAND_PRIORITY[0]
	var parts := {key: [ComboPart.relay(), ComboPart.amplifier_tube()]}
	assert_eq(ComboPartEffects.display_values(parts, key), ComboPartEffects.display_values({}, key))

func test_the_cell_reports_what_was_written_into_it() -> void:
	var key: String = DiceScoring.HAND_PRIORITY[0]
	var cell := _cell(key)
	var values := ComboPartEffects.display_values({key: [ComboPart.resistor()]}, key)
	cell.set_score(values.x, values.y)
	assert_eq(cell.points, values.x)
	assert_eq(cell.mult, values.y)

func test_the_spotlight_redemption_gifts_a_resistor() -> void:
	# claim_spotlight ist die Buchung hinter der Zeremonie - je Runde einmal.
	var run := GameRun.new_run()
	var key: String = DiceScoring.HAND_PRIORITY[0]
	run.spotlight_combo = key
	run.spotlight_claimed_this_round = false
	assert_true(run.claim_spotlight(key), "das Rampenlicht wird eingelöst")
	assert_eq(run.pending_parts.size(), 1, "ein Widerstand wartet auf den Einbau")
	assert_false(run.claim_spotlight(key), "und nur einmal je Runde")

func test_a_clause_spotlight_is_redeemable_without_any_charm() -> void:
	var run := GameRun.new_run()
	run.owned_charms.clear()
	var key: String = DiceScoring.HAND_PRIORITY[1]
	run.spotlight_combo = key
	run.spotlight_claimed_this_round = false
	assert_true(run.claim_spotlight(key), "ohne Charm genauso einlösbar")
	assert_eq(run.pending_parts[0].id, ComboPart.RESISTOR)

# --- Der Chip-Deckel ----------------------------------------------------------------

func _chip() -> ComboChipView:
	var chip := ComboChipView.new()
	add_child_autofree(chip)
	chip.setup(4.0, 1.5)  # Weltmaße einer Zelle
	return chip

func _labels(chip: ComboChipView) -> Dictionary:
	var board := chip.find_child("ScreenLabels", true, false)
	var kids := board.get_children()
	return {"points": kids[1], "mult": kids[2], "state": kids[3]}

func test_the_lid_shows_the_cell_values_and_no_level() -> void:
	var chip := _chip()
	var key: String = DiceScoring.HAND_PRIORITY[0]
	var cell := _cell(key)
	cell.set_score(60, 15)
	chip.sync_cell(cell)
	var l := _labels(chip)
	assert_eq((l["points"] as Label3D).text, "60")
	assert_eq((l["mult"] as Label3D).text, "×15")
	assert_eq((l["state"] as Label3D).text, "", "keine Stufen-Marke mehr")
	assert_false(chip.has_method("set_upgrade_offer"), "das Übertakten ist fort")

func test_the_throttle_still_reads_aus() -> void:
	var chip := _chip()
	chip.set_throttled(true)
	assert_eq((_labels(chip)["state"] as Label3D).text, "AUS")

# --- Zähler-Charms am Dock ----------------------------------------------------------

func _dock() -> CharmDockView:
	var dock := CharmDockView.new()
	dock.size = Vector2(900, 200)
	add_child_autofree(dock)
	return dock

func test_the_old_penny_payout_is_one_formula() -> void:
	# Der Chip zeigt, was die Abrechnung später bucht - eine Formel, zwei Leser.
	assert_eq(CharmEffects.old_penny_payout(0), 3, "erste Auszahlung: $3")
	assert_eq(CharmEffects.old_penny_payout(4), 7, "nach vier Auszahlungen: $7")
	assert_eq(CharmEffects.old_penny_payout(-2), 3, "kein negativer Zähler")

func test_the_payout_formula_matches_the_booking() -> void:
	var ids: Array[String] = [Charm.OLD_PENNY]
	for payouts in [0, 1, 5, 12]:
		var count: int = payouts
		var entries := CharmEffects.round_end_income_entries(0, 0, ids, count)
		assert_eq(int(entries[0]["amount"]), CharmEffects.old_penny_payout(count),
			"Chip und Buchung sagen dasselbe (%d)" % count)

func test_setting_a_badge_shows_it_and_clearing_hides_it() -> void:
	var dock := _dock()
	await wait_frames(2)
	dock.set_badges({0: "$7"})
	await wait_frames(2)
	assert_eq(dock._badge_texts.get(0, ""), "$7", "der Chip trägt seinen Stand")
	dock.set_badges({})
	await wait_frames(2)
	assert_false(dock._badge_texts.has(0), "ohne Zähler kein Chip")

func test_badges_are_rebuilt_wholesale_not_patched() -> void:
	# Umsortieren und Käufe bauen die Reihe neu - die Chips müssen mitkommen,
	# also setzt set_badges IMMER alle Plätze.
	var dock := _dock()
	await wait_frames(2)
	dock.set_badges({0: "+3", 2: "$5"})
	await wait_frames(2)
	dock.set_badges({1: "+9"})
	await wait_frames(2)
	assert_false(dock._badge_texts.has(0), "der alte Platz ist geräumt")
	assert_eq(dock._badge_texts.get(1, ""), "+9", "und der neue gesetzt")

func test_the_broken_mirror_counter_grows_with_farkles() -> void:
	var run := GameRun.new_run()
	assert_eq(run.farkle_count, 0, "ein frischer Lauf hat nichts zerbrochen")
	run.farkle_count += 1
	run.farkle_count += 1
	assert_eq(run.farkle_count, 2, "der Zähler wächst und bleibt")
