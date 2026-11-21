extends GutTest
## Die SERIENSCHALTUNG an der Werkbank: die Slot-Reihe wächst mit dem Hub, die
## Steckreihenfolge IST die Rechnung, das Ziel wählt der Spieler per Klick auf einen
## physischen Pool-Würfel (choose_die), und die Vorschau ist buchstäblich
## dieselbe Rechnung wie der Griff.

## Die gemessene Kette vom 2026-11-18 (siehe test_workshop_drum_layout).
const POOL := Rect2(2916.4, 1994.8, 585.0, 487.5)
const CELL := Vector2(16.4, 40.5)
const FACE := 55.46
const U := 5.042

var view: WorkshopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = WorkshopView.new()
	add_child_autofree(view)
	view.unit_px = U
	view.data_cell_px = CELL
	view.die_face_px = FACE
	var frame := WorkshopView.drum_layout(POOL, PackDrawerView.lie_cell(CELL), FACE, U,
		0.0, 48.75)
	var bounds: Rect2 = frame["bounds"]
	view.position = bounds.position
	view.size = bounds.size
	view.drum_frame = frame
	view.run = run

## Legt count Zahlen-Pakete ins Magazin und liefert ihre uids.
func _stock(count: int) -> Array[int]:
	var uids: Array[int] = []
	for i in count:
		var pack := run.grant_pack(Pack.number_pack())
		uids.append(pack.pack_uid)
	return uids

## Fuellt die Reihe mit LEEREN Netzen auf sechs auf - der volle Turm, und eine leere
## Karte verschiebt keine Zelle und keinen Stand.
func _fill_row() -> void:
	while view.press_slot_uids().size() < GameRun.SERIES_SLOT_CAP:
		var pack := run.grant_pack(Pack.number_pack())
		pack.stamp_net = StampNet.empty_net()
		if not view.slot_pack(pack.pack_uid):
			return

## Ein Paket mit GARANTIERTEM Netz - ein leer gewürfeltes prägt nichts.
func _valued_pack(face: int, amount: int) -> Pack:
	var pack := run.grant_pack(Pack.number_pack())
	pack.stamp_net = StampNet.empty_net()
	pack.stamp_net[face] = StampNet.value_cell(amount)
	return pack

# --- Die Reihe IST die Serienlänge -----------------------------------------------

func test_the_row_carries_exactly_the_series_slots() -> void:
	await wait_frames(2)
	assert_eq(view.slot_count(), run.series_slots(), "die Reihe IST die Serienlänge")
	assert_eq(view._slot_buttons.size(), 6, "und die ist 6 ab Runde 1")
	view.refresh()
	await wait_frames(2)
	assert_eq(view._slot_buttons.size(), 6,
		"der Deckel ist die Block-Größe: eine siebte gibt es nicht")

# --- Stecken, zurückwerfen, umsortieren -------------------------------------------

func test_tapping_a_cassette_fills_the_next_free_slot() -> void:
	var uids := _stock(2)
	view._on_pack_pressed(uids[0])
	view._on_pack_pressed(uids[1])
	assert_eq(view.press_slot_uids(), uids, "in der Reihenfolge des Tippens")

func test_a_slotted_card_is_reserved_against_the_magazine() -> void:
	var uids := _stock(2)
	view.slot_pack(uids[0])
	await wait_frames(2)
	var shown: Array[int] = []
	for entry in view.drawer_entries():
		shown.append(int(entry["uid"]))
	assert_eq(shown, [uids[1]] as Array[int], "was steckt, liegt nicht mehr im Fach")

func test_clicking_a_filled_slot_reports_its_place_and_returns_it() -> void:
	var uids := _stock(1)
	view.slot_pack(uids[0])
	var seen: Array = []
	view.pack_unslotted.connect(func(slot: int, uid: int) -> void: seen.append([slot, uid]))
	view.clear_press_slot(0)
	assert_eq(seen, [[0, uids[0]]], "Platz und Karte gemeldet")
	assert_true(view.press_slot_uids().is_empty())

func test_the_row_is_cap_and_reorder_is_move_not_swap() -> void:
	view.refresh()
	var uids := _stock(3)
	for uid in uids:
		view.slot_pack(uid)
	assert_eq(view.press_slot_uids(), uids)
	view.move_slot(2, 0)
	assert_eq(view.press_slot_uids(), [uids[2], uids[0], uids[1]] as Array[int],
		"herausgenommen und eingesetzt - alles dazwischen rückt eine Stelle")

func test_the_row_never_takes_more_than_its_slots() -> void:
	var uids := _stock(9)
	for uid in uids:
		view.slot_pack(uid)
	assert_eq(view.press_slot_uids().size(), run.series_slots(),
		"über die Serienlänge geht nichts")

func test_a_locked_round_bars_the_row() -> void:
	var uids := _stock(1)
	view.editing_locked = true
	assert_false(view.slot_pack(uids[0]), "unterschrieben wird nichts mehr gesteckt")

# --- Die ZIELWAHL per Pool-Klick --------------------------------------------------

func test_choosing_a_die_reports_it_and_choosing_again_drops_it() -> void:
	var seen: Array = []
	view.die_chosen.connect(func(die: DieDefinition) -> void: seen.append(die))
	view.choose_index(3)
	assert_eq(view.chosen_die(), run.owned_pool[3], "der gewählte Würfel")
	assert_null(view.target_die(), "ohne Karte ist er noch kein Ziel - er steht zum Ansehen")
	assert_eq(view.podium_die(), run.owned_pool[3], "und zwar auf dem Podest")
	view.choose_index(3)
	assert_null(view.chosen_die(), "derselbe Tipp wählt ab")
	assert_eq(seen, [run.owned_pool[3], null], "und beides wird gemeldet")

func test_another_tap_switches_the_target() -> void:
	view.choose_index(1)
	view.choose_index(4)
	assert_eq(view.chosen_die(), run.owned_pool[4])

## scene_root meldet den angetippten PHYSISCHEN Würfel per choose_die; ein
## anderer Würfel wechselt das Ziel, null wählt ab.
func test_choose_die_selects_switches_and_clears() -> void:
	var seen: Array = []
	view.die_chosen.connect(func(die: DieDefinition) -> void: seen.append(die))
	view.choose_die(run.owned_pool[2])
	assert_eq(view.chosen_die(), run.owned_pool[2], "der angetippte Würfel ist gewählt")
	view.choose_die(run.owned_pool[5])
	assert_eq(view.chosen_die(), run.owned_pool[5], "ein anderer löst ihn ab")
	view.choose_die(null)
	assert_null(view.chosen_die(), "null wählt ab")
	assert_eq(seen, [run.owned_pool[2], run.owned_pool[5], null])

# --- ANSEHEN ist nicht AUFWERTEN - aber es gibt nur EINEN Platz: das Podest ------

## Die ERSTE Karte macht den gewählten Würfel zum Ziel, die LETZTE zurück nimmt es
## wieder - beides wird als Wechsel gemeldet, nichts sonst.
func test_die_erste_karte_macht_ihn_zum_ziel_die_letzte_nimmt_es() -> void:
	var seen: Array = []
	view.target_changed.connect(func(die: DieDefinition) -> void: seen.append(die))
	view.choose_index(2)
	await wait_frames(2)
	assert_null(view.target_die(), "gewählt, aber ohne Karte kein Ziel")
	var first := _valued_pack(0, 2)
	var second := _valued_pack(1, 3)
	view.slot_pack(first.pack_uid)
	assert_eq(view.target_die(), run.owned_pool[2], "die erste Karte: er ist Ziel")
	assert_null(view.podium_die(), "und wird nicht mehr nur angesehen")
	assert_eq(view.seated_die(), run.owned_pool[2],
		"sein Körper bleibt auf dem Podest - die Karte bewegt ihn nicht")
	view.slot_pack(second.pack_uid)
	view.clear_press_slot(0)
	assert_eq(view.target_die(), run.owned_pool[2], "eine Karte steckt noch")
	view.clear_press_slot(0)
	assert_null(view.target_die(), "die letzte zurück: kein Ziel mehr")
	assert_eq(view.chosen_die(), run.owned_pool[2], "aber weiter gewählt")
	assert_eq(view.podium_die(), run.owned_pool[2], "wieder nur angesehen")
	assert_eq(view.seated_die(), run.owned_pool[2], "und noch immer auf dem Podest")
	assert_eq(seen, [run.owned_pool[2], null], "genau zwei Wechsel")

## Stecken schon Karten, wird ein frisch gewählter Würfel sofort Ziel.
func test_ein_gewaehlter_wuerfel_bei_steckenden_karten_ist_sofort_ziel() -> void:
	view.slot_pack(_valued_pack(0, 2).pack_uid)
	view.choose_index(1)
	assert_eq(view.target_die(), run.owned_pool[1])

## Die ABWAHL des Ziels schickt ihn heim - die gesteckten Karten bleiben stecken.
func test_die_abwahl_aus_der_kammer_laesst_die_karten_stecken() -> void:
	var pack := _valued_pack(0, 2)
	view.slot_pack(pack.pack_uid)
	view.choose_index(1)
	view.clear_choice()
	assert_null(view.chosen_die())
	assert_null(view.target_die())
	assert_eq(view.press_slot_uids(), [pack.pack_uid] as Array[int], "die Karte bleibt")

## Nach dem PRÄGEN ist die Walze leer: der Würfel ist kein Ziel mehr und steht mit
## seinem neuen Stand auf dem Podest; das Ergebnis bleibt stehen.
func test_nach_dem_praegen_steht_er_wieder_auf_dem_podest() -> void:
	view.choose_index(0)
	view.slot_pack(_valued_pack(0, 2).pack_uid)
	await wait_frames(2)
	view.pull_lever()
	assert_eq(view.target_die(), run.owned_pool[0], "während der Übertragung ist er Ziel")
	view.skip_ceremony()
	await wait_frames(2)
	assert_null(view.target_die(), "danach nicht mehr")
	assert_eq(view.podium_die(), run.owned_pool[0], "er steht auf dem Podest")
	assert_true(view.showing_result(), "das Ergebnis bleibt stehen")
	assert_eq(view._podium_net.def, run.owned_pool[0], "die Die-View zeigt ihn")
	assert_eq(view._podium_net.def, run.owned_pool[0], "ORIGINAL den gebuchten Stand")

