extends GutTest
## Tier-1-Tests der Wirkungen, die mit der zweiten Inhalts-Welle dazukamen und
## auf der bestehenden Wertungs-Verdrahtung sitzen: Acetylen/Schneidbrenner,
## Schutzfolie, Leuchtfarbe, Leerer Sockel, Metronom, Stroboskop, Rücklicht,
## Manometer, Lichtsäule/Eisspiegel und das Schwarzlicht-Geld.

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

const NO_CHARMS: Array[String] = []
const NO_MATS: Array[String] = []

## Würfel mit gesetzten Seitenwerten (optional Material auf Seite 0 und Seele).
func _die(faces: Array, face_material := "", essence_id := "") -> DieDefinition:
	var def := DieDefinition.new()
	def.faces = _d(faces)
	if face_material != "":
		def.set_face_material(0, face_material)
	def.essence_id = essence_id
	return def

# --- Acetylen & Schneidbrenner: beide an der Übertaktungs-Stufe ------------------

func test_acetylene_pays_per_combo_level():
	assert_eq(EssenceEffects.combo_level_base_of(_ids([Essence.ACETYLENE]), 3),
		3 * EssenceEffects.ACETYLENE_PER_LEVEL)
	assert_eq(EssenceEffects.combo_level_base_of(_ids([Essence.ACETYLENE]), 0), 0,
		"eine frische Kombination hat keine Stufe")
	assert_eq(EssenceEffects.combo_level_base_of(_ids([Essence.NEON]), 3), 0)

func test_the_cutting_torch_puts_mult_on_the_same_level():
	var soul := _ids([Essence.ACETYLENE])
	assert_eq(EssenceEffects.combo_level_mult_of(soul, 3), 0, "ohne Brenner kein Mult")
	assert_eq(EssenceEffects.combo_level_mult_of(soul, 3, _ids([Charm.CUTTING_TORCH])),
		3 * EssenceEffects.CUTTING_TORCH_PER_LEVEL)
	assert_eq(EssenceEffects.combo_level_mult_of(_ids([Essence.NEON]), 3, _ids([Charm.CUTTING_TORCH])), 0,
		"der Brenner gehört dem Acetylen allein")

func test_acetylene_and_the_torch_land_in_the_score():
	var levels := {DiceScoring.TWO_KIND: 2}
	var soul := {DiceScoring.CTX_ESSENCES: {0: Essence.ACETYLENE}}
	# Paar mit zwei Stufen: 10 + 2×10 Punkte, 2 + 2×2 Mult, dazu 10 Augen.
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), NO_CHARMS, false,
		_m(["", ""]), levels, {}), (30 + 10) * 6)
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), NO_CHARMS, false,
		_m(["", ""]), levels, soul), (30 + 10 + 20) * 6, "+10 Basis je Stufe")
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), _ids([Charm.CUTTING_TORCH]),
		false, _m(["", ""]), levels, soul), (30 + 10 + 20) * (6 + 6), "+3 Mult je Stufe obendrauf")

func test_acetylene_stays_dark_without_an_upgrade():
	var soul := {DiceScoring.CTX_ESSENCES: {0: Essence.ACETYLENE}}
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), NO_CHARMS, false,
		_m(["", ""]), {}, soul), (10 + 10) * 2)

# --- Schutzfolie: der fabrikneue Würfel ------------------------------------------

func test_the_factory_finish_pays_only_bare_dice():
	var ids := _ids([Charm.FACTORY_FINISH])
	var values := _d([5, 5, 5])
	var order := _p([0, 1, 2])
	var mats := _m(["", DieMaterial.GOLD, ""])
	var ctx := {DiceScoring.CTX_ESSENCES: {2: Essence.NEON}}
	assert_eq(CharmEffects.die_charm_base_at(0, 0, DiceScoring.THREE_KIND, values, ids, ctx, order, 0, mats),
		CharmEffects.FACTORY_FINISH_BASE)
	assert_eq(CharmEffects.die_charm_base_at(0, 1, DiceScoring.THREE_KIND, values, ids, ctx, order, 0, mats), 0,
		"eine Material-Seite ist nicht mehr nackt")
	assert_eq(CharmEffects.die_charm_base_at(0, 2, DiceScoring.THREE_KIND, values, ids, ctx, order, 0, mats), 0,
		"eine Seele ist nicht mehr nackt")

