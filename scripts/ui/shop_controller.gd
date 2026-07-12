class_name ShopController
extends Panel
## Der Shop als kleines ringgebundenes Menü-Büchlein: zwei cremefarbene Seiten
## (links die Würfel-Angebote, rechts Charms und die Coupon-Packs), verbunden
## durch Metall-Binderinge am Falz (siehe RingSpine). Die linke Seite ist bewusst
## etwas kleiner und dunkler - sie liest sich als das "umgeschlagene" Blatt des
## Ringbuchs, unter dem der restliche Blattstapel hervorlugt.
## Umblättern auf eine NOCH NICHT gesehene Seite
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

const CHARM_PRICE := 15  # Preis pro Charm-Kauf
const DICE_OFFER_COUNT := 3  # Würfel-Angebote je Doppelseite (siehe DiceOffer)
const OFFER_THUMB_SIZE := 46  # Kantenlänge der Mini-Vorschau je Angebots-Würfel (siehe DiceRowView)
const CHARM_THUMB_SIZE := 84  # Kantenlänge der 3D-Vorschau je Charm-Angebot (siehe CharmThumb)

## Gebühr fürs Aufschlagen einer NEUEN Doppelseite: erst $2, dann $3, $4 ...
## (fee = FLIP_FEE_BASE + bereits existierende Seiten - 1). Je Besuch zurückgesetzt.
const FLIP_FEE_BASE := 2

## Die vier Coupon-Pack-Sorten (siehe CouponSheet.generate: allowed_kinds).
## Jedes Pack gibt es in den drei Bogengrößen (siehe PACK_SIZES); je größer das
## Raster, desto teurer und desto größere Coupons können darauf liegen (die
## Fläche IST die Rarität). Das gemischte Heft ist bewusst etwas GÜNSTIGER als
## die sortenreinen Packs - wer gezielt zieht, zahlt für die Auswahl. Cover-
## Motive nach Dateinamens-Konvention: PACK_COVER_DIR + id + ".jpg". Als festes
## "Getränke-Sortiment" auf jeder Doppelseite identisch.
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
## (danach greift man zum Umblättern für frische Packs). Umblättern würfelt ein
## neues Sortiment.
const PACK_GRID_COLUMNS := 3
const PACK_OFFER_COUNT := 6

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
	## Die Pack-Angebote der Seite (x = PACKS-Index, y = PACK_SIZES-Index).
	var pack_offers: Array[Vector2i] = []
	## Je Angebot, ob es auf dieser Seite schon gekauft wurde (nur einmal kaufbar).
	var pack_bought: Array[bool] = []

