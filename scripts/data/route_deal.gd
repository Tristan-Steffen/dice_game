class_name RouteDeal
extends Resource
## Ein Deal mit dem Haus: vor JEDER Runde wählt der Spieler einen von drei
## Routen-Angeboten. Jeder Deal hat einen Bonus und einen Malus mit EIGENER
## Laufzeit - daraus entsteht die Taktik: derselbe Deal ist in Runde 1 teuer
## und in Runde 5 fast geschenkt.
##
## Hier stehen nur Daten und Texte; die WIRKUNG lösen GameRun-Abfragen über die
## id auf (effective_goal, round_payout_factor, ...) - nie ein stiller Zweig in
## scene_root.

## Laufzeit einer Deal-Seite: sofort einmalig, nur die Runde der Unterschrift,
## oder bis zur Abrechnung nach dem Stresstest.
enum Scope { INSTANT, ROUND, BLOCK }

## Angebotsplatz: je Runde ein Wirtschafts-, ein Spiel- und ein Wildcard-Deal.
## BOSS-Deals liegen NUR in der Stresstest-Runde aus (eigener Topf).
enum Slot { ECONOMY, GAMEPLAY, TREAT, BOSS }

# --- Deal-ids (Single Source of Truth) ---
const SAVINGS_BONUS := "savings_bonus"
const ADVANCE_PAYMENT := "advance_payment"
const MAINTENANCE_CONTRACT := "maintenance_contract"
const ALL_ON_RED := "all_on_red"

const HIGH_VOLTAGE := "high_voltage"
const OVERCLOCK_DISCOUNT := "overclock_discount"
const ODDS_PACKAGE := "odds_package"
const ANCHOR_CLAUSE := "anchor_clause"

const HAPPY_HOUR := "happy_hour"
const TOURNAMENT_NIGHT := "tournament_night"
const POWER_SPIKE := "power_spike"

const DOUBLE_LOAD := "double_load"
const GOODWILL := "goodwill"
const STANDARD_PROTOCOL := "standard_protocol"

@export var id: String = ""
@export var display_name: String = ""
## Spielertexte der beiden Seiten; leerer Malus = reiner Bonus-Deal (Wildcard).
@export var bonus_text: String = ""
@export var malus_text: String = ""
@export var bonus_scope: Scope = Scope.BLOCK
@export var malus_scope: Scope = Scope.BLOCK
@export var slot: Slot = Slot.ECONOMY
## Akzentfarbe für Karte und Hub-Marke.
@export var color: Color = Color.WHITE
## Hebt das Rundenziel - solche Deals werden nie doppelt angeboten, sonst baut
## sich der Spieler ein unerreichbares Ziel (siehe GameRun.roll_route_offers).
@export var raises_benchmark: bool = false

static func _make(deal_id: String, name: String, slot_kind: Slot, tint: Color) -> RouteDeal:
	var deal := RouteDeal.new()
	deal.id = deal_id
	deal.display_name = name
	deal.slot = slot_kind
	deal.color = tint
	return deal

# --- Wirtschaft ---------------------------------------------------------------

static func savings_bonus() -> RouteDeal:
	var d := _make(SAVINGS_BONUS, "Sparprämie", Slot.ECONOMY, Color("#ffd319"))
	d.bonus_text = "+2$ je übrigem Würfel"
	d.malus_text = "Benchmark +25%"
	d.raises_benchmark = true
	return d

static func advance_payment() -> RouteDeal:
	var d := _make(ADVANCE_PAYMENT, "Vorschuss", Slot.ECONOMY, Color("#ffa62b"))
	d.bonus_text = "+12$ auf die Hand"
	d.bonus_scope = Scope.INSTANT
	d.malus_text = "Rundenauszahlung halbiert"
	return d

static func maintenance_contract() -> RouteDeal:
	var d := _make(MAINTENANCE_CONTRACT, "Wartungsvertrag", Slot.ECONOMY, Color("#8be9fd"))
	d.bonus_text = "Je Rundenbeginn eine Zahl-Gravur"
	d.malus_text = "Übrige Würfel zahlen nichts"
	return d

static func all_on_red() -> RouteDeal:
	var d := _make(ALL_ON_RED, "Alles auf Rot", Slot.ECONOMY, Color("#ff5555"))
	d.bonus_text = "Rundenauszahlung ×3"
	d.bonus_scope = Scope.ROUND
	d.malus_text = "Benchmark +50%"
	d.malus_scope = Scope.ROUND
	d.raises_benchmark = true
	return d

# --- Spiel --------------------------------------------------------------------

