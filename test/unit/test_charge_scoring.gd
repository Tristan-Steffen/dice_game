extends GutTest
## Die LADUNG in der Wertung: die Grundregel (+1 Mult je Ladung), der Wurf je
## Zündung, das Durchbrennen und der durchgebrannte Würfel. Gewürfelt wird hier
## nie - die Würfe stehen als vorgewürfelte Floats im ctx, genau wie beim Zug.

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

## Vorgewürfelter Vorrat eines Slots: true = der Wurf trifft, false = daneben.
func _pool(hits: Array) -> Array[float]:
	var pool: Array[float] = []
	for hit in hits:
		pool.append(0.1 if bool(hit) else 0.9)
	return pool

func _score(key: String, dice: Array[int], ctx: Dictionary, charms: Array[String] = [],
		materials: Array[String] = []) -> int:
	return DiceScoring.score_category(key, dice, charms, false, materials, {}, ctx)

func _build(key: String, dice: Array[int], ctx: Dictionary, charms: Array[String] = [],
		materials: Array[String] = []) -> Dictionary:
	return ScoreBreakdown.build(key, dice, charms, false, materials, {}, ctx)

# --- Die Grundregel -------------------------------------------------------------

func test_each_charge_is_one_mult():
	# Paar aus 4en: 10 Kombi-Punkte + 8 Augen, Mult 2 - je Ladung eine dazu.
	var cold := _score(DiceScoring.TWO_KIND, _d([4, 4]), {})
	assert_eq(cold, 36, "kalt: 18 × 2")
	var ctx := {DiceScoring.CTX_CHARGES: {0: 2, 1: 1}}
	assert_eq(_score(DiceScoring.TWO_KIND, _d([4, 4]), ctx), 90, "18 × (2 + 3)")

func test_a_burned_die_carries_no_charge():
	# Er ist tot, nicht heiß: seine Ladung zählt für die Grundregel nicht mit.
	var ctx := {
		DiceScoring.CTX_CHARGES: {0: 2, 1: 2},
		DiceScoring.CTX_BURNED: {1: true},
	}
	# Nur Slot 0 zählt: Basis 10 + 4 (Slot 1 liefert 0 Augen), Mult 2 + 2.
	assert_eq(_score(DiceScoring.TWO_KIND, _d([4, 4]), ctx), 14 * 4)

func test_without_rolls_the_scoring_never_charges():
	# Der Vorschau fehlt CTX_CHARGE_ROLLS - sie rechnet mit den Ladungen, wie sie
	# liegen, und lädt nichts auf.
	var ctx := {DiceScoring.CTX_CHARGES: {0: 1, 1: 0}}
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	assert_eq(int(breakdown["charges_after"][0]), 1)
	assert_eq(int(breakdown["charges_after"][1]), 0)
	assert_eq(breakdown["burned_after"], [] as Array[int])

# --- Der Wurf je Zündung --------------------------------------------------------

func test_a_hit_lifts_the_charge_by_one():
	var ctx := {
		DiceScoring.CTX_CHARGES: {0: 0, 1: 0},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true]), 1: _pool([false])},
	}
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	assert_eq(int(breakdown["charges_after"][0]), 1, "Treffer lädt")
	assert_eq(int(breakdown["charges_after"][1]), 0, "Fehlwurf lädt nicht")
	# Der END-Stand steht als eigener Schritt vor den Charms und im Mult.
	assert_eq(int(breakdown["charge_mult_step"]["mult_add"]), 1)
	assert_eq(breakdown["merge_total"], 18 * 3, "Mult 2 + 1")

func test_the_firing_reports_its_own_charge():
	var ctx := {
		DiceScoring.CTX_CHARGES: {0: 0, 1: 0},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true]), 1: _pool([false])},
	}
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	var firing: Dictionary = breakdown["die_steps"][0]["die_triggers"][0]["firings"][0]
	assert_eq(int(firing["charge_after"]), 1)
	assert_true(bool(firing["charge_up"]))
	assert_false(bool(firing["burned"]))

func test_retriggers_charge_once_each():
	# Quecksilberdampf tritt dreimal an - drei Würfe, also 0 auf 3 in EINER Hand.
	var ctx := {
		DiceScoring.CTX_ESSENCES: {0: Essence.MERCURY_VAPOR},
		DiceScoring.CTX_CHARGES: {0: 0, 1: 0},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true, true, true]), 1: _pool([false])},
	}
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	assert_eq(int(breakdown["charges_after"][0]), 3, "drei Zündungen, drei Stufen")

