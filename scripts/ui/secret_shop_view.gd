class_name SecretShopView
extends Control
## Der Schwarzmarkt: Hub-Seite hinter der ersten voll ausgereizten Überladung.
## Bezahlt wird ausschließlich in Ladung (⚡) - drei Plätze, jeder EINMAL kaufbar,
## "Neu mischen" tauscht alle drei zu steigendem Preis. Zustands-Mutation läuft
## ausschließlich über GameRun (buy_secret_offer/reroll_secret_stock); die Anzeige
## folgt secret_stock_changed und charge_changed. Einheit u = Breite/100 wie Hub
## und Shop.

## Hinterzimmer-Palette: dunkler als der Laden, Akzent ist das Violett der
## legendären Rarität.
const VIOLET := Color(0.75, 0.35, 1.0)
const CHARGE_COLOR := CasinoStyle.CHARGE
const NEON_TEXT := Color(1.35, 1.35, 1.3)
const NEON_MUTED := Color(0.72, 0.74, 0.86)
const BACKROOM_BG := Color("#0b0918e6")
const CARD_BG := Color("#150f2acc")

var run: GameRun:
	set(value):
		if run != null:
			if run.secret_stock_changed.is_connected(_on_run_changed):
				run.secret_stock_changed.disconnect(_on_run_changed)
			if run.charge_changed.is_connected(_on_charge_changed):
				run.charge_changed.disconnect(_on_charge_changed)
		run = value
		if run != null:
			run.secret_stock_changed.connect(_on_run_changed)
			run.charge_changed.connect(_on_charge_changed)

## Breiteneinheit (size.x / 100), in _build_layout gesetzt.
var u := 8.0

var wallet_label: Label
var cards_row: HBoxContainer
var reroll_button: Button
var close_button: Button
## Ein Knopf je Auslage-Platz (Tests und _refresh arbeiten dagegen).
var offer_buttons: Array[Button] = []

## Hover-Dropdown (Name + Wirkung), wie im Shop.
var detail_card: PanelContainer
var detail_title: Label
var detail_body: Label

var _built := false

## Öffnet die Seite: Gerüst passend zur aktuellen Größe, frische Auslage.
func open() -> void:
	_build_layout()
	_refresh()
	visible = true

# --- Gerüst -------------------------------------------------------------------

