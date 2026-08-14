extends GutTest
## Tests der Werkbank-Seite: die Zwingen (Aufspannung, hub-gestaffelt) und die
## Presse in GameRun - Preisleiter, die eine atomare Pressung, platzieren,
## abschließen.

func _d(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

# --- Aufspannung ---------------------------------------------------------------

func test_a_fresh_run_already_has_its_bank() -> void:
	assert_eq(run.clamped_dice.size(), run.clamp_count())
	assert_eq(run.clamp_count(), GameRun.CLAMP_COUNT, "und das sind vier")

## Die Aufspannung ist FEST: keine Lizenzstufe gibt eine Zwinge dazu.
func test_the_clamp_count_never_moves_with_the_hub_level() -> void:
	for level in [1, 2, 3, 5, 7, 10, 12]:
		run.hub_level = level
		assert_eq(run.clamp_count(), 4, "Hub %d spannt vier auf" % level)

func test_the_draw_takes_exactly_that_many_dice() -> void:
	for level in [1, 3, 5, 7, 10]:
		run.hub_level = level
		run.roll_clamped_dice()
		assert_eq(run.clamped_dice.size(), 4, "Hub %d zieht seine vier Zwingen" % level)

func test_the_bank_holds_distinct_pool_dice() -> void:
	var seen := {}
	for die in run.clamped_dice:
		assert_false(seen.has(die.get_instance_id()), "kein Würfel zweimal in den Zwingen")
		seen[die.get_instance_id()] = true
		assert_true(run.owned_pool.has(die), "und jeder kommt aus dem Pool")

func test_the_round_start_redraws_the_bank() -> void:
	var before: Array[DieDefinition] = run.clamped_dice.duplicate()
	var changed := false
	for i in 20:
		run.apply_round_start_charms()
		if run.clamped_dice != before:
			changed = true
			break
	assert_true(changed, "der nächste Rundenstart zieht neu")

func test_the_draw_is_not_the_queue_order() -> void:
	# Deterministisch wäre steuerbar - die Queue ist spielergeordnet.
	var head_hits := 0
	for i in 40:
		run.roll_clamped_dice()
		if run.clamped_dice[0] == run.owned_pool[0]:
			head_hits += 1
	assert_lt(head_hits, 40, "nie 'die nächsten der Reihe'")

func test_applying_never_moves_the_bank() -> void:
	var before: Array[DieDefinition] = run.clamped_dice.duplicate()
	run.press_pieces.append({"sort": Engraving.CATEGORY_NUMBER, "id": Engraving.NOTCH,
		"stufe": 1, "applications": 1})
	assert_true(run.apply_press_number(0, run.clamped_dice[0], _d([0])))
	assert_eq(run.clamped_dice, before, "kein Tausch bei Benutzung")

func test_the_bank_reports_itself() -> void:
	assert_true(run.is_clamped(run.clamped_dice[0]))
	assert_false(run.is_clamped(DieDefinition.standard()), "ein fremder Würfel liegt in keiner Zwinge")
	assert_false(run.is_clamped(null))

func test_a_redraw_announces_itself() -> void:
	watch_signals(run)
	run.roll_clamped_dice()
	assert_signal_emitted(run, "clamped_changed")

## Ein Ausbau rührt die Aufspannung NICHT an - sie ist fest, und an den stehenden
## Zwingen hängt der nasse Guss.
func test_buying_the_licence_leaves_the_bank_alone() -> void:
	run.hub_level = 2
	run.roll_clamped_dice()
	var before: Array[DieDefinition] = run.clamped_dice.duplicate()
	run.money = 100000
	run.upgrade_hub()
	assert_eq(run.hub_level, 3)
	assert_eq(run.clamped_dice, before, "dieselben vier stehen unverändert")

# --- Der Preis: die erste Pressung ist frei, dann steigt er ---------------------

func test_the_first_press_of_a_session_is_free() -> void:
	assert_eq(run.press_cost(), 0)
	assert_true(run.can_press(), "ohne Energie in der Bank")

func test_every_further_press_costs_one_more() -> void:
	run.grant_pack(Pack.number_pack())
	run.charge = 10
	var prices: Array[int] = []
	for i in 4:
		prices.append(run.press_cost())
		run.grant_pack(Pack.number_pack())
		run.open_press(_d([run.owned_packs.size() - 1]), _rng(40 + i))
	assert_eq(prices, [0, 1, 2, 3] as Array[int], "0 -> 1 -> 2 -> 3 Energie")

func test_the_press_spends_exactly_its_price() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	run.charge = 5
	run.open_press(_d([0]), _rng(41))
	assert_eq(run.charge, 5, "die erste ist frei")
	var result := run.open_press(_d([0]), _rng(42))
	assert_eq(int(result["cost"]), 1)
	assert_eq(run.charge, 4, "die zweite kostet eine Energie")

## Ein Preis je PRESSUNG, gleich wie viele Pakete darin liegen.
func test_six_packs_cost_the_same_as_one() -> void:
	for i in 7:
		run.grant_pack(Pack.number_pack())
	run.charge = 9
	run.open_press(_d([0]), _rng(43))
	run.open_press(_d([0, 1, 2, 3, 4, 5]), _rng(44))
	assert_eq(run.charge, 8, "auch sechs Pakete kosten die eine Energie")

func test_a_press_the_bank_cannot_pay_leaves_everything_untouched() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	run.charge = 0
	run.open_press(_d([0]), _rng(45))  # die freie erste
	var packs := run.owned_packs.size()
	var pieces := run.press_pieces.size()
	var result := run.open_press(_d([0]), _rng(46))
	assert_true(result["readers"].is_empty(), "prüfen, dann abbuchen")
	assert_eq(run.owned_packs.size(), packs, "das Paket bleibt versiegelt")
	assert_eq(run.press_pieces.size(), pieces, "und die Ablage unverändert")
	assert_eq(run.press_uses, 1, "die Pressung hat nie stattgefunden")

func test_the_signature_opens_a_fresh_session() -> void:
	run.grant_pack(Pack.number_pack())
	run.charge = 5
	run.open_press(_d([0]), _rng(47))
	assert_eq(run.press_cost(), 1)
	run.reset_press_cycle()
	assert_eq(run.press_cost(), 0, "nach der Unterschrift presst es wieder frei")

func test_a_fresh_run_presses_free() -> void:
	assert_eq(GameRun.new_run().press_cost(), 0)

## Der Bogen spannt über den Laden: ein Rundenwechsel allein setzt ihn NICHT
## zurück (das tut nur die Unterschrift).
func test_the_round_change_keeps_the_price_climbing() -> void:
	run.grant_pack(Pack.number_pack())
	run.charge = 5
	run.open_press(_d([0]), _rng(48))
	run.advance_round()
	assert_eq(run.press_cost(), 1)

# --- Die Pressung --------------------------------------------------------------

func test_pressing_pays_out_per_pack() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.material_pack())
	var result := run.open_press(_d([0, 1]), _rng(9))
	var readers: Array = result["readers"]
	assert_eq(readers.size(), 2, "je Paket ein Leser")
	for uids in readers:
		assert_true(PhantomPress.YIELDS.has(uids.size()), "und je Leser seine Ausbeute")
	assert_eq(run.press_pieces.size(), int(readers[0].size()) + int(readers[1].size()))

