class_name SideBet
extends RefCounted
## Eine Nebenwette der "Bank": vor einer Runde platziert (Einsatz sofort fällig
## oder als laufende Steuer je Hand), wird sie am Rundenende gegen die
## Rundenbilanz geprüft. Reine Daten/Logik, keine Nodes.

## Bedingung, die die Runde erfüllen muss:
## COMBO           - eine genommene Hand mindestens vom Rang target_combo,
## HAND_SCORE      - eine einzelne Hand mit >= target Punkten,
## FEW_DICE        - die Runde mit höchstens target genommenen Würfeln räumen,
## NO_FARKLE       - die Runde ohne einen einzigen Farkle räumen,
## FIRST_HAND      - schon die ERSTE genommene Hand wertet >= target Punkte,
## OVERCHARGE      - die Runde räumt >= target Überladungs-Stufen,
## DISTINCT_COMBOS - >= target VERSCHIEDENE Kombinationen genommen,
## HAND_LIMIT      - die Runde mit höchstens target Händen räumen,
## COMEBACK        - nach einem Farkle trotzdem geräumt,
## HIGH_DICE       - eine Hand aus >= HIGH_DICE_MIN Würfeln, alle mit >= HIGH_DICE_EYES Augen,
## CLEARED         - nur räumen (die Steuerwetten tragen die Herausforderung im Einsatz),
## MAX_HAND_DICE   - keine Hand nutzt mehr als target Würfel,
## FULL_HANDS      - JEDE Hand nutzt alle sechs Würfel,
## NO_REPEAT       - keine Kombination zweimal genommen.
enum Condition { COMBO, HAND_SCORE, FEW_DICE, NO_FARKLE, FIRST_HAND, OVERCHARGE,
	DISTINCT_COMBOS, HAND_LIMIT, COMEBACK, HIGH_DICE, CLEARED, MAX_HAND_DICE,
	FULL_HANDS, NO_REPEAT }

## Womit der Einsatz bezahlt wird. MONEY/PACKS/ENERGY sind beim Platzieren
## fällig, MONEY_PER_HAND/MONEY_PER_DIE laufen als Steuer je genommener Hand -
## reicht das Geld dafür nicht, verfällt die Wette (voided).
enum Stake { MONEY, PACKS, MONEY_PER_HAND, MONEY_PER_DIE, ENERGY }
## In welcher WARE der Gewinnwert ausgezahlt wird. PACKS = Regal-Karten einer Sorte,
## MULTIPLIER = Multiplikator-Karten, PACK = EIN gewürfelter Sonderposten, SPECIAL =
## der feste Sonderposten (Pointer, Veredelung), PART = ein Modul, DIE = ein Würfel,
## CARD_PACK/DICE_PACK = EIN Laden-Paket, das nach dem Kassieren in der Grube öffnet.
enum Payout { PACKS, MONEY, SPECIAL, ENERGY, PACK, PART, DIE, CATALYST, OPERATOR, MULTIPLIER,
	CARD_PACK, DICE_PACK }

## Quoten je Schwierigkeit (Spieler-Entscheid 2026-11-10).
const ODDS_EASY := 2.0
const ODDS_MEDIUM := 2.5
const ODDS_HARD := 3.0
## Ware statt Geld gibt ein Viertel mehr her - Geld ist die flexiblere Wahl.
const WARE_BONUS := 1.25
## Einsatzwert der Steuern und der Energie in $.
const PER_HAND_HANDS := 4
const PER_DIE_DICE := 10
const ENERGY_STAKE_MONEY := 10
## Energie als Gewinn: 1 ⚡ je so viel Gewinnwert (besser als der Hauskurs $10).
const ENERGY_PRICE := 8
## Höchstens so viele Karten zahlt eine Wette aus.
const MAX_REWARD_CARDS := 4

## Das billigste Paket - darunter zahlt keine Wette eins.
const CARD_PACK_MIN := 9
## Das billigste Würfel-Paket.
const DICE_PACK_MIN := 12
## Die GEWINN-TABELLE: Art, Gewicht und Mindestwert (Geld ohne, Ware mit ×1,25).
const WARES := [
	{"kind": Payout.MONEY, "weight": 20, "min": 0},
	{"kind": Payout.PACKS, "type": Pack.TYPE_NUMBER, "weight": 14, "min": 4},
	{"kind": Payout.PACKS, "type": Pack.TYPE_MATERIAL, "weight": 10, "min": 5},
	{"kind": Payout.PACKS, "type": Pack.TYPE_DICE_MOD, "weight": 8, "min": 6},
	{"kind": Payout.MULTIPLIER, "weight": 6, "min": 8},
	{"kind": Payout.DIE, "weight": 12, "min": 8},
	{"kind": Payout.PART, "weight": 10, "min": 5},
	{"kind": Payout.ENERGY, "weight": 8, "min": 8},
	{"kind": Payout.CATALYST, "weight": 5, "min": 8},
	{"kind": Payout.OPERATOR, "weight": 4, "min": 11},
	{"kind": Payout.PACK, "weight": 3, "min": 18},
	{"kind": Payout.CARD_PACK, "weight": 8, "min": CARD_PACK_MIN},
	{"kind": Payout.DICE_PACK, "weight": 8, "min": DICE_PACK_MIN},
]
## Sorten-Gewichte des Paket-Gewinns: die Auslage-Gewichte des Ladens.
const CARD_PACK_SORT_WEIGHTS := CardPack.SHOP_SORT_WEIGHTS
const DICE_PACK_SORT_WEIGHTS := DicePack.SHOP_SORT_WEIGHTS
## Die Katalysatoren, die eine Wette zahlen darf (nie die Reparatur-Karte).
const BET_CATALYSTS := [Pack.CATALYST_COOL, Pack.CATALYST_CHILL, Pack.CATALYST_PROPELLANT]

## Fortschrittsstufe, ab der eine Wette ohne eigenen "unlock" ausliegt: ab Runde 1.
const UNLOCK_BASE := 1

## Eine "volle" Hand nutzt alle sechs Würfel der Grube.
const FULL_HAND_DICE := 6

## Oberklasse: so viele Würfel muss die Hand werten, jeder mit so vielen Augen.
const HIGH_DICE_MIN := 3
const HIGH_DICE_EYES := 6

