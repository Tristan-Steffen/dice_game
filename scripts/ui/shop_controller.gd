class_name ShopController
extends Panel
## Der Shop als aufgeschlagene Speisekarte: zwei cremefarbene Seiten nebeneinander
## (links die Würfel-Angebote, rechts Charms und Coupon-Bögen), durch die man wie
## in einem kleinen Buch blättert. Umblättern auf eine NOCH NICHT gesehene Seite
## würfelt frische Angebote aus und kostet eine steigende Gebühr (siehe
## FLIP_FEE_BASE - das ist der "Reroll"); Zurückblättern und erneutes
## Vorblättern auf bereits aufgeschlagene Seiten ist gratis, denn die Seiten
## eines Buchs bleiben ja stehen (siehe MenuSpread - inklusive gekaufter Charms).
##
## Die Spielzustands-Mutation (Geld, Charms, Pool) liegt beim GameRun (siehe
## scripts/core/game_run.gd), den der Besitzer (scene_root) über run hereinreicht;
## auf das closed-Signal reagiert scene_root (Rundenwechsel). Käufe wirken sofort
## und sind beliebig oft wiederholbar (Charms je einmal - danach besitzt man sie).

## Wird ausgelöst, wenn der Spieler den Shop mit "Fertig" verlässt.
signal closed

const CHARM_PRICE := 25  # Preis pro Charm-Kauf
const DICE_OFFER_COUNT := 3  # Würfel-Angebote je Doppelseite (siehe DiceOffer)
const OFFER_THUMB_SIZE := 52  # Kantenlänge der Mini-Vorschau je Angebots-Würfel (siehe DiceRowView)

## Gebühr fürs Aufschlagen einer NEUEN Doppelseite: erst $2, dann $3, $4 ...
## (fee = FLIP_FEE_BASE + bereits existierende Seiten - 1). Je Besuch zurückgesetzt.
const FLIP_FEE_BASE := 2

## Angebotene Coupon-Bögen (siehe CouponSheet): je größer das Raster, desto teurer
## und desto größere Coupons können darauf liegen (die Fläche IST die Rarität).
## Als festes "Getränke-Sortiment" auf jeder Doppelseite identisch.
const SHEET_OFFERS := [
	{"kind": CouponSheet.Kind.SNIPPET, "name": "Schnipsel", "price": 6},
	{"kind": CouponSheet.Kind.SHEET, "name": "Bogen", "price": 10},
	{"kind": CouponSheet.Kind.LARGE, "name": "Großbogen", "price": 16},
]

const PAPER_COLOR := Color("efe4c8")  # cremefarbenes Menü-Papier (wie die Coupon-Bögen)
const PAPER_EDGE := Color("c9b98f")   # abgedunkelter Papierrand
const INK := Color(0.16, 0.14, 0.1)   # dunkle "Druckfarbe" für Überschriften auf Papier
const FLIP_DURATION := 0.22  # rein kosmetisches Auffalten der neuen Doppelseite

## Eine aufgeschlagene Doppelseite des Menüs: ihre Würfel-Angebote, ihr
## Charm-Angebot und welche Charms darauf schon gekauft wurden. Bleibt für den
## ganzen Besuch bestehen - Zurückblättern zeigt exakt diese Seite wieder.
class MenuSpread:
	extends RefCounted

	var dice_offers: Array[DiceOffer] = []
	var charm_options: Array[Charm] = []
	var charm_bought: Array[bool] = []

## Der laufende Spiellauf (vom Besitzer scene_root gesetzt) - alle Käufe
## mutieren den Zustand ausschließlich über seine Methoden (siehe GameRun). Der
## Shop hört auf money_changed, damit sich die Kaufbarkeit auch aktualisiert,
## wenn das Geld NICHT durch einen Shop-Kauf steigt - etwa durch die
## Chip-Coupons der Bogen-Abschluss-Animation (siehe scene_root: _grant_chip_coupon).
var run: GameRun:
	set(value):
		if run != null and run.money_changed.is_connected(_on_run_money_changed):
			run.money_changed.disconnect(_on_run_money_changed)
		run = value
		if run != null:
			run.money_changed.connect(_on_run_money_changed)

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var book: HBoxContainer = $VBoxContainer/Book
@onready var left_page: PanelContainer = $VBoxContainer/Book/LeftPage
@onready var left_content: VBoxContainer = $VBoxContainer/Book/LeftPage/LeftContent
@onready var right_page: PanelContainer = $VBoxContainer/Book/RightPage
@onready var right_content: VBoxContainer = $VBoxContainer/Book/RightPage/RightContent
@onready var page_back_button: Button = $VBoxContainer/NavRow/PageBackButton
@onready var page_info_label: Label = $VBoxContainer/NavRow/PageInfoLabel
@onready var page_next_button: Button = $VBoxContainer/NavRow/PageNextButton
@onready var message_label: Label = $VBoxContainer/ShopMessageLabel
@onready var done_button: Button = $VBoxContainer/DoneButton

