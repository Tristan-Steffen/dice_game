extends GutTest
## Tier-2-Tests der dritten Inhalts-Welle: alles, was neuen Lauf-/Rundenzustand
## braucht (Energie, Runde, genommene Hände, Fumbles, Ablage, Erstwertung),
## dazu Sternschnuppen-Deckel, Glasfaser, Lötkolben/Erdungskabel und die
## Hintergrundstrahlung mit ihrer Simulation-gegen-Def-Probe.

func _d(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _p(values: Array) -> Array[int]:
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
const NO_MATS: Array[String] = []
const PAIR := DiceScoring.TWO_KIND

## Würfel mit gesetzten Seitenwerten (und optional einem Material auf Seite 0).
func _die(faces: Array, face_material := "", essence_id := "") -> DieDefinition:
	var def := DieDefinition.new()
	def.faces = _d(faces)
	if face_material != "":
		def.set_face_material(0, face_material)
	def.essence_id = essence_id
	return def

## Ein Paar 5er mit einer Seele auf Slot 0 - die kleinste Bühne für jeden Krit.
func _soul_ctx(essence_id: String) -> Dictionary:
	return {DiceScoring.CTX_ESSENCES: {0: essence_id}}

func _pair_score(charm_ids: Array[String], ctx: Dictionary) -> int:
	return DiceScoring.score_category(PAIR, _d([5, 5]), charm_ids, false, _m(["", ""]), {}, ctx)

# --- Tscherenkow-Licht & Steuerstab: die gelagerte Energie kritet -------------------

func test_the_cherenkov_crit_rides_the_stored_charge():
	var soul := _ids([Essence.CHERENKOV])
	assert_almost_eq(EssenceEffects.crit_of(soul, 5), 1.0, 0.0001, "ohne Energie kein Krit")
	assert_almost_eq(EssenceEffects.crit_of(soul, 5, 0, 0, 0, NO_CHARMS, 10), 3.0, 0.0001)
	assert_almost_eq(EssenceEffects.crit_of(soul, 5, 0, 0, 0, NO_CHARMS, 5), 2.0, 0.0001)

func test_the_moderator_shrinks_the_divisor():
	var soul := _ids([Essence.CHERENKOV])
	assert_almost_eq(EssenceEffects.crit_of(soul, 5, 0, 0, 0, _ids([Charm.MODERATOR]), 10), 6.0, 0.0001)
	assert_almost_eq(EssenceEffects.crit_of(_ids([Essence.NEON]), 5, 0, 0, 0, _ids([Charm.MODERATOR]), 10),
		1.0, 0.0001, "der Steuerstab gehört dem Tscherenkow allein")

func test_the_cherenkov_crit_lands_in_the_score():
	var ctx := _soul_ctx(Essence.CHERENKOV)
	assert_eq(_pair_score(NO_CHARMS, ctx), 40, "ohne Energie zählt das Paar normal")
	ctx[DiceScoring.CTX_CHARGE] = 10
	assert_eq(_pair_score(NO_CHARMS, ctx), 20 * 2 * 3, "×3 an der Zündung des Würfels")
	assert_eq(_pair_score(_ids([Charm.MODERATOR]), ctx), 20 * 2 * 6)

# --- Standby-Licht, Kilometerzähler, Flaschenregal: statische Mult-Charms ----------

func test_the_standby_light_pays_per_stored_charge():
	assert_eq(_pair_score(_ids([Charm.STANDBY_LIGHT]), {}), 40, "leerer Speicher, leerer Charm")
	assert_eq(_pair_score(_ids([Charm.STANDBY_LIGHT]), {DiceScoring.CTX_CHARGE: 4}),
		20 * (2 + 4 * CharmEffects.STANDBY_LIGHT_MULT))

func test_the_odometer_counts_the_played_rounds():
	assert_eq(_pair_score(_ids([Charm.ODOMETER]), {DiceScoring.CTX_ROUND: 7}),
		20 * (2 + 7 * CharmEffects.ODOMETER_MULT))

func test_the_bottle_rack_counts_the_souls_in_the_discard():
	assert_eq(_pair_score(_ids([Charm.BOTTLE_RACK]), {DiceScoring.CTX_DISCARD_SOULS: 3}),
		20 * (2 + 3 * CharmEffects.BOTTLE_RACK_MULT))
	assert_eq(_pair_score(_ids([Charm.BOTTLE_RACK]), {}), 40, "leere Ablage, leerer Charm")

func test_the_bottle_rack_counts_dice_not_kinds():
	# Zwei Würfel mit derselben Seele zahlen zweimal - gezählt wird der Würfel.
	assert_eq(_pair_score(_ids([Charm.BOTTLE_RACK]), {DiceScoring.CTX_DISCARD_SOULS: 2}),
		20 * (2 + 2 * CharmEffects.BOTTLE_RACK_MULT))

# --- Mitternachtssonne & Polartag: je genommener Hand ein Antritt mehr -------------

func test_the_midnight_sun_grows_with_the_taken_hands():
	var order := _p([0, 1])
	var sets := {0: Essence.MIDNIGHT_SUN}
	var values := _d([5, 5])
	assert_eq(EssenceEffects.extra_activations(0, order, sets, NO_CHARMS, values, 0), 0,
		"vor der ersten Hand geht sie noch unter")
	assert_eq(EssenceEffects.extra_activations(0, order, sets, NO_CHARMS, values, 2),
		2 * EssenceEffects.MIDNIGHT_SUN_ACTIVATIONS)
	assert_eq(EssenceEffects.extra_activations(1, order, sets, NO_CHARMS, values, 2), 0,
		"nur die Sonne selbst")

func test_the_polar_day_doubles_every_taken_hand():
	assert_eq(EssenceEffects.extra_activations(0, _p([0]), {0: Essence.MIDNIGHT_SUN},
		_ids([Charm.POLAR_DAY]), _d([5]), 2), 2 * EssenceEffects.MIDNIGHT_SUN_ACTIVATIONS_POLAR)

func test_the_midnight_sun_lands_in_the_score():
	var ctx := _soul_ctx(Essence.MIDNIGHT_SUN)
	assert_eq(_pair_score(NO_CHARMS, ctx), 40)
	ctx[DiceScoring.CTX_HANDS_TAKEN] = 1
	assert_eq(_pair_score(NO_CHARMS, ctx), (10 + 5 + 5 + 5) * 2, "ein zweiter Antritt, ein zweites Mal Augen")

# --- Vulkanblitz & Aschewolke: die Fumbles der Runde -------------------------------

func test_the_volcanic_lightning_crits_with_the_round_fumbles():
	var soul := _ids([Essence.VOLCANIC_LIGHTNING])
	assert_almost_eq(EssenceEffects.crit_of(soul, 5, 0, 0, 0, NO_CHARMS, 0, false, 0), 1.0, 0.0001,
		"ohne Fumble ×1 - also gar kein Krit")
	assert_almost_eq(EssenceEffects.crit_of(soul, 5, 0, 0, 0, NO_CHARMS, 0, false, 2), 3.0, 0.0001)

func test_the_ash_cloud_adds_the_run_long_counter():
	var ctx := {DiceScoring.CTX_FUMBLES: 1, DiceScoring.CTX_ASH_FUMBLES: 3}
	assert_eq(DiceScoring.volcanic_fumbles_in(ctx, NO_CHARMS), 1, "ohne Wolke zählt nur die Runde")
	assert_eq(DiceScoring.volcanic_fumbles_in(ctx, _ids([Charm.ASH_CLOUD])), 4)

func test_the_volcanic_crit_lands_in_the_score():
	var ctx := _soul_ctx(Essence.VOLCANIC_LIGHTNING)
	ctx[DiceScoring.CTX_FUMBLES] = 2
	assert_eq(_pair_score(NO_CHARMS, ctx), 20 * 2 * 3)
	ctx[DiceScoring.CTX_ASH_FUMBLES] = 1
	assert_eq(_pair_score(_ids([Charm.ASH_CLOUD]), ctx), 20 * 2 * 4)

func test_game_run_counts_the_fumbles_on_both_ledgers():
	var run := GameRun.new_run()
	run.note_fumble(false)
	run.note_fumble(true)
	assert_eq(run.round_fumbles, 2)
	assert_eq(run.ash_fumbles, 1, "die Aschewolke zählt nur Fumbles MIT Vulkanblitz")
	run.roll_essence_round_state()
	assert_eq(run.round_fumbles, 0, "der Rundenzähler fängt neu an")
	assert_eq(run.ash_fumbles, 1, "der run-lange bleibt stehen")

# --- Erstwertung: Sternschnuppe, Gammablitz, Magnetar ------------------------------

func test_game_run_marks_a_die_after_its_first_scoring():
	var run := GameRun.new_run()
	var die := DieDefinition.standard()
	assert_true(run.first_scoring(die))
	run.note_dice_scored(_defs([die]), _p([0]))
	assert_false(run.first_scoring(die))
	run.roll_essence_round_state()
	assert_true(run.first_scoring(die), "jede Runde ist wieder eine erste")

func test_the_shooting_star_crits_only_on_its_first_scoring():
	var soul := _ids([Essence.SHOOTING_STAR])
	assert_almost_eq(EssenceEffects.crit_of(soul, 5, 0, 0, 0, NO_CHARMS, 0, true),
		EssenceEffects.SHOOTING_STAR_CRIT, 0.0001)
	assert_almost_eq(EssenceEffects.crit_of(soul, 5, 0, 0, 0, NO_CHARMS, 0, false), 1.0, 0.0001)
	assert_almost_eq(EssenceEffects.crit_of(soul, 5, 0, 0, 0, NO_CHARMS, 0, true, 0, false), 1.0, 0.0001,
		"nur die ERSTE Zündung der Nahme trägt den Strich")

func test_the_gamma_burst_crits_once_and_the_magnetar_always():
	var soul := _ids([Essence.GAMMA_BURST])
	assert_almost_eq(EssenceEffects.crit_of(soul, 5, 0, 0, 0, NO_CHARMS, 0, true),
		EssenceEffects.GAMMA_BURST_CRIT, 0.0001)
	assert_almost_eq(EssenceEffects.crit_of(soul, 5, 0, 0, 0, NO_CHARMS, 0, false), 1.0, 0.0001)
	assert_almost_eq(EssenceEffects.crit_of(soul, 5, 0, 0, 0, _ids([Charm.MAGNETAR]), 0, false),
		EssenceEffects.GAMMA_BURST_CRIT, 0.0001, "der Magnetar strahlt ohne Pause")

func test_the_first_scoring_crit_lands_in_the_score():
	var ctx := _soul_ctx(Essence.SHOOTING_STAR)
	assert_eq(_pair_score(NO_CHARMS, ctx), 40, "eine zweite Wertung zahlt nichts extra")
	ctx[DiceScoring.CTX_FIRST_SCORING] = {0: true}
	assert_eq(_pair_score(NO_CHARMS, ctx), 20 * 2 * 4)

func test_the_farkle_comparison_carries_the_first_scoring_snapshot():
	# Die alte Seite rechnet mit IHREN Marken (vor dem Neuwurf), die neue mit den
	# aktuellen - genau dafür schnappt scene_root pre_reroll_first_scoring.
	var new_ctx := {DiceScoring.CTX_ESSENCES: {0: Essence.SHOOTING_STAR}}
	var old_ctx := {DiceScoring.CTX_ESSENCES: {0: Essence.SHOOTING_STAR},
		DiceScoring.CTX_FIRST_SCORING: {0: true}}
	var fresh: int = DiceScoring.best_hand(_d([5, 5]), NO_CHARMS, false, _m(["", ""]), {}, old_ctx)["score"]
	var used: int = DiceScoring.best_hand(_d([5, 5]), NO_CHARMS, false, _m(["", ""]), {}, new_ctx)["score"]
	assert_eq(fresh, 20 * 2 * 4)
	assert_eq(used, 40)
	# Der Rang entscheidet weiterhin allein: Dreier schlägt Paar, egal wer kritet.
	assert_true(DiceScoring.is_strictly_better(_d([5, 5, 5]), _d([5, 5]), NO_CHARMS,
		_m(["", "", ""]), _m(["", ""]), {}, new_ctx, old_ctx))

# --- Sternschnuppe & Meteorit ------------------------------------------------------

func test_the_shooting_star_fires_like_any_other_die():
	# Der Deckel ist weg: Echo-Kammer, Hasenpfote und Nachglühen kommen durch.
	var soul := _ids([Essence.SHOOTING_STAR])
	var ids := _ids([Charm.ECHO_CHAMBER, Charm.RABBITS_FOOT])
	assert_eq(MaterialEffects.die_trigger_count(0, ids, 0, soul, false, 3, 6, 0), 5)
	assert_eq(MaterialEffects.face_trigger_count(6, ids, 1, soul), 3)
	assert_eq(MaterialEffects.total_trigger_count(0, ids, 6, 0, soul, false, 3, 1, 6, 0), 15)

func test_the_meteorite_crits_at_every_scoring():
	# Ohne ihn kritet nur die ERSTE Wertung der Runde, mit ihm jede - beide Male
	# aber nur an der ersten Zündung.
	var soul := _ids([Essence.SHOOTING_STAR])
	var meteor := _ids([Charm.METEORITE])
	assert_almost_eq(EssenceEffects.crit_of(soul, 5, 0, 0, 0, meteor, 0, false),
		EssenceEffects.SHOOTING_STAR_CRIT, 0.0001)
	assert_almost_eq(EssenceEffects.crit_of(soul, 5, 0, 0, 0, meteor, 0, false, 0, false), 1.0, 0.0001,
		"eine spätere Zündung bleibt kalt")

func test_the_star_fires_often_but_crits_once():
	# Echo-Kammer × Nachglühen: vier Zündungen à 5 Augen plus der Mitwürfel -
	# Basis 35, Mult 2, und GENAU ein Strich ×4.
	var ctx := _soul_ctx(Essence.SHOOTING_STAR)
	ctx[DiceScoring.CTX_RUNES] = {0: _ids([Rune.AFTERGLOW])}
	ctx[DiceScoring.CTX_FIRST_SCORING] = {0: true}
	var ids := _ids([Charm.ECHO_CHAMBER])
	assert_eq(DiceScoring.score_category(PAIR, _d([5, 5]), ids, false, _m(["", ""]), {}, ctx), 280)
	ctx.erase(DiceScoring.CTX_FIRST_SCORING)
	assert_eq(DiceScoring.score_category(PAIR, _d([5, 5]), ids, false, _m(["", ""]), {}, ctx), 70,
		"die zweite Wertung der Runde kritet nicht mehr")
	assert_eq(DiceScoring.score_category(PAIR, _d([5, 5]), _ids([Charm.ECHO_CHAMBER, Charm.METEORITE]),
		false, _m(["", ""]), {}, ctx), 280, "mit Meteorit kritet auch sie - einmal")

# --- Pointer: Lötkolben, Erdungskabel, Glasfaser ---------------------------------

func test_the_soldering_iron_raises_the_base_chance():
	assert_almost_eq(DiceScoring.pointer_base_chance(NO_CHARMS), DiceScoring.POINTER_CHANCE, 0.0001)
	assert_almost_eq(DiceScoring.pointer_base_chance(_ids([Charm.SOLDERING_IRON])), 0.6, 0.0001)
	var stacked := _ids([Charm.SOLDERING_IRON, Charm.SOLDERING_IRON, Charm.SOLDERING_IRON,
		Charm.SOLDERING_IRON, Charm.SOLDERING_IRON, Charm.SOLDERING_IRON])
	assert_lt(DiceScoring.pointer_base_chance(stacked), 1.0, "nie 100 %")
	assert_lt(EssenceEffects.pointer_chance_of(_ids([Essence.PLASMA]),
		DiceScoring.pointer_base_chance(stacked)), 1.0, "auch der Lichtbogen bleibt darunter")

func test_the_ground_wire_counts_the_missed_rolls():
	var ctx := {DiceScoring.CTX_POINTER_FIRES: {0: [[], [{"face": 2, "value": 3, "material": ""}]], 1: [[]]}}
	assert_eq(DiceScoring.pointer_misses_in(ctx), 2)
	assert_eq(DiceScoring.pointer_misses_in({}), 0, "die Vorschau kennt keine Zündungen")

func test_the_ground_wire_lands_in_the_score():
	var ctx := {DiceScoring.CTX_POINTER_FIRES: {0: [[]]}}
	assert_eq(_pair_score(_ids([Charm.GROUND_WIRE]), ctx), 20 * (2 + CharmEffects.GROUND_WIRE_MULT))
	assert_eq(_pair_score(_ids([Charm.GROUND_WIRE]), {}), 40, "ohne Wurf keine Entladung")

func test_the_link_fire_count_is_one_source():
	assert_eq(EssenceEffects.link_fire_count(_ids([]), NO_CHARMS), 1)
	assert_eq(EssenceEffects.link_fire_count(_ids([Essence.OPTICAL_FIBER]), NO_CHARMS),
		EssenceEffects.OPTICAL_FIBER_FIRES)
	assert_eq(EssenceEffects.link_fire_count(_ids([Essence.OPTICAL_FIBER]), _ids([Charm.FEEDBACK])),
		EssenceEffects.OPTICAL_FIBER_FIRES_FEEDBACK)
	assert_eq(EssenceEffects.link_fire_count(_ids([Essence.PLASMA]), _ids([Charm.IGNITION_COIL])), 2,
		"die Zündspule behält ihr Plasma-Verhalten")
	assert_eq(EssenceEffects.link_fire_count(_ids([Essence.PLASMA]), NO_CHARMS), 1)

## Ein RNG, dessen erster Wurf sicher zündet (kein magischer Seed im Test).
func _rng_hit() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	for s in 500:
		rng.seed = s
		if rng.randf() < DiceScoring.POINTER_CHANCE:
			rng.seed = s
			return rng
	return null

func _pointer_die() -> DieDefinition:
	var def := DieDefinition.new()
	def.pointers[0] = 2
	return def

func test_the_optical_fiber_fires_its_target_twice():
	var soul := _ids([Essence.OPTICAL_FIBER])
	var plain := DiceScoring.roll_pointer_fires(_pointer_die(), 0, 1, 1, NO_CHARMS, _ids([]), _rng_hit())
	assert_eq((plain[0] as Array).size(), 1, "normal zündet ein Glied einmal")
	var fiber := DiceScoring.roll_pointer_fires(_pointer_die(), 0, 1, 1, NO_CHARMS, soul, _rng_hit())
	assert_eq((fiber[0] as Array).size(), 2)
	var fed := DiceScoring.roll_pointer_fires(_pointer_die(), 0, 1, 1, _ids([Charm.FEEDBACK]), soul, _rng_hit())
	assert_eq((fed[0] as Array).size(), 3, "die Rückkopplung legt eine dritte drauf")
	for entry: Dictionary in fed[0]:
		assert_eq(int(entry["face"]), 2, "immer dieselbe Zielseite")

# --- Fuchsfeuer & Pilzgeflecht: die Ablage -----------------------------------------

func test_the_foxfire_pays_per_two_discarded_dice():
	var soul := _ids([Essence.FOXFIRE])
	assert_eq(EssenceEffects.discard_eye_bonus_of(soul, _d([]), NO_CHARMS), 0)
	assert_eq(EssenceEffects.discard_eye_bonus_of(soul, _d([3]), NO_CHARMS), 0, "einer ist kein Paar")
	assert_eq(EssenceEffects.discard_eye_bonus_of(soul, _d([3, 4, 5]), NO_CHARMS),
		EssenceEffects.FOXFIRE_PER_PAIR)
	assert_eq(EssenceEffects.discard_eye_bonus_of(_ids([Essence.NEON]), _d([3, 4]), NO_CHARMS), 0)

func test_the_mycelium_adds_the_discard_eyes_on_top():
	assert_eq(EssenceEffects.discard_eye_bonus_of(_ids([Essence.FOXFIRE]), _d([3, 4]),
		_ids([Charm.MYCELIUM])), EssenceEffects.FOXFIRE_PER_PAIR + 7)

func test_the_foxfire_lands_in_the_score():
	var ctx := _soul_ctx(Essence.FOXFIRE)
	ctx[DiceScoring.CTX_DISCARD_VALUES] = _d([3, 4])
	assert_eq(_pair_score(NO_CHARMS, ctx), (10 + 5 + EssenceEffects.FOXFIRE_PER_PAIR + 5) * 2)
	assert_eq(_pair_score(_ids([Charm.MYCELIUM]), ctx),
		(10 + 5 + EssenceEffects.FOXFIRE_PER_PAIR + 7 + 5) * 2)

func test_the_discard_tray_poses_the_recorded_face():
	# Jede Seite muss sich nach oben drehen lassen - sonst zeigte die Ablage eine
	# andere Zahl, als das Fuchsfeuer zählt.
	for face in 6:
		var basis := Basis(DiceTrayView.face_up_pose(face))
		for axis: String in DiceController.AXIS_FACE_INDEX:
			if DiceController.AXIS_FACE_INDEX[axis] != face:
				continue
			var up: Vector3 = basis * DiceController.AXIS_DIRECTIONS[axis]
			assert_almost_eq(up.dot(Vector3.UP), 1.0, 0.0001, "Seite %d liegt oben" % face)
			# Das Tray giert um -90°: die Ziffern-Oben-Richtung muss dort auf +X landen.
			var text_up: Vector3 = Basis(Vector3.UP, -PI / 2.0) * (basis * DiceController.FACE_TEXT_UP[axis])
			assert_almost_eq(text_up.dot(Vector3.RIGHT), 1.0, 0.0001, "Ziffer steht aufrecht")

func test_the_resting_pose_is_the_unposed_one():
	assert_almost_eq(DiceTrayView.face_up_pose(-1).angle_to(Quaternion.IDENTITY), 0.0, 0.0001)
	assert_almost_eq(DiceTrayView.face_up_pose(3).angle_to(Quaternion.IDENTITY), 0.0, 0.0001,
		"Seite 3 liegt in der Ruhelage schon oben")

# --- Neonmarker: die materiallosen Würfel der Runde --------------------------------

func test_the_highlighter_escalates_with_the_round():
	var lit := _die([5, 2, 3, 4, 5, 6], "", Essence.BLACK_LIGHT)
	var mate := _die([5, 2, 3, 4, 5, 6])
	var report := MaterialEffects.apply_take_effects(_defs([lit, mate]), _p([0, 0]), _m(["", ""]),
		_p([0, 1]), _ids([Charm.HIGHLIGHTER]), -1, {0: Essence.BLACK_LIGHT}, _p([0, 1]),
		false, _p([]), {}, 0, 3)
	assert_eq(report.bare_dice, 2)
	assert_eq(report.total_money(), 2 * EssenceEffects.BLACK_LIGHT_PER_DIE + 5,
		"drei aus früheren Händen plus die zwei von jetzt")

func test_without_the_highlighter_the_black_light_stays_flat():
	var lit := _die([5, 2, 3, 4, 5, 6], "", Essence.BLACK_LIGHT)
	var report := MaterialEffects.apply_take_effects(_defs([lit]), _p([0]), _m([""]), _p([0]),
		NO_CHARMS, -1, {0: Essence.BLACK_LIGHT}, _p([0]), false, _p([]), {}, 0, 9)
	assert_eq(report.money, EssenceEffects.BLACK_LIGHT_PER_DIE)

func test_game_run_carries_the_bare_die_counter_through_the_round():
	var run := GameRun.new_run()
	run.note_bare_dice(2)
	run.note_bare_dice(3)
	assert_eq(run.round_bare_dice, 5)
	run.roll_essence_round_state()
	assert_eq(run.round_bare_dice, 0)

# --- Hintergrundstrahlung & Radioteleskop ------------------------------------------

func test_the_background_radiation_grows_every_lying_die():
	var source := _die([5, 2, 3, 4, 5, 6], "", Essence.BACKGROUND_RADIATION)
	var mate := _die([5, 2, 3, 4, 5, 6])
	var idle := _die([1, 1, 1, 1, 1, 1])
	var defs := _defs([source, mate, idle])
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0, 0]), _m(["", "", ""]),
		_p([0, 1]), NO_CHARMS, -1, {0: Essence.BACKGROUND_RADIATION}, _p([0, 1]), false, _p([0, 1, 2]))
	assert_eq(source.faces, _d([6, 3, 4, 5, 6, 7]), "sich selbst eingeschlossen")
	assert_eq(mate.faces, _d([6, 3, 4, 5, 6, 7]))
	assert_eq(idle.faces, _d([2, 2, 2, 2, 2, 2]), "auch der ungewertete liegt auf dem Tisch")
	assert_true(report.grown.has(2), "die Zeremonie muss den Blitz sehen")

