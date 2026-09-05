extends GutTest
## Tier-1-Tests der Zähl-Animation-Zerlegung (ScoreBreakdown): Die Schrittliste
## muss in JEDEM Szenario exakt die echte Wertung (DiceScoring.score_category)
## ergeben - sonst zeigt die Grubenanimation andere Punkte, als der Spieler
## bekommt. Dazu Struktur-Checks: welche Würfel zählen Augen, welche Charms
## welchen Schritten zugeordnet werden, und dass die Zwischenstände lückenlos
## aufeinander aufbauen.

func _d(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _ids(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _m(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

const NO_MATS: Array[String] = []

## ctx mit einer Argon-Seele auf slot: seit dem Kanten-Umbau die Standard-Quelle
## zweier Auslösungen (früher tat das die Quecksilber-Kante).
func _argon(slot: int) -> Dictionary:
	return {DiceScoring.CTX_ESSENCES: {slot: Essence.ARGON}}

## Baut die Zerlegung und prüft das Herzstück: total == score_category.
func _build_and_check(key: String, dice: Array[int], ids: Array[String] = [], first := false, mats: Array[String] = [], levels: Dictionary = {}, ctx: Dictionary = {}) -> Dictionary:
	var breakdown := ScoreBreakdown.build(key, dice, ids, first, mats, levels, ctx)
	var expected := DiceScoring.score_category(key, dice, ids, first, mats, levels, ctx)
	assert_eq(breakdown["total"], expected, "Schrittliste ergibt die echte Wertung (%s)" % key)
	_check_continuity(breakdown)
	return breakdown

## Die Zwischenstände müssen lückenlos aufeinander aufbauen: jede Auslösung
## (Würfel-Puls -> Charm-Anteil -> Krit) startet beim Nachher-Wert der vorigen,
## die Schritte folgen der Reihen-Ordnung, und der letzte Stand ist base/mult.
## Alle Pulse eines Würfel-Schritts in Spielreihenfolge: je Würfel-Trigger seine
## Zündungen und die gezündeten Glieder, zuletzt die Essenz-Glieder.
func _pulses(step: Dictionary) -> Array:
	var out: Array = []
	for group in step["die_triggers"]:
		out.append_array(group["firings"])
		out.append_array(group["links"])
	out.append_array(step.get("det_links", []))
	return out

## Nur die Seiten-Zündungen eines Würfel-Schritts (ohne Glieder).
func _firings(step: Dictionary) -> Array:
	var out: Array = []
	for group in step["die_triggers"]:
		out.append_array(group["firings"])
	return out

func _check_continuity(breakdown: Dictionary) -> void:
	var base: int = breakdown["combo"]["base_add"]
	# Mult ist eine Fließkommazahl, seit Krits Bruchteile sein dürfen (Beherit).
	var mult := float(breakdown["combo"]["mult_add"])
	var expected_order: Array = breakdown["eye_slots"]
	var at := 0
	for step: Dictionary in breakdown["die_steps"]:
		assert_eq(int(step["slot"]), int(expected_order[at]), "Schritte folgen der Reihen-Ordnung")
		at += 1
		for pulse: Dictionary in _pulses(step):
			base += pulse["base_add"]
			mult += float(pulse["mult_add"])
			assert_eq(pulse["base_after"], base, "Zwischenstand nach dem Würfel-Puls")
			assert_almost_eq(float(pulse["mult_after"]), mult, 0.0001)
			base += pulse["charm_base_add"]
			mult += float(pulse["charm_mult_add"])
			assert_eq(pulse["charm_base_after"], base, "Zwischenstand nach dem Charm-Anteil")
			assert_almost_eq(float(pulse["charm_mult_after"]), mult, 0.0001)
			# Jeder Krit schlägt EINZELN ein - die Kette läuft über die Schläge.
			for crit: Dictionary in pulse["crit_steps"]:
				mult *= float(crit["crit_x"])
				assert_eq(crit["base_after"], base, "Zwischenstand nach dem Krit-Schlag")
				assert_almost_eq(float(crit["mult_after"]), mult, 0.0001)
			assert_almost_eq(float(pulse["mult_after_crit"]), mult, 0.0001, "Summe der Krit-Schläge")
		assert_eq(step["base_after"], base, "Würfel-Schritt endet am laufenden Stand")
		assert_almost_eq(float(step["mult_after"]), mult, 0.0001)
	for step: Dictionary in breakdown["charm_steps"]:
		base = (base + int(step["base_add"])) * int(step["base_x"])
		mult = (mult + float(step["mult_add"])) * float(step["mult_x"])
		assert_eq(step["base_after"], base)
		assert_almost_eq(float(step["mult_after"]), mult, 0.0001)
	assert_eq(breakdown["base"], base, "Endstand Basis")
	assert_almost_eq(float(breakdown["mult"]), maxf(1.0, mult), 0.0001, "Endstand Mult (geklemmt)")
	assert_eq(breakdown["merge_total"], ceili(float(base) * maxf(1.0, mult)))
	var total: int = breakdown["merge_total"]
	for step: Dictionary in breakdown["post_steps"]:
		total = int(round((total + step["total_add"]) * step["total_x"]))
		assert_eq(step["total_after"], total)

# --- Grundfälle (charm-/materialfrei) -----------------------------------------

func test_plain_pair_matches_scoring():
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]))
	assert_eq(breakdown["combo"]["base_add"], 10, "feste Paar-Punkte")
	assert_eq(breakdown["combo"]["mult_add"], 2)
	assert_eq(breakdown["die_steps"].size(), 2, "nur die Paar-Würfel zählen Augen")
	assert_eq(breakdown["charm_steps"].size(), 0)
	assert_eq(breakdown["post_steps"].size(), 0)