## Die DIE-VIEW des Podests: der Würfel, der dort steht - Ziel oder nicht -, sonst das
## leere Kreuz; liegt der Rohling auf, ist sie leer.
func test_die_view_des_podests_zeigt_den_podest_wuerfel() -> void:
	await wait_frames(2)
	assert_null(view._podium_net, "ohne Wahl das leere Kreuz")
	view.choose_index(4)
	await wait_frames(2)
	assert_eq(view._podium_net.def, run.owned_pool[4], "gewählt steht er dort")
	view.slot_pack(_valued_pack(0, 2).pack_uid)
	await wait_frames(2)
	assert_eq(view._podium_net.def, run.owned_pool[4], "als Ziel bleibt er dort")
	assert_eq(view._podium_net.def, run.owned_pool[4], "und ORIGINAL zeigt ihn")
	view.set_target_pack(_blank())
	await wait_frames(2)
	assert_null(view._podium_net, "der Rohling liegt auf: kein Würfel auf dem Podest")

# --- Der GRIFF --------------------------------------------------------------------

func test_the_grip_needs_a_target_and_one_stamping_card() -> void:
	var uids := _stock(1)
	await wait_frames(2)
	assert_false(view.can_pull(), "nackt greift nichts")
	view.slot_pack(uids[0])
	assert_false(view.can_pull(), "ohne Ziel auch nicht")
	view.choose_index(0)
	await wait_frames(2)
	assert_true(view.can_pull(), "Ziel plus EINE Karte genügt")
	assert_false(view._action_button.disabled, "der Sitz steht bereit")

## Warum der Knopf grau steht, sagt der INFO-SCHIRM - der Sitz selbst schweigt. Die
## Klartexte sind die EINE Begruendung, und ihre Reihenfolge ist die von can_pull:
## gezurrt vor Ziel vor Karte vor Durchbrand vor Katalysator.
func test_der_knopf_nennt_seine_bremse_in_der_reihenfolge_von_can_pull() -> void:
	await wait_frames(2)
	assert_eq(view.stamp_blocker(),
		"Kein Ziel: einen Vorrats-Würfel antippen oder einen %s auflegen." % Pack.BLANK_NAME,
		"nackt fehlt zuerst das Ziel - und es gibt seit 2026-10-26 zwei Arten davon")
	view.choose_index(0)
	await wait_frames(2)
	assert_eq(view.stamp_blocker(), "Keine Karte in der Reihe.", "dann die Karte")
	view.slot_pack(_valued_pack(0, 3).pack_uid)
	assert_eq(view.stamp_blocker(), "", "fertig: der Knopf schweigt")

