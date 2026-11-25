extends GutTest
## Die Werkstatt-Sitzung an GameRun: EINE Prägung je Runde, die freischaltbaren
## Scheiben, die atomare Buchung, der Karten-Verbrauch und die Katalysatoren.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.drum_slots = GameRun.SERIES_SLOT_CAP

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

# --- EINE Prägung je Runde (Spieler-Entscheid 2026-11-23) -----------------------

func test_a_second_press_in_the_same_round_books_nothing() -> void:
	var first := _card({0: StampNet.value_cell(2)})
	var second := _card({0: StampNet.value_cell(3)})
	var die := _die()
	var before := int(die.faces[0])
	assert_false(run.apply_series(_uids([first]), die, _rng(1)).is_empty())
	assert_false(run.press_allowed(), "die Prägung der Runde ist verbraucht")
	assert_true(run.apply_series(_uids([second]), die, _rng(1)).is_empty(),
		"der zweite Griff bucht nichts")
	assert_eq(int(die.faces[0]), before + 2)
	assert_eq(run.owned_packs.size(), 1, "und die zweite Karte liegt noch da")

func test_the_round_start_frees_the_press_again() -> void:
	var first := _card({0: StampNet.value_cell(2)})
	var second := _card({0: StampNet.value_cell(3)})
	var die := _die()
	run.apply_series(_uids([first]), die, _rng(1))
	run.apply_round_start_charms()
	assert_true(run.press_allowed())
	assert_false(run.apply_series(_uids([second]), die, _rng(1)).is_empty())

func test_the_grounding_clamp_presses_without_using_the_press() -> void:
	var card := _card({0: StampNet.value_cell(2)})
	var clamp := run.grant_pack(Pack.catalyst(Pack.CATALYST_GROUND))
	assert_false(run.apply_series(_uids([card, clamp]), _die(), _rng(1)).is_empty())
	assert_true(run.press_allowed(), "die Klemme verbraucht die Prägung nicht")

func test_the_grounding_clamp_presses_even_after_the_press_is_used() -> void:
	run.apply_series(_uids([_card({0: StampNet.value_cell(2)})]), _die(), _rng(1))
	var card := _card({0: StampNet.value_cell(3)})
	var clamp := run.grant_pack(Pack.catalyst(Pack.CATALYST_GROUND))
	assert_true(run.series_press_allowed(_uids([card, clamp])))
	assert_false(run.apply_series(_uids([card, clamp]), _die(), _rng(1)).is_empty())

# --- Die SCHEIBEN der Walze werden freigeschaltet (2026-11-23) --------------------

func test_a_run_starts_with_two_slices() -> void:
	var fresh := GameRun.new_run()
	assert_eq(fresh.series_slots(), GameRun.START_DRUM_SLOTS)
	assert_eq(fresh.drum_slot_price(), 3, "die dritte kostet 3")

func test_each_slice_costs_the_count_so_far_plus_one() -> void:
	var fresh := GameRun.new_run()
	fresh.energy = 50
	var paid: Array[int] = []
	while fresh.drum_slot_price() > 0:
		var price := fresh.drum_slot_price()
		assert_true(fresh.buy_drum_slot())
		paid.append(price)
	assert_eq(paid, [3, 4, 5, 6] as Array[int])
	assert_eq(fresh.series_slots(), 6)
	assert_eq(fresh.energy, 50 - 18)
	assert_false(fresh.buy_drum_slot(), "eine siebte gibt es nicht")

func test_a_slice_without_the_energy_stays_locked() -> void:
	var fresh := GameRun.new_run()
	fresh.energy = 2
	assert_false(fresh.buy_drum_slot())
	assert_eq(fresh.series_slots(), 2)
	assert_eq(fresh.energy, 2)

# --- Die Buchung --------------------------------------------------------------

func test_the_projection_is_written_through_the_real_write_paths() -> void:
	var card := _card({0: StampNet.value_cell(4),
		1: StampNet.material_cell(DieMaterial.GOLD),
		2: StampNet.rune_cell(Rune.AFTERGLOW)})
	var die := _die()
	var before := int(die.faces[0])
	run.apply_series(_uids([card]), die, _rng(1))
	assert_eq(int(die.faces[0]), before + 4)
	assert_eq(String(die.materials[1]), DieMaterial.GOLD)
	assert_eq(int(die.levels[1]), 1, "frische Farbe liegt unveredelt")
	assert_eq(String(die.runes[2]), Rune.AFTERGLOW)

