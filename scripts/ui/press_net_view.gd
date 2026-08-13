class_name PressNetView
extends Control
## Ein Würfelnetz, in dem GEARBEITET wird: dasselbe aufgeklappte Kreuz wie
## überall (DieNetView), aber jede Zelle ist ein Knopf. Hält die Werkbank ein
## Beutestück in der Hand, leuchten die legalen Seiten und die übrigen dimmen;
## ein Klick setzt. Oben links in einer Zelle sitzt die Plakette des nassen
## Gusses - grün heißt "noch herausnehmbar", grau "überbaut".
##
## Reiner Renderer plus Ziel-Optik: WAS legal ist, sagt PressTargeting, GESETZT
## wird über GameRun - dieses Netz meldet nur den Klick.

## Eine Seite wurde angeklickt (Ziel des gehaltenen Stücks).
signal face_pressed(face_index: int)
## Die Plakette einer nassen Setzung wurde angeklickt: sie soll heraus.
signal mark_pressed(face_index: int)

## Neutraler Rahmen einer Zelle ohne Werkzeug.
const CHIP_BORDER := Color(0.72, 0.76, 0.8)
## Legales Ziel: der Saum in Gold - er IST die Führung.
const TARGET_BORDER := CasinoStyle.GOLD
## Ungeeignete Zelle: Füllung und Ziffer dimmen aus.
const DIM_ALPHA := 0.30
const DIM_NUMBER := Color(0.35, 0.35, 0.42)
## Vorschau: steigt grün (dasselbe Grün wie am liegenden Würfel), sinkt warm-rot.
const PREVIEW_UP := DieFaceDisplay.PREVIEW_NUMBER_COLOR
const PREVIEW_DOWN := Color(1.0, 0.6, 0.5)
## Nasser Guss / überbaute Setzung.
const WET := DieFaceDisplay.PREVIEW_NUMBER_COLOR
const SET_TINT := Color(0.55, 0.58, 0.68)
## Kantenlänge der Plakette relativ zur Zelle (obere LINKE Ecke - dort sitzt
## weder eine Rune noch die Veredelungs-Plakette).
const MARK_SIZE := 0.34

var def: DieDefinition
var cell := 8.0
## Was gerade in der Hand liegt ("" = nichts) und auf welcher Stufe es wirkt.
var held_id := ""
var stufe := 1
## Erster Klick eines gerichteten Paares (-1 = keiner).
var first_face := -1
## Seite -> {index, id, wet} des nassen Gusses (GameRun.press_face_marks).
var marks: Dictionary = {}
## Runde unterschrieben: nur noch Ablesen.
var locked := false

## Zellen nach physischem Seiten-Index und ihre Ruhefarben.
var _chips: Array[Button] = []
var _chip_fills: Array[Color] = []
var _eligible: Array[bool] = []
var _preview := false

func _init() -> void:
	name = "PressNet"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Baut das Netz neu. cell = Zellkante in Pixeln; alles andere sind die Felder
## oben, die der Aufrufer vorher setzt.
func build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_chips.clear()
	_chip_fills.clear()
	_preview = false
	custom_minimum_size = DieNetView.net_size(cell)
	size = custom_minimum_size
	if def == null:
		return
	_eligible = PressTargeting.eligible_faces(def, held_id, first_face)
	_chips.resize(6)
	_chip_fills.resize(6)
	for face in 6:
		var chip := _face_chip(face)
		chip.position = DieNetView.cell_position(face, cell)
		chip.size = Vector2.ONE * cell
		_chips[face] = chip
		add_child(chip)
	# Essenz-Chip, Runen, Veredelungs-Plaketten und Pointer-Pfeile obendrauf - die
	# Pfeile zuletzt, sie liegen über den Zellrändern.
	add_child(DieNetView.edge_chip(def, cell))
	for glyph in DieNetView.rune_glyphs(def, cell):
		add_child(glyph)
	for badge in DieNetView.level_badges(def, cell):
		add_child(badge)
	for arrow in DieNetView.pointer_arrows(def, cell):
		add_child(arrow)
	for face: int in marks:
		add_child(_mark_badge(int(face), marks[face]))

## Eine Seiten-Zelle im Look der Netz-Zellen, nur anklickbar.
func _face_chip(face: int) -> Button:
	var material_id: String = def.materials[face] if face < def.materials.size() else ""
	var fill := DieMaterial.tint_for(material_id, def.material_level(face))
	_chip_fills[face] = fill
	var chip := Button.new()
	# Name mit Seiten-Index: Godot vergibt sonst @Button@N, und dann ist im Baum
	# nicht mehr zu sehen, welche Zelle welche ist.
	chip.name = "NetCell%d" % face
	chip.text = str(def.faces[face])
	chip.focus_mode = Control.FOCUS_NONE
	chip.add_theme_font_size_override("font_size", maxi(8, int(cell * 0.5)))
	var usable := _cell_usable(face)
	chip.disabled = not usable
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if usable \
		else Control.CURSOR_ARROW
	_style_chip(chip, fill, face)
	chip.pressed.connect(func() -> void: face_pressed.emit(face))
	chip.mouse_entered.connect(_show_preview.bind(face))
	chip.mouse_exited.connect(_clear_preview)
	return chip