func test_every_piece_of_a_press_is_flat() -> void:
	run.grant_pack(Pack.number_pack())
	run.open_press(_d([0]), _rng(10))
	for piece in run.press_pieces:
		assert_eq(int(piece["stufe"]), 1, "aus der Presse kommt nur die erste Sprosse")
		assert_eq(int(piece["applications"]), 1)

func test_every_piece_carries_its_own_number() -> void:
	# An der Nummer hängt sein Platz in der Ablage - zwei dürfen sie nie teilen.
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	run.open_press(_d([0, 1]), _rng(11))
	var seen := {}
	for piece in run.press_pieces:
		var uid := int(piece.get("piece_uid", 0))
		assert_gt(uid, 0, "jedes Stück ist gezeichnet")
		assert_false(seen.has(uid), "und keine Nummer zweimal")
		seen[uid] = true

func test_the_reader_lists_name_exactly_the_pieces_they_threw() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.material_pack())
	var result := run.open_press(_d([0, 1]), _rng(12))
	var readers: Array = result["readers"]
	var index := 0
	for slot in readers.size():
		for uid in readers[slot]:
			assert_eq(int(run.press_pieces[index]["piece_uid"]), int(uid))
			index += 1

func test_pressing_is_binding() -> void:
	run.grant_pack(Pack.number_pack())
	run.open_press(_d([0]), _rng(1))
	assert_eq(run.owned_packs.size(), 0, "kein Zurücksiegeln")