func test_a_rune_takes_the_factory_finish_away():
	var ids := _ids([Charm.FACTORY_FINISH])
	var runed := {DiceScoring.CTX_RUNES: {0: _ids([Rune.AFTERGLOW])}}
	assert_eq(CharmEffects.die_charm_base_at(0, 0, DiceScoring.TWO_KIND, _d([5, 5]), ids, runed, _p([0, 1]),
		0, _m(["", ""])), 0)
	assert_eq(CharmEffects.die_charm_base_at(0, 1, DiceScoring.TWO_KIND, _d([5, 5]), ids, runed, _p([0, 1]),
		0, _m(["", ""])), CharmEffects.FACTORY_FINISH_BASE)

func test_the_factory_finish_lands_in_the_score():
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), _ids([Charm.FACTORY_FINISH]),
		false, _m(["", ""]), {}, {}), (10 + 10 + 2 * CharmEffects.FACTORY_FINISH_BASE) * 2)

# --- Leuchtfarbe & Leerer Sockel: statische Mult-Charms --------------------------

func test_luminous_paint_counts_every_rune_of_the_scored_dice():
	var ids := _ids([Charm.LUMINOUS_PAINT])
	var ctx := {DiceScoring.CTX_RUNES: {
		0: _ids([Rune.AFTERGLOW, Rune.SPARK_FLIGHT]),
		1: _ids([Rune.STRAY_LIGHT]),
		2: _ids([Rune.BURN_IN]),
	}}
	assert_eq(CharmEffects.charm_mult_bonus_at(0, DiceScoring.TWO_KIND, _d([5, 5, 3]), NO_MATS, ids, ctx,
		_p([0, 1]), _p([0, 1])), 3 * CharmEffects.LUMINOUS_PAINT_MULT,
		"beide Runen der ersten Seite zählen, die des unbeteiligten Würfels nicht")
	var unscored: Array[int] = []
	assert_eq(CharmEffects.charm_mult_bonus_at(0, DiceScoring.TWO_KIND, _d([5, 5, 3]), NO_MATS, ids, ctx,
		_p([0, 1]), unscored), 0, "ohne gewertete Würfel leuchtet nichts")

func test_the_empty_plinth_pays_for_the_free_spots():
	assert_eq(CharmEffects.charm_mult_bonus_at(0, DiceScoring.TWO_KIND, _d([5, 5]), NO_MATS,
		_ids([Charm.EMPTY_PLINTH])), 5 * CharmEffects.EMPTY_PLINTH_MULT)
	var full := _ids([Charm.EMPTY_PLINTH, Charm.HOUSE_JOKER, Charm.LADYBUG, Charm.HORSESHOE,
		Charm.PEARL_NECKLACE, Charm.FREE_DRINK])
	assert_eq(CharmEffects.charm_mult_bonus_at(0, DiceScoring.TWO_KIND, _d([5, 5]), NO_MATS, full), 0,
		"volles Dock, kein freier Sockel")

func test_the_plinth_mirrors_the_dock_capacity():
	assert_eq(CharmEffects.CHARM_SLOTS, GameRun.CHARM_CAPACITY,
		"core spiegelt die Kapazität, statt in den Laufzustand zu greifen")

# --- Metronom: die Einzelzünder takten sich gegenseitig ---------------------------