## Anklickbar ist eine Zelle nur mit Werkzeug in der Hand und offener Bank; die
## erste Wahl eines Paares bleibt anklickbar (sie ist die Rücknahme).
func _cell_usable(face: int) -> bool:
	if locked or held_id == "":
		return false
	return _eligible[face] or face == first_face

func _style_chip(chip: Button, fill: Color, face: int) -> void:
	var dim := held_id != "" and not _eligible[face] and face != first_face
	var font := CasinoStyle.INK
	var border := CHIP_BORDER
	var width := maxi(2, int(cell * 0.06))
	if face == first_face:
		font = DieFaceDisplay.SELECT_NUMBER_COLOR
		border = DieFaceDisplay.SELECT_NUMBER_COLOR
		width = maxi(2, int(cell * 0.12))
	elif dim:
		fill = Color(fill.r, fill.g, fill.b, fill.a * DIM_ALPHA)
		font = DIM_NUMBER
		border = CHIP_BORDER.darkened(0.35)
	elif held_id != "":
		border = TARGET_BORDER
		width = maxi(2, int(cell * 0.11))
	elif Essence.is_valid_id(def.essence_id):
		border = Essence.glow_for(def.essence_id)
		width = maxi(2, int(cell * 0.1))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		chip.add_theme_color_override(state, font)
	chip.add_theme_color_override("font_outline_color", fill)
	chip.add_theme_constant_override("outline_size", maxi(1, int(cell * 0.06)))
	var box := _chip_box(fill, border, width)
	for state in ["normal", "disabled"]:
		chip.add_theme_stylebox_override(state, box)
	chip.add_theme_stylebox_override("hover", _chip_box(fill.lightened(0.15), border, width))
	chip.add_theme_stylebox_override("pressed", _chip_box(fill.darkened(0.1), border, width))
	chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _chip_box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(maxi(1, width))
	box.set_corner_radius_all(int(cell * 0.2))
	return box

## Die Plakette des nassen Gusses in der oberen linken Zellecke: grün noch
## herausnehmbar (ein Klick holt das Stück zurück in die Hand), grau überbaut.
func _mark_badge(face: int, mark: Dictionary) -> Button:
	var wet := bool(mark.get("wet", false))
	var tint: Color = WET if wet else SET_TINT
	var side := cell * MARK_SIZE
	var inset := cell * 0.04
	var badge := Button.new()
	badge.name = "PressMark%d" % face
	badge.focus_mode = Control.FOCUS_NONE
	badge.size = Vector2.ONE * side
	badge.position = DieNetView.cell_position(face, cell) + Vector2.ONE * inset
	badge.disabled = not wet or locked
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if wet and not locked \
		else Control.CURSOR_ARROW
	var box := _chip_box(Color(tint.r, tint.g, tint.b, 0.9), CasinoStyle.INK,
		maxi(1, int(cell * 0.03)))
	for state in ["normal", "disabled"]:
		badge.add_theme_stylebox_override(state, box)
	badge.add_theme_stylebox_override("hover",
		_chip_box(tint, CasinoStyle.INK, maxi(1, int(cell * 0.03))))
	badge.add_theme_stylebox_override("pressed", box)
	badge.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	badge.pressed.connect(func() -> void: mark_pressed.emit(face))
	return badge

# --- Vorschau ------------------------------------------------------------------

## Überfahren: was die gehaltene Gravur hier täte, steht als "3→5" in den Zellen.
func _show_preview(face: int) -> void:
	if held_id == "" or def == null or locked:
		return
	if PressTargeting.needs_face(held_id) and not _eligible[face]:
		return
	var ghost := PressTargeting.ghost_after(def, held_id, stufe, face, first_face)
	if ghost == null:
		return
	_preview = true
	for i in 6:
		var chip: Button = _chips[i]
		if chip == null or not is_instance_valid(chip):
			continue
		var old_value: int = def.faces[i]
		var new_value: int = ghost.faces[i]
		if new_value == old_value:
			continue
		chip.text = "%d→%d" % [old_value, new_value]
		chip.add_theme_font_size_override("font_size", maxi(8, int(cell * 0.28)))
		var tint: Color = PREVIEW_UP if new_value > old_value else PREVIEW_DOWN
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			chip.add_theme_color_override(state, tint)

func _clear_preview() -> void:
	if not _preview or def == null:
		return
	_preview = false
	for i in 6:
		var chip: Button = _chips[i]
		if chip == null or not is_instance_valid(chip):
			continue
		chip.text = str(def.faces[i])
		chip.add_theme_font_size_override("font_size", maxi(8, int(cell * 0.5)))
		_style_chip(chip, _chip_fills[i], i)

## Die Zelle unter einem Display-Pixel (-1 = keine, DieNetView.EDGE über dem
## Essenz-Chip) - dieselbe Geometrie wie jedes andere Netz.
func face_at_pixel(pixel: Vector2) -> int:
	var rect := get_global_rect()
	if not rect.has_point(pixel):
		return -1
	return DieNetView.face_at(pixel - rect.position, cell)
