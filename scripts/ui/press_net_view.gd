class_name PressNetView
extends Control
## Die EINE Netz-Anzeige der Werkstatt, in zwei Größen.
##
## Als INSTANZ ist sie das SUMMEN-NETZ: das aufgeklappte Kreuz des Zielwürfels
## (DieNetView-Grammatik), aber gezeichnet aus dem GEISTER-Würfel, den die
## Projektion ergäbe. Eine Zelle, deren Augenzahl steigt, liest "3→7" in Grün;
## Material, Runen, Veredelung und Pointer stehen schon im neuen Zustand, und eine
## VERPUFFTE Zelle grault aus und nennt beim Überfahren ihren Grund.
##
## Als STATIK zeichnet sie das MINI-NETZ einer Kassette (stamp_net): dieselbe
## Kreuzform, je Zelle die Glyphe ihrer StampNet-Sorte. Die Karte in der
## Serien-Reihe trägt es, der Laden nennt daneben seine Zeile.
##
## Reine Anzeige: gerechnet hat SeriesResolver, gebucht GameRun.

## Neutraler Rahmen einer Zelle, die die Serie nicht anfaßt.
const CHIP_BORDER := Color(0.72, 0.76, 0.8)
## Eine Zelle, die die Serie ÄNDERT: goldener Saum.
const TOUCHED_BORDER := CasinoStyle.GOLD
## Verpuffte Zelle: Füllung und Ziffer dimmen aus.
const DIM_ALPHA := 0.30
const DIM_NUMBER := Color(0.35, 0.35, 0.42)
## Vorschau: steigt GRÜN, sinkt warm-rot - dieselbe Lesart wie am liegenden
## Würfel, aber für HELLEN Grund gemischt. Die Netz-Zelle trägt die Materialfarbe,
## und ohne Material ist sie WEISS: das helle Grün des 3D-Würfels
## (DieFaceDisplay.PREVIEW_NUMBER_COLOR) verschwand darauf samt seinem weißen Saum
## (Spieler-Meldung 2026-09-04). Gleicher Farbton, dunkler Wert.
const PREVIEW_UP := Color(0.07, 0.42, 0.16)
const PREVIEW_DOWN := Color(0.62, 0.13, 0.08)
## Was ein Beitrag der überfahrenen Karte NICHT ist, verblaßt (Hover-Highlight).
const GHOST_ALPHA := 0.35

## Farben der Mini-Netz-Zellen: Wert-Zellen cyan, Operatoren amber - dieselbe
## Trennung wie an den Kassetten der Serien-Reihe.
const VALUE_TINT := Color("#8be9fd")
const OPERATOR_TINT := Color("#ffb347")
const EMPTY_CELL := Color("#12101f")
const EMPTY_RIM := Color("#2c2740")
## Eine von der Schablone AUFGENOMMENE Zelle: sie verglimmt, sie verschwindet nicht.
const DRAINED_MODULATE := Color(0.34, 0.34, 0.40)

## Klartext der Verpuff-Gründe - EINE Quelle, die Vorschau nennt sie beim Namen.
const FIZZLE_TEXT := {
	SeriesResolver.FIZZLE_NAKED: "verpufft: die Seite trägt kein Material",
	SeriesResolver.FIZZLE_DOPED: "verpufft: die Seite ist schon veredelt",
	SeriesResolver.FIZZLE_BURNED: "verpufft: Einbrand sperrt das Übermalen",
	SeriesResolver.FIZZLE_POINTER: "verpufft: kein Nachbar dieser Seite",
}

## Der Zielwürfel (null = keiner gewählt) und die Projektion der Serie ({} = keine).
var def: DieDefinition
var cell := 8.0
var projection: Dictionary = {}
## Seiten, die die gerade ÜBERFAHRENE Karte beiträgt (leer = kein Hover): alles
## andere verblaßt, damit man den Beitrag EINER Karte im Summen-Netz sieht.
var highlight: Array[int] = []
## Dauer des nächsten Zähl-Takts (0 = die Ziffern springen). Ein gesetzter Takt
## gilt genau EINEN Aufbau - Zahlen ticken, sie springen nie.
var tick_time := 0.0

