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

## Oberer Bereich: vier Charms je Doppelseite (nur Symbol, Beschreibung erst im
## Hover-Dropdown).
const CHARM_OFFER_COUNT := 4

## Unterer Bereich: zwei Reihen à vier Angeboten (Würfel-Bündel ODER Sigill).
const BOTTOM_SLOT_COUNT := 8
const BOTTOM_GRID_COLUMNS := 4

## Würfel-Bündel im unteren Bereich; der Rest der acht Plätze sind Sigille.
const DICE_OFFER_COUNT := 3
const SIGIL_OFFER_COUNT := BOTTOM_SLOT_COUNT - DICE_OFFER_COUNT

## Gebühr fürs Aufschlagen einer NEUEN Doppelseite: $2, dann $3, $4 ...
## Je Besuch zurückgesetzt.
const FLIP_FEE_BASE := 2

## Preis je einzelnem Sigill nach Seltenheit.
const SIGIL_PRICES := {
	Sigil.Rarity.COMMON: 5,
	Sigil.Rarity.UNCOMMON: 9,
	Sigil.Rarity.RARE: 15,
}

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
	var sigil_offers: Array[Sigil] = []  # fünf gemischte Sigille für den unteren Bereich
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
var content_root: VBoxContainer  # trägt Charm-Bereich + Angebots-Bereich
var page_label: Label
var done_button: Button
var page_back_button: Button
var page_next_button: Button

## Hover-Dropdown (Charm-/Sigil-Beschreibung), wie die Gravur-Station.
var shop_tooltip: PanelContainer
var shop_tooltip_title: Label
var shop_tooltip_body: Label

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

## Kopfzeile (Titel + Geld), Inhalts-Bereich (Charms oben, Angebote unten),
## Fußbereich (Blättern + Fertig). Der Neon-Rahmen kommt vom Hub darunter.
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

	# Inhalts-Bereich: die zwei Zonen (Charms / Angebote) baut _rebuild_content je Seite.
	content_root = VBoxContainer.new()
	content_root.name = "Content"
	content_root.add_theme_constant_override("separation", int(u * 1.6))
	content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content_root)

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

	_build_shop_tooltip()  # zuletzt: liegt als Overlay über allem

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

## Frische Doppelseite: vier Charms oben, unten drei Würfel-Bündel + fünf Sigille.
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
	for i in CHARM_OFFER_COUNT:
		if available.is_empty():
			break
		var pick := Charm.pick_weighted(available)
		spread.charm_options.append(pick)
		available.erase(pick)
	spread.charm_bought.resize(spread.charm_options.size())
	spread.charm_bought.fill(false)

	# Gemischte Einzel-Sigille (alle Kategorien, seltenheits-gewichtet).
	spread.sigil_offers = Sigil.roll_draft(SIGIL_OFFER_COUNT, Sigil.Rarity.COMMON)
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

	_rebuild_content(spread)
	page_label.text = "Seite %d" % (current_spread_index + 1)
	_refresh_afford_state()

## Gibt den Inhalt frei - auch beim Schließen wichtig, damit die
## 3D-Vorschau-Viewports nicht im Hintergrund weiterrendern.
func _clear_pages() -> void:
	if content_root != null:
		for child in content_root.get_children():
			child.queue_free()
	offer_buy_buttons.clear()
	charm_buttons.clear()
	sigil_buttons.clear()
	sigil_button_prices.clear()

## Baut die zwei Zonen: oben die vier Charms (nur Symbol), unten das 2×4-Raster
## aus Würfel-Bündeln und Sigillen.
func _rebuild_content(spread: MenuSpread) -> void:
	for child in content_root.get_children():
		child.queue_free()
	offer_buy_buttons.clear()
	charm_buttons.clear()
	sigil_buttons.clear()
	sigil_button_prices.clear()

	# Zone 1: Charms (nur Symbol; Beschreibung erscheint als Hover-Dropdown).
	content_root.add_child(_section_heading("CHARMS – je $%d" % _charm_price()))
	var charm_row := GridContainer.new()
	charm_row.columns = CHARM_OFFER_COUNT
	charm_row.add_theme_constant_override("h_separation", int(u * 1.5))
	charm_row.add_theme_constant_override("v_separation", int(u * 1.0))
	content_root.add_child(charm_row)
	for i in spread.charm_options.size():
		charm_row.add_child(_build_charm_card(spread.charm_options[i], i))

	# Zone 2: Angebote - zwei Reihen à vier (Würfel-Bündel zuerst, dann Sigille).
	content_root.add_child(_section_heading("ANGEBOTE"))
	var options := GridContainer.new()
	options.columns = BOTTOM_GRID_COLUMNS
	options.add_theme_constant_override("h_separation", int(u * 1.2))
	options.add_theme_constant_override("v_separation", int(u * 1.0))
	options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_root.add_child(options)
	for i in spread.dice_offers.size():
		options.add_child(_build_offer_card(spread.dice_offers[i], i))
	for i in spread.sigil_offers.size():
		options.add_child(_build_sigil_card(spread.sigil_offers[i], i))

