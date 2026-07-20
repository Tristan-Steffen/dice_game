class_name SupplyDrawerView
extends Panel
## Eine Vorrats-Schublade der Werkbank - je Gravur-Kategorie eine, in der Farbe
## des passenden Pakets im Laden (grün/magenta/gold). Sie hat ZWEI Betriebsarten
## auf demselben Inhalt:
##   Lager   - reine Anzeige des Bestands (auch aus der Übersicht lesbar).
##   Station - während der Gravur-Zeremonie ist sie das Werkzeug-Bord: gültige
##             Gravuren leuchten, ein Klick nimmt sie auf.
## Die Plätze liegen FEST (alle Archetypen der Kategorie, Nicht-Besessenes als
## Schatten), damit sich das Auge die Geografie merkt und der Moduswechsel nur
## die Farbe ändert - nie die Anordnung.

## Werkzeug aufgenommen/abgelegt (nur in der Station-Betriebsart).
signal tool_pressed(engraving_id: String)

const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")

## Kachelmaß und Spaltenzahl je Kategorie - die Werkbank-Ecke rechnet mit EINER
## gemeinsamen Maßeinheit u, sonst wären die schmalen Schubladen winzig.
const CHIP := Vector2(5.4, 4.2)
const COLUMNS := {
	Engraving.CATEGORY_NUMBER: 6,
	Engraving.CATEGORY_MATERIAL: 3,
	Engraving.CATEGORY_DICE: 3,
}
const TITLES := {
	Engraving.CATEGORY_NUMBER: "ZAHLEN",
	Engraving.CATEGORY_MATERIAL: "MATERIAL",
	Engraving.CATEGORY_DICE: "KANTEN",
}
const COLORS := {
	Engraving.CATEGORY_NUMBER: Color("#50fa7b"),
	Engraving.CATEGORY_MATERIAL: Color("#ff79c6"),
	Engraving.CATEGORY_DICE: Color("#ffd319"),
}

@export var category: String = Engraving.CATEGORY_NUMBER

var run: GameRun:
	set(value):
		if run == value:
			return
		if run != null and run.engravings_changed.is_connected(rebuild):
			run.engravings_changed.disconnect(rebuild)
		run = value
		if run != null:
			run.engravings_changed.connect(rebuild)
		rebuild()

## Gemeinsame Maßeinheit der Werkbank-Ecke (setzt scene_root über place).
var u := 8.0
## Je Platz {button, id, count} - Reihenfolge = Archetyp-Reihenfolge.
var slots: Array[Dictionary] = []

## Station-Betriebsart aktiv, und welches Werkzeug gerade in der Hand liegt.
var _ceremony := false
var _held_id := ""
## Welche Plätze die Station gerade zulässt (leer = alle besessenen).
var _enabled_ids: Array[String] = []

var _grid: GridContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # die Kacheln fangen selbst
	clip_contents = true
	add_theme_stylebox_override("panel", TableScreen.window_style())
	rebuild()

## Fenstermaß, das diese Kategorie bei Einheit unit braucht (scene_root legt die
## Reihe danach aus - die Schubladen sind so breit wie ihr Inhalt).
static func size_for(drawer_category: String, unit: float) -> Vector2:
	var count := _archetypes_of(drawer_category).size()
	var cols: int = COLUMNS.get(drawer_category, 4)
	var rows := int(ceil(float(count) / float(cols)))
	var pad := unit * 1.6
	var chip := Vector2(CHIP.x * unit, CHIP.y * unit)
	var gap := unit * 0.5
	return Vector2(
		cols * chip.x + (cols - 1) * gap + pad * 2.0,
		unit * 2.6 + rows * chip.y + (rows - 1) * gap + pad * 2.0)

## Plätze nach Seltenheit sortiert; innerhalb einer Seltenheit bleibt die
## kanonische Reihenfolge, damit die Geografie stabil liegt.
static func _archetypes_of(drawer_category: String) -> Array[Engraving]:
	var out: Array[Engraving] = []
	for rarity in [Engraving.Rarity.COMMON, Engraving.Rarity.UNCOMMON, Engraving.Rarity.RARE]:
		for archetype in Engraving.all():
			if archetype.category == drawer_category and archetype.rarity == rarity:
				out.append(archetype)
	return out

func place(rect: Rect2, unit: float) -> void:
	position = rect.position
	size = rect.size
	u = unit
	rebuild()

## Schaltet in die Station-Betriebsart (Werkzeug-Bord) und zurück.
func set_ceremony(active: bool) -> void:
	if _ceremony == active:
		return
	_ceremony = active
	_held_id = ""
	restyle()

## Welches Werkzeug in der Hand liegt und welche Plätze nutzbar sind; stylt nur
## um - der Aufbau ist teuer und bleibt stehen.
func set_state(held_id: String, enabled_ids: Array[String]) -> void:
	_held_id = held_id
	_enabled_ids = enabled_ids
	restyle()

func rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	slots.clear()

	var accent: Color = COLORS.get(category, TEXT_COLOR)
	var pad := int(u * 1.6)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = pad
	box.offset_right = -pad
	box.offset_top = pad
	box.offset_bottom = -pad
	box.add_theme_constant_override("separation", int(u * 0.5))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.add_child(_label(TITLES.get(category, category), u * 2.2, accent))

	_grid = GridContainer.new()
	_grid.columns = COLUMNS.get(category, 4)
	_grid.add_theme_constant_override("h_separation", int(u * 0.5))
	_grid.add_theme_constant_override("v_separation", int(u * 0.5))
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_grid)

	var counts := _counts()
	for archetype in _archetypes_of(category):
		var count: int = counts.get(archetype.id, 0)
		var chip := _chip(archetype, count)
		_grid.add_child(chip)
		slots.append({"button": chip, "id": archetype.id, "count": count})
	restyle()

## Bestand je Gravur-id (Testmodus: alles einmal vorhanden).
func _counts() -> Dictionary:
	var counts := {}
	if run == null:
		return counts
	if run.unlimited_engravings:
		for archetype in _archetypes_of(category):
			counts[archetype.id] = 1
		return counts
	for engraving in run.owned_engravings:
		counts[engraving.id] = counts.get(engraving.id, 0) + 1
	return counts

## Ein Platz: das Siegel, bei Besitz mit ×Anzahl. Ohne Besitz nur der Schatten.
func _chip(archetype: Engraving, count: int) -> Button:
	var chip := Button.new()
	chip.focus_mode = Control.FOCUS_NONE
	chip.custom_minimum_size = Vector2(CHIP.x * u, CHIP.y * u)
	chip.tooltip_text = "%s (%s)\n%s" % [archetype.display_name,
		Engraving.rarity_name(archetype.rarity), archetype.description]
	chip.pressed.connect(func() -> void: tool_pressed.emit(archetype.id))

	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(stack)
	var face := EngravingRenderer.for_engraving(archetype)
	face.custom_minimum_size = Vector2.ONE * u * 2.6
	var stage := CenterContainer.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(face)
	stack.add_child(stage)
	if count > 1:
		var badge := _label("×%d" % count, u * 1.4, GOLD)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(badge)
	return chip

## Färbt die Plätze nach Bestand und Betriebsart: Schatten ohne Besitz, Saum in
## der Seltenheitsfarbe mit Besitz, Gold für das Werkzeug in der Hand. In der
## Lager-Betriebsart fängt kein Platz Klicks.
func restyle() -> void:
	for entry in slots:
		var chip: Button = entry["button"]
		if not is_instance_valid(chip):
			continue
		var id: String = entry["id"]
		var owned: bool = int(entry["count"]) > 0
		var usable := _ceremony and owned \
			and (_enabled_ids.is_empty() or _enabled_ids.has(id))
		chip.disabled = not usable
		chip.mouse_filter = Control.MOUSE_FILTER_STOP if _ceremony else Control.MOUSE_FILTER_IGNORE
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if usable \
			else Control.CURSOR_ARROW
		var seam: Color = EngravingRenderer.SEAM_COLORS[Engraving.Rarity.COMMON]
		if id == _held_id:
			seam = GOLD
		elif owned:
			seam = COLORS.get(category, TEXT_COLOR)
		var alpha := 0.9 if owned else 0.22
		chip.add_theme_stylebox_override("normal",
			_chip_box(Color("#221e46cc") if owned else Color("#181534aa"), seam, alpha))
		chip.add_theme_stylebox_override("hover", _chip_box(Color("#2c2757dd"), GOLD, 1.0))
		chip.add_theme_stylebox_override("pressed", _chip_box(Color("#3a2f66"), GOLD, 1.0))
		chip.add_theme_stylebox_override("disabled",
			_chip_box(Color("#181534aa"), seam, alpha * 0.6))
		chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		chip.modulate = Color(1, 1, 1, 1.0 if owned else 0.55)

## Bildschirm-Mitte des Platzes id (Ausgangspunkt der Anwende-Leiterbahn);
## Vector2(-1,-1), wenn diese Schublade ihn nicht führt.
func slot_center_px(engraving_id: String) -> Vector2:
	for entry in slots:
		if entry["id"] == engraving_id:
			var chip: Button = entry["button"]
			if is_instance_valid(chip):
				return chip.get_global_rect().get_center()
	return Vector2(-1, -1)

func _label(text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _chip_box(bg: Color, border: Color, border_alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = Color(border.r, border.g, border.b, border_alpha)
	box.set_border_width_all(maxi(1, int(u * 0.2)))
	box.set_corner_radius_all(int(u * 0.6))
	box.set_content_margin_all(int(u * 0.25))
	return box