func test_sum_category_counts_only_participating_dice():
	# Full House zählt nur die beteiligten Würfel; der unbeteiligte sechste
	# (die 1) bleibt außen vor. Reihen-Ordnung: der DREIER-Block vor dem Paar -
	# die Größe entscheidet vor der Ziffer.
	var breakdown := _build_and_check(DiceScoring.FULL_HOUSE, _d([2, 2, 2, 4, 4, 1]))
	assert_eq(breakdown["eye_slots"], [0, 1, 2, 3, 4])
	assert_eq(breakdown["die_steps"].size(), 5)

func test_composite_hands_count_in_row_order():
	# Gezählt wird kombinations-erst: der Dreier-Block steht vorn, auch wenn er
	# rechts liegt und die kleinere Ziffer trägt - Blöcke bleiben beisammen.
	var breakdown := _build_and_check(DiceScoring.FULL_HOUSE, _d([4, 4, 2, 2, 2, 1]))
	assert_eq(breakdown["eye_slots"], [2, 3, 4, 0, 1])

func test_dice_count_in_row_order_high_to_low():
	# Die Zählreihenfolge ist die aufgereihte Reihe: Wert absteigend, bei
	# Gleichstand kleinster Slot - kanonisch aus den Werten (DiceScoring.
	# trigger_order), weil sie wertungsrelevant ist, sobald Beherit kritet.
	var breakdown := _build_and_check(DiceScoring.LARGE_STRAIGHT, _d([1, 2, 3, 4, 5, 6]))
	assert_eq(breakdown["eye_slots"], [5, 4, 3, 2, 1, 0], "höchster Würfel zuerst")
	var slots: Array[int] = []
	for step: Dictionary in breakdown["die_steps"]:
		slots.append(int(step["slot"]))
	assert_eq(slots, breakdown["eye_slots"], "die Schritte folgen der Reihe")

func test_every_category_example_matches():
	# Jedes Anzeige-Beispiel der Bildschirmliste läuft einmal durch die Zerlegung.
	for key: String in DiceScoring.HAND_PRIORITY:
		_build_and_check(key, _d(DiceScoring.EXAMPLE_DICE[key]))

func test_combo_levels_flow_into_combo_step():
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), _ids([]), false, NO_MATS, {DiceScoring.TWO_KIND: 1})
	assert_eq(breakdown["combo"]["base_add"], 20, "Übertaktungs-Stufe verdoppelt die festen Punkte")
	assert_eq(breakdown["combo"]["mult_add"], 4)

# --- Material-Schritte ----------------------------------------------------------

func test_material_bonuses_split_per_die():
	# Rubin auf Slot 0, Bernstein auf Slot 1: jeder Bonus landet an SEINEM Würfel,
	# die Summe entspricht der echten Wertung.
	var mats := _m([DieMaterial.RUBY, DieMaterial.AMBER, "", "", "", ""])
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), _ids([]), false, mats)
	var steps: Array = breakdown["die_steps"]
	assert_eq(steps[0]["mat_mult_add"], 4, "Rubin: +4 Mult am ersten Würfel")
	assert_eq(steps[0]["mat_base_add"], 0)
	assert_eq(steps[1]["mat_base_add"], 20, "Bernstein: +20 Basis am zweiten Würfel")
	assert_eq(steps[1]["mat_mult_add"], 0)

func test_mercury_edge_retrigger_stays_at_its_die():
	# Quecksilber-Kante: der Würfel spielt zwei Auslösungen, jede zählt Augen
	# und Rubin erneut - als eigene Kettenglieder, nicht als Aggregat.
	var mats := _m([DieMaterial.RUBY, "", "", "", "", ""])
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), _ids([]), false, mats, {}, _argon(0))
	var acts: Array = _firings(breakdown["die_steps"][0])
	assert_eq(acts.size(), 2)
	for pulse: Dictionary in acts:
		assert_eq(int(pulse["base_add"]), 5, "Augen je Auslösung")
		assert_eq(int(pulse["mult_add"]), 4, "Rubin je Auslösung")
	assert_eq(_firings(breakdown["die_steps"][1]).size(), 1, "der Partner löst einfach aus")

func test_the_xray_link_rides_every_die_trigger():
	# Röntgenlicht: das Glied hängt in JEDER Trigger-Gruppe, nicht in den
	# det_links am Ende - und die Schrittliste muss die Wertung treffen.
	var ctx := _argon(0)
	ctx[DiceScoring.CTX_ESSENCE_LINKS] = {0: [{"face": 5, "value": 6, "material": "", "level": 0}]}
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]),
		_ids([]), false, NO_MATS, {}, ctx)
	var step: Dictionary = breakdown["die_steps"][0]
	assert_eq(step["det_links"].size(), 0, "am Ende steht nur noch die Kehrseite-Rune")
	for group: Dictionary in step["die_triggers"]:
		assert_eq(group["links"].size(), 1, "je Antritt eine Belichtung")

