class_name SecretShopView
extends Control
## Der SCHWARZMARKT auf dem Grundriß der Automaten (seit 2026-11-26): ein Bauteil aus
## Gehäuse und drei SCHUBFÄCHERN, Fach i trägt Angebot i. Das Fenster malt nichts - es
## MELDET die Teile in Stations-Einheiten und je Fach Name, Preis und Zustand als reine
## Daten; den Körper (SecretShopBody) stellt scene_root. Unsichtbare Knöpfe über Fächern
## und den Neuwurf-Tasten der Nasen tragen den Klick. Gebucht wird ausschließlich über GameRun.

## Energie ist geflossen (Kauf oder Neuwurf) - erst gebucht, dann gemeldet.
signal energy_spent(amount: int)
## Eine Karte ist gekauft: sie liegt schon im Magazin.
signal goods_purchased(uids: Array[int])
## Ein Seelenwürfel ist gekauft: er liegt schon in pending_dice.
signal die_purchased(def: DieDefinition)
## Ein Modul ist gekauft: es wartet in pending_parts.
signal part_purchased(part: ComboPart)
## Eine Powerbank ist gekauft (Display-Pixel des Fachs).
signal powerbank_purchased(from_px: Vector2)
## Gleich wird Fach index gebucht - vor charm_buying/projector_buying.
signal offer_buying(index: int)
## Gleich wird der Charm gebucht: seine Diskette fliegt zum Projektor.
signal charm_buying
## Gleich wird der Projektor gebucht: sein Körper fliegt an den Port.
signal projector_buying

const BAYS := 3
## Der Grundriß in Stations-Einheiten (= Welt bei unit() = Pixel je Welt).
const UNITS := Vector2(28.0, 19.05)
const BAY_PITCH := 9.4
## Innenmaß eines Fachs: der größte Körper (Projektor samt Kabel) liegt ganz darin.
const BAY_INNER := Vector2(8.7, 8.7)
const BAY_RIM := 0.25
const BAY_Y := -1.35
## Die Teile als (Mitte x, Mitte y, Breite, Höhe) in Stations-Einheiten, y Bild-OBEN;
## je Fach "bay<i>" (Schale samt Rand, ausgefahren), "nose<i>", "label<i>" und die
## Neuwurf-Taste "reroll<i>" auf der Nase (ausgefahren gemessen).
const PARTS := {
	"housing": Rect2(0.0, 6.3375, 28.0, 6.175),
	"info": Rect2(0.0, 7.1, 26.8, 4.25),
	"label0": Rect2(-9.4, 4.2, 8.6, 0.95),
	"label1": Rect2(0.0, 4.2, 8.6, 0.95),
	"label2": Rect2(9.4, 4.2, 8.6, 0.95),
	"bay0": Rect2(-9.4, -1.35, 9.2, 9.2),
	"bay1": Rect2(0.0, -1.35, 9.2, 9.2),
	"bay2": Rect2(9.4, -1.35, 9.2, 9.2),
	"nose0": Rect2(-9.4, -6.95, 9.2, 2.0),
	"nose1": Rect2(0.0, -6.95, 9.2, 2.0),
	"nose2": Rect2(9.4, -6.95, 9.2, 2.0),
	"reroll0": Rect2(-6.3, -6.95, 2.0, 1.2),
	"reroll1": Rect2(3.1, -6.95, 2.0, 1.2),
	"reroll2": Rect2(12.5, -6.95, 2.0, 1.2),
	# Rechts neben dem Gehäuse auf halber Höhe: dort mündet die Hub-Ader.
	"contacts": Rect2(14.45, 0.0, 0.9, 1.1),
}

const STATE_AFFORD := "bezahlbar"
const STATE_DEAR := "zu teuer"
const STATE_BLOCKED := "voll"
const STATE_SOLD := "verkauft"
const STATE_EMPTY := "leer"
const EMPTY_NAME := "— — —"
const SOLD_NAME := "VERKAUFT"
const IDLE_TITLE := "SCHWARZMARKT"