var id: String = ""
var condition: int = Condition.COMBO
var target: int = 0             # HAND_SCORE: Punkte; FEW_DICE: max. Würfel; ...
var target_combo: String = ""   # COMBO: DiceScoring-Kategorie-Key
## > 0: target wird beim Auslegen aus der Quota gerechnet (siehe _nice_target).
var target_factor: float = 0.0
var stake_kind: int = Stake.MONEY
var stake: int = 0              # Geld-Einsatz (einmalig bzw. je Hand/Würfel)
var stake_packs: int = 0           # nur Stake.PACKS: Anzahl geopferter Pakete
## Und WELCHE Pakete: Sorte und Größe, beim Auslegen aus dem BESITZ des Spielers
## gezogen (nie frei gewürfelt) - verzehrt wird genau, was der Knopf nennt.
var stake_pack_type: String = Pack.TYPE_NUMBER
var stake_pack_tier: int = Pack.TIER_NORMAL
var stake_energy: int = 0          # nur Stake.ENERGY: Energie (⚡)
var odds: float = ODDS_MEDIUM
var payout_kind: int = Payout.MONEY
## Sorte der Regal-Karten (Payout.PACKS); Größe und Zahl folgen dem Gewinnwert.
var reward_pack_type: String = Pack.TYPE_NUMBER
var special_id: String = ""    # nur Payout.SPECIAL: Engraving.SPECIAL_IDS
## CATALYST: Katalysator-id, OPERATOR: Operator-id - beim Auslegen festgelegt.
var reward_item_id: String = ""
## nur Payout.PART: das Modul, beim Auswürfeln der Auslage festgelegt.
var reward_part_id: String = ""
## nur Payout.CARD_PACK/DICE_PACK: die Paket-Sorte; die Größe folgt dem Gewinnwert.
var reward_card_pack_sort: String = CardPack.SORT_NUMBER
var reward_dice_pack_sort: String = DicePack.SORT_MIXED
var unlock_level: int = UNLOCK_BASE
var display_name: String = ""
var description: String = ""
## Zahlungsunfähig geworden (Steuer nicht mehr bezahlbar) - die Wette ist tot.
var voided: bool = false
## Was ein PACK-Gewinn tatsächlich ausgeschüttet hat (die Zeremonie liest die
## Sorte für ihren Farbton).
var awarded_pack: Pack = null
## ALLE bei der Abrechnung gewährten Pakete dieser Wette - die Auszahlungs-Seite
## hält genau diese Kassetten bis zum Kassieren zurück und zielt dann auf ihre uids.
var awarded_packs: Array[Pack] = []
## Und wie viele davon am vollen Magazin zu Geld zerfallen sind.
var awarded_fizzled: int = 0
## Der gewonnene Würfel, wie er im Ausgabefach wartet (Payout.DIE).
var awarded_die: DieDefinition = null
## Das gewonnene Paket (CARD_PACK/DICE_PACK): im Lager - oder, war es voll, sofort geöffnet.
var awarded_stored: Resource = null
var awarded_choice: PackChoice = null
## Was der Einsatz WIRKLICH gekostet hat - die Rückversicherung gibt genau das zurück.
var paid_money: int = 0
var paid_energy: int = 0
var paid_packs: Array[Pack] = []
## Lauf-Daten für den Würfel-Gewinn (charm_ids, owned_essences, tier).
var _context: Dictionary = {}
var _rolled_cards: Dictionary = {}  # Größe -> gewürfelte Karten
var _card_packs: Dictionary = {}  # Paketgröße -> CardPack bzw. DicePack
var _fixed_card: Pack = null
var _reward_die: DieDefinition = null
var _die_rarity: int = -2

## Merkt EIN gewährtes Paket (null = am vollen Magazin zerfallen, wird gezählt).
func note_awarded(pack: Pack) -> void:
	if pack != null:
		awarded_packs.append(pack)
	else:
		awarded_fizzled += 1