func test_high_stacker_fires_with_its_die_per_activation():
	# Würfelgebunden: der Hochstapler feuert MIT dem höchsten gewerteten Würfel,
	# je Aktivierung +5 Mult als Charm-Anteil der jeweiligen Auslösung.
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), _ids([Charm.HIGH_STACKER]), false, NO_MATS, {}, _argon(0))
	var step: Dictionary = breakdown["die_steps"][0]
	assert_eq(step["die_charm_indices"], [0], "der Hochstapler hängt am Zielwürfel")
	for pulse: Dictionary in _firings(step):
		assert_eq(int(pulse["charm_mult_add"]), 5, "+5 Mult je Auslösung")
	assert_eq(breakdown["die_steps"][1]["die_charm_indices"], [], "der Partner-Würfel bleibt leer")
	assert_eq(breakdown["charm_steps"].size(), 0, "kein Charm-Phase-Schritt mehr")

## Der Würfel-Schritt eines Slots - die Schritte stehen in Reihen-Ordnung, nicht
## in Slot-Ordnung.
func _step_for_slot(breakdown: Dictionary, slot: int) -> Dictionary:
	for step: Dictionary in breakdown["die_steps"]:
		if int(step["slot"]) == slot:
			return step
	return {}

func test_quadrature_fires_inside_the_lowest_die_step():
	# Full House aus fünf gewerteten Würfeln: die niedrigste 2 auf Slot 0 legt
	# 2² = 4 Basispunkte in ihren EIGENEN Schritt.
	var breakdown := _build_and_check(DiceScoring.FULL_HOUSE, _d([2, 2, 2, 5, 5, 1]), _ids([Charm.QUADRATURE]))
	var step := _step_for_slot(breakdown, 0)
	assert_eq(step["die_charm_indices"], [0], "die Quadratur hängt am niedrigsten Würfel")
	assert_eq(int(step["charm_base_add"]), 4, "2² = 4 Basispunkte")
	assert_eq(_step_for_slot(breakdown, 3)["die_charm_indices"], [], "die Fünfer bleiben leer")
	assert_eq(breakdown["charm_steps"].size(), 0, "kein Charm-Phase-Schritt")

func test_quadrature_stays_out_of_a_narrow_hand():
	var breakdown := _build_and_check(DiceScoring.THREE_KIND, _d([2, 2, 2, 5, 4, 1]), _ids([Charm.QUADRATURE]))
	for step: Dictionary in breakdown["die_steps"]:
		assert_eq(step["die_charm_indices"], [], "drei gewertete Würfel lösen sie nicht aus")

func test_six_pack_retriggers_every_die_of_a_full_hand():
	# Große Straße = alle sechs Würfel: JEDER Schritt zündet zweimal.
	var breakdown := _build_and_check(DiceScoring.LARGE_STRAIGHT, _d([1, 2, 3, 4, 5, 6]), _ids([Charm.SIX_PACK]))
	assert_eq(breakdown["die_steps"].size(), 6)
	for step: Dictionary in breakdown["die_steps"]:
		assert_eq(_firings(step).size(), 2, "Slot %d tritt zweimal an" % int(step["slot"]))

func test_six_pack_sleeps_below_a_full_hand():
	var breakdown := _build_and_check(DiceScoring.FULL_HOUSE, _d([2, 2, 2, 5, 5, 1]), _ids([Charm.SIX_PACK]))
	assert_eq(breakdown["die_steps"].size(), 5)
	for step: Dictionary in breakdown["die_steps"]:
		assert_eq(_firings(step).size(), 1, "fünf Würfel reichen nicht")

func test_beherit_crits_once_in_the_charm_phase():
	# Beherit hängt an der HAND: sein Krit steht in charm_steps, nicht im Würfel-
	# Schritt - auch wenn Argon den Zielwürfel zweimal zünden lässt.
	var breakdown := _build_and_check(DiceScoring.THREE_KIND, _d([4, 4, 4, 1, 2, 3]), _ids([Charm.BEHERIT]), false, NO_MATS, {}, _argon(0))
	var step: Dictionary = breakdown["die_steps"][0]
	assert_eq(_firings(step).size(), 2)
	assert_eq(step["crit_charm_indices"], [], "kein Krit mehr in der Würfelphase")
	var charm_steps: Array = breakdown["charm_steps"]
	assert_eq(charm_steps.size(), 1, "genau ein Schlag, egal wie oft der Würfel zündet")
	assert_almost_eq(float(charm_steps[0]["crit_x"]), 5.0, 0.0001, "1 + niedrigste gewertete 4")

func test_two_beherit_copies_are_two_charm_steps():
	# Dieselbe Regel wie eh und je: jede Kopie schlägt für sich, nie einmal mit
	# ihrem Produkt - nur eben in der Charm-Phase.
	var ids := _ids([Charm.BEHERIT, Charm.BEHERIT])
	var breakdown := _build_and_check(DiceScoring.THREE_KIND, _d([4, 4, 4, 1, 2, 3]), ids)
	var charm_steps: Array = breakdown["charm_steps"]
	assert_eq(charm_steps.size(), 2, "je Kopie ein eigener Schritt")
	for step: Dictionary in charm_steps:
		assert_almost_eq(float(step["crit_x"]), 5.0, 0.0001)
	assert_eq(charm_steps[0]["charm_indices"], [0])
	assert_eq(charm_steps[1]["charm_indices"], [1])

