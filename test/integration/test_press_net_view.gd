extends GutTest
## Tier-2-Tests des Arbeits-Netzes (PressNetView): dasselbe aufgeklappte Kreuz wie
## überall, aber jede Zelle ist ein Knopf. Ohne Werkzeug ist es reine Anzeige; mit
## einem Stück in der Hand leuchten die legalen Seiten golden und die übrigen
## dimmen aus. Die Plakette des nassen Gusses sitzt in der oberen linken Zellecke.

const CELL := 24.0

var net: PressNetView

func before_each() -> void:
	net = PressNetView.new()
	add_child_autofree(net)
	net.cell = CELL

## Ein Würfel mit Material auf Seite 0 und 2.
func _die() -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = [1, 2, 3, 4, 5, 6]
	def.faces = faces
	def.set_face_material(0, DieMaterial.RUBY)
	def.set_face_material(2, DieMaterial.GOLD)
	return def

func _build(held: String = "", first: int = -1) -> void:
	if net.def == null:
		net.def = _die()
	net.held_id = held
	net.first_face = first
	net.build()

## Die sechs Seiten-Zellen in physischer Reihenfolge.
func _cells() -> Array:
	var cells := []
	for child in net.get_children():
		if child is Button and String(child.name).begins_with("NetCell"):
			cells.append(child)
	return cells

func _box(face: int) -> StyleBoxFlat:
	return net._chips[face].get_theme_stylebox("normal") as StyleBoxFlat

# --- Aufbau ---------------------------------------------------------------------

func test_the_net_lays_its_cells_out_as_the_die_net() -> void:
	# Nach PHYSISCHER Lage, nicht nach Augenzahl: nur so treffen die Pointer-
	# Pfeile die Kante, über die sie zeigen.
	_build()
	for face in 6:
		assert_almost_eq(net._chips[face].position, DieNetView.cell_position(face, CELL),
			Vector2.ONE * 0.5, "Seite %d sitzt auf ihrem Kreuz-Platz" % face)
	assert_eq(net.custom_minimum_size, DieNetView.net_size(CELL), "und das Netz misst wie jedes andere")

func test_an_empty_net_builds_nothing() -> void:
	net.def = null
	net.build()
	assert_eq(_cells().size(), 0, "ohne Würfel keine Zellen")

func test_the_net_carries_edge_chip_pointers_and_badges() -> void:
	var def := _die()
	def.essence_id = Essence.NEON
	def.dope(0)
	var pointers: Array[int] = [1, -1, -1, -1, -1, -1]
	def.pointers = pointers
	def.set_rune(2, Rune.AFTERGLOW)
	net.def = def
	net.build()
	var chips := 0
	var arrows := 0
	var badges := 0
	var glyphs := 0
	for child in net.get_children():
		if child is DieNetView.PointerArrow:
			arrows += 1
		elif child is DieNetView.LevelBadge:
			badges += 1
		elif child is DieNetView.RuneGlyph:
			glyphs += 1
		elif child is Panel and not (child is Button):
			chips += 1
	assert_eq(chips, 1, "der Essenz-Chip sitzt in der leeren Kreuz-Ecke")
	assert_eq(arrows, 1, "je Pointer ein Pfeil - der Grund für das Netz")
	assert_eq(badges, 1, "die veredelte Seite trägt ihre Plakette")
	assert_eq(glyphs, 1, "und die Rune ihr Zeichen")

# --- Ohne Werkzeug: reine Anzeige ------------------------------------------------

func test_without_a_tool_no_cell_catches_a_click() -> void:
	_build()
	for face in 6:
		assert_true(net._chips[face].disabled, "Seite %d ist bloß Anzeige" % face)

func test_a_soul_tints_the_cell_borders() -> void:
	var def := _die()
	def.essence_id = Essence.NEON
	net.def = def
	net.build()
	assert_eq(_box(1).border_color, Essence.glow_for(Essence.NEON), "die Seele säumt ihr Netz")

func test_a_soulless_die_keeps_the_neutral_border() -> void:
	_build()
	assert_eq(_box(1).border_color, PressNetView.CHIP_BORDER)

# --- Mit Werkzeug: die legalen Seiten führen -------------------------------------

