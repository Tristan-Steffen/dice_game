extends GutTest
## Tests der Auswahl-Optik und der Material-Tooltips der Seiten-Übersicht in der
## Gravur-Station (DieInspectorView). Die Kanten sind der RAHMEN um das Seiten-
## Raster (Kanten-Materialfarbe, Tooltip beim Überfahren). Look der Seiten-Chips:
##  - GEWÄHLT leuchten Ziffer UND Rahmen in der Auswahlfarbe (kräftiges Violett,
##    DieFaceDisplay.SELECT_NUMBER_COLOR - dieselbe Farbe wie am 3D-Würfel), die
##    FÜLLUNG bleibt aber die Materialfarbe, und die Ziffer bekommt einen schwarzen
##    Umriss (Lesbarkeit auf jeder Materialfarbe).
##  - Seiten/Kanten MIT Material tragen einen handgesteuerten Charm-Tooltip
##    (Hover-Signale, siehe _show_face_tooltip); ohne Material keinen.
##
## Der View wird in den Baum gehängt (add_child_autofree), damit die Chips als
## echte Buttons gebaut werden; die Styleboxen/Farben stehen danach synchron fest.

var view: DieInspectorView

func before_each() -> void:
	view = DieInspectorView.new()
	view.size = Vector2(1400, 1470)
	add_child_autofree(view)
	view.show_die(_die())

## Ein Würfel mit vier belegten und zwei leeren Seiten (Materialliste bewusst
## lückenhaft), Kanten aus Bernstein.
func _die() -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = [1, 2, 3, 4, 5, 6]
	def.faces = faces
	var materials: Array[String] = ["ruby", "", "gold", "glass", "", "bone"]
	def.materials = materials
	def.essence_id = Essence.NEON
	return def

## Die aktuell lebenden Kinder von summary_list. Ein direkter _refresh_face_summary
## räumt die alten per queue_free ab (verzögert!), sie hängen also noch im Baum -
## darum werden zur Löschung vorgemerkte Knoten übersprungen.
func _live_summary() -> Array:
	var live: Array = []
	for c in view.summary_list.get_children():
		if not c.is_queued_for_deletion():
			live.append(c)
	return live

## Das Würfelnetz sitzt IM Kanten-Rahmen (die Kanten sind der Rahmen um die
## Seiten). Neben den Seiten-Chips hängen dort auch Kanten-Chip und Leiterbahn-
## Pfeile - für die Chip-Prüfungen zählen nur die Buttons.
func _face_net() -> Control:
	return _live_summary()[0].get_child(0)

func _face_chips() -> Array:
	var chips: Array = []
	for c in _face_net().get_children():
		if c is Button:
			chips.append(c)
	return chips

func _edge_frame() -> PanelContainer:
	return _live_summary()[0]

## Der Chip, dessen Ziffer in der Pit-Auswahlfarbe leuchtet (genau der gewählte).
func _glowing_chip() -> Button:
	for c in _face_chips():
		var b := c as Button
		if b.get_theme_color("font_color") == DieFaceDisplay.SELECT_NUMBER_COLOR:
			return b
	return null

# --- Auswahl-Optik ------------------------------------------------------------

func test_selected_face_lights_number_and_border_but_keeps_material_fill() -> void:
	view.selected_face = 0  # Rubin-Seite
	view._refresh_face_summary()
	var chip := _glowing_chip()
	assert_not_null(chip, "genau ein Chip leuchtet (der gewählte)")
	var box: StyleBoxFlat = chip.get_theme_stylebox("normal")
	assert_eq(chip.get_theme_color("font_color"), DieFaceDisplay.SELECT_NUMBER_COLOR, "Ziffer leuchtet")
	assert_eq(box.border_color, DieFaceDisplay.SELECT_NUMBER_COLOR, "Rahmen leuchtet")
	assert_eq(box.bg_color, DieMaterial.tint_for("ruby"), "Füllung bleibt die Materialfarbe")

func test_selected_number_gets_black_outline() -> void:
	view.selected_face = 0
	view._refresh_face_summary()
	var chip := _glowing_chip()
	assert_eq(chip.get_theme_color("font_outline_color"), CasinoStyle.INK, "schwarzer Umriss")
	assert_gt(chip.get_theme_constant("outline_size"), 0, "Umriss ist sichtbar dick")

