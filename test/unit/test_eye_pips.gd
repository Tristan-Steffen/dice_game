extends GutTest
## Augen-Pips: die Stückelung der fliegenden Augen und das, was die Schrittliste
## über eine Wertwandlung mitschreibt (value_before, Ansteckungs-Betrag,
## Eigenverlust, Empfänger). Reines Mitschreiben - die Summen der Wertung dürfen
## sich davon nicht bewegen.

func _d(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _m(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _ids(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

const NO_CHARMS: Array[String] = []

# --- Stückelung ------------------------------------------------------------------

func test_eyes_split_greedily_into_fives_and_ones():
	assert_eq(TableScreen.split_eyes(11), _d([5, 5, 1]))
	assert_eq(TableScreen.split_eyes(4), _d([1, 1, 1, 1]))
	assert_eq(TableScreen.split_eyes(5), _d([5]))

func test_nothing_to_carry_launches_no_pip():
	assert_eq(TableScreen.split_eyes(0), _d([]))
	assert_eq(TableScreen.split_eyes(-3), _d([]), "ein negativer Betrag ist kein Regen")

func test_the_split_sums_back_to_its_amount():
	for amount in range(1, 40):
		var total := 0
		for pip: int in TableScreen.split_eyes(amount):
			total += pip
		assert_eq(total, amount, "%d geht verloren" % amount)

# --- Mitschrift der Wandlung -----------------------------------------------------

## Hand aus zwei Achtern wie in test_essence_effects: Slot 0 trägt die Seele,
## Slot 1 zählt danach. mats = Seiten-Material je Slot.
func _hand(sets: Dictionary, charm_ids: Array[String] = NO_CHARMS,
		mats: Array[String] = _m(["", ""])) -> Dictionary:
	var ctx := {DiceScoring.CTX_ESSENCE_SET: sets}
	return ScoreBreakdown.build(DiceScoring.TWO_KIND, _d([8, 8]), charm_ids, false, mats, {}, ctx)

## Erste Zündung eines Slots aus der Schrittliste.
func _first_firing(breakdown: Dictionary, slot: int) -> Dictionary:
	for step: Dictionary in breakdown["die_steps"]:
		if int(step["slot"]) != slot:
			continue
		for group: Dictionary in step["die_triggers"]:
			for firing: Dictionary in group["firings"]:
				return firing
	return {}

func test_every_firing_records_the_value_it_started_from():
	var firing := _first_firing(_hand({0: _ids([Essence.MIASMA])}), 0)
	var before: int = firing["value_before"]
	assert_eq(before, 8, "der physische Wert vor der Wandlung")

func test_the_infection_records_amount_loss_and_recipients():
	var firing := _first_firing(_hand({0: _ids([Essence.MIASMA])}), 0)
	var amount: int = firing["miasma_amount"]
	var loss: int = firing["miasma_self_loss"]
	var recipients: Array = firing["miasma_recipients"]
	assert_eq(amount, 4, "die abgerundete Hälfte der 8")
	assert_eq(loss, 4, "ohne Weihrauchfass verliert die Quelle genau das")
	assert_eq(recipients, _d([1]), "jeder ANDERE gewertete Würfel")

## Die Identität, auf der die Pip-Rechnung steht: value_after ist um den
## Eigenverlust schon gemindert, der Stand nach der Wandlung liegt um ihn höher.
func test_value_after_plus_self_loss_is_the_state_before_the_exhale():
	var firing := _first_firing(_hand({0: _ids([Essence.MIASMA])}), 0)
	var before: int = firing["value_before"]
	var after: int = firing["value_after"]
	var loss: int = firing["miasma_self_loss"]
	assert_eq(after, 4, "8 minus die abgegebene Hälfte")
	assert_eq(after + loss, before, "ohne eigenes Material wandelt nur der Aushauch")

func test_glass_and_miasma_split_into_two_volleys():
	# 9 wird zu 8 (Glas frisst 1), davon geht die Hälfte 4 weg - Endstand 4.
	var ctx := {DiceScoring.CTX_ESSENCE_SET: {0: _ids([Essence.MIASMA])}}
	var mats := _m([DieMaterial.GLASS, ""])
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d([9, 9]), NO_CHARMS, false, mats, {}, ctx)
	var firing := _first_firing(breakdown, 0)
	var before: int = firing["value_before"]
	var after: int = firing["value_after"]
	var loss: int = firing["miasma_self_loss"]
	assert_eq(before, 9)
	assert_eq(after, 4)
	assert_eq(after + loss, 8, "Volley A trägt 9 -> 8, Volley B 8 -> 4")

func test_the_censer_records_the_spread_without_a_self_loss():
	var firing := _first_firing(_hand({0: _ids([Essence.MIASMA])}, _ids([Charm.CENSER])), 0)
	var amount: int = firing["miasma_amount"]
	var loss: int = firing["miasma_self_loss"]
	assert_eq(amount, 4, "angesteckt wird trotzdem")
	assert_eq(loss, 0, "die Quelle gibt nichts her")
	var after: int = firing["value_after"]
	assert_eq(after, 8, "und schrumpft darum nicht")

func test_a_protected_face_records_no_infection_at_all():
	var firing := _first_firing(_hand({0: _ids([Essence.MIASMA, Essence.NITROGEN])}), 0)
	assert_false(firing.has("miasma_amount"), "Stickstoff wehrt die Halbierung ab")
	assert_false(firing.has("miasma_recipients"))
	var before: int = firing["value_before"]
	var after: int = firing["value_after"]
	assert_eq(after, before, "und dann bewegt sich nichts")

func test_a_burn_in_rune_blocks_the_record_too():
	var ctx := {
		DiceScoring.CTX_ESSENCE_SET: {0: _ids([Essence.MIASMA])},
		DiceScoring.CTX_RUNES: {0: _ids([Rune.BURN_IN])},
	}
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d([8, 8]), NO_CHARMS, false, _m(["", ""]), {}, ctx)
	var firing := _first_firing(breakdown, 0)
	assert_false(firing.has("miasma_amount"), "der Einbrand hält seine Seite")

func test_a_soulless_die_records_neither_amount_nor_recipients():
	var firing := _first_firing(_hand({0: _ids([Essence.MIASMA])}), 1)
	assert_false(firing.has("miasma_amount"), "Slot 1 hat keine Seele")
	assert_true(firing.has("value_before"), "die Mitschrift des Werts steht trotzdem")

func test_the_record_leaves_the_sums_untouched():
	var ctx := {DiceScoring.CTX_ESSENCE_SET: {0: _ids([Essence.MIASMA])}}
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d([8, 8]), NO_CHARMS, false, _m(["", ""]), {}, ctx)
	var scored := DiceScoring.score_category(DiceScoring.TWO_KIND, _d([8, 8]), NO_CHARMS, false, _m(["", ""]), {}, ctx)
	assert_eq(int(breakdown["total"]), scored, "Mitschreiben ist keine Wirkung")
