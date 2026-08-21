class_name SecretShopView
extends Panel
## Der Schwarzmarkt: eigenes Tisch-Fenster UNTER den Fumble-Automaten. Es steht
## von Anfang an da, aber VERGITTERT - erst die Lizenzstufe hebt das Gitter
## (set_locked); solange bleibt die Bucht zu, denn die Auslage wird erst beim
## Freischalten gewürfelt.
## Danach: bezahlt wird ausschließlich in Ladung (⚡) - drei Plätze, jeder EINMAL
## kaufbar, "Neu mischen" tauscht alle drei zum immer gleichen Preis.
## Aufgeteilt ist das Fenster wie der Laden: Kopfstreifen und der feste
## KARTEN-SITZ (genau EINE Charm-Karte - Lizenzen sind digitale Ware) bleiben
## Bildschirm, die WARE liegt körperlich in der Bucht daneben. Die zeichnet dieses
## Fenster nie selbst; es meldet nur ihr Rechteck und ihren Inhalt, aufgestellt
## wird sie von scene_root. Das löst nebenbei das Auflösungs-Problem der kleinen
## Tasche: ein echter Würfel unter Glas rendert in Bildschirmauflösung.
## Zustands-Mutation läuft ausschließlich über GameRun (buy_secret_offer/
## reroll_secret_stock); die Anzeige folgt secret_stock_changed und
## charge_changed. Geschlossen wird wie bei jedem Fenster per Rechtsklick.

## Ladung ist für den Laden geflossen (Kauf oder Neuwurf) - scene_root schickt sie
## als Kometen über die Hinterzimmer-Ader. Erst gebucht, dann gemeldet.
signal charge_spent(amount: int)
## Versiegelte Ware ist gekauft (Bündel oder Katalysator): sie liegt schon als
## Paket im Magazin, scene_root fährt sie nur noch dorthin.
signal goods_purchased(uid: int)
## Ein Seelenwürfel ist gekauft: er liegt schon im Ausgabefach, scene_root fährt
## ihn nur noch dorthin. Kein Paket - ein Würfel wird nie versiegelt.
signal die_purchased(def: DieDefinition)
## Die Auslage der Bucht hat sich geändert (Wurf, Kauf, Freischaltung).
signal vitrine_changed
## Ein Schlüsselwort auf der Beschriftung wurde geklickt - scene_root schlägt das
## Lexikon auf.
signal lexikon_requested(entry_id: String)

## Hinterzimmer-Palette: dunkler als der Laden, Akzent ist das Violett der
## legendären Rarität.
const VIOLET := Color(0.75, 0.35, 1.0)
const CHARGE_COLOR := CasinoStyle.CHARGE
const NEON_TEXT := Color(1.35, 1.35, 1.3)
const NEON_MUTED := Color(0.72, 0.74, 0.86)
const BACKROOM_BG := Color("#0b0918e6")
const CARD_BG := Color("#150f2acc")

## Breite des Karten-Sitzes in Einheiten. Er steht FEST - ob eine Karte darin
## liegt oder der legendäre Topf erschöpft ist, ändert die Aufteilung nie.
const CARD_SEAT_WIDTH := 28.0

## Bauhöhe des Inhalts in Einheiten - die Tasche unter den Automaten ist flach,
## also darf die Einheit auch an der HÖHE hängen (wie Gravur-Station/Vertragswahl).
## Der Wert ist knapp UNTER dem Seitenverhältnis der echten Tasche (~1,8) gewählt,
## damit die BREITE bindet: das ist die größte Einheit, die das Fenster tragen
## kann, und die Einheit ist hier gleichbedeutend mit Schriftgröße in Textur-
## Pixeln (das Fenster hat nur ~450×250 davon). Größer geht nicht, kleiner heißt
## Matsch, sobald die Kamera heranfährt (siehe CameraRig.SECRET_SHOP_ZOOM_DISTANCE_CUT).
const CONTENT_UNITS := 54.0

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
		_seen_rolls = -1  # frischer Lauf: die erste Auslage rollt wieder an
		refresh()

## Einheit aus BEIDEN Achsen (in refresh gesetzt).
var u := 4.0

## Vergittert: Schatten-Plätze unter einem dunklen Schleier mit der Bedingung.
var locked := true

