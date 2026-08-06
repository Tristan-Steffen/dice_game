extends GutTest
## Die Leiterbahn (Zeiger-Mechanik): Verdrahtung am Datensatz, der Chance-Wurf
## (einmal je Würfel-Trigger, Sprung für Sprung weiter), die Wertung der
## gezündeten Glieder, Schrittliste und Nehmen-Effekte.

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

func _link(face: int, value: int, material := "", level := 1) -> Dictionary:
	return {"face": face, "value": value, "material": material, "level": level}

## Eingefrorener Wurf: ein Würfel-Trigger, der genau diese Glieder gezündet hat.
func _fires(slot: int, entries: Array) -> Dictionary:
	return {slot: [entries]}

## ctx mit einem eingefrorenen Wurf (die Wertung würfelt nie selbst).
func _ctx_fires(slot: int, entries: Array) -> Dictionary:
	return {DiceScoring.CTX_POINTER_FIRES: _fires(slot, entries)}

## ctx mit Gliedern UND der würfelweiten Augensumme des Slots.
func _ctx_fires_up(slot: int, entries: Array, eye_sum: int) -> Dictionary:
	var ctx := _ctx_fires(slot, entries)
	ctx[DiceScoring.CTX_MATERIAL_LEVELS] = {slot: {"level": 1, "eye_sum": eye_sum}}
	return ctx

## ctx mit einer Argon-Seele auf slot (zwei Würfel-Trigger) und je Trigger einer
## eigenen Glieder-Gruppe - genau so friert der Zug den Wurf ein.
func _ctx_fires_argon(slot: int, groups: Array) -> Dictionary:
	var ctx := {DiceScoring.CTX_POINTER_FIRES: {slot: groups}}
	ctx[DiceScoring.CTX_ESSENCES] = {slot: Essence.ARGON}
	return ctx

## Ein RNG, dessen ERSTER Wurf sicher trifft bzw. sicher danebengeht - so braucht
## kein Test einen magischen Seed. null, wenn keiner gefunden wurde.
func _rng_first(hit: bool, threshold := DiceScoring.POINTER_CHANCE) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	for s in 500:
		rng.seed = s
		if (rng.randf() < threshold) == hit:
			rng.seed = s  # zurückspulen
			return rng
	return null

## Ein RNG, dessen erste beiden Würfe treffen.
func _rng_two_hits() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	for s in 500:
		rng.seed = s
		if rng.randf() < DiceScoring.POINTER_CHANCE and rng.randf() < DiceScoring.POINTER_CHANCE:
			rng.seed = s
			return rng
	return null

# --- Datensatz: Nachbarschaft und Verdrahtung ------------------------------------

func test_opposite_and_adjacency():
	assert_eq(DieDefinition.opposite_face(0), 5)
	assert_eq(DieDefinition.opposite_face(2), 3)
	var def := DieDefinition.new()
	assert_false(def.can_point(0, 0), "nie auf sich selbst")
	assert_false(def.can_point(0, 5), "nie auf die Gegenseite")
	assert_false(def.can_point(0, 6), "außerhalb des Würfels")
	for neighbor in DieDefinition.adjacent_faces(0):
		assert_true(def.can_point(0, neighbor), "Nachbar %d ist gültig" % neighbor)
	assert_eq(DieDefinition.adjacent_faces(0).size(), 4)

func test_pointer_target_reads_the_wiring():
	var def := DieDefinition.new()
	assert_eq(def.pointer_target(3), -1, "ohne Zeiger kein Ziel")
	def.pointers[3] = 0
	assert_eq(def.pointer_target(3), 0)
	assert_eq(def.pointer_target(1), -1, "Zeiger fremder Seiten bleiben stumm")
	assert_eq(def.pointer_target(9), -1, "außerhalb des Würfels")

