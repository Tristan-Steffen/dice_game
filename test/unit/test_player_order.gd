extends GutTest
## Die vom Spieler gelegte Zählreihenfolge. Sie ist eine ANSAGE: liegt sie an,
## bestimmt sie die Auslöse-Folge; fehlt sie, gilt exakt die alte kanonische
## Regel. Beides muss gepinnt sein - das eine ist das Feature, das andere die
## Rückfall-Sicherheit.

func _p(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _ids(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _m(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

# --- Ohne Ansage: alles wie vorher ---------------------------------------------------

func test_without_a_declared_order_the_canonical_rule_holds() -> void:
	var dice := _p([3, 6, 6, 1])
	var scored := _p([0, 1, 2, 3])
	assert_eq(DiceScoring.trigger_order(scored, dice), _p([1, 2, 0, 3]),
		"Wert absteigend, bei Gleichstand der kleinere Slot")

func test_an_empty_declared_order_changes_nothing() -> void:
	var dice := _p([3, 6, 6, 1])
	var scored := _p([0, 1, 2, 3])
	assert_eq(DiceScoring.trigger_order(scored, dice, []),
		DiceScoring.trigger_order(scored, dice), "leere Ansage = keine Ansage")

# --- Kombinations-erst: Blöcke vor Werten --------------------------------------------

func test_a_straight_orders_its_blocks_by_digit():
	# Fünf Einer-Blöcke: die Größe ist überall 1, also entscheidet die ZIFFER -
	# 14 und 13 zählen als 4 und 3 und rutschen hinter die 6 und die 5.
	var dice := _p([14, 13, 6, 5, 2])
	var all := _p([0, 1, 2, 3, 4])
	assert_eq(DiceScoring.trigger_order(all, dice, [], all), _p([2, 3, 0, 1, 4]))

func test_a_bigger_block_beats_a_higher_digit():
	# Full House: der Dreier-Block steht vorn, auch mit der kleineren Ziffer.
	var house := _p([3, 3, 3, 5, 5])
	var all := _p([0, 1, 2, 3, 4])
	assert_eq(DiceScoring.trigger_order(all, house, [], all), _p([0, 1, 2, 3, 4]))
	# Andersherum liegt der Dreier rechts - er zieht trotzdem nach vorn.
	var flipped := _p([5, 5, 5, 3, 3])
	assert_eq(DiceScoring.trigger_order(all, flipped, [], all), _p([0, 1, 2, 3, 4]))
	var mixed := _p([3, 3, 5, 5, 5])
	assert_eq(DiceScoring.trigger_order(all, mixed, [], all), _p([2, 3, 4, 0, 1]),
		"der Dreier-Block bleibt beisammen und steht vorn")

func test_two_pair_leads_with_the_higher_digit():
	var dice := _p([6, 6, 2, 2])
	var all := _p([0, 1, 2, 3])
	assert_eq(DiceScoring.trigger_order(all, dice, [], all), _p([0, 1, 2, 3]))
	var swapped := _p([2, 2, 6, 6])
	assert_eq(DiceScoring.trigger_order(all, swapped, [], all), _p([2, 3, 0, 1]))

func test_the_widened_dice_fall_in_behind_the_combination():
	# Paar Zweier plus ein bloß mitgewerteter Sechser (Krypton/Vollzähler):
	# der Block steht vorn, die 6 hängt sich dahinter.
	var dice := _p([2, 2, 6])
	assert_eq(DiceScoring.trigger_order(_p([0, 1, 2]), dice, [], _p([0, 1])), _p([0, 1, 2]))

func test_the_new_order_moves_the_total_on_purpose():
	# Von Hand nachgerechnet. Full House [4,4,2,2,2,1], Rubin auf Slot 2 (+4 Mult),
	# Xenon auf Slot 0 (Krit ×1,5). Basis = 28 + (2+2+2+4+4) = 42.
	# Reihe [2,3,4,0,1]: erst der Rubin (Mult 4 -> 8), dann der Krit (-> 12).
	# 42 × 12 = 504. Nach der ALTEN Wert-Ordnung [0,1,2,3,4] hätte der Krit vor
	# dem Rubin geschlagen: 4 × 1,5 = 6, +4 = 10, also 420. Genau diese
	# Verschiebung ist gewollt.
	var dice := _p([4, 4, 2, 2, 2, 1])
	var mats := _m(["", "", DieMaterial.RUBY, "", "", ""])
	var ctx := {DiceScoring.CTX_ESSENCES: {0: Essence.XENON}}
	assert_eq(DiceScoring.trigger_order(_p([0, 1, 2, 3, 4]), dice, [], _p([0, 1, 2, 3, 4])),
		_p([2, 3, 4, 0, 1]))
	assert_eq(DiceScoring.score_category(DiceScoring.FULL_HOUSE, dice, _ids([]), false, mats, {}, ctx), 504)

func test_without_a_combination_the_plain_value_rule_holds():
	# Ältere Aufrufer geben keine Kombination mit - dann gilt Wert/Slot wie eh und je.
	var dice := _p([3, 6, 6, 1])
	assert_eq(DiceScoring.trigger_order(_p([0, 1, 2, 3]), dice), _p([1, 2, 0, 3]))

# --- Mit Ansage ----------------------------------------------------------------------

func test_the_declared_order_decides_the_sequence() -> void:
	var dice := _p([3, 6, 6, 1])
	var scored := _p([0, 1, 2, 3])
	assert_eq(DiceScoring.trigger_order(scored, dice, [3, 0, 2, 1]), _p([3, 0, 2, 1]),
		"die gelegte Reihe IST die Zählreihenfolge")

func test_the_declared_order_beats_the_value_rank() -> void:
	# Genau das ist der Sinn: ein niedriger Würfel darf zuerst zählen.
	var dice := _p([1, 6])
	var scored := _p([0, 1])
	assert_eq(DiceScoring.trigger_order(scored, dice, [0, 1]), _p([0, 1]))
	assert_eq(DiceScoring.trigger_order(scored, dice, [1, 0]), _p([1, 0]))

func test_dice_outside_the_hand_are_ignored() -> void:
	# Die Ansage nennt ALLE liegenden Würfel; gewertet wird nur die Auswahl.
	var dice := _p([2, 5, 4, 6])
	var scored := _p([1, 3])
	assert_eq(DiceScoring.trigger_order(scored, dice, [2, 3, 0, 1]), _p([3, 1]),
		"nicht gewertete Würfel verschieben nichts")

func test_an_unnamed_die_falls_in_behind_canonically() -> void:
	var dice := _p([2, 5, 4])
	var scored := _p([0, 1, 2])
	assert_eq(DiceScoring.trigger_order(scored, dice, [2]), _p([2, 1, 0]),
		"der genannte zuerst, der Rest kanonisch dahinter")

# --- Keine Essenz greift mehr in die Reihenfolge ein ---------------------------------

func test_no_essence_moves_a_die_to_the_front_anymore() -> void:
	# Das Photonengas zählt heute Licht, nicht mehr zuerst: die Ansage regiert allein.
	var dice := _p([1, 6, 6])
	var scored := _p([0, 1, 2])
	assert_eq(DiceScoring.trigger_order(scored, dice, [2, 1, 0]), _p([2, 1, 0]))
	assert_eq(DiceScoring.trigger_order(scored, dice), _p([1, 2, 0]), "sonst kanonisch")

# --- Der ctx-Schlüssel ----------------------------------------------------------------

func test_the_order_travels_under_its_own_ctx_key() -> void:
	assert_eq(DiceScoring.CTX_PLAYER_ORDER, "player_order")

func test_the_breakdown_counts_in_the_declared_order() -> void:
	# Die Würfel-Schritte der Zeremonie folgen derselben Ansage wie die Wertung.
	var dice := _p([5, 5, 5])
	var ctx := {DiceScoring.CTX_PLAYER_ORDER: [2, 0, 1]}
	var breakdown := ScoreBreakdown.build(DiceScoring.THREE_KIND, dice,
		[] as Array[String], false, ["", "", ""] as Array[String], {}, ctx)
	var slots := []
	for step in breakdown["die_steps"]:
		slots.append(int(step["slot"]))
	assert_eq(slots, [2, 0, 1], "die Schritt-Folge ist die gelegte Reihe")

func test_the_breakdown_without_an_order_stays_canonical() -> void:
	var dice := _p([5, 5, 5])
	var breakdown := ScoreBreakdown.build(DiceScoring.THREE_KIND, dice,
		[] as Array[String], false, ["", "", ""] as Array[String], {}, {})
	var slots := []
	for step in breakdown["die_steps"]:
		slots.append(int(step["slot"]))
	assert_eq(slots, [0, 1, 2], "ohne Ansage die alte Folge")

# --- "Zuerst gewertet" ist der KOPF DER REIHE ----------------------------------------

func test_the_row_head_is_the_echo_die() -> void:
	var dice := _p([2, 2, 5, 5])
	var ids := _ids([Charm.ECHO_CHAMBER])
	var canonical := DiceScoring.hand_shape(DiceScoring.TWO_PAIR, dice, ids, {})
	assert_eq(int(canonical["echo_slot"]), 2, "ohne Ansage der Kopf der Wert-Reihe")
	var declared := DiceScoring.hand_shape(DiceScoring.TWO_PAIR, dice, ids,
		{DiceScoring.CTX_PLAYER_ORDER: [1, 0, 3, 2]})
	assert_eq(int(declared["echo_slot"]), 1, "die Ansage schiebt den Kopf")

func test_the_declared_head_takes_the_echo_retrigger() -> void:
	# Zwei Paare mit Echo-Kammer: der Kopf zählt zweimal. Kanonisch ist das die 5,
	# angesagt die 2 - der Unterschied sind drei Augen mal Mult 3.
	var dice := _p([2, 2, 5, 5])
	var ids := _ids([Charm.ECHO_CHAMBER])
	var mats := _m(["", "", "", ""])
	var canonical := DiceScoring.score_category(DiceScoring.TWO_PAIR, dice, ids, false, mats, {}, {})
	var declared := DiceScoring.score_category(DiceScoring.TWO_PAIR, dice, ids, false, mats, {},
		{DiceScoring.CTX_PLAYER_ORDER: [0, 1, 2, 3]})
	assert_eq(canonical - declared, 3 * 3)

func test_the_declared_order_leaves_the_front_runner_cold() -> void:
	# Der Vorreiter hängt seit dem Umbau an der ganzen Grube, nicht am Kopf der
	# Reihe - eine Ansage verschiebt seinen Beitrag also nicht mehr.
	var dice := _p([2, 2, 5, 5])
	var ids := _ids([Charm.FRONT_RUNNER])
	var mats := _m(["", "", "", ""])
	var canonical := DiceScoring.score_category(DiceScoring.TWO_PAIR, dice, ids, false, mats, {}, {})
	var declared := DiceScoring.score_category(DiceScoring.TWO_PAIR, dice, ids, false, mats, {},
		{DiceScoring.CTX_PLAYER_ORDER: [1, 0, 3, 2]})
	assert_eq(canonical, declared, "die Ansage ändert seinen Beitrag nicht")
	assert_eq(CharmEffects.charm_base_bonus_at(0, DiceScoring.TWO_PAIR, dice, _p([0, 1, 2, 3]), ids), 14,
		"die ganze Augensumme, einmal")
