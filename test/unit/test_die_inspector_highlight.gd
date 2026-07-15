extends GutTest
## Tests der Auswahl-Optik und der Material-Tooltips der Seiten-Übersicht in der
## Gravur-Station (DieInspectorView). Geprüft wird der Look der Seiten-/Kanten-Chips:
##  - GEWÄHLT leuchten Ziffer UND Rahmen in der Auswahlfarbe (kräftiges Violett,
##    RotatableDieView.SELECT_FACE_COLOR - dieselbe Farbe wie am 3D-Würfel), die
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
	var materials: Array[String] = ["ruby", "", "gold", "glass", "", "mercury"]
	def.materials = materials
	def.edge_material = "amber"
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

func _face_grid() -> GridContainer:
	return _live_summary()[0]

func _edge_chip() -> Button:
	return _live_summary()[1].get_child(0)  # edge_group -> Kanten-Chip

## Der Chip, dessen Ziffer in der Pit-Auswahlfarbe leuchtet (genau der gewählte).
func _glowing_chip() -> Button:
	for c in _face_grid().get_children():
		var b := c as Button
		if b.get_theme_color("font_color") == RotatableDieView.SELECT_FACE_COLOR:
			return b
	return null

# --- Auswahl-Optik ------------------------------------------------------------

func test_selected_face_lights_number_and_border_but_keeps_material_fill() -> void:
	view.selected_face = 0  # Rubin-Seite
	view._refresh_face_summary()
	var chip := _glowing_chip()
	assert_not_null(chip, "genau ein Chip leuchtet (der gewählte)")
	var box: StyleBoxFlat = chip.get_theme_stylebox("normal")
	assert_eq(chip.get_theme_color("font_color"), RotatableDieView.SELECT_FACE_COLOR, "Ziffer leuchtet")
	assert_eq(box.border_color, RotatableDieView.SELECT_FACE_COLOR, "Rahmen leuchtet")
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
	for c in _face_grid().get_children():
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
	for c in _face_grid().get_children():
		if (c as Button).get_theme_color("font_color") == RotatableDieView.SELECT_FACE_COLOR:
			glowing += 1
	assert_eq(glowing, 1)

func test_no_face_glows_when_edges_are_selected() -> void:
	view.edges_selected = true
	view.selected_face = -1
	view._refresh_face_summary()
	assert_null(_glowing_chip(), "keine SEITE leuchtet, wenn die Kanten gewählt sind")
	assert_eq(_edge_chip().get_theme_color("font_color"), RotatableDieView.SELECT_FACE_COLOR, "der Kanten-Chip leuchtet")

# --- Material-Tooltip (handgesteuertes Overlay) -------------------------------

func test_only_material_faces_wire_a_hover_tooltip() -> void:
	# Vier belegte Seiten -> vier Chips mit Hover-Verbindung, zwei ohne.
	var with_tooltip := 0
	for c in _face_grid().get_children():
		if (c as Button).mouse_entered.get_connections().size() > 0:
			with_tooltip += 1
	assert_eq(with_tooltip, 4, "nur Seiten mit Material bekommen einen Tooltip")

func test_edge_chip_wires_a_hover_tooltip_when_edges_have_material() -> void:
	assert_gt(_edge_chip().mouse_entered.get_connections().size(), 0, "Kanten mit Material -> Tooltip")

func test_edge_chip_has_no_tooltip_without_edge_material() -> void:
	var def := _die()
	def.edge_material = ""
	view.show_die(def)
	assert_eq(_edge_chip().mouse_entered.get_connections().size(), 0, "kahle Kanten -> kein Tooltip")

func test_coupon_slots_wire_a_hover_tooltip() -> void:
	# Auch die Coupon-Slots des Gravur-Bords (Ätzungen/Materialien/Kanten) tragen den
	# handgesteuerten Wirkungs-Tooltip - nicht nur die Seiten-Chips.
	view.run = GameRun.new_run()
	view.run.grant_coupon(Coupon.chisel())
	view._build_coupon_board()
	assert_gt(view.slot_entries.size(), 0, "das Bord hat Slots")
	for entry in view.slot_entries:
		var slot: Button = entry["button"]
		assert_gt(slot.mouse_entered.get_connections().size(), 0, "Slot %s hat Tooltip" % entry["id"])

func test_show_and_hide_face_tooltip() -> void:
	assert_false(view.face_tooltip.visible, "anfangs verborgen")
	view._show_face_tooltip(_edge_chip(), "Bernstein", "Kanten-Wirkung.")
	assert_true(view.face_tooltip.visible)
	assert_eq(view.face_tooltip_title.text, "Bernstein")
	assert_eq(view.face_tooltip_body.text, "Kanten-Wirkung.")
	view._hide_face_tooltip()
	assert_false(view.face_tooltip.visible)