func _build_layout() -> void:
	for child in get_children():
		child.queue_free()
	offer_buttons.clear()
	u = maxf(size.x, 640.0) / 100.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true  # nichts über den Hub-Rahmen hinaus (dort endet die Maus)
	_built = true

	# Eigener, deutlich dunklerer Grund: der Hinterzimmer-Look gegen den hellen Laden.
	var backdrop := Panel.new()
	backdrop.name = "Backroom"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = BACKROOM_BG
	box.border_color = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.35)
	box.set_border_width_all(maxi(1, int(u * 0.2)))
	box.set_corner_radius_all(int(u * 1.4))
	backdrop.add_theme_stylebox_override("panel", box)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(u * 3.0))
	margin.add_theme_constant_override("margin_right", int(u * 3.0))
	margin.add_theme_constant_override("margin_top", int(u * 2.0))
	margin.add_theme_constant_override("margin_bottom", int(u * 2.0))
	add_child(margin)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.add_theme_constant_override("separation", int(u * 1.4))
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", int(u * 2.0))
	root.add_child(header)
	header.add_child(_label("S C H W A R Z M A R K T", u * 4.0, Color(1.35, 0.7, 1.7)))
	var rail := _rail(VIOLET)
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(rail)
	wallet_label = _label("⚡ 0/0", u * 4.0, CHARGE_COLOR)
	header.add_child(wallet_label)

	cards_row = HBoxContainer.new()
	cards_row.name = "Offers"
	cards_row.add_theme_constant_override("separation", int(u * 1.8))
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cards_row)

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", int(u * 1.5))
	root.add_child(footer)
	reroll_button = _neon_button("Neu mischen", VIOLET, u * 2.8, Vector2(u * 26.0, u * 5.0))
	reroll_button.pressed.connect(_on_reroll_pressed)
	footer.add_child(reroll_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(spacer)
	close_button = _neon_button("Zurück", VIOLET, u * 2.8, Vector2(u * 18.0, u * 5.0))
	close_button.pressed.connect(_on_close_pressed)
	footer.add_child(close_button)

	_build_detail_card()  # zuletzt: liegt als Overlay über den Karten

# --- Auslage ------------------------------------------------------------------

## Baut die drei Karten neu und zieht Börse und Misch-Preis nach. Rebuild statt
## Patch: ein verkaufter Platz wechselt seine ganze Gestalt.
func _refresh() -> void:
	if not _built or run == null:
		return
	wallet_label.text = "⚡ %d/%d" % [run.charge, run.charge_cap()]
	for child in cards_row.get_children():
		cards_row.remove_child(child)
		child.queue_free()
	offer_buttons.clear()
	var thumb_px := int(u * 15.0)
	for i in run.secret_stock.size():
		cards_row.add_child(_build_offer_card(run.secret_stock[i], i, thumb_px))
	_refresh_afford_state()

## Kaufbarkeit von Karten und Misch-Knopf am Ladungsstand ausrichten.
func _refresh_afford_state() -> void:
	if not _built or run == null:
		return
	var cost := run.secret_reroll_cost()
	reroll_button.text = "Neu mischen ⚡%d" % cost
	reroll_button.disabled = run.charge < cost
	for i in offer_buttons.size():
		if i >= run.secret_stock.size():
			continue
		var offer := run.secret_stock[i]
		var sold: bool = offer[GameRun.OFFER_SOLD]
		offer_buttons[i].disabled = sold or run.charge < int(offer[GameRun.OFFER_PRICE])

## Angebots-Karte: Ware groß, Preis in Ladung darunter; Name und Wirkung zeigt
## der Hover-Dropdown. Rahmen und Lichtfleck tragen die Seltenheit der Ware.
func _build_offer_card(offer: Dictionary, index: int, thumb_px: int) -> Button:
	var kind: String = offer[GameRun.OFFER_KIND]
	var sold: bool = offer[GameRun.OFFER_SOLD]
	var price: int = offer[GameRun.OFFER_PRICE]
	var tint := VIOLET
	var title := ""
	var body := ""
	var face: Control
	if kind == GameRun.KIND_CHARM:
		var charm: Charm = offer[GameRun.OFFER_ITEM]
		tint = charm.rarity_color()
		title = charm.display_name
		body = charm.description
		face = CharmThumb.new(charm, thumb_px)
	else:
		var engraving: Engraving = offer[GameRun.OFFER_ITEM]
		tint = EngravingRenderer.SEAM_COLORS[int(engraving.rarity)]
		title = engraving.display_name
		body = engraving.description
		var renderer := EngravingRenderer.for_engraving(engraving)
		renderer.custom_minimum_size = Vector2(thumb_px, thumb_px)
		face = renderer

	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("normal", _card_box(CARD_BG, tint, 0.7, 0.24))
	card.add_theme_stylebox_override("hover", _card_box(Color("#241a4add"), Color(1.4, 1.1, 0.2), 0.95, 0.3))
	card.add_theme_stylebox_override("pressed", _card_box(Color("#2e2160"), Color(1.4, 1.1, 0.2), 1.0, 0.3))
	card.add_theme_stylebox_override("disabled", _card_box(Color("#100c2266"), tint, 0.2, 0.0))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.mouse_entered.connect(_show_detail.bind(card, title, body))
	card.mouse_exited.connect(_hide_detail)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(u * 0.8))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	var stage := CenterContainer.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_glow_disc(tint, thumb_px * 1.5))
	stage.add_child(face)
	if sold:
		face.modulate = Color(1, 1, 1, 0.3)  # die Ware ist weg, der Platz bleibt
	column.add_child(stage)

	column.add_child(_label("VERKAUFT" if sold else "⚡ %d" % price, u * 2.4,
		NEON_MUTED if sold else CHARGE_COLOR, HORIZONTAL_ALIGNMENT_CENTER))

	if not sold:
		card.pressed.connect(_on_offer_pressed.bind(index))
	offer_buttons.append(card)
	return card

# --- Käufe --------------------------------------------------------------------

func _on_offer_pressed(index: int) -> void:
	if run != null:
		run.buy_secret_offer(index)  # Refresh kommt über secret_stock_changed

func _on_reroll_pressed() -> void:
	if run != null:
		run.reroll_secret_stock()

func _on_close_pressed() -> void:
	_hide_detail()
	visible = false  # der Hub holt Home von selbst zurück

func _on_run_changed() -> void:
	if visible:
		_refresh()

## Ladung allein ändert die Auslage nicht - nur wer was bezahlen kann.
func _on_charge_changed(_value: int) -> void:
	if visible and _built and run != null:
		wallet_label.text = "⚡ %d/%d" % [run.charge, run.charge_cap()]
		_refresh_afford_state()