func test_beherit_reads_the_settled_value_not_the_grown_one():
	# Knochen wächst ZWISCHEN den Zündungen - Beherit feuert danach und rechnet
	# trotzdem mit der LIEGENDEN 4, nicht mit der gewachsenen Seite.
	var mats := _m([DieMaterial.BONE, "", "", "", "", ""])
	var breakdown := _build_and_check(DiceScoring.THREE_KIND, _d([4, 4, 4, 1, 2, 3]), _ids([Charm.BEHERIT]), false, mats, {}, _argon(0))
	var charm_steps: Array = breakdown["charm_steps"]
	assert_eq(charm_steps.size(), 1)
	assert_almost_eq(float(charm_steps[0]["crit_x"]), 5.0, 0.0001)

func test_every_crit_gets_its_own_slam():
	# Zwei Härteofen-Schläge auf einem veredelten Rubin: ZWEIMAL ×2, nie einmal ×4 -
	# die Zeremonie soll jeden Krit zeigen. Das Produkt bleibt crit_x.
	var ids := _ids([Charm.KILN])
	var mats := _m([DieMaterial.RUBY, "", "", "", "", ""])
	var levels := {DiceScoring.CTX_MATERIAL_LEVELS: {0: {"level": DieMaterial.MAX_LEVEL, "eye_sum": 0}}}
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([4, 4, 1, 2, 3, 5]), ids, false, mats, {}, levels)
	var pulse: Dictionary = _firings(breakdown["die_steps"][0])[0]
	var crits: Array = pulse["crit_steps"]
	assert_eq(crits.size(), 2, "je Schlag ein eigener Eintrag")
	for crit: Dictionary in crits:
		assert_almost_eq(float(crit["crit_x"]), 2.0, 0.0001)
		assert_true(bool(crit["from_die"]), "beide kommen vom Würfel, nicht vom Dock-Pad")
	assert_almost_eq(float(pulse["crit_x"]), 4.0, 0.0001, "crit_x bleibt das Produkt")

func test_the_high_stacker_amount_follows_the_running_value():
	# Dasselbe für einen additiven würfelgebundenen Charm - das ZIEL bleibt am
	# liegenden Wert, nur der Betrag wächst mit.
	var mats := _m([DieMaterial.BONE, "", "", "", "", ""])
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([4, 4, 1, 2, 3, 5]), _ids([Charm.HIGH_STACKER]), false, mats, {}, _argon(0))
	var acts: Array = _firings(breakdown["die_steps"][0])
	assert_eq(int(acts[0]["charm_mult_add"]), 4)
	assert_eq(int(acts[1]["charm_mult_add"]), 6, "die gewachsene Seite legt mehr Mult")

func test_a_material_crit_slams_without_a_dock_pad():
	# Rubin III kommt vom Würfel selbst - sein Schlag nennt keine Charm-Position.
	var mats := _m([DieMaterial.RUBY, "", "", "", "", ""])
	var ctx := {DiceScoring.CTX_MATERIAL_LEVELS: {0: {"level": 3, "eye_sum": 21}}}
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), _ids([]), false, mats, {}, ctx)
	var crits: Array = _firings(breakdown["die_steps"][0])[0]["crit_steps"]
	assert_eq(crits.size(), 1)
	assert_true(bool(crits[0]["from_die"]), "kein Dock-Pad")
	assert_eq(crits[0]["charm_indices"], [])

func test_retrigger_interleaves_the_per_die_charm_share():
	# Verzahnung: je Auslösung folgt der Charm-Anteil direkt auf den
	# Würfel-Puls, und der nächste Puls setzt auf dessen After-Stand auf.
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), _ids([Charm.BROADBAND]), false, NO_MATS, {}, _argon(0))
	var step: Dictionary = breakdown["die_steps"][0]
	var acts: Array = _firings(step)
	assert_eq(acts.size(), 2)
	for pulse: Dictionary in acts:
		assert_eq(int(pulse["charm_base_add"]), 5, "Mehrfachstecker-Anteil je Auslösung")
	assert_eq(int(acts[1]["base_after"]), int(acts[0]["charm_base_after"]) + int(acts[1]["base_add"]),
		"Würfel-Puls 2 startet nach Charm-Anteil 1")
	assert_eq(int(acts[1]["charm_base_after"]), int(step["base_after"]), "Ende der Kette = Schritt-Endstand")

# --- Charm-Schritte --------------------------------------------------------------

func test_retrigger_charm_recounts_at_the_die():
	# Hasenpfote löst die 6 erneut aus - als zweite Auslösung mit eigener
	# Augen-Zählung, nicht als Augenwert-Änderung.
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([6, 6, 1, 2, 3, 5]), _ids([Charm.RABBITS_FOOT]))
	var step: Dictionary = breakdown["die_steps"][0]
	assert_eq(step["eye_add"], 6)
	var acts: Array = _firings(step)
	assert_eq(acts.size(), 2, "zweite Auslösung durch den Retrigger")
	assert_eq(int(acts[1]["base_add"]), 6, "die Nachzählung sind wieder die Augen")
	assert_eq(step["eye_charm_indices"], [], "Augenwert selbst unverändert")
	assert_eq(breakdown["charm_steps"].size(), 0, "kein eigener Charm-Schritt")

func test_transform_charm_lights_up_at_the_die():
	# Glückszigaretten: die 1 zeigt eine 6 - der Würfel-Schritt nennt die
	# Besitz-Position des Verwandlers.
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([1, 1, 2, 3, 4, 4]), _ids([Charm.LUCKY_CIGARETTES]))
	var steps: Array = breakdown["die_steps"]
	assert_eq(steps[0]["eye_add"], 6, "verwandelte 1 zählt als 6")
	assert_eq(steps[0]["eye_charm_indices"], [0])

