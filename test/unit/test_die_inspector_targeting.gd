extends GutTest
## Tests der Werkzeug-zuerst-Logik der Gravur-Station (DieInspectorView): Ziel-
## Klassifikation, Seiten-Eignung je Schritt und die Vorschau-Berechnung
## (_ghost_after) - reine Logik über current_def, ohne Szenenbaum (kein _ready).

func _view(values: Array) -> DieInspectorView:
	var view: DieInspectorView = autofree(DieInspectorView.new())
	var def := DieDefinition.new()
	var faces: Array[int] = []
	faces.assign(values)
	def.faces = faces
	view.current_def = def
	return view

# --- _targeting_of -----------------------------------------------------------

func test_every_engraving_has_a_targeting_kind() -> void:
	var view := _view([1, 2, 3, 4, 5, 6])
	for archetype in Engraving.all():
		assert_ne(view._targeting_of(archetype.id), "", "Ziel-Art für %s" % archetype.id)

func test_targeting_kinds_are_correct() -> void:
	var view := _view([1, 2, 3, 4, 5, 6])
	assert_eq(view._targeting_of(Engraving.NOTCH), DieInspectorView.TARGET_FACE)
	assert_eq(view._targeting_of(Engraving.PUNCH), DieInspectorView.TARGET_FACE)
	assert_eq(view._targeting_of(Engraving.BLUEPRINT), DieInspectorView.TARGET_FACE)
	assert_eq(view._targeting_of(Engraving.CHISEL), DieInspectorView.TARGET_PAIR_DIRECTED)
	assert_eq(view._targeting_of(Engraving.GRINDSTONE), DieInspectorView.TARGET_PAIR_DIRECTED)
	assert_eq(view._targeting_of(Engraving.AVERAGING), DieInspectorView.TARGET_PAIR)
	assert_eq(view._targeting_of(Engraving.STRAIGHTEN), DieInspectorView.TARGET_WHOLE_DIE)
	assert_eq(view._targeting_of(Engraving.POLISH), DieInspectorView.TARGET_WHOLE_DIE)
	assert_eq(view._targeting_of(Engraving.SANDPAPER), DieInspectorView.TARGET_WHOLE_DIE)
	assert_eq(view._targeting_of(DieMaterial.GOLD), DieInspectorView.TARGET_FACE)

# --- _eligible_faces ---------------------------------------------------------

func test_no_tool_makes_every_face_eligible() -> void:
	var view := _view([1, 1, 1, 1, 1, 1])
	assert_eq(view._eligible_faces(), [true, true, true, true, true, true] as Array[bool])

func test_file_down_excludes_ones() -> void:
	var view := _view([1, 2, 3, 4, 5, 6])
	view.held_id = Engraving.FILE_DOWN
	var e := view._eligible_faces()
	assert_false(e[0], "eine 1 ist kein Ziel der Feile")
	assert_true(e[1], "eine 2 schon")

func test_punch_targets_every_face() -> void:
	var view := _view([1, 2, 3, 4, 5, 6])
	view.held_id = Engraving.PUNCH
	assert_eq(view._eligible_faces(), [true, true, true, true, true, true] as Array[bool],
		"die Stanze kennt keine Obergrenze")

func test_grindstone_step1_excludes_ones_step2_excludes_first() -> void:
	var view := _view([1, 2, 3, 4, 5, 6])
	view.held_id = Engraving.GRINDSTONE
	var s1 := view._eligible_faces()
	assert_false(s1[0], "Schritt 1 (−1) meidet die 1")
	assert_true(s1[3])
	view.first_face = 3
	var s2 := view._eligible_faces()
	assert_false(s2[3], "Schritt 2 (+1) meidet die erste Seite")
	assert_true(s2[0], "auch eine 1 darf jetzt +1 bekommen")

func test_directed_pair_step2_excludes_the_first_face() -> void:
	var view := _view([1, 2, 3, 4, 5, 6])
	view.held_id = Engraving.CHISEL
	assert_eq(view._eligible_faces(), [true, true, true, true, true, true] as Array[bool],
		"Schritt 1: jede Seite darf Quelle sein")
	view.first_face = 2
	assert_false(view._eligible_faces()[2], "Schritt 2 meidet die Quelle")

func test_material_never_targets_its_own_face() -> void:
	# Dieselbe Gravur auf dieselbe Seite ist kein Ziel mehr - der Dubletten-
	# Aufstieg ist weg, dotiert wird allein über die Dotierung.
	var view := _view([1, 2, 3, 4, 5, 6])
	# Hier geht es um die ZIELWAHL, nicht um den Vorrat - der ist unbegrenzt.
	view.run = GameRun.new_run()
	view.run.unlimited_engravings = true
	view.current_def.set_face_material(0, DieMaterial.GOLD)
	view.held_id = DieMaterial.GOLD
	var e := view._eligible_faces()
	assert_false(e[0], "die Gold-Seite nimmt kein zweites Gold an")
	assert_true(e[1], "jede andere Seite lässt sich streichen")

# --- Vorschau (_ghost_after) - Klon, echte EtchingEffects, current_def bleibt --

func test_preview_notch_bumps_one_face() -> void:
	var view := _view([1, 2, 3, 4, 5, 6])
	view.held_id = Engraving.NOTCH
	var g := view._ghost_after(2)
	assert_eq(g.faces[2], 4, "3 -> 4")
	assert_eq(view.current_def.faces[2], 3, "der echte Würfel bleibt unberührt")

func test_preview_chisel_reads_the_first_click_as_source() -> void:
	# Meißel: erster Klick = Quelle. first=0 (Wert 5), hover=1 -> Ziel wird 5.
	# Pinnt die Quelle→Ziel-Richtung fest.
	var view := _view([5, 1, 1, 1, 1, 1])
	view.held_id = Engraving.CHISEL
	view.first_face = 0
	var g := view._ghost_after(1)
	assert_eq(g.faces[1], 5, "das Ziel erhält den Quellwert (Quelle = erster Klick)")
	assert_eq(view.current_def.faces[1], 1, "unberührt")

func test_preview_polish_bumps_the_whole_die() -> void:
	var view := _view([1, 2, 3, 4, 5, 6])
	view.held_id = Engraving.POLISH
	var g := view._ghost_after(-1)
	assert_eq(g.faces, [2, 3, 4, 5, 6, 7] as Array[int])
	assert_eq(view.current_def.faces, [1, 2, 3, 4, 5, 6] as Array[int], "unberührt")

func test_preview_punch_adds_five() -> void:
	var view := _view([1, 2, 3, 4, 5, 6])
	view.held_id = Engraving.PUNCH
	var g := view._ghost_after(2)
	assert_eq(g.faces[2], 8, "3 -> 8")
	assert_eq(view.current_def.faces[2], 3, "der echte Würfel bleibt unberührt")