func test_the_radiation_stays_in_the_pit_without_the_telescope():
	var source := _die([5, 2, 3, 4, 5, 6], "", Essence.BACKGROUND_RADIATION)
	var filed := _die([4, 4, 4, 4, 4, 4])
	var report := MaterialEffects.apply_take_effects(_defs([source]), _p([0]), _m([""]), _p([0]),
		NO_CHARMS, -1, {0: Essence.BACKGROUND_RADIATION}, _p([0]), false, _p([0]), {}, 0, 0,
		_defs([filed]))
	assert_eq(filed.faces, _d([4, 4, 4, 4, 4, 4]))
	assert_false(report.discard_grown)

func test_the_radio_telescope_reaches_the_discard():
	var source := _die([5, 2, 3, 4, 5, 6], "", Essence.BACKGROUND_RADIATION)
	var filed := _die([4, 4, 4, 4, 4, 4])
	var report := MaterialEffects.apply_take_effects(_defs([source]), _p([0]), _m([""]), _p([0]),
		_ids([Charm.RADIO_TELESCOPE]), -1, {0: Essence.BACKGROUND_RADIATION}, _p([0]), false,
		_p([0]), {}, 0, 0, _defs([filed]))
	assert_eq(filed.faces, _d([5, 5, 5, 5, 5, 5]))
	assert_true(report.discard_grown, "note_pool_changed hängt genau an dieser Flagge")

