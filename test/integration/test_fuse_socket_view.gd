extends GutTest
## Die SICHERUNGS-FASSUNG: eine flache Klappe auf dem Filz, in deren Rinne die
## Sicherung des Zielwürfels liegt - heil bündig, durchgebrannt gesprungen. Der
## Druck darauf ist die Reparatur. Sie bucht NICHTS - sie meldet den Kunden,
## GameRun bucht.

var socket: FuseSocketView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.money = 50
	run.energy = 5
	socket = FuseSocketView.new()
	add_child_autofree(socket)
	socket.setup(Vector3(-24.0, 0.0, 34.0))
	socket.set_prices(run)

func _hot(level: int) -> DieDefinition:
	var die: DieDefinition = run.owned_pool[0]
	die.repair()
	die.charge = level
	socket.set_customer(die)
	return die

func _burnt() -> DieDefinition:
	var die: DieDefinition = run.owned_pool[0]
	die.burn_out()
	socket.set_customer(die)
	return die

## Die Bremse kommt aus der EINEN Regel - die Fassung rechnet nichts nach.
func _sync(die: DieDefinition, enabled := true) -> void:
	socket.set_live(RepairRules.repair_live(run, die, enabled))

# --- Die Sicherung -----------------------------------------------------------------------

func test_ohne_kunden_ist_die_fassung_kalt() -> void:
	assert_null(socket.customer(), "kein Kunde")
	assert_false(socket.burned(), "und Asche liegt keine")
	assert_false(socket.fuse_popped(), "die Sicherung liegt in der Klemme")

## Die Sicherung IST die Anzeige des Durchbrenners: heil liegt sie bündig.
func test_die_sicherung_springt_nur_beim_durchbrenner() -> void:
	_hot(2)
	assert_false(socket.fuse_popped(), "heil liegt sie in der Rinne")
	_burnt()
	assert_true(socket.fuse_popped(), "durchgebrannt ist sie gesprungen")

## Die Signatur liest den STAND, nicht die Referenz.
func test_der_stand_schlaegt_die_referenz() -> void:
	var die := _hot(1)
	assert_false(socket.fuse_popped())
	die.burn_out()
	socket.set_customer(die)
	assert_true(socket.fuse_popped(), "dieselbe Instanz, neuer Stand")

## Die Ladung ist der Fassung gleich - sie kennt nur heil und durchgebrannt.
func test_die_ladung_aendert_die_anzeige_nicht() -> void:
	for level in [0, 1, 2, DieDefinition.CHARGE_MAX]:
		_hot(level)
		assert_false(socket.fuse_popped(), "Ladung %d: die Sicherung liegt" % level)

# --- Die Bedienbarkeit --------------------------------------------------------------------

func test_heil_lebt_die_sicherung_nicht() -> void:
	_sync(_hot(2))
	assert_false(socket.repair_live(), "heil wird nicht repariert")
	assert_false(socket.pick_armed(FuseSocketView.PART_FUSE), "und sie fängt nicht")

func test_durchgebrannt_lebt_sie() -> void:
	_sync(_burnt())
	assert_true(socket.repair_live())
	assert_true(socket.pick_armed(FuseSocketView.PART_FUSE), "und fängt den Strahl")

func test_ohne_kunden_faengt_sie_nicht() -> void:
	_sync(null)
	assert_false(socket.pick_armed(FuseSocketView.PART_FUSE), "sie steht grau")

func test_unbezahlbar_faengt_sie_nicht() -> void:
	run.energy = 0
	_sync(_burnt())
	assert_false(socket.repair_live(), "3 ⚡ hat er nicht")
	assert_false(socket.pick_armed(FuseSocketView.PART_FUSE))
	assert_true(socket.fuse_popped(), "gesprungen ist sie trotzdem")