## Alle in diesem Besuch aufgeschlagenen Doppelseiten (Index 0 = erste).
var spreads: Array[MenuSpread] = []
var current_spread_index: int = 0

# Spiegel der AKTUELLEN Doppelseite - Kauf-Handler und Tests arbeiten dagegen
# (dice_offers/charm_options/charm_bought referenzieren die Arrays des Spreads).
var dice_offers: Array[DiceOffer] = []
var offer_buy_buttons: Array[Button] = []
var charm_options: Array[Charm] = []
var charm_buttons: Array[Button] = []
var charm_bought: Array[bool] = []
var sheet_buttons: Array[Button] = []

func _ready() -> void:
	_style()
	page_back_button.pressed.connect(_on_page_back_pressed)
	page_next_button.pressed.connect(_on_page_next_pressed)
	done_button.pressed.connect(_on_done_pressed)

## Casino-Look des Rahmens + Papier-Look der beiden Menü-Seiten. Der Shop stylt
## sich selbst, damit scene_root._style_ui nichts davon kennen muss.
func _style() -> void:
	CasinoStyle.style_panel(self)
	CasinoStyle.style_score_label(title_label, 22, CasinoStyle.GOLD)
	CasinoStyle.style_body_label(message_label, 15, CasinoStyle.GREEN)
	CasinoStyle.style_chip_label(page_info_label, 15, CasinoStyle.GOLD)
	CasinoStyle.style_button(page_back_button, CasinoStyle.BLUE, CasinoStyle.BLUE_DARK, 15)
	CasinoStyle.style_button(page_next_button, CasinoStyle.BLUE, CasinoStyle.BLUE_DARK, 15)
	CasinoStyle.style_button(done_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK)
	left_page.add_theme_stylebox_override("panel", _paper_box())
	right_page.add_theme_stylebox_override("panel", _paper_box())

## Cremefarbenes Seitenpapier mit dunklerem Rand und weichem Schatten.
func _paper_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER_COLOR
	box.border_color = PAPER_EDGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 3)
	box.set_content_margin_all(14)
	return box

## Öffnet den Shop: das Menü beginnt frisch auf der ersten Doppelseite (alle
## Seiten des vorigen Besuchs sind Geschichte, die Blätter-Gebühr startet neu).
## Sichtbarkeit/Spielzustand steuert der Aufrufer (scene_root._on_round_complete).
func open() -> void:
	message_label.text = ""
	spreads = [_build_spread()]
	current_spread_index = 0
	_show_spread()
	visible = true

# --- Blättern ------------------------------------------------------------------

## Gebühr fürs Aufschlagen der nächsten NEUEN Doppelseite (steigt je Besuch).
func _next_flip_fee() -> int:
	return FLIP_FEE_BASE + spreads.size() - 1

## True, wenn Vorblättern eine neue Doppelseite auswürfeln würde (statt eine
## bereits aufgeschlagene wieder zu zeigen).
func _next_flip_is_new() -> bool:
	return current_spread_index == spreads.size() - 1

## Vorblättern: auf eine bereits gesehene Seite gratis; ans Buchende blättern
## würfelt eine neue Doppelseite aus und kostet die steigende Gebühr.
func _on_page_next_pressed() -> void:
	if _next_flip_is_new():
		var fee := _next_flip_fee()
		if run.money < fee:
			message_label.text = "Nicht genug Geld zum Umblättern ($%d)." % fee
			return
		run.add_money(-fee)
		spreads.append(_build_spread())
		message_label.text = "Neue Doppelseite aufgeschlagen (-$%d)." % fee
	current_spread_index += 1
	_show_spread()
	_play_flip_animation()

## Zurückblättern ist immer gratis - die Seite steht ja schon im Buch.
func _on_page_back_pressed() -> void:
	if current_spread_index == 0:
		return
	current_spread_index -= 1
	_show_spread()
	_play_flip_animation()