var run: GameRun:
	set(value):
		if run != null:
			if run.secret_stock_changed.is_connected(_on_run_changed):
				run.secret_stock_changed.disconnect(_on_run_changed)
			if run.energy_changed.is_connected(_on_energy_changed):
				run.energy_changed.disconnect(_on_energy_changed)
			if run.charms_changed.is_connected(_on_run_changed):
				run.charms_changed.disconnect(_on_run_changed)
		run = value
		if run != null:
			run.secret_stock_changed.connect(_on_run_changed)
			run.energy_changed.connect(_on_energy_changed)
			run.charms_changed.connect(_on_run_changed)
		refresh()

## Je Fach ein unsichtbarer Knopf über Schale und Nase und einer über seiner Neuwurf-Taste.
var bay_buttons: Array[Button] = []
var reroll_buttons: Array[Button] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Pixel je Stations-Einheit (die knappere Achse gewinnt).
func unit() -> float:
	return minf(size.x / UNITS.x, size.y / UNITS.y)

## Ein Teil in eigenen Pixeln.
func part_rect(key: String) -> Rect2:
	var part: Rect2 = PARTS[key]
	var k := unit()
	var mid := size * 0.5 + Vector2(part.position.x, -part.position.y) * k
	return Rect2(mid - part.size * k * 0.5, part.size * k)

func bay_rect(i: int) -> Rect2:
	return part_rect("bay%d" % clampi(i, 0, BAYS - 1))

func nose_rect(i: int) -> Rect2:
	return part_rect("nose%d" % clampi(i, 0, BAYS - 1))

func label_rect(i: int) -> Rect2:
	return part_rect("label%d" % clampi(i, 0, BAYS - 1))

func info_rect() -> Rect2:
	return part_rect("info")

## Die Neuwurf-Taste fährt mit der Nase: eingefahren steht sie eine Fachtiefe weiter oben.
func reroll_rect(i: int) -> Rect2:
	var rect := part_rect("reroll%d" % clampi(i, 0, BAYS - 1))
	if not bay_open(i):
		rect.position.y -= bay_rect(i).size.y
	return rect

## Schale und Nase eines Fachs: dort kauft der Klick, dort fragt der Zeiger.
func bay_hit_rect(i: int) -> Rect2:
	return bay_rect(i).merge(nose_rect(i))

## Alle Teile in eigenen Pixeln.
func layout() -> Dictionary:
	var out := {}
	for key: String in PARTS:
		out[key] = part_rect(key)
	return out

## Das Fach unter einem eigenen Pixel (-1 = keins; nur offene Fächer zählen).
func bay_at(local_px: Vector2) -> int:
	for i in BAYS:
		if bay_open(i) and bay_hit_rect(i).has_point(local_px):
			return i
	return -1

func refresh() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_build_buttons()
	_refresh_buttons()

# --- Zustand je Fach (reine Daten) ----------------------------------------------------

## Ob Fach i ausgefahren steht: es trägt eine unverkaufte Ware.
func bay_open(i: int) -> bool:
	return run != null and i >= 0 and i < run.secret_stock.size() \
		and not bool(run.secret_stock[i][GameRun.OFFER_SOLD])

func offer_at(i: int) -> Dictionary:
	if run == null or i < 0 or i >= run.secret_stock.size():
		return {}
	return run.secret_stock[i]

## Name, Preis und Zustand eines Fachs - was das Schild, die Nase und die Leiste tragen.
func bay_state(i: int) -> Dictionary:
	var offer := offer_at(i)
	if offer.is_empty():
		return {"kind": "", "item": null, "name": EMPTY_NAME, "price": "", "state": STATE_EMPTY,
			"open": false}
	var sold := bool(offer[GameRun.OFFER_SOLD])
	var price := run.secret_offer_price(offer)
	var state := STATE_SOLD if sold else (STATE_BLOCKED if _offer_blocked(offer)
		else (STATE_AFFORD if run.energy >= price else STATE_DEAR))
	return {"kind": String(offer[GameRun.OFFER_KIND]), "item": offer[GameRun.OFFER_ITEM],
		"name": SOLD_NAME if sold else ware_name(offer), "price": "" if sold else str(price),
		"state": state, "open": not sold}

