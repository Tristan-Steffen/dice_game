class_name ShopController
extends Control
## Der Shop zwischen den Runden - ein Neon-Panel auf der Hub-Fläche des
## Tisch-Displays, bedient über die Maus-Weiterleitung. Links Würfel-Angebote,
## rechts Charms und Coupon-Packs. "Umblättern" auf eine NEUE Seite würfelt
## frische Angebote aus und kostet eine steigende Gebühr; bereits gesehene
## Seiten bleiben stehen (MenuSpread) und sind gratis erreichbar.
## Zustands-Mutation läuft ausschließlich über GameRun-Methoden; auf closed
## reagiert scene_root. Alle Maße: Einheit u = Breite/100 (wie HubView).

signal closed

const CHARM_PRICE := 15
const DICE_OFFER_COUNT := 3

## Gebühr fürs Aufschlagen einer NEUEN Doppelseite: $2, dann $3, $4 ...
## Je Besuch zurückgesetzt.
const FLIP_FEE_BASE := 2

## Pack-Sorten (kinds -> CouponSheet.generate). Das gemischte Heft ist bewusst
## günstiger - wer gezielt zieht, zahlt für die Auswahl. Cover-Konvention:
## PACK_COVER_DIR + id + ".jpg".
const PACKS := [
	{"id": "general", "name": "Coupon-Heft", "kinds": [], "prices": [6, 10, 16, 25, 36],
		"tooltip": "Alle Coupon-Arten gemischt - dafür etwas günstiger."},
	{"id": "werkstatt", "name": "Werkstatt-Prospekt", "kinds": [Coupon.KIND_ETCHING], "prices": [8, 13, 20, 30, 42],
		"tooltip": "Nur Ätzungen: verändern die Augen deiner Würfel."},
	{"id": "juwelier", "name": "Juwelier-Katalog", "kinds": [Coupon.KIND_MATERIAL, Coupon.KIND_EDGE], "prices": [8, 13, 20, 30, 42],
		"tooltip": "Nur Würfel-Veredelungen: Seiten-Materialien und Kanten."},
	{"id": "tageskarte", "name": "Tageskarte", "kinds": [Coupon.KIND_MEAL], "prices": [8, 13, 20, 30, 42],
		"tooltip": "Nur Gerichte: werten Kombinationen dauerhaft auf."},
]

## Bogengrößen (Index = Preis-Index in PACKS.prices).
const PACK_SIZES := [
	{"kind": CouponSheet.Kind.SNIPPET, "label": "2×2"},
	{"kind": CouponSheet.Kind.SHEET, "label": "3×3"},
	{"kind": CouponSheet.Kind.LARGE, "label": "5×5"},
	{"kind": CouponSheet.Kind.POSTER, "label": "7×7"},
	{"kind": CouponSheet.Kind.JUMBO, "label": "9×9"},
]

const PACK_COVER_DIR := "res://assets/textures/packs/"

## Pack-Sortiment je Doppelseite: zufällige Kombinationen aus Sorte × Größe,
## jedes Angebot nur einmal kaufbar.
const PACK_GRID_COLUMNS := 3
const PACK_OFFER_COUNT := 6

## Farben im Display-Stil (80s Neon).
const NEON_CYAN := Color("#8be9fd")
const NEON_MAGENTA := Color("#ff79c6")
const NEON_GOLD := Color("#ffd319")
const NEON_GREEN := Color("#50fa7b")
const NEON_TEXT := Color(1.35, 1.35, 1.3)
const NEON_MUTED := Color(0.75, 0.78, 0.9)
const CARD_BG := Color("#241f4a99")

const FLIP_DURATION := 0.25

## Eine aufgeschlagene Doppelseite: bleibt für den ganzen Besuch bestehen -
## Zurückblättern zeigt exakt diese Seite wieder.
class MenuSpread:
	extends RefCounted

	var dice_offers: Array[DiceOffer] = []
	var charm_options: Array[Charm] = []
	var charm_bought: Array[bool] = []
	var pack_offers: Array[Vector2i] = []  # x = PACKS-Index, y = PACK_SIZES-Index
	var pack_bought: Array[bool] = []