static func high_voltage() -> RouteDeal:
	var d := _make(HIGH_VOLTAGE, "Hochspannung", Slot.GAMEPLAY, Color("#50fa7b"))
	d.bonus_text = "Eine Überladungs-Stufe mehr"
	d.malus_text = "Benchmark +15%"
	d.raises_benchmark = true
	return d

static func overclock_discount() -> RouteDeal:
	var d := _make(OVERCLOCK_DISCOUNT, "Übertaktungsrabatt", Slot.GAMEPLAY, Color("#bd93f9"))
	d.bonus_text = "Übertaktungen 25% günstiger"
	d.malus_text = "Überladung endet bei Stufe 2"
	return d

static func odds_package() -> RouteDeal:
	var d := _make(ODDS_PACKAGE, "Quotenpaket", Slot.GAMEPLAY, Color("#ff79c6"))
	d.bonus_text = "Nebenwetten zahlen doppelt"
	d.malus_text = "Wett-Einsätze kosten doppelt"
	return d

static func anchor_clause() -> RouteDeal:
	var d := _make(ANCHOR_CLAUSE, "Anker-Klausel", Slot.GAMEPLAY, Color("#6272a4"))
	d.bonus_text = "Der erste Neuwurf jeder Hand farkelt nicht"
	d.malus_text = "Rundenauszahlung −25%"
	return d

# --- Wildcard: reine Boni (die alten Runden-Ereignisse) -----------------------

static func happy_hour() -> RouteDeal:
	var d := _make(HAPPY_HOUR, "Happy Hour", Slot.TREAT, Color("#ffd319"))
	d.bonus_text = "Rundenauszahlung ×2"
	d.bonus_scope = Scope.ROUND
	return d

static func tournament_night() -> RouteDeal:
	var d := _make(TOURNAMENT_NIGHT, "Turniernacht", Slot.TREAT, Color("#ff79c6"))
	d.bonus_text = "Nebenwetten zahlen doppelt"
	d.bonus_scope = Scope.ROUND
	return d

static func power_spike() -> RouteDeal:
	var d := _make(POWER_SPIKE, "Spannungsspitze", Slot.TREAT, Color("#8be9fd"))
	d.bonus_text = "Eine Kombination steht im Rampenlicht"
	d.bonus_scope = Scope.ROUND
	return d

# --- Stresstest-Konditionen (nur in der Boss-Runde) ---------------------------

static func double_load() -> RouteDeal:
	var d := _make(DOUBLE_LOAD, "Doppelbelastung", Slot.BOSS, Color("#ff5555"))
	d.bonus_text = "Rundenauszahlung ×2"
	d.bonus_scope = Scope.ROUND
	d.malus_text = "Auch der zweitheißeste Chip wird gedrosselt"
	d.malus_scope = Scope.ROUND
	return d

static func goodwill() -> RouteDeal:
	var d := _make(GOODWILL, "Kulanz der Hausleitung", Slot.BOSS, Color("#50fa7b"))
	d.bonus_text = "Kein Chip wird gedrosselt"
	d.bonus_scope = Scope.ROUND
	d.malus_text = "Rundenauszahlung halbiert"
	d.malus_scope = Scope.ROUND
	return d

static func standard_protocol() -> RouteDeal:
	var d := _make(STANDARD_PROTOCOL, "Standardprotokoll", Slot.BOSS, Color("#6272a4"))
	d.bonus_text = "Der Stresstest läuft nach Vorschrift"
	d.bonus_scope = Scope.ROUND
	return d

static func all() -> Array[RouteDeal]:
	return [
		savings_bonus(), advance_payment(), maintenance_contract(), all_on_red(),
		high_voltage(), overclock_discount(), odds_package(), anchor_clause(),
		happy_hour(), tournament_night(), power_spike(),
		double_load(), goodwill(), standard_protocol(),
	]

## Alle Deal-ids eines Angebotsplatzes.
static func ids_for_slot(slot_kind: Slot) -> Array[String]:
	var ids: Array[String] = []
	for deal in all():
		if deal.slot == slot_kind:
			ids.append(deal.id)
	return ids

static func find(deal_id: String) -> RouteDeal:
	for deal in all():
		if deal.id == deal_id:
			return deal
	return null

## Laufzeit-Etikett der Karte ("sofort" / "diese Runde" / "bis zur Abrechnung").
static func scope_label(scope: Scope) -> String:
	match scope:
		Scope.INSTANT:
			return "sofort"
		Scope.ROUND:
			return "diese Runde"
	return "bis zur Abrechnung"

## Ob die id überhaupt ein Deal ist (Marken-Aufbau, Tests).
static func is_valid_id(deal_id: String) -> bool:
	return find(deal_id) != null