func test_instantiate_and_become_copy_pointers():
	var def := DieDefinition.new()
	def.pointers[3] = 0
	var copy := def.instantiate()
	assert_eq(copy.pointers[3], 0)
	copy.pointers[3] = 4
	assert_eq(def.pointers[3], 0, "die Kopie ist unabhängig")
	var host := DieDefinition.new()
	host.become(def)
	assert_eq(host.pointers[3], 0)
	host.pointers[3] = -1
	assert_eq(def.pointers[3], 0, "become teilt kein Array")

# --- Die Chance -----------------------------------------------------------------

func test_the_aggregated_chance_grows_with_the_face_triggers():
	assert_almost_eq(DiceScoring.pointer_chance_for(0.5, 1), 0.5, 0.0001)
	assert_almost_eq(DiceScoring.pointer_chance_for(0.5, 2), 0.75, 0.0001)
	assert_almost_eq(DiceScoring.pointer_chance_for(0.5, 3), 0.875, 0.0001)
	assert_almost_eq(DiceScoring.pointer_chance_for(0.5, 0), 0.5, 0.0001, "mindestens eine Zündung")

func test_plasma_gives_the_pointer_a_second_shot():
	var base := DiceScoring.POINTER_CHANCE
	assert_almost_eq(EssenceEffects.pointer_chance_of(_ids([]), base), 0.5, 0.0001)
	assert_almost_eq(EssenceEffects.pointer_chance_of(_ids([Essence.PLASMA]), base), 0.75, 0.0001,
		"zwei Versuche: aus 50 % werden 75 %")
	assert_almost_eq(EssenceEffects.pointer_chance_of(_ids([Essence.PLASMA]), 0.3), 0.51, 0.0001)
	assert_lt(EssenceEffects.pointer_chance_of(_ids([Essence.PLASMA]), 0.9), 1.0,
		"eine Leiterbahn zündet NIE sicher")
	assert_almost_eq(EssenceEffects.pointer_chance_of(_ids([Essence.NEON]), base), 0.5, 0.0001)
	# Auch aggregiert bleibt der Lichtbogen vorn.
	assert_almost_eq(DiceScoring.pointer_chance_for(0.75, 2), 0.9375, 0.0001)

# --- Der Wurf -------------------------------------------------------------------

func _pointer_die() -> DieDefinition:
	var def := DieDefinition.new()
	def.pointers[0] = 2
	return def

func test_a_failed_roll_fires_nothing():
	var rng := _rng_first(false)
	assert_not_null(rng, "ein Fehlwurf-Seed muss auffindbar sein")
	var groups := DiceScoring.roll_pointer_fires(_pointer_die(), 0, 1, 1, _ids([]), _ids([]), rng)
	assert_eq(groups.size(), 1, "je Würfel-Trigger eine Gruppe")
	assert_eq((groups[0] as Array).size(), 0, "danebengegangen heißt: leere Gruppe")

func test_a_hit_fires_the_target_face_once():
	var rng := _rng_first(true)
	assert_not_null(rng)
	var groups := DiceScoring.roll_pointer_fires(_pointer_die(), 0, 1, 1, _ids([]), _ids([]), rng)
	var fires: Array = groups[0]
	assert_eq(fires.size(), 1, "ein Treffer zündet genau ein Glied")
	assert_eq(int(fires[0]["face"]), 2)
	assert_eq(int(fires[0]["value"]), 3, "Seite 2 zeigt eine 3")

func test_every_die_trigger_rolls_on_its_own():
	var rng := _rng_two_hits()
	assert_not_null(rng)
	var groups := DiceScoring.roll_pointer_fires(_pointer_die(), 0, 2, 1, _ids([]), _ids([]), rng)
	assert_eq(groups.size(), 2, "zwei Würfel-Trigger, zwei Würfe")
	for group in groups:
		assert_lte((group as Array).size(), 1, "ohne Anschluss-Zeiger höchstens ein Glied")

func test_a_die_without_a_pointer_never_fires():
	var rng := _rng_first(true)
	var groups := DiceScoring.roll_pointer_fires(DieDefinition.new(), 0, 3, 2, _ids([]), _ids([]), rng)
	for group in groups:
		assert_eq((group as Array).size(), 0, "ohne Verdrahtung passiert nichts")

