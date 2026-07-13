extends GutTest
## Tests des Wert→Seiten-Auflösers der Gravur-Station (DieInspectorView.
## _face_index_for_value). Er entscheidet, welche physische Seite ein Klick auf
## einen Wert-Chip der Seiten-Übersicht meint (siehe _on_chip_clicked): beim
## zweiten Schritt einer Ätzung (Meißel-Quelle, Schleifstein-Minus) möglichst
## eine ANDERE Seite als die bereits gewählte, sonst als Rückfall die gewählte
## selbst (damit _complete_two_step die "andere Seite"-Rückmeldung geben kann).
##
## Die Methode liest nur current_def.faces, keine Nodes - daher wird die Station
## bewusst ohne Szenenbaum (kein _ready) instanziiert und nur die reine Logik
## geprüft.

func _resolver(values: Array) -> DieInspectorView:
	var view: DieInspectorView = autofree(DieInspectorView.new())
	var def := DieDefinition.new()
	var faces: Array[int] = []
	faces.assign(values)
	def.faces = faces
	view.current_def = def
	return view

func test_returns_index_of_matching_value():
	var view := _resolver([1, 2, 3, 4, 5, 6])
	assert_eq(view._face_index_for_value(4, -1), 3)

func test_absent_value_returns_minus_one():
	var view := _resolver([1, 2, 3, 4, 5, 6])
	assert_eq(view._face_index_for_value(9, -1), -1)

func test_no_exclude_returns_first_occurrence():
	var view := _resolver([4, 4, 3, 4, 5, 6])
	assert_eq(view._face_index_for_value(4, -1), 0)

func test_prefers_index_other_than_excluded():
	var view := _resolver([4, 2, 3, 4, 5, 6])  # Vieren auf Index 0 und 3
	assert_eq(view._face_index_for_value(4, 0), 3, "meidet die ausgeschlossene Seite")
	assert_eq(view._face_index_for_value(4, 3), 0)

func test_falls_back_to_excluded_when_only_match():
	# Nur eine 4 (Index 3), und genau die ist ausgeschlossen -> Rückfall auf sie,
	# damit _complete_two_step "bitte andere Seite" melden kann statt ins Leere zu laufen.
	var view := _resolver([1, 2, 3, 4, 5, 6])
	assert_eq(view._face_index_for_value(4, 3), 3)