func test_the_cap_holds_without_burning():
	# Wer die Spitze erst in DIESER Hand erreicht, kann in ihr nicht durchbrennen.
	var ctx := {
		DiceScoring.CTX_ESSENCES: {0: Essence.MERCURY_VAPOR},
		DiceScoring.CTX_CHARGES: {0: 2, 1: 0},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true, true, true]), 1: _pool([false])},
	}
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	assert_eq(int(breakdown["charges_after"][0]), 3, "gedeckelt")
	assert_eq(breakdown["burned_after"], [] as Array[int], "kein Durchbrennen")

# --- Durchbrennen ---------------------------------------------------------------

func test_a_hot_die_burns_and_stops_firing():
	# Argon tritt zweimal an; der erste Wurf brennt ihn durch, der zweite Antritt
	# entfällt - die durchbrennende Zündung zählt aber noch voll.
	var ctx := {
		DiceScoring.CTX_ESSENCES: {0: Essence.ARGON},
		DiceScoring.CTX_CHARGES: {0: 3, 1: 0},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true, true]), 1: _pool([false])},
	}
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	assert_eq(breakdown["burned_after"], [0] as Array[int])
	assert_eq(int(breakdown["charges_after"][0]), 0, "durchgebrannt trägt keine Ladung")
	var groups: Array = breakdown["die_steps"][0]["die_triggers"]
	assert_eq(groups.size(), 1, "der zweite Antritt entfällt")
	assert_eq(groups[0]["firings"].size(), 1)
	assert_true(bool(groups[0]["firings"][0]["burned"]))

func test_the_burning_firing_still_counts():
	var ctx := {
		DiceScoring.CTX_CHARGES: {0: 3, 1: 0},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true]), 1: _pool([false])},
	}
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	# Beide Augen sind gezählt; die 3 Ladung ist mit dem Durchbrennen fort.
	assert_eq(breakdown["merge_total"], 18 * 2)

func test_a_die_that_entered_burned_scores_nothing():
	# Er zählt für die HAND-ERKENNUNG mit, liefert aber 0 Augen und keinen Schritt.
	var ctx := {DiceScoring.CTX_BURNED: {2: true}}
	assert_true(DiceScoring.qualifies(DiceScoring.LARGE_STRAIGHT, _d([1, 2, 3, 4, 5, 6]), ctx),
		"die Straße bleibt eine Straße")
	var breakdown := _build(DiceScoring.LARGE_STRAIGHT, _d([1, 2, 3, 4, 5, 6]), ctx)
	assert_eq(breakdown["die_steps"].size(), 5, "der Durchgebrannte bekommt keinen Schritt")
	var expected := DiceScoring.points_for(DiceScoring.LARGE_STRAIGHT) + (21 - 3)
	assert_eq(int(breakdown["base"]), expected, "seine Augen fehlen")

func test_a_burned_die_fires_no_material():
	# Kein Material-Beitrag, kein Wachstum: an ihm feuert nichts.
	var ctx := {
		DiceScoring.CTX_BURNED: {1: true},
		DiceScoring.CTX_MATERIAL_LEVELS: {0: {"level": 1, "eye_sum": 24},
			1: {"level": 1, "eye_sum": 24}},
	}
	var materials := _m([DieMaterial.RUBY, DieMaterial.RUBY])
	var with_burn := _score(DiceScoring.TWO_KIND, _d([4, 4]), ctx, _ids([]), materials)
	var ctx_clean := {DiceScoring.CTX_MATERIAL_LEVELS: ctx[DiceScoring.CTX_MATERIAL_LEVELS]}
	var clean := _score(DiceScoring.TWO_KIND, _d([4, 4]), ctx_clean, _ids([]), materials)
	assert_lt(with_burn, clean, "der Durchgebrannte trägt weder Augen noch Rubin bei")

# --- Die Regel-Parameter --------------------------------------------------------

func test_a_negative_step_drains_instead_of_rolling():
	# Ableitung: jede Zündung SENKT, ganz ohne Wurf - auch ohne Wurf-Vorrat.
	var rule := DiceScoring.default_charge_rule()
	rule["step"] = -1
	var ctx := {
		DiceScoring.CTX_CHARGES: {0: 2, 1: 2},
		DiceScoring.CTX_CHARGE_RULE: rule,
	}
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	assert_eq(int(breakdown["charges_after"][0]), 1)
	assert_eq(int(breakdown["charges_after"][1]), 1)

