class_name DebugPartsView
extends Control
## Debug-Werkzeug links neben den Kombinationen: ein Knopf öffnet die Liste aller
## Module, ein Klick meldet die Wahl. Steht nur in Debug-Builds (scene_root).

signal part_chosen(part_id: String)

## Links neben den Kombinationen bleiben nur ~260 Display-Pixel bis zum Rand der Anzeige.
const COLUMNS := 1
const ITEM_SIZE := Vector2(236.0, 36.0)
const TOGGLE_SIZE := Vector2(248.0, 46.0)
const GAP := 2.0
const PAD := 6.0
const FONT_SIZE := 20
const TOGGLE_LABEL := "DEBUG: Module"
const RARITY_ORDER: Array[String] = [ComboPart.RARITY_COMMON, ComboPart.RARITY_RARE,
	ComboPart.RARITY_EPIC, ComboPart.RARITY_LEGENDARY]
const DARK := Color(0.05, 0.05, 0.09)

var toggle: Button
var panel: Panel
var buttons: Dictionary = {}

func _init() -> void:
	name = "DebugParts"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts := sorted_parts()
	var rows := ceili(float(parts.size()) / COLUMNS)
	var panel_size := Vector2(
		PAD * 2.0 + COLUMNS * ITEM_SIZE.x + (COLUMNS - 1) * GAP,
		PAD * 2.0 + rows * ITEM_SIZE.y + (rows - 1) * GAP)
	size = Vector2(panel_size.x, panel_size.y + GAP + TOGGLE_SIZE.y)
	toggle = Button.new()
	toggle.text = TOGGLE_LABEL
	toggle.size = TOGGLE_SIZE
	toggle.position = Vector2(0.0, panel_size.y + GAP)
	CasinoStyle.style_button(toggle, CasinoStyle.GOLD_INTENSE, DARK, FONT_SIZE)
	toggle.pressed.connect(_on_toggle)
	add_child(toggle)
	panel = Panel.new()
	panel.position = Vector2.ZERO
	panel.size = panel_size
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", TableScreen.window_style())
	add_child(panel)
	for index in parts.size():
		var part: ComboPart = parts[index]
		var button := Button.new()
		button.text = part.display_name
		button.clip_text = true
		button.size = ITEM_SIZE
		button.position = Vector2(PAD + (index % COLUMNS) * (ITEM_SIZE.x + GAP),
			PAD + (index / COLUMNS) * (ITEM_SIZE.y + GAP))
		CasinoStyle.style_button(button, part.rarity_color(), DARK, FONT_SIZE)
		button.pressed.connect(func() -> void: part_chosen.emit(part.id))
		panel.add_child(button)
		buttons[part.id] = button

## Alle Module, gewöhnliche zuerst, innerhalb der Seltenheit nach Name.
static func sorted_parts() -> Array[ComboPart]:
	var parts := ComboPart.all()
	parts.sort_custom(func(a: ComboPart, b: ComboPart) -> bool:
		var rank_a := RARITY_ORDER.find(a.rarity)
		var rank_b := RARITY_ORDER.find(b.rarity)
		if rank_a != rank_b:
			return rank_a < rank_b
		return a.display_name < b.display_name)
	return parts

## Stellt den Knopf mit seiner rechten unteren Ecke auf den Punkt, die Liste öffnet nach oben.
func place(right_bottom: Vector2) -> void:
	position = right_bottom - size

func is_open() -> bool:
	return panel.visible

func _on_toggle() -> void:
	panel.visible = not panel.visible
