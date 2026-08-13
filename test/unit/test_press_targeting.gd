extends GutTest
## Tier-1-Tests der Ziel-Logik der Platzierung (PressTargeting): Ziel-Form je
## Gravur, Eignung je Seite im aktuellen Schritt und der Vorschau-Klon. Reine
## Regel, kein Node - die Werkbank führt nur die Klicks.

func _die(values: Array) -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = []
	faces.assign(values)
	def.faces = faces
	return def

# --- Ziel-Form ------------------------------------------------------------------

func test_every_engraving_has_a_targeting_kind() -> void:
	for archetype in Engraving.all():
		assert_ne(PressTargeting.kind_of(archetype.id), "", "Ziel-Art für %s" % archetype.id)

func test_targeting_kinds_are_correct() -> void:
	assert_eq(PressTargeting.kind_of(Engraving.NOTCH), PressTargeting.TARGET_FACE)
	assert_eq(PressTargeting.kind_of(Engraving.CHISEL), PressTargeting.TARGET_PAIR_DIRECTED)
	assert_eq(PressTargeting.kind_of(Engraving.GRINDSTONE), PressTargeting.TARGET_PAIR_DIRECTED)
	assert_eq(PressTargeting.kind_of(Engraving.POINTER), PressTargeting.TARGET_PAIR_DIRECTED)
	assert_eq(PressTargeting.kind_of(Engraving.POLISH), PressTargeting.TARGET_WHOLE_DIE)
	assert_eq(PressTargeting.kind_of(Engraving.OVERPRESSURE), PressTargeting.TARGET_WHOLE_DIE,
		"der Überdruck sucht sich seine Seite selbst")
	assert_eq(PressTargeting.kind_of(Engraving.GROWTH), PressTargeting.TARGET_WHOLE_DIE)
	assert_eq(PressTargeting.kind_of(DieMaterial.GOLD), PressTargeting.TARGET_FACE)

func test_only_the_whole_die_tools_need_no_face() -> void:
	assert_false(PressTargeting.needs_face(Engraving.POLISH))
	assert_true(PressTargeting.needs_face(Engraving.NOTCH))
	assert_true(PressTargeting.needs_face(Engraving.CHISEL))

# --- Eignung je Seite -------------------------------------------------------------

func test_no_tool_makes_every_face_eligible() -> void:
	assert_eq(PressTargeting.eligible_faces(_die([1, 1, 1, 1, 1, 1]), ""),
		[true, true, true, true, true, true] as Array[bool])

func test_notch_targets_every_face() -> void:
	assert_eq(PressTargeting.eligible_faces(_die([1, 2, 3, 4, 5, 6]), Engraving.NOTCH),
		[true, true, true, true, true, true] as Array[bool], "die Kerbe kennt keine Obergrenze")

func test_grindstone_step1_excludes_ones_step2_excludes_first() -> void:
	var def := _die([1, 2, 3, 4, 5, 6])
	var s1 := PressTargeting.eligible_faces(def, Engraving.GRINDSTONE)
	assert_false(s1[0], "Schritt 1 (Quelle) meidet die 1")
	assert_true(s1[3])
	var s2 := PressTargeting.eligible_faces(def, Engraving.GRINDSTONE, 3)
	assert_false(s2[3], "Schritt 2 (+1) meidet die erste Seite")
	assert_true(s2[0], "auch eine 1 darf jetzt +1 bekommen")

func test_directed_pair_step2_excludes_the_first_face() -> void:
	var def := _die([1, 2, 3, 4, 5, 6])
	assert_eq(PressTargeting.eligible_faces(def, Engraving.CHISEL),
		[true, true, true, true, true, true] as Array[bool], "Schritt 1: jede Seite darf Quelle sein")
	assert_false(PressTargeting.eligible_faces(def, Engraving.CHISEL, 2)[2], "Schritt 2 meidet die Quelle")

func test_the_pointer_only_reaches_a_neighbour() -> void:
	# Der Pointer quert genau eine Kante - die Gegenseite ist kein Ziel.
	var def := _die([1, 2, 3, 4, 5, 6])
	var second := PressTargeting.eligible_faces(def, Engraving.POINTER, 0)
	assert_true(second[1], "der Nachbar ist Ziel")
	assert_false(second[5], "die Gegenseite nicht")
	assert_false(second[0], "und die Quelle erst recht nicht")

## Die Veredelung sättigt, was schon liegt: nackt hat nichts zu veredeln, veredelt
## nichts mehr zu gewinnen.
func test_the_doping_only_targets_an_undoped_material() -> void:
	var def := _die([1, 2, 3, 4, 5, 6])
	def.set_face_material(1, DieMaterial.GOLD)
	def.set_face_material(2, DieMaterial.AMBER)
	def.dope(2)
	var e := PressTargeting.eligible_faces(def, Engraving.DOPING)
	assert_true(e[1], "das frische Gold nimmt die Glasur an")
	assert_false(e[2], "der veredelte Bernstein hat nichts mehr zu gewinnen")
	assert_false(e[0], "eine nackte Seite hat nichts zu veredeln")
	assert_eq(PressTargeting.kind_of(Engraving.DOPING), PressTargeting.TARGET_FACE,
		"ein Klick, eine Seite")
	assert_null(PressTargeting.ghost_after(def, Engraving.DOPING, 1, 1),
		"sie verschiebt keine Augen - es gibt nichts vorzuschauen")