## Vorlagen der Auslage (id -> Parameter). Fehlende Schlüssel = Standard
## (Geld-Einsatz, Quote mittel, unlock UNLOCK_BASE). Die WARE würfelt das Auslegen.
## desc = NUR die Gewinnbedingung; Einsatz und Gewinn stehen bereits auf dem Knopf.
## Mit target_factor ist desc ein Formatstring: die Quota füllt die Zahl.
const TEMPLATES := [
	# --- Grundstock (ab UNLOCK_BASE) ---
	{"id": "two_pair", "condition": Condition.COMBO, "combo": DiceScoring.TWO_PAIR,
		"stake": 4, "odds": ODDS_EASY, "name": "Doppelspiel",
		"desc": "Nimm zwei Paare oder besser."},
	{"id": "full_house", "condition": Condition.COMBO, "combo": DiceScoring.FULL_HOUSE,
		"stake": 6, "odds": ODDS_MEDIUM, "name": "Volles Haus",
		"desc": "Nimm ein Full House oder besser."},
	{"id": "large_straight", "condition": Condition.COMBO, "combo": DiceScoring.LARGE_STRAIGHT,
		"stake": 9, "odds": ODDS_HARD, "name": "Die lange Reihe",
		"desc": "Nimm eine Große Straße."},
	{"id": "big_hand", "condition": Condition.HAND_SCORE, "target_factor": 1.0,
		"stake": 6, "odds": ODDS_MEDIUM, "name": "Großer Wurf",
		"desc": "Werte eine einzelne Hand mit %d+ Punkten."},
	{"id": "economist", "condition": Condition.FEW_DICE, "target": 9,
		"stake": 6, "odds": ODDS_MEDIUM, "name": "Sparsam",
		"desc": "Räume die Runde mit höchstens 9 genommenen Würfeln."},
	{"id": "jackpot", "condition": Condition.COMBO, "combo": DiceScoring.FULL_HOUSE,
		"stake": 6, "odds": ODDS_MEDIUM, "name": "Jackpot",
		"desc": "Nimm ein Full House oder besser."},
	{"id": "pawn", "condition": Condition.NO_FARKLE, "stake_kind": Stake.PACKS, "stake_packs": 1,
		"odds": ODDS_MEDIUM, "name": "Pfandleihe",
		"desc": "Räume die Runde ohne Fumble."},
	{"id": "clean_run", "condition": Condition.NO_FARKLE, "stake_kind": Stake.PACKS, "stake_packs": 1,
		"odds": ODDS_MEDIUM, "name": "Saubere Runde",
		"desc": "Räume die Runde ohne Fumble."},
	{"id": "chain_reaction", "condition": Condition.COMBO, "combo": DiceScoring.LARGE_STRAIGHT,
		"stake": 8, "odds": ODDS_HARD, "name": "Kettenreaktion",
		"desc": "Nimm eine Große Straße."},
	{"id": "tinkerer", "condition": Condition.DISTINCT_COMBOS, "target": 3,
		"stake": 7, "odds": ODDS_MEDIUM, "name": "Bastler",
		"desc": "Nimm drei verschiedene Kombinationen."},
	# --- Salon (5) ---
	{"id": "high_roller", "condition": Condition.HAND_SCORE, "target_factor": 2.0,
		"stake": 10, "odds": ODDS_HARD, "name": "Hoher Einsatz",
		"unlock": 5, "desc": "Werte eine Hand mit %d+ Punkten."},
	{"id": "prototype", "condition": Condition.HAND_SCORE, "target_factor": 1.5,
		"stake": 9, "odds": ODDS_MEDIUM, "name": "Prototyp",
		"unlock": 5, "desc": "Werte eine Hand mit %d+ Punkten."},
	{"id": "quick_start", "condition": Condition.FIRST_HAND, "target_factor": 0.6,
		"stake": 5, "odds": ODDS_MEDIUM, "name": "Blitzstart", "unlock": 5,
		"desc": "Werte schon die erste Hand mit %d+ Punkten."},
	{"id": "overclocker", "condition": Condition.OVERCHARGE, "target": 2,
		"stake": 6, "odds": ODDS_MEDIUM, "name": "Übertakter", "unlock": 5,
		"desc": "Räume mindestens zwei Überladungs-Stufen."},
	{"id": "table_fee", "condition": Condition.CLEARED,
		"stake_kind": Stake.MONEY_PER_HAND, "stake": 3, "odds": ODDS_EASY, "name": "Tischgebühr",
		"unlock": 5, "desc": "Räume die Runde - jede genommene Hand kostet."},
	# --- VIP-Lounge (6) ---
	{"id": "collateral", "condition": Condition.HAND_SCORE, "target_factor": 1.3,
		"stake_kind": Stake.PACKS, "stake_packs": 2, "odds": ODDS_MEDIUM, "name": "Sicherheit",
		"unlock": 6, "desc": "Werte eine Hand mit %d+ Punkten."},
	{"id": "resupply", "condition": Condition.COMBO, "combo": DiceScoring.LARGE_STRAIGHT,
		"stake_kind": Stake.PACKS, "stake_packs": 1, "odds": ODDS_HARD, "name": "Nachschub",
		"unlock": 6, "desc": "Nimm eine Große Straße."},
	{"id": "connoisseur", "condition": Condition.DISTINCT_COMBOS, "target": 3,
		"stake": 6, "odds": ODDS_MEDIUM, "name": "Kenner", "unlock": 6,
		"desc": "Nimm drei verschiedene Kombinationen."},
	{"id": "upper_class", "condition": Condition.HIGH_DICE,
		"stake": 6, "odds": ODDS_MEDIUM, "name": "Oberklasse",
		"unlock": 6, "desc": "Werte eine Hand aus mindestens drei Würfeln mit je 6+ Augen."},
	{"id": "dice_toll", "condition": Condition.CLEARED,
		"stake_kind": Stake.MONEY_PER_DIE, "stake": 1, "odds": ODDS_EASY, "name": "Würfelzoll",
		"unlock": 6, "desc": "Räume die Runde - jeder genommene Würfel kostet Zoll."},
	{"id": "variety", "condition": Condition.NO_REPEAT,
		"stake": 5, "odds": ODDS_MEDIUM, "name": "Abwechslung",
		"unlock": 6, "desc": "Nimm keine Kombination zweimal."},
	# --- Suite (7) ---
	{"id": "efficiency", "condition": Condition.HAND_LIMIT, "target": 3,
		"stake": 8, "odds": ODDS_HARD, "name": "Effizienz", "unlock": 7,
		"desc": "Räume die Runde mit höchstens drei Händen."},
	{"id": "comeback", "condition": Condition.COMEBACK,
		"stake": 4, "odds": ODDS_MEDIUM, "name": "Comeback",
		"unlock": 7, "desc": "Räume die Runde nach einem Fumble."},
	{"id": "small_fry", "condition": Condition.MAX_HAND_DICE, "target": 3,
		"stake": 7, "odds": ODDS_HARD, "name": "Kleinvieh", "unlock": 7,
		"desc": "Nimm keine Hand aus mehr als drei Würfeln."},
	# --- Penthouse (8) ---
	{"id": "deep_energy", "condition": Condition.OVERCHARGE, "target": 4,
		"stake_kind": Stake.PACKS, "stake_packs": 1, "odds": ODDS_HARD,
		"name": "Tiefenladung", "unlock": 8,
		"desc": "Räume mindestens vier Überladungs-Stufen."},
	{"id": "blank_check", "condition": Condition.FIRST_HAND, "target_factor": 1.2,
		"stake": 12, "odds": ODDS_HARD, "name": "Blankoscheck",
		"unlock": 8, "desc": "Werte schon die erste Hand mit %d+ Punkten."},
	{"id": "feedback_loop", "condition": Condition.OVERCHARGE, "target": 3,
		"stake_kind": Stake.ENERGY, "stake_energy": 4, "odds": ODDS_MEDIUM,
		"name": "Rückkopplung", "unlock": 8,
		"desc": "Räume mindestens drei Überladungs-Stufen."},
	{"id": "patent", "condition": Condition.COMBO, "combo": DiceScoring.FULL_HOUSE,
		"stake": 12, "odds": ODDS_MEDIUM, "name": "Patent", "unlock": 8,
		"desc": "Nimm ein Full House oder besser."},
	# --- Privatclub (9) ---
	{"id": "collector", "condition": Condition.DISTINCT_COMBOS, "target": 5,
		"stake_kind": Stake.PACKS, "stake_packs": 1, "odds": ODDS_HARD,
		"name": "Sammler", "unlock": 9,
		"desc": "Nimm fünf verschiedene Kombinationen."},
	{"id": "whale", "condition": Condition.HAND_SCORE, "target_factor": 2.5,
		"stake": 25, "odds": ODDS_HARD, "name": "Der Wal",
		"unlock": 9, "desc": "Werte eine Hand mit %d+ Punkten."},
	{"id": "shipment", "condition": Condition.FEW_DICE, "target": 8,
		"stake": 10, "odds": ODDS_HARD, "name": "Warensendung", "unlock": 9,
		"desc": "Räume die Runde mit höchstens 8 genommenen Würfeln."},
	{"id": "full_grip", "condition": Condition.FULL_HANDS,
		"stake_kind": Stake.PACKS, "stake_packs": 1, "odds": ODDS_HARD,
		"name": "Vollgriff", "unlock": 9,
		"desc": "Nimm jede Hand mit allen sechs Würfeln."},
	# --- High Roller (10): die Sonderposten - sie behalten ihren FESTEN Gewinn ---
	{"id": "circuit_contract", "condition": Condition.OVERCHARGE, "target": 5,
		"stake": 20, "odds": ODDS_HARD, "payout": Payout.SPECIAL, "special": Engraving.POINTER,
		"name": "Platinenauftrag", "unlock": 10,
		"desc": "Räume mindestens fünf Überladungs-Stufen."},
	{"id": "clean_room", "condition": Condition.HAND_SCORE, "target_factor": 2.0,
		"stake": 20, "odds": ODDS_HARD, "payout": Payout.SPECIAL, "special": Engraving.DOPING,
		"name": "Reinraum", "unlock": 10,
		"desc": "Werte eine Hand mit %d+ Punkten."},
	{"id": "all_in_hand", "condition": Condition.HAND_LIMIT, "target": 1,
		"stake": 15, "odds": ODDS_HARD, "name": "Alles auf eine Hand", "unlock": 10,
		"desc": "Räume die Runde mit einer einzigen Hand."},
]


