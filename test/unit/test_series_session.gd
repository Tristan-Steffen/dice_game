extends GutTest
## Die Werkstatt-Sitzung an GameRun: der unbegrenzte Griff, die atomare Buchung,
## der Karten-Verbrauch und die vier Katalysatoren.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng

func _uids(packs: Array) -> Array[int]:
	var uids: Array[int] = []
	for pack: Pack in packs:
		uids.append(pack.pack_uid)
	return uids

## Eine Kassette mit GENAU diesem Netz - Tests brauchen ein bekanntes Netz, kein
## gewürfeltes.
func _card(cells: Dictionary) -> Pack:
	var pack := Pack.number_pack()
	pack.stamp_net = StampNet.empty_net()
	for face: int in cells:
		pack.stamp_net[face] = cells[face]
	return run.grant_pack(pack)

func _die() -> DieDefinition:
	return run.owned_pool[0]

# --- Der Griff ist UNBEGRENZT -------------------------------------------------
## Spieler-Entscheid 2026-09-05: die eine Pressung je Sitzung ist gestorben, und
## mit ihr press_uses/press_allowed/reset_press_cycle.

func test_the_session_has_no_press_counter_any_more() -> void:
	assert_false(run.has_method("press_allowed"), "die Bremse ist fort")
	assert_false(run.has_method("reset_press_cycle"))

func test_two_grips_in_a_row_both_book() -> void:
	var first := _card({0: StampNet.value_cell(2)})
	var second := _card({0: StampNet.value_cell(3)})
	var die := _die()
	var before := int(die.faces[0])
	assert_false(run.apply_series(_uids([first]), die, null, _rng(1)).is_empty())
	assert_false(run.apply_series(_uids([second]), die, null, _rng(1)).is_empty(),
		"der zweite Griff bucht genauso")
	assert_eq(int(die.faces[0]), before + 5, "beide Serien stehen auf dem Würfel")
	assert_eq(run.owned_packs.size(), 0, "und beide Karten sind verbraucht")

# --- Die Buchung --------------------------------------------------------------

func test_the_projection_is_written_through_the_real_write_paths() -> void:
	var card := _card({0: StampNet.value_cell(4),
		1: StampNet.material_cell(DieMaterial.GOLD),
		2: StampNet.rune_cell(Rune.CAST),
		3: StampNet.pointer_cell(1)})
	var die := _die()
	var before := int(die.faces[0])
	run.apply_series(_uids([card]), die, null, _rng(1))
	assert_eq(int(die.faces[0]), before + 4)
	assert_eq(String(die.materials[1]), DieMaterial.GOLD)
	assert_eq(int(die.levels[1]), 1, "frische Farbe liegt unveredelt")
	assert_eq(String(die.runes[2]), Rune.CAST)
	assert_eq(int(die.pointers[3]), 1)

func test_the_double_material_lands_doped_on_the_die() -> void:
	var first := _card({2: StampNet.material_cell(DieMaterial.RUBY)})
	var second := _card({2: StampNet.material_cell(DieMaterial.RUBY)})
	run.hub_level = 3
	run.apply_series(_uids([first, second]), _die(), null, _rng(1))
	assert_eq(int(_die().levels[2]), DieMaterial.MAX_LEVEL)

func test_the_preview_is_the_same_calculation_as_the_booking() -> void:
	var card := _card({0: StampNet.value_cell(3), 5: StampNet.value_cell(2)})
	var preview := run.resolve_series(_uids([card]), _die())
	run.apply_series(_uids([card]), _die(), null, _rng(1))
	assert_eq(_die().faces, preview["faces_after"])

func test_the_preview_mutates_nothing() -> void:
	var card := _card({0: StampNet.value_cell(3)})
	var faces := _die().faces.duplicate()
	run.resolve_series(_uids([card]), _die())
	assert_eq(_die().faces, faces)
	assert_eq(run.owned_packs.size(), 1)

func test_the_projection_reports_the_pool_change() -> void:
	watch_signals(run)
	run.apply_series(_uids([_card({0: StampNet.value_cell(1)})]), _die(), null, _rng(1))
	assert_signal_emitted(run, "pool_changed")
	assert_signal_emitted(run, "packs_changed")

# --- Die Serie: Reihenfolge und Länge -----------------------------------------

## Die uids stehen in STECKREIHENFOLGE - sie und nicht die Magazin-Ordnung
## entscheidet, was zuerst rechnet.
func test_the_order_of_the_uids_is_the_order_of_the_series() -> void:
	var value := _card({0: StampNet.value_cell(4)})
	var doubler := _card({0: StampNet.operator_cell(StampNet.OP_DOUBLER)})
	run.hub_level = 3
	var late := run.resolve_series(_uids([value, doubler]), _die())
	var early := run.resolve_series(_uids([doubler, value]), _die())
	assert_eq(int(late["bonus"][0]), 8)
	assert_eq(int(early["bonus"][0]), 4)

func test_the_series_stops_at_the_slot_count() -> void:
	var cards: Array[Pack] = []
	for i in 8:
		cards.append(_card({0: StampNet.value_cell(1)}))
	run.hub_level = 1
	assert_eq(run.series_slots(), 6, "sechs Schächte ab Runde 1")
	assert_eq(int(run.resolve_series(_uids(cards), _die())["bonus"][0]), 6,
		"nur die ersten sechs Karten rechnen mit")

