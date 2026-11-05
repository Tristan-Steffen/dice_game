class_name HintCard
extends PanelContainer
## Die geteilte Hinweis-Karte: Titel in Akzentfarbe, darunter die Wirkung.
## Erscheint nur beim Hover (darf also verdecken, was unter ihr liegt) und setzt
## sich unter ihren Anker - notfalls darüber, wenn die Bühne unten endet.
## Genutzt von den Fahrplan-Stationen, den Deal-Marken am Hub und denen in der
## Grube; sie muss ein Kind ihrer Bühne sein (position ist bühnenrelativ).

const BODY_WIDTH_U := 30.0  # Breite des Fließtexts in u
const BODY_COLOR := Color(1.35, 1.35, 1.3)  # überhelles Weiß, wie der Hub-Text

var title_label: Label
var body_label: Label
var _style: StyleBoxFlat

func _init(u: float) -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.06, 0.05, 0.14, 0.96)
	_style.set_border_width_all(maxi(1, int(u * 0.22)))
	_style.set_corner_radius_all(int(u * 1.2))
	_style.content_margin_left = u * 1.8
	_style.content_margin_right = u * 1.8
	_style.content_margin_top = u * 1.1
	_style.content_margin_bottom = u * 1.1
	add_theme_stylebox_override("panel", _style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(u * 0.5))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", int(u * 3.2))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_label)

	body_label = Label.new()
	body_label.add_theme_font_size_override("font_size", int(u * 2.5))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size.x = u * BODY_WIDTH_U
	body_label.modulate = BODY_COLOR
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body_label)

## Feste Gesamtbreite: Titel und Text brechen um, statt die Karte zu weiten.
func fit_width(width: float, u: float) -> void:
	var text_width := width - u * 1.8 * 2.0
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size.x = text_width
	body_label.custom_minimum_size.x = text_width
	# Umbruch-Höhe rechnet die Label an ihrer aktuellen Breite, nicht am Minimum.
	title_label.size.x = text_width
	body_label.size.x = text_width

## Zeigt die Karte unter dem Anker; sie bleibt mit gap Abstand in der Bühne
## (bündig am Rahmen sah sie eingeklemmt aus). Das Anker-Rechteck kommt über
## global_position - der Anker hängt oft in einer Reihe, seine eigene position
## zählt daher nicht.
func show_for(anchor: Control, stage: Control, title: String, body: String,
		accent: Color, gap: float) -> void:
	show_at(Rect2(anchor.global_position - stage.global_position, anchor.size),
		stage.size, title, body, accent, gap)

## Dasselbe an einem bühnenrelativen Anker-Rechteck (ein 3D-Ding hat keinen Control).
func show_at(anchor: Rect2, stage_size: Vector2, title: String, body: String,
		accent: Color, gap: float) -> void:
	if title == "":
		return
	title_label.text = title
	title_label.modulate = accent
	body_label.text = body
	_style.border_color = Color(accent.r, accent.g, accent.b, 0.85)
	visible = true
	reset_size()
	var box := size
	var y := anchor.end.y + gap
	if y + box.y > stage_size.y:
		y = anchor.position.y - gap - box.y
	var max_x := maxf(gap, stage_size.x - box.x - gap)
	position = Vector2(
		clampf(anchor.get_center().x - box.x * 0.5, minf(gap, max_x), max_x),
		maxf(gap, y))

func hide_card() -> void:
	visible = false