## Bogen-Miniatur einer Pack-Karte: Cover-Motiv als "Papier" in Bogengröße,
## überzogen mit dem echten Raster als Perforationslinien - die Bogengröße ist
## auf einen Blick sichtbar.
class PackSheetThumb:
	extends Control

	const PAPER := Color("efe4c8")
	const PERF := Color(0.42, 0.29, 0.18, 0.7)
	const SIDE_BASE := 34.0
	const SIDE_PER_CELL := 4.0  # 2×2 -> 42px ... 9×9 -> 70px

	var texture: Texture2D
	var dims: int
	var side: float

	func _init(p_texture: Texture2D, p_dims: int, ui_scale: float = 1.0) -> void:
		texture = p_texture
		dims = p_dims
		side = (SIDE_BASE + p_dims * SIDE_PER_CELL) * ui_scale
		custom_minimum_size = Vector2(side, side)

	func _draw() -> void:
		var rect := Rect2((size.x - side) * 0.5, size.y - side, side, side)
		draw_rect(rect, PAPER)
		if texture != null:
			# Motiv seitengetreu einpassen (Cover sind nicht zwingend quadratisch).
			var inner := rect.grow(-2.0)
			var tex_size := texture.get_size()
			var fit := minf(inner.size.x / tex_size.x, inner.size.y / tex_size.y)
			var draw_size := tex_size * fit
			draw_texture_rect(texture, Rect2(inner.position + (inner.size - draw_size) * 0.5, draw_size), false)
		var cell := rect.size.x / float(dims)
		for i in range(1, dims):
			draw_line(Vector2(rect.position.x + i * cell, rect.position.y),
				Vector2(rect.position.x + i * cell, rect.end.y), PERF, 1.0)
			draw_line(Vector2(rect.position.x, rect.position.y + i * cell),
				Vector2(rect.end.x, rect.position.y + i * cell), PERF, 1.0)
		draw_rect(rect, PERF, false, 1.0)

## Der laufende Spiellauf (setzt scene_root). Der Shop hört auf money_changed,
## damit sich die Kaufbarkeit auch bei Geldzugängen von außen aktualisiert
## (z.B. Chip-Coupons der Bogen-Abschluss-Animation).
var run: GameRun:
	set(value):
		if run != null and run.money_changed.is_connected(_on_run_money_changed):
			run.money_changed.disconnect(_on_run_money_changed)
		run = value
		if run != null:
			run.money_changed.connect(_on_run_money_changed)

## Breiteneinheit (size.x / 100), in _build_layout gesetzt.
var u := 8.0

## Gerüst-Referenzen (je open() frisch gebaut).
var money_label: Label
var content_root: VBoxContainer
var left_column: VBoxContainer   # Würfel-Angebote
var right_column: VBoxContainer  # Charms + Coupon-Packs
var page_label: Label
var done_button: Button
var page_back_button: Button
var page_next_button: Button

var spreads: Array[MenuSpread] = []
var current_spread_index: int = 0

# Spiegel der AKTUELLEN Doppelseite - Kauf-Handler und Tests arbeiten dagegen.
var dice_offers: Array[DiceOffer] = []
var offer_buy_buttons: Array[Button] = []
var charm_options: Array[Charm] = []
var charm_buttons: Array[Button] = []
var charm_bought: Array[bool] = []
var pack_offers: Array[Vector2i] = []
var pack_bought: Array[bool] = []
var sheet_buttons: Array[Button] = []
var sheet_button_prices: Array[int] = []

var flip_tween: Tween

## Öffnet den Shop frisch auf der ersten Doppelseite (Gebühr startet neu);
## baut das Gerüst passend zur aktuellen Größe.
func open() -> void:
	_build_layout()
	spreads = [_build_spread()]
	current_spread_index = 0
	_show_spread()
	visible = true

# --- Gerüst (Neon-Panel) -----------------------------------------------------