func test_a_lower_cap_holds_earlier():
	# Kühlkörper: kein Würfel steigt über Ladung 2, Durchbrennen unmöglich.
	var rule := DiceScoring.default_charge_rule()
	rule["cap"] = 2
	var ctx := {
		DiceScoring.CTX_ESSENCES: {0: Essence.MERCURY_VAPOR},
		DiceScoring.CTX_CHARGES: {0: 0, 1: 0},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true, true, true]), 1: _pool([false])},
		DiceScoring.CTX_CHARGE_RULE: rule,
	}
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	assert_eq(int(breakdown["charges_after"][0]), 2)
	assert_eq(breakdown["burned_after"], [] as Array[int])

func test_can_burn_false_keeps_the_die_alive():
	# Kühlpause: kein Würfel brennt diese Runde durch - er bleibt auf der Spitze.
	var rule := DiceScoring.default_charge_rule()
	rule["can_burn"] = false
	var ctx := {
		DiceScoring.CTX_CHARGES: {0: 3, 1: 0},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true]), 1: _pool([false])},
		DiceScoring.CTX_CHARGE_RULE: rule,
	}
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	assert_eq(breakdown["burned_after"], [] as Array[int])
	assert_eq(int(breakdown["charges_after"][0]), 3)

func test_the_fuse_catches_the_first_burnout_only():
	# Sicherung: der erste Durchbrenner fällt auf 0 statt durchzubrennen - und
	# zwar genau EINMAL je Hand.
	var rule := DiceScoring.default_charge_rule()
	rule["fuse_armed"] = true
	var ctx := {
		DiceScoring.CTX_CHARGES: {0: 3, 1: 3},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true]), 1: _pool([true])},
		DiceScoring.CTX_CHARGE_RULE: rule,
	}
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	assert_true(bool(breakdown["fuse_used"]))
	assert_eq(int(breakdown["charges_after"][0]), 0, "die Sicherung setzt ihn auf 0")
	assert_eq(breakdown["burned_after"], [1] as Array[int], "der zweite brennt durch")

# --- Der Wurf-Vorrat ------------------------------------------------------------

func test_roll_charge_rolls_fills_one_pool_per_slot():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rolls := DiceScoring.roll_charge_rolls(_d([0, 3]), rng)
	assert_eq(rolls.size(), 2)
	assert_eq((rolls[0] as Array).size(), DiceScoring.CHARGE_ROLLS_PER_DIE)
	assert_true(rolls.has(3))

func test_the_same_seed_rolls_the_same_pool():
	var a := RandomNumberGenerator.new()
	a.seed = 42
	var b := RandomNumberGenerator.new()
	b.seed = 42
	assert_eq(DiceScoring.roll_charge_rolls(_d([0]), a), DiceScoring.roll_charge_rolls(_d([0]), b))

func test_an_exhausted_pool_counts_as_a_miss():
	# Reicht der Vorrat nicht, gilt der Wurf als verfehlt - nie nachwürfeln.
	var ctx := {
		DiceScoring.CTX_ESSENCES: {0: Essence.MERCURY_VAPOR},
		DiceScoring.CTX_CHARGES: {0: 0, 1: 0},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true]), 1: _pool([false])},
	}
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx)
	assert_eq(int(breakdown["charges_after"][0]), 1, "nur der eine gewürfelte Treffer")

# --- Der Spiegel ----------------------------------------------------------------

func test_the_breakdown_mirrors_the_scoring_with_rolls():
	var ctx := {
		DiceScoring.CTX_ESSENCES: {0: Essence.ARGON},
		DiceScoring.CTX_CHARGES: {0: 1, 1: 3},
		DiceScoring.CTX_CHARGE_ROLLS: {0: _pool([true, false]), 1: _pool([true])},
		DiceScoring.CTX_MATERIAL_LEVELS: {0: {"level": 1, "eye_sum": 24}},
	}
	var materials := _m([DieMaterial.BONE, ""])
	var breakdown := _build(DiceScoring.TWO_KIND, _d([4, 4]), ctx, _ids([]), materials)
	assert_eq(breakdown["merge_total"],
		_score(DiceScoring.TWO_KIND, _d([4, 4]), ctx, _ids([]), materials),
		"Schrittliste und Wertung rechnen byteweise gleich")
