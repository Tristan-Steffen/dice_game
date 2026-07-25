class_name DiceRowView
## Statische Bauhelfer der gemeinsamen "Würfel-Zeile": Mini-3D-Vorschau,
## Augensumme und Seiten-Chips - identischer Look in Sammlung und Shop.
## Die 3D-Vorschau rendert dauerhaft; der Aufrufer gibt die Zeilen beim
## Schließen frei, damit im Hintergrund nichts weiterrendert.

const DEFAULT_THUMB_SIZE := 72
const CHIP_BORDER := Color(0.72, 0.76, 0.8)  # dezenter Rand der Seiten-Chips (wie die echten Würfel)

## Augensumme (Summe aller Seiten) eines Würfels - Sortier- und Anzeigewert.
static func eye_total(def: DieDefinition) -> int:
	var total := 0
	for value in def.faces:
		total += value
	return total

## Komplette Würfel-Zeile: Kopf "(N ×) Vorschau = Augensumme", darunter die
## Seiten-Chips (aufsteigend, je Wert ein Chip mit ×Anzahl). quantity > 1
## zeigt Shop-Bündel gleicher Würfel nur einmal mit Stückzahl.
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

	# Zeile 2: gruppiert nach Wert UND Seiten-Material - eine Material-Seite
	# bekommt ihre eigene getönte Gruppe neben den einfachen Seiten des Werts.
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 16)
	var groups := {}  # "wert|material" -> {value, material, count}
	for i in def.faces.size():
		var material_id: String = def.materials[i] if i < def.materials.size() else ""
		var key := "%d|%s" % [def.faces[i], material_id]
		if not groups.has(key):
			groups[key] = {"value": def.faces[i], "material": material_id, "count": 0}
		groups[key]["count"] += 1
	var entries: Array = groups.values()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["value"] != b["value"]:
			return a["value"] < b["value"]
		return a["material"] < b["material"])  # "" (ohne Material) vor Material-Gruppen
	for entry in entries:
		chips.add_child(_count_chip(entry["value"], entry["count"], entry["material"]))
	col.add_child(chips)
	return row_panel

## Seiten-Eintrag: "N ×" vor dem Chip bei mehrfachem Vorkommen, z.B. "4× [6]".
static func _count_chip(value: int, count: int, material_id: String = "") -> Control:
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
	entry.add_child(_value_chip(value, material_id))
	return entry

## Würfelseiten-Chip im Look der echten Würfel; material_id tönt ihn in der
## Materialfarbe und nennt das Material im Tooltip.
static func _value_chip(value: int, material_id: String = "") -> Label:
	var chip := Label.new()
	chip.text = "%d" % value
	chip.custom_minimum_size = Vector2(34, 34)
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_theme_font_size_override("font_size", 18)
	chip.add_theme_color_override("font_color", CasinoStyle.INK)
	var box := StyleBoxFlat.new()
	box.bg_color = DieMaterial.tint_for(material_id)  # Weiß ohne Material
	box.border_color = CHIP_BORDER
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(5)
	chip.add_theme_stylebox_override("normal", box)
	if DieMaterial.is_valid_id(material_id):
		chip.tooltip_text = "%s: %s" % [DieMaterial.by_id(material_id).display_name, DieMaterial.by_id(material_id).description]
		chip.mouse_filter = Control.MOUSE_FILTER_STOP  # Labels ignorieren Maus sonst - nötig für den Tooltip
	return chip

## Statische 3D-Vorschau eines Würfels (eigener SubViewport/World3D).
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
	# Eigene Welt ohne Tischfläche - die Boden-Lache hätte hier keinen Grund.
	(die.get_node("RigidBody3D/Faces") as DieFaceDisplay).set_pool_enabled(false)
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