## Der Lötkolben reist als EINE Quelle (series_terms) - Vorschau und Buchung
## lesen sie beide.
func test_the_soldering_iron_preview_matches_the_booking() -> void:
	run.owned_charms.append(Charm.soldering_iron())
	var values := _card({0: StampNet.value_cell(6), 1: StampNet.value_cell(4)})
	var pointer := _card({0: StampNet.pointer_cell(1)})
	var die := _die()
	var uids := _uids([values, pointer])
	var preview := run.resolve_series(uids, die)
	assert_eq(int(preview["bonus"][1]), 10, "dazugelötet: 4 + 6")
	var before := int(die.faces[1])
	var booked: Dictionary = run.apply_series(uids, die, _rng(1))["projection"]
	assert_eq(booked["bonus"], preview["bonus"], "Vorschau == Buchung")
	assert_eq(int(die.faces[1]), before + 10)

func test_without_the_soldering_iron_the_copy_overwrites() -> void:
	var values := _card({0: StampNet.value_cell(6), 1: StampNet.value_cell(4)})
	var pointer := _card({0: StampNet.pointer_cell(1)})
	assert_eq(int(run.resolve_series(_uids([values, pointer]), _die())["bonus"][1]), 6)
	assert_false(bool(run.series_terms([] as Array[Pack])["pointer_add"]))

func test_the_double_material_lands_doped_on_the_die() -> void:
	var first := _card({2: StampNet.material_cell(DieMaterial.RUBY)})
	var second := _card({2: StampNet.material_cell(DieMaterial.RUBY)})
	run.apply_series(_uids([first, second]), _die(), _rng(1))
	assert_eq(int(_die().levels[2]), DieMaterial.MAX_LEVEL)

func test_the_preview_is_the_same_calculation_as_the_booking() -> void:
	var card := _card({0: StampNet.value_cell(3), 5: StampNet.value_cell(2)})
	var preview := run.resolve_series(_uids([card]), _die())
	run.apply_series(_uids([card]), _die(), _rng(1))
	assert_eq(_die().faces, preview["faces_after"])

func test_the_preview_mutates_nothing() -> void:
	var card := _card({0: StampNet.value_cell(3)})
	var faces := _die().faces.duplicate()
	run.resolve_series(_uids([card]), _die())
	assert_eq(_die().faces, faces)
	assert_eq(run.owned_packs.size(), 1)

func test_the_projection_reports_the_pool_change() -> void:
	watch_signals(run)
	run.apply_series(_uids([_card({0: StampNet.value_cell(1)})]), _die(), _rng(1))
	assert_signal_emitted(run, "pool_changed")
	assert_signal_emitted(run, "packs_changed")

# --- Die Serie: Reihenfolge und Länge -----------------------------------------

## Die uids stehen in STECKREIHENFOLGE - sie und nicht die Magazin-Ordnung
## entscheidet, was zuerst rechnet.
func test_the_order_of_the_uids_is_the_order_of_the_series() -> void:
	var value := _card({0: StampNet.value_cell(4)})
	var doubler := _card({0: StampNet.operator_cell(StampNet.OP_DOUBLER)})
	var late := run.resolve_series(_uids([value, doubler]), _die())
	var early := run.resolve_series(_uids([doubler, value]), _die())
	assert_eq(int(late["bonus"][0]), 8)
	assert_eq(int(early["bonus"][0]), 4)

func test_the_series_stops_at_the_slot_count() -> void:
	var cards: Array[Pack] = []
	for i in 8:
		cards.append(_card({0: StampNet.value_cell(1)}))
	assert_eq(run.series_slots(), 6, "sechs Scheiben, alle frei")
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
	assert_true(run.apply_series(_uids([card]), null, _rng(1)).is_empty())
	assert_eq(run.owned_packs.size(), 1, "und die Karte liegt noch da")