func test_the_metronome_counts_up_along_the_row():
	# Der Takt baut sich auf: der erste Einzelzünder zahlt nichts, jeder weitere
	# +6 je Einzelzünder VOR ihm.
	var ids := _ids([Charm.METRONOME])
	var singles := _p([0, 1, 2])
	assert_eq(CharmEffects.metronome_base(0, singles, ids), 0, "der erste gibt den Takt nur vor")
	assert_eq(CharmEffects.metronome_base(1, singles, ids), CharmEffects.METRONOME_BASE)
	assert_eq(CharmEffects.metronome_base(2, singles, ids), 2 * CharmEffects.METRONOME_BASE)
	assert_eq(CharmEffects.metronome_base(3, singles, ids), 0, "wer mehrfach zündet, taktet nicht mit")
	assert_eq(CharmEffects.metronome_base(0, _p([0]), ids), 0, "allein schlägt kein Takt")
	assert_eq(CharmEffects.metronome_base(2, singles, _ids([Charm.METRONOME, Charm.METRONOME])),
		4 * CharmEffects.METRONOME_BASE, "je Exemplar erneut")

func test_a_retriggered_die_leaves_the_metronome():
	var ids := _ids([Charm.METRONOME, Charm.RABBITS_FOOT])
	assert_eq(DiceScoring.single_trigger_slots(_p([0, 1]), _d([6, 5]), ids, {}, -1, -1), _p([1]),
		"die Hasenpfoten-6 zündet zweimal und fällt aus dem Takt")

func test_the_metronome_lands_in_the_score():
	# Drei Einzelzünder in der Reihe: 0 + 6 + 12 = 18 Basispunkte.
	assert_eq(DiceScoring.score_category(DiceScoring.THREE_KIND, _d([5, 5, 5]), _ids([Charm.METRONOME]),
		false, _m(["", "", ""]), {}, {}), (18 + 15 + 18) * 3)

# --- Stroboskop: jede weitere Zündung desselben Würfels ---------------------------

func test_the_strobe_grows_with_every_further_firing():
	var ids := _ids([Charm.STROBE])
	assert_eq(CharmEffects.strobe_mult(0, ids), 0, "die erste Zündung bleibt dunkel")
	assert_eq(CharmEffects.strobe_mult(1, ids), CharmEffects.STROBE_MULT)
	assert_eq(CharmEffects.strobe_mult(3, ids), 3 * CharmEffects.STROBE_MULT)
	assert_eq(CharmEffects.strobe_mult(3, _ids([Charm.STROBE, Charm.STROBE])),
		6 * CharmEffects.STROBE_MULT, "je Exemplar erneut")

func test_the_strobe_lands_in_the_score():
	var ctx := {DiceScoring.CTX_ESSENCES: {0: Essence.ARGON}}
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), NO_CHARMS, false,
		_m(["", ""]), {}, ctx), (10 + 15) * 2)
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), _ids([Charm.STROBE]), false,
		_m(["", ""]), {}, ctx), (10 + 15) * (2 + 2), "die zweite Argon-Zündung legt +2 Mult drauf")

# --- Rücklicht: das Schlusslicht der Zählreihenfolge ------------------------------

func test_hand_shape_names_the_tail_of_the_row():
	var shape := DiceScoring.hand_shape(DiceScoring.TWO_KIND, _d([5, 5, 2]), NO_CHARMS, {})
	assert_eq(shape["echo_slot"], 0)
	assert_eq(shape["tail_slot"], 1, "Schluss der Reihe, nicht größter Slot")

func test_the_tail_light_fires_the_last_die_again():
	var ids := _ids([Charm.TAIL_LIGHT])
	assert_eq(MaterialEffects.die_trigger_count(1, ids, -1, _ids([]), false, 0, 0, 1), 2)
	assert_eq(MaterialEffects.die_trigger_count(0, ids, -1, _ids([]), false, 0, 0, 1), 1,
		"nur das Schlusslicht")

func test_a_single_die_is_head_and_tail_at_once():
	var ids := _ids([Charm.TAIL_LIGHT, Charm.ECHO_CHAMBER])
	assert_eq(MaterialEffects.die_trigger_count(0, ids, 0, _ids([]), false, 0, 0, 0), 3,
		"eine Hand aus einem Würfel bekommt beide Zugaben")

