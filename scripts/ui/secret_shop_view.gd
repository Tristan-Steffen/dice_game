class_name SecretShopView
extends Panel
## Der Schwarzmarkt: eigenes Tisch-Fenster UNTER den Fumble-Automaten. Es steht
## von Anfang an da, aber VERGITTERT - ein einziger Knopf in der Mitte kauft den
## Zutritt für Ladung frei (set_locked, unlock_requested); solange liegen nur
## Schatten-Plätze aus, denn die Auslage wird erst beim Freischalten gewürfelt.
## Danach: bezahlt wird ausschließlich in Ladung (⚡) - drei Plätze, jeder EINMAL
## kaufbar, "Neu mischen" tauscht alle drei zu steigendem Preis. Zustands-Mutation
## läuft ausschließlich über GameRun (buy_secret_offer/reroll_secret_stock); die
## Anzeige folgt secret_stock_changed und charge_changed. Geschlossen wird wie bei
## jedem Fenster per Rechtsklick (Kamera zoomt zurück) - kein eigener Knopf.

## Der Spieler will das Gitter heben; die Buchung macht scene_root über GameRun.
signal unlock_requested
## Ladung ist für den Laden geflossen (Kauf oder Neuwurf) - scene_root schickt sie
## als Kometen über die Hinterzimmer-Ader. Erst gebucht, dann gemeldet.
signal charge_spent(amount: int)

## Hinterzimmer-Palette: dunkler als der Laden, Akzent ist das Violett der
## legendären Rarität.
const VIOLET := Color(0.75, 0.35, 1.0)
const CHARGE_COLOR := CasinoStyle.CHARGE
const NEON_TEXT := Color(1.35, 1.35, 1.3)
const NEON_MUTED := Color(0.72, 0.74, 0.86)
const BACKROOM_BG := Color("#0b0918e6")
const CARD_BG := Color("#150f2acc")

## So viele Schatten-Plätze zeigt der vergitterte Laden (= die späteren Plätze).
const SHADOW_SLOTS := 3

## Bauhöhe des Inhalts in Einheiten - die Tasche unter den Automaten ist flach,
## also darf die Einheit auch an der HÖHE hängen (wie Gravur-Station/Vertragswahl).
const CONTENT_UNITS := 72.0

var run: GameRun:
	set(value):
		if run != null:
			if run.secret_stock_changed.is_connected(_on_run_changed):
				run.secret_stock_changed.disconnect(_on_run_changed)
			if run.charge_changed.is_connected(_on_charge_changed):
				run.charge_changed.disconnect(_on_charge_changed)
			if run.charms_changed.is_connected(_on_run_changed):
				run.charms_changed.disconnect(_on_run_changed)
		run = value
		if run != null:
			run.secret_stock_changed.connect(_on_run_changed)
			run.charge_changed.connect(_on_charge_changed)
			run.charms_changed.connect(_on_run_changed)  # der Charm-Platz sperrt am vollen Dock
		refresh()

## Einheit aus BEIDEN Achsen (in refresh gesetzt).
var u := 4.0

## Vergittert: Schatten-Plätze unter einem dunklen Schleier, davor der Knopf.
var locked := true
var can_afford := false

var wallet_label: Label
var cards_row: HBoxContainer
var reroll_button: Button
## Ein Knopf je Auslage-Platz (Tests und _refresh arbeiten dagegen).
var offer_buttons: Array[Button] = []
var lock_overlay: Panel
var unlock_button: Button

## Hover-Dropdown (Name + Wirkung), wie im Shop.
var detail_card: PanelContainer
var detail_title: Label
var detail_body: Label

var _built := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # die Knöpfe fangen selbst
	clip_contents = true
	add_theme_stylebox_override("panel", _window_box())

## Fensterrahmen in Hinterzimmer-Farben: Form und Radius wie jedes Tisch-Fenster,
## nur Füllung dunkler und Saum violett.
func _window_box() -> StyleBoxFlat:
	var box := TableScreen.window_style()
	box.bg_color = BACKROOM_BG
	box.border_color = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.75)
	return box

## scene_root/TableScreen nach Platzierung und Zustandswechseln: Gerüst in der
## aktuellen Fenstergröße, dann die Auslage.
func refresh() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_build_layout()
	_refresh_offers()
	_apply_lock_state()

## Gitter-Zustand von scene_root (einziger Schreiber): locked = noch nicht
## freigeschaltet, affordable = die Börse trägt das Eintrittsgeld.
func set_locked(is_locked: bool, affordable: bool) -> void:
	var was_locked := locked
	locked = is_locked
	can_afford = affordable
	if not _built:
		return
	if was_locked != locked:
		_refresh_offers()  # Schatten <-> echte Ware ist ein Neuaufbau
	_apply_lock_state()

## Schleier, Knopf und Dimmung der Plätze am Gitter-Zustand ausrichten.
func _apply_lock_state() -> void:
	if not _built:
		return
	lock_overlay.visible = locked
	unlock_button.disabled = not can_afford
	reroll_button.visible = not locked
	cards_row.modulate = Color(1, 1, 1, 0.35) if locked else Color.WHITE

# --- Gerüst -------------------------------------------------------------------