## Die Metall-Ringbindung des Menü-Büchleins: ein zeichnendes Overlay über dem
## ganzen Shop (fängt keine Maus), damit die Bügel über BEIDEN Papierseiten
## liegen dürfen. Je Ring: Stanzlöcher in beiden Seiten, ein Metallbügel mit
## Licht- und Schattenkante quer über den Falz-Spalt, plus ein weicher
## Falz-Schatten an den Papier-Innenkanten. Unter der (etwas kleineren) rechten
## Seite lugen zusätzlich die Kanten der übrigen Blätter des Stapels hervor - sie
## liest sich so als oberstes Blatt des noch nicht durchgeblätterten Rests.
class RingSpine:
	extends Control

	const RING_COUNT := 8        # Bügel der Wire-Bindung, gleichmäßig verteilt
	const RING_MARGIN := 30.0    # Abstand des ersten/letzten Rings vom Seitenrand
	const HOLE_INSET := 11.0     # wie weit die Stanzlöcher im Papier sitzen
	const HOLE_RADIUS := 4.5
	const RING_WIDTH := 6.0
	const METAL := Color(0.58, 0.60, 0.65)
	const METAL_LIGHT := Color(0.88, 0.90, 0.94)
	const METAL_DARK := Color(0.30, 0.32, 0.36)
	const HOLE_COLOR := Color(0.2, 0.17, 0.12)   # dunkles Stanzloch im Papier
	const STACK_PAPER := Color("ddd0b0")         # Blattstapel-Kanten unter der linken Seite
	const STACK_LAYERS := 5      # sichtbare Blätter unter dem obersten (der linken Seite)
	const STACK_STEP := 3.0      # wie weit jedes tiefere Blatt nach außen absteht

	var left_page: Control
	var right_page: Control

	func _draw() -> void:
		if left_page == null or right_page == null:
			return
		var lr := Rect2(left_page.global_position - global_position, left_page.size)
		var rr := Rect2(right_page.global_position - global_position, right_page.size)

		_draw_sheet_stack(rr, true)  # Stapel unter der rechten Seite (freie Außenkante = rechts)
		_draw_spine_shadow(lr, true)
		_draw_spine_shadow(rr, false)

		# Ringe über die gemeinsame Höhe beider Seiten verteilen (die linke ist
		# kürzer - alle Löcher müssen in BEIDEN Blättern sitzen).
		var top := maxf(lr.position.y, rr.position.y) + RING_MARGIN
		var bottom := minf(lr.end.y, rr.end.y) - RING_MARGIN
		for i in RING_COUNT:
			var y := lerpf(top, bottom, float(i) / float(RING_COUNT - 1))
			_draw_ring(lr.end.x - HOLE_INSET, rr.position.x + HOLE_INSET, y)

	## Ein Bügel der Bindung: durch beide Stanzlöcher, mit Schlagschatten aufs
	## Papier, Glanzlinie oben und Schattenkante unten (liest sich als rundes Metall).
	func _draw_ring(xl: float, xr: float, y: float) -> void:
		draw_circle(Vector2(xl, y), HOLE_RADIUS, HOLE_COLOR)
		draw_circle(Vector2(xr, y), HOLE_RADIUS, HOLE_COLOR)
		draw_line(Vector2(xl, y + 3.0), Vector2(xr, y + 3.0), Color(0, 0, 0, 0.25), RING_WIDTH)
		draw_line(Vector2(xl, y), Vector2(xr, y), METAL, RING_WIDTH)
		draw_circle(Vector2(xl, y), RING_WIDTH * 0.5, METAL)
		draw_circle(Vector2(xr, y), RING_WIDTH * 0.5, METAL)
		draw_line(Vector2(xl, y - 1.2), Vector2(xr, y - 1.2), METAL_LIGHT, 1.8)
		draw_line(Vector2(xl, y + 1.8), Vector2(xr, y + 1.8), METAL_DARK, 1.2)

	## Weicher Schatten am Falz: die Papier-Innenkante dunkelt zum Spalt hin ab
	## (per-Vertex-Farben des Polygons ergeben den Verlauf).
	func _draw_spine_shadow(rect: Rect2, inner_edge_is_right: bool) -> void:
		var width := 14.0
		var x_inner := rect.end.x if inner_edge_is_right else rect.position.x
		var x_outer := x_inner - width if inner_edge_is_right else x_inner + width
		var points := PackedVector2Array([
			Vector2(x_outer, rect.position.y), Vector2(x_inner, rect.position.y),
			Vector2(x_inner, rect.end.y), Vector2(x_outer, rect.end.y)])
		var dark := Color(0, 0, 0, 0.16)
		var clear := Color(0, 0, 0, 0.0)
		draw_polygon(points, PackedColorArray([clear, dark, dark, clear]))

	## Der Blattstapel unter einer Seite: mehrere Papierblätter treppen sich nach
	## unten und zur freien Außenkante hin ab, sodass ihre Kanten dort hervorlugen -
	## die Seite liest sich so als oberstes Blatt eines Stapels. outer_is_right
	## wählt die freie Außenkante (rechts = Spine links, für die rechte Menü-Seite).
	## Da das Overlay ÜBER dem Seiteninhalt zeichnet, werden nur die Rand-Bänder
	## AUSSERHALB der Seite gemalt (keine Flächen über dem Inhalt); tiefere Blätter
	## zuerst, damit nähere sie überdecken.
	func _draw_sheet_stack(rect: Rect2, outer_is_right: bool) -> void:
		var s := 1.0 if outer_is_right else -1.0          # Richtung "nach außen"
		var edge_x := rect.end.x if outer_is_right else rect.position.x  # freie Außenkante
		var spine_x := rect.position.x if outer_is_right else rect.end.x  # Falz-Seite (fest)
		var edge := Color(0, 0, 0, 0.16)
		for i in range(STACK_LAYERS, 0, -1):
			var out := i * STACK_STEP
			var inn := (i - 1) * STACK_STEP
			var paper := STACK_PAPER.darkened(i * 0.035)
			var outer := edge_x + s * out    # Außenkante DIESES Blattes
			# Unterkante (von der Falz-Seite bis zur abstehenden Außenkante).
			draw_rect(Rect2(minf(spine_x, outer), rect.end.y + inn,
				absf(outer - spine_x), out - inn), paper)
			# Außenkante (ab der um "out" nach unten verschobenen Oberkante).
			draw_rect(Rect2(minf(edge_x + s * inn, outer), rect.position.y + out,
				STACK_STEP, rect.size.y), paper)
			# Dünne Schattenlinie an der Außen- und Unterkante jedes Blattes.
			draw_line(Vector2(outer, rect.position.y + out),
				Vector2(outer, rect.end.y + out), edge, 1.0)
			draw_line(Vector2(minf(spine_x, outer), rect.end.y + out),
				Vector2(maxf(spine_x, outer), rect.end.y + out), edge, 1.0)

