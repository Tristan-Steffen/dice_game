extends GutTest
## Die EINE Netz-Anzeige der Werkstatt: als Instanz das SUMMEN-NETZ der Vorschau
## (der Zielwürfel, wie die Serie ihn zurückließe), als Statik das MINI-NETZ einer
## Kassette. Beide zeichnen dieselbe Kreuzform wie jedes andere Würfelnetz.

var net: PressNetView
var die: DieDefinition

func before_each() -> void:
	die = DieDefinition.standard().instantiate()
	net = PressNetView.new()
	net.def = die
	net.cell = 24.0
	add_child_autofree(net)

func _build() -> void:
	net.build()

## Die Zelle einer Seite (null = keine).
func _cell(face: int) -> Panel:
	return net.get_node_or_null("NetCell%d" % face)

func _text(face: int) -> String:
	var chip := _cell(face)
	if chip == null:
		return ""
	var label: Label = chip.get_node_or_null("Value")
	return label.text if label != null else ""

## Eine Projektion, die genau diese Seite um amount hebt.
func _bump(face: int, amount: int) -> Dictionary:
	var card := StampNet.empty_net()
	card[face] = StampNet.value_cell(amount)
	return SeriesResolver.resolve([card], die)

# --- Die Kreuzform ----------------------------------------------------------------

func test_the_net_lays_its_cells_out_as_the_die_net() -> void:
	_build()
	assert_eq(net.size, DieNetView.net_size(net.cell), "dasselbe Maß wie jedes Netz")
	for face in 6:
		var chip := _cell(face)
		assert_not_null(chip, "Seite %d hat ihre Zelle" % face)
		assert_eq(chip.position, DieNetView.cell_position(face, net.cell),
			"und sie liegt auf ihrem Kreuzplatz")

func test_without_a_target_the_net_builds_nothing() -> void:
	net.def = null
	_build()
	assert_null(_cell(0), "ohne Zielwürfel steht kein Kreuz")
	assert_eq(net.size, DieNetView.net_size(net.cell), "sein Platz bleibt trotzdem")

func test_the_net_carries_edge_chip_runes_and_badges() -> void:
	die.essence_id = Essence.all()[0].id
	die.set_face_material(1, DieMaterial.GOLD)
	die.dope(1)
	die.set_rune(2, Rune.AFTERGLOW)
	die.pointers[0] = DieDefinition.adjacent_faces(0)[0]
	_build()
	var kinds := {}
	for child in net.get_children():
		kinds[child.get_class()] = true
	assert_gt(net.get_child_count(), 6, "über den Zellen liegen Chip, Rune und Pfeil")

# --- Die Vorschau: das Netz zeigt den Zustand NACH der Serie -----------------------

func test_a_raised_face_reads_as_an_arrow() -> void:
	var before: int = die.faces[3]
	net.projection = _bump(3, 4)
	_build()
	assert_eq(_text(3), "%d→%d" % [before, before + 4], "die Zelle zeigt den Weg")
	assert_eq(_text(0), str(die.faces[0]), "eine unberührte Zelle bleibt eine Zahl")
	assert_true(net.touches(3))
	assert_false(net.touches(0))

func test_the_preview_die_carries_material_rune_and_pointer() -> void:
	var card := StampNet.empty_net()
	card[1] = StampNet.material_cell(DieMaterial.RUBY)
	card[2] = StampNet.rune_cell(Rune.AFTERGLOW)
	net.projection = SeriesResolver.resolve([card], die)
	_build()
	var ghost := net.preview_die()
	assert_eq(ghost.materials[1], DieMaterial.RUBY, "das Material liegt schon auf")
	assert_true(ghost.has_rune(2, Rune.AFTERGLOW), "und die Rune sitzt")
	assert_eq(die.materials[1], "", "der ECHTE Würfel bleibt unberührt")

## Eine verpuffte Zelle grault aus und nennt beim Überfahren ihren Grund.
func test_a_fizzled_cell_dims_and_names_its_reason() -> void:
	var card := StampNet.empty_net()
	card[0] = StampNet.dope_cell()  # nackte Seite: nichts zu sättigen
	net.projection = SeriesResolver.resolve([card], die)
	_build()
	assert_eq(net.projection["fizzled"].size(), 1, "die Zelle verpufft")
	assert_eq(_text(0), str(die.faces[0]), "und die Zelle zeigt den alten Stand")
	assert_true(net.hint_for_face(0).contains("verpufft"),
		"der Grund steht in der Zeile: %s" % net.hint_for_face(0))

func test_the_hover_highlight_fades_everything_else() -> void:
	net.projection = _bump(3, 2)
	net.highlight = [3] as Array[int]
	_build()
	assert_almost_eq(_cell(3).modulate.a, 1.0, 0.001, "der Beitrag steht voll da")
	assert_lt(_cell(0).modulate.a, 1.0, "der Rest verblaßt")

func test_the_net_answers_which_face_lies_under_a_pixel() -> void:
	_build()
	await wait_frames(2)
	var at := net.get_global_rect().position + DieNetView.cell_position(4, net.cell) \
		+ Vector2.ONE * net.cell * 0.5
	assert_eq(net.face_at_pixel(at), 4)
	assert_eq(net.face_at_pixel(Vector2(-50, -50)), -1, "außerhalb liegt keine Zelle")