var wallet_label: Label
## Der feste Sitz der EINEN Karte (Bildschirm) und daneben das Feld der Bucht.
var card_seat: Control
var vitrine_slot: Control
## Die EINE Beschriftungskarte der Auslage - ein Stück, eine Karte.
var annotation_card: VitrineAnnotationView
var reroll_button: Button
## Index-treu zur Auslage: je Platz ein Knopf oder null - was körperlich in der
## Bucht liegt, hat auf dem Bildschirm keinen (die Lücken halten die Indizes).
var offer_buttons: Array[Button] = []
var lock_overlay: Panel
## Auf dem Schleier steht, was das Gitter hebt - kein Knopf, nichts zu kaufen.
var lock_notice: Label

## Hover-Dropdown (Name + Wirkung), wie im Shop.
var detail_card: PanelContainer
var detail_title: Label
var detail_body: Label

var _built := false
## Zuletzt gesehener Wurf-Stand (-1 = vergittert/noch keiner). Ein WURF rollt die
## Ware an, ein Kauf lässt sie liegen - mehr entscheidet den Grad nicht.
var _seen_rolls := -1
var _vitrine_grade := ShopController.GRADE_STAND
## Was körperlich in der Bucht liegt, je Auslage-Platz (null = kein solches Stück).
var _bay_packs: Array = []
var _bay_dice: Array = []

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

## Gitter-Zustand von scene_root (einziger Schreiber): locked = die Lizenzstufe
## reicht noch nicht.
func set_locked(is_locked: bool) -> void:
	var was_locked := locked
	locked = is_locked
	if not _built:
		return
	if was_locked != locked:
		_refresh_offers()  # Schatten <-> echte Ware ist ein Neuaufbau
	_apply_lock_state()

## Schleier, Knopf und Dimmung des Sitzes am Gitter-Zustand ausrichten.
func _apply_lock_state() -> void:
	if not _built:
		return
	lock_overlay.visible = locked
	reroll_button.visible = not locked
	card_seat.modulate = Color(1, 1, 1, 0.35) if locked else Color.WHITE

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

	# Kopfstreifen: Titel, Börse und der Neuwurf. Der alte Fuß ist weg - seine
	# Höhe gehört jetzt der Bucht, und der Misch-Knopf steht ohnehin zum Titel.
	var header := HBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", int(u * 1.2))
	root.add_child(header)
	header.add_child(_label("SCHWARZMARKT", u * 4.2, Color(1.35, 0.7, 1.7)))
	var rail := _rail(VIOLET)
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(rail)
	wallet_label = _label("⚡ 0/0", u * 4.2, CHARGE_COLOR)
	wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(wallet_label)
	reroll_button = _neon_button("Neu mischen", VIOLET, u * 2.6, Vector2(u * 24.0, u * 6.2))
	reroll_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reroll_button.pressed.connect(_on_reroll_pressed)
	header.add_child(reroll_button)

	# Darunter die zwei Zonen: links der Karten-Sitz (Bildschirm), rechts die Bucht.
	var body := HBoxContainer.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", int(u * 1.8))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	card_seat = Control.new()
	card_seat.name = "CardSeat"
	card_seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_seat.custom_minimum_size = Vector2(u * CARD_SEAT_WIDTH, 0.0)
	body.add_child(card_seat)

	# Die Bucht bekommt den ganzen Rest. Gemalt wird allein die FASSUNG - die Mitte
	# ist frei, denn dort steht die Ware auf der Fläche.
	vitrine_slot = Control.new()
	vitrine_slot.name = "Vitrine"
	vitrine_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitrine_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vitrine_slot.add_child(_vitrine_frame())
	body.add_child(vitrine_slot)

	_build_detail_card()  # zuletzt: liegt als Overlay über der Karte
	# Die Beschriftung der Auslage steht IM Fenster über dem Buchten-Band: alles,
	# was das Spiel sagt, sagt es auf einer Anzeige.
	annotation_card = VitrineAnnotationView.new()
	annotation_card.lexikon_requested.connect(func(entry_id: String) -> void:
		lexikon_requested.emit(entry_id))
	add_child(annotation_card)
	annotation_card.build(vitrine_unit())
	_build_lock_overlay()  # und ganz oben das Gitter

# --- Die Bucht (gemeldete Geometrie, nie gezeichneter Inhalt) ------------------

## Das Buchten-Rechteck in globalen Display-Pixeln (leeres Rect = noch keins).
func vitrine_rect_px() -> Rect2:
	if vitrine_slot == null or not is_instance_valid(vitrine_slot):
		return Rect2()
	return vitrine_slot.get_global_rect()

