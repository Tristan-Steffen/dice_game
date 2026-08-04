extends GutTest
## Zwei Anzeige-Regeln: eine gestiegene Kombinations-Stufe muss SOFORT mit ihren
## neuen Werten dastehen, und ein Zähler-Charm zeigt seinen laufenden Stand
## dauerhaft am Dock-Pad.

# --- Kombinations-Stufe: Zelle rechnet, Chip spiegelt -------------------------------

func _cell(key: String) -> ComboCellView:
	var cell := ComboCellView.new()
	cell.combo_name = DiceScoring.label_for(key)
	add_child_autofree(cell)
	return cell

func test_raising_a_level_needs_new_score_values_too() -> void:
	# set_level allein rechnet Basispunkte und Mult NICHT neu - genau daran hing
	# die stehengebliebene Anzeige. Die Werte kommen aus DiceScoring.
	var key: String = DiceScoring.HAND_PRIORITY[0]
	var flat := {}
	var raised := {key: 3}
	assert_gt(DiceScoring.points_for(key, raised), DiceScoring.points_for(key, flat),
		"eine Stufe hebt die Basispunkte")
	assert_gte(DiceScoring.mult_for(key, raised), DiceScoring.mult_for(key, flat))

func test_the_cell_reports_what_was_written_into_it() -> void:
	var key: String = DiceScoring.HAND_PRIORITY[0]
	var cell := _cell(key)
	var raised := {key: 3}
	cell.set_score(DiceScoring.points_for(key, raised), DiceScoring.mult_for(key, raised))
	cell.set_level(3)
	assert_eq(cell.level, 3)
	assert_eq(cell.points, DiceScoring.points_for(key, raised))
	assert_eq(cell.mult, DiceScoring.mult_for(key, raised))

func test_a_stale_cell_would_hand_the_chip_stale_values() -> void:
	# Der Chip kopiert die Zelle (sync_cell) - was in ihr steht, steht auf ihm.
	# Darum ist das Schreiben BEIDER Werte die eigentliche Regel: nur set_level
	# ohne set_score ließe die Zahlen auf dem alten Stand stehen.
	var key: String = DiceScoring.HAND_PRIORITY[0]
	var cell := _cell(key)
	cell.set_score(DiceScoring.points_for(key, {}), DiceScoring.mult_for(key, {}))
	cell.set_level(0)
	var flat_points := cell.points
	cell.set_level(4)  # nur die Stufe - so entstand die stehengebliebene Anzeige
	assert_eq(cell.points, flat_points, "set_level rechnet die Werte NICHT nach")
	var raised := {key: 4}
	cell.set_score(DiceScoring.points_for(key, raised), DiceScoring.mult_for(key, raised))
	assert_gt(cell.points, flat_points, "erst set_score bringt den neuen Stand")

func test_the_spotlight_redemption_raises_the_level_in_the_run() -> void:
	# claim_spotlight ist die Buchung hinter der Zeremonie - je Runde einmal.
	var run := GameRun.new_run()
	var key: String = DiceScoring.HAND_PRIORITY[0]
	run.spotlight_combo = key
	run.spotlight_claimed_this_round = false
	var before := run.combo_level(key)
	assert_true(run.claim_spotlight(key), "das Rampenlicht wird eingelöst")
	assert_eq(run.combo_level(key), before + 1, "die Stufe steigt sofort")
	assert_false(run.claim_spotlight(key), "und nur einmal je Runde")

func test_a_clause_spotlight_is_redeemable_without_any_charm() -> void:
	# Rampenlicht aus einer Klausel hat keinen Charm im Dock - die Einlösung darf
	# davon nicht abhängen, sonst stiege die Stufe nie.
	var run := GameRun.new_run()
	run.owned_charms.clear()
	var key: String = DiceScoring.HAND_PRIORITY[1]
	run.spotlight_combo = key
	run.spotlight_claimed_this_round = false
	assert_true(run.claim_spotlight(key), "ohne Charm genauso einlösbar")
	assert_eq(run.combo_level(key), 1)

# --- Übertaktungs-Schild am Chip ----------------------------------------------------

func _chip() -> ComboChipView:
	var chip := ComboChipView.new()
	add_child_autofree(chip)
	chip.setup(4.0, 1.5)  # Weltmaße einer Zelle
	return chip

func test_the_tag_is_armed_only_while_the_combos_view_is_open() -> void:
	# Die Trefferfläche liegt UNTER der Kombinations-Klickzone: bliebe sie
	# dauerhaft scharf, fingen die Chips Klicks aus jeder anderen Sicht ab.
	var chip := _chip()
	var body := chip.upgrade_pick_body()
	assert_eq(body.collision_layer, 0, "geschlossen: nichts zu treffen")
	chip.set_upgrade_visible(true)
	assert_eq(body.collision_layer, ComboChipView.UPGRADE_PICK_LAYER)
	chip.set_upgrade_visible(false)
	assert_eq(body.collision_layer, 0)

func test_the_tag_prints_the_charge_price_and_dims_when_unaffordable() -> void:
	var chip := _chip()
	chip.set_upgrade_visible(true)
	var tag := chip.get_node("UpgradeTag") as Label3D
	chip.set_upgrade_offer(3, true)
	assert_eq(tag.text, "⚡3")
	assert_eq(tag.modulate, ComboChipView.TAG_COLOR, "bezahlbar: Signalfarbe")
	chip.set_upgrade_offer(3, false)
	assert_eq(tag.modulate, ComboChipView.TAG_DIM, "zu wenig Energie: gedimmt")

func test_the_level_no_longer_colours_the_chip() -> void:
	# Die Hitze-Rampe ist weg: der Betriebston steht fest, die Stufe zeigt das
	# LVL-Feld. Sonst wäre der Chip bei jeder Stufe eine andere Farbe.
	var chip := _chip()
	var band := chip.find_child("Display", true, false) as MeshInstance3D
	var key: String = DiceScoring.HAND_PRIORITY[0]
	var cell := _cell(key)
	cell.set_level(0)
	chip.sync_cell(cell)
	var cold: Color = (band.material_override as StandardMaterial3D).emission
	cell.set_level(9)
	chip.sync_cell(cell)
	assert_eq((band.material_override as StandardMaterial3D).emission, cold,
		"neun Stufen später leuchtet er genauso")

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
