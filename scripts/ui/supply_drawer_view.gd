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
## Lager-Betrieb: Überfahren einer Kachel liefert ihre Beschreibungszeile ("" beim
## Verlassen). Die Station schweigt hier - dort führt die Hinweiszeile selbst.
signal hovered(info_text: String)

const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")

## Kachelmaß und Spaltenzahl je Kategorie - die Werkbank-Ecke rechnet mit EINER
## gemeinsamen Maßeinheit u, sonst wären die schmalen Schubladen winzig.
## Quadratisch: das Siegel füllt den Platz fast ganz aus und würde sonst
## verzerrt gezeichnet (EngravingRenderer skaliert in seine Rect-Maße).
const CHIP := Vector2(6.9, 6.9)
## Kantenlänge des Siegels im Platz - der Rest ist nur Luft für den Hover-Saum.
const ICON := 6.6
## Randluft zum Fensterrand und Abstand zwischen den Plätzen (in Einheiten u):
## bewusst knapp, damit die Siegel den Platz füllen.
const PAD := 0.7
const GAP := 0.25
## Nachglühen eines getroffenen Platzes (siehe pop).
const AFTERGLOW_TIME := 2.5
## Pseudo-Kategorie des Sonderbestands rechts der Werkbank: die Sonderposten
## (Engraving.SPECIAL_IDS) - in ihrer Kategorien-Schublade machte eine dritte
## Platz-Reihe die ganze Reihe höher und drückte die Werkbank zusammen.
const CATEGORY_SPECIAL := "special"

const COLUMNS := {
	Engraving.CATEGORY_NUMBER: 6,
	Engraving.CATEGORY_MATERIAL: 3,
	Engraving.CATEGORY_DICE: 3,
	CATEGORY_SPECIAL: 1,
}
## Kategorie-Farbe wie das passende Paket im Laden - färbt nur noch die
## Leiterbahn eines ankommenden Paket-Inhalts (siehe scene_root), nicht die Plätze.
const COLORS := {
	Engraving.CATEGORY_NUMBER: Color("#50fa7b"),
	Engraving.CATEGORY_MATERIAL: Color("#ff79c6"),
	Engraving.CATEGORY_DICE: Color("#ffd319"),
	CATEGORY_SPECIAL: Color("#bd93f9"),
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
## Während der Runde gesperrt: die Plätze sind unbenutzbar (kein Aufnehmen),
## bleiben aber überfahrbar (die Beschreibung erscheint weiter).
var _locked := false

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
	var pad := unit * PAD
	var chip := Vector2(CHIP.x * unit, CHIP.y * unit)
	var gap := unit * GAP
	return Vector2(
		cols * chip.x + (cols - 1) * gap + pad * 2.0,
		rows * chip.y + (rows - 1) * gap + pad * 2.0)

## Plätze nach Seltenheit sortiert; innerhalb einer Seltenheit bleibt die
## kanonische Reihenfolge, damit die Geografie stabil liegt.
static func _archetypes_of(drawer_category: String) -> Array[Engraving]:
	var out: Array[Engraving] = []
	for rarity in [Engraving.Rarity.COMMON, Engraving.Rarity.UNCOMMON, Engraving.Rarity.RARE, Engraving.Rarity.EPIC]:
		for archetype in Engraving.all():
			if _belongs_to(archetype, drawer_category) and archetype.rarity == rarity:
				out.append(archetype)
	return out

## Sonderposten liegen NUR im Sonderbestand, nie in ihrer Kategorien-Schublade.
static func _belongs_to(archetype: Engraving, drawer_category: String) -> bool:
	if drawer_category == CATEGORY_SPECIAL:
		return Engraving.is_special_id(archetype.id)
	return archetype.category == drawer_category and not Engraving.is_special_id(archetype.id)

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
## um - der Aufbau ist teuer und bleibt stehen. locked = während der Runde:
## alle Plätze unbenutzbar (aber weiter überfahrbar).
func set_state(held_id: String, enabled_ids: Array[String], locked := false) -> void:
	_held_id = held_id
	_enabled_ids = enabled_ids
	_locked = locked
	restyle()

func rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	slots.clear()

	var pad := int(u * PAD)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = pad
	box.offset_right = -pad
	box.offset_top = pad
	box.offset_bottom = -pad
	box.add_theme_constant_override("separation", int(u * GAP))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS.get(category, 4)
	_grid.add_theme_constant_override("h_separation", int(u * GAP))
	_grid.add_theme_constant_override("v_separation", int(u * GAP))
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_grid)

	var counts := _counts()
	for archetype in _archetypes_of(category):
		var count: int = counts.get(archetype.id, 0)
		var chip := _chip(archetype, count)
		_grid.add_child(chip)
		slots.append({"button": chip, "id": archetype.id, "count": count})
	restyle()

## Beschreibungszeile fürs Hover-Feld: Name, dann die Wirkung - ohne
## Seltenheits-Angabe (die trägt der Lichtsaum des Siegels).
static func info_line(archetype: Engraving) -> String:
	return "%s: %s" % [archetype.display_name, archetype.description]

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