## Kleinstes ausgelegtes Punktziel.
const MIN_TARGET := 25

## Rundet ein aus der Quota gerechnetes Punktziel auf eine lesbare Zahl:
## unter 1000 auf 25er, darüber auf 100er - eine "1137" auf dem Knopf sähe aus
## wie ein Rechenfehler.
static func _nice_target(raw: float) -> int:
	var step := 100 if raw >= 1000.0 else MIN_TARGET
	return maxi(MIN_TARGET, roundi(raw / float(step)) * step)

## quota = die GESPEICHERTE Rundenquota (nicht effective_goal): eine
## erst nach der Wettannahme unterschriebene Klausel darf ein aufgedrucktes Ziel
## nicht mehr verschieben. context = Lauf-Daten für den Würfel-Gewinn
## (GameRun.side_bet_context).
static func _from_template(t: Dictionary, quota: int = 0, context: Dictionary = {}) -> SideBet:
	var bet := SideBet.new()
	bet.id = t["id"]
	bet.condition = t["condition"]
	bet.target = int(t.get("target", 0))
	bet.target_combo = t.get("combo", "")
	bet.target_factor = float(t.get("target_factor", 0.0))
	bet.stake_kind = int(t.get("stake_kind", Stake.MONEY))
	bet.stake = int(t.get("stake", 0))
	bet.stake_packs = int(t.get("stake_packs", 0))
	bet.stake_energy = int(t.get("stake_energy", 0))
	bet.odds = float(t.get("odds", ODDS_MEDIUM))
	bet.special_id = t.get("special", "")
	bet.unlock_level = int(t.get("unlock", UNLOCK_BASE))
	bet.display_name = t["name"]
	bet.description = t["desc"]
	if bet.target_factor > 0.0:
		bet.target = _nice_target(float(quota) * bet.target_factor)
		bet.description = t["desc"] % bet.target
	bet._context = context
	if t.has("payout"):
		bet.payout_kind = int(t["payout"])
	else:
		bet.roll_reward()
	return bet

## Der Schlüssel der Inventar-Sicht: Sorte plus Größe. EINE Schreibweise, an der
## GameRun.pack_stock und _name_stake_packs hängen.
static func pack_stock_key(pack_type: String, pack_tier: int) -> String:
	return "%s|%d" % [pack_type, pack_tier]

## Würfelt count verschiedene Wett-Angebote aus (ohne Zurücklegen). tier
## filtert die Auslage (jede Vorlage hat ihre Freischalt-Stufe), quota füllt
## die skalierten Punktziele - beide werden HIER eingefroren. stock ist die
## Inventar-Sicht des Magazins (GameRun.pack_stock, reine Daten): eine
## Paket-Einsatz-Vorlage liegt nur aus, wenn der Spieler die genannte Ware WIRKLICH
## besitzt - sonst rückt die nächste Vorlage nach.
static func roll_offers(count: int, tier: int, quota: int,
		stock: Dictionary = {}, context: Dictionary = {}) -> Array[SideBet]:
	var templates: Array = []
	for t: Dictionary in TEMPLATES:
		if int(t.get("unlock", UNLOCK_BASE)) <= tier:
			templates.append(t)
	templates.shuffle()
	var bets: Array[SideBet] = []
	for t: Dictionary in templates:
		if bets.size() >= count:
			break
		var bet := _from_template(t, quota, context)
		if bet.stake_kind == Stake.PACKS:
			if not _name_stake_packs(bet, stock):
				continue
			if not t.has("payout"):
				bet.roll_reward()  # der Einsatzwert steht erst jetzt fest
		bets.append(bet)
	return bets

## Sucht dem Paket-Einsatz seine konkrete Sorte und Größe aus dem BESITZ. false =
## der Spieler hat nichts, was reicht; dann fällt die Vorlage aus der Auslage.
static func _name_stake_packs(bet: SideBet, stock: Dictionary) -> bool:
	var fits: Array[String] = []
	for key: String in stock:
		if int(stock[key]) >= bet.stake_packs:
			fits.append(key)
	if fits.is_empty():
		return false
	fits.sort()  # ohne feste Reihenfolge hinge der Griff an der Dictionary-Laune
	var pick: String = fits.pick_random()
	bet.stake_pack_type = pick.get_slice("|", 0)
	bet.stake_pack_tier = int(pick.get_slice("|", 1))
	return true