func test_the_batch_is_capped_at_six() -> void:
	for i in 9:
		run.grant_pack(Pack.number_pack())
	var result := run.open_press(_d([0, 1, 2, 3, 4, 5, 6, 7, 8]), _rng(2))
	assert_eq(result["readers"].size(), PhantomPress.BATCH_CAP)
	assert_eq(run.owned_packs.size(), 3, "was nicht in die Konsole passt, bleibt liegen")

func test_a_dice_pack_is_no_press_material() -> void:
	run.grant_pack(Pack.dice_pack(DiceOffer.TEMPLATES[0]))
	assert_true(run.open_press(_d([0]), _rng(3))["readers"].is_empty())
	assert_eq(run.owned_packs.size(), 1, "und wird nicht verbraucht")
	assert_eq(run.press_uses, 0, "eine Pressung ohne Ware ist keine")

## Ein Fixinhalt liefert GENAU sein Stück - keine Menge, kein Icon-Wurf.
func test_a_fixed_content_pack_yields_exactly_one_piece() -> void:
	var gold := Engraving.material_engraving(DieMaterial.by_id(DieMaterial.GOLD),
		Engraving.Rarity.COMMON)
	run.grant_pack(Pack.fixed_engraving_pack(gold))
	var result := run.open_press(_d([0]), _rng(4))
	assert_eq(int(result["readers"][0].size()), 1)
	assert_eq(run.press_pieces.size(), 1)
	assert_eq(String(run.press_pieces[0]["id"]), DieMaterial.GOLD)

func test_the_pointer_runs_through_the_same_press() -> void:
	# Sie liegt auf keinem Ikonensatz - geliefert wird sie trotzdem aus ihrem Leser.
	run.grant_pack(Pack.fixed_engraving_pack(Engraving.pointer_engraving()))
	var result := run.open_press(_d([0]), _rng(5))
	assert_eq(result["readers"].size(), 1, "ein Leser, ein Stück")
	assert_eq(run.press_pieces.size(), 1)
	assert_eq(String(run.press_pieces[0]["id"]), Engraving.POINTER)

func test_a_mixed_press_gives_the_fixed_pack_its_own_reader() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.fixed_engraving_pack(Engraving.pointer_engraving()))
	var result := run.open_press(_d([0, 1]), _rng(15))
	var readers: Array = result["readers"]
	assert_eq(readers.size(), 2)
	assert_eq(int(readers[1].size()), 1, "der Fixinhalt wirft genau eins")

## Nachpressen ist erlaubt: die Stücke LEGEN SICH DAZU.
func test_a_second_press_adds_to_the_pile() -> void:
	run.grant_pack(Pack.number_pack())
	run.grant_pack(Pack.number_pack())
	run.charge = 5
	run.open_press(_d([0]), _rng(16))
	var first := run.press_pieces.size()
	run.open_press(_d([0]), _rng(17))
	assert_gt(run.press_pieces.size(), first, "der Haufen wächst")

