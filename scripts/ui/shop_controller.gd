class_name ShopController
extends Panel
## Der Shop als eigenständiger Controller auf dem ShopPanel (siehe
## scenes/scene_root.tscn). Übernimmt die komplette Shop-UI und Kauf-Interaktion;
## die Spielzustands-Mutation (Geld, Charms, Pool) liegt beim GameRun (siehe
## scripts/game_run.gd), den der Besitzer (scene_root) über run hereinreicht.
## Auf das closed-Signal reagiert weiterhin scene_root (Rundenwechsel). So
## wächst scene_root nicht weiter mit, und künftige Shop-Kategorien bekommen
## hier ihren Platz.
##
## Käufe wirken sofort (kein Bestätigen nötig): der Spieler kauft, so viel er
## sich leisten will/kann, und schließt selbst mit "Fertig" ab. Würfel sind
## beliebig oft nachkaufbar, jeder angebotene Charm nur einmal pro Besuch (danach
## besitzt man ihn ja).

## Wird ausgelöst, wenn der Spieler den Shop mit "Fertig" verlässt.
signal closed

const CHARM_PRICE := 25  # Preis pro Charm-Kauf
const DICE_OFFER_COUNT := 3  # wie viele Würfel-Angebote je Besuch ausliegen (siehe DiceOffer)
const OFFER_THUMB_SIZE := 60  # Kantenlänge der Mini-Vorschau je Angebots-Würfel (siehe DiceRowView)

## Angebotene Coupon-Bögen (siehe CouponSheet): je größer das Raster, desto teurer
## und desto größere Coupons können darauf liegen (die Fläche IST die Rarität).
## Man erhält alle echten Ätzungen des Bogens; Lücken sind Marken/Werbeflächen.
const SHEET_OFFERS := [
	{"kind": CouponSheet.Kind.SNIPPET, "name": "Schnipsel", "price": 6},
	{"kind": CouponSheet.Kind.SHEET, "name": "Bogen", "price": 10},
	{"kind": CouponSheet.Kind.LARGE, "name": "Großbogen", "price": 16},
]

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
@onready var dice_section_label: Label = $VBoxContainer/DiceSectionLabel
@onready var offers_list: VBoxContainer = $VBoxContainer/DiceOffersScroll/OffersList
@onready var charm_section_label: Label = $VBoxContainer/CharmSectionLabel
@onready var charm_options_container: HBoxContainer = $VBoxContainer/CharmOptionsContainer
@onready var coupon_section_label: Label = $VBoxContainer/CouponSectionLabel
@onready var coupon_sheet_container: HBoxContainer = $VBoxContainer/CouponSheetContainer
@onready var message_label: Label = $VBoxContainer/ShopMessageLabel
@onready var done_button: Button = $VBoxContainer/DoneButton

var dice_offers: Array[DiceOffer] = []  # Würfel-Angebote dieses Besuchs (Reihenfolge = offers_list)
var offer_buy_buttons: Array[Button] = []  # Kauf-Buttons je Angebot, für die Kaufbarkeits-Aktualisierung
var charm_options: Array[Charm] = []  # Charm-Angebot dieses Besuchs (Reihenfolge = charm_options_container)
var charm_buttons: Array[Button] = []  # dynamisch gebaute Buttons für charm_options
var charm_bought: Array[bool] = []  # welche charm_options in diesem Besuch schon gekauft wurden
var sheet_buttons: Array[Button] = []  # feste Bogen-Kauf-Buttons (Reihenfolge = SHEET_OFFERS)

func _ready() -> void:
	_style()
	_build_sheet_buttons()
	done_button.pressed.connect(_on_done_pressed)

## Baut die drei festen Bogen-Kauf-Buttons (Schnipsel/Bogen/Großbogen, siehe
## SHEET_OFFERS) - beliebig oft nachkaufbar, solange genug Geld da ist.
func _build_sheet_buttons() -> void:
	for i in SHEET_OFFERS.size():
		var offer: Dictionary = SHEET_OFFERS[i]
		var grid: Vector2i = CouponSheet.grid_size(offer["kind"])
		var button := Button.new()
		button.text = "%s\n%d×%d · $%d" % [offer["name"], grid.x, grid.y, offer["price"]]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_sheet_pressed.bind(i))
		CasinoStyle.style_button(button, CasinoStyle.GREEN, CasinoStyle.GREEN_DARK, 14)
		coupon_sheet_container.add_child(button)
		sheet_buttons.append(button)

## Casino-Look des Shops (siehe CasinoStyle) - der Shop stylt sich selbst, damit
## scene_root._style_ui nichts davon kennen muss.
func _style() -> void:
	CasinoStyle.style_panel(self)
	CasinoStyle.style_score_label(title_label, 22, CasinoStyle.GOLD)
	CasinoStyle.style_chip_label(dice_section_label, 18, CasinoStyle.BLUE)
	CasinoStyle.style_chip_label(charm_section_label, 18, CasinoStyle.PURPLE)
	CasinoStyle.style_chip_label(coupon_section_label, 18, CasinoStyle.GREEN)
	CasinoStyle.style_body_label(message_label, 15, CasinoStyle.GREEN)
	CasinoStyle.style_button(done_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK)

## Öffnet den Shop: Angebot frisch auswürfeln und anzeigen. Sichtbarkeit/
## Spielzustand steuert der Aufrufer (scene_root._on_round_complete).
func open() -> void:
	message_label.text = ""
	dice_section_label.text = "Würfel-Angebote"
	coupon_section_label.text = "Coupon-Bögen"
	_populate_dice_offers()
	_populate_charm_options()
	_refresh_afford_state()
	visible = true