# --- Bausteine ----------------------------------------------------------------

func _label(text: String, font_size: float, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _card_box(fill: Color, border: Color, border_alpha: float, glow_alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Color(border.r, border.g, border.b, border_alpha)
	box.set_border_width_all(maxi(1, int(u * 0.22)))
	box.set_corner_radius_all(int(u * 1.2))
	box.set_content_margin_all(int(u * 0.8))
	if glow_alpha > 0.0:
		box.shadow_color = Color(border.r, border.g, border.b, glow_alpha)
		box.shadow_size = int(u * 1.0)
	return box

func _neon_button(text: String, accent: Color, font_size: float, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	button.add_theme_color_override("font_color", NEON_TEXT)
	button.add_theme_color_override("font_hover_color", Color(1.4, 1.1, 0.2))
	button.add_theme_color_override("font_pressed_color", Color(1.4, 1.1, 0.2))
	button.add_theme_color_override("font_disabled_color",
		Color(NEON_MUTED.r, NEON_MUTED.g, NEON_MUTED.b, 0.45))
	button.add_theme_stylebox_override("normal", _button_box(Color("#1a1236cc"), accent))
	button.add_theme_stylebox_override("hover", _button_box(Color("#251a4add"), Color(1.4, 1.1, 0.2)))
	button.add_theme_stylebox_override("pressed", _button_box(Color("#30235e"), Color(1.4, 1.1, 0.2)))
	button.add_theme_stylebox_override("focus", _button_box(Color("#1a1236cc"), accent))
	button.add_theme_stylebox_override("disabled",
		_button_box(Color("#12102466"), Color(accent.r, accent.g, accent.b, 0.25)))
	return button

func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.22)))
	box.set_corner_radius_all(int(u * 0.9))
	box.set_content_margin_all(int(u * 0.8))
	return box

## Dünne Lichtschiene, die nach rechts ausläuft.
func _rail(accent: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([
		Color(accent.r, accent.g, accent.b, 0.7), Color(accent.r, accent.g, accent.b, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 4
	var rail := TextureRect.new()
	rail.texture = texture
	rail.stretch_mode = TextureRect.STRETCH_SCALE
	rail.custom_minimum_size = Vector2(u * 4.0, u * 0.35)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rail

## Weicher radialer Lichtfleck hinter der Ware.
func _glow_disc(tint: Color, side: float) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(tint.r, tint.g, tint.b, 0.34), Color(tint.r, tint.g, tint.b, 0.12),
		Color(tint.r, tint.g, tint.b, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 96
	texture.height = 96
	var disc := TextureRect.new()
	disc.texture = texture
	disc.stretch_mode = TextureRect.STRETCH_SCALE
	disc.custom_minimum_size = Vector2(side, side)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return disc

# --- Hover-Dropdown -----------------------------------------------------------

func _build_detail_card() -> void:
	detail_card = PanelContainer.new()
	detail_card.name = "OfferDetail"
	detail_card.visible = false
	detail_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_panel(detail_card)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", int(u * 0.4))
	detail_card.add_child(col)
	detail_title = Label.new()
	detail_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_score_label(detail_title, int(u * 2.6), CasinoStyle.GOLD)
	col.add_child(detail_title)
	detail_body = Label.new()
	detail_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body.custom_minimum_size = Vector2(u * 28.0, 0)
	CasinoStyle.style_body_label(detail_body, int(u * 1.9), CasinoStyle.CREAM)
	col.add_child(detail_body)
	add_child(detail_card)

## Zeigt die Karte unter (notfalls über) dem Angebot, immer im Panel eingeklemmt.
func _show_detail(anchor: Control, title: String, body: String) -> void:
	if detail_card == null:
		return
	detail_title.text = title
	detail_body.text = body
	detail_card.visible = true
	detail_card.reset_size()
	var local := anchor.get_global_rect().position - get_global_rect().position
	var below := local.y + anchor.size.y + u * 0.6
	var above := local.y - detail_card.size.y - u * 0.6
	var pos := Vector2(local.x, below)
	if below + detail_card.size.y > size.y - u * 1.0 and above >= u * 1.0:
		pos.y = above
	pos.x = clampf(pos.x, u * 1.0, maxf(u * 1.0, size.x - detail_card.size.x - u * 1.0))
	pos.y = clampf(pos.y, u * 1.0, maxf(u * 1.0, size.y - detail_card.size.y - u * 1.0))
	detail_card.position = pos

func _hide_detail() -> void:
	if detail_card != null:
		detail_card.visible = false