# --- Das MINI-NETZ einer Kassette -------------------------------------------------

func test_a_stamp_net_draws_one_cell_per_face() -> void:
	var card := StampNet.empty_net()
	card[0] = StampNet.value_cell(3)
	var mini := PressNetView.stamp_net(card, 12.0)
	add_child_autofree(mini)
	assert_eq(mini.get_child_count(), StampNet.FACES, "sechs Zellen, wie am Würfel")
	assert_eq(mini.size, DieNetView.net_size(12.0))

func test_a_value_cell_writes_its_bonus() -> void:
	var card := StampNet.empty_net()
	card[2] = StampNet.value_cell(7)
	var mini := PressNetView.stamp_net(card, 12.0)
	add_child_autofree(mini)
	var chip: Panel = mini.get_child(2)
	var label: Label = chip.get_node_or_null("CellMark")
	assert_not_null(label, "die Zahl-Zelle trägt ihren Bonus")
	assert_eq(label.text, "+7")

func test_an_operator_cell_writes_its_glyph() -> void:
	var card := StampNet.empty_net()
	card[0] = StampNet.operator_cell(StampNet.OP_DOUBLER)
	var mini := PressNetView.stamp_net(card, 12.0)
	add_child_autofree(mini)
	var label: Label = mini.get_child(0).get_node_or_null("CellMark")
	assert_not_null(label)
	assert_eq(label.text, StampNet.operator_glyph(StampNet.OP_DOUBLER),
		"die Glyphe kommt aus StampNet, hier wird nichts zweitgezeichnet")

func test_an_empty_cell_stays_dark_and_bare() -> void:
	var mini := PressNetView.stamp_net(StampNet.empty_net(), 12.0)
	add_child_autofree(mini)
	assert_eq(mini.get_child(0).get_child_count(), 0, "eine leere Zelle trägt nichts")

func test_a_rune_cell_draws_the_same_figure_as_the_die() -> void:
	var card := StampNet.empty_net()
	card[1] = StampNet.rune_cell(Rune.AFTERGLOW)
	var mini := PressNetView.stamp_net(card, 12.0)
	add_child_autofree(mini)
	var glyph := mini.get_child(1).get_child(0)
	assert_true(glyph is DieNetView.RuneGlyph, "dieselbe EINE Zeichnung wie am Netz")
	assert_eq((glyph as DieNetView.RuneGlyph).lines.size(),
		Rune.glyph_lines(Rune.by_id(Rune.AFTERGLOW).glyph).size())

# --- Der ZÄHL-TAKT und die FALTUNG (die DURCHLICHT-FAHRT) --------------------------

## Zahlen TICKEN, sie springen nie: mit gesetztem Takt steht erst der alte Stand
## da, und der Aufräum-Pfad setzt sie auf ihr Ziel.
func test_the_numbers_tick_instead_of_jumping() -> void:
	_build()
	assert_eq(_text(0), str(die.faces[0]), "ohne Serie steht die nackte Augenzahl")
	net.projection = _bump(0, 6)
	net.tick_time = 1.0
	_build()
	assert_eq(_text(0), str(die.faces[0]), "der Takt beginnt beim alten Stand")
	net.settle_ticks()
	assert_eq(_text(0), "%d→%d" % [die.faces[0], die.faces[0] + 6],
		"und endet auf dem Ziel - Endzustand zuerst")

## Ohne Vorstand gibt es nichts zu ticken: der erste Aufbau steht sofort richtig.
func test_without_a_previous_reading_there_is_nothing_to_tick() -> void:
	net.projection = _bump(1, 3)
	net.tick_time = 1.0
	_build()
	assert_eq(_text(1), "%d→%d" % [die.faces[1], die.faces[1] + 3])

## Ein Takt gilt genau EINEN Aufbau - sonst tickte die nächste Anzeige nach.
func test_a_tick_lasts_exactly_one_build() -> void:
	_build()
	net.tick_time = 1.0
	_build()
	assert_eq(net.tick_time, 0.0)

## Ein neuer Lauf löscht den Stand: von dort tickt nichts mehr irgendwohin.
func test_a_reset_drops_the_standing_reading() -> void:
	_build()
	net.reset_ticks()
	net.projection = _bump(2, 4)
	net.tick_time = 1.0
	_build()
	assert_eq(_text(2), "%d→%d" % [die.faces[2], die.faces[2] + 4], "es springt")

## Die FALTUNG fährt die Zellen zur Mitte, der Aufbau stellt sie zurück.
func test_the_fold_collapses_the_cells_and_build_unfolds_them() -> void:
	_build()
	var home: Vector2 = _cell(0).position
	net.fold(1.0)
	assert_lt(_cell(0).position.distance_to(net.size * 0.5),
		home.distance_to(net.size * 0.5), "die Zelle klappt zur Mitte")
	assert_lt(_cell(0).scale.x, 1.0, "und schrumpft dabei")
	_build()
	assert_eq(_cell(0).position, home, "der Aufbau stellt sie zurück")
	assert_eq(_cell(0).scale, Vector2.ONE)