func test_material_never_targets_its_own_face() -> void:
	# Dieselbe Gravur auf dieselbe Seite ist kein Ziel mehr - der Dubletten-
	# Aufstieg ist weg; gesättigt wird allein mit der Veredelung.
	var def := _die([1, 2, 3, 4, 5, 6])
	def.set_face_material(0, DieMaterial.GOLD)
	var e := PressTargeting.eligible_faces(def, DieMaterial.GOLD)
	assert_false(e[0], "die Gold-Seite nimmt kein zweites Gold an")
	assert_true(e[1], "jede andere Seite lässt sich streichen")

func test_burn_in_blocks_a_foreign_material_but_not_a_value_tool() -> void:
	var def := _die([1, 2, 3, 4, 5, 6])
	def.set_face_material(0, DieMaterial.GOLD)
	def.set_rune(0, Rune.BURN_IN)
	assert_false(PressTargeting.face_eligible(def, DieMaterial.AMBER, 0),
		"die eingebrannte Seite nimmt kein fremdes Material")
	assert_true(PressTargeting.face_eligible(def, DieMaterial.AMBER, 1), "die Nachbarseite bleibt frei")
	assert_true(PressTargeting.face_eligible(def, Engraving.NOTCH, 0),
		"die Kerbe ändert den Wert, nicht das Material")

func test_places_outside_the_die_are_never_eligible() -> void:
	var def := _die([1, 2, 3, 4, 5, 6])
	assert_false(PressTargeting.face_eligible(def, Engraving.NOTCH, -1))
	assert_false(PressTargeting.face_eligible(def, Engraving.NOTCH, 6))

# --- Runen-Platz ------------------------------------------------------------------

func test_a_normal_die_always_replaces_its_single_rune() -> void:
	var def := _die([1, 2, 3, 4, 5, 6])
	assert_eq(PressTargeting.free_rune_slot(def, 0), 0, "leer: der erste Platz")
	def.set_rune(0, Rune.AFTERGLOW)
	assert_eq(PressTargeting.free_rune_slot(def, 0), 0, "belegt: er wird ersetzt")

func test_a_vacuum_die_fills_its_second_slot_first() -> void:
	var def := _die([1, 2, 3, 4, 5, 6])
	def.essence_id = Essence.VACUUM
	def.set_rune(0, Rune.AFTERGLOW)
	assert_eq(PressTargeting.free_rune_slot(def, 0), 1, "das Vakuum trägt zwei")

func test_the_bell_jar_opens_a_third_slot() -> void:
	var def := _die([1, 2, 3, 4, 5, 6])
	def.essence_id = Essence.VACUUM
	def.set_rune(0, Rune.AFTERGLOW, 0)
	def.set_rune(0, Rune.SPARK_FLIGHT, 1)
	assert_eq(PressTargeting.free_rune_slot(def, 0, 0), 0, "ohne Glasglocke ist Schluss")
	assert_eq(PressTargeting.free_rune_slot(def, 0, 1), 2, "mit ihr kommt der dritte")

# --- Vorschau (ghost_after) - Klon, echte EtchingEffects, def bleibt --------------

func test_preview_notch_bumps_one_face() -> void:
	var def := _die([1, 2, 3, 4, 5, 6])
	var ghost := PressTargeting.ghost_after(def, Engraving.NOTCH, 1, 2)
	assert_eq(ghost.faces[2], 4, "3 -> 4")
	assert_eq(def.faces[2], 3, "der echte Würfel bleibt unberührt")

func test_preview_chisel_reads_the_first_click_as_source() -> void:
	var def := _die([5, 1, 1, 1, 1, 1])
	var ghost := PressTargeting.ghost_after(def, Engraving.CHISEL, 1, 1, 0)
	assert_eq(ghost.faces[1], 5, "das Ziel erhält den Quellwert")
	assert_eq(def.faces[1], 1, "unberührt")

func test_preview_polish_bumps_the_whole_die() -> void:
	var def := _die([1, 2, 3, 4, 5, 6])
	var ghost := PressTargeting.ghost_after(def, Engraving.POLISH, 1, -1)
	assert_eq(ghost.faces, [2, 3, 4, 5, 6, 7] as Array[int])
	assert_eq(def.faces, [1, 2, 3, 4, 5, 6] as Array[int], "unberührt")

func test_preview_notch_climbs_with_the_stufe() -> void:
	var ghost := PressTargeting.ghost_after(_die([1, 2, 3, 4, 5, 6]), Engraving.NOTCH, 6, 2)
	assert_eq(ghost.faces[2], 15, "3 + 12 auf Stufe 6")

func test_preview_overpressure_hits_the_highest_face() -> void:
	var ghost := PressTargeting.ghost_after(_die([1, 2, 3, 4, 5, 6]), Engraving.OVERPRESSURE, 1, -1)
	assert_eq(ghost.faces, [1, 2, 3, 4, 5, 8] as Array[int])

func test_a_piece_without_moving_eyes_has_no_preview() -> void:
	# Material, Rune und Pointer ändern keine Augenzahl - dort gibt es nichts
	# vorzuzeigen, und die Zelle bleibt bei ihrer Ziffer.
	var def := _die([1, 2, 3, 4, 5, 6])
	assert_null(PressTargeting.ghost_after(def, DieMaterial.GOLD, 1, 0))
	assert_null(PressTargeting.ghost_after(def, Engraving.POINTER, 1, 1, 0))
	assert_null(PressTargeting.ghost_after(def, "", 1, 0))