func test_eine_reine_katalysator_reihe_nennt_die_fehlende_netz_karte() -> void:
	var fuel := run.grant_pack(Pack.catalyst(Pack.CATALYST_PROPELLANT))
	view.slot_pack(fuel.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	assert_eq(view.stamp_blocker(), "Nur Katalysatoren - eine Netz-Karte fehlt.")

func test_die_gezurrte_runde_schlaegt_jede_andere_bremse() -> void:
	view.editing_locked = true
	await wait_frames(2)
	assert_eq(view.stamp_blocker(), "Runde gezurrt - erst im Laden wieder.",
		"sie steht vor dem fehlenden Ziel")

func test_a_catalysts_only_series_never_stamps() -> void:
	for i in GameRun.SERIES_SLOT_CAP:
		var fuel := run.grant_pack(Pack.catalyst(Pack.CATALYST_PROPELLANT))
		view.slot_pack(fuel.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	assert_eq(view.stamping_card_count(), 0)
	assert_false(view.can_pull(), "Katalysatoren verstärken eine Projektion, sie sind keine")
	assert_true(view._action_button.disabled)

## Der Griff ist UNBEGRENZT (2026-09-05): zwei hintereinander buchen beide.
func test_two_grips_in_a_row_both_book() -> void:
	view.slot_pack(_valued_pack(0, 3).pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	var before: int = run.owned_pool[0].faces[0]
	_fill_row()
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	assert_eq(run.owned_pool[0].faces[0], before + 3, "der erste bucht")
	view.slot_pack(_valued_pack(0, 4).pack_uid)
	_fill_row()
	await wait_frames(2)
	assert_true(view.can_pull(), "und der zweite steht bereit")
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	assert_eq(run.owned_pool[0].faces[0], before + 7, "auch der zweite bucht")

func test_the_grip_books_and_burns_its_cards() -> void:
	var pack := _valued_pack(0, 3)
	view.slot_pack(pack.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	var before: int = run.owned_pool[0].faces[0]
	_fill_row()
	view.pull_lever()
	assert_eq(run.owned_pool[0].faces[0], before + 3, "gebucht ist sofort")
	assert_true(view.press_slot_uids().is_empty() or view.burning(),
		"die Reihe gehört jetzt der Zeremonie")

func test_the_ceremony_reports_the_grip_at_its_end() -> void:
	var pack := _valued_pack(1, 2)
	view.slot_pack(pack.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	var seen: Array = []
	view.series_applied.connect(func(result: Dictionary, _px: Vector2) -> void:
		seen.append(result))
	_fill_row()
	view.pull_lever()
	assert_true(view.burning(), "die Fahrt läuft")
	assert_true(seen.is_empty(), "und meldet erst am Ende")
	view.skip_ceremony()
	await wait_frames(2)
	assert_false(view.burning(), "übersprungen ist sie fertig")
	assert_eq(seen.size(), 1, "und der Griff ist gemeldet")
	assert_eq(int(Dictionary(seen[0]).get("cards", 0)), GameRun.SERIES_SLOT_CAP)

# --- DIE ÜBERTRAGUNG ---------------------------------------------------------------

## Alle Takt-Meldungen der Zeremonie in Reihenfolge, als [Kennung, Nutzlast].
func _record_press() -> Array:
	var beats: Array = []
	view.chamber_opening.connect(func(time: float) -> void: beats.append(["opening", time]))
	view.chamber_closing.connect(func(time: float) -> void: beats.append(["closing", time]))
	view.slices_locked.connect(func(time: float) -> void:
		beats.append(["locked", time]))
	view.stream_passed.connect(func(index: int, faces: Array, values: Array,
			operator: String, time: float) -> void:
		beats.append(["passed", index, faces, values, operator, time]))
	view.stream_struck.connect(func(time: float) -> void: beats.append(["struck", time]))
	return beats

## Es gibt genau EIN Netz, und es PARKT im Netz-Schirm der Netz-Spalte: der
## Schirm hält nur seinen Platz, das Netz selbst liegt genau darauf und fährt nie.
func test_the_net_screen_parks_the_one_net() -> void:
	await wait_frames(2)
	assert_eq(view._net_host.get_child_count(), 0, "der Parkplatz selbst ist leer")
	assert_almost_eq(view._net.get_global_rect().get_center().x,
		view.ist_net_center().x, 0.5, "das Netz steht auf der gemeldeten Mitte")
	assert_almost_eq(view._net.get_global_rect().get_center().y,
		view.ist_net_center().y, 0.5)

## Das Prägen ÖFFNET zuerst die Kammer (der Vor-Takt), DANN verriegeln die Scheiben -
## erst danach läuft der Strom.
func test_the_grip_opens_the_chamber_then_locks_the_slices() -> void:
	var pack := _valued_pack(0, 3)
	view.slot_pack(pack.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	var beats := _record_press()
	_fill_row()
	view.pull_lever()
	await wait_frames(2)
	assert_eq(beats.size(), 1, "erst nur der Vor-Takt")
	assert_eq(String(beats[0][0]), "opening", "die Kammer öffnet sich")
	assert_almost_eq(float(beats[0][1]), WorkshopView.CHAMBER_OPEN_TIME, 0.001)
	await wait_seconds(WorkshopView.CHAMBER_OPEN_TIME + 0.05)
	assert_true(view.burning(), "die Zeremonie läuft noch")
	assert_eq(String(beats[1][0]), "locked", "dann verriegeln die Scheiben")
	assert_almost_eq(float(beats[1][1]), view.lock_time(), 0.001,
		"und zwar in der gemeldeten Gesamtdauer")
	assert_almost_eq(view.lock_time(), WorkshopView.LOCK_TIME
		+ WorkshopView.LOCK_STAGGER * float(GameRun.SERIES_SLOT_CAP - 1), 0.001,
		"eine Scheibe plus die Staffel über die übrigen")
	assert_eq(beats.size(), 2, "kein Würfel-Takt dazwischen - er bleibt in der Kammer")
	view.skip_ceremony()

## Nach dem Einschlag der NACH-Takt: der Würfel steigt, der Boden schließt - ein Skip
## mitten in der Öffnung springt über beide ans Ende.
func test_the_chamber_closes_after_the_strike_and_a_skip_jumps_it() -> void:
	view.slot_pack(_valued_pack(0, 3).pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	var beats := _record_press()
	view.pull_lever()
	await wait_seconds(view.ceremony_time() + 0.3)
	var kinds: Array = []
	for beat in beats:
		kinds.append(String(beat[0]))
	assert_eq(kinds.front(), "opening")
	assert_eq(kinds.back(), "closing", "zuletzt schließt die Kammer")
	assert_eq(kinds[kinds.size() - 2], "struck", "nach dem Einschlag")
	assert_almost_eq(float(beats.back()[1]), WorkshopView.CHAMBER_CLOSE_TIME, 0.001)
	view.slot_pack(_valued_pack(1, 2).pack_uid)
	beats.clear()
	var applied: Array = []
	view.series_applied.connect(func(_r: Dictionary, _p: Vector2) -> void: applied.append(1))
	view.pull_lever()
	view.skip_ceremony()
	await wait_seconds(WorkshopView.CHAMBER_OPEN_TIME + 0.1)
	assert_false(view.burning(), "übersprungen")
	assert_eq(applied.size(), 1, "series_applied genau einmal")
	assert_false(beats.any(func(b: Array) -> bool: return String(b[0]) == "locked"),
		"nach dem Skip kommt kein Takt mehr")

## Je Scheibe EINE Strom-Meldung, in Serienfolge, mit ihren Zellen und dem
## aufgelaufenen Stand - genau das, was die Kassette abdunkelt und das Licht-Netz
## tickt. Zuletzt der Einschlag, und danach kommt nichts mehr.
func test_every_card_reports_its_cells_and_the_running_sum() -> void:
	var first := _valued_pack(0, 2)
	var second := _valued_pack(3, 5)
	view.slot_pack(first.pack_uid)
	view.slot_pack(second.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	var beats := _record_press()
	_fill_row()
	view.pull_lever()
	await wait_seconds(view.ceremony_time() + 0.35)
	var reads: Array = []
	for beat in beats:
		if String(beat[0]) == "passed":
			reads.append(beat)
	assert_eq(reads.size(), GameRun.SERIES_SLOT_CAP, "je Scheibe genau ein Takt")
	assert_eq(int(reads[0][1]), 0, "in Serienfolge - Index 0 liegt OBEN")
	assert_eq(reads[0][2], [0] as Array[int], "Karte 1 gibt ihre Seite her")
	assert_eq(int(reads[0][3][0]), 2, "und der Stand danach ist ihr Wert")
	assert_eq(reads[1][2], [3] as Array[int])
	assert_eq(int(reads[1][3][0]), 2, "der Stand LÄUFT AUF - Karte 1 bleibt darin")
	assert_eq(int(reads[1][3][3]), 5)
	assert_eq(String(beats[-2][0]), "struck", "dann schlägt der Strom ein")
	assert_eq(String(beats[-1][0]), "closing", "und zuletzt schließt die Kammer")

## Ein OPERATOR und ein MULTIPLIKATOR melden ihre Glyphe mit - sie schlagen
## perkussiv zu, statt still aufzunehmen.
func test_operator_and_multiplier_cards_report_their_glyph() -> void:
	var value := _valued_pack(0, 2)
	var doubler := run.grant_pack(Pack.operator_pack(StampNet.OP_DOUBLER))
	doubler.stamp_net = StampNet.empty_net()
	doubler.stamp_net[0] = StampNet.operator_cell(StampNet.OP_DOUBLER)
	var times := run.grant_pack(Pack.multiplier_pack())
	times.stamp_net = StampNet.empty_net()
	times.stamp_net[0] = StampNet.factor_cell(4)
	view.slot_pack(value.pack_uid)
	view.slot_pack(doubler.pack_uid)
	view.slot_pack(times.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	var beats := _record_press()
	_fill_row()
	view.pull_lever()
	await wait_seconds(view.ceremony_time() + 0.35)
	var operators: Array[String] = []
	for beat in beats:
		if String(beat[0]) == "passed":
			operators.append(String(beat[4]))
	assert_eq(operators.size(), GameRun.SERIES_SLOT_CAP)
	assert_eq(operators[0], "", "die Wert-Karte nennt keinen")
	assert_eq(operators[1], StampNet.operator_glyph(StampNet.OP_DOUBLER))
	assert_eq(operators[2], "×4", "das Multiplikator-Netz schlägt mit seinem Faktor zu")

## Die Fahrt darf JEDERZEIT abbrechen: der EINE Aufräum-Pfad stellt das Netz auf
## seinen Endstand, die Reihe ist leer und der Griff genau einmal gemeldet.
func test_an_aborted_ride_owes_nothing() -> void:
	var pack := _valued_pack(0, 4)
	view.slot_pack(pack.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	var park := view.ist_net_center()
	var seen: Array = []
	view.series_applied.connect(func(_result: Dictionary, _px: Vector2) -> void:
		seen.append(true))
	_fill_row()
	view.pull_lever()
	await wait_seconds(WorkshopView.STREAM_STEP * 0.5)
	view.skip_ceremony()
	await wait_frames(2)
	assert_almost_eq(view._net.get_global_rect().get_center().x, park.x, 0.5,
		"das Netz steht auf seinem Parkplatz")
	assert_almost_eq(view._net.get_global_rect().get_center().y, park.y, 0.5)
	assert_true(view.press_slot_uids().is_empty(), "die Reihe ist leer")
	assert_true(view.showing_result(), "und das Netz zeigt das ERGEBNIS")
	assert_eq(view._net.preview_die().faces[0], run.owned_pool[0].faces[0],
		"das Netz zeigt den gebuchten Stand")
	assert_eq(seen.size(), 1, "der Griff ist genau einmal gemeldet")

## Die Fahrt AUSGEFAHREN (ohne Skip): danach ist die Reihe leer, der Sitz trägt
## wieder den Griff, und das Netz steht auf seinem Parkplatz. Derselbe Endzustand,
## den auch das "Fertig" liefert.
func test_the_full_ride_lands_in_the_same_end_state() -> void:
	var pack := _valued_pack(2, 4)
	view.slot_pack(pack.pack_uid)
	view.choose_index(1)
	await wait_frames(2)
	var park := view.ist_net_center()
	_fill_row()
	view.pull_lever()
	var span := view.ceremony_time()
	await wait_seconds(span + 0.35)
	assert_false(view.burning(), "die Fahrt ist von selbst durch")
	assert_true(view.press_slot_uids().is_empty(), "die Reihe ist leer")
	assert_eq(view._action_button.text, "Prägen 0/%d" % run.series_slots(),
		"und der Zähler in der Aufschrift steht wieder auf null")
	assert_true(String(view._action_button.text).begins_with("Prägen"),
		"der Sitz trägt wieder den Griff, nicht das Fertig")
	assert_almost_eq(view._net.get_global_rect().get_center().x, park.x, 0.5,
		"das Netz steht auf seinem Parkplatz")
	assert_almost_eq(view._net.get_global_rect().get_center().y, park.y, 0.5)
	assert_eq(view._net.get_child(0).position,
		DieNetView.cell_position(0, view._net.cell), "und ungefaltet")
	assert_eq(view._net.get_child(0).scale, Vector2.ONE)

## Während der Fahrt rechnet der Soll-Schirm gegen die Ausgangslage - der gebuchte
## Stand kommt erst im Nachspiel.
func test_the_preview_holds_the_before_state_until_the_end() -> void:
	var pack := _valued_pack(0, 6)
	view.slot_pack(pack.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	var before: int = run.owned_pool[0].faces[0]
	_fill_row()
	view.pull_lever()
	await wait_frames(2)
	assert_eq(view.preview_target().faces[0], before,
		"das Netz mißt gegen den Stand VOR dem Griff")
	view.skip_ceremony()
	await wait_frames(2)
	assert_eq(run.owned_pool[0].faces[0], before + 6, "danach ist gebucht")

## Das Netz zeigt danach das ERGEBNIS: den gebuchten Stand mit den GRÜNEN Deltas -
## also den Stand VOR dem Griff plus die Projektion darüber, sonst wäre nichts grün.
func test_after_the_ride_the_net_shows_the_booked_result() -> void:
	var pack := _valued_pack(0, 5)
	view.slot_pack(pack.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	var before: int = run.owned_pool[0].faces[0]
	_fill_row()
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	assert_true(view.showing_result(), "das Ergebnis steht")
	assert_eq(view._net.def.faces[0], before, "das Netz mißt gegen den Stand DAVOR")
	assert_eq(view._net.preview_die().faces[0], before + 5,
		"und zeigt darüber den gebuchten - das ist das Grün")
	assert_false(view.preview().is_empty(), "die Rechnung der Buchung bleibt stehen")

## Der Takt hat eine RAMPE: die späteren Karten fahren schneller, ein Operator
## bekommt seinen Sondermoment obendrauf.
func test_the_beat_ramps_and_operators_get_their_moment() -> void:
	var value := _valued_pack(0, 2)
	var doubler := run.grant_pack(Pack.operator_pack(StampNet.OP_DOUBLER))
	doubler.stamp_net = StampNet.empty_net()
	doubler.stamp_net[0] = StampNet.operator_cell(StampNet.OP_DOUBLER)
	view.refresh()
	var third := _valued_pack(1, 1)
	view.slot_pack(value.pack_uid)
	view.slot_pack(third.pack_uid)
	view.slot_pack(doubler.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	_fill_row()
	view.pull_lever()
	assert_lt(view.card_beat(3), view.card_beat(1), "die Rampe zieht an")
	assert_gt(view.card_beat(2), view.card_beat(1),
		"der Operator bekommt seine %.2f s dazu" % WorkshopView.STREAM_OPERATOR_EXTRA)
	var span := WorkshopView.CHAMBER_OPEN_TIME + view.lock_time()
	for i in GameRun.SERIES_SLOT_CAP:
		span += view.card_beat(i)
	span += WorkshopView.STRIKE_TIME + WorkshopView.STRIKE_HOLD
	span += WorkshopView.CHAMBER_CLOSE_TIME
	assert_almost_eq(view.ceremony_time(), span, 0.001,
		"ceremony_time IST die Summe aller Takte, Vor- und Nach-Takt eingeschlossen")
	view.skip_ceremony()

# --- Die LIVE-VORSCHAU ------------------------------------------------------------

func test_the_preview_is_the_same_calculation_as_the_booking() -> void:
	var pack := _valued_pack(2, 5)
	view.slot_pack(pack.pack_uid)
	view.choose_index(7)
	await wait_frames(2)
	var projection := view.preview()
	assert_eq(projection["faces_after"],
		run.resolve_series(view.press_slot_uids(), run.owned_pool[7])["faces_after"],
		"Vorschau und Buchung rechnen dasselbe")
	assert_eq(int(projection["bonus"][2]), 5)

func test_without_a_target_there_is_nothing_to_preview() -> void:
	var pack := _valued_pack(0, 2)
	view.slot_pack(pack.pack_uid)
	await wait_frames(2)
	assert_true(view.preview().is_empty(), "ohne Zielwürfel keine Rechnung")

## Die REIHENFOLGE ist die Entscheidung: derselbe Satz Karten, andere Ordnung,
## anderes Ergebnis - der Verdoppler rechnet auf der aufgelaufenen Summe.
func test_the_order_of_the_row_changes_the_result() -> void:
	var value := _valued_pack(0, 3)
	var doubler := run.grant_pack(Pack.operator_pack(StampNet.OP_DOUBLER))
	doubler.stamp_net = StampNet.empty_net()
	doubler.stamp_net[0] = StampNet.operator_cell(StampNet.OP_DOUBLER)
	view.slot_pack(value.pack_uid)
	view.slot_pack(doubler.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	assert_eq(int(view.preview()["bonus"][0]), 6, "Wert, dann Verdoppler")
	view.move_slot(1, 0)
	await wait_frames(2)
	assert_eq(int(view.preview()["bonus"][0]), 3, "Verdoppler zuerst verdoppelt nichts")

# --- Der GRIFF trägt den Zähler ---------------------------------------------------

## Der Serien-Schirm ist tot: wie voll die Reihe ist, steht in der Aufschrift des
## Knopfs - "Prägen gesteckt/Serienlänge".
func test_the_stamp_label_counts_the_slots() -> void:
	var uids := _stock(1)
	await wait_frames(2)
	assert_eq(view.stamp_label(), "Prägen 0/%d" % run.series_slots())
	assert_true(view._action_button.visible, "leer steht er da")
	assert_true(view._action_button.disabled, "und grau")
	view.slot_pack(uids[0])
	await wait_frames(2)
	assert_true(view._action_button.visible, "gesteckt steht er da")
	assert_eq(view._action_button.text, "Prägen 1/%d" % run.series_slots())

## Der SERIEN-Schirm ist tot (der Zähler steht in der Griff-Aufschrift), und der
## eigene SUMMEN-Schirm auch: die Summe steht in UPGRADES, mitten in der Gleichung.
func test_the_series_and_sum_screens_are_gone() -> void:
	await wait_frames(2)
	assert_false(view.has_method("series_text"), "kein Serien-Schirm mehr")
	assert_false(view.has_method("set_info"), "und kein dreizeiliger Tooltip mehr")
	assert_null(view.get_node_or_null("Street/SumScreen"), "kein Summen-Schirm mehr")
	assert_null(view.get_node_or_null("Street/BeforeScreen"), "VORHER ist gestorben")
	assert_null(view.get_node_or_null("Street/AfterScreen"), "NACHHER ebenso")
	for screen in ["PodiumScreen", "UpgradesScreen", "ResultScreen"]:
		assert_not_null(view.get_node_or_null("Street/" + screen), "%s steht" % screen)

# --- UPGRADES: die SUMME DER SERIE -------------------------------------------------
# UPGRADES zeigt die REINE Summe der gesteckten Prägenetze, mit Ziel wie ohne.

func _sum_view() -> Control:
	return view.get_node("Street/UpgradesScreen/Net").get_child(0)

## Ohne Karte steht dort das LEERE KREUZ.
func test_the_sum_screen_shows_the_empty_cross_without_a_card() -> void:
	await wait_frames(2)
	assert_eq(_sum_view().name, "EmptyNet", "leer heißt: sechs dunkle Zellen")
	assert_eq(_sum_view().get_child_count(), 6)

## Mit Karten die SUMME - in Steckreihenfolge und OHNE Zielwürfel: ein Verdoppler
## NACH der Wert-Karte verdoppelt, DAVOR nicht (derselbe Kartensatz wie oben).
func test_the_sum_screen_sums_the_slotted_nets_in_order() -> void:
	var value := _valued_pack(0, 3)
	var doubler := run.grant_pack(Pack.operator_pack(StampNet.OP_DOUBLER))
	doubler.stamp_net = StampNet.empty_net()
	doubler.stamp_net[0] = StampNet.operator_cell(StampNet.OP_DOUBLER)
	view.slot_pack(value.pack_uid)
	view.slot_pack(doubler.pack_uid)
	await wait_frames(2)
	assert_null(view.target_die(), "kein Ziel gewählt - die Summe steht trotzdem")
	assert_eq(_sum_view().name, "SeriesSum", "der Schirm trägt die Summe")
	assert_eq(int(view._sum_projection["bonus"][0]), 6, "Wert, dann Verdoppler")
	view.move_slot(1, 0)
	await wait_frames(2)
	assert_eq(int(view._sum_projection["bonus"][0]), 3,
		"Verdoppler zuerst verdoppelt nichts")

## Der HOVER rührt die Summe nicht an - die Karte trägt ihr Netz selbst.
func test_hovering_a_card_keeps_the_sum() -> void:
	var slotted := _valued_pack(0, 3)
	view.slot_pack(slotted.pack_uid)
	await wait_frames(2)
	view.sync_hover_at(view._slot_buttons[0].get_global_rect().get_center())
	assert_eq(_sum_view().name, "SeriesSum", "die Summe bleibt stehen")
	assert_eq(view.hover_pack_name(), slotted.display_name)

## Mit Zielwürfel: ORIGINAL der Würfel, UPGRADES die Summe, ERGEBNIS die Vorschau.
func test_with_a_target_the_equation_reads_original_upgrades_result() -> void:
	var value := _valued_pack(0, 3)
	view.slot_pack(value.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	assert_eq(view.get_node("Street/ResultScreen/Net").get_child_count(), 0,
		"keine Karte neben dem Vorschau-Netz")
	assert_eq(_sum_view().name, "SeriesSum", "UPGRADES trägt die Summe auch mit Ziel")
	assert_false(view._net.projection.is_empty(), "ERGEBNIS ist die Vorschau")
	assert_eq(view._podium_net.def, view.target_die(), "ORIGINAL ist der Würfel")
	assert_true(view._podium_net.projection.is_empty(), "wie er IST")

## Die CAPTION ist am 2026-09-11 gestorben - der Info-Schirm fragt statt dessen
## nach dem PAKET unter dem Zeiger, und die ETAGE schlägt das Magazin.
func test_hover_pack_names_the_floor_before_the_magazine() -> void:
	var slotted := _valued_pack(0, 3)
	var spare := _valued_pack(1, 2)
	view.slot_pack(slotted.pack_uid)
	await wait_frames(2)
	assert_null(view.hover_pack(), "ohne Zeiger liegt keine Karte da")
	view.sync_hover_at(view.pack_anchor_px(spare.pack_uid))
	assert_eq(view.hover_pack(), spare, "die Magazin-Kassette unter dem Zeiger")
	view.sync_hover_at(view._slot_buttons[0].get_global_rect().get_center())
	view._hover_pack_uid = spare.pack_uid  # beides zugleich: die Etage gewinnt
	assert_eq(view.hover_pack(), slotted)
	assert_false(view.get_script().get_script_constant_map().has("CAPTION_STEPS"),
		"die Konstanten der Caption sind fort")
	assert_false(view.has_method("set_caption"), "und ihr Schreiber ebenso")
	assert_false(view.has_method("caption_text"))

## Und eine Zelle des Summen-Netzes erklärt sich selbst: Zahl und Material im
## Klartext, aus denselben Quellen wie jedes andere Netz.
func test_a_sum_cell_explains_itself() -> void:
	var value := _valued_pack(0, 2)
	var stuff := run.grant_pack(Pack.material_pack())
	stuff.stamp_net = StampNet.empty_net()
	stuff.stamp_net[1] = StampNet.material_cell(DieMaterial.RUBY)
	view.slot_pack(value.pack_uid)
	view.slot_pack(stuff.pack_uid)
	await wait_frames(2)
	var rect := _sum_view().get_global_rect()
	var cell := view._sum_cell
	var number := rect.position + DieNetView.cell_position(0, cell) + Vector2.ONE * cell * 0.5
	assert_true(view.net_hint_at(number).contains("+2"),
		"die Zahl-Zelle nennt ihren Zuschlag: %s" % view.net_hint_at(number))
	var stone := rect.position + DieNetView.cell_position(1, cell) + Vector2.ONE * cell * 0.5
	assert_true(view.net_hint_at(stone).contains(DieMaterial.by_id(DieMaterial.RUBY).display_name),
		"die Material-Zelle nennt ihr Material: %s" % view.net_hint_at(stone))

# --- Was scene_root an der Reihe abliest -------------------------------------------

func test_the_row_reports_sorts_places_and_cards() -> void:
	var number := run.grant_pack(Pack.number_pack())
	var material := run.grant_pack(Pack.material_pack())
	view.slot_pack(number.pack_uid)
	view.slot_pack(material.pack_uid)
	await wait_frames(2)
	assert_eq(view.press_slot_sorts(),
		[Engraving.CATEGORY_NUMBER, Engraving.CATEGORY_MATERIAL] as Array[String])
	assert_eq(view.press_slot_anchors().size(), view.slot_count(),
		"auch die leeren Schächte melden ihren Mund")
	assert_eq(view.press_slot_anchors().size(), view.slot_count())

## Die Körper gehören scene_root, die PLÄTZE meldet das Fenster: das PODEST in der
## Gleichung (Platte über seiner Die-View) und die KAMMER ganz in der Platte.
func test_the_window_reports_podium_and_chamber() -> void:
	await wait_frames(2)
	assert_true(view.bench_open(), "die Straße ist Möbel, kein Ablauf")
	assert_gt(view.target_net_center().x, 0.0, "das Podest meldet seinen Anker")
	var plate := view.podium_plate_px()
	assert_true(plate.grow(0.05).encloses(view.chamber_rect_px()), "die KAMMER liegt unter der Platte")
	assert_true(view.podium_rect_px().grow(0.05).encloses(view.chamber_rect_px()), "im Podest-Platz")
	assert_true(plate.has_point(view.podium_stage_center()), "der Podest-Anker liegt auf der Platte")
	var net := view._global(view.podium_net_rect())
	assert_gt(net.position.y, plate.end.y, "die Die-View steht unter der Platte")
	assert_true(view.podium_rect_px().grow(0.05).encloses(net), "beide im Podest-Platz")
	assert_true(view.hit_rects().has(view.podium_rect_px()), "der Platz nimmt Klicks")
	assert_false(view.has_method("target_projector_y"), "die Projektor-Zeile ist gestorben")

# --- Der Zeiger hebt den Beitrag EINER Karte hervor --------------------------------

func test_hovering_a_card_highlights_its_cells() -> void:
	var pack := _valued_pack(4, 2)
	view.slot_pack(pack.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	assert_true(view._net.highlight.is_empty(), "ohne Zeiger leuchtet alles gleich")
	view.sync_hover_at(view._slot_buttons[0].get_global_rect().get_center())
	await wait_frames(2)
	assert_eq(view._net.highlight, [4] as Array[int],
		"die überfahrene Karte zeigt IHRE Zelle")

func test_a_fresh_run_drops_the_standing_series() -> void:
	var uids := _stock(1)
	view.slot_pack(uids[0])
	view.choose_index(2)
	await wait_frames(2)
	view.run = GameRun.new_run()
	await wait_frames(2)
	assert_true(view.press_slot_uids().is_empty(), "die Reihe des alten Laufs ist fort")
	assert_null(view.target_die(), "und sein Ziel ebenso")

# --- Die SCHACHT-REIHE: das Fenster malt nur Löcher und MELDET ihre Anker ----------

## Die 2D-Karten-Attrappen sind mit der Bühnen-Straße gestorben: im Fenster steht
## kein Abbild einer Kassette mehr, nur ihr Schacht - der Körper gehört scene_root.
func test_the_row_carries_no_card_mockups() -> void:
	var uids := _stock(1)
	view.slot_pack(uids[0])
	await wait_frames(2)
	assert_false("SlotCard" in _node_names(view), "keine Karten-Attrappe im Fenster")
	assert_false("SlotCardSeat" in _node_names(view))
	assert_eq(view._slot_buttons.size(), view.slot_count(),
		"gemeldet werden die SCHEIBEN, nicht gemalte Karten")

## Alle Namen im Fensterbaum - der Beweis, dass etwas NICHT mehr gebaut wird.
func _node_names(root: Node) -> Array[String]:
	var names: Array[String] = []
	for child in root.get_children():
		names.append(String(child.name))
		names.append_array(_node_names(child))
	return names

## Fach-Anker und Karten-Fläche sind derselbe Platz (die Karte LIEGT in ihrem
## Fach) - und beide rühren sich beim Legen keinen Byte weit.
func test_the_fach_anchors_stand_still_through_slotting() -> void:
	var uids := _stock(2)
	await wait_frames(2)
	var mouths := view.press_slot_anchors()
	var faces := view.press_slot_anchors()
	assert_eq(mouths, faces, "das FACH IST die Karten-Fläche")
	view.slot_pack(uids[0])
	await wait_frames(2)
	assert_eq(view.press_slot_anchors(), mouths, "gelegt: die Fächer stehen")
	view.clear_press_slot(0)
	await wait_frames(2)
	assert_eq(view.press_slot_anchors(), mouths, "zurückgenommen: sie stehen weiter")

## Umsortieren tauscht die uids der Plätze - der KÖRPER fährt um, das Fenster
## meldet dafür nur die neue Reihenfolge auf denselben Ankern.
func test_reordering_keeps_the_anchors_and_swaps_the_uids() -> void:
	view.refresh()
	var uids := _stock(2)
	view.slot_pack(uids[0])
	view.slot_pack(uids[1])
	await wait_frames(2)
	var anchors := view.press_slot_anchors()
	view.move_slot(1, 0)
	await wait_frames(2)
	assert_eq(view.press_slot_uids(), [uids[1], uids[0]] as Array[int],
		"die Reihenfolge IST die Rechenreihenfolge")
	assert_eq(view.press_slot_anchors(), anchors, "der Turm selbst steht still")

## WELLE L: die Karte in ihrer Etage LIEGT in der EINEN Kartengröße - derselben wie
## im Magazin. Das eigene Schacht-Maß (socket_cell_scale) ist gestorben.
func test_a_tower_cassette_lies_at_the_one_card_size() -> void:
	view.data_cell_px = Vector2(16, 40)
	await wait_frames(2)
	assert_almost_eq(view.lie_span_px().y, 40.0 * PackDrawerView.CASSETTE_SCALE,
		0.001, "die KARTENBREITE in ihrer einen Größe")
	assert_almost_eq(view.lie_span_px().x,
		40.0 * WorkshopView.CARD_ASPECT * PackDrawerView.CASSETTE_SCALE, 0.001,
		"und ihre Langseite quer dazu")
	assert_almost_eq(view.shelf_cell_scale(), PackDrawerView.CASSETTE_SCALE, 0.001,
		"und das Magazin stellt sie in genau derselben - Turm == Magazin")
	assert_false(view.has_method("socket_cell_scale"),
		"es gibt keinen kontext-eigenen Maßstab mehr")

# --- DIE WALZE: EINE Kartengröße, die Scheiben liegen nebeneinander -------------

## Die Scheiben liegen NEBENEINANDER in EINER Zeile, Scheibe 1 links.
func test_the_slices_lie_in_one_row_left_to_right() -> void:
	await wait_frames(2)
	assert_gt(view._slot_buttons.size(), 1)
	var first: Rect2 = view._slot_buttons[0].get_global_rect()
	var second: Rect2 = view._slot_buttons[1].get_global_rect()
	assert_gt(second.position.x, first.position.x, "Scheibe 2 liegt RECHTS von Scheibe 1")
	assert_almost_eq(second.position.y, first.position.y, 0.001, "in EINER Zeile")
	assert_almost_eq(first.size.x, WorkshopView.slice_length_px(view.lie_span_px()), 0.001,
		"eine Scheibe ist so lang wie die liegende Karte samt Luft")

## Die MASSEINHEIT darf von außen vorgegeben werden: der Streifen ist breiter als
## seine 100 u, sonst zerrisse die gewachsene Reihe die senkrechte Rechnung.
func test_the_reported_unit_beats_the_window_width() -> void:
	view.unit_px = 0.0
	await wait_frames(2)
	var own := view.size.x / 100.0
	assert_almost_eq(view.unit(), own, 0.001, "ohne Meldung die u-Konvention")
	view.unit_px = own * 0.5
	await wait_frames(2)
	assert_almost_eq(view.unit(), own * 0.5, 0.001, "gemeldet schlägt gerechnet")

## Die gemeldeten ANKER sind die Mitten der Scheiben - die Höhe der Karte darauf
## rechnet der Körper.
func test_the_anchors_name_the_slice_centres() -> void:
	await wait_frames(2)
	var anchors := view.press_slot_anchors()
	assert_eq(anchors.size(), view.slot_count())
	for i in anchors.size():
		var centre := view._global(view.slice_rect(i)).get_center()
		assert_almost_eq(anchors[i].x, centre.x, 0.001)
		assert_almost_eq(anchors[i].y, centre.y, 0.001)

# --- DER EINE NETZ-SCHIRM unter dem Podest (WELLE S) -------------------------------
# Die Aufschlüsselungs-Zeilen sind tot, die dritte Spalte auch - der Schirm trägt
# das EINE Netz: Vorschau, Ergebnis, grüne Deltas.

## Die Diff-Zeilen sind restlos fort - weder Rechnung noch Zeilen-Hover.
func test_the_breakdown_rows_are_dead() -> void:
	assert_false(view.has_method("diff_rows"), "keine Aufschlüsselungs-Zeilen mehr")
	assert_false(view.has_method("diff_row_slot_at"), "und kein Zeilen-Hover")

## Die drei Netze der Gleichung sind gleich groß: ERGEBNIS und ORIGINAL teilen die Zelle
## der Die-View.
func test_both_nets_share_the_die_view_cell() -> void:
	view.choose_index(0)
	view.slot_pack(_valued_pack(0, 2).pack_uid)
	await wait_frames(2)
	var cell := view.podium_cell()
	assert_almost_eq(view._net.cell, cell, 0.001, "ERGEBNIS in der Zelle der Die-View")
	assert_almost_eq(view._podium_net.cell, cell, 0.001, "und ORIGINAL dasselbe Maß")

## OHNE Ziel rechnet der Netz-Schirm nichts - er hängt allein am gewählten
## Zielwürfel; der wartende Neuzugang wird von der Info-Säule am Fach gezeigt.
func test_the_net_screen_hangs_on_the_target_alone() -> void:
	run.stash_die(DieDefinition.standard(), 0)  # stash_die hinterlegt eine eigene Kopie
	await wait_frames(2)
	assert_null(view.preview_target(), "ohne Ziel steht kein Würfel im Schirm")
	assert_true(view.preview().is_empty())
	view.choose_index(0)
	await wait_frames(2)
	assert_eq(view.preview_target(), view.target_die(), "gewählt rechnet er auf ihm")
	view.clear_choice()
	await wait_frames(2)
	assert_null(view.preview_target(), "abgewählt ist er wieder dunkel")

# --- WELLE U: DER BLOCK und der SCANNER --------------------------------------------

## Die SCHABLONEN-FAHRT ist tot: kein Wechsel-Takt, keine Schiene, keine Faltung -
## das Fenster meldet nur noch Abflug, Presshub und Scan.
func test_the_stencil_ride_is_gone() -> void:
	await wait_frames(2)
	assert_false(view.has_signal("die_handover"), "kein Wechsel-Takt mehr")
	assert_false(view.has_signal("stencil_launched"), "und keine Schablone mehr")
	assert_false(view.has_signal("stencil_folded"))
	assert_false(view.has_method("dim_ist_net"), "das Netz gibt nichts mehr ab")
	assert_false(view.has_signal("card_fused"), "und kein wachsender Block mehr")
	assert_false(view.has_signal("block_travelled"))
	assert_false(view.has_signal("stack_lifted"), "und keine LAWINE mehr")
	assert_false(view.has_signal("stack_slid"))
	assert_false(view.has_signal("stack_dropped"))
	assert_false(view.has_signal("stack_scanned"))
	assert_true(view.has_signal("slices_locked"))
	assert_true(view.has_signal("stream_passed"))
	assert_true(view.has_signal("stream_struck"))
	for dead in ["cards_latched", "die_raised", "light_passed", "light_struck",
			"die_returned"]:
		assert_false(view.has_signal(dead), "%s ist mit dem Durchlicht gestorben" % dead)
	var net := view.ist_net_center()
	assert_gt(net.x, 0.0, "der Parkplatz des Netzes steht")
	assert_almost_eq(net.x, view.result_net_rect().get_center().x
		+ view.get_global_rect().position.x, 1.0, "und liegt in ERGEBNIS")

## Der Zielwürfel behält seine ALTEN Augen, bis die Funken einschlagen: held_faces
## trägt den Stand VOR dem Griff und ist danach wieder leer.
func test_the_window_holds_the_faces_before_the_grip() -> void:
	var pack := _valued_pack(0, 4)
	view.slot_pack(pack.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	assert_null(view.held_faces(), "ohne Zeremonie hält es nichts")
	var before: int = run.owned_pool[0].faces[0]
	_fill_row()
	view.pull_lever()
	await wait_frames(2)
	var held := view.held_faces()
	assert_not_null(held, "während der Zeremonie steht der alte Stand")
	assert_eq(held.faces[0], before)
	assert_eq(run.owned_pool[0].faces[0], before + 4, "gebucht ist längst")
	view.skip_ceremony()
	await wait_frames(2)
	assert_null(view.held_faces(), "danach hält es nichts mehr")

## VORHER hält den alten Stand wie der Würfel und springt erst mit dem EINSCHLAG
## der Funken auf den gebuchten.
func test_before_jumps_with_the_strike() -> void:
	var pack := _valued_pack(0, 4)
	view.slot_pack(pack.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	var before: int = run.owned_pool[0].faces[0]
	var struck: Array[float] = []
	view.stream_struck.connect(func(t: float) -> void: struck.append(t))
	view.pull_lever()
	await wait_frames(2)
	assert_eq(view.before_die().faces[0], before, "VORHER zeigt den alten Stand")
	while struck.is_empty() and view.burning():
		await wait_frames(1)
	assert_eq(view.before_die().faces[0], before, "auch noch beim Abflug der Funken")
	await wait_seconds(WorkshopView.STRIKE_TIME + 0.05)
	assert_eq(view.before_die().faces[0], before + 4, "mit dem Einschlag der neue")
	assert_eq(view._podium_net.def, view.target_die(), "und das Netz zeigt ihn")
	assert_null(view.held_faces(), "der Würfel hält ab dem Einschlag nichts mehr")

## Die Kartendaten der Zeremonie tragen die PAKETGRÖSSE - daraus nimmt der Block
## seine Intensität.
func test_the_card_data_carries_the_tier() -> void:
	var pack := _valued_pack(0, 2)
	pack.tier = Pack.TIER_KOLOSSAL
	assert_eq(int(WorkshopView.card_data(pack.pack_uid, pack).get("tier", -1)),
		Pack.TIER_KOLOSSAL)
	view.slot_pack(pack.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	_fill_row()
	view.pull_lever()
	await wait_frames(2)
	var cards := view.burning_cards()
	assert_eq(cards.size(), GameRun.SERIES_SLOT_CAP)
	assert_eq(int(cards[0].get("tier", -1)), Pack.TIER_KOLOSSAL)
	assert_false(view.burn_projection().is_empty(), "und die Projektion steht")
	view.skip_ceremony()

## Die letzte Etappe des Stroms ist der Einschlag - danach schließt nur noch die Kammer.
func test_the_last_leg_is_the_strike() -> void:
	var pack := _valued_pack(0, 3)
	view.slot_pack(pack.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	var beats := _record_press()
	_fill_row()
	view.pull_lever()
	await wait_seconds(view.ceremony_time() + 0.35)
	assert_eq(String(beats[-1][0]), "closing", "zuletzt schließt die Kammer")
	assert_eq(String(beats[-2][0]), "struck", "davor schlägt der Strom ein")
	assert_eq(String(beats[-3][0]), "passed", "direkt nach der letzten Scheibe")
	assert_almost_eq(float(beats[-2][1]), WorkshopView.STRIKE_TIME, 0.001)

## Skip MITTEN im STROM: das Ende ist genau einmal gemeldet, die Reihe leer, und der
## Endstand ist derselbe wie bei der ausgefahrenen Zeremonie.
func test_a_skip_inside_the_stream_owes_nothing() -> void:
	var pack := _valued_pack(3, 4)
	view.slot_pack(pack.pack_uid)
	view.choose_index(2)
	await wait_frames(2)
	var before: int = run.owned_pool[2].faces[3]
	var seen: Array = []
	view.series_applied.connect(func(_result: Dictionary, _px: Vector2) -> void:
		seen.append(true))
	_fill_row()
	view.pull_lever()
	await wait_seconds(view.chamber_open_time() + view.lock_time()
		+ WorkshopView.STREAM_STEP * 1.5)
	assert_true(view.burning(), "der Strom läuft noch")
	view.skip_ceremony()
	await wait_frames(2)
	assert_eq(seen.size(), 1, "der Griff ist genau einmal gemeldet")
	assert_true(view.press_slot_uids().is_empty(), "die Reihe ist leer")
	assert_eq(run.owned_pool[2].faces[3], before + 4, "gebucht ist gebucht")
	assert_true(view.showing_result(), "und das Ergebnis steht")

## Nach der Buchung STEHT das Ergebnis: das Netz zeigt den gebuchten Würfel mit den
## grünen Deltas - bis abgewählt wird.
func test_the_result_stands_until_the_target_is_dropped() -> void:
	var pack := _valued_pack(1, 3)
	view.slot_pack(pack.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	var before: int = run.owned_pool[0].faces[1]
	_fill_row()
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	assert_true(view.showing_result(), "das Ergebnis steht")
	assert_eq(view._net.def.faces[1], before, "das Netz mißt gegen den Stand DAVOR")
	assert_eq(view._net.preview_die().faces[1], before + 3,
		"und zeigt darüber den gebuchten - das ist das Grün")
	view.clear_choice()
	await wait_frames(2)
	assert_false(view.showing_result(), "abgewählt verfällt das Ergebnis")
	assert_true(view.preview().is_empty(), "und es gibt nichts mehr zu rechnen")

## Ein ANDERES Ziel räumt das Ergebnis ebenso fort - es gehört EINEM Würfel.
func test_another_target_drops_the_standing_result() -> void:
	var pack := _valued_pack(0, 2)
	view.slot_pack(pack.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	_fill_row()
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	assert_true(view.showing_result())
	view.choose_index(3)
	await wait_frames(2)
	assert_false(view.showing_result(), "das Ergebnis gehörte dem anderen Würfel")
	assert_eq(view.chosen_die(), run.owned_pool[3], "gewählt ist der neue")

## Eine frisch gesteckte Karte übernimmt den Schirm sofort wieder als VORSCHAU -
## das stehende Ergebnis ist ein Nachklang, kein Zustand.
func test_a_fresh_card_takes_the_screen_back_from_the_result() -> void:
	view.refresh()
	var first := _valued_pack(0, 2)
	var second := _valued_pack(4, 1)
	view.slot_pack(first.pack_uid)
	view.choose_index(0)
	await wait_frames(2)
	_fill_row()
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	assert_true(view.showing_result())
	view.slot_pack(second.pack_uid)
	await wait_frames(2)
	assert_false(view.showing_result(), "die neue Karte rechnet, statt zu erinnern")
	assert_eq(view.preview_target(), run.owned_pool[0], "und zwar auf dem echten Würfel")
	assert_eq(int(view.preview()["bonus"][4]), 1, "mit ihrem eigenen Beitrag")

# --- WARUM der Griff schweigt ------------------------------------------------------
## Eine geschlossene Bremse stand bisher stumm im Knopf: der Spieler sah einen
## grauen Griff und keinen Grund. Die Caption nennt die ERSTE geschlossene.

func test_a_ready_grip_says_nothing() -> void:
	view.choose_die(run.owned_pool[0])
	view.slot_pack(_valued_pack(0, 2).pack_uid)
	_fill_row()
	assert_true(view.can_pull(), "Ziel plus Karten reichen")
	assert_eq(view.stamp_blocker(), "", "wer greifen darf, bekommt keine Mahnung")

func test_a_zurred_round_names_itself() -> void:
	view.choose_die(run.owned_pool[0])
	view.slot_pack(_valued_pack(0, 2).pack_uid)
	_fill_row()
	view.editing_locked = true
	assert_false(view.can_pull())
	assert_true(view.stamp_blocker().contains("gezurrt"),
		"die gesperrte Werkstatt nennt sich: %s" % view.stamp_blocker())

func test_a_missing_target_names_itself() -> void:
	var pack := _valued_pack(0, 2)
	view.slot_pack(pack.pack_uid)
	assert_null(view.target_die(), "ohne Tipp auf den Vorrat steht kein Ziel")
	assert_true(view.stamp_blocker().contains("Ziel"),
		"das fehlende Ziel nennt sich: %s" % view.stamp_blocker())

func _blank() -> Pack:
	return run.grant_pack(Pack.blank_card())

func test_ein_rohling_als_ziel_schaltet_den_knopf_auf_verdichten() -> void:
	var blank := _blank()
	view.slot_pack(_valued_pack(0, 3).pack_uid)
	view.set_target_pack(blank)
	await wait_frames(2)
	assert_true(view.compressing(), "das Podest verdichtet")
	assert_eq(view.stamp_label(), "Verdichten 1/6", "und der Knopf sagt es")
	assert_true(view.can_pull())
	assert_eq(view.stamp_blocker(), "")

## Die Kammer trägt EIN Ziel: liegt der Rohling dort, bleibt der Würfel gewählt auf dem
## Podest; wird er zurückgelegt, zieht der Würfel in die Kammer nach.
func test_rohling_und_wuerfel_schliessen_einander_als_ziel_aus() -> void:
	var blank := _blank()
	view.choose_index(0)
	view.slot_pack(_valued_pack(0, 2).pack_uid)
	await wait_frames(2)
	assert_eq(view.target_die(), run.owned_pool[0], "mit Karte ist er Ziel")
	view.set_target_pack(blank)
	await wait_frames(2)
	assert_null(view.target_die(), "der Rohling ist jetzt das Ziel")
	assert_eq(view.chosen_die(), run.owned_pool[0], "der Würfel bleibt gewählt")
	assert_eq(view.podium_die(), run.owned_pool[0], "und steht auf dem Podest")
	view.set_target_pack(blank)
	await wait_frames(2)
	assert_null(view.target_pack(), "derselbe Tipp legt den Rohling zurück")
	assert_eq(view.target_die(), run.owned_pool[0], "und der Würfel zieht nach")

func test_derselbe_rohling_waehlt_ab() -> void:
	var blank := _blank()
	view.set_target_pack(blank)
	await wait_frames(2)
	view.set_target_pack(blank)
	await wait_frames(2)
	assert_null(view.target_pack(), "derselbe wählt ab")
	assert_false(view.compressing())

## Der ZIEL-Rohling steckt nie in seiner eigenen Reihe.
func test_der_ziel_rohling_faellt_aus_der_reihe() -> void:
	var blank := _blank()
	view.slot_pack(blank.pack_uid)
	await wait_frames(2)
	assert_eq(view.press_slot_uids(), [blank.pack_uid] as Array[int], "erst steckt er")
	view.set_target_pack(blank)
	await wait_frames(2)
	assert_false(view.press_slot_uids().has(blank.pack_uid),
		"als Ziel ist er kein Futter mehr")

func test_der_knopf_nennt_die_bremsen_des_verdichtens() -> void:
	var blank := _blank()
	view.set_target_pack(blank)
	await wait_frames(2)
	assert_eq(view.stamp_blocker(), "Keine Karte in der Reihe.")
	var op := run.grant_pack(Pack.operator_pack(StampNet.OP_MIRROR))
	view.slot_pack(op.pack_uid)
	await wait_frames(2)
	assert_eq(view.stamp_blocker(), "Operatoren lassen sich nicht verdichten.")
	assert_false(view.can_pull())

func test_ein_katalysator_sperrt_das_verdichten_mit_klartext() -> void:
	var blank := _blank()
	view.slot_pack(run.grant_pack(Pack.catalyst(Pack.CATALYST_PROPELLANT)).pack_uid)
	view.set_target_pack(blank)
	await wait_frames(2)
	assert_eq(view.stamp_blocker(),
		"Katalysatoren verdichten nicht - sie wirken auf einen Würfel.")

## Die ganze Fahrt: buchen vor dem Licht, dann dieselben Takte wie beim Prägen - die
## Funken schlagen in den Rohling in der Kammer.
func test_das_verdichten_bucht_vor_dem_licht_und_schlaegt_in_den_rohling() -> void:
	var blank := _blank()
	var fuel := _valued_pack(0, 5)
	view.slot_pack(fuel.pack_uid)
	view.set_target_pack(blank)
	await wait_frames(2)
	var beats: Array[String] = []
	view.stream_passed.connect(func(_i: int, _f: Array, _v: Array, _g: String,
			_t: float) -> void: beats.append("passed"))
	view.stream_struck.connect(func(_t: float) -> void: beats.append("struck"))
	var locked: Array[float] = []
	view.slices_locked.connect(func(t: float) -> void: locked.append(t))
	var chamber: Array[float] = []
	view.chamber_opening.connect(func(t: float) -> void: chamber.append(t))
	view.chamber_closing.connect(func(t: float) -> void: chamber.append(t))
	var applied: Array = []
	view.series_applied.connect(func(result: Dictionary, _px: Vector2) -> void:
		applied.append(result))
	view.pull_lever()
	assert_eq(int(StampNet.cell_at(blank.stamp_net, 0)["value"]), 5,
		"gebucht vor dem Licht")
	assert_true(view.burning(), "und die Fahrt läuft")
	assert_true(view.compressing(), "sie weiß noch, daß sie verdichtet")
	assert_eq(locked.size(), 1, "die Scheiben verriegeln sofort")
	assert_eq(view.chamber_open_time(), 0.0, "beim Verdichten bleibt die Kammer zu")
	await wait_seconds(view.ceremony_time() + 0.3)
	assert_false(view.burning(), "sie läuft zu Ende")
	assert_eq(beats, ["passed", "struck"] as Array[String],
		"der Strom liest die Karte, dann schlägt er in den Rohling")
	assert_eq(applied.size(), 1, "und sie meldet das Verdichten")
	assert_true(chamber.is_empty(), "kein Vor- und kein Nach-Takt")

func test_nach_dem_verdichten_ist_das_podest_leer() -> void:
	var blank := _blank()
	view.slot_pack(_valued_pack(0, 3).pack_uid)
	view.set_target_pack(blank)
	await wait_frames(2)
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	assert_null(view.target_pack(), "gefüllt ist er kein Rohling mehr")
	assert_false(view.compressing())
	assert_true(blank.is_compressed(), "sondern eine verdichtete Karte")

## ERGEBNIS zeigt beim Verdichten die KARTE, die herauskaeme - nicht die
## Praege-Summe, denn das ist eine andere Rechnung.
func test_der_summen_schirm_zeigt_die_verdichtete_karte() -> void:
	var blank := _blank()
	var mult := run.grant_pack(Pack.number_pack())
	mult.stamp_net = StampNet.empty_net()
	mult.stamp_net[0] = StampNet.factor_cell(4)
	view.slot_pack(mult.pack_uid)
	view.slot_pack(_valued_pack(0, 5).pack_uid)
	view.set_target_pack(blank)
	await wait_frames(2)
	var source := view._result_view_source()
	assert_eq(String(source["mode"]), "card", "als KARTE, nicht als Summe")
	var cell: Dictionary = StampNet.cell_at(source["net"], 0)
	assert_eq(StampNet.compound_glyph(cell), "4x+5", "und zwar als die, die herauskäme")

## Die KARTE entscheidet, was der Tipp tut: eine Netz-Karte steckt, ein ROHLING legt
## sich aufs Podest. Als Futter traege er ohnehin nichts bei.
func test_ein_tipp_auf_einen_rohling_legt_ihn_aufs_podest() -> void:
	var blank := _blank()
	var card := _valued_pack(0, 3)
	view._on_pack_pressed(card.pack_uid)
	view._on_pack_pressed(blank.pack_uid)
	await wait_frames(2)
	assert_eq(view.press_slot_uids(), [card.pack_uid] as Array[int],
		"die Netz-Karte steckt in der Reihe")
	assert_eq(view.target_pack(), blank, "der Rohling liegt auf dem Podest")
	assert_true(view.compressing())

## Eine VERDICHTETE Karte ist kein Rohling mehr - sie steckt wieder in die Reihe
## (praegen darf sie; Futter einer zweiten Verdichtung ist sie nicht, siehe
## test_compression).
func test_ein_tipp_auf_eine_verdichtete_karte_steckt_sie() -> void:
	var blank := _blank()
	blank.stamp_net[0] = StampNet.compound_cell(4, 9)
	view._on_pack_pressed(blank.pack_uid)
	await wait_frames(2)
	assert_eq(view.press_slot_uids(), [blank.pack_uid] as Array[int],
		"gefüllt ist sie Futter wie jede andere")
	assert_null(view.target_pack())

## EIN DING WIRD NIE ZWEIMAL GEZEIGT: liegt der Rohling auf dem Podest, hat er im
## Magazin KEINEN Koerper - sein Platz bleibt stehen, wie der Pool-Sitz des
## Zielwuerfels. (Bug 2026-10-26: er stand doppelt da.)
func test_der_rohling_auf_dem_podest_hat_im_magazin_keinen_koerper() -> void:
	var blank := _blank()
	await wait_frames(2)
	var before := _entry_of(blank.pack_uid)
	assert_false(before.is_empty(), "er liegt im Magazin")
	assert_false(bool(before["withheld"]), "und wird dort gezeigt")
	view.set_target_pack(blank)
	await wait_frames(2)
	var during := _entry_of(blank.pack_uid)
	assert_false(during.is_empty(), "sein PLATZ bleibt stehen")
	assert_true(bool(during["withheld"]), "aber sein Körper liegt in der Kammer")

## Und nach dem Verdichten kommt er zurueck ins Fach - sonst waere die fertige Karte
## nirgends zu finden.
func test_nach_dem_verdichten_steht_die_karte_wieder_im_fach() -> void:
	var blank := _blank()
	view.slot_pack(_valued_pack(0, 3).pack_uid)
	view.set_target_pack(blank)
	await wait_frames(2)
	view.pull_lever()
	view.skip_ceremony()
	await wait_frames(2)
	var entry := _entry_of(blank.pack_uid)
	assert_false(entry.is_empty(), "die verdichtete Karte liegt im Magazin")
	assert_false(bool(entry["withheld"]), "und wird dort auch gezeigt")
	assert_eq(int(entry["column"]), Pack.SHELF_ORDER.find(Pack.SHELF_SPECIAL),
		"im Sonderbestand, wie der Rohling vorher")

## Sein PLATZ ist die Mitte der PODEST-PLATTE - dort, wo sonst der Würfel schwebt. Es
## gibt nur EINEN Platz: liegt er dort, wartet ein gewählter Würfel in seinem Pool-Sitz.
func test_der_rohling_liegt_auf_dem_podest() -> void:
	var blank := _blank()
	view.set_target_pack(blank)
	await wait_frames(2)
	assert_eq(view.blank_seat_center(), view.podium_plate_px().get_center(),
		"die Mitte der Platte")
	assert_eq(view.seated_blank(), blank, "er liegt sofort dort")
	view.choose_index(0)
	view.slot_pack(_valued_pack(0, 2).pack_uid)
	await wait_frames(2)
	assert_eq(view.seated_blank(), blank, "ein gewählter Würfel verdrängt ihn nicht")
	assert_null(view.target_die(), "und ist kein Ziel")
	assert_eq(view.chosen_die(), run.owned_pool[0], "gewählt bleibt er")
	assert_null(view.seated_die(), "aber sein Körper steht nicht auf dem Podest")
	view.clear_blank()
	assert_eq(view.seated_die(), run.owned_pool[0], "zurückgelegt: jetzt steht er dort")

## Waehrend der Zeremonie LIEGT er weiter dort - die Funken schlagen in IHN, und im
## Magazin steht er darum auch nicht schon wieder.
func test_der_rohling_liegt_auch_waehrend_der_zeremonie() -> void:
	var blank := _blank()
	view.slot_pack(_valued_pack(0, 3).pack_uid)
	view.set_target_pack(blank)
	await wait_frames(2)
	assert_eq(view.seated_blank(), blank, "er liegt in der Kammer")
	view.pull_lever()
	await wait_frames(2)
	assert_true(view.burning(), "die Zeremonie laeuft")
	assert_eq(view.seated_blank(), blank, "und er liegt noch dort")
	assert_true(bool(_entry_of(blank.pack_uid)["withheld"]),
		"im Magazin steht er derweil nicht")
	view.skip_ceremony()
	await wait_frames(2)
	assert_null(view.seated_blank(), "danach ist der Platz frei")

## Der Eintrag einer Karte im Magazin ({} = sie liegt nicht dort).
func _entry_of(uid: int) -> Dictionary:
	for entry in view.drawer_entries():
		if int(entry.get("uid", 0)) == uid:
			return entry
	return {}


# --- Der PLATZ einer weit hinausgerollten Karte -----------------------------------
## Bug 2026-10-26 (20 Karten je Sorte, ans Ende gerollt): ein Platz darf LEGITIM
## negativ sein - weit nach links gerollt liegt er unter dem Filz. Der alte
## Gueltigkeits-Test "x >= 0" verwarf ihn und parkte die Karte auf der nackten
## GRUBENMITTE, mitten im Bild. Gemessen brach die Reihe ab Spalte -13 ab.
func test_eine_weit_hinausgerollte_karte_landet_nie_auf_der_grubenmitte() -> void:
	var uids: Array[int] = []
	for i in 40:
		uids.append(run.grant_pack(Pack.fixed_engraving_pack(Engraving.doping())).pack_uid)
	var tray := Pack.SHELF_ORDER.find(Pack.SHELF_SPECIAL)
	view.set_shelf_scroll(tray, PackDrawerView.max_scroll(run.pack_tray_count(tray)))
	await wait_frames(2)
	var mitte := view.shelf_rect_global().get_center()
	# Die kritischen sind die weit LINKS des Fachs: genau die verwarf der alte
	# Gueltigkeits-Test als ungueltig.
	var negativ := 0
	for uid in uids:
		var seat := view.pack_seat_px(uid)
		if seat.y < view.shelf_rect_global().position.y:
			negativ += 1
		assert_gt(seat.distance_to(mitte), 1.0,
			"uid %d (Spalte %d) liegt auf der Grubenmitte"
				% [uid, view.shelf_window_place_of(uid)])
	assert_gt(negativ, 0, "es gibt wirklich Karten über der Anzeige")

## Und die Plaetze bleiben eine GERADE: je Querplatz eine Reihe weiter, gleicher Abstand.
func test_die_plaetze_der_hinausgerollten_karten_bleiben_linear() -> void:
	var uids: Array[int] = []
	for i in 40:
		uids.append(run.grant_pack(Pack.fixed_engraving_pack(Engraving.doping())).pack_uid)
	var tray := Pack.SHELF_ORDER.find(Pack.SHELF_SPECIAL)
	view.set_shelf_scroll(tray, PackDrawerView.max_scroll(run.pack_tray_count(tray)))
	await wait_frames(2)
	var by_column: Dictionary = {}
	for uid in uids:
		by_column[view.shelf_window_place_of(uid)] = view.pack_seat_px(uid)
	var columns: Array = by_column.keys()
	columns.sort()
	assert_gt(columns.size(), 3, "genug Spalten für eine Gerade")
	var across := PackDrawerView.ACROSS
	var step: Vector2 = by_column[columns[across]] - by_column[columns[0]]
	for place: int in columns:
		if not by_column.has(place - across):
			continue
		var delta: Vector2 = by_column[place] - by_column[place - across]
		assert_almost_eq(delta.y, step.y, 0.5, "Platz %d" % place)
		assert_almost_eq(delta.x, 0.0, 0.5, "Platz %d bleibt auf seinem Querplatz" % place)

# --- Jede Reihe rollt FÜR SICH ------------------------------------------------------
## Der Roll-Stand ist je Sorte gebucht: eine Reihe zu rollen läßt die anderen stehen,
## und der Laufwechsel setzt alle auf 0.
func test_jede_reihe_rollt_fuer_sich() -> void:
	for i in 10:
		run.grant_pack(Pack.fixed_engraving_pack(Engraving.doping()))
	for i in 6:
		run.grant_pack(Pack.by_type(Pack.TYPE_DICE_MOD))
	var sonder := Pack.SHELF_ORDER.find(Pack.SHELF_SPECIAL)
	var runen := Pack.SHELF_ORDER.find(Engraving.CATEGORY_DICE)
	view.set_shelf_scroll(sonder, 2)
	view.set_shelf_scroll(runen, 1)
	await wait_frames(2)
	assert_eq(view.shelf_scroll_of(sonder), 2)
	assert_eq(view.shelf_scroll_of(runen), 1, "die andere Reihe behält ihren eigenen Stand")
	assert_eq(view.shelf_scroll_of(0), 0, "eine leere Reihe rastet am Anfang")
	view.set_shelf_scroll(runen, 99)
	assert_eq(view.shelf_scroll_of(runen), PackDrawerView.rows_for(6) - view.shelf_places(),
		"gerastet wird höchstens bis die letzte Reihe am unteren Rand steht")
	assert_eq(view.shelf_overflow(sonder), Vector2i(1, 1), "beide Seiten tragen noch Karten")
	assert_eq(view.shelf_overflow(runen), Vector2i(1, 0))
	view.reset_shelf_scroll()
	assert_eq(view.shelf_scroll_of(sonder), 0)
	assert_eq(view.shelf_scroll_of(runen), 0)

## Ein Zug über eine Reihe bucht beim Loslassen NUR ihren Stand und meldet ihre Reihe.
func test_das_loslassen_bucht_nur_die_gezogene_reihe() -> void:
	for i in 12:
		run.grant_pack(Pack.by_type(Pack.TYPE_DICE_MOD))
	for i in 6:
		run.grant_pack(Pack.fixed_engraving_pack(Engraving.doping()))
	var runen := Pack.SHELF_ORDER.find(Engraving.CATEGORY_DICE)
	var sonder := Pack.SHELF_ORDER.find(Pack.SHELF_SPECIAL)
	await wait_frames(2)
	var snapped: Array[int] = []
	view.shelf_scroll_snapped.connect(func(column: int, _f: float, _t: float) -> void:
		snapped.append(column))
	view._on_scroll_released(runen, -view.shelf_slot_px() * 2.0)
	assert_eq(view.shelf_scroll_of(runen), 2, "zwei Reihen weiter, sofort gebucht")
	assert_eq(view.shelf_scroll_of(sonder), 0, "die Nachbarreihe steht")
	assert_eq(snapped, [runen] as Array[int])

## Eine Lieferung auf einen hinausgerollten Platz landet am RAND ihrer Reihe - die
## Reihe rollt nicht von selbst.
func test_eine_lieferung_landet_an_ihrer_reihe() -> void:
	for i in 6:
		run.grant_pack(Pack.by_type(Pack.TYPE_DICE_MOD))
	var runen := Pack.SHELF_ORDER.find(Engraving.CATEGORY_DICE)
	await wait_frames(2)
	var pit := view.shelf_pit_rect()
	var lane := view.shelf_column_rect(runen)
	var anchor := view.arrival_anchor_px(Pack.by_type(Pack.TYPE_DICE_MOD))
	assert_almost_eq(anchor.y, pit.end.y, 0.5, "unten hinaus: der untere Rand")
	assert_true(anchor.x > lane.position.x and anchor.x < lane.end.x,
		"in der Runen-Spalte")
	assert_eq(view.shelf_scroll_of(runen), 0, "und sie rollt nicht von selbst")
	var number := view.arrival_anchor_px(Pack.number_pack())
	var first := view.shelf_column_rect(0)
	assert_true(first.has_point(number), "eine Zahl landet im Fenster der Zahlen-Spalte")
