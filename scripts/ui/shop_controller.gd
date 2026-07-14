class_name ShopController
extends Control
## Der Shop zwischen den Runden - seit dem Hub-Umbau ein NEON-PANEL direkt AUF
## dem Tisch-Display: er füllt die Hub-Fläche unter der Grube (siehe HubView.
## attach_shop) und übernimmt deren Stil - dunkles Violett, Cyan-Überschriften,
## Magenta-Titel, Gold für Geld/Abschluss, Neon-Grün für die Coupon-Packs.
## Bedient wird er über die Maus-Weiterleitung in den Tisch-SubViewport (siehe
## scene_root._forward_screen_mouse), sobald die Kamera auf den Hub gezoomt ist.
##
## Links die Würfel-Angebote, rechts Charms und Coupon-Packs. "Umblättern" auf
## eine NOCH NICHT gesehene Seite würfelt frische Angebote aus und kostet eine
## steigende Gebühr (siehe FLIP_FEE_BASE - das ist der "Reroll"); Zurückblättern
## und erneutes Vorblättern auf bereits gesehene Seiten ist gratis, denn die
## Seiten bleiben stehen (siehe MenuSpread - inklusive gekaufter Charms).
##
## Die Spielzustands-Mutation (Geld, Charms, Pool) liegt beim GameRun (siehe
## scripts/core/game_run.gd), den der Besitzer (scene_root) über run hereinreicht;
## auf das closed-Signal reagiert scene_root (Rundenwechsel). Käufe wirken sofort
## und sind beliebig oft wiederholbar (Charms je einmal - danach besitzt man sie).
##
## Alle Maße leiten sich aus der eigenen Größe ab (Einheit u = Breite/100, wie
## HubView) - der Shop skaliert also mit der Hub-Fläche; freistehend (Tests)
## greift die Standardgröße aus shop_panel.tscn.

## Wird ausgelöst, wenn der Spieler den Shop mit "Fertig" verlässt.
signal closed

const CHARM_PRICE := 15  # Preis pro Charm-Kauf
const DICE_OFFER_COUNT := 3  # Würfel-Angebote je Doppelseite (siehe DiceOffer)

## Gebühr fürs Aufschlagen einer NEUEN Doppelseite: erst $2, dann $3, $4 ...
## (fee = FLIP_FEE_BASE + bereits existierende Seiten - 1). Je Besuch zurückgesetzt.
const FLIP_FEE_BASE := 2

## Die vier Coupon-Pack-Sorten (siehe CouponSheet.generate: allowed_kinds).
## Jedes Pack gibt es in den fünf Bogengrößen (siehe PACK_SIZES); je größer das
## Raster, desto teurer und desto größere Coupons können darauf liegen (die
## Fläche IST die Rarität). Das gemischte Heft ist bewusst etwas GÜNSTIGER als
## die sortenreinen Packs - wer gezielt zieht, zahlt für die Auswahl. Cover-
## Motive nach Dateinamens-Konvention: PACK_COVER_DIR + id + ".jpg".
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

## Die fünf Bogengrößen jedes Packs (Index = Preis-Index in PACKS.prices).
const PACK_SIZES := [
	{"kind": CouponSheet.Kind.SNIPPET, "label": "2×2"},
	{"kind": CouponSheet.Kind.SHEET, "label": "3×3"},
	{"kind": CouponSheet.Kind.LARGE, "label": "5×5"},
	{"kind": CouponSheet.Kind.POSTER, "label": "7×7"},
	{"kind": CouponSheet.Kind.JUMBO, "label": "9×9"},
]

const PACK_COVER_DIR := "res://assets/textures/packs/"

## Das Pack-Sortiment einer Doppelseite: PACK_OFFER_COUNT zufällig gezogene,
## verschiedene Kombinationen aus Pack-Sorte × Bogengröße (von 4 × 5 = 20
## möglichen), als Raster gezeigt. Jedes Angebot ist nur EINMAL kaufbar
## (danach greift man zum Umblättern für frische Packs).
const PACK_GRID_COLUMNS := 3
const PACK_OFFER_COUNT := 6