# --- Der GEWINNWERT -----------------------------------------------------------

## Was der Einsatz in $ wert ist - aus dem UNBESTEUERTEN Grund-Einsatz.
func stake_value() -> int:
	match stake_kind:
		Stake.PACKS:
			return Pack.tier_price(Pack.type_price(stake_pack_type), stake_pack_tier) * stake_packs
		Stake.MONEY_PER_HAND:
			return stake * PER_HAND_HANDS
		Stake.MONEY_PER_DIE:
			return stake * PER_DIE_DICE
		Stake.ENERGY:
			return stake_energy * ENERGY_STAKE_MONEY
	return stake

func pays_money() -> bool:
	return payout_kind == Payout.MONEY

## Der Gewinnwert in $: Einsatzwert × Quote × factor (Quotenbonus, Hoher Tisch),
## als Ware ×1,25.
func payout_value(factor: float = 1.0) -> int:
	var value := float(stake_value()) * odds * factor
	if not pays_money():
		value *= WARE_BONUS
	return roundi(value)

## Würfelt die WARE aus dem Gewinnwert (Grundwert, ohne Faktor) - danach steht sie.
func roll_reward() -> void:
	var money := roundi(float(stake_value()) * odds)
	var ware := roundi(float(stake_value()) * odds * WARE_BONUS)
	var pool: Array[Dictionary] = []
	for entry: Dictionary in WARES:
		var kind := int(entry["kind"])
		if kind == Payout.MONEY:
			if money >= int(entry["min"]):
				pool.append(entry)
		elif ware >= int(entry["min"]) and _ware_fits(kind, ware):
			pool.append(entry)
	var pick := _pick_ware(pool)
	payout_kind = int(pick.get("kind", Payout.MONEY))
	reward_pack_type = String(pick.get("type", Pack.TYPE_NUMBER))
	_rolled_cards.clear()
	_fixed_card = null
	_reward_die = null
	_die_rarity = -2
	match payout_kind:
		Payout.CATALYST:
			reward_item_id = String(_affordable_ids(BET_CATALYSTS, ware, true).pick_random())
		Payout.OPERATOR:
			reward_item_id = String(_affordable_ids(StampNet.OPERATORS.keys(), ware, false).pick_random())
		Payout.PART:
			reward_part_id = ComboPart.pick_weighted(_affordable_parts(ware)).id
		Payout.PACK:
			_fixed_card = Pack.roll_special_pack()
		Payout.CARD_PACK:
			_card_packs.clear()
			reward_card_pack_sort = String(_pick_pack_sort(CARD_PACK_SORT_WEIGHTS, ware, false))
		Payout.DICE_PACK:
			_card_packs.clear()
			reward_dice_pack_sort = String(_pick_pack_sort(DICE_PACK_SORT_WEIGHTS, ware, true))

## Gibt es für diese Art überhaupt eine Ware bis zu diesem Wert?
func _ware_fits(kind: int, ware: int) -> bool:
	match kind:
		Payout.CATALYST:
			return not _affordable_ids(BET_CATALYSTS, ware, true).is_empty()
		Payout.OPERATOR:
			return not _affordable_ids(StampNet.OPERATORS.keys(), ware, false).is_empty()
		Payout.PART:
			return not _affordable_parts(ware).is_empty()
		Payout.CARD_PACK:
			return not _affordable_pack_sorts(CARD_PACK_SORT_WEIGHTS, ware, false).is_empty()
		Payout.DICE_PACK:
			return not _affordable_pack_sorts(DICE_PACK_SORT_WEIGHTS, ware, true).is_empty()
	return true

static func _pack_price(pack_sort: String, pack_size: int, dice: bool) -> int:
	return DicePack.price_of(pack_sort, pack_size) if dice 		else CardPack.price_of(pack_sort, pack_size)

## Die Paket-Sorten, deren kleinstes Paket der Wert trägt.
static func _affordable_pack_sorts(weights: Dictionary, ware: int, dice: bool) -> Array:
	var out: Array = []
	for pack_sort: String in weights:
		if _pack_price(pack_sort, CardPack.SIZE_SMALL, dice) <= ware:
			out.append(pack_sort)
	out.sort()
	return out

static func _pick_pack_sort(weights: Dictionary, ware: int, dice: bool) -> String:
	var sorts := _affordable_pack_sorts(weights, ware, dice)
	if sorts.is_empty():
		return DicePack.SORT_MIXED if dice else CardPack.SORT_NUMBER
	var total := 0
	for pack_sort: String in sorts:
		total += int(weights[pack_sort])
	var pick := randi() % total
	for pack_sort: String in sorts:
		pick -= int(weights[pack_sort])
		if pick < 0:
			return pack_sort
	return String(sorts.back())

## Die größte Größe der Sorte, deren Preis der Gewinnwert trägt.
func _reward_pack_size(pack_sort: String, factor: float, dice: bool) -> int:
	var value := payout_value(factor)
	for candidate in range(CardPack.SIZE_HUGE, CardPack.SIZE_SMALL, -1):
		if _pack_price(pack_sort, candidate, dice) <= value:
			return candidate
	return CardPack.SIZE_SMALL

## Das gewonnene KARTEN-PAKET. Je Größe einmal gebaut, damit Knopf, Grube und
## Abrechnung dasselbe meinen.
func reward_card_pack(factor: float = 1.0) -> CardPack:
	if payout_kind != Payout.CARD_PACK:
		return null
	var pack_size := _reward_pack_size(reward_card_pack_sort, factor, false)
	if not _card_packs.has(pack_size):
		_card_packs[pack_size] = CardPack.make(reward_card_pack_sort, pack_size)
	return _card_packs[pack_size]

## Das gewonnene WÜRFEL-PAKET: das teuerste bezahlbare Paar aus Größe und Güte
## (gleicher Preis: die größere Größe). Je Paar einmal gebaut.
func reward_dice_pack(factor: float = 1.0) -> DicePack:
	if payout_kind != Payout.DICE_PACK:
		return null
	var pair := reward_dice_pair(reward_dice_pack_sort, payout_value(factor))
	var key := Vector2i(pair.x, pair.y)
	if not _card_packs.has(key):
		_card_packs[key] = DicePack.make(reward_dice_pack_sort, pair.x, pair.y)
	return _card_packs[key]

