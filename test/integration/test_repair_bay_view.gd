extends GutTest
## Die REPARATUR-BUCHT hat EINEN Kunden: den Zielwürfel des Podests (set_target).
## Sie zeigt seine Netz-Zelle, seine Vorrats-Nummer und die Ladungs-Leiter mit
## "- $5" und "+ 1 ⚡" - durchgebrannt statt dessen EINEN Reparatur-Knopf. Sie
## bucht NICHTS (die Signale gehen an scene_root, GameRun bucht), sie sagt in der
## Caption, warum ein Knopf schweigt, und ohne Kunden bittet sie um die Wahl.

var view: RepairBayView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = RepairBayView.new()
	var u := 4.0
	view.size = Vector2(RepairBayView.width_for(u), RepairBayView.height_for(u))
	add_child_autofree(view)
	view.visible = true
	view.set_run(run)

func _hot(index: int, level: int) -> DieDefinition:
	var die: DieDefinition = run.owned_pool[index]
	die.charge = level
	view.set_target(die)
	return die

func _burn(index: int) -> DieDefinition:
	var die: DieDefinition = run.owned_pool[index]
	die.burn_out()
	view.set_target(die)
	return die

func _button(button_name: String) -> Button:
	return view.get_node_or_null("BayContent/" + button_name) as Button

# --- Der Kunde --------------------------------------------------------------------

func test_ohne_ziel_bittet_die_bucht_um_die_wahl() -> void:
	assert_null(view.target, "kein Kunde")
	assert_null(_button("Fall"), "also keine Zelle")
	assert_eq((view.get_node("BayContent/Leer") as Label).text, RepairBayView.EMPTY_TEXT)
	assert_null(_button("Aufladen"), "und keine Knöpfe")

func test_der_zielwuerfel_ist_der_kunde_auch_kalt() -> void:
	var die := _hot(2, 0)
	assert_eq(view.target, die)
	assert_not_null(_button("Fall"), "seine Zelle steht da")
	assert_eq((view.get_node("BayContent/Nummer") as Label).text, "#3", "mit seiner Vorrats-Nummer")
	assert_not_null(view.get_node_or_null("BayContent/Leiter"), "und der Leiter")
	assert_true(_button("Ableiten").disabled, "kalt läßt sich nichts ableiten")
	run.add_energy(GameRun.CHARGE_UP_ENERGY)
	view.refresh()
	assert_false(_button("Aufladen").disabled, "aber aufladen")

func test_der_kunde_folgt_dem_podest() -> void:
	var first := _hot(0, 1)
	assert_eq(view.target, first)
	var second := _hot(1, 2)
	assert_eq(view.target, second, "das Podest wechselt, die Bucht mit")
	view.set_target(null)
	assert_null(_button("Fall"), "leer, wenn keiner dort steht")

func test_ein_verkaufter_kunde_verlaesst_die_bucht() -> void:
	var die := _hot(0, 1)
	run.owned_pool.erase(die)
	view.refresh()
	assert_null(view.target, "wer nicht mehr im Vorrat ist, ist kein Kunde")

# --- Die Knöpfe ---------------------------------------------------------------------

func test_geladen_stehen_leiter_und_zwei_knoepfe() -> void:
	_hot(0, 2)
	run.add_energy(5)
	run.add_money(50)
	view.refresh()
	assert_eq(_button("Ableiten").text, view.drain_label())
	assert_string_contains(_button("Ableiten").text, str(GameRun.DRAIN_MONEY))
	assert_eq(_button("Aufladen").text, view.charge_label())
	assert_string_contains(_button("Aufladen").text, str(GameRun.CHARGE_UP_ENERGY))
	assert_null(_button("Reparieren"), "heil wird nicht repariert")

func test_durchgebrannt_steht_der_eine_reparatur_knopf() -> void:
	_burn(0)
	run.add_energy(GameRun.REPAIR_ENERGY)
	view.refresh()
	assert_eq(_button("Reparieren").text, view.repair_label())
	assert_null(_button("Ableiten"), "kein Ableiten")
	assert_null(_button("Aufladen"), "kein Aufladen - erst reparieren")
	assert_false(_button("Reparieren").disabled)

func test_voll_geladen_schweigt_das_aufladen() -> void:
	_hot(0, DieDefinition.CHARGE_MAX)
	run.add_energy(5)
	run.add_money(50)
	view.refresh()
	assert_true(_button("Aufladen").disabled, "über 3 gibt es nichts")
	assert_false(_button("Ableiten").disabled)
	assert_eq(view.caption_text(), "", "voll ist keine Bremse")

func test_vor_der_letzten_sprosse_warnt_die_caption() -> void:
	_hot(0, DieDefinition.CHARGE_MAX - 1)
	run.add_energy(5)
	run.add_money(50)
	view.refresh()
	assert_eq(view.caption_text(), RepairBayView.WARN_TOP)