## Farben im Display-Stil (siehe HubView/TableScreen: 80s Neon).
const NEON_CYAN := Color("#8be9fd")     # Überschriften der Rubriken, Würfel-Akzent
const NEON_MAGENTA := Color("#ff79c6")  # Titel, Charm-Akzent
const NEON_GOLD := Color("#ffd319")     # Geld, Preise, Fertig-Knopf
const NEON_GREEN := Color("#50fa7b")    # Coupon-Packs
const NEON_TEXT := Color(1.35, 1.35, 1.3)   # überhelles Weiß (leichter Glow)
const NEON_MUTED := Color(0.75, 0.78, 0.9)  # gedämpfte Hinweistexte
const CARD_BG := Color("#241f4a99")     # Karten-Hintergrund auf dem dunklen Violett

const FLIP_DURATION := 0.25  # Einblendzeit der neuen Seite (siehe _play_flip_animation)

## Eine aufgeschlagene Doppelseite des Sortiments: ihre Würfel-Angebote, ihr
## Charm-Angebot und welche Angebote darauf schon gekauft wurden. Bleibt für den
## ganzen Besuch bestehen - Zurückblättern zeigt exakt diese Seite wieder.
class MenuSpread:
	extends RefCounted

	var dice_offers: Array[DiceOffer] = []
	var charm_options: Array[Charm] = []
	var charm_bought: Array[bool] = []
	## Die Pack-Angebote der Seite (x = PACKS-Index, y = PACK_SIZES-Index).
	var pack_offers: Array[Vector2i] = []
	## Je Angebot, ob es auf dieser Seite schon gekauft wurde (nur einmal kaufbar).
	var pack_bought: Array[bool] = []

## Die Bogen-Miniatur einer Pack-Karte: das Cover-Motiv liegt als "Papier" in
## Bogengröße auf der Karte, überzogen mit dem ECHTEN Raster des Packs als
## Perforationslinien. Die Bogengröße ist so auf einen Blick sichtbar - ein
## großes Pack hat sichtbar größeres Papier UND ein feineres Raster als ein
## Schnipsel. Der Bogen bleibt bewusst cremefarbenes Papier (das PRODUKT im
## Regal), nur die Karte drumherum trägt den Neon-Stil. ui_scale skaliert die
## Miniatur mit der Shop-Größe (siehe _build_pack_card).
class PackSheetThumb:
	extends Control

	const PAPER := Color("efe4c8")                   # Bogenpapier hinter dem Motiv
	const PERF := Color(0.42, 0.29, 0.18, 0.7)       # Perforations-Braun (siehe CouponSheetView)
	const SIDE_BASE := 34.0                          # Kantenlänge: SIDE_BASE + dims × SIDE_PER_CELL
	const SIDE_PER_CELL := 4.0                       # 2×2 -> 42px ... 9×9 -> 70px

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
			# Motiv seitengetreu ins Papier einpassen (Cover sind nicht zwingend quadratisch).
			var inner := rect.grow(-2.0)
			var tex_size := texture.get_size()
			var fit := minf(inner.size.x / tex_size.x, inner.size.y / tex_size.y)
			var draw_size := tex_size * fit
			draw_texture_rect(texture, Rect2(inner.position + (inner.size - draw_size) * 0.5, draw_size), false)
		# Das echte Raster des Bogens als Perforationslinien über dem Motiv.
		var cell := rect.size.x / float(dims)
		for i in range(1, dims):
			draw_line(Vector2(rect.position.x + i * cell, rect.position.y),
				Vector2(rect.position.x + i * cell, rect.end.y), PERF, 1.0)
			draw_line(Vector2(rect.position.x, rect.position.y + i * cell),
				Vector2(rect.end.x, rect.position.y + i * cell), PERF, 1.0)
		draw_rect(rect, PERF, false, 1.0)

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

## Breiteneinheit (size.x / 100) - alle Maße/Schriften relativ zur Shop-Breite,
## in _build_layout gesetzt (Mindestwert für freistehende Instanzen ohne Größe).
var u := 8.0

## Gerüst-Referenzen (je open() in _build_layout frisch gebaut).
var money_label: Label
var content_root: VBoxContainer  # Seiteninhalt (für die Umblätter-Einblendung)
var left_column: VBoxContainer   # Würfel-Angebote
var right_column: VBoxContainer  # Charms + Coupon-Packs
var page_label: Label
var done_button: Button
## Blätter-Knöpfe im festen Fußbereich: links zurück, rechts vor (mit Gebühr bei
## neuer Seite) - Zustand siehe _refresh_afford_state.
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
## Kaufknöpfe der Pack-Karten (Reihenfolge = pack_offers der aktuellen Seite) -
## parallel dazu die Preise für die Kaufbarkeits-Prüfung.
var pack_offers: Array[Vector2i] = []
var pack_bought: Array[bool] = []
var sheet_buttons: Array[Button] = []
var sheet_button_prices: Array[int] = []