func test_a_soulless_hand_grows_nothing():
	var plain := _die([5, 2, 3, 4, 5, 6])
	MaterialEffects.apply_take_effects(_defs([plain]), _p([0]), _m([""]), _p([0]),
		NO_CHARMS, -1, {}, _p([0]), false, _p([0]))
	assert_eq(plain.faces, _d([5, 2, 3, 4, 5, 6]))

func test_the_radiation_lands_on_top_of_the_simulated_running_value():
	# Sie ist ein Schwanz-Schritt wie der Gleichrichter: Knochen und Glas landen
	# exakt auf dem Wert der Simulation, DANN legt die Strahlung ihr +1 drauf.
	for face_material in [DieMaterial.BONE, DieMaterial.GLASS, ""]:
		for echoes in 3:
			var ids := _ids([])
			for _e in echoes:
				ids.append(Charm.ECHO_CHAMBER)
			var die := _die([8, 2, 3, 4, 5, 6], face_material, Essence.BACKGROUND_RADIATION)
			MaterialEffects.apply_take_effects(_defs([die]), _p([0]), _m([face_material]), _p([0]),
				ids, 0, {0: Essence.BACKGROUND_RADIATION}, _p([0]), false, _p([0]))
			var activations := MaterialEffects.total_trigger_count(0, ids, 8, 0,
				_ids([Essence.BACKGROUND_RADIATION]))
			var expected := MaterialEffects.value_after_activations(8, activations, face_material,
				ids, 1, _ids([Essence.BACKGROUND_RADIATION])) + EssenceEffects.BACKGROUND_GROWTH
			assert_eq(die.faces[0], expected,
				"Material '%s', %d Echos" % [face_material, echoes])
			assert_eq(die.faces[1], 2 + EssenceEffects.BACKGROUND_GROWTH,
				"die übrigen Seiten wachsen genau einmal")

