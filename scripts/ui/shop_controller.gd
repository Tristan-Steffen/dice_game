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
const CHARM_THUMB_SIZE := 84  # Kantenlänge der 3D-Vorschau je Charm-Angebot (siehe _build_charm_thumb)

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
const FLIP_DURATION := 0.3  # Gesamtdauer des kosmetischen Blatt-Umschlagens (siehe _play_flip_animation)

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

@onready var left_page: PanelContainer = $VBoxContainer/Book/LeftHolder/LeftPage
@onready var left_content: VBoxContainer = $VBoxContainer/Book/LeftHolder/LeftPage/LeftContent
@onready var right_page: PanelContainer = $VBoxContainer/Book/RightHolder/RightPage
@onready var right_content: VBoxContainer = $VBoxContainer/Book/RightHolder/RightPage/RightContent
@onready var done_button: Button = $VBoxContainer/DoneButton

## Blätter-Ecken der aktuellen Doppelseite (je Seiten-Fußzeile neu gebaut,
## siehe _page_footer): links zurück, rechts vor (mit Gebühr bei neuer Seite).
var page_back_button: Button
var page_next_button: Button

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
	done_button.pressed.connect(_on_done_pressed)

## Nur das Menü selbst ist sichtbar: der Panel-Hintergrund bleibt leer (kein
## dunkler Kasten hinter dem Buch), gestylt werden allein die Papier-Seiten und
## der kleine Fertig-Knopf darunter.
func _style() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	CasinoStyle.style_button(done_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, 16)
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
			return  # die Blätter-Ecke ist bei zu wenig Geld ohnehin deaktiviert
		run.add_money(-fee)
		spreads.append(_build_spread())
	current_spread_index += 1
	_show_spread()
	_play_flip_animation(true)

## Zurückblättern ist immer gratis - die Seite steht ja schon im Buch.
func _on_page_back_pressed() -> void:
	if current_spread_index == 0:
		return
	current_spread_index -= 1
	_show_spread()
	_play_flip_animation(false)

var flip_sheets: Array[Node] = []  # temporäre Papier-Blätter der laufenden Flip-Animation
var flip_tween: Tween