## Die Bogen-Miniatur einer Pack-Karte: das Cover-Motiv liegt als "Papier" in
## Bogengröße auf der Karte, überzogen mit dem ECHTEN Raster des Packs als
## Perforationslinien. Die Bogengröße ist so auf einen Blick sichtbar - ein
## großes Pack hat sichtbar größeres Papier UND ein feineres Raster als ein
## Schnipsel. Unten bündig ausgerichtet, damit alle Karten einer Zeile auf
## einer gemeinsamen Grundlinie stehen.
class PackSheetThumb:
	extends Control

	const PAPER := Color("efe4c8")                   # Bogenpapier hinter dem Motiv
	const PERF := Color(0.42, 0.29, 0.18, 0.7)       # Perforations-Braun (siehe CouponSheetView)
	const SIDE_BASE := 34.0                          # Kantenlänge: SIDE_BASE + dims × SIDE_PER_CELL
	const SIDE_PER_CELL := 4.0                       # 2×2 -> 42px ... 9×9 -> 70px

	var texture: Texture2D
	var dims: int
	var side: float

	func _init(p_texture: Texture2D, p_dims: int) -> void:
		texture = p_texture
		dims = p_dims
		side = SIDE_BASE + p_dims * SIDE_PER_CELL
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

@onready var left_page: PanelContainer = $VBoxContainer/Book/LeftHolder/LeftPage
@onready var left_content: VBoxContainer = $VBoxContainer/Book/LeftHolder/LeftPage/LeftContent
@onready var right_page: PanelContainer = $VBoxContainer/Book/RightHolder/RightPage
@onready var right_content: VBoxContainer = $VBoxContainer/Book/RightHolder/RightPage/RightContent
@onready var done_button: Button = $VBoxContainer/DoneButton

## Blätter-Ecken der aktuellen Doppelseite (je Seiten-Fußzeile neu gebaut,
## siehe _page_footer): links zurück, rechts vor (mit Gebühr bei neuer Seite).
var page_back_button: Button
var page_next_button: Button

## Das Ringbinder-Overlay (siehe RingSpine), in _style einmalig aufgebaut.
var ring_spine: RingSpine

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

func _ready() -> void:
	_style()
	done_button.pressed.connect(_on_done_pressed)

## Nur das Menü selbst ist sichtbar: der Panel-Hintergrund bleibt leer (kein
## dunkler Kasten hinter dem Buch), gestylt werden allein die Papier-Seiten und
## der kleine Fertig-Knopf darunter. Obendrauf kommt die Metall-Ringbindung als
## Overlay - und unter der rechten Seite der Blattstapel (siehe RingSpine).
func _style() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	CasinoStyle.style_button(done_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, 16)
	left_page.add_theme_stylebox_override("panel", _paper_box())
	right_page.add_theme_stylebox_override("panel", _paper_box())

	ring_spine = RingSpine.new()
	ring_spine.left_page = left_page
	ring_spine.right_page = right_page
	ring_spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_spine.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ring_spine)  # letztes Kind: zeichnet ÜBER beiden Papierseiten
	# Erst nach dem ersten Container-Layout stehen die Seiten-Rechtecke fest.
	left_page.item_rect_changed.connect(ring_spine.queue_redraw)
	right_page.item_rect_changed.connect(ring_spine.queue_redraw)

## Cremefarbenes Seitenpapier mit dunklerem Rand und weichem Schatten.
func _paper_box(paper: Color = PAPER_COLOR) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = paper
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

## Gebühr fürs Aufschlagen der nächsten NEUEN Doppelseite (steigt je Besuch);
## Wechselgeld-Charm senkt sie (min. $1, siehe CharmEffects.flip_fee).
func _next_flip_fee() -> int:
	return CharmEffects.flip_fee(FLIP_FEE_BASE + spreads.size() - 1, run.charm_ids())

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
	spread.dice_offers = DiceOffer.roll_offers(DICE_OFFER_COUNT, run.charm_ids())  # Gütesiegel erzwingt Veredelungen

	# Besitz-Prüfung über die ROHEN ids (Totems lösen sich in charm_ids() zu
	# ihren Nachbarn auf und würden sonst doppelt angeboten).
	var owned_ids: Array[String] = run.owned_charm_ids()
	var available: Array[Charm] = []
	for charm in Charm.all():
		if not owned_ids.has(charm.id):
			available.append(charm)
	available.shuffle()
	for i in mini(2, available.size()):
		spread.charm_options.append(available[i])
	spread.charm_bought.resize(spread.charm_options.size())
	spread.charm_bought.fill(false)

	# Pack-Sortiment: 9 verschiedene aus allen Sorte-×-Größe-Kombinationen.
	var combos: Array[Vector2i] = []
	for p in PACKS.size():
		for s in PACK_SIZES.size():
			combos.append(Vector2i(p, s))
	combos.shuffle()
	spread.pack_offers = combos.slice(0, PACK_OFFER_COUNT)
	spread.pack_bought.resize(spread.pack_offers.size())
	spread.pack_bought.fill(false)
	return spread

