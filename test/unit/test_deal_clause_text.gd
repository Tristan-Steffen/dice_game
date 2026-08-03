extends GutTest
## Tier-1-Tests des Klausel-Wirkungstexts (DealClause.text_for). Die Vertragskarte
## und die Deal-Marken lesen NUR hier - sie kennen keinen GameRun. Der
## Winkeladvokat verdoppelt die Buchung, also muss er auch die Zahl verdoppeln,
## die auf der Karte steht.

## Klauseln, die der Winkeladvokat sichtbar verändert: id -> verdoppelter Text.
const DOUBLED := {
	DealClause.ADVANCE_PAYMENT: "+24$ auf die Hand",
	DealClause.BLANK_CHEQUE: "+80$ auf die Hand",
	DealClause.SEED_CAPITAL: "+2 Energie sofort",
	DealClause.SEED_CAPITAL_II: "+4 Energie sofort",
	DealClause.SAVINGS_BONUS: "+2$ je übrigem Würfel",
	DealClause.INSURANCE_FRAUD: "Jeder Farkle zahlt 30$ Trost",
	DealClause.HIGH_VOLTAGE: "+6 Überladungs-Stufen",
	DealClause.ODDS_BONUS: "Nebenwetten zahlen vierfach",
	DealClause.TOURNAMENT_NIGHT: "Nebenwetten zahlen vierfach",
	DealClause.HAPPY_HOUR: "Alles Geld dieser Runde vierfach",
	DealClause.ALL_ON_RED: "Alles Geld dieser Runde sechsfach",
	DealClause.INTEREST: "Rundenende: +2$ je vollen 10$ Guthaben",
	DealClause.DOUBLE_LOADER: "Überladungs-Stufen prägen 4 Energie",
	DealClause.CALIBRATION: "Benchmark −75%",
	DealClause.CASH_DISCOUNT: "Ladenware 36% günstiger",
	DealClause.GOLD_VEIN: "+20$ je geräumter Überladungs-Stufe",
}

func test_text_for_returns_the_plain_text_without_the_charm():
	for clause in DealClause.all():
		assert_eq(DealClause.text_for(clause.id), clause.text, clause.id)
		assert_eq(DealClause.text_for(clause.id, 1), clause.text, clause.id)

func test_text_for_doubles_every_quantitative_bonus():
	for clause_id: String in DOUBLED:
		assert_eq(DealClause.text_for(clause_id, 2), String(DOUBLED[clause_id]), clause_id)
		assert_ne(DealClause.text_for(clause_id, 2), DealClause.find(clause_id).text,
			"%s müsste sich lesbar ändern" % clause_id)

func test_text_for_leaves_booleans_and_maluses_untouched():
	# Wer keine Zahl trägt, hat nichts zu verdoppeln - und ein Malus schon gar nicht.
	for clause in DealClause.all():
		if DOUBLED.has(clause.id):
			continue
		assert_eq(DealClause.text_for(clause.id, 2), clause.text, clause.id)

func test_every_doubled_clause_is_a_real_bonus():
	for clause_id: String in DOUBLED:
		var clause := DealClause.find(clause_id)
		assert_not_null(clause, clause_id)
		assert_eq(clause.kind, DealClause.Kind.BONUS, "%s ist kein Bonus" % clause_id)

func test_an_unknown_id_stays_silent():
	assert_eq(DealClause.text_for("gibt_es_nicht"), "")
	assert_eq(DealClause.text_for("gibt_es_nicht", 2), "")