## Rein kosmetisches Blatt-Umschlagen über der (bereits umgebauten) Doppelseite:
## ein papierfarbenes Blatt klappt von der Ausgangsseite zum Buchrücken zu
## (verdeckt dabei kurz die neue Seite und gibt sie beim Zuklappen frei), dann
## klappt es auf der Zielseite vom Rücken her auf und verblasst. Der Spielzustand
## ist zu diesem Zeitpunkt schon vollständig gewechselt, die Animation gate also
## nichts (wichtig für Tests und schnelles Klicken - ein neuer Flip räumt die
## vorige Animation einfach weg).
func _play_flip_animation(forward: bool) -> void:
	_clear_flip_sheets()
	var from_page := right_page if forward else left_page
	var to_page := left_page if forward else right_page

	# Falz liegt immer am Buchrücken: rechte Seite = linke Kante, linke = rechte.
	var sheet_from := _make_flip_sheet(from_page, forward)
	var sheet_to := _make_flip_sheet(to_page, not forward)
	sheet_to.scale.x = 0.0

	var half := FLIP_DURATION * 0.5
	flip_tween = create_tween()
	flip_tween.tween_property(sheet_from, "scale:x", 0.0, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip_tween.tween_property(sheet_to, "scale:x", 1.0, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flip_tween.tween_property(sheet_to, "modulate:a", 0.0, 0.12)
	flip_tween.tween_callback(_clear_flip_sheets)

## Ein papierfarbenes "Blatt" exakt über einer Menü-Seite, mit Falz-Pivot am
## Buchrücken (spine_left = Falz an der linken Blattkante). Als Kind des Panels
## über allen Seiteninhalten gezeichnet.
func _make_flip_sheet(page: PanelContainer, spine_left: bool) -> Panel:
	var sheet := Panel.new()
	sheet.add_theme_stylebox_override("panel", _paper_box())
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)
	sheet.global_position = page.global_position
	sheet.size = page.size
	sheet.pivot_offset = Vector2(0.0 if spine_left else sheet.size.x, sheet.size.y * 0.5)
	flip_sheets.append(sheet)
	return sheet

func _clear_flip_sheets() -> void:
	if flip_tween != null and flip_tween.is_valid():
		flip_tween.kill()
	for sheet in flip_sheets:
		if is_instance_valid(sheet):
			sheet.queue_free()
	flip_sheets.clear()

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
	page_back_button = null
	page_next_button = null

## Linke Menü-Seite: Überschrift + die Würfel-Angebote der Doppelseite.
func _rebuild_left_page(spread: MenuSpread) -> void:
	for child in left_content.get_children():
		child.queue_free()
	offer_buy_buttons.clear()

	left_content.add_child(_menu_heading("Würfel"))
	for i in spread.dice_offers.size():
		left_content.add_child(_build_offer_card(spread.dice_offers[i], i))

	page_back_button = _corner_button("‹")
	page_back_button.pressed.connect(_on_page_back_pressed)
	left_content.add_child(_page_footer(current_spread_index * 2 + 1, page_back_button, true))

## Rechte Menü-Seite: Charms (je einmal kaufbar) + das feste Bogen-Sortiment.
func _rebuild_right_page(spread: MenuSpread) -> void:
	for child in right_content.get_children():
		child.queue_free()
	charm_buttons.clear()
	sheet_buttons.clear()

	right_content.add_child(_menu_heading("Charms (je $%d)" % CHARM_PRICE))
	for i in spread.charm_options.size():
		var charm := spread.charm_options[i]
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 8)
		entry.add_child(_build_charm_thumb(charm, CHARM_THUMB_SIZE))

		var button := Button.new()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, CHARM_THUMB_SIZE)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.tooltip_text = charm.description
		if spread.charm_bought[i] or run.charm_ids().has(charm.id):
			button.text = "%s (gekauft)\n%s" % [charm.display_name, charm.description]
			button.disabled = true
		else:
			button.text = "%s\n%s\n$%d" % [charm.display_name, charm.description, CHARM_PRICE]
			button.pressed.connect(_on_charm_clicked.bind(i))
		CasinoStyle.style_button(button, CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, 13)
		entry.add_child(button)
		right_content.add_child(entry)
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

	page_next_button = _corner_button("›")
	page_next_button.pressed.connect(_on_page_next_pressed)
	right_content.add_child(_page_footer(current_spread_index * 2 + 2, page_next_button, false))

## Überschrift in dunkler "Druckfarbe" auf dem Menü-Papier.
func _menu_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", INK)
	return label

## Seitenzahl-Fußzeile wie in einer echten Speisekarte: "– N –" mittig, dazu die
## Blätter-Ecke der Seite (nav_on_left = linke Blattecke, sonst rechte). Ein
## unsichtbarer Gegen-Platzhalter in Eckengröße hält die Seitenzahl exakt mittig;
## der davor gesetzte Streckplatz drückt die Zeile ans Seitenende.
func _page_footer(page_number: int, corner: Button, nav_on_left: bool) -> Control:
	var holder := VBoxContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(spacer)

	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "– %d –" % page_number
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", INK)

	var ghost := Control.new()  # Gegenstück zur Ecke, hält die Seitenzahl mittig
	ghost.custom_minimum_size = corner.custom_minimum_size
	if nav_on_left:
		row.add_child(corner)
		row.add_child(label)
		row.add_child(ghost)
	else:
		row.add_child(ghost)
		row.add_child(label)
		row.add_child(corner)
	holder.add_child(row)
	return holder

## Kleine Blätter-Ecke am unteren Seitenrand (wie ein Eselsohr zum Umblättern).
func _corner_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(96, 30)
	CasinoStyle.style_button(button, CasinoStyle.BLUE, CasinoStyle.BLUE_DARK, 13)
	return button

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