## Die Presse mintet NICHTS mehr nebenher: kein versiegeltes Paket, keine
## gebankte Stufe - nur die Stücke.
func test_pressing_mints_nothing_beside_the_pieces() -> void:
	for i in 6:
		run.grant_pack(Pack.number_pack())
	run.open_press(_d([0, 1, 2, 3, 4, 5]), _rng(18))
	var pieces := run.press_pieces.size()
	assert_true(run.owned_packs.is_empty(), "kein Sonderposten fällt nebenher ab")
	assert_eq(run.free_overclocks, 0)
	assert_true(run.apply_press_placements())
	assert_eq(run.free_overclocks, 0, "und auch das Fertig bankt keine Gratis-Stufe")
	assert_eq(run.money, pieces * PhantomPress.FIZZLE_MONEY, "nur der Restwert der Hand")

func test_the_free_overclock_is_spent_before_the_charge() -> void:
	run.free_overclocks = 1
	run.charge = 0
	assert_true(run.can_overclock(DiceScoring.FULL_HOUSE), "die Gutschrift trägt allein")
	assert_true(run.overclock_combo(DiceScoring.FULL_HOUSE))
	assert_eq(run.free_overclocks, 0)
	assert_eq(run.charge, 0, "und keine Energie ist geflossen")
	assert_eq(run.combo_level(DiceScoring.FULL_HOUSE), 1)

func test_without_a_credit_the_charge_pays_again() -> void:
	run.charge = 5
	assert_true(run.overclock_combo(DiceScoring.FULL_HOUSE))
	assert_lt(run.charge, 5)

func test_a_banked_credit_shows_as_gratis_on_the_chip() -> void:
	# Der Deckel sagt GRATIS statt eines Preises - und zwar golden: an einer
	# gebankten Stufe kann nichts zu wenig sein.
	assert_eq(ComboChipView.upgrade_cost_text(3, true), ComboChipView.FREE_TEXT)
	assert_eq(ComboChipView.upgrade_cost_tint(true, false), ComboChipView.FREE_COLOR)
	assert_eq(ComboChipView.upgrade_cost_tint(true, true), ComboChipView.FREE_COLOR)

func test_without_a_credit_the_chip_prints_its_price() -> void:
	assert_eq(ComboChipView.upgrade_cost_text(3, false), "⚡3")
	assert_eq(ComboChipView.upgrade_cost_tint(false, true), ComboChipView.COST_COLOR)
	assert_eq(ComboChipView.upgrade_cost_tint(false, false), ComboChipView.COST_DIM)

# --- Platzieren ----------------------------------------------------------------

func _piece(entry: Dictionary) -> void:
	run.press_pieces.append(entry)

func test_a_number_piece_climbs_its_ladder_on_a_clamped_die() -> void:
	_piece({"sort": Engraving.CATEGORY_NUMBER, "id": Engraving.NOTCH, "stufe": 6,
		"applications": 1})
	var die: DieDefinition = run.clamped_dice[0]
	var before: int = die.faces[0]
	assert_true(run.apply_press_number(0, die, _d([0])))
	assert_eq(die.faces[0], before + 12, "Stufe 6 der Kerbe")
	assert_eq(run.press_pieces.size(), 0, "das Stück ist verbraucht")

func test_an_auto_targeting_piece_needs_no_face() -> void:
	_piece({"sort": Engraving.CATEGORY_NUMBER, "id": Engraving.OVERPRESSURE, "stufe": 1,
		"applications": 1})
	var die: DieDefinition = run.clamped_dice[0]
	assert_true(run.apply_press_number(0, die, _d([])))
	assert_eq(die.faces[5], 8, "die höchste Seite +2")

func test_a_piece_never_reaches_past_the_bank() -> void:
	_piece({"sort": Engraving.CATEGORY_NUMBER, "id": Engraving.NOTCH, "stufe": 1,
		"applications": 1})
	var outsider: DieDefinition = null
	for die in run.owned_pool:
		if not run.is_clamped(die):
			outsider = die
			break
	assert_not_null(outsider)
	assert_false(run.apply_press_number(0, outsider, _d([0])),
		"die Bank sind die Zwingen - sonst keine")
	assert_eq(run.press_pieces.size(), 1, "und nichts wird verbraucht")