# --- Schrittliste: die Zerlegung spiegelt die neue Rechnung 1:1 --------------------

func test_the_breakdown_mirrors_every_new_source():
	var ctx := {
		DiceScoring.CTX_ESSENCES: {0: Essence.CHERENKOV, 1: Essence.FOXFIRE},
		DiceScoring.CTX_CHARGE: 5,
		DiceScoring.CTX_ROUND: 4,
		DiceScoring.CTX_HANDS_TAKEN: 2,
		DiceScoring.CTX_FUMBLES: 1,
		DiceScoring.CTX_DISCARD_SOULS: 2,
		DiceScoring.CTX_DISCARD_VALUES: _d([3, 4, 5]),
		DiceScoring.CTX_FIRST_SCORING: {0: true, 1: true},
		DiceScoring.CTX_POINTER_FIRES: {2: [[]]},
	}
	var ids := _ids([Charm.STANDBY_LIGHT, Charm.ODOMETER, Charm.BOTTLE_RACK, Charm.GROUND_WIRE])
	var dice := _d([5, 5, 5])
	var mats := _m(["", "", ""])
	var breakdown := ScoreBreakdown.build(DiceScoring.THREE_KIND, dice, ids, false, mats, {}, ctx)
	assert_eq(int(breakdown["total"]),
		DiceScoring.score_category(DiceScoring.THREE_KIND, dice, ids, false, mats, {}, ctx))