## Rein kosmetisches "Auffalten" der (bereits umgebauten) Doppelseite - der
## Spielzustand ist zu diesem Zeitpunkt schon vollständig gewechselt, die
## Animation gate also nichts (wichtig für Tests und schnelles Klicken).
func _play_flip_animation() -> void:
	book.pivot_offset = book.size / 2.0
	book.scale = Vector2(0.08, 1.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(book, "scale", Vector2.ONE, FLIP_DURATION)

# --- Doppelseiten bauen ---------------------------------------------------------

## Würfelt eine frische Doppelseite aus: DICE_OFFER_COUNT Würfel-Angebote (siehe
## DiceOffer) und bis zu zwei noch nicht besessene Charms.
func _build_spread() -> MenuSpread:
	var spread := MenuSpread.new()
	spread.dice_offers = DiceOffer.roll_offers(DICE_OFFER_COUNT)

	var owned_ids: Array[String] = run.charm_ids()
	var available: Array[Charm] = []
	for charm in Charm.all():
		if not owned_ids.has(charm.id):
			available.append(charm)
	available.shuffle()
	for i in mini(2, available.size()):
		spread.charm_options.append(available[i])
	spread.charm_bought.resize(spread.charm_options.size())
	spread.charm_bought.fill(false)
	return spread

## Zeigt die aktuelle Doppelseite: Spiegel-Variablen umhängen, beide Seiten neu
## bebauen, Navigation und Kaufbarkeit aktualisieren.
func _show_spread() -> void:
	var spread := spreads[current_spread_index]
	dice_offers = spread.dice_offers
	charm_options = spread.charm_options
	charm_bought = spread.charm_bought

	_rebuild_left_page(spread)
	_rebuild_right_page(spread)

	page_info_label.text = "Seiten %d–%d" % [current_spread_index * 2 + 1, current_spread_index * 2 + 2]
	page_back_button.disabled = current_spread_index == 0
	_refresh_afford_state()

## Gibt die Inhalte beider Seiten frei - auch beim Schließen wichtig, damit die
## 3D-Vorschau-Viewports der Würfelzeilen nicht im Hintergrund weiterrendern.
func _clear_pages() -> void:
	for child in left_content.get_children():
		child.queue_free()
	for child in right_content.get_children():
		child.queue_free()
	offer_buy_buttons.clear()
	charm_buttons.clear()
	sheet_buttons.clear()

## Linke Menü-Seite: Überschrift + die Würfel-Angebote der Doppelseite.
func _rebuild_left_page(spread: MenuSpread) -> void:
	for child in left_content.get_children():
		child.queue_free()
	offer_buy_buttons.clear()

	left_content.add_child(_menu_heading("Würfel"))
	for i in spread.dice_offers.size():
		left_content.add_child(_build_offer_card(spread.dice_offers[i], i))
	left_content.add_child(_page_footer(current_spread_index * 2 + 1))

## Rechte Menü-Seite: Charms (je einmal kaufbar) + das feste Bogen-Sortiment.
func _rebuild_right_page(spread: MenuSpread) -> void:
	for child in right_content.get_children():
		child.queue_free()
	charm_buttons.clear()
	sheet_buttons.clear()

	right_content.add_child(_menu_heading("Charms (je $%d)" % CHARM_PRICE))
	for i in spread.charm_options.size():
		var charm := spread.charm_options[i]
		var button := Button.new()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 78)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = charm.description
		if spread.charm_bought[i] or run.charm_ids().has(charm.id):
			button.text = "%s (gekauft)\n%s" % [charm.display_name, charm.description]
			button.disabled = true
		else:
			button.text = "%s\n%s\n$%d" % [charm.display_name, charm.description, CHARM_PRICE]
			button.pressed.connect(_on_charm_clicked.bind(i))
		CasinoStyle.style_button(button, CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, 13)
		right_content.add_child(button)
		charm_buttons.append(button)

	right_content.add_child(_menu_heading("Coupon-Bögen"))
	for i in SHEET_OFFERS.size():
		var offer: Dictionary = SHEET_OFFERS[i]
		var grid: Vector2i = CouponSheet.grid_size(offer["kind"])
		var button := Button.new()
		button.text = "%s · %d×%d · $%d" % [offer["name"], grid.x, grid.y, offer["price"]]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 40)
		button.pressed.connect(_on_sheet_pressed.bind(i))
		CasinoStyle.style_button(button, CasinoStyle.GREEN, CasinoStyle.GREEN_DARK, 13)
		right_content.add_child(button)
		sheet_buttons.append(button)

	right_content.add_child(_page_footer(current_spread_index * 2 + 2))

## Überschrift in dunkler "Druckfarbe" auf dem Menü-Papier.
func _menu_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", INK)
	return label

## Seitenzahl-Fußzeile ("– N –", mittig, unten) wie in einer echten Speisekarte.
## Der davor gesetzte Streckplatz drückt sie ans Seitenende.
func _page_footer(page_number: int) -> Control:
	var holder := VBoxContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(spacer)
	var label := Label.new()
	label.text = "– %d –" % page_number
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", INK)
	holder.add_child(label)
	return holder