## Zeigt die aktuelle Doppelseite: Spiegel-Variablen umhängen, beide Seiten neu
## bebauen, Navigation und Kaufbarkeit aktualisieren.
func _show_spread() -> void:
	var spread := spreads[current_spread_index]
	dice_offers = spread.dice_offers
	charm_options = spread.charm_options
	charm_bought = spread.charm_bought
	pack_offers = spread.pack_offers
	pack_bought = spread.pack_bought

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
	sheet_button_prices.clear()
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
	sheet_button_prices.clear()

	right_content.add_child(_menu_heading("Charms (je $%d)" % _charm_price()))
	for i in spread.charm_options.size():
		var charm := spread.charm_options[i]
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 8)
		entry.add_child(CharmThumb.new(charm, CHARM_THUMB_SIZE))

		var button := Button.new()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, CHARM_THUMB_SIZE)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.tooltip_text = charm.description
		if spread.charm_bought[i] or run.owned_charm_ids().has(charm.id):
			button.text = "%s (gekauft)\n%s" % [charm.display_name, charm.description]
			button.disabled = true
		else:
			button.text = "%s\n%s\n$%d" % [charm.display_name, charm.description, _charm_price()]
			button.pressed.connect(_on_charm_clicked.bind(i))
		CasinoStyle.style_button(button, CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, 13)
		entry.add_child(button)
		right_content.add_child(entry)
		charm_buttons.append(button)

	right_content.add_child(_menu_heading("Coupon-Packs"))
	var grid := GridContainer.new()
	grid.columns = PACK_GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	right_content.add_child(grid)
	for i in spread.pack_offers.size():
		var offer := spread.pack_offers[i]
		grid.add_child(_build_pack_card(offer.x, offer.y, i))

	page_next_button = _corner_button("›")
	page_next_button.pressed.connect(_on_page_next_pressed)
	right_content.add_child(_page_footer(current_spread_index * 2 + 2, page_next_button, false))

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
	card.add_theme_constant_override("separation", 2)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = "%s (%s)\n%s" % [pack["name"], size_label, pack["tooltip"]]

	var cover_path: String = PACK_COVER_DIR + pack["id"] + ".jpg"
	var cover: Texture2D = load(cover_path) if ResourceLoader.exists(cover_path) else null
	var dims: int = CouponSheet.grid_size(PACK_SIZES[size_index]["kind"]).x
	var thumb := PackSheetThumb.new(cover, dims)
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Miniaturen einer Zeile stehen unten bündig
	card.add_child(thumb)

	var name_label := Label.new()
	name_label.text = pack["name"]
	name_label.clip_text = true
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", INK)
	card.add_child(name_label)

	var button := Button.new()
	if pack_bought[offer_index]:
		button.text = "vergriffen"
		button.disabled = true
	else:
		button.text = "%s $%d" % [size_label, price]
		button.pressed.connect(_on_sheet_pressed.bind(offer_index))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 25)
	CasinoStyle.style_button(button, CasinoStyle.GREEN, CasinoStyle.GREEN_DARK, 12)
	card.add_child(button)
	sheet_buttons.append(button)
	sheet_button_prices.append(price)
	return card

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
	box.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	vbox.add_child(DiceRowView.build_row(offer.dice[0], OFFER_THUMB_SIZE, offer.size()))

	# Veredelte Angebote (Material-Seiten/Kanten, siehe DiceOffer._roll_refinements)
	# benennen ihre Veredelungen - die Mini-Vorschau allein ist dafür zu klein,
	# und der Aufpreis soll lesbar begründet sein.
	var refinements := _refinement_text(offer.dice[0])
	if refinements != "":
		var refined_label := Label.new()
		refined_label.text = "Veredelt: %s" % refinements
		refined_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		refined_label.add_theme_font_size_override("font_size", 12)
		refined_label.add_theme_color_override("font_color", CasinoStyle.GOLD)
		vbox.add_child(refined_label)

	var buy := Button.new()
	buy.text = "%s · $%d" % [offer.display_name, _offer_price(offer)]
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.pressed.connect(_on_offer_pressed.bind(index))
	CasinoStyle.style_button(buy, CasinoStyle.BLUE, CasinoStyle.BLUE_DARK, 14)
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
## eine neue Doppelseite (dessen Button auch die fällige Gebühr anzeigt).
func _refresh_afford_state() -> void:
	var money: int = run.money
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
	_clear_flip_sheets()
	_clear_pages()  # 3D-Vorschauen freigeben (kein Hintergrund-Rendern nach dem Schließen)
	visible = false
	closed.emit()