# --- Karten-Verbrauch ---------------------------------------------------------

func test_every_card_of_the_series_is_consumed() -> void:
	var cards: Array[Pack] = [_card({0: StampNet.value_cell(1)}),
		_card({1: StampNet.value_cell(1)})]
	run.apply_series(_uids(cards), _die(), _rng(1))
	assert_eq(run.owned_packs.size(), 0)

func test_cards_outside_the_series_stay() -> void:
	var used := _card({0: StampNet.value_cell(1)})
	_card({1: StampNet.value_cell(1)})
	run.apply_series(_uids([used]), _die(), _rng(1))
	assert_eq(run.owned_packs.size(), 1, "die ungesteckte Karte bleibt liegen")

# --- Die Katalysatoren ---------------------------------------------------

## Die Erdungsklemme legt ihren Term weiter bei - seit dem unbegrenzten Griff
## liest ihn nur niemand mehr. OFFEN: ihre neue Wirkung.
func test_the_ground_clamp_still_reports_its_term() -> void:
	var clamp := Pack.catalyst(Pack.CATALYST_GROUND)
	var packs: Array[Pack] = [clamp]
	assert_true(bool(GameRun.catalyst_terms(packs)["free"]),
		"der Term steht, wirkungslos")

## Der TAKTGEBER ist am 2026-10-26 gestrichen (Spieler-Entscheid) - er hob seit dem
## harten Deckel 6 nichts mehr, und eine Karte ohne Wirkung ist keine.
func test_the_timer_is_gone() -> void:
	assert_false(Pack.CATALYSTS.has("timer"), "er steht in keinem Katalog mehr")
	assert_false(Pack.SPECIAL_ROLL_WEIGHTS.has("timer"), "und wird nirgends gewuerfelt")
	assert_null(Pack.catalyst("timer"), "seine Kassette gibt es nicht")

func test_the_propellant_lifts_every_filled_number_cell() -> void:
	var card := _card({0: StampNet.value_cell(2), 3: StampNet.value_cell(1)})
	var fuel := run.grant_pack(Pack.catalyst(Pack.CATALYST_PROPELLANT))
	var die := _die()
	var before := die.faces.duplicate()
	run.apply_series(_uids([card, fuel]), die, _rng(1))
	assert_eq(int(die.faces[0]), int(before[0]) + 3)
	assert_eq(int(die.faces[3]), int(before[3]) + 2)
	assert_eq(int(die.faces[1]), int(before[1]), "leere Zellen bleiben leer")

# --- Die KÜHL-Karten: sie wirken nach der Hitze des Prägens -------------------

func test_a_multiplier_scales_only_the_upgrades_before_it() -> void:
	var value := _card({0: StampNet.value_cell(3)})
	var times := _card({0: StampNet.factor_cell(4)})
	var die := _die()
	var base: int = die.faces[0]
	run.apply_series(_uids([value, times]), die, _rng(1))
	assert_eq(int(die.faces[0]), base + 12, "die Grundzahl bleibt, der Bonus wird ×4")

func test_a_multiplier_before_the_upgrade_multiplies_nothing() -> void:
	var times := _card({0: StampNet.factor_cell(4)})
	var value := _card({0: StampNet.value_cell(3)})
	var die := _die()
	var base: int = die.faces[0]
	run.apply_series(_uids([times, value]), die, _rng(1))
	assert_eq(int(die.faces[0]), base + 3)

## Eine Serie aus lauter Katalysatoren prägt nicht - sie verstärkt eine Serie,
## sie ist keine.
func test_a_series_of_only_catalysts_does_nothing() -> void:
	var fuel := run.grant_pack(Pack.catalyst(Pack.CATALYST_PROPELLANT))
	assert_true(run.apply_series(_uids([fuel]), _die(), _rng(1)).is_empty())
	assert_eq(run.owned_packs.size(), 1, "und die Karte liegt noch da")

# --- Das Prägen HEIZT ------------------------------------------------------------
## Er ist ein erzwungenes +1 auf den Zielwürfel; an der Spitze brennt der Würfel
## sicher durch, und ein durchgebrannter Würfel wird gar nicht erst geprägt.