func test_a_pointer_loop_stays_under_the_cap():
	# 0 -> 1 -> 0: die Kette darf kreisen, die Schranke hält sie endlich.
	var def := DieDefinition.new()
	def.pointers[0] = 1
	def.pointers[1] = 0
	for s in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var groups := DiceScoring.roll_pointer_fires(def, 0, 1, 1, _ids([]), _ids([]), rng)
		assert_lte((groups[0] as Array).size(), DiceScoring.POINTER_HOP_CAP)

func test_the_same_seed_rolls_the_same_fires():
	var def := DieDefinition.new()
	def.pointers[0] = 1
	def.pointers[1] = 2
	var first := RandomNumberGenerator.new()
	first.seed = 4711
	var second := RandomNumberGenerator.new()
	second.seed = 4711
	assert_eq(DiceScoring.roll_pointer_fires(def, 0, 3, 2, _ids([]), _ids([]), first),
		DiceScoring.roll_pointer_fires(def, 0, 3, 2, _ids([]), _ids([]), second))

func test_a_twice_fired_bone_link_counts_the_grown_value():
	var rng := _rng_two_hits()
	assert_not_null(rng)
	var def := _pointer_die()
	def.set_face_material(2, DieMaterial.BONE)
	def.faces[2] = 4
	var groups := DiceScoring.roll_pointer_fires(def, 0, 2, 1, _ids([]), _ids([]), rng)
	assert_eq(int((groups[0] as Array)[0]["value"]), 4, "erste Zündung: der gedruckte Wert")
	assert_eq(int((groups[1] as Array)[0]["value"]), 6, "zweite Zündung: der gewachsene")

# --- Wertung: gezündete Glieder --------------------------------------------------

func test_a_link_adds_its_eyes_to_the_base():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var plain := DiceScoring.score_category(DiceScoring.TWO_KIND, dice)
	var linked := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, _m([]), {}, _ctx_fires(0, [_link(2, 4)]))
	assert_eq(plain, 40, "Paar 5er: (10 + 10) × 2")
	assert_eq(linked, 48, "Glied-Augen 4 heben die Basis: (10 + 10 + 4) × 2")

func test_a_link_fires_its_face_material():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var no_mats := _m(["", "", "", "", "", ""])
	var linked := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_fires(0, [_link(2, 4, DieMaterial.AMBER)]))
	assert_eq(linked, 88, "Bernstein des Glieds: (10 + 10 + 4 + 20) × 2")

func test_each_die_trigger_carries_only_its_own_fires():
	# Argon tritt zweimal an; der Wurf des zweiten Antritts ging daneben.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var no_mats := _m(["", "", "", "", "", ""])
	var once := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_fires_argon(0, [[_link(2, 4)], []]))
	var twice := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_fires_argon(0, [[_link(2, 4)], [_link(2, 4)]]))
	assert_eq(once, 58, "(10 + 5×2 + 5 + 4) × 2 - ein Fehlwurf zündet nichts")
	assert_eq(twice, 66, "(10 + 5×2 + 5 + 4 + 4) × 2 - beide Antritte trafen")

func test_a_link_crit_fires_at_the_dies_position():
	# Beherit am niedrigsten gewerteten Würfel (Slot 0): die Zündung kritet ×1,5,
	# das Glied ×1,3 - BEVOR das Glas von Slot 1 seinen Mult legt. Feuerte das
	# Glied erst am Ende, läge der Gesamtwert höher.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m(["", DieMaterial.GLASS, "", "", "", ""])
	var linked := DiceScoring.score_category(DiceScoring.TWO_KIND, dice,
		_ids([Charm.BEHERIT]), false, mats, {}, _ctx_fires(0, [_link(2, 3)]))
	assert_eq(linked, 205, "Basis 23 × Mult (2 ×1,5 ×1,3 + 5)")