## Kopfzeile (Titel + Geld), zwei Rubriken-Spalten, Fußbereich (Blättern +
## Fertig). Der Neon-Rahmen kommt vom Hub darunter.
func _build_layout() -> void:
	for child in get_children():
		child.queue_free()
	u = maxf(size.x, 640.0) / 100.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Inhalt darf nie über den Hub-Rahmen hinausragen (die Maus-Weiterleitung
	# endet an der Hub-Fläche).
	clip_contents = true

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
	root.add_theme_constant_override("separation", int(u * 1.2))
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.name = "Header"
	root.add_child(header)
	var title := _label("SHOP", u * 4.5, NEON_MAGENTA)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	money_label = _label("$0", u * 4.0, NEON_GOLD)
	header.add_child(money_label)

	content_root = VBoxContainer.new()
	content_root.name = "Content"
	content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content_root)
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.add_theme_constant_override("separation", int(u * 2.5))
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_root.add_child(columns)
	left_column = VBoxContainer.new()
	left_column.name = "DiceColumn"
	left_column.add_theme_constant_override("separation", int(u * 1.2))
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_stretch_ratio = 1.0
	columns.add_child(left_column)
	right_column = VBoxContainer.new()
	right_column.name = "CharmPackColumn"
	right_column.add_theme_constant_override("separation", int(u * 1.2))
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_stretch_ratio = 1.0
	columns.add_child(right_column)

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", int(u * 1.5))
	root.add_child(footer)
	page_back_button = _neon_button("‹", NEON_CYAN, u * 3.2, Vector2(u * 7.0, u * 5.0))
	page_back_button.pressed.connect(_on_page_back_pressed)
	footer.add_child(page_back_button)
	page_label = _label("Seite 1", u * 2.8, NEON_MUTED)
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(page_label)
	page_next_button = _neon_button("›", NEON_CYAN, u * 3.2, Vector2(u * 12.0, u * 5.0))
	page_next_button.pressed.connect(_on_page_next_pressed)
	footer.add_child(page_next_button)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(footer_spacer)
	done_button = _neon_button("Fertig", NEON_GOLD, u * 3.0, Vector2(u * 18.0, u * 5.0))
	done_button.pressed.connect(_on_done_pressed)
	footer.add_child(done_button)

# --- Blättern ------------------------------------------------------------------

## Gebühr für die nächste NEUE Doppelseite; Wechselgeld-Charm senkt sie.
func _next_flip_fee() -> int:
	return CharmEffects.flip_fee(FLIP_FEE_BASE + spreads.size() - 1, run.charm_ids())

## True, wenn Vorblättern eine neue Doppelseite auswürfeln würde.
func _next_flip_is_new() -> bool:
	return current_spread_index == spreads.size() - 1

func _on_page_next_pressed() -> void:
	if _next_flip_is_new():
		var fee := _next_flip_fee()
		if run.money < fee:
			return  # Knopf ist bei zu wenig Geld ohnehin deaktiviert
		run.add_money(-fee)
		spreads.append(_build_spread())
	current_spread_index += 1
	_show_spread()
	_play_flip_animation()

## Zurückblättern ist immer gratis.
func _on_page_back_pressed() -> void:
	if current_spread_index == 0:
		return
	current_spread_index -= 1
	_show_spread()
	_play_flip_animation()