## Das FELD darin: der Streifen ohne seine gemalte Fassung - dieselbe Rechnung wie
## am Magazin und in der Laden-Bucht.
func vitrine_pit_rect() -> Rect2:
	var strip := vitrine_rect_px()
	if strip.size.x <= 0.0 or strip.size.y <= 0.0:
		return Rect2()
	return PackDrawerView.pit_rect_in(strip, u)

## Maßeinheit der Beschriftungs-Karte. Bewusst DIE DES FENSTERS: die
## Tasche ist die kleinste des Tisches, und eine an der Buchtbreite hängende
## Einheit schriebe dort kleiner als das Fenster selbst.
func vitrine_unit() -> float:
	return u

## Die FASSUNG der Bucht - Rahmen ohne Füllung, Rezeptur aus der Magazin-Fassung.
func _vitrine_frame() -> Panel:
	var well := Panel.new()
	well.name = "VitrineWell"
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var radius := int(u * PackDrawerView.RADIUS)
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = PackDrawerView.RIM_BASE
	box.set_border_width_all(maxi(2, int(u * PackDrawerView.RIM_WIDTH)))
	box.set_corner_radius_all(radius)
	well.add_theme_stylebox_override("panel", box)
	var edge := maxi(2, int(u * PackDrawerView.EDGE))
	well.add_child(PackDrawerView.edge_band("VitrineShade",
		PackDrawerView.WELL_SHADOW, edge, radius, true))
	well.add_child(PackDrawerView.edge_band("VitrineSheen",
		PackDrawerView.WELL_SHEEN, edge, radius, false))
	return well

## Die Beschriftung EINES Stücks zeigen. anchor ist ein GLOBALER Display-Pixel -
## die Karte rechnet ihn selbst in ihren Fenster-Platz um.
func show_bay_annotation(data: Dictionary, anchor: Vector2) -> void:
	if annotation_card == null or not is_instance_valid(annotation_card):
		return
	annotation_card.show_item(data, vitrine_unit())
	annotation_card.place_over(anchor - get_global_rect().position, size)

func hide_bay_annotation() -> void:
	if annotation_card != null and is_instance_valid(annotation_card):
		annotation_card.hide_card()

## Ob der globale Display-Pixel auf der stehenden Karte liegt. Der Zeiger muss vom
## Stück auf seine Beschriftung wandern dürfen - die Schlüsselwörter sind
## Klickziele -, sonst verschwände sie unter ihm.
func bay_annotation_has_point(px: Vector2) -> bool:
	if annotation_card == null or not is_instance_valid(annotation_card) \
			or not annotation_card.visible:
		return false
	return annotation_card.get_global_rect().has_point(px)

## Der Ankunfts-Grad der zuletzt gezeigten Auslage; scene_root fährt ihn EINMAL.
func vitrine_grade() -> String:
	return _vitrine_grade

## Der Platz mit der EINEN Karte (-1 = keiner - der legendäre Topf ist erschöpft
## und eine Sonder-Gravur ist nachgerückt; dann steht deren Kassette in der Bucht
## und der Sitz bleibt leer).
func card_slot_index() -> int:
	if run == null:
		return -1
	for i in run.secret_stock.size():
		if run.secret_stock[i][GameRun.OFFER_KIND] == GameRun.KIND_CHARM:
			return i
	return -1

## Was körperlich in der Bucht liegt: je Auslage-Platz ein Eintrag, null für
## Verkauftes und für den Karten-Sitz. Die Lücken halten die Indizes treu - ein
## Griff meint immer denselben Kaufweg (buy_offer).
func vitrine_stock() -> Dictionary:
	return {
		ShopController.KIND_ENGRAVING_PACK: _bay_packs.duplicate(),
		ShopController.KIND_DIE: _bay_dice.duplicate(),
		ShopController.KIND_SPECIAL: [],
	}