func test_additive_charm_gets_its_own_step():
	var breakdown := _build_and_check(DiceScoring.FULL_HOUSE, _d([2, 2, 2, 5, 5, 1]), _ids([Charm.HORSESHOE]))
	var steps: Array = breakdown["charm_steps"]
	assert_eq(steps.size(), 1)
	assert_eq(steps[0]["charm_indices"], [0])
	assert_eq(steps[0]["mult_add"], 8, "Hufeisen: Full House +8 Mult")

func test_per_die_charm_fires_inside_the_die_step():
	# Mehrfachstecker feuert MIT jedem beteiligten Würfel, nicht in der Charm-Phase:
	# zwei Kopien -> +10 im Schritt jedes Paar-Würfels, beide Positionen genannt.
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), _ids([Charm.BROADBAND, Charm.BROADBAND]))
	var steps: Array = breakdown["die_steps"]
	assert_eq(steps.size(), 2)
	for step: Dictionary in steps:
		assert_eq(step["charm_base_add"], 10, "beide Mehrfachstecker-Kopien am Würfel selbst")
		assert_eq(step["die_charm_indices"], [0, 1])
	assert_eq(breakdown["charm_steps"].size(), 0, "kein Charm-Phase-Schritt mehr")

func test_nonlinear_charms_still_sum_exactly():
	# Einsiedlerkrebs (+6 nur bei ≤2 Charms) + Sammler-Amulett (je anderem Charm):
	# verschränkte Beiträge - die Teleskopsumme muss trotzdem exakt stimmen.
	_build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), _ids([Charm.HERMIT_CRAB, Charm.COLLECTORS_AMULET]))

func test_cult_of_one_becomes_a_crit_step():
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 1, 3, 6]), _ids([Charm.CULT_OF_ONE]))
	var steps: Array = breakdown["charm_steps"]
	assert_eq(steps.size(), 1)
	assert_eq(steps[0]["crit_x"], 4.0, "×2 je gewürfelter 1 (zwei Einsen)")
	assert_eq(steps[0]["mult_x"], 4.0)
	assert_eq(steps[0]["charm_indices"], [0])

func test_gallows_humor_is_a_positioned_crit_step():
	var ids := _ids([Charm.GALLOWS_HUMOR])
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), ids, false, NO_MATS, {}, {"after_farkle": true})
	var crit_steps: Array = breakdown["charm_steps"].filter(func(s: Dictionary) -> bool: return s["crit_x"] > 1)
	assert_eq(crit_steps.size(), 1)
	assert_eq(crit_steps[0]["mult_x"], 4.0, "Krit ×4 an der eigenen Position")
	assert_eq(crit_steps[0]["crit_x"], 4.0, "als Krit markiert - die UI kann ihn inszenieren")
	assert_eq(crit_steps[0]["charm_indices"], [0])

func test_spotlight_gets_its_own_step_at_its_dock_position():
	# Das Rampenlicht wertet nichts, bekommt aber einen Schritt AN SEINER
	# Position - sonst könnte die Animation es nicht dort auslösen. Vor ihm
	# steht das Hufeisen, dessen Schritt also zuerst kommt.
	var ids := _ids([Charm.LADYBUG, Charm.SPOTLIGHT])
	var ctx := {CharmEffects.CTX_SPOTLIGHT: DiceScoring.TWO_KIND}
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), ids, false, NO_MATS, {}, ctx)
	var steps: Array = breakdown["charm_steps"]
	assert_eq(steps.size(), 2, "Marienkäfer und Rampenlicht")
	assert_false(steps[0]["spotlight"], "der Marienkäfer ist kein Rampenlicht")
	assert_true(steps[1]["spotlight"], "das Rampenlicht steht an Position 1")
	assert_eq(steps[1]["base_add"], 0, "es wertet nicht")
	assert_eq(steps[1]["mult_add"], 0)
	assert_eq(steps[1]["base_after"], steps[0]["base_after"], "und verschiebt keine Zahl")
	assert_eq(steps[1]["mult_after"], steps[0]["mult_after"])

func test_spotlight_stays_silent_on_a_different_combination():
	var ids := _ids([Charm.SPOTLIGHT])
	var ctx := {CharmEffects.CTX_SPOTLIGHT: DiceScoring.LARGE_STRAIGHT}
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), ids, false, NO_MATS, {}, ctx)
	assert_eq(breakdown["charm_steps"].size(), 0, "andere Kombination, kein Schritt")

func test_crit_charm_respects_dock_order():
	# KEINE Ausnahmen: Einserkult VOR Schwungrad kritet dessen +6 nicht,
	# dahinter schon - und die Schrittliste läuft in Besitz-Reihenfolge.
	var ctx := {CharmEffects.CTX_STREAK: 3}
	var dice := _d([5, 5, 1, 2, 3, 6])
	var cult_first := _build_and_check(DiceScoring.TWO_KIND, dice, _ids([Charm.CULT_OF_ONE, Charm.MOMENTUM]), false, NO_MATS, {}, ctx)
	var cult_last := _build_and_check(DiceScoring.TWO_KIND, dice, _ids([Charm.MOMENTUM, Charm.CULT_OF_ONE]), false, NO_MATS, {}, ctx)
	# Eine 1 im Wurf: Krit ×2. Vorn: (2×2 + 6) = 10 Mult, Basis 20 -> 200.
	# Hinten: (2 + 6) × 2 = 16 Mult, Basis 20 -> 320.
	assert_eq(cult_first["total"], 200)
	assert_eq(cult_last["total"], 320)
	assert_eq(cult_first["charm_steps"][0]["charm_indices"], [0], "Schritte folgen der Dock-Reihenfolge")
	assert_eq(cult_first["charm_steps"][1]["charm_indices"], [1])