func test_a_held_tool_lights_its_legal_faces_and_dims_the_rest() -> void:
	# Gold liegt auf Seite 2 - dieselbe Farbe noch einmal ist kein Ziel.
	_build(DieMaterial.GOLD)
	assert_eq(_box(0).border_color, PressNetView.TARGET_BORDER, "der Saum IST die Führung")
	assert_false(net._chips[0].disabled, "und die Zelle fängt den Klick")
	assert_eq(net._chips[2].get_theme_color("font_color"), PressNetView.DIM_NUMBER,
		"die Gold-Seite dimmt aus")
	assert_true(net._chips[2].disabled, "und nimmt keinen Klick an")

func test_the_first_click_of_a_pair_stands_out_and_stays_clickable() -> void:
	_build(Engraving.CHISEL, 3)
	assert_eq(_box(3).border_color, DieFaceDisplay.SELECT_NUMBER_COLOR, "die Quelle leuchtet")
	assert_false(net._chips[3].disabled, "ein Klick darauf nimmt sie zurück")
	assert_eq(_box(4).border_color, PressNetView.TARGET_BORDER, "die übrigen bleiben Ziele")

func test_a_cell_reports_its_face_when_pressed() -> void:
	_build(Engraving.NOTCH)
	var pressed: Array[int] = []
	net.face_pressed.connect(func(face: int) -> void: pressed.append(face))
	net._chips[4].pressed.emit()
	assert_eq(pressed, [4] as Array[int])

func test_a_locked_bench_freezes_every_cell() -> void:
	net.locked = true
	_build(Engraving.NOTCH)
	for face in 6:
		assert_true(net._chips[face].disabled, "nach der Unterschrift wird nur noch gelesen")

# --- Vorschau ----------------------------------------------------------------------

func test_hovering_shows_what_the_tool_would_do() -> void:
	_build(Engraving.NOTCH)
	net._show_preview(2)
	assert_eq(net._chips[2].text, "3→4", "die Zelle sagt es selbst")
	assert_eq(net._chips[2].get_theme_color("font_color"), PressNetView.PREVIEW_UP,
		"steigend heißt grün")
	net._clear_preview()
	assert_eq(net._chips[2].text, "3", "danach steht wieder die Ziffer")

func test_an_ineligible_face_shows_no_preview() -> void:
	_build(DieMaterial.GOLD)
	net._show_preview(2)  # trägt schon Gold
	assert_eq(net._chips[2].text, "3", "was nicht geht, zeigt nichts")

# --- Die Plakette des nassen Gusses --------------------------------------------------

## Die Plakette, die in der oberen linken Ecke dieser Zelle sitzt (null = keine).
func _mark_badge(face: int) -> Button:
	return net.get_node_or_null("PressMark%d" % face) as Button

func test_a_wet_mark_is_a_button_a_set_one_is_not() -> void:
	net.def = _die()
	net.marks = {1: {"index": 0, "id": Engraving.NOTCH, "wet": true},
		4: {"index": 1, "id": Engraving.NOTCH, "wet": false}}
	net.build()
	var wet := _mark_badge(1)
	var set_badge := _mark_badge(4)
	assert_not_null(wet, "die nasse Setzung trägt ihre Plakette")
	assert_not_null(set_badge, "die überbaute ebenso")
	assert_false(wet.disabled, "die nasse lässt sich herausnehmen")
	assert_true(set_badge.disabled, "die überbaute nicht mehr")
	assert_eq((wet.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.g,
		PressNetView.WET.g, "grün heißt: noch herausnehmbar")

func test_clicking_a_wet_mark_reports_its_face() -> void:
	net.def = _die()
	net.marks = {1: {"index": 0, "id": Engraving.NOTCH, "wet": true}}
	net.build()
	var faces: Array[int] = []
	net.mark_pressed.connect(func(face: int) -> void: faces.append(face))
	_mark_badge(1).pressed.emit()
	assert_eq(faces, [1] as Array[int])

# --- Geometrie: welche Zelle liegt unter dem Zeiger -----------------------------------

func test_the_net_answers_which_face_lies_under_a_pixel() -> void:
	_build()
	await wait_frames(2)
	var origin := net.get_global_rect().position
	for face in 6:
		var center := origin + DieNetView.cell_position(face, CELL) + Vector2.ONE * CELL * 0.5
		assert_eq(net.face_at_pixel(center), face, "Seite %d liegt unter ihrer Mitte" % face)
	assert_eq(net.face_at_pixel(origin - Vector2.ONE * 50.0), -1, "außerhalb liegt keine")