func test_unselected_material_chip_stays_dark_without_outline() -> void:
	view.selected_face = 0
	view._refresh_face_summary()
	for c in _face_chips():
		var b := c as Button
		if b == _glowing_chip():
			continue
		assert_eq(b.get_theme_color("font_color"), CasinoStyle.INK, "ungewählte Ziffer dunkel")
		assert_eq(b.get_theme_constant("outline_size"), 0, "kein Umriss ohne Auswahl")
		var box: StyleBoxFlat = b.get_theme_stylebox("normal")
		assert_eq(box.border_color, DieInspectorView.CHIP_BORDER, "neutraler Rahmen")

func test_exactly_one_chip_glows_for_a_selected_face() -> void:
	view.selected_face = 3
	view._refresh_face_summary()
	var glowing := 0
	for c in _face_chips():
		if (c as Button).get_theme_color("font_color") == DieFaceDisplay.SELECT_NUMBER_COLOR:
			glowing += 1
	assert_eq(glowing, 1)

# --- Material-Tooltip (handgesteuertes Overlay) -------------------------------

func test_every_face_wires_the_hover_window() -> void:
	# Seit das Fenster fest steht, erklärt sich JEDE Seite - auch die nackte:
	# ein leerer Kopf kostet keinen springenden Kasten mehr. Jeder Chip trägt
	# darum Vorschau- UND Fenster-Verbindung.
	var with_window := 0
	for c in _face_chips():
		if (c as Button).mouse_entered.get_connections().size() >= 2:
			with_window += 1
	assert_eq(with_window, 6, "alle sechs Seiten öffnen das Fenster")

func test_engraving_slots_carry_their_effect_tooltip() -> void:
	# Die Werkzeug-Plätze liegen in den Vorrats-Schubladen und tragen dort die
	# Wirkungs-Beschreibung (Godot-Tooltip, kein handgesteuerter wie die Chips).
	var drawer: SupplyDrawerView = autofree(SupplyDrawerView.new())
	drawer.category = Engraving.CATEGORY_NUMBER
	add_child_autofree(drawer)
	drawer.run = GameRun.new_run()
	assert_gt(drawer.slots.size(), 0, "die Schublade hat Plätze")
	for entry in drawer.slots:
		var slot: Button = entry["button"]
		assert_ne(slot.tooltip_text, "", "Platz %s erklärt sich" % entry["id"])

# --- Würfelnetz (dieselbe Anordnung wie im Netzfeld der Grube) ----------------

func test_the_summary_lays_the_chips_out_as_the_die_net() -> void:
	# Nach PHYSISCHER Lage, nicht nach Augenzahl: nur so treffen die Leiterbahn-
	# Pfeile die Kante, über die sie zeigen.
	var cell: float = view.u * DieInspectorView.TRAY_TILE
	for face in 6:
		var chip: Button = view.face_chips[face]
		assert_almost_eq(chip.position, DieNetView.cell_position(face, cell), Vector2.ONE * 0.5,
			"Seite %d sitzt auf ihrem Kreuz-Platz" % face)

func test_the_summary_shows_pointer_arrows() -> void:
	var def := _die()
	var pointers: Array[int] = [4, -1, 0, -1, -1, -1]
	def.pointers = pointers
	view.show_die(def)
	var arrows := 0
	for c in _face_net().get_children():
		if c is DieNetView.PointerArrow:
			arrows += 1
	assert_eq(arrows, 2, "je Leiterbahn ein Pfeil - der Grund für das Netz")

func test_the_summary_carries_the_edge_chip() -> void:
	var chips := 0
	for c in _face_net().get_children():
		if c is Panel and not (c is Button):
			chips += 1
	assert_eq(chips, 1, "der Kanten-Chip sitzt in der leeren Kreuz-Ecke")

func test_show_and_hide_face_tooltip() -> void:
	assert_false(view.face_tooltip.visible, "anfangs verborgen")
	view._show_face_tooltip("Kopfzeile", _lines(["erste Zeile", "zweite Zeile"]))
	assert_true(view.face_tooltip.visible)
	assert_eq(view.face_tooltip_title.text, "Kopfzeile")
	assert_eq(_tooltip_lines(), ["erste Zeile", "zweite Zeile"], "je Aussage eine Zeile")
	view._hide_face_tooltip()
	assert_false(view.face_tooltip.visible)

## Die sichtbaren Textzeilen des Fensters, von oben nach unten.
func _tooltip_lines() -> Array:
	var out := []
	for child in view.face_tooltip_lines.get_children():
		if child is Label and not child.is_queued_for_deletion():
			out.append(child.text)
	return out