## (Größe, Güte) des teuersten Würfel-Pakets bis zu diesem Wert; keines: Klein/Standard.
static func reward_dice_pair(pack_sort: String, value: int) -> Vector2i:
	var best := Vector2i(CardPack.SIZE_SMALL, DicePack.QUALITY_STANDARD)
	var best_price := -1
	for pack_size in CardPack.SIZES:
		for pack_quality in DicePack.QUALITIES:
			var price := DicePack.price_of(pack_sort, pack_size, pack_quality)
			if price <= value and price >= best_price:
				best = Vector2i(pack_size, pack_quality)
				best_price = price
	return best

static func _affordable_ids(ids: Array, ware: int, catalysts: bool) -> Array:
	var out: Array = []
	for item_id in ids:
		var price := Pack.catalyst_price(item_id) if catalysts \
			else StampNet.operator_price(item_id)
		if price <= ware:
			out.append(item_id)
	return out

static func _affordable_parts(ware: int) -> Array[ComboPart]:
	var out: Array[ComboPart] = []
	for part in ComboPart.pool(false):
		if part.price <= ware:
			out.append(part)
	return out

static func _pick_ware(pool: Array[Dictionary]) -> Dictionary:
	var total := 0
	for entry in pool:
		total += int(entry["weight"])
	if total <= 0:
		return {"kind": Payout.MONEY}
	var pick := randi() % total
	for entry in pool:
		pick -= int(entry["weight"])
		if pick < 0:
			return entry
	return pool.back()

## Preis EINER Karte der gewürfelten Sorte in dieser Größe.
func card_price(pack_tier: int) -> int:
	var base := Pack.MULTIPLIER_PRICE if payout_kind == Payout.MULTIPLIER \
		else Pack.type_price(reward_pack_type)
	return Pack.tier_price(base, pack_tier)

## Die größte Größe, deren Preis der Gewinnwert trägt (Regal- und Multiplikator-Karten).
func reward_tier(factor: float = 1.0) -> int:
	var value := payout_value(factor)
	for pack_tier in range(Pack.TIER_KOLOSSAL, Pack.TIER_NORMAL, -1):
		if card_price(pack_tier) <= value:
			return pack_tier
	return Pack.TIER_NORMAL

## Wie viele Karten: was der Wert in dieser Größe kauft, höchstens MAX_REWARD_CARDS.
func reward_count(factor: float = 1.0) -> int:
	match payout_kind:
		Payout.PACKS, Payout.MULTIPLIER:
			var price := maxi(card_price(reward_tier(factor)), 1)
			return clampi(payout_value(factor) / price, 1, MAX_REWARD_CARDS)
		Payout.SPECIAL, Payout.PACK, Payout.CATALYST, Payout.OPERATOR, Payout.CARD_PACK, 				Payout.DICE_PACK:
			return 1
	return 0

## Der Bargewinn (Payout.MONEY) vor dem Quotenblatt.
func reward_money(factor: float = 1.0) -> int:
	return payout_value(factor) if payout_kind == Payout.MONEY else 0

## Der Energie-Gewinn (Payout.ENERGY).
func reward_energy(factor: float = 1.0) -> int:
	return payout_value(factor) / ENERGY_PRICE if payout_kind == Payout.ENERGY else 0

## Prüft die Wette gegen die Rundenbilanz (siehe scene_root._round_result).
## Eine nicht geräumte Runde (Game Over) und eine verfallene Wette verlieren immer.
func evaluate(result: Dictionary) -> bool:
	if voided or not result.get("cleared", false):
		return false
	match condition:
		Condition.COMBO:
			return int(result.get("best_combo_rank", -1)) >= combo_rank(target_combo)
		Condition.HAND_SCORE:
			return int(result.get("best_hand_score", 0)) >= target
		Condition.FEW_DICE:
			return int(result.get("dice_taken", 9999)) <= target
		Condition.NO_FARKLE:
			return not bool(result.get("farkled", true))
		Condition.FIRST_HAND:
			return int(result.get("first_hand_score", 0)) >= target
		Condition.OVERCHARGE:
			return int(result.get("stages_cleared", 0)) >= target
		Condition.DISTINCT_COMBOS:
			return int(result.get("distinct_combos", 0)) >= target
		Condition.HAND_LIMIT:
			return int(result.get("hands_taken", 9999)) <= target
		Condition.COMEBACK:
			return bool(result.get("farkled", false))
		Condition.HIGH_DICE:
			return bool(result.get("high_hand", false))
		Condition.CLEARED:
			return true
		Condition.MAX_HAND_DICE:
			return int(result.get("max_hand_dice", 0)) <= target
		Condition.FULL_HANDS:
			return int(result.get("hands_taken", 0)) >= 1 \
				and int(result.get("min_hand_dice", 0)) >= FULL_HAND_DICE
		Condition.NO_REPEAT:
			return not bool(result.get("combo_repeated", false))
	return false

## Rang einer Kombination: höher = seltener/besser. Über HAND_PRIORITY
## abgeleitet (Index 0 = beste), damit ">= rank" einen "oder besser"-Vergleich ist.
static func combo_rank(key: String) -> int:
	var index := DiceScoring.HAND_PRIORITY.find(key)
	if index == -1:
		return -1
	return DiceScoring.HAND_PRIORITY.size() - index

## Live-Zustand während der Runde (für die Fortschrittsanzeige): PENDING = noch
## offen, ON_TRACK = aktuell erfüllt, FAILED = nicht mehr erreichbar.
enum Live { PENDING, ON_TRACK, FAILED }