func test_link_values_are_transformed_like_eyes():
	# Glückszigaretten: eine 1 IST eine 6 - auch als Glied.
	var dice := _d([5, 5, 2, 2, 3, 6])
	var linked := DiceScoring.score_category(DiceScoring.TWO_KIND, dice,
		_ids([Charm.LUCKY_CIGARETTES]), false, _m(["", "", "", "", "", ""]),
		{}, _ctx_fires(0, [_link(2, 1)]))
	assert_eq(linked, 52, "(10 + 10 + 6) × 2 - das Glied zeigt die verwandelte 6")

func test_the_preview_scores_without_the_pointer():
	# Ohne den eingefrorenen Wurf fehlt der Schlüssel - die Vorschau zeigt die
	# Hand ohne Leiterbahn, das Nehmen legt sie drauf.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var preview := DiceScoring.best_hand(dice, _ids([]), false, _m([]), {}, {})
	var taken := DiceScoring.best_hand(dice, _ids([]), false, _m([]), {},
		_ctx_fires(0, [_link(2, 4)]))
	assert_eq(int(preview["score"]), 40)
	assert_eq(int(taken["score"]), 48)

func test_the_frozen_roll_scores_the_same_twice():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var ctx := _ctx_fires(0, [_link(2, 4, DieMaterial.AMBER)])
	var first := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]), false, _m([]), {}, ctx)
	var second := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]), false, _m([]), {}, ctx)
	assert_eq(first, second, "derselbe eingefrorene Wurf, dasselbe Ergebnis")

# --- Schrittliste ---------------------------------------------------------------

func test_breakdown_carries_links_and_matches_the_score():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m(["", DieMaterial.GLASS, "", "", "", ""])
	var ctx := _ctx_fires(0, [_link(2, 3, DieMaterial.AMBER)])
	var ids := _ids([Charm.BEHERIT])
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, dice, ids, false, mats, {}, ctx)
	var expected := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, ids, false, mats, {}, ctx)
	assert_eq(int(breakdown["total"]), expected, "Schrittliste spiegelt die Formel")
	var first_step: Dictionary = breakdown["die_steps"][0]
	var groups: Array = first_step["die_triggers"]
	assert_eq(groups.size(), 1, "ein Würfel-Trigger, eine Gruppe")
	var links: Array = groups[0]["links"]
	assert_eq(links.size(), 1, "das Glied hängt am Trigger seines Würfels")
	assert_eq(int(links[0]["face"]), 2)
	assert_eq(String(links[0]["material"]), DieMaterial.AMBER)
	assert_almost_eq(float(links[0]["crit_x"]), 1.3, 0.0001, "Beherit kritet das Glied mit dessen Wert")
	var second_step: Dictionary = breakdown["die_steps"][1]
	var second_groups: Array = second_step["die_triggers"]
	assert_eq((second_groups[0]["links"] as Array).size(), 0, "Slot 1 hat nichts gezündet")

# --- Nehmen-Effekte -------------------------------------------------------------

func _defs(def: DieDefinition) -> Array[DieDefinition]:
	var typed: Array[DieDefinition] = []
	typed.assign([def])
	return typed

## Nehmen-Effekte für EINEN Würfel mit eingefrorenem Wurf.
func _take(def: DieDefinition, fires: Dictionary, essences := {}) -> MaterialEffects.TakeReport:
	return MaterialEffects.apply_take_effects(_defs(def), _d([0]), _m([""]), _d([0]),
		_ids([]), -1, essences, _d([0]), false, _d([]), fires)

func test_a_gold_link_pays_per_fired_occurrence():
	var def := DieDefinition.new()
	def.pointers[0] = 2
	def.materials[2] = DieMaterial.GOLD
	var report := _take(def, _fires(0, [_link(2, 3)]))
	assert_eq(report.total_money(), MaterialEffects.GOLD_PAYOUT, "eine Zündung, ein Satz")
	var twice := DieDefinition.new()
	twice.pointers[0] = 2
	twice.materials[2] = DieMaterial.GOLD
	twice.essence_id = Essence.ARGON
	var argon_report := MaterialEffects.apply_take_effects(_defs(twice), _d([0]), _m([""]), _d([0]),
		_ids([]), -1, {0: Essence.ARGON}, _d([0]), false, _d([]),
		{0: [[_link(2, 3)], [_link(2, 3)]]})
	assert_eq(argon_report.total_money(), MaterialEffects.GOLD_PAYOUT * 2, "zwei Zündungen, zwei Sätze")