## Eine Angebotskarte auf der linken Seite: dunkle "gedruckte" Karte mit der
## Würfel-Zeile im Sammlungs-Look (mit "N ×"-Stück-Multiplikator, alle Würfel
## eines Bündels sind gleich - siehe DiceOffer) und dem Kauf-Button darunter.
func _build_offer_card(offer: DiceOffer, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.13, 0.18, 0.96)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(7)
	card.add_theme_stylebox_override("panel", box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	vbox.add_child(DiceRowView.build_row(offer.dice[0], OFFER_THUMB_SIZE, offer.size()))

	var buy := Button.new()
	buy.text = "%s · $%d" % [offer.display_name, _offer_price(offer)]
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.pressed.connect(_on_offer_pressed.bind(index))
	CasinoStyle.style_button(buy, CasinoStyle.BLUE, CasinoStyle.BLUE_DARK, 14)
	vbox.add_child(buy)
	offer_buy_buttons.append(buy)
	return card

# --- Käufe ----------------------------------------------------------------------

## Effektiver Angebotspreis nach Rabatt-Charms (Trickdieb-Manschette).
func _offer_price(offer: DiceOffer) -> int:
	return CharmEffects.die_price(offer.price, run.charm_ids())

## Kauft das komplette Würfel-Bündel des Angebots (siehe run.purchase_dice) -
## beliebig oft wiederholbar, solange genug Geld da ist.
func _on_offer_pressed(index: int) -> void:
	var offer := dice_offers[index]
	var price := _offer_price(offer)
	if run.money < price:
		message_label.text = "Nicht genug Geld für %s ($%d)." % [offer.display_name, price]
		return
	run.purchase_dice(offer.dice, price)
	message_label.text = "Gekauft: %s – %d Würfel (-$%d)" % [offer.display_name, offer.size(), price]
	_refresh_afford_state()

## Kauft den angeklickten Charm sofort (siehe run.purchase_charm) - je Charm nur
## einmal. Der Besitz-Check fängt auch den Fall ab, dass derselbe Charm auf zwei
## Doppelseiten dieses Besuchs angeboten wurde und schon woanders gekauft ist.
func _on_charm_clicked(index: int) -> void:
	var charm := charm_options[index]
	if charm_bought[index] or run.charm_ids().has(charm.id):
		return
	run.purchase_charm(charm, CHARM_PRICE)
	charm_bought[index] = true
	charm_buttons[index].disabled = true
	charm_buttons[index].text = "%s (gekauft)\n%s" % [charm.display_name, charm.description]
	message_label.text = "Gekauft: %s (-$%d)" % [charm.display_name, CHARM_PRICE]
	_refresh_afford_state()

## Kauft einen Coupon-Bogen (siehe run.buy_coupon_sheet / CouponSheet) - beliebig
## oft nachkaufbar. Die Enthüllung zeigt scene_root (hört auf run.sheet_purchased);
## hier steht nur die kurze Rückmeldung, wie viele echte Ätzungen darauf lagen.
func _on_sheet_pressed(index: int) -> void:
	var offer: Dictionary = SHEET_OFFERS[index]
	if run.money < offer["price"]:
		message_label.text = "Nicht genug Geld für %s ($%d)." % [offer["name"], offer["price"]]
		return
	var sheet := run.buy_coupon_sheet(offer["kind"], offer["price"])
	message_label.text = "%s: %d Ätzung(en) (-$%d)." % [offer["name"], sheet.etching_count(), offer["price"]]
	_refresh_afford_state()

## Deaktiviert alles, was sich der Spieler gerade nicht leisten kann - je Angebot
## seinen (rabattierten) Preis, unverkaufte Charms, Bögen und das Umblättern auf
## eine neue Doppelseite (dessen Button auch die fällige Gebühr anzeigt).
func _refresh_afford_state() -> void:
	var money: int = run.money
	for i in offer_buy_buttons.size():
		offer_buy_buttons[i].disabled = money < _offer_price(dice_offers[i])
	for i in charm_buttons.size():
		if not charm_bought[i]:
			charm_buttons[i].disabled = money < CHARM_PRICE or run.charm_ids().has(charm_options[i].id)
	for i in sheet_buttons.size():
		sheet_buttons[i].disabled = money < SHEET_OFFERS[i]["price"]
	if _next_flip_is_new():
		page_next_button.text = "Umblättern · $%d ›" % _next_flip_fee()
		page_next_button.disabled = money < _next_flip_fee()
	else:
		page_next_button.text = "Weiter ›"
		page_next_button.disabled = false

## Das Geld hat sich geändert, während der Shop offen ist (siehe run-Setter):
## Kaufbarkeit neu bewerten. Wichtig, wenn das Geld NICHT durch einen Shop-Kauf
## steigt - z.B. die Chip-Coupons der Bogen-Abschluss-Animation (siehe
## scene_root: _grant_chip_coupon) sollen sofort wieder Käufe freischalten.
func _on_run_money_changed(_money: int) -> void:
	if visible:
		_refresh_afford_state()

func _on_done_pressed() -> void:
	_clear_pages()  # 3D-Vorschauen freigeben (kein Hintergrund-Rendern nach dem Schließen)
	visible = false
	closed.emit()