## Statische 3D-Vorschau eines Charm-Modells (eigener SubViewport mit eigener
## World3D, gleiche Beleuchtung wie die Würfel-Vorschauen in DiceRowView). Da
## die GLB-Modelle unterschiedlich groß sind, wird das Modell über seine
## Gesamt-AABB auf Einheitsgröße normiert und zentriert (siehe _merged_aabb).
func _build_charm_thumb(charm: Charm, size: int) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(size, size)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = Vector2i(size, size)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)

	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-50, 35, 0)
	key_light.light_energy = 1.1
	viewport.add_child(key_light)

	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.transform = Transform3D(Basis(), Vector3(0, 1.4, 6.0)).looking_at(Vector3.ZERO, Vector3.UP)
	viewport.add_child(camera)

	var path := charm.model_path
	if path == "" or not ResourceLoader.exists(path):
		path = CharmRowView.MODEL_FALLBACK
	var model := (load(path) as PackedScene).instantiate() as Node3D

	# Modell über seine AABB einheitlich einpassen: auf ~2.2 Einheiten skalieren
	# und um sein Zentrum drehbar aufhängen (Pivot), leicht angekippt wie die Würfel.
	var pivot := Node3D.new()
	viewport.add_child(pivot)
	pivot.rotation_degrees = Vector3(-15, 30, 0)
	var aabb := _merged_aabb(model)
	var max_dim: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var fit: float = 2.2 / maxf(max_dim, 0.001)
	model.scale = Vector3.ONE * fit
	model.position = -aabb.get_center() * fit
	pivot.add_child(model)
	return container

## Gesamt-AABB aller MeshInstance3D unter node (im Raum von node) - Grundlage
## fürs Einpassen unterschiedlich großer Charm-Modelle in die Vorschau.
func _merged_aabb(node: Node) -> AABB:
	var result := AABB()
	var found := false
	var stack: Array = [[node, Transform3D()]]
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var current: Node = pair[0]
		var xform: Transform3D = pair[1]
		if current is Node3D and current != node:
			xform = xform * (current as Node3D).transform
		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			var mesh_aabb: AABB = xform * (current as MeshInstance3D).mesh.get_aabb()
			result = mesh_aabb if not found else result.merge(mesh_aabb)
			found = true
		for child in current.get_children():
			stack.push_back([child, xform])
	return result

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
		return  # Button ist bei zu wenig Geld ohnehin deaktiviert
	run.purchase_dice(offer.dice, price)
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
	_refresh_afford_state()

## Kauft einen Coupon-Bogen (siehe run.buy_coupon_sheet / CouponSheet) - beliebig
## oft nachkaufbar. Die Enthüllung zeigt scene_root (hört auf run.sheet_purchased);
## hier steht nur die kurze Rückmeldung, wie viele echte Ätzungen darauf lagen.
func _on_sheet_pressed(index: int) -> void:
	var offer: Dictionary = SHEET_OFFERS[index]
	if run.money < offer["price"]:
		return  # Button ist bei zu wenig Geld ohnehin deaktiviert
	run.buy_coupon_sheet(offer["kind"], offer["price"])
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
	if page_back_button != null and is_instance_valid(page_back_button):
		page_back_button.disabled = current_spread_index == 0
	if page_next_button != null and is_instance_valid(page_next_button):
		if _next_flip_is_new():
			page_next_button.text = "$%d ›" % _next_flip_fee()
			page_next_button.disabled = money < _next_flip_fee()
		else:
			page_next_button.text = "›"
			page_next_button.disabled = false

## Das Geld hat sich geändert, während der Shop offen ist (siehe run-Setter):
## Kaufbarkeit neu bewerten. Wichtig, wenn das Geld NICHT durch einen Shop-Kauf
## steigt - z.B. die Chip-Coupons der Bogen-Abschluss-Animation (siehe
## scene_root: _grant_chip_coupon) sollen sofort wieder Käufe freischalten.
func _on_run_money_changed(_money: int) -> void:
	if visible:
		_refresh_afford_state()

func _on_done_pressed() -> void:
	_clear_flip_sheets()
	_clear_pages()  # 3D-Vorschauen freigeben (kein Hintergrund-Rendern nach dem Schließen)
	visible = false
	closed.emit()
