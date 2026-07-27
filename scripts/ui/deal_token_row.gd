class_name DealTokenRow
extends HBoxContainer
## Die Deal-Marken als Reihe: je wirkende Deal-Seite eine Marke. Grün/rot sagt
## Bonus oder Malus, die Größe die Laufzeit (Block > Runde), die Füllfarbe den
## Deal. Dieselbe Reihe hängt am Hub-Rad UND am oberen Grubenrand - eine
## Grammatik an zwei Orten. Den Hinweis-Text meldet sie nur; platzieren muss ihn
## jede Seite selbst (Hub-Bühne bzw. Grubenfenster).

signal token_hovered(anchor: Control, title: String, body: String, accent: Color)
signal token_left

const BONUS_COLOR := Color("#50fa7b")
const MALUS_COLOR := Color("#ff6b6b")
const ROUND_DIA_U := 4.2
const BLOCK_DIA_U := 5.6
## Abrechnungs-Wisch: Staffelung je Marke und Dauer einer Auflösung.
const SWEEP_GAP := 0.08
const SWEEP_TIME := 0.35

## Die Marken melden Hover selbst (Hub). In der Grube erreicht sie keine Maus -
## dort fragt scene_root je Frame token_at().
var self_hover := true

func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Setzt die wirkenden Deal-Seiten (GameRun.active_deal_sides). Immer komplett
## neu gebaut - eine Marke einzeln nachzuführen ginge irgendwann schief.
func set_sides(sides: Array[Dictionary], u: float) -> void:
	add_theme_constant_override("separation", int(u * 1.0))
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for side in sides:
		var deal := RouteDeal.find(side["id"])
		if deal != null:
			add_child(_make_token(deal, side, u))
	modulate.a = 1.0  # ein Wisch von eben darf nicht kleben bleiben

## Eine Marke: Füllung in Deal-Farbe, Ring grün (Bonus) oder rot (Malus),
## Zeichen + bzw. −. Block-Marken sind größer als Runden-Marken.
func _make_token(deal: RouteDeal, side: Dictionary, u: float) -> Control:
	var bonus: bool = side["bonus"]
	var block: bool = int(side["scope"]) == int(RouteDeal.Scope.BLOCK)
	var accent := BONUS_COLOR if bonus else MALUS_COLOR
	var dia := u * (BLOCK_DIA_U if block else ROUND_DIA_U)

	var token := Panel.new()
	token.name = "Token_%s_%s" % [deal.id, "bonus" if bonus else "malus"]
	token.custom_minimum_size = Vector2(dia, dia)
	token.mouse_filter = Control.MOUSE_FILTER_PASS if self_hover else Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(deal.color.r * 0.35, deal.color.g * 0.35, deal.color.b * 0.35, 0.95)
	box.border_color = accent
	box.set_border_width_all(maxi(1, int(u * (0.4 if block else 0.28))))
	box.set_corner_radius_all(int(dia * 0.5))
	token.add_theme_stylebox_override("panel", box)

	var glyph := Label.new()
	glyph.text = "+" if bonus else "−"
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", int(dia * 0.62))
	glyph.modulate = accent
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.add_child(glyph)

	var text: String = deal.bonus_text if bonus else deal.malus_text
	token.set_meta("hint", {
		"title": deal.display_name,
		"body": "%s\n(%s)" % [text, RouteDeal.scope_label(side["scope"])],
		"accent": accent})
	if self_hover:
		token.mouse_entered.connect(func() -> void:
			var hint: Dictionary = token.get_meta("hint")
			token_hovered.emit(token, hint["title"], hint["body"], hint["accent"]))
		token.mouse_exited.connect(func() -> void: token_left.emit())
	return token

## Marke unter dem Display-Pixel, oder null - der Hover-Weg in der Grube.
func token_at(pixel: Vector2) -> Control:
	if not visible:
		return null
	for child in get_children():
		var token := child as Control
		if token != null and token.get_global_rect().has_point(pixel):
			return token
	return null

## Hinweis-Daten einer Marke: title, body, accent (leer, wenn keine Marke).
func hint_for(token: Control) -> Dictionary:
	if token == null or not token.has_meta("hint"):
		return {}
	return token.get_meta("hint")

## Abrechnung: die Marken lösen sich gestaffelt auf, während die Reihe um
## slide_y wegrutscht - der Block ist beglichen. Liefert die Dauer, damit der
## Aufrufer den Shop erst danach öffnet. Die Deckkraft je Marke tweenen ist
## erlaubt, ihre POSITION nicht: die legt der Container fest, darum rutscht die
## ganze Reihe.
func sweep(slide_y: float) -> float:
	if get_child_count() == 0:
		return 0.0
	var total := 0.0
	var i := 0
	for child in get_children():
		var token := child as Control
		if token == null:
			continue
		token.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var delay := i * SWEEP_GAP
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(token, "modulate:a", 0.0, SWEEP_TIME).set_trans(Tween.TRANS_SINE)
		total = maxf(total, delay + SWEEP_TIME)
		i += 1
	var slide := create_tween()
	slide.tween_property(self, "position:y", position.y + slide_y, total).set_trans(Tween.TRANS_CUBIC)
	return total