## Ein Platz: das Siegel, so groß wie der Platz. Die ×Anzahl liegt als Marke in
## der Ecke DARÜBER - gestapelt fräße sie die Höhe, die jetzt das Siegel hat.
func _chip(archetype: Engraving, count: int) -> Button:
	var chip := Button.new()
	chip.focus_mode = Control.FOCUS_NONE
	chip.custom_minimum_size = Vector2(CHIP.x * u, CHIP.y * u)
	chip.tooltip_text = "%s\n%s" % [archetype.display_name, archetype.description]
	chip.pressed.connect(func() -> void: tool_pressed.emit(archetype.id))
	var info := info_line(archetype)
	# Überfahren meldet die Beschreibung IMMER (auch an der Station): dort
	# überschreibt sie kurz den Werkzeug-Prompt, im Lager füllt sie die Info-Leiste.
	chip.mouse_entered.connect(func() -> void: hovered.emit(info))
	chip.mouse_exited.connect(func() -> void: hovered.emit(""))

	var face := EngravingRenderer.for_engraving(archetype)
	face.bare = true  # die Schublade IST der Grund - keine zweite Kachel darauf
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset := (CHIP.x - ICON) * 0.5 * u
	face.offset_left = inset
	face.offset_top = inset
	face.offset_right = -inset
	face.offset_bottom = -inset
	chip.add_child(face)
	if count > 1:
		var badge := _label("×%d" % count, u * 1.5, GOLD)
		badge.set_anchors_preset(Control.PRESET_FULL_RECT)
		badge.offset_right = -inset
		badge.offset_bottom = -inset * 0.5
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.add_theme_color_override("font_outline_color", CasinoStyle.INK)
		badge.add_theme_constant_override("outline_size", maxi(2, int(u * 0.4)))
		chip.add_child(badge)
	return chip

## Färbt die Plätze nach Bestand und Betriebsart: Schatten ohne Besitz, volle
## Deckung mit Besitz. Die Siegel stehen NACKT auf der Schublade - keine eigene
## Kachel mit Rand; nur das Werkzeug in der Hand und das Überfahren an der
## Station zeichnen einen goldenen Saum. Im Lager fängt kein Platz Klicks.
func restyle() -> void:
	for entry in slots:
		var chip: Button = entry["button"]
		if not is_instance_valid(chip):
			continue
		var id: String = entry["id"]
		var owned: bool = int(entry["count"]) > 0
		var usable := _ceremony and not _locked and owned \
			and (_enabled_ids.is_empty() or _enabled_ids.has(id))
		chip.disabled = not usable
		# Auch im Lager fangen die Kacheln die Maus - fürs Überfahren (Beschreibung
		# in der Info-Leiste); nur der Klick bleibt der Station vorbehalten.
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if usable \
			else Control.CURSOR_ARROW
		var resting: StyleBox = _chip_box(Color("#2c2757dd"), GOLD, 1.0) \
			if id == _held_id else StyleBoxEmpty.new()
		chip.add_theme_stylebox_override("normal", resting)
		chip.add_theme_stylebox_override("hover", _chip_box(Color("#2c2757dd"), GOLD, 1.0))
		chip.add_theme_stylebox_override("pressed", _chip_box(Color("#3a2f66"), GOLD, 1.0))
		chip.add_theme_stylebox_override("disabled", resting)
		chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		chip.modulate = Color(1, 1, 1, 1.0 if owned else 0.35)

## Bildschirm-Mitte des Platzes id (Ausgangspunkt der Anwende-Leiterbahn);
## Vector2(-1,-1), wenn diese Schublade ihn nicht führt.
func slot_center_px(engraving_id: String) -> Vector2:
	for entry in slots:
		if entry["id"] == engraving_id:
			var chip: Button = entry["button"]
			if is_instance_valid(chip):
				return chip.get_global_rect().get_center()
	return Vector2(-1, -1)

## Lässt den Platz kurz aufpluster - Ankunft eines Paket-Inhalts. Mit glow_color
## bleibt danach ein Nachglühen stehen: der Einschlag IST die Auflösung des
## Pakets, und der Spieler braucht einen Moment, um zu lesen, was da ankam.
func pop(engraving_id: String, glow_color := Color(0, 0, 0, 0)) -> void:
	for entry in slots:
		if entry["id"] != engraving_id:
			continue
		var chip: Button = entry["button"]
		if not is_instance_valid(chip):
			return
		chip.pivot_offset = chip.size * 0.5
		var tween := create_tween()
		tween.tween_property(chip, "scale", Vector2.ONE * 1.25, 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(chip, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if glow_color.a > 0.0:
			_afterglow(chip, glow_color)
		return

## Nachglühen AM Platz: hängt am Chip, damit ein Neuaufbau der Schublade
## (rebuild/set_ceremony) es mitnimmt, und liegt als Überlagerung darüber - die
## feste Platz-Geografie darf sich davon nicht verschieben.
func _afterglow(chip: Button, color: Color) -> void:
	var glow := Panel.new()
	glow.name = "Afterglow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bleed := u * 0.5
	glow.offset_left = -bleed
	glow.offset_top = -bleed
	glow.offset_right = bleed
	glow.offset_bottom = bleed
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color.r, color.g, color.b, 0.16)
	box.border_color = color
	box.set_border_width_all(maxi(1, int(u * 0.28)))
	box.set_corner_radius_all(int(u * 0.9))
	glow.add_theme_stylebox_override("panel", box)
	chip.add_child(glow)
	var tween := glow.create_tween()
	tween.tween_property(glow, "modulate:a", 0.0, AFTERGLOW_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(glow.queue_free)

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