func test_the_breakdown_mirrors_the_midnight_sun_activations():
	var ctx := {
		DiceScoring.CTX_ESSENCES: {0: Essence.MIDNIGHT_SUN},
		DiceScoring.CTX_HANDS_TAKEN: 2,
	}
	var breakdown := ScoreBreakdown.build(PAIR, _d([5, 5]), NO_CHARMS, false, _m(["", ""]), {}, ctx)
	assert_eq(int(breakdown["total"]),
		DiceScoring.score_category(PAIR, _d([5, 5]), NO_CHARMS, false, _m(["", ""]), {}, ctx))
	var step: Dictionary = breakdown["die_steps"][0]
	assert_eq((step["die_triggers"] as Array).size(), 3, "zwei genommene Hände, drei Antritte")

func test_the_breakdown_mirrors_the_firing_star():
	var ctx := _soul_ctx(Essence.SHOOTING_STAR)
	ctx[DiceScoring.CTX_RUNES] = {0: _ids([Rune.AFTERGLOW])}
	ctx[DiceScoring.CTX_FIRST_SCORING] = {0: true}
	var ids := _ids([Charm.ECHO_CHAMBER])
	var breakdown := ScoreBreakdown.build(PAIR, _d([5, 5]), ids, false, _m(["", ""]), {}, ctx)
	assert_eq(int(breakdown["total"]),
		DiceScoring.score_category(PAIR, _d([5, 5]), ids, false, _m(["", ""]), {}, ctx))
	var step: Dictionary = breakdown["die_steps"][0]
	assert_eq((step["die_triggers"] as Array).size(), 2, "Echo-Kammer: zwei Antritte")
	assert_eq(((step["die_triggers"][0] as Dictionary)["firings"] as Array).size(), 2,
		"Nachglühen: zwei Zündungen je Antritt")
	var slams := 0
	for group: Dictionary in step["die_triggers"]:
		for firing: Dictionary in group["firings"]:
			slams += (firing["crit_steps"] as Array).size()
	assert_eq(slams, 1, "der Strich fällt genau einmal")