func test_the_tail_light_lands_in_the_score():
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), NO_CHARMS, false,
		_m(["", ""]), {}, {}), (10 + 10) * 2)
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), _ids([Charm.TAIL_LIGHT]), false,
		_m(["", ""]), {}, {}), (10 + 15) * 2)

# --- Manometer: die SEELE des einzigen beseelten Würfels wirkt doppelt -------------

func test_the_pressure_gauge_doubles_the_only_soul_in_the_hand():
	var order := _p([0, 1, 2])
	var ids := _ids([Charm.PRESSURE_GAUGE])
	var one := {1: Essence.NEON}
	assert_eq(EssenceEffects.essence_repeat_count(1, order, one, ids), 2)
	assert_eq(EssenceEffects.essence_repeat_count(0, order, one, ids), 1, "der seelenlose bleibt einfach")
	assert_eq(EssenceEffects.essence_repeat_count(1, order, one, NO_CHARMS), 1, "ohne Charm kein Druck")
	assert_eq(EssenceEffects.essence_repeat_count(1, order, one,
		_ids([Charm.PRESSURE_GAUGE, Charm.PRESSURE_GAUGE])), 3, "je Exemplar einmal mehr")
	# Der WÜRFEL tritt weiter einfach an - es ist die Seele, die doppelt wirkt.
	assert_eq(EssenceEffects.extra_activations(1, order, one, ids), 0)

func test_a_second_soul_lets_the_pressure_out():
	var order := _p([0, 1, 2])
	var ids := _ids([Charm.PRESSURE_GAUGE])
	var two := {1: Essence.NEON, 2: Essence.XENON}
	assert_eq(EssenceEffects.essence_repeat_count(1, order, two, ids), 1)
	assert_eq(EssenceEffects.essence_repeat_count(2, order, two, ids), 1)

func test_the_pressure_gauge_slams_the_essence_crit_twice():
	# Xenon ×1,5 zweimal geschlagen = ×2,25 - nie einmal quadriert und nie ×3.
	var ctx := {DiceScoring.CTX_ESSENCES: {0: Essence.XENON}}
	var ids := _ids([Charm.PRESSURE_GAUGE])
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), ids, false,
		_m(["", ""]), {}, ctx), ceili(20.0 * 2.0 * 1.5 * 1.5))
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), NO_CHARMS, false,
		_m(["", ""]), {}, ctx), ceili(20.0 * 2.0 * 1.5), "ohne Manometer ein Schlag")

func test_the_pressure_gauge_doubles_the_essence_money():
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6], "", Essence.NEON)]
	var sets := {0: _ids([Essence.NEON])}
	var lone := MaterialEffects.apply_take_effects(defs, _p([0]), _m([""]), _p([0]),
		_ids([Charm.PRESSURE_GAUGE]), -1, sets, _p([0]))
	assert_eq(lone.total_money(), 2 * EssenceEffects.NEON_MONEY_PER_DIE, "die Seele zahlt zweimal")
	var plain_defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6], "", Essence.NEON)]
	var plain := MaterialEffects.apply_take_effects(plain_defs, _p([0]), _m([""]), _p([0]),
		NO_CHARMS, -1, sets, _p([0]))
	assert_eq(plain.total_money(), EssenceEffects.NEON_MONEY_PER_DIE)

func test_the_pressure_gauge_doubles_the_face_growth_in_sim_and_def():
	# Helium hebt die obere Seite je Auslösung - unter Druck zweimal, und die Def
	# landet auf genau der Zahl, die die Simulation gezählt hat.
	var sets := {0: _ids([Essence.HELIUM])}
	var ids := _ids([Charm.PRESSURE_GAUGE])
	var defs: Array[DieDefinition] = [_die([5, 2, 3, 4, 5, 6], "", Essence.HELIUM)]
	MaterialEffects.apply_take_effects(defs, _p([0]), _m([""]), _p([0]), ids, -1, sets, _p([0]))
	assert_eq(defs[0].faces[0], 5 + 2 * EssenceEffects.HELIUM_GROWTH)
	assert_eq(MaterialEffects.mutate_value_once(5, "", ids, 1, _ids([Essence.HELIUM]), _ids([]), 2),
		5 + 2 * EssenceEffects.HELIUM_GROWTH, "dieselbe Rechnung wie die Simulation")