func test_a_roll_that_missed_pays_nothing():
	var def := DieDefinition.new()
	def.pointers[0] = 2
	def.materials[2] = DieMaterial.GOLD
	var report := _take(def, _fires(0, []))
	assert_eq(report.money, 0, "ohne Zündung kein Gold - die Verdrahtung allein zahlt nie")
	assert_eq(def.faces[2], 3, "und die Seite bleibt unberührt")

func test_bone_and_glass_hit_the_link_face():
	var def := DieDefinition.new()
	def.pointers[0] = 2
	def.materials[2] = DieMaterial.BONE
	var before: int = def.faces[2]
	var report := _take(def, _fires(0, [_link(2, before, DieMaterial.BONE)]))
	assert_eq(def.faces[2], before + 2, "Knochen wächst auf der GLIED-Seite")
	assert_true(report.grown.has(0))
	var glass := DieDefinition.new()
	glass.pointers[0] = 2
	glass.materials[2] = DieMaterial.GLASS
	glass.faces[2] = 4
	_take(glass, _fires(0, [_link(2, 4, DieMaterial.GLASS)]))
	assert_eq(glass.faces[2], 3, "Glas schrumpft die GLIED-Seite")

func test_a_twice_fired_bone_link_lands_where_the_simulation_counted():
	# Drift-Doktrin: der eingefrorene Wurf und die Def müssen auf demselben Wert
	# enden - sonst zählt die Animation etwas anderes, als der Würfel danach zeigt.
	var def := _pointer_die()
	def.set_face_material(2, DieMaterial.BONE)
	def.faces[2] = 4
	var rng := _rng_two_hits()
	assert_not_null(rng)
	var groups := DiceScoring.roll_pointer_fires(def, 0, 2, 1, _ids([]), _ids([]), rng)
	var last_counted := int((groups[1] as Array)[0]["value"])
	MaterialEffects.apply_take_effects(_defs(def), _d([0]), _m([""]), _d([0]),
		_ids([]), -1, {0: Essence.ARGON}, _d([0]), false, _d([]), {0: groups})
	assert_eq(def.faces[2], last_counted + 2, "die Def steht eine Wandlung hinter der letzten Zählung")

func test_both_axes_and_the_link_land_where_the_roll_counted():
	# Argon (zwei Antritte) auf einem Knochen-Würfel, dessen Leiterbahn beide Male
	# zündet: obere Seite UND Glied-Seite müssen genau dort stehen, wo der
	# eingefrorene Wurf gezählt hat - sonst zeigt der Würfel eine andere Zahl.
	var rng := _rng_two_hits()
	assert_not_null(rng)
	var def := _pointer_die()
	def.set_face_material(0, DieMaterial.BONE)
	def.set_face_material(2, DieMaterial.BONE)
	def.faces[0] = 20
	def.faces[2] = 20
	def.essence_id = Essence.ARGON
	var groups := DiceScoring.roll_pointer_fires(def, 0, 2, 1, _ids([]), _ids([Essence.ARGON]), rng)
	assert_eq((groups[0] as Array).size() + (groups[1] as Array).size(), 2, "beide Antritte trafen")
	assert_eq(int((groups[0] as Array)[0]["value"]), 20, "erste Zündung: der gedruckte Wert")
	assert_eq(int((groups[1] as Array)[0]["value"]), 22, "zweite Zündung: der gewachsene")
	MaterialEffects.apply_take_effects(_defs(def), _d([0]), _m([DieMaterial.BONE]), _d([0]),
		_ids([]), -1, {0: Essence.ARGON}, _d([0]), false, _d([]), {0: groups})
	assert_eq(def.faces[0], 24, "obere Seite: zwei Zündungen, je +2")
	assert_eq(def.faces[2], 24, "Glied-Seite: zwei Zündungen, je +2")