## Der Name einer Ware auf ihrem Schild.
static func ware_name(offer: Dictionary) -> String:
	var item: Variant = offer.get(GameRun.OFFER_ITEM)
	match String(offer.get(GameRun.OFFER_KIND, "")):
		GameRun.KIND_CHARM:
			return (item as Charm).display_name
		GameRun.KIND_DIE:
			var die := item as DieDefinition
			if die.essence_id != "":
				return "%s-Würfel" % Essence.by_id(die.essence_id).display_name
			return "Würfel"
		GameRun.KIND_PART:
			return (item as ComboPart).display_name
		GameRun.KIND_PROJECTOR:
			return "Projektor"
		GameRun.KIND_POWERBANK:
			return "Powerbank"
	return (item as Pack).display_name if item is Pack else ""

## Die Kurzform des vollen Lagers auf der Nase.
static func blocked_tag(kind: String) -> String:
	match kind:
		GameRun.KIND_CHARM:
			return "PORTS VOLL"
		GameRun.KIND_PROJECTOR:
			return "KEIN PORT"
		GameRun.KIND_POWERBANK:
			return "SPEICHER VOLL"
		GameRun.KIND_PART:
			return "MODULE VOLL"
		GameRun.KIND_DIE:
			return ""
	return "MAGAZIN VOLL"

## Preis und Zustand der Neuwurf-Taste von Fach i.
func reroll_state(i: int) -> Dictionary:
	if run == null or i < 0 or i >= run.secret_stock.size():
		return {"price": "", "afford": false}
	var cost := run.secret_reroll_cost()
	return {"price": str(cost), "afford": run.energy >= cost}

## Die Auskunft eines Fachs für das INFO-DISPLAY ({} = keine Ware).
func bay_info(i: int) -> Dictionary:
	var offer := offer_at(i)
	if offer.is_empty() or bool(offer[GameRun.OFFER_SOLD]):
		return {}
	var data := {"title": ware_name(offer), "body": "", "net": null}
	match String(offer[GameRun.OFFER_KIND]):
		GameRun.KIND_CHARM:
			data["body"] = (offer[GameRun.OFFER_ITEM] as Charm).description
		GameRun.KIND_DIE:
			var die: DieDefinition = offer[GameRun.OFFER_ITEM]
			var essence := Essence.by_id(die.essence_id)
			data["body"] = "%s\n%s" % [essence.short, essence.description]
			data["net"] = die
		GameRun.KIND_PART:
			data["body"] = (offer[GameRun.OFFER_ITEM] as ComboPart).description
		GameRun.KIND_PROJECTOR:
			data["body"] = "+1 Charm-Platz: ein weiterer Projektor an einem freien Port."
		GameRun.KIND_POWERBANK:
			data["body"] = "Speicher +%d ⚡ - eine Batterie mehr im Rack." % GameRun.ENERGY_ROW
		GameRun.KIND_CATALYST, GameRun.KIND_BLANK:
			data["body"] = (offer[GameRun.OFFER_ITEM] as Pack).description
		_:
			var card: Pack = offer[GameRun.OFFER_ITEM]
			data["body"] = "%s\nAuf %d Seiten." % [card.fixed_engraving.description,
				StampNet.filled_count(card.stamp_net)]
	return data

## Der Platz mit der Charm-Ware (-1 = keiner, der legendäre Topf ist erschöpft).
func card_slot_index() -> int:
	if run == null:
		return -1
	for i in run.secret_stock.size():
		if run.secret_stock[i][GameRun.OFFER_KIND] == GameRun.KIND_CHARM:
			return i
	return -1

