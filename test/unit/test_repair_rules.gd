extends GutTest
## Die BREMSEN der LADESÄULE: was darf jetzt, und warum nicht. Reine Regel - sie
## bucht nichts und kennt keinen Körper.

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
	assert_false(RepairRules.charge_live(run, null, true), "kein Aufladen")
	assert_false(RepairRules.drain_live(run, null, true), "kein Ableiten")
	assert_false(RepairRules.repair_live(run, null, true), "keine Reparatur")
	assert_eq(RepairRules.blocker(run, null, true), RepairRules.EMPTY_TEXT,
		"und die Säule bittet um die Wahl")

func test_geladen_leben_aufladen_und_ableiten_nicht_die_reparatur() -> void:
	var die := _hot(2)
	assert_true(RepairRules.charge_live(run, die, true))
	assert_true(RepairRules.drain_live(run, die, true))
	assert_false(RepairRules.repair_live(run, die, true), "heil wird nicht repariert")

func test_durchgebrannt_lebt_nur_die_reparatur() -> void:
	var die := _burnt()
	assert_true(RepairRules.repair_live(run, die, true))
	assert_false(RepairRules.charge_live(run, die, true), "erst reparieren")
	assert_false(RepairRules.drain_live(run, die, true))

func test_kalt_schweigt_das_ableiten_voll_das_aufladen() -> void:
	var die := _hot(0)
	assert_false(RepairRules.drain_live(run, die, true), "kalt läßt sich nichts ableiten")
	assert_true(RepairRules.charge_live(run, die, true))
	die.charge = DieDefinition.CHARGE_MAX
	assert_false(RepairRules.charge_live(run, die, true), "über 3 gibt es nichts")
	assert_true(RepairRules.drain_live(run, die, true))

## Kalt, voll und heil sind KEINE Bremsen - der Hebel steht dann einfach grau.
func test_ein_zufriedener_kunde_nennt_keine_bremse() -> void:
	assert_eq(RepairRules.blocker(run, _hot(1), true), "")

func test_vor_der_letzten_sprosse_warnt_sie() -> void:
	assert_true(RepairRules.warns(run, _hot(DieDefinition.CHARGE_MAX - 1)))
	assert_false(RepairRules.warns(run, _hot(0)))
	assert_false(RepairRules.warns(run, _burnt()), "Asche warnt nicht mehr")

# --- Die Börse ----------------------------------------------------------------------

func test_ohne_energie_steht_die_reparatur_grau() -> void:
	var die := _burnt()
	run.energy = 0
	assert_false(RepairRules.repair_live(run, die, true), "unbezahlbar heißt grau")
	assert_eq(RepairRules.blocker(run, die, true), RepairRules.BLOCK_ENERGY, "und sie sagt warum")
	run.energy = GameRun.REPAIR_ENERGY
	assert_true(RepairRules.repair_live(run, die, true), "bezahlbar heißt bedienbar")
	assert_eq(RepairRules.blocker(run, die, true), "", "und die Bremse ist fort")

func test_ohne_geld_steht_das_ableiten_grau() -> void:
	var die := _hot(1)
	run.money = 0
	assert_false(RepairRules.drain_live(run, die, true), "$5 hat er nicht")
	assert_eq(RepairRules.blocker(run, die, true), RepairRules.BLOCK_MONEY)

func test_ohne_energie_steht_das_aufladen_grau() -> void:
	var die := _hot(1)
	run.energy = 0
	assert_false(RepairRules.charge_live(run, die, true))
	assert_eq(RepairRules.blocker(run, die, true), RepairRules.BLOCK_ENERGY)

# --- Die Sperren ----------------------------------------------------------------------

func test_der_wartungsvertrag_schliesst_die_saeule() -> void:
	var die := _hot(1)
	assert_true(RepairRules.charge_live(run, die, true), "offen steht sie")
	run.repair_lock_round = run.round_number
	assert_false(RepairRules.charge_live(run, die, true), "gesperrt nicht mehr")
	assert_false(RepairRules.drain_live(run, die, true), "auch das Ableiten nicht")
	assert_eq(RepairRules.blocker(run, die, true), RepairRules.BLOCK_LOCKED, "der Grund steht da")

func test_die_gezurrte_runde_schliesst_sie_ebenso() -> void:
	var die := _burnt()
	assert_false(RepairRules.repair_live(run, die, false),
		"während der Runde wird nicht repariert")
	assert_eq(RepairRules.blocker(run, die, false), RepairRules.BLOCK_ROUND, "und sie sagt es")
	assert_true(RepairRules.repair_live(run, die, true), "im Laden wieder")

## Der Kühlkörper senkt den Deckel - dieselbe Zahl, aus der GameRun bucht.
func test_der_kuehlkoerper_senkt_den_deckel() -> void:
	run.owned_charms.append(Charm.heat_sink())
	assert_eq(RepairRules.charge_cap(run), GameRun.HEAT_SINK_CAP)
	var die := _hot(GameRun.HEAT_SINK_CAP)
	assert_false(RepairRules.charge_live(run, die, true), "am Deckel ist Schluß")
	assert_false(run.charge_die(die), "und die Buchung sagt dasselbe")

# --- Die Preisschilder --------------------------------------------------------------

func test_die_schilder_nennen_die_regelpreise() -> void:
	assert_eq(RepairRules.charge_price_text(), "%d ⚡" % GameRun.CHARGE_UP_ENERGY)
	assert_eq(RepairRules.drain_price_text(), "$%d" % GameRun.DRAIN_MONEY)
	assert_eq(RepairRules.repair_price_text(run), "%d ⚡" % GameRun.REPAIR_ENERGY)

## Das Isolierband schreibt den Preis um - repair_price() ist die eine Quelle.
func test_das_isolierband_schreibt_den_reparatur_preis_um() -> void:
	run.owned_charms.append(Charm.insulation_tape())
	assert_eq(RepairRules.repair_price_text(run), "$%d" % GameRun.REPAIR_MONEY)