# --- Nach-Schritte (auf die fertige Punktzahl) ------------------------------------

func test_rainbow_trout_is_a_mult_step():
	var breakdown := _build_and_check(DiceScoring.SMALL_STRAIGHT, _d([1, 2, 3, 4, 5, 5]), _ids([Charm.RAINBOW_TROUT]))
	var steps: Array = breakdown["charm_steps"]
	assert_eq(steps.size(), 1)
	assert_eq(steps[0]["mult_add"], 8)
	assert_eq(steps[0]["charm_indices"], [0])
	assert_true(breakdown["post_steps"].is_empty(), "kein Nach-Schritt mehr")

func test_the_magic_card_shows_as_extra_firings():
	# Die erste Hand der Runde tritt jeden Würfel zweimal an - keine Nach-Schritte.
	var ids := _ids([Charm.MAGIC_CARD])
	var ctx := {DiceScoring.CTX_HANDS_TAKEN: 0}
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), ids, true, NO_MATS, {}, ctx)
	assert_eq(breakdown["die_steps"][0]["die_triggers"].size(), 2, "zwei Antritte je Würfel")
	assert_true(breakdown["post_steps"].is_empty(), "die Zauberkarte ist kein Gesamtzahl-Effekt mehr")
	var later := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), ids, false, NO_MATS, {},
		{DiceScoring.CTX_HANDS_TAKEN: 1})
	assert_eq(later["die_steps"][0]["die_triggers"].size(), 1, "spätere Hände treten einfach an")

func test_the_magic_card_spares_dice_that_only_the_full_counter_scores():
	# Die Grenze der Zauberkarte: sie meint die KOMBINATION, nicht die gewertete
	# Menge. Der Vollzähler zieht die unbeteiligte 6 in die Wertung - einen
	# zweiten Antritt bekommt sie deshalb nicht.
	var ids := _ids([Charm.MAGIC_CARD, Charm.FULL_COUNTER])
	var ctx := {DiceScoring.CTX_HANDS_TAKEN: 0}
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), ids, true, NO_MATS, {}, ctx)
	assert_eq(_step_for_slot(breakdown, 0)["die_triggers"].size(), 2, "der Kombinations-Würfel tritt zweimal an")
	assert_eq(_step_for_slot(breakdown, 5)["die_triggers"].size(), 1,
		"nur mitgewertet - kein zweiter Antritt")

func test_after_work_beer_crits_on_an_empty_pool():
	# Leerer Nachziehstapel: ein reiner Krit-Schritt, die Basis bleibt unberührt.
	var ids := _ids([Charm.AFTER_WORK_BEER])
	var ctx := {CharmEffects.CTX_POOL_EMPTY: true}
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), ids, false, NO_MATS, {}, ctx)
	var steps: Array = breakdown["charm_steps"]
	assert_eq(steps.size(), 1)
	assert_eq(steps[0]["base_x"], 1, "kein Basis-Faktor mehr")
	assert_eq(steps[0]["mult_x"], 5.0, "Krit steckt im Mult-Faktor")
	assert_eq(steps[0]["crit_x"], 5.0, "und bleibt als Krit sichtbar")
	assert_eq(steps[0]["charm_indices"], [0])
	assert_true(breakdown["post_steps"].is_empty(), "kein Nach-Schritt mehr")

func test_after_work_beer_stays_quiet_while_the_pool_has_dice():
	var ids := _ids([Charm.AFTER_WORK_BEER])
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]), ids)
	assert_true(breakdown["charm_steps"].is_empty())

# --- Großer Kombinationstest: alles gleichzeitig -----------------------------------

func test_kitchen_sink_scenario_matches_scoring():
	# Materialien + Augen-Charm + additive Charms + Einserkult + Krit + Totem-
	# aufgelöste ids + Übertaktungs-Stufen + Kontext: die Zerlegung muss exakt bleiben.
	var run := GameRun.new_run()
	run.owned_charms.append(Charm.broadband())
	run.owned_charms.append(Charm.parrot_totem())
	run.owned_charms.append(Charm.cult_of_one())
	run.owned_charms.append(Charm.gallows_humor())
	run.owned_charms.append(Charm.rabbits_foot())
	var dice := _d([6, 6, 6, 1, 2, 5])
	var mats := _m([DieMaterial.RUBY, "", DieMaterial.AMBER, "", "", ""])
	var levels := {DiceScoring.THREE_KIND: 1}
	var ctx := {"after_farkle": true, "streak": 2, DiceScoring.CTX_ESSENCES: {1: Essence.ARGON}}
	_build_and_check(DiceScoring.THREE_KIND, dice, run.charm_ids(), true, mats, levels, ctx)

# --- Pro-Würfel-Meteor -------------------------------------------------------------

func test_sediment_fires_in_the_die_steps():
	# Bodensatz: Paar Fünfer, beide Slots spät gezogen -> +4 Mult IM Schritt
	# jedes beteiligten Würfels, keine Charm-Phase.
	var ctx := {CharmEffects.CTX_LATE_SLOTS: [0, 1]}
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]),
		_ids([Charm.SEDIMENT]), false, NO_MATS, {}, ctx)
	var steps: Array = breakdown["die_steps"]
	assert_eq(steps.size(), 2)
	for step: Dictionary in steps:
		assert_eq(step["charm_mult_add"], 4, "+4 Mult mit dem Würfel selbst")
		assert_eq(step["die_charm_indices"], [0])
	assert_eq(breakdown["charm_steps"].size(), 0)