var flip_tween: Tween

## Öffnet den Shop: das Sortiment beginnt frisch auf der ersten Doppelseite
## (alle Seiten des vorigen Besuchs sind Geschichte, die Blätter-Gebühr startet
## neu). Baut das Gerüst passend zur AKTUELLEN Größe neu auf (im Hub = die
## Hub-Fläche). Sichtbarkeit/Spielzustand steuert der Aufrufer
## (scene_root._on_round_complete).
func open() -> void:
	_build_layout()
	spreads = [_build_spread()]
	current_spread_index = 0
	_show_spread()
	visible = true

# --- Gerüst (Neon-Panel) --------------------------------------------------------

## Baut das feste Gerüst des Panels: Kopfzeile (Titel + Geld), zwei Rubriken-
## Spalten und der feste Fußbereich (Blättern + Fertig). Der Neon-Rahmen kommt
## vom Hub darunter (siehe HubView) - der Shop füllt nur dessen Fläche.
func _build_layout() -> void:
	for child in get_children():
		child.queue_free()
	u = maxf(size.x, 640.0) / 100.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sicherheitsnetz: Inhalt darf nie über den Hub-Rahmen hinausragen (die
	# Maus-Weiterleitung endet an der Hub-Fläche, siehe _forward_screen_mouse).
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

	# Kopfzeile: Titel links (Magenta), Geldstand rechts (Gold).
	var header := HBoxContainer.new()
	header.name = "Header"
	root.add_child(header)
	var title := _label("SHOP", u * 4.5, NEON_MAGENTA)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	money_label = _label("$0", u * 4.0, NEON_GOLD)
	header.add_child(money_label)

	# Seiteninhalt: zwei Rubriken-Spalten (links Würfel, rechts Charms + Packs).
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

	# Fester Fußbereich: ‹ Seite N › links, Fertig rechts.
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

## Gebühr fürs Aufschlagen der nächsten NEUEN Doppelseite (steigt je Besuch);
## Wechselgeld-Charm senkt sie (min. $1, siehe CharmEffects.flip_fee).
func _next_flip_fee() -> int:
	return CharmEffects.flip_fee(FLIP_FEE_BASE + spreads.size() - 1, run.charm_ids())

## True, wenn Vorblättern eine neue Doppelseite auswürfeln würde (statt eine
## bereits aufgeschlagene wieder zu zeigen).
func _next_flip_is_new() -> bool:
	return current_spread_index == spreads.size() - 1

## Vorblättern: auf eine bereits gesehene Seite gratis; ans Ende blättern
## würfelt eine neue Doppelseite aus und kostet die steigende Gebühr.
func _on_page_next_pressed() -> void:
	if _next_flip_is_new():
		var fee := _next_flip_fee()
		if run.money < fee:
			return  # der Knopf ist bei zu wenig Geld ohnehin deaktiviert
		run.add_money(-fee)
		spreads.append(_build_spread())
	current_spread_index += 1
	_show_spread()
	_play_flip_animation()

## Zurückblättern ist immer gratis - die Seite steht ja schon im Sortiment.
func _on_page_back_pressed() -> void:
	if current_spread_index == 0:
		return
	current_spread_index -= 1
	_show_spread()
	_play_flip_animation()

## Rein kosmetischer Seitenwechsel im Display-Stil: der (bereits umgebaute)
## Seiteninhalt blendet kurz aus dem Dunkel ein - wie ein Bildschirm, der neu
## zeichnet. Der Spielzustand ist zu diesem Zeitpunkt schon vollständig
## gewechselt, die Animation gate also nichts (wichtig für Tests und schnelles
## Klicken - ein neuer Wechsel ersetzt die vorige Einblendung einfach).
func _play_flip_animation() -> void:
	if flip_tween != null and flip_tween.is_valid():
		flip_tween.kill()
	content_root.modulate = Color(1, 1, 1, 0)
	flip_tween = create_tween()
	flip_tween.tween_property(content_root, "modulate:a", 1.0, FLIP_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# --- Doppelseiten bauen ---------------------------------------------------------

## Würfelt eine frische Doppelseite aus: DICE_OFFER_COUNT Würfel-Angebote (siehe
## DiceOffer) und bis zu zwei noch nicht besessene Charms.
func _build_spread() -> MenuSpread:
	var spread := MenuSpread.new()
	spread.dice_offers = DiceOffer.roll_offers(DICE_OFFER_COUNT, run.charm_ids())  # Gütesiegel erzwingt Veredelungen

	# Besitz-Prüfung über die ROHEN ids (Totems lösen sich in charm_ids() zu
	# ihren Nachbarn auf und würden sonst doppelt angeboten).
	var owned_ids: Array[String] = run.owned_charm_ids()
	var available: Array[Charm] = []
	for charm in Charm.all():
		if not owned_ids.has(charm.id):
			available.append(charm)
	# Gewichtet nach Rarität ziehen (ohne Zurücklegen): Gewöhnliche erscheinen
	# am häufigsten, Legendäre selten - siehe Charm.RARITY_WEIGHTS.
	for i in 2:
		if available.is_empty():
			break
		var pick := Charm.pick_weighted(available)
		spread.charm_options.append(pick)
		available.erase(pick)
	spread.charm_bought.resize(spread.charm_options.size())
	spread.charm_bought.fill(false)

	# Pack-Sortiment: PACK_OFFER_COUNT verschiedene aus allen Sorte-×-Größe-Kombinationen.
	var combos: Array[Vector2i] = []
	for p in PACKS.size():
		for s in PACK_SIZES.size():
			combos.append(Vector2i(p, s))
	combos.shuffle()
	spread.pack_offers = combos.slice(0, PACK_OFFER_COUNT)
	spread.pack_bought.resize(spread.pack_offers.size())
	spread.pack_bought.fill(false)
	return spread

## Zeigt die aktuelle Doppelseite: Spiegel-Variablen umhängen, beide Rubriken-
## Spalten neu bebauen, Navigation und Kaufbarkeit aktualisieren.
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

## Gibt die Inhalte beider Spalten frei - auch beim Schließen wichtig, damit die
## 3D-Vorschau-Viewports der Würfelzeilen nicht im Hintergrund weiterrendern.
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

## Linke Rubrik: Überschrift + die Würfel-Angebote der Doppelseite.
func _rebuild_left_column(spread: MenuSpread) -> void:
	for child in left_column.get_children():
		child.queue_free()
	offer_buy_buttons.clear()

	left_column.add_child(_section_heading("WÜRFEL"))
	for i in spread.dice_offers.size():
		left_column.add_child(_build_offer_card(spread.dice_offers[i], i))

## Rechte Rubrik: Charms (je einmal kaufbar) + das Bogen-Sortiment.
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

## Eine Pack-Karte des Sortiments: die Bogen-Miniatur (Cover-Motiv in
## Bogengröße mit echtem Raster, siehe PackSheetThumb), darunter der Pack-Name
## (klein) und der Kaufknopf mit Größe · Preis. Nach dem Kauf ist die Karte
## "vergriffen" und deaktiviert (nur einmal kaufbar, siehe pack_bought). Der
## Tooltip (auf der ganzen Karte) erklärt, welche Coupon-Arten drin sind.
func _build_pack_card(pack_index: int, size_index: int, offer_index: int) -> Control:
	var pack: Dictionary = PACKS[pack_index]
	var price := _pack_price(pack_index, size_index)  # inkl. Feinschmecker/Schnäppchenjäger
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
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Miniaturen einer Zeile stehen unten bündig
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

## Eine Angebotskarte der Würfel-Rubrik: dunkle Neon-Karte mit der Würfel-Zeile
## im Sammlungs-Look (mit "N ×"-Stück-Multiplikator, alle Würfel eines Bündels
## sind gleich - siehe DiceOffer) und dem Kauf-Button darunter.
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

	# Veredelte Angebote (Material-Seiten/Kanten, siehe DiceOffer._roll_refinements)
	# benennen ihre Veredelungen - die Mini-Vorschau allein ist dafür zu klein,
	# und der Aufpreis soll lesbar begründet sein.
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

## Kurzbeschreibung der Veredelungen eines Angebots-Würfels ("" = keine):
## Material-Seiten (mit Anzahl bei mehreren gleichen) und Kanten-Material,
## z.B. "2× Bernstein-Seite · Gold-Kanten".
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

# --- Neon-Bausteine ---------------------------------------------------------------

## Rubriken-Überschrift in Cyan (Display-Stil, siehe HubView).
func _section_heading(text: String) -> Label:
	return _label(text, u * 2.8, NEON_CYAN)

func _label(text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Ein Knopf im Neon-Stil des Displays: dunkler Grund, Rahmen in der Akzentfarbe
## der Rubrik (Cyan Würfel, Magenta Charms, Grün Packs, Gold Abschluss); Hover
## und Druck wechseln auf Gold, deaktiviert dimmt alles ab.
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

## Effektiver Angebotspreis nach Rabatt-Charms (Trickdieb-Manschette,
## Mengenrabatt für 3er-Bündel).
func _offer_price(offer: DiceOffer) -> int:
	return CharmEffects.die_price(offer.price, run.charm_ids(), offer.size())

## Effektiver Charm-Preis nach Skonto (siehe CharmEffects.charm_price).
func _charm_price() -> int:
	return CharmEffects.charm_price(CHARM_PRICE, run.charm_ids())

## Effektiver Pack-Preis nach Feinschmecker/Schnäppchenjäger (siehe
## CharmEffects.pack_price).
func _pack_price(pack_index: int, size_index: int) -> int:
	var pack: Dictionary = PACKS[pack_index]
	return CharmEffects.pack_price(pack["prices"][size_index], pack["id"], run.charm_ids())

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
## Danach wird die ganze Doppelseite neu bebaut (statt nur den Knopf zu
## deaktivieren): Shop-Charms (Skonto, Wechselgeld, Feinschmecker,
## Schnäppchenjäger, Mengenrabatt, Trickdieb-Manschette ...) wirken schon in
## DIESEM Besuch - alle Preisschilder, die Kaufbarkeits-Schwellen der Packs
## (sheet_button_prices) und die Blätter-Gebühr zeigen sonst alte Preise.
func _on_charm_clicked(index: int) -> void:
	var charm := charm_options[index]
	if charm_bought[index] or run.owned_charm_ids().has(charm.id):
		return
	run.purchase_charm(charm, _charm_price())  # Skonto-Rabatt inklusive
	charm_bought[index] = true  # liegt im Spread - übersteht den Neuaufbau
	_show_spread()

## Kauft ein Coupon-Pack in der gewählten Größe (siehe run.buy_coupon_sheet /
## CouponSheet) - jedes Angebot nur EINMAL (danach vergriffen; frische Packs gibt
## es beim Umblättern). Sortenreine Packs geben ihre erlaubten Coupon-Arten an
## die Bogen-Auswürfelung weiter (siehe PACKS: kinds); die Enthüllung zeigt
## scene_root (hört auf run.sheet_purchased).
func _on_sheet_pressed(offer_index: int) -> void:
	if pack_bought[offer_index]:
		return
	var offer := pack_offers[offer_index]
	var pack: Dictionary = PACKS[offer.x]
	var price := _pack_price(offer.x, offer.y)
	if run.money < price:
		return  # Button ist bei zu wenig Geld ohnehin deaktiviert
	var allowed: Array[String] = []
	allowed.assign(pack["kinds"])
	run.buy_coupon_sheet(PACK_SIZES[offer.y]["kind"], price, allowed)
	# Kleingedrucktes: Chance auf volle Rückerstattung des Kaufpreises.
	if randf() < CharmEffects.pack_refund_chance(run.charm_ids()):
		run.add_money(price)
	pack_bought[offer_index] = true
	sheet_buttons[offer_index].disabled = true
	sheet_buttons[offer_index].text = "vergriffen"
	_refresh_afford_state()

## Deaktiviert alles, was sich der Spieler gerade nicht leisten kann - je Angebot
## seinen (rabattierten) Preis, unverkaufte Charms, Bögen und das Umblättern auf
## eine neue Doppelseite (dessen Knopf auch die fällige Gebühr anzeigt). Hält
## außerdem den Geldstand der Kopfzeile aktuell.
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
