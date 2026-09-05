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
	DealClause.SAVINGS_BONUS: "+2$ je übrigem Würfel",
	DealClause.INSURANCE_FRAUD: "Jeder Fumble zahlt 30$ Trost",
	DealClause.HIGH_VOLTAGE: "+6 Überladungs-Stufen",
	DealClause.ODDS_BONUS: "Nebenwetten zahlen vierfach",
	DealClause.HAPPY_HOUR: "Alles Geld dieser Runde vierfach",
	DealClause.ALL_ON_RED: "Alles Geld dieser Runde sechsfach",
	DealClause.INTEREST: "Rundenende: +2$ je vollen 10$ Guthaben",
	DealClause.DOUBLE_LOADER: "Überladungs-Stufen prägen 4 Energie",
	DealClause.CALIBRATION: "Benchmark −75%",
	DealClause.CASH_DISCOUNT: "Ladenware 36% günstiger",
	DealClause.GOLD_VEIN: "+20$ je geräumter Überladungs-Stufe",
	DealClause.WORK_HARDENING: "Jede ausgelöste Seite wächst dauerhaft um +2 Augen",
	DealClause.CHAIN_DRIVER: "Serienlänge +2",
	DealClause.DRAIN: "Jede Zündung eines gewerteten Würfels senkt seine Ladung um 2",
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

# --- Nachschlagen: EIN geteiltes Exemplar je id ----------------------------------
# find() lief je Frame dutzendfach durch die Überladungs-Stufen und baute jedes Mal
# alle 48 Klauseln neu - das war der Milliarden-Lag. Aufrufer LESEN nur.

func test_find_returns_the_same_instance_every_time():
	var first := DealClause.find(DealClause.CALIBRATION)
	assert_not_null(first)
	assert_eq(DealClause.find(DealClause.CALIBRATION), first, "kein Neubau je Aufruf")

func test_find_still_knows_every_registered_clause():
	for clause in DealClause.all():
		var found := DealClause.find(clause.id)
		assert_not_null(found, clause.id)
		assert_eq(found.id, clause.id)
		assert_eq(found.tier, clause.tier, clause.id)
		assert_eq(found.scope, clause.scope, clause.id)
		assert_eq(found.kind, clause.kind, clause.id)

func test_find_stays_silent_on_an_unknown_id():
	assert_null(DealClause.find("gibt_es_nicht"))
