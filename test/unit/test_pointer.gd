extends GutTest
## Die Leiterbahn (Zeiger-Mechanik): Kette am Datensatz, Wertung der Glieder
## (je Glied EINMAL, nach allen Aktivierungen, volle Auslösung mit getauschter
## Seite), Schrittliste und Nehmen-Effekte.

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

## ctx mit Leiterbahn-Gliedern für einen Slot.
func _ctx_links(slot: int, entries: Array) -> Dictionary:
	return {DiceScoring.CTX_POINTER_LINKS: {slot: entries}}

func _link(face: int, value: int, material := "", level := 1) -> Dictionary:
	return {"face": face, "value": value, "material": material, "level": level}

## ctx mit Gliedern UND der würfelweiten Augensumme des Slots.
func _ctx_links_up(slot: int, entries: Array, eye_sum: int) -> Dictionary:
	var ctx := _ctx_links(slot, entries)
	ctx[DiceScoring.CTX_MATERIAL_LEVELS] = {slot: {"level": 1, "eye_sum": eye_sum}}
	return ctx

## ctx mit Gliedern UND einer Argon-Seele auf slot - seit dem Kanten-Umbau die
## Standard-Quelle zweier Auslösungen.
func _ctx_links_argon(slot: int, entries: Array) -> Dictionary:
	var ctx := _ctx_links(slot, entries)
	ctx[DiceScoring.CTX_ESSENCES] = {slot: Essence.ARGON}
	return ctx

# --- Datensatz: Nachbarschaft und Kette ------------------------------------------

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

func test_pointer_chain_walks_and_a_cycle_stops():
	var def := DieDefinition.new()
	assert_eq(def.pointer_chain(3), [] as Array[int], "ohne Zeiger keine Kette")
	def.pointers[3] = 0
	assert_eq(def.pointer_chain(3), [0] as Array[int])
	def.pointers[0] = 4
	assert_eq(def.pointer_chain(3), _d([0, 4]))
	assert_eq(def.pointer_chain(1), [] as Array[int], "Zeiger fremder Seiten bleiben stumm")
	# Zyklus: 0 -> 4 -> 0 endet, jede Seite feuert höchstens einmal.
	def.pointers[4] = 0
	assert_eq(def.pointer_chain(0), _d([4]))

func test_a_full_chain_can_fire_all_six_faces():
	# Hamiltonpfad über die Nachbarschaft: 3 -> 0 -> 1 -> 2 -> 4 -> 5.
	var def := DieDefinition.new()
	def.pointers[3] = 0
	def.pointers[0] = 1
	def.pointers[1] = 2
	def.pointers[2] = 4
	def.pointers[4] = 5
	assert_eq(def.pointer_chain(3), _d([0, 1, 2, 4, 5]))

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

# --- Wertung: Glieder feuern nach den Aktivierungen ------------------------------

func test_a_link_adds_its_eyes_to_the_base():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var plain := DiceScoring.score_category(DiceScoring.TWO_KIND, dice)
	var linked := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, _m([]), {}, _ctx_links(0, [_link(2, 4)]))
	assert_eq(plain, 40, "Paar 5er: (10 + 10) × 2")
	assert_eq(linked, 48, "Glied-Augen 4 heben die Basis: (10 + 10 + 4) × 2")

func test_a_link_fires_its_face_material():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var no_mats := _m(["", "", "", "", "", ""])
	var linked := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_links(0, [_link(2, 4, DieMaterial.AMBER)]))
	assert_eq(linked, 88, "Bernstein des Glieds: (10 + 10 + 4 + 20) × 2")

func test_retriggers_never_rerun_the_chain():
	# Argon verdoppelt die Aktivierungen - die Kette feuert trotzdem EINMAL.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var no_mats := _m(["", "", "", "", "", ""])
	var linked := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_links_argon(0, [_link(2, 4)]))
	assert_eq(linked, 58, "(10 + 5×2 + 5 + 4) × 2 - das Glied zählt nicht doppelt")

func test_a_link_crit_fires_at_the_dies_position():
	# Beherit am niedrigsten gewerteten Würfel (Slot 0): die Aktivierung kritet
	# ×5, das Glied ×3 - BEVOR das Glas von Slot 1 seinen Mult legt. Feuerte das
	# Glied erst am Ende, wäre der Gesamtwert 1035 statt 805.
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m(["", DieMaterial.GLASS, "", "", "", ""])
	var linked := DiceScoring.score_category(DiceScoring.TWO_KIND, dice,
		_ids([Charm.BEHERIT]), false, mats, {}, _ctx_links(0, [_link(2, 3)]))
	assert_eq(linked, 805, "Basis 23 × Mult (2 ×5 ×3 + 5)")

func test_link_values_are_transformed_like_eyes():
	# Glückszigaretten: eine 1 IST eine 6 - auch als Glied.
	var dice := _d([5, 5, 2, 2, 3, 6])
	var linked := DiceScoring.score_category(DiceScoring.TWO_KIND, dice,
		_ids([Charm.LUCKY_CIGARETTES]), false, _m(["", "", "", "", "", ""]),
		{}, _ctx_links(0, [_link(2, 1)]))
	assert_eq(linked, 52, "(10 + 10 + 6) × 2 - das Glied zeigt die verwandelte 6")