# --- Lichtsäule & Eisspiegel: die Gleichzahlen ------------------------------------

func test_the_light_pillar_fans_every_other_die_with_its_value():
	var order := _p([0, 1, 2])
	var values := _d([5, 5, 3])
	var sets := {0: Essence.LIGHT_PILLAR}
	assert_eq(EssenceEffects.extra_activations(1, order, sets, NO_CHARMS, values),
		EssenceEffects.LIGHT_PILLAR_ACTIVATIONS)
	assert_eq(EssenceEffects.extra_activations(2, order, sets, NO_CHARMS, values), 0,
		"eine andere Augenzahl geht leer aus")
	assert_eq(EssenceEffects.extra_activations(0, order, sets, NO_CHARMS, values), 0,
		"nie die Säule selbst")
	assert_eq(EssenceEffects.extra_activations(1, order, sets, NO_CHARMS), 0,
		"ohne Werte kein Vergleich")

func test_the_ice_mirror_doubles_the_pillar():
	var order := _p([0, 1])
	var values := _d([5, 5])
	var sets := {0: Essence.LIGHT_PILLAR}
	assert_eq(EssenceEffects.extra_activations(1, order, sets, _ids([Charm.ICE_MIRROR]), values),
		EssenceEffects.LIGHT_PILLAR_ACTIVATIONS_MIRRORED)

func test_the_light_pillar_lands_in_the_score():
	var ctx := {DiceScoring.CTX_ESSENCES: {0: Essence.LIGHT_PILLAR}}
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), NO_CHARMS, false,
		_m(["", ""]), {}, ctx), (10 + 15) * 2, "der Mitwürfel tritt zweimal an")
	assert_eq(DiceScoring.score_category(DiceScoring.TWO_KIND, _d([5, 5]), _ids([Charm.ICE_MIRROR]), false,
		_m(["", ""]), {}, ctx), (10 + 20) * 2, "mit Spiegel dreimal")

# --- Schwarzlicht: Geld beim Nehmen -----------------------------------------------

func test_black_light_pays_for_every_bare_die():
	var die := DieDefinition.standard()
	die.essence_id = Essence.BLACK_LIGHT
	var mate := DieDefinition.standard()
	var golden := DieDefinition.standard()
	golden.set_face_material(0, DieMaterial.GOLD)
	var defs: Array[DieDefinition] = [die, mate, golden]
	var report := MaterialEffects.apply_take_effects(defs, _p([0, 0, 0]),
		_m(["", "", DieMaterial.GOLD]), _p([0, 1, 2]), NO_CHARMS, -1,
		{0: Essence.BLACK_LIGHT}, _p([0, 1, 2]))
	assert_eq(report.total_money(), 2 * EssenceEffects.BLACK_LIGHT_PER_DIE + MaterialEffects.GOLD_PAYOUT,
		"zwei materiallose Würfel, dazu die Gold-Seite selbst")

func test_black_light_pays_once_per_take_not_per_activation():
	var die := DieDefinition.standard()
	die.essence_id = Essence.BLACK_LIGHT
	var defs: Array[DieDefinition] = [die]
	var report := MaterialEffects.apply_take_effects(defs, _p([0]), _m([""]), _p([0]),
		_ids([Charm.ECHO_CHAMBER]), 0, {0: Essence.BLACK_LIGHT}, _p([0]))
	assert_eq(report.money, EssenceEffects.BLACK_LIGHT_PER_DIE,
		"die Echo-Kammer verdoppelt die Auslösung, nicht das Geld")

func test_a_soulless_die_never_sees_the_black_light():
	assert_eq(EssenceEffects.bare_die_money_of(_ids([Essence.NEON]), 3), 0)
	assert_eq(EssenceEffects.bare_die_money_of(_ids([Essence.BLACK_LIGHT]), 0), 0)