## Charm-Karte: nur das Symbol + Preis; Name und Wirkung zeigt der Hover-Dropdown.
func _build_charm_card(charm: Charm, index: int) -> Control:
	var owned := charm_bought[index] or run.owned_charm_ids().has(charm.id)
	var card := _neon_button("", NEON_MAGENTA, u * 2.0)
	card.custom_minimum_size = Vector2(0, u * 12.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_entered.connect(_show_shop_tooltip.bind(card, charm.display_name, charm.description))
	card.mouse_exited.connect(_hide_shop_tooltip)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(u * 0.4))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	var thumb_holder := CenterContainer.new()
	thumb_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_holder.add_child(CharmThumb.new(charm, int(u * 7.5)))
	column.add_child(thumb_holder)

	column.add_child(_label("gekauft" if owned else "$%d" % _charm_price(),
		u * 2.0, NEON_MUTED if owned else NEON_GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	if owned:
		card.disabled = true
	else:
		card.pressed.connect(_on_charm_clicked.bind(index))
	charm_buttons.append(card)
	return card

## Sigil-Karte im Angebots-Raster: prozedurales Siegel, Name, Kaufknopf mit Preis;
## Kategorie/Seltenheit/Wirkung zeigt der Hover-Dropdown. Nach dem Kauf "gekauft".
func _build_sigil_card(sigil: Sigil, offer_index: int) -> Control:
	var price := _sigil_price(sigil)

	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", int(u * 0.4))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var thumb := SigilRenderer.for_sigil(sigil)
	thumb.custom_minimum_size = Vector2(u * 8.0, u * 8.0)
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(thumb)

	var name_label := _label(sigil.display_name, u * 1.8, NEON_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.clip_text = true
	card.add_child(name_label)

	var button := _neon_button("", NEON_GREEN, u * 2.0, Vector2(0, u * 4.0))
	button.mouse_entered.connect(_show_shop_tooltip.bind(button,
		"%s – %s (%s)" % [sigil.display_name, sigil.category_name(), Sigil.rarity_name(sigil.rarity)],
		sigil.description))
	button.mouse_exited.connect(_hide_shop_tooltip)
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

	var dice_row := DiceRowView.build_row(offer.dice[0], int(u * 5.0), offer.size())
	dice_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(dice_row)

	# Veredelungen benennen - die Mini-Vorschau allein ist zu klein, und der
	# Aufpreis soll lesbar begründet sein.
	var refinements := _refinement_text(offer.dice[0])
	if refinements != "":
		var refined_label := _label("Veredelt: %s" % refinements, u * 1.7, NEON_GOLD)
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

func _label(text: String, font_size: float, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

# --- Hover-Dropdown (wie die Gravur-Station) -----------------------------------

func _build_shop_tooltip() -> void:
	shop_tooltip = PanelContainer.new()
	shop_tooltip.name = "ShopTooltip"
	shop_tooltip.visible = false
	shop_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_panel(shop_tooltip)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", int(u * 0.4))
	shop_tooltip.add_child(box)
	shop_tooltip_title = Label.new()
	shop_tooltip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_score_label(shop_tooltip_title, int(u * 2.6), CasinoStyle.GOLD)
	box.add_child(shop_tooltip_title)
	shop_tooltip_body = Label.new()
	shop_tooltip_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_tooltip_body.custom_minimum_size = Vector2(u * 28.0, 0)
	CasinoStyle.style_body_label(shop_tooltip_body, int(u * 1.9), CasinoStyle.CREAM)
	box.add_child(shop_tooltip_body)
	add_child(shop_tooltip)

## Zeigt den Dropdown unter (oder notfalls über) dem überfahrenen Element,
## immer im Panel eingeklemmt (clip_contents schneidet Überstände ab).
func _show_shop_tooltip(anchor: Control, title: String, body: String) -> void:
	if shop_tooltip == null:
		return
	shop_tooltip_title.text = title
	shop_tooltip_body.text = body
	shop_tooltip.visible = true
	shop_tooltip.reset_size()
	var local := anchor.get_global_rect().position - get_global_rect().position
	var below := local.y + anchor.size.y + u * 0.6
	var above := local.y - shop_tooltip.size.y - u * 0.6
	var pos := Vector2(local.x, below)
	if below + shop_tooltip.size.y > size.y - u * 1.0 and above >= u * 1.0:
		pos.y = above  # unten kein Platz -> über das Element klappen
	pos.x = clampf(pos.x, u * 1.0, maxf(u * 1.0, size.x - shop_tooltip.size.x - u * 1.0))
	pos.y = clampf(pos.y, u * 1.0, maxf(u * 1.0, size.y - shop_tooltip.size.y - u * 1.0))
	shop_tooltip.position = pos

func _hide_shop_tooltip() -> void:
	if shop_tooltip != null:
		shop_tooltip.visible = false

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