## result trägt dieselben Schlüssel wie evaluate(), aber ohne "cleared" (die
## Runde läuft noch). Siehe scene_root._refresh_side_bet_panel.
func live_state(result: Dictionary) -> int:
	if voided:
		return Live.FAILED  # zahlungsunfähig - die Steuer hat die Wette gerissen
	match condition:
		Condition.COMBO:
			return Live.ON_TRACK if int(result.get("best_combo_rank", -1)) >= combo_rank(target_combo) else Live.PENDING
		Condition.HAND_SCORE:
			return Live.ON_TRACK if int(result.get("best_hand_score", 0)) >= target else Live.PENDING
		Condition.FEW_DICE:
			return Live.FAILED if int(result.get("dice_taken", 0)) > target else Live.ON_TRACK
		Condition.NO_FARKLE:
			return Live.FAILED if bool(result.get("farkled", false)) else Live.ON_TRACK
		Condition.FIRST_HAND:
			# Vor der ersten Hand offen, danach endgültig entschieden.
			if int(result.get("hands_taken", 0)) <= 0:
				return Live.PENDING
			return Live.ON_TRACK if int(result.get("first_hand_score", 0)) >= target else Live.FAILED
		Condition.OVERCHARGE:
			return Live.ON_TRACK if int(result.get("stages_cleared", 0)) >= target else Live.PENDING
		Condition.DISTINCT_COMBOS:
			return Live.ON_TRACK if int(result.get("distinct_combos", 0)) >= target else Live.PENDING
		Condition.HAND_LIMIT:
			return Live.FAILED if int(result.get("hands_taken", 0)) > target else Live.ON_TRACK
		Condition.COMEBACK:
			return Live.ON_TRACK if bool(result.get("farkled", false)) else Live.PENDING
		Condition.HIGH_DICE:
			return Live.ON_TRACK if bool(result.get("high_hand", false)) else Live.PENDING
		Condition.CLEARED:
			return Live.ON_TRACK
		Condition.MAX_HAND_DICE:
			return Live.FAILED if int(result.get("max_hand_dice", 0)) > target else Live.ON_TRACK
		Condition.FULL_HANDS:
			return Live.FAILED if int(result.get("min_hand_dice", FULL_HAND_DICE)) < FULL_HAND_DICE else Live.ON_TRACK
		Condition.NO_REPEAT:
			return Live.FAILED if bool(result.get("combo_repeated", false)) else Live.ON_TRACK
	return Live.PENDING

## Kann diese Wette schon MITTEN in der Runde erfüllt sein? Genau die Bedingungen,
## deren live_state offen beginnt und dann auf ON_TRACK kippt - die übrigen lauten
## bloß "noch nicht gescheitert" und entscheiden sich erst am Rundenende. Abgeleitet
## aus derselben EINEN Fortschritts-Rechnung (leere Bilanz = nichts ist geschehen),
## damit es keine zweite Bedingungs-Auswertung gibt.
func decides_early() -> bool:
	return live_state({}) == Live.PENDING

## Balkenfüllung 0..1 (binäre Bedingungen liefern 0 oder 1).
func progress_fraction(result: Dictionary) -> float:
	match condition:
		Condition.COMBO:
			return 1.0 if int(result.get("best_combo_rank", -1)) >= combo_rank(target_combo) else 0.0
		Condition.HAND_SCORE:
			return _ratio(int(result.get("best_hand_score", 0)))
		Condition.FEW_DICE:
			return _ratio(int(result.get("dice_taken", 0)))
		Condition.NO_FARKLE:
			return 1.0
		Condition.FIRST_HAND:
			return _ratio(int(result.get("first_hand_score", 0)))
		Condition.OVERCHARGE:
			return _ratio(int(result.get("stages_cleared", 0)))
		Condition.DISTINCT_COMBOS:
			return _ratio(int(result.get("distinct_combos", 0)))
		Condition.HAND_LIMIT:
			return _ratio(int(result.get("hands_taken", 0)))
		Condition.COMEBACK:
			return 1.0 if bool(result.get("farkled", false)) else 0.0
		Condition.HIGH_DICE:
			return 1.0 if bool(result.get("high_hand", false)) else 0.0
		Condition.CLEARED:
			return 1.0
		Condition.MAX_HAND_DICE:
			return _ratio(int(result.get("max_hand_dice", 0)))
		Condition.FULL_HANDS:
			return 0.0 if int(result.get("min_hand_dice", FULL_HAND_DICE)) < FULL_HAND_DICE else 1.0
		Condition.NO_REPEAT:
			return 0.0 if bool(result.get("combo_repeated", false)) else 1.0
	return 0.0

func _ratio(value: int) -> float:
	return clampf(float(value) / float(maxi(target, 1)), 0.0, 1.0)

## Kurzer Fortschrittstext für die Anzeige.
func status_label(result: Dictionary) -> String:
	match condition:
		Condition.COMBO:
			var met := int(result.get("best_combo_rank", -1)) >= combo_rank(target_combo)
			return "%s%s" % [DiceScoring.label_for(target_combo), " ✓" if met else ""]
		Condition.HAND_SCORE:
			return "%d / %d" % [int(result.get("best_hand_score", 0)), target]
		Condition.FEW_DICE:
			return "%d / %d Würfel" % [int(result.get("dice_taken", 0)), target]
		Condition.NO_FARKLE:
			return "Fumble!" if bool(result.get("farkled", false)) else "sauber"
		Condition.FIRST_HAND:
			if int(result.get("hands_taken", 0)) <= 0:
				return "offen / %d" % target
			return "%d / %d" % [int(result.get("first_hand_score", 0)), target]
		Condition.OVERCHARGE:
			return "%d / %d Stufen" % [int(result.get("stages_cleared", 0)), target]
		Condition.DISTINCT_COMBOS:
			return "%d / %d Sorten" % [int(result.get("distinct_combos", 0)), target]
		Condition.HAND_LIMIT:
			return "%d / %d Hände" % [int(result.get("hands_taken", 0)), target]
		Condition.COMEBACK:
			return "Fumble ✓" if bool(result.get("farkled", false)) else "noch kein Fumble"
		Condition.HIGH_DICE:
			return "erreicht" if bool(result.get("high_hand", false)) else "offen"
		Condition.CLEARED:
			return "läuft"
		Condition.MAX_HAND_DICE:
			return "max. %d / %d" % [int(result.get("max_hand_dice", 0)), target]
		Condition.FULL_HANDS:
			return "zu klein" if int(result.get("min_hand_dice", FULL_HAND_DICE)) < FULL_HAND_DICE else "voll"
		Condition.NO_REPEAT:
			return "Dublette!" if bool(result.get("combo_repeated", false)) else "verschieden"
	return ""