## Eine tote Sicherung antwortet auch dem Zeiger nicht.
func test_grau_antwortet_dem_zeiger_nicht() -> void:
	_sync(_hot(0))
	socket.set_hovered(FuseSocketView.PART_FUSE)
	assert_eq(socket.hovered(), FuseSocketView.PART_NONE, "heil hebt sich nichts")
	_sync(_burnt())
	socket.set_hovered(FuseSocketView.PART_FUSE)
	assert_eq(socket.hovered(), FuseSocketView.PART_FUSE)

# --- Die Meldung ---------------------------------------------------------------------------

func test_die_sicherung_meldet_den_kunden_und_bucht_nichts() -> void:
	var die := _burnt()
	_sync(die)
	var repaired: Array[DieDefinition] = []
	socket.repair_requested.connect(func(d: DieDefinition) -> void: repaired.append(d))
	assert_true(socket.press(FuseSocketView.PART_FUSE))
	assert_eq(repaired, [die] as Array[DieDefinition])
	assert_true(die.burned_out, "gebucht hat die Fassung nichts")
	assert_eq(run.energy, 5, "und die Börse ist unberührt")

func test_eine_tote_sicherung_meldet_nichts() -> void:
	var die := _hot(0)
	_sync(die)
	var repaired: Array[DieDefinition] = []
	socket.repair_requested.connect(func(d: DieDefinition) -> void: repaired.append(d))
	assert_false(socket.press(FuseSocketView.PART_FUSE), "heil gibt es nichts zu reparieren")
	assert_eq(repaired, [] as Array[DieDefinition])

## Die REPARATUR: der gebuchte Wechsel gesprungen->heil fährt die Sicherung zurück.
func test_die_reparatur_setzt_die_sicherung_zurueck() -> void:
	var die := _burnt()
	assert_true(socket.fuse_popped())
	die.repair()
	socket.set_customer(die)
	assert_false(socket.fuse_popped(), "Endzustand zuerst: sie liegt wieder in der Klemme")

# --- Das Schild ------------------------------------------------------------------------------

func test_das_schild_nennt_den_regelpreis() -> void:
	assert_eq(socket.plate_text(FuseSocketView.PART_FUSE), "%d ⚡" % GameRun.REPAIR_ENERGY)
	assert_eq(socket.plate_text("nichts"), "", "ein fremdes Teil hat kein Schild")

func test_das_isolierband_schreibt_das_schild_um() -> void:
	run.owned_charms.append(Charm.insulation_tape())
	socket.set_prices(run)
	assert_eq(socket.plate_text(FuseSocketView.PART_FUSE), "$%d" % GameRun.REPAIR_MONEY)

# --- Maße -------------------------------------------------------------------------------------

## Die Klappe ist FLACH: sie ragt nur um die gesprungene Sicherung über den Filz.
func test_die_fassung_liegt_flach_auf_dem_filz() -> void:
	var lo := socket.bounds_min()
	var hi := socket.bounds_max()
	assert_gt(hi.x - lo.x, 0.0, "sie hat eine Tiefe")
	assert_gt(hi.y - lo.y, hi.x - lo.x, "und ist breiter als tief - eine Zeile")
	assert_lt(FuseSocketView.height(), 1.0, "und baut kaum über den Tisch")
	assert_lt(socket.fuse_point().y, FuseSocketView.height(), "die Sicherung liegt darunter")
	assert_true(Rect2(lo, hi - lo).has_point(Vector2(socket.fuse_point().x, socket.fuse_point().z)),
		"die Sicherung liegt im Fußabdruck")
	assert_true(Rect2(lo, hi - lo).has_point(Vector2(socket.cable_root().x, socket.cable_root().z)),
		"das Kabel setzt an ihrer Kante an")

## Derselbe Platz baut nichts neu - die Fassung ist Möbel.
func test_derselbe_platz_baut_nichts_neu() -> void:
	var before := socket.get_child_count()
	socket.setup(socket.center)
	assert_eq(socket.get_child_count(), before)