func test_best_hand_sees_the_links():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var hand := DiceScoring.best_hand(dice, _ids([]), false, _m([]), {},
		_ctx_links(0, [_link(2, 4)]))
	assert_eq(int(hand["score"]), 48, "Vorschau und Wertung teilen den ctx")

# --- Schrittliste ---------------------------------------------------------------

func test_breakdown_carries_links_and_matches_the_score():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var mats := _m(["", DieMaterial.GLASS, "", "", "", ""])
	var ctx := _ctx_links(0, [_link(2, 3, DieMaterial.AMBER)])
	var ids := _ids([Charm.BEHERIT])
	var breakdown := ScoreBreakdown.build(DiceScoring.TWO_KIND, dice, ids, false, mats, {}, ctx)
	var expected := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, ids, false, mats, {}, ctx)
	assert_eq(int(breakdown["total"]), expected, "Schrittliste spiegelt die Formel")
	var first_step: Dictionary = breakdown["die_steps"][0]
	var links: Array = first_step["links"]
	assert_eq(links.size(), 1, "das Glied hängt am Schritt seines Würfels")
	assert_eq(int(links[0]["face"]), 2)
	assert_eq(String(links[0]["material"]), DieMaterial.AMBER)
	assert_eq(int(links[0]["crit_x"]), 3, "Beherit kritet das Glied mit dessen Wert")
	var second_step: Dictionary = breakdown["die_steps"][1]
	assert_eq((second_step["links"] as Array).size(), 0, "Slot 1 hat keine Kette")

# --- Nehmen-Effekte -------------------------------------------------------------

func _defs(def: DieDefinition) -> Array[DieDefinition]:
	var typed: Array[DieDefinition] = []
	typed.assign([def])
	return typed

func test_a_gold_link_pays_once_and_ignores_retriggers():
	var def := DieDefinition.new()
	def.pointers[0] = 2
	def.materials[2] = DieMaterial.GOLD
	var report := MaterialEffects.apply_take_effects(_defs(def), _d([0]), _m([""]), _d([0]))
	assert_eq(report.money, MaterialEffects.GOLD_PAYOUT, "Gold der Zielseite zahlt einmal")
	# Argon verdoppelt nur die Aktivierungen des Würfels, nie die Kette.
	var argon := DieDefinition.new()
	argon.pointers[0] = 2
	argon.materials[2] = DieMaterial.GOLD
	argon.essence_id = Essence.ARGON
	var mercury_report := MaterialEffects.apply_take_effects(_defs(argon), _d([0]),
		_m([""]), _d([0]), _ids([]), -1, {0: Essence.ARGON}, _d([0]))
	assert_eq(mercury_report.money, MaterialEffects.GOLD_PAYOUT, "das Glied bleibt bei einmal")

func test_bone_and_glass_hit_the_link_face():
	var def := DieDefinition.new()
	def.pointers[0] = 2
	def.materials[2] = DieMaterial.BONE
	var before: int = def.faces[2]
	var report := MaterialEffects.apply_take_effects(_defs(def), _d([0]), _m([""]), _d([0]))
	assert_eq(def.faces[2], before + 1, "Knochen wächst auf der GLIED-Seite")
	assert_true(report.grown.has(0))
	var glass := DieDefinition.new()
	glass.pointers[0] = 2
	glass.materials[2] = DieMaterial.GLASS
	glass.faces[2] = 4
	MaterialEffects.apply_take_effects(_defs(glass), _d([0]), _m([""]), _d([0]))
	assert_eq(glass.faces[2], 3, "Glas schrumpft die GLIED-Seite")

# --- Gesättigte Glieder: die Stufe des GLIEDS zählt, nicht die der oberen Seite ---

## Würfel mit einer Leiterbahn 0 -> 2 und einem Material der Stufe level darauf.
func _linked_die(material: String, level: int, link_value := -1) -> DieDefinition:
	var def := DieDefinition.new()
	def.pointers[0] = 2
	def.set_face_material(2, material)
	def.levels[2] = level
	if link_value >= 0:
		def.faces[2] = link_value
	return def

func test_amber_link_levels_scale_the_eye_sum():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var no_mats := _m(["", "", "", "", "", ""])
	var first := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_links_up(0, [_link(2, 4, DieMaterial.AMBER, 1)], 21))
	var third := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_links_up(0, [_link(2, 4, DieMaterial.AMBER, 3)], 21))
	assert_eq(first, 130, "(10 + 10 + 4 + 20 + 21) × 2")
	assert_eq(third, 258, "(10 + 10 + 4 + 5×21) × 2")

