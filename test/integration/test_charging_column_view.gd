extends GutTest
## Die LADESÄULE: drei Elko-Dosen zeigen die Ladung des Zielwürfels, zwei Kipphebel
## laden und leiten ab, der Sicherungssockel repariert. Sie bucht NICHTS - sie
## meldet den Kunden, GameRun bucht.

var column: ChargingColumnView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 50
	run.energy = 5
	column = ChargingColumnView.new()
	add_child_autofree(column)
	column.setup(Vector3(-24.0, 0.0, 34.0))
	column.set_prices(run)

func _hot(level: int) -> DieDefinition:
	var die: DieDefinition = run.owned_pool[0]
	die.repair()
	die.charge = level
	column.set_customer(die)
	return die

func _burnt() -> DieDefinition:
	var die: DieDefinition = run.owned_pool[0]
	die.burn_out()
	column.set_customer(die)
	return die

## Die Bremsen kommen aus der EINEN Regel - die Säule rechnet nichts nach.
func _sync(die: DieDefinition, enabled := true) -> void:
	column.set_live(RepairRules.charge_live(run, die, enabled),
		RepairRules.drain_live(run, die, enabled),
		RepairRules.repair_live(run, die, enabled))

# --- Die Dosen -----------------------------------------------------------------------

func test_ohne_kunden_ist_die_saeule_kalt() -> void:
	assert_null(column.customer(), "kein Kunde")
	assert_eq(column.lit_cells(), 0, "keine Dose brennt")
	assert_false(column.burned(), "und Asche liegt auch keine")

func test_je_ladung_eine_dose() -> void:
	for level in [0, 1, 2, DieDefinition.CHARGE_MAX]:
		_hot(level)
		assert_eq(column.lit_cells(), level, "Ladung %d, %d Dosen" % [level, level])

func test_durchgebrannt_brennt_keine_dose_mehr() -> void:
	_hot(DieDefinition.CHARGE_MAX)
	assert_eq(column.lit_cells(), DieDefinition.CHARGE_MAX)
	_burnt()
	assert_eq(column.lit_cells(), 0, "Glut statt Licht")
	assert_true(column.burned())

## Die Sicherung IST die Anzeige des Durchbrenners: heil sitzt sie bündig.
func test_die_sicherung_steht_nur_beim_durchbrenner_heraus() -> void:
	_hot(2)
	assert_false(column.fuse_popped(), "heil sitzt sie im Sockel")
	_burnt()
	assert_true(column.fuse_popped(), "durchgebrannt steht sie heraus")

## Die Signatur liest den STAND, nicht die Referenz: derselbe Würfel mit neuer
## Ladung schreibt die Dosen um.
func test_der_stand_schlaegt_die_referenz() -> void:
	var die := _hot(1)
	assert_eq(column.lit_cells(), 1)
	die.charge = DieDefinition.CHARGE_MAX
	column.set_customer(die)
	assert_eq(column.lit_cells(), DieDefinition.CHARGE_MAX, "dieselbe Instanz, neuer Stand")
	die.burn_out()
	column.set_customer(die)
	assert_true(column.fuse_popped(), "und der Durchbrenner kommt durch")

# --- Die Bedienelemente -----------------------------------------------------------------

func test_geladen_leben_beide_hebel_nicht_die_sicherung() -> void:
	_sync(_hot(2))
	assert_true(column.charge_live(), "aufladen geht")
	assert_true(column.drain_live(), "ableiten auch")
	assert_false(column.repair_live(), "heil wird nicht repariert")
	assert_true(column.pick_armed(ChargingColumnView.PART_CHARGE), "und der Hebel fängt")
	assert_false(column.pick_armed(ChargingColumnView.PART_FUSE), "die Sicherung nicht")

func test_durchgebrannt_lebt_nur_die_sicherung() -> void:
	_sync(_burnt())
	assert_true(column.repair_live())
	assert_false(column.charge_live(), "erst reparieren")
	assert_false(column.drain_live())
	assert_true(column.pick_armed(ChargingColumnView.PART_FUSE))
	assert_false(column.pick_armed(ChargingColumnView.PART_DRAIN))

func test_ohne_kunden_faengt_kein_bedienelement() -> void:
	_sync(null)
	for part in [ChargingColumnView.PART_CHARGE, ChargingColumnView.PART_DRAIN,
			ChargingColumnView.PART_FUSE]:
		assert_false(column.pick_armed(part), "%s steht grau" % part)