## Zellen nach physischem Seiten-Index - der Hover-Hinweis fragt sie ab.
var _chips: Array[Panel] = []
## Ihre Ziffern (der Zähl-Takt schreibt nur sie).
var _labels: Array[Label] = []
var _fizzles: Dictionary = {}  # Seite -> Grund
## Der Zähl-Takt: was auf den Zellen STEHT, woher es lief und wohin.
var _shown: Array[int] = []
var _from: Array[int] = []
var _goal: Array[int] = []
var _before: Array[int] = []
var _tick_left := 0.0
var _tick_span := 0.0

func _init() -> void:
	name = "SeriesNet"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

## Baut das Summen-Netz neu. cell = Zellkante in Pixeln; alles andere sind die
## Felder oben, die der Aufrufer vorher setzt.
func build() -> void:
	set_process(false)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_chips.clear()
	_labels.clear()
	_fizzles.clear()
	var takt := tick_time
	tick_time = 0.0  # ein Takt gilt genau einen Aufbau
	custom_minimum_size = DieNetView.net_size(cell)
	size = custom_minimum_size
	if def == null:
		_shown.clear()
		return
	for entry: Dictionary in projection.get("fizzled", []):
		_fizzles[int(entry.get("face", -1))] = String(entry.get("reason", ""))
	var ghost := preview_die()
	_before.clear()
	_goal.clear()
	for face in 6:
		_before.append(int(def.faces[face]))
		_goal.append(int(ghost.faces[face]))
	# TICKEN statt springen: die Ziffern laufen von ihrem letzten Stand zum neuen.
	# Ohne Takt (oder ohne Vorstand) steht der Zielwert sofort da.
	var ticking := takt > 0.0 and _shown.size() == 6
	_from = _shown.duplicate() if ticking else _goal.duplicate()
	_shown = _from.duplicate()
	_chips.resize(6)
	_labels.resize(6)
	for face in 6:
		var chip := _face_chip(face, ghost)
		chip.position = DieNetView.cell_position(face, cell)
		chip.size = Vector2.ONE * cell
		_chips[face] = chip
		add_child(chip)
		_write_face(face)
	# Essenz-Chip, Runen, Veredelungs-Plaketten und Pointer-Pfeile obendrauf - die
	# Pfeile zuletzt, sie liegen über den Zellrändern. Alle vom GEISTER: die
	# Vorschau zeigt den Zustand NACH der Serie.
	add_child(DieNetView.edge_chip(ghost, cell))
	for glyph in DieNetView.rune_glyphs(ghost, cell):
		add_child(glyph)
	for badge in DieNetView.level_badges(ghost, cell):
		add_child(badge)
	for arrow in DieNetView.pointer_arrows(ghost, cell):
		add_child(arrow)
	if ticking:
		_tick_span = takt
		_tick_left = takt
		set_process(true)

# --- Der ZÄHL-TAKT ---------------------------------------------------------------

func _process(delta: float) -> void:
	_tick_left = maxf(_tick_left - delta, 0.0)
	var step := clampf(1.0 - _tick_left / maxf(_tick_span, 0.001), 0.0, 1.0)
	for face in mini(_shown.size(), 6):
		var value := int(roundf(lerpf(float(_from[face]), float(_goal[face]), step)))
		if value == _shown[face]:
			continue
		_shown[face] = value
		_write_face(face)
	if _tick_left <= 0.0:
		settle_ticks()

## Endzustand zuerst: die Ziffern stehen auf ihrem Ziel, wo der Takt auch stand.
func settle_ticks() -> void:
	set_process(false)
	_tick_left = 0.0
	for face in mini(_shown.size(), 6):
		if _shown[face] == _goal[face]:
			continue
		_shown[face] = _goal[face]
		_write_face(face)

## Es gibt keinen Stand mehr, von dem zu ticken wäre (anderer Würfel, neuer Lauf).
func reset_ticks() -> void:
	set_process(false)
	_shown.clear()

## Die Ziffer EINER Zelle: sie nennt den Stand, nicht das Ziel. Eine verpuffte
## Zelle schweigt - dort steht der Grund, nicht die Rechnung.
func _write_face(face: int) -> void:
	if face < 0 or face >= _labels.size() or _fizzles.has(face):
		return
	var label: Label = _labels[face]
	if label == null or not is_instance_valid(label):
		return
	var shown: int = _shown[face]
	var before: int = _before[face]
	label.text = "%d→%d" % [before, shown] if shown != before else str(before)