## Die Beschriftung EINES Stücks für die Fenster-Karte. Der Preis steht NUR hier - in
## der Bucht hängt kein Schild -, und er ist in ⚡ ausgewiesen.
func vitrine_annotation(_kind: String, index: int) -> Dictionary:
	if run == null or index < 0 or index >= run.secret_stock.size():
		return {}
	var offer := run.secret_stock[index]
	if bool(offer[GameRun.OFFER_SOLD]):
		return {}
	var data := {
		"price": run.secret_offer_price(offer),
		"money": run.charge,
		"charge": true,
		"blocked": ShopController.FULL_TAG if _offer_blocked(offer) else "",
	}
	match String(offer[GameRun.OFFER_KIND]):
		GameRun.KIND_DIE:
			var die: DieDefinition = offer[GameRun.OFFER_ITEM]
			var essence := Essence.by_id(die.essence_id)
			data["title"] = "%s-Würfel" % essence.display_name
			data["body"] = "%s\n%s" % [essence.short, essence.description]
			data["net"] = die
		GameRun.KIND_CATALYST:
			var card_pack: Pack = offer[GameRun.OFFER_ITEM]
			data["title"] = card_pack.display_name
			data["body"] = card_pack.description
		_:
			var engraving: Engraving = offer[GameRun.OFFER_ITEM]
			# Die Bündelgröße steht auf der Kappe der Kassette - hier nennt sie die
			# Beschriftung noch einmal, damit Zahl und Wirkung beieinander stehen.
			var bundle := int(offer.get(GameRun.OFFER_COUNT, 1))
			data["title"] = engraving.display_name
			data["body"] = engraving.description if bundle == 1 \
				else "%s\nEine Datenkarte mit %d Stücken darin." % [engraving.description, bundle]
	return data

## Der Griff in der Bucht kauft: derselbe Weg wie die Karte am Sitz.
func buy_offer(index: int) -> void:
	_on_offer_pressed(index)

# --- Auslage ------------------------------------------------------------------

## Baut den Karten-Sitz neu, sortiert die Ware in die Bucht und zieht Börse und
## Misch-Preis nach. Rebuild statt Patch: ein verkaufter Platz wechselt seine
## ganze Gestalt.
func _refresh_offers() -> void:
	if not _built or run == null:
		return
	wallet_label.text = "⚡ %d/%d" % [run.charge, run.charge_cap()]
	for child in card_seat.get_children():
		card_seat.remove_child(child)
		child.queue_free()
	offer_buttons.clear()
	_bay_packs.clear()
	_bay_dice.clear()
	var thumb_px := int(u * 13.0)
	if locked:
		# Vergittert wird nichts gewürfelt: der Sitz verspricht eine Karte, die
		# Bucht bleibt dunkel - ein besserer Köder als Platzhalter-Ware.
		card_seat.add_child(_build_shadow_card(thumb_px))
		_vitrine_grade = ShopController.GRADE_STAND
		vitrine_changed.emit()
		return
	offer_buttons.resize(run.secret_stock.size())
	var seat := card_slot_index()
	if seat >= 0:
		var card := _build_charm_card(run.secret_stock[seat], seat, thumb_px,
			run.secret_offer_price(run.secret_stock[seat]))
		card_seat.add_child(card)
		offer_buttons[seat] = card
	for i in run.secret_stock.size():
		_sort_into_bay(run.secret_stock[i], i == seat)
	# Ein WURF lässt die neue Ware aufsteigen, ein Kauf lässt sie liegen.
	var rolls := run.secret_rerolls if run.secret_shop_unlocked else -1
	_vitrine_grade = ShopController.GRADE_STAND if rolls == _seen_rolls \
		else ShopController.GRADE_RISE
	_seen_rolls = rolls
	_refresh_afford_state()
	vitrine_changed.emit()

## Ein Auslage-Platz wird zur körperlichen Ware: der Essenzwürfel liegt offen, der
## Sonderbestand steht versiegelt als seine Kassette (das Bündel trägt sein ×n auf
## der Kappe). Verkauft, vergeben oder Karte heißt: dieser Platz bleibt leer.
func _sort_into_bay(offer: Dictionary, on_card_seat: bool) -> void:
	var pack: Pack = null
	var die: DieDefinition = null
	if not on_card_seat and not bool(offer[GameRun.OFFER_SOLD]):
		match String(offer[GameRun.OFFER_KIND]):
			GameRun.KIND_DIE:
				die = offer[GameRun.OFFER_ITEM]
			GameRun.KIND_CATALYST:
				pack = offer[GameRun.OFFER_ITEM]
			GameRun.KIND_ENGRAVING:
				pack = Pack.fixed_engraving_pack(offer[GameRun.OFFER_ITEM] as Engraving,
					int(offer.get(GameRun.OFFER_COUNT, 1)))
	_bay_packs.append(pack)
	_bay_dice.append(die)