func _lines(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

# --- Das Seiten-Fenster: eine Zeile je Aussage, fester Platz ----------------------

func test_a_face_with_material_and_rune_shows_both_lines() -> void:
	# DER kaputte Fall: vorher liefen Material- und Runen-Wirkung in EIN Label
	# und überschrieben sich gegenseitig.
	var def := _die()
	def.set_face_material(0, DieMaterial.RUBY)
	def.raise_level(0)
	def.set_rune(0, Rune.AFTERGLOW)
	view.show_die(def)
	view._show_face_info(0)
	var lines := _tooltip_lines()
	assert_eq(lines.size(), 2, "Material und Rune stehen nebeneinander, nicht ineinander")
	assert_true(lines[0].contains("Rubin"), "erst das Material: %s" % lines[0])
	assert_true(lines[0].contains("II"), "mit seiner Stufe")
	assert_true(lines[1].contains("Nachglühen"), "dann der Rune: %s" % lines[1])

func test_a_vacuum_face_lists_both_of_its_runes() -> void:
	var def := _die()
	def.essence_id = Essence.VACUUM
	def.set_face_material(0, DieMaterial.GOLD)
	def.set_rune(0, Rune.AFTERGLOW, 0)
	def.set_rune(0, Rune.SPARK_FLIGHT, 1)
	def.pointers[0] = 2
	view.show_die(def)
	view._show_face_info(0)
	var lines := _tooltip_lines()
	assert_eq(lines.size(), 4, "Material + zwei Runen + Leiterbahn - der volle Fall")
	assert_true(lines[3].contains("Leiterbahn"), "die Bahn steht zuletzt")

func test_the_face_title_names_number_and_value() -> void:
	view._show_face_info(2)
	assert_true(view.face_tooltip_title.text.contains("Seite 3"), view.face_tooltip_title.text)
	assert_true(view.face_tooltip_title.text.contains("Wert 3"), view.face_tooltip_title.text)

func test_a_bare_face_still_opens_the_window() -> void:
	# Seite 2 trägt nichts - der Kopf allein muss reichen, ohne leere Zeilen.
	view._show_face_info(1)
	assert_true(view.face_tooltip.visible)
	assert_eq(_tooltip_lines().size(), 0, "keine Zeile ohne Aussage")

func test_the_window_sits_right_of_the_die_over_the_grid() -> void:
	await wait_frames(2)
	view._show_face_info(0)
	await wait_frames(2)
	var host_local: Vector2 = view.grid_host.get_global_rect().position - view.get_global_rect().position
	assert_almost_eq(view.face_tooltip.position.x, host_local.x, 1.0,
		"bündig an der linken Kante des Rasters - also rechts vom Würfel-Schirm")
	var bottom: float = view.face_tooltip.position.y + view.face_tooltip.size.y
	assert_almost_eq(bottom, host_local.y + view.grid_host.size.y, 1.0,
		"und unten bündig: die untere linke Ecke des Rasters")

func test_the_window_does_not_follow_the_cursor() -> void:
	# Verankert ist die UNTERE linke Ecke - das Fenster wächst nach oben, wenn
	# eine Seite mehr zu sagen hat, statt nach unten aus dem Panel zu laufen.
	await wait_frames(2)
	view._show_face_info(0)
	await wait_frames(2)
	var first_left: float = view.face_tooltip.position.x
	var first_bottom: float = view.face_tooltip.position.y + view.face_tooltip.size.y
	view._show_face_info(4)
	await wait_frames(2)
	assert_almost_eq(view.face_tooltip.position.x, first_left, 1.0, "dieselbe Kante")
	assert_almost_eq(view.face_tooltip.position.y + view.face_tooltip.size.y, first_bottom, 1.0,
		"und dieselbe Unterkante, egal welche Seite")

func test_the_frame_hover_shows_the_essence() -> void:
	view._on_edge_frame_hover()
	assert_true(view.face_tooltip.visible)
	var essence := Essence.by_id(Essence.NEON)
	assert_true(view.face_tooltip_title.text.contains(essence.display_name))
	assert_true(view.face_tooltip_title.text.contains(essence.display_name), "Name im Kopf")
	assert_eq(_tooltip_lines(), [essence.description], "die volle Wirkung als Zeile")

func test_the_frame_hover_stays_silent_without_an_essence() -> void:
	var def := _die()
	def.essence_id = ""
	view.show_die(def)
	view._on_edge_frame_hover()
	assert_false(view.face_tooltip.visible, "ohne Seele gibt es nichts zu erklären")

func test_hover_exit_hides_the_window() -> void:
	view._show_face_info(0)
	assert_true(view.face_tooltip.visible)
	view._on_edge_frame_hover_exit()
	assert_false(view.face_tooltip.visible)