## Der GEISTER-Würfel: der Zielwürfel, wie die Serie ihn zurückließe. Er geht durch
## dieselben DieDefinition-Schreibwege wie die Buchung, damit Veredelung, Runen-
## Plätze und Einbrand-Regel in der Vorschau genauso greifen.
func preview_die() -> DieDefinition:
	if def == null:
		return null
	var ghost := def.instantiate()
	if projection.is_empty():
		return ghost
	for face in SeriesResolver.FACES:
		ghost.faces[face] = int(projection["faces_after"][face])
		var material := String(projection["materials"][face])
		if material != "":
			ghost.set_face_material(face, material)
		if bool(projection["doped"][face]):
			ghost.dope(face)
		var runes: Array = projection["runes"][face]
		for slot in runes.size():
			if String(runes[slot]) != "":
				ghost.set_rune(face, String(runes[slot]), slot, DieDefinition.MAX_RUNE_SLOTS)
		var target := int(projection["pointers"][face])
		if target >= 0:
			ghost.pointers[face] = target
	return ghost

## Ändert die Serie diese Seite überhaupt?
func touches(face: int) -> bool:
	if projection.is_empty() or def == null:
		return false
	if int(projection["bonus"][face]) != 0:
		return true
	if String(projection["materials"][face]) != "":
		return true
	if bool(projection["doped"][face]):
		return true
	if not Array(projection["runes"][face]).is_empty():
		return true
	return int(projection["pointers"][face]) >= 0

## Eine Seiten-Zelle: die PLATTE trägt das Maß, die Ziffer liegt darin (dieselbe
## Regel wie im Würfelnetz - eine Zelle, die selbst ein Label ist, klemmt sich an
## ihrer Schrift hochkant).
func _face_chip(face: int, ghost: DieDefinition) -> Panel:
	var fill := DieMaterial.tint_for(ghost.materials[face], ghost.material_level(face))
	var before: int = def.faces[face]
	var after: int = ghost.faces[face]
	var faded := not highlight.is_empty() and not highlight.has(face)
	var dim := _fizzles.has(face)
	var border := CHIP_BORDER
	var width := maxi(2, int(cell * 0.06))
	if dim:
		fill = Color(fill.r, fill.g, fill.b, fill.a * DIM_ALPHA)
		border = CHIP_BORDER.darkened(0.35)
	elif touches(face):
		border = TOUCHED_BORDER
		width = maxi(2, int(cell * 0.11))
	elif Essence.is_valid_id(ghost.essence_id):
		border = Essence.glow_for(ghost.essence_id)
		width = maxi(2, int(cell * 0.1))

	var chip := Panel.new()
	# Name mit Seiten-Index: Godot vergibt sonst @Panel@N, und dann ist im Baum
	# nicht mehr zu sehen, welche Zelle welche ist.
	chip.name = "NetCell%d" % face
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _chip_box(fill, border, width))

	var label := Label.new()
	label.name = "Value"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tint := CasinoStyle.INK
	if dim:
		tint = DIM_NUMBER
		label.text = str(before)
		label.add_theme_font_size_override("font_size", DieNetView.face_font_size(cell))
	elif after != before:
		tint = PREVIEW_UP if after > before else PREVIEW_DOWN
		label.text = "%d→%d" % [before, after]
		label.add_theme_font_size_override("font_size", maxi(6, int(cell * 0.28)))
	else:
		label.text = str(after)
		label.add_theme_font_size_override("font_size", DieNetView.face_font_size(cell))
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", fill)
	label.add_theme_constant_override("outline_size", maxi(1, int(cell * 0.06)))
	chip.add_child(label)
	if face < _labels.size():
		_labels[face] = label  # der Zähl-Takt schreibt nur noch diese Zeile
	if faded:
		chip.modulate = Color(1.0, 1.0, 1.0, GHOST_ALPHA)
	return chip

func _chip_box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(maxi(1, width))
	box.set_corner_radius_all(int(cell * 0.2))
	return box