func test_a_material_piece_lands_undoped_and_pays_nothing() -> void:
	_piece({"sort": Engraving.CATEGORY_MATERIAL, "id": DieMaterial.RUBY, "applications": 1})
	var die: DieDefinition = run.clamped_dice[0]
	assert_true(run.apply_press_material(0, die, 1))
	assert_eq(die.materials[1], DieMaterial.RUBY)
	assert_lt(die.material_level(1), DieMaterial.MAX_LEVEL,
		"aus der Presse kommt Material unveredelt")
	assert_true(run.apply_press_placements())
	assert_eq(run.money, 0, "und ohne Münze")

func test_a_burn_in_face_refuses_the_overpaint() -> void:
	var die: DieDefinition = run.clamped_dice[0]
	die.set_face_material(1, DieMaterial.GOLD)
	die.set_rune(1, Rune.BURN_IN)
	_piece({"sort": Engraving.CATEGORY_MATERIAL, "id": DieMaterial.RUBY, "applications": 1})
	assert_false(run.apply_press_material(0, die, 1))
	assert_eq(die.materials[1], DieMaterial.GOLD, "der Einbrand hält")

func test_a_rune_piece_is_placeable_run_many_times() -> void:
	_piece({"sort": Engraving.CATEGORY_DICE, "id": Engraving.RUNE_PREFIX + Rune.AFTERGLOW,
		"applications": 3})
	var die: DieDefinition = run.clamped_dice[0]
	for face in 3:
		assert_true(run.apply_press_rune(0, die, face, 0))
		assert_eq(die.runes[face], Rune.AFTERGLOW)
	assert_eq(run.press_pieces.size(), 0, "nach drei Setzungen ist es leer")

func test_rune_placements_may_spread_over_several_bank_dice() -> void:
	_piece({"sort": Engraving.CATEGORY_DICE, "id": Engraving.RUNE_PREFIX + Rune.CAST,
		"applications": 2})
	assert_true(run.apply_press_rune(0, run.clamped_dice[0], 0, 0))
	assert_true(run.apply_press_rune(0, run.clamped_dice[1], 0, 0))
	assert_eq(run.clamped_dice[0].runes[0], Rune.CAST)
	assert_eq(run.clamped_dice[1].runes[0], Rune.CAST)

func test_a_pointer_piece_wires_two_adjacent_faces() -> void:
	_piece({"sort": Engraving.CATEGORY_DICE, "id": Engraving.POINTER, "applications": 1})
	var die: DieDefinition = run.clamped_dice[0]
	assert_false(run.apply_press_pointer(0, die, 0, 5), "die Gegenseite ist kein Nachbar")
	assert_true(run.apply_press_pointer(0, die, 0, 1))
	assert_eq(die.pointer_target(0), 1)

## Die Veredelung ist der Weg in den veredelten Zustand, der sich kaufen lässt.
func test_a_doping_piece_saturates_an_existing_material() -> void:
	_piece({"sort": Engraving.CATEGORY_MATERIAL, "id": Engraving.DOPING, "applications": 1})
	var die: DieDefinition = run.clamped_dice[0]
	die.set_face_material(2, DieMaterial.RUBY)
	assert_false(run.apply_press_doping(0, die, 0), "eine nackte Seite ist kein Ziel")
	assert_eq(run.press_pieces.size(), 1, "und der Fehlgriff verbraucht nichts")
	assert_true(run.apply_press_doping(0, die, 2))
	assert_eq(die.material_level(2), DieMaterial.MAX_LEVEL)
	assert_eq(die.materials[2], DieMaterial.RUBY, "sie sättigt, sie überstreicht nicht")
	assert_eq(run.press_pieces.size(), 0, "das Stück ist verbraucht")