## Rein kosmetische Einblendung - der Spielzustand ist schon gewechselt, die
## Animation gate nichts (schnelles Klicken ersetzt sie einfach).
func _play_flip_animation() -> void:
	if flip_tween != null and flip_tween.is_valid():
		flip_tween.kill()
	content_root.modulate = Color(1, 1, 1, 0)
	flip_tween = create_tween()
	flip_tween.tween_property(content_root, "modulate:a", 1.0, FLIP_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# --- Doppelseiten bauen --------------------------------------------------------

## Frische Doppelseite: Würfel-Angebote plus bis zu zwei unbesessene Charms.
func _build_spread() -> MenuSpread:
	var spread := MenuSpread.new()
	spread.dice_offers = DiceOffer.roll_offers(DICE_OFFER_COUNT, run.charm_ids())

	# Besitz-Prüfung über die ROHEN ids (Totems lösen sich in charm_ids() zu
	# ihren Nachbarn auf und würden sonst doppelt angeboten).
	var owned_ids: Array[String] = run.owned_charm_ids()
	var available: Array[Charm] = []
	for charm in Charm.all():
		if not owned_ids.has(charm.id):
			available.append(charm)
	# Gewichtet nach Rarität ziehen, ohne Zurücklegen.
	for i in 2:
		if available.is_empty():
			break
		var pick := Charm.pick_weighted(available)
		spread.charm_options.append(pick)
		available.erase(pick)
	spread.charm_bought.resize(spread.charm_options.size())
	spread.charm_bought.fill(false)

	var combos: Array[Vector2i] = []
	for p in PACKS.size():
		for s in PACK_SIZES.size():
			combos.append(Vector2i(p, s))
	combos.shuffle()
	spread.pack_offers = combos.slice(0, PACK_OFFER_COUNT)
	spread.pack_bought.resize(spread.pack_offers.size())
	spread.pack_bought.fill(false)
	return spread

## Zeigt die aktuelle Doppelseite: Spiegel-Variablen umhängen, Spalten neu
## bebauen, Navigation und Kaufbarkeit aktualisieren.
func _show_spread() -> void:
	var spread := spreads[current_spread_index]
	dice_offers = spread.dice_offers
	charm_options = spread.charm_options
	charm_bought = spread.charm_bought
	pack_offers = spread.pack_offers
	pack_bought = spread.pack_bought

	_rebuild_left_column(spread)
	_rebuild_right_column(spread)
	page_label.text = "Seite %d" % (current_spread_index + 1)
	_refresh_afford_state()

## Gibt beide Spalten frei - auch beim Schließen wichtig, damit die
## 3D-Vorschau-Viewports nicht im Hintergrund weiterrendern.
func _clear_pages() -> void:
	if left_column != null:
		for child in left_column.get_children():
			child.queue_free()
	if right_column != null:
		for child in right_column.get_children():
			child.queue_free()
	offer_buy_buttons.clear()
	charm_buttons.clear()
	sheet_buttons.clear()
	sheet_button_prices.clear()

func _rebuild_left_column(spread: MenuSpread) -> void:
	for child in left_column.get_children():
		child.queue_free()
	offer_buy_buttons.clear()

	left_column.add_child(_section_heading("WÜRFEL"))
	for i in spread.dice_offers.size():
		left_column.add_child(_build_offer_card(spread.dice_offers[i], i))

func _rebuild_right_column(spread: MenuSpread) -> void:
	for child in right_column.get_children():
		child.queue_free()
	charm_buttons.clear()
	sheet_buttons.clear()
	sheet_button_prices.clear()

	right_column.add_child(_section_heading("CHARMS – je $%d" % _charm_price()))
	for i in spread.charm_options.size():
		var charm := spread.charm_options[i]
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", int(u * 1.0))
		entry.add_child(CharmThumb.new(charm, int(u * 8.0)))

		var button := _neon_button("", NEON_MAGENTA, u * 2.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, u * 8.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.tooltip_text = charm.description
		if spread.charm_bought[i] or run.owned_charm_ids().has(charm.id):
			button.text = "%s (gekauft)\n%s" % [charm.display_name, charm.description]
			button.disabled = true
		else:
			button.text = "%s\n%s\n$%d" % [charm.display_name, charm.description, _charm_price()]
			button.pressed.connect(_on_charm_clicked.bind(i))
		entry.add_child(button)
		right_column.add_child(entry)
		charm_buttons.append(button)

	right_column.add_child(_section_heading("COUPON-PACKS"))
	var grid := GridContainer.new()
	grid.columns = PACK_GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", int(u * 1.0))
	grid.add_theme_constant_override("v_separation", int(u * 0.8))
	right_column.add_child(grid)
	for i in spread.pack_offers.size():
		var offer := spread.pack_offers[i]
		grid.add_child(_build_pack_card(offer.x, offer.y, i))

## Pack-Karte: Bogen-Miniatur, Pack-Name, Kaufknopf mit Größe · Preis.
## Nach dem Kauf "vergriffen" (nur einmal kaufbar).
func _build_pack_card(pack_index: int, size_index: int, offer_index: int) -> Control:
	var pack: Dictionary = PACKS[pack_index]
	var price := _pack_price(pack_index, size_index)
	var size_label: String = PACK_SIZES[size_index]["label"]

	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", int(u * 0.4))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = "%s (%s)\n%s" % [pack["name"], size_label, pack["tooltip"]]

	var cover_path: String = PACK_COVER_DIR + pack["id"] + ".jpg"
	var cover: Texture2D = load(cover_path) if ResourceLoader.exists(cover_path) else null
	var dims: int = CouponSheet.grid_size(PACK_SIZES[size_index]["kind"]).x
	var thumb := PackSheetThumb.new(cover, dims, u * 0.13)
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Zeile steht unten bündig
	card.add_child(thumb)

	var name_label := _label(pack["name"], u * 1.8, NEON_MUTED)
	name_label.clip_text = true
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)

	var button := _neon_button("", NEON_GREEN, u * 2.0, Vector2(0, u * 4.0))
	if pack_bought[offer_index]:
		button.text = "vergriffen"
		button.disabled = true
	else:
		button.text = "%s $%d" % [size_label, price]
		button.pressed.connect(_on_sheet_pressed.bind(offer_index))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(button)
	sheet_buttons.append(button)
	sheet_button_prices.append(price)
	return card

## Angebotskarte der Würfel-Rubrik: Würfel-Zeile mit "N ×"-Multiplikator
## (alle Würfel eines Bündels sind gleich) und Kauf-Button.
func _build_offer_card(offer: DiceOffer, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = CARD_BG
	box.border_color = Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.45)
	box.set_border_width_all(maxi(1, int(u * 0.2)))
	box.set_corner_radius_all(int(u * 1.0))
	box.set_content_margin_all(int(u * 0.8))
	card.add_theme_stylebox_override("panel", box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(u * 0.5))
	card.add_child(vbox)

	vbox.add_child(DiceRowView.build_row(offer.dice[0], int(u * 6.0), offer.size()))

	# Veredelungen benennen - die Mini-Vorschau allein ist zu klein, und der
	# Aufpreis soll lesbar begründet sein.
	var refinements := _refinement_text(offer.dice[0])
	if refinements != "":
		var refined_label := _label("Veredelt: %s" % refinements, u * 2.0, NEON_GOLD)
		refined_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(refined_label)

	var buy := _neon_button("%s · $%d" % [offer.display_name, _offer_price(offer)], NEON_CYAN, u * 2.2, Vector2(0, u * 4.2))
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.pressed.connect(_on_offer_pressed.bind(index))
	vbox.add_child(buy)
	offer_buy_buttons.append(buy)
	return card

## Kurzbeschreibung der Veredelungen ("" = keine), z.B.
## "2× Bernstein-Seite · Gold-Kanten".
func _refinement_text(def: DieDefinition) -> String:
	var parts: Array[String] = []
	var counts := {}
	for material_id in def.materials:
		if material_id != "":
			counts[material_id] = counts.get(material_id, 0) + 1
	for material_id in counts:
		var material_name: String = DieMaterial.by_id(material_id).display_name
		if counts[material_id] > 1:
			parts.append("%d× %s-Seite" % [counts[material_id], material_name])
		else:
			parts.append("%s-Seite" % material_name)
	if def.edge_material != "":
		parts.append("%s-Kanten" % DieMaterial.by_id(def.edge_material).display_name)
	return " · ".join(parts)

# --- Neon-Bausteine --------------------------------------------------------------

func _section_heading(text: String) -> Label:
	return _label(text, u * 2.8, NEON_CYAN)

func _label(text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Knopf im Display-Neon-Stil: dunkler Grund, Rahmen in der Rubriken-Farbe;
## Hover/Druck wechseln auf Gold, deaktiviert dimmt ab.
func _neon_button(text: String, accent: Color, font_size: float, min_size: Vector2 = Vector2.ZERO) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	button.add_theme_color_override("font_color", NEON_TEXT)
	button.add_theme_color_override("font_hover_color", NEON_GOLD)
	button.add_theme_color_override("font_pressed_color", NEON_GOLD)
	button.add_theme_color_override("font_disabled_color", Color(NEON_MUTED.r, NEON_MUTED.g, NEON_MUTED.b, 0.45))
	button.add_theme_stylebox_override("normal", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("hover", _button_box(Color("#2c2757dd"), NEON_GOLD))
	button.add_theme_stylebox_override("pressed", _button_box(Color("#3a2f66"), NEON_GOLD))
	button.add_theme_stylebox_override("focus", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("disabled", _button_box(Color("#1a183666"), Color(accent.r, accent.g, accent.b, 0.25)))
	return button

func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.22)))
	box.set_corner_radius_all(int(u * 0.9))
	box.set_content_margin_all(int(u * 0.8))
	return box

# --- Käufe ----------------------------------------------------------------------

func _offer_price(offer: DiceOffer) -> int:
	return CharmEffects.die_price(offer.price, run.charm_ids(), offer.size())

func _charm_price() -> int:
	return CharmEffects.charm_price(CHARM_PRICE, run.charm_ids())

func _pack_price(pack_index: int, size_index: int) -> int:
	var pack: Dictionary = PACKS[pack_index]
	return CharmEffects.pack_price(pack["prices"][size_index], pack["id"], run.charm_ids())

## Kauft das komplette Würfel-Bündel - beliebig oft wiederholbar.
func _on_offer_pressed(index: int) -> void:
	var offer := dice_offers[index]
	var price := _offer_price(offer)
	if run.money < price:
		return
	run.purchase_dice(offer.dice, price)
	_refresh_afford_state()

## Kauft den Charm (je einmal). Danach wird die ganze Doppelseite neu bebaut:
## Shop-Charms (Skonto, Wechselgeld, ...) wirken schon in DIESEM Besuch -
## alle Preisschilder und Schwellen zeigen sonst alte Preise.
func _on_charm_clicked(index: int) -> void:
	var charm := charm_options[index]
	if charm_bought[index] or run.owned_charm_ids().has(charm.id):
		return
	run.purchase_charm(charm, _charm_price())
	charm_bought[index] = true  # liegt im Spread - übersteht den Neuaufbau
	_show_spread()

## Kauft ein Coupon-Pack (jedes Angebot nur einmal); die Enthüllung zeigt
## scene_root (hört auf run.sheet_purchased).
func _on_sheet_pressed(offer_index: int) -> void:
	if pack_bought[offer_index]:
		return
	var offer := pack_offers[offer_index]
	var pack: Dictionary = PACKS[offer.x]
	var price := _pack_price(offer.x, offer.y)
	if run.money < price:
		return
	var allowed: Array[String] = []
	allowed.assign(pack["kinds"])
	run.buy_coupon_sheet(PACK_SIZES[offer.y]["kind"], price, allowed)
	# Kleingedrucktes: Chance auf volle Rückerstattung.
	if randf() < CharmEffects.pack_refund_chance(run.charm_ids()):
		run.add_money(price)
	pack_bought[offer_index] = true
	sheet_buttons[offer_index].disabled = true
	sheet_buttons[offer_index].text = "vergriffen"
	_refresh_afford_state()

## Deaktiviert alles Unbezahlbare und hält den Geldstand der Kopfzeile aktuell.
func _refresh_afford_state() -> void:
	var money: int = run.money
	if money_label != null:
		money_label.text = "$%d" % money
	for i in offer_buy_buttons.size():
		offer_buy_buttons[i].disabled = money < _offer_price(dice_offers[i])
	for i in charm_buttons.size():
		if not charm_bought[i]:
			charm_buttons[i].disabled = money < _charm_price() or run.owned_charm_ids().has(charm_options[i].id)
	for i in sheet_buttons.size():
		sheet_buttons[i].disabled = pack_bought[i] or money < sheet_button_prices[i]
	if page_back_button != null and is_instance_valid(page_back_button):
		page_back_button.disabled = current_spread_index == 0
	if page_next_button != null and is_instance_valid(page_next_button):
		if _next_flip_is_new():
			page_next_button.text = "$%d ›" % _next_flip_fee()
			page_next_button.disabled = money < _next_flip_fee()
		else:
			page_next_button.text = "›"
			page_next_button.disabled = false

func _on_run_money_changed(_money: int) -> void:
	if visible:
		_refresh_afford_state()

func _on_done_pressed() -> void:
	_clear_pages()  # 3D-Vorschauen freigeben (kein Hintergrund-Rendern)
	visible = false
	closed.emit()