## Kaufbarkeit der Karte und des Misch-Knopfs am Ladungsstand ausrichten. Die Ware
## in der Bucht sperrt sich nicht - sie sagt ihren Preis auf der Karte.
func _refresh_afford_state() -> void:
	if not _built or run == null:
		return
	var cost := run.secret_reroll_cost()
	reroll_button.text = "Neu mischen ⚡%d" % cost
	reroll_button.disabled = run.charge < cost
	for i in offer_buttons.size():
		if i >= run.secret_stock.size() or offer_buttons[i] == null:
			continue
		var offer := run.secret_stock[i]
		var sold: bool = offer[GameRun.OFFER_SOLD]
		offer_buttons[i].disabled = sold or _offer_blocked(offer) \
			or run.charge < run.secret_offer_price(offer)

## Ob ein Platz an einem vollen Lager hängt: der Charm am Dock, die versiegelte
## Ware am Magazin (buy_secret_offer prüft dasselbe VOR dem Zahlen). Der Würfel
## hängt an keinem - er geht ins Ausgabefach, und das hat keinen Deckel.
func _offer_blocked(offer: Dictionary) -> bool:
	if run == null:
		return false
	if offer[GameRun.OFFER_KIND] == GameRun.KIND_CHARM:
		return run.charms_full()
	if offer[GameRun.OFFER_KIND] == GameRun.KIND_DIE:
		return false
	return run.packs_full()

## Die EINE Karte am Sitz: der legendäre Charm. Lizenzen sind digitale Ware und
## bleiben darum Bildschirm - alles Körperliche liegt in der Bucht daneben.
## Thumb groß, Preis in Ladung darunter; Name und Wirkung zeigt der Hover-Dropdown.
## price kommt fertig vom Aufrufer (GameRun.secret_offer_price) - die Hehlerware
## soll auf dem Schild stehen, nicht erst an der Kasse auffallen.
func _build_charm_card(offer: Dictionary, index: int, thumb_px: int, price: int) -> Button:
	var sold: bool = offer[GameRun.OFFER_SOLD]
	var charm: Charm = offer[GameRun.OFFER_ITEM]
	var tint := charm.rarity_color()
	var title := charm.display_name
	var body := charm.description
	var face: Control = CharmThumb.new(charm, thumb_px)

	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	# Volles Dock: der Sitz zeigt das statt seines Preises.
	var blocked := _offer_blocked(offer)
	var tag := "VERKAUFT" if sold else ("DOCK VOLL" if blocked else "⚡ %d" % price)
	column.add_child(_label(tag, u * 3.0,
		NEON_MUTED if sold or blocked else CHARGE_COLOR, HORIZONTAL_ALIGNMENT_CENTER))

	if not sold:
		card.pressed.connect(_on_offer_pressed.bind(index))
	return card

## Schatten-Sitz des vergitterten Ladens: dieselbe Kartenform, aber leer - er
## verspricht einen Platz, nicht eine bestimmte Ware.
func _build_shadow_card(thumb_px: int) -> Control:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_theme_stylebox_override("panel", _card_box(Color("#100c2266"), VIOLET, 0.3, 0.0))
	var stage := CenterContainer.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_glow_disc(VIOLET, thumb_px))
	stage.add_child(_label("?", u * 8.0, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.6),
		HORIZONTAL_ALIGNMENT_CENTER))
	card.add_child(stage)
	return card

# --- Gitter -------------------------------------------------------------------

## Dunkler Schleier über der ganzen Tasche, in seiner Mitte die Bedingung.
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
	lock_notice = _label("Ab Lizenzstufe %d" % GameRun.SECRET_UNLOCK_HUB_LEVEL,
		u * 4.6, VIOLET, HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(lock_notice)

# --- Käufe --------------------------------------------------------------------

func _on_offer_pressed(index: int) -> void:
	if run == null or index < 0 or index >= run.secret_stock.size():
		return
	var price := run.secret_offer_price(run.secret_stock[index])
	# Was versiegelt hinausgeht, ist ein neues Paket im Magazin, ein Würfel ein
	# neuer Platz im Ausgabefach - gemerkt wird beides VOR dem Kauf, damit die
	# Meldung genau dieses Exemplar meint.
	var stocked := run.owned_packs.size()
	var stashed := run.pending_dice.size()
	if not run.buy_secret_offer(index):  # Refresh kommt über secret_stock_changed
		return
	charge_spent.emit(price)
	if run.owned_packs.size() > stocked:
		goods_purchased.emit(run.owned_packs.back().pack_uid)
	elif run.pending_dice.size() > stashed:
		die_purchased.emit(run.pending_dice.back())

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