## Die Zelle unter einem Display-Pixel (-1 = keine, DieNetView.EDGE über dem
## Essenz-Chip) - dieselbe Geometrie wie jedes andere Netz.
func face_at_pixel(pixel: Vector2) -> int:
	var rect := get_global_rect()
	if not rect.has_point(pixel):
		return -1
	return DieNetView.face_at(pixel - rect.position, cell)

## Erklärzeile zu einer Zelle: der Verpuff-Grund geht vor (er ist die einzige
## Auskunft, die das Netz selbst gibt), sonst spricht der GEISTER-Würfel - dieselbe
## eine Textquelle wie jedes andere Netz.
func hint_for_face(face: int) -> String:
	if _fizzles.has(face):
		return String(FIZZLE_TEXT.get(String(_fizzles[face]), "verpufft"))
	return DieNetView.hint_for(preview_die(), face)

# --- Das MINI-NETZ einer Kassette ------------------------------------------------

## Das Prägenetz einer Karte als Kreuz: je Zelle die Glyphe ihrer Sorte, leere
## Zellen bleiben dunkel. Reine Anzeige, ohne Maus. drained nennt die Seiten, die
## eine Schablone schon AUFGENOMMEN hat - sie dunkeln ab.
static func stamp_net(net: Array, cell: float, accent: Color = VALUE_TINT,
		drained: Array = []) -> Control:
	var span := DieNetView.net_size(cell)
	var root := Control.new()
	root.name = "StampNet"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = span
	root.size = root.custom_minimum_size
	for face in StampNet.FACES:
		var dim := face < drained.size() and bool(drained[face])
		var chip := _stamp_cell(StampNet.cell_at(net, face), cell, accent, dim)
		chip.position = DieNetView.cell_position(face, cell)
		chip.size = Vector2.ONE * cell
		root.add_child(chip)
	return root

## Dasselbe Kreuz in seinem HOCHKANTEN Rahmen - die EINE Ausrichtung, in der eine
## Kassette es trägt (Welle L): sie liegt überall quer gerollt und dreht es im Bild
## wieder auf. Vierteldrehung IM UHRZEIGERSINN, der Versatz setzt das gedrehte
## Rechteck bündig in den Rahmen; gedreht wird der RAHMEN, nie der Inhalt.
static func stamp_net_upright(net: Array, cell: float, accent: Color = VALUE_TINT,
		drained: Array = []) -> Control:
	var root := stamp_net(net, cell, accent, drained)
	var span := root.size
	var host := Control.new()
	host.name = "StampNetTurned"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.custom_minimum_size = Vector2(span.y, span.x)
	host.size = host.custom_minimum_size
	root.rotation = PI * 0.5
	root.position = Vector2(span.y, 0.0)
	host.add_child(root)
	return host

## Welche Zelle des HOCHKANTEN Netzes an dieser Stelle liegt (-1 = keine). Der
## Anteil (0..1 je Achse, Ursprung oben links) wird um die Vierteldrehung des
## Rahmens zurückgedreht und dann dem Kreuz zugeordnet - dieselbe Drehung, die
## stamp_net_upright hinlegt, nur rückwärts. Anteile statt Pixel: der Aufrufer
## mißt am Quad der Karte, nicht an der Backung.
static func upright_face_at(share: Vector2) -> int:
	if share.x < 0.0 or share.x > 1.0 or share.y < 0.0 or share.y > 1.0:
		return -1
	var span := DieNetView.net_size(1.0)
	var flat := Vector2(share.y * span.x, (1.0 - share.x) * span.y)
	for face in StampNet.FACES:
		if Rect2(DieNetView.cell_position(face, 1.0), Vector2.ONE).has_point(flat):
			return face
	return -1