func _build_layout() -> void:
	for child in get_children():
		child.queue_free()
	offer_buttons.clear()
	u = minf(size.x / 100.0, size.y / CONTENT_UNITS)
	_built = true

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(u * 3.0))
	margin.add_theme_constant_override("margin_right", int(u * 3.0))
	margin.add_theme_constant_override("margin_top", int(u * 2.4))
	margin.add_theme_constant_override("margin_bottom", int(u * 2.4))
	add_child(margin)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", int(u * 1.4))
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", int(u * 2.0))
	root.add_child(header)
	header.add_child(_label("SCHWARZMARKT", u * 5.0, Color(1.35, 0.7, 1.7)))
	var rail := _rail(VIOLET)
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(rail)
	wallet_label = _label("⚡ 0/0", u * 5.0, CHARGE_COLOR)
	header.add_child(wallet_label)

	cards_row = HBoxContainer.new()
	cards_row.name = "Offers"
	cards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards_row.add_theme_constant_override("separation", int(u * 1.8))
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cards_row)

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation", int(u * 1.5))
	root.add_child(footer)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(spacer)
	reroll_button = _neon_button("Neu mischen", VIOLET, u * 3.2, Vector2(u * 34.0, u * 7.0))
	reroll_button.pressed.connect(_on_reroll_pressed)
	footer.add_child(reroll_button)

	_build_detail_card()  # zuletzt: liegt als Overlay über den Karten
	_build_lock_overlay()  # und ganz oben das Gitter

# --- Auslage ------------------------------------------------------------------

## Baut die drei Karten neu und zieht Börse und Misch-Preis nach. Rebuild statt
## Patch: ein verkaufter Platz wechselt seine ganze Gestalt.
func _refresh_offers() -> void:
	if not _built or run == null:
		return
	wallet_label.text = "⚡ %d/%d" % [run.charge, run.charge_cap()]
	for child in cards_row.get_children():
		cards_row.remove_child(child)
		child.queue_free()
	offer_buttons.clear()
	var thumb_px := int(u * 13.0)
	if locked:
		# Die Auslage wird erst beim Freischalten gewürfelt - hier stehen Schatten.
		for i in SHADOW_SLOTS:
			cards_row.add_child(_build_shadow_card(thumb_px))
		return
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
		# Voller Charm-Dock sperrt den Charm-Platz wie ein leeres Konto.
		var blocked: bool = offer[GameRun.OFFER_KIND] == GameRun.KIND_CHARM and run.charms_full()
		offer_buttons[i].disabled = sold or blocked \
			or run.charge < int(offer[GameRun.OFFER_PRICE])

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

	# Voller Charm-Dock: der Platz zeigt das statt seines Preises.
	var blocked := kind == GameRun.KIND_CHARM and run != null and run.charms_full()
	var tag := "VERKAUFT" if sold else ("DOCK VOLL" if blocked else "⚡ %d" % price)
	column.add_child(_label(tag, u * 3.0,
		NEON_MUTED if sold or blocked else CHARGE_COLOR, HORIZONTAL_ALIGNMENT_CENTER))

	if not sold:
		card.pressed.connect(_on_offer_pressed.bind(index))
	offer_buttons.append(card)
	return card

## Schatten-Platz des vergitterten Ladens: dieselbe Kartenform, aber leer - er
## verspricht einen Platz, nicht eine bestimmte Ware.
func _build_shadow_card(thumb_px: int) -> Control:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_box(Color("#100c2266"), VIOLET, 0.3, 0.0))
	var stage := CenterContainer.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_glow_disc(VIOLET, thumb_px))
	stage.add_child(_label("?", u * 8.0, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.6),
		HORIZONTAL_ALIGNMENT_CENTER))
	card.add_child(stage)
	return card

# --- Gitter -------------------------------------------------------------------

## Dunkler Schleier über der ganzen Tasche, in seiner Mitte der Freischalt-Knopf.
## Liegt als LETZTES Kind auf allem anderen.
func _build_lock_overlay() -> void:
	lock_overlay = Panel.new()
	lock_overlay.name = "LockOverlay"
	lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	lock_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # nichts darunter ist anfassbar
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.01, 0.06, 0.72)
	box.set_corner_radius_all(int(u * 1.2))
	lock_overlay.add_theme_stylebox_override("panel", box)
	add_child(lock_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_overlay.add_child(center)
	unlock_button = _neon_button("Freischalten ⚡%d" % GameRun.SECRET_UNLOCK_PRICE,
		VIOLET, u * 4.2, Vector2(u * 46.0, u * 10.0))
	unlock_button.pressed.connect(_on_unlock_pressed)
	center.add_child(unlock_button)

func _on_unlock_pressed() -> void:
	unlock_requested.emit()

# --- Käufe --------------------------------------------------------------------

func _on_offer_pressed(index: int) -> void:
	if run == null or index < 0 or index >= run.secret_stock.size():
		return
	var price := int(run.secret_stock[index][GameRun.OFFER_PRICE])
	if run.buy_secret_offer(index):  # Refresh kommt über secret_stock_changed
		charge_spent.emit(price)

func _on_reroll_pressed() -> void:
	if run == null:
		return
	var cost := run.secret_reroll_cost()
	if run.reroll_secret_stock():
		charge_spent.emit(cost)

func _on_run_changed() -> void:
	_refresh_offers()

## Ladung allein ändert die Auslage nicht - nur wer was bezahlen kann.
func _on_charge_changed(_value: int) -> void:
	if _built and run != null:
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
	CasinoStyle.style_score_label(detail_title, int(u * 3.2), CasinoStyle.GOLD)
	col.add_child(detail_title)
	detail_body = Label.new()
	detail_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body.custom_minimum_size = Vector2(u * 36.0, 0)
	CasinoStyle.style_body_label(detail_body, int(u * 2.4), CasinoStyle.CREAM)
	col.add_child(detail_body)
	add_child(detail_card)

## Zeigt die Karte unter (notfalls über) dem Angebot, immer im Fenster eingeklemmt.
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
