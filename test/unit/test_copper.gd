extends GutTest
## Tests des Kupfers: das ⚡-Material. Es speist je Zündung, dotiert doppelt, und
## was über den Speicher hinausläuft, zahlt bar - dieselbe Überlauf-Grammatik wie
## die Stufen-Auszahlung.

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

func _defs(values: Array) -> Array[DieDefinition]:
	var typed: Array[DieDefinition] = []
	typed.assign(values)
	return typed

const NO_CHARMS: Array[String] = []

## Ein Würfel mit Kupfer auf Seite 0 (doped = dotiert).
func _copper_die(doped := false) -> DieDefinition:
	var def := DieDefinition.new()
	def.set_face_material(0, DieMaterial.COPPER)
	if doped:
		def.dope(0)
	return def

func _take(def: DieDefinition, charm_ids: Array[String] = NO_CHARMS,
		essences: Dictionary = {}) -> MaterialEffects.TakeReport:
	return MaterialEffects.apply_take_effects(_defs([def]), _d([0]),
		_m([DieMaterial.COPPER]), _d([0]), charm_ids, -1, essences)

# --- Datensatz ----------------------------------------------------------------

func test_copper_is_the_sixth_material():
	assert_true(DieMaterial.is_valid_id(DieMaterial.COPPER))
	assert_eq(DieMaterial.all().size(), 6, "sechs Materialien, sechs Icons")

func test_copper_states_read_as_energy():
	var copper := DieMaterial.by_id(DieMaterial.COPPER)
	assert_eq(copper.short, "+1 ⚡")
	assert_eq(copper.short_doped, "+2 ⚡")
	assert_ne(copper.description_doped, "", "der dotierte Zustand erklärt sich")

func test_copper_has_a_texture_even_without_its_own_file():
	# Konvention Dateiname = id; fehlt copper.png, trägt die Basis-Textur.
	assert_not_null(DieMaterial.die_texture_for(DieMaterial.COPPER),
		"eine musterlose Seite läse sich wie gar kein Material")

# --- Zündung ------------------------------------------------------------------

func test_a_copper_face_feeds_one_charge_per_firing():
	var report := _take(_copper_die())
	assert_eq(report.copper_charge, MaterialEffects.COPPER_CHARGE)
	assert_eq(report.copper, [0] as Array[int], "der Slot meldet seine Zündung")

func test_a_doped_copper_face_feeds_twice():
	assert_eq(_take(_copper_die(true)).copper_charge, MaterialEffects.COPPER_CHARGE_DOPED)

func test_copper_fires_once_per_activation_on_both_axes():
	# Argon zündet den Würfel zweimal, die Hasenpfote die 6 ein weiteres Mal.
	var def := _copper_die()
	def.faces = _d([6, 2, 3, 4, 5, 1])
	var report := _take(def, _ids([Charm.RABBITS_FOOT]), {0: Essence.ARGON})
	assert_eq(report.copper_charge, 4, "2 Würfel-Trigger × 2 Seiten-Zündungen")
	assert_eq(report.copper.size(), 4, "je Zündung ein Eintrag")

func test_the_kiln_doubles_the_doped_payout():
	assert_eq(_take(_copper_die(true), _ids([Charm.KILN])).copper_charge,
		MaterialEffects.COPPER_CHARGE_DOPED * 2)

func test_the_kiln_leaves_the_undoped_face_alone():
	assert_eq(_take(_copper_die(), _ids([Charm.KILN])).copper_charge, MaterialEffects.COPPER_CHARGE)

func test_another_material_feeds_nothing():
	var def := DieDefinition.new()
	def.set_face_material(0, DieMaterial.GOLD)
	var report := MaterialEffects.apply_take_effects(_defs([def]), _d([0]),
		_m([DieMaterial.GOLD]), _d([0]))
	assert_eq(report.copper_charge, 0)
	assert_true(report.copper.is_empty())

func test_copper_stays_out_of_the_spark_channel():
	# report.charge gehört dem Funkenflug: nur er läuft OHNE Geld-Überlauf.
	assert_eq(_take(_copper_die()).charge, 0)

func test_the_charge_of_one_firing_is_one_source():
	assert_eq(MaterialEffects.copper_charge_once_for(DieMaterial.COPPER, 1, NO_CHARMS), 1)
	assert_eq(MaterialEffects.copper_charge_once_for(DieMaterial.COPPER, DieMaterial.MAX_LEVEL, NO_CHARMS), 2)
	assert_eq(MaterialEffects.copper_charge_once_for(DieMaterial.GOLD, 1, NO_CHARMS), 0)

# --- Buchung: Überlauf zahlt bar ------------------------------------------------

func test_the_charge_lands_in_the_wallet():
	var run := GameRun.new_run()
	assert_eq(run.book_copper_charge(3), 0, "nichts läuft über")
	assert_eq(run.charge, 3)
	assert_eq(run.money, 0)

func test_a_full_wallet_pays_the_overflow_in_cash():
	var run := GameRun.new_run()
	run.charge = run.charge_cap() - 1
	var paid := run.book_copper_charge(4)
	assert_eq(run.charge, run.charge_cap(), "die Börse füllt sich bis zum Deckel")
	assert_eq(paid, 3 * MaterialEffects.COPPER_OVERFLOW_MONEY, "der Rest zahlt bar")
	assert_eq(run.money, paid)

func test_a_completely_full_wallet_pays_everything_in_cash():
	var run := GameRun.new_run()
	run.charge = run.charge_cap()
	assert_eq(run.book_copper_charge(2), 2 * MaterialEffects.COPPER_OVERFLOW_MONEY)
	assert_eq(run.charge, run.charge_cap(), "der Deckel bleibt der Deckel")

func test_booking_nothing_does_nothing():
	var run := GameRun.new_run()
	assert_eq(run.book_copper_charge(0), 0)
	assert_eq(run.charge, 0)
	assert_eq(run.money, 0)