func test_full_counter_scores_bystanders_as_die_steps():
	# Vollzähler macht ALLE liegenden Würfel zu Würfel-Schritten - auch die
	# Unbeteiligten leuchten und zählen ihre Augen, kein eigener Charm-Schritt.
	var breakdown := _build_and_check(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]),
		_ids([Charm.FULL_COUNTER]))
	assert_eq(breakdown["die_steps"].size(), 6, "alle sechs Würfel als Schritt")
	assert_eq(breakdown["eye_slots"], _d([0, 1, 5, 4, 3, 2]),
		"erst die Kombination, dann die bloß Mitgewerteten")
	assert_eq(breakdown["charm_steps"].size(), 0, "kein eigener Vollzähler-Schritt")
	assert_eq(int(breakdown["die_steps"][5]["eye_add"]), 1, "unbeteiligter Würfel (Auge 1) zählt mit")

func test_bonus_that_is_not_per_die_carries_no_pulses():
	# Marienkäfer gibt +4 Mult aufs Paar - ein Schritt, aber kein Pro-Würfel-Charm.
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, _d([5, 5, 1, 2, 3, 6]),
		_ids([Charm.LADYBUG]), false)
	var steps: int = breakdown["charm_steps"].size()
	assert_gt(steps, 0, "Marienkäfer erzeugt einen Schritt")
	for step: Dictionary in breakdown["charm_steps"]:
		assert_false(step.has("pulses"), "Nicht-pro-Würfel-Schritt trägt keine Pulse")

# --- Systematischer Deckungstest: build == score_category über die Matrix ----------
# ScoreBreakdown und DiceScoring komponieren dieselben ~9 Charm-Hooks in eigener
# Reihenfolge. Dieser Fächer prüft NUR die Deckungsgleichheit (nicht Einzelwerte):
# jede Kombination aus Charm-Satz × Wurf × Umgebung muss in beiden Pfaden exakt
# gleich fallen - so kann keine künftige Hook-Änderung die zwei still auseinander-
# laufen lassen (wie schon einmal bei Anzeige/Buchung geschehen).

## Ein Vertreter je Hook-Typ plus ein paar Stapel - Wert egal, nur Deckung zählt.
func _prop_charm_sets() -> Array:
	return [
		[],
		[Charm.TWIN_RING], [Charm.SNAKE_EYES],
		[Charm.PENDULUM], [Charm.ALL_OR_NOTHING], [Charm.MOMENTUM], [Charm.BROKEN_MIRROR],
		[Charm.EVEN_COMPANY], [Charm.ODD_PATH], [Charm.HERMIT_CRAB], [Charm.DISPLAY_CASE],
		[Charm.COLLECTORS_AMULET], [Charm.ECHO_CHAMBER], [Charm.STREET_SWEEPER],
		[Charm.FULL_COUNTER], [Charm.BROADBAND], [Charm.SEDIMENT],
		[Charm.HORSESHOE],
		[Charm.LADYBUG], [Charm.PEARL_NECKLACE], [Charm.RAINBOW_TROUT], [Charm.MAGIC_CARD],
		[Charm.CULT_OF_ONE], [Charm.GALLOWS_HUMOR], [Charm.AFTER_WORK_BEER],
		[Charm.LUCKY_CIGARETTES], [Charm.PENCIL_STUB], [Charm.FOX_TAIL],
		[Charm.SMALL_FRY], [Charm.EQUALIZER],
		[Charm.RABBITS_FOOT], [Charm.FOUR_LEAF_CLOVER],
		[Charm.PROTECTION_MONEY], [Charm.WATERFALL], [Charm.DOUBLE_BOTTOM],
		[Charm.BEHERIT], [Charm.HIGH_STACKER], [Charm.PRIME_TIME], [Charm.QUADRATURE],
		[Charm.FRONT_RUNNER], [Charm.SIX_PACK],
		[Charm.CULT_OF_ONE, Charm.GALLOWS_HUMOR, Charm.MAGIC_CARD],
		[Charm.LUCKY_CIGARETTES, Charm.ECHO_CHAMBER, Charm.FREE_DRINK],
		[Charm.EQUALIZER, Charm.SMALL_FRY, Charm.ECHO_CHAMBER, Charm.FULL_COUNTER],
		[Charm.WATERFALL, Charm.BEHERIT, Charm.ECHO_CHAMBER],
		[Charm.PROTECTION_MONEY, Charm.RABBITS_FOOT, Charm.DOUBLE_BOTTOM],
		[Charm.WATERFALL, Charm.PROTECTION_MONEY, Charm.FULL_COUNTER, Charm.HIGH_STACKER],
	]

## Würfe mit unbeteiligten Würfeln, geraden/ungeraden Läufen, Einsen und Sechsen -
## deckt die wertabhängigen Verzweigungen der Hooks ab.
func _prop_dice() -> Array:
	return [
		[1, 2, 3, 4, 5, 6], [6, 6, 6, 1, 1, 2], [5, 5, 1, 2, 3, 4],
		[1, 1, 2, 4, 6, 6], [2, 2, 2, 4, 4, 6], [1, 3, 5, 5, 5, 5],
		[2, 4, 6, 2, 4, 6], [1, 3, 5, 1, 3, 5],
	]