## Würfelt die Würfel-Angebote dieses Besuchs frisch aus (siehe DiceOffer) und
## baut je Angebot eine liegende Karte (siehe _build_offer_card): links die
## Würfel im Sammlungs-Look (Bild · Augensumme · Seiten), rechts Name und
## Kauf-Button mit (ggf. rabattiertem) Preis. Angebote sind beliebig oft
## nachkaufbar; mehr Würfel je Bündel = einzeln schwächere Würfel.
func _populate_dice_offers() -> void:
	_clear_offers()
	dice_offers = DiceOffer.roll_offers(DICE_OFFER_COUNT)
	for i in dice_offers.size():
		offers_list.add_child(_build_offer_card(dice_offers[i], i))

## Gibt die Angebotskarten samt ihrer 3D-Vorschau-Viewports frei - beim
## Neu-Bestücken und beim Schließen, damit im Hintergrund nichts weiterrendert
## (die Vorschauen laufen mit UPDATE_ALWAYS, siehe DiceRowView).
func _clear_offers() -> void:
	for child in offers_list.get_children():
		child.queue_free()
	offer_buy_buttons.clear()

## Eine liegende Angebotskarte: links EINE Würfel-Zeile im Sammlungs-Look mit
## vorangestelltem "N ×"-Stück-Multiplikator (alle Würfel eines Bündels sind
## gleich, siehe DiceOffer - daher nur einmal gezeigt), rechts eine schmale
## Info-Spalte (Name, Kauf-Button mit Preis nach Rabatt-Charms).
func _build_offer_card(offer: DiceOffer, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.06)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var die_row := DiceRowView.build_row(offer.dice[0], OFFER_THUMB_SIZE, offer.size())
	die_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	die_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(die_row)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.custom_minimum_size = Vector2(160, 0)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = offer.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CasinoStyle.style_chip_label(name_label, 16, CasinoStyle.BLUE)
	info.add_child(name_label)

	var buy := Button.new()
	buy.text = "Kaufen\n$%d" % _offer_price(offer)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.pressed.connect(_on_offer_pressed.bind(index))
	CasinoStyle.style_button(buy, CasinoStyle.BLUE, CasinoStyle.BLUE_DARK, 15)
	info.add_child(buy)
	offer_buy_buttons.append(buy)
	return card

## Würfelt die Charm-Angebote dieses Besuchs aus - alle Charm-Archetypen (siehe
## Charm.all), die der Spieler noch nicht besitzt, max. zwei Stück. Baut die
## Charm-Buttons komplett neu auf, da sich das Angebot bei jedem Besuch ändert.
func _populate_charm_options() -> void:
	for button in charm_buttons:
		button.queue_free()
	charm_buttons.clear()

	var owned_ids: Array[String] = run.charm_ids()
	var available: Array[Charm] = []
	for charm in Charm.all():
		if not owned_ids.has(charm.id):
			available.append(charm)
	available.shuffle()

	charm_options = []
	for i in mini(2, available.size()):
		charm_options.append(available[i])
	charm_bought = []
	charm_bought.resize(charm_options.size())
	charm_bought.fill(false)

	charm_section_label.visible = not charm_options.is_empty()
	for i in charm_options.size():
		var charm := charm_options[i]
		var button := Button.new()
		button.text = "%s\n%s\n$%d" % [charm.display_name, charm.description, CHARM_PRICE]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(280, 84)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = charm.description
		button.pressed.connect(_on_charm_clicked.bind(i))
		CasinoStyle.style_button(button, CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, 14)
		charm_options_container.add_child(button)
		charm_buttons.append(button)
	_refresh_afford_state()

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

## Kauft den angeklickten Charm sofort (siehe run.purchase_charm) - je Charm
## nur einmal pro Besuch. Der Button ist bei fehlendem Geld schon deaktiviert
## (siehe _refresh_afford_state), Godot liefert für deaktivierte Buttons
## kein pressed-Signal - ein Klick kann hier also nur bei ausreichend Geld ankommen.
func _on_charm_clicked(index: int) -> void:
	if charm_bought[index]:
		return
	var charm := charm_options[index]
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

## Deaktiviert Käufe, die sich der Spieler nicht mehr leisten kann - je Angebot
## seinen (rabattierten) Preis, noch nicht gekaufte Charm-Buttons (CHARM_PRICE)
## und je Bogen-Button den eigenen Preis. Geld sinkt innerhalb eines Besuchs nur
## (kein Einkommen mittendrin), ein deaktivierter Button muss also nie reaktiviert werden.
func _refresh_afford_state() -> void:
	var money: int = run.money
	for i in offer_buy_buttons.size():
		offer_buy_buttons[i].disabled = money < _offer_price(dice_offers[i])
	for i in charm_buttons.size():
		if not charm_bought[i]:
			charm_buttons[i].disabled = money < CHARM_PRICE
	for i in sheet_buttons.size():
		sheet_buttons[i].disabled = money < SHEET_OFFERS[i]["price"]

## Das Geld hat sich geändert, während der Shop offen ist (siehe run-Setter):
## Kaufbarkeit neu bewerten. Wichtig, wenn das Geld NICHT durch einen Shop-Kauf
## steigt - z.B. die Chip-Coupons der Bogen-Abschluss-Animation (siehe
## scene_root: _grant_chip_coupon) sollen sofort wieder Käufe freischalten.
func _on_run_money_changed(_money: int) -> void:
	if visible:
		_refresh_afford_state()

func _on_done_pressed() -> void:
	_clear_offers()  # 3D-Vorschauen freigeben (kein Hintergrund-Rendern nach dem Schließen)
	visible = false
	closed.emit()
