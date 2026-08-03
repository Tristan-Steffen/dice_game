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

func test_the_front_runner_pays_at_the_declared_head() -> void:
	var dice := _p([2, 2, 5, 5])
	var ids := _ids([Charm.FRONT_RUNNER])
	var shape := DiceScoring.hand_shape(DiceScoring.TWO_PAIR, dice, ids,
		{DiceScoring.CTX_PLAYER_ORDER: [1, 0, 3, 2]})
	var order: Array[int] = shape["order"]
	assert_eq(CharmEffects.die_charm_base_at(0, 1, DiceScoring.TWO_PAIR, dice, ids, {}, order), 14,
		"die ganze Augensumme am angesagten Kopf")
	assert_eq(CharmEffects.die_charm_base_at(0, 2, DiceScoring.TWO_PAIR, dice, ids, {}, order), 0,
		"der kanonische Kopf zahlt nicht mehr")