# --- Dotierte Glieder: der Zustand des GLIEDS zählt, nicht der der oberen Seite ---

## Würfel mit einer Leiterbahn 0 -> 2 und einem Material im Zustand level darauf.
func _linked_die(material: String, level: int, link_value := -1) -> DieDefinition:
	var def := DieDefinition.new()
	def.pointers[0] = 2
	def.set_face_material(2, material)
	def.levels[2] = level
	if link_value >= 0:
		def.faces[2] = link_value
	return def

func test_amber_link_doping_scales_the_eye_sum():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var no_mats := _m(["", "", "", "", "", ""])
	var plain := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_fires_up(0, [_link(2, 4, DieMaterial.AMBER, 1)], 21))
	var doped := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_fires_up(0, [_link(2, 4, DieMaterial.AMBER, DieMaterial.MAX_LEVEL)], 21))
	assert_eq(plain, 130, "(10 + 10 + 4 + 20 + 21) × 2")
	assert_eq(doped, 258, "(10 + 10 + 4 + 5×21) × 2")

func test_a_ruby_link_crits_when_doped():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var no_mats := _m(["", "", "", "", "", ""])
	var plain := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_fires(0, [_link(2, 4, DieMaterial.RUBY)]))
	var doped := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_fires(0, [_link(2, 4, DieMaterial.RUBY, DieMaterial.MAX_LEVEL)]))
	assert_eq(plain, 144, "24 × (2 + 4)")
	assert_eq(doped, 96, "24 × (2 ×2)")

func test_a_glass_link_crits_when_doped():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var no_mats := _m(["", "", "", "", "", ""])
	var plain := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_fires(0, [_link(2, 4, DieMaterial.GLASS)]))
	var doped := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_fires(0, [_link(2, 4, DieMaterial.GLASS, DieMaterial.MAX_LEVEL)]))
	assert_eq(plain, 144, "24 × (2 + 4)")
	assert_eq(doped, 96, "24 × (2 ×2) - der Krit nimmt die halben Augen des Glieds")

func test_a_doped_gold_link_pays_the_raised_rate():
	var def := _linked_die(DieMaterial.GOLD, DieMaterial.MAX_LEVEL)
	var report := _take(def, _fires(0, [_link(2, 3, DieMaterial.GOLD, DieMaterial.MAX_LEVEL)]))
	assert_eq(report.total_money(), 8, "$7 + $1 für die eine Gold-Seite dieser Nahme")

func test_bone_link_grows_by_its_own_step():
	var plain := _linked_die(DieMaterial.BONE, 1, 40)
	_take(plain, _fires(0, [_link(2, 40, DieMaterial.BONE)]))
	assert_eq(plain.faces[2], 42, "normal wächst flach +2 - eine Zündung, ein Schritt")
	var doped := _linked_die(DieMaterial.BONE, DieMaterial.MAX_LEVEL, 40)
	_take(doped, _fires(0, [_link(2, 40, DieMaterial.BONE, DieMaterial.MAX_LEVEL)]))
	assert_eq(doped.faces[2], 50, "20 % von 40 wären 8 - die Untergrenze +10 greift")

func test_a_glass_link_shrinks_by_its_own_step():
	var plain := _linked_die(DieMaterial.GLASS, 1, 40)
	_take(plain, _fires(0, [_link(2, 40, DieMaterial.GLASS)]))
	assert_eq(plain.faces[2], 39, "normal frisst flach 1")
	var doped := _linked_die(DieMaterial.GLASS, DieMaterial.MAX_LEVEL, 40)
	_take(doped, _fires(0, [_link(2, 40, DieMaterial.GLASS, DieMaterial.MAX_LEVEL)]))
	assert_eq(doped.faces[2], 20, "dotiert halbiert sich")
