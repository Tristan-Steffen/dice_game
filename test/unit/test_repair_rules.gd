extends GutTest
## Die BREMSE der SICHERUNGS-FASSUNG: darf jetzt repariert werden, und wenn nicht,
## warum nicht. Reine Regel - sie bucht nichts und kennt keinen Körper.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 50
	run.energy = 5

func _hot(level: int) -> DieDefinition:
	var die: DieDefinition = run.owned_pool[0]
	die.charge = level
	return die

func _burnt() -> DieDefinition:
	var die: DieDefinition = run.owned_pool[0]
	die.burn_out()
	return die

# --- Der Kunde --------------------------------------------------------------------

func test_ohne_kunden_lebt_nichts() -> void:
	assert_false(RepairRules.repair_live(run, null, true), "keine Reparatur")
	assert_eq(RepairRules.blocker(run, null, true), RepairRules.EMPTY_TEXT,
		"und die Fassung bittet um die Wahl")

func test_heil_wird_nicht_repariert() -> void:
	for level in [0, 1, 2, DieDefinition.CHARGE_MAX]:
		assert_false(RepairRules.repair_live(run, _hot(level), true),
			"Ladung %d ist kein Schaden" % level)

func test_durchgebrannt_lebt_die_reparatur() -> void:
	assert_true(RepairRules.repair_live(run, _burnt(), true))

## Ein heiler Würfel ist KEINE Bremse - seine Sicherung liegt einfach ruhig.
func test_ein_heiler_kunde_nennt_keine_bremse() -> void:
	assert_eq(RepairRules.blocker(run, _hot(1), true), "")
	assert_eq(RepairRules.blocker(run, _hot(DieDefinition.CHARGE_MAX), true), "")

# --- Die Börse ----------------------------------------------------------------------

func test_ohne_energie_steht_die_reparatur_grau() -> void:
	var die := _burnt()
	run.energy = 0
	assert_false(RepairRules.repair_live(run, die, true), "unbezahlbar heißt grau")
	assert_eq(RepairRules.blocker(run, die, true), RepairRules.BLOCK_ENERGY, "und sie sagt warum")
	run.energy = GameRun.REPAIR_ENERGY
	assert_true(RepairRules.repair_live(run, die, true), "bezahlbar heißt bedienbar")
	assert_eq(RepairRules.blocker(run, die, true), "", "und die Bremse ist fort")

func test_mit_isolierband_zaehlt_das_geld() -> void:
	run.owned_charms.append(Charm.insulation_tape())
	var die := _burnt()
	run.energy = 0
	assert_true(RepairRules.repair_live(run, die, true), "Geld statt Energie")
	run.money = 0
	assert_false(RepairRules.repair_live(run, die, true))
	assert_eq(RepairRules.blocker(run, die, true), RepairRules.BLOCK_MONEY)

# --- Die Sperren ----------------------------------------------------------------------

func test_der_wartungsvertrag_schliesst_die_fassung() -> void:
	var die := _burnt()
	assert_true(RepairRules.repair_live(run, die, true), "offen steht sie")
	run.repair_lock_round = run.round_number
	assert_false(RepairRules.repair_live(run, die, true), "gesperrt nicht mehr")
	assert_eq(RepairRules.blocker(run, die, true), RepairRules.BLOCK_LOCKED, "der Grund steht da")

func test_die_gezurrte_runde_schliesst_sie_ebenso() -> void:
	var die := _burnt()
	assert_false(RepairRules.repair_live(run, die, false),
		"während der Runde wird nicht repariert")
	assert_eq(RepairRules.blocker(run, die, false), RepairRules.BLOCK_ROUND, "und sie sagt es")
	assert_true(RepairRules.repair_live(run, die, true), "im Laden wieder")

# --- Das Preisschild --------------------------------------------------------------

func test_das_schild_nennt_den_regelpreis() -> void:
	assert_eq(RepairRules.repair_price_text(run), "%d ⚡" % GameRun.REPAIR_ENERGY)
	assert_eq(RepairRules.repair_price_text(null), "%d ⚡" % GameRun.REPAIR_ENERGY,
		"kopflos derselbe Preis")

## Das Isolierband schreibt den Preis um - repair_price() ist die eine Quelle.
func test_das_isolierband_schreibt_den_reparatur_preis_um() -> void:
	run.owned_charms.append(Charm.insulation_tape())
	assert_eq(RepairRules.repair_price_text(run), "$%d" % GameRun.REPAIR_MONEY)
