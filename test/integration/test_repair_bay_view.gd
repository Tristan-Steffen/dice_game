extends GutTest
## Die REPARATUR-BUCHT: eine Zeile je Vorrats-Würfel, der durchgebrannt ist oder
## Ladung trägt, in Vorrats-Reihenfolge - Netz-Zelle, Vorrats-Nummer und EIN Knopf.
## Sie bucht NICHTS (die Signale gehen an scene_root, GameRun bucht), sie sagt in
## der Caption, warum ein Knopf schweigt, und leer steht dort "Keine Fälle".

var view: RepairBayView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = RepairBayView.new()
	var u := 4.0
	view.size = Vector2(RepairBayView.width_for(u),
		RepairBayView.height_for(u, RepairBayView.FIT_ROWS))
	add_child_autofree(view)
	view.visible = true
	view.set_run(run)

func _hot(index: int, level: int) -> DieDefinition:
	var die: DieDefinition = run.owned_pool[index]
	die.charge = level
	return die

func _burn(index: int) -> DieDefinition:
	var die: DieDefinition = run.owned_pool[index]
	die.burn_out()
	return die

func _seats() -> Array[Button]:
	var out: Array[Button] = []
	for child in view.get_node("BayContent").get_children():
		if child is Button and String(child.name).begins_with("Fall"):
			out.append(child)
	return out

func _actions() -> Array[Button]:
	var out: Array[Button] = []
	for child in view.get_node("BayContent").get_children():
		if child is Button and String(child.name).begins_with("Aktion"):
			out.append(child)
	return out

func _footer() -> Button:
	return view.get_node("BayContent/Entladen")

# --- Die Liste ------------------------------------------------------------------

func test_die_liste_zaehlt_nur_die_faelle_in_vorrats_reihenfolge() -> void:
	var third := _hot(2, 2)
	var first := _burn(0)
	view.refresh()
	var cases := view.cases()
	assert_eq(cases.size(), 2, "genau zwei Fälle")
	assert_eq(cases[0], first, "Vorrats-Reihenfolge: der vordere zuerst")
	assert_eq(cases[1], third, "dann der geladene")
	assert_eq(_seats().size(), 2, "je Fall eine Netz-Zelle")
	assert_eq(view.case_rects().size(), 2, "und sie meldet beide Plätze")

func test_ein_kalter_heiler_vorrat_hat_keine_faelle() -> void:
	assert_true(view.cases().is_empty(), "nichts zu reparieren")
	assert_eq(_seats().size(), 0, "also keine Zeile")
	assert_not_null(view.get_node("BayContent/Leer"), "sondern der Satz")
	assert_eq((view.get_node("BayContent/Leer") as Label).text,
		RepairBayView.EMPTY_TEXT, "Keine Fälle")

func test_je_fall_der_eine_knopf_den_er_braucht() -> void:
	_burn(0)
	_hot(1, 1)
	view.refresh()
	var actions := _actions()
	assert_eq(actions.size(), 2, "je Fall genau ein Knopf")
	assert_eq(actions[0].text, view.repair_label(), "durchgebrannt wird repariert")
	assert_eq(actions[1].text, view.drain_label(), "geladen wird abgeleitet")
	assert_string_contains(actions[1].text, str(GameRun.DRAIN_MONEY), "zum Preis der Regel")

## Das Isolierband macht aus der ⚡-Reparatur eine GELD-Reparatur - der Knopf sagt
## es, denn repair_price() ist die eine Quelle.
func test_das_isolierband_schreibt_den_preis_um() -> void:
	_burn(0)
	view.refresh()
	assert_string_contains(_actions()[0].text, "⚡", "ohne Band kostet sie Energie")
	run.owned_charms.append(Charm.insulation_tape())
	view.refresh()
	assert_string_contains(_actions()[0].text, "$%d" % GameRun.REPAIR_MONEY,
		"mit Band kostet sie Geld")

# --- Die Signale ------------------------------------------------------------------

