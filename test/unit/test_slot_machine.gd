extends GutTest
## Tests der Fumble-Automaten-Logik (SlotMachine/SlotPrize): Sitzungszustand,
## Fumble löscht den Topf, ein Dreh je Automat, Multiplikator, Reset. Die
## Fumble-Wahrscheinlichkeit wird je Test auf 0/1 gesetzt (deterministisch).

func _bank(never_fumble: bool = true) -> SlotMachine:
	var bank := SlotMachine.new()
	bank.fumble_chance = 0.0 if never_fumble else 1.0
	return bank

func test_spin_without_fumble_collects_a_prize() -> void:
	var bank := _bank()
	var prize := bank.spin(0)
	assert_not_null(prize)
	assert_ne(prize.kind, SlotPrize.Kind.FUMBLE)
	assert_eq(bank.hit_count(), 1)
	assert_false(bank.busted)

func test_fumble_wipes_pot_and_ends_session() -> void:
	var bank := _bank()
	bank.spin(0)
	bank.spin(1)
	assert_eq(bank.hit_count(), 2, "zwei Treffer im Topf")
	bank.fumble_chance = 1.0
	var prize := bank.spin(2)
	assert_eq(prize.kind, SlotPrize.Kind.FUMBLE)
	assert_eq(bank.hit_count(), 0, "Fumble löscht den Topf")
	assert_true(bank.busted)

func test_each_machine_spins_once_per_session() -> void:
	var bank := _bank()
	assert_true(bank.can_spin(0))
	bank.spin(0)
	assert_false(bank.can_spin(0), "derselbe Automat nicht zweimal")
	assert_null(bank.spin(0), "zweiter Dreh am selben Automaten: nichts")
	assert_eq(bank.hit_count(), 1)

func test_no_spins_after_a_fumble() -> void:
	var bank := _bank(false)  # sofort Fumble
	bank.spin(0)
	assert_true(bank.busted)
	assert_false(bank.can_spin(1), "nach dem Fumble ist die Sitzung dicht")
	assert_null(bank.spin(1))

func test_multiplier_scales_with_hits() -> void:
	var bank := _bank()
	assert_eq(bank.multiplier(), 1, "ohne Treffer ×1")
	bank.spin(0)
	assert_eq(bank.multiplier(), 1)
	bank.spin(1)
	assert_eq(bank.multiplier(), 2, "zwei Treffer ×2")
	bank.spin(2)
	assert_eq(bank.multiplier(), 3, "drei Treffer ×3")

func test_reset_session_reopens_all_machines() -> void:
	var bank := _bank()
	bank.spin(0)
	bank.spin(1)
	bank.reset_session()
	assert_eq(bank.hit_count(), 0)
	assert_false(bank.busted)
	for i in SlotMachine.MACHINE_COUNT:
		assert_true(bank.can_spin(i), "Automat %d wieder frei" % i)

func test_higher_machines_have_richer_tables() -> void:
	# Automat III bietet mehr Sorten (Charm/Würfel) als Automat I.
	assert_gt(SlotMachine.PRIZE_TABLES[2].size(), SlotMachine.PRIZE_TABLES[0].size())
	assert_gt(SlotMachine.SPIN_PRICES[2], SlotMachine.SPIN_PRICES[0], "höherer Automat teurer")

func test_prize_from_spec_resolves_content() -> void:
	var money := SlotPrize.from_spec({"kind": "money", "amount": 12})
	assert_eq(money.kind, SlotPrize.Kind.MONEY)
	assert_eq(money.money, 12)
	var sigil := SlotPrize.from_spec({"kind": "sigil", "count": 2, "floor": Sigil.Rarity.COMMON})
	assert_eq(sigil.kind, SlotPrize.Kind.SIGIL)
	assert_eq(sigil.sigils.size(), 2)
	var charm := SlotPrize.from_spec({"kind": "charm", "floor": Charm.RARITY_COMMON})
	assert_eq(charm.kind, SlotPrize.Kind.CHARM)
	assert_not_null(charm.charm)
