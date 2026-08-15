extends GutTest
## Tests der Runden-Chronik (RoundLog): das Zerlegen eines Breakdowns in die
## lineare Schrittliste des Rückblicks, die Cursor-Mathematik über
## Eintragsgrenzen hinweg und die Kopier-Disziplin beim Aufzeichnen - eine
## Referenz statt einer Kopie zeigte später den GEWACHSENEN Würfel.

func _d(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _ids(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _kinds(steps: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for step in steps:
		out.append(String(step["kind"]))
	return out

## Ein Breakdown von Hand: ein Würfel mit zwei Zündungen (die zweite auf
## gewachsenem Wert), einem Krit, einem Glied und einem statischen Charm.
func _hand_built() -> Dictionary:
	return {
		"key": DiceScoring.ONE_KIND,
		"participating": _d([0]),
		"eye_slots": _d([0]),
		"combo": {"base_add": 10, "mult_add": 2},
		"die_steps": [{
			"slot": 3,
			"die_triggers": [{
				"firings": [
					{
						"value": 4, "base_add": 4, "mult_add": 0,
						"base_after": 14, "mult_after": 2.0,
						"charm_base_add": 0, "charm_mult_add": 0,
						"die_charm_indices": [],
						"charm_base_after": 14, "charm_mult_after": 2.0,
						"crit_steps": [], "crit_charm_indices": [], "crit_x": 1.0,
						"crit_from_die": false,
						"base_after_crit": 14, "mult_after_crit": 2.0,
						"value_after": 5,
					},
					{
						"value": 5, "base_add": 5, "mult_add": 3,
						"base_after": 19, "mult_after": 5.0,
						"charm_base_add": 2, "charm_mult_add": 0,
						"die_charm_indices": [0],
						"charm_base_after": 21, "charm_mult_after": 5.0,
						"crit_steps": [{
							"crit_x": 1.5, "charm_indices": [], "from_die": true,
							"base_after": 21, "mult_after": 7.5,
						}],
						"crit_charm_indices": [], "crit_x": 1.5,
						"crit_from_die": true,
						"base_after_crit": 21, "mult_after_crit": 7.5,
						"value_after": 6,
					},
				],
				"links": [{
					"face": 2, "material": "",
					"base_add": 3, "mult_add": 0,
					"base_after": 24, "mult_after": 7.5,
					"charm_base_add": 0, "charm_mult_add": 0,
					"die_charm_indices": [],
					"charm_base_after": 24, "charm_mult_after": 7.5,
					"crit_steps": [], "crit_charm_indices": [], "crit_x": 1.0,
					"crit_from_die": false,
					"base_after_crit": 24, "mult_after_crit": 7.5,
				}],
			}],
			"det_links": [{
				"face": 5, "material": "",
				"base_add": 1, "mult_add": 0,
				"base_after": 25, "mult_after": 7.5,
				"charm_base_add": 0, "charm_mult_add": 0,
				"die_charm_indices": [],
				"charm_base_after": 25, "charm_mult_after": 7.5,
				"crit_steps": [], "crit_charm_indices": [], "crit_x": 1.0,
				"crit_from_die": false,
				"base_after_crit": 25, "mult_after_crit": 7.5,
			}],
		}],
		"charm_steps": [{
			"charm_indices": [0],
			"base_add": 5, "mult_add": 0, "base_x": 1, "mult_x": 1.0, "crit_x": 1.0,
			"base_after": 30, "mult_after": 7.5, "spotlight": false,
		}],
		"base": 30, "mult": 7.5, "merge_total": 225,
		"post_steps": [{
			"charm_indices": [0], "total_add": 0, "total_x": 2.0, "total_after": 450,
		}],
		"total": 450, "triggers": 4, "crits": 1,
	}

func test_flatten_gibt_jeden_ausloeser_als_eigenen_schritt() -> void:
	var steps := RoundLog.flatten(_hand_built())
	assert_eq(_kinds(steps), _ids([
		RoundLog.STEP_COMBO,
		RoundLog.STEP_FIRING,
		RoundLog.STEP_FIRING, RoundLog.STEP_CRIT,
		RoundLog.STEP_LINK,
		RoundLog.STEP_DET_LINK,
		RoundLog.STEP_CHARM,
		RoundLog.STEP_MERGE,
		RoundLog.STEP_POST,
		RoundLog.STEP_RESULT,
	]), "Reihenfolge folgt der Zähl-Zeremonie, jeder Krit steht für sich")

func test_flatten_reicht_die_zwischenstaende_durch() -> void:
	var steps := RoundLog.flatten(_hand_built())
	assert_eq(int(steps[0]["base_after"]), 10, "Kombination setzt die Basis")
	assert_eq(float(steps[0]["mult_after"]), 2.0, "Kombination setzt den Mult")
	assert_eq(int(steps[2]["base_after"]), 21, "Zündung zählt den Charm-Anteil mit")
	assert_eq(float(steps[3]["mult_after"]), 7.5, "der Krit trägt seinen eigenen Stand")
	assert_eq(int(steps[6]["base_after"]), 30, "statischer Charm steht am Ende der Basis")

func test_flatten_haengt_den_gesamtstand_nur_an_die_letzten_schritte() -> void:
	var steps := RoundLog.flatten(_hand_built())
	assert_eq(int(steps[1]["total_after"]), RoundLog.NO_TOTAL, "eine Zündung rührt die Summe nicht an")
	assert_eq(int(steps[7]["total_after"]), 225, "Verschmelzen zeigt die Summe")
	assert_eq(int(steps[8]["total_after"]), 450, "der Nach-Schritt hebt sie")
	assert_eq(int(steps[9]["total_after"]), 450, "das Ergebnis ist der gebuchte Stand")

## Knochen/Glas: die Ziffer auf dem Würfel wandert mit und BLEIBT stehen.
func test_flatten_schreibt_den_laufenden_wert_fort() -> void:
	var steps := RoundLog.flatten(_hand_built())
	assert_eq(steps[0]["overrides"], {}, "vor der ersten Zündung steht keine Überschreibung")
	assert_eq(int(steps[1]["overrides"][3]), 5, "die erste Zündung lässt den Würfel wachsen")
	assert_eq(int(steps[2]["overrides"][3]), 6, "die zweite zählt den gewachsenen Wert")
	assert_eq(int(steps[9]["overrides"][3]), 6, "der Wert steht bis zum Ergebnis")

func test_flatten_merkt_sich_slot_und_seite_der_glieder() -> void:
	var steps := RoundLog.flatten(_hand_built())
	assert_eq(int(steps[1]["flash_slot"]), 3, "die Zündung blitzt an ihrem Slot")
	var net: Dictionary = steps[4]["net"]
	assert_eq(int(net["face"]), 2, "das Glied nennt seine Seite fürs Netz-Feld")
	assert_eq(int(net["slot"]), 3, "und seinen Würfel")
	assert_eq(steps[1]["net"], {}, "eine Zündung zeigt kein Glied-Netz")

func test_flatten_benennt_charms_statt_indizes() -> void:
	var steps := RoundLog.flatten(_hand_built(), _ids([Charm.RABBITS_FOOT]))
	assert_string_contains(String(steps[6]["label"]), RoundLog.charm_name(Charm.RABBITS_FOOT))

func test_flatten_faechert_pro_wuerfel_charms_in_pulse_auf() -> void:
	var breakdown := _hand_built()
	breakdown["charm_steps"][0]["pulses"] = [
		{"slot": 1, "base": 0, "mult": 2, "base_after": 25, "mult_after": 9.5},
		{"slot": 4, "base": 0, "mult": 3, "base_after": 25, "mult_after": 12.5},
	]
	var steps := RoundLog.flatten(breakdown)
	var pulse_steps: Array[Dictionary] = []
	for step in steps:
		if String(step["kind"]) == RoundLog.STEP_CHARM_PULSE:
			pulse_steps.append(step)
	assert_eq(pulse_steps.size(), 2, "je Puls ein Schritt")
	assert_eq(int(pulse_steps[1]["flash_slot"]), 4, "der Puls blitzt an seinem Würfel")

func test_flatten_zaehlt_jede_krit_kopie_einzeln() -> void:
	var breakdown := _hand_built()
	var firing: Dictionary = breakdown["die_steps"][0]["die_triggers"][0]["firings"][1]
	firing["crit_steps"] = [
		{"crit_x": 1.4, "charm_indices": [0], "from_die": false,
			"base_after": 21, "mult_after": 7.0},
		{"crit_x": 1.4, "charm_indices": [0], "from_die": false,
			"base_after": 21, "mult_after": 9.8},
	]
	var crits: Array[Dictionary] = []
	for step in RoundLog.flatten(breakdown):
		if String(step["kind"]) == RoundLog.STEP_CRIT:
			crits.append(step)
	assert_eq(crits.size(), 2, "zwei Kopien schlagen zweimal ein")
	assert_eq(float(crits[1]["mult_after"]), 9.8, "der zweite Schlag baut auf dem ersten auf")

func test_flatten_formatiert_bruchzahlen_nach_der_einen_regel() -> void:
	var steps := RoundLog.flatten(_hand_built())
	assert_string_contains(String(steps[3]["label"]), "×1.5")
	assert_false(String(steps[3]["label"]).contains("1.50"), "keine nachlaufenden Nullen")

func test_flatten_vertraegt_einen_leeren_breakdown() -> void:
	assert_eq(RoundLog.flatten({}).size(), 0)

## Die echte Zerlegung: die Schrittliste endet auf den Zahlen des Breakdowns.
func test_flatten_passt_zur_echten_zerlegung() -> void:
	var dice := _d([5, 5, 5, 2, 3, 4])
	var breakdown := ScoreBreakdown.build(DiceScoring.THREE_KIND, dice)
	var steps := RoundLog.flatten(breakdown)
	assert_gt(steps.size(), 3, "Kombination, Würfel und Ergebnis stehen in der Liste")
	var last: Dictionary = steps[steps.size() - 1]
	assert_eq(String(last["kind"]), RoundLog.STEP_RESULT)
	assert_eq(int(last["total_after"]), int(breakdown["total"]), "das Ergebnis ist die echte Wertung")

func test_flatten_bildet_jede_zuendung_der_echten_zerlegung_ab() -> void:
	var dice := _d([6, 6, 6, 1, 2, 3])
	var breakdown := ScoreBreakdown.build(DiceScoring.THREE_KIND, dice)
	var firings := 0
	for die_step: Dictionary in breakdown["die_steps"]:
		for group: Dictionary in die_step["die_triggers"]:
			firings += group["firings"].size()
	var steps := RoundLog.flatten(breakdown)
	var firing_steps := 0
	for step in steps:
		if String(step["kind"]) == RoundLog.STEP_FIRING:
			firing_steps += 1
	assert_eq(firing_steps, firings, "je Zündung der Rechnung ein Schritt im Rückblick")

## --- Cursor ---

func _log_with(counts: Array) -> RoundLog:
	var log_data := RoundLog.new()
	for c: int in counts:
		var steps: Array[Dictionary] = []
		for i in c:
			steps.append({"kind": RoundLog.STEP_FIRING, "label": "S%d" % i})
		log_data.add_entry({"kind": RoundLog.ENTRY_TAKE, "steps": steps})
	return log_data

func test_step_count_zaehlt_die_pose_mit() -> void:
	var log_data := _log_with([3])
	assert_eq(log_data.step_count(0), 4, "Pose plus drei Schritte")
	var throw_log := RoundLog.new()
	throw_log.add_entry({"kind": RoundLog.ENTRY_THROW})
	assert_eq(throw_log.step_count(0), 1, "ein Wurf ist genau seine Pose")

func test_advance_laeuft_ueber_eintragsgrenzen() -> void:
	var log_data := _log_with([2, 2])
	assert_eq(log_data.advance(Vector2i(0, 2), 1), Vector2i(1, 0), "vorwärts in den nächsten Eintrag")
	assert_eq(log_data.advance(Vector2i(1, 0), -1), Vector2i(0, 2), "rückwärts in den letzten Schritt davor")

func test_advance_klemmt_an_beiden_enden() -> void:
	var log_data := _log_with([2, 2])
	assert_eq(log_data.advance(Vector2i(0, 0), -1), Vector2i(0, 0), "vor dem Anfang ist nichts")
	assert_eq(log_data.advance(Vector2i(1, 2), 1), Vector2i(1, 2), "nach dem Ende auch nicht")

func test_total_steps_summiert_alle_eintraege() -> void:
	assert_eq(_log_with([2, 3]).total_steps(), 7, "je Eintrag Pose plus Schritte")

func test_advance_vertraegt_ein_leeres_log() -> void:
	assert_eq(RoundLog.new().advance(Vector2i(0, 0), 1), Vector2i(0, 0))

## --- Aufzeichnung ---

func test_pit_slot_record_kopiert_die_def() -> void:
	var def := DieDefinition.standard()
	var record := RoundLog.pit_slot_record(def, 2, 3, true, false)
	var copy: DieDefinition = record["def"]
	assert_ne(copy, def, "die Chronik hält eine eigene Instanz")
	def.faces[0] = 9
	assert_ne(copy.faces[0], 9, "ein späteres Wachstum färbt nicht in die Vergangenheit ab")
	assert_eq(int(record["face_index"]), 2, "die SEITE ist die Wahrheit, nicht der Wert")

func test_copy_defs_kopiert_jeden_wuerfel() -> void:
	var defs: Array[DieDefinition] = [DieDefinition.standard(), DieDefinition.standard()]
	var copies := RoundLog.copy_defs(defs)
	assert_eq(copies.size(), 2)
	defs[1].faces[3] = 8
	assert_ne(copies[1].faces[3], 8, "die Kopie bleibt stehen")

func test_values_label_nennt_nur_die_liegenden_wuerfel() -> void:
	var pit: Array = [
		RoundLog.pit_slot_record(DieDefinition.standard(), 0, 5, true, false),
		RoundLog.pit_slot_record(DieDefinition.standard(), 0, 2, true, false),
		RoundLog.pit_slot_record(DieDefinition.standard(), 0, 6, false, false),
	]
	assert_eq(RoundLog.values_label(pit), "5 · 2")