func test_die_knoepfe_melden_nur_und_buchen_nichts() -> void:
	var burned := _burn(0)
	var charged := _hot(1, 2)
	run.add_energy(GameRun.REPAIR_ENERGY)
	run.add_money(GameRun.DRAIN_MONEY)
	view.refresh()
	var repaired: Array[DieDefinition] = []
	var drained: Array[DieDefinition] = []
	view.repair_requested.connect(func(die: DieDefinition) -> void: repaired.append(die))
	view.drain_requested.connect(func(die: DieDefinition) -> void: drained.append(die))
	var actions := _actions()
	actions[0].pressed.emit()
	actions[1].pressed.emit()
	assert_eq(repaired, [burned] as Array[DieDefinition], "der Fall meldet SICH")
	assert_eq(drained, [charged] as Array[DieDefinition], "und der andere sich")
	assert_true(burned.burned_out, "gebucht hat das Fenster nichts")
	assert_eq(charged.charge, 2, "und hier auch nicht")

func test_der_fuss_meldet_das_entladen() -> void:
	_hot(0, 2)
	run.add_energy(GameRun.DISCHARGE_ALL_ENERGY)
	view.refresh()
	# Lambdas fangen Locals per WERT - der Zähler reist darum in einem Array.
	var calls: Array[int] = [0]
	view.discharge_all_requested.connect(func() -> void: calls[0] += 1)
	_footer().pressed.emit()
	assert_eq(calls[0], 1, "ein Druck, eine Meldung")
	assert_string_contains(_footer().text, str(GameRun.DISCHARGE_ALL_ENERGY),
		"und die Aufschrift nennt den Preis")

# --- Die Bremsen ------------------------------------------------------------------

func test_ohne_energie_steht_der_reparatur_knopf_grau() -> void:
	_burn(0)
	run.energy = 0
	view.refresh()
	assert_true(_actions()[0].disabled, "unbezahlbar heißt grau")
	assert_eq(view.caption_text(), RepairBayView.BLOCK_ENERGY, "und die Caption sagt warum")
	run.add_energy(GameRun.REPAIR_ENERGY)
	view.refresh()
	assert_false(_actions()[0].disabled, "bezahlbar heißt bedienbar")
	assert_eq(view.caption_text(), "", "und die Caption schweigt")

func test_ohne_geld_steht_der_ableit_knopf_grau() -> void:
	_hot(0, 1)
	run.money = 0
	view.refresh()
	assert_true(_actions()[0].disabled, "$5 hat er nicht")
	assert_eq(view.caption_text(), RepairBayView.BLOCK_MONEY, "und die Caption sagt es")

func test_der_wartungsvertrag_schliesst_die_bucht() -> void:
	_burn(0)
	run.add_energy(10)
	view.refresh()
	assert_false(_actions()[0].disabled, "offen steht sie")
	run.repair_lock_round = run.round_number
	view.refresh()
	assert_true(_actions()[0].disabled, "gesperrt nicht mehr")
	assert_true(_footer().disabled, "auch das Entladen nicht")
	assert_eq(view.caption_text(), RepairBayView.BLOCK_LOCKED, "der Grund steht da")

func test_die_gezurrte_runde_schliesst_sie_ebenso() -> void:
	_burn(0)
	run.add_energy(10)
	view.set_enabled(false)
	assert_true(_actions()[0].disabled, "während der Runde wird nicht repariert")
	assert_eq(view.caption_text(), RepairBayView.BLOCK_ROUND, "und sie sagt es")
	view.set_enabled(true)
	assert_false(_actions()[0].disabled, "im Laden wieder")

# --- Maße --------------------------------------------------------------------------

func test_die_breite_ist_eine_reine_funktion_der_einheit() -> void:
	assert_gt(RepairBayView.width_for(4.0), RepairBayView.width_for(2.0),
		"doppelte Einheit, breitere Bucht")
	assert_almost_eq(RepairBayView.width_for(4.0) / RepairBayView.width_for(2.0), 2.0,
		0.001, "und zwar linear")

## Sie darf nach UNTEN wachsen: eine längere Liste zieht bay_rect mit, sonst fiele
## ein Klick auf die unterste Zeile durch die eine Weiterleitungs-Region.
func test_die_bucht_streckt_sich_mit_der_liste() -> void:
	await wait_frames(2)
	var short_rect := view.bay_rect()
	for i in run.owned_pool.size():
		run.owned_pool[i].charge = 1
	view.refresh()
	await wait_frames(2)
	assert_gt(view.bay_rect().size.y, short_rect.size.y,
		"mehr Fälle, mehr Rechteck")
	assert_eq(view.bay_rect().size.x, short_rect.size.x, "die Breite bleibt")