## Ein totes Bedienelement antwortet auch dem Zeiger nicht.
func test_grau_antwortet_dem_zeiger_nicht() -> void:
	_sync(_hot(0))
	column.set_hovered(ChargingColumnView.PART_DRAIN)
	assert_eq(column.hovered(), ChargingColumnView.PART_NONE, "kalt hebt sich nichts")
	column.set_hovered(ChargingColumnView.PART_CHARGE)
	assert_eq(column.hovered(), ChargingColumnView.PART_CHARGE)

# --- Die Meldungen ---------------------------------------------------------------------

func test_die_hebel_melden_den_kunden_und_buchen_nichts() -> void:
	var die := _hot(1)
	_sync(die)
	var charged: Array[DieDefinition] = []
	var drained: Array[DieDefinition] = []
	column.charge_requested.connect(func(d: DieDefinition) -> void: charged.append(d))
	column.drain_requested.connect(func(d: DieDefinition) -> void: drained.append(d))
	assert_true(column.press(ChargingColumnView.PART_CHARGE), "der obere meldet")
	assert_true(column.press(ChargingColumnView.PART_DRAIN), "der untere auch")
	assert_eq(charged, [die] as Array[DieDefinition])
	assert_eq(drained, [die] as Array[DieDefinition])
	assert_eq(die.charge, 1, "gebucht hat die Säule nichts")
	assert_eq(run.energy, 5, "und die Börse ist unberührt")
	assert_eq(run.money, 50)

func test_die_sicherung_meldet_den_kunden() -> void:
	var die := _burnt()
	_sync(die)
	var repaired: Array[DieDefinition] = []
	column.repair_requested.connect(func(d: DieDefinition) -> void: repaired.append(d))
	assert_true(column.press(ChargingColumnView.PART_FUSE))
	assert_eq(repaired, [die] as Array[DieDefinition])
	assert_true(die.burned_out, "und bucht nichts")

func test_ein_totes_bedienelement_meldet_nichts() -> void:
	var die := _hot(0)
	_sync(die)
	var drained: Array[DieDefinition] = []
	column.drain_requested.connect(func(d: DieDefinition) -> void: drained.append(d))
	assert_false(column.press(ChargingColumnView.PART_DRAIN), "kalt gibt es nichts abzuleiten")
	assert_eq(drained, [] as Array[DieDefinition])

# --- Die Schilder ------------------------------------------------------------------------

func test_die_schilder_nennen_die_regelpreise() -> void:
	assert_eq(column.plate_text(ChargingColumnView.PART_CHARGE),
		RepairRules.charge_price_text())
	assert_eq(column.plate_text(ChargingColumnView.PART_DRAIN),
		RepairRules.drain_price_text())
	assert_eq(column.plate_text(ChargingColumnView.PART_FUSE),
		"%d ⚡" % GameRun.REPAIR_ENERGY)

func test_das_isolierband_schreibt_das_schild_um() -> void:
	run.owned_charms.append(Charm.insulation_tape())
	column.set_prices(run)
	assert_eq(column.plate_text(ChargingColumnView.PART_FUSE),
		"$%d" % GameRun.REPAIR_MONEY)

# --- Maße --------------------------------------------------------------------------------

func test_die_saeule_meldet_fussabdruck_und_kopf() -> void:
	var lo := column.bounds_min()
	var hi := column.bounds_max()
	assert_gt(hi.x - lo.x, 0.0, "sie hat eine Tiefe")
	assert_gt(hi.y - lo.y, 0.0, "und eine Breite")
	assert_almost_eq(column.head_point().y, ChargingColumnView.column_height(), 0.001,
		"der Kopf steht auf voller Höhe")
	# Die Konsole LEHNT sich dem Blick entgegen, ihr Kopf steht also hinter dem Fuß.
	assert_gt(column.head_point().x, column.center.x, "der Kopf lehnt nach hinten")
	assert_lt(column.head_point().x, hi.x + 0.001, "aber nie aus dem Fußabdruck")

## Derselbe Platz baut nichts neu - die Säule ist Möbel.
func test_derselbe_platz_baut_nichts_neu() -> void:
	var before := column.get_child_count()
	column.setup(column.center)
	assert_eq(column.get_child_count(), before)
