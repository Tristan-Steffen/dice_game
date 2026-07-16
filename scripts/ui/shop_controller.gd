class_name ShopController
extends Control
## Der Shop zwischen den Runden - ein Neon-Panel auf der Hub-Fläche des
## Tisch-Displays, bedient über die Maus-Weiterleitung. Links Würfel-Angebote,
## rechts Charms und einzelne Sigille (Zahlen/Materialien/Würfel). "Umblättern"
## auf eine NEUE Seite würfelt frische Angebote aus und kostet eine steigende
## Gebühr; bereits gesehene Seiten bleiben stehen (MenuSpread) und sind gratis
## erreichbar. Zustands-Mutation läuft ausschließlich über GameRun-Methoden; auf
## closed reagiert scene_root. Alle Maße: Einheit u = Breite/100 (wie HubView).

signal closed

const CHARM_PRICE := 15
const DICE_OFFER_COUNT := 3

## Gebühr fürs Aufschlagen einer NEUEN Doppelseite: $2, dann $3, $4 ...
## Je Besuch zurückgesetzt.
const FLIP_FEE_BASE := 2

## Preis je einzelnem Sigill nach Seltenheit.
const SIGIL_PRICES := {
	Sigil.Rarity.COMMON: 5,
	Sigil.Rarity.UNCOMMON: 9,
	Sigil.Rarity.RARE: 15,
}

## Angebote je Kategorie (Zahlen/Materialien/Würfel) auf einer Doppelseite;
## jedes Sigill nur einmal kaufbar.
const SIGIL_OFFERS_PER_CATEGORY := 2

## Grid-Spalten der Sigil-Auslage (eine Zeile je Kategorie).
const SIGIL_GRID_COLUMNS := 2

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
	var sigil_offers: Array[Sigil] = []  # nach Kategorie geordnet (Zahlen, Materialien, Würfel)
	var sigil_bought: Array[bool] = []

## Der laufende Spiellauf (setzt scene_root). Der Shop hört auf money_changed,
## damit sich die Kaufbarkeit auch bei Geldzugängen von außen aktualisiert.
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
var right_column: VBoxContainer  # Charms + Sigille
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
var sigil_offers: Array[Sigil] = []
var sigil_bought: Array[bool] = []
var sigil_buttons: Array[Button] = []
var sigil_button_prices: Array[int] = []

var flip_tween: Tween

## Einmalige Meldung, die beim nächsten Öffnen oben erscheint (Nebenwetten-
## Ergebnis der geräumten Runde); von scene_root vor open() gesetzt.
var pending_bet_notice: String = ""

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

	# Nebenwetten-Ergebnis der letzten Runde (einmalig, dann verbraucht).
	if pending_bet_notice != "":
		var notice := _label(pending_bet_notice, u * 2.3, NEON_GREEN)
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(notice)
		pending_bet_notice = ""

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
	right_column.name = "CharmSigilColumn"
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

	# Einzel-Sigille je Kategorie (Zahlen, Materialien, Würfel) in fester Reihenfolge.
	var sigils: Array[Sigil] = []
	for category in Sigil.CATEGORIES:
		sigils.append_array(Sigil.roll_in_category(category, SIGIL_OFFERS_PER_CATEGORY))
	spread.sigil_offers = sigils
	spread.sigil_bought.resize(spread.sigil_offers.size())
	spread.sigil_bought.fill(false)
	return spread

## Zeigt die aktuelle Doppelseite: Spiegel-Variablen umhängen, Spalten neu
## bebauen, Navigation und Kaufbarkeit aktualisieren.
func _show_spread() -> void:
	var spread := spreads[current_spread_index]
	dice_offers = spread.dice_offers
	charm_options = spread.charm_options
	charm_bought = spread.charm_bought
	sigil_offers = spread.sigil_offers
	sigil_bought = spread.sigil_bought

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
	sigil_buttons.clear()
	sigil_button_prices.clear()

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
	sigil_buttons.clear()
	sigil_button_prices.clear()

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

	# Einzel-Sigille nach Kategorie gruppiert (Zahlen, Materialien, Würfel).
	right_column.add_child(_section_heading("SIGILLE"))
	var by_category := {}
	for i in spread.sigil_offers.size():
		var cat: String = spread.sigil_offers[i].category
		if not by_category.has(cat):
			by_category[cat] = []
		by_category[cat].append(i)
	for category in Sigil.CATEGORIES:
		if not by_category.has(category):
			continue
		right_column.add_child(_label(Sigil.CATEGORY_NAMES[category], u * 2.2, NEON_MUTED))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(u * 1.0))
		right_column.add_child(row)
		for i in by_category[category]:
			row.add_child(_build_sigil_card(spread.sigil_offers[i], i))

## Sigil-Karte: prozedurales Siegel, Name, Kaufknopf mit Preis. Nach dem Kauf
## "gekauft" (jedes Sigill nur einmal je Doppelseite).
func _build_sigil_card(sigil: Sigil, offer_index: int) -> Control:
	var price := _sigil_price(sigil)

	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", int(u * 0.4))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = "%s – %s (%s)\n%s" % [
		sigil.display_name, sigil.category_name(), Sigil.rarity_name(sigil.rarity), sigil.description]

	var thumb := SigilRenderer.for_sigil(sigil)
	thumb.custom_minimum_size = Vector2(u * 9.0, u * 9.0)
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(thumb)

	var name_label := _label(sigil.display_name, u * 1.8, NEON_MUTED)
	name_label.clip_text = true
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)

	var button := _neon_button("", NEON_GREEN, u * 2.0, Vector2(0, u * 4.0))
	if sigil_bought[offer_index]:
		button.text = "gekauft"
		button.disabled = true
	else:
		button.text = "$%d" % price
		button.pressed.connect(_on_sigil_buy_pressed.bind(offer_index))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(button)
	sigil_buttons.append(button)
	sigil_button_prices.append(price)
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

func _sigil_price(sigil: Sigil) -> int:
	return SIGIL_PRICES.get(sigil.rarity, SIGIL_PRICES[Sigil.Rarity.UNCOMMON])

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

## Kauft ein einzelnes Sigill (jedes Angebot nur einmal); landet sofort im Inventar.
func _on_sigil_buy_pressed(offer_index: int) -> void:
	if sigil_bought[offer_index]:
		return
	var sigil := sigil_offers[offer_index]
	var price := _sigil_price(sigil)
	if run.money < price:
		return
	run.purchase_sigil(sigil, price)
	sigil_bought[offer_index] = true
	sigil_buttons[offer_index].disabled = true
	sigil_buttons[offer_index].text = "gekauft"
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
	for i in sigil_buttons.size():
		sigil_buttons[i].disabled = sigil_bought[i] or money < sigil_button_prices[i]
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