## Das Isolierband macht aus der ⚡-Reparatur eine GELD-Reparatur - der Knopf sagt
## es, denn repair_price() ist die eine Quelle.
func test_das_isolierband_schreibt_den_preis_um() -> void:
	_burn(0)
	view.refresh()
	assert_string_contains(_button("Reparieren").text, "%d ⚡" % GameRun.REPAIR_ENERGY)
	run.owned_charms.append(Charm.insulation_tape())
	view.refresh()
	assert_string_contains(_button("Reparieren").text, "$%d" % GameRun.REPAIR_MONEY)

# --- Die Signale ------------------------------------------------------------------

func test_die_knoepfe_melden_nur_und_buchen_nichts() -> void:
	var die := _hot(0, 1)
	run.add_energy(5)
	run.add_money(50)
	view.refresh()
	var drained: Array[DieDefinition] = []
	var charged: Array[DieDefinition] = []
	view.drain_requested.connect(func(d: DieDefinition) -> void: drained.append(d))
	view.charge_requested.connect(func(d: DieDefinition) -> void: charged.append(d))
	_button("Ableiten").pressed.emit()
	_button("Aufladen").pressed.emit()
	assert_eq(drained, [die] as Array[DieDefinition], "der Kunde meldet sich")
	assert_eq(charged, [die] as Array[DieDefinition], "auf beiden Wegen")
	assert_eq(die.charge, 1, "gebucht hat das Fenster nichts")

func test_der_reparatur_knopf_meldet_den_kunden() -> void:
	var die := _burn(0)
	run.add_energy(GameRun.REPAIR_ENERGY)
	view.refresh()
	var repaired: Array[DieDefinition] = []
	view.repair_requested.connect(func(d: DieDefinition) -> void: repaired.append(d))
	_button("Reparieren").pressed.emit()
	assert_eq(repaired, [die] as Array[DieDefinition])
	assert_true(die.burned_out, "und bucht nichts")

# --- Die Bremsen ------------------------------------------------------------------

func test_ohne_energie_steht_die_reparatur_grau() -> void:
	_burn(0)
	run.energy = 0
	view.refresh()
	assert_true(_button("Reparieren").disabled, "unbezahlbar heißt grau")
	assert_eq(view.caption_text(), RepairBayView.BLOCK_ENERGY, "und die Caption sagt warum")
	run.add_energy(GameRun.REPAIR_ENERGY)
	view.refresh()
	assert_false(_button("Reparieren").disabled, "bezahlbar heißt bedienbar")
	assert_eq(view.caption_text(), "", "und die Caption schweigt")

func test_ohne_geld_steht_das_ableiten_grau() -> void:
	_hot(0, 1)
	run.money = 0
	run.add_energy(5)
	view.refresh()
	assert_true(_button("Ableiten").disabled, "$5 hat er nicht")
	assert_eq(view.caption_text(), RepairBayView.BLOCK_MONEY, "und die Caption sagt es")

func test_ohne_energie_steht_das_aufladen_grau() -> void:
	_hot(0, 1)
	run.energy = 0
	run.add_money(50)
	view.refresh()
	assert_true(_button("Aufladen").disabled)
	assert_eq(view.caption_text(), RepairBayView.BLOCK_ENERGY)

func test_der_wartungsvertrag_schliesst_die_bucht() -> void:
	_hot(0, 1)
	run.add_energy(10)
	run.add_money(50)
	view.refresh()
	assert_false(_button("Aufladen").disabled, "offen steht sie")
	run.repair_lock_round = run.round_number
	view.refresh()
	assert_true(_button("Aufladen").disabled, "gesperrt nicht mehr")
	assert_true(_button("Ableiten").disabled, "auch das Ableiten nicht")
	assert_eq(view.caption_text(), RepairBayView.BLOCK_LOCKED, "der Grund steht da")

func test_die_gezurrte_runde_schliesst_sie_ebenso() -> void:
	_burn(0)
	run.add_energy(10)
	view.set_enabled(false)
	assert_true(_button("Reparieren").disabled, "während der Runde wird nicht repariert")
	assert_eq(view.caption_text(), RepairBayView.BLOCK_ROUND, "und sie sagt es")
	view.set_enabled(true)
	assert_false(_button("Reparieren").disabled, "im Laden wieder")

# --- Maße --------------------------------------------------------------------------

func test_die_breite_ist_eine_reine_funktion_der_einheit() -> void:
	assert_almost_eq(RepairBayView.width_for(4.0) / RepairBayView.width_for(2.0), 2.0,
		0.001, "doppelte Einheit, doppelte Bucht")

## EIN Kunde, eine feste Höhe: die Bucht wächst nicht mehr mit einer Liste.
func test_die_bucht_hat_eine_feste_hoehe() -> void:
	await wait_frames(2)
	var empty_rect := view.bay_rect()
	_hot(0, 3)
	await wait_frames(2)
	assert_eq(view.bay_rect(), empty_rect, "mit Kunde wie ohne")
	assert_ne(view.ladder_px(), Vector2.ZERO, "und sie meldet ihre Leiter")