## EINE Zelle des Mini-Netzes. Die Sorte entscheidet Füllung und Zeichen: Zahl
## "+n", Material seine Farbe, Rune ihr Linienzug (dieselbe Quelle wie am Würfel),
## Operator seine Glyphe, Veredelung ihre Plakette, Pointer ein Pfeil.
static func _stamp_cell(entry: Dictionary, cell: float, accent: Color,
		dim := false) -> Panel:
	var kind := StampNet.kind_of(entry)
	var fill := EMPTY_CELL
	var rim := EMPTY_RIM
	var text := ""
	var tint := accent
	match kind:
		StampNet.KIND_VALUE:
			text = "+%d" % int(entry.get("value", 0))
			rim = VALUE_TINT
			tint = VALUE_TINT
		StampNet.KIND_OPERATOR:
			text = StampNet.operator_glyph(String(entry.get("id", "")))
			rim = OPERATOR_TINT
			tint = OPERATOR_TINT
		StampNet.KIND_MATERIAL:
			fill = DieMaterial.tint_for(String(entry.get("id", "")), 1)
			rim = fill.lightened(0.3)
		StampNet.KIND_DOPE:
			rim = accent
		StampNet.KIND_RUNE:
			rim = accent
		StampNet.KIND_POINTER:
			text = "→%d" % (int(entry.get("to", 0)) + 1)
			rim = DieNetView.POINTER_COLOR
			tint = DieNetView.POINTER_COLOR
	var chip := Panel.new()
	chip.name = "StampCell"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(maxi(1, int(cell * 0.08)))
	box.set_corner_radius_all(maxi(1, int(cell * 0.2)))
	chip.add_theme_stylebox_override("panel", box)
	if kind == StampNet.KIND_RUNE:
		chip.add_child(_stamp_rune(String(entry.get("id", "")), cell))
	elif kind == StampNet.KIND_DOPE:
		chip.add_child(_stamp_dope(cell))
	elif text != "":
		chip.add_child(_stamp_label(text, cell, tint))
	# AUFGENOMMEN: Füllung, Saum und Zeichen fallen zugleich - ein Ton, keine
	# zweite Farbtabelle.
	if dim:
		chip.modulate = DRAINED_MODULATE
	return chip

static func _stamp_label(text: String, cell: float, tint: Color) -> Label:
	var label := Label.new()
	label.name = "CellMark"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", maxi(6, int(cell * 0.44)))
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", CasinoStyle.INK)
	label.add_theme_constant_override("outline_size", maxi(1, int(cell * 0.07)))
	label.text = text
	return label

## Der Runen-Linienzug FÜLLT hier die Zelle (Platz 0 ist die ganze Kachel) - im
## Mini-Netz gibt es keine Ziffer, die er umgehen müßte.
static func _stamp_rune(rune_id: String, cell: float) -> Control:
	var rune := Rune.by_id(rune_id)
	var mark := DieNetView.RuneGlyph.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size = Vector2.ONE * cell
	if rune == null:
		return mark
	mark.lines = Rune.glyph_lines(rune.glyph)
	mark.weights = Rune.glyph_weights(rune.glyph)
	mark.tint = rune.tint
	mark.core = rune.core
	return mark

## Die Veredelungs-Zelle trägt die Plakette des Netzes, mittig und groß.
static func _stamp_dope(cell: float) -> Control:
	var badge := DieNetView.LevelBadge.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.tint = Color("#9be7ff")
	var side := cell * 0.62
	badge.size = Vector2.ONE * side
	badge.position = Vector2.ONE * (cell - side) * 0.5
	return badge
# --- Das SUMMEN-NETZ einer ganzen Serie ------------------------------------------

## Die REINE Summe der gesteckten Prägenetze als Kreuz, in derselben
## KARTEN-Grammatik wie stamp_net - nur aus einer PROJEKTION statt aus einem Netz.
## Zielunabhängig: gerechnet hat SeriesResolver OHNE Würfel, hier wird nur gemalt.
static func sum_net(projection: Dictionary, cell: float) -> Control:
	var root := Control.new()
	root.name = "SeriesSum"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = DieNetView.net_size(cell)
	root.size = root.custom_minimum_size
	for face in StampNet.FACES:
		var chip := _sum_cell(projection, face, cell)
		chip.position = DieNetView.cell_position(face, cell)
		chip.size = Vector2.ONE * cell
		root.add_child(chip)
	return root