func test_a_doped_face_has_nothing_left_to_gain() -> void:
	_piece({"sort": Engraving.CATEGORY_MATERIAL, "id": Engraving.DOPING, "applications": 1})
	var die: DieDefinition = run.clamped_dice[0]
	die.set_face_material(2, DieMaterial.RUBY)
	die.dope(2)
	assert_false(run.apply_press_doping(0, die, 2))
	assert_eq(run.press_pieces.size(), 1)

## Der Einbrand sperrt das ÜBERMALEN - die Glasur darauf bleibt erlaubt.
func test_a_burned_in_face_still_takes_the_glaze() -> void:
	_piece({"sort": Engraving.CATEGORY_MATERIAL, "id": Engraving.DOPING, "applications": 1})
	var die: DieDefinition = run.clamped_dice[0]
	die.set_face_material(2, DieMaterial.RUBY)
	die.set_rune(2, Rune.BURN_IN)
	assert_true(run.apply_press_doping(0, die, 2))
	assert_eq(die.material_level(2), DieMaterial.MAX_LEVEL)

func test_a_doping_piece_refuses_a_die_outside_the_bank() -> void:
	_piece({"sort": Engraving.CATEGORY_MATERIAL, "id": Engraving.DOPING, "applications": 1})
	var loose := DieDefinition.standard()
	loose.set_face_material(2, DieMaterial.RUBY)
	assert_false(run.apply_press_doping(0, loose, 2), "nur die Zwingen sind Bank")
	assert_lt(loose.material_level(2), DieMaterial.MAX_LEVEL)

func test_placing_reports_the_pool_change() -> void:
	_piece({"sort": Engraving.CATEGORY_NUMBER, "id": Engraving.NOTCH, "stufe": 1,
		"applications": 1})
	watch_signals(run)
	run.apply_press_number(0, run.clamped_dice[0], _d([0]))
	assert_signal_emitted(run, "pool_changed")

# --- Das Fertig löst die Reste der Hand auf -------------------------------------

func test_the_finish_cashes_every_piece_that_never_found_a_seat() -> void:
	_piece({"sort": Engraving.CATEGORY_NUMBER, "id": Engraving.NOTCH, "stufe": 1,
		"applications": 1})
	_piece({"sort": Engraving.CATEGORY_NUMBER, "id": Engraving.CHISEL, "stufe": 1,
		"applications": 1})
	assert_eq(run.press_cash_out_value(), 2 * PhantomPress.FIZZLE_MONEY)
	assert_true(run.apply_press_placements())
	assert_eq(run.money, 2 * PhantomPress.FIZZLE_MONEY, "kein Stück verschwindet wortlos")
	assert_eq(run.press_pieces.size(), 0)

## Je STÜCK eine Münze, nicht je offener Anwendung - ein Stück ist eine Aufwertung.
func test_the_rest_value_counts_pieces_not_applications() -> void:
	_piece({"sort": Engraving.CATEGORY_DICE, "id": Engraving.RUNE_PREFIX + Rune.AFTERGLOW,
		"applications": 4})
	assert_eq(run.press_cash_out_value(), PhantomPress.FIZZLE_MONEY)
	assert_true(run.apply_press_placements())
	assert_eq(run.money, PhantomPress.FIZZLE_MONEY)

func test_finishing_nothing_is_no_windfall() -> void:
	assert_eq(run.press_cash_out_value(), 0)
	assert_false(run.apply_press_placements())
	assert_eq(run.money, 0)

## Der Gegensatz ist der ganze Punkt: wer die Bank verlässt, statt abzuschließen,
## bekommt nichts.
func test_a_lapse_pays_nothing_even_with_a_full_hand() -> void:
	_piece({"sort": Engraving.CATEGORY_NUMBER, "id": Engraving.NOTCH, "stufe": 1,
		"applications": 1})
	_piece({"sort": Engraving.CATEGORY_NUMBER, "id": Engraving.CHISEL, "stufe": 1,
		"applications": 1})
	run.lapse_press()
	assert_eq(run.money, 0, "was nicht angewendet wurde, hat nie gezahlt")
	assert_true(run.press_pieces.is_empty())
