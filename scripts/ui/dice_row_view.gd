class_name DiceRowView
## Baut die gemeinsame "Würfel-Zeile": Mini-3D-Vorschau des Würfels, seine
## Augensumme und die Seiten-Übersicht (je vorkommender Wert ein Chip mit
## ×Anzahl). Genau dieser Look wird sowohl in der Würfel-Sammlung (scene_root)
## als auch bei den Shop-Angeboten (ShopController) verwendet, damit beide
## identisch aussehen. Reine statische Bauhelfer - keine eigene Node-Instanz.
##
## Die 3D-Vorschau rendert dauerhaft (UPDATE_ALWAYS); der Aufrufer gibt die
## Zeilen frei, sobald die Liste geschlossen wird, damit im Hintergrund nichts
## weiterrendert (siehe scene_root._clear_dice_list / ShopController._clear_offers).

const DEFAULT_THUMB_SIZE := 72
const CHIP_BORDER := Color(0.72, 0.76, 0.8)  # dezenter Rand der Seiten-Chips (wie die echten Würfel)

## Augensumme (Summe aller Seiten) eines Würfels - Sortier- und Anzeigewert.
static func eye_total(def: DieDefinition) -> int:
	var total := 0
	for value in def.faces:
		total += value
	return total

## Eine komplette Würfel-Zeile: PanelContainer mit zwei übereinander liegenden
## Zeilen.
##   Zeile 1 (Kopf): (optionaler Stück-Multiplikator) Mini-Vorschau "=" Augensumme
##                   - liest sich als "N Würfel = so viele Augen".
##   Zeile 2 (Zusammensetzung): die Seiten-Chips (aufsteigend, je Wert ein Chip
##                   mit ×Anzahl) - woraus der Würfel besteht.
## thumb_size steuert die Kantenlänge der 3D-Vorschau; quantity > 1 stellt ein
## "N ×" links vor die Vorschau (für Shop-Bündel gleicher Würfel, die nur einmal
## gezeigt werden - siehe ShopController).
static func build_row(def: DieDefinition, thumb_size: int = DEFAULT_THUMB_SIZE, quantity: int = 1) -> PanelContainer:
	var row_panel := PanelContainer.new()
	var row_box := StyleBoxFlat.new()
	row_box.bg_color = Color(1, 1, 1, 0.05)
	row_box.set_corner_radius_all(8)
	row_box.set_content_margin_all(8)
	row_panel.add_theme_stylebox_override("panel", row_box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	row_panel.add_child(col)

	# --- Zeile 1: (Stückzahl ×) Vorschau = Augensumme ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)

	if quantity > 1:
		var qty := Label.new()
		qty.text = "%d×" % quantity
		qty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		CasinoStyle.style_score_label(qty, 30, CasinoStyle.GOLD)
		head.add_child(qty)

	head.add_child(build_thumb(def, thumb_size))

	var equals := Label.new()
	equals.text = "="
	equals.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	CasinoStyle.style_score_label(equals, 26, CasinoStyle.CREAM)
	head.add_child(equals)

	var total_label := Label.new()
	total_label.text = "%d" % eye_total(def)
	total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	CasinoStyle.style_score_label(total_label, 26, CasinoStyle.GOLD)
	head.add_child(total_label)

	# --- Zeile 2: Zusammensetzung (Seiten-Übersicht) ---
	# Weiter Abstand ZWISCHEN den Wert-Gruppen (der Multiplikator klebt eng an
	# seinem eigenen Chip, siehe _count_chip).
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 16)
	var counts := {}
	for value in def.faces:
		counts[value] = counts.get(value, 0) + 1
	var values := counts.keys()
	values.sort()
	for value in values:
		chips.add_child(_count_chip(value, counts[value]))
	col.add_child(chips)
	return row_panel

## Ein Seiten-Eintrag: bei mehrfachem Vorkommen ein "N ×" davor, dann der weiße
## Würfelseiten-Chip mit NUR der Augenzahl (keine weitere Zahl im weißen Feld) -
## also z.B. "4 × [6]". Bei count == 1 nur der Chip.
static func _count_chip(value: int, count: int) -> Control:
	var entry := HBoxContainer.new()
	entry.add_theme_constant_override("separation", 2)
	entry.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if count > 1:
		var mult := Label.new()
		mult.text = "%d×" % count
		mult.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mult.add_theme_font_size_override("font_size", 18)
		mult.add_theme_color_override("font_color", CasinoStyle.CREAM)
		entry.add_child(mult)
	entry.add_child(_value_chip(value))
	return entry

## Der weiße, abgerundete Würfelseiten-Chip mit der dunklen Augenzahl (im Look
## der echten Würfel) - enthält ausschließlich den Seitenwert.
static func _value_chip(value: int) -> Label:
	var chip := Label.new()
	chip.text = "%d" % value
	chip.custom_minimum_size = Vector2(34, 34)
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_theme_font_size_override("font_size", 18)
	chip.add_theme_color_override("font_color", CasinoStyle.INK)
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.border_color = CHIP_BORDER
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(5)
	chip.add_theme_stylebox_override("normal", box)
	return chip

## Statische 3D-Vorschau eines Würfels (eigener SubViewport mit eigener World3D).
## Baut denselben Würfel wie überall (DieBuilder), stellt ihn schräg dar und
## tönt ihn nach seiner Art (siehe DiceController.KIND_TINTS).
static func build_thumb(def: DieDefinition, size: int = DEFAULT_THUMB_SIZE) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(size, size)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = Vector2i(size, size)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)

	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-50, 35, 0)
	key_light.light_energy = 1.1
	viewport.add_child(key_light)

	var camera := Camera3D.new()
	camera.fov = 30.0
	# looking_at als reine Transform-Mathematik statt camera.look_at, das den
	# Knoten schon im Baum bräuchte (hier wird der Würfel noch losgelöst gebaut).
	camera.transform = Transform3D(Basis(), Vector3(0, 2.6, 5.4)).looking_at(Vector3.ZERO, Vector3.UP)
	viewport.add_child(camera)

	var die := DieBuilder.build()
	viewport.add_child(die)
	die.rotation_degrees = Vector3(-20, 30, 0)
	var body: RigidBody3D = die.get_node("RigidBody3D")
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	var faces: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
	faces.apply_definition(def)
	faces.set_tint(DiceController.KIND_TINTS.get(def.style_id, Color.WHITE))
	return container