func test_breakdown_matches_scoring_across_the_matrix():
	var levels := {DiceScoring.TWO_KIND: 1, DiceScoring.THREE_KIND: 1}
	# Zwei Umgebungen: nackt, und voll (Materialien + Essenzen + reicher Kontext +
	# Übertaktung + erste Hand) - so laufen auch die Material-/Krit-Zweige mit.
	var full_mats := _m([DieMaterial.RUBY, "", DieMaterial.AMBER, DieMaterial.GLASS, "", DieMaterial.BONE])
	var rich_ctx := {
		CharmEffects.CTX_PENDULUM: 4,
		CharmEffects.CTX_FULL_REROLLS: 2, CharmEffects.CTX_STREAK: 3,
		CharmEffects.CTX_POOL_EMPTY: true, CharmEffects.CTX_AFTER_FARKLE: true,
		CharmEffects.CTX_FARKLE_STACKS: 2,
		CharmEffects.CTX_LATE_SLOTS: [4, 5],
		# Essenzen decken den Retrigger- und den Krit-Zweig mit ab.
		DiceScoring.CTX_ESSENCES: {1: Essence.ARGON, 4: Essence.XENON, 5: Essence.FIREDAMP},
	}
	# Nur die Deckung (total == score_category) je Zelle - die Zwischenstände
	# prüfen die gezielten Tests oben. Abweichungen sammeln und EINMAL asserten,
	# sonst ertränkt der Fächer (~640 Zellen) das Log.
	var mismatches: Array[String] = []
	var checked := 0
	for set: Array in _prop_charm_sets():
		var ids := _ids(set)
		for raw: Array in _prop_dice():
			var dice := _d(raw)
			var key: String = DiceScoring.best_hand(dice, ids, false, NO_MATS, {}, {})["key"]
			var first_key: String = DiceScoring.best_hand(dice, ids, true, full_mats, levels, rich_ctx)["key"]
			_collect_mismatch(mismatches, key, dice, ids, false, NO_MATS, {}, {})
			_collect_mismatch(mismatches, first_key, dice, ids, true, full_mats, levels, rich_ctx)
			checked += 2
	assert_eq(mismatches, [] as Array[String],
		"%d/%d Zellen weichen ab: %s" % [mismatches.size(), checked, ", ".join(mismatches)])

## Hängt eine Beschreibung an, WENN build["total"] von score_category abweicht -
## und prüft zugleich, dass jeder Pro-Würfel-Puls-Schritt sich exakt zu seiner
## Marginale summiert (sonst zeigte die Meteor-je-Würfel-Animation falsche Zahlen).
func _collect_mismatch(into: Array[String], key: String, dice: Array[int], ids: Array[String], first: bool, mats: Array[String], levels: Dictionary, ctx: Dictionary) -> void:
	var breakdown := ScoreBreakdown.build(key, dice, ids, first, mats, levels, ctx)
	var total: int = breakdown["total"]
	var expected := DiceScoring.score_category(key, dice, ids, first, mats, levels, ctx)
	if total != expected:
		into.append("%s%s/%s/%s: %d≠%d" % ["erste " if first else "", key, str(ids), str(dice), total, expected])
	for step: Dictionary in breakdown["charm_steps"]:
		if not step.has("pulses"):
			continue
		var sum_base := 0
		var sum_mult := 0
		for p: Dictionary in step["pulses"]:
			sum_base += int(p["base"])
			sum_mult += int(p["mult"])
		if sum_base != int(step["base_add"]) or sum_mult != int(step["mult_add"]):
			into.append("PULSE-SUMME %s/%s: %d/%d≠%d/%d" % [key, str(ids), sum_base, sum_mult, step["base_add"], step["mult_add"]])

## Die LADUNG darf die Deckung nirgends aufbrechen: derselbe Fächer, einmal mit
## Ladungen ohne Würfe (Vorschau) und einmal mit einem eingefrorenen Wurf-Vorrat,
## in dem auch das Durchbrennen vorkommt.
func test_breakdown_matches_scoring_with_charges():
	var mismatches: Array[String] = []
	var hot := {DiceScoring.CTX_CHARGES: {0: 1, 2: 3, 5: 2}}
	var rolling := {
		DiceScoring.CTX_CHARGES: {0: 1, 2: 3, 5: 2},
		DiceScoring.CTX_BURNED: {3: true},
		DiceScoring.CTX_CHARGE_ROLLS: _charge_rolls(),
	}
	for set: Array in _prop_charm_sets():
		var ids := _ids(set)
		for raw: Array in _prop_dice():
			var dice := _d(raw)
			for ctx: Dictionary in [hot, rolling]:
				var key: String = DiceScoring.best_hand(dice, ids, false, NO_MATS, {}, ctx)["key"]
				_collect_mismatch(mismatches, key, dice, ids, false, NO_MATS, {}, ctx)
	assert_eq(mismatches, [] as Array[String], ", ".join(mismatches))

## Vorgewürfelter Vorrat für alle sechs Slots - abwechselnd Treffer und Fehlwurf,
## damit Aufladen UND Durchbrennen im Fächer vorkommen.
func _charge_rolls() -> Dictionary:
	var rolls := {}
	for slot in 6:
		var pool: Array[float] = []
		for r in DiceScoring.CHARGE_ROLLS_PER_DIE:
			pool.append(0.1 if (r + slot) % 2 == 0 else 0.9)
		rolls[slot] = pool
	return rolls