func test_ruby_link_adds_more_on_two_and_crits_on_three():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var no_mats := _m(["", "", "", "", "", ""])
	var plain := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_links(0, [_link(2, 4, DieMaterial.RUBY)]))
	var second := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_links(0, [_link(2, 4, DieMaterial.RUBY, 2)]))
	var third := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_links(0, [_link(2, 4, DieMaterial.RUBY, 3)]))
	assert_eq(plain, 144, "24 × (2 + 4)")
	assert_eq(second, 288, "24 × (2 + 10)")
	assert_eq(third, 96, "24 × (2 ×2)")

func test_glass_link_crits_with_the_link_eyes():
	var dice := _d([5, 5, 1, 2, 3, 6])
	var no_mats := _m(["", "", "", "", "", ""])
	var second := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_links(0, [_link(2, 4, DieMaterial.GLASS, 2)]))
	var third := DiceScoring.score_category(DiceScoring.TWO_KIND, dice, _ids([]),
		false, no_mats, {}, _ctx_links(0, [_link(2, 4, DieMaterial.GLASS, 3)]))
	assert_eq(second, 192, "24 × (2 ×4) - der Krit nimmt die Augen des Glieds")
	assert_eq(third, 576, "24 × ((2 + 4) ×4) - Stufe III addiert UND kritet")

func test_a_gold_link_on_level_three_pays_the_raised_rate():
	var def := _linked_die(DieMaterial.GOLD, 3)
	var report := MaterialEffects.apply_take_effects(_defs(def), _d([0]), _m([""]), _d([0]))
	assert_eq(report.money, 8, "$7 + $1 für die eine Gold-Seite dieser Nahme")

func test_bone_link_levels_grow_by_their_own_step():
	var second := _linked_die(DieMaterial.BONE, 2, 40)
	MaterialEffects.apply_take_effects(_defs(second), _d([0]), _m([""]), _d([0]))
	assert_eq(second.faces[2], 44, "10 % von 40 - und nur EINMAL, Glieder retriggern nie")
	var third := _linked_die(DieMaterial.BONE, 3, 40)
	MaterialEffects.apply_take_effects(_defs(third), _d([0]), _m([""]), _d([0]))
	assert_eq(third.faces[2], 48, "20 % von 40")

func test_a_glass_link_shrinks_by_the_raised_step():
	var def := _linked_die(DieMaterial.GLASS, 2, 40)
	MaterialEffects.apply_take_effects(_defs(def), _d([0]), _m([""]), _d([0]))
	assert_eq(def.faces[2], 32, "20 % von 40")

# --- Plasma: der Lichtbogen hängt zwei Glieder an, Zyklen erlaubt ----------------

func test_plasma_adds_two_links():
	assert_eq(EssenceEffects.extra_pointer_links(Essence.PLASMA), 2)
	assert_eq(EssenceEffects.extra_pointer_links(Essence.NEON), 0)
	assert_eq(EssenceEffects.extra_pointer_links(""), 0)

func test_a_chain_still_stops_at_a_cycle_without_plasma():
	# 0 -> 1 -> 0: ohne Lichtbogen endet die Kette am schon besuchten Glied.
	var def := DieDefinition.new()
	def.pointers[0] = 1
	def.pointers[1] = 0
	assert_eq(def.pointer_chain(0), _d([1]), "ein Zyklus endet einfach")

func test_plasma_walks_the_cycle_further():
	var def := DieDefinition.new()
	def.pointers[0] = 1
	def.pointers[1] = 0
	# Mit +2 läuft der Bogen zwei Glieder über den Zyklus hinaus: 1, 0, 1.
	assert_eq(def.pointer_chain(0, 2), _d([1, 0, 1]))

func test_plasma_extends_a_straight_chain_too():
	var def := DieDefinition.new()
	def.pointers[0] = 1
	def.pointers[1] = 2
	def.pointers[2] = 1  # ab hier pendelt es
	assert_eq(def.pointer_chain(0), _d([1, 2]), "normal endet es am Rücksprung")
	assert_eq(def.pointer_chain(0, 2), _d([1, 2, 1, 2]), "der Bogen pendelt zweimal weiter")

func test_the_chain_can_never_run_away():
	# Harte Schranke: auch mit absurd vielen Zusatzgliedern bleibt sie endlich.
	var def := DieDefinition.new()
	def.pointers[0] = 1
	def.pointers[1] = 0
	assert_lt(def.pointer_chain(0, 999).size(), 1006)

func test_take_effects_walk_the_same_extended_chain():
	# Wertung und Nehmen müssen dieselbe Kette sehen - sonst zahlt Gold anders,
	# als die Vorschau zeigt.
	var def := DieDefinition.new()
	def.essence_id = Essence.PLASMA
	def.pointers[0] = 2
	def.pointers[2] = 0
	def.set_face_material(2, DieMaterial.GOLD)
	var defs: Array[DieDefinition] = [def]
	var report := MaterialEffects.apply_take_effects(defs, _d([0]), _m([""]), _d([0]),
		_ids([]), -1, {0: Essence.PLASMA}, _d([0]))
	# Kette 0 -> 2 -> 0 -> 2 (zwei Zusatzglieder): die Gold-Seite 2 feuert zweimal.
	assert_eq(report.money, MaterialEffects.GOLD_PAYOUT * 2, "das Glied zahlt je Durchlauf")