## Ob ein Platz an einem vollen Lager hängt (buy_secret_offer prüft dasselbe).
func _offer_blocked(offer: Dictionary) -> bool:
	if run == null:
		return false
	match String(offer[GameRun.OFFER_KIND]):
		GameRun.KIND_CHARM:
			return run.charms_full()
		GameRun.KIND_DIE:
			return false
		GameRun.KIND_PART:
			return not run.parts_room()
		GameRun.KIND_PROJECTOR:
			return run.projectors >= GameRun.MAX_PROJECTORS
		GameRun.KIND_POWERBANK:
			return run.powerbank_price() < 0
	return run.pack_room() < 1

# --- Knöpfe -----------------------------------------------------------------------------

func _build_buttons() -> void:
	if bay_buttons.is_empty():
		for i in BAYS:
			var button := _ghost_button("Fach%d" % i)
			button.pressed.connect(_on_offer_pressed.bind(i))
			bay_buttons.append(button)
		# Nach den Fächern gebaut: die Taste liegt über ihrer Nase und fängt den Klick.
		for i in BAYS:
			var key := _ghost_button("Neuwurf%d" % i)
			key.pressed.connect(_on_reroll_pressed.bind(i))
			reroll_buttons.append(key)
	for i in BAYS:
		var rect := bay_hit_rect(i)
		bay_buttons[i].position = rect.position
		bay_buttons[i].size = rect.size
		_place_reroll_button(i)

func _ghost_button(part: String) -> Button:
	var button := Button.new()
	button.name = part
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	add_child(button)
	return button

func _refresh_buttons() -> void:
	if bay_buttons.is_empty() or run == null:
		return
	for i in BAYS:
		var state := bay_state(i)
		bay_buttons[i].disabled = String(state["state"]) != STATE_AFFORD
		reroll_buttons[i].disabled = not bool(reroll_state(i)["afford"])
		_place_reroll_button(i)

func _place_reroll_button(i: int) -> void:
	var rect := reroll_rect(i)
	reroll_buttons[i].position = rect.position
	reroll_buttons[i].size = rect.size

# --- Käufe ------------------------------------------------------------------------------

## Der Griff ins Fach kauft.
func buy_offer(index: int) -> void:
	_on_offer_pressed(index)

func _on_offer_pressed(index: int) -> void:
	if run == null or index < 0 or index >= run.secret_stock.size():
		return
	var offer := run.secret_stock[index]
	var price := run.secret_offer_price(offer)
	var stocked := run.owned_packs.size()
	var stashed := run.pending_dice.size()
	var parts_waiting := run.pending_parts.size()
	# Dieselben Bremsen wie die Buchung - erst dann gibt das Fach seine Ware ab.
	if not bool(offer[GameRun.OFFER_SOLD]) and run.energy >= price and not _offer_blocked(offer):
		offer_buying.emit(index)
		if offer[GameRun.OFFER_KIND] == GameRun.KIND_CHARM:
			charm_buying.emit()
		elif offer[GameRun.OFFER_KIND] == GameRun.KIND_PROJECTOR:
			projector_buying.emit()
	var powerbank: bool = offer[GameRun.OFFER_KIND] == GameRun.KIND_POWERBANK
	if not run.buy_secret_offer(index):
		return
	energy_spent.emit(price)
	if powerbank:
		powerbank_purchased.emit(position + bay_rect(index).get_center())
	if run.owned_packs.size() > stocked:
		var uids: Array[int] = []
		for i in range(stocked, run.owned_packs.size()):
			uids.append(run.owned_packs[i].pack_uid)
		goods_purchased.emit(uids)
	elif run.pending_dice.size() > stashed:
		die_purchased.emit(run.pending_dice.back())
	elif run.pending_parts.size() > parts_waiting:
		part_purchased.emit(run.pending_parts.back())

## Der Neuwurf EINES Fachs - auch ein verkauftes wird so neu bestückt.
func reroll_offer(index: int) -> void:
	_on_reroll_pressed(index)

func _on_reroll_pressed(index: int) -> void:
	if run == null:
		return
	var cost := run.secret_reroll_cost()
	if run.reroll_secret_offer(index):
		energy_spent.emit(cost)

func _on_run_changed() -> void:
	_refresh_buttons()

func _on_energy_changed(_value: int) -> void:
	_refresh_buttons()
