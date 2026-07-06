class_name ScorecardUI
extends PanelContainer
## Die aktive Scorecard (rechte Seite): eine Spalte zum Eintragen der laufenden Runde.

signal category_selected(key: String)

var category_buttons: Dictionary = {}
var bonus_label: Label
var total_label: Label

@onready var content: VBoxContainer = $Margin/Content

func _ready() -> void:
	PageStyle.apply_page_style(self)
	_build()

func _build() -> void:
	var title_label := PageStyle.make_label("KNIFFEL", 22)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)
	content.add_child(PageStyle.make_separator())

	for cat in KniffelScoring.CATEGORIES:
		_add_category_row(cat["key"], cat["label"])

	content.add_child(PageStyle.make_separator())
	bonus_label = _add_score_row("Bonus (63+)")
	total_label = _add_score_row("Gesamt")

func _add_category_row(key: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := PageStyle.make_label(label_text, 16)
	name_label.custom_minimum_size = Vector2(150, 0)
	row.add_child(name_label)

	var score_button := Button.new()
	score_button.custom_minimum_size = Vector2(60, 0)
	score_button.disabled = true
	score_button.text = "-"
	score_button.pressed.connect(func() -> void: category_selected.emit(key))
	PageStyle.style_button(score_button)
	row.add_child(score_button)

	content.add_child(row)
	category_buttons[key] = score_button

func _add_score_row(label_text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := PageStyle.make_label(label_text, 16)
	name_label.custom_minimum_size = Vector2(150, 0)
	row.add_child(name_label)

	var value_label := PageStyle.make_label("0", 16)
	row.add_child(value_label)

	content.add_child(row)
	return value_label

func refresh(category_used: Dictionary, category_scores: Dictionary, preview_scores: Dictionary, can_select: bool) -> void:
	for cat in KniffelScoring.CATEGORIES:
		var key: String = cat["key"]
		var button: Button = category_buttons[key]
		if category_used[key]:
			button.text = str(category_scores[key])
			button.disabled = true
		elif can_select:
			button.text = str(preview_scores[key])
			button.disabled = false
		else:
			button.text = "-"
			button.disabled = true

	bonus_label.text = str(KniffelScoring.calculate_bonus(category_used, category_scores))
	total_label.text = str(KniffelScoring.calculate_total(category_used, category_scores))
