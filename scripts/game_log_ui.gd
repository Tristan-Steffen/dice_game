class_name GameLogUI
extends CenterContainer
## Das Spielprotokoll: eine Gewinnkarten-Seite mit Beschriftungsspalte
## und sechs Wertespalten (1.–6. Spiel). Öffnet zentriert, so groß wie der Inhalt.

signal closed

const TOTAL_COLUMNS := 6

@onready var page: PanelContainer = $Page
@onready var columns_box: HBoxContainer = $Page/Margin/Content/LogColumns
@onready var title_label: Label = $Page/Margin/Content/TopBar/TitleLabel
@onready var close_button: Button = $Page/Margin/Content/TopBar/CloseButton

func _ready() -> void:
	PageStyle.apply_page_style(page)
	PageStyle.style_label(title_label)
	title_label.add_theme_font_size_override("font_size", 20)
	PageStyle.style_button(close_button)
	close_button.pressed.connect(_on_close_pressed)

## round_datas: genau TOTAL_COLUMNS Einträge; null = noch nicht gespielte Runde.
## Gespielte Einträge: {goal, scores, used, bonus, total}.
func open(round_datas: Array) -> void:
	for child in columns_box.get_children():
		child.queue_free()

	var grid := GridContainer.new()
	grid.columns = TOTAL_COLUMNS + 1
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 3)

	var corner := PageStyle.make_label("", 12)
	corner.custom_minimum_size = Vector2(120, 0)
	grid.add_child(corner)
	for i in TOTAL_COLUMNS:
		var data = round_datas[i]
		var header_text := "%d. Spiel" % (i + 1)
		if data != null:
			header_text += "\nZiel: %d" % data["goal"]
		else:
			header_text += "\n–"
		var header := PageStyle.make_label(header_text, 12, PageStyle.TEXT_COLOR if data != null else PageStyle.MUTED_COLOR)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(header)

	for cat in KniffelScoring.CATEGORIES:
		var key: String = cat["key"]
		grid.add_child(PageStyle.make_label(cat["label"], 12))
		for data in round_datas:
			var value_text := "-"
			if data != null and data["used"][key]:
				value_text = str(data["scores"][key])
			grid.add_child(_make_value_cell(value_text, data != null))

	grid.add_child(PageStyle.make_label("Bonus (63+)", 12))
	for data in round_datas:
		grid.add_child(_make_value_cell("-" if data == null else str(data["bonus"]), data != null))

	grid.add_child(PageStyle.make_label("Gesamt", 13))
	for data in round_datas:
		grid.add_child(_make_value_cell("-" if data == null else str(data["total"]), data != null))

	columns_box.add_child(grid)
	visible = true

func _on_close_pressed() -> void:
	visible = false
	closed.emit()

func _make_value_cell(text: String, is_active: bool) -> Label:
	var cell := PageStyle.make_label(text, 12, PageStyle.TEXT_COLOR if is_active else PageStyle.MUTED_COLOR)
	cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.custom_minimum_size = Vector2(84, 0)
	cell.add_theme_stylebox_override("normal", PageStyle.make_cell_stylebox(PageStyle.CELL_COLOR if is_active else PageStyle.CELL_DISABLED_COLOR))
	return cell