## Die GEWINN-KARTEN samt Prägenetz, je Größe einmal gewürfelt und dann fest: die
## Grube zeigt genau die Karten, die die Abrechnung gewährt. factor (Quotenbonus,
## Hoher Tisch) hebt den Wert - mehr Karten oder eine größere.
func reward_cards(factor: float = 1.0) -> Array[Pack]:
	var out: Array[Pack] = []
	match payout_kind:
		Payout.PACKS, Payout.MULTIPLIER:
			var pack_tier := reward_tier(factor)
			var count := reward_count(factor)
			var cards: Array = _rolled_cards.get(pack_tier, [])
			while cards.size() < count:
				var base := Pack.multiplier_pack() if payout_kind == Payout.MULTIPLIER \
					else Pack.by_type(reward_pack_type)
				cards.append(Pack.tiered(base, pack_tier))
			_rolled_cards[pack_tier] = cards
			for i in count:
				out.append(cards[i])
		Payout.SPECIAL, Payout.PACK, Payout.CATALYST, Payout.OPERATOR:
			var card := _single_card()
			if card != null:
				out.append(card)
	return out

## Der EINE feste Karten-Gewinn (Sonderposten, Katalysator, Operator).
func _single_card() -> Pack:
	if _fixed_card != null:
		return _fixed_card
	match payout_kind:
		Payout.SPECIAL:
			var special := special_engraving()
			if special != null:
				_fixed_card = Pack.fixed_engraving_pack(special)
		Payout.CATALYST:
			_fixed_card = Pack.catalyst(reward_item_id)
		Payout.OPERATOR:
			_fixed_card = Pack.operator_pack(reward_item_id)
	return _fixed_card

## Zählt die Grube als KARTEN? Jede Karten-Art ja, Geld, Energie, Modul, Würfel nicht.
func pays_cards() -> bool:
	return payout_kind in [Payout.PACKS, Payout.PACK, Payout.SPECIAL, Payout.CATALYST,
		Payout.OPERATOR, Payout.MULTIPLIER]

## Die Magazin-Sorte der Gewinn-Karten (für Körper und Sammel-Zeile).
func reward_shelf(factor: float = 1.0) -> String:
	var cards := reward_cards(factor)
	if cards.is_empty():
		return Pack.shelf_for_pack_type(reward_pack_type)
	return Pack.shelf_of(cards[0])

## Das gewonnene Modul, frisch (null = keins benannt).
func reward_part() -> ComboPart:
	return ComboPart.make(reward_part_id)

## Die Sonderposten-Gravur eines SPECIAL-Gewinns (null, wenn keine id steht).
func special_engraving() -> Engraving:
	if special_id == "":
		return null
	for engraving in Engraving.all():
		if engraving.id == special_id:
			return engraving
	return null

## Der gewonnene WÜRFEL: seine Seele hängt am Gewinnwert. Gewürfelt wird je
## Seelen-Stufe einmal - ein Quotenbonus kann ihn also noch heben.
func reward_die(factor: float = 1.0) -> DieDefinition:
	if payout_kind != Payout.DIE:
		return null
	var value := payout_value(factor)
	var rarity := DiceOffer.bet_soul_rarity(value)
	if _reward_die == null or rarity != _die_rarity:
		var charms: Array[String] = []
		charms.assign(_context.get("charm_ids", []))
		var owned: Array[String] = []
		owned.assign(_context.get("owned_essences", []))
		_reward_die = DiceOffer.roll_bet_die(value, charms, owned,
			int(_context.get("tier", 1)))
		_die_rarity = rarity
	return _reward_die

## Einsatz-Etikett: Geld, die BENANNTEN Pakete (Sorte + Größe aus dem Besitz gezogen),
## Energie oder laufende Steuer. factor = Deal-Aufschlag (Wettsteuer, Hoher Tisch) -
## der Knopf muss den WIRKLICH fälligen Einsatz zeigen.
func stake_label(factor: float = 1.0) -> String:
	match stake_kind:
		Stake.PACKS:
			return Pack.amount_phrase(stake_pack_type, stake_pack_tier,
				scaled(stake_packs, factor))
		Stake.MONEY_PER_HAND:
			return "$%d je Hand" % scaled(stake, factor)
		Stake.MONEY_PER_DIE:
			return "$%d je Würfel" % scaled(stake, factor)
		Stake.ENERGY:
			return "%d ⚡" % scaled(stake_energy, factor)
	return "$%d" % scaled(stake, factor)

## Ein Einsatz mal Deal-Faktor, aufgerundet - EINE Rundung für Knopf und Buchung.
static func scaled(amount: int, factor: float) -> int:
	return ceili(float(amount) * factor - 0.0001)

## Gewinn-Etikett: was die Wette in ihrer Ware wirklich zahlt. factor wie oben;
## charm_ids nur für den Barbetrag (das Quotenblatt muss auf dem Knopf stehen).
func reward_label(factor: float = 1.0, charm_ids: Array[String] = []) -> String:
	match payout_kind:
		Payout.MONEY:
			return "$%d" % CharmEffects.side_bet_money(reward_money(factor), charm_ids)
		Payout.ENERGY:
			return "%d ⚡" % reward_energy(factor)
		Payout.PART:
			var part := reward_part()
			return "1 %s" % (part.display_name if part != null else "Modul")
		Payout.DIE:
			return "1 %s" % die_name(reward_die(factor))
		Payout.PACKS:
			return Pack.amount_phrase(reward_pack_type, reward_tier(factor), reward_count(factor))
		Payout.MULTIPLIER:
			return Pack.named_phrase(Pack.MULTIPLIER_NAME, reward_tier(factor),
				reward_count(factor))
		Payout.CARD_PACK:
			var card_pack := reward_card_pack(factor)
			return "1 %s" % (card_pack.display_name if card_pack != null else "Paket")
		Payout.DICE_PACK:
			var dice_pack := reward_dice_pack(factor)
			return "1 %s" % (dice_pack.display_name if dice_pack != null else "Paket")
	var card := _single_card()
	return "1 %s" % (card.display_name if card != null else special_id)

## Name eines Würfel-Gewinns samt Seele ("Kraftwürfel · Neon").
static func die_name(die: DieDefinition) -> String:
	if die == null:
		return "Würfel"
	var essence := Essence.by_id(die.essence_id) if die.essence_id != "" else null
	if essence == null:
		return die.display_name
	return "%s · %s" % [die.display_name, essence.display_name]