func test_a_uid_listed_twice_counts_once() -> void:
	var card := _card({0: StampNet.value_cell(3)})
	var uids: Array[int] = [card.pack_uid, card.pack_uid]
	assert_eq(int(run.resolve_series(uids, _die())["bonus"][0]), 3)

func test_an_unknown_uid_is_skipped() -> void:
	var card := _card({0: StampNet.value_cell(3)})
	var uids: Array[int] = [9999, card.pack_uid]
	assert_eq(int(run.resolve_series(uids, _die())["bonus"][0]), 3)

func test_a_series_without_a_die_presses_nothing() -> void:
	var card := _card({0: StampNet.value_cell(3)})
	assert_true(run.apply_series(_uids([card]), null, null, _rng(1)).is_empty())
	assert_eq(run.owned_packs.size(), 1, "und die Karte liegt noch da")

# --- Karten-Verbrauch ---------------------------------------------------------

func test_every_card_of_the_series_is_consumed() -> void:
	var cards: Array[Pack] = [_card({0: StampNet.value_cell(1)}),
		_card({1: StampNet.value_cell(1)})]
	run.hub_level = 3
	run.apply_series(_uids(cards), _die(), null, _rng(1))
	assert_eq(run.owned_packs.size(), 0)

func test_cards_outside_the_series_stay() -> void:
	var used := _card({0: StampNet.value_cell(1)})
	_card({1: StampNet.value_cell(1)})
	run.apply_series(_uids([used]), _die(), null, _rng(1))
	assert_eq(run.owned_packs.size(), 1, "die ungesteckte Karte bleibt liegen")

# --- Die vier Katalysatoren ---------------------------------------------------

## Die Erdungsklemme legt ihren Term weiter bei - seit dem unbegrenzten Griff
## liest ihn nur niemand mehr. OFFEN: ihre neue Wirkung.
func test_the_ground_clamp_still_reports_its_term() -> void:
	var clamp := Pack.catalyst(Pack.CATALYST_GROUND)
	var packs: Array[Pack] = [clamp]
	assert_true(bool(GameRun.catalyst_terms(packs)["free"]),
		"der Term steht, wirkungslos")

## Der Taktgeber bucht seinen Platz weiter - der Deckel der Welle U (sechs Karten
## = ein Block) klemmt ihn nur noch weg. OFFEN: seine neue Wirkung.
func test_the_timer_buys_a_permanent_slot() -> void:
	var card := _card({0: StampNet.value_cell(1)})
	var timer := run.grant_pack(Pack.catalyst(Pack.CATALYST_TIMER))
	run.hub_level = 3
	var before := run.series_slots()
	run.apply_series(_uids([card, timer]), _die(), null, _rng(1))
	assert_eq(run.series_slot_bonus, 1, "der Bonus bleibt für den Lauf gebucht")
	assert_eq(run.series_slots(), before, "aber der Deckel gibt keinen Platz mehr her")

func test_the_propellant_lifts_every_filled_number_cell() -> void:
	var card := _card({0: StampNet.value_cell(2), 3: StampNet.value_cell(1)})
	var fuel := run.grant_pack(Pack.catalyst(Pack.CATALYST_PROPELLANT))
	run.hub_level = 3
	var die := _die()
	var before := die.faces.duplicate()
	run.apply_series(_uids([card, fuel]), die, null, _rng(1))
	assert_eq(int(die.faces[0]), int(before[0]) + 3)
	assert_eq(int(die.faces[3]), int(before[3]) + 2)
	assert_eq(int(die.faces[1]), int(before[1]), "leere Zellen bleiben leer")

func test_the_matrix_hits_a_second_die_with_halved_numbers() -> void:
	var card := _card({0: StampNet.value_cell(5),
		1: StampNet.material_cell(DieMaterial.GOLD)})
	var matrix := run.grant_pack(Pack.catalyst(Pack.CATALYST_MATRIX))
	run.hub_level = 3
	var first := run.owned_pool[0]
	var second := run.owned_pool[1]
	var before := int(second.faces[0])
	run.apply_series(_uids([card, matrix]), first, second, _rng(1))
	assert_eq(int(second.faces[0]), before + 2, "5 / 2 abgerundet")
	assert_eq(String(second.materials[1]), "", "nur der Zahl-Kanal reist mit")
	assert_eq(String(first.materials[1]), DieMaterial.GOLD)

func test_without_the_matrix_the_second_die_is_untouched() -> void:
	var card := _card({0: StampNet.value_cell(5)})
	var second := run.owned_pool[1]
	var before := second.faces.duplicate()
	run.apply_series(_uids([card]), run.owned_pool[0], second, _rng(1))
	assert_eq(second.faces, before)

## Eine Serie aus lauter Katalysatoren prägt nicht - sie verstärkt eine Serie,
## sie ist keine.
func test_a_series_of_only_catalysts_does_nothing() -> void:
	var fuel := run.grant_pack(Pack.catalyst(Pack.CATALYST_PROPELLANT))
	assert_true(run.apply_series(_uids([fuel]), _die(), null, _rng(1)).is_empty())
	assert_eq(run.owned_packs.size(), 1, "und die Karte liegt noch da")