## EINE Zelle der Summe. Sie trägt MEHRERE Kanäle zugleich (anders als eine
## Karten-Zelle): Material füllt sie, die Zahl steht darin, Runen sitzen als kleine
## Glyphen in den unteren Ecken - und ein Pointer, den die Zahl verdrängt, färbt
## wenigstens den Saum.
static func _sum_cell(projection: Dictionary, face: int, cell: float) -> Panel:
	var material := _sum_string(projection, "materials", face)
	var bonus := _sum_int(projection, "bonus", face, 0)
	var pointer := _sum_int(projection, "pointers", face, -1)
	var runes := _sum_runes(projection, face)
	var fill := EMPTY_CELL
	var rim := EMPTY_RIM
	var text := ""
	var tint := VALUE_TINT
	if material != "":
		var level := DieMaterial.MAX_LEVEL if _sum_flag(projection, "doped", face) else 1
		fill = DieMaterial.tint_for(material, level)
		rim = fill.lightened(0.3)
	if bonus != 0:
		text = "%+d" % bonus
		if material == "":
			rim = VALUE_TINT
	elif pointer >= 0:
		text = "→%d" % (pointer + 1)
		tint = DieNetView.POINTER_COLOR
	if pointer >= 0 and bonus != 0:
		rim = DieNetView.POINTER_COLOR  # der Pfeil steht im Saum, die Zahl im Feld
	var chip := Panel.new()
	chip.name = "SumCell"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(maxi(1, int(cell * 0.08)))
	box.set_corner_radius_all(maxi(1, int(cell * 0.2)))
	chip.add_theme_stylebox_override("panel", box)
	if text != "":
		chip.add_child(_stamp_label(text, cell, tint))
	for slot in mini(runes.size(), SUM_RUNE_CAP):
		chip.add_child(_sum_rune(String(runes[slot]), cell, slot))
	return chip

## Bis so viele Runen zeigt eine Summen-Zelle; mehr passten in die Ecken nicht.
const SUM_RUNE_CAP := 2
## Kantenlänge einer Ecken-Glyphe, als Anteil der Zelle.
const SUM_RUNE_SHARE := 0.42

static func _sum_rune(rune_id: String, cell: float, slot: int) -> Control:
	var side := cell * SUM_RUNE_SHARE
	var mark := DieNetView.RuneGlyph.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size = Vector2.ONE * side
	mark.position = Vector2(cell * 0.04 if slot == 0 else cell - side - cell * 0.04,
		cell - side - cell * 0.04)
	var rune := Rune.by_id(rune_id)
	if rune == null:
		return mark
	mark.lines = Rune.glyph_lines(rune.glyph)
	mark.weights = Rune.glyph_weights(rune.glyph)
	mark.tint = rune.tint
	mark.core = rune.core
	return mark

## Der Klartext einer Summen-Zelle ("" = sie trägt nichts): Material, Zahl, Runen
## und Pointer nacheinander - dieselben Quellen wie jedes andere Netz.
static func projection_hint(projection: Dictionary, face: int) -> String:
	var parts: Array[String] = []
	var material := _sum_string(projection, "materials", face)
	if material != "":
		var level := DieMaterial.MAX_LEVEL if _sum_flag(projection, "doped", face) else 1
		var said := DieMaterial.face_hint(material, level)
		if said != "":
			parts.append(said)
	var bonus := _sum_int(projection, "bonus", face, 0)
	if bonus != 0:
		parts.append("%+d Augen" % bonus)
	for rune_id in _sum_runes(projection, face):
		var rune_hint := Rune.hint(String(rune_id))
		if rune_hint != "":
			parts.append(rune_hint)
	var pointer := _sum_int(projection, "pointers", face, -1)
	if pointer >= 0:
		parts.append("Pointer: auf Seite %d" % (pointer + 1))
	return "  ·  ".join(parts)

static func _sum_int(projection: Dictionary, key: String, face: int,
		fallback: int) -> int:
	var row: Array = projection.get(key, [])
	return int(row[face]) if face >= 0 and face < row.size() else fallback

static func _sum_string(projection: Dictionary, key: String, face: int) -> String:
	var row: Array = projection.get(key, [])
	return String(row[face]) if face >= 0 and face < row.size() else ""

static func _sum_flag(projection: Dictionary, key: String, face: int) -> bool:
	var row: Array = projection.get(key, [])
	return face >= 0 and face < row.size() and bool(row[face])

## Die Runen, die die Serie auf dieser Seite NEU legt (leere Plätze fallen weg).
static func _sum_runes(projection: Dictionary, face: int) -> Array:
	var rows: Array = projection.get("runes", [])
	if face < 0 or face >= rows.size():
		return []
	var out: Array = []
	for rune_id in Array(rows[face]):
		if String(rune_id) != "":
			out.append(String(rune_id))
	return out
